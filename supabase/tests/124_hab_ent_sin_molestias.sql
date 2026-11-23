-- Entrenamiento (Fase 8, G2, CA-G-28, PG-03 y PG-19): las molestias NO llegan al servidor. Viven solo en el
-- almacén local cifrado del dispositivo (tipo salud_local). El servidor no tiene dónde guardarlas.
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

-- ---------------------------------------------------------------- ninguna columna ni tabla de molestias
select pruebas.como_postgres();
select pruebas.igual(
  (select coalesce(string_agg(c.table_name || '.' || c.column_name, ', ' order by c.table_name, c.column_name), '')
     from information_schema.columns c
    where c.table_schema = 'public' and c.table_name like 'hab\_ent\_%'
      and c.column_name ~* '(molest|zona|dolor|duel|lesi|diagn|sintom|dolen|intensidad|fisio|medic|salud)'),
  '', 'Ninguna columna de hab_ent_* habla de molestia, zona, dolor, lesión, diagnóstico, síntoma ni salud');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm') and c.relname ~* '(molest|dolor|lesion|diagnos|sintoma)'),
  '', 'Ninguna tabla ni vista de public guarda molestias (ni con otro prefijo)');
select pruebas.igual(
  (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname ~* '(molest|dolor|lesion|diagnos|sintoma)'),
  '', 'Ninguna función de public las recibe');
-- Las columnas exactas de cada tabla: cualquier columna nueva rompe esta prueba y obliga a revisarla.
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_ent_perfil'),
  'actualizado_en,aviso_visto_en,ciclo_semanas,descanso_s,dias_plan,hogar_id,inicio_ciclo,margen_dormir_min,modificado_en,nivel,noche_desde,objetivo,persona_id,prueba_desde,prueba_ventana,ventana,version_pref,voz_descanso',
  'hab_ent_perfil: solo las columnas de la especificación 4.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_ent_plan_dias'),
  'actualizado_en,dia_semana,hogar_id,hora,modificado_en,persona_id,tipo,version', 'hab_ent_plan_dias: solo las de 4.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_ent_inventario'),
  'actualizado_en,confirmado,estado,hogar_id,item_id,modificado_en,notas,persona_id', 'hab_ent_inventario: solo las de 4.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_ent_bandas'),
  'activa,actualizado_en,cantidad,hogar_id,id,modificado_en,nombre,orden,persona_id,resistencia_kg_x10', 'hab_ent_bandas: solo las de 4.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_ent_sesiones'),
  'actualizado_en,bloque_id,catalogo_version,energia,esfuerzo,estado,fecha,fin,hogar_id,id,inicio,modificado_en,persona_id,plan,plantilla,semana_tipo,ventana,version',
  'hab_ent_sesiones: solo las de 4.2');
select pruebas.igual((select string_agg(column_name, ',' order by column_name collate "C") from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_ent_series'),
  'actualizado_en,banda_id,carga_pasos,descanso_real_s,ejercicio_id,esfuerzo,hogar_id,id,lado,modificado_en,motivo_cambio,n,persona_id,reps,segundos,sesion_id,sustituye_a,variante_id',
  'hab_ent_series: solo las de 4.2');
select pruebas.igual((select count(*)::int from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_ent\_%'), 6,
  'Son seis tablas hab_ent_* (una nueva obliga a revisar esta prueba)');

-- El motivo de cambio de una serie nunca dice «molestia» (PG-19).
select pruebas.ok((select pg_get_constraintdef(k.oid) from pg_constraint k
   where k.conrelid = 'public.hab_ent_series'::regclass and k.contype = 'c' and pg_get_constraintdef(k.oid) like '%motivo_cambio%') !~* 'molest|dolor|lesi',
  'La restricción de motivo_cambio no menciona molestia ni dolor');
select pruebas.ok((select pg_get_constraintdef(k.oid) from pg_constraint k
   where k.conrelid = 'public.hab_ent_series'::regclass and k.contype = 'c' and pg_get_constraintdef(k.oid) like '%motivo_cambio%')
   ~ 'no_disponible.*preferencia.*otra', '… y admite solo no_disponible, preferencia y otra');

select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_ent(1);
select pruebas.falla($$update public.hab_ent_series set sustituye_a = 'press_sentado', motivo_cambio = 'molestia'$$,
  'Una serie cambiada «por molestia» no se guarda con ese motivo', '23514');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set sustituye_a = 'press_sentado', motivo_cambio = 'otra'$$), 1,
  '… la app manda «otra» y el servidor solo ve eso');
-- Ni escondida en los dos jsonb.
select pruebas.falla($$update public.hab_ent_sesiones set plan = '[{"ejercicio": "marcy.press", "molestia": "hombro", "zona": "hombro"}]'$$,
  'Una molestia dentro del plan de la sesión se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_inventario set confirmado = '{"molestia": "rodilla"}'$$,
  'Una molestia dentro de lo confirmado del aparato se rechaza', '23514');
select pruebas.falla($$update public.hab_ent_inventario set confirmado = '{"zona_dolorida": true}'$$, '… también una zona', '23514');
select pruebas.falla($$update public.hab_ent_inventario set confirmado = '{"lesion_hombro": 1}'$$, '… o una lesión', '23514');
select pruebas.falla($$update public.hab_ent_inventario set confirmado = '{"diagnostico": "x"}'$$, '… o un diagnóstico', '23514');
-- No existe la columna: un INSERT que la nombre falla por no existir.
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, molestia, modificado_en)
  values (gen_random_uuid(), 'f8100000-0000-5000-8000-000000000001', 'x', 'y', 1, true, now())$$, 'Insertar una columna molestia falla: no existe', '42703');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, zona) values (gen_random_uuid(), 'hombro')$$, 'ni zona en las sesiones', '42703');

-- ---------------------------------------------------------------- el tercer tipo local no admite nube (hab_sobres.tipo)
select pruebas.como_postgres();
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'salud_local', 1, 'QUJDREVGR0g', 1)$$,
  'Un sobre de tipo salud_local es rechazado por la restricción de hab_sobres.tipo (CA-G-28)', '23514');
select pruebas.falla($$insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'molestias', 1, 'QUJDREVGR0g', 1)$$,
  '… y también uno llamado molestias', '23514');
select pruebas.falla($$insert into public.hab_modos (persona_id, hogar_id, tipo) values
  (pruebas.id_persona('ana@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001', 'salud_local')$$,
  'No hay fila de modo para salud_local: no tiene modo ni botón para pasarlo a la nube', '23514');
select pruebas.ok(
  (select pg_get_constraintdef(k.oid) from pg_constraint k where k.conrelid = 'public.hab_sobres'::regclass and k.contype = 'c'
     and pg_get_constraintdef(k.oid) like '%tipo%') !~ 'salud_local',
  'La restricción de hab_sobres.tipo no incluye salud_local');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'salud_local',
  'revision', 1, 'llave_version', 1, 'cifrado', 'QUJDREVGR0g')))$$, 'hab_subir_sobres no recibe un sobre salud_local aunque la nube esté activa', '22023');
select pruebas.falla($$select public.hab_cambiar_modo('salud_local', 'nube_cifrada')$$, 'hab_cambiar_modo no conoce salud_local', '22023');
select pruebas.falla($$select public.hab_reiniciar_nube('salud_local')$$, 'ni hab_reiniciar_nube', '22023');
select pruebas.falla($$select public.hab_borrar_mis_datos('salud_local')$$, 'ni hab_borrar_mis_datos: el servidor no tiene nada que borrar ahí', '22023');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres where tipo not in ('habitos_sensibles', 'diario_oracion')$$), 0,
  'No hay ningún sobre de otro tipo');

rollback;
