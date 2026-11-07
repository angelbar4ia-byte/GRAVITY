-- =============================================================================
-- GRAVITY · Fase 4 · Vista temporal de Finanzas de Papá para el familiar (D24)
-- =============================================================================
-- Especificación: docs/specs/fase-4-vista-temporal.md. Excepción a D5 solo en este punto:
-- el familiar NO tiene acceso permanente al dinero; PIDE la vista y el dueño del hogar la
-- autoriza por 30 minutos. Pasado ese tiempo el servidor vuelve a negar las lecturas.
--
-- CONTRATO DE SERVIDOR (lo usan app, plataforma y asistente; no cambiarlo sin avisar):
--   Tabla public.fin_vistas_solicitadas  (solo cambia por RPC; nadie escribe directo)
--     id, hogar_id, solicitante_id (el familiar), libro_persona_id (Papá: titular del libro
--     representado), motivo (3 caracteres visibles, fin_motivo_valido), estado
--     ('pendiente' | 'autorizada' | 'rechazada' | 'cancelada' | 'vencida'),
--     autorizada_por (el dueño; nulo si no), vigente_hasta (now() + 30 min exactos al
--     autorizar), creado_en, cambiado_en.
--     Lectura: el solicitante ve las suyas; el dueño del hogar las del hogar.
--   fin_pedir_vista_papa(p_motivo text) returns uuid      Solo el familiar vigente. Crea la
--     solicitud pendiente y avisa al dueño (tipo 'solicitud_vista', severidad crítica, sin
--     montos ni nombres). Una pendiente o autorizada vigente a la vez; 5 por 24 horas.
--   fin_responder_vista(p_solicitud uuid, p_accion text)  Solo el dueño del hogar:
--     'autorizar' | 'rechazar' (pendientes) y 'cancelar' (pendiente o autorizada vigente).
--   fin_vista_papa_vigente() returns boolean              Verdadero si la sesión es un
--     familiar con una autorizada cuyo vigente_hasta > now(). Es la verdad para la app.
--   fin_vistas_vencer(p_hogar uuid default null)          Marca 'vencida' lo que pasó de
--     tiempo (autorizadas con vigente_hasta pasado; pendientes de más de 24 horas). Solo
--     service_role / pg_cron (cada 5 minutos). La lectura NO depende de esta marca: la RLS
--     compara vigente_hasta con now() en cada consulta.
--   Lectura con vista vigente: libro de Papá (fin_puede(libro, 'leer')) y, por tanto, todas
--     las tablas fin_* de ese libro; más categorías y cuentas de gasto del hogar (solo
--     nombres) para poder mostrar la vista. Nunca escritura.
--   Bitácora: cada alta y cada cambio de estado quedan por el trigger automático, SIN el
--     motivo, sin montos ni cuentas (solo quién, cuándo y el estado). Las escribe el
--     servidor: no cuentan en el tope de 500 entradas por 24 horas de la app.
--
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabla
-- -----------------------------------------------------------------------------
create table public.fin_vistas_solicitadas (
  id               uuid primary key default gen_random_uuid(),
  hogar_id         uuid not null references public.hogares (id),
  solicitante_id   uuid not null references public.personas (id),
  libro_persona_id uuid not null references public.personas (id),
  motivo           text not null check (char_length(motivo) <= 200 and public.fin_motivo_valido(motivo)),
  estado           text not null default 'pendiente'
                   check (estado in ('pendiente', 'autorizada', 'rechazada', 'cancelada', 'vencida')),
  autorizada_por   uuid references public.personas (id),
  vigente_hasta    timestamptz,
  creado_en        timestamptz not null default now(),
  cambiado_en      timestamptz not null default now(),
  constraint fin_vistas_distintas check (solicitante_id <> libro_persona_id),
  constraint fin_vistas_coherente check (
    case estado
      when 'autorizada' then autorizada_por is not null and vigente_hasta is not null
      when 'pendiente'  then autorizada_por is null and vigente_hasta is null
      when 'rechazada'  then vigente_hasta is null
      else true end)
);
create index fin_vistas_solicitante_idx on public.fin_vistas_solicitadas (solicitante_id, creado_en desc);
create index fin_vistas_hogar_idx on public.fin_vistas_solicitadas (hogar_id, estado);
create unique index fin_vistas_una_pendiente on public.fin_vistas_solicitadas (solicitante_id)
  where estado = 'pendiente';
comment on table public.fin_vistas_solicitadas is
  'D24. Solicitudes del familiar para ver Finanzas de Papá. Solo cambia por fin_pedir_vista_papa / fin_responder_vista. '
  'La autorización dura 30 minutos (vigente_hasta). Sin montos ni cuentas. Cada cambio queda en la bitácora sin el motivo.';

-- Un estado final no se reabre; solo una autorizada pasa a cancelada o vencida.
create function public.fin_vistas_transicion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.estado is distinct from old.estado and not (
       (old.estado = 'pendiente'  and new.estado in ('autorizada', 'rechazada', 'cancelada', 'vencida'))
    or (old.estado = 'autorizada' and new.estado in ('cancelada', 'vencida'))) then
    raise exception using errcode = '23514', message = 'Esa solicitud ya no admite ese cambio.';
  end if;
  if new.id <> old.id or new.hogar_id <> old.hogar_id or new.solicitante_id <> old.solicitante_id
     or new.libro_persona_id <> old.libro_persona_id or new.motivo <> old.motivo or new.creado_en <> old.creado_en then
    raise exception using errcode = '23514', message = 'La solicitud solo cambia de estado.';
  end if;
  return new;
end
$$;
create trigger fin_vistas_a_transicion before update on public.fin_vistas_solicitadas
  for each row execute function public.fin_vistas_transicion();
create function public.fin_vistas_sin_borrar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '23514', message = 'Las solicitudes de vista no se borran.';
end
$$;
create trigger fin_vistas_a_sin_borrar before delete on public.fin_vistas_solicitadas
  for each row execute function public.fin_vistas_sin_borrar();
create trigger fin_vistas_a_sin_truncar before truncate on public.fin_vistas_solicitadas
  for each statement execute function public.fin_vistas_sin_borrar();

-- Bitácora automática SIN el motivo (quién, cuándo y estado; ni montos ni cuentas).
create trigger fin_z_bitacora after insert or update on public.fin_vistas_solicitadas
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'motivo');

alter table public.fin_vistas_solicitadas enable row level security;
create policy fin_vistas_leer on public.fin_vistas_solicitadas for select to authenticated
  using (solicitante_id = (select public.persona_actual())
         or public.rol_en_hogar(hogar_id) = 'dueno');
revoke all on table public.fin_vistas_solicitadas from public, anon, authenticated, service_role;
grant select on public.fin_vistas_solicitadas to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Aviso al dueño (catálogo cerrado, D20): tipo nuevo, sin texto libre
-- -----------------------------------------------------------------------------
alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista'));
alter table public.avisos drop constraint avisos_objeto_tipo_check;
alter table public.avisos add constraint avisos_objeto_tipo_check check (objeto_tipo in (
  'deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'solicitud_vista'));

-- Crítica: no se agrupa por el tope diario y la autorización dura solo 30 minutos.
create or replace function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90', 'solicitud_vista') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80')
      then 'importante'
    else 'informativa' end
$$;

-- -----------------------------------------------------------------------------
-- 3. Vigencia: ¿hay una vista autorizada y en tiempo? (para la RLS y para la app)
-- -----------------------------------------------------------------------------
create function public.fin_vista_papa_vigente()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.fin_vistas_solicitadas s
    where s.solicitante_id = public.persona_actual()
      and s.estado = 'autorizada'
      and s.vigente_hasta > now()
      and public.rol_en_hogar(s.hogar_id) = 'familiar')
$$;
comment on function public.fin_vista_papa_vigente() is
  'D24. Verdadero si la sesión es un familiar del hogar con una vista autorizada cuyo vigente_hasta aún no llega.';

create function public.fin_vista_vigente_hogar(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.fin_vistas_solicitadas s
    where s.hogar_id = p_hogar_id
      and s.solicitante_id = public.persona_actual()
      and s.estado = 'autorizada'
      and s.vigente_hasta > now()
      and public.rol_en_hogar(p_hogar_id) = 'familiar')
$$;
comment on function public.fin_vista_vigente_hogar(uuid) is
  'D24. Como fin_vista_papa_vigente(), para un hogar. Lo usan las políticas de lectura de categorías y cuentas de gasto.';

create function public.fin_vista_vigente_libro(p_libro_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.fin_libros l
    join public.fin_vistas_solicitadas s
      on s.hogar_id = l.hogar_id and s.libro_persona_id = l.titular_id
    where l.id = p_libro_id and l.tipo = 'representado'
      and s.solicitante_id = public.persona_actual()
      and s.estado = 'autorizada'
      and s.vigente_hasta > now()
      and public.rol_en_hogar(l.hogar_id) = 'familiar')
$$;
comment on function public.fin_vista_vigente_libro(uuid) is
  'D24. Verdadero si la sesión (familiar) tiene una vista vigente sobre ese libro representado.';

-- -----------------------------------------------------------------------------
-- 4. fin_puede(): el familiar LEE el libro de papá solo con vista vigente
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
    -- D24: el familiar lee el libro de papá SOLO con una vista autorizada y vigente (30 minutos).
    if v_libro.tipo = 'representado' and public.fin_vista_vigente_libro(p_libro_id) then
      return true;
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
  'D19 + D24. leer: miembro vigente; la cuenta maestra con una consulta registrada en ese libro en los últimos 30 '
  'minutos (I2); en un compartido PÚBLICO, todo adulto con Finanzas del hogar; y, en el libro de papá, el familiar '
  'con una vista autorizada y vigente (fin_vistas_solicitadas, 30 minutos). escribir: titular, miembro o '
  'albacea (el suplente solo sin albacea vigente), con el libro activo. administrar: titular de un personal, '
  'miembro de un compartido, albacea de un representado. Siempre exige un rol con Finanzas, salvo la vista D24 (solo leer).';

-- Nombres de categorías y cuentas de gasto del hogar (sin saldos) para pintar la vista.
drop policy fin_categorias_leer on public.fin_categorias;
create policy fin_categorias_leer on public.fin_categorias for select to authenticated
  using (public.fin_puede_hogar(hogar_id, 'leer') or public.fin_vista_vigente_hogar(hogar_id));
drop policy fin_cuentas_leer on public.fin_cuentas;
create policy fin_cuentas_leer on public.fin_cuentas for select to authenticated
  using (case when libro_id is null then (public.fin_puede_hogar(hogar_id, 'leer') or public.fin_vista_vigente_hogar(hogar_id))
              else public.fin_puede(libro_id, 'leer') end);

-- -----------------------------------------------------------------------------
-- 5. Vencimiento
-- -----------------------------------------------------------------------------
create function public.fin_vistas_vencer(p_hogar_id uuid default null)
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  with v as (
    update public.fin_vistas_solicitadas s
       set estado = 'vencida', cambiado_en = now()
     where (p_hogar_id is null or s.hogar_id = p_hogar_id)
       and ((s.estado = 'autorizada' and s.vigente_hasta <= now())
         or (s.estado = 'pendiente' and s.creado_en <= now() - interval '24 hours'))
    returning 1)
  select count(*)::integer into v_n from v;
  return v_n;
end
$$;
comment on function public.fin_vistas_vencer(uuid) is
  'Marca como vencida la autorizada pasada de tiempo y la pendiente de más de 24 horas. Solo servidor (pg_cron cada 5 min). '
  'La lectura no depende de esta marca: la RLS compara vigente_hasta con now().';

-- -----------------------------------------------------------------------------
-- 6. RPC: pedir y responder
-- -----------------------------------------------------------------------------
create function public.fin_pedir_vista_papa(p_motivo text)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_hogar   uuid;
  v_libro   public.fin_libros%rowtype;
  v_dueno   uuid;
  v_id      uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Necesitas iniciar sesión.';
  end if;
  select m.hogar_id into v_hogar
  from public.membresias m
  where m.persona_id = v_persona and m.rol = 'familiar' and m.activa
    and m.desde <= now() and (m.hasta is null or m.hasta > now())
  order by m.desde desc
  limit 1;
  if v_hogar is null then
    raise exception using errcode = '42501', message = 'Solo el familiar del hogar puede pedir esta vista.';
  end if;
  if not public.fin_motivo_valido(p_motivo) or char_length(p_motivo) > 200 then
    raise exception using errcode = '22023',
      message = 'El motivo necesita al menos 3 caracteres visibles (máximo 200).';
  end if;
  select * into v_libro from public.fin_libros l
   where l.hogar_id = v_hogar and l.tipo = 'representado' and l.titular_id is not null
   order by l.creado_en limit 1;
  if not found then
    raise exception using errcode = '22023', message = 'El hogar no tiene libro de Papá.';
  end if;
  perform public.fin_vistas_vencer(v_hogar);
  if exists (select 1 from public.fin_vistas_solicitadas s
              where s.solicitante_id = v_persona and s.estado in ('pendiente', 'autorizada')) then
    raise exception using errcode = '22023', message = 'Ya tienes una solicitud pendiente o una vista vigente.';
  end if;
  if (select count(*) from public.fin_vistas_solicitadas s
       where s.solicitante_id = v_persona and s.creado_en > now() - interval '24 hours') >= 5 then
    raise exception using errcode = '22023', message = 'Se llegó al tope de 5 solicitudes en 24 horas.';
  end if;
  select m.persona_id into v_dueno
  from public.membresias m
  where m.hogar_id = v_hogar and m.rol = 'dueno' and m.activa
    and m.desde <= now() and (m.hasta is null or m.hasta > now())
  order by m.desde limit 1;
  if v_dueno is null then
    raise exception using errcode = '22023', message = 'El hogar no tiene dueño vigente.';
  end if;
  insert into public.fin_vistas_solicitadas (hogar_id, solicitante_id, libro_persona_id, motivo)
  values (v_hogar, v_persona, v_libro.titular_id, btrim(p_motivo))
  returning id into v_id;
  -- Catálogo cerrado: el aviso no lleva texto, montos ni nombres; solo tipo, libro y solicitud.
  perform public.avisos_insertar(v_hogar, v_dueno, 'finanzas', 'solicitud_vista', v_libro.id, 'solicitud_vista', v_id,
                                 'solicitud_vista:' || v_id::text, now(), v_persona);
  return v_id;
end
$$;
comment on function public.fin_pedir_vista_papa(text) is
  'D24. El familiar pide ver Finanzas de Papá. Crea la solicitud pendiente y avisa al dueño (tipo solicitud_vista, sin '
  'montos ni nombres). Una pendiente o vigente a la vez; 5 por 24 horas (22023). Solo el familiar (42501).';

create function public.fin_responder_vista(p_solicitud uuid, p_accion text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_s       public.fin_vistas_solicitadas%rowtype;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Necesitas iniciar sesión.';
  end if;
  if p_accion is null or p_accion not in ('autorizar', 'rechazar', 'cancelar') then
    raise exception using errcode = '22023', message = 'La acción es autorizar, rechazar o cancelar.';
  end if;
  select * into v_s from public.fin_vistas_solicitadas s where s.id = p_solicitud for update;
  if not found or public.rol_en_hogar(v_s.hogar_id) is distinct from 'dueno' then
    raise exception using errcode = '42501', message = 'Solo el dueño del hogar responde las solicitudes.';
  end if;
  -- Lo que ya pasó de tiempo se marca antes de decidir.
  perform public.fin_vistas_vencer(v_s.hogar_id);
  select * into v_s from public.fin_vistas_solicitadas s where s.id = p_solicitud;
  if v_s.estado = 'vencida' then
    if p_accion = 'cancelar' then
      return;  -- ya venció: no hay nada que cancelar
    end if;
    raise exception using errcode = '22023', message = 'La solicitud ya venció.';
  end if;
  if p_accion in ('autorizar', 'rechazar') and v_s.estado <> 'pendiente' then
    raise exception using errcode = '22023', message = 'La solicitud ya no está pendiente.';
  end if;
  if p_accion = 'cancelar' and v_s.estado not in ('pendiente', 'autorizada') then
    raise exception using errcode = '22023', message = 'La solicitud ya no se puede cancelar.';
  end if;
  if p_accion = 'autorizar' then
    update public.fin_vistas_solicitadas
       set estado = 'autorizada', autorizada_por = v_persona,
           vigente_hasta = now() + interval '30 minutes', cambiado_en = now()
     where id = p_solicitud;
  else
    update public.fin_vistas_solicitadas
       set estado = case p_accion when 'rechazar' then 'rechazada' else 'cancelada' end, cambiado_en = now()
     where id = p_solicitud;
  end if;
  -- El aviso del dueño ya está atendido.
  update public.avisos a set estado = 'resuelta', resuelta_en = now()
   where a.objeto_tipo = 'solicitud_vista' and a.objeto_id = p_solicitud
     and a.estado in ('pendiente', 'enviada', 'agrupada', 'pospuesta', 'leida');
end
$$;
comment on function public.fin_responder_vista(uuid, text) is
  'D24. Solo el dueño del hogar. autorizar: pendiente -> autorizada con vigente_hasta = now() + 30 minutos. rechazar: '
  'pendiente -> rechazada. cancelar: pendiente o autorizada vigente -> cancelada (la lectura se corta al instante). '
  'Cualquier otro estado lanza 22023; no dueño, 42501.';

-- -----------------------------------------------------------------------------
-- 7. Privilegios y tarea programada
-- -----------------------------------------------------------------------------
revoke execute on function
  public.fin_vistas_transicion(), public.fin_vistas_sin_borrar(),
  public.fin_vista_papa_vigente(), public.fin_vista_vigente_hogar(uuid), public.fin_vista_vigente_libro(uuid),
  public.fin_vistas_vencer(uuid), public.fin_pedir_vista_papa(text), public.fin_responder_vista(uuid, text)
  from public, anon, authenticated, service_role;
-- La app y las políticas de lectura (se evalúan con los privilegios de quien consulta).
grant execute on function
  public.fin_vista_papa_vigente(), public.fin_vista_vigente_hogar(uuid), public.fin_vista_vigente_libro(uuid),
  public.fin_pedir_vista_papa(text), public.fin_responder_vista(uuid, text)
  to authenticated;
grant execute on function public.fin_vistas_vencer(uuid) to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('fin-vistas-vencer', '*/5 * * * *', 'select public.fin_vistas_vencer()');
  end if;
end
$$;
