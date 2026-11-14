-- Vista temporal de Finanzas de Papá para el familiar (D24): pedir, autorizar 30 min, cancelar, vencer; bitácora sin montos.
begin;
select pruebas.nuevo_adulto('teo@ejemplo.test');   -- otro coadministrador

-- ---------------------------------------------------------------- sin autorización el familiar no lee nada de Papá (criterio 1)
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), false, 'Sin solicitud no hay vista vigente');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 0, 'La familiar no ve ni la portada del libro de Papá');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos$$), 0, 'ni sus movimientos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas$$) + pruebas.cuenta($$select * from public.fin_categorias$$), 0, 'ni cuentas ni categorías');
select pruebas.falla($$select public.fin_responder_vista(gen_random_uuid(), 'autorizar')$$, 'La familiar no se autoriza a sí misma', '42501');
select pruebas.falla($$select public.fin_pedir_vista_papa('  ')$$, 'El motivo en blanco no sirve', '22023');
select pruebas.falla($$select public.fin_pedir_vista_papa('ab' || chr(8203))$$, 'ni con 2 caracteres visibles', '22023');
select pruebas.falla($$insert into public.fin_vistas_solicitadas (hogar_id, solicitante_id, libro_persona_id, motivo, estado, autorizada_por, vigente_hasta)
  values ('b0000000-0000-4000-8000-000000000001', pruebas.id_persona('carla@ejemplo.test'), 'e0000000-0000-4000-8000-000000000001', 'Directo', 'autorizada',
          pruebas.id_persona('carla@ejemplo.test'), now() + interval '1 day')$$, 'Nadie escribe la tabla directo', '42501');

create temp table t_sol (id uuid) on commit drop;
grant all on t_sol to public;
insert into t_sol select public.fin_pedir_vista_papa('Revisar las medicinas de Papá');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_vistas_solicitadas where estado = 'pendiente'$$), 1, 'La familiar crea su solicitud pendiente y la ve');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 0, 'Pendiente no abre nada');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos$$), 0, '… ni los movimientos');
select pruebas.falla($$select public.fin_pedir_vista_papa('Otra vez, por favor')$$, 'Solo una solicitud pendiente a la vez', '22023');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos$$), 0, 'El aviso no es de la familiar');

-- ---------------------------------------------------------------- quien no es familiar no puede pedir
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.fin_pedir_vista_papa('Quiero ver todo')$$, 'La pareja no pide (ya tiene su acceso)', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_vistas_solicitadas$$), 0, 'y no ve solicitudes ajenas');
select pruebas.falla($$select public.fin_responder_vista((select id from t_sol), 'autorizar')$$, 'La pareja no autoriza (solo el dueño)', '42501');
select pruebas.como('diana@ejemplo.test');
select pruebas.falla($$select public.fin_pedir_vista_papa('Quiero ver todo')$$, 'La cuidadora no pide', '42501');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_vistas_solicitadas$$), 0, 'y no ve solicitudes');

-- ---------------------------------------------------------------- el dueño ve el aviso y la solicitud
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_vistas_solicitadas where estado = 'pendiente'$$), 1, 'El dueño ve la solicitud del hogar');
select pruebas.igual(pruebas.cuenta($$select * from public.avisos where tipo = 'solicitud_vista' and objeto_id = (select id from t_sol)$$), 1,
  'El dueño recibe un aviso del catálogo');
select pruebas.ok((select severidad = 'critica' and modulo = 'finanzas' and objeto_tipo = 'solicitud_vista' from public.avisos where tipo = 'solicitud_vista'),
  'El aviso es crítico y no lleva texto ni montos (solo tipo, libro y solicitud)');
select pruebas.falla($$select public.fin_responder_vista((select id from t_sol), 'borrar')$$, 'Acción desconocida', '22023');

-- ---------------------------------------------------------------- autorizar: 30 minutos exactos (criterio 2)
select public.fin_responder_vista((select id from t_sol), 'autorizar');
select pruebas.ok((select estado = 'autorizada' and autorizada_por = pruebas.id_persona('ana@ejemplo.test')
                          and vigente_hasta = now() + interval '30 minutes' from public.fin_vistas_solicitadas where id = (select id from t_sol)),
  'Autorizada por la dueña con vigente_hasta = ahora + 30 minutos exactos');
select pruebas.igual((select estado from public.avisos where tipo = 'solicitud_vista'), 'resuelta', 'El aviso del dueño queda resuelto');
select pruebas.falla($$select public.fin_responder_vista((select id from t_sol), 'rechazar')$$, 'Una autorizada ya no se rechaza', '22023');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), true, 'Con la vista autorizada, fin_vista_papa_vigente() es verdadera');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 1, 'La familiar ve el libro de Papá…');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_movimientos$$) >= 3, '… sus movimientos');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_cuentas$$) >= 3, '… sus cuentas');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_categorias$$) >= 1, '… y las categorías del hogar');
select pruebas.ok(pruebas.cuenta($$select * from public.fin_v_saldos$$) >= 1, '… y los saldos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros where tipo <> 'representado'$$), 0,
  'Solo el libro de Papá: ni los personales ni los compartidos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos where libro_origen_id is distinct from 'f1000000-0000-4000-8000-000000000002'
  and libro_destino_id is distinct from 'f1000000-0000-4000-8000-000000000002'$$), 0, 'ni movimientos de otros libros');
select pruebas.falla($$insert into public.fin_movimientos (id, hogar_id, tipo, fecha, cuenta_origen_id, cuenta_destino_id, monto_centavos, libro_origen_id,
  registrado_por, en_nombre_de, motivo) values (gen_random_uuid(), 'b0000000-0000-4000-8000-000000000001', 'gasto', current_date,
  'c6000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000005', 100, 'f1000000-0000-4000-8000-000000000002',
  pruebas.id_persona('carla@ejemplo.test'), 'e0000000-0000-4000-8000-000000000001', 'Intento de escribir')$$, 'La vista es solo lectura', '42501');
select pruebas.falla($$select public.fin_pedir_vista_papa('Otra solicitud mientras hay vista')$$, 'Con una vista vigente no se pide otra', '22023');

-- ---------------------------------------------------------------- vence: el servidor rechaza las lecturas
select pruebas.como_postgres();
update public.fin_vistas_solicitadas set vigente_hasta = now() - interval '1 second' where id = (select id from t_sol);
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), false, 'Al pasar vigente_hasta ya no hay vista vigente (aunque el estado no se haya marcado)');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 0, 'El servidor niega el libro');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_movimientos$$), 0, '… los movimientos');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_cuentas$$) + pruebas.cuenta($$select * from public.fin_categorias$$), 0, '… y las cuentas y categorías');
select pruebas.falla($$select public.fin_vistas_vencer()$$, 'La app no corre el vencimiento masivo', '42501');
select pruebas.como_servicio();
select pruebas.igual(public.fin_vistas_vencer(), 1, 'La tarea del servidor la marca vencida');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual((select estado from public.fin_vistas_solicitadas where id = (select id from t_sol)), 'vencida', 'Queda en estado vencida');
select public.fin_responder_vista((select id from t_sol), 'cancelar');
select pruebas.igual((select estado from public.fin_vistas_solicitadas where id = (select id from t_sol)), 'vencida', 'Cancelar una vencida no la cambia');
select pruebas.falla($$select public.fin_responder_vista((select id from t_sol), 'autorizar')$$, 'Una vencida no se autoriza', '22023');

-- ---------------------------------------------------------------- el dueño cancela antes de tiempo (criterio 4)
select pruebas.como('carla@ejemplo.test');
insert into t_sol select public.fin_pedir_vista_papa('Segunda revisión de gastos');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol order by ctid desc limit 1), 'autorizar');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 1, 'Autorizada de nuevo: ve el libro');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol order by ctid desc limit 1), 'cancelar');
select pruebas.igual((select estado from public.fin_vistas_solicitadas order by creado_en desc, ctid desc limit 1), 'cancelada', 'El dueño cancela la vista antes de que venza');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.fin_vista_papa_vigente(), false, 'Cancelada: ya no hay vista');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$) + pruebas.cuenta($$select * from public.fin_movimientos$$), 0, 'y el servidor corta la lectura al instante');
select pruebas.falla($$select public.fin_responder_vista((select id from public.fin_vistas_solicitadas limit 1), 'cancelar')$$, 'La familiar no cancela ni responde', '42501');

-- ---------------------------------------------------------------- rechazar
insert into t_sol select public.fin_pedir_vista_papa('Quiero ver la pensión');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol order by ctid desc limit 1), 'rechazar');
select pruebas.ok((select estado = 'rechazada' and vigente_hasta is null and autorizada_por is null from public.fin_vistas_solicitadas order by creado_en desc, ctid desc limit 1),
  'El dueño rechaza: sin autorización ni vigencia');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_libros$$), 0, 'Rechazada no abre nada');
insert into t_sol select public.fin_pedir_vista_papa('Otra más, de prueba');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol order by ctid desc limit 1), 'cancelar');
select pruebas.ok((select estado = 'cancelada' and vigente_hasta is null from public.fin_vistas_solicitadas order by creado_en desc, ctid desc limit 1),
  'El dueño también cancela una pendiente');
select pruebas.como('carla@ejemplo.test');
insert into t_sol select public.fin_pedir_vista_papa('Quinta solicitud del día');
select pruebas.como('ana@ejemplo.test');
select public.fin_responder_vista((select id from t_sol order by ctid desc limit 1), 'rechazar');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.fin_pedir_vista_papa('Sexta solicitud')$$, 'Tope de 5 solicitudes en 24 horas', '22023');

-- ---------------------------------------------------------------- las tablas no se tocan a mano
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$update public.fin_vistas_solicitadas set estado = 'autorizada', autorizada_por = pruebas.id_persona('ana@ejemplo.test'),
  vigente_hasta = now() + interval '1 day'$$, 'Ni el dueño cambia estados directo', '42501');
select pruebas.falla($$delete from public.fin_vistas_solicitadas$$, 'ni borra', '42501');
select pruebas.como_postgres();
select pruebas.falla($$delete from public.fin_vistas_solicitadas$$, 'Ni el dueño de la tabla borra solicitudes', '23514');
select pruebas.falla($$update public.fin_vistas_solicitadas set estado = 'pendiente' where estado = 'rechazada'$$, 'Un estado final no se reabre', '23514');
select pruebas.falla($$update public.fin_vistas_solicitadas set motivo = 'Cambiado después'$$, 'El motivo no se reescribe', '23514');

-- ---------------------------------------------------------------- anon y otros hogares
select pruebas.como_anon();
select pruebas.falla($$select * from public.fin_vistas_solicitadas$$, 'anon no lee la tabla', '42501');
select pruebas.falla($$select public.fin_vista_papa_vigente()$$, 'ni la vigencia', '42501');
select pruebas.falla($$select public.fin_pedir_vista_papa('anon intenta')$$, 'ni pide', '42501');
select pruebas.como('elena@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.fin_vistas_solicitadas$$), 0, 'Otro hogar no ve solicitudes');
select pruebas.falla($$select public.fin_responder_vista((select id from public.fin_vistas_solicitadas limit 1), 'autorizar')$$, 'ni responde', '42501');

-- ---------------------------------------------------------------- bitácora sin montos (criterio 5)
select pruebas.como_postgres();
select pruebas.ok((select count(*) from public.bitacora where tabla = 'fin_vistas_solicitadas') >= 10,
  'Cada solicitud y cada cambio de estado quedó en la bitácora');
select pruebas.ok(not exists (select 1 from public.bitacora where tabla = 'fin_vistas_solicitadas'
    and (detalle::text ~* 'monto|saldo|cuenta|motivo|medicinas|pensi' )), 'La bitácora no guarda montos, cuentas ni el motivo');
select pruebas.ok(exists (select 1 from public.bitacora b where b.tabla = 'fin_vistas_solicitadas' and b.accion = 'actualizar'
    and b.persona_id = pruebas.id_persona('ana@ejemplo.test') and b.detalle -> 'despues' ->> 'estado' = 'autorizada'
    and b.detalle -> 'despues' ->> 'vigente_hasta' is not null), 'Queda quién autorizó, cuándo y hasta cuándo');
select pruebas.ok(exists (select 1 from public.bitacora b where b.tabla = 'fin_vistas_solicitadas' and b.accion = 'actualizar'
    and b.persona_id is null and b.detalle -> 'despues' ->> 'estado' = 'vencida'), 'y el vencimiento (hecho por el servidor)');
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where tabla = 'fin_vistas_solicitadas'$$) >= 10, 'El dueño lee esa bitácora del hogar');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(pruebas.cuenta($$select * from public.bitacora where tabla = 'fin_vistas_solicitadas'$$) >= 1, 'La familiar lee lo que ella hizo');
select pruebas.como('diana@ejemplo.test');
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where tabla = 'fin_vistas_solicitadas'$$), 0, 'La cuidadora no lee nada de eso');
-- El tope de 500 entradas de la app no cuenta estas entradas (las escribe el servidor).
select pruebas.como_postgres();
select pruebas.ok(not exists (select 1 from public.bitacora where tabla = 'fin_vistas_solicitadas' and accion not in ('insertar', 'actualizar')),
  'Todas son entradas del servidor (no cuentan en el tope de 500)');
rollback;
