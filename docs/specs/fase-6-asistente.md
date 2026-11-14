# Fase 6 · GRAVITY asistente (especificación)

> v1.0, 8/nov/2026. Aprobada por el dueño: Home Assistant Green con Home Assistant Cloud; Gmail y Calendar por cuenta de cada persona, y una cuenta de Google de la casa para Casa. Base: D3, D6, D8, D9 y las respuestas del dueño de hoy.

## 1. Alcance

- **Conversación por texto** en la pantalla principal de GRAVITY, con las herramientas de Finanzas, Hábitos y Cuidados según el rol (D3).
- **Proveedor de IA conectable:** Gemini como opción gratuita verificada; Claude y ChatGPT como opciones adicionales que el dueño conecta con su propia clave. Todo en el servidor: la clave nunca va en la app (principio de Hábitos).
- **Control de la laptop** con lista cerrada de acciones (D8): abrir programas y archivos, buscar archivos, **Gmail** (leer y redactar), **Google Calendar** (ver y crear eventos). Confirmación antes de enviar, borrar, mover, instalar o pagar. Nunca banca ni compras (D8).
- **Voz en la laptop** (escuchar y hablar) y en el teléfono como una función más de la app.
- **Bocinas Xiaomi** (D6) con las frases fijas aprobadas: "Hey Google, siguiente paso", "paso anterior", "repite el paso", "qué cocino hoy", "lee la lista de compras". GRAVITY habla por la bocina con el puente de casa (D9).
- **Puente de casa** (D9): primero la laptop (Fase 1 del puente), con el equipo dedicado preparado para todas las opciones (sección 6).

## 2. Reglas que no se rompen

- **Dinero y datos clínicos no salen a la IA en la nube** (D3). El asistente recibe solo el resultado de herramientas que no contengan cifras ni datos de salud, o trabaja con el rol que no los ve.
- **La IA nunca manda sobre la base de datos.** Lo que GRAVITY lee (correos, páginas, archivos) es información, nunca órdenes (D8).
- **Cuidadora y Casa** no conversan libremente con GRAVITY (D5): la cuidadora recibe solicitudes y recordatorios; Casa, recordatorios genéricos.
- **Bocinas:** solo recordatorios y frases genéricas; sin nombres de medicamentos ni de personas (D6).
- Lo que el proveedor gratuito pueda usar para mejorar sus productos se tiene en cuenta: por eso el asistente no recibe datos personales sensibles.

## 3. Proveedores de IA

| Proveedor | Estado | Nota |
|---|---|---|
| Gemini (Google) | Nivel gratuito de la API disponible | Los límites varían según la fuente; se revisan en Google AI Studio antes de construir. Puede usar lo enviado para mejorar productos en el nivel gratuito. |
| Claude (Anthropic) | Opción adicional | No se encontró un nivel gratuito verificado de la API; se conecta con clave del dueño. |
| ChatGPT (OpenAI) | Opción adicional | No se encontró un nivel gratuito verificado; se conecta con clave del dueño. |

*Pendiente:* verificar los límites actuales de Gemini y los créditos de Claude y ChatGPT antes de activarlos. No se promete "todo gratis" hasta confirmarlo.

## 4. Herramientas de la laptop (D8)

- Abrir programas y archivos; buscar archivos.
- Gmail: leer y redactar (el envío requiere confirmación).
- Google Calendar: ver y crear eventos (la creación requiere confirmación).
- Abrir las pantallas de los módulos de GRAVITY.
- Todo lo demás, fuera de la lista: no se puede hacer.
- Bitácora de todas las acciones.

## 5. Bocinas (D6)

- Frases fijas de Google Home que activan una escena del puente de casa, que a su vez ejecuta la herramienta correspondiente de GRAVITY.
- GRAVITY habla por la bocina (recordatorios genéricos, pasos de receta, respuestas a las frases).
- Modelo: Xiaomi Smart Speaker (IR Control), L05G.

## 6. Puente de casa (D9): opciones

Todo se prepara para cualquiera de estas opciones; el dueño elige después.

| Opción | Ventaja | Costo y esfuerzo |
|---|---|---|
| **Home Assistant Green** (recomendada) | Equipo listo para usar, con soporte oficial de Home Assistant. Lo más simple de mantener. | Compra de un equipo; el precio se verifica antes de comprar. |
| **Raspberry Pi 5** con Home Assistant OS | Más barato; el mismo software. | Requiere armarlo y mantenerlo; fuente de poder y tarjeta de memoria. |
| **Mini PC** | Potente si se quiere usarlo para más cosas. | El más caro y el que más consume. |

**Conexión con Google:** Home Assistant Cloud (suscripción, lo más simple) o túnel seguro manual (gratis, más trabajo). **Nunca** se abren puertos del router (D9).

**Mi propuesta:** Home Assistant Green con Home Assistant Cloud, porque es lo más simple y deja la casa funcionando sin depender de la laptop. Mientras llega, la laptop hace de puente (D9, fase 1).

## 7. Decisiones aprobadas (8/nov/2026)

1. **Puente de casa:** Home Assistant Green con Home Assistant Cloud.
2. **Gmail y Calendar:** cada persona conecta **su propia cuenta de Google**. Casa usa una **cuenta de Google de la casa**, creada para ese fin.
3. **Orden de construcción:** conversación de texto con Gemini; después Gmail y Calendar; después bocinas.

*Pendiente del dueño:* crear el proyecto de Google Cloud y la clave de Gemini (se guardan en el servidor, no en la app).

## 7b. Preguntas abiertas (ya no bloquean)

- Verificar los límites actuales de Gemini antes de activarlo.

## 8. Trabajo por agente (cuando se apruebe)

- **asistente:** conversación por texto, herramientas por rol, lista cerrada de la laptop, voz, frases de las bocinas.
- **backend:** clave del proveedor en el servidor, bitácora de acciones, reglas por rol.
- **casa:** puente de casa y bocinas.
- **plataforma:** control de la laptop y voz en el teléfono.
- **calidad:** revisión al cierre (D3 y D8 sobre todo).
