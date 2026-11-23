-- Entrenamiento (Fase 8, G2, CA-G-30): cuota de filas por persona en las seis tablas hab_ent_* (H-10):
-- sesiones 3 000, series 60 000, inventario 200, bandas 50, plan 7, perfil 1. Al pasarla, 54000. Una tabla sin tope falla.
begin;

-- ---------------------------------------------------------------- bandas: 50
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en)
  select gen_random_uuid(), 'b' || g, 1 + g % 20, 1, now() from generate_series(1, 51) g$$,
  '51 bandas en una sola sentencia superan el tope de 50 (54000)', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en)
  select gen_random_uuid(), 'b' || g, 1 + g % 20, 1, now() from generate_series(1, 50) g$$), 50, 'Hasta el tope de 50 sí entran');
select pruebas.falla($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'una más', 1, 1, now())$$,
  'La siguiente se rechaza', '54000');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_bandas (id, nombre, orden, cantidad, modificado_en) values (gen_random_uuid(), 'mía', 1, 1, now())$$), 1,
  'El tope es por persona: Alex no se ve afectado');

-- ---------------------------------------------------------------- inventario: 200
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, modificado_en)
  select 'otro:p' || g, 'disponible', now() from generate_series(1, 201) g$$, '201 puestos superan el tope de 200', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_inventario (item_id, estado, modificado_en)
  select 'otro:p' || g, 'disponible', now() from generate_series(1, 200) g$$), 200, 'Hasta 200 sí entran');
select pruebas.falla($$insert into public.hab_ent_inventario (item_id, estado, modificado_en) values ('colchoneta', 'disponible', now())$$,
  'El siguiente se rechaza', '54000');

-- ---------------------------------------------------------------- sesiones: 3 000 (se siembran como postgres: es solo volumen)
select pruebas.como_postgres();
insert into public.hab_ent_sesiones (id, persona_id, hogar_id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
select gen_random_uuid(), pruebas.id_persona('ana@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001', date '2020-01-01' + g, 'A', 'corta', 'carga', 'noche',
       '2026-11-02 20:00-06', '2026-11-02 20:30-06', 'completa', 1, now()
from generate_series(1, 3000) g;
select pruebas.igual((select count(*)::int from public.hab_ent_sesiones where persona_id = pruebas.id_persona('ana@ejemplo.test')), 3000, 'Ana llega a 3 000 sesiones');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values (gen_random_uuid(), '2026-12-01', 'B', 'corta', 'carga', 'noche', '2026-12-01 20:00-06', '2026-12-01 20:30-06', 'completa', 1, now())$$,
  'La sesión 3 001 se rechaza (54000)', '54000');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-12-01', 'B', 'corta', 'carga', 'noche', '2026-12-01 20:00-06', '2026-12-01 20:30-06', 'completa', 1, now())$$), 1,
  'Alex sigue registrando');

-- ---------------------------------------------------------------- series: 60 000
select pruebas.como_postgres();
insert into public.hab_ent_sesiones (id, persona_id, hogar_id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e2', pruebas.id_persona('carla@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001',
          '2026-11-02', 'A', 'estandar', 'carga', 'noche', '2026-11-02 20:00-06', '2026-11-02 20:45-06', 'completa', 1, now());
-- 5 000 ejercicios x 12 números = 60 000 series de una sola sesión.
insert into public.hab_ent_series (id, persona_id, hogar_id, sesion_id, ejercicio_id, variante_id, n, reps, modificado_en)
select gen_random_uuid(), pruebas.id_persona('carla@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001',
       'f8100000-0000-5000-8000-0000000000e2', 'ej' || e, 'v', n, 10, now()
from generate_series(1, 5000) e, generate_series(1, 12) n;
select pruebas.igual((select count(*)::int from public.hab_ent_series where persona_id = pruebas.id_persona('carla@ejemplo.test')), 60000,
  'Carla llega a 60 000 series (el tope exacto entra)');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, modificado_en)
  values (gen_random_uuid(), 'f8100000-0000-5000-8000-0000000000e2', 'ej_nuevo', 'v', 1, 10, now())$$,
  'La serie 60 001 se rechaza con 54000 (CA-G-30)', '54000');
do $$
declare
  v_mensaje text;
begin
  begin
    insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, modificado_en)
    values (gen_random_uuid(), 'f8100000-0000-5000-8000-0000000000e2', 'ej_nuevo2', 'v', 1, 10, now());
  exception when others then
    get stacked diagnostics v_mensaje = message_text;
  end;
  perform pruebas.ok(v_mensaje like 'Se llegó al tope de 60000 filas en hab_ent_series%', '… con el mensaje y el tope de la tabla');
end
$$;
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, modificado_en)
  values (gen_random_uuid(), 'f8100000-0000-5000-8000-0000000000e1', 'ej1', 'v', 1, 10, now())$$), 1, 'El tope es por persona: Alex registra su serie');
-- Actualizar o borrar no choca con el tope: solo cuentan las filas nuevas.
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.hab_ent_series set reps = 11 where ejercicio_id = 'ej1' and n = 1$$), 1, 'Cambiar una serie con la cuota llena sí se puede');
select pruebas.igual(pruebas.afecta($$delete from public.hab_ent_series where ejercicio_id = 'ej2'$$), 12, 'Borrar libera espacio…');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_series (id, sesion_id, ejercicio_id, variante_id, n, reps, modificado_en)
  select gen_random_uuid(), 'f8100000-0000-5000-8000-0000000000e2', 'ej_nuevo', 'v', n, 10, now() from generate_series(1, 12) n$$), 12, '… y se puede registrar otra vez');

-- ---------------------------------------------------------------- plan y perfil: el tope es estructural (7 días, 1 perfil)
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_perfil (modificado_en) values (now())$$), 1, 'Un perfil por persona');
select pruebas.falla($$insert into public.hab_ent_perfil (modificado_en) values (now())$$, 'No hay un segundo (llave primaria)', '23505');
select pruebas.igual(pruebas.afecta($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en)
  select g, 'A', now() from generate_series(1, 7) g$$), 7, 'Siete días de plan');
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (8, 'A', now())$$, 'No hay un octavo día', '23514');
select pruebas.falla($$insert into public.hab_ent_plan_dias (dia_semana, tipo, modificado_en) values (1, 'A', now())$$, 'ni un primero repetido', '23505');

-- ---------------------------------------------------------------- guardias (H-10): una tabla sin tope falla
select pruebas.como_postgres();
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_ent\_%'
      and not exists (select 1 from pg_trigger g where g.tgrelid = c.oid and not g.tgisinternal and g.tgname = 'hab_z_cuota'
                        and g.tgfoid = 'public.hab_cuota_filas()'::regprocedure)),
  '', 'Toda tabla hab_ent_* tiene el trigger de cuota (hab_z_cuota)');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_ent\_%'
      and position('when ''' || c.relname || ''' then' in pg_get_functiondef('public.hab_cuota_filas()'::regprocedure)) = 0),
  '', '… y su tope está en hab_cuota_filas');
-- Caso malo: una tabla con el trigger pero sin tope en la función no limita en silencio: falla cerrado (55000).
create table public.hab_ent_prueba_sin_tope (persona_id uuid not null, valor integer);
create trigger hab_z_cuota after insert on public.hab_ent_prueba_sin_tope referencing new table as nuevas
  for each statement execute function public.hab_cuota_filas();
select pruebas.falla($$insert into public.hab_ent_prueba_sin_tope (persona_id, valor) values (gen_random_uuid(), 1)$$,
  'Una tabla sin tope en hab_cuota_filas rechaza la escritura en lugar de no limitar nada', '55000');

rollback;
