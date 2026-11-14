-- Alimentación, Fase 8 v1.7 (migración 20261145): opción B (reclasificar el gasto) y botones del albacea.
--   - B: el albacea reclasifica el gasto de quien compró al libro de Papá (pagado desde una cuenta de Papá) y quien compró anula
--     su gasto en su libro con un contraasiento (lo hace ella). Sin transferencia: el dinero ya lo pagó quien compró.
--   - Mientras haya reembolso activo o confirmado, no se reclasifica; y al reclasificar, no hay reembolso que autorizar.
--   - El resumen de Papá suma la compra cuando el albacea la reclasifica (el costo ya es de Papá).

-- 1. La solicitud guarda el movimiento de Papá de la reclasificación.
alter table public.ali_solicitudes_pago add column reclasificacion_movimiento_id uuid references public.fin_movimientos (id);
comment on column public.ali_solicitudes_pago.reclasificacion_movimiento_id is
  'Gasto de Papá con que el albacea reclasificó una compra rechazada dos veces (opción B). Quien compró anula su gasto en su libro.';

create or replace function public.ali_es_gasto_de_comprador(p_hogar_id uuid, p_compra uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.ali_solicitudes_pago s
                  where s.hogar_id = p_hogar_id and s.compra_id = p_compra and s.intento = 2 and s.estado = 'rechazada')
     and not exists (select 1 from public.ali_solicitudes_pago s
                      where s.hogar_id = p_hogar_id and s.compra_id = p_compra and s.reclasificacion_movimiento_id is not null)
     and not exists (select 1 from public.ali_solicitudes_pago s join public.fin_transferencias t on t.id = s.transferencia_id
                      where s.hogar_id = p_hogar_id and s.compra_id = p_compra and t.estado = 'confirmada')
$$;

create or replace function public.ali_autorizar_reembolso(p_compra uuid, p_cuenta_papa uuid)
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
  if v_s.reclasificacion_movimiento_id is not null then
    raise exception using errcode = '22023', message = 'El gasto ya se reclasificó al libro de Papá: no hay reembolso que autorizar.';
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

create or replace function public.ali_detalle_reembolso(p_compra uuid)
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
  select v_out || jsonb_build_object('reclasificacion', (
           select jsonb_build_object('movimiento_papa_id', s.reclasificacion_movimiento_id,
                                     'anulado_por_comprador', exists (select 1 from public.fin_movimientos a
                                                                       where a.hogar_id = v_c.hogar_id
                                                                         and a.anula_a = v_c.movimiento_id))
             from public.ali_solicitudes_pago s
            where s.compra_id = v_c.id and s.reclasificacion_movimiento_id is not null
            order by s.intento desc limit 1))
    into v_out;
  return v_out;
end
$$;


-- 2. Reclasificar (albacea): el gasto pasa al libro de Papá.
create function public.ali_reclasificar_gasto(p_compra uuid, p_cuenta_papa uuid)
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
  v_titular uuid;
  v_cuenta  public.fin_cuentas%rowtype;
  v_gasto   uuid;
  v_nombre  text;
  v_mov     uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_c from public.ali_compras c where c.id = p_compra for update;
  if not found or v_c.cuenta <> 'papa' then
    raise exception using errcode = 'P0002', message = 'La compra de Papá no existe.';
  end if;
  v_papa := public.ali_libro_papa(v_c.hogar_id);
  if v_papa is null or not public.fin_puede(v_papa, 'escribir') then
    raise exception using errcode = '42501', message = 'Solo el albacea reclasifica un gasto al libro de Papá.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s
   where s.compra_id = p_compra and s.intento = 2 and s.estado = 'rechazada';
  if not found then
    raise exception using errcode = '22023', message = 'Solo se reclasifica una compra rechazada dos veces.';
  end if;
  if v_c.estado_pago <> 'movimiento' then
    raise exception using errcode = '22023', message = 'Primero quien compró registra su gasto.';
  end if;
  if v_s.reclasificacion_movimiento_id is not null then
    raise exception using errcode = '22023', message = 'El gasto ya se reclasificó.';
  end if;
  if v_s.transferencia_id is not null and exists (select 1 from public.fin_transferencias t
       where t.id = v_s.transferencia_id and t.estado in ('pendiente', 'confirmada')) then
    raise exception using errcode = '22023', message = 'Hay un reembolso por transferencia activo: no se reclasifica.';
  end if;
  select * into v_cuenta from public.fin_cuentas c where c.hogar_id = v_c.hogar_id and c.id = p_cuenta_papa and c.libro_id = v_papa;
  if not found or v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'La cuenta de pago es una cuenta de dinero activa del libro de Papá.';
  end if;
  select l.titular_id into v_titular from public.fin_libros l where l.id = v_papa;
  v_gasto := public.ali7_cuenta_gasto_por_omision(v_c.hogar_id);
  if v_gasto is null then
    raise exception using errcode = '22023', message = 'No hay una cuenta de gasto de Alimentación.';
  end if;
  select i.nombre into v_nombre from public.ali_ingredientes i where i.hogar_id = v_c.hogar_id and i.id = v_c.ingrediente_id;
  v_mov := public.ali7_registrar_gasto(v_c.hogar_id, p_cuenta_papa, v_gasto, v_s.monto_centavos,
             'Compra de la lista reclasificada: ' || coalesce(v_nombre, 'compra'), v_titular,
             'Gasto de quien compró (rechazado dos veces) reclasificado al libro de Papá');
  update public.ali_solicitudes_pago set reclasificacion_movimiento_id = v_mov where id = v_s.id;
  return v_mov;
end
$$;
comment on function public.ali_reclasificar_gasto(uuid, uuid) is
  'Opción B (albacea): el gasto de quien compró (rechazado dos veces) pasa al libro de Papá, pagado desde una cuenta suya. Quien compró anula el suyo con ali_anular_gasto_propio.';
revoke all on function public.ali_reclasificar_gasto(uuid, uuid) from public, anon, service_role;
grant execute on function public.ali_reclasificar_gasto(uuid, uuid) to authenticated;

-- 3. Anular mi gasto (quien compró), después de la reclasificación: contraasiento en su libro personal.
create function public.ali_anular_gasto_propio(p_compra uuid, p_motivo text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_c       public.ali_compras%rowtype;
  v_s       public.ali_solicitudes_pago%rowtype;
  v_mov     public.fin_movimientos%rowtype;
  v_contra  uuid := gen_random_uuid();
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_c from public.ali_compras c where c.id = p_compra for update;
  if not found or v_c.cuenta <> 'papa' or v_c.movimiento_id is null then
    raise exception using errcode = 'P0002', message = 'No hay un gasto propio de esta compra.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s
   where s.compra_id = p_compra and s.intento = 2 and s.estado = 'rechazada';
  if not found or v_s.solicitada_por is distinct from v_persona then
    raise exception using errcode = '42501', message = 'Solo quien compró anula su gasto.';
  end if;
  if v_s.reclasificacion_movimiento_id is null then
    raise exception using errcode = '22023', message = 'Primero el albacea reclasifica el gasto al libro de Papá.';
  end if;
  if not public.fin_motivo_valido(p_motivo) then
    raise exception using errcode = '23514', message = 'Anular el gasto lleva un motivo.';
  end if;
  select * into v_mov from public.fin_movimientos m where m.hogar_id = v_c.hogar_id and m.id = v_c.movimiento_id;
  if exists (select 1 from public.fin_movimientos a where a.anula_a = v_mov.id) then
    raise exception using errcode = '22023', message = 'Ese gasto ya está anulado.';
  end if;
  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id, monto_centavos,
                                      nota, motivo, anula_a)
  values (v_contra, v_c.hogar_id, 'anulacion', (now() at time zone 'America/Mexico_City')::date, now(),
          v_mov.cuenta_destino_id, v_mov.cuenta_origen_id, v_mov.monto_centavos,
          'Gasto de compra reclasificado al libro de Papá', left(btrim(p_motivo), 200), v_mov.id);
  return v_contra;
end
$$;
comment on function public.ali_anular_gasto_propio(uuid, text) is
  'Opción B (quien compró): anula su gasto con un contraasiento en su libro, una vez que el albacea lo reclasificó al libro de Papá. Solo-agregar.';
revoke all on function public.ali_anular_gasto_propio(uuid, text) from public, anon, service_role;
grant execute on function public.ali_anular_gasto_propio(uuid, text) to authenticated;
