-- =============================================================================
-- GRAVITY · Fase 3 · Hábitos (tablas en claro, por persona) · D21 (propuesta)
-- =============================================================================
-- docs/specs/fase-3-habitos.md (secciones 4.1, 4.4, 4.5 y 4.6) y D21. Todo registro es de UNA persona:
-- ni el dueño, ni la pareja, ni la cuenta maestra, ni familiar ajeno, cuidador, Hogar o papá leen lo ajeno.
-- Las tablas hab_* NO tienen trigger de bitácora (la bitácora diría cuándo registra algo otra persona) y el
-- prefijo habitos* de la bitácora queda reservado al servidor y oculto al dueño y a la maestra.
-- Decisiones del dueño (commit 42f5251): sensibles solo teléfono por omisión (modo solo_telefono); la tablet
-- PERSONAL funciona como el teléfono (la pública nunca); lo de una persona dada de baja se conserva sin acceso
-- y se borra a los 90 días (hab_limpiar, en 20261106).
-- Convención 12: los grant insert/update repiten la lista completa de columnas.
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Quién tiene Hábitos
-- -----------------------------------------------------------------------------
-- Persona con Hábitos en el hogar: dueño, coadministrador o familiar, con membresía vigente, que NO sea la cuenta
-- maestra sin ser dueña (la maestra es solo lectura total y Hábitos queda fuera de lo que ve; una dueña que además
-- es maestra sigue usando Hábitos con su persona). Cuidador y Hogar (casa) no.
create function public.hab_miembro_activo(p_hogar_id uuid, p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.membresias m
    join public.permisos_rol pr on pr.rol = m.rol and pr.modulo = 'habitos' and pr.accion = 'leer'
    where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
      and pr.alcance = 'propio'
      and not (m.es_maestra and m.rol <> 'dueno'))
$$;
comment on function public.hab_miembro_activo(uuid, uuid) is
  'La persona tiene Hábitos en ese hogar (rol con alcance propio, membresía vigente, no cuenta maestra sin ser dueña).';

create function public.hab_activa(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.persona_actual() is not null and public.hab_miembro_activo(p_hogar_id, public.persona_actual()), false)
$$;
comment on function public.hab_activa(uuid) is
  'La sesión tiene Hábitos en ese hogar. Cuidador, Hogar y la cuenta maestra no leen ni escriben nada.';

create function public.hab_hogar_de(p_persona_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select m.hogar_id from public.membresias m
   where m.persona_id = p_persona_id and public.hab_miembro_activo(m.hogar_id, p_persona_id)
   order by m.desde desc, m.id limit 1
$$;

-- -----------------------------------------------------------------------------
-- 2. Tablas
-- -----------------------------------------------------------------------------
create table public.hab_ajustes (
  persona_id            uuid primary key references public.personas (id),
  hogar_id              uuid not null references public.hogares (id),
  areas_activas         text[] not null default '{espiritual,salud,educacion,personal,laboral,proyectos}',
  minimos_modo          text not null default 'por_area' check (minimos_modo in ('por_area', 'marcados')),
  gracia_semanal        smallint not null default 1 check (gracia_semanal between 0 and 2),
  despertar             time,
  dormir                time,
  franjas               jsonb check (octet_length(franjas::text) <= 4096),
  revision_dia          smallint not null default 6 check (revision_dia between 1 and 7),
  revision_hora         time not null default '14:30',
  revision_aviso_min    smallint not null default 15 check (revision_aviso_min between 0 and 120),
  dar_activo            boolean not null default false,
  dar_dia               smallint check (dar_dia between 1 and 7),
  dar_hora              time,
  versiones_biblia      text[] not null default '{rvr1909,kjv}',
  version_principal     text check (char_length(version_principal) <= 20),
  version_secundaria    text check (char_length(version_secundaria) <= 20),
  aviso_nombre_objetivos boolean not null default false,
  etiqueta_atajo        text not null default 'Pausa' check (char_length(etiqueta_atajo) between 1 and 20),
  bloqueo_reservado_min smallint not null default 2 check (bloqueo_reservado_min between 0 and 60),
  umbral_carga_pb       smallint[] not null default '{5000,8500}' check (cardinality(umbral_carga_pb) = 2),
  asistente             jsonb check (octet_length(asistente::text) <= 8192),
  epoca_nube            integer not null default 0 check (epoca_nube >= 0),
  modificado_en         timestamptz not null default now(),
  actualizado_en        timestamptz not null default now()
);
comment on table public.hab_ajustes is
  'Ajustes de Hábitos de una persona (una fila; la crea el servidor, la app solo hace UPDATE). Sin ninguna palabra '
  'clave sensible: los hábitos a eliminar no aparecen aquí. epoca_nube la sube el servidor al borrar sobres.';

create table public.hab_modos (
  persona_id uuid not null references public.personas (id),
  hogar_id   uuid not null references public.hogares (id),
  tipo       text not null check (tipo in ('habitos_sensibles', 'diario_oracion')),
  modo       text not null default 'solo_telefono' check (modo in ('solo_telefono', 'nube_cifrada')),
  cambiado_en timestamptz not null default now(),
  primary key (persona_id, tipo)
);
comment on table public.hab_modos is
  'Modo de cada tipo sensible. Ambos nacen solo_telefono (nada sale del teléfono). Solo cambia con hab_cambiar_modo.';

create table public.hab_objetivos (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  persona_id     uuid not null references public.personas (id),
  titulo         text not null check (char_length(btrim(titulo)) between 1 and 120),
  area           text not null check (area in ('espiritual', 'salud', 'educacion', 'personal', 'laboral', 'proyectos')),
  tipo           text not null check (tipo in ('construir', 'meta', 'proyecto')),
  unidad         text check (char_length(unidad) <= 20),
  meta_valor     integer check (meta_valor > 0),
  frecuencia     text not null default 'diaria' check (frecuencia in ('diaria', 'dias_semana', 'n_por_semana', 'semanal', 'total')),
  dias_semana    smallint check (dias_semana between 0 and 127),
  veces_por_semana smallint check (veces_por_semana between 1 and 7),
  fecha_inicio   date not null,
  fecha_objetivo date,
  prioridad      smallint not null default 3 check (prioridad between 1 and 5),
  minimo         boolean not null default false,
  esencial       boolean not null default false,
  motivo         text check (char_length(motivo) <= 200),
  nombre_en_aviso boolean not null default false,
  plantilla      text check (char_length(plantilla) <= 60),
  estado         text not null default 'activo' check (estado in ('activo', 'pausado', 'logrado', 'archivado')),
  hitos          jsonb check (jsonb_typeof(hitos) = 'array' and octet_length(hitos::text) <= 16384),
  modificado_en  timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_objetivos_persona_id_key unique (persona_id, id),
  constraint hab_objetivos_hitos_proyecto check (hitos is null or tipo = 'proyecto'),
  constraint hab_objetivos_fechas check (fecha_objetivo is null or fecha_objetivo >= fecha_inicio)
);
comment on table public.hab_objetivos is
  'Objetivos no sensibles. No existe el tipo eliminar: vive en el documento cifrado. No se borran desde la app: se archivan.';

create table public.hab_bloques (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  titulo        text not null check (char_length(btrim(titulo)) between 1 and 120),
  area          text not null check (area in ('espiritual', 'salud', 'educacion', 'personal', 'laboral', 'proyectos')),
  tipo          text not null check (tipo in ('actividad', 'trabajo', 'traslado', 'revision', 'cita')),
  objetivo_id   uuid,
  inicio        time not null,
  duracion_min  smallint not null check (duracion_min between 0 and 1440),
  dias          smallint not null check (dias between 0 and 127),
  cada_semanas  smallint not null default 1 check (cada_semanas between 1 and 52),
  desde         date not null,
  hasta         date,
  minimo        boolean not null default false,
  esencial      boolean not null default false,
  recordar_min  smallint check (recordar_min between 0 and 1440),
  activo        boolean not null default true,
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_bloques_persona_id_key unique (persona_id, id),
  constraint hab_bloques_objetivo_fk foreign key (persona_id, objetivo_id) references public.hab_objetivos (persona_id, id) on delete cascade,
  constraint hab_bloques_fechas check (hasta is null or hasta >= desde)
);

create table public.hab_registros (
  id            uuid primary key,
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  objetivo_id   uuid,
  bloque_id     uuid,
  fecha         date not null,
  estado        text not null default 'pendiente' check (estado in ('pendiente', 'hecho', 'parcial', 'omitido', 'pospuesto')),
  valor         integer check (valor >= 0),
  movido_a      time,
  motivo_omision text check (motivo_omision in ('cansancio', 'sin_tiempo', 'imprevisto', 'otro')),
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_registros_elemento check (objetivo_id is not null or bloque_id is not null),
  constraint hab_registros_objetivo_fk foreign key (persona_id, objetivo_id) references public.hab_objetivos (persona_id, id) on delete cascade,
  constraint hab_registros_bloque_fk foreign key (persona_id, bloque_id) references public.hab_bloques (persona_id, id) on delete cascade
);
create unique index hab_registros_un_elemento_por_dia on public.hab_registros (persona_id, coalesce(bloque_id, objetivo_id), fecha);
create index hab_registros_fecha_idx on public.hab_registros (persona_id, fecha);

create table public.hab_pausas (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  objetivo_id   uuid,
  desde         date not null,
  hasta         date not null,
  motivo        text not null check (motivo in ('descanso', 'viaje', 'salud', 'otra')),
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_pausas_fechas check (hasta >= desde),
  constraint hab_pausas_objetivo_fk foreign key (persona_id, objetivo_id) references public.hab_objetivos (persona_id, id) on delete cascade
);

create table public.hab_planes_lectura (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  tipo          text not null check (tipo in ('ruta_inicio', 'nt_90', 'salmos_proverbios_30', 'biblia_1_ano', 'libro')),
  nombre        text not null check (char_length(btrim(nombre)) between 1 and 80),
  fecha_inicio  date not null,
  dias_semana   smallint not null default 127 check (dias_semana between 1 and 127),
  version_biblica text not null check (version_biblica in ('rvr1909', 'kjv')),
  estado        text not null default 'activo' check (estado in ('activo', 'pausado', 'terminado', 'archivado')),
  libro         smallint check (libro between 1 and 66),
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_planes_persona_id_key unique (persona_id, id),
  constraint hab_planes_libro check ((tipo = 'libro') = (libro is not null))
);

create table public.hab_plan_dias (
  plan_id       uuid not null,
  dia           integer not null check (dia between 1 and 400),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  fecha         date not null,
  segmentos     jsonb not null check (jsonb_typeof(segmentos) = 'array' and octet_length(segmentos::text) <= 4096),
  estado        text not null default 'pendiente' check (estado in ('pendiente', 'hecho', 'parcial', 'saltado')),
  hecho_en      timestamptz,
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  primary key (plan_id, dia),
  constraint hab_plan_dias_plan_fk foreign key (persona_id, plan_id) references public.hab_planes_lectura (persona_id, id) on delete cascade
);

create table public.hab_lecturas (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  fecha         date not null,
  libro         smallint not null check (libro between 1 and 66),
  cap_ini       smallint not null check (cap_ini between 1 and 150),
  cap_fin       smallint not null check (cap_fin between 1 and 150),
  minutos       smallint check (minutos between 0 and 1440),
  plan_id       uuid,
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_lecturas_caps check (cap_fin >= cap_ini),
  constraint hab_lecturas_plan_fk foreign key (persona_id, plan_id) references public.hab_planes_lectura (persona_id, id) on delete cascade
);

create table public.hab_marcas_biblia (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  tipo          text not null check (tipo in ('subrayado', 'marcador')),
  referencia    text not null check (referencia ~ '^[0-9]{1,2}:[0-9]{1,3}:[0-9]{1,3}(-[0-9]{1,3})?$'),
  color         text check (color ~ '^[a-z]{1,20}$'),
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_marcas_color check ((tipo = 'subrayado') = (color is not null))
);
comment on table public.hab_marcas_biblia is 'Sin texto libre: las notas del lector son sensibles (van en el documento cifrado).';

create table public.hab_revisiones (
  id            uuid primary key,
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  semana        date not null check (extract(isodow from semana) = 1),
  estado        text not null default 'pendiente' check (estado in ('pendiente', 'en_curso', 'completada', 'omitida')),
  programada_para timestamptz,
  completada_en timestamptz,
  resumen       jsonb check (octet_length(resumen::text) <= 8192),
  ajustes       jsonb check (octet_length(ajustes::text) <= 8192),
  dar_cumplido  boolean,
  modificado_en timestamptz not null,
  actualizado_en timestamptz not null default now(),
  constraint hab_revisiones_semana_unica unique (persona_id, semana)
);

-- -----------------------------------------------------------------------------
-- 3. Triggers: lo propio lo pone el servidor y el último cambio gana
-- -----------------------------------------------------------------------------
-- SECURITY INVOKER a propósito (necesita current_user): lo que manda la app (rol authenticated) no cambia de
-- persona ni de hogar, y un UPDATE con modificado_en más viejo se ignora sin error (convención 6); uno más de
-- 5 minutos en el futuro se ajusta a la hora del servidor. Las funciones del servidor no pasan por la regla.
create function public.hab_propio()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if public.persona_actual() is not null and current_user = 'authenticated' then
      new.persona_id := public.persona_actual();
      new.hogar_id := public.hab_hogar_de(new.persona_id);
    else
      new.persona_id := coalesce(new.persona_id, public.persona_actual());
      new.hogar_id := coalesce(new.hogar_id, public.hab_hogar_de(new.persona_id));
    end if;
    if new.hogar_id is null then
      raise exception using errcode = '42501', message = 'Esa persona no tiene Hábitos en ningún hogar.';
    end if;
    new.actualizado_en := now();
    if to_jsonb(new) ? 'modificado_en' and new.modificado_en > now() + interval '5 minutes' then
      new.modificado_en := now();
    end if;
    return new;
  end if;
  -- UPDATE
  if new.persona_id is distinct from old.persona_id or new.hogar_id is distinct from old.hogar_id then
    raise exception using errcode = '42501', message = 'La persona y el hogar de un registro de Hábitos no cambian.';
  end if;
  new.actualizado_en := now();
  if current_user = 'authenticated' then
    if new.modificado_en < old.modificado_en then
      return null;  -- el último cambio gana: este es más viejo y se ignora
    end if;
    if new.modificado_en > now() + interval '5 minutes' then
      new.modificado_en := now();
    end if;
  end if;
  return new;
end
$$;
comment on function public.hab_propio() is
  'Trigger de las tablas hab_*: pone persona y hogar, actualizado_en, y aplica el último cambio gana (hab_ultimo_gana).';

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['hab_ajustes', 'hab_objetivos', 'hab_bloques', 'hab_registros', 'hab_pausas',
      'hab_planes_lectura', 'hab_plan_dias', 'hab_lecturas', 'hab_marcas_biblia', 'hab_revisiones']
  loop
    execute format('alter table public.%I enable row level security', v_tabla);
    execute format('create trigger hab_a_propio before insert or update on public.%I
                      for each row execute function public.hab_propio()', v_tabla);
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    execute format($f$create policy %1$s_editar on public.%1$I for update to authenticated
                        using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))
                        with check (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    if v_tabla <> 'hab_ajustes' then
      execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                          with check (public.hab_activa(public.hab_hogar_de((select public.persona_actual()))))$f$, v_tabla);
      execute format($f$create policy %1$s_borrar on public.%1$I for delete to authenticated
                          using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id))$f$, v_tabla);
    end if;
  end loop;
end
$$;

alter table public.hab_modos enable row level security;
create policy hab_modos_leer on public.hab_modos for select to authenticated
  using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id));

-- -----------------------------------------------------------------------------
-- 4. Iniciar Hábitos al dar un rol con Hábitos (y a quien ya lo tenía)
-- -----------------------------------------------------------------------------
create function public.hab_iniciar_persona(p_hogar_id uuid, p_persona_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if not public.hab_miembro_activo(p_hogar_id, p_persona_id) then
    return;
  end if;
  insert into public.hab_ajustes (persona_id, hogar_id) values (p_persona_id, p_hogar_id) on conflict (persona_id) do nothing;
  insert into public.hab_modos (persona_id, hogar_id, tipo)
  select p_persona_id, p_hogar_id, t from unnest(array['habitos_sensibles', 'diario_oracion']) t
  on conflict (persona_id, tipo) do nothing;
end
$$;

create function public.hab_iniciar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  perform public.hab_iniciar_persona(new.hogar_id, new.persona_id);
  return null;
end
$$;
create trigger hab_z_iniciar after insert or update of rol, activa, hasta, es_maestra on public.membresias
  for each row execute function public.hab_iniciar();

select public.hab_iniciar_persona(m.hogar_id, m.persona_id) from public.membresias m;

-- -----------------------------------------------------------------------------
-- 5. Plan de lectura en una transacción
-- -----------------------------------------------------------------------------
create function public.hab_crear_plan_lectura(p_plan jsonb, p_dias jsonb)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_hogar   uuid := public.hab_hogar_de(public.persona_actual());
  v_id      uuid;
begin
  if v_persona is null or v_hogar is null then
    raise exception using errcode = '42501', message = 'Sin Hábitos en este hogar.';
  end if;
  if jsonb_typeof(p_plan) <> 'object' or jsonb_typeof(p_dias) <> 'array' or jsonb_array_length(p_dias) > 400 then
    raise exception using errcode = '22023', message = 'El plan es un objeto y sus días una lista de hasta 400.';
  end if;
  v_id := (p_plan ->> 'id')::uuid;
  if v_id is null then
    raise exception using errcode = '22023', message = 'El plan lleva su id.';
  end if;
  if exists (select 1 from public.hab_planes_lectura p where p.id = v_id and p.persona_id = v_persona) then
    return v_id;  -- idempotente
  end if;
  insert into public.hab_planes_lectura (id, hogar_id, persona_id, tipo, nombre, fecha_inicio, dias_semana,
                                         version_biblica, estado, libro, modificado_en)
  values (v_id, v_hogar, v_persona, p_plan ->> 'tipo', p_plan ->> 'nombre', (p_plan ->> 'fecha_inicio')::date,
          coalesce((p_plan ->> 'dias_semana')::smallint, 127), p_plan ->> 'version_biblica',
          coalesce(p_plan ->> 'estado', 'activo'), (p_plan ->> 'libro')::smallint,
          coalesce((p_plan ->> 'modificado_en')::timestamptz, now()));
  insert into public.hab_plan_dias (plan_id, dia, hogar_id, persona_id, fecha, segmentos, estado, modificado_en)
  select v_id, (d ->> 'dia')::integer, v_hogar, v_persona, (d ->> 'fecha')::date, d -> 'segmentos',
         coalesce(d ->> 'estado', 'pendiente'), coalesce((p_plan ->> 'modificado_en')::timestamptz, now())
  from jsonb_array_elements(p_dias) d;
  return v_id;
end
$$;
comment on function public.hab_crear_plan_lectura(jsonb, jsonb) is
  'Crea el plan y sus días (hasta 400) en una transacción; idempotente por id del plan.';

-- -----------------------------------------------------------------------------
-- 6. Bitácora: el prefijo habitos* es del servidor y está oculto
-- -----------------------------------------------------------------------------
drop policy bitacora_agregar on public.bitacora;
create policy bitacora_agregar on public.bitacora
  for insert to authenticated
  with check (persona_id = (select public.persona_actual())
              and (hogar_id is null or public.rol_en_hogar(hogar_id) is not null)
              and ocurrido_en <= now() + interval '10 minutes'
              and accion not in ('insertar', 'actualizar', 'borrar')
              and accion !~* '^\s*finanzas'
              and accion !~* '^\s*habitos'
              and lower(coalesce(tabla, '')) !~ '^\s*(public\.)?fin_'
              and lower(coalesce(tabla, '')) !~ '^\s*(public\.)?hab_');

create or replace function public.puede_ver_entrada_bitacora(
  p_hogar_id uuid, p_tabla text, p_accion text, p_registro_id text, p_detalle jsonb)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_fila   jsonb;
  v_texto  text;
  v_libros uuid[] := '{}';
begin
  if p_hogar_id is null then
    return false;
  end if;
  -- Hábitos (D21, regla 98): las entradas habitos.* y las tablas hab_* solo las ve quien las hizo (la regla de la
  -- bitácora ya deja ver lo propio): ni el dueño ni la cuenta maestra.
  if p_accion like 'habitos%' or lower(coalesce(p_tabla, '')) like 'hab\_%' then
    return false;
  end if;
  -- Finanzas (tablas fin_* y acciones finanzas*): quien puede leer el libro de
  -- la entrada; lo del hogar, quien tiene Finanzas (o la maestra).
  if lower(coalesce(p_tabla, '')) like 'fin\_%' or p_accion like 'finanzas%' then
    v_fila := coalesce(p_detalle -> 'despues', p_detalle -> 'antes', p_detalle);
    foreach v_texto in array array[
        v_fila ->> 'libro_id', v_fila ->> 'libro_origen_id', v_fila ->> 'libro_destino_id',
        case when p_tabla = 'fin_libros' then coalesce(v_fila ->> 'id', p_registro_id) end]
    loop
      if v_texto ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        v_libros := v_libros || v_texto::uuid;
      end if;
    end loop;
    if cardinality(v_libros) = 0 then
      return public.fin_puede_hogar(p_hogar_id, 'leer');
    end if;
    return exists (select 1 from unnest(v_libros) as l(id) where public.fin_puede(l.id, 'leer'));
  end if;
  if public.es_cuenta_maestra(p_hogar_id) then
    return true;
  end if;
  if p_accion like 'gravity.%' then
    return false;
  end if;
  return public.puede(p_hogar_id, 'ajustes', 'administrar');
end
$$;

-- -----------------------------------------------------------------------------
-- 7. Avisos: el familiar (solo Hábitos) también tiene preferencias; tipos locales hab_* silenciables
-- -----------------------------------------------------------------------------
create or replace function public.avisos_preferencias_sincronizar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if public.fin_destinatario_valido(new.hogar_id, new.persona_id) or public.hab_miembro_activo(new.hogar_id, new.persona_id) then
    insert into public.avisos_preferencias (persona_id, hogar_id)
    values (new.persona_id, new.hogar_id)
    on conflict (persona_id) do nothing;
  else
    delete from public.avisos_preferencias p where p.persona_id = new.persona_id and p.hogar_id = new.hogar_id;
  end if;
  return null;
end
$$;

create or replace function public.avisos_actualizar_preferencias(
  p_zona_horaria text default null, p_silencio_desde time default null, p_silencio_hasta time default null,
  p_criticas_en_silencio boolean default null, p_tope_no_criticas integer default null,
  p_hora_vencimientos time default null, p_resumen_lunes time default null,
  p_recordatorio_cierre_dia integer default null, p_recordatorio_cierre_hora time default null,
  p_tipos_silenciados text[] default null, p_pulsera_texto_corto boolean default null)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
begin
  if not exists (select 1 from public.avisos_preferencias p where p.persona_id = v_persona) then
    raise exception using errcode = '42501', message = 'Esta cuenta no tiene preferencias de avisos de dinero.';
  end if;
  if p_zona_horaria is not null and not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_zona_horaria) then
    raise exception using errcode = '22023', message = 'Zona horaria desconocida.';
  end if;
  if p_tope_no_criticas is not null and p_tope_no_criticas not between 0 and 10 then
    raise exception using errcode = '22023', message = 'El tope va de 0 a 10.';
  end if;
  if p_recordatorio_cierre_dia is not null and p_recordatorio_cierre_dia not between 1 and 7 then
    raise exception using errcode = '22023', message = 'El día del recordatorio va de 1 (lunes) a 7 (domingo).';
  end if;
  if p_tipos_silenciados is not null and exists (
      select 1 from unnest(p_tipos_silenciados) t
       where t is null or t not in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
             'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
             'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado', 'retiro_bolsa_compartida',
             'resumen_lunes', 'recordatorio_cierre',
             'hab_bloque', 'hab_lectura', 'hab_momento', 'hab_reservado', 'hab_revision_pre', 'hab_revision', 'hab_cierre_dia')) then
    raise exception using errcode = '22023', message = 'Tipo de aviso desconocido.';
  end if;
  if coalesce(p_silencio_desde, (select q.silencio_desde from public.avisos_preferencias q where q.persona_id = v_persona))
     = coalesce(p_silencio_hasta, (select q.silencio_hasta from public.avisos_preferencias q where q.persona_id = v_persona)) then
    raise exception using errcode = '22023', message = 'Las horas silenciosas no pueden empezar y terminar a la misma hora.';
  end if;
  update public.avisos_preferencias p
     set zona_horaria = coalesce(p_zona_horaria, p.zona_horaria),
         silencio_desde = coalesce(p_silencio_desde, p.silencio_desde),
         silencio_hasta = coalesce(p_silencio_hasta, p.silencio_hasta),
         criticas_en_silencio = coalesce(p_criticas_en_silencio, p.criticas_en_silencio),
         tope_no_criticas = coalesce(p_tope_no_criticas, p.tope_no_criticas),
         hora_vencimientos = coalesce(p_hora_vencimientos, p.hora_vencimientos),
         resumen_lunes = coalesce(p_resumen_lunes, p.resumen_lunes),
         recordatorio_cierre_dia = coalesce(p_recordatorio_cierre_dia, p.recordatorio_cierre_dia),
         recordatorio_cierre_hora = coalesce(p_recordatorio_cierre_hora, p.recordatorio_cierre_hora),
         tipos_silenciados = coalesce(p_tipos_silenciados, p.tipos_silenciados),
         pulsera_texto_corto = coalesce(p_pulsera_texto_corto, p.pulsera_texto_corto)
   where p.persona_id = v_persona;
end
$$;

insert into public.avisos_preferencias (persona_id, hogar_id)
select distinct on (m.persona_id) m.persona_id, m.hogar_id
from public.membresias m
where public.hab_miembro_activo(m.hogar_id, m.persona_id)
order by m.persona_id, m.desde desc
on conflict (persona_id) do nothing;

-- -----------------------------------------------------------------------------
-- 8. Privilegios (por columna; lo que pone el servidor no se manda)
-- -----------------------------------------------------------------------------
revoke all on table
  public.hab_ajustes, public.hab_modos, public.hab_objetivos, public.hab_bloques, public.hab_registros,
  public.hab_pausas, public.hab_planes_lectura, public.hab_plan_dias, public.hab_lecturas,
  public.hab_marcas_biblia, public.hab_revisiones
  from public, anon, authenticated, service_role;
grant select on
  public.hab_ajustes, public.hab_modos, public.hab_objetivos, public.hab_bloques, public.hab_registros,
  public.hab_pausas, public.hab_planes_lectura, public.hab_plan_dias, public.hab_lecturas,
  public.hab_marcas_biblia, public.hab_revisiones
  to authenticated;
grant delete on
  public.hab_objetivos, public.hab_bloques, public.hab_registros, public.hab_pausas, public.hab_planes_lectura,
  public.hab_plan_dias, public.hab_lecturas, public.hab_marcas_biblia, public.hab_revisiones
  to authenticated;

grant update (areas_activas, minimos_modo, gracia_semanal, despertar, dormir, franjas, revision_dia, revision_hora,
              revision_aviso_min, dar_activo, dar_dia, dar_hora, versiones_biblia, version_principal,
              version_secundaria, aviso_nombre_objetivos, etiqueta_atajo, bloqueo_reservado_min, umbral_carga_pb,
              asistente, modificado_en)
  on public.hab_ajustes to authenticated;
grant insert (id, titulo, area, tipo, unidad, meta_valor, frecuencia, dias_semana, veces_por_semana, fecha_inicio,
              fecha_objetivo, prioridad, minimo, esencial, motivo, nombre_en_aviso, plantilla, estado, hitos, modificado_en),
      update (id, titulo, area, tipo, unidad, meta_valor, frecuencia, dias_semana, veces_por_semana, fecha_inicio,
              fecha_objetivo, prioridad, minimo, esencial, motivo, nombre_en_aviso, plantilla, estado, hitos, modificado_en)
  on public.hab_objetivos to authenticated;
grant insert (id, titulo, area, tipo, objetivo_id, inicio, duracion_min, dias, cada_semanas, desde, hasta, minimo,
              esencial, recordar_min, activo, modificado_en),
      update (id, titulo, area, tipo, objetivo_id, inicio, duracion_min, dias, cada_semanas, desde, hasta, minimo,
              esencial, recordar_min, activo, modificado_en)
  on public.hab_bloques to authenticated;
grant insert (id, objetivo_id, bloque_id, fecha, estado, valor, movido_a, motivo_omision, modificado_en),
      update (id, objetivo_id, bloque_id, fecha, estado, valor, movido_a, motivo_omision, modificado_en)
  on public.hab_registros to authenticated;
grant insert (id, objetivo_id, desde, hasta, motivo, modificado_en),
      update (id, objetivo_id, desde, hasta, motivo, modificado_en)
  on public.hab_pausas to authenticated;
grant insert (id, tipo, nombre, fecha_inicio, dias_semana, version_biblica, estado, libro, modificado_en),
      update (id, tipo, nombre, fecha_inicio, dias_semana, version_biblica, estado, libro, modificado_en)
  on public.hab_planes_lectura to authenticated;
grant insert (plan_id, dia, fecha, segmentos, estado, hecho_en, modificado_en),
      update (plan_id, dia, fecha, segmentos, estado, hecho_en, modificado_en)
  on public.hab_plan_dias to authenticated;
grant insert (id, fecha, libro, cap_ini, cap_fin, minutos, plan_id, modificado_en),
      update (id, fecha, libro, cap_ini, cap_fin, minutos, plan_id, modificado_en)
  on public.hab_lecturas to authenticated;
grant insert (id, tipo, referencia, color, modificado_en),
      update (id, tipo, referencia, color, modificado_en)
  on public.hab_marcas_biblia to authenticated;
grant insert (id, semana, estado, programada_para, completada_en, resumen, ajustes, dar_cumplido, modificado_en),
      update (id, semana, estado, programada_para, completada_en, resumen, ajustes, dar_cumplido, modificado_en)
  on public.hab_revisiones to authenticated;

-- service_role: solo lectura de las tablas en claro (la copia de seguridad y el mantenimiento borran con las funciones).
grant select on
  public.hab_ajustes, public.hab_modos, public.hab_objetivos, public.hab_bloques, public.hab_registros,
  public.hab_pausas, public.hab_planes_lectura, public.hab_plan_dias, public.hab_lecturas,
  public.hab_marcas_biblia, public.hab_revisiones
  to service_role;

revoke execute on function
  public.hab_miembro_activo(uuid, uuid), public.hab_activa(uuid), public.hab_hogar_de(uuid), public.hab_propio(),
  public.hab_iniciar_persona(uuid, uuid), public.hab_iniciar(), public.hab_crear_plan_lectura(jsonb, jsonb),
  public.puede_ver_entrada_bitacora(uuid, text, text, text, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.hab_activa(uuid), public.hab_hogar_de(uuid), public.puede_ver_entrada_bitacora(uuid, text, text, text, jsonb)
  to authenticated, service_role;
grant execute on function public.hab_crear_plan_lectura(jsonb, jsonb) to authenticated;
