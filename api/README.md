# api/ — APIs de GRAVITY con OpenAPI y Swagger UI (D16)

La especificación de las APIs del sistema y su consola local. Se consulta en la laptop, en **Ajustes › Desarrollador** (solo rol Dueño). **No se publica en internet.**

| Archivo | Qué es |
|---|---|
| `openapi.yaml` | La especificación (OpenAPI 3.1). Es la fuente: todo lo demás se genera de aquí. |
| `redocly.yaml` | Reglas de validación (los ejemplos deben cumplir su esquema). |
| `generar_dart.mjs` | Genera `app/lib/modulos/ajustes/desarrollador/operaciones.g.dart` y `swagger/especificacion.js`. |
| `copiar_swagger.mjs` | Copia los archivos de `swagger-ui-dist` a `swagger/swagger-ui/`. |
| `swagger/index.html` | Swagger UI local con el estilo Futurista de noche (`gravity.css`). |
| `swagger/swagger-ui/` | `swagger-ui-dist` 5.33.1 (Apache-2.0, con `LICENSE` y `NOTICE`). No se edita a mano. |

## Grupos

1. **Herramientas de GRAVITY** (D1, D3): `GET /herramientas`, `POST /herramientas/{nombre}` y una operación por herramienta registrada (Fases 0 y 1: navegación; "registrar gasto" solo abre la hoja de registro).
2. **Base de datos**: Supabase/PostgREST (`/rest/v1/...`), según `supabase/migrations/20261020000000_base.sql`. Cada consulta pasa por RLS.
3. **Base de datos · Finanzas** (Fase 1, D19): las 21 tablas `fin_*`, las vistas `fin_v_saldos` y `fin_v_gasto_semana`, y las funciones `fin_puede`, `fin_puede_hogar`, `fin_es_miembro`, `es_cuenta_maestra`, `cuenta_maestra`, `asignar_cuenta_maestra`, `fin_registrar_consulta_maestra`, `fin_crear_libro_representado` y `fin_lunes`, según `supabase/migrations/20261021000000_finanzas_mvp1.sql` y las salvaguardas de `20261023000000_finanzas_salvaguardas.sql` (consulta registrada de la cuenta maestra con vigencia de 30 minutos, bitácora reservada al servidor, libro de Papá con `en_nombre_de` y `motivo`, membresías de los compartidos, `finanzas.maestra_asignada`). Esa migración no agrega ninguna función llamable desde la API: sus ayudantes y triggers no tienen operación. Las respuestas del dueño del 23/oct (`20261024000000_finanzas_respuestas_dueno.sql`) agregan `fin_libros.visibilidad` (`privada` por omisión | `publica`, solo compartidos), la salida de un compartido (`PATCH` a la propia fila de `fin_libro_miembros` con `hasta` = ahora; el servidor archiva el libro si quedan menos de 2), `crear_invitacion(..., p_es_maestra)` e `invitaciones.es_maestra`, la cuenta maestra de solo lectura total sin libro propio, las cuentas de gasto e ingreso archivables con saldo y las RPC `fin_solo_lectura` y `fin_puede_salir` (las demás funciones de esa migración son de triggers y no tienen operación). La migración `20261026000000_finanzas_endurecimiento_1b.sql` (N1 a N5) agrega la RPC `fin_nombrar_albacea` (solo el dueño), el tope de la bitácora (código `54000`: 4 KB por entrada y 500 entradas por persona en 24 horas), el motivo de al menos 3 caracteres visibles (`23514`), `finanzas.salida_libro_representado` para toda salida del libro de Papá y la acción de bitácora `finanzas.albacea_nombrado`; el resto son funciones de triggers sin operación. Solo dueño y coadministrador (cada quien su libro); los libros solo-agregar no tienen PATCH ni DELETE; lo que pone el servidor (`recibido_en`, `libro_*` de los movimientos, columnas generadas) va como `readOnly`; los errores `23503`, `23505`, `23514`, `22023`, `55000` y `42501` están en la descripción del grupo. Ejemplos inventados: el hogar de Ana y Alex de `supabase/seed.sql`, con "Papá (ejemplo)".
4. **Funciones del servidor**: avisos (Fase 2) e intermediario de la IA (Fase 6). Propuestas.
5. **Puente de casa**: Home Assistant en la red local (Fase 6). Propuestas.

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

La prueba de Flutter `app/test/modulos/ajustes/desarrollador/operaciones_generadas_test.dart` falla si `operaciones.g.dart` o `especificacion.js` no corresponden a `openapi.yaml` (huella FNV-1a), si una herramienta registrada en `app/lib/nucleo/herramientas/` no está documentada con los mismos roles, `escribe`, `soloLocal` y fase, si falta una tabla o vista `fin_*` de la migración de Finanzas o una de sus funciones, o si algo de Finanzas no es `x-solo-local` (D3).

## Al cambiar la especificación

1. Edita `openapi.yaml`.
2. `npm run validar` y `npm run generar`.
3. `cd ../app && flutter test test/modulos/ajustes/desarrollador`.

Para agregar una herramienta: agrégala al catálogo de su fase en `app/lib/nucleo/herramientas/catalogo.dart`, documéntala aquí como `POST /herramientas/<modulo>.<accion>` con sus extensiones y regenera. El registro la rechaza al arrancar (`ArgumentError`) si:

- declara un rol que la matriz de permisos (`app/lib/nucleo/permisos/permisos.dart`) no deja abrir el módulo (navegación), escribir en él (si `escribe`) o leerlo (D5);
- es de Finanzas o Cuidados y no es `soloLocal` (D3), **también las de navegación**;
- se la declara a la cuidadora y no es de su bandeja de solicitudes (D18; se resuelve por rol, D17);
- escribe o administra lo ajeno en un módulo donde el rol no tiene alcance total (D19: en Finanzas nadie escribe en el libro de otro). Además, a la cuenta maestra nunca se le ofrece una que escriba o administre lo ajeno y, si no es la dueña (login propio), es de **solo lectura total** (D19, 23/oct): ninguna herramienta que escriba ni que abra una hoja de registro, tampoco para lo propio; si el dueño es además la maestra, conserva las suyas para lo propio.

La orden de gasto exige el verbo (D19, 23/oct): solo "registrar gasto" y sus variantes con ese verbo; la palabra "gasto" suelta no abre nada.

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
