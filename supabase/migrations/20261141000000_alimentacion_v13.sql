-- Alimentación, Fase 8 v1.3 (migración 20261141): porciones recomendadas editables en el menú de dueño y pareja.
--   Respuesta del dueño (docs/specs/fase-8-alimentacion-ampliaciones.md, 2c): la porción por persona es editable.
--   La app ya llamaba a ali_porciones_recomendadas, pero ninguna migración la creó: las porciones nunca se leían.
--   Esta migración agrega la lectura (ali_porciones_recomendadas) y la escritura (ali_fijar_porcion).
--   No mueve dinero. Solo dueño y pareja (ali_puede en el menú 'pareja'); el menú de Papá no lleva porciones.

-- -----------------------------------------------------------------------------
-- 1. Lectura: porciones por platillo y persona de la semana (una fila por platillo y cuenta).
-- -----------------------------------------------------------------------------
create function public.ali_porciones_recomendadas(p_hogar_id uuid, p_semana date)
returns table (platillo_id uuid, cuenta text, porciones numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select m.platillo_id, k.key, max((k.value #>> '{}')::numeric)
    from public.ali_menu m
    cross join lateral jsonb_each(m.porciones_recomendadas) k
   where m.hogar_id = p_hogar_id
     and m.semana = p_semana
     and m.menu = 'pareja'
     and m.platillo_id is not null
     and public.ali_puede(m.hogar_id, m.menu, 'menu', 'leer')
   group by m.platillo_id, k.key
$$;
comment on function public.ali_porciones_recomendadas(uuid, date) is
  'Porciones recomendadas por persona del menú de dueño y pareja, de la semana indicada: platillo, cuenta (dueno o pareja) y porciones. Solo quien puede leer el menú compartido.';

-- -----------------------------------------------------------------------------
-- 2. Escritura: fija la porción de una persona para un platillo en todas sus entradas de la semana.
-- -----------------------------------------------------------------------------
create function public.ali_fijar_porcion(p_hogar_id uuid, p_platillo uuid, p_semana date, p_cuenta text, p_porciones numeric)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  if not public.ali_puede(p_hogar_id, 'pareja', 'menu', 'escribir') then
    raise exception using errcode = '42501', message = 'Solo dueño y pareja cambian las porciones del menú compartido.';
  end if;
  if p_cuenta is null or p_cuenta not in ('dueno', 'pareja') then
    raise exception using errcode = '22023', message = 'La porción es de dueno o de pareja.';
  end if;
  if p_porciones is null or p_porciones < 0.25 or p_porciones > 20 then
    raise exception using errcode = '22023', message = 'La porción va de 0.25 a 20.';
  end if;
  update public.ali_menu m
     set porciones_recomendadas = m.porciones_recomendadas || jsonb_build_object(p_cuenta, p_porciones),
         actualizado_por = public.persona_actual(),
         actualizado_en = now()
   where m.hogar_id = p_hogar_id
     and m.menu = 'pareja'
     and m.semana = p_semana
     and m.platillo_id = p_platillo;
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception using errcode = 'P0002', message = 'El platillo no está en el menú compartido de esa semana.';
  end if;
  return v_n;
end
$$;
comment on function public.ali_fijar_porcion(uuid, uuid, date, text, numeric) is
  'Fija la porción recomendada de dueno o pareja para un platillo del menú compartido de la semana (en todas sus entradas). Solo dueño y pareja; 0.25 a 20. Devuelve cuántas entradas cambió.';

-- -----------------------------------------------------------------------------
-- 3. Privilegios
-- -----------------------------------------------------------------------------
revoke all on function public.ali_porciones_recomendadas(uuid, date), public.ali_fijar_porcion(uuid, uuid, date, text, numeric)
  from public, anon, service_role;
grant execute on function public.ali_porciones_recomendadas(uuid, date), public.ali_fijar_porcion(uuid, uuid, date, text, numeric)
  to authenticated;
