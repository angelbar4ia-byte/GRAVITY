-- =============================================================================
-- GRAVITY · Fase 5 · Cuidados: pendientes de la app (21/nov/2026)
-- =============================================================================
-- 1. Cron de tomas: cui_generar_tomas_todas() recorre los hogares con medicamentos activos y genera las tomas de hoy y
--    mañana (zona de cada hogar). Se programa con pg_cron una vez al día SI la extensión existe (si no, no falla), como
--    fin_vistas_vencer. Solo servidor (service_role / pg_cron). Sin secretos.
-- 2. Posponer toma: cui_posponer_toma(toma) la pasa a la siguiente persona de turno. Solo quien estaba de turno a la hora de
--    la toma (o a quien ya se la pasaron). Una toma ya marcada no se pospone (55000). Auditoría: cuidados.toma_pospuesta,
--    sin texto clínico. Quien la recibe puede marcarla; quien la pasó ya no.
-- 3. cui_cambios_urgentes.atendido_por: quién lo atendió (lo pone el servidor en cui_atender_cambio_urgente).
-- 4. Citas: tabla cui_citas (solo agregar) con las mismas reglas de lectura y escritura que la bitácora de notas.
--    Las citas existentes en la bitácora: cui_bitacora.tipo solo admite 'nota' e 'instruccion', así que no hay filas tipo
--    'cita' que migrar. Si la app guardó citas como nota con prefijo "[cita ", NO se migran automáticamente (la nota no
--    separa fecha, lugar y texto con seguridad): la app o el dueño las repasa y vuelve a crear las que quiera con la tabla nueva.
-- Migración hacia adelante; no edita las anteriores.
-- =============================================================================

-- 1. Cron de tomas -----------------------------------------------------------------------------------------------------
create function public.cui_generar_tomas_todas(p_dias integer default 2)
returns integer
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_h uuid;
  v_n integer := 0;
begin
  if auth.uid() is not null then
    raise exception using errcode = '42501', message = 'Solo el servidor genera las tomas de todos los hogares.';
  end if;
  if p_dias is null or p_dias not between 1 and 14 then
    raise exception using errcode = '22023', message = 'Genera de 1 a 14 días a la vez.';
  end if;
  for v_h in select distinct m.hogar_id from public.cui_medicamentos m where m.activo loop
    v_n := v_n + public.cui_generar_tomas(v_h, (now() at time zone public.cui_zona(v_h))::date, p_dias);
  end loop;
  return v_n;
end
$$;
comment on function public.cui_generar_tomas_todas(integer) is
  'Genera las tomas pendientes de hoy (zona de cada hogar) y los días siguientes para todos los hogares con medicamentos activos. '
  'Idempotente. Solo servidor (pg_cron diario). Devuelve cuántas creó.';
revoke all on function public.cui_generar_tomas_todas(integer) from public, anon, authenticated;
grant execute on function public.cui_generar_tomas_todas(integer) to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- 10:00 UTC = 4:00 en la Ciudad de México: las tomas del día ya existen antes de que empiece el turno.
    perform cron.schedule('cui-generar-tomas', '0 10 * * *', 'select public.cui_generar_tomas_todas()');
  end if;
end
$$;

-- 2. Posponer toma -----------------------------------------------------------------------------------------------------
alter table public.cui_tomas
  add column pospuesta_a uuid references public.personas (id),
  add column pospuesta_en timestamptz,
  add column pospuesta_turno_en timestamptz,
  add constraint cui_tomas_pospuesta check ((pospuesta_a is null) = (pospuesta_en is null and pospuesta_turno_en is null));
comment on column public.cui_tomas.pospuesta_a is
  'A quién se pasó la toma al posponerla (siguiente persona de turno). Solo la pone cui_posponer_toma.';
comment on column public.cui_tomas.pospuesta_turno_en is 'Inicio del turno de pospuesta_a que se usó para elegirla.';

create or replace function public.cui_tomas_guardar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'estado' - 'marcada_por' - 'marcada_en' - 'pospuesta_a' - 'pospuesta_en' - 'pospuesta_turno_en')
     is distinct from
     (to_jsonb(old) - 'estado' - 'marcada_por' - 'marcada_en' - 'pospuesta_a' - 'pospuesta_en' - 'pospuesta_turno_en') then
    raise exception using errcode = '42501', message = 'Una toma solo cambia de estado y de a quién se pasa.';
  end if;
  return new;
end
$$;

-- Marcar: igual que v1.2, pero si la toma está pospuesta solo la marcan el dueño y a quien se la pasaron.
create or replace function public.cui_marcar_toma(p_toma_id uuid, p_estado text)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_t      public.cui_tomas%rowtype;
  v_perfil text;
  v_yo     uuid := public.persona_actual();
begin
  if p_estado is null or p_estado not in ('dado', 'no_dado') then
    raise exception using errcode = '22023', message = 'El estado de una toma es dado o no_dado.';
  end if;
  select * into v_t from public.cui_tomas t where t.id = p_toma_id;
  if found then
    v_perfil := public.cui_perfil(v_t.hogar_id);
  end if;
  if not found or v_perfil is null
     or not (v_perfil = 'dueno'
             or (v_perfil in ('cuidadora', 'hermana') and v_t.pospuesta_a = v_yo)
             or (v_perfil in ('cuidadora', 'hermana') and v_t.pospuesta_a is null
                 and exists (select 1 from public.cui_quien_en_turno(v_t.hogar_id, v_t.programada_para) q
                              where q.persona_id = v_yo
                                and q.tipo = case v_perfil when 'cuidadora' then 'cuidadora' else 'hermana_visita' end))) then
    raise exception using errcode = '42501', message = 'No puedes marcar esta toma.';
  end if;
  update public.cui_tomas t set estado = p_estado, marcada_por = v_yo, marcada_en = now() where t.id = v_t.id;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_t.hogar_id, v_yo, 'cuidados.toma_marcada', 'cui_tomas', v_t.id::text, jsonb_build_object('estado', p_estado));
end
$$;
comment on function public.cui_marcar_toma(uuid, text) is
  'Marca una toma como dado o no_dado. Dueño; cuidadora o hermana que estaban de turno (cuidadora / hermana_visita) a la hora '
  'programada o a quien se la pasaron al posponerla. Cada cambio queda en la bitácora (cuidados.toma_marcada, solo el estado).';

create function public.cui_posponer_toma(p_toma uuid)
returns uuid
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_t       public.cui_tomas%rowtype;
  v_perfil  text;
  v_yo      uuid := public.persona_actual();
  v_ref     timestamptz;
  v_zona    text;
  v_sig     uuid;
  v_sig_ts  timestamptz;
begin
  select * into v_t from public.cui_tomas t where t.id = p_toma;
  if found then
    v_perfil := public.cui_perfil(v_t.hogar_id);
  end if;
  -- Mismo 42501 exista o no la toma: solo quien estaba de turno a la hora de la toma (o a quien ya se la pasaron).
  if not found or v_perfil is null or v_yo is null or v_perfil not in ('dueno', 'cuidadora', 'hermana')
     or not (case when v_t.pospuesta_a is not null then v_t.pospuesta_a = v_yo
                  else exists (select 1 from public.cui_quien_en_turno(v_t.hogar_id, v_t.programada_para) q
                                where q.persona_id = v_yo) end) then
    raise exception using errcode = '42501', message = 'No puedes posponer esta toma.';
  end if;
  if v_t.estado <> 'pendiente' then
    raise exception using errcode = '55000', message = 'La toma ya fue marcada.';
  end if;
  v_ref := coalesce(v_t.pospuesta_turno_en, v_t.programada_para);
  v_zona := public.cui_zona(v_t.hogar_id);
  -- Los cambios de turno ocurren en los límites de cui_turnos: se prueban los próximos 7 días.
  select c.ts, q.persona_id into v_sig_ts, v_sig
    from (select distinct ((d.dia + (b.min * interval '1 minute')) at time zone v_zona) as ts
            from generate_series(((v_ref at time zone v_zona)::date)::timestamp,
                                 ((v_ref at time zone v_zona)::date + 7)::timestamp, interval '1 day') as d (dia)
            cross join (select t.inicio_min as min from public.cui_turnos t where t.hogar_id = v_t.hogar_id
                        union select t.fin_min from public.cui_turnos t where t.hogar_id = v_t.hogar_id) b) c
    cross join lateral public.cui_quien_en_turno(v_t.hogar_id, c.ts) q
   where c.ts > v_ref and q.persona_id <> v_yo
   order by c.ts, q.tipo
   limit 1;
  if v_sig is null then
    raise exception using errcode = '22023', message = 'No hay a quién pasarle la toma.';
  end if;
  update public.cui_tomas t
     set pospuesta_a = v_sig, pospuesta_en = now(), pospuesta_turno_en = v_sig_ts
   where t.id = v_t.id;
  insert into public.bitacora (hogar_id, persona_id, accion, tabla, registro_id, detalle)
  values (v_t.hogar_id, v_yo, 'cuidados.toma_pospuesta', 'cui_tomas', v_t.id::text, '{}'::jsonb);
  return v_sig;
end
$$;
comment on function public.cui_posponer_toma(uuid) is
  'Pasa una toma pendiente a la siguiente persona de turno (cui_quien_en_turno en el próximo cambio de turno). Solo quien estaba '
  'de turno a la hora de la toma, o a quien ya se la pasaron. Devuelve la persona. Ya marcada: 55000; sin permiso: 42501. '
  'Auditoría sin datos clínicos.';
revoke all on function public.cui_posponer_toma(uuid) from public, anon;
grant execute on function public.cui_posponer_toma(uuid) to authenticated;

-- 3. Quién atendió el cambio urgente ----------------------------------------------------------------------------------
alter table public.cui_cambios_urgentes add column atendido_por uuid references public.personas (id);
comment on column public.cui_cambios_urgentes.atendido_por is 'Persona que lo atendió. La pone el servidor en cui_atender_cambio_urgente.';

create or replace function public.cui_cambios_guardar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (to_jsonb(new) - 'atendido_en' - 'atendido_por') is distinct from (to_jsonb(old) - 'atendido_en' - 'atendido_por')
     or old.atendido_en is not null then
    raise exception using errcode = '42501', message = 'Un cambio urgente solo se marca como atendido, una vez.';
  end if;
  return new;
end
$$;

create or replace function public.cui_atender_cambio_urgente(p_id uuid)
returns void
language plpgsql volatile security definer
set search_path = ''
as $$
declare
  v_c public.cui_cambios_urgentes%rowtype;
  v_p text;
begin
  select * into v_c from public.cui_cambios_urgentes c where c.id = p_id;
  if found then
    v_p := public.cui_perfil(v_c.hogar_id);
  end if;
  if not found or v_p is null or v_p in ('pareja', 'pareja_consentida')
     or not (v_p = 'dueno' or v_c.para_persona = public.persona_actual()
             or (v_c.para_persona is null and v_p in ('cuidadora', 'hermana'))) then
    raise exception using errcode = '42501', message = 'No puedes atender este cambio.';
  end if;
  if v_c.atendido_en is not null then
    return;
  end if;
  update public.cui_cambios_urgentes c set atendido_en = now(), atendido_por = public.persona_actual() where c.id = v_c.id;
  update public.avisos a set estado = 'resuelta', resuelta_en = now()
   where a.objeto_tipo = 'cambio_urgente' and a.objeto_id = v_c.id and a.persona_id = public.persona_actual()
     and a.estado not in ('cancelada', 'resuelta');
end
$$;
comment on function public.cui_atender_cambio_urgente(uuid) is
  'Marca el cambio como atendido, con quién lo atendió (atendido_por), y resuelve su aviso. Quien lo recibe, el dueño o, si nadie '
  'estaba de turno, una cuidadora u hermana.';

-- 4. Citas -------------------------------------------------------------------------------------------------------------
create table public.cui_citas (
  id            uuid primary key default gen_random_uuid(),
  hogar_id      uuid not null references public.hogares (id),
  persona_id    uuid not null references public.personas (id),
  programada_en timestamptz not null,
  lugar         text check (char_length(btrim(lugar)) between 1 and 120),
  nota          text check (char_length(btrim(nota)) between 1 and 500),
  creada_en     timestamptz not null default now()
);
create index cui_citas_hogar_idx on public.cui_citas (hogar_id, programada_en desc);
comment on table public.cui_citas is
  'Citas de Papá (médicas y otras): DATO CLÍNICO (D3). SOLO AGREGAR; la corrección es una fila nueva. Mismas reglas de lectura y '
  'escritura que las notas de la bitácora de cuidados.';
alter table public.cui_citas enable row level security;

create function public.cui_citas_propio()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_n bigint;
begin
  new.persona_id := coalesce(public.persona_actual(), new.persona_id);
  new.creada_en := now();
  select count(*) into v_n from public.cui_citas c where c.persona_id = new.persona_id and c.creada_en > now() - interval '24 hours';
  if v_n >= 300 then
    raise exception using errcode = '54000', message = 'Demasiados registros en 24 horas.';
  end if;
  return new;
end
$$;
create trigger cui_a_propio before insert on public.cui_citas
  for each row execute function public.cui_citas_propio();
create trigger cui_c_solo_agregar before update or delete on public.cui_citas
  for each row execute function public.impedir_cambios_solo_agregar();
create trigger cui_c_sin_truncar before truncate on public.cui_citas
  for each statement execute function public.impedir_cambios_solo_agregar();

create policy cui_citas_leer on public.cui_citas for select to authenticated
  using (public.cui_puede(hogar_id, 'bitacora', 'leer')
         and (public.cui_perfil(hogar_id) <> 'cuidadora'
              or persona_id = (select public.persona_actual())
              or public.cui_autor_visible_cuidadora(hogar_id, persona_id)));
create policy cui_citas_agregar on public.cui_citas for insert to authenticated
  with check (public.cui_puede(hogar_id, 'bitacora', 'escribir'));

revoke all on table public.cui_citas from public, anon, authenticated, service_role;
grant select on public.cui_citas to authenticated, service_role;
grant insert (id, hogar_id, programada_en, lugar, nota) on public.cui_citas to authenticated;
revoke execute on function public.cui_citas_propio() from public, anon, authenticated, service_role;
