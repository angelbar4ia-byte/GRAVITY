-- =============================================================================
-- HALLAZGOS DE LA REVISIÓN DE CALIDAD · Fase 1b (docs/revisiones/fase-1b.md)
-- =============================================================================
-- FALLA HOY A PROPÓSITO: cada bloque demuestra un hallazgo del servidor.
-- No entra en la corrida normal (el nombre no empieza con NN_). Para correrlo:
--   bash supabase/tests/correr.sh hallazgos_fase1b.sql
-- Cada comprobación se reporta por separado (NOTICE "hallazgo abierto" o "ok");
-- al final falla con la lista de los que siguen abiertos. Cuando backend los
-- arregle, mueve las afirmaciones a un archivo NN_*.sql y borra este.
--
-- Cada intento corre en una subtransacción que siempre se deshace, así que no
-- deja datos y los hallazgos no se contaminan entre sí. Una preparación o un
-- ataque que el servidor rechaza con un error cuenta como RESUELTO, salvo en los
-- intentos que miden "¿se puede recuperar?" (ver pg_temp.puede).
-- =============================================================================
begin;

create temporary table hallazgos (clave text primary key, abierto boolean) on commit drop;
grant select, insert on hallazgos to authenticated, anon, service_role;

-- intento(clave, preparación, ataque): VERDADERO = el hallazgo sigue abierto.
create function pg_temp.intento(p_clave text, p_preparacion text, p_ataque text)
returns void
language plpgsql
as $$
declare
  v_abierto boolean := false;
  v_detalle text;
begin
  begin
    begin
      if p_preparacion is not null then
        execute p_preparacion;
      end if;
      execute 'select ' || p_ataque into v_abierto;
    exception when sqlstate 'ZZ001' then
      raise;
    when others then
      v_abierto := false;
    end;
    raise exception using errcode = 'ZZ001', message = 'fin del intento',
                          detail = coalesce(v_abierto, false)::text;
  exception when sqlstate 'ZZ001' then
    get stacked diagnostics v_detalle = pg_exception_detail;
  end;
  insert into hallazgos values (p_clave, v_detalle::boolean);
end
$$;

-- puede(sql): ¿la sentencia se ejecuta sin error y cambia al menos una fila?
-- Sirve para los hallazgos del tipo "la persona debería poder y no puede".
create function pg_temp.puede(p_sql text) returns boolean
language plpgsql
as $$
declare
  v_n integer;
begin
  execute p_sql;
  get diagnostics v_n = row_count;
  return v_n > 0;
exception when others then
  return false;
end
$$;
grant execute on function pg_temp.puede(text) to authenticated, anon, service_role;

-- -----------------------------------------------------------------------------
-- N1. Cualquier miembro llena la base con la bitácora. La regla de inserción
-- solo mira quién escribe y qué acción, no cuántas entradas ni cuánto pesan (hasta
-- 32 KB cada una). En el plan gratis (500 MB) bastan unas pocas sentencias para que
-- el proyecto deje de aceptar escrituras para TODA la familia. Es M2 (parte 2) de la
-- Fase 0, que seguía pendiente; aquí con la medición: 1,200 entradas de ~30 KB
-- (36 MB) entran en una sola sentencia desde una cuenta de FAMILIAR (sin Finanzas).
-- Esperado: un tope por persona (p. ej. 1,000 entradas por día o por sentencia).
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'N1: un familiar mete 36 MB en la bitácora con una sola sentencia',
  $$select pruebas.como('carla@ejemplo.test')$$,
  $$pruebas.afecta('insert into public.bitacora (hogar_id, accion, detalle)
      select ''b0000000-0000-4000-8000-000000000001'', ''relleno'',
             jsonb_build_object(''x'', repeat(''a'', 30000))
        from generate_series(1, 1200)') = 1200$$);

select pg_temp.intento(
  'N1b: la cuenta Hogar (la de la tablet pública) también puede',
  $$select pruebas.como('casa@ejemplo.test')$$,
  $$pruebas.afecta('insert into public.bitacora (hogar_id, accion, detalle)
      select ''b0000000-0000-4000-8000-000000000001'', ''relleno'',
             jsonb_build_object(''x'', repeat(''a'', 30000))
        from generate_series(1, 1200)') = 1200$$);

-- -----------------------------------------------------------------------------
-- N2. "Motivo obligatorio" en el libro de Papá: el servidor compara contra ''
-- después de btrim(), que solo quita ESPACIOS. Un motivo de un tabulador o de un
-- salto de línea cuenta como motivo, y la salvaguarda de D19 (motivo en TODO
-- movimiento en nombre de Papá) queda en la forma y no en el fondo. (Un punto o
-- "x" también pasan; eso lo decide el dueño, no se prueba aquí.)
-- Esperado: un motivo en blanco (espacio, tabulador, salto de línea) se rechaza.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'N2a: el albacea registra un gasto de Papá con un tabulador como motivo',
  $$select pruebas.como('ana@ejemplo.test')$$,
  $$pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
      'c2000000-0000-4000-8000-000000000001', 5000, p_motivo => E'\t',
      p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null$$);

select pg_temp.intento(
  'N2b: ... o con un salto de línea y un espacio',
  $$select pruebas.como('ana@ejemplo.test')$$,
  $$pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
      'c3000000-0000-4000-8000-000000000001', 100000, p_motivo => E'\r\n ',
      p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001') is not null$$);

-- -----------------------------------------------------------------------------
-- N3. La salida del libro de Papá solo avisa al suplente si el destino es un libro
-- PERSONAL. Pasar el dinero a un compartido (del que el albacea es miembro) y de
-- ahí a su cuenta personal evita el aviso en dos pasos: la segunda transferencia
-- sale de un compartido, no del libro representado. D19 (23/oct): "las salidas
-- hacia un libro personal avisan al suplente". Ese camino indirecto es una salida
-- hacia un libro personal. Esperado: toda salida del libro de Papá hacia OTRO libro
-- (no solo personal) deja la entrada finanzas.salida_libro_representado.
-- Escenario: Beto y Ana comparten un libro del que el suplente (Alex) no es miembro.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'N3: Papá -> compartido de Ana y Beto (sin el suplente) no deja aviso para el suplente',
  $$select pruebas.como_postgres();
    select pruebas.nuevo_adulto('beto@ejemplo.test');
    select pruebas.como('ana@ejemplo.test');
    insert into public.fin_libros (id, hogar_id, nombre, tipo)
      values ('f2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Ana y Beto', 'compartido');
    insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
      values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000001',
              pruebas.id_persona('beto@ejemplo.test'), 'miembro');
    insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
      values ('c9000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
              'f2000000-0000-4000-8000-000000000001', 'Caja de Ana y Beto', 'efectivo');
    select pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
      'c9000000-0000-4000-8000-000000000001', 100000, p_motivo => 'Pago de la renta (ejemplo)',
      p_en_nombre_de => 'e0000000-0000-4000-8000-000000000001');
    select pruebas.como('alex@ejemplo.test')$$,
  $$not exists (select 1 from public.bitacora where accion = 'finanzas.salida_libro_representado')$$);

-- -----------------------------------------------------------------------------
-- N4. El libro de Papá se puede quedar sin nadie que lo lleve y ni el dueño lo
-- recupera. Para agregar un albacea hay que poder "administrar" el libro, y eso
-- exige ser albacea (o suplente sin albacea) VIGENTE; el dueño del hogar no cuenta.
-- Si el albacea deja el cargo sin suplente (un toque equivocado en "Dejar el
-- cargo"), nadie con sesión normal puede nombrar a otro: solo service_role.
-- Esperado: el dueño del hogar puede volver a nombrar albacea.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'N4: la dueña deja el cargo de albacea sin suplente y ya no puede volver a nombrarse',
  $$select pruebas.como('ana@ejemplo.test');
    update public.fin_libro_miembros set hasta = now()
     where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea_suplente';
    update public.fin_libro_miembros set hasta = now()
     where libro_id = 'f1000000-0000-4000-8000-000000000002' and papel = 'albacea'$$,
  $$not pg_temp.puede('insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
      values (''b0000000-0000-4000-8000-000000000001'', ''f1000000-0000-4000-8000-000000000002'',
              pruebas.id_persona(''ana@ejemplo.test''), ''albacea'')')$$);

-- -----------------------------------------------------------------------------
-- N5. Un compartido sin administrador. Si quien lo creó es dado de baja DEL HOGAR
-- (no se "sale" del libro), `creado_por` sigue apuntando a una persona sin acceso:
-- nadie puede agregar miembros, cambiar la visibilidad ni archivar (la dueña solo
-- puede si es miembro). El relevo del administrador ocurre únicamente cuando alguien
-- cierra su fila del libro. Esperado: al perder el administrador su rol en el hogar,
-- el cargo pasa al miembro vigente más antiguo, como cuando se sale.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'N5: se da de baja al administrador de un compartido y el que queda no puede agregar a nadie',
  $$select pruebas.como_postgres();
    select pruebas.nuevo_adulto('beto@ejemplo.test');
    select pruebas.nuevo_adulto('caro@ejemplo.test');
    insert into public.fin_libros (id, hogar_id, nombre, tipo, creado_por)
      values ('f2000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Beto y Alex',
              'compartido', pruebas.id_persona('beto@ejemplo.test'));
    insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
      values ('b0000000-0000-4000-8000-000000000001', 'f2000000-0000-4000-8000-000000000002',
              pruebas.id_persona('alex@ejemplo.test'), 'miembro');
    update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('beto@ejemplo.test');
    select pruebas.como('alex@ejemplo.test')$$,
  $$not pg_temp.puede('insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
      values (''b0000000-0000-4000-8000-000000000001'', ''f2000000-0000-4000-8000-000000000002'',
              pruebas.id_persona(''caro@ejemplo.test''), ''miembro'')')$$);

-- -----------------------------------------------------------------------------
-- Reporte
-- -----------------------------------------------------------------------------
select pruebas.como_postgres();
do $$
declare
  r record;
begin
  for r in select * from hallazgos order by clave loop
    if r.abierto then
      raise notice 'hallazgo abierto - %', r.clave;
    else
      raise notice 'ok - resuelto: %', r.clave;
    end if;
  end loop;
end
$$;
select pruebas.igual(
  (select string_agg(clave, ' | ' order by clave) from hallazgos where abierto),
  null::text,
  'Hallazgos del servidor (Fase 1b) resueltos');

rollback;
