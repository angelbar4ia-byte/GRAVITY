-- Entrega de avisos (Edge Function), retención, aviso al suplente de papá, retiro de una bolsa compartida y
-- consultas repetidas de la maestra (criterios 27, 40, 42, 49, 50 y P12).
begin;

select pruebas.nuevo_adulto('teo@ejemplo.test');
select pruebas.como_postgres();

-- ---------------------------------------------------------------- reclamar (skip locked) y dispositivos
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '2 days')$$), 1,
  'Se reclama el aviso de Ana: un renglón por aviso y dispositivo (su teléfono; no la laptop)');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '2 days' + interval '1 minute')$$), 0,
  'Una segunda corrida inmediata no recibe nada (skip locked / reclamado)');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '2 days' + interval '4 minutes')$$), 1,
  'Si la primera corrida murió, a los 3 minutos se libera');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '1 hour')$$), 0,
  'Un aviso que aún no toca (enviar_en futuro) no se reclama');

-- La tablet pública nunca recibe, aunque sea el único dispositivo.
delete from public.dispositivos where persona_id = pruebas.id_persona('ana@ejemplo.test');
insert into public.dispositivos (persona_id, plataforma, token_avisos, nombre, tipo)
values (pruebas.id_persona('ana@ejemplo.test'), 'android', 'tok-publica-ana', 'Tablet', 'tablet_publica');
update public.avisos set reclamado_hasta = null;
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '9 days')$$), 0,
  'Una tablet pública no recibe avisos de dinero: no se reclama nada para ella');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-publica-ana'),
  '… (el trigger la mantiene apagada)');
update public.dispositivos set tipo = 'tablet_personal', recibe_avisos = false where token_avisos = 'tok-publica-ana';
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '9 days')$$), 0,
  'Una tablet personal apagada (por omisión) tampoco');
update public.dispositivos set recibe_avisos = true where token_avisos = 'tok-publica-ana';
update public.avisos set reclamado_hasta = null;
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '9 days')$$), 1,
  'Una tablet personal que la persona prende sí');
-- Persona dada de baja: no se le envía.
update public.avisos set reclamado_hasta = null;
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '9 days')$$), 0,
  'A quien se dio de baja del hogar no se le envía');
update public.membresias set activa = true, hasta = null where persona_id = pruebas.id_persona('ana@ejemplo.test');

-- Quién puede llamar a estas funciones.
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select * from public.avisos_reclamar()$$, 'La app no reclama avisos', '42501');
select pruebas.falla($$select public.avisos_resultado_envio(gen_random_uuid(), true)$$, 'ni registra resultados', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.avisos_reclamar()$$, 'Sin sesión tampoco', '42501');
select pruebas.como_servicio();
select pruebas.ok(pruebas.cuenta($$select * from public.avisos_reclamar(200, now() + interval '30 days')$$) >= 0, 'service_role sí (la Edge Function)');
select pruebas.como_postgres();

-- ---------------------------------------------------------------- entregas y reintentos
update public.avisos set reclamado_hasta = null;
select public.avisos_registrar_entrega(
  (select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'),
  (select id from public.dispositivos where token_avisos = 'tok-publica-ana'), 'error', '503');
select pruebas.igual((select fallos from public.dispositivos where token_avisos = 'tok-publica-ana'), 1::smallint, 'Un error suma un fallo');
select public.avisos_registrar_entrega((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'),
  (select id from public.dispositivos where token_avisos = 'tok-publica-ana'), 'ok', '200');
select pruebas.igual((select fallos from public.dispositivos where token_avisos = 'tok-publica-ana'), 0::smallint, 'Un envío bueno los reinicia');
select public.avisos_registrar_entrega((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'),
  (select id from public.dispositivos where token_avisos = 'tok-publica-ana'), 'error', '500')
  from generate_series(1, 5);
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-publica-ana'),
  'Tras 5 fallos seguidos el dispositivo se desactiva');
select public.avisos_registrar_entrega((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'),
  (select id from public.dispositivos where token_avisos = 'tok-publica-ana'), 'token_invalido', 'UNREGISTERED');
select pruebas.igual(pruebas.cuenta($$select * from public.dispositivos where token_avisos = 'tok-publica-ana'$$), 0,
  'FCM responde UNREGISTERED: se borra el token');
select pruebas.igual((select count(*)::int from public.avisos_entregas), 8, 'Cada intento quedó en avisos_entregas');
select pruebas.falla($$select public.avisos_registrar_entrega(gen_random_uuid(), null, 'raro')$$, 'Resultado desconocido', '22023');

-- Reintentos a los 5, 15 y 60 minutos; después, enviado sin entrega.
update public.avisos set estado = 'pendiente', intentos = 0, enviar_en = '2026-11-01 10:00-06' where clave = 'fondo_bajo:ejemplo:2026-w43';
select public.avisos_resultado_envio((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), false, '2026-11-01 10:00-06');
select pruebas.igual((select intentos || ' ' || estado || ' ' || to_char(enviar_en at time zone 'America/Mexico_City', 'HH24:MI')
  from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), '1 pendiente 10:05', 'Primer fallo: reintento a los 5 minutos');
select public.avisos_resultado_envio((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), false, '2026-11-01 10:05-06');
select pruebas.igual((select intentos || ' ' || to_char(enviar_en at time zone 'America/Mexico_City', 'HH24:MI')
  from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), '2 10:20', 'Segundo: a los 15 minutos');
select public.avisos_resultado_envio((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), false, '2026-11-01 10:20-06');
select pruebas.igual((select intentos || ' ' || to_char(enviar_en at time zone 'America/Mexico_City', 'HH24:MI')
  from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), '3 11:20', 'Tercero: a los 60 minutos');
select public.avisos_resultado_envio((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), false, '2026-11-01 11:20-06');
select pruebas.igual((select estado from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), 'enviada',
  'Después se da por enviado sin entrega (queda en la bandeja)');
update public.avisos set estado = 'pendiente' where clave = 'fondo_bajo:ejemplo:2026-w43';
select public.avisos_resultado_envio((select id from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'), true, '2026-11-01 12:00-06');
select pruebas.igual((select estado || ' ' || (enviada_en is not null)::text from public.avisos where clave = 'fondo_bajo:ejemplo:2026-w43'),
  'enviada true', 'Un envío bueno marca enviada');

-- ---------------------------------------------------------------- 49: retención
insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, programado_para, enviar_en, creado_en)
select gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'sistema', 'base_80', 'importante',
       'viejo:' || d, now(), now(), now() - (d || ' days')::interval
from unnest(array[89, 91, 120]) d;
insert into public.avisos_entregas (aviso_id, resultado, enviada_en)
select (select id from public.avisos where clave = 'viejo:89'), 'ok', now() - (d || ' days')::interval from unnest(array[29, 31, 60]) d;
select pruebas.igual((select count(*)::int from public.bitacora where tabla like 'avisos%'), 0,
  'La bitácora no crece por cada aviso');
select pruebas.igual(public.avisos_limpiar(), 2, 'La limpieza borra los avisos de más de 90 días (2)');
select pruebas.igual((select string_agg(clave, ',' order by clave) from public.avisos where clave like 'viejo:%'), 'viejo:89',
  '… y deja el de 89');
select pruebas.igual((select count(*)::int from public.avisos_entregas e where e.aviso_id = (select id from public.avisos where clave = 'viejo:89')
  and e.enviada_en < now() - interval '30 days'), 0, 'Las entregas de más de 30 días se borran');
select pruebas.igual((select count(*)::int from public.avisos_entregas e where e.aviso_id = (select id from public.avisos where clave = 'viejo:89')
  and e.enviada_en >= now() - interval '30 days'), 1, '… y las recientes quedan');
select pruebas.ok((select count(*) > 0 from public.fin_movimientos) and (select count(*) > 0 from public.bitacora),
  'Nada más se borra: los movimientos y la bitácora siguen');
select pruebas.falla($$truncate public.bitacora$$, 'La bitácora no se toca', '42501');

-- ---------------------------------------------------------------- 40: aviso al suplente de papá
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 1000,
  p_motivo => 'Medicinas de papá (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
  p_id => 'ee200000-0000-4000-8000-000000000001') is not null, 'Ana (albacea) pasa dinero de papá a su libro');
select pruebas.como_postgres();
select pruebas.igual(
  (select string_agg(u.email || ':' || a.tipo || ':' || a.severidad, ',') from public.avisos a
     join public.personas p on p.id = a.persona_id join auth.users u on u.id = p.usuario_id
    where a.clave = 'salida_libro_representado:ee200000-0000-4000-8000-000000000001'),
  'alex@ejemplo.test:salida_libro_representado:importante',
  'El suplente (Alex) recibe el aviso, y no quien hizo el movimiento');
select pruebas.ok(exists (select 1 from public.bitacora where accion = 'finanzas.salida_libro_representado'
  and registro_id = 'ee200000-0000-4000-8000-000000000001'), 'La entrada de bitácora de la Fase 1b sigue igual');
select pruebas.igual((select objeto_tipo || ' ' || (objeto_id = 'ee200000-0000-4000-8000-000000000001')::text from public.avisos
  where clave = 'salida_libro_representado:ee200000-0000-4000-8000-000000000001'), 'movimiento true', 'El aviso apunta al movimiento');
-- Sin suplente vigente no pasa nada.
update public.fin_libro_miembros set hasta = now() where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea_suplente';
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 1000,
  p_motivo => 'Más medicinas (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
  p_id => 'ee200000-0000-4000-8000-000000000002') is not null, 'Otra salida, ya sin suplente');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos where clave = 'salida_libro_representado:ee200000-0000-4000-8000-000000000002'), 0,
  'Sin suplente vigente no se avisa a nadie');
-- Si el suplente es quien hace el movimiento, no se avisa a sí mismo.
update public.fin_libro_miembros set hasta = now() where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', pruebas.id_persona('alex@ejemplo.test'), 'albacea_suplente');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001', 'c4000000-0000-4000-8000-000000000001', 1000,
  p_motivo => 'Gasto de papá (ejemplo)', p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
  p_id => 'ee200000-0000-4000-8000-000000000003') is not null, 'El suplente (único que lleva el libro) hace una salida');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos where clave = 'salida_libro_representado:ee200000-0000-4000-8000-000000000003'), 0,
  'No se avisa a quien hizo el movimiento');

-- ---------------------------------------------------------------- 27: retiro de una bolsa compartida avisa a los otros
select pruebas.como('ana@ejemplo.test');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9300000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Ahorro de la casa', 'ahorro'),
  ('c9300000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Banco de la casa', 'banco');
insert into public.fin_bolsas_ahorro (id, hogar_id, libro_id, nombre, tipo, cuenta_id)
values ('ea000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
        'Vacaciones', 'meta_libre', 'c9300000-0000-4000-8000-000000000001');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(pruebas.registrar('transferencia', 'c9300000-0000-4000-8000-000000000001', 'c9300000-0000-4000-8000-000000000002', 5000,
  p_id => 'ee200000-0000-4000-8000-000000000004') is not null, 'Alex (miembro) retira de la bolsa compartida');
select pruebas.igual(pruebas.afecta($$insert into public.fin_retiros_ahorro (id, hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, registrado_en)
  values ('e7000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          'ea000000-0000-4000-8000-000000000004', 'ee200000-0000-4000-8000-000000000004', 'uso_previsto', 'Pago del hotel', now())$$), 1,
  'y registra el retiro');
select pruebas.como_postgres();
select pruebas.igual(
  (select string_agg(u.email || ':' || a.tipo || ':' || a.severidad, ',') from public.avisos a
     join public.personas p on p.id = a.persona_id join auth.users u on u.id = p.usuario_id
    where a.clave = 'retiro_bolsa_compartida:e7000000-0000-4000-8000-000000000002'),
  'ana@ejemplo.test:retiro_bolsa_compartida:informativa', 'Los OTROS miembros reciben el aviso informativo; quien retiró, no');

-- ---------------------------------------------------------------- P12: consultas repetidas de la maestra
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000001'), 'La maestra consulta un libro');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000001'), '… y otra vez en el mismo minuto');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = 'f1000000-0000-4000-8000-000000000001'), 1, 'Una sola entrada por minuto y libro');
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000002'), 'Otro libro sí deja su propia entrada');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'finanzas.consulta_maestra'), 2, 'Una por libro');
-- Una entrada de hace más de un minuto no frena la siguiente: se prueba con otro libro y una entrada vieja.
insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle, registrado_en)
values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'finanzas.consulta_maestra', 'fin_libros',
        pruebas.libro_personal('ana@ejemplo.test')::text, '{}', now() - interval '2 minutes');
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')), 'La maestra consulta el libro de Ana');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = pruebas.libro_personal('ana@ejemplo.test')::text), 2,
  'Con la entrada anterior de hace 2 minutos, la nueva sí se registra');

rollback;
