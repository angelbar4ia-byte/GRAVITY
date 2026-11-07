-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados · 2/4: tablas, reglas por rol (RLS) y privilegios
-- =============================================================================
-- docs/specs/fase-5-cuidados.md (v1.0, aprobada): turnos (§3), consentimientos (§4), permisos (§5).
-- Los permisos viven aquí (D5, D7). El dinero y los datos clínicos nunca van a la IA ni a las bocinas (D3, D6).
--
-- CONTRATO PARA LAS DEMÁS ÁREAS (cuidados, plataforma, finanzas). No cambia sin avisar en un informe:
--   cui_turnos(id, hogar_id, persona_id, dia_semana 1-7 [1 = lunes], inicio_min, fin_min [0..1440, fin > inicio],
--              tipo in ('cuidadora','dueno','hermana_visita'))      Un turno no cruza la medianoche: se parte en dos.
--   cui_medicamentos(id, hogar_id, nombre, dosis, horas text[] 'HH:MM', notas, activo)
--   cui_tomas(id, hogar_id, medicamento_id, programada_para, estado in ('pendiente','dado','no_dado'),
--             marcada_por, marcada_en)      Solo cambia con cui_marcar_toma(); las crea cui_generar_tomas().
--   cui_comidas(id, hogar_id, fecha, tiempo, resultado in ('comio','comio_poco','rechazo'), registrada_por,
--               registrada_en)             Solo agregar (la corrección es una fila nueva; vale la más reciente).
--   cui_bitacora(id, hogar_id, persona_id, nota <= 500, creada_en)                          Solo agregar.
--   cui_entregas(id, hogar_id, de_persona, para_persona, nota <= 500, creada_en)             Solo agregar.
--   cui_cambios_urgentes(id, hogar_id, de_persona, para_persona, texto <= 200, creado_en, atendido_en)
--             Solo el dueño los crea (cui_crear_cambio_urgente); crea el aviso 'cambio_urgente_cuidados'.
--   cui_gastos(id, hogar_id, persona_id, monto_centavos > 0, concepto, fecha, estado in ('pendiente_confirmacion',
--              'confirmado','rechazado'), confirmado_en)  Lo registra quien cuida; pasa a Finanzas solo tras la
--              confirmación del dueño (cui_confirmar_gasto). EXTENSIONES: ambito ('cuidado' | 'casa') y registrado_en.
--   cui_autorizacion_resumen(hogar_id, persona_id, autorizado_por, vigente, cambiado_en)  Solo el albacea (RPC).
--   cui_consentimientos(hogar_id, persona_id, concedido, cambiado_en, cambiado_por)       Solo su titular (RPC).
-- Lo que pone el servidor y la app NO manda: persona_id / registrada_por / de_persona / estado / marcada_* /
-- confirmado_en / *_en. Operaciones (RPC): ver la migración 20261115 y supabase/README.md ("Cuidados").
--
-- Quién es quién (cui_perfil): dueño = rol 'dueno'; pareja = rol 'coadministrador' (con su consentimiento:
-- 'pareja_consentida'); cuidadora = rol 'cuidador' o 'familiar' con algún turno de tipo 'cuidadora'; hermana =
-- rol 'cuidador' o 'familiar' con algún turno 'hermana_visita'. Sin turnos asignados, un cuidador o familiar NO
-- tiene acceso a Cuidados. Dado de baja (membresía no vigente) = sin perfil = sin acceso, al instante.
--
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior. Convención 12: los grant repiten la lista completa.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tablas
-- -----------------------------------------------------------------------------
create table public.cui_turnos (
  id          uuid primary key default gen_random_uuid(),
  hogar_id    uuid not null references public.hogares (id),
  persona_id  uuid not null references public.personas (id),
  dia_semana  smallint not null check (dia_semana between 1 and 7),
  inicio_min  integer not null check (inicio_min between 0 and 1439),
  fin_min     integer not null check (fin_min between 1 and 1440),
  tipo        text not null check (tipo in ('cuidadora', 'dueno', 'hermana_visita')),
  constraint cui_turnos_orden check (fin_min > inicio_min)
);
create index cui_turnos_hogar_dia_idx on public.cui_turnos (hogar_id, dia_semana);
create index cui_turnos_persona_idx on public.cui_turnos (persona_id);
comment on table public.cui_turnos is
  'Turnos semanales de cuidado (spec 5 §3). dia_semana 1 = lunes … 7 = domingo; minutos desde medianoche en la zona del hogar '
  '(cui_zona). Un turno no cruza la medianoche. Los recordatorios llegan a quien está de turno (cui_quien_en_turno).';

create table public.cui_medicamentos (
  id        uuid primary key default gen_random_uuid(),
  hogar_id  uuid not null references public.hogares (id),
  nombre    text not null check (char_length(btrim(nombre)) between 1 and 80),
  dosis     text check (char_length(dosis) <= 80),
  horas     text[] not null check (
              cardinality(horas) between 1 and 12
              and array_to_string(horas, ',') ~ '^(([01][0-9]|2[0-3]):[0-5][0-9])(,([01][0-9]|2[0-3]):[0-5][0-9])*$'),
  notas     text check (char_length(notas) <= 500),
  activo    boolean not null default true,
  constraint cui_medicamentos_hogar_id_key unique (hogar_id, id)
);
comment on table public.cui_medicamentos is
  'Medicamentos de Papá: DATO CLÍNICO (D3). Nunca a la IA en la nube ni a las bocinas (los recordatorios en voz alta son '
  'genéricos, D6). Solo el dueño los cambia; "activo" en lugar de borrar.';

create table public.cui_tomas (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  medicamento_id  uuid not null,
  programada_para timestamptz not null,
  estado          text not null default 'pendiente' check (estado in ('pendiente', 'dado', 'no_dado')),
  marcada_por     uuid references public.personas (id),
  marcada_en      timestamptz,
  constraint cui_tomas_medicamento_fk foreign key (hogar_id, medicamento_id)
    references public.cui_medicamentos (hogar_id, id),
  constraint cui_tomas_una_por_hora unique (medicamento_id, programada_para),
  constraint cui_tomas_marca check ((estado = 'pendiente') = (marcada_en is null and marcada_por is null))
);
create index cui_tomas_hogar_idx on public.cui_tomas (hogar_id, programada_para);
comment on table public.cui_tomas is
  'Una fila por medicamento y hora programada. Solo cambian con cui_marcar_toma(); cada cambio deja una entrada en la '
  'bitácora (cuidados.toma_marcada) con el estado y sin datos clínicos extra.';

create table public.cui_comidas (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  fecha         date not null,
  tiempo        text not null check (tiempo in ('desayuno', 'comida', 'cena', 'colacion')),
  resultado     text not null check (resultado in ('comio', 'comio_poco', 'rechazo')),
  registrada_por uuid not null references public.personas (id),
  registrada_en timestamptz not null default now()
);
create index cui_comidas_hogar_idx on public.cui_comidas (hogar_id, fecha desc);
comment on table public.cui_comidas is
  'Comidas de Papá. SOLO AGREGAR: una fila por registro; la corrección es una fila nueva (vale la más reciente por fecha y tiempo).';

create table public.cui_bitacora (
  id         uuid primary key default gen_random_uuid(),
  hogar_id   uuid not null references public.hogares (id),
  persona_id uuid not null references public.personas (id),
  nota       text not null check (char_length(btrim(nota)) between 1 and 500),
  creada_en  timestamptz not null default now()
);
create index cui_bitacora_hogar_idx on public.cui_bitacora (hogar_id, creada_en desc);
comment on table public.cui_bitacora is
  'Bitácora de cuidados (notas clínicas del día a día, D3). SOLO AGREGAR. No es la bitácora de auditoría (public.bitacora). '
  'La pareja no la ve, tampoco con consentimiento (spec 5 §5).';

create table public.cui_entregas (
  id           uuid primary key default gen_random_uuid(),
  hogar_id     uuid not null references public.hogares (id),
  de_persona   uuid not null references public.personas (id),
  para_persona uuid not null references public.personas (id),
  nota         text not null check (char_length(btrim(nota)) between 1 and 500),
  creada_en    timestamptz not null default now(),
  constraint cui_entregas_distintas check (de_persona <> para_persona)
);
create index cui_entregas_para_idx on public.cui_entregas (para_persona, creada_en desc);
comment on table public.cui_entregas is
  'Entrega de turno: notas de quien se va para quien sigue (spec 5 §3). SOLO AGREGAR; la leen quien la escribe, quien la recibe y el dueño.';

create table public.cui_cambios_urgentes (
  id           uuid primary key default gen_random_uuid(),
  hogar_id     uuid not null references public.hogares (id),
  de_persona   uuid not null references public.personas (id),
  para_persona uuid references public.personas (id),
  texto        text not null check (char_length(btrim(texto)) between 1 and 200),
  creado_en    timestamptz not null default now(),
  atendido_en  timestamptz
);
create index cui_cambios_hogar_idx on public.cui_cambios_urgentes (hogar_id, creado_en desc);
comment on table public.cui_cambios_urgentes is
  'Cambios urgentes del dueño (D4). Solo se crean con cui_crear_cambio_urgente(), que avisa al cuidador de turno; sin nadie '
  'de turno, para_persona queda nula y lo ve cualquier cuidadora u hermana al entrar. Solo cambia atendido_en.';

create table public.cui_gastos (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  persona_id      uuid not null references public.personas (id),
  monto_centavos  bigint not null check (monto_centavos > 0),
  concepto        text not null check (char_length(btrim(concepto)) between 1 and 120),
  fecha           date not null,
  estado          text not null default 'pendiente_confirmacion'
                  check (estado in ('pendiente_confirmacion', 'confirmado', 'rechazado')),
  confirmado_en   timestamptz,
  ambito          text not null default 'cuidado' check (ambito in ('cuidado', 'casa')),
  registrado_en   timestamptz not null default now(),
  constraint cui_gastos_confirmacion check ((estado = 'pendiente_confirmacion') = (confirmado_en is null))
);
create index cui_gastos_hogar_idx on public.cui_gastos (hogar_id, fecha desc);
create index cui_gastos_persona_idx on public.cui_gastos (persona_id);
comment on table public.cui_gastos is
  'Gastos de cuidado (centavos). Los registra quien cuida; pasan a Finanzas solo tras la confirmación del dueño '
  '(cui_confirmar_gasto; el paso a Finanzas es de finanzas). Solo agregar, salvo estado y confirmado_en.';
comment on column public.cui_gastos.ambito is
  'EXTENSIÓN al contrato: "cuidado" (por omisión) o "casa". cui_resumen_mensual separa los dos totales.';

create table public.cui_consentimientos (
  hogar_id    uuid not null references public.hogares (id),
  persona_id  uuid not null references public.personas (id),
  concedido   boolean not null default false,
  cambiado_en timestamptz not null default now(),
  cambiado_por uuid references public.personas (id),
  primary key (hogar_id, persona_id)
);
comment on table public.cui_consentimientos is
  'Consentimiento explícito de cada persona (spec 5 §4). Lo cambia su titular con cui_cambiar_consentimiento(); el de Papá '
  '(sin cuenta) lo firma el albacea. Sin fila = no concedido. Hoy abre a la pareja los medicamentos y las comidas.';

create table public.cui_autorizacion_resumen (
  hogar_id       uuid not null references public.hogares (id),
  persona_id     uuid not null references public.personas (id),
  autorizado_por uuid references public.personas (id),
  vigente        boolean not null default false,
  cambiado_en    timestamptz not null default now(),
  primary key (hogar_id, persona_id)
);
comment on table public.cui_autorizacion_resumen is
  'La hermana ve el resumen mensual solo si el albacea (D19) lo autorizó (cui_autorizar_resumen). Sin fila = sin autorización.';

-- -----------------------------------------------------------------------------
-- 2. Funciones para las reglas (SECURITY DEFINER, search_path vacío)
-- -----------------------------------------------------------------------------
-- Zona horaria del hogar: la del dueño en sus preferencias de avisos (o Ciudad de México). Los turnos y las
-- horas de los medicamentos se leen en esta zona.
create function public.cui_zona(p_hogar_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select coalesce(
    (select ap.zona_horaria
       from public.membresias m
       join public.avisos_preferencias ap on ap.persona_id = m.persona_id
      where m.hogar_id = p_hogar_id and m.rol = 'dueno' and m.activa
      limit 1),
    'America/Mexico_City')
$$;
comment on function public.cui_zona(uuid) is 'Zona horaria del hogar para los turnos (la del dueño; por omisión America/Mexico_City).';

-- Perfil de la sesión en Cuidados: dueno | pareja | pareja_consentida | cuidadora | hermana | nulo.
create function public.cui_perfil(p_hogar_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_rol text := public.rol_en_hogar(p_hogar_id);
  v_yo  uuid := public.persona_actual();
begin
  if v_rol is null or v_yo is null then
    return null;
  end if;
  if v_rol = 'dueno' then
    return 'dueno';
  end if;
  if v_rol = 'coadministrador' then
    return case when exists (select 1 from public.cui_consentimientos c
                              where c.hogar_id = p_hogar_id and c.persona_id = v_yo and c.concedido)
                then 'pareja_consentida' else 'pareja' end;
  end if;
  if v_rol in ('cuidador', 'familiar') then
    if exists (select 1 from public.cui_turnos t
                where t.hogar_id = p_hogar_id and t.persona_id = v_yo and t.tipo = 'cuidadora') then
      return 'cuidadora';
    end if;
    if exists (select 1 from public.cui_turnos t
                where t.hogar_id = p_hogar_id and t.persona_id = v_yo and t.tipo = 'hermana_visita') then
      return 'hermana';
    end if;
  end if;
  return null;
end
$$;
comment on function public.cui_perfil(uuid) is
  'Perfil de quien consulta en Cuidados: dueno, pareja (sin consentimiento), pareja_consentida, cuidadora, hermana o nulo '
  '(Casa, maestra sin consentimiento aparte, cuidador sin turnos, dado de baja…). Es la verdad de las reglas por rol.';

-- Quién puede leer o escribir cada parte (spec 5 §5). objeto: turnos | medicamentos | tomas | comidas | bitacora |
-- entregas | cambios | gastos. Las reglas por registro (propios, para quien es) las añaden las políticas.
create function public.cui_puede(p_hogar_id uuid, p_objeto text, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_p text := public.cui_perfil(p_hogar_id);
begin
  if v_p is null or p_accion not in ('leer', 'escribir')
     or p_objeto not in ('turnos', 'medicamentos', 'tomas', 'comidas', 'bitacora', 'entregas', 'cambios', 'gastos') then
    return false;
  end if;
  if p_accion = 'leer' then
    return case p_objeto
      when 'turnos' then true
      when 'medicamentos' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'tomas' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'comidas' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'bitacora' then v_p in ('dueno', 'cuidadora', 'hermana')
      when 'entregas' then v_p in ('dueno', 'cuidadora', 'hermana')
      when 'cambios' then v_p in ('dueno', 'cuidadora', 'hermana')
      when 'gastos' then true
      else false end;
  end if;
  return case p_objeto
    when 'turnos' then v_p = 'dueno'
    when 'medicamentos' then v_p = 'dueno'
    when 'comidas' then v_p in ('dueno', 'cuidadora')
    when 'bitacora' then v_p in ('dueno', 'cuidadora', 'hermana')
    when 'entregas' then v_p in ('dueno', 'cuidadora', 'hermana')
    when 'gastos' then true
    else false end;   -- tomas y cambios urgentes solo cambian con sus RPC
end
$$;
comment on function public.cui_puede(uuid, text, text) is
  'Spec 5 §5: quién lee y escribe cada parte. Pareja: turnos siempre; medicamentos, tomas y comidas (solo lectura) con su '
  'consentimiento; nunca la bitácora ni las entregas; gastos solo los suyos. Cuidadora: lee todo lo clínico, marca tomas, '
  'registra comidas, escribe bitácora y entregas, gastos propios. Hermana: lee, escribe bitácora y entregas, gastos propios.';

-- ¿Está esta persona en el círculo de cuidado (dueño vigente o con turnos y membresía vigente)?
create function public.cui_en_circulo(p_hogar_id uuid, p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membresias m
     where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
       and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and (m.rol = 'dueno'
            or (m.rol in ('cuidador', 'familiar')
                and exists (select 1 from public.cui_turnos t
                             where t.hogar_id = p_hogar_id and t.persona_id = p_persona_id))))
$$;
comment on function public.cui_en_circulo(uuid, uuid) is 'Para quién se puede escribir una entrega de turno: el dueño o quien tiene turnos y sigue vigente.';

-- ¿Puede registrar la comida de esa fecha? El dueño siempre; la cuidadora si tiene turno ese día de la semana.
create function public.cui_puede_comida(p_hogar_id uuid, p_fecha date)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_p text := public.cui_perfil(p_hogar_id);
begin
  if v_p = 'dueno' then
    return true;
  end if;
  return v_p = 'cuidadora' and exists (
    select 1 from public.cui_turnos t
     where t.hogar_id = p_hogar_id and t.persona_id = public.persona_actual() and t.tipo = 'cuidadora'
       and t.dia_semana = extract(isodow from p_fecha)::int);
end
$$;
comment on function public.cui_puede_comida(uuid, date) is 'Registrar la comida de una fecha: el dueño siempre; la cuidadora solo en un día en que tiene turno.';

-- Quién está de turno en un instante. La app, el servidor de avisos (service_role) y las pruebas la usan para
-- los recordatorios: fuera de turno no llega nada a la cuidadora (spec 5 §3, criterio 1). Solo cuenta a quien
-- sigue vigente en el hogar (una baja deja de estar de turno al instante). Un cuidador o familiar sin perfil
-- en Cuidados, y Casa, no obtienen filas.
create function public.cui_quien_en_turno(p_hogar_id uuid, p_ts timestamptz default now())
returns table (persona_id uuid, tipo text)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_zona  text := public.cui_zona(p_hogar_id);
  v_local timestamp := p_ts at time zone v_zona;
  v_dia   integer := extract(isodow from v_local)::int;
  v_min   integer := extract(hour from v_local)::int * 60 + extract(minute from v_local)::int;
begin
  -- Con sesión de usuario debe tener perfil en Cuidados; sin sesión solo llega el servidor (service_role).
  if auth.uid() is not null and public.cui_perfil(p_hogar_id) is null then
    return;
  end if;
  return query
    select t.persona_id, t.tipo
      from public.cui_turnos t
      join public.membresias m on m.hogar_id = t.hogar_id and m.persona_id = t.persona_id
     where t.hogar_id = p_hogar_id and t.dia_semana = v_dia
       and v_min >= t.inicio_min and v_min < t.fin_min
       and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and ((t.tipo = 'dueno' and m.rol = 'dueno')
            or (t.tipo in ('cuidadora', 'hermana_visita') and m.rol in ('cuidador', 'familiar')))
     order by t.tipo, t.inicio_min;
end
$$;
comment on function public.cui_quien_en_turno(uuid, timestamptz) is
  'Quién está de turno en p_ts (zona del hogar): persona y tipo (cuidadora, dueno, hermana_visita). Solo membresías vigentes. '
  'Los recordatorios de medicamentos y comidas van a estas personas y a nadie más.';

-- El albacea vigente de Papá (D19) y la persona de Papá.
create function public.cui_persona_papa(p_hogar_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select l.titular_id from public.fin_libros l
   where l.hogar_id = p_hogar_id and l.tipo = 'representado' and l.activo
   order by l.creado_en, l.id limit 1
$$;
comment on function public.cui_persona_papa(uuid) is 'La persona bajo cuidado (titular del libro representado del hogar); nulo si no hay.';

create function public.cui_es_albacea(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.rol_en_hogar(p_hogar_id) is not null
     and exists (
       select 1 from public.fin_libro_miembros fm
         join public.fin_libros l on l.id = fm.libro_id
        where l.hogar_id = p_hogar_id and l.tipo = 'representado' and l.activo
          and fm.papel = 'albacea' and fm.hasta is null
          and fm.persona_id = public.persona_actual())
$$;
comment on function public.cui_es_albacea(uuid) is 'Verdadero si la sesión es el albacea vigente (D19) del libro de Papá en el hogar.';

-- -----------------------------------------------------------------------------
-- 3. Lo que pone el servidor, validaciones, solo-agregar y topes
-- -----------------------------------------------------------------------------
create function public.cui_propio()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.hogar_id is distinct from old.hogar_id then
      raise exception using errcode = '42501', message = 'El hogar de un registro de Cuidados no cambia.';
    end if;
    return new;
  end if;
  case tg_table_name
    when 'cui_comidas' then
      new.registrada_por := coalesce(public.persona_actual(), new.registrada_por);
      new.registrada_en := now();
    when 'cui_bitacora' then
      new.persona_id := coalesce(public.persona_actual(), new.persona_id);
      new.creada_en := now();
    when 'cui_entregas' then
      new.de_persona := coalesce(public.persona_actual(), new.de_persona);
      new.creada_en := now();
    when 'cui_gastos' then
      new.persona_id := coalesce(public.persona_actual(), new.persona_id);
      new.registrado_en := now();
      if public.persona_actual() is not null then
        new.estado := 'pendiente_confirmacion';
        new.confirmado_en := null;
      end if;
    else null;
  end case;
  return new;
end
$$;

-- Tope de registros propios por día (contra abuso o un teléfono con falla): 54000.
create function public.cui_tope_diario()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_col  text;
  v_ts   text;
  v_quien uuid;
  v_n    bigint;
begin
  select c.col, c.ts into v_col, v_ts from (values
    ('cui_comidas', 'registrada_por', 'registrada_en'),
    ('cui_bitacora', 'persona_id', 'creada_en'),
    ('cui_entregas', 'de_persona', 'creada_en'),
    ('cui_gastos', 'persona_id', 'registrado_en')) as c (tabla, col, ts) where c.tabla = tg_table_name;
  v_quien := (to_jsonb(new) ->> v_col)::uuid;
  execute format('select count(*) from public.%I where %I = $1 and %I > now() - interval ''24 hours''',
                 tg_table_name, v_col, v_ts) into v_n using v_quien;
  if v_n >= 300 then
    raise exception using errcode = '54000',
      message = format('Se llegó al tope de 300 registros en 24 horas en %s.', tg_table_name);
  end if;
  return new;
end
$$;

-- Un turno es del dueño o de un cuidador o familiar vigente del mismo hogar.
create function public.cui_turnos_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.hogar_id is distinct from old.hogar_id then
    raise exception using errcode = '42501', message = 'El hogar de un turno no cambia.';
  end if;
  if not exists (
       select 1 from public.membresias m
        where m.hogar_id = new.hogar_id and m.persona_id = new.persona_id and m.activa
          and m.desde <= now() and (m.hasta is null or m.hasta > now())
          and ((new.tipo = 'dueno' and m.rol = 'dueno')
               or (new.tipo in ('cuidadora', 'hermana_visita') and m.rol in ('cuidador', 'familiar')))) then
    raise exception using errcode = '22023',
      message = 'El turno "dueno" es del dueño; "cuidadora" y "hermana_visita", de un cuidador o familiar vigente del hogar.';
  end if;
  return new;
end
$$;

-- Solo estado y confirmado_en cambian en un gasto, una sola vez.
create function public.cui_gastos_guardar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'estado' - 'confirmado_en') is distinct from (to_jsonb(old) - 'estado' - 'confirmado_en') then
    raise exception using errcode = '42501', message = 'Un gasto de cuidado solo cambia de estado; se corrige con un gasto nuevo.';
  end if;
  if old.estado <> 'pendiente_confirmacion' then
    raise exception using errcode = '55000', message = 'El gasto ya fue resuelto.';
  end if;
  return new;
end
$$;

-- Solo atendido_en cambia en un cambio urgente, una sola vez.
create function public.cui_cambios_guardar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'atendido_en') is distinct from (to_jsonb(old) - 'atendido_en') or old.atendido_en is not null then
    raise exception using errcode = '42501', message = 'Un cambio urgente solo se marca como atendido, una vez.';
  end if;
  return new;
end
$$;

-- Una toma solo cambia de estado y de quién la marcó.
create function public.cui_tomas_guardar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'estado' - 'marcada_por' - 'marcada_en') is distinct from (to_jsonb(old) - 'estado' - 'marcada_por' - 'marcada_en') then
    raise exception using errcode = '42501', message = 'Una toma solo cambia de estado.';
  end if;
  return new;
end
$$;

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['cui_turnos', 'cui_medicamentos', 'cui_tomas', 'cui_comidas', 'cui_bitacora', 'cui_entregas',
                                 'cui_cambios_urgentes', 'cui_gastos', 'cui_consentimientos', 'cui_autorizacion_resumen'] loop
    execute format('alter table public.%I enable row level security', v_tabla);
  end loop;
  -- hogar fijo y lo que pone el servidor
  foreach v_tabla in array array['cui_comidas', 'cui_bitacora', 'cui_entregas', 'cui_gastos'] loop
    execute format('create trigger cui_a_propio before insert or update on public.%I
                      for each row execute function public.cui_propio()', v_tabla);
    execute format('create trigger cui_b_tope before insert on public.%I
                      for each row execute function public.cui_tope_diario()', v_tabla);
  end loop;
  foreach v_tabla in array array['cui_medicamentos', 'cui_tomas', 'cui_cambios_urgentes', 'cui_consentimientos',
                                 'cui_autorizacion_resumen'] loop
    execute format('create trigger cui_a_propio before update on public.%I
                      for each row execute function public.cui_propio()', v_tabla);
  end loop;
  -- solo agregar (sin UPDATE ni DELETE ni TRUNCATE)
  foreach v_tabla in array array['cui_comidas', 'cui_bitacora', 'cui_entregas'] loop
    execute format('create trigger cui_c_solo_agregar before update or delete on public.%I
                      for each row execute function public.impedir_cambios_solo_agregar()', v_tabla);
    execute format('create trigger cui_c_sin_truncar before truncate on public.%I
                      for each statement execute function public.impedir_cambios_solo_agregar()', v_tabla);
  end loop;
  -- sin DELETE ni TRUNCATE (el UPDATE lo limitan las funciones de guarda)
  foreach v_tabla in array array['cui_tomas', 'cui_cambios_urgentes', 'cui_gastos', 'cui_medicamentos',
                                 'cui_consentimientos', 'cui_autorizacion_resumen'] loop
    execute format('create trigger cui_c_sin_borrar before delete on public.%I
                      for each row execute function public.impedir_cambios_solo_agregar()', v_tabla);
    execute format('create trigger cui_c_sin_truncar before truncate on public.%I
                      for each statement execute function public.impedir_cambios_solo_agregar()', v_tabla);
  end loop;
end
$$;

create trigger cui_d_turnos_validar before insert or update on public.cui_turnos
  for each row execute function public.cui_turnos_validar();
create trigger cui_c_sin_truncar before truncate on public.cui_turnos
  for each statement execute function public.impedir_cambios_solo_agregar();
create trigger cui_d_gastos_guardar before update on public.cui_gastos
  for each row execute function public.cui_gastos_guardar();
create trigger cui_d_cambios_guardar before update on public.cui_cambios_urgentes
  for each row execute function public.cui_cambios_guardar();
create trigger cui_d_tomas_guardar before update on public.cui_tomas
  for each row execute function public.cui_tomas_guardar();

-- Bitácora de auditoría automática (quién y cuándo; sin nombres de medicamentos, dosis, notas ni textos).
create trigger cui_z_bitacora after insert or update or delete on public.cui_turnos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger cui_z_bitacora after insert or update on public.cui_medicamentos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'nombre', 'dosis', 'horas', 'notas');
create trigger cui_z_bitacora after insert or update on public.cui_gastos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'concepto');
create trigger cui_z_bitacora after insert or update on public.cui_cambios_urgentes
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'texto');
create trigger cui_z_bitacora after insert or update on public.cui_consentimientos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger cui_z_bitacora after insert or update on public.cui_autorizacion_resumen
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');

-- -----------------------------------------------------------------------------
-- 4. Reglas por registro (RLS)
-- -----------------------------------------------------------------------------
create policy cui_turnos_leer on public.cui_turnos for select to authenticated
  using (public.cui_puede(hogar_id, 'turnos', 'leer'));
create policy cui_turnos_agregar on public.cui_turnos for insert to authenticated
  with check (public.cui_puede(hogar_id, 'turnos', 'escribir'));
create policy cui_turnos_editar on public.cui_turnos for update to authenticated
  using (public.cui_puede(hogar_id, 'turnos', 'escribir'))
  with check (public.cui_puede(hogar_id, 'turnos', 'escribir'));
create policy cui_turnos_borrar on public.cui_turnos for delete to authenticated
  using (public.cui_puede(hogar_id, 'turnos', 'escribir'));

create policy cui_medicamentos_leer on public.cui_medicamentos for select to authenticated
  using (public.cui_puede(hogar_id, 'medicamentos', 'leer'));
create policy cui_medicamentos_agregar on public.cui_medicamentos for insert to authenticated
  with check (public.cui_puede(hogar_id, 'medicamentos', 'escribir'));
create policy cui_medicamentos_editar on public.cui_medicamentos for update to authenticated
  using (public.cui_puede(hogar_id, 'medicamentos', 'escribir'))
  with check (public.cui_puede(hogar_id, 'medicamentos', 'escribir'));

create policy cui_tomas_leer on public.cui_tomas for select to authenticated
  using (public.cui_puede(hogar_id, 'tomas', 'leer'));

create policy cui_comidas_leer on public.cui_comidas for select to authenticated
  using (public.cui_puede(hogar_id, 'comidas', 'leer'));
create policy cui_comidas_agregar on public.cui_comidas for insert to authenticated
  with check (public.cui_puede(hogar_id, 'comidas', 'escribir') and public.cui_puede_comida(hogar_id, fecha));

create policy cui_bitacora_leer on public.cui_bitacora for select to authenticated
  using (public.cui_puede(hogar_id, 'bitacora', 'leer'));
create policy cui_bitacora_agregar on public.cui_bitacora for insert to authenticated
  with check (public.cui_puede(hogar_id, 'bitacora', 'escribir'));

create policy cui_entregas_leer on public.cui_entregas for select to authenticated
  using (public.cui_puede(hogar_id, 'entregas', 'leer')
         and (public.cui_perfil(hogar_id) = 'dueno'
              or de_persona = (select public.persona_actual())
              or para_persona = (select public.persona_actual())));
create policy cui_entregas_agregar on public.cui_entregas for insert to authenticated
  with check (public.cui_puede(hogar_id, 'entregas', 'escribir') and public.cui_en_circulo(hogar_id, para_persona));

create policy cui_cambios_leer on public.cui_cambios_urgentes for select to authenticated
  using (public.cui_puede(hogar_id, 'cambios', 'leer')
         and (public.cui_perfil(hogar_id) = 'dueno'
              or de_persona = (select public.persona_actual())
              or para_persona = (select public.persona_actual())
              or para_persona is null));

create policy cui_gastos_leer on public.cui_gastos for select to authenticated
  using (public.cui_puede(hogar_id, 'gastos', 'leer')
         and (public.cui_perfil(hogar_id) = 'dueno' or persona_id = (select public.persona_actual())));
create policy cui_gastos_agregar on public.cui_gastos for insert to authenticated
  with check (public.cui_puede(hogar_id, 'gastos', 'escribir'));

create policy cui_consentimientos_leer on public.cui_consentimientos for select to authenticated
  using (public.cui_perfil(hogar_id) is not null
         and (public.cui_perfil(hogar_id) = 'dueno' or persona_id = (select public.persona_actual())));

create policy cui_autorizacion_leer on public.cui_autorizacion_resumen for select to authenticated
  using (public.cui_perfil(hogar_id) is not null
         and (public.cui_perfil(hogar_id) = 'dueno' or persona_id = (select public.persona_actual())));

-- -----------------------------------------------------------------------------
-- 5. Privilegios (por columna: lo que pone el servidor no se manda)
-- -----------------------------------------------------------------------------
revoke all on table public.cui_turnos, public.cui_medicamentos, public.cui_tomas, public.cui_comidas, public.cui_bitacora,
  public.cui_entregas, public.cui_cambios_urgentes, public.cui_gastos, public.cui_consentimientos,
  public.cui_autorizacion_resumen from public, anon, authenticated, service_role;

grant select on public.cui_turnos, public.cui_medicamentos, public.cui_tomas, public.cui_comidas, public.cui_bitacora,
  public.cui_entregas, public.cui_cambios_urgentes, public.cui_gastos, public.cui_consentimientos,
  public.cui_autorizacion_resumen to authenticated, service_role;

grant insert (id, hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo),
      update (id, hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo),
      delete on public.cui_turnos to authenticated;
grant insert (id, hogar_id, nombre, dosis, horas, notas, activo),
      update (id, hogar_id, nombre, dosis, horas, notas, activo) on public.cui_medicamentos to authenticated;
grant insert (id, hogar_id, fecha, tiempo, resultado) on public.cui_comidas to authenticated;
grant insert (id, hogar_id, nota) on public.cui_bitacora to authenticated;
grant insert (id, hogar_id, para_persona, nota) on public.cui_entregas to authenticated;
grant insert (id, hogar_id, monto_centavos, concepto, fecha, ambito) on public.cui_gastos to authenticated;

revoke execute on function
  public.cui_zona(uuid), public.cui_perfil(uuid), public.cui_puede(uuid, text, text), public.cui_en_circulo(uuid, uuid),
  public.cui_puede_comida(uuid, date), public.cui_quien_en_turno(uuid, timestamptz), public.cui_persona_papa(uuid),
  public.cui_es_albacea(uuid), public.cui_propio(), public.cui_tope_diario(), public.cui_turnos_validar(),
  public.cui_gastos_guardar(), public.cui_cambios_guardar(), public.cui_tomas_guardar()
  from public, anon, authenticated, service_role;
-- Las políticas se evalúan con el rol de quien consulta: necesita ejecutar lo que usan.
grant execute on function
  public.cui_perfil(uuid), public.cui_puede(uuid, text, text), public.cui_en_circulo(uuid, uuid),
  public.cui_puede_comida(uuid, date), public.cui_quien_en_turno(uuid, timestamptz), public.cui_persona_papa(uuid),
  public.cui_es_albacea(uuid), public.cui_zona(uuid)
  to authenticated, service_role;
