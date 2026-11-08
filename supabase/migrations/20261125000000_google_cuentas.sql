-- =============================================================================
-- GRAVITY · Fase 6 · Cuentas de Google del asistente (Gmail y Calendar), migración hacia adelante
-- =============================================================================
-- Cada persona conecta SU cuenta de Google (ambito 'personal'); la casa tiene UNA cuenta de Google propia (ambito 'casa'),
-- conectada por el dueño. Aquí solo vive el token de renovación (refresh token) CIFRADO por la función gravity-asistente
-- (AES-256-GCM con GOOGLE_TOKEN_KEY, secreto del servidor, nunca en la base ni en la app). La base nunca ve el token en claro.
--   - RLS: cada persona ve solo la fila de SU cuenta (persona_id = persona_actual()). Nadie más: ni el dueño ni la pareja.
--   - Aun para la dueña, la app NO puede leer token_cifrado: el privilegio de columna solo cubre los datos de estado.
--   - Escribir (conectar, renovar) solo lo hace el servidor (service_role). La app solo puede desconectar (función) y,
--     el dueño, aprobar o quitar el acceso de Casa al calendario de la casa.
--   - Casa nunca lee Gmail: el servidor solo le deja calendario.ver de la cuenta 'casa' y solo si acceso_casa = true.
-- Sin secretos ni valores reales.
-- =============================================================================

create table public.google_cuentas (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  -- Quien conectó la cuenta y es su dueña. En la cuenta de la casa, el dueño del hogar.
  persona_id     uuid not null references public.personas (id),
  ambito         text not null check (ambito in ('personal', 'casa')),
  correo         text not null check (char_length(correo) between 3 and 320),
  alcances       text[] not null check (cardinality(alcances) between 1 and 10),
  -- Refresh token cifrado (formato v1:<iv>:<texto>, base64). Nunca en claro.
  token_cifrado  text not null check (token_cifrado ~ '^v1:[A-Za-z0-9+/=_-]+:[A-Za-z0-9+/=_-]+$'),
  -- Solo la cuenta de la casa: el dueño aprobó que Casa vea el calendario de la casa.
  acceso_casa    boolean not null default false,
  conectada_en   timestamptz not null default now(),
  actualizada_en timestamptz not null default now(),
  constraint google_cuentas_acceso_casa_solo_casa check (ambito = 'casa' or acceso_casa = false)
);
create unique index google_cuentas_una_personal on public.google_cuentas (persona_id) where ambito = 'personal';
create unique index google_cuentas_una_casa on public.google_cuentas (hogar_id) where ambito = 'casa';

comment on table public.google_cuentas is
  'Cuenta de Google conectada al asistente. El token de renovación va cifrado por el servidor; la app nunca lo lee.';
comment on column public.google_cuentas.token_cifrado is
  'AES-256-GCM con GOOGLE_TOKEN_KEY (secreto de la función). No hay privilegio de lectura para authenticated.';

alter table public.google_cuentas enable row level security;
create policy google_cuentas_propia on public.google_cuentas for select to authenticated
  using (persona_id = (select public.persona_actual()));

revoke all on table public.google_cuentas from public, anon, authenticated, service_role;
grant select (id, hogar_id, persona_id, ambito, correo, alcances, acceso_casa, conectada_en, actualizada_en)
  on public.google_cuentas to authenticated;
grant select, insert, update, delete on public.google_cuentas to service_role;

-- El dueño aprueba (o quita) que Casa vea el calendario de la casa.
create function public.google_acceso_casa(p_hogar_id uuid, p_permitir boolean)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_filas integer;
begin
  if (select public.rol_en_hogar(p_hogar_id)) is distinct from 'dueno' then
    raise exception 'Solo el dueño decide si Casa ve el calendario de la casa.' using errcode = '42501';
  end if;
  update public.google_cuentas c
     set acceso_casa = coalesce(p_permitir, false), actualizada_en = now()
   where c.hogar_id = p_hogar_id and c.ambito = 'casa';
  get diagnostics v_filas = row_count;
  if v_filas = 0 then
    raise exception 'Aún no hay una cuenta de Google de la casa conectada.' using errcode = '22023';
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, detalle)
  values (p_hogar_id, public.persona_actual(), 'google.acceso_casa', 'google_cuentas',
          jsonb_build_object('permitir', coalesce(p_permitir, false)));
end
$$;

-- Desconectar: la persona quita SU cuenta; el dueño puede quitar la de la casa.
create function public.google_desconectar(p_hogar_id uuid, p_ambito text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_yo uuid := public.persona_actual();
begin
  if v_yo is null or (select public.rol_en_hogar(p_hogar_id)) is null then
    raise exception 'Sin permiso.' using errcode = '42501';
  end if;
  if p_ambito = 'personal' then
    delete from public.google_cuentas c where c.hogar_id = p_hogar_id and c.persona_id = v_yo and c.ambito = 'personal';
  elsif p_ambito = 'casa' then
    if (select public.rol_en_hogar(p_hogar_id)) is distinct from 'dueno' then
      raise exception 'Solo el dueño quita la cuenta de la casa.' using errcode = '42501';
    end if;
    delete from public.google_cuentas c where c.hogar_id = p_hogar_id and c.ambito = 'casa';
  else
    raise exception 'Ámbito inválido.' using errcode = '22023';
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, detalle)
  values (p_hogar_id, v_yo, 'google.desconectar', 'google_cuentas', jsonb_build_object('ambito', p_ambito));
end
$$;

revoke execute on function public.google_acceso_casa(uuid, boolean), public.google_desconectar(uuid, text)
  from public, anon;
grant execute on function public.google_acceso_casa(uuid, boolean), public.google_desconectar(uuid, text)
  to authenticated;
