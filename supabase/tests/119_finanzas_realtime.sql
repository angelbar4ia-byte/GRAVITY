-- Finanzas · Fase 8, paquete F8-6.6: actualización entre dispositivos con Realtime Broadcast (migración 20261148;
-- docs/specs/fase-8-finanzas-realtime.md). Casos de servidor: tolerancia sin Realtime, un mensaje por libro y por
-- transacción, mensaje sin datos, el envío que falla no estorba, y quién puede suscribirse (política de realtime.messages).
-- El servidor de pruebas es Postgres puro: el esquema realtime se SIMULA aquí (stub) con la firma documentada por Supabase.
-- Hogar Ejemplo: Ana (dueña, albacea de Papá), Alex (pareja, suplente de Papá), Carla (familiar), Diana (cuidadora),
-- Hogar (rol casa), Marta (cuenta maestra), Elena (otro hogar).
begin;

create temp table t_ids (clave text primary key, id uuid);
grant all on t_ids to public;
insert into t_ids values
  ('ana', pruebas.libro_personal('ana@ejemplo.test')),
  ('alex', pruebas.libro_personal('alex@ejemplo.test')),
  ('comp', 'f1000000-0000-4000-8000-000000000001'),
  ('papa', 'f1000000-0000-4000-8000-000000000002');

-- ---------------------------------------------------------------- 1: instalación
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from pg_trigger g
    where not g.tgisinternal and g.tgname in ('fin_realtime_ins', 'fin_realtime_upd', 'fin_realtime_del')), 54,
  '1: 18 tablas de Finanzas con tres disparadores por sentencia (alta, cambio, baja)');
select pruebas.igual((select count(*)::int from pg_trigger g
    where g.tgname like 'fin_realtime_%' and g.tgtype & 1 = 1), 0,
  '1: ninguno es por fila (no inunda el canal en importaciones masivas)');
select pruebas.igual((select count(*)::int from pg_trigger g
    where g.tgname in ('fin_realtime_ins', 'fin_realtime_upd', 'fin_realtime_del')
      and g.tgrelid = 'public.fin_movimientos'::regclass), 3, '1: fin_movimientos incluido');
select pruebas.igual((select count(*)::int from pg_trigger g
    where g.tgname like 'fin_realtime_%' and g.tgrelid in ('public.fin_libros'::regclass, 'public.fin_categorias'::regclass)), 0,
  '1: lo que no está en la lista (libros, categorías) no dispara');
select pruebas.igual((select count(*)::int from unnest(array['public.fin_realtime_avisar()', 'public.fin_realtime_instalar_politica()']) f
    where has_function_privilege('authenticated', f, 'execute') or has_function_privilege('anon', f, 'execute')
       or has_function_privilege('service_role', f, 'execute')), 0,
  '1: el disparador y el instalador no se ejecutan desde la API');
select pruebas.ok(has_function_privilege('authenticated', 'public.fin_realtime_puede_suscribir(text)', 'execute')
                  and not has_function_privilege('anon', 'public.fin_realtime_puede_suscribir(text)', 'execute'),
  '1: solo authenticated ejecuta la regla de suscripción');
select pruebas.igual(public.fin_realtime_instalar_politica(), 'omitida', '1: sin esquema realtime el instalador se omite sin fallar');

-- ---------------------------------------------------------------- 2: sin Realtime, escribir sigue funcionando
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 1234, current_date,
  p_id => 'd9100000-0000-4000-8000-000000000001');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where id = 'd9100000-0000-4000-8000-000000000001'$$), 1,
  '2: sin esquema realtime registrar un gasto funciona (el disparador no hace nada)');

-- ---------------------------------------------------------------- 3: se simula el esquema realtime (stub)
select pruebas.como_postgres();
create schema realtime;
grant usage on schema realtime to anon, authenticated, service_role;
create table realtime.messages (
  id bigserial primary key,
  topic text not null,
  extension text not null default 'broadcast',
  event text,
  payload jsonb,
  private boolean default false
);
grant select on realtime.messages to authenticated;
grant usage on sequence realtime.messages_id_seq to authenticated;
alter table realtime.messages enable row level security;
create function realtime.send(payload jsonb, event text, topic text, private boolean default true) returns void
language sql as $$ insert into realtime.messages (topic, event, payload, private) values (topic, event, payload, private) $$;
create function realtime.topic() returns text language sql stable as $$ select nullif(current_setting('realtime.topic', true), '') $$;
grant execute on function realtime.topic() to anon, authenticated;
-- Reinicia la lista de libros ya avisados (en producción dura una transacción; las pruebas viven en una sola).
create function pg_temp.reiniciar() returns void language sql as $$ select set_config('gravity.fin_realtime_avisados', '', true) $$;
create function pg_temp.mensajes(p_libro text) returns integer language sql
as $$ select count(*)::int from realtime.messages m where m.topic = 'finanzas:libro:' || p_libro $$;
grant execute on function pg_temp.reiniciar(), pg_temp.mensajes(text) to public;
select pg_temp.reiniciar();
delete from realtime.messages;

-- ---------------------------------------------------------------- 4: un gasto avisa a su libro, sin datos
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 987654, current_date,
  p_id => 'd9100000-0000-4000-8000-000000000002');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from realtime.messages), 1, '4: registrar un gasto emite exactamente un mensaje');
select pruebas.igual(pg_temp.mensajes((select id::text from t_ids where clave = 'ana')), 1, '4: va al canal del libro de Ana');
select pruebas.ok((select event = 'cambio' and private and payload = '{"v": 1}'::jsonb from realtime.messages),
  '4: evento «cambio», canal privado y cuerpo {"v":1}: ni monto, ni cuenta, ni nota, ni filas');
select pruebas.ok((select not (m.payload::text ~ '[0-9]{3}' or m.payload::text ~* 'gasto|monto|centavos|cuenta') from realtime.messages m),
  '4: el cuerpo no trae cifras ni nombres de nada');

-- ---------------------------------------------------------------- 5: un mensaje por libro y por transacción
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 500, current_date,
  p_id => 'd9100000-0000-4000-8000-000000000003');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from realtime.messages), 1,
  '5: otra escritura al mismo libro en la misma transacción no duplica el mensaje');
select pg_temp.reiniciar();
-- Dos filas del mismo libro y una de otro, en UNA sola sentencia: un mensaje por libro (no por fila).
delete from realtime.messages;
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9100000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'Banco extra 1 (realtime)', 'banco'),
  ('c9100000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'ana'), 'Banco extra 2 (realtime)', 'banco'),
  ('c9100000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', (select id from t_ids where clave = 'alex'), 'Banco extra 3 (realtime)', 'banco');
select pruebas.igual((select count(*)::int from realtime.messages), 2, '5: tres filas, dos libros, una sentencia: dos mensajes');
select pruebas.ok(pg_temp.mensajes((select id::text from t_ids where clave = 'ana')) = 1
              and pg_temp.mensajes((select id::text from t_ids where clave = 'alex')) = 1, '5: uno por libro');

-- Cambio y baja también avisan.
select pg_temp.reiniciar();
delete from realtime.messages;
update public.fin_cuentas set nombre = 'Banco extra 1 (renombrada)' where id = 'c9100000-0000-4000-8000-000000000001';
select pruebas.igual((select count(*)::int from realtime.messages), 1, '5: un UPDATE avisa');
select pg_temp.reiniciar();
delete from realtime.messages;
delete from public.fin_cuentas where id = 'c9100000-0000-4000-8000-000000000002';
select pruebas.igual((select count(*)::int from realtime.messages), 1, '5: un DELETE avisa');
-- Una sentencia que no toca filas no avisa.
select pg_temp.reiniciar();
delete from realtime.messages;
update public.fin_cuentas set nombre = 'x' where id = '00000000-0000-0000-0000-000000000000';
select pruebas.igual((select count(*)::int from realtime.messages), 0, '5: una sentencia sin filas no avisa');
-- Fila sin libro (cuenta del hogar): no hay canal al que avisar.
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9100000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', null, 'Cuenta del hogar (realtime)', 'de_gasto');
select pruebas.igual((select count(*)::int from realtime.messages), 0, '5: una fila sin libro no emite');

-- ---------------------------------------------------------------- 6: un movimiento entre dos libros avisa a los dos
select pg_temp.reiniciar();
delete from realtime.messages;
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('gasto', 'c5000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 700, current_date,
  p_id => 'd9100000-0000-4000-8000-000000000004');
select pruebas.como_postgres();
select pruebas.ok(pg_temp.mensajes((select id::text from t_ids where clave = 'comp')) = 1, '6: un gasto en el compartido avisa al compartido');

-- Insertar un movimiento que toca DOS libros (libro_origen y libro_destino distintos): un mensaje a cada uno.
select pg_temp.reiniciar();
delete from realtime.messages;
select pruebas.igual(
  (with v as (select distinct l from unnest(array[(select id from t_ids where clave = 'ana'), (select id from t_ids where clave = 'comp'),
                                                   (select id from t_ids where clave = 'ana')]) l)
   select count(*)::int from v), 2, '6: (control) dos libros distintos');
-- Se prueba la regla de las dos columnas con una sola sentencia sobre fin_movimientos que actualiza un movimiento ya
-- existente con libro_origen y libro_destino (UPDATE de una columna inocua es imposible: libro solo-agregar), así que se
-- llama al disparador con las dos columnas sobre una tabla temporal equivalente.
create table public.zz_prueba_realtime (id int primary key, libro_origen_id uuid, libro_destino_id uuid);
create trigger fin_realtime_ins after insert on public.zz_prueba_realtime referencing new table as nuevas
  for each statement execute function public.fin_realtime_avisar('libro_origen_id', 'libro_destino_id');
insert into public.zz_prueba_realtime values
  (1, (select id from t_ids where clave = 'ana'), (select id from t_ids where clave = 'comp')),
  (2, (select id from t_ids where clave = 'ana'), null);
select pruebas.ok(pg_temp.mensajes((select id::text from t_ids where clave = 'ana')) = 1
              and pg_temp.mensajes((select id::text from t_ids where clave = 'comp')) = 1 and (select count(*) from realtime.messages) = 2,
  '6: con dos columnas de libro (origen y destino) avisa a cada libro una vez');
drop table public.zz_prueba_realtime;

-- ---------------------------------------------------------------- 7: si el envío falla, la escritura sigue
select pg_temp.reiniciar();
create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true) returns void
language plpgsql as $$ begin raise exception 'Realtime caído (simulado)'; end $$;
select pruebas.como('ana@ejemplo.test');
select pruebas.registrar('gasto', 'c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 800, current_date,
  p_id => 'd9100000-0000-4000-8000-000000000005');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where id = 'd9100000-0000-4000-8000-000000000005'$$), 1,
  '7: si realtime.send falla, el movimiento se guarda igual (solo advertencia)');
select pruebas.como_postgres();
create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true) returns void
language sql as $$ insert into realtime.messages (topic, event, payload, private) values (topic, event, payload, private) $$;

-- ---------------------------------------------------------------- 8: quién puede suscribirse
select pruebas.igual(public.fin_realtime_instalar_politica(), 'instalada', '8: con esquema realtime se instala la política');
select pruebas.igual(public.fin_realtime_instalar_politica(), 'instalada', '8: y se puede repetir');
select pruebas.igual((select count(*)::int from pg_policy where polrelid = 'realtime.messages'::regclass and polname = 'fin_realtime_suscribir'), 1,
  '8: una sola política de suscripción en realtime.messages');
select pruebas.ok((select polcmd = 'r' and polroles = array[(select oid from pg_roles where rolname = 'authenticated')]::oid[]
                     from pg_policy where polname = 'fin_realtime_suscribir'), '8: solo lectura (suscribirse) y solo para authenticated: nadie escribe en el canal');
delete from realtime.messages;
insert into realtime.messages (topic, extension) select 'finanzas:libro:' || id::text, 'broadcast' from t_ids;
insert into realtime.messages (topic, extension) values ('finanzas:libro:' || (select id from t_ids where clave = 'ana'), 'presence');
insert into realtime.messages (topic, extension) values ('otro:tema', 'broadcast'), ('finanzas:libro:no-es-uuid', 'broadcast');
-- ¿Puede esta persona escuchar el tema? (con RLS de verdad sobre la tabla simulada)
create function pg_temp.oye(p_tema text, p_ext text default 'broadcast') returns boolean language plpgsql as $$
begin
  perform set_config('realtime.topic', p_tema, true);
  return exists (select 1 from realtime.messages m where m.topic = p_tema and m.extension = p_ext);
end $$;
grant execute on function pg_temp.oye(text, text) to public;

select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'ana')), '8: Ana escucha su libro');
select pruebas.ok(pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'comp')), '8: Ana escucha el compartido');
select pruebas.ok(pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'papa')), '8: Ana (albacea) escucha el libro de Papá');
select pruebas.ok(not pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'alex')), '8: Ana NO escucha el libro personal de Alex');
select pruebas.ok(not pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'ana'), 'presence'), '8: solo el tipo broadcast');
select pruebas.ok(not pg_temp.oye('otro:tema') and not pg_temp.oye('finanzas:libro:no-es-uuid'), '8: temas ajenos o mal formados: nadie');
select pruebas.igual(public.fin_realtime_puede_suscribir(null), false, '8: tema nulo: falso');
select pruebas.igual(public.fin_realtime_puede_suscribir('finanzas:libro:' || gen_random_uuid()::text), false, '8: libro inexistente: falso');

select pruebas.como('alex@ejemplo.test');
select pruebas.ok(pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'alex')), '8: Alex escucha su libro');
select pruebas.ok(pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'comp')), '8: Alex escucha el compartido');
select pruebas.ok(not pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'ana')), '8: Alex NO escucha el libro personal de Ana');

-- Sin Finanzas: familiar, cuidadora, Casa (tablet pública) y gente de otro hogar no escuchan nada.
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from t_ids where pg_temp.oye('finanzas:libro:' || id)), 0, '8: la familiar no escucha ningún libro, ni el de Papá');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual((select count(*)::int from t_ids where pg_temp.oye('finanzas:libro:' || id)), 0, '8: la cuidadora no escucha ninguno');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual((select count(*)::int from t_ids where pg_temp.oye('finanzas:libro:' || id)), 0, '8: Casa (tablet pública) no escucha ninguno');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual((select count(*)::int from t_ids where pg_temp.oye('finanzas:libro:' || id)), 0, '8: nadie de otro hogar escucha');
select pruebas.como_anon();
select pruebas.igual(has_table_privilege('anon', 'realtime.messages', 'select'), false, '8: anon no lee realtime.messages');

-- La cuenta maestra: solo con consulta vigente y solo ese libro (I2).
select pruebas.como('marta@ejemplo.test');
select pruebas.igual((select count(*)::int from t_ids where pg_temp.oye('finanzas:libro:' || id)), 0, '8: la cuenta maestra sin consulta no escucha nada');
select pruebas.ok(public.fin_registrar_consulta_maestra((select id from t_ids where clave = 'ana')), '8: (la maestra registra su consulta al libro de Ana)');
select pruebas.ok(pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'ana')), '8: con consulta vigente escucha ese libro');
select pruebas.ok(not pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'alex')), '8: y solo ese');
select pruebas.como_postgres();
-- Una consulta de hace 31 minutos (vencida) al libro de Alex, escrita como lo haría el servidor.
insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('marta@ejemplo.test'), 'finanzas.consulta_maestra', 'fin_libros',
          (select id::text from t_ids where clave = 'alex'), '{}'::jsonb, now() - interval '31 minutes');
select pruebas.como('marta@ejemplo.test');
select pruebas.ok(not pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'alex')), '8: con la consulta vencida (más de 30 min) no puede suscribirse');

-- La vista temporal de Papá (D24) no se suscribe.
select pruebas.como_postgres();
insert into public.fin_vistas_solicitadas (hogar_id, solicitante_id, libro_persona_id, motivo, estado, autorizada_por, vigente_hasta)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 'e0000000-0000-4000-8000-000000000001',
          'Revisar medicinas (ejemplo)', 'autorizada', pruebas.id_persona('ana@ejemplo.test'), now() + interval '30 minutes');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.fin_vista_papa_vigente(), '8: (la familiar tiene una vista vigente de Papá)');
select pruebas.ok(public.fin_puede((select id from t_ids where clave = 'papa'), 'leer'), '8: (y fin_puede le deja leer ese libro)');
select pruebas.ok(not pg_temp.oye('finanzas:libro:' || (select id from t_ids where clave = 'papa')),
  '8: aun así la vista temporal de Papá NO se suscribe (D24): se actualiza al entrar, no en vivo');

select pruebas.como_postgres();
rollback;
