-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, paquete F8-6.8: «pagos al corte» admite «sin dato»
-- (revisión de calidad docs/revisiones/finanzas-bloque-6.md, hallazgo H-02; D3, D6, D20)
-- =============================================================================
-- Problema: fin_estados_cuenta.pagos_al_corte_centavos era `not null default 0` (migración 20261146). Un estado de cuenta
-- importado sin que nadie capturara los pagos quedaba con 0, y el dominio lo leía como «pagó cero»: acusaba en falso al vampiro V-D
-- («intereses por pagar solo el mínimo») y ponía rojo el semáforo B6b de quien sí pagó.
--
-- Qué hace esta migración (hacia adelante; no edita 20261146 ni usa UPDATE en tablas solo-agregar):
-- 1. La columna admite NULO y pierde el `default 0`: nulo = «sin dato» (nadie capturó los pagos); un 0 capturado a propósito sigue
--    siendo «no pagó nada». El check `>= 0` se conserva (un nulo lo cumple).
-- 2. Filas ya existentes. Llevan 0 sin que nadie lo haya capturado (la app aún no escribe esa columna: solo la llenaba el valor por
--    omisión) y no se pueden corregir con UPDATE (el libro es solo-agregar). DECISIÓN: se dejan intactas y la vista de vigentes
--    (fin_v_estados_cuenta_vigentes, la vía de lectura) devuelve NULO para todo registro anterior a esta migración cuyo valor sea 0.
--    Un valor distinto de cero anterior sí se capturó a propósito (el valor por omisión era 0) y se respeta. Un 0 capturado desde
--    esta migración es un 0 real. La marca de tiempo se congela al aplicar la migración (now()) y queda escrita en el comentario
--    de la columna. Si se prefiere otra regla (por ejemplo, nulo solo para ciertas filas), es un cambio de la vista, no de datos.
-- 3. La vista conserva sus columnas, su orden y sus tipos (create or replace); solo cambia la expresión de pagos_al_corte_centavos.
--    Sigue con security_invoker y con los mismos privilegios.
-- Dinero en bigint de centavos. Sin secretos ni datos reales.
-- =============================================================================

alter table public.fin_estados_cuenta alter column pagos_al_corte_centavos drop not null;
alter table public.fin_estados_cuenta alter column pagos_al_corte_centavos drop default;

do $$
declare
  v_corte timestamptz := now();
  v_cols  text;
begin
  select string_agg(
           case when a.attname = 'pagos_al_corte_centavos'
                then format('case when e.registrado_en < %L::timestamptz and e.pagos_al_corte_centavos = 0 then null '
                            'else e.pagos_al_corte_centavos end::bigint as pagos_al_corte_centavos', v_corte)
                else format('e.%I', a.attname) end,
           ', ' order by a.attnum)
    into v_cols
  from pg_attribute a
  where a.attrelid = 'public.fin_estados_cuenta'::regclass and a.attnum > 0 and not a.attisdropped;

  execute 'create or replace view public.fin_v_estados_cuenta_vigentes with (security_invoker = true) as '
          'select distinct on (e.deuda_id, e.fecha_corte) ' || v_cols ||
          ' from public.fin_estados_cuenta e order by e.deuda_id, e.fecha_corte, e.registrado_en desc, e.id desc';

  execute format('comment on column public.fin_estados_cuenta.pagos_al_corte_centavos is %L',
    'Pagos hechos entre el corte y la fecha límite de pago (B6b y V-D: ¿pagó el total, o solo el mínimo?). Nulo = sin dato '
    '(nadie los capturó); 0 = se capturó que no pagó nada. Los registros anteriores a ' || v_corte::text ||
    ' con valor 0 llevaban ese 0 por omisión: la vista de vigentes los devuelve como nulo.');
end $$;
