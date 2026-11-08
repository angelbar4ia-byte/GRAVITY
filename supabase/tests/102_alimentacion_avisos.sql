-- Alimentación, Fase 7: avisos desde el servidor (migración 20261128). Cada aviso va a quien debe y a nadie más; no se repite; sin texto ni cifras.
-- Seed: Ana dueña y albacea de Papá, Alex pareja y suplente, Carla familiar, Diana cuidadora, Casa, Marta maestra (cuenta maestra), Elena otro hogar.
begin;
select pruebas.como_postgres();
create function pg_temp.n(p_correo text, p_tipo text) returns integer language sql as $$
  select count(*)::int from public.avisos a where a.tipo = p_tipo and a.persona_id = pruebas.id_persona(p_correo) $$;
create function pg_temp.total(p_tipo text) returns integer language sql as $$
  select count(*)::int from public.avisos a where a.tipo = p_tipo $$;

-- ---------------------------------------------------------------- catálogo
select pruebas.igual(public.avisos_severidad('compra_papa_albacea'), 'importante', 'compra_papa_albacea es importante');
select pruebas.igual(public.avisos_severidad('reposicion_suplemento'), 'importante', 'reposicion_suplemento es importante');
select pruebas.igual(public.avisos_severidad('votacion_abierta'), 'informativa', 'votacion_abierta es informativa');
select pruebas.igual(public.avisos_severidad('votacion_empate'), 'informativa', 'votacion_empate es informativa');
select pruebas.igual(public.avisos_severidad('recordatorio_toma'), 'importante', 'Los tipos previos conservan su severidad (recordatorio_toma)');
select pruebas.igual(public.avisos_severidad('cambio_urgente_cuidados'), 'critica', 'y cambio_urgente_cuidados');
select pruebas.ok(not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'avisos'
                               and (column_name ~ 'monto|nombre|texto|titulo|mensaje|cuerpo|centavos|platillo')),
  'avisos no tiene columnas de monto, nombre ni texto libre (catálogo genérico, D20)');

-- ---------------------------------------------------------------- compra de Papá: al albacea
insert into public.ali_ingredientes (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos)
values ('a7100000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001', 'Leche Zeta', 'l', 'Lácteos', 2500);
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.ali_compras (id, hogar_id, cuenta, ingrediente_id, cantidad) values
  ('a7300000-0000-4000-8000-0000000000f1', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000000f1', 4),
  ('a7300000-0000-4000-8000-0000000000f2', 'b0000000-0000-4000-8000-000000000001', 'papa', 'a7100000-0000-4000-8000-0000000000f1', 2)$$), 2, 'Preparación: dos compras de Papá');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('compra_papa_albacea'), 0, 'Pedir la compra no avisa todavía');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000000f1', 1050)) ->> 'estado_pago', 'solicitud', 'La pareja marca la compra de Papá: queda la solicitud');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.n('ana@ejemplo.test', 'compra_papa_albacea'), 1, 'El albacea (Ana) recibe el aviso de la compra de Papá');
select pruebas.igual(pg_temp.total('compra_papa_albacea'), 1, 'y nadie más: ni la suplente mientras haya albacea');
select pruebas.igual(pg_temp.n('alex@ejemplo.test', 'compra_papa_albacea') + pg_temp.n('carla@ejemplo.test', 'compra_papa_albacea')
  + pg_temp.n('diana@ejemplo.test', 'compra_papa_albacea') + pg_temp.n('casa@ejemplo.test', 'compra_papa_albacea')
  + pg_temp.n('marta@ejemplo.test', 'compra_papa_albacea') + pg_temp.n('elena@ejemplo.test', 'compra_papa_albacea'), 0,
  'Ni la pareja, la familiar, la cuidadora, Casa, la maestra ni otro hogar');
select pruebas.ok((select a.severidad = 'importante' and a.modulo = 'alimentacion' and a.libro_id is null and a.objeto_tipo = 'solicitud_pago'
                          and a.objeto_id = (select s.id from public.ali_solicitudes_pago s) and a.clave = 'compra_papa:' || a.objeto_id::text
                     from public.avisos a where a.tipo = 'compra_papa_albacea'), 'Importante, módulo alimentacion, apunta a la solicitud, clave estable');
select pruebas.ok(not exists (select 1 from public.avisos a where a.tipo = 'compra_papa_albacea' and row_to_json(a)::text ~* 'leche|1050|10\.50'),
  'El aviso no lleva el producto ni el monto');
select pruebas.ok(not public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'alimentacion',
  'compra_papa_albacea', null, 'solicitud_pago', (select id from public.ali_solicitudes_pago),
  'compra_papa:' || (select id from public.ali_solicitudes_pago)::text, now()), 'Con la misma clave no se repite');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.avisos_insertar('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('ana@ejemplo.test'), 'alimentacion',
  'compra_papa_albacea', null, null, null, 'x:1', now())$$, 'La app no inserta avisos directo', '42501');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where tipo = 'compra_papa_albacea'$$), 1, 'El albacea lo lee en su bandeja');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where tipo = 'compra_papa_albacea'$$), 0, 'y la pareja no lo ve');
-- Al resolverse, el aviso se da por atendido.
select pruebas.como('ana@ejemplo.test');
select public.ali_resolver_solicitud_pago((select id from public.ali_solicitudes_pago), false, null, null, 'Compra repetida');
select pruebas.como_postgres();
select pruebas.igual((select estado from public.avisos where tipo = 'compra_papa_albacea'), 'resuelta', 'Rechazada o pagada, el aviso queda resuelto');
-- Sin albacea vigente, la suplente.
update public.fin_libro_miembros set hasta = now() where papel = 'albacea' and libro_id = 'f1000000-0000-4000-8000-000000000002';
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000000f2', 500)$$, 'La familiar no marca compras', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual((select public.ali_marcar_comprada('a7300000-0000-4000-8000-0000000000f2', 500)) ->> 'estado_pago', 'solicitud', 'Otra compra de Papá');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.n('alex@ejemplo.test', 'compra_papa_albacea'), 1, 'Sin albacea vigente avisa a la suplente');
select pruebas.igual(pg_temp.n('ana@ejemplo.test', 'compra_papa_albacea'), 1, 'y Ana no recibe uno más');

-- ---------------------------------------------------------------- votación abierta: a quienes votan
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Cena Zeta', array['a1000000-0000-4000-8000-000000000001']::uuid[]) is not null,
  'Carla propone un menú');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('votacion_abierta'), 2, 'Avisa a dos personas');
select pruebas.igual(pg_temp.n('ana@ejemplo.test', 'votacion_abierta') + pg_temp.n('alex@ejemplo.test', 'votacion_abierta'), 2, 'A la dueña y a la pareja, que votan');
select pruebas.igual(pg_temp.n('carla@ejemplo.test', 'votacion_abierta'), 0, 'No a quien la propuso');
select pruebas.igual(pg_temp.n('diana@ejemplo.test', 'votacion_abierta') + pg_temp.n('casa@ejemplo.test', 'votacion_abierta')
  + pg_temp.n('marta@ejemplo.test', 'votacion_abierta') + pg_temp.n('elena@ejemplo.test', 'votacion_abierta'), 0,
  'Ni la cuidadora, ni Casa, ni la maestra ni otro hogar');
select pruebas.ok((select bool_and(a.severidad = 'informativa' and a.modulo = 'alimentacion' and a.objeto_tipo = 'votacion' and a.libro_id is null
                                    and a.clave = 'votacion:' || a.objeto_id::text and a.objeto_id = (select id from public.ali_votaciones))
                     from public.avisos a where a.tipo = 'votacion_abierta'), 'Informativos, apuntan a la votación, clave estable');
select pruebas.ok(not exists (select 1 from public.avisos a where a.tipo = 'votacion_abierta' and row_to_json(a)::text ~* 'cena|zeta'),
  'No llevan el título del menú');
-- Más movimiento en la votación no repite el aviso.
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_proponer_alternativa((select id from public.ali_votaciones), 'Cena Beta', array['a1000000-0000-4000-8000-000000000002']::uuid[]) is not null, 'Alex da la alternativa');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena Zeta')), 'abierta', 'Alex vota A');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena Beta')), 'abierta', 'y cambia a B');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena Zeta')), 'abierta', 'Ana vota A: 1 a 1');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('votacion_abierta'), 2, 'Alternativa y votos no repiten el aviso');
select pruebas.igual(pg_temp.total('votacion_empate'), 0, 'y mientras esté abierta no hay aviso de empate');

-- ---------------------------------------------------------------- empate resuelto por volado: a quienes votan
update public.ali_votaciones set cierra_en = now() - interval '1 hour';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 1, 'El servidor cierra la votación empatada');
select pruebas.como_postgres();
select pruebas.ok((select ganadora_por_volado from public.ali_votaciones), 'Decidió el volado');
select pruebas.igual(pg_temp.total('votacion_empate'), 3, 'Avisa de que decidió el volado a tres personas');
select pruebas.igual(pg_temp.n('ana@ejemplo.test', 'votacion_empate') + pg_temp.n('alex@ejemplo.test', 'votacion_empate')
  + pg_temp.n('carla@ejemplo.test', 'votacion_empate'), 3, 'a la dueña, la pareja y la familiar (también a quien propuso)');
select pruebas.igual(pg_temp.n('diana@ejemplo.test', 'votacion_empate') + pg_temp.n('casa@ejemplo.test', 'votacion_empate')
  + pg_temp.n('marta@ejemplo.test', 'votacion_empate') + pg_temp.n('elena@ejemplo.test', 'votacion_empate'), 0,
  'y no a la cuidadora, Casa, la maestra ni otro hogar');
select pruebas.ok((select bool_and(a.severidad = 'informativa' and a.modulo = 'alimentacion' and a.objeto_tipo = 'votacion' and a.clave = 'empate:' || a.objeto_id::text)
                     from public.avisos a where a.tipo = 'votacion_empate'), 'Informativos, con clave estable');
select pruebas.ok(not exists (select 1 from public.avisos a where a.tipo = 'votacion_empate' and row_to_json(a)::text ~* 'cena|zeta|beta|volado'),
  'Sin título ni resultado en el aviso');
select pruebas.ok(not exists (select 1 from public.avisos where tipo = 'votacion_abierta' and estado in ('pendiente', 'agrupada', 'pospuesta')),
  'Cerrada la votación, el aviso de "abierta" que no salió se cancela');
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 0, 'Cerrar de nuevo no hace nada');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('votacion_empate'), 3, 'y el aviso de empate no se repite');
-- Sin empate: no hay aviso de empate.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Sola', array['a1000000-0000-4000-8000-000000000001']::uuid[]) is not null, 'Ana propone otra');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('votacion_abierta'), 4, 'Avisa a Alex y a Carla (no a Ana, que propuso)');
select pruebas.igual(pg_temp.n('ana@ejemplo.test', 'votacion_abierta'), 1, 'Ana conserva solo el de la anterior');
update public.ali_votaciones set cierra_en = now() - interval '1 hour' where titulo = 'Sola';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 1, 'Cierra la que tiene una sola propuesta');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('votacion_empate'), 3, 'Ganar sin volado no genera aviso de empate');

-- ---------------------------------------------------------------- reposición de suplemento: a quien compra
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_programar_toma('a3000000-0000-4000-8000-000000000001', now() - interval '3 hours') is not null, 'La dueña programa una toma');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('reposicion_suplemento'), 0, 'Programar la toma no avisa');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(public.ali_revisar_tomas('b0000000-0000-4000-8000-000000000001'), 1, 'Pasa el plazo sin confirmar');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('reposicion_suplemento'), 2, 'Se avisa de la reposición a dos personas');
select pruebas.igual(pg_temp.n('ana@ejemplo.test', 'reposicion_suplemento') + pg_temp.n('alex@ejemplo.test', 'reposicion_suplemento'), 2, 'A la dueña y a la pareja, que compran');
select pruebas.igual(pg_temp.n('carla@ejemplo.test', 'reposicion_suplemento') + pg_temp.n('diana@ejemplo.test', 'reposicion_suplemento')
  + pg_temp.n('casa@ejemplo.test', 'reposicion_suplemento') + pg_temp.n('marta@ejemplo.test', 'reposicion_suplemento')
  + pg_temp.n('elena@ejemplo.test', 'reposicion_suplemento'), 0, 'No a la familiar, la cuidadora, Casa, la maestra ni otro hogar');
select pruebas.ok((select bool_and(a.severidad = 'importante' and a.modulo = 'alimentacion' and a.objeto_tipo = 'reposicion' and a.libro_id is null
                                    and a.clave = 'reposicion:' || a.objeto_id::text and a.objeto_id = (select id from public.ali_reposiciones_suplemento))
                     from public.avisos a where a.tipo = 'reposicion_suplemento'), 'Importantes, apuntan a la reposición, clave estable');
select pruebas.ok(not exists (select 1 from public.avisos a where a.tipo = 'reposicion_suplemento' and row_to_json(a)::text ~* 'suplemento de ejemplo|dosis'),
  'Sin nombre ni dosis del suplemento (dato clínico, D3)');
-- No se repite: otra toma sin confirmar del mismo suplemento no abre otra reposición ni otro aviso.
insert into public.ali_tomas_suplemento (hogar_id, suplemento_id, nombre, prevista_en)
values ('b0000000-0000-4000-8000-000000000001', 'a3000000-0000-4000-8000-000000000001', 'x', now() - interval '5 hours');
select pruebas.como_servicio();
select pruebas.igual(public.ali_revisar_tomas(), 1, 'El servidor revisa otra toma sin confirmar');
select pruebas.como_postgres();
select pruebas.igual(pg_temp.total('reposicion_suplemento'), 2, 'La reposición pendiente ya existía: no hay aviso nuevo');
select pruebas.como('alex@ejemplo.test');
select public.ali_resolver_reposicion((select id from public.ali_reposiciones_suplemento), true);
select pruebas.como_postgres();
select pruebas.ok((select bool_and(estado = 'resuelta') from public.avisos where tipo = 'reposicion_suplemento'), 'Atendida la reposición, los avisos quedan resueltos');

-- ---------------------------------------------------------------- quien nunca recibe nada de Alimentación
select pruebas.igual((select count(*)::int from public.avisos a where a.modulo = 'alimentacion'
                       and a.persona_id in (pruebas.id_persona('diana@ejemplo.test'), pruebas.id_persona('casa@ejemplo.test'),
                                            pruebas.id_persona('marta@ejemplo.test'), pruebas.id_persona('elena@ejemplo.test'))), 0,
  'La cuidadora, Casa, la cuenta maestra y otro hogar no reciben ningún aviso de Alimentación');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where modulo = 'alimentacion'$$), 0, 'La maestra no ve ninguno');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where modulo = 'alimentacion'$$), 0, 'Casa tampoco');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where modulo = 'alimentacion'$$), 0, 'ni la cuidadora');
select pruebas.como_postgres();
-- Ningún aviso lleva cifras en lo que dice (tipo, módulo, tipo de objeto): el catálogo es cerrado.
select pruebas.ok(not exists (select 1 from public.avisos a where a.modulo = 'alimentacion' and (a.tipo || a.modulo || a.objeto_tipo) ~ '[0-9]'),
  'Tipo, módulo y objeto de los avisos de Alimentación no llevan cifras');
rollback;
