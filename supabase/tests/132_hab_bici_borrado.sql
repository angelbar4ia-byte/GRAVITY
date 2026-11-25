-- Bicicleta (Fase 8, B2, CA-B-20): borrar mis datos. El alcance «bicicleta» borra solo las cuatro tablas hab_bici_*
-- (decisión del dueño del 25/nov/2026: la música será un módulo propio y NO se borra con la bicicleta); el alcance
-- «todo» y la baja a los 90 días (D21) borran esas cuatro y también hab_musica_listas; «entrenamiento» no toca ninguna
-- de las cinco; una tabla hab_* ausente de la lista falla la prueba (H-10). Migración: 20261155000000.
begin;

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
  -- (la lista sobrevive al alcance «bicicleta»: al volver a sembrar no se duplica)
  insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
    values (v_l, 'Lista de ejemplo', 'bicicleta', 'otra', 'https://musica.ejemplo.test/lista/1', 1, now())
    on conflict (persona_id, id) do nothing;
end
$$;
-- Filas de bicicleta de una persona: las cuatro hab_bici_* (sin RLS: se corre como postgres).
create function pruebas.bici_de(p_correo text) returns integer
language sql stable
as $$
  select (select count(*) from public.hab_bici_bicicletas where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_bici_perfil where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_bici_mantenimientos where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_bici_salidas where persona_id = pruebas.id_persona(p_correo))::int
$$;
-- Listas de música de una persona (aparte: no son de la bicicleta).
create function pruebas.musica_de(p_correo text) returns integer
language sql stable
as $$
  select (select count(*) from public.hab_musica_listas where persona_id = pruebas.id_persona(p_correo))::int
$$;
grant execute on function pruebas.sembrar_bici(integer, uuid) to authenticated;

select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_bici(1, 'f5100000-0000-4000-8000-000000000001');
insert into public.hab_ent_perfil (modificado_en) values (now());   -- entrenamiento de Ana: no debe tocarse con «bicicleta»
select pruebas.como('alex@ejemplo.test');
select pruebas.sembrar_bici(2);
select pruebas.como('carla@ejemplo.test');
select pruebas.sembrar_bici(3);
select pruebas.como_postgres();
select pruebas.igual(pruebas.bici_de('ana@ejemplo.test'), 4, 'Ana tiene sus cuatro filas de bicicleta…');
select pruebas.igual(pruebas.musica_de('ana@ejemplo.test'), 1, '… y su lista de música');

-- ---------------------------------------------------------------- alcance «bicicleta»
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('ubicacion')$$, 'Un alcance desconocido se rechaza', '22023');
select public.hab_borrar_mis_datos('bicicleta');
select pruebas.como_postgres();
select pruebas.igual(pruebas.bici_de('ana@ejemplo.test'), 0, 'hab_borrar_mis_datos(bicicleta) borra las cuatro tablas hab_bici_* de Ana');
select pruebas.igual(pruebas.musica_de('ana@ejemplo.test'), 1, '… y NO borra su lista de música (será un módulo propio)');
select pruebas.igual(pruebas.bici_de('alex@ejemplo.test') + pruebas.musica_de('alex@ejemplo.test'), 5, '… y no toca lo de la pareja');
select pruebas.igual(pruebas.bici_de('carla@ejemplo.test') + pruebas.musica_de('carla@ejemplo.test'), 5, '… ni lo de la familiar');
select pruebas.igual((select count(*)::int from public.hab_ent_perfil where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1,
  'El entrenamiento de Ana queda (no es de la bicicleta)');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 2,
  'Lo demás de Hábitos de Ana queda (objetivos)');
select pruebas.igual((select count(*)::int from public.hab_bloques where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1, '… y su bloque de agenda');
select pruebas.igual((select count(*)::int from public.hab_sobres where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1, '… ni sus sobres del diario');
select pruebas.igual((select modo from public.hab_modos where persona_id = pruebas.id_persona('ana@ejemplo.test') and tipo = 'diario_oracion'), 'nube_cifrada',
  '… ni sus modos');
select pruebas.igual((select epoca_nube from public.hab_ajustes where persona_id = pruebas.id_persona('ana@ejemplo.test')), 0,
  '… ni la época de la nube (no hay nada cifrado que reiniciar)');
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'habitos.borrar_datos' and persona_id = pruebas.id_persona('ana@ejemplo.test')), 1,
  'Deja una constancia sin contenido');
select pruebas.igual((select detalle::text || '/' || coalesce(tabla, 'sin tabla') from public.bitacora
  where accion = 'habitos.borrar_datos' and persona_id = pruebas.id_persona('ana@ejemplo.test')), '{}/sin tabla', '… sin tabla ni detalle');
select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_bici(1, 'f5100000-0000-4000-8000-000000000001');   -- vuelve a empezar de cero sin chocar con nada

-- ---------------------------------------------------------------- los alcances que no son de bicicleta no la tocan
select public.hab_borrar_mis_datos('sensibles');
select public.hab_borrar_mis_datos('diario');
select public.hab_borrar_mis_datos('entrenamiento');
select pruebas.como_postgres();
select pruebas.igual(pruebas.bici_de('ana@ejemplo.test'), 4, 'sensibles, diario y entrenamiento no borran la bicicleta…');
select pruebas.igual(pruebas.musica_de('ana@ejemplo.test'), 1, '… ni sus enlaces de música');
select pruebas.igual((select count(*)::int from public.hab_ent_perfil where persona_id = pruebas.id_persona('ana@ejemplo.test')), 0, '… y entrenamiento sí borró lo suyo');
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- alcance «todo»
select public.hab_borrar_mis_datos('todo');
select pruebas.como_postgres();
select pruebas.igual(pruebas.bici_de('ana@ejemplo.test'), 0, 'hab_borrar_mis_datos(todo) también borra las cuatro tablas de la bicicleta…');
select pruebas.igual(pruebas.musica_de('ana@ejemplo.test'), 0, '… y SÍ borra los enlaces de música (todo es todo)');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 0, '… y lo demás de Hábitos');
select pruebas.igual((select count(*)::int from public.hab_ajustes where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1, '… y deja los ajustes');
select pruebas.igual(pruebas.bici_de('alex@ejemplo.test') + pruebas.musica_de('alex@ejemplo.test'), 5, 'Lo de la pareja sigue intacto');

-- ---------------------------------------------------------------- quien no tiene Hábitos no borra
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('bicicleta')$$, 'La cuenta maestra no borra', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('bicicleta')$$, 'La cuidadora tampoco', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('bicicleta')$$, 'ni Hogar', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.hab_borrar_mis_datos('bicicleta')$$, 'ni anon', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_datos_de(pruebas.id_persona('ana@ejemplo.test'), 'bicicleta')$$,
  'Nadie llama a la función interna con la persona de otro', '42501');
select pruebas.como_postgres();
select pruebas.igual(pruebas.bici_de('alex@ejemplo.test') + pruebas.musica_de('alex@ejemplo.test'), 5, 'Nada de lo anterior tocó lo de Alex');

-- ---------------------------------------------------------------- la persona borra lo suyo, fila por fila, y las llaves se comportan
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_bicicletas$$), 1, 'Alex borra su bicicleta…');
select pruebas.como_postgres();
select pruebas.igual((select bicicleta_activa_id from public.hab_bici_perfil where persona_id = pruebas.id_persona('alex@ejemplo.test')), null,
  '… y su perfil queda sin bicicleta activa (el perfil sigue ahí)');
select pruebas.igual((select bicicleta_id from public.hab_bici_salidas where persona_id = pruebas.id_persona('alex@ejemplo.test')), null,
  '… su salida queda sin bicicleta (la salida sigue)');
select pruebas.igual((select count(*)::int from public.hab_bici_salidas where persona_id = pruebas.id_persona('alex@ejemplo.test')), 1, '… la salida sigue');
select pruebas.igual((select count(*)::int from public.hab_bici_mantenimientos where persona_id = pruebas.id_persona('alex@ejemplo.test')), 0,
  '… y sus mantenimientos y lecturas se van con ella (cascada)');
select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_bici(7);
-- hab_borrar_mis_datos('todo') borró el bloque de Ana: se vuelve a crear para probar la llave de la salida.
select pruebas.como_postgres();
insert into public.hab_bloques (id, hogar_id, persona_id, titulo, area, tipo, inicio, duracion_min, dias, desde, modificado_en)
  values ('f8400000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'),
          'Salida en bicicleta (ejemplo)', 'salud', 'actividad', '08:00', 240, 32, '2026-11-02', now());
update public.hab_bici_salidas set bloque_id = 'f8400000-0000-4000-8000-000000000001' where persona_id = pruebas.id_persona('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.hab_bici_salidas where bloque_id = 'f8400000-0000-4000-8000-000000000001'), 1,
  'Una salida puede colgar de su bloque de Hábitos');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bloques where id = 'f8400000-0000-4000-8000-000000000001'$$), 1, 'Si Ana borra el bloque…');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_bici_salidas where persona_id = pruebas.id_persona('ana@ejemplo.test') and bloque_id is null), 1,
  '… la salida se queda, sin bloque (no se borra ni falla)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_salidas$$), 1, 'Si Ana borra una salida…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_bicicletas$$), 1, '… su bicicleta sigue (la salida no es dueña de nada)');
select pruebas.igual(pruebas.afecta($$delete from public.hab_musica_listas$$), 1, 'Una lista de música se borra sola');

-- ---------------------------------------------------------------- la baja: se conserva sin acceso y se borra a los 90 días
select pruebas.como_postgres();
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.igual(pruebas.bici_de('carla@ejemplo.test') + pruebas.musica_de('carla@ejemplo.test'), 5, 'Quien se da de baja conserva sus datos…');
select pruebas.igual(public.hab_limpiar(now() + interval '89 days'), 0, 'A los 89 días no se borra nada');
select pruebas.igual(pruebas.bici_de('carla@ejemplo.test') + pruebas.musica_de('carla@ejemplo.test'), 5, '… sigue ahí');
select pruebas.ok(public.hab_limpiar(now() + interval '91 days') >= 1, 'A los 91 días se limpia a esa persona');
select pruebas.igual(pruebas.bici_de('carla@ejemplo.test') + pruebas.musica_de('carla@ejemplo.test'), 0,
  '… y el borrado incluye las cuatro tablas de la bicicleta y la música (la baja equivale a «todo»)');
select pruebas.igual(pruebas.bici_de('alex@ejemplo.test') + pruebas.musica_de('alex@ejemplo.test'), 3,
  'Lo de quien sigue en el hogar no se toca (Alex: 3 filas, sin la bicicleta que borró ni su lectura)');

-- ---------------------------------------------------------------- guardias (H-10): una tabla ausente de la lista falla la prueba
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_%'
      and position('public.' || c.relname in pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure)) = 0),
  '', 'Toda tabla hab_* (también las futuras) aparece en hab_borrar_datos_de');
-- El bloque del alcance bicicleta va de «in ('bicicleta', 'todo')» hasta «if p_alcance = 'todo'»; el de «todo» solo, desde ahí.
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c,
          (select pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure) as def) f
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_bici\_%'
      and position('delete from public.' || c.relname || ' where persona_id' in
        substr(f.def, position('''bicicleta'', ''todo''' in f.def),
               position('if p_alcance = ''todo''' in f.def) - position('''bicicleta'', ''todo''' in f.def))) = 0),
  '', 'Las cuatro hab_bici_* están dentro del bloque del alcance bicicleta');
select pruebas.igual(
  (select position('delete from public.hab_musica_listas where persona_id' in
            substr(f.def, position('''bicicleta'', ''todo''' in f.def),
                   position('if p_alcance = ''todo''' in f.def) - position('''bicicleta'', ''todo''' in f.def)))
     from (select pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure) as def) f),
  0, 'hab_musica_listas NO está dentro del bloque del alcance bicicleta');
select pruebas.ok(
  (select position('delete from public.hab_musica_listas where persona_id' in substr(f.def, position('if p_alcance = ''todo''' in f.def))) > 0
     from (select pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure) as def) f),
  'hab_musica_listas SÍ está en el bloque de todo');
select pruebas.ok(pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure) like '%''bicicleta''%'
  and pg_get_functiondef('public.hab_borrar_mis_datos(text)'::regprocedure) like '%''bicicleta''%',
  'El alcance bicicleta existe en las dos funciones');
select pruebas.ok(pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure) like '%''entrenamiento''%'
  and pg_get_functiondef('public.hab_borrar_mis_datos(text)'::regprocedure) like '%''entrenamiento''%',
  'y siguen los alcances anteriores');

rollback;
