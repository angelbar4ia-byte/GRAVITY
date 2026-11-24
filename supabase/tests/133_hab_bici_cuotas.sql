-- Bicicleta (Fase 8, B2, CA-B-21): cuota de filas por persona en las cinco tablas (H-10): salidas 1 500,
-- mantenimientos 2 000, bicicletas 20, listas de música 100, perfil 1. Al pasarla, 54000. Una tabla sin tope falla.
begin;

-- ---------------------------------------------------------------- bicicletas: 20
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en)
  select gen_random_uuid(), 'b' || g, now() from generate_series(1, 21) g$$,
  '21 bicicletas en una sola sentencia superan el tope de 20 (54000)', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en)
  select ('f8500000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'b' || g, now() from generate_series(1, 20) g$$), 20, 'Hasta el tope de 20 sí entran');
select pruebas.falla($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values (gen_random_uuid(), 'una más', now())$$,
  'La siguiente se rechaza', '54000');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values ('f8500000-0000-4000-8000-0000000000a1', 'mía', now())$$), 1,
  'El tope es por persona: Alex no se ve afectado');

-- ---------------------------------------------------------------- listas de música: 100
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  select gen_random_uuid(), 'l' || g, 'bicicleta', 'otra', 'https://musica.ejemplo.test/' || g, 1 + g % 20, now() from generate_series(1, 101) g$$,
  '101 listas superan el tope de 100 (54000)', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  select gen_random_uuid(), 'l' || g, 'bicicleta', 'otra', 'https://musica.ejemplo.test/' || g, 1 + g % 20, now() from generate_series(1, 100) g$$), 100,
  'Hasta 100 sí entran');
select pruebas.falla($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'una más', 'fuerza', 'otra', 'https://musica.ejemplo.test/mas', 1, now())$$, 'La siguiente se rechaza', '54000');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_musica_listas (id, nombre, actividad, app, enlace, orden, modificado_en)
  values (gen_random_uuid(), 'mía', 'fuerza', 'otra', 'https://musica.ejemplo.test/mia', 1, now())$$), 1, 'Alex sigue guardando las suyas');

-- ---------------------------------------------------------------- salidas: 1 500 (se siembran como postgres: es solo volumen)
select pruebas.como_postgres();
insert into public.hab_bici_salidas (id, persona_id, hogar_id, fecha, n, estado, modificado_en)
select gen_random_uuid(), pruebas.id_persona('ana@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001', date '2020-01-01' + g, 1, 'hecha', now()
from generate_series(1, 1500) g;
select pruebas.igual((select count(*)::int from public.hab_bici_salidas where persona_id = pruebas.id_persona('ana@ejemplo.test')), 1500, 'Ana llega a 1 500 salidas');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values (gen_random_uuid(), '2026-12-01', 1, 'hecha', now())$$, 'La salida 1 501 se rechaza (54000)', '54000');
do $$
declare
  v_mensaje text;
begin
  begin
    insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en) values (gen_random_uuid(), '2026-12-02', 1, 'hecha', now());
  exception when others then
    get stacked diagnostics v_mensaje = message_text;
  end;
  perform pruebas.ok(v_mensaje like 'Se llegó al tope de 1500 filas en hab_bici_salidas%', '… con el mensaje y el tope de la tabla (CA-B-21)');
end
$$;
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  values ('f8700000-0000-5000-8000-0000000000e1', '2026-12-01', 1, 'hecha', now())$$), 1, 'El tope es por persona: Alex registra su salida');
-- Actualizar o borrar no choca con el tope: solo cuentan las filas nuevas.
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_salidas set esfuerzo = 3 where fecha = '2020-01-02'$$), 1, 'Cambiar una salida con la cuota llena sí se puede');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_salidas where fecha between '2020-01-02' and '2020-01-04'$$), 3, 'Borrar libera espacio…');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_salidas (id, fecha, n, estado, modificado_en)
  select gen_random_uuid(), '2026-12-01', n, 'hecha', now() from generate_series(1, 3) n$$), 3, '… y se puede registrar otra vez');

-- ---------------------------------------------------------------- mantenimientos: 2 000
select pruebas.como('carla@ejemplo.test');
insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values ('f8500000-0000-4000-8000-0000000000c1', 'Mi bici (ejemplo)', now());
select pruebas.como_postgres();
insert into public.hab_bici_mantenimientos (id, persona_id, hogar_id, bicicleta_id, tarea, fecha, modificado_en)
select gen_random_uuid(), pruebas.id_persona('carla@ejemplo.test'), 'b0000000-0000-4000-8000-000000000001',
       'f8500000-0000-4000-8000-0000000000c1', 'otra', date '2015-01-01' + g, now()
from generate_series(1, 2000) g;
select pruebas.igual((select count(*)::int from public.hab_bici_mantenimientos where persona_id = pruebas.id_persona('carla@ejemplo.test')), 2000,
  'Carla llega a 2 000 mantenimientos (el tope exacto entra)');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values (gen_random_uuid(), 'f8500000-0000-4000-8000-0000000000c1', 'lubricar_cadena', '2026-12-01', now())$$,
  'El mantenimiento 2 001 se rechaza con 54000', '54000');
select pruebas.falla($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  select gen_random_uuid(), 'f8500000-0000-4000-8000-0000000000c1', 'lubricar_cadena', date '2026-12-01' + g, now() from generate_series(1, 5) g$$,
  '… también cinco en una sola sentencia', '54000');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_bicicletas (id, nombre, modificado_en) values ('f8500000-0000-4000-8000-0000000000a2', 'mía', now())$$), 1,
  'Alex tiene su bicicleta (el tope es por persona)');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  values ('f8600000-0000-5000-8000-0000000000e1', 'f8500000-0000-4000-8000-0000000000a2', 'lubricar_cadena', '2026-12-01', now())$$), 1,
  'y registra su mantenimiento');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.hab_bici_mantenimientos set nota = 'x' where fecha = '2015-01-02'$$), 1, 'Cambiar uno con la cuota llena sí se puede');
select pruebas.igual(pruebas.afecta($$delete from public.hab_bici_mantenimientos where fecha between '2015-01-02' and '2015-01-04'$$), 3, 'Borrar libera espacio…');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_mantenimientos (id, bicicleta_id, tarea, fecha, modificado_en)
  select gen_random_uuid(), 'f8500000-0000-4000-8000-0000000000c1', 'lubricar_cadena', date '2026-12-01' + g, now() from generate_series(1, 3) g$$), 3,
  '… y se puede registrar otra vez');

-- ---------------------------------------------------------------- perfil: el tope es estructural (1 por persona)
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_bici_perfil (modificado_en) values (now())$$), 1, 'Un perfil por persona');
select pruebas.falla($$insert into public.hab_bici_perfil (modificado_en) values (now())$$, 'No hay un segundo (llave primaria)', '23505');

-- ---------------------------------------------------------------- guardias (H-10): una tabla sin tope falla
select pruebas.como_postgres();
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and (c.relname like 'hab\_bici\_%' or c.relname like 'hab\_musica\_%')
      and not exists (select 1 from pg_trigger g where g.tgrelid = c.oid and not g.tgisinternal and g.tgname = 'hab_z_cuota'
                        and g.tgfoid = 'public.hab_cuota_filas()'::regprocedure)),
  '', 'Toda tabla hab_bici_* y hab_musica_* tiene el trigger de cuota (hab_z_cuota)');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and (c.relname like 'hab\_bici\_%' or c.relname like 'hab\_musica\_%')
      and position('when ''' || c.relname || ''' then' in pg_get_functiondef('public.hab_cuota_filas()'::regprocedure)) = 0),
  '', '… y su tope está en hab_cuota_filas');
select pruebas.igual(
  (select coalesce(string_agg(c.relname, ', ' order by c.relname), '')
     from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relname like 'hab\_ent\_%'
      and position('when ''' || c.relname || ''' then' in pg_get_functiondef('public.hab_cuota_filas()'::regprocedure)) = 0),
  '', 'Los topes anteriores del gimnasio siguen en la función');
-- Caso malo: una tabla con el trigger pero sin tope en la función no limita en silencio: falla cerrado (55000).
create table public.hab_bici_prueba_sin_tope (persona_id uuid not null, valor integer);
create trigger hab_z_cuota after insert on public.hab_bici_prueba_sin_tope referencing new table as nuevas
  for each statement execute function public.hab_cuota_filas();
select pruebas.falla($$insert into public.hab_bici_prueba_sin_tope (persona_id, valor) values (gen_random_uuid(), 1)$$,
  'Una tabla sin tope en hab_cuota_filas rechaza la escritura en lugar de no limitar nada', '55000');

rollback;
