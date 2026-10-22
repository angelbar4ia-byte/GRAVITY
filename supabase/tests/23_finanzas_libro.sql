-- Sección 4.3: el servidor valida cada movimiento al insertarlo (tabla de
-- combinaciones de libro.dart), las cuentas activas, los libros que toca y
-- las columnas que pone él (recibido_en, libros, registrado_por).
begin;
select pruebas.como('ana@ejemplo.test');

-- Cuentas nuevas sin saldo inicial para probar aperturas.
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c3000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001',
   pruebas.libro_personal('ana@ejemplo.test'), 'Tarjeta nueva', 'tarjeta');

-- ---------------------------------------------------------------- combinaciones válidas
select pruebas.ok(pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
                                    'c3000000-0000-4000-8000-000000000007', 100000) is not null,
  'apertura: Apertura → activo');
select pruebas.ok(pruebas.registrar('apertura', 'c3000000-0000-4000-8000-0000000000f1',
                                    pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'), 30000) is not null,
  'apertura: pasivo → Apertura');
select pruebas.ok(pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 50000) is not null,
  'ingreso: origen de ingreso → activo (un extra)');
select pruebas.ok(pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 9000) is not null,
  'gasto: activo → gasto');
select pruebas.ok(pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000005', 60000) is not null,
  'gasto: tarjeta (pasivo) → gasto: sube la deuda');
select pruebas.ok(pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000012', 1500) is not null,
  'gasto: intereses → gasto financiero');
select pruebas.ok(pruebas.registrar('reembolso', 'c2000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000001', 20000) is not null,
  'reembolso: gasto → activo (baja el gasto, no es ingreso)');
select pruebas.ok(pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000007', 10000) is not null,
  'transferencia: activo → activo (aportación a ahorro)');
select pruebas.ok(pruebas.registrar('pago_deuda', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003', 30000) is not null,
  'pago_deuda: activo → pasivo');
select pruebas.ok(pruebas.registrar('reclasificacion', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'por_clasificar'),
                                    'c2000000-0000-4000-8000-000000000001', 12000) is not null,
  'reclasificacion: Por clasificar → gasto');
select pruebas.ok(pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
                                    'c3000000-0000-4000-8000-000000000002', 700, p_motivo => 'Encontré un billete (ejemplo)') is not null,
  'ajuste: Ajustes → activo, con motivo');
select pruebas.ok(pruebas.registrar('ajuste', 'c3000000-0000-4000-8000-000000000003',
                                    pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'), 200,
                                    p_motivo => 'Comisión que no registré (ejemplo)') is not null,
  'ajuste: pasivo → Ajustes, con motivo');

-- ---------------------------------------------------------------- combinaciones inválidas
select pruebas.falla($$select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
  'c3000000-0000-4000-8000-000000000007', 100)$$, 'apertura: una sola por cuenta', '22023');
select pruebas.falla($$select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'apertura: no a una cuenta de gasto', '22023');
select pruebas.falla($$select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000002', 100)$$, 'ingreso: no sale de un activo', '22023');
select pruebas.falla($$select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000005',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'ingreso: no llega a un gasto', '22023');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000005',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'gasto: no sale de un origen de ingreso', '22023');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000002', 100)$$, 'gasto: no va a un activo', '22023');
select pruebas.falla($$select pruebas.registrar('reembolso', 'c2000000-0000-4000-8000-000000000005',
  'c3000000-0000-4000-8000-000000000005', 100)$$, 'reembolso: no va a un origen de ingreso', '22023');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000003', 100)$$, 'transferencia: no a un pasivo (eso es pago_deuda)', '22023');
select pruebas.falla($$select pruebas.registrar('pago_deuda', 'c3000000-0000-4000-8000-000000000003',
  'c3000000-0000-4000-8000-000000000001', 100)$$, 'pago_deuda: no de pasivo a activo', '22023');
select pruebas.falla($$select pruebas.registrar('reclasificacion', 'c2000000-0000-4000-8000-000000000004',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'reclasificacion: solo desde Por clasificar', '22023');
select pruebas.falla($$select pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
  'c2000000-0000-4000-8000-000000000001', 100, p_motivo => 'x')$$, 'ajuste: no contra un gasto', '22023');
select pruebas.falla($$select pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
  'c3000000-0000-4000-8000-000000000002', 100)$$, 'ajuste: motivo obligatorio', '23514');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 100)$$, 'Origen y destino distintos', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 0)$$, 'Monto mayor que cero', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', -500)$$, 'Sin montos negativos (la dirección la dan las cuentas)', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3999999-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Una cuenta que no existe (o aún no se sube): 23503, se reintenta', '23503');
select pruebas.falla($$select pruebas.registrar('gasto', 'c7000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Una cuenta de otro hogar no sirve', '23503');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100, p_motivo => repeat('m', 201))$$, 'Motivo de 200 caracteres como máximo', '23514');

-- ---------------------------------------------------------------- entre libros (D19)
create temporary table aportacion on commit drop as
  select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001',
                           'c5000000-0000-4000-8000-000000000001', 25000) as id;
select pruebas.ok(
  (select libro_origen_id = pruebas.libro_personal('ana@ejemplo.test')
          and libro_destino_id = 'f1000000-0000-4000-8000-000000000001'
     from public.fin_movimientos where id = (select id from aportacion)),
  'Una aportación al compartido es un solo movimiento entre dos libros');
select pruebas.ok(pruebas.registrar('pago_deuda', 'c5000000-0000-4000-8000-000000000001',
                                    'c3000000-0000-4000-8000-000000000003', 5000) is not null,
  'Un pago de deuda también puede cruzar de libro (la casa abona a la tarjeta de Ana)');
select pruebas.falla($$select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000005',
  'c5000000-0000-4000-8000-000000000001', 100)$$, 'Un ingreso no cruza de libro', '22023');
select pruebas.falla($$select pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
  'c5000000-0000-4000-8000-000000000001', 100, p_motivo => 'x')$$, 'Un ajuste va contra los Ajustes del mismo libro', '22023');
select pruebas.ok(
  pruebas.registrar('anulacion', 'c5000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 25000,
                    p_motivo => 'Aportación duplicada', p_anula => (select id from aportacion)) is not null,
  'La anulación de una aportación también cruza de libro');

-- ---------------------------------------------------------------- columnas que pone el servidor
select pruebas.ok(
  (select bool_and(recibido_en = now() and registrado_por = pruebas.id_persona('ana@ejemplo.test')
                   and realizado_por = pruebas.id_persona('ana@ejemplo.test'))
     from public.fin_movimientos where id = (select id from aportacion)),
  'recibido_en, registrado_por y realizado_por los pone el servidor (sesión)');
select pruebas.falla($$insert into public.fin_movimientos (hogar_id, tipo, fecha, registrado_en, recibido_en,
  cuenta_origen_id, cuenta_destino_id, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21', now(), now() - interval '1 year',
          'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 100)$$,
  'La app no fija recibido_en', '42501');
select pruebas.falla($$insert into public.fin_movimientos (hogar_id, tipo, fecha, registrado_en, libro_origen_id,
  cuenta_origen_id, cuenta_destino_id, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21', now(), 'f1000000-0000-4000-8000-000000000001',
          'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 100)$$,
  'La app no fija el libro de un movimiento', '42501');
select pruebas.falla($$insert into public.fin_movimientos (hogar_id, tipo, fecha, cuenta_origen_id,
  cuenta_destino_id, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21',
          'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 100)$$,
  'registrado_en (cuándo se capturó) es obligatorio', '23502');

-- ---------------------------------------------------------------- pendientes y cuentas congeladas
create temporary table saldo_antes on commit drop as
  select saldo_centavos, saldo_con_pendientes_centavos from public.fin_v_saldos
   where cuenta_id = 'c3000000-0000-4000-8000-000000000002';
insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, estado_inicial)
values ('d7000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21', now(),
        'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000007', 5000, 'pendiente');
select pruebas.ok(
  (select v.saldo_centavos = a.saldo_centavos
          and v.saldo_con_pendientes_centavos = a.saldo_con_pendientes_centavos - 5000
     from public.fin_v_saldos v, saldo_antes a where v.cuenta_id = 'c3000000-0000-4000-8000-000000000002'),
  'Un pendiente no cambia el saldo confirmado (sí el saldo con pendientes)');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000007',
  'c3000000-0000-4000-8000-000000000002', 5000, p_motivo => 'x', p_anula => 'd7000000-0000-4000-8000-000000000001')$$,
  'Solo se anula un movimiento confirmado', '22023');

create temporary table al_ahorro on commit drop as
  select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001',
                           'c3000000-0000-4000-8000-000000000007', 3000) as id;
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'congelada'
  where id = 'c3000000-0000-4000-8000-000000000007'$$), 1, 'Se congela la cuenta de ahorro');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000007',
  'c3000000-0000-4000-8000-000000000001', 100)$$, 'Una cuenta congelada no admite movimientos nuevos', '55000');
select pruebas.ok(
  pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000007', 'c3000000-0000-4000-8000-000000000001', 3000,
                    p_motivo => 'Se apartó de más', p_anula => (select id from al_ahorro)) is not null,
  'Pero sí la anulación de uno anterior');

rollback;
