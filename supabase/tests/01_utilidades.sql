-- =============================================================================
-- GRAVITY · Ayudantes para las pruebas SQL (SOLO PRUEBAS; no es migración)
-- =============================================================================
-- Se aplica después de las migraciones y del seed. Esquema "pruebas":
--   pruebas.como(correo)      Actúa como esa cuenta (rol authenticated + JWT).
--   pruebas.como_anon()       Actúa sin sesión (rol anon).
--   pruebas.como_servicio()   Actúa como service_role (funciones de servidor).
--   pruebas.como_postgres()   Vuelve al dueño de las tablas (sin RLS).
--   pruebas.ok(cond, desc)    Falla si cond no es verdadera.
--   pruebas.igual(a, b, desc) Falla si a es distinto de b (muestra ambos).
--   pruebas.cuenta(sql)       Cuántas filas ve el rol actual.
--   pruebas.afecta(sql)       Cuántas filas cambió (UPDATE o DELETE filtrado = 0).
--   pruebas.falla(sql, desc, sqlstate)  Exige que el SQL lance error (y su código).
--   pruebas.id_usuario(correo), pruebas.id_persona(correo)
-- Cada afirmación correcta imprime "NOTICE: ok - ..."; una falla lanza error.
-- =============================================================================

create schema pruebas;
grant usage on schema pruebas to anon, authenticated, service_role;

create function pruebas.id_usuario(p_correo text) returns uuid
language sql stable security definer set search_path = ''
as $$ select u.id from auth.users u where u.email = p_correo $$;

create function pruebas.id_persona(p_correo text) returns uuid
language sql stable security definer set search_path = ''
as $$
  select p.id from public.personas p join auth.users u on u.id = p.usuario_id
  where u.email = p_correo
$$;

create function pruebas.como(p_correo text) returns void
language plpgsql
as $$
declare
  v_id uuid := pruebas.id_usuario(p_correo);
begin
  if v_id is null then
    raise exception 'No existe la cuenta de prueba %', p_correo;
  end if;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_id, 'role', 'authenticated', 'email', p_correo)::text, true);
end
$$;

create function pruebas.como_anon(p_sub_falso uuid default null) returns void
language plpgsql
as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claim.sub', coalesce(p_sub_falso::text, ''), true);
  perform set_config('request.jwt.claim.role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end
$$;

create function pruebas.como_servicio() returns void
language plpgsql
as $$
begin
  perform set_config('role', 'service_role', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
end
$$;

create function pruebas.como_postgres() returns void
language plpgsql
as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', '', true);
  perform set_config('request.jwt.claims', '', true);
end
$$;

create function pruebas.ok(p_cond boolean, p_desc text) returns void
language plpgsql
as $$
begin
  if p_cond is distinct from true then
    raise exception 'FALLA: %', p_desc;
  end if;
  raise notice 'ok - %', p_desc;
end
$$;

create function pruebas.igual(p_obtenido anyelement, p_esperado anyelement, p_desc text) returns void
language plpgsql
as $$
begin
  if p_obtenido is distinct from p_esperado then
    raise exception 'FALLA: % (obtenido: %, esperado: %)', p_desc,
      coalesce(p_obtenido::text, 'NULL'), coalesce(p_esperado::text, 'NULL');
  end if;
  raise notice 'ok - %', p_desc;
end
$$;

create function pruebas.cuenta(p_sql text) returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  execute format('select count(*) from (%s) as q', p_sql) into v_n;
  return v_n;
end
$$;

create function pruebas.afecta(p_sql text) returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  execute p_sql;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;

create function pruebas.falla(p_sql text, p_desc text, p_estado text default null) returns void
language plpgsql
as $$
declare
  v_estado  text;
  v_mensaje text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_estado = returned_sqlstate, v_mensaje = message_text;
  end;
  if v_estado is null then
    raise exception 'FALLA: % (se esperaba un error y no lo hubo)', p_desc;
  end if;
  if p_estado is not null and v_estado <> p_estado then
    raise exception 'FALLA: % (error % "%"; se esperaba %)', p_desc, v_estado, v_mensaje, p_estado;
  end if;
  raise notice 'ok - % [%]', p_desc, v_estado;
end
$$;

grant execute on all functions in schema pruebas to anon, authenticated, service_role;
