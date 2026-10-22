-- Criterio 25: nadie (ni el dueño, ni service_role, ni el dueño de las tablas)
-- edita, borra ni vacía un movimiento, una conciliación, un cierre o una
-- importación. Criterio 9: un gasto de una semana cerrada se corrige con
-- anulación y contraasiento, y la semana se recalcula. Criterio 16: la foto
-- de un cierre guardado no cambia con correcciones posteriores.
begin;

create temporary table antes on commit drop as
  select t.tabla, pruebas.cuenta(format('select * from public.%I', t.tabla)) as filas
  from unnest(array['fin_movimientos', 'fin_conciliaciones', 'fin_cierres', 'fin_cierre_partidas',
                    'fin_cierre_abonos', 'fin_importaciones']) as t(tabla);

do $$
declare
  v_tabla text;
  v_quien text;
begin
  foreach v_tabla in array array['fin_movimientos', 'fin_conciliaciones', 'fin_cierres', 'fin_cierre_partidas',
                                 'fin_cierre_abonos', 'fin_importaciones']
  loop
    foreach v_quien in array array['ana@ejemplo.test', 'alex@ejemplo.test', 'marta@ejemplo.test',
                                   'service_role', 'postgres']
    loop
      if v_quien = 'service_role' then
        perform pruebas.como_servicio();
      elsif v_quien = 'postgres' then
        perform pruebas.como_postgres();
      else
        perform pruebas.como(v_quien);
      end if;
      perform pruebas.falla(format('update public.%I set hogar_id = hogar_id', v_tabla),
        format('%s no edita %s', v_quien, v_tabla), '42501');
      perform pruebas.falla(format('delete from public.%I', v_tabla),
        format('%s no borra %s', v_quien, v_tabla), '42501');
      perform pruebas.falla(format('truncate public.%I cascade', v_tabla),
        format('%s no vacía %s', v_quien, v_tabla), '42501');
    end loop;
  end loop;
end
$$;
select pruebas.como_postgres();
select pruebas.ok(
  (select bool_and(pruebas.cuenta(format('select * from public.%I', a.tabla)) = a.filas) from antes a),
  'Los libros solo agregar siguen intactos');
select pruebas.igual(
  (select monto_centavos || ' ' || tipo || ' ' || fecha from public.fin_movimientos
    where id = 'd1000000-0000-4000-8000-000000000005'),
  '4500 gasto 2026-10-13', 'El gasto de la semana cerrada sigue igual');

-- ---------------------------------------------------------------- criterio 9
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(
  (select estado from public.fin_semanas where id = 'e6000000-0000-4000-8000-000000000001'),
  'cerrada', 'La semana del 12/oct de Ana está cerrada');
select pruebas.igual(
  (select gasto_centavos from public.fin_v_gasto_semana
    where libro_id = pruebas.libro_personal('ana@ejemplo.test') and semana_inicio = '2026-10-12'
      and cuenta_id = 'c2000000-0000-4000-8000-000000000004'),
  4500::bigint, 'Antes: Transporte gastó $45.00 esa semana');
select pruebas.ok(
  pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000004', 'c3000000-0000-4000-8000-000000000002', 4500,
                    '2026-10-13', 'Monto equivocado (ejemplo)', 'd1000000-0000-4000-8000-000000000005',
                    p_id => 'd2000000-0000-4000-8000-000000000001') is not null,
  'Se anula el gasto de la semana cerrada: contraasiento con la misma fecha y motivo');
select pruebas.ok(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000004', 3500,
                    '2026-10-13') is not null,
  'Y se registra el monto correcto con su fecha');
select pruebas.igual(
  (select gasto_centavos from public.fin_v_gasto_semana
    where libro_id = pruebas.libro_personal('ana@ejemplo.test') and semana_inicio = '2026-10-12'
      and cuenta_id = 'c2000000-0000-4000-8000-000000000004'),
  3500::bigint, 'La semana se recalcula: Transporte gastó $35.00');
select pruebas.igual(
  (select monto_centavos from public.fin_movimientos where id = 'd1000000-0000-4000-8000-000000000005'),
  4500::bigint, 'El original no se editó');
select pruebas.igual(
  (select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000002'),
  184000::bigint, 'El efectivo queda con la corrección (183,000 + 4,500 − 3,500 centavos)');

-- ---------------------------------------------------------------- criterio 16
select pruebas.igual(
  (select activos || '/' || pasivos || '/' || patrimonio || '/' || gasto_real
     from public.fin_cierres where id = 'e9000000-0000-4000-8000-000000000001'),
  '1975500/805000/1170500/37577', 'La foto del cierre y del balance no cambia con la corrección');
select pruebas.igual(
  (select gastado from public.fin_cierre_partidas where id = 'e9000000-0000-4000-8000-000000000011'),
  4500::bigint, 'Ni lo gastado que guardó el cierre en esa partida');
select pruebas.falla($$update public.fin_partidas_semana set asignado = 1
  where id = 'e7000000-0000-4000-8000-000000000011'$$,
  'El plan de una semana cerrada no cambia', '55000');
select pruebas.falla($$update public.fin_abonos_semana set abono_planeado = 1
  where id = 'e8000000-0000-4000-8000-000000000011'$$,
  'Ni sus abonos', '55000');
select pruebas.falla($$update public.fin_semanas set ingreso = 1 where id = 'e6000000-0000-4000-8000-000000000001'$$,
  'Ni la semana', '55000');

-- ---------------------------------------------------------------- reglas de la anulación
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000004',
  'c3000000-0000-4000-8000-000000000002', 4500, '2026-10-13', 'Otra vez', 'd1000000-0000-4000-8000-000000000005')$$,
  'Un movimiento se anula una sola vez', '23505');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000004', 4500, '2026-10-13', 'x', 'd2000000-0000-4000-8000-000000000001')$$,
  'No se anula un contraasiento', '22023');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000008',
  'c3000000-0000-4000-8000-000000000003', 1000, '2026-10-14', 'x', 'd1000000-0000-4000-8000-000000000006')$$,
  'El contraasiento lleva el mismo monto', '22023');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000003',
  'c2000000-0000-4000-8000-000000000008', 25000, '2026-10-14', 'x', 'd1000000-0000-4000-8000-000000000006')$$,
  'Con origen y destino invertidos', '22023');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000008',
  'c3000000-0000-4000-8000-000000000003', 25000, '2026-10-14', null, 'd1000000-0000-4000-8000-000000000006')$$,
  'Y con motivo', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000004', 100, '2026-10-21', 'x', 'd1000000-0000-4000-8000-000000000006')$$,
  'anula_a solo va en una anulación', '23514');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000008',
  'c3000000-0000-4000-8000-000000000003', 25000, '2026-10-14', 'x', 'd9999999-0000-4000-8000-000000000001')$$,
  'No se anula lo que no existe (o aún no se sube: se reintenta)', '23503');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000008',
  'c3000000-0000-4000-8000-000000000003', 25000, '2026-10-14', 'Deshecho al capturar')$$,
  'Una anulación dice qué movimiento anula (no se reintenta: 23514)', '23514');
select pruebas.igual(
  (select count(*)::int from public.fin_movimientos where anula_a = 'd1000000-0000-4000-8000-000000000006'), 0,
  'El cine de Ana sigue sin anular');

rollback;
