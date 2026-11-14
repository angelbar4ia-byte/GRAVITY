-- Alimentación (D23): dos menús por hogar; ali_puede decide quién lee y escribe cada parte. Casa nada; la maestra solo lee.
begin;
select pruebas.nuevo_adulto('teo@ejemplo.test');   -- otro coadministrador (la pareja)

-- ---------------------------------------------------------------- dueña y pareja: los dos menús
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus$$), 2, 'La dueña ve los dos perfiles');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menu$$) + pruebas.cuenta($$select * from public.ali_suplementos$$)
  + pruebas.cuenta($$select * from public.ali_platillos$$) + pruebas.cuenta($$select * from public.ali_compras_marcas$$), 7, '… y todo el contenido');
select pruebas.igual(pruebas.afecta($$update public.ali_menus set perfil = '{"titulo": "Nuevo"}' where menu = 'papa'$$), 1, 'La dueña edita el perfil clínico de Papá');
select pruebas.igual(pruebas.afecta($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 0, 'cena')$$), 1, 'y su menú');
select pruebas.ok((select actualizado_por = pruebas.id_persona('ana@ejemplo.test') from public.ali_menu where tiempo = 'cena'), 'Queda quién lo cambió (lo pone el servidor)');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, actualizado_por)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 1, 'cena', pruebas.id_persona('alex@ejemplo.test'))$$,
  'La app no manda actualizado_por', '42501');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo) values
  ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-03', 0, 'cena')$$, 'El menú es de una semana en lunes', '23514');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 0, 'cena')$$, 'Una entrada por menú, día y tiempo', '23505');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 2, 'cena', gen_random_uuid())$$, 'El platillo existe en el hogar', '23503');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo) values
  ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 2, 'merienda')$$, 'Cuatro tiempos de comida', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.ali_compras_marcas (hogar_id, menu, semana, clave)
  values ('b0000000-0000-4000-8000-000000000001', 'pareja', '2026-11-02', 'Lechuga|pieza')$$), 1, 'Marca "comprado"');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus$$), 2, 'La pareja ve los dos perfiles');
select pruebas.igual(pruebas.afecta($$update public.ali_menu set platillo_id = 'a1000000-0000-4000-8000-000000000002' where menu = 'pareja'$$), 1, 'y edita el menú de la pareja');
select pruebas.igual(pruebas.afecta($$update public.ali_menu set platillo_id = null where menu = 'papa' and tiempo = 'desayuno'$$), 1, '… y el de Papá');
select pruebas.igual(pruebas.afecta($$insert into public.ali_suplementos (hogar_id, menu, nombre) values ('b0000000-0000-4000-8000-000000000001', 'papa', 'Otro')$$), 1, 'Edita suplementos');
select pruebas.igual(pruebas.afecta($$insert into public.ali_compras_marcas (hogar_id, menu, semana, clave)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 'Plátano|pieza')$$), 1, 'y marca comprado');
select pruebas.igual(pruebas.afecta($$update public.ali_menus set perfil = '{"titulo": "Cambio de la pareja"}' where menu = 'papa'$$), 0,
  'Pero el perfil clínico de Papá lo edita solo el dueño');
select pruebas.igual(pruebas.afecta($$update public.ali_menus set perfil = '{"titulo": "Pareja"}' where menu = 'pareja'$$), 1, 'El de la pareja sí');

-- ---------------------------------------------------------------- familiar: edita el menú de Papá y nada más
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus where menu = 'papa'$$), 1, 'La familiar ve el perfil de Papá');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus where menu = 'pareja'$$) + pruebas.cuenta($$select * from public.ali_menu where menu = 'pareja'$$)
  + pruebas.cuenta($$select * from public.ali_suplementos where menu = 'pareja'$$) + pruebas.cuenta($$select * from public.ali_compras_marcas where menu = 'pareja'$$), 0,
  'No ve nada del menú de la pareja');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras_marcas$$), 0, 'ni la lista de compras de Papá (por confirmar)');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_suplementos where menu = 'papa'$$) >= 1, 'Ve los suplementos de Papá…');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_platillos$$) >= 2, '… y los platillos');
select pruebas.igual(pruebas.afecta($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id)
  values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 3, 'comida', 'a1000000-0000-4000-8000-000000000001')$$), 1, 'EDITA el menú de Papá (ajuste del 6/nov)');
select pruebas.igual(pruebas.afecta($$update public.ali_menu set platillo_id = 'a1000000-0000-4000-8000-000000000002' where menu = 'papa' and dia = 3$$), 1, '… y lo cambia');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo)
  values ('b0000000-0000-4000-8000-000000000001', 'pareja', '2026-11-02', 4, 'cena')$$, 'No escribe el de la pareja', '42501');
select pruebas.igual(pruebas.afecta($$update public.ali_menu set platillo_id = null where menu = 'pareja'$$), 0, '… ni lo modifica');
select pruebas.falla($$insert into public.ali_suplementos (hogar_id, menu, nombre) values ('b0000000-0000-4000-8000-000000000001', 'papa', 'X')$$, 'No edita suplementos', '42501');
select pruebas.falla($$insert into public.ali_platillos (hogar_id, nombre) values ('b0000000-0000-4000-8000-000000000001', 'X')$$, 'ni platillos', '42501');
select pruebas.falla($$insert into public.ali_compras_marcas (hogar_id, menu, semana, clave) values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 'X|g')$$, 'ni marca comprado', '42501');
select pruebas.igual(pruebas.afecta($$update public.ali_menus set perfil = '{}' where menu = 'papa'$$), 0, 'ni el perfil');

-- ---------------------------------------------------------------- cuidadora: solo ve a Papá y su lista
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus$$), 1, 'La cuidadora ve el perfil de Papá');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_menu where menu = 'papa'$$) >= 1 and pruebas.cuenta($$select * from public.ali_compras_marcas where menu = 'papa'$$) >= 1,
  '… su menú y su lista de compras');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menu where menu = 'pareja'$$) + pruebas.cuenta($$select * from public.ali_suplementos where menu = 'pareja'$$)
  + pruebas.cuenta($$select * from public.ali_compras_marcas where menu = 'pareja'$$), 0, 'Nada de la pareja');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo) values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 5, 'cena')$$,
  'No edita', '42501');
select pruebas.igual(pruebas.afecta($$delete from public.ali_menu$$), 0, 'ni borra');

-- ---------------------------------------------------------------- la cuenta maestra: solo lectura de los dos
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus$$), 2, 'La maestra ve los dos perfiles');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_menu$$) >= 2 and pruebas.cuenta($$select * from public.ali_suplementos$$) >= 2
  and pruebas.cuenta($$select * from public.ali_compras_marcas$$) >= 1, '… y todo lo demás');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo) values ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 5, 'cena')$$,
  'Nunca escribe el menú de Papá', '42501');
select pruebas.falla($$insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo) values ('b0000000-0000-4000-8000-000000000001', 'pareja', '2026-11-02', 5, 'cena')$$,
  'ni el de la pareja', '42501');
select pruebas.igual(pruebas.afecta($$update public.ali_menus set perfil = '{}'$$) + pruebas.afecta($$delete from public.ali_suplementos$$)
  + pruebas.afecta($$delete from public.ali_compras_marcas$$), 0, 'ni perfil, suplementos ni compras');

-- ---------------------------------------------------------------- Casa, otro hogar, anon
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus$$) + pruebas.cuenta($$select * from public.ali_menu$$)
  + pruebas.cuenta($$select * from public.ali_suplementos$$) + pruebas.cuenta($$select * from public.ali_platillos$$)
  + pruebas.cuenta($$select * from public.ali_compras_marcas$$), 0, 'La cuenta Casa (tablet pública) no ve NADA, ni el perfil clínico');
select pruebas.falla($$insert into public.ali_platillos (hogar_id, nombre) values ('b0000000-0000-4000-8000-000000000001', 'X')$$, 'ni escribe', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menus$$) + pruebas.cuenta($$select * from public.ali_menu$$)
  + pruebas.cuenta($$select * from public.ali_platillos$$), 0, 'Otro hogar no ve nada');
select pruebas.falla($$insert into public.ali_platillos (hogar_id, nombre) values ('b0000000-0000-4000-8000-000000000001', 'X')$$, 'ni escribe en este hogar', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.ali_menus$$, 'Sin sesión no se lee nada', '42501');

-- ---------------------------------------------------------------- la dueña que además es maestra conserva sus permisos
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.igual(pruebas.afecta($$update public.ali_menus set perfil = '{"titulo": "Sigue editando"}' where menu = 'papa'$$), 1, 'La dueña-maestra sigue editando');
select pruebas.como_postgres();
select pruebas.ok(not public.ali_puede('b0000000-0000-4000-8000-000000000001', 'otro', 'menu', 'leer'), 'Un menú desconocido es falso');
select pruebas.ok(not public.ali_puede('b0000000-0000-4000-8000-000000000001', 'papa', 'precio', 'leer'), 'Un objeto desconocido es falso');
select pruebas.ok(not public.ali_puede('b0000000-0000-4000-8000-000000000001', 'papa', 'menu', 'borrar'), 'Una acción desconocida es falsa');

-- ---------------------------------------------------------------- esquema y cuota
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public'
  and table_name in ('ali_platillos', 'ali_menus', 'ali_menu', 'ali_suplementos', 'ali_compras_marcas')
  and column_name ~* '(precio|costo|monto|centavos)'), 'Sin columnas de precio ni dinero (las de la Fase 4; los precios de la Fase 7 están en ali_ingredientes, test 100)');
select pruebas.ok(not exists (select 1 from pg_trigger t where not t.tgisinternal and t.tgfoid = 'public.registrar_cambio_en_bitacora()'::regprocedure
  and t.tgrelid::regclass::text like 'ali\_%'), 'Sin bitácora (el perfil clínico no se copia a otra parte)');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.ali_suplementos (hogar_id, menu, nombre)
  select 'b0000000-0000-4000-8000-000000000001', 'pareja', 'S' || g from generate_series(1, 201) g$$, 'Cuota de filas por hogar', '54000');
rollback;
