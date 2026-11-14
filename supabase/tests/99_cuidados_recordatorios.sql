-- Cuidados: recordatorios de toma desde el servidor (migración 20261124, spec 5 v1.7 8i).
-- Hogar Ejemplo (UTC-6). Lunes 9/nov/2026: Diana (cuidadora) 9:00-15:00, Ana (dueña) 15:00-24:00; martes: Diana 7:30-15:00,
-- Carla (hermana) 15:00-24:00. Medicamento A 8:00 y 20:00, B 14:00. Alex pareja, Marta maestra, Casa.
begin;

select pruebas.como_servicio();
select pruebas.igual(public.cui_generar_tomas('b0000000-0000-4000-8000-000000000001', '2026-11-09', 2), 6, 'Preparación: tomas del lunes y el martes');

-- Cuenta los avisos de recordatorio de la toma de esa hora para una persona (leyendo como superusuario, sin RLS)
select pruebas.como_postgres();
create function pg_temp.n(p_correo text, p_ts text) returns integer language sql as $$
  select count(*)::int from public.avisos a join public.cui_tomas t on t.id = a.objeto_id
   where a.tipo = 'recordatorio_toma' and a.persona_id = pruebas.id_persona(p_correo) and t.programada_para = p_ts::timestamptz $$;
create function pg_temp.total() returns integer language sql as $$
  select count(*)::int from public.avisos where tipo = 'recordatorio_toma' $$;

-- Solo el servidor
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.cui_avisar_tomas_proximas()$$, 'Ni el dueño la ejecuta (solo el servidor)', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.cui_avisar_tomas_proximas()$$, 'La cuidadora tampoco', '42501');
select pruebas.como_servicio();
select pruebas.falla($$select public.cui_avisar_tomas_proximas(0)$$, 'Ventana de 0 minutos inválida', '22023');
select pruebas.falla($$select public.cui_avisar_tomas_proximas(121)$$, 'Ventana de más de 120 minutos inválida', '22023');

-- Fuera de ventana: lunes 13:30 (-06) y la toma de las 14:00 está a 30 minutos
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-09 13:30-06'), 0, 'Fuera de ventana no genera nada');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total(), 0, 'y no hay avisos de toma');

-- En ventana: lunes 13:50, la de las 14:00 es de la cuidadora
select pruebas.como_servicio();
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-09 13:50-06'), 1, 'En ventana crea un aviso');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.n('diana@ejemplo.test', '2026-11-09 14:00-06'), 1, 'Va a la cuidadora de turno');
select pruebas.igual(pg_temp.total(), 1, 'y a nadie más');
select pruebas.ok((select a.severidad = 'importante' and a.modulo = 'cuidados' and a.objeto_tipo = 'toma' and a.estado = 'pendiente'
                         and a.libro_id is null and a.enviar_en = '2026-11-09 14:00-06'::timestamptz
                     from public.avisos a where a.tipo = 'recordatorio_toma'),
  'Importante, módulo cuidados, apunta a la toma y sale a la hora de la toma');

-- No se repite
select pruebas.como_servicio();
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-09 13:50-06'), 0, 'Segunda corrida: no crea otro');
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-09 13:55-06'), 0, 'Ni cinco minutos después');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total(), 1, 'Sigue habiendo un solo aviso');

-- Una toma marcada no avisa (lunes 20:00 del dueño, marcada antes)
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$select public.cui_marcar_toma(t.id, 'dado') from public.cui_tomas t
  where t.programada_para = '2026-11-09 20:00-06'$$), 1, 'Preparación: el dueño marca la de las 20:00');
select pruebas.como_servicio();
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-09 19:50-06'), 0, 'Una toma ya marcada no genera aviso');

-- Turno del dueño: la de las 8:00 del lunes nadie está de turno, cubre el dueño (residual)
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-09 07:50-06'), 1, 'Sin cuidadora de turno, el aviso va al dueño');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.n('ana@ejemplo.test', '2026-11-09 08:00-06'), 1, 'El dueño recibe el de las 8:00');

-- Pospuesta a otra persona: martes 20:00 es de Carla; la pospone ella y pasa a la siguiente persona de turno (miércoles)
select pruebas.como('carla@ejemplo.test');
select pruebas.ok((select public.cui_posponer_toma(t.id) is not null from public.cui_tomas t where t.programada_para = '2026-11-10 20:00-06'),
  'Carla pospone su toma del martes 20:00');
select pruebas.como_postgres();
select pruebas.ok((select pospuesta_a is not null and pospuesta_turno_en is not null from public.cui_tomas where programada_para = '2026-11-10 20:00-06'),
  'Queda pospuesta a alguien con la hora de su turno');
select pruebas.como_servicio();
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-10 19:50-06'), 0, 'A la hora original no avisa (ya no es de Carla)');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.n('carla@ejemplo.test', '2026-11-10 20:00-06'), 0, 'Carla no recibe el recordatorio de la que pasó');
select pruebas.como_servicio();
select pruebas.igual(public.cui_avisar_tomas_proximas(15, (select pospuesta_turno_en - interval '5 minutes' from public.cui_tomas
                                                            where programada_para = '2026-11-10 20:00-06')), 1,
  'Cerca del turno de quien la recibió, avisa');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos a join public.cui_tomas t on t.id = a.objeto_id
                       where a.tipo = 'recordatorio_toma' and t.programada_para = '2026-11-10 20:00-06'
                         and a.persona_id = t.pospuesta_a), 1, 'Va a la persona a quien se la pasaron');

-- Pareja, maestra y Casa no reciben nunca; el aviso no lleva nombres
select pruebas.como_servicio();
select public.cui_avisar_tomas_proximas(120, '2026-11-09 07:00-06');
select public.cui_avisar_tomas_proximas(120, '2026-11-09 13:00-06');
select public.cui_avisar_tomas_proximas(120, '2026-11-10 07:00-06');
select public.cui_avisar_tomas_proximas(120, '2026-11-10 13:00-06');
select public.cui_avisar_tomas_proximas(120, '2026-11-10 19:00-06');
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.avisos a
                       where a.tipo = 'recordatorio_toma'
                         and a.persona_id in (pruebas.id_persona('alex@ejemplo.test'), pruebas.id_persona('marta@ejemplo.test'),
                                              pruebas.id_persona('casa@ejemplo.test'))), 0,
  'La pareja, la maestra y Casa no reciben recordatorios de toma');
select pruebas.ok(not exists (select 1 from public.avisos a where a.tipo = 'recordatorio_toma'
                               and (a.clave ~* '(medicamento|ejemplo|dosis|tableta|capsula)')),
  'La clave del aviso no lleva nombres de medicamento ni de persona (D6)');
select pruebas.ok(not exists (select 1 from information_schema.columns
                               where table_schema = 'public' and table_name = 'avisos'
                                 and column_name in ('texto', 'nota', 'concepto', 'nombre', 'titulo', 'cuerpo')),
  'avisos no tiene columnas de texto: el texto genérico vive en el catálogo de la app');
select pruebas.ok((select bool_and(clave = 'toma:' || objeto_id::text || ':' || persona_id::text) from public.avisos where tipo = 'recordatorio_toma'),
  'La clave es estable: toma y destinatario');

-- El aviso de toma no cuenta para el tope diario de no críticas
select pruebas.ok(not exists (select 1 from public.avisos where tipo = 'recordatorio_toma' and estado = 'agrupada'),
  'Ningún recordatorio de toma queda agrupado por el tope diario');

-- Una medicina inactiva no avisa
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.cui_medicamentos set activo = false where id = 'a5200000-0000-4000-8000-000000000002'$$), 1,
  'Preparación: el dueño desactiva el medicamento B');
select pruebas.como_servicio();
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-11 13:50-06'), 0, 'Sin tomas pendientes de medicamentos activos, nada (miércoles)');
select pruebas.igual(public.cui_avisar_tomas_proximas(15, '2026-11-10 13:50-06'), 0, 'Medicamento inactivo: no avisa (martes 14:00)');

rollback;
