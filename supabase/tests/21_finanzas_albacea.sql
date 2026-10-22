-- D19: el libro de Papá (representado) lo llevan su albacea (Ana) y su
-- suplente (Alex). El albacea registra EN NOMBRE de Papá con motivo; el
-- suplente solo escribe si no hay albacea vigente; máximo 2 (albacea y
-- suplente); solo adultos con Finanzas. Papá no tiene cuenta.
begin;

-- ---------------------------------------------------------------- el albacea
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  'fin_puede(): el albacea escribe y administra el libro de Papá');
select pruebas.ok(
  pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000011', 150000,
                    p_motivo => 'Pago de la cuidadora de la semana (ejemplo)',
                    p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001',
                    p_id => 'd6000000-0000-4000-8000-000000000001') is not null,
  'El albacea registra un gasto en nombre de Papá, con motivo');
select pruebas.ok(exists (
  select 1 from public.bitacora
   where tabla = 'fin_movimientos' and registro_id = 'd6000000-0000-4000-8000-000000000001'
     and accion = 'insertar' and persona_id = pruebas.id_persona('ana@ejemplo.test')
     and detalle -> 'despues' ->> 'en_nombre_de' = 'e0000000-0000-4000-8000-000000000001'
     and detalle -> 'despues' ->> 'motivo' is not null),
  'Queda en la bitácora quién lo hizo (Ana), en nombre de quién (Papá) y por qué');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000005', 1000, p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'En nombre de Papá sin motivo, no', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000005', 1000, p_motivo => '   ',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Ni con un motivo en blanco', '23514');
select pruebas.falla($$select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000002',
  'c2000000-0000-4000-8000-000000000005', 1000, p_motivo => 'x',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'en_nombre_de solo en un movimiento del libro de Papá', '22023');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000005', 1000, p_motivo => 'x',
  p_en_nombre_de => pruebas.id_persona('carla@ejemplo.test'))$$,
  'en_nombre_de es el titular del libro (Papá), no otra persona', '22023');
select pruebas.ok(
  pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001', 'c6000000-0000-4000-8000-000000000001',
                    50000) is not null,
  'Ana aporta de su banco a la cuenta de Papá (transferencia entre libros)');

-- ---------------------------------------------------------------- el suplente
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  'fin_puede(): con albacea vigente, el suplente lee y no escribe ni administra');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos
  where libro_origen_id = 'f1000000-0000-4000-8000-000000000002'
     or libro_destino_id = 'f1000000-0000-4000-8000-000000000002'$$), 5,
  'El suplente ve los movimientos del libro de Papá');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000005', 1000, p_motivo => 'Medicinas',
  p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001')$$,
  'Con albacea vigente, el suplente no registra en nombre de Papá (ni con motivo)', '42501');
select pruebas.falla($$select pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000005', 1000)$$,
  'Ni sin en_nombre_de', '42501');
select pruebas.falla($$insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo)
  values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002', 'Otra', 'banco')$$,
  'Ni crea cuentas en el libro de Papá', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea'$$), 0,
  'El suplente no quita al albacea');

-- ---------------------------------------------------------------- miembros válidos
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('marta@ejemplo.test'), 'albacea_suplente')$$,
  'Solo un suplente (máximo 2 en un libro representado)', '23505');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('marta@ejemplo.test'), 'albacea')$$,
  'Solo un albacea vigente', '23505');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('carla@ejemplo.test'), 'albacea')$$,
  'Una familiar sin Finanzas no puede ser albacea', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000001', 'albacea')$$,
  'Papá no es miembro de su propio libro', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('marta@ejemplo.test'), 'miembro')$$,
  'En un libro representado solo hay albacea y suplente', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values (pruebas.libro_personal('ana@ejemplo.test'), pruebas.id_persona('alex@ejemplo.test'), 'miembro')$$,
  'Nadie más entra a un libro personal', '22023');
select pruebas.falla($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'albacea')$$,
  'En un libro compartido todos son miembros', '22023');
select pruebas.falla($$update public.fin_libro_miembros set hasta = now()
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$,
  'El titular no deja su libro personal', '22023');
select pruebas.falla($$update public.fin_libro_miembros set persona_id = pruebas.id_persona('marta@ejemplo.test')
  where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea_suplente'$$,
  'Un miembro no se cambia por otra persona (se cierra y se agrega)', '42501');

-- ---------------------------------------------------------------- el albacea deja el cargo
select pruebas.igual(pruebas.afecta($$update public.fin_libro_miembros set hasta = now()
  where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea'$$), 1,
  'Ana deja de ser albacea (queda en la bitácora)');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'leer'),
  'Quien deja de ser albacea ya no ve el libro de Papá');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')
                  and public.fin_puede('f1000000-0000-4000-8000-000000000002', 'administrar'),
  'Sin albacea vigente, el suplente escribe y administra');
select pruebas.ok(
  pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000005', 1000,
                    p_motivo => 'Medicinas mientras Ana está de viaje (ejemplo)',
                    p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null,
  'El suplente registra en nombre de Papá, con motivo');
select pruebas.igual(pruebas.afecta($$insert into public.fin_libro_miembros (libro_id, persona_id, papel)
  values ('f1000000-0000-4000-8000-000000000002', pruebas.id_persona('marta@ejemplo.test'), 'albacea')$$), 1,
  'El suplente nombra un albacea nuevo (hogar_id lo pone el servidor)');
select pruebas.ok(not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir'),
  'Con albacea vigente otra vez, el suplente vuelve a solo leer');

-- ---------------------------------------------------------------- crear el libro de una persona representada
select pruebas.falla($$select public.fin_crear_libro_representado('b0000000-0000-4000-8000-000000000001', 'Abuela (ejemplo)')$$,
  'Solo el dueño crea el libro de una persona representada', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(
  public.fin_crear_libro_representado('b0000000-0000-4000-8000-000000000001', 'Abuela (ejemplo)', null,
                                      'f1000000-0000-4000-8000-0000000000a1'),
  'f1000000-0000-4000-8000-0000000000a1'::uuid, 'La dueña crea el libro de la abuela con el id que manda la app');
select pruebas.igual(
  public.fin_crear_libro_representado('b0000000-0000-4000-8000-000000000001', 'Abuela (ejemplo)', null,
                                      'f1000000-0000-4000-8000-0000000000a1'),
  'f1000000-0000-4000-8000-0000000000a1'::uuid, 'Reintentar devuelve el mismo libro');
select pruebas.igual((select count(*)::int from public.personas where nombre_visible = 'Abuela (ejemplo)'), 1,
  '… sin duplicar a la persona');
select pruebas.igual(
  (select papel from public.fin_libro_miembros
    where libro_id = 'f1000000-0000-4000-8000-0000000000a1' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'albacea', 'Quien lo crea queda como albacea');
select pruebas.ok(exists (
  select 1 from public.fin_libros l join public.personas p on p.id = l.titular_id
   where l.id = 'f1000000-0000-4000-8000-0000000000a1' and l.tipo = 'representado' and p.usuario_id is null),
  'La persona representada no tiene cuenta');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas
  where libro_id = 'f1000000-0000-4000-8000-0000000000a1'$$), 3,
  'Su libro nace con Ajustes, Apertura y Por clasificar');
select pruebas.falla($$insert into public.fin_libros (hogar_id, nombre, tipo, titular_id)
  values ('b0000000-0000-4000-8000-000000000001', 'Directo', 'representado', 'e0000000-0000-4000-8000-000000000001')$$,
  'Un libro representado no se crea directo en la tabla', '42501');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.personas where nombre_visible like 'Abuela%'$$), 0,
  'Una familiar no ve a la persona representada');

rollback;
