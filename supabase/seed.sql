-- =============================================================================
-- GRAVITY · Datos de ejemplo (SOLO desarrollo local y pruebas)
-- =============================================================================
-- Personas y hogares FICTICIOS. Nunca datos reales (van en data/personal/,
-- ignorada por git). NUNCA aplicar al proyecto real: `supabase db push` no lo
-- aplica (no uses --include-seed); `supabase db reset` sí, solo en local.
--
-- Las cuentas NO tienen contraseña (encrypted_password vacío): nadie puede
-- entrar con ellas aunque este archivo llegara por error a un proyecto real.
-- Para entrar en Supabase local, ponles contraseña desde Studio
-- (Authentication › Users) o crea tus propias cuentas de prueba.
--
-- Correos en el dominio reservado .test (RFC 2606): no existen.
--
-- Hogar Ejemplo (b000…0001): un integrante por rol de D5.
--   ana@ejemplo.test    Ana Ejemplo      dueno
--   beto@ejemplo.test   Beto Ejemplo     coadministrador
--   carla@ejemplo.test  Carla Ejemplo    familiar
--   diana@ejemplo.test  Diana Cuidadora  cuidador
--   casa@ejemplo.test   Casa Ejemplo     casa (tablet y puente de casa)
-- Hogar Vecino (b000…0002): para probar el aislamiento entre hogares.
--   elena@ejemplo.test  Elena Vecina     dueno
-- Sin hogar (para probar invitaciones):
--   nuevo@ejemplo.test  Nuevo Ejemplo
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
  ('a0000000-0000-4000-8000-000000000002', 'beto@ejemplo.test',  'Beto Ejemplo'),
  ('a0000000-0000-4000-8000-000000000003', 'carla@ejemplo.test', 'Carla Ejemplo'),
  ('a0000000-0000-4000-8000-000000000004', 'diana@ejemplo.test', 'Diana Cuidadora'),
  ('a0000000-0000-4000-8000-000000000005', 'casa@ejemplo.test',  'Casa Ejemplo'),
  ('a0000000-0000-4000-8000-000000000006', 'elena@ejemplo.test', 'Elena Vecina'),
  ('a0000000-0000-4000-8000-000000000007', 'nuevo@ejemplo.test', 'Nuevo Ejemplo')
) as u (id, correo, nombre);

insert into public.hogares (id, nombre) values
  ('b0000000-0000-4000-8000-000000000001', 'Hogar Ejemplo'),
  ('b0000000-0000-4000-8000-000000000002', 'Hogar Vecino');

insert into public.membresias (hogar_id, persona_id, rol)
select m.hogar::uuid, p.id, m.rol
from (values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'dueno'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'coadministrador'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'familiar'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004', 'cuidador'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000005', 'casa'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000006', 'dueno')
) as m (hogar, usuario, rol)
join public.personas p on p.usuario_id = m.usuario::uuid;

-- Muestra de dinero (centavos, MXN). Montos inventados.
insert into public.finanzas_muestra (id, hogar_id, descripcion, monto_centavos, registrado_por)
select f.id::uuid, f.hogar::uuid, f.descripcion, f.monto, p.id
from (values
  ('c0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'Despensa semanal (ejemplo)', 185000, 'a0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   'Transporte (ejemplo)', 42050, 'a0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002',
   'Renta (ejemplo del hogar vecino)', 900000, 'a0000000-0000-4000-8000-000000000006')
) as f (id, hogar, descripcion, monto, usuario)
join public.personas p on p.usuario_id = f.usuario::uuid;

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
