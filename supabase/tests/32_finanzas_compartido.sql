-- Libros compartidos (D19, decisiones del dueño del 21 y 23/oct/2026):
--   * quien lo crea es el administrador: solo él (o el dueño del hogar, si es
--     miembro) agrega y saca a otras personas, cambia la visibilidad y lo archiva
--     (I1, revisión de calidad de la Fase 1);
--   * CUALQUIER miembro puede salirse siempre (2.ª ronda del 23/oct): si al salir
--     (o al ser sacado) quedan menos de 2 miembros vigentes el libro NO se archiva:
--     pasa a privado, sigue activo y el que queda es el administrador; si se sale el
--     creador, creado_por pasa al miembro vigente más antiguo;
--   * el último miembro no puede salirse (22023): el administrador lo archiva;
--   * archivar es solo una decisión explícita del administrador.
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

-- ---------------------------------------------------------------- quitar a otro: con menos de 2 el libro pasa a privado
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('teo@ejemplo.test')
    and hasta is null$$), 1,
  'I1: la administradora saca a Teo (quedan Ana y Alex)');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'La administradora lo hace público');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$), 1,
  '2.ª ronda del 23/oct: saca a Alex y quedan menos de 2: ya no es error (22023)');
select pruebas.como_postgres();
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  'El libro sigue activo: no se archiva solo');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'), 'privada',
  'Pasó de público a privado');
select pruebas.igual((select creado_por from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  pruebas.id_persona('ana@ejemplo.test'), 'Ana, la que queda, es la administradora');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')
    and hasta is null$$,
  'El último miembro no puede salirse (puede archivar el libro)', '22023');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir'), 'Y el libro, con un solo miembro, sigue registrando');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'miembro')$$), 1,
  'Ana vuelve a agregar a Alex');

-- ---------------------------------------------------------------- salirse con 2 miembros: pasa a privado y sigue activo
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'Ana lo vuelve público');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer'), 'Alex lo lee');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')
    and hasta is null$$), 1,
  '23/oct: Alex se sale aunque solo queden 2 miembros: el servidor lo permite');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer'),
  'Alex ya no lo lee: al quedar 1 miembro pasó a privado (y él deja de ser miembro)');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  'El libro NO quedó archivado: sigue activo');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'), 'privada',
  'Volvió a privado');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer') and public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir')
                  and public.fin_puede('f1000000-0000-4000-8000-000000000001', 'administrar'),
  'Ana, la que queda, lo lee, registra y administra');
select pruebas.ok(pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100) is not null, 'Un movimiento nuevo entra');
select pruebas.ok(pruebas.cuenta('select * from public.fin_movimientos where libro_origen_id = ''f1000000-0000-4000-8000-000000000001''') > 0,
  'Sus movimientos siguen a la vista');

-- ---------------------------------------------------------------- archivar es solo una decisión explícita del administrador
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = false
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'Ana, la administradora, lo archiva a mano');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir'),
  'Archivado: se lee y ya no registra');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$, 'Un movimiento nuevo en el libro archivado se rechaza', '42501');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'administrar'),
  'La administradora sigue administrándolo (para reactivarlo)');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = true
  where id = 'f1000000-0000-4000-8000-000000000001'$$), 1, 'La administradora lo reactiva (sin pedir 2 miembros)');
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

-- ---------------------------------------------------------------- se sale el creador con solo otro miembro: pasa el cargo, sigue activo
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
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d1')
                  and (select creado_por from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d1')
                      = pruebas.id_persona('ana@ejemplo.test'),
  'El libro sigue activo y Ana es ahora su administradora');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where tabla = 'fin_libros'
  and registro_id = 'f1000000-0000-4000-8000-0000000000d1' and accion = 'actualizar'$$), 1,
  'El relevo queda en la bitácora');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-0000000000d1', 'administrar'),
  'Ana lo administra (y puede archivarlo)');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d1' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$,
  'Y como último miembro no puede salirse', '22023');

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
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-0000000000d2'$$), 1, 'Alex, el creador, lo hace público');
select pruebas.como_postgres();
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('teo@ejemplo.test');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 1,
  'Con Teo dado de baja del hogar solo quedan 2 vigentes: sacar a Ana deja a Alex solo');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d2'),
  'privada', 'Teo no cuenta: el libro pasó a privado');
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d2'),
  'y sigue activo');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('teo@ejemplo.test')
    and hasta is null$$), 1,
  'Pero sí se limpia el cargo de quien ya no está en el hogar (no cambia a quienes quedan)');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('alex@ejemplo.test')
    and hasta is null$$,
  'Alex, ya solo, no puede salirse', '22023');

-- ---------------------------------------------------------------- el mantenimiento (service_role) sigue las mismas reglas
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-0000000000d2', pruebas.id_persona('ana@ejemplo.test'), 'miembro')$$), 1,
  'Alex vuelve a agregar a Ana (quedan 2)');
select pruebas.como_servicio();
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('ana@ejemplo.test')
    and hasta is null$$), 1,
  'El servidor puede quitar a otro y deja a Alex solo: el libro sigue activo');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d2' and persona_id = pruebas.id_persona('alex@ejemplo.test')
    and hasta is null$$,
  'Pero tampoco el servidor deja el libro sin ningún miembro', '22023');

-- ---------------------------------------------------------------- si el administrador ya no es del hogar, el cargo pasa al más antiguo
select pruebas.como_postgres();
select pruebas.nuevo_adulto('uma@ejemplo.test', 'Uma Ejemplo');
select pruebas.como('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo, visibilidad) values
  ('f1000000-0000-4000-8000-0000000000d3', 'b0000000-0000-4000-8000-000000000001', 'Mudanza (ejemplo)', 'compartido', 'publica');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000d3', pruebas.id_persona('ana@ejemplo.test'), 'miembro'),
  ('f1000000-0000-4000-8000-0000000000d3', pruebas.id_persona('uma@ejemplo.test'), 'miembro');
select pruebas.como_postgres();
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-0000000000d3' and persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 1,
  'Ana se sale; el administrador (Alex) ya no es adulto del hogar: solo cuenta Uma');
select pruebas.como_postgres();
select pruebas.igual((select creado_por from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d3'),
  pruebas.id_persona('uma@ejemplo.test'), 'El cargo pasa a Uma, que queda sola');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d3'),
  'privada', 'El libro pasa a privado');
select pruebas.ok((select activo from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000d3'),
  'y sigue activo');

-- ---------------------------------------------------------------- la maestra no es miembro
select pruebas.como_postgres();
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-0000000000d2',
          pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$,
  'La cuenta maestra (solo lectura) no se agrega a un libro, ni por el servidor', '22023');

rollback;
