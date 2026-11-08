-- =============================================================================
-- GRAVITY · Finanzas · Ampliaciones bloque 1 v1.2 (docs/specs/fase-8-finanzas-ampliaciones.md, 1b y 2)
-- Transferencia a la casa a una subcuenta, referencia por subcuenta y aviso al receptor.
-- =============================================================================
-- * Transferencias a la casa (dueno_a_casa, pareja_a_casa): la persona elige la SUBCUENTA (servicio) destino con
--   p_subcuenta, obligatoria en esas rutas y nula en pareja_a_dueno. Sin subcuenta activa de la casa del hogar: 22023.
--   La subcuenta queda en fin_transferencias.subcuenta_id y, al confirmar, el movimiento resultante cuenta como
--   aportado a ESA subcuenta (el dinero entra a la cuenta de dinero de la casa que elige el receptor, como antes).
--   Las filas anteriores a esta migración conservan subcuenta_id nulo (restricción NOT VALID).
-- * Referencia por subcuenta: fin_casa_referencias.subcuenta_id nulo = reparto GENERAL (50/25/25 por omisión);
--   con valor = reparto propio de esa subcuenta (la suma por subcuenta no pasa de 10000). Si una subcuenta tiene
--   reparto propio, solo ese reparto aplica a ese servicio. Se fija con fin_casa_fijar_referencia (solo el dueño);
--   la escritura directa de la tabla queda solo para el reparto general.
-- * fin_casa_aportacion devuelve, además de una fila por persona (subcuenta_id nulo: parte general y totales), una
--   fila por persona y subcuenta con reparto propio.
-- * Aviso 'transferencia_pendiente' (importante) al receptor al proponer; sin monto ni nota (D3, D20). Se cierra al
--   responder (resuelta) o al cancelar quien propuso (cancelada).
-- Migración hacia adelante. Sin secretos.
-- =============================================================================

-- 1. Avisos: tipo y objeto nuevos (mismo patrón que 20261124 y 20261128) ------------------------------------------
alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados', 'recordatorio_toma',
  'compra_papa_albacea', 'votacion_abierta', 'votacion_empate', 'reposicion_suplemento',
  'transferencia_pendiente'));

alter table public.avisos drop constraint avisos_objeto_tipo_check;
alter table public.avisos add constraint avisos_objeto_tipo_check check (objeto_tipo in (
  'deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'solicitud_vista', 'cambio_urgente', 'toma',
  'solicitud_pago', 'votacion', 'reposicion', 'transferencia'));

create or replace function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90', 'solicitud_vista', 'cambio_urgente_cuidados') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80',
                    'recordatorio_toma', 'compra_papa_albacea', 'reposicion_suplemento', 'transferencia_pendiente')
      then 'importante'
    else 'informativa' end
$$;

-- 2. Transferencias: subcuenta destino --------------------------------------------------------------------------------
alter table public.fin_transferencias add column subcuenta_id uuid;
alter table public.fin_transferencias add constraint fin_transferencias_subcuenta_fk
  foreign key (hogar_id, subcuenta_id) references public.fin_casa_subcuentas (hogar_id, id);
alter table public.fin_transferencias add constraint fin_transferencias_subcuenta_ruta
  check ((ruta = 'pareja_a_dueno' and subcuenta_id is null) or (ruta <> 'pareja_a_dueno' and subcuenta_id is not null))
  not valid;
create index fin_transferencias_subcuenta_idx on public.fin_transferencias (subcuenta_id) where subcuenta_id is not null;
comment on column public.fin_transferencias.subcuenta_id is
  'Subcuenta (servicio) de la casa a la que va la transferencia: obligatoria en dueno_a_casa y pareja_a_casa, nula en pareja_a_dueno.';

-- 3. Referencia por subcuenta -----------------------------------------------------------------------------------------
alter table public.fin_casa_referencias add column subcuenta_id uuid;
alter table public.fin_casa_referencias add constraint fin_casa_referencias_subcuenta_fk
  foreign key (hogar_id, subcuenta_id) references public.fin_casa_subcuentas (hogar_id, id);
alter table public.fin_casa_referencias drop constraint fin_casa_referencias_unica;
create unique index fin_casa_referencias_general_unica on public.fin_casa_referencias (hogar_id, persona_id)
  where subcuenta_id is null;
create unique index fin_casa_referencias_subcuenta_unica on public.fin_casa_referencias (subcuenta_id, persona_id)
  where subcuenta_id is not null;
comment on column public.fin_casa_referencias.subcuenta_id is
  'Nulo = reparto general del hogar (50/25/25 por omisión). Con valor = reparto propio de esa subcuenta; si la '
  'subcuenta tiene alguno, ese reparto reemplaza al general en ese servicio. La suma por subcuenta no pasa de 10000.';
comment on table public.fin_casa_referencias is
  'Parte de REFERENCIA de cada persona en la aportación a la casa, en puntos base (5000 = 50 %), general (subcuenta_id '
  'nulo; por omisión Papá 5000, dueño y pareja 2500) o propia de una subcuenta. Es una referencia, no una obligación '
  'ni una deuda. La suma por reparto (general o de una subcuenta) no pasa de 10000.';

create or replace function public.fin_casa_referencias_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_casa  uuid := public.fin_casa_libro(new.hogar_id);
  v_rol   text;
  v_otras bigint;
begin
  if v_casa is null then
    raise exception using errcode = '22023', message = 'La casa aún no tiene su libro configurado.';
  end if;
  new.libro_id := v_casa;
  if new.subcuenta_id is not null and not exists (
      select 1 from public.fin_casa_subcuentas s
      where s.id = new.subcuenta_id and s.hogar_id = new.hogar_id and s.libro_id = v_casa) then
    raise exception using errcode = '22023', message = 'La subcuenta no es de la casa de este hogar.';
  end if;
  v_rol := public.fin_rol_de(new.hogar_id, new.persona_id);
  if not (
       exists (select 1 from public.fin_libros l
               where l.hogar_id = new.hogar_id and l.tipo = 'representado' and l.titular_id = new.persona_id)
       or (v_rol in ('dueno', 'coadministrador')
           and exists (select 1 from public.fin_libros l
                       where l.hogar_id = new.hogar_id and l.tipo = 'personal' and l.titular_id = new.persona_id))) then
    raise exception using errcode = '22023',
      message = 'La referencia es de Papá, del dueño o de la pareja del hogar.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('fin_casa_referencias:' || new.hogar_id::text, 0));
  select coalesce(sum(r.parte_pb), 0) into v_otras
  from public.fin_casa_referencias r
  where r.hogar_id = new.hogar_id and r.persona_id <> new.persona_id
    and r.subcuenta_id is not distinct from new.subcuenta_id;
  if v_otras + new.parte_pb > 10000 then
    raise exception using errcode = '23514', message = 'Las partes de referencia no pasan de 100 %.';
  end if;
  new.actualizado_por := public.persona_actual();
  new.actualizado_en := now();
  return new;
end
$$;

drop trigger fin_a_columnas_fijas on public.fin_casa_referencias;
create trigger fin_a_columnas_fijas before update on public.fin_casa_referencias
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'persona_id', 'subcuenta_id');

-- La escritura directa solo toca el reparto general; el de una subcuenta va por fin_casa_fijar_referencia.
drop policy fin_casa_referencias_agregar on public.fin_casa_referencias;
drop policy fin_casa_referencias_editar on public.fin_casa_referencias;
create policy fin_casa_referencias_agregar on public.fin_casa_referencias for insert to authenticated
  with check (subcuenta_id is null and public.fin_puede(libro_id, 'administrar'));
create policy fin_casa_referencias_editar on public.fin_casa_referencias for update to authenticated
  using (subcuenta_id is null and public.fin_puede(libro_id, 'administrar'))
  with check (subcuenta_id is null and public.fin_puede(libro_id, 'administrar'));

-- Solo el dueño fija la referencia (de una subcuenta, o la general con p_subcuenta nulo).
create function public.fin_casa_fijar_referencia(p_subcuenta uuid, p_persona uuid, p_partes_pb int)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo     uuid := public.persona_actual();
  v_hogar  uuid;
  v_casa   uuid;
begin
  if v_yo is null then
    raise exception using errcode = '42501', message = 'Sin sesión.';
  end if;
  if p_persona is null or p_partes_pb is null or p_partes_pb not between 0 and 10000 then
    raise exception using errcode = '22023', message = 'La parte es de 0 a 10000 puntos base.';
  end if;
  if p_subcuenta is null then
    select h.hogar_id into v_hogar from public.membresias h
     where h.persona_id = v_yo and h.activa and h.rol = 'dueno' and h.desde <= now() and (h.hasta is null or h.hasta > now())
     limit 1;
  else
    select s.hogar_id into v_hogar from public.fin_casa_subcuentas s where s.id = p_subcuenta;
  end if;
  if v_hogar is null or public.fin_rol_de(v_hogar, v_yo) is distinct from 'dueno' then
    raise exception using errcode = '42501', message = 'Solo el dueño fija la referencia.';
  end if;
  v_casa := public.fin_casa_libro(v_hogar);
  if v_casa is null or not public.fin_puede(v_casa, 'administrar') then
    raise exception using errcode = '42501', message = 'Solo el dueño fija la referencia.';
  end if;
  -- El validador (trigger) pone el libro, comprueba a la persona y la suma por reparto.
  update public.fin_casa_referencias r set parte_pb = p_partes_pb
   where r.hogar_id = v_hogar and r.persona_id = p_persona and r.subcuenta_id is not distinct from p_subcuenta;
  if not found then
    insert into public.fin_casa_referencias (hogar_id, libro_id, persona_id, subcuenta_id, parte_pb)
    values (v_hogar, v_casa, p_persona, p_subcuenta, p_partes_pb);
  end if;
end
$$;
comment on function public.fin_casa_fijar_referencia(uuid, uuid, int) is
  'Solo el dueño. Fija la parte de referencia (puntos base) de una persona en una subcuenta de la casa; con '
  'p_subcuenta nulo, en el reparto general. La suma por reparto no pasa de 10000 (23514). Es una referencia, no una deuda.';

-- 4. Proponer: subcuenta destino + aviso al receptor ------------------------------------------------------------------
drop function public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text);
create function public.fin_proponer_transferencia(
  p_id uuid, p_cuenta_origen uuid, p_destino_persona uuid, p_monto_centavos bigint,
  p_fecha date default current_date, p_nota text default null, p_subcuenta uuid default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo      uuid := public.persona_actual();
  v_cuenta  public.fin_cuentas%rowtype;
  v_libro   public.fin_libros%rowtype;
  v_rol     text;
  v_rol_d   text;
  v_ruta    text;
  v_ldest   uuid;
  v_previa  public.fin_transferencias%rowtype;
  r         record;
begin
  if v_yo is null then
    raise exception using errcode = '42501', message = 'Sin sesión.';
  end if;
  if p_id is null or p_cuenta_origen is null or p_monto_centavos is null or p_monto_centavos <= 0 then
    raise exception using errcode = '22023', message = 'La transferencia lleva identificador, cuenta y un monto mayor a cero (centavos).';
  end if;
  if p_nota is not null and char_length(p_nota) > 200 then
    raise exception using errcode = '22023', message = 'La nota no pasa de 200 caracteres.';
  end if;
  select * into v_cuenta from public.fin_cuentas c where c.id = p_cuenta_origen;
  if not found or v_cuenta.libro_id is null then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esa cuenta.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = v_cuenta.libro_id;
  if v_libro.tipo <> 'personal' or v_libro.titular_id is distinct from v_yo
     or not public.fin_puede(v_libro.id, 'escribir') then
    raise exception using errcode = '42501',
      message = 'Solo propones transferencias desde tu propio libro personal.';
  end if;
  if v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'La cuenta de origen es una cuenta de dinero activa.';
  end if;

  v_rol := public.fin_rol_de(v_libro.hogar_id, v_yo);
  if p_destino_persona is null then
    v_ldest := public.fin_casa_libro(v_libro.hogar_id);
    if v_ldest is null then
      raise exception using errcode = '22023', message = 'La casa aún no tiene su cuenta general configurada.';
    end if;
    v_ruta := case v_rol when 'dueno' then 'dueno_a_casa' when 'coadministrador' then 'pareja_a_casa' end;
  else
    v_rol_d := public.fin_rol_de(v_libro.hogar_id, p_destino_persona);
    if p_destino_persona <> v_yo and v_rol = 'coadministrador' and v_rol_d = 'dueno' then
      v_ruta := 'pareja_a_dueno';
      v_ldest := (select l.id from public.fin_libros l
                  where l.hogar_id = v_libro.hogar_id and l.tipo = 'personal' and l.titular_id = p_destino_persona);
    end if;
  end if;
  if v_ruta is null or v_ldest is null then
    raise exception using errcode = '22023',
      message = 'Esa ruta no está permitida: solo pareja a dueño, dueño a casa y pareja a casa.';
  end if;

  -- La subcuenta: obligatoria a la casa, nula a una persona.
  if v_ruta = 'pareja_a_dueno' then
    if p_subcuenta is not null then
      raise exception using errcode = '22023', message = 'Una transferencia a una persona no lleva subcuenta.';
    end if;
  elsif p_subcuenta is null or not exists (
      select 1 from public.fin_casa_subcuentas s
      where s.id = p_subcuenta and s.hogar_id = v_libro.hogar_id and s.libro_id = v_ldest and s.activa) then
    raise exception using errcode = '22023',
      message = 'Elige una subcuenta activa de la casa del hogar para esa transferencia.';
  end if;

  select * into v_previa from public.fin_transferencias t where t.id = p_id;
  if found then
    if v_previa.persona_origen_id = v_yo and v_previa.cuenta_origen_id = p_cuenta_origen
       and v_previa.persona_destino_id is not distinct from p_destino_persona
       and v_previa.subcuenta_id is not distinct from p_subcuenta
       and v_previa.monto_centavos = p_monto_centavos and v_previa.fecha = p_fecha
       and v_previa.nota is not distinct from p_nota then
      return p_id;
    end if;
    raise exception using errcode = '23505', message = format('Ya existe la transferencia %s con otro contenido.', p_id);
  end if;

  insert into public.fin_transferencias (id, hogar_id, ruta, persona_origen_id, persona_destino_id,
    libro_origen_id, libro_destino_id, cuenta_origen_id, monto_centavos, fecha, nota, propuesta_por, subcuenta_id)
  values (p_id, v_libro.hogar_id, v_ruta, v_yo, p_destino_persona, v_libro.id, v_ldest, p_cuenta_origen,
          p_monto_centavos, p_fecha, p_nota, v_yo, p_subcuenta);

  -- Aviso al receptor (sin monto ni nota): la persona destino o, si recibe la casa, el otro adulto con Finanzas.
  for r in
    select d.persona_id
      from public.ali_destinatarios_cuentas(v_libro.hogar_id, false) d
     where d.persona_id <> v_yo
       and public.fin_destinatario_valido(v_libro.hogar_id, d.persona_id)
       and (p_destino_persona is null or d.persona_id = p_destino_persona)
  loop
    perform public.avisos_insertar(v_libro.hogar_id, r.persona_id, 'finanzas', 'transferencia_pendiente', v_ldest,
                                   'transferencia', p_id, 'transferencia:' || p_id::text, now(), v_yo, now());
  end loop;
  return p_id;
end
$$;
comment on function public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text, uuid) is
  'Propone una transferencia desde tu libro personal: a la persona dueña (si eres la pareja; p_subcuenta nulo) o, '
  'con p_destino_persona nulo, a una SUBCUENTA activa de la casa (p_subcuenta obligatoria; 22023 si falta o no es de '
  'la casa). Queda pendiente: sin confirmación no hay movimiento. Avisa al receptor (transferencia_pendiente, sin monto).';

-- Al responder o cancelar, el aviso se cierra.
create function public.fin_aviso_transferencia_cerrada()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.avisos a
     set estado = case when new.estado = 'cancelada' then 'cancelada' else 'resuelta' end,
         resuelta_en = case when new.estado = 'cancelada' then a.resuelta_en else now() end
   where a.tipo = 'transferencia_pendiente' and a.objeto_id = new.id
     and a.estado in ('pendiente', 'enviada', 'agrupada', 'pospuesta', 'leida');
  return null;
end
$$;
create trigger fin_transferencias_aviso_cerrar after update of estado on public.fin_transferencias
  for each row when (old.estado = 'pendiente' and new.estado <> 'pendiente')
  execute function public.fin_aviso_transferencia_cerrada();

-- 5. Aportación: referencia por subcuenta -----------------------------------------------------------------------------
drop function public.fin_casa_aportacion(uuid, date);
create function public.fin_casa_aportacion(p_hogar_id uuid, p_fecha date default current_date)
returns table (persona_id uuid, parte_pb integer, referencia_centavos bigint, aportado_centavos bigint,
               desde date, hasta date, vence_antes_de date, subcuenta_id uuid)
language plpgsql stable security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_casa    uuid := public.fin_casa_libro(p_hogar_id);
  v_periodo text;
  v_desde   date;
  v_hasta   date;
  v_meses   numeric;
  v_vence   date;
begin
  if v_casa is null or not public.fin_puede(v_casa, 'leer') then
    raise exception using errcode = '42501', message = 'Sin permiso para ver la casa.';
  end if;
  select c.periodo into v_periodo from public.fin_casa_config c where c.hogar_id = p_hogar_id;
  select r.desde, r.hasta into v_desde, v_hasta from public.fin_periodo_rango(v_periodo, p_fecha) r;
  v_meses := case v_periodo when 'semana' then 12.0 / 52 when 'mes' then 1 when 'bimestre' then 2
                            when 'semestre' then 6 else 12 end;
  select min(s.proximo_vencimiento) into v_vence
    from public.fin_casa_subcuentas s
   where s.libro_id = v_casa and s.activa and s.proximo_vencimiento >= p_fecha;
  return query
  with personas as (
    select distinct r.persona_id from public.fin_casa_referencias r where r.hogar_id = p_hogar_id
  ),
  subs as (
    select s.id, s.monto_estimado_centavos::numeric * v_meses / s.cada_meses as total,
           exists (select 1 from public.fin_casa_referencias x where x.subcuenta_id = s.id) as propia
      from public.fin_casa_subcuentas s
     where s.libro_id = v_casa and s.activa and s.monto_estimado_centavos is not null
  ),
  -- parte efectiva de cada persona en cada subcuenta: la propia si la subcuenta tiene reparto, si no la general
  efectiva as (
    select p.persona_id, s.id as sub_id, s.total, s.propia,
           coalesce(case when s.propia
                         then (select x.parte_pb from public.fin_casa_referencias x
                                where x.subcuenta_id = s.id and x.persona_id = p.persona_id)
                         else (select x.parte_pb from public.fin_casa_referencias x
                                where x.hogar_id = p_hogar_id and x.subcuenta_id is null and x.persona_id = p.persona_id)
                    end, 0) as parte
      from personas p cross join subs s
  ),
  transf as (
    select m.id as mov_id, m.monto_centavos, lo.titular_id, t.subcuenta_id
      from public.fin_movimientos m
      join public.fin_libros lo on lo.id = m.libro_origen_id
      left join public.fin_transferencias t on t.movimiento_id = m.id
     where m.tipo = 'transferencia' and m.libro_destino_id = v_casa
       and lo.tipo in ('personal', 'representado')
       and m.fecha between v_desde and v_hasta
       and not exists (select 1 from public.fin_movimientos a where a.anula_a = m.id)
  ),
  pagos as (
    select a.monto_centavos, a.aportante_id, a.subcuenta_id
      from public.fin_casa_aportes a
     where a.libro_id = v_casa and a.suma_al_aportado and a.fecha between v_desde and v_hasta
       and not exists (select 1 from public.fin_movimientos x where x.anula_a = a.movimiento_id)
  )
  -- Una fila por persona (totales; parte_pb = reparto general).
  select p.persona_id,
         coalesce((select g.parte_pb from public.fin_casa_referencias g
                    where g.hogar_id = p_hogar_id and g.subcuenta_id is null and g.persona_id = p.persona_id), 0)::integer,
         round(coalesce((select sum(e.total * e.parte / 10000) from efectiva e where e.persona_id = p.persona_id), 0))::bigint,
         (coalesce((select sum(t.monto_centavos) from transf t where t.titular_id = p.persona_id), 0)
          + coalesce((select sum(g.monto_centavos) from pagos g where g.aportante_id = p.persona_id), 0))::bigint,
         v_desde, v_hasta, v_vence, null::uuid
    from personas p
  union all
  -- Una fila por persona en cada subcuenta con reparto propio.
  select e.persona_id, e.parte::integer, round(e.total * e.parte / 10000)::bigint,
         (coalesce((select sum(t.monto_centavos) from transf t where t.titular_id = e.persona_id and t.subcuenta_id = e.sub_id), 0)
          + coalesce((select sum(g.monto_centavos) from pagos g where g.aportante_id = e.persona_id and g.subcuenta_id = e.sub_id), 0))::bigint,
         v_desde, v_hasta,
         (select s.proximo_vencimiento from public.fin_casa_subcuentas s where s.id = e.sub_id and s.proximo_vencimiento >= p_fecha),
         e.sub_id
    from efectiva e
   where e.propia
  order by 1, 8 nulls first;
end
$$;
comment on function public.fin_casa_aportacion(uuid, date) is
  'Por persona, en el periodo configurado de la casa que contiene la fecha: parte de referencia, aportación de '
  'referencia (estimado de cada subcuenta × periodo × parte efectiva) y lo aportado (transferencias a la casa no '
  'anuladas + servicios pagados con su dinero). Fila con subcuenta_id nulo = totales de la persona (parte_pb general); '
  'filas con subcuenta_id = referencia y aportado de esa subcuenta cuando tiene reparto propio. Es una referencia: '
  'la aportación es libre y no hay deudores.';

-- 6. Privilegios -------------------------------------------------------------------------------------------------------
revoke execute on function
  public.fin_casa_fijar_referencia(uuid, uuid, int),
  public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text, uuid),
  public.fin_casa_aportacion(uuid, date),
  public.fin_aviso_transferencia_cerrada()
  from public, anon, authenticated, service_role;
grant execute on function
  public.fin_casa_fijar_referencia(uuid, uuid, int),
  public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text, uuid),
  public.fin_casa_aportacion(uuid, date)
  to authenticated;
