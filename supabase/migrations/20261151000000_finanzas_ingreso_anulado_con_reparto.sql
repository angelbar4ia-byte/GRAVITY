-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, paquete F8-6.9: ingreso anulado con reparto (hallazgo H-03 de docs/revisiones/finanzas-bloque-6.md)
-- (docs/specs/fase-8-finanzas-dispersion.md; decisión del dueño del 20/nov/2026: opción B con alternativa A; D3, D5, D6, D19, D20, D24)
-- =============================================================================
-- Problema: al anular un ingreso ya repartido, el reparto pasa a «anulada» (disparador de 20261147/20261149) pero los movimientos que
-- creó (abono extra y ahorro) siguen vigentes, y solo queda una entrada de bitácora: la persona no se entera.
--
-- Decisión del dueño: la app NO deshace nada sola al anular el ingreso; AVISA, y con un toque la persona puede DESHACER el reparto
-- (anular los movimientos que creó, con motivo y sin borrar historial) o DEJARLO ASÍ. Qué agrega esta migración:
--
-- 1. fin_repartos_anulados_con_movimientos(p_libro): RPC de LECTURA. Los repartos «anulada» cuyo ingreso está anulado y que todavía
--    tienen movimientos hijos vigentes, sin los que la persona ya decidió «dejar así». p_libro nulo = todos los libros que la persona
--    puede ver. Mismos permisos que el resto de la dispersión (fin_dispersion_puede_ver): familiar, cuidador, Casa, tablet pública y
--    vista temporal de Papá no; la cuenta maestra solo con consulta vigente; el libro de Papá, en nombre de él. Solo ids y un conteo.
-- 2. fin_deshacer_reparto_anulado(p_dispersion, p_motivo): RPC nueva (idempotente). DECISIÓN: no se extiende fin_deshacer_dispersion
--    porque ahí «anulada» significa «reintento: ya está deshecho» y devuelve sin tocar nada; cambiarlo alteraría un contrato probado
--    (120, secciones 4 y 10) y haría que un reintento viejo anulara dinero. La RPC nueva reutiliza el ayudante interno
--    fin_dispersion_anular_movimientos (contraasiento con la misma fecha y el motivo; ids estables). Exige escribir en el libro; en el
--    libro de Papá, en su nombre y con motivo (3 a 200 caracteres). Solo actúa sobre un reparto anulado cuyo ingreso está anulado:
--    no sirve para anular movimientos de otros repartos.
-- 3. fin_dejar_reparto_anulado(p_dispersion): RPC nueva (idempotente). Registra «dejarlo así» en fin_dispersion_descartes
--    (solo-agregar; no toca dinero). El aviso no vuelve a aparecer para ese reparto, en ningún dispositivo.
-- 4. Aviso nuevo en el catálogo cerrado, informativo y SIN cifras ni nombres (D20): ingreso_anulado_con_reparto, «Un ingreso anulado
--    tenía reparto». Se extienden igual que en 20261146 y 20261147: la restricción de tipo de la tabla avisos, avisos_tipo_emitible,
--    fin_dispersion_aviso_titulo, fin_emitir_aviso y avisos_actualizar_preferencias. La severidad es informativa (cae en el «else» de
--    avisos_severidad, que no cambia). Lo emite la app (que sabe qué repartos están así), con el ingreso por objeto.
-- Sin realtime en la tabla nueva (el conteo de disparadores de 20261148 es una invariante probada): otro dispositivo se entera de
-- «dejarlo así» en su próxima recarga; los movimientos anulados sí disparan Realtime (fin_movimientos).
-- Dinero en bigint de centavos. Migración hacia adelante. Sin secretos ni datos reales.
-- =============================================================================

-- 1. Decisiones «dejarlo así» (solo-agregar) --------------------------------------------------------------------------------
create table public.fin_dispersion_descartes (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  dispersion_id  uuid not null,
  decidido_por   uuid not null default public.persona_actual() references public.personas (id),
  decidido_en    timestamptz not null default now(),
  en_nombre_de   uuid references public.personas (id),
  constraint fin_dispersion_descartes_una_key unique (dispersion_id),
  constraint fin_dispersion_descartes_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_dispersion_descartes_dispersion_fk foreign key (libro_id, dispersion_id)
    references public.fin_dispersiones (libro_id, id)
);
comment on table public.fin_dispersion_descartes is
  'H-03. La persona vio que un ingreso anulado tenía reparto y decidió dejarlo así (sin deshacer sus movimientos). Solo-agregar; '
  'una fila por reparto. No mueve dinero. Escritura solo por fin_dejar_reparto_anulado.';
create trigger fin_solo_agregar before update or delete on public.fin_dispersion_descartes
  for each row execute function public.impedir_cambios_solo_agregar();
create trigger fin_sin_truncate before truncate on public.fin_dispersion_descartes
  for each statement execute function public.impedir_cambios_solo_agregar();
create trigger fin_z_bitacora after insert or update or delete on public.fin_dispersion_descartes
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
alter table public.fin_dispersion_descartes enable row level security;
create policy fin_dispersion_descartes_leer on public.fin_dispersion_descartes for select to authenticated
  using (public.fin_dispersion_puede_ver(libro_id));
revoke all on table public.fin_dispersion_descartes from public, anon, authenticated, service_role;
grant select on public.fin_dispersion_descartes to authenticated, service_role;
-- Sin grant de escritura: solo las RPC.

-- 2. Lectura: repartos anulados con movimientos todavía vigentes ---------------------------------------------------------------
create function public.fin_repartos_anulados_con_movimientos(p_libro uuid default null)
returns table (dispersion_id uuid, libro_id uuid, movimiento_id uuid, movimientos_vigentes integer)
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if public.persona_actual() is null or (p_libro is not null and not public.fin_dispersion_puede_ver(p_libro)) then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  return query
  select q.did, q.lid, q.mid, q.vivos
    from (
      select d.id as did, d.libro_id as lid, d.movimiento_id as mid,
             (select count(*)::integer from public.fin_dispersion_lineas l
               where l.dispersion_id = d.id and l.movimiento_id is not null
                 and not exists (select 1 from public.fin_movimientos a where a.anula_a = l.movimiento_id)) as vivos,
             d.creada_en as creada
        from public.fin_dispersiones d
       where d.estado = 'anulada'
         and (p_libro is null or d.libro_id = p_libro)
         and public.fin_dispersion_puede_ver(d.libro_id)
         -- el ingreso está anulado (así llegó el reparto a «anulada» con dinero vivo)
         and exists (select 1 from public.fin_movimientos a where a.anula_a = d.movimiento_id)
         and not exists (select 1 from public.fin_dispersion_descartes x where x.dispersion_id = d.id)) q
   where q.vivos > 0
   order by q.creada, q.did;
end
$$;
comment on function public.fin_repartos_anulados_con_movimientos(uuid) is
  'H-03. Repartos anulados (el ingreso se anuló) que aún tienen movimientos de abono extra o ahorro vigentes y que la persona no '
  'dejó así. Solo ids y cuántos movimientos. Mismos permisos que fin_ingresos_por_repartir (fin_dispersion_puede_ver); p_libro nulo = '
  'todos los libros visibles.';

-- 3. Deshacer los movimientos de un reparto anulado --------------------------------------------------------------------------
create function public.fin_deshacer_reparto_anulado(p_dispersion uuid, p_motivo text default null)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d      public.fin_dispersiones%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_motivo text := nullif(btrim(p_motivo), '');
  v_nombre uuid;
  v_n      integer;
begin
  select * into v_d from public.fin_dispersiones d where d.id = p_dispersion;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  v_libro := public.fin_dispersion_exigir(v_d.libro_id, 'escribir');
  if v_d.estado <> 'anulada' then
    raise exception using errcode = '55000',
      message = 'Solo se deshacen aquí los movimientos de un reparto anulado: usa «Deshacer reparto» del ingreso.';
  end if;
  if not exists (select 1 from public.fin_movimientos a where a.anula_a = v_d.movimiento_id) then
    raise exception using errcode = '55000', message = 'El ingreso de ese reparto no está anulado.';
  end if;
  if v_motivo is null and v_libro.tipo <> 'representado' then
    v_motivo := 'Reparto de un ingreso anulado, deshecho';
  end if;
  if not public.fin_motivo_valido(v_motivo) or char_length(v_motivo) > 200 then
    raise exception using errcode = '22023', message = 'El motivo necesita de 3 a 200 caracteres visibles.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, v_motivo, true);   -- en el libro de Papá: en su nombre y con motivo
  perform pg_advisory_xact_lock(hashtextextended('fin_dispersion:' || v_d.movimiento_id::text, 0));
  v_n := public.fin_dispersion_anular_movimientos(v_d.id, v_motivo);   -- idempotente: solo los que sigan vigentes
  if v_n > 0 then
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (v_d.hogar_id, public.persona_actual(), 'finanzas.dispersion_anulada_deshecha', 'fin_dispersiones', v_d.id::text,
            jsonb_strip_nulls(jsonb_build_object('libro_id', v_d.libro_id, 'movimiento_id', v_d.movimiento_id,
                                                 'movimientos_anulados', v_n, 'en_nombre_de', v_nombre, 'motivo', v_motivo)));
  end if;
  return jsonb_build_object('dispersion_id', v_d.id, 'movimientos_anulados', v_n);
end
$$;
comment on function public.fin_deshacer_reparto_anulado(uuid, text) is
  'H-03, alternativa A. Anula con contraasiento y motivo (misma fecha) los movimientos que creó un reparto anulado cuyo ingreso está '
  'anulado y que siguen vigentes. Idempotente (repetir anula 0). No extiende fin_deshacer_dispersion: ahí «anulada» es un reintento. '
  'escribir en el libro; en el de Papá, en su nombre y con motivo de 3 a 200 caracteres.';

-- 4. «Dejarlo así» ----------------------------------------------------------------------------------------------------------
create function public.fin_dejar_reparto_anulado(p_dispersion uuid)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d      public.fin_dispersiones%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_nombre uuid;
begin
  select * into v_d from public.fin_dispersiones d where d.id = p_dispersion;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  v_libro := public.fin_dispersion_exigir(v_d.libro_id, 'escribir');
  if v_d.estado <> 'anulada' then
    raise exception using errcode = '55000', message = 'Solo se puede dejar así un reparto anulado.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, null, false);
  insert into public.fin_dispersion_descartes (hogar_id, libro_id, dispersion_id, en_nombre_de)
  values (v_d.hogar_id, v_d.libro_id, v_d.id, v_nombre)
  on conflict (dispersion_id) do nothing;
  return jsonb_build_object('dispersion_id', v_d.id, 'dejado', true);
end
$$;
comment on function public.fin_dejar_reparto_anulado(uuid) is
  'H-03, opción B. La persona decide dejar así un reparto anulado con movimientos vigentes: no se toca dinero y el aviso no vuelve a '
  'salir. Idempotente. escribir en el libro.';

revoke all on function public.fin_repartos_anulados_con_movimientos(uuid), public.fin_deshacer_reparto_anulado(uuid, text),
  public.fin_dejar_reparto_anulado(uuid) from public, anon;
grant execute on function public.fin_repartos_anulados_con_movimientos(uuid), public.fin_deshacer_reparto_anulado(uuid, text),
  public.fin_dejar_reparto_anulado(uuid) to authenticated;

-- 5. Aviso (D20): catálogo cerrado, sin cifras ni nombres --------------------------------------------------------------------
alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados', 'recordatorio_toma',
  'compra_papa_albacea', 'votacion_abierta', 'votacion_empate', 'reposicion_suplemento',
  'transferencia_pendiente',
  'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala',
  'ingreso_por_repartir', 'ingreso_anulado_con_reparto'));

-- La calcula la app en el dispositivo y la emite con fin_emitir_aviso. Severidad: informativa (el «else» de avisos_severidad).
create or replace function public.avisos_tipo_emitible(p_tipo text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_tipo in ('protegido_riesgo', 'flujo_negativo', 'abono_bajo_minimo', 'partida_100', 'partida_80',
                    'fondo_bajo', 'uso_limite', 'aportacion_pendiente', 'conciliacion_pendiente',
                    'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala',
                    'ingreso_por_repartir', 'ingreso_anulado_con_reparto')
$$;

-- Título genérico (D20): hasta 40 caracteres, sin dígitos, sin "$" y sin nombres.
create or replace function public.fin_dispersion_aviso_titulo(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case p_tipo when 'ingreso_por_repartir' then 'Tienes un ingreso por repartir'
                     when 'ingreso_anulado_con_reparto' then 'Un ingreso anulado tenía reparto' end
$$;

-- fin_emitir_aviso: igual que en 20261147 más el tipo nuevo (quien ve los repartos del libro; el ingreso, con reparto anulado, por objeto).
create or replace function public.fin_emitir_aviso(
  p_libro_id uuid, p_tipo text, p_objeto_tipo text, p_objeto_id uuid, p_clave text)
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro   public.fin_libros%rowtype;
  v_actor   uuid := public.persona_actual();
  v_persona uuid;
  v_n       integer := 0;
  v_hoy     integer;
  v_ok      boolean;
  v_crit    integer;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found or not public.fin_puede(p_libro_id, 'escribir') then
    raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos de ese libro.';
  end if;
  if not public.avisos_tipo_emitible(p_tipo) then
    raise exception using errcode = '22023', message = 'Ese tipo de aviso no lo emite la app.';
  end if;
  if p_objeto_tipo is not null and p_objeto_tipo not in ('deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'patron') then
    raise exception using errcode = '22023', message = 'Tipo de objeto no válido.';
  end if;
  if (p_objeto_tipo is null) <> (p_objeto_id is null) then
    raise exception using errcode = '22023', message = 'El objeto lleva tipo e id, o ninguno.';
  end if;
  if p_clave is null or char_length(p_clave) > 120 or p_clave !~ '^[a-z0-9_:.-]+$' then
    raise exception using errcode = '22023', message = 'La clave son minúsculas, dígitos y _ : . - (máximo 120).';
  end if;
  if not public.fin_destinatario_valido(v_libro.hogar_id, v_actor) then
    raise exception using errcode = '42501', message = 'Solo un miembro con permiso de escribir emite avisos de ese libro.';
  end if;
  -- Los avisos de fugas y deudas solo los emite quien puede ver las deudas del libro (misma regla que las tablas).
  if p_tipo in ('fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')
     and not public.fin_fugas_puede_ver(p_libro_id) then
    raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos de fugas y deudas de ese libro.';
  end if;
  -- El aviso del reparto de ingresos: solo quien puede ver los repartos y con el ingreso como objeto.
  if p_tipo = 'ingreso_por_repartir' then
    if not public.fin_dispersion_puede_ver(p_libro_id) then
      raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos del reparto de ingresos de ese libro.';
    end if;
    if p_objeto_tipo is distinct from 'movimiento' or p_objeto_id is null
       or not exists (select 1 from public.fin_movimientos x
                       where x.id = p_objeto_id and x.tipo = 'ingreso' and x.libro_destino_id = p_libro_id) then
      raise exception using errcode = '22023', message = 'El aviso del reparto lleva por objeto un ingreso de ese libro.';
    end if;
  end if;
  -- El aviso del ingreso anulado con reparto (H-03): solo quien puede ver los repartos; el objeto es el ingreso (de ese libro)
  -- y debe tener un reparto anulado.
  if p_tipo = 'ingreso_anulado_con_reparto' then
    if not public.fin_dispersion_puede_ver(p_libro_id) then
      raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos del reparto de ingresos de ese libro.';
    end if;
    if p_objeto_tipo is distinct from 'movimiento' or p_objeto_id is null
       or not exists (select 1 from public.fin_movimientos x
                       where x.id = p_objeto_id and x.tipo = 'ingreso' and x.libro_destino_id = p_libro_id)
       or not exists (select 1 from public.fin_dispersiones d
                       where d.movimiento_id = p_objeto_id and d.libro_id = p_libro_id and d.estado = 'anulada') then
      raise exception using errcode = '22023',
        message = 'El aviso del ingreso anulado lleva por objeto un ingreso de ese libro con reparto anulado.';
    end if;
  end if;
  -- F2-3: el objeto debe pertenecer al libro del aviso.
  if p_objeto_id is not null then
    v_ok := case p_objeto_tipo
      when 'deuda' then exists (select 1 from public.fin_deudas x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'ocurrencia' then exists (select 1 from public.fin_ocurrencias x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'partida' then exists (select 1 from public.fin_partidas_semana x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'bolsa' then exists (select 1 from public.fin_bolsas_ahorro x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'semana' then exists (select 1 from public.fin_semanas x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'libro' then p_objeto_id = p_libro_id
      when 'movimiento' then exists (select 1 from public.fin_movimientos x
                                      where x.id = p_objeto_id and (x.libro_origen_id = p_libro_id or x.libro_destino_id = p_libro_id))
      when 'patron' then exists (select 1 from public.fin_patrones_cobro x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      else false end;
    if not coalesce(v_ok, false) then
      raise exception using errcode = '22023', message = 'Ese objeto no es de ese libro.';
    end if;
  end if;
  -- F2-3: las críticas que emite la app se limitan a 5 por día y libro.
  if p_tipo in ('flujo_negativo', 'abono_bajo_minimo', 'deuda_se_volvio_mala') then
    select count(distinct a.clave) into v_crit from public.avisos a
     where a.libro_id = p_libro_id and a.tipo in ('flujo_negativo', 'abono_bajo_minimo', 'deuda_se_volvio_mala')
       and a.emitido_por is not null and a.creado_en > now() - interval '24 hours'
       and a.clave <> p_clave;
    if v_crit >= 5 then
      raise exception using errcode = '22023', message = 'Se llegó al tope de 5 avisos críticos al día en ese libro.';
    end if;
  end if;
  select count(distinct a.clave) into v_hoy from public.avisos a
   where a.emitido_por = v_actor and a.creado_en > now() - interval '24 hours';
  if v_hoy >= 60 then
    raise exception using errcode = '22023', message = 'Se llegó al tope de 60 avisos al día por persona.';
  end if;
  for v_persona in select * from public.fin_avisos_destinatarios(p_libro_id, p_tipo, v_actor) loop
    if public.avisos_insertar(v_libro.hogar_id, v_persona, 'finanzas', p_tipo, p_libro_id, p_objeto_tipo,
                              p_objeto_id, p_clave, now(), v_actor) then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end
$$;

-- Preferencias: el tipo nuevo se puede silenciar (suena menos, sigue en la bandeja). Igual que la versión de 20261147 más el tipo.
create or replace function public.avisos_actualizar_preferencias(
  p_zona_horaria text default null, p_silencio_desde time default null, p_silencio_hasta time default null,
  p_criticas_en_silencio boolean default null, p_tope_no_criticas integer default null,
  p_hora_vencimientos time default null, p_resumen_lunes time default null,
  p_recordatorio_cierre_dia integer default null, p_recordatorio_cierre_hora time default null,
  p_tipos_silenciados text[] default null, p_pulsera_texto_corto boolean default null)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
begin
  if not exists (select 1 from public.avisos_preferencias p where p.persona_id = v_persona) then
    raise exception using errcode = '42501', message = 'Esta cuenta no tiene preferencias de avisos de dinero.';
  end if;
  if p_zona_horaria is not null and not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_zona_horaria) then
    raise exception using errcode = '22023', message = 'Zona horaria desconocida.';
  end if;
  if p_tope_no_criticas is not null and p_tope_no_criticas not between 0 and 10 then
    raise exception using errcode = '22023', message = 'El tope va de 0 a 10.';
  end if;
  if p_recordatorio_cierre_dia is not null and p_recordatorio_cierre_dia not between 1 and 7 then
    raise exception using errcode = '22023', message = 'El día del recordatorio va de 1 (lunes) a 7 (domingo).';
  end if;
  if p_tipos_silenciados is not null and exists (
      select 1 from unnest(p_tipos_silenciados) t
       where t is null or t not in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
             'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
             'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado', 'retiro_bolsa_compartida',
             'resumen_lunes', 'recordatorio_cierre',
             'hab_bloque', 'hab_lectura', 'hab_momento', 'hab_reservado', 'hab_revision_pre', 'hab_revision', 'hab_cierre_dia',
             'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala',
             'ingreso_por_repartir', 'ingreso_anulado_con_reparto')) then
    raise exception using errcode = '22023', message = 'Tipo de aviso desconocido.';
  end if;
  if coalesce(p_silencio_desde, (select q.silencio_desde from public.avisos_preferencias q where q.persona_id = v_persona))
     = coalesce(p_silencio_hasta, (select q.silencio_hasta from public.avisos_preferencias q where q.persona_id = v_persona)) then
    raise exception using errcode = '22023', message = 'Las horas silenciosas no pueden empezar y terminar a la misma hora.';
  end if;
  update public.avisos_preferencias p
     set zona_horaria = coalesce(p_zona_horaria, p.zona_horaria),
         silencio_desde = coalesce(p_silencio_desde, p.silencio_desde),
         silencio_hasta = coalesce(p_silencio_hasta, p.silencio_hasta),
         criticas_en_silencio = coalesce(p_criticas_en_silencio, p.criticas_en_silencio),
         tope_no_criticas = coalesce(p_tope_no_criticas, p.tope_no_criticas),
         hora_vencimientos = coalesce(p_hora_vencimientos, p.hora_vencimientos),
         resumen_lunes = coalesce(p_resumen_lunes, p.resumen_lunes),
         recordatorio_cierre_dia = coalesce(p_recordatorio_cierre_dia, p.recordatorio_cierre_dia),
         recordatorio_cierre_hora = coalesce(p_recordatorio_cierre_hora, p.recordatorio_cierre_hora),
         tipos_silenciados = coalesce(p_tipos_silenciados, p.tipos_silenciados),
         pulsera_texto_corto = coalesce(p_pulsera_texto_corto, p.pulsera_texto_corto)
   where p.persona_id = v_persona;
end
$$;
