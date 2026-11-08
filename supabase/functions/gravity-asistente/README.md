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

## Pruebas (sin red)

```
node --experimental-strip-types --test supabase/functions/gravity-asistente/asistente_test.ts
# o, con Deno:  cd supabase/functions/gravity-asistente && deno task probar
```

## Despliegue

```
supabase functions deploy gravity-asistente
```
(con verificación de JWT activada: la función exige la sesión de una persona.)
