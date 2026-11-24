-- Bicicleta (Fase 8, B2, CA-B-19, PB-03): el tipo local ubicacion_local (rutas, enlaces de ruta y contacto de
-- emergencia) NO llega al servidor. hab_sobres.tipo sigue admitiendo solo los dos tipos de la nube; el servidor
-- rechaza un sobre ubicacion_local (y también salud_local, del gimnasio).
begin;

select pruebas.como_postgres();
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'ubicacion_local', 1, 'QUJDREVGR0g', 1)$$,
  'Un sobre de tipo ubicacion_local es rechazado por la restricción de hab_sobres.tipo (CA-B-19)', '23514');
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'salud_local', 1, 'QUJDREVGR0g', 1)$$,
  '… y también salud_local (del gimnasio)', '23514');
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'rutas', 1, 'QUJDREVGR0g', 1)$$,
  '… y uno llamado rutas', '23514');
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'contacto_emergencia', 1, 'QUJDREVGR0g', 1)$$,
  '… o uno llamado contacto_emergencia', '23514');
select pruebas.falla($$insert into public.hab_modos (persona_id, hogar_id, tipo) values
  (pruebas.id_persona('ana@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001', 'ubicacion_local')$$,
  'No hay fila de modo para ubicacion_local: no tiene modo ni botón para pasarlo a la nube', '23514');
select pruebas.ok(
  (select pg_get_constraintdef(k.oid) from pg_constraint k where k.conrelid = 'public.hab_sobres'::regclass and k.contype = 'c'
     and pg_get_constraintdef(k.oid) like '%tipo%') !~ '(ubicacion_local|salud_local)',
  'La restricción de hab_sobres.tipo no incluye ubicacion_local ni salud_local');
select pruebas.ok(
  (select pg_get_constraintdef(k.oid) from pg_constraint k where k.conrelid = 'public.hab_modos'::regclass and k.contype = 'c'
     and pg_get_constraintdef(k.oid) like '%tipo%') !~ '(ubicacion_local|salud_local)',
  'La de hab_modos.tipo tampoco');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'ubicacion_local',
  'revision', 1, 'llave_version', 1, 'cifrado', 'QUJDREVGR0g')))$$, 'hab_subir_sobres no recibe un sobre ubicacion_local aunque la nube esté activa', '22023');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'salud_local',
  'revision', 1, 'llave_version', 1, 'cifrado', 'QUJDREVGR0g')))$$, '… ni uno salud_local', '22023');
select pruebas.falla($$select public.hab_cambiar_modo('ubicacion_local', 'nube_cifrada')$$, 'hab_cambiar_modo no conoce ubicacion_local', '22023');
select pruebas.falla($$select public.hab_reiniciar_nube('ubicacion_local')$$, 'ni hab_reiniciar_nube', '22023');
select pruebas.falla($$select public.hab_borrar_mis_datos('ubicacion_local')$$, 'ni hab_borrar_mis_datos: el servidor no tiene nada que borrar ahí', '22023');
select pruebas.falla($$select public.hab_borrar_mis_datos('rutas')$$, '… ni un alcance rutas', '22023');
select pruebas.falla($$select public.hab_borrar_mis_datos('contacto')$$, '… ni un alcance contacto', '22023');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres where tipo not in ('habitos_sensibles', 'diario_oracion')$$), 0,
  'No hay ningún sobre de otro tipo');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'ubicacion_local', 1, 'QUJDREVGR0g', 1)$$,
  'La app tampoco escribe sobres directo (42501)', '42501');

rollback;
