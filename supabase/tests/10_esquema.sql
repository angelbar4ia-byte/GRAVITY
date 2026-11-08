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

-- La matriz de la sección 5, con los cambios de D18 y D19 (Fase 1).
select pruebas.igual((select count(*)::int from public.permisos_rol), 59,
  'La matriz tiene 59 permisos (sección 5 + gravity alineado con la app + D18 y D19); la hermana es cuidadora (D5)');
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'dueno' and modulo = 'finanzas'),
  'administrar=propio,escribir=propio,leer=propio', 'D19: Dueño: Finanzas propio (su libro y los compartidos)');
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'coadministrador' and modulo = 'finanzas'),
  'administrar=propio,escribir=propio,leer=propio', 'D19 (P1, P2): Coadministrador: Finanzas propio');
select pruebas.ok(
  (select bool_and(nota like 'D19%') from public.permisos_rol
    where modulo = 'finanzas' and rol in ('dueno', 'coadministrador')),
  'D19: la nota de cada permiso de Finanzas cita la decisión');
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
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'cuidador' and modulo = 'gravity'),
  'escribir=restringido,leer=restringido', 'D18: Cuidador: GRAVITY restringido (sus solicitudes y recordatorios)');
select pruebas.igual(
  (select count(*)::int from public.permisos_rol where rol = 'casa' and modulo = 'ajustes'),
  0, 'Casa: sin Ajustes');
select pruebas.igual(
  (select string_agg(rol::text, ',' order by rol)
     from public.permisos_rol where modulo = 'ajustes' and accion = 'administrar'),
  'dueno', 'Solo el dueño administra Ajustes (personas, roles, invitaciones)');

-- Alineación con el espejo de la app (revisión de la Fase 0, hallazgo I1).
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'dueno' and modulo = 'gravity'),
  'administrar=propio,escribir=propio,leer=propio', 'D18: Dueño: GRAVITY propio (cada quien su historial)');
select pruebas.igual(
  (select string_agg(rol::text || ':' || accion::text || '=' || alcance::text, ',' order by rol, accion)
     from public.permisos_rol where modulo = 'gravity' and rol in ('coadministrador', 'familiar', 'casa')),
  'casa:escribir=propio,casa:leer=propio,coadministrador:escribir=propio,'
  'coadministrador:leer=propio,familiar:escribir=propio,familiar:leer=propio',
  'I1: Coadministrador, familiar y casa: GRAVITY solo lo propio');
select pruebas.igual(
  (select string_agg(accion::text || '=' || alcance::text, ',' order by accion)
     from public.permisos_rol where rol = 'coadministrador' and modulo = 'cuidados'),
  'escribir=restringido,leer=restringido',
  'I1: Coadministrador: Cuidados restringido (sin acceso hasta que exista el consentimiento)');
select pruebas.igual(
  (select count(*)::int from public.permisos_rol where alcance = 'restringido' and accion = 'administrar'),
  0, 'Ningún alcance restringido administra');

-- Finanzas (Fase 1): libros solo agregar, vistas con security_invoker, bitácora.
select pruebas.ok(to_regclass('public.finanzas_muestra') is null, 'La muestra de la Fase 0 ya no existe');
select pruebas.igual(
  (select coalesce(string_agg(t.tabla, ', ' order by t.tabla), '')
     from unnest(array['fin_movimientos', 'fin_conciliaciones', 'fin_cierres', 'fin_cierre_partidas',
                       'fin_cierre_abonos', 'fin_importaciones']) as t(tabla)
    where (select count(*) from pg_trigger g
            where g.tgrelid = ('public.' || t.tabla)::regclass and not g.tgisinternal
              and g.tgfoid = 'public.impedir_cambios_solo_agregar()'::regprocedure) <> 2),
  '', 'Libros solo agregar de Finanzas con los dos triggers de impedir_cambios_solo_agregar()');
select pruebas.igual(
  (select coalesce(string_agg(r.rol || ':' || t.tabla || ':' || p.priv, ', '), '')
     from unnest(array['fin_movimientos', 'fin_conciliaciones', 'fin_cierres', 'fin_cierre_partidas',
                       'fin_cierre_abonos', 'fin_importaciones', 'fin_estados_cuenta', 'fin_retiros_ahorro']) as t(tabla),
          unnest(array['anon', 'authenticated', 'service_role']) as r(rol),
          unnest(array['UPDATE', 'DELETE', 'TRUNCATE']) as p(priv)
    where (p.priv = 'UPDATE' and has_any_column_privilege(r.rol, 'public.' || t.tabla, 'UPDATE'))
       or (p.priv <> 'UPDATE' and has_table_privilege(r.rol, 'public.' || t.tabla, p.priv))),
  '', 'Libros solo agregar de Finanzas sin UPDATE (ni de una columna), DELETE ni TRUNCATE para la API');
select pruebas.igual(
  (select count(*)::int from pg_policy
    where polrelid in ('public.fin_movimientos'::regclass, 'public.fin_conciliaciones'::regclass,
                       'public.fin_cierres'::regclass, 'public.fin_cierre_partidas'::regclass,
                       'public.fin_cierre_abonos'::regclass, 'public.fin_importaciones'::regclass,
                       'public.fin_estados_cuenta'::regclass, 'public.fin_retiros_ahorro'::regclass)
      and polcmd in ('w', 'd')),
  0, 'Libros solo agregar de Finanzas sin reglas de UPDATE ni DELETE');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v' and c.relname like 'fin\_%'
      and not coalesce(c.reloptions @> array['security_invoker=true'], false)),
  '', 'Las vistas fin_v_* respetan la RLS de quien consulta (security_invoker)');
select pruebas.igual(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v' and c.relname like 'fin\_v\_%'),
  5, 'Existen fin_v_saldos, fin_v_gasto_semana y las tres de la Fase 2 (deuda_resumen, bolsa_saldo, estados_cuenta_vigentes)');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'fin\_%'
      and not exists (select 1 from pg_trigger g
                       where g.tgrelid = c.oid and not g.tgisinternal
                         and g.tgfoid = 'public.registrar_cambio_en_bitacora()'::regprocedure)),
  '', 'Toda tabla fin_* registra sus cambios en la bitácora');
select pruebas.igual(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'fin\_%'),
  33, 'Las 33 tablas de Finanzas (21 de la Fase 1, 5 de la Fase 2, 1 de la Fase 4 y 6 del bloque 1 de la fase 8)');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'fin\_%'
      and not exists (select 1 from pg_attribute a
                       where a.attrelid = c.oid and a.attname = 'hogar_id' and a.attnotnull)),
  '', 'Toda tabla fin_* lleva hogar_id obligatorio');
select pruebas.ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'membresias_una_maestra_por_hogar'),
  'D19: una sola cuenta maestra por hogar (índice único parcial)');
select pruebas.ok(
  not has_column_privilege('authenticated', 'public.membresias', 'es_maestra', 'UPDATE'),
  'D19: la cuenta maestra solo se asigna con asignar_cuenta_maestra()');

-- Salvaguardas de Finanzas (20261023000000): triggers en su sitio y funciones internas
-- que la app no puede llamar como RPC.
select pruebas.igual(
  (select string_agg(g.tgname, ',' order by g.tgname) from pg_trigger g
    where not g.tgisinternal
      and ((g.tgrelid = 'public.fin_libro_miembros'::regclass and g.tgname = 'fin_c_proteger')
        or (g.tgrelid = 'public.fin_movimientos'::regclass and g.tgname in ('fin_b_representado', 'fin_y_salida_representado')))),
  'fin_b_representado,fin_c_proteger,fin_y_salida_representado',
  'I1 e I3: triggers de membresías del compartido y del libro representado instalados');
select pruebas.igual(
  (select coalesce(string_agg(p.proname || ':' || r.rol, ', ' order by p.proname, r.rol), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
          unnest(array['anon', 'authenticated', 'service_role']) as r(rol)
    where n.nspname = 'public'
      and p.proname in ('fin_vigencia_consulta_maestra', 'fin_adulto_con_finanzas', 'fin_libro_miembros_proteger',
                        'fin_movimientos_representado', 'fin_movimientos_salida_representado')
      and has_function_privilege(r.rol, p.oid, 'execute')),
  '', 'Los ayudantes y triggers de las salvaguardas no se ejecutan desde la API');
select pruebas.ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'bitacora_consulta_maestra_idx'),
  'I2: índice parcial para buscar la consulta vigente de la cuenta maestra');
select pruebas.igual(public.fin_vigencia_consulta_maestra(), interval '30 minutes' ,
  'I2: la consulta de la cuenta maestra vale 30 minutos');

-- Respuestas del dueño del 23/oct (20261024): visibilidad, cuenta maestra con login propio y archivo.
select pruebas.igual(
  (select string_agg(g.tgrelid::regclass::text || ':' || g.tgname, ',' order by g.tgrelid::regclass::text, g.tgname)
     from pg_trigger g
    where not g.tgisinternal
      and g.tgname in ('fin_c_proteger', 'fin_c_sin_maestra', 'fin_d_archivar_cuenta')),
  'fin_categorias:fin_d_archivar_cuenta,fin_libro_miembros:fin_c_proteger,fin_libro_miembros:fin_c_sin_maestra,fin_libros:fin_c_proteger',
  '23/oct: triggers de administrador, salida, maestra de solo lectura y archivo de la cuenta de gasto instalados');
select pruebas.igual(
  (select column_default || ' ' || is_nullable from information_schema.columns
    where table_schema = 'public' and table_name = 'fin_libros' and column_name = 'visibilidad'),
  '''privada''::text NO', '23/oct: fin_libros.visibilidad es privada por omisión y obligatoria');
select pruebas.ok(
  has_column_privilege('authenticated', 'public.fin_libros', 'visibilidad', 'INSERT')
  and has_column_privilege('authenticated', 'public.fin_libros', 'visibilidad', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.fin_libros', 'creado_por', 'UPDATE'),
  '23/oct: la app manda y cambia visibilidad; creado_por (el administrador) solo lo cambia el servidor');
select pruebas.ok(
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'crear_invitacion'),
  '23/oct: una sola crear_invitacion (con p_es_maestra), sin sobrecargas ambiguas');
select pruebas.ok(
  exists (select 1 from information_schema.columns
           where table_schema = 'public' and table_name = 'invitaciones' and column_name = 'es_maestra'),
  '23/oct: las invitaciones llevan es_maestra');
select pruebas.igual(
  (select coalesce(string_agg(p.proname || ':' || r.rol, ', ' order by p.proname, r.rol), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
          unnest(array['anon', 'authenticated']) as r(rol)
    where n.nspname = 'public'
      and p.proname in ('fin_libro_miembros_sin_maestra', 'fin_libros_proteger', 'fin_categorias_archivar_cuenta')
      and has_function_privilege(r.rol, p.oid, 'execute')),
  '', '23/oct: los triggers nuevos no se ejecutan desde la API');
select pruebas.ok(
  not has_function_privilege('anon', 'public.fin_solo_lectura(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.fin_puede_salir(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.crear_invitacion(uuid, text, text, integer, boolean)', 'execute')
  and has_function_privilege('authenticated', 'public.crear_invitacion(uuid, text, text, integer, boolean)', 'execute'),
  '23/oct: anon no ejecuta las funciones nuevas; authenticated sí crea invitaciones');

-- Endurecimiento de la Fase 1b (20261026): tope de la bitácora, motivo, relevo y albacea.
select pruebas.igual(
  (select string_agg(g.tgrelid::regclass::text || ':' || g.tgname, ',' order by g.tgrelid::regclass::text, g.tgname)
     from pg_trigger g
    where not g.tgisinternal
      and g.tgname in ('bitacora_tope', 'fin_c_motivo', 'fin_z_relevo_administrador')),
  'bitacora:bitacora_tope,fin_conciliaciones:fin_c_motivo,fin_movimientos:fin_c_motivo,membresias:fin_z_relevo_administrador',
  '1b: triggers del tope de la bitácora, del motivo y del relevo del administrador instalados');
select pruebas.ok(
  (select g.tgtype & 1 = 0 from pg_trigger g where g.tgname = 'bitacora_tope' and g.tgrelid = 'public.bitacora'::regclass),
  '1b N1: el tope de la bitácora es un trigger por sentencia (uno por fila no ve las inserciones en lote)');
select pruebas.igual(
  (select coalesce(string_agg(p.proname || ':' || r.rol, ', ' order by p.proname, r.rol), '')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
          unnest(array['anon', 'authenticated', 'service_role']) as r(rol)
    where n.nspname = 'public'
      and p.proname in ('bitacora_tope_por_persona', 'fin_motivo_valido', 'fin_motivo_validar',
                        'fin_libro_asegurar_administrador', 'fin_membresia_relevo_administrador')
      and has_function_privilege(r.rol, p.oid, 'execute')),
  '', '1b: los ayudantes y triggers nuevos no se ejecutan desde la API');
select pruebas.ok(
  has_function_privilege('authenticated', 'public.fin_nombrar_albacea(uuid, uuid, text)', 'execute')
  and not has_function_privilege('anon', 'public.fin_nombrar_albacea(uuid, uuid, text)', 'execute')
  and not has_function_privilege('service_role', 'public.fin_nombrar_albacea(uuid, uuid, text)', 'execute'),
  '1b N4: fin_nombrar_albacea solo la ejecuta authenticated (y adentro exige ser el dueño)');
select pruebas.ok(
  (select p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%') from pg_proc p
    where p.oid = 'public.fin_nombrar_albacea(uuid, uuid, text)'::regprocedure),
  '1b N4: fin_nombrar_albacea es SECURITY DEFINER con search_path fijo');

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

-- Red de seguridad para lo que se cree después en public (hallazgo M1): una
-- función o tabla de una fase futura creada SIN revoke ni grant explícitos.
-- Va al final: la tabla de prueba no tiene RLS (lo revisan las de arriba).
create function public.funcion_de_una_fase_futura() returns integer
language sql security definer set search_path = '' as $$ select 1 $$;
create table public.tabla_de_una_fase_futura (id uuid primary key);
create sequence public.secuencia_de_una_fase_futura;

select pruebas.ok(
  not has_function_privilege('anon', 'public.funcion_de_una_fase_futura()', 'execute')
  and not has_function_privilege('public', 'public.funcion_de_una_fase_futura()', 'execute'),
  'M1: anon (ni PUBLIC) ejecuta una función creada después sin revoke explícito');
select pruebas.igual(
  (select coalesce(string_agg(p.priv, ','), '')
     from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(priv)
    where has_table_privilege('anon', 'public.tabla_de_una_fase_futura', p.priv)),
  '', 'M1: anon no recibe nada en una tabla creada después');
select pruebas.ok(
  not has_sequence_privilege('anon', 'public.secuencia_de_una_fase_futura', 'usage')
  and not has_sequence_privilege('anon', 'public.secuencia_de_una_fase_futura', 'select'),
  'M1: anon no recibe nada en una secuencia creada después');
select pruebas.igual(
  (select coalesce(string_agg(r.rol || ':' || p.priv, ','), '')
     from unnest(array['authenticated', 'service_role']) as r(rol),
          unnest(array['TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(priv)
    where has_table_privilege(r.rol, 'public.tabla_de_una_fase_futura', p.priv)
      and not (r.rol = 'service_role' and p.priv <> 'TRUNCATE')),
  '', 'M1: authenticated no recibe TRUNCATE, REFERENCES ni TRIGGER, ni service_role TRUNCATE, en una tabla creada después');

rollback;
