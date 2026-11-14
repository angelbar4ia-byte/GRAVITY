-- Alimentación, Fase 8 v1.1 (migración 20261139): tiendas editables y borrables, regresar compra con contraasiento,
-- compra rechazada que sigue en el historial, Casa solo ve la comida familiar y el menú del día de Papá, porciones por persona.
-- Seed: Ana dueña y albacea de Papá, Alex pareja, Carla familiar, Diana cuidadora, Casa, Marta maestra, Elena otro hogar.
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000010a1', 'b0000000-0000-4000-8000-000000000001', 'Arroz R', 'kg', 'Despensa', 2000),
  ('a7100000-0000-4000-8000-0000000010a2', 'b0000000-0000-4000-8000-000000000001', 'Leche R', 'l', 'Lácteos', 2500),
  ('a7100000-0000-4000-8000-0000000010a3', 'b0000000-0000-4000-8000-000000000001', 'Pan R', 'pza', 'Panadería', 1000);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000010b1', 'b0000000-0000-4000-8000-000000000001', 'Mercado'),
  ('a7500000-0000-4000-8000-0000000010b2', 'b0000000-0000-4000-8000-000000000001', 'Super'),
  ('a7500000-0000-4000-8000-0000000010b3', 'b0000000-0000-4000-8000-000000000001', 'Sin uso'),
  ('a7500000-0000-4000-8000-0000000010b9', 'b0000000-0000-4000-8000-000000000002', 'Tienda del vecino');

-- ---------------------------------------------------------------- tiendas: editar
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', '  Abarrotes Lupita ') ->> 'nombre', 'Abarrotes Lupita', 'La dueña edita el nombre (sin espacios sobrantes)');
select pruebas.igual(public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'ABARROTES LUPITA') ->> 'nombre', 'ABARROTES LUPITA', 'Cambiar solo mayúsculas de la misma tienda se permite');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'mercado')$$, 'El nombre es único sin distinguir mayúsculas', '23505');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', '   ')$$, 'Nombre vacío', '22023');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', repeat('x', 61))$$, 'Más de 60', '22023');
select pruebas.ok(public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', repeat('x', 60)) is not null, 'Exactamente 60 sí');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'Sin uso') ->> 'nombre', 'Sin uso', 'La pareja también edita');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'X')$$, 'La familiar ni ve la tienda', 'P0002');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b3')$$, 'La cuidadora no borra', 'P0002');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'X')$$, 'Casa no edita', 'P0002');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'X')$$, 'La maestra lee, no edita', '42501');
select pruebas.falla($$select public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b3')$$, '… ni borra', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'X')$$, 'Otro hogar no toca mis tiendas', 'P0002');
select pruebas.falla($$select public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b3')$$, '… ni las borra', 'P0002');
select pruebas.como_anon();
select pruebas.falla($$select public.ali_editar_tienda('a7500000-0000-4000-8000-0000000010b3', 'X')$$, 'anon no ejecuta (editar)', '42501');
select pruebas.falla($$select public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b3')$$, 'anon no ejecuta (borrar)', '42501');
select pruebas.falla($$select public.ali_regresar_compra(gen_random_uuid(), 'Motivo')$$, 'anon no ejecuta (regresar)', '42501');

-- ---------------------------------------------------------------- compras para las pruebas
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000010a1', 2) is not null, 'Preparación: arroz en la lista de la dueña');
select pruebas.igual((select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1),
  5000, 'c3000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000010b1')) ->> 'estado_pago', 'movimiento', 'La dueña compra arroz en Mercado');

select pruebas.como_postgres();
create temp table _o as select c.id as compra, c.movimiento_id as mov, h.id as hist from public.ali_compras c
  join public.ali_precios_historial h on h.compra_id = c.id where c.cuenta = 'dueno' and c.comprado;
grant select on _o to public;
select pruebas.como('ana@ejemplo.test');
-- ---------------------------------------------------------------- tiendas: borrar (con y sin compras)
select pruebas.igual(public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b1'), 'desactivada', 'Una tienda con compras se DESACTIVA en lugar de borrarse');
select pruebas.ok((select not activa from public.ali_tiendas where id = 'a7500000-0000-4000-8000-0000000010b1'), '… sigue en la lista, desactivada');
select pruebas.igual(public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b1'), 'desactivada', 'Repetir no la borra');
select pruebas.igual(public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b3'), 'borrada', 'Una tienda sin compras se borra');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tiendas where id = 'a7500000-0000-4000-8000-0000000010b3'$$), 0, '… y ya no existe');
select pruebas.falla($$select public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b3')$$, 'Borrar una inexistente', 'P0002');
select pruebas.ok((select (public.ali_tienda_activa('a7500000-0000-4000-8000-0000000010b1', true) ->> 'activa')::boolean), 'Mercado se reactiva para seguir comprando');

-- ---------------------------------------------------------------- regresar compra: reglas y efectos
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where tipo = 'anulacion'$$), 0, 'Antes: ninguna anulación');
select pruebas.falla($$select public.ali_regresar_compra((select compra from _o), '  ')$$, 'Regresar lleva motivo', '23514');
select pruebas.falla($$select public.ali_regresar_compra((select compra from _o), 'ab')$$, 'El motivo de 2 caracteres no vale', '23514');
select pruebas.falla($$select public.ali_regresar_compra(gen_random_uuid(), 'Me equivoqué')$$, 'Compra inexistente', 'P0002');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_regresar_compra((select compra from _o), 'Me equivoqué')$$,
  'La pareja no regresa la compra de la lista del dueño', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_regresar_compra('a7300000-0000-4000-8000-000000000000', 'Me equivoqué')$$, 'La familiar no regresa compras', 'P0002');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_regresar_compra((select compra from _o), 'Me equivoqué')$$, 'La maestra no regresa compras', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_regresar_compra((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1), 'Me equivoqué')$$, 'No se regresa una compra pendiente', 'P0002');

select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select ((public.ali_regresar_compra((select compra from _o), 'Marqué la compra equivocada')) ->> 'contraasiento_id') is not null), 'La dueña regresa su compra');
select pruebas.ok((select not comprado and comprado_en is null and monto_centavos is null and estado_pago = 'sin_pago' and movimiento_id is null and tienda_id is null
                     from public.ali_compras where id = (select compra from _o)), 'La compra vuelve a pendiente');
select pruebas.ok((select a.tipo = 'anulacion' and a.anula_a = (select mov from _o) and a.monto_centavos = o.monto_centavos
                          and a.cuenta_origen_id = o.cuenta_destino_id and a.cuenta_destino_id = o.cuenta_origen_id and a.motivo = 'Marqué la compra equivocada'
                     from public.fin_movimientos a join public.fin_movimientos o on o.id = a.anula_a), 'El dinero se revierte con un contraasiento invertido, con el motivo');
select pruebas.ok(exists (select 1 from public.fin_movimientos where id = (select mov from _o) and tipo = 'gasto'), 'El movimiento original NO se borra (solo agregar)');
select pruebas.ok((select revertida and revertida_en is not null and revertida_por = pruebas.id_persona('ana@ejemplo.test') and precio_centavos = 2500
                          and (original ->> 'monto_centavos')::bigint = 5000 and original ->> 'tienda_id' = 'a7500000-0000-4000-8000-0000000010b1'
                     from public.ali_precios_historial where id = (select hist from _o)), 'La fila de precio real NO se borra: queda revertida con la compra original');
select pruebas.ok((select cantidad = 0 from public.ali_despensa where cuenta = 'dueno' and ingrediente_id = 'a7100000-0000-4000-8000-0000000010a1'), 'El inventario baja lo comprado');
select pruebas.ok((select precio_real_centavos is null and precio_es_base from public.ali_ingredientes where id = 'a7100000-0000-4000-8000-0000000010a1'),
  'El precio real del ingrediente vuelve al base (no queda otra compra vigente)');
select pruebas.ok((select accion = 'alimentacion.regresar_compra' and tabla = 'ali_compras' and registro_id = (select compra::text from _o)
                          and detalle::text !~ '[0-9]{4}' and not (detalle ? 'monto_centavos')
                     from public.bitacora where accion = 'alimentacion.regresar_compra'), 'Queda un registro en la bitácora, sin montos');
select pruebas.falla($$select public.ali_regresar_compra((select compra from _o), 'Otra vez')$$, 'Ya pendiente, no se regresa dos veces', '22023');
select pruebas.como_postgres();
select pruebas.falla($$update public.ali_precios_historial set precio_centavos = 1$$, 'El historial de precios sigue siendo solo agregar', '42501');
select pruebas.falla($$delete from public.ali_precios_historial$$, '… no se borra', '42501');
select pruebas.falla($$update public.ali_precios_historial set revertida = false, revertida_en = null, original = null$$, '… ni se desmarca', '42501');
-- La compra original sigue en el historial, marcada, y no suma.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select count(*) = 1 and bool_and(revertida and tienda = 'Mercado' and gasto_centavos = 5000 and cantidad = 2 and precio_unitario_centavos = 2500)
                     from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)), 'El historial conserva la compra original (marcada revertida)');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tienda')$$), 0, 'Pero el resumen no suma una compra regresada');
-- Se puede marcar otra vez (con otro precio) y el historial queda con las dos filas.
select pruebas.igual((select public.ali_marcar_comprada((select compra from _o), 4800, 'c3000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000010b2')) ->> 'precio_real_centavos', '2400',
  'La compra se marca de nuevo (Super, 48.00)');
select pruebas.ok((select count(*) = 2 and count(*) filter (where revertida) = 1 and sum(gasto_centavos) filter (where not revertida) = 4800
                     from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)), 'Historial: la original (revertida) y la nueva');
select pruebas.igual((select sum(gasto_centavos)::bigint from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')), 4800::bigint, 'El resumen suma solo la vigente');
select pruebas.como_postgres();
select pruebas.falla($$update public.ali_compras set comprado = false where comprado$$, 'Nadie más desmarca compras por fuera de la función', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_borrar_tienda('a7500000-0000-4000-8000-0000000010b1'), 'desactivada', 'Mercado solo tiene la compra regresada: sigue sin borrarse');

-- Compra de la pareja: solo ella la regresa.
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000010a3', 1) is not null, 'Preparación: pan en la lista de la pareja');
select pruebas.ok((select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'pareja' and not comprado limit 1),
  1200, 'c4000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000010b2')) is not null, 'La pareja compra pan');
select pruebas.como_postgres();
create temp table _p as select id as compra from public.ali_compras where cuenta = 'pareja' and comprado;
grant select on _p to public;
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_regresar_compra((select compra from _p), 'Me equivoqué')$$, 'La dueña no regresa la compra de la lista de la pareja', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_regresar_compra((select id from public.ali_compras where cuenta = 'pareja' and comprado limit 1), 'Era otro pan') is not null, 'La pareja regresa la suya');

-- ---------------------------------------------------------------- compra de Papá: solicitud sin pagar vuelve (se retira de la cola del albacea)
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000010a2', 2) is not null, 'Preparación: una compra de Papá por marcar (la pareja la agrega a su lista)');
select pruebas.como_postgres();
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000010c1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000010a2', 2, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000010c2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000010a3', 1, pruebas.id_persona('ana@ejemplo.test'));
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000010c1', 1050, p_tienda => 'a7500000-0000-4000-8000-0000000010b2')) ->> 'estado_pago', 'solicitud', 'La pareja marca la compra de Papá: solicitud al albacea');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000010c2', 800, p_tienda => 'a7500000-0000-4000-8000-0000000010b2')) ->> 'estado_pago', 'solicitud', 'y otra');
select pruebas.ok((public.ali_regresar_compra('a7300000-0000-4000-8000-0000000010c1', 'La compré de más') ->> 'solicitud_retirada')::boolean, 'Regresarla sin pagar retira la solicitud, sin contraasiento');
select pruebas.ok((select estado = 'revertida' and resuelta_en is not null from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000010c1'), 'La solicitud queda revertida (ya no pendiente)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where tipo = 'anulacion' and nota is not null and anula_a in (select movimiento_id from public.ali_compras where cuenta = 'papa')$$), 0, 'Sin dinero movido, no hay contraasiento');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago where estado = 'pendiente'$$), 1, 'El albacea solo tiene pendiente la otra solicitud');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000010c1', 1100, p_tienda => 'a7500000-0000-4000-8000-0000000010b2')) ->> 'estado_pago', 'solicitud', 'Marcada otra vez, abre una solicitud nueva');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago where estado = 'pendiente'$$), 2, '… y el albacea vuelve a tener dos pendientes');

-- Papá pagada del libro de Papá: solo el albacea regresa y se hace contraasiento en ese libro.
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000010c2' and estado = 'pendiente'),
  true, 'c6000000-0000-4000-8000-000000000002') is not null, 'El albacea aprueba y paga la solicitud de la otra compra');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_regresar_compra('a7300000-0000-4000-8000-0000000010c2', 'La pagó el albacea')$$, 'La pareja no regresa una compra de Papá ya pagada del libro de Papá', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((public.ali_regresar_compra('a7300000-0000-4000-8000-0000000010c2', 'Compra duplicada') ->> 'contraasiento_id') is not null, 'La albacea la regresa con contraasiento');
select pruebas.ok((select a.tipo = 'anulacion' and a.en_nombre_de is not distinct from o.en_nombre_de and a.monto_centavos = 800
                     from public.fin_movimientos a join public.fin_movimientos o on o.id = a.anula_a
                    where o.cuenta_origen_id = 'c6000000-0000-4000-8000-000000000002'), 'El contraasiento va en el libro de Papá, en su nombre');
select pruebas.ok((select estado = 'revertida' from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000010c2'
                    order by resuelta_en desc limit 1), 'La solicitud pagada queda revertida');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_precios_historial$$), 0, 'La cuidadora no lee el historial de precios');

-- ---------------------------------------------------------------- compra rechazada por el albacea: SIGUE en el historial
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null) where cuenta = 'papa' and not revertida$$), 1,
  'Antes de rechazar, la compra de Papá pendiente (leche) está en el historial');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000010c1' and estado = 'pendiente'),
  false, null, null, 'Ya compré eso en la semana') is null, 'El albacea rechaza el pago');
select pruebas.ok((select estado_pago = 'rechazada' and comprado and monto_centavos = 1100 and tienda_id is not null
                     from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000010c1'), 'La compra solo cambia su estado de pago: sigue marcada, con su monto y su tienda');
select pruebas.ok((select count(*) = 1 and bool_and(precio_unitario_centavos = 550 and gasto_centavos = 1100)
                     from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, 'a7100000-0000-4000-8000-0000000010a2') where not revertida), 'La compra rechazada sigue en ali_historial_compras con su precio real');
select pruebas.ok(not exists (select 1 from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')
                    where clave = 'a7100000-0000-4000-8000-0000000010a2'), '… pero no suma en el resumen de Papá (es gasto de quien compró, v1.4)');
select pruebas.ok((select precio_real_centavos = 550 from public.ali_ingredientes where id = 'a7100000-0000-4000-8000-0000000010a2'), 'El precio real del ingrediente se conserva');

-- ---------------------------------------------------------------- porciones recomendadas por persona (menú de dueño y pareja)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id, porciones_recomendadas)
  values ('b0000000-0000-4000-8000-000000000001', 'pareja', date_trunc('week', current_date)::date, 0, 'comida', 'a1000000-0000-4000-8000-000000000001', '{"dueno": 1.5, "pareja": 1}')$$), 1,
  'La dueña guarda porciones recomendadas por persona en el menú compartido');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id, porciones_recomendadas)
  values ('b0000000-0000-4000-8000-000000000001', 'pareja', date_trunc('week', current_date)::date, 1, 'comida', 'a1000000-0000-4000-8000-000000000001', '{"abuelo": 1}')$$, 'Solo dueño y pareja', '22023');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id, porciones_recomendadas)
  values ('b0000000-0000-4000-8000-000000000001', 'pareja', date_trunc('week', current_date)::date, 1, 'comida', 'a1000000-0000-4000-8000-000000000001', '{"dueno": 50}')$$, 'Entre 0.25 y 20', '22023');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id, porciones_recomendadas)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', date_trunc('week', current_date)::date, 1, 'comida', 'a1000000-0000-4000-8000-000000000001', '{"dueno": 1}')$$, 'El menú de Papá no lleva porciones por persona', '22023');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok((select (porciones_recomendadas ->> 'dueno')::numeric = 1.5 and (porciones_recomendadas ->> 'pareja')::numeric = 1 from public.ali_menu where menu = 'pareja' and porciones_recomendadas <> '{}'::jsonb),
  'La pareja ve el mismo menú con las porciones de cada quien');

-- ---------------------------------------------------------------- Casa: solo la comida familiar y el menú del día de Papá
select pruebas.como_postgres();
insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id)
select 'b0000000-0000-4000-8000-000000000001', 'papa', h - (extract(isodow from h)::int - 1), extract(isodow from h)::int - 1, 'comida', 'a1000000-0000-4000-8000-000000000001'
  from (select (now() at time zone 'America/Mexico_City')::date as h) d;
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Cena del jueves', array['a1000000-0000-4000-8000-000000000001']::uuid[], 'casa', current_date + 3) is not null,
  'La familiar propone la comida familiar');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_proponer_alternativa((select id from public.ali_votaciones where titulo = 'Cena del jueves'), 'Cena ligera', array['a1000000-0000-4000-8000-000000000002']::uuid[]) is not null,
  'La pareja da la alternativa');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votaciones$$) + pruebas.cuenta($$select * from public.ali_votacion_opciones$$)
  + pruebas.cuenta($$select * from public.ali_opcion_platillos$$) + pruebas.cuenta($$select * from public.ali_votos$$), 0, 'Con la votación abierta Casa no ve nada del plan familiar');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_votar((select id from public.ali_votaciones where titulo = 'Cena del jueves'), (select id from public.ali_votacion_opciones where titulo = 'Cena del jueves')) is not null, 'La dueña vota');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_votar((select id from public.ali_votaciones where titulo = 'Cena del jueves'), (select id from public.ali_votacion_opciones where titulo = 'Cena del jueves')) is not null, '… y la familiar');
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour' where titulo = 'Cena del jueves';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(null), 1, 'El servidor cierra la votación');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votaciones$$), 1, 'Cerrada, Casa ve la comida familiar aprobada');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votacion_opciones$$), 1, '… solo la opción ganadora');
select pruebas.ok((select titulo = 'Cena del jueves' and platillos <> '{}' from public.ali_votacion_opciones), '… con los nombres de sus platillos');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_opcion_platillos$$), 1, '… y sus platillos');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votos$$), 0, 'Casa no ve los votos');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_platillos$$) + pruebas.cuenta($$select * from public.ali_menu$$), 0, 'Casa no lee el catálogo de platillos ni los menús directo');
select pruebas.igual((select count(*)::int from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001')), 1, 'Casa recibe el menú del día de Papá');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votacion_opciones$$), 2, 'La dueña sigue viendo las dos propuestas');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votos$$), 2, '… y los votos');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votaciones$$), 0, 'Otro hogar no ve nada');

rollback;
