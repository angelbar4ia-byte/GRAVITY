-- Endurecimiento de la Fase 2 (docs/revisiones/fase-2.md): F2-1, F2-3, F2-4 y F2-5.
begin;
select pruebas.nuevo_adulto('teo@ejemplo.test');
select pruebas.como_postgres();

-- ---------------------------------------------------------------- F2-1
delete from public.avisos where persona_id = pruebas.id_persona('ana@ejemplo.test');
select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'finanzas', 'fondo_bajo',
  pruebas.libro_personal('ana@ejemplo.test'), null, null, 'k1', now());
select public.avisos_registrar_entrega((select id from public.avisos where clave = 'k1'), d.id, 'error', 'red')
  from public.dispositivos d, generate_series(1, 6) where d.tipo = 'telefono' and d.persona_id = pruebas.id_persona('ana@ejemplo.test');
select pruebas.ok((select recibe_avisos and fallos = 0 from public.dispositivos where tipo = 'telefono' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'F2-1: los errores transitorios (5xx, cuota, red) no suman fallos ni apagan el push');
select public.avisos_registrar_entrega((select id from public.avisos where clave = 'k1'), d.id, 'rechazado', '403')
  from public.dispositivos d, generate_series(1, 5) where d.tipo = 'telefono' and d.persona_id = pruebas.id_persona('ana@ejemplo.test');
select pruebas.ok((select not recibe_avisos and fallos = 5 from public.dispositivos where tipo = 'telefono' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'Cinco rechazos definitivos sí lo apagan');
select pruebas.como('ana@ejemplo.test');
select public.registrar_dispositivo('token-fcm-de-ejemplo-ana', 'android', 'Teléfono de Ana (ejemplo)', 'telefono');
select pruebas.ok((select recibe_avisos and fallos = 0 from public.dispositivos where token_avisos = 'token-fcm-de-ejemplo-ana'),
  'Al volver a abrir la app, el teléfono se reactiva y reinicia sus fallos');
select public.registrar_dispositivo('tok-tp', 'android', 'Tablet', 'tablet_personal');
select pruebas.igual(pruebas.afecta($$update public.dispositivos set recibe_avisos = false where token_avisos = 'tok-tp'$$), 1, 'Ana apaga su tablet personal');
select public.registrar_dispositivo('tok-tp', 'android', 'Tablet', 'tablet_personal');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-tp'), 'La tablet personal conserva su elección');
select public.registrar_dispositivo('tok-pub', 'android', 'Tablet', 'tablet_publica');
select public.registrar_dispositivo('tok-pub', 'android', 'Tablet', 'tablet_publica');
select pruebas.ok(not (select recibe_avisos from public.dispositivos where token_avisos = 'tok-pub'), 'La tablet pública nunca se reactiva');
select pruebas.como_postgres();
select public.avisos_registrar_entrega((select id from public.avisos where clave = 'k1'), (select id from public.dispositivos where token_avisos = 'tok-pub'), 'token_invalido', 'UNREGISTERED');
select pruebas.igual(pruebas.cuenta($$select * from public.dispositivos where token_avisos = 'tok-pub'$$), 0, 'El token inválido (UNREGISTERED) sigue borrándose');

-- ---------------------------------------------------------------- F2-5
select pruebas.ok((select pg_get_constraintdef(oid) like '%(libro_id, bolsa_destino_id)%' from pg_constraint
  where conrelid = 'public.fin_retiros_ahorro'::regclass and conname = 'fin_retiros_destino_fk'), 'F2-5: la FK del destino es compuesta con libro_id');
select pruebas.ok(not exists (select 1 from pg_constraint c where c.contype = 'f'
  and c.conrelid in ('public.fin_msi'::regclass, 'public.fin_estados_cuenta'::regclass, 'public.fin_bolsas_ahorro'::regclass,
                     'public.fin_aportaciones_ahorro'::regclass, 'public.fin_retiros_ahorro'::regclass)
  and c.confrelid in ('public.fin_deudas'::regclass, 'public.fin_bolsas_ahorro'::regclass, 'public.fin_cuentas'::regclass,
                      'public.fin_semanas'::regclass, 'public.fin_libros'::regclass)
  and cardinality(c.conkey) = 1),
  'Ninguna otra llave de la Fase 2 hacia tablas de libro es de una sola columna');
select pruebas.como('ana@ejemplo.test');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9400000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Ahorro de la casa', 'ahorro');
insert into public.fin_bolsas_ahorro (id, hogar_id, libro_id, nombre, tipo, cuenta_id)
values ('ea000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Vacaciones', 'meta_libre', 'c9400000-0000-4000-8000-000000000001');
select pruebas.ok(pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000010', 'c3000000-0000-4000-8000-000000000001', 5000,
  p_id => 'd1000000-0000-4000-8000-0000000000b1') is not null, 'Ana retira de su fondo');
select pruebas.falla($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, bolsa_destino_id, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000b1', 'cambio_destino', 'Cambio de plan', 'ea000000-0000-4000-8000-0000000000f1', now())$$,
  'Un retiro no nombra una bolsa de otro libro', '23503');
select pruebas.falla($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, bolsa_destino_id, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000b1', 'cambio_destino', 'Cambio de plan', 'ea000000-0000-4000-8000-000000000001', now())$$,
  'ni la misma bolsa', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, bolsa_destino_id, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000b1', 'cambio_destino', 'Cambio de plan', 'ea000000-0000-4000-8000-000000000002', now())$$), 1,
  'Pasar a otra bolsa del mismo libro sí');

-- ---------------------------------------------------------------- F2-3
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'flujo_negativo', 'semana',
  'e6000000-0000-4000-8000-000000000002', 'x1')$$, 'La semana (de un libro personal) no es del compartido', '22023');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_100', 'deuda',
  gen_random_uuid(), 'x2')$$, 'Un objeto inexistente se rechaza', '22023');
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_100', 'libro',
  'f1000000-0000-4000-8000-000000000001', 'x3')$$, 'Un libro que no es el del aviso', '22023');
select pruebas.igual(public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_100', 'semana',
  'e6000000-0000-4000-8000-000000000002', 'x4'), 1, 'Su propio objeto sí (semana del libro)');
select pruebas.igual(public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'), 'partida_100', 'movimiento',
  'd1000000-0000-4000-8000-0000000000b1', 'x5'), 1, 'Un movimiento que toca el libro sí');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000002', 'fondo_bajo', 'movimiento',
  'd1000000-0000-4000-8000-0000000000b1', 'x6')$$, 'Un movimiento que no toca el libro, no', '22023');
-- Críticas: 5 por día y libro.
select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'flujo_negativo', null, null, 'crit:' || g) from generate_series(1, 5) g;
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'abono_bajo_minimo', null, null, 'crit:6')$$,
  'La 6.ª crítica del día en el libro se rechaza', '22023');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'flujo_negativo', null, null, 'crit:3'), 0,
  'Repetir una clave ya emitida no cuenta ni falla');
select pruebas.igual(public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'fondo_bajo', null, null, 'otra:1'), 2,
  'Los demás tipos siguen (tope de 60)');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'flujo_negativo', null, null, 'crit:alex')$$,
  'El tope de críticas es del libro, también para el otro miembro', '22023');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'fondo_bajo', null, null, 'm1')$$,
  'La maestra no emite', '42501');
select pruebas.como('teo@ejemplo.test');
select pruebas.falla($$select public.fin_emitir_aviso('f1000000-0000-4000-8000-000000000001', 'fondo_bajo', null, null, 'm2')$$,
  'Quien no es miembro del compartido no emite', '42501');

-- ---------------------------------------------------------------- F2-4
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_silencio_desde => '22:00', p_silencio_hasta => '22:00')$$,
  'F2-4: horas silenciosas con inicio = fin se rechazan', '22023');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_silencio_hasta => '22:00')$$,
  'también si una de las dos coincide con la guardada', '22023');
select public.avisos_actualizar_preferencias(p_silencio_desde => '23:00', p_silencio_hasta => '06:00');
select pruebas.ok((select silencio_desde::text = '23:00:00' from public.avisos_preferencias), 'Un rango distinto sí');
rollback;
