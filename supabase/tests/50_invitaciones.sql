-- Invitaciones: solo las ve (y crea, y revoca) el dueño; se aceptan con el
-- token y el correo confirmado correcto; el token no se guarda en claro.
begin;

-- Solo el dueño las ve.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.invitaciones'), 1, 'El dueño ve las invitaciones de su hogar');
do $$
declare
  v_correo text;
begin
  foreach v_correo in array array['beto@ejemplo.test', 'carla@ejemplo.test', 'diana@ejemplo.test',
                                  'casa@ejemplo.test', 'elena@ejemplo.test', 'nuevo@ejemplo.test']
  loop
    perform pruebas.como(v_correo);
    perform pruebas.igual(pruebas.cuenta('select * from public.invitaciones'), 0,
      v_correo || ' no ve invitaciones');
  end loop;
end
$$;

-- Solo el dueño invita.
select pruebas.como('beto@ejemplo.test');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'alguien@ejemplo.test', 'familiar')$$, 'El coadministrador no invita', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'alguien@ejemplo.test', 'cuidador')$$, 'El cuidador no invita', '42501');
select pruebas.falla($$insert into public.invitaciones (hogar_id, correo, rol, token_hash, expira_en)
  values ('b0000000-0000-4000-8000-000000000001', 'x@ejemplo.test', 'familiar', repeat('a', 64), now())$$,
  'Nadie inserta invitaciones directo en la tabla', '42501');

-- El dueño invita; el token se entrega una vez y solo se guarda su hash.
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'otro.dueno@ejemplo.test', 'dueno')$$, 'No se invita con rol dueño', '22023');
select pruebas.falla($$select public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'x@ejemplo.test', 'jefe')$$, 'No se invita con un rol inexistente', '23514');

create temporary table inv on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
                                        '  Prima@Ejemplo.TEST ', 'cuidador', 3);
select pruebas.ok((select char_length(token) = 64 and token ~ '^[0-9a-f]+$' from inv),
  'El token tiene 64 caracteres hexadecimales');
select pruebas.igual(
  (select i.correo from public.invitaciones i join inv on inv.invitacion_id = i.id),
  'prima@ejemplo.test', 'El correo se guarda en minúsculas y sin espacios');
select pruebas.igual(
  (select i.token_hash from public.invitaciones i join inv on inv.invitacion_id = i.id),
  (select encode(sha256(convert_to(token, 'UTF8')), 'hex') from inv),
  'Se guarda el SHA-256 del token');
select pruebas.igual(
  pruebas.cuenta($$select * from public.invitaciones i, inv
                   where i.token_hash = inv.token or i.correo = inv.token$$), 0,
  'El token no se guarda en claro');
select pruebas.ok(
  (select i.expira_en between now() + interval '3 days' - interval '1 minute'
                         and now() + interval '3 days' + interval '1 minute'
     from public.invitaciones i join inv on inv.invitacion_id = i.id),
  'La invitación expira según la vigencia pedida');

-- Reinvitar al mismo correo revoca la anterior.
select public.crear_invitacion('b0000000-0000-4000-8000-000000000001', 'prima@ejemplo.test', 'cuidador');
select pruebas.igual(
  (select count(*)::int from public.invitaciones
    where correo = 'prima@ejemplo.test' and revocada_en is null and aceptada_en is null), 1,
  'Una sola invitación pendiente por correo');

-- Aceptar: la persona del correo invitado, con el token correcto.
select pruebas.como('nuevo@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion('token-equivocado')$$,
  'Un token equivocado no sirve', '22023');
select pruebas.igual(public.aceptar_invitacion('token-de-ejemplo-solo-local'),
  'b0000000-0000-4000-8000-000000000001'::uuid, 'Nuevo acepta su invitación');
select pruebas.igual(public.rol_en_hogar('b0000000-0000-4000-8000-000000000001'), 'familiar',
  'Nuevo entra con el rol invitado (familiar)');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 0,
  'Como familiar, Nuevo no ve dinero');
select pruebas.falla($$select public.aceptar_invitacion('token-de-ejemplo-solo-local')$$,
  'Una invitación aceptada no se reutiliza', '22023');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  exists (select 1 from public.invitaciones
           where id = 'd0000000-0000-4000-8000-000000000001'
             and aceptada_por = pruebas.id_persona('nuevo@ejemplo.test')),
  'El dueño ve quién aceptó la invitación');
select pruebas.ok(
  exists (select 1 from public.bitacora
           where tabla = 'membresias' and accion = 'insertar'
             and persona_id = pruebas.id_persona('nuevo@ejemplo.test')),
  'La nueva membresía queda en la bitácora');

-- Correo distinto: no sirve aunque tenga el token.
create temporary table inv2 on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
                                        'otra.persona@ejemplo.test', 'familiar');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv2))$$,
  'Con el token de otro correo no se entra', '42501');

-- Correo no confirmado: no sirve.
select pruebas.como_postgres();
grant select on inv2 to authenticated;
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at)
values ('a0000000-0000-4000-8000-0000000000b1', 'otra.persona@ejemplo.test', '{}', null);
select pruebas.como('otra.persona@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv2))$$,
  'Sin correo confirmado no se entra', '42501');

-- Expirada y revocada: no sirven.
select pruebas.como_postgres();
update auth.users set email_confirmed_at = now() where id = 'a0000000-0000-4000-8000-0000000000b1';
update public.invitaciones set expira_en = now() - interval '1 second'
 where correo = 'otra.persona@ejemplo.test' and aceptada_en is null and revocada_en is null;
select pruebas.como('otra.persona@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv2))$$,
  'Una invitación expirada no sirve', '22023');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.revocar_invitacion(
  (select invitacion_id from inv where true))$$), 1, 'El dueño revoca una invitación');
select pruebas.falla($$select public.revocar_invitacion((select invitacion_id from inv))$$,
  'No se revoca dos veces', '22023');

-- Quien ya pertenece al hogar no entra dos veces.
create temporary table inv3 on commit drop as
  select * from public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
                                        'carla@ejemplo.test', 'coadministrador');
grant select on inv3 to authenticated;
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.aceptar_invitacion((select token from inv3))$$,
  'Quien ya es miembro no se une otra vez', '23505');
select pruebas.igual(public.rol_en_hogar('b0000000-0000-4000-8000-000000000001'), 'familiar',
  'Su rol no cambia por aceptar otra invitación');

-- Sin sesión no se acepta nada.
select pruebas.como_anon();
select pruebas.falla($$select public.aceptar_invitacion('token-de-ejemplo-solo-local')$$,
  'Sin sesión no se aceptan invitaciones', '42501');

rollback;
