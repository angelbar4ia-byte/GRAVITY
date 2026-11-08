-- Google (Fase 6): cada persona ve solo su cuenta, nadie lee el token, el servidor escribe, el dueño aprueba a Casa.
-- Hogar Ejemplo: Ana dueña, Alex pareja, Carla familiar, Diana cuidadora, Casa.
begin;
select pruebas.como_servicio();
insert into public.google_cuentas (hogar_id, persona_id, ambito, correo, alcances, token_cifrado) values
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'),  'personal', 'ana@gmail.test',  array['gmail.readonly'], 'v1:aXY=:Y2lmcmFkbw=='),
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'personal', 'alex@gmail.test', array['gmail.readonly'], 'v1:aXY=:Y2lmcmFkbw=='),
  ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'),  'casa',     'casa@gmail.test', array['calendar.readonly'], 'v1:aXY=:Y2lmcmFkbw==');
select pruebas.falla($$insert into public.google_cuentas (hogar_id, persona_id, ambito, correo, alcances, token_cifrado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'personal', 'otra@gmail.test', array['x'], 'v1:aXY=:Y2k=')$$,
  'Una sola cuenta personal por persona', '23505');
select pruebas.falla($$insert into public.google_cuentas (hogar_id, persona_id, ambito, correo, alcances, token_cifrado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 'personal', 'c@gmail.test', array['x'], 'token en claro')$$,
  'El token solo se guarda en formato cifrado', '23514');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas$$), 2, 'Ana ve su cuenta y la de la casa que conectó');
select pruebas.falla($$select token_cifrado from public.google_cuentas$$, 'Ni la dueña lee el token desde la app', '42501');
select pruebas.falla($$select * from public.google_cuentas$$, 'select * tampoco (incluye el token)', '42501');
select pruebas.falla($$insert into public.google_cuentas (hogar_id, persona_id, ambito, correo, alcances, token_cifrado)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'personal', 'x@x.test', array['x'], 'v1:a:b')$$,
  'La app no escribe cuentas', '42501');
select pruebas.falla($$update public.google_cuentas set acceso_casa = true$$, 'La app no actualiza directo', '42501');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas$$), 1, 'Alex ve solo la suya');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas where correo = 'ana@gmail.test'$$), 0, 'Y no la de Ana');
select pruebas.falla($$select public.google_acceso_casa('b0000000-0000-4000-8000-000000000001', true)$$,
  'La pareja no aprueba el acceso de Casa', '42501');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas$$), 0, 'Carla no conectó nada: no ve nada');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas$$), 0, 'La cuidadora no ve cuentas');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas$$), 0, 'Casa tampoco lee la fila (el servidor decide)');
select pruebas.falla($$select public.google_acceso_casa('b0000000-0000-4000-8000-000000000001', true)$$, 'Casa no se aprueba sola', '42501');

select pruebas.como('ana@ejemplo.test');
select public.google_acceso_casa('b0000000-0000-4000-8000-000000000001', true);
select pruebas.ok((select acceso_casa from public.google_cuentas where ambito = 'casa'), 'El dueño aprueba a Casa');
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'google.acceso_casa'), 1, 'Queda en la bitácora');
select public.google_acceso_casa('b0000000-0000-4000-8000-000000000001', false);
select pruebas.ok(not (select acceso_casa from public.google_cuentas where ambito = 'casa'), 'Y la puede quitar');

select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.google_desconectar('b0000000-0000-4000-8000-000000000001', 'casa')$$, 'La pareja no quita la cuenta de la casa', '42501');
select public.google_desconectar('b0000000-0000-4000-8000-000000000001', 'personal');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas$$), 0, 'Alex desconecta la suya');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas where ambito = 'personal'$$), 1, 'La de Ana sigue');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(public.google_desconectar('b0000000-0000-4000-8000-000000000001', 'personal') is null, true, 'Casa no borra cuentas ajenas (no hay fila propia)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select id from public.google_cuentas where ambito = 'personal'$$), 1, 'La de Ana sigue');
rollback;
