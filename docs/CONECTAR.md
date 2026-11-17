# Conectar GRAVITY de punta a punta

> Guía para dejar la app funcional con servidor real. Ningún secreto va en el repositorio ni en el chat:
> las claves se escriben solo en Supabase, en el Vault o en `--dart-define` al compilar.

## Qué hace falta de cada lado

| Paso | Quién | Dónde |
|---|---|---|
| 1. Crear proyecto Supabase (con confirmación de correo y "Secure password change") | dueño | supabase.com |
| 2. Activar extensiones `pg_cron` y `pg_net` (**antes** de aplicar migraciones) | dueño | Database › Extensions |
| 3. Aplicar las 51 migraciones en orden (`supabase/migrations`) y correr `bash supabase/tests/correr.sh` en una base local primero | dueño con CLI `supabase` (no está en este contenedor) | su computadora |
| 4. Crear usuarios y roles (ver `supabase/README.md`) | dueño | Supabase |
| 5. Proyecto Firebase + app Android + cuenta de servicio | dueño | Firebase |
| 6. Secretos de funciones (tabla abajo) | dueño | `supabase secrets set …` |
| 7. Vault: `gravity_project_url` y `gravity_service_role` (ver README, avisos) | dueño | SQL editor |
| 8. Desplegar `enviar-avisos` y `gravity-asistente` | dueño | `supabase functions deploy` |
| 9. Compilar con `--dart-define` | dueño | laptop / teléfono |
| 10. Comprobar en dispositivo (lista abajo) | dueño + Claude | |

## Secretos de las funciones

| Nombre | Función | Notas |
|---|---|---|
| `FCM_SERVICE_ACCOUNT` | enviar-avisos | JSON de la cuenta de servicio de Firebase. Sin él no envía y no falla |
| `GEMINI_API_KEY` (o `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`) | gravity-asistente | Solo en servidor. Revisar términos del nivel gratuito antes de activar |
| `GRAVITY_IA_PROVEEDOR`, `GRAVITY_IA_MODELO`, `GRAVITY_IA_LIMITE_DIARIO` | gravity-asistente | Opcionales; confirmar el nombre del modelo en el proveedor |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`, `GOOGLE_TOKEN_KEY` | integración Google | Solo si se activa esa integración |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` las inyecta Supabase en las funciones.

## Compilar la app

```
cd app
flutter build windows --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon>
flutter build apk      --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=GRAVITY_DISPOSITIVO=telefono
```

La clave `anon` es pública por diseño; la protección real son las reglas RLS. Nunca uses la `service_role` en la app.
Sin esas variables la app arranca en modo demostración.

## Comprobaciones de que quedó conectado

1. Inicio de sesión real con cada rol (D5): cada persona ve solo lo suyo.
2. Un movimiento de Finanzas se guarda y aparece en otro dispositivo.
3. `select * from cron.job;` muestra `avisos-enviar`, `hab-limpieza` y `cui-generar-tomas`.
4. Aviso de prueba llega al teléfono (FCM).
5. El asistente responde por texto; sin clave responde `503 sin_clave`; el dinero y lo clínico nunca salen (D3).
6. Fallas de red: la cola sin conexión reenvía al volver.

## Lo que Claude puede hacer aquí y lo que no

- Puede: mantener este documento, revisar migraciones y funciones, escribir pruebas, preparar scripts de despliegue.
- No puede en este contenedor: `flutter`, `deno` y `supabase` CLI no están instalados; hay `docker` y `psql` para probar SQL.
- Para compilar o desplegar desde la computadora del dueño hace falta conectar esa computadora a la sesión.
