---
name: leccion-idioma
description: Redacta y revisa sesiones diarias del curso de idiomas de GRAVITY (una hora, de lunes a viernes) en el formato gravity-ingles-v1, con explicación en español, preguntas con su razón, pronunciación, tarea de producción con lista de cotejo y modelo, audios de traslado, frases para repetir, tarjetas y mini prueba. Úsala cuando se pida escribir o revisar una sesión, una semana o un escalón del curso de inglés. Para simulacros y partes de examen se usa simulacro-examen-idioma.
---

# Lección de idioma

**Alcance:** GRAVITY · Hábitos · idiomas. Primera aplicación: inglés. La plantilla de la sesión es una **propuesta** hasta que el dueño responda la decisión D-ING-2 del plan; mientras tanto, nada pasa de `borrador`.

## Lee antes de escribir

1. `docs/specs/fase-8-ingles-plan.md`: secciones 2, 3.1, 3.2 y 5, y el temario del escalón en el anexo B.
2. `docs/specs/fase-8-ingles-formato.md`: sección 7 (sesión, mínimos por bloque, longitudes por etapa y cálculo de minutos) y sección 4 (tipos de pregunta).
3. Los tres ejemplos patrón del curso en `data/ingles/ejemplos/`: `sesion-b1-1-s01-lun-ejemplo.yaml` y los dos `audio-b1-1-s01-*`. Son el nivel de calidad exigido.
4. `data/ingles/niveles.yaml`, cuando exista: qué gramática es nueva en cada escalón.

## Por qué existe esta habilidad

La revisión del bloque (ING-B4) midió las lecciones anteriores: de 62 a 113 palabras y de 1.4 a 2.5 ejercicios por día, para una hora de estudio. Daban para 5 a 10 minutos. Una sesión es buena cuando **llena los 60 minutos con práctica**, no cuando cubre un tema.

## La semana

| Día | Enfoque | La lección trae |
|---|---|---|
| Lunes | Gramática y vocabulario | Explicación, 6 ejemplos, un error común y 10 preguntas o más |
| Martes | Escucha | Un audio propio con 8 preguntas |
| Miércoles | Pronunciación | Explicación del sonido y 12 elementos |
| Jueves | Lectura y escritura | Un texto con 6 preguntas |
| Viernes | Conversación | Diálogo guiado de 8 turnos con variantes, y la mini prueba de 10 preguntas |

Además, cada semana lleva **dos audios de traslado** (un monólogo y un diálogo), 20 frases para repetir por sesión y 8 tarjetas nuevas de lunes a jueves (32 en la semana).

## Reglas de redacción

1. **Una idea por sesión.** El título y el "puedo" dicen qué sabrá hacer la persona al terminar. Si hacen falta dos "puedo", son dos sesiones.
2. **La explicación va en español y dice el porqué.** Corta, con la pregunta que decide (por ejemplo: "¿es así siempre o solo por ahora?"). Nada de listas de reglas sin criterio.
3. **Los ejemplos son frases que alguien diría.** En inglés, con su traducción natural al español de México. Sin nombres de marcas, sin dinero real, sin datos de salud de personas reales.
4. **El error común es el del hispanohablante.** `mal`, `bien` y `porque`.
5. **Cada pregunta mide la idea del día**, y solo esa. La primera opción es la correcta; cada distractor es un error que alguien del nivel cometería, con su `porque_no`.
6. **Las respuestas escritas listan todas las formas válidas** (con y sin contracción). Si la consigna admite dos tiempos verbales, dice cuál quiere.
7. **La pronunciación se elige por la gramática del día**: los sonidos que esa gramática obliga a decir. Cada elemento trae una nota que se pueda seguir sin saber fonética; el símbolo fonético es apoyo, no explicación.
8. **La producción siempre trae** consigna, extensión, puntos obligatorios, lista de cotejo que la persona puede marcar sola, respuesta modelo dentro de la extensión y errores típicos.
9. **Los audios de traslado cargan la gramática de la semana** y se repiten los cinco días: volver a oír lo mismo es parte del método. Van dentro de la longitud de la etapa. Las 20 frases para repetir salen de esos audios y de la lección.
10. **Las tarjetas** traen la palabra o expresión, su traducción y un ejemplo que la contiene. Vocabulario del tema de la semana y del nivel del escalón.
11. **Nada se usa dos veces**: ni frases de ejemplo entre sesiones, ni preguntas entre la lección y la mini prueba.
12. **El nivel manda.** No se usa gramática de un escalón posterior en ejemplos, audios ni modelos, salvo como frase hecha.

## Los minutos se calculan, no se declaran

Con la fórmula de la sección 7 del formato. El total debe quedar entre 54 y 66 minutos, y cada bloque entre el 70 % y el 150 % de su tiempo. Si una sesión no llega, falta práctica: se añaden preguntas, elementos o frases; no se alarga la explicación.

## Procedimiento del autor

1. Lee la ficha de la semana (escalón, tema, "puedo") y los ejemplos patrón.
2. Escribe las cinco sesiones, los dos audios, las tarjetas y la mini prueba en `data/ingles/curso/<escalon>/semana-NN/`, en `borrador`.
3. Corre `dart run bin/ingles.dart validar <ruta>` en `herramientas/ingles` y corrige hasta cero errores. Mientras la herramienta no exista, cuenta a mano los mínimos de la tabla y los minutos, y dilo en el reporte.
4. Entrega el reporte de la sección 5.4 del plan. No hagas commit.

## Qué revisa quien resuelve a ciegas

Las preguntas objetivas de las cinco lecciones y de la mini prueba, con el mismo procedimiento que en `simulacro-examen-idioma`: contesta sin ver la clave e intenta defender una segunda respuesta. La pronunciación, la producción y los guiones no entran en el cuaderno; los revisa calidad por muestreo, con los ejemplos patrón al lado.

## Lo que no hace esta habilidad

- No decide el temario de un escalón: eso es `niveles.yaml` y el anexo B del plan.
- No califica escritura ni habla: la persona se evalúa con la lista de cotejo y el modelo.
- No escribe otros idiomas hasta que el dueño lo pida.
