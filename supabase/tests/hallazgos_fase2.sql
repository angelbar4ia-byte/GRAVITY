-- Hallazgos ABIERTOS de la revisión de la Fase 2 (docs/revisiones/fase-2.md). ABIERTO = el defecto existe.
-- Uso: psql -f hallazgos_fase2.sql contra un clúster con migraciones y seed (ver correr.sh con GRAVITY_PG_MANTENER=1).
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
select pg_temp.intento('F2-1 push se apaga tras 5 errores y no se recupera al re-registrar',
 $$select pruebas.como_postgres();
   delete from public.avisos where persona_id=pruebas.id_persona('ana@ejemplo.test');
   select public.avisos_insertar(p.hogar_id,p.persona_id,'finanzas','fondo_bajo',pruebas.libro_personal('ana@ejemplo.test'),null,null,'k1',now()) from public.avisos_preferencias p where p.persona_id=pruebas.id_persona('ana@ejemplo.test');
   update public.dispositivos set recibe_avisos=true, fallos=0 where tipo='telefono' and persona_id=pruebas.id_persona('ana@ejemplo.test');
   select public.avisos_registrar_entrega((select id from public.avisos where clave='k1'), d.id, 'error', 'red') from public.dispositivos d, generate_series(1,5) where d.tipo='telefono' and d.persona_id=pruebas.id_persona('ana@ejemplo.test')$$,
 $$(select count(*) from public.dispositivos where tipo='telefono' and persona_id=pruebas.id_persona('ana@ejemplo.test') and not recibe_avisos) > 0$$);
select pg_temp.intento('F2-5 retiro hacia bolsa de otro libro',
 $$select pruebas.como_postgres()$$,
 $$(select pg_get_constraintdef(oid) from pg_constraint where conrelid='public.fin_retiros_ahorro'::regclass and contype='f' and conname like '%destino%') not like '%libro_id%'$$);
select pg_temp.intento('F2-4 silencio_desde = silencio_hasta aceptado',
 $$select pruebas.como('ana@ejemplo.test')$$,
 $$(select public.avisos_actualizar_preferencias(p_silencio_desde => '22:00', p_silencio_hasta => '22:00')) is null$$);
\o
select pruebas.como_postgres();
select clave, case when abierto then 'ABIERTO' else 'cerrado' end estado, nota from hallazgos order by clave;
rollback;
