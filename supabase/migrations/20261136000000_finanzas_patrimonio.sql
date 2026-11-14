-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, bloque 3: objetivos, inversión, bienes y previsión
-- (docs/specs/fase-8-patrimonio.md v1.0)
-- =============================================================================
-- * Tablas nuevas: fin_objetivos, fin_inversiones, fin_bienes y fin_previsiones. Sin escritura directa: solo las RPC.
-- * El objetivo LEE el apartado de ahorro (fin_bolsas_ahorro, D28/Fase 2): guarda solo el vínculo (bolsa_id), nunca
--   una copia del saldo ni de las aportaciones. El avance se calcula al leerlo (fin_objetivo_avance).
-- * Reglas (D19): cada fila pertenece a una persona (su libro). La leen quienes pueden leer el libro (fin_puede 'leer':
--   la titular; la pareja, las de la casa; el dueño como albacea de Papá y el suplente igual que en la Fase 1; la
--   cuenta maestra solo con consulta vigente). Escribe quien administra el libro (la titular; el dueño como albacea).
--   Casa, la familiar y la cuidadora no ven nada.
-- * Dinero en centavos; rendimiento en puntos base, capturado: este bloque NO lo calcula.
-- * origen de una inversión: 'capturado' (a mano) o 'verificado' (leído del estado en PDF, en la laptop).
-- * Un dato sin fecha de captura no es vigente (vistas fin_v_*_vigentes).
-- * Bitácora sin montos ni rendimientos (D3). Nada de este bloque sale a la IA ni a las bocinas.
-- Migración hacia adelante. Sin secretos ni datos reales.
-- =============================================================================

-- 1. Tablas ------------------------------------------------------------------------------------------------------------
create table public.fin_objetivos (
  id                  uuid primary key default gen_random_uuid(),
  hogar_id            uuid not null references public.hogares (id),
  libro_id            uuid not null,
  titular_id          uuid not null references public.personas (id),
  nombre              text not null check (char_length(btrim(nombre)) between 1 and 60),
  monto_meta_centavos bigint not null check (monto_meta_centavos > 0),
  fecha_meta          date not null,
  bolsa_id            uuid,
  activo              boolean not null default true,
  creado_por          uuid not null default public.persona_actual() references public.personas (id),
  creado_en           timestamptz not null default now(),
  constraint fin_objetivos_libro_id_key unique (libro_id, id),
  constraint fin_objetivos_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_objetivos_bolsa_fk foreign key (libro_id, bolsa_id) references public.fin_bolsas_ahorro (libro_id, id)
);
-- Un apartado alimenta a un solo objetivo activo (si no, su saldo contaría doble).
create unique index fin_objetivos_bolsa_unica on public.fin_objetivos (bolsa_id) where activo and bolsa_id is not null;
comment on table public.fin_objetivos is
  'Meta de ahorro de una persona (su libro): monto y fecha. bolsa_id = el apartado de ahorro que la alimenta (se LEE, no '
  'se copia). Escritura solo por RPC (fin_objetivo_guardar); una baja es activo = false.';

create table public.fin_inversiones (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid not null,
  titular_id      uuid not null references public.personas (id),
  nombre          text not null check (char_length(btrim(nombre)) between 1 and 60),
  saldo_centavos  bigint not null check (saldo_centavos >= 0),
  rendimiento_pb  integer check (rendimiento_pb between -10000 and 100000),
  origen          text not null default 'capturado' check (origen in ('capturado', 'verificado')),
  fecha_captura   date,
  activa          boolean not null default true,
  creado_por      uuid not null default public.persona_actual() references public.personas (id),
  creado_en       timestamptz not null default now(),
  constraint fin_inversiones_libro_id_key unique (libro_id, id),
  constraint fin_inversiones_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_inversiones_verificado_fecha check (origen <> 'verificado' or fecha_captura is not null)
);
comment on table public.fin_inversiones is
  'Inversión de una persona. rendimiento_pb (puntos base) se muestra tal como se capturó; nulo = sin dato; este bloque no '
  'lo calcula. origen: capturado (a mano) o verificado (leído del estado en PDF). Sin fecha de captura no es vigente. '
  'Escritura solo por RPC.';

create table public.fin_bienes (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  titular_id     uuid not null references public.personas (id),
  nombre         text not null check (char_length(btrim(nombre)) between 1 and 60),
  valor_centavos bigint not null check (valor_centavos >= 0),
  tipo           text not null check (tipo in ('auto', 'casa', 'otro')),
  fecha_captura  date,
  activo         boolean not null default true,
  creado_por     uuid not null default public.persona_actual() references public.personas (id),
  creado_en      timestamptz not null default now(),
  constraint fin_bienes_libro_id_key unique (libro_id, id),
  constraint fin_bienes_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id)
);
comment on table public.fin_bienes is
  'Bien (auto, casa, otro) con su valor ingresado a mano y la fecha de captura. Sin fecha de captura no es vigente. '
  'Escritura solo por RPC.';

create table public.fin_previsiones (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  titular_id     uuid not null references public.personas (id),
  nombre         text not null check (char_length(btrim(nombre)) between 1 and 60),
  tipo           text not null check (tipo in ('seguro', 'pension', 'otro')),
  valor_centavos bigint not null check (valor_centavos >= 0),
  fecha_captura  date,
  activa         boolean not null default true,
  creado_por     uuid not null default public.persona_actual() references public.personas (id),
  creado_en      timestamptz not null default now(),
  constraint fin_previsiones_libro_id_key unique (libro_id, id),
  constraint fin_previsiones_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id)
);
comment on table public.fin_previsiones is
  'Previsión (seguro, pensión, otro) con su valor ingresado a mano y la fecha de captura. Sin fecha de captura no es '
  'vigente. Escritura solo por RPC.';

create index fin_objetivos_libro_idx on public.fin_objetivos (libro_id);
create index fin_inversiones_libro_idx on public.fin_inversiones (libro_id);
create index fin_bienes_libro_idx on public.fin_bienes (libro_id);
create index fin_previsiones_libro_idx on public.fin_previsiones (libro_id);

-- 2. Validaciones, sin borrados y bitácora sin cifras -----------------------------------------------------------------
-- La titular lleva el libro; la fecha de captura no es del futuro.
create function public.fin_patrimonio_validar()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_fecha date := (to_jsonb(new) ->> 'fecha_captura')::date;
begin
  select * into v_libro from public.fin_libros l where l.id = new.libro_id;
  if tg_op = 'INSERT' or new.titular_id is distinct from old.titular_id then
    if not (v_libro.titular_id = new.titular_id
            or exists (select 1 from public.fin_libro_miembros m
                        where m.libro_id = new.libro_id and m.persona_id = new.titular_id
                          and m.desde <= now() and (m.hasta is null or m.hasta > now()))) then
      raise exception using errcode = '22023', message = 'La titular debe llevar este libro.';
    end if;
  end if;
  if v_fecha is not null and v_fecha > current_date + 1 then
    raise exception using errcode = '22023', message = 'La fecha de captura no puede ser futura.';
  end if;
  return new;
end
$$;

create function public.fin_patrimonio_sin_borrar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '42501', message = 'Los objetivos, inversiones, bienes y previsiones no se borran: se dan de baja.';
end
$$;

do $$
declare
  v_tabla text;
begin
  foreach v_tabla in array array['fin_objetivos', 'fin_inversiones', 'fin_bienes', 'fin_previsiones'] loop
    execute format('create trigger fin_a_columnas_fijas before update on public.%I
      for each row execute function public.fin_columnas_fijas(''id'', ''hogar_id'', ''libro_id'', ''creado_por'', ''creado_en'')', v_tabla);
    execute format('create trigger fin_b_validar before insert or update on public.%I
      for each row execute function public.fin_patrimonio_validar()', v_tabla);
    execute format('create trigger fin_a_sin_borrar before delete on public.%I
      for each row execute function public.fin_patrimonio_sin_borrar()', v_tabla);
    execute format('alter table public.%I enable row level security', v_tabla);
    execute format('create policy %I on public.%I for select to authenticated using (public.fin_puede(libro_id, ''leer''))',
                   v_tabla || '_leer', v_tabla);
    execute format('revoke all on table public.%I from public, anon, authenticated, service_role', v_tabla);
    execute format('grant select on public.%I to authenticated, service_role', v_tabla);
  end loop;
end
$$;
-- Sin grant de escritura: solo las RPC.

-- Bitácora sin montos, saldos, valores ni rendimientos (D3).
create trigger fin_z_bitacora after insert or update or delete on public.fin_objetivos
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'monto_meta_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_inversiones
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'saldo_centavos', 'rendimiento_pb');
create trigger fin_z_bitacora after insert or update or delete on public.fin_bienes
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'valor_centavos');
create trigger fin_z_bitacora after insert or update or delete on public.fin_previsiones
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'valor_centavos');

-- 3. Vistas de lo vigente (con fecha de captura) -----------------------------------------------------------------------
create view public.fin_v_inversiones_vigentes with (security_invoker = true) as
  select * from public.fin_inversiones where activa and fecha_captura is not null;
create view public.fin_v_bienes_vigentes with (security_invoker = true) as
  select * from public.fin_bienes where activo and fecha_captura is not null;
create view public.fin_v_previsiones_vigentes with (security_invoker = true) as
  select * from public.fin_previsiones where activa and fecha_captura is not null;
comment on view public.fin_v_inversiones_vigentes is 'Inversiones activas con fecha de captura. Sin fecha no es vigente.';
comment on view public.fin_v_bienes_vigentes is 'Bienes activos con fecha de captura. Sin fecha no es vigente.';
comment on view public.fin_v_previsiones_vigentes is 'Previsiones activas con fecha de captura. Sin fecha no es vigente.';
revoke all on table public.fin_v_inversiones_vigentes, public.fin_v_bienes_vigentes, public.fin_v_previsiones_vigentes
  from public, anon, authenticated, service_role;
grant select on public.fin_v_inversiones_vigentes, public.fin_v_bienes_vigentes, public.fin_v_previsiones_vigentes
  to authenticated, service_role;

-- 4. RPC de escritura --------------------------------------------------------------------------------------------------
-- Quien administra el libro (la titular; el dueño como albacea de Papá) y libro no archivado.
create function public.fin_patrimonio_autoriza(p_libro uuid, p_id uuid)
returns public.fin_libros
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  if public.persona_actual() is null or p_libro is null or not public.fin_puede(p_libro, 'administrar') then
    raise exception using errcode = '42501', message = 'No puedes administrar el patrimonio de este libro.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = p_libro;
  if not v_libro.activo then
    raise exception using errcode = '42501', message = 'El libro está archivado.';
  end if;
  if p_id is null then
    raise exception using errcode = '22023', message = 'El id es obligatorio.';
  end if;
  return v_libro;
end
$$;

create function public.fin_objetivo_guardar(
  p_id uuid, p_libro uuid, p_titular uuid, p_nombre text, p_monto_meta_centavos bigint, p_fecha_meta date,
  p_bolsa uuid default null, p_activo boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_ex    public.fin_objetivos%rowtype;
begin
  v_libro := public.fin_patrimonio_autoriza(p_libro, p_id);
  select * into v_ex from public.fin_objetivos o where o.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro then
      raise exception using errcode = '23505', message = 'Ese id ya es de otro objetivo.';
    end if;
    update public.fin_objetivos o
       set titular_id = p_titular, nombre = btrim(p_nombre), monto_meta_centavos = p_monto_meta_centavos,
           fecha_meta = p_fecha_meta, bolsa_id = p_bolsa, activo = coalesce(p_activo, true)
     where o.id = p_id;
  else
    insert into public.fin_objetivos (id, hogar_id, libro_id, titular_id, nombre, monto_meta_centavos, fecha_meta,
                                      bolsa_id, activo)
    values (p_id, v_libro.hogar_id, p_libro, p_titular, btrim(p_nombre), p_monto_meta_centavos, p_fecha_meta,
            p_bolsa, coalesce(p_activo, true));
  end if;
  return p_id;
end
$$;
comment on function public.fin_objetivo_guardar(uuid, uuid, uuid, text, bigint, date, uuid, boolean) is
  'Crea o actualiza (idempotente por id) un objetivo de ahorro. p_bolsa = apartado de ahorro del mismo libro que lo '
  'alimenta (se lee, no se copia). Solo quien administra el libro. Una baja es p_activo = false.';

create function public.fin_inversion_guardar(
  p_id uuid, p_libro uuid, p_titular uuid, p_nombre text, p_saldo_centavos bigint, p_rendimiento_pb integer,
  p_origen text default 'capturado', p_fecha_captura date default null, p_activa boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_ex    public.fin_inversiones%rowtype;
begin
  v_libro := public.fin_patrimonio_autoriza(p_libro, p_id);
  select * into v_ex from public.fin_inversiones i where i.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro then
      raise exception using errcode = '23505', message = 'Ese id ya es de otra inversión.';
    end if;
    update public.fin_inversiones i
       set titular_id = p_titular, nombre = btrim(p_nombre), saldo_centavos = p_saldo_centavos,
           rendimiento_pb = p_rendimiento_pb, origen = coalesce(p_origen, 'capturado'),
           fecha_captura = p_fecha_captura, activa = coalesce(p_activa, true)
     where i.id = p_id;
  else
    insert into public.fin_inversiones (id, hogar_id, libro_id, titular_id, nombre, saldo_centavos, rendimiento_pb,
                                        origen, fecha_captura, activa)
    values (p_id, v_libro.hogar_id, p_libro, p_titular, btrim(p_nombre), p_saldo_centavos, p_rendimiento_pb,
            coalesce(p_origen, 'capturado'), p_fecha_captura, coalesce(p_activa, true));
  end if;
  return p_id;
end
$$;
comment on function public.fin_inversion_guardar(uuid, uuid, uuid, text, bigint, integer, text, date, boolean) is
  'Crea o actualiza (idempotente por id) una inversión. p_rendimiento_pb en puntos base, tal como lo capturó la persona '
  '(nulo = sin dato; no se calcula). p_origen: capturado o verificado (leído del PDF; exige fecha de captura). Solo '
  'quien administra el libro. Una baja es p_activa = false.';

create function public.fin_bien_guardar(
  p_id uuid, p_libro uuid, p_titular uuid, p_nombre text, p_tipo text, p_valor_centavos bigint,
  p_fecha_captura date default null, p_activo boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_ex    public.fin_bienes%rowtype;
begin
  v_libro := public.fin_patrimonio_autoriza(p_libro, p_id);
  select * into v_ex from public.fin_bienes b where b.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro then
      raise exception using errcode = '23505', message = 'Ese id ya es de otro bien.';
    end if;
    update public.fin_bienes b
       set titular_id = p_titular, nombre = btrim(p_nombre), tipo = p_tipo, valor_centavos = p_valor_centavos,
           fecha_captura = p_fecha_captura, activo = coalesce(p_activo, true)
     where b.id = p_id;
  else
    insert into public.fin_bienes (id, hogar_id, libro_id, titular_id, nombre, tipo, valor_centavos, fecha_captura, activo)
    values (p_id, v_libro.hogar_id, p_libro, p_titular, btrim(p_nombre), p_tipo, p_valor_centavos, p_fecha_captura,
            coalesce(p_activo, true));
  end if;
  return p_id;
end
$$;
comment on function public.fin_bien_guardar(uuid, uuid, uuid, text, text, bigint, date, boolean) is
  'Crea o actualiza (idempotente por id) un bien (auto, casa, otro) con su valor y fecha de captura. Sin fecha de '
  'captura no es vigente. Solo quien administra el libro. Una baja es p_activo = false.';

create function public.fin_prevision_guardar(
  p_id uuid, p_libro uuid, p_titular uuid, p_nombre text, p_tipo text, p_valor_centavos bigint,
  p_fecha_captura date default null, p_activa boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_ex    public.fin_previsiones%rowtype;
begin
  v_libro := public.fin_patrimonio_autoriza(p_libro, p_id);
  select * into v_ex from public.fin_previsiones p where p.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro then
      raise exception using errcode = '23505', message = 'Ese id ya es de otra previsión.';
    end if;
    update public.fin_previsiones p
       set titular_id = p_titular, nombre = btrim(p_nombre), tipo = p_tipo, valor_centavos = p_valor_centavos,
           fecha_captura = p_fecha_captura, activa = coalesce(p_activa, true)
     where p.id = p_id;
  else
    insert into public.fin_previsiones (id, hogar_id, libro_id, titular_id, nombre, tipo, valor_centavos, fecha_captura, activa)
    values (p_id, v_libro.hogar_id, p_libro, p_titular, btrim(p_nombre), p_tipo, p_valor_centavos, p_fecha_captura,
            coalesce(p_activa, true));
  end if;
  return p_id;
end
$$;
comment on function public.fin_prevision_guardar(uuid, uuid, uuid, text, text, bigint, date, boolean) is
  'Crea o actualiza (idempotente por id) una previsión (seguro, pensión, otro) con su valor y fecha de captura. Sin '
  'fecha de captura no es vigente. Solo quien administra el libro. Una baja es p_activa = false.';

-- 5. Avance de un objetivo (lectura del apartado, sin copiarlo) --------------------------------------------------------
-- ahorrado = saldo actual del apartado (su cuenta en el libro). Ritmo semanal = aporte_fijo del apartado si lo tiene;
-- si no, el promedio de sus últimas 8 aportaciones confirmadas. Sin ritmo: falta_dato (no se inventa).
-- estado: ok | cumplido | sin_apartado | falta_dato.
create function public.fin_objetivo_avance(p_objetivo uuid, p_hoy date default current_date)
returns table (
  objetivo_id uuid, estado text, monto_meta_centavos bigint, ahorrado_centavos bigint, falta_centavos bigint,
  aporte_semanal_centavos bigint, ritmo_origen text, semanas_estimadas integer, fecha_estimada date,
  fecha_meta date, a_tiempo boolean, aporte_necesario_semanal_centavos bigint)
language plpgsql stable security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_o       public.fin_objetivos%rowtype;
  v_ahorro  bigint := 0;
  v_falta   bigint;
  v_aporte  bigint;
  v_origen  text;
  v_semanas integer;
  v_estado  text;
  v_fecha   date;
  v_necesario bigint;
  v_sem_meta integer;
begin
  select * into v_o from public.fin_objetivos o where o.id = p_objetivo;
  if not found or public.persona_actual() is null or not public.fin_puede(v_o.libro_id, 'leer') then
    raise exception using errcode = '42501', message = 'No puedes ver este objetivo.';
  end if;
  if v_o.bolsa_id is not null then
    select greatest(coalesce(s.saldo_centavos, 0), 0)::bigint into v_ahorro
      from public.fin_v_bolsa_saldo s where s.bolsa_id = v_o.bolsa_id and s.libro_id = v_o.libro_id;
    v_ahorro := coalesce(v_ahorro, 0);
    select b.aporte_fijo_centavos into v_aporte from public.fin_bolsas_ahorro b where b.id = v_o.bolsa_id;
    if v_aporte is not null and v_aporte > 0 then
      v_origen := 'aporte_fijo';
    else
      select (sum(x.aportado_centavos) / count(*))::bigint into v_aporte
        from (select a.aportado_centavos
                from public.fin_aportaciones_ahorro a
                join public.fin_semanas s on s.libro_id = a.libro_id and s.id = a.semana_id
               where a.bolsa_id = v_o.bolsa_id and a.estado = 'confirmada'
               order by s.semana_inicio desc limit 8) x;
      if v_aporte is not null and v_aporte > 0 then
        v_origen := 'promedio';
      else
        v_aporte := null;
      end if;
    end if;
  end if;
  v_falta := greatest(v_o.monto_meta_centavos - v_ahorro, 0);
  if v_falta = 0 then
    v_estado := 'cumplido';
    v_semanas := 0;
  elsif v_o.bolsa_id is null then
    v_estado := 'sin_apartado';
  elsif v_aporte is null then
    v_estado := 'falta_dato';
  else
    v_estado := 'ok';
    v_semanas := ((v_falta + v_aporte - 1) / v_aporte)::integer;
  end if;
  if v_semanas is not null then
    v_fecha := p_hoy + v_semanas * 7;
  end if;
  if v_falta > 0 then
    v_sem_meta := greatest(((v_o.fecha_meta - p_hoy) + 6) / 7, 1);
    v_necesario := (v_falta + v_sem_meta - 1) / v_sem_meta;
  else
    v_necesario := 0;
  end if;
  return query select v_o.id, v_estado, v_o.monto_meta_centavos, v_ahorro, v_falta, v_aporte, v_origen, v_semanas,
                      v_fecha, v_o.fecha_meta, case when v_fecha is null then null else v_fecha <= v_o.fecha_meta end,
                      v_necesario;
end
$$;
comment on function public.fin_objetivo_avance(uuid, date) is
  'Fase 8 bloque 3. Cuánto falta y en cuántas semanas se alcanza con el apartado de ahorro (se lee su saldo y su ritmo; '
  'nada se copia). Ritmo = aporte fijo del apartado o el promedio de sus últimas 8 aportaciones confirmadas. Estados: '
  'ok, cumplido, sin_apartado (el objetivo no tiene apartado) y falta_dato (el apartado no tiene ritmo conocido; no se '
  'estima). aporte_necesario_semanal = lo que haría falta cada semana para llegar a la fecha meta. Lo lee quien puede '
  'leer el libro (fin_puede leer: titular, pareja en la casa, albacea y suplente de Papá, maestra con consulta vigente).';

-- 6. Permisos de las funciones -----------------------------------------------------------------------------------------
revoke execute on function
  public.fin_patrimonio_autoriza(uuid, uuid), public.fin_patrimonio_validar(), public.fin_patrimonio_sin_borrar(),
  public.fin_objetivo_guardar(uuid, uuid, uuid, text, bigint, date, uuid, boolean),
  public.fin_inversion_guardar(uuid, uuid, uuid, text, bigint, integer, text, date, boolean),
  public.fin_bien_guardar(uuid, uuid, uuid, text, text, bigint, date, boolean),
  public.fin_prevision_guardar(uuid, uuid, uuid, text, text, bigint, date, boolean),
  public.fin_objetivo_avance(uuid, date)
  from public, anon, authenticated, service_role;
grant execute on function
  public.fin_objetivo_guardar(uuid, uuid, uuid, text, bigint, date, uuid, boolean),
  public.fin_inversion_guardar(uuid, uuid, uuid, text, bigint, integer, text, date, boolean),
  public.fin_bien_guardar(uuid, uuid, uuid, text, text, bigint, date, boolean),
  public.fin_prevision_guardar(uuid, uuid, uuid, text, text, bigint, date, boolean),
  public.fin_objetivo_avance(uuid, date)
  to authenticated;
