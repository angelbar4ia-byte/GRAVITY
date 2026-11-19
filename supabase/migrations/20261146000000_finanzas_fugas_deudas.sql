-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, bloque 6: fugas silenciosas y deuda buena o mala
-- (docs/specs/fase-8-fugas-y-deudas.md v0.3, secciones 6, 7, 8.3 y 10.3; D3, D5, D19, D20, D24, D30)
-- =============================================================================
-- Qué hace (todo el cálculo de fugas y del semáforo es LOCAL, en el dispositivo; el servidor solo guarda lo que la
-- persona declara o responde y protege quién lo ve):
--
-- 1. Columnas opcionales en tablas existentes (el libro sigue solo-agregar):
--      fin_movimientos.comercio (≤ 80) y .cobro_automatico   (solo se llenan al insertar; la bitácora omite el comercio)
--      fin_msi.precio_contado_centavos                       (solo al crear el MSI)
--      fin_estados_cuenta.pagos_al_corte_centavos            (pagos entre el corte y la fecha límite: B6b y V-D)
-- 2. Seis tablas nuevas, TODAS solo-agregar (sin update ni delete para nadie; "lo vigente" es la fila más reciente o
--    la que ninguna otra reemplaza) y con escritura únicamente por RPC security definer:
--      fin_fuga_parametros      umbrales por libro (historial; vigente = el último)
--      fin_patrones_cobro       un cobro que se repite o una subcategoría hormiga vigilada (inmutable)
--      fin_fuga_clasificaciones decisión de la persona (o de la regla) y su historial (reemplaza_a)
--      fin_fuga_respuestas      reconoce, uso, ya no sirve..., cancelado (con fecha y folio), con historial
--      fin_deuda_propositos     para qué fue una deuda, estado del objetivo, "lo uso poco" y precio de contado
--      fin_deuda_semaforo       historial de cambios del nivel mostrado (avisar una vez y la histéresis)
--    El estado de un patrón (protegido, cancelado, cancelado sin folio) NO se edita: se deriva de sus
--    clasificaciones y respuestas (vista fin_v_patrones_estado).
-- 3. RPC (6.3): fin_patron_crear, fin_fuga_responder, fin_fuga_clasificar, fin_patron_cancelar, fin_deuda_declarar,
--    fin_fuga_parametros_cambiar y fin_deuda_semaforo_registrar.
-- 4. Permisos (7): lectura con fin_fugas_puede_ver(libro) = fin_deudas_puede_ver (la regla de deudas y tarjetas) más rol
--    dueño o coadministrador (excluye la vista temporal de Papá, D24); escritura con fin_puede(libro,'escribir') Y esa
--    lectura (declarar propósito y cambiar umbrales: 'administrar').
--    Familiar, cuidador, Casa, la tablet pública y la vista temporal de Papá (D24) no leen ni escriben nada; la cuenta
--    maestra solo lee, con consulta vigente. En el libro de Papá toda decisión queda "en nombre de" con motivo (D19).
-- 5. Avisos (8.3): catálogo cerrado con cuatro tipos nuevos (fuga_por_reconocer, fuga_revision_mensual,
--    deuda_en_vigilancia, deuda_se_volvio_mala), objeto 'patron', severidades, tipos emitibles, destinatarios y
--    silenciables. Los avisos no tienen columnas de texto, monto ni nombre (D3, D20): el título genérico vive en el
--    catálogo (aquí, fin_fugas_aviso_titulo, solo para que una prueba verifique que no lleva dígitos, "$" ni pasa de 40).
-- Dinero en bigint de centavos; porcentajes en puntos base. Migración hacia adelante. Sin secretos ni datos reales.
-- =============================================================================

-- 1. Columnas en tablas existentes ---------------------------------------------------------------------------------
alter table public.fin_movimientos
  add column comercio text check (comercio is null or char_length(btrim(comercio)) between 1 and 80),
  add column cobro_automatico boolean not null default false;
comment on column public.fin_movimientos.comercio is
  'Opcional (hasta 80). Dato del libro: jamás sale en un aviso, a la IA ni a las bocinas (D3, D20). Solo se llena al insertar.';
comment on column public.fin_movimientos.cobro_automatico is
  'Verdadero = la persona marcó "es un cargo automático" (o viene de una importación). Solo al insertar.';
grant insert (comercio, cobro_automatico) on public.fin_movimientos to authenticated;

-- La bitácora de movimientos ya no copia el comercio (es un dato del libro, no de auditoría).
drop trigger fin_z_bitacora on public.fin_movimientos;
create trigger fin_z_bitacora after insert or update or delete on public.fin_movimientos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'comercio');

alter table public.fin_msi
  add column precio_contado_centavos bigint check (precio_contado_centavos > 0);
comment on column public.fin_msi.precio_contado_centavos is
  'Opcional: lo que habría costado de contado (sobreprecio, B2). Se llena al crear el MSI; para corregirlo se agrega '
  'una declaración de propósito nueva (fin_deuda_propositos.precio_contado_centavos).';
-- Convención 12: el grant repite la lista completa. Se agrega solo a INSERT: no cambia después.
grant insert (id, hogar_id, libro_id, deuda_id, tarjeta_deuda_id, cuenta_pasivo_id, comercio, descripcion,
              fecha_compra, monto_total_centavos, mensualidades, activo, precio_contado_centavos)
  on public.fin_msi to authenticated;

alter table public.fin_estados_cuenta
  add column pagos_al_corte_centavos bigint not null default 0 check (pagos_al_corte_centavos >= 0);
comment on column public.fin_estados_cuenta.pagos_al_corte_centavos is
  'Pagos hechos entre el corte y la fecha límite de pago (para B6b y V-D: ¿pagó el total, o solo el mínimo?).';
grant insert (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago, saldo_al_corte_centavos,
              pago_minimo_centavos, pago_sin_intereses_centavos, intereses_centavos, cargos_centavos,
              tasa_declarada_pb, cat_pb, via, registrado_por, registrado_en, pagos_al_corte_centavos)
  on public.fin_estados_cuenta to authenticated;
-- La vista expone la columna nueva (al final: create or replace solo agrega columnas al final).
create or replace view public.fin_v_estados_cuenta_vigentes with (security_invoker = true) as
select distinct on (e.deuda_id, e.fecha_corte) e.*
from public.fin_estados_cuenta e
order by e.deuda_id, e.fecha_corte, e.registrado_en desc, e.id desc;

-- 2. Tablas nuevas -------------------------------------------------------------------------------------------------
-- 2.1 Parámetros por libro (historial: vigente = el último). Los valores por omisión son [Propuesta] de la spec (3, 5).
create table public.fin_fuga_parametros (
  id                         uuid primary key default gen_random_uuid(),
  hogar_id                   uuid not null references public.hogares (id),
  libro_id                   uuid not null,
  tope_hormiga_centavos      bigint   not null default 15000 check (tope_hormiga_centavos between 1 and 100000000),
  hormiga_min_gastos         smallint not null default 8     check (hormiga_min_gastos between 1 and 100),
  hormiga_min_semanas        smallint not null default 3     check (hormiga_min_semanas between 1 and 4),
  hormiga_min_ingreso_pb     integer  not null default 100   check (hormiga_min_ingreso_pb between 0 and 10000),
  hormiga_conjunto_pb        integer  not null default 500   check (hormiga_conjunto_pb between 0 and 10000),
  recurrente_tolerancia_pb   integer  not null default 1000  check (recurrente_tolerancia_pb between 0 and 10000),
  vampiro_crecimiento_pb     integer  not null default 1000  check (vampiro_crecimiento_pb between 0 and 100000),
  zombie_respuestas          smallint not null default 2     check (zombie_respuestas between 1 and 12),
  servicio_periodos_min      smallint not null default 6     check (servicio_periodos_min between 3 and 60),
  servicio_periodos_mediana  smallint not null default 12    check (servicio_periodos_mediana between 3 and 60),
  servicio_mediana_pb        integer  not null default 2500  check (servicio_mediana_pb between 0 and 100000),
  msi_ambar_pb               integer  not null default 1000  check (msi_ambar_pb between 0 and 10000),
  msi_rojo_pb                integer  not null default 2000  check (msi_rojo_pb between 0 and 10000),
  msi_activos_ambar          smallint not null default 3     check (msi_activos_ambar between 1 and 20),
  msi_activos_rojo           smallint not null default 4     check (msi_activos_rojo between 1 and 20),
  plazo_ambar_meses          smallint not null default 18    check (plazo_ambar_meses between 1 and 48),
  baja_nivel_evaluaciones    smallint not null default 2     check (baja_nivel_evaluaciones between 1 and 8),
  cambiado_por               uuid not null default public.persona_actual() references public.personas (id),
  en_nombre_de               uuid references public.personas (id),
  motivo                     text check (char_length(motivo) <= 200),
  creado_en                  timestamptz not null default clock_timestamp(),
  constraint fin_fuga_parametros_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_fuga_parametros_msi_orden check (msi_ambar_pb <= msi_rojo_pb and msi_activos_ambar <= msi_activos_rojo),
  constraint fin_fuga_parametros_servicio_orden check (servicio_periodos_min <= servicio_periodos_mediana)
);
create index fin_fuga_parametros_libro_idx on public.fin_fuga_parametros (libro_id, creado_en desc, id desc);
comment on table public.fin_fuga_parametros is
  'Umbrales de fugas y deuda por libro. SOLO AGREGAR: cada cambio es una fila nueva y vale la más reciente '
  '(fin_v_fuga_parametros_vigentes); sin fila se usan los valores por omisión de la app. Escritura solo por RPC.';

-- 2.2 Patrones de cobro (inmutables: protegido y cancelado se derivan de clasificaciones y respuestas)
create table public.fin_patrones_cobro (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  clave          text not null check (char_length(clave) between 1 and 200 and clave !~ '[[:cntrl:]]'),
  comercio_norm  text check (comercio_norm is null or char_length(comercio_norm) between 1 and 80),
  categoria_id   uuid,
  compromiso_id  uuid,
  cadencia       text not null check (cadencia in ('semanal', 'quincenal', 'mensual', 'bimestral', 'anual', 'irregular')),
  automatico     boolean not null default false,
  origen         text not null default 'detectado' check (origen in ('detectado', 'manual')),
  creado_por     uuid not null default public.persona_actual() references public.personas (id),
  creado_en      timestamptz not null default now(),
  constraint fin_patrones_cobro_libro_id_key unique (libro_id, id),
  constraint fin_patrones_cobro_clave_unica unique (libro_id, clave),
  constraint fin_patrones_cobro_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_patrones_cobro_categoria_fk foreign key (hogar_id, categoria_id) references public.fin_categorias (hogar_id, id),
  constraint fin_patrones_cobro_compromiso_fk foreign key (libro_id, compromiso_id) references public.fin_compromisos (libro_id, id)
);
comment on table public.fin_patrones_cobro is
  'Un cobro que se repite o una subcategoría hormiga vigilada. SOLO AGREGAR. comercio_norm es dato del libro: jamás sale '
  'en un aviso (D20). Su estado (protegido, cancelado) sale de fin_v_patrones_estado.';

-- 2.3 Clasificaciones (decisión de la persona o de la regla) con historial
create table public.fin_fuga_clasificaciones (
  id                       uuid primary key default gen_random_uuid(),
  hogar_id                 uuid not null references public.hogares (id),
  libro_id                 uuid not null,
  patron_id                uuid not null,
  fuga                     text not null check (fuga in ('hormiga', 'fantasma', 'vampiro', 'zombie', 'ninguna')),
  origen                   text not null check (origen in ('regla', 'persona')),
  regla                    text check (regla ~ '^[A-Z][A-Z0-9]{0,2}$'),
  fuga_regla               text check (fuga_regla in ('hormiga', 'fantasma', 'vampiro', 'zombie', 'ninguna')),
  vigilar                  boolean not null default false,
  monto_al_decidir_centavos bigint check (monto_al_decidir_centavos >= 0),
  reemplaza_a              uuid,
  motivo                   text check (char_length(motivo) <= 200),
  decidido_por             uuid not null default public.persona_actual() references public.personas (id),
  en_nombre_de             uuid references public.personas (id),
  decidido_en              timestamptz not null default now(),
  constraint fin_fuga_clasificaciones_patron_id_key unique (patron_id, id),
  constraint fin_fuga_clasificaciones_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_fuga_clasificaciones_patron_fk foreign key (libro_id, patron_id) references public.fin_patrones_cobro (libro_id, id),
  constraint fin_fuga_clasificaciones_reemplaza_fk foreign key (patron_id, reemplaza_a)
    references public.fin_fuga_clasificaciones (patron_id, id),
  constraint fin_fuga_clasificaciones_vigilar check (not vigilar or (origen = 'persona' and fuga = 'ninguna')),
  constraint fin_fuga_clasificaciones_persona check (origen <> 'persona' or fuga_regla is not null)
);
-- Una fila solo puede ser reemplazada una vez (como la anulación del libro) y cada patrón tiene una sola cadena.
create unique index fin_fuga_clasificaciones_un_reemplazo on public.fin_fuga_clasificaciones (reemplaza_a)
  where reemplaza_a is not null;
create unique index fin_fuga_clasificaciones_una_raiz on public.fin_fuga_clasificaciones (patron_id)
  where reemplaza_a is null;
comment on table public.fin_fuga_clasificaciones is
  'Clasificación de un patrón y su historial. SOLO AGREGAR; vigente = la que ninguna otra reemplaza. La persona gana a la '
  'regla: una decisión de la persona que contradice a la regla (fuga <> fuga_regla) exige motivo de 3 a 200 caracteres. '
  'En el libro de Papá, en_nombre_de y motivo son obligatorios (D19).';

-- 2.4 Respuestas de la persona
create table public.fin_fuga_respuestas (
  id                uuid primary key default gen_random_uuid(),
  hogar_id          uuid not null references public.hogares (id),
  libro_id          uuid not null,
  patron_id         uuid not null,
  pregunta          text not null check (pregunta in ('reconoce', 'uso', 'ya_no_sirve', 'ya_no_existe', 'ya_no_la_quiero',
                                                      'duplicado', 'plan_viejo', 'cancelado', 'temporada')),
  respuesta         text not null check (respuesta in ('si', 'no', 'despues')),
  fecha_cancelacion date,
  folio             text check (folio ~ '^[A-Za-z0-9-]{1,40}$'),
  periodo_lunes     date not null check (extract(isodow from periodo_lunes) = 1),
  reemplaza_a       uuid,
  motivo            text check (char_length(motivo) <= 200),
  registrado_por    uuid not null default public.persona_actual() references public.personas (id),
  en_nombre_de      uuid references public.personas (id),
  registrado_en     timestamptz not null default now(),
  recibido_en       timestamptz not null default now(),
  constraint fin_fuga_respuestas_patron_pregunta_key unique (patron_id, pregunta, id),
  constraint fin_fuga_respuestas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_fuga_respuestas_patron_fk foreign key (libro_id, patron_id) references public.fin_patrones_cobro (libro_id, id),
  constraint fin_fuga_respuestas_reemplaza_fk foreign key (patron_id, pregunta, reemplaza_a)
    references public.fin_fuga_respuestas (patron_id, pregunta, id),
  -- La fecha de cancelación solo existe en un "ya lo cancelé"; el folio solo con fecha. Sin folio = cancelado sin folio.
  constraint fin_fuga_respuestas_cancelacion check (
    (fecha_cancelacion is not null) = (pregunta = 'cancelado' and respuesta = 'si')),
  constraint fin_fuga_respuestas_folio_con_fecha check (folio is null or fecha_cancelacion is not null)
);
create unique index fin_fuga_respuestas_un_reemplazo on public.fin_fuga_respuestas (reemplaza_a)
  where reemplaza_a is not null;
-- Una raíz por patrón, pregunta y periodo (una cancelación: una raíz por patrón, se corrige con reemplaza_a).
create unique index fin_fuga_respuestas_raiz_periodo on public.fin_fuga_respuestas (patron_id, pregunta, periodo_lunes)
  where reemplaza_a is null and pregunta <> 'cancelado';
create unique index fin_fuga_respuestas_raiz_cancelado on public.fin_fuga_respuestas (patron_id)
  where reemplaza_a is null and pregunta = 'cancelado';
create index fin_fuga_respuestas_patron_idx on public.fin_fuga_respuestas (patron_id, periodo_lunes desc);
comment on table public.fin_fuga_respuestas is
  'Respuesta de la persona a una pregunta de uso o reconocimiento, o una cancelación (fecha y folio; sin folio = '
  'cancelado sin folio). SOLO AGREGAR; se corrige con una respuesta nueva (reemplaza_a); el conteo de "2 seguidas" usa '
  'la última de cada periodo. periodo_lunes es el lunes de la semana en que se contestó.';

-- 2.5 Propósito de una deuda
create table public.fin_deuda_propositos (
  id                      uuid primary key default gen_random_uuid(),
  hogar_id                uuid not null references public.hogares (id),
  libro_id                uuid not null,
  deuda_id                uuid not null,
  proposito               text not null check (proposito in ('bien_duradero', 'genera_ingreso', 'patrimonio',
                                                             'educacion_o_salud', 'emergencia', 'consumo')),
  objetivo_texto          text check (objetivo_texto is null or (char_length(objetivo_texto) between 1 and 80
                                      and objetivo_texto !~ '[0-9$]')),
  bien_id                 uuid,
  objetivo_id             uuid,
  vida_util_meses         smallint check (vida_util_meses between 1 and 600),
  estado_objetivo         text not null default 'vigente' check (estado_objetivo in ('vigente', 'cumplido', 'ya_no_existe', 'cambio')),
  uso_poco                boolean not null default false,
  precio_contado_centavos bigint check (precio_contado_centavos > 0),
  reemplaza_a             uuid,
  motivo                  text check (char_length(motivo) <= 200),
  declarado_por           uuid not null default public.persona_actual() references public.personas (id),
  en_nombre_de            uuid references public.personas (id),
  declarado_en            timestamptz not null default now(),
  constraint fin_deuda_propositos_deuda_id_key unique (deuda_id, id),
  constraint fin_deuda_propositos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_deuda_propositos_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id),
  constraint fin_deuda_propositos_bien_fk foreign key (libro_id, bien_id) references public.fin_bienes (libro_id, id),
  constraint fin_deuda_propositos_objetivo_fk foreign key (libro_id, objetivo_id) references public.fin_objetivos (libro_id, id),
  constraint fin_deuda_propositos_reemplaza_fk foreign key (deuda_id, reemplaza_a)
    references public.fin_deuda_propositos (deuda_id, id)
);
create unique index fin_deuda_propositos_un_reemplazo on public.fin_deuda_propositos (reemplaza_a)
  where reemplaza_a is not null;
create unique index fin_deuda_propositos_una_raiz on public.fin_deuda_propositos (deuda_id)
  where reemplaza_a is null;
comment on table public.fin_deuda_propositos is
  'Propósito declarado de una deuda y estado del objetivo. SOLO AGREGAR; vale la declaración más reciente. objetivo_texto: '
  'hasta 80 caracteres y sin cifras (dato del libro, jamás en un aviso). uso_poco = B5 ámbar ("lo uso poco"). '
  'precio_contado_centavos corrige el de fin_msi sin editarlo.';

-- 2.6 Historial del semáforo de cada deuda
create table public.fin_deuda_semaforo (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid not null,
  deuda_id        uuid not null,
  lunes           date not null check (extract(isodow from lunes) = 1),
  nivel           text not null check (nivel in ('verde', 'ambar', 'rojo', 'gris')),
  senales         text[] not null default '{}' check (cardinality(senales) <= 30
                    and array_position(senales, null) is null and array_to_string(senales, ',') ~ '^([A-Z][0-9][a-z]?(,|$))*$'),
  bajas_seguidas  smallint not null default 0 check (bajas_seguidas between 0 and 8),
  calculado_en    timestamptz not null default clock_timestamp(),
  registrado_por  uuid not null default public.persona_actual() references public.personas (id),
  recibido_en     timestamptz not null default clock_timestamp(),
  constraint fin_deuda_semaforo_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_deuda_semaforo_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id)
);
create index fin_deuda_semaforo_deuda_idx on public.fin_deuda_semaforo (deuda_id, calculado_en desc, recibido_en desc, id desc);
comment on table public.fin_deuda_semaforo is
  'Historial del nivel mostrado de una deuda (verde, ambar, rojo, gris) y sus códigos de señal (B1 a M8). SOLO AGREGAR; '
  'se agrega solo cuando cambia el nivel o el contador de bajas (histéresis). Sin cifras ni nombres.';

-- 3. Validaciones (triggers) ---------------------------------------------------------------------------------------
-- 3.1 Clasificaciones: la persona gana a la regla, con motivo cuando la contradice (SQ-7); Papá, en nombre de con motivo.
create function public.fin_fuga_clasificaciones_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if new.origen = 'persona' and not new.vigilar and new.fuga_regla is not null and new.fuga <> new.fuga_regla
     and not public.fin_motivo_valido(new.motivo) then
    raise exception using errcode = '22023',
      message = 'Una decisión que contradice a la regla lleva motivo de 3 a 200 caracteres.';
  end if;
  if new.origen = 'persona' and v_libro.tipo = 'representado'
     and (new.en_nombre_de is distinct from v_libro.titular_id or not public.fin_motivo_valido(new.motivo)) then
    raise exception using errcode = '22023',
      message = 'En el libro de Papá la decisión queda en nombre de él y con motivo (de 3 a 200 caracteres).';
  end if;
  return new;
end
$$;
create trigger fin_b_validar before insert on public.fin_fuga_clasificaciones
  for each row execute function public.fin_fuga_clasificaciones_validar();

-- 3.2 Solo agregar, sin truncate, y bitácora (sin motivos, comercios, textos ni folios: no son de auditoría).
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_fuga_parametros', 'fin_patrones_cobro', 'fin_fuga_clasificaciones',
                                 'fin_fuga_respuestas', 'fin_deuda_propositos', 'fin_deuda_semaforo']
  loop
    execute format('create trigger fin_solo_agregar before update or delete on public.%I
                      for each row execute function public.impedir_cambios_solo_agregar()', v_tabla);
    execute format('create trigger fin_sin_truncate before truncate on public.%I
                      for each statement execute function public.impedir_cambios_solo_agregar()', v_tabla);
    execute format('alter table public.%I enable row level security', v_tabla);
  end loop;
end
$$;
create trigger fin_z_bitacora after insert or update or delete on public.fin_fuga_parametros
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'motivo', 'tope_hormiga_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_patrones_cobro
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'comercio_norm', 'clave');
create trigger fin_z_bitacora after insert or update or delete on public.fin_fuga_clasificaciones
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'motivo', 'monto_al_decidir_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_fuga_respuestas
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'motivo', 'folio');
create trigger fin_z_bitacora after insert or update or delete on public.fin_deuda_propositos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'motivo', 'objetivo_texto', 'precio_contado_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_deuda_semaforo
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');

-- Quién ve estas tablas: lo mismo que fin_deudas_puede_ver (miembro vigente del libro; la cuenta maestra con consulta
-- vigente) PERO sin la vista temporal de Papá (D24): fin_deudas_puede_ver sigue a fin_puede(libro, 'leer') desde
-- 20261135 y esa regla deja leer al familiar con una vista autorizada; esta spec (7, C-7) la excluye. Solo ven el dueño
-- y los coadministradores del hogar (la maestra incluida, solo con consulta vigente); familiar, cuidador y Casa, nunca.
create function public.fin_fugas_puede_ver(p_libro uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.fin_deudas_puede_ver(p_libro)
                  and public.rol_en_hogar(l.hogar_id) in ('dueno', 'coadministrador'), false)
    from public.fin_libros l where l.id = p_libro
$$;
comment on function public.fin_fugas_puede_ver(uuid) is
  'D5, D19, D24. fin_deudas_puede_ver con rol dueño o coadministrador: el familiar con vista temporal de Papá no ve fugas ni '
  'propósitos de deuda. La cuenta maestra lee solo con consulta vigente (lo decide fin_puede).';

-- 4. RLS y privilegios: solo lectura con fin_fugas_puede_ver; nada de escritura directa --------------------------------
create policy fin_fuga_parametros_leer on public.fin_fuga_parametros for select to authenticated
  using (public.fin_fugas_puede_ver(libro_id));
create policy fin_patrones_cobro_leer on public.fin_patrones_cobro for select to authenticated
  using (public.fin_fugas_puede_ver(libro_id));
create policy fin_fuga_clasificaciones_leer on public.fin_fuga_clasificaciones for select to authenticated
  using (public.fin_fugas_puede_ver(libro_id));
create policy fin_fuga_respuestas_leer on public.fin_fuga_respuestas for select to authenticated
  using (public.fin_fugas_puede_ver(libro_id));
create policy fin_deuda_propositos_leer on public.fin_deuda_propositos for select to authenticated
  using (public.fin_fugas_puede_ver(libro_id));
create policy fin_deuda_semaforo_leer on public.fin_deuda_semaforo for select to authenticated
  using (public.fin_fugas_puede_ver(libro_id));

-- Vistas de lo vigente (security_invoker: respetan la RLS de quien consulta).
create view public.fin_v_fuga_parametros_vigentes with (security_invoker = true) as
select distinct on (p.libro_id) p.*
from public.fin_fuga_parametros p
order by p.libro_id, p.creado_en desc, p.id desc;
create view public.fin_v_fuga_clasificaciones_vigentes with (security_invoker = true) as
select c.*
from public.fin_fuga_clasificaciones c
where not exists (select 1 from public.fin_fuga_clasificaciones r where r.reemplaza_a = c.id);
create view public.fin_v_fuga_respuestas_vigentes with (security_invoker = true) as
select r.*
from public.fin_fuga_respuestas r
where not exists (select 1 from public.fin_fuga_respuestas x where x.reemplaza_a = r.id);
create view public.fin_v_deuda_propositos_vigentes with (security_invoker = true) as
select d.*
from public.fin_deuda_propositos d
where not exists (select 1 from public.fin_deuda_propositos x where x.reemplaza_a = d.id);
create view public.fin_v_deuda_semaforo_actual with (security_invoker = true) as
select distinct on (s.deuda_id) s.*
from public.fin_deuda_semaforo s
order by s.deuda_id, s.calculado_en desc, s.recibido_en desc, s.id desc;
-- Estado derivado de un patrón: protegido ("No es una fuga"), vigilar, cancelado y cancelado sin folio.
create view public.fin_v_patrones_estado with (security_invoker = true) as
select p.id as patron_id, p.hogar_id, p.libro_id, p.clave, p.cadencia, p.automatico,
       coalesce(c.origen = 'persona' and c.fuga = 'ninguna' and not c.vigilar, false) as protegido,
       coalesce(c.vigilar, false) as vigilar,
       k.fecha_cancelacion as cancelado_en,
       k.folio as folio_cancelacion,
       coalesce(k.fecha_cancelacion is not null and k.folio is null, false) as cancelado_sin_folio
from public.fin_patrones_cobro p
left join lateral (
  select c1.* from public.fin_fuga_clasificaciones c1
   where c1.patron_id = p.id
     and not exists (select 1 from public.fin_fuga_clasificaciones r where r.reemplaza_a = c1.id)
   limit 1) c on true
left join lateral (
  select r1.* from public.fin_fuga_respuestas r1
   where r1.patron_id = p.id and r1.pregunta = 'cancelado'
     and not exists (select 1 from public.fin_fuga_respuestas r where r.reemplaza_a = r1.id)
   limit 1) k on true;
comment on view public.fin_v_patrones_estado is
  'Estado vigente de cada patrón, derivado (los patrones no se editan): protegido, vigilar, fecha y folio de cancelación.';

revoke all on table
  public.fin_fuga_parametros, public.fin_patrones_cobro, public.fin_fuga_clasificaciones, public.fin_fuga_respuestas,
  public.fin_deuda_propositos, public.fin_deuda_semaforo, public.fin_v_fuga_parametros_vigentes,
  public.fin_v_fuga_clasificaciones_vigentes, public.fin_v_fuga_respuestas_vigentes, public.fin_v_deuda_propositos_vigentes,
  public.fin_v_deuda_semaforo_actual, public.fin_v_patrones_estado
  from public, anon, authenticated, service_role;
grant select on
  public.fin_fuga_parametros, public.fin_patrones_cobro, public.fin_fuga_clasificaciones, public.fin_fuga_respuestas,
  public.fin_deuda_propositos, public.fin_deuda_semaforo, public.fin_v_fuga_parametros_vigentes,
  public.fin_v_fuga_clasificaciones_vigentes, public.fin_v_fuga_respuestas_vigentes, public.fin_v_deuda_propositos_vigentes,
  public.fin_v_deuda_semaforo_actual, public.fin_v_patrones_estado
  to authenticated, service_role;
-- Sin grant de escritura: solo las RPC.

-- 5. Ayudantes internos --------------------------------------------------------------------------------------------
-- Exige el permiso en el libro Y fin_fugas_puede_ver (la regla de tarjetas sin la vista temporal de Papá). El suplente de
-- Papá lee siempre (fin_puede leer) pero escribe solo sin albacea vigente; la cuenta maestra nunca escribe; el familiar con
-- vista temporal (D24) ni lee ni escribe.
create function public.fin_fugas_exigir(p_libro uuid, p_accion text)
returns public.fin_libros
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  if public.persona_actual() is null or p_libro is null
     or not public.fin_puede(p_libro, p_accion) or not public.fin_fugas_puede_ver(p_libro) then
    raise exception using errcode = '42501', message = 'No puedes usar las fugas y deudas de este libro.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = p_libro;
  return v_libro;
end
$$;
comment on function public.fin_fugas_exigir(uuid, text) is
  'Interna. Permiso en el libro (fin_puede) y fin_fugas_puede_ver; si no, 42501.';

-- En el libro de Papá la decisión queda en nombre de él y con motivo (D19). Devuelve en_nombre_de (nulo en otros libros).
create function public.fin_fugas_en_nombre(p_libro public.fin_libros, p_motivo text, p_exige boolean)
returns uuid
language plpgsql immutable
set search_path = ''
as $$
begin
  if p_motivo is not null and char_length(p_motivo) > 200 then
    raise exception using errcode = '22023', message = 'El motivo admite hasta 200 caracteres.';
  end if;
  if p_libro.tipo = 'representado' then
    if p_exige and not public.fin_motivo_valido(p_motivo) then
      raise exception using errcode = '22023',
        message = 'En el libro de Papá la decisión lleva motivo (de 3 a 200 caracteres).';
    end if;
    return p_libro.titular_id;
  end if;
  return null;
end
$$;

-- Lunes de la semana de una fecha (la semana empieza en lunes).
create function public.fin_fugas_lunes(p_fecha date)
returns date
language sql immutable
set search_path = ''
as $$ select p_fecha - (extract(isodow from p_fecha)::int - 1) $$;

-- Fecha de hoy en la zona de la persona (avisos_preferencias) o en la de México.
create function public.fin_fugas_hoy()
returns date
language sql stable security definer
set search_path = ''
as $$
  select (now() at time zone coalesce(
    (select p.zona_horaria from public.avisos_preferencias p where p.persona_id = public.persona_actual()),
    'America/Mexico_City'))::date
$$;

-- 6. RPC de escritura (sección 6.3) -------------------------------------------------------------------------------
-- 6.1 Patrón de cobro. Idempotente por id y por (libro, clave): si el patrón ya existe devuelve el existente.
create function public.fin_patron_crear(
  p_id uuid, p_libro uuid, p_comercio_norm text, p_categoria uuid, p_cadencia text, p_automatico boolean,
  p_clave text default null, p_origen text default 'manual', p_compromiso uuid default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_clave text;
  v_com   text := nullif(btrim(p_comercio_norm), '');
  v_ex    public.fin_patrones_cobro%rowtype;
begin
  v_libro := public.fin_fugas_exigir(p_libro, 'escribir');
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id del patrón es obligatorio.';
  end if;
  v_clave := coalesce(nullif(btrim(p_clave), ''), coalesce(lower(v_com), 'sin-comercio') || '|' || coalesce(p_categoria::text, 'sin-categoria'));
  select * into v_ex from public.fin_patrones_cobro x where x.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro or v_ex.clave <> v_clave then
      raise exception using errcode = '23505', message = 'Ese id ya es de otro patrón.';
    end if;
    return v_ex.id;
  end if;
  select * into v_ex from public.fin_patrones_cobro x where x.libro_id = p_libro and x.clave = v_clave;
  if found then
    return v_ex.id;
  end if;
  if (select count(*) from public.fin_patrones_cobro x where x.libro_id = p_libro) >= 2000 then
    raise exception using errcode = '22023', message = 'Se llegó al tope de 2000 patrones por libro.';
  end if;
  insert into public.fin_patrones_cobro (id, hogar_id, libro_id, clave, comercio_norm, categoria_id, compromiso_id,
                                         cadencia, automatico, origen, creado_por)
  values (p_id, v_libro.hogar_id, p_libro, v_clave, v_com, p_categoria, p_compromiso, p_cadencia,
          coalesce(p_automatico, false), p_origen, public.persona_actual());
  return p_id;
end
$$;
comment on function public.fin_patron_crear(uuid, uuid, text, uuid, text, boolean, text, text, uuid) is
  'Crea un patrón de cobro (idempotente por id y por clave). escribir en el libro y poder ver sus deudas. '
  'Sin p_clave se arma con comercio y categoría.';

-- Busca el patrón y el permiso en su libro (sin revelar si existe).
create function public.fin_fugas_patron(p_patron uuid, p_accion text)
returns public.fin_patrones_cobro
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_p public.fin_patrones_cobro%rowtype;
begin
  select * into v_p from public.fin_patrones_cobro x where x.id = p_patron;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes usar las fugas y deudas de este libro.';
  end if;
  perform public.fin_fugas_exigir(v_p.libro_id, p_accion);
  return v_p;
end
$$;

-- 6.2 Responder una pregunta (reconoce, uso, ya no sirve...). La cancelación va por fin_patron_cancelar.
create function public.fin_fuga_responder(
  p_id uuid, p_patron uuid, p_pregunta text, p_respuesta text, p_periodo_lunes date default null,
  p_registrado_en timestamptz default null, p_motivo text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_p     public.fin_patrones_cobro%rowtype;
  v_libro public.fin_libros%rowtype;
  v_hoy   date := public.fin_fugas_hoy();
  v_lunes date;
  v_vig   public.fin_fuga_respuestas%rowtype;
  v_ex    public.fin_fuga_respuestas%rowtype;
  v_nombre uuid;
  v_exige boolean := p_pregunta not in ('reconoce', 'uso', 'temporada');
begin
  v_p := public.fin_fugas_patron(p_patron, 'escribir');
  select * into v_libro from public.fin_libros l where l.id = v_p.libro_id;
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id de la respuesta es obligatorio.';
  end if;
  if p_pregunta = 'cancelado' then
    raise exception using errcode = '22023', message = 'Una cancelación se registra con fin_patron_cancelar.';
  end if;
  if p_pregunta is null or p_pregunta not in ('reconoce', 'uso', 'ya_no_sirve', 'ya_no_existe', 'ya_no_la_quiero',
                                              'duplicado', 'plan_viejo', 'temporada')
     or p_respuesta is null or p_respuesta not in ('si', 'no', 'despues') then
    raise exception using errcode = '22023', message = 'Pregunta o respuesta no válida.';
  end if;
  v_lunes := coalesce(p_periodo_lunes, public.fin_fugas_lunes(v_hoy));
  if extract(isodow from v_lunes) <> 1 or v_lunes > v_hoy + 1 or v_lunes < v_hoy - 400 then
    raise exception using errcode = '22023', message = 'El periodo es el lunes de la semana en que se contestó.';
  end if;
  if p_registrado_en is not null and p_registrado_en > now() + interval '1 day' then
    raise exception using errcode = '22023', message = 'La fecha de registro no puede estar en el futuro.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, p_motivo, v_exige);

  perform pg_advisory_xact_lock(hashtextextended('fin_fuga_resp:' || p_patron::text || ':' || p_pregunta || ':' || v_lunes::text, 0));
  select * into v_ex from public.fin_fuga_respuestas r where r.id = p_id;
  if found then
    if v_ex.patron_id = p_patron and v_ex.pregunta = p_pregunta and v_ex.respuesta = p_respuesta and v_ex.periodo_lunes = v_lunes then
      return v_ex.id;
    end if;
    raise exception using errcode = '23505', message = 'Ese id ya es de otra respuesta.';
  end if;
  select * into v_vig from public.fin_fuga_respuestas r
   where r.patron_id = p_patron and r.pregunta = p_pregunta and r.periodo_lunes = v_lunes
     and not exists (select 1 from public.fin_fuga_respuestas x where x.reemplaza_a = r.id);
  if found and v_vig.respuesta = p_respuesta then
    return v_vig.id;   -- ya dijo lo mismo en este periodo: no se duplica
  end if;
  insert into public.fin_fuga_respuestas (id, hogar_id, libro_id, patron_id, pregunta, respuesta, periodo_lunes,
                                          reemplaza_a, motivo, registrado_por, en_nombre_de, registrado_en)
  values (p_id, v_p.hogar_id, v_p.libro_id, p_patron, p_pregunta, p_respuesta, v_lunes,
          case when found then v_vig.id end, nullif(btrim(p_motivo), ''), public.persona_actual(), v_nombre,
          coalesce(p_registrado_en, now()));
  return p_id;
end
$$;
comment on function public.fin_fuga_responder(uuid, uuid, text, text, date, timestamptz, text) is
  'Agrega una respuesta (reconoce, uso, ya_no_sirve, ya_no_existe, ya_no_la_quiero, duplicado, plan_viejo, temporada). '
  'escribir en el libro. Si ya había una vigente en el mismo periodo, la nueva la reemplaza (reemplaza_a, lo pone el '
  'servidor); si dice lo mismo no duplica. En el libro de Papá, las decisiones llevan motivo y quedan en su nombre.';

-- 6.3 Clasificar (decisión de la persona). La nueva reemplaza a la vigente; la anterior no se toca.
create function public.fin_fuga_clasificar(
  p_id uuid, p_patron uuid, p_fuga text, p_fuga_regla text, p_motivo text default null, p_regla text default null,
  p_vigilar boolean default false, p_monto_centavos bigint default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_p      public.fin_patrones_cobro%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_vig    public.fin_fuga_clasificaciones%rowtype;
  v_ex     public.fin_fuga_clasificaciones%rowtype;
  v_nombre uuid;
  v_contradice boolean;
begin
  v_p := public.fin_fugas_patron(p_patron, 'escribir');
  select * into v_libro from public.fin_libros l where l.id = v_p.libro_id;
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id de la clasificación es obligatorio.';
  end if;
  if p_fuga is null or p_fuga not in ('hormiga', 'fantasma', 'vampiro', 'zombie', 'ninguna')
     or p_fuga_regla is null or p_fuga_regla not in ('hormiga', 'fantasma', 'vampiro', 'zombie', 'ninguna') then
    raise exception using errcode = '22023', message = 'La fuga y la que dijo la regla son del catálogo (hormiga, fantasma, vampiro, zombie, ninguna).';
  end if;
  if coalesce(p_vigilar, false) and p_fuga <> 'ninguna' then
    raise exception using errcode = '22023', message = '"Vigilar" no es una fuga: va con la clasificación ninguna.';
  end if;
  v_contradice := not coalesce(p_vigilar, false) and p_fuga <> p_fuga_regla;
  if v_contradice and not public.fin_motivo_valido(p_motivo) then
    raise exception using errcode = '22023', message = 'Una decisión que contradice a la regla lleva motivo de 3 a 200 caracteres.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, p_motivo, true);

  perform pg_advisory_xact_lock(hashtextextended('fin_fuga_clas:' || p_patron::text, 0));
  select * into v_ex from public.fin_fuga_clasificaciones c where c.id = p_id;
  if found then
    if v_ex.patron_id = p_patron and v_ex.fuga = p_fuga and v_ex.vigilar = coalesce(p_vigilar, false) then
      return v_ex.id;
    end if;
    raise exception using errcode = '23505', message = 'Ese id ya es de otra clasificación.';
  end if;
  select * into v_vig from public.fin_fuga_clasificaciones c
   where c.patron_id = p_patron and not exists (select 1 from public.fin_fuga_clasificaciones x where x.reemplaza_a = c.id);
  if found and v_vig.origen = 'persona' and v_vig.fuga = p_fuga and v_vig.vigilar = coalesce(p_vigilar, false)
     and v_vig.fuga_regla = p_fuga_regla then
    return v_vig.id;   -- la misma decisión ya es la vigente
  end if;
  insert into public.fin_fuga_clasificaciones (id, hogar_id, libro_id, patron_id, fuga, origen, regla, fuga_regla, vigilar,
                                               monto_al_decidir_centavos, reemplaza_a, motivo, decidido_por, en_nombre_de)
  values (p_id, v_p.hogar_id, v_p.libro_id, p_patron, p_fuga, 'persona', p_regla, p_fuga_regla, coalesce(p_vigilar, false),
          p_monto_centavos, case when found then v_vig.id end, nullif(btrim(p_motivo), ''), public.persona_actual(), v_nombre);
  return p_id;
end
$$;
comment on function public.fin_fuga_clasificar(uuid, uuid, text, text, text, text, boolean, bigint) is
  'Agrega la decisión de la persona sobre un patrón (reemplaza a la vigente, que no se edita). p_fuga_regla es lo que '
  'dijo la regla: si la decisión la contradice, el motivo de 3 a 200 caracteres es obligatorio (SQ-7). "No es una fuga" '
  'es p_fuga = ninguna; "Vigilar" es ninguna con p_vigilar. escribir en el libro; en el de Papá, en su nombre y con motivo.';

-- 6.4 Cancelar un patrón: fecha y folio (sin folio = cancelado sin folio). Si hay compromiso ligado, le pone hasta.
create function public.fin_patron_cancelar(
  p_id uuid, p_patron uuid, p_fecha date, p_folio text default null, p_motivo text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_p     public.fin_patrones_cobro%rowtype;
  v_libro public.fin_libros%rowtype;
  v_hoy   date := public.fin_fugas_hoy();
  v_folio text := nullif(btrim(p_folio), '');
  v_vig   public.fin_fuga_respuestas%rowtype;
  v_ex    public.fin_fuga_respuestas%rowtype;
  v_nombre uuid;
begin
  v_p := public.fin_fugas_patron(p_patron, 'escribir');
  select * into v_libro from public.fin_libros l where l.id = v_p.libro_id;
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id de la cancelación es obligatorio.';
  end if;
  if p_fecha is null or p_fecha > v_hoy + 1 or p_fecha < v_hoy - 3650 then
    raise exception using errcode = '22023', message = 'La fecha de cancelación es de hoy o anterior.';
  end if;
  if v_folio is not null and v_folio !~ '^[A-Za-z0-9-]{1,40}$' then
    raise exception using errcode = '22023', message = 'El folio lleva de 1 a 40 caracteres: letras, números y guiones.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, p_motivo, true);

  perform pg_advisory_xact_lock(hashtextextended('fin_fuga_canc:' || p_patron::text, 0));
  select * into v_ex from public.fin_fuga_respuestas r where r.id = p_id;
  if found then
    if v_ex.patron_id = p_patron and v_ex.pregunta = 'cancelado' and v_ex.fecha_cancelacion = p_fecha
       and v_ex.folio is not distinct from v_folio then
      return v_ex.id;
    end if;
    raise exception using errcode = '23505', message = 'Ese id ya es de otra respuesta.';
  end if;
  select * into v_vig from public.fin_fuga_respuestas r
   where r.patron_id = p_patron and r.pregunta = 'cancelado'
     and not exists (select 1 from public.fin_fuga_respuestas x where x.reemplaza_a = r.id);
  insert into public.fin_fuga_respuestas (id, hogar_id, libro_id, patron_id, pregunta, respuesta, fecha_cancelacion, folio,
                                          periodo_lunes, reemplaza_a, motivo, registrado_por, en_nombre_de)
  values (p_id, v_p.hogar_id, v_p.libro_id, p_patron, 'cancelado', 'si', p_fecha, v_folio,
          public.fin_fugas_lunes(v_hoy), case when found then v_vig.id end, nullif(btrim(p_motivo), ''),
          public.persona_actual(), v_nombre);
  -- El compromiso ligado deja de proponerse: hasta = fecha de cancelación (solo si no termina antes).
  if v_p.compromiso_id is not null then
    update public.fin_compromisos c set hasta = p_fecha
     where c.id = v_p.compromiso_id and c.libro_id = v_p.libro_id
       and (c.hasta is null or c.hasta > p_fecha) and (c.desde is null or c.desde <= p_fecha);
  end if;
  return p_id;
end
$$;
comment on function public.fin_patron_cancelar(uuid, uuid, date, text, text) is
  'Registra la cancelación de un patrón (respuesta cancelado con fecha y folio; sin folio = cancelado sin folio, que se '
  'completa con otra llamada que reemplaza a la anterior). Folio: 1 a 40 caracteres [A-Za-z0-9-]. Si el patrón tiene '
  'compromiso, le pone hasta = fecha. escribir en el libro.';

-- 6.5 Declarar el propósito de una deuda (administrar). Vale la más reciente.
create function public.fin_deuda_declarar(
  p_id uuid, p_deuda uuid, p_proposito text, p_objetivo_texto text default null, p_bien uuid default null,
  p_objetivo uuid default null, p_vida_util integer default null, p_estado text default 'vigente',
  p_uso_poco boolean default false, p_precio_contado_centavos bigint default null, p_motivo text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d      public.fin_deudas%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_vig    public.fin_deuda_propositos%rowtype;
  v_ex     public.fin_deuda_propositos%rowtype;
  v_texto  text := nullif(btrim(p_objetivo_texto), '');
  v_nombre uuid;
begin
  select * into v_d from public.fin_deudas d where d.id = p_deuda;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes usar las fugas y deudas de este libro.';
  end if;
  v_libro := public.fin_fugas_exigir(v_d.libro_id, 'administrar');
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id de la declaración es obligatorio.';
  end if;
  if p_proposito is null or p_proposito not in ('bien_duradero', 'genera_ingreso', 'patrimonio', 'educacion_o_salud',
                                                'emergencia', 'consumo') then
    raise exception using errcode = '22023', message = 'Propósito no válido.';
  end if;
  if p_estado is null or p_estado not in ('vigente', 'cumplido', 'ya_no_existe', 'cambio') then
    raise exception using errcode = '22023', message = 'Estado del objetivo no válido.';
  end if;
  if v_texto is not null and (char_length(v_texto) > 80 or v_texto ~ '[0-9$]') then
    raise exception using errcode = '22023', message = 'El objetivo lleva hasta 80 caracteres y no lleva cifras.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, p_motivo, true);

  perform pg_advisory_xact_lock(hashtextextended('fin_deuda_prop:' || p_deuda::text, 0));
  select * into v_ex from public.fin_deuda_propositos x where x.id = p_id;
  if found then
    if v_ex.deuda_id = p_deuda and v_ex.proposito = p_proposito and v_ex.estado_objetivo = p_estado then
      return v_ex.id;
    end if;
    raise exception using errcode = '23505', message = 'Ese id ya es de otra declaración.';
  end if;
  select * into v_vig from public.fin_deuda_propositos x
   where x.deuda_id = p_deuda and not exists (select 1 from public.fin_deuda_propositos y where y.reemplaza_a = x.id);
  insert into public.fin_deuda_propositos (id, hogar_id, libro_id, deuda_id, proposito, objetivo_texto, bien_id, objetivo_id,
                                           vida_util_meses, estado_objetivo, uso_poco, precio_contado_centavos,
                                           reemplaza_a, motivo, declarado_por, en_nombre_de)
  values (p_id, v_d.hogar_id, v_d.libro_id, p_deuda, p_proposito, v_texto, p_bien, p_objetivo, p_vida_util, p_estado,
          coalesce(p_uso_poco, false), p_precio_contado_centavos, case when found then v_vig.id end,
          nullif(btrim(p_motivo), ''), public.persona_actual(), v_nombre);
  return p_id;
end
$$;
comment on function public.fin_deuda_declarar(uuid, uuid, text, text, uuid, uuid, integer, text, boolean, bigint, text) is
  'Agrega una declaración de propósito de una deuda (reemplaza a la vigente, que no se edita). administrar en el libro. '
  'objetivo_texto: hasta 80 y sin cifras. p_uso_poco = "lo uso poco" (B5 ámbar). En el libro de Papá, con motivo y en su nombre.';

-- 6.6 Cambiar umbrales (administrar). Parte de lo vigente (o de los valores por omisión) y cambia solo lo que se manda.
create function public.fin_fuga_parametros_cambiar(
  p_libro uuid, p_id uuid default null,
  p_tope_hormiga_centavos bigint default null, p_hormiga_min_gastos integer default null,
  p_hormiga_min_semanas integer default null, p_hormiga_min_ingreso_pb integer default null,
  p_hormiga_conjunto_pb integer default null, p_recurrente_tolerancia_pb integer default null,
  p_vampiro_crecimiento_pb integer default null, p_zombie_respuestas integer default null,
  p_servicio_periodos_min integer default null, p_servicio_periodos_mediana integer default null,
  p_servicio_mediana_pb integer default null, p_msi_ambar_pb integer default null, p_msi_rojo_pb integer default null,
  p_msi_activos_ambar integer default null, p_msi_activos_rojo integer default null,
  p_plazo_ambar_meses integer default null, p_baja_nivel_evaluaciones integer default null,
  p_motivo text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_v     public.fin_fuga_parametros%rowtype;
  v_id    uuid := coalesce(p_id, gen_random_uuid());
  v_nombre uuid;
begin
  v_libro := public.fin_fugas_exigir(p_libro, 'administrar');
  v_nombre := public.fin_fugas_en_nombre(v_libro, p_motivo, true);
  if exists (select 1 from public.fin_fuga_parametros x where x.id = v_id) then
    if exists (select 1 from public.fin_fuga_parametros x where x.id = v_id and x.libro_id = p_libro) then
      return v_id;   -- reintento del mismo cambio
    end if;
    raise exception using errcode = '23505', message = 'Ese id ya es de otro cambio.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('fin_fuga_par:' || p_libro::text, 0));
  select * into v_v from public.fin_v_fuga_parametros_vigentes x where x.libro_id = p_libro;
  if not found then
    v_v.tope_hormiga_centavos := 15000; v_v.hormiga_min_gastos := 8; v_v.hormiga_min_semanas := 3;
    v_v.hormiga_min_ingreso_pb := 100; v_v.hormiga_conjunto_pb := 500; v_v.recurrente_tolerancia_pb := 1000;
    v_v.vampiro_crecimiento_pb := 1000; v_v.zombie_respuestas := 2; v_v.servicio_periodos_min := 6;
    v_v.servicio_periodos_mediana := 12; v_v.servicio_mediana_pb := 2500; v_v.msi_ambar_pb := 1000;
    v_v.msi_rojo_pb := 2000; v_v.msi_activos_ambar := 3; v_v.msi_activos_rojo := 4; v_v.plazo_ambar_meses := 18;
    v_v.baja_nivel_evaluaciones := 2;
  end if;
  insert into public.fin_fuga_parametros (id, hogar_id, libro_id, tope_hormiga_centavos, hormiga_min_gastos,
      hormiga_min_semanas, hormiga_min_ingreso_pb, hormiga_conjunto_pb, recurrente_tolerancia_pb,
      vampiro_crecimiento_pb, zombie_respuestas, servicio_periodos_min, servicio_periodos_mediana,
      servicio_mediana_pb, msi_ambar_pb, msi_rojo_pb, msi_activos_ambar, msi_activos_rojo, plazo_ambar_meses,
      baja_nivel_evaluaciones, cambiado_por, en_nombre_de, motivo)
  values (v_id, v_libro.hogar_id, p_libro,
      coalesce(p_tope_hormiga_centavos, v_v.tope_hormiga_centavos), coalesce(p_hormiga_min_gastos, v_v.hormiga_min_gastos),
      coalesce(p_hormiga_min_semanas, v_v.hormiga_min_semanas), coalesce(p_hormiga_min_ingreso_pb, v_v.hormiga_min_ingreso_pb),
      coalesce(p_hormiga_conjunto_pb, v_v.hormiga_conjunto_pb), coalesce(p_recurrente_tolerancia_pb, v_v.recurrente_tolerancia_pb),
      coalesce(p_vampiro_crecimiento_pb, v_v.vampiro_crecimiento_pb), coalesce(p_zombie_respuestas, v_v.zombie_respuestas),
      coalesce(p_servicio_periodos_min, v_v.servicio_periodos_min), coalesce(p_servicio_periodos_mediana, v_v.servicio_periodos_mediana),
      coalesce(p_servicio_mediana_pb, v_v.servicio_mediana_pb), coalesce(p_msi_ambar_pb, v_v.msi_ambar_pb),
      coalesce(p_msi_rojo_pb, v_v.msi_rojo_pb), coalesce(p_msi_activos_ambar, v_v.msi_activos_ambar),
      coalesce(p_msi_activos_rojo, v_v.msi_activos_rojo), coalesce(p_plazo_ambar_meses, v_v.plazo_ambar_meses),
      coalesce(p_baja_nivel_evaluaciones, v_v.baja_nivel_evaluaciones), public.persona_actual(), v_nombre,
      nullif(btrim(p_motivo), ''));
  return v_id;
end
$$;
comment on function public.fin_fuga_parametros_cambiar(uuid, uuid, bigint, integer, integer, integer, integer, integer,
  integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, text) is
  'Cambia umbrales de un libro agregando una fila nueva (solo lo que se manda; lo demás sigue como estaba). '
  'administrar en el libro. Los valores se validan con los check de la tabla (22023 o 23514).';

-- 6.7 Registrar el semáforo de una deuda: solo cuando cambia el nivel mostrado o el contador de bajas.
create function public.fin_deuda_semaforo_registrar(
  p_id uuid, p_deuda uuid, p_lunes date, p_nivel text, p_senales text[] default '{}',
  p_bajas_seguidas integer default 0, p_calculado_en timestamptz default null)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d    public.fin_deudas%rowtype;
  v_ult  public.fin_deuda_semaforo%rowtype;
begin
  select * into v_d from public.fin_deudas d where d.id = p_deuda;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes usar las fugas y deudas de este libro.';
  end if;
  perform public.fin_fugas_exigir(v_d.libro_id, 'escribir');
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id del registro es obligatorio.';
  end if;
  if p_nivel is null or p_nivel not in ('verde', 'ambar', 'rojo', 'gris') then
    raise exception using errcode = '22023', message = 'Nivel no válido.';
  end if;
  if p_calculado_en is not null and p_calculado_en > now() + interval '1 day' then
    raise exception using errcode = '22023', message = 'La fecha de cálculo no puede estar en el futuro.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('fin_deuda_sem:' || p_deuda::text, 0));
  if exists (select 1 from public.fin_deuda_semaforo s where s.id = p_id) then
    return false;   -- reintento del mismo registro
  end if;
  select * into v_ult from public.fin_deuda_semaforo s
   where s.deuda_id = p_deuda order by s.calculado_en desc, s.recibido_en desc, s.id desc limit 1;
  if found and v_ult.nivel = p_nivel and v_ult.bajas_seguidas = coalesce(p_bajas_seguidas, 0) then
    return false;   -- sin cambio: no se agrega nada
  end if;
  insert into public.fin_deuda_semaforo (id, hogar_id, libro_id, deuda_id, lunes, nivel, senales, bajas_seguidas,
                                         calculado_en, registrado_por)
  values (p_id, v_d.hogar_id, v_d.libro_id, p_deuda, p_lunes, p_nivel, coalesce(p_senales, '{}'),
          coalesce(p_bajas_seguidas, 0), coalesce(p_calculado_en, clock_timestamp()), public.persona_actual());
  return true;
end
$$;
comment on function public.fin_deuda_semaforo_registrar(uuid, uuid, date, text, text[], integer, timestamptz) is
  'Agrega el nivel mostrado de una deuda solo si cambió (o cambió el contador de bajas). Devuelve verdadero si agregó. '
  'escribir en el libro. Los códigos de señal van sin cifras (B1 a M8).';

revoke all on function
  public.fin_fugas_exigir(uuid, text), public.fin_fugas_en_nombre(public.fin_libros, text, boolean),
  public.fin_fugas_hoy(), public.fin_fugas_patron(uuid, text),
  public.fin_fuga_clasificaciones_validar()
  from public, anon, authenticated;
-- Lunes de una semana: puro y sin datos; la app y las pruebas lo pueden llamar.
grant execute on function public.fin_fugas_lunes(date) to authenticated;
revoke all on function
  public.fin_patron_crear(uuid, uuid, text, uuid, text, boolean, text, text, uuid),
  public.fin_fuga_responder(uuid, uuid, text, text, date, timestamptz, text),
  public.fin_fuga_clasificar(uuid, uuid, text, text, text, text, boolean, bigint),
  public.fin_patron_cancelar(uuid, uuid, date, text, text),
  public.fin_deuda_declarar(uuid, uuid, text, text, uuid, uuid, integer, text, boolean, bigint, text),
  public.fin_fuga_parametros_cambiar(uuid, uuid, bigint, integer, integer, integer, integer, integer, integer, integer,
    integer, integer, integer, integer, integer, integer, integer, integer, integer, text),
  public.fin_deuda_semaforo_registrar(uuid, uuid, date, text, text[], integer, timestamptz)
  from public, anon;
grant execute on function
  public.fin_patron_crear(uuid, uuid, text, uuid, text, boolean, text, text, uuid),
  public.fin_fuga_responder(uuid, uuid, text, text, date, timestamptz, text),
  public.fin_fuga_clasificar(uuid, uuid, text, text, text, text, boolean, bigint),
  public.fin_patron_cancelar(uuid, uuid, date, text, text),
  public.fin_deuda_declarar(uuid, uuid, text, text, uuid, uuid, integer, text, boolean, bigint, text),
  public.fin_fuga_parametros_cambiar(uuid, uuid, bigint, integer, integer, integer, integer, integer, integer, integer,
    integer, integer, integer, integer, integer, integer, integer, integer, integer, text),
  public.fin_deuda_semaforo_registrar(uuid, uuid, date, text, text[], integer, timestamptz)
  to authenticated;

-- 7. Avisos (8.3): catálogo cerrado, sin cifras ni comercios (D3, D20) --------------------------------------------------
alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados', 'recordatorio_toma',
  'compra_papa_albacea', 'votacion_abierta', 'votacion_empate', 'reposicion_suplemento',
  'transferencia_pendiente',
  'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala'));

alter table public.avisos drop constraint avisos_objeto_tipo_check;
alter table public.avisos add constraint avisos_objeto_tipo_check check (objeto_tipo in (
  'deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'solicitud_vista', 'cambio_urgente', 'toma',
  'solicitud_pago', 'votacion', 'reposicion', 'transferencia', 'patron'));

create or replace function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90', 'solicitud_vista', 'cambio_urgente_cuidados',
                    'deuda_se_volvio_mala') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80',
                    'recordatorio_toma', 'compra_papa_albacea', 'reposicion_suplemento', 'transferencia_pendiente',
                    'fuga_por_reconocer', 'deuda_en_vigilancia')
      then 'importante'
    else 'informativa' end
$$;

-- Las calcula la app en el dispositivo y las emite con fin_emitir_aviso.
create or replace function public.avisos_tipo_emitible(p_tipo text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_tipo in ('protegido_riesgo', 'flujo_negativo', 'abono_bajo_minimo', 'partida_100', 'partida_80',
                    'fondo_bajo', 'uso_limite', 'aportacion_pendiente', 'conciliacion_pendiente',
                    'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')
$$;

-- Texto genérico de cada aviso nuevo (8.3): hasta 40 caracteres, sin dígitos, sin "$" y sin nombres. La app tiene su propio
-- catálogo; esta función deja el contrato verificable en el servidor. Nulo para cualquier otro tipo.
create function public.fin_fugas_aviso_titulo(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case p_tipo
    when 'fuga_por_reconocer'    then 'Hay un cobro por reconocer'
    when 'fuga_revision_mensual' then 'Tienes una revisión de cobros'
    when 'deuda_en_vigilancia'   then 'Revisa una deuda a meses'
    when 'deuda_se_volvio_mala'  then 'Una deuda necesita atención'
  end
$$;
create function public.avisos_texto_valido(p_texto text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_texto is not null and char_length(p_texto) between 1 and 40 and p_texto !~ '[0-9$]'
$$;
comment on function public.fin_fugas_aviso_titulo(text) is
  'Título genérico (D20) de los cuatro avisos del bloque de fugas y deudas. Los avisos no guardan texto: la app lo toma de su catálogo.';
comment on function public.avisos_texto_valido(text) is
  'D20: un texto de aviso lleva de 1 a 40 caracteres, sin dígitos y sin "$".';

-- Destinatarios: igual que antes; fuga_por_reconocer también va a quien registró (el actor) (8.3).
create or replace function public.fin_avisos_destinatarios(p_libro_id uuid, p_tipo text, p_actor uuid default null)
returns setof uuid
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found then
    return;
  end if;
  -- Quien registró (partida al 80 %, y al 100 % junto con el titular).
  if p_tipo = 'partida_80' or (p_tipo = 'partida_100' and v_libro.tipo = 'compartido') then
    if p_actor is not null and public.fin_destinatario_valido(v_libro.hogar_id, p_actor) then
      return next p_actor;
    end if;
    return;
  end if;
  return query
  with candidatos as (
    select v_libro.titular_id as persona_id where v_libro.tipo = 'personal'
    union
    select m.persona_id from public.fin_libro_miembros m
     where v_libro.tipo = 'compartido' and m.libro_id = p_libro_id and m.desde <= now()
       and (m.hasta is null or m.hasta > now())
    union
    select m.persona_id from public.fin_libro_miembros m
     where v_libro.tipo = 'representado' and m.libro_id = p_libro_id and m.papel = 'albacea'
       and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and public.fin_destinatario_valido(v_libro.hogar_id, m.persona_id)
    union
    select m.persona_id from public.fin_libro_miembros m
     where v_libro.tipo = 'representado' and m.libro_id = p_libro_id and m.papel = 'albacea_suplente'
       and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and public.fin_destinatario_valido(v_libro.hogar_id, m.persona_id)
       and not exists (select 1 from public.fin_libro_miembros a
                        where a.libro_id = p_libro_id and a.papel = 'albacea' and a.desde <= now()
                          and (a.hasta is null or a.hasta > now())
                          and public.fin_destinatario_valido(v_libro.hogar_id, a.persona_id))
  )
  select c.persona_id from candidatos c
   where c.persona_id is not null and public.fin_destinatario_valido(v_libro.hogar_id, c.persona_id)
  union
  select p_actor where p_tipo in ('partida_100', 'fuga_por_reconocer') and p_actor is not null
                   and public.fin_destinatario_valido(v_libro.hogar_id, p_actor);
end
$$;

-- fin_emitir_aviso: igual que antes; acepta el objeto 'patron' y las críticas emitidas por la app (la de deuda mala)
-- tienen el mismo tope de 5 por día y libro.
create or replace function public.fin_emitir_aviso(
  p_libro_id uuid, p_tipo text, p_objeto_tipo text, p_objeto_id uuid, p_clave text)
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_libro   public.fin_libros%rowtype;
  v_actor   uuid := public.persona_actual();
  v_persona uuid;
  v_n       integer := 0;
  v_hoy     integer;
  v_ok      boolean;
  v_crit    integer;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_id;
  if not found or not public.fin_puede(p_libro_id, 'escribir') then
    raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos de ese libro.';
  end if;
  if not public.avisos_tipo_emitible(p_tipo) then
    raise exception using errcode = '22023', message = 'Ese tipo de aviso no lo emite la app.';
  end if;
  if p_objeto_tipo is not null and p_objeto_tipo not in ('deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'patron') then
    raise exception using errcode = '22023', message = 'Tipo de objeto no válido.';
  end if;
  if (p_objeto_tipo is null) <> (p_objeto_id is null) then
    raise exception using errcode = '22023', message = 'El objeto lleva tipo e id, o ninguno.';
  end if;
  if p_clave is null or char_length(p_clave) > 120 or p_clave !~ '^[a-z0-9_:.-]+$' then
    raise exception using errcode = '22023', message = 'La clave son minúsculas, dígitos y _ : . - (máximo 120).';
  end if;
  if not public.fin_destinatario_valido(v_libro.hogar_id, v_actor) then
    raise exception using errcode = '42501', message = 'Solo un miembro con permiso de escribir emite avisos de ese libro.';
  end if;
  -- Los avisos de fugas y deudas solo los emite quien puede ver las deudas del libro (misma regla que las tablas).
  if p_tipo in ('fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')
     and not public.fin_fugas_puede_ver(p_libro_id) then
    raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos de fugas y deudas de ese libro.';
  end if;
  -- F2-3: el objeto debe pertenecer al libro del aviso.
  if p_objeto_id is not null then
    v_ok := case p_objeto_tipo
      when 'deuda' then exists (select 1 from public.fin_deudas x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'ocurrencia' then exists (select 1 from public.fin_ocurrencias x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'partida' then exists (select 1 from public.fin_partidas_semana x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'bolsa' then exists (select 1 from public.fin_bolsas_ahorro x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'semana' then exists (select 1 from public.fin_semanas x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      when 'libro' then p_objeto_id = p_libro_id
      when 'movimiento' then exists (select 1 from public.fin_movimientos x
                                      where x.id = p_objeto_id and (x.libro_origen_id = p_libro_id or x.libro_destino_id = p_libro_id))
      when 'patron' then exists (select 1 from public.fin_patrones_cobro x where x.libro_id = p_libro_id and x.id = p_objeto_id)
      else false end;
    if not coalesce(v_ok, false) then
      raise exception using errcode = '22023', message = 'Ese objeto no es de ese libro.';
    end if;
  end if;
  -- F2-3: las críticas que emite la app se limitan a 5 por día y libro.
  if p_tipo in ('flujo_negativo', 'abono_bajo_minimo', 'deuda_se_volvio_mala') then
    select count(distinct a.clave) into v_crit from public.avisos a
     where a.libro_id = p_libro_id and a.tipo in ('flujo_negativo', 'abono_bajo_minimo', 'deuda_se_volvio_mala')
       and a.emitido_por is not null and a.creado_en > now() - interval '24 hours'
       and a.clave <> p_clave;
    if v_crit >= 5 then
      raise exception using errcode = '22023', message = 'Se llegó al tope de 5 avisos críticos al día en ese libro.';
    end if;
  end if;
  select count(distinct a.clave) into v_hoy from public.avisos a
   where a.emitido_por = v_actor and a.creado_en > now() - interval '24 hours';
  if v_hoy >= 60 then
    raise exception using errcode = '22023', message = 'Se llegó al tope de 60 avisos al día por persona.';
  end if;
  for v_persona in select * from public.fin_avisos_destinatarios(p_libro_id, p_tipo, v_actor) loop
    if public.avisos_insertar(v_libro.hogar_id, v_persona, 'finanzas', p_tipo, p_libro_id, p_objeto_tipo,
                              p_objeto_id, p_clave, now(), v_actor) then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end
$$;

-- Preferencias: los cuatro tipos nuevos se pueden silenciar (suenan menos, siguen en la bandeja). Igual que la versión
-- de Hábitos (20261105) más los cuatro tipos.
create or replace function public.avisos_actualizar_preferencias(
  p_zona_horaria text default null, p_silencio_desde time default null, p_silencio_hasta time default null,
  p_criticas_en_silencio boolean default null, p_tope_no_criticas integer default null,
  p_hora_vencimientos time default null, p_resumen_lunes time default null,
  p_recordatorio_cierre_dia integer default null, p_recordatorio_cierre_hora time default null,
  p_tipos_silenciados text[] default null, p_pulsera_texto_corto boolean default null)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
begin
  if not exists (select 1 from public.avisos_preferencias p where p.persona_id = v_persona) then
    raise exception using errcode = '42501', message = 'Esta cuenta no tiene preferencias de avisos de dinero.';
  end if;
  if p_zona_horaria is not null and not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_zona_horaria) then
    raise exception using errcode = '22023', message = 'Zona horaria desconocida.';
  end if;
  if p_tope_no_criticas is not null and p_tope_no_criticas not between 0 and 10 then
    raise exception using errcode = '22023', message = 'El tope va de 0 a 10.';
  end if;
  if p_recordatorio_cierre_dia is not null and p_recordatorio_cierre_dia not between 1 and 7 then
    raise exception using errcode = '22023', message = 'El día del recordatorio va de 1 (lunes) a 7 (domingo).';
  end if;
  if p_tipos_silenciados is not null and exists (
      select 1 from unnest(p_tipos_silenciados) t
       where t is null or t not in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
             'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
             'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado', 'retiro_bolsa_compartida',
             'resumen_lunes', 'recordatorio_cierre',
             'hab_bloque', 'hab_lectura', 'hab_momento', 'hab_reservado', 'hab_revision_pre', 'hab_revision', 'hab_cierre_dia',
             'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala')) then
    raise exception using errcode = '22023', message = 'Tipo de aviso desconocido.';
  end if;
  if coalesce(p_silencio_desde, (select q.silencio_desde from public.avisos_preferencias q where q.persona_id = v_persona))
     = coalesce(p_silencio_hasta, (select q.silencio_hasta from public.avisos_preferencias q where q.persona_id = v_persona)) then
    raise exception using errcode = '22023', message = 'Las horas silenciosas no pueden empezar y terminar a la misma hora.';
  end if;
  update public.avisos_preferencias p
     set zona_horaria = coalesce(p_zona_horaria, p.zona_horaria),
         silencio_desde = coalesce(p_silencio_desde, p.silencio_desde),
         silencio_hasta = coalesce(p_silencio_hasta, p.silencio_hasta),
         criticas_en_silencio = coalesce(p_criticas_en_silencio, p.criticas_en_silencio),
         tope_no_criticas = coalesce(p_tope_no_criticas, p.tope_no_criticas),
         hora_vencimientos = coalesce(p_hora_vencimientos, p.hora_vencimientos),
         resumen_lunes = coalesce(p_resumen_lunes, p.resumen_lunes),
         recordatorio_cierre_dia = coalesce(p_recordatorio_cierre_dia, p.recordatorio_cierre_dia),
         recordatorio_cierre_hora = coalesce(p_recordatorio_cierre_hora, p.recordatorio_cierre_hora),
         tipos_silenciados = coalesce(p_tipos_silenciados, p.tipos_silenciados),
         pulsera_texto_corto = coalesce(p_pulsera_texto_corto, p.pulsera_texto_corto)
   where p.persona_id = v_persona;
end
$$;
