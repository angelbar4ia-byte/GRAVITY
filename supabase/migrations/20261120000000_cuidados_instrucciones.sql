-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados v1.4 (respuesta del dueño, 7/nov/2026; spec 5 §8f)
-- =============================================================================
-- Instrucciones para la cuidadora principal. El dueño, la hermana y la pareja pueden dejarlas; la cuidadora las ve.
-- 1. cui_bitacora.tipo ('nota' por omisión | 'instruccion'). La app no lo manda en el INSERT directo (el privilegio de
--    columnas sigue siendo id, hogar_id, nota): toda fila directa es 'nota'. Solo la RPC crea 'instruccion'.
-- 2. cui_dejar_instruccion(hogar, texto) → id. Dueño, hermana y pareja (con o sin consentimiento; no la cuenta maestra).
--    1 a 500 caracteres (22023). Quién la deja lo pone el servidor. Deja cuidados.instruccion_dejada en la bitácora de
--    auditoría SIN el texto (D3). La pareja sigue sin escribir directo en la tabla (cui_puede no cambia).
-- 3. Lectura de la cuidadora (política cui_bitacora_leer): lo suyo; lo de dueño y hermana (v1.1); y las INSTRUCCIONES de
--    la pareja. La pareja sin consentimiento no lee la bitácora, ni sus propias instrucciones; con consentimiento la lee
--    entera (v1.2). Las entregas de turno no cambian.
-- Migración hacia adelante; no edita las anteriores.
-- =============================================================================

alter table public.cui_bitacora
  add column tipo text not null default 'nota' check (tipo in ('nota', 'instruccion'));
comment on column public.cui_bitacora.tipo is
  'nota (bitácora del día a día) o instruccion (dueño, hermana o pareja para la cuidadora principal; solo la crea cui_dejar_instruccion).';

-- Ayudante: ¿es una instrucción de esta persona legible por la cuidadora? Dueño, hermana (turnos hermana_visita) o pareja
-- (coadministrador que no es la cuenta maestra).
create function public.cui_autor_pareja(p_hogar_id uuid, p_persona_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (select 1 from public.membresias m
                  where m.hogar_id = p_hogar_id and m.persona_id = p_persona_id
                    and m.rol = 'coadministrador' and not m.es_maestra)
$$;
comment on function public.cui_autor_pareja(uuid, uuid) is
  'Spec 5 §8f: ¿esta persona es la pareja (coadministrador que no es la cuenta maestra)? La cuidadora lee sus instrucciones.';
revoke all on function public.cui_autor_pareja(uuid, uuid) from public, anon;
grant execute on function public.cui_autor_pareja(uuid, uuid) to authenticated;

drop policy cui_bitacora_leer on public.cui_bitacora;
create policy cui_bitacora_leer on public.cui_bitacora for select to authenticated
  using (public.cui_puede(hogar_id, 'bitacora', 'leer')
         and (public.cui_perfil(hogar_id) <> 'cuidadora'
              or persona_id = (select public.persona_actual())
              or public.cui_autor_visible_cuidadora(hogar_id, persona_id)
              or (tipo = 'instruccion' and public.cui_autor_pareja(hogar_id, persona_id))));

create function public.cui_dejar_instruccion(p_hogar_id uuid, p_texto text)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_perfil text := public.cui_perfil(p_hogar_id);
  v_yo     uuid := public.persona_actual();
  v_id     uuid := gen_random_uuid();
begin
  if v_perfil is null or v_yo is null
     or v_perfil not in ('dueno', 'hermana', 'pareja', 'pareja_consentida')
     or (v_perfil in ('pareja', 'pareja_consentida') and not public.cui_autor_pareja(p_hogar_id, v_yo)) then
    raise exception using errcode = '42501', message = 'No puedes dejar instrucciones para la cuidadora.';
  end if;
  if p_texto is null or char_length(btrim(p_texto)) not between 1 and 500 then
    raise exception using errcode = '22023', message = 'La instrucción lleva de 1 a 500 caracteres.';
  end if;
  insert into public.cui_bitacora (id, hogar_id, persona_id, nota, tipo)
  values (v_id, p_hogar_id, v_yo, btrim(p_texto), 'instruccion');
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (p_hogar_id, v_yo, 'cuidados.instruccion_dejada', 'cui_bitacora', v_id::text, '{}'::jsonb);
  return v_id;
end
$$;
comment on function public.cui_dejar_instruccion(uuid, text) is
  'Deja una instrucción para la cuidadora principal (spec 5 §8f): dueño, hermana o pareja (con o sin consentimiento). 1 a 500 '
  'caracteres. La cuidadora la lee; la pareja solo si tiene consentimiento. La auditoría no lleva el texto.';
revoke all on function public.cui_dejar_instruccion(uuid, text) from public, anon;
grant execute on function public.cui_dejar_instruccion(uuid, text) to authenticated;
