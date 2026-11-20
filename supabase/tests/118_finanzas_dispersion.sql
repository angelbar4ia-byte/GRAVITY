-- Finanzas · Fase 8, paquete F8-6.5: dispersión de ingresos con confirmación (migración 20261147;
-- docs/specs/fase-8-finanzas-dispersion.md, casos de servidor: RLS, unicidad por movimiento, suma de líneas,
-- idempotencia, anulación del ingreso, rechazo de la corrección de tipo si ya está repartido, libro de Papá, aviso sin cifras).
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente de Papá), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra), Elena (otro hogar).
-- Libros: personal de Ana y de Alex; compartido f100…0001 (Ana y Alex); Papá f100…0002 (Ana albacea, Alex suplente).
begin;

create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;
insert into t_ids values ('ana', pruebas.libro_personal('ana@ejemplo.test')), ('alex', pruebas.libro_personal('alex@ejemplo.test'));
-- Fecha de los ingresos de la prueba: hace dos días en la zona de México (dentro de la semana anterior o de la actual).
create temp table t_f (f date);
grant all on t_f to public;
insert into t_f select ((now() at time zone 'America/Mexico_City')::date) - 2;

-- ---------------------------------------------------------------- 0: preparación (como postgres)
select pruebas.como_postgres();
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c8700000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', 'Préstamo de Papá (dispersión)', 'prestamo'),
  ('c8700000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Sueldo casa (dispersión)', 'origen_ingreso'),
  ('c8700000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Extras casa (dispersión)', 'origen_ingreso');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, minimo_centavos, tasa_anual_pb) values
  ('e8700000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   'Préstamo de Papá (dispersión)', 'con_costo', 'prestamo', 'c8700000-0000-4000-8000-000000000001', 20000, 'mensual', 10000, 1200);

-- Ingresos de Ana (cuenta Banco de Ana c3…01; Extras c3…06; Sueldo de Ana c3…05; Ahorro de Ana c3…07; Tarjeta c3…03).
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 900000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000001');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000001', 500000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000002');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 300000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000003');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 700000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000004');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 400000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000005');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 250000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000006');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 150000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000008');
-- Un gasto (no es ingreso) para los rechazos.
select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 1000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000007');
-- Papá (Ana es albacea): en su nombre y con motivo.
select pruebas.registrar('ingreso', 'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 1000000, (select f from t_f),
  p_id => 'd8700000-0000-4000-8000-000000000011', p_motivo => 'Pensión del mes (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
select pruebas.registrar('ingreso', 'c6000000-0000-4000-8000-000000000004', 'c6000000-0000-4000-8000-000000000001', 600000, (select f from t_f),
  p_id => 'd8700000-0000-4000-8000-000000000012', p_motivo => 'Apoyo del mes (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
select pruebas.registrar('ingreso', 'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 300000, (select f from t_f),
  p_id => 'd8700000-0000-4000-8000-000000000013', p_motivo => 'Otra pensión (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
-- Compartido f100…0001 (Ana y Alex): cuenta de la casa c5…01.
select pruebas.registrar('ingreso', 'c8700000-0000-4000-8000-000000000003', 'c5000000-0000-4000-8000-000000000001', 800000, (select f from t_f), p_id => 'd8700000-0000-4000-8000-000000000021');

-- ---------------------------------------------------------------- 1: tablas, RLS y privilegios
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('fin_dispersiones', 'fin_dispersion_lineas') and c.relrowsecurity), 2,
  '1: las dos tablas nuevas tienen RLS');
select pruebas.igual((select count(*)::int from unnest(array['fin_dispersiones', 'fin_dispersion_lineas']) t
    where has_table_privilege('authenticated', 'public.' || t, 'insert') or has_table_privilege('authenticated', 'public.' || t, 'update')
       or has_table_privilege('authenticated', 'public.' || t, 'delete') or has_table_privilege('authenticated', 'public.' || t, 'truncate')
       or has_table_privilege('service_role', 'public.' || t, 'insert') or has_table_privilege('service_role', 'public.' || t, 'update')
       or has_table_privilege('service_role', 'public.' || t, 'delete') or has_table_privilege('service_role', 'public.' || t, 'truncate')
       or has_table_privilege('anon', 'public.' || t, 'select')), 0,
  '1: nadie escribe directo (solo RPC) y anon no lee');
select pruebas.ok(has_table_privilege('authenticated', 'public.fin_dispersiones', 'select')
  and has_table_privilege('authenticated', 'public.fin_dispersion_lineas', 'select')
  and has_table_privilege('authenticated', 'public.fin_v_dispersiones_vigentes', 'select'), '1: authenticated sí las lee (filtrado por RLS)');
select pruebas.ok(not exists (select 1 from pg_class c where c.relname = 'fin_v_dispersiones_vigentes' and not coalesce(c.reloptions @> array['security_invoker=true'], false)),
  '1: la vista de vigentes respeta la RLS de quien consulta');
select pruebas.igual((select count(*)::int from unnest(array['public.fin_guardar_propuesta(jsonb)', 'public.fin_confirmar_dispersion(jsonb)',
      'public.fin_deshacer_dispersion(uuid, text)', 'public.fin_corregir_tipo_ingreso(uuid, uuid, text, uuid, uuid, uuid)',
      'public.fin_dispersion_parametros_cambiar(uuid, text, date, integer, bigint, boolean, text)', 'public.fin_ingresos_por_repartir(uuid)']) f
    where has_function_privilege('anon', f, 'execute') or not has_function_privilege('authenticated', f, 'execute')), 0,
  '1: las seis RPC son para authenticated y no para anon');
select pruebas.igual((select count(*)::int from unnest(array['public.fin_dispersion_registrar(jsonb, text)', 'public.fin_dispersion_exigir(uuid, text)',
      'public.fin_dispersion_json(uuid)', 'public.fin_dispersion_ingreso(uuid)', 'public.fin_dispersion_al_anular_ingreso()']) f
    where has_function_privilege('authenticated', f, 'execute') or has_function_privilege('anon', f, 'execute')), 0,
  '1: los ayudantes internos no son RPC');
select pruebas.ok(exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'fin_dispersiones_una_vigente'),
  '1: un único reparto vigente por movimiento (índice único parcial)');
select pruebas.igual((select count(*)::int from pg_trigger g where g.tgrelid in ('public.fin_dispersiones'::regclass, 'public.fin_dispersion_lineas'::regclass)
    and not g.tgisinternal and g.tgfoid = 'public.registrar_cambio_en_bitacora()'::regprocedure), 2, '1: las dos registran sus cambios en la bitácora');

-- ---------------------------------------------------------------- 2: guardar propuesta (borrador): sin movimientos
select pruebas.como('ana@ejemplo.test');
create temp table t_n (clave text primary key, n int);
grant all on t_n to public;
insert into t_n select 'mov_antes', count(*)::int from public.fin_movimientos;
select pruebas.igual((public.fin_guardar_propuesta($j${
  "id": "a8700000-0000-4000-8000-000000000001", "movimiento_id": "d8700000-0000-4000-8000-000000000001", "motivo": null,
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "pago_deuda", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 100000},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 300000}]}$j$::jsonb) ->> 'estado'),
  'propuesta', '2: guardar la propuesta devuelve el reparto en estado propuesta');
select pruebas.igual((select count(*)::int from public.fin_movimientos), (select n from t_n where clave = 'mov_antes'),
  '2: guardar una propuesta no crea movimientos');
select pruebas.igual((select count(*)::int from public.fin_dispersion_lineas where dispersion_id = 'a8700000-0000-4000-8000-000000000001'), 3,
  '2: y guarda sus tres renglones');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd8700000-0000-4000-8000-000000000001'), 'propuesta/900000', '2: el ingreso sigue pendiente completo con una propuesta');
-- Idempotente y reemplazable: el mismo id con otros renglones reemplaza los renglones.
select pruebas.igual((public.fin_guardar_propuesta($j${
  "id": "a8700000-0000-4000-8000-000000000001", "movimiento_id": "d8700000-0000-4000-8000-000000000001",
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 400000}]}$j$::jsonb) -> 'lineas' -> 1 ->> 'monto_centavos'),
  '400000', '2: guardar otra vez la misma propuesta reemplaza sus renglones');
select pruebas.igual((select count(*)::int from public.fin_dispersion_lineas where dispersion_id = 'a8700000-0000-4000-8000-000000000001'), 2,
  '2: y no deja los renglones viejos');
-- Otro id para el mismo ingreso: la propuesta vieja se anula (un único reparto vigente).
select public.fin_guardar_propuesta($j${
  "id": "a8700000-0000-4000-8000-000000000002", "movimiento_id": "d8700000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 900000}]}$j$::jsonb);
select pruebas.igual((select string_agg(estado, ',' order by id) from public.fin_dispersiones where movimiento_id = 'd8700000-0000-4000-8000-000000000001'),
  'anulada,propuesta', '2 (unicidad): la propuesta nueva reemplaza a la vieja: solo una vigente por movimiento');
select pruebas.igual((select count(*)::int from public.fin_v_dispersiones_vigentes where movimiento_id = 'd8700000-0000-4000-8000-000000000001'), 1,
  '2: la vista de vigentes muestra una');
-- Suma de renglones.
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 100}]}'::jsonb)$j$,
  '2 (suma): los renglones deben sumar el monto del ingreso', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 400000}]}'::jsonb)$j$,
  '2 (suma): ni de más', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "libre", "etiqueta": "L", "monto_centavos": 400000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": -100000}]}'::jsonb)$j$,
  '2: un monto negativo no entra', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "libre", "etiqueta": "L", "monto_centavos": 299999.5}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 0.5}]}'::jsonb)$j$,
  '2: ni con decimales (centavos enteros)', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "regalo", "etiqueta": "L", "monto_centavos": 300000}]}'::jsonb)$j$, '2: un destino fuera del catálogo se rechaza', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "libre", "etiqueta": "L", "monto_centavos": 100000}, {"destino": "libre", "etiqueta": "L2", "monto_centavos": 200000}]}'::jsonb)$j$,
  '2: dos renglones con el mismo destino y referencia se rechazan', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": []}'::jsonb)$j$, '2: sin renglones no hay reparto', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-0000000000ff", "etiqueta": "X", "monto_centavos": 300000}]}'::jsonb)$j$,
  '2: una deuda que no es de este libro se rechaza', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "abono_extra", "etiqueta": "X", "monto_centavos": 300000}]}'::jsonb)$j$,
  '2: un abono extra sin deuda se rechaza', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 1000}]}'::jsonb)$j$, '2 (criterio 15): un gasto no se reparte', '42501');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000009", "movimiento_id": "d8700000-0000-4000-8000-0000000000ee",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 1000}]}'::jsonb)$j$, '2: un movimiento que no existe tampoco', '42501');

-- ---------------------------------------------------------------- 3: confirmar: movimientos solo de abono extra y ahorro, idempotente
select pruebas.como('ana@ejemplo.test');
insert into t_n select 'mov_antes_confirmar', count(*)::int from public.fin_movimientos;
create temp table t_json (clave text primary key, j jsonb);
grant all on t_json to public;
insert into t_json values ('confirmar_1', $j${
  "id": "a8700000-0000-4000-8000-000000000003", "movimiento_id": "d8700000-0000-4000-8000-000000000001", "modo": "confirmacion",
  "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "pago_deuda", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 100000},
    {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 150000,
     "movimiento_id": "b8700000-0000-4000-8000-000000000001"},
    {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b8700000-0000-4000-8000-000000000002"},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 50000}]}$j$::jsonb);
select pruebas.igual((public.fin_confirmar_dispersion((select j from t_json where clave = 'confirmar_1')) ->> 'estado'), 'confirmada',
  '3 (criterio 8): confirmar devuelve el reparto confirmado');
select pruebas.igual((select count(*)::int from public.fin_movimientos) - (select n from t_n where clave = 'mov_antes_confirmar'), 2,
  '3: crea solo dos movimientos: el abono extra y el ahorro (el pago de deuda solo aparta, P4)');
select pruebas.igual((select tipo || ':' || monto_centavos::text || ':' || cuenta_origen_id::text || '>' || cuenta_destino_id::text
    from public.fin_movimientos where id = 'b8700000-0000-4000-8000-000000000001'),
  'pago_deuda:150000:c3000000-0000-4000-8000-000000000001>c3000000-0000-4000-8000-000000000003', '3: el abono extra es un pago de deuda del banco a la tarjeta');
select pruebas.igual((select tipo || ':' || monto_centavos::text || ':' || cuenta_destino_id::text from public.fin_movimientos where id = 'b8700000-0000-4000-8000-000000000002'),
  'transferencia:100000:c3000000-0000-4000-8000-000000000007', '3: el ahorro es una transferencia a la cuenta de ahorro');
select pruebas.igual((select count(*)::int from public.fin_dispersion_lineas where dispersion_id = 'a8700000-0000-4000-8000-000000000003' and movimiento_id is not null), 2,
  '3: solo dos renglones guardan el movimiento que crearon');
select pruebas.igual((select resuelta_por = public.persona_actual() and resuelta_en is not null and en_nombre_de is null
    from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000003'), true, '3: queda quién y cuándo lo confirmó');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000002'), 'anulada',
  '3: la propuesta que había quedó reemplazada');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd8700000-0000-4000-8000-000000000001'), 'confirmada/50000', '3: del ingreso confirmado solo queda por repartir el renglón sobrante');
-- Idempotencia (criterio 8).
select pruebas.igual((public.fin_confirmar_dispersion((select j from t_json where clave = 'confirmar_1')) ->> 'estado'), 'confirmada',
  '3 (idempotencia): repetir Aceptar devuelve el mismo reparto');
select pruebas.igual((select count(*)::int from public.fin_movimientos) - (select n from t_n where clave = 'mov_antes_confirmar'), 2,
  '3: y no duplica movimientos');
select pruebas.igual((select count(*)::int from public.fin_dispersiones where movimiento_id = 'd8700000-0000-4000-8000-000000000001' and estado = 'confirmada'), 1,
  '3: ni repartos');
-- Otro id para el mismo ingreso ya repartido; guardar propuesta sobre el mismo id confirmado.
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-0000000000aa", "movimiento_id": "d8700000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 900000}]}'::jsonb)$j$, '3 (unicidad): un ingreso ya repartido no admite otro reparto', '55000');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000003", "movimiento_id": "d8700000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 900000}]}'::jsonb)$j$, '3: ni volver a propuesta uno confirmado', '55000');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000003", "movimiento_id": "d8700000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 500000}]}'::jsonb)$j$, '3: el mismo id de otro ingreso es conflicto', '23505');
-- Ahorro y cuentas.
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000010", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 200000}]}'::jsonb)$j$,
  '3: un ahorro sin cuenta de ahorro se rechaza (queda por repartir)', '22023');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000010", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "cuenta_ahorro_id": "c4000000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 200000}]}'::jsonb)$j$,
  '3: ni una cuenta de ahorro de otro libro', '22023');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000010", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 200000}]}'::jsonb)$j$,
  '3: ni la misma cuenta donde entró el ingreso', '22023');
select pruebas.igual((select count(*)::int from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000010'), 0,
  '3: un rechazo no deja nada a medias (la transacción se revierte)');
-- Un renglón en cero no mueve dinero.
select pruebas.igual((public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000011", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 300000}, {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 0}]}$j$::jsonb) ->> 'estado'),
  'confirmada', '3: un ahorro en cero se confirma sin cuenta y sin movimiento');
select pruebas.igual((select count(*)::int from public.fin_movimientos) - (select n from t_n where clave = 'mov_antes_confirmar'), 2, '3: y sin movimientos nuevos');
-- Los ids de los movimientos pueden omitirse: el servidor los deriva y es estable.
select pruebas.igual((select count(*)::int from jsonb_array_elements(public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000012", "movimiento_id": "d8700000-0000-4000-8000-000000000006", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 250000}]}$j$::jsonb) -> 'lineas') l where l.value ->> 'movimiento_id' is not null), 1,
  '3: sin movimiento_id en el renglón, el servidor deriva uno estable');
select public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000012", "movimiento_id": "d8700000-0000-4000-8000-000000000006", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 250000}]}$j$::jsonb);
select pruebas.igual((select count(*)::int from public.fin_movimientos where nota = 'Ahorro con un ingreso' and monto_centavos = 250000), 1,
  '3: y repetirlo con ese id derivado tampoco duplica');

-- ---------------------------------------------------------------- 4: deshacer
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_dispersion('a8700000-0000-4000-8000-000000000003', 'Me equivoqué')$$,
  '4: Alex no deshace el reparto del libro de Ana', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_deshacer_dispersion('a8700000-0000-4000-8000-000000000003', '  ')$$, '4: el motivo es obligatorio', '22023');
select pruebas.falla($$select public.fin_deshacer_dispersion('a8700000-0000-4000-8000-0000000000ee', 'Me equivoqué')$$, '4: un reparto que no existe', '42501');
select pruebas.igual((public.fin_deshacer_dispersion('a8700000-0000-4000-8000-000000000003', 'Me equivoqué al repartir') ->> 'estado'), 'anulada',
  '4 (P5): deshacer deja el reparto anulado');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8700000-0000-4000-8000-000000000001', 'b8700000-0000-4000-8000-000000000002')), 2,
  '4: y anula con contraasiento los dos movimientos que creó');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a = 'd8700000-0000-4000-8000-000000000001'), 0, '4: el ingreso no se toca');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd8700000-0000-4000-8000-000000000001'), 'por_repartir/900000', '4: el ingreso vuelve a «por repartir» completo');
select pruebas.igual((public.fin_deshacer_dispersion('a8700000-0000-4000-8000-000000000003', 'Me equivoqué al repartir') ->> 'estado'), 'anulada',
  '4: deshacer otra vez es idempotente');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8700000-0000-4000-8000-000000000001', 'b8700000-0000-4000-8000-000000000002')), 2,
  '4: sin contraasientos de más');
-- Un ingreso deshecho se puede repartir otra vez con otro id.
select pruebas.igual((public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000004", "movimiento_id": "d8700000-0000-4000-8000-000000000001", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 800000}, {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000}]}$j$::jsonb) ->> 'estado'),
  'confirmada', '4: tras deshacer, el ingreso se reparte de nuevo');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000001", "movimiento_id": "d8700000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 900000}]}'::jsonb)$j$, '4: un reparto anulado no vuelve a guardarse', '55000');

-- ---------------------------------------------------------------- 5: modo automático (P1): solo lo comprometido, nunca mueve dinero
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000020", "movimiento_id": "d8700000-0000-4000-8000-000000000002", "modo": "automatico",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 300000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 200000}]}'::jsonb)$j$,
  '5 (criterio 12): sin activar el modo automático en el libro no se aplica nada solo', '55000');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), 'solo_a_veces')$$, '5: modo fuera del catálogo', '22023');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), null, date '2026-11-18')$$, '5: el «desde» es un lunes', '22023');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), null, null, 10001)$$, '5: la parte libre va de 0 a 10000', '22023');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), null, null, null, 0)$$, '5: el tope de ahorro es mayor que cero', '22023');
select pruebas.igual((public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), 'automatico', null, 1000, 500000) ->> 'modo'), 'automatico',
  '5: Ana activa el modo automático');
select pruebas.igual((select dispersion_desde = public.fin_fugas_lunes(((now() at time zone 'America/Mexico_City')::date)) - 7
    and dispersion_parte_libre_pb = 1000 and dispersion_tope_ahorro = 500000 from public.fin_parametros where libro_id = (select id from t_ids where clave = 'ana')),
  true, '5 (P2): al activar se fija «desde» en el lunes de la semana anterior');
select pruebas.igual((public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), null, null, null, null, true) ->> 'tope_ahorro'), null,
  '5: quitar el tope lo deja sin tope');
select pruebas.igual((select dispersion_desde = public.fin_fugas_lunes(((now() at time zone 'America/Mexico_City')::date)) - 7
    from public.fin_parametros where libro_id = (select id from t_ids where clave = 'ana')), true, '5: y «desde» no se mueve solo');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000020", "movimiento_id": "d8700000-0000-4000-8000-000000000002", "modo": "automatico",
  "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 300000}, {"destino": "ahorro", "etiqueta": "A", "monto_centavos": 200000}]}'::jsonb)$j$,
  '5 (criterio 12): en modo automático el remanente no se aplica (ahorro)', '22023');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000020", "movimiento_id": "d8700000-0000-4000-8000-000000000002", "modo": "automatico",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 300000}, {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "A", "monto_centavos": 200000}]}'::jsonb)$j$,
  '5: ni el abono extra', '22023');
insert into t_n select 'mov_antes_auto', count(*)::int from public.fin_movimientos;
select pruebas.igual((public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000020", "movimiento_id": "d8700000-0000-4000-8000-000000000002", "modo": "automatico",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 300000},
             {"destino": "pago_deuda", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 50000},
             {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 150000}]}$j$::jsonb) ->> 'estado'),
  'automatica', '5: en modo automático se asigna lo comprometido y el estado es automatica');
select pruebas.igual((select count(*)::int from public.fin_movimientos), (select n from t_n where clave = 'mov_antes_auto'), '5: sin crear movimientos');
select pruebas.igual((select resuelta_por is null and modo = 'automatico' from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000020'), true,
  '5: nadie lo confirmó a mano (resuelta_por nulo)');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd8700000-0000-4000-8000-000000000002'), 'automatica/150000', '5: del automático solo queda el remanente por repartir');

-- ---------------------------------------------------------------- 6: la suma de los renglones también se cuida en la base (disparador diferido)
select pruebas.como_postgres();
insert into public.fin_dispersiones (id, hogar_id, libro_id, movimiento_id, estado, modo, creada_por)
  values ('a8700000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'),
          'd8700000-0000-4000-8000-000000000005', 'propuesta', 'confirmacion', pruebas.id_persona('ana@ejemplo.test'));
insert into public.fin_dispersion_lineas (hogar_id, libro_id, dispersion_id, orden, destino, etiqueta, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'a8700000-0000-4000-8000-0000000000b1', 0, 'libre', 'L', 1);
select pruebas.falla($$set constraints all immediate$$, '6 (suma): aun escribiendo directo, la suma distinta del monto no pasa', '23514');
select pruebas.como_postgres();
delete from public.fin_dispersion_lineas where dispersion_id = 'a8700000-0000-4000-8000-0000000000b1';
update public.fin_dispersiones set estado = 'anulada' where id = 'a8700000-0000-4000-8000-0000000000b1';
set constraints all immediate;
select pruebas.ok(true, '6: una propuesta anulada ya no exige la suma');
set constraints all deferred;   -- como en producción: la suma se revisa al terminar la transacción
-- Solo agregar: ni editar ni borrar; las transiciones válidas son las únicas.
select pruebas.falla($$update public.fin_dispersiones set movimiento_id = 'd8700000-0000-4000-8000-000000000003' where id = 'a8700000-0000-4000-8000-000000000004'$$,
  '6: el movimiento de un reparto no cambia', '42501');
select pruebas.falla($$delete from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000004'$$, '6: un reparto no se borra', '42501');
select pruebas.falla($$truncate public.fin_dispersiones, public.fin_dispersion_lineas$$, '6: ni se trunca (con sus renglones, que la apuntan)', '42501');
select pruebas.falla($$truncate public.fin_dispersion_lineas$$, '6: ni se trunca solo los renglones', '42501');
select pruebas.falla($$update public.fin_dispersion_lineas set monto_centavos = 1 where dispersion_id = 'a8700000-0000-4000-8000-000000000004'$$, '6: un renglón no se edita', '42501');
select pruebas.falla($$delete from public.fin_dispersion_lineas where dispersion_id = 'a8700000-0000-4000-8000-000000000004'$$, '6: ni se borra el de un reparto confirmado', '55000');
select pruebas.falla($$insert into public.fin_dispersion_lineas (hogar_id, libro_id, dispersion_id, orden, destino, etiqueta, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'a8700000-0000-4000-8000-000000000004', 9, 'libre', 'L', 0)$$,
  '6: ni se agrega uno a un reparto confirmado', '55000');
select pruebas.falla($$update public.fin_dispersiones set estado = 'propuesta' where id = 'a8700000-0000-4000-8000-000000000004'$$, '6: un confirmado solo se anula', '55000');
select pruebas.falla($$update public.fin_dispersiones set estado = 'confirmada' where id = 'a8700000-0000-4000-8000-000000000002'$$, '6: uno anulado ya no cambia', '55000');
select pruebas.falla($$insert into public.fin_dispersiones (id, hogar_id, libro_id, movimiento_id, estado, modo, creada_por)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'd8700000-0000-4000-8000-000000000001', 'propuesta', 'confirmacion',
          pruebas.id_persona('ana@ejemplo.test'))$$, '6 (unicidad): la base rechaza un segundo reparto vigente del mismo ingreso', '23505');
select pruebas.falla($$insert into public.fin_dispersiones (id, hogar_id, libro_id, movimiento_id, estado, modo, creada_por, en_nombre_de)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'd8700000-0000-4000-8000-000000000003', 'propuesta', 'confirmacion',
          pruebas.id_persona('ana@ejemplo.test'), 'e0000000-0000-4000-8000-000000000001')$$, '6: en nombre de otra persona exige motivo', '23514');

-- ---------------------------------------------------------------- 7: permisos por rol (D5, D19, D24)
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = (select id from t_ids where clave = 'ana')$$) >= 4,
  '7: Ana lee los repartos de su libro');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_dispersion_lineas where libro_id = (select id from t_ids where clave = 'ana')$$) >= 8,
  '7: y sus renglones');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = (select id from t_ids where clave = 'ana')$$), 0,
  '7: Alex no lee los repartos del libro personal de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersion_lineas where libro_id = (select id from t_ids where clave = 'ana')$$), 0, '7: ni los renglones');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-0000000000c1", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '7: ni escribe un reparto en el libro de Ana', '42501');
select pruebas.falla($$select * from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))$$, '7: ni lista sus ingresos por repartir', '42501');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), 'automatico')$$, '7: ni cambia sus parámetros', '42501');
select pruebas.falla($$insert into public.fin_dispersiones (id, hogar_id, libro_id, movimiento_id, estado, modo)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'alex'), 'd8700000-0000-4000-8000-000000000003', 'propuesta', 'confirmacion')$$,
  '7: nadie inserta directo, ni en su propio libro', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones$$), 0, '7: la familiar no lee repartos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersion_lineas$$), 0, '7: ni renglones');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-0000000000c2", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '7: ni guarda', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones$$), 0, '7: la cuidadora no lee repartos');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-0000000000c3", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '7: ni confirma', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones$$), 0, '7: la cuenta de la casa (tablet) no lee repartos');
select pruebas.falla($$select * from public.fin_ingresos_por_repartir('f1000000-0000-4000-8000-000000000001')$$, '7: ni lista ingresos por repartir', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones$$), 0, '7: otro hogar no lee nada');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-0000000000c4", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '7: ni escribe en el hogar de otros', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_dispersiones$$, '7: anon no lee', '42501');
select pruebas.falla($j$select public.fin_guardar_propuesta('{}'::jsonb)$j$, '7: anon no llama las RPC', '42501');
-- Cuenta maestra: lectura con consulta registrada y nunca escribe (D19).
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = (select id from t_ids where clave = 'ana')$$), 0,
  '7: la maestra no lee el reparto de un libro ajeno sin consulta registrada');
select public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'ana'));
select pruebas.ok(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = (select id from t_ids where clave = 'ana')$$) >= 4,
  '7: con la consulta registrada, la maestra lee');
select pruebas.ok((select count(*) from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))) >= 1, '7: y la lista de ingresos por repartir');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-0000000000c5", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '7 (criterio 16): pero no guarda propuestas', '42501');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-0000000000c5", "movimiento_id": "d8700000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '7: ni confirma', '42501');
select pruebas.falla($$select public.fin_deshacer_dispersion('a8700000-0000-4000-8000-000000000004', 'Probando la maestra')$$, '7: ni deshace', '42501');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', 'Probando la maestra',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '7: ni corrige el tipo de un ingreso', '42501');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), 'confirmacion')$$, '7: ni cambia parámetros', '42501');

-- ---------------------------------------------------------------- 8: corregir el tipo de un ingreso (decisión 4)
select pruebas.como('ana@ejemplo.test');
create temp table t_saldo (clave text primary key, v bigint);
grant all on t_saldo to public;
insert into t_saldo select 'banco_antes', saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001' and libro_id = (select id from t_ids where clave = 'ana');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000007', 'c3000000-0000-4000-8000-000000000005', 'Era sueldo',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8 (criterio 15): no se corrige el tipo de algo que no es ingreso', '42501');
-- P5 (20/nov/2026): un ingreso ya repartido SÍ se corrige; el reparto se deshace en la misma transacción, sin movimientos huérfanos.
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000005', 'Era sueldo',
    'a9700000-0000-4000-8000-0000000000a3', 'a9700000-0000-4000-8000-0000000000a1', 'a9700000-0000-4000-8000-0000000000a2') ->> 'nuevo_id'),
  'a9700000-0000-4000-8000-0000000000a2', '8 (P5): un ingreso ya repartido se corrige');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000003'), 'anulada',
  '8 (P5): su reparto queda anulado');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8700000-0000-4000-8000-000000000001', 'b8700000-0000-4000-8000-000000000002')), 2,
  '8 (P5): los movimientos que creó el reparto (abono extra y ahorro) quedan anulados: sin huérfanos');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'a9700000-0000-4000-8000-0000000000a2'), 'por_repartir/900000', '8 (P5): el ingreso nuevo nace por repartir');
-- Deshacer el reparto devolvió el dinero del abono y del ahorro al banco: la referencia del saldo es la de ahora.
update t_saldo set v = (select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001'
                          and libro_id = (select id from t_ids where clave = 'ana')) where clave = 'banco_antes';
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000005', 'Era sueldo',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8: el tipo igual al actual se rechaza (aunque esté repartido)', '22023');
select pruebas.igual((select estado from public.fin_dispersiones where movimiento_id = 'd8700000-0000-4000-8000-000000000002' and estado <> 'anulada'), 'automatica',
  '8: y el rechazo no toca el reparto automático');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000006', 'Era sueldo',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8 (criterio 15): ni a un tipo igual al actual', '22023');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000001', 'Era sueldo',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8 (criterio 15): ni a una cuenta que no es de origen de ingreso', '22023');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c4000000-0000-4000-8000-000000000003', 'Era sueldo',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8: ni al origen de ingreso de otro libro', '22023');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', '  ',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8 (criterio 15): el motivo es obligatorio', '22023');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', 'ab' || chr(8203),
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8: ni con menos de 3 caracteres visibles', '22023');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', 'Era sueldo',
  null, gen_random_uuid(), gen_random_uuid())$$, '8: el grupo y los ids de los asientos son obligatorios', '22023');
-- Un reparto en borrador (propuesta) no impide corregir; el disparador lo anula.
select public.fin_guardar_propuesta($j${
  "id": "a8700000-0000-4000-8000-000000000030", "movimiento_id": "d8700000-0000-4000-8000-000000000005",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 100000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}$j$::jsonb);
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', 'El sueldo se registró como extra',
    'a9700000-0000-4000-8000-000000000003', 'a9700000-0000-4000-8000-000000000001', 'a9700000-0000-4000-8000-000000000002') ->> 'nuevo_id'),
  'a9700000-0000-4000-8000-000000000002', '8: corregir el tipo devuelve los ids de los dos asientos');
select pruebas.igual((select tipo || ':' || anula_a::text || ':' || fecha::text || ':' || grupo_id::text || ':' || motivo from public.fin_movimientos
    where id = 'a9700000-0000-4000-8000-000000000001'),
  'anulacion:d8700000-0000-4000-8000-000000000005:' || (select f from t_f)::text || ':a9700000-0000-4000-8000-000000000003:El sueldo se registró como extra',
  '8 (criterio 13): la anulación lleva la misma fecha económica, el grupo y el motivo');
select pruebas.igual((select tipo || ':' || cuenta_origen_id::text || '>' || cuenta_destino_id::text || ':' || monto_centavos::text || ':' || fecha::text || ':' || grupo_id::text
    from public.fin_movimientos where id = 'a9700000-0000-4000-8000-000000000002'),
  'ingreso:c3000000-0000-4000-8000-000000000005>c3000000-0000-4000-8000-000000000001:400000:' || (select f from t_f)::text || ':a9700000-0000-4000-8000-000000000003',
  '8 (criterio 13): el ingreso nuevo conserva monto, fecha y cuenta de destino, con el origen correcto y el mismo grupo');
-- Los ids de los dos asientos son los que se pidieron: p_id_anulacion es el primero.
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001' and libro_id = (select id from t_ids where clave = 'ana')),
  (select v from t_saldo where clave = 'banco_antes'), '8 (criterio 13): el saldo de la cuenta no cambia');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id = 'd8700000-0000-4000-8000-000000000005' and tipo = 'ingreso'), 1, '8: el original sigue en el libro (no se edita ni se borra)');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000030'), 'anulada',
  '8 (criterio 14): la propuesta del ingreso viejo pasa a anulada (el disparador)');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'a9700000-0000-4000-8000-000000000002'), 'por_repartir/400000', '8 (criterio 14): el ingreso nuevo nace por repartir');
select pruebas.igual((select count(*)::int from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd8700000-0000-4000-8000-000000000005'), 0, '8: y el viejo ya no aparece');
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', 'El sueldo se registró como extra',
    'a9700000-0000-4000-8000-000000000003', 'a9700000-0000-4000-8000-000000000001', 'a9700000-0000-4000-8000-000000000002') ->> 'nuevo_id'),
  'a9700000-0000-4000-8000-000000000002', '8 (idempotencia): repetir la corrección con los mismos ids devuelve lo mismo');
select pruebas.igual((select count(*)::int from public.fin_movimientos where grupo_id = 'a9700000-0000-4000-8000-000000000003'), 2, '8: sin asientos de más');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000005', 'Otra vez',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8 (criterio 15): el ingreso ya anulado no se corrige otra vez', '55000');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000003', 'c3000000-0000-4000-8000-000000000005', 'Era sueldo',
  gen_random_uuid(), 'a9700000-0000-4000-8000-000000000001', gen_random_uuid())$$, '8: un id de asiento que ya es de otra corrección se rechaza', '23505');
-- El ingreso nuevo se reparte como cualquier otro, y ya repartido no se corrige.
select public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000031", "movimiento_id": "a9700000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 400000}]}$j$::jsonb);
select pruebas.igual((public.fin_corregir_tipo_ingreso('a9700000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000006', 'Otra vez',
    'a9700000-0000-4000-8000-000000000043', 'a9700000-0000-4000-8000-000000000041', 'a9700000-0000-4000-8000-000000000042') ->> 'nuevo_id'),
  'a9700000-0000-4000-8000-000000000042', '8 (P5): el ingreso nuevo ya repartido también se corrige (deshace su reparto)');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000031'), 'anulada', '8 (P5): y su reparto queda anulado');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000005', 'No es mío',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8: Alex no corrige el tipo de un ingreso del libro de Ana', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000005', 'No es mío',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '8: ni la familiar', '42501');
-- Libro compartido: el ingreso de Ana, corregido por Alex, queda pendiente de su confirmación (5.0 ter).
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000021', 'c8700000-0000-4000-8000-000000000002', 'Era el sueldo de la casa',
    'a9700000-0000-4000-8000-000000000011', 'a9700000-0000-4000-8000-000000000012', 'a9700000-0000-4000-8000-000000000013') ->> 'grupo_id'),
  'a9700000-0000-4000-8000-000000000011', '8: en un libro compartido, Alex corrige el ingreso de Ana');
select pruebas.igual((select string_agg(estado_inicial, ',' order by id) from public.fin_movimientos where grupo_id = 'a9700000-0000-4000-8000-000000000011'), 'pendiente,pendiente',
  '8 (5.0 ter): el ingreso de otra persona se corrige con asientos pendientes');

-- ---------------------------------------------------------------- 9: anular el ingreso pasa el reparto a «anulada»
select pruebas.como('ana@ejemplo.test');
select public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000040", "movimiento_id": "d8700000-0000-4000-8000-000000000004", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
             {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 120000,
              "movimiento_id": "b8700000-0000-4000-8000-000000000041"},
             {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 80000, "movimiento_id": "b8700000-0000-4000-8000-000000000042"}]}$j$::jsonb);
select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006', 700000, (select f from t_f),
  'Registrado dos veces por error', 'd8700000-0000-4000-8000-000000000004');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000040'), 'anulada',
  '9 (anulación): al anular el ingreso, su reparto pasa a anulada');
select pruebas.como_postgres();
select pruebas.igual((select (detalle ->> 'movimientos_vigentes')::int from public.bitacora where accion = 'finanzas.dispersion_anulada' and registro_id = 'a8700000-0000-4000-8000-000000000040'), 2,
  '9: los movimientos que creó NO se anulan solos y queda una entrada en la bitácora con cuántos siguen vigentes');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8700000-0000-4000-8000-000000000041', 'b8700000-0000-4000-8000-000000000042')), 0,
  '9: de hecho siguen sin anular');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000043", "movimiento_id": "d8700000-0000-4000-8000-000000000004",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}'::jsonb)$j$, '9: un ingreso anulado ya no se reparte', '55000');
select pruebas.igual((select count(*)::int from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana')) where movimiento_id = 'd8700000-0000-4000-8000-000000000004'), 0,
  '9: ni aparece por repartir');
-- Un reparto en borrador también se anula con el ingreso.
select public.fin_guardar_propuesta($j${
  "id": "a8700000-0000-4000-8000-000000000044", "movimiento_id": "d8700000-0000-4000-8000-000000000008",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 150000}]}$j$::jsonb);
select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006', 150000, (select f from t_f),
  'Era un depósito repetido', 'd8700000-0000-4000-8000-000000000008');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000044'), 'anulada', '9: la propuesta también pasa a anulada');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000045", "movimiento_id": "d8700000-0000-4000-8000-000000000008",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 150000}]}'::jsonb)$j$, '9: y no se guarda otra para un ingreso anulado', '55000');

-- ---------------------------------------------------------------- 10: libro de Papá (D19): en nombre de él y con motivo
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($j$select public.fin_confirmar_dispersion('{"id": "a8700000-0000-4000-8000-000000000050", "movimiento_id": "d8700000-0000-4000-8000-000000000011",
  "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 200000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 800000}]}'::jsonb)$j$,
  '10 (criterio 16): en el libro de Papá, confirmar sin motivo se rechaza', '22023');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000050", "movimiento_id": "d8700000-0000-4000-8000-000000000011", "motivo": "ab",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 1000000}]}'::jsonb)$j$, '10: ni guardar una propuesta con un motivo de 2 caracteres', '22023');
select pruebas.igual((public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000050", "movimiento_id": "d8700000-0000-4000-8000-000000000011", "motivo": "Pensión repartida por la albacea",
  "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 200000, "movimiento_id": "b8700000-0000-4000-8000-000000000051"},
             {"destino": "abono_extra", "referencia_id": "e8700000-0000-4000-8000-000000000001", "etiqueta": "Préstamo de Papá", "monto_centavos": 100000,
              "movimiento_id": "b8700000-0000-4000-8000-000000000052"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}$j$::jsonb) ->> 'en_nombre_de'),
  'e0000000-0000-4000-8000-000000000001', '10: con motivo, el albacea confirma en nombre de Papá');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id in ('b8700000-0000-4000-8000-000000000051', 'b8700000-0000-4000-8000-000000000052')
    and en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and motivo = 'Pensión repartida por la albacea'), 2,
  '10: los movimientos que crea van en nombre de Papá y con el motivo');
select pruebas.igual((select realizado_por from public.fin_movimientos where id = 'b8700000-0000-4000-8000-000000000051'), 'e0000000-0000-4000-8000-000000000001'::uuid,
  '10: realizados por Papá, como el resto de su libro');
select pruebas.como_postgres();
select pruebas.ok(exists (select 1 from public.bitacora b where b.tabla = 'fin_dispersiones' and b.detalle::text like '%Pensión repartida por la albacea%'),
  '10: la decisión queda en la bitácora con su motivo');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  '10: Alex (suplente) lee los repartos de Papá');
select pruebas.falla($j$select public.fin_guardar_propuesta('{"id": "a8700000-0000-4000-8000-000000000053", "movimiento_id": "d8700000-0000-4000-8000-000000000013", "motivo": "Lo hago yo",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}'::jsonb)$j$, '10 (I4): pero el suplente no escribe mientras haya albacea', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  '10 (D24): la familiar no lee repartos de Papá');
-- Papá: parámetros y corrección de tipo.
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_dispersion_parametros_cambiar('f1000000-0000-4000-8000-000000000002', 'automatico')$$, '10: los parámetros de Papá piden motivo', '22023');
select pruebas.igual((public.fin_dispersion_parametros_cambiar('f1000000-0000-4000-8000-000000000002', 'confirmacion', null, null, null, false, 'Activo el reparto de Papá') ->> 'modo'),
  'confirmacion', '10: con motivo se activa el reparto de Papá');
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000012', 'c6000000-0000-4000-8000-000000000003', 'Era la pensión, no el apoyo',
    'a9700000-0000-4000-8000-000000000021', 'a9700000-0000-4000-8000-000000000022', 'a9700000-0000-4000-8000-000000000023') ->> 'nuevo_id'),
  'a9700000-0000-4000-8000-000000000023', '10: el albacea corrige el tipo en el libro de Papá');
select pruebas.igual((select count(*)::int from public.fin_movimientos where grupo_id = 'a9700000-0000-4000-8000-000000000021'
    and en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and motivo = 'Era la pensión, no el apoyo'), 2,
  '10: los dos asientos de la corrección van en nombre de Papá y con motivo');
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8700000-0000-4000-8000-000000000011', 'c6000000-0000-4000-8000-000000000004', 'Era el apoyo',
    'a9700000-0000-4000-8000-000000000053', 'a9700000-0000-4000-8000-000000000051', 'a9700000-0000-4000-8000-000000000052') ->> 'nuevo_id'),
  'a9700000-0000-4000-8000-000000000052', '10 (P5): el ingreso de Papá ya repartido se corrige (en su nombre y con motivo)');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8700000-0000-4000-8000-000000000050'), 'anulada', '10 (P5): y su reparto queda anulado');
-- Un reparto automático en el libro de Papá deja motivo y su nombre.
select pruebas.igual((public.fin_dispersion_parametros_cambiar('f1000000-0000-4000-8000-000000000002', 'automatico', null, null, null, false, 'Reparto automático de Papá') ->> 'modo'),
  'automatico', '10: Papá en modo automático');
select pruebas.igual((public.fin_confirmar_dispersion($j${
  "id": "a8700000-0000-4000-8000-000000000054", "movimiento_id": "d8700000-0000-4000-8000-000000000013", "modo": "automatico",
  "lineas": [{"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 300000}]}$j$::jsonb) ->> 'motivo'),
  'Reparto automático', '10: el automático en el libro de Papá queda en su nombre con un motivo de sistema');

-- ---------------------------------------------------------------- 11: avisos (D20): «Tienes un ingreso por repartir», sin cifras
select pruebas.como_postgres();
select pruebas.igual(public.avisos_severidad('ingreso_por_repartir'), 'informativa', '11: el aviso es informativo');
select pruebas.ok(public.avisos_tipo_emitible('ingreso_por_repartir') and public.avisos_tipo_emitible('flujo_negativo') and not public.avisos_tipo_emitible('compra_papa_albacea'),
  '11: la app lo emite y los demás tipos siguen igual');
select pruebas.igual(public.avisos_severidad('transferencia_pendiente') || public.avisos_severidad('deuda_se_volvio_mala') || public.avisos_severidad('fuga_por_reconocer'),
  'importantecriticaimportante', '11: los tipos previos conservan su severidad');
select pruebas.igual(public.fin_dispersion_aviso_titulo('ingreso_por_repartir'), 'Tienes un ingreso por repartir', '11: el título genérico del catálogo');
select pruebas.ok(public.avisos_texto_valido(public.fin_dispersion_aviso_titulo('ingreso_por_repartir'))
  and public.fin_dispersion_aviso_titulo('ingreso_por_repartir') !~ '[0-9$]' and char_length(public.fin_dispersion_aviso_titulo('ingreso_por_repartir')) <= 40,
  '11 (D20): sin dígitos, sin $ y de hasta 40 caracteres');
select pruebas.ok(public.fin_dispersion_aviso_titulo('pago_proximo') is null, '11: solo describe su propio tipo');
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'avisos'
    and (column_name ilike '%monto%' or column_name ilike '%centavos%' or column_name ilike '%titulo%' or column_name ilike '%texto%' or column_name ilike '%cuerpo%' or column_name ilike '%nombre%')),
  '11: la tabla de avisos sigue sin columnas de texto, monto ni nombre');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_por_repartir', 'movimiento', 'd8700000-0000-4000-8000-000000000006', 'ingreso:d8700000-0000-4000-8000-000000000006:por_repartir'),
  1, '11: Ana emite el aviso de su ingreso y solo le llega a ella (libro personal)');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_por_repartir', 'movimiento', 'd8700000-0000-4000-8000-000000000006', 'ingreso:d8700000-0000-4000-8000-000000000006:por_repartir'),
  0, '11: emitirlo otra vez no duplica (idempotente por clave)');
select pruebas.igual((select tipo || '/' || severidad || '/' || objeto_tipo from public.avisos where clave = 'ingreso:d8700000-0000-4000-8000-000000000006:por_repartir'),
  'ingreso_por_repartir/informativa/movimiento', '11: queda como informativo con el ingreso por objeto');
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'ingreso_por_repartir' and persona_id = pruebas.id_persona('alex@ejemplo.test')), 0, '11: Alex no recibe el del libro de Ana');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_por_repartir', null, null, 'ingreso:x:1')$$, '11: sin ingreso por objeto se rechaza', '22023');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_por_repartir', 'movimiento', 'd8700000-0000-4000-8000-000000000007', 'ingreso:x:2')$$,
  '11: ni con un movimiento que no es ingreso', '22023');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_por_repartir', 'libro', (select id from t_ids where clave = 'ana'), 'ingreso:x:3')$$,
  '11: ni con otro tipo de objeto', '22023');
-- Compartido: sus dos miembros reciben el aviso.
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'ingreso_por_repartir', 'movimiento', 'a9700000-0000-4000-8000-000000000013', 'ingreso:a9700000-0000-4000-8000-000000000013:por_repartir'),
  2, '11: en un compartido avisa a sus dos miembros');
-- Papá: el albacea.
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'ingreso_por_repartir', 'movimiento', 'a9700000-0000-4000-8000-000000000023', 'ingreso:a9700000-0000-4000-8000-000000000023:por_repartir'),
  1, '11: en el libro de Papá, solo el albacea');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'ingreso_por_repartir', 'movimiento', 'a9700000-0000-4000-8000-000000000023', 'ingreso:x:4')$$,
  '11 (D24): la familiar con vista temporal no emite', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'ingreso_por_repartir', 'movimiento', 'a9700000-0000-4000-8000-000000000013', 'ingreso:x:5')$$,
  '11: ni la cuidadora', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'ana'), 'ingreso_por_repartir', 'movimiento', 'd8700000-0000-4000-8000-000000000006', 'ingreso:x:6')$$,
  '11: ni la maestra (solo lee)', '42501');
-- Se puede silenciar; uno inventado no.
select pruebas.como('ana@ejemplo.test');
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['ingreso_por_repartir', 'fuga_por_reconocer']);
select pruebas.igual((select tipos_silenciados from public.avisos_preferencias where persona_id = public.persona_actual()), array['ingreso_por_repartir', 'fuga_por_reconocer'],
  '11: Ana silencia el aviso nuevo (sigue en la bandeja)');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['ingreso_inventado'])$$, '11: un tipo desconocido se rechaza', '22023');
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['hab_bloque', 'deuda_en_vigilancia']);
select pruebas.igual((select tipos_silenciados from public.avisos_preferencias where persona_id = public.persona_actual()), array['hab_bloque', 'deuda_en_vigilancia'],
  '11: los tipos de Hábitos y de fugas siguen siendo válidos');

-- ---------------------------------------------------------------- 12: bitácora
select pruebas.como_postgres();
select pruebas.ok(exists (select 1 from public.bitacora b where b.tabla = 'fin_dispersiones') and exists (select 1 from public.bitacora b where b.tabla = 'fin_dispersion_lineas')
  and exists (select 1 from public.bitacora b where b.accion = 'finanzas.dispersion_parametros'), '12: reparto, renglones y parámetros dejan rastro en la bitácora');
select pruebas.ok(not exists (select 1 from public.bitacora b where b.tabla = 'fin_dispersion_lineas' and b.detalle::text ~* 'renta'),
  '12: la bitácora de los renglones no copia las etiquetas');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(exists (select 1 from public.bitacora b where b.accion = 'finanzas.dispersion_anulada'), '12: Ana ve la entrada de la dispersión anulada de su libro');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.bitacora b where b.accion = 'finanzas.dispersion_anulada' and (b.detalle ->> 'libro_id')::uuid = (select id from t_ids where clave = 'ana')
    and b.persona_id <> public.persona_actual()), 0, '12: Alex no ve esa entrada del libro de Ana');

rollback;
