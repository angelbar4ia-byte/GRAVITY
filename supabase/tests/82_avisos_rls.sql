-- Avisos (D20): esquema sin dinero ni texto libre, RLS, preferencias, dispositivos y fin_emitir_aviso
-- (criterios 32 -esquema-, 39, 41, 42 y 47 de docs/specs/fase-2-finanzas.md).
begin;

select pruebas.nuevo_adulto('teo@ejemplo.test');

-- ---------------------------------------------------------------- esquema: nada de dinero ni de texto libre
select pruebas.como_postgres();
select pruebas.igual(
  (select string_agg(column_name, ',' order by column_name) from information_schema.columns
    where table_schema = 'public' and table_name = 'avisos'),
  'clave,creado_en,emitido_por,enviada_en,enviar_en,estado,hogar_id,id,intentos,leida_en,libro_id,modulo,objeto_id,objeto_tipo,persona_id,programado_para,reclamado_hasta,resuelta_en,severidad,tipo',
  'D3: avisos no tiene columnas de monto, de nombre ni de texto libre');
select pruebas.ok(not exists (select 1 from information_schema.columns
  where table_schema = 'public' and table_name in ('avisos', 'avisos_entregas', 'avisos_preferencias', 'avisos_sistema')
    and column_name <> 'pulsera_texto_corto'
    and column_name ~* '(monto|centavos|nombre|texto|titulo|cuerpo|mensaje|comercio|descripcion)'),
  'Ninguna tabla de avisos lleva columnas de monto, nombre, título ni cuerpo');
select pruebas.falla($$insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, programado_para, enviar_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'sistema',
          'Pago de $500 a Banco', 'critica', 'x', now(), now())$$, 'El tipo es de un catálogo cerrado', '23514');
select pruebas.falla($$insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, programado_para, enviar_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'sistema',
          'base_80', 'importante', 'Pago de $500 a Banco', now(), now())$$,
  'La clave no es texto libre (solo minúsculas, dígitos y _ : . -)', '23514');

-- ---------------------------------------------------------------- RLS de avisos
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos$$), 1, 'Ana ve su aviso de ejemplo');
select pruebas.falla($$insert into public.avisos (id, hogar_id, persona_id, modulo, tipo, severidad, clave, programado_para, enviar_en)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'sistema',
          'base_80', 'importante', 'a-mano', now(), now())$$, 'Nadie inserta avisos directo', '42501');
select pruebas.falla($$update public.avisos set estado = 'leida'$$, 'Nadie los cambia directo', '42501');
select pruebas.falla($$delete from public.avisos$$, 'Nadie los borra', '42501');
select pruebas.falla($$select * from public.avisos_entregas$$, 'avisos_entregas no es legible para la app', '42501');
select pruebas.falla($$select * from public.avisos_sistema$$, 'avisos_sistema tampoco', '42501');
select pruebas.falla($$update public.avisos_preferencias set tope_no_criticas = 9$$, 'Las preferencias se cambian con la función', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos$$), 0, 'La pareja no ve los avisos de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_preferencias$$), 1, 'Alex ve solo sus preferencias');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos$$), 0, 'Otro hogar no ve nada');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos$$) + pruebas.cuenta($$select * from public.avisos_preferencias$$), 0,
  'Una familiar no ve avisos ni preferencias');
select pruebas.como_anon();
select pruebas.falla($$select * from public.avisos$$, 'Sin sesión no se lee nada', '42501');

-- ---------------------------------------------------------------- preferencias: quién las tiene
select pruebas.como_postgres();
select pruebas.igual(
  (select string_agg(u.email, ',' order by u.email) from public.avisos_preferencias p
     join public.personas pe on pe.id = p.persona_id join auth.users u on u.id = pe.usuario_id),
  'alex@ejemplo.test,ana@ejemplo.test,elena@ejemplo.test,teo@ejemplo.test',
  'Tienen preferencias los adultos con Finanzas; no la maestra, ni familiar, cuidador o Casa');
select pruebas.igual((select tope_no_criticas from public.avisos_preferencias where persona_id = pruebas.id_persona('ana@ejemplo.test')),
  3::smallint, 'Por omisión: tope de 3 no críticos');
select pruebas.igual((select silencio_desde::text || '-' || silencio_hasta::text || ' ' || hora_vencimientos::text
  from public.avisos_preferencias where persona_id = pruebas.id_persona('ana@ejemplo.test')),
  '22:00:00-07:00:00 09:00:00', '… silencio de 22:00 a 07:00 y avisos a las 9:00');
update public.membresias set rol = 'familiar' where persona_id = pruebas.id_persona('teo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos_preferencias where persona_id = pruebas.id_persona('teo@ejemplo.test')$$), 0,
  'Quien pierde Finanzas pierde sus preferencias');
update public.membresias set rol = 'coadministrador' where persona_id = pruebas.id_persona('teo@ejemplo.test');
select pruebas.igual((select count(*)::int from public.avisos_preferencias where persona_id = pruebas.id_persona('teo@ejemplo.test')), 1,
  'y las recupera al volver a tenerla');

-- ---------------------------------------------------------------- preferencias: cada quien las suyas, con rangos
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tope_no_criticas => 11)$$, 'Tope fuera de 0 a 10', '22023');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tope_no_criticas => -1)$$, 'Tope negativo', '22023');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_zona_horaria => 'Marte/Fobos')$$, 'Zona desconocida', '22023');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_recordatorio_cierre_dia => 8)$$, 'Día del recordatorio', '22023');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tipos_silenciados => array['pago de $5'])$$,
  'Tipo del catálogo', '22023');
select public.avisos_actualizar_preferencias(p_tope_no_criticas => 5, p_criticas_en_silencio => true,
    p_tipos_silenciados => array['partida_80']);
select pruebas.igual((select tope_no_criticas from public.avisos_preferencias), 5::smallint, '… y quedan');
select pruebas.igual((select hora_vencimientos::text from public.avisos_preferencias), '09:00:00', '… lo que no pidió no cambia');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select tope_no_criticas from public.avisos_preferencias), 3::smallint, 'Las de Alex no se movieron');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tope_no_criticas => 2)$$,
  'La maestra no tiene preferencias de dinero', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tope_no_criticas => 2)$$, 'Una familiar tampoco', '42501');

-- ---------------------------------------------------------------- dispositivos (M13)
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.registrar_dispositivo('tok-carla', 'android', 'Teléfono de Carla', 'telefono') is not null,
  'Carla registra su teléfono');
select pruebas.ok((select recibe_avisos from public.dispositivos where token_avisos = 'tok-carla'),
  'Un teléfono recibe avisos por omisión');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.registrar_dispositivo('tok-tablet-ana', 'android', 'Tablet de Ana', 'tablet_personal') is not null,
  'Ana registra su tablet personal');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-tablet-ana'),
  'La tablet personal está apagada por omisión');
select pruebas.igual(pruebas.afecta($$update public.dispositivos set recibe_avisos = true where token_avisos = 'tok-tablet-ana'$$), 1,
  '… y Ana la puede prender');
select pruebas.ok(public.registrar_dispositivo('tok-tablet-ana', 'android', 'Tablet de Ana', 'tablet_personal') is not null,
  'Ana registra la misma tablet otra vez (al abrir la app)');
select pruebas.ok((select recibe_avisos from public.dispositivos where token_avisos = 'tok-tablet-ana'),
  '… y no se apaga su elección');
select pruebas.ok(public.registrar_dispositivo('tok-laptop-ana', 'windows', 'Laptop', 'laptop') is not null, 'Ana registra su laptop');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-laptop-ana'),
  'La laptop no recibe push por omisión');
select pruebas.ok(public.registrar_dispositivo('tok-publica', 'android', 'Tablet de la casa', 'tablet_publica') is not null,
  'Se registra una tablet pública');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-publica'),
  'Una tablet pública nunca recibe avisos');
select pruebas.igual(pruebas.afecta($$update public.dispositivos set recibe_avisos = true where token_avisos = 'tok-publica'$$), 1,
  'Aunque se intente prender…');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-publica'), '… sigue apagada (trigger)');
select pruebas.falla($$insert into public.dispositivos (plataforma, token_avisos) values ('android', 'tok-directo')$$,
  'No se inserta directo', '42501');
select pruebas.falla($$update public.dispositivos set token_avisos = 'otro' where token_avisos = 'tok-publica'$$,
  'El token no se cambia a mano', '42501');
select pruebas.falla($$select public.registrar_dispositivo('t', 'android', 'x', 'reloj')$$, 'Tipo desconocido', '22023');
select pruebas.falla($$select public.registrar_dispositivo('', 'android')$$, 'Token vacío', '22023');
-- Entrar con otra cuenta en el mismo equipo reasigna el token.
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.registrar_dispositivo('tok-tablet-ana', 'android', 'Tablet', 'tablet_personal') is not null,
  'Alex entra en la misma tablet y registra el mismo token');
select pruebas.igual(pruebas.cuenta($$select * from public.dispositivos where token_avisos = 'tok-tablet-ana'$$), 1, 'El token es de Alex');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-tablet-ana'),
  '… y empieza apagado (no hereda la elección de Ana)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.dispositivos where token_avisos = 'tok-tablet-ana'$$), 0,
  'Ana ya no lo tiene (M13: un token, una persona)');
select pruebas.ok(public.quitar_dispositivo('tok-laptop-ana'), 'quitar_dispositivo borra el suyo');
select pruebas.ok(not public.quitar_dispositivo('tok-carla'), '… pero no el de otra persona');
select pruebas.como_postgres();
select pruebas.ok((select count(*) = 1 from public.dispositivos where token_avisos = 'tok-carla'), 'El de Carla sigue');
select pruebas.falla($$insert into public.dispositivos (persona_id, plataforma, token_avisos)
  values (pruebas.id_persona('ana@ejemplo.test'), 'android', 'tok-carla')$$, 'Un token no se duplica entre personas', '23505');
select pruebas.como_anon();
select pruebas.falla($$select public.registrar_dispositivo('tok-anon', 'android')$$, 'Sin sesión no se registra', '42501');

-- ---------------------------------------------------------------- fin_emitir_aviso
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_100', 'partida',
  'e4000000-0000-4000-8000-000000000001', 'partida_100:p1:2026-w43'), 1, 'Ana emite partida_100 en su libro: 1 destinatario');
select pruebas.igual(public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_100', 'partida',
  'e4000000-0000-4000-8000-000000000001', 'partida_100:p1:2026-w43'), 0, 'La misma clave no se inserta dos veces');
select pruebas.igual((select severidad || '/' || estado from public.avisos where clave = 'partida_100:p1:2026-w43'),
  'importante/pendiente', 'Severidad fija del catálogo');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'pago_proximo', null, null, 'k1')$$,
  'Un tipo que no es emitible por la app se rechaza', '22023');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'base_90', null, null, 'k2')$$,
  'Tampoco los del sistema', '22023');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'fondo_bajo', null, null, 'Con Texto $5')$$,
  'La clave no es texto libre', '22023');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'fondo_bajo', 'deuda', null, 'k3')$$,
  'Objeto con tipo e id', '22023');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'fondo_bajo', null, null, 'k4')$$,
  'La pareja no emite en el libro personal de Ana', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'fondo_bajo', null, null, 'k5')$$,
  'La maestra (solo lectura) no emite', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'fondo_bajo', null, null, 'k6')$$,
  'Una familiar tampoco', '42501');

-- Destinatarios: compartido = todos los miembros; partida_80 = quien registró; papá = el albacea.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'flujo_negativo', 'semana',
  'e6000000-0000-4000-8000-000000000002', 'flujo_negativo:c1:2026-w43'), 2, 'Compartido: avisa a sus 2 miembros');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'partida_80', 'partida',
  'e4000000-0000-4000-8000-000000000001', 'partida_80:c1:2026-w43'), 1, 'partida_80: solo a quien registró');
select pruebas.igual((select persona_id from public.avisos where clave = 'partida_80:c1:2026-w43'),
  pruebas.id_persona('alex@ejemplo.test'), '… que es Alex');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'fondo_bajo', 'libro',
  'f1000000-0000-4000-8000-000000000002', 'fondo_bajo:papa:2026-w43'), 1, 'Libro de papá: solo el albacea (Ana)');
select pruebas.como_postgres();
select pruebas.igual(
  (select count(*)::int from public.avisos where clave = 'fondo_bajo:papa:2026-w43' and persona_id = pruebas.id_persona('alex@ejemplo.test')),
  0, 'El suplente no, mientras haya albacea vigente');
update public.fin_libro_miembros set hasta = now() where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'fondo_bajo', 'libro',
  'f1000000-0000-4000-8000-000000000002', 'fondo_bajo:papa:2026-w44'), 1, 'Sin albacea vigente avisa al suplente');
select pruebas.como_postgres();
select pruebas.ok(not exists (
  select 1 from public.avisos a where a.persona_id in (pruebas.id_persona('marta@ejemplo.test'), pruebas.id_persona('carla@ejemplo.test'),
    pruebas.id_persona('diana@ejemplo.test'), pruebas.id_persona('casa@ejemplo.test'))),
  'Nunca la maestra, ni familiar, cuidador o Casa reciben avisos de dinero');

-- Tope de 60 emisiones al día por persona.
select pruebas.como_postgres();
select count(public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas',
  'partida_80', pruebas.libro_personal('ana@ejemplo.test'), null, null, 'relleno:' || g, now(), pruebas.id_persona('ana@ejemplo.test')))
  from generate_series(1, 60) g;
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_80', null, null, 'una-mas')$$,
  'Más de 60 emisiones al día se rechaza', '22023');

rollback;
