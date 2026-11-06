-- Endurecimiento de Hábitos (revisión docs/revisiones/fase-3.md): F3-2 (en la 90), F3-3 alias, F3-4, F3-5, F3-9 y F3-10.
begin;
select pruebas.como('carla@ejemplo.test');

-- F3-3 (alias del KDF)
select public.hab_guardar_llave(1, 'pbkdf2-sha256', '{"vueltas": 600000}', 'c2FsZGVzYWwxMjM0NTY', 'bGxhdmVlbnZ1ZWx0YTEyMzQ1Njc4OTA');
select pruebas.igual((select kdf from public.hab_llaves), 'pbkdf2-sha256', 'Se acepta pbkdf2-sha256 como alias del KDF');

-- F3-4: la bitácora no se llena con las constancias
select public.hab_borrar_mis_datos('sensibles') from generate_series(1, 600);
select pruebas.igual(pruebas.cuenta($$select * from public.bitacora where accion = 'habitos.borrar_datos'$$), 1,
  'F3-4: 600 llamadas dejan una sola constancia por minuto');

-- F3-9
select pruebas.como('elena@ejemplo.test');
select pruebas.ok(public.hab_hogar_de(pruebas.id_persona('ana@ejemplo.test')) is null, 'F3-9: no revela el hogar de otra persona');
select pruebas.ok(public.hab_hogar_de(pruebas.id_persona('elena@ejemplo.test')) is not null, '… sí el propio');
select pruebas.como('alex@ejemplo.test');
select pruebas.ok(public.hab_hogar_de(pruebas.id_persona('carla@ejemplo.test')) is null, '… ni siquiera el de alguien de su mismo hogar');

-- F3-10: cuota de filas
select pruebas.como('carla@ejemplo.test');
select pruebas.falla($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  select 'x' || g, 'salud', 'construir', '2026-10-01', now() from generate_series(1, 2001) g$$,
  'F3-10: más de 2000 objetivos por persona se rechaza', '54000');
select pruebas.igual(pruebas.afecta($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  select 'y' || g, 'salud', 'construir', '2026-10-01', now() from generate_series(1, 1999) g$$), 1999, 'Hasta el tope sí entra (1 + 1999 = 2000)');
select pruebas.falla($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  values ('uno más', 'salud', 'construir', '2026-10-01', now())$$, 'El siguiente se rechaza', '54000');
select pruebas.como('alex@ejemplo.test');
select pruebas.igual(pruebas.afecta($$insert into public.hab_objetivos (titulo, area, tipo, fecha_inicio, modificado_en)
  values ('mío', 'salud', 'construir', '2026-10-01', now())$$), 1, 'El tope es por persona');

-- F3-5: la baja se cuenta desde desactivada_en
select pruebas.como_postgres();
select pruebas.nuevo_adulto('beto@ejemplo.test');
select pruebas.nuevo_adulto('caro@ejemplo.test');
update public.membresias set activa = false, hasta = null where persona_id = pruebas.id_persona('beto@ejemplo.test');
select pruebas.ok((select desactivada_en is not null from public.membresias where persona_id = pruebas.id_persona('beto@ejemplo.test')),
  'F3-5: al pasar activa a falso queda la fecha de baja');
select pruebas.igual(public.hab_limpiar(now() + interval '89 days'), 0, 'activa = false con hasta nulo: a los 89 días se conserva');
select pruebas.igual((select count(*)::int from public.hab_ajustes where persona_id = pruebas.id_persona('beto@ejemplo.test')), 1, 'Beto conserva sus ajustes');
select public.hab_limpiar(now() + interval '91 days');
select pruebas.igual((select count(*)::int from public.hab_ajustes where persona_id = pruebas.id_persona('beto@ejemplo.test')), 0, 'A los 91 días se borran');
update public.membresias set activa = true, hasta = now() - interval '91 days', desde = now() - interval '400 days' where persona_id = pruebas.id_persona('caro@ejemplo.test');
select pruebas.ok((select desactivada_en <= now() - interval '90 days' from public.membresias where persona_id = pruebas.id_persona('caro@ejemplo.test')),
  'F3-5b: con hasta vencido, la baja cuenta desde hasta');
select public.hab_limpiar();
select pruebas.igual((select count(*)::int from public.hab_ajustes where persona_id = pruebas.id_persona('caro@ejemplo.test')), 0,
  '… y se limpia a los 90 días de ese hasta');
select pruebas.ok((select count(*) from public.hab_ajustes where persona_id = pruebas.id_persona('ana@ejemplo.test')) = 1, 'Quien sigue en el hogar no se toca');
-- Volver al hogar quita la fecha de baja
update public.membresias set activa = true, hasta = null where persona_id = pruebas.id_persona('caro@ejemplo.test');
select pruebas.ok((select desactivada_en is null from public.membresias where persona_id = pruebas.id_persona('caro@ejemplo.test')), 'Al volver al hogar se borra la fecha de baja');
rollback;
