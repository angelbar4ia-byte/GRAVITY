-- Cuidados v1.4 (spec 5 §8f): instrucciones para la cuidadora principal. Hogar Ejemplo: Ana dueña, Alex pareja,
-- Marta cuenta maestra (coadministrador), Carla hermana, Diana cuidadora, Casa.
begin;

-- ---------------------------------------------------------------- la pareja SIN consentimiento deja una instrucción
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'Papá no debe comer sal hoy (ejemplo)') is not null,
  'La pareja sin consentimiento deja una instrucción');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora$$), 0, 'La pareja sin consentimiento no lee la bitácora, ni su propia instrucción');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_entregas$$), 0, '… ni las entregas');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota) values ('b0000000-0000-4000-8000-000000000001', 'x')$$,
  'La pareja no escribe directo en la tabla', '42501');
select pruebas.falla($$insert into public.cui_bitacora (hogar_id, nota, tipo) values ('b0000000-0000-4000-8000-000000000001', 'x', 'instruccion')$$,
  'ni mandando tipo = instruccion', '42501');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', repeat('x', 501))$$,
  'Más de 500 caracteres falla', '22023');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', '   ')$$, 'Texto vacío falla', '22023');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', null)$$, 'Texto nulo falla', '22023');
select pruebas.ok(public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', repeat('y', 500)) is not null, 'Exactamente 500 caracteres sí');

-- ---------------------------------------------------------------- dueña y hermana
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'Dar la cena a las 19:00 (ejemplo)') is not null,
  'La dueña deja una instrucción');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'Llevo la fruta el martes (ejemplo)') is not null,
  'La hermana deja una instrucción');

-- ---------------------------------------------------------------- la cuidadora
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora where tipo = 'instruccion'$$), 4,
  'La cuidadora ve las instrucciones de dueña, hermana y pareja (2 de la pareja)');
select pruebas.ok(exists (select 1 from public.cui_bitacora where persona_id = pruebas.id_persona('alex@ejemplo.test') and tipo = 'instruccion'),
  'Ve la instrucción de la pareja');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'x')$$,
  'La cuidadora no deja instrucciones por esta vía', '42501');

-- Una nota (no instrucción) de la pareja, escrita por el servidor, sigue oculta para la cuidadora
select pruebas.como_postgres();
insert into public.cui_bitacora (hogar_id, persona_id, nota)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'Nota de la pareja (ejemplo)');
-- Entrada (cualquier tipo) de otra persona que no es dueño, hermana ni pareja: la cuenta maestra
insert into public.cui_bitacora (hogar_id, persona_id, nota, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'Entrada de la maestra (ejemplo)', 'instruccion');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora where nota like 'Nota de la pareja%'$$), 0, 'No ve una nota de la pareja que no es instrucción');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_bitacora where nota like 'Entrada de la maestra%'$$), 0, 'No ve la entrada de quien no es dueño, hermana ni pareja');

-- ---------------------------------------------------------------- la maestra, la cuidadora y la auditoría
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'x')$$, 'La cuenta maestra no deja instrucciones', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'cuidados.instruccion_dejada'$$), 4,
  'Cada instrucción deja su entrada de auditoría');
select pruebas.ok(not exists (select 1 from public.bitacora where accion = 'cuidados.instruccion_dejada' and detalle::text like '%Papá%'),
  'La auditoría no lleva el texto');

-- ---------------------------------------------------------------- la pareja CON consentimiento
select pruebas.como('alex@ejemplo.test');
select public.cui_cambiar_consentimiento('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), true);
select pruebas.ok(public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'Otra instrucción (ejemplo)') is not null,
  'Con consentimiento también deja instrucciones');
select pruebas.ok(pruebas.cuenta($$select * from public.cui_bitacora$$) >= 5, 'Con consentimiento lee la bitácora (v1.2)');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_entregas$$), 0, 'Las entregas siguen cerradas');

-- ---------------------------------------------------------------- quien no es del círculo
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.cui_dejar_instruccion('b0000000-0000-4000-8000-000000000001', 'x')$$, 'Casa no deja instrucciones', '42501');

rollback;
