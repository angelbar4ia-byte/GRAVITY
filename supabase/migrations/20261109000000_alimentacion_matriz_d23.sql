-- =============================================================================
-- GRAVITY · Fase 4 · Matriz de Alimentación según D23 (ajuste del 6/nov/2026)
-- =============================================================================
-- docs/DECISIONES.md D23 y la revisión docs/revisiones/fase-4.md (F4-A2/A3, I1).
-- - El familiar edita el menú de Papá (no el de la pareja): fila escribir, restringido.
-- - Casa no ve Alimentación: se quita su fila de leer (sin fila = sin acceso). La tablet pública
--   no muestra el menú ni la lista de Papá (D3: el perfil clínico no sale a la tablet).
-- La decisión fina la aplica ali_puede() (migración 20261108); esta matriz solo debe reflejar la app.
-- Sigue siendo una migración hacia adelante: la base no se edita.
-- =============================================================================

update public.permisos_rol
   set nota = 'D23 (ajuste 6/nov): lee su parte; el familiar edita solo el menú de papá (ali_puede)'
 where rol = 'familiar' and modulo = 'alimentacion' and accion = 'leer';

insert into public.permisos_rol (rol, modulo, accion, alcance, nota)
values ('familiar', 'alimentacion', 'escribir', 'restringido',
        'D23 (ajuste 6/nov): edita solo el menú de papá (ali_puede)');

delete from public.permisos_rol
 where rol = 'casa' and modulo = 'alimentacion' and accion = 'leer';
