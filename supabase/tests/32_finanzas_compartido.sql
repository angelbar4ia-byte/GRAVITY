-- Libros compartidos (D19, decisiones del dueño del 21 y 23/oct/2026):
--   * quien lo crea es el administrador: solo él (o el dueño del hogar, si es
--     miembro) agrega y saca a otras personas, cambia la visibilidad y lo archiva
--     (I1, revisión de calidad de la Fase 1);
--   * CUALQUIER miembro puede salirse siempre; si al salir quedan menos de 2
--     miembros vigentes el libro se archiva (activo = false, solo lectura); si se
--     sale el creador, creado_por pasa al miembro vigente más antiguo;
--   * quitar a OTRO nunca deja menos de 2 miembros vigentes (22023).
-- (La visibilidad pública y privada está en 33_finanzas_visibilidad.sql.)
begin;

-- Un tercer adulto (la cuenta maestra es solo lectura y no puede llevar un libro).
select pruebas.nuevo_adulto('teo@ejemplo.test');

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
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('teo@ejemplo.test'), 'miembro')$$,
  '23/oct: un miembro que no es el administrador no agrega a nadie', '42501');
select pruebas.falla($$update public.fin_libros set activo = false where id = 'f1000000-0000-4000-8000-000000000001'$$,
  '23/oct: ni archiva el libro', '42501');
select pruebas.falla($$update public.fin_libros set visibilidad = 'publica' where id = 'f1000000-0000-4000-8000-000000000001'$$,
  '23/oct: ni cambia su visibilidad', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set nombre = 'Casa y despensa'
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'Renombrarlo sí puede cualquier miembro');
select pruebas.falla($$update public.fin_libros set creado_por = pruebas.id_persona('alex@ejemplo.test')
  where id = 'f1000000-0000-4000-8000-000000000001'$$,
  'El administrador solo lo cambia el servidor (la API no puede cambiar creado_por)', '42501');

-- ---------------------------------------------------------------- el administrador agrega; con tres, nadie saca a nadie
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('teo@ejemplo.test'), 'miembro')$$), 1,
  'Ana (creadora) agrega a Teo, tercer miembro');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$,
  'I1: con tres miembros, Alex (que no lo creó) no saca a Teo', '42501');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: ni a la dueña, aunque Teo y él sean mayoría', '42501');
select pruebas.como('teo@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set desde = now() - interval '5 years'
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$,
  'Nadie se adelanta su fecha de ingreso para heredar el cargo de administrador', '42501');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'I1: Teo no saca a Ana', '42501');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'I1: ni a Alex', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and hasta is null$$), 3, 'Siguen los tres vigentes');

-- ---------------------------------------------------------------- cualquiera puede salirse
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$), 1,
  '23/oct: Teo se sale por su cuenta (quedan 2)');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer'),
  '… y deja de leer el compartido (privado)');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = null
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$), 0,
  'Quien se salió no se reincorpora solo');
-- Intento de reingreso con INSERT ... ON CONFLICT DO UPDATE sobre su propia fila ya cerrada
-- (conociendo su id, que ya no puede leer): la política lo rechaza y la fila sigue cerrada.
select pruebas.como_postgres();
create temporary table fila_teo as
  select id, hogar_id from public.fin_libro_miembros
   where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test');
grant select on fila_teo to authenticated;
select pruebas.como('teo@ejemplo.test');
select pruebas.falla($$insert into public.fin_libro_miembros (id, hogar_id, libro_id, persona_id, papel, desde, hasta)
  select f.id, f.hogar_id, 'f1000000-0000-4000-8000-000000000001', pruebas.id_persona('teo@ejemplo.test'), 'miembro', now(), null
    from fila_teo f
  on conflict (id) do update set hasta = null$$,
  'Quien se salió no se reincorpora con un upsert sobre su fila cerrada', '42501');
select pruebas.como_postgres();
select pruebas.ok((select hasta is not null from public.fin_libro_miembros where id = (select id from fila_teo)),
  '… y su fila sigue cerrada');
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  'Con 2 miembros que siguen, el libro sigue activo');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('teo@ejemplo.test'), 'miembro')$$,
  'Alex no lo vuelve a agregar (solo el administrador)', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('teo@ejemplo.test'), 'miembro')$$), 1,
  'Ana lo vuelve a agregar con un cargo nuevo');

-- ---------------------------------------------------------------- quitar a otro, nunca por debajo de 2
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test')
    and hasta is null$$), 1,
  'I1: la administradora saca a Teo (quedan Ana y Alex)');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'Pero no saca a Alex: el compartido no baja de 2 miembros vigentes (para terminarlo se archiva)', '22023');

-- ---------------------------------------------------------------- salir con 2 miembros: el libro se archiva
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')
    and hasta is null$$), 1,
  '23/oct: Alex se sale aunque solo queden 2 miembros: el servidor lo permite');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer'), 'Alex ya no lee el libro');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not (select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  'El libro quedó archivado (activo = false): solo queda 1 miembro vigente');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir'),
  'Archivado: quien sigue lo lee y ya no registra');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Un movimiento nuevo en el libro archivado se rechaza', '42501');
select pruebas.ok(pruebas.cuenta('select * from public.fin_movimientos where libro_origen_id = ''f1000000-0000-4000-8000-000000000001''') > 0,
  'Sus movimientos siguen a la vista');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'administrar'),
  'La administradora sigue administrándolo (para reactivarlo)');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = true
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'La administradora lo reactiva');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir'), 'Admite movimientos otra vez');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'miembro')$$), 1,
  'Y vuelve a agregar a Alex');

-- ---------------------------------------------------------------- un archivado lo administra solo su creador
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = false
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'La administradora lo archiva a mano');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'administrar'),
  'Archivado, Alex lo lee y ya no lo administra');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Cuenta nueva', 'banco')$$,
  'Ni crea cuentas en él', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = true
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 0,
  'Ni lo reactiva (no lo administra: la regla no le deja tocarlo)');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')
    and hasta is null$$), 1,
  'Pero sí se sale de un libro archivado (cualquier miembro, siempre)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = true
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'Ana lo reactiva (sola; queda con 1 miembro)');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'miembro')$$), 1,
  'y vuelve a agregar a Alex');

-- ---------------------------------------------------------------- se sale la administradora: el cargo pasa al miembro más antiguo
select pruebas.como_postgres();
-- Fechas de ingreso distintas (en la prueba todo ocurre en el mismo instante).
update public.fin_libro_miembros set desde = now() - interval '10 days'
 where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')
   and hasta is null;
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('teo@ejemplo.test'), 'miembro')$$), 1,
  'Teo entra otra vez (el más reciente)');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')
    and hasta is null$$), 1,
  '23/oct: Ana, la creadora, se sale (quedan Alex y Teo)');
select pruebas.como_postgres();
select pruebas.igual(
  (select creado_por from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  pruebas.id_persona('alex@ejemplo.test'),
  'creado_por pasa al miembro vigente más antiguo (provisional): Alex');
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  'El libro sigue activo (quedan 2)');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                  and pruebas.cuenta('select * from public.fin_libros where id = ''f1000000-0000-4000-8000-000000000001''') = 0,
  'Ana ya no ve el libro (era privado)');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'administrar'),
  'Alex es ahora el administrador');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, '… cambia la visibilidad');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'privada'
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, '… y la vuelve a cambiar');
select pruebas.como('teo@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'Teo no saca al nuevo administrador', '42501');

-- ---------------------------------------------------------------- se sale el creador con solo otro miembro: archiva y pasa el cargo
select pruebas.como('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo) values
  ('f1000000-0000-4000-8000-0000000000d1', 'b0000000-0000-4000-8000-000000000001', 'Viaje de Alex (ejemplo)', 'compartido');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000d1', pruebas.id_persona('ana@ejemplo.test'), 'miembro');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d1'),
  'privada', 'Un compartido nace privado');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d1' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$), 1,
  'Alex, creador de un libro de 2, se sale');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not (select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d1')
                  and (select creado_por from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d1')
                      = pruebas.id_persona('ana@ejemplo.test'),
  'El libro queda archivado y Ana es ahora su administradora');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where tabla = 'fin_libros'
  and registro_id = 'f1000000-0000-4000-8000-0000000000d1' and accion = 'actualizar'$$), 1,
  'El archivo y el relevo quedan en la bitácora');

-- ---------------------------------------------------------------- el dueño del hogar, aunque no lo creó
select pruebas.como('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo) values
  ('f1000000-0000-4000-8000-0000000000d2', 'b0000000-0000-4000-8000-000000000001', 'Regalos (ejemplo)', 'compartido');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000d2', pruebas.id_persona('ana@ejemplo.test'), 'miembro'),
  ('f1000000-0000-4000-8000-0000000000d2', pruebas.id_persona('teo@ejemplo.test'), 'miembro');
select pruebas.como('teo@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'En el libro de Alex, Teo (ni creador ni dueño) no saca a nadie', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$), 1,
  'La dueña del hogar, aunque no creó el libro de Alex y es miembro, sí saca a otra persona (quedan 2)');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-0000000000d2', pruebas.id_persona('teo@ejemplo.test'), 'miembro')$$), 1,
  'y también agrega miembros');
select pruebas.falla($$update public.fin_libros set activo = false where id = 'f1000000-0000-4000-8000-0000000000d2'$$,
  'Pero no archiva ni cambia la visibilidad: eso es solo de quien lo creó', '42501');

-- ---------------------------------------------------------------- las bajas del hogar cuentan como ausencia
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('teo@ejemplo.test');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'Con Teo dado de baja del hogar solo quedan 2 vigentes: sacar a Ana (otro) da 22023', '22023');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('teo@ejemplo.test')
    and hasta is null$$), 1,
  'Pero sí se limpia el cargo de quien ya no está en el hogar (no cambia a quienes quedan)');

-- ---------------------------------------------------------------- el mantenimiento (service_role) también respeta el mínimo
select pruebas.como_servicio();
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'El mínimo de 2 miembros vale al quitar a otro, también para las funciones del servidor', '22023');

-- ---------------------------------------------------------------- la maestra no es miembro
select pruebas.como_postgres();
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-0000000000d2',
          pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$,
  'La cuenta maestra (solo lectura) no se agrega a un libro, ni por el servidor', '22023');

rollback;
