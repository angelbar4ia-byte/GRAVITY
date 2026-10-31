-- =============================================================================
-- GRAVITY · Fase 2 · Finanzas MVP 2: deudas a detalle y ahorro
-- =============================================================================
-- docs/specs/fase-2-finanzas.md (secciones 4.1, 4.2 y 5.1 a 5.2). Se construye con las
-- propuestas por defecto de la sección 9 mientras el dueño responde.
--
--   * fin_deudas: clase, acreedor, monto original, CAT, día de corte, pago anticipado y
--     qué reduce el extra. Las filas de la Fase 1 se rellenan (con_costo -> credito, o
--     tarjeta si su cuenta pasivo es de tipo tarjeta; familiar -> familiar; msi -> msi).
--   * fin_parametros: orden del ahorro, dependientes, mínimos en lo esencial, días de aviso.
--   * Tablas nuevas: fin_msi, fin_estados_cuenta (solo agregar), fin_bolsas_ahorro,
--     fin_aportaciones_ahorro y fin_retiros_ahorro (solo agregar).
--   * Vistas fin_v_deuda_resumen, fin_v_bolsa_saldo y fin_v_estados_cuenta_vigentes.
--
-- El saldo siempre sale del libro: no se guardan saldos. Una bolsa es una cuenta de tipo
-- ahorro; una deuda, una cuenta pasivo. Aportar y retirar son transferencias.
-- Convención 12: los grants de fin_deudas y fin_parametros repiten la lista completa.
-- Migración nueva (hacia adelante). PostgreSQL 15 o superior. Sin extensiones.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. fin_deudas: columnas nuevas
-- -----------------------------------------------------------------------------
alter table public.fin_deudas
  add column clase text,
  add column acreedor text check (char_length(btrim(acreedor)) between 1 and 80),
  add column monto_original_centavos bigint check (monto_original_centavos > 0),
  add column cat_pb integer check (cat_pb >= 0),
  add column corte_dia smallint check (corte_dia between 0 and 31),
  add column permite_pago_anticipado boolean,
  add column extra_reduce text check (extra_reduce in ('plazo', 'cuota'));

update public.fin_deudas d
   set clase = case d.tipo
                 when 'msi' then 'msi'
                 when 'familiar' then 'familiar'
                 else case when exists (select 1 from public.fin_cuentas c
                                         where c.id = d.cuenta_pasivo_id and c.tipo = 'tarjeta')
                           then 'tarjeta' else 'credito' end
               end;

alter table public.fin_deudas
  alter column clase set not null,
  add constraint fin_deudas_clase check (clase in ('tarjeta', 'prestamo', 'credito', 'msi', 'familiar')),
  add constraint fin_deudas_clase_tipo check ((clase = 'msi') = (tipo = 'msi') and (clase = 'familiar') = (tipo = 'familiar')),
  add constraint fin_deudas_corte_solo_tarjeta check (corte_dia is null or clase = 'tarjeta');
comment on column public.fin_deudas.clase is
  'tarjeta, prestamo, credito, msi o familiar. msi <=> tipo msi; familiar <=> tipo familiar; las demás son con_costo. '
  'Si el INSERT no la trae (cola de la Fase 1) el servidor la deduce.';
comment on column public.fin_deudas.permite_pago_anticipado is
  'Nulo = "verificar con la caja": la app no propone extra a capital mientras sea nulo (regla 12).';

-- La cola de la Fase 1 mandaba deudas sin clase: se deduce del tipo y de la cuenta pasivo.
create function public.fin_deudas_clase_por_omision()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if new.clase is null then
    new.clase := case new.tipo
      when 'msi' then 'msi'
      when 'familiar' then 'familiar'
      else case when exists (select 1 from public.fin_cuentas c
                              where c.id = new.cuenta_pasivo_id and c.tipo = 'tarjeta')
                then 'tarjeta' else 'credito' end
    end;
  end if;
  return new;
end
$$;
-- Se llama fin_a_clase: corre antes de fin_a_una_vez (la comparación del reenvío ya ve la clase).
create trigger fin_a_clase before insert on public.fin_deudas
  for each row execute function public.fin_deudas_clase_por_omision();

grant insert (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma,
              dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil, minimo_centavos,
              tasa_anual_pb, prioridad_manual, grupo_prioritario, orden_grupo, activa,
              clase, acreedor, monto_original_centavos, cat_pb, corte_dia, permite_pago_anticipado, extra_reduce),
      update (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia, forma,
              dia_semana, dias_mes, fecha_ancla, intervalo_meses, regla_inhabil, minimo_centavos,
              tasa_anual_pb, prioridad_manual, grupo_prioritario, orden_grupo, activa,
              clase, acreedor, monto_original_centavos, cat_pb, corte_dia, permite_pago_anticipado, extra_reduce)
  on public.fin_deudas to authenticated;

-- -----------------------------------------------------------------------------
-- 2. fin_parametros: ahorro y avisos
-- -----------------------------------------------------------------------------
alter table public.fin_parametros
  add column orden_ahorro text[] not null default '{fondo_n1,reservas,metas_fecha,fondo_meta,metas_libres}',
  add column dependientes_cuidados boolean not null default false,
  add column esenciales_incluyen_minimos boolean not null default true,
  add column dias_aviso_deuda smallint[] not null default '{3,1}',
  add constraint fin_parametros_orden_ahorro check (
    array_ndims(orden_ahorro) = 1 and cardinality(orden_ahorro) = 5
    and orden_ahorro <@ array['fondo_n1', 'reservas', 'metas_fecha', 'fondo_meta', 'metas_libres']),
  add constraint fin_parametros_dias_aviso check (
    array_ndims(dias_aviso_deuda) = 1 and cardinality(dias_aviso_deuda) between 0 and 3
    and 0 <= all (dias_aviso_deuda) and 14 >= all (dias_aviso_deuda));
comment on column public.fin_parametros.dependientes_cuidados is
  'Lo declara la persona; no se infiere (nivel 4 sugerido del fondo, regla 20).';
comment on column public.fin_parametros.dias_aviso_deuda is
  'Días antes del vencimiento en que avisa (por omisión 3 y 1; de 0 a 3 avisos entre 0 y 14 días).';

create function public.fin_parametros_f2_validar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select count(distinct x) from unnest(new.orden_ahorro) x) <> 5 then
    raise exception using errcode = '23514', message = 'El orden del ahorro no repite pasos.';
  end if;
  if (select count(distinct x) from unnest(new.dias_aviso_deuda) x) <> cardinality(new.dias_aviso_deuda) then
    raise exception using errcode = '23514', message = 'Los días de aviso no se repiten.';
  end if;
  return new;
end
$$;
create trigger fin_b_f2 before insert or update on public.fin_parametros
  for each row execute function public.fin_parametros_f2_validar();

grant insert (libro_id, hogar_id, meta_remanente_pb, ahorro_minimo_con_deuda_pb, tope_arrastre_semanas,
              partida_ambar_pb, partida_rojo_pb, remanente_verde_pb, remanente_ambar_pb, carga_ambar_pb,
              carga_rojo_pb, cumplimiento_verde_pb, cumplimiento_ambar_pb, cierre_automatico_dias,
              cuenta_ajustes_id, cuenta_apertura_id, cuenta_por_clasificar_id,
              orden_ahorro, dependientes_cuidados, esenciales_incluyen_minimos, dias_aviso_deuda),
      update (libro_id, hogar_id, meta_remanente_pb, ahorro_minimo_con_deuda_pb, tope_arrastre_semanas,
              partida_ambar_pb, partida_rojo_pb, remanente_verde_pb, remanente_ambar_pb, carga_ambar_pb,
              carga_rojo_pb, cumplimiento_verde_pb, cumplimiento_ambar_pb, cierre_automatico_dias,
              cuenta_ajustes_id, cuenta_apertura_id, cuenta_por_clasificar_id,
              orden_ahorro, dependientes_cuidados, esenciales_incluyen_minimos, dias_aviso_deuda)
  on public.fin_parametros to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Tablas nuevas
-- -----------------------------------------------------------------------------
create table public.fin_msi (
  id                   uuid primary key default gen_random_uuid(),
  hogar_id             uuid not null references public.hogares (id),
  libro_id             uuid not null,
  deuda_id             uuid not null,
  tarjeta_deuda_id     uuid,
  cuenta_pasivo_id     uuid not null,
  comercio             text check (char_length(btrim(comercio)) between 1 and 80),
  descripcion          text check (char_length(descripcion) <= 120),
  fecha_compra         date not null,
  monto_total_centavos bigint not null check (monto_total_centavos > 0),
  mensualidades        smallint not null check (mensualidades between 2 and 48),
  activo               boolean not null default true,
  constraint fin_msi_libro_id_key unique (libro_id, id),
  constraint fin_msi_deuda_unica unique (deuda_id),
  constraint fin_msi_pasivo_unico unique (cuenta_pasivo_id),
  constraint fin_msi_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_msi_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id),
  constraint fin_msi_tarjeta_fk foreign key (libro_id, tarjeta_deuda_id) references public.fin_deudas (libro_id, id),
  constraint fin_msi_pasivo_fk foreign key (libro_id, cuenta_pasivo_id) references public.fin_cuentas (libro_id, id)
);
comment on table public.fin_msi is
  'Compra a meses sin intereses de un libro. Comercio y descripción son datos del libro: jamás salen en un aviso. '
  'Las mensualidades pagadas y restantes salen de las ocurrencias de su deuda; el saldo, de su cuenta pasivo.';

create table public.fin_estados_cuenta (
  id                          uuid primary key default gen_random_uuid(),
  hogar_id                    uuid not null references public.hogares (id),
  libro_id                    uuid not null,
  deuda_id                    uuid not null,
  fecha_corte                 date not null,
  fecha_limite_pago           date not null,
  saldo_al_corte_centavos     bigint not null,
  pago_minimo_centavos        bigint not null check (pago_minimo_centavos >= 0),
  pago_sin_intereses_centavos bigint not null check (pago_sin_intereses_centavos >= 0),
  intereses_centavos          bigint not null default 0 check (intereses_centavos >= 0),
  cargos_centavos             bigint not null default 0 check (cargos_centavos >= 0),
  tasa_declarada_pb           integer check (tasa_declarada_pb >= 0),
  cat_pb                      integer check (cat_pb >= 0),
  via                         text not null default 'manual' check (via = 'manual'),
  registrado_por              uuid not null default public.persona_actual() references public.personas (id),
  registrado_en               timestamptz not null,
  recibido_en                 timestamptz not null default now(),
  constraint fin_estados_cuenta_fechas check (fecha_limite_pago >= fecha_corte),
  constraint fin_estados_cuenta_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_estados_cuenta_deuda_fk foreign key (libro_id, deuda_id) references public.fin_deudas (libro_id, id)
);
create index fin_estados_cuenta_deuda_idx on public.fin_estados_cuenta (deuda_id, fecha_corte, registrado_en desc);
comment on table public.fin_estados_cuenta is
  'Estado de cuenta capturado a mano. SOLO AGREGAR: para un mismo corte vale el registro más reciente '
  '(registrado_en, luego id); se corrige agregando otro. No hay estimador.';

create table public.fin_bolsas_ahorro (
  id                         uuid primary key default gen_random_uuid(),
  hogar_id                   uuid not null references public.hogares (id),
  libro_id                   uuid not null,
  nombre                     text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo                       text not null check (tipo in ('fondo_emergencia', 'reserva', 'meta_fecha', 'meta_libre')),
  cuenta_id                  uuid not null,
  meta_centavos              bigint check (meta_centavos > 0),
  monto_anual_centavos       bigint check (monto_anual_centavos > 0),
  fecha_meta                 date,
  nivel_meta                 smallint check (nivel_meta between 1 and 5),
  aporte_fijo_centavos       bigint check (aporte_fijo_centavos >= 0),
  aporte_pb                  integer check (aporte_pb between 0 and 10000),
  metodos                    text[] not null default '{}',
  redondeo_multiplo_centavos bigint not null default 1000 check (redondeo_multiplo_centavos > 0),
  reto_base_centavos         bigint check (reto_base_centavos > 0),
  prioridad                  smallint not null default 1 check (prioridad >= 1),
  activa                     boolean not null default true,
  constraint fin_bolsas_libro_id_key unique (libro_id, id),
  constraint fin_bolsas_cuenta_unica unique (cuenta_id),
  constraint fin_bolsas_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_bolsas_cuenta_fk foreign key (libro_id, cuenta_id) references public.fin_cuentas (libro_id, id),
  constraint fin_bolsas_nivel_solo_fondo check ((tipo = 'fondo_emergencia') = (nivel_meta is not null)),
  constraint fin_bolsas_fondo_sin_meta check (tipo <> 'fondo_emergencia' or meta_centavos is null),
  constraint fin_bolsas_reserva check ((tipo = 'reserva') = (monto_anual_centavos is not null)),
  constraint fin_bolsas_meta_fecha check ((tipo = 'meta_fecha') = (fecha_meta is not null)
                                          and (tipo <> 'meta_fecha' or meta_centavos is not null)),
  constraint fin_bolsas_metodos check (
    cardinality(metodos) <= 8 and array_position(metodos, null) is null
    and metodos <@ array['pagate_primero', 'monto_fijo', 'meta_fecha', 'reto_52_semanas', 'redondeo',
                         'sobrante_semanal', 'sobre_categoria', 'porcentaje_extras'])
);
create unique index fin_bolsas_un_fondo on public.fin_bolsas_ahorro (libro_id)
  where tipo = 'fondo_emergencia' and activa;
comment on table public.fin_bolsas_ahorro is
  'Bolsa de ahorro = cuenta de tipo ahorro del libro. Un solo fondo de emergencia activo por libro. Cambiar la '
  'configuración vale de ahí en adelante; el historial son los movimientos. Métodos: pagate_primero, monto_fijo, '
  'meta_fecha, reto_52_semanas, redondeo, sobrante_semanal, sobre_categoria, porcentaje_extras.';

create table public.fin_aportaciones_ahorro (
  id                 uuid primary key default gen_random_uuid(),
  hogar_id           uuid not null references public.hogares (id),
  libro_id           uuid not null,
  semana_id          uuid not null,
  bolsa_id           uuid not null,
  sugerido_centavos  bigint not null check (sugerido_centavos >= 0),
  aportado_centavos  bigint not null default 0 check (aportado_centavos >= 0),
  pendiente_centavos bigint generated always as (greatest(sugerido_centavos - aportado_centavos, 0)) stored,
  estado             text not null default 'propuesta'
                     check (estado in ('propuesta', 'confirmada', 'pospuesta', 'omitida')),
  movimiento_id      uuid,
  confirmada_por     uuid references public.personas (id),
  confirmada_en      timestamptz,
  constraint fin_aportaciones_unica unique (semana_id, bolsa_id),
  constraint fin_aportaciones_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_aportaciones_semana_fk foreign key (libro_id, semana_id) references public.fin_semanas (libro_id, id),
  constraint fin_aportaciones_bolsa_fk foreign key (libro_id, bolsa_id) references public.fin_bolsas_ahorro (libro_id, id),
  constraint fin_aportaciones_movimiento_fk foreign key (hogar_id, movimiento_id) references public.fin_movimientos (hogar_id, id),
  constraint fin_aportaciones_confirmada check ((estado = 'confirmada') = (movimiento_id is not null)
                                                 and (estado <> 'confirmada' or aportado_centavos > 0)
                                                 and (estado = 'confirmada' or aportado_centavos = 0))
);
comment on table public.fin_aportaciones_ahorro is
  'Reparto semanal del ahorro por bolsa. Cambia solo mientras la semana no esté cerrada, salvo confirmar la de la semana '
  'recién cerrada; movimiento_id y aportado no se tocan una vez puestos. Lo no aportado queda como pendiente sin castigo.';

create table public.fin_retiros_ahorro (
  id               uuid primary key default gen_random_uuid(),
  hogar_id         uuid not null references public.hogares (id),
  libro_id         uuid not null,
  bolsa_id         uuid not null,
  movimiento_id    uuid not null,
  tipo             text not null check (tipo in ('uso_previsto', 'emergencia', 'cambio_destino')),
  motivo           text check (char_length(motivo) <= 200),
  bolsa_destino_id uuid,
  registrado_por   uuid not null default public.persona_actual() references public.personas (id),
  registrado_en    timestamptz not null,
  recibido_en      timestamptz not null default now(),
  constraint fin_retiros_movimiento_unico unique (movimiento_id),
  constraint fin_retiros_destino check ((tipo = 'cambio_destino') = (bolsa_destino_id is not null)),
  constraint fin_retiros_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_retiros_bolsa_fk foreign key (libro_id, bolsa_id) references public.fin_bolsas_ahorro (libro_id, id),
  constraint fin_retiros_destino_fk foreign key (bolsa_destino_id) references public.fin_bolsas_ahorro (id),
  constraint fin_retiros_movimiento_fk foreign key (hogar_id, movimiento_id) references public.fin_movimientos (hogar_id, id)
);
comment on table public.fin_retiros_ahorro is
  'Retiro de una bolsa. SOLO AGREGAR. El motivo exige 3 caracteres visibles (fin_motivo_valido).';

-- -----------------------------------------------------------------------------
-- 4. Validaciones (triggers)
-- -----------------------------------------------------------------------------
create function public.fin_msi_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_deuda public.fin_deudas%rowtype;
begin
  select * into v_deuda from public.fin_deudas d where d.libro_id = new.libro_id and d.id = new.deuda_id;
  if found and v_deuda.clase <> 'msi' then
    raise exception using errcode = '22023', message = 'La deuda de un MSI es de clase msi.';
  end if;
  if found and v_deuda.cuenta_pasivo_id <> new.cuenta_pasivo_id then
    raise exception using errcode = '22023', message = 'El MSI usa la cuenta pasivo propia de su deuda.';
  end if;
  if new.tarjeta_deuda_id is not null and exists (
      select 1 from public.fin_deudas t where t.libro_id = new.libro_id and t.id = new.tarjeta_deuda_id and t.clase <> 'tarjeta') then
    raise exception using errcode = '22023', message = 'La tarjeta de un MSI es una deuda de clase tarjeta.';
  end if;
  if exists (select 1 from public.fin_cuentas c where c.id = new.cuenta_pasivo_id and c.tipo <> 'prestamo') then
    raise exception using errcode = '22023', message = 'La cuenta propia de un MSI es de tipo prestamo.';
  end if;
  return new;
end
$$;

create function public.fin_estados_cuenta_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.fin_deudas d where d.libro_id = new.libro_id and d.id = new.deuda_id and d.clase <> 'tarjeta') then
    raise exception using errcode = '22023', message = 'El estado de cuenta es de una deuda de clase tarjeta.';
  end if;
  return new;
end
$$;

create function public.fin_bolsas_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.fin_cuentas c where c.id = new.cuenta_id and c.tipo <> 'ahorro') then
    raise exception using errcode = '22023', message = 'La cuenta de una bolsa es de tipo ahorro.';
  end if;
  return new;
end
$$;

create function public.fin_aportaciones_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_cerrada boolean;
  v_cuenta  uuid;
begin
  select (s.estado = 'cerrada') into v_cerrada from public.fin_semanas s
   where s.libro_id = new.libro_id and s.id = new.semana_id;
  if tg_op = 'UPDATE' then
    if old.movimiento_id is not null and (new.movimiento_id is distinct from old.movimiento_id
                                          or new.aportado_centavos is distinct from old.aportado_centavos) then
      raise exception using errcode = '42501', message = 'El movimiento y lo aportado ya no se cambian.';
    end if;
    -- Semana cerrada: solo se confirma la aportación (la del cierre recién hecho).
    if coalesce(v_cerrada, false) and not (old.estado <> 'confirmada' and new.estado = 'confirmada') then
      raise exception using errcode = '55000', message = 'La semana está cerrada: solo se confirma la aportación.';
    end if;
  end if;
  if new.movimiento_id is not null then
    select b.cuenta_id into v_cuenta from public.fin_bolsas_ahorro b where b.libro_id = new.libro_id and b.id = new.bolsa_id;
    if not exists (select 1 from public.fin_movimientos m
                   where m.id = new.movimiento_id and m.tipo = 'transferencia' and m.cuenta_destino_id = v_cuenta) then
      raise exception using errcode = '22023', message = 'La aportación es una transferencia hacia la cuenta de la bolsa.';
    end if;
  end if;
  if new.estado = 'confirmada' and (tg_op = 'INSERT' or old.estado <> 'confirmada') then
    new.confirmada_por := public.persona_actual();
    new.confirmada_en := now();
  elsif tg_op = 'UPDATE' then
    new.confirmada_por := old.confirmada_por;
    new.confirmada_en := old.confirmada_en;
  end if;
  return new;
end
$$;

create function public.fin_retiros_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_cuenta uuid;
begin
  if not public.fin_motivo_valido(new.motivo) then
    raise exception using errcode = '23514',
      message = 'El motivo necesita al menos 3 caracteres visibles.';
  end if;
  select b.cuenta_id into v_cuenta from public.fin_bolsas_ahorro b where b.libro_id = new.libro_id and b.id = new.bolsa_id;
  if not exists (select 1 from public.fin_movimientos m
                 where m.id = new.movimiento_id and m.tipo = 'transferencia' and m.cuenta_origen_id = v_cuenta) then
    raise exception using errcode = '22023', message = 'El retiro es una transferencia desde la cuenta de la bolsa.';
  end if;
  return new;
end
$$;

create trigger fin_a_una_vez before insert on public.fin_msi
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_msi
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'deuda_id', 'cuenta_pasivo_id');
create trigger fin_b_validar before insert or update on public.fin_msi
  for each row execute function public.fin_msi_validar();

create trigger fin_a_una_vez before insert on public.fin_estados_cuenta
  for each row execute function public.fin_una_vez('estricto', 'recibido_en');
create trigger fin_b_validar before insert on public.fin_estados_cuenta
  for each row execute function public.fin_estados_cuenta_validar();

create trigger fin_a_una_vez before insert on public.fin_bolsas_ahorro
  for each row execute function public.fin_una_vez('flexible');
create trigger fin_a_columnas_fijas before update on public.fin_bolsas_ahorro
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'cuenta_id', 'tipo');
create trigger fin_b_validar before insert or update on public.fin_bolsas_ahorro
  for each row execute function public.fin_bolsas_validar();

create trigger fin_a_una_vez before insert on public.fin_aportaciones_ahorro
  for each row execute function public.fin_una_vez('flexible', 'confirmada_por', 'confirmada_en', 'pendiente_centavos');
create trigger fin_a_columnas_fijas before update on public.fin_aportaciones_ahorro
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'semana_id', 'bolsa_id');
create trigger fin_b_validar before insert or update on public.fin_aportaciones_ahorro
  for each row execute function public.fin_aportaciones_validar();

create trigger fin_a_una_vez before insert on public.fin_retiros_ahorro
  for each row execute function public.fin_una_vez('estricto', 'recibido_en');
create trigger fin_b_validar before insert on public.fin_retiros_ahorro
  for each row execute function public.fin_retiros_validar();

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_estados_cuenta', 'fin_retiros_ahorro'] loop
    execute format('create trigger fin_solo_agregar before update or delete on public.%I
                      for each row execute function public.impedir_cambios_solo_agregar()', v_tabla);
    execute format('create trigger fin_sin_truncate before truncate on public.%I
                      for each statement execute function public.impedir_cambios_solo_agregar()', v_tabla);
  end loop;
  foreach v_tabla in array array['fin_msi', 'fin_estados_cuenta', 'fin_bolsas_ahorro', 'fin_aportaciones_ahorro',
                                 'fin_retiros_ahorro'] loop
    execute format('create trigger fin_z_bitacora after insert or update or delete on public.%I
                      for each row execute function public.registrar_cambio_en_bitacora(''hogar_id'')', v_tabla);
    execute format('alter table public.%I enable row level security', v_tabla);
  end loop;
end
$$;

-- -----------------------------------------------------------------------------
-- 5. Reglas por registro (RLS)
-- -----------------------------------------------------------------------------
do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_msi', 'fin_bolsas_ahorro'] loop
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (public.fin_puede(libro_id, 'leer'))$f$, v_tabla);
    execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                        with check (public.fin_puede(libro_id, 'administrar'))$f$, v_tabla);
    execute format($f$create policy %1$s_editar on public.%1$I for update to authenticated
                        using (public.fin_puede(libro_id, 'administrar'))
                        with check (public.fin_puede(libro_id, 'administrar'))$f$, v_tabla);
  end loop;
  foreach v_tabla in array array['fin_estados_cuenta', 'fin_retiros_ahorro'] loop
    execute format($f$create policy %1$s_leer on public.%1$I for select to authenticated
                        using (public.fin_puede(libro_id, 'leer'))$f$, v_tabla);
    execute format($f$create policy %1$s_agregar on public.%1$I for insert to authenticated
                        with check (registrado_por = (select public.persona_actual())
                                    and public.fin_puede(libro_id, 'escribir'))$f$, v_tabla);
  end loop;
end
$$;
create policy fin_aportaciones_ahorro_leer on public.fin_aportaciones_ahorro for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_aportaciones_ahorro_agregar on public.fin_aportaciones_ahorro for insert to authenticated
  with check (public.fin_puede(libro_id, 'escribir'));
create policy fin_aportaciones_ahorro_editar on public.fin_aportaciones_ahorro for update to authenticated
  using (public.fin_puede(libro_id, 'escribir'))
  with check (public.fin_puede(libro_id, 'escribir'));

-- -----------------------------------------------------------------------------
-- 6. Vistas de apoyo (security_invoker: respetan la RLS de quien consulta)
-- -----------------------------------------------------------------------------
create view public.fin_v_deuda_resumen with (security_invoker = true) as
select d.hogar_id, d.libro_id, d.id as deuda_id, d.nombre, d.clase, d.tipo, d.cuenta_pasivo_id,
       coalesce(s.saldo_centavos, 0)::bigint as saldo_centavos,
       coalesce((select sum(sm.saldo_centavos)
                   from public.fin_msi m
                   join public.fin_v_saldos sm on sm.cuenta_id = m.cuenta_pasivo_id and sm.libro_id = m.libro_id
                  where m.tarjeta_deuda_id = d.id and m.activo), 0)::bigint as msi_pendiente_centavos
from public.fin_deudas d
left join public.fin_v_saldos s on s.cuenta_id = d.cuenta_pasivo_id and s.libro_id = d.libro_id;
comment on view public.fin_v_deuda_resumen is
  'Saldo de cada deuda (desde el libro) y, en una tarjeta, el saldo pendiente de sus MSI. No guarda nada.';

create view public.fin_v_bolsa_saldo with (security_invoker = true) as
select b.hogar_id, b.libro_id, b.id as bolsa_id, b.nombre, b.tipo, b.cuenta_id, b.activa,
       coalesce(s.saldo_centavos, 0)::bigint as saldo_centavos
from public.fin_bolsas_ahorro b
left join public.fin_v_saldos s on s.cuenta_id = b.cuenta_id and s.libro_id = b.libro_id;
comment on view public.fin_v_bolsa_saldo is 'Saldo de cada bolsa de ahorro, desde su cuenta del libro.';

create view public.fin_v_estados_cuenta_vigentes with (security_invoker = true) as
select distinct on (e.deuda_id, e.fecha_corte) e.*
from public.fin_estados_cuenta e
order by e.deuda_id, e.fecha_corte, e.registrado_en desc, e.id desc;
comment on view public.fin_v_estados_cuenta_vigentes is
  'El registro más reciente de cada corte (lo vigente; los demás son el historial).';

-- -----------------------------------------------------------------------------
-- 7. Privilegios
-- -----------------------------------------------------------------------------
revoke all on table
  public.fin_msi, public.fin_estados_cuenta, public.fin_bolsas_ahorro, public.fin_aportaciones_ahorro,
  public.fin_retiros_ahorro, public.fin_v_deuda_resumen, public.fin_v_bolsa_saldo, public.fin_v_estados_cuenta_vigentes
  from public, anon, authenticated, service_role;

grant select on
  public.fin_msi, public.fin_estados_cuenta, public.fin_bolsas_ahorro, public.fin_aportaciones_ahorro,
  public.fin_retiros_ahorro, public.fin_v_deuda_resumen, public.fin_v_bolsa_saldo, public.fin_v_estados_cuenta_vigentes
  to authenticated, service_role;

grant insert (id, hogar_id, libro_id, deuda_id, tarjeta_deuda_id, cuenta_pasivo_id, comercio, descripcion,
              fecha_compra, monto_total_centavos, mensualidades, activo),
      update (id, hogar_id, libro_id, deuda_id, tarjeta_deuda_id, cuenta_pasivo_id, comercio, descripcion,
              fecha_compra, monto_total_centavos, mensualidades, activo)
  on public.fin_msi to authenticated;
grant insert (id, hogar_id, libro_id, nombre, tipo, cuenta_id, meta_centavos, monto_anual_centavos, fecha_meta,
              nivel_meta, aporte_fijo_centavos, aporte_pb, metodos, redondeo_multiplo_centavos, reto_base_centavos,
              prioridad, activa),
      update (id, hogar_id, libro_id, nombre, tipo, cuenta_id, meta_centavos, monto_anual_centavos, fecha_meta,
              nivel_meta, aporte_fijo_centavos, aporte_pb, metodos, redondeo_multiplo_centavos, reto_base_centavos,
              prioridad, activa)
  on public.fin_bolsas_ahorro to authenticated;
grant insert (id, hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos, aportado_centavos, estado, movimiento_id),
      update (id, hogar_id, libro_id, semana_id, bolsa_id, sugerido_centavos, aportado_centavos, estado, movimiento_id)
  on public.fin_aportaciones_ahorro to authenticated;
grant insert (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago, saldo_al_corte_centavos,
              pago_minimo_centavos, pago_sin_intereses_centavos, intereses_centavos, cargos_centavos,
              tasa_declarada_pb, cat_pb, via, registrado_por, registrado_en)
  on public.fin_estados_cuenta to authenticated;
grant insert (id, hogar_id, libro_id, bolsa_id, movimiento_id, tipo, motivo, bolsa_destino_id, registrado_por,
              registrado_en)
  on public.fin_retiros_ahorro to authenticated;

grant insert, update on public.fin_msi, public.fin_bolsas_ahorro, public.fin_aportaciones_ahorro to service_role;
grant insert on public.fin_estados_cuenta, public.fin_retiros_ahorro to service_role;

revoke execute on function
  public.fin_deudas_clase_por_omision(), public.fin_parametros_f2_validar(), public.fin_msi_validar(),
  public.fin_estados_cuenta_validar(), public.fin_bolsas_validar(), public.fin_aportaciones_validar(),
  public.fin_retiros_validar()
  from public, anon, authenticated, service_role;
