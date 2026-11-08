-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, bloque 2: deudas e intereses (docs/specs/fase-8-deudas-intereses.md v1.0)
-- Simulador de estrategias de pago, estimador de intereses y beneficios de tarjetas.
-- =============================================================================
-- * No se duplica lo que ya existe: fin_deudas (Fase 1 y 2) ya guarda la tasa en puntos base
--   (tasa_anual_pb), el pago mínimo (minimo_centavos) y el calendario; el SALDO sale del libro (cuenta pasivo).
--   Se agregan: fecha_limite (próxima fecha límite de pago), dato_verificado (falso = capturado a mano, no leído
--   de un estado de cuenta) y tasa_pendiente (la tasa aún no se conoce: el simulador dice "falta dato").
-- * Tablas nuevas: fin_tarjetas y fin_tarjeta_beneficios. Sin escritura directa: solo las RPC.
-- * Funciones: fin_simular_estrategias y fin_estimar_intereses (cálculo en el servidor, nada sale a la IA, D3).
-- * Reglas (D19): cada tarjeta y deuda pertenece a una persona (su libro). Las ven y escriben solo quien lleva el
--   libro (la titular; el dueño como albacea de Papá; la pareja en la casa) y la cuenta maestra con consulta
--   vigente (solo lectura). Casa, la familiar y la cuidadora no ven nada. Las tablas nuevas, además, no muestran el
--   libro de Papá al suplente mientras haya albacea (ver fin_deudas_puede_ver).
-- * Bitácora sin saldos ni tasas: se recrea el trigger de fin_deudas omitiendo cifras.
-- Migración hacia adelante. Sin secretos ni datos reales.
-- =============================================================================

-- 1. fin_deudas: columnas nuevas ---------------------------------------------------------------------------------------
alter table public.fin_deudas
  add column fecha_limite date,
  add column dato_verificado boolean not null default false,
  add column tasa_pendiente boolean not null default false;
comment on column public.fin_deudas.fecha_limite is
  'Próxima fecha límite de pago (del estado de cuenta). Nula = falta el dato para la estrategia por vencimiento.';
comment on column public.fin_deudas.dato_verificado is
  'Verdadero = tasa, mínimo y fecha salen de un estado de cuenta. Falso = capturado a mano.';
comment on column public.fin_deudas.tasa_pendiente is
  'Verdadero = la tasa aún no se conoce (tasa_anual_pb queda en 0). El simulador responde falta_dato; nunca estima.';

alter table public.fin_deudas drop constraint fin_deudas_tasa;
alter table public.fin_deudas add constraint fin_deudas_tasa check (
  tasa_anual_pb >= 0
  and (not tasa_pendiente or tasa_anual_pb = 0)
  and ((tipo = 'con_costo' and (tasa_anual_pb > 0 or tasa_pendiente))
       or (tipo <> 'con_costo' and tasa_anual_pb = 0)));

-- Convención 12: el grant repite la lista completa de columnas.
grant insert (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma,
              dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil, minimo_centavos,
              tasa_anual_pb, prioridad_manual, grupo_prioritario, orden_grupo, activa,
              clase, acreedor, monto_original_centavos, cat_pb, corte_dia, permite_pago_anticipado, extra_reduce,
              fecha_limite, dato_verificado, tasa_pendiente),
      update (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma,
              dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil, minimo_centavos,
              tasa_anual_pb, prioridad_manual, grupo_prioritario, orden_grupo, activa,
              clase, acreedor, monto_original_centavos, cat_pb, corte_dia, permite_pago_anticipado, extra_reduce,
              fecha_limite, dato_verificado, tasa_pendiente)
  on public.fin_deudas to authenticated;

-- Bitácora de fin_deudas sin tasas, mínimos, abonos ni fechas límite (D3: nada de cifras).
drop trigger fin_z_bitacora on public.fin_deudas;
create trigger fin_z_bitacora after insert or update or delete on public.fin_deudas
  for each row execute function public.registrar_cambio_en_bitacora(
    'hogar_id', 'tasa_anual_pb', 'minimo_centavos', 'abono_centavos', 'cat_pb', 'monto_original_centavos',
    'fecha_limite');

-- 2. Tarjetas y beneficios ---------------------------------------------------------------------------------------------
create table public.fin_tarjetas (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid not null,
  titular_id      uuid not null references public.personas (id),
  deuda_id        uuid,
  banco           text not null check (char_length(btrim(banco)) between 1 and 60),
  nombre          text not null check (char_length(btrim(nombre)) between 1 and 60),
  limite_centavos bigint check (limite_centavos > 0),
  corte_dia       smallint check (corte_dia between 0 and 31),
  limite_pago_dia smallint check (limite_pago_dia between 0 and 31),
  activa          boolean not null default true,
  creada_por      uuid not null default public.persona_actual() references public.personas (id),
  creada_en       timestamptz not null default now(),
  constraint fin_tarjetas_libro_id_key unique (libro_id, id),
  constraint fin_tarjetas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_tarjetas_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id)
);
create unique index fin_tarjetas_nombre_unico on public.fin_tarjetas (libro_id, lower(btrim(banco)), lower(btrim(nombre)))
  where activa;
comment on table public.fin_tarjetas is
  'Tarjeta de una persona (su libro). corte_dia y limite_pago_dia son días del mes (0 = último). limite_centavos '
  'opcional. deuda_id: la deuda (clase tarjeta) que la representa. Escritura solo por RPC.';

create table public.fin_tarjeta_beneficios (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  tarjeta_id     uuid not null,
  tipo           text not null check (tipo in ('puntos', 'cashback', 'meses_sin_intereses')),
  descripcion    text not null check (char_length(btrim(descripcion)) between 1 and 80
                                       and descripcion !~ '[$]' and descripcion !~ '[0-9]{4}'),
  vigente_desde  date not null,
  vigente_hasta  date,
  activo         boolean not null default true,
  creado_por     uuid not null default public.persona_actual() references public.personas (id),
  creado_en      timestamptz not null default now(),
  constraint fin_tarjeta_beneficios_tarjeta_fk foreign key (libro_id, tarjeta_id)
    references public.fin_tarjetas (libro_id, id),
  constraint fin_tarjeta_beneficios_vigencia check (vigente_hasta is null or vigente_hasta >= vigente_desde)
);
create index fin_tarjeta_beneficios_tarjeta_idx on public.fin_tarjeta_beneficios (tarjeta_id);
comment on table public.fin_tarjeta_beneficios is
  'Beneficio de una tarjeta (puntos, cashback, meses sin intereses). Descripción corta, sin cifras de saldo (ni "$" ni '
  'números de 4 dígitos). Escritura solo por RPC.';

-- 3. Quién ve las deudas y tarjetas (D19) -----------------------------------------------------------------------------
-- Lee quien puede leer el libro. En el libro de Papá solo quien lo administra (el dueño como albacea; el suplente
-- solo si no hay albacea) y la maestra con consulta vigente.
create function public.fin_deudas_puede_ver(p_libro uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.fin_puede(p_libro, 'leer')
         and (l.tipo <> 'representado'
              or public.fin_puede(p_libro, 'administrar')
              or public.es_cuenta_maestra(l.hogar_id)), false)
  from public.fin_libros l where l.id = p_libro
$$;
comment on function public.fin_deudas_puede_ver(uuid) is
  'D19. Ve las tarjetas y beneficios del libro quien puede leerlo; en el libro de Papá, solo quien lo administra '
  '(albacea) y la cuenta maestra con consulta vigente.';

create function public.fin_tarjetas_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if tg_op = 'INSERT' or new.titular_id is distinct from old.titular_id then
    if not (v_libro.titular_id = new.titular_id
            or exists (select 1 from public.fin_libro_miembros m
                        where m.libro_id = new.libro_id and m.persona_id = new.titular_id
                          and m.desde <= now() and (m.hasta is null or m.hasta > now()))) then
      raise exception using errcode = '22023', message = 'La titular de la tarjeta debe llevar este libro.';
    end if;
  end if;
  if new.deuda_id is not null and not exists (
       select 1 from public.fin_deudas d where d.id = new.deuda_id and d.libro_id = new.libro_id and d.clase = 'tarjeta') then
    raise exception using errcode = '22023', message = 'La deuda de una tarjeta es de clase tarjeta y del mismo libro.';
  end if;
  return new;
end
$$;
create trigger fin_a_columnas_fijas before update on public.fin_tarjetas
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'creada_por', 'creada_en');
create trigger fin_b_validar before insert or update on public.fin_tarjetas
  for each row execute function public.fin_tarjetas_validar();
create trigger fin_a_columnas_fijas before update on public.fin_tarjeta_beneficios
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'tarjeta_id', 'creado_por', 'creado_en');

-- Sin borrados ni TRUNCATE: una baja es activa = false.
create function public.fin_tarjetas_sin_borrar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '42501', message = 'Las tarjetas y sus beneficios no se borran: se dan de baja.';
end
$$;
create trigger fin_a_sin_borrar before delete on public.fin_tarjetas
  for each row execute function public.fin_tarjetas_sin_borrar();
create trigger fin_a_sin_borrar before delete on public.fin_tarjeta_beneficios
  for each row execute function public.fin_tarjetas_sin_borrar();

-- Bitácora sin cifras (el límite de crédito se omite).
create trigger fin_z_bitacora after insert or update or delete on public.fin_tarjetas
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'limite_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_tarjeta_beneficios
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');

alter table public.fin_tarjetas enable row level security;
alter table public.fin_tarjeta_beneficios enable row level security;
create policy fin_tarjetas_leer on public.fin_tarjetas for select to authenticated
  using (public.fin_deudas_puede_ver(libro_id));
create policy fin_tarjeta_beneficios_leer on public.fin_tarjeta_beneficios for select to authenticated
  using (public.fin_deudas_puede_ver(libro_id));

revoke all on table public.fin_tarjetas, public.fin_tarjeta_beneficios
  from public, anon, authenticated, service_role;
grant select on public.fin_tarjetas, public.fin_tarjeta_beneficios to authenticated, service_role;
-- Sin grant de escritura: solo las RPC.

-- 4. RPC de escritura ------------------------------------------------------------------------------------------------
create function public.fin_tarjeta_guardar(
  p_id uuid, p_libro uuid, p_titular uuid, p_banco text, p_nombre text,
  p_limite_centavos bigint default null, p_corte_dia smallint default null, p_limite_pago_dia smallint default null,
  p_deuda uuid default null, p_activa boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_ex    public.fin_tarjetas%rowtype;
begin
  if public.persona_actual() is null or p_libro is null or not public.fin_puede(p_libro, 'administrar') then
    raise exception using errcode = '42501', message = 'No puedes administrar las tarjetas de este libro.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = p_libro;
  if not v_libro.activo then
    raise exception using errcode = '42501', message = 'El libro está archivado.';
  end if;
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id de la tarjeta es obligatorio.';
  end if;
  select * into v_ex from public.fin_tarjetas t where t.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro then
      raise exception using errcode = '23505', message = 'Ese id ya es de otra tarjeta.';
    end if;
    update public.fin_tarjetas t
       set titular_id = p_titular, deuda_id = p_deuda, banco = btrim(p_banco), nombre = btrim(p_nombre),
           limite_centavos = p_limite_centavos, corte_dia = p_corte_dia, limite_pago_dia = p_limite_pago_dia,
           activa = p_activa
     where t.id = p_id;
  else
    insert into public.fin_tarjetas (id, hogar_id, libro_id, titular_id, deuda_id, banco, nombre, limite_centavos,
                                     corte_dia, limite_pago_dia, activa)
    values (p_id, v_libro.hogar_id, p_libro, p_titular, p_deuda, btrim(p_banco), btrim(p_nombre), p_limite_centavos,
            p_corte_dia, p_limite_pago_dia, p_activa);
  end if;
  return p_id;
end
$$;
comment on function public.fin_tarjeta_guardar(uuid, uuid, uuid, text, text, bigint, smallint, smallint, uuid, boolean) is
  'Crea o actualiza (idempotente por id) una tarjeta del libro. Solo quien administra el libro (titular; albacea de Papá). '
  'Una baja es p_activa = false.';

create function public.fin_tarjeta_beneficio_guardar(
  p_id uuid, p_tarjeta uuid, p_tipo text, p_descripcion text, p_desde date, p_hasta date default null,
  p_activo boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_t  public.fin_tarjetas%rowtype;
  v_ex public.fin_tarjeta_beneficios%rowtype;
begin
  select * into v_t from public.fin_tarjetas t where t.id = p_tarjeta;
  if not found or public.persona_actual() is null or not public.fin_puede(v_t.libro_id, 'administrar') then
    raise exception using errcode = '42501', message = 'No puedes administrar los beneficios de esta tarjeta.';
  end if;
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id del beneficio es obligatorio.';
  end if;
  select * into v_ex from public.fin_tarjeta_beneficios b where b.id = p_id;
  if found then
    if v_ex.tarjeta_id <> p_tarjeta then
      raise exception using errcode = '23505', message = 'Ese id ya es de otro beneficio.';
    end if;
    update public.fin_tarjeta_beneficios b
       set tipo = p_tipo, descripcion = btrim(p_descripcion), vigente_desde = p_desde, vigente_hasta = p_hasta,
           activo = p_activo
     where b.id = p_id;
  else
    insert into public.fin_tarjeta_beneficios (id, hogar_id, libro_id, tarjeta_id, tipo, descripcion, vigente_desde,
                                               vigente_hasta, activo)
    values (p_id, v_t.hogar_id, v_t.libro_id, p_tarjeta, p_tipo, btrim(p_descripcion), p_desde, p_hasta, p_activo);
  end if;
  return p_id;
end
$$;
comment on function public.fin_tarjeta_beneficio_guardar(uuid, uuid, text, text, date, date, boolean) is
  'Crea o actualiza (idempotente por id) un beneficio de tarjeta: puntos, cashback o meses_sin_intereses; '
  'descripción corta sin cifras de saldo. Solo quien administra el libro.';

-- Tasa, mínimo y fecha límite de una deuda (tasa nula = pendiente: el simulador dirá falta_dato).
create function public.fin_deuda_datos_guardar(
  p_deuda uuid, p_tasa_pb integer, p_pago_minimo_centavos bigint, p_fecha_limite date, p_verificado boolean default false)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d public.fin_deudas%rowtype;
begin
  select * into v_d from public.fin_deudas d where d.id = p_deuda;
  if not found or public.persona_actual() is null or not public.fin_puede(v_d.libro_id, 'administrar') then
    raise exception using errcode = '42501', message = 'No puedes administrar las deudas de este libro.';
  end if;
  if p_pago_minimo_centavos is null or p_pago_minimo_centavos < 0 then
    raise exception using errcode = '22023', message = 'El pago mínimo es de 0 en adelante, en centavos.';
  end if;
  update public.fin_deudas d
     set tasa_anual_pb = coalesce(p_tasa_pb, 0), tasa_pendiente = (p_tasa_pb is null),
         minimo_centavos = p_pago_minimo_centavos, fecha_limite = p_fecha_limite,
         dato_verificado = coalesce(p_verificado, false)
   where d.id = p_deuda;
end
$$;
comment on function public.fin_deuda_datos_guardar(uuid, integer, bigint, date, boolean) is
  'Fija tasa (puntos base; nula = pendiente), pago mínimo, fecha límite y si el dato es verificado (de un estado de '
  'cuenta) o capturado a mano. Solo quien administra el libro.';

-- 5. Simulación ----------------------------------------------------------------------------------------------------------
-- Núcleo: una estrategia sobre las deudas activas del libro, mes a mes (interés mensual = tasa / 12 sobre el saldo,
-- redondeado al centavo; se pagan los mínimos y el resto del presupuesto va a la deuda que toca). Nunca estima:
-- si falta un saldo, una tasa (o la fecha límite, solo en vencimiento; el mínimo, solo en pago_minimo), responde
-- falta_dato. Sin permisos: lo llaman las funciones públicas ya autorizadas.
create function public.fin_deudas_simular_nucleo(p_libro uuid, p_modo text, p_presupuesto bigint, p_hoy date)
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
  v_pres_def bigint := 0;
  v_cap    bigint := 0;
  v_int    bigint := 0;
  v_total  bigint := 0;
  v_mes    integer := 0;
  v_disp   bigint;
  v_p      bigint;
  v_ig     bigint;
  v_venc   integer := 0;
  v_suma_min bigint := 0;
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
    v_pres_def := v_pres_def + greatest(r.minimo_centavos, round(r.abono_centavos * case r.frecuencia
        when 'semanal' then 52.0 / 12 when 'catorcenal' then 26.0 / 12 when 'quincenal' then 2.0
        when 'mensual' then 1.0 when 'bimestral' then 0.5 when 'trimestral' then 1.0 / 3
        when 'semestral' then 1.0 / 6 when 'anual' then 1.0 / 12 else 1.0 end)::bigint);
  end loop;
  v_n := coalesce(cardinality(v_ids), 0);
  v_pres := coalesce(p_presupuesto, v_pres_def);

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

  -- Orden de ataque (solo para el dinero extra).
  select array_agg(t.i order by t.k1, t.k2, t.i) into v_ord
    from (select g.i,
                 case p_modo when 'bola_de_nieve' then v_saldo[g.i]
                             when 'avalancha' then -v_tasa[g.i]::bigint
                             when 'vencimiento' then (v_lim[g.i] - date '2000-01-01')::bigint
                             else g.i::bigint end as k1,
                 case p_modo when 'bola_de_nieve' then -v_tasa[g.i]::bigint
                             when 'avalancha' then v_saldo[g.i]
                             when 'vencimiento' then -v_tasa[g.i]::bigint
                             else 0::bigint end as k2
            from generate_series(1, v_n) g (i)) t;

  while v_mes < 600 and exists (select 1 from unnest(v_saldo) s where s > 0) loop
    v_mes := v_mes + 1;
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

-- Quién puede simular: quien administra el libro (la titular; el dueño como albacea de Papá). No la maestra.
create function public.fin_deudas_simulacion_autoriza(p_libro uuid)
returns void
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if public.persona_actual() is null or p_libro is null or not public.fin_puede(p_libro, 'administrar') then
    raise exception using errcode = '42501', message = 'Solo quien lleva este libro simula sus deudas.';
  end if;
end
$$;

create function public.fin_simular_estrategias(
  p_libro uuid, p_estrategia text default null, p_presupuesto_mensual bigint default null,
  p_hoy date default current_date)
returns table (
  estrategia text, estado text, falta text[], capital_centavos bigint, intereses_centavos bigint,
  total_pagado_centavos bigint, meses integer, orden uuid[], vencidas_sin_liquidar_mes1 integer,
  presupuesto_mensual_centavos bigint, recomendada boolean)
language plpgsql stable security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.fin_deudas_simulacion_autoriza(p_libro);
  if p_estrategia is not null and p_estrategia not in ('bola_de_nieve', 'avalancha', 'vencimiento') then
    raise exception using errcode = '22023', message = 'La estrategia es bola_de_nieve, avalancha o vencimiento.';
  end if;
  if p_presupuesto_mensual is not null and p_presupuesto_mensual < 0 then
    raise exception using errcode = '22023', message = 'El presupuesto mensual no es negativo.';
  end if;
  return query
  with e as (
    select s.n, x.*
      from unnest(array['bola_de_nieve', 'avalancha', 'vencimiento']) with ordinality as s (modo, n)
     cross join lateral public.fin_deudas_simular_nucleo(p_libro, s.modo, p_presupuesto_mensual, p_hoy) x
     where p_estrategia is null or s.modo = p_estrategia)
  select e.estrategia, e.estado, e.falta, e.capital_centavos, e.intereses_centavos, e.total_pagado_centavos, e.meses,
         e.orden, e.vencidas_sin_liquidar_mes1, e.presupuesto_mensual_centavos,
         (e.estado = 'ok' and row_number() over (partition by (e.estado = 'ok') order by e.intereses_centavos, e.n) = 1)
    from e
   order by e.n;
end
$$;
comment on function public.fin_simular_estrategias(uuid, text, bigint, date) is
  'Fase 8 bloque 2. Para bola_de_nieve, avalancha y vencimiento: capital pagado, intereses, total pagado, meses y orden '
  'de liquidación (ids de deuda). Si falta un saldo, una tasa (o la fecha límite en vencimiento) devuelve estado '
  'falta_dato y la lista en falta; no estima. no_alcanza = el presupuesto no cubre los mínimos o no liquida en 600 meses. '
  'recomendada = menor interés entre las que calcularon; el pago lo confirma la persona. Presupuesto mensual por omisión: '
  'la suma de los abonos de las deudas (en su equivalente mensual, no menos que el mínimo). Solo quien administra el libro.';

create function public.fin_estimar_intereses(
  p_libro uuid, p_presupuesto_mensual bigint default null, p_hoy date default current_date)
returns table (
  escenario text, estado text, falta text[], intereses_centavos bigint, meses integer,
  ahorro_vs_minimo_centavos bigint)
language plpgsql stable security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform public.fin_deudas_simulacion_autoriza(p_libro);
  if p_presupuesto_mensual is not null and p_presupuesto_mensual < 0 then
    raise exception using errcode = '22023', message = 'El presupuesto mensual no es negativo.';
  end if;
  return query
  with e as (
    select s.n, x.*
      from unnest(array['minimo', 'bola_de_nieve', 'avalancha', 'vencimiento']) with ordinality as s (modo, n)
     cross join lateral public.fin_deudas_simular_nucleo(p_libro, s.modo, p_presupuesto_mensual, p_hoy) x)
  select e.estrategia, e.estado, e.falta, e.intereses_centavos, e.meses,
         case when e.n > 1 and e.estado = 'ok' and m.estado = 'ok' then m.intereses_centavos - e.intereses_centavos end
    from e cross join (select e2.estado, e2.intereses_centavos from e e2 where e2.n = 1) m
   order by e.n;
end
$$;
comment on function public.fin_estimar_intereses(uuid, bigint, date) is
  'Fase 8 bloque 2. Intereses con el pago mínimo (pago_minimo) y con cada estrategia, y cuánto se ahorra frente al '
  'mínimo. Sin dato (saldo, tasa, pago mínimo) responde falta_dato; sin estimar. Solo quien administra el libro.';

-- 6. Privilegios ------------------------------------------------------------------------------------------------------------
revoke execute on function
  public.fin_deudas_puede_ver(uuid), public.fin_tarjetas_validar(), public.fin_tarjetas_sin_borrar(),
  public.fin_tarjeta_guardar(uuid, uuid, uuid, text, text, bigint, smallint, smallint, uuid, boolean),
  public.fin_tarjeta_beneficio_guardar(uuid, uuid, text, text, date, date, boolean),
  public.fin_deuda_datos_guardar(uuid, integer, bigint, date, boolean),
  public.fin_deudas_simular_nucleo(uuid, text, bigint, date), public.fin_deudas_simulacion_autoriza(uuid),
  public.fin_simular_estrategias(uuid, text, bigint, date), public.fin_estimar_intereses(uuid, bigint, date)
  from public, anon, authenticated, service_role;
grant execute on function public.fin_deudas_puede_ver(uuid) to authenticated, service_role;
grant execute on function
  public.fin_tarjeta_guardar(uuid, uuid, uuid, text, text, bigint, smallint, smallint, uuid, boolean),
  public.fin_tarjeta_beneficio_guardar(uuid, uuid, text, text, date, date, boolean),
  public.fin_deuda_datos_guardar(uuid, integer, bigint, date, boolean),
  public.fin_simular_estrategias(uuid, text, bigint, date), public.fin_estimar_intereses(uuid, bigint, date)
  to authenticated;
