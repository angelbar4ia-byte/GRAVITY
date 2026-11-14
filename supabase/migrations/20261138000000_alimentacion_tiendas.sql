-- =============================================================================
-- GRAVITY · Alimentación Fase 8 (ampliaciones 1, 3 y 4): tiendas del hogar y análisis del historial de compra
-- =============================================================================
-- Especificación: docs/specs/fase-8-alimentacion-ampliaciones.md (sección 1). Migración hacia adelante.
--   1) ali_tiendas: lista de tiendas del hogar (nombre corto, activa). La app agrega con ali_agregar_tienda y desactiva con
--      ali_tienda_activa; no se borra una tienda con compras (FK, 23503): se desactiva.
--   2) ali_compras.tienda_id (nulo): las compras anteriores quedan sin tienda ("sin tienda"). Toda compra NUEVA (ali_marcar_comprada, que
--      gana el parámetro p_tienda) exige tienda: sin ella 22023. Un trigger lo vuelve a exigir si alguien marca por otra vía.
--   3) Solo lectura, con las reglas de la lista (security invoker): ali_historial_compras y ali_resumen_historial. Solo precios REALES
--      (los de ali_precios_historial); el precio base de supuesto no entra. D3: nada de esto sale a la IA ni a las bocinas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tiendas del hogar
-- -----------------------------------------------------------------------------
create table public.ali_tiendas (
  id         uuid primary key default gen_random_uuid(),
  hogar_id   uuid not null references public.hogares (id),
  nombre     text not null check (char_length(btrim(nombre)) between 1 and 60),
  activa     boolean not null default true,
  creada_por uuid references public.personas (id),
  creada_en  timestamptz not null default now(),
  constraint ali_tiendas_hogar_id_key unique (hogar_id, id)
);
create unique index ali_tiendas_nombre_uno on public.ali_tiendas (hogar_id, lower(btrim(nombre)));
comment on table public.ali_tiendas is
  'Tiendas del hogar (Fase 8). Cada compra nueva lleva una. No se borran si tienen compras: se desactivan. La app escribe solo por ali_agregar_tienda y ali_tienda_activa.';

alter table public.ali_tiendas enable row level security;
-- Quien lleva las listas (dueño y pareja) y la maestra leen; el borrado (de una tienda sin compras) es de dueño y pareja.
create policy ali_tiendas_leer on public.ali_tiendas for select to authenticated
  using (public.ali_cuenta_de(hogar_id) in ('dueno', 'pareja', 'maestra'));
create policy ali_tiendas_borrar on public.ali_tiendas for delete to authenticated
  using (public.ali_cuenta_de(hogar_id) in ('dueno', 'pareja'));
revoke all on table public.ali_tiendas from public, anon, authenticated, service_role;
grant select on public.ali_tiendas to authenticated, service_role;
grant delete on public.ali_tiendas to authenticated;

-- -----------------------------------------------------------------------------
-- 2. La tienda en la compra
-- -----------------------------------------------------------------------------
alter table public.ali_compras add column tienda_id uuid;
alter table public.ali_compras add constraint ali_compras_tienda_fk
  foreign key (hogar_id, tienda_id) references public.ali_tiendas (hogar_id, id) on delete restrict;
create index ali_compras_historial_idx on public.ali_compras (hogar_id, comprado_en) where comprado;
comment on column public.ali_compras.tienda_id is
  'Tienda donde se compró. Nula solo en las compras anteriores a la Fase 8 (se leen como "sin tienda"); obligatoria en las nuevas. Solo la escribe ali_marcar_comprada.';

create function public.ali_compras_exige_tienda()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.comprado and not old.comprado and new.tienda_id is null then
    raise exception using errcode = '22023', message = 'Una compra nueva lleva tienda.', hint = 'tienda_id';
  end if;
  return new;
end
$$;
create trigger ali8_b_tienda before update on public.ali_compras
  for each row execute function public.ali_compras_exige_tienda();
revoke execute on function public.ali_compras_exige_tienda() from public, anon, authenticated, service_role;

-- ali_marcar_comprada gana p_tienda (quinto parámetro). Se reemplaza la firma de cuatro.
drop function public.ali_marcar_comprada(uuid, bigint, uuid, uuid);
create function public.ali_marcar_comprada(
  p_compra uuid, p_monto_centavos bigint default null, p_cuenta_origen uuid default null, p_cuenta_gasto uuid default null,
  p_tienda uuid default null)
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
  -- Fase 8: la tienda es obligatoria en toda compra nueva (la lista del hogar; ver ali_agregar_tienda).
  if p_tienda is null then
    raise exception using errcode = '22023', message = 'Indica en qué tienda compraste.', hint = 'p_tienda';
  end if;
  if not exists (select 1 from public.ali_tiendas t where t.hogar_id = v_c.hogar_id and t.id = p_tienda and t.activa) then
    raise exception using errcode = '22023', message = 'La tienda no existe en este hogar o está desactivada.', hint = 'p_tienda';
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
         estado_pago = v_estado, movimiento_id = v_mov, tienda_id = p_tienda
   where id = v_c.id;
  if v_estado = 'solicitud' then
    insert into public.ali_solicitudes_pago (hogar_id, compra_id, monto_centavos) values (v_c.hogar_id, v_c.id, p_monto_centavos)
    returning id into v_sol;
  end if;
  return jsonb_build_object('estado_pago', v_estado, 'movimiento_id', v_mov, 'solicitud_id', v_sol, 'precio_real_centavos', v_unit);
end
$$;
comment on function public.ali_marcar_comprada(uuid, bigint, uuid, uuid, uuid) is
  'Marca una compra de la lista. Con p_monto_centavos (lo pagado en total): el precio real por unidad reemplaza al base del ingrediente, se anota en '
  'el historial, sube la despensa de la cuenta y se registra el gasto: dueno/pareja desde p_cuenta_origen de su libro personal; casa desde una cuenta del '
  'libro compartido de ali_ajustes; papa con p_cuenta_origen del libro de Papá solo si quien llama es el albacea, y sin ella queda una solicitud al albacea '
  '(estado_pago = solicitud). Sin monto solo marca y sube el inventario. p_cuenta_gasto: por omisión la de la categoría Alimentación. Devuelve estado_pago, movimiento_id, '
  'solicitud_id y precio_real_centavos. Fase 8: p_tienda (obligatoria, tienda activa del hogar; 22023 si falta o no vale) queda en ali_compras.tienda_id.';

revoke all on function public.ali_marcar_comprada(uuid, bigint, uuid, uuid, uuid) from public, anon, service_role;
grant execute on function public.ali_marcar_comprada(uuid, bigint, uuid, uuid, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Agregar y desactivar tiendas
-- -----------------------------------------------------------------------------
create function public.ali_agregar_tienda(p_hogar_id uuid, p_nombre text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_t      public.ali_tiendas%rowtype;
begin
  if public.persona_actual() is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  if public.ali_cuenta_de(p_hogar_id) is null or public.ali_cuenta_de(p_hogar_id) not in ('dueno', 'pareja') then
    raise exception using errcode = '42501', message = 'Tu cuenta no agrega tiendas.';
  end if;
  if char_length(v_nombre) not between 1 and 60 then
    raise exception using errcode = '22023', message = 'El nombre de la tienda lleva de 1 a 60 caracteres.';
  end if;
  -- Si ya existe (aunque desactivada) se reutiliza y se reactiva: no se repite.
  select * into v_t from public.ali_tiendas t where t.hogar_id = p_hogar_id and lower(btrim(t.nombre)) = lower(v_nombre) for update;
  if found then
    if not v_t.activa then
      update public.ali_tiendas set activa = true where id = v_t.id returning * into v_t;
    end if;
  else
    insert into public.ali_tiendas (hogar_id, nombre, creada_por) values (p_hogar_id, v_nombre, public.persona_actual())
    returning * into v_t;
  end if;
  return jsonb_build_object('id', v_t.id, 'nombre', v_t.nombre, 'activa', v_t.activa);
end
$$;
comment on function public.ali_agregar_tienda(uuid, text) is
  'Agrega una tienda a la lista del hogar (dueño y pareja). Si el nombre ya existe (sin distinguir mayúsculas) devuelve esa y la reactiva. 42501 otra cuenta; 22023 nombre fuera de 1 a 60.';

create function public.ali_tienda_activa(p_tienda uuid, p_activa boolean)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_t public.ali_tiendas%rowtype;
begin
  if public.persona_actual() is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  if p_activa is null then
    raise exception using errcode = '22023', message = 'Indica si la tienda queda activa.';
  end if;
  select * into v_t from public.ali_tiendas t where t.id = p_tienda for update;
  if not found or coalesce(public.ali_cuenta_de(v_t.hogar_id), '') not in ('dueno', 'pareja', 'maestra') then
    raise exception using errcode = 'P0002', message = 'La tienda no existe.';
  end if;
  if public.ali_cuenta_de(v_t.hogar_id) not in ('dueno', 'pareja') then
    raise exception using errcode = '42501', message = 'Tu cuenta no cambia tiendas.';
  end if;
  update public.ali_tiendas set activa = p_activa where id = v_t.id returning * into v_t;
  return jsonb_build_object('id', v_t.id, 'nombre', v_t.nombre, 'activa', v_t.activa);
end
$$;
comment on function public.ali_tienda_activa(uuid, boolean) is
  'Activa o desactiva una tienda (dueño y pareja). Una tienda con compras no se borra: se desactiva. P0002 si no existe o no se lee; 42501 la maestra.';

revoke all on function public.ali_agregar_tienda(uuid, text), public.ali_tienda_activa(uuid, boolean) from public, anon, service_role;
grant execute on function public.ali_agregar_tienda(uuid, text), public.ali_tienda_activa(uuid, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Análisis del historial (solo lectura; security invoker: las reglas de la lista de cada cuenta)
-- -----------------------------------------------------------------------------
-- Cada cuenta ve su propio libro de compras y la lista de Papá y de la casa que le toca (dueño y pareja; la maestra todas);
-- el familiar no lee precios (ali_precios_historial). Solo compras marcadas con monto, con su precio unitario REAL.
create function public.ali_historial_compras(
  p_hogar_id uuid, p_desde date, p_hasta date, p_ingrediente uuid default null, p_tienda uuid default null)
returns table (
  compra_id uuid, fecha date, ingrediente_id uuid, ingrediente text, unidad text, tienda_id uuid, tienda text,
  cuenta text, precio_unitario_centavos bigint, cantidad numeric, gasto_centavos bigint)
language plpgsql stable security invoker
set search_path = ''
as $$
begin
  if p_desde is not null and p_hasta is not null and p_desde > p_hasta then
    raise exception using errcode = '22023', message = 'El rango de fechas está al revés.';
  end if;
  return query
  select c.id, (c.comprado_en at time zone 'America/Mexico_City')::date, c.ingrediente_id, i.nombre,
         coalesce(c.unidad, i.unidad), c.tienda_id, coalesce(t.nombre, 'Sin tienda'),
         c.cuenta, h.precio_centavos, c.cantidad, c.monto_centavos
    from public.ali_compras c
    join public.ali_precios_historial h on h.hogar_id = c.hogar_id and h.compra_id = c.id
    join public.ali_ingredientes i on i.hogar_id = c.hogar_id and i.id = c.ingrediente_id
    left join public.ali_tiendas t on t.hogar_id = c.hogar_id and t.id = c.tienda_id
   where c.hogar_id = p_hogar_id and c.comprado and c.monto_centavos is not null
     and (p_desde is null or (c.comprado_en at time zone 'America/Mexico_City')::date >= p_desde)
     and (p_hasta is null or (c.comprado_en at time zone 'America/Mexico_City')::date <= p_hasta)
     and (p_ingrediente is null or c.ingrediente_id = p_ingrediente)
     and (p_tienda is null or c.tienda_id = p_tienda)
   order by 2 desc, c.comprado_en desc, c.id;
end
$$;
comment on function public.ali_historial_compras(uuid, date, date, uuid, uuid) is
  'Compras reales marcadas con monto: fecha local, ingrediente, tienda ("Sin tienda" para las anteriores a la Fase 8), precio unitario real, cantidad y gasto '
  'en centavos. El precio base de supuesto no aparece. Filtros opcionales por ingrediente y tienda. Security invoker: lo que la cuenta lee de la lista.';

create function public.ali_resumen_historial(
  p_hogar_id uuid, p_desde date, p_hasta date, p_eje text,
  p_escala text default 'mes', p_ingrediente uuid default null, p_tienda uuid default null)
returns table (
  clave text, etiqueta text, compras bigint, cantidad numeric, gasto_centavos bigint,
  precio_min_centavos bigint, precio_max_centavos bigint, precio_primero_centavos bigint, precio_ultimo_centavos bigint, variacion_pct numeric)
language plpgsql stable security invoker
set search_path = ''
as $$
begin
  if p_eje is null or p_eje not in ('tiempo', 'precio', 'producto', 'tienda') then
    raise exception using errcode = '22023', message = 'El eje es tiempo, precio, producto o tienda.';
  end if;
  if p_escala is null or p_escala not in ('semana', 'mes', 'bimestre', 'semestre', 'anio') then
    raise exception using errcode = '22023', message = 'La escala es semana, mes, bimestre, semestre o anio.';
  end if;
  return query
  with h as (
    select * from public.ali_historial_compras(p_hogar_id, p_desde, p_hasta, p_ingrediente, p_tienda)
  ), g as (
    select h.*,
      case p_eje
        when 'tiempo' then (case p_escala
          when 'semana' then date_trunc('week', h.fecha::timestamp)
          when 'mes' then date_trunc('month', h.fecha::timestamp)
          when 'bimestre' then make_timestamp(extract(year from h.fecha)::int, ((extract(month from h.fecha)::int - 1) / 2) * 2 + 1, 1, 0, 0, 0)
          when 'semestre' then make_timestamp(extract(year from h.fecha)::int, ((extract(month from h.fecha)::int - 1) / 6) * 6 + 1, 1, 0, 0, 0)
          else date_trunc('year', h.fecha::timestamp) end)::date::text
        when 'tienda' then coalesce(h.tienda_id::text, 'sin_tienda')
        else h.ingrediente_id::text end as k,
      case p_eje when 'tienda' then h.tienda else h.ingrediente end as e
    from h
  )
  select g.k, min(g.e) as et, count(*)::bigint, sum(g.cantidad), sum(g.gasto_centavos)::bigint,
         -- Los precios unitarios solo se comparan entre compras del MISMO producto (ejes precio y producto, o filtrando un ingrediente).
         case when p_eje in ('precio', 'producto') or p_ingrediente is not null then min(g.precio_unitario_centavos) end,
         case when p_eje in ('precio', 'producto') or p_ingrediente is not null then max(g.precio_unitario_centavos) end,
         case when p_eje = 'precio' then (array_agg(g.precio_unitario_centavos order by g.fecha, g.compra_id))[1] end,
         case when p_eje = 'precio' then (array_agg(g.precio_unitario_centavos order by g.fecha desc, g.compra_id desc))[1] end,
         case when p_eje = 'precio' then
           round(((array_agg(g.precio_unitario_centavos order by g.fecha desc, g.compra_id desc))[1]
                  - (array_agg(g.precio_unitario_centavos order by g.fecha, g.compra_id))[1])::numeric * 100
                 / nullif((array_agg(g.precio_unitario_centavos order by g.fecha, g.compra_id))[1], 0), 1) end
    from g
   group by g.k
   order by (case when p_eje = 'tiempo' then g.k end), sum(g.gasto_centavos) desc, g.k;
end
$$;
comment on function public.ali_resumen_historial(uuid, date, date, text, text, uuid, uuid) is
  'Resumen del historial por eje: tiempo (clave = inicio del periodo; p_escala semana, mes, bimestre, semestre o anio), precio (por ingrediente: primero, ultimo, minimo, maximo y variacion porcentual), '
  'producto (por ingrediente) o tienda (con "sin_tienda" para lo anterior a la Fase 8). Los cuatro ejes suman lo mismo (compras, cantidad y gasto) para el mismo rango y filtros. '
  'Solo precios reales; security invoker. 22023 eje o escala inválidos.';

revoke all on function public.ali_historial_compras(uuid, date, date, uuid, uuid), public.ali_resumen_historial(uuid, date, date, text, text, uuid, uuid)
  from public, anon, service_role;
grant execute on function public.ali_historial_compras(uuid, date, date, uuid, uuid), public.ali_resumen_historial(uuid, date, date, text, text, uuid, uuid)
  to authenticated;
