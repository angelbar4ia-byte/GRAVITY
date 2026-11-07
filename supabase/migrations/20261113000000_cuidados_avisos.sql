-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados · 1/4: el aviso del cambio urgente (D4, D5, D20)
-- =============================================================================
-- docs/specs/fase-5-cuidados.md (secciones 1, 3 y 7.4). El dueño manda un cambio urgente desde su
-- teléfono y el servidor avisa al cuidador de turno al instante (cui_crear_cambio_urgente, migración
-- 20261115). Igual que con 'solicitud_vista' (20261110): catálogo cerrado, SIN texto libre en el aviso
-- (D3, D20): el aviso solo apunta al cambio (objeto_tipo 'cambio_urgente', objeto_id = cui_cambios_urgentes.id)
-- y la app lo lee con las reglas por rol.
--   - avisos.modulo admite 'cuidados' (el aviso no lleva libro: avisos_modulo_libro sigue igual).
--   - avisos.tipo admite 'cambio_urgente_cuidados' (severidad crítica: no se agrupa por el tope diario).
--   - avisos.objeto_tipo admite 'cambio_urgente'.
-- Migración hacia adelante: reemplaza checks y la función de severidad (conserva todos los tipos previos).
-- =============================================================================

alter table public.avisos drop constraint avisos_modulo_check;
alter table public.avisos add constraint avisos_modulo_check check (modulo in ('finanzas', 'sistema', 'cuidados'));

alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados'));

alter table public.avisos drop constraint avisos_objeto_tipo_check;
alter table public.avisos add constraint avisos_objeto_tipo_check check (objeto_tipo in (
  'deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'solicitud_vista', 'cambio_urgente'));

create or replace function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90', 'solicitud_vista', 'cambio_urgente_cuidados') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80')
      then 'importante'
    else 'informativa' end
$$;
