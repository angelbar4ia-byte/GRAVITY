-- Alimentación, Fase 8 v1.5 (migración 20261143): tras el segundo rechazo, quien compró registra el gasto en su libro personal.
-- Seed: Ana dueña y albacea de Papá y dueña de su libro personal (cuentas c3...01 banco y c3...02 efectivo). Papá: efectivo c6...02.
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000014a1', 'b0000000-0000-4000-8000-000000000001', 'Garbanzo G', 'kg', 'Despensa', 4000);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000014b1', 'b0000000-0000-4000-8000-000000000001', 'Tienda G');
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000014c1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000014a1', 1, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000014c2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000014a1', 2, pruebas.id_persona('ana@ejemplo.test'));

-- Ana compra (solicitud de reembolso) y el albacea la rechaza dos veces.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000014c1', 4000, p_tienda => 'a7500000-0000-4000-8000-0000000014b1')) ->> 'estado_pago', 'solicitud', 'Compra con solicitud de reembolso');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000014c1' and intento = 1), false, null, null, 'No era urgente') is null, 'Primer rechazo');
select pruebas.falla($$select public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c1', 'c3000000-0000-4000-8000-000000000002')$$,
  'Antes del segundo rechazo no hay gasto que registrar', '22023');
select pruebas.ok(public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000014c1' and intento = 1), 'Sí era necesaria') is not null, 'Ana reenvía una vez');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000014c1' and intento = 2), false, null, null, 'Sigue sin ser de Papá') is null, 'Segundo rechazo');

-- Registrar el gasto: solo quien compró, desde su libro personal.
select pruebas.falla($$select public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c1', null)$$,
  'Elige la cuenta', '22023');
select pruebas.falla($$select public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'La cuenta de Papá no es personal', '22023');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c1', 'c3000000-0000-4000-8000-000000000002')$$,
  'Otra persona no registra el gasto', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c1', 'c3000000-0000-4000-8000-000000000002') is not null,
  'Quien compró registra el gasto en su efectivo');
select pruebas.ok((select estado_pago = 'movimiento' and movimiento_id is not null from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000014c1'),
  'La compra queda con su gasto registrado');
select pruebas.ok(exists (select 1 from public.fin_movimientos m where m.id = (select movimiento_id from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000014c1')
                           and m.cuenta_origen_id = 'c3000000-0000-4000-8000-000000000002' and m.monto_centavos = 4000),
  'El gasto sale del efectivo personal de Ana, por el monto pagado');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos m where m.nota ilike 'Compra rechazada en el reembolso%'$$), 1,
  'Queda una sola anotación, en su libro');
select pruebas.falla($$select public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c1', 'c3000000-0000-4000-8000-000000000002')$$,
  'No se registra dos veces', '22023');

-- Un rechazo que no es el segundo no registra gasto; la compra sigue reenviable.
select pruebas.como_postgres();
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000014c3', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000014a1', 3, pruebas.id_persona('ana@ejemplo.test'));
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000014c3', 6000, p_tienda => 'a7500000-0000-4000-8000-0000000014b1')) ->> 'estado_pago', 'solicitud', 'Otra compra con solicitud');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000014c3' and intento = 1), false, null, null, 'Hoy no') is null, 'Rechazo único');
select pruebas.falla($$select public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000014c3', 'c3000000-0000-4000-8000-000000000002')$$,
  'Con un solo rechazo no hay gasto', '22023');
rollback;
