-- =============================================================================
-- GRAVITY · Fase 4 · D24: cada consulta de la vista de Papá queda en la bitácora
-- =============================================================================
-- Decisión del dueño (7/nov/2026): cada consulta queda registrada. Esta migración quita el tope de
-- una entrada por minuto que la función heredaba de la cuenta maestra (D19). Sigue sin montos,
-- cuentas ni motivo, y sin vista vigente sigue dando 42501.
-- Migración hacia adelante: reemplaza la función; los permisos se mantienen.
-- =============================================================================

create or replace function public.fin_registrar_consulta_vista()
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
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_sol.hogar_id, public.persona_actual(), 'finanzas.consulta_vista', 'fin_vistas_consultas',
          v_sol.id::text, jsonb_build_object('solicitud_id', v_sol.id));
end
$$;

comment on function public.fin_registrar_consulta_vista() is
  'D24/D19. El familiar con vista vigente la llama al consultar el libro de Papá: deja una entrada por consulta (quién y cuándo, sin montos ni cuentas). Sin vista vigente, 42501.';
