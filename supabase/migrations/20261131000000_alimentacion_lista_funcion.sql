-- =============================================================================
-- GRAVITY · Alimentación Fase 7 (v1.2, 5c): lista de compras por función y presentación del ingrediente
-- =============================================================================
-- 1) La app ya no inserta en ali_compras: se agrega con ali_agregar_a_lista (suma si ya hay una pendiente de la semana).
-- 2) ali_ingredientes.presentacion (texto libre, p. ej. "bolsa 1 kg"); unidad y presentación del MISMO ingrediente se
--    cambian con ali_editar_presentacion. El nombre sigue siendo único por hogar; la marca no entra en la clave.
-- =============================================================================

alter table public.ali_compras add column unidad text check (unidad is null or char_length(btrim(unidad)) between 1 and 20);
comment on column public.ali_compras.unidad is
  'Unidad con que se pidió (por omisión la del ingrediente). Solo la escribe ali_agregar_a_lista.';
alter table public.ali_ingredientes add column presentacion text
  check (presentacion is null or char_length(btrim(presentacion)) between 1 and 60);
comment on column public.ali_ingredientes.presentacion is
  'Presentación del empaque (texto libre, sin marca en la clave). Solo la escribe ali_editar_presentacion.';

-- La app no inserta directo en la lista.
drop policy ali_compras_agregar on public.ali_compras;
revoke insert on public.ali_compras from authenticated;
revoke insert (id, hogar_id, cuenta, ingrediente_id, cantidad, comprador_id, para_el) on public.ali_compras from authenticated;

create function public.ali_agregar_a_lista(
  p_hogar_id uuid, p_ingrediente uuid, p_cantidad numeric, p_unidad text default null)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_q      text := public.ali_cuenta_de(p_hogar_id);
  v_cuenta text;
  v_ing    public.ali_ingredientes%rowtype;
  v_unidad text;
  v_fila   public.ali_compras%rowtype;
  v_semana timestamptz := date_trunc('week', now());
begin
  if public.persona_actual() is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  v_cuenta := case v_q when 'dueno' then 'dueno' when 'pareja' then 'pareja' when 'familiar' then 'papa' end;
  if v_cuenta is null then
    raise exception using errcode = '42501', message = 'Tu cuenta no agrega a la lista de compras.';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception using errcode = '22023', message = 'La cantidad debe ser mayor que cero.';
  end if;
  if p_unidad is not null and btrim(p_unidad) = '' then
    raise exception using errcode = '22023', message = 'La unidad no puede ir vacía.';
  end if;
  select * into v_ing from public.ali_ingredientes i
   where i.id = p_ingrediente and i.hogar_id = p_hogar_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'El ingrediente no existe.';
  end if;
  v_unidad := coalesce(btrim(p_unidad), v_ing.unidad);

  select * into v_fila from public.ali_compras c
   where c.hogar_id = p_hogar_id and c.cuenta = v_cuenta and c.ingrediente_id = p_ingrediente
     and not c.comprado and c.votacion_id is null and c.creada_en >= v_semana
     and coalesce(c.unidad, v_ing.unidad) = v_unidad
   order by c.creada_en limit 1 for update;
  if found then
    update public.ali_compras set cantidad = cantidad + p_cantidad, unidad = v_unidad
     where id = v_fila.id returning * into v_fila;
  else
    insert into public.ali_compras (hogar_id, cuenta, ingrediente_id, cantidad, unidad, solicitada_por)
    values (p_hogar_id, v_cuenta, p_ingrediente, p_cantidad, v_unidad, public.persona_actual())
    returning * into v_fila;
  end if;
  return jsonb_build_object('id', v_fila.id, 'cuenta', v_fila.cuenta, 'ingrediente_id', v_fila.ingrediente_id,
                            'cantidad', v_fila.cantidad, 'unidad', v_fila.unidad, 'pasillo', v_ing.pasillo, 'comprado', false);
end
$$;
comment on function public.ali_agregar_a_lista(uuid, uuid, numeric, text) is
  'Agrega un ingrediente a la lista de la semana (dueño y pareja: la suya; familiar: la de Papá). Si ya hay una fila pendiente del '
  'mismo ingrediente y unidad esta semana, suma la cantidad. 42501 cuidadora, Casa, maestra; 22023 cantidad <= 0 o unidad vacía; P0002 sin ingrediente.';

create function public.ali_editar_presentacion(p_ingrediente uuid, p_unidad text, p_presentacion text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_ing    public.ali_ingredientes%rowtype;
  v_unidad text;
  v_pres   text;
begin
  if public.persona_actual() is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_ing from public.ali_ingredientes i where i.id = p_ingrediente for update;
  if not found or not public.ali_puede7(v_ing.hogar_id, 'ingredientes', null, 'leer') then
    raise exception using errcode = 'P0002', message = 'El ingrediente no existe.';
  end if;
  if not public.ali_puede7(v_ing.hogar_id, 'ingredientes', null, 'escribir') then
    raise exception using errcode = '42501', message = 'Tu cuenta no edita el catálogo de ingredientes.';
  end if;
  if p_unidad is not null and (btrim(p_unidad) = '' or char_length(btrim(p_unidad)) > 20) then
    raise exception using errcode = '22023', message = 'La unidad lleva de 1 a 20 caracteres.';
  end if;
  -- nulo conserva; cadena vacía quita la presentación.
  v_unidad := coalesce(btrim(p_unidad), v_ing.unidad);
  v_pres := case when p_presentacion is null then v_ing.presentacion else nullif(btrim(p_presentacion), '') end;
  if v_pres is not null and char_length(v_pres) > 60 then
    raise exception using errcode = '22023', message = 'La presentación lleva hasta 60 caracteres.';
  end if;
  update public.ali_ingredientes
     set unidad = v_unidad, presentacion = v_pres,
         actualizado_por = public.persona_actual(), actualizado_en = now()
   where id = v_ing.id;
  -- Lo pendiente de la lista sigue la nueva unidad (no se crea otro ingrediente ni otra fila).
  if v_unidad is distinct from v_ing.unidad then
    update public.ali_compras set unidad = v_unidad
     where ingrediente_id = v_ing.id and not comprado and coalesce(unidad, v_ing.unidad) = v_ing.unidad;
  end if;
  return jsonb_build_object('id', v_ing.id, 'nombre', v_ing.nombre, 'unidad', v_unidad, 'presentacion', v_pres);
end
$$;
comment on function public.ali_editar_presentacion(uuid, text, text) is
  'Cambia la unidad o la presentación del MISMO ingrediente (no crea otro; la marca no es clave). p_unidad nulo conserva; p_presentacion nulo '
  'conserva y vacío la quita. 42501 si no es dueño ni pareja, 22023 si la unidad no vale, P0002 si no existe o no se lee.';

revoke all on function public.ali_agregar_a_lista(uuid, uuid, numeric, text) from public, anon;
revoke all on function public.ali_editar_presentacion(uuid, text, text) from public, anon;
grant execute on function public.ali_agregar_a_lista(uuid, uuid, numeric, text) to authenticated;
grant execute on function public.ali_editar_presentacion(uuid, text, text) to authenticated;
