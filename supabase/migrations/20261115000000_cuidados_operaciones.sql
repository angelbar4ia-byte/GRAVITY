-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados · 3/4: operaciones (RPC) y baja de un cuidador
-- =============================================================================
-- docs/specs/fase-5-cuidados.md (§3 a §5 y criterios 1 a 6). Todas SECURITY DEFINER con search_path vacío; revocadas
-- a PUBLIC y anon. Errores: 42501 sin permiso (el mismo mensaje exista o no el registro), 22023 dato inválido,
-- 55000 estado (ya resuelto). Contrato completo en la cabecera de 20261114000000_cuidados_esquema.sql.
--
--   cui_generar_tomas(hogar, desde, dias)        dueño o servidor: crea las tomas pendientes de los medicamentos activos
--   cui_marcar_toma(toma, estado)                dueño; cuidadora de turno a la hora de la toma. Deja entrada en la bitácora
--   cui_crear_cambio_urgente(hogar, texto, id)   solo el dueño; avisa al cuidador de turno al instante
--   cui_atender_cambio_urgente(id)               quien lo recibe (o cualquier cuidadora/hermana si nadie estaba de turno)
--   cui_confirmar_gasto(gasto, confirmar)        solo el dueño; el paso a Finanzas es de finanzas
--   cui_cambiar_consentimiento(hogar, persona, concedido)   su titular; el albacea, por Papá
--   cui_autorizar_resumen(hogar, persona, vigente)          solo el albacea (D19)
--   cui_resumen_mensual(mes)                     dueño y hermana autorizada; sin montos de la pareja ni del dueño
--   cui_resumen_papa(hogar, dia)                 conteos del día, sin nombres ni dosis (también para la pareja)
-- Además: una baja (membresía no vigente) cancela los avisos de Cuidados pendientes de esa persona.
-- Migración hacia adelante.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tomas
-- -----------------------------------------------------------------------------
create function public.cui_generar_tomas(p_hogar_id uuid, p_desde date, p_dias integer default 1)
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_zona text := public.cui_zona(p_hogar_id);
  v_n    integer;
begin
  -- Con sesión, solo el dueño; sin sesión llega el servidor (service_role: anon no puede ejecutarla).
  if auth.uid() is not null and public.cui_perfil(p_hogar_id) is distinct from 'dueno' then
    raise exception using errcode = '42501', message = 'Solo el dueño genera las tomas.';
  end if;
  if p_desde is null or p_dias is null or p_dias not between 1 and 14 then
    raise exception using errcode = '22023', message = 'Genera de 1 a 14 días a la vez.';
  end if;
  insert into public.cui_tomas (hogar_id, medicamento_id, programada_para)
  select m.hogar_id, m.id, ((d.dia + h.hora::time)::timestamp at time zone v_zona)
    from public.cui_medicamentos m
    cross join lateral unnest(m.horas) as h (hora)
    cross join generate_series(p_desde::timestamp, (p_desde + (p_dias - 1))::timestamp, interval '1 day') as d (dia)
   where m.hogar_id = p_hogar_id and m.activo
  on conflict (medicamento_id, programada_para) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
comment on function public.cui_generar_tomas(uuid, date, integer) is
  'Crea las tomas pendientes de los medicamentos activos para p_dias días desde p_desde (zona del hogar). Idempotente. '
  'Devuelve cuántas creó. Solo el dueño o el servidor.';

create function public.cui_marcar_toma(p_toma_id uuid, p_estado text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_t      public.cui_tomas%rowtype;
  v_perfil text;
  v_yo     uuid := public.persona_actual();
begin
  if p_estado is null or p_estado not in ('dado', 'no_dado') then
    raise exception using errcode = '22023', message = 'El estado de una toma es dado o no_dado.';
  end if;
  select * into v_t from public.cui_tomas t where t.id = p_toma_id;
  if found then
    v_perfil := public.cui_perfil(v_t.hogar_id);
  end if;
  -- Mismo 42501 exista o no la toma. Dueño siempre; la cuidadora solo si está de turno a la hora de la toma;
  -- la hermana y la pareja solo leen (spec 5 §5).
  if not found or v_perfil is null
     or not (v_perfil = 'dueno'
             or (v_perfil = 'cuidadora'
                 and exists (select 1 from public.cui_quien_en_turno(v_t.hogar_id, v_t.programada_para) q
                              where q.persona_id = v_yo and q.tipo = 'cuidadora'))) then
    raise exception using errcode = '42501', message = 'No puedes marcar esta toma.';
  end if;
  update public.cui_tomas t set estado = p_estado, marcada_por = v_yo, marcada_en = now() where t.id = v_t.id;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_t.hogar_id, v_yo, 'cuidados.toma_marcada', 'cui_tomas', v_t.id::text, jsonb_build_object('estado', p_estado));
end
$$;
comment on function public.cui_marcar_toma(uuid, text) is
  'Marca una toma como dado o no_dado. Dueño, o cuidadora que estaba de turno a la hora programada. Cada cambio queda en la '
  'bitácora (cuidados.toma_marcada, solo el estado: sin medicamento ni dosis).';

-- -----------------------------------------------------------------------------
-- 2. Cambios urgentes (D4)
-- -----------------------------------------------------------------------------
create function public.cui_crear_cambio_urgente(p_hogar_id uuid, p_texto text, p_id uuid default gen_random_uuid())
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_yo   uuid := public.persona_actual();
  v_para uuid;
  r      record;
begin
  if public.cui_perfil(p_hogar_id) is distinct from 'dueno' then
    raise exception using errcode = '42501', message = 'Solo el dueño manda cambios urgentes.';
  end if;
  if p_texto is null or char_length(btrim(p_texto)) not between 1 and 200 then
    raise exception using errcode = '22023', message = 'El cambio urgente lleva de 1 a 200 caracteres.';
  end if;
  -- Idempotente para la cola sin conexión: el mismo id del mismo dueño no se repite.
  if exists (select 1 from public.cui_cambios_urgentes c
              where c.id = p_id and c.hogar_id = p_hogar_id and c.de_persona = v_yo) then
    return p_id;
  end if;
  select q.persona_id into v_para
    from public.cui_quien_en_turno(p_hogar_id, now()) q
   where q.tipo <> 'dueno' and q.persona_id <> v_yo
   order by q.tipo limit 1;
  insert into public.cui_cambios_urgentes (id, hogar_id, de_persona, para_persona, texto)
  values (p_id, p_hogar_id, v_yo, v_para, btrim(p_texto));
  -- Aviso inmediato (crítico) a todo cuidador de turno; sin texto: solo apunta al cambio (D3, D20).
  for r in select q.persona_id from public.cui_quien_en_turno(p_hogar_id, now()) q
            where q.tipo <> 'dueno' and q.persona_id <> v_yo loop
    perform public.avisos_insertar(p_hogar_id, r.persona_id, 'cuidados', 'cambio_urgente_cuidados', null,
                                   'cambio_urgente', p_id, 'cambio_urgente:' || p_id::text, now(), v_yo);
    -- Inmediato (D4): no espera al fin del silencio nocturno (la hermana puede estar de turno de noche).
    update public.avisos a set enviar_en = now()
     where a.persona_id = r.persona_id and a.clave = 'cambio_urgente:' || p_id::text and a.estado = 'pendiente';
  end loop;
  return p_id;
end
$$;
comment on function public.cui_crear_cambio_urgente(uuid, text, uuid) is
  'Solo el dueño. Crea el cambio y avisa AL INSTANTE (tipo cambio_urgente_cuidados, crítico, sin esperar el silencio nocturno) a quien está de turno que no sea él. Sin nadie '
  'de turno, para_persona queda nula (lo ven al entrar). Devuelve el id (idempotente por id).';

create function public.cui_atender_cambio_urgente(p_id uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_c public.cui_cambios_urgentes%rowtype;
  v_p text;
begin
  select * into v_c from public.cui_cambios_urgentes c where c.id = p_id;
  if found then
    v_p := public.cui_perfil(v_c.hogar_id);
  end if;
  if not found or v_p is null or v_p in ('pareja', 'pareja_consentida')
     or not (v_p = 'dueno' or v_c.para_persona = public.persona_actual()
             or (v_c.para_persona is null and v_p in ('cuidadora', 'hermana'))) then
    raise exception using errcode = '42501', message = 'No puedes atender este cambio.';
  end if;
  if v_c.atendido_en is not null then
    return;
  end if;
  update public.cui_cambios_urgentes c set atendido_en = now() where c.id = v_c.id;
  update public.avisos a set estado = 'resuelta', resuelta_en = now()
   where a.objeto_tipo = 'cambio_urgente' and a.objeto_id = v_c.id and a.persona_id = public.persona_actual()
     and a.estado not in ('cancelada', 'resuelta');
end
$$;
comment on function public.cui_atender_cambio_urgente(uuid) is 'Marca el cambio como atendido (y resuelve su aviso). Quien lo recibe, el dueño o, si nadie estaba de turno, una cuidadora u hermana.';

-- -----------------------------------------------------------------------------
-- 3. Gastos de cuidado: la confirmación del dueño
-- -----------------------------------------------------------------------------
create function public.cui_confirmar_gasto(p_gasto_id uuid, p_confirmar boolean)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_g public.cui_gastos%rowtype;
begin
  select * into v_g from public.cui_gastos g where g.id = p_gasto_id;
  if not found or public.cui_perfil(v_g.hogar_id) is distinct from 'dueno' then
    raise exception using errcode = '42501', message = 'Solo el dueño confirma los gastos de cuidado.';
  end if;
  if p_confirmar is null then
    raise exception using errcode = '22023', message = 'Indica si se confirma o se rechaza.';
  end if;
  update public.cui_gastos g
     set estado = case when p_confirmar then 'confirmado' else 'rechazado' end, confirmado_en = now()
   where g.id = v_g.id;   -- cui_gastos_guardar: 55000 si ya estaba resuelto
end
$$;
comment on function public.cui_confirmar_gasto(uuid, boolean) is
  'Solo el dueño: confirma (true) o rechaza (false) un gasto pendiente. El paso a Finanzas parte del estado confirmado (finanzas).';

-- -----------------------------------------------------------------------------
-- 4. Consentimientos y autorización del resumen
-- -----------------------------------------------------------------------------
create function public.cui_cambiar_consentimiento(p_hogar_id uuid, p_persona_id uuid, p_concedido boolean)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_yo uuid := public.persona_actual();
begin
  if p_concedido is null or p_persona_id is null then
    raise exception using errcode = '22023', message = 'Indica de quién es el consentimiento y si se concede.';
  end if;
  -- Lo cambia su titular (miembro vigente del hogar); el de Papá, que no tiene cuenta, lo firma el albacea (spec 5 §4).
  if public.rol_en_hogar(p_hogar_id) is null
     or not (p_persona_id = v_yo
             or (p_persona_id = public.cui_persona_papa(p_hogar_id) and public.cui_es_albacea(p_hogar_id))) then
    raise exception using errcode = '42501', message = 'Solo el titular, o el albacea por Papá, cambia un consentimiento.';
  end if;
  insert into public.cui_consentimientos (hogar_id, persona_id, concedido, cambiado_en, cambiado_por)
  values (p_hogar_id, p_persona_id, p_concedido, now(), v_yo)
  on conflict (hogar_id, persona_id)
  do update set concedido = excluded.concedido, cambiado_en = now(), cambiado_por = v_yo;
end
$$;
comment on function public.cui_cambiar_consentimiento(uuid, uuid, boolean) is
  'Concede o retira el consentimiento de una persona. Lo cambia su titular; el de Papá, el albacea. Queda en la bitácora.';

create function public.cui_autorizar_resumen(p_hogar_id uuid, p_persona_id uuid, p_vigente boolean)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  if not public.cui_es_albacea(p_hogar_id) then
    raise exception using errcode = '42501', message = 'Solo el albacea autoriza el resumen mensual.';
  end if;
  if p_vigente is null or p_persona_id is null or not exists (
       select 1 from public.membresias m
        where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
          and m.rol in ('cuidador', 'familiar')) then
    raise exception using errcode = '22023', message = 'Solo se autoriza a un cuidador o familiar del hogar.';
  end if;
  insert into public.cui_autorizacion_resumen (hogar_id, persona_id, autorizado_por, vigente, cambiado_en)
  values (p_hogar_id, p_persona_id, public.persona_actual(), p_vigente, now())
  on conflict (hogar_id, persona_id)
  do update set autorizado_por = excluded.autorizado_por, vigente = excluded.vigente, cambiado_en = now();
end
$$;
comment on function public.cui_autorizar_resumen(uuid, uuid, boolean) is
  'Solo el albacea (D19): autoriza (true) o retira (false) que la hermana vea el resumen mensual. Queda en la bitácora.';

-- -----------------------------------------------------------------------------
-- 5. Resúmenes
-- -----------------------------------------------------------------------------
-- Total del mes de los gastos de cuidado y de la casa CONFIRMADOS, SIN los que registró la pareja o el dueño (su rol
-- en el hogar, vigente o no). Solo el dueño y la hermana con autorización vigente; devuelve totales, nunca filas.
create function public.cui_resumen_mensual(p_mes date)
returns table (hogar_id uuid, mes date, gastos_cuidado_centavos bigint, gastos_casa_centavos bigint, n_gastos integer)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_yo  uuid := public.persona_actual();
  v_mes date := date_trunc('month', p_mes)::date;
begin
  if v_yo is null or p_mes is null then
    raise exception using errcode = '42501', message = 'No tienes acceso al resumen mensual.';
  end if;
  return query
    select m.hogar_id, v_mes,
           coalesce(sum(g.monto_centavos) filter (where g.ambito = 'cuidado'), 0)::bigint,
           coalesce(sum(g.monto_centavos) filter (where g.ambito = 'casa'), 0)::bigint,
           count(g.id)::integer
      from public.membresias m
      left join public.cui_gastos g
        on g.hogar_id = m.hogar_id and g.estado = 'confirmado'
       and g.fecha >= v_mes and g.fecha < (v_mes + interval '1 month')::date
       and not exists (select 1 from public.membresias x
                        where x.hogar_id = g.hogar_id and x.persona_id = g.persona_id
                          and x.rol in ('dueno', 'coadministrador'))
     where m.persona_id = v_yo and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and (m.rol = 'dueno'
            or (m.rol in ('cuidador', 'familiar')
                and exists (select 1 from public.cui_turnos t
                             where t.hogar_id = m.hogar_id and t.persona_id = v_yo and t.tipo = 'hermana_visita')
                and exists (select 1 from public.cui_autorizacion_resumen a
                             where a.hogar_id = m.hogar_id and a.persona_id = v_yo and a.vigente)))
     group by m.hogar_id;
  if not found then
    raise exception using errcode = '42501', message = 'No tienes acceso al resumen mensual.';
  end if;
end
$$;
comment on function public.cui_resumen_mensual(date) is
  'Spec 5 §4 y criterio 3. Total del mes (p_mes se lleva al día 1) de gastos de cuidado y de la casa confirmados, EXCLUYENDO los de la '
  'pareja y el dueño. Solo el dueño y la hermana con autorización vigente del albacea; otra sesión recibe 42501.';

create function public.cui_resumen_papa(p_hogar_id uuid, p_dia date default null)
returns table (dia date, tomas_total integer, tomas_dadas integer, tomas_no_dadas integer, tomas_pendientes integer,
               comidas_registradas integer, comidas_con_rechazo integer)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_zona text := public.cui_zona(p_hogar_id);
  v_dia  date := coalesce(p_dia, (now() at time zone public.cui_zona(p_hogar_id))::date);
begin
  if public.cui_perfil(p_hogar_id) is null then
    raise exception using errcode = '42501', message = 'No tienes acceso a Cuidados.';
  end if;
  return query
    select v_dia,
           (select count(*)::integer from public.cui_tomas t
             where t.hogar_id = p_hogar_id and t.programada_para >= v_dia::timestamp at time zone v_zona
               and t.programada_para < (v_dia + 1)::timestamp at time zone v_zona),
           (select count(*)::integer from public.cui_tomas t
             where t.hogar_id = p_hogar_id and t.estado = 'dado' and t.programada_para >= v_dia::timestamp at time zone v_zona
               and t.programada_para < (v_dia + 1)::timestamp at time zone v_zona),
           (select count(*)::integer from public.cui_tomas t
             where t.hogar_id = p_hogar_id and t.estado = 'no_dado' and t.programada_para >= v_dia::timestamp at time zone v_zona
               and t.programada_para < (v_dia + 1)::timestamp at time zone v_zona),
           (select count(*)::integer from public.cui_tomas t
             where t.hogar_id = p_hogar_id and t.estado = 'pendiente' and t.programada_para >= v_dia::timestamp at time zone v_zona
               and t.programada_para < (v_dia + 1)::timestamp at time zone v_zona),
           (select count(*)::integer from (select distinct c.tiempo from public.cui_comidas c
                                            where c.hogar_id = p_hogar_id and c.fecha = v_dia) x),
           (select count(*)::integer from (select distinct on (c.tiempo) c.resultado from public.cui_comidas c
                                            where c.hogar_id = p_hogar_id and c.fecha = v_dia
                                            order by c.tiempo, c.registrada_en desc, c.id) u
             where u.resultado = 'rechazo');
end
$$;
comment on function public.cui_resumen_papa(uuid, date) is
  'Resumen del día de Papá: conteos de tomas y comidas, SIN nombres ni dosis ni notas. Cualquiera con perfil en Cuidados, '
  'también la pareja sin consentimiento (spec 5 §4).';

-- -----------------------------------------------------------------------------
-- 6. Baja: los avisos de Cuidados pendientes de quien ya no es miembro se cancelan
-- -----------------------------------------------------------------------------
-- El acceso a los datos ya se corta al instante (todas las reglas parten de rol_en_hogar); esto evita que le lleguen
-- recordatorios o cambios urgentes ya programados.
create function public.cui_baja_cancela_avisos()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if not new.activa or (new.hasta is not null and new.hasta <= now()) then
    update public.avisos a set estado = 'cancelada'
     where a.persona_id = new.persona_id and a.hogar_id = new.hogar_id and a.modulo = 'cuidados'
       and a.estado in ('pendiente', 'pospuesta', 'agrupada');
  end if;
  return null;
end
$$;
create trigger membresias_z_cui_baja after update of activa, hasta on public.membresias
  for each row execute function public.cui_baja_cancela_avisos();

-- -----------------------------------------------------------------------------
-- 7. Privilegios
-- -----------------------------------------------------------------------------
revoke execute on function
  public.cui_generar_tomas(uuid, date, integer), public.cui_marcar_toma(uuid, text),
  public.cui_crear_cambio_urgente(uuid, text, uuid), public.cui_atender_cambio_urgente(uuid),
  public.cui_confirmar_gasto(uuid, boolean), public.cui_cambiar_consentimiento(uuid, uuid, boolean),
  public.cui_autorizar_resumen(uuid, uuid, boolean), public.cui_resumen_mensual(date),
  public.cui_resumen_papa(uuid, date), public.cui_baja_cancela_avisos()
  from public, anon, authenticated, service_role;
grant execute on function
  public.cui_marcar_toma(uuid, text), public.cui_crear_cambio_urgente(uuid, text, uuid),
  public.cui_atender_cambio_urgente(uuid), public.cui_confirmar_gasto(uuid, boolean),
  public.cui_cambiar_consentimiento(uuid, uuid, boolean), public.cui_autorizar_resumen(uuid, uuid, boolean),
  public.cui_resumen_mensual(date), public.cui_resumen_papa(uuid, date)
  to authenticated;
grant execute on function public.cui_generar_tomas(uuid, date, integer) to authenticated, service_role;
