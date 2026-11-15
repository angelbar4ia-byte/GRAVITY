# Revisión a ciegas de los ejemplos patrón · ronda 2

> Paquete P1.4a del plan `docs/specs/fase-8-ingles-plan.md`. Fecha: 15/nov/2026.
> Cuaderno: el generado tras las correcciones de la ronda 1 (commit `a6c4f98`), 40 preguntas en 7 unidades, pegado completo en el encargo.
> Revisor: otro agente `calidad` en Sonnet (`calidad-c`), en árbol aislado y sin abrir archivos. Respuestas en `ronda-2-calidad-c.yaml`.

## Resultado

| | Ronda 1 | Ronda 2 |
|---|---|---|
| Respuesta principal igual a la clave | 40 de 40 | 40 de 40 |
| Segundas respuestas defendibles (disputas) | 6 | 2 |
| Disputas de la ronda 1 que volvieron a aparecer | — | 0 de 6 |

Las seis preguntas reescritas tras la ronda 1 pasaron: el revisor nuevo no encontró segunda respuesta en cinco de ellas y en la sexta (`ue2-0001-8`) encontró una distinta, que es una de las dos disputas de esta ronda.

## Disputas y cómo se cerraron

| Pregunta | Clave | Lo que defendió el revisor | Cierre |
|---|---|---|---|
| `ue2-0001-8` | None | *Neither*, si el lector cuenta dos problemas y no tres | El texto ahora dice "of these **three** problems" |
| `ue4-0001-4` | is said to be | *is said to have been* (el propio revisor dice que cambia el tiempo) | Las dos oraciones llevan ahora "**still** haunted": el infinitivo perfecto deja de caber |

`ue2-0001-3` (*for* / *behind*) y `ue4-0001-5` (*my car* / *the car*): las dos formas ya estaban en `aceptadas`. No son disputas.

## Observaciones de calidad que también se atendieron

No eran disputas (la respuesta era única), pero el ejemplo patrón debe dar el nivel:

| Unidad | Observación del revisor | Cambio |
|---|---|---|
| Transformaciones, pregunta 5 | Con el participio fuera del hueco quedó fácil para B2 | Sustituida: "I ___ by the local garage every year" (clave HAVE; *have my car serviced*). *Service* no tiene sinónimo exacto y la respuesta vuelve a medir dos cosas |
| TOEFL, completar palabras | En dos palabras se ocultaba mucho más de la mitad; el hueco `a__` casi no daba pista | Se oculta la segunda mitad de cada palabra y el hueco 9 pasa de *age* a *wooden* |
| Sesión, preguntas 02 a 06 | Varios distractores se descartaban por concordancia (*start*, *rise*), no por la idea de la lección | Distractores nuevos que son errores de formación del continuo o del hispanohablante (*is start*, *am understand*, *rising*); 05 y 06 pasan a respuesta escrita |
| Sesión, pregunta 09 | Mecánica y ajena a la regla; faltaba practicar "lo que está cambiando" | Sustituida: "Let's go home. It ___ (get) dark." |
| Lectura B1, pregunta e | "I never planned it" era discutible | La opción dice ahora "It wasn't really my choice" |
| Formación de palabras | Un salto de línea raro | Corregido; sin cambio de contenido |

## Un dato que no se pudo verificar

El revisor afirma que en el TOEFL real "se da más o menos la mitad de cada palabra". La especificación oficial y la página de ETS solo dicen "partially missing words". Se adopta la mitad final como **criterio provisional**, por ser la convención de este tipo de prueba, y queda anotado como pendiente en el formato (V14) hasta ver una muestra oficial.

## Observaciones que no se atendieron, y por qué

- **La oración sobrante de las oraciones omitidas es fácil de descartar.** Cierto. Una sobrante más tentadora tiene que seguir siendo imposible en los seis huecos, y los dos intentos de redacción cabían a medias en alguno. Se deja como está y se anota como límite del ejemplo.
- **El enunciado de la pregunta global de la lectura no sería de B1 Preliminary.** El primer revisor opinó lo contrario. La prueba de muestra del manual usa otra fórmula ("What would be a good introduction to this article?"), así que las dos son defendibles; no se cambia.
- **Estimaciones de longitud.** Los dos revisores estimaron de más el texto de lectura (440 y 430 palabras; mide 394). Las longitudes las decide el conteo, no la impresión.

## Estado

Las preguntas cambiadas en esta ronda todavía no las ha resuelto nadie a ciegas. Por la regla 12 del plan (si el contenido cambia, la revisión caduca), hace falta una ronda 3 con otro agente sobre las cinco unidades tocadas. Los ejemplos siguen en `borrador`.
