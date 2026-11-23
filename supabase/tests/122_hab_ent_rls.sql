-- Entrenamiento (Fase 8, G2, CA-G-26): las seis tablas hab_ent_* son de UNA persona. Ni el dueño, ni la pareja,
-- ni la cuenta maestra, ni Casa, ni el cuidador, ni otro hogar, ni anon leen o escriben lo ajeno. Sin bitácora.
begin;

-- Ayudantes de esta prueba (se deshacen con el rollback): siembra lo mismo para la sesión actual y cuenta lo visible.
create function pruebas.sembrar_ent(p_n integer) returns void
language plpgsql
as $$
declare
  v_b uuid := ('f8200000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
  v_s uuid := ('f8100000-0000-5000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
  v_r uuid := ('f8300000-0000-5000-8000-' || lpad(p_n::text, 12, '0'))::uuid;
begin
  insert into public.hab_ent_perfil (modificado_en) values (now());
  insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (1, 'A', now());
  insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
    values ('marcy.press', 'disponible', '{"pasos_max": 10}', now());
  insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (v_b, 'Verde', 1, 1, now());
  insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan,
                                       catalogo_version, modificado_en)
    values (v_s, '2026-11-02'::date + p_n, 'A', 'estandar', 'carga', 'noche', '2026-11-02 20:00-06', '2026-11-02 20:45-06',
            'completa', '[{"ejercicio": "marcy.press", "series": 3, "reps_min": 8, "reps_max": 12}]', 1, now());
  insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, carga_pasos, banda_id, esfuerzo, modificado_en)
    values (v_r, v_s, 'marcy.press', 'press_sentado', 1, 10, 4, v_b, 3, now());
end
$$;
create function pruebas.ent_visibles() returns integer
language sql stable
as $$
  select (select count(*) from public.hab_ent_perfil)::int + (select count(*) from public.hab_ent_plan_dias)::int
       + (select count(*) from public.hab_ent_inventario)::int + (select count(*) from public.hab_ent_bandas)::int
       + (select count(*) from public.hab_ent_sesiones)::int + (select count(*) from public.hab_ent_series)::int
$$;
grant execute on function pruebas.sembrar_ent(integer), pruebas.ent_visibles() to authenticated, service_role;

-- Cada persona siembra lo suyo (el bloque de Hábitos de Ana, para probar la llave foránea de la sesión, viene del seed).
select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_ent(1);
select pruebas.como('alex@ejemplo.test');
select pruebas.sembrar_ent(2);
select pruebas.como('carla@ejemplo.test');
select pruebas.sembrar_ent(3);
select pruebas.como('elena@ejemplo.test');
select pruebas.sembrar_ent(4);

-- ---------------------------------------------------------------- cada quien lo suyo
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 6, 'Ana ve lo suyo: una fila en cada una de las seis tablas');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'$$), 1, '… su sesión');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 6, 'La pareja (coadministrador) ve solo lo suyo');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'$$), 0,
  'El coadministrador NO lee la sesión del dueño');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_series where id = 'f8300000-0000-5000-8000-000000000001'$$), 0, '… ni su serie');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_bandas where id = 'f8200000-0000-4000-8000-000000000001'$$), 0, '… ni sus bandas');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 6, 'La familiar ve solo lo suyo');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select persona_id from public.hab_ent_perfil where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_ent_plan_dias where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_ent_inventario where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_ent_bandas where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_ent_sesiones where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$)
  + pruebas.cuenta($$select persona_id from public.hab_ent_series where persona_id <> pruebas.id_persona('ana@ejemplo.test')$$), 0,
  'El dueño del hogar NO lee nada de la pareja ni de la familiar (ninguna de las seis tablas)');

-- ---------------------------------------------------------------- no se cambia ni se borra lo ajeno
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 5, modificado_en = now() + interval '1 minute'
  where id = 'f8100000-0000-5000-8000-000000000001'$$), 0, 'Alex no cambia la sesión de Ana (0 filas)');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set reps = 99, modificado_en = now() + interval '1 minute'
  where id = 'f8300000-0000-5000-8000-000000000001'$$), 0, '… ni su serie');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set dias_plan = 5, modificado_en = now() + interval '1 minute'
  where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0, '… ni su perfil');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'$$), 0,
  '… ni la borra');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_inventario where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0,
  '… ni su inventario');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_series$$), 1, 'Un DELETE sin filtro solo alcanza lo suyo (1 serie)');
-- Persona y hogar los pone el servidor: la app no los manda ni los cambia.
select pruebas.falla($$insert into public.hab_ent_bandas (id, persona_id, nombre, orden, cantidad, modificado_en)
  values (gen_random_uuid(), pruebas.id_persona('ana@ejemplo.test'), 'X', 1, 1, now())$$, 'La app no manda persona_id (sin permiso de columna)', '42501');
select pruebas.falla($$insert into public.hab_ent_bandas (id, hogar_id, nombre, orden, cantidad, modificado_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000002', 'X', 1, 1, now())$$, 'ni hogar_id', '42501');
select pruebas.falla($$update public.hab_ent_perfil set persona_id = pruebas.id_persona('ana@ejemplo.test')$$, 'ni cambia la persona de lo suyo', '42501');
-- Las llaves foráneas compuestas no cruzan personas.
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000a1', 'f8100000-0000-5000-8000-000000000001', 'marcy.press', 'press_sentado', 2, now())$$,
  'Una serie no cuelga de la sesión de otra persona', '23503');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, banda_id, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000a2', 'f8100000-0000-5000-8000-000000000002', 'marcy.press', 'press_sentado', 2,
          'f8200000-0000-4000-8000-000000000001', now())$$, 'ni usa la banda de otra persona', '23503');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, bloque_id, inicio, fin, estado,
    catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000a3', '2026-12-01', 'B', 'corta', 'carga', 'noche', 'f5100000-0000-4000-8000-000000000001',
          '2026-12-01 20:00-06', '2026-12-01 20:30-06', 'completa', 1, now())$$, 'ni apunta al bloque de Hábitos de otra persona', '23503');

-- ---------------------------------------------------------------- los demás roles: nada, ni leer ni escribir
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 0, 'La cuenta maestra no lee nada de hab_ent_*');
select pruebas.falla($$insert into public.hab_ent_perfil (modificado_en) values (now())$$, 'ni escribe su perfil', '42501');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, estado, catalogo_version, modificado_en)
  values (gen_random_uuid(), '2026-12-01', 'A', 'corta', 'carga', 'noche', now(), 'en_curso', 1, now())$$, 'ni una sesión', '42501');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 1$$), 0, 'ni cambia nada ajeno');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_series$$), 0, 'ni borra nada ajeno');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 0, 'La cuidadora no lee nada');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'X', 1, 1, now())$$,
  'ni escribe', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 0, 'La cuenta Hogar (tablet pública) no lee nada');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'X', 1, 1, now())$$,
  'ni escribe', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 6, 'Otro hogar: solo lo suyo (6 filas)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones where id in
  ('f8100000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000002', 'f8100000-0000-5000-8000-000000000003')$$), 0,
  '… nada del hogar de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0,
  '… ni por hogar');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000a9', 'f8100000-0000-5000-8000-000000000001', 'marcy.press', 'press_sentado', 3, now())$$,
  'Otro hogar no cuelga series de una sesión de este', '23503');
select pruebas.como_anon();
select pruebas.falla($$select * from public.hab_ent_perfil$$, 'Sin sesión no se lee el perfil', '42501');
select pruebas.falla($$select * from public.hab_ent_plan_dias$$, 'ni el plan', '42501');
select pruebas.falla($$select * from public.hab_ent_inventario$$, 'ni el inventario', '42501');
select pruebas.falla($$select * from public.hab_ent_bandas$$, 'ni las bandas', '42501');
select pruebas.falla($$select * from public.hab_ent_sesiones$$, 'ni las sesiones', '42501');
select pruebas.falla($$select * from public.hab_ent_series$$, 'ni las series', '42501');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'X', 1, 1, now())$$,
  'anon tampoco escribe', '42501');
select pruebas.falla($$delete from public.hab_ent_series$$, 'ni borra', '42501');
select pruebas.como_servicio();
select pruebas.ok(pruebas.ent_visibles() >= 0, 'service_role solo lee (respaldo y mantenimiento)');
select pruebas.falla($$insert into public.hab_ent_bandas (id, hogar_id, persona_id, nombre, orden, cantidad, modificado_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'X', 1, 1, now())$$,
  'service_role no escribe directo', '42501');
select pruebas.falla($$delete from public.hab_ent_series$$, 'ni borra directo', '42501');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_ent_sesiones where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1, 'Lo de Ana sigue intacto');
select pruebas.igual((select reps from public.hab_ent_series where id = 'f8300000-0000-5000-8000-000000000001'), 10::smallint, '… también su serie');

-- ---------------------------------------------------------------- una persona dada de baja pierde el acceso (y se conserva)
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 0, 'Quien se da de baja pierde el acceso al instante');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'X', 1, 1, now())$$,
  '… y ya no escribe', '42501');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_series$$), 0, '… ni borra');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_ent_series where persona_id = pruebas.id_persona('carla@ejemplo.test')), 1,
  'Sus datos se conservan (se borran a los 90 días)');
update public.membresias set activa = true, hasta = null where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 6, 'Si vuelve al hogar recupera su acceso y sus datos');
-- Quien pasa a cuidador ya no tiene Hábitos.
select pruebas.como_postgres();
update public.membresias set rol = 'cuidador' where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.ent_visibles(), 0, 'Quien pasa a cuidador ya no lee nada de hab_ent_*');

-- ---------------------------------------------------------------- sin bitácora (CA-G-26)
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where lower(tabla) like 'hab\_ent\_%'), 0,
  'Escribir en las seis tablas no deja ninguna entrada en la bitácora');
select pruebas.igual((select count(*)::int from pg_trigger g
   where g.tgrelid in ('public.hab_ent_perfil'::regclass, 'public.hab_ent_plan_dias'::regclass, 'public.hab_ent_inventario'::regclass,
                       'public.hab_ent_bandas'::regclass, 'public.hab_ent_sesiones'::regclass, 'public.hab_ent_series'::regclass)
     and not g.tgisinternal and g.tgfoid = 'public.registrar_cambio_en_bitacora()'::regprocedure), 0,
  'Ninguna de las seis tiene el trigger de bitácora');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', 'hab_ent_series')$$,
  'Una entrada con tabla hab_ent_series es rechazada', '42501');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', ' Public.HAB_ENT_sesiones')$$,
  '… también con mayúsculas, espacio y esquema', '42501');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla) values ('b0000000-0000-4000-8000-000000000001', 'x', 'hab_ent_perfil')$$,
  '… en cualquiera de las seis', '42501');
select pruebas.como_postgres();
insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id) values
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'actualizar', 'hab_ent_series', 'f8300000-0000-5000-8000-000000000002'),
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'actualizar', 'hab_ent_sesiones', 'f8100000-0000-5000-8000-000000000002');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where lower(tabla) like 'hab\_ent\_%'$$), 0,
  'Si el servidor escribiera una (simulado), el dueño no la ve');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where lower(tabla) like 'hab\_ent\_%'$$), 0, 'ni la cuenta maestra');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where lower(tabla) like 'hab\_ent\_%'$$), 0, 'ni otra persona del hogar');

rollback;
