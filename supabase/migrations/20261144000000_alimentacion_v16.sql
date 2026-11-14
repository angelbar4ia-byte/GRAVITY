-- Alimentación, Fase 8 v1.6 (migración 20261144): reembolso por transferencia (opción A) y registro de quién compró.
--   - Un gasto rechazado dos veces es de quien compró (v1.5). Si el albacea autoriza el reembolso, propone una
--     transferencia de una cuenta de Papá a quien compró (ruta papa_a_persona). Quien compró la confirma y el dinero queda
--     en su cuenta; la confirmación genera el movimiento de transferencia entre los dos libros (sin duplicar nada).
--   - El consumo se refleja en Papá (pagado por transferencia): el resumen de Papá suma la compra cuando hay reembolso confirmado.
--   - Quien compró originalmente (comprado_por / solicitada_por) siempre queda registrado, sea quien sea el albacea.

-- 1. La ruta papa_a_persona (la propone el albacea; la confirma quien recibe).
alter table public.fin_transferencias drop constraint fin_transferencias_ruta_check;
alter table public.fin_transferencias add constraint fin_transferencias_ruta_check
  check (ruta in ('pareja_a_dueno', 'dueno_a_casa', 'pareja_a_casa', 'papa_a_persona'));
-- La persona destino es obligatoria en las rutas de persona (pareja_a_dueno y papa_a_persona); en las de casa, no.
alter table public.fin_transferencias drop constraint fin_transferencias_destino_persona;
alter table public.fin_transferencias add constraint fin_transferencias_destino_persona
  check ((ruta in ('pareja_a_dueno', 'papa_a_persona')) = (persona_destino_id is not null));
-- La subcuenta es de la casa: solo las rutas a casa la llevan; pareja_a_dueno y papa_a_persona no.
alter table public.fin_transferencias drop constraint fin_transferencias_subcuenta_ruta;
alter table public.fin_transferencias add constraint fin_transferencias_subcuenta_ruta
  check ((ruta in ('pareja_a_dueno', 'papa_a_persona') and subcuenta_id is null)
      or (ruta in ('dueno_a_casa', 'pareja_a_casa') and subcuenta_id is not null));

-- 2. La solicitud guarda la transferencia de su reembolso.
alter table public.ali_solicitudes_pago add column transferencia_id uuid references public.fin_transferencias (id);
comment on column public.ali_solicitudes_pago.transferencia_id is
  'Solo solicitudes rechazadas dos veces con reembolso autorizado: la transferencia de Papá a quien compró (ali_autorizar_reembolso).';

-- 3. ¿Es gasto de quien compró? (rechazada dos veces y sin reembolso confirmado)
create function public.ali_es_gasto_de_comprador(p_hogar_id uuid, p_compra uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.ali_solicitudes_pago s
                  where s.hogar_id = p_hogar_id and s.compra_id = p_compra and s.intento = 2 and s.estado = 'rechazada')
     and not exists (select 1 from public.ali_solicitudes_pago s join public.fin_transferencias t on t.id = s.transferencia_id
                      where s.hogar_id = p_hogar_id and s.compra_id = p_compra and t.estado = 'confirmada')
$$;
revoke all on function public.ali_es_gasto_de_comprador(uuid, uuid) from public, anon, service_role;
grant execute on function public.ali_es_gasto_de_comprador(uuid, uuid) to authenticated;

-- 3b. Confirmar la transferencia: el movimiento de Papá va en su nombre.
create or replace function public.fin_responder_transferencia(
  p_transferencia uuid, p_accion text, p_cuenta_destino uuid default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo      uuid := public.persona_actual();
  v_t       public.fin_transferencias%rowtype;
  v_cuenta  public.fin_cuentas%rowtype;
  v_origen  public.fin_cuentas%rowtype;
  v_cuentas uuid[];
  v_mov     uuid;
  v_receptor boolean;
begin
  if v_yo is null then
    raise exception using errcode = '42501', message = 'Sin sesión.';
  end if;
  if p_accion is null or p_accion not in ('confirmar', 'rechazar') then
    raise exception using errcode = '22023', message = 'La acción es confirmar o rechazar.';
  end if;
  select * into v_t from public.fin_transferencias t where t.id = p_transferencia for update;
  if not found then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esa transferencia.';
  end if;
  -- El receptor: la persona destino o, si la casa recibe, otro miembro de su libro.
  v_receptor := v_yo <> v_t.persona_origen_id
                and public.fin_puede(v_t.libro_destino_id, 'escribir')
                and (v_t.persona_destino_id is null or v_t.persona_destino_id = v_yo);
  if not v_receptor then
    raise exception using errcode = '42501', message = 'Solo la confirma o la rechaza quien la recibe.';
  end if;
  if v_t.estado <> 'pendiente' then
    if (v_t.estado = 'confirmada' and p_accion = 'confirmar' and v_t.confirmada_por = v_yo) then
      return v_t.movimiento_id;
    elsif (v_t.estado = 'rechazada' and p_accion = 'rechazar') then
      return null;
    end if;
    raise exception using errcode = '55000', message = format('La transferencia ya está %s.', v_t.estado);
  end if;

  if p_accion = 'rechazar' then
    update public.fin_transferencias
       set estado = 'rechazada', respondida_por = v_yo, respondida_en = now()
     where id = v_t.id;
    return null;
  end if;

  -- Confirmar: cuenta que recibe.
  if p_cuenta_destino is null then
    select array_agg(c.id) into v_cuentas from public.fin_cuentas c
     where c.libro_id = v_t.libro_destino_id and c.liquida and c.estado = 'activa';
    if coalesce(cardinality(v_cuentas), 0) <> 1 then
      raise exception using errcode = '22023', message = 'Elige la cuenta que recibe el dinero.';
    end if;
    p_cuenta_destino := v_cuentas[1];
  end if;
  select * into v_cuenta from public.fin_cuentas c
   where c.id = p_cuenta_destino and c.libro_id = v_t.libro_destino_id;
  if not found or v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' then
    raise exception using errcode = '22023',
      message = 'La cuenta que recibe es una cuenta de dinero activa de ese libro.';
  end if;
  select * into v_origen from public.fin_cuentas c where c.id = v_t.cuenta_origen_id;
  if v_origen.estado <> 'activa' then
    raise exception using errcode = '55000', message = 'La cuenta de origen ya no está activa.';
  end if;

  v_mov := gen_random_uuid();
  update public.fin_transferencias
     set estado = 'confirmada', confirmada_por = v_yo, respondida_por = v_yo, respondida_en = now(),
         cuenta_destino_id = p_cuenta_destino, movimiento_id = v_mov
   where id = v_t.id;
  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
    cuenta_destino_id, monto_centavos, realizado_por, registrado_por, via, nota, en_nombre_de, motivo)
  values (v_mov, v_t.hogar_id, 'transferencia', v_t.fecha, now(), v_t.cuenta_origen_id, p_cuenta_destino,
          v_t.monto_centavos, v_t.persona_origen_id, v_yo, 'manual', coalesce(v_t.nota, 'Transferencia confirmada'),
          (select l.titular_id from public.fin_libros l where l.id = v_t.libro_origen_id and l.tipo = 'representado'),
          case when exists (select 1 from public.fin_libros l where l.id = v_t.libro_origen_id and l.tipo = 'representado')
               then 'Reembolso de una compra de Papá' end);
  return v_mov;
end
$$;

-- 4. Autorizar el reembolso: el albacea propone la transferencia de Papá a quien compró.
create function public.ali_autorizar_reembolso(p_compra uuid, p_cuenta_papa uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_c       public.ali_compras%rowtype;
  v_s       public.ali_solicitudes_pago%rowtype;
  v_papa    uuid;
  v_t       public.fin_transferencias%rowtype;
  v_libro_d uuid;
  v_id      uuid := gen_random_uuid();
  v_cuenta  public.fin_cuentas%rowtype;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_c from public.ali_compras c where c.id = p_compra;
  if not found or v_c.cuenta <> 'papa' then
    raise exception using errcode = 'P0002', message = 'La compra de Papá no existe.';
  end if;
  v_papa := public.ali_libro_papa(v_c.hogar_id);
  if v_papa is null or not public.fin_puede(v_papa, 'escribir') then
    raise exception using errcode = '42501', message = 'Solo el albacea autoriza el reembolso.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s
   where s.compra_id = p_compra and s.intento = 2 and s.estado = 'rechazada';
  if not found then
    raise exception using errcode = '22023', message = 'El reembolso se autoriza para una compra rechazada dos veces.';
  end if;
  if v_c.estado_pago <> 'movimiento' then
    raise exception using errcode = '22023', message = 'Primero quien compró registra su gasto.';
  end if;
  if v_s.transferencia_id is not null and exists (select 1 from public.fin_transferencias t
       where t.id = v_s.transferencia_id and t.estado in ('pendiente', 'confirmada')) then
    raise exception using errcode = '22023', message = 'Ya hay una transferencia de reembolso activa.';
  end if;
  select * into v_cuenta from public.fin_cuentas c where c.hogar_id = v_c.hogar_id and c.id = p_cuenta_papa and c.libro_id = v_papa;
  if not found or v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'La cuenta de pago es una cuenta de dinero activa del libro de Papá.';
  end if;
  select l.id into v_libro_d from public.fin_libros l
   where l.hogar_id = v_c.hogar_id and l.tipo = 'personal' and l.titular_id = v_s.solicitada_por;
  if v_libro_d is null then
    raise exception using errcode = '22023', message = 'Quien compró no tiene libro personal.';
  end if;
  insert into public.fin_transferencias (id, hogar_id, ruta, persona_origen_id, persona_destino_id,
    libro_origen_id, libro_destino_id, cuenta_origen_id, monto_centavos, fecha, nota, propuesta_por)
  values (v_id, v_c.hogar_id, 'papa_a_persona', v_persona, v_s.solicitada_por,
          v_papa, v_libro_d, p_cuenta_papa, v_s.monto_centavos, current_date,
          'Reembolso de compra de Papá', v_persona);
  update public.ali_solicitudes_pago set transferencia_id = v_id where id = v_s.id;
  return v_id;
end
$$;
comment on function public.ali_autorizar_reembolso(uuid, uuid) is
  'El albacea autoriza el reembolso de una compra de Papá rechazada dos veces: propone la transferencia de una cuenta de Papá a quien compró. Quien compró la confirma con fin_responder_transferencia (el dinero llega a su cuenta). La compra conserva quién la hizo.';
revoke all on function public.ali_autorizar_reembolso(uuid, uuid) from public, anon, service_role;
grant execute on function public.ali_autorizar_reembolso(uuid, uuid) to authenticated;

-- 5. Detalle: quién compró, cada intento y el reembolso (lo ve el albacea y quien compró).
create function public.ali_detalle_reembolso(p_compra uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_c       public.ali_compras%rowtype;
  v_papa    uuid;
  v_out     jsonb;
begin
  select * into v_c from public.ali_compras c where c.id = p_compra;
  if not found then
    raise exception using errcode = 'P0002', message = 'La compra no existe.';
  end if;
  v_papa := public.ali_libro_papa(v_c.hogar_id);
  if v_persona is null or not (
       (v_papa is not null and public.fin_puede(v_papa, 'leer'))
       or v_c.comprado_por = v_persona
       or exists (select 1 from public.ali_solicitudes_pago s where s.compra_id = p_compra and s.solicitada_por = v_persona)) then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esta compra.';
  end if;
  select jsonb_build_object(
    'compra_id', v_c.id,
    'comprado_por', v_c.comprado_por,
    'solicitada_por', (select s.solicitada_por from public.ali_solicitudes_pago s where s.compra_id = v_c.id order by s.intento limit 1),
    'estado_pago', v_c.estado_pago,
    'intentos', coalesce((select jsonb_agg(jsonb_build_object(
                    'intento', s.intento, 'estado', s.estado, 'justificacion', s.justificacion, 'motivo', s.motivo,
                    'solicitada_por', s.solicitada_por, 'solicitada_en', s.solicitada_en, 'resuelta_en', s.resuelta_en)
                  order by s.intento) from public.ali_solicitudes_pago s where s.compra_id = v_c.id), '[]'::jsonb),
    'reembolso', (select jsonb_build_object('transferencia_id', t.id, 'estado', t.estado, 'monto_centavos', t.monto_centavos,
                    'confirmada_por', t.confirmada_por)
                    from public.ali_solicitudes_pago s join public.fin_transferencias t on t.id = s.transferencia_id
                   where s.compra_id = v_c.id and s.transferencia_id is not null
                   order by s.intento desc limit 1))
  into v_out;
  return v_out;
end
$$;
revoke all on function public.ali_detalle_reembolso(uuid) from public, anon, service_role;
grant execute on function public.ali_detalle_reembolso(uuid) to authenticated;

-- 6. Resumen de Papá: suma la compra cuando el consumo es de Papá (sin gasto de quien compró).
create or replace function public.ali_resumen_historial(
  p_hogar_id uuid, p_desde date, p_hasta date, p_eje text,
  p_escala text default 'mes', p_ingrediente uuid default null, p_tienda uuid default null)
returns table (
  clave text, etiqueta text, compras bigint, cantidad numeric, gasto_centavos bigint,
  precio_min_centavos bigint, precio_max_centavos bigint, precio_primero_centavos bigint, precio_ultimo_centavos bigint, variacion_pct numeric)
language plpgsql stable security invoker
set search_path = ''
as $$
begin
  if p_eje is null or p_eje not in ('tiempo', 'precio', 'producto', 'tienda') then
    raise exception using errcode = '22023', message = 'El eje es tiempo, precio, producto o tienda.';
  end if;
  if p_escala is null or p_escala not in ('semana', 'mes', 'bimestre', 'semestre', 'anio') then
    raise exception using errcode = '22023', message = 'La escala es semana, mes, bimestre, semestre o anio.';
  end if;
  return query
  with h as (
    select * from public.ali_historial_compras(p_hogar_id, p_desde, p_hasta, p_ingrediente, p_tienda) x
    where not x.revertida
      and not exists (select 1 from public.ali_compras c where c.hogar_id = p_hogar_id and c.id = x.compra_id and c.estado_pago = 'rechazada')
      and not public.ali_es_gasto_de_comprador(p_hogar_id, x.compra_id)
  ), g as (
    select h.*,
      case p_eje
        when 'tiempo' then (case p_escala
          when 'semana' then date_trunc('week', h.fecha::timestamp)
          when 'mes' then date_trunc('month', h.fecha::timestamp)
          when 'bimestre' then make_timestamp(extract(year from h.fecha)::int, ((extract(month from h.fecha)::int - 1) / 2) * 2 + 1, 1, 0, 0, 0)
          when 'semestre' then make_timestamp(extract(year from h.fecha)::int, ((extract(month from h.fecha)::int - 1) / 6) * 6 + 1, 1, 0, 0, 0)
          else date_trunc('year', h.fecha::timestamp) end)::date::text
        when 'tienda' then coalesce(h.tienda_id::text, 'sin_tienda')
        else h.ingrediente_id::text end as k,
      case p_eje when 'tienda' then h.tienda else h.ingrediente end as e
    from h
  )
  select g.k, min(g.e) as et, count(*)::bigint, sum(g.cantidad), sum(g.gasto_centavos)::bigint,
         case when p_eje in ('precio', 'producto') or p_ingrediente is not null then min(g.precio_unitario_centavos) end,
         case when p_eje in ('precio', 'producto') or p_ingrediente is not null then max(g.precio_unitario_centavos) end,
         case when p_eje = 'precio' then (array_agg(g.precio_unitario_centavos order by g.fecha, g.compra_id))[1] end,
         case when p_eje = 'precio' then (array_agg(g.precio_unitario_centavos order by g.fecha desc, g.compra_id desc))[1] end,
         case when p_eje = 'precio' then
           round(((array_agg(g.precio_unitario_centavos order by g.fecha desc, g.compra_id desc))[1]
                  - (array_agg(g.precio_unitario_centavos order by g.fecha, g.compra_id))[1])::numeric * 100
                 / nullif((array_agg(g.precio_unitario_centavos order by g.fecha, g.compra_id))[1], 0), 1) end
    from g
   group by g.k
   order by (case when p_eje = 'tiempo' then g.k end), sum(g.gasto_centavos) desc, g.k;
end
$$;

