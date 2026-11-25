-- =============================================================================
-- GRAVITY · Fase 8 · Hábitos · (1) La música sale del borrado de la bicicleta y (2) llaves primarias por persona, 2.ª parte
-- =============================================================================
-- Corrige 20261153000000_habitos_bicicleta.sql y completa 20261154000000_habitos_llaves_por_persona.sql SIN editarlas
-- (migraciones solo hacia adelante).
--
-- PARTE 1 · Decisión del dueño (25/nov/2026, docs/specs/fase-8-habitos-bicicleta.md, sección 16, punto 2)
-- La música será un módulo propio (cocinar, leer, bici, gimnasio, orar y quizá trabajar). Por eso el alcance de borrado
-- `bicicleta` YA NO borra `hab_musica_listas`: borra solo las cuatro tablas `hab_bici_*`. El alcance `todo` SÍ las borra
-- todas, también la música (quien pide borrar todo no quiere que quede nada suyo); `entrenamiento` tampoco la toca (como
-- antes). Se reescriben `hab_borrar_datos_de` y `hab_borrar_mis_datos` conservando todo lo demás tal cual; solo se
-- mueve una línea (`hab_musica_listas`) del bloque `bicicleta`/`todo` al bloque `todo`, y se corrige el comentario.
--
-- PARTE 2 · Llaves primarias (persona_id, id) en las demás tablas de Hábitos con ids calculables (G6-M1, 2.ª parte)
-- La migración 20261154 pasó a (persona_id, id) las siete tablas de gimnasio, bicicleta y música. Quedaban cinco tablas
-- de Hábitos con `id uuid primary key` GLOBAL y un id que la app calcula sin secreto (UUID v5 con el espacio de nombres
-- `6b1f8e0a-…`, que está en la app):
--   hab_revisiones     v5('revision|<lunes>')              no lleva ni la persona: dos personas del mismo hogar generan
--                                                          el MISMO id para la misma semana y la segunda choca (23505)
--                                                          en la llave global: es un fallo funcional, además del sondeo.
--   hab_marcas_biblia  v5('marca|<tipo>|<referencia>')     igual: sin persona; la segunda persona que subraya el mismo
--                                                          versículo choca.
--   hab_registros      v5('registro|<objetivo>|<fecha>') o v5('bloque|<bloque>|<fecha>'): con el objetivo o el bloque
--                      de gimnasio (ver abajo) es calculable por cualquiera que conozca el id de la persona.
--   hab_objetivos      el objetivo «Entrenamiento» es v5('gimobjetivo|<persona>').
--   hab_bloques        el bloque de cada día del plan de gimnasio es v5('gimbloque|<persona>|<día>').
-- Con la llave global, un `INSERT` con el id de otra persona daba 23505 si esa fila existía: un bit por intento sobre
-- «¿usa Ana el gimnasio?» o «¿tiene Ana un registro el día D?», para cualquier persona del hogar.
--
-- No se tocan (sus ids son UUID v4 aleatorios, no calculables, o su llave ya es por persona):
--   hab_pausas, hab_planes_lectura, hab_lecturas (v4 en la app), hab_plan_dias (llave (plan_id, dia) con un plan v4),
--   hab_sobres (v4; la llave global no deja sondear lo que no se puede calcular), hab_ajustes, hab_llaves, hab_modos,
--   hab_ent_perfil, hab_ent_plan_dias, hab_ent_inventario, hab_bici_perfil (llave natural por persona).
--
-- La corrección sigue EXACTO el método de 20261154: retira las llaves foráneas que dependen de las restricciones
-- únicas (persona_id, id); la llave primaria pasa a (persona_id, id) (en hab_objetivos y hab_bloques sale también la
-- restricción única repetida); las llaves foráneas se recrean con el mismo nombre, las mismas columnas y el mismo
-- ON DELETE. Los índices únicos naturales (hab_registros_un_elemento_por_dia, hab_revisiones_semana_unica), los
-- triggers, las reglas (RLS), los privilegios y los topes no se tocan.
--
-- Efecto para quien sube (la app y la cola): el upsert ya no se resuelve por `id` sino por `persona_id,id`
-- (`ON CONFLICT (persona_id, id)`; en PostgREST `on_conflict=persona_id,id`). La app NO manda `persona_id`: el trigger
-- hab_a_propio (BEFORE INSERT) lo pone antes de que Postgres busque el conflicto. Un `on_conflict=id` solo ya no tiene
-- llave única que lo respalde (42P10). Subir el id de otra persona ya no da 23505: crea la fila propia. En
-- hab_revisiones `on_conflict=persona_id,semana` (el que ya usa la app) sigue valiendo.
--
-- PostgreSQL 15 o superior (ON DELETE SET NULL con lista de columnas, como en las migraciones originales).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PARTE 1. Borrar mis datos: «bicicleta» borra solo las cuatro hab_bici_*; «todo» sigue borrando también la música
-- -----------------------------------------------------------------------------
create or replace function public.hab_borrar_datos_de(p_persona_id uuid, p_alcance text)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if p_alcance in ('sensibles', 'todo') then
    delete from public.hab_sobres where persona_id = p_persona_id and tipo = 'habitos_sensibles';
  end if;
  if p_alcance in ('diario', 'todo') then
    delete from public.hab_sobres where persona_id = p_persona_id and tipo = 'diario_oracion';
  end if;
  if p_alcance in ('entrenamiento', 'todo') then
    delete from public.hab_ent_series where persona_id = p_persona_id;
    delete from public.hab_ent_sesiones where persona_id = p_persona_id;
    delete from public.hab_ent_plan_dias where persona_id = p_persona_id;
    delete from public.hab_ent_bandas where persona_id = p_persona_id;
    delete from public.hab_ent_inventario where persona_id = p_persona_id;
    delete from public.hab_ent_perfil where persona_id = p_persona_id;
  end if;
  if p_alcance in ('bicicleta', 'todo') then
    delete from public.hab_bici_mantenimientos where persona_id = p_persona_id;
    delete from public.hab_bici_salidas where persona_id = p_persona_id;
    delete from public.hab_bici_perfil where persona_id = p_persona_id;
    delete from public.hab_bici_bicicletas where persona_id = p_persona_id;
  end if;
  if p_alcance = 'todo' then
    -- La música será un módulo propio (decisión del 25/nov/2026): solo «todo» la borra, ni «bicicleta» ni
    -- «entrenamiento» la tocan.
    delete from public.hab_musica_listas where persona_id = p_persona_id;
    delete from public.hab_llaves where persona_id = p_persona_id;
    delete from public.hab_registros where persona_id = p_persona_id;
    delete from public.hab_lecturas where persona_id = p_persona_id;
    delete from public.hab_marcas_biblia where persona_id = p_persona_id;
    delete from public.hab_revisiones where persona_id = p_persona_id;
    delete from public.hab_pausas where persona_id = p_persona_id;
    delete from public.hab_plan_dias where persona_id = p_persona_id;
    delete from public.hab_planes_lectura where persona_id = p_persona_id;
    delete from public.hab_bloques where persona_id = p_persona_id;
    delete from public.hab_objetivos where persona_id = p_persona_id;
    update public.hab_modos set modo = 'solo_telefono', cambiado_en = now() where persona_id = p_persona_id;
  end if;
  if p_alcance not in ('entrenamiento', 'bicicleta') then
    update public.hab_ajustes set epoca_nube = epoca_nube + 1 where persona_id = p_persona_id;
  end if;
end
$$;

create or replace function public.hab_borrar_mis_datos(p_alcance text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  perform public.hab_exigir_activa();
  if p_alcance not in ('sensibles', 'diario', 'entrenamiento', 'bicicleta', 'todo') then
    raise exception using errcode = '22023', message = 'El alcance es sensibles, diario, entrenamiento, bicicleta o todo.';
  end if;
  perform public.hab_borrar_datos_de(public.persona_actual(), p_alcance);
  perform public.hab_nota('habitos.borrar_datos');
end
$$;
comment on function public.hab_borrar_mis_datos(text) is
  'Borrado físico de lo propio: sensibles, diario, entrenamiento (las seis tablas hab_ent_*), bicicleta (solo las '
  'cuatro tablas hab_bici_*; NO los enlaces de música, que serán un módulo propio) o todo (también la llave, las '
  'tablas en claro y los enlaces de música; deja hab_ajustes). Deja una constancia sin contenido. No es un libro '
  'contable: se puede borrar.';

-- -----------------------------------------------------------------------------
-- PARTE 2. Llaves primarias (persona_id, id) en hab_objetivos, hab_bloques, hab_registros, hab_marcas_biblia, hab_revisiones
-- -----------------------------------------------------------------------------
-- 2.1 Retirar las llaves foráneas que dependen de las restricciones únicas (persona_id, id) de hab_objetivos y hab_bloques
alter table public.hab_bloques drop constraint hab_bloques_objetivo_fk;
alter table public.hab_registros drop constraint hab_registros_objetivo_fk;
alter table public.hab_registros drop constraint hab_registros_bloque_fk;
alter table public.hab_pausas drop constraint hab_pausas_objetivo_fk;
alter table public.hab_bici_salidas drop constraint hab_bici_salidas_bloque_fk;
alter table public.hab_ent_sesiones drop constraint hab_ent_sesiones_bloque_fk;

-- 2.2 Llave primaria (persona_id, id): sale la global y la restricción única que queda repetida
alter table public.hab_objetivos
  drop constraint hab_objetivos_pkey,
  drop constraint hab_objetivos_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_bloques
  drop constraint hab_bloques_pkey,
  drop constraint hab_bloques_persona_id_key,
  add primary key (persona_id, id);
alter table public.hab_registros
  drop constraint hab_registros_pkey,
  add primary key (persona_id, id);
alter table public.hab_marcas_biblia
  drop constraint hab_marcas_biblia_pkey,
  add primary key (persona_id, id);
alter table public.hab_revisiones
  drop constraint hab_revisiones_pkey,
  add primary key (persona_id, id);

-- 2.3 Recrear las llaves foráneas (mismos nombres, columnas y ON DELETE que en las migraciones originales)
alter table public.hab_bloques
  add constraint hab_bloques_objetivo_fk foreign key (persona_id, objetivo_id)
    references public.hab_objetivos (persona_id, id) on delete cascade;
alter table public.hab_registros
  add constraint hab_registros_objetivo_fk foreign key (persona_id, objetivo_id)
    references public.hab_objetivos (persona_id, id) on delete cascade,
  add constraint hab_registros_bloque_fk foreign key (persona_id, bloque_id)
    references public.hab_bloques (persona_id, id) on delete cascade;
alter table public.hab_pausas
  add constraint hab_pausas_objetivo_fk foreign key (persona_id, objetivo_id)
    references public.hab_objetivos (persona_id, id) on delete cascade;
alter table public.hab_bici_salidas
  add constraint hab_bici_salidas_bloque_fk foreign key (persona_id, bloque_id)
    references public.hab_bloques (persona_id, id) on delete set null (bloque_id);
alter table public.hab_ent_sesiones
  add constraint hab_ent_sesiones_bloque_fk foreign key (persona_id, bloque_id)
    references public.hab_bloques (persona_id, id) on delete set null (bloque_id);
