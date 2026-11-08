-- Alimentación, Fase 7 v1.2 (5c): lista por función y presentación del mismo ingrediente (migración 20261131).
-- Seed: Ana dueña, Alex pareja, Carla familiar, Diana cuidadora, Casa, Marta maestra, Elena otro hogar.
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo) values
  ('a7100000-0000-4000-8000-0000000000d1', 'b0000000-0000-4000-8000-000000000001', 'Arroz Lista', 'kg', 'Despensa'),
  ('a7100000-0000-4000-8000-0000000000d2', 'b0000000-0000-4000-8000-000000000001', 'Frijol Lista', 'kg', 'Despensa');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d1', 2) ->> 'cantidad')::numeric, 2::numeric, 'La dueña agrega a su lista');
select pruebas.igual((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d1', 1.5, 'kg') ->> 'cantidad')::numeric, 3.5::numeric, 'Mismo ingrediente pendiente: suma, no duplica');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras where ingrediente_id = 'a7100000-0000-4000-8000-0000000000d1'$$), 1, 'Una sola fila');
select pruebas.igual((select cuenta || ':' || unidad || ':' || comprado::text from public.ali_compras where ingrediente_id = 'a7100000-0000-4000-8000-0000000000d1'), 'dueno:kg:false', 'Cuenta propia, unidad y sin comprar');
select pruebas.igual(public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d1', 1, 'l') ->> 'pasillo', 'Despensa', 'Otra unidad es otra fila; el pasillo sale del ingrediente');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras where ingrediente_id = 'a7100000-0000-4000-8000-0000000000d1'$$), 2, 'dos filas por unidad distinta');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 0)$$, 'Cantidad cero', '22023');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', -1)$$, 'Cantidad negativa', '22023');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1, '  ')$$, 'Unidad vacía', '22023');
select pruebas.falla($$insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad) values
  ('b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'La app no inserta directo', '42501');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d1', 2) ->> 'cantidad')::numeric, 2::numeric, 'La pareja tiene su propia lista (no suma con la del dueño)');
select pruebas.falla($$insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad) values
  ('b0000000-0000-4000-8000-000000000001', 'pareja', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'y tampoco inserta directo', '42501');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 3) ->> 'cuenta', 'papa', 'La familiar agrega al menú de Papá');
select pruebas.igual((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1) ->> 'cantidad')::numeric, 4::numeric, 'y suma sin duplicar');

select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'La cuidadora no agrega', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'Casa no agrega', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'La cuenta maestra no agrega', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'Otro hogar no agrega', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000000d2', 1)$$, 'anon no ejecuta', '42501');

-- ---------------------------------------------------------------- presentación del mismo ingrediente
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d1', 'pza', 'bolsa 900 g') ->> 'presentacion', 'bolsa 900 g', 'La dueña cambia unidad y presentación');
select pruebas.igual((select unidad || '|' || presentacion from public.ali_ingredientes where id = 'a7100000-0000-4000-8000-0000000000d1'), 'pza|bolsa 900 g', 'del mismo ingrediente');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes where lower(nombre) = 'arroz lista'$$), 1, 'sin crear otro');
select pruebas.igual((select cantidad from public.ali_compras where ingrediente_id = 'a7100000-0000-4000-8000-0000000000d1' and cuenta = 'dueno' and unidad = 'pza'), 3.5::numeric, 'Lo pendiente sigue la nueva unidad');
select pruebas.igual(public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d1', null, null) ->> 'presentacion', 'bolsa 900 g', 'Nulo conserva');
select pruebas.igual(public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d1', null, '') ->> 'presentacion', null, 'Vacío quita la presentación');
select pruebas.falla($$select public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d1', '  ', null)$$, 'Unidad vacía', '22023');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad) values ('b0000000-0000-4000-8000-000000000001', ' ARROZ lista ', 'kg')$$, 'El nombre sigue único por hogar (marca o presentación no crean otro)', '23505');
select pruebas.falla($$update public.ali_ingredientes set presentacion = 'x' where id = 'a7100000-0000-4000-8000-0000000000d1'$$, 'La presentación no se escribe directo', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d2', null, 'caja 1 kg') ->> 'unidad', 'kg', 'La pareja también edita');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d2', 'g', null)$$, 'La familiar no edita', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d2', 'g', null)$$, 'La maestra no edita', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d2', 'g', null)$$, 'La cuidadora no lee ni edita', 'P0002');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d2', 'g', null)$$, 'Casa tampoco', 'P0002');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.ali_editar_presentacion('a7100000-0000-4000-8000-0000000000d2', 'g', null)$$, 'Otro hogar no la toca', 'P0002');
select pruebas.como_postgres();
