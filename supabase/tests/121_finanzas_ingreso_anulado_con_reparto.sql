-- Finanzas · Fase 8, paquete F8-6.9: ingreso anulado con reparto (migración 20261151; hallazgo H-03; decisión del dueño del
-- 20/nov/2026: opción B con alternativa A; docs/specs/fase-8-finanzas-dispersion.md): anular el ingreso NO deshace nada solo; la app
-- puede saber qué repartos anulados tienen movimientos vigentes (fin_repartos_anulados_con_movimientos), deshacerlos
-- (fin_deshacer_reparto_anulado, con contraasiento y motivo) o dejarlos así (fin_dejar_reparto_anulado), con permisos por rol,
-- idempotencia, libro de Papá en su nombre y con motivo, y un aviso nuevo sin cifras (D20).
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente de Papá), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra), Elena (otro hogar).
begin;

create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;
insert into t_ids values ('ana', pruebas.libro_personal('ana@ejemplo.test'));
create temp table t_f (f date);
grant all on t_f to public;
insert into t_f select ((now() at time zone 'America/Mexico_City')::date) - 2;
create temp table t_n (clave text primary key, n bigint);
grant all on t_n to public;
create temp table t_sol (id uuid);
grant all on t_sol to public;

-- ---------------------------------------------------------------- 0: preparación
select pruebas.como_postgres();
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9300000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', 'Préstamo de Papá (anulado)', 'prestamo');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, minimo_centavos, tasa_anual_pb) values
  ('e9300000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   'Préstamo de Papá (anulado)', 'con_costo', 'prestamo', 'c9300000-0000-4000-8000-000000000001', 20000, 'mensual', 10000, 1200);

-- Ingresos de Ana (Banco c3…01, Extras c3…06, Ahorro c3…07). I1 se anulará con reparto; I2 queda vigente (control); I3 se deshace
-- por la vía normal; I4 se anulará y se dejará así; I5 se anulará sin reparto.
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 900000, (select f from t_f), p_id => 'd9300000-0000-4000-8000-000000000001');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 500000, (select f from t_f), p_id => 'd9300000-0000-4000-8000-000000000002');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 600000, (select f from t_f), p_id => 'd9300000-0000-4000-8000-000000000003');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 400000, (select f from t_f), p_id => 'd9300000-0000-4000-8000-000000000004');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 300000, (select f from t_f), p_id => 'd9300000-0000-4000-8000-000000000005');
-- Papá (Ana es albacea): en su nombre y con motivo. Su cuenta c6…01, ahorro c6…02, origen pensión c6…03.
select pruebas.registrar('ingreso', 'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 1000000, (select f from t_f),
  p_id => 'd9300000-0000-4000-8000-000000000011', p_motivo => 'Pensión del mes (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
select public.fin_dispersion_parametros_cambiar('f1000000-0000-4000-8000-000000000002', 'confirmacion', null, null, null, false, 'Activo el reparto de Papá');

select public.fin_confirmar_dispersion($j${
  "id": "a9300000-0000-4000-8000-000000000001", "movimiento_id": "d9300000-0000-4000-8000-000000000001", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 150000,
     "movimiento_id": "b9300000-0000-4000-8000-000000000001"},
    {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b9300000-0000-4000-8000-000000000002"},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 150000}]}$j$::jsonb);
select public.fin_confirmar_dispersion($j${
  "id": "a9300000-0000-4000-8000-000000000002", "movimiento_id": "d9300000-0000-4000-8000-000000000002", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b9300000-0000-4000-8000-000000000003"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 400000}]}$j$::jsonb);
select public.fin_confirmar_dispersion($j${
  "id": "a9300000-0000-4000-8000-000000000003", "movimiento_id": "d9300000-0000-4000-8000-000000000003", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b9300000-0000-4000-8000-000000000004"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 500000}]}$j$::jsonb);
select public.fin_confirmar_dispersion($j${
  "id": "a9300000-0000-4000-8000-000000000004", "movimiento_id": "d9300000-0000-4000-8000-000000000004", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 50000, "movimiento_id": "b9300000-0000-4000-8000-000000000005"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 350000}]}$j$::jsonb);
select public.fin_confirmar_dispersion($j${
  "id": "a9300000-0000-4000-8000-000000000011", "movimiento_id": "d9300000-0000-4000-8000-000000000011", "motivo": "Pensión repartida por la albacea",
  "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 200000, "movimiento_id": "b9300000-0000-4000-8000-000000000011"},
             {"destino": "abono_extra", "referencia_id": "e9300000-0000-4000-8000-000000000001", "etiqueta": "Préstamo de Papá", "monto_centavos": 100000,
              "movimiento_id": "b9300000-0000-4000-8000-000000000012"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}$j$::jsonb);
-- I3: se deshace por la vía normal (ni su ingreso ni nada más se anula).
select public.fin_deshacer_dispersion('a9300000-0000-4000-8000-000000000003', 'Me equivoqué de reparto');

-- ---------------------------------------------------------------- 1: estructura y privilegios
select pruebas.como_postgres();
select pruebas.ok(has_function_privilege('authenticated', 'public.fin_repartos_anulados_con_movimientos(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.fin_deshacer_reparto_anulado(uuid, text)', 'execute')
  and has_function_privilege('authenticated', 'public.fin_dejar_reparto_anulado(uuid)', 'execute'), '1: las tres RPC son para authenticated');
select pruebas.ok(not has_function_privilege('anon', 'public.fin_repartos_anulados_con_movimientos(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.fin_deshacer_reparto_anulado(uuid, text)', 'execute')
  and not has_function_privilege('anon', 'public.fin_dejar_reparto_anulado(uuid)', 'execute'), '1: y no para anon');
select pruebas.ok(not has_table_privilege('authenticated', 'public.fin_dispersion_descartes', 'insert')
  and not has_table_privilege('authenticated', 'public.fin_dispersion_descartes', 'update')
  and not has_table_privilege('authenticated', 'public.fin_dispersion_descartes', 'delete')
  and has_table_privilege('authenticated', 'public.fin_dispersion_descartes', 'select'), '1: la tabla de decisiones es de solo lectura para la app (escribe la RPC)');
select pruebas.ok((select relrowsecurity from pg_class where oid = 'public.fin_dispersion_descartes'::regclass), '1: con RLS');
select pruebas.ok(exists (select 1 from pg_trigger g where g.tgrelid = 'public.fin_dispersion_descartes'::regclass and g.tgname = 'fin_solo_agregar'),
  '1: solo-agregar (sin UPDATE ni DELETE)');

-- ---------------------------------------------------------------- 2: anular el ingreso NO deshace nada solo (opción B)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))), 0,
  '2: antes de anular el ingreso no hay nada que avisar');
select pruebas.como_postgres();
insert into t_n select 'mov_antes', count(*) from public.fin_movimientos;
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006', 900000, (select f from t_f),
  'Lo registré dos veces', 'd9300000-0000-4000-8000-000000000001');
select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006', 400000, (select f from t_f),
  'Lo registré dos veces', 'd9300000-0000-4000-8000-000000000004');
select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006', 300000, (select f from t_f),
  'Lo registré dos veces', 'd9300000-0000-4000-8000-000000000005');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos) - (select n::int from t_n where clave = 'mov_antes'), 3,
  '2: anular tres ingresos agrega solo las tres anulaciones (el servidor no deshace nada por su cuenta)');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in
    ('b9300000-0000-4000-8000-000000000001', 'b9300000-0000-4000-8000-000000000002', 'b9300000-0000-4000-8000-000000000005')), 0,
  '2: el abono extra y los ahorros que creó el reparto siguen vigentes (sin contraasiento)');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a9300000-0000-4000-8000-000000000001'), 'anulada',
  '2: el reparto pasó a anulada');
select pruebas.igual((select (detalle ->> 'movimientos_vigentes')::int from public.bitacora where accion = 'finanzas.dispersion_anulada'
    and registro_id = 'a9300000-0000-4000-8000-000000000001'), 2, '2: la bitácora ya lo decía (y ahora la app puede saberlo)');

-- ---------------------------------------------------------------- 3: lectura: qué repartos anulados tienen movimientos vigentes
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select string_agg(dispersion_id::text || ':' || movimientos_vigentes::text, ',' order by dispersion_id)
    from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))),
  'a9300000-0000-4000-8000-000000000001:2,a9300000-0000-4000-8000-000000000004:1',
  '3: Ana ve los repartos de I1 (2 movimientos) e I4 (1); no el de I2 (vigente), ni el de I3 (deshecho por la vía normal), ni I5 (sin reparto)');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos()), 2,
  '3: sin libro, los de todos los libros que ve (el de Papá aún no se anula)');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd9300000-0000-4000-8000-000000000001'), 1, '3: la fila trae el ingreso');
-- Papá: se anula su ingreso en su nombre.
select pruebas.registrar('anulacion', 'c6000000-0000-4000-8000-000000000001', 'c6000000-0000-4000-8000-000000000003', 1000000, (select f from t_f),
  'Pensión capturada dos veces (ejemplo)', 'd9300000-0000-4000-8000-000000000011', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
select pruebas.igual((select movimientos_vigentes from public.fin_repartos_anulados_con_movimientos('f1000000-0000-4000-8000-000000000002')), 2,
  '3: Ana (albacea) ve el reparto anulado del libro de Papá, con sus 2 movimientos');

-- ---------------------------------------------------------------- 4: permisos de lectura por rol
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))$$, '4: la pareja no lee los repartos del libro personal de Ana', '42501');
select pruebas.igual((select string_agg(libro_id::text, ',') from public.fin_repartos_anulados_con_movimientos()), 'f1000000-0000-4000-8000-000000000002',
  '4: y sin libro solo ve el de Papá (es su suplente), ninguno del libro de Ana');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))$$, '4: la familiar no lee', '42501');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos()), 0, '4: y sin libro ve cero');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))$$, '4: la cuidadora no lee', '42501');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos()), 0, '4: y sin libro ve cero');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))$$, '4: la tablet de la casa no lee', '42501');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos()), 0, '4: y sin libro ve cero');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))$$, '4: otro hogar no lee', '42501');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos()), 0, '4: y sin libro ve cero');
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos()$$, '4: anon no llama la RPC', '42501');
-- La familiar con la vista temporal de Papá (D24) no ve repartos.
select pruebas.como('carla@ejemplo.test');
insert into t_sol select public.fin_pedir_vista_papa('Revisar la pensión');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol), 'autorizar');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), true, '4: la familiar tiene la vista temporal de Papá vigente');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos('f1000000-0000-4000-8000-000000000002')$$, '4 (D24): la vista temporal de Papá no lee repartos', '42501');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000011', 'Con la vista temporal')$$, '4 (D24): ni deshace', '42501');
select pruebas.falla($$select public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000011')$$, '4 (D24): ni deja así', '42501');
-- Cuenta maestra (D19): solo lectura, y con consulta vigente.
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select * from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))$$, '4 (D19): la maestra sin consulta no lee', '42501');
select public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'ana'));
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))), 2,
  '4 (D19): con consulta vigente la maestra lee');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Lo intento yo')$$, '4 (D19): la maestra es de solo lectura: no deshace', '42501');
select pruebas.falla($$select public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000001')$$, '4 (D19): ni deja así', '42501');

-- ---------------------------------------------------------------- 5: permisos de escritura por rol
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Lo hago yo')$$, '5: la pareja no deshace el reparto del libro personal de Ana', '42501');
select pruebas.falla($$select public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000001')$$, '5: ni lo deja así', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Lo hago yo')$$, '5: la familiar no deshace', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Lo hago yo')$$, '5: la cuidadora no deshace', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Lo hago yo')$$, '5: la tablet de la casa no deshace', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Lo hago yo')$$, '5: otro hogar no deshace', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'x')$$, '5: anon no deshace', '42501');
select pruebas.falla($$select public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000001')$$, '5: anon no deja así', '42501');
-- Papá: el suplente (Alex) no escribe mientras haya albacea.
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000011', 'Lo hago yo, suplente')$$, '5 (I4): el suplente no deshace mientras haya albacea', '42501');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in
    ('b9300000-0000-4000-8000-000000000001', 'b9300000-0000-4000-8000-000000000002', 'b9300000-0000-4000-8000-000000000011', 'b9300000-0000-4000-8000-000000000012')), 0,
  '5: los intentos ajenos no tocaron ningún movimiento');
select pruebas.igual((select count(*)::int from public.fin_dispersion_descartes), 0, '5: ni dejaron decisiones');

-- ---------------------------------------------------------------- 6: validaciones
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000002', 'Quiero deshacerlo')$$,
  '6: un reparto vigente (su ingreso sigue vivo) no se deshace por aquí: usa «Deshacer reparto»', '55000');
select pruebas.falla($$select public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000002')$$, '6: ni se «deja así» un reparto vigente', '55000');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000003', 'Otra vez')$$,
  '6: un reparto deshecho por la vía normal (su ingreso sigue vivo) tampoco: esta RPC no sirve para anular otros movimientos', '55000');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-0000000000ff', 'No existe')$$, '6: un reparto que no existe se trata como sin permiso', '42501');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'ab')$$, '6: un motivo de 2 caracteres se rechaza', '22023');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', repeat('x', 201))$$, '6: ni uno de 201', '22023');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))), 2,
  '6: ningún rechazo cambió lo pendiente');

-- ---------------------------------------------------------------- 7: deshacer: anula exactamente los movimientos del reparto
select pruebas.como_postgres();
delete from t_n where clave = 'mov_antes';
insert into t_n select 'mov_antes', count(*) from public.fin_movimientos;
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Anulé el ingreso: deshago su reparto') ->> 'movimientos_anulados')::int, 2,
  '7: Ana deshace el reparto de I1: 2 movimientos anulados');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos) - (select n::int from t_n where clave = 'mov_antes'), 2,
  '7: se agregaron exactamente 2 anulaciones (ninguna otra cosa se tocó)');
select pruebas.igual((select string_agg(anula_a::text, ',' order by anula_a) from public.fin_movimientos
    where anula_a in ('b9300000-0000-4000-8000-000000000001', 'b9300000-0000-4000-8000-000000000002', 'b9300000-0000-4000-8000-000000000003',
                      'b9300000-0000-4000-8000-000000000005', 'b9300000-0000-4000-8000-000000000011', 'b9300000-0000-4000-8000-000000000012')),
  'b9300000-0000-4000-8000-000000000001,b9300000-0000-4000-8000-000000000002',
  '7: son el abono extra y el ahorro de I1; los de I2 (vigente), I4 (anulado, aún sin decidir) y Papá siguen vigentes');
select pruebas.ok(not exists (select 1 from public.fin_movimientos a join public.fin_movimientos m on m.id = a.anula_a
    where a.anula_a in ('b9300000-0000-4000-8000-000000000001', 'b9300000-0000-4000-8000-000000000002')
      and not (a.tipo = 'anulacion' and a.fecha = m.fecha and a.monto_centavos = m.monto_centavos
               and a.cuenta_origen_id = m.cuenta_destino_id and a.cuenta_destino_id = m.cuenta_origen_id
               and a.motivo = 'Anulé el ingreso: deshago su reparto')),
  '7: son contraasientos de la misma fecha y monto, con el motivo');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a9300000-0000-4000-8000-000000000001'), 'anulada',
  '7: el reparto sigue anulado (el historial se conserva; nada se borró)');
select pruebas.igual((select count(*)::int from public.fin_dispersion_lineas where dispersion_id = 'a9300000-0000-4000-8000-000000000001'), 4,
  '7: y conserva sus renglones');
select pruebas.ok(exists (select 1 from public.bitacora b where b.accion = 'finanzas.dispersion_anulada_deshecha' and b.registro_id = 'a9300000-0000-4000-8000-000000000001'
    and (b.detalle ->> 'movimientos_anulados')::int = 2), '7: la bitácora registra el deshacer');
select pruebas.ok(not exists (select 1 from public.bitacora b, jsonb_object_keys(b.detalle) k
    where b.accion = 'finanzas.dispersion_anulada_deshecha'
      and k not in ('libro_id', 'movimiento_id', 'movimientos_anulados', 'en_nombre_de', 'motivo')),
  '7 (D20): la bitácora solo lleva ids, el conteo y el motivo: sin montos ni etiquetas');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select string_agg(dispersion_id::text, ',') from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))),
  'a9300000-0000-4000-8000-000000000004', '7: I1 deja de estar pendiente; queda I4');

-- ---------------------------------------------------------------- 8: idempotencia
select pruebas.como_postgres();
delete from t_n where clave = 'mov_antes';
insert into t_n select 'mov_antes', count(*) from public.fin_movimientos;
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001', 'Anulé el ingreso: deshago su reparto') ->> 'movimientos_anulados')::int, 0,
  '8: repetir el deshacer no anula nada más');
select pruebas.igual((public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000001') ->> 'movimientos_anulados')::int, 0,
  '8: ni con otro motivo, ni sin motivo');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos), (select n::int from t_n where clave = 'mov_antes')::int, '8: no se agregó ningún movimiento');
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'finanzas.dispersion_anulada_deshecha' and registro_id = 'a9300000-0000-4000-8000-000000000001'), 1,
  '8: y la bitácora no se repite');

-- ---------------------------------------------------------------- 9: «dejarlo así» (opción B): no toca dinero y no vuelve a aparecer
select pruebas.como_postgres();
delete from t_n where clave = 'mov_antes';
insert into t_n select 'mov_antes', count(*) from public.fin_movimientos;
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000004') ->> 'dejado')::boolean, true, '9: Ana deja así el reparto de I4');
select pruebas.igual((public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000004') ->> 'dejado')::boolean, true, '9: repetirlo es idempotente');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos((select id from t_ids where clave = 'ana'))), 0, '9: ya no aparece');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos()), 1, '9: sin libro, solo queda el de Papá');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos), (select n::int from t_n where clave = 'mov_antes')::int, '9: no se tocó dinero');
select pruebas.igual((select count(*)::int from public.fin_dispersion_descartes where dispersion_id = 'a9300000-0000-4000-8000-000000000004'), 1, '9: una sola decisión guardada');
select pruebas.ok((select en_nombre_de is null and decidido_por = pruebas.id_persona('ana@ejemplo.test') from public.fin_dispersion_descartes where dispersion_id = 'a9300000-0000-4000-8000-000000000004'),
  '9: quedó quién decidió (y no es en nombre de nadie en un libro personal)');
select pruebas.falla($$update public.fin_dispersion_descartes set decidido_en = now()$$, '9: solo-agregar: sin UPDATE', '42501');
select pruebas.falla($$delete from public.fin_dispersion_descartes$$, '9: ni DELETE', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.fin_dispersion_descartes (hogar_id, libro_id, dispersion_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', 'a9300000-0000-4000-8000-000000000011')$$,
  '9: nadie escribe la tabla directo', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_dispersion_descartes), 0, '9: la familiar no ve las decisiones');
-- Un reparto que se deja así todavía se puede deshacer después (la persona cambia de idea): el dinero manda, no el aviso.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000004') ->> 'movimientos_anulados')::int, 1,
  '9: lo que se dejó así aún puede deshacerse más tarde (sin motivo, en un libro personal, usa el motivo por omisión)');

-- ---------------------------------------------------------------- 10: libro de Papá (D19): en su nombre y con motivo
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000011')$$, '10 (D19): en el libro de Papá, sin motivo se rechaza', '22023');
select pruebas.falla($$select public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000011', 'ab')$$, '10: ni con 2 caracteres', '22023');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b9300000-0000-4000-8000-000000000011', 'b9300000-0000-4000-8000-000000000012')), 0,
  '10: los rechazos no tocan el dinero de Papá');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.fin_deshacer_reparto_anulado('a9300000-0000-4000-8000-000000000011', 'Anulé la pensión: deshago el reparto') ->> 'movimientos_anulados')::int, 2,
  '10: con motivo, la albacea deshace el reparto de Papá');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b9300000-0000-4000-8000-000000000011', 'b9300000-0000-4000-8000-000000000012')
    and en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and motivo = 'Anulé la pensión: deshago el reparto'), 2,
  '10: las anulaciones van en nombre de Papá y con el motivo');
select pruebas.ok(exists (select 1 from public.bitacora b where b.accion = 'finanzas.dispersion_anulada_deshecha' and b.registro_id = 'a9300000-0000-4000-8000-000000000011'
    and b.detalle ->> 'en_nombre_de' = 'e0000000-0000-4000-8000-000000000001' and b.detalle ->> 'motivo' = 'Anulé la pensión: deshago el reparto'),
  '10: la bitácora lo registra en nombre de Papá, con el motivo');
-- «Dejar así» en el libro de Papá queda en su nombre. Se prueba con otro ingreso anulado con reparto.
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('ingreso', 'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 800000, (select f from t_f),
  p_id => 'd9300000-0000-4000-8000-000000000012', p_motivo => 'Otra pensión (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
select public.fin_confirmar_dispersion($j${
  "id": "a9300000-0000-4000-8000-000000000012", "movimiento_id": "d9300000-0000-4000-8000-000000000012", "motivo": "Reparto de la segunda pensión",
  "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b9300000-0000-4000-8000-000000000013"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}$j$::jsonb);
select pruebas.registrar('anulacion', 'c6000000-0000-4000-8000-000000000001', 'c6000000-0000-4000-8000-000000000003', 800000, (select f from t_f),
  'Capturada por error (ejemplo)', 'd9300000-0000-4000-8000-000000000012', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos('f1000000-0000-4000-8000-000000000002')), 1, '10: el segundo ingreso de Papá aparece');
select public.fin_dejar_reparto_anulado('a9300000-0000-4000-8000-000000000012');
select pruebas.como_postgres();
select pruebas.igual((select en_nombre_de from public.fin_dispersion_descartes where dispersion_id = 'a9300000-0000-4000-8000-000000000012'),
  'e0000000-0000-4000-8000-000000000001', '10: «dejarlo así» en el libro de Papá queda en su nombre');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_repartos_anulados_con_movimientos('f1000000-0000-4000-8000-000000000002')), 0, '10: y ya no aparece');

-- ---------------------------------------------------------------- 11: avisos (D20): «Un ingreso anulado tenía reparto», sin cifras
select pruebas.como_postgres();
select pruebas.igual(public.avisos_severidad('ingreso_anulado_con_reparto'), 'informativa', '11: el aviso es informativo');
select pruebas.ok(public.avisos_tipo_emitible('ingreso_anulado_con_reparto') and public.avisos_tipo_emitible('ingreso_por_repartir')
  and not public.avisos_tipo_emitible('compra_papa_albacea'), '11: la app lo emite y los demás tipos siguen igual');
select pruebas.igual(public.avisos_severidad('transferencia_pendiente') || public.avisos_severidad('deuda_se_volvio_mala') || public.avisos_severidad('fuga_por_reconocer'),
  'importantecriticaimportante', '11: los tipos previos conservan su severidad');
select pruebas.igual(public.fin_dispersion_aviso_titulo('ingreso_anulado_con_reparto'), 'Un ingreso anulado tenía reparto', '11: el título genérico del catálogo');
select pruebas.igual(public.fin_dispersion_aviso_titulo('ingreso_por_repartir'), 'Tienes un ingreso por repartir', '11: el título del aviso anterior no cambió');
select pruebas.ok(public.avisos_texto_valido(public.fin_dispersion_aviso_titulo('ingreso_anulado_con_reparto'))
  and public.fin_dispersion_aviso_titulo('ingreso_anulado_con_reparto') !~ '[0-9$]'
  and char_length(public.fin_dispersion_aviso_titulo('ingreso_anulado_con_reparto')) <= 40,
  '11 (D20): sin dígitos, sin $ y de hasta 40 caracteres');
select pruebas.ok(public.fin_dispersion_aviso_titulo('pago_proximo') is null, '11: solo describe sus propios tipos');
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'avisos'
    and (column_name ilike '%monto%' or column_name ilike '%centavos%' or column_name ilike '%titulo%' or column_name ilike '%texto%' or column_name ilike '%cuerpo%' or column_name ilike '%nombre%')),
  '11: la tabla de avisos sigue sin columnas de texto, monto ni nombre');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000001',
    'ingreso:d9300000-0000-4000-8000-000000000001:anulado_con_reparto'), 1, '11: Ana emite el aviso del ingreso anulado y solo le llega a ella (libro personal)');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000001',
    'ingreso:d9300000-0000-4000-8000-000000000001:anulado_con_reparto'), 0, '11: repetirlo no duplica (misma clave)');
select pruebas.igual((select tipo || '/' || severidad || '/' || objeto_tipo from public.avisos where clave = 'ingreso:d9300000-0000-4000-8000-000000000001:anulado_con_reparto'),
  'ingreso_anulado_con_reparto/informativa/movimiento', '11: informativo y con el ingreso por objeto');
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'ingreso_anulado_con_reparto' and persona_id = pruebas.id_persona('alex@ejemplo.test')), 0,
  '11: Alex no recibe el del libro de Ana');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', null, null, 'ingreso:x:1')$$, '11: sin ingreso por objeto se rechaza', '22023');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000002', 'ingreso:x:2')$$,
  '11: un ingreso cuyo reparto no está anulado se rechaza', '22023');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000005', 'ingreso:x:3')$$,
  '11: ni un ingreso anulado que nunca se repartió', '22023');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'libro', (select id from t_ids where clave = 'ana'), 'ingreso:x:4')$$,
  '11: ni con un objeto que no es un movimiento', '22023');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000001', 'ingreso:x:5')$$, '11: la familiar no emite', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000001', 'ingreso:x:6')$$, '11: ni la cuidadora', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_anulado_con_reparto', 'movimiento', 'd9300000-0000-4000-8000-000000000001', 'ingreso:x:7')$$, '11: ni la maestra (solo lee)', '42501');
-- Se puede silenciar; uno inventado no; los anteriores siguen valiendo.
select pruebas.como('ana@ejemplo.test');
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['ingreso_anulado_con_reparto', 'ingreso_por_repartir']);
select pruebas.igual((select tipos_silenciados from public.avisos_preferencias where persona_id = public.persona_actual()), array['ingreso_anulado_con_reparto', 'ingreso_por_repartir'],
  '11: Ana silencia el aviso nuevo (sigue en la bandeja)');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['ingreso_inventado'])$$, '11: un tipo desconocido se rechaza', '22023');
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['hab_bloque', 'deuda_en_vigilancia']);
select pruebas.igual((select tipos_silenciados from public.avisos_preferencias where persona_id = public.persona_actual()), array['hab_bloque', 'deuda_en_vigilancia'],
  '11: los tipos de Hábitos y de fugas siguen válidos');

rollback;
