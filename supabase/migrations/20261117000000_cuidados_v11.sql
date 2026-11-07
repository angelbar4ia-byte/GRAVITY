-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados v1.1 (respuestas del dueño, 7/nov/2026; spec 5 §8c)
-- =============================================================================
-- 1. Bitácora de cuidados: la cuidadora ve LO SUYO y lo que escriben para ella con Papá la hermana y el dueño. No ve
--    nada más: la pareja no escribe bitácora y no se le muestra la de nadie más. Dueño y hermana siguen viendo toda la
--    bitácora de cuidados (cui_puede no cambia). Cambia solo la política de lectura de cui_bitacora, con un ayudante
--    cui_autor_visible_cuidadora(hogar, persona): el autor es el dueño del hogar o tiene turnos de hermana.
-- 2. Turno residual del dueño: cui_quien_en_turno(hogar, ts) (misma firma y misma fuente de los recordatorios) devuelve
--    al dueño vigente (tipo 'dueno') cuando en ese instante no hay turno de cuidadora ni de hermana: noches, madrugadas
--    y huecos ya no devuelven nada. Con cuidadora o hermana de turno, todo queda igual que antes (el dueño solo aparece
--    si tiene turno propio). Un cambio urgente y los recordatorios de noche llegan así al dueño.
-- Migración hacia adelante; no edita las anteriores.
-- =============================================================================

-- 1. Bitácora ------------------------------------------------------------------------------------------------------
create function public.cui_autor_visible_cuidadora(p_hogar_id uuid, p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (select 1 from public.membresias m
                  where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.rol = 'dueno')
      or exists (select 1 from public.membresias m
                  join public.cui_turnos t on t.hogar_id = m.hogar_id and t.persona_id = m.persona_id
                 where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.rol = 'familiar'
                   and t.tipo = 'hermana_visita')
$$;
comment on function public.cui_autor_visible_cuidadora(uuid, uuid) is
  'Spec 5 §8c: ¿la cuidadora puede leer lo que escribió esta persona en la bitácora de cuidados? Solo el dueño y la hermana (con turnos de hermana_visita).';
revoke all on function public.cui_autor_visible_cuidadora(uuid, uuid) from public, anon;
grant execute on function public.cui_autor_visible_cuidadora(uuid, uuid) to authenticated;

drop policy cui_bitacora_leer on public.cui_bitacora;
create policy cui_bitacora_leer on public.cui_bitacora for select to authenticated
  using (public.cui_puede(hogar_id, 'bitacora', 'leer')
         and (public.cui_perfil(hogar_id) <> 'cuidadora'
              or persona_id = (select public.persona_actual())
              or public.cui_autor_visible_cuidadora(hogar_id, persona_id)));

-- 2. Turno residual del dueño ----------------------------------------------------------------------------------------
create or replace function public.cui_quien_en_turno(p_hogar_id uuid, p_ts timestamptz default now())
returns table (persona_id uuid, tipo text)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_zona  text := public.cui_zona(p_hogar_id);
  v_local timestamp := p_ts at time zone v_zona;
  v_dia   integer := extract(isodow from v_local)::int;
  v_min   integer := extract(hour from v_local)::int * 60 + extract(minute from v_local)::int;
begin
  -- Con sesión de usuario debe tener perfil en Cuidados; sin sesión solo llega el servidor (service_role).
  if auth.uid() is not null and public.cui_perfil(p_hogar_id) is null then
    return;
  end if;
  return query
    with base as (
      select t.persona_id as pid, t.tipo as tp, t.inicio_min as ini
        from public.cui_turnos t
        join public.membresias m on m.hogar_id = t.hogar_id and m.persona_id = t.persona_id
       where t.hogar_id = p_hogar_id and t.dia_semana = v_dia
         and v_min >= t.inicio_min and v_min < t.fin_min
         and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
         and ((t.tipo = 'dueno' and m.rol = 'dueno')
              or (t.tipo in ('cuidadora', 'hermana_visita') and m.rol in ('cuidador', 'familiar')))
    )
    select b.pid, b.tp from base b
    union all
    -- Residual (spec 5 §8c): sin cuidadora ni hermana de turno, cubre el dueño (si no aparece ya por turno propio).
    select m.persona_id, 'dueno'
      from public.membresias m
     where m.hogar_id = p_hogar_id and m.rol = 'dueno'
       and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and not exists (select 1 from base b where b.tp in ('cuidadora', 'hermana_visita'))
       and not exists (select 1 from base b where b.pid = m.persona_id)
    order by 2, 3 nulls first;
end
$$;
