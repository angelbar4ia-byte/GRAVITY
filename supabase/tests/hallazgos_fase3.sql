-- Hallazgos ABIERTOS de la revisión de la Fase 3 (docs/revisiones/fase-3.md). ABIERTO = el defecto existe.
-- Uso: psql -f hallazgos_fase3.sql contra un clúster con migraciones y seed (correr.sh con GRAVITY_PG_MANTENER=1).
begin;
create temporary table hallazgos (clave text primary key, abierto boolean, nota text) on commit drop;
grant select, insert on hallazgos to authenticated, anon, service_role;
create function pg_temp.intento(p_clave text, p_preparacion text, p_ataque text)
returns void language plpgsql as $$
declare v_abierto boolean := false; v_detalle text; v_error text;
begin
  begin
    begin
      if p_preparacion is not null then execute p_preparacion; end if;
      execute 'select ' || p_ataque into v_abierto;
    exception when sqlstate 'ZZ001' then raise;
              when others then
      v_abierto := false; v_error := sqlstate || ' ' || sqlerrm;
    end;
    raise exception using errcode = 'ZZ001', message = 'fin del intento', detail = coalesce(v_abierto, false)::text || '|' || coalesce(v_error,'');
  exception when sqlstate 'ZZ001' then
    get stacked diagnostics v_detalle = pg_exception_detail;
  end;
  insert into hallazgos values (p_clave, split_part(v_detalle,'|',1)::boolean, nullif(split_part(v_detalle,'|',2),''));
end $$;
\o /dev/null
select pg_temp.intento('F3-2 [DEFECTO si la nota dice 22023] segunda subida con salto de revisión 1 a 3',
 $$select pruebas.como('ana@ejemplo.test');
   select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id','f5600000-0000-4000-8000-0000000000aa','tipo','diario_oracion','revision',1,'llave_version',1,'cifrado','AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')))$$,
 $$(select public.hab_subir_sobres(jsonb_build_array(jsonb_build_object('id','f5600000-0000-4000-8000-0000000000aa','tipo','diario_oracion','revision',3,'llave_version',1,'cifrado','BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB')))) is null$$);
select pg_temp.intento('F3-3 [DEFECTO si la nota dice 23514] hab_guardar_llave con el KDF del cliente', $$select pruebas.como('carla@ejemplo.test')$$,
 $$(select public.hab_guardar_llave(1,'pbkdf2-sha256','{"vueltas":600000}'::jsonb,'c2FsZGVzYWwxMjM0NTY','bGxhdmVlbnZ1ZWx0YTEyMzQ1Njc4OTA')) is null$$);
select pg_temp.intento('F3-4 la bitácora se llena sin tope con hab_borrar_mis_datos (600 llamadas)',
 $$select pruebas.como('carla@ejemplo.test'); select public.hab_borrar_mis_datos('sensibles') from generate_series(1,600)$$,
 $$(select count(*) from public.bitacora where accion='habitos.borrar_datos' and persona_id=pruebas.id_persona('carla@ejemplo.test')) > 500$$);
select pg_temp.intento('F3-5 hab_limpiar no borra a quien se dio de baja con activa=false y hasta nulo (a los 400 dias)',
 $$select pruebas.como_postgres();
   update public.membresias set desde = now() - interval '400 days', activa = false, hasta = null where persona_id = pruebas.id_persona('carla@ejemplo.test');
   select public.hab_limpiar()$$,
 $$exists (select 1 from public.hab_ajustes where persona_id = pruebas.id_persona('carla@ejemplo.test'))$$);
select pg_temp.intento('F3-5b ni a quien tiene activa=true y hasta vencido hace 91 dias',
 $$select pruebas.como_postgres();
   update public.membresias set desde = now() - interval '400 days', activa = true, hasta = now() - interval '91 days' where persona_id = pruebas.id_persona('carla@ejemplo.test');
   select public.hab_limpiar()$$,
 $$exists (select 1 from public.hab_ajustes where persona_id = pruebas.id_persona('carla@ejemplo.test'))$$);
select pg_temp.intento('F3-9 hab_hogar_de revela el hogar de cualquier persona (otro hogar)', $$select pruebas.como('elena@ejemplo.test')$$,
 $$public.hab_hogar_de(pruebas.id_persona('ana@ejemplo.test')) is not null$$);
select pg_temp.intento('F3-10 sin cuota de filas en las tablas en claro (3000 objetivos de 10 KB)', $$select pruebas.como('carla@ejemplo.test');
   insert into public.hab_objetivos(titulo,area,tipo,fecha_inicio,modificado_en,hitos) select 'x'||g,'salud','proyecto','2026-10-01',now(),(select jsonb_agg(repeat('z',50)) from generate_series(1,200)) from generate_series(1,3000) g$$,
 $$(select count(*) from public.hab_objetivos) >= 3000$$);
\o
select pruebas.como_postgres();
select clave, case when abierto then 'ABIERTO' else 'cerrado' end estado, nota from hallazgos order by clave;
rollback;
