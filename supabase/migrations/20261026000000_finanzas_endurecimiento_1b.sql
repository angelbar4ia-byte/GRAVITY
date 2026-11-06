-- =============================================================================
-- GRAVITY · Fase 1b · Endurecimiento (hallazgos N1 a N5 de la revisión de calidad)
-- =============================================================================
-- docs/revisiones/fase-1b.md (secciones 5 y 6). Criterios por defecto, PROVISIONALES
-- hasta que responda el dueño (se anotan en supabase/README.md para D17/D19):
--
--   N1  Tope de la bitácora por persona. Un trigger por sentencia limita lo que la
--       APP (rol authenticated) escribe directamente en `bitacora`: 4 KB por entrada
--       y 500 entradas por persona en 24 horas. Lo que escriben los triggers y las
--       funciones del servidor, y el service_role, no cuenta ni se limita (el vaciado
--       de la cola sin conexión genera entradas automáticas y no se toca).
--   N2  El motivo vale solo con al menos 3 caracteres visibles tras quitar TODO el
--       espacio en blanco (espacios, tabuladores, saltos de línea, espacios Unicode y
--       caracteres invisibles), en el libro de papá, en las anulaciones, en los ajustes
--       y en las conciliaciones con diferencia. Va en TRIGGERS y no en un CHECK nuevo:
--       los CHECK también corren al restaurar una copia y rechazarían motivos viejos
--       de uno o dos caracteres (los triggers se apagan al restaurar).
--   N3  Toda salida del libro de papá hacia CUALQUIER otro libro (personal o compartido)
--       deja la entrada `finanzas.salida_libro_representado` para el suplente.
--   N4  fin_nombrar_albacea(libro, persona, papel): el dueño del hogar puede volver a
--       nombrar albacea (o suplente) de un libro de papá cuyo cargo quedó vacío.
--   N5  Si el administrador de un compartido deja de ser adulto con Finanzas del hogar
--       (baja, o su rol ya no lleva Finanzas), el cargo pasa al miembro vigente más
--       antiguo (trigger sobre `membresias`); con menos de 2 vigentes el libro pasa a
--       privado, como cuando alguien se sale.
--
-- Migración nueva (hacia adelante): las anteriores no se tocan. Esta migración no agrega
-- columnas a tablas fin_* (convención 12 del README: sin cambio en los grants insert).
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. N1: tope de la bitácora por persona
-- -----------------------------------------------------------------------------
-- SECURITY INVOKER a propósito: así `current_user` es el rol que escribe. Desde la API
-- es `authenticated`; dentro de los triggers y funciones SECURITY DEFINER es su dueño, y
-- para service_role es `service_role`: esos no se limitan. Las entradas de la app son las
-- que la regla de inserción deja pasar: nunca insertar, actualizar ni borrar, ni
-- finanzas*, ni tablas fin_* (I5). Las lee la propia persona por RLS (sus entradas siempre
-- las ve) y el índice bitacora_persona_idx hace barato el conteo.
-- Al excederlo: 54000 (program_limit_exceeded). No es de las clases que la cola reintenta
-- (08, 40001, 40P01, 53, 57): lo rechazado queda en "requiere atención". La sentencia
-- completa se deshace: no se guarda ninguna de sus entradas.
create function public.bitacora_tope_por_persona()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  c_max_entradas constant integer := 500;     -- por persona, en 24 horas
  c_max_bytes    constant integer := 4096;    -- por entrada (el detalle en texto)
  v_persona uuid;
  v_n       integer;
begin
  if current_user <> 'authenticated' then
    return null;
  end if;
  if exists (select 1 from nuevas n where octet_length(n.detalle::text) > c_max_bytes) then
    raise exception using errcode = '54000',
      message = 'Una entrada de la bitácora pesa más de 4 KB.',
      hint    = 'La bitácora guarda hechos breves, no archivos ni listas largas.';
  end if;
  for v_persona in select distinct n.persona_id from nuevas n where n.persona_id is not null loop
    select count(*)::integer into v_n
    from public.bitacora b
    where b.persona_id = v_persona
      and b.registrado_en > now() - interval '24 hours'
      and b.accion not in ('insertar', 'actualizar', 'borrar')
      and b.accion !~* '^\s*finanzas'
      and lower(coalesce(b.tabla, '')) !~ '^\s*(public\.)?fin_';
    if v_n > c_max_entradas then
      raise exception using errcode = '54000',
        message = 'Demasiadas entradas en la bitácora: el tope es de 500 por persona en 24 horas.',
        hint    = 'Inténtalo de nuevo mañana; si es un error de la app, avísale a quien la mantiene.';
    end if;
  end loop;
  return null;
end
$$;
comment on function public.bitacora_tope_por_persona() is
  'N1: tope de lo que la app escribe en la bitácora: 4 KB por entrada y 500 entradas por persona en 24 horas '
  '(54000 al excederlo). No limita a los triggers, a las funciones del servidor ni a service_role.';
create trigger bitacora_tope
  after insert on public.bitacora
  referencing new table as nuevas
  for each statement execute function public.bitacora_tope_por_persona();

-- -----------------------------------------------------------------------------
-- 2. N2: el motivo necesita al menos 3 caracteres visibles
-- -----------------------------------------------------------------------------
-- Se quita todo lo que no se ve: espacio en blanco ASCII y Unicode (NBSP, espacios
-- de ancho fijo, separadores de línea y de párrafo, ideográfico), caracteres de control
-- y de formato invisibles (ancho cero, marcas de dirección, soft hyphen, BOM, rellenos).
create function public.fin_motivo_valido(p_motivo text)
returns boolean
language sql immutable parallel safe
set search_path = ''
as $$
  select char_length(regexp_replace(coalesce(p_motivo, ''),
    '[[:space:][:cntrl:]\u0085 ­؜ᅟᅠ ᠎ -‏ -  -⁯⠀　ㅤ﻿ﾠ￹-￻]',
    '', 'g')) >= 3
$$;
comment on function public.fin_motivo_valido(text) is
  'N2: el motivo cuenta solo si tiene al menos 3 caracteres visibles tras quitar todo espacio en blanco y '
  'caracteres invisibles (espacios, tabuladores, saltos de línea, espacios Unicode).';

-- Libro de papá: el motivo ya no puede ser en blanco ni de uno o dos caracteres.
create or replace function public.fin_movimientos_representado()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_titulares uuid[];
begin
  select coalesce(array_agg(l.titular_id), '{}'::uuid[]) into v_titulares
  from public.fin_libros l
  where l.tipo = 'representado' and l.id in (new.libro_origen_id, new.libro_destino_id);
  if cardinality(v_titulares) = 0 then
    return new;
  end if;
  if new.en_nombre_de is null or not (new.en_nombre_de = any (v_titulares)) then
    raise exception using errcode = '23514',
      message = 'Todo movimiento del libro de una persona representada va en su nombre (en_nombre_de).';
  end if;
  if not public.fin_motivo_valido(new.motivo) then
    raise exception using errcode = '23514',
      message = 'Todo movimiento del libro de una persona representada lleva motivo (al menos 3 caracteres visibles).';
  end if;
  return new;
end
$$;

-- Anulaciones, ajustes, movimientos en nombre de otra persona y conciliaciones con
-- diferencia: mismo criterio. Los CHECK de las tablas (no vacío tras btrim) no se tocan
-- (así una copia vieja se restaura); este trigger corre solo en altas nuevas, después del
-- que no deja pasar un reenvío idéntico, así que lo ya guardado nunca se rechaza.
create function public.fin_motivo_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'fin_movimientos' then
    if (new.tipo in ('ajuste', 'anulacion') or new.en_nombre_de is not null)
       and not public.fin_motivo_valido(new.motivo) then
      raise exception using errcode = '23514',
        message = 'El motivo necesita al menos 3 caracteres visibles.',
        hint    = 'Los espacios, tabuladores y saltos de línea no cuentan.';
    end if;
  elsif tg_table_name = 'fin_conciliaciones' then
    if new.saldo_declarado is distinct from new.saldo_calculado and not public.fin_motivo_valido(new.motivo) then
      raise exception using errcode = '23514',
        message = 'El motivo necesita al menos 3 caracteres visibles.',
        hint    = 'Los espacios, tabuladores y saltos de línea no cuentan.';
    end if;
  end if;
  return new;
end
$$;
-- Se llaman fin_c_*: corren después de las validaciones propias de cada tabla (fin_a_*, fin_b_*), de modo
-- que un error de estructura (cuentas, ajuste, libro) sigue saliendo con su propio código.
create trigger fin_c_motivo before insert on public.fin_movimientos
  for each row execute function public.fin_motivo_validar();
create trigger fin_c_motivo before insert on public.fin_conciliaciones
  for each row execute function public.fin_motivo_validar();

-- -----------------------------------------------------------------------------
-- 3. N3: toda salida del libro de papá avisa al suplente
-- -----------------------------------------------------------------------------
-- Antes solo si el destino era un libro personal; pasar por un compartido evitaba el
-- aviso. Ahora cualquier libro distinto del de papá.
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
  end if;
  return null;
end
$$;

-- -----------------------------------------------------------------------------
-- 4. N4: el dueño vuelve a nombrar albacea del libro de papá
-- -----------------------------------------------------------------------------
-- Se agrega al validador de miembros una vía más: el dueño del hogar puede dar de alta
-- al albacea (o al suplente) de un libro representado cuando ese cargo está vacío (nadie
-- vigente que siga siendo adulto con Finanzas). La regla de inserción (RLS) sigue exigiendo
-- administrar el libro: la única puerta es la función de abajo (SECURITY DEFINER).
create or replace function public.fin_libro_miembros_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if not found then
    raise exception using errcode = '23503', message = 'El libro no existe (¿aún no se sube?).';
  end if;
  if tg_op = 'INSERT' and auth.uid() is not null
     and not public.fin_puede(new.libro_id, 'administrar')
     -- Arranque: el primer miembro de un libro nuevo (lo agrega el servidor).
     and not (not exists (select 1 from public.fin_libro_miembros m where m.libro_id = new.libro_id)
              and new.persona_id = (case when v_libro.tipo = 'personal' then v_libro.titular_id
                                         else v_libro.creado_por end))
     -- N4: el dueño del hogar nombra al albacea o al suplente de un cargo vacío.
     and not (v_libro.tipo = 'representado'
              and new.papel in ('albacea', 'albacea_suplente')
              and public.puede(v_libro.hogar_id, 'ajustes', 'administrar')
              and not exists (select 1 from public.fin_libro_miembros v
                              where v.libro_id = new.libro_id and v.papel = new.papel and v.hasta is null
                                and public.fin_adulto_con_finanzas(v_libro.hogar_id, v.persona_id))) then
    raise exception using errcode = '42501', message = 'Sin permiso para administrar los miembros de ese libro.';
  end if;
  if new.hogar_id is not null and new.hogar_id <> v_libro.hogar_id then
    raise exception using errcode = '22023', message = 'El libro es de otro hogar.';
  end if;
  new.hogar_id := v_libro.hogar_id;

  if v_libro.tipo = 'personal' and (new.papel <> 'titular' or new.persona_id <> v_libro.titular_id) then
    raise exception using errcode = '22023', message = 'El titular de un libro personal es su único miembro.';
  end if;
  if v_libro.tipo = 'personal' and new.hasta is not null then
    raise exception using errcode = '22023', message = 'El titular no deja su libro personal.';
  end if;
  if v_libro.tipo = 'compartido' and new.papel <> 'miembro' then
    raise exception using errcode = '22023', message = 'En un libro compartido todos son miembros.';
  end if;
  if v_libro.tipo = 'representado' and new.papel not in ('albacea', 'albacea_suplente') then
    raise exception using errcode = '22023', message = 'Un libro representado lo llevan su albacea y su suplente.';
  end if;
  if v_libro.tipo = 'representado' and new.persona_id = v_libro.titular_id then
    raise exception using errcode = '22023', message = 'La persona representada no es miembro de su libro.';
  end if;
  if (new.hasta is null or new.hasta > now()) and not exists (
      select 1 from public.membresias m
      join public.permisos_rol pr on pr.rol = m.rol and pr.modulo = 'finanzas' and pr.accion = 'leer'
      where m.hogar_id = new.hogar_id and m.persona_id = new.persona_id and m.activa
        and m.desde <= now() and (m.hasta is null or m.hasta > now())
        and pr.alcance in ('propio', 'total')) then
    raise exception using errcode = '22023',
      message = 'Solo un adulto con Finanzas en el hogar (dueño o coadministrador) lleva un libro.';
  end if;
  return new;
end
$$;

create function public.fin_nombrar_albacea(
  p_libro_id uuid, p_persona_id uuid, p_papel text default 'albacea')
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro    public.fin_libros%rowtype;
  v_id       uuid;
  v_anterior uuid;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  -- Mismo 42501 exista o no el libro y sea de quien sea: no revela libros.
  if not found
     or not public.puede(v_libro.hogar_id, 'ajustes', 'administrar')
     or coalesce(public.alcance(v_libro.hogar_id, 'finanzas', 'administrar'), '') not in ('propio', 'total') then
    raise exception using errcode = '42501', message = 'Solo el dueño del hogar nombra al albacea del libro de papá.';
  end if;
  if v_libro.tipo <> 'representado' then
    raise exception using errcode = '22023', message = 'Solo el libro de una persona representada tiene albacea.';
  end if;
  if p_papel is null or p_papel not in ('albacea', 'albacea_suplente') then
    raise exception using errcode = '22023', message = 'El cargo es albacea o albacea_suplente.';
  end if;
  if p_persona_id is null or not public.fin_adulto_con_finanzas(v_libro.hogar_id, p_persona_id) then
    raise exception using errcode = '22023',
      message = 'Solo un adulto con Finanzas en el hogar (dueño o coadministrador) lleva un libro.';
  end if;
  if p_persona_id = v_libro.titular_id then
    raise exception using errcode = '22023', message = 'La persona representada no es miembro de su libro.';
  end if;
  -- El cargo debe estar vacío: nadie vigente que siga siendo adulto con Finanzas.
  if exists (select 1 from public.fin_libro_miembros m
             where m.libro_id = p_libro_id and m.papel = p_papel and m.hasta is null
               and public.fin_adulto_con_finanzas(v_libro.hogar_id, m.persona_id)) then
    raise exception using errcode = '22023',
      message = 'Ese cargo ya lo ocupa alguien: quien lo tiene debe dejarlo primero.';
  end if;
  if exists (select 1 from public.fin_libro_miembros m
             where m.libro_id = p_libro_id and m.persona_id = p_persona_id and m.hasta is null) then
    raise exception using errcode = '22023',
      message = 'Esa persona ya lleva el libro con otro cargo: que lo deje primero.';
  end if;
  -- Un cargo abierto de alguien que ya no es adulto con Finanzas estorba al índice único:
  -- se cierra.
  update public.fin_libro_miembros m
     set hasta = now()
   where m.libro_id = p_libro_id and m.papel = p_papel and m.hasta is null
  returning m.persona_id into v_anterior;
  insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values (v_libro.hogar_id, p_libro_id, p_persona_id, p_papel)
  returning id into v_id;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_libro.hogar_id, public.persona_actual(), 'finanzas.albacea_nombrado', 'fin_libro_miembros',
          v_id::text,
          jsonb_build_object('libro_id', p_libro_id, 'persona_id', p_persona_id, 'papel', p_papel,
                             'anterior_persona_id', v_anterior));
  return v_id;
end
$$;
comment on function public.fin_nombrar_albacea(uuid, uuid, text) is
  'N4. Solo el dueño del hogar. Nombra albacea (o suplente) del libro de papá cuando ese cargo está vacío; si hay '
  'un cargo abierto de alguien que ya no es adulto con Finanzas, lo cierra. Deja finanzas.albacea_nombrado en la '
  'bitácora. Devuelve el id de la fila de fin_libro_miembros.';
revoke execute on function public.fin_nombrar_albacea(uuid, uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.fin_nombrar_albacea(uuid, uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. N5: el administrador de un compartido deja de ser adulto con Finanzas
-- -----------------------------------------------------------------------------
-- Reglas (las mismas de cuando alguien se sale): si el administrador ya no es miembro
-- vigente, el cargo pasa al miembro vigente más antiguo (`desde`, luego `id`); con menos
-- de 2 miembros vigentes el libro pasa a privado. Nunca se archiva solo.
create function public.fin_libro_asegurar_administrador(p_libro_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro   public.fin_libros%rowtype;
  v_vigentes uuid[];
  v_relevo  uuid;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id and l.tipo = 'compartido';
  if not found then
    return;
  end if;
  select coalesce(array_agg(x.persona_id order by x.desde, x.id), '{}'::uuid[]) into v_vigentes
  from public.fin_libro_miembros x
  where x.libro_id = p_libro_id and x.desde <= now() and (x.hasta is null or x.hasta > now())
    and public.fin_adulto_con_finanzas(v_libro.hogar_id, x.persona_id);
  if cardinality(v_vigentes) = 0 then
    return;  -- nadie a quien pasarle el cargo
  end if;
  if v_libro.creado_por is null or not (v_libro.creado_por = any (v_vigentes)) then
    v_relevo := v_vigentes[1];
  end if;
  if v_relevo is not null or (cardinality(v_vigentes) < 2 and v_libro.visibilidad <> 'privada') then
    update public.fin_libros l
       set creado_por = coalesce(v_relevo, l.creado_por),
           visibilidad = case when cardinality(v_vigentes) < 2 then 'privada' else l.visibilidad end
     where l.id = p_libro_id;
  end if;
end
$$;
comment on function public.fin_libro_asegurar_administrador(uuid) is
  'N5. Si el administrador de un compartido ya no es miembro vigente (adulto con Finanzas), el cargo pasa al miembro '
  'vigente más antiguo; con menos de 2 vigentes el libro pasa a privado. Interna: la llama el trigger de membresías.';

create function public.fin_membresia_relevo_administrador()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro uuid;
begin
  if public.fin_adulto_con_finanzas(new.hogar_id, new.persona_id) then
    return null;  -- sigue siendo adulto con Finanzas
  end if;
  for v_libro in
    select l.id
    from public.fin_libros l
    where l.hogar_id = new.hogar_id and l.tipo = 'compartido'
      and (l.creado_por = new.persona_id
           or exists (select 1 from public.fin_libro_miembros m
                      where m.libro_id = l.id and m.persona_id = new.persona_id and m.hasta is null))
    order by l.creado_en, l.id
  loop
    perform public.fin_libro_asegurar_administrador(v_libro);
  end loop;
  return null;
end
$$;
comment on function public.fin_membresia_relevo_administrador() is
  'N5. Trigger de membresías: al dejar de ser adulto con Finanzas, la persona deja el cargo de administrador de los '
  'compartidos (pasa al miembro vigente más antiguo) y, si quedan menos de 2 vigentes, el libro pasa a privado.';
create trigger fin_z_relevo_administrador
  after update of rol, activa, hasta on public.membresias
  for each row execute function public.fin_membresia_relevo_administrador();

-- -----------------------------------------------------------------------------
-- 6. Privilegios de las funciones nuevas
-- -----------------------------------------------------------------------------
-- Ninguna es para la app salvo fin_nombrar_albacea (arriba): las demás las ejecutan
-- triggers y otras funciones del servidor.
revoke execute on function
  public.bitacora_tope_por_persona(), public.fin_motivo_valido(text), public.fin_motivo_validar(),
  public.fin_libro_asegurar_administrador(uuid), public.fin_membresia_relevo_administrador()
  from public, anon, authenticated, service_role;
