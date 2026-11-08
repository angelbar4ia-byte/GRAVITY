-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados · recordatorios de toma desde el servidor (spec 5 v1.7, sección 8i)
-- =============================================================================
-- El servidor genera el recordatorio de cada toma pendiente y lo entrega al cuidador de turno como aviso (tabla avisos,
-- que entrega la Edge Function enviar-avisos con FCM); ya no depende de que la app esté abierta.
--   - avisos.tipo admite 'recordatorio_toma' (importante) y avisos.objeto_tipo admite 'toma' (conserva todos los previos).
--   - El aviso NO lleva medicamento, dosis ni persona (D3, D6): solo apunta a la toma (objeto_id); el texto genérico está en
--     el catálogo de la app. La clave de deduplicación es 'toma:<id de la toma>:<destinatario>' (única por persona y clave).
--   - El recordatorio de toma no cuenta para el tope diario de avisos no críticos (se agruparía y no sonaría) y no espera al
--     silencio nocturno: la persona está de turno a esa hora. Sigue siendo de severidad importante.
--   - cui_avisar_tomas_proximas(ventana, ahora): solo service_role o pg_cron. Destinatario: a quien se la pasaron
--     (pospuesta_a, con membresía vigente) o quien esté de turno a la hora de la toma (cui_quien_en_turno: cuidadora,
--     hermana de visita o, sin nadie, el dueño). Nunca la pareja ni Casa. Se programa cada 5 minutos si pg_cron existe.
-- Migración hacia adelante. Sin secretos.
-- =============================================================================

alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados', 'recordatorio_toma'));

alter table public.avisos drop constraint avisos_objeto_tipo_check;
alter table public.avisos add constraint avisos_objeto_tipo_check check (objeto_tipo in (
  'deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'solicitud_vista', 'cambio_urgente', 'toma'));

create or replace function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90', 'solicitud_vista', 'cambio_urgente_cuidados') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80',
                    'recordatorio_toma')
      then 'importante'
    else 'informativa' end
$$;

-- avisos_insertar: igual que antes; el recordatorio de toma no entra en el tope diario.
create or replace function public.avisos_insertar(
  p_hogar_id uuid, p_persona_id uuid, p_modulo text, p_tipo text, p_libro_id uuid,
  p_objeto_tipo text, p_objeto_id uuid, p_clave text, p_programado timestamptz,
  p_emisor uuid default null, p_ahora timestamptz default now())
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_pref   public.avisos_preferencias%rowtype;
  v_zona   text;
  v_sev    text := public.avisos_severidad(p_tipo);
  v_envio  timestamptz;
  v_estado text := 'pendiente';
  v_dia    date;
  v_n      integer;
  v_fijo   boolean := p_tipo in ('resumen_lunes', 'recordatorio_cierre', 'recordatorio_toma');
  v_id     uuid := md5('aviso:' || p_persona_id::text || ':' || p_clave)::uuid;
  v_filas  integer;
begin
  select * into v_pref from public.avisos_preferencias p where p.persona_id = p_persona_id;
  v_zona  := coalesce(v_pref.zona_horaria, 'America/Mexico_City');
  v_envio := public.avisos_ajustar_envio(p_persona_id, v_sev, greatest(p_programado, p_ahora));
  -- Un tipo silenciado no suena, pero sigue a la vista en la bandeja.
  if p_tipo = any (coalesce(v_pref.tipos_silenciados, '{}')) then
    v_estado := 'agrupada';
  elsif v_sev <> 'critica' and not v_fijo then
    v_dia := (v_envio at time zone v_zona)::date;
    select count(*) into v_n from public.avisos a
     where a.persona_id = p_persona_id and a.severidad <> 'critica' and a.estado <> 'cancelada'
       and a.tipo not in ('resumen_lunes', 'recordatorio_cierre')
       and (a.enviar_en at time zone v_zona)::date = v_dia;
    if v_n >= coalesce(v_pref.tope_no_criticas, 3) then
      v_estado := 'agrupada';
    end if;
  end if;
  insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, libro_id, objeto_tipo,
                             objeto_id, programado_para, enviar_en, estado, emitido_por, creado_en)
  values (v_id, p_hogar_id, p_persona_id, p_modulo, p_tipo, v_sev, p_clave, p_libro_id, p_objeto_tipo,
          p_objeto_id, p_programado, v_envio, v_estado, p_emisor, p_ahora)
  on conflict (persona_id, clave) do nothing;
  get diagnostics v_filas = row_count;
  return v_filas > 0;
end
$$;
comment on function public.avisos_insertar(uuid, uuid, text, text, uuid, text, uuid, text, timestamptz, uuid, timestamptz) is
  'Interna. Inserta un aviso de forma idempotente por (persona, clave), aplicando el silencio y el tope diario (no al resumen, al cierre ni al recordatorio de toma).';

-- Recordatorios de toma ----------------------------------------------------------------------------------------------
create function public.cui_avisar_tomas_proximas(p_ventana_min integer default 15, p_ahora timestamptz default now())
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  r       record;
  q       record;
  v_n     integer := 0;
  v_cuando timestamptz;
  v_clave text;
begin
  -- Solo el servidor (service_role / pg_cron, sin sesión de usuario).
  if auth.uid() is not null then
    raise exception using errcode = '42501', message = 'Solo el servidor genera los recordatorios de toma.';
  end if;
  if p_ventana_min is null or p_ventana_min not between 1 and 120 then
    raise exception using errcode = '22023', message = 'La ventana es de 1 a 120 minutos.';
  end if;
  for r in
    select t.id, t.hogar_id, t.programada_para, t.pospuesta_a,
           greatest(t.programada_para, coalesce(t.pospuesta_turno_en, t.programada_para)) as cuando
      from public.cui_tomas t
      join public.cui_medicamentos m on m.hogar_id = t.hogar_id and m.id = t.medicamento_id and m.activo
     where t.estado = 'pendiente'
       and greatest(t.programada_para, coalesce(t.pospuesta_turno_en, t.programada_para))
           between p_ahora and p_ahora + make_interval(mins => p_ventana_min)
  loop
    v_cuando := r.cuando;
    if r.pospuesta_a is not null then
      -- Pasada a otra persona: solo a ella (si su membresía sigue vigente).
      for q in select m.persona_id from public.membresias m
                where m.hogar_id = r.hogar_id and m.persona_id = r.pospuesta_a and m.activa
                  and m.desde <= p_ahora and (m.hasta is null or m.hasta > p_ahora) loop
        v_clave := 'toma:' || r.id::text || ':' || q.persona_id::text;
        if public.avisos_insertar(r.hogar_id, q.persona_id, 'cuidados', 'recordatorio_toma', null, 'toma', r.id,
                                  v_clave, v_cuando, null, p_ahora) then
          v_n := v_n + 1;
        end if;
        update public.avisos a set enviar_en = greatest(v_cuando, p_ahora)
         where a.persona_id = q.persona_id and a.clave = v_clave and a.estado = 'pendiente';
      end loop;
    else
      for q in select x.persona_id from public.cui_quien_en_turno(r.hogar_id, r.programada_para) x loop
        v_clave := 'toma:' || r.id::text || ':' || q.persona_id::text;
        if public.avisos_insertar(r.hogar_id, q.persona_id, 'cuidados', 'recordatorio_toma', null, 'toma', r.id,
                                  v_clave, v_cuando, null, p_ahora) then
          v_n := v_n + 1;
        end if;
        update public.avisos a set enviar_en = greatest(v_cuando, p_ahora)
         where a.persona_id = q.persona_id and a.clave = v_clave and a.estado = 'pendiente';
      end loop;
    end if;
  end loop;
  return v_n;
end
$$;
comment on function public.cui_avisar_tomas_proximas(integer, timestamptz) is
  'Crea (idempotente por toma y destinatario) el aviso recordatorio_toma de cada toma pendiente que cae en los próximos '
  'p_ventana_min minutos: a quien se la pasaron o a quien está de turno (nunca pareja ni Casa). Sin nombres ni dosis (D3, D6). '
  'Solo servidor (pg_cron cada 5 min). Devuelve cuántos avisos nuevos creó.';
revoke all on function public.cui_avisar_tomas_proximas(integer, timestamptz) from public, anon, authenticated;
grant execute on function public.cui_avisar_tomas_proximas(integer, timestamptz) to service_role;

-- Cron cada 5 minutos si pg_cron existe (si no, no falla: el dueño lo activa con cui_programar_cron_tomas) --------------
create or replace function public.cui_programar_cron_tomas()
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not exists (
       select 1 from public.membresias m
        where m.persona_id = public.persona_actual() and m.rol = 'dueno' and m.activa
          and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
    raise exception using errcode = '42501', message = 'Solo el dueño programa la generación de tomas.';
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    return false;   -- activa pg_cron en Supabase (Database > Extensions) y vuelve a llamar
  end if;
  -- cron.schedule con el mismo nombre actualiza el trabajo (idempotente).
  execute $c$select cron.schedule('cui-generar-tomas', '0 10 * * *', 'select public.cui_generar_tomas_todas()')$c$;
  execute $c$select cron.schedule('cui-avisar-tomas', '*/5 * * * *', 'select public.cui_avisar_tomas_proximas()')$c$;
  return true;
end
$$;
comment on function public.cui_programar_cron_tomas() is
  'Programa (o reprograma) cui-generar-tomas (diario) y cui-avisar-tomas (cada 5 min) si pg_cron existe; false si aún no. Solo el dueño o el servidor.';

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('cui-avisar-tomas', '*/5 * * * *', 'select public.cui_avisar_tomas_proximas()');
  end if;
end
$$;
