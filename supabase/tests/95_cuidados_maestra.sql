-- Cuidados (Fase 5): la cuenta maestra que no es la dueña (D19, F5-B1) y el gasto de casa de la cuidadora (F5-I1).
-- Marta es la cuenta maestra (coadministradora); Ana, la dueña; Diana, la cuidadora; Carla, la hermana; Alex, la pareja.
begin;

-- Datos clínicos de ejemplo escritos por la dueña
select pruebas.como('ana@ejemplo.test');
select public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 1);
insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado) values ('b0000000-0000-4000-8000-000000000001', '2026-11-08', 'comida', 'comio');
insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'Nota clínica (ejemplo)');
insert into public.cui_citas (hogar_id, programada_en, lugar, nota)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-20 10:00-06', 'Clínica (ejemplo)', 'Cita (ejemplo)');
select pruebas.como_postgres();
-- Peor caso: una fila de consentimiento concedido para la maestra (por ejemplo, de antes de esta corrección)
insert into public.cui_consentimientos (hogar_id, persona_id, concedido, cambiado_por)
values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), true, pruebas.id_persona('marta@ejemplo.test'))
on conflict (hogar_id, persona_id) do update set concedido = true;

-- ---------------------------------------------------------------- la maestra, aun con la fila concedida
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(public.cui_perfil('b0000000-0000-4000-8000-000000000001'), 'pareja', 'Nunca es pareja_consentida');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$), 11, 'Ve los turnos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 0, 'No lee medicamentos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_tomas$$), 0, 'No lee tomas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_comidas$$), 0, 'No lee comidas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 0, 'No lee la bitácora');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 0, 'No lee citas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 0, 'No lee gastos');
select pruebas.ok(not public.cui_puede('b0000000-0000-4000-8000-000000000001', 'medicamentos', 'leer'), 'cui_puede: medicamentos leer = falso');
select pruebas.ok(public.cui_puede('b0000000-0000-4000-8000-000000000001', 'turnos', 'leer'), 'cui_puede: turnos leer = verdadero');

-- No concede consentimiento, ni a sí misma ni a nadie
select pruebas.falla($$select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), true)$$,
  'No se da consentimiento a sí misma', '42501');
select pruebas.falla($$select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), false)$$,
  'ni lo retira', '42501');
select pruebas.falla($$select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true)$$,
  'ni lo da por otra persona', '42501');

-- No escribe nada
select pruebas.ok(not public.cui_puede('b0000000-0000-4000-8000-000000000001', 'gastos', 'escribir'), 'cui_puede: gastos escribir = falso');
select pruebas.falla($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha)
  values ('b0000000-0000-4000-8000-000000000001', 1000, 'x', '2026-11-08')$$, 'No registra gastos de cuidado', '42501');
select pruebas.falla($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, ambito)
  values ('b0000000-0000-4000-8000-000000000001', 1000, 'x', '2026-11-08', 'casa')$$, 'ni de la casa', '42501');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$, 'No escribe bitácora', '42501');
select pruebas.falla($$insert into public.cui_citas (hogar_id, programada_en, lugar, nota)
  values ('b0000000-0000-4000-8000-000000000001', now(), 'x', 'x')$$, 'ni citas', '42501');
select pruebas.falla($$insert into public.cui_entregas (hogar_id, para_persona, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 'x')$$, 'ni entregas', '42501');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-09', 'cena', 'comio')$$, 'ni comidas', '42501');
select pruebas.falla($$insert into public.cui_medicamentos (hogar_id, nombre, horas) values ('b0000000-0000-4000-8000-000000000001', 'X', '{08:00}')$$,
  'ni medicamentos', '42501');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 2, 600, 700, 'cuidadora')$$, 'ni turnos', '42501');
select pruebas.falla($$select public.cui_marcar_toma((select id from public.cui_tomas limit 1), 'dado')$$, 'ni marca tomas', '42501');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'x')$$, 'ni deja instrucciones', '42501');
select pruebas.falla($$select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'x')$$, 'ni cambios urgentes', '42501');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$, 'ni horarios de comida', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_comida$$), 0, 'ni los lee');

-- La fila concedida de la maestra se retira (migración) y el perfil la ignora
select pruebas.como_postgres();
update public.cui_consentimientos set concedido = false where persona_id = pruebas.id_persona('marta@ejemplo.test');

-- ---------------------------------------------------------------- la pareja sigue como antes
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.cui_perfil('b0000000-0000-4000-8000-000000000001'), 'pareja', 'La pareja sin consentimiento sigue siendo pareja');
select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true);
select pruebas.igual(public.cui_perfil('b0000000-0000-4000-8000-000000000001'), 'pareja_consentida', 'La pareja sí da su consentimiento');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 2, '… y lee medicamentos');

-- ---------------------------------------------------------------- la dueña que además es maestra conserva su rol
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.igual(public.cui_perfil('b0000000-0000-4000-8000-000000000001'), 'dueno', 'La dueña-maestra sigue siendo dueña en Cuidados');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 2, '… lee medicamentos');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha)
  values ('b0000000-0000-4000-8000-000000000001', 5000, 'Gasto de la dueña (ejemplo)', '2026-11-08')$$), 1, '… y registra gastos');
select pruebas.ok(not public.cui_es_maestra_ajena('b0000000-0000-4000-8000-000000000001'), 'No es maestra ajena');

-- ---------------------------------------------------------------- F5-I1: gasto de casa
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, ambito)
  values ('b0000000-0000-4000-8000-000000000001', 9000, 'Despensa (cuidadora)', '2026-11-08', 'casa')$$,
  'La cuidadora no registra gastos de la casa', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, ambito)
  values ('b0000000-0000-4000-8000-000000000001', 9000, 'Pañales (cuidadora)', '2026-11-08', 'cuidado')$$), 1,
  'pero sí los de cuidado');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, ambito)
  values ('b0000000-0000-4000-8000-000000000001', 9000, 'Despensa (hermana)', '2026-11-08', 'casa')$$), 1, 'La hermana sí registra gastos de la casa');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, ambito)
  values ('b0000000-0000-4000-8000-000000000001', 9000, 'Despensa (pareja)', '2026-11-08', 'casa')$$), 1, 'La pareja también');

-- ---------------------------------------------------------------- F5-I5: programar el cron de tomas
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.cui_programar_cron_tomas()$$, 'La cuidadora no programa el cron', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.cui_programar_cron_tomas() is not null, 'La dueña lo invoca (false sin pg_cron, true con pg_cron)');
select pruebas.como_anon();
select pruebas.falla($$select public.cui_programar_cron_tomas()$$, 'anon no puede', '42501');

rollback;
