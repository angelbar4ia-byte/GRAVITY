-- Criterio 24 (T9): una semana sin cerrar se cierra con pendientes marcados y
-- se puede reabrir (queda en la bitácora); al volver a cerrar se guarda la
-- versión siguiente del cierre. Una semana cerrada no cambia su plan.
-- (El cierre automático a los 3 días lo decide la app; el servidor guarda la
-- foto con con_pendientes y protege la semana.)
begin;
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- reglas de la semana
select pruebas.falla($$insert into public.fin_semanas (hogar_id, libro_id, semana_inicio)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), '2026-10-21')$$,
  'La semana empieza en lunes', '23514');
select pruebas.falla($$insert into public.fin_semanas (hogar_id, libro_id, semana_inicio)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), '2026-10-19')$$,
  'Una semana por libro', '23505');
select pruebas.falla($$insert into public.fin_semanas (hogar_id, libro_id, semana_inicio, ingreso, presupuesto,
  deuda_plan, remanente_plan)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), '2026-10-26',
          100000, 50000, 10000, 40001)$$,
  'La cascada cuadra: remanente = ingreso − presupuesto − deuda', '23514');
select pruebas.falla($$insert into public.fin_semanas (hogar_id, libro_id, semana_inicio, estado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), '2026-10-26', 'cerrada')$$,
  'Una semana no nace cerrada', '22023');
select pruebas.igual(pruebas.afecta($$insert into public.fin_semanas (id, hogar_id, libro_id, semana_inicio, estado,
  activada_por)
  values ('e6000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001',
          pruebas.libro_personal('ana@ejemplo.test'), '2026-10-26', 'borrador', pruebas.id_persona('alex@ejemplo.test'))$$), 1,
  'Ana arma el borrador de la semana del 26/oct');
select pruebas.ok(
  (select activada_por is null and activada_en is null from public.fin_semanas where id = 'e6000000-0000-4000-8000-000000000003'),
  'Un borrador no está activado (el servidor ignora el activada_por que mande la app)');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'activa'
  where id = 'e6000000-0000-4000-8000-000000000003'$$), 1, 'Activa la semana');
select pruebas.ok(
  (select activada_por = pruebas.id_persona('ana@ejemplo.test') and activada_en is not null
     from public.fin_semanas where id = 'e6000000-0000-4000-8000-000000000003'),
  'Quién y cuándo activó la semana los pone el servidor');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_semanas (hogar_id, libro_id, semana_inicio)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), '2026-10-19')$$), 1,
  'Alex tiene su propia semana del 19/oct en su libro');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'por_cerrar'
  where id = 'e6000000-0000-4000-8000-000000000002'$$), 0, 'Alex no toca la semana de Ana');
select pruebas.falla($$insert into public.fin_cierres (hogar_id, semana_id, version, ingreso_real, gasto_real,
  activos, pasivos, patrimonio)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002', 1, 0, 0, 0, 0, 0)$$,
  'Ni la cierra', '42501');

-- ---------------------------------------------------------------- cierre con pendientes
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.fin_semanas set estado = 'cerrada' where id = 'e6000000-0000-4000-8000-000000000002'$$,
  'Antes de cerrar se guarda el cierre', '55000');
select pruebas.falla($$insert into public.fin_cierres (hogar_id, semana_id, version, ingreso_real, gasto_real,
  activos, pasivos, patrimonio)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002', 2, 0, 0, 0, 0, 0)$$,
  'La primera foto es la versión 1', '22023');
select pruebas.falla($$insert into public.fin_cierres (hogar_id, semana_id, version, ingreso_real, gasto_real,
  activos, pasivos, patrimonio)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002', 1, 0, 0, 100, 10, 1)$$,
  'La foto del balance cuadra: patrimonio = activos − pasivos', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cierres (id, hogar_id, semana_id, version, ingreso_real,
  gasto_real, abono_real, abono_diferido, accion_elegida, con_pendientes, activos, pasivos, patrimonio)
  values ('e9000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
          'e6000000-0000-4000-8000-000000000002', 1, 415385, 21000, 20000, 19231, 'ninguna', true,
          1964000, 870000, 1094000)$$), 1,
  'Cierre automático (sin cerrar en 3 días): foto con pendientes marcados');
select pruebas.igual(
  (select libro_id from public.fin_cierres where id = 'e9000000-0000-4000-8000-000000000002'),
  pruebas.libro_personal('ana@ejemplo.test'), 'El cierre va en el libro de su semana (lo pone el servidor)');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cierre_abonos (hogar_id, cierre_id, deuda_id, planeado, "real", minimo)
  values ('b0000000-0000-4000-8000-000000000001', 'e9000000-0000-4000-8000-000000000002',
          'e5000000-0000-4000-8000-000000000001', 27692, 8461, 10385)$$), 1,
  'Guarda el abono real de la tarjeta');
select pruebas.igual(
  (select diferido from public.fin_cierre_abonos where cierre_id = 'e9000000-0000-4000-8000-000000000002'),
  19231::bigint, 'El abono diferido lo calcula el servidor (planeado − real)');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'cerrada'
  where id = 'e6000000-0000-4000-8000-000000000002'$$), 1, 'Con su cierre guardado, la semana se cierra');
select pruebas.igual(
  (select c.con_pendientes from public.fin_cierres c where c.semana_id = 'e6000000-0000-4000-8000-000000000002'),
  true, 'La semana quedó cerrada con pendientes marcados');

-- ---------------------------------------------------------------- cerrada: nada cambia
select pruebas.falla($$update public.fin_semanas set techo = 1 where id = 'e6000000-0000-4000-8000-000000000002'$$,
  'Una semana cerrada no cambia', '55000');
select pruebas.falla($$update public.fin_partidas_semana set asignado = 1
  where id = 'e7000000-0000-4000-8000-000000000012'$$, 'Ni sus partidas', '55000');
select pruebas.falla($$insert into public.fin_partidas_semana (hogar_id, semana_id, origen, origen_id, tipo, asignado)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002', 'sobre',
          'e4000000-0000-4000-8000-000000000003', 'variable', 1)$$, 'Ni se le agregan partidas', '55000');
select pruebas.falla($$insert into public.fin_abonos_semana (hogar_id, semana_id, deuda_id, abono_planeado)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002',
          'e5000000-0000-4000-8000-000000000002', 1)$$, 'Ni abonos', '55000');
select pruebas.falla($$insert into public.fin_cierres (hogar_id, semana_id, version, ingreso_real, gasto_real,
  activos, pasivos, patrimonio)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002', 2, 0, 0, 0, 0, 0)$$,
  'Para volver a cerrarla hay que reabrirla', '55000');
select pruebas.falla($$insert into public.fin_ocurrencias (hogar_id, libro_id, origen, origen_id, fecha_programada,
  fecha_ajustada, monto_esperado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'compromiso',
          'e3000000-0000-4000-8000-000000000006', '2026-10-20', '2026-10-20', 35000)$$,
  'Ni se agregan ocurrencias en esa semana', '55000');
select pruebas.igual(pruebas.afecta($$update public.fin_ocurrencias set estado = 'parcial'
  where id = 'ea000000-0000-4000-8000-000000000001'$$), 1,
  'En una semana cerrada, una ocurrencia sí cambia de estado (p. ej. un ingreso que llegó tarde)');
select pruebas.falla($$update public.fin_ocurrencias set monto_esperado = 1
  where id = 'ea000000-0000-4000-8000-000000000001'$$, 'Pero no su monto', '55000');

-- ---------------------------------------------------------------- reabrir
select pruebas.falla($$update public.fin_semanas set estado = 'por_cerrar', techo = 5
  where id = 'e6000000-0000-4000-8000-000000000002'$$, 'Al reabrir solo cambia el estado', '55000');
select pruebas.falla($$update public.fin_semanas set estado = 'borrador'
  where id = 'e6000000-0000-4000-8000-000000000002'$$, 'Una semana reabierta no vuelve a borrador', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'por_cerrar'
  where id = 'e6000000-0000-4000-8000-000000000002'$$), 1, 'Se reabre (la app pide confirmación)');
select pruebas.igual(
  (select reaperturas from public.fin_semanas where id = 'e6000000-0000-4000-8000-000000000002'),
  1::smallint, 'El servidor cuenta la reapertura');
select pruebas.ok(exists (
  select 1 from public.bitacora
   where tabla = 'fin_semanas' and registro_id = 'e6000000-0000-4000-8000-000000000002' and accion = 'actualizar'
     and detalle -> 'antes' ->> 'estado' = 'cerrada' and detalle -> 'despues' ->> 'estado' = 'por_cerrar'
     and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'La reapertura queda en la bitácora con quién la hizo');
select pruebas.igual(pruebas.afecta($$update public.fin_partidas_semana set asignado = 60000
  where id = 'e7000000-0000-4000-8000-000000000012'$$), 1, 'Reabierta, el plan se puede ajustar');

-- ---------------------------------------------------------------- volver a cerrar: versión 2
select pruebas.falla($$insert into public.fin_cierres (hogar_id, semana_id, version, ingreso_real, gasto_real,
  activos, pasivos, patrimonio)
  values ('b0000000-0000-4000-8000-000000000001', 'e6000000-0000-4000-8000-000000000002', 1, 0, 0, 0, 0, 0)$$,
  'La versión 1 ya existe: el cierre nuevo es la 2', '22023');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cierres (id, hogar_id, semana_id, version, ingreso_real,
  gasto_real, abono_real, accion_elegida, con_pendientes, activos, pasivos, patrimonio)
  values ('e9000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001',
          'e6000000-0000-4000-8000-000000000002', 2, 415385, 21000, 39231, 'abono_extra', false,
          1964000, 850769, 1113231)$$), 1, 'Se guarda la versión 2 del cierre');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'cerrada'
  where id = 'e6000000-0000-4000-8000-000000000002'$$), 1, 'Y se cierra otra vez');
select pruebas.igual(
  (select string_agg(version || ':' || con_pendientes || ':' || pasivos, ',' order by version)
     from public.fin_cierres where semana_id = 'e6000000-0000-4000-8000-000000000002'),
  '1:true:870000,2:false:850769', 'Las dos fotos quedan; la primera no cambió');

rollback;
