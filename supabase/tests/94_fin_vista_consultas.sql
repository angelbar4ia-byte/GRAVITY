-- Cada consulta de la vista temporal de Papá queda en la bitácora, sin montos ni cuentas (D24, D19).
begin;
create temp table t_sol (id uuid) on commit drop;
grant all on t_sol to public;

select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_registrar_consulta_vista()$$, 'Sin vista vigente no se registra', '42501');
insert into t_sol select public.fin_pedir_vista_papa('Revisar las medicinas de Papá');
select pruebas.falla($$select public.fin_registrar_consulta_vista()$$, 'Pendiente tampoco', '42501');

select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol), 'autorizar');
select pruebas.falla($$select public.fin_registrar_consulta_vista()$$, 'El dueño no usa la RPC del familiar', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_registrar_consulta_vista()$$, 'La pareja tampoco', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_registrar_consulta_vista()$$, 'ni la cuidadora', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.fin_registrar_consulta_vista()$$, 'ni anon', '42501');

select pruebas.como('carla@ejemplo.test');
select public.fin_registrar_consulta_vista();
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'finanzas.consulta_vista'), 1, 'La familiar con vista vigente deja una entrada');
select pruebas.ok(exists (select 1 from public.bitacora where accion = 'finanzas.consulta_vista'
    and persona_id = pruebas.id_persona('carla@ejemplo.test') and registrado_en is not null), 'con quién y cuándo');
select pruebas.ok(not exists (select 1 from public.bitacora where accion = 'finanzas.consulta_vista'
    and detalle::text ~* 'monto|saldo|cuenta|motivo|medicinas'), 'sin montos, cuentas ni motivo');
select pruebas.como('carla@ejemplo.test');
select public.fin_registrar_consulta_vista();
select pruebas.como_postgres();
select pruebas.igual((select count(*)::int from public.bitacora where accion = 'finanzas.consulta_vista'), 2, 'Cada consulta queda en la bitácora, sin tope por minuto (D24)');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where accion = 'finanzas.consulta_vista'$$) >= 1, 'El dueño las lee');
rollback;
