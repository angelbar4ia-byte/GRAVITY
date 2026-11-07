-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados v1.2 (respuestas del dueño, 7/nov/2026; spec 5 §8d)
-- =============================================================================
-- 1. Medicamentos: la hermana puede marcar "dado" o "no_dado" (cui_marcar_toma) igual que la cuidadora: solo si estaba de
--    turno (tipo 'hermana_visita' en cui_turnos) a la HORA PROGRAMADA de la toma. Fuera de su turno, 42501. El dueño sigue
--    pudiendo siempre; la pareja (con o sin consentimiento) sigue sin poder marcar. Mismo 42501 exista o no la toma.
-- 2. Bitácora de cuidados: la pareja con consentimiento vigente (cui_consentimientos.concedido, perfil 'pareja_consentida')
--    la lee, solo lectura. Sin consentimiento (o retirado) no ve nada: el perfil cambia en la misma consulta. Cambia
--    cui_puede(…, 'bitacora', 'leer'); la política cui_bitacora_leer (v1.1) ya deja pasar a quien no es cuidadora.
--    Las entregas de turno NO cambian: siguen cerradas para la pareja. Escribir bitácora tampoco cambia.
-- Migración hacia adelante; no edita las anteriores. Los permisos_rol (espejo de la app) no cambian.
-- =============================================================================

-- 1. Marcar tomas ------------------------------------------------------------------------------------------------------
create or replace function public.cui_marcar_toma(p_toma_id uuid, p_estado text)
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
  -- Mismo 42501 exista o no la toma. Dueño siempre; cuidadora u hermana solo si estaban de turno (con su tipo de turno)
  -- a la hora de la toma (spec 5 §8d); la pareja solo lee.
  if not found or v_perfil is null
     or not (v_perfil = 'dueno'
             or (v_perfil in ('cuidadora', 'hermana')
                 and exists (select 1 from public.cui_quien_en_turno(v_t.hogar_id, v_t.programada_para) q
                              where q.persona_id = v_yo
                                and q.tipo = case v_perfil when 'cuidadora' then 'cuidadora' else 'hermana_visita' end))) then
    raise exception using errcode = '42501', message = 'No puedes marcar esta toma.';
  end if;
  update public.cui_tomas t set estado = p_estado, marcada_por = v_yo, marcada_en = now() where t.id = v_t.id;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_t.hogar_id, v_yo, 'cuidados.toma_marcada', 'cui_tomas', v_t.id::text, jsonb_build_object('estado', p_estado));
end
$$;
comment on function public.cui_marcar_toma(uuid, text) is
  'Marca una toma como dado o no_dado. Dueño; cuidadora o hermana que estaban de turno (cuidadora / hermana_visita) a la hora '
  'programada. Cada cambio queda en la bitácora (cuidados.toma_marcada, solo el estado: sin medicamento ni dosis).';

-- 2. Permisos ----------------------------------------------------------------------------------------------------------
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
  if p_accion = 'leer' then
    return case p_objeto
      when 'turnos' then true
      when 'medicamentos' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'tomas' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'comidas' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')
      when 'bitacora' then v_p in ('dueno', 'pareja_consentida', 'cuidadora', 'hermana')   -- v1.2: pareja con consentimiento
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
  'Spec 5 §5 (v1.2): quién lee y escribe cada parte. Pareja: turnos siempre; medicamentos, tomas, comidas y bitácora (solo '
  'lectura) con su consentimiento; nunca las entregas; gastos solo los suyos. Cuidadora: lee todo lo clínico, marca tomas de '
  'su turno, registra comidas, escribe bitácora y entregas. Hermana: lee, marca tomas de su turno, escribe bitácora y entregas.';
