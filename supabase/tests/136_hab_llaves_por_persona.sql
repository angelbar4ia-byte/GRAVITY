-- Hábitos · Gimnasio y bicicleta (Fase 8, hallazgo G6-M1 de la revisión de calidad): las llaves primarias son POR PERSONA.
-- Antes `id uuid primary key` era global y los ids v5 (persona + fecha + plantilla + un espacio de nombres público) se
-- pueden calcular: una persona del hogar podía saber si otra tenía una sesión o una serie con un INSERT que daba 23505.
-- Migración: 20261154000000_habitos_llaves_por_persona.sql. Esta prueba reemplaza la sonda de calidad
-- (app/test/revision_calidad/g6_sonda_pk_global.sql) y cubre las siete tablas con `id`.
begin;

-- ---------------------------------------------------------------- la forma de las llaves
select pruebas.igual(
  (select string_agg(c.relname || '=' || pg_get_constraintdef(k.oid), '; ' order by c.relname)
     from pg_constraint k join pg_class c on c.oid = k.conrelid
    where k.contype = 'p' and c.relnamespace = 'public'::regnamespace
      and c.relname in ('hab_ent_bandas', 'hab_ent_sesiones', 'hab_ent_series', 'hab_bici_bicicletas',
                        'hab_bici_mantenimientos', 'hab_bici_salidas', 'hab_musica_listas')),
  'hab_bici_bicicletas=PRIMARY KEY (persona_id, id); hab_bici_mantenimientos=PRIMARY KEY (persona_id, id); '
  'hab_bici_salidas=PRIMARY KEY (persona_id, id); hab_ent_bandas=PRIMARY KEY (persona_id, id); '
  'hab_ent_series=PRIMARY KEY (persona_id, id); hab_ent_sesiones=PRIMARY KEY (persona_id, id); '
  'hab_musica_listas=PRIMARY KEY (persona_id, id)',
  'Las siete tablas con id tienen llave primaria (persona_id, id)');
select pruebas.igual(
  (select count(*)::int from pg_index i join pg_class c on c.oid = i.indrelid
    where c.relnamespace = 'public'::regnamespace
      and (c.relname like 'hab\_ent\_%' or c.relname like 'hab\_bici\_%' or c.relname = 'hab_musica_listas')
      and i.indisunique and array_length(i.indkey::int2[], 1) = 1
      and (select a.attname from pg_attribute a where a.attrelid = i.indrelid and a.attnum = i.indkey[0]) = 'id'),
  0, 'Ninguna tabla de entrenamiento, bicicleta o música tiene una llave única global sobre id');
select pruebas.igual(
  (select count(*)::int from pg_constraint k join pg_class c on c.oid = k.conrelid
    where k.contype = 'u' and c.relnamespace = 'public'::regnamespace and pg_get_constraintdef(k.oid) = 'UNIQUE (persona_id, id)'
      and c.relname in ('hab_ent_bandas', 'hab_ent_sesiones', 'hab_bici_bicicletas', 'hab_bici_mantenimientos', 'hab_bici_salidas', 'hab_musica_listas')),
  0, 'La restricción única (persona_id, id) que quedaba repetida se retiró (la primaria la sustituye)');
select pruebas.igual(
  (select string_agg(k.conname || ': ' || pg_get_constraintdef(k.oid), ' | ' order by k.conname)
     from pg_constraint k
    where k.contype = 'f' and k.conname in ('hab_ent_series_sesion_fk', 'hab_ent_series_banda_fk', 'hab_bici_perfil_bicicleta_fk',
                                            'hab_bici_mantenimientos_bicicleta_fk', 'hab_bici_salidas_bicicleta_fk')),
  'hab_bici_mantenimientos_bicicleta_fk: FOREIGN KEY (persona_id, bicicleta_id) REFERENCES hab_bici_bicicletas(persona_id, id) ON DELETE CASCADE | '
  || 'hab_bici_perfil_bicicleta_fk: FOREIGN KEY (persona_id, bicicleta_activa_id) REFERENCES hab_bici_bicicletas(persona_id, id) ON DELETE SET NULL (bicicleta_activa_id) | '
  || 'hab_bici_salidas_bicicleta_fk: FOREIGN KEY (persona_id, bicicleta_id) REFERENCES hab_bici_bicicletas(persona_id, id) ON DELETE SET NULL (bicicleta_id) | '
  || 'hab_ent_series_banda_fk: FOREIGN KEY (persona_id, banda_id) REFERENCES hab_ent_bandas(persona_id, id) ON DELETE SET NULL (banda_id) | '
  || 'hab_ent_series_sesion_fk: FOREIGN KEY (persona_id, sesion_id) REFERENCES hab_ent_sesiones(persona_id, id) ON DELETE CASCADE',
  'Las cinco llaves foráneas siguen por persona y conservan su ON DELETE');
select pruebas.igual(
  (select count(*)::int from pg_indexes where schemaname = 'public'
     and indexname in ('hab_ent_series_natural', 'hab_bici_mantenimientos_natural')),
  2, 'Los índices únicos naturales (serie y mantenimiento) siguen');
select pruebas.igual(
  (select count(*)::int from pg_constraint where conname in ('hab_ent_sesiones_dia_plantilla', 'hab_bici_salidas_dia_n') and contype = 'u'),
  2, '… y las restricciones únicas por día (sesión y salida) también');

-- ---------------------------------------------------------------- la sonda de G6-M1: gimnasio
-- Ana tiene sesión, serie y banda con ids que cualquiera puede calcular.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-11-30', 'A', 'estandar', 'carga', 'noche', '2026-11-30 20:00-06', '2026-11-30 20:45-06', 'completa', '[]', 1, now())$$), 1,
  'Ana sube su sesión');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en)
  values ('f8200000-0000-4000-8000-0000000000e1', 'Verde de Ana', 1, 1, now())$$), 1, '… y su banda');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, banda_id, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000e1', 'f8100000-0000-5000-8000-0000000000e1', 'marcy.press', 'press_sentado', 1, 9,
          'f8200000-0000-4000-8000-0000000000e1', now())$$), 1, '… y su serie con esa banda');

-- Alex (pareja, coadministrador) prueba los mismos ids con filas suyas.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-12-07', 'B', 'estandar', 'carga', 'noche', '2026-12-07 20:00-06', '2026-12-07 20:45-06', 'completa', '[]', 1, now())$$), 1,
  'G6-M1: con el id de la sesión de Ana, Alex inserta la suya sin 23505: no hay sondeo posible');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en)
  values ('f8200000-0000-4000-8000-0000000000e1', 'Banda de Alex', 1, 1, now())$$), 1, '… ni con el id de su banda');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, banda_id, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000e1', 'f8100000-0000-5000-8000-0000000000e1', 'marcy.press', 'press_sentado', 1, 5,
          'f8200000-0000-4000-8000-0000000000e1', now())$$), 1, '… ni con el id de su serie (de su sesión y su banda)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones$$) + pruebas.cuenta($$select * from public.hab_ent_series$$)
                     + pruebas.cuenta($$select * from public.hab_ent_bandas$$), 3,
  'Alex solo ve lo suyo: una sesión, una serie y una banda');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, modificado_en)
  values ('f8300000-0000-5000-8000-0000000000e2', 'f8100000-0000-5000-8000-0000000000ff', 'marcy.press', 'press_sentado', 1, now())$$,
  'Una serie de Alex no cuelga de una sesión que no existe en lo suyo: 23503', '23503');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_sesiones set esfuerzo = 4, modificado_en = now()
  where id = 'f8100000-0000-5000-8000-0000000000e1'$$), 1, 'Alex cambia solo su sesión con ese id');

-- El conflicto es por (persona_id, id) y no necesita que la app mande persona_id (lo pone hab_a_propio).
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-12-07', 'B', 'estandar', 'carga', 'noche', '2026-12-07 20:00-06', '2026-12-07 20:45-06', 'completa', '[]', 1, now() + interval '1 minute')
  on conflict (persona_id, id) do update set esfuerzo = excluded.esfuerzo, modificado_en = excluded.modificado_en$$), 1,
  'Upsert por (persona_id, id) sin mandar persona_id: encuentra la fila propia y la actualiza');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-12-07', 'B', 'estandar', 'carga', 'noche', '2026-12-07 20:00-06', '2026-12-07 20:45-06', 'completa', '[]', 1, now())
  on conflict (id) do update set esfuerzo = excluded.esfuerzo$$,
  'El viejo on_conflict=id ya no tiene llave única que lo respalde (42P10): la app debe usar persona_id,id', '42P10');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-0000000000e1'), null::smallint,
  'La sesión de Ana quedó como ella la dejó (sin esfuerzo)');

-- ---------------------------------------------------------------- la sonda de G6-M1: bicicleta y música
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en)
  values ('f8500000-0000-4000-8000-0000000000e1', 'Bici de Ana', now())$$), 1, 'Ana sube su bicicleta');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, bicicleta_id, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000e1', '2026-11-21', 1, 'hecha', 'f8500000-0000-4000-8000-0000000000e1', now())$$), 1, '… su salida');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values ('f8600000-0000-5000-8000-0000000000e1', 'f8500000-0000-4000-8000-0000000000e1', 'lubricar_cadena', '2026-11-14', now())$$), 1, '… su mantenimiento');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-0000000000e1', 'Lista de Ana', 'bicicleta', 'otra', 'https://musica.ejemplo.test/ana', 1, now())$$), 1, '… su lista de música');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_perfil (bicicleta_activa_id, modificado_en)
  values ('f8500000-0000-4000-8000-0000000000e1', now())$$), 1, '… y su perfil con esa bicicleta activa');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en)
  values ('f8500000-0000-4000-8000-0000000000e1', 'Bici de Alex', now())$$), 1,
  'G6-M1: con el id de la bicicleta de Ana, Alex inserta la suya sin 23505');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, bicicleta_id, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000e1', '2026-11-21', 1, 'hecha', 'f8500000-0000-4000-8000-0000000000e1', now())$$), 1,
  '… ni con el id de la salida (aunque sea el mismo día y número)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values ('f8600000-0000-5000-8000-0000000000e1', 'f8500000-0000-4000-8000-0000000000e1', 'lubricar_cadena', '2026-11-14', now())$$), 1, '… ni con el del mantenimiento');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values ('f8800000-0000-4000-8000-0000000000e1', 'Lista de Alex', 'bicicleta', 'otra', 'https://musica.ejemplo.test/alex', 1, now())$$), 1, '… ni con el de la lista');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_bicicletas$$) + pruebas.cuenta($$select * from public.hab_bici_salidas$$)
                     + pruebas.cuenta($$select * from public.hab_bici_mantenimientos$$) + pruebas.cuenta($$select * from public.hab_musica_listas$$), 4,
  'Alex solo ve lo suyo (cuatro filas)');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, bicicleta_id, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000e2', '2026-11-22', 1, 'hecha', 'f8500000-0000-4000-8000-0000000000ff', now())$$,
  'Una salida de Alex no cuelga de una bicicleta que no es suya: 23503', '23503');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000e1', '2026-11-21', 1, 'hecha', now())$$,
  'Su propio id repetido sí choca (23505): la llave sigue protegiendo lo propio', '23505');

-- ---------------------------------------------------------------- los ON DELETE siguen igual
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_bandas where id = 'f8200000-0000-4000-8000-0000000000e1'$$), 1, 'Ana borra su banda');
select pruebas.igual((select banda_id from public.hab_ent_series where id = 'f8300000-0000-5000-8000-0000000000e1'), null::uuid,
  '… su serie queda sin banda (ON DELETE SET NULL (banda_id))');
select pruebas.igual((select reps from public.hab_ent_series where id = 'f8300000-0000-5000-8000-0000000000e1'), 9::smallint, '… y conserva su contenido');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_bicicletas where id = 'f8500000-0000-4000-8000-0000000000e1'$$), 1, 'Ana borra su bicicleta');
select pruebas.igual((select bicicleta_id from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-0000000000e1'), null::uuid,
  '… su salida queda sin bicicleta (ON DELETE SET NULL)');
select pruebas.igual((select bicicleta_activa_id from public.hab_bici_perfil), null::uuid, '… su perfil queda sin bicicleta activa');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bici_mantenimientos$$), 0, '… y sus mantenimientos se van con ella (ON DELETE CASCADE)');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-0000000000e1'$$), 1, 'Ana borra su sesión');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_series$$), 0, '… y sus series se van con ella (ON DELETE CASCADE)');
-- Nada de lo de Alex se movió.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones$$) + pruebas.cuenta($$select * from public.hab_ent_series$$)
                     + pruebas.cuenta($$select * from public.hab_bici_bicicletas$$) + pruebas.cuenta($$select * from public.hab_bici_mantenimientos$$), 4,
  'Lo de Alex no se movió: sesión, serie, bicicleta y mantenimiento siguen');
select pruebas.igual((select banda_id from public.hab_ent_series where id = 'f8300000-0000-5000-8000-0000000000e1'), 'f8200000-0000-4000-8000-0000000000e1'::uuid,
  '… y su serie conserva su banda');

rollback;
