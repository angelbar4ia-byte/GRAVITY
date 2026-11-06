-- =============================================================================
-- GRAVITY · Fase 1 · Salvaguardas de Finanzas
-- =============================================================================
-- Corrige los hallazgos importantes de la revisión de calidad de la Fase 1
-- (docs/revisiones/fase-1.md): las salvaguardas de D19 dejan de depender de que
-- el cliente se porte bien y pasan a vivir en el servidor.
--
--   I1  Libro compartido: solo quien lo creó, o el dueño del hogar, cambia la
--       membresía de otra persona; nunca quedan menos de 2 miembros vigentes.
--   I2  Cuenta maestra: leer el contenido de un libro ajeno exige una consulta
--       registrada por esa persona en ese libro, con vigencia de 30 minutos
--       (fin_registrar_consulta_maestra() la crea y escribe la bitácora).
--   I3  Libro representado (papá): todo movimiento lleva en_nombre_de y motivo;
--       las salidas hacia un libro personal dejan una entrada propia en la
--       bitácora (finanzas.salida_libro_representado).
--   I4  Albacea y suplente: "vigente" solo si su membresía del hogar sigue
--       activa y con Finanzas; si el albacea sale, el suplente escribe.
--   I5  Bitácora: las acciones finanzas* y las tablas fin_* las escribe solo el
--       servidor (triggers y funciones SECURITY DEFINER).
--   M6  La cuenta maestra (si no es la dueña) no cambia la configuración del
--       hogar (categorías, cuentas de gasto, días inhábiles, importaciones).
--   M10 Asignar o quitar la cuenta maestra deja una entrada en la bitácora
--       (finanzas.maestra_asignada) que ve todo adulto con Finanzas.
--
-- Criterios provisionales mientras el dueño responde (se anotan para D17/D19).
-- Migración nueva (hacia adelante): las anteriores no se tocan.
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Ayudantes internos (solo los ejecutan otras funciones del servidor)
-- -----------------------------------------------------------------------------
create function public.fin_vigencia_consulta_maestra()
returns interval
language sql immutable
set search_path = ''
as $$ select interval '30 minutes' $$;
comment on function public.fin_vigencia_consulta_maestra() is
  'Cuánto vale una consulta registrada de la cuenta maestra a un libro ajeno (I2): 30 minutos.';

-- ¿La persona es hoy un adulto con Finanzas en el hogar? (membresía activa y
-- vigente, con un rol que lee Finanzas.) Es la condición de I4: un albacea, un
-- suplente o un miembro que ya no la cumple deja de contar.
create function public.fin_adulto_con_finanzas(p_hogar_id uuid, p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.membresias m
    join public.permisos_rol pr on pr.rol = m.rol and pr.modulo = 'finanzas' and pr.accion = 'leer'
    where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
      and pr.alcance in ('propio', 'total'))
$$;
comment on function public.fin_adulto_con_finanzas(uuid, uuid) is
  'La persona tiene hoy una membresía activa del hogar con un rol que lee Finanzas (I4).';

-- Las consultas se buscan por (persona, libro, instante): índice parcial.
create index bitacora_consulta_maestra_idx
  on public.bitacora (persona_id, registro_id, registrado_en desc)
  where accion = 'finanzas.consulta_maestra';

-- -----------------------------------------------------------------------------
-- 2. fin_puede(): I2 (consulta vigente de la maestra) e I4 (albacea vigente)
-- -----------------------------------------------------------------------------
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
    -- La cuenta maestra solo lee lo ajeno, y solo con una consulta registrada
    -- por ella en ese libro en los últimos 30 minutos (I2); nunca escribe.
    return p_accion = 'leer'
       and public.es_cuenta_maestra(v_libro.hogar_id)
       and exists (
         select 1
         from public.bitacora b
         where b.accion = 'finanzas.consulta_maestra'
           and b.persona_id = v_persona
           and b.registro_id = p_libro_id::text
           and b.registrado_en > now() - public.fin_vigencia_consulta_maestra());
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
      return false;
    end if;
    -- El suplente escribe solo si no hay albacea vigente.
    return v_papel in ('titular', 'miembro', 'albacea')
        or (v_papel = 'albacea_suplente' and not v_albacea);
  end if;

  -- administrar
  return (v_libro.tipo = 'personal' and v_papel = 'titular')
      or (v_libro.tipo = 'compartido' and v_papel = 'miembro')
      or (v_libro.tipo = 'representado'
          and (v_papel = 'albacea' or (v_papel = 'albacea_suplente' and not v_albacea)));
end
$$;
comment on function public.fin_puede(uuid, text) is
  'D19. leer: miembro vigente del libro, o la cuenta maestra con una consulta registrada en ese libro en los '
  'últimos 30 minutos (I2). escribir: titular, miembro o albacea (el suplente solo sin albacea vigente; el '
  'albacea es vigente solo si sigue siendo adulto con Finanzas, I4), con el libro activo. administrar: titular '
  'de un personal, miembro de un compartido, albacea de un representado. Siempre exige un rol con Finanzas.';

-- -----------------------------------------------------------------------------
-- 3. fin_puede_hogar(): M6 (la maestra no cambia la configuración del hogar)
-- -----------------------------------------------------------------------------
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
  if not v_rol_con_finanzas then
    return false;
  end if;
  -- M6: la cuenta maestra solo lee. Si no es la dueña, tampoco cambia la
  -- configuración del hogar (puede congelar cuentas de gasto, archivar
  -- categorías o desactivar festivos de los demás).
  return not (public.es_cuenta_maestra(p_hogar_id) and public.rol_en_hogar(p_hogar_id) <> 'dueno');
end
$$;
comment on function public.fin_puede_hogar(uuid, text) is
  'Para lo de Finanzas que es del HOGAR (categorías, cuentas de gasto, días inhábiles, importaciones): el rol '
  'tiene Finanzas (propio o total) para esa acción; la cuenta maestra además lee, pero, si no es la dueña, no '
  'cambia la configuración del hogar (M6).';

-- -----------------------------------------------------------------------------
-- 4. Bitácora: quién ve qué (I2) y quién escribe qué (I5)
-- -----------------------------------------------------------------------------
-- La cuenta maestra ya no ve las entradas de Finanzas por atajo: pasan por
-- fin_puede() (consulta vigente). Para lo demás (membresías, invitaciones,
-- historial de GRAVITY) sigue viendo todo el hogar (D19).
create or replace function public.puede_ver_entrada_bitacora(
  p_hogar_id uuid, p_tabla text, p_accion text, p_registro_id text, p_detalle jsonb)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_fila   jsonb;
  v_texto  text;
  v_libros uuid[] := '{}';
begin
  if p_hogar_id is null then
    return false;
  end if;
  -- Finanzas (tablas fin_* y acciones finanzas*): quien puede leer el libro de
  -- la entrada; lo del hogar, quien tiene Finanzas (o la maestra).
  if lower(coalesce(p_tabla, '')) like 'fin\_%' or p_accion like 'finanzas%' then
    v_fila := coalesce(p_detalle -> 'despues', p_detalle -> 'antes', p_detalle);
    foreach v_texto in array array[
        v_fila ->> 'libro_id', v_fila ->> 'libro_origen_id', v_fila ->> 'libro_destino_id',
        case when p_tabla = 'fin_libros' then coalesce(v_fila ->> 'id', p_registro_id) end]
    loop
      if v_texto ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        v_libros := v_libros || v_texto::uuid;
      end if;
    end loop;
    if cardinality(v_libros) = 0 then
      return public.fin_puede_hogar(p_hogar_id, 'leer');
    end if;
    return exists (select 1 from unnest(v_libros) as l(id) where public.fin_puede(l.id, 'leer'));
  end if;
  if public.es_cuenta_maestra(p_hogar_id) then
    return true;
  end if;
  if p_accion like 'gravity.%' then
    return false;
  end if;
  return public.puede(p_hogar_id, 'ajustes', 'administrar');
end
$$;
comment on function public.puede_ver_entrada_bitacora(uuid, text, text, text, jsonb) is
  'Regla de lectura de la bitácora. Finanzas (fin_* y finanzas*): quien puede leer el libro (la cuenta maestra '
  'solo con una consulta vigente); lo del hogar, quien tiene Finanzas. Historial de GRAVITY: su autor y la cuenta '
  'maestra. Lo demás: el dueño y la cuenta maestra.';

-- I5: las acciones finanzas* y las tablas fin_* de la bitácora las escriben
-- solo los triggers y las funciones SECURITY DEFINER (que no pasan por RLS).
drop policy bitacora_agregar on public.bitacora;
create policy bitacora_agregar on public.bitacora
  for insert to authenticated
  with check (persona_id = (select public.persona_actual())
              and (hogar_id is null or public.rol_en_hogar(hogar_id) is not null)
              and ocurrido_en <= now() + interval '10 minutes'
              and accion not in ('insertar', 'actualizar', 'borrar')
              and accion !~* '^\s*finanzas'
              and lower(coalesce(tabla, '')) !~ '^\s*(public\.)?fin_');

-- -----------------------------------------------------------------------------
-- 5. Cuenta maestra: consulta registrada (I2) y aviso del cambio (M10)
-- -----------------------------------------------------------------------------
create or replace function public.fin_registrar_consulta_maestra(p_libro_id uuid)
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found or not public.es_cuenta_maestra(v_libro.hogar_id) then
    raise exception using errcode = '42501', message = 'Solo la cuenta maestra del hogar registra consultas.';
  end if;
  if public.fin_es_miembro(p_libro_id) then
    return false;  -- lo propio no se registra
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_libro.hogar_id, public.persona_actual(), 'finanzas.consulta_maestra', 'fin_libros',
          p_libro_id::text,
          jsonb_build_object('libro_id', p_libro_id, 'tipo', v_libro.tipo,
                             'vigencia_minutos', (extract(epoch from public.fin_vigencia_consulta_maestra()) / 60)::integer));
  return true;
end
$$;
comment on function public.fin_registrar_consulta_maestra(uuid) is
  'La cuenta maestra la llama ANTES de abrir un libro ajeno: deja la consulta en la bitácora '
  '(finanzas.consulta_maestra, visible para quienes llevan ese libro) y habilita su lectura por 30 minutos; '
  'sin una consulta vigente el servidor no le devuelve filas de ese libro (I2). Pasado ese tiempo hay que '
  'llamarla de nuevo. Devuelve falso si el libro es propio (no se registra ni hace falta).';

create or replace function public.asignar_cuenta_maestra(p_hogar_id uuid, p_persona_id uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_anterior uuid;
begin
  if not public.puede(p_hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501', message = 'Solo el dueño del hogar asigna la cuenta maestra.';
  end if;
  if p_persona_id is not null and not exists (
      select 1 from public.membresias m
      where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
        and m.desde <= now() and (m.hasta is null or m.hasta > now())
        and m.rol in ('dueno', 'coadministrador')) then
    raise exception using errcode = '22023',
      message = 'La cuenta maestra debe ser un miembro vigente con Finanzas (dueño o coadministrador).';
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

  -- M10: el cambio queda a la vista de todo adulto con Finanzas (sin libro_id
  -- en el detalle: lo ve quien tiene Finanzas en el hogar).
  if v_anterior is distinct from p_persona_id then
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (p_hogar_id, public.persona_actual(), 'finanzas.maestra_asignada', 'membresias',
            coalesce(p_persona_id, v_anterior)::text,
            jsonb_build_object('anterior_persona_id', v_anterior, 'nueva_persona_id', p_persona_id));
  end if;
end
$$;
comment on function public.asignar_cuenta_maestra(uuid, uuid) is
  'Solo el dueño. Nombra la cuenta maestra del hogar (dueño o coadministrador vigente) o la quita con nulo. '
  'Queda en la bitácora de membresías (solo el dueño la ve) y en una entrada finanzas.maestra_asignada que ve '
  'todo adulto con Finanzas (M10).';

-- -----------------------------------------------------------------------------
-- 6. Libros: la cuenta maestra ve que existen (sin consulta); I2 protege el contenido
-- -----------------------------------------------------------------------------
-- Sin esto la maestra no podría ni listar los libros para elegir cuál consultar.
-- Solo ve la portada (libro y miembros); cuentas, movimientos, plan y cierres
-- exigen la consulta registrada.
drop policy fin_libros_leer on public.fin_libros;
create policy fin_libros_leer on public.fin_libros for select to authenticated
  using (public.fin_puede(id, 'leer') or public.es_cuenta_maestra(hogar_id));

drop policy fin_libro_miembros_leer on public.fin_libro_miembros;
create policy fin_libro_miembros_leer on public.fin_libro_miembros for select to authenticated
  using (public.fin_puede(libro_id, 'leer') or public.es_cuenta_maestra(hogar_id));

-- Crear un libro propio no es "configuración del hogar" (M6): la maestra
-- también puede crear los suyos.
drop policy fin_libros_agregar on public.fin_libros;
create policy fin_libros_agregar on public.fin_libros for insert to authenticated
  with check (creado_por = (select public.persona_actual())
              and coalesce(public.alcance(hogar_id, 'finanzas', 'administrar'), '') in ('propio', 'total')
              and ((tipo = 'personal' and titular_id = (select public.persona_actual()))
                   or tipo = 'compartido'));

-- -----------------------------------------------------------------------------
-- 7. I1: membresías de un libro compartido
-- -----------------------------------------------------------------------------
create function public.fin_libro_miembros_proteger()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro   public.fin_libros%rowtype;
  v_antes   boolean;
  v_despues boolean;
  v_otros   integer;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if not found or v_libro.tipo <> 'compartido' then
    return new;
  end if;

  -- (a) Cambiar la membresía de OTRA persona: solo quien creó el libro o el
  -- dueño del hogar. (Lo propio —salirse— lo decide cada quien, ver (b).)
  if auth.uid() is not null
     and new.persona_id is distinct from public.persona_actual()
     and (new.desde is distinct from old.desde or new.hasta is distinct from old.hasta
          or new.papel is distinct from old.papel)
     and v_libro.creado_por is distinct from public.persona_actual()
     and not public.puede(v_libro.hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501',
      message = 'En un libro compartido solo quien lo creó, o el dueño del hogar, cambia la membresía de otra persona.';
  end if;

  -- (b) Nunca menos de 2 miembros vigentes (adultos con Finanzas).
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
    if v_otros < 2 then
      raise exception using errcode = '22023',
        message = 'Un libro compartido no baja de 2 miembros vigentes.',
        hint    = 'Para dejar de usarlo, desactiva el libro.';
    end if;
  end if;
  return new;
end
$$;
create trigger fin_c_proteger before update on public.fin_libro_miembros
  for each row execute function public.fin_libro_miembros_proteger();

-- -----------------------------------------------------------------------------
-- 8. I3: libro representado (papá)
-- -----------------------------------------------------------------------------
-- Corre después de fin_a_validar (que ya puso los libros y no deja pasar un
-- reenvío idéntico): lo ya guardado nunca se rechaza por esta regla.
create function public.fin_movimientos_representado()
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
  if nullif(btrim(new.motivo), '') is null then
    raise exception using errcode = '23514',
      message = 'Todo movimiento del libro de una persona representada lleva motivo.';
  end if;
  return new;
end
$$;
create trigger fin_b_representado before insert on public.fin_movimientos
  for each row execute function public.fin_movimientos_representado();

-- Salida del libro de papá hacia un libro personal: entrada propia en la
-- bitácora, a la vista de quienes llevan el libro (el aviso al suplente se hará
-- con las notificaciones de la Fase 2).
create function public.fin_movimientos_salida_representado()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.libro_origen_id is not null and new.libro_destino_id is not null
     and exists (select 1 from public.fin_libros o where o.id = new.libro_origen_id and o.tipo = 'representado')
     and exists (select 1 from public.fin_libros d where d.id = new.libro_destino_id and d.tipo = 'personal') then
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
create trigger fin_y_salida_representado after insert on public.fin_movimientos
  for each row execute function public.fin_movimientos_salida_representado();

-- -----------------------------------------------------------------------------
-- 9. Privilegios de las funciones nuevas
-- -----------------------------------------------------------------------------
-- Ninguna es para la app: las ejecutan otras funciones y triggers del servidor.
revoke execute on function
  public.fin_vigencia_consulta_maestra(), public.fin_adulto_con_finanzas(uuid, uuid),
  public.fin_libro_miembros_proteger(), public.fin_movimientos_representado(),
  public.fin_movimientos_salida_representado()
  from public, anon, authenticated, service_role;
