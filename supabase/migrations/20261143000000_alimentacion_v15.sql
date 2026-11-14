-- Alimentación, Fase 8 v1.5 (migración 20261143): gasto de quien compró tras el segundo rechazo (respuesta del dueño, 14/nov/2026).
--   - Si el reembolso se rechaza por segunda vez, el gasto se registra en una cuenta del libro personal de quien compró.
--     Lo hace quien compró (no el albacea), con ali7_registrar_gasto: el movimiento es de su libro, no del de Papá.
--   - Si después se autoriza el reembolso, el pago se traspasa: el mecanismo lo define el dueño (pendiente).

-- 1. Guardia de compras: deja pasar el paso rechazada -> movimiento solo desde ali_registrar_gasto_rechazado.
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
    if old.estado_pago = 'rechazada' and new.estado_pago = 'movimiento'
       and current_setting('gravity.ali_gasto_propio', true) is not distinct from old.id::text
       and (to_jsonb(new) - v_libres) = (to_jsonb(old) - v_libres) then
      return new;  -- ali_registrar_gasto_rechazado (gasto de quien compró, tras el segundo rechazo)
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

-- 2. Registrar el gasto de quien compró (tras el segundo rechazo).
create function public.ali_registrar_gasto_rechazado(p_compra uuid, p_cuenta uuid, p_cuenta_gasto uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_c       public.ali_compras%rowtype;
  v_s       public.ali_solicitudes_pago%rowtype;
  v_tipo    text;
  v_titular uuid;
  v_gasto   uuid;
  v_nombre  text;
  v_mov     uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_c from public.ali_compras c where c.id = p_compra for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'La compra no existe.';
  end if;
  if v_c.cuenta <> 'papa' then
    raise exception using errcode = '22023', message = 'Solo las compras de Papá rechazadas dos veces pasan a gasto de quien compró.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s where s.compra_id = p_compra and s.intento = 2 and s.estado = 'rechazada';
  if not found then
    raise exception using errcode = '22023', message = 'El gasto se registra cuando el reembolso se rechaza por segunda vez.';
  end if;
  if v_s.solicitada_por is distinct from v_persona then
    raise exception using errcode = '42501', message = 'Solo quien compró registra el gasto.';
  end if;
  if v_c.estado_pago <> 'rechazada' then
    raise exception using errcode = '22023', message = 'La compra ya tiene su gasto registrado.';
  end if;
  if p_cuenta is null then
    raise exception using errcode = '22023', message = 'Elige la cuenta donde registras el gasto.';
  end if;
  select l.tipo, l.titular_id into v_tipo, v_titular
    from public.fin_cuentas c join public.fin_libros l on l.hogar_id = c.hogar_id and l.id = c.libro_id
   where c.hogar_id = v_c.hogar_id and c.id = p_cuenta;
  if not found or v_tipo <> 'personal' or v_titular is distinct from v_persona then
    raise exception using errcode = '22023', message = 'La cuenta debe ser de tu libro personal.';
  end if;
  v_gasto := coalesce(p_cuenta_gasto, public.ali7_cuenta_gasto_por_omision(v_c.hogar_id));
  if v_gasto is null or not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_c.hogar_id and c.id = v_gasto and c.clase = 'gasto') then
    raise exception using errcode = '22023', message = 'No hay una cuenta de gasto de Alimentación (indica p_cuenta_gasto).';
  end if;
  select i.nombre into v_nombre from public.ali_ingredientes i where i.hogar_id = v_c.hogar_id and i.id = v_c.ingrediente_id;
  v_mov := public.ali7_registrar_gasto(v_c.hogar_id, p_cuenta, v_gasto, v_s.monto_centavos,
             'Compra rechazada en el reembolso: ' || coalesce(v_nombre, 'compra'), null,
             'Compra de Papá rechazada dos veces por el albacea: el gasto es de quien compró');
  perform set_config('gravity.ali_gasto_propio', v_c.id::text, true);
  update public.ali_compras set estado_pago = 'movimiento', movimiento_id = v_mov where id = v_c.id;
  return v_mov;
end
$$;
comment on function public.ali_registrar_gasto_rechazado(uuid, uuid, uuid) is
  'Tras el segundo rechazo de una compra de Papá, quien compró registra el gasto en una cuenta de su libro personal (y, si hace falta, la cuenta de gasto de Alimentación). No mueve el libro de Papá.';

-- 3. Privilegios
revoke all on function public.ali_registrar_gasto_rechazado(uuid, uuid, uuid) from public, anon, service_role;
grant execute on function public.ali_registrar_gasto_rechazado(uuid, uuid, uuid) to authenticated;
