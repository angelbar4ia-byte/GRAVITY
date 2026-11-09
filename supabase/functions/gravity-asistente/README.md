# gravity-asistente (Fase 6, parte 1: conversación de texto)

Función Edge de Supabase (Deno). La app le manda `{mensaje, sesion, historial?}` con la sesión de la
persona y recibe `{respuesta, herramienta}`. La app ejecuta la herramienta **en el dispositivo**; su
resultado nunca vuelve al modelo (D3).

## Dónde va la clave (solo en el servidor)

```
supabase secrets set GEMINI_API_KEY=<clave de Google AI Studio>
```

Nunca en la app, en el repositorio ni en una variable de la app. Sin clave, la función responde
`503 sin_clave` con un mensaje claro y no llama a nadie.

## Ajustes (secretos o variables de la función)

| Nombre | Por omisión | Qué hace |
|---|---|---|
| `GRAVITY_IA_PROVEEDOR` | `gemini` | `gemini`, `claude` o `chatgpt`. |
| `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | (sin valor) | Clave del proveedor elegido. Claude y ChatGPT, con clave del dueño. |
| `GRAVITY_IA_MODELO` | `gemini-2.5-flash`, `claude-haiku-4-5`, `gpt-4o-mini` | Modelo. Los nombres por omisión **no están verificados**: confírmalos en el proveedor. |
| `GRAVITY_IA_LIMITE_DIARIO` | `30` | Mensajes por persona y por día. `0` = sin límite. Al llegar: `429 limite_diario`. |

**Uso sin costo:** el nivel gratuito de Gemini **no está verificado** (spec de la Fase 6, sección 3) y
puede usar lo enviado para mejorar sus productos. Antes de activarlo, revisa los límites vigentes en
Google AI Studio y ajusta `GRAVITY_IA_LIMITE_DIARIO` por debajo de ellos. El conteo sale de la bitácora
(`accion = 'gravity.asistente'`).

## Qué ve el proveedor (D3)

Solo: las instrucciones fijas, los últimos 6 turnos, el mensaje de la persona y los **nombres y
descripciones genéricas** de las herramientas de Finanzas, Hábitos y Cuidados que su rol puede usar
(`catalogo.json`, con el rol que la base le da, no el que diga la app). Montos y medidas de salud que
la persona escriba se reemplazan por `[dato oculto]`, y el contexto se vuelve a revisar antes de
enviarse (`contexto.ts`). No hay herramientas de lectura que devuelvan datos al modelo. Cuidador y
Casa no conversan (D5).

`catalogo.json` es un espejo del registro de la app; `app/test/modulos/gravity/conversacion/catalogo_servidor_test.dart`
falla si dejan de coincidir.

## Bitácora

Una fila por mensaje: quién (`persona_id`), cuándo (`registrado_en`) y en `detalle`:
`{sesion, proveedor, herramienta, resultado}`. Nunca el texto de la conversación.

## Acción `sugerir_recetas` (Alimentación, Fase 8)

Petición: `{accion: "sugerir_recetas", contexto: {ingredientes: [{nombre, cantidad_aprox, unidad}], preferencias}}`
(hasta 60 ingredientes; preferencias de hasta 300 caracteres). Respuesta: `{recetas: [{titulo, porciones, pasos: [...],
ingredientes: [{nombre, cantidad, unidad, pasillo?}]}]}` (formato del archivo de recetas v1; hasta 5 recetas).

- **D3:** el contexto solo acepta `ingredientes` y `preferencias`; cualquier otro campo (perfil, alergias, textura, dieta
  de Papá…) se descarta sin leerse y nunca llega al proveedor. Nombres y preferencias pasan por `redactar` y la revisión
  final de `contexto.ts`. Código en `sugerir_recetas.ts`.
- **Respuesta del modelo:** se valida como JSON estricto (tolera un bloque de código envolvente). Si no es válida:
  `502 respuesta_invalida`, sin receta alguna. Petición mal formada: `400` (`ingredientes_invalidos`,
  `demasiados_ingredientes`, `preferencias_largas`…).
- **No guarda nada** en el servidor: la app guarda la receta solo si la persona confirma.
- **Mismo proveedor y límites** que la conversación: `GRAVITY_IA_PROVEEDOR`, `GRAVITY_IA_LIMITE_DIARIO` (cada sugerencia
  cuenta como un mensaje), mismos roles (dueño, coadministrador, familiar; cuidador y Casa: `403`). Sin clave: `503 sin_clave`
  sin llamar al proveedor. Bitácora: quién, cuándo y `sugerir_recetas`/resultado; nunca el contenido.
- Pide hasta 2500 tokens de salida (la conversación usa 400) y, con Gemini, `responseMimeType: application/json`.

## Gmail y Google Calendar (Fase 6, parte 2) — preparado, sin conectar

Herramientas (`herramientas_google.ts`, adaptador en `google.ts`, cifrado en `cifrado.ts`):

| Herramienta | Qué hace | Roles | Confirmación |
|---|---|---|---|
| `gmail.leer` | Lista los correos recientes de la bandeja | dueño, coadministrador, familiar | no (solo lee) |
| `gmail.redactar` | Crea un **borrador** en el Gmail de la persona | ídem | el envío (`gmail.enviar`, interna) exige `confirmado: true` |
| `calendario.ver` | Próximos eventos (1 a 14 días) | ídem y **Casa** (solo la cuenta de la casa) | no |
| `calendario.crear` | Crea un evento | dueño, coadministrador, familiar | sin `confirmado: true` solo devuelve la vista previa y no llama a Google |

Cuidadora: ninguna. Casa: solo `calendario.ver` de la **cuenta de la casa** y solo si el dueño lo aprobó
(`google_acceso_casa`); nunca Gmail. "Hermana" es un familiar (D5).

**Cómo se llaman.** El modelo solo elige el *nombre* (catálogo genérico, módulo `google`). La app lo ejecuta con
`{accion: "herramienta", herramienta, parametros, confirmado, sesion}`; los parámetros los captura la persona en
un formulario, no el modelo. La cuenta usada sale de la identidad que el servidor lee de la base, nunca de un id
que mande la app: cada persona solo toca su correo. Conectar: `{accion: "google_url", ambito}` devuelve la URL de
Google y `{accion: "google_codigo", codigo, estado}` guarda la cuenta (el `estado` va firmado, caduca a los 10
minutos y liga el código a esa persona). La cuenta de la casa la conecta solo el dueño y pide solo
`calendar.events.readonly`.

**D3 — decisión: el contenido de Google NO vuelve al modelo.** Ni cuerpos, ni asuntos, ni cuántos resultados hubo.
El servidor devuelve el resultado solo a la app (campo `local`), que lo muestra en pantalla; no entra al historial
que viaja al servidor, ni a la bitácora. Se eligió esta opción (y no pasar el contenido por el filtro de
`contexto.ts`) porque un filtro de expresiones regulares puede fallar con un correo (montos, medicamentos, datos de
Cuidados en texto libre) y aquí no hay camino que pueda fallar. Si algún día el asistente debe "resumir" correos,
será una decisión nueva (propuesta al dueño) y pasaría por `redactar`/`verificarContextoLimpio`.

**Tokens.** Solo se guarda el token de renovación, cifrado con AES-256-GCM (`GOOGLE_TOKEN_KEY`) y ligado a la
persona (AAD = `persona:ámbito`) en `public.google_cuentas` (migración `20261125000000`). RLS: cada persona ve
solo su fila; ni ella lee `token_cifrado` desde la app; escribe solo el servidor. Bitácora (`gravity.google`): quién,
cuándo, herramienta y resultado; nunca asuntos, destinatarios ni cuerpos.

**Secretos del servidor** (sin valores en el repositorio):

```
supabase secrets set GOOGLE_CLIENT_ID=<id del cliente OAuth>
supabase secrets set GOOGLE_CLIENT_SECRET=<secreto del cliente OAuth>
supabase secrets set GOOGLE_REDIRECT_URI=<URI de redirección registrada en Google Cloud>
supabase secrets set GOOGLE_TOKEN_KEY=$(openssl rand -base64 32)
```
Sin ellos la función responde `503 google_sin_configurar` / `google_sin_clave`. Sin cuenta conectada: `409
sin_cuenta_google` ("Falta conectar tu cuenta de Google."). Cuenta revocada: `409 cuenta_google_caducada`.

**Pasos de Google Cloud (los hace el dueño):** (1) crear un proyecto; (2) habilitar *Gmail API* y *Google Calendar
API*; (3) pantalla de consentimiento OAuth: tipo *Externo*, en modo *Pruebas*, agregando como usuarios de prueba
los correos de la familia y el de la casa (en Pruebas el token de renovación caduca a los 7 días; para uso
continuo hay que publicar la app y, por usar el alcance restringido `gmail.readonly`, pasar la verificación de
Google — decisión pendiente); (4) alcances: `gmail.readonly`, `gmail.compose`, `calendar.events`,
`calendar.events.readonly`, `userinfo.email`; (5) credenciales: ID de cliente OAuth tipo *Aplicación web* con la
URI de redirección elegida; (6) guardar los cuatro secretos de arriba. Falta decidir la URI de redirección y el
botón "Conectar" de la app (no se conectó nada todavía).

## Pruebas (sin red)

```
node --experimental-strip-types --test supabase/functions/gravity-asistente/*_test.ts
# o, con Deno:  cd supabase/functions/gravity-asistente && deno task probar
```

## Despliegue

```
supabase functions deploy gravity-asistente
```
(con verificación de JWT activada: la función exige la sesión de una persona.)
