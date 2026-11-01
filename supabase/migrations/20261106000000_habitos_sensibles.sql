-- =============================================================================
-- GRAVITY · Fase 3 · Hábitos sensibles: sobres cifrados, llaves y modos (D13, D21 propuesta)
-- =============================================================================
-- docs/specs/fase-3-habitos.md (4.2, 4.3 y 4.5). El servidor SOLO guarda sobres cifrados (AES-256-GCM hecho en el
-- teléfono): nunca ve texto claro, ni la hora de cada registro (un sobre por día y tipo, con la hora del SERVIDOR),
-- ni la llave maestra (viaja envuelta con la frase de 12 palabras). Decisiones del dueño (commit 42f5251): nube apagada
-- por omisión (solo_telefono), frase de 12 palabras, la tablet PERSONAL funciona como el teléfono (puede registrar su
-- dispositivo y subir o leer sobres cifrados; la pública nunca recibe la llave) y lo de quien se da de baja se
-- conserva sin acceso y se borra a los 90 días (hab_limpiar).
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior. pg_cron solo si existe.
-- =============================================================================

create table public.hab_sobres (
  id             uuid primary key,
  hogar_id       uuid not null references public.hogares (id),
  persona_id     uuid not null references public.personas (id),
  tipo           text not null check (tipo in ('habitos_sensibles', 'diario_oracion')),
  revision       integer not null check (revision >= 1),
  cifrado        text not null check (char_length(cifrado) between 1 and 87400 and cifrado ~ '^[A-Za-z0-9_-]+$'),
  llave_version  integer not null check (llave_version >= 1),
  eliminado      boolean not null default false,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index hab_sobres_persona_idx on public.hab_sobres (persona_id, tipo, actualizado_en);
comment on table public.hab_sobres is
  'Documentos cifrados de Hábitos (un sobre por día y tipo). El id es opaco (HMAC en el teléfono). El servidor solo ve el '
  'tipo, la revisión, el tamaño y su propia hora. Solo se escribe con hab_subir_sobres.';

create table public.hab_llaves (
  persona_id     uuid primary key references public.personas (id),
  hogar_id       uuid not null references public.hogares (id),
  version        integer not null check (version >= 1),
  kdf            text not null check (kdf in ('pbkdf2-hmac-sha256', 'argon2id')),
  kdf_params     jsonb not null check (jsonb_typeof(kdf_params) = 'object' and octet_length(kdf_params::text) <= 1024),
  sal            text not null check (char_length(sal) between 8 and 128 and sal ~ '^[A-Za-z0-9_=+/-]+$'),
  llave_envuelta text not null check (char_length(llave_envuelta) between 16 and 512 and llave_envuelta ~ '^[A-Za-z0-9_=+/-]+$'),
  creado_en      timestamptz not null default now(),
  rotada_en      timestamptz
);
comment on table public.hab_llaves is
  'La llave maestra ENVUELTA con una llave derivada de la frase de recuperación. El servidor no puede abrirla.';

alter table public.hab_sobres enable row level security;
alter table public.hab_llaves enable row level security;
create policy hab_sobres_leer on public.hab_sobres for select to authenticated
  using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id)
         and exists (select 1 from public.hab_modos m where m.persona_id = hab_sobres.persona_id
                       and m.tipo = hab_sobres.tipo and m.modo = 'nube_cifrada'));
create policy hab_llaves_leer on public.hab_llaves for select to authenticated
  using (persona_id = (select public.persona_actual()) and public.hab_activa(hogar_id));

insert into public.avisos_sistema (clave, valor) values ('habitos_cuota_bytes', to_jsonb(26214400::bigint));

revoke all on table public.hab_sobres, public.hab_llaves from public, anon, authenticated, service_role;
grant select on public.hab_sobres, public.hab_llaves to authenticated;

-- ---------------------------------------------------------------- utilidades internas
create function public.hab_nota(p_accion text)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  -- Constancia SIN contenido: quién y cuándo, nada más.
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (public.hab_hogar_de(public.persona_actual()), public.persona_actual(), p_accion, null, null, '{}'::jsonb);
end
$$;

create function public.hab_exigir_activa()
returns uuid
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_hogar uuid := public.hab_hogar_de(public.persona_actual());
begin
  if public.persona_actual() is null or v_hogar is null then
    raise exception using errcode = '42501', message = 'Sin Hábitos en este hogar.';
  end if;
  return v_hogar;
end
$$;

-- ---------------------------------------------------------------- llaves
create function public.hab_guardar_llave(
  p_version integer, p_kdf text, p_kdf_params jsonb, p_sal text, p_llave_envuelta text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_hogar  uuid := public.hab_exigir_activa();
  v_actual public.hab_llaves%rowtype;
begin
  select * into v_actual from public.hab_llaves l where l.persona_id = public.persona_actual();
  if not found then
    if p_version is distinct from 1 then
      raise exception using errcode = '22023', message = 'La primera envoltura es la versión 1.';
    end if;
    insert into public.hab_llaves (persona_id, hogar_id, version, kdf, kdf_params, sal, llave_envuelta)
    values (public.persona_actual(), v_hogar, 1, p_kdf, p_kdf_params, p_sal, p_llave_envuelta);
    perform public.hab_nota('habitos.activar_cifrado');
  elsif p_version = v_actual.version
        and p_kdf = v_actual.kdf and p_kdf_params = v_actual.kdf_params and p_sal = v_actual.sal
        and p_llave_envuelta = v_actual.llave_envuelta then
    return;  -- reintento idéntico
  elsif p_version = v_actual.version + 1 then
    update public.hab_llaves set version = p_version, kdf = p_kdf, kdf_params = p_kdf_params, sal = p_sal,
                                 llave_envuelta = p_llave_envuelta, rotada_en = now()
     where persona_id = public.persona_actual();
  else
    raise exception using errcode = '22023', message = 'La versión de la envoltura sube de 1 en 1.';
  end if;
end
$$;
comment on function public.hab_guardar_llave(integer, text, jsonb, text, text) is
  'Crea (versión 1) o reemplaza (versión actual + 1) la llave maestra envuelta. Idempotente. Deja constancia sin contenido '
  'al crearla (habitos.activar_cifrado).';

-- ---------------------------------------------------------------- modos
create function public.hab_cambiar_modo(p_tipo text, p_modo text, p_confirmar_borrado boolean default false)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_actual text;
begin
  perform public.hab_exigir_activa();
  if p_modo not in ('solo_telefono', 'nube_cifrada') then
    raise exception using errcode = '22023', message = 'El modo es solo_telefono o nube_cifrada.';
  end if;
  select m.modo into v_actual from public.hab_modos m where m.persona_id = public.persona_actual() and m.tipo = p_tipo;
  if not found then
    raise exception using errcode = '22023', message = 'Tipo desconocido.';
  end if;
  if v_actual = p_modo then
    return;
  end if;
  if p_modo = 'nube_cifrada' then
    if not exists (select 1 from public.hab_llaves l where l.persona_id = public.persona_actual()) then
      raise exception using errcode = '55000', message = 'Antes de activar la nube hay que guardar la llave (la frase de recuperación).';
    end if;
  else
    if not coalesce(p_confirmar_borrado, false) then
      raise exception using errcode = '22023', message = 'Volver a solo teléfono borra lo de la nube: pide confirmación.';
    end if;
    delete from public.hab_sobres s where s.persona_id = public.persona_actual() and s.tipo = p_tipo;
    update public.hab_ajustes set epoca_nube = epoca_nube + 1 where persona_id = public.persona_actual();
  end if;
  update public.hab_modos set modo = p_modo, cambiado_en = now()
   where persona_id = public.persona_actual() and tipo = p_tipo;
  perform public.hab_nota('habitos.cambiar_modo');
end
$$;
comment on function public.hab_cambiar_modo(text, text, boolean) is
  'Pasar a nube_cifrada exige la llave guardada (55000); volver a solo_telefono borra físicamente los sobres de ese tipo, '
  'exige p_confirmar_borrado y sube epoca_nube.';

-- ---------------------------------------------------------------- sobres
create function public.hab_subir_sobres(p_sobres jsonb)
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
      v_conflictos := v_conflictos || jsonb_build_array(jsonb_build_object('id', v_id, 'revision', v_srv.revision));
    elsif v_rev = v_srv.revision + 1 then
      select coalesce(sum(octet_length(s.cifrado)), 0) into v_usado from public.hab_sobres s where s.persona_id = v_persona;
      if v_usado - octet_length(v_srv.cifrado) + octet_length(v_cif) > v_cuota then
        raise exception using errcode = '22023', message = 'Se llegó a la cuota de Hábitos en la nube.';
      end if;
      update public.hab_sobres set revision = v_rev, cifrado = v_cif, llave_version = v_llave, eliminado = v_elim,
                                   actualizado_en = now()
       where id = v_id;
      v_aceptados := v_aceptados + 1;
    else
      raise exception using errcode = '22023', message = 'La revisión de un sobre sube de 1 en 1.';
    end if;
  end loop;
  return jsonb_build_object('aceptados', v_aceptados, 'conflictos', v_conflictos);
end
$$;
comment on function public.hab_subir_sobres(jsonb) is
  'Hasta 50 sobres por llamada. Valida modo (nube_cifrada), revisión (nueva o +1; menor o igual = conflicto que se devuelve), '
  'tamaño (<= 64 KB) y cuota (25 MB, avisos_sistema.habitos_cuota_bytes). Idempotente. La hora que queda es la del servidor.';

-- ---------------------------------------------------------------- reiniciar y borrar
create function public.hab_reiniciar_nube(p_tipo text default 'todos')
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
begin
  perform public.hab_exigir_activa();
  if p_tipo not in ('habitos_sensibles', 'diario_oracion', 'todos') then
    raise exception using errcode = '22023', message = 'Tipo desconocido.';
  end if;
  delete from public.hab_sobres s where s.persona_id = v_persona and (p_tipo = 'todos' or s.tipo = p_tipo);
  update public.hab_modos set modo = 'solo_telefono', cambiado_en = now()
   where persona_id = v_persona and (p_tipo = 'todos' or tipo = p_tipo);
  -- La llave sirve a ambos tipos: solo se borra cuando ninguno queda en la nube.
  if not exists (select 1 from public.hab_modos m where m.persona_id = v_persona and m.modo = 'nube_cifrada') then
    delete from public.hab_llaves where persona_id = v_persona;
  end if;
  update public.hab_ajustes set epoca_nube = epoca_nube + 1 where persona_id = v_persona;
  perform public.hab_nota('habitos.reiniciar_nube');
end
$$;
comment on function public.hab_reiniciar_nube(text) is
  'Perdí la frase y ningún equipo tiene la llave: borra los sobres (y la llave si ya nada usa la nube) y vuelve a solo_telefono.';

create function public.hab_borrar_datos_de(p_persona_id uuid, p_alcance text)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if p_alcance in ('sensibles', 'todo') then
    delete from public.hab_sobres where persona_id = p_persona_id and tipo = 'habitos_sensibles';
  end if;
  if p_alcance in ('diario', 'todo') then
    delete from public.hab_sobres where persona_id = p_persona_id and tipo = 'diario_oracion';
  end if;
  if p_alcance = 'todo' then
    delete from public.hab_llaves where persona_id = p_persona_id;
    delete from public.hab_registros where persona_id = p_persona_id;
    delete from public.hab_lecturas where persona_id = p_persona_id;
    delete from public.hab_marcas_biblia where persona_id = p_persona_id;
    delete from public.hab_revisiones where persona_id = p_persona_id;
    delete from public.hab_pausas where persona_id = p_persona_id;
    delete from public.hab_plan_dias where persona_id = p_persona_id;
    delete from public.hab_planes_lectura where persona_id = p_persona_id;
    delete from public.hab_bloques where persona_id = p_persona_id;
    delete from public.hab_objetivos where persona_id = p_persona_id;
    update public.hab_modos set modo = 'solo_telefono', cambiado_en = now() where persona_id = p_persona_id;
  end if;
  update public.hab_ajustes set epoca_nube = epoca_nube + 1 where persona_id = p_persona_id;
end
$$;

create function public.hab_borrar_mis_datos(p_alcance text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  perform public.hab_exigir_activa();
  if p_alcance not in ('sensibles', 'diario', 'todo') then
    raise exception using errcode = '22023', message = 'El alcance es sensibles, diario o todo.';
  end if;
  perform public.hab_borrar_datos_de(public.persona_actual(), p_alcance);
  perform public.hab_nota('habitos.borrar_datos');
end
$$;
comment on function public.hab_borrar_mis_datos(text) is
  'Borrado físico de lo propio: sensibles, diario o todo (con todo también la llave y las tablas en claro; deja hab_ajustes). '
  'Deja una constancia sin contenido. No es un libro contable: se puede borrar.';

-- ---------------------------------------------------------------- limpieza
-- Tumbas de sobres de más de 30 días y datos de quien se dio de baja hace más de 90 días (sin ninguna membresía vigente).
create function public.hab_limpiar(p_ahora timestamptz default now())
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
    select distinct x.persona_id from (
      select persona_id from public.hab_ajustes union select persona_id from public.hab_sobres union select persona_id from public.hab_llaves
    ) x
    where not exists (select 1 from public.membresias m where m.persona_id = x.persona_id and m.activa
                        and m.desde <= p_ahora and (m.hasta is null or m.hasta > p_ahora))
      and not exists (select 1 from public.membresias m where m.persona_id = x.persona_id
                        and (m.activa or m.hasta is null or m.hasta > p_ahora - interval '90 days'))
  loop
    perform public.hab_borrar_datos_de(v_persona, 'todo');
    delete from public.hab_modos where persona_id = v_persona;
    delete from public.hab_ajustes where persona_id = v_persona;
    v_n := v_n + 1;
  end loop;
  return v_tumbas + v_n;
end
$$;
comment on function public.hab_limpiar(timestamptz) is
  'Nocturna. Borra tumbas de sobres de más de 30 días y todo lo de Hábitos de quien lleva más de 90 días dado de baja '
  '(hasta entonces se conserva sin acceso). Devuelve tumbas + personas limpiadas.';

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('hab-limpieza', '45 9 * * *', 'select public.hab_limpiar()');
  end if;
end
$$;

revoke execute on function
  public.hab_nota(text), public.hab_exigir_activa(), public.hab_guardar_llave(integer, text, jsonb, text, text),
  public.hab_cambiar_modo(text, text, boolean), public.hab_subir_sobres(jsonb), public.hab_reiniciar_nube(text),
  public.hab_borrar_datos_de(uuid, text), public.hab_borrar_mis_datos(text), public.hab_limpiar(timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function
  public.hab_guardar_llave(integer, text, jsonb, text, text), public.hab_cambiar_modo(text, text, boolean),
  public.hab_subir_sobres(jsonb), public.hab_reiniciar_nube(text), public.hab_borrar_mis_datos(text)
  to authenticated;
