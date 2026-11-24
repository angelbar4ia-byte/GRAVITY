-- G6-M1 (hallazgo) · Las llaves primarias de hab_ent_sesiones, hab_ent_series y hab_ent_bandas son GLOBALES (solo `id`),
-- así que una persona del mismo hogar puede saber si otra tiene una sesión o una serie probando su id.
--
-- Los ids de sesión y de serie son UUID v5 de datos que no son secretos (persona + fecha + plantilla; el espacio de
-- nombres está en app/lib/nucleo/gimnasio/ids_gimnasio.dart), así que se pueden calcular. Insertar una fila con ese id da
-- 23505 «duplicate key» si la otra persona ya la tiene y funciona si no: un bit por intento sobre «¿entrenó Ana el día D?».
--
-- CÓMO CORRERLO: es una prueba del estilo de supabase/tests (usa los ayudantes `pruebas.*`). Cópiala como
-- supabase/tests/NNN_hab_ent_sin_sonda.sql (el siguiente número libre) y corre `bash supabase/tests/correr.sh NNN_*.sql`.
-- HOY FALLA (por eso es un hallazgo); pasa cuando las llaves sean (persona_id, id):
--   alter table public.hab_ent_sesiones drop constraint hab_ent_sesiones_pkey, add primary key (persona_id, id);
--   (igual en hab_ent_series y hab_ent_bandas; los upserts de la cola usan on_conflict=persona_id,id)
begin;

create function pruebas.sembrar_sonda() returns void language plpgsql as $$
begin
  insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan,
                                       catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-11-30', 'A', 'estandar', 'carga', 'noche',
          '2026-11-30 20:00-06', '2026-11-30 20:45-06', 'completa', '[]', 1, now());
end $$;
grant execute on function pruebas.sembrar_sonda() to authenticated;

select pruebas.como('ana@ejemplo.test');
select pruebas.sembrar_sonda();

-- Alex (pareja, coadministrador) prueba el id de la sesión de Ana con una fila suya.
select pruebas.como('alex@ejemplo.test');
do $$
begin
  insert into public.hab_ent_sesiones (id, fecha, plantilla, version, semana_tipo, ventana, inicio, fin, estado, plan,
                                       catalogo_version, modificado_en)
  values ('f8100000-0000-5000-8000-0000000000e1', '2026-12-07', 'B', 'estandar', 'carga', 'noche',
          '2026-12-07 20:00-06', '2026-12-07 20:45-06', 'completa', '[]', 1, now());
  raise notice 'ok - Alex puede usar ese id: la llave es por persona y no revela nada de Ana';
exception when unique_violation then
  raise exception 'HALLAZGO G6-M1: el id de la sesión de Ana ya existe (23505) y Alex lo ve: sondeo posible entre personas del hogar';
end $$;

rollback;
