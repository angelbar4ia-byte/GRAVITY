-- Aislamiento entre hogares: una persona de otro hogar no ve ni toca nada.
-- Elena es dueña del Hogar Vecino; Ana es dueña del Hogar Ejemplo.
begin;

select pruebas.como('elena@ejemplo.test');
select pruebas.igual(public.rol_en_hogar('b0000000-0000-4000-8000-000000000001'), null::text,
  'Elena no tiene rol en el Hogar Ejemplo');
select pruebas.igual(
  (select count(*)::int from public.mis_permisos('b0000000-0000-4000-8000-000000000001')), 0,
  'Elena no tiene permisos en el Hogar Ejemplo');

-- Lectura: de cada tabla, solo lo de su propio hogar o lo suyo.
select pruebas.igual(pruebas.cuenta($$select * from public.hogares
  where id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve el hogar ajeno');
select pruebas.igual(pruebas.cuenta('select * from public.hogares'), 1, 'Ve solo su hogar');
select pruebas.igual(pruebas.cuenta('select * from public.personas'), 1,
  'Solo se ve a sí misma (no ve a las personas del hogar ajeno)');
select pruebas.igual(pruebas.cuenta($$select * from public.membresias
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve membresías del hogar ajeno');
select pruebas.igual(pruebas.cuenta('select * from public.invitaciones'), 0, 'No ve invitaciones ajenas');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve dinero del hogar ajeno');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 2, 'Ve el dinero de su hogar (2 movimientos)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve libros del hogar ajeno');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve cuentas ni categorías de gasto del hogar ajeno');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_categorias
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve el árbol de categorías del hogar ajeno');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_v_saldos
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve saldos del hogar ajeno');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                  and not public.fin_puede_hogar('b0000000-0000-4000-8000-000000000001', 'leer'),
  'fin_puede() y fin_puede_hogar(): nada en el hogar ajeno');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve la bitácora del hogar ajeno');
select pruebas.igual(pruebas.cuenta('select * from public.dispositivos'), 0, 'No ve dispositivos ajenos');

-- Escritura sobre el hogar ajeno: nada.
select pruebas.falla($$
  select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 100)$$,
  'No registra dinero en el hogar ajeno (con cuentas de ese hogar)', '42501');
select pruebas.falla($$
  select pruebas.registrar('gasto', 'c7000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 100,
                           p_hogar => 'b0000000-0000-4000-8000-000000000002')$$,
  'No mezcla una cuenta suya con una del hogar ajeno', '23503');
select pruebas.igual(pruebas.afecta($$
  update public.fin_cuentas set nombre = 'Tomada'
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No cambia cuentas ajenas');
select pruebas.falla($$
  insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          pruebas.id_persona('elena@ejemplo.test'), 'miembro')$$,
  'No se mete a un libro compartido del hogar ajeno', '42501');
select pruebas.igual(pruebas.afecta($$
  update public.hogares set nombre = 'Tomado'
  where id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No renombra el hogar ajeno');
select pruebas.igual(pruebas.afecta($$
  update public.membresias set rol = 'familiar'
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No cambia roles del hogar ajeno');
select pruebas.falla($$
  select public.crear_invitacion('b0000000-0000-4000-8000-000000000001', 'yo@ejemplo.test', 'coadministrador')$$,
  'No se invita sola al hogar ajeno', '42501');
select pruebas.falla($$
  select public.revocar_invitacion('d0000000-0000-4000-8000-000000000001')$$,
  'No revoca invitaciones del hogar ajeno', '22023');

-- Y al revés: la dueña del Hogar Ejemplo no ve el Hogar Vecino.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hogares
  where id = 'b0000000-0000-4000-8000-000000000002'$$), 0, 'Ana no ve el Hogar Vecino');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where hogar_id = 'b0000000-0000-4000-8000-000000000002'$$), 0, 'Ana no ve el dinero del Hogar Vecino');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where hogar_id = 'b0000000-0000-4000-8000-000000000002'$$), 0, 'Ana no ve las cuentas del Hogar Vecino');
select pruebas.igual(pruebas.cuenta($$select * from public.personas
  where id = pruebas.id_persona('elena@ejemplo.test')$$), 0, 'Ana no ve a Elena');

-- Sin hogar: una cuenta nueva no ve nada de nadie.
select pruebas.como('nuevo@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta('select * from public.hogares')
  + pruebas.cuenta('select * from public.membresias')
  + pruebas.cuenta('select * from public.invitaciones')
  + pruebas.cuenta('select * from public.fin_movimientos')
  + pruebas.cuenta('select * from public.fin_libros')
  + pruebas.cuenta('select * from public.fin_cuentas')
  + pruebas.cuenta('select * from public.bitacora')
  + pruebas.cuenta('select * from public.dispositivos'), 0,
  'Una cuenta sin hogar no ve hogares, dinero, invitaciones, bitácora ni dispositivos');
select pruebas.igual(pruebas.cuenta('select * from public.personas'), 1,
  'Una cuenta sin hogar solo se ve a sí misma');

rollback;
