-- =============================================================================
-- GRAVITY · Emulación mínima de Supabase para pruebas locales
-- =============================================================================
-- SOLO PARA PRUEBAS. NO es una migración y nunca se aplica al proyecto real:
-- en Supabase todo esto ya existe (esquema auth, auth.uid() y los roles).
--
-- Reproduce lo necesario para probar las reglas por rol (RLS):
--   * Roles sin login anon, authenticated y service_role (este con BYPASSRLS).
--   * Privilegios por defecto de Supabase: anon y authenticated reciben TODOS
--     los permisos sobre lo que se crea en public. Por eso las migraciones de
--     GRAVITY revocan y conceden de forma explícita, y las reglas (RLS) son la
--     verdad. Las pruebas así reflejan el peor caso del proyecto real.
--   * Esquema auth con auth.users (subconjunto de columnas reales) y las
--     funciones auth.uid(), auth.role() y auth.jwt(), que leen las mismas
--     variables de sesión que PostgREST.
--
-- Es idempotente: se puede correr en un servidor donde los roles ya existen
-- (p. ej. el Postgres de Supabase local) dentro de una base nueva.
-- =============================================================================

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

-- Privilegios por defecto como en Supabase (lo que crea postgres en public).
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Esquema auth
-- -----------------------------------------------------------------------------
create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

-- Subconjunto de las columnas reales de auth.users (mismos nombres y tipos),
-- suficiente para que seed.sql funcione igual aquí y en Supabase local.
create table if not exists auth.users (
  instance_id        uuid,
  id                 uuid primary key,
  aud                varchar(255),
  role               varchar(255),
  email              varchar(255),
  encrypted_password varchar(255),
  email_confirmed_at timestamptz,
  confirmation_token varchar(255),
  recovery_token     varchar(255),
  email_change_token_new varchar(255),
  email_change       varchar(255),
  raw_app_meta_data  jsonb,
  raw_user_meta_data jsonb,
  created_at         timestamptz default now(),
  updated_at         timestamptz default now(),
  deleted_at         timestamptz
);

-- auth.uid(): igual que en Supabase, lee la variable de sesión del JWT.
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create or replace function auth.role() returns text
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

create or replace function auth.jwt() returns jsonb
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')
  )::jsonb
$$;

grant execute on function auth.uid(), auth.role(), auth.jwt() to anon, authenticated, service_role;
