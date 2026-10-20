-- =============================================================================
-- GRAVITY · Fase 0 · Esquema base
-- =============================================================================
-- Hogares, personas, membresías con rol (D5), matriz de permisos por módulo y
-- acción (docs/specs/fase-0-cimientos.md, sección 5), invitaciones,
-- dispositivos (tokens de avisos) y bitácora de auditoría (solo agregar).
-- Incluye la tabla de MUESTRA finanzas_muestra para demostrar la regla del
-- dinero en la Fase 0 (la reemplaza el esquema real de Finanzas en la Fase 1).
--
-- Principio (D5, D7): los permisos viven en el servidor. RLS activado en TODAS
-- las tablas; las reglas usan las funciones rol_en_hogar() y puede().
--
-- Requiere el esquema auth de Supabase (auth.users y auth.uid()). Para pruebas
-- locales se emula con supabase/tests/00_emulacion_supabase.sql.
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tipos (dominios) comunes
-- -----------------------------------------------------------------------------
create domain public.rol_hogar as text
  check (value in ('dueno', 'coadministrador', 'familiar', 'cuidador', 'casa'));
comment on domain public.rol_hogar is
  'Roles de D5. La persona bajo cuidado no tiene cuenta ni rol: sus datos viven en Cuidados.';

create domain public.modulo_app as text
  check (value in ('gravity', 'finanzas', 'habitos', 'cuidados', 'alimentacion', 'casa', 'ajustes'));

create domain public.accion_permiso as text
  check (value in ('leer', 'escribir', 'administrar'));

create domain public.alcance_permiso as text
  check (value in ('total', 'propio', 'restringido'));
comment on domain public.alcance_permiso is
  'total: todo el módulo en el hogar. propio: solo los registros de la persona. '
  'restringido: un subconjunto que define el módulo en su fase (p. ej. "su turno").';

-- -----------------------------------------------------------------------------
-- 2. Hogares, personas, membresías y matriz de permisos
-- -----------------------------------------------------------------------------
create table public.hogares (
  id        uuid primary key default gen_random_uuid(),
  nombre    text not null check (char_length(btrim(nombre)) between 1 and 80),
  creado_en timestamptz not null default now()
);
comment on table public.hogares is 'Hogar: unidad que agrupa personas, roles y datos de los módulos.';

create table public.personas (
  id             uuid primary key default gen_random_uuid(),
  usuario_id     uuid unique references auth.users (id) on delete set null,
  nombre_visible text not null check (char_length(btrim(nombre_visible)) between 1 and 80),
  creado_en      timestamptz not null default now()
);
comment on table public.personas is
  'Persona con cuenta. Se crea sola al registrarse (trigger en auth.users). '
  'No se borra: si se elimina la cuenta, usuario_id queda nulo y la bitácora conserva su nombre.';
comment on column public.personas.usuario_id is 'auth.users.id; nulo si la cuenta se eliminó.';

create table public.membresias (
  id         uuid primary key default gen_random_uuid(),
  hogar_id   uuid not null references public.hogares (id),
  persona_id uuid not null references public.personas (id),
  rol        public.rol_hogar not null,
  activa     boolean not null default true,
  desde      timestamptz not null default now(),
  hasta      timestamptz,
  creado_en  timestamptz not null default now(),
  constraint membresias_hasta_despues_de_desde check (hasta is null or hasta >= desde)
);
comment on table public.membresias is
  'Rol de una persona en un hogar. Vigente si activa, desde <= ahora y (hasta nula o futura). '
  'Dar de baja = activa falso u hasta = ahora: el acceso se pierde de inmediato. No se borran.';

create unique index membresias_una_activa_por_persona
  on public.membresias (hogar_id, persona_id) where activa;
create unique index membresias_un_dueno_activo
  on public.membresias (hogar_id) where activa and rol = 'dueno';
create index membresias_persona_idx on public.membresias (persona_id);

create table public.permisos_rol (
  rol     public.rol_hogar       not null,
  modulo  public.modulo_app      not null,
  accion  public.accion_permiso  not null,
  alcance public.alcance_permiso not null,
  nota    text,
  primary key (rol, modulo, accion)
);
comment on table public.permisos_rol is
  'Matriz rol × módulo × acción (especificación de la Fase 0, sección 5). Solo cambia por migración. '
  'Sin fila = sin acceso. La app lleva un espejo solo para ocultar lo que no corresponde.';

-- -----------------------------------------------------------------------------
-- 3. Funciones auxiliares para las reglas (SECURITY DEFINER, search_path fijo)
-- -----------------------------------------------------------------------------
-- Son SECURITY DEFINER para leer membresías y la matriz sin pasar por RLS (y
-- sin recursión de reglas). Usan search_path vacío y nombres calificados.

create function public.persona_actual()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select p.id from public.personas p where p.usuario_id = auth.uid()
$$;
comment on function public.persona_actual() is 'personas.id de quien hace la consulta (nulo si no hay sesión).';

create function public.rol_en_hogar(p_hogar_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select m.rol::text
  from public.membresias m
  join public.personas p on p.id = m.persona_id
  where m.hogar_id = p_hogar_id
    and p.usuario_id = auth.uid()
    and m.activa
    and m.desde <= now()
    and (m.hasta is null or m.hasta > now())
  limit 1
$$;
comment on function public.rol_en_hogar(uuid) is 'Rol vigente de quien consulta en el hogar; nulo si no es miembro.';

create function public.alcance(p_hogar_id uuid, p_modulo text, p_accion text)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_alcance text;
begin
  -- Un módulo o acción mal escrito en una regla falla en lugar de negar en silencio.
  perform p_modulo::public.modulo_app;
  perform p_accion::public.accion_permiso;
  if p_modulo is null or p_accion is null then
    raise exception using errcode = '22023', message = 'Módulo y acción son obligatorios';
  end if;
  select pr.alcance::text into v_alcance
  from public.permisos_rol pr
  where pr.rol = public.rol_en_hogar(p_hogar_id)
    and pr.modulo = p_modulo
    and pr.accion = p_accion;
  return v_alcance;
end
$$;
comment on function public.alcance(uuid, text, text) is
  'Alcance (total, propio, restringido) del rol de quien consulta para el módulo y la acción; nulo = sin acceso.';

create function public.puede(p_hogar_id uuid, p_modulo text, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
begin
  return coalesce(public.alcance(p_hogar_id, p_modulo, p_accion) = 'total', false);
end
$$;
comment on function public.puede(uuid, text, text) is
  'Verdadero solo si el rol tiene alcance TOTAL. Para "propio" usa puede_sobre(); '
  '"restringido" lo resuelve cada módulo en su fase con sus propias reglas.';

create function public.puede_sobre(p_hogar_id uuid, p_modulo text, p_accion text, p_persona_id uuid)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_alcance text := public.alcance(p_hogar_id, p_modulo, p_accion);
begin
  return coalesce(
    v_alcance = 'total'
    or (v_alcance = 'propio' and p_persona_id is not null and p_persona_id = public.persona_actual()),
    false);
end
$$;
comment on function public.puede_sobre(uuid, text, text, uuid) is
  'Para registros con dueño (persona_id): total, o propio si el registro es de quien consulta.';

create function public.puede_ver_persona(p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_persona_id = public.persona_actual()
      or exists (
        select 1
        from public.membresias m
        where m.persona_id = p_persona_id
          and public.puede(m.hogar_id, 'ajustes', 'administrar')
      )
$$;
comment on function public.puede_ver_persona(uuid) is
  'Cada quien se ve a sí mismo; quien administra Ajustes del hogar (dueño) ve a sus miembros, también a los dados de baja.';

create function public.mis_permisos(p_hogar_id uuid)
returns table (modulo text, accion text, alcance text)
language sql stable security definer
set search_path = ''
as $$
  select pr.modulo::text, pr.accion::text, pr.alcance::text
  from public.permisos_rol pr
  where pr.rol = public.rol_en_hogar(p_hogar_id)
  order by 1, 2
$$;
comment on function public.mis_permisos(uuid) is 'Espejo para la app: los permisos del rol vigente de quien consulta.';

-- -----------------------------------------------------------------------------
-- 4. Invitaciones, dispositivos, bitácora y la muestra de Finanzas
-- -----------------------------------------------------------------------------
create table public.invitaciones (
  id           uuid primary key default gen_random_uuid(),
  hogar_id     uuid not null references public.hogares (id),
  correo       text not null
               check (correo = lower(btrim(correo))
                      and char_length(correo) <= 254
                      and correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  rol          public.rol_hogar not null check (rol <> 'dueno'),
  token_hash   text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  expira_en    timestamptz not null,
  creada_por   uuid references public.personas (id),
  creada_en    timestamptz not null default now(),
  aceptada_en  timestamptz,
  aceptada_por uuid references public.personas (id),
  revocada_en  timestamptz
);
create index invitaciones_hogar_idx on public.invitaciones (hogar_id);
comment on table public.invitaciones is
  'Invitación a un hogar. Solo se guarda el SHA-256 del token; el token se entrega una vez al crearla. '
  'Se crean, aceptan y revocan con crear_invitacion(), aceptar_invitacion() y revocar_invitacion().';

create table public.dispositivos (
  id           uuid primary key default gen_random_uuid(),
  persona_id   uuid not null default public.persona_actual() references public.personas (id),
  plataforma   text not null check (plataforma in ('android', 'windows')),
  token_avisos text check (char_length(token_avisos) between 1 and 4096),
  nombre       text check (char_length(nombre) <= 80),
  creado_en    timestamptz not null default now(),
  ultimo_uso   timestamptz not null default now(),
  constraint dispositivos_token_por_persona unique (persona_id, token_avisos)
);
comment on table public.dispositivos is
  'Dispositivos de cada persona y su token de avisos (FCM, solo Android). Cada quien ve solo los suyos; '
  'la función de avisos (Fase 2) los lee con service_role.';

create table public.bitacora (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid references public.hogares (id),
  persona_id    uuid default public.persona_actual() references public.personas (id),
  accion        text not null check (char_length(accion) between 1 and 60
                                     and accion ~ '^[a-z][a-z0-9_.]*$'),
  tabla         text check (char_length(tabla) <= 63),
  registro_id   text check (char_length(registro_id) <= 200),
  detalle       jsonb not null default '{}'::jsonb
                check (jsonb_typeof(detalle) = 'object' and octet_length(detalle::text) <= 32768),
  ocurrido_en   timestamptz not null default now(),
  registrado_en timestamptz not null default now()
);
create index bitacora_hogar_idx on public.bitacora (hogar_id, registrado_en desc);
create index bitacora_persona_idx on public.bitacora (persona_id, registrado_en desc);
comment on table public.bitacora is
  'Bitácora de auditoría, SOLO AGREGAR: quién (persona_id), qué (accion), cuándo (ocurrido_en, '
  'registrado_en), tabla, registro y detalle. Sin UPDATE ni DELETE: reglas, permisos y trigger lo impiden.';
comment on column public.bitacora.persona_id is 'Quién. Lo pone el servidor (persona_actual()); nulo = sistema.';
comment on column public.bitacora.accion is
  'Qué: identificador en minúsculas (letras, dígitos, _ y .), p. ej. entrega_de_turno o gravity.abrir. '
  'insertar, actualizar y borrar están reservadas a registrar_cambio_en_bitacora(): la app no puede usarlas.';
comment on column public.bitacora.ocurrido_en is 'Cuándo ocurrió (puede venir del dispositivo, p. ej. cola sin conexión).';
comment on column public.bitacora.registrado_en is 'Cuándo llegó al servidor; lo pone el servidor.';

create table public.finanzas_muestra (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  descripcion    text not null check (char_length(btrim(descripcion)) between 1 and 200),
  monto_centavos bigint not null,
  registrado_por uuid default public.persona_actual() references public.personas (id),
  creado_en      timestamptz not null default now()
);
create index finanzas_muestra_hogar_idx on public.finanzas_muestra (hogar_id);
comment on table public.finanzas_muestra is
  'MUESTRA de la Fase 0 para demostrar la regla del dinero (solo dueño escribe; coadministrador lee; '
  'familiar, cuidador y casa no ven nada). La reemplaza el esquema real de Finanzas en la Fase 1, '
  'que la borra con una migración. Dinero en centavos (bigint), MXN.';

-- -----------------------------------------------------------------------------
-- 5. Triggers: solo agregar, bitácora automática y persona al registrarse
-- -----------------------------------------------------------------------------
-- Reutilizable para todo libro solo-agregar (bitácora hoy; movimientos de
-- Finanzas en la Fase 1): BEFORE UPDATE OR DELETE por fila y BEFORE TRUNCATE.
create function public.impedir_cambios_solo_agregar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '42501',
    message = format('La tabla %I es de solo agregar: no se edita ni se borra (%s).', tg_table_name, tg_op),
    hint    = 'Corrige con un registro nuevo (anulación y contraasiento).';
end
$$;
comment on function public.impedir_cambios_solo_agregar() is
  'Trigger para libros solo-agregar: bloquea UPDATE, DELETE y TRUNCATE para cualquier rol, también el dueño de la tabla.';

-- Registra en la bitácora cada cambio de la tabla.
-- Argumentos del trigger: [0] columna con el hogar (por defecto hogar_id);
-- [1..] columnas que no se copian al detalle (p. ej. token_hash).
create function public.registrar_cambio_en_bitacora()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_col_hogar text   := coalesce(tg_argv[0], 'hogar_id');
  v_omitir    text[] := coalesce(tg_argv[1:], '{}'::text[]);
  v_antes     jsonb;
  v_despues   jsonb;
  v_fila      jsonb;
begin
  if tg_op in ('UPDATE', 'DELETE') then v_antes := to_jsonb(old) - v_omitir; end if;
  if tg_op in ('INSERT', 'UPDATE') then v_despues := to_jsonb(new) - v_omitir; end if;
  if tg_op = 'UPDATE' and v_antes = v_despues then
    return null;
  end if;
  v_fila := coalesce(v_despues, v_antes);
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (
    (coalesce(to_jsonb(new), to_jsonb(old)) ->> v_col_hogar)::uuid,
    public.persona_actual(),
    case tg_op when 'INSERT' then 'insertar' when 'UPDATE' then 'actualizar' else 'borrar' end,
    tg_table_name,
    v_fila ->> 'id',
    jsonb_strip_nulls(jsonb_build_object('antes', v_antes, 'despues', v_despues))
  );
  return null;
end
$$;

-- Crea la persona al registrarse una cuenta (nombre de raw_user_meta_data.nombre
-- o, si falta, la parte del correo antes de la @).
create function public.crear_persona_de_usuario()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.personas (usuario_id, nombre_visible)
  values (
    new.id,
    left(coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'nombre'), ''),
      nullif(btrim(split_part(coalesce(new.email, ''), '@', 1)), ''),
      'Persona'), 80)
  )
  on conflict (usuario_id) do nothing;
  return new;
end
$$;

create trigger al_crear_usuario_crear_persona
  after insert on auth.users
  for each row execute function public.crear_persona_de_usuario();

create trigger bitacora_solo_agregar
  before update or delete on public.bitacora
  for each row execute function public.impedir_cambios_solo_agregar();
create trigger bitacora_sin_truncate
  before truncate on public.bitacora
  for each statement execute function public.impedir_cambios_solo_agregar();

create trigger hogares_a_bitacora
  after insert or update or delete on public.hogares
  for each row execute function public.registrar_cambio_en_bitacora('id');
create trigger membresias_a_bitacora
  after insert or update or delete on public.membresias
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger invitaciones_a_bitacora
  after insert or update or delete on public.invitaciones
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'token_hash');
create trigger finanzas_muestra_a_bitacora
  after insert or update or delete on public.finanzas_muestra
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');

-- -----------------------------------------------------------------------------
-- 6. Operaciones (RPC): crear hogar e invitaciones
-- -----------------------------------------------------------------------------
create function public.crear_hogar(p_nombre text)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_hogar   uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Necesitas iniciar sesión para crear un hogar.';
  end if;
  insert into public.hogares (nombre) values (btrim(p_nombre)) returning id into v_hogar;
  insert into public.membresias (hogar_id, persona_id, rol) values (v_hogar, v_persona, 'dueno');
  return v_hogar;
end
$$;
comment on function public.crear_hogar(text) is 'Crea un hogar y deja a quien lo crea como dueño.';

create function public.crear_invitacion(
  p_hogar_id uuid,
  p_correo text,
  p_rol text,
  p_vigencia_dias integer default 7)
returns table (invitacion_id uuid, token text, expira timestamptz)
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_correo text := lower(btrim(p_correo));
  v_token  text;
  v_id     uuid;
  v_expira timestamptz;
begin
  if not public.puede(p_hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501', message = 'Solo el dueño del hogar puede invitar.';
  end if;
  perform p_rol::public.rol_hogar;
  if p_rol is null or p_rol = 'dueno' then
    raise exception using errcode = '22023', message = 'Rol no válido para una invitación.';
  end if;
  if p_vigencia_dias is null or p_vigencia_dias not between 1 and 30 then
    raise exception using errcode = '22023', message = 'La vigencia va de 1 a 30 días.';
  end if;

  -- Una sola invitación pendiente por correo y hogar: las anteriores se revocan.
  update public.invitaciones i
     set revocada_en = now()
   where i.hogar_id = p_hogar_id and i.correo = v_correo
     and i.aceptada_en is null and i.revocada_en is null;

  -- 244 bits aleatorios (dos UUID v4 de pg_strong_random), en hexadecimal.
  v_token  := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  v_expira := now() + make_interval(days => p_vigencia_dias);

  insert into public.invitaciones (hogar_id, correo, rol, token_hash, expira_en, creada_por)
  values (p_hogar_id, v_correo, p_rol, encode(sha256(convert_to(v_token, 'UTF8')), 'hex'),
          v_expira, public.persona_actual())
  returning id into v_id;

  return query select v_id, v_token, v_expira;
end
$$;
comment on function public.crear_invitacion(uuid, text, text, integer) is
  'Solo dueño. Devuelve el token UNA vez (se guarda solo su hash). Rol: coadministrador, familiar, cuidador o casa.';

create function public.aceptar_invitacion(p_token text)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona    uuid := public.persona_actual();
  v_correo     text;
  v_confirmado timestamptz;
  v_inv        public.invitaciones%rowtype;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Necesitas iniciar sesión para aceptar la invitación.';
  end if;

  select lower(u.email), u.email_confirmed_at into v_correo, v_confirmado
  from auth.users u where u.id = auth.uid();

  select * into v_inv
  from public.invitaciones i
  where i.token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex')
  for update;

  if not found or v_inv.aceptada_en is not null or v_inv.revocada_en is not null
     or v_inv.expira_en <= now() then
    raise exception using errcode = '22023', message = 'La invitación no es válida o ya expiró.';
  end if;
  if v_confirmado is null or v_correo is distinct from v_inv.correo then
    raise exception using errcode = '42501',
      message = 'La invitación es para otro correo, o tu correo aún no está confirmado.';
  end if;
  -- Una membresía con fecha de fin vencida ya no da acceso: se cierra para
  -- que la persona pueda volver al hogar con la invitación nueva (M3).
  update public.membresias m
     set activa = false
   where m.hogar_id = v_inv.hogar_id and m.persona_id = v_persona
     and m.activa and m.hasta is not null and m.hasta <= now();
  if exists (select 1 from public.membresias m
             where m.hogar_id = v_inv.hogar_id and m.persona_id = v_persona and m.activa) then
    raise exception using errcode = '23505', message = 'Ya perteneces a este hogar.';
  end if;

  insert into public.membresias (hogar_id, persona_id, rol)
  values (v_inv.hogar_id, v_persona, v_inv.rol);

  update public.invitaciones
     set aceptada_en = now(), aceptada_por = v_persona
   where id = v_inv.id;

  return v_inv.hogar_id;
end
$$;
comment on function public.aceptar_invitacion(text) is
  'La acepta la persona cuyo correo CONFIRMADO coincide; crea su membresía con el rol invitado. Devuelve el hogar.';

create function public.revocar_invitacion(p_invitacion_id uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  update public.invitaciones i
     set revocada_en = now()
   where i.id = p_invitacion_id
     and i.aceptada_en is null and i.revocada_en is null
     and public.puede(i.hogar_id, 'ajustes', 'administrar');
  if not found then
    raise exception using errcode = '22023', message = 'No hay una invitación pendiente que puedas revocar.';
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 7. Matriz inicial de permisos (especificación de la Fase 0, sección 5)
-- -----------------------------------------------------------------------------
-- "total" = todo el módulo; "propio" = solo lo de la persona; "restringido" =
-- subconjunto que define el módulo en su fase (la nota dice cuál). puede() y
-- puede_sobre() solo dan acceso con "total" o "propio": "restringido" no da
-- acceso hasta que el módulo defina su regla en su fase.
-- El módulo gravity no está en la sección 5. Alineado con el espejo de la app
-- en la revisión de la Fase 0 (hallazgo I1): el dueño, total; coadministrador,
-- familiar y casa, lo propio (su historial y preferencias); el cuidador, nada
-- (D5: solo Cuidados).
insert into public.permisos_rol (rol, modulo, accion, alcance, nota) values
  -- dueño
  ('dueno', 'gravity',      'leer',        'total',       'Revisión Fase 0 (I1): no está en la sección 5'),
  ('dueno', 'gravity',      'escribir',    'total',       'Revisión Fase 0 (I1): no está en la sección 5'),
  ('dueno', 'gravity',      'administrar', 'total',       'Revisión Fase 0 (I1): no está en la sección 5'),
  ('dueno', 'finanzas',     'leer',        'total',       null),
  ('dueno', 'finanzas',     'escribir',    'total',       null),
  ('dueno', 'finanzas',     'administrar', 'total',       null),
  ('dueno', 'habitos',      'leer',        'propio',      'Lo propio'),
  ('dueno', 'habitos',      'escribir',    'propio',      'Lo propio'),
  ('dueno', 'cuidados',     'leer',        'total',       null),
  ('dueno', 'cuidados',     'escribir',    'total',       null),
  ('dueno', 'cuidados',     'administrar', 'total',       null),
  ('dueno', 'alimentacion', 'leer',        'total',       null),
  ('dueno', 'alimentacion', 'escribir',    'total',       null),
  ('dueno', 'alimentacion', 'administrar', 'total',       null),
  ('dueno', 'casa',         'leer',        'total',       null),
  ('dueno', 'casa',         'escribir',    'total',       null),
  ('dueno', 'casa',         'administrar', 'total',       null),
  ('dueno', 'ajustes',      'leer',        'total',       null),
  ('dueno', 'ajustes',      'escribir',    'total',       null),
  ('dueno', 'ajustes',      'administrar', 'total',       'Personas, roles e invitaciones'),
  -- coadministrador
  ('coadministrador', 'gravity',      'leer',        'propio',      'Revisión Fase 0 (I1): no está en la sección 5'),
  ('coadministrador', 'gravity',      'escribir',    'propio',      'Revisión Fase 0 (I1): no está en la sección 5'),
  ('coadministrador', 'finanzas',     'leer',        'total',       'Lo que registra se define en la Fase 1'),
  ('coadministrador', 'habitos',      'leer',        'propio',      'Lo propio'),
  ('coadministrador', 'habitos',      'escribir',    'propio',      'Lo propio'),
  ('coadministrador', 'cuidados',     'leer',        'restringido', 'Según consentimiento (Fase 5); sin acceso mientras no exista'),
  ('coadministrador', 'cuidados',     'escribir',    'restringido', 'Según consentimiento (Fase 5); sin acceso mientras no exista'),
  ('coadministrador', 'alimentacion', 'leer',        'total',       null),
  ('coadministrador', 'alimentacion', 'escribir',    'total',       null),
  ('coadministrador', 'alimentacion', 'administrar', 'total',       null),
  ('coadministrador', 'casa',         'leer',        'total',       null),
  ('coadministrador', 'casa',         'escribir',    'total',       null),
  ('coadministrador', 'casa',         'administrar', 'total',       null),
  ('coadministrador', 'ajustes',      'leer',        'propio',      'Lo propio'),
  ('coadministrador', 'ajustes',      'escribir',    'propio',      'Lo propio'),
  -- familiar
  ('familiar', 'gravity',      'leer',     'propio',      'Revisión Fase 0 (I1): no está en la sección 5'),
  ('familiar', 'gravity',      'escribir', 'propio',      'Revisión Fase 0 (I1): no está en la sección 5'),
  ('familiar', 'habitos',      'leer',     'propio',      'Lo propio'),
  ('familiar', 'habitos',      'escribir', 'propio',      'Lo propio'),
  ('familiar', 'alimentacion', 'leer',     'restringido', 'Su parte (Fase 7)'),
  ('familiar', 'casa',         'leer',     'total',       null),
  ('familiar', 'ajustes',      'leer',     'propio',      'Lo propio'),
  ('familiar', 'ajustes',      'escribir', 'propio',      'Lo propio'),
  -- cuidador (sin GRAVITY: D5, solo Cuidados)
  ('cuidador', 'finanzas',     'escribir', 'restringido', 'Solo gastos de cuidado propios (Fase 5); nunca lee Finanzas'),
  ('cuidador', 'cuidados',     'leer',     'restringido', 'Su turno (Fase 5)'),
  ('cuidador', 'cuidados',     'escribir', 'restringido', 'Su turno (Fase 5)'),
  ('cuidador', 'alimentacion', 'leer',     'restringido', 'Comidas de la persona bajo cuidado, sin costos (Fase 7)'),
  ('cuidador', 'casa',         'leer',     'total',       null),
  ('cuidador', 'ajustes',      'leer',     'propio',      'Lo propio'),
  ('cuidador', 'ajustes',      'escribir', 'propio',      'Lo propio'),
  -- casa (cuenta compartida de la tablet y del puente de casa)
  ('casa', 'gravity',      'leer',     'propio',      'Revisión Fase 0 (I1): no está en la sección 5'),
  ('casa', 'gravity',      'escribir', 'propio',      'Revisión Fase 0 (I1): no está en la sección 5'),
  ('casa', 'cuidados',     'leer',     'restringido', 'Solo recordatorios genéricos, sin nombres ni medicamentos (D3)'),
  ('casa', 'alimentacion', 'leer',     'restringido', 'Menú y lista de compras (Fase 7)'),
  ('casa', 'casa',         'leer',     'total',       null);

-- -----------------------------------------------------------------------------
-- 8. Reglas por registro (RLS) en TODAS las tablas
-- -----------------------------------------------------------------------------
-- Sin regla = sin acceso. anon no tiene reglas ni privilegios. service_role
-- (funciones de servidor) salta RLS por diseño de Supabase.
alter table public.hogares          enable row level security;
alter table public.personas         enable row level security;
alter table public.membresias       enable row level security;
alter table public.permisos_rol     enable row level security;
alter table public.invitaciones     enable row level security;
alter table public.dispositivos     enable row level security;
alter table public.bitacora         enable row level security;
alter table public.finanzas_muestra enable row level security;

-- hogares: los ven sus miembros; el dueño cambia el nombre. Se crean con crear_hogar().
create policy hogares_leer on public.hogares
  for select to authenticated
  using (public.rol_en_hogar(id) is not null);
create policy hogares_editar on public.hogares
  for update to authenticated
  using (public.puede(id, 'ajustes', 'administrar'))
  with check (public.puede(id, 'ajustes', 'administrar'));

-- personas: cada quien a sí mismo; el dueño a los miembros de su hogar.
create policy personas_leer on public.personas
  for select to authenticated
  using (public.puede_ver_persona(id));
create policy personas_editar_propia on public.personas
  for update to authenticated
  using (usuario_id = (select auth.uid()))
  with check (usuario_id = (select auth.uid()));

-- membresías: cada quien las suyas; el dueño las del hogar. El dueño cambia rol
-- o da de baja a otros, pero no se toca a sí mismo ni nombra otro dueño.
-- Se crean con crear_hogar() y aceptar_invitacion(); no se borran.
create policy membresias_leer on public.membresias
  for select to authenticated
  using (persona_id = (select public.persona_actual())
         or public.puede(hogar_id, 'ajustes', 'administrar'));
create policy membresias_editar on public.membresias
  for update to authenticated
  using (public.puede(hogar_id, 'ajustes', 'administrar')
         and persona_id <> (select public.persona_actual()))
  with check (public.puede(hogar_id, 'ajustes', 'administrar')
              and persona_id <> (select public.persona_actual())
              and rol <> 'dueno');

-- permisos_rol: lectura para cualquier sesión (la app lleva el espejo).
create policy permisos_rol_leer on public.permisos_rol
  for select to authenticated
  using (true);

-- invitaciones: solo quien administra Ajustes del hogar (dueño).
create policy invitaciones_leer on public.invitaciones
  for select to authenticated
  using (public.puede(hogar_id, 'ajustes', 'administrar'));

-- dispositivos: cada quien los suyos.
create policy dispositivos_leer on public.dispositivos
  for select to authenticated
  using (persona_id = (select public.persona_actual()));
create policy dispositivos_agregar on public.dispositivos
  for insert to authenticated
  with check (persona_id = (select public.persona_actual()));
create policy dispositivos_editar on public.dispositivos
  for update to authenticated
  using (persona_id = (select public.persona_actual()))
  with check (persona_id = (select public.persona_actual()));
create policy dispositivos_borrar on public.dispositivos
  for delete to authenticated
  using (persona_id = (select public.persona_actual()));

-- bitácora: el dueño ve la de su hogar; cada quien ve lo que él hizo.
-- Cualquier miembro agrega a su nombre. Sin reglas de UPDATE ni DELETE.
-- Las acciones de los triggers (insertar, actualizar, borrar) quedan reservadas:
-- nadie puede fabricar una entrada que parezca un cambio automático (M2). El
-- trigger escribe como dueño de la tabla, sin pasar por esta regla.
create policy bitacora_leer on public.bitacora
  for select to authenticated
  using (persona_id = (select public.persona_actual())
         or (hogar_id is not null and public.puede(hogar_id, 'ajustes', 'administrar')));
create policy bitacora_agregar on public.bitacora
  for insert to authenticated
  with check (persona_id = (select public.persona_actual())
              and (hogar_id is null or public.rol_en_hogar(hogar_id) is not null)
              and ocurrido_en <= now() + interval '10 minutes'
              and accion not in ('insertar', 'actualizar', 'borrar'));

-- finanzas_muestra: la regla del dinero.
create policy finanzas_muestra_leer on public.finanzas_muestra
  for select to authenticated
  using (public.puede(hogar_id, 'finanzas', 'leer'));
create policy finanzas_muestra_agregar on public.finanzas_muestra
  for insert to authenticated
  with check (public.puede(hogar_id, 'finanzas', 'escribir')
              and registrado_por = (select public.persona_actual()));
create policy finanzas_muestra_editar on public.finanzas_muestra
  for update to authenticated
  using (public.puede(hogar_id, 'finanzas', 'escribir'))
  with check (public.puede(hogar_id, 'finanzas', 'escribir'));
create policy finanzas_muestra_borrar on public.finanzas_muestra
  for delete to authenticated
  using (public.puede(hogar_id, 'finanzas', 'escribir'));

-- -----------------------------------------------------------------------------
-- 9. Privilegios explícitos (Supabase concede TODO por defecto a anon y
--    authenticated; aquí se deja solo lo necesario, por columna cuando aplica)
-- -----------------------------------------------------------------------------
revoke all on table
  public.hogares, public.personas, public.membresias, public.permisos_rol,
  public.invitaciones, public.dispositivos, public.bitacora, public.finanzas_muestra
  from public, anon, authenticated, service_role;

grant select                                          on public.hogares          to authenticated;
grant update (nombre)                                 on public.hogares          to authenticated;
grant select                                          on public.personas         to authenticated;
grant update (nombre_visible)                         on public.personas         to authenticated;
grant select                                          on public.membresias       to authenticated;
grant update (rol, activa, hasta)                     on public.membresias       to authenticated;
grant select                                          on public.permisos_rol     to authenticated;
grant select                                          on public.invitaciones     to authenticated;
grant select, delete                                  on public.dispositivos     to authenticated;
grant insert (id, plataforma, token_avisos, nombre)   on public.dispositivos     to authenticated;
grant update (token_avisos, nombre, ultimo_uso)       on public.dispositivos     to authenticated;
grant select                                          on public.bitacora         to authenticated;
grant insert (id, hogar_id, accion, tabla, registro_id, detalle, ocurrido_en)
                                                      on public.bitacora         to authenticated;
grant select, delete                                  on public.finanzas_muestra to authenticated;
grant insert (id, hogar_id, descripcion, monto_centavos) on public.finanzas_muestra to authenticated;
grant update (descripcion, monto_centavos)            on public.finanzas_muestra to authenticated;

-- service_role (funciones de servidor): todo menos cambiar la matriz y la bitácora.
grant select, insert, update, delete on
  public.hogares, public.personas, public.membresias, public.invitaciones,
  public.dispositivos, public.finanzas_muestra
  to service_role;
grant select         on public.permisos_rol to service_role;
grant select, insert on public.bitacora     to service_role;

-- Funciones: nada para anon ni PUBLIC; las de reglas y RPC para authenticated.
revoke execute on function
  public.persona_actual(), public.rol_en_hogar(uuid), public.alcance(uuid, text, text),
  public.puede(uuid, text, text), public.puede_sobre(uuid, text, text, uuid),
  public.puede_ver_persona(uuid), public.mis_permisos(uuid),
  public.impedir_cambios_solo_agregar(), public.registrar_cambio_en_bitacora(),
  public.crear_persona_de_usuario(),
  public.crear_hogar(text), public.crear_invitacion(uuid, text, text, integer),
  public.aceptar_invitacion(text), public.revocar_invitacion(uuid)
  from public, anon, authenticated, service_role;

grant execute on function
  public.persona_actual(), public.rol_en_hogar(uuid), public.alcance(uuid, text, text),
  public.puede(uuid, text, text), public.puede_sobre(uuid, text, text, uuid),
  public.puede_ver_persona(uuid), public.mis_permisos(uuid)
  to authenticated, service_role;
grant execute on function
  public.crear_hogar(text), public.crear_invitacion(uuid, text, text, integer),
  public.aceptar_invitacion(text), public.revocar_invitacion(uuid)
  to authenticated;

-- Red de seguridad para lo que cree después quien aplica las migraciones
-- (postgres). Cada migración nueva debe, de todos modos, activar RLS, revocar
-- y conceder explícito; esto cubre el olvido (M1):
-- * Funciones: PostgreSQL da EXECUTE a PUBLIC por omisión en TODOS los
--   esquemas, y un REVOKE "in schema" no lo quita; por eso se revoca sin
--   esquema. Con eso anon no ejecuta ninguna función nueva; authenticated y
--   service_role la siguen ejecutando por los privilegios de Supabase en public.
-- * Tablas: nada para anon; sin TRUNCATE (salta RLS), REFERENCES ni TRIGGER
--   para authenticated, y sin TRUNCATE para service_role.
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke all on functions from anon;
alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke truncate, references, trigger on tables from authenticated;
alter default privileges in schema public revoke truncate on tables from service_role;

-- -----------------------------------------------------------------------------
-- 10. Cuentas que ya existían antes de esta migración (proyecto real)
-- -----------------------------------------------------------------------------
insert into public.personas (usuario_id, nombre_visible)
select u.id,
       left(coalesce(nullif(btrim(u.raw_user_meta_data ->> 'nombre'), ''),
                     nullif(btrim(split_part(coalesce(u.email, ''), '@', 1)), ''),
                     'Persona'), 80)
from auth.users u
on conflict (usuario_id) do nothing;
