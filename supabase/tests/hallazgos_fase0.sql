-- =============================================================================
-- HALLAZGOS DE LA REVISIÓN DE CALIDAD · Fase 0 (docs/revisiones/fase-0.md)
-- =============================================================================
-- FALLA HOY A PROPÓSITO: cada bloque demuestra un hallazgo MENOR del servidor.
-- No entra en la corrida normal (el nombre no empieza con NN_). Para correrlo:
--   bash supabase/tests/correr.sh hallazgos_fase0.sql
-- Cada comprobación se reporta por separado (NOTICE "hallazgo abierto" o
-- "ok"); al final falla con la lista de los que siguen abiertos. Cuando se
-- arreglen, el backend puede mover estas afirmaciones a un archivo NN_*.sql.
-- =============================================================================
begin;

create temporary table hallazgos (clave text primary key, abierto boolean) on commit drop;
grant select, insert on hallazgos to authenticated, anon, service_role;

-- -----------------------------------------------------------------------------
-- M1. La "red de seguridad" de privilegios por omisión no cubre lo que se cree
-- después en public: una función nueva queda ejecutable por anon (vía PUBLIC,
-- que un REVOKE por esquema no quita) y una tabla nueva da TRUNCATE (que salta
-- RLS) a authenticated. Hoy 10_esquema.sql lo atrapa al correr las pruebas,
-- pero una migración aplicada sin correrlas lo deja abierto.
-- -----------------------------------------------------------------------------
select pruebas.como_postgres();
create function public.funcion_de_una_fase_futura() returns integer
language sql security definer set search_path = '' as $$ select 1 $$;
create table public.tabla_de_una_fase_futura (id uuid primary key);

insert into hallazgos values
  ('M1a: anon ejecuta una función creada después sin REVOKE explícito',
   has_function_privilege('anon', 'public.funcion_de_una_fase_futura()', 'execute')),
  ('M1b: authenticated recibe TRUNCATE en una tabla creada después',
   has_table_privilege('authenticated', 'public.tabla_de_una_fase_futura', 'truncate'));

-- -----------------------------------------------------------------------------
-- M2. Cualquier miembro (incluso la cuenta Casa) escribe en la bitácora
-- entradas que parecen automáticas: acción "borrar" sobre finanzas_muestra con
-- un detalle inventado. El dueño no distingue lo escrito por los triggers.
-- -----------------------------------------------------------------------------
do $$
begin
  perform pruebas.como('casa@ejemplo.test');
  begin
    insert into public.bitacora (hogar_id, accion, tabla, registro_id, detalle)
    values ('b0000000-0000-4000-8000-000000000001', 'borrar', 'finanzas_muestra',
            'c0000000-0000-4000-8000-000000000001',
            '{"antes": {"monto_centavos": 185000, "descripcion": "Despensa semanal (ejemplo)"}}');
    insert into hallazgos values
      ('M2: la cuenta Casa fabrica entradas con acciones reservadas a los triggers', true);
  exception when insufficient_privilege or check_violation then
    insert into hallazgos values
      ('M2: la cuenta Casa fabrica entradas con acciones reservadas a los triggers', false);
  end;
  perform pruebas.como_postgres();
end
$$;

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
  'Hallazgos menores del servidor resueltos');

rollback;
