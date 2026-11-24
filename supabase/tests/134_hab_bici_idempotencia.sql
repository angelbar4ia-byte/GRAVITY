-- Bicicleta (Fase 8, B2, CA-B-22): idempotencia. La misma salida o el mismo mantenimiento con el mismo id (v5) no
-- duplica; con el mismo id y otro contenido gana el de modificado_en más reciente, llegue en el orden que llegue
-- (dos equipos). Los ids de ejemplo tienen la forma de v5 (versión 5 en el tercer grupo).
begin;

-- Subidas como las hace la cola: upsert por id (o por la llave natural en el perfil).
create function pruebas.up_salida(p_id uuid, p_esfuerzo integer, p_mod timestamptz, p_fecha date default '2026-11-21', p_n integer default 1) returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  insert into public.hab_bici_salidas (id, fecha, n, inicio, duracion_min, distancia_m, desnivel_m, superficie, esfuerzo, clima, acompanado, estado, modificado_en)
  values (p_id, p_fecha, p_n, '08:00', 240, 62000, 500, 'mixta', p_esfuerzo, 'despejado', false, 'hecha', p_mod)
  on conflict (id) do update set fecha = excluded.fecha, n = excluded.n, bloque_id = excluded.bloque_id, bicicleta_id = excluded.bicicleta_id,
    inicio = excluded.inicio, duracion_min = excluded.duracion_min, distancia_m = excluded.distancia_m, desnivel_m = excluded.desnivel_m,
    superficie = excluded.superficie, esfuerzo = excluded.esfuerzo, clima = excluded.clima, acompanado = excluded.acompanado,
    estado = excluded.estado, motivo = excluded.motivo, modificado_en = excluded.modificado_en;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
create function pruebas.up_mant(p_id uuid, p_odo integer, p_mod timestamptz, p_fecha date default '2026-11-14') returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, odometro_m, modificado_en)
  values (p_id, 'f8500000-0000-4000-8000-000000000001', 'lectura_odometro', p_fecha, p_odo, p_mod)
  on conflict (id) do update set bicicleta_id = excluded.bicicleta_id, tarea = excluded.tarea, fecha = excluded.fecha,
    odometro_m = excluded.odometro_m, nota = excluded.nota, modificado_en = excluded.modificado_en;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
grant execute on function pruebas.up_salida(uuid, integer, timestamptz, date, integer),
  pruebas.up_mant(uuid, integer, timestamptz, date) to authenticated;

select pruebas.como('ana@ejemplo.test');
-- La bicicleta: se sube antes que lo que cuelga de ella (orden de subida de la cola).
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, odometro_inicial_m, modificado_en)
  values ('f8500000-0000-4000-8000-000000000001', 'Mi bici (ejemplo)', 350000, now() - interval '60 minutes')
  on conflict (id) do update set nombre = excluded.nombre, odometro_inicial_m = excluded.odometro_inicial_m, modificado_en = excluded.modificado_en$$), 1,
  'Bicicleta: se crea con upsert por id');

-- ---------------------------------------------------------------- salida: el mismo id no duplica
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 3, now() - interval '60 minutes'), 1, 'Se sube la salida');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 3, now() - interval '60 minutes'), 1, 'Subirla otra vez (reintento) no falla…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas$$), 1, '… ni duplica: una sola salida');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values ('f8700000-0000-5000-8000-000000000001', '2026-11-21', 1, 'hecha', now())
  on conflict do nothing$$), 0, 'Con ON CONFLICT DO NOTHING tampoco: 0 filas, sin error');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values ('f8700000-0000-5000-8000-000000000001', '2026-11-21', 1, 'hecha', now())$$,
  'Un INSERT simple con el mismo id no duplica: 23505', '23505');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000aa', '2026-11-21', 1, 'hecha', now())$$,
  'Otro id para el mismo día y número tampoco duplica (23505): el id es v5 de persona, fecha y número', '23505');
select pruebas.falla($$select pruebas.up_salida('f8700000-0000-5000-8000-0000000000aa', 2, now())$$, '… ni con upsert por id', '23505');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-0000000000ab', 2, now() - interval '30 minutes', '2026-11-21', 2), 1,
  'La segunda salida del día (otro número, otro id) sí entra');

-- ---------------------------------------------------------------- salida: gana el modificado_en más reciente
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 5, now() - interval '50 minutes'), 1, 'Otro contenido con modificado_en más nuevo: gana');
select pruebas.igual((select esfuerzo from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'), 5::smallint, '… y queda el nuevo');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 1, now() - interval '70 minutes'), 0, 'Otro contenido con modificado_en más viejo: se ignora (0 filas, sin error)');
select pruebas.igual((select esfuerzo from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'), 5::smallint, '… y se queda el más reciente');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas where fecha = '2026-11-21'$$), 2, 'Siguen siendo las dos salidas del día');
-- Dos equipos, el mismo id, llegan en orden inverso: el resultado es el mismo.
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000002', 4, now() - interval '50 minutes', '2026-11-22'), 1, 'Equipo B sube primero (esfuerzo 4, hace 50 min)');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000002', 2, now() - interval '55 minutes', '2026-11-22'), 0, '… y después llega el equipo A (esfuerzo 2, hace 55 min): se ignora');
select pruebas.igual((select esfuerzo from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000002'), 4::smallint, 'Gana el más reciente (el del equipo B)');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000003', 2, now() - interval '55 minutes', '2026-11-23'), 1, 'En el otro orden: A sube primero (hace 55 min)…');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000003', 4, now() - interval '50 minutes', '2026-11-23'), 1, '… y B después (hace 50 min): reemplaza');
select pruebas.igual((select esfuerzo from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000003'), 4::smallint, 'Mismo resultado: gana el más reciente');
-- Del futuro lejano: entra, ajustado.
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 2, now() + interval '3 days'), 1, 'Un modificado_en del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'),
  '… ajustado a la hora del servidor (no deja la fila «congelada» en el futuro)');
select pruebas.igual(pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 3, now() + interval '1 minute'), 1, '… y un cambio posterior legítimo todavía gana');

-- ---------------------------------------------------------------- mantenimiento (lectura del odómetro)
select pruebas.igual(pruebas.up_mant('f8600000-0000-5000-8000-000000000001', 480000, now() - interval '60 minutes'), 1, 'Se sube la lectura del odómetro');
select pruebas.igual(pruebas.up_mant('f8600000-0000-5000-8000-000000000001', 480000, now() - interval '60 minutes'), 1, 'El reintento no falla…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_mantenimientos$$), 1, '… ni duplica');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, odometro_m, modificado_en)
  values ('f8600000-0000-5000-8000-000000000001', 'f8500000-0000-4000-8000-000000000001', 'lectura_odometro', '2026-11-14', 480000, now())$$,
  'Un INSERT simple con el mismo id da 23505', '23505');
select pruebas.falla($$select pruebas.up_mant('f8600000-0000-5000-8000-0000000000bb', 480000, now())$$,
  'La misma tarea de la misma bicicleta y fecha con otro id no duplica (23505)', '23505');
select pruebas.igual(pruebas.up_mant('f8600000-0000-5000-8000-000000000001', 481000, now() - interval '55 minutes'), 1, 'Más nueva gana (481 km)');
select pruebas.igual(pruebas.up_mant('f8600000-0000-5000-8000-000000000001', 470000, now() - interval '65 minutes'), 0, 'Más vieja se ignora');
select pruebas.igual((select odometro_m from public.hab_bici_mantenimientos), 481000, '… queda la más reciente');
select pruebas.igual(pruebas.up_mant('f8600000-0000-5000-8000-000000000001', 482000, now() + interval '30 days'), 1, 'Futuro lejano: entra');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_bici_mantenimientos), '… ajustado');
select pruebas.igual(pruebas.up_mant('f8600000-0000-5000-8000-000000000002', 490000, now() - interval '40 minutes', '2026-11-28'), 1, 'Otra fecha, otro id: otra lectura');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_mantenimientos$$), 2, '… dos lecturas en total');

-- ---------------------------------------------------------------- las otras tres tablas: upsert por su llave natural
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_perfil (duracion_prevista_min, modificado_en) values (240, now() - interval '60 minutes')
  on conflict (persona_id) do update set duracion_prevista_min = excluded.duracion_prevista_min, modificado_en = excluded.modificado_en$$), 1,
  'Perfil: se crea con upsert por persona');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_perfil (duracion_prevista_min, bicicleta_activa_id, modificado_en)
  values (300, 'f8500000-0000-4000-8000-000000000001', now() - interval '50 minutes')
  on conflict (persona_id) do update set duracion_prevista_min = excluded.duracion_prevista_min,
    bicicleta_activa_id = excluded.bicicleta_activa_id, modificado_en = excluded.modificado_en$$), 1, '… y el más nuevo gana');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_perfil (duracion_prevista_min, modificado_en) values (180, now() - interval '120 minutes')
  on conflict (persona_id) do update set duracion_prevista_min = excluded.duracion_prevista_min, modificado_en = excluded.modificado_en$$), 0, '… el más viejo se ignora');
select pruebas.igual((select duracion_prevista_min::text || '/' || bicicleta_activa_id::text from public.hab_bici_perfil), '300/f8500000-0000-4000-8000-000000000001',
  '… y es una sola fila');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, odometro_inicial_m, modificado_en)
  values ('f8500000-0000-4000-8000-000000000001', 'Vieja', 1, now() - interval '120 minutes')
  on conflict (id) do update set nombre = excluded.nombre, odometro_inicial_m = excluded.odometro_inicial_m, modificado_en = excluded.modificado_en$$), 0,
  'Bicicleta: la más vieja se ignora');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, odometro_inicial_m, modificado_en)
  values ('f8500000-0000-4000-8000-000000000001', 'Nueva', 360000, now() - interval '10 minutes')
  on conflict (id) do update set nombre = excluded.nombre, odometro_inicial_m = excluded.odometro_inicial_m, modificado_en = excluded.modificado_en$$), 1,
  '… la más nueva gana');
select pruebas.igual((select nombre || '/' || count(*) over () from public.hab_bici_bicicletas), 'Nueva/1', 'queda «Nueva», una sola bicicleta');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-000000000001', 'Lista', 'bicicleta', 'otra', 'https://musica.ejemplo.test/lista/1', 1, now() - interval '60 minutes')
  on conflict (id) do update set nombre = excluded.nombre, actividad = excluded.actividad, app = excluded.app, enlace = excluded.enlace,
    orden = excluded.orden, modificado_en = excluded.modificado_en$$), 1, 'Música: se crea');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-000000000001', 'Vieja', 'fuerza', 'otra', 'https://musica.ejemplo.test/vieja', 1, now() - interval '120 minutes')
  on conflict (id) do update set nombre = excluded.nombre, actividad = excluded.actividad, app = excluded.app, enlace = excluded.enlace,
    orden = excluded.orden, modificado_en = excluded.modificado_en$$), 0, '… la más vieja se ignora');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-000000000001', 'Nueva', 'fuerza', 'spotify', 'https://musica.ejemplo.test/nueva', 2, now() - interval '10 minutes')
  on conflict (id) do update set nombre = excluded.nombre, actividad = excluded.actividad, app = excluded.app, enlace = excluded.enlace,
    orden = excluded.orden, modificado_en = excluded.modificado_en$$), 1, '… la más nueva gana');
select pruebas.igual((select nombre || '/' || actividad || '/' || count(*) over () from public.hab_musica_listas), 'Nueva/fuerza/1', 'queda «Nueva», una sola lista');

-- ---------------------------------------------------------------- el id de otra persona no se pisa
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select pruebas.up_salida('f8700000-0000-5000-8000-000000000001', 1, now() + interval '1 minute')$$,
  'Alex no pisa con un upsert la salida de Ana (aunque conozca su id)', '42501');
select pruebas.falla($$select pruebas.up_mant('f8600000-0000-5000-8000-000000000001', 1, now() + interval '1 minute')$$, '… ni su lectura', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values ('f8500000-0000-4000-8000-000000000001', 'Falsa', now())
  on conflict (id) do nothing$$), 0, 'Con DO NOTHING no cambia nada ajeno');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-000000000001', 'Falsa', 'bicicleta', 'otra', 'https://musica.ejemplo.test/falsa', 1, now())
  on conflict (id) do update set nombre = excluded.nombre, modificado_en = excluded.modificado_en$$, '… ni la lista de música', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas$$) + pruebas.cuenta($$select * from public.hab_bici_mantenimientos$$), 0, 'Y Alex no ve nada de lo de Ana');
select pruebas.como_postgres();
select pruebas.igual((select esfuerzo from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'), 3::smallint, 'La salida de Ana quedó como ella la dejó');
select pruebas.igual((select odometro_m from public.hab_bici_mantenimientos where id = 'f8600000-0000-5000-8000-000000000001'), 482000, '… y su lectura');
select pruebas.igual((select nombre from public.hab_bici_bicicletas where id = 'f8500000-0000-4000-8000-000000000001'), 'Nueva', '… y su bicicleta');
select pruebas.igual((select nombre from public.hab_musica_listas where id = 'f8800000-0000-4000-8000-000000000001'), 'Nueva', '… y su lista');

rollback;
