-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, paquete F8-6.5: dispersión de ingresos con confirmación
-- (docs/specs/fase-8-finanzas-dispersion.md, sección «Modelo de datos propuesto»; D3, D5, D6, D19, D20, D24)
-- =============================================================================
-- Qué hace (la PROPUESTA se calcula en el dispositivo con el dominio puro; el servidor guarda lo que la persona decide,
-- liga los movimientos y protege quién lo ve: ningún monto sale a IA ni a bocinas, D3 y D6):
--
-- 1. Cuatro columnas en fin_parametros (solo por RPC): dispersion_modo, dispersion_desde, dispersion_parte_libre_pb y
--    dispersion_tope_ahorro.
-- 2. Dos tablas nuevas, con escritura únicamente por RPC security definer:
--      fin_dispersiones        el reparto de UN ingreso. Un único reparto vigente por movimiento (índice único parcial).
--                              Su estado cambia solo por transiciones controladas (propuesta -> confirmada, automatica o
--                              anulada; confirmada o automatica -> anulada); nada se borra.
--      fin_dispersion_lineas   los renglones (presupuesto, pago_deuda, abono_extra, ahorro, libre, por_repartir). Son
--                              inmutables; solo los de una PROPUESTA (un borrador, no un asiento) se reemplazan al guardarla
--                              otra vez. La suma de los renglones es siempre el monto del ingreso (disparador diferido).
--    El libro de movimientos sigue siendo solo-agregar: confirmar un reparto agrega movimientos de abono extra y de ahorro y
--    nada más (decisión P4: el renglón de pagos de deuda solo aparta; el pago real se registra con «Registrar pago»).
-- 3. RPC: fin_guardar_propuesta, fin_confirmar_dispersion (idempotente por id), fin_deshacer_dispersion,
--    fin_corregir_tipo_ingreso (anulación + ingreso nuevo con el mismo grupo y motivo; rechaza si ya está repartido),
--    fin_dispersion_parametros_cambiar y fin_ingresos_por_repartir (lectura).
-- 4. Disparador: si el ingreso se anula, su reparto pasa a «anulada». Los movimientos que ese reparto creó NO se anulan solos:
--    queda una entrada en la bitácora (finanzas.dispersion_anulada) con cuántos siguen vigentes.
-- 5. Permisos (D5, D19, D24): leer con fin_dispersion_puede_ver (fin_puede leer y rol dueño o coadministrador; la cuenta
--    maestra lee con consulta vigente y NUNCA escribe); escribir con fin_puede(libro, 'escribir') y esa misma lectura;
--    parámetros: 'administrar'. Familiar (también con la vista temporal de Papá), cuidador, Casa y la tablet pública no leen ni
--    escriben nada. En el libro de Papá todo queda «en nombre de» él y con motivo.
-- 6. Avisos (D20): un tipo nuevo en el catálogo cerrado, ingreso_por_repartir («Tienes un ingreso por repartir»), sin cifras,
--    nombres ni montos. Extiende el catálogo, la severidad, los tipos emitibles, fin_emitir_aviso y las preferencias.
-- Dinero en bigint de centavos; porcentajes en puntos base. Migración hacia adelante. Sin secretos ni datos reales.
-- =============================================================================

-- 1. Parámetros por libro ------------------------------------------------------------------------------------------
-- Una sentencia por columna (así la prueba de contrato de la app las ve todas). Sin GRANT: solo las cambia
-- fin_dispersion_parametros_cambiar (administrar) y la app no las escribe directo.
alter table public.fin_parametros
  add column dispersion_modo text not null default 'confirmacion'
    check (dispersion_modo in ('confirmacion', 'automatico'));
alter table public.fin_parametros
  add column dispersion_desde date
    check (dispersion_desde is null or extract(isodow from dispersion_desde) = 1);
alter table public.fin_parametros
  add column dispersion_parte_libre_pb integer not null default 0
    check (dispersion_parte_libre_pb between 0 and 10000);
alter table public.fin_parametros
  add column dispersion_tope_ahorro bigint
    check (dispersion_tope_ahorro is null or dispersion_tope_ahorro > 0);
comment on column public.fin_parametros.dispersion_modo is
  'confirmacion (por omisión: la persona valida cada reparto) o automatico (asigna solo lo comprometido; nunca mueve dinero). '
  'Solo por fin_dispersion_parametros_cambiar.';
comment on column public.fin_parametros.dispersion_desde is
  'Lunes desde el que los ingresos piden reparto; lo anterior se da por repartido. Nulo = función sin activar: la app usa el '
  'lunes de la semana anterior (P2) y fin_dispersion_parametros_cambiar lo fija al activarla.';
comment on column public.fin_parametros.dispersion_parte_libre_pb is
  'Parte libre de un ingreso extra, en puntos base del remanente (0 por omisión, 5.1 bis punto 4).';
comment on column public.fin_parametros.dispersion_tope_ahorro is
  'Tope del ahorro de un ingreso, en centavos (la meta); lo que lo pasa queda libre. Nulo = sin tope.';

-- 2. Tablas nuevas -------------------------------------------------------------------------------------------------
create table public.fin_dispersiones (
  id             uuid primary key default gen_random_uuid(),
  hogar_id       uuid not null references public.hogares (id),
  libro_id       uuid not null,
  movimiento_id  uuid not null,
  estado         text not null check (estado in ('por_repartir', 'propuesta', 'confirmada', 'automatica', 'anulada')),
  modo           text not null default 'confirmacion' check (modo in ('confirmacion', 'automatico')),
  creada_por     uuid not null default public.persona_actual() references public.personas (id),
  creada_en      timestamptz not null default now(),
  resuelta_por   uuid references public.personas (id),
  resuelta_en    timestamptz,
  en_nombre_de   uuid references public.personas (id),
  motivo         text check (char_length(motivo) <= 200),
  constraint fin_dispersiones_libro_id_key unique (libro_id, id),
  constraint fin_dispersiones_libro_fk foreign key (hogar_id, libro_id) references public.fin_libros (hogar_id, id),
  constraint fin_dispersiones_movimiento_fk foreign key (hogar_id, movimiento_id)
    references public.fin_movimientos (hogar_id, id),
  constraint fin_dispersiones_confirmada check (estado <> 'confirmada' or (modo = 'confirmacion' and resuelta_por is not null
                                                                          and resuelta_en is not null)),
  constraint fin_dispersiones_automatica check (estado <> 'automatica' or modo = 'automatico'),
  constraint fin_dispersiones_en_nombre_de_con_motivo check (en_nombre_de is null or nullif(btrim(motivo), '') is not null)
);
-- Un único reparto vigente por movimiento: solo las anuladas pueden repetirse.
create unique index fin_dispersiones_una_vigente on public.fin_dispersiones (movimiento_id) where estado <> 'anulada';
create index fin_dispersiones_libro_idx on public.fin_dispersiones (libro_id, creada_en desc);
comment on table public.fin_dispersiones is
  'Reparto de un ingreso (cascada: presupuesto, deuda, remanente). UN reparto vigente por movimiento. Sin DELETE; el estado '
  'solo cambia por transiciones (propuesta a confirmada, automatica o anulada; confirmada o automatica a anulada) hechas por '
  'las RPC y por el disparador que anula el reparto cuando se anula el ingreso. Escritura solo por RPC.';

create table public.fin_dispersion_lineas (
  id              uuid primary key default gen_random_uuid(),
  hogar_id        uuid not null references public.hogares (id),
  libro_id        uuid not null,
  dispersion_id   uuid not null,
  orden           smallint not null check (orden >= 0),
  destino         text not null check (destino in ('presupuesto', 'pago_deuda', 'abono_extra', 'ahorro', 'libre', 'por_repartir')),
  referencia_id   uuid,
  etiqueta        text not null check (char_length(btrim(etiqueta)) between 1 and 80),
  monto_centavos  bigint not null check (monto_centavos >= 0),
  movimiento_id   uuid,
  constraint fin_dispersion_lineas_dispersion_fk foreign key (libro_id, dispersion_id)
    references public.fin_dispersiones (libro_id, id),
  constraint fin_dispersion_lineas_movimiento_fk foreign key (hogar_id, movimiento_id)
    references public.fin_movimientos (hogar_id, id),
  -- Solo el abono extra y el ahorro mueven dinero (P4: los pagos de deuda solo apartan).
  constraint fin_dispersion_lineas_movimiento_solo_si_mueve check (movimiento_id is null or destino in ('abono_extra', 'ahorro')),
  -- Pago de deuda y abono extra apuntan a su deuda; ahorro, libre y por repartir no apuntan a nada.
  constraint fin_dispersion_lineas_referencia check (
    case destino
      when 'pago_deuda' then referencia_id is not null
      when 'abono_extra' then referencia_id is not null
      when 'ahorro' then referencia_id is null
      when 'libre' then referencia_id is null
      when 'por_repartir' then referencia_id is null
      else true end)
);
-- Un renglón por destino y referencia dentro de un reparto (así un abono extra o un ahorro tiene un solo movimiento).
create unique index fin_dispersion_lineas_unica on public.fin_dispersion_lineas
  (dispersion_id, destino, coalesce(referencia_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index fin_dispersion_lineas_dispersion_idx on public.fin_dispersion_lineas (dispersion_id, orden);
create index fin_dispersion_lineas_movimiento_idx on public.fin_dispersion_lineas (movimiento_id) where movimiento_id is not null;
comment on table public.fin_dispersion_lineas is
  'Renglones de un reparto. Inmutables (sin UPDATE); solo los de una propuesta (borrador) se reemplazan al guardarla de nuevo. '
  'Su suma es el monto del ingreso. movimiento_id es el abono extra o el ahorro que creó el servidor al confirmar. '
  'etiqueta es un dato del libro: jamás sale en un aviso (D3, D20). Escritura solo por RPC.';

-- 3. Validaciones y solo-agregar -------------------------------------------------------------------------------------
-- 3.1 El reparto solo cambia de estado; nada se borra.
create function public.fin_dispersiones_proteger()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '42501', message = 'Un reparto no se borra: se anula y queda como registro.';
  end if;
  if new.id <> old.id or new.hogar_id <> old.hogar_id or new.libro_id <> old.libro_id
     or new.movimiento_id <> old.movimiento_id or new.creada_por <> old.creada_por or new.creada_en <> old.creada_en then
    raise exception using errcode = '42501', message = 'Un reparto solo cambia de estado.';
  end if;
  if old.estado = 'anulada' then
    raise exception using errcode = '55000', message = 'Un reparto anulado ya no cambia.';
  end if;
  if old.estado in ('confirmada', 'automatica') then
    if new.estado <> 'anulada' or (to_jsonb(old) - 'estado') is distinct from (to_jsonb(new) - 'estado') then
      raise exception using errcode = '55000', message = 'Un reparto confirmado solo se anula (deshacer).';
    end if;
  end if;
  return new;
end
$$;
create trigger fin_a_proteger before update or delete on public.fin_dispersiones
  for each row execute function public.fin_dispersiones_proteger();
create trigger fin_sin_truncate before truncate on public.fin_dispersiones
  for each statement execute function public.impedir_cambios_solo_agregar();

-- 3.2 Los renglones no se editan; solo los de una propuesta se agregan o se reemplazan.
create function public.fin_dispersion_lineas_proteger()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_estado text;
begin
  if tg_op = 'UPDATE' then
    raise exception using errcode = '42501', message = 'Un renglón de reparto no se edita.';
  end if;
  select d.estado into v_estado from public.fin_dispersiones d
   where d.id = case tg_op when 'DELETE' then old.dispersion_id else new.dispersion_id end;
  if v_estado is distinct from 'propuesta' then
    raise exception using errcode = '55000',
      message = 'Los renglones solo se agregan o se reemplazan mientras el reparto es una propuesta.';
  end if;
  return case tg_op when 'DELETE' then old else new end;
end
$$;
create trigger fin_a_proteger before insert or update or delete on public.fin_dispersion_lineas
  for each row execute function public.fin_dispersion_lineas_proteger();
create trigger fin_sin_truncate before truncate on public.fin_dispersion_lineas
  for each statement execute function public.impedir_cambios_solo_agregar();

-- 3.3 La suma de los renglones es el monto del ingreso (diferido: al terminar la transacción, con todos los renglones).
create function public.fin_dispersion_cuadra()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id    uuid;
  v_d     public.fin_dispersiones%rowtype;
  v_monto bigint;
  v_suma  bigint;
begin
  if tg_table_name = 'fin_dispersiones' then
    v_id := new.id;
  else
    v_id := case tg_op when 'DELETE' then old.dispersion_id else new.dispersion_id end;
  end if;
  select * into v_d from public.fin_dispersiones d where d.id = v_id;
  if not found or v_d.estado = 'anulada' then
    return null;
  end if;
  select m.monto_centavos into v_monto from public.fin_movimientos m where m.id = v_d.movimiento_id;
  select coalesce(sum(l.monto_centavos), 0) into v_suma from public.fin_dispersion_lineas l where l.dispersion_id = v_id;
  if v_suma <> v_monto then
    raise exception using errcode = '23514',
      message = format('Los renglones del reparto suman %s y el ingreso es de %s centavos.', v_suma, v_monto);
  end if;
  return null;
end
$$;
create constraint trigger fin_dispersion_cuadra_d after insert or update on public.fin_dispersiones
  deferrable initially deferred for each row execute function public.fin_dispersion_cuadra();
create constraint trigger fin_dispersion_cuadra_l after insert or delete on public.fin_dispersion_lineas
  deferrable initially deferred for each row execute function public.fin_dispersion_cuadra();

-- 3.4 Bitácora (la de los renglones sin la etiqueta: es un dato del libro, no de auditoría).
create trigger fin_z_bitacora after insert or update or delete on public.fin_dispersiones
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id');
create trigger fin_z_bitacora after insert or update or delete on public.fin_dispersion_lineas
  for each row execute function public.registrar_cambio_en_bitacora('hogar_id', 'etiqueta');

-- 3.5 Si el ingreso se anula, su reparto pasa a «anulada». Los movimientos que el reparto creó siguen siendo reales: no se
-- anulan solos y queda un aviso en la bitácora (sin cifras) con cuántos siguen vigentes.
create function public.fin_dispersion_al_anular_ingreso()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d      public.fin_dispersiones%rowtype;
  v_vivos  integer;
begin
  if new.tipo <> 'anulacion' or new.estado_inicial <> 'confirmado' then
    return null;
  end if;
  for v_d in
    select d.* from public.fin_dispersiones d where d.movimiento_id = new.anula_a and d.estado <> 'anulada'
  loop
    select count(*)::integer into v_vivos
      from public.fin_dispersion_lineas l
     where l.dispersion_id = v_d.id and l.movimiento_id is not null
       and not exists (select 1 from public.fin_movimientos a where a.anula_a = l.movimiento_id);
    update public.fin_dispersiones set estado = 'anulada' where id = v_d.id;
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (v_d.hogar_id, public.persona_actual(), 'finanzas.dispersion_anulada', 'fin_dispersiones', v_d.id::text,
            jsonb_build_object('libro_id', v_d.libro_id, 'movimiento_id', v_d.movimiento_id,
                               'estado_anterior', v_d.estado, 'movimientos_vigentes', v_vivos));
  end loop;
  return null;
end
$$;
-- fin_y_*: después de fin_a_validar y de los fin_b_ y fin_c_ del libro; antes de la bitácora (fin_z_).
create trigger fin_y_dispersion_anulada after insert on public.fin_movimientos
  for each row execute function public.fin_dispersion_al_anular_ingreso();

-- 4. RLS y privilegios: solo lectura con fin_dispersion_puede_ver; nada de escritura directa -------------------------------
-- Quién ve el reparto: miembro vigente del libro (fin_puede leer: el albacea y el suplente en el de Papá; la cuenta maestra con
-- consulta vigente; el lector de un compartido público) con rol dueño o coadministrador. Excluye al familiar (también con la vista
-- temporal de Papá, D24), al cuidador y a Casa.
create function public.fin_dispersion_puede_ver(p_libro uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.fin_puede(p_libro, 'leer') and public.rol_en_hogar(l.hogar_id) in ('dueno', 'coadministrador'), false)
    from public.fin_libros l where l.id = p_libro
$$;
comment on function public.fin_dispersion_puede_ver(uuid) is
  'D5, D19, D24. fin_puede(libro, leer) con rol dueño o coadministrador: el familiar con vista temporal de Papá, el cuidador y '
  'Casa no ven repartos. La cuenta maestra lee solo con consulta vigente (lo decide fin_puede).';

create policy fin_dispersiones_leer on public.fin_dispersiones for select to authenticated
  using (public.fin_dispersion_puede_ver(libro_id));
create policy fin_dispersion_lineas_leer on public.fin_dispersion_lineas for select to authenticated
  using (public.fin_dispersion_puede_ver(libro_id));
alter table public.fin_dispersiones enable row level security;
alter table public.fin_dispersion_lineas enable row level security;

create view public.fin_v_dispersiones_vigentes with (security_invoker = true) as
select d.* from public.fin_dispersiones d where d.estado <> 'anulada';
comment on view public.fin_v_dispersiones_vigentes is 'El reparto vigente de cada ingreso (todas las que no están anuladas).';

revoke all on table public.fin_dispersiones, public.fin_dispersion_lineas, public.fin_v_dispersiones_vigentes
  from public, anon, authenticated, service_role;
grant select on public.fin_dispersiones, public.fin_dispersion_lineas, public.fin_v_dispersiones_vigentes
  to authenticated, service_role;
-- Sin grant de escritura: solo las RPC.

-- 5. Ayudantes internos --------------------------------------------------------------------------------------------
-- Permiso en el libro Y poder verlo. El suplente de Papá escribe solo sin albacea vigente; la cuenta maestra nunca escribe.
create function public.fin_dispersion_exigir(p_libro uuid, p_accion text)
returns public.fin_libros
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
begin
  if public.persona_actual() is null or p_libro is null
     or not public.fin_puede(p_libro, p_accion) or not public.fin_dispersion_puede_ver(p_libro) then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  select * into v_libro from public.fin_libros l where l.id = p_libro;
  return v_libro;
end
$$;
comment on function public.fin_dispersion_exigir(uuid, text) is 'Interna. fin_puede en el libro y fin_dispersion_puede_ver; si no, 42501.';

-- El reparto con sus renglones, como lo devuelven las RPC.
create function public.fin_dispersion_json(p_id uuid)
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'id', d.id, 'libro_id', d.libro_id, 'movimiento_id', d.movimiento_id, 'estado', d.estado, 'modo', d.modo,
           'creada_en', d.creada_en, 'resuelta_por', d.resuelta_por, 'resuelta_en', d.resuelta_en,
           'en_nombre_de', d.en_nombre_de, 'motivo', d.motivo,
           'lineas', coalesce((select jsonb_agg(jsonb_build_object(
                         'destino', l.destino, 'referencia_id', l.referencia_id, 'etiqueta', l.etiqueta,
                         'monto_centavos', l.monto_centavos, 'movimiento_id', l.movimiento_id) order by l.orden)
                       from public.fin_dispersion_lineas l where l.dispersion_id = d.id), '[]'::jsonb))
    from public.fin_dispersiones d where d.id = p_id
$$;

-- Lunes de la semana anterior a hoy: el «desde» por omisión (P2).
create function public.fin_dispersion_desde_por_omision()
returns date
language sql stable security definer
set search_path = ''
as $$ select public.fin_fugas_lunes(public.fin_fugas_hoy()) - 7 $$;

-- Un ingreso vigente: de tipo ingreso, confirmado, que entra a una cuenta del libro y sin anulación.
create function public.fin_dispersion_ingreso(p_movimiento uuid)
returns public.fin_movimientos
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_m public.fin_movimientos%rowtype;
begin
  select * into v_m from public.fin_movimientos m where m.id = p_movimiento;
  if not found or v_m.tipo <> 'ingreso' or v_m.libro_destino_id is null then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  return v_m;
end
$$;

-- 6. RPC de escritura ----------------------------------------------------------------------------------------------
-- 6.1 Guardar (propuesta) o confirmar un reparto: el trabajo es el mismo; cambia el estado final y si se crean movimientos.
-- Payload (jsonb): id, movimiento_id, modo ('confirmacion' | 'automatico'), motivo, cuenta_ahorro_id, fecha y lineas:
--   [{destino, referencia_id, etiqueta, monto_centavos, movimiento_id}].
create function public.fin_dispersion_registrar(p jsonb, p_final text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_mov_id  uuid;
  v_modo    text;
  v_motivo  text;
  v_ahorro  uuid;
  v_fecha   date;
  v_hoy     date := public.fin_fugas_hoy();
  v_mov     public.fin_movimientos%rowtype;
  v_libro   public.fin_libros%rowtype;
  v_ex      public.fin_dispersiones%rowtype;
  v_otro    public.fin_dispersiones%rowtype;
  v_param   public.fin_parametros%rowtype;
  v_deuda   public.fin_deudas%rowtype;
  v_cuenta  public.fin_cuentas%rowtype;
  v_nombre  uuid;
  v_realiza uuid;
  v_suma    bigint := 0;
  v_n       integer;
  e         record;
  v_destino text;
  v_ref     uuid;
  v_etiq    text;
  v_monto   bigint;
  v_midl    uuid;
  v_mid     uuid;
  v_cuenta_dest uuid;
  v_tipo    text;
  v_nota    text;
begin
  if public.persona_actual() is null or p is null or jsonb_typeof(p) <> 'object' then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  v_id := nullif(p ->> 'id', '')::uuid;
  v_mov_id := nullif(p ->> 'movimiento_id', '')::uuid;
  v_modo := coalesce(nullif(p ->> 'modo', ''), 'confirmacion');
  v_motivo := nullif(btrim(p ->> 'motivo'), '');
  v_ahorro := nullif(p ->> 'cuenta_ahorro_id', '')::uuid;
  v_fecha := nullif(p ->> 'fecha', '')::date;
  if v_id is null or v_mov_id is null then
    raise exception using errcode = '22023', message = 'El reparto lleva su id y el id del ingreso.';
  end if;
  if v_modo not in ('confirmacion', 'automatico') then
    raise exception using errcode = '22023', message = 'El modo es confirmacion o automatico.';
  end if;
  if (p_final = 'automatica') <> (v_modo = 'automatico') and p_final <> 'propuesta' then
    raise exception using errcode = '22023', message = 'El modo no corresponde al estado del reparto.';
  end if;
  if p_final = 'propuesta' and v_modo = 'automatico' then
    raise exception using errcode = '22023', message = 'Una propuesta es del modo con confirmación.';
  end if;
  if v_motivo is not null and char_length(v_motivo) > 200 then
    raise exception using errcode = '22023', message = 'El motivo admite hasta 200 caracteres.';
  end if;
  if jsonb_typeof(p -> 'lineas') is distinct from 'array' or jsonb_array_length(p -> 'lineas') not between 1 and 100 then
    raise exception using errcode = '22023', message = 'El reparto lleva de 1 a 100 renglones.';
  end if;

  -- El ingreso y el permiso en su libro (antes de revelar nada más).
  v_mov := public.fin_dispersion_ingreso(v_mov_id);
  v_libro := public.fin_dispersion_exigir(v_mov.libro_destino_id, 'escribir');
  if nullif(p ->> 'libro_id', '') is not null and (p ->> 'libro_id')::uuid <> v_libro.id then
    raise exception using errcode = '22023', message = 'El ingreso es de otro libro.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, v_motivo, p_final <> 'automatica');
  if v_libro.tipo = 'representado' and p_final = 'automatica' and v_motivo is null then
    v_motivo := 'Reparto automático';
  end if;
  v_realiza := case when v_libro.tipo = 'representado' then v_libro.titular_id else public.persona_actual() end;

  perform pg_advisory_xact_lock(hashtextextended('fin_dispersion:' || v_mov_id::text, 0));

  -- Idempotencia por id y reglas de vigencia.
  select * into v_ex from public.fin_dispersiones d where d.id = v_id;
  if found then
    if v_ex.movimiento_id <> v_mov_id then
      raise exception using errcode = '23505', message = 'Ese id ya es de otro reparto.';
    end if;
    if v_ex.estado = p_final and p_final <> 'propuesta' then
      return public.fin_dispersion_json(v_id);   -- reintento de la misma confirmación: no duplica nada
    end if;
    if v_ex.estado = 'anulada' then
      raise exception using errcode = '55000', message = 'Ese reparto ya está anulado.';
    end if;
    if v_ex.estado in ('confirmada', 'automatica') then
      raise exception using errcode = '55000', message = 'Ese ingreso ya está repartido.';
    end if;
  end if;
  if exists (select 1 from public.fin_movimientos a where a.anula_a = v_mov_id) then
    raise exception using errcode = '55000', message = 'Ese ingreso está anulado: ya no se reparte.';
  end if;
  if v_mov.estado_inicial <> 'confirmado' then
    raise exception using errcode = '55000', message = 'Solo se reparte un ingreso confirmado.';
  end if;
  select * into v_otro from public.fin_dispersiones d
   where d.movimiento_id = v_mov_id and d.estado <> 'anulada' and d.id <> v_id;
  if found and v_otro.estado in ('confirmada', 'automatica') then
    raise exception using errcode = '55000', message = 'Ese ingreso ya está repartido.';
  end if;

  select * into v_param from public.fin_parametros fp where fp.libro_id = v_libro.id;
  if p_final = 'automatica' and v_param.dispersion_modo is distinct from 'automatico' then
    raise exception using errcode = '55000', message = 'Este libro no está en modo automático.';
  end if;
  if v_fecha is not null and v_fecha > v_hoy + 1 then
    raise exception using errcode = '22023', message = 'La fecha del reparto no puede estar en el futuro.';
  end if;
  v_fecha := greatest(coalesce(v_fecha, v_hoy), v_mov.fecha);

  -- Los renglones: validar todos antes de escribir.
  for e in select x.value as r, x.ordinality as n from jsonb_array_elements(p -> 'lineas') with ordinality x loop
    if jsonb_typeof(e.r) <> 'object' then
      raise exception using errcode = '22023', message = 'Cada renglón es un objeto.';
    end if;
    v_destino := e.r ->> 'destino';
    v_ref := nullif(e.r ->> 'referencia_id', '')::uuid;
    if v_destino is null or v_destino not in ('presupuesto', 'pago_deuda', 'abono_extra', 'ahorro', 'libre', 'por_repartir') then
      raise exception using errcode = '22023', message = 'Destino de renglón no válido.';
    end if;
    if jsonb_typeof(e.r -> 'monto_centavos') is distinct from 'number' or (e.r ->> 'monto_centavos') !~ '^[0-9]{1,15}$' then
      raise exception using errcode = '22023', message = 'El monto de cada renglón es un entero en centavos, cero o más.';
    end if;
    v_monto := (e.r ->> 'monto_centavos')::bigint;
    v_suma := v_suma + v_monto;
    if nullif(btrim(e.r ->> 'etiqueta'), '') is null then
      raise exception using errcode = '22023', message = 'Cada renglón lleva su etiqueta.';
    end if;
    if (v_destino in ('pago_deuda', 'abono_extra')) <> (v_ref is not null) and v_destino in ('pago_deuda', 'abono_extra', 'ahorro', 'libre', 'por_repartir') then
      raise exception using errcode = '22023',
        message = 'Los pagos de deuda y los abonos extra apuntan a su deuda; el ahorro, lo libre y lo por repartir no apuntan a nada.';
    end if;
    if v_destino in ('pago_deuda', 'abono_extra') then
      select * into v_deuda from public.fin_deudas d where d.id = v_ref and d.libro_id = v_libro.id;
      if not found then
        raise exception using errcode = '22023', message = 'La deuda del renglón no es de este libro.';
      end if;
      if v_destino = 'abono_extra' and v_monto > 0 and not v_deuda.activa then
        raise exception using errcode = '55000', message = 'Esa deuda ya no está activa: no recibe abonos.';
      end if;
    end if;
    if v_modo = 'automatico' and v_destino in ('abono_extra', 'ahorro', 'libre') and v_monto > 0 then
      raise exception using errcode = '22023',
        message = 'En modo automático solo se asigna lo comprometido; el remanente queda por repartir.';
    end if;
    if v_destino = 'ahorro' and v_monto > 0 and p_final <> 'propuesta' and v_ahorro is null then
      raise exception using errcode = '22023', message = 'Elige la cuenta de ahorro o deja ese dinero por repartir.';
    end if;
  end loop;
  if v_suma <> v_mov.monto_centavos then
    raise exception using errcode = '22023',
      message = format('Los renglones suman %s y el ingreso es de %s centavos.', v_suma, v_mov.monto_centavos);
  end if;
  select count(*) into v_n from (
    select 1 from jsonb_array_elements(p -> 'lineas') r
     group by r.value ->> 'destino', coalesce(nullif(r.value ->> 'referencia_id', ''), '-') having count(*) > 1) x;
  if v_n > 0 then
    raise exception using errcode = '22023', message = 'Hay renglones repetidos (mismo destino y misma referencia).';
  end if;
  if v_ahorro is not null and p_final <> 'propuesta' then
    select * into v_cuenta from public.fin_cuentas c where c.id = v_ahorro and c.libro_id = v_libro.id;
    if not found or v_cuenta.clase <> 'activo' or v_cuenta.estado <> 'activa' or v_cuenta.id = v_mov.cuenta_destino_id then
      raise exception using errcode = '22023', message = 'La cuenta de ahorro es otra cuenta de dinero activa de este libro.';
    end if;
  end if;

  -- Escribir: la cabecera siempre como propuesta; los renglones; y al final el estado definitivo (así los renglones entran
  -- mientras el reparto es un borrador y las transiciones son las únicas permitidas).
  if v_otro.id is not null and v_otro.estado in ('propuesta', 'por_repartir') then
    update public.fin_dispersiones set estado = 'anulada' where id = v_otro.id;   -- la propuesta vieja se reemplaza
  end if;
  if v_ex.id is not null then
    delete from public.fin_dispersion_lineas where dispersion_id = v_id;
    update public.fin_dispersiones set modo = v_modo, motivo = v_motivo, en_nombre_de = v_nombre where id = v_id;
  else
    insert into public.fin_dispersiones (id, hogar_id, libro_id, movimiento_id, estado, modo, creada_por, en_nombre_de, motivo)
    values (v_id, v_libro.hogar_id, v_libro.id, v_mov_id, 'propuesta', v_modo, public.persona_actual(), v_nombre, v_motivo);
  end if;

  for e in select x.value as r, x.ordinality as n from jsonb_array_elements(p -> 'lineas') with ordinality x loop
    v_destino := e.r ->> 'destino';
    v_ref := nullif(e.r ->> 'referencia_id', '')::uuid;
    v_monto := (e.r ->> 'monto_centavos')::bigint;
    v_etiq := left(btrim(e.r ->> 'etiqueta'), 80);
    v_mid := null;
    -- Solo el abono extra y el ahorro mueven dinero, y solo al confirmar (también en el automático: ahí no hay ninguno).
    if p_final in ('confirmada', 'automatica') and v_destino in ('abono_extra', 'ahorro') and v_monto > 0 then
      v_midl := nullif(e.r ->> 'movimiento_id', '')::uuid;
      v_mid := coalesce(v_midl, md5('fin_dispersion_mov:' || v_id::text || ':'
                                    || case when v_destino = 'ahorro' then 'ahorro' else 'extra:' || v_ref::text end)::uuid);
      if v_destino = 'abono_extra' then
        select d.cuenta_pasivo_id into v_cuenta_dest from public.fin_deudas d where d.id = v_ref;
        v_tipo := 'pago_deuda';
        v_nota := 'Abono extra con un ingreso';
      else
        v_cuenta_dest := v_ahorro;
        v_tipo := 'transferencia';
        v_nota := 'Ahorro con un ingreso';
      end if;
      insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                          monto_centavos, realizado_por, registrado_por, en_nombre_de, via, nota, motivo)
      values (v_mid, v_libro.hogar_id, v_tipo, v_fecha, now(), v_mov.cuenta_destino_id, v_cuenta_dest, v_monto,
              v_realiza, public.persona_actual(), v_nombre, 'manual', v_nota, v_motivo);
    end if;
    insert into public.fin_dispersion_lineas (hogar_id, libro_id, dispersion_id, orden, destino, referencia_id, etiqueta,
                                              monto_centavos, movimiento_id)
    values (v_libro.hogar_id, v_libro.id, v_id, (e.n - 1)::smallint, v_destino, v_ref, v_etiq, v_monto, v_mid);
  end loop;

  if p_final <> 'propuesta' then
    update public.fin_dispersiones
       set estado = p_final,
           resuelta_por = case when p_final = 'confirmada' then public.persona_actual() end,
           resuelta_en = case when p_final = 'confirmada' then now() end
     where id = v_id;
  end if;
  return public.fin_dispersion_json(v_id);
end
$$;
comment on function public.fin_dispersion_registrar(jsonb, text) is
  'Interna: la usan fin_guardar_propuesta y fin_confirmar_dispersion. Valida el ingreso, el permiso, los renglones y la suma, '
  'reemplaza la propuesta anterior y, al confirmar, crea los movimientos de abono extra y ahorro con ids estables.';

create function public.fin_guardar_propuesta(p_dispersion jsonb)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
begin
  return public.fin_dispersion_registrar(p_dispersion, 'propuesta');
end
$$;
comment on function public.fin_guardar_propuesta(jsonb) is
  'Guarda el reparto editado como propuesta (borrador): no crea movimientos y el ingreso sigue por repartir. Si ya había una '
  'propuesta del mismo ingreso, la reemplaza. Idempotente por id. escribir en el libro; en el de Papá, en su nombre y con motivo.';

create function public.fin_confirmar_dispersion(p_dispersion jsonb)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
begin
  return public.fin_dispersion_registrar(p_dispersion,
    case when coalesce(p_dispersion ->> 'modo', 'confirmacion') = 'automatico' then 'automatica' else 'confirmada' end);
end
$$;
comment on function public.fin_confirmar_dispersion(jsonb) is
  'Confirma un reparto en una transacción: lo guarda con sus renglones y crea SOLO los movimientos de abono extra (pago de '
  'deuda) y de ahorro (transferencia) con ids estables; el renglón de pagos de deuda solo aparta (P4). Idempotente por id: '
  'repetirlo devuelve el reparto sin duplicar nada. Con modo automatico (solo si el libro está en ese modo) asigna lo '
  'comprometido y nunca crea movimientos. Rechaza un ingreso anulado, ya repartido, o una suma distinta del monto.';

-- 6.2 Deshacer un reparto aplicado: anula los movimientos que creó y el reparto queda «anulado» (el ingreso vuelve a «por repartir»).
create function public.fin_deshacer_dispersion(p_dispersion uuid, p_motivo text default 'Reparto deshecho')
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d      public.fin_dispersiones%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_motivo text := nullif(btrim(p_motivo), '');
  l        record;
  v_m      public.fin_movimientos%rowtype;
begin
  select * into v_d from public.fin_dispersiones d where d.id = p_dispersion;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  v_libro := public.fin_dispersion_exigir(v_d.libro_id, 'escribir');
  if v_d.estado = 'anulada' then
    return public.fin_dispersion_json(v_d.id);   -- reintento: ya está deshecho
  end if;
  if v_d.estado not in ('confirmada', 'automatica') then
    raise exception using errcode = '55000', message = 'Una propuesta no se deshace: se reemplaza o se deja para después.';
  end if;
  if not public.fin_motivo_valido(v_motivo) then
    raise exception using errcode = '22023', message = 'El motivo necesita al menos 3 caracteres visibles.';
  end if;
  perform public.fin_fugas_en_nombre(v_libro, v_motivo, true);
  perform pg_advisory_xact_lock(hashtextextended('fin_dispersion:' || v_d.movimiento_id::text, 0));
  for l in select x.movimiento_id from public.fin_dispersion_lineas x
            where x.dispersion_id = v_d.id and x.movimiento_id is not null order by x.orden loop
    if exists (select 1 from public.fin_movimientos a where a.anula_a = l.movimiento_id) then
      continue;   -- ya estaba anulado
    end if;
    select * into v_m from public.fin_movimientos m where m.id = l.movimiento_id;
    insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                        monto_centavos, realizado_por, registrado_por, en_nombre_de, via, motivo, anula_a)
    values (md5('fin_dispersion_deshacer:' || v_m.id::text)::uuid, v_m.hogar_id, 'anulacion', v_m.fecha, now(),
            v_m.cuenta_destino_id, v_m.cuenta_origen_id, v_m.monto_centavos, v_m.realizado_por,
            public.persona_actual(), v_m.en_nombre_de, 'manual', v_motivo, v_m.id);
  end loop;
  update public.fin_dispersiones set estado = 'anulada' where id = v_d.id;
  return public.fin_dispersion_json(v_d.id);
end
$$;
comment on function public.fin_deshacer_dispersion(uuid, text) is
  'Anula los movimientos de abono extra y ahorro que creó un reparto confirmado o automático (contraasientos con su misma fecha) '
  'y pasa el reparto a anulada: el ingreso vuelve a por repartir. Idempotente. escribir en el libro; motivo de 3 caracteres.';

-- 6.3 Corregir el tipo de un ingreso (sueldo registrado como extra): anulación + ingreso nuevo con el mismo grupo y motivo.
create function public.fin_corregir_tipo_ingreso(
  p_movimiento uuid, p_cuenta_origen uuid, p_motivo text, p_grupo uuid, p_id_anulacion uuid, p_id_nuevo uuid)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_m      public.fin_movimientos%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_orig   public.fin_cuentas%rowtype;
  v_nueva  public.fin_cuentas%rowtype;
  v_motivo text := nullif(btrim(p_motivo), '');
  v_estado text;
  v_ex     public.fin_movimientos%rowtype;
begin
  v_m := public.fin_dispersion_ingreso(p_movimiento);
  v_libro := public.fin_dispersion_exigir(v_m.libro_destino_id, 'escribir');
  if p_cuenta_origen is null or p_grupo is null or p_id_anulacion is null or p_id_nuevo is null then
    raise exception using errcode = '22023', message = 'Faltan la cuenta de origen, el grupo o los ids de los dos asientos.';
  end if;
  if not public.fin_motivo_valido(v_motivo) or char_length(v_motivo) > 200 then
    raise exception using errcode = '22023', message = 'El motivo necesita de 3 a 200 caracteres visibles.';
  end if;
  perform public.fin_fugas_en_nombre(v_libro, v_motivo, true);
  perform pg_advisory_xact_lock(hashtextextended('fin_dispersion:' || p_movimiento::text, 0));

  -- Reintento: los dos asientos ya existen con los ids dados.
  select * into v_ex from public.fin_movimientos a where a.id = p_id_anulacion;
  if found then
    if v_ex.anula_a is distinct from p_movimiento or v_ex.grupo_id is distinct from p_grupo
       or not exists (select 1 from public.fin_movimientos n where n.id = p_id_nuevo and n.grupo_id = p_grupo
                                                                 and n.cuenta_origen_id = p_cuenta_origen) then
      raise exception using errcode = '23505', message = 'Esos ids ya son de otra corrección.';
    end if;
    return jsonb_build_object('anulacion_id', p_id_anulacion, 'nuevo_id', p_id_nuevo, 'grupo_id', p_grupo);
  end if;

  if v_m.estado_inicial <> 'confirmado' then
    raise exception using errcode = '55000', message = 'Solo se corrige un ingreso confirmado; uno pendiente se rechaza.';
  end if;
  if exists (select 1 from public.fin_movimientos a where a.anula_a = p_movimiento) then
    raise exception using errcode = '55000', message = 'Ese ingreso ya está anulado.';
  end if;
  if exists (select 1 from public.fin_dispersiones d
              where d.movimiento_id = p_movimiento and d.estado in ('confirmada', 'automatica')) then
    raise exception using errcode = '55000',
      message = 'Ese ingreso ya está repartido. Deshaz el reparto y vuelve a intentarlo.';
  end if;
  select * into v_orig from public.fin_cuentas c where c.id = v_m.cuenta_origen_id;
  if p_cuenta_origen = v_m.cuenta_origen_id then
    raise exception using errcode = '22023', message = 'Elige un tipo distinto del actual.';
  end if;
  select * into v_nueva from public.fin_cuentas c where c.id = p_cuenta_origen and c.hogar_id = v_m.hogar_id;
  if not found or v_nueva.clase <> 'ingreso' or v_nueva.estado <> 'activa'
     or v_nueva.libro_id is distinct from v_orig.libro_id then
    raise exception using errcode = '22023', message = 'Elige un tipo de ingreso válido.';
  end if;
  -- En un libro compartido, el ingreso de otra persona se corrige pendiente de su confirmación (5.0 ter).
  v_estado := case when v_libro.tipo = 'compartido' and v_m.realizado_por <> public.persona_actual()
                   then 'pendiente' else 'confirmado' end;

  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                      monto_centavos, grupo_id, realizado_por, registrado_por, en_nombre_de, via, motivo,
                                      anula_a, estado_inicial)
  values (p_id_anulacion, v_m.hogar_id, 'anulacion', v_m.fecha, now(), v_m.cuenta_destino_id, v_m.cuenta_origen_id,
          v_m.monto_centavos, p_grupo, v_m.realizado_por, public.persona_actual(), v_m.en_nombre_de, 'manual', v_motivo,
          p_movimiento, v_estado);
  insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                      monto_centavos, grupo_id, realizado_por, registrado_por, en_nombre_de, via, nota,
                                      motivo, estado_inicial)
  values (p_id_nuevo, v_m.hogar_id, 'ingreso', v_m.fecha, now(), p_cuenta_origen, v_m.cuenta_destino_id,
          v_m.monto_centavos, p_grupo, v_m.realizado_por, public.persona_actual(), v_m.en_nombre_de, 'manual', v_m.nota,
          v_motivo, v_estado);
  return jsonb_build_object('anulacion_id', p_id_anulacion, 'nuevo_id', p_id_nuevo, 'grupo_id', p_grupo);
end
$$;
comment on function public.fin_corregir_tipo_ingreso(uuid, uuid, text, uuid, uuid, uuid) is
  'Corrige el tipo de un ingreso (p. ej. extra a sueldo) sin borrar nada: agrega la anulación (misma fecha) y un ingreso nuevo con '
  'el mismo monto, fecha y cuenta de destino desde p_cuenta_origen, ambos con p_grupo y el motivo. Rechaza lo que no es ingreso, '
  'un ingreso pendiente o anulado, uno ya repartido (confirmado o automático), un tipo igual o que no es de origen de ingreso. '
  'En un compartido, el ingreso de otra persona se corrige pendiente. Idempotente por los ids de los dos asientos. El reparto en '
  'borrador (propuesta) del ingreso viejo pasa a anulada por el disparador. escribir en el libro; el motivo es obligatorio.';

-- 6.4 Parámetros del reparto (administrar). Fija «desde» al activar la función.
create function public.fin_dispersion_parametros_cambiar(
  p_libro uuid, p_modo text default null, p_desde date default null, p_parte_libre_pb integer default null,
  p_tope_ahorro bigint default null, p_quitar_tope boolean default false, p_motivo text default null)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro  public.fin_libros%rowtype;
  v_p      public.fin_parametros%rowtype;
  v_motivo text := nullif(btrim(p_motivo), '');
  v_nombre uuid;
begin
  v_libro := public.fin_dispersion_exigir(p_libro, 'administrar');
  v_nombre := public.fin_fugas_en_nombre(v_libro, v_motivo, true);
  if p_modo is not null and p_modo not in ('confirmacion', 'automatico') then
    raise exception using errcode = '22023', message = 'El modo es confirmacion o automatico.';
  end if;
  if p_desde is not null and extract(isodow from p_desde) <> 1 then
    raise exception using errcode = '22023', message = 'El «desde» es un lunes (la semana empieza en lunes).';
  end if;
  if p_parte_libre_pb is not null and p_parte_libre_pb not between 0 and 10000 then
    raise exception using errcode = '22023', message = 'La parte libre va de 0 a 10000 puntos base.';
  end if;
  if p_tope_ahorro is not null and p_tope_ahorro <= 0 then
    raise exception using errcode = '22023', message = 'El tope de ahorro es mayor que cero (o se quita).';
  end if;
  select * into v_p from public.fin_parametros fp where fp.libro_id = p_libro for update;
  if not found then
    raise exception using errcode = '22023', message = 'Este libro no tiene parámetros todavía.';
  end if;
  update public.fin_parametros fp
     set dispersion_modo = coalesce(p_modo, fp.dispersion_modo),
         dispersion_desde = coalesce(p_desde, fp.dispersion_desde, public.fin_dispersion_desde_por_omision()),
         dispersion_parte_libre_pb = coalesce(p_parte_libre_pb, fp.dispersion_parte_libre_pb),
         dispersion_tope_ahorro = case when p_quitar_tope then null else coalesce(p_tope_ahorro, fp.dispersion_tope_ahorro) end
   where fp.libro_id = p_libro
  returning * into v_p;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_libro.hogar_id, public.persona_actual(), 'finanzas.dispersion_parametros', 'fin_parametros', p_libro::text,
          jsonb_strip_nulls(jsonb_build_object('libro_id', p_libro, 'modo', v_p.dispersion_modo,
                                               'desde', v_p.dispersion_desde, 'en_nombre_de', v_nombre, 'motivo', v_motivo)));
  return jsonb_build_object('modo', v_p.dispersion_modo, 'desde', v_p.dispersion_desde,
                            'parte_libre_pb', v_p.dispersion_parte_libre_pb, 'tope_ahorro', v_p.dispersion_tope_ahorro);
end
$$;
comment on function public.fin_dispersion_parametros_cambiar(uuid, text, date, integer, bigint, boolean, text) is
  'Cambia solo lo que se manda. La primera vez fija dispersion_desde (el lunes dado o el de la semana anterior, P2). administrar en '
  'el libro (la cuenta maestra nunca); en el de Papá, con motivo. Deja una entrada en la bitácora.';

-- 6.5 Lectura: ingresos con algo por repartir (para listas grandes; la app calcula con lo cargado).
create function public.fin_ingresos_por_repartir(p_libro uuid)
returns table (movimiento_id uuid, fecha date, monto_centavos bigint, cuenta_origen_id uuid, cuenta_destino_id uuid,
               dispersion_id uuid, estado text, pendiente_centavos bigint)
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_desde date;
begin
  if public.persona_actual() is null or p_libro is null or not public.fin_dispersion_puede_ver(p_libro) then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  select coalesce(fp.dispersion_desde, public.fin_dispersion_desde_por_omision()) into v_desde
    from public.fin_parametros fp where fp.libro_id = p_libro;
  v_desde := coalesce(v_desde, public.fin_dispersion_desde_por_omision());
  return query
  select q.id, q.fecha, q.monto_centavos, q.cuenta_origen_id, q.cuenta_destino_id, q.did, q.est, q.pend
    from (
      select m.id, m.fecha, m.monto_centavos, m.cuenta_origen_id, m.cuenta_destino_id, d.id as did,
             coalesce(d.estado, 'por_repartir') as est,
             case when d.id is null or d.estado in ('por_repartir', 'propuesta') then m.monto_centavos
                  else coalesce((select sum(l.monto_centavos) from public.fin_dispersion_lineas l
                                  where l.dispersion_id = d.id and l.destino = 'por_repartir'), 0)::bigint end as pend
        from public.fin_movimientos m
        left join public.fin_dispersiones d on d.movimiento_id = m.id and d.estado <> 'anulada'
       where m.libro_destino_id = p_libro and m.tipo = 'ingreso' and m.estado_inicial = 'confirmado'
         and m.fecha >= v_desde
         and not exists (select 1 from public.fin_movimientos a where a.anula_a = m.id)) q
   where q.pend > 0
   order by q.fecha desc, q.id;
end
$$;
comment on function public.fin_ingresos_por_repartir(uuid) is
  'Ingresos del libro desde dispersion_desde (o el lunes de la semana anterior) sin reparto vigente, con propuesta o con renglón por '
  'repartir. Solo lectura, solo quien puede ver los repartos del libro.';

revoke all on function
  public.fin_dispersiones_proteger(), public.fin_dispersion_lineas_proteger(), public.fin_dispersion_cuadra(),
  public.fin_dispersion_al_anular_ingreso(), public.fin_dispersion_exigir(uuid, text), public.fin_dispersion_json(uuid),
  public.fin_dispersion_desde_por_omision(), public.fin_dispersion_ingreso(uuid),
  public.fin_dispersion_registrar(jsonb, text)
  from public, anon, authenticated;
revoke all on function
  public.fin_guardar_propuesta(jsonb), public.fin_confirmar_dispersion(jsonb), public.fin_deshacer_dispersion(uuid, text),
  public.fin_corregir_tipo_ingreso(uuid, uuid, text, uuid, uuid, uuid),
  public.fin_dispersion_parametros_cambiar(uuid, text, date, integer, bigint, boolean, text),
  public.fin_ingresos_por_repartir(uuid)
  from public, anon;
grant execute on function
  public.fin_guardar_propuesta(jsonb), public.fin_confirmar_dispersion(jsonb), public.fin_deshacer_dispersion(uuid, text),
  public.fin_corregir_tipo_ingreso(uuid, uuid, text, uuid, uuid, uuid),
  public.fin_dispersion_parametros_cambiar(uuid, text, date, integer, bigint, boolean, text),
  public.fin_ingresos_por_repartir(uuid)
  to authenticated;
-- La usan las reglas (RLS): solo las sesiones de la app.
grant execute on function public.fin_dispersion_puede_ver(uuid) to authenticated, service_role;

-- 7. Avisos (D20): catálogo cerrado, sin cifras ni nombres ---------------------------------------------------------------
alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados', 'recordatorio_toma',
  'compra_papa_albacea', 'votacion_abierta', 'votacion_empate', 'reposicion_suplemento',
  'transferencia_pendiente',
  'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala',
  'ingreso_por_repartir'));

-- Severidad: igual que antes; ingreso_por_repartir es informativo (cae en el «else»).
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

-- La calcula la app en el dispositivo (sabe los montos) y la emite con fin_emitir_aviso.
create or replace function public.avisos_tipo_emitible(p_tipo text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_tipo in ('protegido_riesgo', 'flujo_negativo', 'abono_bajo_minimo', 'partida_100', 'partida_80',
                    'fondo_bajo', 'uso_limite', 'aportacion_pendiente', 'conciliacion_pendiente',
                    'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala',
                    'ingreso_por_repartir')
$$;

-- Título genérico (D20): hasta 40 caracteres, sin dígitos, sin "$" y sin nombres. La app tiene su propio catálogo; esto deja
-- el contrato verificable en el servidor. Nulo para cualquier otro tipo.
create function public.fin_dispersion_aviso_titulo(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case p_tipo when 'ingreso_por_repartir' then 'Tienes un ingreso por repartir' end
$$;
comment on function public.fin_dispersion_aviso_titulo(text) is
  'Título genérico (D20) del aviso del reparto de ingresos. Los avisos no guardan texto, monto ni nombre: la app lo toma de su catálogo.';

-- fin_emitir_aviso: igual que en 20261146; el tipo nuevo lo emite quien puede ver los repartos del libro y lleva por objeto el
-- ingreso (objeto_tipo 'movimiento'), que debe ser un ingreso que entra a ese libro.
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
  -- El aviso del reparto de ingresos: solo quien puede ver los repartos y con el ingreso como objeto.
  if p_tipo = 'ingreso_por_repartir' then
    if not public.fin_dispersion_puede_ver(p_libro_id) then
      raise exception using errcode = '42501', message = 'Sin permiso para emitir avisos del reparto de ingresos de ese libro.';
    end if;
    if p_objeto_tipo is distinct from 'movimiento' or p_objeto_id is null
       or not exists (select 1 from public.fin_movimientos x
                       where x.id = p_objeto_id and x.tipo = 'ingreso' and x.libro_destino_id = p_libro_id) then
      raise exception using errcode = '22023', message = 'El aviso del reparto lleva por objeto un ingreso de ese libro.';
    end if;
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

-- Preferencias: el tipo nuevo se puede silenciar (suena menos, sigue en la bandeja). Igual que la versión de 20261146 más el tipo.
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
             'fuga_por_reconocer', 'fuga_revision_mensual', 'deuda_en_vigilancia', 'deuda_se_volvio_mala',
             'ingreso_por_repartir')) then
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
