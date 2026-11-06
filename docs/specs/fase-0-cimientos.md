# Especificación — Fase 0: Cimientos

> Versión 1.0 (20/oct/2026). Base: `docs/ROADMAP.md` (sección 3), `docs/DECISIONES.md` (D1 a D16) y `docs/DISENO_UX_UI.md`. Esta especificación fija las **convenciones comunes** que siguen todos los agentes en todas las fases.

## 1. Resultado utilizable

Entrar con tu cuenta en la laptop (Windows), el teléfono y la tablet (Android); cada rol ve solo lo suyo; la pantalla principal de GRAVITY existe (sin IA) con el estilo Futurista; lo registrado sin señal se sube después; hay copia de seguridad diaria; las APIs están documentadas.

## 2. Estructura del repositorio

```
app/                  App Flutter "gravity": Windows (completa) y Android (teléfono y tablet)
  lib/
    main.dart
    app/              arranque, router, cascarones por dispositivo (laptop, tablet, teléfono)
    nucleo/           sesión, roles y permisos (espejo del servidor), cola sin conexión, configuración
      herramientas/   herramientas de GRAVITY (D1, D3)
    diseno/           sistema de estilos, componentes y gadgets
    modulos/
      gravity/
        pantalla/     pantalla principal (laptop) y núcleo
        ordenes/      barra de órdenes (Fase 0: solo navegación)
      ajustes/        personas y roles, apariencia, voz, privacidad, copias, notificaciones
        desarrollador/  Ajustes › Desarrollador (D16)
      finanzas/       Fase 1
      habitos/        Fase 3
  test/               espejo de lib/
paquetes/
  finanzas_dominio/   lógica pura de Finanzas (Dart sin Flutter) con pruebas
supabase/
  migrations/         SQL con nombre AAAAMMDDHHMMSS_descripcion.sql
  tests/              pruebas SQL de las reglas por rol
  seed.sql            datos de ejemplo (nunca datos reales)
  functions/          funciones de servidor (Deno/TypeScript), desde la Fase 2
api/
  openapi.yaml        especificación OpenAPI (D16)
  swagger/            página local de Swagger UI
herramientas/
  respaldo/           respaldo diario desde la laptop y restauración
casa/                 Home Assistant (Fase 6)
data/                 datos semilla (data/personal/ está ignorada por git)
docs/                 decisiones, roadmap, diseño, especificaciones y diseños de módulos
```

## 3. Pila técnica

| Tema | Elección |
|---|---|
| App | Flutter estable 3.47 (Dart 3.13); plataformas `windows` y `android` |
| Estado | Riverpod |
| Navegación | go_router |
| Base local | drift (SQLite): cola sin conexión y copia del día |
| Servidor | Supabase (`supabase_flutter`): cuentas con correo y contraseña en la Fase 0 |
| Avisos | Firebase Cloud Messaging (solo Android); Crashlytics (solo Android); App Distribution |
| Seguridad local | almacenamiento seguro para llaves y sesiones; huella o PIN |
| Idioma | Español de México en la interfaz |
| Calidad | `flutter_lints`; `flutter analyze` sin errores; pruebas en verde |

Las versiones de los paquetes se toman de pub.dev al agregarlos y se fijan con `^`.

## 4. Convenciones (obligatorias en todas las fases)

- **Identificadores** de dominio en español sin acentos ni ñ (`Movimiento`, `registrarGasto`, `anio`). Textos de la interfaz en español con acentos.
- **Dinero:** enteros en **centavos** (`int`), nunca `double`. Moneda MXN.
- **Semana:** empieza en **lunes**; fechas en hora local del dispositivo; en la base, `date` y `timestamptz`.
- **Identificadores de registros:** UUID generados en el dispositivo (la cola sin conexión es idempotente).
- **Libro solo-agregar:** los movimientos no se editan ni se borran; se corrigen con anulación y contraasiento.
- **Roles (D5):** `dueno`, `coadministrador`, `familiar`, `cuidador`, `casa`.
- **Módulos:** `gravity`, `finanzas`, `habitos`, `cuidados`, `alimentacion`, `casa`, `ajustes`.
- **Permisos:** la verdad está en el **servidor** (RLS). El cliente lleva un espejo de la matriz solo para ocultar lo que no corresponde.
- **Herramientas de GRAVITY (D1, D3):** cada una declara `nombre`, `descripcion`, `modulo`, `roles`, `escribe` (pide confirmación) y `soloLocal` (su resultado nunca se envía a la IA).
- **Sin secretos ni datos reales** en el repositorio. Las llaves de Supabase y Firebase entran por `--dart-define` o archivos ignorados por git.
- **Pruebas:** todo lo que se entrega tiene pruebas que pasan.

## 5. Matriz inicial de permisos (rol × módulo)

| Módulo | dueno | coadministrador | familiar | cuidador | casa |
|---|---|---|---|---|---|
| finanzas | total | leer (lo que registra se define en la Fase 1) | — | gastos de cuidado propios (Fase 5) | — |
| habitos | lo propio | lo propio | lo propio | — | — |
| cuidados | total | según consentimiento | — | su turno | recordatorios genéricos |
| alimentacion | total | total | leer su parte | leer comidas de papá | leer menú y lista |
| casa | total | total | leer | leer | leer |
| ajustes | total | lo propio | lo propio | lo propio | — |

## 6. Trabajo por agente

| Agente | Entrega | Carpetas propias |
|---|---|---|
| **plataforma** | Cascarones laptop/tablet/teléfono; router por rol; sesión; cola sin conexión; estructura de Ajustes; tablet con cambio de usuario por PIN y regreso al modo Casa a los 2 min; Firebase preparado (se activa con la configuración del dueño) | `app/lib/app`, `app/lib/nucleo` (menos `herramientas`), `app/lib/modulos/ajustes` (menos `desarrollador`), `app/pubspec.yaml` (dependencias) |
| **diseno** | Sistema de estilos de 4 capas; Futurista de día y de noche; claro/oscuro por hora; componentes base; núcleo animado; pantalla principal de GRAVITY y "Hoy" del teléfono con datos de ejemplo | `app/lib/diseno`, `app/lib/modulos/gravity/pantalla`, `app/assets`, sección `flutter:` de `pubspec.yaml` |
| **backend** | Esquema base (hogar, personas, membresías y roles, permisos, invitaciones, dispositivos, bitácora); RLS; pruebas SQL; respaldo diario y restauración | `supabase/`, `herramientas/respaldo` |
| **asistente** | Interfaz y registro de herramientas; barra de órdenes de navegación; `api/openapi.yaml` y página Swagger UI; Ajustes › Desarrollador | `app/lib/nucleo/herramientas`, `app/lib/modulos/gravity/ordenes`, `app/lib/modulos/ajustes/desarrollador`, `api/` |
| **finanzas** | Especificación de la Fase 1 y paquete `finanzas_dominio` (semana, equivalentes semanales, libro, cascada) con pruebas | `docs/specs/fase-1-finanzas.md`, `paquetes/finanzas_dominio` |
| **arquitecto** | Proyecto base, integración, revisión, commits y roadmap | todo |

## 7. Criterios de aceptación

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | Entras con tu cuenta en la laptop y en el teléfono | Manual, con el proyecto real de Supabase |
| 2 | Cuidador solo ve Cuidados; Familiar no ve dinero, **comprobado en el servidor** | Pruebas SQL de RLS + pruebas de navegación por rol |
| 3 | Un registro sin internet se sube al volver la señal | Pruebas de la cola con servidor simulado |
| 4 | Copia de seguridad diaria que se puede restaurar | Prueba del script contra una base local |
| 5 | La app llega a un teléfono por App Distribution | Manual, con el proyecto real de Firebase |
| 6 | Tablet: modo Casa sin dinero; PIN abre las pantallas de la persona; regresa al modo Casa a los 2 min | Pruebas de widgets |
| 7 | El estilo cambia sin reiniciar y el claro/oscuro cambia según la hora | Pruebas del sistema de estilos |
| 8 | Lo construido aparece documentado en Ajustes › Desarrollador | Validación de `openapi.yaml` + prueba de la pantalla |

## 8. Lo que necesita el dueño del proyecto

1. Crear el proyecto de **Supabase** (plan gratis) y compartir la URL y la llave pública por un medio seguro (no en el repositorio).
2. Crear el proyecto de **Firebase** con una app Android para avisos, reporte de fallas y App Distribution, y descargar `google-services.json` (no se sube al repositorio).
3. Instalar **Flutter** en la laptop Windows para compilar la versión de escritorio.
