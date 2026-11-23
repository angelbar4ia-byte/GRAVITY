-- Entrenamiento (Fase 8, G2, CA-G-29): borrar mis datos. El alcance «entrenamiento» y el alcance «todo» borran las
-- seis tablas hab_ent_*; la baja a los 90 días (D21) también; una tabla hab_* ausente de la lista falla la prueba (H-10).
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
-- Filas de entrenamiento de una persona (sin RLS: se corre como postgres).
create function pruebas.ent_de(p_correo text) returns integer
language sql stable
as $$
  select (select count(*) from public.hab_ent_perfil where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_ent_plan_dias where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_ent_inventario where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_ent_bandas where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_ent_sesiones where persona_id = pruebas.id_persona(p_correo))::int
       + (select count(*) from public.hab_ent_series where persona_id = pruebas.id_persona(p_correo))::int
$$;
grant execute on function pruebas.sembrar_ent(integer) to authenticated;

select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_ent(1);
select pruebas.como('alex@ejemplo.test');
select pruebas.sembrar_ent(2);
select pruebas.como('carla@ejemplo.test');
select pruebas.sembrar_ent(3);
select pruebas.como_postgres();
select pruebas.igual(pruebas.ent_de('ana@ejemplo.test'), 6, 'Ana tiene sus seis filas');

-- ---------------------------------------------------------------- alcance «entrenamiento»
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('molestias')$$, 'Un alcance desconocido se rechaza', '22023');
select public.hab_borrar_mis_datos('entrenamiento');
select pruebas.como_postgres();
select pruebas.igual(pruebas.ent_de('ana@ejemplo.test'), 0, 'hab_borrar_mis_datos(entrenamiento) borra las seis tablas de Ana');
select pruebas.igual(pruebas.ent_de('alex@ejemplo.test'), 6, '… y no toca lo de la pareja');
select pruebas.igual(pruebas.ent_de('carla@ejemplo.test'), 6, '… ni lo de la familiar');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 2,
  'Lo demás de Hábitos de Ana queda (objetivos)');
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
select pruebas.sembrar_ent(1);   -- vuelve a empezar de cero sin chocar con nada

-- ---------------------------------------------------------------- los alcances que no son de entrenamiento no lo tocan
select public.hab_borrar_mis_datos('sensibles');
select public.hab_borrar_mis_datos('diario');
select pruebas.como_postgres();
select pruebas.igual(pruebas.ent_de('ana@ejemplo.test'), 6, 'sensibles y diario no borran el entrenamiento');
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- alcance «todo»
select public.hab_borrar_mis_datos('todo');
select pruebas.como_postgres();
select pruebas.igual(pruebas.ent_de('ana@ejemplo.test'), 0, 'hab_borrar_mis_datos(todo) también borra las seis tablas');
select pruebas.igual((select count(*)::int from public.hab_objetivos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 0, '… y lo demás de Hábitos');
select pruebas.igual((select count(*)::int from public.hab_ajustes where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1, '… y deja los ajustes');
select pruebas.igual(pruebas.ent_de('alex@ejemplo.test'), 6, 'Lo de la pareja sigue intacto');

-- ---------------------------------------------------------------- quien no tiene Hábitos no borra
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('entrenamiento')$$, 'La cuenta maestra no borra', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('entrenamiento')$$, 'La cuidadora tampoco', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_mis_datos('entrenamiento')$$, 'ni Hogar', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.hab_borrar_mis_datos('entrenamiento')$$, 'ni anon', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.hab_borrar_datos_de(pruebas.id_persona('ana@ejemplo.test'), 'entrenamiento')$$,
  'Nadie llama a la función interna con la persona de otro', '42501');
select pruebas.como_postgres();
select pruebas.igual(pruebas.ent_de('alex@ejemplo.test'), 6, 'Nada de lo anterior tocó lo de Alex');

-- ---------------------------------------------------------------- la persona borra lo suyo, fila por fila, y las llaves se comportan
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_bandas$$), 1, 'Alex borra su banda…');
select pruebas.como_postgres();
select pruebas.igual((select banda_id from public.hab_ent_series where persona_id = pruebas.id_persona('alex@ejemplo.test')), null,
  '… y su serie queda sin banda (la serie y la persona siguen ahí)');
select pruebas.igual((select count(*)::int from public.hab_ent_series where persona_id = pruebas.id_persona('alex@ejemplo.test')), 1, '… la serie sigue');
select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_ent(7);
select pruebas.como_postgres();
insert into public.hab_bloques (id, hogar_id, persona_id, titulo, area, tipo, inicio, duracion_min, dias, desde, modificado_en)
  values ('f8400000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'),
          'Gimnasio (ejemplo)', 'salud', 'actividad', '19:00', 45, 127, '2026-11-02', now());
update public.hab_ent_sesiones set bloque_id = 'f8400000-0000-4000-8000-000000000001' where persona_id = pruebas.id_persona('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.hab_ent_sesiones where bloque_id = 'f8400000-0000-4000-8000-000000000001'), 1, 'Una sesión puede colgar de su bloque de Hábitos');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bloques where id = 'f8400000-0000-4000-8000-000000000001'$$), 1, 'Si Ana borra el bloque…');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.hab_ent_sesiones where persona_id = pruebas.id_persona('ana@ejemplo.test') and bloque_id is null), 1,
  '… la sesión se queda, sin bloque (no se borra ni falla)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_sesiones$$), 1, 'Si Ana borra una sesión…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_series$$), 0, '… sus series se van con ella (cascada)');

-- ---------------------------------------------------------------- la baja: se conserva sin acceso y se borra a los 90 días
select pruebas.como_postgres();
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('carla@ejemplo.test');
select pruebas.igual(pruebas.ent_de('carla@ejemplo.test'), 6, 'Quien se da de baja conserva sus datos…');
select pruebas.igual(public.hab_limpiar(now() + interval '89 days'), 0, 'A los 89 días no se borra nada');
select pruebas.igual(pruebas.ent_de('carla@ejemplo.test'), 6, '… sigue ahí');
select pruebas.ok(public.hab_limpiar(now() + interval '91 days') >= 1, 'A los 91 días se limpia a esa persona');
select pruebas.igual(pruebas.ent_de('carla@ejemplo.test'), 0, '… y el borrado incluye las seis tablas de entrenamiento');
select pruebas.igual(pruebas.ent_de('alex@ejemplo.test'), 5, 'Lo de quien sigue en el hogar no se toca (Alex: 5 filas, sin la banda que borró)');

-- ---------------------------------------------------------------- guardias (H-10): una tabla ausente de la lista falla la prueba
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_%'
      and position('public.' || c.relname in pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure)) = 0),
  '', 'Toda tabla hab_* (también las futuras) aparece en hab_borrar_datos_de');
select pruebas.ok(pg_get_functiondef('public.hab_borrar_datos_de(uuid, text)'::regprocedure) like '%''entrenamiento''%'
  and pg_get_functiondef('public.hab_borrar_mis_datos(text)'::regprocedure) like '%''entrenamiento''%',
  'El alcance entrenamiento existe en las dos funciones');

rollback;
