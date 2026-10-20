# Instrucciones para Claude Code — GRAVITY

Asistente virtual tipo JARVIS (voz y texto). Fase inicial: arquitectura y stack sin definir.

## Lee primero
- `README.md` (objetivo y hoja de ruta).
- `docs/CONTRATO_CONEXION_APPS.md` (v2.0), sobre todo la **sección 9** y la 10. Es una copia: la fuente está en la raíz de SEGUNDO CEREBRO. La sección 9 es **propuesta**: confírmala o ajústala con el usuario.

## Primera tarea
1. Proponer arquitectura y stack, con pros y contras, y preguntar al usuario antes de decidir. Pregunta clave: ¿Android, escritorio o ambos? Eso cambia los enlaces `gravity://` del contrato.
2. Actualizar la hoja de ruta del `README.md` con lo que se decida.

## Reglas respecto de las otras apps (contrato v2.0, sección 9)
1. GRAVITY no es dueña de datos de Presupuesto, Hábitos ni Cuidados, y no lee sus bases de datos.
2. Actúa sobre ellas solo abriendo pantallas por enlace (`presupuesto://`, `habitos://`), por orden del usuario. Un enlace no importa, no escribe ni confirma por el usuario.
3. Solo lee un plan o seguimiento exportado si el usuario lo concede de forma explícita y por sesión.
4. Prohibido: dinero, cuentas, precios, datos clínicos de la persona bajo cuidado y datos de salud de terceros.
5. Si usa un modelo de lenguaje: lo mínimo necesario, sin nombres ni alergias, activado por el usuario, y la clave de la API nunca dentro de la app.
6. Si necesita un dato nuevo de otra app, propón un cambio al contrato (qué y por qué); no lo resuelvas por tu cuenta.
7. Funciona sin las otras apps y ellas sin GRAVITY.

## Cómo trabajar
- No cambies el contrato por tu cuenta. Se edita primero en la raíz y se corre `sincronizar-contrato.sh`.
- Este repositorio es independiente (se enlaza como submódulo). Haz commit aquí; luego actualiza el puntero en la raíz.
- No guardes claves ni secretos en el repositorio.
- Responde en español.
