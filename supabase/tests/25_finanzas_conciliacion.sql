-- Criterio 14 (5.0 bis 2-5): una conciliación con diferencia crea un ajuste
-- con motivo contra la cuenta Ajustes del libro, queda en la bitácora y el
-- ajuste se ve siempre. La conciliación es solo agregar.
begin;
select pruebas.como('ana@ejemplo.test');

select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001'),
  1780000::bigint, 'Saldo calculado del banco de Ana: $17,800.00');

-- Declara $17,803.00: diferencia de +$3.00 → ajuste Ajustes → banco, con motivo.
select pruebas.ok(
  pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
                    'c3000000-0000-4000-8000-000000000001', 300, '2026-10-21',
                    'Intereses que no había registrado (ejemplo)', p_id => 'd3000000-0000-4000-8000-000000000001') is not null,
  'Primero se registra el ajuste, con motivo');
select pruebas.igual(pruebas.afecta($$insert into public.fin_conciliaciones (id, hogar_id, cuenta_id, fecha,
  saldo_declarado, saldo_calculado, ajuste_movimiento_id, motivo)
  values ('eb000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
          'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1780300, 1780000,
          'd3000000-0000-4000-8000-000000000001', 'Intereses que no había registrado (ejemplo)')$$), 1,
  'Luego la conciliación que lo referencia');
select pruebas.igual(
  (select diferencia || ' ' || (libro_id = pruebas.libro_personal('ana@ejemplo.test')) || ' ' || (persona_id = pruebas.id_persona('ana@ejemplo.test'))
     from public.fin_conciliaciones where id = 'eb000000-0000-4000-8000-000000000002'),
  '300 true true', 'La diferencia, el libro y quién concilió los pone el servidor');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001'),
  1780300::bigint, 'Tras el ajuste, el saldo calculado es el declarado');
select pruebas.ok(
  exists (select 1 from public.bitacora where tabla = 'fin_conciliaciones'
           and registro_id = 'eb000000-0000-4000-8000-000000000002' and persona_id = pruebas.id_persona('ana@ejemplo.test'))
  and exists (select 1 from public.bitacora where tabla = 'fin_movimientos'
           and registro_id = 'd3000000-0000-4000-8000-000000000001'
           and detalle -> 'despues' ->> 'motivo' = 'Intereses que no había registrado (ejemplo)'),
  'La conciliación y el ajuste con su motivo quedan en la bitácora');
select pruebas.ok(exists (select 1 from public.fin_movimientos where tipo = 'ajuste'
                            and id = 'd3000000-0000-4000-8000-000000000001'),
  'El ajuste se ve siempre en el libro');

-- Pasivo: la tarjeta debe $2.00 más de lo calculado → ajuste tarjeta → Ajustes.
select pruebas.ok(
  pruebas.registrar('ajuste', 'c3000000-0000-4000-8000-000000000003',
                    pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'), 200, '2026-10-21',
                    'Comisión del estado de cuenta (ejemplo)', p_id => 'd3000000-0000-4000-8000-000000000002') is not null
  and pruebas.afecta($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
        saldo_calculado, ajuste_movimiento_id, motivo)
        values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003', '2026-10-21',
                505200, 505000, 'd3000000-0000-4000-8000-000000000002', 'Comisión del estado de cuenta (ejemplo)')$$) = 1,
  'En un pasivo que sube, el ajuste va de la cuenta a Ajustes');

-- Sin diferencia: no hace falta ajuste.
select pruebas.igual(pruebas.afecta($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha,
  saldo_declarado, saldo_calculado)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1780300, 1780300)$$), 1,
  'Una conciliación sin diferencia no lleva ajuste');

-- ---------------------------------------------------------------- errores
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002', '2026-10-21', 100, 200, 'x')$$,
  'Con diferencia, la conciliación exige su ajuste', '23514');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1780300, 1780000,
          'd3000000-0000-4000-8000-000000000001')$$,
  'Con diferencia, el motivo es obligatorio', '23514');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1780300, 1780000,
          'd3000000-0000-4000-8000-000000000001', 'Otra vez')$$,
  'Un ajuste sirve a una sola conciliación', '23505');
select pruebas.registrar('ajuste', 'c3000000-0000-4000-8000-000000000001',
                         pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'), 200, '2026-10-21',
                         'Al revés', p_id => 'd3000000-0000-4000-8000-000000000003');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1780300, 1780100,
          'd3000000-0000-4000-8000-000000000003', 'x')$$,
  'El ajuste va en la dirección de la diferencia', '22023');
select pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
                         'c3000000-0000-4000-8000-000000000001', 150, '2026-10-21',
                         'Monto distinto', p_id => 'd3000000-0000-4000-8000-000000000004');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1780400, 1780200,
          'd3000000-0000-4000-8000-000000000004', 'x')$$,
  'El ajuste es por el monto de la diferencia', '22023');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', '2026-10-22', 1780350, 1780200,
          'd3000000-0000-4000-8000-000000000004', 'x')$$,
  'Y con la fecha de la conciliación', '22023');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002', '2026-10-13', 0, 4500,
          'd1000000-0000-4000-8000-000000000005', 'x')$$,
  'Un gasto no es un ajuste de conciliación', '22023');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado, saldo_calculado)
  values ('b0000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', '2026-10-21', 0, 0)$$,
  'Solo se concilian activos y pasivos', '22023');

-- ---------------------------------------------------------------- quién
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_conciliaciones'), 0,
  'Alex no ve las conciliaciones del libro de Ana');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, libro_id, cuenta_id, fecha, saldo_declarado, saldo_calculado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'c3000000-0000-4000-8000-000000000001', '2026-10-21', 1, 1)$$,
  'Ni concilia cuentas de Ana', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado, saldo_calculado)
  values ('b0000000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000002', '2026-10-21', 0, 0)$$), 1,
  'Alex concilia la caja chica del compartido');

rollback;
