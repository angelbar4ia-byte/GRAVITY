-- =============================================================================
-- GRAVITY · Fase 8 · Hábitos · Llaves primarias por persona (hallazgo G6-M1 de la revisión de calidad del gimnasio)
-- =============================================================================
-- docs/revisiones/fase-8-gimnasio.md, G6-M1. Corrige 20261152000000_habitos_gimnasio.sql y
-- 20261153000000_habitos_bicicleta.sql SIN editarlas (migraciones solo hacia adelante).
--
-- El problema. Las tablas por persona de gimnasio y bicicleta declaraban `id uuid primary key`: la llave era GLOBAL.
-- Los ids de sesión, serie, mantenimiento y salida son UUID v5 de datos que no son secretos (persona, fecha,
-- plantilla… y un espacio de nombres que está en la app). Cualquier persona del hogar podía calcular el id de otra y
-- probarlo con un INSERT: 23505 «duplicate key» si la otra persona tiene esa fila, y entra si no. Un bit por intento
-- sobre «¿entrenó Ana el día D?» o «¿salió Ana en bici el día D?».
--
-- La corrección. La llave primaria pasa a ser (persona_id, id) en las siete tablas con `id`:
--   gimnasio:  hab_ent_bandas, hab_ent_sesiones, hab_ent_series
--   bicicleta: hab_bici_bicicletas, hab_bici_mantenimientos, hab_bici_salidas, hab_musica_listas
-- Así el mismo id en dos personas son dos filas distintas y nadie puede sondear lo ajeno. Las seis ya tenían además
-- `unique (persona_id, id)` (lo usaban las llaves foráneas compuestas); ahora esa llave ES la primaria y la
-- restricción única redundante se retira. Las llaves foráneas que dependían de ella se recrean con el mismo nombre,
-- las mismas columnas y el mismo ON DELETE. Los índices únicos naturales (día + plantilla, serie, mantenimiento,
-- salida del día) no se tocan.
--
-- Efecto para quien sube (la cola de la app): el upsert ya no se resuelve por `id`, sino por `persona_id,id`
-- (`ON CONFLICT (persona_id, id)`; en PostgREST `on_conflict=persona_id,id`). La app NO manda `persona_id`: el trigger
-- hab_a_propio (BEFORE INSERT) lo pone antes de que Postgres busque el conflicto, igual que ya pasa con
-- `on_conflict=persona_id` en el perfil y con `persona_id,dia_semana` en el plan. Un `on_conflict=id` solo
-- (sin persona_id) ya NO tiene una llave única que lo respalde y PostgREST/Postgres lo rechaza (42P10).
-- Con esto, subir el id de otra persona ya no da 42501: crea la fila propia, sin tocar la ajena.
--
-- Nada de esto cambia columnas, RLS, triggers ni topes. PostgreSQL 15 o superior (ON DELETE SET NULL con lista de
-- columnas, como en las migraciones originales).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Retirar las llaves foráneas que dependen de las restricciones únicas (persona_id, id)
-- -----------------------------------------------------------------------------
alter table public.hab_ent_series drop constraint hab_ent_series_sesion_fk;
alter table public.hab_ent_series drop constraint hab_ent_series_banda_fk;
alter table public.hab_bici_perfil drop constraint hab_bici_perfil_bicicleta_fk;
alter table public.hab_bici_mantenimientos drop constraint hab_bici_mantenimientos_bicicleta_fk;
alter table public.hab_bici_salidas drop constraint hab_bici_salidas_bicicleta_fk;

-- -----------------------------------------------------------------------------
-- 2. Llave primaria (persona_id, id): sale la global y la restricción única que queda repetida
-- -----------------------------------------------------------------------------
alter table public.hab_ent_bandas
  drop constraint hab_ent_bandas_pkey,
  drop constraint hab_ent_bandas_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_ent_sesiones
  drop constraint hab_ent_sesiones_pkey,
  drop constraint hab_ent_sesiones_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_ent_series
  drop constraint hab_ent_series_pkey,
  add primary key (persona_id, id);
alter table public.hab_bici_bicicletas
  drop constraint hab_bici_bicicletas_pkey,
  drop constraint hab_bici_bicicletas_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_bici_mantenimientos
  drop constraint hab_bici_mantenimientos_pkey,
  drop constraint hab_bici_mantenimientos_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_bici_salidas
  drop constraint hab_bici_salidas_pkey,
  drop constraint hab_bici_salidas_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_musica_listas
  drop constraint hab_musica_listas_pkey,
  drop constraint hab_musica_listas_persona_id_key,
  add primary key (persona_id, id);

-- -----------------------------------------------------------------------------
-- 3. Recrear las llaves foráneas (mismos nombres, columnas y ON DELETE que en las migraciones originales)
-- -----------------------------------------------------------------------------
alter table public.hab_ent_series
  add constraint hab_ent_series_sesion_fk foreign key (persona_id, sesion_id)
    references public.hab_ent_sesiones (persona_id, id) on delete cascade,
  add constraint hab_ent_series_banda_fk foreign key (persona_id, banda_id)
    references public.hab_ent_bandas (persona_id, id) on delete set null (banda_id);
alter table public.hab_bici_perfil
  add constraint hab_bici_perfil_bicicleta_fk foreign key (persona_id, bicicleta_activa_id)
    references public.hab_bici_bicicletas (persona_id, id) on delete set null (bicicleta_activa_id);
alter table public.hab_bici_mantenimientos
  add constraint hab_bici_mantenimientos_bicicleta_fk foreign key (persona_id, bicicleta_id)
    references public.hab_bici_bicicletas (persona_id, id) on delete cascade;
alter table public.hab_bici_salidas
  add constraint hab_bici_salidas_bicicleta_fk foreign key (persona_id, bicicleta_id)
    references public.hab_bici_bicicletas (persona_id, id) on delete set null (bicicleta_id);
