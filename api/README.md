# api/ — APIs de GRAVITY con OpenAPI y Swagger UI (D16)

La especificación de las APIs del sistema y su consola local. Se consulta en la laptop, en **Ajustes › Desarrollador** (solo rol Dueño). **No se publica en internet.**

| Archivo | Qué es |
|---|---|
| `openapi.yaml` | La especificación (OpenAPI 3.1). Es la fuente: todo lo demás se genera de aquí. |
| `redocly.yaml` | Reglas de validación. |
| `generar_dart.mjs` | Genera `app/lib/modulos/ajustes/desarrollador/operaciones.g.dart` y `swagger/especificacion.js`. |
| `copiar_swagger.mjs` | Copia los archivos de `swagger-ui-dist` a `swagger/swagger-ui/`. |
| `swagger/index.html` | Swagger UI local con el estilo Futurista de noche (`gravity.css`). |
| `swagger/swagger-ui/` | `swagger-ui-dist` 5.33.1 (Apache-2.0, con `LICENSE` y `NOTICE`). No se edita a mano. |

## Grupos

1. **Herramientas de GRAVITY** (D1, D3): `GET /herramientas`, `POST /herramientas/{nombre}` y una operación por herramienta registrada (Fase 0: navegación).
2. **Base de datos**: Supabase/PostgREST (`/rest/v1/...`), según `supabase/migrations/`. Cada consulta pasa por RLS.
3. **Funciones del servidor**: avisos (Fase 2) e intermediario de la IA (Fase 6). Propuestas.
4. **Puente de casa**: Home Assistant en la red local (Fase 6). Propuestas.

## Extensiones obligatorias en cada operación

| Extensión | Valores | Significado |
|---|---|---|
| `x-roles` | lista de `dueno`, `coadministrador`, `familiar`, `cuidador`, `casa` | Quién la puede usar (D5). La verdad está en el servidor (RLS). |
| `x-escribe` | `true`, `false` o `segun-herramienta` | Si escribe datos: pide confirmación antes de enviarse. |
| `x-solo-local` | `true`, `false` o `segun-herramienta` | Si su resultado nunca pasa por la IA en la nube (D3). |
| `x-fase` | entero | Fase del roadmap en que se construye. |

El generador falla si falta alguna o si un rol no existe.

## Comandos (desde `api/`, con Node 20 o superior)

```bash
npm install          # una vez: swagger-ui-dist y yaml (versiones fijas)
npm run validar      # npx --yes @redocly/cli@2.59.0 lint openapi.yaml
npm run generar      # regenera operaciones.g.dart y swagger/especificacion.js
npm run verificar    # comprueba que lo generado esté al día (sale con 1 si no)
npm run swagger      # copia swagger-ui-dist a swagger/swagger-ui/ (al cambiar su versión)
```

Desde la raíz del repositorio, la validación equivale a:

```bash
npx --yes @redocly/cli@2.59.0 lint api/openapi.yaml --config api/redocly.yaml
```

La prueba de Flutter `app/test/modulos/ajustes/desarrollador/operaciones_generadas_test.dart` falla si `operaciones.g.dart` o `especificacion.js` no corresponden a `openapi.yaml` (huella FNV-1a), o si una herramienta registrada en `app/lib/nucleo/herramientas/` no está documentada con los mismos roles, `escribe` y `soloLocal`.

## Al cambiar la especificación

1. Edita `openapi.yaml`.
2. `npm run validar` y `npm run generar`.
3. `cd ../app && flutter test test/modulos/ajustes/desarrollador`.

Para agregar una herramienta: regístrala en `app/lib/nucleo/herramientas/`, documéntala aquí como `POST /herramientas/<modulo>.<accion>` con sus extensiones y regenera.

## Abrir Swagger UI

- **Doble clic** en `swagger/index.html`: usa `swagger/especificacion.js` (el navegador no deja leer `../openapi.yaml` desde `file://`).
- **Servida por http** (lee `openapi.yaml` en vivo):
  ```bash
  npx --yes http-server@14.1.1 . -p 8080 -a 127.0.0.1
  # y abre http://127.0.0.1:8080/swagger/
  ```
- **Desde la app**: Ajustes › Desarrollador › *Abrir en Swagger UI*. La ruta se indica al compilar:
  ```bash
  flutter run -d windows --dart-define=RUTA_SWAGGER=C:\ruta\gravity\api\swagger\index.html
  ```
  Sin `RUTA_SWAGGER`, la app busca `api/swagger/index.html` junto a su directorio de trabajo y, si no la encuentra, explica cómo abrirla.

**Seguridad de la consola:** toda llamada que no sea de lectura pide confirmación antes de salir; la sesión no se guarda (`persistAuthorization: false`); la especificación nunca se envía al validador público de swagger.io (`validatorUrl: null`); y la telemetría de instalación de `swagger-ui-dist` (Scarf) está desactivada en `package.json`. Las llaves de Supabase y Home Assistant se pegan en *Authorize* solo durante la sesión; nunca se escriben en estos archivos.
