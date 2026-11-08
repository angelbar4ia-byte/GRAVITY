-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, bloque 2: ajustes v1.1 (docs/specs/fase-8-deudas-intereses.md, respuestas del dueño)
-- 1. Papá uniforme: fin_deudas_puede_ver sigue fin_puede(libro, 'leer') de la Fase 1 (también para fin_tarjetas
--    y fin_tarjeta_beneficios, que la usan en su RLS).
-- 2. Presupuesto mensual por omisión = suma de los pagos mínimos de las deudas activas con saldo; si se pasa uno,
--    no puede ser menor que esa suma (si lo es: no_alcanza).
-- 3. Vencimiento con ciclos futuros: cada mes se ordena por la fecha límite de ese ciclo (la fecha de la deuda
--    repetida cada mes); una deuda cuya fecha aún no llega al mes no tiene urgencia ese mes.
-- Migración hacia adelante. Sin cambios de firma.
-- =============================================================================

create or replace function public.fin_deudas_puede_ver(p_libro uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.fin_puede(p_libro, 'leer'), false)
$$;
comment on function public.fin_deudas_puede_ver(uuid) is
  'D19. Misma regla que fin_puede(libro, ''leer'') de la Fase 1: miembro vigente del libro (en el de Papá, el albacea '
  'y el suplente), vista temporal autorizada de un familiar y la cuenta maestra con consulta vigente.';

-- Primera fecha del ciclo mensual de una deuda que cae en p_desde o después (la fecha original si ya es futura).
create function public.fin_deudas_ciclo_desde(p_fecha date, p_desde date)
returns date
language plpgsql immutable
set search_path = ''
as $$
declare
  v_k integer;
  v_d date;
begin
  if p_fecha is null or p_fecha >= p_desde then
    return p_fecha;
  end if;
  v_k := ((extract(year from p_desde) - extract(year from p_fecha)) * 12
          + extract(month from p_desde) - extract(month from p_fecha))::integer;
  v_d := (p_fecha + v_k * interval '1 month')::date;
  if v_d < p_desde then
    v_d := (p_fecha + (v_k + 1) * interval '1 month')::date;
  end if;
  return v_d;
end
$$;
revoke execute on function public.fin_deudas_ciclo_desde(date, date) from public, anon, authenticated, service_role;

create or replace function public.fin_deudas_simular_nucleo(p_libro uuid, p_modo text, p_presupuesto bigint, p_hoy date)
returns table (
  estrategia text, estado text, falta text[], capital_centavos bigint, intereses_centavos bigint,
  total_pagado_centavos bigint, meses integer, orden uuid[], vencidas_sin_liquidar_mes1 integer,
  presupuesto_mensual_centavos bigint)
language plpgsql security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_nombre text := case p_modo when 'minimo' then 'pago_minimo' else p_modo end;
  v_ids    uuid[] := '{}';
  v_saldo  bigint[] := '{}';
  v_tasa   integer[] := '{}';
  v_min    bigint[] := '{}';
  v_lim    date[] := '{}';
  v_liq    boolean[] := '{}';
  v_falta  text[] := '{}';
  v_ord    integer[];
  v_orden  uuid[] := '{}';
  v_n      integer;
  v_i      integer;
  v_idx    integer;
  v_pres   bigint;
  v_cap    bigint := 0;
  v_int    bigint := 0;
  v_total  bigint := 0;
  v_mes    integer := 0;
  v_disp   bigint;
  v_p      bigint;
  v_ig     bigint;
  v_venc   integer := 0;
  v_suma_min bigint := 0;
  v_ini    date;
  v_fin    date;
  r        record;
begin
  for r in
    select d.id, d.tasa_anual_pb, d.tasa_pendiente, d.minimo_centavos, d.abono_centavos, d.frecuencia, d.fecha_limite,
           exists (select 1 from public.fin_movimientos m
                    where m.cuenta_origen_id = d.cuenta_pasivo_id or m.cuenta_destino_id = d.cuenta_pasivo_id) as hay,
           coalesce((select sum(s.saldo_centavos) from public.fin_v_saldos s
                      where s.cuenta_id = d.cuenta_pasivo_id and s.libro_id = d.libro_id), 0)::bigint as saldo
      from public.fin_deudas d
     where d.libro_id = p_libro and d.activa
     order by d.id
  loop
    if not r.hay then
      v_falta := v_falta || 'saldo'::text;
      continue;
    end if;
    if r.saldo <= 0 then
      continue;  -- ya está pagada
    end if;
    if r.tasa_pendiente then
      v_falta := v_falta || 'tasa'::text;
    end if;
    if p_modo = 'vencimiento' and r.fecha_limite is null then
      v_falta := v_falta || 'fecha_limite'::text;
    end if;
    if p_modo = 'minimo' and r.minimo_centavos = 0 then
      v_falta := v_falta || 'pago_minimo'::text;
    end if;
    v_ids := v_ids || r.id;
    v_saldo := v_saldo || r.saldo;
    v_tasa := v_tasa || r.tasa_anual_pb;
    v_min := v_min || r.minimo_centavos;
    v_lim := v_lim || r.fecha_limite;
    v_liq := v_liq || false;
    v_cap := v_cap + r.saldo;
    v_suma_min := v_suma_min + r.minimo_centavos;
  end loop;
  v_n := coalesce(cardinality(v_ids), 0);
  v_pres := coalesce(p_presupuesto, v_suma_min);

  if cardinality(v_falta) > 0 then
    return query select v_nombre, 'falta_dato', (select array_agg(distinct x order by x) from unnest(v_falta) x),
      null::bigint, null::bigint, null::bigint, null::integer, null::uuid[], null::integer, v_pres;
    return;
  end if;
  if v_n = 0 then
    return query select v_nombre, 'ok', '{}'::text[], 0::bigint, 0::bigint, 0::bigint, 0, '{}'::uuid[], 0, 0::bigint;
    return;
  end if;
  if p_modo <> 'minimo' and v_pres < v_suma_min then
    return query select v_nombre, 'no_alcanza', '{presupuesto}'::text[], null::bigint, null::bigint, null::bigint,
      null::integer, null::uuid[], null::integer, v_pres;
    return;
  end if;

  while v_mes < 600 and exists (select 1 from unnest(v_saldo) s where s > 0) loop
    v_mes := v_mes + 1;
    -- Orden de ataque del dinero extra. En vencimiento se recalcula cada mes con las fechas límite de ese ciclo.
    v_ini := (p_hoy + (v_mes - 1) * interval '1 month')::date;
    v_fin := (p_hoy + v_mes * interval '1 month')::date;
    select array_agg(t.i order by t.k0, t.k1, t.k2, t.i) into v_ord
      from (select g.i,
                   case when p_modo = 'vencimiento' and v_lim[g.i] >= v_fin then 1 else 0 end as k0,
                   case p_modo when 'bola_de_nieve' then v_saldo[g.i]
                               when 'avalancha' then -v_tasa[g.i]::bigint
                               when 'vencimiento' then (
                                 case when v_mes = 1 then v_lim[g.i]
                                      else public.fin_deudas_ciclo_desde(v_lim[g.i], v_ini) end
                                 - date '2000-01-01')::bigint
                               else g.i::bigint end as k1,
                   case p_modo when 'bola_de_nieve' then -v_tasa[g.i]::bigint
                               when 'avalancha' then v_saldo[g.i]
                               when 'vencimiento' then -v_tasa[g.i]::bigint
                               else 0::bigint end as k2
              from generate_series(1, v_n) g (i)) t;
    for v_i in 1..v_n loop
      if v_saldo[v_i] > 0 then
        v_ig := (v_saldo[v_i] * v_tasa[v_i] + 60000) / 120000;
        v_saldo[v_i] := v_saldo[v_i] + v_ig;
        v_int := v_int + v_ig;
      end if;
    end loop;
    v_disp := v_pres;
    for v_i in 1..v_n loop
      if v_saldo[v_i] > 0 then
        v_p := least(v_min[v_i], v_saldo[v_i]);
        v_saldo[v_i] := v_saldo[v_i] - v_p;
        v_total := v_total + v_p;
        v_disp := v_disp - v_p;
      end if;
    end loop;
    if p_modo <> 'minimo' then
      foreach v_idx in array v_ord loop
        exit when v_disp <= 0;
        if v_saldo[v_idx] > 0 then
          v_p := least(v_disp, v_saldo[v_idx]);
          v_saldo[v_idx] := v_saldo[v_idx] - v_p;
          v_total := v_total + v_p;
          v_disp := v_disp - v_p;
        end if;
      end loop;
    end if;
    foreach v_idx in array v_ord loop
      if v_saldo[v_idx] = 0 and not v_liq[v_idx] then
        v_liq[v_idx] := true;
        v_orden := v_orden || v_ids[v_idx];
      end if;
    end loop;
    if v_mes = 1 then
      select count(*)::integer into v_venc from generate_series(1, v_n) g (i)
       where v_lim[g.i] is not null and v_lim[g.i] <= p_hoy and v_saldo[g.i] > 0;
    end if;
  end loop;

  if exists (select 1 from unnest(v_saldo) s where s > 0) then
    return query select v_nombre, 'no_alcanza', case when p_modo = 'minimo' then '{pago_minimo}' else '{presupuesto}' end::text[],
      null::bigint, null::bigint, null::bigint, null::integer, null::uuid[], null::integer, v_pres;
    return;
  end if;
  return query select v_nombre, 'ok', '{}'::text[], v_cap, v_int, v_total, v_mes, v_orden, v_venc,
    case when p_modo = 'minimo' then null::bigint else v_pres end;
end
$$;

comment on function public.fin_simular_estrategias(uuid, text, bigint, date) is
  'Fase 8 bloque 2 (v1.1). Para bola_de_nieve, avalancha y vencimiento: capital pagado, intereses, total pagado, meses y '
  'orden de liquidación (ids de deuda). Si falta un saldo, una tasa (o la fecha límite en vencimiento) devuelve estado '
  'falta_dato y la lista en falta; no estima. no_alcanza = el presupuesto no cubre los mínimos o no liquida en 600 meses. '
  'recomendada = menor interés entre las que calcularon; el pago lo confirma la persona. Presupuesto mensual: si es nulo, '
  'la suma de los pagos mínimos de las deudas; si se pasa, ese monto (menor que la suma de mínimos = no_alcanza). '
  'vencimiento proyecta cada mes la fecha límite de cada deuda (ciclos futuros). Solo quien administra el libro.';
comment on function public.fin_estimar_intereses(uuid, bigint, date) is
  'Fase 8 bloque 2 (v1.1). Intereses con el pago mínimo (pago_minimo) y con cada estrategia, y cuánto se ahorra frente al '
  'mínimo. Presupuesto nulo = suma de los pagos mínimos; uno menor que esa suma da no_alcanza. Sin dato (saldo, tasa, '
  'pago mínimo) responde falta_dato; sin estimar. Solo quien administra el libro.';
