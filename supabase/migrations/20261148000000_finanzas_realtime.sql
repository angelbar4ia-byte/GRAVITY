-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, paquete F8-6.6: actualización entre dispositivos (Supabase Realtime)
-- (docs/specs/fase-8-finanzas-realtime.md; D3, D5, D19, D20, D24)
-- =============================================================================
-- Qué hace:
--   Cuando cambian los datos de un libro de Finanzas, la base emite un mensaje de Realtime Broadcast SIN DATOS por el
--   canal privado de ESE libro:
--       tema    finanzas:libro:<uuid del libro>
--       evento  cambio
--       cuerpo  {"v":1}            (nada de montos, comercios, cuentas ni filas: el dinero NO viaja por el canal)
--   Cada dispositivo suscrito vuelve a pedir lo suyo con su propia sesión y ahí se aplica la RLS.
--
--   1. fin_realtime_avisar(): disparador POR SENTENCIA (con tablas de transición, no por fila) en las tablas de
--      Finanzas que la persona ve. Un solo mensaje por libro y por transacción: una importación masiva o una RPC que
--      toca varias tablas no inunda el canal.
--   2. fin_realtime_puede_suscribir(tema): quién puede escuchar un canal. Solo quien LEE ese libro (fin_puede 'leer':
--      titular, miembro, albacea; la cuenta maestra solo con consulta vigente, I2; el lector de un compartido público
--      adulto con Finanzas) y NO la vista temporal de Papá (D24). Familiar, cuidador, Casa y la tablet pública no
--      tienen Finanzas: fin_puede les responde falso.
--   3. fin_realtime_instalar_politica(): crea en realtime.messages la política de lectura (suscribirse) para
--      `authenticated`. Nadie puede ESCRIBIR en el canal (no hay política de insert): solo el disparador, que es
--      security definer, emite mensajes.
--
-- Tolerancia: el servidor de pruebas es Postgres puro SIN esquema realtime, y un proyecto puede tener Realtime apagado.
-- Todo lo que toca realtime.* se comprueba antes (to_regclass / to_regprocedure) y, si falta, solo avisa (notice). Si el
-- envío falla en el momento, avisa (warning) y NUNCA bloquea la escritura del libro. Si se enciende Realtime después,
-- basta correr `select public.fin_realtime_instalar_politica();` como dueño.
--
-- NO verificado contra un Supabase real (no había uno disponible al escribir esto): la firma de realtime.send(payload
-- jsonb, event text, topic text, private boolean) y el nombre realtime.topic() / realtime.messages.extension son los de
-- la documentación de Supabase recordada; ver la nota de la especificación.
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. El disparador por sentencia
-- -----------------------------------------------------------------------------
-- Argumentos del trigger: los nombres de las columnas que traen el libro (uno, o dos en fin_movimientos).
create function public.fin_realtime_avisar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_col    text;
  v_libros uuid[] := '{}';
  v_nuevos uuid[];
  v_libro  uuid;
  v_hechos text;
begin
  -- Sin Realtime (Postgres puro o proyecto sin él) no hay nada que hacer.
  if to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null then
    return null;
  end if;

  foreach v_col in array tg_argv loop
    if tg_op in ('INSERT', 'UPDATE') then
      execute format('select coalesce(array_agg(distinct %1$I), ''{}'') from nuevas where %1$I is not null', v_col)
        into v_nuevos;
      v_libros := v_libros || v_nuevos;
    end if;
    if tg_op in ('DELETE', 'UPDATE') then
      execute format('select coalesce(array_agg(distinct %1$I), ''{}'') from viejas where %1$I is not null', v_col)
        into v_nuevos;
      v_libros := v_libros || v_nuevos;
    end if;
  end loop;

  -- Un mensaje por libro y por transacción (la lista de los ya avisados vive solo en esta transacción).
  v_hechos := coalesce(current_setting('gravity.fin_realtime_avisados', true), '');
  for v_libro in select distinct l from unnest(v_libros) as l loop
    if position(',' || v_libro::text || ',' in ',' || v_hechos || ',') > 0 then
      continue;
    end if;
    begin
      perform realtime.send(jsonb_build_object('v', 1), 'cambio', 'finanzas:libro:' || v_libro::text, true);
      v_hechos := case when v_hechos = '' then v_libro::text else v_hechos || ',' || v_libro::text end;
    exception when others then
      -- Nunca estorba la escritura del libro.
      raise warning 'fin_realtime_avisar: no se pudo avisar (%)', sqlstate;
    end;
  end loop;
  perform set_config('gravity.fin_realtime_avisados', v_hechos, true);
  return null;
end
$$;
comment on function public.fin_realtime_avisar() is
  'F8-6.6. Trigger por sentencia: emite por Realtime Broadcast un mensaje sin datos ("el libro X cambió") por libro y por '
  'transacción. Tolerante a la ausencia de realtime.send. Argumentos: columnas con el libro.';

-- Una pareja de triggers por evento (las tablas de transición no admiten varios eventos en uno).
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('fin_movimientos',          array['libro_origen_id', 'libro_destino_id']),
      ('fin_cuentas',              array['libro_id']),
      ('fin_deudas',               array['libro_id']),
      ('fin_msi',                  array['libro_id']),
      ('fin_estados_cuenta',       array['libro_id']),
      ('fin_ocurrencias',          array['libro_id']),
      ('fin_ingresos',             array['libro_id']),
      ('fin_compromisos',          array['libro_id']),
      ('fin_semanas',              array['libro_id']),
      ('fin_partidas_semana',      array['libro_id']),
      ('fin_parametros',           array['libro_id']),
      ('fin_dispersiones',         array['libro_id']),
      ('fin_dispersion_lineas',    array['libro_id']),
      ('fin_patrones_cobro',       array['libro_id']),
      ('fin_fuga_clasificaciones', array['libro_id']),
      ('fin_fuga_respuestas',      array['libro_id']),
      ('fin_deuda_propositos',     array['libro_id']),
      ('fin_deuda_semaforo',       array['libro_id'])
    ) as t(tabla, columnas)
  loop
    if to_regclass('public.' || r.tabla) is null then
      raise notice 'fin_realtime: la tabla % no existe; se omite', r.tabla;
      continue;
    end if;
    execute format(
      'create trigger fin_realtime_ins after insert on public.%I referencing new table as nuevas '
      'for each statement execute function public.fin_realtime_avisar(%s)',
      r.tabla, (select string_agg(quote_literal(c), ', ') from unnest(r.columnas) c));
    execute format(
      'create trigger fin_realtime_upd after update on public.%I referencing old table as viejas new table as nuevas '
      'for each statement execute function public.fin_realtime_avisar(%s)',
      r.tabla, (select string_agg(quote_literal(c), ', ') from unnest(r.columnas) c));
    execute format(
      'create trigger fin_realtime_del after delete on public.%I referencing old table as viejas '
      'for each statement execute function public.fin_realtime_avisar(%s)',
      r.tabla, (select string_agg(quote_literal(c), ', ') from unnest(r.columnas) c));
  end loop;
end
$$;

-- -----------------------------------------------------------------------------
-- 2. Quién puede suscribirse
-- -----------------------------------------------------------------------------
create function public.fin_realtime_puede_suscribir(p_tema text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_libro uuid;
begin
  if p_tema is null
     or p_tema !~ '^finanzas:libro:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return false;
  end if;
  v_libro := substr(p_tema, char_length('finanzas:libro:') + 1)::uuid;
  -- Lee el libro (con la vigencia de la consulta de la maestra, I2) y no es la vista temporal de Papá (D24).
  return public.fin_puede(v_libro, 'leer') and not public.fin_vista_vigente_libro(v_libro);
end
$$;
comment on function public.fin_realtime_puede_suscribir(text) is
  'F8-6.6. ¿Puede quien consulta escuchar el tema finanzas:libro:<uuid>? Solo quien lee ese libro (fin_puede leer), nunca la '
  'vista temporal de Papá (D24). Tema mal formado: falso.';

-- -----------------------------------------------------------------------------
-- 3. La política de realtime.messages (solo si el proyecto tiene Realtime)
-- -----------------------------------------------------------------------------
create function public.fin_realtime_instalar_politica()
returns text
language plpgsql
set search_path = ''
as $$
begin
  if to_regclass('realtime.messages') is null or to_regprocedure('realtime.topic()') is null then
    raise notice 'fin_realtime: este servidor no tiene realtime.messages/realtime.topic(); no se instala la política. '
                 'Al activar Realtime, corre: select public.fin_realtime_instalar_politica();';
    return 'omitida';
  end if;
  begin
    execute 'drop policy if exists fin_realtime_suscribir on realtime.messages';
    execute 'create policy fin_realtime_suscribir on realtime.messages for select to authenticated '
            'using (realtime.messages.extension = ''broadcast'' '
            'and public.fin_realtime_puede_suscribir((select realtime.topic())))';
  exception when insufficient_privilege then
    raise notice 'fin_realtime: sin permiso para crear la política en realtime.messages; créala como dueño del proyecto.';
    return 'sin_permiso';
  end;
  return 'instalada';
end
$$;
comment on function public.fin_realtime_instalar_politica() is
  'F8-6.6. Crea (o rehace) la política que deja suscribirse a los canales finanzas:libro:*. No hace nada, y lo dice, si el '
  'servidor no tiene Realtime. Solo la corre el dueño de la base.';

revoke all on function public.fin_realtime_avisar(), public.fin_realtime_instalar_politica()
  from public, anon, authenticated, service_role;
revoke all on function public.fin_realtime_puede_suscribir(text) from public, anon, service_role;
-- La evalúa Realtime con el rol de quien se suscribe.
grant execute on function public.fin_realtime_puede_suscribir(text) to authenticated;

select public.fin_realtime_instalar_politica();
