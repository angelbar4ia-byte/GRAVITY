-- Finanzas · Fase 8, bloque 2: deudas e intereses (docs/specs/fase-8-deudas-intereses.md v1.0).
-- Simulador de estrategias, estimador de intereses y beneficios de tarjetas.
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra). Se usa el libro personal de Alex (sin deudas en el seed).
-- Escenario (centavos, tasas en puntos base):
--   D1 Tarjeta X  saldo 1 000 000, 48 %, mínimo 50 000, límite 20/nov  (tarjeta)
--   D2 Préstamo   saldo   500 000, 12 %, mínimo 30 000, límite 10/nov  (la que vence antes)
--   D3 Cuenta     saldo   200 000, 24 %, mínimo 20 000, límite 15/nov
begin;

create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;
insert into t_ids values ('libro', pruebas.libro_personal('alex@ejemplo.test'));

-- ---------------------------------------------------------------- 0: preparación (Alex lleva su libro)
select pruebas.como('alex@ejemplo.test');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c4700000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Tarjeta X (ejemplo)', 'tarjeta'),
  ('c4700000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Préstamo (ejemplo)', 'prestamo'),
  ('c4700000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Cuenta (ejemplo)', 'prestamo'),
  ('c4700000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Sin saldo (ejemplo)', 'prestamo');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia,
                               minimo_centavos, tasa_anual_pb, fecha_limite, dato_verificado) values
  ('e5700000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Tarjeta X', 'con_costo', 'c4700000-0000-4000-8000-000000000001', 100000, 'mensual', 50000, 4800, '2026-11-20', true),
  ('e5700000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Préstamo', 'con_costo', 'c4700000-0000-4000-8000-000000000002', 50000, 'mensual', 30000, 1200, '2026-11-10', false),
  ('e5700000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Cuenta', 'con_costo', 'c4700000-0000-4000-8000-000000000003', 20000, 'mensual', 20000, 2400, '2026-11-15', false);
select pruebas.registrar('apertura', 'c4700000-0000-4000-8000-000000000001', pruebas.cuenta_sistema(pruebas.libro_personal('alex@ejemplo.test'), 'apertura'), 1000000);
select pruebas.registrar('apertura', 'c4700000-0000-4000-8000-000000000002', pruebas.cuenta_sistema(pruebas.libro_personal('alex@ejemplo.test'), 'apertura'), 500000);
select pruebas.registrar('apertura', 'c4700000-0000-4000-8000-000000000003', pruebas.cuenta_sistema(pruebas.libro_personal('alex@ejemplo.test'), 'apertura'), 200000);

select pruebas.igual((select dato_verificado::text || '/' || tasa_pendiente::text from public.fin_deudas
   where id = 'e5700000-0000-4000-8000-000000000002'), 'false/false',
  '0: un dato capturado a mano queda no verificado (por omisión)');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos,
  frecuencia, tasa_anual_pb) values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
  'Sin tasa', 'con_costo', 'c4700000-0000-4000-8000-000000000004', 1, 'mensual', 0)$$,
  '0: una deuda con costo sin tasa y sin marcarla pendiente se rechaza', '23514');

-- ---------------------------------------------------------------- 1: las tres estrategias (criterios 1 y 2)
select pruebas.igual((select count(*)::int from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')), 3, '1: tres estrategias');
select pruebas.igual((select string_agg(estado, ',' order by estrategia) from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')), 'ok,ok,ok', '1: las tres calculan');
select pruebas.igual((select count(distinct capital_centavos)::int from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')), 1,
  '1 (criterio 1): las tres pagan el mismo capital');
select pruebas.igual((select max(capital_centavos) from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')), 1700000::bigint,
  '1: y es la suma de los saldos de las tres deudas');
select pruebas.ok((select bool_and(total_pagado_centavos = capital_centavos + intereses_centavos)
   from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')),
  '1: total pagado = capital + intereses');
select pruebas.ok(
  (select intereses_centavos from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 300000, '2026-11-08'))
  < (select intereses_centavos from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'bola_de_nieve', 300000, '2026-11-08')),
  '1 (criterio 2): la avalancha paga menos intereses que la bola de nieve cuando las tasas difieren');
select pruebas.igual((select estrategia from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08') where recomendada), 'avalancha',
  '1: se recomienda la de menor interés (y solo una)');
select pruebas.igual((select count(*)::int from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08') where recomendada), 1, '1: una sola recomendada');
select pruebas.igual((select (orden)[1] from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'bola_de_nieve', 300000, '2026-11-08')),
  'e5700000-0000-4000-8000-000000000003'::uuid, '1: bola de nieve liquida primero la de saldo más chico');
select pruebas.igual((select (orden)[1] from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 300000, '2026-11-08')),
  'e5700000-0000-4000-8000-000000000001'::uuid, '1: avalancha liquida primero la de tasa más alta (por tasa, no por saldo)');
select pruebas.igual((select (orden)[1] from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'vencimiento', 800000, '2026-11-08')),
  'e5700000-0000-4000-8000-000000000002'::uuid, '1: vencimiento liquida primero la que vence antes');
select pruebas.igual((select cardinality(orden) from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 300000, '2026-11-08')),
  3, '1: el orden trae las tres deudas');
select pruebas.igual((select presupuesto_mensual_centavos from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', null, '2026-11-08')),
  100000::bigint, '1 (v1.1): sin presupuesto, usa la suma de los pagos mínimos (50 000 + 30 000 + 20 000)');
select pruebas.igual((select presupuesto_mensual_centavos from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 250000, '2026-11-08')),
  250000::bigint, '1 (v1.1): si la persona pide otro monto, se usa ese');
select pruebas.igual((select estado from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 99999, '2026-11-08')),
  'no_alcanza', '1 (v1.1): un monto menor que la suma de mínimos no alcanza');
select pruebas.igual((select estado from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 100000, '2026-11-08')),
  'ok', '1 (v1.1): justo la suma de mínimos sí alcanza');
select pruebas.ok((select bool_and(estado = 'ok') from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), null, null, '2026-11-08')),
  '1 (v1.1): sin presupuesto las tres estrategias calculan con la suma de mínimos');
select pruebas.falla($$select * from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'azar')$$,
  '1: una estrategia desconocida se rechaza', '22023');
select pruebas.igual((select estado from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 50000, '2026-11-08')),
  'no_alcanza', '1: un presupuesto menor que los mínimos no alcanza (no inventa un plan)');

-- ---------------------------------------------------------------- 2: vencimiento (criterio 3)
-- Hoy 12/nov: el préstamo (10/nov) ya venció. Con liquidez para liquidarlo, la estrategia por vencimiento lo cubre.
select pruebas.igual((select vencidas_sin_liquidar_mes1 from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), 'vencimiento', 800000, '2026-11-12')), 0,
  '2 (criterio 3): con liquidez, por vencimiento no queda deuda vencida sin liquidar');
select pruebas.igual((select vencidas_sin_liquidar_mes1 from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), 'avalancha', 800000, '2026-11-12')), 1,
  '2: la avalancha, con la misma liquidez, sí deja la vencida sin liquidar');

-- Ciclos futuros (v1.1): D2 vence en el mes 3 (10/ene); D1 y D3 no tienen urgencia (junio y julio). Liquidez: mínimos
-- (100 000) + 150 000 de extra, que no alcanza para dos deudas a la vez.
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000001', 4800, 50000, '2027-06-20', false);
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000002', 1200, 30000, '2027-01-10', false);
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000003', 2400, 20000, '2027-07-15', false);
select pruebas.igual((select (orden)[1] from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'vencimiento', 250000, '2026-11-08')),
  'e5700000-0000-4000-8000-000000000002'::uuid,
  '2 (v1.1): la deuda con vencimiento en el mes 3 se liquida antes que la que no tiene urgencia');
create temp table t_venc as
  select intereses_centavos as i3 from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'vencimiento', 250000, '2026-11-08');
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000002', 1200, 30000, '2026-11-10', false);
select pruebas.ok((select t.i3 < e.intereses_centavos from t_venc t,
   public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'vencimiento', 250000, '2026-11-08') e),
  '2 (v1.1): sin urgencia en los meses 1 y 2, el extra va a la de mayor tasa (menos intereses que con vencimiento en el mes 1)');
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000001', 4800, 50000, '2026-11-20', false);
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000003', 2400, 20000, '2026-11-15', false);

-- ---------------------------------------------------------------- 3: un dato faltante bloquea solo a quien lo necesita (criterio 4)
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000003', 2400, 20000, null, false);
select pruebas.igual((select string_agg(estrategia || '=' || estado, ',' order by estrategia)
   from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')),
  'avalancha=ok,bola_de_nieve=ok,vencimiento=falta_dato',
  '3 (criterio 4): sin fecha límite, solo la estrategia por vencimiento dice falta_dato');
select pruebas.igual((select falta from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'vencimiento', 300000, '2026-11-08')),
  array['fecha_limite']::text[], '3: y dice qué falta');
select pruebas.ok((select intereses_centavos is null and total_pagado_centavos is null and orden is null
   from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'vencimiento', 300000, '2026-11-08')),
  '3: falta_dato no trae cifras (no estima)');
-- Tasa desconocida (nula = pendiente): la necesitan las tres para calcular el interés.
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000003', null, 20000, '2026-11-15', false);
select pruebas.igual((select tasa_pendiente::text || '/' || tasa_anual_pb::text from public.fin_deudas
   where id = 'e5700000-0000-4000-8000-000000000003'), 'true/0', '3: tasa nula = pendiente');
select pruebas.igual((select string_agg(estrategia || '=' || estado || ':' || array_to_string(falta, '+'), ',' order by estrategia)
   from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')),
  'avalancha=falta_dato:tasa,bola_de_nieve=falta_dato:tasa,vencimiento=falta_dato:tasa', '3: sin tasa no se estima ninguna');
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000003', 2400, 20000, '2026-11-15', true);
select pruebas.igual((select string_agg(distinct estado, ',') from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')), 'ok', '3: con el dato completo vuelven a calcular');
select pruebas.ok((select dato_verificado from public.fin_deudas where id = 'e5700000-0000-4000-8000-000000000003'),
  '3: el dato verificado queda marcado');
-- Saldo desconocido: una deuda activa sin ningún movimiento en su cuenta.
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia,
                               minimo_centavos, tasa_anual_pb, fecha_limite) values
  ('e5700000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'),
   'Sin saldo', 'con_costo', 'c4700000-0000-4000-8000-000000000004', 1000, 'mensual', 1000, 1000, '2026-11-30');
select pruebas.igual((select string_agg(estado || ':' || array_to_string(falta, '+'), ',' order by estrategia)
   from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')),
  'falta_dato:saldo,falta_dato:saldo,falta_dato:saldo', '3: sin saldo conocido no se estima');
update public.fin_deudas set activa = false where id = 'e5700000-0000-4000-8000-000000000004';
select pruebas.igual((select string_agg(distinct estado, ',') from public.fin_simular_estrategias(
  (select id from t_ids where clave = 'libro'), null, 300000, '2026-11-08')), 'ok', '3: dada de baja, ya no bloquea');

-- ---------------------------------------------------------------- 4: estimador de intereses
select pruebas.igual((select count(*)::int from public.fin_estimar_intereses((select id from t_ids where clave = 'libro'), 300000, '2026-11-08')),
  4, '4: pago mínimo y tres estrategias');
select pruebas.igual((select string_agg(escenario, ',' order by escenario) from public.fin_estimar_intereses(
  (select id from t_ids where clave = 'libro'), 300000, '2026-11-08')), 'avalancha,bola_de_nieve,pago_minimo,vencimiento',
  '4: los escenarios');
select pruebas.ok((select m.intereses_centavos > a.intereses_centavos
   from public.fin_estimar_intereses((select id from t_ids where clave = 'libro'), 300000, '2026-11-08') m,
        public.fin_estimar_intereses((select id from t_ids where clave = 'libro'), 300000, '2026-11-08') a
  where m.escenario = 'pago_minimo' and a.escenario = 'avalancha'),
  '4: pagar solo el mínimo cuesta más intereses que la avalancha');
select pruebas.ok((select ahorro_vs_minimo_centavos > 0 from public.fin_estimar_intereses(
  (select id from t_ids where clave = 'libro'), 300000, '2026-11-08') where escenario = 'avalancha'),
  '4: el ahorro frente al mínimo es positivo');
select pruebas.ok((select a.intereses_centavos = e.intereses_centavos
   from public.fin_estimar_intereses((select id from t_ids where clave = 'libro'), 300000, '2026-11-08') a,
        public.fin_simular_estrategias((select id from t_ids where clave = 'libro'), 'avalancha', 300000, '2026-11-08') e
  where a.escenario = 'avalancha'), '4: el estimador y el simulador coinciden');
select pruebas.igual((select ahorro_vs_minimo_centavos is null from public.fin_estimar_intereses(
  (select id from t_ids where clave = 'libro'), 300000, '2026-11-08') where escenario = 'pago_minimo'), true,
  '4: el escenario del mínimo no tiene ahorro');
-- Mínimo desconocido (0) solo bloquea el escenario del mínimo.
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000002', 1200, 0, '2026-11-10', false);
select pruebas.igual((select estado || ':' || array_to_string(falta, '+') from public.fin_estimar_intereses(
  (select id from t_ids where clave = 'libro'), 300000, '2026-11-08') where escenario = 'pago_minimo'), 'falta_dato:pago_minimo',
  '4: sin pago mínimo, el escenario del mínimo dice falta_dato');
select pruebas.igual((select estado from public.fin_estimar_intereses(
  (select id from t_ids where clave = 'libro'), 300000, '2026-11-08') where escenario = 'avalancha'), 'ok',
  '4: … y las estrategias siguen calculando');
select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000002', 1200, 30000, '2026-11-10', false);

-- ---------------------------------------------------------------- 5: tarjetas y beneficios (RPC)
select pruebas.igual(public.fin_tarjeta_guardar('a1070000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Banco Ejemplo', 'Oro', 5000000, 5::smallint, 25::smallint,
  'e5700000-0000-4000-8000-000000000001'),
  'a1070000-0000-4000-8000-000000000001'::uuid, '5: Alex da de alta su tarjeta');
select pruebas.igual(public.fin_tarjeta_guardar('a1070000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Banco Ejemplo', 'Oro', 5000000, 5::smallint, 25::smallint,
  'e5700000-0000-4000-8000-000000000001'),
  'a1070000-0000-4000-8000-000000000001'::uuid, '5: reenviar lo mismo es idempotente');
select pruebas.igual((select count(*)::int from public.fin_tarjetas), 1, '5: una tarjeta');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-000000000002', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('carla@ejemplo.test'), 'Banco Ejemplo', 'Otra')$$,
  '5: la titular debe llevar el libro', '22023');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-000000000002', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Banco Ejemplo', 'Otra', 100, 32::smallint)$$,
  '5: el día de corte es de 0 a 31', '23514');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-000000000002', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'Banco Ejemplo', 'Otra', 100, 5::smallint, 25::smallint, 'e5700000-0000-4000-8000-000000000002')$$,
  '5: la deuda de una tarjeta es de clase tarjeta', '22023');
select pruebas.igual(public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b1', 'a1070000-0000-4000-8000-000000000001',
  'cashback', 'Devolución en supermercados', '2026-11-01', '2026-12-31'),
  'a1070000-0000-4000-8000-0000000000b1'::uuid, '5: beneficio de cashback');
select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b2', 'a1070000-0000-4000-8000-000000000001',
  'meses_sin_intereses', '3 y 6 meses en tiendas', '2026-11-01');
select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b3', 'a1070000-0000-4000-8000-000000000001',
  'puntos', 'Puntos dobles en gasolina', '2026-11-01');
select pruebas.igual((select count(*)::int from public.fin_tarjeta_beneficios), 3, '5: tres beneficios');
select pruebas.falla($$select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b4', 'a1070000-0000-4000-8000-000000000001',
  'millas', 'Millas', '2026-11-01')$$, '5: el tipo es puntos, cashback o meses sin intereses', '23514');
select pruebas.falla($$select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b4', 'a1070000-0000-4000-8000-000000000001',
  'puntos', 'Saldo a favor de $500', '2026-11-01')$$, '5: la descripción no lleva cifras de saldo ($)', '23514');
select pruebas.falla($$select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b4', 'a1070000-0000-4000-8000-000000000001',
  'puntos', 'Saldo 123456', '2026-11-01')$$, '5: ni números largos', '23514');
select pruebas.falla($$select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b4', 'a1070000-0000-4000-8000-000000000001',
  'puntos', 'Vigencia al revés', '2026-11-10', '2026-11-01')$$, '5: la vigencia no termina antes de empezar', '23514');
-- Escritura directa y borrados: nada (solo RPC; baja = activa false).
select pruebas.falla($$insert into public.fin_tarjetas (hogar_id, libro_id, titular_id, banco, nombre)
  values ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'),
          pruebas.id_persona('alex@ejemplo.test'), 'B', 'N')$$, '5: no hay INSERT directo de tarjetas', '42501');
select pruebas.falla($$update public.fin_tarjetas set banco = 'X'$$, '5: ni UPDATE directo', '42501');
select pruebas.falla($$delete from public.fin_tarjetas$$, '5: ni DELETE', '42501');
select pruebas.falla($$insert into public.fin_tarjeta_beneficios (hogar_id, libro_id, tarjeta_id, tipo, descripcion, vigente_desde)
  values ('b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'libro'),
          'a1070000-0000-4000-8000-000000000001', 'puntos', 'x', '2026-11-01')$$, '5: no hay INSERT directo de beneficios', '42501');
select public.fin_tarjeta_beneficio_guardar('a1070000-0000-4000-8000-0000000000b3', 'a1070000-0000-4000-8000-000000000001',
  'puntos', 'Puntos dobles en gasolina', '2026-11-01', null, false);
select pruebas.igual((select activo from public.fin_tarjeta_beneficios where id = 'a1070000-0000-4000-8000-0000000000b3'), false,
  '5: una baja es activo = false');

-- ---------------------------------------------------------------- 6: Papá (albacea) y la casa (compartido)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000a1', 'f1000000-0000-4000-8000-000000000002',
  (select titular_id from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'), 'Banco Ejemplo', 'Papá'),
  'a1070000-0000-4000-8000-0000000000a1'::uuid, '6: Ana, albacea, da de alta una tarjeta de Papá');
select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000c1', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('ana@ejemplo.test'), 'Banco Ejemplo', 'Casa');
select pruebas.igual((select count(*)::int from public.fin_tarjetas), 2,
  '6: Ana ve la de Papá y la de la casa (no la de Alex, que es personal)');
select pruebas.falla($$select * from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'))$$,
  '6: Ana no simula las deudas personales de Alex', '42501');
select pruebas.falla($$select * from public.fin_estimar_intereses((select id from t_ids where clave = 'libro'))$$,
  '6: ni estima sus intereses', '42501');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000a2', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'B', 'N')$$, '6: ni escribe tarjetas en el libro de Alex', '42501');
select pruebas.falla($$select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000001', 1, 1, null)$$,
  '6: ni cambia las tasas de las deudas de Alex', '42501');
select pruebas.igual((select count(*)::int from public.fin_simular_estrategias('f1000000-0000-4000-8000-000000000002')), 3,
  '6: como albacea sí simula las deudas de Papá');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_tarjetas where libro_id = 'f1000000-0000-4000-8000-000000000001'), 1,
  '6: la pareja ve las tarjetas de la casa');
select pruebas.igual((select count(*)::int from public.fin_tarjetas where libro_id = 'f1000000-0000-4000-8000-000000000002'), 1,
  '6 (v1.1): el suplente lee las de Papá igual que lee su libro (fin_puede leer, Fase 1)');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer')
  and public.fin_deudas_puede_ver('f1000000-0000-4000-8000-000000000002'),
  '6 (v1.1): la regla de deudas coincide con fin_puede leer');
select pruebas.falla($$select * from public.fin_simular_estrategias('f1000000-0000-4000-8000-000000000002')$$,
  '6: ni simula las deudas de Papá', '42501');
select pruebas.igual((select count(*)::int from public.fin_tarjetas), 3, '6: Alex ve la suya, la de la casa y la de Papá (suplente)');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000a6', 'f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('ana@ejemplo.test'), 'B', 'N')$$, '6: pero con albacea vigente el suplente no escribe tarjetas de Papá', '42501');
-- Sin albacea vigente, el suplente administra (y lee) el libro de Papá.
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = now()
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_tarjetas where libro_id = 'f1000000-0000-4000-8000-000000000002'), 1,
  '6 (v1.1): sin albacea vigente, el suplente sigue leyendo las tarjetas de Papá');
select pruebas.igual((select count(*)::int from public.fin_simular_estrategias('f1000000-0000-4000-8000-000000000002')), 3,
  '6 (v1.1): y, al ocupar el lugar del albacea, simula sus deudas');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_tarjetas where libro_id = 'f1000000-0000-4000-8000-000000000002'), 0,
  '6 (v1.1): quien dejó de ser albacea ya no ve las tarjetas de Papá');
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = null
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea' and hasta is not null;
select pruebas.como('alex@ejemplo.test');

-- ---------------------------------------------------------------- 7: familiar, cuidadora, Casa y anon: nada
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjetas'), 0, '7: la familiar no ve tarjetas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjeta_beneficios'), 0, '7: ni beneficios');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_deudas where libro_id = (select id from t_ids where clave = 'libro')$$), 0,
  '7: ni deudas');
select pruebas.falla($$select * from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'))$$,
  '7: no simula', '42501');
select pruebas.falla($$select * from public.fin_simular_estrategias('f1000000-0000-4000-8000-000000000002')$$,
  '7: ni con la vista temporal de Papá', '42501');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000a3', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('carla@ejemplo.test'), 'B', 'N')$$, '7: no escribe tarjetas', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjetas'), 0, '7: la cuidadora no ve tarjetas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjeta_beneficios'), 0, '7: ni beneficios');
select pruebas.falla($$select * from public.fin_estimar_intereses('f1000000-0000-4000-8000-000000000001')$$, '7: ni estima', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjetas'), 0, '7: Casa no ve tarjetas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjeta_beneficios'), 0, '7: ni beneficios');
select pruebas.falla($$select * from public.fin_simular_estrategias('f1000000-0000-4000-8000-000000000001')$$, '7: ni simula', '42501');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000a4', 'f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('ana@ejemplo.test'), 'B', 'N')$$, '7: ni escribe', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_tarjetas$$, '7: anon no lee tarjetas', '42501');
select pruebas.falla($$select * from public.fin_simular_estrategias('f1000000-0000-4000-8000-000000000001')$$, '7: anon no simula', '42501');

-- ---------------------------------------------------------------- 8: la cuenta maestra solo lee con consulta vigente
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjetas'), 0, '8: sin consulta, la maestra no ve tarjetas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjeta_beneficios'), 0, '8: ni beneficios');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_deudas where libro_id = (select id from t_ids where clave = 'libro')$$), 0,
  '8: ni deudas');
select public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'libro'));
select pruebas.igual(pruebas.cuenta($$select * from public.fin_tarjetas where libro_id = (select id from t_ids where clave = 'libro')$$), 1,
  '8: con consulta vigente lee la tarjeta de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_tarjeta_beneficios where libro_id = (select id from t_ids where clave = 'libro')$$), 3,
  '8: y sus beneficios');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjetas where libro_id = ''f1000000-0000-4000-8000-000000000002'''), 0,
  '8: la consulta es por libro: la tarjeta de Papá sigue sin verse');
select public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000002');
select pruebas.igual(pruebas.cuenta('select * from public.fin_tarjetas where libro_id = ''f1000000-0000-4000-8000-000000000002'''), 1,
  '8: con consulta al libro de Papá, lo lee');
select pruebas.falla($$select public.fin_tarjeta_guardar('a1070000-0000-4000-8000-0000000000a5', (select id from t_ids where clave = 'libro'),
  pruebas.id_persona('alex@ejemplo.test'), 'B', 'N')$$, '8: la maestra nunca escribe', '42501');
select pruebas.falla($$select public.fin_deuda_datos_guardar('e5700000-0000-4000-8000-000000000001', 1, 1, null)$$,
  '8: ni cambia datos de deudas', '42501');
select pruebas.falla($$select * from public.fin_simular_estrategias((select id from t_ids where clave = 'libro'))$$,
  '8: ni simula (solo lee)', '42501');

-- ---------------------------------------------------------------- 9: bitácora sin saldos ni tasas (D3)
select pruebas.como_postgres();
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_tarjetas') >= 3, '9: las tarjetas dejan entrada en la bitácora');
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_tarjeta_beneficios') >= 3, '9: y los beneficios');
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_deudas' and accion = 'actualizar') >= 1,
  '9: cambiar los datos de una deuda deja entrada');
select pruebas.igual((select count(*)::int from public.bitacora
   where tabla in ('fin_tarjetas', 'fin_tarjeta_beneficios', 'fin_deudas')
     and detalle::text ~ '(tasa_anual_pb|minimo_centavos|abono_centavos|limite_centavos|fecha_limite|cat_pb|monto_original_centavos|saldo_)'), 0,
  '9: ninguna entrada de tarjetas, beneficios o deudas lleva tasa, mínimo, abono, límite, fecha límite ni saldo');
select pruebas.igual((select count(*)::int from public.bitacora
   where detalle::text like '%4800%' and tabla in ('fin_tarjetas', 'fin_tarjeta_beneficios', 'fin_deudas')), 0,
  '9: ni el valor de una tasa');
select pruebas.igual((select count(*)::int from public.bitacora
   where tabla in ('fin_tarjetas', 'fin_tarjeta_beneficios', 'fin_deudas') and detalle::text ~ ': 5000000[,}]'), 0,
  '9: ni el límite de crédito');
-- Ninguna de las funciones deja entradas propias con cifras: las simulaciones no escriben.
select pruebas.igual((select count(*)::int from public.bitacora where accion like '%simul%' or accion like '%interes%'), 0,
  '9: simular y estimar no dejan entradas');

rollback;
