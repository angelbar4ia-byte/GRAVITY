-- =============================================================================
-- GRAVITY · Cuidados: correcciones de la revisión de la Fase 5 (F5-B1, F5-I1, F5-I5)
-- =============================================================================
-- F5-B1 (D19): la cuenta maestra que NO es la dueña es de solo lectura total y no lee lo clínico. No da consentimiento
--   (a sí misma ni a nadie), cui_perfil nunca la trata como pareja_consentida y cui_puede solo le deja leer turnos.
-- F5-I1: los gastos de ámbito 'casa' los registran solo dueño, hermana y pareja; la cuidadora recibe 42501.
-- F5-I5: cui_programar_cron_tomas() programa (idempotente) la generación diaria de tomas si pg_cron se activa después.
-- Migración nueva (hacia adelante). Sin secretos.
-- =============================================================================

-- 1. ¿Es la sesión la cuenta maestra sin ser la dueña? ---------------------------------------------------------------
create function public.cui_es_maestra_ajena(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (select 1 from public.membresias m
                  where m.hogar_id = p_hogar_id and m.persona_id = public.persona_actual()
                    and m.es_maestra and m.activa and m.rol <> 'dueno'
                    and m.desde <= now() and (m.hasta is null or m.hasta > now()))
$$;
comment on function public.cui_es_maestra_ajena(uuid) is
  'D19: ¿quien consulta es la cuenta maestra vigente y no la dueña? Solo lectura total: en Cuidados solo ve turnos.';
revoke all on function public.cui_es_maestra_ajena(uuid) from public, anon;
grant execute on function public.cui_es_maestra_ajena(uuid) to authenticated;

-- 2. Perfil: la maestra ajena nunca es pareja_consentida ------------------------------------------------------------
create or replace function public.cui_perfil(p_hogar_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_rol text := public.rol_en_hogar(p_hogar_id);
  v_yo  uuid := public.persona_actual();
begin
  if v_rol is null or v_yo is null then
    return null;
  end if;
  if v_rol = 'dueno' then
    return 'dueno';
  end if;
  if v_rol = 'coadministrador' then
    if public.cui_es_maestra_ajena(p_hogar_id) then
      return 'pareja';   -- nunca consentida, aunque exista una fila concedida
    end if;
    return case when exists (select 1 from public.cui_consentimientos c
                              where c.hogar_id = p_hogar_id and c.persona_id = v_yo and c.concedido)
                then 'pareja_consentida' else 'pareja' end;
  end if;
  if v_rol in ('cuidador', 'familiar') then
    if exists (select 1 from public.cui_turnos t
                where t.hogar_id = p_hogar_id and t.persona_id = v_yo and t.tipo = 'cuidadora') then
      return 'cuidadora';
    end if;
    if exists (select 1 from public.cui_turnos t
                where t.hogar_id = p_hogar_id and t.persona_id = v_yo and t.tipo = 'hermana_visita') then
      return 'hermana';
    end if;
  end if;
  return null;
end
$$;

-- 3. Permisos: la maestra ajena solo lee turnos; el gasto de casa no es de la cuidadora ----------------------------------
create or replace function public.cui_puede(p_hogar_id uuid, p_objeto text, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_p text := public.cui_perfil(p_hogar_id);
begin
  if v_p is null or p_accion not in ('leer', 'escribir')
     or p_objeto not in ('turnos', 'medicamentos', 'tomas', 'comidas', 'bitacora', 'entregas', 'cambios', 'gastos') then
    return false;
  end if;
  if public.cui_es_maestra_ajena(p_hogar_id) then
    return p_objeto = 'turnos' and p_accion = 'leer';   -- D19: no escribe nada y no lee lo clínico
  end if;
  if p_accion = 'leer' then
    return case p_objeto
      when 'turnos' then true
      when 'medicamentos' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'tomas' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'comidas' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'bitacora' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'entregas' then v_p in ('dueno', 'cuidadora', 'hermana')
      when 'cambios' then v_p in ('dueno', 'cuidadora', 'hermana')
      when 'gastos' then true
      else false end;
  end if;
  return case p_objeto
    when 'turnos' then v_p = 'dueno'
    when 'medicamentos' then v_p = 'dueno'
    when 'comidas' then v_p in ('dueno', 'cuidadora')
    when 'bitacora' then v_p in ('dueno', 'cuidadora', 'hermana')
    when 'entregas' then v_p in ('dueno', 'cuidadora', 'hermana')
    when 'gastos' then true
    else false end;   -- tomas y cambios urgentes solo cambian con sus RPC
end
$$;
comment on function public.cui_puede(uuid, text, text) is
  'Spec 5 §5 (v1.6): quién lee y escribe cada parte. Cuenta maestra que no es la dueña: solo lee turnos, no escribe nada (D19). '
  'Pareja: turnos siempre; medicamentos, tomas, comidas y bitácora (solo lectura) con su consentimiento; gastos solo los suyos. '
  'Cuidadora y hermana como antes.';

-- F5-I1: gastos del ámbito casa solo dueño, hermana y pareja
drop policy cui_gastos_agregar on public.cui_gastos;
create policy cui_gastos_agregar on public.cui_gastos for insert to authenticated
  with check (public.cui_puede(hogar_id, 'gastos', 'escribir')
              and (ambito = 'cuidado'
                   or public.cui_perfil(hogar_id) in ('dueno', 'hermana', 'pareja', 'pareja_consentida')));

-- 4. Consentimientos: la maestra ajena no concede (F5-B1) ------------------------------------------------------------
create or replace function public.cui_cambiar_consentimiento(p_hogar_id uuid, p_persona_id uuid, p_concedido boolean)
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
  -- Lo cambia su titular (miembro vigente del hogar, no la cuenta maestra ajena: D19); el de Papá, que no tiene cuenta,
  -- lo firma el albacea (spec 5 §4).
  if public.rol_en_hogar(p_hogar_id) is null
     or public.cui_es_maestra_ajena(p_hogar_id)
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

-- Si la maestra ya tenía un consentimiento concedido, se retira.
update public.cui_consentimientos c
   set concedido = false, cambiado_en = now()
 where c.concedido
   and exists (select 1 from public.membresias m
                where m.hogar_id = c.hogar_id and m.persona_id = c.persona_id and m.es_maestra and m.rol <> 'dueno');

-- 5. F5-I5: programar el cron de tomas cuando pg_cron se active después --------------------------------------------------
create function public.cui_programar_cron_tomas()
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  -- Quien llama desde la app debe ser dueño vigente de algún hogar; el servidor (sin sesión) también puede.
  if auth.uid() is not null and not exists (
       select 1 from public.membresias m
        where m.persona_id = public.persona_actual() and m.rol = 'dueno' and m.activa
          and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
    raise exception using errcode = '42501', message = 'Solo el dueño programa la generación de tomas.';
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    return false;   -- activa pg_cron en Supabase (Database > Extensions) y vuelve a llamar
  end if;
  -- 10:00 UTC = 4:00 en la Ciudad de México. cron.schedule con el mismo nombre actualiza el trabajo (idempotente).
  execute $c$select cron.schedule('cui-generar-tomas', '0 10 * * *', 'select public.cui_generar_tomas_todas()')$c$;
  return true;
end
$$;
comment on function public.cui_programar_cron_tomas() is
  'Programa (o reprograma) el trabajo diario cui-generar-tomas si pg_cron existe; devuelve false si aún no. Solo el dueño o el servidor.';
revoke all on function public.cui_programar_cron_tomas() from public, anon;
grant execute on function public.cui_programar_cron_tomas() to authenticated, service_role;
