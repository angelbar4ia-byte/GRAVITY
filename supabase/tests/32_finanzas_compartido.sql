-- I1 (revisión de calidad de la Fase 1): en un libro compartido solo quien lo
-- creó, o el dueño del hogar, cambia la membresía de otra persona; y nunca
-- quedan menos de 2 miembros vigentes. Antes, cualquier miembro (también la
-- pareja) podía sacar a la dueña de "Gastos de la casa".
begin;

-- ---------------------------------------------------------------- la pareja no saca a la dueña
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: la pareja no cierra la membresía de la dueña en el compartido', '42501');
select pruebas.falla($$update public.fin_libro_miembros set desde = now() + interval '1 year'
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: ni la deja "fuera" moviendo su fecha de inicio al futuro', '42501');
select pruebas.ok(
  (select hasta is null and desde <= now() from public.fin_libro_miembros
    where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'I1: la dueña sigue como miembro vigente');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir'),
  'Y Alex sigue pudiendo registrar en el compartido');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'I1: ni él mismo sale si el libro quedaría con menos de 2 miembros', '22023');

-- ---------------------------------------------------------------- nunca menos de 2
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'I1: ni la dueña (creadora) saca a Alex: el compartido no baja de 2 miembros', '22023');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: ni ella misma se sale', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = false
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1,
  'Para dejar de usar un compartido se desactiva el libro (cualquier miembro puede)');
select pruebas.afecta($$update public.fin_libros set activo = true where id = 'f1000000-0000-4000-8000-000000000001'$$);

-- Con un tercero, la creadora (dueña) sí puede sacarlo; los demás miembros no.
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$), 1,
  'Ana agrega a Marta (tercera miembro del compartido)');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('marta@ejemplo.test')$$,
  'I1: con tres miembros, Alex (que no lo creó) no saca a Marta', '42501');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: ni a la dueña, aunque ya no sea la única otra persona', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: dos miembros no se ponen de acuerdo para sacar a la tercera persona: Marta no saca a Ana', '42501');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'I1: ni a Alex', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and hasta is null$$), 3, 'Siguen los tres vigentes');

-- Cada quien puede salirse si quedan 2 o más.
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 1,
  'Marta se sale por su cuenta (quedan 2)');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                  and pruebas.cuenta('select * from public.fin_movimientos') = 0,
  '… y deja de leer el compartido (aunque sea la cuenta maestra, ve solo la portada)');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = null
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 0,
  'Quien se salió no se reincorpora sola (ya no administra el libro)');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = null
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('marta@ejemplo.test')$$,
  'I1: ni otro miembro que no creó el libro la reincorpora (sí se vuelve a agregar con un cargo nuevo)', '42501');

-- La creadora (dueña) vuelve a sacar a alguien cuando hay tres.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$), 1,
  'Ana vuelve a agregar a Marta con un cargo nuevo');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('marta@ejemplo.test')
    and hasta is null$$), 1,
  'I1: la creadora (y dueña) sí cierra la membresía de otra persona cuando quedan 2');

-- ---------------------------------------------------------------- el dueño del hogar, aunque no lo haya creado
select pruebas.como('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo) values
  ('f1000000-0000-4000-8000-0000000000d1', 'b0000000-0000-4000-8000-000000000001', 'Viaje de Alex (ejemplo)', 'compartido');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000d1', pruebas.id_persona('ana@ejemplo.test'), 'miembro'),
  ('f1000000-0000-4000-8000-0000000000d1', pruebas.id_persona('marta@ejemplo.test'), 'miembro');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d1' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: en el libro de Alex, Marta (ni creadora ni dueña) no saca a nadie', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d1' and persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 1,
  'I1: la dueña del hogar, aunque no creó el libro de Alex, sí cierra la membresía de otra persona');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-0000000000d1', pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$), 1,
  'Alex (creador) la vuelve a agregar');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d1' and persona_id = pruebas.id_persona('marta@ejemplo.test')
    and hasta is null$$), 1,
  'I1: el creador también cierra la membresía de otra persona');

-- ---------------------------------------------------------------- bajas del hogar cuentan como ausencia
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$), 1,
  'El compartido vuelve a tener tres cargos (Ana, Alex y Marta)');
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('marta@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'I1: con Marta dada de baja del hogar solo quedan 2 vigentes: Alex no puede salir', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('marta@ejemplo.test')
    and hasta is null$$), 1,
  'Pero sí se limpia el cargo de quien ya no está en el hogar (no cambia a quienes quedan)');

-- ---------------------------------------------------------------- el mantenimiento (service_role) también respeta el mínimo
select pruebas.como_servicio();
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'El mínimo de 2 miembros vale para todos, también para las funciones del servidor', '22023');

rollback;
