-- Pruebas del esquema: RLS en todo, funciones seguras, privilegios y matriz.
begin;

-- RLS activado en TODAS las tablas de public (también las que se agreguen después).
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  '', 'RLS activado en todas las tablas de public');

-- Toda función SECURITY DEFINER de public fija search_path.
select pruebas.igual(
  (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg
                       where cfg like 'search_path=%')),
  '', 'Toda función SECURITY DEFINER de public fija search_path');

-- anon no tiene privilegios sobre ninguna tabla ni función de public.
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
      and (has_table_privilege('anon', c.oid, 'select')
        or has_table_privilege('anon', c.oid, 'insert')
        or has_table_privilege('anon', c.oid, 'update')
        or has_table_privilege('anon', c.oid, 'delete')
        or has_table_privilege('anon', c.oid, 'truncate'))),
  '', 'anon no tiene privilegios sobre ninguna tabla de public');
select pruebas.igual(
  (select coalesce(string_agg(p.proname, ', ' order by p.proname), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  '', 'anon no ejecuta ninguna función de public');

-- Nadie de la API puede vaciar tablas (TRUNCATE salta RLS).
select pruebas.igual(
  (select coalesce(string_agg(r.rol || ':' || c.relname, ', '), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace,
          unnest(array['anon', 'authenticated']) as r(rol)
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and has_table_privilege(r.rol, c.oid, 'truncate')),
  '', 'anon y authenticated no tienen TRUNCATE en ninguna tabla');

-- Bitácora: ningún rol de la API tiene UPDATE, DELETE ni TRUNCATE.
select pruebas.igual(
  (select coalesce(string_agg(r.rol || ':' || p.priv, ', '), '')
     from unnest(array['anon', 'authenticated', 'service_role']) as r(rol),
          unnest(array['UPDATE', 'DELETE', 'TRUNCATE']) as p(priv)
    where has_table_privilege(r.rol, 'public.bitacora', p.priv)),
  '', 'Bitácora sin UPDATE, DELETE ni TRUNCATE para anon, authenticated y service_role');
select pruebas.igual(
  (select count(*)::int from pg_trigger
    where tgrelid = 'public.bitacora'::regclass and not tgisinternal
      and tgfoid = 'public.impedir_cambios_solo_agregar()'::regprocedure),
  2, 'Bitácora con triggers de solo agregar (fila y TRUNCATE)');
select pruebas.igual(
  (select count(*)::int from pg_policy
    where polrelid = 'public.bitacora'::regclass and polcmd in ('w', 'd')),
  0, 'Bitácora sin reglas de UPDATE ni DELETE');

-- La matriz de la sección 5.
select pruebas.igual((select count(*)::int from public.permisos_rol), 57,
  'La matriz tiene 57 permisos (sección 5 + módulo gravity propuesto)');
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'dueno' and modulo = 'finanzas'),
  'administrar=total,escribir=total,leer=total', 'Dueño: Finanzas total');
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'coadministrador' and modulo = 'finanzas'),
  'leer=total', 'Coadministrador: Finanzas solo lectura');
select pruebas.igual(
  (select count(*)::int from public.permisos_rol
    where rol in ('familiar', 'casa') and modulo = 'finanzas'),
  0, 'Familiar y Casa: nada de Finanzas');
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',')
     from public.permisos_rol where rol = 'cuidador' and modulo = 'finanzas'),
  'escribir=restringido', 'Cuidador: no lee Finanzas; solo gastos de cuidado propios (Fase 5)');
select pruebas.igual(
  (select count(*)::int from public.permisos_rol
    where modulo = 'habitos' and alcance <> 'propio'),
  0, 'Hábitos: solo lo propio para todos los roles (ni el dueño ve lo de otros)');
select pruebas.igual(
  (select count(*)::int from public.permisos_rol where rol in ('cuidador', 'casa') and modulo = 'habitos'),
  0, 'Cuidador y Casa: nada de Hábitos');
select pruebas.igual(
  (select string_agg(modulo::text, ',' order by modulo)
     from public.permisos_rol where rol = 'cuidador' and accion = 'leer' and alcance = 'total'),
  'casa', 'Cuidador: lectura total solo de Casa; Cuidados por su turno (restringido)');
select pruebas.igual(
  (select count(*)::int from public.permisos_rol where rol = 'casa' and modulo = 'ajustes'),
  0, 'Casa: sin Ajustes');
select pruebas.igual(
  (select string_agg(rol::text, ',' order by rol)
     from public.permisos_rol where modulo = 'ajustes' and accion = 'administrar'),
  'dueno', 'Solo el dueño administra Ajustes (personas, roles, invitaciones)');

-- puede() rechaza nombres mal escritos en lugar de negar en silencio.
select pruebas.falla(
  $$select public.puede('b0000000-0000-4000-8000-000000000001', 'finanza', 'leer')$$,
  'puede() rechaza un módulo mal escrito', '23514');
select pruebas.falla(
  $$select public.puede('b0000000-0000-4000-8000-000000000001', 'finanzas', 'ver')$$,
  'puede() rechaza una acción mal escrita', '23514');

-- Persona automática al crear una cuenta.
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('a0000000-0000-4000-8000-0000000000a1', 'con.nombre@ejemplo.test', '{"nombre": "  Nombre Elegido  "}', now()),
  ('a0000000-0000-4000-8000-0000000000a2', 'sin.nombre@ejemplo.test', '{}', now());
select pruebas.igual(
  (select nombre_visible from public.personas where usuario_id = 'a0000000-0000-4000-8000-0000000000a1'),
  'Nombre Elegido', 'Al registrarse se crea su persona con el nombre elegido');
select pruebas.igual(
  (select nombre_visible from public.personas where usuario_id = 'a0000000-0000-4000-8000-0000000000a2'),
  'sin.nombre', 'Sin nombre, la persona toma la parte del correo antes de la @');

-- Si se elimina la cuenta, la persona queda (la bitácora conserva su nombre).
delete from auth.users where id = 'a0000000-0000-4000-8000-0000000000a2';
select pruebas.ok(
  exists (select 1 from public.personas where nombre_visible = 'sin.nombre' and usuario_id is null),
  'Al eliminar la cuenta, la persona se conserva sin usuario');

rollback;
