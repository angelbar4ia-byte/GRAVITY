-- =============================================================================
-- GRAVITY · Finanzas · Fase 8, paquete F8-6.7: «Cambiar reparto»
-- (docs/specs/fase-8-finanzas-dispersion.md, pregunta P5 resuelta por el dueño el 20/nov/2026; D3, D5, D6, D19, D20, D24)
-- =============================================================================
-- Un reparto de ingreso ya CONFIRMADO (o automático) se puede CAMBIAR, no solo deshacer. Qué agrega:
--
-- 1. fin_dispersiones: columnas version (1, 2, 3… dentro de la cadena de un ingreso) y reemplaza_a (el reparto al que sustituye),
--    y un estado nuevo, «reemplazada»: el reparto anterior conserva su historial (renglones y movimientos que creó) pero ya no es
--    el vigente. UN único reparto vigente por ingreso (el índice único parcial excluye anuladas y reemplazadas).
-- 2. fin_cambiar_dispersion(p_cambio jsonb): en UNA transacción y con CONTROL DE VERSIÓN: el cliente manda el id del reparto que
--    vio y su versión; si ya no es el vigente con esa versión, rechaza («El reparto cambió, vuelve a cargar.», SQLSTATE 40001) para
--    que dos dispositivos no se pisen. Libro solo-agregar: anula con contraasiento y motivo los movimientos que creó el reparto
--    anterior (abono extra y ahorro), pasa el anterior a «reemplazada» y confirma el nuevo con sus propios movimientos (solo abono
--    extra y ahorro; el renglón de pagos de deuda sigue solo apartando, P4). Idempotente por el id del cambio (= id del reparto
--    nuevo). Mismos permisos que confirmar: escribir en el libro y poder ver los repartos; la cuenta maestra (solo lectura), el
--    familiar, el cuidador, Casa, la tablet pública y la vista temporal de Papá no pueden. En el libro de Papá: en su nombre y con
--    motivo. Suma de renglones = monto del ingreso.
-- 3. fin_corregir_tipo_ingreso ya no rechaza un ingreso repartido: en la misma transacción deshace el reparto (anula los
--    movimientos que creó y lo pasa a «anulada») y agrega los dos asientos de la corrección; el ingreso nuevo nace «por repartir» y
--    se reparte como sueldo. Sin movimientos huérfanos. Solo si la corrección quedaría pendiente de otra persona (compartido) se
--    pide primero cambiar o deshacer el reparto.
-- 4. fin_deshacer_dispersion, el disparador de anulación del ingreso, fin_ingresos_por_repartir y fin_dispersion_registrar
--    entienden «reemplazada» (no es vigente). Bitácora: finanzas.dispersion_cambiada, sin cifras (D20).
-- Dinero en bigint de centavos. Migración hacia adelante. Sin secretos ni datos reales. No hay tablas nuevas: los disparadores de
-- Realtime (20261148) de fin_dispersiones y fin_dispersion_lineas siguen avisando.
-- =============================================================================

-- 1. Cadena de versiones ---------------------------------------------------------------------------------------------
alter table public.fin_dispersiones add column version integer not null default 1 check (version >= 1);
alter table public.fin_dispersiones add column reemplaza_a uuid references public.fin_dispersiones (id);
alter table public.fin_dispersiones drop constraint fin_dispersiones_estado_check;
alter table public.fin_dispersiones add constraint fin_dispersiones_estado_check
  check (estado in ('por_repartir', 'propuesta', 'confirmada', 'automatica', 'anulada', 'reemplazada'));
-- Una versión sustituye a una sola anterior, y una anterior tiene una sola sucesora.
alter table public.fin_dispersiones add constraint fin_dispersiones_cadena
  check ((version = 1) = (reemplaza_a is null));
create unique index fin_dispersiones_una_sucesora on public.fin_dispersiones (reemplaza_a) where reemplaza_a is not null;
drop index public.fin_dispersiones_una_vigente;
create unique index fin_dispersiones_una_vigente on public.fin_dispersiones (movimiento_id)
  where estado not in ('anulada', 'reemplazada');
comment on column public.fin_dispersiones.version is
  'Versión dentro de la cadena de cambios de un ingreso: 1 el primer reparto, 2 el primer cambio… El cliente la manda al cambiar '
  'el reparto; si ya no es la vigente, el servidor rechaza (control de versión).';
comment on column public.fin_dispersiones.reemplaza_a is
  'El reparto al que sustituye este (nulo en la versión 1). Lo fija fin_cambiar_dispersion; nunca cambia.';

-- Las vigentes: todas las que no están anuladas ni reemplazadas.
drop view public.fin_v_dispersiones_vigentes;
create view public.fin_v_dispersiones_vigentes with (security_invoker = true) as
select d.* from public.fin_dispersiones d where d.estado not in ('anulada', 'reemplazada');
comment on view public.fin_v_dispersiones_vigentes is 'El reparto vigente de cada ingreso (ni anulado ni reemplazado).';
revoke all on table public.fin_v_dispersiones_vigentes from public, anon, authenticated, service_role;
grant select on public.fin_v_dispersiones_vigentes to authenticated, service_role;

comment on table public.fin_dispersiones is
  'Reparto de un ingreso (cascada: presupuesto, deuda, remanente). UN reparto vigente por movimiento; cambiarlo (P5) crea otra '
  'versión y deja la anterior como reemplazada con su historial. Sin DELETE; el estado solo cambia por transiciones (propuesta a '
  'confirmada, automatica o anulada; confirmada o automatica a anulada o reemplazada) hechas por las RPC y por el disparador que '
  'anula el reparto cuando se anula el ingreso. Escritura solo por RPC.';

-- 2. Protección: el estado solo cambia por transiciones; la cadena no se toca -------------------------------------------------
create or replace function public.fin_dispersiones_proteger()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '42501', message = 'Un reparto no se borra: se anula y queda como registro.';
  end if;
  if new.id <> old.id or new.hogar_id <> old.hogar_id or new.libro_id <> old.libro_id
     or new.movimiento_id <> old.movimiento_id or new.creada_por <> old.creada_por or new.creada_en <> old.creada_en
     or new.version <> old.version or new.reemplaza_a is distinct from old.reemplaza_a then
    raise exception using errcode = '42501', message = 'Un reparto solo cambia de estado.';
  end if;
  if old.estado in ('anulada', 'reemplazada') then
    raise exception using errcode = '55000', message = 'Un reparto anulado o reemplazado ya no cambia.';
  end if;
  if old.estado in ('confirmada', 'automatica') then
    if new.estado not in ('anulada', 'reemplazada') or (to_jsonb(old) - 'estado') is distinct from (to_jsonb(new) - 'estado') then
      raise exception using errcode = '55000', message = 'Un reparto confirmado solo se anula (deshacer) o se reemplaza (cambiar).';
    end if;
  end if;
  if new.estado = 'reemplazada' and old.estado not in ('confirmada', 'automatica') then
    raise exception using errcode = '55000', message = 'Solo un reparto aplicado se reemplaza.';
  end if;
  return new;
end
$$;

-- La versión y el vínculo los fija el servidor al insertar, a partir de lo que dejó fin_cambiar_dispersion (variable de la
-- transacción): nadie los manda desde afuera, porque la tabla no tiene escritura directa.
create function public.fin_dispersion_version()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_prev uuid;
  v_ant  public.fin_dispersiones%rowtype;
begin
  v_prev := nullif(current_setting('gravity.fin_dispersion_reemplaza', true), '')::uuid;
  if v_prev is null then
    return new;
  end if;
  select * into v_ant from public.fin_dispersiones d where d.id = v_prev;
  if found and v_ant.movimiento_id = new.movimiento_id then
    new.version := v_ant.version + 1;
    new.reemplaza_a := v_ant.id;
  end if;
  return new;
end
$$;
create trigger fin_a_version before insert on public.fin_dispersiones
  for each row execute function public.fin_dispersion_version();

-- El reparto con sus renglones, como lo devuelven las RPC (ahora con la versión).
create or replace function public.fin_dispersion_json(p_id uuid)
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'id', d.id, 'libro_id', d.libro_id, 'movimiento_id', d.movimiento_id, 'estado', d.estado, 'modo', d.modo,
           'version', d.version, 'reemplaza_a', d.reemplaza_a,
           'creada_en', d.creada_en, 'resuelta_por', d.resuelta_por, 'resuelta_en', d.resuelta_en,
           'en_nombre_de', d.en_nombre_de, 'motivo', d.motivo,
           'lineas', coalesce((select jsonb_agg(jsonb_build_object(
                         'destino', l.destino, 'referencia_id', l.referencia_id, 'etiqueta', l.etiqueta,
                         'monto_centavos', l.monto_centavos, 'movimiento_id', l.movimiento_id) order by l.orden)
                       from public.fin_dispersion_lineas l where l.dispersion_id = d.id), '[]'::jsonb))
    from public.fin_dispersiones d where d.id = p_id
$$;

-- Anula (contraasiento con su misma fecha y el motivo) los movimientos que creó un reparto y siguen vigentes. Devuelve cuántos.
-- Interna: la usan deshacer, cambiar y corregir el tipo; ellas validan el permiso. Ids estables: repetir no duplica.
create function public.fin_dispersion_anular_movimientos(p_dispersion uuid, p_motivo text)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  l   record;
  v_m public.fin_movimientos%rowtype;
  v_n integer := 0;
begin
  for l in select x.movimiento_id from public.fin_dispersion_lineas x
            where x.dispersion_id = p_dispersion and x.movimiento_id is not null order by x.orden loop
    if exists (select 1 from public.fin_movimientos a where a.anula_a = l.movimiento_id) then
      continue;   -- ya estaba anulado
    end if;
    select * into v_m from public.fin_movimientos m where m.id = l.movimiento_id;
    insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                        monto_centavos, realizado_por, registrado_por, en_nombre_de, via, motivo, anula_a)
    values (md5('fin_dispersion_deshacer:' || v_m.id::text)::uuid, v_m.hogar_id, 'anulacion', v_m.fecha, now(),
            v_m.cuenta_destino_id, v_m.cuenta_origen_id, v_m.monto_centavos, v_m.realizado_por,
            public.persona_actual(), v_m.en_nombre_de, 'manual', p_motivo, v_m.id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;
comment on function public.fin_dispersion_anular_movimientos(uuid, text) is
  'Interna. Anula con contraasiento los movimientos de abono extra y ahorro que creó un reparto (los que sigan vigentes).';

-- 3. Disparador de anulación del ingreso: ignora las reemplazadas ------------------------------------------------------------

create or replace function public.fin_dispersion_registrar(p jsonb, p_final text)
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
    if v_ex.estado = 'reemplazada' then
      raise exception using errcode = '40001', message = 'El reparto cambió, vuelve a cargar.';
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
   where d.movimiento_id = v_mov_id and d.estado not in ('anulada', 'reemplazada') and d.id <> v_id;
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

create or replace function public.fin_ingresos_por_repartir(p_libro uuid)
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
        left join public.fin_dispersiones d on d.movimiento_id = m.id and d.estado not in ('anulada', 'reemplazada')
       where m.libro_destino_id = p_libro and m.tipo = 'ingreso' and m.estado_inicial = 'confirmado'
         and m.fecha >= v_desde
         and not exists (select 1 from public.fin_movimientos a where a.anula_a = m.id)) q
   where q.pend > 0
   order by q.fecha desc, q.id;
end
$$;

create or replace function public.fin_dispersion_al_anular_ingreso()
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
    select d.* from public.fin_dispersiones d where d.movimiento_id = new.anula_a and d.estado not in ('anulada', 'reemplazada')
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

create or replace function public.fin_corregir_tipo_ingreso(
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
  v_repartos uuid[];
  v_reparto  uuid;
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
  -- Ya repartido (P5): la corrección deshace el reparto en la misma transacción (abajo). Si la corrección queda pendiente de otra
  -- persona (compartido, 5.0 ter) no se deshace nada todavía: se pide cambiar o deshacer el reparto primero.
  v_repartos := array(select d.id from public.fin_dispersiones d
                       where d.movimiento_id = p_movimiento and d.estado in ('confirmada', 'automatica'));
  if cardinality(v_repartos) > 0 and v_libro.tipo = 'compartido' and v_m.realizado_por <> public.persona_actual() then
    raise exception using errcode = '55000',
      message = 'Ese ingreso ya está repartido y su corrección espera la confirmación de otra persona. '
                'Cambia o deshaz el reparto y vuelve a intentarlo.';
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

  -- Sin movimientos huérfanos: los abonos extra y el ahorro que creó el reparto se anulan (contraasiento con su fecha y el motivo
  -- de la corrección) y el reparto queda anulado; el ingreso nuevo nace «por repartir». El disparador de anulación del ingreso ya
  -- no encuentra reparto vigente.
  foreach v_reparto in array v_repartos loop
    perform public.fin_dispersion_anular_movimientos(v_reparto, v_motivo);
    update public.fin_dispersiones set estado = 'anulada' where id = v_reparto;
  end loop;

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

-- 4. Deshacer: una reemplazada ya no se deshace (cambió) ------------------------------------------------------------------------
create or replace function public.fin_deshacer_dispersion(p_dispersion uuid, p_motivo text default 'Reparto deshecho')
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_d      public.fin_dispersiones%rowtype;
  v_libro  public.fin_libros%rowtype;
  v_motivo text := nullif(btrim(p_motivo), '');
begin
  select * into v_d from public.fin_dispersiones d where d.id = p_dispersion;
  if not found then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  v_libro := public.fin_dispersion_exigir(v_d.libro_id, 'escribir');
  if v_d.estado = 'anulada' then
    return public.fin_dispersion_json(v_d.id);   -- reintento: ya está deshecho
  end if;
  if v_d.estado = 'reemplazada' then
    raise exception using errcode = '40001', message = 'El reparto cambió, vuelve a cargar.';
  end if;
  if v_d.estado not in ('confirmada', 'automatica') then
    raise exception using errcode = '55000', message = 'Una propuesta no se deshace: se reemplaza o se deja para después.';
  end if;
  if not public.fin_motivo_valido(v_motivo) then
    raise exception using errcode = '22023', message = 'El motivo necesita al menos 3 caracteres visibles.';
  end if;
  perform public.fin_fugas_en_nombre(v_libro, v_motivo, true);
  perform pg_advisory_xact_lock(hashtextextended('fin_dispersion:' || v_d.movimiento_id::text, 0));
  perform public.fin_dispersion_anular_movimientos(v_d.id, v_motivo);
  update public.fin_dispersiones set estado = 'anulada' where id = v_d.id;
  return public.fin_dispersion_json(v_d.id);
end
$$;

-- 5. Cambiar un reparto ya confirmado (P5) ---------------------------------------------------------------------------------------
-- Payload (jsonb): el del reparto de siempre (id = id del cambio y del reparto nuevo, movimiento_id, motivo, cuenta_ahorro_id,
-- fecha, lineas) más dispersion_anterior_id y version_esperada (lo que el cliente vio).
create function public.fin_cambiar_dispersion(p_cambio jsonb)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_ant_id  uuid;
  v_vers    integer;
  v_mov_id  uuid;
  v_motivo  text;
  v_mov     public.fin_movimientos%rowtype;
  v_libro   public.fin_libros%rowtype;
  v_ant     public.fin_dispersiones%rowtype;
  v_ex      public.fin_dispersiones%rowtype;
  v_nombre  uuid;
  v_anulados integer;
begin
  if public.persona_actual() is null or p_cambio is null or jsonb_typeof(p_cambio) <> 'object' then
    raise exception using errcode = '42501', message = 'No puedes repartir ingresos de este libro.';
  end if;
  v_id := nullif(p_cambio ->> 'id', '')::uuid;
  v_ant_id := nullif(p_cambio ->> 'dispersion_anterior_id', '')::uuid;
  v_mov_id := nullif(p_cambio ->> 'movimiento_id', '')::uuid;
  v_vers := case when (p_cambio ->> 'version_esperada') ~ '^[0-9]{1,9}$' then (p_cambio ->> 'version_esperada')::integer end;
  v_motivo := nullif(btrim(p_cambio ->> 'motivo'), '');
  if v_id is null or v_ant_id is null or v_mov_id is null or v_vers is null then
    raise exception using errcode = '22023',
      message = 'El cambio lleva su id, el id del ingreso, el reparto que viste y su versión.';
  end if;

  -- El permiso primero (antes de revelar nada más): escribir en el libro del ingreso y poder ver sus repartos.
  v_mov := public.fin_dispersion_ingreso(v_mov_id);
  v_libro := public.fin_dispersion_exigir(v_mov.libro_destino_id, 'escribir');
  if v_motivo is null and v_libro.tipo <> 'representado' then
    v_motivo := 'Reparto cambiado';
  end if;
  if not public.fin_motivo_valido(v_motivo) or char_length(v_motivo) > 200 then
    raise exception using errcode = '22023', message = 'El motivo necesita de 3 a 200 caracteres visibles.';
  end if;
  v_nombre := public.fin_fugas_en_nombre(v_libro, v_motivo, true);   -- en el libro de Papá: en su nombre y con motivo
  perform pg_advisory_xact_lock(hashtextextended('fin_dispersion:' || v_mov_id::text, 0));

  -- Reintento: el cambio ya se hizo con este id.
  select * into v_ex from public.fin_dispersiones d where d.id = v_id;
  if found then
    if v_ex.movimiento_id <> v_mov_id or v_ex.reemplaza_a is distinct from v_ant_id then
      raise exception using errcode = '23505', message = 'Ese id ya es de otro reparto.';
    end if;
    return public.fin_dispersion_json(v_id);
  end if;

  -- Control de versión: debe seguir siendo el reparto vigente que el cliente vio.
  select * into v_ant from public.fin_dispersiones d where d.id = v_ant_id for update;
  if not found or v_ant.movimiento_id <> v_mov_id then
    raise exception using errcode = '22023', message = 'Ese reparto no es de este ingreso.';
  end if;
  if v_ant.estado in ('propuesta', 'por_repartir') then
    raise exception using errcode = '55000', message = 'Una propuesta no se cambia: se confirma o se deja para después.';
  end if;
  if v_ant.estado not in ('confirmada', 'automatica') or v_ant.version <> v_vers then
    raise exception using errcode = '40001', message = 'El reparto cambió, vuelve a cargar.';
  end if;
  if exists (select 1 from public.fin_movimientos a where a.anula_a = v_mov_id) then
    raise exception using errcode = '55000', message = 'Ese ingreso está anulado: ya no se reparte.';
  end if;

  -- Todo en esta transacción (si algo falla abajo, nada queda a medias): anular lo del reparto anterior, reemplazarlo y confirmar
  -- el nuevo con sus movimientos. fin_dispersion_registrar valida los renglones, la suma y la cuenta de ahorro.
  v_anulados := public.fin_dispersion_anular_movimientos(v_ant.id, v_motivo);
  update public.fin_dispersiones set estado = 'reemplazada' where id = v_ant.id;
  perform set_config('gravity.fin_dispersion_reemplaza', v_ant.id::text, true);
  perform public.fin_dispersion_registrar(
    p_cambio || jsonb_build_object('id', v_id, 'movimiento_id', v_mov_id, 'modo', 'confirmacion', 'motivo', v_motivo),
    'confirmada');
  perform set_config('gravity.fin_dispersion_reemplaza', '', true);

  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_libro.hogar_id, public.persona_actual(), 'finanzas.dispersion_cambiada', 'fin_dispersiones', v_id::text,
          jsonb_strip_nulls(jsonb_build_object('libro_id', v_libro.id, 'movimiento_id', v_mov_id,
                                               'reparto_anterior', v_ant.id, 'version_anterior', v_ant.version,
                                               'version_nueva', v_ant.version + 1, 'movimientos_anulados', v_anulados,
                                               'en_nombre_de', v_nombre, 'motivo', v_motivo)));
  return public.fin_dispersion_json(v_id);
end
$$;
comment on function public.fin_cambiar_dispersion(jsonb) is
  'Cambia un reparto confirmado o automático en una transacción: anula con contraasiento y motivo los movimientos del anterior, '
  'lo deja reemplazado (conserva su historial) y confirma el nuevo (versión +1) con sus movimientos de abono extra y ahorro. '
  'Control de versión: manda dispersion_anterior_id y version_esperada; si ya no es el vigente con esa versión, 40001 «El reparto '
  'cambió, vuelve a cargar.». Idempotente por id (el del reparto nuevo). escribir en el libro; en el de Papá, en su nombre y con motivo.';

comment on function public.fin_deshacer_dispersion(uuid, text) is
  'Anula los movimientos de abono extra y ahorro que creó un reparto confirmado o automático (contraasientos con su misma fecha) '
  'y pasa el reparto a anulada: el ingreso vuelve a por repartir. Idempotente. Un reparto reemplazado responde 40001 (cambió). '
  'escribir en el libro; motivo de 3 caracteres.';
comment on function public.fin_corregir_tipo_ingreso(uuid, uuid, text, uuid, uuid, uuid) is
  'Corrige el tipo de un ingreso (p. ej. extra a sueldo) sin borrar nada: agrega la anulación (misma fecha) y un ingreso nuevo con '
  'el mismo monto, fecha y cuenta de destino desde p_cuenta_origen, ambos con p_grupo y el motivo. Rechaza lo que no es ingreso, '
  'un ingreso pendiente o anulado, un tipo igual o que no es de origen de ingreso. Un ingreso ya repartido (confirmado o '
  'automático) se corrige: antes, en la misma transacción, se anulan los movimientos que creó el reparto y este queda anulado '
  '(el ingreso nuevo nace por repartir); si la corrección queda pendiente de otra persona (compartido) se rechaza hasta cambiar o '
  'deshacer el reparto. Idempotente por los ids de los dos asientos. escribir en el libro; el motivo es obligatorio.';

revoke all on function public.fin_dispersion_version(), public.fin_dispersion_anular_movimientos(uuid, text) from public, anon, authenticated;
revoke all on function public.fin_cambiar_dispersion(jsonb) from public, anon;
grant execute on function public.fin_cambiar_dispersion(jsonb) to authenticated;
