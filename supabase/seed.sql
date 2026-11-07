-- =============================================================================
-- GRAVITY · Datos de ejemplo (SOLO desarrollo local y pruebas)
-- =============================================================================
-- Personas, hogares y dinero FICTICIOS. Nunca datos reales (van en
-- data/personal/, ignorada por git). NUNCA aplicar al proyecto real:
-- `supabase db push` no lo aplica (no uses --include-seed); `supabase db reset`
-- sí, solo en local.
--
-- Las cuentas NO tienen contraseña (encrypted_password vacío): nadie puede
-- entrar con ellas aunque este archivo llegara por error a un proyecto real.
-- Para entrar en Supabase local, ponles contraseña desde Studio
-- (Authentication › Users) o crea tus propias cuentas de prueba.
--
-- Correos en el dominio reservado .test (RFC 2606): no existen.
--
-- Hogar Ejemplo (b000…0001), el hogar de Ana y Alex del diseño de FINANZAS:
--   ana@ejemplo.test    Ana Ejemplo      dueno (albacea del libro de papá)
--   alex@ejemplo.test   Alex Ejemplo     coadministrador (pareja; suplente)
--   carla@ejemplo.test  Carla Ejemplo    familiar
--   diana@ejemplo.test  Diana Cuidadora  cuidador
--   casa@ejemplo.test   Hogar            casa (cuenta del equipo de las tablets; el
--                                        identificador sigue siendo "casa", D14)
--   marta@ejemplo.test  Marta Maestra    coadministrador con la CUENTA MAESTRA: otra
--                                        persona con su PROPIO login (D19, 23/oct), solo
--                                        lectura total en Finanzas y SIN libro propio
--   Papá (ejemplo)      persona bajo cuidado, SIN cuenta (e000…0001)
-- Libros de Finanzas (D19):
--   personal de Ana y de Alex (los crea el servidor al dar el rol; la maestra no lleva)
--   f100…0001  "Gastos de la casa"  compartido PRIVADO: Ana (administradora) y Alex
--   f100…0002  "Papá (ejemplo)"     representado: Ana albacea, Alex suplente
-- Hogar Vecino (b000…0002): para probar el aislamiento entre hogares.
--   elena@ejemplo.test  Elena Vecina     dueno
-- Sin hogar (para probar invitaciones):
--   nuevo@ejemplo.test  Nuevo Ejemplo
--
-- Los montos son inventados (inspirados en el ejemplo 5.6 bis del diseño).
-- =============================================================================

-- Cuentas (el trigger al_crear_usuario_crear_persona crea su persona).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
       u.correo, '', now(), '', '', '', '',
       '{"provider": "email", "providers": ["email"]}'::jsonb,
       jsonb_build_object('nombre', u.nombre), now(), now()
from (values
  ('a0000000-0000-4000-8000-000000000001', 'ana@ejemplo.test',   'Ana Ejemplo'),
  ('a0000000-0000-4000-8000-000000000002', 'alex@ejemplo.test',  'Alex Ejemplo'),
  ('a0000000-0000-4000-8000-000000000003', 'carla@ejemplo.test', 'Carla Ejemplo'),
  ('a0000000-0000-4000-8000-000000000004', 'diana@ejemplo.test', 'Diana Cuidadora'),
  ('a0000000-0000-4000-8000-000000000005', 'casa@ejemplo.test',  'Hogar'),
  ('a0000000-0000-4000-8000-000000000006', 'elena@ejemplo.test', 'Elena Vecina'),
  ('a0000000-0000-4000-8000-000000000007', 'nuevo@ejemplo.test', 'Nuevo Ejemplo'),
  ('a0000000-0000-4000-8000-000000000008', 'marta@ejemplo.test', 'Marta Maestra')
) as u (id, correo, nombre);

insert into public.hogares (id, nombre) values
  ('b0000000-0000-4000-8000-000000000001', 'Hogar Ejemplo'),
  ('b0000000-0000-4000-8000-000000000002', 'Hogar Vecino');

-- Al dar un rol con Finanzas (dueño, coadministrador) el servidor crea su
-- libro personal con sus cuentas de sistema (Ajustes, Apertura, Por clasificar);
-- a la cuenta maestra (coadministrador con es_maestra) no le crea ninguno.
insert into public.membresias (hogar_id, persona_id, rol, es_maestra)
select m.hogar::uuid, p.id, m.rol, m.maestra
from (values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'dueno',           false),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'coadministrador', false),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'familiar',        false),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004', 'cuidador',        false),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000005', 'casa',            false),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000008', 'coadministrador', true),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000006', 'dueno',           false)
) as m (hogar, usuario, rol, maestra)
join public.personas p on p.usuario_id = m.usuario::uuid;

-- Papá: persona bajo cuidado, sin cuenta (en la app se crea con
-- fin_crear_libro_representado()).
insert into public.personas (id, nombre_visible)
values ('e0000000-0000-4000-8000-000000000001', 'Papá (ejemplo)');

-- Invitación pendiente a nuevo@ejemplo.test como familiar. Token de ejemplo
-- (solo local): 'token-de-ejemplo-solo-local'. Se guarda solo su SHA-256.
insert into public.invitaciones (id, hogar_id, correo, rol, token_hash, expira_en, creada_por)
select 'd0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
       'nuevo@ejemplo.test', 'familiar',
       encode(sha256(convert_to('token-de-ejemplo-solo-local', 'UTF8')), 'hex'),
       now() + interval '7 days', p.id
from public.personas p
where p.usuario_id = 'a0000000-0000-4000-8000-000000000001';

-- Un dispositivo por persona con teléfono (tokens inventados).
insert into public.dispositivos (persona_id, plataforma, token_avisos, nombre)
select p.id, d.plataforma, d.token, d.nombre
from (values
  ('a0000000-0000-4000-8000-000000000001', 'windows', null,                         'Laptop (ejemplo)'),
  ('a0000000-0000-4000-8000-000000000001', 'android', 'token-fcm-de-ejemplo-ana',   'Teléfono de Ana (ejemplo)'),
  ('a0000000-0000-4000-8000-000000000004', 'android', 'token-fcm-de-ejemplo-diana', 'Teléfono de Diana (ejemplo)'),
  ('a0000000-0000-4000-8000-000000000005', 'android', 'token-fcm-de-ejemplo-casa',  'Tablet de la casa (ejemplo)')
) as d (usuario, plataforma, token, nombre)
join public.personas p on p.usuario_id = d.usuario::uuid;

-- Una entrada manual en la bitácora (las demás las crean los triggers).
insert into public.bitacora (hogar_id, persona_id, accion, detalle)
select 'b0000000-0000-4000-8000-000000000001', p.id, 'datos_de_ejemplo',
       '{"nota": "Datos ficticios cargados por seed.sql"}'::jsonb
from public.personas p
where p.usuario_id = 'a0000000-0000-4000-8000-000000000001';

-- =============================================================================
-- Finanzas (D19). Se cargan "como" la persona que lo haría en la app (su
-- sesión en request.jwt.claim.sub), así pasan por las mismas validaciones del
-- servidor y la bitácora dice quién. Ayudantes temporales (pg_temp: no quedan
-- en la base).
-- =============================================================================
create function pg_temp.como(p_usuario uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(p_usuario::text, ''), false)
$$;
create function pg_temp.persona(p_usuario uuid) returns uuid language sql as $$
  select p.id from public.personas p where p.usuario_id = p_usuario
$$;
create function pg_temp.libro_personal(p_usuario uuid) returns uuid language sql as $$
  select l.id from public.fin_libros l join public.personas p on p.id = l.titular_id
  where p.usuario_id = p_usuario and l.tipo = 'personal'
$$;
create function pg_temp.cuenta_sistema(p_libro uuid, p_tipo text) returns uuid language sql as $$
  select c.id from public.fin_cuentas c where c.libro_id = p_libro and c.tipo = p_tipo
$$;

-- ----------------------------------------------------------------- Ana (dueña)
select pg_temp.como('a0000000-0000-4000-8000-000000000001');

-- Libros compartido y representado; quien los crea queda como miembro o albacea.
-- "Gastos de la casa" es privado (por omisión): lo leen y escriben solo Ana (quien lo creó, su
-- administradora) y Alex; la cuenta maestra lo lee con consulta; el dueño solo lo ve por ser miembro.
insert into public.fin_libros (id, hogar_id, nombre, tipo, titular_id, visibilidad) values
  ('f1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'Gastos de la casa', 'compartido', null, 'privada'),
  ('f1000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   'Papá (ejemplo)', 'representado', 'e0000000-0000-4000-8000-000000000001', 'privada');
insert into public.fin_libro_miembros (hogar_id, libro_id, persona_id, papel) values
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001',
   pg_temp.persona('a0000000-0000-4000-8000-000000000002'), 'miembro'),
  ('b0000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002',
   pg_temp.persona('a0000000-0000-4000-8000-000000000002'), 'albacea_suplente');

-- Cuentas de gasto del HOGAR (árbol común) y categorías de 3 niveles.
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
select c.id::uuid, 'b0000000-0000-4000-8000-000000000001', null, c.nombre, c.tipo
from (values
  ('c2000000-0000-4000-8000-000000000001', 'Alimentación',           'de_gasto'),
  ('c2000000-0000-4000-8000-000000000002', 'Vivienda',               'de_gasto'),
  ('c2000000-0000-4000-8000-000000000003', 'Servicios',              'de_gasto'),
  ('c2000000-0000-4000-8000-000000000004', 'Transporte',             'de_gasto'),
  ('c2000000-0000-4000-8000-000000000005', 'Salud',                  'de_gasto'),
  ('c2000000-0000-4000-8000-000000000006', 'Limpieza',               'de_gasto'),
  ('c2000000-0000-4000-8000-000000000007', 'Cuidado personal',       'de_gasto'),
  ('c2000000-0000-4000-8000-000000000008', 'Entretenimiento',        'de_gasto'),
  ('c2000000-0000-4000-8000-000000000009', 'Vestimenta',             'de_gasto'),
  ('c2000000-0000-4000-8000-000000000010', 'Impuestos y trámites',   'de_gasto'),
  ('c2000000-0000-4000-8000-000000000011', 'Cuidados de Papá',       'de_gasto'),
  ('c2000000-0000-4000-8000-000000000012', 'Intereses y comisiones', 'gasto_financiero')
) as c (id, nombre, tipo);

insert into public.fin_categorias (id, hogar_id, padre_id, nivel, nombre, naturaleza, prioridad,
                                   protegida, es_del_sistema, posiblemente_deducible, cuenta_gasto_id)
select c.id::uuid, 'b0000000-0000-4000-8000-000000000001', c.padre::uuid, c.nivel, c.nombre, c.naturaleza,
       c.prioridad, c.protegida, true, c.deducible, c.cuenta::uuid
from (values
  ('c1000000-0000-4000-8000-000000000001', null,                                   1, 'Alimentación',          'variable', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000001'),
  ('c1000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 2, 'Súper',                 'variable', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000001'),
  ('c1000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000002', 3, 'Fruta y verdura',       'variable', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000001'),
  ('c1000000-0000-4000-8000-000000000004', null,                                   1, 'Vivienda',              'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000002'),
  ('c1000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000004', 2, 'Renta',                 'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000002'),
  ('c1000000-0000-4000-8000-000000000006', null,                                   1, 'Servicios',             'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000003'),
  ('c1000000-0000-4000-8000-000000000007', 'c1000000-0000-4000-8000-000000000006', 2, 'Luz',                   'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000003'),
  ('c1000000-0000-4000-8000-000000000008', 'c1000000-0000-4000-8000-000000000006', 2, 'Agua',                  'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000003'),
  ('c1000000-0000-4000-8000-000000000009', 'c1000000-0000-4000-8000-000000000006', 2, 'Internet',              'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000003'),
  ('c1000000-0000-4000-8000-000000000010', 'c1000000-0000-4000-8000-000000000006', 2, 'Celular',               'fija',     'necesario',    true,  false, 'c2000000-0000-4000-8000-000000000003'),
  ('c1000000-0000-4000-8000-000000000011', null,                                   1, 'Transporte',            'variable', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000004'),
  ('c1000000-0000-4000-8000-000000000012', null,                                   1, 'Salud',                 'variable', 'necesario',    false, true,  'c2000000-0000-4000-8000-000000000005'),
  ('c1000000-0000-4000-8000-000000000013', 'c1000000-0000-4000-8000-000000000012', 2, 'Medicinas',             'variable', 'necesario',    false, true,  'c2000000-0000-4000-8000-000000000005'),
  ('c1000000-0000-4000-8000-000000000014', null,                                   1, 'Limpieza',              'variable', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000006'),
  ('c1000000-0000-4000-8000-000000000015', null,                                   1, 'Cuidado personal',      'variable', 'deseable',     false, false, 'c2000000-0000-4000-8000-000000000007'),
  ('c1000000-0000-4000-8000-000000000016', null,                                   1, 'Entretenimiento',       'variable', 'discrecional', false, false, 'c2000000-0000-4000-8000-000000000008'),
  ('c1000000-0000-4000-8000-000000000017', null,                                   1, 'Vestimenta',            'mixta',    'deseable',     false, false, 'c2000000-0000-4000-8000-000000000009'),
  ('c1000000-0000-4000-8000-000000000018', null,                                   1, 'Impuestos y trámites',  'eventual', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000010'),
  ('c1000000-0000-4000-8000-000000000019', 'c1000000-0000-4000-8000-000000000018', 2, 'Placas y predial',      'eventual', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000010'),
  ('c1000000-0000-4000-8000-000000000020', null,                                   1, 'Cuidados de Papá',      'fija',     'necesario',    true,  true,  'c2000000-0000-4000-8000-000000000011'),
  ('c1000000-0000-4000-8000-000000000021', null,                                   1, 'Intereses y comisiones','variable', 'necesario',    false, false, 'c2000000-0000-4000-8000-000000000012')
) as c (id, padre, nivel, nombre, naturaleza, prioridad, protegida, deducible, cuenta);

update public.fin_cuentas c
   set categoria_id = k.id
  from public.fin_categorias k
 where k.cuenta_gasto_id = c.id and k.nivel = 1;

-- Cuentas de cada libro.
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo, limite_centavos)
select c.id::uuid, 'b0000000-0000-4000-8000-000000000001', c.libro, c.nombre, c.tipo, c.limite
from (values
  ('c3000000-0000-4000-8000-000000000001', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Banco de Ana',              'banco',          null::bigint),
  ('c3000000-0000-4000-8000-000000000002', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Efectivo de Ana',           'efectivo',       null),
  ('c3000000-0000-4000-8000-000000000003', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Tarjeta de crédito de Ana', 'tarjeta',        2000000),
  ('c3000000-0000-4000-8000-000000000004', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Préstamo de la tía',        'prestamo',       null),
  ('c3000000-0000-4000-8000-000000000005', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Sueldo de Ana',             'origen_ingreso', null),
  ('c3000000-0000-4000-8000-000000000006', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Extras',                    'origen_ingreso', null),
  ('c3000000-0000-4000-8000-000000000007', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Ahorro de Ana',             'ahorro',         null),
  ('c5000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001'::uuid,                    'Cuenta de la casa',         'banco',          null),
  ('c5000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001'::uuid,                    'Caja chica de la casa',     'efectivo',       null),
  ('c6000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000002'::uuid,                    'Cuenta de pensión',         'banco',          null),
  ('c6000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000002'::uuid,                    'Efectivo de Papá',          'efectivo',       null),
  ('c6000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000002'::uuid,                    'Pensión',                   'origen_ingreso', null),
  ('c6000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000002'::uuid,                    'Apoyo 60+',                 'origen_ingreso', null)
) as c (id, libro, nombre, tipo, limite);

-- Ingresos y sus vigencias. Papá: pensión los días 1 y 11 (siguiente día hábil)
-- y apoyo bimestral (D19, regla 6). Montos inventados.
insert into public.fin_ingresos (id, hogar_id, libro_id, persona_id, nombre, tipo,
                                 cuenta_origen_id, cuenta_destino_id, certeza) values
  ('e1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), pg_temp.persona('a0000000-0000-4000-8000-000000000001'),
   'Sueldo de Ana', 'salario', 'c3000000-0000-4000-8000-000000000005', 'c3000000-0000-4000-8000-000000000001', 'segura'),
  ('e1000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001',
   'f1000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000001',
   'Pensión', 'pension', 'c6000000-0000-4000-8000-000000000003', 'c6000000-0000-4000-8000-000000000001', 'segura'),
  ('e1000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001',
   'f1000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000001',
   'Apoyo 60+', 'otro', 'c6000000-0000-4000-8000-000000000004', 'c6000000-0000-4000-8000-000000000001', 'probable');

insert into public.fin_vigencias_ingreso (id, hogar_id, ingreso_id, monto_neto_centavos, forma, dias_mes,
                                          fecha_ancla, intervalo_meses, regla_inhabil, desde) values
  ('e2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001',
   900000, 'quincenal', '{15,0}', null, null, 'siguiente_dia_habil', '2026-01-01'),
  ('e2000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000003',
   350000, 'mensual', '{1,11}', null, null, 'siguiente_dia_habil', '2026-01-01'),
  ('e2000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000004',
   600000, 'cada_meses', null, '2026-09-01', 2, 'siguiente_dia_habil', '2026-01-01');

-- Compromisos: los de la casa en el compartido; el celular de Ana en su libro.
insert into public.fin_compromisos (id, hogar_id, libro_id, nombre, tipo, cuenta_gasto_id, categoria_id,
                                    monto_centavos, frecuencia, forma, dias_mes, fecha_ancla, intervalo_meses,
                                    protegida, prioridad, desde)
select c.id::uuid, 'b0000000-0000-4000-8000-000000000001', c.libro, c.nombre, c.tipo, c.cuenta::uuid, c.categoria::uuid,
       c.monto, c.frecuencia, c.forma, c.dias::smallint[], c.ancla::date, c.intervalo, c.protegida, 'necesario', '2026-01-01'
from (values
  ('e3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001'::uuid, 'Renta',            'fija',    'c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000005', 800000, 'mensual',   'mensual',    '{1}',  null,         null::smallint, true),
  ('e3000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001'::uuid, 'Luz',              'fija',    'c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000007',  90000, 'bimestral', 'cada_meses', null,   '2026-09-20', 2,              true),
  ('e3000000-0000-4000-8000-000000000003', 'f1000000-0000-4000-8000-000000000001'::uuid, 'Agua',             'fija',    'c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000008',  30000, 'mensual',   'mensual',    '{10}', null,         null,           true),
  ('e3000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000001'::uuid, 'Internet',         'fija',    'c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000009',  40000, 'mensual',   'mensual',    '{5}',  null,         null,           true),
  ('e3000000-0000-4000-8000-000000000005', 'f1000000-0000-4000-8000-000000000001'::uuid, 'Placas y predial', 'reserva', 'c2000000-0000-4000-8000-000000000010', 'c1000000-0000-4000-8000-000000000019', 156000, 'anual',     'cada_meses', null,   '2027-01-31', 12,             false),
  ('e3000000-0000-4000-8000-000000000006', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Celular de Ana', 'fija', 'c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000010', 35000, 'mensual', 'mensual', '{20}', null, null, true)
) as c (id, libro, nombre, tipo, cuenta, categoria, monto, frecuencia, forma, dias, ancla, intervalo, protegida);

-- Sobres (partidas variables) de cada libro.
insert into public.fin_sobres (id, hogar_id, libro_id, cuenta_gasto_id, nombre, monto_semanal_centavos,
                               protegida, prioridad, piso_minimo_centavos, modo_arrastre)
select s.id::uuid, 'b0000000-0000-4000-8000-000000000001', s.libro, s.cuenta::uuid, s.nombre, s.monto,
       s.protegida, s.prioridad, s.piso, s.modo
from (values
  ('e4000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000001', 'Alimentación',     150000, false, 'necesario',    100000, 'arrastrar'),
  ('e4000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000006', 'Limpieza',          15000, false, 'necesario',         0, 'arrastrar'),
  ('e4000000-0000-4000-8000-000000000003', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'c2000000-0000-4000-8000-000000000004', 'Transporte', 70000, false, 'necesario', 0, 'arrastrar'),
  ('e4000000-0000-4000-8000-000000000004', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'c2000000-0000-4000-8000-000000000005', 'Salud', 30000, false, 'necesario', 0, 'arrastrar'),
  ('e4000000-0000-4000-8000-000000000005', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'c2000000-0000-4000-8000-000000000007', 'Cuidado personal', 15000, false, 'deseable', 0, 'arrastrar'),
  ('e4000000-0000-4000-8000-000000000006', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'c2000000-0000-4000-8000-000000000008', 'Entretenimiento', 25000, false, 'discrecional', 0, 'al_remanente'),
  ('e4000000-0000-4000-8000-000000000007', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'c2000000-0000-4000-8000-000000000009', 'Vestimenta', 20000, false, 'deseable', 0, 'arrastrar'),
  ('e4000000-0000-4000-8000-000000000008', 'f1000000-0000-4000-8000-000000000002'::uuid, 'c2000000-0000-4000-8000-000000000005', 'Medicinas de Papá', 40000, true,  'necesario',     40000, 'arrastrar')
) as s (id, libro, cuenta, nombre, monto, protegida, prioridad, piso, modo);

-- Deudas de Ana: tarjeta (48 % anual) y préstamo de la tía, en su grupo prioritario.
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, cuenta_pasivo_id, abono_centavos, frecuencia,
                               forma, dias_mes, minimo_centavos, tasa_anual_pb, grupo_prioritario, orden_grupo) values
  ('e5000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Tarjeta de crédito', 'con_costo',
   'c3000000-0000-4000-8000-000000000003', 120000, 'mensual', 'mensual', '{28}', 45000, 4800, true, 1),
  ('e5000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Préstamo de la tía', 'familiar',
   'c3000000-0000-4000-8000-000000000004', 50000, 'mensual', 'mensual', '{15}', 0, 0, true, 2);

-- Días inhábiles del hogar (precarga de la LFT art. 74): uno revisado y activo, otro por revisar.
insert into public.fin_dias_inhabiles (id, hogar_id, fecha, nombre, tipo, fuente, activo) values
  ('ec000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', '2026-11-16',
   'Día de la Revolución', 'festivo_oficial', 'LFT art. 74, fracción VI', true),
  ('ec000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', '2026-12-25',
   'Navidad', 'festivo_oficial', 'LFT art. 74, fracción VIII', false);

-- Movimientos de Ana, del compartido y de Papá (Ana como albacea, en su nombre).
insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, categoria_id, en_nombre_de, nota, motivo)
select m.id::uuid, 'b0000000-0000-4000-8000-000000000001', m.tipo, m.fecha::date, m.registrado::timestamptz,
       m.origen, m.destino, m.monto, m.categoria::uuid, m.en_nombre::uuid, m.nota, m.motivo
from (values
  ('d1000000-0000-4000-8000-000000000001', 'apertura',      '2026-10-01', '2026-10-01 09:00-06', pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'apertura'), 'c3000000-0000-4000-8000-000000000001'::uuid, 1500000, null, null, 'Saldo inicial (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000002', 'apertura',      '2026-10-01', '2026-10-01 09:01-06', pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'apertura'), 'c3000000-0000-4000-8000-000000000002'::uuid,  200000, null, null, 'Saldo inicial (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000003', 'apertura',      '2026-10-01', '2026-10-01 09:02-06', 'c3000000-0000-4000-8000-000000000003'::uuid, pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'apertura'),  600000, null, null, 'Deuda inicial de la tarjeta (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000004', 'apertura',      '2026-10-01', '2026-10-01 09:03-06', 'c3000000-0000-4000-8000-000000000004'::uuid, pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'apertura'),  300000, null, null, 'Préstamo de la tía (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000005', 'gasto',         '2026-10-13', '2026-10-13 08:10-06', 'c3000000-0000-4000-8000-000000000002'::uuid, 'c2000000-0000-4000-8000-000000000004'::uuid,   4500, 'c1000000-0000-4000-8000-000000000011', null, 'Pasajes (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000006', 'gasto',         '2026-10-14', '2026-10-14 20:30-06', 'c3000000-0000-4000-8000-000000000003'::uuid, 'c2000000-0000-4000-8000-000000000008'::uuid,  25000, 'c1000000-0000-4000-8000-000000000016', null, 'Cine (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000007', 'ingreso',       '2026-10-15', '2026-10-15 10:00-06', 'c3000000-0000-4000-8000-000000000005'::uuid, 'c3000000-0000-4000-8000-000000000001'::uuid, 900000, null, null, 'Quincena (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000008', 'pago_deuda',    '2026-10-16', '2026-10-16 10:05-06', 'c3000000-0000-4000-8000-000000000001'::uuid, 'c3000000-0000-4000-8000-000000000003'::uuid, 120000, null, null, 'Abono a la tarjeta (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000009', 'transferencia', '2026-10-16', '2026-10-16 10:10-06', 'c3000000-0000-4000-8000-000000000001'::uuid, 'c5000000-0000-4000-8000-000000000001'::uuid, 500000, null, null, 'Aportación a la casa (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000010', 'gasto',         '2026-10-20', '2026-10-20 13:00-06', 'c3000000-0000-4000-8000-000000000002'::uuid, pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'por_clasificar'), 12000, null, null, 'Captura rápida (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000011', 'apertura',      '2026-10-01', '2026-10-01 09:10-06', pg_temp.cuenta_sistema('f1000000-0000-4000-8000-000000000001', 'apertura'), 'c5000000-0000-4000-8000-000000000001'::uuid, 1000000, null, null, 'Saldo inicial de la casa (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000012', 'gasto',         '2026-10-01', '2026-10-01 09:20-06', 'c5000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000002'::uuid, 800000, 'c1000000-0000-4000-8000-000000000005', null, 'Renta de octubre (ejemplo)', null),
  ('d1000000-0000-4000-8000-000000000015', 'apertura',      '2026-10-01', '2026-10-01 09:30-06', pg_temp.cuenta_sistema('f1000000-0000-4000-8000-000000000002', 'apertura'), 'c6000000-0000-4000-8000-000000000001'::uuid, 250000, null, 'e0000000-0000-4000-8000-000000000001', null, 'Saldo inicial de la cuenta de pensión (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000016', 'ingreso',       '2026-10-12', '2026-10-12 11:00-06', 'c6000000-0000-4000-8000-000000000003'::uuid, 'c6000000-0000-4000-8000-000000000001'::uuid, 350000, null, 'e0000000-0000-4000-8000-000000000001', null, 'Pensión del 11 de octubre, pagada el lunes (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000017', 'gasto',         '2026-10-14', '2026-10-14 12:00-06', 'c6000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000005'::uuid,  40000, 'c1000000-0000-4000-8000-000000000013', 'e0000000-0000-4000-8000-000000000001', 'Farmacia', 'Medicinas de Papá (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000020', 'ajuste',        '2026-10-20', '2026-10-20 21:00-06', 'c3000000-0000-4000-8000-000000000002'::uuid, pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'ajustes'), 500, null, null, null, 'Diferencia al contar el efectivo (ejemplo)')
) as m (id, tipo, fecha, registrado, origen, destino, monto, categoria, en_nombre, nota, motivo);

-- Conciliación del efectivo de Ana con su ajuste (diferencia de −$5.00).
insert into public.fin_conciliaciones (id, hogar_id, cuenta_id, fecha, saldo_declarado, saldo_calculado,
                                       ajuste_movimiento_id, motivo) values
  ('eb000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'c3000000-0000-4000-8000-000000000002', '2026-10-20', 183000, 183500,
   'd1000000-0000-4000-8000-000000000020', 'Diferencia al contar el efectivo (ejemplo)');

-- Plan de Ana: semana del 12/oct (se cierra abajo) y del 19/oct (activa).
-- Cascada: ingreso 4,153.85 − presupuesto 1,680.77 − deuda 392.31 = 2,080.77.
insert into public.fin_semanas (id, hogar_id, libro_id, semana_inicio, estado, ingreso, presupuesto, deuda_plan,
                                remanente_plan, meta_remanente_pb, ahorro_minimo_con_deuda_pb, techo)
select s.id::uuid, 'b0000000-0000-4000-8000-000000000001', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'),
       s.inicio::date, 'activa', 415385, 168077, 39231, 208077, 2000, 0, 293077
from (values ('e6000000-0000-4000-8000-000000000001', '2026-10-12'),
             ('e6000000-0000-4000-8000-000000000002', '2026-10-19')) as s (id, inicio);

insert into public.fin_partidas_semana (id, hogar_id, semana_id, origen, origen_id, cuenta_gasto_id, tipo, asignado,
                                        prioridad, modo_arrastre, protegida)
select (left(p.id, 35) || s.n)::uuid, 'b0000000-0000-4000-8000-000000000001', s.semana::uuid, p.origen, p.origen_id::uuid,
       p.cuenta::uuid, p.tipo, p.asignado, p.prioridad, p.modo, p.protegida
from (values ('e6000000-0000-4000-8000-000000000001', '1'),
             ('e6000000-0000-4000-8000-000000000002', '2')) as s (semana, n),
     (values
  ('e7000000-0000-4000-8000-00000000001', 'sobre',      'e4000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000004', 'variable', 70000, 'necesario',    'arrastrar',    false),
  ('e7000000-0000-4000-8000-00000000002', 'sobre',      'e4000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000005', 'variable', 30000, 'necesario',    'arrastrar',    false),
  ('e7000000-0000-4000-8000-00000000003', 'sobre',      'e4000000-0000-4000-8000-000000000005', 'c2000000-0000-4000-8000-000000000007', 'variable', 15000, 'deseable',     'arrastrar',    false),
  ('e7000000-0000-4000-8000-00000000004', 'sobre',      'e4000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000008', 'variable', 25000, 'discrecional', 'al_remanente', false),
  ('e7000000-0000-4000-8000-00000000005', 'sobre',      'e4000000-0000-4000-8000-000000000007', 'c2000000-0000-4000-8000-000000000009', 'variable', 20000, 'deseable',     'arrastrar',    false),
  ('e7000000-0000-4000-8000-00000000006', 'compromiso', 'e3000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000003', 'fija',      8077, 'necesario',    'arrastrar',    true)
) as p (id, origen, origen_id, cuenta, tipo, asignado, prioridad, modo, protegida);

insert into public.fin_abonos_semana (id, hogar_id, semana_id, deuda_id, abono_planeado, minimo, extra_planeado)
select (left(a.id, 35) || s.n)::uuid, 'b0000000-0000-4000-8000-000000000001', s.semana::uuid, a.deuda::uuid,
       a.planeado, a.minimo, 0
from (values ('e6000000-0000-4000-8000-000000000001', '1'),
             ('e6000000-0000-4000-8000-000000000002', '2')) as s (semana, n),
     (values ('e8000000-0000-4000-8000-00000000001', 'e5000000-0000-4000-8000-000000000001', 27692, 10385),
             ('e8000000-0000-4000-8000-00000000002', 'e5000000-0000-4000-8000-000000000002', 11539,     0)
) as a (id, deuda, planeado, minimo);

-- Ocurrencias (antes de cerrar la semana del 12/oct).
insert into public.fin_ocurrencias (id, hogar_id, libro_id, origen, origen_id, fecha_programada, fecha_ajustada,
                                    monto_esperado, estado, movimiento_id) values
  ('ea000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'ingreso', 'e1000000-0000-4000-8000-000000000001',
   '2026-10-15', '2026-10-15', 900000, 'cumplida', 'd1000000-0000-4000-8000-000000000007'),
  ('ea000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'ingreso', 'e1000000-0000-4000-8000-000000000001',
   '2026-10-31', '2026-11-02', 900000, 'esperada', null),
  ('ea000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001',
   'f1000000-0000-4000-8000-000000000002', 'ingreso', 'e1000000-0000-4000-8000-000000000003',
   '2026-11-01', '2026-11-02', 350000, 'esperada', null),
  ('ea000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001',
   'f1000000-0000-4000-8000-000000000001', 'compromiso', 'e3000000-0000-4000-8000-000000000001',
   '2026-11-01', '2026-11-01', 800000, 'esperada', null);

-- Cierre de la semana del 12/oct (foto del plan contra lo real y del balance).
insert into public.fin_cierres (id, hogar_id, semana_id, version, ingreso_real, gasto_real, abono_real,
                                abono_diferido, abono_extra_real, ahorro_real, deficit, arrastre_siguiente,
                                accion_elegida, con_pendientes, activos, pasivos, patrimonio, cerrado_en) values
  ('e9000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'e6000000-0000-4000-8000-000000000001', 1, 415385, 37577, 39231, 0, 0, 0, 0, 130500,
   'abono_extra', false, 1975500, 805000, 1170500, '2026-10-19 08:00-06');
insert into public.fin_cierre_partidas (id, hogar_id, cierre_id, partida_id, gastado, arrastre_siguiente, al_remanente)
select p.id::uuid, 'b0000000-0000-4000-8000-000000000001', 'e9000000-0000-4000-8000-000000000001', p.partida::uuid,
       p.gastado, p.arrastre, p.remanente
from (values
  ('e9000000-0000-4000-8000-000000000011', 'e7000000-0000-4000-8000-000000000011',  4500, 65500, 0),
  ('e9000000-0000-4000-8000-000000000012', 'e7000000-0000-4000-8000-000000000021',     0, 30000, 0),
  ('e9000000-0000-4000-8000-000000000013', 'e7000000-0000-4000-8000-000000000031',     0, 15000, 0),
  ('e9000000-0000-4000-8000-000000000014', 'e7000000-0000-4000-8000-000000000041', 25000,     0, 0),
  ('e9000000-0000-4000-8000-000000000015', 'e7000000-0000-4000-8000-000000000051',     0, 20000, 0),
  ('e9000000-0000-4000-8000-000000000016', 'e7000000-0000-4000-8000-000000000061',  8077,     0, 0)
) as p (id, partida, gastado, arrastre, remanente);
insert into public.fin_cierre_abonos (id, hogar_id, cierre_id, deuda_id, planeado, "real", minimo) values
  ('e9000000-0000-4000-8000-000000000021', 'b0000000-0000-4000-8000-000000000001',
   'e9000000-0000-4000-8000-000000000001', 'e5000000-0000-4000-8000-000000000001', 27692, 27692, 10385),
  ('e9000000-0000-4000-8000-000000000022', 'b0000000-0000-4000-8000-000000000001',
   'e9000000-0000-4000-8000-000000000001', 'e5000000-0000-4000-8000-000000000002', 11539, 11539, 0);
update public.fin_semanas set estado = 'cerrada' where id = 'e6000000-0000-4000-8000-000000000001';

-- Importación de la hoja Categorías (registro).
insert into public.fin_importaciones (id, hogar_id, archivo, hoja, filas_leidas, filas_creadas, filas_omitidas, detalle) values
  ('ed000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'DATOS_SEMILLA_PRESUPUESTO.xlsx', 'Categorías', 23, 21, 2,
   '{"omitidas": [{"fila": 7, "motivo": "Nombre repetido"}, {"fila": 19, "motivo": "Pago de deuda: no es categoría de gasto"}]}');

-- ------------------------------------------------------------ Alex (pareja)
select pg_temp.como('a0000000-0000-4000-8000-000000000002');

insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo)
select c.id::uuid, 'b0000000-0000-4000-8000-000000000001',
       pg_temp.libro_personal('a0000000-0000-4000-8000-000000000002'), c.nombre, c.tipo
from (values
  ('c4000000-0000-4000-8000-000000000001', 'Banco de Alex',    'banco'),
  ('c4000000-0000-4000-8000-000000000002', 'Efectivo de Alex', 'efectivo'),
  ('c4000000-0000-4000-8000-000000000003', 'Sueldo de Alex',   'origen_ingreso')
) as c (id, nombre, tipo);

insert into public.fin_ingresos (id, hogar_id, libro_id, persona_id, nombre, tipo, cuenta_origen_id, cuenta_destino_id) values
  ('e1000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000002'), pg_temp.persona('a0000000-0000-4000-8000-000000000002'),
   'Sueldo de Alex', 'salario', 'c4000000-0000-4000-8000-000000000003', 'c4000000-0000-4000-8000-000000000001');
insert into public.fin_vigencias_ingreso (id, hogar_id, ingreso_id, monto_neto_centavos, forma, dias_mes, desde) values
  ('e2000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   'e1000000-0000-4000-8000-000000000002', 1400000, 'mensual', '{0}', '2026-01-01');

insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, categoria_id, nota)
select m.id::uuid, 'b0000000-0000-4000-8000-000000000001', m.tipo, m.fecha::date, m.registrado::timestamptz,
       m.origen, m.destino, m.monto, m.categoria::uuid, m.nota
from (values
  ('d1000000-0000-4000-8000-000000000021', 'apertura',      '2026-10-01', '2026-10-01 18:00-06', pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000002'), 'apertura'), 'c4000000-0000-4000-8000-000000000001'::uuid, 800000, null, 'Saldo inicial (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000022', 'ingreso',       '2026-09-30', '2026-10-01 18:05-06', 'c4000000-0000-4000-8000-000000000003'::uuid, 'c4000000-0000-4000-8000-000000000001'::uuid, 1400000, null, 'Sueldo de septiembre (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000013', 'transferencia', '2026-10-16', '2026-10-16 19:00-06', 'c4000000-0000-4000-8000-000000000001'::uuid, 'c5000000-0000-4000-8000-000000000001'::uuid, 700000, null, 'Aportación a la casa (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000014', 'gasto',         '2026-10-17', '2026-10-17 12:00-06', 'c5000000-0000-4000-8000-000000000001'::uuid, 'c2000000-0000-4000-8000-000000000001'::uuid, 185000, 'c1000000-0000-4000-8000-000000000002', 'Despensa semanal (ejemplo)'),
  ('d1000000-0000-4000-8000-000000000023', 'gasto',         '2026-10-18', '2026-10-18 15:00-06', 'c4000000-0000-4000-8000-000000000002'::uuid, 'c2000000-0000-4000-8000-000000000008'::uuid,  30000, 'c1000000-0000-4000-8000-000000000016', 'Futbol con amigos (ejemplo)')
) as m (id, tipo, fecha, registrado, origen, destino, monto, categoria, nota);

-- ------------------------------------------------------------ Elena (hogar vecino)
select pg_temp.como('a0000000-0000-4000-8000-000000000006');

insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c7000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000002',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000006'), 'Banco de Elena', 'banco'),
  ('c7000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002', null, 'Vivienda', 'de_gasto');
insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, nota) values
  ('d1000000-0000-4000-8000-000000000030', 'b0000000-0000-4000-8000-000000000002', 'apertura', '2026-10-01',
   '2026-10-01 10:00-06', pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000006'), 'apertura'),
   'c7000000-0000-4000-8000-000000000001', 1500000, 'Saldo inicial (ejemplo del hogar vecino)'),
  ('d1000000-0000-4000-8000-000000000031', 'b0000000-0000-4000-8000-000000000002', 'gasto', '2026-10-01',
   '2026-10-01 10:05-06', 'c7000000-0000-4000-8000-000000000001', 'c7000000-0000-4000-8000-000000000002',
   900000, 'Renta (ejemplo del hogar vecino)');

select pg_temp.como(null);

-- ------------------------------------------------------------ Fase 2 (datos inventados)
-- Dispositivos: el teléfono recibe avisos; la laptop no; la tablet pública de la casa nunca.
select pg_temp.como(null);
update public.dispositivos set tipo = 'laptop' where plataforma = 'windows';
update public.dispositivos set tipo = 'telefono', recibe_avisos = true where plataforma = 'android';
insert into public.dispositivos (persona_id, plataforma, token_avisos, nombre, tipo)
select p.id, 'android', 'token-fcm-de-ejemplo-tablet-casa', 'Tablet de la casa (ejemplo)', 'tablet_publica'
from public.personas p where p.usuario_id = 'a0000000-0000-4000-8000-000000000005';

select pg_temp.como('a0000000-0000-4000-8000-000000000001');

-- Tarjeta de Ana: acreedor, día de corte y su estado de cuenta capturado a mano.
update public.fin_deudas set acreedor = 'Banco de ejemplo', corte_dia = 20, cat_pb = 7500
 where id = 'e5000000-0000-4000-8000-000000000001';
insert into public.fin_estados_cuenta (id, hogar_id, libro_id, deuda_id, fecha_corte, fecha_limite_pago,
    saldo_al_corte_centavos, pago_minimo_centavos, pago_sin_intereses_centavos, intereses_centavos, cargos_centavos,
    tasa_declarada_pb, registrado_en) values
  ('e8000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'e5000000-0000-4000-8000-000000000001',
   '2026-10-20', '2026-11-09', 600000, 45000, 600000, 0, 0, 4800, '2026-10-21 10:00-06');

-- Un MSI inventado: una lavadora a 12 meses, con su cuenta pasivo propia.
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c3000000-0000-4000-8000-000000000012', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'MSI Lavadora (ejemplo)', 'prestamo');
insert into public.fin_deudas (id, hogar_id, libro_id, nombre, tipo, clase, cuenta_pasivo_id, abono_centavos,
                               frecuencia, forma, dias_mes, minimo_centavos, tasa_anual_pb) values
  ('e5000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'MSI Lavadora (ejemplo)', 'msi', 'msi',
   'c3000000-0000-4000-8000-000000000012', 50000, 'mensual', 'mensual', '{20}', 50000, 0);
insert into public.fin_msi (id, hogar_id, libro_id, deuda_id, tarjeta_deuda_id, cuenta_pasivo_id, comercio,
                            descripcion, fecha_compra, monto_total_centavos, mensualidades) values
  ('e9000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'e5000000-0000-4000-8000-000000000003',
   'e5000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000012', 'Tienda de ejemplo',
   'Lavadora (ejemplo)', '2026-10-05', 600000, 12);
insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, nota) values
  ('d1000000-0000-4000-8000-000000000040', 'b0000000-0000-4000-8000-000000000001', 'gasto', '2026-10-05',
   '2026-10-05 12:00-06', 'c3000000-0000-4000-8000-000000000012', 'c2000000-0000-4000-8000-000000000002',
   600000, 'Compra a 12 meses sin intereses (ejemplo)');

-- Bolsas de ahorro: fondo de emergencia (nivel 3) y una meta con fecha.
insert into public.fin_cuentas (id, hogar_id, libro_id, nombre, tipo) values
  ('c3000000-0000-4000-8000-000000000010', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Fondo de emergencia', 'ahorro'),
  ('c3000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Celular nuevo', 'ahorro');
insert into public.fin_bolsas_ahorro (id, hogar_id, libro_id, nombre, tipo, cuenta_id, meta_centavos, fecha_meta,
                                      nivel_meta, metodos, prioridad) values
  ('ea000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Fondo de emergencia', 'fondo_emergencia',
   'c3000000-0000-4000-8000-000000000010', null, null, 3, '{monto_fijo}', 1),
  ('ea000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'Celular nuevo', 'meta_fecha',
   'c3000000-0000-4000-8000-000000000011', 900000, '2027-03-01', null, '{meta_fecha}', 2);
insert into public.fin_movimientos (id, hogar_id, tipo, fecha, registrado_en, cuenta_origen_id, cuenta_destino_id,
                                    monto_centavos, nota) values
  ('d1000000-0000-4000-8000-000000000041', 'b0000000-0000-4000-8000-000000000001', 'apertura', '2026-10-12',
   '2026-10-12 12:00-06', pg_temp.cuenta_sistema(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'apertura'),
   'c3000000-0000-4000-8000-000000000010', 150000, 'Saldo inicial del fondo (ejemplo)');

-- Un aviso de ejemplo (lo emite la app para Ana; sin montos ni nombres).
select public.fin_emitir_aviso(pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'), 'fondo_bajo',
                               'libro', pg_temp.libro_personal('a0000000-0000-4000-8000-000000000001'),
                               'fondo_bajo:ejemplo:2026-w43');

select pg_temp.como(null);

-- ------------------------------------------------------------ Fase 3: Hábitos (datos inventados)
-- Cada persona ve solo lo suyo. Los sobres son bytes aleatorios, nunca texto de hábitos reales.
select pg_temp.como('a0000000-0000-4000-8000-000000000001');
insert into public.hab_objetivos (id, titulo, area, tipo, unidad, meta_valor, frecuencia, fecha_inicio, prioridad, minimo, modificado_en) values
  ('f5000000-0000-4000-8000-000000000001', 'Leer 20 minutos al día (ejemplo)', 'espiritual', 'construir', 'minutos', 20, 'diaria', '2026-10-19', 2, true, '2026-10-19 08:00-06'),
  ('f5000000-0000-4000-8000-000000000002', 'Caminar tres veces por semana (ejemplo)', 'salud', 'construir', 'veces', 3, 'n_por_semana', '2026-10-19', 3, false, '2026-10-19 08:00-06');
insert into public.hab_bloques (id, titulo, area, tipo, objetivo_id, inicio, duracion_min, dias, desde, minimo, recordar_min, modificado_en) values
  ('f5100000-0000-4000-8000-000000000001', 'Lectura de la mañana (ejemplo)', 'espiritual', 'actividad', 'f5000000-0000-4000-8000-000000000001', '07:30', 20, 127, '2026-10-19', true, 10, '2026-10-19 08:00-06');
insert into public.hab_registros (id, objetivo_id, fecha, estado, valor, modificado_en) values
  ('f5200000-0000-4000-8000-000000000001', 'f5000000-0000-4000-8000-000000000001', '2026-10-26', 'hecho', 20, '2026-10-26 08:00-06'),
  ('f5200000-0000-4000-8000-000000000002', 'f5000000-0000-4000-8000-000000000001', '2026-10-27', 'parcial', 10, '2026-10-27 08:00-06');
select public.hab_crear_plan_lectura(
  '{"id": "f5300000-0000-4000-8000-000000000001", "tipo": "ruta_inicio", "nombre": "Ruta de inicio (ejemplo)", "fecha_inicio": "2026-10-26", "version_biblica": "rvr1909"}'::jsonb,
  '[{"dia": 1, "fecha": "2026-10-26", "segmentos": [{"libro": 43, "cap_ini": 1, "cap_fin": 1}]},
    {"dia": 2, "fecha": "2026-10-27", "segmentos": [{"libro": 43, "cap_ini": 2, "cap_fin": 2}]}]'::jsonb);
insert into public.hab_marcas_biblia (id, tipo, referencia, color, modificado_en) values
  ('f5400000-0000-4000-8000-000000000001', 'subrayado', '43:3:16', 'amarillo', '2026-10-27 08:20-06');
insert into public.hab_revisiones (id, semana, estado, resumen, modificado_en) values
  ('f5500000-0000-4000-8000-000000000001', '2026-10-19', 'completada', '{"espiritual": 8000}'::jsonb, '2026-10-26 14:40-06');
-- Nube cifrada del diario de oración de Ana (llave envuelta y sobres inventados: bytes aleatorios).
select public.hab_guardar_llave(1, 'pbkdf2-hmac-sha256', '{"vueltas": 600000}'::jsonb,
  translate(encode(decode(md5('sal-de-ejemplo'), 'hex'), 'base64'), '+/=', '-_'),
  translate(encode(decode(md5('a') || md5('b') || md5('c'), 'hex'), 'base64'), '+/=', '-_'));
select public.hab_cambiar_modo('diario_oracion', 'nube_cifrada');
select public.hab_subir_sobres(jsonb_build_array(
  jsonb_build_object('id', 'f5600000-0000-4000-8000-000000000001', 'tipo', 'diario_oracion', 'revision', 1, 'llave_version', 1,
    'cifrado', translate(encode(decode(md5('s1') || md5('s2') || md5('s3'), 'hex'), 'base64'), '+/=\n', '-_'))));

select pg_temp.como('a0000000-0000-4000-8000-000000000002');
insert into public.hab_objetivos (id, titulo, area, tipo, unidad, meta_valor, frecuencia, fecha_inicio, modificado_en) values
  ('f5000000-0000-4000-8000-000000000003', 'Estudiar inglés 15 minutos (ejemplo)', 'educacion', 'construir', 'minutos', 15, 'diaria', '2026-10-19', '2026-10-19 08:00-06');
select pg_temp.como('a0000000-0000-4000-8000-000000000003');
insert into public.hab_objetivos (id, titulo, area, tipo, unidad, meta_valor, frecuencia, fecha_inicio, modificado_en) values
  ('f5000000-0000-4000-8000-000000000004', 'Orar cada noche (ejemplo)', 'espiritual', 'construir', null, null, 'diaria', '2026-10-19', '2026-10-19 08:00-06');
select pg_temp.como(null);

-- ------------------------------------------------------------ Fase 4: Alimentación (datos inventados, sin precios)
select pg_temp.como('a0000000-0000-4000-8000-000000000001');
insert into public.ali_platillos (id, hogar_id, nombre, ingredientes, duros) values
  ('a1000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Avena con plátano (ejemplo)',
   '[{"nombre": "Avena", "cantidad": 50, "unidad": "g", "seccion": "Despensa"}, {"nombre": "Plátano", "cantidad": 1, "unidad": "pieza", "seccion": "Frutas"}]', '{}'),
  ('a1000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Ensalada con nueces (ejemplo)',
   '[{"nombre": "Lechuga", "cantidad": 1, "unidad": "pieza", "seccion": "Verduras"}]', '{nueces}');
insert into public.ali_menus (hogar_id, menu, perfil) values
  ('b0000000-0000-4000-8000-000000000001', 'papa', '{"titulo": "Perfil de ejemplo (inventado)", "lineas": ["Dieta alta en proteínas (ejemplo)"], "texturaBlanda": true}'),
  ('b0000000-0000-4000-8000-000000000001', 'pareja', '{"titulo": "Pareja y dueño (ejemplo)", "lineas": [], "texturaBlanda": false}');
insert into public.ali_menu (id, hogar_id, menu, semana, dia, tiempo, platillo_id) values
  ('a2000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 0, 'desayuno', 'a1000000-0000-4000-8000-000000000001'),
  ('a2000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'pareja', '2026-11-02', 0, 'comida', 'a1000000-0000-4000-8000-000000000002');
insert into public.ali_suplementos (id, hogar_id, menu, nombre, dosis, horario) values
  ('a3000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'papa', 'Suplemento de ejemplo', '1 cápsula (ejemplo)', 'Con el desayuno'),
  ('a3000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'pareja', 'Vitamina de ejemplo', '1 tableta (ejemplo)', 'Por la mañana');
insert into public.ali_compras_marcas (hogar_id, menu, semana, clave) values
  ('b0000000-0000-4000-8000-000000000001', 'papa', '2026-11-02', 'Avena|g');
select pg_temp.como(null);
