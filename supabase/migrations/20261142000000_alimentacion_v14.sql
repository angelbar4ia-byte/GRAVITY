-- Alimentación, Fase 8 v1.4 (migración 20261142): reembolso de compras de Papá (respuesta del dueño, 14/nov/2026).
--   - Compra de Papá sin cuenta de pago = solicitud de reembolso al albacea.
--   - Aprobada: sale de una cuenta de Papá (ya era así).
--   - Rechazada: no se elige cuenta, no se mueve dinero y la compra queda como rechazada. Quien compró puede reenviar la
--     solicitud UNA vez con justificación (la solicitud nueva queda en la cola del albacea; la anterior se conserva).
--   - Rechazada otra vez: el gasto es de quien compró. No se registra en el libro de Papá; la compra sigue en el historial.
--   - El resumen de Papá no suma las compras rechazadas (son gasto de quien compró).
--   - Se quita el valor por omisión de la cuenta de efectivo de Papá al rechazar (cuenta_rechazo_id ya no se escribe).

-- 1. Intentos de la solicitud: el historial guarda cada intento (1 la original, 2 el reenvío).
alter table public.ali_solicitudes_pago add column intento smallint not null default 1 check (intento in (1, 2));
alter table public.ali_solicitudes_pago add column justificacion text check (char_length(justificacion) <= 200);
comment on column public.ali_solicitudes_pago.intento is 'Intento de la solicitud de reembolso: 1 la original, 2 el reenvío con justificación (el último).';
comment on column public.ali_solicitudes_pago.justificacion is 'Justificación de quien compró al reenviar la solicitud rechazada (de 3 a 200 caracteres).';
create unique index ali_solicitudes_pago_intento on public.ali_solicitudes_pago (compra_id, intento) where estado <> 'revertida';
drop index public.ali_solicitudes_pago_una;
create unique index ali_solicitudes_pago_activa on public.ali_solicitudes_pago (compra_id) where estado in ('pendiente', 'pagada');

-- 2. Rechazar: sin cuenta y sin dinero (ver encabezado).
create or replace function public.ali_resolver_solicitud_pago(
  p_solicitud uuid, p_aprobar boolean, p_cuenta_origen uuid default null, p_cuenta_gasto uuid default null, p_motivo text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_s       public.ali_solicitudes_pago%rowtype;
  v_c       public.ali_compras%rowtype;
  v_libro   uuid;
  v_titular uuid;
  v_gasto   uuid;
  v_mov     uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s where s.id = p_solicitud for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'La solicitud no existe.';
  end if;
  v_libro := public.ali_libro_papa(v_s.hogar_id);
  if v_libro is null or not public.fin_puede(v_libro, 'escribir') then
    raise exception using errcode = '42501', message = 'Solo el albacea resuelve las compras de Papá.';
  end if;
  if v_s.estado <> 'pendiente' then
    raise exception using errcode = '22023', message = 'La solicitud ya se resolvió.';
  end if;
  select * into v_c from public.ali_compras c where c.id = v_s.compra_id;
  if p_aprobar is null then
    raise exception using errcode = '22023', message = 'Indica si se aprueba.';
  end if;
  if p_aprobar then
    v_gasto := coalesce(p_cuenta_gasto, public.ali7_cuenta_gasto_por_omision(v_s.hogar_id));
    if v_gasto is null or not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_s.hogar_id and c.id = v_gasto and c.clase = 'gasto') then
      raise exception using errcode = '22023', message = 'No hay una cuenta de gasto de Alimentación (indica p_cuenta_gasto).';
    end if;
    if p_cuenta_origen is null or not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_s.hogar_id and c.id = p_cuenta_origen and c.libro_id = v_libro) then
      raise exception using errcode = '22023', message = 'La cuenta de pago es una cuenta del libro de Papá.';
    end if;
    select l.titular_id into v_titular from public.fin_libros l where l.id = v_libro;
    v_mov := public.ali7_registrar_gasto(v_s.hogar_id, p_cuenta_origen, v_gasto, v_s.monto_centavos,
               'Compra de la lista de Papá', v_titular, 'Compra de la lista de Alimentación aprobada por el albacea');
    update public.ali_solicitudes_pago set estado = 'pagada', resuelta_por = v_persona, resuelta_en = now(), movimiento_id = v_mov where id = v_s.id;
    update public.ali_compras set estado_pago = 'movimiento', movimiento_id = v_mov where id = v_s.compra_id;
  else
    if not public.fin_motivo_valido(p_motivo) then
      raise exception using errcode = '23514', message = 'Rechazar una compra de Papá lleva un motivo.';
    end if;
    -- v1.4: al rechazar no se elige cuenta. La compra queda como rechazada: quien compró puede reenviarla una vez
    -- con justificación; si se rechaza otra vez, el gasto es de quien compró (no se registra en el libro de Papá).
    if p_cuenta_gasto is not null then
      raise exception using errcode = '22023', message = 'Al rechazar no se elige cuenta: el gasto lo registra quien compró.';
    end if;
    update public.ali_solicitudes_pago set estado = 'rechazada', resuelta_por = v_persona, resuelta_en = now(), motivo = left(p_motivo, 200) where id = v_s.id;
    update public.ali_compras set estado_pago = 'rechazada' where id = v_s.compra_id;
  end if;
  return v_mov;
end
$$;

-- 2b. La guardia de compras deja pasar el paso rechazada -> solicitud (solo desde ali_reenviar_solicitud).
create or replace function public.ali_compras_guardia()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libres text[] := array['estado_pago', 'movimiento_id', 'cuenta_rechazo_id'];
  v_regreso text[] := array['comprado', 'comprado_en', 'comprado_por', 'monto_centavos', 'estado_pago', 'movimiento_id', 'tienda_id', 'cuenta_rechazo_id'];
begin
  if tg_op = 'DELETE' then
    if old.comprado then
      raise exception using errcode = '42501', message = 'Una compra marcada no se borra: se corrige en Finanzas con una anulación.';
    end if;
    return old;
  end if;
  if old.comprado then
    if not new.comprado and current_setting('gravity.ali_regreso', true) is not distinct from old.id::text
       and (to_jsonb(new) - v_regreso) = (to_jsonb(old) - v_regreso) then
      return new;  -- ali_regresar_compra
    end if;
    if old.estado_pago = 'rechazada' and new.estado_pago = 'solicitud'
       and current_setting('gravity.ali_reenvio', true) is not distinct from old.id::text
       and (to_jsonb(new) - v_libres) = (to_jsonb(old) - v_libres) then
      return new;  -- ali_reenviar_solicitud (un solo reenvío, con justificación)
    end if;
    if (to_jsonb(new) - v_libres) is distinct from (to_jsonb(old) - v_libres)
       or not (old.estado_pago = 'solicitud' and new.estado_pago in ('movimiento', 'rechazada')) then
      raise exception using errcode = '42501', message = 'Una compra marcada ya no se edita ni se desmarca.';
    end if;
  elsif new.comprado and (new.cuenta is distinct from old.cuenta or new.ingrediente_id is distinct from old.ingrediente_id) then
    raise exception using errcode = '42501', message = 'La cuenta y el ingrediente de una compra no cambian.';
  end if;
  return new;
end
$$;

-- 3. Reenviar una solicitud rechazada (solo quien compró, una vez, con justificación).
create function public.ali_reenviar_solicitud(p_solicitud uuid, p_justificacion text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_s       public.ali_solicitudes_pago%rowtype;
  v_j       text := btrim(coalesce(p_justificacion, ''));
  v_nueva   uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s where s.id = p_solicitud for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'La solicitud no existe.';
  end if;
  if v_s.solicitada_por is distinct from v_persona then
    raise exception using errcode = '42501', message = 'Solo quien compró reenvía la solicitud.';
  end if;
  if v_s.estado <> 'rechazada' or v_s.intento <> 1 then
    raise exception using errcode = '22023', message = 'Solo se reenvía una vez, y solo una solicitud rechazada. Si se rechazó otra vez, el gasto es tuyo.';
  end if;
  if exists (select 1 from public.ali_solicitudes_pago x where x.compra_id = v_s.compra_id and x.intento = 2 and x.estado <> 'revertida') then
    raise exception using errcode = '22023', message = 'Solo se reenvía una vez. Si se rechazó otra vez, el gasto es tuyo.';
  end if;
  if char_length(v_j) < 3 or char_length(v_j) > 200 then
    raise exception using errcode = '23514', message = 'La justificación lleva de 3 a 200 caracteres.';
  end if;
  insert into public.ali_solicitudes_pago (hogar_id, compra_id, monto_centavos, intento, justificacion)
    values (v_s.hogar_id, v_s.compra_id, v_s.monto_centavos, 2, left(v_j, 200))
    returning id into v_nueva;
  perform set_config('gravity.ali_reenvio', v_s.compra_id::text, true);  -- la guardia deja pasar solo este paso
  update public.ali_compras set estado_pago = 'solicitud' where id = v_s.compra_id;
  return v_nueva;
end
$$;
comment on function public.ali_reenviar_solicitud(uuid, text) is
  'Quien compró reenvía una vez una solicitud de reembolso rechazada, con justificación (3 a 200). La nueva queda en la cola del albacea; la rechazada se conserva en el historial.';

-- 4. Resumen de Papá sin compras rechazadas.
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

-- 5. Privilegios
revoke all on function public.ali_reenviar_solicitud(uuid, text) from public, anon, service_role;
grant execute on function public.ali_reenviar_solicitud(uuid, text) to authenticated;
