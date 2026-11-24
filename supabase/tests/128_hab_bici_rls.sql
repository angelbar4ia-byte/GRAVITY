-- Bicicleta (Fase 8, B2, CA-B-16): las cinco tablas hab_bici_* y hab_musica_listas son de UNA persona. Ni el dueño,
-- ni la pareja, ni la cuenta maestra, ni Casa, ni el cuidador, ni otro hogar, ni anon leen o escriben lo ajeno.
-- Una baja pierde el acceso. Sin bitácora (el prefijo hab_ está reservado).
begin;

-- Ayudantes de esta prueba (se deshacen con el rollback): siembra lo mismo para la sesión actual y cuenta lo visible.
-- Ids de ejemplo con la forma de v4 (bicicleta, lista) y de v5 (mantenimiento, salida).
create function pruebas.sembrar_bici(p_n integer, p_bloque uuid default null) returns void
language plpgsql
as $$
declare
  v_b uuid := ('f8500000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
  v_m uuid := ('f8600000-0000-5000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
  v_s uuid := ('f8700000-0000-5000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
  v_l uuid := ('f8800000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
begin
  insert into public.hab_bici_bicicletas (id, nombre, tipo, odometro_inicial_m, intervalos, modificado_en)
    values (v_b, 'Mi bici (ejemplo)', 'gravel', 350000, '{"lubricar_cadena": {"km": 150, "semanas": 4}}', now());
  insert into public.hab_bici_perfil (bicicleta_activa_id, preparacion, modificado_en)
    values (v_b, '[{"id": "luces_cargadas", "activo": true}, {"texto": "Llevar mi gorra (ejemplo)"}]', now());
  insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, odometro_m, modificado_en)
    values (v_m, v_b, 'lectura_odometro', '2026-11-14', 480000, now());
  insert into public.hab_bici_salidas (id, fecha, n, bloque_id, bicicleta_id, inicio, duracion_min, distancia_m, desnivel_m,
                                       superficie, esfuerzo, clima, acompanado, estado, modificado_en)
    values (v_s, '2026-11-21', 1, p_bloque, v_b, '08:00', 240, 62000, 500, 'mixta', 3, 'despejado', false, 'hecha', now());
  insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
    values (v_l, 'Lista de ejemplo', 'bicicleta', 'otra', 'https://musica.ejemplo.test/lista/1', 1, now());
end
$$;
create function pruebas.bici_visibles() returns integer
language sql stable
as $$
  select (select count(*) from public.hab_bici_bicicletas)::int + (select count(*) from public.hab_bici_perfil)::int
       + (select count(*) from public.hab_bici_mantenimientos)::int + (select count(*) from public.hab_bici_salidas)::int
       + (select count(*) from public.hab_musica_listas)::int
$$;
grant execute on function pruebas.sembrar_bici(integer, uuid), pruebas.bici_visibles() to authenticated, service_role;

-- Cada persona siembra lo suyo (el bloque de Hábitos de Ana, para probar la llave foránea de la salida, viene del seed).
select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_bici(1, 'f5100000-0000-4000-8000-000000000001');
select pruebas.como('alex@ejemplo.test');
select pruebas.sembrar_bici(2);
select pruebas.como('carla@ejemplo.test');
select pruebas.sembrar_bici(3);
select pruebas.como('elena@ejemplo.test');
select pruebas.sembrar_bici(4);

-- ---------------------------------------------------------------- cada quien lo suyo
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 5, 'Ana ve lo suyo: una fila en cada una de las cinco tablas');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'$$), 1, '… su salida');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 5, 'La pareja (coadministrador) ve solo lo suyo');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'$$), 0,
  'El coadministrador NO lee la salida del dueño');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_bicicletas where id = 'f8500000-0000-4000-8000-000000000001'$$), 0, '… ni su bicicleta');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_mantenimientos where id = 'f8600000-0000-5000-8000-000000000001'$$), 0, '… ni su lectura del odómetro');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_musica_listas where id = 'f8800000-0000-4000-8000-000000000001'$$), 0, '… ni su lista de música');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_perfil where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0, '… ni su perfil');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 5, 'La familiar ve solo lo suyo');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select persona_id from public.hab_bici_bicicletas where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_bici_perfil where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_bici_mantenimientos where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_bici_salidas where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_musica_listas where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$), 0,
  'El dueño del hogar NO lee nada de la pareja ni de la familiar (ninguna de las cinco tablas)');

-- ---------------------------------------------------------------- no se cambia ni se borra lo ajeno
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 5, modificado_en = now() + interval '1 minute'
  where id = 'f8700000-0000-5000-8000-000000000001'$$), 0, 'Alex no cambia la salida de Ana (0 filas)');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set nombre = 'Mía', modificado_en = now() + interval '1 minute'
  where id = 'f8500000-0000-4000-8000-000000000001'$$), 0, '… ni su bicicleta');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_mantenimientos set odometro_m = 1, modificado_en = now() + interval '1 minute'
  where id = 'f8600000-0000-5000-8000-000000000001'$$), 0, '… ni su lectura');
select pruebas.igual(pruebas.afecta($$update public.hab_musica_listas set orden = 9, modificado_en = now() + interval '1 minute'
  where id = 'f8800000-0000-4000-8000-000000000001'$$), 0, '… ni su lista de música');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set carga_piernas = 'ligera', modificado_en = now() + interval '1 minute'
  where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0, '… ni su perfil');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'$$), 0, '… ni la borra');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_bicicletas where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0, '… ni su bicicleta');
select pruebas.igual(pruebas.afecta($$delete from public.hab_musica_listas$$), 1, 'Un DELETE sin filtro solo alcanza lo suyo (1 lista)');
-- Persona y hogar los pone el servidor: la app no los manda ni los cambia.
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, persona_id, nombre, modificado_en)
  values (gen_random_uuid(), pruebas.id_persona('ana@ejemplo.test'), 'X', now())$$, 'La app no manda persona_id (sin permiso de columna)', '42501');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, hogar_id, nombre, modificado_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000002', 'X', now())$$, 'ni hogar_id', '42501');
select pruebas.falla($$update public.hab_bici_perfil set persona_id = pruebas.id_persona('ana@ejemplo.test')$$, 'ni cambia la persona de lo suyo', '42501');
-- Las llaves foráneas compuestas no cruzan personas.
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, bicicleta_id, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000a1', '2026-11-28', 1, 'f8500000-0000-4000-8000-000000000001', 'hecha', now())$$,
  'Una salida no usa la bicicleta de otra persona', '23503');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values ('f8600000-0000-5000-8000-0000000000a2', 'f8500000-0000-4000-8000-000000000001', 'lubricar_cadena', '2026-11-28', now())$$,
  'ni un mantenimiento cuelga de la bicicleta de otra persona', '23503');
select pruebas.falla($$update public.hab_bici_perfil set bicicleta_activa_id = 'f8500000-0000-4000-8000-000000000001'$$,
  'ni el perfil la pone como bicicleta activa', '23503');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, bloque_id, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000a3', '2026-11-28', 1, 'f5100000-0000-4000-8000-000000000001', 'hecha', now())$$,
  'ni apunta al bloque de Hábitos de otra persona', '23503');

-- ---------------------------------------------------------------- los demás roles: nada, ni leer ni escribir
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 0, 'La cuenta maestra no lee nada de la bicicleta');
select pruebas.falla($$insert into public.hab_bici_perfil (modificado_en) values (now())$$, 'ni escribe su perfil', '42501');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values (gen_random_uuid(), '2026-12-01', 1, 'hecha', now())$$, 'ni una salida', '42501');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'X', 'bicicleta', 'otra', 'https://musica.ejemplo.test/x', 1, now())$$, 'ni una lista de música', '42501');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 1$$), 0, 'ni cambia nada ajeno');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_salidas$$), 0, 'ni borra nada ajeno');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 0, 'La cuidadora no lee nada');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values (gen_random_uuid(), 'X', now())$$, 'ni escribe', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 0, 'La cuenta Hogar (tablet pública) no lee nada');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values (gen_random_uuid(), 'X', now())$$, 'ni escribe', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 5, 'Otro hogar: solo lo suyo (5 filas)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas where id in
  ('f8700000-0000-5000-8000-000000000001', 'f8700000-0000-5000-8000-000000000002', 'f8700000-0000-5000-8000-000000000003')$$), 0,
  '… nada del hogar de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_salidas where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, '… ni por hogar');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, bicicleta_id, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000a9', '2026-11-28', 1, 'f8500000-0000-4000-8000-000000000001', 'hecha', now())$$,
  'Otro hogar no cuelga una salida de una bicicleta de este', '23503');
select pruebas.como_anon();
select pruebas.falla($$select * from public.hab_bici_perfil$$, 'Sin sesión no se lee el perfil', '42501');
select pruebas.falla($$select * from public.hab_bici_bicicletas$$, 'ni las bicicletas', '42501');
select pruebas.falla($$select * from public.hab_bici_mantenimientos$$, 'ni los mantenimientos', '42501');
select pruebas.falla($$select * from public.hab_bici_salidas$$, 'ni las salidas', '42501');
select pruebas.falla($$select * from public.hab_musica_listas$$, 'ni las listas de música', '42501');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values (gen_random_uuid(), 'X', now())$$, 'anon tampoco escribe', '42501');
select pruebas.falla($$delete from public.hab_bici_salidas$$, 'ni borra', '42501');
select pruebas.como_servicio();
select pruebas.ok(pruebas.bici_visibles() >= 0, 'service_role solo lee (respaldo y mantenimiento)');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, hogar_id, persona_id, nombre, modificado_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'X', now())$$,
  'service_role no escribe directo', '42501');
select pruebas.falla($$delete from public.hab_bici_salidas$$, 'ni borra directo', '42501');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_bici_salidas where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1, 'Lo de Ana sigue intacto');
select pruebas.igual((select distancia_m from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'), 62000, '… también su salida');

-- ---------------------------------------------------------------- una persona dada de baja pierde el acceso (y se conserva)
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 0, 'Quien se da de baja pierde el acceso al instante');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values (gen_random_uuid(), 'X', now())$$, '… y ya no escribe', '42501');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_salidas$$), 0, '… ni borra');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_bici_salidas where persona_id = pruebas.id_persona('carla@ejemplo.test')), 1,
  'Sus datos se conservan (se borran a los 90 días)');
update public.membresias set activa = true, hasta = null where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 5, 'Si vuelve al hogar recupera su acceso y sus datos');
-- Quien pasa a cuidador ya no tiene Hábitos.
select pruebas.como_postgres();
update public.membresias set rol = 'cuidador' where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.bici_visibles(), 0, 'Quien pasa a cuidador ya no lee nada de la bicicleta');

-- ---------------------------------------------------------------- sin bitácora (CA-B-16)
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where lower(tabla) like 'hab\_bici\_%' or lower(tabla) like 'hab\_musica\_%'), 0,
  'Escribir en las cinco tablas no deja ninguna entrada en la bitácora');
select pruebas.igual((select count(*)::int from pg_trigger g
   where g.tgrelid in ('public.hab_bici_bicicletas'::regclass, 'public.hab_bici_perfil'::regclass, 'public.hab_bici_mantenimientos'::regclass,
                       'public.hab_bici_salidas'::regclass, 'public.hab_musica_listas'::regclass)
     and not g.tgisinternal and g.tgfoid = 'public.registrar_cambio_en_bitacora()'::regprocedure), 0,
  'Ninguna de las cinco tiene el trigger de bitácora');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', 'hab_bici_salidas')$$,
  'Una entrada con tabla hab_bici_salidas es rechazada', '42501');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', ' Public.HAB_BICI_perfil')$$,
  '… también con mayúsculas, espacio y esquema', '42501');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', 'hab_musica_listas')$$,
  '… y con la de música', '42501');
select pruebas.como_postgres();
insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id) values
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'actualizar', 'hab_bici_salidas', 'f8700000-0000-5000-8000-000000000002'),
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'actualizar', 'hab_bici_mantenimientos', 'f8600000-0000-5000-8000-000000000002'),
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'actualizar', 'hab_musica_listas', 'f8800000-0000-4000-8000-000000000002');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where lower(tabla) like 'hab\_bici\_%' or lower(tabla) like 'hab\_musica\_%'$$), 0,
  'Si el servidor escribiera una (simulado), el dueño no la ve');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where lower(tabla) like 'hab\_bici\_%' or lower(tabla) like 'hab\_musica\_%'$$), 0,
  'ni la cuenta maestra');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where lower(tabla) like 'hab\_bici\_%' or lower(tabla) like 'hab\_musica\_%'$$), 0,
  'ni otra persona del hogar');

rollback;
