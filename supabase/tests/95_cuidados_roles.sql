-- Cuidados (Fase 5): reglas por rol (spec 5 §5), criterios 2 y 6 (D3). Hogar Ejemplo: Ana dueña y albacea, Alex pareja,
-- Marta cuenta maestra (coadministrador), Carla hermana (familiar con turnos de hermana_visita), Diana cuidadora,
-- Casa. Los turnos y los dos medicamentos de ejemplo vienen del seed.
begin;

-- ---------------------------------------------------------------- la dueña
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$), 11, 'La dueña ve los 11 turnos del seed');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 2, '… y los medicamentos');
select pruebas.igual(public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 1), 3,
  'Genera las 3 tomas del lunes 9/nov (08:00 y 20:00 de A, 14:00 de B)');
select pruebas.igual(public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 1), 0, 'Generar de nuevo no duplica');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_tomas where estado = 'pendiente'$$), 3, 'Las tomas nacen pendientes');
select pruebas.ok((select programada_para = '2026-11-09 14:00:00-06'::timestamptz from public.cui_tomas t
                    join public.cui_medicamentos m on m.id = t.medicamento_id where m.nombre like 'Medicamento B%'),
  'Las horas se leen en la zona del hogar (14:00 de Ciudad de México)');
select pruebas.falla($$select public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 30)$$,
  'Genera de 1 a 14 días', '22023');
select pruebas.falla($$update public.cui_tomas set estado = 'dado'$$, 'Nadie cambia una toma directo (solo cui_marcar_toma)', '42501');
select pruebas.falla($$insert into public.cui_tomas (hogar_id, medicamento_id, programada_para)
  values ('b0000000-0000-4000-8000-000000000001', 'a5200000-0000-4000-8000-000000000001', now())$$,
  'ni las inserta directo', '42501');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 1, 600, 700, 'dueno')$$,
  'El turno "dueno" es solo del dueño', '22023');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 1, 600, 700, 'cuidadora')$$,
  'La pareja no es cuidadora', '22023');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 1, 700, 600, 'cuidadora')$$,
  'El turno termina después de empezar', '23514');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 8, 600, 700, 'cuidadora')$$,
  'Día de la semana de 1 a 7', '23514');
select pruebas.falla($$insert into public.cui_medicamentos (hogar_id, nombre, horas)
  values ('b0000000-0000-4000-8000-000000000001', 'X', '{25:00}')$$, 'Las horas son HH:MM válidas', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.cui_medicamentos (id, hogar_id, nombre, dosis, horas)
  values ('a5200000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001', 'Medicamento C (ejemplo)', '1', '{09:30}')$$), 1,
  'La dueña agrega un medicamento');
select pruebas.igual(pruebas.afecta($$update public.cui_medicamentos set activo = false where id = 'a5200000-0000-4000-8000-0000000000f1'$$), 1,
  '… y lo desactiva (no se borra)');
select pruebas.falla($$delete from public.cui_medicamentos$$, 'Los medicamentos no se borran', '42501');
-- Solo agregar
select pruebas.igual(pruebas.afecta($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-08', 'comida', 'comio_poco')$$), 1, 'La dueña registra la comida del domingo');
select pruebas.ok((select registrada_por = pruebas.id_persona('ana@ejemplo.test') from public.cui_comidas), 'Quién la registró lo pone el servidor');
select pruebas.falla($$update public.cui_comidas set resultado = 'comio'$$, 'Las comidas no se editan (corrección con fila nueva)', '42501');
select pruebas.falla($$delete from public.cui_comidas$$, 'ni se borran', '42501');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado, registrada_por)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-08', 'cena', 'comio', pruebas.id_persona('diana@ejemplo.test'))$$,
  'La app no manda registrada_por', '42501');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-08', 'merienda', 'comio')$$, 'Cuatro tiempos de comida', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-08', 'comida', 'comio')$$), 1, 'La corrección es una fila nueva');
select pruebas.igual(pruebas.afecta($$insert into public.cui_bitacora (hogar_id, nota)
  values ('b0000000-0000-4000-8000-000000000001', 'Papá durmió bien (ejemplo)')$$), 1, 'La dueña escribe en la bitácora de cuidados');
select pruebas.falla($$update public.cui_bitacora set nota = 'otra'$$, 'La bitácora de cuidados es solo agregar', '42501');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', repeat('x', 501))$$,
  'Una nota de 500 caracteres como máximo', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.cui_entregas (hogar_id, para_persona, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 'Entrega del domingo (ejemplo)')$$), 1,
  'La dueña deja una entrega de turno a Diana');
select pruebas.falla($$insert into public.cui_entregas (hogar_id, para_persona, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('casa@ejemplo.test'), 'x')$$,
  'Una entrega solo va a quien cuida', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha)
  values ('a5300000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 25000, 'Pañales (ejemplo)', '2026-11-05')$$), 1,
  'La dueña registra un gasto de cuidado');
select pruebas.ok((select estado = 'pendiente_confirmacion' and confirmado_en is null from public.cui_gastos), 'Nace pendiente de confirmación');
select pruebas.falla($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, estado)
  values ('b0000000-0000-4000-8000-000000000001', 100, 'x', '2026-11-05', 'confirmado')$$, 'Nadie fija el estado al registrar', '42501');
select pruebas.falla($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha)
  values ('b0000000-0000-4000-8000-000000000001', 0, 'x', '2026-11-05')$$, 'El monto es mayor que cero', '23514');
select pruebas.falla($$update public.cui_gastos set monto_centavos = 1$$, 'Un gasto no se edita', '42501');
select pruebas.falla($$delete from public.cui_gastos$$, 'ni se borra', '42501');
select pruebas.falla($$update public.cui_cambios_urgentes set texto = 'x'$$, 'Un cambio urgente no se edita', '42501');
select pruebas.falla($$insert into public.cui_cambios_urgentes (hogar_id, de_persona, texto)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'x')$$,
  'Solo se crea con cui_crear_cambio_urgente', '42501');
select pruebas.falla($$insert into public.cui_consentimientos (hogar_id, persona_id, concedido)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true)$$,
  'Los consentimientos solo cambian por RPC', '42501');
select pruebas.falla($$insert into public.cui_autorizacion_resumen (hogar_id, persona_id, vigente)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true)$$,
  'La autorización del resumen tampoco', '42501');

-- ---------------------------------------------------------------- la pareja (sin consentimiento)
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$), 11, 'La pareja ve los turnos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$) + pruebas.cuenta($$select * from public.cui_tomas$$)
  + pruebas.cuenta($$select * from public.cui_comidas$$), 0, 'Sin consentimiento no ve medicamentos, tomas ni comidas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$) + pruebas.cuenta($$select * from public.cui_entregas$$)
  + pruebas.cuenta($$select * from public.cui_cambios_urgentes$$), 0, 'ni la bitácora clínica, ni entregas ni cambios');
select pruebas.igual((select tomas_total from public.cui_resumen_papa('b0000000-0000-4000-8000-000000000001', '2026-11-09')), 3,
  'Pero sí el resumen de Papá del día (conteos, sin nombres)');
select pruebas.igual((select comidas_registradas from public.cui_resumen_papa('b0000000-0000-4000-8000-000000000001', '2026-11-08')), 1,
  'incluidas las comidas del domingo (cuenta el tiempo de comida, no cada corrección)');
select pruebas.igual((select tomas_pendientes from public.cui_resumen_papa('b0000000-0000-4000-8000-000000000001', '2026-11-09')), 3, 'Tomas pendientes');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 0, 'No ve el gasto de otro');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 1, 1200, 1300, 'cuidadora')$$, 'No cambia turnos', '42501');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$, 'No escribe en la bitácora', '42501');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado) values ('b0000000-0000-4000-8000-000000000001', '2026-11-09', 'comida', 'comio')$$,
  'No registra comidas', '42501');
select pruebas.falla($$insert into public.cui_medicamentos (hogar_id, nombre, horas) values ('b0000000-0000-4000-8000-000000000001', 'X', '{08:00}')$$,
  'No cambia medicamentos', '42501');
select pruebas.igual(pruebas.afecta($$update public.cui_medicamentos set activo = false$$), 0, '… ni los modifica');
select pruebas.falla($$select public.cui_marcar_toma((select id from public.cui_tomas limit 1), 'dado')$$, 'No marca tomas', '42501');
select pruebas.falla($$select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'x')$$, 'No manda cambios urgentes', '42501');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'No ve el resumen mensual', '42501');
select pruebas.falla($$select public.cui_confirmar_gasto('a5300000-0000-4000-8000-000000000001', true)$$, 'No confirma gastos', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha)
  values ('a5300000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 9900, 'Guantes (pareja)', '2026-11-06')$$), 1,
  'Registra sus propios gastos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 1, '… y solo ve los suyos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_consentimientos$$), 0, 'Aún no hay consentimientos');
select pruebas.falla($$select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true)$$,
  'No da el consentimiento de otra persona', '42501');
select pruebas.falla($$select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', true)$$,
  'ni el de Papá (lo firma el albacea; Alex solo es suplente)', '42501');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), true)$$,
  'Alex no es el albacea: no autoriza el resumen', '42501');

-- Con su consentimiento explícito
select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true);
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 3, 'Con consentimiento ve los medicamentos (solo lectura)');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_tomas$$), 3, '… las tomas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_comidas$$), 2, '… y las comidas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 1, 'Con consentimiento lee la bitácora de cuidados (v1.2)');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_entregas$$), 0, 'Pero las entregas de turno siguen cerradas');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$,
  'y la bitácora es solo lectura para ella', '42501');
select pruebas.igual(pruebas.afecta($$update public.cui_medicamentos set activo = false$$), 0, 'Sigue sin poder cambiar nada');
select pruebas.falla($$select public.cui_marcar_toma((select id from public.cui_tomas limit 1), 'dado')$$, 'ni marcar tomas', '42501');
select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), false);
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$) + pruebas.cuenta($$select * from public.cui_bitacora$$), 0,
  'Al retirar el consentimiento se cierra de inmediato (también la bitácora)');

-- ---------------------------------------------------------------- la cuenta maestra (otra coadministradora)
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$), 11, 'La maestra ve los turnos como pareja');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$) + pruebas.cuenta($$select * from public.cui_bitacora$$)
  + pruebas.cuenta($$select * from public.cui_gastos$$), 0, 'pero lo clínico y el dinero de cuidados, nada');

-- ---------------------------------------------------------------- la hermana
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$), 11, 'La hermana ve los turnos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 3, '… medicamentos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_tomas$$), 3, '… tomas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_comidas$$), 2, '… y comidas, solo lectura');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 1, 'Lee la bitácora de cuidados');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_entregas$$), 0, 'La entrega de la dueña a Diana no es para ella');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado) values ('b0000000-0000-4000-8000-000000000001', '2026-11-09', 'comida', 'comio')$$,
  'No registra comidas (solo lectura)', '42501');
select pruebas.falla($$select public.cui_marcar_toma((select id from public.cui_tomas limit 1), 'dado')$$, 'No marca tomas (solo lectura)', '42501');
select pruebas.falla($$insert into public.cui_medicamentos (hogar_id, nombre, horas) values ('b0000000-0000-4000-8000-000000000001', 'X', '{08:00}')$$,
  'No cambia medicamentos', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_bitacora (hogar_id, nota)
  values ('b0000000-0000-4000-8000-000000000001', 'Visita del martes (ejemplo)')$$), 1, 'Escribe en la bitácora');
select pruebas.ok((select persona_id = pruebas.id_persona('carla@ejemplo.test') from public.cui_bitacora where nota like 'Visita%'),
  'quién la escribió lo pone el servidor');
select pruebas.igual(pruebas.afecta($$insert into public.cui_entregas (hogar_id, para_persona, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 'Nota de la hermana (ejemplo)')$$), 1, 'Deja entrega de turno');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_entregas$$), 1, '… y ve la que ella escribió');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (hogar_id, monto_centavos, concepto, fecha, ambito)
  values ('b0000000-0000-4000-8000-000000000001', 18000, 'Despensa (hermana)', '2026-11-04', 'casa')$$), 1, 'Registra sus gastos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 1, '… y solo ve los suyos');
select pruebas.falla($$select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'x')$$, 'No manda cambios urgentes', '42501');
select pruebas.falla($$select public.cui_confirmar_gasto((select id from public.cui_gastos limit 1), true)$$, 'No confirma su propio gasto', '42501');
select pruebas.falla($$select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true)$$,
  'No cambia el consentimiento de otro', '42501');

-- ---------------------------------------------------------------- la cuidadora (criterio 2)
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$), 11, 'La cuidadora ve los turnos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_medicamentos$$), 3, '… los medicamentos');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_tomas$$), 3, '… las tomas');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 2, '… y la bitácora de cuidados: la del dueño y la de la hermana (v1.1)');
select pruebas.ok(exists (select 1 from public.cui_bitacora where persona_id = pruebas.id_persona('carla@ejemplo.test')), 'Ve la entrada de la hermana');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_entregas$$), 2, 'Las entregas que le dejaron (dueña y hermana)');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_consentimientos$$), 0, 'No ve consentimientos');
select pruebas.falla($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 7, 0, 600, 'cuidadora')$$, 'No se asigna turnos', '42501');
select pruebas.falla($$insert into public.cui_medicamentos (hogar_id, nombre, horas) values ('b0000000-0000-4000-8000-000000000001', 'X', '{08:00}')$$,
  'No cambia medicamentos', '42501');
select pruebas.falla($$select public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-10', 1)$$, 'No genera tomas', '42501');
select pruebas.falla($$select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'x')$$, 'No manda cambios urgentes', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-09', 'comida', 'rechazo')$$), 1, 'Registra la comida de un lunes (día de su turno)');
select pruebas.falla($$insert into public.cui_comidas (hogar_id, fecha, tiempo, resultado)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-08', 'cena', 'comio')$$, 'No en domingo (cuida el dueño)', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'Tomó agua (ejemplo)')$$), 1,
  'Escribe en la bitácora');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 3, 'Ve lo suyo, lo del dueño y lo de la hermana');
-- v1.1: la entrada de cualquier otra persona (aquí la pareja, escrita directo por el servidor) no la ve la cuidadora
select pruebas.como_postgres();
insert into public.cui_bitacora (hogar_id, persona_id, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'Nota de otra persona (ejemplo)');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora where nota like 'Nota de otra%'$$), 0, 'No ve la entrada de otra persona');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 3, '… y sigue viendo solo esas tres');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 4, 'La hermana sigue leyendo toda la bitácora de cuidados');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$insert into public.cui_entregas (hogar_id, para_persona, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'x')$$, 'No deja entregas a la pareja', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.cui_gastos (id, hogar_id, monto_centavos, concepto, fecha)
  values ('a5300000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 12000, 'Cremas (cuidadora)', '2026-11-03')$$), 1, 'Registra su gasto');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_gastos$$), 1, '… y solo ve el suyo');
select pruebas.falla($$select public.cui_confirmar_gasto('a5300000-0000-4000-8000-000000000003', true)$$, 'No confirma gastos', '42501');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'No ve el resumen mensual', '42501');
select pruebas.falla($$select public.cui_autorizar_resumen('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), true)$$,
  'No se autoriza a sí misma', '42501');
-- Criterio 2: nada de la familia fuera de Cuidados
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$) + pruebas.cuenta($$select * from public.fin_cuentas$$)
  + pruebas.cuenta($$select * from public.fin_movimientos$$) + pruebas.cuenta($$select * from public.fin_deudas$$), 0, 'No lee Finanzas');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$) + pruebas.cuenta($$select * from public.hab_registros$$), 0, 'ni Hábitos');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where persona_id is distinct from pruebas.id_persona('diana@ejemplo.test')$$), 0,
  'En la bitácora de auditoría solo está lo suyo (no la de la familia)');
select pruebas.igual(pruebas.cuenta($$select * from public.membresias$$), 1, 'No ve a los demás miembros del hogar');
select pruebas.igual(pruebas.cuenta($$select * from public.invitaciones$$) + pruebas.cuenta($$select * from public.fin_vistas_solicitadas$$), 0,
  'ni invitaciones ni solicitudes de la familia');

-- ---------------------------------------------------------------- Casa, otro hogar, sin hogar y anon (criterio 6, D3)
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$) + pruebas.cuenta($$select * from public.cui_medicamentos$$)
  + pruebas.cuenta($$select * from public.cui_tomas$$) + pruebas.cuenta($$select * from public.cui_comidas$$)
  + pruebas.cuenta($$select * from public.cui_bitacora$$) + pruebas.cuenta($$select * from public.cui_entregas$$)
  + pruebas.cuenta($$select * from public.cui_cambios_urgentes$$) + pruebas.cuenta($$select * from public.cui_gastos$$)
  + pruebas.cuenta($$select * from public.cui_consentimientos$$) + pruebas.cuenta($$select * from public.cui_autorizacion_resumen$$), 0,
  'D3: la cuenta Casa (tablet y bocinas) no ve NADA de Cuidados');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$, 'ni escribe', '42501');
select pruebas.falla($$select * from public.cui_resumen_papa('b0000000-0000-4000-8000-000000000001')$$, 'ni el resumen de Papá', '42501');
select pruebas.ok(public.cui_perfil('b0000000-0000-4000-8000-000000000001') is null, 'Casa no tiene perfil en Cuidados');

select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$) + pruebas.cuenta($$select * from public.cui_medicamentos$$)
  + pruebas.cuenta($$select * from public.cui_gastos$$) + pruebas.cuenta($$select * from public.cui_bitacora$$), 0, 'Otro hogar no ve nada');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$, 'ni escribe en este hogar', '42501');
select pruebas.falla($$select public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-10', 1)$$, 'ni genera tomas', '42501');

select pruebas.como('nuevo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_turnos$$) + pruebas.cuenta($$select * from public.cui_gastos$$), 0, 'Sin hogar, nada');

select pruebas.como_anon();
select pruebas.falla($$select * from public.cui_turnos$$, 'anon no lee turnos', '42501');
select pruebas.falla($$select * from public.cui_medicamentos$$, 'ni medicamentos', '42501');
select pruebas.falla($$select * from public.cui_gastos$$, 'ni gastos', '42501');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$, 'ni escribe', '42501');
select pruebas.falla($$select public.cui_perfil('b0000000-0000-4000-8000-000000000001')$$, 'ni ejecuta cui_perfil', '42501');
select pruebas.falla($$select * from public.cui_resumen_mensual('2026-11-01')$$, 'ni el resumen mensual', '42501');
select pruebas.falla($$select public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-10', 1)$$, 'ni genera tomas', '42501');
select pruebas.falla($$select public.cui_marcar_toma(gen_random_uuid(), 'dado')$$, 'ni marca tomas', '42501');
select pruebas.falla($$select * from public.cui_quien_en_turno('b0000000-0000-4000-8000-000000000001')$$, 'ni consulta quién está de turno', '42501');

-- ---------------------------------------------------------------- D3: lo clínico no se copia a otras tablas
select pruebas.como_postgres();
select pruebas.igual(
  (select count(*)::int from public.bitacora b
    where b.hogar_id = 'b0000000-0000-4000-8000-000000000001'
      and (b.detalle::text ilike '%Medicamento%' or b.detalle::text ilike '%tableta%' or b.detalle::text ilike '%cápsula%'
           or b.detalle::text ilike '%Papá durmió%' or b.detalle::text ilike '%Visita del martes%'
           or b.detalle::text ilike '%Pañales (ejemplo)%' or b.detalle::text ilike '%Despensa (hermana)%'
           or b.detalle::text ilike '%Cremas (cuidadora)%')), 0,
  'D3: la bitácora de auditoría no copia nombres de medicamentos, dosis, notas clínicas ni conceptos de gastos');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'cui_medicamentos'), 'Pero sí registra que hubo un cambio en medicamentos');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'cui_gastos' and detalle -> 'despues' ? 'monto_centavos'),
  'y el gasto con su monto, sin concepto (solo lo ven el dueño y quien lo hizo)');
select pruebas.ok(not exists (select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'avisos' and column_name in ('texto', 'nota', 'concepto', 'nombre', 'titulo', 'cuerpo')),
  'D3: los avisos (también los de Cuidados) no llevan texto');

rollback;
