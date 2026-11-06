-- =============================================================================
-- GRAVITY · Fase 2 · Ajustes de avisos para plataforma
-- =============================================================================
--   * avisos_porcentaje_base(): porcentaje de la base usado, solo para el dueño
--     (Ajustes > Copias de seguridad). Solo lectura; no revela nada más de avisos_sistema.
--   * La clave de los avisos de vencimiento y la columna dispositivos.recibe_avisos se documentan
--     y se prueban en supabase/README.md y en la prueba 87.
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior.
-- =============================================================================
create function public.avisos_porcentaje_base()
returns numeric
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_limite bigint;
begin
  if not exists (select 1 from public.membresias m where m.persona_id = public.persona_actual() and m.rol = 'dueno'
                  and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
    raise exception using errcode = '42501', message = 'Solo el dueño ve el porcentaje de la base.';
  end if;
  select (valor #>> '{}')::bigint into v_limite from public.avisos_sistema where clave = 'limite_base_bytes';
  if coalesce(v_limite, 0) <= 0 then
    return null;
  end if;
  return round(pg_catalog.pg_database_size(pg_catalog.current_database())::numeric * 100 / v_limite, 1);
end
$$;
comment on function public.avisos_porcentaje_base() is
  'Solo el dueño: porcentaje de la base usado respecto del límite (null si no hay límite). Solo lectura.';
revoke execute on function public.avisos_porcentaje_base() from public, anon, authenticated, service_role;
grant execute on function public.avisos_porcentaje_base() to authenticated;
