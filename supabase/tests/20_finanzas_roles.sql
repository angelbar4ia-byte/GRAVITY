-- Criterio 26 con D19: cada quien ve y registra en su libro y en los
-- compartidos de los que es miembro; la pareja no ve las finanzas personales
-- del dueño (ni al revés); familiar, cuidador y casa no ven nada de Finanzas.
-- Todo comprobado en el servidor (RLS). La cuenta maestra está en 28_*.
-- (Antes de D19 el criterio decía "el coadministrador lee y no escribe"; con
-- P1 y P2 la pareja lleva su propio libro y registra en los compartidos.)
begin;

-- ---------------------------------------------------------------- Ana (dueña)
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  public.alcance('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer') = 'propio'
  and not public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer'),
  'D19: el dueño tiene Finanzas con alcance propio, ya no total');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 3,
  'Ana ve 3 libros: el suyo, "Gastos de la casa" y el de Papá (es su albacea)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 18,
  'Ana ve sus movimientos, los del compartido y los de Papá (18)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros
  where id = pruebas.libro_personal('alex@ejemplo.test')$$), 0, 'Ana no ve el libro personal de Alex');
select pruebas.ok(not public.fin_puede(pruebas.libro_personal('alex@ejemplo.test'), 'leer'),
  'fin_puede(): la dueña no lee el libro de la pareja');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = pruebas.libro_personal('alex@ejemplo.test')$$), 0, 'Ana no ve las cuentas de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where id in (
  'd1000000-0000-4000-8000-000000000021', 'd1000000-0000-4000-8000-000000000022',
  'd1000000-0000-4000-8000-000000000023')$$), 0, 'Ana no ve los movimientos personales de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_ingresos
  where libro_id = pruebas.libro_personal('alex@ejemplo.test')$$), 0, 'Ana no ve el sueldo de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_v_saldos
  where cuenta_id = 'c4000000-0000-4000-8000-000000000001'$$), 0, 'Ana no ve el saldo del banco de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_v_gasto_semana
  where libro_id = pruebas.libro_personal('alex@ejemplo.test')$$), 0, 'Ana no ve el gasto semanal de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_parametros
  where libro_id = pruebas.libro_personal('alex@ejemplo.test')$$), 0, 'Ana no ve los parámetros de Alex');
select pruebas.ok(exists (select 1 from public.fin_movimientos where id = 'd1000000-0000-4000-8000-000000000013'),
  'D19 regla 1: la aportación de Alex al compartido se ve desde el compartido');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where id = 'c4000000-0000-4000-8000-000000000001'$$), 0,
  '… pero no la cuenta personal de Alex de donde salió');
select pruebas.igual(
  (select p.nombre_visible from public.personas p
    where p.id = (select realizado_por from public.fin_movimientos where id = 'd1000000-0000-4000-8000-000000000013')),
  'Alex Ejemplo', '… y sí quién la hizo: la app muestra "Aportación de Alex"');
select pruebas.igual(
  (select libro_origen_id from public.fin_movimientos where id = 'd1000000-0000-4000-8000-000000000013'),
  pruebas.libro_personal('alex@ejemplo.test'), 'El servidor anota el libro de cada lado del movimiento');

-- ---------------------------------------------------------------- Alex (pareja)
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(
  public.alcance('b0000000-0000-4000-8000-000000000001', 'finanzas', 'escribir') = 'propio'
  and public.alcance('b0000000-0000-4000-8000-000000000001', 'finanzas', 'administrar') = 'propio',
  'D19 (P2): la pareja escribe y administra lo suyo');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros'), 3,
  'Alex ve 3 libros: el suyo, el compartido y el de Papá (es suplente)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_movimientos'), 11,
  'Alex ve sus movimientos, los del compartido y los de Papá (11)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros
  where id = pruebas.libro_personal('ana@ejemplo.test')$$), 0, 'P1: Alex no ve el libro personal de Ana');
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_cuentas', 'fin_ingresos', 'fin_compromisos', 'fin_sobres', 'fin_deudas',
                                 'fin_semanas', 'fin_partidas_semana', 'fin_abonos_semana', 'fin_cierres',
                                 'fin_cierre_partidas', 'fin_cierre_abonos', 'fin_ocurrencias',
                                 'fin_conciliaciones', 'fin_parametros', 'fin_libro_miembros',
                                 'fin_vigencias_ingreso', 'fin_v_saldos', 'fin_v_gasto_semana']
  loop
    perform pruebas.igual(pruebas.cuenta(format(
      'select * from public.%I where libro_id = pruebas.libro_personal(%L)', v_tabla, 'ana@ejemplo.test')), 0,
      'P1: Alex no ve nada del libro de Ana en ' || v_tabla);
  end loop;
end
$$;
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = pruebas.libro_personal('ana@ejemplo.test')
    and libro_destino_id is distinct from 'f1000000-0000-4000-8000-000000000001'$$), 0,
  'Alex no ve los movimientos personales de Ana');
select pruebas.ok(exists (select 1 from public.fin_movimientos where id = 'd1000000-0000-4000-8000-000000000009'),
  'La aportación de Ana al compartido sí la ve (D19 regla 1)');
select pruebas.igual(pruebas.cuenta('select * from public.fin_cuentas where libro_id is null'), 12,
  'Las 12 cuentas de gasto del hogar son comunes: Alex las ve');
select pruebas.igual(pruebas.cuenta('select * from public.fin_categorias'), 21,
  'El árbol de categorías es del hogar: Alex lo ve completo');

-- ---------------------------------------------------------------- registrar
select pruebas.ok(pruebas.registrar('gasto', 'c4000000-0000-4000-8000-000000000002',
                                    'c2000000-0000-4000-8000-000000000004', 4200) is not null,
  'Alex registra un gasto en su libro');
select pruebas.ok(pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
                                    'c2000000-0000-4000-8000-000000000001', 20000,
                                    p_id => 'd5000000-0000-4000-8000-000000000001') is not null,
  'Alex registra un gasto en el compartido');
select pruebas.ok(pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000002',
                                    'c2000000-0000-4000-8000-000000000006', 3000,
                                    p_realizado_por => pruebas.id_persona('ana@ejemplo.test')) is not null,
  'Alex registra en el compartido un gasto que pagó Ana (realizado_por)');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001',
                                                'c2000000-0000-4000-8000-000000000004', 100)$$,
  'Alex no registra en el libro de Ana', '42501');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001',
                                                'c5000000-0000-4000-8000-000000000001', 100)$$,
  'Alex no saca dinero de la cuenta de Ana hacia el compartido', '42501');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('alex@ejemplo.test'), 'Ahorro de Alex', 'ahorro')$$), 1,
  'Alex administra su libro: crea una cuenta');
select pruebas.igual(pruebas.afecta($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Tarjeta de la casa', 'tarjeta')$$), 1,
  'Alex administra el compartido (es miembro)');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Intrusa', 'banco')$$,
  'Alex no crea cuentas en el libro de Ana', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set nombre = 'Cambiada'
  where id = 'c3000000-0000-4000-8000-000000000001'$$), 0, 'Alex no cambia cuentas de Ana');
select pruebas.igual(pruebas.afecta($$update public.fin_parametros set meta_remanente_pb = 0
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$), 0, 'Alex no cambia los parámetros de Ana');
select pruebas.igual(pruebas.afecta($$update public.fin_semanas set estado = 'por_cerrar'
  where id = 'e6000000-0000-4000-8000-000000000002'$$), 0, 'Alex no toca el plan semanal de Ana');
select pruebas.igual(pruebas.afecta($$insert into public.fin_categorias (hogar_id, nivel, nombre)
  values ('b0000000-0000-4000-8000-000000000001', 1, 'Mascotas')$$), 1,
  'El árbol de categorías es común: la pareja también agrega categorías');

select pruebas.como('ana@ejemplo.test');
select pruebas.ok(exists (select 1 from public.fin_movimientos where id = 'd5000000-0000-4000-8000-000000000001'),
  'Ana ve el gasto que Alex registró en el compartido');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas where nombre = 'Ahorro de Alex'$$), 0,
  'Ana no ve la cuenta nueva del libro de Alex');
select pruebas.falla($$insert into public.fin_movimientos (hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
  cuenta_destino_id, monto_centavos, registrado_por)
  values ('b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21', now(), 'c5000000-0000-4000-8000-000000000001',
          'c2000000-0000-4000-8000-000000000001', 100, pruebas.id_persona('alex@ejemplo.test'))$$,
  'Nadie registra a nombre de otra persona (registrado_por)', '42501');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
                                                'c2000000-0000-4000-8000-000000000001', 100,
                                                p_realizado_por => pruebas.id_persona('carla@ejemplo.test'))$$,
  'Quien realizó el gasto lleva el libro (Carla no)', '22023');

-- ---------------------------------------------------------------- familiar, cuidador y casa
do $$
declare
  v_correo text;
  v_tabla  text;
begin
  foreach v_correo in array array['carla@ejemplo.test', 'diana@ejemplo.test', 'casa@ejemplo.test']
  loop
    perform pruebas.como(v_correo);
    for v_tabla in
      select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind in ('r', 'v') and c.relname like 'fin\_%'
       order by c.relname
    loop
      perform pruebas.igual(pruebas.cuenta(format('select * from public.%I', v_tabla)), 0,
        format('%s no ve nada de %s', v_correo, v_tabla));
    end loop;
    perform pruebas.igual(pruebas.cuenta($q$select * from public.bitacora
                                           where tabla like 'fin\_%' or accion like 'finanzas.%'$q$), 0,
      v_correo || ' no ve el dinero por la bitácora');
    perform pruebas.igual(pruebas.cuenta($q$select * from public.personas
                                           where id = 'e0000000-0000-4000-8000-000000000001'$q$), 0,
      v_correo || ' no ve a Papá por Finanzas');
    perform pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                       and not public.fin_puede_hogar('b0000000-0000-4000-8000-000000000001', 'leer')
                       and not public.es_cuenta_maestra('b0000000-0000-4000-8000-000000000001'),
      v_correo || ': fin_puede() y fin_puede_hogar() niegan');
    perform pruebas.falla($q$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000002',
                                                      'c2000000-0000-4000-8000-000000000001', 100)$q$,
      v_correo || ' no registra un gasto (ni de la caja chica de la casa)', '42501');
    perform pruebas.falla($q$insert into public.fin_libros (hogar_id, nombre, tipo)
                            values ('b0000000-0000-4000-8000-000000000001', 'Mi libro', 'compartido')$q$,
      v_correo || ' no crea libros', '42501');
    perform pruebas.falla($q$insert into public.fin_categorias (hogar_id, nivel, nombre)
                            values ('b0000000-0000-4000-8000-000000000001', 1, 'Intento')$q$,
      v_correo || ' no crea categorías', '42501');
    perform pruebas.igual(pruebas.afecta($q$update public.fin_cuentas set nombre = 'x'$q$), 0,
      v_correo || ' no cambia cuentas');
    perform pruebas.igual(pruebas.afecta($q$delete from public.fin_categorias$q$), 0,
      v_correo || ' no borra categorías');
  end loop;
end
$$;

-- ---------------------------------------------------------------- bitácora (D19)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where tabla = 'fin_movimientos' and registro_id = 'd1000000-0000-4000-8000-000000000023'$$), 0,
  'D19: la dueña ya no ve en la bitácora el gasto personal de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where tabla = 'fin_cuentas' and registro_id = 'c4000000-0000-4000-8000-000000000001'$$), 0,
  'D19: ni las cuentas personales de Alex');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where tabla = 'fin_movimientos' and registro_id = 'd1000000-0000-4000-8000-000000000014'$$), 1,
  'Pero sí lo que Alex registra en el compartido');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where tabla = 'fin_movimientos' and registro_id = 'd1000000-0000-4000-8000-000000000009'$$), 1,
  'Alex ve en la bitácora la aportación de Ana al compartido');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where tabla = 'fin_movimientos' and registro_id = 'd1000000-0000-4000-8000-000000000005'$$), 0,
  'Pero no los gastos personales de Ana');

-- ---------------------------------------------------------------- baja
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.membresias set activa = false, hasta = now()
  where persona_id = pruebas.id_persona('alex@ejemplo.test')$$), 1, 'La dueña da de baja a Alex');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_libros')
                     + pruebas.cuenta('select * from public.fin_movimientos')
                     + pruebas.cuenta('select * from public.fin_cuentas'), 0,
  'Dado de baja, Alex ya no ve nada de Finanzas (ni su libro, ni el compartido)');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
                                                'c2000000-0000-4000-8000-000000000001', 100)$$,
  'Ni registra en el compartido', '42501');

rollback;
