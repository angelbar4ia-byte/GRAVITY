-- =============================================================================
-- GRAVITY · Fase 7 · Alimentación · avisos desde el servidor (D20, D28, spec 7 v1.1)
-- =============================================================================
-- Mismo patrón que Cuidados (20261113 y 20261124): catálogo cerrado, SIN texto libre ni cifras (D3, D20). El aviso solo
-- apunta al objeto (objeto_tipo + objeto_id); el texto genérico vive en el catálogo de la app. Nunca lleva montos, nombres
-- de platillos, de suplementos ni de personas.
--   - avisos.modulo admite 'alimentacion' (sin libro: avisos_modulo_libro sigue igual).
--   - avisos.tipo admite:
--       compra_papa_albacea    (importante)  una compra de Papá espera el pago del albacea.
--       votacion_abierta       (informativa) se abrió el plan familiar y toca votar.
--       votacion_empate        (informativa) el empate lo decidió el volado.
--       reposicion_suplemento  (importante)  un suplemento de Papá quedó sin confirmar: hay que reponerlo.
--   - avisos.objeto_tipo admite 'solicitud_pago', 'votacion' y 'reposicion' (conserva todos los previos).
--   - Severidad en avisos_severidad (conserva las de los tipos previos, incluido 'recordatorio_toma').
-- Quién recibe (calculado en el servidor, nunca la cuenta maestra, la cuidadora, Casa ni la persona bajo cuidado):
--   - compra de Papá: el albacea vigente del libro de Papá (el suplente solo si no hay albacea vigente), como en Finanzas.
--   - votación abierta y empate: quienes votan (dueño, pareja y familiar vigentes); la abierta no se la manda a quien propuso.
--   - reposición: quienes compran (dueño y pareja vigentes).
-- Se generan con triggers sobre las tablas de Alimentación, dentro de la misma transacción que la RPC: ali_marcar_comprada
-- (solicitud), ali_proponer_menu (votación), ali_cerrar_votaciones (volado) y ali_revisar_tomas (reposición). Claves estables
-- (única por persona y clave): no se repiten. Al resolverse el asunto, el aviso pendiente se cancela o se da por resuelto.
-- Migración hacia adelante. Sin secretos.
-- =============================================================================

alter table public.avisos drop constraint avisos_modulo_check;
alter table public.avisos add constraint avisos_modulo_check check (modulo in ('finanzas', 'sistema', 'cuidados', 'alimentacion'));

alter table public.avisos drop constraint avisos_tipo_check;
alter table public.avisos add constraint avisos_tipo_check check (tipo in (
  'pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
  'abono_bajo_minimo', 'partida_100', 'partida_80', 'ingreso_retrasado', 'fondo_bajo', 'uso_limite',
  'aportacion_pendiente', 'conciliacion_pendiente', 'salida_libro_representado',
  'retiro_bolsa_compartida', 'resumen_lunes', 'recordatorio_cierre', 'base_80', 'base_90',
  'solicitud_vista', 'cambio_urgente_cuidados', 'recordatorio_toma',
  'compra_papa_albacea', 'votacion_abierta', 'votacion_empate', 'reposicion_suplemento'));

alter table public.avisos drop constraint avisos_objeto_tipo_check;
alter table public.avisos add constraint avisos_objeto_tipo_check check (objeto_tipo in (
  'deuda', 'ocurrencia', 'partida', 'bolsa', 'semana', 'libro', 'movimiento', 'solicitud_vista', 'cambio_urgente', 'toma',
  'solicitud_pago', 'votacion', 'reposicion'));

create or replace function public.avisos_severidad(p_tipo text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_tipo in ('pago_proximo', 'limite_tarjeta', 'pago_vencido', 'protegido_riesgo', 'flujo_negativo',
                    'abono_bajo_minimo', 'base_90', 'solicitud_vista', 'cambio_urgente_cuidados') then 'critica'
    when p_tipo in ('partida_100', 'ingreso_retrasado', 'fondo_bajo', 'salida_libro_representado', 'base_80',
                    'recordatorio_toma', 'compra_papa_albacea', 'reposicion_suplemento')
      then 'importante'
    else 'informativa' end
$$;

-- Destinatarios --------------------------------------------------------------------------------------------------------
-- Albacea vigente del libro de Papá (o, sin albacea vigente, su suplente). Misma regla que fin_destinatarios_aviso.
create function public.ali_destinatarios_albacea(p_hogar_id uuid)
returns table (persona_id uuid)
language sql stable security definer
set search_path = ''
as $$
  with l as (select public.ali_libro_papa(p_hogar_id) as id),
  vig as (
    select m.persona_id, m.papel
      from public.fin_libro_miembros m join l on m.libro_id = l.id
     where m.papel in ('albacea', 'albacea_suplente') and m.desde <= now() and (m.hasta is null or m.hasta > now())
       and public.fin_destinatario_valido(p_hogar_id, m.persona_id))
  select v.persona_id from vig v where v.papel = 'albacea'
  union
  select v.persona_id from vig v where v.papel = 'albacea_suplente' and not exists (select 1 from vig a where a.papel = 'albacea')
$$;
comment on function public.ali_destinatarios_albacea(uuid) is
  'Interna. Albacea vigente del libro de Papá (el suplente solo sin albacea vigente), sin la cuenta maestra que no es dueña.';

-- Quienes votan (votaciones/votar) o compran (reposiciones/escribir) son dueño y pareja; votar suma al familiar.
-- La cuenta maestra (coadministrador con la marca) solo lee: nunca recibe.
create function public.ali_destinatarios_cuentas(p_hogar_id uuid, p_con_familiar boolean)
returns table (persona_id uuid)
language sql stable security definer
set search_path = ''
as $$
  select distinct m.persona_id
    from public.membresias m
   where m.hogar_id = p_hogar_id and m.activa and m.desde <= now() and (m.hasta is null or m.hasta > now())
     and (m.rol = 'dueno'
          or (m.rol = 'coadministrador' and not m.es_maestra)
          or (p_con_familiar and m.rol = 'familiar'))
$$;
comment on function public.ali_destinatarios_cuentas(uuid, boolean) is
  'Interna. Dueño y pareja vigentes (y el familiar si p_con_familiar). Nunca la maestra, la cuidadora ni Casa.';

-- Generadores ---------------------------------------------------------------------------------------------------------
create function public.ali_aviso_solicitud_pago()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in select d.persona_id from public.ali_destinatarios_albacea(new.hogar_id) d loop
    perform public.avisos_insertar(new.hogar_id, r.persona_id, 'alimentacion', 'compra_papa_albacea', null, 'solicitud_pago', new.id,
                                   'compra_papa:' || new.id::text, new.solicitada_en, new.solicitada_por, new.solicitada_en);
  end loop;
  return null;
end
$$;
create trigger ali_solicitudes_pago_avisar after insert on public.ali_solicitudes_pago
  for each row execute function public.ali_aviso_solicitud_pago();

create function public.ali_aviso_votacion_abierta()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in select d.persona_id from public.ali_destinatarios_cuentas(new.hogar_id, true) d
            where d.persona_id is distinct from new.creada_por loop
    perform public.avisos_insertar(new.hogar_id, r.persona_id, 'alimentacion', 'votacion_abierta', null, 'votacion', new.id,
                                   'votacion:' || new.id::text, new.creada_en, new.creada_por, new.creada_en);
  end loop;
  return null;
end
$$;
create trigger ali_votaciones_avisar_abierta after insert on public.ali_votaciones
  for each row execute function public.ali_aviso_votacion_abierta();

-- Cierre: el empate decidido por volado avisa a quienes votan; cerrar cancela el aviso de "votación abierta" que siga pendiente.
create function public.ali_aviso_votacion_cierre()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  r record;
begin
  update public.avisos a set estado = 'cancelada'
   where a.tipo = 'votacion_abierta' and a.objeto_id = new.id and a.estado in ('pendiente', 'agrupada', 'pospuesta');
  if new.ganadora_por_volado then
    for r in select d.persona_id from public.ali_destinatarios_cuentas(new.hogar_id, true) d loop
      perform public.avisos_insertar(new.hogar_id, r.persona_id, 'alimentacion', 'votacion_empate', null, 'votacion', new.id,
                                     'empate:' || new.id::text, coalesce(new.cerrada_en, now()), null, coalesce(new.cerrada_en, now()));
    end loop;
  end if;
  return null;
end
$$;
create trigger ali_votaciones_avisar_cierre after update of estado on public.ali_votaciones
  for each row when (old.estado is distinct from new.estado and new.estado = 'cerrada')
  execute function public.ali_aviso_votacion_cierre();

create function public.ali_aviso_reposicion()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  r record;
begin
  for r in select d.persona_id from public.ali_destinatarios_cuentas(new.hogar_id, false) d loop
    perform public.avisos_insertar(new.hogar_id, r.persona_id, 'alimentacion', 'reposicion_suplemento', null, 'reposicion', new.id,
                                   'reposicion:' || new.id::text, new.creada_en, null, new.creada_en);
  end loop;
  return null;
end
$$;
create trigger ali_reposiciones_avisar after insert on public.ali_reposiciones_suplemento
  for each row execute function public.ali_aviso_reposicion();

-- Resuelto el asunto, el aviso que sigue vivo se da por atendido.
create function public.ali_aviso_asunto_resuelto()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.avisos a set estado = 'resuelta', resuelta_en = now()
   where a.objeto_id = new.id and a.tipo = tg_argv[0]
     and a.estado in ('pendiente', 'enviada', 'agrupada', 'pospuesta', 'leida');
  return null;
end
$$;
create trigger ali_solicitudes_pago_resuelta after update of estado on public.ali_solicitudes_pago
  for each row when (old.estado = 'pendiente' and new.estado <> 'pendiente')
  execute function public.ali_aviso_asunto_resuelto('compra_papa_albacea');
create trigger ali_reposiciones_resuelta after update of estado on public.ali_reposiciones_suplemento
  for each row when (old.estado = 'pendiente' and new.estado <> 'pendiente')
  execute function public.ali_aviso_asunto_resuelto('reposicion_suplemento');

-- Privilegios: son internas; nadie las llama directo.
revoke all on function public.ali_destinatarios_albacea(uuid), public.ali_destinatarios_cuentas(uuid, boolean),
  public.ali_aviso_solicitud_pago(), public.ali_aviso_votacion_abierta(), public.ali_aviso_votacion_cierre(),
  public.ali_aviso_reposicion(), public.ali_aviso_asunto_resuelto() from public, anon, authenticated;
