-- Entrenamiento (Fase 8, G2, CA-G-27): esquema y rangos de las seis tablas hab_ent_*; lo que pone el servidor;
-- el último cambio gana; y el motivo «molestia» no existe (PG-19).
begin;

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
grant execute on function pruebas.sembrar_ent(integer) to authenticated;

select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_ent(1);

-- ---------------------------------------------------------------- lo que pone el servidor
select pruebas.como_postgres();
select pruebas.igual((select p.persona_id || '/' || p.hogar_id from public.hab_ent_perfil p),
  pruebas.id_persona('ana@ejemplo.test') || '/b0000000-0000-4000-8000-000000000001', 'El servidor pone persona y hogar del perfil');
select pruebas.igual((select count(*)::int from public.hab_ent_sesiones s
   where s.persona_id = pruebas.id_persona('ana@ejemplo.test') and s.hogar_id = 'b0000000-0000-4000-8000-000000000001'
     and s.actualizado_en = now()), 1, '… de la sesión, con actualizado_en del servidor');
select pruebas.igual((select count(*)::int from public.hab_ent_series s
   where s.persona_id = pruebas.id_persona('ana@ejemplo.test') and s.hogar_id = 'b0000000-0000-4000-8000-000000000001'), 1, '… y de la serie');
select pruebas.ok(
  (select bool_and(not has_column_privilege('authenticated', format('public.%I', t.t), c.c, p.p))
     from unnest(array['hab_ent_perfil', 'hab_ent_plan_dias', 'hab_ent_inventario', 'hab_ent_bandas', 'hab_ent_sesiones', 'hab_ent_series']) t(t),
          unnest(array['persona_id', 'hogar_id', 'actualizado_en']) c(c),
          unnest(array['INSERT', 'UPDATE']) p(p)),
  'En ninguna de las seis la app puede mandar ni cambiar persona_id, hogar_id ni actualizado_en');
select pruebas.ok(not has_table_privilege('authenticated', 'public.hab_ent_series', 'INSERT')
  and not has_table_privilege('authenticated', 'public.hab_ent_sesiones', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.hab_ent_perfil', 'TRUNCATE'),
  'Los privilegios son por columna (sin INSERT ni UPDATE de tabla completa, sin TRUNCATE)');

-- Valores por omisión del perfil
select pruebas.igual((select dias_plan || '/' || version_pref || '/' || ventana || '/' || noche_desde || '/' || objetivo || '/' || nivel
    || '/' || ciclo_semanas || '/' || margen_dormir_min || '/' || voz_descanso || '/' || coalesce(inicio_ciclo::text, 'nulo')
    || '/' || coalesce(descanso_s::text, 'nulo') || '/' || coalesce(prueba_desde::text, 'nulo') || '/' || coalesce(aviso_visto_en::text, 'nulo')
  from public.hab_ent_perfil),
  '3/auto/noche/19:00:00/salud_general/principiante/4/90/false/nulo/nulo/nulo/nulo', 'Perfil: valores por omisión de la especificación');
select pruebas.igual((select version from public.hab_ent_plan_dias), 'auto', 'Plan: la versión nace en auto');
select pruebas.igual((select activa::text || '/' || coalesce(resistencia_kg_x10::text, 'nulo') from public.hab_ent_bandas), 'true/nulo', 'Banda: activa y sin resistencia leída');

-- ---------------------------------------------------------------- perfil
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.hab_ent_perfil set dias_plan = 2$$, 'dias_plan 2 se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set dias_plan = 6$$, 'dias_plan 6 se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set dias_plan = 0$$, 'dias_plan 0 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set dias_plan = 4$$), 1, 'dias_plan 4 entra');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set dias_plan = 5$$), 1, 'dias_plan 5 entra');
select pruebas.falla($$update public.hab_ent_perfil set version_pref = 'mini'$$, 'version_pref solo auto, corta, estandar o larga', '23514');
select pruebas.falla($$update public.hab_ent_perfil set ventana = 'tarde'$$, 'ventana solo manana, noche o flexible', '23514');
select pruebas.falla($$update public.hab_ent_perfil set objetivo = 'bajar_peso'$$, 'objetivo fuera de la lista', '23514');
select pruebas.falla($$update public.hab_ent_perfil set nivel = 'avanzado'$$, 'nivel solo principiante o intermedio', '23514');
select pruebas.falla($$update public.hab_ent_perfil set inicio_ciclo = '2026-11-24'$$, 'inicio_ciclo un martes se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set inicio_ciclo = '2026-11-22'$$, 'inicio_ciclo un domingo se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set inicio_ciclo = '2026-11-23'$$), 1, 'inicio_ciclo un lunes entra');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set inicio_ciclo = null$$), 1, '… y nulo (el plan aún no empieza)');
select pruebas.falla($$update public.hab_ent_perfil set ciclo_semanas = 1$$, 'ciclo_semanas 1 se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set ciclo_semanas = 2$$, 'ciclo_semanas 2 se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set ciclo_semanas = 9$$, 'ciclo_semanas 9 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set ciclo_semanas = 0$$), 1, 'ciclo_semanas 0 (sin descarga programada) entra');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set ciclo_semanas = 3$$) + pruebas.afecta($$update public.hab_ent_perfil set ciclo_semanas = 8$$), 2,
  '… y de 3 a 8');
select pruebas.falla($$update public.hab_ent_perfil set descanso_s = 29$$, 'descanso_s 29 se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set descanso_s = 121$$, 'descanso_s 121 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set descanso_s = 30$$) + pruebas.afecta($$update public.hab_ent_perfil set descanso_s = 120$$)
  + pruebas.afecta($$update public.hab_ent_perfil set descanso_s = null$$), 3, 'descanso_s de 30 a 120 o nulo');
select pruebas.falla($$update public.hab_ent_perfil set margen_dormir_min = -1$$, 'margen_dormir_min negativo se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_perfil set margen_dormir_min = 241$$, 'margen_dormir_min 241 se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set margen_dormir_min = 0$$) + pruebas.afecta($$update public.hab_ent_perfil set margen_dormir_min = 240$$), 2,
  'margen_dormir_min de 0 a 240');
select pruebas.falla($$update public.hab_ent_perfil set prueba_desde = '2026-11-23'$$, 'Una prueba de ventana lleva su ventana', '23514');
select pruebas.falla($$update public.hab_ent_perfil set prueba_ventana = 'manana'$$, '… y su fecha', '23514');
select pruebas.falla($$update public.hab_ent_perfil set prueba_desde = '2026-11-23', prueba_ventana = 'flexible'$$, 'La ventana en prueba es manana o noche', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set prueba_desde = '2026-11-23', prueba_ventana = 'manana', voz_descanso = true,
  aviso_visto_en = now()$$), 1, 'Fecha y ventana de la prueba, voz y aviso visto entran');
select pruebas.falla($$update public.hab_ent_perfil set noche_desde = null$$, 'noche_desde obligatorio', '23502');

-- ---------------------------------------------------------------- plan semanal
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (0, 'A', now())$$, 'dia_semana 0 se rechaza', '23514');
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (8, 'A', now())$$, 'dia_semana 8 se rechaza', '23514');
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (2, 'D', now())$$, 'tipo fuera de A, B, C, R1, R2, bici y descanso', '23514');
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, version, modificado_en) values (2, 'B', 'enorme', now())$$, 'version fuera de la lista', '23514');
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (1, 'B', now())$$, 'Un solo registro por día de la semana', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_plan_dias (dia_semana, tipo, version, hora, modificado_en)
  select g, (array['A', 'B', 'C', 'R1', 'R2', 'bici', 'descanso'])[g], 'larga', '19:30', now() from generate_series(2, 7) g$$), 6, 'Los siete días con sus siete tipos entran');

-- ---------------------------------------------------------------- inventario
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('', 'disponible', now())$$, 'item_id vacío', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values (repeat('a', 61), 'disponible', now())$$, 'item_id de 61 caracteres', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('Marcy Press', 'disponible', now())$$,
  'item_id solo ids de catálogo (sin mayúsculas ni espacios)', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_inventario (item_id, estado, modificado_en)
  values ('otro:remo en polea', 'disponible', now()), ('banco_inclinado', 'no_disponible', now()), ('ancla_puerta', 'futuro', now())$$), 3,
  'Un puesto suelto (otro:<texto corto>) y ids del catálogo entran, en los tres estados');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('colchoneta', 'roto', now())$$, 'estado fuera de la lista', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, notas, modificado_en) values ('colchoneta', 'disponible', repeat('n', 201), now())$$,
  'notas de más de 200 caracteres', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en) values ('colchoneta', 'disponible', '[]', now())$$,
  'confirmado es un objeto', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('colchoneta', 'disponible', jsonb_build_object('pasos_max', repeat('1', 2100)), now())$$, 'confirmado de más de 2 KB', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_inventario (item_id, estado, confirmado, notas, modificado_en)
  values ('marcy.polea_alta', 'disponible', '{"pasos_max": 10, "kg_por_paso_x10": 68, "relacion_polea": "2:1", "capacidad_banco_kg": 120, "ancla": true, "fecha": "2026-11-23"}',
          'Confirmado en la primera sesión', now())$$), 1, 'Lo confirmado del aparato entra (números, sí o no y fichas cortas)');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', '{"molestia_rodilla": true}', now())$$, 'Un campo de molestia en lo confirmado se rechaza', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', '{"zona": "rodilla"}', now())$$, '… también una zona', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', '{"dolor_hombro": 2}', now())$$, '… o un dolor', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', '{"Pasos": 10}', now())$$, 'Los campos van en minúsculas', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', '{"nota": "me duele la rodilla al empujar"}', now())$$, 'Una frase no es un valor confirmado', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', '{"pasos": {"max": 10}}', now())$$, 'Sin objetos anidados', '23514');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, confirmado, modificado_en)
  values ('marcy.polea_baja', 'disponible', (select jsonb_object_agg('campo' || g, 1) from generate_series(1, 21) g), now())$$,
  'Más de 20 campos', '23514');

-- ---------------------------------------------------------------- bandas
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), '   ', 1, 1, now())$$, 'nombre vacío', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), repeat('b', 41), 1, 1, now())$$, 'nombre de 41 caracteres', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'Roja', 0, 1, now())$$, 'orden 0', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'Roja', 21, 1, now())$$, 'orden 21', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'Roja', 2, 0, now())$$, 'cantidad 0', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'Roja', 2, 11, now())$$, 'cantidad 11', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, resistencia_kg_x10, modificado_en) values (gen_random_uuid(), 'Roja', 2, 1, 0, now())$$, 'resistencia 0', '23514');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, resistencia_kg_x10, modificado_en) values (gen_random_uuid(), 'Roja', 2, 1, 2001, now())$$, 'resistencia 2001', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, resistencia_kg_x10, activa, modificado_en)
  values (gen_random_uuid(), 'Roja', 2, 2, 150, false, now()), (gen_random_uuid(), 'Negra', 20, 10, 2000, true, now())$$), 2, 'Bandas válidas entran (con y sin resistencia leída)');

-- ---------------------------------------------------------------- sesiones
select pruebas.falla($$update public.hab_ent_sesiones set plantilla = 'D'$$, 'plantilla fuera de A, B, C, R1 y R2 (bici no es sesión)', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plantilla = 'bici'$$, '… tampoco bici', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set version = 'auto'$$, 'version de una sesión: corta, estandar o larga', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set semana_tipo = 'normal'$$, 'semana_tipo fuera de la lista', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set ventana = 'flexible'$$, 'ventana de una sesión: manana o noche', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set esfuerzo = 0$$, 'esfuerzo 0', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set esfuerzo = 6$$, 'esfuerzo 6', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set energia = 0$$, 'energia 0', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set energia = 6$$, 'energia 6', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 1, energia = 5$$) + pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 5, energia = 1$$)
  + pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = null, energia = null$$), 3, 'esfuerzo y energia de 1 a 5 o nulos');
select pruebas.falla($$update public.hab_ent_sesiones set estado = 'terminada'$$, 'estado fuera de en_curso, completa y parcial', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set estado = 'en_curso'$$, 'Una sesión en curso no tiene fin', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set estado = 'en_curso', fin = null$$), 1, '… y sin fin sí está en curso');
select pruebas.falla($$update public.hab_ent_sesiones set estado = 'parcial'$$, 'Una sesión terminada lleva fin', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set estado = 'parcial', fin = '2026-11-02 20:30-06'$$), 1, 'Terminada a medias (parcial) con su fin');
select pruebas.falla($$update public.hab_ent_sesiones set fin = '2026-11-02 19:00-06'$$, 'fin antes del inicio', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set catalogo_version = 0$$, 'catalogo_version 0', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set inicio = null$$, 'inicio obligatorio', '23502');
-- plan: lista de ejercicio, variante, series, reps_min, reps_max y nada más
select pruebas.falla($$update public.hab_ent_sesiones set plan = '{"ejercicio": "marcy.press"}'$$, 'El plan es una lista', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '["marcy.press"]'$$, 'Cada elemento del plan es un objeto', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"series": 3}]'$$, 'Cada elemento lleva el ejercicio', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "Press de pecho"}]'$$, 'El ejercicio es un id del catálogo, no una frase', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "molestia": "rodilla"}]'$$, 'Una clave molestia en el plan se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "zona": "hombro"}]'$$, '… o una zona', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "nota": "x"}]'$$, '… ni ninguna clave que no sea de la lista', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "series": 13}]'$$, 'series del plan: hasta 12', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "reps_max": 101}]'$$, 'reps del plan: hasta 100', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "reps_min": 12, "reps_max": 8}]'$$, 'reps_min no supera a reps_max', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "series": 2.5}]'$$, 'series enteras', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "series": "3"}]'$$, 'series es un número, no un texto', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = (select jsonb_agg(jsonb_build_object('ejercicio', 'e' || g)) from generate_series(1, 41) g)$$,
  'Más de 40 ejercicios en el plan', '23514');
select pruebas.falla($$update public.hab_ent_sesiones set plan = (select jsonb_agg(jsonb_build_object('ejercicio', 'ejercicio_largo_' || g, 'variante', 'variante_larga_' || g, 'series', 3, 'reps_min', 8, 'reps_max', 12))
  from generate_series(1, 40) g)$$, 'El plan de más de 2 KB se rechaza', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "variante": "press_sentado", "series": 3, "reps_min": 8, "reps_max": 12},
  {"ejercicio": "plancha", "variante": null, "series": 3, "reps_min": null, "reps_max": null}, {"ejercicio": "caminata_suave"}]'$$), 1,
  'Un plan válido entra (con variante nula, sin series o sin repeticiones)');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set plan = '[]'$$), 1, '… y vacío');
select pruebas.falla($$update public.hab_ent_sesiones set plan = null$$, 'El plan no es nulo', '23502');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000b1', '2026-11-03', 'A', 'corta', 'carga', 'noche', '2026-11-03 20:00-06', '2026-11-03 20:30-06', 'completa', 1, now())$$,
  'Un día y una plantilla, una sola sesión (aunque venga con otro id)', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000b2', '2026-11-03', 'R1', 'corta', 'descarga', 'manana', '2026-11-03 07:00-06', '2026-11-03 07:30-06', 'completa', 1, now()),
         ('f8100000-0000-5000-8000-0000000000b3', '2026-11-04', 'B', 'larga', 'reentrada', 'noche', '2026-11-04 20:00-06', '2026-11-04 21:00-06', 'completa', 1, now()),
         ('f8100000-0000-5000-8000-0000000000b4', '2026-11-05', 'C', 'estandar', 'foco', 'noche', '2026-11-05 20:00-06', null, 'en_curso', 1, now())$$), 3,
  'Otra plantilla el mismo día y los cuatro tipos de semana entran');

-- ---------------------------------------------------------------- series
select pruebas.falla($$update public.hab_ent_series set reps = 101$$, 'reps 101', '23514');
select pruebas.falla($$update public.hab_ent_series set reps = -1$$, 'reps negativas', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set reps = 0$$) + pruebas.afecta($$update public.hab_ent_series set reps = 100$$)
  + pruebas.afecta($$update public.hab_ent_series set reps = null, segundos = 45$$), 3, 'reps de 0 a 100 o nulas (con segundos para la plancha)');
select pruebas.falla($$update public.hab_ent_series set segundos = 901$$, 'segundos 901', '23514');
select pruebas.falla($$update public.hab_ent_series set segundos = -1$$, 'segundos negativos', '23514');
select pruebas.falla($$update public.hab_ent_series set carga_pasos = 61$$, 'carga_pasos 61', '23514');
select pruebas.falla($$update public.hab_ent_series set carga_pasos = -1$$, 'carga_pasos negativa', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set carga_pasos = 0$$) + pruebas.afecta($$update public.hab_ent_series set carga_pasos = 60$$), 2,
  'carga_pasos de 0 a 60');
select pruebas.falla($$update public.hab_ent_series set esfuerzo = 0$$, 'esfuerzo de la serie 0', '23514');
select pruebas.falla($$update public.hab_ent_series set esfuerzo = 6$$, 'esfuerzo de la serie 6', '23514');
select pruebas.falla($$update public.hab_ent_series set n = 0$$, 'n 0', '23514');
select pruebas.falla($$update public.hab_ent_series set n = 13$$, 'n 13', '23514');
select pruebas.falla($$update public.hab_ent_series set lado = 'centro'$$, 'lado solo izquierdo o derecho', '23514');
select pruebas.falla($$update public.hab_ent_series set descanso_real_s = 901$$, 'descanso_real_s 901', '23514');
select pruebas.falla($$update public.hab_ent_series set descanso_real_s = -1$$, 'descanso_real_s negativo', '23514');
select pruebas.falla($$update public.hab_ent_series set ejercicio_id = 'Press de pecho'$$, 'ejercicio_id es un id del catálogo (sin frases)', '23514');
select pruebas.falla($$update public.hab_ent_series set variante_id = ''$$, 'variante_id obligatoria', '23514');
select pruebas.falla($$update public.hab_ent_series set sustituye_a = 'me duele'$$, 'sustituye_a es un id del catálogo', '23514');
-- PG-19 (CA-G-27): el motivo «molestia» no existe
select pruebas.falla($$update public.hab_ent_series set sustituye_a = 'press_sentado', motivo_cambio = 'molestia'$$,
  'motivo_cambio = molestia se rechaza (el servidor solo ve no_disponible, preferencia u otra)', '23514');
select pruebas.falla($$update public.hab_ent_series set motivo_cambio = 'dolor'$$, '… ni dolor', '23514');
select pruebas.falla($$update public.hab_ent_series set motivo_cambio = 'lesion'$$, '… ni lesion', '23514');
select pruebas.falla($$update public.hab_ent_series set motivo_cambio = ''$$, '… ni vacío', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set sustituye_a = 'press_sentado', motivo_cambio = 'no_disponible'$$)
  + pruebas.afecta($$update public.hab_ent_series set motivo_cambio = 'preferencia'$$)
  + pruebas.afecta($$update public.hab_ent_series set motivo_cambio = 'otra'$$)
  + pruebas.afecta($$update public.hab_ent_series set sustituye_a = null, motivo_cambio = null$$), 4, 'no_disponible, preferencia, otra y nulo entran');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, lado, reps, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000c1', 'f8100000-0000-5000-8000-000000000001', 'subida_banco', 'con_banda', 1, 'izquierdo', 10, now()),
         ('f8300000-0000-5000-8000-0000000000c2', 'f8100000-0000-5000-8000-000000000001', 'subida_banco', 'con_banda', 1, 'derecho', 10, now()),
         ('f8300000-0000-5000-8000-0000000000c3', 'f8100000-0000-5000-8000-000000000001', 'subida_banco', 'con_banda', 2, 'izquierdo', 10, now())$$), 3,
  'La misma serie en cada lado y la siguiente entran');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, lado, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000c4', 'f8100000-0000-5000-8000-000000000001', 'subida_banco', 'con_banda', 1, 'izquierdo', now())$$,
  'Una serie (sesión, ejercicio, número y lado) una sola vez, aunque venga con otro id', '23505');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000c5', gen_random_uuid(), 'marcy.press', 'press_sentado', 1, now())$$, 'Una serie sin sesión no entra', '23503');

-- ---------------------------------------------------------------- último gana (modificado_en)
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 2, modificado_en = now() + interval '1 minute'
  where id = 'f8100000-0000-5000-8000-000000000001'$$), 1, 'Un cambio más nuevo gana');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 4, modificado_en = now() - interval '1 hour'
  where id = 'f8100000-0000-5000-8000-000000000001'$$), 0, 'Uno más viejo se ignora, sin error (0 filas)');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'), 2::smallint, '… y queda el más reciente');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set reps = 7, modificado_en = now() - interval '1 hour' where id = 'f8300000-0000-5000-8000-000000000001'$$), 0,
  'Lo mismo en las series');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_perfil set dias_plan = 3, modificado_en = now() - interval '1 hour'$$), 0, '… en el perfil');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_bandas set cantidad = 9, modificado_en = now() - interval '1 hour'$$), 0, '… en las bandas');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_inventario set estado = 'no_disponible', modificado_en = now() - interval '1 hour'$$), 0, '… en el inventario');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_plan_dias set tipo = 'C', modificado_en = now() - interval '1 hour'$$), 0, '… y en el plan');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 3, modificado_en = now() + interval '2 days'
  where id = 'f8100000-0000-5000-8000-000000000001'$$), 1, 'Uno del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'),
  '… ajustado a la hora del servidor (tope de 5 minutos)');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set reps = 8, modificado_en = now() + interval '30 days' where id = 'f8300000-0000-5000-8000-000000000001'$$), 1,
  'Lo mismo en una serie…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_ent_series where id = 'f8300000-0000-5000-8000-000000000001'), '… ajustada');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en)
  values ('f8200000-0000-4000-8000-0000000000f1', 'Futura', 3, 1, now() + interval '10 days')$$), 1, 'Una fila nueva con fecha del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_ent_bandas where id = 'f8200000-0000-4000-8000-0000000000f1'), '… también ajustada');
select pruebas.falla($$update public.hab_ent_series set persona_id = pruebas.id_persona('alex@ejemplo.test')$$, 'La persona de una serie no cambia', '42501');
select pruebas.falla($$update public.hab_ent_series set actualizado_en = now() + interval '1 year'$$, 'actualizado_en es del servidor', '42501');

rollback;
