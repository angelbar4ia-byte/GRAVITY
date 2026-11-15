---
name: simulacro-examen-idioma
description: Construye y revisa unidades, prácticas y simulacros de examen de idiomas (Cambridge, TOEIC, TOEFL y otros) en el formato gravity-ingles-v1, con contrato tomado del manual oficial, preguntas originales, una sola respuesta defendible, explicación por pregunta y resolución a ciegas. Úsala cuando se pida un simulacro, una práctica por partes, una prueba de ubicación o la revisión de un examen de idioma en GRAVITY. El enfoque actual es inglés; la habilidad sirve para otros idiomas después.
---

# Simulacro de examen de idioma

**Alcance:** GRAVITY · Hábitos · idiomas. Primera aplicación: inglés. Otros idiomas se agregan más adelante, en su propia carpeta, y solo cuando el dueño lo pida.

## Lee antes de escribir

1. `docs/specs/fase-8-ingles-plan.md`, secciones 2 y 5 (principios y reglas de trabajo).
2. `docs/specs/fase-8-ingles-formato.md` (formato, tipos de pregunta y comprobaciones V01 a V26).
3. El contrato del examen en `data/ingles/formatos/`. Si no existe, se escribe primero, con la página del manual oficial para cada dato.
4. Los ejemplos patrón de `data/ingles/ejemplos/`: son el nivel de calidad exigido.

## Principios (no negociables)

1. **Formato por contrato.** Partes, número de preguntas y de opciones, longitud de los textos y de los guiones, tiempos y número de reproducciones salen del manual oficial. Si la red no alcanza la fuente, se pide el PDF al dueño; no se completa de memoria.
2. **Longitud del contrato o etiqueta de reducido.** Un simulacro con textos más cortos que los oficiales no es "completo". La fidelidad la calcula la herramienta; no se escribe a mano.
3. **Preguntas originales.** Del examinador solo se usa el formato.
4. **Una sola respuesta defendible.** Si una pregunta se puede discutir, está mal: se reescribe o se retira.
5. **La primera opción de la fuente es la correcta.** No se escriben letras: el sorteo lo hace la herramienta.
6. **Distractores plausibles.** Cada opción incorrecta responde bien a otra pregunta parecida o refleja un error típico del nivel. Nunca una frase absurda.
7. **Explicación por pregunta.** `porque` con la evidencia del texto o del audio; `porque_no` en los distractores del curso.
8. **Nada se usa dos veces.** Ni entre formas, ni entre práctica y forma, ni entre ubicación y lo demás.
9. **Nadie revisa su propio trabajo.** Toda pregunta objetiva se resuelve a ciegas por otro agente antes de pasar a `revisado`.
10. **Lo que no se puede verificar queda como pendiente.** Nunca se presenta como oficial algo que no se confirmó.

## Reglas por tipo de pregunta

| Tipo | Regla |
|---|---|
| Opción múltiple de lectura o escucha | Las preguntas siguen el orden del texto; la última puede ser global. Ninguna se contesta sin leer o escuchar |
| Texto con huecos y opciones | Las cuatro opciones son palabras distintas de la misma categoría, no formas del mismo verbo |
| Hueco abierto | Solo palabras gramaticales (preposiciones, artículos, auxiliares, pronombres, conectores, partículas). Se listan todas las respuestas válidas. Si caben más de tres palabras de contenido, el hueco está mal elegido |
| Formación de palabras | Toda respuesta transforma la base. Hay prefijos negativos, plurales y cambios de categoría |
| Transformación con palabra clave | La palabra clave va dentro de la respuesta, sin cambios, y no aparece fuera del hueco |
| Oraciones omitidas | Cada oración colocada declara su `ancla`: el pronombre, conector o repetición que la fija a ese hueco y a ningún otro |
| Correspondencia | Cada respuesta cita su `evidencia`. Las respuestas se reparten entre los textos |
| Completar palabras (TOEFL) | Siempre dentro de un texto, con la primera oración completa |
| Escucha | Guion con voces, longitud del contrato y reproducciones del contrato. El guion no aparece en el cuaderno |
| Escritura y habla | Consigna, extensión, puntos obligatorios, lista de cotejo, respuesta modelo y errores típicos |

## Procedimiento del autor

1. Lee el contrato de la parte y un ejemplo patrón del mismo tipo.
2. Escribe la unidad en `data/ingles/unidades/<formato>/<parte>/`, en estado `borrador`.
3. Corre `dart run bin/ingles.dart validar <ruta>` en `herramientas/ingles` y corrige hasta cero errores. Pasa a `validado`.
4. Entrega el reporte de la sección 5.4 del plan con la salida de `informe`. No hagas commit.

## Procedimiento del revisor a ciegas

1. Recibes solo el cuaderno exportado, sin clave. No abras `data/ingles/unidades`.
2. Contesta todo. En huecos abiertos, formación de palabras y transformaciones, escribe todas las respuestas que consideres válidas.
3. Por cada pregunta, intenta defender una segunda opción. Si lo logras, anótala en `otras_validas`.
4. Guarda el archivo de respuestas en `docs/revisiones/ingles/` con el formato de la sección 9 del formato.
5. El integrador corre `comparar`. Las disputas vuelven al autor; no se discuten.

## Mientras no exista la herramienta

Hasta que se construya `herramientas/ingles` (paquete P1.2 del plan):
- Escribe en el formato `gravity-ingles-v1` igualmente, copiando la estructura de los ejemplos patrón.
- Revisa a mano las reglas de la tabla anterior y cuenta las palabras de cada estímulo contra el contrato.
- No marques ningún archivo por encima de `borrador`.

## Lo que no hace esta habilidad

- No califica exámenes reales ni emite certificados.
- No convierte resultados a la escala oficial de un examen si esa escala no está verificada en su fuente.
- No escribe material de otros idiomas hasta que el dueño lo pida.
