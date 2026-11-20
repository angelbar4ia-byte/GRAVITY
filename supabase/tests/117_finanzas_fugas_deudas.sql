-- Finanzas · Fase 8, bloque 6: fugas silenciosas y deuda buena o mala (migración 20261146;
-- docs/specs/fase-8-fugas-y-deudas.md v0.3, casos SQ-1 a SQ-9 de la sección 10.3).
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente de Papá), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra), Elena (otro hogar).
-- Libros: personal de Alex y de Ana; compartido f100…0001 (Ana y Alex); Papá f100…0002 (Ana albacea, Alex suplente).
begin;

create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;
insert into t_ids values ('alex', pruebas.libro_personal('alex@ejemplo.test')), ('ana', pruebas.libro_personal('ana@ejemplo.test'));

-- ---------------------------------------------------------------- 0: preparación (como postgres)
select pruebas.como_postgres();
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c8600000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Banco F (ejemplo)', 'banco'),
  ('c8600000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Tarjeta F (ejemplo)', 'tarjeta'),
  ('c8600000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'MSI laptop (ejemplo)', 'prestamo'),
  ('c8600000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', 'Préstamo de Papá (ejemplo)', 'prestamo'),
  ('c8600000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Préstamo de la casa (ejemplo)', 'prestamo');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, minimo_centavos, tasa_anual_pb) values
  ('e8600000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Tarjeta F', 'con_costo', 'tarjeta', 'c8600000-0000-4000-8000-000000000002', 50000, 'mensual', 30000, 4800),
  ('e8600000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'MSI laptop', 'msi', 'msi', 'c8600000-0000-4000-8000-000000000003', 100000, 'mensual', 0, 0),
  ('e8600000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   'Préstamo de Papá', 'con_costo', 'prestamo', 'c8600000-0000-4000-8000-000000000004', 20000, 'mensual', 10000, 1200),
  ('e8600000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
   'Préstamo de la casa', 'con_costo', 'prestamo', 'c8600000-0000-4000-8000-000000000005', 20000, 'mensual', 10000, 1200);
-- Dinero en el banco de Alex para un gasto de prueba (rol postgres con la sesión de Alex para los defaults).
select set_config('request.jwt.claim.sub', pruebas.id_usuario('alex@ejemplo.test')::text, true),
  set_config('request.jwt.claims', json_build_object('sub', pruebas.id_usuario('alex@ejemplo.test'), 'role', 'authenticated')::text, true);
select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('alex@ejemplo.test'), 'apertura'),
  'c8600000-0000-4000-8000-000000000001', 500000, p_realizado_por => pruebas.id_persona('alex@ejemplo.test'));

-- ---------------------------------------------------------------- 1: columnas nuevas (SQ-9, libro solo-agregar)
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
    cuenta_destino_id, monto_centavos, comercio, cobro_automatico)
  values ('d8600000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-11-02', '2026-11-02 12:00-06',
          'c8600000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 8900, 'Streaming Ejemplo', true)$$), 1,
  '1 (SQ-9): un gasto con comercio y cobro automático entra');
select pruebas.igual((select comercio || '/' || cobro_automatico::text from public.fin_movimientos where id = 'd8600000-0000-4000-8000-000000000001'),
  'Streaming Ejemplo/true', '1: y quedan guardados');
select pruebas.igual(pruebas.afecta($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
    cuenta_destino_id, monto_centavos)
  values ('d8600000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-11-02', '2026-11-02 12:05-06',
          'c8600000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 4500)$$), 1,
  '1 (UI-3): sin comercio y sin la casilla sigue entrando igual');
select pruebas.igual((select comercio is null and not cobro_automatico from public.fin_movimientos where id = 'd8600000-0000-4000-8000-000000000002'),
  true, '1: comercio nulo y cobro_automatico falso por omisión');
select pruebas.falla($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
    monto_centavos, comercio) values ('d8600000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-11-02',
    '2026-11-02 12:10-06', 'c8600000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 100, repeat('x', 81))$$,
  '1: el comercio admite hasta 80 caracteres', '23514');
select pruebas.falla($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
    monto_centavos, comercio) values ('d8600000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-11-02',
    '2026-11-02 12:11-06', 'c8600000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 100, '   ')$$,
  '1: ni en blanco', '23514');
select pruebas.falla($$update public.fin_movimientos set comercio = 'Otro'$$, '1 (SQ-9): ningún movimiento se edita (ni el comercio)', '42501');
select pruebas.falla($$delete from public.fin_movimientos$$, '1: ni se borra', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
    cuenta_destino_id, monto_centavos, comercio, cobro_automatico)
  values ('d8600000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-11-02', '2026-11-02 12:00-06',
          'c8600000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 8900, 'Streaming Ejemplo', true)
  on conflict (id) do nothing$$), 0, '1: reenviar el mismo movimiento (la cola) no duplica');
select pruebas.como_postgres();
select pruebas.ok(not exists (select 1 from public.bitacora b where b.tabla = 'fin_movimientos' and b.detalle::text ~* 'streaming'),
  '1: la bitácora no copia el comercio');

-- fin_msi.precio_contado_centavos y fin_estados_cuenta.pagos_al_corte_centavos
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_msi (id, hogar_id, libro_id, deuda_id, tarjeta_deuda_id, cuenta_pasivo_id,
    fecha_compra, monto_total_centavos, mensualidades, precio_contado_centavos)
  values ('a8600000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
          'e8600000-0000-4000-8000-000000000002', 'e8600000-0000-4000-8000-000000000001', 'c8600000-0000-4000-8000-000000000003',
          '2026-10-01', 1050000, 10, 1000000)$$), 1, '1: un MSI se crea con su precio de contado');
select pruebas.igual((select precio_contado_centavos from public.fin_msi where id = 'a8600000-0000-4000-8000-000000000001'), 1000000::bigint,
  '1: y queda guardado');
select pruebas.falla($$update public.fin_msi set precio_contado_centavos = 1$$, '1: el precio de contado no se cambia después (se declara otro)', '42501');
select pruebas.falla($$insert into public.fin_msi (id, hogar_id, libro_id, deuda_id, cuenta_pasivo_id, fecha_compra, monto_total_centavos,
    mensualidades, precio_contado_centavos) values ('a8600000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
    pruebas.libro_personal('alex@ejemplo.test'), 'e8600000-0000-4000-8000-000000000002', 'c8600000-0000-4000-8000-000000000003',
    '2026-10-01', 1, 2, 0)$$, '1: el precio de contado es mayor que cero', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, intereses_centavos, registrado_en, pagos_al_corte_centavos)
  values ('b8600000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
          'e8600000-0000-4000-8000-000000000001', '2026-10-20', '2026-11-09', 300000, 30000, 300000, 4100, '2026-10-22 10:00-06', 30000)$$), 1,
  '1: un estado de cuenta guarda el pago hecho entre el corte y la fecha límite');
select pruebas.igual((select pagos_al_corte_centavos from public.fin_v_estados_cuenta_vigentes where id = 'b8600000-0000-4000-8000-000000000001'),
  30000::bigint, '1: y la vista de vigentes lo muestra');
select pruebas.igual(pruebas.afecta($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('b8600000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
          'e8600000-0000-4000-8000-000000000001', '2026-09-20', '2026-10-09', 300000, 30000, 300000, '2026-09-22 10:00-06')$$), 1,
  '1: sin el dato, el estado entra igual');
select pruebas.ok((select pagos_al_corte_centavos is null from public.fin_estados_cuenta where id = 'b8600000-0000-4000-8000-000000000002'),
  '1 (H-02): sin el dato, pagos_al_corte_centavos queda NULO (sin dato), no 0');
select pruebas.ok((select pagos_al_corte_centavos is null from public.fin_v_estados_cuenta_vigentes where id = 'b8600000-0000-4000-8000-000000000002'),
  '1 (H-02): y la vista de vigentes también lo da como nulo');
select pruebas.igual(pruebas.afecta($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en, pagos_al_corte_centavos)
  values ('b8600000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
          'e8600000-0000-4000-8000-000000000001', '2026-07-20', '2026-08-09', 300000, 30000, 300000, now() + interval '1 day', 0)$$), 1,
  '1 (H-02): un 0 capturado después de la migración se guarda');
select pruebas.igual((select pagos_al_corte_centavos from public.fin_v_estados_cuenta_vigentes where id = 'b8600000-0000-4000-8000-000000000003'),
  0::bigint, '1 (H-02): y la vista lo muestra como 0 real (no pagó nada)');
select pruebas.igual(pruebas.afecta($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en, pagos_al_corte_centavos)
  values ('b8600000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
          'e8600000-0000-4000-8000-000000000001', '2026-06-20', '2026-07-09', 300000, 30000, 300000, '2026-06-22 10:00-06', 0)$$), 1,
  '1 (H-02): un registro anterior a la migración con 0 (el valor por omisión de entonces)');
select pruebas.ok((select pagos_al_corte_centavos is null from public.fin_v_estados_cuenta_vigentes where id = 'b8600000-0000-4000-8000-000000000004'),
  '1 (H-02): la vista lo devuelve como nulo (sin dato): ese 0 nunca se capturó');
select pruebas.falla($$insert into public.fin_estados_cuenta (hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en, pagos_al_corte_centavos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'e8600000-0000-4000-8000-000000000001',
          '2026-08-20', '2026-09-09', 1, 1, 1, now(), -1)$$, '1: el pago al corte no es negativo', '23514');
select pruebas.falla($$update public.fin_estados_cuenta set pagos_al_corte_centavos = 1$$, '1: el estado de cuenta sigue sin editarse', '42501');

-- ---------------------------------------------------------------- 2: SQ-1 · RLS, sin update ni delete, solo agregar
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname in ('fin_fuga_parametros', 'fin_patrones_cobro', 'fin_fuga_clasificaciones',
      'fin_fuga_respuestas', 'fin_deuda_propositos', 'fin_deuda_semaforo') and c.relrowsecurity), 6,
  '2 (SQ-1): las seis tablas nuevas tienen RLS');
select pruebas.igual((select count(*)::int from unnest(array['fin_fuga_parametros', 'fin_patrones_cobro', 'fin_fuga_clasificaciones',
      'fin_fuga_respuestas', 'fin_deuda_propositos', 'fin_deuda_semaforo']) t
    where has_table_privilege('authenticated', 'public.' || t, 'update') or has_table_privilege('authenticated', 'public.' || t, 'delete')
       or has_table_privilege('authenticated', 'public.' || t, 'insert') or has_table_privilege('authenticated', 'public.' || t, 'truncate')
       or has_table_privilege('service_role', 'public.' || t, 'update') or has_table_privilege('service_role', 'public.' || t, 'delete')
       or has_table_privilege('anon', 'public.' || t, 'select')), 0,
  '2 (SQ-1): authenticated no inserta, actualiza, borra ni trunca; service_role no cambia; anon no lee');
select pruebas.igual((select count(*)::int from unnest(array['fin_fuga_parametros', 'fin_patrones_cobro', 'fin_fuga_clasificaciones',
      'fin_fuga_respuestas', 'fin_deuda_propositos', 'fin_deuda_semaforo']) t
    where has_table_privilege('authenticated', 'public.' || t, 'select')), 6, '2: authenticated sí las lee (filtrado por RLS)');
select pruebas.igual((select count(*)::int from pg_trigger g join pg_class c on c.oid = g.tgrelid
    where c.relname in ('fin_fuga_parametros', 'fin_patrones_cobro', 'fin_fuga_clasificaciones', 'fin_fuga_respuestas',
      'fin_deuda_propositos', 'fin_deuda_semaforo') and g.tgname in ('fin_solo_agregar', 'fin_sin_truncate', 'fin_z_bitacora')), 18,
  '2: cada tabla lleva sus triggers de solo-agregar, sin truncate y bitácora');

-- ---------------------------------------------------------------- 3: patrones (RPC)
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'alex'),
  'streaming ejemplo', 'c1000000-0000-4000-8000-000000000001', 'mensual', true, 'comercio|streaming ejemplo|c1', 'detectado'),
  'f8600000-0000-4000-8000-000000000001'::uuid, '3: Alex crea un patrón en su libro');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'alex'),
  'streaming ejemplo', 'c1000000-0000-4000-8000-000000000001', 'mensual', true, 'comercio|streaming ejemplo|c1', 'detectado'),
  'f8600000-0000-4000-8000-000000000001'::uuid, '3: reenviarlo (la cola) devuelve el mismo patrón');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-0000000000a1', (select id from t_ids where clave = 'alex'),
  'streaming ejemplo', 'c1000000-0000-4000-8000-000000000001', 'mensual', true, 'comercio|streaming ejemplo|c1', 'detectado'),
  'f8600000-0000-4000-8000-000000000001'::uuid, '3: otro dispositivo con la misma clave obtiene el existente');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro), 1, '3: y no hay duplicado');
select pruebas.falla($$select public.fin_patron_crear('f8600000-0000-4000-8000-0000000000a2', (select id from t_ids where clave = 'alex'),
  'x', null, 'cada_dia', false)$$, '3: la cadencia es del catálogo', '23514');
select pruebas.falla($$select public.fin_patron_crear(null, (select id from t_ids where clave = 'alex'), 'x', null, 'mensual', false)$$,
  '3: el id es obligatorio', '22023');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-000000000002', (select id from t_ids where clave = 'alex'),
  null, 'c1000000-0000-4000-8000-000000000001', 'irregular', false), 'f8600000-0000-4000-8000-000000000002'::uuid,
  '3: sin clave ni comercio se arma una clave por categoría');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_patron_crear('f8600000-0000-4000-8000-0000000000a3', (select id from t_ids where clave = 'alex'),
  'x', null, 'mensual', false)$$, '3: Ana no escribe en el libro personal de Alex', '42501');
select pruebas.igual(pruebas.cuenta('select * from public.fin_patrones_cobro'), 0, '3 (SQ-3): ni lo lee');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-000000000011', (select id from t_ids where clave = 'ana'),
  'gimnasio ejemplo', 'c1000000-0000-4000-8000-000000000001', 'mensual', true), 'f8600000-0000-4000-8000-000000000011'::uuid,
  '3: Ana crea uno en su libro');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-000000000012', 'f1000000-0000-4000-8000-000000000001',
  'agua ejemplo', 'c1000000-0000-4000-8000-000000000001', 'mensual', true, null, 'manual', 'e3000000-0000-4000-8000-000000000003'),
  'f8600000-0000-4000-8000-000000000012'::uuid, '3: y uno del compartido, ligado al compromiso del agua');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro), 3,
  '3 (SQ-3): Alex ve los dos suyos y el del compartido; no el libro personal de Ana');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000011'), 0,
  '3: en concreto, no ve el de Ana');

-- ---------------------------------------------------------------- 4: respuestas
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000001', 'f8600000-0000-4000-8000-000000000001', 'reconoce', 'no'),
  'a9600000-0000-4000-8000-000000000001'::uuid, '4: "No lo conocía"');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000001', 'f8600000-0000-4000-8000-000000000001', 'reconoce', 'no'),
  'a9600000-0000-4000-8000-000000000001'::uuid, '4: reenviarla (la cola) devuelve la misma');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000002', 'f8600000-0000-4000-8000-000000000001', 'reconoce', 'no'),
  'a9600000-0000-4000-8000-000000000001'::uuid, '4: decir lo mismo en el mismo periodo no agrega otra fila');
select pruebas.igual((select count(*)::int from public.fin_fuga_respuestas), 1, '4: sigue habiendo una');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000003', 'f8600000-0000-4000-8000-000000000001', 'reconoce', 'si'),
  'a9600000-0000-4000-8000-000000000003'::uuid, '4: corregir a "Sí, lo conozco" agrega una fila nueva');
select pruebas.igual((select reemplaza_a from public.fin_fuga_respuestas where id = 'a9600000-0000-4000-8000-000000000003'),
  'a9600000-0000-4000-8000-000000000001'::uuid, '4: que reemplaza a la anterior (la pone el servidor)');
select pruebas.igual((select count(*)::int from public.fin_fuga_respuestas), 2, '4: el historial conserva las dos');
select pruebas.igual((select id from public.fin_v_fuga_respuestas_vigentes where patron_id = 'f8600000-0000-4000-8000-000000000001' and pregunta = 'reconoce'),
  'a9600000-0000-4000-8000-000000000003'::uuid, '4: la vigente es la corrección');
-- "No lo usé" en dos periodos distintos: las dos cuentan (la última de cada periodo)
select public.fin_fuga_responder('a9600000-0000-4000-8000-000000000004', 'f8600000-0000-4000-8000-000000000001', 'uso', 'no',
  public.fin_fugas_lunes(current_date - 14));
select public.fin_fuga_responder('a9600000-0000-4000-8000-000000000005', 'f8600000-0000-4000-8000-000000000001', 'uso', 'no',
  public.fin_fugas_lunes(current_date - 7));
select pruebas.igual((select count(*)::int from public.fin_v_fuga_respuestas_vigentes where pregunta = 'uso' and respuesta = 'no'), 2,
  '4: dos "No lo usé" de periodos distintos');
select pruebas.igual((select count(*)::int from public.fin_fuga_respuestas where pregunta = 'uso'), 2, '4: son dos filas independientes');
-- valores que no estaban en el catálogo de 6.2
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000006', 'f8600000-0000-4000-8000-000000000001', 'ya_no_la_quiero', 'si'),
  'a9600000-0000-4000-8000-000000000006'::uuid, '4: admite ya_no_la_quiero (Z4)');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000007', 'f8600000-0000-4000-8000-000000000001', 'duplicado', 'si'),
  'a9600000-0000-4000-8000-000000000007'::uuid, '4: admite duplicado (Z2)');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000008', 'f8600000-0000-4000-8000-000000000001', 'plan_viejo', 'si'),
  'a9600000-0000-4000-8000-000000000008'::uuid, '4: admite plan_viejo (Z3)');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000009', 'f8600000-0000-4000-8000-000000000001', 'ya_no_existe', 'si'),
  'a9600000-0000-4000-8000-000000000009'::uuid, '4: y ya_no_existe (Z5) y ya_no_sirve (Z1)');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'inventada', 'si')$$,
  '4: una pregunta fuera del catálogo se rechaza', '22023');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'uso', 'quizas')$$,
  '4: una respuesta fuera del catálogo también', '22023');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'cancelado', 'si')$$,
  '4: cancelar va por fin_patron_cancelar', '22023');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'uso', 'no', current_date + 3)$$,
  '4: el periodo es un lunes y no futuro', '22023');
select pruebas.falla($$select public.fin_fuga_responder('a9600000-0000-4000-8000-000000000001', 'f8600000-0000-4000-8000-000000000002', 'reconoce', 'si')$$,
  '4: el mismo id con otro contenido es un duplicado real', '23505');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), gen_random_uuid(), 'uso', 'si')$$,
  '4: un patrón que no existe no revela nada (42501)', '42501');

-- cancelación: fecha y folio
select pruebas.igual(public.fin_patron_cancelar('a9600000-0000-4000-8000-0000000000c1', 'f8600000-0000-4000-8000-000000000001', current_date),
  'a9600000-0000-4000-8000-0000000000c1'::uuid, '4 (DF-26): cancelar sin folio');
select pruebas.igual((select cancelado_sin_folio from public.fin_v_patrones_estado where patron_id = 'f8600000-0000-4000-8000-000000000001'), true,
  '4: queda "cancelado sin folio" (pendiente de completar)');
select pruebas.igual((select folio from public.fin_fuga_respuestas where id = 'a9600000-0000-4000-8000-0000000000c1') is null, true,
  '4: sin folio guardado');
select pruebas.igual(public.fin_patron_cancelar('a9600000-0000-4000-8000-0000000000c2', 'f8600000-0000-4000-8000-000000000001', current_date, 'ABC-123'),
  'a9600000-0000-4000-8000-0000000000c2'::uuid, '4 (DF-26): completar con el folio ABC-123 agrega una fila que reemplaza');
select pruebas.igual((select reemplaza_a from public.fin_fuga_respuestas where id = 'a9600000-0000-4000-8000-0000000000c2'),
  'a9600000-0000-4000-8000-0000000000c1'::uuid, '4: reemplaza a la cancelación sin folio');
select pruebas.igual((select cancelado_en = current_date and not cancelado_sin_folio and folio_cancelacion = 'ABC-123'
  from public.fin_v_patrones_estado where patron_id = 'f8600000-0000-4000-8000-000000000001'), true,
  '4: el estado derivado es cancelado, con fecha y folio');
select pruebas.falla($$select public.fin_patron_cancelar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000002', current_date, 'AB C')$$,
  '4 (DF-26): un folio con espacios se rechaza', '22023');
select pruebas.falla($$select public.fin_patron_cancelar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000002', current_date, repeat('A', 41))$$,
  '4 (DF-26): y uno de más de 40 caracteres', '22023');
select pruebas.igual(public.fin_patron_cancelar('a9600000-0000-4000-8000-0000000000c3', 'f8600000-0000-4000-8000-000000000002', current_date, repeat('A', 40)),
  'a9600000-0000-4000-8000-0000000000c3'::uuid, '4: un folio de exactamente 40 caracteres sí entra');
select pruebas.igual(public.fin_patron_cancelar('a9600000-0000-4000-8000-0000000000c4', 'f8600000-0000-4000-8000-000000000002', current_date, '   ') is not null, true,
  '4: un folio en blanco cuenta como sin folio (y reemplaza al anterior)');
select pruebas.falla($$select public.fin_patron_cancelar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000002', current_date + 10)$$,
  '4: la fecha de cancelación no es futura', '22023');
select pruebas.falla($$select public.fin_patron_cancelar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000002', null)$$,
  '4: y es obligatoria', '22023');
-- compromiso ligado: hasta = fecha de cancelación
select pruebas.como('ana@ejemplo.test');
select public.fin_patron_cancelar('a9600000-0000-4000-8000-0000000000c5', 'f8600000-0000-4000-8000-000000000012', current_date, 'AGUA-1');
select pruebas.como_postgres();
select pruebas.igual((select hasta from public.fin_compromisos where id = 'e3000000-0000-4000-8000-000000000003'), current_date,
  '4: el compromiso ligado deja de proponerse (hasta = fecha de cancelación)');
-- integridad directa de la tabla (rol postgres, sin RPC; la sesión sigue siendo la de Alex para los defaults)
select pruebas.como_postgres();
select set_config('request.jwt.claim.sub', pruebas.id_usuario('alex@ejemplo.test')::text, true),
  set_config('request.jwt.claims', json_build_object('sub', pruebas.id_usuario('alex@ejemplo.test'), 'role', 'authenticated')::text, true);
select pruebas.falla($$insert into public.fin_fuga_respuestas (hogar_id, libro_id, patron_id, pregunta, respuesta, periodo_lunes, fecha_cancelacion)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000002'),
  'f8600000-0000-4000-8000-000000000002', 'cancelado', 'no', public.fin_fugas_lunes(current_date), current_date)$$,
  '4: una fecha de cancelación solo va con un "ya lo cancelé"', '23514');
select pruebas.falla($$insert into public.fin_fuga_respuestas (hogar_id, libro_id, patron_id, pregunta, respuesta, periodo_lunes, folio)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000002'),
  'f8600000-0000-4000-8000-000000000002', 'uso', 'si', public.fin_fugas_lunes(current_date), 'ABC')$$,
  '4: un folio solo va con fecha de cancelación', '23514');
select pruebas.falla($$insert into public.fin_fuga_respuestas (hogar_id, libro_id, patron_id, pregunta, respuesta, periodo_lunes)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000002'),
  'f8600000-0000-4000-8000-000000000002', 'uso', 'si', current_date + (8 - extract(isodow from current_date)::int + 1))$$,
  '4: el periodo es un lunes (cualquier otro día se rechaza)', '23514');
select pruebas.falla($$insert into public.fin_fuga_respuestas (hogar_id, libro_id, patron_id, pregunta, respuesta, periodo_lunes, reemplaza_a)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000001'),
  'f8600000-0000-4000-8000-000000000001', 'reconoce', 'no', public.fin_fugas_lunes(current_date), 'a9600000-0000-4000-8000-000000000001')$$,
  '4 (SQ-6): una respuesta no admite dos reemplazos', '23505');
select pruebas.falla($$update public.fin_fuga_respuestas set respuesta = 'si'$$, '4: las respuestas no se editan (ni el dueño de la tabla)', '42501');
select pruebas.falla($$delete from public.fin_fuga_respuestas$$, '4: ni se borran', '42501');
select pruebas.falla($$truncate public.fin_fuga_respuestas$$, '4: ni se truncan', '42501');

-- ---------------------------------------------------------------- 5: clasificaciones (la persona gana a la regla)
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma')$$,
  '5 (SQ-7): contradecir a la regla sin motivo se rechaza', '22023');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma', 'ab')$$,
  '5 (SQ-7): con 2 caracteres tampoco', '22023');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma', repeat('x', 201))$$,
  '5 (SQ-7): ni con más de 200', '22023');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma', 'ab' || chr(8203))$$,
  '5 (SQ-7): ni con caracteres invisibles', '22023');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'zombie', 'fantasma', 'Lo uso para trabajar', null, true)$$,
  '5: "Vigilar" no es una fuga (va con ninguna)', '22023');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'inventada', 'fantasma', 'Lo uso para trabajar')$$,
  '5: la fuga es del catálogo', '22023');
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000001', 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma',
  'Lo uso para trabajar', 'F3'), 'c9600000-0000-4000-8000-000000000001'::uuid, '5 (DF-18): "No es una fuga" con motivo');
select pruebas.igual((select protegido from public.fin_v_patrones_estado where patron_id = 'f8600000-0000-4000-8000-000000000001'), true,
  '5: el patrón queda protegido');
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000001', 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma',
  'Lo uso para trabajar', 'F3'), 'c9600000-0000-4000-8000-000000000001'::uuid, '5: reenviarla (la cola) no duplica');
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000009', 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'fantasma',
  'Lo uso para trabajar', 'F3'), 'c9600000-0000-4000-8000-000000000001'::uuid, '5: la misma decisión vigente no se repite');
select pruebas.igual((select count(*)::int from public.fin_fuga_clasificaciones), 1, '5: una sola fila hasta ahora');
-- corrección por fila nueva
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000002', 'f8600000-0000-4000-8000-000000000001', 'zombie', 'fantasma',
  'Ya no lo uso', 'Z1', false, 8900), 'c9600000-0000-4000-8000-000000000002'::uuid, '5: cambiar de opinión agrega una fila nueva');
select pruebas.igual((select reemplaza_a from public.fin_fuga_clasificaciones where id = 'c9600000-0000-4000-8000-000000000002'),
  'c9600000-0000-4000-8000-000000000001'::uuid, '5 (4.3): reemplaza a la anterior (la pone el servidor)');
select pruebas.igual((select count(*)::int from public.fin_fuga_clasificaciones), 2, '5: y la anterior queda en el historial');
select pruebas.igual((select id from public.fin_v_fuga_clasificaciones_vigentes where patron_id = 'f8600000-0000-4000-8000-000000000001'),
  'c9600000-0000-4000-8000-000000000002'::uuid, '5: la vigente es la corrección');
select pruebas.igual((select protegido from public.fin_v_patrones_estado where patron_id = 'f8600000-0000-4000-8000-000000000001'), false,
  '5: y el patrón ya no está protegido');
select pruebas.igual((select fuga || '/' || motivo from public.fin_fuga_clasificaciones where id = 'c9600000-0000-4000-8000-000000000001'),
  'ninguna/Lo uso para trabajar', '5: la fila anterior sigue intacta');
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000003', 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'zombie',
  null, null, true), 'c9600000-0000-4000-8000-000000000003'::uuid, '5: "Lo necesito pero lo quiero revisar" no pide motivo');
select pruebas.igual((select vigilar from public.fin_v_patrones_estado where patron_id = 'f8600000-0000-4000-8000-000000000001'), true,
  '5: queda en "Vigilar"');
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000004', 'f8600000-0000-4000-8000-000000000002', 'hormiga', 'hormiga'),
  'c9600000-0000-4000-8000-000000000004'::uuid, '5: aceptar lo que dijo la regla no pide motivo');
-- integridad directa
select pruebas.como_postgres();
select set_config('request.jwt.claim.sub', pruebas.id_usuario('alex@ejemplo.test')::text, true),
  set_config('request.jwt.claims', json_build_object('sub', pruebas.id_usuario('alex@ejemplo.test'), 'role', 'authenticated')::text, true);
select pruebas.falla($$insert into public.fin_fuga_clasificaciones (hogar_id, libro_id, patron_id, fuga, origen, fuga_regla, reemplaza_a)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000001'),
  'f8600000-0000-4000-8000-000000000001', 'vampiro', 'persona', 'fantasma', 'c9600000-0000-4000-8000-000000000001')$$,
  '5 (SQ-6): una clasificación no admite dos reemplazos de la misma fila (también sin motivo: el motivo se valida después)', '22023');
select pruebas.falla($$insert into public.fin_fuga_clasificaciones (hogar_id, libro_id, patron_id, fuga, origen, fuga_regla, reemplaza_a, motivo)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000001'),
  'f8600000-0000-4000-8000-000000000001', 'vampiro', 'persona', 'fantasma', 'c9600000-0000-4000-8000-000000000001', 'Otro motivo')$$,
  '5 (SQ-6): con motivo, el segundo reemplazo de la misma fila lo rechaza el índice único', '23505');
select pruebas.falla($$insert into public.fin_fuga_clasificaciones (hogar_id, libro_id, patron_id, fuga, origen, fuga_regla)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000002'),
  'f8600000-0000-4000-8000-000000000002', 'ninguna', 'persona', 'hormiga')$$,
  '5 (SQ-7): sin pasar por la RPC, contradecir a la regla sin motivo también se rechaza (trigger)', '22023');
select pruebas.falla($$insert into public.fin_fuga_clasificaciones (hogar_id, libro_id, patron_id, fuga, origen)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000002'),
  'f8600000-0000-4000-8000-000000000002', 'ninguna', 'persona')$$,
  '5: una decisión de la persona dice qué había dicho la regla', '23514');
select pruebas.falla($$insert into public.fin_fuga_clasificaciones (hogar_id, libro_id, patron_id, fuga, origen)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000001'),
  'f8600000-0000-4000-8000-000000000001', 'hormiga', 'regla')$$,
  '5: un patrón tiene una sola cadena de clasificaciones (una raíz)', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_fuga_clasificaciones (hogar_id, libro_id, patron_id, fuga, origen, regla)
  values ('b0000000-0000-4000-8000-000000000001', (select libro_id from public.fin_patrones_cobro where id = 'f8600000-0000-4000-8000-000000000011'),
  'f8600000-0000-4000-8000-000000000011', 'fantasma', 'regla', 'F3')$$), 1, '5: la regla puede dejar su propia fila (origen regla)');
select pruebas.falla($$update public.fin_fuga_clasificaciones set fuga = 'hormiga'$$, '5: las clasificaciones no se editan', '42501');
select pruebas.falla($$delete from public.fin_fuga_clasificaciones$$, '5: ni se borran', '42501');

-- ---------------------------------------------------------------- 6: propósito de una deuda
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000001', 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso',
  'Laptop de trabajo', null, null, 48, 'vigente', false, 1000000), 'd9600000-0000-4000-8000-000000000001'::uuid,
  '6: Alex declara el propósito de su MSI');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000001', 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso',
  'Laptop de trabajo', null, null, 48, 'vigente', false, 1000000), 'd9600000-0000-4000-8000-000000000001'::uuid, '6: reenviarla no duplica');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso', 'Laptop de 2026')$$,
  '6: el objetivo no lleva cifras', '22023');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso', 'Cuesta $ mucho')$$,
  '6: ni el signo de pesos', '22023');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso', repeat('a', 81))$$,
  '6: ni pasa de 80 caracteres', '22023');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'inventado')$$,
  '6: el propósito es del catálogo', '22023');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'consumo', null, null, null, null, 'perdido')$$,
  '6: el estado del objetivo también', '22023');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'consumo', null, null, null, 0)$$,
  '6: la vida útil es de 1 a 600 meses', '23514');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000002', 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso',
  'Laptop de trabajo', null, null, 48, 'vigente', true), 'd9600000-0000-4000-8000-000000000002'::uuid,
  '6 (B5): marcar "lo uso poco" agrega otra declaración');
select pruebas.igual((select reemplaza_a from public.fin_deuda_propositos where id = 'd9600000-0000-4000-8000-000000000002'),
  'd9600000-0000-4000-8000-000000000001'::uuid, '6: que reemplaza a la anterior');
select pruebas.igual((select uso_poco from public.fin_v_deuda_propositos_vigentes where deuda_id = 'e8600000-0000-4000-8000-000000000002'), true,
  '6: la vigente trae uso_poco');
select pruebas.igual((select count(*)::int from public.fin_deuda_propositos), 2, '6: y el historial conserva las dos');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000003', 'e8600000-0000-4000-8000-000000000002', 'genera_ingreso',
  'Laptop de trabajo', null, null, 48, 'ya_no_existe', true), 'd9600000-0000-4000-8000-000000000003'::uuid, '6: "ya no existe" también');
select pruebas.igual((select estado_objetivo from public.fin_v_deuda_propositos_vigentes where deuda_id = 'e8600000-0000-4000-8000-000000000002'),
  'ya_no_existe', '6: la vigente es la más reciente');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'consumo', null, gen_random_uuid())$$,
  '6: el bien debe ser del mismo libro', '23503');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'consumo')$$,
  '6: Ana no declara propósitos de las deudas personales de Alex', '42501');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), gen_random_uuid(), 'consumo')$$,
  '6: una deuda que no existe da lo mismo (42501)', '42501');
select pruebas.igual(pruebas.cuenta('select * from public.fin_deuda_propositos'), 0, '6 (SQ-3): ni los lee');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000011', 'e8600000-0000-4000-8000-000000000004', 'patrimonio',
  'Mejoras de la casa'), 'd9600000-0000-4000-8000-000000000011'::uuid, '6: en el compartido, cualquier miembro declara');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000012', 'e8600000-0000-4000-8000-000000000004', 'patrimonio',
  'Mejoras de la casa', null, null, null, 'cumplido'), 'd9600000-0000-4000-8000-000000000012'::uuid,
  '6: y el otro miembro lo corrige (vale la más reciente)');
select pruebas.igual((select count(*)::int from public.fin_deuda_propositos where deuda_id = 'e8600000-0000-4000-8000-000000000004'), 2,
  '6: los dos miembros ven las dos filas');

-- ---------------------------------------------------------------- 7: parámetros por libro
select pruebas.igual((select count(*)::int from public.fin_v_fuga_parametros_vigentes), 0, '7: sin cambios no hay fila (la app usa sus valores por omisión)');
select pruebas.igual(public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), 'a7600000-0000-4000-8000-000000000001',
  p_tope_hormiga_centavos => 20000), 'a7600000-0000-4000-8000-000000000001'::uuid, '7: Alex sube el tope hormiga');
select pruebas.igual((select tope_hormiga_centavos::text || '/' || hormiga_min_gastos::text || '/' || msi_activos_rojo::text
  from public.fin_v_fuga_parametros_vigentes where libro_id = (select id from t_ids where clave = 'alex')), '20000/8/4',
  '7: lo demás conserva los valores por omisión de la spec');
select pruebas.igual(public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), 'a7600000-0000-4000-8000-000000000001',
  p_tope_hormiga_centavos => 20000), 'a7600000-0000-4000-8000-000000000001'::uuid, '7: reenviarlo no duplica');
create temp table t_par (id uuid);
grant all on t_par to public;
insert into t_par select public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), null, p_msi_rojo_pb => 3000);
select pruebas.igual((select id from public.fin_v_fuga_parametros_vigentes where libro_id = (select id from t_ids where clave = 'alex')),
  (select id from t_par), '7: otro cambio agrega una fila y esa pasa a ser la vigente');
select pruebas.igual((select tope_hormiga_centavos::text || '/' || msi_rojo_pb::text from public.fin_v_fuga_parametros_vigentes
  where libro_id = (select id from t_ids where clave = 'alex')), '20000/3000', '7: conserva el cambio anterior');
select pruebas.igual((select count(*)::int from public.fin_fuga_parametros), 2, '7: y el historial tiene las dos filas');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), null, p_msi_ambar_pb => 5000)$$,
  '7: el ámbar no pasa del rojo', '23514');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), null, p_hormiga_min_semanas => 5)$$,
  '7: las semanas mínimas van de 1 a 4', '23514');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), null, p_tope_hormiga_centavos => 0)$$,
  '7: el tope es positivo', '23514');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'), null, p_tope_hormiga_centavos => 100)$$,
  '7: Ana no cambia los umbrales de Alex', '42501');

-- ---------------------------------------------------------------- 8: semáforo de la deuda
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_deuda_semaforo_registrar('a8700000-0000-4000-8000-000000000001', 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'rojo', array['B1', 'M3', 'B4b']), true, '8: se registra el primer nivel');
select pruebas.igual(public.fin_deuda_semaforo_registrar('a8700000-0000-4000-8000-000000000002', 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'rojo', array['B1']), false, '8: el mismo nivel no agrega nada');
select pruebas.igual(public.fin_deuda_semaforo_registrar('a8700000-0000-4000-8000-000000000001', 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'ambar'), false, '8: reenviar el mismo id no duplica');
select pruebas.igual(public.fin_deuda_semaforo_registrar('a8700000-0000-4000-8000-000000000003', 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'rojo', array['B1'], 1), true, '8: cambia el contador de bajas (histéresis): se agrega');
select pruebas.igual(public.fin_deuda_semaforo_registrar('a8700000-0000-4000-8000-000000000004', 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'ambar', array['B4c']), true, '8: cambia el nivel: se agrega');
select pruebas.igual((select nivel from public.fin_v_deuda_semaforo_actual where deuda_id = 'e8600000-0000-4000-8000-000000000002'), 'ambar',
  '8: el actual es el último');
select pruebas.igual((select count(*)::int from public.fin_deuda_semaforo), 3, '8: el historial conserva las filas');
select pruebas.falla($$select public.fin_deuda_semaforo_registrar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'azul')$$, '8: el nivel es verde, ambar, rojo o gris', '22023');
select pruebas.falla($$select public.fin_deuda_semaforo_registrar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'verde', array['x9'])$$, '8: las señales son códigos (B1 a M8), no texto', '23514');
select pruebas.falla($$select public.fin_deuda_semaforo_registrar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002',
  public.fin_fugas_lunes(current_date), 'verde', array['Laptop de 2026'])$$, '8: ni cifras ni nombres', '23514');
select pruebas.falla($$select public.fin_deuda_semaforo_registrar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002',
  current_date + 1, 'verde')$$, '8: el lunes es lunes (si no, falla)', '23514');

-- ---------------------------------------------------------------- 9: familiar, cuidadora, Casa, anon y otro hogar: nada (SQ-2)
select pruebas.como_postgres();
create temp table t_tablas (t text);
grant all on t_tablas to public;
insert into t_tablas values ('fin_fuga_parametros'), ('fin_patrones_cobro'), ('fin_fuga_clasificaciones'), ('fin_fuga_respuestas'),
  ('fin_deuda_propositos'), ('fin_deuda_semaforo'), ('fin_v_fuga_parametros_vigentes'), ('fin_v_fuga_clasificaciones_vigentes'),
  ('fin_v_fuga_respuestas_vigentes'), ('fin_v_deuda_propositos_vigentes'), ('fin_v_deuda_semaforo_actual'), ('fin_v_patrones_estado');
create function pg_temp.visibles() returns integer language plpgsql as $$
declare
  v_t text;
  v_n integer := 0;
  v_k integer;
begin
  for v_t in select t from t_tablas loop
    execute format('select count(*) from public.%I', v_t) into v_k;
    v_n := v_n + v_k;
  end loop;
  return v_n;
end $$;
grant execute on function pg_temp.visibles() to public;
select pruebas.ok(pg_temp.visibles() > 0, '9: hay datos de las tablas nuevas para que la prueba tenga sentido');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pg_temp.visibles(), 0, '9 (SQ-2): la familiar no lee ninguna tabla ni vista nueva');
select pruebas.falla($$select public.fin_patron_crear(gen_random_uuid(), 'f1000000-0000-4000-8000-000000000001', 'x', null, 'mensual', false)$$,
  '9 (SQ-2): la familiar no crea patrones', '42501');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', 'uso', 'si')$$,
  '9: ni responde', '42501');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', 'ninguna', 'ninguna')$$,
  '9: ni clasifica', '42501');
select pruebas.falla($$select public.fin_patron_cancelar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', current_date)$$,
  '9: ni cancela', '42501');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000004', 'consumo')$$,
  '9: ni declara propósitos', '42501');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar('f1000000-0000-4000-8000-000000000001')$$, '9: ni cambia umbrales', '42501');
select pruebas.falla($$select public.fin_deuda_semaforo_registrar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000004', public.fin_fugas_lunes(current_date), 'rojo')$$,
  '9: ni registra el semáforo', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pg_temp.visibles(), 0, '9 (SQ-2): la cuidadora no lee nada');
select pruebas.falla($$select public.fin_patron_crear(gen_random_uuid(), 'f1000000-0000-4000-8000-000000000001', 'x', null, 'mensual', false)$$,
  '9: ni crea patrones', '42501');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', 'uso', 'si')$$, '9: ni responde', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pg_temp.visibles(), 0, '9 (SQ-2): Casa (la tablet pública) no lee nada');
select pruebas.falla($$select public.fin_patron_crear(gen_random_uuid(), 'f1000000-0000-4000-8000-000000000001', 'x', null, 'mensual', false)$$,
  '9: ni crea patrones', '42501');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', 'uso', 'si')$$, '9: ni responde', '42501');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000004', 'consumo')$$, '9: ni declara', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pg_temp.visibles(), 0, '9: otro hogar no ve nada');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', 'uso', 'si')$$, '9: ni responde', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_patrones_cobro$$, '9: anon no lee (sin permiso)', '42501');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000012', 'uso', 'si')$$,
  '9: ni ejecuta las RPC', '42501');
select pruebas.falla($$select public.fin_fugas_exigir('f1000000-0000-4000-8000-000000000001', 'leer')$$, '9: las funciones internas no se ejecutan desde la app', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_fugas_exigir('f1000000-0000-4000-8000-000000000001', 'leer')$$, '9: tampoco con sesión', '42501');
select pruebas.falla($$insert into public.fin_patrones_cobro (hogar_id, libro_id, clave, cadencia) values
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'directo', 'mensual')$$, '9 (SQ-1): nadie inserta directo', '42501');
select pruebas.falla($$update public.fin_patrones_cobro set cadencia = 'anual'$$, '9 (SQ-1): nadie actualiza', '42501');
select pruebas.falla($$delete from public.fin_patrones_cobro$$, '9 (SQ-1): nadie borra', '42501');

-- ---------------------------------------------------------------- 10: la cuenta maestra solo lee, con consulta vigente (SQ-4)
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pg_temp.visibles(), 0, '10 (SQ-4): sin consulta registrada, la maestra no lee nada');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'uso', 'si')$$,
  '10: ni responde', '42501');
select public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'alex'));
select pruebas.ok((select count(*) from public.fin_patrones_cobro where libro_id = (select id from t_ids where clave = 'alex')) = 2
  and (select count(*) from public.fin_deuda_propositos where libro_id = (select id from t_ids where clave = 'alex')) = 3,
  '10 (SQ-4): con consulta vigente lee las fugas y propósitos de ese libro');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro where libro_id <> (select id from t_ids where clave = 'alex')), 0,
  '10: y solo de ese libro (no de los demás)');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'uso', 'si')$$,
  '10 (SQ-4): no escribe respuestas', '42501');
select pruebas.falla($$select public.fin_patron_crear(gen_random_uuid(), (select id from t_ids where clave = 'alex'), 'x', null, 'mensual', false)$$,
  '10 (SQ-4): ni crea patrones', '42501');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000001', 'ninguna', 'ninguna')$$,
  '10: ni clasifica', '42501');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', 'consumo')$$,
  '10: ni declara propósitos', '42501');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar((select id from t_ids where clave = 'alex'))$$, '10: ni cambia umbrales', '42501');
select pruebas.falla($$select public.fin_deuda_semaforo_registrar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000002', public.fin_fugas_lunes(current_date), 'rojo')$$,
  '10: ni registra el semáforo', '42501');

-- ---------------------------------------------------------------- 11: libro de Papá (SQ-5) y vista temporal (D24)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_patron_crear('f8600000-0000-4000-8000-000000000021', 'f1000000-0000-4000-8000-000000000002',
  'farmacia ejemplo', 'c1000000-0000-4000-8000-000000000001', 'mensual', false), 'f8600000-0000-4000-8000-000000000021'::uuid,
  '11: el albacea crea un patrón en el libro de Papá');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000021', 'f8600000-0000-4000-8000-000000000021', 'uso', 'no'),
  'a9600000-0000-4000-8000-000000000021'::uuid, '11: y responde una pregunta de uso (sin motivo)');
select pruebas.igual((select en_nombre_de from public.fin_fuga_respuestas where id = 'a9600000-0000-4000-8000-000000000021'),
  'e0000000-0000-4000-8000-000000000001'::uuid, '11: queda en nombre de Papá');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000021', 'zombie', 'zombie')$$,
  '11 (SQ-5): una decisión del albacea sobre Papá exige motivo (aunque coincida con la regla)', '22023');
select pruebas.falla($$select public.fin_patron_cancelar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000021', current_date, 'X-1')$$,
  '11: cancelar también', '22023');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000003', 'consumo')$$,
  '11: y declarar un propósito', '22023');
select pruebas.igual(public.fin_fuga_clasificar('c9600000-0000-4000-8000-000000000021', 'f8600000-0000-4000-8000-000000000021', 'zombie', 'zombie',
  'Ya no toma ese medicamento', 'Z1'), 'c9600000-0000-4000-8000-000000000021'::uuid, '11 (SQ-5): con motivo, entra');
select pruebas.igual((select en_nombre_de from public.fin_fuga_clasificaciones where id = 'c9600000-0000-4000-8000-000000000021'),
  'e0000000-0000-4000-8000-000000000001'::uuid, '11: en nombre de Papá');
select pruebas.igual(public.fin_deuda_declarar('d9600000-0000-4000-8000-000000000021', 'e8600000-0000-4000-8000-000000000003', 'educacion_o_salud',
  'Gastos de salud', null, null, null, 'vigente', false, null, 'Lo pidió Papá'), 'd9600000-0000-4000-8000-000000000021'::uuid,
  '11: el propósito de una deuda de Papá entra con motivo');
select pruebas.igual(public.fin_deuda_semaforo_registrar('a8700000-0000-4000-8000-000000000021', 'e8600000-0000-4000-8000-000000000003',
  public.fin_fugas_lunes(current_date), 'verde'), true, '11: y el semáforo (lo calcula la app, sin motivo)');
delete from t_par;
insert into t_par select public.fin_fuga_parametros_cambiar('f1000000-0000-4000-8000-000000000002', null, p_tope_hormiga_centavos => 9000, p_motivo => 'Gasto menudo de Papá');
select pruebas.igual((select id from public.fin_v_fuga_parametros_vigentes where libro_id = 'f1000000-0000-4000-8000-000000000002'),
  (select id from t_par), '11: y los umbrales, con motivo');
select pruebas.falla($$select public.fin_fuga_parametros_cambiar('f1000000-0000-4000-8000-000000000002', null, p_tope_hormiga_centavos => 9100)$$,
  '11: sin motivo no', '22023');
-- El suplente lee (fin_puede leer) pero escribe solo sin albacea vigente.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro where libro_id = 'f1000000-0000-4000-8000-000000000002'), 1,
  '11 (SQ-5): el suplente lee las fugas de Papá');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000021', 'uso', 'si')$$,
  '11 (SQ-5): pero con albacea vigente no escribe', '42501');
select pruebas.falla($$select public.fin_patron_crear(gen_random_uuid(), 'f1000000-0000-4000-8000-000000000002', 'x', null, 'mensual', false)$$,
  '11: ni crea', '42501');
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = now() where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_fuga_responder('a9600000-0000-4000-8000-000000000022', 'f8600000-0000-4000-8000-000000000021', 'uso', 'si',
  null, null, null), 'a9600000-0000-4000-8000-000000000022'::uuid,
  '11 (SQ-5): sin albacea vigente el suplente responde (sin motivo en preguntas de uso)');
select pruebas.igual((select reemplaza_a from public.fin_fuga_respuestas where id = 'a9600000-0000-4000-8000-000000000022'),
  'a9600000-0000-4000-8000-000000000021'::uuid, '11: corrigiendo la del albacea en ese periodo');
select pruebas.falla($$select public.fin_fuga_clasificar(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000021', 'ninguna', 'zombie')$$,
  '11: y las decisiones llevan motivo también para él', '22023');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro where libro_id = 'f1000000-0000-4000-8000-000000000002'), 0,
  '11: quien dejó de ser albacea ya no lee las fugas de Papá');
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = null where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
-- Vista temporal de Papá (D24): ni lee ni escribe.
select pruebas.como('carla@ejemplo.test');
create temp table t_sol (id uuid) on commit drop;
grant all on t_sol to public;
insert into t_sol select public.fin_pedir_vista_papa('Revisar las cuentas de Papá');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol), 'autorizar');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), true, '11 (D24): la vista temporal está autorizada');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer')
  and (select count(*) from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002') > 0,
  '11 (D24): control: la familiar sí lee las cuentas de Papá con la vista');
select pruebas.igual(pg_temp.visibles(), 0, '11 (SQ-5, D24): pero no lee ninguna fuga ni propósito de Papá');
select pruebas.igual((select count(*)::int from public.fin_patrones_cobro), 0, '11: ni patrones');
select pruebas.falla($$select public.fin_fuga_responder(gen_random_uuid(), 'f8600000-0000-4000-8000-000000000021', 'uso', 'si')$$,
  '11 (D24): ni responde', '42501');
select pruebas.falla($$select public.fin_deuda_declarar(gen_random_uuid(), 'e8600000-0000-4000-8000-000000000003', 'consumo')$$,
  '11 (D24): ni declara', '42501');

-- ---------------------------------------------------------------- 12: avisos (SQ-8, D20)
select pruebas.como_postgres();
select pruebas.igual(public.avisos_severidad('fuga_por_reconocer'), 'importante', '12: fuga_por_reconocer es importante');
select pruebas.igual(public.avisos_severidad('fuga_revision_mensual'), 'informativa', '12: fuga_revision_mensual es informativa');
select pruebas.igual(public.avisos_severidad('deuda_en_vigilancia'), 'importante', '12: deuda_en_vigilancia es importante');
select pruebas.igual(public.avisos_severidad('deuda_se_volvio_mala'), 'critica', '12: deuda_se_volvio_mala es crítica');
select pruebas.igual(public.avisos_severidad('transferencia_pendiente') || public.avisos_severidad('recordatorio_toma') || public.avisos_severidad('base_90'),
  'importanteimportantecritica', '12: los tipos previos conservan su severidad');
select pruebas.ok(public.avisos_tipo_emitible('fuga_por_reconocer') and public.avisos_tipo_emitible('fuga_revision_mensual')
  and public.avisos_tipo_emitible('deuda_en_vigilancia') and public.avisos_tipo_emitible('deuda_se_volvio_mala')
  and public.avisos_tipo_emitible('flujo_negativo') and not public.avisos_tipo_emitible('compra_papa_albacea'),
  '12: los cuatro tipos nuevos son emitibles por la app y los demás siguen igual');
select pruebas.igual((select count(*)::int from unnest(array['fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala']) t
  where public.avisos_texto_valido(public.fin_fugas_aviso_titulo(t))), 4, '12 (SQ-8): los cuatro títulos pasan la regla de D20');
select pruebas.igual(public.fin_fugas_aviso_titulo('base_80'), null, '12: la función del catálogo solo conoce los cuatro nuevos');
select pruebas.ok(not public.avisos_texto_valido('Cobro de 89 pesos') and not public.avisos_texto_valido('Cobro de $ mucho')
  and not public.avisos_texto_valido(repeat('a', 41)) and not public.avisos_texto_valido('') and not public.avisos_texto_valido(null)
  and public.avisos_texto_valido(repeat('a', 40)),
  '12 (SQ-8): un texto con dígitos, "$" o más de 40 caracteres no pasa; de 40 exactos sí');
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'avisos'
    and column_name ~ 'monto|nombre|texto|titulo|mensaje|cuerpo|centavos|comercio'),
  '12 (SQ-8): avisos sigue sin columnas de monto, nombre, comercio ni texto libre');
select pruebas.falla($$insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, programado_para, enviar_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas', 'tipo_inventado',
  'informativa', 'x', now(), now())$$, '12: el catálogo es cerrado (un tipo inventado no entra)', '23514');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'fuga_por_reconocer', 'patron',
  'f8600000-0000-4000-8000-000000000001', 'patron:f8600000-0000-4000-8000-000000000001:reconocer'), 1,
  '12: Alex emite "hay un cobro por reconocer" sobre un patrón de su libro (un destinatario: él)');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'fuga_por_reconocer', 'patron',
  'f8600000-0000-4000-8000-000000000001', 'patron:f8600000-0000-4000-8000-000000000001:reconocer'), 0, '12: repetirlo (misma clave) no avisa dos veces');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'fuga_por_reconocer', 'patron',
  'f8600000-0000-4000-8000-000000000011', 'patron:otro')$$, '12: un patrón de otro libro no vale', '22023');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'fuga_revision_mensual', 'libro',
  (select id from t_ids where clave = 'alex'), 'revision:2026-11'), 1, '12: la revisión mensual va al titular');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'deuda_en_vigilancia', 'deuda',
  'e8600000-0000-4000-8000-000000000002', 'deuda:e8600000-0000-4000-8000-000000000002:ambar'), 1, '12: deuda en vigilancia (clave con objeto y nivel)');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'deuda_se_volvio_mala', 'deuda',
  'e8600000-0000-4000-8000-000000000002', 'deuda:e8600000-0000-4000-8000-000000000002:rojo'), 1, '12: deuda que se volvió mala');
select pruebas.igual(public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'deuda_se_volvio_mala', 'deuda',
  'e8600000-0000-4000-8000-000000000002', 'deuda:e8600000-0000-4000-8000-000000000002:rojo'), 0, '12: un mismo cambio avisa una sola vez');
select pruebas.igual((select count(*)::int from public.avisos where persona_id = pruebas.id_persona('alex@ejemplo.test')
    and tipo in ('fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')), 4, '12: Alex tiene sus cuatro avisos');
select pruebas.como_postgres();
select pruebas.ok((select bool_and(a.modulo = 'finanzas' and a.libro_id = (select id from t_ids where clave = 'alex')
        and a.severidad = public.avisos_severidad(a.tipo))
      from public.avisos a where a.tipo in ('fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')),
  '12: del módulo finanzas, con su libro y su severidad del catálogo');
select pruebas.ok(not exists (select 1 from public.avisos a where a.tipo in ('fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')
    and row_to_json(a)::text ~* 'streaming|laptop|8900|89\.00|1050000'),
  '12 (SQ-8): ningún aviso trae comercio, objetivo ni monto');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where tipo = 'deuda_se_volvio_mala'$$), 1, '12: Alex lee el suyo');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where tipo in ('fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')$$), 0,
  '12: Ana no recibe los avisos del libro personal de Alex');
-- Compartido: los dos miembros; el actor de fuga_por_reconocer ya es miembro (no se duplica).
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'deuda_en_vigilancia', 'deuda',
  'e8600000-0000-4000-8000-000000000004', 'deuda:e8600000-0000-4000-8000-000000000004:ambar'), 2, '12: en un libro compartido avisa a sus dos miembros');
-- Papá: el albacea; el suplente solo si no hay albacea vigente.
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'deuda_se_volvio_mala', 'deuda',
  'e8600000-0000-4000-8000-000000000003', 'deuda:e8600000-0000-4000-8000-000000000003:rojo'), 1, '12: en el libro de Papá, solo el albacea');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos where clave = 'deuda:e8600000-0000-4000-8000-000000000003:rojo'
    and persona_id = pruebas.id_persona('alex@ejemplo.test')), 0, '12: el suplente no recibe mientras haya albacea');
update public.fin_libro_miembros set hasta = now() where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'deuda_se_volvio_mala', 'deuda',
  'e8600000-0000-4000-8000-000000000003', 'deuda:e8600000-0000-4000-8000-000000000003:rojo2'), 1, '12: sin albacea vigente, el suplente (y nadie más)');
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = null where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
-- quién no puede emitir
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'deuda_se_volvio_mala', 'deuda',
  'e8600000-0000-4000-8000-000000000003', 'x:1')$$, '12 (D24): la familiar con vista temporal no emite avisos de Papá', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'fuga_revision_mensual', 'libro', 'f1000000-0000-4000-8000-000000000001', 'x:2')$$,
  '12: la cuidadora tampoco', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'fuga_revision_mensual', 'libro', (select id from t_ids where clave = 'alex'), 'x:3')$$,
  '12: ni la maestra (solo lee)', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso((select id from t_ids where clave = 'alex'), 'compra_papa_albacea', null, null, 'x:4')$$,
  '12: un tipo que no es de la app sigue sin poder emitirse', '22023');
-- Se pueden silenciar los tipos nuevos (siguen en la bandeja); uno inventado no.
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['deuda_en_vigilancia', 'fuga_revision_mensual']);
select pruebas.igual((select tipos_silenciados from public.avisos_preferencias where persona_id = public.persona_actual()),
  array['deuda_en_vigilancia', 'fuga_revision_mensual'], '12: Alex silencia dos de los tipos nuevos');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['fuga_inventada'])$$,
  '12: un tipo desconocido se rechaza', '22023');
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['hab_bloque']);
select pruebas.igual((select tipos_silenciados from public.avisos_preferencias where persona_id = public.persona_actual()), array['hab_bloque'],
  '12: los tipos de Hábitos siguen siendo válidos (la lista se conservó)');

-- ---------------------------------------------------------------- 13: bitácora sin comercios, motivos ni textos
select pruebas.como_postgres();
select pruebas.ok(exists (select 1 from public.bitacora b where b.tabla = 'fin_fuga_clasificaciones')
  and exists (select 1 from public.bitacora b where b.tabla = 'fin_patrones_cobro')
  and exists (select 1 from public.bitacora b where b.tabla = 'fin_fuga_respuestas')
  and exists (select 1 from public.bitacora b where b.tabla = 'fin_deuda_propositos')
  and exists (select 1 from public.bitacora b where b.tabla = 'fin_deuda_semaforo')
  and exists (select 1 from public.bitacora b where b.tabla = 'fin_fuga_parametros'), '13: cada tabla nueva deja su rastro en la bitácora');
select pruebas.ok(not exists (select 1 from public.bitacora b where b.tabla in ('fin_patrones_cobro', 'fin_fuga_clasificaciones', 'fin_fuga_respuestas',
      'fin_deuda_propositos', 'fin_fuga_parametros') and b.detalle::text ~* 'streaming|gimnasio|lo uso para trabajar|laptop de trabajo|abc-123|ya no toma|gastos de salud|agua ejemplo|agua-1|lo pidió papá|farmacia'),
  '13: y no copia comercios, motivos, objetivos ni folios');

rollback;
