-- Alimentación, Fase 7 v1.1 (5a): empate por volado, cambio de voto mientras esté abierta y "¿hay presupuesto?" solo sí o no.
begin;
-- Fixtures (postgres). Platillos del seed a1000000-...01 y ...02. Ana dueña y albacea de Papá, Alex pareja, Carla familiar, Diana cuidadora,
-- Casa, Marta maestra, Elena otro hogar.
-- ---------------------------------------------------------------- volado
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Cena A', array['a1000000-0000-4000-8000-000000000001']::uuid[]) is not null, 'Carla propone');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.ali_proponer_alternativa((select id from public.ali_votaciones), 'Cena B', array['a1000000-0000-4000-8000-000000000002']::uuid[]) is not null, 'Alex da la alternativa');
-- Cambio de voto con la votación abierta, sin empate de por medio.
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena A')), 'abierta', 'Alex vota por A');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena B')), 'abierta', 'y CAMBIA a B mientras está abierta');
select pruebas.ok((select opcion_id = (select id from public.ali_votacion_opciones where titulo = 'Cena B') and cambios = 1
                     from public.ali_votos where persona_id = pruebas.id_persona('alex@ejemplo.test')), 'El cambio quedó (una vez)');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena A')), 'abierta', 'Ana vota por A: 1 a 1 (empate)');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena B')), 'abierta', 'Con empate sigue pudiendo cambiar: B');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones where titulo = 'Cena A')), 'abierta', '… y de nuevo A (1 a 1)');
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(null), 1, 'Al vencer, el cierre procesa la votación');
select pruebas.como_postgres();
select pruebas.ok((select estado = 'cerrada' and ronda = 1 and ganadora_id is not null and ganadora_por_volado and cerrada_en is not null from public.ali_votaciones),
  'El empate 1 a 1 se resuelve por VOLADO: queda cerrada, con ganadora, sin reabrir, y marcada por volado');
select pruebas.ok((select ganadora_id in (select id from public.ali_votacion_opciones) from public.ali_votaciones), 'La ganadora es una de las propuestas');
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.ali_votar((select id from public.ali_votaciones), (select id from public.ali_votacion_opciones limit 1))$$, 'Cerrada, ya no se vota', '22023');
select pruebas.igual(public.ali_cerrar_votaciones('b0000000-0000-4000-8000-000000000001'), 0, 'No queda nada por reabrir ni cerrar');

-- Sin empate: gana la de más votos, sin volado. Quien cambió su voto antes del cierre cuenta con el nuevo.
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Comida A', array['a1000000-0000-4000-8000-000000000001']::uuid[]) is not null, 'Se abre otra votación');
select pruebas.como('carla@ejemplo.test');
select pruebas.ok(public.ali_proponer_alternativa((select id from public.ali_votaciones where titulo = 'Comida A'), 'Comida B', array['a1000000-0000-4000-8000-000000000002']::uuid[]) is not null, 'alternativa');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida A'), (select id from public.ali_votacion_opciones where titulo = 'Comida A')), 'abierta', 'Carla vota A');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida A'), (select id from public.ali_votacion_opciones where titulo = 'Comida B')), 'abierta', 'Alex vota B');
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida A'), (select id from public.ali_votacion_opciones where titulo = 'Comida B')), 'abierta', 'Ana vota B (B 2, A 1)');
select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.ali_votar((select id from public.ali_votaciones where titulo = 'Comida A'), (select id from public.ali_votacion_opciones where titulo = 'Comida B')), 'abierta', 'Carla cambia a B antes del cierre (B 3)');
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour' where titulo = 'Comida A';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 1, 'Cierra');
select pruebas.como_postgres();
select pruebas.ok((select ganadora_id = (select id from public.ali_votacion_opciones where titulo = 'Comida B') and not ganadora_por_volado from public.ali_votaciones where titulo = 'Comida A'),
  'Gana B por votos (cuenta el voto cambiado) y NO por volado');

-- Empate sin votos y una sola propuesta: la sola gana sin volado; 0 a 0 con dos propuestas va a volado.
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.ali_proponer_menu('b0000000-0000-4000-8000-000000000001', 'Sola', array['a1000000-0000-4000-8000-000000000001']::uuid[]) is not null, 'propuesta sola');
select pruebas.como_postgres();
update public.ali_votaciones set cierra_en = now() - interval '1 hour' where titulo = 'Sola';
select pruebas.como_servicio();
select pruebas.igual(public.ali_cerrar_votaciones(), 1, 'Cierra la sola');
select pruebas.como_postgres();
select pruebas.ok((select estado = 'cerrada' and not ganadora_por_volado from public.ali_votaciones where titulo = 'Sola'), 'Una sola propuesta gana sin volado');

-- El volado reparte (no favorece siempre a la misma): 40 votaciones empatadas 0 a 0 deben dar ambas ganadoras.
create temp table pruebas_volado (ganadora_orden smallint);
do $$
declare
  v_id uuid; v_o1 uuid; v_o2 uuid; v_g uuid;
begin
  for i in 1..40 loop
    insert into public.ali_votaciones (hogar_id, cuenta, titulo, creada_por)
      values ('b0000000-0000-4000-8000-000000000001', 'papa', 'Volado ' || i, pruebas.id_persona('ana@ejemplo.test')) returning id into v_id;
    insert into public.ali_votacion_opciones (hogar_id, votacion_id, orden, propuesto_por, titulo) values
      ('b0000000-0000-4000-8000-000000000001', v_id, 1, pruebas.id_persona('ana@ejemplo.test'), 'X') returning id into v_o1;
    insert into public.ali_votacion_opciones (hogar_id, votacion_id, orden, propuesto_por, titulo) values
      ('b0000000-0000-4000-8000-000000000001', v_id, 2, pruebas.id_persona('alex@ejemplo.test'), 'Y') returning id into v_o2;
    update public.ali_votaciones set cierra_en = now() - interval '1 hour' where id = v_id;
    perform public.ali_cerrar_votaciones('b0000000-0000-4000-8000-000000000001');
    select ganadora_id into v_g from public.ali_votaciones where id = v_id;
    insert into pruebas_volado values (case when v_g = v_o1 then 1 else 2 end);
  end loop;
end $$;
select pruebas.ok((select count(distinct ganadora_orden) = 2 from pruebas_volado), 'El volado es aleatorio: ambas propuestas ganan alguna vez en 40 empates');
select pruebas.ok((select count(*) = 40 from public.ali_votaciones where titulo like 'Volado %' and ganadora_por_volado and estado = 'cerrada'), 'Todos quedaron cerrados por volado, ninguno reabierto');

-- ---------------------------------------------------------------- ¿hay presupuesto? (solo sí o no)
-- Fixtures: semana activa de hoy con partida de Alimentación (cuenta de gasto c2000000-...01) en los tres libros.
select pruebas.como_postgres();
insert into public.fin_semanas (hogar_id, libro_id, semana_inicio, estado, ingreso, presupuesto, deuda_plan, remanente_plan, techo)
select 'b0000000-0000-4000-8000-000000000001', l.id, public.fin_lunes((now() at time zone 'America/Mexico_City')::date), 'activa', 100000, 50000, 0, 50000, 100000
  from public.fin_libros l where l.hogar_id = 'b0000000-0000-4000-8000-000000000001' and l.activo
   and (l.id in ('f1000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002') or (l.tipo = 'personal' and l.titular_id = pruebas.id_persona('ana@ejemplo.test')))
on conflict (libro_id, semana_inicio) do update set estado = 'activa';
select pruebas.ok((select count(*) >= 3 from public.fin_semanas s where s.semana_inicio = public.fin_lunes((now() at time zone 'America/Mexico_City')::date)), 'Hay semanas activas de prueba');
insert into public.fin_sobres (hogar_id, libro_id, cuenta_gasto_id, nombre, monto_semanal_centavos)
select s.hogar_id, s.libro_id, 'c2000000-0000-4000-8000-000000000001', 'Despensa de prueba', 20000
  from public.fin_semanas s where s.semana_inicio = public.fin_lunes((now() at time zone 'America/Mexico_City')::date);
insert into public.fin_partidas_semana (hogar_id, libro_id, semana_id, origen, origen_id, cuenta_gasto_id, tipo, asignado, arrastre_recibido)
select s.hogar_id, s.libro_id, s.id, 'sobre', k.id, 'c2000000-0000-4000-8000-000000000001', 'variable',
       case when s.libro_id = 'f1000000-0000-4000-8000-000000000002' then 5000 else 20000 end, 1000
  from public.fin_semanas s join public.fin_sobres k on k.libro_id = s.libro_id and k.nombre = 'Despensa de prueba'
 where s.semana_inicio = public.fin_lunes((now() at time zone 'America/Mexico_City')::date);
insert into public.ali_ajustes (hogar_id, libro_casa_id) values ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001')
  on conflict (hogar_id) do update set libro_casa_id = excluded.libro_casa_id;

select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 21000), true, 'La dueña: sí hay (libro personal, justo el monto)');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 21001), false, '… y un centavo más, no');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 0), false, 'Monto cero: no');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', null), false, 'Monto nulo: no');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 21000, 'casa'), true, 'La casa: sí (libro compartido elegido)');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 6000, 'papa'), true, 'Papá: la albacea pregunta y sí hay');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 6001, 'papa'), false, '… y si no alcanza, no');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'otra'), false, 'Una cuenta que no existe: no');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000002', 100), false, 'Otro hogar ajeno: no');
select pruebas.igual(pg_typeof(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100))::text, 'boolean', 'La respuesta es un booleano, nada más');
select pruebas.ok((select count(*) = 1 from pg_proc p where p.proname = 'ali_hay_presupuesto' and p.prorettype = 'boolean'::regtype and not p.proretset),
  'La función devuelve solo boolean (no tabla ni json con cifras)');

-- El gasto de la semana descuenta.
select pruebas.como_postgres();
insert into public.fin_movimientos (hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id, monto_centavos, nota, registrado_por, realizado_por)
values ('b0000000-0000-4000-8000-000000000001', 'gasto', (now() at time zone 'America/Mexico_City')::date, now(),
        'c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 15000, 'prueba', pruebas.id_persona('ana@ejemplo.test'), pruebas.id_persona('ana@ejemplo.test'));
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 6000), true, 'Tras gastar 150.00 quedan 60.00 en su libro: sí');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 6001), false, '… y 60.01 ya no');

select pruebas.como('alex@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'papa'), false, 'La pareja no es la albacea: Papá responde no sin explicar');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'casa'), true, 'La pareja pregunta por la casa');

select pruebas.como('carla@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 21000), true, 'La familiar pregunta por la casa (sin cuenta indicada)');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'papa'), false, 'Para Papá, la familiar no (no es albacea)');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'personal'), false, 'ni por libros personales');

select pruebas.como('diana@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100), false, 'La cuidadora no: siempre no');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'casa'), false, '… ni por la casa');
select pruebas.como('casa@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'casa'), false, 'Casa no pregunta');
select pruebas.como('marta@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'casa'), false, 'La cuenta maestra no (solo lectura de precios)');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100, 'papa'), false, '… ni Papá');
select pruebas.como_anon();
select pruebas.falla($$select public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100)$$, 'Sin sesión no hay acceso', '42501');

-- No revela montos: ni el mensaje de error ni la respuesta dependen de cifras; sin libro/semana también es un no mudo.
select pruebas.como_postgres();
update public.fin_semanas set estado = 'por_cerrar' where semana_inicio = public.fin_lunes((now() at time zone 'America/Mexico_City')::date);
select pruebas.como('ana@ejemplo.test');
select pruebas.igual(public.ali_hay_presupuesto('b0000000-0000-4000-8000-000000000001', 100), false, 'Sin semana activa: no (sin decir por qué)');
rollback;
