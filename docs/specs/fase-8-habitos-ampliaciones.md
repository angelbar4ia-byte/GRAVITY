# Fase 8 · Bloque 5 — Hábitos: Inglés (núcleo)

> v0.1 (14/nov/2026), **borrador para aprobación del dueño**. No hay código todavía.
> Fuente: `docs/modulos/habitos/diseno-app-habitos.md` §5.3 (Inglés) y Anexo A (plan de 24 semanas B1 → B2). Base: `fase-3-habitos.md`, D21 (datos sensibles) y las reglas de D3 y D6.

## Alcance de este bloque (5a)

Lo que entra:
1. **Ruta de aprendizaje B1 → B2** tomada del Anexo A: unidades temáticas con lecciones cortas (5 a 10 minutos).
2. **Prueba de nivel inicial** corta, para confirmar B1 y ubicar puntos débiles. Su resultado ajusta el punto de inicio.
3. **Vocabulario con repaso espaciado**: tarjetas con ejemplo, guardadas por el usuario o tomadas de las lecciones. El repaso sigue un intervalo creciente según acierto.
4. **Gramática** en explicaciones breves con ejercicios de opción múltiple.
5. **Métricas**: palabras aprendidas, minutos de estudio, racha de días y precisión por unidad. Se muestran en Hoy y en el área de inglés.
6. **Sin conexión**: todo el contenido de las lecciones y las tarjetas funciona sin internet. El progreso se guarda local y se sincroniza como el resto de Hábitos.

Lo que **no** entra en 5a (queda para bloques posteriores, cada uno con su especificación):
- Audio, dictados, velocidad y acentos (requiere decidir fuente de audio y licencias).
- Pronunciación con reconocimiento de voz (requiere decidir motor de reconocimiento y si corre en el teléfono).
- Conversación guiada y redacciones corregidas con IA (van después de la Fase 6 y respetan D3: sin datos clínicos ni de dinero).
- Interfaz bilingüe y alternancia automática de pantallas.
- Exámenes simulados, inglés para el trabajo y series con subtítulos.

## Reglas
- El contenido de las lecciones es **propio** (generado por el equipo a partir del Anexo A), no se copia de fuentes con licencia. Cualquier material externo se aprueba antes.
- No se envía a ningún servicio de IA en esta etapa. Sin llamadas de red para estudiar.
- Dinero y datos clínicos no entran a este módulo. El progreso de inglés no sale de Hábitos.
- Pareja: el progreso es privado de cada persona. El reto con la pareja queda para un bloque posterior.

## Datos (propuesta)
- `ing_unidades` (orden, nivel, título), `ing_lecciones` (unidad, orden, duración estimada, contenido en JSON corto).
- `ing_tarjetas` (texto en inglés, traducción, ejemplo, intervalo, próximo repaso).
- `ing_sesiones` (fecha, minutos, lecciones completadas, aciertos y errores).
- `ing_prueba` (fecha, nivel estimado, puntos débiles).
- Todas con RLS por persona, como el resto de Hábitos. Solo solo-agregar en sesiones y pruebas.

## Preguntas que necesito que respondas antes de construir
1. **¿Aprueba el alcance 5a?** Audio, pronunciación e IA quedan para bloques siguientes.
2. **¿Quién escribe el contenido de las lecciones?** Propongo que yo lo redacte a partir del Anexo A y tú lo revises unidad por unidad (la primera unidad antes de seguir con la siguiente).
3. **¿Cuántas lecciones por semana?** El Anexo A usa 24 semanas. Propongo 5 días a la semana, unas 15 minutos al día.
4. **¿El repaso de tarjetas es diario o solo cuando se tiene tiempo?** Propongo un recordatorio local discreto, sin presión si se falla un día.
5. **¿Cuenta como hábito de Hábitos (racha y puntos del área personal) o es un área aparte?** Propongo que sea un área propia con su propia racha.

## Criterios de aceptación (borrador)
- La prueba de nivel ubica al usuario en una unidad del Anexo A y se puede repetir después de 30 días.
- Una lección de 5 a 10 minutos se completa sin conexión y deja sesión registrada.
- Las tarjetas repiten en intervalo creciente: acierto alarga el intervalo, error lo regresa a un día.
- Las métricas de la sección "Métricas" del diseño aparecen en el área de inglés.
- Pruebas: dominio en Dart (intervalos y racha), app (lección, prueba de nivel, tarjetas) y SQL (RLS por persona).
