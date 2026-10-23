-- =============================================================================
-- GRAVITY · Fase 1 · Respuestas del dueño del 23/oct/2026 (D14, D18, D19)
-- =============================================================================
-- docs/DECISIONES.md (D19, "Respuestas del dueño del 23/oct/2026") y
-- docs/specs/fase-1-finanzas.md, sección 9.0 bis.
--
--   1. Cuenta maestra con login propio: es OTRA persona (rol coadministrador +
--      es_maestra) que crea el dueño con una invitación; no lleva libro propio y,
--      si no es la dueña, es SOLO LECTURA TOTAL en Finanzas: fin_puede() de
--      escribir y administrar es falso para ella en cualquier libro, y
--      fin_puede_hogar() también. Sigue necesitando la consulta registrada
--      (30 minutos) para leer libros ajenos. El dueño puede ser además la
--      maestra con su propia persona (en lo suyo sigue escribiendo).
--   2. Libros compartidos: quien lo crea es el administrador (agrega y saca
--      miembros, cambia la visibilidad y lo archiva); `visibilidad` privada (por
--      omisión) o pública (además LEEN, no escriben, los adultos con Finanzas del
--      hogar); cualquier miembro puede salirse; si al salir quedan menos de 2
--      miembros vigentes el libro se archiva (activo = false, solo lectura);
--      si se sale el creador, creado_por pasa al miembro vigente más antiguo.
--   3. Cuentas: el saldo cero para cerrar o archivar aplica solo a activos y
--      pasivos (las de gasto e ingreso son de periodo); archivar una categoría
--      archiva su cuenta de gasto.
--
-- Criterios provisionales (se anotan para D17/D19): ver supabase/README.md.
-- Migración nueva (hacia adelante): las anteriores no se tocan.
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Columnas nuevas
-- -----------------------------------------------------------------------------
alter table public.invitaciones
  add column es_maestra boolean not null default false,
  add constraint invitaciones_maestra_coadministrador check (not es_maestra or rol = 'coadministrador');
comment on column public.invitaciones.es_maestra is
  'Invitación a la cuenta maestra (D19, 23/oct): al aceptarla, la membresía nace coadministrador con es_maestra.';

alter table public.fin_libros
  add column visibilidad text not null default 'privada'
    check (visibilidad in ('privada', 'publica')),
  add constraint fin_libros_visibilidad_compartido check (tipo = 'compartido' or visibilidad = 'privada');
comment on column public.fin_libros.visibilidad is
  'Solo en libros compartidos. privada (por omisión): leen y escriben sus miembros; la cuenta maestra lee con '
  'consulta. publica: además LEEN (no escriben) los adultos con Finanzas del hogar. La cambia solo quien lo creó.';

-- Los permisos por columna se suman; se repite la lista completa (y no solo la columna
-- nueva) para que quien lea las migraciones con un grant por tabla (las pruebas de la app
-- toman el último "grant insert" de cada tabla) vea todas las columnas que la app puede mandar.
grant insert (id, hogar_id, nombre, tipo, titular_id, activo, visibilidad),
      update (id, hogar_id, nombre, tipo, titular_id, activo, visibilidad)
  on public.fin_libros to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Cuenta maestra: solo lectura total si no es la dueña
-- -----------------------------------------------------------------------------
create function public.fin_solo_lectura(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.es_cuenta_maestra(p_hogar_id) and public.rol_en_hogar(p_hogar_id) <> 'dueno', false)
$$;
comment on function public.fin_solo_lectura(uuid) is
  'La sesión es la cuenta maestra y no es la dueña: en Finanzas solo lee (D19, 23/oct).';

create or replace function public.fin_puede_hogar(p_hogar_id uuid, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_rol_con_finanzas boolean;
begin
  perform p_accion::public.accion_permiso;
  if p_accion is null then
    raise exception using errcode = '22023', message = 'La acción es obligatoria';
  end if;
  v_rol_con_finanzas := coalesce(public.alcance(p_hogar_id, 'finanzas', p_accion), '') in ('propio', 'total');
  if p_accion = 'leer' then
    return v_rol_con_finanzas or public.es_cuenta_maestra(p_hogar_id);
  end if;
  -- La maestra que no es la dueña no escribe ni administra nada, tampoco lo del hogar.
  return v_rol_con_finanzas and not public.fin_solo_lectura(p_hogar_id);
end
$$;
comment on function public.fin_puede_hogar(uuid, text) is
  'Para lo de Finanzas que es del HOGAR (categorías, cuentas de gasto, días inhábiles, importaciones): el rol '
  'tiene Finanzas (propio o total) para esa acción; la cuenta maestra además lee, pero si no es la dueña es '
  'solo lectura total (M6, D19 del 23/oct).';

-- fin_puede(): maestra de solo lectura; libro compartido público; archivado.
create or replace function public.fin_puede(p_libro_id uuid, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_libro   public.fin_libros%rowtype;
  v_papel   text;
  v_albacea boolean;
begin
  perform p_accion::public.accion_permiso;
  if p_accion is null then
    raise exception using errcode = '22023', message = 'La acción es obligatoria';
  end if;
  if p_libro_id is null or v_persona is null then
    return false;
  end if;
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found then
    return false;
  end if;

  -- La cuenta maestra que no es la dueña es solo lectura total, en cualquier libro.
  if p_accion <> 'leer' and public.fin_solo_lectura(v_libro.hogar_id) then
    return false;
  end if;

  -- El rol vigente debe tener Finanzas para esa acción (propio en D19).
  if coalesce(public.alcance(v_libro.hogar_id, 'finanzas', p_accion), '') in ('propio', 'total') then
    select m.papel into v_papel
    from public.fin_libro_miembros m
    where m.libro_id = p_libro_id and m.persona_id = v_persona
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
    order by case m.papel when 'titular' then 1 when 'albacea' then 2 when 'miembro' then 3 else 4 end
    limit 1;
  end if;

  if v_papel is null then
    if p_accion <> 'leer' then
      return false;
    end if;
    -- La cuenta maestra lee lo ajeno solo con una consulta registrada por ella
    -- en ese libro en los últimos 30 minutos (I2), también si es pública.
    if public.es_cuenta_maestra(v_libro.hogar_id) then
      return exists (
        select 1
        from public.bitacora b
        where b.accion = 'finanzas.consulta_maestra'
          and b.persona_id = v_persona
          and b.registro_id = p_libro_id::text
          and b.registrado_en > now() - public.fin_vigencia_consulta_maestra());
    end if;
    -- Un libro compartido PÚBLICO lo leen (no lo escriben) los adultos con Finanzas del hogar.
    return v_libro.tipo = 'compartido' and v_libro.visibilidad = 'publica'
       and coalesce(public.alcance(v_libro.hogar_id, 'finanzas', 'leer'), '') in ('propio', 'total');
  end if;
  if p_accion = 'leer' then
    return true;
  end if;

  -- Albacea vigente (I4): su cargo está abierto Y sigue siendo un adulto con
  -- Finanzas en el hogar. Si no, el suplente ocupa su lugar.
  v_albacea := exists (
    select 1 from public.fin_libro_miembros a
    where a.libro_id = p_libro_id and a.papel = 'albacea'
      and a.desde <= now() and (a.hasta is null or a.hasta > now())
      and public.fin_adulto_con_finanzas(v_libro.hogar_id, a.persona_id));

  if p_accion = 'escribir' then
    if not v_libro.activo then
      return false;  -- archivado: solo lectura
    end if;
    -- El suplente escribe solo si no hay albacea vigente.
    return v_papel in ('titular', 'miembro', 'albacea')
        or (v_papel = 'albacea_suplente' and not v_albacea);
  end if;

  -- administrar. Un compartido archivado solo lo administra su creador (para reactivarlo).
  if v_libro.tipo = 'compartido' and not v_libro.activo then
    return v_libro.creado_por = v_persona and v_papel = 'miembro';
  end if;
  return (v_libro.tipo = 'personal' and v_papel = 'titular')
      or (v_libro.tipo = 'compartido' and v_papel = 'miembro')
      or (v_libro.tipo = 'representado'
          and (v_papel = 'albacea' or (v_papel = 'albacea_suplente' and not v_albacea)));
end
$$;
comment on function public.fin_puede(uuid, text) is
  'D19. leer: miembro vigente; la cuenta maestra con una consulta registrada en ese libro en los últimos 30 '
  'minutos (I2); y, en un compartido PÚBLICO, todo adulto con Finanzas del hogar. escribir: titular, miembro o '
  'albacea (el suplente solo sin albacea vigente), con el libro activo (archivado = solo lectura). administrar: '
  'titular de un personal, miembro de un compartido (archivado: solo su creador), albacea de un representado. '
  'La cuenta maestra que no es la dueña nunca escribe ni administra. Siempre exige un rol con Finanzas.';

-- La maestra no es miembro de ningún libro (es solo lectura): no se agrega a uno.
create function public.fin_libro_miembros_sin_maestra()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.membresias m
             where m.hogar_id = new.hogar_id and m.persona_id = new.persona_id
               and m.es_maestra and m.rol <> 'dueno') then
    raise exception using errcode = '22023',
      message = 'La cuenta maestra es solo lectura: no lleva libros.';
  end if;
  return new;
end
$$;
create trigger fin_c_sin_maestra before insert on public.fin_libro_miembros
  for each row execute function public.fin_libro_miembros_sin_maestra();

-- Crear un libro no es para la maestra de solo lectura.
drop policy fin_libros_agregar on public.fin_libros;
create policy fin_libros_agregar on public.fin_libros for insert to authenticated
  with check (creado_por = (select public.persona_actual())
              and coalesce(public.alcance(hogar_id, 'finanzas', 'administrar'), '') in ('propio', 'total')
              and not public.fin_solo_lectura(hogar_id)
              and ((tipo = 'personal' and titular_id = (select public.persona_actual()))
                   or tipo = 'compartido'));

-- Libro personal automático: la maestra de solo lectura no lleva uno.
create or replace function public.fin_libro_personal_por_membresia()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.activa
     and not (new.es_maestra and new.rol <> 'dueno')
     and exists (select 1 from public.permisos_rol pr
                 where pr.rol = new.rol and pr.modulo = 'finanzas' and pr.accion = 'administrar'
                   and pr.alcance in ('propio', 'total'))
     and not exists (select 1 from public.fin_libros l
                     where l.hogar_id = new.hogar_id and l.titular_id = new.persona_id and l.tipo = 'personal') then
    insert into public.fin_libros (hogar_id, nombre, tipo, titular_id, creado_por)
    select new.hogar_id, left('Finanzas de ' || p.nombre_visible, 80), 'personal', new.persona_id, new.persona_id
    from public.personas p where p.id = new.persona_id;
  end if;
  return null;
end
$$;

-- -----------------------------------------------------------------------------
-- 3. Invitar a la cuenta maestra (otra persona, con su propio login)
-- -----------------------------------------------------------------------------
-- Se amplía crear_invitacion con p_es_maestra (por omisión falso: las llamadas
-- de 4 parámetros siguen funcionando).
drop function public.crear_invitacion(uuid, text, text, integer);
create function public.crear_invitacion(
  p_hogar_id uuid,
  p_correo text,
  p_rol text,
  p_vigencia_dias integer default 7,
  p_es_maestra boolean default false)
returns table (invitacion_id uuid, token text, expira timestamptz)
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_correo  text := lower(btrim(p_correo));
  v_maestra boolean := coalesce(p_es_maestra, false);
  v_token   text;
  v_id      uuid;
  v_expira  timestamptz;
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
  if v_maestra then
    if p_rol <> 'coadministrador' then
      raise exception using errcode = '22023', message = 'La cuenta maestra se invita con el rol coadministrador.';
    end if;
    -- D19 (23/oct): la maestra es OTRA persona con su propio login.
    if exists (select 1
               from auth.users u
               join public.personas p on p.usuario_id = u.id
               join public.membresias m on m.persona_id = p.id
               where lower(u.email) = v_correo and m.hogar_id = p_hogar_id and m.activa
                 and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
      raise exception using errcode = '22023',
        message = 'Ese correo ya es de un miembro del hogar: la cuenta maestra necesita otra cuenta, con otro correo.';
    end if;
  end if;

  -- Una sola invitación pendiente por correo y hogar: las anteriores se revocan.
  update public.invitaciones i
     set revocada_en = now()
   where i.hogar_id = p_hogar_id and i.correo = v_correo
     and i.aceptada_en is null and i.revocada_en is null;

  -- 244 bits aleatorios (dos UUID v4 de pg_strong_random), en hexadecimal.
  v_token  := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  v_expira := now() + make_interval(days => p_vigencia_dias);

  insert into public.invitaciones (hogar_id, correo, rol, es_maestra, token_hash, expira_en, creada_por)
  values (p_hogar_id, v_correo, p_rol, v_maestra,
          encode(sha256(convert_to(v_token, 'UTF8')), 'hex'), v_expira, public.persona_actual())
  returning id into v_id;

  return query select v_id, v_token, v_expira;
end
$$;
comment on function public.crear_invitacion(uuid, text, text, integer, boolean) is
  'Solo dueño. Devuelve el token UNA vez (se guarda solo su hash). Rol: coadministrador, familiar, cuidador o casa. '
  'Con p_es_maestra = true (solo rol coadministrador, y un correo que no sea de un miembro del hogar) al aceptarla '
  'la persona queda coadministrador con la marca de cuenta maestra y SIN libro personal (D19, 23/oct).';
revoke execute on function public.crear_invitacion(uuid, text, text, integer, boolean)
  from public, anon, authenticated, service_role;
grant execute on function public.crear_invitacion(uuid, text, text, integer, boolean) to authenticated;

create or replace function public.aceptar_invitacion(p_token text)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona    uuid := public.persona_actual();
  v_correo     text;
  v_confirmado timestamptz;
  v_inv        public.invitaciones%rowtype;
  v_anterior   uuid;
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

  -- Cuenta maestra: una por hogar; la anterior deja de serlo (queda anotado).
  if v_inv.es_maestra then
    select m.persona_id into v_anterior
    from public.membresias m
    where m.hogar_id = v_inv.hogar_id and m.es_maestra and m.activa
    limit 1;
    update public.membresias m
       set es_maestra = false
     where m.hogar_id = v_inv.hogar_id and m.es_maestra;
  end if;

  insert into public.membresias (hogar_id, persona_id, rol, es_maestra)
  values (v_inv.hogar_id, v_persona, v_inv.rol, v_inv.es_maestra);

  update public.invitaciones
     set aceptada_en = now(), aceptada_por = v_persona
   where id = v_inv.id;

  if v_inv.es_maestra then
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (v_inv.hogar_id, v_persona, 'finanzas.maestra_asignada', 'membresias', v_persona::text,
            jsonb_build_object('anterior_persona_id', v_anterior, 'nueva_persona_id', v_persona,
                               'invitada_por', v_inv.creada_por));
  end if;

  return v_inv.hogar_id;
end
$$;
comment on function public.aceptar_invitacion(text) is
  'La acepta la persona cuyo correo CONFIRMADO coincide; crea su membresía con el rol invitado (y, en una invitación '
  'de cuenta maestra, con la marca es_maestra, sin libro personal). Devuelve el hogar.';

-- Nombrar a mano la cuenta maestra: el dueño (con su propia persona) o una cuenta que no lleva libro propio.
create or replace function public.asignar_cuenta_maestra(p_hogar_id uuid, p_persona_id uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_anterior uuid;
  v_rol      text;
begin
  if not public.puede(p_hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501', message = 'Solo el dueño del hogar asigna la cuenta maestra.';
  end if;
  if p_persona_id is not null then
    select m.rol::text into v_rol
    from public.membresias m
    where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
      and m.rol in ('dueno', 'coadministrador');
    if v_rol is null then
      raise exception using errcode = '22023',
        message = 'La cuenta maestra debe ser un miembro vigente con Finanzas (dueño o coadministrador).';
    end if;
    -- Es solo lectura: no puede ser alguien que lleva su propio libro (salvo la dueña).
    if v_rol <> 'dueno' and exists (
        select 1 from public.fin_libros l
        where l.hogar_id = p_hogar_id and l.titular_id = p_persona_id and l.tipo = 'personal') then
      raise exception using errcode = '22023',
        message = 'La cuenta maestra es solo lectura: no puede llevar un libro propio. '
                  'Invita a otra persona como cuenta maestra, o nómbrate tú.';
    end if;
  end if;
  select m.persona_id into v_anterior
  from public.membresias m
  where m.hogar_id = p_hogar_id and m.es_maestra and m.activa
  limit 1;

  update public.membresias m
     set es_maestra = false
   where m.hogar_id = p_hogar_id and m.es_maestra
     and (p_persona_id is null or m.persona_id <> p_persona_id or not m.activa);
  if p_persona_id is not null then
    update public.membresias m
       set es_maestra = true
     where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa and not m.es_maestra;
  end if;

  if v_anterior is distinct from p_persona_id then
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (p_hogar_id, public.persona_actual(), 'finanzas.maestra_asignada', 'membresias',
            coalesce(p_persona_id, v_anterior)::text,
            jsonb_build_object('anterior_persona_id', v_anterior, 'nueva_persona_id', p_persona_id));
  end if;
end
$$;
comment on function public.asignar_cuenta_maestra(uuid, uuid) is
  'Solo el dueño. Nombra la cuenta maestra del hogar o la quita con nulo. Puede ser el propio dueño (con su '
  'persona) o un coadministrador vigente que no lleve libro propio (una cuenta creada con una invitación de cuenta '
  'maestra). Queda en la bitácora de membresías y en finanzas.maestra_asignada, que ve todo adulto con Finanzas.';

-- -----------------------------------------------------------------------------
-- 4. Libros compartidos: administrador, visibilidad, salida y archivo
-- -----------------------------------------------------------------------------
-- creado_por (el administrador) lo cambia solo el servidor: al salirse el creador.
drop trigger fin_a_columnas_fijas on public.fin_libros;
create trigger fin_a_columnas_fijas before update on public.fin_libros
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'tipo', 'titular_id', 'creado_en');

create function public.fin_libros_proteger()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Solo desde la API (rol authenticated): las funciones del servidor (como la
  -- salida de un miembro) pueden archivar o pasar el cargo de administrador.
  if current_user = 'authenticated' then
    if new.creado_por is distinct from old.creado_por then
      raise exception using errcode = '42501', message = 'El administrador de un libro lo cambia solo el servidor.';
    end if;
    if new.tipo = 'compartido' and old.creado_por is distinct from public.persona_actual()
       and (new.visibilidad is distinct from old.visibilidad or new.activo is distinct from old.activo) then
      raise exception using errcode = '42501',
        message = 'Solo quien creó un libro compartido cambia su visibilidad o lo archiva.';
    end if;
  end if;
  return new;
end
$$;
create trigger fin_c_proteger before update on public.fin_libros
  for each row execute function public.fin_libros_proteger();

-- ¿Puede la sesión salirse de este libro? (miembro vigente de un compartido; siempre, también archivado.)
create function public.fin_puede_salir(p_libro_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.fin_libros l
    join public.fin_libro_miembros m on m.libro_id = l.id
    where l.id = p_libro_id and l.tipo = 'compartido'
      and m.persona_id = public.persona_actual()
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
      and public.rol_en_hogar(l.hogar_id) is not null)
$$;
comment on function public.fin_puede_salir(uuid) is
  'La sesión es miembro vigente de este libro compartido: puede cerrar su propia membresía (salirse), siempre.';

drop policy fin_libro_miembros_editar on public.fin_libro_miembros;
create policy fin_libro_miembros_editar on public.fin_libro_miembros for update to authenticated
  using (public.fin_puede(libro_id, 'administrar')
         or (persona_id = (select public.persona_actual()) and public.fin_puede_salir(libro_id)))
  with check (public.fin_puede(libro_id, 'administrar')
              or (persona_id = (select public.persona_actual()) and public.fin_puede_salir(libro_id)));

-- Membresías de un compartido (reemplaza la de las salvaguardas):
--  * agregar o cambiar a OTRA persona: solo quien creó el libro o el dueño del hogar;
--  * salirse uno mismo: siempre; si quedan menos de 2 miembros vigentes el libro
--    se archiva (activo = false) y, si se sale el creador, creado_por pasa al
--    miembro vigente más antiguo (provisional);
--  * quitar a otro nunca deja menos de 2 miembros vigentes (22023).
create or replace function public.fin_libro_miembros_proteger()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro   public.fin_libros%rowtype;
  v_yo      uuid := public.persona_actual();
  v_es_yo   boolean;
  v_antes   boolean;
  v_despues boolean;
  v_otros   integer;
  v_relevo  uuid;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if not found or v_libro.tipo <> 'compartido' then
    return new;
  end if;
  v_es_yo := auth.uid() is not null and new.persona_id is not distinct from v_yo;

  if tg_op = 'INSERT' then
    if auth.uid() is not null
       and exists (select 1 from public.fin_libro_miembros m where m.libro_id = new.libro_id)
       and v_libro.creado_por is distinct from v_yo
       and not public.puede(v_libro.hogar_id, 'ajustes', 'administrar') then
      raise exception using errcode = '42501',
        message = 'En un libro compartido solo quien lo creó, o el dueño del hogar, agrega miembros.';
    end if;
    return new;
  end if;

  -- (a) Cambiar la membresía de OTRA persona: solo quien creó el libro o el dueño del hogar.
  if auth.uid() is not null and not v_es_yo
     and (new.desde is distinct from old.desde or new.hasta is distinct from old.hasta
          or new.papel is distinct from old.papel)
     and v_libro.creado_por is distinct from v_yo
     and not public.puede(v_libro.hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501',
      message = 'En un libro compartido solo quien lo creó, o el dueño del hogar, cambia la membresía de otra persona.';
  end if;

  -- (a2) La fecha de ingreso no se cambia a sí mismo (decide quién hereda el cargo si el
  -- administrador se sale): solo el administrador o el dueño del hogar.
  if auth.uid() is not null and v_es_yo and new.desde is distinct from old.desde
     and v_libro.creado_por is distinct from v_yo
     and not public.puede(v_libro.hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501',
      message = 'La fecha de ingreso a un libro compartido la cambia solo su administrador.';
  end if;

  -- (b) Salida del libro.
  v_antes := old.desde <= now() and (old.hasta is null or old.hasta > now())
             and public.fin_adulto_con_finanzas(v_libro.hogar_id, old.persona_id);
  v_despues := new.desde <= now() and (new.hasta is null or new.hasta > now())
               and public.fin_adulto_con_finanzas(v_libro.hogar_id, new.persona_id);
  if v_antes and not v_despues then
    select count(*)::integer into v_otros
    from public.fin_libro_miembros m
    where m.libro_id = new.libro_id and m.id <> new.id
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
      and public.fin_adulto_con_finanzas(v_libro.hogar_id, m.persona_id);
    if v_es_yo then
      -- Cualquiera puede salirse. Si se va el creador, el cargo pasa al miembro vigente más antiguo.
      if v_libro.creado_por = new.persona_id then
        select m.persona_id into v_relevo
        from public.fin_libro_miembros m
        where m.libro_id = new.libro_id and m.id <> new.id
          and m.desde <= now() and (m.hasta is null or m.hasta > now())
          and public.fin_adulto_con_finanzas(v_libro.hogar_id, m.persona_id)
        order by m.desde, m.id
        limit 1;
      end if;
      -- Con menos de 2 miembros vigentes el libro se archiva (solo lectura).
      if (v_otros < 2 and v_libro.activo) or v_relevo is not null then
        update public.fin_libros l
           set activo = case when v_otros < 2 then false else l.activo end,
               creado_por = coalesce(v_relevo, l.creado_por)
         where l.id = new.libro_id;
      end if;
    elsif v_otros < 2 then
      raise exception using errcode = '22023',
        message = 'Un libro compartido no baja de 2 miembros vigentes.',
        hint    = 'Para dejar de usarlo, archívalo (activo = false).';
    end if;
  end if;
  return new;
end
$$;
drop trigger fin_c_proteger on public.fin_libro_miembros;
create trigger fin_c_proteger before insert or update on public.fin_libro_miembros
  for each row execute function public.fin_libro_miembros_proteger();

-- puede_ver_persona(): quien lee un compartido público ve a sus miembros.
create or replace function public.puede_ver_persona(p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_persona_id = public.persona_actual()
      or exists (
        select 1
        from public.membresias m
        where m.persona_id = p_persona_id
          and (public.puede(m.hogar_id, 'ajustes', 'administrar') or public.es_cuenta_maestra(m.hogar_id))
      )
      or exists (
        select 1
        from public.fin_libros l
        where l.titular_id = p_persona_id
          and (public.puede(l.hogar_id, 'ajustes', 'administrar') or public.es_cuenta_maestra(l.hogar_id))
      )
      or exists (
        select 1
        from public.fin_libro_miembros yo
        join public.fin_libros l on l.id = yo.libro_id
        where yo.persona_id = public.persona_actual()
          and yo.desde <= now() and (yo.hasta is null or yo.hasta > now())
          and public.rol_en_hogar(l.hogar_id) is not null
          and (l.titular_id = p_persona_id
               or exists (select 1 from public.fin_libro_miembros otro
                          where otro.libro_id = l.id and otro.persona_id = p_persona_id))
      )
      or exists (
        select 1
        from public.fin_libros l
        where l.tipo = 'compartido' and l.visibilidad = 'publica'
          and public.fin_puede(l.id, 'leer')
          and exists (select 1 from public.fin_libro_miembros otro
                      where otro.libro_id = l.id and otro.persona_id = p_persona_id)
      )
$$;
comment on function public.puede_ver_persona(uuid) is
  'Cada quien se ve a sí mismo; el dueño ve a los miembros del hogar y a los titulares de sus libros; quien comparte '
  'un libro de Finanzas ve a sus miembros y a su titular; quien lee un compartido público ve a sus miembros; la '
  'cuenta maestra, a todos (D19).';

-- -----------------------------------------------------------------------------
-- 5. Cuentas: saldo cero solo en activos y pasivos; archivar la categoría archiva su cuenta
-- -----------------------------------------------------------------------------
create or replace function public.fin_cuentas_al_cambiar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_total      bigint;
  v_confirmado bigint;
begin
  new.creada_por := old.creada_por;
  new.creada_en  := old.creada_en;
  if new.tipo <> old.tipo then
    if old.tipo in ('ajustes', 'apertura', 'por_clasificar') or new.tipo in ('ajustes', 'apertura', 'por_clasificar') then
      raise exception using errcode = '22023', message = 'Las cuentas de sistema no cambian de tipo.';
    end if;
    if exists (select 1 from public.fin_movimientos m
               where m.cuenta_origen_id = old.id or m.cuenta_destino_id = old.id) then
      raise exception using errcode = '22023', message = 'Una cuenta con movimientos no cambia de tipo.';
    end if;
  end if;
  if old.tipo in ('ajustes', 'apertura', 'por_clasificar') and new.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'Las cuentas de sistema siempre están activas.';
  end if;
  -- Saldo cero para cerrar o archivar: solo activos y pasivos. Las cuentas de
  -- gasto e ingreso son de periodo y se archivan con su saldo (D19, 23/oct).
  if new.estado in ('cerrada', 'archivada') and old.estado not in ('cerrada', 'archivada')
     and old.clase in ('activo', 'pasivo') then
    select coalesce(sum(case when m.cuenta_destino_id = old.id then m.monto_centavos else -m.monto_centavos end), 0),
           coalesce(sum(case when m.cuenta_destino_id = old.id then m.monto_centavos else -m.monto_centavos end)
                      filter (where m.estado_inicial = 'confirmado'), 0)
      into v_total, v_confirmado
    from public.fin_movimientos m
    where m.cuenta_origen_id = old.id or m.cuenta_destino_id = old.id;
    if v_total <> 0 or v_confirmado <> 0 then
      raise exception using errcode = '22023', message = 'Solo se cierra o archiva una cuenta con saldo cero.';
    end if;
  end if;
  return new;
end
$$;

create function public.fin_categorias_archivar_cuenta()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.cuenta_gasto_id is null or new.archivada is not distinct from old.archivada then
    return null;
  end if;
  if new.archivada then
    -- La cuenta de gasto se archiva cuando ya no queda otra categoría activa que la use.
    if not exists (select 1 from public.fin_categorias c
                   where c.cuenta_gasto_id = new.cuenta_gasto_id and c.id <> new.id and not c.archivada) then
      update public.fin_cuentas set estado = 'archivada'
       where id = new.cuenta_gasto_id and estado in ('activa', 'congelada');
    end if;
  else
    update public.fin_cuentas set estado = 'activa'
     where id = new.cuenta_gasto_id and estado = 'archivada';
  end if;
  return null;
end
$$;
create trigger fin_d_archivar_cuenta after update of archivada on public.fin_categorias
  for each row execute function public.fin_categorias_archivar_cuenta();

-- Movimientos: igual que antes, salvo que la anulación acepta cuentas de gasto o
-- ingreso archivadas o cerradas (se archivan con saldo: anular un gasto las
-- acerca a cero). En activos y pasivos cerrados sigue sin aceptarse.
create or replace function public.fin_movimientos_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_origen    public.fin_cuentas%rowtype;
  v_destino   public.fin_cuentas%rowtype;
  v_original  public.fin_movimientos%rowtype;
  v_existente jsonb;
  v_ignorar   text[] := array['recibido_en', 'libro_origen_id', 'libro_destino_id'];
  v_libros    uuid[];
  v_real      public.fin_cuentas%rowtype;
  v_valido    boolean;
begin
  -- 1. Cuentas del mismo hogar; su libro lo pone el servidor.
  select * into v_origen from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_origen_id;
  if not found then
    raise exception using errcode = '23503', message = 'La cuenta de origen no existe en este hogar (¿aún no se sube?).';
  end if;
  select * into v_destino from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_destino_id;
  if not found then
    raise exception using errcode = '23503', message = 'La cuenta de destino no existe en este hogar (¿aún no se sube?).';
  end if;
  new.libro_origen_id  := v_origen.libro_id;
  new.libro_destino_id := v_destino.libro_id;

  -- 2. Permiso en cada libro que toca (antes de revelar nada más).
  if auth.uid() is not null and not (
       (new.libro_origen_id is null or public.fin_puede(new.libro_origen_id, 'escribir'))
       and (new.libro_destino_id is null or public.fin_puede(new.libro_destino_id, 'escribir'))) then
    raise exception using errcode = '42501', message = 'Sin permiso para registrar movimientos en ese libro.';
  end if;

  -- 3. Idempotencia: el mismo id con el mismo contenido no hace nada.
  perform pg_advisory_xact_lock(hashtextextended('fin_movimientos:' || new.id::text, 0));
  select to_jsonb(m) into v_existente from public.fin_movimientos m where m.id = new.id;
  if v_existente is not null then
    if (v_existente - v_ignorar) = (to_jsonb(new) - v_ignorar) then
      return null;
    end if;
    raise exception using errcode = '23505',
      message = format('Ya existe el movimiento %s con otro contenido.', new.id),
      hint    = 'Los movimientos no se editan: se anulan con un contraasiento.';
  end if;
  new.recibido_en := now();

  -- 4. Combinación de cuentas por tipo (tabla de 4.3, la de libro.dart).
  if new.tipo = 'anulacion' then
    if new.anula_a is null then
      raise exception using errcode = '23514', message = 'Una anulación dice qué movimiento anula (anula_a).';
    end if;
    select * into v_original from public.fin_movimientos m where m.hogar_id = new.hogar_id and m.id = new.anula_a;
    if not found then
      raise exception using errcode = '23503', message = 'El movimiento que se anula no existe (¿aún no se sube?).';
    end if;
    if v_original.tipo = 'anulacion' then
      raise exception using errcode = '22023', message = 'No se anula un contraasiento: registra de nuevo el movimiento correcto.';
    end if;
    if v_original.estado_inicial <> 'confirmado' then
      raise exception using errcode = '22023', message = 'Solo se anula un movimiento confirmado.';
    end if;
    if exists (select 1 from public.fin_movimientos m where m.anula_a = new.anula_a) then
      raise exception using errcode = '23505', message = 'Ese movimiento ya tiene una anulación.';
    end if;
    if new.monto_centavos <> v_original.monto_centavos
       or new.cuenta_origen_id <> v_original.cuenta_destino_id
       or new.cuenta_destino_id <> v_original.cuenta_origen_id then
      raise exception using errcode = '22023',
        message = 'El contraasiento lleva el mismo monto con origen y destino invertidos.';
    end if;
    if (v_origen.estado in ('cerrada', 'archivada') and v_origen.clase in ('activo', 'pasivo'))
       or (v_destino.estado in ('cerrada', 'archivada') and v_destino.clase in ('activo', 'pasivo')) then
      raise exception using errcode = '55000', message = 'Una de las cuentas está cerrada o archivada.';
    end if;
  else
    if v_origen.estado <> 'activa' or v_destino.estado <> 'activa' then
      raise exception using errcode = '55000',
        message = 'Una de las cuentas no está activa (congelada, cerrada o archivada): no admite movimientos nuevos.';
    end if;
    v_valido := case new.tipo
      when 'apertura'        then (v_origen.clase = 'apertura' and v_destino.clase = 'activo')
                               or (v_origen.clase = 'pasivo' and v_destino.clase = 'apertura')
      when 'ingreso'         then v_origen.clase = 'ingreso' and v_destino.clase = 'activo'
      when 'gasto'           then v_origen.clase in ('activo', 'pasivo') and v_destino.clase = 'gasto'
      when 'reembolso'       then v_origen.clase = 'gasto' and v_destino.clase in ('activo', 'pasivo')
      when 'transferencia'   then v_origen.clase = 'activo' and v_destino.clase = 'activo'
      when 'pago_deuda'      then v_origen.clase = 'activo' and v_destino.clase = 'pasivo'
      when 'reclasificacion' then v_origen.tipo = 'por_clasificar' and v_destino.clase = 'gasto'
      when 'ajuste'          then (v_origen.clase = 'ajuste' and v_destino.clase in ('activo', 'pasivo'))
                               or (v_origen.clase in ('activo', 'pasivo') and v_destino.clase = 'ajuste')
      else false
    end;
    if not v_valido then
      raise exception using errcode = '22023',
        message = format('Un movimiento de tipo %s no puede ir de %s (%s) a %s (%s).', new.tipo,
                         v_origen.tipo, v_origen.clase, v_destino.tipo, v_destino.clase);
    end if;
    if new.tipo = 'apertura' then
      v_real := case when v_origen.clase = 'apertura' then v_destino else v_origen end;
      if exists (select 1 from public.fin_movimientos o
                 where o.tipo = 'apertura'
                   and (o.cuenta_origen_id = v_real.id or o.cuenta_destino_id = v_real.id)
                   and not exists (select 1 from public.fin_movimientos a where a.anula_a = o.id)) then
        raise exception using errcode = '22023',
          message = 'La cuenta ya tiene saldo inicial; se corrige con anulación o con un ajuste.';
      end if;
    end if;
  end if;

  -- 5. Libros: solo transferencias y pagos de deuda cruzan de un libro a otro
  --    (aportación a un compartido); apertura y ajuste, dentro del mismo libro.
  if new.libro_origen_id is not null and new.libro_destino_id is not null
     and new.libro_origen_id <> new.libro_destino_id
     and new.tipo not in ('transferencia', 'pago_deuda')
     and not (new.tipo = 'anulacion' and v_original.tipo in ('transferencia', 'pago_deuda')) then
    raise exception using errcode = '22023',
      message = 'Solo una transferencia o un pago de deuda va de un libro a otro.';
  end if;

  -- 6. Quién: realizado_por es quien registra, un miembro vigente o el titular
  --    de alguno de los libros; en_nombre_de es el titular de un libro
  --    representado que toca el movimiento (y lo registra su albacea: paso 2).
  v_libros := array_remove(array[new.libro_origen_id, new.libro_destino_id], null);
  if new.realizado_por is distinct from new.registrado_por
     and not exists (select 1 from public.fin_libros l where l.id = any (v_libros) and l.titular_id = new.realizado_por)
     and not exists (select 1 from public.fin_libro_miembros m
                     where m.libro_id = any (v_libros) and m.persona_id = new.realizado_por
                       and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
    raise exception using errcode = '22023', message = 'Quien realizó el movimiento no lleva ese libro.';
  end if;
  if new.en_nombre_de is not null and not exists (
      select 1 from public.fin_libros l
      where l.id = any (v_libros) and l.tipo = 'representado' and l.titular_id = new.en_nombre_de) then
    raise exception using errcode = '22023',
      message = 'en_nombre_de es el titular de un libro representado que toca el movimiento.';
  end if;
  return new;
end
$$;

-- -----------------------------------------------------------------------------
-- 6. Privilegios de las funciones nuevas
-- -----------------------------------------------------------------------------
revoke execute on function
  public.fin_solo_lectura(uuid), public.fin_puede_salir(uuid),
  public.fin_libro_miembros_sin_maestra(), public.fin_libros_proteger(),
  public.fin_categorias_archivar_cuenta()
  from public, anon, authenticated, service_role;
-- Las reglas (RLS) las llaman directamente con el rol de la sesión.
grant execute on function public.fin_solo_lectura(uuid), public.fin_puede_salir(uuid)
  to authenticated, service_role;
