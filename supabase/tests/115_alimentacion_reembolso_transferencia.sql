-- Alimentación, Fase 8 v1.6 (migración 20261144): reembolso por transferencia (A).
-- Alex compra para Papá; el albacea (Ana) la rechaza dos veces; Alex registra su gasto; el albacea autoriza el reembolso
-- (transferencia de una cuenta de Papá a Alex); Alex la confirma. Quien compró queda registrado en todo momento.
begin;
select pruebas.como_postgres();

-- Efectivo en el libro personal de Alex (el servidor ya le creó el libro al darle el rol).
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo, limite_centavos) values
  ('c3000000-0000-4000-8000-0000000015b1', 'b0000000-0000-4000-8000-000000000001',
   (select l.id from public.fin_libros l where l.tipo = 'personal' and l.titular_id = pruebas.id_persona('alex@ejemplo.test')),
   'Efectivo de prueba R15', 'efectivo', null);

insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000016a1', 'b0000000-0000-4000-8000-000000000001', 'Chícharo R', 'kg', 'Despensa', 3500);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000016b1', 'b0000000-0000-4000-8000-000000000001', 'Tienda R6');
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000016c1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000016a1', 1, pruebas.id_persona('alex@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000016c2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000016a1', 2, pruebas.id_persona('alex@ejemplo.test'));

-- Alex compra (solicitud de reembolso). Ana rechaza y Alex reenvía.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000016c1', 3500, p_tienda => 'a7500000-0000-4000-8000-0000000016b1')) ->> 'estado_pago', 'solicitud', 'Compra con solicitud');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000016c1' and intento = 1), false, null, null, 'Primer rechazo') is null, 'Primer rechazo');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000016c1' and intento = 1), 'Era para la semana') is not null, 'Alex reenvía');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000016c1' and intento = 2), false, null, null, 'Segundo rechazo') is null, 'Segundo rechazo');

-- Antes de registrar su gasto no hay reembolso que autorizar; el gasto lo registra Alex.
select pruebas.falla($$select public.ali_autorizar_reembolso('a7300000-0000-4000-8000-0000000016c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'Primero quien compró registra su gasto', '22023');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000016c1', 'c3000000-0000-4000-8000-0000000015b1') is not null, 'Alex registra su gasto en su efectivo');
select pruebas.ok(public.ali_es_gasto_de_comprador('b0000000-0000-4000-8000-000000000001', 'a7300000-0000-4000-8000-0000000016c1'), 'Mientras no hay reembolso, es gasto de quien compró');
select pruebas.ok(not exists (select 1 from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto') where clave = 'a7100000-0000-4000-8000-0000000016a1'),
  'Y no suma en el resumen de Papá');

-- El albacea autoriza el reembolso: transferencia de Papá a Alex. Una sola activa; solo el albacea.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_autorizar_reembolso('a7300000-0000-4000-8000-0000000016c1', 'c6000000-0000-4000-8000-000000000002') is not null,
  'El albacea propone la transferencia de Papá a Alex');
select pruebas.ok(exists (select 1 from public.fin_transferencias t join public.ali_solicitudes_pago s on s.transferencia_id = t.id
                           where s.compra_id = 'a7300000-0000-4000-8000-0000000016c1' and t.ruta = 'papa_a_persona' and t.estado = 'pendiente'
                             and t.persona_destino_id = pruebas.id_persona('alex@ejemplo.test') and t.monto_centavos = 3500),
  'La transferencia queda pendiente, de Papá a quien compró, por el monto');
select pruebas.falla($$select public.ali_autorizar_reembolso('a7300000-0000-4000-8000-0000000016c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'No hay dos transferencias de reembolso activas', '22023');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_autorizar_reembolso('a7300000-0000-4000-8000-0000000016c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'Solo el albacea autoriza', '42501');

-- Quien compró confirma; el dinero llega a su cuenta y sale de la de Papá (una sola vez).
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia((select transferencia_id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000016c1' and intento = 2), 'confirmar', 'c3000000-0000-4000-8000-0000000015b1')$$,
  'Quien propone no confirma su propia transferencia', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_responder_transferencia((select transferencia_id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000016c1' and intento = 2), 'confirmar', 'c3000000-0000-4000-8000-0000000015b1') is not null,
  'Alex confirma el reembolso');
select pruebas.ok(exists (select 1 from public.fin_movimientos m where m.tipo = 'transferencia' and m.cuenta_origen_id = 'c6000000-0000-4000-8000-000000000002'
                           and m.cuenta_destino_id = 'c3000000-0000-4000-8000-0000000015b1' and m.monto_centavos = 3500),
  'El movimiento sale de la cuenta de Papá y llega a la de Alex');
select pruebas.ok(not public.ali_es_gasto_de_comprador('b0000000-0000-4000-8000-000000000001', 'a7300000-0000-4000-8000-0000000016c1'),
  'Con el reembolso confirmado ya no es gasto de quien compró');
select pruebas.ok(exists (select 1 from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')
                           where clave = 'a7100000-0000-4000-8000-0000000016a1' and gasto_centavos = 3500),
  'El consumo ahora sí es de Papá (pagado por transferencia)');

-- Quien compró queda registrado en el detalle, para el albacea y para quien compró; a otros no.
select pruebas.ok((select (d ->> 'comprado_por')::uuid = pruebas.id_persona('alex@ejemplo.test') and (d -> 'reembolso' ->> 'estado') = 'confirmada'
                     from (select public.ali_detalle_reembolso('a7300000-0000-4000-8000-0000000016c1') d) x),
  'El detalle conserva quién compró y el reembolso confirmado');
select pruebas.ok((select jsonb_array_length(d -> 'intentos') = 2 from (select public.ali_detalle_reembolso('a7300000-0000-4000-8000-0000000016c1') d) x),
  'Guarda los dos intentos');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select (d ->> 'solicitada_por')::uuid = pruebas.id_persona('alex@ejemplo.test') from (select public.ali_detalle_reembolso('a7300000-0000-4000-8000-0000000016c1') d) x),
  'El albacea ve quién compró');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_detalle_reembolso('a7300000-0000-4000-8000-0000000016c1')$$,
  'La casa no ve el detalle de la compra', '42501');

-- Solo se reembolsa una compra rechazada dos veces.
select pruebas.como_postgres();
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000016c3', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000016a1', 1, pruebas.id_persona('alex@ejemplo.test'));
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000016c3', 1200, p_tienda => 'a7500000-0000-4000-8000-0000000016b1')) ->> 'estado_pago', 'solicitud', 'Otra compra con solicitud');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000016c3' and intento = 1), false, null, null, 'Rechazo único') is null, 'Rechazo único');
select pruebas.falla($$select public.ali_autorizar_reembolso('a7300000-0000-4000-8000-0000000016c3', 'c6000000-0000-4000-8000-000000000002')$$,
  'Un solo rechazo no se reembolsa', '22023');
rollback;
