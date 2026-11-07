-- Cuidados (Fase 5): turnos (spec 5 §3), recordatorios solo a quien está de turno (criterio 1), marcado de tomas y
-- cambio urgente con su aviso (criterio 4). Hogar Ejemplo; zona America/Mexico_City (UTC-6 en noviembre, sin horario de verano).
-- Semana de prueba: lunes 9/nov/2026 a domingo 15/nov/2026.
begin;

create function pg_temp.turno(p_ts text) returns text
language sql security definer
as $$
  select coalesce(string_agg(split_part(u.email, '@', 1) || ':' || q.tipo, ',' order by u.email, q.tipo), '-')
    from public.cui_quien_en_turno('b0000000-0000-4000-8000-000000000001', p_ts::timestamptz) q
    join public.personas p on p.id = q.persona_id join auth.users u on u.id = p.usuario_id
$$;
grant execute on function pg_temp.turno(text) to authenticated, service_role;

-- ---------------------------------------------------------------- quién está de turno (la dueña consulta)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pg_temp.turno('2026-11-09 08:00-06'), 'ana:dueno', 'Lunes 8:00: nadie de cuidado, cubre el dueño (turno residual)');
select pruebas.igual(pg_temp.turno('2026-11-09 09:00-06'), 'diana:cuidadora', 'Lunes 9:00: la cuidadora');
select pruebas.igual(pg_temp.turno('2026-11-09 14:59-06'), 'diana:cuidadora', 'Lunes 14:59: la cuidadora');
select pruebas.igual(pg_temp.turno('2026-11-09 15:00-06'), 'ana:dueno', 'Lunes 15:00: el dueño toma la tarde');
select pruebas.igual(pg_temp.turno('2026-11-09 15:00:00+00'), 'diana:cuidadora', 'Las horas se leen en la zona del hogar (15:00 UTC = 9:00 en la Ciudad de México)');
select pruebas.igual(pg_temp.turno('2026-11-10 07:29-06'), 'ana:dueno', 'Martes 7:29: cubre el dueño');
select pruebas.igual(pg_temp.turno('2026-11-10 07:30-06'), 'diana:cuidadora', 'Martes 7:30: la cuidadora');
select pruebas.igual(pg_temp.turno('2026-11-10 15:00-06'), 'carla:hermana_visita', 'Martes 15:00: la hermana (sin la cuidadora)');
select pruebas.igual(pg_temp.turno('2026-11-11 06:59-06'), 'carla:hermana_visita', 'Miércoles 6:59: la hermana todavía');
select pruebas.igual(pg_temp.turno('2026-11-11 07:00-06'), 'ana:dueno', 'Miércoles 7:00: la hermana se va, cubre el dueño hasta las 7:30');
select pruebas.igual(pg_temp.turno('2026-11-11 18:29-06'), 'diana:cuidadora', 'Miércoles 18:29: la cuidadora');
select pruebas.igual(pg_temp.turno('2026-11-11 18:30-06'), 'ana:dueno', 'Miércoles 18:30: termina la cuidadora, cubre el dueño');
select pruebas.igual(pg_temp.turno('2026-11-13 18:00-06'), 'diana:cuidadora', 'Viernes 18:00: la cuidadora');
select pruebas.igual(pg_temp.turno('2026-11-14 10:00-06'), 'diana:cuidadora', 'Sábado por la mañana: la cuidadora');
select pruebas.igual(pg_temp.turno('2026-11-14 16:00-06'), 'ana:dueno', 'Sábado por la tarde: el dueño');
select pruebas.igual(pg_temp.turno('2026-11-15 00:00-06'), 'ana:dueno', 'Domingo desde la medianoche: el dueño');
select pruebas.igual(pg_temp.turno('2026-11-15 12:00-06'), 'ana:dueno', 'Domingo todo el día: solo el dueño');
select pruebas.igual(pg_temp.turno('2026-11-15 23:59-06'), 'ana:dueno', '… hasta el final del día');

-- Criterio 1: el destinatario de cada recordatorio sale de esta función y fuera de turno no sale nadie.
select pruebas.igual(public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 2), 6, 'Tomas del lunes y el martes');
select pruebas.igual(
  (select string_agg(to_char(t.programada_para at time zone 'America/Mexico_City', 'DD HH24:MI') || '=' ||
                     pg_temp.turno(t.programada_para::text), ' ' order by t.programada_para)
     from public.cui_tomas t where t.programada_para < '2026-11-10 00:00-06'),
  '09 08:00=ana:dueno 09 14:00=diana:cuidadora 09 20:00=ana:dueno',
  'Criterio 1: la toma de las 8:00 del lunes va al dueño (residual); la de las 14:00, a la cuidadora; la de las 20:00, al dueño');

-- Turno residual del dueño (spec 5 §8c): de madrugada y de noche, sin cuidadora ni hermana, devuelve al dueño y a nadie más
select pruebas.igual(pg_temp.turno('2026-11-10 02:00-06'), 'ana:dueno', 'Martes 2:00: la noche sin turno devuelve al dueño');
select pruebas.igual(pg_temp.turno('2026-11-12 23:00-06'), 'ana:dueno', 'Jueves 23:00: la noche sin turno devuelve al dueño');
select pruebas.igual(pg_temp.turno('2026-11-10 16:00-06'), 'carla:hermana_visita', 'Con la hermana de turno no se añade al dueño');
select pruebas.igual(pg_temp.turno('2026-11-09 16:00-06'), 'ana:dueno', 'Con turno propio el dueño no sale repetido');

-- La cuidadora ve a quién avisarían, y a sí misma solo dentro de su turno
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pg_temp.turno('2026-11-09 08:00-06'), 'ana:dueno', 'Diana a las 8:00 del lunes: no está de turno (cubre el dueño)');
select pruebas.igual(pg_temp.turno('2026-11-09 10:00-06'), 'diana:cuidadora', 'y a las 10:00 sí');
select pruebas.igual(pg_temp.turno('2026-11-15 12:00-06'), 'ana:dueno', 'El domingo ve que cuida el dueño');

-- Sin perfil en Cuidados, nada (Casa, otro hogar)
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pg_temp.turno('2026-11-09 10:00-06'), '-', 'Casa no consulta los turnos (D3)');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pg_temp.turno('2026-11-09 10:00-06'), '-', 'ni otro hogar');
-- El servidor (avisos) sí: sin sesión de usuario
select pruebas.como_servicio();
select pruebas.igual(pg_temp.turno('2026-11-09 10:00-06'), 'diana:cuidadora', 'El servidor de avisos consulta quién está de turno');
select pruebas.igual(public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-11', 1), 3, 'y genera las tomas del día');

-- ---------------------------------------------------------------- marcar tomas
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t
  where t.programada_para = '2026-11-09 14:00-06'$$), 1, 'La cuidadora marca "dado" la toma de las 14:00 del lunes (su turno)');
select pruebas.ok((select estado = 'dado' and marcada_por = pruebas.id_persona('diana@ejemplo.test') and marcada_en is not null
                     from public.cui_tomas where programada_para = '2026-11-09 14:00-06'), 'Queda quién y cuándo');
select pruebas.falla($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-09 08:00-06'$$,
  'No marca una toma de antes de su turno (8:00 del lunes)', '42501');
select pruebas.falla($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-09 20:00-06'$$,
  'ni una del turno del dueño (20:00)', '42501');
select pruebas.falla($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-10 20:00-06'$$,
  'ni una del turno de la hermana', '42501');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'no_dado') from public.cui_tomas t
  where t.programada_para = '2026-11-09 14:00-06'$$), 1, 'Puede corregirla a "no_dado"');
select pruebas.falla($$select public.cui_marcar_toma(t.id, 'pendiente') from public.cui_tomas t where t.programada_para = '2026-11-09 14:00-06'$$,
  'No la regresa a pendiente', '22023');
select pruebas.falla($$select public.cui_marcar_toma(gen_random_uuid(), 'dado')$$, 'Una toma que no existe: 42501 como cualquier otra', '42501');
select pruebas.igual(
  (select count(*)::int from public.bitacora where accion = 'cuidados.toma_marcada' and persona_id = pruebas.id_persona('diana@ejemplo.test')),
  2, 'Cada cambio de estado queda en la bitácora (2 marcas)');
select pruebas.ok((select bool_and(detalle = jsonb_build_object('estado', detalle ->> 'estado')) from public.bitacora where accion = 'cuidados.toma_marcada'),
  'y el detalle es solo el estado (sin medicamento, dosis ni hora)');

select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-10 20:00-06'$$,
  'La hermana solo lee los medicamentos, también en su turno de martes', '42501');

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t where t.programada_para = '2026-11-09 08:00-06'$$), 1,
  'El dueño marca cualquier toma');
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'cuidados.toma_marcada' and persona_id = pruebas.id_persona('ana@ejemplo.test')), 1,
  'y también queda en la bitácora');
select pruebas.igual((select tomas_dadas || '/' || tomas_no_dadas || '/' || tomas_pendientes from public.cui_resumen_papa('b0000000-0000-4000-8000-000000000001', '2026-11-09')),
  '1/1/1', 'El resumen del día: una dada, una no dada y una pendiente');

-- ---------------------------------------------------------------- cambio urgente (criterio 4)
-- Para que la prueba no dependa de la hora en que corre, la cuidadora tiene un turno de todo el día de HOY.
select pruebas.igual(pruebas.afecta($$insert into public.cui_turnos (hogar_id, persona_id, dia_semana, inicio_min, fin_min, tipo)
  select 'b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'),
         extract(isodow from now() at time zone 'America/Mexico_City')::int, 0, 1440, 'cuidadora'$$), 1,
  'Preparación: turno de todo el día de hoy para la cuidadora');
select pruebas.falla($$select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', repeat('x', 201))$$, 'El cambio urgente lleva 200 caracteres como máximo', '22023');
select pruebas.falla($$select public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', '   ')$$, 'y no va vacío', '22023');
select pruebas.igual(public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'Papá no debe comer sal hoy (ejemplo)',
  'a5400000-0000-4000-8000-000000000001'), 'a5400000-0000-4000-8000-000000000001'::uuid, 'El dueño manda un cambio urgente');
select pruebas.igual(public.cui_crear_cambio_urgente('b0000000-0000-4000-8000-000000000001', 'Papá no debe comer sal hoy (ejemplo)',
  'a5400000-0000-4000-8000-000000000001'), 'a5400000-0000-4000-8000-000000000001'::uuid, 'Reenviarlo con el mismo id (cola sin conexión) no lo duplica');
select pruebas.ok((select para_persona = pruebas.id_persona('diana@ejemplo.test') and de_persona = pruebas.id_persona('ana@ejemplo.test')
                     and atendido_en is null from public.cui_cambios_urgentes), 'Va para la cuidadora de turno');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where objeto_tipo = 'cambio_urgente'$$), 0, 'La dueña no recibe aviso de su propio cambio');

select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos where objeto_id = 'a5400000-0000-4000-8000-000000000001'
                         and persona_id = pruebas.id_persona('diana@ejemplo.test') and modulo = 'cuidados'
                         and tipo = 'cambio_urgente_cuidados' and severidad = 'critica' and objeto_tipo = 'cambio_urgente'
                         and estado = 'pendiente' and libro_id is null), 1,
  'Criterio 4: aviso crítico inmediato a la cuidadora de turno (sin texto: apunta al cambio)');
select pruebas.ok((select enviar_en <= now() from public.avisos where objeto_id = 'a5400000-0000-4000-8000-000000000001'
                     and persona_id = pruebas.id_persona('diana@ejemplo.test')),
  'y sale al instante, sin esperar el silencio nocturno (D4)');
select pruebas.igual((select count(*)::int from public.avisos where objeto_id = 'a5400000-0000-4000-8000-000000000001'),
  (select count(distinct q.persona_id)::int from public.cui_quien_en_turno('b0000000-0000-4000-8000-000000000001') q
    where q.tipo <> 'dueno'),
  'Reciben el aviso todos los cuidadores que están de turno ahora (la cuidadora y, si coincide, la hermana), una vez cada uno');
select pruebas.igual((select count(*)::int from public.avisos where objeto_id = 'a5400000-0000-4000-8000-000000000001'
                         and persona_id not in (pruebas.id_persona('diana@ejemplo.test'), pruebas.id_persona('carla@ejemplo.test'))), 0,
  'Nadie más lo recibe (ni la pareja ni la dueña)');
select pruebas.ok((select bool_and(accion in ('insertar', 'actualizar')) and bool_and(not (detalle::text ilike '%no debe comer%'))
                     from public.bitacora where tabla = 'cui_cambios_urgentes'), 'D3: el texto del cambio no se copia a la bitácora de auditoría');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where objeto_tipo = 'cambio_urgente' and estado = 'pendiente'$$), 1, 'La cuidadora ve su aviso');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_cambios_urgentes$$), 1, '… y lee el cambio');
select pruebas.falla($$insert into public.cui_cambios_urgentes (hogar_id, de_persona, texto)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('diana@ejemplo.test'), 'x')$$, 'Ella no crea cambios urgentes', '42501');
select pruebas.falla($$update public.cui_cambios_urgentes set atendido_en = now()$$, 'ni lo marca atendido directo', '42501');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.cui_cambios_urgentes$$) + pruebas.cuenta($$select * from public.avisos where objeto_tipo = 'cambio_urgente'$$), 0,
  'La pareja no ve el cambio urgente ni su aviso');
select pruebas.falla($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-000000000001')$$, 'ni lo atiende', '42501');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-000000000001')$$), 1, 'La cuidadora lo marca atendido');
select pruebas.ok((select atendido_en is not null from public.cui_cambios_urgentes), 'Queda la hora');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where objeto_tipo = 'cambio_urgente' and estado = 'resuelta'$$), 1, 'y su aviso queda resuelto');
select pruebas.igual(pruebas.afecta($$select public.cui_atender_cambio_urgente('a5400000-0000-4000-8000-000000000001')$$), 1, 'Atenderlo otra vez no falla');

rollback;
