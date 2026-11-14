-- =============================================================================
-- GRAVITY · Alimentación Fase 7: código de barras del ingrediente
-- =============================================================================
-- Un código identifica a un ingrediente del hogar (el lector de la app lo busca en el catálogo local).
-- La columna no se escribe directo (sin permiso de columna para la app): solo la RPC ali_guardar_codigo_barras,
-- que valida el formato y deja la regla en el servidor. Lectura: la misma de ali_ingredientes.
-- =============================================================================

alter table public.ali_ingredientes add column codigo_barras text;
alter table public.ali_ingredientes add constraint ali_ingredientes_codigo_formato
  check (codigo_barras is null or codigo_barras ~ '^[0-9]{8,14}$');
create unique index ali_ingredientes_codigo_unico on public.ali_ingredientes (hogar_id, codigo_barras) where codigo_barras is not null;
comment on column public.ali_ingredientes.codigo_barras is
  'Código de barras (EAN/UPC, 8 a 14 dígitos) del producto. Único por hogar. Solo lo escribe la RPC ali_guardar_codigo_barras.';

create function public.ali_guardar_codigo_barras(p_ingrediente uuid, p_codigo text)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_persona uuid := public.persona_actual();
  v_ing     public.ali_ingredientes%rowtype;
  v_codigo  text := nullif(btrim(p_codigo), '');
begin
  if v_persona is null then
    raise exception using errcode = '42501', message = 'Se necesita una sesión.';
  end if;
  select * into v_ing from public.ali_ingredientes i where i.id = p_ingrediente for update;
  -- Sin permiso de lectura, el ingrediente "no existe" para quien llama (no se revela).
  if not found or not public.ali_puede7(v_ing.hogar_id, 'ingredientes', null, 'leer') then
    raise exception using errcode = 'P0002', message = 'El ingrediente no existe.';
  end if;
  if not public.ali_puede7(v_ing.hogar_id, 'ingredientes', null, 'escribir') then
    raise exception using errcode = '42501', message = 'Tu cuenta no edita el catálogo de ingredientes.';
  end if;
  if v_codigo is not null and v_codigo !~ '^[0-9]{8,14}$' then
    raise exception using errcode = '22023', message = 'El código de barras lleva de 8 a 14 dígitos.';
  end if;
  if v_codigo is not null and exists (
       select 1 from public.ali_ingredientes i
        where i.hogar_id = v_ing.hogar_id and i.codigo_barras = v_codigo and i.id <> v_ing.id) then
    raise exception using errcode = '23505', message = 'Ese código ya pertenece a otro ingrediente del hogar.';
  end if;
  update public.ali_ingredientes set codigo_barras = v_codigo, actualizado_por = v_persona, actualizado_en = now()
   where id = v_ing.id;
  return v_codigo;
end
$$;
comment on function public.ali_guardar_codigo_barras(uuid, text) is
  'Asocia un código de barras (8 a 14 dígitos) a un ingrediente; p_codigo nulo o vacío lo quita. 42501 si no es dueño ni pareja, '
  '22023 si el formato no vale, 23505 si el código ya es de otro ingrediente del hogar. Devuelve el código guardado.';

revoke all on function public.ali_guardar_codigo_barras(uuid, text) from public, anon;
grant execute on function public.ali_guardar_codigo_barras(uuid, text) to authenticated;
