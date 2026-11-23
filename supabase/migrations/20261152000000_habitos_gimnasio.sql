-- =============================================================================
-- GRAVITY · Fase 8 · Hábitos · Entrenamiento propio (G2): tablas hab_ent_*
-- =============================================================================
-- docs/specs/fase-8-habitos-gimnasio.md, secciones 4.1 a 4.3, 9, 13.5 (CA-G-26 a CA-G-31), 16 (PG-02, PG-03,
-- PG-19) y 17 («pedidos a backend»). La especificación y sus propuestas PG-xx están vigentes (sección 20, G0
-- cerrado el 23/nov/2026).
--
-- Qué guarda el servidor: perfil, plan semanal, inventario del equipo, bandas, sesiones y series de UNA persona,
-- en claro y bajo RLS (como hab_registros): ni el dueño, ni la pareja, ni la cuenta maestra, ni Casa, ni el
-- cuidador, ni otro hogar, ni anon leen o escriben lo ajeno. Editables con último-gana (modificado_en); la
-- persona puede borrar lo suyo. Sin trigger de bitácora: el prefijo hab_ ya está protegido y oculto (20261105).
--
-- Qué NO guarda, nunca (4.3, PG-03): molestias, zonas, dolor, diagnósticos. No hay columna ni tabla para ellas y
-- el motivo de cambio de una serie no admite «molestia» (PG-19): si la persona cambia por una molestia, el
-- servidor ve «otra». Las molestias viven solo en el almacén local cifrado del dispositivo (tipo salud_local);
-- hab_sobres.tipo (20261106) sigue admitiendo solo los dos tipos de la nube, así que un error de la app que
-- intentara subirlas es rechazado.
--
-- Convención 12: los grant insert/update repiten la lista completa de columnas. Migración nueva (hacia adelante).
-- PostgreSQL 15 o superior (ON DELETE SET NULL con lista de columnas). Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tablas
-- -----------------------------------------------------------------------------
-- Una fila por persona (se crea al primer uso).
create table public.hab_ent_perfil (
  persona_id        uuid primary key references public.personas (id),
  hogar_id          uuid not null references public.hogares (id),
  dias_plan         smallint not null default 3 check (dias_plan in (3, 4, 5)),
  version_pref      text not null default 'auto' check (version_pref in ('auto', 'corta', 'estandar', 'larga')),
  ventana           text not null default 'noche' check (ventana in ('manana', 'noche', 'flexible')),
  noche_desde       time not null default '19:00',
  objetivo          text not null default 'salud_general'
                    check (objetivo in ('fuerza', 'masa', 'perdida_grasa', 'salud_general')),
  nivel             text not null default 'principiante' check (nivel in ('principiante', 'intermedio')),
  inicio_ciclo      date check (extract(isodow from inicio_ciclo) = 1),   -- lunes; nulo = aún no empieza el plan
  ciclo_semanas     smallint not null default 4 check (ciclo_semanas = 0 or ciclo_semanas between 3 and 8),
  descanso_s        smallint check (descanso_s between 30 and 120),        -- nulo = el de la versión
  margen_dormir_min smallint not null default 90 check (margen_dormir_min between 0 and 240),
  prueba_desde      date,
  prueba_ventana    text check (prueba_ventana in ('manana', 'noche')),
  voz_descanso      boolean not null default false,
  aviso_visto_en    timestamptz,
  modificado_en     timestamptz not null,
  actualizado_en    timestamptz not null default now(),
  constraint hab_ent_perfil_prueba check ((prueba_desde is null) = (prueba_ventana is null))
);
comment on table public.hab_ent_perfil is
  'Perfil de entrenamiento de una persona (una fila). Preferencias y fechas del ciclo; sin ningún dato de salud.';

-- Una fila por día de la semana (1 = lunes).
create table public.hab_ent_plan_dias (
  persona_id     uuid not null references public.personas (id),
  dia_semana     smallint not null check (dia_semana between 1 and 7),
  hogar_id       uuid not null references public.hogares (id),
  tipo           text not null check (tipo in ('A', 'B', 'C', 'R1', 'R2', 'bici', 'descanso')),
  version        text not null default 'auto' check (version in ('auto', 'corta', 'estandar', 'larga')),
  hora           time,
  modificado_en  timestamptz not null,
  actualizado_en timestamptz not null default now(),
  primary key (persona_id, dia_semana)
);
comment on table public.hab_ent_plan_dias is 'Plan semanal de entrenamiento: qué plantilla toca cada día (lunes a domingo).';

-- Un aparato, puesto o accesorio por fila. item_id: id del catálogo (marcy.press) o un puesto suelto (otro:<texto>).
create table public.hab_ent_inventario (
  persona_id     uuid not null references public.personas (id),
  item_id        text not null check (char_length(item_id) between 1 and 60
                                      and (item_id ~ '^[a-z0-9][a-z0-9_.:-]*$'
                                           or item_id ~ '^otro:[^[:cntrl:]]{1,55}$')),
  hogar_id       uuid not null references public.hogares (id),
  estado         text not null check (estado in ('disponible', 'no_disponible', 'futuro')),
  confirmado     jsonb not null default '{}'::jsonb
                 check (jsonb_typeof(confirmado) = 'object' and octet_length(confirmado::text) <= 2048),
  notas          text check (char_length(notas) <= 200),
  modificado_en  timestamptz not null,
  actualizado_en timestamptz not null default now(),
  primary key (persona_id, item_id)
);
comment on table public.hab_ent_inventario is
  'Inventario del equipo de la persona. confirmado: solo datos del aparato (pasos de la pila, kg por paso, polea, '
  'capacidad del banco…); la forma la valida hab_ent_validar_inventario. Datos de equipo, no de salud.';

-- Las bandas de la persona.
create table public.hab_ent_bandas (
  id                 uuid primary key,
  persona_id         uuid not null references public.personas (id),
  hogar_id           uuid not null references public.hogares (id),
  nombre             text not null check (char_length(btrim(nombre)) between 1 and 40),
  orden              smallint not null check (orden between 1 and 20),
  resistencia_kg_x10 smallint check (resistencia_kg_x10 between 1 and 2000),
  cantidad           smallint not null check (cantidad between 1 and 10),
  activa             boolean not null default true,
  modificado_en      timestamptz not null,
  actualizado_en     timestamptz not null default now(),
  constraint hab_ent_bandas_persona_id_key unique (persona_id, id)
);
comment on table public.hab_ent_bandas is
  'Bandas de resistencia de la persona; el orden (de la más ligera a la más fuerte) lo pone ella.';

-- Una sesión por día y plantilla. id: v5 de (persona, fecha, plantilla): dos equipos convergen.
create table public.hab_ent_sesiones (
  id               uuid primary key,
  persona_id       uuid not null references public.personas (id),
  hogar_id         uuid not null references public.hogares (id),
  fecha            date not null,
  plantilla        text not null check (plantilla in ('A', 'B', 'C', 'R1', 'R2')),
  version          text not null check (version in ('corta', 'estandar', 'larga')),
  semana_tipo      text not null check (semana_tipo in ('carga', 'descarga', 'reentrada', 'foco')),
  ventana          text not null check (ventana in ('manana', 'noche')),
  bloque_id        uuid,
  inicio           timestamptz not null,
  fin              timestamptz,
  estado           text not null check (estado in ('en_curso', 'completa', 'parcial')),
  esfuerzo         smallint check (esfuerzo between 1 and 5),
  energia          smallint check (energia between 1 and 5),
  plan             jsonb not null default '[]'::jsonb check (octet_length(plan::text) <= 2048),
  catalogo_version smallint not null check (catalogo_version >= 1),
  modificado_en    timestamptz not null,
  actualizado_en   timestamptz not null default now(),
  constraint hab_ent_sesiones_persona_id_key unique (persona_id, id),
  constraint hab_ent_sesiones_dia_plantilla unique (persona_id, fecha, plantilla),
  constraint hab_ent_sesiones_bloque_fk foreign key (persona_id, bloque_id)
    references public.hab_bloques (persona_id, id) on delete set null (bloque_id),
  constraint hab_ent_sesiones_fin check (fin is null or fin >= inicio),
  constraint hab_ent_sesiones_en_curso check ((estado = 'en_curso') = (fin is null))
);
comment on table public.hab_ent_sesiones is
  'Una sesión de entrenamiento por día y plantilla. En curso (fin nulo) hasta que la persona la termina. plan: lo '
  'planeado, solo ejercicio, variante, series y repeticiones (forma validada por hab_ent_validar_sesion).';

-- Una por serie hecha. id: v5 de (persona, sesión, ejercicio, número, lado).
create table public.hab_ent_series (
  id              uuid primary key,
  persona_id      uuid not null references public.personas (id),
  hogar_id        uuid not null references public.hogares (id),
  sesion_id       uuid not null,
  ejercicio_id    text not null check (ejercicio_id ~ '^[a-z0-9][a-z0-9_.:-]{0,59}$'),
  variante_id     text not null check (variante_id ~ '^[a-z0-9][a-z0-9_.:-]{0,59}$'),
  n               smallint not null check (n between 1 and 12),
  lado            text check (lado in ('izquierdo', 'derecho')),
  reps            smallint check (reps between 0 and 100),
  segundos        smallint check (segundos between 0 and 900),
  carga_pasos     smallint check (carga_pasos between 0 and 60),
  banda_id        uuid,
  esfuerzo        smallint check (esfuerzo between 1 and 5),
  descanso_real_s smallint check (descanso_real_s between 0 and 900),
  sustituye_a     text check (sustituye_a ~ '^[a-z0-9][a-z0-9_.:-]{0,59}$'),
  -- PG-19: el motivo «molestia» NO existe aquí a propósito; el servidor ve «otra».
  motivo_cambio   text check (motivo_cambio in ('no_disponible', 'preferencia', 'otra')),
  modificado_en   timestamptz not null,
  actualizado_en  timestamptz not null default now(),
  constraint hab_ent_series_sesion_fk foreign key (persona_id, sesion_id)
    references public.hab_ent_sesiones (persona_id, id) on delete cascade,
  constraint hab_ent_series_banda_fk foreign key (persona_id, banda_id)
    references public.hab_ent_bandas (persona_id, id) on delete set null (banda_id)
);
comment on table public.hab_ent_series is
  'Una serie hecha: repeticiones o segundos, carga en pasos de la pila (PG-04) o banda, esfuerzo y descanso real. '
  'Sin molestias ni zonas: motivo_cambio solo admite no_disponible, preferencia u otra.';
-- El id v5 ya identifica (sesión, ejercicio, número, lado): ningún cliente duplica una serie con otro id.
create unique index hab_ent_series_natural
  on public.hab_ent_series (persona_id, sesion_id, ejercicio_id, n, coalesce(lado, ''));

-- Índices: historial, récords y llaves foráneas (borrados y cascadas sin recorrer toda la tabla).
create index hab_ent_sesiones_fecha_idx on public.hab_ent_sesiones (persona_id, fecha desc);
create index hab_ent_sesiones_act_idx on public.hab_ent_sesiones (persona_id, actualizado_en);
create index hab_ent_sesiones_bloque_idx on public.hab_ent_sesiones (persona_id, bloque_id) where bloque_id is not null;
create index hab_ent_series_ejercicio_idx on public.hab_ent_series (persona_id, ejercicio_id, variante_id);
create index hab_ent_series_act_idx on public.hab_ent_series (persona_id, actualizado_en);
create index hab_ent_series_banda_idx on public.hab_ent_series (persona_id, banda_id) where banda_id is not null;

-- -----------------------------------------------------------------------------
-- 2. Forma de los dos jsonb (lo que el servidor ve de ellos es lo único permitido)
-- -----------------------------------------------------------------------------
-- Triggers (SECURITY INVOKER; un trigger no necesita EXECUTE de quien escribe, así no quedan como RPC).
-- plan: lista de hasta 40 objetos con SOLO ejercicio, variante, series, reps_min y reps_max.
create function public.hab_ent_validar_sesion()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  c_id constant text := '^[a-z0-9][a-z0-9_.:-]{0,59}$';
  e jsonb;
  k text;
  v jsonb;
  n numeric;
begin
  if new.plan is null then
    return new;  -- lo rechaza el NOT NULL de la columna
  end if;
  if jsonb_typeof(new.plan) is distinct from 'array' or jsonb_array_length(new.plan) > 40 then
    raise exception using errcode = '23514', message = 'El plan de la sesión es una lista de hasta 40 ejercicios.';
  end if;
  for e in select x.value from jsonb_array_elements(new.plan) x loop
    if jsonb_typeof(e) <> 'object' then
      raise exception using errcode = '23514', message = 'Cada ejercicio del plan es un objeto.';
    end if;
    if jsonb_typeof(e -> 'ejercicio') is distinct from 'string' or (e ->> 'ejercicio') !~ c_id then
      raise exception using errcode = '23514', message = 'Cada ejercicio del plan lleva el id del catálogo.';
    end if;
    for k, v in select x.key, x.value from jsonb_each(e) x loop
      if k not in ('ejercicio', 'variante', 'series', 'reps_min', 'reps_max') then
        raise exception using errcode = '23514',
          message = 'El plan solo admite ejercicio, variante, series, reps_min y reps_max.';
      end if;
      if k = 'variante' then
        if jsonb_typeof(v) <> 'null' and (jsonb_typeof(v) <> 'string' or (v #>> '{}') !~ c_id) then
          raise exception using errcode = '23514', message = 'La variante del plan es un id del catálogo.';
        end if;
      elsif k <> 'ejercicio' and jsonb_typeof(v) <> 'null' then
        if jsonb_typeof(v) <> 'number' then
          raise exception using errcode = '23514', message = format('%s del plan es un número entero.', k);
        end if;
        n := (v #>> '{}')::numeric;
        if n <> trunc(n) or n < 0 or n > (case when k = 'series' then 12 else 100 end) then
          raise exception using errcode = '23514', message = format('%s del plan fuera de rango.', k);
        end if;
      end if;
    end loop;
    if jsonb_typeof(e -> 'reps_min') = 'number' and jsonb_typeof(e -> 'reps_max') = 'number'
       and (e ->> 'reps_min')::numeric > (e ->> 'reps_max')::numeric then
      raise exception using errcode = '23514', message = 'reps_min no puede ser mayor que reps_max.';
    end if;
  end loop;
  return new;
end
$$;
comment on function public.hab_ent_validar_sesion() is
  'Trigger de hab_ent_sesiones: el plan solo lleva ejercicio, variante, series, reps_min y reps_max (23514 si no).';

-- confirmado: pares campo → valor del aparato (hasta 20); campos en minúsculas; valores números, booleanos o
-- fichas cortas (letras minúsculas, dígitos y . : _ - /); nunca frases. Nada que insinúe salud.
create function public.hab_ent_validar_inventario()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  k text;
  v jsonb;
begin
  if new.confirmado is null then
    return new;  -- lo rechaza el NOT NULL de la columna
  end if;
  if jsonb_typeof(new.confirmado) is distinct from 'object' or (select count(*) from jsonb_object_keys(new.confirmado)) > 20 then
    raise exception using errcode = '23514', message = 'Lo confirmado del aparato es un objeto de hasta 20 campos.';
  end if;
  for k, v in select x.key, x.value from jsonb_each(new.confirmado) x loop
    if k !~ '^[a-z][a-z0-9_]{0,39}$' then
      raise exception using errcode = '23514', message = 'Los campos confirmados van en minúsculas, dígitos y guion bajo (hasta 40).';
    end if;
    if k ~ '(molest|dolor|duel|lesi|diagn|sintom|zona|salud|fisio|medic)' then
      raise exception using errcode = '23514', message = 'El inventario guarda datos del aparato, no de salud.';
    end if;
    if jsonb_typeof(v) not in ('number', 'boolean', 'null', 'string')
       or (jsonb_typeof(v) = 'string' and (v #>> '{}') !~ '^[a-z0-9][a-z0-9_.:/-]{0,39}$') then
      raise exception using errcode = '23514', message = 'Cada valor confirmado es un número, un sí o no, o una ficha corta.';
    end if;
  end loop;
  return new;
end
$$;
comment on function public.hab_ent_validar_inventario() is
  'Trigger de hab_ent_inventario: confirmado solo lleva datos del aparato (23514 si no).';

-- -----------------------------------------------------------------------------
-- 3. RLS, triggers y reglas: lo propio, solo de quien tiene Hábitos
-- -----------------------------------------------------------------------------
-- hab_propio (20261105) pone persona y hogar, actualizado_en y aplica el último gana (un UPDATE más viejo se ignora;
-- uno a más de 5 minutos en el futuro se ajusta a la hora del servidor).
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['hab_ent_perfil', 'hab_ent_plan_dias', 'hab_ent_inventario', 'hab_ent_bandas',
                                 'hab_ent_sesiones', 'hab_ent_series']
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

create trigger hab_b_validar before insert or update on public.hab_ent_sesiones
  for each row execute function public.hab_ent_validar_sesion();
create trigger hab_b_validar before insert or update on public.hab_ent_inventario
  for each row execute function public.hab_ent_validar_inventario();

-- -----------------------------------------------------------------------------
-- 4. Cuota de filas (H-10): sesiones 3 000, series 60 000, inventario 200, bandas 50, plan 7, perfil 1
-- -----------------------------------------------------------------------------
-- Una tabla sin tope falla CERRADO (antes un CASE sin tope no limitaba nada en silencio).
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
    when 'hab_ent_bandas' then 50 when 'hab_ent_plan_dias' then 7 when 'hab_ent_perfil' then 1 end;
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
-- 5. Borrar mis datos: alcance nuevo «entrenamiento» y las seis tablas dentro de «todo»
-- -----------------------------------------------------------------------------
-- El alcance entrenamiento no toca sobres ni modos ni epoca_nube (no hay nada en la nube cifrada que reiniciar).
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
  if p_alcance <> 'entrenamiento' then
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
  if p_alcance not in ('sensibles', 'diario', 'entrenamiento', 'todo') then
    raise exception using errcode = '22023', message = 'El alcance es sensibles, diario, entrenamiento o todo.';
  end if;
  perform public.hab_borrar_datos_de(public.persona_actual(), p_alcance);
  perform public.hab_nota('habitos.borrar_datos');
end
$$;
comment on function public.hab_borrar_mis_datos(text) is
  'Borrado físico de lo propio: sensibles, diario, entrenamiento (las seis tablas hab_ent_*) o todo (también la llave y '
  'las tablas en claro; deja hab_ajustes). Deja una constancia sin contenido. No es un libro contable: se puede borrar.';

-- -----------------------------------------------------------------------------
-- 6. Privilegios (por columna; lo que pone el servidor no se manda)
-- -----------------------------------------------------------------------------
revoke all on table
  public.hab_ent_perfil, public.hab_ent_plan_dias, public.hab_ent_inventario, public.hab_ent_bandas,
  public.hab_ent_sesiones, public.hab_ent_series
  from public, anon, authenticated, service_role;
grant select, delete on
  public.hab_ent_perfil, public.hab_ent_plan_dias, public.hab_ent_inventario, public.hab_ent_bandas,
  public.hab_ent_sesiones, public.hab_ent_series
  to authenticated;
-- service_role: solo lectura (el respaldo y el mantenimiento borran con las funciones).
grant select on
  public.hab_ent_perfil, public.hab_ent_plan_dias, public.hab_ent_inventario, public.hab_ent_bandas,
  public.hab_ent_sesiones, public.hab_ent_series
  to service_role;

grant insert (dias_plan, version_pref, ventana, noche_desde, objetivo, nivel, inicio_ciclo, ciclo_semanas,
              descanso_s, margen_dormir_min, prueba_desde, prueba_ventana, voz_descanso, aviso_visto_en, modificado_en),
      update (dias_plan, version_pref, ventana, noche_desde, objetivo, nivel, inicio_ciclo, ciclo_semanas,
              descanso_s, margen_dormir_min, prueba_desde, prueba_ventana, voz_descanso, aviso_visto_en, modificado_en)
  on public.hab_ent_perfil to authenticated;
grant insert (dia_semana, tipo, version, hora, modificado_en),
      update (dia_semana, tipo, version, hora, modificado_en)
  on public.hab_ent_plan_dias to authenticated;
grant insert (item_id, estado, confirmado, notas, modificado_en),
      update (item_id, estado, confirmado, notas, modificado_en)
  on public.hab_ent_inventario to authenticated;
grant insert (id, nombre, orden, resistencia_kg_x10, cantidad, activa, modificado_en),
      update (id, nombre, orden, resistencia_kg_x10, cantidad, activa, modificado_en)
  on public.hab_ent_bandas to authenticated;
grant insert (id, fecha, plantilla, version, semana_tipo, ventana, bloque_id, inicio, fin, estado, esfuerzo, energia,
              plan, catalogo_version, modificado_en),
      update (id, fecha, plantilla, version, semana_tipo, ventana, bloque_id, inicio, fin, estado, esfuerzo, energia,
              plan, catalogo_version, modificado_en)
  on public.hab_ent_sesiones to authenticated;
grant insert (id, sesion_id, ejercicio_id, variante_id, n, lado, reps, segundos, carga_pasos, banda_id, esfuerzo,
              descanso_real_s, sustituye_a, motivo_cambio, modificado_en),
      update (id, sesion_id, ejercicio_id, variante_id, n, lado, reps, segundos, carga_pasos, banda_id, esfuerzo,
              descanso_real_s, sustituye_a, motivo_cambio, modificado_en)
  on public.hab_ent_series to authenticated;

-- Los triggers no necesitan EXECUTE de quien escribe; en public, authenticated lo recibe por omisión (quedaría como RPC).
revoke execute on function public.hab_ent_validar_sesion(), public.hab_ent_validar_inventario()
  from public, anon, authenticated, service_role;
