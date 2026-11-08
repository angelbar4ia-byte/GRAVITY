-- Cuidados (Fase 5): gastos de cuidado, su confirmación y el resumen mensual (spec 5 §4, criterio 3).
-- La hermana ve el total del mes de gastos de cuidado y de la casa SIN los de la pareja ni los del dueño, y solo si el albacea
-- (Ana, D19) la autorizó. Ana es dueña y albacea; Alex, la pareja, solo suplente.
begin;

-- Gastos registrados por cada quien, con su propia sesión.
select pruebas.como('diana@ejemplo.test');
insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha, ambito) values
  ('a5300000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-000000000001', 12000, 'Cremas (ejemplo)',     '2026-11-03', 'cuidado'),
  ('a5300000-0000-4000-8000-0000000000a3', 'b0000000-0000-4000-8000-000000000001',  4000, 'Guantes de octubre',   '2026-10-31', 'cuidado'),
  ('a5300000-0000-4000-8000-0000000000a4', 'b0000000-0000-4000-8000-000000000001',  3000, 'Se rechazará',         '2026-11-08', 'cuidado'),
  ('a5300000-0000-4000-8000-0000000000a5', 'b0000000-0000-4000-8000-000000000001',  2000, 'Sigue pendiente',      '2026-11-09', 'cuidado');
-- F5-I1: el servidor ya no deja a la cuidadora registrar gastos de la casa; este de 5000 llega como dato previo (sin RLS).
select pruebas.como_postgres();
insert into public.cui_gastos (id, hogar_id, persona_id, monto_centavos, concepto, fecha, ambito) values
  ('a5300000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'),
   5000, 'Detergente (ejemplo)', '2026-11-20', 'casa');
select pruebas.como('carla@ejemplo.test');
insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha, ambito) values
  ('a5300000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-000000000001', 18000, 'Despensa (hermana)', '2026-11-04', 'casa'),
  ('a5300000-0000-4000-8000-0000000000b2', 'b0000000-0000-4000-8000-000000000001',  7000, 'Medicina de venta libre (ejemplo)', '2026-11-30', 'cuidado');
select pruebas.como('alex@ejemplo.test');
insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha, ambito) values
  ('a5300000-0000-4000-8000-0000000000c1', 'b0000000-0000-4000-8000-000000000001',  9900, 'Gasto de la casa (pareja)', '2026-11-06', 'casa');
select pruebas.como('ana@ejemplo.test');
insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha, ambito) values
  ('a5300000-0000-4000-8000-0000000000d1', 'b0000000-0000-4000-8000-000000000001', 25000, 'Pañales (dueño)', '2026-11-05', 'cuidado');

-- ---------------------------------------------------------------- la confirmación del dueño
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 9, 'La dueña ve todos los gastos de cuidado');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos where estado = 'pendiente_confirmacion'$$), 9, 'Todos nacen pendientes');
select pruebas.igual((select gastos_cuidado_centavos + gastos_casa_centavos from public.cui_resumen_mensual('2026-11-01')), 0::bigint,
  'Mientras no estén confirmados no cuentan');
select public.cui_confirmar_gasto(g::uuid, true)
  from unnest(array['a5300000-0000-4000-8000-0000000000a1', 'a5300000-0000-4000-8000-0000000000a2', 'a5300000-0000-4000-8000-0000000000a3',
                    'a5300000-0000-4000-8000-0000000000b1', 'a5300000-0000-4000-8000-0000000000b2', 'a5300000-0000-4000-8000-0000000000c1',
                    'a5300000-0000-4000-8000-0000000000d1']) as g;
select public.cui_confirmar_gasto('a5300000-0000-4000-8000-0000000000a4', false);
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos where estado = 'confirmado' and confirmado_en is not null$$), 7, 'Siete confirmados con su hora');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos where estado = 'rechazado'$$), 1, 'Uno rechazado');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos where estado = 'pendiente_confirmacion'$$), 1, 'Y uno pendiente');
select pruebas.falla($$select public.cui_confirmar_gasto('a5300000-0000-4000-8000-0000000000a4', true)$$, 'Un gasto resuelto no se vuelve a resolver', '55000');
select pruebas.falla($$select public.cui_confirmar_gasto(gen_random_uuid(), true)$$, 'Un gasto que no existe: 42501', '42501');
select pruebas.falla($$update public.cui_gastos set estado = 'confirmado' where id = 'a5300000-0000-4000-8000-0000000000a5'$$, 'No se confirma con un UPDATE directo', '42501');

-- ---------------------------------------------------------------- criterio 3: el resumen
-- Mes de noviembre, solo gastos confirmados y sin los de la pareja ni los del dueño:
--   cuidado = 12000 (Diana) + 7000 (Carla) = 19000; casa = 5000 (Diana) + 18000 (Carla) = 23000; 4 gastos.
select pruebas.igual((select gastos_cuidado_centavos from public.cui_resumen_mensual('2026-11-01')), 19000::bigint, 'El dueño ve el total de cuidado del mes (sin lo suyo)');
select pruebas.igual((select gastos_casa_centavos from public.cui_resumen_mensual('2026-11-01')), 23000::bigint, '… y el de la casa (sin lo de la pareja)');
select pruebas.igual((select n_gastos from public.cui_resumen_mensual('2026-11-01')), 4, '… de 4 gastos');
select pruebas.igual((select mes from public.cui_resumen_mensual('2026-11-17')), '2026-11-01'::date, 'Cualquier día del mes lleva al día 1');
select pruebas.igual((select gastos_cuidado_centavos from public.cui_resumen_mensual('2026-10-01')), 4000::bigint, 'Octubre trae solo el de octubre');
select pruebas.igual((select gastos_cuidado_centavos + gastos_casa_centavos from public.cui_resumen_mensual('2026-12-01')), 0::bigint, 'Un mes sin gastos da cero');
select pruebas.como_postgres();
select pruebas.igual((select sum(monto_centavos)::bigint from public.cui_gastos where estado = 'confirmado' and fecha between '2026-11-01' and '2026-11-30'), 76900::bigint,
  'Control: sumando TODO lo confirmado de noviembre darían 76 900; el resumen deja fuera los 34 900 de la pareja y el dueño');
select pruebas.igual(
  (select array_to_string(proargnames, ',') from pg_proc where proname = 'cui_resumen_mensual'),
  'p_mes,hogar_id,mes,gastos_cuidado_centavos,gastos_casa_centavos,n_gastos',
  'El resumen devuelve solo totales: ninguna columna de persona ni de concepto');

-- Sin autorización del albacea, la hermana no lo ve
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'Criterio 3: sin autorización del albacea, la hermana no ve el resumen', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_autorizacion_resumen$$), 0, 'Aún no hay autorización');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true)$$,
  'Ella no se autoriza', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true)$$,
  'La pareja (suplente del albacea) tampoco la autoriza', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true)$$,
  'El albacea solo autoriza a un cuidador o familiar', '22023');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), null)$$,
  'La autorización es sí o no', '22023');
select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true);
select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), true);

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_autorizacion_resumen$$), 1, 'La hermana ve su propia autorización');
select pruebas.ok((select vigente and autorizado_por = pruebas.id_persona('ana@ejemplo.test') from public.cui_autorizacion_resumen), 'firmada por el albacea');
select pruebas.igual((select gastos_cuidado_centavos from public.cui_resumen_mensual('2026-11-01')), 19000::bigint,
  'Criterio 3: con la autorización, la hermana ve el total de cuidado del mes');
select pruebas.igual((select gastos_casa_centavos from public.cui_resumen_mensual('2026-11-01')), 23000::bigint,
  '… y el de la casa, sin los montos de la pareja ni del dueño');
select pruebas.igual((select n_gastos from public.cui_resumen_mensual('2026-11-01')), 4, '… de 4 gastos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 2, 'Pero en sus filas solo están sus propios gastos (no los de la pareja ni los del dueño)');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos where persona_id <> pruebas.id_persona('carla@ejemplo.test')$$), 0, '… ninguno ajeno');
select pruebas.falla($$update public.cui_autorizacion_resumen set vigente = false$$, 'No retira ni cambia la autorización', '42501');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), false)$$,
  'ni por RPC', '42501');

-- La cuidadora no es la hermana: aunque el albacea la autorizara por error, no ve el resumen
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'La cuidadora no ve el resumen (spec 5 §5: No)', '42501');
-- Pareja, maestra, Casa, otro hogar, sin hogar y anon
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'La pareja no ve el resumen', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'ni la cuenta maestra', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'ni Casa', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_resumen_mensual('2026-11-01') where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0,
  'El dueño de otro hogar solo ve el resumen de SU hogar (en ceros), nunca el de este');
select pruebas.igual((select gastos_cuidado_centavos + gastos_casa_centavos from public.cui_resumen_mensual('2026-11-01')), 0::bigint, '… sin nuestros montos');
select pruebas.como('nuevo@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'ni quien no tiene hogar', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'ni anon', '42501');

-- El albacea retira la autorización: se cierra de inmediato
select pruebas.como('ana@ejemplo.test');
select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), false);
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'Retirada la autorización, la hermana ya no ve el resumen', '42501');

-- Quedan en la bitácora de auditoría la autorización y la confirmación (quién y cuándo), sin conceptos
select pruebas.como_postgres();
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'cui_autorizacion_resumen' and accion = 'insertar')
                  and exists (select 1 from public.bitacora where tabla = 'cui_autorizacion_resumen' and accion = 'actualizar'),
  'Cada cambio de autorización deja su entrada');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'cui_gastos' and accion = 'actualizar'
                          and detalle -> 'despues' ->> 'estado' = 'confirmado'), 'y cada confirmación de un gasto');

rollback;
