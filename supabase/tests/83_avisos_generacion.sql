-- Generación de avisos (criterios 34 a 39 y 41): vencimientos, pago vencido, idempotencia, silencio,
-- tope diario y destinatarios. p_ahora de las funciones permite fijar la hora (zona de México, UTC-6).
begin;

-- Una ocurrencia de pago de la tarjeta de Ana (jueves 12/nov/2026) y otra del préstamo familiar.
select pruebas.como('ana@ejemplo.test');
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee100000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
        'deuda', 'e5000000-0000-4000-8000-000000000001', '2026-11-12', '2026-11-12', 120000);
select pruebas.como_postgres();

-- ---------------------------------------------------------------- 34: días antes
select pruebas.ok(public.avisos_generar_vencimientos('2026-11-02 12:00-06') >= 2, 'La corrida del 2/nov crea avisos');
select pruebas.igual(
  (select string_agg(to_char(enviar_en at time zone 'America/Mexico_City', 'YYYY-MM-DD HH24:MI') || ' ' || tipo || ' ' || severidad,
                     ' | ' order by enviar_en)
     from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001'),
  '2026-11-09 09:00 limite_tarjeta critica | 2026-11-11 09:00 limite_tarjeta critica',
  'Pago el jueves 12/nov: avisos el lunes 9/nov y el miércoles 11/nov a las 9:00 (límite de tarjeta, crítico)');
select pruebas.igual(
  (select count(distinct persona_id)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001'), 1,
  'Solo el titular del libro personal');
select pruebas.igual(
  (select persona_id from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001' limit 1),
  pruebas.id_persona('ana@ejemplo.test'), '… Ana');
select pruebas.igual(public.avisos_generar_vencimientos('2026-11-02 12:00-06'), 0,
  '36: correr la generación otra vez no duplica nada');

-- Deuda dada de alta el 11/nov (su pago es el 12/nov): solo el aviso del 11, sin avalancha de atrasados.
select pruebas.como('ana@ejemplo.test');
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee100000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
        'deuda', 'e5000000-0000-4000-8000-000000000002', '2026-11-12', '2026-11-12', 50000);
select pruebas.como_postgres();
select public.avisos_generar_vencimientos('2026-11-11 08:00-06');
select pruebas.igual(
  (select string_agg(to_char(enviar_en at time zone 'America/Mexico_City', 'YYYY-MM-DD HH24:MI') || ' ' || tipo, ' | ' order by enviar_en)
     from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000002'),
  '2026-11-11 09:00 pago_proximo', 'Dada de alta el 11/nov: solo se crea el aviso del 11 (el del 9 ya pasó y no se recupera)');
select pruebas.igual(
  (select severidad from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000002'), 'critica',
  'El pago de una deuda es crítico');

-- Cambiar la fecha cancela los avisos viejos y crea los nuevos.
update public.fin_ocurrencias set fecha_ajustada = '2026-11-13' where id = 'ee100000-0000-4000-8000-000000000001';
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001' and estado = 'cancelada'), 2,
  '36: al cambiar la fecha los avisos pendientes del paso viejo quedan cancelados');
select public.avisos_generar_vencimientos('2026-11-02 12:00-06');
select pruebas.igual(
  (select string_agg(to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI'), ' | ' order by enviar_en)
     from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001' and estado = 'pendiente'),
  '11-10 09:00 | 11-12 09:00', '… y se crean los de la fecha nueva (3 y 1 días antes del 13)');

-- 35 / 38: registrar el pago cancela los pendientes.
update public.fin_ocurrencias set estado = 'cumplida' where id = 'ee100000-0000-4000-8000-000000000001';
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001' and estado = 'pendiente'), 0,
  'Registrar el pago (ocurrencia cumplida) cancela los avisos pendientes');
select pruebas.igual(public.avisos_generar_vencimientos('2026-11-02 12:00-06') >= 0, true, 'y la generación no los revive');
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000001' and estado = 'pendiente'), 0,
  '… (sigue en cero)');

-- 35: pago vencido.
select pruebas.como('ana@ejemplo.test');
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee100000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
        'deuda', 'e5000000-0000-4000-8000-000000000001', '2026-12-04', '2026-12-04', 120000);
select pruebas.como_postgres();
select public.avisos_generar_vencimientos('2026-12-05 10:00-06');
select pruebas.igual((select estado from public.fin_ocurrencias where id = 'ee100000-0000-4000-8000-000000000003'), 'retrasada',
  'Un pago esperado cuyo día pasó queda retrasado');
select pruebas.igual(
  (select string_agg(tipo || ' ' || severidad || ' ' || to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI'),
                     ' | ' order by enviar_en)
     from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000003'),
  'pago_vencido critica 12-05 10:00 | pago_vencido critica 12-07 09:00',
  'Aviso crítico el día siguiente y otro a los 3 días');
select public.avisos_generar_vencimientos('2026-12-09 10:00-06');
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000003'), 2, 'Después se calla (no hay más)');
update public.fin_ocurrencias set estado = 'cumplida' where id = 'ee100000-0000-4000-8000-000000000003';
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000003' and estado = 'pendiente'), 0,
  'Registrar el pago cancela los pendientes del vencido');

-- 7: un pago con monto cero no avisa.
select pruebas.como('ana@ejemplo.test');
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee100000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
        'deuda', 'e5000000-0000-4000-8000-000000000001', '2027-01-12', '2027-01-12', 0);
select pruebas.como_postgres();
select public.avisos_generar_vencimientos('2027-01-05 10:00-06');
select pruebas.igual((select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000004'), 0,
  'Un pago con monto esperado en cero no avisa');

-- Ingreso retrasado: el viernes 6/nov no llegó; el siguiente día hábil es el lunes 9/nov.
select pruebas.como('ana@ejemplo.test');
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee100000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
        'ingreso', 'e1000000-0000-4000-8000-000000000001', '2026-11-06', '2026-11-06', 900000);
select pruebas.como_postgres();
select public.avisos_generar_vencimientos('2026-11-09 10:00-06');
select pruebas.igual(
  (select tipo || ' ' || severidad from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000005'),
  'ingreso_retrasado importante', 'Ingreso sin llegar al siguiente día hábil: aviso importante');
select pruebas.igual(public.avisos_generar_vencimientos('2026-11-09 10:00-06'), 0, 'y uno solo');

-- ---------------------------------------------------------------- 39: libro compartido = todos los miembros
select pruebas.como('ana@ejemplo.test');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9100000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Crédito de la casa', 'prestamo');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma, dias_mes,
                               minimo_centavos, tasa_anual_pb)
values ('e5100000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
        'Crédito de la casa', 'con_costo', 'c9100000-0000-4000-8000-000000000001', 100000, 'mensual', 'mensual', '{25}', 100000, 2400);
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee100000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
        'deuda', 'e5100000-0000-4000-8000-000000000001', '2026-11-25', '2026-11-25', 100000);
select pruebas.igual((select clase from public.fin_deudas where id = 'e5100000-0000-4000-8000-000000000001'), 'credito',
  'Sin clase en el INSERT, el servidor la deduce (con_costo en cuenta prestamo = credito)');
select pruebas.como_postgres();
select pruebas.como('alex@ejemplo.test');
select public.avisos_actualizar_preferencias(p_hora_vencimientos => time '08:00');
select pruebas.como_postgres();
select public.avisos_generar_vencimientos('2026-11-18 12:00-06');
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000006'), 4,
  'Compartido: 2 avisos (3 y 1 días antes) para cada uno de sus 2 miembros');
select pruebas.igual(
  (select string_agg(to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI'), ',' order by enviar_en)
     from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000006'
       and persona_id = pruebas.id_persona('alex@ejemplo.test')),
  '11-22 08:00,11-24 08:00', 'Cada quien a su hora (Alex pidió las 8:00)');
select pruebas.igual(
  (select string_agg(to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI'), ',' order by enviar_en)
     from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000006'
       and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  '11-22 09:00,11-24 09:00', '… y Ana a las 9:00');
select pruebas.igual(
  (select count(*)::int from public.avisos where objeto_id = 'ee100000-0000-4000-8000-000000000006'
     and persona_id not in (pruebas.id_persona('ana@ejemplo.test'), pruebas.id_persona('alex@ejemplo.test'))), 0,
  'Nunca la maestra, ni familiar, cuidador o Casa');

-- ---------------------------------------------------------------- 37: horas silenciosas
select pruebas.igual(public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'pago_proximo', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'sil:critica', '2027-02-01 23:00-06',
  null, '2027-02-01 12:00-06'), true, 'Se crea un aviso crítico programado a las 23:00');
select pruebas.igual((select to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI') from public.avisos where clave = 'sil:critica'),
  '02-02 07:00', 'Una crítica de las 23:00 sale a las 07:00');
select pruebas.como('ana@ejemplo.test');
select public.avisos_actualizar_preferencias(p_criticas_en_silencio => true);
select pruebas.como_postgres();
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'pago_proximo', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'sil:critica2', '2027-02-01 23:00-06',
  null, '2027-02-01 12:00-06');
select pruebas.igual((select to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI') from public.avisos where clave = 'sil:critica2'),
  '02-01 23:00', 'Con criticas_en_silencio sale a su hora');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'partida_100', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'sil:noncritica', '2027-02-01 23:00-06',
  null, '2027-02-01 12:00-06');
select pruebas.igual((select to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI') from public.avisos where clave = 'sil:noncritica'),
  '02-02 07:00', 'Los no críticos nunca suenan de noche, aunque se permitan las críticas');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'partida_100', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'sil:madrugada', '2027-02-02 03:00-06',
  null, '2027-02-02 02:00-06');
select pruebas.igual((select to_char(enviar_en at time zone 'America/Mexico_City', 'MM-DD HH24:MI') from public.avisos where clave = 'sil:madrugada'),
  '02-02 07:00', 'De madrugada sale el mismo día a las 07:00');

-- ---------------------------------------------------------------- 38: tope diario (Alex: 3 no críticos al día)
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'finanzas',
  'partida_100', 'f1000000-0000-4000-8000-000000000001', null, null, 'tope:' || g, '2027-03-02 10:00-06', null, '2027-03-01 12:00-06')
  from generate_series(1, 4) g;
select pruebas.igual((select string_agg(estado, ',' order by clave) from public.avisos where clave like 'tope:%'),
  'pendiente,pendiente,pendiente,agrupada', 'Con 4 no críticos el mismo día salen 3 y el cuarto queda agrupado (y visible)');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'finanzas',
  'pago_proximo', 'f1000000-0000-4000-8000-000000000001', null, null, 'tope:critica', '2027-03-02 10:00-06', null, '2027-03-01 12:00-06');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'finanzas',
  'resumen_lunes', 'f1000000-0000-4000-8000-000000000001', null, null, 'tope:resumen', '2027-03-02 10:00-06', null, '2027-03-01 12:00-06');
select pruebas.igual((select string_agg(estado, ',' order by clave) from public.avisos where clave in ('tope:critica', 'tope:resumen')),
  'pendiente,pendiente', 'Las críticas y los recordatorios fijos no cuentan ni se agrupan');
-- El día se mide en la zona de la persona: en Tokio (UTC+9) la 1:00 del día 2 cae en otro día que las 21:00 del día 1.
select pruebas.como('ana@ejemplo.test');
select public.avisos_actualizar_preferencias(p_zona_horaria => 'Asia/Tokyo', p_tope_no_criticas => 1);
select pruebas.como_postgres();
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'partida_100', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'zona:a', '2027-05-01 12:00+00', null, '2027-05-01 00:00+00');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'partida_100', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'zona:b', '2027-05-01 16:00+00', null, '2027-05-01 00:00+00');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'partida_100', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'zona:c', '2027-05-01 13:00+00', null, '2027-05-01 00:00+00');
select pruebas.igual((select string_agg(clave || '=' || estado, ',' order by clave) from public.avisos where clave like 'zona:%'),
  'zona:a=pendiente,zona:b=pendiente,zona:c=agrupada',
  'Tope 1 en Tokio: a (21:00 del 1) y b (a las 07:00 del 2) son de días distintos; c es el segundo del día 1');

-- Un tipo silenciado no suena pero sigue en la bandeja.
select pruebas.como('alex@ejemplo.test');
select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['fondo_bajo']);
select public.fin_emitir_aviso(pruebas.libro_personal('alex@ejemplo.test'), 'fondo_bajo', null, null, 'silenciado:1');
select pruebas.igual((select estado from public.avisos where clave = 'silenciado:1'), 'agrupada',
  'Un tipo silenciado queda a la vista en la bandeja pero no suena (agrupada)');

-- ---------------------------------------------------------------- avisos_marcar
select pruebas.como('alex@ejemplo.test');
select public.avisos_marcar(md5('aviso:' || pruebas.id_persona('alex@ejemplo.test')::text || ':tope:critica')::uuid, 'leida');
select pruebas.igual((select estado from public.avisos where clave = 'tope:critica'), 'leida', 'Alex marca su aviso como leído');
select public.avisos_marcar(md5('aviso:' || pruebas.id_persona('alex@ejemplo.test')::text || ':tope:critica')::uuid, 'posponer_1h');
select pruebas.ok((select estado = 'pospuesta' and enviar_en >= now() + interval '59 minutes' from public.avisos where clave = 'tope:critica'),
  'Posponer 1 hora: vuelve a salir dentro de una hora');
select public.avisos_marcar(md5('aviso:' || pruebas.id_persona('alex@ejemplo.test')::text || ':tope:critica')::uuid, 'posponer_manana');
select pruebas.ok((select estado = 'pospuesta' and enviar_en > now() + interval '1 hour' from public.avisos where clave = 'tope:critica'),
  'Posponer hasta mañana');
select public.avisos_marcar(md5('aviso:' || pruebas.id_persona('alex@ejemplo.test')::text || ':tope:critica')::uuid, 'resuelta');
select pruebas.ok((select estado = 'resuelta' and resuelta_en is not null from public.avisos where clave = 'tope:critica'), 'Hecho');
select pruebas.falla($$select public.avisos_marcar(md5('aviso:' || pruebas.id_persona('alex@ejemplo.test')::text || ':tope:critica')::uuid, 'borrar')$$,
  'Acción desconocida', '22023');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.avisos_marcar(md5('aviso:' || pruebas.id_persona('alex@ejemplo.test')::text || ':tope:critica')::uuid, 'leida')$$,
  'Nadie marca los avisos de otra persona', '42501');

rollback;
