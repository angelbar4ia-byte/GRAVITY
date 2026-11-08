-- Alimentación, Fase 7 (D28): reglas de cada cuenta, precio base que el real reemplaza, compras con dinero (libro correcto o
-- solicitud al albacea), plan familiar por votación (cambio de voto mientras esté abierta, cierre diario), suplementos y menú del día para Casa.
begin;
-- Fixtures como postgres. Cuentas del seed: Ana dueña y albacea de Papá, Alex pareja y suplente, Carla familiar, Diana cuidadora,
-- Casa, Marta maestra, Elena otro hogar.
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Arroz',  'kg', 'Despensa', 2000),
  ('a7100000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Frijol', 'kg', 'Despensa', 3000),
  ('a7100000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'Leche',  'l',  'Lácteos',  2500),
  ('a7100000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'Pollo',  'kg', 'Carnes',   9000);
insert into public.ali_despensa (hogar_id, cuenta, ingrediente_id, cantidad, reservado) values
  ('b0000000-0000-4000-8000-000000000001', 'papa',   'a7100000-0000-4000-8000-000000000001', 5, 0),
  ('b0000000-0000-4000-8000-000000000001', 'dueno',  'a7100000-0000-4000-8000-000000000002', 4, 1),
  ('b0000000-0000-4000-8000-000000000001', 'dueno',  'a7100000-0000-4000-8000-000000000003', 2, 2),
  ('b0000000-0000-4000-8000-000000000001', 'pareja', 'a7100000-0000-4000-8000-000000000003', 6, 2),
  ('b0000000-0000-4000-8000-000000000001', 'casa',   'a7100000-0000-4000-8000-000000000001', 1, 0);
insert into public.ali_platillo_ingredientes (hogar_id, platillo_id, ingrediente_id, cantidad) values
  ('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-000000000001', 3),
  ('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-000000000002', 2),
  ('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000002', 'a7100000-0000-4000-8000-000000000003', 1);
insert into public.ali_ingredientes (hogar_id, nombre, unidad) values ('b0000000-0000-4000-8000-000000000002', 'Ingrediente del vecino', 'kg');

-- ---------------------------------------------------------------- catálogo y precio base
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$), 7, 'La dueña ve los ingredientes (3 del seed y 4 de la prueba)');
select pruebas.ok((select precio_es_base and precio_vigente_centavos = 2000 and precio_real_centavos is null
                     from public.ali_ingredientes where nombre = 'Arroz'), 'El precio de un ingrediente nuevo es el BASE supuesto: se marca como base');
select pruebas.igual(pruebas.afecta($$insert into public.ali_ingredientes (hogar_id, nombre, unidad, pasillo, precio_base_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Huevo', 'pieza', 'Lácteos', 300)$$), 1, 'La dueña agrega ingredientes con precio base');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad) values ('b0000000-0000-4000-8000-000000000001', 'ARROZ ', 'kg')$$,
  'El nombre no se repite (sin importar mayúsculas)', '23505');
select pruebas.falla($$update public.ali_ingredientes set precio_real_centavos = 100, precio_real_en = now() where nombre = 'Huevo'$$,
  'Nadie escribe el precio real a mano (solo la compra)', '42501');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad, precio_base_centavos) values ('b0000000-0000-4000-8000-000000000001', 'Negativo', 'kg', -1)$$,
  'El precio base no es negativo', '23514');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.ali_ingredientes set precio_base_centavos = 2100 where nombre = 'Arroz'$$), 1, 'La pareja edita el catálogo');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$), 8, 'La familiar ve el catálogo');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad) values ('b0000000-0000-4000-8000-000000000001', 'X', 'kg')$$, 'pero no lo edita', '42501');
select pruebas.igual(pruebas.afecta($$update public.ali_ingredientes set precio_base_centavos = 1$$), 0, '… ni cambia precios');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$) + pruebas.cuenta($$select * from public.ali_despensa$$)
  + pruebas.cuenta($$select * from public.ali_compras$$) + pruebas.cuenta($$select * from public.ali_precios_historial$$), 0, 'La cuidadora no ve catálogo, despensas ni compras');

select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$) + pruebas.cuenta($$select * from public.ali_despensa$$)
  + pruebas.cuenta($$select * from public.ali_compras$$) + pruebas.cuenta($$select * from public.ali_recetas$$)
  + pruebas.cuenta($$select * from public.ali_platillo_ingredientes$$) + pruebas.cuenta($$select * from public.ali_solicitudes_pago$$), 0,
  'Casa no ve catálogo, recetas, despensas ni compras');

select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$), 8, 'La maestra lee el catálogo');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad) values ('b0000000-0000-4000-8000-000000000001', 'M', 'kg')$$, 'y no escribe', '42501');

select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_ingredientes$$), 1, 'Otro hogar solo ve lo suyo');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad) values ('b0000000-0000-4000-8000-000000000001', 'E', 'kg')$$, 'y no escribe en este hogar', '42501');

-- ---------------------------------------------------------------- recetas y pasos
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.ali_recetas (id, hogar_id, platillo_id, titulo, porciones)
  values ('a7200000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Avena con plátano', 2)$$), 1,
  'La dueña carga una receta');
select pruebas.igual(pruebas.afecta($$insert into public.ali_receta_pasos (hogar_id, receta_id, orden, texto) values
  ('b0000000-0000-4000-8000-000000000001', 'a7200000-0000-4000-8000-000000000001', 1, 'Calienta la leche con la avena.'),
  ('b0000000-0000-4000-8000-000000000001', 'a7200000-0000-4000-8000-000000000001', 2, 'Cocina 10 minutos moviendo.'),
  ('b0000000-0000-4000-8000-000000000001', 'a7200000-0000-4000-8000-000000000001', 3, 'Sirve con el plátano en rodajas.')$$), 3, 'Sus pasos van en orden, de texto libre');
select pruebas.ok((select array_agg(tiene_cifras order by orden) = array[false, true, false] from public.ali_receta_pasos),
  'tiene_cifras avisa qué pasos llevan números (el filtro de la bocina decide)');
set constraints all immediate;
select pruebas.falla($$insert into public.ali_receta_pasos (hogar_id, receta_id, orden, texto)
  values ('b0000000-0000-4000-8000-000000000001', 'a7200000-0000-4000-8000-000000000001', 2, 'Otro segundo paso.')$$, 'Un solo paso por lugar', '23505');
select pruebas.falla($$insert into public.ali_recetas (hogar_id, platillo_id, titulo) values ('b0000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'Otra')$$,
  'Una receta por platillo', '23505');
select pruebas.falla($$insert into public.ali_receta_pasos (hogar_id, receta_id, orden, texto)
  values ('b0000000-0000-4000-8000-000000000001', 'a7200000-0000-4000-8000-000000000001', 4, '')$$, 'El paso no va vacío', '23514');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.ali_recetas set porciones = 4 where titulo = 'Avena con plátano'$$), 1, 'La pareja edita recetas');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_receta_pasos$$), 3, 'La familiar lee la receta');
select pruebas.falla($$insert into public.ali_receta_pasos (hogar_id, receta_id, orden, texto) values ('b0000000-0000-4000-8000-000000000001', 'a7200000-0000-4000-8000-000000000001', 9, 'X')$$,
  'y no la edita', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_receta_pasos$$), 3, 'La cuidadora lee las recetas (cocina para Papá)');
select pruebas.igual(pruebas.afecta($$delete from public.ali_recetas$$), 0, 'y no las borra');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.ali_recetas set porciones = 9$$), 0, 'La maestra no escribe recetas');

-- ---------------------------------------------------------------- despensa por cuenta
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_despensa where cuenta = 'pareja'$$), 0, 'La dueña NO ve la despensa de la pareja');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_despensa where cuenta in ('papa', 'dueno', 'casa')$$) = 4, '… ve la de Papá, la suya y la de la casa');
select pruebas.falla($$insert into public.ali_despensa (hogar_id, cuenta, ingrediente_id, cantidad)
  values ('b0000000-0000-4000-8000-000000000001', 'pareja', 'a7100000-0000-4000-8000-000000000004', 1)$$, 'ni escribe en ella', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.ali_despensa (hogar_id, cuenta, ingrediente_id, cantidad)
  values ('b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000004', 1)$$), 1, 'Escribe en la suya');
select pruebas.falla($$insert into public.ali_despensa (hogar_id, cuenta, ingrediente_id, cantidad)
  values ('b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000004', -1)$$, 'La cantidad no es negativa', '23514');
select pruebas.igual((select count(*)::int from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'pareja')), 1,
  'Ve los SOBRANTES de la pareja (solo lo no reservado)');
select pruebas.ok((select sobrante = 4 and nombre = 'Leche' from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'pareja')),
  '… 6 de leche menos 2 reservados');
select pruebas.falla($$select * from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'dueno')$$, 'No pide los suyos como ajenos', '42501');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_despensa where cuenta = 'dueno'$$), 0, 'La pareja NO ve la despensa del dueño');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_despensa where cuenta in ('papa', 'pareja', 'casa')$$) = 3, '… ve la de Papá, la suya y la de la casa');
select pruebas.igual((select count(*)::int from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'dueno')), 2, 'Ve los sobrantes del dueño');
select pruebas.ok((select count(*) = 2 and sum(sobrante) = 4 and bool_or(nombre = 'Frijol' and sobrante = 3) from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'dueno')),
  '… frijol 3 de 4 (1 reservado) y pollo 1');
select pruebas.ok(not exists (select 1 from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'dueno') where nombre = 'Leche'),
  '… la leche del dueño está toda reservada: no se comparte');
select pruebas.falla($$select * from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'pareja')$$, 'Los suyos no son "sobrantes ajenos"', '42501');
select pruebas.igual(pruebas.afecta($$update public.ali_despensa set cantidad = 99 where cuenta = 'dueno'$$), 0, 'No toca la del dueño');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_despensa$$), 1, 'La familiar solo ve la despensa de Papá');
select pruebas.ok((select cuenta = 'papa' from public.ali_despensa), '… esa y ninguna otra');
select pruebas.igual(pruebas.afecta($$update public.ali_despensa set cantidad = 1$$), 0, 'sin poder editarla (solo lectura del de Papá)');
select pruebas.falla($$select * from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'pareja')$$, 'ni los sobrantes de la pareja', '42501');

select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select * from public.ali_sobrantes('b0000000-0000-4000-8000-000000000001', 'dueno')$$, 'La cuidadora no ve sobrantes', '42501');

select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_despensa$$), 6, 'La maestra lee todas las despensas');
select pruebas.igual(pruebas.afecta($$update public.ali_despensa set cantidad = 0$$), 0, 'y no escribe');

-- ---------------------------------------------------------------- lista de compras: quién agrega y quién ve
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, para_el, comprador_id) values
  ('a7300000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000001', 2, current_date, pruebas.id_persona('ana@ejemplo.test')),
  ('a7300000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000001', 1, current_date, null)$$), 2,
  'La dueña arma su lista (quién compra y cuándo)');
select pruebas.ok((select solicitada_por = pruebas.id_persona('ana@ejemplo.test') from public.ali_compras where id = 'a7300000-0000-4000-8000-000000000001'),
  'Queda quién la pidió (lo pone el servidor)');
select pruebas.falla($$insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad, comprado) values
  ('b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000001', 1, true)$$, 'Nadie crea una compra ya marcada', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad) values
  ('a7300000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-000000000003', 4),
  ('a7300000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-000000000004', 1),
  ('a7300000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000001', 'casa', 'a7100000-0000-4000-8000-000000000004', 3)$$), 3,
  'y las de Papá y de la casa');
select pruebas.falla($$insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad) values
  ('b0000000-0000-4000-8000-000000000001', 'pareja', 'a7100000-0000-4000-8000-000000000001', 1)$$, 'Pero no la lista de la pareja', '42501');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras where cuenta = 'dueno'$$), 0, 'La pareja no ve la lista del dueño');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras where cuenta in ('papa', 'casa')$$), 3, '… ve las de Papá y de la casa');
select pruebas.igual(pruebas.afecta($$insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad) values
  ('a7300000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000001', 'pareja', 'a7100000-0000-4000-8000-000000000003', 2)$$), 1, 'Arma la suya');
select pruebas.falla($$insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad) values
  ('b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000001', 1)$$, 'y no la del dueño', '42501');

select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad) values
  ('b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-000000000001', 1)$$, 'La familiar no escribe la lista directo', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras$$), 0, 'Y no ve las listas de otros');
select pruebas.falla($$select public.ali_solicitar_compra('b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-000000000001', 1)$$,
  'Solicita solo para Papá o la casa', '22023');
select pruebas.ok(public.ali_solicitar_compra('b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-000000000003', 2) is not null,
  'SOLICITA un ingrediente para la despensa de Papá');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras$$), 1, 'Ve solo lo que solicitó');
select pruebas.igual(pruebas.afecta($$delete from public.ali_compras$$), 1, 'Y puede retirarlo mientras no se compre');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000003')$$, 'No marca compras', '42501');

select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_solicitar_compra('b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-000000000003', 2)$$,
  'La cuidadora no solicita compras', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_solicitar_compra('b0000000-0000-4000-8000-000000000001', 'casa', 'a7100000-0000-4000-8000-000000000003', 2)$$,
  'Casa tampoco', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras$$), 6, 'La maestra lee todas las listas');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000003')$$, 'y no marca compras', '42501');

-- ---------------------------------------------------------------- compra con precio real: reemplaza al base y dinero al libro correcto
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', 5000, 'c4000000-0000-4000-8000-000000000002')$$,
  'La pareja no marca la lista del dueño', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', 5000)$$, 'Con monto hace falta la cuenta de pago', '22023');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', 5000, 'c4000000-0000-4000-8000-000000000002')$$,
  'La compra del dueño sale de SU libro, no del de la pareja', '42501');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', 0, 'c3000000-0000-4000-8000-000000000002')$$,
  'El monto es mayor que cero', '22023');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', null, 'c3000000-0000-4000-8000-000000000002')$$,
  'Sin monto no hay movimiento', '22023');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', 5000, 'c3000000-0000-4000-8000-000000000002')) ->> 'estado_pago',
  'movimiento', 'La dueña marca la compra con lo que pagó: 2 kg por 50.00 pesos');
select pruebas.ok((select precio_real_centavos = 2500 and not precio_es_base and precio_vigente_centavos = 2500 and precio_base_centavos = 2100 and precio_real_en is not null
                     from public.ali_ingredientes where nombre = 'Arroz'),
  'El precio REAL (25.00 el kg) reemplaza al base en el catálogo; el base queda como estaba');
select pruebas.ok((select m.tipo = 'gasto' and m.monto_centavos = 5000 and m.cuenta_origen_id = 'c3000000-0000-4000-8000-000000000002'
                          and m.cuenta_destino_id = 'c2000000-0000-4000-8000-000000000001' and m.libro_origen_id = pruebas.libro_personal('ana@ejemplo.test')
                          and m.en_nombre_de is null
                     from public.fin_movimientos m join public.ali_compras c on c.movimiento_id = m.id where c.id = 'a7300000-0000-4000-8000-000000000001'),
  'Se registró el gasto en el libro personal de la dueña, en la cuenta de Alimentación');
select pruebas.ok((select cantidad = 2 from public.ali_despensa where cuenta = 'dueno' and ingrediente_id = 'a7100000-0000-4000-8000-000000000001'),
  'La despensa de la dueña sube con lo comprado (2 kg)');
select pruebas.ok((select estado_pago = 'movimiento' and comprado and monto_centavos = 5000 and comprado_por = pruebas.id_persona('ana@ejemplo.test') from public.ali_compras
                    where id = 'a7300000-0000-4000-8000-000000000001'), 'La compra queda marcada con quién y cuánto');
select pruebas.igual((select count(*)::int from public.ali_precios_historial where ingrediente_id = 'a7100000-0000-4000-8000-000000000001'), 1, 'El historial guarda el precio capturado');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000001', 5000, 'c3000000-0000-4000-8000-000000000002')$$,
  'Una compra no se marca dos veces', '22023');
select pruebas.igual(pruebas.afecta($$update public.ali_compras set cantidad = 9 where id = 'a7300000-0000-4000-8000-000000000001'$$), 0, 'Marcada, ya no se edita');
select pruebas.igual(pruebas.afecta($$delete from public.ali_compras where id = 'a7300000-0000-4000-8000-000000000001'$$), 0, '… ni se borra');
-- La siguiente compra ACTUALIZA el real (no vuelve al base).
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000002', 3000, 'c3000000-0000-4000-8000-000000000002')) ->> 'precio_real_centavos',
  '3000', 'La segunda compra (1 kg a 30.00) actualiza el precio real');
select pruebas.ok((select precio_real_centavos = 3000 and not precio_es_base from public.ali_ingredientes where nombre = 'Arroz'), 'El catálogo tiene el último precio real');
select pruebas.igual((select count(*)::int from public.ali_precios_historial where ingrediente_id = 'a7100000-0000-4000-8000-000000000001'), 2, 'y el historial, los dos');
select pruebas.ok((select cantidad = 3 from public.ali_despensa where cuenta = 'dueno' and ingrediente_id = 'a7100000-0000-4000-8000-000000000001'), 'La despensa suma 3 kg en total');
select pruebas.como_postgres();
select pruebas.falla($$update public.ali_compras set comprado = false where id = 'a7300000-0000-4000-8000-000000000001'$$, 'Ni el servidor desmarca una compra', '42501');
select pruebas.falla($$update public.ali_precios_historial set precio_centavos = 1$$, 'El historial de precios es solo agregar', '42501');
select pruebas.falla($$delete from public.ali_precios_historial$$, '… no se borra', '42501');
select pruebas.ok((select count(*) = 2 from public.fin_movimientos m where m.id in (select movimiento_id from public.ali_compras where movimiento_id is not null)),
  'Por ahora, dos movimientos de compras en el libro');

-- Sin precio: solo marca y sube el inventario; el precio queda como estaba.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000006')) ->> 'estado_pago', 'sin_pago', 'La pareja marca la suya sin precio');
select pruebas.ok((select precio_real_centavos is null and precio_es_base from public.ali_ingredientes where nombre = 'Leche'), 'Sin precio capturado, el ingrediente sigue con el BASE');
select pruebas.ok((select cantidad = 8 from public.ali_despensa where cuenta = 'pareja' and ingrediente_id = 'a7100000-0000-4000-8000-000000000003'), 'y su despensa sube');

-- Compra de la casa: el libro compartido lo elige el dueño.
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000005', 1200, 'c5000000-0000-4000-8000-000000000001')$$,
  'Sin libro elegido por el dueño, la compra de la casa no se paga', '22023');
select pruebas.falla($$insert into public.ali_ajustes (hogar_id, libro_casa_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001')$$,
  'La pareja no elige el libro de la casa', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.ali_ajustes (hogar_id, libro_casa_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002')$$,
  'El libro de la casa es compartido (no el de Papá)', '22023');
select pruebas.igual(pruebas.afecta($$insert into public.ali_ajustes (hogar_id, libro_casa_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001')$$), 1,
  'El dueño elige "Gastos de la casa"');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000005', 1200, 'c4000000-0000-4000-8000-000000000002')$$,
  'La compra de la casa no sale de un libro personal', '42501');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000005', 1200, 'c5000000-0000-4000-8000-000000000002')) ->> 'estado_pago', 'movimiento',
  'Sale del libro compartido que eligió el dueño');
select pruebas.ok((select m.libro_origen_id = 'f1000000-0000-4000-8000-000000000001' and m.monto_centavos = 1200 from public.fin_movimientos m
                    join public.ali_compras c on c.movimiento_id = m.id where c.id = 'a7300000-0000-4000-8000-000000000005'), '… el movimiento está en el libro de la casa');
select pruebas.ok((select precio_real_centavos = 400 from public.ali_ingredientes where nombre = 'Pollo'), 'y el pollo tiene su precio real (12.00 entre 3 kg)');

-- Compra de Papá: solicitud al albacea.
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000003', 1050, 'c6000000-0000-4000-8000-000000000002')$$,
  'La pareja (suplente) no paga directo del libro de Papá mientras haya albacea', '42501');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000003', 1050)) ->> 'estado_pago', 'solicitud',
  'Sin cuenta de pago, la compra de Papá queda como SOLICITUD al albacea');
select pruebas.ok((select count(*) = 0 from public.fin_movimientos m where m.monto_centavos = 1050), 'Todavía no hay movimiento en el libro de Papá');
select pruebas.ok((select precio_real_centavos = 263 from public.ali_ingredientes where nombre = 'Leche'), 'El precio real de la leche (10.50 entre 4 l, redondeado) ya cuenta');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago$$), 1, 'La pareja ve su solicitud');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago), true, 'c6000000-0000-4000-8000-000000000002')$$,
  'pero no la resuelve (no es el albacea)', '42501');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago$$), 1, 'La albacea ve la solicitud');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago), true)$$, 'Aprobar pide la cuenta de pago de Papá', '22023');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago), true, 'c3000000-0000-4000-8000-000000000002')$$,
  'y no puede ser de otro libro', '22023');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago), true, 'c6000000-0000-4000-8000-000000000002') is not null,
  'La albacea aprueba y paga');
select pruebas.ok((select m.en_nombre_de = 'e0000000-0000-4000-8000-000000000001' and m.monto_centavos = 1050 and m.motivo is not null
                          and m.libro_origen_id = 'f1000000-0000-4000-8000-000000000002' and m.tipo = 'gasto'
                     from public.fin_movimientos m join public.ali_compras c on c.movimiento_id = m.id where c.id = 'a7300000-0000-4000-8000-000000000003'),
  'El gasto sale del libro de Papá, en su nombre y con motivo (D19)');
select pruebas.ok((select estado_pago = 'movimiento' from public.ali_compras where id = 'a7300000-0000-4000-8000-000000000003')
                  and (select estado = 'pagada' from public.ali_solicitudes_pago), 'La compra y la solicitud quedan pagadas');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago), true, 'c6000000-0000-4000-8000-000000000002')$$,
  'Una solicitud se resuelve una vez', '22023');
-- La albacea compra algo de Papá y lo paga directo.
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000004', 1800, 'c6000000-0000-4000-8000-000000000002')) ->> 'estado_pago', 'movimiento',
  'La albacea, al marcar con la cuenta de Papá, aprueba y paga en el acto');
-- Rechazo con motivo.
select pruebas.igual(public.ali_solicitar_compra('b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-000000000002', 1) is not null, true, 'Otra solicitud');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada(id, 700) from public.ali_compras where ingrediente_id = 'a7100000-0000-4000-8000-000000000002' and cuenta = 'papa') ->> 'estado_pago',
  'solicitud', 'La pareja la marca con precio: otra solicitud');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where estado = 'pendiente'), false, null, null, 'x')$$,
  'Rechazar lleva un motivo válido', '23514');
select pruebas.ok(public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago where estado = 'pendiente'), false, null, null, 'Ya compré eso en la semana') is null,
  'La albacea rechaza con motivo (sin movimiento)');
select pruebas.ok((select estado_pago = 'rechazada' from public.ali_compras where cuenta = 'papa' and ingrediente_id = 'a7100000-0000-4000-8000-000000000002'), 'La compra queda como rechazada');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago$$) + pruebas.cuenta($$select * from public.ali_precios_historial$$), 0, 'La familiar no ve solicitudes de pago ni historial de precios');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago$$), 0, 'La cuidadora tampoco');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_solicitudes_pago$$), 2, 'La maestra lee las solicitudes');

-- ---------------------------------------------------------------- plan familiar: propuesta, alternativa, voto, cierre diario
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Cena del martes', array['a1000000-0000-4000-8000-000000000001']::uuid[])$$,
  'La cuidadora no propone menús familiares', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votaciones$$), 0, 'ni ve el plan familiar');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'X', array[]::uuid[])$$, 'Una propuesta lleva platillos', '22023');
select pruebas.falla($$select public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'X', array[gen_random_uuid()])$$, 'y platillos que existan', '23503');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Cena del martes', array['a1000000-0000-4000-8000-000000000001']::uuid[],
  'casa', current_date + 3) is not null, 'La familiar PROPONE un menú (abre la votación)');
select pruebas.ok((select cierra_en - creada_en = interval '1 day' and estado = 'abierta' and ronda = 1 from public.ali_votaciones), 'La votación dura un día y cierra al día siguiente');
select pruebas.falla($$select public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Otra', array['a1000000-0000-4000-8000-000000000002']::uuid[])$$,
  'Solo una votación abierta por plan', '22023');
select pruebas.falla($$select public.ali_proponer_alternativa((select id from public.ali_votaciones), 'Yo mismo', array['a1000000-0000-4000-8000-000000000002']::uuid[])$$,
  'La alternativa la da OTRA persona', '22023');
select pruebas.falla($$update public.ali_votaciones set estado = 'cerrada'$$, 'Nadie cambia la votación a mano', '42501');
select pruebas.falla($$insert into public.ali_votos (votacion_id, hogar_id, persona_id, opcion_id) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$$,
  'ni mete votos directo', '42501');

select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_proponer_alternativa((select id from public.ali_votaciones), 'Cena ligera', array['a1000000-0000-4000-8000-000000000002']::uuid[]) is not null,
  'La pareja da la propuesta alternativa');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_proponer_alternativa((select id from public.ali_votaciones), 'Una tercera', array['a1000000-0000-4000-8000-000000000002']::uuid[])$$,
  'Solo hay dos propuestas', '23505');
select pruebas.ok((select count(*) = 2 and bool_and(platillos <> '{}') from public.ali_votacion_opciones), 'Las dos opciones llevan los nombres de sus platillos');

-- Votos: Ana por la 1, Alex por la 2 → empate al cierre (Carla no vota).
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena del martes')), 'abierta', 'La dueña vota');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena ligera')), 'abierta', 'La pareja vota por la otra');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena ligera')), 'abierta', 'Repetir el mismo voto no hace nada');
select pruebas.igual((select cambios from public.ali_votos where persona_id = pruebas.id_persona('alex@ejemplo.test'))::int, 0, '… y no cuenta como cambio');
select pruebas.igual(public.ali_cerrar_votaciones('b0000000-0000-4000-8000-000000000001'), 0, 'Antes de su hora la votación no cierra');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votaciones$$), 1, 'Casa VE el plan familiar');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votacion_opciones$$), 2, '… sus propuestas');
select pruebas.ok((select bool_and(platillos <> '{}') from public.ali_votacion_opciones), '… con los nombres de los platillos');
select pruebas.falla($$select public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones limit 1))$$, 'pero no vota', '42501');
select pruebas.falla($$select public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'X', array['a1000000-0000-4000-8000-000000000001']::uuid[])$$, 'ni propone', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_votar((select id from public.ali_votaciones), gen_random_uuid())$$, 'La cuidadora no vota', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votos$$), 2, 'La maestra ve los votos');
select pruebas.falla($$select public.ali_votar((select id from public.ali_votaciones), gen_random_uuid())$$, 'pero no vota', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votaciones$$) + pruebas.cuenta($$select * from public.ali_votos$$), 0, 'Otro hogar no ve nada del plan');

-- Con 1 a 1 y la votación aún abierta, cada quien puede CAMBIAR su voto (antes del cierre, haya empate o no).
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena del martes')), 'abierta',
  'Aun con 1 a 1, la votación sigue abierta y cada quien puede CAMBIAR su voto');
select pruebas.ok((select opcion_id = (select id from public.ali_votacion_opciones where titulo = 'Cena del martes') and cambios = 1
                     from public.ali_votos where persona_id = pruebas.id_persona('alex@ejemplo.test')), 'El voto cambió (una vez)');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_votos$$), 2, 'Sigue un voto por persona');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena ligera')), 'abierta', 'La familiar también vota');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena del martes')), 'abierta', '… y cambia a la propuesta (3 a 0)');
-- Llega el día siguiente: se cierra con los votos de ese momento (el empate se resuelve por volado: ver 101_alimentacion_volado.sql).
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(null), 1, 'El cierre diario del servidor procesa la votación vencida');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_cerrar_votaciones('b0000000-0000-4000-8000-000000000001'), 0, 'Ya no queda nada por cerrar (también lo puede pedir la app de la dueña)');
select pruebas.ok((select estado = 'cerrada' and ganadora_id = (select id from public.ali_votacion_opciones where titulo = 'Cena del martes') and cerrada_en is not null from public.ali_votaciones),
  'Ganó la propuesta por votos, sin volado');
select pruebas.falla($$select public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena ligera'))$$,
  'Cerrada, ya no se vota', '22023');
select pruebas.falla($$select public.ali_cerrar_votaciones(null)$$, 'La dueña no cierra las de todos los hogares', '42501');
select pruebas.igual(public.ali_cerrar_votaciones('b0000000-0000-4000-8000-000000000001'), 0, 'Ya no queda nada por cerrar');

-- Ganador → faltantes → pedir compra. Avena con plátano necesita 3 de arroz y 2 de plátano; en la despensa de la casa hay 1 de arroz.
select pruebas.ok((select count(*) = 2 and sum(faltante) = 4 from public.ali_faltantes((select id from public.ali_votaciones))), 'El ganador evalúa faltantes: arroz 2, plátano 2');
select pruebas.ok((select disponible = 1 from public.ali_faltantes((select id from public.ali_votaciones)) where nombre = 'Arroz'), 'La dueña ve lo que hay en la despensa de la casa');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok((select count(*) = 2 and bool_and(disponible is null) and sum(faltante) = 4 from public.ali_faltantes((select id from public.ali_votaciones))),
  'La familiar ve los faltantes pero no el inventario de la casa');
select pruebas.igual(public.ali_pedir_compra_faltantes((select id from public.ali_votaciones), array['a7100000-0000-4000-8000-000000000001']::uuid[]), 1,
  'Quien propuso pide la compra de UN faltante');
select pruebas.igual(public.ali_pedir_compra_faltantes((select id from public.ali_votaciones)), 1, 'y luego del resto (sin repetir el ya pedido)');
select pruebas.igual(public.ali_pedir_compra_faltantes((select id from public.ali_votaciones)), 0, 'Pedir otra vez no duplica');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras where votacion_id is not null$$), 2, 'La familiar ve lo que pidió');
select pruebas.como_postgres();
select pruebas.ok((select count(*) = 2 and bool_and(cuenta = 'casa' and not comprado and para_el = current_date + 3) from public.ali_compras where votacion_id is not null),
  'Quedan en la lista de la casa, para el día del plan');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_faltantes('00000000-0000-4000-8000-000000000000')$$, 'La cuidadora no evalúa faltantes', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select * from public.ali_faltantes((select id from public.ali_votaciones))$$, 'Casa tampoco (sin despensa ni compras)', '42501');

-- Segunda votación: gana la alternativa; una propuesta sin contendiente gana sola; el servidor cierra a diario.
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Comida del sábado', array['a1000000-0000-4000-8000-000000000001']::uuid[]) is not null,
  'Se puede abrir otra votación cuando la anterior cerró');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_proponer_alternativa((select id from public.ali_votaciones where titulo = 'Comida del sábado'), 'Comida casera', array['a1000000-0000-4000-8000-000000000002']::uuid[]) is not null,
  'La familiar da la alternativa');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida del sábado'), (select id from public.ali_votacion_opciones where titulo = 'Comida casera')), 'abierta', 'Carla vota por la suya');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida del sábado'), (select id from public.ali_votacion_opciones where titulo = 'Comida casera')), 'abierta', 'Ana la acompaña');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida del sábado'), (select id from public.ali_votacion_opciones where titulo = 'Comida del sábado')), 'abierta', 'Alex vota por la suya');
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour' where titulo = 'Comida del sábado';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 1, 'El servidor cierra al día siguiente');
select pruebas.como_postgres();
select pruebas.ok((select ganadora_id = (select id from public.ali_votacion_opciones where titulo = 'Comida casera') from public.ali_votaciones where titulo = 'Comida del sábado'),
  'Ganó la alternativa 2 a 1');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Plan de Papá', array['a1000000-0000-4000-8000-000000000001']::uuid[], 'papa') is not null,
  'Propuesta para el plan de Papá (otro plan, otra votación)');
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour' where titulo = 'Plan de Papá';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 1, 'Una propuesta sin contendiente ni votos gana al cerrar');
select pruebas.como_postgres();
select pruebas.ok((select estado = 'cerrada' from public.ali_votaciones where titulo = 'Plan de Papá'), '… queda cerrada');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select disponible = 5 from public.ali_faltantes((select id from public.ali_votaciones where titulo = 'Plan de Papá')) where nombre = 'Arroz'), '… (5 de arroz, la de Papá)');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok((select disponible = 5 from public.ali_faltantes((select id from public.ali_votaciones where titulo = 'Plan de Papá')) where nombre = 'Arroz'),
  'La familiar sí ve la despensa de Papá');

-- ---------------------------------------------------------------- suplementos: tomas, confirmación y reposición
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_programar_toma('a3000000-0000-4000-8000-000000000001', now() - interval '3 hours') is not null, 'La dueña programa una toma del suplemento de Papá');
select pruebas.ok(public.ali_programar_toma('a3000000-0000-4000-8000-000000000001', now() + interval '3 hours') is not null, '… y otra más tarde');
select pruebas.falla($$select public.ali_programar_toma('a3000000-0000-4000-8000-000000000002', now())$$, 'Las tomas son solo de los suplementos de Papá', '22023');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_programar_toma('a3000000-0000-4000-8000-000000000001', now() + interval '9 hours')$$, 'La familiar no programa tomas', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tomas_suplemento$$), 2, 'pero las ve');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tomas_suplemento$$), 2, 'Casa VE las tomas');
select pruebas.ok((select bool_and(nombre = 'Suplemento de ejemplo') from public.ali_tomas_suplemento), '… con el nombre del suplemento');
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'ali_tomas_suplemento' and column_name in ('dosis', 'horario')),
  'Las tomas no llevan la dosis (dato clínico)');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_suplementos$$), 0, 'Casa no ve los suplementos en sí');
select pruebas.falla($$select public.ali_confirmar_toma((select id from public.ali_tomas_suplemento limit 1), true)$$, 'Casa no confirma', '42501');
select pruebas.falla($$select public.ali_revisar_tomas('b0000000-0000-4000-8000-000000000001')$$, 'ni revisa tomas', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_confirmar_toma((select id from public.ali_tomas_suplemento limit 1), true)$$, 'La maestra solo ve', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tomas_suplemento$$), 0, 'Otro hogar no ve las tomas');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tomas_suplemento$$), 2, 'La cuidadora ve las tomas');
select pruebas.igual(public.ali_confirmar_toma((select id from public.ali_tomas_suplemento where prevista_en > now()), true), 'dado', 'Quien lo da lo CONFIRMA: dado');
select pruebas.ok((select confirmado_por = pruebas.id_persona('diana@ejemplo.test') and confirmado_en is not null and estado = 'dado'
                     from public.ali_tomas_suplemento where prevista_en > now()), 'Queda quién lo confirmó');
select pruebas.falla($$select public.ali_confirmar_toma((select id from public.ali_tomas_suplemento where prevista_en > now()), false)$$, 'Una confirmación no se cambia', '22023');
select pruebas.falla($$update public.ali_tomas_suplemento set estado = 'dado'$$, 'Nadie confirma por la tabla', '42501');

-- Nadie confirma la primera: pasa el plazo y se solicita la reposición.
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.ali_revisar_tomas('b0000000-0000-4000-8000-000000000001'), 1, 'La toma sin confirmar pasa a "sin_confirmar"');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select count(*) = 1 and bool_and(estado = 'pendiente') from public.ali_reposiciones_suplemento), 'y se SOLICITA la reposición del suplemento');
select pruebas.ok((select estado = 'sin_confirmar' from public.ali_tomas_suplemento where prevista_en < now()), 'La toma queda marcada');
select pruebas.como_postgres();
insert into public.ali_tomas_suplemento (hogar_id, suplemento_id, nombre, prevista_en)
values ('b0000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'x', now() - interval '5 hours');
select pruebas.como_servicio();
select pruebas.igual(public.ali_revisar_tomas(), 1, 'El servidor revisa las de todos los hogares');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_reposiciones_suplemento$$), 1, 'Una sola reposición pendiente por suplemento');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_reposiciones_suplemento$$), 1, 'La pareja la ve');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_reposiciones_suplemento$$), 0, 'La familiar no ve las reposiciones');
select pruebas.falla($$select public.ali_resolver_reposicion((select id from public.ali_reposiciones_suplemento), true)$$, 'ni las resuelve', '42501');
select pruebas.como('alex@ejemplo.test');
select public.ali_resolver_reposicion((select id from public.ali_reposiciones_suplemento), true);
select pruebas.ok((select estado = 'atendida' and resuelta_por = pruebas.id_persona('alex@ejemplo.test') from public.ali_reposiciones_suplemento), 'La pareja marca la reposición como atendida');
select pruebas.falla($$select public.ali_resolver_reposicion((select id from public.ali_reposiciones_suplemento), true)$$, 'Una vez', '22023');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(public.ali_confirmar_toma((select id from public.ali_tomas_suplemento where estado = 'sin_confirmar' order by prevista_en limit 1), false), 'no_dado',
  'Una toma sin confirmar se puede confirmar después (no dado)');

-- ---------------------------------------------------------------- menú del día de Papá para Casa
select pruebas.como_postgres();
insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id)
select 'b0000000-0000-4000-8000-000000000001', 'papa', h - (extract(isodow from h)::int - 1), extract(isodow from h)::int - 1, t.tiempo, t.platillo::uuid
  from (select (now() at time zone 'America/Mexico_City')::date as h) d,
       (values ('comida', 'a1000000-0000-4000-8000-000000000001'), ('cena', 'a1000000-0000-4000-8000-000000000002')) as t (tiempo, platillo);
insert into public.ali_menu (hogar_id, menu, semana, dia, tiempo, platillo_id)
select 'b0000000-0000-4000-8000-000000000001', 'papa', h - (extract(isodow from h)::int - 1), extract(isodow from h)::int - 1, 'colacion', 'a1000000-0000-4000-8000-000000000001'
  from (select (now() at time zone 'America/Mexico_City')::date + 1 as h) d;
select pruebas.como('casa@ejemplo.test');
select pruebas.igual((select count(*)::int from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001')), 2, 'Casa recibe el menú del DÍA de Papá (2 tiempos)');
select pruebas.ok((select array_agg(tiempo order by tiempo) = array['cena', 'comida'] from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001')), '… comida y cena');
select pruebas.igual((select count(*)::int from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001', current_date + 400)), 2,
  'Casa no pide otros días: siempre recibe el de hoy');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_menu$$) + pruebas.cuenta($$select * from public.ali_menus$$) + pruebas.cuenta($$select * from public.ali_platillos$$)
  + pruebas.cuenta($$select * from public.ali_suplementos$$), 0, 'Pero Casa sigue sin leer las tablas del menú, el perfil clínico ni el catálogo');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001')), 2, 'La cuidadora recibe el menú del día de Papá');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001', (now() at time zone 'America/Mexico_City')::date + 1)), 1,
  'La familiar puede pedir otro día (mañana: la colación)');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select * from public.ali_menu_del_dia_papa('b0000000-0000-4000-8000-000000000001')$$, 'Otro hogar no recibe nada', '42501');

-- ---------------------------------------------------------------- general: aislamiento, anon, esquema, cuota
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_recetas$$) + pruebas.cuenta($$select * from public.ali_despensa$$) + pruebas.cuenta($$select * from public.ali_compras$$)
  + pruebas.cuenta($$select * from public.ali_ajustes$$) + pruebas.cuenta($$select * from public.ali_opcion_platillos$$) + pruebas.cuenta($$select * from public.ali_reposiciones_suplemento$$), 0,
  'Otro hogar no ve recetas, despensas, compras ni ajustes');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-000000000004', 1)$$, 'ni marca compras ajenas', '42501');
select pruebas.como_anon();
select pruebas.falla($$select * from public.ali_ingredientes$$, 'Sin sesión no se lee el catálogo', '42501');
select pruebas.falla($$select * from public.ali_votaciones$$, '… ni el plan', '42501');
select pruebas.falla($$select public.ali_votar(gen_random_uuid(), gen_random_uuid())$$, '… ni se vota', '42501');
select pruebas.como_postgres();
select pruebas.ok((select bool_and(c.relrowsecurity) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname in (
  'ali_ingredientes', 'ali_recetas', 'ali_receta_pasos', 'ali_platillo_ingredientes', 'ali_ajustes', 'ali_despensa', 'ali_compras', 'ali_solicitudes_pago',
  'ali_precios_historial', 'ali_votaciones', 'ali_votacion_opciones', 'ali_opcion_platillos', 'ali_votos', 'ali_tomas_suplemento', 'ali_reposiciones_suplemento')),
  'Todas las tablas nuevas tienen RLS');
select pruebas.ok(not exists (select 1 from pg_trigger t where not t.tgisinternal and t.tgfoid = 'public.registrar_cambio_en_bitacora()'::regprocedure
  and t.tgrelid::regclass::text like 'ali\_%'), 'Sin bitácora en Alimentación (hay datos clínicos de Papá)');
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name like 'ali\_%'
  and column_name ~* '(precio|monto|centavos)' and table_name not in ('ali_ingredientes', 'ali_compras', 'ali_solicitudes_pago', 'ali_precios_historial')),
  'El dinero solo está en ingredientes, compras, solicitudes de pago e historial de precios');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.ali_ingredientes (hogar_id, nombre, unidad) select 'b0000000-0000-4000-8000-000000000001', 'Masivo ' || g, 'kg' from generate_series(1, 5001) g$$,
  'Cuota de filas por hogar', '54000');
rollback;
