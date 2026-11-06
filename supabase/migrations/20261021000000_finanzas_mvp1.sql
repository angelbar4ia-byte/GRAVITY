-- =============================================================================
-- GRAVITY · Fase 1 · Finanzas MVP 1
-- =============================================================================
-- docs/specs/fase-1-finanzas.md v0.2 (secciones 4.1 a 4.5) y D18, D19:
--   * Libros (D19): cada persona adulta con Finanzas tiene su libro personal;
--     hay libros compartidos ("Gastos de la casa") y el libro representado de
--     papá, que llevan sus albaceas (1 albacea y, opcional, 1 suplente).
--   * Cuenta maestra (D19): una por hogar, la asigna el dueño; solo LEE todo
--     (Finanzas y el historial de GRAVITY) y nunca escribe en lo ajeno.
--   * Tablas fin_*: configuración, plan semanal, libro de movimientos SOLO
--     AGREGAR (con anulación y contraasiento), cierres, conciliaciones e
--     importaciones. Categorías y cuentas de gasto son del HOGAR (árbol común).
--   * Matriz (D18, D19): dueño y coadministrador con alcance PROPIO en Finanzas;
--     dueño con alcance propio en GRAVITY; cuidador con GRAVITY restringido.
--   * Se borra finanzas_muestra (muestra de la Fase 0).
--
-- Reglas de RLS: fin_puede(libro_id, accion) para lo que es de un libro y
-- fin_puede_hogar(hogar_id, accion) para lo que es del hogar (categorías,
-- cuentas de gasto, días inhábiles e importaciones).
--
-- Idempotencia (cola sin conexión): insertar dos veces el mismo id con el
-- mismo contenido NO hace nada y no falla (también con ON CONFLICT DO
-- NOTHING); el mismo id con otro contenido falla con 23505 en los libros
-- solo-agregar. Ver supabase/README.md, "Contrato para la app".
--
-- Compatible con PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. La muestra de la Fase 0 se va (su trigger y sus reglas se van con ella)
-- -----------------------------------------------------------------------------
drop table public.finanzas_muestra;

-- -----------------------------------------------------------------------------
-- 1. Tipos comunes de Finanzas
-- -----------------------------------------------------------------------------
create domain public.fin_prioridad as text
  check (value in ('necesario', 'deseable', 'discrecional'));
create domain public.fin_regla_inhabil as text
  check (value in ('siguiente_dia_habil', 'dia_habil_anterior', 'sin_cambio'));
comment on domain public.fin_regla_inhabil is
  'Qué hacer si un pago cae en sábado, domingo o día inhábil (decisión 44; D19 regla 5).';
create domain public.fin_forma_pago as text
  check (value in ('semanal', 'catorcenal', 'quincenal', 'mensual', 'cada_meses'));
comment on domain public.fin_forma_pago is
  'Calendario: semanal (dia_semana), catorcenal (fecha_ancla), quincenal (2 dias_mes), '
  'mensual (1 o más dias_mes, p. ej. {1,11}) o cada_meses (fecha_ancla + intervalo_meses).';
create domain public.fin_frecuencia as text
  check (value in ('semanal', 'catorcenal', 'quincenal', 'mensual', 'bimestral',
                   'trimestral', 'semestral', 'anual', 'diaria'));
create domain public.fin_modo_arrastre as text
  check (value in ('arrastrar', 'al_remanente'));

-- -----------------------------------------------------------------------------
-- 2. Libros (D19, sección 4.5)
-- -----------------------------------------------------------------------------
create table public.fin_libros (
  id          uuid primary key default gen_random_uuid(),
  hogar_id    uuid not null references public.hogares (id),
  nombre      text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo        text not null check (tipo in ('personal', 'compartido', 'representado')),
  titular_id  uuid references public.personas (id),
  activo      boolean not null default true,
  creado_por  uuid default public.persona_actual() references public.personas (id),
  creado_en   timestamptz not null default now(),
  constraint fin_libros_titular check ((tipo = 'compartido') = (titular_id is null)),
  constraint fin_libros_hogar_id_key unique (hogar_id, id)
);
create unique index fin_libros_un_personal_por_persona
  on public.fin_libros (hogar_id, titular_id) where tipo = 'personal';
create unique index fin_libros_un_representado_por_persona
  on public.fin_libros (hogar_id, titular_id) where tipo = 'representado';
comment on table public.fin_libros is
  'Libro de Finanzas (D19): personal (de una persona con Finanzas; se crea solo al darle el rol), '
  'compartido (p. ej. "Gastos de la casa"; 2 o más adultos) o representado (el de papá, sin cuenta; '
  'lo llevan sus albaceas). Se crea el representado con fin_crear_libro_representado().';
comment on column public.fin_libros.titular_id is
  'Persona dueña del libro: obligatoria en personal y representado; nula en compartido.';

create table public.fin_libro_miembros (
  id          uuid primary key default gen_random_uuid(),
  hogar_id    uuid not null references public.hogares (id),
  libro_id    uuid not null,
  persona_id  uuid not null references public.personas (id),
  papel       text not null check (papel in ('titular', 'miembro', 'albacea', 'albacea_suplente')),
  desde       timestamptz not null default now(),
  hasta       timestamptz,
  constraint fin_libro_miembros_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_libro_miembros_hasta check (hasta is null or hasta >= desde)
);
create unique index fin_libro_miembros_uno_vigente
  on public.fin_libro_miembros (libro_id, persona_id) where hasta is null;
create unique index fin_libro_miembros_un_albacea
  on public.fin_libro_miembros (libro_id) where papel = 'albacea' and hasta is null;
create unique index fin_libro_miembros_un_suplente
  on public.fin_libro_miembros (libro_id) where papel = 'albacea_suplente' and hasta is null;
create index fin_libro_miembros_persona_idx on public.fin_libro_miembros (persona_id);
comment on table public.fin_libro_miembros is
  'Quién lleva cada libro. personal: solo su titular. compartido: miembros adultos. representado: '
  '1 albacea y, opcional, 1 albacea_suplente (que escribe solo si no hay albacea vigente). '
  'No se borran: se cierra hasta.';

-- -----------------------------------------------------------------------------
-- 3. Categorías y cuentas
-- -----------------------------------------------------------------------------
create table public.fin_categorias (
  id                     uuid primary key default gen_random_uuid(),
  hogar_id               uuid not null references public.hogares (id),
  padre_id               uuid,
  nivel                  smallint not null check (nivel between 1 and 3),
  nombre                 text not null check (char_length(btrim(nombre)) between 1 and 80),
  icono                  text check (char_length(icono) <= 64),
  color                  text check (char_length(color) <= 32),
  naturaleza             text check (char_length(naturaleza) <= 40),
  prioridad              public.fin_prioridad not null default 'necesario',
  protegida              boolean not null default false,
  es_del_sistema         boolean not null default false,
  oculta                 boolean not null default false,
  archivada              boolean not null default false,
  posiblemente_deducible boolean not null default false,
  cuenta_gasto_id        uuid,
  constraint fin_categorias_hogar_id_key unique (hogar_id, id),
  constraint fin_categorias_nombre_unico unique nulls not distinct (hogar_id, padre_id, nombre),
  constraint fin_categorias_padre_fk foreign key (hogar_id, padre_id)
    references public.fin_categorias (hogar_id, id) on delete restrict,
  constraint fin_categorias_nivel_padre check ((nivel = 1) = (padre_id is null))
);
comment on table public.fin_categorias is
  'Árbol de categorías del HOGAR (3 niveles, común a todos los libros). Se borra solo sin datos '
  '(llaves foráneas restrict); con datos se archiva (archivada).';

create table public.fin_cuentas (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid,
  nombre          text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo            text not null check (tipo in (
                    'efectivo', 'banco', 'ahorro', 'inversion', 'por_cobrar', 'tarjeta', 'prestamo',
                    'origen_ingreso', 'de_gasto', 'gasto_financiero', 'por_clasificar', 'ajustes', 'apertura')),
  clase           text generated always as (
                    case
                      when tipo in ('efectivo', 'banco', 'ahorro', 'inversion', 'por_cobrar') then 'activo'
                      when tipo in ('tarjeta', 'prestamo') then 'pasivo'
                      when tipo = 'origen_ingreso' then 'ingreso'
                      when tipo in ('de_gasto', 'gasto_financiero', 'por_clasificar') then 'gasto'
                      when tipo = 'ajustes' then 'ajuste'
                      else 'apertura'
                    end) stored,
  liquida         boolean generated always as (tipo in ('efectivo', 'banco')) stored,
  estado          text not null default 'activa'
                  check (estado in ('activa', 'congelada', 'cerrada', 'archivada')),
  categoria_id    uuid,
  limite_centavos bigint,
  creada_por      uuid default public.persona_actual() references public.personas (id),
  creada_en       timestamptz not null default now(),
  constraint fin_cuentas_hogar_id_key unique (hogar_id, id),
  constraint fin_cuentas_libro_id_key unique (libro_id, id),
  constraint fin_cuentas_nombre_unico unique nulls not distinct (hogar_id, libro_id, nombre),
  constraint fin_cuentas_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_cuentas_categoria_fk foreign key (hogar_id, categoria_id)
    references public.fin_categorias (hogar_id, id) on delete restrict,
  constraint fin_cuentas_gasto_es_del_hogar
    check ((tipo in ('de_gasto', 'gasto_financiero')) = (libro_id is null)),
  constraint fin_cuentas_categoria_solo_en_gasto
    check (categoria_id is null or tipo in ('de_gasto', 'gasto_financiero')),
  constraint fin_cuentas_limite
    check (limite_centavos is null or (limite_centavos > 0 and tipo = 'tarjeta'))
);
create unique index fin_cuentas_una_de_sistema_por_libro
  on public.fin_cuentas (libro_id, tipo) where tipo in ('ajustes', 'apertura', 'por_clasificar');
comment on table public.fin_cuentas is
  'Cuentas. Las de gasto por rubro (de_gasto, gasto_financiero) son del HOGAR (libro_id nulo); todas '
  'las demás son de un libro. Cada libro tiene sus cuentas de sistema Ajustes, Apertura y Por '
  'clasificar (se crean solas). Cerrar o archivar solo con saldo cero; borrar solo sin movimientos.';
comment on column public.fin_cuentas.clase is 'Generada desde tipo: activo, pasivo, ingreso, gasto, ajuste o apertura.';
comment on column public.fin_cuentas.liquida is 'Generada: efectivo y banco entran al "disponible".';

alter table public.fin_categorias
  add constraint fin_categorias_cuenta_gasto_fk foreign key (hogar_id, cuenta_gasto_id)
    references public.fin_cuentas (hogar_id, id) on delete restrict;

-- -----------------------------------------------------------------------------
-- 4. Parámetros por libro
-- -----------------------------------------------------------------------------
create table public.fin_parametros (
  libro_id                   uuid primary key,
  hogar_id                   uuid not null references public.hogares (id),
  meta_remanente_pb          integer  not null default 2000 check (meta_remanente_pb between 0 and 10000),
  ahorro_minimo_con_deuda_pb integer  not null default 0 check (ahorro_minimo_con_deuda_pb between 0 and 10000),
  tope_arrastre_semanas      smallint not null default 2 check (tope_arrastre_semanas between 0 and 52),
  partida_ambar_pb           integer  not null default 8000,
  partida_rojo_pb            integer  not null default 10000,
  remanente_verde_pb         integer  not null default 2000,
  remanente_ambar_pb         integer  not null default 1000,
  carga_ambar_pb             integer  not null default 2000,
  carga_rojo_pb              integer  not null default 3500,
  cumplimiento_verde_pb      integer  not null default 9000,
  cumplimiento_ambar_pb      integer  not null default 7000,
  cierre_automatico_dias     smallint not null default 3 check (cierre_automatico_dias between 1 and 30),
  cuenta_ajustes_id          uuid not null,
  cuenta_apertura_id         uuid not null,
  cuenta_por_clasificar_id   uuid not null,
  constraint fin_parametros_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_parametros_ajustes_fk foreign key (libro_id, cuenta_ajustes_id)
    references public.fin_cuentas (libro_id, id),
  constraint fin_parametros_apertura_fk foreign key (libro_id, cuenta_apertura_id)
    references public.fin_cuentas (libro_id, id),
  constraint fin_parametros_por_clasificar_fk foreign key (libro_id, cuenta_por_clasificar_id)
    references public.fin_cuentas (libro_id, id),
  constraint fin_parametros_partida check (0 <= partida_ambar_pb and partida_ambar_pb <= partida_rojo_pb and partida_rojo_pb <= 100000),
  constraint fin_parametros_remanente check (0 <= remanente_ambar_pb and remanente_ambar_pb <= remanente_verde_pb and remanente_verde_pb <= 10000),
  constraint fin_parametros_carga check (0 <= carga_ambar_pb and carga_ambar_pb <= carga_rojo_pb and carga_rojo_pb <= 100000),
  constraint fin_parametros_cumplimiento check (0 <= cumplimiento_ambar_pb and cumplimiento_ambar_pb <= cumplimiento_verde_pb and cumplimiento_verde_pb <= 10000)
);
comment on table public.fin_parametros is
  'Parámetros de Finanzas de cada libro (una fila por libro; se crea sola con los valores por defecto '
  'de 5.6 bis y 5.9 bis). Porcentajes en puntos base (2000 = 20 %). Se cambian con UPDATE (no insert).';

-- -----------------------------------------------------------------------------
-- 5. Libro de movimientos (SOLO AGREGAR)
-- -----------------------------------------------------------------------------
create table public.fin_movimientos (
  id                uuid primary key default gen_random_uuid(),
  hogar_id          uuid not null references public.hogares (id),
  tipo              text not null check (tipo in ('apertura', 'ingreso', 'gasto', 'reembolso', 'transferencia',
                                                  'pago_deuda', 'reclasificacion', 'ajuste', 'anulacion')),
  fecha             date not null,
  registrado_en     timestamptz not null,
  recibido_en       timestamptz not null default now(),
  cuenta_origen_id  uuid not null,
  cuenta_destino_id uuid not null,
  libro_origen_id   uuid,
  libro_destino_id  uuid,
  monto_centavos    bigint not null check (monto_centavos > 0),
  categoria_id      uuid,
  grupo_id          uuid,
  realizado_por     uuid not null default public.persona_actual() references public.personas (id),
  registrado_por    uuid not null default public.persona_actual() references public.personas (id),
  en_nombre_de      uuid references public.personas (id),
  via               text not null default 'manual'
                    check (via in ('manual', 'voz', 'imagen', 'qr', 'importacion')),
  nota              text check (char_length(nota) <= 200),
  motivo            text check (char_length(motivo) <= 200),
  anula_a           uuid,
  estado_inicial    text not null default 'confirmado' check (estado_inicial in ('confirmado', 'pendiente')),
  constraint fin_movimientos_hogar_id_key unique (hogar_id, id),
  constraint fin_movimientos_origen_fk foreign key (hogar_id, cuenta_origen_id)
    references public.fin_cuentas (hogar_id, id),
  constraint fin_movimientos_destino_fk foreign key (hogar_id, cuenta_destino_id)
    references public.fin_cuentas (hogar_id, id),
  constraint fin_movimientos_libro_origen_fk foreign key (hogar_id, libro_origen_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_movimientos_libro_destino_fk foreign key (hogar_id, libro_destino_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_movimientos_categoria_fk foreign key (hogar_id, categoria_id)
    references public.fin_categorias (hogar_id, id),
  constraint fin_movimientos_anula_fk foreign key (hogar_id, anula_a)
    references public.fin_movimientos (hogar_id, id),
  constraint fin_movimientos_origen_distinto check (cuenta_origen_id <> cuenta_destino_id),
  constraint fin_movimientos_motivo_obligatorio
    check (tipo not in ('ajuste', 'anulacion') or nullif(btrim(motivo), '') is not null),
  constraint fin_movimientos_anula_solo_en_anulacion check ((tipo = 'anulacion') = (anula_a is not null)),
  constraint fin_movimientos_en_nombre_de_con_motivo
    check (en_nombre_de is null or nullif(btrim(motivo), '') is not null),
  constraint fin_movimientos_con_libro check (libro_origen_id is not null or libro_destino_id is not null)
);
create unique index fin_movimientos_una_anulacion on public.fin_movimientos (anula_a) where anula_a is not null;
create index fin_movimientos_hogar_fecha_idx on public.fin_movimientos (hogar_id, fecha);
create index fin_movimientos_origen_idx on public.fin_movimientos (cuenta_origen_id);
create index fin_movimientos_destino_idx on public.fin_movimientos (cuenta_destino_id);
create index fin_movimientos_libro_origen_idx on public.fin_movimientos (libro_origen_id, fecha);
create index fin_movimientos_libro_destino_idx on public.fin_movimientos (libro_destino_id, fecha);
create index fin_movimientos_grupo_idx on public.fin_movimientos (grupo_id) where grupo_id is not null;
comment on table public.fin_movimientos is
  'Libro de movimientos SOLO AGREGAR con partida doble simplificada (sección 4.3). No se edita ni se '
  'borra: se corrige con una anulación (contraasiento). Un movimiento entre libros (aportación a un '
  'compartido) se ve desde los dos.';
comment on column public.fin_movimientos.registrado_en is 'Cuándo se capturó (lo manda el dispositivo; obligatorio).';
comment on column public.fin_movimientos.recibido_en is 'Cuándo llegó al servidor; lo pone el servidor.';
comment on column public.fin_movimientos.libro_origen_id is 'Libro de la cuenta de origen; lo pone el servidor (nulo en cuentas de gasto del hogar).';
comment on column public.fin_movimientos.libro_destino_id is 'Libro de la cuenta de destino; lo pone el servidor (nulo en cuentas de gasto del hogar).';
comment on column public.fin_movimientos.en_nombre_de is
  'Persona representada (papá) cuando un albacea registra en su nombre; motivo obligatorio (D19).';

-- -----------------------------------------------------------------------------
-- 6. Ingresos, compromisos, sobres y deudas (configuración de cada libro)
-- -----------------------------------------------------------------------------
create table public.fin_ingresos (
  id                uuid primary key default gen_random_uuid(),
  hogar_id          uuid not null references public.hogares (id),
  libro_id          uuid not null,
  persona_id        uuid not null references public.personas (id),
  nombre            text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo              text not null default 'salario'
                    check (tipo in ('salario', 'independiente', 'prestaciones', 'pension', 'otro')),
  cuenta_origen_id  uuid,
  cuenta_destino_id uuid,
  certeza           text not null default 'segura' check (certeza in ('segura', 'probable', 'incierta')),
  activo            boolean not null default true,
  constraint fin_ingresos_libro_id_key unique (libro_id, id),
  constraint fin_ingresos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_ingresos_origen_fk foreign key (libro_id, cuenta_origen_id) references public.fin_cuentas (libro_id, id),
  constraint fin_ingresos_destino_fk foreign key (libro_id, cuenta_destino_id) references public.fin_cuentas (libro_id, id)
);
comment on table public.fin_ingresos is
  'Ingresos recurrentes de un libro (por persona). Los extras no se configuran: son movimientos ingreso.';

create table public.fin_vigencias_ingreso (
  id                  uuid primary key default gen_random_uuid(),
  hogar_id            uuid not null references public.hogares (id),
  libro_id            uuid not null,
  ingreso_id          uuid not null,
  monto_neto_centavos bigint not null check (monto_neto_centavos > 0),
  forma               public.fin_forma_pago not null,
  dia_semana          smallint check (dia_semana between 1 and 7),
  dias_mes            smallint[],
  fecha_ancla         date,
  intervalo_meses     smallint check (intervalo_meses between 1 and 12),
  regla_inhabil       public.fin_regla_inhabil not null default 'siguiente_dia_habil',
  desde               date not null,
  hasta               date,
  constraint fin_vigencias_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_vigencias_ingreso_fk foreign key (libro_id, ingreso_id) references public.fin_ingresos (libro_id, id),
  constraint fin_vigencias_hasta check (hasta is null or hasta >= desde),
  constraint fin_vigencias_dias_mes check (
    dias_mes is null or (array_ndims(dias_mes) = 1 and cardinality(dias_mes) between 1 and 31
                         and 0 <= all (dias_mes) and 31 >= all (dias_mes)
                         and array_position(dias_mes, null) is null)),
  constraint fin_vigencias_calendario check (
       (forma = 'semanal' and dia_semana is not null)
    or (forma = 'catorcenal' and fecha_ancla is not null)
    or (forma = 'quincenal' and cardinality(dias_mes) = 2)
    or (forma = 'mensual' and cardinality(dias_mes) >= 1)
    or (forma = 'cada_meses' and fecha_ancla is not null and intervalo_meses is not null))
);
create index fin_vigencias_ingreso_idx on public.fin_vigencias_ingreso (ingreso_id, desde);
comment on table public.fin_vigencias_ingreso is
  'Monto neto y calendario de un ingreso por periodo. Un cambio de neto crea una vigencia nueva y '
  'cierra hasta en la anterior; no se traslapan. dias_mes: 0 = último día del mes.';

create table public.fin_compromisos (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid not null,
  nombre          text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo            text not null check (tipo in ('fija', 'reserva')),
  cuenta_gasto_id uuid,
  categoria_id    uuid,
  monto_centavos  bigint not null check (monto_centavos > 0),
  frecuencia      public.fin_frecuencia not null,
  dias_activos    smallint check (dias_activos between 1 and 7),
  forma           public.fin_forma_pago,
  dia_semana      smallint check (dia_semana between 1 and 7),
  dias_mes        smallint[],
  fecha_ancla     date,
  intervalo_meses smallint check (intervalo_meses between 1 and 12),
  regla_inhabil   public.fin_regla_inhabil not null default 'sin_cambio',
  protegida       boolean not null default false,
  prioridad       public.fin_prioridad not null default 'necesario',
  desde           date,
  hasta           date,
  activo          boolean not null default true,
  constraint fin_compromisos_libro_id_key unique (libro_id, id),
  constraint fin_compromisos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_compromisos_cuenta_fk foreign key (hogar_id, cuenta_gasto_id) references public.fin_cuentas (hogar_id, id),
  constraint fin_compromisos_categoria_fk foreign key (hogar_id, categoria_id) references public.fin_categorias (hogar_id, id),
  constraint fin_compromisos_diaria check ((frecuencia = 'diaria') = (dias_activos is not null)),
  constraint fin_compromisos_hasta check (hasta is null or desde is null or hasta >= desde),
  constraint fin_compromisos_dias_mes check (
    dias_mes is null or (array_ndims(dias_mes) = 1 and cardinality(dias_mes) between 1 and 31
                         and 0 <= all (dias_mes) and 31 >= all (dias_mes)
                         and array_position(dias_mes, null) is null)),
  constraint fin_compromisos_calendario check (
       forma is null
    or (forma = 'semanal' and dia_semana is not null)
    or (forma = 'catorcenal' and fecha_ancla is not null)
    or (forma = 'quincenal' and cardinality(dias_mes) = 2)
    or (forma = 'mensual' and cardinality(dias_mes) >= 1)
    or (forma = 'cada_meses' and fecha_ancla is not null and intervalo_meses is not null))
);
comment on table public.fin_compromisos is
  'Gastos fijos y reservas de un libro (renta, servicios, placas y predial). regla_inhabil por '
  'compromiso; por defecto sin_cambio (D19 regla 5).';

create table public.fin_sobres (
  id                     uuid primary key default gen_random_uuid(),
  hogar_id               uuid not null references public.hogares (id),
  libro_id               uuid not null,
  cuenta_gasto_id        uuid not null,
  nombre                 text not null check (char_length(btrim(nombre)) between 1 and 80),
  monto_semanal_centavos bigint not null check (monto_semanal_centavos >= 0),
  protegida              boolean not null default false,
  prioridad              public.fin_prioridad not null default 'necesario',
  piso_minimo_centavos   bigint not null default 0,
  modo_arrastre          public.fin_modo_arrastre not null default 'arrastrar',
  activo                 boolean not null default true,
  constraint fin_sobres_libro_id_key unique (libro_id, id),
  constraint fin_sobres_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_sobres_cuenta_fk foreign key (hogar_id, cuenta_gasto_id) references public.fin_cuentas (hogar_id, id),
  constraint fin_sobres_piso check (piso_minimo_centavos between 0 and monto_semanal_centavos)
);
comment on table public.fin_sobres is 'Partidas variables por rubro (sobres) del presupuesto de un libro.';

create table public.fin_deudas (
  id                uuid primary key default gen_random_uuid(),
  hogar_id          uuid not null references public.hogares (id),
  libro_id          uuid not null,
  nombre            text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo              text not null check (tipo in ('con_costo', 'familiar', 'msi')),
  cuenta_pasivo_id  uuid not null,
  abono_centavos    bigint not null check (abono_centavos >= 0),
  frecuencia        public.fin_frecuencia not null check (frecuencia <> 'diaria'),
  forma             public.fin_forma_pago,
  dia_semana        smallint check (dia_semana between 1 and 7),
  dias_mes          smallint[],
  fecha_ancla       date,
  intervalo_meses   smallint check (intervalo_meses between 1 and 12),
  regla_inhabil     public.fin_regla_inhabil not null default 'sin_cambio',
  minimo_centavos   bigint not null default 0 check (minimo_centavos >= 0),
  tasa_anual_pb     integer not null default 0,
  prioridad_manual  smallint check (prioridad_manual >= 1),
  grupo_prioritario boolean not null default false,
  orden_grupo       smallint check (orden_grupo >= 1),
  activa            boolean not null default true,
  constraint fin_deudas_libro_id_key unique (libro_id, id),
  constraint fin_deudas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_deudas_pasivo_fk foreign key (libro_id, cuenta_pasivo_id) references public.fin_cuentas (libro_id, id),
  constraint fin_deudas_tasa check ((tipo = 'con_costo' and tasa_anual_pb > 0) or (tipo <> 'con_costo' and tasa_anual_pb = 0)),
  constraint fin_deudas_grupo check (grupo_prioritario = (orden_grupo is not null)),
  constraint fin_deudas_dias_mes check (
    dias_mes is null or (array_ndims(dias_mes) = 1 and cardinality(dias_mes) between 1 and 31
                         and 0 <= all (dias_mes) and 31 >= all (dias_mes)
                         and array_position(dias_mes, null) is null)),
  constraint fin_deudas_calendario check (
       forma is null
    or (forma = 'semanal' and dia_semana is not null)
    or (forma = 'catorcenal' and fecha_ancla is not null)
    or (forma = 'quincenal' and cardinality(dias_mes) = 2)
    or (forma = 'mensual' and cardinality(dias_mes) >= 1)
    or (forma = 'cada_meses' and fecha_ancla is not null and intervalo_meses is not null))
);
comment on table public.fin_deudas is
  'Deudas de un libro. El saldo sale del libro (cuenta pasivo). Tasa en puntos base (> 0 solo en '
  'con_costo). grupo_prioritario y orden_grupo: el grupo que elige el titular (D19 regla 4, P12).';

create table public.fin_dias_inhabiles (
  id           uuid primary key default gen_random_uuid(),
  hogar_id     uuid not null references public.hogares (id),
  fecha        date not null,
  nombre       text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo         text not null default 'festivo_oficial' check (tipo in ('festivo_oficial', 'personal')),
  fuente       text check (char_length(fuente) <= 120),
  activo       boolean not null default false,
  revisado_por uuid references public.personas (id),
  revisado_en  timestamptz,
  constraint fin_dias_inhabiles_fecha_unica unique (hogar_id, fecha)
);
comment on table public.fin_dias_inhabiles is
  'Calendario de días inhábiles del HOGAR. La precarga (LFT art. 74) nace inactiva: el dueño la revisa '
  'y la activa. revisado_por y revisado_en los pone el servidor cuando cambia activo.';

-- -----------------------------------------------------------------------------
-- 7. Plan semanal
-- -----------------------------------------------------------------------------
create table public.fin_semanas (
  id                         uuid primary key default gen_random_uuid(),
  hogar_id                   uuid not null references public.hogares (id),
  libro_id                   uuid not null,
  semana_inicio              date not null check (extract(isodow from semana_inicio) = 1),
  estado                     text not null default 'borrador'
                             check (estado in ('borrador', 'activa', 'pendiente_ingreso', 'por_cerrar', 'cerrada')),
  metodo                     text not null default 'sobres' check (metodo = 'sobres'),
  ingreso                    bigint not null default 0 check (ingreso >= 0),
  presupuesto                bigint not null default 0 check (presupuesto >= 0),
  deuda_plan                 bigint not null default 0 check (deuda_plan >= 0),
  remanente_plan             bigint not null default 0,
  meta_remanente_pb          integer not null default 2000 check (meta_remanente_pb between 0 and 10000),
  ahorro_minimo_con_deuda_pb integer not null default 0 check (ahorro_minimo_con_deuda_pb between 0 and 10000),
  techo                      bigint not null default 0,
  activada_por               uuid references public.personas (id),
  activada_en                timestamptz,
  reaperturas                smallint not null default 0 check (reaperturas >= 0),
  constraint fin_semanas_libro_id_key unique (libro_id, id),
  constraint fin_semanas_una_por_libro unique (libro_id, semana_inicio),
  constraint fin_semanas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_semanas_cascada check (remanente_plan = ingreso - presupuesto - deuda_plan)
);
comment on table public.fin_semanas is
  'Foto del plan de una semana (lunes) de un libro. Cambia solo mientras no esté cerrada; para cerrar '
  'se guarda antes el cierre (versión reaperturas + 1); reabrir solo cambia el estado.';
comment on column public.fin_semanas.reaperturas is 'Veces que se reabrió; lo pone el servidor.';

create table public.fin_partidas_semana (
  id                uuid primary key default gen_random_uuid(),
  hogar_id          uuid not null references public.hogares (id),
  libro_id          uuid not null,
  semana_id         uuid not null,
  origen            text not null check (origen in ('compromiso', 'sobre')),
  origen_id         uuid not null,
  cuenta_gasto_id   uuid,
  tipo              text not null check (tipo in ('fija', 'variable', 'reserva')),
  asignado          bigint not null check (asignado >= 0),
  arrastre_recibido bigint not null default 0 check (arrastre_recibido >= 0),
  protegida         boolean not null default false,
  prioridad         public.fin_prioridad not null default 'necesario',
  piso_minimo       bigint not null default 0 check (piso_minimo >= 0),
  modo_arrastre     public.fin_modo_arrastre not null default 'arrastrar',
  constraint fin_partidas_libro_id_key unique (libro_id, id),
  constraint fin_partidas_una_por_origen unique (semana_id, origen, origen_id),
  constraint fin_partidas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_partidas_semana_fk foreign key (libro_id, semana_id) references public.fin_semanas (libro_id, id),
  constraint fin_partidas_cuenta_fk foreign key (hogar_id, cuenta_gasto_id) references public.fin_cuentas (hogar_id, id),
  constraint fin_partidas_tipo_origen check ((origen = 'sobre') = (tipo = 'variable'))
);

create table public.fin_abonos_semana (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  semana_id      uuid not null,
  deuda_id       uuid not null,
  abono_planeado bigint not null check (abono_planeado >= 0),
  minimo         bigint not null default 0 check (minimo >= 0),
  extra_planeado bigint not null default 0 check (extra_planeado >= 0),
  constraint fin_abonos_una_por_deuda unique (semana_id, deuda_id),
  constraint fin_abonos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_abonos_semana_fk foreign key (libro_id, semana_id) references public.fin_semanas (libro_id, id),
  constraint fin_abonos_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id)
);

-- -----------------------------------------------------------------------------
-- 8. Cierres (SOLO AGREGAR)
-- -----------------------------------------------------------------------------
create table public.fin_cierres (
  id                 uuid primary key default gen_random_uuid(),
  hogar_id           uuid not null references public.hogares (id),
  libro_id           uuid not null,
  semana_id          uuid not null,
  version            smallint not null check (version >= 1),
  ingreso_real       bigint not null,
  gasto_real         bigint not null,
  abono_real         bigint not null default 0 check (abono_real >= 0),
  abono_diferido     bigint not null default 0 check (abono_diferido >= 0),
  abono_extra_real   bigint not null default 0 check (abono_extra_real >= 0),
  ahorro_real        bigint not null default 0 check (ahorro_real >= 0),
  deficit            bigint not null default 0 check (deficit >= 0),
  arrastre_siguiente bigint not null default 0 check (arrastre_siguiente >= 0),
  accion_elegida     text check (char_length(btrim(accion_elegida)) between 1 and 60),
  con_pendientes     boolean not null default false,
  activos            bigint not null,
  pasivos            bigint not null,
  patrimonio         bigint not null,
  cerrado_por        uuid not null default public.persona_actual() references public.personas (id),
  cerrado_en         timestamptz not null default now(),
  constraint fin_cierres_libro_id_key unique (libro_id, id),
  constraint fin_cierres_version_unica unique (semana_id, version),
  constraint fin_cierres_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_cierres_semana_fk foreign key (libro_id, semana_id) references public.fin_semanas (libro_id, id),
  constraint fin_cierres_patrimonio check (patrimonio = activos - pasivos)
);
comment on table public.fin_cierres is
  'Foto del cierre de una semana y del balance (SOLO AGREGAR). Reabrir y volver a cerrar crea la '
  'versión siguiente; las correcciones posteriores no cambian una foto guardada.';

create table public.fin_cierre_partidas (
  id                 uuid primary key default gen_random_uuid(),
  hogar_id           uuid not null references public.hogares (id),
  libro_id           uuid not null,
  cierre_id          uuid not null,
  partida_id         uuid not null,
  gastado            bigint not null,
  arrastre_siguiente bigint not null default 0 check (arrastre_siguiente >= 0),
  al_remanente       bigint not null default 0 check (al_remanente >= 0),
  constraint fin_cierre_partidas_una unique (cierre_id, partida_id),
  constraint fin_cierre_partidas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_cierre_partidas_cierre_fk foreign key (libro_id, cierre_id) references public.fin_cierres (libro_id, id),
  constraint fin_cierre_partidas_partida_fk foreign key (libro_id, partida_id) references public.fin_partidas_semana (libro_id, id)
);

create table public.fin_cierre_abonos (
  id        uuid primary key default gen_random_uuid(),
  hogar_id  uuid not null references public.hogares (id),
  libro_id  uuid not null,
  cierre_id uuid not null,
  deuda_id  uuid not null,
  planeado  bigint not null check (planeado >= 0),
  "real"    bigint not null check ("real" >= 0),
  minimo    bigint not null default 0 check (minimo >= 0),
  diferido  bigint generated always as (greatest(planeado - "real", 0)) stored,
  constraint fin_cierre_abonos_una unique (cierre_id, deuda_id),
  constraint fin_cierre_abonos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_cierre_abonos_cierre_fk foreign key (libro_id, cierre_id) references public.fin_cierres (libro_id, id),
  constraint fin_cierre_abonos_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id)
);
comment on table public.fin_cierre_abonos is 'AbonoDiferido del diseño (SOLO AGREGAR): diferido = planeado − real (generada).';

-- -----------------------------------------------------------------------------
-- 9. Ocurrencias, conciliaciones e importaciones
-- -----------------------------------------------------------------------------
create table public.fin_ocurrencias (
  id               uuid primary key default gen_random_uuid(),
  hogar_id         uuid not null references public.hogares (id),
  libro_id         uuid not null,
  origen           text not null check (origen in ('ingreso', 'compromiso', 'deuda')),
  origen_id        uuid not null,
  fecha_programada date not null,
  fecha_ajustada   date not null,
  monto_esperado   bigint not null check (monto_esperado >= 0),
  estado           text not null default 'esperada'
                   check (estado in ('esperada', 'cumplida', 'parcial', 'retrasada', 'no_llegara', 'omitida')),
  movimiento_id    uuid,
  constraint fin_ocurrencias_una unique (libro_id, origen, origen_id, fecha_programada),
  constraint fin_ocurrencias_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_ocurrencias_movimiento_fk foreign key (hogar_id, movimiento_id) references public.fin_movimientos (hogar_id, id)
);
create index fin_ocurrencias_fecha_idx on public.fin_ocurrencias (libro_id, fecha_ajustada);
comment on table public.fin_ocurrencias is
  'Fechas esperadas de ingresos, compromisos y deudas (horizonte de 13 semanas). En una semana cerrada '
  'no se agregan ni cambian fecha ni monto; el estado y el movimiento sí (p. ej. un ingreso retrasado).';

create table public.fin_conciliaciones (
  id                   uuid primary key default gen_random_uuid(),
  hogar_id             uuid not null references public.hogares (id),
  libro_id             uuid not null,
  cuenta_id            uuid not null,
  fecha                date not null,
  saldo_declarado      bigint not null,
  saldo_calculado      bigint not null,
  diferencia           bigint generated always as (saldo_declarado - saldo_calculado) stored,
  ajuste_movimiento_id uuid,
  motivo               text check (char_length(motivo) <= 200),
  persona_id           uuid not null default public.persona_actual() references public.personas (id),
  creado_en            timestamptz not null default now(),
  constraint fin_conciliaciones_un_ajuste unique (ajuste_movimiento_id),
  constraint fin_conciliaciones_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_conciliaciones_cuenta_fk foreign key (libro_id, cuenta_id) references public.fin_cuentas (libro_id, id),
  constraint fin_conciliaciones_ajuste_fk foreign key (hogar_id, ajuste_movimiento_id) references public.fin_movimientos (hogar_id, id),
  constraint fin_conciliaciones_ajuste_si_difiere check ((saldo_declarado = saldo_calculado) = (ajuste_movimiento_id is null)),
  constraint fin_conciliaciones_motivo_si_difiere check (saldo_declarado = saldo_calculado or nullif(btrim(motivo), '') is not null)
);
comment on table public.fin_conciliaciones is
  'Conciliaciones de saldo (SOLO AGREGAR). Con diferencia, primero se registra el movimiento de ajuste '
  '(contra la cuenta Ajustes del libro, con motivo) y luego la conciliación que lo referencia.';

create table public.fin_importaciones (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  archivo        text not null check (char_length(btrim(archivo)) between 1 and 255),
  hoja           text check (char_length(hoja) <= 100),
  filas_leidas   integer not null default 0 check (filas_leidas >= 0),
  filas_creadas  integer not null default 0 check (filas_creadas >= 0),
  filas_omitidas integer not null default 0 check (filas_omitidas >= 0),
  detalle        jsonb not null default '{}'::jsonb
                 check (jsonb_typeof(detalle) in ('object', 'array') and octet_length(detalle::text) <= 262144),
  persona_id     uuid not null default public.persona_actual() references public.personas (id),
  creado_en      timestamptz not null default now(),
  constraint fin_importaciones_filas check (filas_creadas + filas_omitidas <= filas_leidas)
);
comment on table public.fin_importaciones is 'Registro de importaciones del HOGAR (p. ej. la hoja Categorías). SOLO AGREGAR.';

-- -----------------------------------------------------------------------------
-- 10. Cuenta maestra (D19) en las membresías
-- -----------------------------------------------------------------------------
alter table public.membresias
  add column es_maestra boolean not null default false,
  add constraint membresias_maestra_con_finanzas check (not es_maestra or rol in ('dueno', 'coadministrador'));
create unique index membresias_una_maestra_por_hogar on public.membresias (hogar_id) where es_maestra;
comment on column public.membresias.es_maestra is
  'Cuenta maestra (D19): solo LEE todo el hogar (Finanzas e historial de GRAVITY), nunca escribe en lo '
  'ajeno. Una por hogar; solo dueño o coadministrador; la asigna el dueño con asignar_cuenta_maestra().';

-- -----------------------------------------------------------------------------
-- 11. Funciones para las reglas (SECURITY DEFINER, search_path vacío)
-- -----------------------------------------------------------------------------
create function public.es_cuenta_maestra(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
           select 1
           from public.membresias m
           join public.personas p on p.id = m.persona_id
           where m.hogar_id = p_hogar_id
             and p.usuario_id = auth.uid()
             and m.es_maestra and m.activa
             and m.desde <= now() and (m.hasta is null or m.hasta > now()))
     and coalesce(public.alcance(p_hogar_id, 'finanzas', 'leer'), '') in ('propio', 'total')
$$;
comment on function public.es_cuenta_maestra(uuid) is
  'Verdadero si quien consulta es la cuenta maestra vigente del hogar (D19) y su rol tiene Finanzas.';

create function public.fin_puede_hogar(p_hogar_id uuid, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
begin
  perform p_accion::public.accion_permiso;
  if p_accion is null then
    raise exception using errcode = '22023', message = 'La acción es obligatoria';
  end if;
  if coalesce(public.alcance(p_hogar_id, 'finanzas', p_accion), '') in ('propio', 'total') then
    return true;
  end if;
  return p_accion = 'leer' and public.es_cuenta_maestra(p_hogar_id);
end
$$;
comment on function public.fin_puede_hogar(uuid, text) is
  'Para lo de Finanzas que es del HOGAR (categorías, cuentas de gasto, días inhábiles, importaciones): '
  'el rol tiene Finanzas (propio o total) para esa acción; la cuenta maestra además lee.';

create function public.fin_es_miembro(p_libro_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.fin_libro_miembros m
    join public.fin_libros l on l.id = m.libro_id
    where m.libro_id = p_libro_id
      and m.persona_id = public.persona_actual()
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
      and public.rol_en_hogar(l.hogar_id) is not null)
$$;
comment on function public.fin_es_miembro(uuid) is
  'Quien consulta es miembro vigente del libro (cualquier papel) y sigue en el hogar.';

create function public.fin_puede(p_libro_id uuid, p_accion text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_libro   public.fin_libros%rowtype;
  v_papel   text;
  v_albacea boolean;
begin
  perform p_accion::public.accion_permiso;
  if p_accion is null then
    raise exception using errcode = '22023', message = 'La acción es obligatoria';
  end if;
  if p_libro_id is null or v_persona is null then
    return false;
  end if;
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found then
    return false;
  end if;

  -- El rol vigente debe tener Finanzas para esa acción (propio en D19).
  if coalesce(public.alcance(v_libro.hogar_id, 'finanzas', p_accion), '') in ('propio', 'total') then
    select m.papel into v_papel
    from public.fin_libro_miembros m
    where m.libro_id = p_libro_id and m.persona_id = v_persona
      and m.desde <= now() and (m.hasta is null or m.hasta > now())
    order by case m.papel when 'titular' then 1 when 'albacea' then 2 when 'miembro' then 3 else 4 end
    limit 1;
  end if;

  if v_papel is null then
    -- La cuenta maestra solo lee lo ajeno; nunca escribe ni administra.
    return p_accion = 'leer' and public.es_cuenta_maestra(v_libro.hogar_id);
  end if;
  if p_accion = 'leer' then
    return true;
  end if;

  v_albacea := exists (
    select 1 from public.fin_libro_miembros a
    where a.libro_id = p_libro_id and a.papel = 'albacea'
      and a.desde <= now() and (a.hasta is null or a.hasta > now()));

  if p_accion = 'escribir' then
    if not v_libro.activo then
      return false;
    end if;
    -- El suplente escribe solo si no hay albacea vigente.
    return v_papel in ('titular', 'miembro', 'albacea')
        or (v_papel = 'albacea_suplente' and not v_albacea);
  end if;

  -- administrar
  return (v_libro.tipo = 'personal' and v_papel = 'titular')
      or (v_libro.tipo = 'compartido' and v_papel = 'miembro')
      or (v_libro.tipo = 'representado'
          and (v_papel = 'albacea' or (v_papel = 'albacea_suplente' and not v_albacea)));
end
$$;
comment on function public.fin_puede(uuid, text) is
  'D19. leer: miembro vigente del libro o cuenta maestra. escribir: titular, miembro o albacea (el '
  'suplente solo sin albacea vigente), con el libro activo. administrar: titular de un personal, '
  'miembro de un compartido, albacea de un representado. Siempre exige un rol con Finanzas.';

-- ¿Puede quien consulta ver esta entrada de la bitácora? (además de las suyas)
-- * La cuenta maestra ve todo el hogar.
-- * Historial de GRAVITY (acciones gravity.*): solo quien lo hizo (D18).
-- * Finanzas (tablas fin_* y acciones finanzas.*): quien puede leer el libro
--   de la entrada; lo del hogar, quien tiene Finanzas (D19).
-- * Lo demás (membresías, invitaciones, entregas de turno…): el dueño.
create function public.puede_ver_entrada_bitacora(
  p_hogar_id uuid, p_tabla text, p_accion text, p_registro_id text, p_detalle jsonb)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_fila   jsonb;
  v_texto  text;
  v_libros uuid[] := '{}';
begin
  if p_hogar_id is null then
    return false;
  end if;
  if public.es_cuenta_maestra(p_hogar_id) then
    return true;
  end if;
  if p_accion like 'gravity.%' then
    return false;
  end if;
  if p_tabla like 'fin\_%' or p_accion like 'finanzas.%' then
    v_fila := coalesce(p_detalle -> 'despues', p_detalle -> 'antes', p_detalle);
    foreach v_texto in array array[
        v_fila ->> 'libro_id', v_fila ->> 'libro_origen_id', v_fila ->> 'libro_destino_id',
        case when p_tabla = 'fin_libros' then coalesce(v_fila ->> 'id', p_registro_id) end]
    loop
      if v_texto ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        v_libros := v_libros || v_texto::uuid;
      end if;
    end loop;
    if cardinality(v_libros) = 0 then
      return public.fin_puede_hogar(p_hogar_id, 'leer');
    end if;
    return exists (select 1 from unnest(v_libros) as l(id) where public.fin_puede(l.id, 'leer'));
  end if;
  return public.puede(p_hogar_id, 'ajustes', 'administrar');
end
$$;

-- personas: además de a sí mismo y de lo que ve el dueño (Fase 0), quien
-- comparte un libro ve a los demás miembros y al titular (p. ej. la pareja ve
-- quién aportó al compartido; los albaceas ven a papá); la cuenta maestra ve a
-- los miembros del hogar y a los titulares de sus libros.
create or replace function public.puede_ver_persona(p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_persona_id = public.persona_actual()
      or exists (
        select 1
        from public.membresias m
        where m.persona_id = p_persona_id
          and (public.puede(m.hogar_id, 'ajustes', 'administrar') or public.es_cuenta_maestra(m.hogar_id))
      )
      or exists (
        select 1
        from public.fin_libros l
        where l.titular_id = p_persona_id
          and (public.puede(l.hogar_id, 'ajustes', 'administrar') or public.es_cuenta_maestra(l.hogar_id))
      )
      or exists (
        select 1
        from public.fin_libro_miembros yo
        join public.fin_libros l on l.id = yo.libro_id
        where yo.persona_id = public.persona_actual()
          and yo.desde <= now() and (yo.hasta is null or yo.hasta > now())
          and public.rol_en_hogar(l.hogar_id) is not null
          and (l.titular_id = p_persona_id
               or exists (select 1 from public.fin_libro_miembros otro
                          where otro.libro_id = l.id and otro.persona_id = p_persona_id))
      )
$$;
comment on function public.puede_ver_persona(uuid) is
  'Cada quien se ve a sí mismo; el dueño ve a los miembros del hogar y a los titulares de sus libros; '
  'quien comparte un libro de Finanzas ve a sus miembros y a su titular; la cuenta maestra, a todos (D19).';

-- -----------------------------------------------------------------------------
-- 12. Operaciones (RPC)
-- -----------------------------------------------------------------------------
create function public.asignar_cuenta_maestra(p_hogar_id uuid, p_persona_id uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
begin
  if not public.puede(p_hogar_id, 'ajustes', 'administrar') then
    raise exception using errcode = '42501', message = 'Solo el dueño del hogar asigna la cuenta maestra.';
  end if;
  if p_persona_id is not null and not exists (
      select 1 from public.membresias m
      where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa
        and m.desde <= now() and (m.hasta is null or m.hasta > now())
        and m.rol in ('dueno', 'coadministrador')) then
    raise exception using errcode = '22023',
      message = 'La cuenta maestra debe ser un miembro vigente con Finanzas (dueño o coadministrador).';
  end if;
  update public.membresias m
     set es_maestra = false
   where m.hogar_id = p_hogar_id and m.es_maestra
     and (p_persona_id is null or m.persona_id <> p_persona_id or not m.activa);
  if p_persona_id is not null then
    update public.membresias m
       set es_maestra = true
     where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id and m.activa and not m.es_maestra;
  end if;
end
$$;
comment on function public.asignar_cuenta_maestra(uuid, uuid) is
  'Solo el dueño. Nombra la cuenta maestra del hogar (dueño o coadministrador vigente) o la quita con nulo. '
  'Queda en la bitácora (membresías).';

create function public.cuenta_maestra(p_hogar_id uuid)
returns table (persona_id uuid, nombre_visible text)
language sql stable security definer
set search_path = ''
as $$
  select p.id, p.nombre_visible
  from public.membresias m
  join public.personas p on p.id = m.persona_id
  where m.hogar_id = p_hogar_id and m.es_maestra and m.activa
    and public.rol_en_hogar(p_hogar_id) is not null
$$;
comment on function public.cuenta_maestra(uuid) is
  'Para Ajustes › Privacidad: cualquier miembro del hogar ve si existe la cuenta maestra y de quién es (D19).';

create function public.fin_registrar_consulta_maestra(p_libro_id uuid)
returns boolean
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found or not public.es_cuenta_maestra(v_libro.hogar_id) then
    raise exception using errcode = '42501', message = 'Solo la cuenta maestra del hogar registra consultas.';
  end if;
  if public.fin_es_miembro(p_libro_id) then
    return false;  -- lo propio no se registra
  end if;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_libro.hogar_id, public.persona_actual(), 'finanzas.consulta_maestra', 'fin_libros',
          p_libro_id::text, jsonb_build_object('libro_id', p_libro_id, 'tipo', v_libro.tipo));
  return true;
end
$$;
comment on function public.fin_registrar_consulta_maestra(uuid) is
  'La app la llama al abrir un libro ajeno con la cuenta maestra: deja la consulta en la bitácora '
  '(finanzas.consulta_maestra), visible para quienes llevan ese libro. Devuelve falso si el libro es propio.';

create function public.fin_crear_libro_representado(
  p_hogar_id uuid, p_nombre_titular text, p_nombre_libro text default null, p_libro_id uuid default null)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid;
  v_libro   uuid;
begin
  if not public.puede(p_hogar_id, 'ajustes', 'administrar')
     or coalesce(public.alcance(p_hogar_id, 'finanzas', 'administrar'), '') not in ('propio', 'total') then
    raise exception using errcode = '42501', message = 'Solo el dueño crea el libro de una persona representada.';
  end if;
  -- Reintento: si ya existe ese libro representado en el hogar, se devuelve.
  if p_libro_id is not null then
    select l.id into v_libro from public.fin_libros l
    where l.id = p_libro_id and l.hogar_id = p_hogar_id and l.tipo = 'representado';
    if found then
      return v_libro;
    end if;
  end if;
  if nullif(btrim(p_nombre_titular), '') is null then
    raise exception using errcode = '22023', message = 'Falta el nombre de la persona representada.';
  end if;
  insert into public.personas (nombre_visible) values (left(btrim(p_nombre_titular), 80))
  returning id into v_persona;
  insert into public.fin_libros (id, hogar_id, nombre, tipo, titular_id, creado_por)
  values (coalesce(p_libro_id, gen_random_uuid()), p_hogar_id,
          left(coalesce(nullif(btrim(p_nombre_libro), ''), btrim(p_nombre_titular)), 80),
          'representado', v_persona, public.persona_actual())
  returning id into v_libro;
  return v_libro;
end
$$;
comment on function public.fin_crear_libro_representado(uuid, text, text, uuid) is
  'Solo el dueño. Crea la persona sin cuenta (papá) y su libro representado; quien lo crea queda como '
  'albacea. El suplente se agrega en fin_libro_miembros. Con p_libro_id es idempotente.';

-- -----------------------------------------------------------------------------
-- 13. Triggers
-- -----------------------------------------------------------------------------
-- 13.1 Genéricos

-- Idempotencia de la cola sin conexión. Va antes que las demás validaciones.
-- tg_argv[0]: 'estricto' (solo agregar: mismo id con otro contenido = 23505)
--             o 'flexible' (configuración: lo resuelve ON CONFLICT o la llave).
-- tg_argv[1..]: columnas que pone el servidor (o generadas) y no se comparan.
-- Mismo id y mismo contenido: no inserta nada y no falla.
create function public.fin_una_vez()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_modo      text   := tg_argv[0];
  v_ignorar   text[] := coalesce(tg_argv[1:], '{}'::text[]);
  v_existente jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended(tg_table_name || ':' || new.id::text, 0));
  execute format('select to_jsonb(t) from %s t where t.id = $1', tg_relid::regclass)
    into v_existente using new.id;
  if v_existente is null then
    return new;
  end if;
  if (v_existente - v_ignorar) = (to_jsonb(new) - v_ignorar) then
    return null;
  end if;
  if v_modo = 'estricto' then
    raise exception using
      errcode = '23505',
      message = format('Ya existe un registro %s en %I con otro contenido.', new.id, tg_table_name),
      hint    = 'No se edita: se corrige con un registro nuevo (anulación o versión siguiente).';
  end if;
  return new;
end
$$;

-- Columnas que no cambian en un UPDATE (tg_argv: nombres de columna).
create function public.fin_columnas_fijas()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_col     text;
  v_antes   jsonb := to_jsonb(old);
  v_despues jsonb := to_jsonb(new);
begin
  foreach v_col in array tg_argv loop
    if v_antes -> v_col is distinct from v_despues -> v_col then
      raise exception using errcode = '42501',
        message = format('La columna %I de %I no se cambia.', v_col, tg_table_name);
    end if;
  end loop;
  return new;
end
$$;

-- Lunes de la semana de una fecha (semana en lunes).
create function public.fin_lunes(p_fecha date)
returns date
language sql immutable
set search_path = ''
as $$ select p_fecha - (extract(isodow from p_fecha)::integer - 1) $$;

-- 13.2 Libros y miembros

-- Antes de crear un libro: el titular de un personal tiene Finanzas en el
-- hogar; el de un representado es una persona sin cuenta y sin membresía.
create function public.fin_libros_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    return new;
  end if;
  -- (Desde la app solo se crea el propio; el de otra persona lo rechaza la RLS.)
  if new.tipo = 'personal'
     and (current_user <> 'authenticated' or new.titular_id = public.persona_actual())
     and not exists (
      select 1 from public.membresias m
      join public.permisos_rol pr on pr.rol = m.rol and pr.modulo = 'finanzas' and pr.accion = 'administrar'
      where m.hogar_id = new.hogar_id and m.persona_id = new.titular_id and m.activa
        and m.desde <= now() and (m.hasta is null or m.hasta > now())
        and pr.alcance in ('propio', 'total')) then
    raise exception using errcode = '22023',
      message = 'El titular de un libro personal debe tener Finanzas en el hogar (dueño o coadministrador).';
  end if;
  if new.tipo = 'representado' and exists (
      select 1 from public.personas p where p.id = new.titular_id and p.usuario_id is not null) then
    raise exception using errcode = '22023',
      message = 'Un libro representado es de una persona sin cuenta (persona bajo cuidado).';
  end if;
  return new;
end
$$;

-- Al crear un libro: su primer miembro (titular, miembro o albacea), sus
-- cuentas de sistema (Ajustes, Apertura, Por clasificar) y sus parámetros.
create function public.fin_libros_al_crear()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_miembro       uuid := case when new.tipo = 'personal' then new.titular_id else new.creado_por end;
  v_ajustes       uuid;
  v_apertura      uuid;
  v_por_clasificar uuid;
begin
  if v_miembro is not null then
    insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel)
    values (new.hogar_id, new.id, v_miembro,
            case new.tipo when 'personal' then 'titular' when 'compartido' then 'miembro' else 'albacea' end);
  end if;
  insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo, creada_por)
  values (new.hogar_id, new.id, 'Ajustes', 'ajustes', new.creado_por) returning id into v_ajustes;
  insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo, creada_por)
  values (new.hogar_id, new.id, 'Apertura', 'apertura', new.creado_por) returning id into v_apertura;
  insert into public.fin_cuentas (hogar_id, libro_id, nombre, tipo, creada_por)
  values (new.hogar_id, new.id, 'Por clasificar', 'por_clasificar', new.creado_por) returning id into v_por_clasificar;
  insert into public.fin_parametros (libro_id, hogar_id, cuenta_ajustes_id, cuenta_apertura_id, cuenta_por_clasificar_id)
  values (new.id, new.hogar_id, v_ajustes, v_apertura, v_por_clasificar);
  return null;
end
$$;

-- Libro personal automático para quien recibe un rol con Finanzas (D19).
create function public.fin_libro_personal_por_membresia()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.activa
     and exists (select 1 from public.permisos_rol pr
                 where pr.rol = new.rol and pr.modulo = 'finanzas' and pr.accion = 'administrar'
                   and pr.alcance in ('propio', 'total'))
     and not exists (select 1 from public.fin_libros l
                     where l.hogar_id = new.hogar_id and l.titular_id = new.persona_id and l.tipo = 'personal') then
    insert into public.fin_libros (hogar_id, nombre, tipo, titular_id, creado_por)
    select new.hogar_id, left('Finanzas de ' || p.nombre_visible, 80), 'personal', new.persona_id, new.persona_id
    from public.personas p where p.id = new.persona_id;
  end if;
  return null;
end
$$;

-- Miembros: papel según el tipo de libro y solo adultos con Finanzas.
-- SECURITY DEFINER para ver el rol de la otra persona; primero revisa el
-- permiso para no revelar nada a quien no administra el libro.
create function public.fin_libro_miembros_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if not found then
    raise exception using errcode = '23503', message = 'El libro no existe (¿aún no se sube?).';
  end if;
  if tg_op = 'INSERT' and auth.uid() is not null
     and not public.fin_puede(new.libro_id, 'administrar')
     -- Arranque: el primer miembro de un libro nuevo (lo agrega el servidor).
     and not (not exists (select 1 from public.fin_libro_miembros m where m.libro_id = new.libro_id)
              and new.persona_id = (case when v_libro.tipo = 'personal' then v_libro.titular_id
                                         else v_libro.creado_por end)) then
    raise exception using errcode = '42501', message = 'Sin permiso para administrar los miembros de ese libro.';
  end if;
  if new.hogar_id is not null and new.hogar_id <> v_libro.hogar_id then
    raise exception using errcode = '22023', message = 'El libro es de otro hogar.';
  end if;
  new.hogar_id := v_libro.hogar_id;

  if v_libro.tipo = 'personal' and (new.papel <> 'titular' or new.persona_id <> v_libro.titular_id) then
    raise exception using errcode = '22023', message = 'El titular de un libro personal es su único miembro.';
  end if;
  if v_libro.tipo = 'personal' and new.hasta is not null then
    raise exception using errcode = '22023', message = 'El titular no deja su libro personal.';
  end if;
  if v_libro.tipo = 'compartido' and new.papel <> 'miembro' then
    raise exception using errcode = '22023', message = 'En un libro compartido todos son miembros.';
  end if;
  if v_libro.tipo = 'representado' and new.papel not in ('albacea', 'albacea_suplente') then
    raise exception using errcode = '22023', message = 'Un libro representado lo llevan su albacea y su suplente.';
  end if;
  if v_libro.tipo = 'representado' and new.persona_id = v_libro.titular_id then
    raise exception using errcode = '22023', message = 'La persona representada no es miembro de su libro.';
  end if;
  if (new.hasta is null or new.hasta > now()) and not exists (
      select 1 from public.membresias m
      join public.permisos_rol pr on pr.rol = m.rol and pr.modulo = 'finanzas' and pr.accion = 'leer'
      where m.hogar_id = new.hogar_id and m.persona_id = new.persona_id and m.activa
        and m.desde <= now() and (m.hasta is null or m.hasta > now())
        and pr.alcance in ('propio', 'total')) then
    raise exception using errcode = '22023',
      message = 'Solo un adulto con Finanzas en el hogar (dueño o coadministrador) lleva un libro.';
  end if;
  return new;
end
$$;

-- 13.3 Categorías y cuentas

create function public.fin_categorias_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_nivel_padre smallint;
  v_tipo        text;
begin
  if new.padre_id is not null then
    select c.nivel into v_nivel_padre from public.fin_categorias c
    where c.hogar_id = new.hogar_id and c.id = new.padre_id;
    if found and new.nivel <> v_nivel_padre + 1 then
      raise exception using errcode = '22023', message = 'Una subcategoría va un nivel abajo de su categoría (máximo 3).';
    end if;
  end if;
  if tg_op = 'UPDATE' and new.nivel <> old.nivel
     and exists (select 1 from public.fin_categorias h where h.padre_id = old.id) then
    raise exception using errcode = '22023', message = 'Mueve primero sus subcategorías.';
  end if;
  if new.cuenta_gasto_id is not null then
    select c.tipo into v_tipo from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_gasto_id;
    if found and v_tipo not in ('de_gasto', 'gasto_financiero') then
      raise exception using errcode = '22023', message = 'La cuenta de una categoría es una cuenta de gasto.';
    end if;
  end if;
  return new;
end
$$;

create function public.fin_cuentas_al_insertar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Desde la app (rol authenticated) quien crea es siempre la sesión.
  if current_user = 'authenticated' then
    new.creada_por := public.persona_actual();
  end if;
  if new.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'Una cuenta nace activa.';
  end if;
  return new;
end
$$;

-- Cambios de una cuenta. SECURITY DEFINER para sumar TODOS sus movimientos
-- (una cuenta de gasto del hogar tiene movimientos de varios libros). La
-- regla de UPDATE (RLS) ya filtró las filas que se pueden cambiar.
create function public.fin_cuentas_al_cambiar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_total      bigint;
  v_confirmado bigint;
begin
  new.creada_por := old.creada_por;
  new.creada_en  := old.creada_en;
  if new.tipo <> old.tipo then
    if old.tipo in ('ajustes', 'apertura', 'por_clasificar') or new.tipo in ('ajustes', 'apertura', 'por_clasificar') then
      raise exception using errcode = '22023', message = 'Las cuentas de sistema no cambian de tipo.';
    end if;
    if exists (select 1 from public.fin_movimientos m
               where m.cuenta_origen_id = old.id or m.cuenta_destino_id = old.id) then
      raise exception using errcode = '22023', message = 'Una cuenta con movimientos no cambia de tipo.';
    end if;
  end if;
  if old.tipo in ('ajustes', 'apertura', 'por_clasificar') and new.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'Las cuentas de sistema siempre están activas.';
  end if;
  if new.estado in ('cerrada', 'archivada') and old.estado not in ('cerrada', 'archivada') then
    select coalesce(sum(case when m.cuenta_destino_id = old.id then m.monto_centavos else -m.monto_centavos end), 0),
           coalesce(sum(case when m.cuenta_destino_id = old.id then m.monto_centavos else -m.monto_centavos end)
                      filter (where m.estado_inicial = 'confirmado'), 0)
      into v_total, v_confirmado
    from public.fin_movimientos m
    where m.cuenta_origen_id = old.id or m.cuenta_destino_id = old.id;
    if v_total <> 0 or v_confirmado <> 0 then
      raise exception using errcode = '22023', message = 'Solo se cierra o archiva una cuenta con saldo cero.';
    end if;
  end if;
  return new;
end
$$;

-- 13.4 Movimientos (sección 4.3)
-- SECURITY DEFINER para ubicar el libro de cada cuenta aunque no se vea; antes
-- de validar nada revisa el permiso (fin_puede escribir en cada libro), que
-- repite la regla de inserción (RLS).
create function public.fin_movimientos_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_origen    public.fin_cuentas%rowtype;
  v_destino   public.fin_cuentas%rowtype;
  v_original  public.fin_movimientos%rowtype;
  v_existente jsonb;
  v_ignorar   text[] := array['recibido_en', 'libro_origen_id', 'libro_destino_id'];
  v_libros    uuid[];
  v_real      public.fin_cuentas%rowtype;
  v_valido    boolean;
begin
  -- 1. Cuentas del mismo hogar; su libro lo pone el servidor.
  select * into v_origen from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_origen_id;
  if not found then
    raise exception using errcode = '23503', message = 'La cuenta de origen no existe en este hogar (¿aún no se sube?).';
  end if;
  select * into v_destino from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_destino_id;
  if not found then
    raise exception using errcode = '23503', message = 'La cuenta de destino no existe en este hogar (¿aún no se sube?).';
  end if;
  new.libro_origen_id  := v_origen.libro_id;
  new.libro_destino_id := v_destino.libro_id;

  -- 2. Permiso en cada libro que toca (antes de revelar nada más).
  if auth.uid() is not null and not (
       (new.libro_origen_id is null or public.fin_puede(new.libro_origen_id, 'escribir'))
       and (new.libro_destino_id is null or public.fin_puede(new.libro_destino_id, 'escribir'))) then
    raise exception using errcode = '42501', message = 'Sin permiso para registrar movimientos en ese libro.';
  end if;

  -- 3. Idempotencia: el mismo id con el mismo contenido no hace nada.
  perform pg_advisory_xact_lock(hashtextextended('fin_movimientos:' || new.id::text, 0));
  select to_jsonb(m) into v_existente from public.fin_movimientos m where m.id = new.id;
  if v_existente is not null then
    if (v_existente - v_ignorar) = (to_jsonb(new) - v_ignorar) then
      return null;
    end if;
    raise exception using errcode = '23505',
      message = format('Ya existe el movimiento %s con otro contenido.', new.id),
      hint    = 'Los movimientos no se editan: se anulan con un contraasiento.';
  end if;
  new.recibido_en := now();

  -- 4. Combinación de cuentas por tipo (tabla de 4.3, la de libro.dart).
  if new.tipo = 'anulacion' then
    if new.anula_a is null then
      raise exception using errcode = '23514', message = 'Una anulación dice qué movimiento anula (anula_a).';
    end if;
    select * into v_original from public.fin_movimientos m where m.hogar_id = new.hogar_id and m.id = new.anula_a;
    if not found then
      raise exception using errcode = '23503', message = 'El movimiento que se anula no existe (¿aún no se sube?).';
    end if;
    if v_original.tipo = 'anulacion' then
      raise exception using errcode = '22023', message = 'No se anula un contraasiento: registra de nuevo el movimiento correcto.';
    end if;
    if v_original.estado_inicial <> 'confirmado' then
      raise exception using errcode = '22023', message = 'Solo se anula un movimiento confirmado.';
    end if;
    if exists (select 1 from public.fin_movimientos m where m.anula_a = new.anula_a) then
      raise exception using errcode = '23505', message = 'Ese movimiento ya tiene una anulación.';
    end if;
    if new.monto_centavos <> v_original.monto_centavos
       or new.cuenta_origen_id <> v_original.cuenta_destino_id
       or new.cuenta_destino_id <> v_original.cuenta_origen_id then
      raise exception using errcode = '22023',
        message = 'El contraasiento lleva el mismo monto con origen y destino invertidos.';
    end if;
    if v_origen.estado in ('cerrada', 'archivada') or v_destino.estado in ('cerrada', 'archivada') then
      raise exception using errcode = '55000', message = 'Una de las cuentas está cerrada o archivada.';
    end if;
  else
    if v_origen.estado <> 'activa' or v_destino.estado <> 'activa' then
      raise exception using errcode = '55000',
        message = 'Una de las cuentas no está activa (congelada, cerrada o archivada): no admite movimientos nuevos.';
    end if;
    v_valido := case new.tipo
      when 'apertura'        then (v_origen.clase = 'apertura' and v_destino.clase = 'activo')
                               or (v_origen.clase = 'pasivo' and v_destino.clase = 'apertura')
      when 'ingreso'         then v_origen.clase = 'ingreso' and v_destino.clase = 'activo'
      when 'gasto'           then v_origen.clase in ('activo', 'pasivo') and v_destino.clase = 'gasto'
      when 'reembolso'       then v_origen.clase = 'gasto' and v_destino.clase in ('activo', 'pasivo')
      when 'transferencia'   then v_origen.clase = 'activo' and v_destino.clase = 'activo'
      when 'pago_deuda'      then v_origen.clase = 'activo' and v_destino.clase = 'pasivo'
      when 'reclasificacion' then v_origen.tipo = 'por_clasificar' and v_destino.clase = 'gasto'
      when 'ajuste'          then (v_origen.clase = 'ajuste' and v_destino.clase in ('activo', 'pasivo'))
                               or (v_origen.clase in ('activo', 'pasivo') and v_destino.clase = 'ajuste')
      else false
    end;
    if not v_valido then
      raise exception using errcode = '22023',
        message = format('Un movimiento de tipo %s no puede ir de %s (%s) a %s (%s).', new.tipo,
                         v_origen.tipo, v_origen.clase, v_destino.tipo, v_destino.clase);
    end if;
    if new.tipo = 'apertura' then
      v_real := case when v_origen.clase = 'apertura' then v_destino else v_origen end;
      if exists (select 1 from public.fin_movimientos o
                 where o.tipo = 'apertura'
                   and (o.cuenta_origen_id = v_real.id or o.cuenta_destino_id = v_real.id)
                   and not exists (select 1 from public.fin_movimientos a where a.anula_a = o.id)) then
        raise exception using errcode = '22023',
          message = 'La cuenta ya tiene saldo inicial; se corrige con anulación o con un ajuste.';
      end if;
    end if;
  end if;

  -- 5. Libros: solo transferencias y pagos de deuda cruzan de un libro a otro
  --    (aportación a un compartido); apertura y ajuste, dentro del mismo libro.
  if new.libro_origen_id is not null and new.libro_destino_id is not null
     and new.libro_origen_id <> new.libro_destino_id
     and new.tipo not in ('transferencia', 'pago_deuda')
     and not (new.tipo = 'anulacion' and v_original.tipo in ('transferencia', 'pago_deuda')) then
    raise exception using errcode = '22023',
      message = 'Solo una transferencia o un pago de deuda va de un libro a otro.';
  end if;

  -- 6. Quién: realizado_por es quien registra, un miembro vigente o el titular
  --    de alguno de los libros; en_nombre_de es el titular de un libro
  --    representado que toca el movimiento (y lo registra su albacea: paso 2).
  v_libros := array_remove(array[new.libro_origen_id, new.libro_destino_id], null);
  if new.realizado_por is distinct from new.registrado_por
     and not exists (select 1 from public.fin_libros l where l.id = any (v_libros) and l.titular_id = new.realizado_por)
     and not exists (select 1 from public.fin_libro_miembros m
                     where m.libro_id = any (v_libros) and m.persona_id = new.realizado_por
                       and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
    raise exception using errcode = '22023', message = 'Quien realizó el movimiento no lleva ese libro.';
  end if;
  if new.en_nombre_de is not null and not exists (
      select 1 from public.fin_libros l
      where l.id = any (v_libros) and l.tipo = 'representado' and l.titular_id = new.en_nombre_de) then
    raise exception using errcode = '22023',
      message = 'en_nombre_de es el titular de un libro representado que toca el movimiento.';
  end if;
  return new;
end
$$;

-- 13.5 Configuración de cada libro

create function public.fin_ingresos_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_tipo  text;
  v_clase text;
begin
  if not exists (select 1 from public.fin_libros l where l.id = new.libro_id and l.titular_id = new.persona_id)
     and not exists (select 1 from public.fin_libro_miembros m
                     where m.libro_id = new.libro_id and m.persona_id = new.persona_id and m.hasta is null)
     and exists (select 1 from public.fin_libros l where l.id = new.libro_id) then
    raise exception using errcode = '22023', message = 'El ingreso es del titular o de un miembro del libro.';
  end if;
  if new.cuenta_origen_id is not null then
    select c.tipo into v_tipo from public.fin_cuentas c where c.id = new.cuenta_origen_id;
    if found and v_tipo <> 'origen_ingreso' then
      raise exception using errcode = '22023', message = 'La cuenta de origen de un ingreso es de tipo origen_ingreso.';
    end if;
  end if;
  if new.cuenta_destino_id is not null then
    select c.clase into v_clase from public.fin_cuentas c where c.id = new.cuenta_destino_id;
    if found and v_clase <> 'activo' then
      raise exception using errcode = '22023', message = 'Un ingreso llega a una cuenta de activo (banco, efectivo…).';
    end if;
  end if;
  return new;
end
$$;

create function public.fin_vigencias_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libro uuid;
begin
  select i.libro_id into v_libro from public.fin_ingresos i where i.hogar_id = new.hogar_id and i.id = new.ingreso_id;
  if found then
    if new.libro_id is null then
      new.libro_id := v_libro;
    elsif new.libro_id <> v_libro then
      raise exception using errcode = '22023', message = 'La vigencia va en el libro de su ingreso.';
    end if;
  end if;
  -- (Con hasta antes de desde responde el check de la tabla.)
  if (new.hasta is null or new.hasta >= new.desde) and exists (
             select 1 from public.fin_vigencias_ingreso v
             where v.ingreso_id = new.ingreso_id and v.id <> new.id
               and daterange(v.desde, v.hasta, '[]') && daterange(new.desde, new.hasta, '[]')) then
    raise exception using errcode = '22023',
      message = 'Las vigencias de un ingreso no se traslapan: cierra la anterior (hasta) antes de la nueva.';
  end if;
  return new;
end
$$;

-- Compromisos y sobres van a una cuenta de gasto del hogar.
create function public.fin_cuenta_de_gasto_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_tipo text;
begin
  if new.cuenta_gasto_id is not null then
    select c.tipo into v_tipo from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_gasto_id;
    if found and v_tipo not in ('de_gasto', 'gasto_financiero') then
      raise exception using errcode = '22023', message = 'La cuenta debe ser una cuenta de gasto del hogar.';
    end if;
  end if;
  return new;
end
$$;

create function public.fin_deudas_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_clase text;
begin
  select c.clase into v_clase from public.fin_cuentas c where c.id = new.cuenta_pasivo_id;
  if found and v_clase <> 'pasivo' then
    raise exception using errcode = '22023', message = 'La cuenta de una deuda es una tarjeta o un préstamo (pasivo).';
  end if;
  return new;
end
$$;

-- Días inhábiles: quién y cuándo revisó, al cambiar activo.
create function public.fin_dias_inhabiles_revisar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.revisado_por := case when new.activo then public.persona_actual() end;
    new.revisado_en  := case when new.activo then now() end;
  elsif new.activo is distinct from old.activo then
    new.revisado_por := public.persona_actual();
    new.revisado_en  := now();
  else
    new.revisado_por := old.revisado_por;
    new.revisado_en  := old.revisado_en;
  end if;
  return new;
end
$$;

-- 13.6 Plan semanal

create function public.fin_semanas_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.estado = 'cerrada' then
      raise exception using errcode = '22023',
        message = 'Una semana nace abierta; se cierra después de guardar su cierre.';
    end if;
    new.reaperturas  := 0;
    new.activada_por := case when new.estado <> 'borrador' then public.persona_actual() end;
    new.activada_en  := case when new.estado <> 'borrador' then now() end;
    return new;
  end if;

  new.reaperturas  := old.reaperturas;
  new.activada_por := old.activada_por;
  new.activada_en  := old.activada_en;
  if old.estado = 'cerrada' then
    -- Reabrir (con confirmación en la app; queda en la bitácora).
    if new.estado = 'cerrada' then
      raise exception using errcode = '55000',
        message = 'La semana está cerrada: se corrige con anulación y contraasiento, o se reabre.';
    end if;
    if (to_jsonb(new) - 'estado') <> (to_jsonb(old) - 'estado') then
      raise exception using errcode = '55000', message = 'Al reabrir una semana solo cambia su estado.';
    end if;
    if new.estado = 'borrador' then
      raise exception using errcode = '22023', message = 'Una semana reabierta no vuelve a borrador.';
    end if;
    new.reaperturas := old.reaperturas + 1;
  elsif new.estado = 'cerrada' then
    if not exists (select 1 from public.fin_cierres c
                   where c.semana_id = new.id and c.version = old.reaperturas + 1) then
      raise exception using errcode = '55000',
        message = format('Antes de cerrar la semana guarda su cierre (versión %s).', old.reaperturas + 1);
    end if;
  end if;
  if new.estado <> 'borrador' and new.activada_en is null then
    new.activada_por := public.persona_actual();
    new.activada_en  := now();
  end if;
  return new;
end
$$;

-- Partidas y abonos: van en el libro de su semana y no cambian si está cerrada.
create function public.fin_plan_de_semana_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libro  uuid;
  v_estado text;
  v_tipo   text;
begin
  select s.libro_id, s.estado into v_libro, v_estado
  from public.fin_semanas s where s.hogar_id = new.hogar_id and s.id = new.semana_id;
  if found then
    if new.libro_id is null then
      new.libro_id := v_libro;
    elsif new.libro_id <> v_libro then
      raise exception using errcode = '22023', message = 'Va en el libro de su semana.';
    end if;
    if v_estado = 'cerrada' then
      raise exception using errcode = '55000',
        message = 'La semana está cerrada: el plan ya no cambia (se corrige con anulación y contraasiento).';
    end if;
  end if;
  if tg_table_name = 'fin_partidas_semana' then
    if new.origen = 'compromiso' and not exists (
        select 1 from public.fin_compromisos c where c.libro_id = new.libro_id and c.id = new.origen_id) then
      raise exception using errcode = '23503', message = 'El compromiso de la partida no existe en ese libro.';
    end if;
    if new.origen = 'sobre' and not exists (
        select 1 from public.fin_sobres s where s.libro_id = new.libro_id and s.id = new.origen_id) then
      raise exception using errcode = '23503', message = 'El sobre de la partida no existe en ese libro.';
    end if;
    if new.cuenta_gasto_id is not null then
      select c.tipo into v_tipo from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_gasto_id;
      if found and v_tipo not in ('de_gasto', 'gasto_financiero') then
        raise exception using errcode = '22023', message = 'La cuenta de una partida es una cuenta de gasto del hogar.';
      end if;
    end if;
  end if;
  return new;
end
$$;

-- Ocurrencias: su origen es del mismo libro; en una semana cerrada no se
-- agregan ni cambian fecha ni monto (el estado y el movimiento sí).
create function public.fin_ocurrencias_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.origen = 'ingreso' and not exists (select 1 from public.fin_ingresos x where x.libro_id = new.libro_id and x.id = new.origen_id))
     or (new.origen = 'compromiso' and not exists (select 1 from public.fin_compromisos x where x.libro_id = new.libro_id and x.id = new.origen_id))
     or (new.origen = 'deuda' and not exists (select 1 from public.fin_deudas x where x.libro_id = new.libro_id and x.id = new.origen_id)) then
    raise exception using errcode = '23503', message = 'El origen de la ocurrencia no existe en ese libro.';
  end if;
  if new.movimiento_id is not null and exists (
      select 1 from public.fin_movimientos m
      where m.id = new.movimiento_id
        and new.libro_id is distinct from m.libro_origen_id and new.libro_id is distinct from m.libro_destino_id) then
    raise exception using errcode = '22023', message = 'El movimiento de una ocurrencia toca su libro.';
  end if;
  if (tg_op = 'INSERT'
      or new.fecha_programada is distinct from old.fecha_programada
      or new.fecha_ajustada is distinct from old.fecha_ajustada
      or new.monto_esperado is distinct from old.monto_esperado)
     and exists (select 1 from public.fin_semanas s
                 where s.libro_id = new.libro_id and s.estado = 'cerrada'
                   and (s.semana_inicio = public.fin_lunes(new.fecha_ajustada)
                        or (tg_op = 'UPDATE' and s.semana_inicio = public.fin_lunes(old.fecha_ajustada)))) then
    raise exception using errcode = '55000',
      message = 'La semana de esa ocurrencia está cerrada: su fecha y su monto ya no cambian.';
  end if;
  return new;
end
$$;

-- 13.7 Cierres, conciliaciones

create function public.fin_cierres_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_semana public.fin_semanas%rowtype;
begin
  select * into v_semana from public.fin_semanas s where s.hogar_id = new.hogar_id and s.id = new.semana_id;
  if found then
    if new.libro_id is null then
      new.libro_id := v_semana.libro_id;
    elsif new.libro_id <> v_semana.libro_id then
      raise exception using errcode = '22023', message = 'El cierre va en el libro de su semana.';
    end if;
    if v_semana.estado = 'cerrada' then
      raise exception using errcode = '55000', message = 'La semana ya está cerrada: reábrela para cerrarla otra vez.';
    end if;
    if new.version <> v_semana.reaperturas + 1 then
      raise exception using errcode = '22023',
        message = format('La versión de este cierre es %s.', v_semana.reaperturas + 1);
    end if;
  end if;
  return new;
end
$$;

create function public.fin_cierre_detalle_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_cierre public.fin_cierres%rowtype;
begin
  select * into v_cierre from public.fin_cierres c where c.hogar_id = new.hogar_id and c.id = new.cierre_id;
  if found then
    if new.libro_id is null then
      new.libro_id := v_cierre.libro_id;
    elsif new.libro_id <> v_cierre.libro_id then
      raise exception using errcode = '22023', message = 'Va en el libro de su cierre.';
    end if;
    if tg_table_name = 'fin_cierre_partidas' then
      if not exists (select 1 from public.fin_partidas_semana p
                     where p.id = new.partida_id and p.semana_id = v_cierre.semana_id) then
        raise exception using errcode = '22023', message = 'La partida es de otra semana.';
      end if;
    end if;
  end if;
  return new;
end
$$;

create function public.fin_conciliaciones_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_cuenta  public.fin_cuentas%rowtype;
  v_mov     public.fin_movimientos%rowtype;
  v_ajustes uuid;
  v_dif     bigint := new.saldo_declarado - new.saldo_calculado;
  v_hacia   boolean;
begin
  select * into v_cuenta from public.fin_cuentas c where c.hogar_id = new.hogar_id and c.id = new.cuenta_id;
  if not found then
    return new;
  end if;
  if new.libro_id is null then
    new.libro_id := v_cuenta.libro_id;
  elsif new.libro_id is distinct from v_cuenta.libro_id then
    raise exception using errcode = '22023', message = 'La conciliación va en el libro de su cuenta.';
  end if;
  if v_cuenta.clase not in ('activo', 'pasivo') then
    raise exception using errcode = '22023', message = 'Solo se concilian activos y pasivos.';
  end if;
  if new.ajuste_movimiento_id is not null then
    select * into v_mov from public.fin_movimientos m where m.hogar_id = new.hogar_id and m.id = new.ajuste_movimiento_id;
    if found then
      select p.cuenta_ajustes_id into v_ajustes from public.fin_parametros p where p.libro_id = new.libro_id;
      -- Sube un activo: Ajustes → cuenta. Sube un pasivo: cuenta → Ajustes.
      v_hacia := case when v_cuenta.clase = 'activo' then v_dif > 0 else v_dif < 0 end;
      if v_mov.tipo <> 'ajuste' or v_mov.monto_centavos <> abs(v_dif) or v_mov.fecha <> new.fecha
         or v_mov.cuenta_origen_id <> (case when v_hacia then v_ajustes else new.cuenta_id end)
         or v_mov.cuenta_destino_id <> (case when v_hacia then new.cuenta_id else v_ajustes end) then
        raise exception using errcode = '22023',
          message = 'El ajuste no corresponde a la diferencia de la conciliación (tipo, monto, fecha o dirección).';
      end if;
    end if;
  end if;
  return new;
end
$$;

-- 13.8 Instalación de los triggers
-- Orden por nombre: fin_a_ (idempotencia o columnas fijas), fin_b_
-- (validación), fin_z_ (bitácora, AFTER).

-- Libros y miembros
create trigger fin_a_columnas_fijas before update on public.fin_libros
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'tipo', 'titular_id', 'creado_por', 'creado_en');
create trigger fin_b_validar before insert on public.fin_libros
  for each row execute function public.fin_libros_validar();
create trigger fin_c_al_crear after insert on public.fin_libros
  for each row execute function public.fin_libros_al_crear();
create trigger fin_a_columnas_fijas before update on public.fin_libro_miembros
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'persona_id');
create trigger fin_b_validar before insert or update on public.fin_libro_miembros
  for each row execute function public.fin_libro_miembros_validar();
create trigger fin_libro_personal after insert or update of rol, activa on public.membresias
  for each row execute function public.fin_libro_personal_por_membresia();

-- Configuración (idempotencia flexible: ON CONFLICT o la llave resuelven el resto)
create trigger fin_a_una_vez before insert on public.fin_categorias
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_categorias
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id');
create trigger fin_b_validar before insert or update on public.fin_categorias
  for each row execute function public.fin_categorias_validar();

create trigger fin_a_una_vez before insert on public.fin_cuentas
  for each row execute function public.fin_una_vez('flexible', 'clase', 'liquida', 'creada_por', 'creada_en');
create trigger fin_a_columnas_fijas before update on public.fin_cuentas
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id');
create trigger fin_b_al_insertar before insert on public.fin_cuentas
  for each row execute function public.fin_cuentas_al_insertar();
create trigger fin_b_al_cambiar before update on public.fin_cuentas
  for each row execute function public.fin_cuentas_al_cambiar();

create trigger fin_a_columnas_fijas before update on public.fin_parametros
  for each row execute function public.fin_columnas_fijas('libro_id', 'hogar_id', 'cuenta_ajustes_id',
                                                          'cuenta_apertura_id', 'cuenta_por_clasificar_id');

create trigger fin_a_una_vez before insert on public.fin_ingresos
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_ingresos
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id');
create trigger fin_b_validar before insert or update on public.fin_ingresos
  for each row execute function public.fin_ingresos_validar();

create trigger fin_a_una_vez before insert on public.fin_vigencias_ingreso
  for each row execute function public.fin_una_vez('flexible', 'libro_id');
create trigger fin_a_columnas_fijas before update on public.fin_vigencias_ingreso
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'ingreso_id');
create trigger fin_b_validar before insert or update on public.fin_vigencias_ingreso
  for each row execute function public.fin_vigencias_validar();

create trigger fin_a_una_vez before insert on public.fin_compromisos
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_compromisos
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id');
create trigger fin_b_validar before insert or update on public.fin_compromisos
  for each row execute function public.fin_cuenta_de_gasto_validar();

create trigger fin_a_una_vez before insert on public.fin_sobres
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_sobres
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id');
create trigger fin_b_validar before insert or update on public.fin_sobres
  for each row execute function public.fin_cuenta_de_gasto_validar();

create trigger fin_a_una_vez before insert on public.fin_deudas
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_deudas
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id');
create trigger fin_b_validar before insert or update on public.fin_deudas
  for each row execute function public.fin_deudas_validar();

create trigger fin_a_una_vez before insert on public.fin_dias_inhabiles
  for each row execute function public.fin_una_vez('flexible', 'revisado_por', 'revisado_en');
create trigger fin_a_columnas_fijas before update on public.fin_dias_inhabiles
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id');
create trigger fin_b_revisar before insert or update on public.fin_dias_inhabiles
  for each row execute function public.fin_dias_inhabiles_revisar();

-- Plan semanal
create trigger fin_a_una_vez before insert on public.fin_semanas
  for each row execute function public.fin_una_vez('flexible', 'activada_por', 'activada_en', 'reaperturas');
create trigger fin_a_columnas_fijas before update on public.fin_semanas
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'semana_inicio');
create trigger fin_b_validar before insert or update on public.fin_semanas
  for each row execute function public.fin_semanas_validar();

create trigger fin_a_una_vez before insert on public.fin_partidas_semana
  for each row execute function public.fin_una_vez('flexible', 'libro_id');
create trigger fin_a_columnas_fijas before update on public.fin_partidas_semana
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'semana_id', 'origen', 'origen_id');
create trigger fin_b_validar before insert or update on public.fin_partidas_semana
  for each row execute function public.fin_plan_de_semana_validar();

create trigger fin_a_una_vez before insert on public.fin_abonos_semana
  for each row execute function public.fin_una_vez('flexible', 'libro_id');
create trigger fin_a_columnas_fijas before update on public.fin_abonos_semana
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'semana_id', 'deuda_id');
create trigger fin_b_validar before insert or update on public.fin_abonos_semana
  for each row execute function public.fin_plan_de_semana_validar();

create trigger fin_a_una_vez before insert on public.fin_ocurrencias
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_ocurrencias
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'origen', 'origen_id');
create trigger fin_b_validar before insert or update on public.fin_ocurrencias
  for each row execute function public.fin_ocurrencias_validar();

-- Libros SOLO AGREGAR: idempotencia estricta, validación y los dos triggers
-- de impedir_cambios_solo_agregar() (fila y TRUNCATE), como la bitácora.
create trigger fin_a_validar before insert on public.fin_movimientos
  for each row execute function public.fin_movimientos_validar();

create trigger fin_a_una_vez before insert on public.fin_conciliaciones
  for each row execute function public.fin_una_vez('estricto', 'diferencia', 'creado_en', 'libro_id');
create trigger fin_b_validar before insert on public.fin_conciliaciones
  for each row execute function public.fin_conciliaciones_validar();

create trigger fin_a_una_vez before insert on public.fin_cierres
  for each row execute function public.fin_una_vez('estricto', 'cerrado_en', 'libro_id');
create trigger fin_b_validar before insert on public.fin_cierres
  for each row execute function public.fin_cierres_validar();

create trigger fin_a_una_vez before insert on public.fin_cierre_partidas
  for each row execute function public.fin_una_vez('estricto', 'libro_id');
create trigger fin_b_validar before insert on public.fin_cierre_partidas
  for each row execute function public.fin_cierre_detalle_validar();

create trigger fin_a_una_vez before insert on public.fin_cierre_abonos
  for each row execute function public.fin_una_vez('estricto', 'diferido', 'libro_id');
create trigger fin_b_validar before insert on public.fin_cierre_abonos
  for each row execute function public.fin_cierre_detalle_validar();

create trigger fin_a_una_vez before insert on public.fin_importaciones
  for each row execute function public.fin_una_vez('estricto', 'creado_en');

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_movimientos', 'fin_conciliaciones', 'fin_cierres',
                                 'fin_cierre_partidas', 'fin_cierre_abonos', 'fin_importaciones']
  loop
    execute format('create trigger fin_solo_agregar before update or delete on public.%I
                      for each row execute function public.impedir_cambios_solo_agregar()', v_tabla);
    execute format('create trigger fin_sin_truncate before truncate on public.%I
                      for each statement execute function public.impedir_cambios_solo_agregar()', v_tabla);
  end loop;
end
$$;

-- Bitácora de todo cambio en Finanzas (detalle de importaciones fuera: puede ser grande).
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array[
      'fin_libros', 'fin_libro_miembros', 'fin_categorias', 'fin_cuentas', 'fin_parametros',
      'fin_movimientos', 'fin_ingresos', 'fin_vigencias_ingreso', 'fin_compromisos', 'fin_sobres',
      'fin_deudas', 'fin_dias_inhabiles', 'fin_semanas', 'fin_partidas_semana', 'fin_abonos_semana',
      'fin_cierres', 'fin_cierre_partidas', 'fin_cierre_abonos', 'fin_ocurrencias', 'fin_conciliaciones']
  loop
    execute format('create trigger fin_z_bitacora after insert or update or delete on public.%I
                      for each row execute function public.registrar_cambio_en_bitacora(''hogar_id'')', v_tabla);
  end loop;
end
$$;
create trigger fin_z_bitacora after insert or update or delete on public.fin_importaciones
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'detalle');

-- -----------------------------------------------------------------------------
-- 14. Vistas de apoyo (security_invoker: respetan la RLS de quien consulta)
-- -----------------------------------------------------------------------------
-- Cada movimiento son dos asientos: + en destino y − en origen. El libro de
-- un asiento es el de su cuenta o, en una cuenta de gasto del hogar, el del
-- otro lado del movimiento (así el gasto se reparte por libro).
create view public.fin_v_saldos with (security_invoker = true) as
with asientos as (
  select m.cuenta_destino_id as cuenta_id, coalesce(m.libro_destino_id, m.libro_origen_id) as libro_id,
         m.monto_centavos as delta, m.estado_inicial
  from public.fin_movimientos m
  union all
  select m.cuenta_origen_id, coalesce(m.libro_origen_id, m.libro_destino_id),
         -m.monto_centavos, m.estado_inicial
  from public.fin_movimientos m
), por_cuenta as (
  select a.cuenta_id, a.libro_id,
         sum(a.delta) filter (where a.estado_inicial = 'confirmado') as confirmado,
         sum(a.delta) as con_pendientes
  from asientos a
  group by a.cuenta_id, a.libro_id
)
select c.hogar_id,
       coalesce(p.libro_id, c.libro_id) as libro_id,
       c.id as cuenta_id, c.nombre, c.tipo, c.clase, c.liquida, c.estado,
       (case when c.clase in ('activo', 'gasto') then 1 else -1 end) * coalesce(p.confirmado, 0)::bigint
         as saldo_centavos,
       (case when c.clase in ('activo', 'gasto') then 1 else -1 end) * coalesce(p.con_pendientes, 0)::bigint
         as saldo_con_pendientes_centavos
from public.fin_cuentas c
left join por_cuenta p on p.cuenta_id = c.id;
comment on view public.fin_v_saldos is
  'Saldo confirmado por cuenta con el signo de su clase (en una tarjeta, lo que se debe). Las cuentas de '
  'gasto del hogar salen una vez por libro (lo que gastó cada libro que puedes leer).';

create view public.fin_v_gasto_semana with (security_invoker = true) as
with asientos as (
  select m.cuenta_destino_id as cuenta_id, coalesce(m.libro_destino_id, m.libro_origen_id) as libro_id,
         m.fecha, m.monto_centavos as delta
  from public.fin_movimientos m where m.estado_inicial = 'confirmado'
  union all
  select m.cuenta_origen_id, coalesce(m.libro_origen_id, m.libro_destino_id), m.fecha, -m.monto_centavos
  from public.fin_movimientos m where m.estado_inicial = 'confirmado'
)
select c.hogar_id, a.libro_id, public.fin_lunes(a.fecha) as semana_inicio,
       c.id as cuenta_id, c.nombre, c.tipo,
       sum(a.delta)::bigint as gasto_centavos
from asientos a
join public.fin_cuentas c on c.id = a.cuenta_id
where c.clase = 'gasto'
group by c.hogar_id, a.libro_id, public.fin_lunes(a.fecha), c.id, c.nombre, c.tipo;
comment on view public.fin_v_gasto_semana is
  'Gasto neto confirmado por libro, cuenta de gasto y semana (lunes): gastos − reembolsos ± anulaciones '
  'y reclasificaciones, por la fecha económica del movimiento.';

-- -----------------------------------------------------------------------------
-- 15. Reglas por registro (RLS)
-- -----------------------------------------------------------------------------
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array[
      'fin_libros', 'fin_libro_miembros', 'fin_categorias', 'fin_cuentas', 'fin_parametros',
      'fin_movimientos', 'fin_ingresos', 'fin_vigencias_ingreso', 'fin_compromisos', 'fin_sobres',
      'fin_deudas', 'fin_dias_inhabiles', 'fin_semanas', 'fin_partidas_semana', 'fin_abonos_semana',
      'fin_cierres', 'fin_cierre_partidas', 'fin_cierre_abonos', 'fin_ocurrencias', 'fin_conciliaciones',
      'fin_importaciones']
  loop
    execute format('alter table public.%I enable row level security', v_tabla);
  end loop;
end
$$;

-- Libros: cada quien los suyos, los compartidos de los que es miembro y, si
-- es albacea, el de papá; la cuenta maestra lee todos. El personal lo crea el
-- servidor (o la persona para sí); el representado, fin_crear_libro_representado().
create policy fin_libros_leer on public.fin_libros for select to authenticated
  using (public.fin_puede(id, 'leer'));
create policy fin_libros_agregar on public.fin_libros for insert to authenticated
  with check (creado_por = (select public.persona_actual())
              and public.fin_puede_hogar(hogar_id, 'administrar')
              and ((tipo = 'personal' and titular_id = (select public.persona_actual()))
                   or tipo = 'compartido'));
create policy fin_libros_editar on public.fin_libros for update to authenticated
  using (public.fin_puede(id, 'administrar'))
  with check (public.fin_puede(id, 'administrar'));

create policy fin_libro_miembros_leer on public.fin_libro_miembros for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_libro_miembros_agregar on public.fin_libro_miembros for insert to authenticated
  with check (public.fin_puede(libro_id, 'administrar'));
create policy fin_libro_miembros_editar on public.fin_libro_miembros for update to authenticated
  using (public.fin_puede(libro_id, 'administrar'))
  with check (public.fin_puede(libro_id, 'administrar'));

-- Del hogar: categorías y días inhábiles.
create policy fin_categorias_leer on public.fin_categorias for select to authenticated
  using (public.fin_puede_hogar(hogar_id, 'leer'));
create policy fin_categorias_agregar on public.fin_categorias for insert to authenticated
  with check (public.fin_puede_hogar(hogar_id, 'administrar'));
create policy fin_categorias_editar on public.fin_categorias for update to authenticated
  using (public.fin_puede_hogar(hogar_id, 'administrar'))
  with check (public.fin_puede_hogar(hogar_id, 'administrar'));
create policy fin_categorias_borrar on public.fin_categorias for delete to authenticated
  using (public.fin_puede_hogar(hogar_id, 'administrar'));

create policy fin_dias_inhabiles_leer on public.fin_dias_inhabiles for select to authenticated
  using (public.fin_puede_hogar(hogar_id, 'leer'));
create policy fin_dias_inhabiles_agregar on public.fin_dias_inhabiles for insert to authenticated
  with check (public.fin_puede_hogar(hogar_id, 'administrar'));
create policy fin_dias_inhabiles_editar on public.fin_dias_inhabiles for update to authenticated
  using (public.fin_puede_hogar(hogar_id, 'administrar'))
  with check (public.fin_puede_hogar(hogar_id, 'administrar'));

-- Cuentas: las de gasto son del hogar; las demás, de su libro.
create policy fin_cuentas_leer on public.fin_cuentas for select to authenticated
  using (case when libro_id is null then public.fin_puede_hogar(hogar_id, 'leer')
              else public.fin_puede(libro_id, 'leer') end);
create policy fin_cuentas_agregar on public.fin_cuentas for insert to authenticated
  with check (case when libro_id is null then public.fin_puede_hogar(hogar_id, 'administrar')
                   else public.fin_puede(libro_id, 'administrar') end);
create policy fin_cuentas_editar on public.fin_cuentas for update to authenticated
  using (case when libro_id is null then public.fin_puede_hogar(hogar_id, 'administrar')
              else public.fin_puede(libro_id, 'administrar') end)
  with check (case when libro_id is null then public.fin_puede_hogar(hogar_id, 'administrar')
                   else public.fin_puede(libro_id, 'administrar') end);
create policy fin_cuentas_borrar on public.fin_cuentas for delete to authenticated
  using (case when libro_id is null then public.fin_puede_hogar(hogar_id, 'administrar')
              else public.fin_puede(libro_id, 'administrar') end);

-- Configuración de cada libro: leer / administrar.
create policy fin_parametros_leer on public.fin_parametros for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_parametros_agregar on public.fin_parametros for insert to authenticated
  with check (public.fin_puede(libro_id, 'administrar'));
create policy fin_parametros_editar on public.fin_parametros for update to authenticated
  using (public.fin_puede(libro_id, 'administrar'))
  with check (public.fin_puede(libro_id, 'administrar'));

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_ingresos', 'fin_vigencias_ingreso', 'fin_compromisos', 'fin_sobres', 'fin_deudas']
  loop
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (public.fin_puede(libro_id, 'leer'))$f$, v_tabla);
    execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                        with check (public.fin_puede(libro_id, 'administrar'))$f$, v_tabla);
    execute format($f$create policy %1$s_editar on public.%1$I for update to authenticated
                        using (public.fin_puede(libro_id, 'administrar'))
                        with check (public.fin_puede(libro_id, 'administrar'))$f$, v_tabla);
  end loop;
  -- Plan: leer / escribir (nunca en una semana cerrada: triggers).
  foreach v_tabla in array array['fin_semanas', 'fin_partidas_semana', 'fin_abonos_semana', 'fin_ocurrencias']
  loop
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (public.fin_puede(libro_id, 'leer'))$f$, v_tabla);
    execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                        with check (public.fin_puede(libro_id, 'escribir'))$f$, v_tabla);
    execute format($f$create policy %1$s_editar on public.%1$I for update to authenticated
                        using (public.fin_puede(libro_id, 'escribir'))
                        with check (public.fin_puede(libro_id, 'escribir'))$f$, v_tabla);
  end loop;
  -- Solo agregar: leer / agregar; sin reglas de UPDATE ni DELETE.
  foreach v_tabla in array array['fin_cierre_partidas', 'fin_cierre_abonos']
  loop
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (public.fin_puede(libro_id, 'leer'))$f$, v_tabla);
    execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                        with check (public.fin_puede(libro_id, 'escribir'))$f$, v_tabla);
  end loop;
end
$$;

-- Movimientos: se ven desde cualquiera de sus dos libros; para registrar hay
-- que poder escribir en cada libro que tocan, siempre a nombre propio.
create policy fin_movimientos_leer on public.fin_movimientos for select to authenticated
  using (public.fin_puede(libro_origen_id, 'leer') or public.fin_puede(libro_destino_id, 'leer'));
create policy fin_movimientos_agregar on public.fin_movimientos for insert to authenticated
  with check (registrado_por = (select public.persona_actual())
              and (libro_origen_id is not null or libro_destino_id is not null)
              and (libro_origen_id is null or public.fin_puede(libro_origen_id, 'escribir'))
              and (libro_destino_id is null or public.fin_puede(libro_destino_id, 'escribir')));

create policy fin_conciliaciones_leer on public.fin_conciliaciones for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_conciliaciones_agregar on public.fin_conciliaciones for insert to authenticated
  with check (persona_id = (select public.persona_actual()) and public.fin_puede(libro_id, 'escribir'));

create policy fin_cierres_leer on public.fin_cierres for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_cierres_agregar on public.fin_cierres for insert to authenticated
  with check (cerrado_por = (select public.persona_actual()) and public.fin_puede(libro_id, 'escribir'));

create policy fin_importaciones_leer on public.fin_importaciones for select to authenticated
  using (public.fin_puede_hogar(hogar_id, 'leer'));
create policy fin_importaciones_agregar on public.fin_importaciones for insert to authenticated
  with check (persona_id = (select public.persona_actual()) and public.fin_puede_hogar(hogar_id, 'administrar'));

-- Bitácora (D18, D19): cada quien lo suyo; el resto según
-- puede_ver_entrada_bitacora() (el dueño ya no ve las finanzas personales de
-- la pareja ni su historial de GRAVITY; la cuenta maestra ve todo).
drop policy bitacora_leer on public.bitacora;
create policy bitacora_leer on public.bitacora
  for select to authenticated
  using (persona_id = (select public.persona_actual())
         or public.puede_ver_entrada_bitacora(hogar_id, tabla, accion, registro_id, detalle));

-- -----------------------------------------------------------------------------
-- 16. Privilegios explícitos (por columna: lo que pone el servidor no se manda)
-- -----------------------------------------------------------------------------
revoke all on table
  public.fin_libros, public.fin_libro_miembros, public.fin_categorias, public.fin_cuentas,
  public.fin_parametros, public.fin_movimientos, public.fin_ingresos, public.fin_vigencias_ingreso,
  public.fin_compromisos, public.fin_sobres, public.fin_deudas, public.fin_dias_inhabiles,
  public.fin_semanas, public.fin_partidas_semana, public.fin_abonos_semana, public.fin_cierres,
  public.fin_cierre_partidas, public.fin_cierre_abonos, public.fin_ocurrencias,
  public.fin_conciliaciones, public.fin_importaciones, public.fin_v_saldos, public.fin_v_gasto_semana
  from public, anon, authenticated, service_role;

grant select on
  public.fin_libros, public.fin_libro_miembros, public.fin_categorias, public.fin_cuentas,
  public.fin_parametros, public.fin_movimientos, public.fin_ingresos, public.fin_vigencias_ingreso,
  public.fin_compromisos, public.fin_sobres, public.fin_deudas, public.fin_dias_inhabiles,
  public.fin_semanas, public.fin_partidas_semana, public.fin_abonos_semana, public.fin_cierres,
  public.fin_cierre_partidas, public.fin_cierre_abonos, public.fin_ocurrencias,
  public.fin_conciliaciones, public.fin_importaciones, public.fin_v_saldos, public.fin_v_gasto_semana
  to authenticated, service_role;

-- Configuración y plan: insertar y cambiar las columnas de la app. Las llaves
-- (id, hogar_id, libro_id…) también, para que funcione upsert (PostgREST pone
-- todas las columnas en el SET); los triggers fin_a_columnas_fijas impiden
-- que cambien de verdad.
grant insert (id, hogar_id, nombre, tipo, titular_id, activo),
      update (id, hogar_id, nombre, tipo, titular_id, activo)
  on public.fin_libros to authenticated;
grant insert (id, hogar_id, libro_id, persona_id, papel, desde, hasta),
      update (id, hogar_id, libro_id, persona_id, papel, desde, hasta)
  on public.fin_libro_miembros to authenticated;
grant insert (id, hogar_id, padre_id, nivel, nombre, icono, color, naturaleza, prioridad, protegida,
              es_del_sistema, oculta, archivada, posiblemente_deducible, cuenta_gasto_id),
      update (id, hogar_id, padre_id, nivel, nombre, icono, color, naturaleza, prioridad, protegida,
              es_del_sistema, oculta, archivada, posiblemente_deducible, cuenta_gasto_id),
      delete
  on public.fin_categorias to authenticated;
grant insert (id, hogar_id, libro_id, nombre, tipo, estado, categoria_id, limite_centavos, creada_por),
      update (id, hogar_id, libro_id, nombre, tipo, estado, categoria_id, limite_centavos, creada_por),
      delete
  on public.fin_cuentas to authenticated;
grant insert (libro_id, hogar_id, meta_remanente_pb, ahorro_minimo_con_deuda_pb, tope_arrastre_semanas,
              partida_ambar_pb, partida_rojo_pb, remanente_verde_pb, remanente_ambar_pb, carga_ambar_pb,
              carga_rojo_pb, cumplimiento_verde_pb, cumplimiento_ambar_pb, cierre_automatico_dias,
              cuenta_ajustes_id, cuenta_apertura_id, cuenta_por_clasificar_id),
      update (libro_id, hogar_id, meta_remanente_pb, ahorro_minimo_con_deuda_pb, tope_arrastre_semanas,
              partida_ambar_pb, partida_rojo_pb, remanente_verde_pb, remanente_ambar_pb, carga_ambar_pb,
              carga_rojo_pb, cumplimiento_verde_pb, cumplimiento_ambar_pb, cierre_automatico_dias,
              cuenta_ajustes_id, cuenta_apertura_id, cuenta_por_clasificar_id)
  on public.fin_parametros to authenticated;
grant insert (id, hogar_id, libro_id, persona_id, nombre, tipo, cuenta_origen_id, cuenta_destino_id, certeza, activo),
      update (id, hogar_id, libro_id, persona_id, nombre, tipo, cuenta_origen_id, cuenta_destino_id, certeza, activo)
  on public.fin_ingresos to authenticated;
grant insert (id, hogar_id, libro_id, ingreso_id, monto_neto_centavos, forma, dia_semana, dias_mes,
              fecha_ancla, intervalo_meses, regla_inhabil, desde, hasta),
      update (id, hogar_id, libro_id, ingreso_id, monto_neto_centavos, forma, dia_semana, dias_mes,
              fecha_ancla, intervalo_meses, regla_inhabil, desde, hasta)
  on public.fin_vigencias_ingreso to authenticated;
grant insert (id, hogar_id, libro_id, nombre, tipo, cuenta_gasto_id, categoria_id, monto_centavos, frecuencia,
              dias_activos, forma, dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil,
              protegida, prioridad, desde, hasta, activo),
      update (id, hogar_id, libro_id, nombre, tipo, cuenta_gasto_id, categoria_id, monto_centavos, frecuencia,
              dias_activos, forma, dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil,
              protegida, prioridad, desde, hasta, activo)
  on public.fin_compromisos to authenticated;
grant insert (id, hogar_id, libro_id, cuenta_gasto_id, nombre, monto_semanal_centavos, protegida, prioridad,
              piso_minimo_centavos, modo_arrastre, activo),
      update (id, hogar_id, libro_id, cuenta_gasto_id, nombre, monto_semanal_centavos, protegida, prioridad,
              piso_minimo_centavos, modo_arrastre, activo)
  on public.fin_sobres to authenticated;
grant insert (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma,
              dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil, minimo_centavos,
              tasa_anual_pb, prioridad_manual, grupo_prioritario, orden_grupo, activa),
      update (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma,
              dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil, minimo_centavos,
              tasa_anual_pb, prioridad_manual, grupo_prioritario, orden_grupo, activa)
  on public.fin_deudas to authenticated;
grant insert (id, hogar_id, fecha, nombre, tipo, fuente, activo, revisado_por, revisado_en),
      update (id, hogar_id, fecha, nombre, tipo, fuente, activo, revisado_por, revisado_en)
  on public.fin_dias_inhabiles to authenticated;
grant insert (id, hogar_id, libro_id, semana_inicio, estado, metodo, ingreso, presupuesto, deuda_plan,
              remanente_plan, meta_remanente_pb, ahorro_minimo_con_deuda_pb, techo, activada_por, activada_en),
      update (id, hogar_id, libro_id, semana_inicio, estado, metodo, ingreso, presupuesto, deuda_plan,
              remanente_plan, meta_remanente_pb, ahorro_minimo_con_deuda_pb, techo, activada_por, activada_en)
  on public.fin_semanas to authenticated;
grant insert (id, hogar_id, libro_id, semana_id, origen, origen_id, cuenta_gasto_id, tipo, asignado,
              arrastre_recibido, protegida, prioridad, piso_minimo, modo_arrastre),
      update (id, hogar_id, libro_id, semana_id, origen, origen_id, cuenta_gasto_id, tipo, asignado,
              arrastre_recibido, protegida, prioridad, piso_minimo, modo_arrastre)
  on public.fin_partidas_semana to authenticated;
grant insert (id, hogar_id, libro_id, semana_id, deuda_id, abono_planeado, minimo, extra_planeado),
      update (id, hogar_id, libro_id, semana_id, deuda_id, abono_planeado, minimo, extra_planeado)
  on public.fin_abonos_semana to authenticated;
grant insert (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado,
              estado, movimiento_id),
      update (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado,
              estado, movimiento_id)
  on public.fin_ocurrencias to authenticated;

-- Solo agregar: solo INSERT, sin las columnas que pone el servidor.
grant insert (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id, monto_centavos,
              categoria_id, grupo_id, realizado_por, registrado_por, en_nombre_de, via, nota, motivo,
              anula_a, estado_inicial)
  on public.fin_movimientos to authenticated;
grant insert (id, hogar_id, libro_id, cuenta_id, fecha, saldo_declarado, saldo_calculado,
              ajuste_movimiento_id, motivo, persona_id, creado_en)
  on public.fin_conciliaciones to authenticated;
grant insert (id, hogar_id, libro_id, semana_id, version, ingreso_real, gasto_real, abono_real, abono_diferido,
              abono_extra_real, ahorro_real, deficit, arrastre_siguiente, accion_elegida, con_pendientes,
              activos, pasivos, patrimonio, cerrado_por, cerrado_en)
  on public.fin_cierres to authenticated;
grant insert (id, hogar_id, libro_id, cierre_id, partida_id, gastado, arrastre_siguiente, al_remanente)
  on public.fin_cierre_partidas to authenticated;
grant insert (id, hogar_id, libro_id, cierre_id, deuda_id, planeado, "real", minimo)
  on public.fin_cierre_abonos to authenticated;
grant insert (id, hogar_id, archivo, hoja, filas_leidas, filas_creadas, filas_omitidas, detalle, persona_id,
              creado_en)
  on public.fin_importaciones to authenticated;

-- service_role (funciones de servidor): configuración y plan completos; los
-- libros solo agregar, solo INSERT. Sin TRUNCATE.
grant insert, update on
  public.fin_libros, public.fin_libro_miembros, public.fin_categorias, public.fin_cuentas,
  public.fin_parametros, public.fin_ingresos, public.fin_vigencias_ingreso, public.fin_compromisos,
  public.fin_sobres, public.fin_deudas, public.fin_dias_inhabiles, public.fin_semanas,
  public.fin_partidas_semana, public.fin_abonos_semana, public.fin_ocurrencias
  to service_role;
grant delete on public.fin_categorias, public.fin_cuentas to service_role;
grant insert on
  public.fin_movimientos, public.fin_conciliaciones, public.fin_cierres, public.fin_cierre_partidas,
  public.fin_cierre_abonos, public.fin_importaciones
  to service_role;

-- Funciones: nada para anon ni PUBLIC. Las de las reglas y las RPC, para
-- authenticated; las de los triggers, para nadie (se ejecutan igual).
revoke execute on function
  public.es_cuenta_maestra(uuid), public.fin_puede_hogar(uuid, text), public.fin_es_miembro(uuid),
  public.fin_puede(uuid, text), public.puede_ver_entrada_bitacora(uuid, text, text, text, jsonb),
  public.asignar_cuenta_maestra(uuid, uuid), public.cuenta_maestra(uuid),
  public.fin_registrar_consulta_maestra(uuid), public.fin_crear_libro_representado(uuid, text, text, uuid),
  public.fin_lunes(date),
  public.fin_una_vez(), public.fin_columnas_fijas(), public.fin_libros_validar(), public.fin_libros_al_crear(),
  public.fin_libro_personal_por_membresia(), public.fin_libro_miembros_validar(),
  public.fin_categorias_validar(), public.fin_cuentas_al_insertar(), public.fin_cuentas_al_cambiar(),
  public.fin_movimientos_validar(), public.fin_ingresos_validar(), public.fin_vigencias_validar(),
  public.fin_cuenta_de_gasto_validar(), public.fin_deudas_validar(), public.fin_dias_inhabiles_revisar(),
  public.fin_semanas_validar(), public.fin_plan_de_semana_validar(), public.fin_ocurrencias_validar(),
  public.fin_cierres_validar(), public.fin_cierre_detalle_validar(), public.fin_conciliaciones_validar()
  from public, anon, authenticated, service_role;

grant execute on function
  public.es_cuenta_maestra(uuid), public.fin_puede_hogar(uuid, text), public.fin_es_miembro(uuid),
  public.fin_puede(uuid, text), public.puede_ver_entrada_bitacora(uuid, text, text, text, jsonb),
  public.cuenta_maestra(uuid), public.fin_lunes(date)
  to authenticated, service_role;
grant execute on function
  public.asignar_cuenta_maestra(uuid, uuid), public.fin_registrar_consulta_maestra(uuid),
  public.fin_crear_libro_representado(uuid, text, text, uuid)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 17. Matriz de permisos (D18, D19)
-- -----------------------------------------------------------------------------
update public.permisos_rol
   set alcance = 'propio',
       nota = 'D19: su libro personal y los compartidos de los que es miembro (fin_puede); albacea del libro de papá'
 where rol = 'dueno' and modulo = 'finanzas';
update public.permisos_rol
   set alcance = 'propio',
       nota = 'D19 (P1): su libro personal y los compartidos; no ve las finanzas personales del dueño'
 where rol = 'coadministrador' and modulo = 'finanzas';
update public.permisos_rol
   set alcance = 'propio',
       nota = 'D18: cada quien su historial, también el dueño; la cuenta maestra (D19) ve todo'
 where rol = 'dueno' and modulo = 'gravity';
insert into public.permisos_rol (rol, modulo, accion, alcance, nota) values
  ('coadministrador', 'finanzas', 'escribir',    'propio',      'D19 (P2): registra en su libro y en los compartidos'),
  ('coadministrador', 'finanzas', 'administrar', 'propio',      'D19: administra su libro y los compartidos de los que es miembro'),
  ('cuidador',        'gravity',  'leer',        'restringido', 'D18: solo sus solicitudes y recordatorios'),
  ('cuidador',        'gravity',  'escribir',    'restringido', 'D18: confirma sus solicitudes y recordatorios');

-- -----------------------------------------------------------------------------
-- 18. Libros personales de quienes ya tenían un rol con Finanzas (proyecto real)
-- -----------------------------------------------------------------------------
insert into public.fin_libros (hogar_id, nombre, tipo, titular_id, creado_por)
select m.hogar_id, left('Finanzas de ' || p.nombre_visible, 80), 'personal', m.persona_id, m.persona_id
from public.membresias m
join public.personas p on p.id = m.persona_id
where m.activa and m.rol in ('dueno', 'coadministrador')
  and not exists (select 1 from public.fin_libros l
                  where l.hogar_id = m.hogar_id and l.titular_id = m.persona_id and l.tipo = 'personal');
