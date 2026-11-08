-- Cuidados v1.6 (migración 20261122): horarios de comida editables por hogar.
-- Hogar Ejemplo: Ana dueña, Alex pareja, Marta cuenta maestra, Carla hermana, Diana cuidadora, Casa.
begin;

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 4,
  'El dueño lee los cuatro horarios');
select pruebas.igual((select hora::text from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001') where tiempo = 'desayuno'),
  '08:30:00', 'Desayuno por omisión 08:30');
select pruebas.igual((select string_agg(tiempo || '=' || hora::text, ',') from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')),
  'desayuno=08:30:00,comida=14:00:00,colacion=17:00:00,cena=19:00:00', 'Valores por omisión y orden del día');

select pruebas.ok(public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '13:30') = time '13:30',
  'El dueño cambia la hora de la comida');
select pruebas.igual((select hora::text from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001') where tiempo = 'comida'),
  '13:30:00', 'Queda guardada');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'cuidados.horario_comida_cambiado'
  and detalle->>'tiempo' = 'comida' and detalle->>'despues' = '13:30:00'$$), 1, 'El cambio queda en la bitácora de auditoría');
select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '13:30');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'cuidados.horario_comida_cambiado'$$), 1,
  'Sin cambio real no se repite la entrada');
select pruebas.ok(public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'cena', '23:59') = time '23:59', '23:59 es válido');
select pruebas.ok(public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'desayuno', '00:00') = time '00:00', '00:00 es válido');

select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'cena', '24:00')$$,
  'Hora fuera de rango (24:00)', '22023');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'cena', null)$$,
  'Hora nula', '22023');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'merienda', '18:00')$$,
  'Tiempo desconocido', '22023');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', null, '18:00')$$,
  'Tiempo nulo', '22023');
select pruebas.falla($$update public.cui_horarios_comida set hora = '10:00'$$, 'La app no escribe directo', '42501');
select pruebas.falla($$insert into public.cui_horarios_comida values ('b0000000-0000-4000-8000-000000000001', 'cena', '10:00')$$,
  'ni inserta', '42501');
select pruebas.igual((select hora::text from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001') where tiempo = 'cena'),
  '23:59:00', 'Lo inválido no cambió nada');

-- Quienes ven Cuidados leen, pero no escriben
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 4, 'La pareja lee');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$,
  'La pareja no cambia horarios', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 4, 'La cuidadora lee');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$,
  'La cuidadora no cambia horarios', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 4, 'La hermana lee');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$,
  'La hermana no cambia horarios', '42501');

-- Quienes no ven Cuidados
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 0, 'La cuenta maestra no lee');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$,
  'La maestra no cambia horarios', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 0, 'Casa no lee');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$,
  'Casa no cambia horarios', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_horarios_hogar('b0000000-0000-4000-8000-000000000001')$$), 0, 'Otro hogar no lee');
select pruebas.falla($$select public.cui_fijar_horario_comida('b0000000-0000-4000-8000-000000000001', 'comida', '15:00')$$,
  'Otro hogar no cambia', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.cui_horarios_comida$$, 'anon no lee', '42501');

-- Hogar nuevo: se siembran los cuatro horarios
select pruebas.como_servicio();
insert into public.hogares (nombre) values ('Hogar nuevo horarios');
select pruebas.igual((select count(*)::int from public.cui_horarios_comida h join public.hogares g on g.id = h.hogar_id
                       where g.nombre = 'Hogar nuevo horarios'), 4, 'Un hogar nuevo trae sus cuatro horarios');

rollback;
