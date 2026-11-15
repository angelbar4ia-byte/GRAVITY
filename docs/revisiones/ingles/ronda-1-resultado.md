# Revisión a ciegas de los ejemplos patrón · ronda 1

> Paquete P1.4a del plan `docs/specs/fase-8-ingles-plan.md`. Fecha: 15/nov/2026.
> Cuaderno: `docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md` (commit `1d35e94`), 40 preguntas en 7 unidades.
> Revisor: un agente `calidad` en Sonnet (`calidad-a`). Respuestas en `ronda-1-calidad-a.yaml`.
> Comparación: a mano, contra la clave que imprime `herramientas/ingles/transitorio/cuaderno_ejemplos.py --clave`.

## Resultado

| Unidad | Preguntas | Coinciden | Disputas |
|---|---|---|---|
| `ej-cam-b1-r3-0001` · B1 Preliminary, Reading 3 | 5 | 5 | 0 |
| `ej-cam-b2-ue2-0001` · B2 First, hueco abierto | 8 | 6 | 2 |
| `ej-cam-b2-ue3-0001` · B2 First, formación de palabras | 8 | 7 | 1 |
| `ej-cam-b2-ue4-0001` · B2 First, transformaciones | 6 | 4 | 2 |
| `ej-cam-b2-r6-0001` · B2 First, oraciones omitidas | 1 (6 huecos) | 1 | 0 |
| `ej-toefl-r-palabras-0001` · TOEFL, completar palabras | 1 (10 palabras) | 1 | 0 |
| `ej-b1-1-s01-lun` · curso, lección del lunes | 11 | 10 | 1 |
| **Total** | **40** | **34** | **6** |

En las 40 preguntas, la respuesta principal del revisor coincide con la clave. Las seis disputas son segundas respuestas que el revisor pudo defender.

## Disputas y cómo se cerraron

Regla del plan (anexo D.4): una disputa no se discute. O la respuesta entra en `aceptadas` porque de verdad es válida, o la pregunta se reescribe para que deje de serlo.

| Pregunta | Clave | Lo que defendió el revisor | Cierre |
|---|---|---|---|
| `ue2-0001-7` | since | *from* ("in service from the 1980s") | Reescrita: "in service **ever** ___ the 1980s". Solo cabe *since* |
| `ue2-0001-8` | so ("Even so") | *then* ("Even then") | Reescrita: "___ of these problems, however, has stopped…". Solo cabe *None* |
| `ue3-0001-1` | thoughts | *thinking* ("our own thinking") | Reescrita: "while our own ___ **drift** by". El verbo sin -s pide plural |
| `ue4-0001-1` | not as/so entertaining as | Lo mismo con *nearly*, *quite*, *half*, *nowhere near* | Sustituida por otra pregunta (clave BEST) cuya respuesta ocupa las cinco palabras: no cabe ningún añadido |
| `ue4-0001-5` | am having my car repaired | *fixed* por *repaired*; *the* por *my*; duda con *'m* | Reescrita: "I'm ___ repaired at the moment". El participio queda fuera del hueco; se aceptan *having my car* y *having the car* |
| `lun-09` | How often do you go to the gym? | *How often are you going to the gym?* | La consigna ahora pide la pregunta "en presente simple" |

`ue2-0001-3`: el revisor propuso *behind* además de *for*. Ya estaba en `aceptadas`; no es disputa.

## Otros hallazgos de la ronda

1. **El ejemplo de lectura de B1 era largo.** El revisor lo estimó en unas 440 palabras; medía 406. El contrato de B1 Preliminary, escrito en paralelo, fija el rango en 300 a 400 (la muestra oficial mide 352). Se recortó a 394.
2. **Falta una regla para comparar respuestas escritas.** El revisor preguntó si la mayúscula inicial y el signo de interrogación cuentan. Se añade al formato: no cuentan (sección 9).
3. **El árbol aislado no contenía el cuaderno.** El agente lo buscó en su árbol de trabajo, no lo encontró y lo leyó del árbol principal. Es decir, en este entorno el árbol aislado no parte de la rama de trabajo, y dar una ruta saca al revisor de su aislamiento. El plan se corrige: el cuaderno se pega dentro del encargo, como decía la primera redacción.
4. **Solo hubo un revisor.** El plan pedía dos para los ejemplos patrón; el segundo lanzamiento fue negado por el sistema de permisos. La ronda 2 la resuelve un agente distinto, sobre el cuaderno corregido.

## Lo que esta ronda no prueba

- Que las preguntas corregidas estén bien: eso lo dirá la ronda 2.
- Que el nivel de cada unidad sea el que dice. El revisor opinó que sí, pero es una opinión, no una medición.
- Nada sobre las partes que no son objetivas (pronunciación, producción, guiones de audio): no entran en el cuaderno.
