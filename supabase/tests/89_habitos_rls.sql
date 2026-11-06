-- Hábitos (Fase 3, D21): todo es de UNA persona. Ni el dueño, ni la pareja, ni la cuenta maestra, ni otro hogar,
-- ni cuidador ni Hogar leen lo ajeno. Sin bitácora; el prefijo habitos* es del servidor.
begin;

select pruebas.nuevo_adulto('teo@ejemplo.test');

-- ---------------------------------------------------------------- cada quien lo suyo
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 2, 'Ana ve sus 2 objetivos');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_registros$$) + pruebas.cuenta($$select * from public.hab_bloques$$)
  + pruebas.cuenta($$select * from public.hab_planes_lectura$$) + pruebas.cuenta($$select * from public.hab_plan_dias$$)
  + pruebas.cuenta($$select * from public.hab_marcas_biblia$$) + pruebas.cuenta($$select * from public.hab_revisiones$$), 8,
  '… y sus registros, bloque, plan (2 días), marca y revisión');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ajustes$$), 1, 'Una fila de ajustes (la suya)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_modos$$), 2, 'Dos modos, ambos suyos');
select pruebas.igual((select string_agg(tipo || '=' || modo, ',' order by tipo) from public.hab_modos),
  'diario_oracion=nube_cifrada,habitos_sensibles=solo_telefono', 'Por omisión solo teléfono (Ana activó la nube del diario en el seed)');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 1, 'La pareja ve solo su objetivo');
select pruebas.igual((select titulo from public.hab_objetivos), 'Estudiar inglés 15 minutos (ejemplo)', '… que es suyo');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_registros$$) + pruebas.cuenta($$select * from public.hab_planes_lectura$$)
  + pruebas.cuenta($$select * from public.hab_revisiones$$) + pruebas.cuenta($$select * from public.hab_marcas_biblia$$), 0,
  'No ve nada de lo de la dueña');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 1, 'La familiar ve solo el suyo');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$), 0,
  'La dueña del hogar NO ve lo de la pareja ni lo de la familiar');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ajustes where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$), 0,
  '… ni sus ajustes');

-- ---------------------------------------------------------------- los demás roles: nada
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$) + pruebas.cuenta($$select * from public.hab_ajustes$$)
  + pruebas.cuenta($$select * from public.hab_modos$$) + pruebas.cuenta($$select * from public.hab_registros$$), 0,
  'La cuenta maestra no tiene Hábitos: no lee nada');
select pruebas.falla($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  values ('X', 'salud', 'construir', '2026-11-01', now())$$, 'ni escribe', '42501');
select pruebas.igual((select count(*)::int from public.avisos_preferencias), 0, 'ni tiene preferencias');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$) + pruebas.cuenta($$select * from public.hab_ajustes$$), 0, 'La cuidadora no lee nada');
select pruebas.falla($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  values ('X', 'salud', 'construir', '2026-11-01', now())$$, 'ni escribe', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$) + pruebas.cuenta($$select * from public.hab_ajustes$$), 0, 'La cuenta Hogar (tablet pública) no lee nada');
select pruebas.falla($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  values ('X', 'salud', 'construir', '2026-11-01', now())$$, 'ni escribe', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 0, 'Otro hogar no ve lo de este');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ajustes$$), 1, '… solo sus propios ajustes');
select pruebas.como_anon();
select pruebas.falla($$select * from public.hab_objetivos$$, 'Sin sesión no se lee nada', '42501');

-- ---------------------------------------------------------------- escribir lo propio
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$insert into public.hab_objetivos (id, persona_id, titulo, area, tipo, fecha_inicio, modificado_en)
  values (gen_random_uuid(), pruebas.id_persona('ana@ejemplo.test'), 'X', 'salud', 'construir', '2026-11-01', now())$$,
  'La app no manda persona_id (sin permiso de columna)', '42501');
select pruebas.falla($$insert into public.hab_objetivos (id, hogar_id, titulo, area, tipo, fecha_inicio, modificado_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000002', 'X', 'salud', 'construir', '2026-11-01', now())$$,
  'ni hogar_id', '42501');
select pruebas.falla($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en, actualizado_en)
  values (gen_random_uuid(), 'X', 'salud', 'construir', '2026-11-01', now(), now())$$, 'ni actualizado_en', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en)
  values ('f5000000-0000-4000-8000-0000000000a1', 'Caminar (ejemplo)', 'salud', 'construir', '2026-11-01', now())$$), 1, 'Alex inserta lo suyo…');
select pruebas.igual((select persona_id || '/' || hogar_id from public.hab_objetivos where id = 'f5000000-0000-4000-8000-0000000000a1'),
  pruebas.id_persona('alex@ejemplo.test') || '/b0000000-0000-4000-8000-000000000001',
  '… el servidor lo deja a su nombre y en su hogar');
select pruebas.falla($$update public.hab_objetivos set persona_id = pruebas.id_persona('ana@ejemplo.test') where id = 'f5000000-0000-4000-8000-0000000000a1'$$,
  'La persona de un registro no cambia', '42501');
select pruebas.falla($$insert into public.hab_registros (id, objetivo_id, fecha, modificado_en)
  values (gen_random_uuid(), 'f5000000-0000-4000-8000-000000000001', '2026-11-01', now())$$,
  'Un registro no apunta al objetivo de otra persona', '23503');
select pruebas.falla($$insert into public.hab_registros (id, fecha, modificado_en) values (gen_random_uuid(), '2026-11-01', now())$$,
  'Un registro lleva un objetivo o un bloque', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_registros (id, objetivo_id, fecha, estado, modificado_en)
  values ('f5200000-0000-4000-8000-0000000000a1', 'f5000000-0000-4000-8000-0000000000a1', '2026-11-01', 'hecho', now())$$), 1, 'Registra un día');
select pruebas.falla($$insert into public.hab_registros (id, objetivo_id, fecha, modificado_en)
  values (gen_random_uuid(), 'f5000000-0000-4000-8000-0000000000a1', '2026-11-01', now())$$, 'Un registro por elemento y día', '23505');
-- Último gana
select pruebas.igual(pruebas.afecta($$update public.hab_registros set estado = 'pendiente', modificado_en = now() - interval '1 hour'
  where id = 'f5200000-0000-4000-8000-0000000000a1'$$), 0, 'Un cambio más viejo se ignora, sin error');
select pruebas.igual((select estado from public.hab_registros where id = 'f5200000-0000-4000-8000-0000000000a1'), 'hecho', '… y queda el más reciente');
select pruebas.igual(pruebas.afecta($$update public.hab_registros set estado = 'omitido', motivo_omision = 'cansancio', modificado_en = now() + interval '1 minute'
  where id = 'f5200000-0000-4000-8000-0000000000a1'$$), 1, 'Uno más nuevo gana');
select pruebas.igual(pruebas.afecta($$update public.hab_registros set estado = 'hecho', modificado_en = now() + interval '2 days'
  where id = 'f5200000-0000-4000-8000-0000000000a1'$$), 1, 'Uno del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_registros where id = 'f5200000-0000-4000-8000-0000000000a1'),
  '… ajustado a la hora del servidor (tope de 5 minutos)');
select pruebas.falla($$update public.hab_ajustes set epoca_nube = 5$$, 'epoca_nube es del servidor', '42501');
select pruebas.igual(pruebas.afecta($$update public.hab_ajustes set gracia_semanal = 2, modificado_en = now()$$), 1, 'Los ajustes sí se cambian');
select pruebas.falla($$insert into public.hab_ajustes (persona_id, hogar_id) values (pruebas.id_persona('alex@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001')$$,
  'Los ajustes los crea el servidor', '42501');
select pruebas.falla($$update public.hab_modos set modo = 'nube_cifrada'$$, 'El modo solo cambia con hab_cambiar_modo', '42501');
select pruebas.igual(pruebas.afecta($$delete from public.hab_objetivos where id = 'f5000000-0000-4000-8000-0000000000a1'$$), 1, 'Borra lo suyo');
select pruebas.igual(pruebas.afecta($$delete from public.hab_objetivos$$), 1, 'Un DELETE sin filtro solo alcanza lo suyo (1 fila: su objetivo del seed)');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 2, 'Lo de Ana sigue intacto');
select pruebas.igual((select count(*)::int from public.hab_registros where id = 'f5200000-0000-4000-8000-0000000000a1'), 0, 'El registro se fue en cascada con su objetivo');

-- ---------------------------------------------------------------- plan de lectura
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.hab_crear_plan_lectura(
  '{"id": "f5300000-0000-4000-8000-0000000000c1", "tipo": "nt_90", "nombre": "NT en 90 días", "fecha_inicio": "2026-11-02", "version_biblica": "kjv"}'::jsonb,
  '[{"dia": 1, "fecha": "2026-11-02", "segmentos": []}, {"dia": 2, "fecha": "2026-11-03", "segmentos": []}]'::jsonb) is not null, 'Carla crea un plan');
select pruebas.ok(public.hab_crear_plan_lectura(
  '{"id": "f5300000-0000-4000-8000-0000000000c1", "tipo": "nt_90", "nombre": "NT en 90 días", "fecha_inicio": "2026-11-02", "version_biblica": "kjv"}'::jsonb,
  '[{"dia": 1, "fecha": "2026-11-02", "segmentos": []}]'::jsonb) is not null, 'Repetirlo es idempotente');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_plan_dias where plan_id = 'f5300000-0000-4000-8000-0000000000c1'$$), 2, 'con sus 2 días, sin duplicar');
select pruebas.falla($$select public.hab_crear_plan_lectura('{"id": "f5300000-0000-4000-8000-0000000000c2"}'::jsonb,
  (select jsonb_agg(jsonb_build_object('dia', g)) from generate_series(1, 401) g))$$, 'Más de 400 días se rechaza', '22023');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.hab_crear_plan_lectura('{"id": "f5300000-0000-4000-8000-0000000000c3"}'::jsonb, '[]'::jsonb)$$,
  'La maestra no crea planes', '42501');

-- ---------------------------------------------------------------- quién tiene Hábitos
select pruebas.como_postgres();
select pruebas.igual(
  (select string_agg(u.email, ',' order by u.email) from public.hab_ajustes a
     join public.personas p on p.id = a.persona_id join auth.users u on u.id = p.usuario_id where a.hogar_id = 'b0000000-0000-4000-8000-000000000001'),
  'alex@ejemplo.test,ana@ejemplo.test,carla@ejemplo.test,teo@ejemplo.test',
  'Tienen Hábitos dueña, pareja, familiar y el nuevo coadministrador; no la maestra, la cuidadora ni Hogar');
select pruebas.igual((select count(*)::int from public.hab_modos where persona_id = pruebas.id_persona('teo@ejemplo.test') and modo = 'solo_telefono'), 2,
  'Cada uno nace con los dos modos en solo teléfono');
select pruebas.ok(not public.hab_miembro_activo('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test')),
  'La cuenta maestra que no es la dueña queda fuera');
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.como_postgres();
select pruebas.ok(public.hab_miembro_activo('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test')),
  'La dueña que además es maestra conserva su Hábitos');
update public.membresias set rol = 'cuidador' where persona_id = pruebas.id_persona('teo@ejemplo.test');
select pruebas.como('teo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ajustes$$), 0, 'Quien pasa a cuidador ya no lee nada');

-- ---------------------------------------------------------------- bitácora
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where tabla like 'hab\_%'), 0, 'Las tablas hab_* no escriben en la bitácora');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion) values ('b0000000-0000-4000-8000-000000000001', 'habitos.borrar_datos')$$,
  'El prefijo habitos* es del servidor', '42501');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', 'hab_objetivos')$$,
  'ni las tablas hab_*', '42501');
select pruebas.como_postgres();
insert into public.bitacora (hogar_id, persona_id, accion) values
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'habitos.borrar_datos');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion like 'habitos.%'$$), 1, 'Quien la hizo ve su entrada');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion like 'habitos.%' and persona_id <> pruebas.id_persona('ana@ejemplo.test')$$), 0,
  'El dueño no ve las entradas habitos.* de otros');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion like 'habitos.%'$$), 0, 'ni la cuenta maestra');

-- ---------------------------------------------------------------- baja: se conserva sin acceso y se borra a los 90 días
select pruebas.como_postgres();
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 0, 'Una persona dada de baja pierde el acceso al instante');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('carla@ejemplo.test')), 1, '… pero sus datos se conservan');
select pruebas.igual(public.hab_limpiar(now() + interval '89 days'), 0, 'A los 89 días no se borra nada');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('carla@ejemplo.test')), 1, '… sigue ahí');
select pruebas.igual(public.hab_limpiar(now() + interval '91 days'), 1, 'A los 91 días se limpia a esa persona');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('carla@ejemplo.test'))
  + (select count(*)::int from public.hab_ajustes where persona_id = pruebas.id_persona('carla@ejemplo.test'))
  + (select count(*)::int from public.hab_modos where persona_id = pruebas.id_persona('carla@ejemplo.test'))
  + (select count(*)::int from public.hab_planes_lectura where persona_id = pruebas.id_persona('carla@ejemplo.test')), 0,
  '… objetivos, plan, ajustes y modos');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 2,
  'Lo de quien sigue en el hogar no se toca');
select pruebas.igual(public.hab_limpiar(now() + interval '200 days'), 0, 'Limpiar dos veces no hace nada de más');

-- La dueña dada de baja de otro hogar... y volver al hogar antes de los 90 días conserva todo (membresía vigente).
rollback;
