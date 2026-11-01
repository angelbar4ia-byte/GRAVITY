-- Hábitos sensibles (D13, D21): el servidor solo guarda sobres cifrados; modos, llaves, subida en lote, borrado.
begin;

-- ---------------------------------------------------------------- esquema: el servidor no ve nada en claro
select pruebas.como_postgres();
select pruebas.igual((select string_agg(column_name, ',' order by column_name) from information_schema.columns
  where table_schema = 'public' and table_name = 'hab_sobres'),
  'actualizado_en,cifrado,creado_en,eliminado,hogar_id,id,llave_version,persona_id,revision,tipo',
  'hab_sobres solo tiene tipo, revisión, texto cifrado y horas del servidor (ni fecha ni clase de registro)');
select pruebas.ok(not has_column_privilege('authenticated', 'public.hab_sobres', 'cifrado', 'INSERT')
  and not has_table_privilege('authenticated', 'public.hab_sobres', 'INSERT')
  and not has_any_column_privilege('authenticated', 'public.hab_sobres', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.hab_sobres', 'DELETE')
  and not has_table_privilege('authenticated', 'public.hab_llaves', 'INSERT'),
  'Los sobres y las llaves no se escriben directo (solo con las funciones)');

-- ---------------------------------------------------------------- lo de Ana (seed): solo ella
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 1, 'Ana ve su sobre del diario (modo nube)');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_llaves$$), 1, '… y su llave envuelta');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$) + pruebas.cuenta($$select * from public.hab_llaves$$), 0, 'La pareja no ve sobres ni llaves de Ana');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$) + pruebas.cuenta($$select * from public.hab_llaves$$), 0, 'La maestra tampoco');
select pruebas.falla($$select public.hab_subir_sobres('[]'::jsonb)$$, 'ni sube nada', '42501');
select pruebas.falla($$select public.hab_guardar_llave(1, 'pbkdf2-hmac-sha256', '{}', 'saldesal1', 'llaveenvuelta12345')$$, 'ni guarda llaves', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.hab_cambiar_modo('diario_oracion', 'nube_cifrada')$$, 'La cuidadora no usa Hábitos', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.hab_subir_sobres('[]'::jsonb)$$, 'La cuenta Hogar (tablet pública) tampoco', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 0, 'Otro hogar no ve nada');
select pruebas.como_anon();
select pruebas.falla($$select public.hab_subir_sobres('[]'::jsonb)$$, 'Sin sesión no se ejecuta', '42501');

-- ---------------------------------------------------------------- llaves (Carla: familiar, parte de cero)
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.hab_cambiar_modo('habitos_sensibles', 'nube_cifrada')$$, 'Sin llave guardada no se activa la nube', '55000');
select pruebas.falla($$select public.hab_guardar_llave(2, 'pbkdf2-hmac-sha256', '{"vueltas": 600000}', 'saldesal1', 'llaveenvuelta12345')$$,
  'La primera envoltura es la versión 1', '22023');
select pruebas.falla($$select public.hab_guardar_llave(1, 'md5', '{}', 'saldesal1', 'llaveenvuelta12345')$$, 'El KDF es de una lista', '23514');
select public.hab_guardar_llave(1, 'pbkdf2-hmac-sha256', '{"vueltas": 600000}', 'saldesal1', 'llaveenvuelta12345');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_llaves$$), 1, 'Guarda su llave envuelta');
select public.hab_guardar_llave(1, 'pbkdf2-hmac-sha256', '{"vueltas": 600000}', 'saldesal1', 'llaveenvuelta12345');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'habitos.activar_cifrado'$$), 1,
  'Repetir lo mismo es idempotente y deja una sola constancia sin contenido');
select pruebas.igual((select detalle::text || coalesce(tabla, 'sin-tabla') from public.bitacora where accion = 'habitos.activar_cifrado'),
  '{}sin-tabla', 'La constancia no lleva contenido');
select pruebas.falla($$select public.hab_guardar_llave(3, 'pbkdf2-hmac-sha256', '{}', 'saldesal2', 'llaveenvuelta67890')$$, 'La versión sube de 1 en 1', '22023');
select public.hab_guardar_llave(2, 'pbkdf2-hmac-sha256', '{"vueltas": 700000}', 'saldesal2', 'llaveenvuelta67890');
select pruebas.ok((select version = 2 and rotada_en is not null from public.hab_llaves), 'Cambiar la frase sube la versión (y los datos no se recifran)');
select pruebas.falla($$update public.hab_llaves set version = 9$$, 'La llave no se cambia a mano', '42501');

-- ---------------------------------------------------------------- modos y sobres
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'habitos_sensibles',
  'revision', 1, 'llave_version', 1, 'cifrado', 'AAAA')))$$, 'En solo teléfono el servidor no recibe sobres', '22023');
select public.hab_cambiar_modo('habitos_sensibles', 'nube_cifrada');
select pruebas.igual((select modo from public.hab_modos where tipo = 'habitos_sensibles'), 'nube_cifrada', 'Activa la nube del tipo');
select pruebas.igual((select modo from public.hab_modos where tipo = 'diario_oracion'), 'solo_telefono', '… el otro tipo sigue solo teléfono');
select pruebas.igual(public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 1, 'llave_version', 1, 'cifrado', 'QUJDREVGR0g'))) ->> 'aceptados', '1', 'Sube un sobre');
select pruebas.igual(public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 1, 'llave_version', 1, 'cifrado', 'QUJDREVGR0g'))) ->> 'aceptados', '0', 'Subir lo mismo es idempotente');
select pruebas.igual(public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 2, 'llave_version', 1, 'cifrado', 'QUJDREVGR0gy'))) ->> 'aceptados', '1', 'La revisión siguiente entra');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 4, 'llave_version', 1, 'cifrado', 'QUJD')))$$, 'La revisión sube de 1 en 1', '22023');
select pruebas.igual(public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 2, 'llave_version', 1, 'cifrado', 'b3RyYQ'))) -> 'conflictos' -> 0 ->> 'revision', '2',
  'Otra versión de la misma revisión es un conflicto: se devuelve la del servidor');
select pruebas.igual((select cifrado from public.hab_sobres where id = 'f6000000-0000-4000-8000-000000000001'), 'QUJDREVGR0gy', '… y no se pisa');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f5600000-0000-4000-8000-000000000001',
  'tipo', 'diario_oracion', 'revision', 1, 'llave_version', 1, 'cifrado', 'QUJD')))$$, 'El sobre de otra persona no se toca (y el tipo de Carla está en solo teléfono)', '22023');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000002',
  'tipo', 'habitos_sensibles', 'revision', 1, 'llave_version', 1, 'cifrado', 'texto en claro con espacios y ñ')))$$,
  'El cifrado es base64url (no texto en claro)', '23514');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000002',
  'tipo', 'habitos_sensibles', 'revision', 1, 'llave_version', 1, 'cifrado', repeat('A', 87401))))$$, 'Más de 64 KB se rechaza', '23514');
select pruebas.falla($$select public.hab_subir_sobres((select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'habitos_sensibles',
  'revision', 1, 'llave_version', 1, 'cifrado', 'QUJD')) from generate_series(1, 51)))$$, 'Hasta 50 sobres por llamada', '22023');
select pruebas.igual(public.hab_subir_sobres((select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'habitos_sensibles',
  'revision', 1, 'llave_version', 1, 'cifrado', 'QUJD')) from generate_series(1, 50))) ->> 'aceptados', '50', 'Con 50 sí');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 51, 'Carla ve sus 51 sobres');
-- Tumba
select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 3, 'llave_version', 1, 'cifrado', 'QUJD', 'eliminado', true)));
select pruebas.ok((select eliminado from public.hab_sobres where id = 'f6000000-0000-4000-8000-000000000001'), 'Una tumba es un sobre eliminado');
-- Cuota
select pruebas.como_postgres();
update public.avisos_sistema set valor = to_jsonb(100::bigint) where clave = 'habitos_cuota_bytes';
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'tipo', 'habitos_sensibles',
  'revision', 1, 'llave_version', 1, 'cifrado', 'QUJD')))$$, 'Pasar la cuota por persona se rechaza', '22023');
select pruebas.como_postgres();
update public.avisos_sistema set valor = to_jsonb(26214400::bigint) where clave = 'habitos_cuota_bytes';
-- Otra persona no toca el sobre de Carla
select pruebas.como('alex@ejemplo.test');
select public.hab_guardar_llave(1, 'pbkdf2-hmac-sha256', '{}', 'saldesal1', 'llaveenvuelta12345');
select public.hab_cambiar_modo('habitos_sensibles', 'nube_cifrada');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-000000000001',
  'tipo', 'habitos_sensibles', 'revision', 4, 'llave_version', 1, 'cifrado', 'QUJD')))$$, 'Un sobre ajeno no se actualiza', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 0, 'Alex no ve los de Carla');

-- ---------------------------------------------------------------- volver a solo teléfono borra la nube
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.hab_cambiar_modo('habitos_sensibles', 'solo_telefono')$$, 'Sin confirmar no se borra', '22023');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 51, '… y no se perdió nada');
select public.hab_cambiar_modo('habitos_sensibles', 'solo_telefono', true);
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 0, 'Con confirmación se borran físicamente los sobres de ese tipo');
select pruebas.igual((select epoca_nube from public.hab_ajustes), 1, 'y sube la época de la nube (los demás equipos borran su copia)');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'habitos.cambiar_modo'$$), 2, 'Cada cambio de modo deja su constancia sin contenido');

-- ---------------------------------------------------------------- reiniciar la nube y borrar mis datos
select public.hab_cambiar_modo('habitos_sensibles', 'nube_cifrada');
select public.hab_cambiar_modo('diario_oracion', 'nube_cifrada');
select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id', 'f6000000-0000-4000-8000-0000000000d1', 'tipo', 'diario_oracion',
  'revision', 1, 'llave_version', 2, 'cifrado', 'QUJD'), jsonb_build_object('id', 'f6000000-0000-4000-8000-0000000000d2',
  'tipo', 'habitos_sensibles', 'revision', 1, 'llave_version', 2, 'cifrado', 'QUJD')));
select public.hab_reiniciar_nube('diario_oracion');
select pruebas.igual((select string_agg(tipo || ':' || modo, ',' order by tipo) from public.hab_modos),
  'diario_oracion:solo_telefono,habitos_sensibles:nube_cifrada', 'Reinicia un tipo y el otro sigue');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_llaves$$), 1, 'La llave se queda mientras el otro tipo use la nube');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 1, 'Se fueron los sobres del tipo reiniciado');
select public.hab_reiniciar_nube();
select pruebas.igual(pruebas.cuenta($$select * from public.hab_llaves$$) + pruebas.cuenta($$select * from public.hab_sobres$$), 0,
  'Reiniciar todo borra los sobres y la llave');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 1, 'Lo que está en claro no se toca al reiniciar la nube');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'habitos.reiniciar_nube'$$), 2, 'Cada reinicio deja su constancia');
select pruebas.falla($$select public.hab_reiniciar_nube('otro')$$, 'Tipo desconocido', '22023');
select pruebas.falla($$select public.hab_borrar_mis_datos('otra-cosa')$$, 'Alcance desconocido', '22023');
select public.hab_borrar_mis_datos('todo');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 0, 'Borrar todo quita también lo que estaba en claro');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ajustes$$), 1, '… y deja los ajustes');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'habitos.borrar_datos'$$), 1, 'Deja una sola constancia sin contenido');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 2, 'Lo de Ana no se tocó');
select public.hab_borrar_mis_datos('diario');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_sobres$$), 0, 'Ana borra solo su diario');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_objetivos$$), 2, '… y lo demás sigue');

-- ---------------------------------------------------------------- limpieza de tumbas y tablets
select pruebas.como_postgres();
insert into public.hab_sobres (id, hogar_id, persona_id, tipo, revision, cifrado, llave_version, eliminado, actualizado_en) values
  ('f6000000-0000-4000-8000-0000000000e1', 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'habitos_sensibles', 1, 'QUJD', 1, true, now() - interval '31 days'),
  ('f6000000-0000-4000-8000-0000000000e2', 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'habitos_sensibles', 1, 'QUJD', 1, true, now() - interval '29 days'),
  ('f6000000-0000-4000-8000-0000000000e3', 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 'habitos_sensibles', 1, 'QUJD', 1, false, now() - interval '60 days');
select pruebas.igual(public.hab_limpiar(), 1, 'La limpieza borra la tumba de más de 30 días');
select pruebas.igual((select count(*)::int from public.hab_sobres where persona_id = pruebas.id_persona('alex@ejemplo.test')), 2,
  '… y deja la de 29 días y el sobre vivo (aunque sea viejo)');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.registrar_dispositivo('tok-tablet-carla', 'android', 'Tablet personal', 'tablet_personal') is not null,
  'La tablet personal registra su dispositivo como el teléfono');
rollback;
