-- Bicicleta (Fase 8, B2, CA-B-23, PB-14): enlaces de música. Solo https, de 10 a 300 caracteres; el dominio no se
-- restringe, el esquema sí. La tabla es compartida: el gimnasio y la bicicleta leen la misma lista (no tiene
-- columna de módulo, solo de actividad). Cada persona ve solo las suyas.
begin;

select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- enlace: solo https
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'Spotify (ejemplo)', 'bicicleta', 'spotify', 'https://open.spotify.example/playlist/abc123', 1, now()),
         (gen_random_uuid(), 'Amazon Music (ejemplo)', 'fuerza', 'amazon_music', 'https://music.amazon.example/playlists/xyz', 2, now()),
         (gen_random_uuid(), 'Otra app (ejemplo)', 'traslado', 'otra', 'https://otra.example/lista?id=7&x=y#parte', 3, now())$$), 3,
  'Enlaces https de varias apps y dominios entran (el dominio no se restringe)');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'http://musica.ejemplo.test/lista/1', 4, now())$$, 'http sin cifrar se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'HTTPS://musica.ejemplo.test/lista/1', 4, now())$$, 'El esquema va en minúsculas: HTTPS:// se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'javascript:alert(1)//https://x.example', 4, now())$$, 'javascript: se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'intent://musica.ejemplo.test/lista#Intent;scheme=https;end', 4, now())$$, 'intent: se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'file:///sdcard/Download/lista.m3u', 4, now())$$, 'file: se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'content://media/external/audio/lista', 4, now())$$, 'content: se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'tel:+525555555555', 4, now())$$, 'tel: se rechaza (no es un enlace de música)', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'sms:+525555555555?body=hola', 4, now())$$, 'sms: se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'geo:19.4326,-99.1332', 4, now())$$, 'geo: se rechaza (eso es una ruta, va en el dispositivo)', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'musica.ejemplo.test/lista/1', 4, now())$$, 'Sin esquema se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://musica.ejemplo.test/mi lista', 4, now())$$, 'Un enlace con espacios se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', E'https://musica.ejemplo.test/lista\n', 4, now())$$, '… ni con salto de línea', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', null, 4, now())$$, 'El enlace es obligatorio', '23502');

-- ---------------------------------------------------------------- enlace: de 10 a 300 caracteres
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://', 4, now())$$, 'Solo el esquema (8 caracteres) se rechaza', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://a', 4, now())$$, '9 caracteres se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'Corto', 'bicicleta', 'otra', 'https://ab', 4, now())$$), 1, '10 caracteres entra');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'Largo', 'bicicleta', 'otra', 'https://' || repeat('a', 292), 5, now())$$), 1, '300 caracteres entra');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://' || repeat('a', 293), 6, now())$$, '301 caracteres se rechaza', '23514');

-- ---------------------------------------------------------------- las demás columnas
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), '   ', 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 6, now())$$, 'nombre vacío', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), repeat('n', 61), 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 6, now())$$, 'nombre de 61 caracteres', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), repeat('n', 60), 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 6, now())$$), 1, 'nombre de 60 caracteres entra');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'yoga', 'otra', 'https://musica.ejemplo.test/x', 7, now())$$, 'actividad fuera de la lista', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  select gen_random_uuid(), 'A ' || a, a, 'otra', 'https://musica.ejemplo.test/' || a, 7, now()
  from unnest(array['bicicleta', 'fuerza', 'regenerativo', 'traslado', 'devocional']) a$$), 5, 'Las cinco actividades entran');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'youtube', 'https://musica.ejemplo.test/x', 8, now())$$, 'app fuera de spotify, amazon_music y otra', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 0, now())$$, 'orden 0', '23514');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 21, now())$$, 'orden 21', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'Orden 20', 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 20, now())$$), 1, 'orden 20 entra');
select pruebas.falla($$update public.hab_musica_listas set enlace = 'http://musica.ejemplo.test/x' where nombre = 'Corto'$$, 'Cambiar el enlace a http también se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_musica_listas set enlace = 'https://otra.example/nueva' where nombre = 'Corto'$$), 1, '… y a otro https entra');

-- ---------------------------------------------------------------- compartida entre el gimnasio y la bicicleta
select pruebas.ok((select count(*) = 0 from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_musica_listas' and column_name ~* '(modulo|gimnasio|bici)'),
  'La tabla no tiene columna de módulo: una lista de «fuerza» y una de «bicicleta» son del mismo lugar');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas where actividad = 'fuerza'$$), 2,
  'La consulta que haría el gimnasio (actividad fuerza) ve sus listas…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas where actividad = 'bicicleta'$$), 6,
  '… la que haría la bicicleta (actividad bicicleta) ve las suyas…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas$$), 12, '… y cualquiera de las dos puede leer todas (12 en total)');

-- ---------------------------------------------------------------- cada persona ve solo las suyas
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas$$), 0, 'La pareja no ve las listas de Ana');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'La de Alex', 'fuerza', 'amazon_music', 'https://music.amazon.example/alex', 1, now())$$), 1, 'Alex guarda la suya');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas$$), 1, '… y solo ve esa');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas where nombre = 'La de Alex'$$), 0, 'Ana tampoco ve la de Alex');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas$$), 0, 'La cuenta maestra no ve ninguna');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas$$), 0, 'ni la cuidadora');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas$$), 0, 'ni la cuenta Hogar');
select pruebas.como_anon();
select pruebas.falla($$select * from public.hab_musica_listas$$, 'ni anon', '42501');

rollback;
