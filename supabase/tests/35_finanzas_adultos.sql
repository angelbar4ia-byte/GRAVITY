-- fin_adultos_con_finanzas(hogar) (2.ª ronda del 23/oct/2026, D19): los adultos con
-- Finanzas del hogar (dueño y coadministradores vigentes), para agregarlos a un
-- compartido. Nunca devuelve familiares, cuidadores, casa ni la cuenta maestra que no
-- es la dueña. La ve cualquier adulto con Finanzas del hogar; nadie más.
begin;

-- Un tercer adulto con Finanzas.
select pruebas.nuevo_adulto('teo@ejemplo.test', 'Teo Ejemplo');

-- ---------------------------------------------------------------- la dueña
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 3,
  'La dueña ve 3 adultos con Finanzas: ella, Alex y Teo');
select pruebas.ok(
  (select array_agg(f.persona_id order by f.persona_id)
     from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f)
  = (select array_agg(i order by i) from unnest(array[
       pruebas.id_persona('ana@ejemplo.test'), pruebas.id_persona('alex@ejemplo.test'),
       pruebas.id_persona('teo@ejemplo.test')]) as i),
  'Son exactamente Ana, Alex y Teo');
select pruebas.igual(
  (select string_agg(f.rol, ',' order by f.rol, f.nombre_visible)
     from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f),
  'coadministrador,coadministrador,dueno', 'Con su rol: la dueña y dos coadministradores');
select pruebas.igual(
  (select f.nombre_visible from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f
    where f.persona_id = pruebas.id_persona('alex@ejemplo.test')),
  'Alex Ejemplo', 'Devuelve el nombre visible');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f
  where f.persona_id in (pruebas.id_persona('marta@ejemplo.test'), pruebas.id_persona('carla@ejemplo.test'),
                         pruebas.id_persona('diana@ejemplo.test'), pruebas.id_persona('casa@ejemplo.test'))$$), 0,
  'Nunca la cuenta maestra, ni la familiar, ni la cuidadora, ni la cuenta Casa');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f
  where f.persona_id = 'e0000000-0000-4000-8000-000000000001'$$), 0,
  'Ni Papá (persona sin cuenta ni membresía)');

-- ---------------------------------------------------------------- la pareja y el tercer adulto
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 3,
  'Alex (coadministrador) ve los mismos 3');
select pruebas.como('teo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 3,
  'Teo también');

-- ---------------------------------------------------------------- la cuenta maestra
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 3,
  'La maestra (adulta con Finanzas, solo lectura) la ve; no aparece ella misma');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f
  where f.persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 0,
  'La lista no la incluye a ella');

-- ---------------------------------------------------------------- roles sin Finanzas
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 0,
  'La familiar no ve nada (sin error)');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 0,
  'La cuidadora no ve nada');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 0,
  'La cuenta Casa no ve nada');

-- ---------------------------------------------------------------- otros hogares y sin hogar
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 0,
  'La dueña de otro hogar no ve a los de este');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000002')$$), 1,
  'En su propio hogar solo está ella');
select pruebas.como('nuevo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 0,
  'Quien no tiene hogar tampoco');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas(null)$$), 0,
  'Con hogar nulo no devuelve nada');

-- ---------------------------------------------------------------- sin sesión y sin permiso de ejecución
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$,
  'Sin sesión (anon) no se ejecuta', '42501');
select pruebas.como_servicio();
select pruebas.falla($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$,
  'service_role tampoco: es solo de la API de las personas con sesión', '42501');
select pruebas.como_postgres();
select pruebas.ok(has_function_privilege('authenticated', 'public.fin_adultos_con_finanzas(uuid)', 'execute')
                  and not has_function_privilege('anon', 'public.fin_adultos_con_finanzas(uuid)', 'execute')
                  and not has_function_privilege('service_role', 'public.fin_adultos_con_finanzas(uuid)', 'execute'),
  'Solo authenticated la ejecuta');

-- ---------------------------------------------------------------- bajas y cambios de rol
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('teo@ejemplo.test');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 2,
  'Quien se dio de baja del hogar deja de aparecer');
select pruebas.como('teo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 0,
  'y él ya no la ve');
select pruebas.como_postgres();
update public.membresias set rol = 'familiar' where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 1,
  'Quien pasa a familiar sale de la lista (queda la dueña)');
select pruebas.como_postgres();
update public.membresias set rol = 'coadministrador' where persona_id = pruebas.id_persona('alex@ejemplo.test');

-- ---------------------------------------------------------------- la dueña, además, cuenta maestra
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f
  where f.persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 1,
  'La dueña, aunque además sea la cuenta maestra, aparece (ella sí escribe)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001')$$), 3,
  'Ana, Alex y Marta: al dejar de ser la maestra, Marta es una coadministradora con Finanzas');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_adultos_con_finanzas('b0000000-0000-4000-8000-000000000001') f
  where f.persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 1,
  'y entonces sí aparece');

rollback;
