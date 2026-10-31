-- Finanzas Fase 2 en el servidor: clases de deuda, MSI, estados de cuenta, bolsas de ahorro, aportaciones y
-- retiros (criterios 2, 12, 26, 27, 28 y 57 de docs/specs/fase-2-finanzas.md).
begin;

select pruebas.nuevo_adulto('teo@ejemplo.test');
select pruebas.como_postgres();
select pruebas.igual(
  (select string_agg(nombre || '=' || clase, ',' order by nombre) from public.fin_deudas
    where libro_id = pruebas.libro_personal('ana@ejemplo.test')),
  'MSI Lavadora (ejemplo)=msi,Préstamo de la tía=familiar,Tarjeta de crédito=tarjeta',
  '1: las deudas de la Fase 1 conservan sus filas, con su clase');

-- ---------------------------------------------------------------- 2: clases de deuda
select pruebas.como('ana@ejemplo.test');
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9200000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Tarjeta B', 'tarjeta'),
  ('c9200000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Préstamo B', 'prestamo');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'con_costo', 'msi',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 2400)$$, 'clase msi exige tipo msi', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'msi', 'credito',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual')$$, 'tipo msi exige clase msi', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'familiar', 'tarjeta',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual')$$, 'clase familiar <=> tipo familiar', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'msi', 'msi',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 100)$$, 'La tasa de un MSI es cero', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'con_costo', 'prestamo',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 0)$$, 'Una deuda con costo exige tasa', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb, corte_dia)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'con_costo', 'prestamo',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 2400, 15)$$, 'El día de corte es solo de tarjetas', '23514');
select pruebas.falla($$insert into public.fin_deudas (hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb, extra_reduce)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'con_costo', 'prestamo',
          'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 2400, 'nada')$$, 'extra_reduce es plazo o cuota', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos,
    frecuencia, tasa_anual_pb, acreedor, cat_pb, corte_dia, permite_pago_anticipado, extra_reduce, monto_original_centavos)
  values ('e5200000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'Tarjeta B', 'con_costo', 'tarjeta', 'c9200000-0000-4000-8000-000000000001', 1000, 'mensual', 4500, 'Banco B', 6000, 0, null, null, 2000000)$$), 1,
  'Una tarjeta con sus datos nuevos entra (corte 0 = último día; pago anticipado nulo = verificar)');
select pruebas.igual(pruebas.afecta($$insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb)
  values ('e5200000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'Préstamo B', 'con_costo', 'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 2400)$$), 1,
  'Una deuda sin clase (cola de la Fase 1) entra…');
select pruebas.igual((select clase from public.fin_deudas where id = 'e5200000-0000-4000-8000-000000000002'), 'credito', '… como credito');
select pruebas.igual(pruebas.afecta($$insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, tasa_anual_pb)
  values ('e5200000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'Préstamo B', 'con_costo', 'c9200000-0000-4000-8000-000000000002', 1000, 'mensual', 2400)$$ || ' on conflict (id) do nothing'), 0,
  'y reenviarla igual no duplica');

-- ---------------------------------------------------------------- parámetros nuevos
select pruebas.igual((select dias_aviso_deuda::text || orden_ahorro::text || esenciales_incluyen_minimos::text || dependientes_cuidados::text
  from public.fin_parametros where libro_id = pruebas.libro_personal('ana@ejemplo.test')),
  '{3,1}{fondo_n1,reservas,metas_fecha,fondo_meta,metas_libres}truefalse', 'Valores por omisión de fin_parametros');
select pruebas.igual(pruebas.afecta($$update public.fin_parametros set dias_aviso_deuda = '{7,3,1}', dependientes_cuidados = true
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$), 1, 'Ana cambia los días de aviso y declara dependientes');
select pruebas.falla($$update public.fin_parametros set dias_aviso_deuda = '{15}' where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$,
  'Los días van de 0 a 14', '23514');
select pruebas.falla($$update public.fin_parametros set dias_aviso_deuda = '{3,3}' where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$,
  'Sin repetidos', '23514');
select pruebas.falla($$update public.fin_parametros set dias_aviso_deuda = '{1,2,3,4}' where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$,
  'Hasta 3 avisos', '23514');
select pruebas.falla($$update public.fin_parametros set orden_ahorro = '{fondo_n1,fondo_n1,reservas,metas_fecha,fondo_meta}'
  where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$, 'El orden del ahorro no repite pasos', '23514');

-- ---------------------------------------------------------------- MSI
select pruebas.falla($$insert into public.fin_msi (hogar_id, libro_id, deuda_id, cuenta_pasivo_id, fecha_compra, monto_total_centavos, mensualidades)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'e5200000-0000-4000-8000-000000000002',
          'c9200000-0000-4000-8000-000000000002', '2026-10-01', 600000, 12)$$, 'La deuda de un MSI es de clase msi', '22023');
select pruebas.falla($$update public.fin_msi set mensualidades = 1$$, 'Un MSI tiene de 2 a 48 mensualidades', '23514');
select pruebas.falla($$update public.fin_msi set mensualidades = 49$$, '… hasta 48', '23514');
select pruebas.falla($$update public.fin_msi set cuenta_pasivo_id = 'c9200000-0000-4000-8000-000000000002'$$,
  'Su cuenta pasivo no cambia', '42501');
select pruebas.igual((select msi_pendiente_centavos from public.fin_v_deuda_resumen where deuda_id = 'e5000000-0000-4000-8000-000000000001'),
  600000::bigint, 'La tarjeta muestra el MSI pendiente (sale del libro, no se guarda)');
select pruebas.igual((select saldo_centavos from public.fin_v_deuda_resumen where deuda_id = 'e5000000-0000-4000-8000-000000000003'),
  600000::bigint, 'El pasivo propio del MSI subió por el total de la compra');

-- ---------------------------------------------------------------- 12: estados de cuenta, solo agregar
select pruebas.igual(pruebas.afecta($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('e8000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000001', '2026-10-20', '2026-11-09', 610000, 46000, 610000, '2026-10-22 10:00-06')$$), 1,
  'Ana corrige el corte agregando otro estado de cuenta');
select pruebas.igual((select id from public.fin_v_estados_cuenta_vigentes where deuda_id = 'e5000000-0000-4000-8000-000000000001'
  and fecha_corte = '2026-10-20'), 'e8000000-0000-4000-8000-000000000002', 'El último registro de un corte es el vigente');
select pruebas.igual((select count(*)::int from public.fin_estados_cuenta where deuda_id = 'e5000000-0000-4000-8000-000000000001'), 2,
  '… y el anterior queda como historial');
select pruebas.falla($$update public.fin_estados_cuenta set pago_minimo_centavos = 1$$, 'Nadie edita un estado de cuenta', '42501');
select pruebas.falla($$delete from public.fin_estados_cuenta$$, 'Nadie lo borra', '42501');
select pruebas.falla($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('e8000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000001', '2026-10-20', '2026-11-09', 999, 46000, 610000, '2026-10-22 10:00-06')$$,
  'El mismo id con otro contenido es un duplicado real', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('e8000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000001', '2026-10-20', '2026-11-09', 610000, 46000, 610000, '2026-10-22 10:00-06')
  on conflict (id) do nothing$$), 0, 'Reenviarlo igual (la cola) no duplica ni falla');
select pruebas.falla($$insert into public.fin_estados_cuenta (hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000002', '2026-10-20', '2026-11-09', 1, 1, 1, now())$$,
  'El estado de cuenta es de una tarjeta', '22023');
select pruebas.falla($$insert into public.fin_estados_cuenta (hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000001', '2026-10-20', '2026-10-01', 1, 1, 1, now())$$,
  'El límite de pago no es antes del corte', '23514');
select pruebas.falla($$insert into public.fin_estados_cuenta (hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en, registrado_por)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000001', '2026-11-20', '2026-12-09', 1, 1, 1, now(), pruebas.id_persona('alex@ejemplo.test'))$$,
  'Nadie registra a nombre de otra persona', '42501');

-- ---------------------------------------------------------------- bolsas
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c9200000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Otro ahorro', 'ahorro');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id, nivel_meta)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Otro fondo', 'fondo_emergencia',
          'c9200000-0000-4000-8000-000000000003', 3)$$, 'Un solo fondo de emergencia activo por libro', '23505');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Mala', 'meta_libre',
          'c3000000-0000-4000-8000-000000000001')$$, 'La cuenta de una bolsa es de tipo ahorro', '22023');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id, nivel_meta)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Meta', 'meta_libre',
          'c9200000-0000-4000-8000-000000000003', 3)$$, 'El nivel es solo del fondo', '23514');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id, monto_anual_centavos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Meta', 'meta_libre',
          'c9200000-0000-4000-8000-000000000003', 5200)$$, 'El monto anual es solo de las reservas', '23514');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Meta', 'meta_fecha',
          'c9200000-0000-4000-8000-000000000003')$$, 'Una meta con fecha lleva fecha y monto', '23514');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id, metodos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'Meta', 'meta_libre',
          'c9200000-0000-4000-8000-000000000003', '{magia}')$$, 'Los métodos son los de la lista', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_bolsas_ahorro (id, hogar_id, libro_id, nombre, tipo, cuenta_id, monto_anual_centavos,
    metodos, reto_base_centavos)
  values ('ea000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'Regreso a clases', 'reserva', 'c9200000-0000-4000-8000-000000000003', 780000,
          '{monto_fijo,reto_52_semanas,redondeo}', 1000)$$), 1, 'Una reserva con sus métodos entra');
select pruebas.falla($$update public.fin_bolsas_ahorro set tipo = 'meta_libre' where id = 'ea000000-0000-4000-8000-000000000003'$$,
  'El tipo y la cuenta de una bolsa no cambian', '42501');
select pruebas.igual((select saldo_centavos from public.fin_v_bolsa_saldo where bolsa_id = 'ea000000-0000-4000-8000-000000000001'),
  150000::bigint, 'El saldo de la bolsa sale del libro (fin_v_bolsa_saldo)');
select pruebas.falla($$delete from public.fin_bolsas_ahorro$$, 'Una bolsa no se borra (se desactiva)', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_bolsas_ahorro set activa = false where id = 'ea000000-0000-4000-8000-000000000003'$$), 1,
  'Se desactiva con activa');

-- ---------------------------------------------------------------- aportaciones
select pruebas.ok(pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000010',
  15000, '2026-10-19', p_id => 'd1000000-0000-4000-8000-0000000000a1') is not null, 'Ana aporta $150 al fondo (transferencia)');
select pruebas.igual(pruebas.afecta($$insert into public.fin_aportaciones_ahorro (id, hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos)
  values ('ef000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e6000000-0000-4000-8000-000000000002', 'ea000000-0000-4000-8000-000000000001', 20000)$$), 1, 'Se propone la aportación de la semana activa');
select pruebas.igual((select pendiente_centavos from public.fin_aportaciones_ahorro where id = 'ef000000-0000-4000-8000-000000000001'),
  20000::bigint, 'pendiente = sugerido − aportado (generada)');
select pruebas.falla($$insert into public.fin_aportaciones_ahorro (hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos, pendiente_centavos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e6000000-0000-4000-8000-000000000002', 'ea000000-0000-4000-8000-000000000002', 5, 5)$$, 'pendiente_centavos no se manda (es generada)', '428C9');
select pruebas.falla($$insert into public.fin_aportaciones_ahorro (hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e6000000-0000-4000-8000-000000000002', 'ea000000-0000-4000-8000-000000000001', 1)$$, 'Una aportación por semana y bolsa', '23505');
select pruebas.falla($$update public.fin_aportaciones_ahorro set estado = 'confirmada', aportado_centavos = 15000
  where id = 'ef000000-0000-4000-8000-000000000001'$$, 'Confirmada exige su movimiento', '23514');
select pruebas.igual(pruebas.afecta($$update public.fin_aportaciones_ahorro set estado = 'pospuesta' where id = 'ef000000-0000-4000-8000-000000000001'$$), 1,
  'Posponer no mueve dinero');
select pruebas.igual(pruebas.afecta($$update public.fin_aportaciones_ahorro set estado = 'confirmada', aportado_centavos = 15000,
    movimiento_id = 'd1000000-0000-4000-8000-0000000000a1' where id = 'ef000000-0000-4000-8000-000000000001'$$), 1,
  'Confirmar deja aportado y movimiento');
select pruebas.igual((select pendiente_centavos from public.fin_aportaciones_ahorro where id = 'ef000000-0000-4000-8000-000000000001'),
  5000::bigint, 'Lo no aportado queda como pendiente, sin castigo');
select pruebas.ok((select confirmada_por = pruebas.id_persona('ana@ejemplo.test') and confirmada_en is not null
  from public.fin_aportaciones_ahorro where id = 'ef000000-0000-4000-8000-000000000001'), 'Queda quién y cuándo (lo pone el servidor)');
select pruebas.falla($$update public.fin_aportaciones_ahorro set aportado_centavos = 1 where id = 'ef000000-0000-4000-8000-000000000001'$$,
  'El movimiento y lo aportado ya no se cambian', '42501');
-- Semana cerrada: solo se confirma la aportación (la del cierre recién hecho).
select pruebas.igual(pruebas.afecta($$insert into public.fin_aportaciones_ahorro (id, hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos)
  values ('ef000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e6000000-0000-4000-8000-000000000001', 'ea000000-0000-4000-8000-000000000001', 10000)$$), 1,
  'El cierre propone el reparto de la semana cerrada');
select pruebas.falla($$update public.fin_aportaciones_ahorro set sugerido_centavos = 20000 where id = 'ef000000-0000-4000-8000-000000000002'$$,
  'Pero la propuesta de una semana cerrada no se edita', '55000');
select pruebas.ok(pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000010',
  10000, '2026-10-14', p_id => 'd1000000-0000-4000-8000-0000000000a2') is not null, 'Se aporta con la fecha de la semana cerrada');
select pruebas.igual(pruebas.afecta($$update public.fin_aportaciones_ahorro set estado = 'confirmada', aportado_centavos = 10000,
    movimiento_id = 'd1000000-0000-4000-8000-0000000000a2' where id = 'ef000000-0000-4000-8000-000000000002'$$), 1,
  'Sí se puede confirmar la aportación de la semana recién cerrada');

-- ---------------------------------------------------------------- 26: retiros
select pruebas.ok(pruebas.registrar('transferencia', 'c3000000-0000-4000-8000-000000000010', 'c3000000-0000-4000-8000-000000000001',
  5000, '2026-10-21', p_id => 'd1000000-0000-4000-8000-0000000000a3') is not null, 'Ana retira $50 del fondo');
select pruebas.falla($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000a3', 'emergencia', E'\t ab', now())$$, 'El motivo vale con 3 caracteres visibles', '23514');
select pruebas.falla($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000a1', 'emergencia', 'Se descompuso la lavadora', now())$$,
  'El retiro es una transferencia DESDE la cuenta de la bolsa', '22023');
select pruebas.falla($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000a3', 'cambio_destino', 'Cambio de plan', now())$$, 'El cambio de destino lleva la bolsa de destino', '23514');
select pruebas.igual(pruebas.afecta($$insert into public.fin_retiros_ahorro (id, hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, registrado_en)
  values ('e7000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'ea000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-0000000000a3', 'emergencia', 'Se descompuso la lavadora', now())$$), 1,
  'Retiro de emergencia con motivo');
select pruebas.ok(exists (select 1 from public.bitacora where tabla = 'fin_retiros_ahorro' and registro_id = 'e7000000-0000-4000-8000-000000000001'),
  '… queda en la bitácora');
select pruebas.falla($$update public.fin_retiros_ahorro set tipo = 'uso_previsto'$$, 'Un retiro no se edita', '42501');
select pruebas.falla($$delete from public.fin_retiros_ahorro$$, 'ni se borra', '42501');
select pruebas.falla($$insert into public.fin_retiros_ahorro (hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'ea000000-0000-4000-8000-000000000001',
          'd1000000-0000-4000-8000-0000000000a3', 'emergencia', 'Otra vez el mismo', now())$$, 'Un movimiento, un retiro', '23505');
select pruebas.igual((select saldo_centavos from public.fin_v_bolsa_saldo where bolsa_id = 'ea000000-0000-4000-8000-000000000001'),
  170000::bigint, 'Saldo del fondo: 1,500 + 150 + 100 − 50 = $1,700 (sale del libro)');

-- ---------------------------------------------------------------- 28: RLS
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(
  pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$) + pruebas.cuenta($$select * from public.fin_msi$$)
  + pruebas.cuenta($$select * from public.fin_estados_cuenta$$) + pruebas.cuenta($$select * from public.fin_aportaciones_ahorro$$)
  + pruebas.cuenta($$select * from public.fin_retiros_ahorro$$) + pruebas.cuenta($$select * from public.fin_v_deuda_resumen
      where libro_id = pruebas.libro_personal('ana@ejemplo.test')$$) + pruebas.cuenta($$select * from public.fin_v_bolsa_saldo$$),
  0, 'La pareja no ve las deudas, bolsas ni estados de cuenta del libro personal del dueño');
select pruebas.falla($$insert into public.fin_bolsas_ahorro (hogar_id, libro_id, nombre, tipo, cuenta_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'), 'X', 'meta_libre', 'c9200000-0000-4000-8000-000000000003')$$,
  'ni escribe en ellas', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$) + pruebas.cuenta($$select * from public.fin_estados_cuenta$$)
  + pruebas.cuenta($$select * from public.fin_msi$$), 0, 'Una familiar no ve nada');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$) + pruebas.cuenta($$select * from public.fin_retiros_ahorro$$), 0,
  'La cuidadora tampoco');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$) + pruebas.cuenta($$select * from public.fin_aportaciones_ahorro$$), 0,
  'ni la cuenta Hogar');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$) + pruebas.cuenta($$select * from public.fin_msi$$), 0,
  'ni otro hogar');
-- La maestra: portada sí; contenido solo con consulta; nunca escribe.
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$), 0, 'La maestra sin consulta no lee las bolsas');
select pruebas.ok(public.fin_registrar_consulta_maestra(pruebas.libro_personal('ana@ejemplo.test')), 'Registra su consulta');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_bolsas_ahorro$$) >= 2 and pruebas.cuenta($$select * from public.fin_estados_cuenta$$) >= 2
  and pruebas.cuenta($$select * from public.fin_msi$$) = 1, 'Con la consulta lee bolsas, estados de cuenta y MSI');
select pruebas.falla($$insert into public.fin_estados_cuenta (hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, registrado_en)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
          'e5000000-0000-4000-8000-000000000001', '2026-12-20', '2027-01-09', 1, 1, 1, now())$$, 'y nunca escribe', '42501');
select pruebas.igual(pruebas.afecta($$update public.fin_bolsas_ahorro set activa = false$$), 0, 'ni cambia bolsas');

-- ---------------------------------------------------------------- 57: contrato de columnas
select pruebas.como_postgres();
select pruebas.ok(
  not has_column_privilege('authenticated', 'public.fin_aportaciones_ahorro', 'pendiente_centavos', 'INSERT')
  and not has_column_privilege('authenticated', 'public.fin_aportaciones_ahorro', 'confirmada_por', 'INSERT')
  and not has_column_privilege('authenticated', 'public.fin_aportaciones_ahorro', 'confirmada_en', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.fin_estados_cuenta', 'recibido_en', 'INSERT')
  and not has_column_privilege('authenticated', 'public.fin_retiros_ahorro', 'recibido_en', 'INSERT')
  and has_column_privilege('authenticated', 'public.fin_estados_cuenta', 'registrado_en', 'INSERT')
  and has_column_privilege('authenticated', 'public.fin_deudas', 'clase', 'INSERT')
  and has_column_privilege('authenticated', 'public.fin_parametros', 'dias_aviso_deuda', 'UPDATE'),
  'La app no manda lo que pone el servidor (pendiente, quién confirmó, recibido_en); sí registrado_en, clase y días de aviso');
select pruebas.ok(not has_table_privilege('authenticated', 'public.fin_estados_cuenta', 'UPDATE')
  and not has_any_column_privilege('authenticated', 'public.fin_estados_cuenta', 'UPDATE')
  and not has_any_column_privilege('authenticated', 'public.fin_retiros_ahorro', 'UPDATE')
  and not has_table_privilege('service_role', 'public.fin_retiros_ahorro', 'DELETE'),
  'Las tablas solo agregar no tienen UPDATE ni DELETE para la API');

rollback;
