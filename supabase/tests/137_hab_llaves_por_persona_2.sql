-- Hábitos (Fase 8, hallazgo G6-M1, 2.ª parte): las llaves primarias son POR PERSONA también en hab_objetivos, hab_bloques,
-- hab_registros, hab_marcas_biblia y hab_revisiones. Antes `id uuid primary key` era global y la app calcula esos ids sin
-- secreto: hab_revisiones = v5('revision|<lunes>') y hab_marcas_biblia = v5('marca|<tipo>|<referencia>') ni siquiera llevan
-- la persona (dos personas del mismo hogar chocaban con 23505); el objetivo y los bloques de gimnasio son v5 de la persona
-- y los registros salen de ellos. Migración: 20261155000000_habitos_musica_aparte_y_llaves_por_persona_2.sql. La 136 cubre
-- las otras siete tablas con id; esta, las cinco que faltaban.
-- Datos de la semilla: Ana tiene los objetivos f5000…01 y …02, el bloque f5100…01, los registros f5200…01 y …02, la marca
-- f5400…01 y la revisión f5500…01; Alex, el objetivo f5000…03. Alex prueba con los ids de Ana (calculables) y no pasa nada.
begin;

-- ---------------------------------------------------------------- la forma de las llaves
select pruebas.igual(
  (select string_agg(c.relname || '=' || pg_get_constraintdef(k.oid), '; ' order by c.relname)
     from pg_constraint k join pg_class c on c.oid = k.conrelid
    where k.contype = 'p' and c.relnamespace = 'public'::regnamespace
      and c.relname in ('hab_objetivos', 'hab_bloques', 'hab_registros', 'hab_marcas_biblia', 'hab_revisiones')),
  'hab_bloques=PRIMARY KEY (persona_id, id); hab_marcas_biblia=PRIMARY KEY (persona_id, id); '
  'hab_objetivos=PRIMARY KEY (persona_id, id); hab_registros=PRIMARY KEY (persona_id, id); '
  'hab_revisiones=PRIMARY KEY (persona_id, id)',
  'Las cinco tablas tienen llave primaria (persona_id, id)');
-- Guardia: una tabla hab_* nueva con llave global sobre id falla esta prueba hasta que alguien decida si su id se puede calcular.
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_constraint k join pg_class c on c.oid = k.conrelid
    where k.contype = 'p' and c.relnamespace = 'public'::regnamespace and c.relname like 'hab\_%'
      and pg_get_constraintdef(k.oid) = 'PRIMARY KEY (id)'),
  'hab_lecturas, hab_pausas, hab_planes_lectura, hab_sobres',
  'Solo quedan con llave global las cuatro de ids v4 aleatorios (no calculables); toda tabla hab_* nueva con llave sobre id solo debe revisarse aquí');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_constraint k join pg_class c on c.oid = k.conrelid
    where k.contype = 'u' and c.relnamespace = 'public'::regnamespace and c.relname like 'hab\_%'
      and pg_get_constraintdef(k.oid) = 'UNIQUE (persona_id, id)'),
  'hab_planes_lectura',
  'La restricción única (persona_id, id) que quedaba repetida se retiró en hab_objetivos y hab_bloques (la de los planes, v4, sigue)');
select pruebas.igual(
  (select string_agg(k.conname || ': ' || pg_get_constraintdef(k.oid), ' | ' order by k.conname)
     from pg_constraint k
    where k.contype = 'f' and k.conname in ('hab_bloques_objetivo_fk', 'hab_registros_objetivo_fk', 'hab_registros_bloque_fk',
                                            'hab_pausas_objetivo_fk', 'hab_bici_salidas_bloque_fk', 'hab_ent_sesiones_bloque_fk')),
  'hab_bici_salidas_bloque_fk: FOREIGN KEY (persona_id, bloque_id) REFERENCES hab_bloques(persona_id, id) ON DELETE SET NULL (bloque_id) | '
  || 'hab_bloques_objetivo_fk: FOREIGN KEY (persona_id, objetivo_id) REFERENCES hab_objetivos(persona_id, id) ON DELETE CASCADE | '
  || 'hab_ent_sesiones_bloque_fk: FOREIGN KEY (persona_id, bloque_id) REFERENCES hab_bloques(persona_id, id) ON DELETE SET NULL (bloque_id) | '
  || 'hab_pausas_objetivo_fk: FOREIGN KEY (persona_id, objetivo_id) REFERENCES hab_objetivos(persona_id, id) ON DELETE CASCADE | '
  || 'hab_registros_bloque_fk: FOREIGN KEY (persona_id, bloque_id) REFERENCES hab_bloques(persona_id, id) ON DELETE CASCADE | '
  || 'hab_registros_objetivo_fk: FOREIGN KEY (persona_id, objetivo_id) REFERENCES hab_objetivos(persona_id, id) ON DELETE CASCADE',
  'Las seis llaves foráneas que dependían de ellas siguen por persona y conservan su ON DELETE');
select pruebas.igual(
  (select count(*)::int from pg_indexes where schemaname = 'public'
     and indexname in ('hab_registros_un_elemento_por_dia', 'hab_revisiones_semana_unica')),
  2, 'Los índices únicos naturales (un registro por elemento y día, una revisión por semana) siguen');
select pruebas.igual(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and c.relnamespace = 'public'::regnamespace
      and c.relname in ('hab_objetivos', 'hab_bloques', 'hab_registros', 'hab_marcas_biblia', 'hab_revisiones')
      and t.tgname in ('hab_a_propio', 'hab_z_cuota')),
  10, 'Los triggers (hab_a_propio y la cuota) siguen en las cinco tablas');
select pruebas.igual(
  (select count(*)::int from pg_class c where c.relnamespace = 'public'::regnamespace and c.relrowsecurity
      and c.relname in ('hab_objetivos', 'hab_bloques', 'hab_registros', 'hab_marcas_biblia', 'hab_revisiones')),
  5, 'La RLS sigue activa en las cinco');

-- ---------------------------------------------------------------- la sonda de G6-M1 con los ids de Ana
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 1, 'Alex parte de su objetivo (no ve los de Ana)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en)
  values ('f5000000-0000-4000-8000-000000000001', 'Entrenar (Alex)', 'salud', 'construir', '2026-11-01', now())$$), 1,
  'Con el id del objetivo de Ana, Alex crea el suyo sin 23505: no hay sondeo de «¿usa Ana el gimnasio?»');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bloques (id, titulo, area, tipo, objetivo_id, inicio, duracion_min, dias, desde, modificado_en)
  values ('f5100000-0000-4000-8000-000000000001', 'Gimnasio (Alex)', 'salud', 'actividad', 'f5000000-0000-4000-8000-000000000001', '20:00', 45, 2, '2026-11-01', now())$$), 1,
  '… ni con el id del bloque (su bloque cuelga de su objetivo)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_registros (id, objetivo_id, fecha, estado, valor, modificado_en)
  values ('f5200000-0000-4000-8000-000000000001', 'f5000000-0000-4000-8000-000000000001', '2026-10-26', 'omitido', null, now())$$), 1,
  '… ni con el id del registro (aunque sea el mismo día)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_registros (id, bloque_id, fecha, estado, modificado_en)
  values ('f5200000-0000-4000-8000-000000000002', 'f5100000-0000-4000-8000-000000000001', '2026-10-27', 'hecho', now())$$), 1,
  '… ni con el id del registro de un bloque');
select pruebas.igual(pruebas.afecta($$insert into public.hab_marcas_biblia (id, tipo, referencia, color, modificado_en)
  values ('f5400000-0000-4000-8000-000000000001', 'subrayado', '43:3:16', 'verde', now())$$), 1,
  '… ni con el id de la marca (el v5 de «marca|tipo|referencia» es el mismo para todos)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-4000-8000-000000000001', '2026-10-19', 'pendiente', now())$$), 1,
  '… ni con el id de la revisión de esa semana (el v5 de «revision|lunes» tampoco lleva a la persona)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_pausas (objetivo_id, desde, hasta, motivo, modificado_en)
  values ('f5000000-0000-4000-8000-000000000001', '2026-11-02', '2026-11-08', 'viaje', now())$$), 1, 'Alex pausa su objetivo (para la cascada)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 2, 'Alex ve solo lo suyo: sus dos objetivos…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bloques$$) + pruebas.cuenta($$select * from public.hab_registros$$)
                     + pruebas.cuenta($$select * from public.hab_marcas_biblia$$) + pruebas.cuenta($$select * from public.hab_revisiones$$), 5,
  '… y un bloque, dos registros, una marca y una revisión');
select pruebas.falla($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en)
  values ('f5000000-0000-4000-8000-000000000001', 'Otra vez', 'salud', 'construir', '2026-11-01', now())$$,
  'Su propio id repetido sí choca (23505): la llave sigue protegiendo lo propio', '23505');
select pruebas.falla($$insert into public.hab_marcas_biblia (id, tipo, referencia, color, modificado_en)
  values ('f5400000-0000-4000-8000-000000000001', 'subrayado', '43:3:16', 'rojo', now())$$,
  '… también en las marcas', '23505');
select pruebas.falla($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-4000-8000-0000000000aa', '2026-10-19', 'pendiente', now())$$,
  '… y la revisión de la misma semana con otro id sigue chocando (23505, único por persona y semana)', '23505');
select pruebas.falla($$insert into public.hab_registros (id, objetivo_id, fecha, estado, modificado_en)
  values ('f5200000-0000-4000-8000-0000000000aa', 'f5000000-0000-4000-8000-000000000001', '2026-10-26', 'hecho', now())$$,
  '… y el mismo elemento y día con otro id también (23505: un registro por elemento y día)', '23505');
select pruebas.falla($$insert into public.hab_registros (id, objetivo_id, fecha, estado, modificado_en)
  values ('f5200000-0000-4000-8000-0000000000bb', 'f5000000-0000-4000-8000-000000000002', '2026-10-30', 'hecho', now())$$,
  'Un registro de Alex no cuelga del objetivo de Ana (f5000…02 no es suyo): 23503', '23503');
select pruebas.falla($$insert into public.hab_bloques (id, titulo, area, tipo, objetivo_id, inicio, duracion_min, dias, desde, modificado_en)
  values (gen_random_uuid(), 'Colgado', 'salud', 'actividad', 'f5000000-0000-4000-8000-000000000002', '20:00', 45, 2, '2026-11-01', now())$$,
  'Un bloque de Alex no cuelga del objetivo de Ana: 23503', '23503');

-- Lo de Ana quedó como ella lo dejó.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select titulo from public.hab_objetivos where id = 'f5000000-0000-4000-8000-000000000001'), 'Leer 20 minutos al día (ejemplo)',
  'El objetivo de Ana sigue igual');
select pruebas.igual((select titulo from public.hab_bloques where id = 'f5100000-0000-4000-8000-000000000001'), 'Lectura de la mañana (ejemplo)', '… su bloque');
select pruebas.igual((select estado from public.hab_registros where id = 'f5200000-0000-4000-8000-000000000001'), 'hecho', '… su registro');
select pruebas.igual((select color from public.hab_marcas_biblia where id = 'f5400000-0000-4000-8000-000000000001'), 'amarillo', '… su marca');
select pruebas.igual((select estado from public.hab_revisiones where id = 'f5500000-0000-4000-8000-000000000001'), 'completada', '… su revisión');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$) + pruebas.cuenta($$select * from public.hab_bloques$$)
                     + pruebas.cuenta($$select * from public.hab_registros$$) + pruebas.cuenta($$select * from public.hab_marcas_biblia$$)
                     + pruebas.cuenta($$select * from public.hab_revisiones$$), 7,
  'Ana sigue viendo solo las suyas (dos objetivos, un bloque, dos registros, una marca y una revisión)');

-- ---------------------------------------------------------------- la subida idempotente por (persona_id, id) sin mandar persona_id
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en)
  values ('f5000000-0000-4000-8000-000000000001', 'Entrenar más (Alex)', 'salud', 'construir', '2026-11-01', now() + interval '1 minute')
  on conflict (persona_id, id) do update set titulo = excluded.titulo, modificado_en = excluded.modificado_en$$), 1,
  'Objetivo: upsert por (persona_id, id) sin mandar persona_id encuentra la fila propia y la actualiza');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bloques (id, titulo, area, tipo, objetivo_id, inicio, duracion_min, dias, desde, modificado_en)
  values ('f5100000-0000-4000-8000-000000000001', 'Gimnasio tarde (Alex)', 'salud', 'actividad', 'f5000000-0000-4000-8000-000000000001', '20:00', 45, 2, '2026-11-01', now() + interval '1 minute')
  on conflict (persona_id, id) do update set titulo = excluded.titulo, modificado_en = excluded.modificado_en$$), 1,
  'Bloque: lo mismo');
select pruebas.igual(pruebas.afecta($$insert into public.hab_registros (id, objetivo_id, fecha, estado, modificado_en)
  values ('f5200000-0000-4000-8000-000000000001', 'f5000000-0000-4000-8000-000000000001', '2026-10-26', 'hecho', now() + interval '1 minute')
  on conflict (persona_id, id) do update set estado = excluded.estado, modificado_en = excluded.modificado_en$$), 1,
  'Registro: lo mismo (omitido pasa a hecho)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_marcas_biblia (id, tipo, referencia, color, modificado_en)
  values ('f5400000-0000-4000-8000-000000000001', 'subrayado', '43:3:16', 'rojo', now() + interval '1 minute')
  on conflict (persona_id, id) do update set color = excluded.color, modificado_en = excluded.modificado_en$$), 1,
  'Marca: lo mismo');
select pruebas.igual(pruebas.afecta($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-4000-8000-000000000001', '2026-10-19', 'completada', now() + interval '1 minute')
  on conflict (persona_id, id) do update set estado = excluded.estado, modificado_en = excluded.modificado_en$$), 1,
  'Revisión: lo mismo');
select pruebas.igual((select estado from public.hab_revisiones where semana = '2026-10-19'), 'completada', '… y la revisión de Alex quedó completada');
-- Reenvío idéntico de la cola (DO NOTHING / ignore-duplicates): no duplica ni falla.
select pruebas.igual(pruebas.afecta($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en)
  values ('f5000000-0000-4000-8000-000000000001', 'Entrenar más (Alex)', 'salud', 'construir', '2026-11-01', now())
  on conflict (persona_id, id) do nothing$$), 0, 'El reenvío con DO NOTHING no inserta otra fila (idempotente)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 2, '… y Alex sigue con sus dos objetivos');
-- Con otro contenido gana el modificado_en más reciente.
select pruebas.igual(pruebas.afecta($$insert into public.hab_marcas_biblia (id, tipo, referencia, color, modificado_en)
  values ('f5400000-0000-4000-8000-000000000001', 'subrayado', '43:3:16', 'azul', now() - interval '1 hour')
  on conflict (persona_id, id) do update set color = excluded.color, modificado_en = excluded.modificado_en$$), 0,
  'Un reenvío con modificado_en más viejo se ignora (último gana)');
select pruebas.igual((select color from public.hab_marcas_biblia), 'rojo', '… y la marca conserva lo último');
-- La subida por la llave natural de la revisión (la que ya usa la app) sigue valiendo.
select pruebas.igual(pruebas.afecta($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-4000-8000-0000000000cc', '2026-10-19', 'omitida', now() + interval '2 minutes')
  on conflict (persona_id, semana) do update set estado = excluded.estado, modificado_en = excluded.modificado_en$$), 1,
  'Revisión: on conflict (persona_id, semana) sigue valiendo');
-- El viejo on_conflict=id ya no tiene llave única que lo respalde.
select pruebas.falla($$insert into public.hab_objetivos (id, titulo, area, tipo, fecha_inicio, modificado_en)
  values ('f5000000-0000-4000-8000-000000000001', 'X', 'salud', 'construir', '2026-11-01', now())
  on conflict (id) do update set titulo = excluded.titulo$$, 'El viejo on_conflict=id da 42P10 en objetivos', '42P10');
select pruebas.falla($$insert into public.hab_bloques (id, titulo, area, tipo, inicio, duracion_min, dias, desde, modificado_en)
  values ('f5100000-0000-4000-8000-000000000001', 'X', 'salud', 'actividad', '20:00', 45, 2, '2026-11-01', now())
  on conflict (id) do update set titulo = excluded.titulo$$, '… en bloques', '42P10');
select pruebas.falla($$insert into public.hab_registros (id, objetivo_id, fecha, estado, modificado_en)
  values ('f5200000-0000-4000-8000-000000000001', 'f5000000-0000-4000-8000-000000000001', '2026-10-26', 'hecho', now())
  on conflict (id) do update set estado = excluded.estado$$, '… en registros', '42P10');
select pruebas.falla($$insert into public.hab_marcas_biblia (id, tipo, referencia, color, modificado_en)
  values ('f5400000-0000-4000-8000-000000000001', 'subrayado', '43:3:16', 'rojo', now())
  on conflict (id) do update set color = excluded.color$$, '… en marcas', '42P10');
select pruebas.falla($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-4000-8000-000000000001', '2026-10-19', 'completada', now())
  on conflict (id) do update set estado = excluded.estado$$, '… y en revisiones', '42P10');
-- Lo de Ana no se movió con nada de lo anterior.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select titulo from public.hab_objetivos where id = 'f5000000-0000-4000-8000-000000000001'), 'Leer 20 minutos al día (ejemplo)', 'El objetivo de Ana sigue igual');
select pruebas.igual((select estado from public.hab_registros where id = 'f5200000-0000-4000-8000-000000000001'), 'hecho', '… su registro');
select pruebas.igual((select color from public.hab_marcas_biblia where id = 'f5400000-0000-4000-8000-000000000001'), 'amarillo', '… su marca');
select pruebas.igual((select estado from public.hab_revisiones where id = 'f5500000-0000-4000-8000-000000000001'), 'completada', '… su revisión');
select pruebas.igual((select modificado_en from public.hab_revisiones where id = 'f5500000-0000-4000-8000-000000000001'), '2026-10-26 14:40-06'::timestamptz,
  '… y con su hora de modificación original');

-- ---------------------------------------------------------------- los ON DELETE siguen igual, cada quien en lo suyo
select pruebas.como('alex@ejemplo.test');
-- Una salida de bicicleta y una sesión de gimnasio de Alex cuelgan de su bloque.
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, bloque_id, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000d1', '2026-11-21', 1, 'hecha', 'f5100000-0000-4000-8000-000000000001', now())$$), 1,
  'Una salida de Alex cuelga de su bloque');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, bloque_id, inicio, fin, estado, plan, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000d1', '2026-11-30', 'A', 'estandar', 'carga', 'noche', 'f5100000-0000-4000-8000-000000000001',
          '2026-11-30 20:00-06', '2026-11-30 20:45-06', 'completa', '[]', 1, now())$$), 1, '… y una sesión de gimnasio también');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bloques where id = 'f5100000-0000-4000-8000-000000000001'$$), 1, 'Alex borra su bloque');
select pruebas.igual((select bloque_id from public.hab_bici_salidas where id = 'f8700000-0000-5000-8000-0000000000d1'), null::uuid,
  '… su salida queda sin bloque (ON DELETE SET NULL (bloque_id))');
select pruebas.igual((select bloque_id from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-0000000000d1'), null::uuid,
  '… su sesión también');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_registros where bloque_id is not null$$), 0,
  '… y el registro de ese bloque se va con él (ON DELETE CASCADE)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_registros$$), 1, '… y el registro de su objetivo sigue');
-- El bloque de Ana, con el mismo id, no se movió.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bloques where id = 'f5100000-0000-4000-8000-000000000001'$$), 1, 'El bloque de Ana, con el mismo id, sigue');
-- Ana borra su objetivo: se va lo suyo (bloque, registros) y nada de Alex.
select pruebas.igual(pruebas.afecta($$delete from public.hab_objetivos where id = 'f5000000-0000-4000-8000-000000000001'$$), 1, 'Ana borra su objetivo');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_bloques$$), 0, '… su bloque se va con él (ON DELETE CASCADE)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_registros$$), 0, '… y sus registros también');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 1, '… le queda el otro objetivo');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos where id = 'f5000000-0000-4000-8000-000000000001'$$), 1, 'El objetivo de Alex, con el mismo id, sigue');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_registros$$), 1, '… y su registro');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_pausas where objetivo_id = 'f5000000-0000-4000-8000-000000000001'$$), 1, '… y su pausa');
select pruebas.igual(pruebas.afecta($$delete from public.hab_objetivos where id = 'f5000000-0000-4000-8000-000000000001'$$), 1, 'Alex borra su objetivo');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_pausas$$) + pruebas.cuenta($$select * from public.hab_registros$$), 0,
  '… y su pausa y su registro se van con él (ON DELETE CASCADE)');

-- ---------------------------------------------------------------- el caso funcional: dos personas, la misma semana, el mismo id
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-5000-8000-0000000000e1', '2026-11-23', 'pendiente', now())$$), 1, 'Ana guarda la revisión de la semana (id v5 de la semana)');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_revisiones (id, semana, estado, modificado_en)
  values ('f5500000-0000-5000-8000-0000000000e1', '2026-11-23', 'pendiente', now())$$), 1,
  'La familiar guarda la suya con el MISMO id (antes daba 23505 en la llave global: un fallo funcional del hogar)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_revisiones where semana = '2026-11-23'$$), 1, '… y cada quien ve solo la suya');

rollback;
