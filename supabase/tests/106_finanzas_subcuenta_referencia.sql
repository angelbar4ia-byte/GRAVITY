-- Finanzas · v1.2 (docs/specs/fase-8-finanzas-ampliaciones.md, 1b y 2): transferencia a la casa a una SUBCUENTA,
-- referencia por subcuenta y aviso al receptor.
-- Hogar Ejemplo: Ana (dueña), Alex (pareja), Carla (familiar), Diana (cuidadora), Hogar (rol casa), Marta (cuenta maestra).
-- Cuentas: Ana c3…01, Alex c4…01, casa c5…01. Categorías: Luz c1…07, Agua c1…08.
begin;

-- ---------------------------------------------------------------- 0: casa y subcuentas
select pruebas.como('ana@ejemplo.test');
select public.fin_casa_configurar('f1000000-0000-4000-8000-000000000001', 'mes');
insert into public.fin_casa_subcuentas (id, hogar_id, libro_id, categoria_id, dia_limite, cada_meses, monto_estimado_centavos)
values ('a1061000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
        'c1000000-0000-4000-8000-000000000007', 17, 2, 120000),
       ('a1061000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
        'c1000000-0000-4000-8000-000000000008', 5, 1, 30000);

-- ---------------------------------------------------------------- 1: la ruta a la casa lleva subcuenta
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000090',
  'c4000000-0000-4000-8000-000000000001', null, 60000, '2026-11-10')$$,
  '1: pareja -> casa sin subcuenta se rechaza', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000091',
  'c4000000-0000-4000-8000-000000000001', null, 60000, '2026-11-10', null, 'a1061000-0000-4000-8000-0000000000ff')$$,
  '1: una subcuenta que no existe se rechaza', '22023');
select pruebas.falla($$select public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000092',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 100, '2026-11-10', null, 'a1061000-0000-4000-8000-000000000001')$$,
  '1: pareja -> dueño no lleva subcuenta', '22023');
select pruebas.igual(public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000001', null, 60000, '2026-11-10', null, 'a1061000-0000-4000-8000-000000000001'),
  'a1060000-0000-4000-8000-000000000001'::uuid, '1: pareja -> casa (Luz) se propone');
select pruebas.igual((select subcuenta_id from public.fin_transferencias where id = 'a1060000-0000-4000-8000-000000000001'),
  'a1061000-0000-4000-8000-000000000001'::uuid, '1: la subcuenta queda en la transferencia');
-- idempotente y con otra subcuenta es otro contenido
select pruebas.igual(public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000001', null, 60000, '2026-11-10', null, 'a1061000-0000-4000-8000-000000000001'),
  'a1060000-0000-4000-8000-000000000001'::uuid, '1: reenviar lo mismo no duplica');
select pruebas.falla($$select public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000001', null, 60000, '2026-11-10', null, 'a1061000-0000-4000-8000-000000000002')$$,
  '1: el mismo id con otra subcuenta se rechaza', '23505');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000093',
  'c3000000-0000-4000-8000-000000000001', null, 100, '2026-11-10')$$,
  '1: dueño -> casa sin subcuenta se rechaza', '22023');
select pruebas.igual(public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000002',
  'c3000000-0000-4000-8000-000000000001', null, 25000, '2026-11-10', 'Agua', 'a1061000-0000-4000-8000-000000000002'),
  'a1060000-0000-4000-8000-000000000002'::uuid, '1: dueño -> casa (Agua) se propone');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.fin_proponer_transferencia('a1060000-0000-4000-8000-000000000003',
  'c4000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 40000, '2026-11-10'),
  'a1060000-0000-4000-8000-000000000003'::uuid, '1: pareja -> dueño sigue sin subcuenta');
select pruebas.como_postgres();
select pruebas.igual((select subcuenta_id is null from public.fin_transferencias where id = 'a1060000-0000-4000-8000-000000000003'),
  true, '1: pareja -> dueño guarda subcuenta nula');
select pruebas.falla($$insert into public.fin_transferencias (hogar_id, ruta, persona_origen_id, libro_origen_id, libro_destino_id,
  cuenta_origen_id, monto_centavos, fecha, propuesta_por)
  values ('b0000000-0000-4000-8000-000000000001', 'dueno_a_casa', pruebas.id_persona('ana@ejemplo.test'),
          pruebas.libro_personal('ana@ejemplo.test'), 'f1000000-0000-4000-8000-000000000001',
          'c3000000-0000-4000-8000-000000000001', 1, '2026-11-10', pruebas.id_persona('ana@ejemplo.test'))$$,
  '1: la base rechaza una transferencia a la casa sin subcuenta', '23514');

-- ---------------------------------------------------------------- 2: aviso solo al receptor, sin monto
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'transferencia_pendiente'), 3, '2: tres avisos, uno por transferencia');
select pruebas.igual((select a.persona_id from public.avisos a where a.objeto_id = 'a1060000-0000-4000-8000-000000000001'),
  pruebas.id_persona('ana@ejemplo.test'), '2: Alex propone a la casa: avisa a Ana');
select pruebas.igual((select a.persona_id from public.avisos a where a.objeto_id = 'a1060000-0000-4000-8000-000000000002'),
  pruebas.id_persona('alex@ejemplo.test'), '2: Ana propone a la casa: avisa a Alex');
select pruebas.igual((select a.persona_id from public.avisos a where a.objeto_id = 'a1060000-0000-4000-8000-000000000003'),
  pruebas.id_persona('ana@ejemplo.test'), '2: pareja -> dueño: avisa a la dueña');
select pruebas.igual((select count(*)::int from public.avisos a
   where a.tipo = 'transferencia_pendiente' and a.persona_id = pruebas.id_persona('carla@ejemplo.test')
      or a.tipo = 'transferencia_pendiente' and a.persona_id = pruebas.id_persona('diana@ejemplo.test')
      or a.tipo = 'transferencia_pendiente' and a.persona_id = pruebas.id_persona('marta@ejemplo.test')
      or a.tipo = 'transferencia_pendiente' and a.persona_id = pruebas.id_persona('casa@ejemplo.test')), 0,
  '2: ni la familiar, ni la cuidadora, ni la cuenta maestra, ni Casa reciben el aviso');
select pruebas.igual((select count(*)::int from public.avisos a
   where a.tipo = 'transferencia_pendiente' and a.persona_id = a.emitido_por), 0, '2: quien propone no se avisa a sí mismo');
select pruebas.igual((select string_agg(distinct a.modulo || '/' || a.severidad || '/' || a.objeto_tipo, ',')
   from public.avisos a where a.tipo = 'transferencia_pendiente'),
  'finanzas/importante/transferencia', '2: finanzas, importante, objeto transferencia');
select pruebas.igual((select count(*)::int from public.avisos a
   where a.tipo = 'transferencia_pendiente' and ((select jsonb_object_agg(k, v)::text from jsonb_each(to_jsonb(a)) e(k, v) where k not in ('id', 'clave', 'objeto_id') and k !~ '(_en|_para|_hasta)$') ~ '(60000|25000|40000|Agua)')), 0,
  '2: el aviso no lleva monto ni nota');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'transferencia_pendiente'), 2, '2: Ana ve sus dos avisos');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'transferencia_pendiente'), 1, '2: Alex ve solo el suyo');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'transferencia_pendiente'), 0, '2: la familiar no ve ninguno');

-- ---------------------------------------------------------------- 3: el aviso se cierra al responder
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_transferencia('a1060000-0000-4000-8000-000000000001', 'confirmar', 'c5000000-0000-4000-8000-000000000001');
select pruebas.como('alex@ejemplo.test');
select public.fin_responder_transferencia('a1060000-0000-4000-8000-000000000002', 'rechazar');
select pruebas.como('alex@ejemplo.test');
select public.fin_cancelar_transferencia('a1060000-0000-4000-8000-000000000003');
select pruebas.como_postgres();
select pruebas.igual((select a.estado from public.avisos a where a.objeto_id = 'a1060000-0000-4000-8000-000000000001'), 'resuelta', '3: confirmar cierra el aviso');
select pruebas.igual((select a.estado from public.avisos a where a.objeto_id = 'a1060000-0000-4000-8000-000000000002'), 'resuelta', '3: rechazar cierra el aviso');
select pruebas.igual((select a.estado from public.avisos a where a.objeto_id = 'a1060000-0000-4000-8000-000000000003'), 'cancelada', '3: cancelar quita el aviso');

-- ---------------------------------------------------------------- 4: referencia por subcuenta
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(
  (select string_agg(p.nombre_visible || '=' || r.parte_pb, ', ' order by r.parte_pb desc, p.nombre_visible)
     from public.fin_casa_referencias r join public.personas p on p.id = r.persona_id where r.subcuenta_id is null),
  'Papá (ejemplo)=5000, Alex Ejemplo=2500, Ana Ejemplo=2500', '4: por omisión 50/25/25 en el reparto general');
select pruebas.igual(
  (select string_agg(p.nombre_visible || ':' || a.referencia_centavos || ':' || a.aportado_centavos, ', ' order by p.nombre_visible)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
     join public.personas p on p.id = a.persona_id),
  'Alex Ejemplo:22500:60000, Ana Ejemplo:22500:0, Papá (ejemplo):45000:0',
  '4: sin reparto propio rige el general (estimado del mes 90000)');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 0)$$,
  '4: la referencia es de Papá, del dueño o de la pareja', '22023');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-0000000000ff', pruebas.id_persona('ana@ejemplo.test'), 0)$$,
  '4: una subcuenta inexistente se rechaza', '42501');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 10001)$$,
  '4: una parte no pasa de 10000', '22023');
select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 5000);
select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 5000);
select pruebas.igual(
  (select sum(parte_pb)::int from public.fin_casa_referencias where subcuenta_id = 'a1061000-0000-4000-8000-000000000001'),
  10000, '4: la suma de la subcuenta llega a 10000');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 6000)$$,
  '4: la suma por subcuenta no pasa de 10000', '23514');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 1)$$,
  '4: ni sumando a Papá', '23514');
select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 3000);
select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 5000);
select pruebas.igual((select count(*)::int from public.fin_casa_referencias where subcuenta_id = 'a1061000-0000-4000-8000-000000000001'),
  2, '4: fijar de nuevo actualiza, no duplica');
-- Otra subcuenta tiene su propio tope: Agua puede sumar 10000 aparte
select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000001', 10000);
select pruebas.igual((select count(*)::int from public.fin_casa_referencias where subcuenta_id = 'a1061000-0000-4000-8000-000000000002'),
  1, '4: cada subcuenta lleva su propia suma (Agua: Papá 100 %)');
-- El reparto general no cambia
select pruebas.igual((select sum(parte_pb)::int from public.fin_casa_referencias where subcuenta_id is null), 10000,
  '4: el general sigue sumando 10000');
select pruebas.igual(pruebas.afecta($$update public.fin_casa_referencias set parte_pb = 1 where subcuenta_id is not null$$), 0,
  '4: la escritura directa no toca el reparto de una subcuenta');
select pruebas.falla($$insert into public.fin_casa_referencias (hogar_id, persona_id, parte_pb, subcuenta_id)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 1, 'a1061000-0000-4000-8000-000000000002')$$,
  '4: ni insertar directo con subcuenta', '42501');
-- Quién no puede fijar
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('alex@ejemplo.test'), 1000)$$,
  '4: la pareja no fija la referencia (solo el dueño)', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 1000)$$,
  '4: la familiar no', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 1000)$$,
  '4: la cuenta maestra no', '42501');
select pruebas.como('casa@ejemplo.test');
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 1000)$$,
  '4: la cuenta Casa no', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.fin_casa_fijar_referencia('a1061000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 1)$$,
  '4: anon no ejecuta', '42501');

-- ---------------------------------------------------------------- 5: aportación devuelve la referencia por subcuenta
select pruebas.como('ana@ejemplo.test');
-- Luz: Ana 50 %, Alex 50 % (60000 al mes → 30000 c/u); Agua: Papá 100 % (30000); el resto, general (ninguna otra)
select pruebas.igual(
  (select string_agg(p.nombre_visible || ':' || a.referencia_centavos || ':' || a.aportado_centavos, ', ' order by p.nombre_visible)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
     join public.personas p on p.id = a.persona_id where a.subcuenta_id is null),
  'Alex Ejemplo:30000:60000, Ana Ejemplo:30000:0, Papá (ejemplo):30000:0',
  '5: los totales por persona suman la referencia de cada subcuenta con su reparto');
select pruebas.igual(
  (select string_agg(p.nombre_visible || ':' || a.parte_pb || ':' || a.referencia_centavos || ':' || a.aportado_centavos, ', ' order by p.nombre_visible)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
     join public.personas p on p.id = a.persona_id where a.subcuenta_id = 'a1061000-0000-4000-8000-000000000001'),
  'Alex Ejemplo:5000:30000:60000, Ana Ejemplo:5000:30000:0, Papá (ejemplo):0:0:0',
  '5: la fila de Luz lleva su referencia y lo aportado a esa subcuenta');
select pruebas.igual(
  (select string_agg(p.nombre_visible || ':' || a.referencia_centavos || ':' || a.aportado_centavos, ', ' order by p.nombre_visible)
     from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10') a
     join public.personas p on p.id = a.persona_id where a.subcuenta_id = 'a1061000-0000-4000-8000-000000000002'),
  'Alex Ejemplo:0:0, Ana Ejemplo:0:0, Papá (ejemplo):30000:0',
  '5: Agua tiene su reparto propio (Papá 100 %)');
select pruebas.igual((select count(*)::int from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')),
  9, '5: 3 filas de totales y 3 por cada subcuenta con reparto propio');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select * from public.fin_casa_aportacion('b0000000-0000-4000-8000-000000000001', '2026-11-10')$$,
  '5: la familiar no ve la aportación', '42501');

rollback;
