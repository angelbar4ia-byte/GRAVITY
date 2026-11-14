-- =============================================================================
-- GRAVITY · Fase 4 · Cada consulta de la vista temporal de Papá queda en la bitácora (D24, D19)
-- Decisión del dueño (7/nov/2026): hoy solo quedan el inicio y el fin de la vista.
-- Contenido nuevo:
--   fin_registrar_consulta_vista() returns void   Solo el familiar con vista vigente. Una entrada
--       'finanzas.consulta_vista' por consulta, sin montos ni cuentas (quién y cuándo). Mismo tope que
--       fin_registrar_consulta_maestra: una entrada por minuto y persona.
-- =============================================================================
create function public.fin_registrar_consulta_vista()
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_sol public.fin_vistas_solicitadas%rowtype;
begin
  if not public.fin_vista_papa_vigente() then
    raise exception using errcode = '42501', message = 'No hay una vista temporal vigente.';
  end if;
  select * into v_sol from public.fin_vistas_solicitadas s
   where s.solicitante_id = public.persona_actual() and s.estado = 'autorizada' and s.vigente_hasta > now()
   order by s.vigente_hasta desc limit 1;
  if exists (select 1 from public.bitacora b
              where b.accion = 'finanzas.consulta_vista' and b.persona_id = public.persona_actual()
                and b.registrado_en > now() - interval '1 minute') then
    return;  -- ya hay una entrada del último minuto: no engorda la bitácora
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_sol.hogar_id, public.persona_actual(), 'finanzas.consulta_vista', 'fin_vistas_consultas',
          v_sol.id::text, jsonb_build_object('solicitud_id', v_sol.id));
end
$$;
comment on function public.fin_registrar_consulta_vista() is
  'D24/D19. El familiar con vista vigente la llama al consultar el libro de Papá: deja una entrada (quién y cuándo, sin montos ni cuentas), una por minuto. Sin vista vigente, 42501.';

revoke execute on function public.fin_registrar_consulta_vista() from public, anon, authenticated, service_role;
grant execute on function public.fin_registrar_consulta_vista() to authenticated;
