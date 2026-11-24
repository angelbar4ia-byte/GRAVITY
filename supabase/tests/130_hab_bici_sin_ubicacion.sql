-- Bicicleta (Fase 8, B2, CA-B-18, PB-03 y PB-04): NO hay ubicación en el servidor. Ninguna tabla hab_bici_* ni
-- hab_musica_listas tiene columna de latitud, longitud, trazo, ruta, domicilio, contacto o teléfono; la salida no
-- tiene llave a ninguna ruta. Rutas, contacto y trazos viven solo en el almacén local del dispositivo.
begin;

-- La consulta que vigila el esquema, como función, para poder probarla también con un caso malo.
create function pruebas.columnas_de_ubicacion() returns text
language sql stable
as $$
  select coalesce(string_agg(c.table_name || '.' || c.column_name, ', ' order by c.table_name, c.column_name), '')
    from information_schema.columns c
   where c.table_schema = 'public' and (c.table_name like 'hab\_bici\_%' or c.table_name = 'hab_musica_listas')
     and c.column_name ~* ('(^|_)(lat|lon|lng|alt|geo|gps|ruta|rutas|route|mapa|punto|puntos)(_|$)|latitud|longitud|coordenad|traza|trazo|waypoint'
                           || '|ubicac|domicil|direccion|calle|colonia|contact|telefon|celular|whatsapp|sms|emergen|enlace_ruta|enlace_mapa')
$$;

-- ---------------------------------------------------------------- ninguna columna ni tabla de ubicación
select pruebas.como_postgres();
select pruebas.igual(pruebas.columnas_de_ubicacion(), '',
  'Ninguna columna de hab_bici_* ni de hab_musica_listas habla de latitud, longitud, trazo, ruta, domicilio, contacto ni teléfono');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v', 'm', 'f')
      and (c.relname ~* '(ubicac|ruta|route|traza|trazo|coordenad|domicil|waypoint|gps)'
           or (c.relname like 'hab\_%' and c.relname ~* '(contacto|telefon|geo)'))),
  '', 'Ninguna tabla ni vista de public guarda ubicación, rutas, trazos ni domicilio (con ningún prefijo), ni contactos en Hábitos');
select pruebas.igual(
  (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'hab\_%' and p.proname ~* '(ubicac|ruta|route|traza|trazo|coordenad|domicil|contacto|telefon|waypoint|geo|gps)'),
  '', 'Ninguna función de Hábitos las recibe');
-- Las columnas exactas de cada tabla: cualquier columna nueva rompe esta prueba y obliga a revisarla.
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_bici_perfil'),
  'actualizado_en,aviso_visto_en,bicicleta_activa_id,carga_piernas,duracion_prevista_min,hogar_id,intervalo_agua_min,intervalo_comida_min,margen_revision_min,modificado_en,persona_id,preparacion,tope_aumento_pct'
  , 'hab_bici_perfil: solo las columnas de la especificación 5.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_bici_bicicletas'),
  'activa,actualizado_en,hogar_id,id,intervalos,modificado_en,nombre,odometro_inicial_m,persona_id,tipo', 'hab_bici_bicicletas: solo las de 5.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_bici_mantenimientos'),
  'actualizado_en,bicicleta_id,fecha,hogar_id,id,modificado_en,nota,odometro_m,persona_id,tarea', 'hab_bici_mantenimientos: solo las de 5.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_bici_salidas'),
  'acompanado,actualizado_en,bicicleta_id,bloque_id,clima,desnivel_m,distancia_m,duracion_min,esfuerzo,estado,fecha,hogar_id,id,inicio,modificado_en,motivo,n,persona_id,superficie',
  'hab_bici_salidas: solo las de 5.2 (sin ruta, sin lugar)');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_musica_listas'),
  'actividad,actualizado_en,app,enlace,hogar_id,id,modificado_en,nombre,orden,persona_id', 'hab_musica_listas: solo las de 5.2');
select pruebas.igual((select count(*)::int from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_bici\_%'), 4,
  'Son cuatro tablas hab_bici_* (una nueva obliga a revisar esta prueba)');
select pruebas.igual((select count(*)::int from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_musica\_%'), 1,
  '… y una sola hab_musica_* (la compartida con el gimnasio)');

-- ---------------------------------------------------------------- la salida no enlaza con ninguna ruta
select pruebas.igual(
  (select string_agg(distinct f.confrelid::regclass::text, ',' order by f.confrelid::regclass::text) from pg_constraint f
    where f.contype = 'f' and f.conrelid = 'public.hab_bici_salidas'::regclass),
  'hab_bici_bicicletas,hab_bloques,hogares,personas', 'hab_bici_salidas solo apunta a bicicletas, bloques de Hábitos, hogares y personas: ninguna ruta');
select pruebas.igual(
  (select coalesce(string_agg(f.conrelid::regclass::text || '->' || f.confrelid::regclass::text, ', ' order by f.conrelid::regclass::text, f.confrelid::regclass::text), '')
     from pg_constraint f
    where f.contype = 'f' and f.conrelid in ('public.hab_bici_perfil'::regclass, 'public.hab_bici_bicicletas'::regclass, 'public.hab_bici_mantenimientos'::regclass,
                                             'public.hab_bici_salidas'::regclass, 'public.hab_musica_listas'::regclass)
      and f.confrelid::regclass::text not in ('hab_bici_bicicletas', 'hab_bloques', 'hogares', 'personas')),
  '', 'Ninguna de las cinco tablas apunta a nada fuera de bicicletas, bloques, hogares y personas');

-- ---------------------------------------------------------------- caso malo: una columna de ubicación rompe la vigilancia
-- (todo esto se deshace con el rollback)
alter table public.hab_bici_salidas add column ruta text;
select pruebas.igual(pruebas.columnas_de_ubicacion(), 'hab_bici_salidas.ruta', 'Agregar una columna ruta es detectado por la vigilancia del esquema');
alter table public.hab_bici_salidas drop column ruta;
alter table public.hab_bici_bicicletas add column latitud integer;
alter table public.hab_bici_mantenimientos add column telefono_taller text;
alter table public.hab_musica_listas add column enlace_ruta text;
select pruebas.igual(pruebas.columnas_de_ubicacion(), 'hab_bici_bicicletas.latitud, hab_bici_mantenimientos.telefono_taller, hab_musica_listas.enlace_ruta',
  '… también latitud, un teléfono y un enlace de ruta');
alter table public.hab_bici_bicicletas drop column latitud;
alter table public.hab_bici_mantenimientos drop column telefono_taller;
alter table public.hab_musica_listas drop column enlace_ruta;
select pruebas.igual(pruebas.columnas_de_ubicacion(), '', 'Sin ellas, vuelve a estar limpio');

-- ---------------------------------------------------------------- la app no puede mandar lo que no existe
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, estado, ruta_id, modificado_en)
  values (gen_random_uuid(), '2026-11-21', 'hecha', gen_random_uuid(), now())$$, 'Insertar una salida con ruta_id falla: la columna no existe', '42703');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, estado, latitud, longitud, modificado_en)
  values (gen_random_uuid(), '2026-11-21', 'hecha', 19.4, -99.1, now())$$, 'ni coordenadas', '42703');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, estado, traza, modificado_en)
  values (gen_random_uuid(), '2026-11-21', 'hecha', '[]', now())$$, 'ni un trazo', '42703');
select pruebas.falla($$insert into public.hab_bici_perfil (contacto_emergencia, modificado_en) values ('Mamá (ejemplo)', now())$$, 'ni un contacto de emergencia en el perfil', '42703');
select pruebas.falla($$insert into public.hab_bici_perfil (telefono, modificado_en) values ('5555555555', now())$$, 'ni un teléfono', '42703');
select pruebas.falla($$insert into public.hab_bici_perfil (domicilio, modificado_en) values ('Calle Ejemplo 1', now())$$, 'ni un domicilio', '42703');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, taller, modificado_en) values (gen_random_uuid(), 'X', 'Taller (ejemplo)', now())$$,
  'ni un taller (lugar) en la bicicleta', '42703');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, lugar, modificado_en)
  values (gen_random_uuid(), gen_random_uuid(), 'otra', '2026-11-21', 'Taller (ejemplo)', now())$$, 'ni el lugar del mantenimiento', '42703');
-- Ni escondida en los dos jsonb.
select pruebas.como('ana@ejemplo.test');
insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values ('f8500000-0000-4000-8000-000000000001', 'Mi bici (ejemplo)', now());
insert into public.hab_bici_perfil (modificado_en) values (now());
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"texto": "Salida", "ruta": "calle", "lat": 19.4}]'$$,
  'Una ruta dentro de la preparación se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"id": "luces", "activo": true, "ubicacion": "casa"}]'$$,
  '… también una ubicación', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"contacto": "Mamá", "telefono": "5555555555"}]'$$,
  '… o un contacto con teléfono (sin id ni texto)', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"ruta": {"km": 10}}'$$, 'Una ruta dentro de los intervalos se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"km": 10, "lugar": "taller"}}'$$, '… ni un lugar', '23514');
-- El enlace de música es el único enlace del servidor y debe ser https.
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'geo:19.4326,-99.1332', 1, now())$$, 'Un enlace geo: (coordenadas) no entra como enlace de música', '23514');

rollback;
