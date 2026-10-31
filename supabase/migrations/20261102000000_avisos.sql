-- =============================================================================
-- GRAVITY · Fase 2 · Infraestructura de avisos (D20, propuesta)
-- =============================================================================
-- docs/specs/fase-2-finanzas.md (4.1 a 4.3 y 5.4 a 5.5) y D20. Se construye con las
-- propuestas por defecto mientras el dueño responde.
--
--   * Tablas avisos, avisos_entregas, avisos_preferencias y avisos_sistema (sin prefijo
--     fin_: Hábitos y Cuidados las reutilizarán). SIN columnas de monto, de nombre ni de
--     texto libre: el texto sale de un catálogo cerrado que vive en la app.
--   * dispositivos: tipo, recibe_avisos, token único GLOBAL (cierra M13); registrar_dispositivo
--     y quitar_dispositivo. Una tablet pública nunca recibe avisos.
--   * Destinatarios calculados en el servidor (libro personal, compartido, papá); nunca la
--     cuenta maestra que no es la dueña, ni familiar, cuidador o Casa.
--   * Silencio (22:00 a 07:00) y tope diario de avisos no críticos en la zona de la persona.
--   * fin_emitir_aviso (la app), avisos_marcar, avisos_actualizar_preferencias.
--   * avisos_generar_vencimientos() (cada hora), avisos_revisar_base() (diaria, 80 y 90 %,
--     solo el dueño), avisos_limpiar() (90 y 30 días), con pg_cron si existe.
--   * Funciones para la Edge Function enviar-avisos (solo service_role): reclamar con
--     skip locked, registrar entrega y resultado (reintentos a los 5, 15 y 60 minutos).
--   * Aviso al suplente dentro de la entrada N3, aviso del retiro de una bolsa compartida
--     y límite de una consulta repetida de la maestra por minuto y libro (P12).
--
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior. pg_cron, pg_net y el Vault
-- se usan solo si existen (en Supabase sí); las pruebas locales no los necesitan.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Catálogo: severidad y tipos emitibles por la app
-- -----------------------------------------------------------------------------
create function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80')
      then 'importante'
    else 'informativa' end
$$;
comment on function public.avisos_severidad(text) is
  'Severidad fija de cada tipo del catálogo (P3): críticas = cuestan dinero si no se atienden.';

create function public.avisos_tipo_emitible(p_tipo text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_tipo in ('protegido_riesgo', 'flujo_negativo', 'abono_bajo_minimo', 'partida_100', 'partida_80',
                    'fondo_bajo', 'uso_limite', 'aportacion_pendiente', 'conciliacion_pendiente')
$$;
comment on function public.avisos_tipo_emitible(text) is
  'Tipos que la app puede emitir con fin_emitir_aviso (los que solo el motor sabe calcular).';

-- -----------------------------------------------------------------------------
-- 2. Tablas
-- -----------------------------------------------------------------------------
create table public.avisos_preferencias (
  persona_id               uuid primary key references public.personas (id),
  hogar_id                 uuid not null references public.hogares (id),
  zona_horaria             text not null default 'America/Mexico_City',
  silencio_desde           time not null default '22:00',
  silencio_hasta           time not null default '07:00',
  criticas_en_silencio     boolean not null default false,
  tope_no_criticas         smallint not null default 3 check (tope_no_criticas between 0 and 10),
  hora_vencimientos        time not null default '09:00',
  resumen_lunes            time not null default '08:00',
  recordatorio_cierre_dia  smallint not null default 7 check (recordatorio_cierre_dia between 1 and 7),
  recordatorio_cierre_hora time not null default '19:00',
  tipos_silenciados        text[] not null default '{}',
  pulsera_texto_corto      boolean not null default true
);
comment on table public.avisos_preferencias is
  'Preferencias de avisos de cada persona (una fila). La crea el servidor al darle un rol con Finanzas; '
  'la app las cambia con avisos_actualizar_preferencias. La cuenta maestra que no es la dueña no tiene.';

create table public.avisos (
  id             uuid primary key,
  hogar_id       uuid not null references public.hogares (id),
  persona_id     uuid not null references public.personas (id),
  modulo         text not null check (modulo in ('finanzas', 'sistema')),
  tipo           text not null check (tipo in (
                   'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                   'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
                   'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
                   'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90')),
  severidad      text not null check (severidad in ('critica', 'importante', 'informativa')),
  clave          text not null check (char_length(clave) <= 120 and clave ~ '^[a-z0-9_:.-]+$'),
  libro_id       uuid,
  objeto_tipo    text check (objeto_tipo in ('deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento')),
  objeto_id      uuid,
  programado_para timestamptz not null,
  enviar_en      timestamptz not null,
  estado         text not null default 'pendiente'
                 check (estado in ('pendiente', 'enviada', 'agrupada', 'cancelada', 'leida', 'resuelta', 'pospuesta')),
  enviada_en     timestamptz,
  leida_en       timestamptz,
  resuelta_en    timestamptz,
  creado_en      timestamptz not null default now(),
  emitido_por    uuid references public.personas (id),
  intentos       smallint not null default 0 check (intentos >= 0),
  reclamado_hasta timestamptz,
  constraint avisos_clave_unica unique (persona_id, clave),
  constraint avisos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint avisos_modulo_libro check ((modulo = 'finanzas') = (libro_id is not null)),
  constraint avisos_objeto check ((objeto_tipo is null) = (objeto_id is null))
);
create index avisos_persona_idx on public.avisos (persona_id, enviar_en desc);
create index avisos_pendientes_idx on public.avisos (enviar_en) where estado in ('pendiente', 'pospuesta');
create index avisos_objeto_idx on public.avisos (objeto_id) where objeto_id is not null;
comment on table public.avisos is
  'Avisos dirigidos a una persona. SIN columnas de monto, de nombre ni de texto libre (D3, D20): el texto sale de un '
  'catálogo cerrado en la app y por Firebase solo viaja {v, id}. Los destinatarios los fija el servidor. Se borran a '
  'los 90 días. Cada persona lee solo los suyos; solo cambian las funciones.';
comment on column public.avisos.clave is
  'Idempotencia: único con persona_id. Solo letras minúsculas, dígitos y _ : . - (no es texto para mostrar).';

create table public.avisos_entregas (
  id             uuid primary key default gen_random_uuid(),
  aviso_id       uuid not null references public.avisos (id) on delete cascade,
  dispositivo_id uuid,
  enviada_en     timestamptz not null default now(),
  resultado      text not null check (resultado in ('ok', 'token_invalido', 'error')),
  codigo         text check (char_length(codigo) <= 60)
);
create index avisos_entregas_aviso_idx on public.avisos_entregas (aviso_id);
create index avisos_entregas_fecha_idx on public.avisos_entregas (enviada_en);

create table public.avisos_sistema (
  clave text primary key check (char_length(clave) <= 60),
  valor jsonb not null check (octet_length(valor::text) <= 200)
);
insert into public.avisos_sistema (clave, valor) values
  ('limite_base_bytes', to_jsonb(524288000::bigint)),
  ('umbral_aviso_pct', to_jsonb(80)),
  ('umbral_critico_pct', to_jsonb(90));
comment on table public.avisos_sistema is
  'Una fila por parámetro. limite_base_bytes = 500 MB (cupo del plan gratuito; verificar el cupo vigente).';

alter table public.avisos_preferencias enable row level security;
alter table public.avisos enable row level security;
alter table public.avisos_entregas enable row level security;
alter table public.avisos_sistema enable row level security;

create policy avisos_preferencias_leer on public.avisos_preferencias for select to authenticated
  using (persona_id = (select public.persona_actual()));
create policy avisos_leer on public.avisos for select to authenticated
  using (persona_id = (select public.persona_actual()));

revoke all on table public.avisos_preferencias, public.avisos, public.avisos_entregas, public.avisos_sistema
  from public, anon, authenticated, service_role;
grant select on public.avisos_preferencias, public.avisos to authenticated;
grant select on public.avisos_preferencias, public.avisos, public.avisos_entregas, public.avisos_sistema to service_role;
grant update (estado, enviada_en, enviar_en, intentos, reclamado_hasta) on public.avisos to service_role;
grant insert on public.avisos_entregas to service_role;
grant delete on public.avisos, public.avisos_entregas to service_role;

-- Realtime de la bandeja (laptop con la app abierta), si el proyecto lo tiene.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.avisos;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 3. Preferencias: las crea el servidor al dar un rol con Finanzas
-- -----------------------------------------------------------------------------
create function public.fin_destinatario_valido(p_hogar_id uuid, p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.fin_adulto_con_finanzas(p_hogar_id, p_persona_id)
     and not exists (select 1 from public.membresias m
                      where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id
                        and m.activa and m.es_maestra and m.rol <> 'dueno')
$$;
comment on function public.fin_destinatario_valido(uuid, uuid) is
  'Adulto con Finanzas del hogar que no es la cuenta maestra sin ser dueña: a esas personas se les dirigen avisos de dinero.';

create function public.avisos_preferencias_sincronizar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if public.fin_destinatario_valido(new.hogar_id, new.persona_id) then
    insert into public.avisos_preferencias (persona_id, hogar_id)
    values (new.persona_id, new.hogar_id)
    on conflict (persona_id) do nothing;
  elsif not public.fin_adulto_con_finanzas(new.hogar_id, new.persona_id)
        or exists (select 1 from public.membresias m where m.hogar_id = new.hogar_id
                    and m.persona_id = new.persona_id and m.activa and m.es_maestra and m.rol <> 'dueno') then
    delete from public.avisos_preferencias p where p.persona_id = new.persona_id and p.hogar_id = new.hogar_id;
  end if;
  return null;
end
$$;
create trigger avisos_z_preferencias after insert or update of rol, activa, hasta, es_maestra on public.membresias
  for each row execute function public.avisos_preferencias_sincronizar();

insert into public.avisos_preferencias (persona_id, hogar_id)
select distinct on (m.persona_id) m.persona_id, m.hogar_id
from public.membresias m
where public.fin_destinatario_valido(m.hogar_id, m.persona_id)
order by m.persona_id, m.desde desc
on conflict (persona_id) do nothing;

-- -----------------------------------------------------------------------------
-- 4. Dispositivos: tipo, recibe_avisos, token único global (cierra M13)
-- -----------------------------------------------------------------------------
alter table public.dispositivos
  add column tipo text not null default 'telefono'
    check (tipo in ('telefono', 'tablet_personal', 'tablet_publica', 'laptop')),
  add column recibe_avisos boolean not null default false,
  add column ultimo_envio_en timestamptz,
  add column fallos smallint not null default 0 check (fallos >= 0);
update public.dispositivos set tipo = 'laptop' where plataforma = 'windows';
update public.dispositivos set recibe_avisos = true where tipo = 'telefono' and token_avisos is not null;

alter table public.dispositivos drop constraint dispositivos_token_por_persona;
create unique index dispositivos_token_unico on public.dispositivos (token_avisos) where token_avisos is not null;
comment on column public.dispositivos.recibe_avisos is
  'Falso por omisión en tablet personal y laptop; siempre falso en tablet pública (trigger).';

create function public.dispositivos_sin_avisos_en_tablet_publica()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tipo = 'tablet_publica' then
    new.recibe_avisos := false;
  end if;
  return new;
end
$$;
create trigger dispositivos_a_publica before insert or update on public.dispositivos
  for each row execute function public.dispositivos_sin_avisos_en_tablet_publica();

-- Los tokens entran solo por registrar_dispositivo (reasigna el token a quien lo registra).
drop policy dispositivos_agregar on public.dispositivos;
revoke insert on public.dispositivos from authenticated;
revoke update on public.dispositivos from authenticated;
grant update (nombre, ultimo_uso, recibe_avisos) on public.dispositivos to authenticated;

create function public.registrar_dispositivo(
  p_token text, p_plataforma text, p_nombre text default null, p_tipo text default 'telefono')
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_id      uuid;
  v_antes   public.dispositivos%rowtype;
  v_recibe  boolean;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Hace falta una sesión.';
  end if;
  if p_token is null or char_length(btrim(p_token)) not between 1 and 4096 then
    raise exception using errcode = '22023', message = 'El token del dispositivo va de 1 a 4096 caracteres.';
  end if;
  if p_plataforma not in ('android', 'windows') then
    raise exception using errcode = '22023', message = 'La plataforma es android o windows.';
  end if;
  if p_tipo is null or p_tipo not in ('telefono', 'tablet_personal', 'tablet_publica', 'laptop') then
    raise exception using errcode = '22023', message = 'El tipo es telefono, tablet_personal, tablet_publica o laptop.';
  end if;
  v_id := md5('dispositivo:' || p_token)::uuid;
  -- Entrar con otra cuenta en el mismo equipo reasigna el token (M13).
  delete from public.dispositivos d where d.token_avisos = p_token and d.persona_id <> v_persona;
  select * into v_antes from public.dispositivos d where d.id = v_id;
  v_recibe := case when p_tipo = 'tablet_publica' then false
                   when found and v_antes.persona_id = v_persona then v_antes.recibe_avisos
                   else p_tipo = 'telefono' end;
  insert into public.dispositivos (id, persona_id, plataforma, token_avisos, nombre, tipo, recibe_avisos)
  values (v_id, v_persona, p_plataforma, p_token, left(p_nombre, 80), p_tipo, v_recibe)
  on conflict (id) do update
     set persona_id = excluded.persona_id, plataforma = excluded.plataforma, nombre = excluded.nombre,
         tipo = excluded.tipo, recibe_avisos = excluded.recibe_avisos, ultimo_uso = now(), fallos = 0;
  return v_id;
end
$$;
comment on function public.registrar_dispositivo(text, text, text, text) is
  'Da de alta o REASIGNA el token a la persona de la sesión (id derivado del token). Un teléfono recibe avisos por '
  'omisión; tablet personal y laptop, no; una tablet pública nunca (cierra M13).';

create function public.quitar_dispositivo(p_token text)
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  delete from public.dispositivos d where d.token_avisos = p_token and d.persona_id = public.persona_actual();
  get diagnostics v_n = row_count;
  return v_n > 0;
end
$$;
comment on function public.quitar_dispositivo(text) is
  'Al cerrar sesión, al quitar a la persona de la tablet y en una baja: borra el token de esa persona.';

-- -----------------------------------------------------------------------------
-- 5. Destinatarios, silencio, tope e inserción idempotente (internas)
-- -----------------------------------------------------------------------------
-- Libro personal: su titular. Compartido: todos los miembros vigentes. Papá: el albacea
-- vigente y, si no hay, el suplente. Siempre adultos con Finanzas y nunca la maestra no dueña.
create function public.fin_avisos_destinatarios(p_libro_id uuid, p_tipo text, p_actor uuid default null)
returns setof uuid
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found then
    return;
  end if;
  -- Quien registró (partida al 80 %, y al 100 % junto con el titular).
  if p_tipo = 'partida_80' or (p_tipo = 'partida_100' and v_libro.tipo = 'compartido') then
    if p_actor is not null and public.fin_destinatario_valido(v_libro.hogar_id, p_actor) then
      return next p_actor;
    end if;
    return;
  end if;
  return query
  with candidatos as (
    select v_libro.titular_id as persona_id where v_libro.tipo = 'personal'
    union
    select m.persona_id from public.fin_libro_miembros m
     where v_libro.tipo = 'compartido' and m.libro_id = p_libro_id and m.desde <= now()
       and (m.hasta is null or m.hasta > now())
    union
    select m.persona_id from public.fin_libro_miembros m
     where v_libro.tipo = 'representado' and m.libro_id = p_libro_id and m.papel = 'albacea'
       and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and public.fin_destinatario_valido(v_libro.hogar_id, m.persona_id)
    union
    select m.persona_id from public.fin_libro_miembros m
     where v_libro.tipo = 'representado' and m.libro_id = p_libro_id and m.papel = 'albacea_suplente'
       and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and public.fin_destinatario_valido(v_libro.hogar_id, m.persona_id)
       and not exists (select 1 from public.fin_libro_miembros a
                        where a.libro_id = p_libro_id and a.papel = 'albacea' and a.desde <= now()
                          and (a.hasta is null or a.hasta > now())
                          and public.fin_destinatario_valido(v_libro.hogar_id, a.persona_id))
  )
  select c.persona_id from candidatos c
   where c.persona_id is not null and public.fin_destinatario_valido(v_libro.hogar_id, c.persona_id)
  union
  select p_actor where p_tipo = 'partida_100' and p_actor is not null
                   and public.fin_destinatario_valido(v_libro.hogar_id, p_actor);
end
$$;
comment on function public.fin_avisos_destinatarios(uuid, text, uuid) is
  'Destinatarios de un aviso de dinero (regla 41). Nadie elige destinatarios desde la app. Nunca la cuenta maestra '
  'que no es la dueña, ni familiar, cuidador o Casa.';

-- Hora de salida de un aviso: respeta el silencio de la persona (las críticas, salvo que lo permita).
create function public.avisos_ajustar_envio(p_persona_id uuid, p_severidad text, p_cuando timestamptz)
returns timestamptz
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_pref  public.avisos_preferencias%rowtype;
  v_zona  text;
  v_desde time;
  v_hasta time;
  v_crit  boolean;
  v_local timestamp;
  v_hora  time;
  v_en_silencio boolean;
begin
  select * into v_pref from public.avisos_preferencias p where p.persona_id = p_persona_id;
  v_zona  := coalesce(v_pref.zona_horaria, 'America/Mexico_City');
  v_desde := coalesce(v_pref.silencio_desde, time '22:00');
  v_hasta := coalesce(v_pref.silencio_hasta, time '07:00');
  v_crit  := coalesce(v_pref.criticas_en_silencio, false);
  if v_desde = v_hasta or (p_severidad = 'critica' and v_crit) then
    return p_cuando;
  end if;
  v_local := p_cuando at time zone v_zona;
  v_hora  := v_local::time;
  v_en_silencio := case when v_desde > v_hasta then (v_hora >= v_desde or v_hora < v_hasta)
                        else (v_hora >= v_desde and v_hora < v_hasta) end;
  if not v_en_silencio then
    return p_cuando;
  end if;
  v_local := case when v_desde > v_hasta and v_hora >= v_desde
                  then (v_local::date + 1) + v_hasta
                  else v_local::date + v_hasta end;
  return v_local at time zone v_zona;
end
$$;

create function public.avisos_insertar(
  p_hogar_id uuid, p_persona_id uuid, p_modulo text, p_tipo text, p_libro_id uuid,
  p_objeto_tipo text, p_objeto_id uuid, p_clave text, p_programado timestamptz,
  p_emisor uuid default null, p_ahora timestamptz default now())
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_pref   public.avisos_preferencias%rowtype;
  v_zona   text;
  v_sev    text := public.avisos_severidad(p_tipo);
  v_envio  timestamptz;
  v_estado text := 'pendiente';
  v_dia    date;
  v_n      integer;
  v_fijo   boolean := p_tipo in ('resumen_lunes', 'recordatorio_cierre');
  v_id     uuid := md5('aviso:' || p_persona_id::text || ':' || p_clave)::uuid;
  v_filas  integer;
begin
  select * into v_pref from public.avisos_preferencias p where p.persona_id = p_persona_id;
  v_zona  := coalesce(v_pref.zona_horaria, 'America/Mexico_City');
  v_envio := public.avisos_ajustar_envio(p_persona_id, v_sev, greatest(p_programado, p_ahora));
  -- Un tipo silenciado no suena, pero sigue a la vista en la bandeja.
  if p_tipo = any (coalesce(v_pref.tipos_silenciados, '{}')) then
    v_estado := 'agrupada';
  elsif v_sev <> 'critica' and not v_fijo then
    v_dia := (v_envio at time zone v_zona)::date;
    select count(*) into v_n from public.avisos a
     where a.persona_id = p_persona_id and a.severidad <> 'critica' and a.estado <> 'cancelada'
       and a.tipo not in ('resumen_lunes', 'recordatorio_cierre')
       and (a.enviar_en at time zone v_zona)::date = v_dia;
    if v_n >= coalesce(v_pref.tope_no_criticas, 3) then
      v_estado := 'agrupada';
    end if;
  end if;
  insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, libro_id, objeto_tipo,
                             objeto_id, programado_para, enviar_en, estado, emitido_por, creado_en)
  values (v_id, p_hogar_id, p_persona_id, p_modulo, p_tipo, v_sev, p_clave, p_libro_id, p_objeto_tipo,
          p_objeto_id, p_programado, v_envio, v_estado, p_emisor, p_ahora)
  on conflict (persona_id, clave) do nothing;
  get diagnostics v_filas = row_count;
  return v_filas > 0;
end
$$;
comment on function public.avisos_insertar(uuid, uuid, text, text, uuid, text, uuid, text, timestamptz, uuid, timestamptz) is
  'Interna. Inserta un aviso de forma idempotente por (persona, clave), aplicando el silencio y el tope diario.';

-- -----------------------------------------------------------------------------
-- 6. Funciones para la app
-- -----------------------------------------------------------------------------
create function public.fin_emitir_aviso(
  p_libro_id uuid, p_tipo text, p_objeto_tipo text, p_objeto_id uuid, p_clave text)
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro   public.fin_libros%rowtype;
  v_actor   uuid := public.persona_actual();
  v_persona uuid;
  v_n       integer := 0;
  v_hoy     integer;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found or not public.fin_puede(p_libro_id, 'escribir') then
    raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos de ese libro.';
  end if;
  if not public.avisos_tipo_emitible(p_tipo) then
    raise exception using errcode = '22023', message = 'Ese tipo de aviso no lo emite la app.';
  end if;
  if p_objeto_tipo is not null and p_objeto_tipo not in ('deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento') then
    raise exception using errcode = '22023', message = 'Tipo de objeto no válido.';
  end if;
  if (p_objeto_tipo is null) <> (p_objeto_id is null) then
    raise exception using errcode = '22023', message = 'El objeto lleva tipo e id, o ninguno.';
  end if;
  if p_clave is null or char_length(p_clave) > 120 or p_clave !~ '^[a-z0-9_:.-]+$' then
    raise exception using errcode = '22023', message = 'La clave son minúsculas, dígitos y _ : . - (máximo 120).';
  end if;
  select count(distinct a.clave) into v_hoy from public.avisos a
   where a.emitido_por = v_actor and a.creado_en > now() - interval '24 hours';
  if v_hoy >= 60 then
    raise exception using errcode = '22023', message = 'Se llegó al tope de 60 avisos al día por persona.';
  end if;
  for v_persona in select * from public.fin_avisos_destinatarios(p_libro_id, p_tipo, v_actor) loop
    if public.avisos_insertar(v_libro.hogar_id, v_persona, 'finanzas', p_tipo, p_libro_id, p_objeto_tipo,
                              p_objeto_id, p_clave, now(), v_actor) then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end
$$;
comment on function public.fin_emitir_aviso(uuid, text, text, uuid, text) is
  'La app emite los avisos que solo el motor sabe calcular. Valida escribir en el libro y que el tipo sea emitible; los '
  'destinatarios los calcula el servidor; idempotente por clave; 60 por persona al día (22023). Devuelve cuántos creó.';

create function public.avisos_marcar(p_aviso_id uuid, p_accion text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_a    public.avisos%rowtype;
  v_pref public.avisos_preferencias%rowtype;
  v_zona text;
  v_man  timestamptz;
begin
  select * into v_a from public.avisos a where a.id = p_aviso_id and a.persona_id = public.persona_actual();
  if not found then
    raise exception using errcode = '42501', message = 'Ese aviso no es tuyo.';
  end if;
  if p_accion = 'leida' then
    update public.avisos set estado = 'leida', leida_en = now() where id = p_aviso_id and estado <> 'cancelada';
  elsif p_accion = 'resuelta' then
    update public.avisos set estado = 'resuelta', resuelta_en = now(), leida_en = coalesce(leida_en, now())
     where id = p_aviso_id and estado <> 'cancelada';
  elsif p_accion = 'posponer_1h' then
    update public.avisos set estado = 'pospuesta', enviar_en = public.avisos_ajustar_envio(persona_id, severidad, now() + interval '1 hour'),
                             reclamado_hasta = null
     where id = p_aviso_id and estado in ('pendiente', 'enviada', 'agrupada', 'pospuesta', 'leida');
  elsif p_accion = 'posponer_manana' then
    select * into v_pref from public.avisos_preferencias p where p.persona_id = v_a.persona_id;
    v_zona := coalesce(v_pref.zona_horaria, 'America/Mexico_City');
    v_man := (((now() at time zone v_zona)::date + 1) + coalesce(v_pref.hora_vencimientos, time '09:00')) at time zone v_zona;
    update public.avisos set estado = 'pospuesta', enviar_en = public.avisos_ajustar_envio(persona_id, severidad, v_man),
                             reclamado_hasta = null
     where id = p_aviso_id and estado in ('pendiente', 'enviada', 'agrupada', 'pospuesta', 'leida');
  else
    raise exception using errcode = '22023', message = 'La acción es leida, resuelta, posponer_1h o posponer_manana.';
  end if;
end
$$;
comment on function public.avisos_marcar(uuid, text) is
  'La persona marca SU aviso: leida, resuelta, posponer_1h o posponer_manana (vuelve a salir a esa hora). Otro: 42501.';

create function public.avisos_actualizar_preferencias(
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
             'resumen_lunes', 'recordatorio_cierre')) then
    raise exception using errcode = '22023', message = 'Tipo de aviso desconocido.';
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
comment on function public.avisos_actualizar_preferencias(text, time, time, boolean, integer, time, time, integer, time, text[], boolean) is
  'La persona cambia SUS preferencias (los parámetros nulos no cambian). Valida rangos: tope de 0 a 10, zona horaria real, '
  'tipos del catálogo. La cuenta maestra que no es la dueña no tiene preferencias (42501).';

-- -----------------------------------------------------------------------------
-- 7. Avisos del servidor: salida de papá, retiro compartido, resolución
-- -----------------------------------------------------------------------------
create function public.fin_aviso_salida_representado(
  p_hogar_id uuid, p_libro_origen_id uuid, p_movimiento_id uuid, p_actor uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_suplente uuid;
begin
  select m.persona_id into v_suplente
  from public.fin_libro_miembros m
  where m.libro_id = p_libro_origen_id and m.papel = 'albacea_suplente' and m.desde <= now()
    and (m.hasta is null or m.hasta > now())
    and public.fin_destinatario_valido(p_hogar_id, m.persona_id);
  if v_suplente is null or v_suplente is not distinct from p_actor then
    return;
  end if;
  perform public.avisos_insertar(p_hogar_id, v_suplente, 'finanzas', 'salida_libro_representado', p_libro_origen_id,
                                 'movimiento', p_movimiento_id, 'salida_libro_representado:' || p_movimiento_id::text,
                                 now(), p_actor);
end
$$;

-- N3 (Fase 1b) + aviso al suplente dentro de la misma función.
create or replace function public.fin_movimientos_salida_representado()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.libro_origen_id is not null and new.libro_destino_id is not null
     and new.libro_origen_id <> new.libro_destino_id
     and exists (select 1 from public.fin_libros o where o.id = new.libro_origen_id and o.tipo = 'representado') then
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (new.hogar_id, public.persona_actual(), 'finanzas.salida_libro_representado', 'fin_movimientos',
            new.id::text,
            jsonb_build_object('libro_id', new.libro_origen_id, 'libro_destino_id', new.libro_destino_id,
                               'tipo', new.tipo, 'fecha', new.fecha, 'monto_centavos', new.monto_centavos,
                               'en_nombre_de', new.en_nombre_de, 'motivo', new.motivo));
    perform public.fin_aviso_salida_representado(new.hogar_id, new.libro_origen_id, new.id, public.persona_actual());
  end if;
  return null;
end
$$;

-- Retiro de una bolsa de un libro compartido: aviso informativo a los OTROS miembros.
create function public.fin_retiros_avisar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid;
begin
  if exists (select 1 from public.fin_libros l where l.id = new.libro_id and l.tipo = 'compartido') then
    for v_persona in select * from public.fin_avisos_destinatarios(new.libro_id, 'retiro_bolsa_compartida', new.registrado_por) loop
      if v_persona <> new.registrado_por then
        perform public.avisos_insertar(new.hogar_id, v_persona, 'finanzas', 'retiro_bolsa_compartida', new.libro_id,
                                       'movimiento', new.movimiento_id, 'retiro_bolsa_compartida:' || new.id::text,
                                       now(), new.registrado_por);
      end if;
    end loop;
  end if;
  return null;
end
$$;
create trigger fin_y_avisar after insert on public.fin_retiros_ahorro
  for each row execute function public.fin_retiros_avisar();

-- Registrar el pago (la ocurrencia deja de estar pendiente) o cambiar su fecha cancela los avisos pendientes.
create function public.avisos_cancelar_por_ocurrencia()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.estado not in ('esperada', 'retrasada') or new.fecha_ajustada is distinct from old.fecha_ajustada then
    update public.avisos a set estado = 'cancelada'
     where a.objeto_tipo = 'ocurrencia' and a.objeto_id = new.id
       and a.estado in ('pendiente', 'agrupada', 'pospuesta')
       and (new.estado not in ('esperada', 'retrasada') or split_part(a.clave, ':', 3) <> new.fecha_ajustada::text);
  end if;
  return null;
end
$$;
create trigger avisos_z_cancelar after update of estado, fecha_ajustada on public.fin_ocurrencias
  for each row execute function public.avisos_cancelar_por_ocurrencia();

-- Consultas repetidas de la maestra (P12 por defecto): una entrada por minuto y libro.
create or replace function public.fin_registrar_consulta_maestra(p_libro_id uuid)
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found or not public.es_cuenta_maestra(v_libro.hogar_id) then
    raise exception using errcode = '42501', message = 'Solo la cuenta maestra del hogar registra consultas.';
  end if;
  if public.fin_es_miembro(p_libro_id) then
    return false;  -- lo propio no se registra
  end if;
  if exists (select 1 from public.bitacora b
              where b.accion = 'finanzas.consulta_maestra' and b.persona_id = public.persona_actual()
                and b.registro_id = p_libro_id::text and b.registrado_en > now() - interval '1 minute') then
    return true;  -- ya hay una entrada del último minuto: la consulta sigue vigente y no engorda la bitácora
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_libro.hogar_id, public.persona_actual(), 'finanzas.consulta_maestra', 'fin_libros',
          p_libro_id::text,
          jsonb_build_object('libro_id', p_libro_id, 'tipo', v_libro.tipo,
                             'vigencia_minutos', (extract(epoch from public.fin_vigencia_consulta_maestra()) / 60)::integer));
  return true;
end
$$;

-- -----------------------------------------------------------------------------
-- 8. Programación: vencimientos, ingresos retrasados, base de datos y limpieza
-- -----------------------------------------------------------------------------
create function public.fin_siguiente_dia_habil(p_hogar_id uuid, p_fecha date)
returns date
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_d date := p_fecha + 1;
begin
  while extract(isodow from v_d) in (6, 7)
        or exists (select 1 from public.fin_dias_inhabiles i where i.hogar_id = p_hogar_id and i.fecha = v_d and i.activo) loop
    v_d := v_d + 1;
  end loop;
  return v_d;
end
$$;

create function public.avisos_generar_vencimientos(p_ahora timestamptz default now())
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  r        record;
  v_pers   uuid;
  v_pref   public.avisos_preferencias%rowtype;
  v_zona   text;
  v_hora   time;
  v_hoy    date := (p_ahora at time zone 'America/Mexico_City')::date;
  v_dias   smallint[];
  v_n      smallint;
  v_ts     timestamptz;
  v_tipo   text;
  v_creados integer := 0;
begin
  -- Un pago esperado cuya fecha ya pasó queda retrasado.
  update public.fin_ocurrencias o set estado = 'retrasada'
   where o.origen = 'deuda' and o.estado = 'esperada' and o.fecha_ajustada < v_hoy and o.monto_esperado > 0;

  for r in
    select o.id, o.hogar_id, o.libro_id, o.fecha_ajustada, o.estado, d.clase,
           coalesce(pa.dias_aviso_deuda, '{3,1}'::smallint[]) as dias
    from public.fin_ocurrencias o
    join public.fin_deudas d on d.libro_id = o.libro_id and d.id = o.origen_id
    join public.fin_libros l on l.id = o.libro_id and l.activo
    left join public.fin_parametros pa on pa.libro_id = o.libro_id
    where o.origen = 'deuda' and o.estado in ('esperada', 'retrasada') and o.monto_esperado > 0 and d.activa
      and o.fecha_ajustada between v_hoy - 3 and v_hoy + 14
  loop
    -- La fecha cambió: los avisos pendientes del paso viejo se cancelan.
    update public.avisos a set estado = 'cancelada'
     where a.objeto_tipo = 'ocurrencia' and a.objeto_id = r.id
       and a.estado in ('pendiente', 'agrupada', 'pospuesta') and split_part(a.clave, ':', 3) <> r.fecha_ajustada::text;
    v_tipo := case when r.clase = 'tarjeta' then 'limite_tarjeta' else 'pago_proximo' end;
    for v_pers in select * from public.fin_avisos_destinatarios(r.libro_id, v_tipo) loop
      select * into v_pref from public.avisos_preferencias p where p.persona_id = v_pers;
      v_zona := coalesce(v_pref.zona_horaria, 'America/Mexico_City');
      v_hora := coalesce(v_pref.hora_vencimientos, time '09:00');
      if r.fecha_ajustada >= v_hoy and r.estado = 'esperada' then
        -- Días antes: solo los que aún no pasaron (no se recupera lo atrasado).
        foreach v_n in array r.dias loop
          v_ts := ((r.fecha_ajustada - v_n::integer) + v_hora) at time zone v_zona;
          if v_ts > p_ahora and public.avisos_insertar(r.hogar_id, v_pers, 'finanzas', v_tipo, r.libro_id, 'ocurrencia',
                r.id, v_tipo || ':' || r.id::text || ':' || r.fecha_ajustada::text || ':' || v_n::text, v_ts, null, p_ahora) then
            v_creados := v_creados + 1;
          end if;
        end loop;
      else
        -- Vencido: uno al día siguiente y otro a los 3 días; luego se calla.
        foreach v_n in array array[1, 3]::smallint[] loop
          v_ts := ((r.fecha_ajustada + v_n::integer) + v_hora) at time zone v_zona;
          if v_ts > p_ahora - interval '36 hours' and public.avisos_insertar(r.hogar_id, v_pers, 'finanzas', 'pago_vencido',
                r.libro_id, 'ocurrencia', r.id,
                'pago_vencido:' || r.id::text || ':' || r.fecha_ajustada::text || ':' || v_n::text, v_ts, null, p_ahora) then
            v_creados := v_creados + 1;
          end if;
        end loop;
      end if;
    end loop;
  end loop;

  -- Ingreso retrasado: sin cumplir al siguiente día hábil de su fecha.
  for r in
    select o.id, o.hogar_id, o.libro_id, o.fecha_ajustada,
           public.fin_siguiente_dia_habil(o.hogar_id, o.fecha_ajustada) as limite
    from public.fin_ocurrencias o
    join public.fin_libros l on l.id = o.libro_id and l.activo
    where o.origen = 'ingreso' and o.estado in ('esperada', 'retrasada') and o.monto_esperado > 0
      and o.fecha_ajustada between v_hoy - 3 and v_hoy + 1
  loop
    update public.avisos a set estado = 'cancelada'
     where a.objeto_tipo = 'ocurrencia' and a.objeto_id = r.id
       and a.estado in ('pendiente', 'agrupada', 'pospuesta') and split_part(a.clave, ':', 3) <> r.fecha_ajustada::text;
    for v_pers in select * from public.fin_avisos_destinatarios(r.libro_id, 'ingreso_retrasado') loop
      select * into v_pref from public.avisos_preferencias p where p.persona_id = v_pers;
      v_zona := coalesce(v_pref.zona_horaria, 'America/Mexico_City');
      v_ts := (r.limite + coalesce(v_pref.hora_vencimientos, time '09:00')) at time zone v_zona;
      if v_ts > p_ahora - interval '36 hours' and public.avisos_insertar(r.hogar_id, v_pers, 'finanzas', 'ingreso_retrasado',
            r.libro_id, 'ocurrencia', r.id,
            'ingreso_retrasado:' || r.id::text || ':' || r.fecha_ajustada::text || ':1', v_ts, null, p_ahora) then
        v_creados := v_creados + 1;
      end if;
    end loop;
  end loop;
  return v_creados;
end
$$;
comment on function public.avisos_generar_vencimientos(timestamptz) is
  'Cada hora (pg_cron). Pagos de deuda: avisos 3 y 1 días antes (dias_aviso_deuda) a la hora de la persona, solo los que '
  'aún no pasaron; vencidos: al día siguiente y a los 3 días; ingresos sin llegar al siguiente día hábil. Idempotente por '
  'clave; cancela los avisos de una fecha vieja. p_ahora es solo para pruebas.';

create function public.avisos_revisar_base(p_bytes bigint default null, p_ahora timestamptz default now())
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_limite bigint;
  v_aviso  numeric;
  v_crit   numeric;
  v_bytes  bigint := coalesce(p_bytes, pg_catalog.pg_database_size(pg_catalog.current_database()));
  v_pct    numeric;
  v_tipo   text;
  v_dueno  record;
  v_n      integer := 0;
begin
  select (valor #>> '{}')::bigint into v_limite from public.avisos_sistema where clave = 'limite_base_bytes';
  select (valor #>> '{}')::numeric into v_aviso from public.avisos_sistema where clave = 'umbral_aviso_pct';
  select (valor #>> '{}')::numeric into v_crit from public.avisos_sistema where clave = 'umbral_critico_pct';
  if coalesce(v_limite, 0) <= 0 then
    return 0;
  end if;
  v_pct := v_bytes::numeric * 100 / v_limite;
  v_tipo := case when v_pct >= coalesce(v_crit, 90) then 'base_90'
                 when v_pct >= coalesce(v_aviso, 80) then 'base_80' end;
  if v_tipo is null then
    return 0;
  end if;
  for v_dueno in
    select m.hogar_id, m.persona_id from public.membresias m
     where m.rol = 'dueno' and m.activa and m.desde <= p_ahora and (m.hasta is null or m.hasta > p_ahora)
  loop
    if public.avisos_insertar(v_dueno.hogar_id, v_dueno.persona_id, 'sistema', v_tipo, null, null, null,
         v_tipo || ':' || to_char(p_ahora at time zone 'America/Mexico_City', 'YYYY-MM-DD'), p_ahora, null, p_ahora) then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end
$$;
comment on function public.avisos_revisar_base(bigint, timestamptz) is
  'Diaria (06:00 hora de México). Con la base al 80 % avisa (importante) y al 90 % (crítico) SOLO al dueño de cada hogar; uno '
  'por día. p_bytes y p_ahora son solo para pruebas.';

create function public.avisos_estado_base()
returns table (bytes bigint, limite_bytes bigint, porcentaje numeric)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_limite bigint;
begin
  if not exists (select 1 from public.membresias m where m.persona_id = public.persona_actual() and m.rol = 'dueno'
                  and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
    raise exception using errcode = '42501', message = 'Solo el dueño ve el estado de la base.';
  end if;
  select (valor #>> '{}')::bigint into v_limite from public.avisos_sistema where clave = 'limite_base_bytes';
  return query select pg_catalog.pg_database_size(pg_catalog.current_database()), v_limite,
                      round(pg_catalog.pg_database_size(pg_catalog.current_database())::numeric * 100 / nullif(v_limite, 0), 1);
end
$$;
comment on function public.avisos_estado_base() is
  'Solo el dueño: tamaño de la base, su límite y el porcentaje (Ajustes › Copias de seguridad). Solo lectura.';

create function public.avisos_limpiar(p_ahora timestamptz default now())
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  delete from public.avisos_entregas e where e.enviada_en < p_ahora - interval '30 days';
  delete from public.avisos a where a.creado_en < p_ahora - interval '90 days';
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
comment on function public.avisos_limpiar(timestamptz) is
  'Nocturna. Borra avisos de más de 90 días y entregas de más de 30. Es la única excepción al "nadie borra" '
  '(no son libro contable). La bitácora no se toca.';

-- -----------------------------------------------------------------------------
-- 9. Funciones para la Edge Function enviar-avisos (solo service_role)
-- -----------------------------------------------------------------------------
-- Reclama hasta p_limite avisos listos con "for update skip locked" y los marca como reclamados por 3 minutos,
-- así dos corridas a la vez no duplican. Devuelve un renglón por aviso y dispositivo. NUNCA incluye
-- tablet_publica ni equipos con recibe_avisos = false, ni a personas dadas de baja.
create function public.avisos_reclamar(p_limite integer default 200, p_ahora timestamptz default now())
returns table (aviso_id uuid, intentos smallint, dispositivo_id uuid, token text)
language sql volatile security definer
set search_path = ''
as $$
  with c as (
    select a.id
    from public.avisos a
    where a.estado in ('pendiente', 'pospuesta') and a.enviar_en <= p_ahora
      and (a.reclamado_hasta is null or a.reclamado_hasta < p_ahora)
      and exists (select 1 from public.dispositivos d
                   where d.persona_id = a.persona_id and d.recibe_avisos and d.tipo <> 'tablet_publica'
                     and d.token_avisos is not null)
      and exists (select 1 from public.membresias m
                   where m.persona_id = a.persona_id and m.hogar_id = a.hogar_id and m.activa
                     and m.desde <= p_ahora and (m.hasta is null or m.hasta > p_ahora))
    order by a.enviar_en
    limit greatest(least(coalesce(p_limite, 200), 200), 0)
    for update skip locked
  ), u as (
    update public.avisos a set reclamado_hasta = p_ahora + interval '3 minutes'
      from c where a.id = c.id
    returning a.id, a.persona_id, a.intentos
  )
  select u.id, u.intentos, d.id, d.token_avisos
  from u
  join public.dispositivos d on d.persona_id = u.persona_id and d.recibe_avisos and d.tipo <> 'tablet_publica'
                            and d.token_avisos is not null
$$;

create function public.avisos_registrar_entrega(
  p_aviso_id uuid, p_dispositivo_id uuid, p_resultado text, p_codigo text default null)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  if p_resultado not in ('ok', 'token_invalido', 'error') then
    raise exception using errcode = '22023', message = 'El resultado es ok, token_invalido o error.';
  end if;
  insert into public.avisos_entregas (aviso_id, dispositivo_id, resultado, codigo)
  values (p_aviso_id, p_dispositivo_id, p_resultado, left(p_codigo, 60));
  if p_resultado = 'ok' then
    update public.dispositivos set ultimo_envio_en = now(), fallos = 0 where id = p_dispositivo_id;
  elsif p_resultado = 'token_invalido' then
    delete from public.dispositivos where id = p_dispositivo_id;
  else
    update public.dispositivos set fallos = least(fallos + 1, 32000) where id = p_dispositivo_id;
    update public.dispositivos set recibe_avisos = false where id = p_dispositivo_id and fallos >= 5;
  end if;
end
$$;

-- Reintentos a los 5, 15 y 60 minutos; después se da por enviado-sin-entrega (queda en la bandeja).
create function public.avisos_resultado_envio(p_aviso_id uuid, p_ok boolean, p_ahora timestamptz default now())
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_intentos smallint;
begin
  if p_ok then
    update public.avisos set estado = 'enviada', enviada_en = p_ahora, reclamado_hasta = null
     where id = p_aviso_id and estado in ('pendiente', 'pospuesta');
    return;
  end if;
  update public.avisos set intentos = intentos + 1, reclamado_hasta = null
   where id = p_aviso_id and estado in ('pendiente', 'pospuesta')
  returning intentos into v_intentos;
  if v_intentos is null then
    return;
  end if;
  if v_intentos <= 3 then
    update public.avisos set enviar_en = p_ahora + (case v_intentos when 1 then interval '5 minutes'
                                                                    when 2 then interval '15 minutes'
                                                                    else interval '60 minutes' end)
     where id = p_aviso_id;
  else
    update public.avisos set estado = 'enviada', enviada_en = p_ahora where id = p_aviso_id;
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 10. Tareas (pg_cron + pg_net), solo si el proyecto las tiene
-- -----------------------------------------------------------------------------
-- La URL del proyecto y la clave de servicio viven en el Vault de Supabase (nunca en el repositorio):
--   select vault.create_secret('https://<ref>.supabase.co', 'gravity_project_url');
--   select vault.create_secret('<clave service_role>', 'gravity_service_role_key');
-- Sin esos secretos la tarea no hace nada.
create function public.avisos_invocar_enviar()
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_url   text;
  v_clave text;
begin
  if to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null
     or to_regclass('vault.decrypted_secrets') is null then
    return;
  end if;
  execute 'select decrypted_secret from vault.decrypted_secrets where name = ''gravity_project_url''' into v_url;
  execute 'select decrypted_secret from vault.decrypted_secrets where name = ''gravity_service_role_key''' into v_clave;
  if v_url is null or v_clave is null then
    return;
  end if;
  execute 'select net.http_post(url := $1, headers := $2, body := $3)'
    using v_url || '/functions/v1/enviar-avisos',
          jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_clave),
          '{}'::jsonb;
end
$$;

do $$
begin
  begin
    create extension if not exists pg_cron;
    create extension if not exists pg_net;
  exception when others then
    raise notice 'pg_cron o pg_net no están disponibles aquí (%): activa las extensiones en Supabase y vuelve a programar las tareas.', sqlerrm;
  end;
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('avisos-vencimientos', '0 * * * *', 'select public.avisos_generar_vencimientos()');
    perform cron.schedule('avisos-base', '0 12 * * *', 'select public.avisos_revisar_base()');
    perform cron.schedule('avisos-limpieza', '30 9 * * *', 'select public.avisos_limpiar()');
    perform cron.schedule('avisos-enviar', '*/5 * * * *', 'select public.avisos_invocar_enviar()');
  end if;
end
$$;

-- -----------------------------------------------------------------------------
-- 11. Privilegios de las funciones
-- -----------------------------------------------------------------------------
revoke execute on function
  public.avisos_severidad(text), public.avisos_tipo_emitible(text), public.fin_destinatario_valido(uuid, uuid),
  public.avisos_preferencias_sincronizar(), public.dispositivos_sin_avisos_en_tablet_publica(),
  public.registrar_dispositivo(text, text, text, text), public.quitar_dispositivo(text),
  public.fin_avisos_destinatarios(uuid, text, uuid), public.avisos_ajustar_envio(uuid, text, timestamptz),
  public.avisos_insertar(uuid, uuid, text, text, uuid, text, uuid, text, timestamptz, uuid, timestamptz),
  public.fin_emitir_aviso(uuid, text, text, uuid, text), public.avisos_marcar(uuid, text),
  public.avisos_actualizar_preferencias(text, time, time, boolean, integer, time, time, integer, time, text[], boolean),
  public.fin_aviso_salida_representado(uuid, uuid, uuid, uuid), public.fin_retiros_avisar(),
  public.avisos_cancelar_por_ocurrencia(), public.fin_siguiente_dia_habil(uuid, date),
  public.avisos_generar_vencimientos(timestamptz), public.avisos_revisar_base(bigint, timestamptz),
  public.avisos_limpiar(timestamptz), public.avisos_reclamar(integer, timestamptz),
  public.avisos_registrar_entrega(uuid, uuid, text, text), public.avisos_resultado_envio(uuid, boolean, timestamptz),
  public.avisos_invocar_enviar(), public.avisos_estado_base()
  from public, anon, authenticated, service_role;

-- Para la app (con sesión).
grant execute on function
  public.registrar_dispositivo(text, text, text, text), public.quitar_dispositivo(text),
  public.fin_emitir_aviso(uuid, text, text, uuid, text), public.avisos_marcar(uuid, text), public.avisos_estado_base(),
  public.avisos_actualizar_preferencias(text, time, time, boolean, integer, time, time, integer, time, text[], boolean)
  to authenticated;
-- Para la Edge Function y las tareas.
grant execute on function
  public.avisos_reclamar(integer, timestamptz), public.avisos_registrar_entrega(uuid, uuid, text, text),
  public.avisos_resultado_envio(uuid, boolean, timestamptz)
  to service_role;
