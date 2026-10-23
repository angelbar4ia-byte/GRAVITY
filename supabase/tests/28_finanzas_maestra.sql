-- D19: la cuenta maestra (una por hogar, la asigna el dueño) solo LEE y nunca
-- escribe en lo ajeno. Revisión de calidad de la Fase 1:
--   I2  leer el contenido de un libro ajeno exige una consulta registrada por
--       ella en ese libro, con vigencia de 30 minutos (lo impone el servidor);
--   M6  si no es la dueña, no cambia la configuración del hogar;
--   M10 asignar o quitar la cuenta maestra deja una entrada que ve todo adulto
--       con Finanzas.
-- D18: el dueño ya no ve el historial de GRAVITY ni las finanzas personales de
-- los demás en la bitácora.
begin;

-- Una entrada de historial de GRAVITY de la familiar (para D18).
select pruebas.como('carla@ejemplo.test');
insert into public.bitacora (hogar_id, accion, detalle)
values ('b0000000-0000-4000-8000-000000000001', 'gravity.pregunta', '{"tema": "receta"}');

-- ---------------------------------------------------------------- portada sin consulta
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
  'Marta es la cuenta maestra del Hogar Ejemplo');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 5,
  'Sin consulta ve la portada: los 5 libros del hogar (Ana, Alex, el suyo, el compartido y el de Papá)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libro_miembros'), 7,
  '… y quién lleva cada uno (7 cargos), para elegir cuál consultar');
select pruebas.igual(pruebas.cuenta('select * from public.personas'), 7, '… y los nombres de las personas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_cuentas where libro_id is null'), 12,
  'Las cuentas de gasto y las categorías son del hogar: no piden consulta');
select pruebas.igual(pruebas.cuenta('select * from public.fin_categorias'), 21, '… las categorías tampoco');

-- I2: sin consulta registrada, el contenido de los libros ajenos no se lee.
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 0,
  'I2: sin consulta no lee movimientos de nadie (el suyo aún no tiene)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_cuentas where libro_id is not null
  and libro_id <> pruebas.libro_personal(''marta@ejemplo.test'')'), 0, 'I2: ni cuentas ajenas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_v_saldos where cuenta_id = ''c3000000-0000-4000-8000-000000000001'''), 0,
  'I2: ni el saldo del banco de Ana');
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_ingresos', 'fin_vigencias_ingreso', 'fin_compromisos', 'fin_sobres',
                                 'fin_deudas', 'fin_semanas', 'fin_partidas_semana', 'fin_abonos_semana',
                                 'fin_cierres', 'fin_cierre_partidas', 'fin_cierre_abonos', 'fin_ocurrencias',
                                 'fin_conciliaciones', 'fin_v_gasto_semana']
  loop
    perform pruebas.igual(pruebas.cuenta(format(
      'select * from public.%I where libro_id <> pruebas.libro_personal(%L)', v_tabla, 'marta@ejemplo.test')), 0,
      'I2: sin consulta no lee ' || v_tabla || ' ajenas');
  end loop;
end
$$;
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer'),
  'I2: fin_puede(): sin consulta, la maestra no lee el libro de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where registro_id = 'd1000000-0000-4000-8000-000000000023'$$), 0,
  'I2: tampoco las finanzas personales de Alex por la bitácora');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where tabla like 'fin\_%'
  and (detalle -> 'despues' ->> 'libro_origen_id') = pruebas.libro_personal('ana@ejemplo.test')::text$$), 0,
  'I2: ni los movimientos de Ana por la bitácora');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'gravity.pregunta'$$), 1,
  'Lo que no es de Finanzas (historial de GRAVITY) sí lo ve (D19)');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion like 'finanzas%'$$), 0,
  'Aún no hay consultas suyas en la bitácora');

-- La maestra no se da la consulta sola: la bitácora de Finanzas es del servidor (I5).
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla, registro_id, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'finanzas.consulta_maestra', 'fin_libros',
          pruebas.libro_personal('ana@ejemplo.test')::text,
          jsonb_build_object('libro_id', pruebas.libro_personal('ana@ejemplo.test')::text))$$,
  'I2/I5: la maestra no se escribe a mano su propia consulta', '42501');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer'),
  '… y sigue sin leer');

-- ---------------------------------------------------------------- la consulta vence a los 30 minutos
-- (Solo el servidor escribe estas entradas: aquí las fecha el dueño de las tablas.)
select pruebas.como_postgres();
insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle, registrado_en)
select 'b0000000-0000-4000-8000-000000000001', c.quien, 'finanzas.consulta_maestra', 'fin_libros',
       c.libro::text, jsonb_build_object('libro_id', c.libro), now() - c.antiguedad
from (values
  (pruebas.id_persona('marta@ejemplo.test'), pruebas.libro_personal('alex@ejemplo.test'),     interval '31 minutes'),
  (pruebas.id_persona('marta@ejemplo.test'), 'f1000000-0000-4000-8000-000000000002'::uuid,    interval '29 minutes'),
  (pruebas.id_persona('carla@ejemplo.test'), pruebas.libro_personal('ana@ejemplo.test'),      interval '1 minute')
) as c (quien, libro, antiguedad);
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('alex@ejemplo.test'), 'leer'),
  'I2: una consulta de hace 31 minutos ya venció');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'),
  'I2: una de hace 29 minutos sigue vigente');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer'),
  'I2: la consulta es de la persona: la de otra (Carla) no la habilita');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = 'f1000000-0000-4000-8000-000000000002'$$), 3,
  'I2: con la vigente lee los movimientos del libro de Papá (3)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = pruebas.libro_personal('alex@ejemplo.test')$$), 0,
  'I2: y nada del libro de Alex, cuya consulta venció');

-- ---------------------------------------------------------------- con consulta registrada
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')),
  'Al abrir el libro de Ana, la consulta queda en la bitácora');
select pruebas.ok(public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer')
                  and not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'escribir')
                  and not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'administrar'),
  'fin_puede(): con la consulta vigente lee el libro de Ana; no escribe ni administra');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = pruebas.libro_personal('ana@ejemplo.test')
     or libro_destino_id = pruebas.libro_personal('ana@ejemplo.test')$$), 11,
  'Con la consulta ve los 11 movimientos que tocan el libro de Ana');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001'),
  1780000::bigint, '… y el saldo del banco de Ana');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('alex@ejemplo.test'), 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer'),
  'La consulta es POR LIBRO: el de Alex (vencida) y el compartido siguen cerrados');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('alex@ejemplo.test'))
                  and public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000001')
                  and public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000002'),
  'Consulta los otros tres libros (cada una queda en la bitácora; renovar una vigente es válido)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 21,
  'Con las cuatro consultas vigentes ve los 21 movimientos del hogar');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c4000000-0000-4000-8000-000000000001'),
  1500000::bigint, 'Y el saldo del banco de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where hogar_id = 'b0000000-0000-4000-8000-000000000002'$$), 0, 'Nada del hogar vecino');
select pruebas.ok(
  pruebas.cuenta($$select * from public.bitacora where registro_id = 'd1000000-0000-4000-8000-000000000023'$$) = 1
  and pruebas.cuenta($$select * from public.bitacora where accion = 'gravity.pregunta'$$) = 1,
  'En la bitácora ve las finanzas de los libros consultados y el historial de GRAVITY');
select pruebas.igual(
  (select detalle ->> 'vigencia_minutos' from public.bitacora
    where accion = 'finanzas.consulta_maestra' and registro_id = pruebas.libro_personal('ana@ejemplo.test')::text
      and persona_id = pruebas.id_persona('marta@ejemplo.test')),
  '30', 'La entrada dice cuánto vale la consulta: 30 minutos');

-- ---------------------------------------------------------------- no escribe en lo ajeno
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'No registra en el libro de Ana (ni con la consulta vigente)', '42501');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Ni en el compartido (no es miembro)', '42501');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000005', 100, p_motivo => 'x', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Ni en el de Papá', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set nombre = nombre || ' (x)'
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$), 0, 'No cambia cuentas de Ana');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'por_cerrar'
  where id = 'e6000000-0000-4000-8000-000000000001'$$), 0, 'No reabre semanas ajenas');
select pruebas.igual(pruebas.afecta($$update public.fin_parametros set meta_remanente_pb = 0$$), 1,
  'Solo cambia los parámetros de su propio libro');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$,
  'No se mete sola a un libro', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
  values ('c8000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
          pruebas.libro_personal('marta@ejemplo.test'), 'Banco de Marta', 'banco')$$), 1,
  'Lo suyo sí lo administra');
select pruebas.ok(
  pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('marta@ejemplo.test'), 'apertura'),
                    'c8000000-0000-4000-8000-000000000001', 10000) is not null,
  'Y registra en su propio libro');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libros (id, hogar_id, nombre, tipo)
  values ('f1000000-0000-4000-8000-0000000000c1', 'b0000000-0000-4000-8000-000000000001', 'Viaje de Marta (ejemplo)', 'compartido')$$), 1,
  'Y crea un libro propio (crear el suyo no es configurar el hogar)');

-- ---------------------------------------------------------------- M6: configuración del hogar
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'congelada' where libro_id is null$$), 0,
  'M6: la maestra no congela las cuentas de gasto del hogar');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = true$$), 0,
  'M6: ni archiva categorías');
select pruebas.igual(pruebas.afecta($$update public.fin_dias_inhabiles set activo = not activo$$), 0,
  'M6: ni cambia los festivos');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 1, 'Categoría de la maestra')$$,
  'M6: ni agrega categorías del hogar', '42501');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', null, 'Gasto de la maestra', 'de_gasto')$$,
  'M6: ni cuentas de gasto del hogar', '42501');
select pruebas.falla($$insert into public.fin_importaciones (hogar_id, archivo, hoja)
  values ('b0000000-0000-4000-8000-000000000001', 'x.xlsx', 'Categorías')$$,
  'M6: ni importa categorías', '42501');
select pruebas.igual(pruebas.afecta($$delete from public.fin_categorias where id = 'c1000000-0000-4000-8000-000000000003'$$), 0,
  'M6: ni borra categorías');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_dias_inhabiles set activo = activo
  where id = 'ec000000-0000-4000-8000-000000000001'$$), 1,
  'M6 es solo de la maestra: la pareja, que no lo es, sigue configurando lo del hogar');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_dias_inhabiles set activo = activo
  where id = 'ec000000-0000-4000-8000-000000000001'$$), 1, 'Y la dueña también');

-- ---------------------------------------------------------------- consultas en la bitácora
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not public.fin_registrar_consulta_maestra(pruebas.libro_personal('marta@ejemplo.test')),
  'Lo propio no se registra ni hace falta');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = pruebas.libro_personal('ana@ejemplo.test')::text
  and persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 1,
  'Ana ve que la cuenta maestra consultó su libro, y quién');
select pruebas.falla($$select public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000001')$$,
  'Solo la cuenta maestra registra consultas', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = pruebas.libro_personal('ana@ejemplo.test')::text
  and persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 0,
  'Alex no ve las consultas de la maestra al libro personal de Ana');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = 'f1000000-0000-4000-8000-000000000001'$$) >= 1,
  'Pero sí las del compartido, que también lleva');

-- ---------------------------------------------------------------- transparencia
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select nombre_visible from public.cuenta_maestra('b0000000-0000-4000-8000-000000000001')),
  'Marta Maestra', 'Cualquier miembro ve que la cuenta maestra existe y de quién es (Ajustes › Privacidad)');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual((select count(*)::int from public.cuenta_maestra('b0000000-0000-4000-8000-000000000001')), 0,
  'Alguien de otro hogar no');

-- ---------------------------------------------------------------- D18 y D19 en la bitácora del dueño
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'gravity.pregunta'$$), 0,
  'D18: la dueña no ve el historial de GRAVITY de la familiar');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where registro_id = 'd1000000-0000-4000-8000-000000000023'$$), 0,
  'D19: ni las finanzas personales de la pareja');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where tabla = 'membresias'$$) >= 6,
  'Pero sí los cambios de membresías (Ajustes del hogar)');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'gravity.pregunta'$$), 1,
  'Cada quien ve su propio historial');

-- ---------------------------------------------------------------- asignar la cuenta maestra
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('alex@ejemplo.test'))$$, 'Solo el dueño asigna la cuenta maestra', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.membresias set es_maestra = true
  where persona_id = pruebas.id_persona('alex@ejemplo.test')$$, 'No se marca directo en la tabla', '42501');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('carla@ejemplo.test'))$$, 'Una familiar no puede ser la cuenta maestra', '22023');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('casa@ejemplo.test'))$$, 'La cuenta Casa nunca (D3)', '22023');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('elena@ejemplo.test'))$$, 'Ni alguien de otro hogar', '22023');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'));
select pruebas.igual(
  (select string_agg(p.nombre_visible, ',') from public.membresias m join public.personas p on p.id = m.persona_id
    where m.hogar_id = 'b0000000-0000-4000-8000-000000000001' and m.es_maestra),
  'Alex Ejemplo', 'Una sola cuenta maestra a la vez: ahora Alex');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'membresias' and accion = 'actualizar'
                            and detalle -> 'despues' ->> 'es_maestra' = 'true'),
  'El cambio de cuenta maestra queda en la bitácora de membresías (la ve el dueño)');
select pruebas.falla($$update public.membresias set rol = 'familiar'
  where persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'La cuenta maestra no pasa a un rol sin Finanzas', '23514');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 2,
  'Marta dejó de ser maestra: solo ve su libro y el que creó');

-- M10: el cambio lo ve todo adulto con Finanzas (la pareja y la exmaestra), no los demás.
select pruebas.igual(
  (select detalle ->> 'anterior_persona_id' || ' > ' || (detalle ->> 'nueva_persona_id')
     from public.bitacora where accion = 'finanzas.maestra_asignada'),
  pruebas.id_persona('marta@ejemplo.test')::text || ' > ' || pruebas.id_persona('alex@ejemplo.test')::text,
  'M10: Marta ve que dejó de ser la cuenta maestra y quién la sustituye');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 0,
  'M10: una familiar (sin Finanzas) no lo ve');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 0,
  'M10: tampoco la cuidadora');

-- Alex, ahora maestro, no ve el libro de Ana hasta consultarlo (I2).
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'), 'Alex es ahora la cuenta maestra');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer'),
  'I2: sin consulta no lee el libro de Ana');

-- La dueña puede asignarse a sí misma (queda como pregunta al dueño), pero ya no sin rastro (I2/M10).
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.ok(public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
  'La dueña puede nombrarse cuenta maestra (decisión pendiente del dueño)');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('alex@ejemplo.test'), 'leer'),
  'I2: pero sin consulta tampoco lee el libro de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = pruebas.libro_personal('alex@ejemplo.test') and libro_destino_id is null$$), 0,
  'I2: ni sus movimientos');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('alex@ejemplo.test')),
  'Tras consultarlo (queda en la bitácora)…');
select pruebas.ok(public.fin_puede(pruebas.libro_personal('alex@ejemplo.test'), 'leer'), '… ya lo lee');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'congelada' where libro_id is null$$), 12,
  'M6: la dueña, aunque sea la maestra, sí configura el hogar (no se le quita)');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'
  and persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 1,
  'Alex ve que Ana, como maestra, consultó su libro');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 2,
  'M10: y los dos cambios de cuenta maestra');

select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 2,
  'Reasignar a la misma persona no repite la entrada');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', null);
select pruebas.igual(
  (select count(*)::int from public.membresias where hogar_id = 'b0000000-0000-4000-8000-000000000001' and es_maestra), 0,
  'Con nulo se quita la cuenta maestra');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 3,
  'M10: y también queda anotado');

-- La baja quita la lectura de la maestra al instante.
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'));
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')),
  'Marta vuelve a ser la maestra y consulta el libro de Ana');
select pruebas.como('ana@ejemplo.test');
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('marta@ejemplo.test');
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001')
                  and pruebas.cuenta('select * from public.fin_movimientos') = 0,
  'Dada de baja, la cuenta maestra ya no lee nada, aunque su consulta siga vigente');

rollback;
