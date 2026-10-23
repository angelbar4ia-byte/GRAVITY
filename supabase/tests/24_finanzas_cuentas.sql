-- Criterio 15 (5.0 bis 2-6): una cuenta con movimientos no se borra; se
-- cierra o archiva solo con saldo cero; congelada o cerrada no admite
-- movimientos nuevos. Cuentas de sistema y de gasto del hogar. Categorías:
-- 3 niveles, se borran solo sin datos; con datos se archivan (5.2).
begin;
select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- borrar
select pruebas.falla($$delete from public.fin_cuentas where id = 'c3000000-0000-4000-8000-000000000002'$$,
  'No se borra una cuenta con movimientos (llave foránea restrict)', '23503');
select pruebas.igual(pruebas.afecta($$delete from public.fin_cuentas where id = 'c3000000-0000-4000-8000-000000000006'$$), 1,
  'Una cuenta sin movimientos se borra');
select pruebas.falla($$delete from public.fin_cuentas
  where id = pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura')$$,
  'Las cuentas de sistema no se borran', '23503');

-- ---------------------------------------------------------------- cerrar y archivar
select pruebas.falla($$update public.fin_cuentas set estado = 'cerrada' where id = 'c3000000-0000-4000-8000-000000000002'$$,
  'No se cierra una cuenta con saldo', '22023');
select pruebas.falla($$update public.fin_cuentas set estado = 'archivada' where id = 'c3000000-0000-4000-8000-000000000003'$$,
  'Ni se archiva una tarjeta con deuda', '22023');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c3000000-0000-4000-8000-0000000000f2', 'b0000000-0000-4000-8000-000000000001',
   pruebas.libro_personal('ana@ejemplo.test'), 'Cuenta vieja', 'banco'),
  ('c3000000-0000-4000-8000-0000000000f3', 'b0000000-0000-4000-8000-000000000001',
   pruebas.libro_personal('ana@ejemplo.test'), 'Cuenta con pendiente', 'banco');
select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
                         'c3000000-0000-4000-8000-0000000000f2', 100000);
select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-0000000000f2',
                         'c3000000-0000-4000-8000-000000000001', 100000);
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c3000000-0000-4000-8000-0000000000f2'),
  0::bigint, 'La cuenta vieja quedó en cero');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'cerrada'
  where id = 'c3000000-0000-4000-8000-0000000000f2'$$), 1, 'Con saldo cero sí se cierra');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-0000000000f2',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Una cuenta cerrada no admite movimientos', '55000');
select pruebas.falla($$delete from public.fin_cuentas where id = 'c3000000-0000-4000-8000-0000000000f2'$$,
  'Cerrada pero con movimientos: no se borra', '23503');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'archivada'
  where id = 'c3000000-0000-4000-8000-0000000000f2'$$), 1, 'Y se archiva');
select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
                         'c3000000-0000-4000-8000-0000000000f3', 1000);
select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-0000000000f3',
                         'c3000000-0000-4000-8000-000000000001', 1000);
insert into public.fin_movimientos (hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, estado_inicial)
values ('b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21', now(),
        'c3000000-0000-4000-8000-0000000000f3', 'c2000000-0000-4000-8000-000000000001', 500, 'pendiente');
select pruebas.falla($$update public.fin_cuentas set estado = 'cerrada' where id = 'c3000000-0000-4000-8000-0000000000f3'$$,
  'Con un pendiente tampoco se cierra (saldo confirmado cero, con pendientes no)', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'congelada'
  where id = 'c3000000-0000-4000-8000-000000000002'$$), 1, 'Se congela una cuenta con saldo');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Congelada no admite movimientos nuevos', '55000');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'activa'
  where id = 'c3000000-0000-4000-8000-000000000002'$$), 1, 'Y se reactiva');

-- D19 (23/oct/2026): el saldo cero solo vale para activos y pasivos; las cuentas de gasto e
-- ingreso son de periodo y se archivan o cierran con su saldo.
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'archivada'
  where id = 'c2000000-0000-4000-8000-000000000008'$$), 1,
  'Una cuenta de gasto con movimientos (Entretenimiento) se archiva sin saldo cero');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000008', 100)$$,
  'Archivada, no admite gastos nuevos', '55000');
select pruebas.ok(
  pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000008', 'c3000000-0000-4000-8000-000000000003', 25000,
                    '2026-10-14', 'Cine mal capturado (ejemplo)', 'd1000000-0000-4000-8000-000000000006') is not null,
  'Pero sí se anula un gasto anterior (acerca la cuenta a cero)');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'cerrada'
  where id = 'c3000000-0000-4000-8000-000000000005'$$), 1,
  'Una cuenta de ingreso (Sueldo de Ana) se cierra sin saldo cero');
select pruebas.falla($$select pruebas.registrar('ingreso', 'c3000000-0000-4000-8000-000000000005',
  'c3000000-0000-4000-8000-000000000001', 100)$$,
  'Cerrada, no admite ingresos nuevos', '55000');
select pruebas.ok(
  pruebas.registrar('anulacion', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000005', 900000,
                    '2026-10-15', 'Quincena duplicada (ejemplo)', 'd1000000-0000-4000-8000-000000000007') is not null,
  'Pero sí se anula uno anterior');
select pruebas.falla($$update public.fin_cuentas set estado = 'archivada' where id = 'c3000000-0000-4000-8000-000000000003'$$,
  'Una tarjeta (pasivo) con deuda sigue pidiendo saldo cero', '22023');
select pruebas.falla($$update public.fin_cuentas set estado = 'cerrada' where id = 'c3000000-0000-4000-8000-000000000001'$$,
  'Un banco (activo) con saldo, también', '22023');
select pruebas.falla($$update public.fin_cuentas set estado = 'archivada'
  where id = pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'por_clasificar')$$,
  'Una cuenta de sistema (Por clasificar) nunca se archiva', '22023');

-- ---------------------------------------------------------------- cuentas de sistema y tipos
select pruebas.falla($$update public.fin_cuentas set estado = 'congelada'
  where id = pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes')$$,
  'Las cuentas de sistema siempre están activas', '22023');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Otros ajustes', 'ajustes')$$,
  'Un libro tiene una sola cuenta Ajustes', '23505');
select pruebas.falla($$update public.fin_cuentas set tipo = 'banco'
  where id = pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'por_clasificar')$$,
  'Una cuenta de sistema no cambia de tipo', '22023');
select pruebas.falla($$update public.fin_cuentas set tipo = 'ahorro' where id = 'c3000000-0000-4000-8000-000000000001'$$,
  'Con movimientos, una cuenta no cambia de tipo', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set tipo = 'inversion'
  where id = 'c3000000-0000-4000-8000-000000000007'$$), 1, 'Sin movimientos sí');
select pruebas.igual(
  (select clase || ' ' || liquida from public.fin_cuentas where id = 'c3000000-0000-4000-8000-000000000007'),
  'activo false', 'clase y liquida se recalculan desde el tipo');
select pruebas.falla($$update public.fin_cuentas set libro_id = 'f1000000-0000-4000-8000-000000000001'
  where id = 'c3000000-0000-4000-8000-000000000007'$$, 'Una cuenta no cambia de libro', '42501');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', null, 'Banco suelto', 'banco')$$,
  'Un banco es de un libro', '23514');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Mascotas', 'de_gasto')$$,
  'Las cuentas de gasto son del hogar (D19)', '23514');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Banco de Ana', 'banco')$$,
  'Nombre único dentro del libro', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Banco de Ana', 'banco')$$), 1,
  'El mismo nombre en otro libro sí');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo, limite_centavos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Banco con límite', 'banco', 1000)$$,
  'El límite de crédito es solo de tarjetas', '23514');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo, estado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Nace cerrada', 'banco', 'cerrada')$$,
  'Una cuenta nace activa', '22023');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo, creada_por) values
  ('c3000000-0000-4000-8000-0000000000f4', 'b0000000-0000-4000-8000-000000000001',
   pruebas.libro_personal('ana@ejemplo.test'), 'Monedero', 'efectivo', pruebas.id_persona('alex@ejemplo.test'));
select pruebas.igual(
  (select creada_por from public.fin_cuentas where id = 'c3000000-0000-4000-8000-0000000000f4'),
  pruebas.id_persona('ana@ejemplo.test'), 'creada_por la pone el servidor aunque la app mande otra');

-- ---------------------------------------------------------------- categorías
select pruebas.falla($$delete from public.fin_categorias where id = 'c1000000-0000-4000-8000-000000000001'$$,
  'Una categoría con datos (subcategorías, cuenta) no se borra', '23503');
select pruebas.falla($$delete from public.fin_categorias where id = 'c1000000-0000-4000-8000-000000000011'$$,
  'Ni una con movimientos', '23503');
select pruebas.igual(pruebas.afecta($$delete from public.fin_categorias where id = 'c1000000-0000-4000-8000-000000000003'$$), 1,
  'Una sin datos sí se borra');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = true
  where id = 'c1000000-0000-4000-8000-000000000002'$$), 1, 'Con datos se archiva');
select pruebas.igual(pruebas.afecta($$insert into public.fin_categorias (id, hogar_id, padre_id, nivel, nombre)
  values ('c1000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001',
          'c1000000-0000-4000-8000-000000000002', 3, 'Lácteos')$$), 1, 'Tercer nivel bajo Súper');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, padre_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-0000000000f1', 4, 'Quesos')$$,
  'No hay cuarto nivel', '23514');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, padre_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 3, 'Salto')$$,
  'Una subcategoría va un nivel abajo de su categoría', '22023');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, padre_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', null, 2, 'Huérfana')$$, 'Sin padre es nivel 1', '23514');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, padre_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 2, 'Súper')$$,
  'Nombre único bajo la misma categoría', '23505');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 1, 'Alimentación')$$, 'También en el primer nivel', '23505');
select pruebas.falla($$update public.fin_categorias set padre_id = 'c1000000-0000-4000-8000-000000000005', nivel = 3
  where id = 'c1000000-0000-4000-8000-000000000002'$$, 'Una categoría con subcategorías no baja de nivel', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set padre_id = 'c1000000-0000-4000-8000-000000000011'
  where id = 'c1000000-0000-4000-8000-000000000002'$$), 1, 'Se mueve a otra categoría del mismo nivel');
select pruebas.falla($$update public.fin_categorias set cuenta_gasto_id = 'c3000000-0000-4000-8000-000000000001'
  where id = 'c1000000-0000-4000-8000-000000000011'$$, 'La cuenta de una categoría es de gasto', '22023');

-- D19 (23/oct/2026): archivar una categoría archiva su cuenta de gasto (cuando ya no queda otra
-- categoría activa que la use); desarchivarla la reactiva.
select pruebas.igual((select estado from public.fin_cuentas where id = 'c2000000-0000-4000-8000-000000000001'),
  'activa', 'Archivar la subcategoría Súper no archiva la cuenta de Alimentación (la usa otra categoría activa)');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = true
  where id = 'c1000000-0000-4000-8000-000000000001'$$), 1, 'Se archiva la categoría Alimentación');
select pruebas.igual((select estado from public.fin_cuentas where id = 'c2000000-0000-4000-8000-000000000001'),
  'archivada', 'Ya no queda ninguna categoría activa con esa cuenta: se archiva también la cuenta de gasto');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Y ya no admite gastos', '55000');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = false
  where id = 'c1000000-0000-4000-8000-000000000001'$$), 1, 'Se desarchiva la categoría');
select pruebas.igual((select estado from public.fin_cuentas where id = 'c2000000-0000-4000-8000-000000000001'),
  'activa', 'y su cuenta vuelve a estar activa');
select pruebas.ok(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 100) is not null,
  'Admite gastos otra vez');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = true
  where id = 'c1000000-0000-4000-8000-000000000011'$$), 1, 'Se archiva Transporte (cuenta propia, con movimientos)');
select pruebas.igual((select estado from public.fin_cuentas where id = 'c2000000-0000-4000-8000-000000000004'),
  'archivada', 'y su cuenta de gasto también (con saldo)');
-- La pareja también configura el hogar; la maestra no (M6).
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = false
  where id = 'c1000000-0000-4000-8000-000000000011'$$), 0, 'La cuenta maestra no desarchiva categorías');
select pruebas.igual((select estado from public.fin_cuentas where id = 'c2000000-0000-4000-8000-000000000004'),
  'archivada', 'ni se reactivan cuentas por esa vía');

rollback;
