-- Alimentación, Fase 8 v1.2 (migración 20261140): compra de Papá rechazada por el albacea y regresar compra de Papá.
-- Seed: Ana dueña y albacea de Papá, Alex pareja. Libro de Papá: efectivo c6...02, banco c6...01. Cuenta de Ana: c3...02 (otro libro).
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000011a1', 'b0000000-0000-4000-8000-000000000001', 'Frijol Q', 'kg', 'Despensa', 3000);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000011b1', 'b0000000-0000-4000-8000-000000000001', 'Tienda Q');
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000011c1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000011a1', 1, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000011c2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000011a1', 2, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000011c3', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000011a1', 3, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000011c4', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000011a1', 4, pruebas.id_persona('ana@ejemplo.test'));
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000011c1', 3000, p_tienda => 'a7500000-0000-4000-8000-0000000011b1')) ->> 'estado_pago', 'solicitud', 'Preparación: solicitud 1');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000011c2', 6000, p_tienda => 'a7500000-0000-4000-8000-0000000011b1')) ->> 'estado_pago', 'solicitud', 'Preparación: solicitud 2');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000011c3', 9000, p_tienda => 'a7500000-0000-4000-8000-0000000011b1')) ->> 'estado_pago', 'solicitud', 'Preparación: solicitud 3');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000011c4', 12000, p_tienda => 'a7500000-0000-4000-8000-0000000011b1')) ->> 'estado_pago', 'solicitud', 'Preparación: solicitud 4');

-- ---------------------------------------------------------------- regresar: la solicitud sale de la cola del albacea
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago where estado = 'pendiente' and compra_id = 'a7300000-0000-4000-8000-0000000011c4'$$), 1, 'La solicitud 4 está en la cola del albacea');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_regresar_compra('a7300000-0000-4000-8000-0000000011c4', 'Me equivoqué de compra') is not null, 'La pareja regresa la compra 4');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago where estado = 'pendiente' and compra_id = 'a7300000-0000-4000-8000-0000000011c4'$$), 0, 'Ya no aparece en la cola del albacea');
select pruebas.ok((select estado = 'revertida' from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c4'), '… queda revertida');
select pruebas.ok((select not comprado and estado_pago = 'sin_pago' from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000011c4'), '… y la compra vuelve a pendiente');

-- ---------------------------------------------------------------- rechazo: efectivo por omisión
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c1' and estado = 'pendiente'),
  false, null, null, 'Ya hay frijol') is null, 'El albacea rechaza sin elegir cuenta');
select pruebas.ok((select estado_pago = 'rechazada' and cuenta_rechazo_id = 'c6000000-0000-4000-8000-000000000002' and comprado and monto_centavos = 3000
                     from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000011c1'), 'Vuelve a la cuenta de efectivo del libro de Papá por omisión');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where nota ilike 'Compra de la lista de Papá'$$), 0, 'No se mueve dinero');

-- ---------------------------------------------------------------- rechazo: otra cuenta del libro
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c2' and estado = 'pendiente'),
  false, null, 'c6000000-0000-4000-8000-000000000001', 'Mejor de la cuenta de pensión') is null, 'El albacea rechaza y elige otra cuenta del libro');
select pruebas.ok((select estado_pago = 'rechazada' and cuenta_rechazo_id = 'c6000000-0000-4000-8000-000000000001'
                     from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000011c2'), 'La compra usa la cuenta elegida');

-- ---------------------------------------------------------------- la cuenta debe ser del libro
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c3' and estado = 'pendiente'),
  false, null, 'c3000000-0000-4000-8000-000000000002', 'Otra cuenta')$$, 'Una cuenta de otro libro no vale', '22023');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c3' and estado = 'pendiente'),
  false, null, gen_random_uuid(), 'Otra cuenta')$$, 'Una cuenta inexistente tampoco', '22023');
select pruebas.ok((select estado = 'pendiente' from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c3'), 'La solicitud con error sigue pendiente');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000011c3' and estado = 'pendiente'),
  false, null, null, 'No soy albacea')$$, 'La pareja no resuelve', '42501');

-- ---------------------------------------------------------------- sigue en el historial con su precio real
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select count(*) = 2 and sum(gasto_centavos) = 9000
                     from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, 'a7100000-0000-4000-8000-0000000011a1')
                    where not revertida and compra_id in ('a7300000-0000-4000-8000-0000000011c1', 'a7300000-0000-4000-8000-0000000011c2')),
  'Las dos compras rechazadas siguen en el historial con su precio real');
select pruebas.ok((select precio_unitario_centavos = 3000 from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, 'a7100000-0000-4000-8000-0000000011a1')
                    where compra_id = 'a7300000-0000-4000-8000-0000000011c1'), 'Con su precio unitario real');

-- ---------------------------------------------------------------- regresar una rechazada limpia la cuenta
select pruebas.ok(public.ali_regresar_compra('a7300000-0000-4000-8000-0000000011c2', 'La volví a pensar') is not null, 'La rechazada se puede regresar');
select pruebas.ok((select cuenta_rechazo_id is null and not comprado from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000011c2'), '… y se limpia la cuenta de rechazo');
rollback;
