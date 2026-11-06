-- =============================================================================
-- Guardias de la revisión de calidad de la Fase 3 (docs/revisiones/fase-3.md)
-- =============================================================================
-- Regresiones que PASAN hoy: aislamiento de Hábitos, funciones internas, sobres,
-- bitácora reservada. Lo abierto vive en hallazgos_fase3.sql.
begin;

-- ====================================== funciones internas no llamables
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.hab_limpiar()$$, 'F3G1: nadie llama a hab_limpiar', '42501');
select pruebas.falla($$select public.hab_borrar_datos_de(pruebas.id_persona('ana@ejemplo.test'), 'todo')$$, 'F3G2: ni borra datos ajenos con la función interna', '42501');
select pruebas.falla($$select public.hab_nota('habitos.borrar_datos')$$, 'F3G3: ni escribe constancias a mano', '42501');
select pruebas.falla($$select public.hab_iniciar_persona('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'))$$, 'F3G4: ni inicia personas', '42501');
select pruebas.falla($$select public.hab_miembro_activo('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'))$$, 'F3G5: ni consulta quién tiene Hábitos', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.hab_borrar_mis_datos('todo')$$, 'F3G6: anon no borra', '42501');
select pruebas.falla($$select count(*) from public.hab_objetivos$$, 'F3G7: anon no lee', '42501');

-- ====================================== aislamiento: lo de Ana es de Ana
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.hab_objetivos where id = ''f5000000-0000-4000-8000-000000000001'''), 0, 'F3G8: la pareja no lee un objetivo de Ana');
select pruebas.igual(pruebas.afecta('update public.hab_objetivos set titulo = ''x'' where id = ''f5000000-0000-4000-8000-000000000001'''), 0, 'F3G9: ni lo cambia');
select pruebas.igual(pruebas.afecta('delete from public.hab_objetivos where id = ''f5000000-0000-4000-8000-000000000001'''), 0, 'F3G10: ni lo borra');
select pruebas.falla($$insert into public.hab_registros (id, objetivo_id, fecha, estado, modificado_en)
  values (gen_random_uuid(), 'f5000000-0000-4000-8000-000000000001', '2026-11-01', 'hecho', now())$$,
  'F3G11: ni registra sobre un objetivo ajeno (llave compuesta con persona)', '23503');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id','f5600000-0000-4000-8000-000000000001','tipo','diario_oracion','revision',2,'llave_version',1,'cifrado','AAAAAAAAAAAAAAAAAAAAAAAA')))$$,
  'F3G12: ni pisa un sobre de Ana', '22023');

-- ====================================== sobres
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.hab_subir_sobres((select jsonb_agg(jsonb_build_object('id',gen_random_uuid(),'tipo','diario_oracion','revision',1,'llave_version',1,'cifrado','AAAAAAAAAAAAAAAAAAAAAAAA')) from generate_series(1,51)))$$,
  'F3G14: máximo 50 sobres por llamada', '22023');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'tipo','habitos_sensibles','revision',1,'llave_version',1,'cifrado','AAAAAAAAAAAAAAAAAAAAAAAA')))$$,
  'F3G15: un tipo en solo teléfono no recibe sobres', '22023');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'tipo','diario_oracion','revision',1,'llave_version',1,'cifrado','texto con espacios y ñ')))$$,
  'F3G16: el cifrado solo admite base64url', '23514');
select pruebas.falla($$select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'tipo','diario_oracion','revision',1,'llave_version',1,'cifrado',repeat('A', 87401))))$$,
  'F3G17: un sobre de más de 64 KB no entra', '23514');
select pruebas.falla($$select public.hab_cambiar_modo('diario_oracion','solo_telefono')$$, 'F3G18: volver a solo teléfono pide confirmar el borrado', '22023');

-- ====================================== bitácora reservada
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.bitacora (hogar_id, persona_id, accion, tabla, ocurrido_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 'habitos.falso', null, now())$$,
  'F3G19: la app no escribe acciones habitos.*', '42501');
select public.hab_borrar_mis_datos('sensibles');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.bitacora where accion like ''habitos%'' and persona_id = pruebas.id_persona(''carla@ejemplo.test'')'), 0, 'F3G20: la dueña no ve habitos.* de Carla');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.bitacora where accion like ''habitos%'''), 0, 'F3G21: ni la maestra');

-- ====================================== la familiar no recibe avisos de dinero aunque tenga preferencias
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.fin_avisos_destinatarios(pruebas.libro_personal('ana@ejemplo.test'), 'fondo_bajo') d
  where d = pruebas.id_persona('carla@ejemplo.test')), 0, 'F3G22: Carla (familiar con preferencias de Hábitos) no es destinataria de avisos de dinero');

rollback;
