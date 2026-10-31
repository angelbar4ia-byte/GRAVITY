-- La portada del libro representado (papá) para el dueño del hogar (D19; migración
-- 20261027000000_finanzas_portada_representado.sql). Criterio provisional:
--   * el DUEÑO del hogar lee SIEMPRE, aunque no sea miembro, la fila de fin_libros y las de
--     fin_libro_miembros (quién es albacea y suplente) de los libros REPRESENTADOS de su hogar;
--   * nada más: ni cuentas, ni movimientos, ni plan, ni saldos, ni bitácora del libro;
--   * solo el dueño (no coadministrador, ni la maestra que no es la dueña, ni familiar,
--     cuidador o casa), solo tipo representado, solo su hogar, y solo lectura.
begin;

select pruebas.nuevo_adulto('teo@ejemplo.test');

-- ---------------------------------------------------------------- precondiciones
select pruebas.como_postgres();
select pruebas.ok(
  (select count(*) from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002') > 0
  and (select count(*) from public.fin_movimientos
        where libro_origen_id = 'f1000000-0000-4000-8000-000000000002'
           or libro_destino_id = 'f1000000-0000-4000-8000-000000000002') > 0
  and (select count(*) from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002') = 2,
  'Precondición: el libro de papá tiene cuentas, movimientos, albacea y suplente');

-- ---------------------------------------------------------------- el dueño que lleva el libro (sin cambio)
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'),
  'Ana, albacea, lee todo el libro de papá (como siempre)');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$) > 0,
  '… incluidas sus cuentas');

-- ---------------------------------------------------------------- el dueño deja de ser miembro
-- Ana y el suplente dejan el cargo: el libro de papá queda sin nadie que lo lleve (el caso de N4).
update public.fin_libro_miembros set hasta = now()
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea_suplente';
update public.fin_libro_miembros set hasta = now()
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'),
  'Precondición: Ana ya no es miembro ni lee el contenido del libro de papá');

select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  'La dueña, aunque no sea miembro, ve la fila del libro de papá');
select pruebas.igual(
  (select nombre from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'),
  'Papá (ejemplo)', '… con su nombre');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros
  where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 2,
  'Y las filas de quién lo llevaba (albacea y suplente)');
select pruebas.igual(pruebas.cuenta($$select * from public.personas
  where id in (select persona_id from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002')$$), 2,
  'Y puede leer el nombre de esas dos personas (miembros de su hogar)');

-- Nada más: ni una cuenta, ni un movimiento, ni el plan, ni los saldos, ni la bitácora del libro.
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'No ve las cuentas del libro');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = 'f1000000-0000-4000-8000-000000000002' or libro_destino_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'ni sus movimientos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_v_saldos where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'ni sus saldos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_v_gasto_semana where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'ni el gasto por semana');
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_parametros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_ingresos where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_vigencias_ingreso where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_compromisos where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_sobres where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_deudas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_semanas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_ocurrencias where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_cierres where libro_id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_conciliaciones where libro_id = 'f1000000-0000-4000-8000-000000000002'$$),
  0, 'ni el plan: parámetros, ingresos, vigencias, compromisos, sobres, deudas, semanas, ocurrencias, cierres y conciliaciones');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where persona_id <> pruebas.id_persona('ana@ejemplo.test')
    and (detalle -> 'despues' ->> 'libro_origen_id' = 'f1000000-0000-4000-8000-000000000002'
         or detalle ->> 'libro_id' = 'f1000000-0000-4000-8000-000000000002')$$), 0,
  'ni lo que otras personas dejaron en la bitácora del libro');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  'fin_puede() sigue negando leer, escribir y administrar: la portada no abre el libro');

-- Solo lectura.
select pruebas.igual(pruebas.afecta($$update public.fin_libros set nombre = 'Otro nombre'
  where id = 'f1000000-0000-4000-8000-000000000002'$$), 0, 'No cambia el libro');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set activo = false
  where id = 'f1000000-0000-4000-8000-000000000002'$$), 0, 'ni lo archiva');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0, 'ni cambia a sus miembros');
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
          pruebas.id_persona('ana@ejemplo.test'), 'albacea')$$,
  'ni se agrega a mano (la única puerta es fin_nombrar_albacea)', '42501');

-- ---------------------------------------------------------------- lo que no se ve de más
-- Un compartido privado de Alex y Teo, y el libro personal de Alex: la dueña no los ve (D19).
select pruebas.como('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo) values
  ('f1000000-0000-4000-8000-0000000000e1', 'b0000000-0000-4000-8000-000000000001', 'Alex y Teo (ejemplo)', 'compartido');
insert into public.fin_libro_miembros (libro_id, persona_id, papel) values
  ('f1000000-0000-4000-8000-0000000000e1', pruebas.id_persona('teo@ejemplo.test'), 'miembro');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros
  where id = 'f1000000-0000-4000-8000-0000000000e1'$$), 0,
  'Un compartido privado ajeno sigue sin verse');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros
  where libro_id = 'f1000000-0000-4000-8000-0000000000e1'$$), 0,
  'ni quiénes lo llevan');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros
  where id = pruebas.libro_personal('alex@ejemplo.test')$$), 0,
  'ni el libro personal de la pareja');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 3,
  'La dueña ve exactamente 3 libros: el suyo, el compartido de la casa y la portada de papá');

-- Los libros representados de OTRO hogar no se ven.
select pruebas.como('elena@ejemplo.test');
select pruebas.ok(public.fin_crear_libro_representado('b0000000-0000-4000-8000-000000000002', 'Abuela (ejemplo)', null,
                  'f1000000-0000-4000-8000-0000000000e2') is not null,
  'Elena, dueña de otro hogar, crea el libro de su abuela');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000e2'$$), 1,
  'Elena lo ve');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-0000000000e2'$$), 0,
  'Ana, dueña de otro hogar, no ve el libro de la abuela de Elena');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-0000000000e2'$$), 0,
  'ni quiénes lo llevan');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'Y Elena no ve el libro de papá de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'ni quiénes lo llevan');

-- ---------------------------------------------------------------- los demás roles no ven la portada
select pruebas.como('teo@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'Un coadministrador que no es miembro no ve el libro de papá (aunque Alex, que lo fue, sí lo vio)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  '… ni quiénes lo llevaban');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  'Alex, que era el suplente y ya dejó el cargo, tampoco');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$),
  0, 'La familiar no ve nada');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$),
  0, 'La cuidadora no ve nada');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$),
  0, 'La cuenta Hogar no ve nada');

-- La cuenta maestra que no es la dueña: sin cambio (ya veía la portada de todos los libros;
-- el contenido solo con consulta registrada).
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_libro_miembros where libro_id = 'f1000000-0000-4000-8000-000000000002'$$),
  3, 'Marta (maestra) sigue viendo la portada: el libro y sus 2 filas de miembros');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$), 0,
  '… y sin consulta no ve las cuentas (no cambió)');
select pruebas.ok(public.fin_registrar_consulta_maestra('f1000000-0000-4000-8000-000000000002'),
  '… registra su consulta');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$) > 0,
  '… y con ella sí lee el contenido (no cambió)');

-- Sin sesión.
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_libros$$, 'Sin sesión no se lee nada', '42501');

-- ---------------------------------------------------------------- el dueño vuelve a nombrarse desde la portada
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
                    pruebas.id_persona('ana@ejemplo.test'), 'albacea') is not null,
  'Con la portada a la vista, la dueña se nombra albacea (N4)');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer')
                  and pruebas.cuenta($$select * from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$) > 0,
  '… y ahora sí lee el contenido: es albacea');

-- ---------------------------------------------------------------- la dueña que además es la cuenta maestra
select pruebas.como_postgres();
update public.fin_libro_miembros set hasta = now()
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.como('ana@ejemplo.test');
select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'));
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000002'$$)
  + pruebas.cuenta($$select * from public.fin_cuentas where libro_id = 'f1000000-0000-4000-8000-000000000002'$$),
  1, 'La dueña que además es maestra ve la portada y, sin consulta, no el contenido');

rollback;
