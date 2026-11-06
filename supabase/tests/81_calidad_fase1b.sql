-- =============================================================================
-- Guardias de la revisión de calidad de la Fase 1b (docs/revisiones/fase-1b.md)
-- =============================================================================
-- Intentos de romper con un PostgreSQL real las reglas nuevas del 23/oct/2026
-- (cuenta maestra con login propio, libros compartidos, libro de papá, bitácora).
-- Todos PASAN hoy: son regresiones que no deben abrirse. Lo que sí está abierto
-- vive en hallazgos_fase1b.sql (no entra en la corrida normal).
--
-- Nota: nada de aquí depende de que un compartido con menos de 2 miembros se
-- archive (la decisión de la 2.ª ronda del 23/oct lo cambia a "pasa a privado").
begin;

-- Dos adultos más (la cuenta maestra no lleva libro): Beto y Caro.
select pruebas.nuevo_adulto('beto@ejemplo.test');
select pruebas.nuevo_adulto('caro@ejemplo.test');

-- ================================================================== maestra
-- Marta (coadministrador + es_maestra, sin libro propio) es de SOLO LECTURA
-- TOTAL: ninguna vía de escritura le sirve, ni con una consulta registrada.
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$,
  'Q1: la maestra no registra en el compartido', '42501');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$,
  'Q1: ni en el libro de Ana', '42501');
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$,
  'Q1: la maestra no se agrega a un compartido', '42501');
select pruebas.falla($$insert into public.fin_libros (id, hogar_id, nombre, tipo)
  values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', 'Libro de la maestra', 'compartido')$$,
  'Q1: la maestra no crea libros', '42501');
select pruebas.falla($$select public.fin_crear_libro_representado('b0000000-0000-4000-8000-000000000001',
  'Otra persona', 'Su libro', gen_random_uuid())$$,
  'Q1: la maestra no crea el libro de una persona representada', '42501');
select pruebas.falla($$select public.asignar_cuenta_maestra('b0000000-0000-4000-8000-000000000001', null)$$,
  'Q1: la maestra no se quita ni se cambia a sí misma', '42501');
select pruebas.falla($$update public.membresias set es_maestra = false
  where persona_id = pruebas.id_persona('marta@ejemplo.test')$$,
  'Q1: la marca de maestra no se toca directo', '42501');
select pruebas.falla($$select count(*) from public.crear_invitacion('b0000000-0000-4000-8000-000000000001',
  'otra@ejemplo.test', 'familiar')$$,
  'Q1: la maestra no invita', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_categorias set archivada = true$$), 0,
  'Q1: la maestra no archiva categorías');
select pruebas.igual(pruebas.afecta($$update public.fin_cuentas set estado = 'congelada' where libro_id is null$$), 0,
  'Q1: ni congela las cuentas de gasto del hogar');
select pruebas.igual(pruebas.afecta($$update public.fin_dias_inhabiles set activo = not activo$$), 0,
  'Q1: ni cambia los días inhábiles');
select pruebas.falla($$insert into public.fin_importaciones (hogar_id, archivo, filas_leidas, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'x.csv', 0, '{}')$$,
  'Q1: ni registra una importación', '42501');
-- Forjar la propia consulta en la bitácora (para saltarse la función que la registra).
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla, registro_id, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'finanzas.consulta_maestra', 'fin_libros',
          pruebas.libro_personal('ana@ejemplo.test')::text, '{}')$$,
  'Q2: la maestra no escribe su propia consulta a mano', '42501');
-- Sin consulta, el contenido ajeno no se lee (ni por las vistas ni por la bitácora).
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$), 0, 'Q3: sin consulta no ve las cuentas de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = pruebas.libro_personal('ana@ejemplo.test')
     or libro_destino_id = pruebas.libro_personal('ana@ejemplo.test')$$), 0,
  'Q3: ni sus movimientos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_v_saldos
  where libro_id = pruebas.libro_personal('ana@ejemplo.test') and saldo_centavos <> 0$$), 0,
  'Q3: ni sus saldos por la vista');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where tabla in ('fin_movimientos', 'fin_cuentas', 'fin_ingresos', 'fin_semanas')
    and detalle::text like '%' || pruebas.libro_personal('ana@ejemplo.test')::text || '%'$$), 0,
  'Q3: ni la bitácora de lo que ocurre en el libro de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion like 'finanzas.salida%'$$), 0,
  'Q3: ni los avisos de salida del libro de Papá');
select pruebas.igual(pruebas.cuenta('select * from public.invitaciones'), 0, 'Q3: no ve invitaciones (solo el dueño)');
select pruebas.igual(pruebas.cuenta($$select * from public.dispositivos
  where persona_id <> pruebas.id_persona('marta@ejemplo.test')$$), 0, 'Q3: ni los dispositivos de otras personas');
-- La consulta es por libro y por persona: la de Ana no abre el de Alex.
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')),
  'Q4: la maestra registra su consulta al libro de Ana');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$) > 0, 'Q4: y con ella lee el libro de Ana');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = pruebas.libro_personal('alex@ejemplo.test')$$), 0, 'Q4: pero no el de Alex');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000001', 100)$$,
  'Q4: con la consulta vigente sigue sin escribir', '42501');
select pruebas.falla($$select public.fin_registrar_consulta_maestra('320f08b3-426c-4d28-828d-5522b90a8c3c')$$,
  'Q4: no registra consultas a libros de otro hogar', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test'))$$,
  'Q4: quien no es la maestra no registra consultas (ni descubre libros por el error)', '42501');

-- ============================================================ compartidos
-- "Gastos de la casa": creada por Ana, miembros Ana y Alex. Beto entra como tercer miembro.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          pruebas.id_persona('beto@ejemplo.test'), 'miembro')$$), 1,
  'Q5: la administradora agrega a un tercer miembro');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$update public.fin_libros set creado_por = pruebas.id_persona('alex@ejemplo.test')
  where id = 'f1000000-0000-4000-8000-000000000001'$$,
  'Q5: un miembro no se adueña del cargo de administrador', '42501');
select pruebas.falla($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f1000000-0000-4000-8000-000000000001'$$,
  'Q5: solo la administradora cambia la visibilidad', '42501');
select pruebas.falla($$update public.fin_libros set activo = false
  where id = 'f1000000-0000-4000-8000-000000000001'$$,
  'Q5: ni lo archiva', '42501');
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          pruebas.id_persona('caro@ejemplo.test'), 'miembro')$$,
  'Q5: ni agrega a otro', '42501');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('beto@ejemplo.test')$$,
  'Q5: ni saca a otro', '42501');
select pruebas.falla($$update public.fin_libro_miembros set desde = '2000-01-01'
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  'Q5: ni se adelanta la fecha de ingreso para heredar el cargo', '42501');
-- Quien se sale no vuelve a entrar por su cuenta (ni abriendo su fila ni con upsert ni con una fila nueva).
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('beto@ejemplo.test')$$), 1,
  'Q6: Beto se sale cuando quiere');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = null
  where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('beto@ejemplo.test')$$), 0,
  'Q6: no reabre su fila');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (id, hogar_id, libro_id, persona_id, papel)
  select id, hogar_id, libro_id, persona_id, papel from public.fin_libro_miembros
   where libro_id = 'f1000000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('beto@ejemplo.test')
  on conflict (id) do update set hasta = null$$), 0,
  'Q6: ni con upsert');
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
          pruebas.id_persona('beto@ejemplo.test'), 'miembro')$$,
  'Q6: ni con una fila nueva', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = 'f1000000-0000-4000-8000-000000000001'$$), 0, 'Q6: y ya no ve el libro (privado)');

-- Un compartido privado de otros: la dueña (no miembro) no lo ve, no se agrega, no lo toca.
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libros (id, hogar_id, nombre, tipo)
  values ('f2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Beto y Caro', 'compartido')$$), 1,
  'Q7: Beto crea un compartido');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000001',
          pruebas.id_persona('caro@ejemplo.test'), 'miembro')$$), 1,
  'Q7: y agrega a Caro');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000001'$$), 0,
  'Q7: la dueña no ve el libro privado de Beto y Caro');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libro_miembros
  where libro_id = 'f2000000-0000-4000-8000-000000000001'$$), 0, 'Q7: ni sus miembros');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora
  where detalle::text like '%f2000000-0000-4000-8000-000000000001%'$$), 0, 'Q7: ni su bitácora');
select pruebas.falla($$insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
  values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000001',
          pruebas.id_persona('ana@ejemplo.test'), 'miembro')$$,
  'Q7: no se agrega a sí misma', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f2000000-0000-4000-8000-000000000001'$$), 0, 'Q7: ni lo hace público');
-- Público: los adultos con Finanzas lo LEEN, no escriben, y no ven lo personal de quien aportó.
select pruebas.como('beto@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set visibilidad = 'publica'
  where id = 'f2000000-0000-4000-8000-000000000001'$$), 1, 'Q8: el administrador lo hace público');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000001'$$) = 1,
  'Q8: ahora la dueña lo lee');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000001', 'Colada', 'efectivo')$$,
  'Q8: pero no crea cuentas', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libros set nombre = 'Mío'
  where id = 'f2000000-0000-4000-8000-000000000001'$$), 0, 'Q8: ni lo renombra');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$), 0,
  'Q8: leer un público no abre los libros personales de quien aportó');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000001'$$), 0,
  'Q8: una familiar (sin Finanzas) no lee un público');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where id = 'f2000000-0000-4000-8000-000000000001'$$), 0,
  'Q8: ni la cuenta Hogar');

-- ================================================================== papá
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000)$$,
  'Q9: ni sin en_nombre_de ni sin motivo', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Q9: ni con en_nombre_de y sin motivo', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => '   ')$$,
  'Q9: ni con un motivo de puros espacios', '23514');
select pruebas.falla($$select pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 100000)$$,
  'Q9: la transferencia de la pensión al banco de Ana sin motivo', '23514');
select pruebas.ok(pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
  'c3000000-0000-4000-8000-000000000001', 100000, p_motivo => 'Reembolso de medicinas (ejemplo)',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null,
  'Q9: con motivo y en su nombre sí entra');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$) = 1,
  'Q9: y la salida hacia un libro personal queda en la bitácora');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$) = 1,
  'Q9: que ve el suplente');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.salida_libro_representado'$$), 0,
  'Q9: y no una familiar');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => 'x',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Q9: tampoco registra una familiar', '42501');

-- ================================================================ bitácora
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, persona_id, accion)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'tablet.registro')$$,
  'Q10: la cuenta Hogar no escribe a nombre de Ana', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, accion, tabla)
  values ('b0000000-0000-4000-8000-000000000001', 'x', E'\nfin_libros')$$,
  'Q10: ni con una tabla fin_ escondida tras un salto de línea', '42501');

rollback;
