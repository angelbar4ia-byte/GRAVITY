-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados · 4/4: matriz de permisos (permisos_rol)
-- =============================================================================
-- docs/specs/fase-5-cuidados.md §2 y §5. La decisión fina la toma cui_puede() (migración 20261114): permisos_rol solo es
-- el espejo que lee la app para mostrar u ocultar el módulo (mis_permisos). Cambios:
--  - La hermana es 'familiar' (Cuidador familiar, §2; igual que en Alimentación D23): entra a Cuidados con alcance
--    restringido (sus visitas y los martes, resumen autorizado por el albacea) en leer y escribir (bitácora, entrega, gastos).
--    Sin turnos asignados por el dueño no tiene acceso (cui_perfil).
--  - Notas del coadministrador y del cuidador al día con las reglas de Fase 5.
-- Migración hacia adelante.
-- =============================================================================

insert into public.permisos_rol (rol, modulo, accion, alcance, nota)
values
  ('familiar', 'cuidados', 'leer',     'restringido', 'Fase 5: la hermana lee sus turnos y visitas, medicamentos y comidas, y el resumen mensual si el albacea lo autoriza (cui_puede)'),
  ('familiar', 'cuidados', 'escribir', 'restringido', 'Fase 5: la hermana escribe bitácora, entregas de turno y sus gastos de cuidado (cui_puede)');

update public.permisos_rol
   set nota = 'Fase 5: turnos y resumen de Papá, medicamentos y comidas solo con su consentimiento, nunca la bitácora (cui_puede)'
 where rol = 'coadministrador' and modulo = 'cuidados' and accion = 'leer';

update public.permisos_rol
   set nota = 'Fase 5: sus propios gastos de cuidado (cui_puede)'
 where rol = 'coadministrador' and modulo = 'cuidados' and accion = 'escribir';

update public.permisos_rol
   set nota = 'Fase 5: su turno, marca dado solo a la hora de su turno (cui_marcar_toma), no ve la familia fuera de Cuidados'
 where rol = 'cuidador' and modulo = 'cuidados' and accion = 'escribir';
