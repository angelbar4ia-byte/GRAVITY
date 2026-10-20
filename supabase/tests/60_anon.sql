-- Sin sesión (anon, la llave pública de la app) no se ve ni se hace nada.
begin;

-- Cada tabla de public, también las que se agreguen en fases futuras.
select pruebas.como_anon();
do $$
declare
  v_tabla text;
begin
  for v_tabla in
    select format('%I.%I', n.nspname, c.relname)
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
     order by c.relname
  loop
    perform pruebas.falla(format('select * from %s', v_tabla), 'anon no lee ' || v_tabla, '42501');
  end loop;
end
$$;

select pruebas.falla($$insert into public.bitacora (accion) values ('anon')$$,
  'anon no escribe en la bitácora', '42501');
select pruebas.falla($$insert into public.finanzas_muestra (hogar_id, descripcion, monto_centavos)
  values ('b0000000-0000-4000-8000-000000000001', 'anon', 1)$$, 'anon no registra dinero', '42501');
select pruebas.falla($$select public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'leer')$$,
  'anon no ejecuta puede()', '42501');
select pruebas.falla($$select public.crear_hogar('Hogar anónimo')$$, 'anon no crea hogares', '42501');
select pruebas.falla($$select * from public.mis_permisos('b0000000-0000-4000-8000-000000000001')$$,
  'anon no consulta permisos', '42501');

-- Aunque traiga un "sub" falsificado del dueño, sigue siendo anon.
select pruebas.como_anon(pruebas.id_usuario('ana@ejemplo.test'));
select pruebas.falla('select * from public.finanzas_muestra',
  'anon con sub falsificado no lee dinero', '42501');
select pruebas.falla('select * from public.personas',
  'anon con sub falsificado no lee personas', '42501');

rollback;
