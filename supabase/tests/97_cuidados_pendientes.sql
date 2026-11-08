-- Cuidados: pendientes (migración 20261121): cron de tomas, posponer toma, quién atendió el cambio urgente y citas.
-- Hogar Ejemplo (zona America/Mexico_City, UTC-6). Semana de prueba: lunes 9/nov/2026. Ana dueña, Alex pareja,
-- Marta cuenta maestra, Carla hermana, Diana cuidadora, Casa.
begin;

-- Id de la toma de esa hora (sin pasar por la RLS de quien consulta: la pareja y Casa no leen tomas)
create function pg_temp.toma(p_ts text) returns uuid
language sql security definer
as $$ select id from public.cui_tomas where programada_para = p_ts::timestamptz $$;
grant execute on function pg_temp.toma(text) to authenticated, service_role;

-- ---------------------------------------------------------------- 1. generación diaria de tomas (cron)
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.cui_generar_tomas_todas()$$, 'Ni el dueño genera las tomas de todos los hogares (solo el servidor)', '42501');
select pruebas.como_servicio();
select pruebas.falla($$select public.cui_generar_tomas_todas(0)$$, 'Cero días es inválido', '22023');
select pruebas.falla($$select public.cui_generar_tomas_todas(15)$$, 'Más de 14 días es inválido', '22023');
select pruebas.ok(public.cui_generar_tomas_todas(2) >= 0, 'El servidor genera las tomas de todos los hogares');
select pruebas.igual(public.cui_generar_tomas_todas(2), 0, 'Es idempotente: la segunda corrida no crea nada');
select pruebas.ok((select count(*) from public.cui_tomas where programada_para >= date_trunc('day', now()) - interval '1 day') > 0
                    or not exists (select 1 from public.cui_medicamentos where activo),
  'Las tomas de hoy existen');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.cui_generar_tomas_todas()$$, 'La cuidadora no la ejecuta', '42501');

-- ---------------------------------------------------------------- 2. posponer toma
select pruebas.como_servicio();
select pruebas.igual(public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 2), 6, 'Preparación: tomas del lunes y el martes');

-- Lunes 14:00 es de Diana (turno 9:00 a 15:00); a las 15:00 sigue el dueño.
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.cui_posponer_toma(t.id) from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'$$,
  'Fuera de turno (la hermana el lunes 14:00): 42501', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.cui_posponer_toma(pg_temp.toma('2026-11-09 14:00-06'))$$,
  'La pareja no pospone', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.cui_posponer_toma(pg_temp.toma('2026-11-09 14:00-06'))$$,
  'Casa no pospone', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.cui_posponer_toma(gen_random_uuid())$$, 'Una toma que no existe: 42501', '42501');
select pruebas.falla($$select public.cui_posponer_toma(t.id) from public.cui_tomas t where t.programada_para = '2026-11-09 20:00-06'$$,
  'La cuidadora no pospone la toma de las 20:00 (turno del dueño)', '42501');
select pruebas.ok((select public.cui_posponer_toma(t.id) = pruebas.id_persona('ana@ejemplo.test')
                     from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'),
  'La cuidadora pospone su toma de las 14:00: pasa a quien sigue (el dueño a las 15:00)');
select pruebas.ok((select pospuesta_a = pruebas.id_persona('ana@ejemplo.test') and estado = 'pendiente' and pospuesta_en is not null
                     from public.cui_tomas where programada_para = '2026-11-09 14:00-06'),
  'Queda a quién se pasó y sigue pendiente');
select pruebas.falla($$select public.cui_posponer_toma(t.id) from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'$$,
  'Quien la pasó ya no puede posponerla otra vez', '42501');
select pruebas.falla($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'$$,
  'ni marcarla', '42501');
select pruebas.falla($$update public.cui_tomas set pospuesta_a = null$$, 'La app no escribe la pospuesta directo', '42501');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t
  where t.programada_para = '2026-11-09 14:00-06'$$), 1, 'Quien la recibe la marca');

-- Ya marcada: no se pospone (la de las 20:00 del lunes es del dueño; el martes 20:00 es de la hermana)
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t
  where t.programada_para = '2026-11-10 20:00-06'$$), 1, 'Preparación: la hermana marca su toma del martes 20:00');
select pruebas.falla($$select public.cui_posponer_toma(t.id) from public.cui_tomas t where t.programada_para = '2026-11-10 20:00-06'$$,
  'Una toma ya marcada no se pospone', '55000');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.cui_posponer_toma(t.id) from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'$$,
  'ni la que recibió y marcó', '55000');

-- Otra toma: la del dueño el lunes 20:00 pasa a la siguiente persona de turno que no sea él (martes 7:30 la cuidadora)
select pruebas.ok((select public.cui_posponer_toma(t.id) = pruebas.id_persona('diana@ejemplo.test')
                     from public.cui_tomas t where t.programada_para = '2026-11-09 20:00-06'),
  'El dueño pospone la de las 20:00 y pasa a la cuidadora del siguiente turno (martes 7:30)');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'no_dado') from public.cui_tomas t
  where t.programada_para = '2026-11-09 20:00-06'$$), 1, 'La cuidadora a quien se la pasaron puede marcarla');

-- Auditoría sin texto clínico
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'cuidados.toma_pospuesta'$$), 2,
  'Cada pospuesta queda en la bitácora de auditoría');
select pruebas.ok((select bool_and(detalle = '{}'::jsonb) from public.bitacora where accion = 'cuidados.toma_pospuesta'),
  'y no lleva datos clínicos (medicamento, dosis, hora)');

-- ---------------------------------------------------------------- 3. cambio urgente: quién lo atendió
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  select 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'),
         extract(isodow from now() at time zone 'America/Mexico_City')::int, 0, 1440, 'cuidadora'$$), 1,
  'Preparación: turno de todo el día de hoy para la cuidadora');
select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'Cambio de ejemplo uno', 'a5400000-0000-4000-8000-0000000000c1');
select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'Cambio de ejemplo dos', 'a5400000-0000-4000-8000-0000000000c2');
select pruebas.ok((select atendido_por is null from public.cui_cambios_urgentes where id = 'a5400000-0000-4000-8000-0000000000c1'),
  'Sin atender, atendido_por es nulo');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-0000000000c1')$$), 1, 'La cuidadora lo atiende');
select pruebas.ok((select atendido_por = pruebas.id_persona('diana@ejemplo.test') and atendido_en is not null
                     from public.cui_cambios_urgentes where id = 'a5400000-0000-4000-8000-0000000000c1'),
  'Queda quién lo atendió (la pone el servidor)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-0000000000c1')$$), 1,
  'Atenderlo otra vez no falla');
select pruebas.ok((select atendido_por = pruebas.id_persona('diana@ejemplo.test') from public.cui_cambios_urgentes
                    where id = 'a5400000-0000-4000-8000-0000000000c1'), '… y no cambia quién lo atendió');
select pruebas.igual(pruebas.afecta($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-0000000000c2')$$), 1, 'El dueño atiende el otro');
select pruebas.ok((select atendido_por = pruebas.id_persona('ana@ejemplo.test') from public.cui_cambios_urgentes
                    where id = 'a5400000-0000-4000-8000-0000000000c2'), 'y queda a su nombre');
select pruebas.falla($$update public.cui_cambios_urgentes set atendido_por = pruebas.id_persona('carla@ejemplo.test')$$,
  'La app no escribe atendido_por directo', '42501');

-- ---------------------------------------------------------------- 4. citas
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_citas (hogar_id, programada_en, lugar, nota)
  values ('b0000000-0000-4000-8000-000000000001', '2026-11-20 10:00-06', 'Clínica de ejemplo', 'Llevar estudios (ejemplo)')$$), 1,
  'La dueña agrega una cita');
select pruebas.ok((select persona_id = pruebas.id_persona('ana@ejemplo.test') and creada_en <= now() from public.cui_citas),
  'El servidor pone quién y cuándo');
select pruebas.falla($$insert into public.cui_citas (hogar_id, persona_id, programada_en) values
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), now())$$, 'No manda persona_id', '42501');
select pruebas.falla($$insert into public.cui_citas (hogar_id, programada_en, lugar) values
  ('b0000000-0000-4000-8000-000000000001', now(), repeat('x', 121))$$, 'Lugar de más de 120 caracteres falla', '23514');
select pruebas.falla($$insert into public.cui_citas (hogar_id, programada_en, nota) values
  ('b0000000-0000-4000-8000-000000000001', now(), repeat('x', 501))$$, 'Nota de más de 500 caracteres falla', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.cui_citas (hogar_id, programada_en, lugar, nota) values
  ('b0000000-0000-4000-8000-000000000001', now(), repeat('x', 120), repeat('y', 500))$$), 1, 'Los máximos exactos sí');
select pruebas.falla($$update public.cui_citas set lugar = 'otro'$$, 'Solo agregar: sin UPDATE', '42501');
select pruebas.falla($$delete from public.cui_citas$$, 'ni DELETE', '42501');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_citas (hogar_id, programada_en, lugar) values
  ('b0000000-0000-4000-8000-000000000001', '2026-11-25 09:00-06', 'Laboratorio de ejemplo')$$), 1, 'La hermana agrega una cita');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.cui_citas (hogar_id, programada_en, lugar) values
  ('b0000000-0000-4000-8000-000000000001', '2026-11-26 09:00-06', 'Consulta de ejemplo')$$), 1, 'La cuidadora agrega una cita');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 4,
  'La cuidadora ve lo suyo y lo del dueño y la hermana (4 citas), como la bitácora');

select pruebas.como_postgres();
insert into public.cui_citas (hogar_id, persona_id, programada_en, lugar)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), now(), 'Cita de la maestra (ejemplo)');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas where lugar like 'Cita de la maestra%'$$), 0,
  'La cuidadora no ve la cita de quien no es dueño ni hermana');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 5, 'La dueña ve todas');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 5, 'La hermana ve todas');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 0, 'La pareja sin consentimiento no ve citas');
select pruebas.falla($$insert into public.cui_citas (hogar_id, programada_en) values ('b0000000-0000-4000-8000-000000000001', now())$$,
  'ni escribe', '42501');
select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true);
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 5, 'Con consentimiento las lee (como la bitácora)');
select pruebas.falla($$insert into public.cui_citas (hogar_id, programada_en) values ('b0000000-0000-4000-8000-000000000001', now())$$,
  'pero sigue sin escribir', '42501');

select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 0, 'La cuenta maestra no ve citas');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 0, 'Casa no ve citas');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_citas$$), 0, 'Otro hogar no ve citas');
select pruebas.falla($$insert into public.cui_citas (hogar_id, programada_en) values ('b0000000-0000-4000-8000-000000000001', now())$$,
  'ni escribe en este hogar', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.cui_citas$$, 'anon no lee', '42501');

rollback;
