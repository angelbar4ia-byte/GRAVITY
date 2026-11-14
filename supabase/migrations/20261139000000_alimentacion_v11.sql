-- =============================================================================
-- GRAVITY · Alimentación Fase 8 v1.1 (respuestas del dueño, 9/nov/2026)
-- =============================================================================
-- Especificación: docs/specs/fase-8-alimentacion-ampliaciones.md (2b y 3). Migración hacia adelante.
--   1) Tiendas editables y borrables: ali_editar_tienda y ali_borrar_tienda (con compras, la desactiva).
--   2) Regresar una compra: ali_regresar_compra. La compra vuelve a pendiente; el dinero se revierte con un CONTRAASIENTO (anulación)
--      en el libro; la fila de precio real del historial no se borra: queda marcada como revertida y conserva la compra original.
--   3) Compra rechazada por el albacea: NO sale del historial. Rechazar solo cambia el estado de pago (estado_pago = 'rechazada':
--      el albacea no la paga del libro de Papá; se paga con otra cuenta). La compra sigue con su precio real en ali_historial_compras.
--      No hay cambio de código: queda documentado y probado.
--   4) Platillos: Casa los lee solo en la comida familiar (plan familiar CERRADO, solo la opción ganadora) y en el menú del día de Papá
--      (ali_menu_del_dia_papa, ya limitado a hoy). El menú de dueño y pareja es uno solo (ali_menu.menu = 'pareja') con porciones
--      recomendadas por persona (ali_menu.porciones_recomendadas).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tiendas: editar y borrar
-- -----------------------------------------------------------------------------
create function public.ali_editar_tienda(p_tienda uuid, p_nombre text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_t      public.ali_tiendas%rowtype;
begin
  if public.persona_actual() is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_t from public.ali_tiendas t where t.id = p_tienda for update;
  if not found or coalesce(public.ali_cuenta_de(v_t.hogar_id), '') not in ('dueno', 'pareja', 'maestra') then
    raise exception using errcode = 'P0002', message = 'La tienda no existe.';
  end if;
  if public.ali_cuenta_de(v_t.hogar_id) not in ('dueno', 'pareja') then
    raise exception using errcode = '42501', message = 'Tu cuenta no edita tiendas.';
  end if;
  if char_length(v_nombre) not between 1 and 60 then
    raise exception using errcode = '22023', message = 'El nombre de la tienda lleva de 1 a 60 caracteres.';
  end if;
  if exists (select 1 from public.ali_tiendas o
              where o.hogar_id = v_t.hogar_id and o.id <> v_t.id and lower(btrim(o.nombre)) = lower(v_nombre)) then
    raise exception using errcode = '23505', message = 'Ya hay una tienda con ese nombre.';
  end if;
  update public.ali_tiendas set nombre = v_nombre where id = v_t.id returning * into v_t;
  return jsonb_build_object('id', v_t.id, 'nombre', v_t.nombre, 'activa', v_t.activa);
end
$$;
comment on function public.ali_editar_tienda(uuid, text) is
  'Cambia el nombre de una tienda (dueño y pareja). Único por hogar sin distinguir mayúsculas (23505 si otra ya lo usa); 22023 fuera de 1 a 60; '
  'P0002 si no existe o no se lee; 42501 la maestra. Las compras ya hechas siguen apuntando a la misma tienda (con el nombre nuevo).';

create function public.ali_borrar_tienda(p_tienda uuid)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_t public.ali_tiendas%rowtype;
begin
  if public.persona_actual() is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_t from public.ali_tiendas t where t.id = p_tienda for update;
  if not found or coalesce(public.ali_cuenta_de(v_t.hogar_id), '') not in ('dueno', 'pareja', 'maestra') then
    raise exception using errcode = 'P0002', message = 'La tienda no existe.';
  end if;
  if public.ali_cuenta_de(v_t.hogar_id) not in ('dueno', 'pareja') then
    raise exception using errcode = '42501', message = 'Tu cuenta no borra tiendas.';
  end if;
  -- Con compras (también las regresadas, que conservan su tienda en el historial) no se borra: se desactiva.
  if exists (select 1 from public.ali_compras c where c.hogar_id = v_t.hogar_id and c.tienda_id = v_t.id)
     or exists (select 1 from public.ali_precios_historial h
                 where h.hogar_id = v_t.hogar_id and h.revertida and h.original ->> 'tienda_id' = v_t.id::text) then
    update public.ali_tiendas set activa = false where id = v_t.id;
    return 'desactivada';
  end if;
  delete from public.ali_tiendas where id = v_t.id;
  return 'borrada';
end
$$;
comment on function public.ali_borrar_tienda(uuid) is
  'Borra una tienda sin compras (devuelve borrada) o, si tiene compras (aun regresadas), la desactiva en su lugar (devuelve desactivada) para no dejar el '
  'historial sin tienda. Solo dueño y pareja; P0002 si no existe o no se lee; 42501 la maestra.';

-- -----------------------------------------------------------------------------
-- 2. Regresar compras: marcas en el historial de precios y en las solicitudes
-- -----------------------------------------------------------------------------
-- El historial sigue siendo solo-agregar: la única edición permitida es marcar una fila como revertida (una vez), sin tocar lo demás.
alter table public.ali_precios_historial
  add column revertida boolean not null default false,
  add column revertida_en timestamptz,
  add column revertida_por uuid references public.personas (id),
  add column original jsonb check (original is null or (jsonb_typeof(original) = 'object' and octet_length(original::text) <= 4096)),
  add constraint ali_precios_historial_revertida_coherente check (revertida = (revertida_en is not null and original is not null));
comment on column public.ali_precios_historial.revertida is
  'Verdadero si la compra se regresó (ali_regresar_compra). La fila no se borra: original guarda la compra original (fecha, monto, cantidad, unidad, tienda, cuenta, movimiento y contraasiento).';

create function public.ali_precios_guardia()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libres text[] := array['revertida', 'revertida_en', 'revertida_por', 'original'];
begin
  if tg_op = 'UPDATE' and not old.revertida and new.revertida
     and (to_jsonb(new) - v_libres) = (to_jsonb(old) - v_libres) then
    return new;
  end if;
  raise exception using errcode = '42501',
    message = format('La tabla %I es de solo agregar: no se edita ni se borra (%s).', tg_table_name, tg_op),
    hint    = 'Solo se marca como revertida con ali_regresar_compra.';
end
$$;
drop trigger ali7_c_solo_agregar on public.ali_precios_historial;
create trigger ali7_c_solo_agregar before update or delete on public.ali_precios_historial
  for each row execute function public.ali_precios_guardia();
revoke execute on function public.ali_precios_guardia() from public, anon, authenticated, service_role;

-- Una solicitud de Papá puede quedar "revertida" (la compra se regresó): sale de la cola del albacea y la compra puede marcarse otra vez.
alter table public.ali_solicitudes_pago drop constraint ali_solicitudes_pago_estado_check;
alter table public.ali_solicitudes_pago add constraint ali_solicitudes_pago_estado_check
  check (estado in ('pendiente', 'pagada', 'rechazada', 'revertida'));
alter table public.ali_solicitudes_pago drop constraint ali_solicitudes_pago_una;
create unique index ali_solicitudes_pago_una on public.ali_solicitudes_pago (compra_id) where estado <> 'revertida';

-- La guardia de la compra deja pasar el regreso (y solo el regreso): la función lo avisa con una variable de la transacción.
create or replace function public.ali_compras_guardia()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libres text[] := array['estado_pago', 'movimiento_id'];
  v_regreso text[] := array['comprado', 'comprado_en', 'comprado_por', 'monto_centavos', 'estado_pago', 'movimiento_id', 'tienda_id'];
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

create function public.ali_regresar_compra(p_compra uuid, p_motivo text)
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
         movimiento_id = null, tienda_id = null
   where id = v_c.id;
  perform set_config('gravity.ali_regreso', '', true);

  -- Bitácora sin montos ni nombres de producto (D3).
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_c.hogar_id, v_persona, 'alimentacion.regresar_compra', 'ali_compras', v_c.id::text,
          jsonb_build_object('cuenta', v_c.cuenta, 'con_contraasiento', v_contra is not null, 'solicitud_retirada', v_sol_ret));
  return jsonb_build_object('compra_id', v_c.id, 'contraasiento_id', v_contra, 'solicitud_retirada', v_sol_ret);
end
$$;
comment on function public.ali_regresar_compra(uuid, text) is
  'Regresa una compra marcada a pendiente (dueño y pareja, cada quien la de su lista; motivo de 3 caracteres visibles, 23514 si no). El movimiento de dinero se '
  'revierte con un contraasiento (anulación) en su libro, sin borrar nada; la fila de ali_precios_historial queda marcada como revertida con la compra original; '
  'el inventario baja lo comprado; el precio real del ingrediente vuelve al de su última compra vigente. Una compra de Papá aún sin pagar retira su solicitud '
  '(estado revertida) de la cola del albacea; si ya se pagó del libro de Papá, solo el albacea la regresa (42501). Deja bitácora sin montos. '
  '22023 si no está marcada; P0002 si no existe.';

-- -----------------------------------------------------------------------------
-- 3. El historial conserva las compras regresadas (marcadas) y no las suma
-- -----------------------------------------------------------------------------
drop function public.ali_historial_compras(uuid, date, date, uuid, uuid);
create function public.ali_historial_compras(
  p_hogar_id uuid, p_desde date, p_hasta date, p_ingrediente uuid default null, p_tienda uuid default null)
returns table (
  compra_id uuid, fecha date, ingrediente_id uuid, ingrediente text, unidad text, tienda_id uuid, tienda text,
  cuenta text, precio_unitario_centavos bigint, cantidad numeric, gasto_centavos bigint, revertida boolean)
language plpgsql stable security invoker
set search_path = ''
as $$
begin
  if p_desde is not null and p_hasta is not null and p_desde > p_hasta then
    raise exception using errcode = '22023', message = 'El rango de fechas está al revés.';
  end if;
  return query
  with b as (
    select c.id as cid, h.id as hid, h.registrado_en, h.revertida as rev, c.ingrediente_id as ing, h.precio_centavos as precio,
           case when h.revertida then (h.original ->> 'comprado_en')::timestamptz else c.comprado_en end as cuando,
           case when h.revertida then (h.original ->> 'tienda_id')::uuid else c.tienda_id end as tid,
           case when h.revertida then h.original ->> 'unidad' else coalesce(c.unidad, i.unidad) end as und,
           case when h.revertida then h.original ->> 'cuenta' else c.cuenta end as cta,
           case when h.revertida then (h.original ->> 'cantidad')::numeric else c.cantidad end as cant,
           case when h.revertida then (h.original ->> 'monto_centavos')::bigint else c.monto_centavos end as monto,
           i.nombre as nombre_ing
      from public.ali_precios_historial h
      join public.ali_compras c on c.hogar_id = h.hogar_id and c.id = h.compra_id
      join public.ali_ingredientes i on i.hogar_id = c.hogar_id and i.id = c.ingrediente_id
     where h.hogar_id = p_hogar_id and (h.revertida or (c.comprado and c.monto_centavos is not null))
  )
  select b.cid, (b.cuando at time zone 'America/Mexico_City')::date, b.ing, b.nombre_ing, b.und, b.tid, coalesce(t.nombre, 'Sin tienda'),
         b.cta, b.precio, b.cant, b.monto, b.rev
    from b
    left join public.ali_tiendas t on t.hogar_id = p_hogar_id and t.id = b.tid
   where (p_desde is null or (b.cuando at time zone 'America/Mexico_City')::date >= p_desde)
     and (p_hasta is null or (b.cuando at time zone 'America/Mexico_City')::date <= p_hasta)
     and (p_ingrediente is null or b.ing = p_ingrediente)
     and (p_tienda is null or b.tid = p_tienda)
   order by 2 desc, b.cuando desc, b.hid;
end
$$;
comment on function public.ali_historial_compras(uuid, date, date, uuid, uuid) is
  'Compras reales marcadas con monto: fecha local, ingrediente, tienda ("Sin tienda" para las anteriores a la Fase 8), precio unitario real, cantidad y gasto '
  'en centavos. El precio base de supuesto no aparece. Filtros opcionales por ingrediente y tienda. Security invoker: lo que la cuenta lee de la lista. '
  'Fase 8 v1.1: una compra rechazada por el albacea sigue aquí (solo cambia su estado de pago); una compra regresada también, con revertida = true '
  '(los datos de la compra original) y ali_resumen_historial no la suma.';

-- El resumen solo suma lo vigente (no las regresadas).
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
    select * from public.ali_historial_compras(p_hogar_id, p_desde, p_hasta, p_ingrediente, p_tienda) x where not x.revertida
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

-- -----------------------------------------------------------------------------
-- 4. Casa y platillos; menú de dueño y pareja con porciones recomendadas
-- -----------------------------------------------------------------------------
-- Casa lee SOLO la comida familiar: el plan familiar (cuenta casa) ya CERRADO y su opción ganadora, con los nombres de sus platillos.
-- Nunca las votaciones abiertas, las opciones perdedoras, los votos ni el catálogo (ali_platillos). ali_puede7(..., 'votaciones', 'leer')
-- sigue siendo la puerta general (Casa pasa); el filtro por fila va en las políticas. El menú del día de Papá es la RPC ali_menu_del_dia_papa.
drop policy ali_votaciones_leer on public.ali_votaciones;
create policy ali_votaciones_leer on public.ali_votaciones for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer')
         and (public.ali_cuenta_de(hogar_id) <> 'casa' or (cuenta = 'casa' and estado = 'cerrada')));
drop policy ali_votacion_opciones_leer on public.ali_votacion_opciones;
create policy ali_votacion_opciones_leer on public.ali_votacion_opciones for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer')
         and (public.ali_cuenta_de(hogar_id) <> 'casa'
              or exists (select 1 from public.ali_votaciones v
                          where v.hogar_id = ali_votacion_opciones.hogar_id and v.id = ali_votacion_opciones.votacion_id
                            and v.cuenta = 'casa' and v.estado = 'cerrada' and v.ganadora_id = ali_votacion_opciones.id)));
drop policy ali_opcion_platillos_leer on public.ali_opcion_platillos;
create policy ali_opcion_platillos_leer on public.ali_opcion_platillos for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer')
         and (public.ali_cuenta_de(hogar_id) <> 'casa'
              or exists (select 1 from public.ali_votacion_opciones o join public.ali_votaciones v on v.hogar_id = o.hogar_id and v.id = o.votacion_id
                          where o.id = ali_opcion_platillos.opcion_id and v.cuenta = 'casa' and v.estado = 'cerrada' and v.ganadora_id = o.id)));
drop policy ali_votos_leer on public.ali_votos;
create policy ali_votos_leer on public.ali_votos for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer') and public.ali_cuenta_de(hogar_id) <> 'casa');

-- Porciones recomendadas por persona en el menú de dueño y pareja (un solo menú, 'pareja'): {"dueno": 1.5, "pareja": 1}.
alter table public.ali_menu add column porciones_recomendadas jsonb not null default '{}'::jsonb
  check (jsonb_typeof(porciones_recomendadas) = 'object' and octet_length(porciones_recomendadas::text) <= 256);
comment on column public.ali_menu.porciones_recomendadas is
  'Solo en el menú pareja (dueño y pareja comparten el mismo menú): porciones recomendadas por persona, {"dueno": n, "pareja": n} con n entre 0.25 y 20. En el menú de Papá siempre {}.';

create function public.ali_menu_porciones_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  r record;
begin
  if new.menu <> 'pareja' and new.porciones_recomendadas <> '{}'::jsonb then
    raise exception using errcode = '22023', message = 'Las porciones por persona son del menú de dueño y pareja.';
  end if;
  for r in select k.key, k.value from jsonb_each(new.porciones_recomendadas) k loop
    if r.key not in ('dueno', 'pareja') or jsonb_typeof(r.value) <> 'number' or (r.value #>> '{}')::numeric not between 0.25 and 20 then
      raise exception using errcode = '22023', message = 'Porciones recomendadas: dueno y pareja, de 0.25 a 20.';
    end if;
  end loop;
  return new;
end
$$;
create trigger ali8_b_porciones before insert or update on public.ali_menu
  for each row execute function public.ali_menu_porciones_validar();
revoke execute on function public.ali_menu_porciones_validar() from public, anon, authenticated, service_role;
grant insert (porciones_recomendadas), update (porciones_recomendadas) on public.ali_menu to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Privilegios
-- -----------------------------------------------------------------------------
revoke all on function public.ali_editar_tienda(uuid, text), public.ali_borrar_tienda(uuid), public.ali_regresar_compra(uuid, text),
  public.ali_historial_compras(uuid, date, date, uuid, uuid), public.ali_resumen_historial(uuid, date, date, text, text, uuid, uuid)
  from public, anon, service_role;
grant execute on function public.ali_editar_tienda(uuid, text), public.ali_borrar_tienda(uuid), public.ali_regresar_compra(uuid, text),
  public.ali_historial_compras(uuid, date, date, uuid, uuid), public.ali_resumen_historial(uuid, date, date, text, text, uuid, uuid)
  to authenticated;
