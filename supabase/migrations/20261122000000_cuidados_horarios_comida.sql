-- Cuidados v1.6: horarios de comida editables por hogar.
-- 1. cui_horarios_comida(hogar_id, tiempo, hora): cuatro filas por hogar (desayuno 08:30, comida 14:00, colacion 17:00,
--    cena 19:00 por omisión). Se siembran al crear el hogar (trigger) y aquí para los hogares existentes, sin pisar nada.
-- 2. Lectura: dueño, pareja, cuidadora y hermana (quien ya ve Cuidados). La cuenta maestra y Casa no.
-- 3. Escritura: solo el dueño, por cui_fijar_horario_comida. El cambio queda en la bitácora de auditoría (tiempo y hora,
--    sin texto clínico).
-- 4. cui_horarios_hogar(hogar) devuelve los cuatro horarios en orden del día.

create table public.cui_horarios_comida (
  hogar_id uuid not null references public.hogares (id),
  tiempo   text not null check (tiempo in ('desayuno', 'comida', 'colacion', 'cena')),
  hora     time not null check (hora >= time '00:00' and hora <= time '23:59'),
  primary key (hogar_id, tiempo)
);
comment on table public.cui_horarios_comida is
  'Hora de cada tiempo de comida del hogar (la usan los recordatorios de comidas). Solo el dueño las cambia, con cui_fijar_horario_comida.';
alter table public.cui_horarios_comida enable row level security;

-- ¿Ve esta persona los horarios? Quien ve Cuidados, salvo la cuenta maestra (cui_perfil la cuenta como pareja).
create function public.cui_ve_horarios(p_hogar_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select public.cui_perfil(p_hogar_id) is not null
     and not exists (select 1 from public.membresias m
                      where m.hogar_id = p_hogar_id and m.persona_id = public.persona_actual() and m.es_maestra)
$$;
comment on function public.cui_ve_horarios(uuid) is
  'Dueño, pareja, cuidadora u hermana con perfil vigente en Cuidados; no la cuenta maestra, Casa ni otro hogar.';
revoke all on function public.cui_ve_horarios(uuid) from public, anon;
grant execute on function public.cui_ve_horarios(uuid) to authenticated;

create policy cui_horarios_leer on public.cui_horarios_comida for select to authenticated
  using ((select public.cui_ve_horarios(hogar_id)));

revoke all on table public.cui_horarios_comida from public, anon, authenticated, service_role;
grant select on public.cui_horarios_comida to authenticated, service_role;

-- Siembra: al crear el hogar y para los existentes (sin pisar lo que ya haya).
create function public.cui_sembrar_horarios()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.cui_horarios_comida (hogar_id, tiempo, hora)
  values (new.id, 'desayuno', '08:30'), (new.id, 'comida', '14:00'), (new.id, 'colacion', '17:00'), (new.id, 'cena', '19:00')
  on conflict (hogar_id, tiempo) do nothing;
  return new;
end
$$;
revoke all on function public.cui_sembrar_horarios() from public, anon, authenticated, service_role;
create trigger cui_sembrar_horarios after insert on public.hogares
  for each row execute function public.cui_sembrar_horarios();

insert into public.cui_horarios_comida (hogar_id, tiempo, hora)
select h.id, v.tiempo, v.hora
  from public.hogares h
 cross join (values ('desayuno', time '08:30'), ('comida', time '14:00'), ('colacion', time '17:00'), ('cena', time '19:00')) as v (tiempo, hora)
on conflict (hogar_id, tiempo) do nothing;

create function public.cui_fijar_horario_comida(p_hogar_id uuid, p_tiempo text, p_hora time)
returns time
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_antes time;
begin
  if public.persona_actual() is null or public.cui_perfil(p_hogar_id) is distinct from 'dueno' then
    raise exception using errcode = '42501', message = 'Solo el dueño cambia los horarios de comida.';
  end if;
  if p_tiempo is null or p_tiempo not in ('desayuno', 'comida', 'colacion', 'cena') then
    raise exception using errcode = '22023', message = 'Tiempo de comida desconocido.';
  end if;
  if p_hora is null or p_hora < time '00:00' or p_hora > time '23:59' then
    raise exception using errcode = '22023', message = 'La hora debe estar entre 00:00 y 23:59.';
  end if;
  select hora into v_antes from public.cui_horarios_comida where hogar_id = p_hogar_id and tiempo = p_tiempo;
  insert into public.cui_horarios_comida (hogar_id, tiempo, hora) values (p_hogar_id, p_tiempo, p_hora)
  on conflict (hogar_id, tiempo) do update set hora = excluded.hora;
  if v_antes is distinct from p_hora then
    insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
    values (p_hogar_id, public.persona_actual(), 'cuidados.horario_comida_cambiado', 'cui_horarios_comida',
            p_hogar_id::text || ':' || p_tiempo,
            jsonb_build_object('tiempo', p_tiempo, 'antes', v_antes, 'despues', p_hora));
  end if;
  return p_hora;
end
$$;
comment on function public.cui_fijar_horario_comida(uuid, text, time) is
  'Solo el dueño. Fija la hora de un tiempo de comida (00:00 a 23:59). Auditoría cuidados.horario_comida_cambiado con tiempo, antes y después; sin texto clínico.';
revoke all on function public.cui_fijar_horario_comida(uuid, text, time) from public, anon;
grant execute on function public.cui_fijar_horario_comida(uuid, text, time) to authenticated;

create function public.cui_horarios_hogar(p_hogar_id uuid)
returns table (tiempo text, hora time)
language sql stable security invoker
set search_path = ''
as $$
  select h.tiempo, h.hora from public.cui_horarios_comida h
   where h.hogar_id = p_hogar_id
   order by case h.tiempo when 'desayuno' then 1 when 'comida' then 2 when 'colacion' then 3 else 4 end
$$;
comment on function public.cui_horarios_hogar(uuid) is
  'Los cuatro horarios de comida del hogar, en orden del día. Los lee quien ve Cuidados (la RLS de la tabla decide).';
revoke all on function public.cui_horarios_hogar(uuid) from public, anon;
grant execute on function public.cui_horarios_hogar(uuid) to authenticated;
