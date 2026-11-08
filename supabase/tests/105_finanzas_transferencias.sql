-- Finanzas · Ampliaciones bloque 1 (docs/specs/fase-8-finanzas-ampliaciones.md): transferencias con
-- confirmación del receptor, casa con subcuentas, aportantes y periodo de la aportación.
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra). Casa = libro compartido f100…0001; Papá = libro f100…0002.
begin;
create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;

-- ---------------------------------------------------------------- 0: antes de configurar la casa
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', null, 10000, '2026-11-10')$$,
  '0: sin casa configurada no hay ruta dueño -> casa', '22023');

-- ---------------------------------------------------------------- 1: configurar la casa
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes')$$,
  '1: la familiar no configura la casa', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes')$$,
  '1: la cuidadora no configura la casa', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes')$$,
  '1: la cuenta Casa no configura la casa', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes')$$,
  '1: la cuenta maestra solo lee: no configura', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'quincena')$$,
  '1: el periodo es semana, mes, bimestre, semestre o anual', '23514');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000002', 'mes')$$,
  '1: el libro de Papá no puede ser la casa', '22023');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes');
select pruebas.igual((select periodo::text from public.fin_casa_config), 'mes', '1: periodo mensual');
select pruebas.igual(
  (select string_agg(p.nombre_visible || '=' || r.parte_pb, ', ' order by r.parte_pb desc, p.nombre_visible)
     from public.fin_casa_referencias r join public.personas p on p.id = r.persona_id),
  'Papá (ejemplo)=5000, Alex Ejemplo=2500, Ana Ejemplo=2500', '1: referencia por omisión: Papá 50 %, dueño y pareja 25 % cada uno');
select pruebas.igual(
  (select sum(parte_pb)::int from public.fin_casa_referencias), 10000, '1: las partes suman el 100 %');

-- ---------------------------------------------------------------- 2: periodos configurables
select pruebas.como_postgres();
select pruebas.igual((select desde::text || '..' || hasta::text from public.fin_periodo_rango('semana', '2026-11-10')), '2026-11-09..2026-11-15', '2: semana en lunes');
select pruebas.igual((select desde::text || '..' || hasta::text from public.fin_periodo_rango('mes', '2026-11-10')), '2026-11-01..2026-11-30', '2: mes');
select pruebas.igual((select desde::text || '..' || hasta::text from public.fin_periodo_rango('bimestre', '2026-11-10')), '2026-11-01..2026-12-31', '2: bimestre (noviembre-diciembre)');
select pruebas.igual((select desde::text || '..' || hasta::text from public.fin_periodo_rango('bimestre', '2026-02-28')), '2026-01-01..2026-02-28', '2: bimestre (enero-febrero)');
select pruebas.igual((select desde::text || '..' || hasta::text from public.fin_periodo_rango('semestre', '2026-11-10')), '2026-07-01..2026-12-31', '2: semestre');
select pruebas.igual((select desde::text || '..' || hasta::text from public.fin_periodo_rango('anual', '2026-11-10')), '2026-01-01..2026-12-31', '2: año');
select pruebas.falla($$select * from public.fin_periodo_rango('decada', '2026-11-10')$$, '2: un periodo inventado se rechaza', '23514');

-- ---------------------------------------------------------------- 3: rutas permitidas
select pruebas.como('alex@ejemplo.test');
-- pareja -> dueño
select pruebas.igual(public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 50000, '2026-11-10', 'Para el seguro'),
  'a1050000-0000-4000-8000-000000000001'::uuid, '3: pareja -> dueño se propone');
-- pareja -> casa
select pruebas.igual(public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000002',
  'c4000000-0000-4000-8000-000000000001', null, 60000, '2026-11-10'),
  'a1050000-0000-4000-8000-000000000002'::uuid, '3: pareja -> casa se propone');
select pruebas.igual((select ruta from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000001'), 'pareja_a_dueno', '3: ruta pareja_a_dueno');
select pruebas.igual((select ruta from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000002'), 'pareja_a_casa', '3: ruta pareja_a_casa');
select pruebas.igual((select estado from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000001'), 'pendiente', '3: nace pendiente');
-- Rutas que no existen
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000090',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 100, '2026-11-10')$$,
  '3: a uno mismo no', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000091',
  'c4000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 100, '2026-11-10')$$,
  '3: la pareja no transfiere directo a Papá (su libro lo mueve el albacea, D19)', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000092',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 100, '2026-11-10')$$,
  '3: ni a la familiar', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000093',
  'c4000000-0000-4000-8000-000000000001', null, 0, '2026-11-10')$$,
  '3: el monto es mayor a cero', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000094',
  'c3000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$,
  '3: no propone desde la cuenta de otra persona', '42501');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000095',
  'c5000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 100, '2026-11-10')$$,
  '3: ni desde una cuenta de la casa (no es un libro personal)', '42501');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 99999, '2026-11-10', 'Para el seguro')$$,
  '3: el mismo id con otro contenido se rechaza', '23505');
select pruebas.igual(public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 50000, '2026-11-10', 'Para el seguro'),
  'a1050000-0000-4000-8000-000000000001'::uuid, '3: reenviar lo mismo (cola sin conexión) no duplica');
select pruebas.igual((select count(*)::int from public.fin_transferencias), 2, '3: sigue habiendo dos');
select pruebas.como('ana@ejemplo.test');
-- dueño -> casa
select pruebas.igual(public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000003',
  'c3000000-0000-4000-8000-000000000001', null, 30000, '2026-11-10'),
  'a1050000-0000-4000-8000-000000000003'::uuid, '3: dueño -> casa se propone');
select pruebas.igual((select ruta from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000003'), 'dueno_a_casa', '3: ruta dueno_a_casa');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000096',
  'c3000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 100, '2026-11-10')$$,
  '3: dueño -> pareja no es una ruta', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000097',
  'c3000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 100, '2026-11-10')$$,
  '3: dueño -> Papá tampoco', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000098',
  'c6000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$,
  '3: ni desde el libro de Papá', '42501');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000099',
  'c3000000-0000-4000-8000-000000000003', null, 100, '2026-11-10')$$,
  '3: ni desde una tarjeta (no es dinero)', '22023');
-- Los demás no proponen
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-0000000000a1',
  'c3000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$, '3: la familiar no propone', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-0000000000a2',
  'c3000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$, '3: la cuidadora no propone', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-0000000000a3',
  'c3000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$, '3: la cuenta Casa no propone', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-0000000000a4',
  'c4000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$, '3: la cuenta maestra solo lee: no propone', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.fin_proponer_transferencia('a1050000-0000-4000-8000-0000000000a5',
  'c3000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$, '3: anon no ejecuta la RPC', '42501');

-- ---------------------------------------------------------------- 4: sin confirmación no hay movimiento
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos where tipo = 'transferencia' and fecha = '2026-11-10'), 0,
  '4: pendientes no generan movimiento');
select pruebas.igual((select count(*)::int from public.fin_movimientos where nota in ('Para el seguro', 'Transferencia confirmada')), 0,
  '4: ninguno se registró por nota');
select pruebas.como('alex@ejemplo.test');
-- Saltarse la confirmación escribiendo el movimiento directo en el libro de Ana
select pruebas.falla($$select pruebas.registrar('transferencia', 'c4000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 50000, '2026-11-10')$$,
  '4: la pareja no escribe un movimiento en el libro de la dueña sin su confirmación', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c4000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 50000, '2026-11-10')$$,
  '4: la dueña tampoco jala dinero del libro de la pareja', '42501');
select pruebas.falla($$insert into public.fin_transferencias (id, hogar_id, ruta, persona_origen_id, libro_origen_id,
  libro_destino_id, cuenta_origen_id, monto_centavos, fecha, propuesta_por)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', 'dueno_a_casa', pruebas.id_persona('ana@ejemplo.test'),
          pruebas.libro_personal('ana@ejemplo.test'), 'f1000000-0000-4000-8000-000000000001',
          'c3000000-0000-4000-8000-000000000001', 100, '2026-11-10', pruebas.id_persona('ana@ejemplo.test'))$$,
  '4: la app no inserta transferencias directo (solo por la RPC)', '42501');
select pruebas.falla($$update public.fin_transferencias set estado = 'confirmada' where id = 'a1050000-0000-4000-8000-000000000001'$$,
  '4: ni las confirma con un UPDATE', '42501');
select pruebas.falla($$delete from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000001'$$,
  '4: ni las borra', '42501');

-- ---------------------------------------------------------------- 5: quién ve las transferencias
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_transferencias), 3, '5: Alex ve las suyas y la de la casa (es miembro)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_transferencias), 3, '5: Ana ve las suyas y las de la casa');

-- ---------------------------------------------------------------- 6: el receptor confirma (pareja -> dueño)
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001')$$,
  '6: quien propone no se confirma a sí mismo', '42501');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'rechazar')$$,
  '6: ni la rechaza', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001')$$,
  '6: la familiar no confirma', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001')$$,
  '6: la cuidadora no confirma', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001')$$,
  '6: la cuenta Casa no confirma', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001')$$,
  '6: la cuenta maestra solo lee: no confirma', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'tal vez')$$,
  '6: la acción es confirmar o rechazar', '22023');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar')$$,
  '6: con dos cuentas de dinero hay que elegir la que recibe', '22023');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000003')$$,
  '6: la tarjeta no recibe', '22023');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c5000000-0000-4000-8000-000000000001')$$,
  '6: una cuenta de la casa no es del libro que recibe', '22023');
select pruebas.igual((select count(*)::int from public.fin_movimientos where tipo = 'transferencia' and fecha = '2026-11-10'), 0,
  '6: tras los intentos fallidos sigue sin haber movimiento');
insert into t_ids select 'mov1', public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001');
select pruebas.ok((select id from t_ids where clave = 'mov1') is not null, '6: la dueña confirma y recibe el id del movimiento');
select pruebas.igual((select estado from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000001'), 'confirmada', '6: queda confirmada');
select pruebas.igual((select confirmada_por from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000001'),
  pruebas.id_persona('ana@ejemplo.test'), '6: confirmada_por es la receptora');
select pruebas.igual(
  (select m.tipo || ':' || m.monto_centavos || ':' || (m.libro_origen_id = pruebas.libro_personal('alex@ejemplo.test'))
          || ':' || (m.libro_destino_id = pruebas.libro_personal('ana@ejemplo.test'))
          || ':' || (m.realizado_por = pruebas.id_persona('alex@ejemplo.test'))
          || ':' || (m.registrado_por = pruebas.id_persona('ana@ejemplo.test'))
     from public.fin_movimientos m where m.id = (select id from t_ids where clave = 'mov1')),
  'transferencia:50000:true:true:true:true', '6: movimiento transferencia en centavos entre los dos libros, hecho por Alex y registrado por Ana');
select pruebas.igual((select movimiento_id from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000001'),
  (select id from t_ids where clave = 'mov1'), '6: la transferencia enlaza su movimiento');
select pruebas.igual(public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'confirmar', 'c3000000-0000-4000-8000-000000000001'),
  (select id from t_ids where clave = 'mov1'), '6: confirmar de nuevo devuelve el mismo movimiento');
select pruebas.igual((select count(*)::int from public.fin_movimientos where tipo = 'transferencia' and fecha = '2026-11-10'), 1,
  '6: y no duplica el movimiento');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000001', 'rechazar')$$,
  '6: una confirmada ya no se rechaza', '55000');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id = (select id from t_ids where clave = 'mov1')), 1, '6: Ana ve el movimiento');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id = (select id from t_ids where clave = 'mov1')), 1, '6: Alex lo ve desde su libro');
select pruebas.falla($$select public.fin_cancelar_transferencia('a1050000-0000-4000-8000-000000000001')$$,
  '6: una confirmada ya no se cancela', '55000');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id = (select id from t_ids where clave = 'mov1')), 0, '6: la familiar no lo ve');

-- ---------------------------------------------------------------- 7: casa como receptor
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000002', 'confirmar', 'c5000000-0000-4000-8000-000000000001')$$,
  '7: quien aporta a la casa no confirma su propia aportación', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000002', 'confirmar')$$,
  '7: la casa tiene dos cuentas de dinero: hay que elegir', '22023');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000002', 'confirmar', 'c3000000-0000-4000-8000-000000000002')$$,
  '7: la cuenta que recibe debe ser de la casa', '22023');
insert into t_ids select 'mov2', public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000002', 'confirmar', 'c5000000-0000-4000-8000-000000000001');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000003', 'confirmar', 'c5000000-0000-4000-8000-000000000001')$$,
  '7: tampoco la dueña confirma la que ella misma propuso a la casa', '42501');
select pruebas.como('alex@ejemplo.test');
insert into t_ids select 'mov3', public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000003', 'confirmar', 'c5000000-0000-4000-8000-000000000001');
select pruebas.como_postgres();
select pruebas.igual(
  (select m.libro_origen_id = pruebas.libro_personal('alex@ejemplo.test') and m.libro_destino_id = 'f1000000-0000-4000-8000-000000000001'
          and m.monto_centavos = 60000 and m.tipo = 'transferencia'
     from public.fin_movimientos m where m.id = (select id from t_ids where clave = 'mov2')),
  true, '7: pareja -> casa: movimiento del libro de Alex al de la casa');
select pruebas.igual(
  (select m.libro_origen_id = pruebas.libro_personal('ana@ejemplo.test') and m.libro_destino_id = 'f1000000-0000-4000-8000-000000000001'
          and m.monto_centavos = 30000 and m.realizado_por = pruebas.id_persona('ana@ejemplo.test')
     from public.fin_movimientos m where m.id = (select id from t_ids where clave = 'mov3')),
  true, '7: dueño -> casa: movimiento del libro de Ana al de la casa');
select pruebas.igual((select count(*)::int from public.fin_movimientos where tipo = 'transferencia' and fecha = '2026-11-10'), 3,
  '7: tres confirmadas, tres movimientos');

-- ---------------------------------------------------------------- 8: rechazar y cancelar dejan registro, sin movimiento
select pruebas.como('alex@ejemplo.test');
select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000004',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 20000, '2026-11-10', 'Prueba de rechazo');
select public.fin_proponer_transferencia('a1050000-0000-4000-8000-000000000005',
  'c4000000-0000-4000-8000-000000000001', null, 5000, '2026-11-10');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000004', 'rechazar'), null::uuid,
  '8: rechazar no devuelve movimiento');
select pruebas.igual((select estado from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000004'), 'rechazada', '8: queda rechazada');
select pruebas.igual((select respondida_por from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000004'),
  pruebas.id_persona('ana@ejemplo.test'), '8: con quién la rechazó');
select pruebas.igual((select (respondida_en is not null and confirmada_por is null and movimiento_id is null)
                        from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000004'),
  true, '8: con fecha, sin confirmadora y sin movimiento');
select pruebas.igual(public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000004', 'rechazar'), null::uuid, '8: rechazar otra vez no cambia nada');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000004', 'confirmar', 'c3000000-0000-4000-8000-000000000001')$$,
  '8: una rechazada ya no se confirma', '55000');
select pruebas.igual((select count(*)::int from public.fin_movimientos where tipo = 'transferencia' and fecha = '2026-11-10'), 3,
  '8: la rechazada no generó movimiento');
select pruebas.igual((select count(*)::int from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000004'), 1,
  '8: la rechazada sigue como registro');
-- cancelar
select pruebas.falla($$select public.fin_cancelar_transferencia('a1050000-0000-4000-8000-000000000005')$$,
  '8: solo cancela quien la propuso', '42501');
select pruebas.como('alex@ejemplo.test');
select public.fin_cancelar_transferencia('a1050000-0000-4000-8000-000000000005');
select pruebas.igual((select estado from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000005'), 'cancelada', '8: queda cancelada');
select public.fin_cancelar_transferencia('a1050000-0000-4000-8000-000000000005');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_responder_transferencia('a1050000-0000-4000-8000-000000000005', 'confirmar', 'c5000000-0000-4000-8000-000000000001')$$,
  '8: una cancelada ya no se confirma', '55000');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_movimientos where tipo = 'transferencia' and fecha = '2026-11-10'), 3,
  '8: ni la cancelada ni la rechazada generaron movimiento');
select pruebas.falla($$delete from public.fin_transferencias where id = 'a1050000-0000-4000-8000-000000000004'$$,
  '8: no se borra ni como administrador de la base', '42501');
select pruebas.falla($$update public.fin_transferencias set monto_centavos = 1 where id = 'a1050000-0000-4000-8000-000000000004'$$,
  '8: una cerrada no se edita', '55000');
select pruebas.falla($$truncate public.fin_transferencias$$, '8: ni se vacía');
-- Bitácora: quién y cuándo, sin montos
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'fin_transferencias'
    and persona_id = pruebas.id_persona('ana@ejemplo.test') and registrado_en is not null), '8: la bitácora dice quién respondió y cuándo');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'fin_transferencias'
    and persona_id = pruebas.id_persona('alex@ejemplo.test')), '8: y quién propuso');
select pruebas.ok(not exists (select 1 from public.bitacora where tabla = 'fin_transferencias'
    and detalle::text ~* 'monto|Para el seguro|Prueba de rechazo'), '8: la bitácora de transferencias no lleva montos ni notas');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.bitacora where tabla = 'fin_transferencias'), 0, '8: la familiar no lee esa bitácora');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.bitacora where tabla in ('fin_transferencias', 'fin_casa_ingresos', 'fin_casa_aportes')), 0, '8: la cuidadora tampoco');

-- ---------------------------------------------------------------- 9: subcuentas de la casa
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_casa_subcuentas (id, hogar_id, libro_id, categoria_id, dia_limite, cada_meses, monto_estimado_centavos)
  values ('a1051000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          'c1000000-0000-4000-8000-000000000007', 17, 2, 120000)$$), 1, '9: Ana da de alta la subcuenta Luz (bimestral)');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_casa_subcuentas (id, hogar_id, libro_id, categoria_id, dia_limite, cada_meses, proximo_vencimiento, monto_estimado_centavos)
  values ('a1051000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          'c1000000-0000-4000-8000-000000000008', 5, 1, '2026-12-05', 30000)$$), 1, '9: Alex da de alta Agua (mensual, con fecha límite)');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000021')$$,
  '9: la categoría debe tener cuenta de gasto del hogar (no gasto financiero)', '22023');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'c1000000-0000-4000-8000-000000000009')$$,
  '9: la subcuenta va en el libro de la casa, no en uno personal', '22023');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id, cada_meses)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000009', 5)$$,
  '9: el ciclo es 1, 2, 3, 6 o 12 meses', '23514');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id, dia_limite)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000009', 40)$$,
  '9: el día límite es de 1 a 31', '23514');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000007')$$,
  '9: una categoría no se repite en la casa', '23505');
select pruebas.falla($$update public.fin_casa_subcuentas set categoria_id = 'c1000000-0000-4000-8000-000000000009'
  where id = 'a1051000-0000-4000-8000-000000000002'$$, '9: la categoría de una subcuenta no cambia', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_subcuentas set proximo_vencimiento = '2026-12-05', monto_estimado_centavos = 30000
  where id = 'a1051000-0000-4000-8000-000000000002'$$), 1, '9: sí cambia su fecha límite y su estimado');
select pruebas.falla($$delete from public.fin_casa_subcuentas where id = 'a1051000-0000-4000-8000-000000000002'$$,
  '9: no se borran (se desactivan)', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_subcuentas), 0, '9: la familiar no ve las subcuentas');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000009')$$,
  '9: ni crea subcuentas', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_subcuentas), 0, '9: la cuidadora no ve las subcuentas');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000009')$$,
  '9: ni crea subcuentas', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_subcuentas), 0, '9: la cuenta Casa no ve las subcuentas');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000009')$$,
  '9: ni crea subcuentas', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_subcuentas), 0, '9: la cuenta maestra no lee sin consulta registrada');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000001'), '9: la maestra registra su consulta de la casa');
select pruebas.igual((select count(*)::int from public.fin_casa_subcuentas), 2, '9: con la consulta vigente, lee');
select pruebas.falla($$insert into public.fin_casa_subcuentas (hogar_id, libro_id, categoria_id)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000009')$$,
  '9: pero no escribe', '42501');

-- ---------------------------------------------------------------- 10: pago de servicios y aportante
-- Desde la cuenta de la casa: Ana paga la luz y el aportante es Alex.
select pruebas.como('ana@ejemplo.test');
insert into t_ids select 'ap1', public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000001',
  'a1051000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 150000, '2026-11-10',
  pruebas.id_persona('alex@ejemplo.test'), 'Luz de noviembre');
select pruebas.igual(
  (select a.aportante_id = pruebas.id_persona('alex@ejemplo.test') and a.pagado_por = pruebas.id_persona('ana@ejemplo.test')
          and a.monto_centavos = 150000 and not a.suma_al_aportado and a.subcuenta_id = 'a1051000-0000-4000-8000-000000000001'
     from public.fin_casa_aportes a where a.id = (select id from t_ids where clave = 'ap1')),
  true, '10: el pago de la luz registra al aportante (Alex), distinto de quien pagó (Ana)');
select pruebas.igual(
  (select m.tipo || ':' || m.monto_centavos || ':' || (m.categoria_id = 'c1000000-0000-4000-8000-000000000007')
          || ':' || (m.cuenta_destino_id = 'c2000000-0000-4000-8000-000000000003')
     from public.fin_movimientos m where m.id = 'a1052000-0000-4000-8000-000000000001'),
  'gasto:150000:true:true', '10: y un movimiento de gasto de la categoría Luz en la cuenta de gasto Servicios');
select pruebas.igual(public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000001',
  'a1051000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 150000, '2026-11-10',
  pruebas.id_persona('alex@ejemplo.test'), 'Luz de noviembre'), (select id from t_ids where clave = 'ap1'),
  '10: repetir la llamada (cola sin conexión) no duplica');
select pruebas.igual((select count(*)::int from public.fin_movimientos where id = 'a1052000-0000-4000-8000-000000000001'), 1, '10: un solo movimiento');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000002',
  'a1051000-0000-4000-8000-000000000001', 'c5000000-0000-4000-8000-000000000001', 1000, '2026-11-10',
  pruebas.id_persona('carla@ejemplo.test'))$$, '10: el aportante de la casa es un miembro o Papá, no la familiar', '22023');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000003',
  'a1051000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 0, '2026-11-10')$$,
  '10: el monto es mayor a cero', '22023');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000004',
  'a1051000-0000-4000-8000-000000000001', 'c4000000-0000-4000-8000-000000000001', 1000, '2026-11-10')$$,
  '10: no se paga desde el libro de la pareja', '42501');
-- Desde el dinero personal de Alex: el aportante es él.
select pruebas.como('alex@ejemplo.test');
insert into t_ids select 'ap2', public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000010',
  'a1051000-0000-4000-8000-000000000002', 'c4000000-0000-4000-8000-000000000001', 40000, '2026-11-10');
select pruebas.igual(
  (select a.aportante_id = pruebas.id_persona('alex@ejemplo.test') and a.pagado_por = pruebas.id_persona('alex@ejemplo.test') and a.suma_al_aportado
     from public.fin_casa_aportes a where a.id = (select id from t_ids where clave = 'ap2')),
  true, '10: pagando con su dinero, Alex es pagador y aportante, y suma al aportado');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000011',
  'a1051000-0000-4000-8000-000000000002', 'c4000000-0000-4000-8000-000000000001', 1000, '2026-11-10',
  pruebas.id_persona('ana@ejemplo.test'))$$, '10: desde un libro personal el aportante no es otra persona', '22023');
-- Papá: lo mueve su albacea (D19). Alex es suplente: no escribe mientras Ana sea albacea.
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000012',
  'a1051000-0000-4000-8000-000000000002', 'c6000000-0000-4000-8000-000000000001', 25000, '2026-11-10')$$,
  '10: el suplente no paga desde el libro de Papá con albacea vigente (D19)', '42501');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000013',
  'a1051000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 25000, '2026-11-10',
  'e0000000-0000-4000-8000-000000000001')$$,
  '10: ni atribuye un aporte a Papá', '42501');
select pruebas.como('ana@ejemplo.test');
insert into t_ids select 'ap3', public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000014',
  'a1051000-0000-4000-8000-000000000002', 'c6000000-0000-4000-8000-000000000001', 25000, '2026-11-10');
select pruebas.igual(
  (select a.aportante_id = 'e0000000-0000-4000-8000-000000000001' and a.pagado_por = pruebas.id_persona('ana@ejemplo.test') and a.suma_al_aportado
     from public.fin_casa_aportes a where a.id = (select id from t_ids where clave = 'ap3')),
  true, '10: la albacea paga con el dinero de Papá: aportante Papá, pagador Ana');
select pruebas.igual(
  (select m.en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and m.motivo is not null
     from public.fin_movimientos m where m.id = 'a1052000-0000-4000-8000-000000000014'),
  true, '10: el movimiento va en nombre de Papá y con motivo');
insert into t_ids select 'ap4', public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000015',
  'a1051000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000002', 5000, '2026-11-10',
  'e0000000-0000-4000-8000-000000000001');
select pruebas.ok((select aportante_id from public.fin_casa_aportes where id = (select id from t_ids where clave = 'ap4')) = 'e0000000-0000-4000-8000-000000000001',
  '10: la albacea atribuye a Papá un pago de la caja de la casa');
-- Sin acceso
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000020',
  'a1051000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 1000, '2026-11-10')$$, '10: la familiar no paga servicios', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000021',
  'a1051000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 1000, '2026-11-10')$$, '10: la cuidadora no paga servicios', '42501');
select pruebas.igual((select count(*)::int from public.fin_casa_aportes), 0, '10: la cuidadora no ve los aportes');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000022',
  'a1051000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 1000, '2026-11-10')$$, '10: la cuenta Casa no paga servicios', '42501');
select pruebas.igual((select count(*)::int from public.fin_casa_aportes), 0, '10: la cuenta Casa no ve los aportes');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_casa_pagar_servicio('a1052000-0000-4000-8000-000000000023',
  'a1051000-0000-4000-8000-000000000002', 'c5000000-0000-4000-8000-000000000001', 1000, '2026-11-10')$$, '10: la cuenta maestra no paga (solo lee)', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_aportes), 4, '10: los miembros de la casa ven los aportes');
select pruebas.falla($$update public.fin_casa_aportes set aportante_id = pruebas.id_persona('alex@ejemplo.test')$$,
  '10: los aportes no se editan desde la app', '42501');
select pruebas.falla($$insert into public.fin_casa_aportes (hogar_id, libro_id, subcuenta_id, movimiento_id, aportante_id, pagado_por, monto_centavos, fecha, suma_al_aportado)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'a1051000-0000-4000-8000-000000000002',
          'a1052000-0000-4000-8000-000000000010', pruebas.id_persona('alex@ejemplo.test'), pruebas.id_persona('alex@ejemplo.test'), 1, '2026-11-10', true)$$,
  '10: ni se inventan aportes directo', '42501');
select pruebas.como_postgres();
select pruebas.falla($$update public.fin_casa_aportes set monto_centavos = 1$$, '10: ni como administrador (solo agregar)');
select pruebas.falla($$delete from public.fin_casa_aportes$$, '10: ni se borran');

-- ---------------------------------------------------------------- 11: aportación de referencia y aportado
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(
  (select string_agg(p.nombre_visible || ':' || a.referencia_centavos || ':' || a.aportado_centavos, ', ' order by p.nombre_visible)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
     join public.personas p on p.id = a.persona_id),
  'Alex Ejemplo:22500:100000, Ana Ejemplo:22500:30000, Papá (ejemplo):45000:25000',
  '11: mes: referencia (Luz 60000 + Agua 30000 al mes; 25/25/50 %) y aportado (transferencias a la casa + servicios pagados con su dinero)');
select pruebas.igual((select distinct vence_antes_de::text from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')),
  '2026-12-05', '11: la aportación debe caer antes de la fecha límite más próxima');
select pruebas.igual((select distinct desde::text || '..' || hasta::text from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')),
  '2026-11-01..2026-11-30', '11: el periodo es el del mes');
select pruebas.igual(
  (select a.aportado_centavos from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-10-20') a
    where a.persona_id = pruebas.id_persona('alex@ejemplo.test')),
  700000::bigint, '11: en octubre cuenta la aportación del seed (700000 centavos de Alex)');
select pruebas.ok(not exists (
  select 1 from unnest((select proargnames from pg_proc where oid = 'public.fin_casa_aportacion(uuid, date)'::regprocedure)) n
   where n ~* 'falt|deud|debe|adeud'), '11: sin columnas de faltante ni de deuda: la aportación es libre');
-- La anulación de una transferencia confirmada resta de lo aportado
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.registrar('anulacion', 'c5000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 30000,
  '2026-11-10', 'Se aportó por error', (select id from t_ids where clave = 'mov3')) is not null, '11: anular una transferencia confirmada (contraasiento)') ;
select pruebas.igual(
  (select a.aportado_centavos from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
    where a.persona_id = pruebas.id_persona('ana@ejemplo.test')),
  0::bigint, '11: anulada, ya no cuenta como aportada');
-- Cambiar el periodo
select pruebas.como('alex@ejemplo.test');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'semana');
select pruebas.igual(
  (select string_agg(a.referencia_centavos::text, ',' order by a.parte_pb desc, a.persona_id)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a),
  '10385,5192,5192', '11: semana: 90000 al mes x 12/52 x partes (50/25/25 %), en centavos redondeados');
select pruebas.igual((select distinct desde::text || '..' || hasta::text from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')),
  '2026-11-09..2026-11-15', '11: semana en lunes');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'bimestre');
select pruebas.igual(
  (select string_agg(a.referencia_centavos::text, ',' order by a.parte_pb desc, a.persona_id)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a),
  '90000,45000,45000', '11: bimestre');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'semestre');
select pruebas.igual(
  (select string_agg(a.referencia_centavos::text, ',' order by a.parte_pb desc, a.persona_id)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a),
  '270000,135000,135000', '11: semestre');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'anual');
select pruebas.igual(
  (select string_agg(a.referencia_centavos::text, ',' order by a.parte_pb desc, a.persona_id)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a),
  '540000,270000,270000', '11: año');
select pruebas.igual(
  (select a.aportado_centavos from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
    where a.persona_id = pruebas.id_persona('alex@ejemplo.test')),
  800000::bigint, '11: en el año de 2026 Alex suma lo del seed (700000) y lo de noviembre (60000 + 40000)');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select * from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')$$, '11: la familiar no ve la aportación', '42501');
select pruebas.falla($$select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'anual')$$, '11: ni cambia el periodo', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select * from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')$$, '11: la cuidadora tampoco', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select * from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')$$, '11: ni la cuenta Casa', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(
  (select count(*)::int from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')), 3,
  '11: la cuenta maestra lee con su consulta vigente');
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')$$, '11: anon no ejecuta', '42501');

-- ---------------------------------------------------------------- 12: partes de referencia
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.fin_casa_referencias set parte_pb = 6000 where persona_id = 'e0000000-0000-4000-8000-000000000001'$$,
  '12: las partes no pasan del 100 %', '23514');
select pruebas.falla($$update public.fin_casa_referencias set parte_pb = 10001 where persona_id = 'e0000000-0000-4000-8000-000000000001'$$,
  '12: una parte no pasa de 10000', '23514');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_referencias set parte_pb = 1500 where persona_id = pruebas.id_persona('alex@ejemplo.test')$$), 1,
  '12: Ana ajusta la referencia de Alex');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_referencias set parte_pb = 6000 where persona_id = 'e0000000-0000-4000-8000-000000000001'$$), 1,
  '12: y la de Papá (referencia libre, nada obliga)');
select pruebas.falla($$insert into public.fin_casa_referencias (hogar_id, persona_id, parte_pb)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 0)$$,
  '12: solo hay referencia de Papá, del dueño y de la pareja', '22023');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_referencias), 0, '12: la familiar no ve las partes');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_referencias set parte_pb = 0$$), 0, '12: ni las cambia');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_referencias) + (select count(*)::int from public.fin_casa_config), 0, '12: la cuenta Casa no ve nada de esto');

-- ---------------------------------------------------------------- 13: ingreso por persona (RLS por persona)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 3000000, 'mes')$$), 1, '13: Ana registra su ingreso');
select pruebas.falla($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 1, 'mes')$$,
  '13: pero no el de Alex', '42501');
select pruebas.falla($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), -5, 'mes')$$,
  '13: el ingreso no es negativo', '23514');
select pruebas.falla($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 100, 'decada')$$,
  '13: el periodo del ingreso es uno de los cinco', '23514');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_ingresos set ingreso_centavos = 3100000 where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 1,
  '13: Ana actualiza el suyo');
-- Papá: su albacea
select pruebas.igual(pruebas.afecta($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 1200000, 'mes')$$), 1,
  '13: Ana, como albacea, registra el ingreso de Papá (D19)');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 1800000, 'mes')$$), 1, '13: Alex registra el suyo');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 2, '13: Alex ve el suyo y, como suplente, el de Papá');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos where persona_id = pruebas.id_persona('ana@ejemplo.test')), 0,
  '13: pero no el de Ana (RLS por persona)');
select pruebas.falla($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos, periodo)
  values ('b0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 1, 'mes')$$,
  '13: el suplente no toca el ingreso de Papá con albacea vigente (D19)', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_ingresos set ingreso_centavos = 1 where persona_id <> pruebas.id_persona('alex@ejemplo.test')$$), 0,
  '13: ni edita el de otra persona');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 2, '13: Ana ve el suyo y el de Papá (no el de Alex)');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 0, '13: la familiar no ve ingresos');
select pruebas.falla($$insert into public.fin_casa_ingresos (hogar_id, persona_id, ingreso_centavos) values
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 100)$$, '13: ni registra', '22023');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 0, '13: la cuidadora no ve ingresos');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 0, '13: la cuenta Casa no ve ingresos');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 0, '13: la maestra no lee sin consulta');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('alex@ejemplo.test')), '13: registra su consulta del libro de Alex');
select pruebas.igual((select count(*)::int from public.fin_casa_ingresos), 1, '13: con consulta lee solo ese libro');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_ingresos set ingreso_centavos = 1$$), 0, '13: y no escribe');
select pruebas.como_postgres();
select pruebas.ok(not exists (select 1 from public.bitacora where tabla = 'fin_casa_ingresos'
    and detalle::text ~ '3000000|3100000|1200000|1800000|ingreso_centavos'), '13: la bitácora de ingresos no lleva montos');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'fin_casa_ingresos'), '13: pero sí quién y cuándo');

-- ---------------------------------------------------------------- 14: configuración legible solo por quien lleva la casa
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_config), 1, '14: Alex lee la configuración de la casa');
select pruebas.falla($$insert into public.fin_casa_config (hogar_id, libro_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001')$$,
  '14: pero solo se cambia por la RPC', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_config) + (select count(*)::int from public.fin_transferencias)
  + (select count(*)::int from public.fin_casa_aportes), 0, '14: la cuidadora no ve nada de este bloque');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_config) + (select count(*)::int from public.fin_transferencias)
  + (select count(*)::int from public.fin_casa_aportes), 0, '14: la cuenta Casa tampoco');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.fin_casa_config) + (select count(*)::int from public.fin_transferencias)
  + (select count(*)::int from public.fin_casa_aportes), 0, '14: ni la familiar');
select pruebas.como_anon();
select pruebas.falla($$select count(*) from public.fin_transferencias$$, '14: anon no lee transferencias', '42501');
rollback;
