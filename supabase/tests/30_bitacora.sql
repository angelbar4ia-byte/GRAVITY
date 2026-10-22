-- Bitácora solo-agregar: nadie la actualiza ni la borra (ningún rol de la
-- app, ni service_role, ni el dueño de la tabla); cada quien agrega a su nombre.
begin;

create temporary table conteo_inicial on commit drop as
  select count(*)::int as n from public.bitacora;

-- Ningún rol de la app actualiza, borra ni vacía la bitácora.
do $$
declare
  v_correo text;
begin
  foreach v_correo in array array['ana@ejemplo.test', 'alex@ejemplo.test', 'carla@ejemplo.test',
                                  'diana@ejemplo.test', 'casa@ejemplo.test', 'elena@ejemplo.test']
  loop
    perform pruebas.como(v_correo);
    perform pruebas.falla($q$update public.bitacora set accion = 'alterada'$q$,
      v_correo || ' no actualiza la bitácora', '42501');
    perform pruebas.falla('delete from public.bitacora',
      v_correo || ' no borra la bitácora', '42501');
    perform pruebas.falla('truncate public.bitacora',
      v_correo || ' no vacía la bitácora', '42501');
  end loop;
end
$$;

-- service_role (funciones de servidor) tampoco.
select pruebas.como_servicio();
select pruebas.falla($$update public.bitacora set accion = 'alterada'$$,
  'service_role no actualiza la bitácora', '42501');
select pruebas.falla('delete from public.bitacora', 'service_role no borra la bitácora', '42501');
select pruebas.falla('truncate public.bitacora', 'service_role no vacía la bitácora', '42501');

-- Ni el dueño de las tablas (postgres): lo impide el trigger.
select pruebas.como_postgres();
select pruebas.falla($$update public.bitacora set accion = 'alterada'$$,
  'postgres no actualiza la bitácora (trigger)', '42501');
select pruebas.falla('delete from public.bitacora', 'postgres no borra la bitácora (trigger)', '42501');
select pruebas.falla('truncate public.bitacora', 'postgres no vacía la bitácora (trigger)', '42501');
select pruebas.igual((select count(*)::int from public.bitacora), (select n from conteo_inicial),
  'La bitácora sigue intacta');
select pruebas.ok(
  not exists (select 1 from public.bitacora where accion = 'alterada'),
  'Ninguna entrada fue alterada');

-- Agregar: cada quien a su nombre y solo en su hogar.
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$
  insert into public.bitacora (hogar_id, accion, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'abrio_pantalla', '{"pantalla": "hoy"}')$$), 1,
  'Un familiar agrega una entrada en su hogar');
select pruebas.igual(
  (select persona_id from public.bitacora where accion = 'abrio_pantalla'),
  pruebas.id_persona('carla@ejemplo.test'),
  'El servidor pone quién (persona de la sesión)');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, persona_id, accion)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'suplantar')$$,
  'Nadie agrega a nombre de otra persona', '42501');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, accion, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', 'fecha_falsa', now() - interval '1 year')$$,
  'Nadie fija la hora de registro del servidor', '42501');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, accion)
  values ('b0000000-0000-4000-8000-000000000002', 'en_otro_hogar')$$,
  'Nadie agrega en un hogar ajeno', '42501');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, accion, ocurrido_en)
  values ('b0000000-0000-4000-8000-000000000001', 'del_futuro', now() + interval '1 day')$$,
  'Nadie registra algo ocurrido en el futuro', '42501');
select pruebas.igual(pruebas.afecta($$
  insert into public.bitacora (hogar_id, accion, ocurrido_en)
  values ('b0000000-0000-4000-8000-000000000001', 'registrado_sin_conexion', now() - interval '2 hours')$$), 1,
  'Lo registrado sin conexión conserva cuándo ocurrió');

-- Acciones reservadas a los triggers (hallazgo M2): nadie fabrica una entrada
-- que parezca un cambio automático, ni con una acción que se le parezca.
do $$
declare
  v_correo text;
  v_accion text;
begin
  foreach v_correo in array array['ana@ejemplo.test', 'alex@ejemplo.test', 'carla@ejemplo.test',
                                  'diana@ejemplo.test', 'casa@ejemplo.test']
  loop
    perform pruebas.como(v_correo);
    foreach v_accion in array array['insertar', 'actualizar', 'borrar']
    loop
      perform pruebas.falla(format($q$
        insert into public.bitacora (hogar_id, accion, tabla, registro_id, detalle)
        values ('b0000000-0000-4000-8000-000000000001', %L, 'finanzas_muestra',
                'c0000000-0000-4000-8000-000000000001',
                '{"antes": {"monto_centavos": 185000, "descripcion": "Despensa semanal (ejemplo)"}}')$q$,
        v_accion),
        format('M2: %s no agrega entradas con la acción reservada "%s"', v_correo, v_accion), '42501');
    end loop;
  end loop;
end
$$;
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, accion, tabla)
  values ('b0000000-0000-4000-8000-000000000001', 'Borrar', 'finanzas_muestra')$$,
  'M2: tampoco con mayúsculas', '23514');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, accion, tabla)
  values ('b0000000-0000-4000-8000-000000000001', ' borrar', 'finanzas_muestra')$$,
  'M2: ni con espacios', '23514');
select pruebas.falla($$
  insert into public.bitacora (hogar_id, accion, tabla)
  values ('b0000000-0000-4000-8000-000000000001', 'bоrrar', 'finanzas_muestra')$$,
  'M2: ni con letras de otro alfabeto que se parecen', '23514');
select pruebas.igual(pruebas.afecta($$
  insert into public.bitacora (hogar_id, accion, detalle)
  values ('b0000000-0000-4000-8000-000000000001', 'gravity.recordatorio_leido', '{"tipo": "generico"}')$$), 1,
  'M2: la cuenta Casa sí agrega sus propias acciones');
select pruebas.como_servicio();
select pruebas.falla($$
  insert into public.bitacora (accion) values ('Aviso Enviado')$$,
  'El formato de la acción vale para todos, también service_role', '23514');
select pruebas.como('carla@ejemplo.test');

-- Lectura: cada quien lo suyo; el dueño todo lo de su hogar.
select pruebas.igual(
  pruebas.cuenta($$select * from public.bitacora
                   where persona_id is distinct from pruebas.id_persona('carla@ejemplo.test')$$), 0,
  'Un familiar solo ve sus propias entradas');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.bitacora'), 0,
  'El cuidador no ve la bitácora de la familia');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(
  pruebas.cuenta($$select * from public.bitacora where accion = 'abrio_pantalla'$$) = 1
  and pruebas.cuenta($$select * from public.bitacora
                       where hogar_id = 'b0000000-0000-4000-8000-000000000002'$$) = 0,
  'El dueño ve la bitácora de su hogar y no la de otro');

-- La bitácora automática no copia el hash del token de invitaciones.
select pruebas.igual(
  pruebas.cuenta($$select * from public.bitacora
                   where tabla = 'invitaciones' and detalle::text like '%token_hash%'$$), 0,
  'La bitácora no guarda el hash del token de invitación');

rollback;
