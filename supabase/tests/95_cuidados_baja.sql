-- Cuidados (Fase 5): dar de baja a un cuidador corta su acceso al instante (spec 5 §5, criterio 5); lo que registró queda con su
-- nombre en la bitácora. Hogar Ejemplo: Diana (cuidadora) y Carla (hermana).
begin;

-- Antes de la baja: Diana trabaja, tiene un aviso pendiente y escribe cosas.
select pruebas.como('ana@ejemplo.test');
select public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 1);
select set_config('cui.toma', (select id::text from public.cui_tomas where programada_para = '2026-11-09 14:00-06'), true);
select pruebas.igual(pruebas.afecta($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  select 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'),
         extract(isodow from now() at time zone 'America/Mexico_City')::int, 0, 1440, 'cuidadora'$$), 1,
  'Preparación: Diana está de turno hoy');
select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'Cambio previo a la baja (ejemplo)', 'a5400000-0000-4000-8000-0000000000b1');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where objeto_tipo = 'cambio_urgente' and estado = 'pendiente'$$), 1, 'Diana tiene su aviso pendiente');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'$$), 1,
  'Marca una toma');
select pruebas.igual(pruebas.afecta($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-09', 'comida', 'comio')$$), 1, 'Registra una comida');
select pruebas.igual(pruebas.afecta($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'Nota de Diana (ejemplo)')$$), 1,
  'Escribe una nota');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha)
  values ('b0000000-0000-4000-8000-000000000001', 3500, 'Gasto de Diana (ejemplo)', '2026-11-05')$$), 1, 'Registra un gasto');
select pruebas.ok(pruebas.cuenta($$select * from public.cui_medicamentos$$) = 2 and pruebas.cuenta($$select * from public.cui_turnos$$) > 0, 'Ve medicamentos y turnos');
select pruebas.ok(public.cui_perfil('b0000000-0000-4000-8000-000000000001') = 'cuidadora', 'Su perfil es cuidadora');

-- La baja: el dueño la da de baja
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.membresias set activa = false, hasta = now()
  where persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 1, 'El dueño da de baja a la cuidadora');

-- Criterio 5: en la misma transacción, al instante
select pruebas.como('diana@ejemplo.test');
select pruebas.ok(public.cui_perfil('b0000000-0000-4000-8000-000000000001') is null, 'Criterio 5: sin perfil en Cuidados');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$) + pruebas.cuenta($$select * from public.cui_medicamentos$$)
  + pruebas.cuenta($$select * from public.cui_tomas$$) + pruebas.cuenta($$select * from public.cui_comidas$$)
  + pruebas.cuenta($$select * from public.cui_bitacora$$) + pruebas.cuenta($$select * from public.cui_entregas$$)
  + pruebas.cuenta($$select * from public.cui_cambios_urgentes$$) + pruebas.cuenta($$select * from public.cui_gastos$$)
  + pruebas.cuenta($$select * from public.cui_consentimientos$$) + pruebas.cuenta($$select * from public.cui_autorizacion_resumen$$), 0,
  'ya no lee nada de Cuidados, ni lo que ella misma registró');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$, 'no escribe en la bitácora', '42501');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado) values ('b0000000-0000-4000-8000-000000000001', '2026-11-09', 'cena', 'comio')$$,
  'ni comidas', '42501');
select pruebas.falla($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha) values ('b0000000-0000-4000-8000-000000000001', 100, 'x', '2026-11-05')$$,
  'ni gastos', '42501');
select pruebas.falla($$insert into public.cui_entregas (hogar_id, para_persona, nota) values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'x')$$,
  'ni entregas', '42501');
select pruebas.falla($$select public.cui_marcar_toma(current_setting('cui.toma')::uuid, 'dado')$$, 'ni marca tomas', '42501');
select pruebas.falla($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-0000000000b1')$$, 'ni atiende cambios urgentes', '42501');
select pruebas.falla($$select * from public.cui_resumen_papa('b0000000-0000-4000-8000-000000000001')$$, 'ni el resumen de Papá', '42501');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'ni el resumen mensual', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_quien_en_turno('b0000000-0000-4000-8000-000000000001')$$), 0, 'ni sabe quién está de turno');

-- Ya no está de turno: no le llegan recordatorios ni cambios urgentes
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_quien_en_turno('b0000000-0000-4000-8000-000000000001', '2026-11-09 10:00-06') q
  where q.persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 0, 'Dada de baja, Diana ya no figura de turno (un lunes a las 10:00 era suya)');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_quien_en_turno('b0000000-0000-4000-8000-000000000001') q
  where q.persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 0, '… ni ahora, aunque tenía turno de todo el día');
select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'Cambio posterior a la baja (ejemplo)', 'a5400000-0000-4000-8000-0000000000b2');
select pruebas.como_postgres();
select pruebas.igual((select estado from public.avisos where objeto_id = 'a5400000-0000-4000-8000-0000000000b1' and persona_id = pruebas.id_persona('diana@ejemplo.test')),
  'cancelada', 'Su aviso pendiente se canceló con la baja');
select pruebas.igual((select count(*)::int from public.avisos where objeto_id = 'a5400000-0000-4000-8000-0000000000b2' and persona_id = pruebas.id_persona('diana@ejemplo.test')), 0,
  'Un cambio urgente nuevo ya no le avisa');
select pruebas.ok((select para_persona is distinct from pruebas.id_persona('diana@ejemplo.test') from public.cui_cambios_urgentes where id = 'a5400000-0000-4000-8000-0000000000b2'),
  'ni va dirigido a ella');

-- Lo que registró queda con su nombre
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora where persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 1, 'Su nota sigue en la bitácora de cuidados, a su nombre');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos where persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 1, 'su gasto, a su nombre');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_comidas where registrada_por = pruebas.id_persona('diana@ejemplo.test')$$), 1, 'su comida, a su nombre');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_tomas where marcada_por = pruebas.id_persona('diana@ejemplo.test')$$), 1, 'y su marca de la toma');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'cuidados.toma_marcada' and persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 1,
  'con su entrada en la bitácora de auditoría');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'membresias' and accion = 'actualizar'
                            and detalle -> 'despues' ->> 'activa' = 'false'), 'y la baja también queda registrada');

-- La hermana: baja con solo activa = false (sin fecha)
select pruebas.como('ana@ejemplo.test');
select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true);
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.cui_medicamentos$$) = 2, 'Antes de la baja, la hermana lee los medicamentos');
select pruebas.ok((select count(*) from public.cui_resumen_mensual('2026-11-01')) = 1, '… y el resumen mensual autorizado');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.membresias set activa = false where persona_id = pruebas.id_persona('carla@ejemplo.test')$$), 1,
  'El dueño da de baja a la hermana');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$) + pruebas.cuenta($$select * from public.cui_turnos$$)
  + pruebas.cuenta($$select * from public.cui_bitacora$$) + pruebas.cuenta($$select * from public.cui_autorizacion_resumen$$), 0,
  'La hermana pierde de inmediato el acceso a Cuidados');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$,
  'y el resumen mensual, aunque su autorización siguiera vigente en la tabla', '42501');

-- Un cuidador sin turnos asignados nunca tuvo acceso
select pruebas.como_postgres();
select pruebas.nuevo_adulto('tercera@ejemplo.test', 'Tercera Cuidadora', 'cuidador');
select pruebas.como('tercera@ejemplo.test');
select pruebas.ok(public.cui_perfil('b0000000-0000-4000-8000-000000000001') is null, 'Una cuidadora nueva, sin turnos, no tiene perfil');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$) + pruebas.cuenta($$select * from public.cui_turnos$$), 0, 'y no ve nada hasta que el dueño le asigne turnos');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('tercera@ejemplo.test'), 4, 480, 1020, 'cuidadora')$$), 1, 'El dueño le asigna un turno');
select pruebas.como('tercera@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 2, 'Con turno, ve los medicamentos');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$delete from public.cui_turnos where persona_id = pruebas.id_persona('tercera@ejemplo.test')$$), 1, 'El dueño le quita el turno');
select pruebas.como('tercera@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 0, 'y pierde el acceso al instante');

rollback;
