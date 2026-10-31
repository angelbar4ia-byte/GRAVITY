-- =============================================================================
-- Guardias de la revisión de calidad de la Fase 2 (docs/revisiones/fase-2.md)
-- =============================================================================
-- Regresiones que PASAN hoy: privilegios de las funciones de avisos, RLS por rol
-- de las tablas nuevas de dinero y avisos. Lo abierto vive en hallazgos_fase2.sql.
begin;

-- ====================================== funciones solo del servidor
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select * from public.avisos_reclamar(10)$$, 'F2G1: un usuario no reclama avisos', '42501');
select pruebas.falla($$select public.avisos_registrar_entrega(gen_random_uuid(), gen_random_uuid(), 'token_invalido')$$,
  'F2G2: un usuario no borra tokens ajenos', '42501');
select pruebas.falla($$select public.avisos_resultado_envio(gen_random_uuid(), true)$$, 'F2G3: ni cierra envíos', '42501');
select pruebas.falla($$select public.avisos_generar_vencimientos()$$, 'F2G4: ni dispara generadores', '42501');
select pruebas.falla($$select public.avisos_limpiar()$$, 'F2G5: ni la limpieza', '42501');
select pruebas.falla($$select public.avisos_revisar_base(999999999999)$$, 'F2G6: ni revisa la base con bytes falsos', '42501');
select pruebas.falla($$select count(*) from public.avisos_sistema$$, 'F2G7: avisos_sistema cerrada', '42501');
select pruebas.falla($$select count(*) from public.avisos_entregas$$, 'F2G8: avisos_entregas cerrada', '42501');
select pruebas.falla($$insert into public.avisos (id,hogar_id,persona_id,modulo,tipo,severidad,clave,programado_para,enviar_en)
  values (gen_random_uuid(),'b0000000-0000-4000-8000-000000000001',pruebas.id_persona('ana@ejemplo.test'),'sistema','base_80','importante','k',now(),now())$$,
  'F2G9: no se insertan avisos a mano', '42501');
select pruebas.falla($$insert into public.dispositivos (persona_id,plataforma,token_avisos)
  values (pruebas.id_persona('ana@ejemplo.test'),'android','t-falso')$$, 'F2G10: no se registran dispositivos a mano', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.registrar_dispositivo('x','android')$$, 'F2G11: anon no registra dispositivos', '42501');
select pruebas.como_servicio();
select pruebas.falla($$select public.avisos_generar_vencimientos()$$, 'F2G12: ni el servicio llama generadores (solo cron)', '42501');

-- ====================================== RLS de las tablas nuevas
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.avisos'), 0, 'F2G13: la maestra no ve avisos ajenos');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bolsas_ahorro') + pruebas.cuenta('select * from public.fin_deudas')
  + pruebas.cuenta('select * from public.fin_estados_cuenta') + pruebas.cuenta('select * from public.fin_msi'), 0,
  'F2G14: la maestra sin consulta no ve deudas, bolsas, estados ni MSI');
select pruebas.falla($$select public.avisos_actualizar_preferencias(p_tope_no_criticas => 5)$$,
  'F2G15: la maestra no tiene preferencias de dinero', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bolsas_ahorro') + pruebas.cuenta('select * from public.fin_v_deuda_resumen'), 0,
  'F2G16: la familiar no ve ahorro ni deudas');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bolsas_ahorro') + pruebas.cuenta('select * from public.fin_deudas'), 0,
  'F2G17: el cuidador no ve ahorro ni deudas');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bolsas_ahorro') + pruebas.cuenta('select * from public.fin_deudas'), 0,
  'F2G18: la cuenta Casa no ve ahorro ni deudas');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.fin_bolsas_ahorro where libro_id = pruebas.libro_personal(''ana@ejemplo.test'')')
  + pruebas.cuenta('select * from public.avisos where persona_id = pruebas.id_persona(''ana@ejemplo.test'')'), 0,
  'F2G19: otro hogar no ve lo de Ana');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta('select * from public.avisos where persona_id = pruebas.id_persona(''ana@ejemplo.test'')')
  + pruebas.cuenta('select * from public.avisos_preferencias where persona_id = pruebas.id_persona(''ana@ejemplo.test'')'), 0,
  'F2G20: la pareja no ve los avisos ni preferencias de Ana');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.fin_estados_cuenta set intereses_centavos = 0$$, 'F2G21: estados de cuenta solo-agregar (update)', '42501');
select pruebas.falla($$delete from public.fin_estados_cuenta$$, 'F2G22: estados de cuenta solo-agregar (delete)', '42501');
select pruebas.como('marta@ejemplo.test');
select public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test'));
select pruebas.falla($$select public.fin_emitir_aviso(pruebas.libro_personal('ana@ejemplo.test'),'flujo_negativo',null,null,'k:1')$$,
  'F2G23: la maestra con consulta no emite avisos', '42501');

rollback;
