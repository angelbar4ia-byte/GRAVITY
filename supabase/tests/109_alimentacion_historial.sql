-- Alimentación, Fase 8 (ampliaciones 1, 3 y 4): tiendas del hogar e historial de compra (migración 20261138).
-- Seed: Ana dueña y albacea de Papá, Alex pareja, Carla familiar, Diana cuidadora, Casa, Marta maestra, Elena otro hogar.
begin;
select pruebas.como_postgres();
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) values
  ('a7100000-0000-4000-8000-0000000009a1', 'b0000000-0000-4000-8000-000000000001', 'Arroz H', 'kg', 'Despensa', 2000),
  ('a7100000-0000-4000-8000-0000000009a2', 'b0000000-0000-4000-8000-000000000001', 'Frijol H', 'kg', 'Despensa', 3000),
  ('a7100000-0000-4000-8000-0000000009a3', 'b0000000-0000-4000-8000-000000000001', 'Leche H', 'l', 'Lácteos', 2500),
  ('a7100000-0000-4000-8000-0000000009a4', 'b0000000-0000-4000-8000-000000000001', 'Sal H', 'kg', 'Despensa', 2000);
insert into public.ali_tiendas (id, hogar_id, nombre) values
  ('a7500000-0000-4000-8000-0000000009b1', 'b0000000-0000-4000-8000-000000000001', 'Mercado'),
  ('a7500000-0000-4000-8000-0000000009b2', 'b0000000-0000-4000-8000-000000000001', 'Super'),
  ('a7500000-0000-4000-8000-0000000009b3', 'b0000000-0000-4000-8000-000000000001', 'Tienda cerrada'),
  ('a7500000-0000-4000-8000-0000000009b9', 'b0000000-0000-4000-8000-000000000002', 'Tienda del vecino');
update public.ali_tiendas set activa = false where id = 'a7500000-0000-4000-8000-0000000009b3';

-- Compras ANTERIORES a la Fase 8 (sin tienda): enero y marzo de 2026, con su precio real.
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por, comprado, comprado_en, comprado_por, monto_centavos, estado_pago) values
  ('a7300000-0000-4000-8000-0000000009c1', 'b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-0000000009a1', 2,
   pruebas.id_persona('ana@ejemplo.test'), true, '2026-01-10 12:00-06', pruebas.id_persona('ana@ejemplo.test'), 5000, 'solicitud'),
  ('a7300000-0000-4000-8000-0000000009c2', 'b0000000-0000-4000-8000-000000000001', 'dueno', 'a7100000-0000-4000-8000-0000000009a2', 1,
   pruebas.id_persona('ana@ejemplo.test'), true, '2026-03-05 12:00-06', pruebas.id_persona('ana@ejemplo.test'), 3000, 'solicitud');
insert into public.ali_precios_historial (hogar_id, ingrediente_id, precio_centavos, compra_id, registrado_por) values
  ('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a1', 2500, 'a7300000-0000-4000-8000-0000000009c1', pruebas.id_persona('ana@ejemplo.test')),
  ('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a2', 3000, 'a7300000-0000-4000-8000-0000000009c2', pruebas.id_persona('ana@ejemplo.test'));
-- Una compra de Papá por marcar.
insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad, solicitada_por) values
  ('a7300000-0000-4000-8000-0000000009c3', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000009a3', 2, pruebas.id_persona('ana@ejemplo.test'));

-- ---------------------------------------------------------------- la tienda es obligatoria en toda compra nueva
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a1', 2) is not null, 'Preparación: arroz en la lista');
select pruebas.falla($$select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1),
  5600, 'c3000000-0000-4000-8000-000000000002')$$, 'Una compra nueva sin tienda no se guarda', '22023');
select pruebas.falla($$select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1),
  5600, 'c3000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000009b3')$$, 'Ni con una tienda desactivada', '22023');
select pruebas.falla($$select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1),
  5600, 'c3000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000009b9')$$, 'Ni con la tienda de otro hogar', '22023');
select pruebas.falla($$select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1),
  null, p_tienda => null)$$, 'Tampoco una compra sin precio va sin tienda', '22023');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_compras where cuenta = 'dueno' and not comprado$$), 1, 'La compra fallida queda pendiente');
select pruebas.como_postgres();
select pruebas.falla($$update public.ali_compras set comprado = true, comprado_en = now(), comprado_por = pruebas.id_persona('ana@ejemplo.test'),
  monto_centavos = 100, estado_pago = 'solicitud' where cuenta = 'dueno' and not comprado$$, 'El servidor también lo exige si se marca por otra vía', '22023');

-- ---------------------------------------------------------------- compras nuevas con tienda
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada((select id from public.ali_compras where cuenta = 'dueno' and not comprado limit 1),
  5600, 'c3000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000009b1')) ->> 'precio_real_centavos', '2800', 'Arroz en Mercado: 2 kg por 56.00');
select pruebas.igual((select public.ali_marcar_comprada((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a2', 1) ->> 'id')::uuid,
  3300, 'c3000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000009b2')) ->> 'precio_real_centavos', '3300', 'Frijol en Super');
-- Sin precio: marca con tienda, pero no es precio real y no entra al historial.
select pruebas.igual((select public.ali_marcar_comprada((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a4', 1) ->> 'id')::uuid,
  p_tienda => 'a7500000-0000-4000-8000-0000000009b1')) ->> 'estado_pago', 'sin_pago', 'Compra sin precio, con tienda');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000009c3', 1050, p_tienda => 'a7500000-0000-4000-8000-0000000009b2')) ->> 'estado_pago',
  'solicitud', 'Compra de Papá con tienda (solicitud al albacea)');
select pruebas.ok((select tienda_id = 'a7500000-0000-4000-8000-0000000009b2' from public.ali_compras where id = 'a7300000-0000-4000-8000-0000000009c3'), 'La compra guarda su tienda');
select pruebas.falla($$update public.ali_compras set tienda_id = 'a7500000-0000-4000-8000-0000000009b1' where id = 'a7300000-0000-4000-8000-0000000009c3'$$,
  'La app no escribe la tienda directo', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a1', 1) ->> 'id')::uuid,
  2400, 'c4000000-0000-4000-8000-000000000002', p_tienda => 'a7500000-0000-4000-8000-0000000009b1')) ->> 'precio_real_centavos', '2400', 'La pareja compra en su propia lista');

-- ---------------------------------------------------------------- tiendas: lista del hogar, agregar, desactivar, no borrar con compras
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tiendas$$), 3, 'La dueña ve las tiendas de su hogar (no la del vecino)');
select pruebas.igual(public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', '  Abarrotes Lupita ') ->> 'nombre', 'Abarrotes Lupita', 'La dueña agrega una tienda (sin espacios sobrantes)');
select pruebas.igual((public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'mercado') ->> 'id')::uuid, 'a7500000-0000-4000-8000-0000000009b1'::uuid, 'Un nombre repetido (sin mayúsculas) devuelve la misma');
select pruebas.igual((public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'Tienda cerrada') ->> 'activa')::boolean, true, 'Agregar una desactivada la reactiva');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', '   ')$$, 'Nombre vacío', '22023');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', repeat('x', 61))$$, 'Nombre de más de 60', '22023');
select pruebas.falla($$insert into public.ali_tiendas (hogar_id, nombre) values ('b0000000-0000-4000-8000-000000000001', 'Directa')$$, 'No se inserta directo', '42501');
select pruebas.falla($$delete from public.ali_tiendas where id = 'a7500000-0000-4000-8000-0000000009b1'$$, 'Una tienda con compras no se borra', '23503');
select pruebas.igual((public.ali_tienda_activa('a7500000-0000-4000-8000-0000000009b1', false) ->> 'activa')::boolean, false, 'Se desactiva');
select pruebas.falla($$select public.ali_marcar_comprada((public.ali_agregar_a_lista('b0000000-0000-4000-8000-000000000001', 'a7100000-0000-4000-8000-0000000009a4', 1) ->> 'id')::uuid,
  p_tienda => 'a7500000-0000-4000-8000-0000000009b1')$$, 'y una desactivada ya no recibe compras', '22023');
select pruebas.igual((public.ali_tienda_activa('a7500000-0000-4000-8000-0000000009b1', true) ->> 'activa')::boolean, true, 'y se reactiva');
select pruebas.igual(pruebas.afecta($$delete from public.ali_tiendas where nombre = 'Abarrotes Lupita'$$), 1, 'Una tienda sin compras sí se borra');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'Farmacia') is not null, 'La pareja también agrega');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'X')$$, 'La familiar no agrega', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_tiendas$$), 0, 'ni ve la lista');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'X')$$, 'La cuidadora no agrega', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'X')$$, 'Casa tampoco', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'X')$$, 'La maestra lee, no agrega', '42501');
select pruebas.falla($$select public.ali_tienda_activa('a7500000-0000-4000-8000-0000000009b1', false)$$, 'ni cambia tiendas', '42501');
select pruebas.ok(pruebas.cuenta($$select * from public.ali_tiendas$$) >= 4, 'pero las lee');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'X')$$, 'Otro hogar no agrega a este', '42501');
select pruebas.falla($$select public.ali_tienda_activa('a7500000-0000-4000-8000-0000000009b1', false)$$, 'ni toca sus tiendas', 'P0002');
select pruebas.como_anon();
select pruebas.falla($$select public.ali_agregar_tienda('b0000000-0000-4000-8000-000000000001', 'X')$$, 'anon no ejecuta', '42501');
select pruebas.falla($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$, 'anon no lee el historial', '42501');

-- ---------------------------------------------------------------- historial: solo precios reales; las anteriores, sin tienda
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 5,
  'La dueña ve 5 compras reales: 2 anteriores, 2 propias nuevas y la de Papá; no la sin precio ni la de la pareja');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null) where tienda = 'Sin tienda' and tienda_id is null$$), 2,
  'Las anteriores aparecen como "Sin tienda"');
select pruebas.ok(not exists (select 1 from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)
                               where precio_unitario_centavos in (2000, 3000) and ingrediente <> 'Frijol H'),
  'El precio base de supuesto no aparece (Arroz y Sal valían 2000 de base)');
select pruebas.ok(not exists (select 1 from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null) where ingrediente = 'Sal H'),
  'La compra sin precio no entra');
select pruebas.igual((select sum(gasto_centavos)::bigint from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)), 17950::bigint, 'Gasto total: 50 + 30 + 56 + 33 + 10.50 pesos');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31')$$), 2, 'Filtro por fechas');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, 'a7100000-0000-4000-8000-0000000009a1')$$), 2, 'Filtro por ingrediente (Arroz: la anterior y la de Mercado)');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, null, 'a7500000-0000-4000-8000-0000000009b2')$$), 2, 'Filtro por tienda (Super: frijol y leche de Papá)');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, 'a7100000-0000-4000-8000-0000000009a1', 'a7500000-0000-4000-8000-0000000009b2')$$), 0, 'Combinados');
select pruebas.igual((select precio_unitario_centavos from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null, 'a7100000-0000-4000-8000-0000000009a3')), 525::bigint, 'Precio unitario real de la leche de Papá: 10.50 entre 2');
select pruebas.falla($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', '2026-02-01', '2026-01-01')$$, 'Rango al revés', '22023');

-- ---------------------------------------------------------------- los cuatro ejes suman lo mismo
select pruebas.igual((select array_agg(distinct t) from (
    select (sum(compras), sum(gasto_centavos), sum(cantidad))::text t from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tiempo')
    union all select (sum(compras), sum(gasto_centavos), sum(cantidad))::text from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'precio')
    union all select (sum(compras), sum(gasto_centavos), sum(cantidad))::text from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')
    union all select (sum(compras), sum(gasto_centavos), sum(cantidad))::text from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tienda')
    union all select (count(*), sum(gasto_centavos), sum(cantidad))::text from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)) z), array['(5,17950,8.000)'],
  'Tiempo, precio, producto y tienda suman lo mismo que las compras reales (5 compras, 17,950 centavos)');
select pruebas.igual((select sum(monto_centavos)::bigint from public.ali_compras where comprado and monto_centavos is not null), 17950::bigint, 'y eso es la suma de las compras de la lista de la dueña');
select pruebas.igual((select array_agg(distinct (select sum(gasto_centavos)::bigint from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tiempo', e)))
                        from unnest(array['semana', 'mes', 'bimestre', 'semestre', 'anio']) e), array[17950::bigint], 'En cualquier escala de tiempo el total es el mismo');
select pruebas.igual((select string_agg(clave || '=' || gasto_centavos, ',' order by clave) from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31', 'tiempo', 'semana')),
  '2026-01-05=5000,2026-03-02=3000', 'Escala semana (lunes)');
select pruebas.igual((select string_agg(clave || '=' || gasto_centavos, ',' order by clave) from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31', 'tiempo', 'mes')),
  '2026-01-01=5000,2026-03-01=3000', 'Escala mes');
select pruebas.igual((select string_agg(clave || '=' || gasto_centavos, ',' order by clave) from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31', 'tiempo', 'bimestre')),
  '2026-01-01=5000,2026-03-01=3000', 'Escala bimestre');
select pruebas.igual((select string_agg(clave || '=' || gasto_centavos, ',' order by clave) from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31', 'tiempo', 'semestre')),
  '2026-01-01=8000', 'Escala semestre');
select pruebas.igual((select string_agg(clave || '=' || gasto_centavos, ',' order by clave) from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31', 'tiempo', 'anio')),
  '2026-01-01=8000', 'Escala año');
select pruebas.igual((select clave || ':' || etiqueta || ':' || gasto_centavos from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', '2026-01-01', '2026-03-31', 'tienda')),
  'sin_tienda:Sin tienda:8000', 'Eje tienda: lo anterior es "sin tienda"');
select pruebas.igual((select precio_primero_centavos || '>' || precio_ultimo_centavos || ' ' || variacion_pct from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'precio')
                       where etiqueta = 'Arroz H'), '2500>2800 12.0', 'Eje precio: el arroz subió 12.0 por ciento');
select pruebas.igual((select compras || '/' || cantidad || '/' || gasto_centavos from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')
                       where etiqueta = 'Arroz H'), '2/4.000/10600', 'Eje producto: veces, cantidad y gasto del arroz');
select pruebas.igual((select string_agg(etiqueta || '=' || gasto_centavos, ',' order by etiqueta) from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tienda', 'mes', 'a7100000-0000-4000-8000-0000000009a1')),
  'Mercado=5600,Sin tienda=5000', 'Eje tienda filtrado a un producto: dónde se compró el arroz');
select pruebas.falla($$select * from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'otro')$$, 'Eje inválido', '22023');
select pruebas.falla($$select * from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tiempo', 'decada')$$, 'Escala inválida', '22023');

-- ---------------------------------------------------------------- cada cuenta ve solo su lista (regla de Alimentación)
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 2,
  'La pareja ve su compra y la de Papá, no las de la dueña');
select pruebas.igual((select sum(gasto_centavos)::bigint from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tienda')), 3450::bigint, 'y su resumen suma solo eso');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 6, 'La maestra lee todas');
select pruebas.igual((select sum(gasto_centavos)::bigint from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')), 20350::bigint, 'y los ejes suman lo mismo para ella');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 0,
  'La familiar no ve precios (solo ve el menú de Papá)');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'producto')$$), 0, 'ni resumen');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 0, 'La cuidadora no ve nada');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 0, 'Casa tampoco');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_historial_compras('b0000000-0000-4000-8000-000000000001', null, null)$$), 0, 'Otro hogar no ve el historial de este');
select pruebas.igual(pruebas.cuenta($$select * from public.ali_resumen_historial('b0000000-0000-4000-8000-000000000001', null, null, 'tienda')$$), 0, 'ni el resumen');
select pruebas.como_postgres();
rollback;
