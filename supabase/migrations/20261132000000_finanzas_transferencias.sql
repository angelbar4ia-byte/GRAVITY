-- =============================================================================
-- GRAVITY · Finanzas · Ampliaciones bloque 1 v1.0 (docs/specs/fase-8-finanzas-ampliaciones.md)
-- Transferencias con confirmación del receptor, casa con subcuentas, registro de
-- aportantes y periodo de la aportación.
-- =============================================================================
-- * Transferencias (sección 1): solo tres rutas, pareja -> dueño, dueño -> casa
--   y pareja -> casa. Se proponen con fin_proponer_transferencia(); el receptor
--   las confirma o rechaza con fin_responder_transferencia(); quien propone puede
--   cancelarlas con fin_cancelar_transferencia(). Sin confirmación no hay
--   movimiento. Al confirmar, el servidor registra UN movimiento de tipo
--   transferencia entre los dos libros (libro solo-agregar): se ve desde los dos.
--   Rechazada o cancelada queda como registro; nada se borra. Papá (libro
--   representado) no es ruta de transferencias: lo suyo lo mueve su albacea (D19).
-- * Casa (sección 1, estructura de cuentas): la casa es un libro compartido
--   designado en fin_casa_config. Sus subcuentas (fin_casa_subcuentas) son los
--   servicios, que el modelo ya tiene como categorías con cuenta de gasto del
--   hogar. Cada pago de servicio (fin_casa_pagar_servicio) guarda quién pagó y
--   quién APORTÓ (fin_casa_aportes).
-- * Periodo de la aportación (sección 2a): semana, mes, bimestre, semestre o año
--   por hogar; parte de referencia por persona (Papá 50 %; dueño y pareja, 25 %
--   cada uno); ingreso por persona con RLS por persona; fecha límite por subcuenta.
--   La aportación es libre: nada marca deudores.
-- * Dinero en centavos. La bitácora de las transferencias y de los ingresos no
--   lleva montos. La cuenta maestra solo lee (con su consulta vigente); la
--   cuidadora y la cuenta Casa no ven nada (sus roles no tienen Finanzas).
-- Compatible con PostgreSQL 15 o superior.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tipo común
-- -----------------------------------------------------------------------------
create domain public.fin_periodo_aportacion as text
  check (value in ('semana', 'mes', 'bimestre', 'semestre', 'anual'));
comment on domain public.fin_periodo_aportacion is
  'Periodo de la aportación a la casa (spec fase 8, 2a): semana (lunes a domingo), mes, bimestre '
  '(meses 1-2, 3-4…), semestre (enero-junio, julio-diciembre) o año.';

-- -----------------------------------------------------------------------------
-- 2. Casa: configuración por hogar, partes de referencia e ingreso por persona
-- -----------------------------------------------------------------------------
create table public.fin_casa_config (
  hogar_id        uuid primary key references public.hogares (id),
  libro_id        uuid not null,
  periodo         public.fin_periodo_aportacion not null default 'mes',
  actualizado_por uuid default public.persona_actual() references public.personas (id),
  actualizado_en  timestamptz not null default now(),
  constraint fin_casa_config_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_casa_config_libro_unico unique (libro_id)
);
comment on table public.fin_casa_config is
  'Configuración de la casa por hogar: qué libro compartido es la cuenta general de la casa y el periodo de '
  'la aportación (semana, mes, bimestre, semestre o año). Una fila por hogar; se cambia con fin_casa_configurar().';

create table public.fin_casa_referencias (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid not null,
  persona_id      uuid not null references public.personas (id),
  parte_pb        integer not null check (parte_pb between 0 and 10000),
  actualizado_por uuid default public.persona_actual() references public.personas (id),
  actualizado_en  timestamptz not null default now(),
  constraint fin_casa_referencias_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_casa_referencias_unica unique (hogar_id, persona_id)
);
comment on table public.fin_casa_referencias is
  'Parte de REFERENCIA de cada persona en la aportación a la casa, en puntos base (5000 = 50 %). Por omisión: '
  'Papá 5000; el dueño y la pareja, 2500 cada uno. Es una referencia, no una obligación ni una deuda. La suma '
  'del hogar no pasa de 10000.';

create table public.fin_casa_ingresos (
  id               uuid primary key default gen_random_uuid(),
  hogar_id         uuid not null references public.hogares (id),
  libro_id         uuid not null,
  persona_id       uuid not null references public.personas (id),
  ingreso_centavos bigint not null check (ingreso_centavos >= 0),
  periodo          public.fin_periodo_aportacion not null default 'mes',
  actualizado_por  uuid default public.persona_actual() references public.personas (id),
  actualizado_en   timestamptz not null default now(),
  constraint fin_casa_ingresos_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_casa_ingresos_unico unique (hogar_id, persona_id)
);
comment on table public.fin_casa_ingresos is
  'Ingreso de cada persona por periodo, como dato para la aportación (spec 2a). Dato personal: lo lee y lo '
  'escribe quien lleva su libro (la persona; el albacea en el caso de Papá); la cuenta maestra lo lee con su '
  'consulta vigente. No sale a la IA ni a las bocinas (D3). Su bitácora no lleva el monto.';
comment on column public.fin_casa_ingresos.libro_id is 'Libro personal (o representado) de la persona; lo pone el servidor.';

-- -----------------------------------------------------------------------------
-- 3. Subcuentas de la casa (servicios) y aportes
-- -----------------------------------------------------------------------------
create table public.fin_casa_subcuentas (
  id                      uuid primary key default gen_random_uuid(),
  hogar_id                uuid not null references public.hogares (id),
  libro_id                uuid not null,
  categoria_id            uuid not null,
  activa                  boolean not null default true,
  dia_limite              smallint check (dia_limite between 1 and 31),
  cada_meses              smallint not null default 1 check (cada_meses in (1, 2, 3, 6, 12)),
  proximo_vencimiento     date,
  monto_estimado_centavos bigint check (monto_estimado_centavos > 0),
  creada_por              uuid default public.persona_actual() references public.personas (id),
  creada_en               timestamptz not null default now(),
  constraint fin_casa_subcuentas_hogar_id_key unique (hogar_id, id),
  constraint fin_casa_subcuentas_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_casa_subcuentas_categoria_fk foreign key (hogar_id, categoria_id)
    references public.fin_categorias (hogar_id, id) on delete restrict,
  constraint fin_casa_subcuentas_una_por_categoria unique (libro_id, categoria_id)
);
comment on table public.fin_casa_subcuentas is
  'Subcuentas de la casa: los servicios y gastos (luz, agua, teléfono…). Cada una es una categoría de gasto del '
  'hogar (con su cuenta de gasto); los pagos son movimientos de gasto de esa categoría. Lleva la fecha límite '
  '(dia_limite y proximo_vencimiento) y un estimado por ciclo (cada_meses). No se borran: se desactivan.';

create table public.fin_casa_aportes (
  id               uuid primary key default gen_random_uuid(),
  hogar_id         uuid not null references public.hogares (id),
  libro_id         uuid not null,
  subcuenta_id     uuid not null,
  movimiento_id    uuid not null,
  aportante_id     uuid not null references public.personas (id),
  pagado_por       uuid not null references public.personas (id),
  monto_centavos   bigint not null check (monto_centavos > 0),
  fecha            date not null,
  suma_al_aportado boolean not null,
  creado_en        timestamptz not null default now(),
  constraint fin_casa_aportes_subcuenta_fk foreign key (hogar_id, subcuenta_id)
    references public.fin_casa_subcuentas (hogar_id, id),
  constraint fin_casa_aportes_libro_fk foreign key (hogar_id, libro_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_casa_aportes_movimiento_fk foreign key (hogar_id, movimiento_id)
    references public.fin_movimientos (hogar_id, id),
  constraint fin_casa_aportes_un_movimiento unique (movimiento_id)
);
create index fin_casa_aportes_aportante_idx on public.fin_casa_aportes (aportante_id, fecha);
comment on table public.fin_casa_aportes is
  'Quién APORTÓ a cada pago de un servicio de la casa (aportante_id), además de quién lo pagó (pagado_por). '
  'Solo agregar. suma_al_aportado es falso cuando el pago salió de una cuenta de la casa (ese dinero ya se '
  'contó cuando entró a la casa por una transferencia) y verdadero cuando salió de un libro personal o del '
  'de Papá.';

-- -----------------------------------------------------------------------------
-- 4. Transferencias entre personas (confirma el receptor)
-- -----------------------------------------------------------------------------
create table public.fin_transferencias (
  id                 uuid primary key default gen_random_uuid(),
  hogar_id           uuid not null references public.hogares (id),
  ruta               text not null check (ruta in ('pareja_a_dueno', 'dueno_a_casa', 'pareja_a_casa')),
  estado             text not null default 'pendiente'
                     check (estado in ('pendiente', 'confirmada', 'rechazada', 'cancelada')),
  persona_origen_id  uuid not null references public.personas (id),
  persona_destino_id uuid references public.personas (id),
  libro_origen_id    uuid not null,
  libro_destino_id   uuid not null,
  cuenta_origen_id   uuid not null,
  cuenta_destino_id  uuid,
  monto_centavos     bigint not null check (monto_centavos > 0),
  fecha              date not null,
  nota               text check (char_length(nota) <= 200),
  propuesta_por      uuid not null references public.personas (id),
  propuesta_en       timestamptz not null default now(),
  confirmada_por     uuid references public.personas (id),
  respondida_por     uuid references public.personas (id),
  respondida_en      timestamptz,
  movimiento_id      uuid,
  constraint fin_transferencias_hogar_id_key unique (hogar_id, id),
  constraint fin_transferencias_libro_origen_fk foreign key (hogar_id, libro_origen_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_transferencias_libro_destino_fk foreign key (hogar_id, libro_destino_id)
    references public.fin_libros (hogar_id, id),
  constraint fin_transferencias_cuenta_origen_fk foreign key (hogar_id, cuenta_origen_id)
    references public.fin_cuentas (hogar_id, id),
  constraint fin_transferencias_cuenta_destino_fk foreign key (hogar_id, cuenta_destino_id)
    references public.fin_cuentas (hogar_id, id),
  constraint fin_transferencias_movimiento_fk foreign key (hogar_id, movimiento_id)
    references public.fin_movimientos (hogar_id, id) deferrable initially deferred,
  constraint fin_transferencias_movimiento_unico unique (movimiento_id),
  constraint fin_transferencias_destino_persona
    check ((ruta = 'pareja_a_dueno') = (persona_destino_id is not null)),
  constraint fin_transferencias_distintas check (persona_destino_id is distinct from persona_origen_id),
  constraint fin_transferencias_estado_coherente check (
    case estado
      when 'pendiente' then confirmada_por is null and movimiento_id is null
                            and respondida_en is null and respondida_por is null
      when 'confirmada' then confirmada_por is not null and movimiento_id is not null
                             and cuenta_destino_id is not null
                             and respondida_en is not null and respondida_por = confirmada_por
      else confirmada_por is null and movimiento_id is null
           and respondida_en is not null and respondida_por is not null
    end)
);
create index fin_transferencias_pendientes_idx on public.fin_transferencias (hogar_id, estado);
create index fin_transferencias_origen_idx on public.fin_transferencias (persona_origen_id);
create index fin_transferencias_destino_idx on public.fin_transferencias (persona_destino_id)
  where persona_destino_id is not null;
comment on table public.fin_transferencias is
  'Transferencias entre personas (spec fase 8, sección 1). Rutas: pareja_a_dueno, dueno_a_casa, pareja_a_casa. '
  'La propone quien envía y la confirma el receptor (o, si el receptor es la casa, otro miembro de su libro); '
  'solo entonces el servidor registra el movimiento. Rechazada o cancelada queda como registro. No se borra ni '
  'se edita fuera de los cambios de estado de las RPC. Su bitácora no lleva monto ni nota.';
comment on column public.fin_transferencias.cuenta_destino_id is
  'Cuenta que recibe: la elige el receptor al confirmar (quien propone no ve el libro de quien recibe).';
comment on column public.fin_transferencias.confirmada_por is 'Quién confirmó; nulo mientras esté pendiente, rechazada o cancelada.';
comment on column public.fin_transferencias.movimiento_id is 'Movimiento (tipo transferencia) que generó la confirmación.';

-- -----------------------------------------------------------------------------
-- 5. Funciones de apoyo (SECURITY DEFINER, search_path vacío)
-- -----------------------------------------------------------------------------
-- Rol vigente de otra persona en un hogar.
create function public.fin_rol_de(p_hogar_id uuid, p_persona_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select m.rol::text
  from public.membresias m
  where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id
    and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
  limit 1
$$;

-- Libro designado como "casa" (cuenta general) de un hogar; nulo si no hay.
create function public.fin_casa_libro(p_hogar_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$ select c.libro_id from public.fin_casa_config c where c.hogar_id = p_hogar_id $$;
comment on function public.fin_casa_libro(uuid) is 'Libro de la casa del hogar (fin_casa_config), o nulo.';

-- Rango [desde, hasta] (ambos inclusive) del periodo que contiene la fecha.
create function public.fin_periodo_rango(p_periodo text, p_fecha date)
returns table (desde date, hasta date)
language plpgsql immutable
set search_path = ''
as $$
declare
  v_mes int;
  v_ini int;
begin
  perform p_periodo::public.fin_periodo_aportacion;
  if p_fecha is null then
    raise exception using errcode = '22023', message = 'La fecha es obligatoria';
  end if;
  v_mes := extract(month from p_fecha)::int;
  case p_periodo
    when 'semana' then
      desde := p_fecha - (extract(isodow from p_fecha)::int - 1);
      hasta := desde + 6;
    when 'mes' then
      desde := date_trunc('month', p_fecha)::date;
      hasta := (desde + interval '1 month' - interval '1 day')::date;
    when 'bimestre' then
      v_ini := ((v_mes - 1) / 2) * 2 + 1;
      desde := make_date(extract(year from p_fecha)::int, v_ini, 1);
      hasta := (desde + interval '2 months' - interval '1 day')::date;
    when 'semestre' then
      v_ini := case when v_mes <= 6 then 1 else 7 end;
      desde := make_date(extract(year from p_fecha)::int, v_ini, 1);
      hasta := (desde + interval '6 months' - interval '1 day')::date;
    else
      desde := make_date(extract(year from p_fecha)::int, 1, 1);
      hasta := make_date(extract(year from p_fecha)::int, 12, 31);
  end case;
  return next;
end
$$;
comment on function public.fin_periodo_rango(text, date) is
  'Rango [desde, hasta] del periodo (semana, mes, bimestre, semestre, anual) que contiene la fecha. Semana en lunes.';

-- Libro personal (o representado) de una persona en un hogar; nulo si no lleva.
create function public.fin_libro_de_persona(p_hogar_id uuid, p_persona_id uuid)
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select l.id from public.fin_libros l
  where l.hogar_id = p_hogar_id and l.titular_id = p_persona_id and l.tipo in ('personal', 'representado')
  order by case l.tipo when 'personal' then 1 else 2 end
  limit 1
$$;

-- Quién puede ejecutar la inserción del movimiento de una transferencia confirmada.
create function public.fin_transferencia_autoriza(
  p_movimiento_id uuid, p_tipo text, p_cuenta_origen uuid, p_cuenta_destino uuid, p_monto bigint)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_tipo = 'transferencia'
     and exists (
       select 1 from public.fin_transferencias t
       where t.movimiento_id = p_movimiento_id and t.estado = 'confirmada'
         and t.confirmada_por = public.persona_actual()
         and t.cuenta_origen_id = p_cuenta_origen and t.cuenta_destino_id = p_cuenta_destino
         and t.monto_centavos = p_monto)
$$;
comment on function public.fin_transferencia_autoriza(uuid, text, uuid, uuid, bigint) is
  'Verdadero solo para el movimiento que enlaza una transferencia ya confirmada por quien consulta (la fila '
  'solo la cambian las RPC): es la única excepción a "para registrar hay que escribir en cada libro".';

-- -----------------------------------------------------------------------------
-- 6. El validador de movimientos acepta esa excepción (el resto, igual)
-- -----------------------------------------------------------------------------
create or replace function public.fin_movimientos_validar()
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
  --    Excepción única: la transferencia que el receptor acaba de confirmar con
  --    fin_responder_transferencia() (el servidor ya la dejó confirmada y enlazada
  --    a este movimiento; el receptor no escribe en el libro de quien la propuso).
  if auth.uid() is not null and not (
       (new.libro_origen_id is null or public.fin_puede(new.libro_origen_id, 'escribir'))
       and (new.libro_destino_id is null or public.fin_puede(new.libro_destino_id, 'escribir')))
     and not public.fin_transferencia_autoriza(new.id, new.tipo, new.cuenta_origen_id,
                                               new.cuenta_destino_id, new.monto_centavos) then
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
    if (v_origen.estado in ('cerrada', 'archivada') and v_origen.clase in ('activo', 'pasivo'))
       or (v_destino.estado in ('cerrada', 'archivada') and v_destino.clase in ('activo', 'pasivo')) then
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
-- -----------------------------------------------------------------------------
-- 7. Triggers
-- -----------------------------------------------------------------------------
-- Transferencias: no se borran y solo cambian de estado (pendiente -> otro) por
-- las RPC; el resto de las columnas no cambia nunca.
create function public.fin_transferencias_proteger()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_libres text[] := array['estado', 'cuenta_destino_id', 'confirmada_por', 'respondida_por',
                           'respondida_en', 'movimiento_id'];
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '42501',
      message = 'Una transferencia no se borra: rechazada o cancelada queda como registro.';
  end if;
  if old.estado <> 'pendiente' then
    raise exception using errcode = '55000',
      message = format('La transferencia ya está %s: no cambia.', old.estado);
  end if;
  if (to_jsonb(old) - v_libres) is distinct from (to_jsonb(new) - v_libres) then
    raise exception using errcode = '42501', message = 'Una transferencia solo cambia de estado.';
  end if;
  return new;
end
$$;
create trigger fin_a_proteger before update or delete on public.fin_transferencias
  for each row execute function public.fin_transferencias_proteger();
create trigger fin_sin_truncate before truncate on public.fin_transferencias
  for each statement execute function public.impedir_cambios_solo_agregar();

-- Aportes: solo agregar.
create trigger fin_solo_agregar before update or delete on public.fin_casa_aportes
  for each row execute function public.impedir_cambios_solo_agregar();
create trigger fin_sin_truncate before truncate on public.fin_casa_aportes
  for each statement execute function public.impedir_cambios_solo_agregar();

-- Subcuentas: del libro de la casa y con categoría de gasto del hogar.
create function public.fin_casa_subcuentas_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_casa uuid := public.fin_casa_libro(new.hogar_id);
  v_cuenta public.fin_cuentas%rowtype;
begin
  if v_casa is null or new.libro_id is distinct from v_casa then
    raise exception using errcode = '22023', message = 'La subcuenta va en el libro de la casa del hogar.';
  end if;
  select c.* into v_cuenta
  from public.fin_categorias k
  join public.fin_cuentas c on c.hogar_id = k.hogar_id and c.id = k.cuenta_gasto_id
  where k.hogar_id = new.hogar_id and k.id = new.categoria_id;
  if not found or v_cuenta.tipo <> 'de_gasto' then
    raise exception using errcode = '22023',
      message = 'La subcuenta es una categoría de gasto del hogar (con su cuenta de gasto).';
  end if;
  return new;
end
$$;
create trigger fin_a_una_vez before insert on public.fin_casa_subcuentas
  for each row execute function public.fin_una_vez('flexible', 'creada_en');
create trigger fin_a_columnas_fijas before update on public.fin_casa_subcuentas
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'categoria_id');
create trigger fin_b_validar before insert or update on public.fin_casa_subcuentas
  for each row execute function public.fin_casa_subcuentas_validar();

-- Partes de referencia: el libro lo pone el servidor; solo Papá, el dueño y la
-- pareja; la suma del hogar no pasa de 10000 (100 %).
create function public.fin_casa_referencias_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_casa  uuid := public.fin_casa_libro(new.hogar_id);
  v_rol   text;
  v_otras bigint;
begin
  if v_casa is null then
    raise exception using errcode = '22023', message = 'La casa aún no tiene su libro configurado.';
  end if;
  new.libro_id := v_casa;
  v_rol := public.fin_rol_de(new.hogar_id, new.persona_id);
  if not (
       exists (select 1 from public.fin_libros l
               where l.hogar_id = new.hogar_id and l.tipo = 'representado' and l.titular_id = new.persona_id)
       or (v_rol in ('dueno', 'coadministrador')
           and exists (select 1 from public.fin_libros l
                       where l.hogar_id = new.hogar_id and l.tipo = 'personal' and l.titular_id = new.persona_id))) then
    raise exception using errcode = '22023',
      message = 'La referencia es de Papá, del dueño o de la pareja del hogar.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('fin_casa_referencias:' || new.hogar_id::text, 0));
  select coalesce(sum(r.parte_pb), 0) into v_otras
  from public.fin_casa_referencias r
  where r.hogar_id = new.hogar_id and r.persona_id <> new.persona_id;
  if v_otras + new.parte_pb > 10000 then
    raise exception using errcode = '23514', message = 'Las partes de referencia no pasan de 100 %.';
  end if;
  new.actualizado_por := public.persona_actual();
  new.actualizado_en := now();
  return new;
end
$$;
create trigger fin_a_columnas_fijas before update on public.fin_casa_referencias
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'persona_id');
create trigger fin_b_validar before insert or update on public.fin_casa_referencias
  for each row execute function public.fin_casa_referencias_validar();

-- Ingreso por persona: el libro es el de la persona (lo pone el servidor).
create function public.fin_casa_ingresos_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  new.libro_id := public.fin_libro_de_persona(new.hogar_id, new.persona_id);
  if new.libro_id is null then
    raise exception using errcode = '22023', message = 'Esa persona no lleva un libro de Finanzas en el hogar.';
  end if;
  new.actualizado_por := public.persona_actual();
  new.actualizado_en := now();
  return new;
end
$$;
create trigger fin_a_columnas_fijas before update on public.fin_casa_ingresos
  for each row execute function public.fin_columnas_fijas('id', 'hogar_id', 'libro_id', 'persona_id');
create trigger fin_b_validar before insert or update on public.fin_casa_ingresos
  for each row execute function public.fin_casa_ingresos_validar();

-- Bitácora. Transferencias e ingresos, sin montos ni notas.
create trigger fin_z_bitacora after insert or update or delete on public.fin_transferencias
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'monto_centavos', 'nota');
create trigger fin_z_bitacora after insert or update or delete on public.fin_casa_ingresos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'ingreso_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_casa_config
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger fin_z_bitacora after insert or update or delete on public.fin_casa_referencias
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger fin_z_bitacora after insert or update or delete on public.fin_casa_subcuentas
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger fin_z_bitacora after insert or update or delete on public.fin_casa_aportes
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');

-- -----------------------------------------------------------------------------
-- 8. Operaciones (RPC)
-- -----------------------------------------------------------------------------
-- 8.1 Proponer una transferencia. El destino es una persona (pareja -> dueño) o,
-- con p_destino_persona nulo, la casa. Idempotente por p_id (cola sin conexión).
create function public.fin_proponer_transferencia(
  p_id uuid, p_cuenta_origen uuid, p_destino_persona uuid, p_monto_centavos bigint,
  p_fecha date default current_date, p_nota text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo      uuid := public.persona_actual();
  v_cuenta  public.fin_cuentas%rowtype;
  v_libro   public.fin_libros%rowtype;
  v_rol     text;
  v_rol_d   text;
  v_ruta    text;
  v_ldest   uuid;
  v_previa  public.fin_transferencias%rowtype;
begin
  if v_yo is null then
    raise exception using errcode = '42501', message = 'Sin sesión.';
  end if;
  if p_id is null or p_cuenta_origen is null or p_monto_centavos is null or p_monto_centavos <= 0 then
    raise exception using errcode = '22023', message = 'La transferencia lleva identificador, cuenta y un monto mayor a cero (centavos).';
  end if;
  if p_nota is not null and char_length(p_nota) > 200 then
    raise exception using errcode = '22023', message = 'La nota no pasa de 200 caracteres.';
  end if;
  select * into v_cuenta from public.fin_cuentas c where c.id = p_cuenta_origen;
  if not found or v_cuenta.libro_id is null then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esa cuenta.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = v_cuenta.libro_id;
  if v_libro.tipo <> 'personal' or v_libro.titular_id is distinct from v_yo
     or not public.fin_puede(v_libro.id, 'escribir') then
    raise exception using errcode = '42501',
      message = 'Solo propones transferencias desde tu propio libro personal.';
  end if;
  if v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' then
    raise exception using errcode = '22023', message = 'La cuenta de origen es una cuenta de dinero activa.';
  end if;

  v_rol := public.fin_rol_de(v_libro.hogar_id, v_yo);
  if p_destino_persona is null then
    v_ldest := public.fin_casa_libro(v_libro.hogar_id);
    if v_ldest is null then
      raise exception using errcode = '22023', message = 'La casa aún no tiene su cuenta general configurada.';
    end if;
    v_ruta := case v_rol when 'dueno' then 'dueno_a_casa' when 'coadministrador' then 'pareja_a_casa' end;
  else
    v_rol_d := public.fin_rol_de(v_libro.hogar_id, p_destino_persona);
    if p_destino_persona <> v_yo and v_rol = 'coadministrador' and v_rol_d = 'dueno' then
      v_ruta := 'pareja_a_dueno';
      v_ldest := (select l.id from public.fin_libros l
                  where l.hogar_id = v_libro.hogar_id and l.tipo = 'personal' and l.titular_id = p_destino_persona);
    end if;
  end if;
  if v_ruta is null or v_ldest is null then
    raise exception using errcode = '22023',
      message = 'Esa ruta no está permitida: solo pareja a dueño, dueño a casa y pareja a casa.';
  end if;

  select * into v_previa from public.fin_transferencias t where t.id = p_id;
  if found then
    if v_previa.persona_origen_id = v_yo and v_previa.cuenta_origen_id = p_cuenta_origen
       and v_previa.persona_destino_id is not distinct from p_destino_persona
       and v_previa.monto_centavos = p_monto_centavos and v_previa.fecha = p_fecha
       and v_previa.nota is not distinct from p_nota then
      return p_id;
    end if;
    raise exception using errcode = '23505', message = format('Ya existe la transferencia %s con otro contenido.', p_id);
  end if;

  insert into public.fin_transferencias (id, hogar_id, ruta, persona_origen_id, persona_destino_id,
    libro_origen_id, libro_destino_id, cuenta_origen_id, monto_centavos, fecha, nota, propuesta_por)
  values (p_id, v_libro.hogar_id, v_ruta, v_yo, p_destino_persona, v_libro.id, v_ldest, p_cuenta_origen,
          p_monto_centavos, p_fecha, p_nota, v_yo);
  return p_id;
end
$$;
comment on function public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text) is
  'Propone una transferencia desde tu libro personal: a la persona dueña (si eres la pareja) o, con '
  'p_destino_persona nulo, a la casa (dueño o pareja). Queda pendiente: sin confirmación no hay movimiento.';

-- 8.2 Responder (el receptor): confirmar genera el movimiento; rechazar solo cierra.
-- p_cuenta_destino: la cuenta que recibe; si falta y el libro destino tiene una sola
-- cuenta de dinero activa, se usa esa. Devuelve el id del movimiento (nulo al rechazar).
create function public.fin_responder_transferencia(
  p_transferencia uuid, p_accion text, p_cuenta_destino uuid default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo      uuid := public.persona_actual();
  v_t       public.fin_transferencias%rowtype;
  v_cuenta  public.fin_cuentas%rowtype;
  v_origen  public.fin_cuentas%rowtype;
  v_cuentas uuid[];
  v_mov     uuid;
  v_receptor boolean;
begin
  if v_yo is null then
    raise exception using errcode = '42501', message = 'Sin sesión.';
  end if;
  if p_accion is null or p_accion not in ('confirmar', 'rechazar') then
    raise exception using errcode = '22023', message = 'La acción es confirmar o rechazar.';
  end if;
  select * into v_t from public.fin_transferencias t where t.id = p_transferencia for update;
  if not found then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esa transferencia.';
  end if;
  -- El receptor: la persona destino o, si la casa recibe, otro miembro de su libro.
  v_receptor := v_yo <> v_t.persona_origen_id
                and public.fin_puede(v_t.libro_destino_id, 'escribir')
                and (v_t.persona_destino_id is null or v_t.persona_destino_id = v_yo);
  if not v_receptor then
    raise exception using errcode = '42501', message = 'Solo la confirma o la rechaza quien la recibe.';
  end if;
  if v_t.estado <> 'pendiente' then
    if (v_t.estado = 'confirmada' and p_accion = 'confirmar' and v_t.confirmada_por = v_yo) then
      return v_t.movimiento_id;
    elsif (v_t.estado = 'rechazada' and p_accion = 'rechazar') then
      return null;
    end if;
    raise exception using errcode = '55000', message = format('La transferencia ya está %s.', v_t.estado);
  end if;

  if p_accion = 'rechazar' then
    update public.fin_transferencias
       set estado = 'rechazada', respondida_por = v_yo, respondida_en = now()
     where id = v_t.id;
    return null;
  end if;

  -- Confirmar: cuenta que recibe.
  if p_cuenta_destino is null then
    select array_agg(c.id) into v_cuentas from public.fin_cuentas c
     where c.libro_id = v_t.libro_destino_id and c.liquida and c.estado = 'activa';
    if coalesce(cardinality(v_cuentas), 0) <> 1 then
      raise exception using errcode = '22023', message = 'Elige la cuenta que recibe el dinero.';
    end if;
    p_cuenta_destino := v_cuentas[1];
  end if;
  select * into v_cuenta from public.fin_cuentas c
   where c.id = p_cuenta_destino and c.libro_id = v_t.libro_destino_id;
  if not found or v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' then
    raise exception using errcode = '22023',
      message = 'La cuenta que recibe es una cuenta de dinero activa de ese libro.';
  end if;
  select * into v_origen from public.fin_cuentas c where c.id = v_t.cuenta_origen_id;
  if v_origen.estado <> 'activa' then
    raise exception using errcode = '55000', message = 'La cuenta de origen ya no está activa.';
  end if;

  v_mov := gen_random_uuid();
  update public.fin_transferencias
     set estado = 'confirmada', confirmada_por = v_yo, respondida_por = v_yo, respondida_en = now(),
         cuenta_destino_id = p_cuenta_destino, movimiento_id = v_mov
   where id = v_t.id;
  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
    cuenta_destino_id, monto_centavos, realizado_por, registrado_por, via, nota)
  values (v_mov, v_t.hogar_id, 'transferencia', v_t.fecha, now(), v_t.cuenta_origen_id, p_cuenta_destino,
          v_t.monto_centavos, v_t.persona_origen_id, v_yo, 'manual', coalesce(v_t.nota, 'Transferencia confirmada'));
  return v_mov;
end
$$;
comment on function public.fin_responder_transferencia(uuid, text, uuid) is
  'El receptor confirma (se registra el movimiento entre los dos libros) o rechaza (queda como registro, sin '
  'movimiento). p_cuenta_destino es opcional si el libro que recibe tiene una sola cuenta de dinero activa. '
  'Repetir la misma respuesta no duplica nada.';

-- 8.3 Cancelar (quien propuso, mientras siga pendiente). Queda como registro.
create function public.fin_cancelar_transferencia(p_transferencia uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo uuid := public.persona_actual();
  v_t  public.fin_transferencias%rowtype;
begin
  select * into v_t from public.fin_transferencias t where t.id = p_transferencia for update;
  if v_yo is null or not found or v_t.persona_origen_id <> v_yo then
    raise exception using errcode = '42501', message = 'Solo cancela quien la propuso.';
  end if;
  if v_t.estado = 'cancelada' then
    return;
  end if;
  if v_t.estado <> 'pendiente' then
    raise exception using errcode = '55000', message = format('La transferencia ya está %s.', v_t.estado);
  end if;
  update public.fin_transferencias
     set estado = 'cancelada', respondida_por = v_yo, respondida_en = now()
   where id = v_t.id;
end
$$;
comment on function public.fin_cancelar_transferencia(uuid) is
  'Quien propuso cancela una transferencia pendiente; queda como registro (no se borra).';

-- 8.4 Configurar la casa: libro general y periodo. Al crearla, deja las partes de
-- referencia por omisión (Papá 50 %; dueño y pareja, 25 % cada uno).
create function public.fin_casa_configurar(p_libro_casa uuid, p_periodo text default 'mes')
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo     uuid := public.persona_actual();
  v_libro  public.fin_libros%rowtype;
  v_actual uuid;
  v_papa   uuid;
  v_adultos uuid[];
  v_n      int;
  v_resto  int;
  v_parte  int;
  i        int;
begin
  select * into v_libro from public.fin_libros l where l.id = p_libro_casa;
  if v_yo is null or not found or not public.fin_puede(p_libro_casa, 'administrar') then
    raise exception using errcode = '42501', message = 'Sin permiso para configurar la casa.';
  end if;
  if v_libro.tipo <> 'compartido' then
    raise exception using errcode = '22023', message = 'La cuenta general de la casa es un libro compartido.';
  end if;
  perform p_periodo::public.fin_periodo_aportacion;
  v_actual := public.fin_casa_libro(v_libro.hogar_id);
  if v_actual is not null and v_actual <> p_libro_casa then
    raise exception using errcode = '22023', message = 'La casa del hogar ya tiene otro libro.';
  end if;
  insert into public.fin_casa_config (hogar_id, libro_id, periodo, actualizado_por, actualizado_en)
  values (v_libro.hogar_id, p_libro_casa, p_periodo, v_yo, now())
  on conflict (hogar_id) do update
    set periodo = excluded.periodo, actualizado_por = excluded.actualizado_por, actualizado_en = excluded.actualizado_en;

  if not exists (select 1 from public.fin_casa_referencias r where r.hogar_id = v_libro.hogar_id) then
    select l.titular_id into v_papa from public.fin_libros l
     where l.hogar_id = v_libro.hogar_id and l.tipo = 'representado' and l.activo
     order by l.creado_en, l.id limit 1;
    select coalesce(array_agg(l.titular_id order by (m.rol = 'dueno') desc, l.creado_en, l.id), '{}')
      into v_adultos
      from public.fin_libros l
      join public.membresias m on m.hogar_id = l.hogar_id and m.persona_id = l.titular_id
                              and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
     where l.hogar_id = v_libro.hogar_id and l.tipo = 'personal' and l.activo
       and m.rol in ('dueno', 'coadministrador');
    v_n := cardinality(v_adultos);
    v_resto := case when v_papa is null then 10000 else 5000 end;
    if v_papa is not null then
      insert into public.fin_casa_referencias (hogar_id, libro_id, persona_id, parte_pb)
      values (v_libro.hogar_id, p_libro_casa, v_papa, 5000);
    end if;
    for i in 1 .. v_n loop
      v_parte := v_resto / v_n + case when i = 1 then v_resto % v_n else 0 end;
      insert into public.fin_casa_referencias (hogar_id, libro_id, persona_id, parte_pb)
      values (v_libro.hogar_id, p_libro_casa, v_adultos[i], v_parte);
    end loop;
  end if;
end
$$;
comment on function public.fin_casa_configurar(uuid, text) is
  'Designa el libro compartido de la casa y el periodo de la aportación (semana, mes, bimestre, semestre, anual). '
  'Solo quien administra ese libro. La primera vez deja las partes de referencia por omisión.';

-- 8.5 Pagar un servicio de la casa y registrar quién aportó.
-- Origen: una cuenta del libro de la casa, de tu libro personal o del libro de Papá (albacea).
-- p_id es el id del movimiento (cola sin conexión: repetir la llamada no duplica nada).
-- Devuelve el id del aporte.
create function public.fin_casa_pagar_servicio(
  p_id uuid, p_subcuenta uuid, p_cuenta_origen uuid, p_monto_centavos bigint,
  p_fecha date default current_date, p_aportante uuid default null, p_nota text default null)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_yo      uuid := public.persona_actual();
  v_sub     public.fin_casa_subcuentas%rowtype;
  v_gasto   uuid;
  v_origen  public.fin_cuentas%rowtype;
  v_libro   public.fin_libros%rowtype;
  v_aporte  uuid;
  v_aportante uuid;
  v_papa    uuid;
  v_en_nombre uuid;
  v_motivo  text;
  v_suma    boolean;
begin
  if v_yo is null then
    raise exception using errcode = '42501', message = 'Sin sesión.';
  end if;
  select a.id into v_aporte from public.fin_casa_aportes a
   where a.movimiento_id = p_id and a.pagado_por = v_yo;
  if found then
    return v_aporte;
  end if;
  if p_id is null or p_monto_centavos is null or p_monto_centavos <= 0 then
    raise exception using errcode = '22023', message = 'El pago lleva identificador y un monto mayor a cero (centavos).';
  end if;
  select * into v_sub from public.fin_casa_subcuentas s where s.id = p_subcuenta;
  if not found or not public.fin_puede(v_sub.libro_id, 'leer') then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esa subcuenta.';
  end if;
  if not v_sub.activa then
    raise exception using errcode = '55000', message = 'La subcuenta está desactivada.';
  end if;
  select k.cuenta_gasto_id into v_gasto from public.fin_categorias k where k.id = v_sub.categoria_id;
  select * into v_origen from public.fin_cuentas c where c.id = p_cuenta_origen;
  if not found or v_origen.libro_id is null then
    raise exception using errcode = '42501', message = 'Sin permiso sobre esa cuenta.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = v_origen.libro_id;
  if v_libro.hogar_id <> v_sub.hogar_id or not public.fin_puede(v_libro.id, 'escribir') then
    raise exception using errcode = '42501', message = 'Sin permiso para pagar desde esa cuenta.';
  end if;

  if v_libro.id = v_sub.libro_id then
    -- Sale de la casa: el aportante es un miembro de la casa o Papá (si lo lleva quien paga).
    v_aportante := coalesce(p_aportante, v_yo);
    v_papa := (select l.titular_id from public.fin_libros l
               where l.hogar_id = v_sub.hogar_id and l.tipo = 'representado' and l.titular_id = v_aportante limit 1);
    if v_papa is not null then
      if not public.fin_puede((select l.id from public.fin_libros l
                               where l.hogar_id = v_sub.hogar_id and l.tipo = 'representado'
                                 and l.titular_id = v_papa), 'escribir') then
        raise exception using errcode = '42501',
          message = 'Lo de Papá lo registra su albacea (D19).';
      end if;
    elsif not exists (select 1 from public.fin_libro_miembros m
                      where m.libro_id = v_sub.libro_id and m.persona_id = v_aportante
                        and m.desde <= now() and (m.hasta is null or m.hasta > now())) then
      raise exception using errcode = '22023', message = 'El aportante es de la casa: un miembro de su libro o Papá.';
    end if;
    v_suma := false;
  elsif v_libro.tipo in ('personal', 'representado') then
    -- Sale del dinero de una persona: ella es quien aporta.
    v_aportante := v_libro.titular_id;
    if p_aportante is not null and p_aportante <> v_aportante then
      raise exception using errcode = '22023',
        message = 'Si pagas desde un libro personal, el aportante es su titular.';
    end if;
    if v_libro.tipo = 'representado' then
      v_en_nombre := v_libro.titular_id;
      v_motivo := 'Pago de un servicio de la casa';
    end if;
    v_suma := true;
  else
    raise exception using errcode = '22023', message = 'Paga desde la casa, tu libro personal o el de Papá.';
  end if;

  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id,
    cuenta_destino_id, monto_centavos, categoria_id, realizado_por, registrado_por, en_nombre_de,
    via, nota, motivo)
  values (p_id, v_sub.hogar_id, 'gasto', p_fecha, now(), p_cuenta_origen, v_gasto, p_monto_centavos,
          v_sub.categoria_id, v_yo, v_yo, v_en_nombre, 'manual', p_nota, v_motivo);
  insert into public.fin_casa_aportes (hogar_id, libro_id, subcuenta_id, movimiento_id, aportante_id,
    pagado_por, monto_centavos, fecha, suma_al_aportado)
  values (v_sub.hogar_id, v_sub.libro_id, v_sub.id, p_id, v_aportante, v_yo, p_monto_centavos, p_fecha, v_suma)
  returning id into v_aporte;
  return v_aporte;
end
$$;
comment on function public.fin_casa_pagar_servicio(uuid, uuid, uuid, bigint, date, uuid, text) is
  'Paga un servicio (subcuenta) de la casa con un movimiento de gasto y deja el APORTANTE (quien pone el dinero) '
  'además de quien lo paga. Desde la casa, el aportante es un miembro o Papá (su albacea); desde un libro '
  'personal o el de Papá, es el titular.';

-- 8.6 Aportación de referencia y aportado del periodo, por persona. Sin deudores:
-- no hay columna de faltante. vence_antes_de: la fecha límite más próxima.
create function public.fin_casa_aportacion(p_hogar_id uuid, p_fecha date default current_date)
returns table (persona_id uuid, parte_pb integer, referencia_centavos bigint, aportado_centavos bigint,
               desde date, hasta date, vence_antes_de date)
language plpgsql stable security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_casa    uuid := public.fin_casa_libro(p_hogar_id);
  v_periodo text;
  v_desde   date;
  v_hasta   date;
  v_meses   numeric;
  v_total   numeric;
  v_vence   date;
begin
  if v_casa is null or not public.fin_puede(v_casa, 'leer') then
    raise exception using errcode = '42501', message = 'Sin permiso para ver la casa.';
  end if;
  select c.periodo into v_periodo from public.fin_casa_config c where c.hogar_id = p_hogar_id;
  select r.desde, r.hasta into v_desde, v_hasta from public.fin_periodo_rango(v_periodo, p_fecha) r;
  v_meses := case v_periodo when 'semana' then 12.0 / 52 when 'mes' then 1 when 'bimestre' then 2
                            when 'semestre' then 6 else 12 end;
  select coalesce(sum(s.monto_estimado_centavos::numeric * v_meses / s.cada_meses), 0) into v_total
    from public.fin_casa_subcuentas s
   where s.libro_id = v_casa and s.activa and s.monto_estimado_centavos is not null;
  select min(s.proximo_vencimiento) into v_vence
    from public.fin_casa_subcuentas s
   where s.libro_id = v_casa and s.activa and s.proximo_vencimiento >= p_fecha;
  return query
  select r.persona_id, r.parte_pb,
         round(v_total * r.parte_pb / 10000)::bigint,
         (
           -- dinero que entró a la casa desde el libro de esa persona (transferencias no anuladas)
           coalesce((select sum(m.monto_centavos) from public.fin_movimientos m
                      join public.fin_libros lo on lo.id = m.libro_origen_id
                     where m.tipo = 'transferencia' and m.libro_destino_id = v_casa
                       and lo.titular_id = r.persona_id and lo.tipo in ('personal', 'representado')
                       and m.fecha between v_desde and v_hasta
                       and not exists (select 1 from public.fin_movimientos a where a.anula_a = m.id)), 0)
           -- servicios pagados directamente con su dinero
           + coalesce((select sum(a.monto_centavos) from public.fin_casa_aportes a
                        where a.libro_id = v_casa and a.aportante_id = r.persona_id and a.suma_al_aportado
                          and a.fecha between v_desde and v_hasta
                          and not exists (select 1 from public.fin_movimientos x where x.anula_a = a.movimiento_id)), 0)
         )::bigint,
         v_desde, v_hasta, v_vence
    from public.fin_casa_referencias r
   where r.hogar_id = p_hogar_id
   order by r.persona_id;
end
$$;
comment on function public.fin_casa_aportacion(uuid, date) is
  'Por persona, en el periodo configurado de la casa que contiene la fecha: parte de referencia, aportación '
  'de referencia (estimado de las subcuentas × periodo × parte) y lo aportado (transferencias a la casa no '
  'anuladas + servicios pagados con su dinero). Es una referencia: la aportación es libre y no hay deudores.';

-- -----------------------------------------------------------------------------
-- 9. Reglas por registro (RLS)
-- -----------------------------------------------------------------------------
alter table public.fin_transferencias enable row level security;
alter table public.fin_casa_config enable row level security;
alter table public.fin_casa_referencias enable row level security;
alter table public.fin_casa_ingresos enable row level security;
alter table public.fin_casa_subcuentas enable row level security;
alter table public.fin_casa_aportes enable row level security;

-- Transferencias: quien la propone, quien la recibe, la casa (sus miembros) y la cuenta maestra con su consulta.
create policy fin_transferencias_leer on public.fin_transferencias for select to authenticated
  using (persona_origen_id = (select public.persona_actual())
         or persona_destino_id = (select public.persona_actual())
         or public.fin_puede(libro_origen_id, 'leer')
         or public.fin_puede(libro_destino_id, 'leer'));

create policy fin_casa_config_leer on public.fin_casa_config for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));

create policy fin_casa_referencias_leer on public.fin_casa_referencias for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_casa_referencias_agregar on public.fin_casa_referencias for insert to authenticated
  with check (public.fin_puede(libro_id, 'administrar'));
create policy fin_casa_referencias_editar on public.fin_casa_referencias for update to authenticated
  using (public.fin_puede(libro_id, 'administrar'))
  with check (public.fin_puede(libro_id, 'administrar'));

-- Ingreso: el libro de la persona decide (ella; el albacea en el caso de Papá; la maestra solo lee).
create policy fin_casa_ingresos_leer on public.fin_casa_ingresos for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_casa_ingresos_agregar on public.fin_casa_ingresos for insert to authenticated
  with check (public.fin_puede(libro_id, 'escribir'));
create policy fin_casa_ingresos_editar on public.fin_casa_ingresos for update to authenticated
  using (public.fin_puede(libro_id, 'escribir'))
  with check (public.fin_puede(libro_id, 'escribir'));

create policy fin_casa_subcuentas_leer on public.fin_casa_subcuentas for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));
create policy fin_casa_subcuentas_agregar on public.fin_casa_subcuentas for insert to authenticated
  with check (public.fin_puede(libro_id, 'administrar'));
create policy fin_casa_subcuentas_editar on public.fin_casa_subcuentas for update to authenticated
  using (public.fin_puede(libro_id, 'administrar'))
  with check (public.fin_puede(libro_id, 'administrar'));

create policy fin_casa_aportes_leer on public.fin_casa_aportes for select to authenticated
  using (public.fin_puede(libro_id, 'leer'));

-- -----------------------------------------------------------------------------
-- 10. Privilegios explícitos
-- -----------------------------------------------------------------------------
revoke all on table
  public.fin_transferencias, public.fin_casa_config, public.fin_casa_referencias,
  public.fin_casa_ingresos, public.fin_casa_subcuentas, public.fin_casa_aportes
  from public, anon, authenticated, service_role;

grant select on
  public.fin_transferencias, public.fin_casa_config, public.fin_casa_referencias,
  public.fin_casa_ingresos, public.fin_casa_subcuentas, public.fin_casa_aportes
  to authenticated, service_role;

-- Lo que escribe la app directo (las llaves también, para upsert; los triggers las fijan).
grant insert (id, hogar_id, persona_id, parte_pb),
      update (id, hogar_id, persona_id, parte_pb)
  on public.fin_casa_referencias to authenticated;
grant insert (id, hogar_id, persona_id, ingreso_centavos, periodo),
      update (id, hogar_id, persona_id, ingreso_centavos, periodo)
  on public.fin_casa_ingresos to authenticated;
grant insert (id, hogar_id, libro_id, categoria_id, activa, dia_limite, cada_meses, proximo_vencimiento,
              monto_estimado_centavos),
      update (id, hogar_id, libro_id, categoria_id, activa, dia_limite, cada_meses, proximo_vencimiento,
              monto_estimado_centavos)
  on public.fin_casa_subcuentas to authenticated;
-- Transferencias, configuración y aportes: solo por las RPC (sin escritura directa).

revoke execute on function
  public.fin_rol_de(uuid, uuid), public.fin_casa_libro(uuid), public.fin_periodo_rango(text, date),
  public.fin_libro_de_persona(uuid, uuid),
  public.fin_transferencia_autoriza(uuid, text, uuid, uuid, bigint),
  public.fin_transferencias_proteger(), public.fin_casa_subcuentas_validar(),
  public.fin_casa_referencias_validar(), public.fin_casa_ingresos_validar(),
  public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text),
  public.fin_responder_transferencia(uuid, text, uuid), public.fin_cancelar_transferencia(uuid),
  public.fin_casa_configurar(uuid, text),
  public.fin_casa_pagar_servicio(uuid, uuid, uuid, bigint, date, uuid, text),
  public.fin_casa_aportacion(uuid, date)
  from public, anon, authenticated, service_role;

grant execute on function public.fin_periodo_rango(text, date) to authenticated, service_role;
grant execute on function
  public.fin_proponer_transferencia(uuid, uuid, uuid, bigint, date, text),
  public.fin_responder_transferencia(uuid, text, uuid), public.fin_cancelar_transferencia(uuid),
  public.fin_casa_configurar(uuid, text),
  public.fin_casa_pagar_servicio(uuid, uuid, uuid, bigint, date, uuid, text),
  public.fin_casa_aportacion(uuid, date)
  to authenticated;
