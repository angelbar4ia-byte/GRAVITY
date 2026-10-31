-- =============================================================================
-- GRAVITY · Fase 2 · Endurecimiento (revisión de calidad docs/revisiones/fase-2.md)
-- =============================================================================
-- Criterios por defecto, PROVISIONALES (se anotan en supabase/README.md):
--   F2-1  Solo cuentan como fallo del dispositivo los resultados definitivos: el token inválido lo borra
--         y el nuevo resultado `rechazado` suma (5 lo apagan). Los errores transitorios de FCM (`error`:
--         5xx, cuota, red) reintentan sin sumar. registrar_dispositivo reactiva `recibe_avisos` y
--         reinicia `fallos` cuando el equipo es un TELÉFONO (no tablet personal ni pública).
--   F2-5  Las llaves de la Fase 2 son compuestas con libro_id: un retiro no apunta a una bolsa de otro libro.
--   F2-3  fin_emitir_aviso valida que objeto_id sea del libro, que quien emite sea miembro con permiso de
--         escribir y limita las críticas que emite la app (flujo_negativo, abono_bajo_minimo) a 5 por día y
--         libro. LO IDEAL: que solo el motor del servidor emita críticas (se decide en la siguiente ronda).
--   F2-4  (de la misma revisión) horas silenciosas con inicio = fin se rechazan (22023).
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior.
-- =============================================================================

-- F2-1: resultado `rechazado`
alter table public.avisos_entregas drop constraint avisos_entregas_resultado_check;
alter table public.avisos_entregas add constraint avisos_entregas_resultado_check
  check (resultado in ('ok', 'token_invalido', 'error', 'rechazado'));

create or replace function public.avisos_registrar_entrega(
  p_aviso_id uuid, p_dispositivo_id uuid, p_resultado text, p_codigo text default null)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  if p_resultado not in ('ok', 'token_invalido', 'error', 'rechazado') then
    raise exception using errcode = '22023', message = 'El resultado es ok, token_invalido, error o rechazado.';
  end if;
  insert into public.avisos_entregas (aviso_id, dispositivo_id, resultado, codigo)
  values (p_aviso_id, p_dispositivo_id, p_resultado, left(p_codigo, 60));
  if p_resultado = 'ok' then
    update public.dispositivos set ultimo_envio_en = now(), fallos = 0 where id = p_dispositivo_id;
  elsif p_resultado = 'token_invalido' then
    delete from public.dispositivos where id = p_dispositivo_id;
  elsif p_resultado = 'rechazado' then
    -- Fallo definitivo distinto del token (p. ej. configuración): sí suma; a los 5 se apaga.
    update public.dispositivos set fallos = least(fallos + 1, 32000) where id = p_dispositivo_id;
    update public.dispositivos set recibe_avisos = false where id = p_dispositivo_id and fallos >= 5;
  end if;
  -- 'error' (5xx, cuota, red) es transitorio: se reintenta sin sumar fallos (F2-1).
end
$$;

create or replace function public.registrar_dispositivo(
  p_token text, p_plataforma text, p_nombre text default null, p_tipo text default 'telefono')
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_id      uuid;
  v_antes   public.dispositivos%rowtype;
  v_recibe  boolean;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Hace falta una sesión.';
  end if;
  if p_token is null or char_length(btrim(p_token)) not between 1 and 4096 then
    raise exception using errcode = '22023', message = 'El token del dispositivo va de 1 a 4096 caracteres.';
  end if;
  if p_plataforma not in ('android', 'windows') then
    raise exception using errcode = '22023', message = 'La plataforma es android o windows.';
  end if;
  if p_tipo is null or p_tipo not in ('telefono', 'tablet_personal', 'tablet_publica', 'laptop') then
    raise exception using errcode = '22023', message = 'El tipo es telefono, tablet_personal, tablet_publica o laptop.';
  end if;
  v_id := md5('dispositivo:' || p_token)::uuid;
  -- Entrar con otra cuenta en el mismo equipo reasigna el token (M13).
  delete from public.dispositivos d where d.token_avisos = p_token and d.persona_id <> v_persona;
  -- Un dispositivo anterior con ese token (aunque su id no sea el derivado) se actualiza, no se duplica.
  select * into v_antes from public.dispositivos d where d.token_avisos = p_token;
  if found then
    v_id := v_antes.id;
  end if;
  -- F2-1: un teléfono que vuelve a abrir la app se reactiva; la tablet personal conserva la elección.
  v_recibe := case when p_tipo = 'tablet_publica' then false
                   when p_tipo = 'telefono' then true
                   when found and v_antes.persona_id = v_persona then v_antes.recibe_avisos
                   else p_tipo = 'telefono' end;
  insert into public.dispositivos (id, persona_id, plataforma, token_avisos, nombre, tipo, recibe_avisos)
  values (v_id, v_persona, p_plataforma, p_token, left(p_nombre, 80), p_tipo, v_recibe)
  on conflict (id) do update
     set persona_id = excluded.persona_id, plataforma = excluded.plataforma, nombre = excluded.nombre,
         tipo = excluded.tipo, recibe_avisos = excluded.recibe_avisos, ultimo_uso = now(), fallos = 0;
  return v_id;
end
$$;

-- F2-5
alter table public.fin_retiros_ahorro drop constraint fin_retiros_destino_fk;
alter table public.fin_retiros_ahorro
  add constraint fin_retiros_destino_fk foreign key (libro_id, bolsa_destino_id)
    references public.fin_bolsas_ahorro (libro_id, id),
  add constraint fin_retiros_destino_distinto check (bolsa_destino_id is distinct from bolsa_id);

-- F2-3
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
  if p_objeto_tipo is not null and p_objeto_tipo not in ('deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento') then
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
      else false end;
    if not coalesce(v_ok, false) then
      raise exception using errcode = '22023', message = 'Ese objeto no es de ese libro.';
    end if;
  end if;
  -- F2-3: las críticas que emite la app se limitan a 5 por día y libro.
  if p_tipo in ('flujo_negativo', 'abono_bajo_minimo') then
    select count(distinct a.clave) into v_crit from public.avisos a
     where a.libro_id = p_libro_id and a.tipo in ('flujo_negativo', 'abono_bajo_minimo')
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

-- F2-4
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
             'resumen_lunes', 'recordatorio_cierre')) then
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

