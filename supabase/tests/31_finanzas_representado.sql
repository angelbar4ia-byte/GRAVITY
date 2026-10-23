-- Libro de Papá (representado), revisión de calidad de la Fase 1:
--   I3  todo movimiento del libro lleva en_nombre_de = Papá y motivo (también
--       las anulaciones); las salidas hacia un libro personal dejan además una
--       entrada finanzas.salida_libro_representado en la bitácora;
--   I4  albacea y suplente son "vigentes" solo si su membresía del hogar sigue
--       activa y con Finanzas: si el albacea se va, el suplente escribe.
-- (El resto de las reglas del albacea está en 21_finanzas_albacea.sql.)
begin;

-- Un tercer adulto (la cuenta maestra es solo lectura y no puede llevar un libro).
select pruebas.nuevo_adulto('teo@ejemplo.test');

-- ---------------------------------------------------------------- I3: todo en nombre de Papá y con motivo
-- (Revisión de calidad de la Fase 1; criterio 34: el servidor lo exige, no solo la app.)
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000)$$,
  'I3: el albacea no registra un gasto de Papá sin en_nombre_de ni motivo', '23514');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 100000)$$,
  'I3: ni pasa dinero de Papá a su banco personal sin en_nombre_de ni motivo', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => 'Despensa de Papá (ejemplo)')$$,
  'I3: con motivo pero sin en_nombre_de, tampoco', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'I3: con en_nombre_de pero sin motivo, tampoco', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => '   ',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'I3: ni con un motivo en blanco', '23514');
select pruebas.falla($$insert into public.fin_movimientos (hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
  cuenta_destino_id, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'ingreso', '2026-10-21', now(),
          'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 350000)$$,
  'I3: tampoco un ingreso (la pensión) sin en_nombre_de ni motivo', '23514');
select pruebas.falla($$select pruebas.registrar('apertura', pruebas.cuenta_sistema('f1000000-0000-4000-8000-000000000002', 'apertura'),
  'c6000000-0000-4000-8000-000000000002', 100)$$,
  'I3: ni una apertura', '23514');
select pruebas.falla($$select pruebas.registrar('reclasificacion', pruebas.cuenta_sistema('f1000000-0000-4000-8000-000000000002', 'por_clasificar'),
  'c2000000-0000-4000-8000-000000000005', 100)$$,
  'I3: ni una reclasificación', '23514');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = 'f1000000-0000-4000-8000-000000000002'
     or libro_destino_id = 'f1000000-0000-4000-8000-000000000002'$$), 3,
  'I3: no entró ninguno de los intentos (siguen los 3 del ejemplo)');

-- La anulación también va en su nombre.
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000005',
  'c6000000-0000-4000-8000-000000000001', 40000, '2026-10-14', 'Farmacia mal capturada',
  'd1000000-0000-4000-8000-000000000017')$$,
  'I3: la anulación en el libro de Papá exige en_nombre_de', '23514');
select pruebas.ok(
  pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000005', 'c6000000-0000-4000-8000-000000000001', 40000,
                    '2026-10-14', 'Farmacia mal capturada',
                    'd1000000-0000-4000-8000-000000000017', 'e0000000-0000-4000-8000-000000000001') is not null,
  'I3: con en_nombre_de y motivo, la anulación entra');

-- Lo que sí entra, y un reenvío de algo ya guardado no se rechaza por esta regla.
select pruebas.ok(
  pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 5000,
                    p_motivo => 'Despensa de Papá (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
                    p_id => 'd8000000-0000-4000-8000-000000000001') is not null,
  'I3: en su nombre y con motivo, el gasto entra');
select pruebas.igual(
  pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 5000,
                    p_motivo => 'Despensa de Papá (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
                    p_id => 'd8000000-0000-4000-8000-000000000001'),
  null::uuid, 'I3: reenviarlo (cola sin conexión) no falla ni duplica');
select pruebas.igual((select realizado_por from public.fin_movimientos where id = 'd8000000-0000-4000-8000-000000000001'),
  pruebas.id_persona('ana@ejemplo.test'), 'Queda quién lo hizo (Ana, la albacea) y en nombre de quién (Papá)');
-- Un movimiento de otro libro no necesita nada de esto.
select pruebas.ok(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 100) is not null,
  'Un movimiento del libro de Ana no pide en_nombre_de');

-- Salida del libro de Papá hacia un libro personal: entrada propia en la bitácora.
select pruebas.ok(
  pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 100000,
                    p_motivo => 'Reembolso de lo que adelanté para Papá (ejemplo)',
                    p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
                    p_id => 'd8000000-0000-4000-8000-000000000002') is not null,
  'I3: la salida de la pensión al banco de Ana entra, con motivo y en nombre de Papá');
select pruebas.igual(
  (select detalle ->> 'monto_centavos' || ' ' || (detalle ->> 'motivo')
     from public.bitacora where accion = 'finanzas.salida_libro_representado'
      and registro_id = 'd8000000-0000-4000-8000-000000000002'),
  '100000 Reembolso de lo que adelanté para Papá (ejemplo)',
  'I3: y deja la entrada finanzas.salida_libro_representado con monto y motivo');
select pruebas.igual(
  (select persona_id from public.bitacora where accion = 'finanzas.salida_libro_representado'
    and registro_id = 'd8000000-0000-4000-8000-000000000002'),
  pruebas.id_persona('ana@ejemplo.test'), 'I3: con quién la hizo');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 1,
  'I3: una sola entrada (el gasto, la aportación y la anulación no son salidas hacia un libro personal)');
select pruebas.igual(
  pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 100000,
                    p_motivo => 'Reembolso de lo que adelanté para Papá (ejemplo)',
                    p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
                    p_id => 'd8000000-0000-4000-8000-000000000002'),
  null::uuid, 'I3: reenviar la salida no repite la entrada');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 1,
  'I3: sigue habiendo una');
-- El suplente la ve (el aviso con notificación llegará en la Fase 2).
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 1,
  'I3: el suplente ve la salida en la bitácora');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 0,
  'I3: una familiar no');

-- ---------------------------------------------------------------- I4: el albacea ya no está en el hogar
-- Alex es albacea y Ana suplente; Ana da de baja a Alex: el cargo de Alex deja de contar y Ana escribe.
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = desde where libro_id = 'f1000000-0000-4000-8000-000000000002';
insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel) values
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   pruebas.id_persona('alex@ejemplo.test'), 'albacea'),
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   pruebas.id_persona('ana@ejemplo.test'), 'albacea_suplente');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  'I4: con Alex albacea en el hogar, la suplente Ana lee y no escribe');
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  'I4: dado de baja el albacea, la suplente escribe y administra al instante');
select pruebas.ok(
  pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000005', 7000,
                    p_motivo => 'Medicinas (el albacea ya no está) (ejemplo)',
                    p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null,
  'I4: y registra en nombre de Papá');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea' and hasta is null$$), 1,
  'I4: puede cerrar el cargo del albacea que se fue');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('teo@ejemplo.test'), 'albacea')$$), 1,
  'I4: y nombrar a un albacea nuevo');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'),
  'El que se fue no ve nada del libro de Papá');

-- El albacea que pierde Finanzas (cambia de rol) tampoco cuenta: el suplente ocupa su lugar.
select pruebas.como_postgres();
update public.membresias set activa = true, hasta = null where persona_id = pruebas.id_persona('alex@ejemplo.test');
update public.fin_libro_miembros set hasta = desde where libro_id = 'f1000000-0000-4000-8000-000000000002';
insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel) values
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   pruebas.id_persona('alex@ejemplo.test'), 'albacea'),
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   pruebas.id_persona('ana@ejemplo.test'), 'albacea_suplente');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir'),
  'I4: Alex vuelve al hogar y es albacea otra vez: Ana solo lee');
update public.membresias set rol = 'familiar' where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir'),
  'I4: si Alex pasa a un rol sin Finanzas, Ana escribe');

rollback;
