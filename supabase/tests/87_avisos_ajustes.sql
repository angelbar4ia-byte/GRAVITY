-- Ajustes de avisos para plataforma (20261103): porcentaje de la base, recibe_avisos por token y clave de vencimientos.
begin;
select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.avisos_porcentaje_base() between 0 and 1000, 'La dueña ve el porcentaje de la base');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.avisos_porcentaje_base()$$, 'La pareja no', '42501');
select pruebas.como('marta@ejemplo.test');
select pruebas.falla($$select public.avisos_porcentaje_base()$$, 'La maestra no', '42501');
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$select public.avisos_porcentaje_base()$$, 'Una familiar no', '42501');
select pruebas.como_anon();
select pruebas.falla($$select public.avisos_porcentaje_base()$$, 'Sin sesión no', '42501');

-- UPDATE de recibe_avisos de SU dispositivo por token; nada más.
select pruebas.como('ana@ejemplo.test');
select public.registrar_dispositivo('tok-t', 'android', 'Tablet', 'tablet_personal');
select pruebas.igual(pruebas.afecta($$update public.dispositivos set recibe_avisos = true where token_avisos = 'tok-t'$$), 1, 'Ana prende su tablet por token');
select pruebas.falla($$update public.dispositivos set persona_id = pruebas.id_persona('alex@ejemplo.test') where token_avisos = 'tok-t'$$, 'No cambia de dueño', '42501');
select pruebas.falla($$update public.dispositivos set tipo = 'telefono' where token_avisos = 'tok-t'$$, 'ni el tipo', '42501');
select pruebas.falla($$update public.dispositivos set fallos = 0 where token_avisos = 'tok-t'$$, 'ni los fallos', '42501');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$update public.dispositivos set recibe_avisos = false where token_avisos = 'tok-t'$$), 0, 'Alex no toca el de Ana');

-- Clave de los avisos de vencimiento: n = días antes.
select pruebas.como('ana@ejemplo.test');
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada, monto_esperado)
values ('ee300000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', pruebas.libro_personal('ana@ejemplo.test'),
        'deuda', 'e5000000-0000-4000-8000-000000000002', '2026-11-12', '2026-11-12', 50000);
select pruebas.como_postgres();
select public.avisos_generar_vencimientos('2026-11-02 12:00-06');
select pruebas.igual((select string_agg(clave, ',' order by clave) from public.avisos where objeto_id = 'ee300000-0000-4000-8000-000000000001'),
  'pago_proximo:ee300000-0000-4000-8000-000000000001:2026-11-12:1,pago_proximo:ee300000-0000-4000-8000-000000000001:2026-11-12:3',
  'La clave es tipo:objeto_id:fecha_ajustada:n con n = días antes (3 y 1)');
rollback;
