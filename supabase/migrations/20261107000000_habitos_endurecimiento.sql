-- =============================================================================
-- GRAVITY · Fase 3 · Hábitos: endurecimiento (revisión de calidad docs/revisiones/fase-3.md)
-- =============================================================================
-- Criterios por defecto, PROVISIONALES (se anotan en supabase/README.md):
--   F3-2  hab_subir_sobres acepta una revisión MAYOR que la del servidor (no exige +1); igual o menor es un
--         conflicto que se devuelve sin abortar el lote. Además se acepta el KDF 'pbkdf2-sha256' como alias.
--   F3-4  Las constancias habitos* (hab_nota) son una por acción, persona y minuto: no se llena la bitácora.
--   F3-5  membresias.desactivada_en (la pone un trigger) y hab_limpiar borra a los 90 días desde esa fecha.
--   F3-9  hab_hogar_de(persona) solo contesta por la propia sesión.
--   F3-10 Cuota de filas por persona en las tablas en claro (54000).
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior.
-- =============================================================================

-- F3-2
create or replace function public.hab_subir_sobres(p_sobres jsonb)
returns jsonb
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_hogar    uuid := public.hab_exigir_activa();
  v_persona  uuid := public.persona_actual();
  v_s        jsonb;
  v_id       uuid;
  v_tipo     text;
  v_rev      integer;
  v_cif      text;
  v_llave    integer;
  v_elim     boolean;
  v_srv      public.hab_sobres%rowtype;
  v_aceptados integer := 0;
  v_conflictos jsonb := '[]'::jsonb;
  v_cuota    bigint;
  v_usado    bigint;
begin
  if jsonb_typeof(p_sobres) <> 'array' or jsonb_array_length(p_sobres) > 50 then
    raise exception using errcode = '22023', message = 'Hasta 50 sobres por llamada.';
  end if;
  select coalesce((valor #>> '{}')::bigint, 26214400) into v_cuota from public.avisos_sistema where clave = 'habitos_cuota_bytes';
  for v_s in select * from jsonb_array_elements(p_sobres) loop
    v_id := (v_s ->> 'id')::uuid;
    v_tipo := v_s ->> 'tipo';
    v_rev := (v_s ->> 'revision')::integer;
    v_cif := v_s ->> 'cifrado';
    v_llave := (v_s ->> 'llave_version')::integer;
    v_elim := coalesce((v_s ->> 'eliminado')::boolean, false);
    if v_id is null or v_tipo is null or v_rev is null or v_cif is null or v_llave is null then
      raise exception using errcode = '22023', message = 'Cada sobre lleva id, tipo, revision, cifrado y llave_version.';
    end if;
    if not exists (select 1 from public.hab_modos m where m.persona_id = v_persona and m.tipo = v_tipo and m.modo = 'nube_cifrada') then
      raise exception using errcode = '22023', message = 'Ese tipo no está en modo nube cifrada: el servidor no recibe sobres.';
    end if;
    select * into v_srv from public.hab_sobres s where s.id = v_id;
    if found and v_srv.persona_id <> v_persona then
      raise exception using errcode = '42501', message = 'Ese sobre no es tuyo.';
    end if;
    if not found then
      select coalesce(sum(octet_length(s.cifrado)), 0) into v_usado from public.hab_sobres s where s.persona_id = v_persona;
      if v_usado + octet_length(v_cif) > v_cuota then
        raise exception using errcode = '22023', message = 'Se llegó a la cuota de Hábitos en la nube.';
      end if;
      insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version, eliminado)
      values (v_id, v_hogar, v_persona, v_tipo, v_rev, v_cif, v_llave, v_elim);
      v_aceptados := v_aceptados + 1;
    elsif v_srv.tipo <> v_tipo then
      raise exception using errcode = '22023', message = 'El tipo de un sobre no cambia.';
    elsif v_rev = v_srv.revision and v_cif = v_srv.cifrado and v_llave = v_srv.llave_version and v_elim = v_srv.eliminado then
      null;  -- reintento idéntico: no hace nada
    elsif v_rev <= v_srv.revision then
      -- Conflicto: no aborta el lote; se devuelve la revisión del servidor (el cliente descarga, fusiona y sube una mayor).
      v_conflictos := v_conflictos || jsonb_build_array(jsonb_build_object('id', v_id, 'revision', v_srv.revision));
    else
      -- F3-2: cualquier revisión MAYOR que la del servidor entra (la cola puede saltar revisiones intermedias).
      select coalesce(sum(octet_length(s.cifrado)), 0) into v_usado from public.hab_sobres s where s.persona_id = v_persona;
      if v_usado - octet_length(v_srv.cifrado) + octet_length(v_cif) > v_cuota then
        raise exception using errcode = '22023', message = 'Se llegó a la cuota de Hábitos en la nube.';
      end if;
      update public.hab_sobres set revision = v_rev, cifrado = v_cif, llave_version = v_llave, eliminado = v_elim,
                                   actualizado_en = now()
       where id = v_id;
      v_aceptados := v_aceptados + 1;
    end if;
  end loop;
  return jsonb_build_object('aceptados', v_aceptados, 'conflictos', v_conflictos);
end
$$;

alter table public.hab_llaves drop constraint hab_llaves_kdf_check;
alter table public.hab_llaves add constraint hab_llaves_kdf_check
  check (kdf in ('pbkdf2-hmac-sha256', 'pbkdf2-sha256', 'argon2id'));

-- F3-4
create or replace function public.hab_nota(p_accion text)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  -- Constancia SIN contenido: quién y cuándo, nada más. F3-4: una por acción, persona y minuto (no se puede llenar la bitácora).
  if exists (select 1 from public.bitacora b where b.accion = p_accion and b.persona_id = public.persona_actual()
              and b.registrado_en > now() - interval '1 minute') then
    return;
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (public.hab_hogar_de(public.persona_actual()), public.persona_actual(), p_accion, null, null, '{}'::jsonb);
end
$$;

-- F3-9
create or replace function public.hab_hogar_de(p_persona_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select m.hogar_id from public.membresias m
   where m.persona_id = p_persona_id
     and (public.persona_actual() is null or p_persona_id = public.persona_actual())
     and public.hab_miembro_activo(m.hogar_id, p_persona_id)
   order by m.desde desc, m.id limit 1
$$;

-- F3-5
alter table public.membresias add column desactivada_en timestamptz;
comment on column public.membresias.desactivada_en is
  'Cuándo se dio de baja (la pone un trigger al pasar activa a falso o al fijar hasta). Base de los 90 días de Hábitos.';
update public.membresias set desactivada_en = case when not activa then coalesce(hasta, now()) else hasta end
 where not activa or hasta is not null;

create function public.membresias_desactivada_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.desactivada_en := case when not new.activa then now() else new.hasta end;
  elsif new.activa and new.hasta is null then
    new.desactivada_en := null;                                   -- volvió al hogar
  elsif (old.activa and not new.activa) then
    new.desactivada_en := now();
  elsif new.hasta is not null and new.hasta is distinct from old.hasta then
    new.desactivada_en := new.hasta;
  else
    new.desactivada_en := old.desactivada_en;
  end if;
  return new;
end
$$;
create trigger membresias_a_desactivada before insert or update on public.membresias
  for each row execute function public.membresias_desactivada_en();

create or replace function public.hab_limpiar(p_ahora timestamptz default now())
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid;
  v_n integer := 0;
  v_tumbas integer;
begin
  delete from public.hab_sobres s where s.eliminado and s.actualizado_en < p_ahora - interval '30 days';
  get diagnostics v_tumbas = row_count;
  for v_persona in
    select x.persona_id from (
      select persona_id from public.hab_ajustes union select persona_id from public.hab_sobres union select persona_id from public.hab_llaves
    ) x
    where not exists (select 1 from public.membresias m where m.persona_id = x.persona_id and m.activa
                        and m.desde <= p_ahora and (m.hasta is null or m.hasta > p_ahora))
      -- F3-5: 90 días desde la fecha de baja (desactivada_en) en todos los casos; sin membresía alguna cuenta desde hoy.
      and coalesce((select max(coalesce(m.desactivada_en, m.hasta, m.desde)) from public.membresias m where m.persona_id = x.persona_id),
                   '-infinity'::timestamptz) < p_ahora - interval '90 days'
  loop
    perform public.hab_borrar_datos_de(v_persona, 'todo');
    delete from public.hab_modos where persona_id = v_persona;
    delete from public.hab_ajustes where persona_id = v_persona;
    v_n := v_n + 1;
  end loop;
  return v_tumbas + v_n;
end
$$;

-- F3-10
create index hab_pausas_persona_idx on public.hab_pausas (persona_id);
create index hab_plan_dias_persona_idx on public.hab_plan_dias (persona_id);
create index hab_lecturas_persona_idx on public.hab_lecturas (persona_id);
create index hab_marcas_persona_idx on public.hab_marcas_biblia (persona_id);

create function public.hab_cuota_filas()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid;
  v_tope    integer := case tg_table_name
    when 'hab_objetivos' then 2000 when 'hab_bloques' then 5000 when 'hab_registros' then 20000
    when 'hab_pausas' then 500 when 'hab_planes_lectura' then 100 when 'hab_plan_dias' then 40000
    when 'hab_lecturas' then 20000 when 'hab_marcas_biblia' then 20000 when 'hab_revisiones' then 600 end;
  v_n       bigint;
begin
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
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['hab_objetivos', 'hab_bloques', 'hab_registros', 'hab_pausas', 'hab_planes_lectura',
                                 'hab_plan_dias', 'hab_lecturas', 'hab_marcas_biblia', 'hab_revisiones']
  loop
    execute format('create trigger hab_z_cuota after insert on public.%I referencing new table as nuevas
                      for each statement execute function public.hab_cuota_filas()', v_tabla);
  end loop;
end
$$;

revoke execute on function public.hab_subir_sobres(jsonb), public.hab_nota(text), public.hab_limpiar(timestamptz),
  public.membresias_desactivada_en(), public.hab_cuota_filas()
  from public, anon, authenticated, service_role;
grant execute on function public.hab_subir_sobres(jsonb) to authenticated;
