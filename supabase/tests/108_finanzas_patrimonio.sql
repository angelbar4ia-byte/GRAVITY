-- Finanzas · Fase 8, bloque 3: objetivos, inversión, bienes y previsión (docs/specs/fase-8-patrimonio.md v1.0).
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra). Se usa el libro personal de Alex.
-- Escenario (centavos): apartado "Viaje" con aporte fijo 20 000 y 30 000 ahorrados; objetivo de 100 000 al 20/dic.
--   Falta 70 000 -> 4 semanas con 20 000 por semana (hoy 8/nov/2026) -> 6/dic; necesario por semana: 70 000 / 6 = 11 667.
begin;

create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;
insert into t_ids values ('libro', pruebas.libro_personal('alex@ejemplo.test'));

-- ---------------------------------------------------------------- 0: preparación (el apartado de ahorro de Alex)
select pruebas.como('alex@ejemplo.test');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c4800000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Viaje (ejemplo)', 'ahorro'),
  ('c4800000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Casa fondo (ejemplo)', 'ahorro'),
  ('c4800000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Banco (ejemplo)', 'banco'),
  ('c4800000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Otro apartado (ejemplo)', 'ahorro');
insert into public.fin_bolsas_ahorro (id, hogar_id, libro_id, nombre, tipo, cuenta_id, aporte_fijo_centavos) values
  ('ea800000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Viaje', 'meta_libre', 'c4800000-0000-4000-8000-000000000001', 20000),
  ('ea800000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Casa fondo', 'meta_libre', 'c4800000-0000-4000-8000-000000000002', null),
  ('ea800000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Otro', 'meta_libre', 'c4800000-0000-4000-8000-000000000004', null);
select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('alex@ejemplo.test'), 'apertura'), 'c4800000-0000-4000-8000-000000000001', 30000);
select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('alex@ejemplo.test'), 'apertura'), 'c4800000-0000-4000-8000-000000000003', 200000);

-- ---------------------------------------------------------------- 1: avance del objetivo (criterio 1)
select pruebas.igual(public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Viaje', 100000, '2026-12-20', 'ea800000-0000-4000-8000-000000000001'),
  'a1080000-0000-4000-8000-0000000000a1'::uuid, '1: Alex guarda un objetivo ligado a su apartado');
select pruebas.igual((select ahorrado_centavos from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  30000::bigint, '1: lo ahorrado es el saldo del apartado (se lee)');
select pruebas.igual((select falta_centavos from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  70000::bigint, '1: falta = meta - ahorrado');
select pruebas.igual((select semanas_estimadas from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  4, '1: 70 000 con 20 000 por semana = 4 semanas (redondeo hacia arriba)');
select pruebas.igual((select fecha_estimada from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  '2026-12-06'::date, '1: fecha estimada = hoy + 4 semanas');
select pruebas.igual((select estado || '/' || ritmo_origen || '/' || a_tiempo::text
   from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  'ok/aporte_fijo/true', '1: estado ok, ritmo del aporte fijo, llega a tiempo');
select pruebas.igual((select aporte_necesario_semanal_centavos from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  11667::bigint, '1: aporte necesario por semana para llegar a la fecha meta (70 000 en 6 semanas)');
-- No se copia: un movimiento nuevo en el apartado mueve el avance sin tocar el objetivo.
select pruebas.registrar('transferencia', 'c4800000-0000-4000-8000-000000000003', 'c4800000-0000-4000-8000-000000000001', 50000, '2026-11-02');
select pruebas.igual((select ahorrado_centavos || '/' || falta_centavos || '/' || semanas_estimadas
   from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  '80000/20000/1', '1: el avance lee el apartado vivo (80 000 ahorrados, faltan 20 000, 1 semana)');
select pruebas.ok(not exists (select 1 from information_schema.columns
   where table_schema = 'public' and table_name = 'fin_objetivos' and column_name ~ 'ahorrado|saldo|aport'),
  '1: el objetivo no guarda copia del apartado');
select pruebas.igual((select a_tiempo::text from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-12-13')),
  'true', '1: a tiempo con la fecha estimada antes de la meta');
select pruebas.igual((select a_tiempo::text from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-12-14')),
  'false', '1: fuera de tiempo si la estimada pasa de la fecha meta (14/dic + 7 días = 21/dic)');
select pruebas.registrar('transferencia', 'c4800000-0000-4000-8000-000000000003', 'c4800000-0000-4000-8000-000000000001', 20000, '2026-11-03');
select pruebas.igual((select estado || '/' || falta_centavos || '/' || semanas_estimadas || '/' || aporte_necesario_semanal_centavos
   from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a1', '2026-11-08')),
  'cumplido/0/0/0', '1: con la meta alcanzada queda cumplido, sin falta');

-- Sin apartado y sin ritmo: no se inventa.
select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Sin apartado', 50000, '2027-01-31');
select pruebas.igual((select estado || '/' || falta_centavos || '/' || coalesce(semanas_estimadas::text, 'nulo')
   from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a2', '2026-11-08')),
  'sin_apartado/50000/nulo', '1: un objetivo sin apartado dice sin_apartado, sin semanas');
select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a3', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Casa', 60000, '2027-03-01', 'ea800000-0000-4000-8000-000000000002');
select pruebas.igual((select estado || '/' || coalesce(semanas_estimadas::text, 'nulo')
   from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a3', '2026-11-08')),
  'falta_dato/nulo', '1: un apartado sin aporte fijo ni aportaciones: falta_dato (no estima)');
-- Promedio de las aportaciones confirmadas (últimas 8) cuando no hay aporte fijo.
select pruebas.como_postgres();
insert into public.fin_semanas (id, hogar_id, libro_id, semana_inicio) values
  ('e6800000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'), '2026-10-26'),
  ('e6800000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'), '2026-11-02');
select pruebas.como('alex@ejemplo.test');
select pruebas.registrar('transferencia', 'c4800000-0000-4000-8000-000000000003', 'c4800000-0000-4000-8000-000000000002', 10000, '2026-10-27',
  p_id => 'd1080000-0000-4000-8000-0000000000a1');
select pruebas.registrar('transferencia', 'c4800000-0000-4000-8000-000000000003', 'c4800000-0000-4000-8000-000000000002', 20000, '2026-11-03',
  p_id => 'd1080000-0000-4000-8000-0000000000a2');
insert into public.fin_aportaciones_ahorro (hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos, aportado_centavos, estado, movimiento_id) values
  ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'), 'e6800000-0000-4000-8000-000000000001',
   'ea800000-0000-4000-8000-000000000002', 10000, 10000, 'confirmada', 'd1080000-0000-4000-8000-0000000000a1'),
  ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'), 'e6800000-0000-4000-8000-000000000002',
   'ea800000-0000-4000-8000-000000000002', 20000, 20000, 'confirmada', 'd1080000-0000-4000-8000-0000000000a2');
select pruebas.igual((select estado || '/' || ritmo_origen || '/' || aporte_semanal_centavos || '/' || falta_centavos || '/' || semanas_estimadas
   from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a3', '2026-11-08')),
  'ok/promedio/15000/30000/2', '1: sin aporte fijo, el ritmo es el promedio de las aportaciones confirmadas (15 000; faltan 30 000; 2 semanas)');
-- Un apartado alimenta a un solo objetivo activo.
select pruebas.falla($$select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a4', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Otro viaje', 1000, '2027-01-01', 'ea800000-0000-4000-8000-000000000001')$$,
  '1: dos objetivos activos no comparten apartado', '23505');
select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Viaje', 100000, '2026-12-20', 'ea800000-0000-4000-8000-000000000001', false);
select pruebas.ok(not (select activo from public.fin_objetivos where id = 'a1080000-0000-4000-8000-0000000000a1'),
  '1: la baja es activo en falso (y libera el apartado)');
select pruebas.falla($$select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a5', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Monto cero', 0, '2027-01-01')$$, '1: la meta es mayor que cero', '23514');
select pruebas.falla($$select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a5', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Apartado ajeno', 100, '2027-01-01', 'ea800000-0000-4000-8000-0000000009ff')$$,
  '1: el apartado debe existir en el mismo libro', '23503');
select pruebas.igual(pruebas.cuenta($$select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Sin apartado', 50000, '2027-01-31')$$), 1,
  '1: guardar de nuevo el mismo id no falla (idempotente)');
select pruebas.igual((select count(*)::int from public.fin_objetivos where id = 'a1080000-0000-4000-8000-0000000000a2'), 1,
  '1: y no duplica');

-- ---------------------------------------------------------------- 2: inversiones, origen capturado y verificado (criterios 2 y 3)
select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Cetes (ejemplo)', 7654321, 1234, 'capturado', '2026-11-05');
select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Fondo (ejemplo)', 500000, 875, 'verificado', '2026-11-06');
select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b3', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Sin origen dicho', 100, null);
select pruebas.igual((select origen from public.fin_inversiones where id = 'a1080000-0000-4000-8000-0000000000b1'), 'capturado',
  '2: la inversión a mano queda capturada');
select pruebas.igual((select origen from public.fin_inversiones where id = 'a1080000-0000-4000-8000-0000000000b2'), 'verificado',
  '2: la leída del PDF queda verificada');
select pruebas.igual((select origen from public.fin_inversiones where id = 'a1080000-0000-4000-8000-0000000000b3'), 'capturado',
  '2: sin decir origen, es capturada');
select pruebas.igual((select count(distinct origen)::int from public.fin_inversiones), 2, '2: los dos orígenes se distinguen');
select pruebas.igual((select rendimiento_pb from public.fin_inversiones where id = 'a1080000-0000-4000-8000-0000000000b1'), 1234,
  '3: el rendimiento queda tal como se capturó (puntos base, sin cálculo)');
select pruebas.ok((select rendimiento_pb is null from public.fin_inversiones where id = 'a1080000-0000-4000-8000-0000000000b3'),
  '3: sin rendimiento capturado queda en nulo (no se inventa)');
select pruebas.falla($$select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b4', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 1, 1, 'automatico', '2026-11-06')$$, '2: un origen fuera de catálogo se rechaza', '23514');
select pruebas.falla($$select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b4', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 1, 1, 'verificado', null)$$, '2: un dato verificado exige fecha de captura', '23514');
select pruebas.falla($$select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b4', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', -1, 1)$$, '2: el saldo no es negativo', '23514');
select pruebas.falla($$select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b4', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 1, 1, 'capturado', current_date + 30)$$, '2: la fecha de captura no es futura', '22023');
select pruebas.igual((select count(*)::int from public.fin_v_inversiones_vigentes), 2,
  '2: las vigentes son las que tienen fecha de captura');
select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000b1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Cetes (ejemplo)', 7654321, 1234, 'capturado', '2026-11-05', false);
select pruebas.igual((select count(*)::int from public.fin_v_inversiones_vigentes), 1, '2: la baja (activa en falso) sale de las vigentes');

-- ---------------------------------------------------------------- 3: bienes y previsiones sin fecha no son vigentes (criterio 4)
select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Auto (ejemplo)', 'auto', 98765432, '2026-11-01');
select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Casa (ejemplo)', 'casa', 150000000);
select public.fin_prevision_guardar('a1080000-0000-4000-8000-0000000000d1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Seguro de vida (ejemplo)', 'seguro', 40000000, '2026-10-15');
select public.fin_prevision_guardar('a1080000-0000-4000-8000-0000000000d2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Pensión (ejemplo)', 'pension', 20000000);
select pruebas.igual((select count(*)::int from public.fin_bienes), 2, '3: los dos bienes quedan guardados');
select pruebas.igual((select string_agg(nombre, ',') from public.fin_v_bienes_vigentes), 'Auto (ejemplo)',
  '3: el bien sin fecha de captura no es vigente');
select pruebas.igual((select string_agg(nombre, ',') from public.fin_v_previsiones_vigentes), 'Seguro de vida (ejemplo)',
  '3: la previsión sin fecha de captura no es vigente');
select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Casa (ejemplo)', 'casa', 150000000, '2026-11-07');
select pruebas.igual((select count(*)::int from public.fin_v_bienes_vigentes), 2, '3: al capturar la fecha, el bien pasa a vigente');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c3', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 'yate', 1, '2026-11-01')$$, '3: el tipo de bien es auto, casa u otro', '23514');
select pruebas.falla($$select public.fin_prevision_guardar('a1080000-0000-4000-8000-0000000000d3', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 'ahorro', 1, '2026-11-01')$$, '3: el tipo de previsión es seguro, pensión u otro', '23514');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c3', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('ana@ejemplo.test'), 'X', 'otro', 1, '2026-11-01')$$, '3: la titular debe llevar el libro', '22023');
select pruebas.falla($$delete from public.fin_bienes$$, '3: nada se borra (sin permiso de escritura directa)', '42501');
select pruebas.falla($$insert into public.fin_bienes (hogar_id, libro_id, titular_id, nombre, tipo, valor_centavos)
  values ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'), pruebas.id_persona('alex@ejemplo.test'), 'X', 'otro', 1)$$,
  '3: sin escritura directa', '42501');
select pruebas.falla($$update public.fin_objetivos set monto_meta_centavos = 1$$, '3: ni actualizar directo', '42501');

-- ---------------------------------------------------------------- 4: reglas por cuenta
-- Ana (pareja, albacea de Papá): no escribe ni lee el libro personal de Alex; sí la casa y Papá.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_objetivos'), 0, '4: Ana no ve los objetivos personales de Alex');
select pruebas.igual(pruebas.cuenta('select * from public.fin_inversiones'), 0, '4: ni sus inversiones');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes'), 0, '4: ni sus bienes');
select pruebas.igual(pruebas.cuenta('select * from public.fin_previsiones'), 0, '4: ni sus previsiones');
select pruebas.falla($$select * from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a2')$$,
  '4: ni el avance de un objetivo de Alex', '42501');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c9', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 'otro', 1, '2026-11-01')$$, '4: ni escribe en su libro', '42501');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Auto robado', 'auto', 1, '2026-11-01')$$, '4: ni pisa un id de Alex', '42501');
-- Papá: Ana como albacea.
select pruebas.igual(public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000e1', 'f1000000-0000-4000-8000-000000000002',
  (select titular_id from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'), 'Casa de Papá (ejemplo)', 'casa', 80000000, '2026-11-01'),
  'a1080000-0000-4000-8000-0000000000e1'::uuid, '4: Ana, como albacea, guarda un bien de Papá');
select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000e2', 'f1000000-0000-4000-8000-000000000002',
  (select titular_id from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'), 'Ahorro de Papá (ejemplo)', 300000, 500, 'capturado', '2026-11-01');
select public.fin_prevision_guardar('a1080000-0000-4000-8000-0000000000e3', 'f1000000-0000-4000-8000-000000000002',
  (select titular_id from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'), 'Pensión de Papá (ejemplo)', 'pension', 5000000, '2026-11-01');
select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000e4', 'f1000000-0000-4000-8000-000000000002',
  (select titular_id from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'), 'Fondo de Papá', 100000, '2027-06-01');
select pruebas.igual((select estado from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000e4')), 'sin_apartado',
  '4: y lee el avance de su objetivo');
-- Casa compartida: la pareja ve y escribe.
select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000f1', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('ana@ejemplo.test'), 'Refrigerador de la casa (ejemplo)', 'otro', 1500000, '2026-11-01');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes'), 2, '4: Ana ve el bien de Papá y el de la casa (no los de Alex)');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bienes where libro_id = 'f1000000-0000-4000-8000-000000000001'$$), 1,
  '4: la pareja ve los bienes de la casa');
select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000f2', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('alex@ejemplo.test'), 'Sillón de la casa (ejemplo)', 'otro', 800000, '2026-11-01');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bienes where libro_id = 'f1000000-0000-4000-8000-000000000001'$$), 2,
  '4: y la pareja también escribe en la casa');
-- Papá: el suplente lee igual que en la Fase 1 (fin_puede leer), pero con albacea vigente no escribe.
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'), '4: premisa: Alex lee el libro de Papá (fin_puede)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bienes where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  '4: el suplente lee los bienes de Papá como lee su libro');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_inversiones where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  '4: sus inversiones');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_previsiones where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  '4: sus previsiones');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_objetivos where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  '4: y sus objetivos');
select pruebas.igual((select estado from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000e4')), 'sin_apartado',
  '4: y el avance');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000e9', 'f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('ana@ejemplo.test'), 'X', 'otro', 1, '2026-11-01')$$, '4: con albacea vigente, el suplente no escribe lo de Papá', '42501');

-- Carla (familiar), Diana (cuidadora), Casa y anon: nada
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_objetivos'), 0, '4: la familiar no ve objetivos');
select pruebas.igual(pruebas.cuenta('select * from public.fin_inversiones'), 0, '4: ni inversiones');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes'), 0, '4: ni bienes');
select pruebas.igual(pruebas.cuenta('select * from public.fin_previsiones'), 0, '4: ni previsiones');
select pruebas.igual(pruebas.cuenta('select * from public.fin_v_bienes_vigentes'), 0, '4: ni las vistas de vigentes');
select pruebas.falla($$select * from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000e4')$$, '4: ni el avance', '42501');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000e8', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('carla@ejemplo.test'), 'X', 'otro', 1, '2026-11-01')$$, '4: no escribe', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_objetivos'), 0, '4: la cuidadora no ve objetivos');
select pruebas.igual(pruebas.cuenta('select * from public.fin_inversiones'), 0, '4: ni inversiones');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes'), 0, '4: ni bienes');
select pruebas.igual(pruebas.cuenta('select * from public.fin_previsiones'), 0, '4: ni previsiones');
select pruebas.falla($$select public.fin_inversion_guardar('a1080000-0000-4000-8000-0000000000e7', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('diana@ejemplo.test'), 'X', 1, 1)$$, '4: no escribe', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_objetivos'), 0, '4: Casa no ve objetivos');
select pruebas.igual(pruebas.cuenta('select * from public.fin_inversiones'), 0, '4: ni inversiones');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes'), 0, '4: ni bienes');
select pruebas.igual(pruebas.cuenta('select * from public.fin_previsiones'), 0, '4: ni previsiones');
select pruebas.falla($$select * from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000e4')$$, '4: ni el avance', '42501');
select pruebas.falla($$select public.fin_prevision_guardar('a1080000-0000-4000-8000-0000000000e6', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('ana@ejemplo.test'), 'X', 'otro', 1, '2026-11-01')$$, '4: ni escribe', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_bienes$$, '4: anon no lee bienes', '42501');
select pruebas.falla($$select * from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000e4')$$, '4: ni el avance', '42501');

-- La cuenta maestra solo lee con consulta vigente
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes'), 0, '4: sin consulta, la maestra no ve bienes');
select pruebas.igual(pruebas.cuenta('select * from public.fin_inversiones'), 0, '4: ni inversiones');
select pruebas.falla($$select * from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a2')$$, '4: ni el avance sin consulta', '42501');
select public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'libro'));
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bienes where libro_id = (select id from t_ids where clave = 'libro')$$), 2,
  '4: con consulta vigente lee los bienes de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_inversiones where libro_id = (select id from t_ids where clave = 'libro')$$), 3,
  '4: sus inversiones');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_objetivos where libro_id = (select id from t_ids where clave = 'libro')$$), 3,
  '4: sus objetivos');
select pruebas.igual((select estado from public.fin_objetivo_avance('a1080000-0000-4000-8000-0000000000a2')), 'sin_apartado',
  '4: y el avance');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bienes where libro_id = ''f1000000-0000-4000-8000-000000000002'''), 0,
  '4: la consulta es por libro: lo de Papá sigue sin verse');
select pruebas.falla($$select public.fin_bien_guardar('a1080000-0000-4000-8000-0000000000c1', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 'auto', 1, '2026-11-01')$$, '4: la maestra nunca escribe', '42501');
select pruebas.falla($$select public.fin_objetivo_guardar('a1080000-0000-4000-8000-0000000000a2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'X', 1, '2027-01-01')$$, '4: ni objetivos', '42501');

-- ---------------------------------------------------------------- 5: bitácora sin cifras (D3)
select pruebas.como_postgres();
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_objetivos') >= 3, '5: los objetivos dejan entrada en la bitácora');
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_inversiones') >= 3, '5: y las inversiones');
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_bienes') >= 3, '5: y los bienes');
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_previsiones') >= 3, '5: y las previsiones');
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_inversiones' and accion = 'actualizar') >= 1,
  '5: dar de baja una inversión deja entrada');
select pruebas.igual((select count(*)::int from public.bitacora
   where tabla in ('fin_objetivos', 'fin_inversiones', 'fin_bienes', 'fin_previsiones')
     and detalle::text ~ '(monto_meta_centavos|saldo_centavos|rendimiento_pb|valor_centavos)'), 0,
  '5: ninguna entrada lleva monto, saldo, rendimiento ni valor');
select pruebas.igual((select count(*)::int from public.bitacora
   where tabla in ('fin_objetivos', 'fin_inversiones', 'fin_bienes', 'fin_previsiones')
     and detalle::text ~ ': (100000|7654321|1234|875|98765432|150000000|40000000|20000000)[,}]'), 0,
  '5: ni los valores capturados');
select pruebas.igual((select count(*)::int from public.bitacora where accion like '%avance%'), 0, '5: leer un avance no deja entradas');

rollback;
