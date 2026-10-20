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
select pruebas.igual(pruebas.cuenta($$select * from public.finanzas_muestra
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve dinero del hogar ajeno');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 1, 'Ve el dinero de su hogar');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No ve la bitácora del hogar ajeno');
select pruebas.igual(pruebas.cuenta('select * from public.dispositivos'), 0, 'No ve dispositivos ajenos');

-- Escritura sobre el hogar ajeno: nada.
select pruebas.falla($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Intrusión', 1)$$,
  'No registra dinero en el hogar ajeno', '42501');
select pruebas.igual(pruebas.afecta($$
  update public.finanzas_muestra set monto_centavos = 0
  where hogar_id = 'b0000000-0000-4000-8000-000000000001'$$), 0, 'No cambia dinero ajeno');
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
select pruebas.igual(pruebas.cuenta($$select * from public.finanzas_muestra
  where hogar_id = 'b0000000-0000-4000-8000-000000000002'$$), 0, 'Ana no ve el dinero del Hogar Vecino');
select pruebas.igual(pruebas.cuenta($$select * from public.personas
  where id = pruebas.id_persona('elena@ejemplo.test')$$), 0, 'Ana no ve a Elena');

-- Sin hogar: una cuenta nueva no ve nada de nadie.
select pruebas.como('nuevo@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta('select * from public.hogares')
  + pruebas.cuenta('select * from public.membresias')
  + pruebas.cuenta('select * from public.invitaciones')
  + pruebas.cuenta('select * from public.finanzas_muestra')
  + pruebas.cuenta('select * from public.bitacora')
  + pruebas.cuenta('select * from public.dispositivos'), 0,
  'Una cuenta sin hogar no ve hogares, dinero, invitaciones, bitácora ni dispositivos');
select pruebas.igual(pruebas.cuenta('select * from public.personas'), 1,
  'Una cuenta sin hogar solo se ve a sí misma');

rollback;
