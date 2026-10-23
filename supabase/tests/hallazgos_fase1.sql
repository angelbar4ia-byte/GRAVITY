-- =============================================================================
-- HALLAZGOS DE LA REVISIÓN DE CALIDAD · Fase 1 (docs/revisiones/fase-1.md)
-- =============================================================================
-- FALLA HOY A PROPÓSITO: cada bloque demuestra un hallazgo del servidor.
-- No entra en la corrida normal (el nombre no empieza con NN_). Para correrlo:
--   bash supabase/tests/correr.sh hallazgos_fase1.sql
-- Cada comprobación se reporta por separado (NOTICE "hallazgo abierto" o
-- "ok"); al final falla con la lista de los que siguen abiertos. Cuando el
-- backend los arregle, mueve las afirmaciones a un archivo NN_*.sql y borra
-- este (como se hizo con hallazgos_fase0.sql).
--
-- Cada intento corre en una subtransacción que siempre se deshace, así que no
-- deja datos y los hallazgos no se contaminan entre sí. Un intento que el
-- servidor rechaza (error) cuenta como RESUELTO.
-- =============================================================================
begin;

create temporary table hallazgos (clave text primary key, abierto boolean) on commit drop;
grant select, insert on hallazgos to authenticated, anon, service_role;

-- intento(clave, preparación, ataque):
--   preparación: sentencias que dejan el escenario y eligen quién actúa;
--   ataque: expresión booleana; VERDADERA = el hallazgo sigue abierto. Si lanza
--   un error, el servidor lo frenó (resuelto).
create function pg_temp.intento(p_clave text, p_preparacion text, p_ataque text)
returns void
language plpgsql
as $$
declare
  v_abierto boolean;
  v_detalle text;
begin
  begin
    if p_preparacion is not null then
      execute p_preparacion;
    end if;
    begin
      execute 'select ' || p_ataque into v_abierto;
    exception when others then
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

-- -----------------------------------------------------------------------------
-- I-S1. Un coadministrador (cualquier miembro de un libro compartido) cierra la
-- membresía de la dueña: ella pierde el libro compartido y la pareja se queda
-- como único miembro (la especificación pide 2 o más). Nadie más puede
-- devolverla.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'I-S1: la pareja expulsa a la dueña del libro compartido (hasta = now())',
  $$select pruebas.como('alex@ejemplo.test')$$,
  $$pruebas.afecta('update public.fin_libro_miembros set hasta = now()
      where libro_id = ''f1000000-0000-4000-8000-000000000001''
        and persona_id = pruebas.id_persona(''ana@ejemplo.test'')') > 0$$);

-- -----------------------------------------------------------------------------
-- I-S2. La cuenta maestra lee los libros ajenos directamente por la API sin
-- dejar rastro: la consulta solo queda en la bitácora si la APP llama a
-- fin_registrar_consulta_maestra(). D19: "cada consulta a lo de otra persona
-- queda en la bitácora". La prueba exige que, sin consulta registrada, el
-- libro ajeno no se lea (una forma de cerrarlo; hay otras).
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'I-S2: la cuenta maestra lee el libro de Ana sin consulta en la bitácora',
  $$select pruebas.como('marta@ejemplo.test')$$,
  $$pruebas.cuenta('select * from public.fin_movimientos
      where libro_origen_id = pruebas.libro_personal(''ana@ejemplo.test'')') > 0
    and pruebas.cuenta('select * from public.bitacora
      where accion = ''finanzas.consulta_maestra''') = 0$$);

-- -----------------------------------------------------------------------------
-- I-S3. El albacea registra en el libro de Papá SIN en_nombre_de y SIN motivo
-- (un gasto y una transferencia hacia su banco personal): el servidor solo
-- exige motivo cuando en_nombre_de viene puesto. Regla 50 y criterio 34: todo
-- movimiento del libro representado va en su nombre y con motivo.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'I-S3a: el albacea registra un gasto de Papá sin en_nombre_de ni motivo',
  $$select pruebas.como('ana@ejemplo.test')$$,
  $$pruebas.registrar('gasto', 'c6000000-0000-4000-8000-000000000002',
      'c2000000-0000-4000-8000-000000000001', 5000) is not null$$);

select pg_temp.intento(
  'I-S3b: el albacea pasa dinero de Papá a su banco personal sin en_nombre_de ni motivo',
  $$select pruebas.como('ana@ejemplo.test')$$,
  $$pruebas.registrar('transferencia', 'c6000000-0000-4000-8000-000000000001',
      'c3000000-0000-4000-8000-000000000001', 100000) is not null$$);

-- -----------------------------------------------------------------------------
-- I-S4. Si el albacea deja de tener acceso (baja del hogar), su cargo sigue
-- "vigente" en fin_libro_miembros: el suplente no escribe ni administra y nadie
-- puede cerrar el cargo. El libro de Papá queda bloqueado. D17: el suplente
-- escribe "si no hay albacea vigente"; D5: la baja quita el acceso de
-- inmediato. Escenario: Alex albacea, Ana suplente; Ana da de baja a Alex.
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'I-S4: con el albacea dado de baja, el suplente no puede escribir en el libro de Papá',
  $$select pruebas.como_postgres();
    update public.fin_libro_miembros set hasta = desde
     where libro_id = 'f1000000-0000-4000-8000-000000000002';
    insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel) values
      ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
       pruebas.id_persona('alex@ejemplo.test'), 'albacea'),
      ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
       pruebas.id_persona('ana@ejemplo.test'), 'albacea_suplente');
    select pruebas.como('ana@ejemplo.test');
    update public.membresias set activa = false, hasta = now()
     where persona_id = pruebas.id_persona('alex@ejemplo.test')$$,
  $$not public.fin_puede('f1000000-0000-4000-8000-000000000002', 'escribir')$$);

-- -----------------------------------------------------------------------------
-- I-S5. Cualquier miembro (también un familiar sin Finanzas) agrega a la
-- bitácora entradas "finanzas.consulta_maestra" con el libro_id de otra
-- persona: aparecen en su historial con un autor falso (la dueña vería "Carla
-- consultó tu libro"). README, "Pendientes conocidos".
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'I-S5: un familiar fabrica una consulta de la cuenta maestra en la bitácora de Ana',
  $$select pruebas.como('carla@ejemplo.test');
    insert into public.bitacora (hogar_id, accion, tabla, registro_id, detalle)
    values ('b0000000-0000-4000-8000-000000000001', 'finanzas.consulta_maestra', 'fin_libros',
            pruebas.libro_personal('ana@ejemplo.test')::text,
            jsonb_build_object('libro_id', pruebas.libro_personal('ana@ejemplo.test')::text, 'tipo', 'personal'));
    select pruebas.como('ana@ejemplo.test')$$,
  $$pruebas.cuenta('select * from public.bitacora where accion = ''finanzas.consulta_maestra''
      and persona_id = pruebas.id_persona(''carla@ejemplo.test'')') > 0$$);

-- -----------------------------------------------------------------------------
-- M-S6. La cuenta maestra "nunca escribe en lo ajeno" (regla 55), pero como
-- tiene rol con Finanzas administra lo del HOGAR: puede congelar todas las
-- cuentas de gasto, y entonces nadie registra gastos (55000). (Lo mismo puede
-- hacer cualquier otro adulto con Finanzas: decisión del dueño.)
-- -----------------------------------------------------------------------------
select pg_temp.intento(
  'M-S6: la cuenta maestra congela las cuentas de gasto del hogar y bloquea los gastos de todos',
  $$select pruebas.como('marta@ejemplo.test')$$,
  $$pruebas.afecta('update public.fin_cuentas set estado = ''congelada'' where libro_id is null') > 0$$);

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
  'Hallazgos del servidor (Fase 1) resueltos');

rollback;
