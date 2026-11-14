-- Alimentación, Fase 8 v1.3 (migración 20261141): porciones recomendadas editables y su lectura.
-- Seed: Ana dueña y albacea de Papá, Alex pareja, Carla familiar, Casa, Marta maestra, Elena otro hogar.
begin;
select pruebas.como_postgres();
insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id, porciones_recomendadas)
values ('b0000000-0000-4000-8000-000000000001', 'pareja', date_trunc('week', current_date)::date, 3, 'comida',
        'a1000000-0000-4000-8000-000000000001', '{"dueno": 1, "pareja": 1}'),
       ('b0000000-0000-4000-8000-000000000001', 'pareja', date_trunc('week', current_date)::date, 4, 'cena',
        'a1000000-0000-4000-8000-000000000001', '{"dueno": 1, "pareja": 1}');

-- ---------------------------------------------------------------- lectura
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.ali_porciones_recomendadas('b0000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date)), 2,
  'La lectura devuelve una fila por platillo y persona, aunque el platillo esté en varias entradas');
select pruebas.ok((select count(*) = 2 and bool_and(porciones = 1)
                     from public.ali_porciones_recomendadas('b0000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date)),
  'La dueña ve las porciones de dueño y de pareja');

-- ---------------------------------------------------------------- escritura de la dueña
select pruebas.igual(public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
  date_trunc('week', current_date)::date, 'dueno', 2), 2, 'La dueña fija su porción en todas las entradas del platillo de la semana');
select pruebas.ok((select count(*) = 2 and bool_and((porciones_recomendadas ->> 'dueno')::numeric = 2) and bool_and((porciones_recomendadas ->> 'pareja')::numeric = 1)
                     from public.ali_menu where menu = 'pareja' and platillo_id = 'a1000000-0000-4000-8000-000000000001'
                      and semana = date_trunc('week', current_date)::date),
  'Cambiar la porción del dueño no toca la de la pareja');
select pruebas.falla($$select public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date, 'abuelo', 1)$$,
  'Solo dueno o pareja', '22023');
select pruebas.falla($$select public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date, 'dueno', 0)$$,
  'Porción menor a 0.25', '22023');
select pruebas.falla($$select public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date, 'dueno', 21)$$,
  'Porción mayor a 20', '22023');
select pruebas.falla($$select public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', (date_trunc('week', current_date) - interval '7 days')::date, 'dueno', 1)$$,
  'Un platillo que no está en la semana indicada no se cambia', 'P0002');

-- ---------------------------------------------------------------- la pareja cambia la suya y conserva la de la dueña
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
  date_trunc('week', current_date)::date, 'pareja', 1.5), 2, 'La pareja fija su porción');
select pruebas.ok((select count(*) = 2 and bool_and((porciones_recomendadas ->> 'dueno')::numeric = 2) and bool_and((porciones_recomendadas ->> 'pareja')::numeric = 1.5)
                     from public.ali_menu where menu = 'pareja' and platillo_id = 'a1000000-0000-4000-8000-000000000001'
                      and semana = date_trunc('week', current_date)::date),
  'La porción de la dueña queda y la de la pareja cambia');

-- ---------------------------------------------------------------- la familiar no cambia ni ve el menú compartido
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date, 'dueno', 3)$$,
  'La familiar no cambia porciones del menú compartido', '42501');
select pruebas.ok((select count(*) = 0 from public.ali_porciones_recomendadas('b0000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date)),
  'La familiar no lee las porciones del menú compartido');

-- ---------------------------------------------------------------- la casa no ve nada del menú compartido
select pruebas.como('casa@ejemplo.test');
select pruebas.ok((select count(*) = 0 from public.ali_porciones_recomendadas('b0000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date)),
  'Casa no lee las porciones');

-- ---------------------------------------------------------------- otro hogar no cambia nada de este
select pruebas.como('elena@ejemplo.test');
select pruebas.ok((select count(*) = 0 from public.ali_porciones_recomendadas('b0000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date)),
  'Un hogar ajeno no lee las porciones de este hogar');
select pruebas.falla($$select public.ali_fijar_porcion('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', date_trunc('week', current_date)::date, 'dueno', 1)$$,
  'Un hogar ajeno no cambia porciones', '42501');
