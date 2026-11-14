-- Alimentación, Fase 8 v1.7 (migración 20261145): opción B. El albacea reclasifica el gasto de quien compró al libro de Papá;
-- quien compró anula su gasto en su libro. Sin transferencia.
-- Seed: Ana albacea; Alex compra (su libro personal y su efectivo de prueba R15, de la prueba 115 — aquí se crea otro).
begin;
select pruebas.como_postgres();
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo, limite_centavos) values
  ('c3000000-0000-4000-8000-0000000017b1', 'b0000000-0000-4000-8000-000000000001',
   (select l.id from public.fin_libros l where l.tipo = 'personal' and l.titular_id = pruebas.id_persona('alex@ejemplo.test')),
   'Efectivo de prueba R17', 'efectivo', null);
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000017a1', 'b0000000-0000-4000-8000-000000000001', 'Haba R', 'kg', 'Despensa', 2000);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000017b2', 'b0000000-0000-4000-8000-000000000001', 'Tienda R7');
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000017c1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000017a1', 1, pruebas.id_persona('alex@ejemplo.test')),
  ('a7300000-0000-4000-8000-0000000017c2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000017a1', 2, pruebas.id_persona('alex@ejemplo.test'));

-- Alex compra; Ana rechaza dos veces; Alex registra su gasto.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000017c1', 2500, p_tienda => 'a7500000-0000-4000-8000-0000000017b2')) ->> 'estado_pago', 'solicitud', 'Compra con solicitud');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000017c1' and intento = 1), false, null, null, 'Primer rechazo') is null, 'Primer rechazo');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_reenviar_solicitud((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000017c1' and intento = 1), 'Era para la semana') is not null, 'Alex reenvía');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where compra_id = 'a7300000-0000-4000-8000-0000000017c1' and intento = 2), false, null, null, 'Segundo rechazo') is null, 'Segundo rechazo');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_registrar_gasto_rechazado('a7300000-0000-4000-8000-0000000017c1', 'c3000000-0000-4000-8000-0000000017b1') is not null, 'Alex registra su gasto en su efectivo');

-- Reclasificar: solo el albacea, con cuenta de Papá, y solo una vez.
select pruebas.falla($$select public.ali_reclasificar_gasto('a7300000-0000-4000-8000-0000000017c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'Quien compró no reclasifica al libro de Papá', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_reclasificar_gasto('a7300000-0000-4000-8000-0000000017c1', 'c3000000-0000-4000-8000-0000000017b1')$$,
  'La cuenta debe ser del libro de Papá', '22023');
select pruebas.ok(public.ali_reclasificar_gasto('a7300000-0000-4000-8000-0000000017c1', 'c6000000-0000-4000-8000-000000000002') is not null,
  'El albacea reclasifica el gasto al libro de Papá');
select pruebas.ok(exists (select 1 from public.fin_movimientos m where m.cuenta_origen_id = 'c6000000-0000-4000-8000-000000000002' and m.monto_centavos = 2500
                           and m.en_nombre_de = (select l.titular_id from public.fin_libros l where l.id = (select libro_id from public.fin_cuentas where id = 'c6000000-0000-4000-8000-000000000002'))),
  'El gasto sale de Papá, a su nombre');
select pruebas.falla($$select public.ali_reclasificar_gasto('a7300000-0000-4000-8000-0000000017c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'No se reclasifica dos veces', '22023');
select pruebas.falla($$select public.ali_autorizar_reembolso('a7300000-0000-4000-8000-0000000017c1', 'c6000000-0000-4000-8000-000000000002')$$,
  'Ya reclasificado no hay reembolso', '22023');

-- El costo ya es de Papá en su resumen (aunque Alex todavía no anule su gasto).
select pruebas.ok(exists (select 1 from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')
                           where clave = 'a7100000-0000-4000-8000-0000000017a1' and gasto_centavos = 2500),
  'El resumen de Papá suma la compra al reclasificarse');

-- Quien compró anula su gasto en su libro (solo ella, una vez, con motivo).
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_anular_gasto_propio('a7300000-0000-4000-8000-0000000017c1', 'Se pasó a Papá')$$,
  'Quien no compró no anula el gasto', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_anular_gasto_propio('a7300000-0000-4000-8000-0000000017c1', 'no')$$,
  'El motivo es obligatorio', '23514');
select pruebas.ok(public.ali_anular_gasto_propio('a7300000-0000-4000-8000-0000000017c1', 'Se pasó al libro de Papá') is not null,
  'Alex anula su gasto con un contraasiento');
select pruebas.ok(exists (select 1 from public.fin_movimientos a join public.fin_movimientos o on o.id = a.anula_a
                           where o.id = (select movimiento_id from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000017c1')
                             and a.tipo = 'anulacion' and a.cuenta_origen_id = o.cuenta_destino_id),
  'El contraasiento invierte su gasto en su libro');
select pruebas.falla($$select public.ali_anular_gasto_propio('a7300000-0000-4000-8000-0000000017c1', 'Otra vez')$$,
  'No se anula dos veces', '22023');

-- Detalle: se ve la reclasificación y que quien compró ya anuló su gasto.
select pruebas.ok((select (d -> 'reclasificacion' ->> 'anulado_por_comprador')::boolean
                     from (select public.ali_detalle_reembolso('a7300000-0000-4000-8000-0000000017c1') d) x),
  'El detalle muestra que quien compró anuló su gasto');

-- Compra con gasto de Alex pero sin rechazo doble: no se reclasifica.
select pruebas.como_postgres();
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000017c3', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000017a1', 1, pruebas.id_persona('alex@ejemplo.test'));
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000017c3', 900, p_tienda => 'a7500000-0000-4000-8000-0000000017b2')) ->> 'estado_pago', 'solicitud', 'Otra compra con solicitud');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_reclasificar_gasto('a7300000-0000-4000-8000-0000000017c3', 'c6000000-0000-4000-8000-000000000002')$$,
  'Solo se reclasifica una compra rechazada dos veces', '22023');
rollback;
