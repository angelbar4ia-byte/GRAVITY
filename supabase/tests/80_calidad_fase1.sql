-- =============================================================================
-- Revisión de calidad de la Fase 1 (docs/revisiones/fase-1.md): guardias que
-- hoy PASAN y que conviene conservar. Son los intentos de romper el servidor
-- que la revisión probó a mano y que el servidor resiste:
--   1. escalada de privilegios (coadministrador y familiares);
--   2. roles sin Finanzas: ni tablas, ni vistas, ni funciones, ni bitácora;
--   3. libros solo agregar contra todos los roles, TRUNCATE en cascada y
--      ON CONFLICT DO UPDATE;
--   4. cruce entre libros: solo transferencia y pago de deuda, con permiso en
--      los dos libros;
--   5. reenvío de otra persona con el mismo id.
-- Los hallazgos que esta revisión dejó abiertos (I1 a I5, M6) se corrigieron en
-- 20261023000000_finanzas_salvaguardas.sql y sus pruebas viven en 28 (I2, M6, M10),
-- 30 (I5), 31 (I3, I4) y 32 (I1); hallazgos_fase1.sql ya no existe.
-- =============================================================================
begin;

-- ---------------------------------------------------------------- 1. escalada
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('alex@ejemplo.test'), 'albacea')$$,
  'Escalada: el suplente no se agrega como albacea del libro de Papá', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set papel = 'albacea'
  where libro_id = 'f1000000-0000-4000-8000-000000000002'
    and persona_id = pruebas.id_persona('alex@ejemplo.test')$$), 0,
  'Escalada: el suplente no cambia su papel a albacea (con albacea vigente no administra)');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000002'
    and persona_id = pruebas.id_persona('ana@ejemplo.test')$$), 0,
  'Escalada: el suplente no cierra el cargo de la albacea');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values (pruebas.libro_personal('ana@ejemplo.test'), pruebas.id_persona('alex@ejemplo.test'), 'miembro')$$,
  'Escalada: la pareja no se mete al libro personal de la dueña', '42501');
select pruebas.falla($$update public.membresias set es_maestra = true
  where persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'Escalada: la pareja no se pone sola la marca de cuenta maestra (sin permiso de columna)', '42501');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('alex@ejemplo.test'))$$,
  'Escalada: la pareja no llama asignar_cuenta_maestra', '42501');
select pruebas.igual(pruebas.afecta($$update public.membresias set rol = 'dueno'
  where persona_id = pruebas.id_persona('alex@ejemplo.test')$$), 0,
  'Escalada: la pareja no se cambia el rol a dueño');
select pruebas.falla($$select public.fin_crear_libro_representado('b0000000-0000-4000-8000-000000000001', 'Tía falsa')$$,
  'Escalada: la pareja no crea el libro de una persona representada (solo el dueño)', '42501');
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo, titular_id, creado_por)
  values ('b0000000-0000-4000-8000-000000000001', 'Libro de Ana', 'personal',
          pruebas.id_persona('ana@ejemplo.test'), public.persona_actual())$$,
  'Escalada: la pareja no crea un libro personal a nombre de otra persona', '42501');
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo, titular_id, creado_por)
  values ('b0000000-0000-4000-8000-000000000001', 'Otro de Papá', 'representado',
          'e0000000-0000-4000-8000-000000000001', public.persona_actual())$$,
  'Escalada: ni crea un libro representado a mano (solo con la función del dueño)', '42501');

select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 'miembro')$$,
  'Un familiar no entra a un libro compartido (solo adultos con Finanzas)', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 'miembro')$$,
  'Una cuidadora no entra a un libro compartido', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('casa@ejemplo.test'), 'miembro')$$,
  'La cuenta Casa no entra a un libro compartido', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('elena@ejemplo.test'), 'miembro')$$,
  'Una persona de otro hogar no entra a un libro compartido', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 'miembro')$$,
  'Papá (sin cuenta) no es miembro de un libro compartido', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('carla@ejemplo.test'), 'albacea_suplente')$$,
  'Un familiar no es suplente del albacea', '22023');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('carla@ejemplo.test'))$$,
  'La cuenta maestra no puede ser un familiar', '22023');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001',
  pruebas.id_persona('casa@ejemplo.test'))$$,
  'Ni la cuenta Casa', '22023');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000002',
  pruebas.id_persona('elena@ejemplo.test'))$$,
  'El dueño de un hogar no asigna la cuenta maestra de otro hogar', '42501');

-- ---------------------------------------------------- 2. roles sin Finanzas
do $$
declare
  v_correo text;
  v_tabla  text;
  v_n      integer;
begin
  foreach v_correo in array array['carla@ejemplo.test', 'diana@ejemplo.test', 'casa@ejemplo.test'] loop
    perform pruebas.como(v_correo);
    foreach v_tabla in array array[
        'fin_libros', 'fin_libro_miembros', 'fin_categorias', 'fin_cuentas', 'fin_parametros',
        'fin_movimientos', 'fin_ingresos', 'fin_vigencias_ingreso', 'fin_compromisos', 'fin_sobres',
        'fin_deudas', 'fin_dias_inhabiles', 'fin_semanas', 'fin_partidas_semana', 'fin_abonos_semana',
        'fin_cierres', 'fin_cierre_partidas', 'fin_cierre_abonos', 'fin_ocurrencias',
        'fin_conciliaciones', 'fin_importaciones', 'fin_v_saldos', 'fin_v_gasto_semana'] loop
      execute format('select count(*) from public.%I', v_tabla) into v_n;
      perform pruebas.igual(v_n, 0, format('%s no ve filas de %s', v_correo, v_tabla));
    end loop;
    select count(*) into v_n from public.bitacora where tabla like 'fin\_%' or accion like 'finanzas.%';
    perform pruebas.igual(v_n, 0, format('%s no ve entradas de Finanzas en la bitácora', v_correo));
    perform pruebas.falla('select public.fin_registrar_consulta_maestra(''f1000000-0000-4000-8000-000000000001'')',
      format('%s no registra consultas de la cuenta maestra', v_correo), '42501');
    perform pruebas.falla('select public.fin_crear_libro_representado(''b0000000-0000-4000-8000-000000000001'', ''x'')',
      format('%s no crea el libro de una persona representada', v_correo), '42501');
    perform pruebas.falla('insert into public.fin_libros (hogar_id, nombre, tipo, creado_por) '
      || 'values (''b0000000-0000-4000-8000-000000000001'', ''x'', ''compartido'', public.persona_actual())',
      format('%s no crea libros', v_correo), '42501');
    perform pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'leer')
                       and not public.fin_puede('f1000000-0000-4000-8000-000000000001', 'escribir')
                       and not public.fin_es_miembro('f1000000-0000-4000-8000-000000000001')
                       and not public.fin_puede_hogar('b0000000-0000-4000-8000-000000000001', 'leer'),
      format('fin_puede(), fin_es_miembro() y fin_puede_hogar() niegan todo a %s', v_correo));
    perform pruebas.como_postgres();
  end loop;
end
$$;

-- ------------------------------------------------------------ 3. solo agregar
select pruebas.como_postgres();
select pruebas.falla($$truncate public.fin_cuentas cascade$$,
  'Solo agregar: TRUNCATE de cuentas en cascada arrastra movimientos y se frena', '42501');
select pruebas.falla($$truncate public.fin_libros cascade$$,
  'Solo agregar: TRUNCATE de libros en cascada se frena', '42501');
select pruebas.falla($$truncate public.hogares cascade$$,
  'Solo agregar: TRUNCATE de hogares en cascada se frena', '42501');
select pruebas.falla($$update public.fin_cierres set ingreso_real = 0$$,
  'Solo agregar: el dueño de la tabla no edita cierres', '42501');
select pruebas.falla($$delete from public.fin_conciliaciones$$,
  'Solo agregar: el dueño de la tabla no borra conciliaciones', '42501');
select pruebas.como_servicio();
select pruebas.falla($$update public.fin_movimientos set nota = 'x'$$,
  'Solo agregar: service_role no edita movimientos', '42501');
select pruebas.falla($$delete from public.fin_movimientos$$,
  'Solo agregar: service_role no borra movimientos', '42501');
select pruebas.falla($$truncate public.fin_movimientos$$,
  'Solo agregar: service_role no vacía movimientos', '42501');
select pruebas.falla($$update public.fin_cierres set ingreso_real = 0$$,
  'Solo agregar: service_role no edita cierres', '42501');
select pruebas.falla($$delete from public.fin_cierre_partidas$$,
  'Solo agregar: service_role no borra renglones de cierre', '42501');
select pruebas.falla($$delete from public.fin_importaciones$$,
  'Solo agregar: service_role no borra importaciones', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en,
    cuenta_origen_id, cuenta_destino_id, monto_centavos)
  select id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id, 1
  from public.fin_movimientos limit 1
  on conflict (id) do update set monto_centavos = excluded.monto_centavos$$,
  'Solo agregar: ON CONFLICT DO UPDATE no cambia un monto (sin permiso de UPDATE)', '42501');
select pruebas.falla($$truncate public.fin_movimientos$$,
  'Solo agregar: la dueña no vacía movimientos', '42501');

-- ---------------------------------------------------------- 4. entre libros
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c5000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 500000, p_motivo => 'x',
  p_anula => 'd1000000-0000-4000-8000-000000000009')$$,
  'Alex no anula la aportación de Ana al compartido (la mitad es de un libro ajeno)', '42501');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c5000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 100)$$,
  'Alex no saca dinero del compartido hacia el banco personal de Ana', '42501');
select pruebas.falla($$select pruebas.registrar('pago_deuda', 'c4000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000003', 100)$$,
  'Alex no paga una deuda del libro de Ana (no escribe en ese libro)', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('ingreso',
  (select id from public.fin_cuentas where libro_id = pruebas.libro_personal('ana@ejemplo.test') and tipo = 'origen_ingreso' limit 1),
  'c5000000-0000-4000-8000-000000000001', 100)$$,
  'Cruce entre libros: un ingreso de un libro no llega a la cuenta de otro (combinación válida, libros distintos)', '22023');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000001', 'administrar'),
  'Ana administra el compartido (crea una cuenta nueva sin saldo inicial)');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
values ('c5000000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001',
        'f1000000-0000-4000-8000-000000000001', 'Cuenta nueva de la casa', 'banco');
select pruebas.falla($$select pruebas.registrar('ajuste', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'),
  'c5000000-0000-4000-8000-000000000001', 100, p_motivo => 'x')$$,
  'Cruce entre libros: un ajuste de un libro no mueve la cuenta de otro', '22023');
select pruebas.falla($$select pruebas.registrar('apertura', pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'apertura'),
  'c5000000-0000-4000-8000-0000000000f1', 100)$$,
  'Cruce entre libros: una apertura no cruza', '22023');

-- ---------------------------------------- 5. reenvío de otra persona (mismo id)
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 7700,
                    p_id => 'd7000000-0000-4000-8000-0000000000a1') is not null,
  'Ana registra un gasto con un id fijo');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en,
    cuenta_origen_id, cuenta_destino_id, monto_centavos)
  values ('d7000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-21',
          '2026-10-21 12:00:00-06', 'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 7700)$$,
  'Alex no reenvía el movimiento de Ana como suyo: no tiene permiso en ese libro', '42501');

rollback;
