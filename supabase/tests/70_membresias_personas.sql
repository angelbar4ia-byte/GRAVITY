-- Personas, membresías y dispositivos: el cuidador no ve a la familia; el dueño
-- administra roles y bajas; la baja quita el acceso de inmediato.
begin;

-- ---------------------------------------------------------------- quién ve a quién
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.personas'), 5,
  'El dueño ve a las 5 personas de su hogar');
select pruebas.igual(pruebas.cuenta('select * from public.membresias'), 5,
  'El dueño ve las 5 membresías de su hogar');

do $$
declare
  v_correo text;
begin
  foreach v_correo in array array['beto@ejemplo.test', 'carla@ejemplo.test',
                                  'diana@ejemplo.test', 'casa@ejemplo.test']
  loop
    perform pruebas.como(v_correo);
    perform pruebas.igual(pruebas.cuenta('select * from public.personas'), 1,
      v_correo || ' solo se ve a sí mismo en personas');
    perform pruebas.igual(pruebas.cuenta('select * from public.membresias'), 1,
      v_correo || ' solo ve su membresía');
    perform pruebas.igual(pruebas.cuenta('select * from public.hogares'), 1,
      v_correo || ' ve su hogar');
  end loop;
end
$$;

-- ---------------------------------------------------------------- cuidador: solo Cuidados
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(
  (select string_agg(modulo || ':' || accion || '=' || alcance, ', ' order by modulo, accion)
     from public.mis_permisos('b0000000-0000-4000-8000-000000000001')),
  'ajustes:escribir=propio, ajustes:leer=propio, alimentacion:leer=restringido, casa:leer=total, '
  'cuidados:escribir=restringido, cuidados:leer=restringido, finanzas:escribir=restringido',
  'Cuidador: Cuidados de su turno, comidas de la persona bajo cuidado, Casa y lo propio; nada de familia ni GRAVITY');
select pruebas.ok(
  not public.puede('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer')
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer',
                             pruebas.id_persona('carla@ejemplo.test'))
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'alimentacion', 'leer')
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'ajustes', 'leer'),
  'Cuidador: sin Hábitos, sin Alimentación completa y sin Ajustes del hogar');
select pruebas.ok(
  public.alcance('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer') is null
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer',
                             pruebas.id_persona('diana@ejemplo.test'))
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'gravity', 'escribir',
                             pruebas.id_persona('diana@ejemplo.test')),
  'I1: Cuidador: sin GRAVITY, ni siquiera lo propio');
select pruebas.ok(
  not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer')
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer',
                             pruebas.id_persona('diana@ejemplo.test'))
  and public.alcance('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer') is null,
  'I1: Cuidador: no lee Finanzas, ni lo que él registra');

-- ---------------------------------------------------------------- coadministrador y dueño (I1)
select pruebas.como('beto@ejemplo.test');
select pruebas.ok(
  public.alcance('b0000000-0000-4000-8000-000000000001', 'cuidados', 'leer') = 'restringido'
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'cuidados', 'leer')
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'cuidados', 'escribir')
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'cuidados', 'leer',
                             pruebas.id_persona('beto@ejemplo.test'))
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'cuidados', 'escribir',
                             pruebas.id_persona('beto@ejemplo.test')),
  'I1: Coadministrador: sin acceso a Cuidados hasta que exista el consentimiento (Fase 5)');
select pruebas.ok(
  public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer',
                     pruebas.id_persona('beto@ejemplo.test'))
  and not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer',
                             pruebas.id_persona('ana@ejemplo.test')),
  'Coadministrador: GRAVITY lo propio, no lo de otros');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  public.puede('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer')
  and public.puede('b0000000-0000-4000-8000-000000000001', 'gravity', 'escribir')
  and public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'gravity', 'leer',
                         pruebas.id_persona('carla@ejemplo.test')),
  'I1: Dueño: GRAVITY total');

-- ---------------------------------------------------------------- lo propio (puede_sobre)
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(
  public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer',
                     pruebas.id_persona('carla@ejemplo.test')),
  'Familiar: lee sus propios Hábitos');
select pruebas.ok(
  not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer',
                         pruebas.id_persona('ana@ejemplo.test')),
  'Familiar: no lee los Hábitos de otra persona');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  not public.puede_sobre('b0000000-0000-4000-8000-000000000001', 'habitos', 'leer',
                         pruebas.id_persona('carla@ejemplo.test')),
  'Dueño: tampoco lee los Hábitos de otra persona (D13)');

-- ---------------------------------------------------------------- roles y bajas
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.membresias set rol = 'casa'
  where persona_id = pruebas.id_persona('carla@ejemplo.test')$$), 0,
  'El coadministrador no cambia roles');

select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.membresias (hogar_id, persona_id, rol)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('elena@ejemplo.test'), 'familiar')$$,
  'Nadie agrega membresías directo (solo por invitación)', '42501');
select pruebas.falla($$update public.membresias set rol = 'dueno'
  where persona_id = pruebas.id_persona('beto@ejemplo.test')$$,
  'El dueño no nombra a otro dueño', '42501');
select pruebas.igual(pruebas.afecta($$update public.membresias set activa = false
  where persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0,
  'El dueño no se da de baja ni se cambia el rol a sí mismo');
select pruebas.falla($$update public.membresias set persona_id = pruebas.id_persona('elena@ejemplo.test')
  where persona_id = pruebas.id_persona('carla@ejemplo.test')$$,
  'Nadie cambia a quién pertenece una membresía', '42501');
select pruebas.falla('delete from public.membresias', 'Las membresías no se borran', '42501');

select pruebas.igual(pruebas.afecta($$update public.membresias set rol = 'familiar'
  where persona_id = pruebas.id_persona('beto@ejemplo.test')$$), 1,
  'El dueño cambia el rol del coadministrador a familiar');
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.finanzas_muestra'), 0,
  'Con el rol nuevo deja de ver el dinero al instante');

-- Baja de la cuidadora (D5): pierde el acceso; lo que hizo queda con su nombre.
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  values ('b0000000-0000-4000-8000-000000000001', 'entrega_de_turno')$$), 1,
  'La cuidadora registra una entrega de turno');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.membresias set activa = false, hasta = now()
  where persona_id = pruebas.id_persona('diana@ejemplo.test')$$), 1,
  'El dueño da de baja a la cuidadora');
select pruebas.como('diana@ejemplo.test');
select pruebas.ok(
  public.rol_en_hogar('b0000000-0000-4000-8000-000000000001') is null
  and pruebas.cuenta('select * from public.hogares') = 0
  and (select count(*) from public.mis_permisos('b0000000-0000-4000-8000-000000000001')) = 0,
  'Dada de baja, la cuidadora pierde el acceso de inmediato');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion)
  values ('b0000000-0000-4000-8000-000000000001', 'despues_de_la_baja')$$,
  'Dada de baja, ya no registra en el hogar', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  exists (select 1 from public.bitacora b join public.personas p on p.id = b.persona_id
           where b.accion = 'entrega_de_turno' and p.nombre_visible = 'Diana Cuidadora'),
  'Lo que registró queda en la bitácora con su nombre');

-- Membresía con fecha de fin vencida: tampoco da acceso.
select pruebas.como_postgres();
update public.membresias set hasta = now() - interval '1 minute', desde = now() - interval '1 day'
 where persona_id = pruebas.id_persona('casa@ejemplo.test');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(public.rol_en_hogar('b0000000-0000-4000-8000-000000000001'), null::text,
  'Una membresía con fecha de fin vencida no da acceso');

-- ---------------------------------------------------------------- personas
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.personas set nombre_visible = 'Carla E.'
  where id = pruebas.id_persona('carla@ejemplo.test')$$), 1, 'Cada quien cambia su nombre visible');
select pruebas.igual(pruebas.afecta($$update public.personas set nombre_visible = 'Otro nombre'
  where id = pruebas.id_persona('ana@ejemplo.test')$$), 0, 'Nadie cambia el nombre de otra persona');
select pruebas.falla($$update public.personas set usuario_id = null
  where id = pruebas.id_persona('carla@ejemplo.test')$$,
  'Nadie cambia la cuenta enlazada a su persona', '42501');
select pruebas.falla($$insert into public.personas (nombre_visible) values ('Persona falsa')$$,
  'Nadie crea personas directo (las crea el registro de la cuenta)', '42501');

-- ---------------------------------------------------------------- hogares
select pruebas.como('nuevo@ejemplo.test');
select pruebas.falla($$insert into public.hogares (nombre) values ('Directo')$$,
  'Los hogares no se insertan directo', '42501');
create temporary table nuevo_hogar on commit drop as select public.crear_hogar('Hogar de Nuevo') as id;
select pruebas.igual(public.rol_en_hogar((select id from nuevo_hogar)), 'dueno',
  'Quien crea un hogar queda como dueño');
select pruebas.igual(pruebas.afecta($$update public.hogares set nombre = 'Hogar Renombrado'
  where id = (select id from nuevo_hogar)$$), 1, 'El dueño renombra su hogar');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.hogares set nombre = 'Cambio'$$), 0,
  'Un familiar no renombra el hogar');

-- ---------------------------------------------------------------- dispositivos
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.dispositivos'), 2, 'Ana ve sus 2 dispositivos');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.dispositivos'), 0, 'Carla no ve dispositivos ajenos');
select pruebas.igual(pruebas.afecta($$insert into public.dispositivos (plataforma, token_avisos, nombre)
  values ('android', 'token-fcm-de-prueba-carla', 'Teléfono de Carla')$$), 1,
  'Carla registra su teléfono');
select pruebas.igual(
  (select persona_id from public.dispositivos where token_avisos = 'token-fcm-de-prueba-carla'),
  pruebas.id_persona('carla@ejemplo.test'), 'El dispositivo queda a su nombre');
select pruebas.falla($$insert into public.dispositivos (persona_id, plataforma, token_avisos)
  values (pruebas.id_persona('ana@ejemplo.test'), 'android', 'token-robado')$$,
  'Nadie registra un dispositivo a nombre de otra persona', '42501');
select pruebas.falla($$insert into public.dispositivos (plataforma, token_avisos)
  values ('ios', 'token-x')$$, 'Plataforma desconocida rechazada', '23514');
select pruebas.igual(pruebas.afecta('delete from public.dispositivos'), 1,
  'Carla solo puede borrar su propio dispositivo');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.dispositivos'), 2,
  'Los dispositivos de Ana siguen ahí');

rollback;
