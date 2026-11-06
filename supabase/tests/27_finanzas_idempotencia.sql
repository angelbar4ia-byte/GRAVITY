-- Criterio 27 (sin conexión): reintentar no duplica. La cola de la app sube
-- con upsert on_conflict=id, ignore-duplicates (INSERT … ON CONFLICT (id) DO
-- NOTHING). Mismo id y mismo contenido: no inserta nada y no falla. Mismo id
-- con otro contenido: en los libros solo agregar, error 23505 (no se edita).
begin;
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- movimientos
select pruebas.igual(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 12345,
                    p_id => 'd4000000-0000-4000-8000-000000000001'),
  'd4000000-0000-4000-8000-000000000001'::uuid, 'Primer envío: se guarda');
select pruebas.igual(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 12345,
                    p_id => 'd4000000-0000-4000-8000-000000000001'),
  null::uuid, 'Reenvío idéntico (respuesta perdida): no inserta nada y no falla');
select pruebas.igual(pruebas.afecta($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en,
  cuenta_origen_id, cuenta_destino_id, monto_centavos, realizado_por)
  values ('d4000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21',
          '2026-10-21 12:00:00-06', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001',
          12345, pruebas.id_persona('ana@ejemplo.test'))
  on conflict (id) do nothing$$), 0,
  'Como la cola de la app (ON CONFLICT DO NOTHING): 0 filas y sin error');
select pruebas.igual(
  (select count(*)::int from public.fin_movimientos where id = 'd4000000-0000-4000-8000-000000000001'), 1,
  'Queda una sola fila');
select pruebas.igual(
  (select count(*)::int from public.bitacora where tabla = 'fin_movimientos'
     and registro_id = 'd4000000-0000-4000-8000-000000000001'), 1,
  'Y una sola entrada en la bitácora');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 99999, p_id => 'd4000000-0000-4000-8000-000000000001')$$,
  'Mismo id con otro monto: 23505 (los movimientos no se editan)', '23505');
select pruebas.falla($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en,
  cuenta_origen_id, cuenta_destino_id, monto_centavos)
  values ('d4000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21',
          '2026-10-21 12:00:00-06', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 99999)
  on conflict (id) do nothing$$,
  'También con ON CONFLICT DO NOTHING: el cambio no se pierde en silencio', '23505');
select pruebas.igual(
  (select monto_centavos from public.fin_movimientos where id = 'd4000000-0000-4000-8000-000000000001'),
  12345::bigint, 'El movimiento guardado no cambió');

-- Deshacer al capturar = anulación; reenviarla no falla aunque el original ya tenga anulación.
select pruebas.ok(
  pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002', 12345,
                    p_motivo => 'Deshecho al capturar', p_anula => 'd4000000-0000-4000-8000-000000000001',
                    p_id => 'd4000000-0000-4000-8000-000000000002') is not null,
  '"Guardado · Deshacer": la anulación se guarda');
select pruebas.igual(
  pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002', 12345,
                    p_motivo => 'Deshecho al capturar', p_anula => 'd4000000-0000-4000-8000-000000000001',
                    p_id => 'd4000000-0000-4000-8000-000000000002'),
  null::uuid, 'Reenviar la anulación no falla');

-- La apertura reenviada no choca con "una por cuenta".
select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
                         'c3000000-0000-4000-8000-000000000007', 5000, p_id => 'd4000000-0000-4000-8000-000000000003');
select pruebas.igual(
  pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
                    'c3000000-0000-4000-8000-000000000007', 5000, p_id => 'd4000000-0000-4000-8000-000000000003'),
  null::uuid, 'Reenviar una apertura no falla');

-- Si entre envíos la cuenta se congeló, el reenvío de lo ya guardado no falla.
update public.fin_cuentas set estado = 'congelada' where id = 'c3000000-0000-4000-8000-000000000002';
select pruebas.igual(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 12345,
                    p_id => 'd4000000-0000-4000-8000-000000000001'),
  null::uuid, 'Reenvío de lo ya guardado con la cuenta congelada: no falla');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Pero un movimiento nuevo sí se rechaza', '55000');
update public.fin_cuentas set estado = 'activa' where id = 'c3000000-0000-4000-8000-000000000002';

-- El id es del dispositivo: otra persona u otro hogar no pisan ni duplican.
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000002', 800000, '2026-10-01', p_id => 'd1000000-0000-4000-8000-000000000012',
  p_realizado_por => pruebas.id_persona('ana@ejemplo.test'))$$,
  'El mismo id desde otra persona: 23505 (no se duplica ni se pisa)', '23505');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('gasto', 'c7000000-0000-4000-8000-000000000001',
  'c7000000-0000-4000-8000-000000000002', 100, p_id => 'd1000000-0000-4000-8000-000000000012',
  p_hogar => 'b0000000-0000-4000-8000-000000000002')$$,
  'El mismo id desde otro hogar: 23505, sin ver nada del original', '23505');

-- ---------------------------------------------------------------- conciliaciones, cierres e importaciones
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_conciliaciones (id, hogar_id, cuenta_id, fecha,
  saldo_declarado, saldo_calculado) values ('eb000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000007', '2026-10-21', 5000, 5000) on conflict (id) do nothing$$), 1,
  'Conciliación: primer envío');
select pruebas.igual(pruebas.afecta($$insert into public.fin_conciliaciones (id, hogar_id, cuenta_id, fecha,
  saldo_declarado, saldo_calculado) values ('eb000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000007', '2026-10-21', 5000, 5000) on conflict (id) do nothing$$), 0,
  'Conciliación reenviada: 0 filas (creado_en y diferencia no se comparan)');
select pruebas.falla($$insert into public.fin_conciliaciones (id, hogar_id, cuenta_id, fecha,
  saldo_declarado, saldo_calculado) values ('eb000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000007', '2026-10-21', 7000, 7000) on conflict (id) do nothing$$,
  'Conciliación con el mismo id y otros saldos: 23505', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cierre_partidas (id, hogar_id, cierre_id, partida_id,
  gastado, arrastre_siguiente, al_remanente)
  values ('e9000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000001',
          'e9000000-0000-4000-8000-000000000001', 'e7000000-0000-4000-8000-000000000011', 4500, 65500, 0)
  on conflict (id) do nothing$$), 0,
  'Partida de un cierre reenviada (con la semana ya cerrada): 0 filas, sin error');
select pruebas.falla($$insert into public.fin_cierre_partidas (id, hogar_id, cierre_id, partida_id,
  gastado, arrastre_siguiente, al_remanente)
  values ('e9000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000001',
          'e9000000-0000-4000-8000-000000000001', 'e7000000-0000-4000-8000-000000000011', 1, 0, 0)
  on conflict (id) do nothing$$, 'La foto de un cierre no se reescribe con el mismo id', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cierres (id, hogar_id, semana_id, version, ingreso_real,
  gasto_real, abono_real, abono_diferido, abono_extra_real, ahorro_real, deficit, arrastre_siguiente,
  accion_elegida, con_pendientes, activos, pasivos, patrimonio, cerrado_en)
  values ('e9000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
          'e6000000-0000-4000-8000-000000000001', 1, 415385, 37577, 39231, 0, 0, 0, 0, 130500,
          'abono_extra', false, 1975500, 805000, 1170500, '2026-10-19 08:00-06')
  on conflict (id) do nothing$$), 0, 'Cierre reenviado: 0 filas, sin error');
select pruebas.igual(pruebas.afecta($$insert into public.fin_importaciones (id, hogar_id, archivo, hoja,
  filas_leidas, filas_creadas, filas_omitidas)
  values ('ed000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
          'DATOS_SEMILLA_PRESUPUESTO.xlsx', 'Categorías', 23, 0, 23) on conflict (id) do nothing$$), 1,
  'Importación registrada');
select pruebas.igual(pruebas.afecta($$insert into public.fin_importaciones (id, hogar_id, archivo, hoja,
  filas_leidas, filas_creadas, filas_omitidas)
  values ('ed000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
          'DATOS_SEMILLA_PRESUPUESTO.xlsx', 'Categorías', 23, 0, 23) on conflict (id) do nothing$$), 0,
  'Y reenviada: 0 filas');

-- ---------------------------------------------------------------- configuración y plan (se pueden editar)
select pruebas.igual(pruebas.afecta($$insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
  values ('c3000000-0000-4000-8000-0000000000f9', 'b0000000-0000-4000-8000-000000000001',
          pruebas.libro_personal('ana@ejemplo.test'), 'Vales', 'efectivo') on conflict (id) do nothing$$), 1,
  'Cuenta nueva desde la cola');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
  values ('c3000000-0000-4000-8000-0000000000f9', 'b0000000-0000-4000-8000-000000000001',
          pruebas.libro_personal('ana@ejemplo.test'), 'Vales', 'efectivo') on conflict (id) do nothing$$), 0,
  'Reenviada: 0 filas');
select pruebas.falla($$insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
  values ('c3000000-0000-4000-8000-0000000000f9', 'b0000000-0000-4000-8000-000000000001',
          pruebas.libro_personal('ana@ejemplo.test'), 'Vales de despensa', 'efectivo')$$,
  'Sin ON CONFLICT, el mismo id con otro nombre choca con la llave (se edita con UPDATE)', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_partidas_semana (id, hogar_id, semana_id, origen, origen_id,
  cuenta_gasto_id, tipo, asignado, prioridad, modo_arrastre, protegida)
  values ('e7000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000001',
          'e6000000-0000-4000-8000-000000000001', 'sobre', 'e4000000-0000-4000-8000-000000000003',
          'c2000000-0000-4000-8000-000000000004', 'variable', 70000, 'necesario', 'arrastrar', false)
  on conflict (id) do nothing$$), 0,
  'Una partida ya guardada se reenvía sin error aunque su semana ya esté cerrada');

rollback;
