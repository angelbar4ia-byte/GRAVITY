-- Alimentación, Fase 8 v1.2 (migración 20261140): respuestas del dueño (docs/specs/fase-8-alimentacion-ampliaciones.md, 2c).
--   1) Regresar una compra de Papá: la solicitud se retira de la cola del albacea (estado 'revertida'); YA estaba en 20261139
--      (ali_regresar_compra) y la prueba 110 lo cubre. Aquí solo se limpia la cuenta de rechazo al regresar.
--   2) Compra rechazada por el albacea: la compra se queda en el historial con su precio real y vuelve a una cuenta del libro de Papá:
--      por omisión la de efectivo; el albacea puede elegir otra con p_cuenta_gasto (del mismo libro, 22023 si no).
--      La firma de ali_resolver_solicitud_pago NO cambia (p_cuenta_gasto ya existía para aprobar). No se mueve dinero.

alter table public.ali_compras add column cuenta_rechazo_id uuid;
alter table public.ali_compras add constraint ali_compras_cuenta_rechazo_fk
  foreign key (hogar_id, cuenta_rechazo_id) references public.fin_cuentas (hogar_id, id);
comment on column public.ali_compras.cuenta_rechazo_id is
  'Solo compras de Papá rechazadas por el albacea: la cuenta del libro de Papá a la que vuelve la compra (efectivo por omisión, o la que el albacea eligió). Sin movimiento de dinero.';

-- La guardia deja que ali_resolver_solicitud_pago escriba la cuenta al rechazar y que el regreso la limpie.
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

-- ali_regresar_compra: igual que en 20261139, y además limpia la cuenta de rechazo.
create or replace function public.ali_regresar_compra(p_compra uuid, p_motivo text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_c       public.ali_compras%rowtype;
  v_mov     public.fin_movimientos%rowtype;
  v_contra  uuid;
  v_sol_ret boolean := false;
  v_original jsonb;
  v_h       uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_c from public.ali_compras c where c.id = p_compra for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'La compra no existe.';
  end if;
  -- Quien puede marcar la compra de esa lista puede regresarla (dueño y pareja; cada quien la suya).
  if not public.ali_puede7(v_c.hogar_id, 'compras', v_c.cuenta, 'comprar') then
    raise exception using errcode = '42501', message = 'Tu cuenta no regresa compras de esta lista.';
  end if;
  if not v_c.comprado then
    raise exception using errcode = '22023', message = 'La compra no está marcada.';
  end if;
  if not public.fin_motivo_valido(p_motivo) then
    raise exception using errcode = '23514', message = 'Regresar una compra lleva un motivo.';
  end if;

  -- El dinero: contraasiento (anulación) del movimiento; nunca se borra nada. Lo escribe quien puede escribir en ese libro
  -- (la compra de Papá pagada del libro de Papá solo la regresa el albacea: 42501 del libro).
  if v_c.movimiento_id is not null then
    select * into v_mov from public.fin_movimientos m where m.hogar_id = v_c.hogar_id and m.id = v_c.movimiento_id;
    if not exists (select 1 from public.fin_movimientos a where a.anula_a = v_mov.id) then
      v_contra := gen_random_uuid();
      insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id, monto_centavos,
                                          en_nombre_de, nota, motivo, anula_a)
      values (v_contra, v_c.hogar_id, 'anulacion', (now() at time zone 'America/Mexico_City')::date, now(),
              v_mov.cuenta_destino_id, v_mov.cuenta_origen_id, v_mov.monto_centavos,
              v_mov.en_nombre_de, 'Compra de la lista regresada', left(btrim(p_motivo), 200), v_mov.id);
    end if;
  end if;

  -- La solicitud al albacea (si hubo) sale de su cola: la compra vuelve a pendiente y, si se marca otra vez, abre una nueva.
  update public.ali_solicitudes_pago
     set estado = 'revertida', resuelta_por = v_persona, resuelta_en = now(), motivo = left(btrim(p_motivo), 200)
   where compra_id = v_c.id and estado <> 'revertida'
  returning true into v_sol_ret;
  v_sol_ret := coalesce(v_sol_ret, false);

  -- El historial de precios conserva la compra original.
  v_original := jsonb_build_object('comprado_en', v_c.comprado_en, 'monto_centavos', v_c.monto_centavos, 'cantidad', v_c.cantidad,
                                   'unidad', coalesce(v_c.unidad, (select i.unidad from public.ali_ingredientes i where i.hogar_id = v_c.hogar_id and i.id = v_c.ingrediente_id)),
                                   'tienda_id', v_c.tienda_id, 'cuenta', v_c.cuenta, 'movimiento_id', v_c.movimiento_id, 'contraasiento_id', v_contra);
  select h.id into v_h from public.ali_precios_historial h where h.compra_id = v_c.id and not h.revertida order by h.registrado_en desc limit 1;
  if v_h is not null then
    update public.ali_precios_historial
       set revertida = true, revertida_en = now(), revertida_por = v_persona, original = v_original || jsonb_build_object('precio_centavos', precio_centavos)
     where id = v_h;
    -- El precio real del ingrediente vuelve al de su última compra vigente (o a "solo base" si no queda ninguna).
    update public.ali_ingredientes i
       set precio_real_centavos = (select h.precio_centavos from public.ali_precios_historial h
                                    where h.hogar_id = i.hogar_id and h.ingrediente_id = i.id and not h.revertida
                                    order by h.registrado_en desc, h.id desc limit 1),
           precio_real_en = (select h.registrado_en from public.ali_precios_historial h
                              where h.hogar_id = i.hogar_id and h.ingrediente_id = i.id and not h.revertida
                              order by h.registrado_en desc, h.id desc limit 1)
     where i.hogar_id = v_c.hogar_id and i.id = v_c.ingrediente_id;
  end if;

  -- El inventario baja lo que subió con la compra (sin pasar de cero).
  update public.ali_despensa set cantidad = greatest(0, cantidad - v_c.cantidad)
   where hogar_id = v_c.hogar_id and cuenta = v_c.cuenta and ingrediente_id = v_c.ingrediente_id;

  perform set_config('gravity.ali_regreso', v_c.id::text, true);
  update public.ali_compras
     set comprado = false, comprado_en = null, comprado_por = null, monto_centavos = null, estado_pago = 'sin_pago',
         movimiento_id = null, tienda_id = null, cuenta_rechazo_id = null
   where id = v_c.id;
  perform set_config('gravity.ali_regreso', '', true);

  -- Bitácora sin montos ni nombres de producto (D3).
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_c.hogar_id, v_persona, 'alimentacion.regresar_compra', 'ali_compras', v_c.id::text,
          jsonb_build_object('cuenta', v_c.cuenta, 'con_contraasiento', v_contra is not null, 'solicitud_retirada', v_sol_ret));
  return jsonb_build_object('compra_id', v_c.id, 'contraasiento_id', v_contra, 'solicitud_retirada', v_sol_ret);
end
$$;

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
  v_rechazo uuid;
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
    -- v1.2: la compra vuelve a la cuenta de efectivo del libro de Papá, o a otra cuenta de ese libro que el albacea elija.
    if p_cuenta_gasto is not null then
      if not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_s.hogar_id and c.id = p_cuenta_gasto and c.libro_id = v_libro) then
        raise exception using errcode = '22023', message = 'La cuenta elegida debe ser una cuenta del libro de Papá.';
      end if;
      v_rechazo := p_cuenta_gasto;
    else
      select c.id into v_rechazo from public.fin_cuentas c
       where c.hogar_id = v_s.hogar_id and c.libro_id = v_libro and c.tipo = 'efectivo' and c.estado = 'activa'
       order by c.creada_en, c.id limit 1;
    end if;
    update public.ali_solicitudes_pago set estado = 'rechazada', resuelta_por = v_persona, resuelta_en = now(), motivo = left(p_motivo, 200) where id = v_s.id;
    update public.ali_compras set estado_pago = 'rechazada', cuenta_rechazo_id = v_rechazo where id = v_s.compra_id;
  end if;
  return v_mov;
end
$$;
comment on function public.ali_resolver_solicitud_pago(uuid, boolean, uuid, uuid, text) is
  'D19: el albacea aprueba (registra el gasto en el libro de Papá, en su nombre y con motivo; devuelve el movimiento) o rechaza (con motivo). '
  'Al rechazar, la compra sigue en el historial y vuelve a la cuenta de efectivo del libro de Papá, o a la cuenta de ese libro en p_cuenta_gasto (22023 si es de otro libro); no mueve dinero.';
