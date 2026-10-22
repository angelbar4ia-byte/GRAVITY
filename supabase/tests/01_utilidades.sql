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

-- -----------------------------------------------------------------------------
-- Finanzas (Fase 1)
--   pruebas.libro_personal(correo)       id del libro personal de esa cuenta.
--   pruebas.cuenta_sistema(libro, tipo)  Ajustes, Apertura o Por clasificar del libro.
--   pruebas.registrar(tipo, origen, destino, monto, ...)  Inserta un movimiento
--     como el rol actual (con RLS) y devuelve su id; nulo si el servidor no
--     insertó nada (mismo id y mismo contenido: idempotencia).
-- Libros fijos del seed: compartido f100…0001 ("Gastos de la casa") y
-- representado f100…0002 ("Papá (ejemplo)", persona e000…0001).
-- -----------------------------------------------------------------------------
create function pruebas.libro_personal(p_correo text) returns uuid
language sql stable security definer set search_path = ''
as $$
  select l.id from public.fin_libros l
  join public.personas p on p.id = l.titular_id
  join auth.users u on u.id = p.usuario_id
  where u.email = p_correo and l.tipo = 'personal'
$$;

create function pruebas.cuenta_sistema(p_libro uuid, p_tipo text) returns uuid
language sql stable security definer set search_path = ''
as $$ select c.id from public.fin_cuentas c where c.libro_id = p_libro and c.tipo = p_tipo $$;

create function pruebas.registrar(
  p_tipo text, p_origen uuid, p_destino uuid, p_monto bigint,
  p_fecha date default '2026-10-21', p_motivo text default null, p_anula uuid default null,
  p_en_nombre_de uuid default null, p_id uuid default gen_random_uuid(),
  p_hogar uuid default 'b0000000-0000-4000-8000-000000000001', p_realizado_por uuid default null)
returns uuid
language sql
as $$
  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                      monto_centavos, motivo, anula_a, en_nombre_de, realizado_por)
  values (p_id, p_hogar, p_tipo, p_fecha, '2026-10-21 12:00:00-06', p_origen, p_destino, p_monto, p_motivo,
          p_anula, p_en_nombre_de, coalesce(p_realizado_por, public.persona_actual()))
  returning id
$$;

grant execute on all functions in schema pruebas to anon, authenticated, service_role;
