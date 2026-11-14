-- =============================================================================
-- GRAVITY · Fase 7 · Alimentación completa (primera tanda: esquema y reglas por cuenta)
-- =============================================================================
-- docs/specs/fase-7-alimentacion.md v1.0 (secciones 2, 3 y 5), D3, D5, D19, D23 y D28.
-- Agrega al esquema de la Fase 4 (20261108, 20261109):
--   - ali_ingredientes: catálogo con PRECIO BASE SUPUESTO (no es un dato real) y precio real (lo que capturó alguien).
--   - ali_recetas, ali_receta_pasos, ali_platillo_ingredientes: receta con pasos de texto libre en orden.
--   - ali_despensa: inventario por cuenta ('papa', 'dueno', 'pareja', 'casa'); el familiar solo lee el de Papá.
--   - ali_compras (lista por pasillo; el pasillo sale del ingrediente), ali_solicitudes_pago (Papá: solicitud al albacea),
--     ali_precios_historial (solo agregar), ali_ajustes (libro compartido de la casa que elige el dueño).
--   - ali_votaciones, ali_votacion_opciones, ali_opcion_platillos, ali_votos: plan familiar por votación (un día).
--   - ali_tomas_suplemento y ali_reposiciones_suplemento: confirmación de toma (dado / no dado) y reposición.
-- Los permisos NO salen de permisos_rol: los decide ali_puede7() (como ali_puede() en la Fase 4). Casa: solo el menú del
-- día de Papá (RPC ali_menu_del_dia_papa, sin datos clínicos), el plan familiar y las tomas. La cuenta maestra solo lee.
-- Todo lo que cambia a la vez dinero, precio, inventario o votos va por RPC (security definer con permiso explícito):
-- las tablas correspondientes no admiten escritura directa. Sin bitácora (hay datos clínicos de Papá).
-- Convención 12: los grant repiten la lista completa. Migración nueva (hacia adelante). PostgreSQL 15 o superior.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Quién es quien, y la matriz de D28
-- -----------------------------------------------------------------------------
create function public.ali_cuenta_de(p_hogar_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select case
    when r.rol is null then null
    when r.rol = 'coadministrador' and public.es_cuenta_maestra(p_hogar_id) then 'maestra'
    when r.rol = 'dueno' then 'dueno'
    when r.rol = 'coadministrador' then 'pareja'
    when r.rol = 'familiar' then 'familiar'
    when r.rol = 'cuidador' then 'cuidador'
    when r.rol = 'casa' then 'casa'
    else null end
  from (select public.rol_en_hogar(p_hogar_id) as rol) r
$$;
comment on function public.ali_cuenta_de(uuid) is
  'Cuenta de Alimentación de quien consulta: dueno, pareja (coadministrador), maestra (coadministrador con la marca), familiar, cuidador o casa. Nulo si no es del hogar.';

-- objeto: ingredientes | recetas | despensa | compras | votaciones | tomas | reposiciones | ajustes.
-- p_cuenta: la despensa o la lista de que se trata (papa | dueno | pareja | casa); nulo en lo demás.
-- accion: leer | escribir | comprar | proponer | votar | confirmar.
create function public.ali_puede7(p_hogar_id uuid, p_objeto text, p_cuenta text, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_q text := public.ali_cuenta_de(p_hogar_id);
begin
  if v_q is null
     or p_objeto not in ('ingredientes', 'recetas', 'despensa', 'compras', 'votaciones', 'tomas', 'reposiciones', 'ajustes')
     or p_accion not in ('leer', 'escribir', 'comprar', 'proponer', 'votar', 'confirmar')
     or (p_objeto in ('despensa', 'compras') and (p_cuenta is null or p_cuenta <> all (array['papa', 'dueno', 'pareja', 'casa']))) then
    return false;
  end if;
  return case p_objeto
    when 'ingredientes' then case p_accion
      when 'leer' then v_q in ('dueno', 'pareja', 'familiar', 'maestra')
      when 'escribir' then v_q in ('dueno', 'pareja')
      else false end
    when 'recetas' then case p_accion
      when 'leer' then v_q in ('dueno', 'pareja', 'familiar', 'cuidador', 'maestra')
      when 'escribir' then v_q in ('dueno', 'pareja')
      else false end
    when 'despensa' then case p_accion
      when 'leer' then case p_cuenta
        when 'papa' then v_q in ('dueno', 'pareja', 'familiar', 'maestra')
        when 'dueno' then v_q in ('dueno', 'maestra')
        when 'pareja' then v_q in ('pareja', 'maestra')
        else v_q in ('dueno', 'pareja', 'maestra') end
      when 'escribir' then case p_cuenta
        when 'dueno' then v_q = 'dueno'
        when 'pareja' then v_q = 'pareja'
        else v_q in ('dueno', 'pareja') end
      else false end
    when 'compras' then case p_accion
      when 'leer' then case p_cuenta
        when 'dueno' then v_q in ('dueno', 'maestra')
        when 'pareja' then v_q in ('pareja', 'maestra')
        else v_q in ('dueno', 'pareja', 'maestra') end
      when 'escribir' then case p_cuenta
        when 'dueno' then v_q = 'dueno'
        when 'pareja' then v_q = 'pareja'
        else v_q in ('dueno', 'pareja') end
      when 'comprar' then case p_cuenta
        when 'dueno' then v_q = 'dueno'
        when 'pareja' then v_q = 'pareja'
        else v_q in ('dueno', 'pareja') end
      else false end
    when 'votaciones' then case p_accion
      when 'leer' then v_q in ('dueno', 'pareja', 'familiar', 'casa', 'maestra')
      when 'proponer' then v_q in ('dueno', 'pareja', 'familiar')
      when 'votar' then v_q in ('dueno', 'pareja', 'familiar')
      else false end
    when 'tomas' then case p_accion
      when 'leer' then v_q in ('dueno', 'pareja', 'familiar', 'cuidador', 'casa', 'maestra')
      when 'confirmar' then v_q in ('dueno', 'pareja', 'familiar', 'cuidador')
      when 'escribir' then v_q in ('dueno', 'pareja')
      else false end
    when 'reposiciones' then case p_accion
      when 'leer' then v_q in ('dueno', 'pareja', 'maestra')
      when 'escribir' then v_q in ('dueno', 'pareja')
      else false end
    else case p_accion
      when 'leer' then v_q in ('dueno', 'pareja', 'maestra')
      when 'escribir' then v_q = 'dueno'
      else false end
  end;
end
$$;
comment on function public.ali_puede7(uuid, text, text, text) is
  'D28 (Fase 7): quién lee y escribe cada parte nueva de Alimentación. La despensa de otra cuenta no se ve (solo los sobrantes de '
  'pareja y dueño, con ali_sobrantes). Casa lee el plan familiar y las tomas, nada más. Cuidadora: solo tomas y recetas. '
  'La maestra solo lee. "comprar" marca la compra y toca el dinero (RPC ali_marcar_comprada).';

-- -----------------------------------------------------------------------------
-- 2. Tablas del catálogo y la receta
-- -----------------------------------------------------------------------------
create table public.ali_ingredientes (
  id                      uuid primary key default gen_random_uuid(),
  hogar_id                uuid not null references public.hogares (id),
  nombre                  text not null check (char_length(btrim(nombre)) between 1 and 80),
  unidad                  text not null check (char_length(btrim(unidad)) between 1 and 20),
  pasillo                 text not null default 'Otros' check (char_length(btrim(pasillo)) between 1 and 40),
  precio_base_centavos    bigint check (precio_base_centavos is null or precio_base_centavos >= 0),
  precio_real_centavos    bigint check (precio_real_centavos is null or precio_real_centavos > 0),
  precio_real_en          timestamptz,
  precio_es_base          boolean generated always as (precio_real_centavos is null) stored,
  precio_vigente_centavos bigint generated always as (coalesce(precio_real_centavos, precio_base_centavos)) stored,
  actualizado_por         uuid references public.personas (id),
  actualizado_en          timestamptz not null default now(),
  constraint ali_ingredientes_hogar_id_key unique (hogar_id, id),
  constraint ali_ingredientes_real_con_fecha check ((precio_real_centavos is null) = (precio_real_en is null))
);
create unique index ali_ingredientes_nombre_unico on public.ali_ingredientes (hogar_id, lower(btrim(nombre)));
comment on table public.ali_ingredientes is
  'Catálogo de ingredientes del hogar. Precios por UNIDAD, en centavos. precio_base_centavos es un SUPUESTO sin mucha relevancia (no un '
  'dato real): precio_es_base lo dice. La primera compra real lo reemplaza (precio_real_centavos) y las siguientes lo actualizan; '
  'solo la RPC ali_marcar_comprada escribe el real. Nunca se inventan precios (spec 3).';
comment on column public.ali_ingredientes.precio_es_base is 'Verdadero mientras no haya una compra real: el precio vigente es el supuesto.';

create table public.ali_recetas (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  platillo_id     uuid,
  titulo          text not null check (char_length(btrim(titulo)) between 1 and 120),
  porciones       smallint not null default 1 check (porciones between 1 and 100),
  actualizado_por uuid references public.personas (id),
  actualizado_en  timestamptz not null default now(),
  constraint ali_recetas_hogar_id_key unique (hogar_id, id),
  constraint ali_recetas_platillo_fk foreign key (hogar_id, platillo_id) references public.ali_platillos (hogar_id, id) on delete set null (platillo_id)
);
create unique index ali_recetas_un_platillo on public.ali_recetas (hogar_id, platillo_id) where platillo_id is not null;
comment on table public.ali_recetas is 'Receta de un platillo (título, porciones); sus pasos están en ali_receta_pasos. Se carga primero desde archivo (spec 5).';

create table public.ali_receta_pasos (
  id          uuid primary key default gen_random_uuid(),
  hogar_id    uuid not null references public.hogares (id),
  receta_id   uuid not null,
  orden       smallint not null check (orden between 1 and 60),
  texto       text not null check (char_length(btrim(texto)) between 1 and 500),
  tiene_cifras boolean generated always as (texto ~ '[0-9]') stored,
  constraint ali_receta_pasos_receta_fk foreign key (hogar_id, receta_id) references public.ali_recetas (hogar_id, id) on delete cascade,
  constraint ali_receta_pasos_orden unique (receta_id, orden) deferrable initially deferred
);
comment on table public.ali_receta_pasos is
  'Pasos de la receta, en orden, de texto libre. tiene_cifras es solo un aviso (hay dígitos): por la bocina no deben llevar cifras y '
  'el filtro de salida de la Fase 6b decide; el servidor no recorta nada.';

create table public.ali_platillo_ingredientes (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  platillo_id    uuid not null,
  ingrediente_id uuid not null,
  cantidad       numeric(12, 3) not null check (cantidad > 0),
  constraint ali_platillo_ingredientes_platillo_fk foreign key (hogar_id, platillo_id) references public.ali_platillos (hogar_id, id) on delete cascade,
  constraint ali_platillo_ingredientes_ing_fk foreign key (hogar_id, ingrediente_id) references public.ali_ingredientes (hogar_id, id),
  constraint ali_platillo_ingredientes_uno unique (platillo_id, ingrediente_id)
);
comment on table public.ali_platillo_ingredientes is 'Ingredientes de un platillo con cantidad en la unidad del ingrediente. Base de los faltantes del plan familiar.';

create table public.ali_ajustes (
  hogar_id       uuid primary key references public.hogares (id),
  libro_casa_id  uuid,
  actualizado_por uuid references public.personas (id),
  actualizado_en timestamptz not null default now(),
  constraint ali_ajustes_libro_fk foreign key (hogar_id, libro_casa_id) references public.fin_libros (hogar_id, id)
);
comment on table public.ali_ajustes is 'Ajustes de Alimentación del hogar. libro_casa_id: el libro compartido de donde salen las compras de la casa; lo elige el dueño.';

-- -----------------------------------------------------------------------------
-- 3. Plan familiar por votación (D28)
-- -----------------------------------------------------------------------------
create table public.ali_votaciones (
  id          uuid primary key default gen_random_uuid(),
  hogar_id    uuid not null references public.hogares (id),
  cuenta      text not null default 'casa' check (cuenta in ('casa', 'papa')),
  titulo      text not null check (char_length(btrim(titulo)) between 1 and 120),
  para_el     date,
  creada_por  uuid not null default public.persona_actual() references public.personas (id),
  creada_en   timestamptz not null default now(),
  cierra_en   timestamptz not null default now() + interval '1 day',
  estado      text not null default 'abierta' check (estado in ('abierta', 'empate', 'cerrada')),
  ronda       smallint not null default 1 check (ronda >= 1),
  ganadora_id uuid,
  cerrada_en  timestamptz,
  constraint ali_votaciones_hogar_id_key unique (hogar_id, id),
  constraint ali_votaciones_ganadora_coherente check ((estado = 'cerrada') = (ganadora_id is not null and cerrada_en is not null))
);
create unique index ali_votaciones_una_abierta on public.ali_votaciones (hogar_id, cuenta) where estado in ('abierta', 'empate');
comment on table public.ali_votaciones is
  'Plan familiar (D28). Dura un día (cierra_en). abierta: se vota y cada quien puede cambiar su voto. empate: al cierre quedaron igualados; sigue '
  'abierta un día más para que cambien su voto (ronda +1). cerrada: hay ganadora_id. Solo cambia por las RPC ali_proponer_*, ali_votar y ali_cerrar_votaciones.';

create table public.ali_votacion_opciones (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  votacion_id   uuid not null,
  orden         smallint not null check (orden in (1, 2)),
  propuesto_por uuid not null references public.personas (id),
  titulo        text not null check (char_length(btrim(titulo)) between 1 and 120),
  platillos     text[] not null default '{}' check (cardinality(platillos) <= 30),
  creada_en     timestamptz not null default now(),
  constraint ali_votacion_opciones_votacion_fk foreign key (hogar_id, votacion_id) references public.ali_votaciones (hogar_id, id) on delete cascade,
  constraint ali_votacion_opciones_orden unique (votacion_id, orden),
  constraint ali_votacion_opciones_votacion_id_key unique (votacion_id, id),
  constraint ali_votacion_opciones_hogar_id_key unique (hogar_id, id)
);
comment on table public.ali_votacion_opciones is
  'Orden 1: la propuesta; orden 2: la propuesta alternativa de otra persona. platillos: nombres al momento de proponer (para que Casa los vea sin leer el catálogo).';

create table public.ali_opcion_platillos (
  opcion_id   uuid not null references public.ali_votacion_opciones (id) on delete cascade,
  hogar_id    uuid not null references public.hogares (id),
  platillo_id uuid not null,
  primary key (opcion_id, platillo_id),
  constraint ali_opcion_platillos_platillo_fk foreign key (hogar_id, platillo_id) references public.ali_platillos (hogar_id, id) on delete cascade
);

create table public.ali_votos (
  votacion_id uuid not null,
  hogar_id    uuid not null references public.hogares (id),
  persona_id  uuid not null references public.personas (id),
  opcion_id   uuid not null,
  votado_en   timestamptz not null default now(),
  cambios     smallint not null default 0,
  primary key (votacion_id, persona_id),
  constraint ali_votos_votacion_fk foreign key (hogar_id, votacion_id) references public.ali_votaciones (hogar_id, id) on delete cascade,
  constraint ali_votos_opcion_fk foreign key (votacion_id, opcion_id) references public.ali_votacion_opciones (votacion_id, id) on delete cascade
);
comment on table public.ali_votos is 'Un voto por persona y votación; se cambia con ali_votar mientras la votación esté abierta o en empate (cambios cuenta las veces).';

-- -----------------------------------------------------------------------------
-- 4. Despensa, lista de compras, pagos y precios
-- -----------------------------------------------------------------------------
create table public.ali_despensa (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  cuenta         text not null check (cuenta in ('papa', 'dueno', 'pareja', 'casa')),
  ingrediente_id uuid not null,
  cantidad       numeric(12, 3) not null default 0 check (cantidad >= 0),
  reservado      numeric(12, 3) not null default 0 check (reservado >= 0),
  actualizado_por uuid references public.personas (id),
  actualizado_en timestamptz not null default now(),
  constraint ali_despensa_ing_fk foreign key (hogar_id, ingrediente_id) references public.ali_ingredientes (hogar_id, id),
  constraint ali_despensa_uno unique (hogar_id, cuenta, ingrediente_id)
);
comment on table public.ali_despensa is
  'Inventario por cuenta (D28): papa, dueno, pareja y casa. reservado = lo ya planeado de la semana; lo que sobra es cantidad - reservado y es lo único que '
  'pareja y dueño se comparten (ali_sobrantes). Se actualiza al marcar compras.';

create table public.ali_compras (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  cuenta         text not null check (cuenta in ('papa', 'dueno', 'pareja', 'casa')),
  ingrediente_id uuid not null,
  cantidad       numeric(12, 3) not null check (cantidad > 0),
  solicitada_por uuid not null default public.persona_actual() references public.personas (id),
  comprador_id   uuid references public.personas (id),
  para_el        date,
  votacion_id    uuid,
  comprado       boolean not null default false,
  comprado_en    timestamptz,
  comprado_por   uuid references public.personas (id),
  monto_centavos bigint check (monto_centavos is null or monto_centavos > 0),
  estado_pago    text not null default 'sin_pago' check (estado_pago in ('sin_pago', 'movimiento', 'solicitud', 'rechazada')),
  movimiento_id  uuid,
  creada_en      timestamptz not null default now(),
  constraint ali_compras_hogar_id_key unique (hogar_id, id),
  constraint ali_compras_ing_fk foreign key (hogar_id, ingrediente_id) references public.ali_ingredientes (hogar_id, id),
  constraint ali_compras_votacion_fk foreign key (hogar_id, votacion_id) references public.ali_votaciones (hogar_id, id),
  constraint ali_compras_mov_fk foreign key (hogar_id, movimiento_id) references public.fin_movimientos (hogar_id, id),
  constraint ali_compras_comprada_coherente check (comprado = (comprado_en is not null and comprado_por is not null)),
  constraint ali_compras_pago_coherente check (
    (estado_pago = 'sin_pago' and monto_centavos is null and movimiento_id is null)
    or (comprado and monto_centavos is not null and estado_pago <> 'sin_pago'
        and (movimiento_id is not null) = (estado_pago = 'movimiento')))
);
create unique index ali_compras_una_por_votacion on public.ali_compras (votacion_id, ingrediente_id) where votacion_id is not null;
create index ali_compras_lista_idx on public.ali_compras (hogar_id, cuenta, comprado);
comment on table public.ali_compras is
  'Lista de compras por cuenta; el pasillo sale del ingrediente (se agrupa en la app). comprador_id = quién compra; para_el = cuándo. '
  'Al marcarla (ali_marcar_comprada) con monto: precio real al ingrediente, inventario y movimiento del libro correcto '
  '(Papá: solicitud al albacea). Una compra marcada ya no se desmarca ni se borra: se corrige en Finanzas con anulación.';

create table public.ali_solicitudes_pago (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  compra_id      uuid not null,
  monto_centavos bigint not null check (monto_centavos > 0),
  estado         text not null default 'pendiente' check (estado in ('pendiente', 'pagada', 'rechazada')),
  solicitada_por uuid not null default public.persona_actual() references public.personas (id),
  solicitada_en  timestamptz not null default now(),
  resuelta_por   uuid references public.personas (id),
  resuelta_en    timestamptz,
  motivo         text check (char_length(motivo) <= 200),
  movimiento_id  uuid,
  constraint ali_solicitudes_pago_compra_fk foreign key (hogar_id, compra_id) references public.ali_compras (hogar_id, id),
  constraint ali_solicitudes_pago_mov_fk foreign key (hogar_id, movimiento_id) references public.fin_movimientos (hogar_id, id),
  constraint ali_solicitudes_pago_una unique (compra_id),
  constraint ali_solicitudes_pago_resuelta check ((estado = 'pendiente') = (resuelta_en is null))
);
comment on table public.ali_solicitudes_pago is
  'Compra de Papá: la aprueba y paga el albacea (D19). Se resuelve con ali_resolver_solicitud_pago, que registra el gasto en el libro de Papá (en su nombre, con motivo).';

create table public.ali_precios_historial (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  ingrediente_id uuid not null,
  precio_centavos bigint not null check (precio_centavos > 0),
  compra_id      uuid,
  registrado_por uuid references public.personas (id),
  registrado_en  timestamptz not null default now(),
  constraint ali_precios_historial_ing_fk foreign key (hogar_id, ingrediente_id) references public.ali_ingredientes (hogar_id, id),
  constraint ali_precios_historial_compra_fk foreign key (hogar_id, compra_id) references public.ali_compras (hogar_id, id)
);
create index ali_precios_historial_idx on public.ali_precios_historial (hogar_id, ingrediente_id, registrado_en desc);
comment on table public.ali_precios_historial is 'Solo agregar: cada precio real capturado al comprar (base del historial con alerta). Nunca precios inventados.';

-- -----------------------------------------------------------------------------
-- 5. Suplementos de Papá: tomas y reposición (D28)
-- -----------------------------------------------------------------------------
create table public.ali_tomas_suplemento (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  suplemento_id   uuid not null,
  nombre          text not null,
  prevista_en     timestamptz not null,
  estado          text not null default 'pendiente' check (estado in ('pendiente', 'dado', 'no_dado', 'sin_confirmar')),
  confirmado_por  uuid references public.personas (id),
  confirmado_en   timestamptz,
  constraint ali_tomas_suplemento_hogar_id_key unique (hogar_id, id),
  constraint ali_tomas_suplemento_fk foreign key (suplemento_id) references public.ali_suplementos (id) on delete cascade,
  constraint ali_tomas_suplemento_una unique (suplemento_id, prevista_en),
  constraint ali_tomas_suplemento_confirmada check ((estado in ('dado', 'no_dado')) = (confirmado_por is not null and confirmado_en is not null))
);
comment on table public.ali_tomas_suplemento is
  'Toma de un suplemento de Papá. La confirma quien la da (dado / no dado, ali_confirmar_toma); si nadie la confirma pasa a sin_confirmar y se solicita '
  'la reposición (ali_revisar_tomas). Casa solo lee: nombre es una copia sin dosis.';

create table public.ali_reposiciones_suplemento (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  suplemento_id uuid not null,
  toma_id       uuid,
  estado        text not null default 'pendiente' check (estado in ('pendiente', 'atendida', 'descartada')),
  creada_en     timestamptz not null default now(),
  resuelta_por  uuid references public.personas (id),
  resuelta_en   timestamptz,
  constraint ali_reposiciones_suplemento_fk foreign key (suplemento_id) references public.ali_suplementos (id) on delete cascade,
  constraint ali_reposiciones_toma_fk foreign key (toma_id) references public.ali_tomas_suplemento (id) on delete set null,
  constraint ali_reposiciones_resuelta check ((estado = 'pendiente') = (resuelta_en is null))
);
create unique index ali_reposiciones_una_pendiente on public.ali_reposiciones_suplemento (suplemento_id) where estado = 'pendiente';
comment on table public.ali_reposiciones_suplemento is 'Solicitud de reposición de un suplemento cuando una toma queda sin confirmar. Una pendiente por suplemento.';

-- -----------------------------------------------------------------------------
-- 6. Lo que pone el servidor, validaciones y cuota de filas
-- -----------------------------------------------------------------------------
create function public.ali7_propio()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if to_jsonb(new) ? 'actualizado_por' then
    new.actualizado_por := coalesce(public.persona_actual(), new.actualizado_por);
    new.actualizado_en := now();
  end if;
  if tg_op = 'UPDATE' and to_jsonb(new) ? 'hogar_id' and new.hogar_id is distinct from old.hogar_id then
    raise exception using errcode = '42501', message = 'El hogar de un registro de Alimentación no cambia.';
  end if;
  return new;
end
$$;

-- El libro de la casa debe ser compartido y del mismo hogar.
create function public.ali_ajustes_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.libro_casa_id is not null and not exists (
       select 1 from public.fin_libros l where l.id = new.libro_casa_id and l.hogar_id = new.hogar_id and l.tipo = 'compartido' and l.activo) then
    raise exception using errcode = '22023', message = 'El libro de la casa debe ser un libro compartido activo del hogar.';
  end if;
  return new;
end
$$;

-- Una compra marcada no se desmarca ni se edita; solo la resolución del pago cambia su estado.
create function public.ali_compras_guardia()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libres text[] := array['estado_pago', 'movimiento_id'];
begin
  if tg_op = 'DELETE' then
    if old.comprado then
      raise exception using errcode = '42501', message = 'Una compra marcada no se borra: se corrige en Finanzas con una anulación.';
    end if;
    return old;
  end if;
  if old.comprado then
    if (to_jsonb(new) - v_libres) is distinct from (to_jsonb(old) - v_libres)
       or not (old.estado_pago = 'solicitud' and new.estado_pago in ('movimiento', 'rechazada')) then
      raise exception using errcode = '42501', message = 'Una compra marcada ya no se edita ni se desmarca.';
    end if;
  elsif new.comprado and (new.cuenta is distinct from old.cuenta or new.ingrediente_id is distinct from old.ingrediente_id) then
    raise exception using errcode = '42501', message = 'La cuenta y el ingrediente de una compra no cambian.';
  end if;
  return new;
end
$$;

-- Cada toma lleva el nombre del suplemento (sin dosis) y solo existe para los de Papá.
create function public.ali_tomas_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_s public.ali_suplementos%rowtype;
begin
  select * into v_s from public.ali_suplementos s where s.id = new.suplemento_id;
  if not found or v_s.hogar_id <> new.hogar_id or v_s.menu <> 'papa' then
    raise exception using errcode = '22023', message = 'Las tomas son de los suplementos de Papá de este hogar.';
  end if;
  new.nombre := v_s.nombre;
  return new;
end
$$;

create function public.ali7_cuota_filas()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_hogar uuid;
  v_tope  integer := case tg_table_name when 'ali_ingredientes' then 5000 when 'ali_recetas' then 2000
                       when 'ali_receta_pasos' then 40000 when 'ali_platillo_ingredientes' then 40000
                       when 'ali_despensa' then 20000 when 'ali_compras' then 50000 when 'ali_votaciones' then 3000
                       when 'ali_precios_historial' then 100000 when 'ali_solicitudes_pago' then 20000
                       when 'ali_tomas_suplemento' then 100000 when 'ali_reposiciones_suplemento' then 5000 end;
  v_n bigint;
begin
  for v_hogar in select distinct n.hogar_id from nuevas n loop
    execute format('select count(*) from public.%I where hogar_id = $1', tg_table_name) into v_n using v_hogar;
    if v_n > v_tope then
      raise exception using errcode = '54000',
        message = format('Se llegó al tope de %s filas en %s.', v_tope, tg_table_name), hint = 'Borra lo que ya no uses.';
    end if;
  end loop;
  return null;
end
$$;

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['ali_ingredientes', 'ali_recetas', 'ali_receta_pasos', 'ali_platillo_ingredientes', 'ali_ajustes', 'ali_despensa',
                                 'ali_compras', 'ali_solicitudes_pago', 'ali_precios_historial', 'ali_votaciones', 'ali_votacion_opciones',
                                 'ali_opcion_platillos', 'ali_votos', 'ali_tomas_suplemento', 'ali_reposiciones_suplemento'] loop
    execute format('alter table public.%I enable row level security', v_tabla);
    execute format('create trigger ali7_a_propio before insert or update on public.%I
                      for each row execute function public.ali7_propio()', v_tabla);
  end loop;
  foreach v_tabla in array array['ali_ingredientes', 'ali_recetas', 'ali_receta_pasos', 'ali_platillo_ingredientes', 'ali_despensa',
                                 'ali_compras', 'ali_solicitudes_pago', 'ali_precios_historial', 'ali_votaciones',
                                 'ali_tomas_suplemento', 'ali_reposiciones_suplemento'] loop
    execute format('create trigger ali7_z_cuota after insert on public.%I referencing new table as nuevas
                      for each statement execute function public.ali7_cuota_filas()', v_tabla);
  end loop;
end
$$;

create trigger ali7_b_validar before insert or update on public.ali_ajustes
  for each row execute function public.ali_ajustes_validar();
create trigger ali7_b_guardia before update or delete on public.ali_compras
  for each row execute function public.ali_compras_guardia();
create trigger ali7_b_validar before insert on public.ali_tomas_suplemento
  for each row execute function public.ali_tomas_validar();
-- El historial de precios es solo agregar.
create trigger ali7_c_solo_agregar before update or delete on public.ali_precios_historial
  for each row execute function public.impedir_cambios_solo_agregar();

-- -----------------------------------------------------------------------------
-- 7. Reglas por registro (RLS)
-- -----------------------------------------------------------------------------
create policy ali_ingredientes_leer on public.ali_ingredientes for select to authenticated
  using (public.ali_puede7(hogar_id, 'ingredientes', null, 'leer'));
create policy ali_ingredientes_agregar on public.ali_ingredientes for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'ingredientes', null, 'escribir'));
create policy ali_ingredientes_editar on public.ali_ingredientes for update to authenticated
  using (public.ali_puede7(hogar_id, 'ingredientes', null, 'escribir'))
  with check (public.ali_puede7(hogar_id, 'ingredientes', null, 'escribir'));
create policy ali_ingredientes_borrar on public.ali_ingredientes for delete to authenticated
  using (public.ali_puede7(hogar_id, 'ingredientes', null, 'escribir'));

create policy ali_recetas_leer on public.ali_recetas for select to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'leer'));
create policy ali_recetas_agregar on public.ali_recetas for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));
create policy ali_recetas_editar on public.ali_recetas for update to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'))
  with check (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));
create policy ali_recetas_borrar on public.ali_recetas for delete to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));

create policy ali_receta_pasos_leer on public.ali_receta_pasos for select to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'leer'));
create policy ali_receta_pasos_agregar on public.ali_receta_pasos for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));
create policy ali_receta_pasos_editar on public.ali_receta_pasos for update to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'))
  with check (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));
create policy ali_receta_pasos_borrar on public.ali_receta_pasos for delete to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));

create policy ali_platillo_ingredientes_leer on public.ali_platillo_ingredientes for select to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'leer'));
create policy ali_platillo_ingredientes_agregar on public.ali_platillo_ingredientes for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));
create policy ali_platillo_ingredientes_editar on public.ali_platillo_ingredientes for update to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'))
  with check (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));
create policy ali_platillo_ingredientes_borrar on public.ali_platillo_ingredientes for delete to authenticated
  using (public.ali_puede7(hogar_id, 'recetas', null, 'escribir'));

create policy ali_ajustes_leer on public.ali_ajustes for select to authenticated
  using (public.ali_puede7(hogar_id, 'ajustes', null, 'leer'));
create policy ali_ajustes_agregar on public.ali_ajustes for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'ajustes', null, 'escribir'));
create policy ali_ajustes_editar on public.ali_ajustes for update to authenticated
  using (public.ali_puede7(hogar_id, 'ajustes', null, 'escribir'))
  with check (public.ali_puede7(hogar_id, 'ajustes', null, 'escribir'));

create policy ali_despensa_leer on public.ali_despensa for select to authenticated
  using (public.ali_puede7(hogar_id, 'despensa', cuenta, 'leer'));
create policy ali_despensa_agregar on public.ali_despensa for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'despensa', cuenta, 'escribir'));
create policy ali_despensa_editar on public.ali_despensa for update to authenticated
  using (public.ali_puede7(hogar_id, 'despensa', cuenta, 'escribir'))
  with check (public.ali_puede7(hogar_id, 'despensa', cuenta, 'escribir'));
create policy ali_despensa_borrar on public.ali_despensa for delete to authenticated
  using (public.ali_puede7(hogar_id, 'despensa', cuenta, 'escribir'));

-- Lista de compras: dueño y pareja la llevan; el familiar solo ve y borra lo que él solicitó (papa y casa).
create policy ali_compras_leer on public.ali_compras for select to authenticated
  using (public.ali_puede7(hogar_id, 'compras', cuenta, 'leer')
         or (solicitada_por = public.persona_actual() and cuenta in ('papa', 'casa') and public.ali_cuenta_de(hogar_id) = 'familiar'));
create policy ali_compras_agregar on public.ali_compras for insert to authenticated
  with check (public.ali_puede7(hogar_id, 'compras', cuenta, 'escribir'));
create policy ali_compras_editar on public.ali_compras for update to authenticated
  using (not comprado and public.ali_puede7(hogar_id, 'compras', cuenta, 'escribir'))
  with check (not comprado and public.ali_puede7(hogar_id, 'compras', cuenta, 'escribir'));
create policy ali_compras_borrar on public.ali_compras for delete to authenticated
  using (not comprado and (public.ali_puede7(hogar_id, 'compras', cuenta, 'escribir')
         or (solicitada_por = public.persona_actual() and cuenta in ('papa', 'casa') and public.ali_cuenta_de(hogar_id) = 'familiar')));

-- Solicitud de pago de Papá: la ve quien la hizo, el albacea (quien puede escribir en el libro de Papá) y la maestra.
create function public.ali_libro_papa(p_hogar_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select l.id from public.fin_libros l
  where l.hogar_id = p_hogar_id and l.tipo = 'representado' and l.activo
  order by l.creado_en, l.id limit 1
$$;
comment on function public.ali_libro_papa(uuid) is 'El libro representado (el de Papá) del hogar; nulo si no existe.';

create function public.ali_ve_solicitud(p_hogar_id uuid, p_solicitante uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.ali_cuenta_de(p_hogar_id) is not null and (
    p_solicitante = public.persona_actual()
    or public.ali_cuenta_de(p_hogar_id) = 'maestra'
    or public.fin_puede(public.ali_libro_papa(p_hogar_id), 'escribir'))
$$;

create policy ali_solicitudes_pago_leer on public.ali_solicitudes_pago for select to authenticated
  using (public.ali_ve_solicitud(hogar_id, solicitada_por));
create policy ali_precios_historial_leer on public.ali_precios_historial for select to authenticated
  using (public.ali_puede7(hogar_id, 'ingredientes', null, 'leer') and public.ali_cuenta_de(hogar_id) <> 'familiar');

create policy ali_votaciones_leer on public.ali_votaciones for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer'));
create policy ali_votacion_opciones_leer on public.ali_votacion_opciones for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer'));
create policy ali_opcion_platillos_leer on public.ali_opcion_platillos for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer'));
create policy ali_votos_leer on public.ali_votos for select to authenticated
  using (public.ali_puede7(hogar_id, 'votaciones', null, 'leer'));

create policy ali_tomas_suplemento_leer on public.ali_tomas_suplemento for select to authenticated
  using (public.ali_puede7(hogar_id, 'tomas', null, 'leer'));
create policy ali_reposiciones_suplemento_leer on public.ali_reposiciones_suplemento for select to authenticated
  using (public.ali_puede7(hogar_id, 'reposiciones', null, 'leer'));

-- -----------------------------------------------------------------------------
-- 8. Privilegios de las tablas (por columna; lo que toca dinero, precio y votos solo por RPC)
-- -----------------------------------------------------------------------------
revoke all on table public.ali_ingredientes, public.ali_recetas, public.ali_receta_pasos, public.ali_platillo_ingredientes, public.ali_ajustes,
  public.ali_despensa, public.ali_compras, public.ali_solicitudes_pago, public.ali_precios_historial, public.ali_votaciones,
  public.ali_votacion_opciones, public.ali_opcion_platillos, public.ali_votos, public.ali_tomas_suplemento, public.ali_reposiciones_suplemento
  from public, anon, authenticated, service_role;
grant select on public.ali_ingredientes, public.ali_recetas, public.ali_receta_pasos, public.ali_platillo_ingredientes, public.ali_ajustes,
  public.ali_despensa, public.ali_compras, public.ali_solicitudes_pago, public.ali_precios_historial, public.ali_votaciones,
  public.ali_votacion_opciones, public.ali_opcion_platillos, public.ali_votos, public.ali_tomas_suplemento, public.ali_reposiciones_suplemento
  to authenticated, service_role;
grant delete on public.ali_ingredientes, public.ali_recetas, public.ali_receta_pasos, public.ali_platillo_ingredientes, public.ali_despensa,
  public.ali_compras to authenticated;
grant insert (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos),
      update (id, hogar_id, nombre, unidad, pasillo, precio_base_centavos) on public.ali_ingredientes to authenticated;
grant insert (id, hogar_id, platillo_id, titulo, porciones), update (id, hogar_id, platillo_id, titulo, porciones) on public.ali_recetas to authenticated;
grant insert (id, hogar_id, receta_id, orden, texto), update (id, hogar_id, receta_id, orden, texto) on public.ali_receta_pasos to authenticated;
grant insert (id, hogar_id, platillo_id, ingrediente_id, cantidad), update (id, hogar_id, platillo_id, ingrediente_id, cantidad)
  on public.ali_platillo_ingredientes to authenticated;
grant insert (hogar_id, libro_casa_id), update (hogar_id, libro_casa_id) on public.ali_ajustes to authenticated;
grant insert (id, hogar_id, cuenta, ingrediente_id, cantidad, reservado), update (id, hogar_id, cuenta, ingrediente_id, cantidad, reservado)
  on public.ali_despensa to authenticated;
grant insert (id, hogar_id, cuenta, ingrediente_id, cantidad, comprador_id, para_el),
      update (id, hogar_id, cuenta, ingrediente_id, cantidad, comprador_id, para_el) on public.ali_compras to authenticated;

-- -----------------------------------------------------------------------------
-- 9. RPC: compras, precios, inventario y dinero
-- -----------------------------------------------------------------------------
-- Gasto en el libro (lo usan la marca de compra y la resolución de Papá). Interno.
create function public.ali7_registrar_gasto(
  p_hogar_id uuid, p_origen uuid, p_destino uuid, p_monto bigint, p_nota text, p_en_nombre_de uuid, p_motivo text)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id, monto_centavos,
                                      en_nombre_de, nota, motivo)
  values (v_id, p_hogar_id, 'gasto', (now() at time zone 'America/Mexico_City')::date, now(), p_origen, p_destino, p_monto,
          p_en_nombre_de, left(p_nota, 200), p_motivo);
  return v_id;
end
$$;

create function public.ali7_cuenta_gasto_por_omision(p_hogar_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select k.cuenta_gasto_id from public.fin_categorias k
  where k.hogar_id = p_hogar_id and k.nivel = 1 and k.es_del_sistema and k.nombre = 'Alimentación' and k.cuenta_gasto_id is not null
  limit 1
$$;

create function public.ali_marcar_comprada(
  p_compra uuid, p_monto_centavos bigint default null, p_cuenta_origen uuid default null, p_cuenta_gasto uuid default null)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_c       public.ali_compras%rowtype;
  v_ing     public.ali_ingredientes%rowtype;
  v_ajustes public.ali_ajustes%rowtype;
  v_libro   public.fin_libros%rowtype;
  v_origen_libro uuid;
  v_gasto   uuid;
  v_mov     uuid;
  v_sol     uuid;
  v_estado  text := 'sin_pago';
  v_unit    bigint;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_c from public.ali_compras c where c.id = p_compra for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'La compra no existe.';
  end if;
  if not public.ali_puede7(v_c.hogar_id, 'compras', v_c.cuenta, 'comprar') then
    raise exception using errcode = '42501', message = 'Tu cuenta no marca compras de esta lista.';
  end if;
  if v_c.comprado then
    raise exception using errcode = '22023', message = 'La compra ya está marcada.';
  end if;
  if p_monto_centavos is not null and p_monto_centavos <= 0 then
    raise exception using errcode = '22023', message = 'El monto va en centavos y es mayor que cero.';
  end if;
  if p_monto_centavos is null and (p_cuenta_origen is not null or p_cuenta_gasto is not null) then
    raise exception using errcode = '22023', message = 'Sin monto no hay movimiento: indica lo que pagaste.';
  end if;
  select * into v_ing from public.ali_ingredientes i where i.hogar_id = v_c.hogar_id and i.id = v_c.ingrediente_id;

  if p_monto_centavos is not null then
    v_gasto := coalesce(p_cuenta_gasto, public.ali7_cuenta_gasto_por_omision(v_c.hogar_id));
    if v_gasto is null or not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_c.hogar_id and c.id = v_gasto and c.clase = 'gasto') then
      raise exception using errcode = '22023', message = 'No hay una cuenta de gasto de Alimentación (indica p_cuenta_gasto).';
    end if;
    if v_c.cuenta = 'papa' and p_cuenta_origen is null then
      -- Compra de Papá sin cuenta de pago: queda como solicitud al albacea.
      v_estado := 'solicitud';
    else
      if p_cuenta_origen is null then
        raise exception using errcode = '22023', message = 'Falta la cuenta de pago (p_cuenta_origen).';
      end if;
      select l.* into v_libro from public.fin_cuentas c join public.fin_libros l on l.hogar_id = c.hogar_id and l.id = c.libro_id
       where c.hogar_id = v_c.hogar_id and c.id = p_cuenta_origen;
      if not found then
        raise exception using errcode = '23503', message = 'La cuenta de pago no existe en este hogar o no es de un libro.';
      end if;
      if v_c.cuenta in ('dueno', 'pareja') then
        if v_libro.tipo <> 'personal' or v_libro.titular_id is distinct from v_persona then
          raise exception using errcode = '42501', message = 'Tu compra sale de tu propio libro.';
        end if;
      elsif v_c.cuenta = 'casa' then
        select * into v_ajustes from public.ali_ajustes a where a.hogar_id = v_c.hogar_id;
        if v_ajustes.libro_casa_id is null then
          raise exception using errcode = '22023', message = 'El dueño aún no elige el libro compartido de las compras de la casa.',
            hint = 'ali_ajustes.libro_casa_id';
        end if;
        if v_libro.id <> v_ajustes.libro_casa_id then
          raise exception using errcode = '42501', message = 'Las compras de la casa salen del libro compartido que eligió el dueño.';
        end if;
      else
        -- Papá con cuenta: solo el albacea (quien escribe en el libro de Papá) la paga directo.
        if v_libro.id is distinct from public.ali_libro_papa(v_c.hogar_id) or not public.fin_puede(v_libro.id, 'escribir') then
          raise exception using errcode = '42501', message = 'Las compras de Papá las aprueba y paga el albacea.';
        end if;
      end if;
      v_mov := public.ali7_registrar_gasto(v_c.hogar_id, p_cuenta_origen, v_gasto, p_monto_centavos,
                 'Compra de la lista: ' || v_ing.nombre,
                 case when v_c.cuenta = 'papa' then v_libro.titular_id end,
                 case when v_c.cuenta = 'papa' then 'Compra de la lista de Alimentación' end);
      v_estado := 'movimiento';
    end if;

    -- El precio real reemplaza al base y se actualiza con cada compra (por unidad).
    v_unit := greatest(round(p_monto_centavos::numeric / v_c.cantidad)::bigint, 1);
    update public.ali_ingredientes set precio_real_centavos = v_unit, precio_real_en = now()
     where hogar_id = v_c.hogar_id and id = v_c.ingrediente_id;
    insert into public.ali_precios_historial (hogar_id, ingrediente_id, precio_centavos, compra_id, registrado_por)
    values (v_c.hogar_id, v_c.ingrediente_id, v_unit, v_c.id, v_persona);
  end if;

  -- El inventario de la cuenta sube con lo comprado.
  insert into public.ali_despensa (hogar_id, cuenta, ingrediente_id, cantidad)
  values (v_c.hogar_id, v_c.cuenta, v_c.ingrediente_id, v_c.cantidad)
  on conflict (hogar_id, cuenta, ingrediente_id) do update set cantidad = public.ali_despensa.cantidad + excluded.cantidad;

  update public.ali_compras
     set comprado = true, comprado_en = now(), comprado_por = v_persona, monto_centavos = p_monto_centavos,
         estado_pago = v_estado, movimiento_id = v_mov
   where id = v_c.id;
  if v_estado = 'solicitud' then
    insert into public.ali_solicitudes_pago (hogar_id, compra_id, monto_centavos) values (v_c.hogar_id, v_c.id, p_monto_centavos)
    returning id into v_sol;
  end if;
  return jsonb_build_object('estado_pago', v_estado, 'movimiento_id', v_mov, 'solicitud_id', v_sol, 'precio_real_centavos', v_unit);
end
$$;
comment on function public.ali_marcar_comprada(uuid, bigint, uuid, uuid) is
  'Marca una compra de la lista. Con p_monto_centavos (lo pagado en total): el precio real por unidad reemplaza al base del ingrediente, se anota en '
  'el historial, sube la despensa de la cuenta y se registra el gasto: dueno/pareja desde p_cuenta_origen de su libro personal; casa desde una cuenta del '
  'libro compartido de ali_ajustes; papa con p_cuenta_origen del libro de Papá solo si quien llama es el albacea, y sin ella queda una solicitud al albacea '
  '(estado_pago = solicitud). Sin monto solo marca y sube el inventario. p_cuenta_gasto: por omisión la de la categoría Alimentación. Devuelve estado_pago, movimiento_id, '
  'solicitud_id y precio_real_centavos.';

create function public.ali_resolver_solicitud_pago(
  p_solicitud uuid, p_aprobar boolean, p_cuenta_origen uuid default null, p_cuenta_gasto uuid default null, p_motivo text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_s       public.ali_solicitudes_pago%rowtype;
  v_c       public.ali_compras%rowtype;
  v_libro   uuid;
  v_titular uuid;
  v_gasto   uuid;
  v_mov     uuid;
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_s from public.ali_solicitudes_pago s where s.id = p_solicitud for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'La solicitud no existe.';
  end if;
  v_libro := public.ali_libro_papa(v_s.hogar_id);
  if v_libro is null or not public.fin_puede(v_libro, 'escribir') then
    raise exception using errcode = '42501', message = 'Solo el albacea resuelve las compras de Papá.';
  end if;
  if v_s.estado <> 'pendiente' then
    raise exception using errcode = '22023', message = 'La solicitud ya se resolvió.';
  end if;
  select * into v_c from public.ali_compras c where c.id = v_s.compra_id;
  if p_aprobar is null then
    raise exception using errcode = '22023', message = 'Indica si se aprueba.';
  end if;
  if p_aprobar then
    v_gasto := coalesce(p_cuenta_gasto, public.ali7_cuenta_gasto_por_omision(v_s.hogar_id));
    if v_gasto is null or not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_s.hogar_id and c.id = v_gasto and c.clase = 'gasto') then
      raise exception using errcode = '22023', message = 'No hay una cuenta de gasto de Alimentación (indica p_cuenta_gasto).';
    end if;
    if p_cuenta_origen is null or not exists (select 1 from public.fin_cuentas c where c.hogar_id = v_s.hogar_id and c.id = p_cuenta_origen and c.libro_id = v_libro) then
      raise exception using errcode = '22023', message = 'La cuenta de pago es una cuenta del libro de Papá.';
    end if;
    select l.titular_id into v_titular from public.fin_libros l where l.id = v_libro;
    v_mov := public.ali7_registrar_gasto(v_s.hogar_id, p_cuenta_origen, v_gasto, v_s.monto_centavos,
               'Compra de la lista de Papá', v_titular, 'Compra de la lista de Alimentación aprobada por el albacea');
    update public.ali_solicitudes_pago set estado = 'pagada', resuelta_por = v_persona, resuelta_en = now(), movimiento_id = v_mov where id = v_s.id;
    update public.ali_compras set estado_pago = 'movimiento', movimiento_id = v_mov where id = v_s.compra_id;
  else
    if not public.fin_motivo_valido(p_motivo) then
      raise exception using errcode = '23514', message = 'Rechazar una compra de Papá lleva un motivo.';
    end if;
    update public.ali_solicitudes_pago set estado = 'rechazada', resuelta_por = v_persona, resuelta_en = now(), motivo = left(p_motivo, 200) where id = v_s.id;
    update public.ali_compras set estado_pago = 'rechazada' where id = v_s.compra_id;
  end if;
  return v_mov;
end
$$;
comment on function public.ali_resolver_solicitud_pago(uuid, boolean, uuid, uuid, text) is
  'D19: el albacea aprueba (registra el gasto en el libro de Papá, en su nombre y con motivo; devuelve el movimiento) o rechaza (con motivo).';

create function public.ali_solicitar_compra(
  p_hogar_id uuid, p_cuenta text, p_ingrediente uuid, p_cantidad numeric, p_para_el date default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if public.ali_cuenta_de(p_hogar_id) not in ('dueno', 'pareja', 'familiar') then
    raise exception using errcode = '42501', message = 'Tu cuenta no solicita compras.';
  end if;
  if p_cuenta not in ('papa', 'casa') then
    raise exception using errcode = '22023', message = 'Se solicita para la despensa de Papá o la de la casa.';
  end if;
  insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad, para_el)
  values (p_hogar_id, p_cuenta, p_ingrediente, p_cantidad, p_para_el)
  returning id into v_id;
  return v_id;
end
$$;
comment on function public.ali_solicitar_compra(uuid, text, uuid, numeric, date) is
  'El familiar (y dueño o pareja) solicita un ingrediente para la despensa de Papá o de la casa. Queda en la lista; la marca quien compra.';

-- Sobrantes que pareja y dueño se comparten (D28): lo que no está reservado en la despensa del otro.
create function public.ali_sobrantes(p_hogar_id uuid, p_cuenta text)
returns table (ingrediente_id uuid, nombre text, unidad text, pasillo text, sobrante numeric)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_q text := public.ali_cuenta_de(p_hogar_id);
begin
  if not ((v_q = 'dueno' and p_cuenta = 'pareja') or (v_q = 'pareja' and p_cuenta = 'dueno')) then
    raise exception using errcode = '42501', message = 'Solo se ven los sobrantes de la otra cuenta (dueño y pareja).';
  end if;
  return query
    select d.ingrediente_id, i.nombre, i.unidad, i.pasillo, d.cantidad - d.reservado
      from public.ali_despensa d
      join public.ali_ingredientes i on i.hogar_id = d.hogar_id and i.id = d.ingrediente_id
     where d.hogar_id = p_hogar_id and d.cuenta = p_cuenta and d.cantidad > d.reservado
     order by i.pasillo, i.nombre;
end
$$;
comment on function public.ali_sobrantes(uuid, text) is
  'D28: lo que sobra (cantidad menos reservado) de la despensa del dueño (p_cuenta = dueno) o de la pareja (pareja), solo para la otra persona. Lo reservado no se comparte.';

-- Menú del día de Papá para Casa y para quien ve su menú: solo nombres de platillos, sin perfil clínico ni ingredientes (D3).
create function public.ali_menu_del_dia_papa(p_hogar_id uuid, p_fecha date default null)
returns table (tiempo text, platillo text)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_q   text := public.ali_cuenta_de(p_hogar_id);
  v_hoy date := (now() at time zone 'America/Mexico_City')::date;
  v_f   date;
begin
  if v_q is null or v_q not in ('dueno', 'pareja', 'familiar', 'cuidador', 'casa', 'maestra') then
    raise exception using errcode = '42501', message = 'Tu cuenta no ve el menú de Papá.';
  end if;
  v_f := case when v_q = 'casa' then v_hoy else coalesce(p_fecha, v_hoy) end;  -- Casa: solo el menú del día
  return query
    select m.tiempo, p.nombre
      from public.ali_menu m
      join public.ali_platillos p on p.hogar_id = m.hogar_id and p.id = m.platillo_id
     where m.hogar_id = p_hogar_id and m.menu = 'papa'
       and m.semana = v_f - (extract(isodow from v_f)::int - 1) and m.dia = extract(isodow from v_f)::int - 1
     order by array_position(array['desayuno', 'colacion', 'comida', 'cena'], m.tiempo);
end
$$;
comment on function public.ali_menu_del_dia_papa(uuid, date) is
  'D28: el menú de Papá de un día (tiempo y nombre del platillo). Casa solo recibe el de hoy (México); sin perfil clínico, ingredientes ni duros.';

-- -----------------------------------------------------------------------------
-- 10. RPC: plan familiar y votación
-- -----------------------------------------------------------------------------
create function public.ali7_agregar_opcion(
  p_votacion uuid, p_hogar_id uuid, p_orden smallint, p_titulo text, p_platillos uuid[])
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id uuid := gen_random_uuid();
  v_nombres text[];
begin
  if coalesce(cardinality(p_platillos), 0) not between 1 and 30 then
    raise exception using errcode = '22023', message = 'Una propuesta lleva de 1 a 30 platillos.';
  end if;
  select array_agg(p.nombre order by p.nombre) into v_nombres
    from public.ali_platillos p where p.hogar_id = p_hogar_id and p.id = any (p_platillos);
  if coalesce(cardinality(v_nombres), 0) <> (select count(distinct x) from unnest(p_platillos) x) then
    raise exception using errcode = '23503', message = 'Algún platillo no existe en este hogar.';
  end if;
  insert into public.ali_votacion_opciones (id, hogar_id, votacion_id, orden, propuesto_por, titulo, platillos)
  values (v_id, p_hogar_id, p_votacion, p_orden, public.persona_actual(), p_titulo, v_nombres);
  insert into public.ali_opcion_platillos (opcion_id, hogar_id, platillo_id)
  select v_id, p_hogar_id, x from (select distinct unnest(p_platillos) as x) q;
  return v_id;
end
$$;

create function public.ali_proponer_menu(
  p_hogar_id uuid, p_titulo text, p_platillos uuid[], p_cuenta text default 'casa', p_para_el date default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.ali_puede7(p_hogar_id, 'votaciones', null, 'proponer') then
    raise exception using errcode = '42501', message = 'Tu cuenta no propone menús familiares.';
  end if;
  if p_cuenta not in ('casa', 'papa') then
    raise exception using errcode = '22023', message = 'El plan es de la casa o de Papá.';
  end if;
  if char_length(btrim(coalesce(p_titulo, ''))) not between 1 and 120 then
    raise exception using errcode = '22023', message = 'El título lleva de 1 a 120 caracteres.';
  end if;
  perform public.ali_cerrar_votaciones(p_hogar_id);
  if exists (select 1 from public.ali_votaciones v where v.hogar_id = p_hogar_id and v.cuenta = p_cuenta and v.estado in ('abierta', 'empate')) then
    raise exception using errcode = '22023', message = 'Ya hay una votación abierta para este plan.';
  end if;
  insert into public.ali_votaciones (hogar_id, cuenta, titulo, para_el) values (p_hogar_id, p_cuenta, btrim(p_titulo), p_para_el)
  returning id into v_id;
  perform public.ali7_agregar_opcion(v_id, p_hogar_id, 1::smallint, btrim(p_titulo), p_platillos);
  return v_id;
end
$$;
comment on function public.ali_proponer_menu(uuid, text, uuid[], text, date) is
  'D28: alguien propone un menú (opción 1) y abre la votación, que dura un día. Una votación abierta por plan (casa o papa).';

create function public.ali_proponer_alternativa(p_votacion uuid, p_titulo text, p_platillos uuid[])
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_v public.ali_votaciones%rowtype;
begin
  select * into v_v from public.ali_votaciones v where v.id = p_votacion for update;
  if not found or not public.ali_puede7(v_v.hogar_id, 'votaciones', null, 'proponer') then
    raise exception using errcode = '42501', message = 'No puedes proponer en esa votación.';
  end if;
  perform public.ali_cerrar_votaciones(v_v.hogar_id);
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if v_v.estado <> 'abierta' then
    raise exception using errcode = '22023', message = 'La votación ya no admite otra propuesta.';
  end if;
  if exists (select 1 from public.ali_votacion_opciones o where o.votacion_id = p_votacion and o.propuesto_por = public.persona_actual()) then
    raise exception using errcode = '22023', message = 'La propuesta alternativa la da otra persona.';
  end if;
  if exists (select 1 from public.ali_votacion_opciones o where o.votacion_id = p_votacion and o.orden = 2) then
    raise exception using errcode = '23505', message = 'La votación ya tiene su propuesta alternativa.';
  end if;
  if char_length(btrim(coalesce(p_titulo, ''))) not between 1 and 120 then
    raise exception using errcode = '22023', message = 'El título lleva de 1 a 120 caracteres.';
  end if;
  return public.ali7_agregar_opcion(p_votacion, v_v.hogar_id, 2::smallint, btrim(p_titulo), p_platillos);
end
$$;
comment on function public.ali_proponer_alternativa(uuid, text, uuid[]) is 'D28: otra persona (no quien propuso) da la propuesta alternativa mientras la votación esté abierta.';

create function public.ali_votar(p_votacion uuid, p_opcion uuid)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_v public.ali_votaciones%rowtype;
  v_persona uuid := public.persona_actual();
begin
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if not found or not public.ali_puede7(v_v.hogar_id, 'votaciones', null, 'votar') then
    raise exception using errcode = '42501', message = 'Tu cuenta no vota en esta votación.';
  end if;
  perform public.ali_cerrar_votaciones(v_v.hogar_id);
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if v_v.estado = 'cerrada' then
    raise exception using errcode = '22023', message = 'La votación ya cerró.';
  end if;
  if not exists (select 1 from public.ali_votacion_opciones o where o.votacion_id = p_votacion and o.id = p_opcion) then
    raise exception using errcode = '23503', message = 'Esa opción no es de esta votación.';
  end if;
  insert into public.ali_votos (votacion_id, hogar_id, persona_id, opcion_id) values (p_votacion, v_v.hogar_id, v_persona, p_opcion)
  on conflict (votacion_id, persona_id) do update
    set opcion_id = excluded.opcion_id, votado_en = now(), cambios = public.ali_votos.cambios + 1
    where public.ali_votos.opcion_id <> excluded.opcion_id;
  return v_v.estado;
end
$$;
comment on function public.ali_votar(uuid, uuid) is
  'D28: vota o cambia el voto mientras la votación esté abierta o en empate. Devuelve el estado. Cerrada: 22023.';

-- Cierra las votaciones vencidas: gana la opción con más votos; una sola opción gana sin votos; si hay empate la votación pasa a
-- "empate" un día más (ronda +1) para que cada quien pueda cambiar su voto. Lo llama el servidor a diario y la app al abrir el plan.
create function public.ali_cerrar_votaciones(p_hogar_id uuid default null)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_v   public.ali_votaciones%rowtype;
  v_n   integer := 0;
  v_ops integer;
  v_top uuid;
  v_cuantas integer;
begin
  if auth.uid() is not null and (p_hogar_id is null or public.ali_cuenta_de(p_hogar_id) is null) then
    raise exception using errcode = '42501', message = 'Indica un hogar al que perteneces.';
  end if;
  for v_v in
    select * from public.ali_votaciones v
     where v.estado in ('abierta', 'empate') and v.cierra_en <= now() and (p_hogar_id is null or v.hogar_id = p_hogar_id)
     for update
  loop
    select count(*) into v_ops from public.ali_votacion_opciones o where o.votacion_id = v_v.id;
    if v_ops = 0 then
      continue;
    end if;
    with c as (
      select o.id, o.orden, count(vt.persona_id) as n
        from public.ali_votacion_opciones o left join public.ali_votos vt on vt.opcion_id = o.id
       where o.votacion_id = v_v.id group by o.id, o.orden)
    select (select c1.id from c c1 order by c1.n desc, c1.orden limit 1),
           (select count(*) from c c2 where c2.n = (select max(c3.n) from c c3))
      into v_top, v_cuantas;
    if v_ops = 1 or v_cuantas = 1 then
      update public.ali_votaciones set estado = 'cerrada', ganadora_id = v_top, cerrada_en = now() where id = v_v.id;
    else
      update public.ali_votaciones set estado = 'empate', ronda = ronda + 1, cierra_en = now() + interval '1 day' where id = v_v.id;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;
comment on function public.ali_cerrar_votaciones(uuid) is
  'D28: cierra las votaciones vencidas del hogar (o de todos, solo el servidor) y devuelve cuántas movió. Empate: sigue abierta un día más, cada quien puede cambiar su voto.';

-- Qué le falta a la despensa del plan para el menú ganador.
create function public.ali_faltantes(p_votacion uuid)
returns table (ingrediente_id uuid, nombre text, unidad text, pasillo text, necesario numeric, disponible numeric, faltante numeric)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_v public.ali_votaciones%rowtype;
  v_ve boolean;
begin
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if not found or not public.ali_puede7(v_v.hogar_id, 'votaciones', null, 'leer') or public.ali_cuenta_de(v_v.hogar_id) = 'casa' then
    raise exception using errcode = '42501', message = 'Tu cuenta no evalúa faltantes.';
  end if;
  if v_v.estado <> 'cerrada' then
    raise exception using errcode = '22023', message = 'La votación aún no tiene ganadora.';
  end if;
  v_ve := public.ali_puede7(v_v.hogar_id, 'despensa', v_v.cuenta, 'leer');
  return query
    select i.id, i.nombre, i.unidad, i.pasillo, q.necesario,
           case when v_ve then coalesce(d.cantidad, 0) end,
           greatest(q.necesario - coalesce(d.cantidad, 0), 0)
      from (select pi.ingrediente_id, sum(pi.cantidad) as necesario
              from public.ali_opcion_platillos op
              join public.ali_platillo_ingredientes pi on pi.hogar_id = op.hogar_id and pi.platillo_id = op.platillo_id
             where op.opcion_id = v_v.ganadora_id group by pi.ingrediente_id) q
      join public.ali_ingredientes i on i.hogar_id = v_v.hogar_id and i.id = q.ingrediente_id
      left join public.ali_despensa d on d.hogar_id = v_v.hogar_id and d.cuenta = v_v.cuenta and d.ingrediente_id = q.ingrediente_id
     order by i.pasillo, i.nombre;
end
$$;
comment on function public.ali_faltantes(uuid) is
  'D28: ingredientes del menú ganador, lo necesario y lo que falta en la despensa del plan (casa o papa). disponible es nulo si tu cuenta no ve esa despensa.';

create function public.ali_pedir_compra_faltantes(p_votacion uuid, p_ingredientes uuid[] default null)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_v public.ali_votaciones%rowtype;
  v_persona uuid := public.persona_actual();
  v_n integer;
begin
  select * into v_v from public.ali_votaciones v where v.id = p_votacion;
  if not found or v_v.estado <> 'cerrada' then
    raise exception using errcode = '22023', message = 'La votación no tiene ganadora.';
  end if;
  if not (public.ali_cuenta_de(v_v.hogar_id) in ('dueno', 'pareja')
          or exists (select 1 from public.ali_votacion_opciones o where o.id = v_v.ganadora_id and o.propuesto_por = v_persona)) then
    raise exception using errcode = '42501', message = 'Pide la compra quien propuso el menú ganador (o el dueño y la pareja).';
  end if;
  insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad, para_el, votacion_id)
  select v_v.hogar_id, v_v.cuenta, f.ingrediente_id, f.faltante, v_v.para_el, v_v.id
    from public.ali_faltantes(p_votacion) f
   where f.faltante > 0 and (p_ingredientes is null or f.ingrediente_id = any (p_ingredientes))
  on conflict (votacion_id, ingrediente_id) where votacion_id is not null do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;
comment on function public.ali_pedir_compra_faltantes(uuid, uuid[]) is
  'D28: quien propuso el menú ganador pide a la lista de compras los faltantes (todos o los que indique). Devuelve cuántos agregó; no repite lo ya pedido.';

-- -----------------------------------------------------------------------------
-- 11. RPC: suplementos de Papá (D28)
-- -----------------------------------------------------------------------------
create function public.ali_programar_toma(p_suplemento uuid, p_prevista timestamptz)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_s public.ali_suplementos%rowtype;
  v_id uuid;
begin
  select * into v_s from public.ali_suplementos s where s.id = p_suplemento;
  if not found or not public.ali_puede7(v_s.hogar_id, 'tomas', null, 'escribir') then
    raise exception using errcode = '42501', message = 'Tu cuenta no programa tomas.';
  end if;
  insert into public.ali_tomas_suplemento (hogar_id, suplemento_id, nombre, prevista_en)
  values (v_s.hogar_id, v_s.id, v_s.nombre, p_prevista)
  on conflict (suplemento_id, prevista_en) do update set nombre = excluded.nombre
  returning id into v_id;
  return v_id;
end
$$;

create function public.ali_confirmar_toma(p_toma uuid, p_dado boolean)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_t public.ali_tomas_suplemento%rowtype;
begin
  if p_dado is null then
    raise exception using errcode = '22023', message = 'Indica si se dio o no.';
  end if;
  select * into v_t from public.ali_tomas_suplemento t where t.id = p_toma for update;
  if not found or not public.ali_puede7(v_t.hogar_id, 'tomas', null, 'confirmar') then
    raise exception using errcode = '42501', message = 'Tu cuenta no confirma tomas.';
  end if;
  if v_t.estado in ('dado', 'no_dado') then
    raise exception using errcode = '22023', message = 'La toma ya está confirmada.';
  end if;
  update public.ali_tomas_suplemento
     set estado = case when p_dado then 'dado' else 'no_dado' end, confirmado_por = public.persona_actual(), confirmado_en = now()
   where id = p_toma;
  return case when p_dado then 'dado' else 'no_dado' end;
end
$$;
comment on function public.ali_confirmar_toma(uuid, boolean) is
  'D28: quien dio (o no) el suplemento lo confirma, una sola vez. Dueño, pareja, familiar y cuidadora; Casa solo ve. Devuelve dado o no_dado.';

-- Las tomas sin confirmar pasado el plazo pasan a sin_confirmar y piden la reposición del suplemento.
create function public.ali_revisar_tomas(p_hogar_id uuid default null, p_gracia interval default interval '2 hours')
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_t public.ali_tomas_suplemento%rowtype;
  v_n integer := 0;
begin
  if auth.uid() is not null and (p_hogar_id is null or not public.ali_puede7(p_hogar_id, 'tomas', null, 'confirmar')) then
    raise exception using errcode = '42501', message = 'Tu cuenta no revisa tomas.';
  end if;
  for v_t in
    select * from public.ali_tomas_suplemento t
     where t.estado = 'pendiente' and t.prevista_en + p_gracia <= now() and (p_hogar_id is null or t.hogar_id = p_hogar_id)
     for update
  loop
    update public.ali_tomas_suplemento set estado = 'sin_confirmar' where id = v_t.id;
    insert into public.ali_reposiciones_suplemento (hogar_id, suplemento_id, toma_id) values (v_t.hogar_id, v_t.suplemento_id, v_t.id)
    on conflict (suplemento_id) where estado = 'pendiente' do nothing;
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;
comment on function public.ali_revisar_tomas(uuid, interval) is
  'D28: si nadie confirma una toma en p_gracia (2 horas), queda sin_confirmar y se solicita la reposición (una pendiente por suplemento). Devuelve cuántas tomas movió.';

create function public.ali_resolver_reposicion(p_reposicion uuid, p_atendida boolean)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_r public.ali_reposiciones_suplemento%rowtype;
begin
  select * into v_r from public.ali_reposiciones_suplemento r where r.id = p_reposicion for update;
  if not found or not public.ali_puede7(v_r.hogar_id, 'reposiciones', null, 'escribir') then
    raise exception using errcode = '42501', message = 'Tu cuenta no resuelve reposiciones.';
  end if;
  if v_r.estado <> 'pendiente' or p_atendida is null then
    raise exception using errcode = '22023', message = 'La reposición ya se resolvió.';
  end if;
  update public.ali_reposiciones_suplemento
     set estado = case when p_atendida then 'atendida' else 'descartada' end, resuelta_por = public.persona_actual(), resuelta_en = now()
   where id = p_reposicion;
end
$$;

-- -----------------------------------------------------------------------------
-- 12. Privilegios de las funciones
-- -----------------------------------------------------------------------------
revoke execute on function
  public.ali_cuenta_de(uuid), public.ali_puede7(uuid, text, text, text), public.ali7_propio(), public.ali_ajustes_validar(),
  public.ali_compras_guardia(), public.ali_tomas_validar(), public.ali7_cuota_filas(), public.ali_libro_papa(uuid),
  public.ali_ve_solicitud(uuid, uuid), public.ali7_registrar_gasto(uuid, uuid, uuid, bigint, text, uuid, text),
  public.ali7_cuenta_gasto_por_omision(uuid), public.ali_marcar_comprada(uuid, bigint, uuid, uuid),
  public.ali_resolver_solicitud_pago(uuid, boolean, uuid, uuid, text), public.ali_solicitar_compra(uuid, text, uuid, numeric, date),
  public.ali_sobrantes(uuid, text), public.ali_menu_del_dia_papa(uuid, date),
  public.ali7_agregar_opcion(uuid, uuid, smallint, text, uuid[]), public.ali_proponer_menu(uuid, text, uuid[], text, date),
  public.ali_proponer_alternativa(uuid, text, uuid[]), public.ali_votar(uuid, uuid), public.ali_cerrar_votaciones(uuid),
  public.ali_faltantes(uuid), public.ali_pedir_compra_faltantes(uuid, uuid[]), public.ali_programar_toma(uuid, timestamptz),
  public.ali_confirmar_toma(uuid, boolean), public.ali_revisar_tomas(uuid, interval), public.ali_resolver_reposicion(uuid, boolean)
  from public, anon, authenticated, service_role;
-- Las usan las reglas por registro o la app.
grant execute on function
  public.ali_cuenta_de(uuid), public.ali_puede7(uuid, text, text, text), public.ali_libro_papa(uuid), public.ali_ve_solicitud(uuid, uuid),
  public.ali_marcar_comprada(uuid, bigint, uuid, uuid), public.ali_resolver_solicitud_pago(uuid, boolean, uuid, uuid, text),
  public.ali_solicitar_compra(uuid, text, uuid, numeric, date), public.ali_sobrantes(uuid, text), public.ali_menu_del_dia_papa(uuid, date),
  public.ali_proponer_menu(uuid, text, uuid[], text, date), public.ali_proponer_alternativa(uuid, text, uuid[]), public.ali_votar(uuid, uuid),
  public.ali_cerrar_votaciones(uuid), public.ali_faltantes(uuid), public.ali_pedir_compra_faltantes(uuid, uuid[]),
  public.ali_programar_toma(uuid, timestamptz), public.ali_confirmar_toma(uuid, boolean), public.ali_revisar_tomas(uuid, interval),
  public.ali_resolver_reposicion(uuid, boolean)
  to authenticated;
-- El servidor (cierre diario de votaciones y revisión de tomas).
grant execute on function public.ali_cuenta_de(uuid), public.ali_puede7(uuid, text, text, text), public.ali_cerrar_votaciones(uuid),
  public.ali_revisar_tomas(uuid, interval) to service_role;
