# Revisión a ciegas de los ejemplos patrón · ronda 3

> Paquete P1.4a del plan `docs/specs/fase-8-ingles-plan.md`. Fecha: 15/nov/2026.
> Cuaderno: el regenerado tras la ronda 2 (commit `adabf70`), solo las cinco unidades que cambiaron: 31 preguntas.
> Revisor: un tercer agente `calidad` en Sonnet (`calidad-d`), en árbol aislado y sin abrir archivos. Respuestas en `ronda-3-calidad-d.yaml`.
> Comparación: `python3 herramientas/ingles/transitorio/comparar_ronda.py docs/revisiones/ingles/ronda-3-calidad-d.yaml`. El programa se probó antes con una copia donde se plantaron tres desacuerdos y los detectó.

## Resultado

| | Ronda 1 | Ronda 2 | Ronda 3 |
|---|---|---|---|
| Preguntas resueltas | 40 | 40 | 31 (solo lo cambiado) |
| Respuesta principal igual a la clave | 40 | 40 | 31 |
| Segundas respuestas defendibles (disputas) | 6 | 2 | **0** |

Las dos preguntas que cerraron la ronda 2 (`ue2-0001-8` con *Neither* y `ue4-0001-4` con *to have been*) no volvieron a aparecer: el revisor dice expresamente que *Neither* no sirve con tres problemas y que *is said to still be* no encaja con el texto fijo.

Dos veces el revisor anotó una segunda respuesta (`ue2-0001-3`, *behind*; `ue4-0001-5`, *the car*), y las dos ya estaban en `aceptadas`: no son disputas.

## Observaciones que no cambiaron nada

| Observación | Por qué se deja |
|---|---|
| `lun-03`: *I'm understanding* es "defendible solo débilmente" en inglés actual | Es el distractor que la lección enseña a evitar (los verbos de estado casi no van en continuo), y el revisor contestó la clave con seguridad alta. Cambiarlo obligaría a otra ronda por una duda que el propio revisor no convirtió en segunda respuesta |
| `r3-c`: la opción D (amigos) es un distractor "válido pero cercano" | Un buen distractor se parece a la respuesta. La explicación por opción ya dice por qué no |
| El texto de lectura B1 "ronda las 420 palabras" | Mide 394, dentro del rango del contrato (300 a 400). Tres revisores han estimado de más; el conteo manda |
| TOEFL, completar palabras: "en el real se da la primera mitad de cada palabra" | Sigue sin poderse verificar: la especificación solo dice *partially missing words*. La regla de la segunda mitad queda como provisional en el contrato (`ocultar`) |
| El texto de TOEFL tiene palabras "más cerca de B2" | La unidad está marcada B1 y el contrato no fija nivel por palabra. Se revisará al escribir la unidad real |

## Lo que tres rondas prueban, y lo que no

**Prueban:** que ningún revisor, de tres, encuentra ya una segunda respuesta en estas preguntas, y que el proceso funciona: cada ronda encontró cosas que el autor no había visto (8 segundas respuestas en total) y cada corrección sobrevivió a la ronda siguiente.

**No prueban:**
- **Independencia total.** Los tres revisores son agentes del mismo modelo. Comparten sesgos: pueden pasar por alto lo mismo. La revisión a ciegas atrapa inconsistencias, no garantiza que un hablante nativo o un examinador de Cambridge esté de acuerdo. Por eso el plan mantiene el muestreo del dueño y la puerta de etapa con formato oficial.
- **Que el nivel sea el que dice.** Los revisores opinan sobre el nivel; no lo miden.
- **Nada sobre lo no objetivo**: pronunciación, producción y guiones de audio no entran en el cuaderno.

## Estado

Los nueve ejemplos siguen en `borrador`, y deben seguir así por ahora:
- El validador da 0 errores, pero "sin niveles" (`niveles.yaml`, paquete P1.3) y "sin contrato" (`gravity-sesion-60`, paquete P1.1b) son avisos en `borrador` y **errores desde `validado`**. Cuando existan, los ejemplos pasan a `validado`.
- A `revisado` solo se llega con la orden `comparar` (paquete P1.2c), que guarda la huella de lo revisado. Estas tres rondas se comparan con un programa transitorio y no dejan huella; cuando exista `comparar`, se repiten sobre el contenido final.
- La plantilla de sesión la aprueba el dueño (decisión D-ING-4, ya confirmada: aprueba plantillas y una muestra).
