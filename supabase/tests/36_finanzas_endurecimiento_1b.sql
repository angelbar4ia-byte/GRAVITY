-- Endurecimiento de la Fase 1b (docs/revisiones/fase-1b.md, hallazgos N1 a N5;
-- migración 20261026000000_finanzas_endurecimiento_1b.sql). Criterios provisionales:
--   N1  la app escribe en la bitácora como máximo 4 KB por entrada y 500 entradas por
--       persona en 24 horas (54000); los triggers, las funciones del servidor y
--       service_role no cuentan ni se limitan;
--   N2  el motivo vale con 3 o más caracteres visibles (sin espacios ni invisibles);
--   N3  toda salida del libro de papá hacia otro libro avisa al suplente;
--   N4  fin_nombrar_albacea: el dueño vuelve a nombrar albacea de un cargo vacío;
--   N5  si el administrador de un compartido deja de ser adulto con Finanzas, el cargo
--       pasa al miembro vigente más antiguo (y con menos de 2 vigentes el libro es privado).
-- (Estas afirmaciones nacieron en hallazgos_fase1b.sql, de calidad.)
begin;

select pruebas.nuevo_adulto('beto@ejemplo.test');
select pruebas.nuevo_adulto('caro@ejemplo.test');
select pruebas.nuevo_adulto('dora@ejemplo.test');

-- =============================================================================
-- N1. Tope de la bitácora
-- =============================================================================
select pruebas.igual(octet_length(jsonb_build_object('x', repeat('a', 4087))::text), 4096,
  'Precondición: este detalle pesa justo 4096 bytes');

-- Una familiar (sin Finanzas): ya no mete 36 MB con una sola sentencia.
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, detalle)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno',
         jsonb_build_object('x', repeat('a', 30000))
    from generate_series(1, 1200)$$,
  'N1: 1,200 entradas de 30 KB en una sentencia se rechazan', '54000');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'relleno'$$), 0,
  '… y no se guarda ninguna (la sentencia se deshace)');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'relleno', jsonb_build_object('x', repeat('a', 4088)))$$,
  'Una sola entrada de 4097 bytes se rechaza', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'relleno', jsonb_build_object('x', repeat('a', 4087)))$$), 1,
  'Una de 4096 bytes entra');
-- 499 más: 500 en total, en una sentencia.
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno' from generate_series(1, 499)$$), 499,
  'Hasta 500 entradas en 24 horas entran');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion)
  values ('b0000000-0000-4000-8000-000000000001', 'relleno')$$,
  'La 501.ª se rechaza', '54000');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'relleno'$$), 500,
  'Quedaron las 500 (la rechazada no deja nada)');

-- El tope es por persona: Diana no se ve afectada por Carla.
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno' from generate_series(1, 500)$$), 500,
  'Diana, otra persona, tiene sus propias 500');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno' from generate_series(1, 2)$$,
  'y también se topa', '54000');

-- Una sola sentencia con más de 500: rechazada completa.
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000002', 'relleno' from generate_series(1, 501)$$,
  'Una persona nueva no mete 501 en una sentencia', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000002', 'relleno' from generate_series(1, 500)$$), 500,
  '… pero 500 sí');

-- N1b: la cuenta Hogar (la de la tablet pública).
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, detalle)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno', jsonb_build_object('x', repeat('a', 30000))
    from generate_series(1, 1200)$$,
  'N1b: la cuenta Hogar tampoco mete 36 MB', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno' from generate_series(1, 500)$$), 500,
  '… y tiene sus 500 como cualquiera');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion) values ('b0000000-0000-4000-8000-000000000001', 'relleno')$$,
  '… y se topa', '54000');

-- Las entradas de más de 24 horas ya no cuentan.
select pruebas.como_postgres();
insert into public.bitacora (hogar_id, persona_id, accion, registrado_en)
select 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'relleno_viejo',
       now() - interval '25 hours'
  from generate_series(1, 600);
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno' from generate_series(1, 500)$$), 500,
  'Las de hace más de 24 horas no cuentan: Alex tiene sus 500 de hoy');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion) values ('b0000000-0000-4000-8000-000000000001', 'relleno')$$,
  '… y la 501.ª de hoy se rechaza', '54000');

-- Las entradas automáticas (triggers) no cuentan ni se limitan: un vaciado grande de la cola.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok((select count(pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
                                                    'c2000000-0000-4000-8000-000000000004', 100))
                     from generate_series(1, 520)) = 520,
  'Ana registra 520 gastos de una vez (como un vaciado de la cola sin conexión)');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where accion = 'insertar'
  and tabla = 'fin_movimientos' and persona_id = pruebas.id_persona('ana@ejemplo.test')
  and registrado_en >= now()$$) >= 520,
  '… y cada uno dejó su entrada automática, sin toparse');
-- (Ana ya tiene 1 entrada propia del seed: "datos_de_ejemplo".)
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno' from generate_series(1, 499)$$), 499,
  'Esas entradas automáticas no gastan su tope de 500 propias (le quedan 499 de las 500)');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion) values ('b0000000-0000-4000-8000-000000000001', 'relleno')$$,
  '… que sí se acaba con las suyas', '54000');

-- Las funciones del servidor y service_role no se limitan.
select pruebas.como_servicio();
select pruebas.igual(pruebas.afecta($$insert into public.bitacora (hogar_id, accion, detalle)
  select 'b0000000-0000-4000-8000-000000000001', 'relleno_servidor', jsonb_build_object('x', repeat('a', 30000))
    from generate_series(1, 600)$$), 600,
  'service_role escribe 600 entradas de 30 KB sin tope');
select pruebas.como_postgres();
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where accion = 'relleno_servidor'$$) = 600,
  '… y quedaron guardadas');

-- La acción reservada sigue sin pasar (I5), con o sin tope.
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion) values ('b0000000-0000-4000-8000-000000000001', 'finanzas.x')$$,
  'I5 sigue en pie: finanzas* es del servidor', '42501');

-- =============================================================================
-- N2. El motivo necesita al menos 3 caracteres visibles
-- =============================================================================
-- La regla en sí (una función pura del servidor; la app no la ejecuta).
select pruebas.como_postgres();
select pruebas.ok(
  not public.fin_motivo_valido(null) and not public.fin_motivo_valido('')
  and not public.fin_motivo_valido('   ') and not public.fin_motivo_valido(E'\t\r\n')
  and not public.fin_motivo_valido('ab') and not public.fin_motivo_valido(E' a \t b ')
  and not public.fin_motivo_valido(E'\u00a0\u00a0\u00a0\u00a0') and not public.fin_motivo_valido(E'\u3164\u3164\u3164')
  and not public.fin_motivo_valido(E'\u2800\u2800\u2800') and not public.fin_motivo_valido(E'\u200b\u200c\u200d\u2060'),
  'Vacío, espacios, tabuladores, saltos, dos caracteres e invisibles no son motivo');
select pruebas.ok(
  public.fin_motivo_valido('abc') and public.fin_motivo_valido('a b c') and public.fin_motivo_valido('Renta')
  and public.fin_motivo_valido(E'\n  Compra de la medicina  \n') and public.fin_motivo_valido('ñañ')
  and public.fin_motivo_valido('a.b') and public.fin_motivo_valido('ab-'),
  'Tres o más caracteres visibles, con al menos 2 que no son puntuación y no todos iguales, sí');
select pruebas.ok(
  not public.fin_motivo_valido('...') and not public.fin_motivo_valido('___') and not public.fin_motivo_valido('---')
  and not public.fin_motivo_valido('aaa') and not public.fin_motivo_valido('111') and not public.fin_motivo_valido('a..')
  and not public.fin_motivo_valido(E'\u00bf?\u00a1'),
  'F4-M1: "___", "...", "aaa" y similares no son motivo (misma regla que la app)');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => E'\t',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'N2a: un tabulador no es un motivo (gasto de papá)', '23514');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 100000, p_motivo => E'\r\n ',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'N2b: un salto de línea y un espacio tampoco', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => 'xx',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Dos caracteres no bastan', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => E'  　 ',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Espacios Unicode (no separable, de ancho fijo, ideográfico, separador de línea) no cuentan', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => E'​​​​﻿',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Caracteres invisibles (ancho cero, BOM) no cuentan', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => E' a\tb\n ',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Se cuentan los visibles: " a<tab>b" son solo 2', '23514');
select pruebas.ok(pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => 'a b c',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null,
  'Tres caracteres visibles ("a b c") bastan');
select pruebas.ok(pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => E'  Medicinas de papá (ejemplo)\n',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null,
  'Un motivo normal con espacios alrededor pasa');

-- Anulaciones.
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000004',
  'c3000000-0000-4000-8000-000000000002', 4500, '2026-10-13', E'\t\t', 'd1000000-0000-4000-8000-000000000005')$$,
  'Una anulación con motivo en blanco se rechaza', '23514');
select pruebas.falla($$select pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000004',
  'c3000000-0000-4000-8000-000000000002', 4500, '2026-10-13', 'ab', 'd1000000-0000-4000-8000-000000000005')$$,
  'Y con dos caracteres', '23514');
select pruebas.ok(pruebas.registrar('anulacion', 'c2000000-0000-4000-8000-000000000004',
  'c3000000-0000-4000-8000-000000000002', 4500, '2026-10-13', 'Monto equivocado (ejemplo)',
  'd1000000-0000-4000-8000-000000000005') is not null,
  'Con motivo de verdad, sí');

-- Ajustes y conciliaciones con diferencia.
select pruebas.falla($$select pruebas.registrar('ajuste', 'c3000000-0000-4000-8000-000000000003',
  pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'), 200, '2026-10-21', E'\n\n')$$,
  'Un ajuste con motivo en blanco se rechaza', '23514');
select pruebas.ok(pruebas.registrar('ajuste', 'c3000000-0000-4000-8000-000000000003',
  pruebas.cuenta_sistema(pruebas.libro_personal('ana@ejemplo.test'), 'ajustes'), 200, '2026-10-21',
  'Comisión del estado de cuenta (ejemplo)', p_id => 'd3000000-0000-4000-8000-000000000002') is not null,
  'Con motivo, el ajuste entra');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003', '2026-10-21',
          505200, 505000, 'd3000000-0000-4000-8000-000000000002', E'\t')$$,
  'Una conciliación con diferencia y motivo en blanco se rechaza', '23514');
select pruebas.falla($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003', '2026-10-21',
          505200, 505000, 'd3000000-0000-4000-8000-000000000002', 'ok')$$,
  'Y con dos caracteres', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_conciliaciones (hogar_id, cuenta_id, fecha, saldo_declarado,
  saldo_calculado, ajuste_movimiento_id, motivo)
  values ('b0000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000003', '2026-10-21',
          505200, 505000, 'd3000000-0000-4000-8000-000000000002', 'Comisión del estado de cuenta (ejemplo)')$$), 1,
  'Con motivo, la conciliación entra');

-- Controles: donde el motivo no es obligatorio, sigue siendo libre.
select pruebas.ok(pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000004', 100, p_motivo => 'x') is not null,
  'Un gasto de Ana (sin ser en nombre de nadie) puede llevar un motivo corto: no es obligatorio');
select pruebas.ok(pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000004', 100, p_motivo => null) is not null,
  '… o ninguno');

-- Un reenvío idéntico de lo ya guardado no se rechaza.
select pruebas.ok(pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 1234, p_motivo => 'Pañales (ejemplo)',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001', p_id => 'ee000000-0000-4000-8000-000000000001') is not null,
  'El movimiento de papá se guarda');
select pruebas.ok(pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 1234, p_motivo => 'Pañales (ejemplo)',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001', p_id => 'ee000000-0000-4000-8000-000000000001') is null,
  'Reenviarlo idéntico no falla ni duplica (la cola sin conexión)');

-- =============================================================================
-- N3. Toda salida del libro de papá hacia otro libro avisa al suplente
-- =============================================================================
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 0,
  'Antes de empezar no hay avisos de salida (los gastos de papá no salen del libro)');
select pruebas.como('ana@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo)
  values ('f2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Ana y Beto', 'compartido');
insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000001',
          pruebas.id_persona('beto@ejemplo.test'), 'miembro');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
  values ('c9000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
          'f2000000-0000-4000-8000-000000000001', 'Caja de Ana y Beto', 'efectivo');
select pruebas.ok(pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
  'c9000000-0000-4000-8000-000000000001', 100000, p_motivo => 'Pago de la renta (ejemplo)',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
  p_id => 'ee000000-0000-4000-8000-000000000002') is not null,
  'Papá → un compartido de Ana y Beto (sin el suplente)');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'
  and registro_id = 'ee000000-0000-4000-8000-000000000002'$$), 1,
  'N3: el suplente ve el aviso de la salida hacia el compartido');
select pruebas.igual(
  (select detalle ->> 'libro_destino_id' from public.bitacora where accion = 'finanzas.salida_libro_representado'
    and registro_id = 'ee000000-0000-4000-8000-000000000002'),
  'f2000000-0000-4000-8000-000000000001', '… con el libro de destino, el monto y el motivo');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 0,
  'Una familiar no lo ve');
-- Hacia un libro personal sigue avisando.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 50000, p_motivo => 'Compra de su medicina (ejemplo)',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
  p_id => 'ee000000-0000-4000-8000-000000000003') is not null, 'Papá → el libro personal de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'
  and registro_id = 'ee000000-0000-4000-8000-000000000003'$$), 1, 'Esa salida sigue avisando');
-- Lo que no sale del libro no avisa.
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'
  and registro_id = 'ee000000-0000-4000-8000-000000000001'$$), 0,
  'Un gasto de papá (hacia una cuenta de gasto del hogar) no es una salida de su libro');

-- =============================================================================
-- N4. El dueño vuelve a nombrar albacea del libro de papá
-- =============================================================================
-- Como en la revisión: el albacea deja el cargo sin suplente (y el suplente también).
update public.fin_libro_miembros set hasta = now()
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea_suplente';
update public.fin_libro_miembros set hasta = now()
 where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea';
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'),
  'Precondición: el libro de papá se quedó sin nadie que lo lleve');
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
          pruebas.id_persona('ana@ejemplo.test'), 'albacea')$$,
  'Un insert directo sigue sin pasar: la única puerta es la función', '42501');
select pruebas.ok(public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
                    pruebas.id_persona('ana@ejemplo.test'), 'albacea') is not null,
  'N4: la dueña vuelve a nombrarse albacea');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  '… y vuelve a llevar el libro');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.albacea_nombrado'
  and detalle ->> 'libro_id' = 'f1000000-0000-4000-8000-000000000002'$$), 1,
  'Queda en la bitácora (finanzas.albacea_nombrado)');
select pruebas.ok(public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
                    pruebas.id_persona('alex@ejemplo.test'), 'albacea_suplente') is not null,
  'También nombra al suplente');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$,
  'Con el cargo ocupado no se nombra a otro', '22023');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea_suplente')$$,
  'Ni al suplente, si ya hay', '22023');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'miembro')$$, 'El cargo es albacea o suplente', '22023');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('carla@ejemplo.test'), 'albacea')$$, 'Solo un adulto con Finanzas (no una familiar)', '22023');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  'e0000000-0000-4000-8000-000000000001', 'albacea')$$, 'Papá no se nombra a sí mismo', '22023');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000001',
  pruebas.id_persona('ana@ejemplo.test'), 'albacea')$$, 'Solo el libro representado tiene albacea', '22023');

-- Cargo abierto de alguien que ya no es adulto con Finanzas: el dueño lo releva.
select pruebas.como_postgres();
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
                    pruebas.id_persona('beto@ejemplo.test'), 'albacea_suplente') is not null,
  'Con el suplente dado de baja del hogar, la dueña nombra a otro (cierra el cargo abierto del que se fue)');
select pruebas.igual(
  (select detalle ->> 'anterior_persona_id' from public.bitacora where accion = 'finanzas.albacea_nombrado'
    and detalle ->> 'papel' = 'albacea_suplente'
    and detalle ->> 'persona_id' = pruebas.id_persona('beto@ejemplo.test')::text),
  pruebas.id_persona('alex@ejemplo.test')::text, 'La entrada dice a quién relevó');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$,
  'Quien ya lleva el libro con otro cargo no recibe un segundo', '22023');

-- Solo el dueño.
select pruebas.como('beto@ejemplo.test');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$,
  'Ni el suplente ni un coadministrador nombran albacea', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$, 'Una familiar tampoco', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$, 'Ni la cuenta maestra', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$, 'Ni la dueña de otro hogar', '42501');
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-0000000000ff',
  pruebas.id_persona('beto@ejemplo.test'), 'albacea')$$, 'Un libro que no existe da el mismo 42501', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  'a0000000-0000-4000-8000-000000000001', 'albacea')$$, 'Sin sesión no se ejecuta', '42501');
select pruebas.como_servicio();
select pruebas.falla($$select public.fin_nombrar_albacea('f1000000-0000-4000-8000-000000000002',
  'a0000000-0000-4000-8000-000000000001', 'albacea')$$, 'service_role tampoco', '42501');

-- =============================================================================
-- N5. El administrador de un compartido deja de ser adulto con Finanzas
-- =============================================================================
select pruebas.como_postgres();
-- Compartido público de Beto (creador, el más antiguo), Alex y Caro; Dora entrará después.
update public.membresias set activa = true, hasta = null where persona_id = pruebas.id_persona('alex@ejemplo.test');
insert into public.fin_libros (id, hogar_id, nombre, tipo, creado_por, visibilidad)
  values ('f2000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Beto, Alex y Caro',
          'compartido', pruebas.id_persona('beto@ejemplo.test'), 'publica');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros
  where libro_id = 'f2000000-0000-4000-8000-000000000002'$$), 1, 'Precondición: el creador entra solo como miembro');
insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel) values
  ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000002', pruebas.id_persona('alex@ejemplo.test'), 'miembro'),
  ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000002', pruebas.id_persona('caro@ejemplo.test'), 'miembro');
update public.fin_libro_miembros set desde = now() - interval '30 days'
 where libro_id = 'f2000000-0000-4000-8000-000000000002' and persona_id = pruebas.id_persona('beto@ejemplo.test');
update public.fin_libro_miembros set desde = now() - interval '10 days'
 where libro_id = 'f2000000-0000-4000-8000-000000000002' and persona_id = pruebas.id_persona('alex@ejemplo.test');
update public.fin_libro_miembros set desde = now() - interval '5 days'
 where libro_id = 'f2000000-0000-4000-8000-000000000002' and persona_id = pruebas.id_persona('caro@ejemplo.test');

-- Se da de baja al administrador DEL HOGAR (no se sale del libro).
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('beto@ejemplo.test');
select pruebas.igual((select creado_por from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  pruebas.id_persona('alex@ejemplo.test'), 'N5: el cargo pasa al miembro vigente más antiguo (Alex)');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  'publica', 'Quedan 2 vigentes: sigue público');
select pruebas.ok((select activo from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  'y activo');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f2000000-0000-4000-8000-000000000002', 'administrar'), 'Alex administra el libro');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000002',
          pruebas.id_persona('dora@ejemplo.test'), 'miembro')$$), 1,
  'y ya puede agregar a otra persona (Dora)');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'privada'
  where id = 'f2000000-0000-4000-8000-000000000002'$$), 1, '… y cambiar la visibilidad');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f2000000-0000-4000-8000-000000000002'$$), 1, '… (la deja pública otra vez)');

-- El administrador pierde Finanzas por cambio de rol (no por baja).
select pruebas.como_postgres();
update public.fin_libro_miembros set desde = now() - interval '1 day'
 where libro_id = 'f2000000-0000-4000-8000-000000000002' and persona_id = pruebas.id_persona('dora@ejemplo.test');
update public.membresias set rol = 'familiar' where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.igual((select creado_por from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  pruebas.id_persona('caro@ejemplo.test'), 'Alex pasa a familiar: el cargo pasa a Caro (la más antigua que queda)');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  'publica', 'Siguen 2 vigentes (Caro y Dora): público');

-- Se da de baja a quien no es el administrador: el cargo no cambia, y con 1 vigente pasa a privado.
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('dora@ejemplo.test');
select pruebas.igual((select creado_por from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  pruebas.id_persona('caro@ejemplo.test'), 'La baja de otro miembro no cambia al administrador');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  'privada', 'Con 1 solo vigente el libro pasa a privado');
select pruebas.ok((select activo from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  'y no se archiva');

-- Si no queda nadie, no hay a quién pasarle el cargo (y no falla).
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('caro@ejemplo.test');
select pruebas.igual((select creado_por from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000002'),
  pruebas.id_persona('caro@ejemplo.test'), 'Sin nadie vigente el cargo se queda donde estaba');

-- Una baja sin libros compartidos, de una familiar o de la maestra, no hace nada ni falla.
select pruebas.igual(pruebas.afecta($$update public.membresias set activa = false, hasta = now()
  where persona_id = pruebas.id_persona('carla@ejemplo.test')$$), 1, 'Una familiar se da de baja sin problema');
select pruebas.igual(pruebas.afecta($$update public.membresias set rol = 'coadministrador'
  where persona_id = pruebas.id_persona('marta@ejemplo.test')$$), 1, 'Y la maestra se actualiza sin problema');

-- El seed: la baja del miembro del compartido de la casa (Alex) deja a Ana sola y privado.
update public.membresias set activa = true, hasta = null, rol = 'coadministrador'
 where persona_id = pruebas.id_persona('alex@ejemplo.test');
update public.fin_libros set visibilidad = 'publica' where id = 'f1000000-0000-4000-8000-000000000001';
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('alex@ejemplo.test');
select pruebas.igual((select visibilidad from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  'privada', '"Gastos de la casa": al darse de baja Alex solo queda Ana y el libro pasa a privado');
select pruebas.igual((select creado_por from public.fin_libros where id = 'f1000000-0000-4000-8000-000000000001'),
  pruebas.id_persona('ana@ejemplo.test'), 'Ana sigue como administradora');

rollback;
