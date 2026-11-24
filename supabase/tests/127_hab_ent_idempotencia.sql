-- Entrenamiento (Fase 8, G2, CA-G-31): idempotencia. La misma sesión o serie con el mismo id (v5) no duplica; con
-- el mismo id y otro contenido gana el de modificado_en más reciente, llegue en el orden que llegue (dos equipos).
begin;

-- Subidas como las hace la cola: upsert por (persona_id, id) (o por la llave natural en perfil, plan e inventario).
-- La app no manda persona_id: lo pone el trigger hab_a_propio antes de buscar el conflicto (G6-M1).
create function pruebas.up_sesion(p_id uuid, p_esfuerzo integer, p_mod timestamptz, p_fecha date default '2026-11-23') returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, esfuerzo, plan, catalogo_version, modificado_en)
  values (p_id, p_fecha, 'A', 'estandar', 'carga', 'noche', '2026-11-23 20:00-06', '2026-11-23 20:45-06', 'completa', p_esfuerzo,
          '[{"ejercicio": "marcy.press", "series": 3, "reps_min": 8, "reps_max": 12}]', 1, p_mod)
  on conflict (persona_id, id) do update set fecha = excluded.fecha, plantilla = excluded.plantilla, version = excluded.version,
    semana_tipo = excluded.semana_tipo, ventana = excluded.ventana, inicio = excluded.inicio, fin = excluded.fin,
    estado = excluded.estado, esfuerzo = excluded.esfuerzo, plan = excluded.plan, catalogo_version = excluded.catalogo_version,
    modificado_en = excluded.modificado_en;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
create function pruebas.up_serie(p_id uuid, p_sesion uuid, p_reps integer, p_mod timestamptz, p_n integer default 1) returns integer
language plpgsql
as $$
declare
  v_n integer;
begin
  insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, carga_pasos, esfuerzo, modificado_en)
  values (p_id, p_sesion, 'marcy.press', 'press_sentado', p_n, p_reps, 4, 3, p_mod)
  on conflict (persona_id, id) do update set sesion_id = excluded.sesion_id, ejercicio_id = excluded.ejercicio_id, variante_id = excluded.variante_id,
    n = excluded.n, reps = excluded.reps, carga_pasos = excluded.carga_pasos, esfuerzo = excluded.esfuerzo, modificado_en = excluded.modificado_en;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
grant execute on function pruebas.up_sesion(uuid, integer, timestamptz, date), pruebas.up_serie(uuid, uuid, integer, timestamptz, integer) to authenticated;

select pruebas.como('ana@ejemplo.test');

-- ---------------------------------------------------------------- sesión: el mismo id no duplica
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 3, now() - interval '60 minutes'), 1, 'Se sube la sesión');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 3, now() - interval '60 minutes'), 1, 'Subirla otra vez (reintento) no falla…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones$$), 1, '… ni duplica: una sola sesión');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-000000000001', '2026-11-23', 'A', 'estandar', 'carga', 'noche', '2026-11-23 20:00-06', '2026-11-23 20:45-06', 'completa', 1, now())
  on conflict do nothing$$), 0, 'Con ON CONFLICT DO NOTHING tampoco: 0 filas, sin error');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-000000000001', '2026-11-23', 'A', 'estandar', 'carga', 'noche', '2026-11-23 20:00-06', '2026-11-23 20:45-06', 'completa', 1, now())$$,
  'Un INSERT simple con el mismo id no duplica: 23505', '23505');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000aa', '2026-11-23', 'A', 'estandar', 'carga', 'noche', '2026-11-23 20:00-06', '2026-11-23 20:45-06', 'completa', 1, now())$$,
  'Otro id para el mismo día y plantilla tampoco duplica (23505): el id es v5 de persona, fecha y plantilla', '23505');
select pruebas.falla($$select pruebas.up_sesion('f8100000-0000-5000-8000-0000000000aa', 2, now())$$, '… ni con upsert por id', '23505');

-- ---------------------------------------------------------------- sesión: gana el modificado_en más reciente
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 5, now() - interval '50 minutes'), 1, 'Otro contenido con modificado_en más nuevo: gana');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones), 5::smallint, '… y queda el nuevo');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 1, now() - interval '70 minutes'), 0, 'Otro contenido con modificado_en más viejo: se ignora (0 filas, sin error)');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones), 5::smallint, '… y se queda el más reciente');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones$$), 1, 'Sigue siendo una sola sesión');
-- Dos equipos, el mismo id, llegan en orden inverso: el resultado es el mismo.
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000002', 4, now() - interval '50 minutes', '2026-11-24'), 1, 'Equipo B sube primero (esfuerzo 4, hace 50 min)');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000002', 2, now() - interval '55 minutes', '2026-11-24'), 0, '… y después llega el equipo A (esfuerzo 2, hace 55 min): se ignora');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000002'), 4::smallint, 'Gana el más reciente (el del equipo B)');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000003', 2, now() - interval '55 minutes', '2026-11-25'), 1, 'En el otro orden: A sube primero (hace 55 min)…');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000003', 4, now() - interval '50 minutes', '2026-11-25'), 1, '… y B después (hace 50 min): reemplaza');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000003'), 4::smallint, 'Mismo resultado: gana el más reciente');
-- Del futuro lejano: entra, ajustado.
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 2, now() + interval '3 days'), 1, 'Un modificado_en del futuro lejano entra…');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'),
  '… ajustado a la hora del servidor (no deja la fila «congelada» en el futuro)');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 3, now() + interval '1 minute'), 1, '… y un cambio posterior legítimo todavía gana');

-- ---------------------------------------------------------------- serie
select pruebas.igual(pruebas.up_serie('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 10, now() - interval '60 minutes'), 1, 'Se sube la serie');
select pruebas.igual(pruebas.up_serie('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 10, now() - interval '60 minutes'), 1, 'El reintento no falla…');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_series$$), 1, '… ni duplica');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, modificado_en)
  values ('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 'marcy.press', 'press_sentado', 1, 10, now())$$,
  'Un INSERT simple con el mismo id da 23505', '23505');
select pruebas.falla($$select pruebas.up_serie('f8300000-0000-5000-8000-0000000000bb', 'f8100000-0000-5000-8000-000000000001', 10, now())$$,
  'La misma serie (sesión, ejercicio, número, lado) con otro id no duplica (23505)', '23505');
select pruebas.igual(pruebas.up_serie('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 12, now() - interval '55 minutes'), 1, 'Más nueva gana (12 repeticiones)');
select pruebas.igual(pruebas.up_serie('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 8, now() - interval '65 minutes'), 0, 'Más vieja se ignora');
select pruebas.igual((select reps from public.hab_ent_series), 12::smallint, '… queda la más reciente');
select pruebas.igual(pruebas.up_serie('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 9, now() + interval '30 days'), 1,
  'Futuro lejano: entra');
select pruebas.ok((select modificado_en <= now() + interval '5 minutes' from public.hab_ent_series), '… ajustado');

-- ---------------------------------------------------------------- las otras cuatro tablas: upsert por su llave natural
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_perfil (dias_plan, modificado_en) values (4, now() - interval '60 minutes')
  on conflict (persona_id) do update set dias_plan = excluded.dias_plan, modificado_en = excluded.modificado_en$$), 1, 'Perfil: se crea con upsert por persona');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_perfil (dias_plan, modificado_en) values (5, now() - interval '50 minutes')
  on conflict (persona_id) do update set dias_plan = excluded.dias_plan, modificado_en = excluded.modificado_en$$), 1, '… y el más nuevo gana');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_perfil (dias_plan, modificado_en) values (3, now() - interval '120 minutes')
  on conflict (persona_id) do update set dias_plan = excluded.dias_plan, modificado_en = excluded.modificado_en$$), 0, '… el más viejo se ignora');
select pruebas.igual((select dias_plan from public.hab_ent_perfil), 5::smallint, '… y es una sola fila');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (2, 'B', now() - interval '60 minutes')
  on conflict (persona_id, dia_semana) do update set tipo = excluded.tipo, modificado_en = excluded.modificado_en$$), 1, 'Plan: se crea el día 2');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (2, 'C', now() - interval '120 minutes')
  on conflict (persona_id, dia_semana) do update set tipo = excluded.tipo, modificado_en = excluded.modificado_en$$), 0, '… el más viejo se ignora');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (2, 'C', now() - interval '10 minutes')
  on conflict (persona_id, dia_semana) do update set tipo = excluded.tipo, modificado_en = excluded.modificado_en$$), 1, '… el más nuevo gana');
select pruebas.igual((select tipo from public.hab_ent_plan_dias where dia_semana = 2), 'C', 'queda C');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('marcy.press', 'disponible', now() - interval '60 minutes')
  on conflict (persona_id, item_id) do update set estado = excluded.estado, modificado_en = excluded.modificado_en$$), 1, 'Inventario: se crea');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('marcy.press', 'no_disponible', now() - interval '30 minutes')
  on conflict (persona_id, item_id) do update set estado = excluded.estado, modificado_en = excluded.modificado_en$$), 1, '… el más nuevo gana');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('marcy.press', 'disponible', now() - interval '45 minutes')
  on conflict (persona_id, item_id) do update set estado = excluded.estado, modificado_en = excluded.modificado_en$$), 0, '… el más viejo se ignora');
select pruebas.igual((select estado || '/' || count(*) over () from public.hab_ent_inventario), 'no_disponible/1', 'queda no_disponible, una sola fila');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values ('f8200000-0000-4000-8000-000000000001', 'Verde', 1, 1, now() - interval '60 minutes')
  on conflict (persona_id, id) do update set nombre = excluded.nombre, orden = excluded.orden, cantidad = excluded.cantidad, modificado_en = excluded.modificado_en$$), 1,
  'Bandas: se crea');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values ('f8200000-0000-4000-8000-000000000001', 'Vieja', 1, 5, now() - interval '120 minutes')
  on conflict (persona_id, id) do update set nombre = excluded.nombre, orden = excluded.orden, cantidad = excluded.cantidad, modificado_en = excluded.modificado_en$$), 0, '… la más vieja se ignora');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values ('f8200000-0000-4000-8000-000000000001', 'Nueva', 2, 2, now() - interval '10 minutes')
  on conflict (persona_id, id) do update set nombre = excluded.nombre, orden = excluded.orden, cantidad = excluded.cantidad, modificado_en = excluded.modificado_en$$), 1, '… la más nueva gana');
select pruebas.igual((select nombre || '/' || count(*) over () from public.hab_ent_bandas), 'Nueva/1', 'queda «Nueva», una sola banda');

-- ---------------------------------------------------------------- el mismo id en otra persona es otra fila (G6-M1)
-- La llave es (persona_id, id): el id v5 se puede calcular, así que no puede revelar ni pisar nada de otra persona.
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones$$) + pruebas.cuenta($$select * from public.hab_ent_series$$), 0,
  'Alex no ve nada de lo de Ana');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 1, now() - interval '5 minutes'), 1,
  'Alex sube una sesión con el MISMO id que la de Ana: no choca (23505) ni da 42501: crea la suya');
select pruebas.igual(pruebas.up_sesion('f8100000-0000-5000-8000-000000000001', 1, now() - interval '5 minutes'), 1,
  '… y su reintento sigue siendo idempotente');
select pruebas.igual(pruebas.cuenta($$select * from public.hab_ent_sesiones$$), 1, 'Alex ve una sola sesión: la suya');
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones), 1::smallint, '… con su propio contenido');
select pruebas.igual(pruebas.up_serie('f8300000-0000-5000-8000-000000000001', 'f8100000-0000-5000-8000-000000000001', 1, now() - interval '5 minutes'), 1,
  'Con el mismo id de serie y de sesión que Ana, Alex crea su propia serie (de su propia sesión)');
select pruebas.falla($$select pruebas.up_serie('f8300000-0000-5000-8000-000000000002', 'f8100000-0000-5000-8000-0000000000bb', 1, now(), 2)$$,
  'Una serie de Alex no cuelga de una sesión que no es suya: 23503', '23503');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values ('f8200000-0000-4000-8000-000000000001', 'De Alex', 1, 1, now())
  on conflict (persona_id, id) do nothing$$), 1, 'Una banda con el mismo id que la de Ana: Alex crea la suya');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values ('f8200000-0000-4000-8000-000000000001', 'Otra de Alex', 1, 1, now())
  on conflict (persona_id, id) do nothing$$), 0, '… y repetirla no cambia nada');
select pruebas.como_postgres();
select pruebas.igual((select esfuerzo from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  3::smallint, 'La sesión de Ana quedó como ella la dejó');
select pruebas.igual((select reps from public.hab_ent_series where id = 'f8300000-0000-5000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  9::smallint, '… y su serie');
select pruebas.igual((select nombre from public.hab_ent_bandas where id = 'f8200000-0000-4000-8000-000000000001' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  'Nueva', '… y su banda');
select pruebas.igual((select count(*)::int from public.hab_ent_sesiones where id = 'f8100000-0000-5000-8000-000000000001'), 2,
  'Hay dos filas con ese id: una de cada persona');
select pruebas.igual((select pg_get_constraintdef(k.oid) from pg_constraint k where k.conrelid = 'public.hab_ent_sesiones'::regclass and k.contype = 'p'),
  'PRIMARY KEY (persona_id, id)', 'La llave primaria de las sesiones es (persona_id, id)');

rollback;
