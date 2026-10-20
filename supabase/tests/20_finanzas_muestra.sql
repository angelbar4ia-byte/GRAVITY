-- La regla del dinero (D3, D5), comprobada en el servidor con finanzas_muestra:
-- dueño lee y escribe; coadministrador solo lee; familiar, cuidador y casa no ven nada.
begin;

-- ---------------------------------------------------------------- dueño
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 2,
  'Dueño lee el dinero de su hogar (2 filas)');
select pruebas.ok(public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'escribir'),
  'puede(): dueño escribe Finanzas');
select pruebas.igual(pruebas.afecta($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Gasto de prueba', 10000)$$), 1,
  'Dueño registra un gasto');
select pruebas.igual(
  (select registrado_por from public.finanzas_muestra where descripcion = 'Gasto de prueba'),
  pruebas.id_persona('ana@ejemplo.test'),
  'registrado_por lo pone el servidor (persona de la sesión)');
select pruebas.falla($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos, registrado_por)
  values ('b0000000-0000-4000-8000-000000000001', 'A nombre de otro', 1,
          pruebas.id_persona('beto@ejemplo.test'))$$,
  'Nadie registra a nombre de otra persona', '42501');
select pruebas.igual(pruebas.afecta($$
  update public.finanzas_muestra set monto_centavos = 43000
  where id = 'c0000000-0000-4000-8000-000000000002'$$), 1,
  'Dueño corrige un monto');
select pruebas.igual(pruebas.afecta($$
  delete from public.finanzas_muestra where descripcion = 'Gasto de prueba'$$), 1,
  'Dueño borra en la muestra (la Fase 1 usará libro solo-agregar)');
select pruebas.ok(
  exists (select 1 from public.bitacora
           where tabla = 'finanzas_muestra' and accion = 'actualizar'
             and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'Cada cambio de dinero queda en la bitácora con quién lo hizo');

-- ---------------------------------------------------------------- coadministrador
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 2,
  'Coadministrador lee el dinero del hogar');
select pruebas.ok(not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'escribir'),
  'puede(): coadministrador no escribe Finanzas');
select pruebas.falla($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Intento', 100)$$,
  'Coadministrador no registra dinero', '42501');
select pruebas.igual(pruebas.afecta($$
  update public.finanzas_muestra set monto_centavos = 1$$), 0,
  'Coadministrador no cambia montos');
select pruebas.igual(pruebas.afecta($$delete from public.finanzas_muestra$$), 0,
  'Coadministrador no borra dinero');

-- ---------------------------------------------------------------- familiar, cuidador y casa
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 0, 'Familiar NO lee dinero');
select pruebas.ok(not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer'),
  'puede(): familiar sin lectura de Finanzas');
select pruebas.falla($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Intento', 100)$$,
  'Familiar no registra dinero', '42501');
select pruebas.igual(pruebas.afecta('update public.finanzas_muestra set monto_centavos = 1'), 0,
  'Familiar no cambia montos');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where tabla = 'finanzas_muestra'$$), 0,
  'Familiar no ve el dinero por la bitácora');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 0, 'Cuidador NO lee dinero');
select pruebas.ok(not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer'),
  'puede(): cuidador sin lectura de Finanzas');
select pruebas.ok(not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'escribir'),
  'puede(): cuidador sin escritura total (los gastos de cuidado llegan en la Fase 5)');
select pruebas.falla($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Intento', 100)$$,
  'Cuidador no registra en Finanzas', '42501');
select pruebas.igual(pruebas.afecta('delete from public.finanzas_muestra'), 0, 'Cuidador no borra dinero');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where tabla = 'finanzas_muestra'$$), 0,
  'Cuidador no ve el dinero por la bitácora');

select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 0, 'Casa NO lee dinero');
select pruebas.ok(not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer'),
  'puede(): casa sin lectura de Finanzas');
select pruebas.falla($$
  insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'Intento', 100)$$,
  'Casa no registra dinero', '42501');
select pruebas.igual(pruebas.afecta('update public.finanzas_muestra set monto_centavos = 1'), 0,
  'Casa no cambia montos');

-- La baja quita el acceso al dinero de inmediato (el coadministrador deja de leer).
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$
  update public.membresias set activa = false, hasta = now()
  where persona_id = pruebas.id_persona('beto@ejemplo.test')$$), 1,
  'Dueño da de baja al coadministrador');
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 0,
  'Dado de baja, ya no lee dinero');

rollback;
