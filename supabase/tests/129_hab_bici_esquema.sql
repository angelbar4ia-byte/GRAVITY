-- Bicicleta (Fase 8, B2, CA-B-17): esquema y rangos de las cinco tablas; lo que pone el servidor; el último
-- cambio gana (también el futuro lejano, que se ajusta); la forma de los dos jsonb (preparacion e intervalos).
begin;

create function pruebas.sembrar_bici() returns void
language plpgsql
as $$
begin
  insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values ('f8500000-0000-4000-8000-000000000001', 'Mi bici (ejemplo)', now());
  insert into public.hab_bici_perfil (modificado_en) values (now());
  insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
    values ('f8600000-0000-5000-8000-000000000001', 'f8500000-0000-4000-8000-000000000001', 'lubricar_cadena', '2026-11-14', now());
  insert into public.hab_bici_salidas (id, fecha, estado, modificado_en) values ('f8700000-0000-5000-8000-000000000001', '2026-11-21', 'hecha', now());
  insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
    values ('f8800000-0000-4000-8000-000000000001', 'Lista de ejemplo', 'bicicleta', 'otra', 'https://musica.ejemplo.test/lista/1', 1, now());
end
$$;
grant execute on function pruebas.sembrar_bici() to authenticated;

select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_bici();

-- ---------------------------------------------------------------- lo que pone el servidor
select pruebas.como_postgres();
select pruebas.igual((select p.persona_id || '/' || p.hogar_id from public.hab_bici_perfil p),
  pruebas.id_persona('ana@ejemplo.test') || '/b0000000-0000-4000-8000-000000000001', 'El servidor pone persona y hogar del perfil');
select pruebas.igual((select count(*)::int from public.hab_bici_salidas s
   where s.persona_id = pruebas.id_persona('ana@ejemplo.test') and s.hogar_id = 'b0000000-0000-4000-8000-000000000001'
     and s.actualizado_en = now()), 1, '… de la salida, con actualizado_en del servidor');
select pruebas.igual((select count(*)::int from public.hab_bici_bicicletas s
   where s.persona_id = pruebas.id_persona('ana@ejemplo.test') and s.hogar_id = 'b0000000-0000-4000-8000-000000000001'), 1, '… de la bicicleta');
select pruebas.igual((select count(*)::int from public.hab_bici_mantenimientos s
   where s.persona_id = pruebas.id_persona('ana@ejemplo.test') and s.hogar_id = 'b0000000-0000-4000-8000-000000000001'), 1, '… del mantenimiento');
select pruebas.igual((select count(*)::int from public.hab_musica_listas s
   where s.persona_id = pruebas.id_persona('ana@ejemplo.test') and s.hogar_id = 'b0000000-0000-4000-8000-000000000001'), 1, '… y de la lista de música');
select pruebas.ok(
  (select bool_and(not has_column_privilege('authenticated', format('public.%I', t.t), c.c, p.p))
     from unnest(array['hab_bici_bicicletas', 'hab_bici_perfil', 'hab_bici_mantenimientos', 'hab_bici_salidas', 'hab_musica_listas']) t(t),
          unnest(array['persona_id', 'hogar_id', 'actualizado_en']) c(c),
          unnest(array['INSERT', 'UPDATE']) p(p)),
  'En ninguna de las cinco la app puede mandar ni cambiar persona_id, hogar_id ni actualizado_en');
select pruebas.ok(not has_table_privilege('authenticated', 'public.hab_bici_salidas', 'INSERT')
  and not has_table_privilege('authenticated', 'public.hab_bici_perfil', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.hab_musica_listas', 'INSERT')
  and not has_table_privilege('authenticated', 'public.hab_bici_salidas', 'TRUNCATE'),
  'Los privilegios son por columna (sin INSERT ni UPDATE de tabla completa, sin TRUNCATE)');

-- Valores por omisión
select pruebas.igual((select duracion_prevista_min || '/' || margen_revision_min || '/' || carga_piernas || '/' || tope_aumento_pct
    || '/' || preparacion::text || '/' || coalesce(intervalo_agua_min::text, 'nulo') || '/' || coalesce(intervalo_comida_min::text, 'nulo')
    || '/' || coalesce(aviso_visto_en::text, 'nulo') || '/' || coalesce(bicicleta_activa_id::text, 'nulo')
  from public.hab_bici_perfil), '240/90/normal/20/[]/nulo/nulo/nulo/nulo', 'Perfil: valores por omisión de la especificación (el agua y la comida, vacíos)');
select pruebas.igual((select coalesce(tipo, 'nulo') || '/' || odometro_inicial_m || '/' || coalesce(intervalos::text, 'nulo') || '/' || activa
  from public.hab_bici_bicicletas), 'nulo/0/nulo/true', 'Bicicleta: sin tipo supuesto, odómetro inicial 0, intervalos iniciales y activa');
select pruebas.igual((select n || '/' || acompanado || '/' || coalesce(distancia_m::text, 'nulo') || '/' || coalesce(motivo, 'nulo') from public.hab_bici_salidas),
  '1/false/nulo/nulo', 'Salida: número 1, sin acompañante y sin cifras inventadas');

-- ---------------------------------------------------------------- perfil
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.hab_bici_perfil set duracion_prevista_min = 29$$, 'duracion_prevista_min 29 se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set duracion_prevista_min = 721$$, 'duracion_prevista_min 721 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set duracion_prevista_min = 30$$) + pruebas.afecta($$update public.hab_bici_perfil set duracion_prevista_min = 720$$), 2,
  'duracion_prevista_min de 30 a 720');
select pruebas.falla($$update public.hab_bici_perfil set duracion_prevista_min = null$$, 'duracion_prevista_min obligatoria', '23502');
select pruebas.falla($$update public.hab_bici_perfil set margen_revision_min = -1$$, 'margen_revision_min negativo se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set margen_revision_min = 241$$, 'margen_revision_min 241 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set margen_revision_min = 0$$) + pruebas.afecta($$update public.hab_bici_perfil set margen_revision_min = 240$$), 2,
  'margen_revision_min de 0 a 240');
select pruebas.falla($$update public.hab_bici_perfil set carga_piernas = 'alta'$$, 'carga_piernas solo normal, ligera o por_esfuerzo', '23514');
select pruebas.falla($$update public.hab_bici_perfil set carga_piernas = null$$, 'carga_piernas obligatoria', '23502');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set carga_piernas = 'ligera'$$) + pruebas.afecta($$update public.hab_bici_perfil set carga_piernas = 'por_esfuerzo'$$)
  + pruebas.afecta($$update public.hab_bici_perfil set carga_piernas = 'normal'$$), 3, 'Las tres cargas de piernas entran');
select pruebas.falla($$update public.hab_bici_perfil set tope_aumento_pct = 4$$, 'tope_aumento_pct 4 se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set tope_aumento_pct = 51$$, 'tope_aumento_pct 51 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set tope_aumento_pct = 5$$) + pruebas.afecta($$update public.hab_bici_perfil set tope_aumento_pct = 50$$), 2,
  'tope_aumento_pct de 5 a 50');
select pruebas.falla($$update public.hab_bici_perfil set intervalo_agua_min = 9$$, 'intervalo_agua_min 9 se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set intervalo_agua_min = 121$$, 'intervalo_agua_min 121 se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set intervalo_comida_min = 0$$, 'intervalo_comida_min 0 se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_perfil set intervalo_comida_min = 121$$, 'intervalo_comida_min 121 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set intervalo_agua_min = 10, intervalo_comida_min = 120$$)
  + pruebas.afecta($$update public.hab_bici_perfil set intervalo_agua_min = 120, intervalo_comida_min = 10$$)
  + pruebas.afecta($$update public.hab_bici_perfil set intervalo_agua_min = null, intervalo_comida_min = null$$), 3, 'Agua y comida: de 10 a 120 o nulos');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set aviso_visto_en = now()$$), 1, 'aviso_visto_en entra');
select pruebas.falla($$update public.hab_bici_perfil set modificado_en = null$$, 'modificado_en obligatorio', '23502');
select pruebas.falla($$update public.hab_bici_perfil set bicicleta_activa_id = gen_random_uuid()$$, 'La bicicleta activa existe (llave compuesta)', '23503');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set bicicleta_activa_id = 'f8500000-0000-4000-8000-000000000001'$$), 1, '… y una propia sí entra');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set bicicleta_activa_id = null$$), 1, '… o ninguna');

-- preparacion: puntos del catálogo {id, activo} y hasta 10 propios {texto}
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '{"id": "luces_cargadas", "activo": true}'$$, 'La preparación es una lista', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '["luces_cargadas"]'$$, 'Cada punto es un objeto', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{}]'$$, 'Un punto vacío no entra (lleva id o texto)', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"activo": true}]'$$, '… ni uno sin id ni texto', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"id": "Luces Cargadas", "activo": true}]'$$, 'El id es una ficha corta (sin mayúsculas ni espacios)', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"id": "luces_cargadas"}]'$$, 'Un punto del catálogo dice si está activo', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"id": "luces_cargadas", "activo": "si"}]'$$, '… con sí o no, no con un texto', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"id": "luces_cargadas", "activo": true, "nota": "x"}]'$$, 'Un punto del catálogo no admite otras claves', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"id": "luces_cargadas", "activo": true, "texto": "x"}]'$$, '… ni mezclar id y texto', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"texto": ""}]'$$, 'Un punto propio no está vacío', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"texto": "   "}]'$$, '… ni solo espacios', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = jsonb_build_array(jsonb_build_object('texto', repeat('t', 61)))$$, 'Un punto propio de 61 caracteres', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = jsonb_build_array(jsonb_build_object('texto', E'a\nb'))$$, 'Un punto propio sin saltos de línea ni caracteres de control', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"texto": 5}]'$$, 'El texto propio es un texto', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"texto": "x", "activo": "no"}]'$$, 'activo de un punto propio es sí o no', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = '[{"texto": "x", "ruta": "calle"}]'$$, 'Un punto propio no admite otras claves (ni ruta)', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = (select jsonb_agg(jsonb_build_object('texto', 'p' || g)) from generate_series(1, 11) g)$$,
  'Once puntos propios se rechazan (hasta 10)', '23514');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = (select jsonb_agg(jsonb_build_object('id', 'punto_' || g, 'activo', true)) from generate_series(1, 41) g)$$,
  'Más de 40 puntos', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set preparacion = (select jsonb_agg(jsonb_build_object('texto', 'Punto propio ' || g, 'activo', g % 2 = 0)) from generate_series(1, 10) g)$$), 1,
  'Diez puntos propios entran');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set preparacion = (select jsonb_agg(jsonb_build_object('id', 'punto_' || g, 'activo', g % 2 = 0)) from generate_series(1, 40) g)$$), 1,
  'Cuarenta puntos del catálogo entran');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set preparacion =
  '[{"id": "bici_revisada", "activo": true}, {"id": "protector_solar", "activo": false}, {"texto": "Llevar mi gorra (ejemplo)"}, {"texto": "Cargar el reloj", "activo": true}]'$$), 1,
  'Una preparación válida mezcla catálogo y propios');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set preparacion = '[]'$$), 1, '… y vacía');
select pruebas.falla($$update public.hab_bici_perfil set preparacion = null$$, 'La preparación no es nula', '23502');

-- ---------------------------------------------------------------- bicicletas
select pruebas.falla($$update public.hab_bici_bicicletas set nombre = '   '$$, 'nombre vacío', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set nombre = repeat('b', 41)$$, 'nombre de 41 caracteres', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set nombre = null$$, 'nombre obligatorio', '23502');
select pruebas.falla($$update public.hab_bici_bicicletas set tipo = 'bmx'$$, 'tipo fuera de la lista', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set tipo = 'montana'$$) + pruebas.afecta($$update public.hab_bici_bicicletas set tipo = 'ruta'$$)
  + pruebas.afecta($$update public.hab_bici_bicicletas set tipo = 'gravel'$$) + pruebas.afecta($$update public.hab_bici_bicicletas set tipo = 'urbana'$$)
  + pruebas.afecta($$update public.hab_bici_bicicletas set tipo = 'otra'$$) + pruebas.afecta($$update public.hab_bici_bicicletas set tipo = null$$), 6,
  'Los cinco tipos y «ninguno» entran');
select pruebas.falla($$update public.hab_bici_bicicletas set odometro_inicial_m = -1$$, 'odometro_inicial_m negativo', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set odometro_inicial_m = 200000001$$, 'odometro_inicial_m de más de 200 000 km', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set odometro_inicial_m = null$$, 'odometro_inicial_m obligatorio', '23502');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set odometro_inicial_m = 0$$) + pruebas.afecta($$update public.hab_bici_bicicletas set odometro_inicial_m = 200000000$$), 2,
  'odometro_inicial_m de 0 a 200 000 000 m');
select pruebas.falla($$update public.hab_bici_bicicletas set activa = null$$, 'activa obligatoria', '23502');
-- intervalos
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '[]'$$, 'Los intervalos son un objeto', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '"cada 150 km"'$$, '… no un texto', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"cambiar_llantas": {"km": 100}}'$$, 'Una tarea fuera del catálogo se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lectura_odometro": {"km": 100}}'$$, '… también lectura_odometro (no tiene intervalo)', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": 150}'$$, 'El intervalo de una tarea es un objeto', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": null}'$$, '… no nulo (una tarea ausente usa el valor inicial)', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"millas": 90}}'$$, 'Solo km y semanas', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"km": 0}}'$$, 'Un intervalo de 0 km se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"km": -5}}'$$, '… ni uno negativo', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"km": 150.5}}'$$, '… ni con decimales', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"km": "150"}}'$$, '… ni como texto', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"km": 100001}}'$$, 'km de más de 100 000', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"semanas": 0}}'$$, 'semanas 0', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = '{"lubricar_cadena": {"semanas": 521}}'$$, 'semanas 521', '23514');
select pruebas.falla($$update public.hab_bici_bicicletas set intervalos = jsonb_build_object('lubricar_cadena', jsonb_build_object('km', 150, 'semanas', 4, 'nota', repeat('x', 1100)))$$,
  'Más de 1 KB', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set intervalos =
  '{"lubricar_cadena": {"km": 150, "semanas": 4}, "limpiar_transmision": {"km": null, "semanas": null}, "revisar_frenos_llantas": {"km": 300}, "revision_general": {"km": 2000, "semanas": 26}}'$$), 1,
  'Intervalos válidos entran (con una parte nula, ausente o los dos nulos: la tarea queda desactivada)');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set intervalos = '{}'$$), 1, '… y vacíos');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set intervalos = null$$), 1, '… o nulos (los valores iniciales)');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set intervalos = '{"revision_general": {"km": 100000, "semanas": 520}}'$$), 1, 'Los máximos entran');

-- ---------------------------------------------------------------- mantenimientos
select pruebas.falla($$update public.hab_bici_mantenimientos set tarea = 'cambiar_llantas'$$, 'tarea fuera de la lista', '23514');
select pruebas.falla($$update public.hab_bici_mantenimientos set tarea = null$$, 'tarea obligatoria', '23502');
select pruebas.falla($$update public.hab_bici_mantenimientos set fecha = null$$, 'fecha obligatoria', '23502');
select pruebas.falla($$update public.hab_bici_mantenimientos set tarea = 'lectura_odometro'$$, 'Una lectura del odómetro sin odometro_m se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_mantenimientos set tarea = 'lectura_odometro', odometro_m = null$$, '… aunque se mande nulo', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_mantenimientos set tarea = 'lectura_odometro', odometro_m = 480000$$), 1, '… con la cifra sí entra');
select pruebas.falla($$update public.hab_bici_mantenimientos set odometro_m = -1$$, 'odometro_m negativo se rechaza', '23514');
select pruebas.falla($$update public.hab_bici_mantenimientos set odometro_m = 200000001$$, 'odometro_m de más de 200 000 km', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_mantenimientos set odometro_m = 0$$) + pruebas.afecta($$update public.hab_bici_mantenimientos set odometro_m = 200000000$$), 2,
  'odometro_m de 0 a 200 000 000');
select pruebas.falla($$update public.hab_bici_mantenimientos set tarea = 'otra', odometro_m = null, nota = repeat('n', 121)$$, 'nota de más de 120 caracteres', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_mantenimientos set tarea = 'lubricar_cadena', odometro_m = null, nota = repeat('n', 120)$$), 1,
  'nota de 120 caracteres y odometro_m nulo en una tarea que no es lectura');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  select gen_random_uuid(), 'f8500000-0000-4000-8000-000000000001', t, '2026-11-15', now()
  from unnest(array['limpiar_transmision', 'revisar_frenos_llantas', 'revision_general', 'otra']) t$$), 4, 'Las demás tareas entran');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values (gen_random_uuid(), 'f8500000-0000-4000-8000-000000000001', 'lubricar_cadena', '2026-11-14', now())$$,
  'La misma tarea de la misma bicicleta el mismo día, una sola vez (aunque venga con otro id)', '23505');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, tarea, fecha, modificado_en)
  values (gen_random_uuid(), 'otra', '2026-11-16', now())$$, 'bicicleta_id obligatoria', '23502');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values (gen_random_uuid(), gen_random_uuid(), 'otra', '2026-11-16', now())$$, 'Un mantenimiento sin bicicleta no entra', '23503');

-- ---------------------------------------------------------------- salidas
select pruebas.falla($$update public.hab_bici_salidas set esfuerzo = 0$$, 'esfuerzo 0', '23514');
select pruebas.falla($$update public.hab_bici_salidas set esfuerzo = 6$$, 'esfuerzo 6', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 1$$) + pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 5$$)
  + pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = null$$), 3, 'esfuerzo de 1 a 5 o nulo');
select pruebas.falla($$update public.hab_bici_salidas set distancia_m = -1$$, 'distancia_m negativa', '23514');
select pruebas.falla($$update public.hab_bici_salidas set distancia_m = 1000001$$, 'distancia_m de más de 1 000 km', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set distancia_m = 0$$) + pruebas.afecta($$update public.hab_bici_salidas set distancia_m = 1000000$$)
  + pruebas.afecta($$update public.hab_bici_salidas set distancia_m = null$$), 3, 'distancia_m de 0 a 1 000 000 o nula');
select pruebas.falla($$update public.hab_bici_salidas set duracion_min = 0$$, 'duracion_min 0', '23514');
select pruebas.falla($$update public.hab_bici_salidas set duracion_min = 1441$$, 'duracion_min 1441', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set duracion_min = 1$$) + pruebas.afecta($$update public.hab_bici_salidas set duracion_min = 1440$$)
  + pruebas.afecta($$update public.hab_bici_salidas set duracion_min = null$$), 3, 'duracion_min de 1 a 1 440 o nula');
select pruebas.falla($$update public.hab_bici_salidas set desnivel_m = -1$$, 'desnivel_m negativo', '23514');
select pruebas.falla($$update public.hab_bici_salidas set desnivel_m = 20001$$, 'desnivel_m 20001', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set desnivel_m = 0$$) + pruebas.afecta($$update public.hab_bici_salidas set desnivel_m = 20000$$), 2,
  'desnivel_m de 0 a 20 000');
select pruebas.falla($$update public.hab_bici_salidas set n = 0$$, 'n 0', '23514');
select pruebas.falla($$update public.hab_bici_salidas set n = 4$$, 'n 4', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set n = 3$$) + pruebas.afecta($$update public.hab_bici_salidas set n = 1$$), 2, 'n de 1 a 3');
select pruebas.falla($$update public.hab_bici_salidas set superficie = 'asfalto'$$, 'superficie fuera de calle, terreno y mixta', '23514');
select pruebas.falla($$update public.hab_bici_salidas set superficie = 'ciclovia'$$, '… ciclovia es de un tramo de ruta, no de la salida', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set superficie = 'calle'$$) + pruebas.afecta($$update public.hab_bici_salidas set superficie = 'terreno'$$)
  + pruebas.afecta($$update public.hab_bici_salidas set superficie = 'mixta'$$) + pruebas.afecta($$update public.hab_bici_salidas set superficie = null$$), 4,
  'Las tres superficies y «ninguna» entran');
select pruebas.falla($$update public.hab_bici_salidas set clima = 'tormenta'$$, 'clima fuera de la lista', '23514');
select pruebas.igual((select sum(pruebas.afecta(format('update public.hab_bici_salidas set clima = %L', c)))::int
  from unnest(array['despejado', 'nublado', 'lluvia', 'calor', 'frio']) c), 5, 'Los cinco climas entran');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set clima = null$$), 1, '… y ninguno');
select pruebas.falla($$update public.hab_bici_salidas set estado = 'terminada'$$, 'estado fuera de hecha, parcial y omitida', '23514');
select pruebas.falla($$update public.hab_bici_salidas set estado = null$$, 'estado obligatorio', '23502');
select pruebas.falla($$update public.hab_bici_salidas set fecha = null$$, 'fecha obligatoria', '23502');
select pruebas.falla($$update public.hab_bici_salidas set acompanado = null$$, 'acompanado obligatorio (sí o no, sin identificar a nadie)', '23502');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set estado = 'parcial', acompanado = true, inicio = '08:00'$$), 1, 'parcial, acompañado y con hora de inicio entran');
select pruebas.falla($$update public.hab_bici_salidas set motivo = 'miedo', estado = 'omitida'$$, 'motivo fuera de clima, seguridad y otra', '23514');
select pruebas.falla($$update public.hab_bici_salidas set motivo = 'clima'$$, 'Un motivo solo acompaña a una salida omitida (parcial con motivo, no)', '23514');
select pruebas.falla($$update public.hab_bici_salidas set estado = 'hecha', motivo = 'seguridad'$$, '… tampoco una hecha', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set estado = 'omitida', motivo = null$$)
  + pruebas.afecta($$update public.hab_bici_salidas set estado = 'omitida', motivo = 'clima'$$)
  + pruebas.afecta($$update public.hab_bici_salidas set estado = 'omitida', motivo = 'seguridad'$$)
  + pruebas.afecta($$update public.hab_bici_salidas set estado = 'omitida', motivo = 'otra'$$), 4, 'Omitida con clima, seguridad, otra o sin motivo entra');
select pruebas.falla($$update public.hab_bici_salidas set estado = 'hecha'$$, 'Pasar a hecha sin quitar el motivo se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set estado = 'hecha', motivo = null$$), 1, '… quitándolo entra');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values (gen_random_uuid(), '2026-11-21', 1, 'hecha', now())$$, 'Un día y un número, una sola salida (aunque venga con otro id)', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000b2', '2026-11-21', 2, 'hecha', now()), ('f8700000-0000-5000-8000-0000000000b3', '2026-11-21', 3, 'parcial', now())$$), 2,
  'Una segunda y una tercera salida el mismo día entran');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values (gen_random_uuid(), '2026-11-21', 4, 'hecha', now())$$, 'Una cuarta no', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, bloque_id, bicicleta_id, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000b4', '2026-11-28', 1, 'f5100000-0000-4000-8000-000000000001', 'f8500000-0000-4000-8000-000000000001', 'hecha', now())$$), 1,
  'Una salida cuelga de su propio bloque de Hábitos y de su propia bicicleta');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, bicicleta_id, estado, modificado_en)
  values (gen_random_uuid(), '2026-12-05', gen_random_uuid(), 'hecha', now())$$, 'Una bicicleta que no existe, no', '23503');

-- ---------------------------------------------------------------- listas de música (el detalle está en 135)
select pruebas.falla($$update public.hab_musica_listas set enlace = 'http://musica.ejemplo.test/lista/1'$$, 'El enlace de música es https (http sin cifrar, no)', '23514');
select pruebas.falla($$update public.hab_musica_listas set actividad = 'yoga'$$, 'actividad fuera de la lista', '23514');
select pruebas.falla($$update public.hab_musica_listas set app = 'radio'$$, 'app fuera de la lista', '23514');

-- ---------------------------------------------------------------- último gana (modificado_en), en las cinco
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 2, modificado_en = now() + interval '1 minute'
  where id = 'f8700000-0000-5000-8000-000000000001'$$), 1, 'Un cambio más nuevo gana');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 4, modificado_en = now() - interval '1 hour'
  where id = 'f8700000-0000-5000-8000-000000000001'$$), 0, 'Uno más viejo se ignora, sin error (0 filas)');
select pruebas.igual((select esfuerzo from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'), 2::smallint, '… y queda el más reciente');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_perfil set carga_piernas = 'ligera', modificado_en = now() - interval '1 hour'$$), 0, 'Lo mismo en el perfil');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set nombre = 'Vieja', modificado_en = now() - interval '1 hour'$$), 0, '… en las bicicletas');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_mantenimientos set nota = 'vieja', modificado_en = now() - interval '1 hour'$$), 0, '… en los mantenimientos');
select pruebas.igual(pruebas.afecta($$update public.hab_musica_listas set nombre = 'Vieja', modificado_en = now() - interval '1 hour'$$), 0, '… y en las listas de música');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 3, modificado_en = now() + interval '2 days'
  where id = 'f8700000-0000-5000-8000-000000000001'$$), 1, 'Uno del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-000000000001'),
  '… ajustado a la hora del servidor (tope de 5 minutos)');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_bicicletas set nombre = 'Futura', modificado_en = now() + interval '30 days'$$), 1, 'Lo mismo en una bicicleta…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_bici_bicicletas), '… ajustada');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-0000000000f1', 'Futura', 'fuerza', 'otra', 'https://musica.ejemplo.test/lista/f', 2, now() + interval '10 days')$$), 1,
  'Una fila nueva con fecha del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_musica_listas where id = 'f8800000-0000-4000-8000-0000000000f1'), '… también ajustada');
select pruebas.falla($$update public.hab_bici_salidas set persona_id = pruebas.id_persona('alex@ejemplo.test')$$, 'La persona de una salida no cambia', '42501');
select pruebas.falla($$update public.hab_bici_salidas set actualizado_en = now() + interval '1 year'$$, 'actualizado_en es del servidor', '42501');

rollback;
