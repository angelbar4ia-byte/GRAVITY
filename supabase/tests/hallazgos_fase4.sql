-- Hallazgos ABIERTOS de la revisión de la Fase 4 (docs/revisiones/fase-4.md). ABIERTO = el defecto existe.
-- Uso: psql -f hallazgos_fase4.sql contra un clúster con migraciones y seed (correr.sh con GRAVITY_PG_MANTENER=1).
-- No entra en la corrida normal (el nombre no empieza con NN_).
begin;
create temporary table hallazgos (clave text primary key, abierto boolean, nota text) on commit drop;
grant select, insert on hallazgos to authenticated, anon, service_role;
create function pg_temp.intento(p_clave text, p_preparacion text, p_ataque text)
returns void language plpgsql as $$
declare v_abierto boolean := false; v_detalle text; v_error text;
begin
  begin
    begin
      if p_preparacion is not null then execute p_preparacion; end if;
      execute 'select ' || p_ataque into v_abierto;
    exception when sqlstate 'ZZ001' then raise;
              when others then
      v_abierto := false; v_error := sqlstate || ' ' || sqlerrm;
    end;
    raise exception using errcode = 'ZZ001', message = 'fin del intento', detail = coalesce(v_abierto, false)::text || '|' || coalesce(v_error,'');
  exception when sqlstate 'ZZ001' then
    get stacked diagnostics v_detalle = pg_exception_detail;
  end;
  insert into hallazgos values (p_clave, split_part(v_detalle,'|',1)::boolean, nullif(split_part(v_detalle,'|',2),''));
end $$;
\o /dev/null

-- F4-M1: la app exige 2 letras o dígitos y no todos iguales (motivoValido); el servidor solo cuenta 3 visibles.
select pg_temp.intento('F4-M1 fin_motivo_valido acepta "___" (3 subrayados)', null,
  $$public.fin_motivo_valido('___')$$);
select pg_temp.intento('F4-M1b fin_motivo_valido acepta "aaa" (todos iguales)', null,
  $$public.fin_motivo_valido('aaa')$$);
select pg_temp.intento('F4-M1c fin_motivo_valido acepta "..." (sin letras ni dígitos)', null,
  $$public.fin_motivo_valido('...')$$);

-- F4-A2: D23 dice que la cuenta Casa (tablet pública) no ve ningún menú; la matriz le da lectura.
-- `puede` solo cuenta alcance total/propio; la fila es 'restringido' ("Menú y lista de compras (Fase 7)").
select pg_temp.intento('F4-A2 la cuenta Casa tiene fila de lectura en Alimentación (alcance restringido, permisos_rol)', $$select pruebas.como('casa@ejemplo.test')$$,
  $$public.alcance('b0000000-0000-4000-8000-000000000001', 'alimentacion', 'leer') is not null$$);

-- F4-A3: ajuste del 6/nov: el familiar edita el menú de Papá; la matriz solo le da leer ("su parte").
select pg_temp.intento('F4-A3 el familiar NO puede escribir Alimentación (permisos_rol) aunque D23 lo deja editar el menú de Papá',
  $$select pruebas.como('carla@ejemplo.test')$$,
  $$not public.puede('b0000000-0000-4000-8000-000000000001', 'alimentacion', 'escribir')$$);

-- F4-B1: sin tablas de Alimentación ni de la vista temporal (D23, D24): los permisos solo viven en la app.
select pg_temp.intento('F4-B1 no existen las tablas ali_* (Alimentación solo en memoria en la app)', null,
  $$to_regclass('public.ali_menu') is null and to_regclass('public.ali_menus') is null$$);
select pg_temp.intento('F4-B2 no existe fin_vistas_solicitadas (D24 pendiente)', null,
  $$to_regclass('public.fin_vistas_solicitadas') is null$$);
\o
select pruebas.como_postgres();
select clave, case when abierto then 'ABIERTO' else 'cerrado' end estado, nota from hallazgos order by clave;
rollback;
