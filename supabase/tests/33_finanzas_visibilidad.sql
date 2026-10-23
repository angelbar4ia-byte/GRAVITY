-- Libros compartidos: visibilidad (decisión del dueño del 23/oct/2026).
--   privada (por omisión): leen y escriben sus miembros; la cuenta maestra lee
--     con consulta registrada; el dueño del hogar NO entra si no es miembro;
--   publica: además LEEN (no escriben) los adultos con Finanzas del hogar.
-- La cambia solo quien creó el libro.
begin;

-- Un tercer adulto y un libro de Alex y Teo (Ana, la dueña, no es miembro).
select pruebas.nuevo_adulto('teo@ejemplo.test');
select pruebas.como('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo) values
  ('f1000000-0000-4000-8000-0000000000e1', 'b0000000-0000-4000-8000-000000000001', 'Alex y Teo (ejemplo)', 'compartido');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000e1', pruebas.id_persona('teo@ejemplo.test'), 'miembro');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'f1000000-0000-4000-8000-0000000000e1', 'Cuenta de Alex y Teo', 'banco');
select pruebas.registrar('apertura', pruebas.cuenta_sistema('f1000000-0000-4000-8000-0000000000e1', 'apertura'),
                         'c9000000-0000-4000-8000-000000000001', 300000, p_id => 'd9000000-0000-4000-8000-000000000001');
select pruebas.registrar('gasto', 'c9000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 45000,
                         p_id => 'd9000000-0000-4000-8000-000000000002');

-- ---------------------------------------------------------------- por omisión es privado
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000e1'),
  'privada', 'Un compartido nace privado');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'escribir')
                  and public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'administrar'),
  'Su creador lo lee, lo escribe y lo administra');

-- El dueño del hogar NO entra a un compartido privado del que no es miembro.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'),
  'Privado: la dueña (adulta con Finanzas, no miembro) no lo lee');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros where id = ''f1000000-0000-4000-8000-0000000000e1'''), 0,
  '… no ve el libro');
select pruebas.igual(pruebas.cuenta('select * from public.fin_cuentas where libro_id = ''f1000000-0000-4000-8000-0000000000e1'''), 0,
  '… ni sus cuentas');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos where libro_origen_id = ''f1000000-0000-4000-8000-0000000000e1'''), 0,
  '… ni sus movimientos');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libro_miembros where libro_id = ''f1000000-0000-4000-8000-0000000000e1'''), 0,
  '… ni quién lo lleva');
select pruebas.igual(pruebas.cuenta('select * from public.fin_v_saldos where libro_id = ''f1000000-0000-4000-8000-0000000000e1'''), 0,
  '… ni sus saldos');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where registro_id = 'd9000000-0000-4000-8000-000000000002'$$), 0,
  '… ni su bitácora');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'), 'La familiar tampoco');

-- Solo quien lo creó cambia la visibilidad.
select pruebas.como('teo@ejemplo.test');
select pruebas.falla($$update public.fin_libros set visibilidad = 'publica' where id = 'f1000000-0000-4000-8000-0000000000e1'$$,
  'Un miembro que no lo creó no lo hace público', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-0000000000e1'$$), 0, 'La dueña, que no es miembro, tampoco');

-- Los libros personales y el de Papá no son públicos.
select pruebas.como_postgres();
select pruebas.falla($$update public.fin_libros set visibilidad = 'publica' where tipo = 'personal'$$,
  'Un libro personal no puede ser público', '23514');
select pruebas.falla($$update public.fin_libros set visibilidad = 'publica' where tipo = 'representado'$$,
  'Ni el de Papá', '23514');
select pruebas.falla($$update public.fin_libros set visibilidad = 'secreta' where id = 'f1000000-0000-4000-8000-0000000000e1'$$,
  'Solo privada o pública', '23514');

-- ---------------------------------------------------------------- pública: leen los adultos con Finanzas, no escriben
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-0000000000e1'$$), 1, 'Alex, el creador, lo hace público');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'escribir')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'administrar'),
  'Pública: la dueña lo lee y no lo escribe ni lo administra');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros where id = ''f1000000-0000-4000-8000-0000000000e1'''), 1,
  '… ve el libro');
select pruebas.igual(pruebas.cuenta('select * from public.fin_cuentas where libro_id = ''f1000000-0000-4000-8000-0000000000e1'''), 4,
  '… sus cuentas (la suya, Ajustes, Apertura y Por clasificar)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos where libro_origen_id = ''f1000000-0000-4000-8000-0000000000e1'''), 2,
  '… y sus movimientos');
select pruebas.igual((select saldo_centavos from public.fin_v_saldos where cuenta_id = 'c9000000-0000-4000-8000-000000000001'),
  255000::bigint, '… y su saldo');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libro_miembros where libro_id = ''f1000000-0000-4000-8000-0000000000e1'''), 2,
  '… y quién lo lleva');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where registro_id = 'd9000000-0000-4000-8000-000000000002'$$), 1,
  '… y su bitácora');
select pruebas.igual(pruebas.cuenta($$select * from public.personas where nombre_visible = 'Teo'$$), 1,
  '… y a los miembros por su nombre');
select pruebas.falla($$select pruebas.registrar('gasto', 'c9000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'No registra en él', '42501');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-0000000000e1', 'Cuenta de Ana', 'banco')$$,
  'No crea cuentas', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set nombre = 'Otro nombre'
  where id = 'c9000000-0000-4000-8000-000000000001'$$), 0, 'No cambia lo que lee');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-0000000000e1', pruebas.id_persona('ana@ejemplo.test'), 'miembro')$$,
  'No se agrega como miembro', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000e1'$$), 0, 'Ni saca a nadie');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set nombre = 'X' where id = 'f1000000-0000-4000-8000-0000000000e1'$$), 0,
  'Ni lo renombra');

-- Lo leen también la pareja y, en el libro de Ana, la pareja; no quien no tiene Finanzas ni otro hogar.
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'),
  'La familiar (sin Finanzas) no lo lee, aunque sea público');
select pruebas.como('diana@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'), 'La cuidadora tampoco');
select pruebas.como('casa@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'), 'Ni la cuenta Hogar (rol casa)');
select pruebas.como('elena@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'), 'Ni alguien de otro hogar');
select pruebas.como('ana@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo, visibilidad) values
  ('f1000000-0000-4000-8000-0000000000e2', 'b0000000-0000-4000-8000-000000000001', 'Ana y Teo (ejemplo)', 'compartido', 'publica');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000e2', pruebas.id_persona('teo@ejemplo.test'), 'miembro');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000e2'),
  'publica', 'Un compartido puede nacer público (se manda en el INSERT)');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000e2', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e2', 'escribir'),
  'La pareja (adulta con Finanzas) lee el público de Ana y Teo y no lo escribe');

-- ---------------------------------------------------------------- la cuenta maestra
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'),
  'Maestra: aunque sea público, necesita la consulta registrada');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-0000000000e1'),
  '… registra la consulta');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'),
  '… y con la consulta lo lee');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'escribir')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e2', 'leer'),
  '… no lo escribe, y la consulta es de ese libro (el otro público sigue cerrado)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_maestra'
  and registro_id = 'f1000000-0000-4000-8000-0000000000e1'$$), 1,
  'La consulta de la maestra a un libro público también queda a la vista de quienes lo leen');

-- La dueña como maestra (con su persona): en un libro ajeno, público o no, lee con consulta.
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer'),
  'La dueña, siendo además la cuenta maestra, necesita consulta para leer el público ajeno');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-0000000000e1'),
  '… tras registrar la consulta');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'escribir'),
  '… lo lee, sin escribir');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', null);

-- ---------------------------------------------------------------- de público a privado
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'privada'
  where id = 'f1000000-0000-4000-8000-0000000000e1'$$), 1, 'Alex lo vuelve privado');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer')
                  and pruebas.cuenta('select * from public.fin_movimientos where libro_origen_id = ''f1000000-0000-4000-8000-0000000000e1''') = 0,
  'La dueña deja de leerlo al instante');

-- ---------------------------------------------------------------- archivado y público; salir de uno público
select pruebas.como('alex@ejemplo.test');
update public.fin_libros set visibilidad = 'publica' where id = 'f1000000-0000-4000-8000-0000000000e1';
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000e1' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$,
  'Alex (creador) no saca a Teo: dejaría el libro con 1 miembro (solo se sale uno mismo, y entonces se archiva)', '22023');
select pruebas.como('teo@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000e1' and persona_id = pruebas.id_persona('teo@ejemplo.test')$$), 1,
  'Teo se sale del libro público (quedan 1: se archiva)');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'escribir'),
  'Quien se sale de un libro público lo sigue leyendo como adulto del hogar (pero no escribe)');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(not (select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000e1')
                  and public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-0000000000e1', 'escribir'),
  'Archivado y público: la dueña lo sigue leyendo, solo lectura');

rollback;
