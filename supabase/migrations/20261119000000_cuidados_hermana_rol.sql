-- =============================================================================
-- GRAVITY · Fase 5 · La hermana es cuidadora por membresía (D5)
-- =============================================================================
-- D5 (confirmada): la hermana es "Cuidador (familiar)". Su acceso a Cuidados lo decide cui_perfil() por el tipo
-- de sus turnos (hermana_visita), no por una fila de familiar. Por eso se quitan las dos filas de familiar en
-- cuidados que puso 20261116: la matriz vuelve a su forma de la Fase 0 para familiar (sin acceso a Cuidados).
-- Migración hacia adelante.
-- =============================================================================

delete from public.permisos_rol
 where rol = 'familiar' and modulo = 'cuidados' and accion = 'leer';

delete from public.permisos_rol
 where rol = 'familiar' and modulo = 'cuidados' and accion = 'escribir';
