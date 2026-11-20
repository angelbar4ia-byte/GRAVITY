-- Finanzas · Fase 8, paquete F8-6.7: «Cambiar reparto» (migración 20261149; P5 resuelta por el dueño el 20/nov/2026;
-- docs/specs/fase-8-finanzas-dispersion.md): fin_cambiar_dispersion con control de versión, anulación con contraasiento de lo que
-- creó el reparto anterior, cadena de versiones con historial, un único vigente, libro solo-agregar, libro de Papá, permisos por
-- rol, atomicidad, idempotencia, anulación del ingreso tras cambiar y corregir el tipo de un ingreso ya repartido.
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

-- El mensaje de error de un SQL (nulo si no falla).
create function pruebas.mensaje_de(p_sql text) returns text
language plpgsql
as $$
declare
  v_m text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_m = message_text;
  end;
  return v_m;
end
$$;
grant execute on function pruebas.mensaje_de(text) to public, authenticated;

-- ---------------------------------------------------------------- 0: preparación (como postgres)
select pruebas.como_postgres();
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c8800000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', 'Préstamo de Papá (cambiar)', 'prestamo'),
  ('c8800000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Extras casa (cambiar)', 'origen_ingreso'),
  ('c8800000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Sueldo casa (cambiar)', 'origen_ingreso');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, minimo_centavos, tasa_anual_pb) values
  ('e8800000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   'Préstamo de Papá (cambiar)', 'con_costo', 'prestamo', 'c8800000-0000-4000-8000-000000000001', 20000, 'mensual', 10000, 1200);

-- Ingresos (Ana: Banco c3…01, Extras c3…06, Sueldo c3…05, Tarjeta c3…03, Ahorro c3…07).
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 900000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000001');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 500000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000002');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 600000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000003');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 400000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000004');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 250000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000005');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 300000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000006');
select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000001', 200000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000007');
-- Papá (Ana es albacea): en su nombre y con motivo. Su cuenta c6…01, ahorro c6…02, origen pensión c6…03.
select pruebas.registrar('ingreso', 'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 1000000, (select f from t_f),
  p_id => 'd8800000-0000-4000-8000-000000000011', p_motivo => 'Pensión del mes (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
-- Compartido f100…0001 (Ana y Alex): cuenta de la casa c5…01.
select pruebas.registrar('ingreso', 'c8800000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 800000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000021');
select pruebas.registrar('ingreso', 'c8800000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 700000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000022');
-- Un gasto (no es ingreso).
select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 1000, (select f from t_f), p_id => 'd8800000-0000-4000-8000-000000000031');

-- Reparto base del ingreso 1 (900,000): presupuesto 500,000; pago de deuda 100,000 (solo aparta); abono extra 150,000; ahorro 100,000;
-- por repartir 50,000.
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000001", "movimiento_id": "d8800000-0000-4000-8000-000000000001", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "pago_deuda", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 100000},
    {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 150000,
     "movimiento_id": "b8800000-0000-4000-8000-000000000001"},
    {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b8800000-0000-4000-8000-000000000002"},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 50000}]}$j$::jsonb);
create temp table t_saldo (clave text primary key, v bigint);
grant all on t_saldo to public;
insert into t_saldo select 'banco_antes', saldo_centavos from public.fin_v_saldos
  where cuenta_id = 'c3000000-0000-4000-8000-000000000001' and libro_id = (select id from t_ids where clave = 'ana');
insert into t_n select 'mov_antes', count(*) from public.fin_movimientos;

-- ---------------------------------------------------------------- 1: estructura y privilegios
select pruebas.como_postgres();
select pruebas.ok((select count(*) = 2 from information_schema.columns where table_schema = 'public' and table_name = 'fin_dispersiones'
    and column_name in ('version', 'reemplaza_a')), '1: la cadena de versiones: columnas version y reemplaza_a');
select pruebas.ok(has_function_privilege('authenticated', 'public.fin_cambiar_dispersion(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.fin_cambiar_dispersion(jsonb)', 'execute'), '1: fin_cambiar_dispersion es para authenticated y no para anon');
select pruebas.igual((select count(*)::int from unnest(array['public.fin_dispersion_anular_movimientos(uuid, text)', 'public.fin_dispersion_version()']) f
    where has_function_privilege('authenticated', f, 'execute') or has_function_privilege('anon', f, 'execute')), 0,
  '1: los ayudantes internos nuevos no son RPC');
select pruebas.ok(exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'fin_dispersiones_una_vigente'
    and indexdef like '%reemplazada%'), '1: el índice de un único reparto vigente excluye las reemplazadas');
select pruebas.igual((select version::text || '/' || coalesce(reemplaza_a::text, 'nulo') from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000001'),
  '1/nulo', '1: el primer reparto es la versión 1 y no reemplaza a nadie');

-- ---------------------------------------------------------------- 2: cambiar (camino feliz)
select pruebas.como('ana@ejemplo.test');
create temp table t_json (clave text primary key, j jsonb);
grant all on t_json to public;
insert into t_json values ('cambio_2', $j${
  "id": "a8800000-0000-4000-8000-000000000002", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000001", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000001", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "pago_deuda", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 100000},
    {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 200000,
     "movimiento_id": "b8800000-0000-4000-8000-000000000011"},
    {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 50000, "movimiento_id": "b8800000-0000-4000-8000-000000000012"},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 50000}]}$j$::jsonb);
select pruebas.igual((public.fin_cambiar_dispersion((select j from t_json where clave = 'cambio_2')) ->> 'estado'), 'confirmada',
  '2: cambiar devuelve el reparto nuevo, confirmado');
select pruebas.igual((select version::text || '/' || reemplaza_a::text from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000002'),
  '2/a8800000-0000-4000-8000-000000000001', '2: es la versión 2 y reemplaza al reparto anterior');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000001'), 'reemplazada',
  '2: el anterior queda como reemplazado');
select pruebas.igual((select count(*)::int from public.fin_dispersion_lineas where dispersion_id = 'a8800000-0000-4000-8000-000000000001'), 5,
  '2 (historial): el anterior conserva sus cinco renglones');
select pruebas.igual((select count(*)::int from public.fin_dispersion_lineas where dispersion_id = 'a8800000-0000-4000-8000-000000000002'), 5, '2: y el nuevo guarda los suyos');
select pruebas.igual((select sum(monto_centavos)::int from public.fin_dispersion_lineas where dispersion_id = 'a8800000-0000-4000-8000-000000000002'), 900000,
  '2: la suma de los renglones nuevos es el monto del ingreso');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8800000-0000-4000-8000-000000000001', 'b8800000-0000-4000-8000-000000000002')), 2,
  '2 (solo-agregar): el abono extra y el ahorro del anterior se anulan con contraasiento');
select pruebas.ok((select bool_and(a.tipo = 'anulacion' and a.fecha = o.fecha and a.monto_centavos = o.monto_centavos
                                   and a.cuenta_origen_id = o.cuenta_destino_id and a.cuenta_destino_id = o.cuenta_origen_id
                                   and nullif(btrim(a.motivo), '') is not null)
    from public.fin_movimientos a join public.fin_movimientos o on o.id = a.anula_a
   where a.anula_a in ('b8800000-0000-4000-8000-000000000001', 'b8800000-0000-4000-8000-000000000002')),
  '2: cada anulación es el contraasiento exacto (misma fecha, monto y cuentas al revés) y lleva motivo');
select pruebas.igual((select motivo from public.fin_movimientos where anula_a = 'b8800000-0000-4000-8000-000000000001'), 'Reparto cambiado',
  '2: sin motivo escrito, el de omisión es «Reparto cambiado»');
select pruebas.igual((select tipo || ':' || monto_centavos::text from public.fin_movimientos where id = 'b8800000-0000-4000-8000-000000000011'), 'pago_deuda:200000',
  '2: el abono extra nuevo es un pago de deuda por el monto editado');
select pruebas.igual((select tipo || ':' || monto_centavos::text || ':' || cuenta_destino_id::text from public.fin_movimientos where id = 'b8800000-0000-4000-8000-000000000012'),
  'transferencia:50000:c3000000-0000-4000-8000-000000000007', '2: y el ahorro nuevo, una transferencia a la cuenta de ahorro');
select pruebas.igual((select count(*)::int from public.fin_movimientos) - (select n from t_n where clave = 'mov_antes')::int, 4,
  '2: en total, dos anulaciones y dos movimientos nuevos (el pago de deuda sigue solo apartando, P4)');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id in ('b8800000-0000-4000-8000-000000000001', 'b8800000-0000-4000-8000-000000000002')), 2,
  '2 (solo-agregar): y los movimientos viejos siguen ahí, sin editar ni borrar');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001' and libro_id = (select id from t_ids where clave = 'ana'))
    - (select v from t_saldo where clave = 'banco_antes'), 0::bigint,
  '2: el saldo del banco refleja solo la diferencia: se devuelven 250,000 del reparto anterior y salen 250,000 del nuevo');
select pruebas.igual((select count(*)::int from public.fin_v_dispersiones_vigentes where movimiento_id = 'd8800000-0000-4000-8000-000000000001'), 1,
  '2: un único reparto vigente por ingreso');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'd8800000-0000-4000-8000-000000000001'), 'confirmada/50000', '2: del ingreso solo queda por repartir el renglón sobrante');
select pruebas.igual((public.fin_cambiar_dispersion((select j from t_json where clave = 'cambio_2')) ->> 'version'), '2', '2 (idempotencia): repetir el mismo cambio devuelve el mismo reparto');

-- ---------------------------------------------------------------- 3: idempotencia
insert into t_n select 'mov_tras_cambio', count(*) from public.fin_movimientos;
select public.fin_cambiar_dispersion((select j from t_json where clave = 'cambio_2'));
select pruebas.igual((select count(*) from public.fin_movimientos), (select n from t_n where clave = 'mov_tras_cambio'),
  '3 (idempotencia): repetir el cambio no duplica ni anula movimientos');
select pruebas.igual((select count(*)::int from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000001'), 2,
  '3: ni repartos');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000002", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000099",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 900000}]}'::jsonb)$j$,
  '3: el id de un cambio ya hecho no sirve para otro reparto anterior', '23505');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000001", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000002",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 900000}]}'::jsonb)$j$,
  '3: ni el id de otro reparto como id del cambio', '23505');

-- ---------------------------------------------------------------- 4: control de versión
-- El segundo dispositivo todavía ve la versión 1 (id a…01): rechazado con un error claro.
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000003", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000001",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 900000}]}'::jsonb)$j$,
  '4 (versión): editar el reparto que ya fue reemplazado se rechaza', '40001');
select pruebas.igual(pruebas.mensaje_de($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000003", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000001",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 900000}]}'::jsonb)$j$), 'El reparto cambió, vuelve a cargar.',
  '4: el mensaje es claro: «El reparto cambió, vuelve a cargar.»');
-- Con el id vigente pero una versión vieja.
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000003", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000002",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 900000}]}'::jsonb)$j$,
  '4: con el id vigente pero la versión vieja también se rechaza', '40001');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000003", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000002",
  "version_esperada": 7, "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 900000}]}'::jsonb)$j$,
  '4: ni una versión inventada', '40001');
select pruebas.igual((select count(*)::int from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000001'), 2,
  '4: el rechazo no deja repartos de más');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000003", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000002",
  "movimiento_id": "d8800000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 900000}]}'::jsonb)$j$,
  '4: sin versión esperada no hay cambio', '22023');
-- Con la versión correcta se encadena una tercera versión.
select pruebas.igual((public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000003", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000002", "version_esperada": 2,
  "movimiento_id": "d8800000-0000-4000-8000-000000000001", "motivo": "Me alcanzó para más ahorro", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [
    {"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000},
    {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 400000, "movimiento_id": "b8800000-0000-4000-8000-000000000021"}]}$j$::jsonb) ->> 'version'),
  '3', '4: con la versión que sí vio, el cambio pasa y es la versión 3');
select pruebas.igual((select string_agg(version::text || ':' || estado, ',' order by version) from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000001'),
  '1:reemplazada,2:reemplazada,3:confirmada', '4 (historial): la cadena completa queda guardada, solo la última vigente');
select pruebas.igual((select string_agg(coalesce(reemplaza_a::text, 'nulo'), ',' order by version) from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000001'),
  'nulo,a8800000-0000-4000-8000-000000000001,a8800000-0000-4000-8000-000000000002', '4: cada versión apunta a la que reemplaza');
select pruebas.igual((select motivo from public.fin_movimientos where anula_a = 'b8800000-0000-4000-8000-000000000011'), 'Me alcanzó para más ahorro',
  '4: con motivo escrito, las anulaciones llevan ese motivo');
select pruebas.igual((select count(*)::int from public.fin_movimientos m where m.id in ('b8800000-0000-4000-8000-000000000011', 'b8800000-0000-4000-8000-000000000012', 'b8800000-0000-4000-8000-000000000021')
    and not exists (select 1 from public.fin_movimientos a where a.anula_a = m.id)), 1, '4: de la cadena, solo el ahorro de la versión 3 sigue vigente');
-- Un reparto reemplazado ya no se deshace: «cambió».
select pruebas.falla($$select public.fin_deshacer_dispersion('a8800000-0000-4000-8000-000000000002', 'Probando')$$, '4: deshacer un reparto reemplazado responde que cambió', '40001');
-- Inmutabilidad de la cadena (como postgres, sin RLS: la protección es del disparador).
select pruebas.como_postgres();
select pruebas.falla($$update public.fin_dispersiones set estado = 'confirmada' where id = 'a8800000-0000-4000-8000-000000000001'$$,
  '4: un reparto reemplazado ya no cambia', '55000');
select pruebas.falla($$update public.fin_dispersiones set version = 9 where id = 'a8800000-0000-4000-8000-000000000003'$$,
  '4: la versión no se edita', '42501');
select pruebas.falla($$update public.fin_dispersiones set reemplaza_a = null where id = 'a8800000-0000-4000-8000-000000000003'$$,
  '4: ni el vínculo con el anterior', '42501');
select pruebas.falla($$delete from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000001'$$, '4: nada se borra', '42501');
select pruebas.falla($$update public.fin_dispersion_lineas set monto_centavos = 1 where dispersion_id = 'a8800000-0000-4000-8000-000000000001'$$, '4: los renglones del historial no se editan', '42501');
select pruebas.falla($$insert into public.fin_dispersiones (id, hogar_id, libro_id, movimiento_id, estado, modo, creada_por)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'd8800000-0000-4000-8000-000000000001',
          'propuesta', 'confirmacion', pruebas.id_persona('ana@ejemplo.test'))$$, '4 (unicidad): no puede haber dos repartos vigentes del mismo ingreso', '23505');

-- ---------------------------------------------------------------- 5: atomicidad
select pruebas.como('ana@ejemplo.test');
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000011", "movimiento_id": "d8800000-0000-4000-8000-000000000002", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [
    {"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-000000000001", "etiqueta": "Tarjeta", "monto_centavos": 100000,
     "movimiento_id": "b8800000-0000-4000-8000-000000000031"},
    {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b8800000-0000-4000-8000-000000000032"},
    {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 300000}]}$j$::jsonb);
delete from t_n where clave = 'mov_antes_fallo';
insert into t_n select 'mov_antes_fallo', count(*) from public.fin_movimientos;
-- La suma no cuadra: falla DESPUÉS de anular lo anterior; todo se revierte.
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000012", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 100}]}'::jsonb)$j$, '5 (suma): los renglones deben sumar el monto del ingreso', '22023');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000012", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 600000}]}'::jsonb)$j$, '5: ni de más', '22023');
-- El ahorro sin cuenta de ahorro: falla en la validación de los renglones, ya con el anterior anulado.
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000012", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 500000}]}'::jsonb)$j$, '5: elegir ahorro sin la cuenta se rechaza', '22023');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000012", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000002", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000001",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 500000}]}'::jsonb)$j$, '5: la cuenta de ahorro no puede ser la del ingreso', '22023');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000012", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "abono_extra", "referencia_id": "e5000000-0000-4000-8000-0000000000ff", "etiqueta": "X", "monto_centavos": 500000}]}'::jsonb)$j$,
  '5: una deuda que no es de este libro se rechaza', '22023');
select pruebas.igual((select count(*) from public.fin_movimientos), (select n from t_n where clave = 'mov_antes_fallo'),
  '5 (atomicidad): tras los fallos no hay anulaciones ni movimientos de más');
select pruebas.igual((select estado || '/' || version::text from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000011'), 'confirmada/1',
  '5: el reparto anterior sigue confirmado, sin tocar');
select pruebas.igual((select count(*)::int from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000002'), 1,
  '5: y no quedó un reparto nuevo a medias');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8800000-0000-4000-8000-000000000031', 'b8800000-0000-4000-8000-000000000032')), 0,
  '5: los movimientos del reparto anterior siguen vigentes');
-- Un cambio válido después de los fallos sí pasa (con los mismos ids que fallaron).
select pruebas.igual((public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000012", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 500000}]}$j$::jsonb) ->> 'version'), '2',
  '5: y un cambio válido, con los mismos ids que habían fallado, pasa');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8800000-0000-4000-8000-000000000031', 'b8800000-0000-4000-8000-000000000032')), 2,
  '5: cambiar a un reparto sin movimientos anula los del anterior (el dinero vuelve al banco)');
-- Un reparto en propuesta no se cambia: se confirma; un ingreso sin reparto no tiene qué cambiar.
select public.fin_guardar_propuesta($j${
  "id": "a8800000-0000-4000-8000-000000000021", "movimiento_id": "d8800000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 100000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 500000}]}$j$::jsonb);
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000022", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000021",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000003",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 600000}]}'::jsonb)$j$, '5: una propuesta no se cambia, se confirma', '55000');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000023", "dispersion_anterior_id": "a8800000-0000-4000-8000-0000000000aa",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000004",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 400000}]}'::jsonb)$j$, '5: un reparto que no existe no se cambia', '22023');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000023", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000004",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 400000}]}'::jsonb)$j$, '5: ni uno que es de otro ingreso', '22023');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000023", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000011",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000031",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 1000}]}'::jsonb)$j$, '5: ni de algo que no es un ingreso', '42501');

-- ---------------------------------------------------------------- 6: permisos por rol
-- Reparto vigente del ingreso 1 (a…03, versión 3). Ninguno de estos puede cambiarlo.
create temp table t_cambio_ajeno (clave text primary key, j text);
grant all on t_cambio_ajeno to public;
insert into t_cambio_ajeno values ('c', $j${"id": "a8800000-0000-4000-8000-0000000000c1", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000003",
  "version_esperada": 3, "movimiento_id": "d8800000-0000-4000-8000-000000000001", "motivo": "Lo intento yo",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 900000}]}$j$);
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_cambiar_dispersion((select j::jsonb from t_cambio_ajeno where clave = 'c'))$$, '6: la pareja no cambia el reparto del libro personal de Ana', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_cambiar_dispersion((select j::jsonb from t_cambio_ajeno where clave = 'c'))$$, '6: la familiar no cambia repartos', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_cambiar_dispersion((select j::jsonb from t_cambio_ajeno where clave = 'c'))$$, '6: la cuidadora no cambia repartos', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_cambiar_dispersion((select j::jsonb from t_cambio_ajeno where clave = 'c'))$$, '6: la tablet de la casa no cambia repartos', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.fin_cambiar_dispersion((select j::jsonb from t_cambio_ajeno where clave = 'c'))$$, '6: otro hogar tampoco', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.fin_cambiar_dispersion('{}'::jsonb)$$, '6: anon no llama la RPC', '42501');
-- Cuenta maestra: lectura con consulta registrada, nunca escribe (D19).
select pruebas.como('marta@ejemplo.test');
select public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'ana'));
select pruebas.falla($$select public.fin_cambiar_dispersion((select j::jsonb from t_cambio_ajeno where clave = 'c'))$$, '6 (D19): la cuenta maestra es de solo lectura, aun con consulta registrada', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select estado || '/' || version::text from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000003'), 'confirmada/3',
  '6: tras todos los intentos ajenos, el reparto vigente sigue igual');
-- Compartido f100…0001: Ana reparte y Alex (miembro) puede cambiarlo.
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000031", "movimiento_id": "d8800000-0000-4000-8000-000000000021",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Casa", "monto_centavos": 800000}]}$j$::jsonb);
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000032", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000031", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000021",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Casa", "monto_centavos": 500000}, {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 300000}]}$j$::jsonb) ->> 'version'),
  '2', '6: en un libro compartido, la pareja miembro sí cambia el reparto');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones where libro_id = 'f1000000-0000-4000-8000-000000000001'$$), 0, '6: y la familiar no ve ese reparto (ni sus versiones)');

-- ---------------------------------------------------------------- 7: libro de Papá (D19): en su nombre y con motivo
select pruebas.como('ana@ejemplo.test');
select public.fin_dispersion_parametros_cambiar('f1000000-0000-4000-8000-000000000002', 'confirmacion', null, null, null, false, 'Activo el reparto de Papá');
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000041", "movimiento_id": "d8800000-0000-4000-8000-000000000011", "motivo": "Pensión repartida por la albacea",
  "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 200000, "movimiento_id": "b8800000-0000-4000-8000-000000000041"},
             {"destino": "abono_extra", "referencia_id": "e8800000-0000-4000-8000-000000000001", "etiqueta": "Préstamo de Papá", "monto_centavos": 100000,
              "movimiento_id": "b8800000-0000-4000-8000-000000000042"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}$j$::jsonb);
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000042", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000041",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000011", "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 300000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}'::jsonb)$j$,
  '7 (D19): en el libro de Papá, cambiar sin motivo se rechaza', '22023');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000042", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000041",
  "version_esperada": 1, "movimiento_id": "d8800000-0000-4000-8000-000000000011", "motivo": "ab", "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 300000}, {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}'::jsonb)$j$,
  '7: ni con un motivo de 2 caracteres', '22023');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000041'), 'confirmada', '7: los rechazos no tocan el reparto de Papá');
select pruebas.igual((public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000042", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000041", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000011", "motivo": "Corrijo el reparto de la pensión", "cuenta_ahorro_id": "c6000000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 300000, "movimiento_id": "b8800000-0000-4000-8000-000000000043"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 700000}]}$j$::jsonb) ->> 'en_nombre_de'),
  'e0000000-0000-4000-8000-000000000001', '7: con motivo, la albacea cambia el reparto en nombre de Papá');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id = 'b8800000-0000-4000-8000-000000000043'
    and en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and motivo = 'Corrijo el reparto de la pensión'), 1,
  '7: el movimiento nuevo va en nombre de Papá y con el motivo');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a in ('b8800000-0000-4000-8000-000000000041', 'b8800000-0000-4000-8000-000000000042')
    and en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and motivo = 'Corrijo el reparto de la pensión'), 2,
  '7: y las anulaciones del reparto anterior también, con el motivo');
select pruebas.como_postgres();
select pruebas.ok(exists (select 1 from public.bitacora b where b.accion = 'finanzas.dispersion_cambiada' and b.registro_id = 'a8800000-0000-4000-8000-000000000042'
    and b.detalle ->> 'motivo' = 'Corrijo el reparto de la pensión' and (b.detalle ->> 'version_nueva')::int = 2), '7: la bitácora registra el cambio con su motivo y la versión');
select pruebas.ok(not exists (select 1 from public.bitacora b, jsonb_object_keys(b.detalle) k
    where b.accion = 'finanzas.dispersion_cambiada'
      and k not in ('libro_id', 'movimiento_id', 'reparto_anterior', 'version_anterior', 'version_nueva', 'movimientos_anulados', 'en_nombre_de', 'motivo')),
  '7 (D20): la bitácora del cambio solo lleva ids, versiones y el motivo: sin montos ni etiquetas');
-- Suplente (Alex) mientras haya albacea, y la familiar con la vista temporal de Papá (D24): no escriben.
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000043", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000042",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000011", "motivo": "Lo hago yo",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 1000000}]}'::jsonb)$j$, '7 (I4): el suplente no cambia mientras haya albacea', '42501');
select pruebas.como('carla@ejemplo.test');
create temp table t_sol (id uuid);
grant all on t_sol to public;
insert into t_sol select public.fin_pedir_vista_papa('Revisar el reparto de la pensión');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol), 'autorizar');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), true, '7: la familiar tiene la vista temporal de Papá vigente');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_dispersiones$$), 0, '7 (D24): y aun así no ve repartos');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000043", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000042",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000011", "motivo": "Con la vista temporal",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 1000000}]}'::jsonb)$j$, '7 (D24): la vista temporal de Papá no cambia repartos', '42501');

-- ---------------------------------------------------------------- 8: modo automático: un reparto automático también se cambia
select pruebas.como('ana@ejemplo.test');
select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), 'automatico');
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000051", "movimiento_id": "d8800000-0000-4000-8000-000000000005", "modo": "automatico",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 150000}, {"destino": "por_repartir", "etiqueta": "Por repartir", "monto_centavos": 100000}]}$j$::jsonb);
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000051'), 'automatica', '8: el reparto nace automático');
select pruebas.igual((public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000052", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000051", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000005", "modo": "automatico", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 150000},
             {"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b8800000-0000-4000-8000-000000000051"}]}$j$::jsonb) ->> 'estado'),
  'confirmada', '8: la persona lo cambia: queda confirmado por ella (con confirmación, aunque el libro esté en automático)');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000051'), 'reemplazada', '8: y el automático queda reemplazado');
select public.fin_dispersion_parametros_cambiar((select id from t_ids where clave = 'ana'), 'confirmacion');

-- ---------------------------------------------------------------- 9: anular el ingreso después de cambiar
-- Ingreso 4: reparto, cambio, y luego se anula el ingreso: el reparto vigente pasa a anulada; las versiones viejas siguen reemplazadas.
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000061", "movimiento_id": "d8800000-0000-4000-8000-000000000004", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b8800000-0000-4000-8000-000000000061"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 300000}]}$j$::jsonb);
select public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000062", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000061", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000004", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 150000, "movimiento_id": "b8800000-0000-4000-8000-000000000062"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 250000}]}$j$::jsonb);
select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000006', 400000, (select f from t_f),
  'Registrado dos veces por error', 'd8800000-0000-4000-8000-000000000004');
select pruebas.igual((select string_agg(version::text || ':' || estado, ',' order by version) from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000004'),
  '1:reemplazada,2:anulada', '9 (anulación): al anular el ingreso tras cambiar, el vigente pasa a anulada y el historial se conserva');
select pruebas.igual((select count(*)::int from public.fin_v_dispersiones_vigentes where movimiento_id = 'd8800000-0000-4000-8000-000000000004'), 0, '9: no queda ningún reparto vigente');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000063", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000062",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000004",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 400000}]}'::jsonb)$j$, '9: y un ingreso anulado ya no se cambia', '40001');
select pruebas.como_postgres();
select pruebas.igual((select (detalle ->> 'movimientos_vigentes')::int from public.bitacora where accion = 'finanzas.dispersion_anulada' and registro_id = 'a8800000-0000-4000-8000-000000000062'), 1,
  '9: los movimientos de la versión vigente siguen vigentes y la bitácora lo dice (como al anular cualquier reparto)');
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- 10: deshacer y luego cambiar
select pruebas.igual((public.fin_deshacer_dispersion('a8800000-0000-4000-8000-000000000012', 'Mejor lo dejo por repartir') ->> 'estado'), 'anulada',
  '10: un reparto cambiado se deshace como cualquier otro (la versión vigente)');
select pruebas.falla($j$select public.fin_cambiar_dispersion('{"id": "a8800000-0000-4000-8000-000000000013", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000012",
  "version_esperada": 2, "movimiento_id": "d8800000-0000-4000-8000-000000000002",
  "lineas": [{"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 500000}]}'::jsonb)$j$, '10: cambiar un reparto ya deshecho responde que cambió', '40001');

-- ---------------------------------------------------------------- 11: corregir el tipo de un ingreso ya repartido (y ya cambiado)
select pruebas.como('ana@ejemplo.test');
-- Ingreso 6 (300,000): repartido con ahorro y cambiado una vez; luego se corrige su tipo.
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000071", "movimiento_id": "d8800000-0000-4000-8000-000000000006", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 100000, "movimiento_id": "b8800000-0000-4000-8000-000000000071"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 200000}]}$j$::jsonb);
select public.fin_cambiar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000072", "dispersion_anterior_id": "a8800000-0000-4000-8000-000000000071", "version_esperada": 1,
  "movimiento_id": "d8800000-0000-4000-8000-000000000006", "cuenta_ahorro_id": "c3000000-0000-4000-8000-000000000007",
  "lineas": [{"destino": "ahorro", "etiqueta": "Ahorro", "monto_centavos": 120000, "movimiento_id": "b8800000-0000-4000-8000-000000000072"},
             {"destino": "por_repartir", "etiqueta": "P", "monto_centavos": 180000}]}$j$::jsonb);
delete from t_n where clave = 'mov_antes_tipo';
insert into t_n select 'mov_antes_tipo', count(*) from public.fin_movimientos;
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8800000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000005', 'Era el sueldo, no un extra',
    'a8800000-0000-4000-8000-0000000000a3', 'a8800000-0000-4000-8000-0000000000a1', 'a8800000-0000-4000-8000-0000000000a2') ->> 'nuevo_id'),
  'a8800000-0000-4000-8000-0000000000a2', '11 (P5): un ingreso ya repartido se corrige de tipo');
select pruebas.igual((select string_agg(version::text || ':' || estado, ',' order by version) from public.fin_dispersiones where movimiento_id = 'd8800000-0000-4000-8000-000000000006'),
  '1:reemplazada,2:anulada', '11: su reparto vigente queda anulado y el historial sigue');
select pruebas.igual((select count(*)::int from public.fin_movimientos where anula_a = 'b8800000-0000-4000-8000-000000000072'), 1,
  '11 (sin huérfanos): el ahorro que creó el reparto se anula en la misma transacción');
select pruebas.igual((select count(*) from public.fin_movimientos) - (select n from t_n where clave = 'mov_antes_tipo'), 3::bigint,
  '11: tres asientos: la anulación del ahorro y los dos de la corrección (nada más)');
select pruebas.igual((select motivo from public.fin_movimientos where anula_a = 'b8800000-0000-4000-8000-000000000072'), 'Era el sueldo, no un extra',
  '11: la anulación del ahorro lleva el motivo de la corrección');
select pruebas.igual((select estado || '/' || pendiente_centavos::text from public.fin_ingresos_por_repartir((select id from t_ids where clave = 'ana'))
    where movimiento_id = 'a8800000-0000-4000-8000-0000000000a2'), 'por_repartir/300000', '11: el ingreso nuevo nace por repartir y se reparte como sueldo');
select pruebas.igual((select count(*)::int from public.fin_movimientos where grupo_id = 'a8800000-0000-4000-8000-0000000000a3'), 2, '11: los asientos de la corrección comparten grupo');
-- Corrección repetida con los mismos ids: idempotente, no anula nada más.
select public.fin_corregir_tipo_ingreso('d8800000-0000-4000-8000-000000000006', 'c3000000-0000-4000-8000-000000000005', 'Era el sueldo, no un extra',
  'a8800000-0000-4000-8000-0000000000a3', 'a8800000-0000-4000-8000-0000000000a1', 'a8800000-0000-4000-8000-0000000000a2');
select pruebas.igual((select count(*) from public.fin_movimientos) - (select n from t_n where clave = 'mov_antes_tipo'), 3::bigint, '11 (idempotencia): repetir la corrección no agrega nada');
-- El ingreso nuevo ya se puede repartir (y cambiar).
select pruebas.igual((public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000073", "movimiento_id": "a8800000-0000-4000-8000-0000000000a2",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Renta", "monto_centavos": 300000}]}$j$::jsonb) ->> 'estado'), 'confirmada', '11: el ingreso corregido se reparte');
-- Compartido, ingreso de otra persona: la corrección queda pendiente; con reparto, se pide cambiarlo o deshacerlo primero.
select pruebas.como('ana@ejemplo.test');
select public.fin_confirmar_dispersion($j${
  "id": "a8800000-0000-4000-8000-000000000081", "movimiento_id": "d8800000-0000-4000-8000-000000000022",
  "lineas": [{"destino": "presupuesto", "etiqueta": "Casa", "monto_centavos": 700000}]}$j$::jsonb);
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_corregir_tipo_ingreso('d8800000-0000-4000-8000-000000000022', 'c8800000-0000-4000-8000-000000000003', 'Era el sueldo de la casa',
  gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$, '11 (5.0 ter): la corrección pendiente de otra persona no deshace el reparto: se pide cambiarlo o deshacerlo antes', '55000');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000081'), 'confirmada', '11: y el rechazo no toca el reparto');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.fin_corregir_tipo_ingreso('d8800000-0000-4000-8000-000000000022', 'c8800000-0000-4000-8000-000000000003', 'Era el sueldo de la casa',
    'a8800000-0000-4000-8000-0000000000b3', 'a8800000-0000-4000-8000-0000000000b1', 'a8800000-0000-4000-8000-0000000000b2') ->> 'grupo_id'),
  'a8800000-0000-4000-8000-0000000000b3', '11: quien registró el ingreso lo corrige en un libro compartido (confirmado, sin esperar a nadie)');
select pruebas.igual((select estado from public.fin_dispersiones where id = 'a8800000-0000-4000-8000-000000000081'), 'anulada', '11: y su reparto queda anulado');

rollback;
