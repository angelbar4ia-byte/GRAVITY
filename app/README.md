# GRAVITY — app Flutter

Una sola app (D1): en **Windows** es la laptop con el sistema completo; en **Android** es el teléfono (lo mínimo) o la tablet de la casa (D4, D14). Cada persona ve solo lo de su rol (D5). Pila y convenciones: `docs/specs/fase-0-cimientos.md`.

## Correr la app

```bash
cd app
flutter pub get
flutter run -d windows        # laptop
flutter run -d <android-id>   # teléfono o tablet
```

Sin llaves de Supabase la app arranca en **modo demostración**: personas de ejemplo, selector de rol en la pantalla de entrar y, en la tablet, personas de ejemplo con PIN `1234`. Nada de lo de ejemplo se guarda en el dispositivo.

### Llaves de Supabase (las pone el dueño; nunca en el repositorio)

```bash
flutter run -d windows \
  --dart-define=SUPABASE_URL=https://<proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<llave pública (anon o publishable)>
```

Para no escribirlas cada vez, guárdalas en `app/.env.json` (el `.gitignore` de la raíz ignora `.env.*`, así que no se sube) y usa `--dart-define-from-file=.env.json`:

```json
{ "SUPABASE_URL": "https://<proyecto>.supabase.co", "SUPABASE_ANON_KEY": "<llave>" }
```

La llave pública no da permisos por sí sola: lo que cada persona puede leer o escribir lo deciden las reglas por registro (RLS) del servidor. La llave de servicio (`service_role`) **nunca** va en la app.

### Probar otro cascarón desde la laptop

`--dart-define=GRAVITY_DISPOSITIVO=tablet` (o `telefono`, `laptop`). Sin esa opción se detecta solo: Windows → laptop; Android con lado corto ≥ 600 dp → tablet; si no, teléfono.

## Firebase (solo Android: avisos, fallas y reparto)

Firebase se inicializa **solo en Android y solo si existe la configuración**. Sin ella la app compila, arranca y Ajustes › Notificaciones dice "falta la configuración de Firebase".

Para activarlo (dueño):

1. En la consola de Firebase, crea el proyecto y una app Android con el paquete `mx.segundocerebro.gravity`.
2. Descarga `google-services.json` y cópialo a `app/android/app/google-services.json`. **No se sube**: el `.gitignore` de la raíz lo ignora.
3. Compila de nuevo. `android/app/build.gradle.kts` aplica el complemento `com.google.gms.google-services` solo si ese archivo existe.

App Distribution se usa desde la consola o la CLI de Firebase con el APK (`flutter build apk`); no requiere código.

## Pruebas y análisis

```bash
cd app
flutter analyze
flutter test test/app test/nucleo test/modulos/ajustes   # lo de plataforma
flutter test                                             # todo
```

Código generado (drift): `dart run build_runner build --delete-conflicting-outputs`.

## Qué hay (plataforma, Fase 0)

| Carpeta | Contenido |
|---|---|
| `lib/main.dart` | Arranque y cola automática |
| `lib/app/` | Arranque (`arranque.dart`), detección de dispositivo, router (`router.dart`, go_router), navegación por rol (`navegacion.dart`), cascarones laptop/teléfono/tablet, pantallas de entrar, inicio, "Más", (+) y "Próximamente", modo Casa y PIN de la tablet, y `pantallas_externas.dart` |
| `lib/nucleo/permisos/` | Espejo de la matriz de permisos: `puede(rol, modulo, accion)`, `puedeAbrir`, `modulosNavegables` |
| `lib/nucleo/sesion/` | `ServicioSesion` con Supabase, demostración y falso (pruebas) |
| `lib/nucleo/base_local/`, `lib/nucleo/cola/` | Base local drift y cola sin conexión (UUID, reintentos con espera creciente, idempotencia) |
| `lib/nucleo/seguridad/` | Almacenamiento seguro, PIN con hash (PBKDF2-SHA256) y huella |
| `lib/nucleo/tablet/` | Personas de la tablet, modo Casa, desbloqueo y regreso por inactividad |
| `lib/nucleo/firebase/` | Inicialización condicional de Firebase |
| `lib/modulos/ajustes/` | Ajustes: Apariencia, Voz, Personas y roles, Privacidad, Copias, Notificaciones y Desarrollador |

### Conectar pantallas de otros agentes

Todo pasa por `lib/app/pantallas_externas.dart`: cada función dice en su comentario la línea que va al conectar (pantalla principal de GRAVITY, "Hoy" del teléfono, barra de órdenes, Ajustes › Desarrollador, tema y selector de Apariencia). Ningún otro archivo cambia.

### Tablet de la casa (D14)

- Arranca en **modo Casa** (rol Casa: sin dinero ni datos clínicos), con contextos General · Cocina · Gimnasio · Cuidados.
- "Agregar persona": la persona escribe su correo y contraseña una vez (se comprueban en el servidor sin cambiar la sesión de la tablet) y elige un PIN de 4 a 6 dígitos. Solo se guarda el **hash** del PIN, en el almacenamiento seguro. Tras 5 intentos fallidos, espera de 30 s.
- Huella opcional por persona. Android no dice de quién es la huella: cualquier dedo registrado en la tablet la acepta.
- Tras 2 minutos sin uso (editable en Ajustes › Personas y roles) regresa sola al modo Casa.
- Fase 0: el cambio de persona arma la interfaz con su rol; la sesión del servidor sigue siendo la de la tablet (ver pendientes).

## Pendientes

- Al entrar, la app lee `personas` (por `usuario_id`) y la membresía vigente en `membresias` (esquema base de `supabase/`). Si cambia el esquema, se ajusta `leerPerfilPorOmision` en `lib/nucleo/sesion/servicio_sesion_supabase.dart`. Propuesta al backend: una función `mi_perfil()` que lo entregue en una sola llamada.
- Tablet: cambiar también la sesión del servidor por persona (guardar el token de cada una, cifrado y desbloqueado con su PIN).
- Bloqueo del teléfono con PIN o huella y Crashlytics (complemento de Gradle aparte).
- Cada módulo registra en `tablasDeLaCola` (`lib/app/arranque.dart`) la tabla de sus registros sin conexión.
