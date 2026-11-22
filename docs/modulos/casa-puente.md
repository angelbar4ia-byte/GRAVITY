# Casa: puente con Home Assistant y bocinas Xiaomi

> v1.0, 8/nov/2026. Base: D3, D5, D6, D9 y `docs/specs/fase-6-asistente.md`. Nada está conectado todavía: esto es lo que se prepara y lo que hará el dueño.

## 1. Qué hay en el código

- `app/lib/modulos/casa/puente/frases.dart`: tabla frase -> herramienta -> roles, y `TraductorFrases`.
- `app/lib/modulos/casa/puente/mensaje_bocina.dart`: `FiltroBocina`; solo él crea un `MensajeBocina`.
- `app/lib/modulos/casa/puente/puente_casa.dart`: interfaz `PuenteCasa`, `PuenteCasaFalso` (pruebas) y `PuenteHomeAssistant` (API local).
- Pruebas sin red: `app/test/modulos/casa/puente_casa_test.dart`.

## 2. Frases fijas (D6)

| Frase ("Hey Google, ...") | Herramienta de GRAVITY | Roles |
|---|---|---|
| siguiente paso | `alimentacion.receta_siguiente_paso` | Casa, Dueño, Co-administrador, Familiar |
| paso anterior | `alimentacion.receta_paso_anterior` | ídem |
| repite el paso | `alimentacion.receta_repetir_paso` | ídem |
| qué cocino hoy | `alimentacion.que_cocino_hoy` | ídem |
| lee la lista de compras | `alimentacion.leer_lista_compras` | ídem |

- Las bocinas siempre llegan como rol Casa (la voz no identifica, D5). Cuidador: sin acceso a este canal.
- Frase fuera de la tabla o rol sin permiso: no pasa nada.
- **Pendiente de otros agentes (alimentación):** esas herramientas aún no existen en el registro; los nombres son una propuesta. Al crearlas, deben ser de lectura y rol Casa incluido.

## 3. Lo que GRAVITY dice por la bocina

Solo recordatorios genéricos, pasos de receta y la lista de compras. `FiltroBocina` rechaza antes de enviar: cifras (cualquier dígito), dinero, términos clínicos o de dosis, medicamentos y nombres de personas (estos dos se cargan desde el servidor al arrancar el puente, no viven en el repositorio), enlaces, texto vacío o de más de 280 caracteres. Consecuencia: un paso como "hornea 20 minutos" se rechaza; los pasos deben redactarse sin dígitos ("hornea hasta dorar").

## 4. Configuración (pasos del dueño)

1. **Home Assistant Green**: conectarlo por cable al router, encenderlo y abrir `http://homeassistant.local:8123`; crear la cuenta de administrador. Verificar el precio actual en la tienda oficial de Home Assistant antes de comprar.
2. **Home Assistant Cloud**: en Ajustes > Home Assistant Cloud, iniciar sesión y suscribirse. Verificar precio y periodo de prueba en la página oficial antes de pagar. Activar la integración con Google Assistant desde ahí. No abrir puertos en el router, ni siquiera "por si acaso".
3. **Bocinas Xiaomi (L05G)**: configuradas en Google Home y en la misma red Wi-Fi que el Green. En Home Assistant, agregar la integración Google Cast; deben aparecer como `media_player.*`. Anotar el nombre de la de cocina.
4. **Cuenta Casa**: usar la cuenta de Google de la casa (fase 6, decisión 2) en Google Home. En GRAVITY, la cuenta con rol Casa.
5. **Frases**: en Google Home crear una rutina por frase (comando de voz = la frase) cuya acción active una escena o script de Home Assistant (por ejemplo `script.siguiente_paso`). Cada script manda al puente el id de escena de la tabla (`siguiente_paso`, etc.) y la bocina de origen.
6. **Token**: en el perfil de un usuario de Home Assistant dedicado (no administrador, solo lo necesario) crear un token de acceso de larga duración. Guardarlo **solo** como secreto del servidor o variable de entorno del puente. Nunca en la app, el repositorio ni `data/`.
7. **Nombres y medicamentos para el filtro**: cargarlos como secretos del servidor, no en el repositorio.

## 5. Qué verificar

- La bocina de la cocina aparece como `media_player` y reproduce un aviso de prueba genérico desde Herramientas para desarrolladores > Acciones (`tts.speak`).
- Cada una de las cinco frases dispara su rutina; "agrega leche a la lista" no hace nada.
- Con rol cuidador, ninguna frase ejecuta herramienta.
- Un texto con medicamento, nombre o monto no llega a la bocina (probar con el puente falso y luego en vivo).
- `nmap` o el panel del router muestran que no hay puertos reenviados.
- Apagar la laptop: con el Green las frases siguen funcionando (en la fase 1 con la laptop, solo con ella encendida y en la red de casa).

## 6. Preguntas para el dueño

- ¿Aprueba los nombres propuestos de las herramientas de alimentación?
- ¿"Qué toca hoy" (que aparece en D6) queda fuera de esta primera tanda? Se dejó fuera por no estar en la lista aprobada.

## 7. Pantalla del módulo Casa en la app (F8-7.1, 22/nov/2026)

La ruta `/casa` ya no dice "Próximamente": `app/lib/modulos/casa/pantallas/pantalla_casa.dart` (laptop y tablet; solo lectura).

- **Estado del puente.** Por omisión muestra *"Aún no hay puente configurado"* y, en "Cómo configurarlo", los pasos de la sección 4 (sin precios ni direcciones). La app **no habla con Home Assistant**: el token vive en el equipo del puente (sección 4, paso 6) y la pantalla nunca lo pide ni lo muestra (no tiene campos de texto). El estado sale de una interfaz, `FuentePuente` (`estado/estado_puente.dart`), con dos implementaciones: `FuentePuenteNoConfigurada` (la de siempre) y `FuentePuenteEnMemoria` (pruebas). Los estados son *no configurado*, *no responde* y *conectado* (con la hora de la última respuesta).
- **Frases fijas.** Lista las cinco frases de `frasesFijas` con lo que hace cada una (la descripción de su herramienta en `alimentacion_voz.dart`) y quién puede usarla. No deja escribir una frase libre ni mandar texto a la bocina (D6).
- **Nota de límites.** Repite que por las bocinas nunca hay dinero ni datos clínicos y qué descarta `FiltroBocina` (cifras, dinero, términos de salud, nombres, enlaces, más de 280 caracteres).
- **Quién la abre.** La matriz de `Modulo.casa`: dueño, pareja, familiar (lectura) y la cuenta Casa de la tablet. La cuidadora entra a Cuidados, no a Casa.
- **Pendiente (pregunta 1 para el dueño y el arquitecto).** Falta definir **cómo reporta su estado el puente a la app** (un latido hacia Supabase con la cuenta Casa, por ejemplo). Mientras no exista, la fuente real no se puede escribir sin inventar comportamiento; cuando exista, solo hay que cambiar `fuentePuenteProvider`.
- Corrección a la sección 2: las cinco herramientas de alimentación **ya existen** en el registro (`app/lib/nucleo/herramientas/alimentacion_voz.dart`).
