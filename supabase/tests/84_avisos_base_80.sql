-- Aviso al 80 % de la base (criterio 48): con el tamaño simulado y el límite configurable.
begin;

select pruebas.como_postgres();
select pruebas.igual((select valor from public.avisos_sistema where clave = 'limite_base_bytes'), to_jsonb(524288000::bigint),
  'El límite por omisión es de 500 MB');

select pruebas.igual(public.avisos_revisar_base(412316860, '2027-11-02 12:00+00'), 0, 'Al 78.6 % no avisa');
select pruebas.igual(public.avisos_revisar_base(414000000, '2027-11-02 12:00+00'), 0, 'Al 79.0 % no avisa');
select pruebas.igual(public.avisos_revisar_base(419430400, '2027-11-02 12:00+00'), 2,
  'Al 80 % avisa a cada dueño (Ana y Elena, de su hogar)');
select pruebas.igual(
  (select string_agg(u.email || ':' || a.tipo || ':' || a.severidad, ',' order by u.email)
     from public.avisos a join public.personas p on p.id = a.persona_id join auth.users u on u.id = p.usuario_id
    where a.clave like 'base\_%'),
  'ana@ejemplo.test:base_80:importante,elena@ejemplo.test:base_80:importante',
  'Solo a los dueños (no a la pareja, ni a la maestra, ni a nadie más), importante');
select pruebas.igual((select modulo || ' ' || coalesce(libro_id::text, 'sin libro') from public.avisos
  where clave like 'base\_80%' limit 1), 'sistema sin libro', 'Es un aviso del sistema, sin libro');
select pruebas.igual(public.avisos_revisar_base(419430400, '2027-11-02 18:00+00'), 0, 'Uno al día como máximo');
select pruebas.igual(public.avisos_revisar_base(477000000, '2027-11-02 18:00+00'), 2, 'Al 90 % es otro aviso (crítico)');
select pruebas.igual((select count(*)::int from public.avisos where tipo = 'base_90' and severidad = 'critica'), 2, '… crítico');
select pruebas.igual(public.avisos_revisar_base(419430400, '2027-11-03 12:00+00'), 2, 'Al día siguiente, si sigue arriba, avisa otra vez');
-- 06:00 hora de México = 12:00 UTC: cae en horas silenciosas, así que el aviso sale a las 07:00.
select pruebas.igual((select to_char(enviar_en at time zone 'America/Mexico_City', 'HH24:MI')
  from public.avisos where clave = 'base_80:2027-11-02' and persona_id = pruebas.id_persona('ana@ejemplo.test')),
  '07:00', 'A las 06:00 hora de México sale a las 07:00 (silencio)');
-- Límite configurable.
update public.avisos_sistema set valor = to_jsonb(1000::bigint) where clave = 'limite_base_bytes';
select pruebas.igual(public.avisos_revisar_base(800, '2027-11-10 12:00+00'), 2, 'Con otro límite (1000 bytes) 800 es el 80 %');
update public.avisos_sistema set valor = to_jsonb(0::bigint) where clave = 'limite_base_bytes';
select pruebas.igual(public.avisos_revisar_base(800, '2027-11-11 12:00+00'), 0, 'Un límite en cero no avisa (y no divide entre cero)');
update public.avisos_sistema set valor = to_jsonb(524288000::bigint) where clave = 'limite_base_bytes';
select pruebas.ok(public.avisos_revisar_base() >= 0, 'Sin tamaño simulado lee pg_database_size sin error');

-- Un dueño dado de baja no recibe.
update public.membresias set activa = false, hasta = now() where persona_id = pruebas.id_persona('elena@ejemplo.test');
select pruebas.igual(public.avisos_revisar_base(419430400, '2027-11-20 12:00+00'), 1, 'Elena, de baja, ya no recibe: solo Ana');

select pruebas.como('ana@ejemplo.test');
select pruebas.ok(public.avisos_porcentaje_base() >= 0, 'El dueño ve el porcentaje de la base');
select pruebas.como('alex@ejemplo.test');
select pruebas.falla($$select public.avisos_porcentaje_base()$$, 'La pareja no', '42501');
select pruebas.como('ana@ejemplo.test');
-- La app no llama a estas funciones.
select pruebas.como('ana@ejemplo.test');
select pruebas.falla($$select public.avisos_revisar_base(1, now())$$, 'La app no ejecuta avisos_revisar_base', '42501');
select pruebas.falla($$select public.avisos_generar_vencimientos()$$, 'ni avisos_generar_vencimientos', '42501');
select pruebas.falla($$select public.avisos_limpiar()$$, 'ni avisos_limpiar', '42501');

rollback;
