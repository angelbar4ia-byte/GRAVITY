-- Patrimonio v1.1 (spec fase-8-patrimonio.md v1.1): la fecha de un objetivo es opcional y el rendimiento de una
-- inversión es obligatorio (puede ser 0). Las firmas de las RPC no cambian; solo las validaciones.

-- 1. Inversiones: rendimiento_pb obligatorio. No se inventa un valor para filas viejas: si existe alguna sin
--    rendimiento, la migración se detiene y pide capturarlo antes (nulo = sin dato ya no es válido).
do $$
begin
  if exists (select 1 from public.fin_inversiones where rendimiento_pb is null) then
    raise exception using errcode = '23502',
      message = 'Hay inversiones sin rendimiento: captura su rendimiento_pb (0 si no rinde) antes de aplicar Patrimonio v1.1.';
  end if;
end
$$;
alter table public.fin_inversiones alter column rendimiento_pb set not null;
comment on table public.fin_inversiones is
  'Inversión de una persona. rendimiento_pb (puntos base, obligatorio; 0 si no rinde) se muestra tal como se capturó; '
  'este bloque no lo calcula. origen: capturado (a mano) o verificado (leído del estado en PDF). Sin fecha de captura no '
  'es vigente. Escritura solo por RPC.';

create or replace function public.fin_inversion_guardar(
  p_id uuid, p_libro uuid, p_titular uuid, p_nombre text, p_saldo_centavos bigint, p_rendimiento_pb integer,
  p_origen text default 'capturado', p_fecha_captura date default null, p_activa boolean default true)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_libro public.fin_libros%rowtype;
  v_ex    public.fin_inversiones%rowtype;
begin
  v_libro := public.fin_patrimonio_autoriza(p_libro, p_id);
  if p_rendimiento_pb is null then
    raise exception using errcode = '22023', message = 'El rendimiento es obligatorio (0 si no rinde).';
  end if;
  select * into v_ex from public.fin_inversiones i where i.id = p_id;
  if found then
    if v_ex.libro_id <> p_libro then
      raise exception using errcode = '23505', message = 'Ese id ya es de otra inversión.';
    end if;
    update public.fin_inversiones i
       set titular_id = p_titular, nombre = btrim(p_nombre), saldo_centavos = p_saldo_centavos,
           rendimiento_pb = p_rendimiento_pb, origen = coalesce(p_origen, 'capturado'),
           fecha_captura = p_fecha_captura, activa = coalesce(p_activa, true)
     where i.id = p_id;
  else
    insert into public.fin_inversiones (id, hogar_id, libro_id, titular_id, nombre, saldo_centavos, rendimiento_pb,
                                        origen, fecha_captura, activa)
    values (p_id, v_libro.hogar_id, p_libro, p_titular, btrim(p_nombre), p_saldo_centavos, p_rendimiento_pb,
            coalesce(p_origen, 'capturado'), p_fecha_captura, coalesce(p_activa, true));
  end if;
  return p_id;
end
$$;
comment on function public.fin_inversion_guardar(uuid, uuid, uuid, text, bigint, integer, text, date, boolean) is
  'Crea o actualiza (idempotente por id) una inversión. p_rendimiento_pb obligatorio, en puntos base, tal como lo '
  'capturó la persona (0 si no rinde; nulo se rechaza con 22023; no se calcula). p_origen: capturado o verificado (leído '
  'del PDF; exige fecha de captura). Solo quien administra el libro. Una baja es p_activa = false.';

-- 2. Objetivos: fecha_meta opcional. Las filas existentes ya tienen fecha; la RPC no cambia (acepta nulo).
alter table public.fin_objetivos alter column fecha_meta drop not null;
comment on table public.fin_objetivos is
  'Meta de ahorro de una persona (su libro): monto y fecha opcional. bolsa_id = el apartado de ahorro que la alimenta '
  '(se LEE, no se copia). Escritura solo por RPC (fin_objetivo_guardar); una baja es activo = false.';

-- 3. Avance: con fecha calcula a_tiempo y el aporte necesario; sin fecha, solo semanas estimadas (a_tiempo y
--    aporte_necesario_semanal quedan nulos: no se marca "a tiempo" ni "no alcanza").
create or replace function public.fin_objetivo_avance(p_objetivo uuid, p_hoy date default current_date)
returns table (
  objetivo_id uuid, estado text, monto_meta_centavos bigint, ahorrado_centavos bigint, falta_centavos bigint,
  aporte_semanal_centavos bigint, ritmo_origen text, semanas_estimadas integer, fecha_estimada date,
  fecha_meta date, a_tiempo boolean, aporte_necesario_semanal_centavos bigint)
language plpgsql stable security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_o       public.fin_objetivos%rowtype;
  v_ahorro  bigint := 0;
  v_falta   bigint;
  v_aporte  bigint;
  v_origen  text;
  v_semanas integer;
  v_estado  text;
  v_fecha   date;
  v_necesario bigint;
  v_sem_meta integer;
begin
  select * into v_o from public.fin_objetivos o where o.id = p_objetivo;
  if not found or public.persona_actual() is null or not public.fin_puede(v_o.libro_id, 'leer') then
    raise exception using errcode = '42501', message = 'No puedes ver este objetivo.';
  end if;
  if v_o.bolsa_id is not null then
    select greatest(coalesce(s.saldo_centavos, 0), 0)::bigint into v_ahorro
      from public.fin_v_bolsa_saldo s where s.bolsa_id = v_o.bolsa_id and s.libro_id = v_o.libro_id;
    v_ahorro := coalesce(v_ahorro, 0);
    select b.aporte_fijo_centavos into v_aporte from public.fin_bolsas_ahorro b where b.id = v_o.bolsa_id;
    if v_aporte is not null and v_aporte > 0 then
      v_origen := 'aporte_fijo';
    else
      select (sum(x.aportado_centavos) / count(*))::bigint into v_aporte
        from (select a.aportado_centavos
                from public.fin_aportaciones_ahorro a
                join public.fin_semanas s on s.libro_id = a.libro_id and s.id = a.semana_id
               where a.bolsa_id = v_o.bolsa_id and a.estado = 'confirmada'
               order by s.semana_inicio desc limit 8) x;
      if v_aporte is not null and v_aporte > 0 then
        v_origen := 'promedio';
      else
        v_aporte := null;
      end if;
    end if;
  end if;
  v_falta := greatest(v_o.monto_meta_centavos - v_ahorro, 0);
  if v_falta = 0 then
    v_estado := 'cumplido';
    v_semanas := 0;
  elsif v_o.bolsa_id is null then
    v_estado := 'sin_apartado';
  elsif v_aporte is null then
    v_estado := 'falta_dato';
  else
    v_estado := 'ok';
    v_semanas := ((v_falta + v_aporte - 1) / v_aporte)::integer;
  end if;
  if v_semanas is not null then
    v_fecha := p_hoy + v_semanas * 7;
  end if;
  if v_falta > 0 and v_o.fecha_meta is not null then
    v_sem_meta := greatest(((v_o.fecha_meta - p_hoy) + 6) / 7, 1);
    v_necesario := (v_falta + v_sem_meta - 1) / v_sem_meta;
  elsif v_falta = 0 then
    v_necesario := 0;
  end if;
  return query select v_o.id, v_estado, v_o.monto_meta_centavos, v_ahorro, v_falta, v_aporte, v_origen, v_semanas,
                      v_fecha, v_o.fecha_meta, case when v_fecha is null or v_o.fecha_meta is null then null else v_fecha <= v_o.fecha_meta end,
                      v_necesario;
end
$$;
comment on function public.fin_objetivo_avance(uuid, date) is
  'Fase 8 bloque 3 (v1.1). Cuánto falta y en cuántas semanas se alcanza con el apartado de ahorro (se lee su saldo y su '
  'ritmo; nada se copia). Ritmo = aporte fijo del apartado o el promedio de sus últimas 8 aportaciones confirmadas. '
  'Estados: ok, cumplido, sin_apartado y falta_dato (no se estima). Con fecha_meta: a_tiempo y '
  'aporte_necesario_semanal (lo que haría falta cada semana hasta esa fecha). Sin fecha_meta: ambos nulos y solo se '
  'muestran las semanas estimadas. Lo lee quien puede leer el libro (fin_puede leer; la maestra con consulta vigente).';
