-- =============================================================================
-- GRAVITY · Fase 4 · Alimentación en el servidor (D23) y motivo con la regla de la app (F4-M1)
-- =============================================================================
-- docs/specs/fase-4-alimentacion.md (secciones 4 y 6), D23 y la revisión docs/revisiones/fase-4.md (F4-B1, F4-M1).
-- Dos menús por hogar: 'papa' (con su perfil clínico, dato D3) y 'pareja' (el del dueño y su pareja). Los permisos
-- NO salen de permisos_rol (no distingue menús ni el ajuste del 6/nov): los decide ali_puede(). Casa no ve nada; la
-- cuenta maestra que no es la dueña solo lee; el familiar edita el menú de Papá (nunca el de la pareja).
-- Sin precios ni dinero; sin bitácora (el perfil clínico de Papá no debe copiarse a una entrada que ven otros).
-- Convención 12: los grant repiten la lista completa. Migración nueva (hacia adelante). PostgreSQL 15 o superior.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. F4-M1: fin_motivo_valido igual que la app (motivoValido)
-- -----------------------------------------------------------------------------
-- Tres caracteres visibles, de ellos al menos dos que no sean puntuación o símbolos ('___', '...' y '---' no valen) y
-- no todos iguales ('aaa' no vale). La puntuación se define por lista (no por clase de letras) para no depender
-- de la configuración regional del servidor.
create or replace function fin_motivo_valido(p_motivo text)
returns boolean
language sql immutable parallel safe
set search_path = ''
as $$
  select char_length(q.s) >= 3
     and char_length(regexp_replace(q.s, '[!-/:-@\[-`{-~¡¿«»·‐-‧‰-⁞]', '', 'g')) >= 2
     and (select count(distinct c) from regexp_split_to_table(q.s, '') c) > 1
  from (select regexp_replace(coalesce(p_motivo, ''),
          '[[:space:][:cntrl:]\u0085 ­؜ᅟᅠ ᠎ -‏ -  -⁯⠀　ㅤ﻿ﾠ￹-￻]', '', 'g') as s) q
$$;
comment on function fin_motivo_valido(text) is
  'El motivo cuenta si tiene 3 caracteres visibles, al menos 2 que no son puntuación ni símbolos y no todos iguales '
  '(la misma regla que motivoValido en la app).';

-- -----------------------------------------------------------------------------
-- 2. ali_puede(hogar, menu, objeto, accion)
-- -----------------------------------------------------------------------------
-- objeto: platillos | menu | perfil | suplementos | compras. accion: leer | escribir. menu: 'papa' o 'pareja' (nulo en platillos).
create function public.ali_puede(p_hogar_id uuid, p_menu text, p_objeto text, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_rol  text := public.rol_en_hogar(p_hogar_id)::text;
  v_quien text;
begin
  if p_accion not in ('leer', 'escribir') or p_objeto not in ('platillos', 'menu', 'perfil', 'suplementos', 'compras')
     or (p_objeto <> 'platillos' and p_menu not in ('papa', 'pareja')) then
    return false;
  end if;
  -- La cuenta maestra (D19) que no es la dueña es solo lectura; Casa y cualquier otro rol, nada.
  v_quien := case
    when v_rol is null then null
    when v_rol in ('coadministrador') and public.es_cuenta_maestra(p_hogar_id) then 'maestra'
    when v_rol = 'dueno' then 'dueno'
    when v_rol = 'coadministrador' then 'pareja'
    when v_rol = 'familiar' then 'familiar'
    when v_rol = 'cuidador' then 'cuidador'
    else null end;
  if v_quien is null then
    return false;
  end if;
  if p_accion = 'leer' then
    return case
      when p_objeto = 'compras' and p_menu = 'papa' then v_quien in ('dueno', 'pareja', 'cuidador', 'maestra')
      when p_objeto = 'compras' then v_quien in ('dueno', 'pareja', 'maestra')
      when p_objeto = 'platillos' or p_menu = 'papa' then v_quien in ('dueno', 'pareja', 'familiar', 'cuidador', 'maestra')
      else v_quien in ('dueno', 'pareja', 'maestra') end;
  end if;
  return case
    when p_objeto = 'perfil' and p_menu = 'papa' then v_quien = 'dueno'
    when p_objeto = 'menu' and p_menu = 'papa' then v_quien in ('dueno', 'pareja', 'familiar')
    else v_quien in ('dueno', 'pareja') end;
end
$$;
comment on function public.ali_puede(uuid, text, text, text) is
  'D23: quién lee y escribe cada parte de Alimentación. Papá: dueño, pareja y familiar editan el menú; cuidadora y maestra solo lo ven; '
  'el perfil clínico lo edita solo el dueño; suplementos y platillos, dueño y pareja; "comprado", dueño y pareja; la lista de '
  'compras de Papá no la ve el familiar. Pareja: dueño y pareja (la maestra solo lee). Casa: nada.';

-- -----------------------------------------------------------------------------
-- 3. Tablas
-- -----------------------------------------------------------------------------
create table public.ali_platillos (
  id           uuid primary key default gen_random_uuid(),
  hogar_id     uuid not null references public.hogares (id),
  nombre       text not null check (char_length(btrim(nombre)) between 1 and 120),
  ingredientes jsonb not null default '[]'::jsonb check (jsonb_typeof(ingredientes) = 'array' and octet_length(ingredientes::text) <= 16384),
  duros        text[] not null default '{}' check (cardinality(duros) <= 30),
  creado_en    timestamptz not null default now(),
  constraint ali_platillos_hogar_id_key unique (hogar_id, id)
);
comment on table public.ali_platillos is
  'Catálogo de platillos del hogar. ingredientes: [{nombre, cantidad, unidad, seccion}]. Sin precios. duros: alimentos duros o crudos '
  '(advierten en el menú de Papá).';

create table public.ali_menus (
  hogar_id       uuid not null references public.hogares (id),
  menu           text not null check (menu in ('papa', 'pareja')),
  perfil         jsonb not null default '{}'::jsonb check (jsonb_typeof(perfil) = 'object' and octet_length(perfil::text) <= 8192),
  actualizado_por uuid references public.personas (id),
  actualizado_en timestamptz not null default now(),
  primary key (hogar_id, menu)
);
comment on table public.ali_menus is 'Un renglón por menú y hogar con su perfil. El perfil de Papá es DATO CLÍNICO (D3): no sale a la IA ni a las bocinas.';

create table public.ali_menu (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  menu           text not null check (menu in ('papa', 'pareja')),
  semana         date not null check (extract(isodow from semana) = 1),
  dia            smallint not null check (dia between 0 and 6),
  tiempo         text not null check (tiempo in ('desayuno', 'comida', 'cena', 'colacion')),
  platillo_id    uuid,
  actualizado_por uuid references public.personas (id),
  actualizado_en timestamptz not null default now(),
  constraint ali_menu_una_entrada unique (hogar_id, menu, semana, dia, tiempo),
  constraint ali_menu_platillo_fk foreign key (hogar_id, platillo_id) references public.ali_platillos (hogar_id, id)
);
create index ali_menu_semana_idx on public.ali_menu (hogar_id, menu, semana);

create table public.ali_suplementos (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  menu           text not null check (menu in ('papa', 'pareja')),
  nombre         text not null check (char_length(btrim(nombre)) between 1 and 80),
  dosis          text check (char_length(dosis) <= 80),
  horario        text check (char_length(horario) <= 80),
  actualizado_por uuid references public.personas (id),
  actualizado_en timestamptz not null default now()
);
comment on table public.ali_suplementos is 'Suplementos de cada menú (dosis sensible). Los de Papá son dato clínico (D3).';

create table public.ali_compras_marcas (
  hogar_id    uuid not null references public.hogares (id),
  menu        text not null check (menu in ('papa', 'pareja')),
  semana      date not null check (extract(isodow from semana) = 1),
  clave       text not null check (char_length(clave) between 1 and 200),
  marcado_por uuid references public.personas (id),
  marcado_en  timestamptz not null default now(),
  primary key (hogar_id, menu, semana, clave)
);
comment on table public.ali_compras_marcas is 'Fila presente = comprado. La lista de compras se deriva del menú; aquí solo el conjunto de marcados.';

-- -----------------------------------------------------------------------------
-- 4. Lo que pone el servidor y cuota de filas
-- -----------------------------------------------------------------------------
create function public.ali_propio()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'ali_compras_marcas' then
    new.marcado_por := coalesce(public.persona_actual(), new.marcado_por);
    new.marcado_en := now();
  elsif tg_table_name = 'ali_platillos' then
    if tg_op = 'UPDATE' then
      new.creado_en := old.creado_en;
    end if;
  else
    new.actualizado_por := coalesce(public.persona_actual(), new.actualizado_por);
    new.actualizado_en := now();
  end if;
  if tg_op = 'UPDATE' and to_jsonb(new) ? 'hogar_id' and new.hogar_id is distinct from old.hogar_id then
    raise exception using errcode = '42501', message = 'El hogar de un registro de Alimentación no cambia.';
  end if;
  return new;
end
$$;

create function public.ali_cuota_filas()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_hogar uuid;
  v_tope  integer := case tg_table_name when 'ali_platillos' then 2000 when 'ali_menu' then 20000
                       when 'ali_suplementos' then 200 when 'ali_compras_marcas' then 20000 end;
  v_n bigint;
begin
  for v_hogar in select distinct n.hogar_id from nuevas n loop
    execute format('select count(*) from public.%I where hogar_id = $1', tg_table_name) into v_n using v_hogar;
    if v_n > v_tope then
      raise exception using errcode = '54000',
        message = format('Se llegó al tope de %s filas en %s.', v_tope, tg_table_name), hint = 'Borra lo que ya no uses.';
    end if;
  end loop;
  return null;
end
$$;

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['ali_platillos', 'ali_menus', 'ali_menu', 'ali_suplementos', 'ali_compras_marcas'] loop
    execute format('alter table public.%I enable row level security', v_tabla);
    execute format('create trigger ali_a_propio before insert or update on public.%I
                      for each row execute function public.ali_propio()', v_tabla);
  end loop;
  foreach v_tabla in array array['ali_platillos', 'ali_menu', 'ali_suplementos', 'ali_compras_marcas'] loop
    execute format('create trigger ali_z_cuota after insert on public.%I referencing new table as nuevas
                      for each statement execute function public.ali_cuota_filas()', v_tabla);
  end loop;
end
$$;

-- -----------------------------------------------------------------------------
-- 5. Reglas por registro (RLS)
-- -----------------------------------------------------------------------------
create policy ali_platillos_leer on public.ali_platillos for select to authenticated
  using (public.ali_puede(hogar_id, null, 'platillos', 'leer'));
create policy ali_platillos_agregar on public.ali_platillos for insert to authenticated
  with check (public.ali_puede(hogar_id, null, 'platillos', 'escribir'));
create policy ali_platillos_editar on public.ali_platillos for update to authenticated
  using (public.ali_puede(hogar_id, null, 'platillos', 'escribir'))
  with check (public.ali_puede(hogar_id, null, 'platillos', 'escribir'));
create policy ali_platillos_borrar on public.ali_platillos for delete to authenticated
  using (public.ali_puede(hogar_id, null, 'platillos', 'escribir'));

create policy ali_menus_leer on public.ali_menus for select to authenticated
  using (public.ali_puede(hogar_id, menu, 'menu', 'leer'));
create policy ali_menus_agregar on public.ali_menus for insert to authenticated
  with check (public.ali_puede(hogar_id, menu, 'perfil', 'escribir'));
create policy ali_menus_editar on public.ali_menus for update to authenticated
  using (public.ali_puede(hogar_id, menu, 'perfil', 'escribir'))
  with check (public.ali_puede(hogar_id, menu, 'perfil', 'escribir'));

create policy ali_menu_leer on public.ali_menu for select to authenticated
  using (public.ali_puede(hogar_id, menu, 'menu', 'leer'));
create policy ali_menu_agregar on public.ali_menu for insert to authenticated
  with check (public.ali_puede(hogar_id, menu, 'menu', 'escribir'));
create policy ali_menu_editar on public.ali_menu for update to authenticated
  using (public.ali_puede(hogar_id, menu, 'menu', 'escribir'))
  with check (public.ali_puede(hogar_id, menu, 'menu', 'escribir'));
create policy ali_menu_borrar on public.ali_menu for delete to authenticated
  using (public.ali_puede(hogar_id, menu, 'menu', 'escribir'));

create policy ali_suplementos_leer on public.ali_suplementos for select to authenticated
  using (public.ali_puede(hogar_id, menu, 'suplementos', 'leer'));
create policy ali_suplementos_agregar on public.ali_suplementos for insert to authenticated
  with check (public.ali_puede(hogar_id, menu, 'suplementos', 'escribir'));
create policy ali_suplementos_editar on public.ali_suplementos for update to authenticated
  using (public.ali_puede(hogar_id, menu, 'suplementos', 'escribir'))
  with check (public.ali_puede(hogar_id, menu, 'suplementos', 'escribir'));
create policy ali_suplementos_borrar on public.ali_suplementos for delete to authenticated
  using (public.ali_puede(hogar_id, menu, 'suplementos', 'escribir'));

create policy ali_compras_marcas_leer on public.ali_compras_marcas for select to authenticated
  using (public.ali_puede(hogar_id, menu, 'compras', 'leer'));
create policy ali_compras_marcas_agregar on public.ali_compras_marcas for insert to authenticated
  with check (public.ali_puede(hogar_id, menu, 'compras', 'escribir'));
create policy ali_compras_marcas_borrar on public.ali_compras_marcas for delete to authenticated
  using (public.ali_puede(hogar_id, menu, 'compras', 'escribir'));

-- -----------------------------------------------------------------------------
-- 6. Privilegios (por columna; actualizado_por/en y marcado_por/en los pone el servidor)
-- -----------------------------------------------------------------------------
revoke all on table public.ali_platillos, public.ali_menus, public.ali_menu, public.ali_suplementos, public.ali_compras_marcas
  from public, anon, authenticated, service_role;
grant select, delete on public.ali_platillos, public.ali_menu, public.ali_suplementos, public.ali_compras_marcas to authenticated;
grant select on public.ali_menus to authenticated;
grant select on public.ali_platillos, public.ali_menus, public.ali_menu, public.ali_suplementos, public.ali_compras_marcas to service_role;
grant insert (id, hogar_id, nombre, ingredientes, duros), update (id, hogar_id, nombre, ingredientes, duros)
  on public.ali_platillos to authenticated;
grant insert (hogar_id, menu, perfil), update (hogar_id, menu, perfil) on public.ali_menus to authenticated;
grant insert (id, hogar_id, menu, semana, dia, tiempo, platillo_id), update (id, hogar_id, menu, semana, dia, tiempo, platillo_id)
  on public.ali_menu to authenticated;
grant insert (id, hogar_id, menu, nombre, dosis, horario), update (id, hogar_id, menu, nombre, dosis, horario)
  on public.ali_suplementos to authenticated;
grant insert (hogar_id, menu, semana, clave) on public.ali_compras_marcas to authenticated;

revoke execute on function public.ali_puede(uuid, text, text, text), public.ali_propio(), public.ali_cuota_filas()
  from public, anon, authenticated, service_role;
grant execute on function public.ali_puede(uuid, text, text, text) to authenticated, service_role;
