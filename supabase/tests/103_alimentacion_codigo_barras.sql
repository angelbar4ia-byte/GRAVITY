-- Alimentación, Fase 7: código de barras del ingrediente (migración 20261129).
-- Seed: Ana dueña, Alex pareja, Carla familiar, Diana cuidadora, Casa, Marta maestra, Elena otro hogar.
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo) values
  ('a7100000-0000-4000-8000-0000000000c1', 'b0000000-0000-4000-8000-000000000001', 'Avena Cero', 'kg', 'Despensa'),
  ('a7100000-0000-4000-8000-0000000000c2', 'b0000000-0000-4000-8000-000000000001', 'Atún Cero', 'pza', 'Despensa');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '7501055300013'), '7501055300013', 'La dueña guarda un código de 13 dígitos');
select pruebas.igual((select codigo_barras from public.ali_ingredientes where id = 'a7100000-0000-4000-8000-0000000000c1'), '7501055300013', 'Quedó en el ingrediente');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', ' 7501055300013 '), '7501055300013', 'Mismo código otra vez (con espacios): idempotente');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '7501055300013')$$, 'Un código, un ingrediente por hogar', '23505');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '1234567')$$, '7 dígitos no valen', '22023');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '123456789012345')$$, '15 dígitos no valen', '22023');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '75010553A0013')$$, 'Con letras no vale', '22023');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '12345678; drop')$$, 'Ni con basura', '22023');
select pruebas.falla($$update public.ali_ingredientes set codigo_barras = '12345678' where id = 'a7100000-0000-4000-8000-0000000000c2'$$, 'La app no escribe la columna directo', '42501');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', null), null, 'Nulo quita el código');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '7501055300013'), '7501055300013', 'y se puede volver a poner');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '12345678'), '12345678', 'La pareja también guarda (8 dígitos es el mínimo)');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c2', '12345678901234'), '12345678901234', 'y 14 dígitos es el máximo');

select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '99999999')$$, 'La familiar lee pero no escribe', '42501');
select pruebas.igual((select codigo_barras from public.ali_ingredientes where id = 'a7100000-0000-4000-8000-0000000000c1'), '7501055300013', 'La familiar sí lee el código');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '99999999')$$, 'La cuenta maestra no escribe', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '99999999')$$, 'La cuidadora no escribe', 'P0002');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$), 0, 'ni lee el catálogo');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '99999999')$$, 'Casa no escribe', 'P0002');

select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes where codigo_barras is not null$$), 0, 'Otro hogar no ve los códigos');
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '99999999')$$, 'ni toca el ingrediente ajeno', 'P0002');
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo) select 'a7100000-0000-4000-8000-0000000000c9', h.id, 'Avena Otra', 'kg', 'Despensa'
  from public.hogares h where h.id <> 'b0000000-0000-4000-8000-000000000001' limit 1;
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c9', '7501055300013'), '7501055300013', 'Otro hogar puede usar el mismo código (único por hogar)');

select pruebas.como_anon();
select pruebas.falla($$select public.ali_guardar_codigo_barras('a7100000-0000-4000-8000-0000000000c1', '12345678')$$, 'Sin sesión no se ejecuta', '42501');
rollback;
