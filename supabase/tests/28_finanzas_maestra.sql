-- D19: la cuenta maestra (una por hogar, la asigna el dueño) solo LEE todo
-- (libros y bitácora, incluido el historial de GRAVITY) y nunca escribe en lo
-- ajeno; cada consulta a un libro ajeno queda en la bitácora; cualquier
-- miembro ve que existe. D18: el dueño ya no ve el historial de GRAVITY ni
-- las finanzas personales de los demás en la bitácora.
begin;

-- Una entrada de historial de GRAVITY de la familiar (para D18).
select pruebas.como('carla@ejemplo.test');
insert into public.bitacora (hogar_id, accion, detalle)
values ('b0000000-0000-4000-8000-000000000001', 'gravity.pregunta', '{"tema": "receta"}');

-- ---------------------------------------------------------------- lee todo
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
  'Marta es la cuenta maestra del Hogar Ejemplo');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 5,
  'La cuenta maestra ve los 5 libros del hogar (Ana, Alex, el suyo, el compartido y el de Papá)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 21,
  'Y los 21 movimientos de todos los libros');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where hogar_id = 'b0000000-0000-4000-8000-000000000002'$$), 0, 'Nada del hogar vecino');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-000000000001'),
  1780000::bigint, 'Ve el saldo del banco de Ana');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c4000000-0000-4000-8000-000000000001'),
  1500000::bigint, 'Y el de Alex');
select pruebas.ok(
  pruebas.cuenta($$select * from public.bitacora where registro_id = 'd1000000-0000-4000-8000-000000000023'$$) = 1
  and pruebas.cuenta($$select * from public.bitacora where accion = 'gravity.pregunta'$$) = 1,
  'En la bitácora ve las finanzas personales y el historial de GRAVITY de todos');

-- ---------------------------------------------------------------- no escribe en lo ajeno
select pruebas.ok(public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer')
                  and not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'escribir')
                  and not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'administrar'),
  'fin_puede(): la cuenta maestra lee el libro de Ana y no escribe ni administra');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'No registra en el libro de Ana', '42501');
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

-- ---------------------------------------------------------------- consultas en la bitácora
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')),
  'Al abrir el libro de Ana, la consulta queda en la bitácora');
select pruebas.ok(not public.fin_registrar_consulta_maestra(pruebas.libro_personal('marta@ejemplo.test')),
  'Lo propio no se registra');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = pruebas.libro_personal('ana@ejemplo.test')::text
  and persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 1,
  'Ana ve que la cuenta maestra consultó su libro, y quién');
select pruebas.falla($$select public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000001')$$,
  'Solo la cuenta maestra registra consultas', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'$$), 0,
  'Alex no ve las consultas al libro personal de Ana');

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
  'El cambio de cuenta maestra queda en la bitácora');
select pruebas.falla($$update public.membresias set rol = 'familiar'
  where persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'La cuenta maestra no pasa a un rol sin Finanzas', '23514');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 1,
  'Marta dejó de ser maestra: solo ve su libro');
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', null);
select pruebas.igual(
  (select count(*)::int from public.membresias where hogar_id = 'b0000000-0000-4000-8000-000000000001' and es_maestra), 0,
  'Con nulo se quita la cuenta maestra');

-- La baja quita la lectura de la maestra al instante.
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'));
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('marta@ejemplo.test');
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001')
                  and pruebas.cuenta('select * from public.fin_movimientos') = 0,
  'Dada de baja, la cuenta maestra ya no lee nada');

rollback;
