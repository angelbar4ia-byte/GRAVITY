-- Cuenta maestra con login propio (decisión del dueño del 23/oct/2026, D19):
-- la crea el dueño con una invitación; es OTRA persona (rol coadministrador +
-- es_maestra) sin libro propio; si no es la dueña es solo lectura total en
-- Finanzas; y en este paso no ve nada de Cuidados ni de Hábitos de otros.
begin;

-- La persona que será la nueva cuenta maestra se registra con su correo (confirmado).
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('a0000000-0000-4000-8000-0000000000c1', 'maestra2@ejemplo.test', '{"nombre": "Cuenta Maestra Nueva"}', now()),
  ('a0000000-0000-4000-8000-0000000000c2', 'sin.confirmar@ejemplo.test', '{}', null);

-- ---------------------------------------------------------------- crear la invitación
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'maestra2@ejemplo.test', 'coadministrador', 7, true)$$,
  'Solo el dueño invita a la cuenta maestra (la pareja no)', '42501');

select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'maestra2@ejemplo.test', 'familiar', 7, true)$$,
  'La cuenta maestra se invita con el rol coadministrador', '22023');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'maestra2@ejemplo.test', 'dueno', 7, true)$$,
  'Nunca con el rol dueño', '22023');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'alex@ejemplo.test', 'coadministrador', 7, true)$$,
  'No se invita a un miembro del hogar: la maestra es otra persona con su propio login', '22023');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'ANA@Ejemplo.test', 'coadministrador', 7, true)$$,
  'Ni al correo del propio dueño (aunque lo escriba distinto)', '22023');

-- La firma de 4 parámetros sigue funcionando y no crea una maestra.
create temporary table inv_normal on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001', 'tio@ejemplo.test', 'coadministrador', 7);
select pruebas.igual((select i.es_maestra from public.invitaciones i join inv_normal n on n.invitacion_id = i.id),
  false, 'Una invitación normal de coadministrador no es de cuenta maestra');

create temporary table inv on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001', '  Maestra2@Ejemplo.TEST ',
                                        'coadministrador', 7, true);
select pruebas.ok((select char_length(token) = 64 from inv), 'El token sale una vez (64 hexadecimales)');
select pruebas.ok(
  (select i.es_maestra and i.rol = 'coadministrador' and i.correo = 'maestra2@ejemplo.test'
     from public.invitaciones i join inv on inv.invitacion_id = i.id),
  'La invitación queda marcada como de cuenta maestra (correo en minúsculas)');
select pruebas.igual(
  (select count(*)::int from public.invitaciones i where i.es_maestra and i.aceptada_en is null and i.revocada_en is null), 1,
  'El dueño ve la invitación pendiente de cuenta maestra');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.invitaciones where es_maestra'), 0,
  'La pareja no ve las invitaciones');

-- Una pendiente por correo: reinvitar revoca la anterior.
select pruebas.como('ana@ejemplo.test');
create temporary table inv_nueva on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001', 'maestra2@ejemplo.test',
                                        'coadministrador', 7, true);
select pruebas.ok((select i.revocada_en is not null from public.invitaciones i join inv on inv.invitacion_id = i.id),
  'Reinvitar al mismo correo revoca la anterior');
select pruebas.como_postgres();
grant select on inv, inv_nueva to authenticated;

-- ---------------------------------------------------------------- aceptarla
select pruebas.como('maestra2@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv))$$,
  'La invitación revocada no sirve', '22023');
select pruebas.como('sin.confirmar@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv_nueva))$$,
  'Con otro correo (sin confirmar) no se acepta', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv_nueva))$$,
  'Con el token de otra persona no se entra', '42501');

select pruebas.como('maestra2@ejemplo.test');
select pruebas.igual(public.aceptar_invitacion((select token from inv_nueva)),
  'b0000000-0000-4000-8000-000000000001'::uuid, 'La persona invitada acepta y recibe el hogar');
select pruebas.igual(public.rol_en_hogar('b0000000-0000-4000-8000-000000000001'), 'coadministrador',
  'Entra como coadministrador');
select pruebas.ok(public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
  'y como cuenta maestra');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv_nueva))$$,
  'La invitación aceptada no se reutiliza', '22023');
select pruebas.igual((select count(*)::int from public.fin_libros where titular_id = pruebas.id_persona('maestra2@ejemplo.test')), 0,
  'NO se le crea libro personal');
select pruebas.igual((select count(*)::int from public.fin_cuentas c join public.fin_libros l on l.id = c.libro_id
                       where l.titular_id = pruebas.id_persona('maestra2@ejemplo.test')), 0,
  'ni cuentas de sistema, ni parámetros');

-- La anterior (Marta) dejó de serlo; queda en la bitácora para todo adulto con Finanzas.
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
  'Marta (la maestra anterior) ya no lo es: una sola por hogar');
select pruebas.igual(
  (select detalle ->> 'anterior_persona_id' || ' > ' || (detalle ->> 'nueva_persona_id') || ' por ' || (detalle ->> 'invitada_por')
     from public.bitacora where accion = 'finanzas.maestra_asignada'),
  pruebas.id_persona('marta@ejemplo.test')::text || ' > ' || pruebas.id_persona('maestra2@ejemplo.test')::text
    || ' por ' || pruebas.id_persona('ana@ejemplo.test')::text,
  'La entrada dice quién era, quién es y quién la invitó');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 1,
  'La pareja ve el cambio');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 0,
  'Una familiar no');
select pruebas.igual((select nombre_visible from public.cuenta_maestra('b0000000-0000-4000-8000-000000000001')),
  'Cuenta Maestra Nueva', 'Ajustes › Privacidad: todos ven quién es la cuenta maestra');

-- ---------------------------------------------------------------- solo lectura total y sin libro
select pruebas.como('maestra2@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 4,
  'Ve la portada de los 4 libros del hogar; no lleva uno');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 0, 'Sin consulta no lee el contenido');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')),
  'Registra su consulta al libro de Ana');
select pruebas.ok(public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'leer'),
  'Y lo lee 30 minutos');
select pruebas.ok(
  not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'escribir')
  and not public.fin_puede(pruebas.libro_personal('ana@ejemplo.test'), 'administrar')
  and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir')
  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
  and not public.fin_puede_hogar('b0000000-0000-4000-8000-000000000001', 'escribir')
  and not public.fin_puede_hogar('b0000000-0000-4000-8000-000000000001', 'administrar')
  and public.fin_solo_lectura('b0000000-0000-4000-8000-000000000001'),
  'En ningún libro (ni en lo del hogar) escribe ni administra');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Registrar un gasto: 42501', '42501');
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo, titular_id)
  values ('b0000000-0000-4000-8000-000000000001', 'Mi libro', 'personal', pruebas.id_persona('maestra2@ejemplo.test'))$$,
  'Crear su libro personal: 42501', '42501');
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'Un compartido', 'compartido')$$,
  'Crear un compartido: 42501', '42501');
select pruebas.falla($$insert into public.fin_categorias (hogar_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 1, 'Nueva')$$, 'Crear una categoría del hogar: 42501', '42501');

-- ---------------------------------------------------------------- no entra a Cuidados ni a Hábitos de otros
select pruebas.ok(
  not public.puede('b0000000-0000-4000-8000-000000000001', 'cuidados', 'leer')
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'cuidados', 'escribir')
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'cuidados', 'administrar')
  and public.alcance('b0000000-0000-4000-8000-000000000001', 'cuidados', 'leer') = 'restringido',
  'Cuidados: sin acceso (restringido hasta que exista el consentimiento, Fase 5)');
select pruebas.ok(
  not public.puede('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer')
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer', pruebas.id_persona('ana@ejemplo.test'))
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'escribir', pruebas.id_persona('alex@ejemplo.test'))
  and public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer', pruebas.id_persona('maestra2@ejemplo.test')),
  'Hábitos: solo lo suyo (alcance propio); nada de nadie más');
select pruebas.igual(
  (select count(*)::int from public.mis_permisos('b0000000-0000-4000-8000-000000000001')
    where modulo in ('cuidados', 'habitos') and alcance = 'total'), 0,
  'Ningún permiso de Cuidados ni de Hábitos con alcance total');
select pruebas.ok(
  not public.puede('b0000000-0000-4000-8000-000000000001', 'ajustes', 'administrar')
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer'),
  'Tampoco administra Ajustes ni lee el GRAVITY de otros');
select pruebas.igual(pruebas.cuenta('select * from public.invitaciones'), 0, 'No ve las invitaciones');
select pruebas.igual(pruebas.cuenta($$select * from public.dispositivos$$), 0, 'Ni los dispositivos de otros');

-- ---------------------------------------------------------------- no cambia a un rol sin Finanzas ni se vuelve dueña
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.membresias set rol = 'familiar'
  where persona_id = pruebas.id_persona('maestra2@ejemplo.test')$$,
  'La cuenta maestra no pasa a un rol sin Finanzas', '23514');
select pruebas.falla($$update public.membresias set rol = 'dueno'
  where persona_id = pruebas.id_persona('maestra2@ejemplo.test')$$,
  'Ni se nombra otro dueño', '42501');
select pruebas.falla($$update public.membresias set es_maestra = false
  where persona_id = pruebas.id_persona('maestra2@ejemplo.test')$$,
  'La marca solo se cambia con asignar_cuenta_maestra()', '42501');

-- ---------------------------------------------------------------- asignar a mano
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'));
select pruebas.ok(
  (select es_maestra from public.membresias where persona_id = pruebas.id_persona('marta@ejemplo.test')
     and hogar_id = 'b0000000-0000-4000-8000-000000000001'),
  'Se puede volver a nombrar a una coadministradora que no lleva libro propio (Marta)');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('alex@ejemplo.test'))$$,
  'Pero no a quien lleva su libro (Alex): la maestra es solo lectura', '22023');
-- La dueña, con su persona, puede serlo; luego una invitación de cuenta maestra la releva.
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.ok(public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001')
                  and not public.fin_solo_lectura('b0000000-0000-4000-8000-000000000001'),
  'La dueña es además la maestra con su propia persona: en lo suyo sigue escribiendo');
create temporary table inv3 on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001', 'maestra3@ejemplo.test',
                                        'coadministrador', 3, true);
select pruebas.como_postgres();
grant select on inv3 to authenticated;
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at)
values ('a0000000-0000-4000-8000-0000000000c3', 'maestra3@ejemplo.test', '{}', now());
select pruebas.como('maestra3@ejemplo.test');
select public.aceptar_invitacion((select token from inv3));
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
  'Al aceptar la nueva invitación, la dueña (que era la maestra) deja de serlo');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.maestra_asignada'$$), 4,
  'y cada cambio de cuenta maestra quedó anotado');

-- ---------------------------------------------------------------- vencida
select pruebas.como_postgres();
update public.invitaciones set expira_en = now() - interval '1 second' where es_maestra and aceptada_en is null;
select pruebas.como('ana@ejemplo.test');
create temporary table inv4 on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001', 'maestra4@ejemplo.test',
                                        'coadministrador', 1, true);
select pruebas.como_postgres();
grant select on inv4 to authenticated;
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at)
values ('a0000000-0000-4000-8000-0000000000c4', 'maestra4@ejemplo.test', '{}', now());
update public.invitaciones set expira_en = now() - interval '1 second' where correo = 'maestra4@ejemplo.test';
select pruebas.como('maestra4@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv4))$$,
  'Una invitación de cuenta maestra vencida no sirve', '22023');

rollback;
