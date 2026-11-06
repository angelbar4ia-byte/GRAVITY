-- =============================================================================
-- GRAVITY · Fase 1 · Respuestas del dueño, 2.ª ronda del 23/oct/2026 (D19)
-- =============================================================================
-- docs/DECISIONES.md (D19, "Respuestas del dueño del 23/oct/2026").
--
--   1. Salirse de un compartido (o que saquen a alguien): si quedan menos de 2
--      miembros vigentes el libro NO se archiva: pasa a visibilidad 'privada' y
--      sigue activo, y el miembro que queda es el administrador (creado_por).
--      El último miembro vigente no puede salirse (22023, con la pista de
--      archivar). Archivar es solo la decisión explícita del administrador.
--      Quitar a otro dejando menos de 2 se trata igual que salirse (ya no 22023).
--      Si se va el administrador, el cargo pasa al miembro vigente más antiguo.
--   2. fin_adultos_con_finanzas(hogar): los adultos con Finanzas del hogar
--      (nombre y rol; nunca la cuenta maestra que no es la dueña, ni familiar,
--      cuidador o casa), visible para cualquier adulto con Finanzas del hogar,
--      para poder agregarlos a un compartido.
--   3. La hora de `hasta` al salirse la pone el teléfono: no hay función de salida.
--
-- Migración nueva (hacia adelante): las anteriores no se tocan. Reemplaza el
-- trigger de la membresía de un compartido de 20261024000000_finanzas_respuestas_dueno.sql.
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Membresías de un compartido: salida, relevo y paso a privado
-- -----------------------------------------------------------------------------
-- Reglas (sin cambio frente a la migración anterior):
--  * agregar o cambiar a OTRA persona: solo quien creó el libro o el dueño del hogar;
--  * la fecha de ingreso no se cambia a sí mismo.
-- Reglas nuevas al cerrar la membresía de alguien que hoy cuenta como miembro:
--  * si no quedaría nadie vigente: 22023 (el último miembro no se sale; el
--    administrador archiva el libro si ya no se usa);
--  * si el administrador ya no es miembro vigente (se va él, o ya no es adulto
--    del hogar), el cargo pasa al miembro vigente más antiguo (`desde`, luego `id`);
--  * si quedan menos de 2 miembros vigentes el libro pasa a 'privada' y el único
--    que queda es el administrador. NUNCA se archiva solo.
-- Todo cambio de fin_libros queda en la bitácora por su trigger.
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

  -- (b) Alguien deja de contar como miembro: salida propia o la saca otra persona.
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

    -- El último miembro vigente no se sale (ni lo sacan): el libro no se queda sin nadie.
    if v_otros = 0 then
      raise exception using errcode = '22023',
        message = 'El último miembro de un libro compartido no puede salirse.',
        hint    = 'Si ya no lo usas, archívalo (activo = false).';
    end if;

    -- ¿Sigue siendo miembro vigente quien lo administra? Si no, el cargo pasa al más antiguo.
    if not exists (
        select 1 from public.fin_libro_miembros m
        where m.libro_id = new.libro_id and m.id <> new.id and m.persona_id = v_libro.creado_por
          and m.desde <= now() and (m.hasta is null or m.hasta > now())
          and public.fin_adulto_con_finanzas(v_libro.hogar_id, m.persona_id)) then
      select m.persona_id into v_relevo
      from public.fin_libro_miembros m
      where m.libro_id = new.libro_id and m.id <> new.id
        and m.desde <= now() and (m.hasta is null or m.hasta > now())
        and public.fin_adulto_con_finanzas(v_libro.hogar_id, m.persona_id)
      order by m.desde, m.id
      limit 1;
    end if;

    -- Con menos de 2 miembros el libro pasa a privado (activo no cambia: nunca se archiva solo).
    if v_relevo is not null or (v_otros < 2 and v_libro.visibilidad <> 'privada') then
      update public.fin_libros l
         set creado_por = coalesce(v_relevo, l.creado_por),
             visibilidad = case when v_otros < 2 then 'privada' else l.visibilidad end
       where l.id = new.libro_id;
    end if;
  end if;
  return new;
end
$$;
comment on function public.fin_libro_miembros_proteger() is
  'Trigger de las membresías de un libro compartido (D19, 23/oct): solo el administrador o el dueño agregan o cambian '
  'a otros; cualquiera se sale; el último miembro no puede salirse (22023); si el administrador se va (o ya no es '
  'miembro vigente) el cargo pasa al miembro vigente más antiguo; con menos de 2 miembros el libro pasa a privado y '
  'sigue activo. Archivar es solo del administrador.';

-- -----------------------------------------------------------------------------
-- 2. Los adultos con Finanzas del hogar (para agregarlos a un compartido)
-- -----------------------------------------------------------------------------
-- Dueño y coadministradores vigentes con Finanzas. Se excluye la cuenta maestra que no es la
-- dueña (solo lectura: no lleva libros ni es miembro) y, por el rol, a familiares, cuidadores y casa.
-- La ve cualquier adulto con Finanzas del hogar (incluida la maestra, que ya ve los nombres del
-- hogar); si la sesión no lo es, no devuelve filas (no da error). Incluye a la propia sesión.
create function public.fin_adultos_con_finanzas(p_hogar_id uuid)
returns table (persona_id uuid, nombre_visible text, rol text)
language sql stable security definer
set search_path = ''
as $$
  select p.id, p.nombre_visible, m.rol::text
  from public.membresias m
  join public.personas p on p.id = m.persona_id
  where m.hogar_id = p_hogar_id
    and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
    and public.fin_adulto_con_finanzas(p_hogar_id, m.persona_id)
    and not (m.es_maestra and m.rol <> 'dueno')
    and public.fin_adulto_con_finanzas(p_hogar_id, public.persona_actual())
  order by p.nombre_visible, p.id
$$;
comment on function public.fin_adultos_con_finanzas(uuid) is
  'Adultos con Finanzas del hogar (persona_id, nombre_visible, rol) para agregarlos a un compartido: dueño y '
  'coadministradores vigentes, sin la cuenta maestra que no es la dueña, ni familiar, cuidador o casa. Solo la '
  've un adulto con Finanzas del hogar; si no lo es, devuelve cero filas.';
revoke execute on function public.fin_adultos_con_finanzas(uuid) from public, anon, authenticated, service_role;
grant execute on function public.fin_adultos_con_finanzas(uuid) to authenticated;
