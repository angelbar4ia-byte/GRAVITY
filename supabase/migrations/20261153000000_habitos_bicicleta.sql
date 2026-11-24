-- =============================================================================
-- GRAVITY · Fase 8 · Hábitos · Bicicleta de los sábados (B2): tablas hab_bici_* y hab_musica_listas
-- =============================================================================
-- docs/specs/fase-8-habitos-bicicleta.md, secciones 5.1 a 5.4, 7, 8 (fila B2), 9.2 (CA-B-16 a CA-B-23), 12 y 15
-- (B0 cerrado el 24/nov/2026: la especificación y sus propuestas PB-xx están vigentes). Misma plantilla que
-- 20261152000000_habitos_gimnasio.sql.
--
-- Qué guarda el servidor: perfil, bicicletas, mantenimientos (incluye las lecturas del odómetro), salidas y enlaces
-- de música de UNA persona, en claro y bajo RLS (como hab_registros): ni el dueño, ni la pareja, ni la cuenta
-- maestra, ni Casa, ni el cuidador, ni otro hogar, ni anon leen o escriben lo ajeno. Editables con último-gana
-- (modificado_en); la persona puede borrar lo suyo. Sin trigger de bitácora: el prefijo hab_ ya está protegido y
-- oculto (20261105). Solo números sin lugar: fecha, duración, distancia en metros, desnivel, esfuerzo.
--
-- Qué NO guarda, nunca (5.2, 7, PB-03, PB-04): ubicación, ruta, trazo, coordenadas, enlace de ruta, domicilio,
-- contacto de emergencia ni teléfono. No hay columna ni tabla para ellos y la salida NO enlaza con ninguna ruta:
-- el vínculo salida-ruta, las rutas y el contacto viven solo en el dispositivo (tipo local ubicacion_local).
-- hab_sobres.tipo (20261106) sigue admitiendo solo los dos tipos de la nube, así que un error de la app que
-- intentara subir un sobre ubicacion_local es rechazado.
--
-- hab_musica_listas es COMPARTIDA con el gimnasio (PB-14: «Abrir mi lista»); no existía antes de esta migración
-- (el gimnasio solo la menciona en su especificación), así que se crea aquí una sola vez.
--
-- Convención 12: los grant insert/update repiten la lista completa de columnas. Migración nueva (hacia adelante).
-- PostgreSQL 15 o superior (ON DELETE SET NULL con lista de columnas). Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tablas
-- -----------------------------------------------------------------------------
-- Las bicicletas van primero: el perfil, los mantenimientos y las salidas apuntan a ellas.
create table public.hab_bici_bicicletas (
  id                uuid primary key,
  persona_id        uuid not null references public.personas (id),
  hogar_id          uuid not null references public.hogares (id),
  nombre            text not null check (char_length(btrim(nombre)) between 1 and 40),
  tipo              text check (tipo in ('montana', 'ruta', 'gravel', 'urbana', 'otra')),   -- nulo: no se supone ninguno
  odometro_inicial_m integer not null default 0 check (odometro_inicial_m between 0 and 200000000),
  intervalos        jsonb check (jsonb_typeof(intervalos) = 'object' and octet_length(intervalos::text) <= 1024),
  activa            boolean not null default true,
  modificado_en     timestamptz not null,
  actualizado_en    timestamptz not null default now(),
  constraint hab_bici_bicicletas_persona_id_key unique (persona_id, id)
);
comment on table public.hab_bici_bicicletas is
  'Bicicletas de una persona. odometro_inicial_m: lo que ya tenía al registrarla (en metros). intervalos: '
  '{tarea: {km, semanas}} de mantenimiento (nulo = valores iniciales; forma validada por hab_bici_validar_bicicleta). '
  'El odómetro NO se guarda: se calcula (inicial + última lectura + salidas).';

-- Una fila por persona (se crea al primer uso).
create table public.hab_bici_perfil (
  persona_id            uuid primary key references public.personas (id),
  hogar_id              uuid not null references public.hogares (id),
  bicicleta_activa_id   uuid,
  duracion_prevista_min smallint not null default 240 check (duracion_prevista_min between 30 and 720),
  margen_revision_min   smallint not null default 90 check (margen_revision_min between 0 and 240),
  carga_piernas         text not null default 'normal' check (carga_piernas in ('normal', 'ligera', 'por_esfuerzo')),
  tope_aumento_pct      smallint not null default 20 check (tope_aumento_pct between 5 and 50),
  preparacion           jsonb not null default '[]'::jsonb check (octet_length(preparacion::text) <= 4096),
  intervalo_agua_min    smallint check (intervalo_agua_min between 10 and 120),     -- solo V2; nulo = sin sugerencia
  intervalo_comida_min  smallint check (intervalo_comida_min between 10 and 120),   -- solo V2; nulo = sin sugerencia
  aviso_visto_en        timestamptz,
  modificado_en         timestamptz not null,
  actualizado_en        timestamptz not null default now(),
  constraint hab_bici_perfil_bicicleta_fk foreign key (persona_id, bicicleta_activa_id)
    references public.hab_bici_bicicletas (persona_id, id) on delete set null (bicicleta_activa_id)
);
comment on table public.hab_bici_perfil is
  'Perfil de bicicleta de una persona (una fila). Valores de las reglas (duración prevista, margen con la revisión, '
  'carga de piernas, tope de aumento) y la lista de preparación (forma validada por hab_bici_validar_perfil). '
  'Sin ningún dato de ubicación ni de salud.';

-- Hechos del cuidado de la bici. id: v5 de (persona, bicicleta, tarea, fecha): dos equipos convergen.
create table public.hab_bici_mantenimientos (
  id             uuid primary key,
  persona_id     uuid not null references public.personas (id),
  hogar_id       uuid not null references public.hogares (id),
  bicicleta_id   uuid not null,
  tarea          text not null check (tarea in ('lubricar_cadena', 'limpiar_transmision', 'revisar_frenos_llantas',
                                                'revision_general', 'lectura_odometro', 'otra')),
  fecha          date not null,
  odometro_m     integer check (odometro_m between 0 and 200000000),
  nota           text check (char_length(nota) <= 120),
  modificado_en  timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_bici_mantenimientos_persona_id_key unique (persona_id, id),
  constraint hab_bici_mantenimientos_bicicleta_fk foreign key (persona_id, bicicleta_id)
    references public.hab_bici_bicicletas (persona_id, id) on delete cascade,
  -- Una lectura del odómetro sin la cifra no dice nada (4.8).
  constraint hab_bici_mantenimientos_lectura check (tarea <> 'lectura_odometro' or odometro_m is not null)
);
comment on table public.hab_bici_mantenimientos is
  'Mantenimientos hechos y lecturas del odómetro («hoy marca X km», tarea lectura_odometro con odometro_m obligatorio). '
  'nota: texto libre corto; la pantalla pide no escribir lugares ni talleres (el servidor no puede validarlo).';
-- El id v5 ya identifica (bicicleta, tarea, fecha): ningún cliente duplica un mantenimiento con otro id.
create unique index hab_bici_mantenimientos_natural
  on public.hab_bici_mantenimientos (persona_id, bicicleta_id, tarea, fecha);

-- Una salida por día y número (1 a 3). id: v5 de (persona, fecha, n). SIN ruta, SIN lugar (PB-04).
create table public.hab_bici_salidas (
  id             uuid primary key,
  persona_id     uuid not null references public.personas (id),
  hogar_id       uuid not null references public.hogares (id),
  fecha          date not null,
  n              smallint not null default 1 check (n between 1 and 3),
  bloque_id      uuid,
  bicicleta_id   uuid,
  inicio         time,
  duracion_min   smallint check (duracion_min between 1 and 1440),
  distancia_m    integer check (distancia_m between 0 and 1000000),
  desnivel_m     smallint check (desnivel_m between 0 and 20000),
  superficie     text check (superficie in ('calle', 'terreno', 'mixta')),
  esfuerzo       smallint check (esfuerzo between 1 and 5),
  clima          text check (clima in ('despejado', 'nublado', 'lluvia', 'calor', 'frio')),
  acompanado     boolean not null default false,   -- sin identificar a nadie
  estado         text not null check (estado in ('hecha', 'parcial', 'omitida')),
  motivo         text check (motivo in ('clima', 'seguridad', 'otra')),
  modificado_en  timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_bici_salidas_persona_id_key unique (persona_id, id),
  constraint hab_bici_salidas_dia_n unique (persona_id, fecha, n),
  constraint hab_bici_salidas_bloque_fk foreign key (persona_id, bloque_id)
    references public.hab_bloques (persona_id, id) on delete set null (bloque_id),
  constraint hab_bici_salidas_bicicleta_fk foreign key (persona_id, bicicleta_id)
    references public.hab_bici_bicicletas (persona_id, id) on delete set null (bicicleta_id),
  -- El motivo (clima, seguridad u otra) solo acompaña a una salida omitida; en las demás es nulo (5.2).
  constraint hab_bici_salidas_motivo check (motivo is null or estado = 'omitida')
);
comment on table public.hab_bici_salidas is
  'Una salida en bicicleta por día y número: solo números sin lugar (fecha, hora de inicio, duración, distancia en '
  'metros que escribe la persona, desnivel, superficie, esfuerzo, clima). NO enlaza con ninguna ruta ni guarda '
  'ubicación: eso es ubicacion_local, solo en el dispositivo. Una salida omitida (estado omitida) no suma al odómetro.';

-- Enlaces de música, compartidos con el gimnasio (PB-14). El esquema https se exige aquí; el dominio no se restringe.
create table public.hab_musica_listas (
  id             uuid primary key,
  persona_id     uuid not null references public.personas (id),
  hogar_id       uuid not null references public.hogares (id),
  nombre         text not null check (char_length(btrim(nombre)) between 1 and 60),
  actividad      text not null check (actividad in ('bicicleta', 'fuerza', 'regenerativo', 'traslado', 'devocional')),
  app            text not null check (app in ('spotify', 'amazon_music', 'otra')),
  enlace         text not null check (char_length(enlace) between 10 and 300
                                      and enlace ~ '^https://[^[:space:][:cntrl:]]+$'),
  orden          smallint not null check (orden between 1 and 20),
  modificado_en  timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_musica_listas_persona_id_key unique (persona_id, id)
);
comment on table public.hab_musica_listas is
  'Enlaces https a listas de música de la persona (Spotify, Amazon Music u otra app), por actividad. Compartida entre '
  'el gimnasio y la bicicleta. Solo el enlace: nada de lo que suena ni de cuentas.';

-- Índices: historial, sincronía y llaves foráneas (borrados y cascadas sin recorrer toda la tabla).
create index hab_bici_salidas_fecha_idx on public.hab_bici_salidas (persona_id, fecha desc);
create index hab_bici_salidas_act_idx on public.hab_bici_salidas (persona_id, actualizado_en);
create index hab_bici_salidas_bloque_idx on public.hab_bici_salidas (persona_id, bloque_id) where bloque_id is not null;
create index hab_bici_salidas_bicicleta_idx on public.hab_bici_salidas (persona_id, bicicleta_id) where bicicleta_id is not null;
create index hab_bici_mantenimientos_fecha_idx on public.hab_bici_mantenimientos (persona_id, bicicleta_id, fecha desc);
create index hab_bici_mantenimientos_act_idx on public.hab_bici_mantenimientos (persona_id, actualizado_en);
create index hab_bici_perfil_bicicleta_idx on public.hab_bici_perfil (persona_id, bicicleta_activa_id) where bicicleta_activa_id is not null;

-- -----------------------------------------------------------------------------
-- 2. Forma de los dos jsonb (lo que el servidor ve de ellos es lo único permitido)
-- -----------------------------------------------------------------------------
-- Triggers (SECURITY INVOKER; un trigger no necesita EXECUTE de quien escribe, así no quedan como RPC).
-- preparacion: lista de hasta 40 elementos. Un punto del catálogo es {id, activo} (id: ficha corta; activo: sí o no);
-- un punto propio es {texto} (1 a 60 caracteres, sin caracteres de control; activo opcional), hasta 10 propios.
create function public.hab_bici_validar_perfil()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  e jsonb;
  k text;
  v_propios integer := 0;
begin
  if new.preparacion is null then
    return new;  -- lo rechaza el NOT NULL de la columna
  end if;
  if jsonb_typeof(new.preparacion) is distinct from 'array' or jsonb_array_length(new.preparacion) > 40 then
    raise exception using errcode = '23514', message = 'La preparación es una lista de hasta 40 puntos.';
  end if;
  for e in select x.value from jsonb_array_elements(new.preparacion) x loop
    if jsonb_typeof(e) <> 'object' then
      raise exception using errcode = '23514', message = 'Cada punto de la preparación es un objeto.';
    end if;
    if e ? 'id' then
      for k in select x.key from jsonb_each(e) x loop
        if k not in ('id', 'activo') then
          raise exception using errcode = '23514', message = 'Un punto del catálogo solo admite id y activo.';
        end if;
      end loop;
      if jsonb_typeof(e -> 'id') is distinct from 'string' or (e ->> 'id') !~ '^[a-z][a-z0-9_]{0,39}$' then
        raise exception using errcode = '23514', message = 'El id de un punto de la preparación es una ficha corta del catálogo.';
      end if;
      if jsonb_typeof(e -> 'activo') is distinct from 'boolean' then
        raise exception using errcode = '23514', message = 'Cada punto del catálogo dice si está activo (sí o no).';
      end if;
    elsif e ? 'texto' then
      for k in select x.key from jsonb_each(e) x loop
        if k not in ('texto', 'activo') then
          raise exception using errcode = '23514', message = 'Un punto propio solo admite texto y activo.';
        end if;
      end loop;
      if jsonb_typeof(e -> 'texto') is distinct from 'string'
         or char_length(btrim(e ->> 'texto')) not between 1 and 60
         or (e ->> 'texto') ~ '[[:cntrl:]]' then
        raise exception using errcode = '23514', message = 'Un punto propio es un texto de 1 a 60 caracteres.';
      end if;
      if e ? 'activo' and jsonb_typeof(e -> 'activo') is distinct from 'boolean' then
        raise exception using errcode = '23514', message = 'activo de un punto propio es sí o no.';
      end if;
      v_propios := v_propios + 1;
      if v_propios > 10 then
        raise exception using errcode = '23514', message = 'Hasta 10 puntos propios en la preparación.';
      end if;
    else
      raise exception using errcode = '23514', message = 'Cada punto de la preparación lleva id (catálogo) o texto (propio).';
    end if;
  end loop;
  return new;
end
$$;
comment on function public.hab_bici_validar_perfil() is
  'Trigger de hab_bici_perfil: preparacion solo lleva puntos {id, activo} del catálogo o hasta 10 {texto} propios (23514 si no).';

-- intervalos: {tarea: {km, semanas}} solo de las cuatro tareas con intervalo; km de 1 a 100 000 y semanas de 1 a 520,
-- o nulo (un intervalo vacío desactiva esa parte de la tarea; un 0 se rechaza). Una tarea ausente usa el valor inicial.
create function public.hab_bici_validar_bicicleta()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  k text;
  v jsonb;
  c text;
  x jsonb;
  n numeric;
begin
  if new.intervalos is null then
    return new;  -- nulo = los valores iniciales
  end if;
  if jsonb_typeof(new.intervalos) is distinct from 'object' then
    raise exception using errcode = '23514', message = 'Los intervalos son un objeto {tarea: {km, semanas}}.';
  end if;
  for k, v in select t.key, t.value from jsonb_each(new.intervalos) t loop
    if k not in ('lubricar_cadena', 'limpiar_transmision', 'revisar_frenos_llantas', 'revision_general') then
      raise exception using errcode = '23514', message = 'Solo hay intervalos para las cuatro tareas del catálogo.';
    end if;
    if jsonb_typeof(v) <> 'object' then
      raise exception using errcode = '23514', message = 'El intervalo de una tarea es un objeto {km, semanas}.';
    end if;
    for c, x in select t.key, t.value from jsonb_each(v) t loop
      if c not in ('km', 'semanas') then
        raise exception using errcode = '23514', message = 'El intervalo de una tarea solo admite km y semanas.';
      end if;
      if jsonb_typeof(x) = 'null' then
        continue;
      end if;
      if jsonb_typeof(x) <> 'number' then
        raise exception using errcode = '23514', message = format('%s del intervalo es un número entero o nulo.', c);
      end if;
      n := (x #>> '{}')::numeric;
      if n <> trunc(n) or n < 1 or n > (case when c = 'km' then 100000 else 520 end) then
        raise exception using errcode = '23514', message = format('%s del intervalo fuera de rango.', c);
      end if;
    end loop;
  end loop;
  return new;
end
$$;
comment on function public.hab_bici_validar_bicicleta() is
  'Trigger de hab_bici_bicicletas: intervalos solo lleva {tarea: {km, semanas}} de las cuatro tareas del catálogo (23514 si no).';

-- -----------------------------------------------------------------------------
-- 3. RLS, triggers y reglas: lo propio, solo de quien tiene Hábitos
-- -----------------------------------------------------------------------------
-- hab_propio (20261105) pone persona y hogar, actualizado_en y aplica el último gana (un UPDATE más viejo se ignora;
-- uno a más de 5 minutos en el futuro se ajusta a la hora del servidor).
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['hab_bici_bicicletas', 'hab_bici_perfil', 'hab_bici_mantenimientos', 'hab_bici_salidas',
                                 'hab_musica_listas']
  loop
    execute format('alter table public.%I enable row level security', v_tabla);
    execute format('create trigger hab_a_propio before insert or update on public.%I
                      for each row execute function public.hab_propio()', v_tabla);
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                        with check (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    execute format($f$create policy %1$s_editar on public.%1$I for update to authenticated
                        using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))
                        with check (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    execute format($f$create policy %1$s_borrar on public.%1$I for delete to authenticated
                        using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    execute format('create trigger hab_z_cuota after insert on public.%I referencing new table as nuevas
                      for each statement execute function public.hab_cuota_filas()', v_tabla);
  end loop;
end
$$;

create trigger hab_b_validar before insert or update on public.hab_bici_perfil
  for each row execute function public.hab_bici_validar_perfil();
create trigger hab_b_validar before insert or update on public.hab_bici_bicicletas
  for each row execute function public.hab_bici_validar_bicicleta();

-- -----------------------------------------------------------------------------
-- 4. Cuota de filas (H-10): salidas 1 500, mantenimientos 2 000, bicicletas 20, listas de música 100, perfil 1
-- -----------------------------------------------------------------------------
-- Una tabla sin tope falla CERRADO. Se conservan todos los topes anteriores.
create or replace function public.hab_cuota_filas()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid;
  v_tope    integer := case tg_table_name
    when 'hab_objetivos' then 2000 when 'hab_bloques' then 5000 when 'hab_registros' then 20000
    when 'hab_pausas' then 500 when 'hab_planes_lectura' then 100 when 'hab_plan_dias' then 40000
    when 'hab_lecturas' then 20000 when 'hab_marcas_biblia' then 20000 when 'hab_revisiones' then 600
    when 'hab_ent_sesiones' then 3000 when 'hab_ent_series' then 60000 when 'hab_ent_inventario' then 200
    when 'hab_ent_bandas' then 50 when 'hab_ent_plan_dias' then 7 when 'hab_ent_perfil' then 1
    when 'hab_bici_salidas' then 1500 when 'hab_bici_mantenimientos' then 2000 when 'hab_bici_bicicletas' then 20
    when 'hab_bici_perfil' then 1 when 'hab_musica_listas' then 100 end;
  v_n       bigint;
begin
  if v_tope is null then
    raise exception using errcode = '55000',
      message = format('La tabla %s no tiene tope de filas en hab_cuota_filas.', tg_table_name);
  end if;
  for v_persona in select distinct n.persona_id from nuevas n loop
    execute format('select count(*) from public.%I where persona_id = $1', tg_table_name) into v_n using v_persona;
    if v_n > v_tope then
      raise exception using errcode = '54000',
        message = format('Se llegó al tope de %s filas en %s.', v_tope, tg_table_name),
        hint = 'Archiva o borra lo que ya no uses.';
    end if;
  end loop;
  return null;
end
$$;

-- -----------------------------------------------------------------------------
-- 5. Borrar mis datos: alcance nuevo «bicicleta» y las cinco tablas dentro de «todo»
-- -----------------------------------------------------------------------------
-- El alcance bicicleta no toca sobres ni modos ni epoca_nube (no hay nada en la nube cifrada que reiniciar) y, como
-- pide la especificación (5.2, CA-B-20), borra las cinco tablas, incluidos los enlaces de música (compartidos con el
-- gimnasio; el alcance entrenamiento NO los borra). Rutas y contacto no están aquí: se borran del equipo.
create or replace function public.hab_borrar_datos_de(p_persona_id uuid, p_alcance text)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if p_alcance in ('sensibles', 'todo') then
    delete from public.hab_sobres where persona_id = p_persona_id and tipo = 'habitos_sensibles';
  end if;
  if p_alcance in ('diario', 'todo') then
    delete from public.hab_sobres where persona_id = p_persona_id and tipo = 'diario_oracion';
  end if;
  if p_alcance in ('entrenamiento', 'todo') then
    delete from public.hab_ent_series where persona_id = p_persona_id;
    delete from public.hab_ent_sesiones where persona_id = p_persona_id;
    delete from public.hab_ent_plan_dias where persona_id = p_persona_id;
    delete from public.hab_ent_bandas where persona_id = p_persona_id;
    delete from public.hab_ent_inventario where persona_id = p_persona_id;
    delete from public.hab_ent_perfil where persona_id = p_persona_id;
  end if;
  if p_alcance in ('bicicleta', 'todo') then
    delete from public.hab_bici_mantenimientos where persona_id = p_persona_id;
    delete from public.hab_bici_salidas where persona_id = p_persona_id;
    delete from public.hab_bici_perfil where persona_id = p_persona_id;
    delete from public.hab_bici_bicicletas where persona_id = p_persona_id;
    delete from public.hab_musica_listas where persona_id = p_persona_id;
  end if;
  if p_alcance = 'todo' then
    delete from public.hab_llaves where persona_id = p_persona_id;
    delete from public.hab_registros where persona_id = p_persona_id;
    delete from public.hab_lecturas where persona_id = p_persona_id;
    delete from public.hab_marcas_biblia where persona_id = p_persona_id;
    delete from public.hab_revisiones where persona_id = p_persona_id;
    delete from public.hab_pausas where persona_id = p_persona_id;
    delete from public.hab_plan_dias where persona_id = p_persona_id;
    delete from public.hab_planes_lectura where persona_id = p_persona_id;
    delete from public.hab_bloques where persona_id = p_persona_id;
    delete from public.hab_objetivos where persona_id = p_persona_id;
    update public.hab_modos set modo = 'solo_telefono', cambiado_en = now() where persona_id = p_persona_id;
  end if;
  if p_alcance not in ('entrenamiento', 'bicicleta') then
    update public.hab_ajustes set epoca_nube = epoca_nube + 1 where persona_id = p_persona_id;
  end if;
end
$$;

create or replace function public.hab_borrar_mis_datos(p_alcance text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  perform public.hab_exigir_activa();
  if p_alcance not in ('sensibles', 'diario', 'entrenamiento', 'bicicleta', 'todo') then
    raise exception using errcode = '22023', message = 'El alcance es sensibles, diario, entrenamiento, bicicleta o todo.';
  end if;
  perform public.hab_borrar_datos_de(public.persona_actual(), p_alcance);
  perform public.hab_nota('habitos.borrar_datos');
end
$$;
comment on function public.hab_borrar_mis_datos(text) is
  'Borrado físico de lo propio: sensibles, diario, entrenamiento (las seis tablas hab_ent_*), bicicleta (las cinco '
  'tablas hab_bici_* y hab_musica_listas) o todo (también la llave y las tablas en claro; deja hab_ajustes). Deja una '
  'constancia sin contenido. No es un libro contable: se puede borrar.';

-- -----------------------------------------------------------------------------
-- 6. Privilegios (por columna; lo que pone el servidor no se manda)
-- -----------------------------------------------------------------------------
revoke all on table
  public.hab_bici_bicicletas, public.hab_bici_perfil, public.hab_bici_mantenimientos, public.hab_bici_salidas,
  public.hab_musica_listas
  from public, anon, authenticated, service_role;
grant select, delete on
  public.hab_bici_bicicletas, public.hab_bici_perfil, public.hab_bici_mantenimientos, public.hab_bici_salidas,
  public.hab_musica_listas
  to authenticated;
-- service_role: solo lectura (el respaldo y el mantenimiento borran con las funciones).
grant select on
  public.hab_bici_bicicletas, public.hab_bici_perfil, public.hab_bici_mantenimientos, public.hab_bici_salidas,
  public.hab_musica_listas
  to service_role;

grant insert (id, nombre, tipo, odometro_inicial_m, intervalos, activa, modificado_en),
      update (id, nombre, tipo, odometro_inicial_m, intervalos, activa, modificado_en)
  on public.hab_bici_bicicletas to authenticated;
grant insert (bicicleta_activa_id, duracion_prevista_min, margen_revision_min, carga_piernas, tope_aumento_pct,
              preparacion, intervalo_agua_min, intervalo_comida_min, aviso_visto_en, modificado_en),
      update (bicicleta_activa_id, duracion_prevista_min, margen_revision_min, carga_piernas, tope_aumento_pct,
              preparacion, intervalo_agua_min, intervalo_comida_min, aviso_visto_en, modificado_en)
  on public.hab_bici_perfil to authenticated;
grant insert (id, bicicleta_id, tarea, fecha, odometro_m, nota, modificado_en),
      update (id, bicicleta_id, tarea, fecha, odometro_m, nota, modificado_en)
  on public.hab_bici_mantenimientos to authenticated;
grant insert (id, fecha, n, bloque_id, bicicleta_id, inicio, duracion_min, distancia_m, desnivel_m, superficie,
              esfuerzo, clima, acompanado, estado, motivo, modificado_en),
      update (id, fecha, n, bloque_id, bicicleta_id, inicio, duracion_min, distancia_m, desnivel_m, superficie,
              esfuerzo, clima, acompanado, estado, motivo, modificado_en)
  on public.hab_bici_salidas to authenticated;
grant insert (id, nombre, actividad, app, enlace, orden, modificado_en),
      update (id, nombre, actividad, app, enlace, orden, modificado_en)
  on public.hab_musica_listas to authenticated;

-- Los triggers no necesitan EXECUTE de quien escribe; en public, authenticated lo recibe por omisión (quedaría como RPC).
revoke execute on function public.hab_bici_validar_perfil(), public.hab_bici_validar_bicicleta()
  from public, anon, authenticated, service_role;
