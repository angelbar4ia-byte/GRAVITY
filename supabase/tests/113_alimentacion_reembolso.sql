-- Alimentación, Fase 8 v1.4 (migración 20261142): reembolso de compras de Papá.
-- Compra de Papá sin cuenta de pago = solicitud. Aprobada: sale de Papá. Rechazada: se puede reenviar UNA vez con
-- justificación; si se rechaza otra vez, el gasto es de quien compró (no se registra en el libro de Papá).
-- Seed: Ana dueña y albacea de Papá, Alex pareja (quien compra en esta prueba). Efectivo de Papá c6...02.
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000013a1', 'b0000000-0000-4000-8000-000000000001', 'Lenteja R', 'kg', 'Despensa', 2500);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000013b1', 'b0000000-0000-4000-8000-000000000001', 'Tienda R');
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000013c1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000013a1', 1, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000013c2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000013a1', 2, pruebas.id_persona('ana@ejemplo.test'));

-- ---------------------------------------------------------------- compra: queda como solicitud
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000013c1', 2000, p_tienda => 'a7500000-0000-4000-8000-0000000013b1')) ->> 'estado_pago', 'solicitud', 'Sin cuenta de pago, la compra de Papá es solicitud');
select pruebas.ok(exists (select 1 from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and estado = 'pendiente' and intento = 1), 'La solicitud 1 está pendiente');

-- ---------------------------------------------------------------- primer rechazo: no hay cuenta ni dinero
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 1), false, null, null, 'Ya no hacía falta') is null,
  'El albacea rechaza la solicitud 1');
select pruebas.ok((select estado_pago = 'rechazada' from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000013c1'), 'La compra queda rechazada');

-- ---------------------------------------------------------------- reenvío: solo quien compró, con justificación de 3 a 200
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 1), 'Sí')$$,
  'El reenvío lleva justificación de 3 caracteres o más', '23514');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 1), 'Es para la semana')$$,
  'Quien no compró no reenvía', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 1), 'Era para la cena de la semana') is not null,
  'Quien compró reenvía con justificación');
select pruebas.ok(exists (select 1 from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 2 and estado = 'pendiente' and justificacion = 'Era para la cena de la semana'),
  'El reenvío queda pendiente como intento 2 con su justificación');
select pruebas.ok((select estado_pago = 'solicitud' from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000013c1'), 'La compra vuelve a solicitud');
select pruebas.falla($$select public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 1), 'Otra vez')$$,
  'Solo se reenvía una vez', '22023');

-- ---------------------------------------------------------------- segundo rechazo: el gasto es de quien compró
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 2), false, null, null, 'Sigue sin ser de Papá') is null,
  'El albacea rechaza el reenvío');
select pruebas.ok((select estado_pago = 'rechazada' from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000013c1'), 'La compra queda rechazada otra vez');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where nota ilike 'Compra de la lista de Papá'$$), 0, 'El gasto no se registra en el libro de Papá');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and intento = 2), 'Tercera vez')$$,
  'Ya no se reenvía: el gasto es de quien compró', '22023');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1'$$), 2,
  'El histórico guarda los dos intentos');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c1' and estado = 'pendiente'$$), 0,
  'Ninguno queda en la cola del albacea');

-- ---------------------------------------------------------------- una compra aprobada tras reenvío sale de Papá
select pruebas.como_postgres();
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000013c3', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000013a1', 3, pruebas.id_persona('ana@ejemplo.test'));
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000013c3', 3000, p_tienda => 'a7500000-0000-4000-8000-0000000013b1')) ->> 'estado_pago', 'solicitud', 'Otra compra de Papá queda solicitud');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000013c3' and intento = 1), true, 'c6000000-0000-4000-8000-000000000002', null, 'Compra aprobada') is not null,
  'El albacea aprueba y paga desde el efectivo de Papá');
select pruebas.ok((select estado_pago = 'movimiento' from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000013c3'), 'La compra aprobada queda pagada por Papá');
rollback;
