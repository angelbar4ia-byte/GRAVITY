-- =============================================================================
-- GRAVITY · Alimentación (Fase 7, v1.1 5a) · Empate por volado y "¿hay presupuesto?" (solo sí o no)
-- =============================================================================
-- Decisiones del dueño:
--   1. Un empate al cierre ya NO reabre la votación un día: se decide por volado en el servidor entre las propuestas
--      empatadas, y se guarda que fue por volado. Cuenta el voto tal como esté al cierre (quien lo cambió antes, cuenta).
--   2. El voto se puede cambiar mientras la votación esté abierta, haya empate o no (ya era así; se deja explícito).
--   3. ali_hay_presupuesto(hogar, monto) responde solo sí o no; nunca saldos, cuentas ni montos.
-- Solo hacia adelante: la migración 20261126000000 no se edita.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Volado: el estado "empate" desaparece; la ganadora guarda que salió por volado
-- -----------------------------------------------------------------------------
-- Votaciones que hubieran quedado en empate vuelven a abiertas (se resuelven en su próximo cierre).
alter table public.ali_votaciones drop constraint ali_votaciones_estado_check;
update public.ali_votaciones set estado = 'abierta', ronda = 1 where estado = 'empate';
alter table public.ali_votaciones add constraint ali_votaciones_estado_check check (estado in ('abierta', 'cerrada'));
alter table public.ali_votaciones add column ganadora_por_volado boolean not null default false;
alter table public.ali_votaciones add constraint ali_votaciones_volado_coherente check (not ganadora_por_volado or estado = 'cerrada');

drop index public.ali_votaciones_una_abierta;
create unique index ali_votaciones_una_abierta on public.ali_votaciones (hogar_id, cuenta) where estado = 'abierta';

comment on table public.ali_votaciones is
  'Plan familiar (D28). Dura un día (cierra_en). abierta: se vota y cada quien puede cambiar su voto. cerrada: hay ganadora_id; si al cierre hubo '
  'empate, el servidor decidió por volado (ganadora_por_volado = true). Solo cambia por las RPC ali_proponer_*, ali_votar y ali_cerrar_votaciones.';
comment on column public.ali_votaciones.ronda is 'Sin uso desde el volado (siempre 1); se conserva por compatibilidad.';
comment on column public.ali_votaciones.ganadora_por_volado is 'Verdadero si al cierre hubo empate y la ganadora salió por volado en el servidor.';
comment on table public.ali_votos is 'Un voto por persona y votación; se cambia con ali_votar mientras la votación esté abierta (cambios cuenta las veces).';

-- -----------------------------------------------------------------------------
-- 2. Voto: se cambia mientras la votación esté abierta, haya empate o no
-- -----------------------------------------------------------------------------
create or replace function public.ali_votar(p_votacion uuid, p_opcion uuid)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_v public.ali_votaciones%rowtype;
  v_persona uuid := public.persona_actual();
begin
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if not found or not public.ali_puede7(v_v.hogar_id, 'votaciones', null, 'votar') then
    raise exception using errcode = '42501', message = 'Tu cuenta no vota en esta votación.';
  end if;
  perform public.ali_cerrar_votaciones(v_v.hogar_id);
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if v_v.estado <> 'abierta' then
    raise exception using errcode = '22023', message = 'La votación ya cerró.';
  end if;
  if not exists (select 1 from public.ali_votacion_opciones o where o.votacion_id = p_votacion and o.id = p_opcion) then
    raise exception using errcode = '23503', message = 'Esa opción no es de esta votación.';
  end if;
  insert into public.ali_votos (votacion_id, hogar_id, persona_id, opcion_id) values (p_votacion, v_v.hogar_id, v_persona, p_opcion)
  on conflict (votacion_id, persona_id) do update
    set opcion_id = excluded.opcion_id, votado_en = now(), cambios = public.ali_votos.cambios + 1
    where public.ali_votos.opcion_id <> excluded.opcion_id;
  return v_v.estado;
end
$$;
comment on function public.ali_votar(uuid, uuid) is
  'D28: vota o cambia el voto mientras la votación esté abierta (haya empate o no). Devuelve el estado. Cerrada: 22023.';

-- -----------------------------------------------------------------------------
-- 3. Cierre: gana la de más votos; con empate, volado entre las empatadas
-- -----------------------------------------------------------------------------
create or replace function public.ali_cerrar_votaciones(p_hogar_id uuid default null)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_v   public.ali_votaciones%rowtype;
  v_n   integer := 0;
  v_ops integer;
  v_top uuid;
  v_cuantas integer;
begin
  if auth.uid() is not null and (p_hogar_id is null or public.ali_cuenta_de(p_hogar_id) is null) then
    raise exception using errcode = '42501', message = 'Indica un hogar al que perteneces.';
  end if;
  for v_v in
    select * from public.ali_votaciones v
     where v.estado = 'abierta' and v.cierra_en <= now() and (p_hogar_id is null or v.hogar_id = p_hogar_id)
     for update
  loop
    select count(*) into v_ops from public.ali_votacion_opciones o where o.votacion_id = v_v.id;
    if v_ops = 0 then
      continue;
    end if;
    -- Votos tal como están al cierre. Entre las de más votos, una sola gana; si hay varias, volado con gen_random_uuid()
    -- (aleatorio criptográfico del servidor, sin semilla que se pueda predecir).
    with c as (
      select o.id, count(vt.persona_id) as n
        from public.ali_votacion_opciones o left join public.ali_votos vt on vt.opcion_id = o.id
       where o.votacion_id = v_v.id group by o.id),
    empatadas as (select c1.id from c c1 where c1.n = (select max(c2.n) from c c2))
    select (select e.id from empatadas e order by gen_random_uuid() limit 1), (select count(*) from empatadas)
      into v_top, v_cuantas;
    update public.ali_votaciones
       set estado = 'cerrada', ganadora_id = v_top, cerrada_en = now(), ganadora_por_volado = (v_cuantas > 1)
     where id = v_v.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;
comment on function public.ali_cerrar_votaciones(uuid) is
  'D28: cierra las votaciones vencidas del hogar (o de todos, solo el servidor) y devuelve cuántas cerró. Gana la de más votos (una propuesta sin '
  'contendiente gana sola); si hay empate decide un volado en el servidor entre las empatadas y queda ganadora_por_volado = true. No se reabre.';

-- -----------------------------------------------------------------------------
-- 4. ¿Hay presupuesto para comprar? Solo sí o no
-- -----------------------------------------------------------------------------
-- p_cuenta: nulo = la de quien pregunta (dueño/pareja: su libro personal; familiar: el libro compartido de la casa); 'casa' o 'papa' para elegir.
-- Responde false, sin decir por qué, si: no hay sesión o hogar, la cuenta no puede preguntar (cuidadora, Casa, maestra), el monto no es mayor que
-- cero, Papá y quien pregunta no es el albacea, no hay libro, semana activa ni partida de Alimentación, o no alcanza.
-- Presupuesto disponible = (asignado + arrastre) de las partidas de la cuenta de gasto de Alimentación en la semana activa (lunes) del libro,
-- menos lo gastado en esa cuenta y semana (vista fin_v_gasto_semana de Finanzas). Es interno: no se devuelve ninguna cifra.
create function public.ali_hay_presupuesto(p_hogar_id uuid, p_monto_centavos bigint, p_cuenta text default null)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_q      text := public.ali_cuenta_de(p_hogar_id);
  v_cuenta text;
  v_libro  uuid;
  v_gasto  uuid;
  v_lunes  date := public.fin_lunes((now() at time zone 'America/Mexico_City')::date);
  v_disp   bigint;
begin
  if public.persona_actual() is null or v_q is null or v_q not in ('dueno', 'pareja', 'familiar')
     or p_monto_centavos is null or p_monto_centavos <= 0 then
    return false;
  end if;
  v_cuenta := coalesce(p_cuenta, case when v_q = 'familiar' then 'casa' else 'personal' end);
  if v_cuenta = 'personal' and v_q in ('dueno', 'pareja') then
    select l.id into v_libro from public.fin_libros l
     where l.hogar_id = p_hogar_id and l.tipo = 'personal' and l.activo and l.titular_id = public.persona_actual()
     order by l.creado_en, l.id limit 1;
  elsif v_cuenta = 'casa' then
    select a.libro_casa_id into v_libro from public.ali_ajustes a where a.hogar_id = p_hogar_id;
  elsif v_cuenta = 'papa' then
    v_libro := public.ali_libro_papa(p_hogar_id);
    if v_libro is not null and not public.fin_puede(v_libro, 'escribir') then
      return false;
    end if;
  else
    return false;
  end if;
  v_gasto := public.ali7_cuenta_gasto_por_omision(p_hogar_id);
  if v_libro is null or v_gasto is null then
    return false;
  end if;
  select sum(p.asignado + p.arrastre_recibido)::bigint
         - coalesce((select sum(g.gasto_centavos) from public.fin_v_gasto_semana g
                      where g.libro_id = v_libro and g.semana_inicio = v_lunes and g.cuenta_id = v_gasto), 0)
    into v_disp
    from public.fin_semanas s join public.fin_partidas_semana p on p.libro_id = s.libro_id and p.semana_id = s.id
   where s.libro_id = v_libro and s.semana_inicio = v_lunes and s.estado = 'activa' and p.cuenta_gasto_id = v_gasto;
  return coalesce(v_disp >= p_monto_centavos, false);
end
$$;
comment on function public.ali_hay_presupuesto(uuid, bigint, text) is
  'D28: ¿hay presupuesto para comprar este monto (centavos)? Solo true o false: nunca saldos, cuentas ni montos. Pregunta el dueño, la pareja o la '
  'familiar; para Papá solo el albacea (si no, false sin decir por qué). La cuidadora, Casa y la maestra siempre reciben false. Cuenta nula: dueño/pareja '
  'su libro personal, familiar el libro de la casa.';

revoke execute on function public.ali_hay_presupuesto(uuid, bigint, text) from public, anon, authenticated, service_role;
grant execute on function public.ali_hay_presupuesto(uuid, bigint, text) to authenticated;
