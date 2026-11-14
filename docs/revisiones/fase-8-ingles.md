# Revisión de calidad — Fase 8, bloque 5 (Hábitos · Inglés)

Revisor: arquitecto (sesión de análisis) · Fecha: 14/nov/2026 · Árbol: `856e48c` (rama `claude/zen-pasteur-b0jblz`).
Alcance: `docs/contenido/ingles/` completo (30 documentos, unas 8,500 líneas), `docs/specs/fase-8-habitos-ampliaciones.md` (bloque 5a, v0.4), el Anexo A de `docs/modulos/habitos/diseno-app-habitos.md`, la habilidad `.claude/skills/simulacro-examen-idioma/` y el estado del módulo Hábitos en la app. Los manuales oficiales usados para comparar están citados en `docs/contenido/ingles/formatos-oficiales.md`.

El plan que corrige estos hallazgos está en `docs/specs/fase-8-ingles-plan.md`. Los códigos entre paréntesis (por ejemplo, P1.2) son paquetes de ese plan.

## 1. Veredicto

**No apto todavía para usarse como curso ni como preparación de examen. Sí es una buena base de borradores.** Hay cinco hallazgos bloqueantes. Ninguno es de código: son de validez del contenido y de calibración.

Lo que más pesa:

1. Los simulacros "completos" tienen el número correcto de preguntas, pero sus textos y guiones son entre 2.5 y 6 veces más cortos que los del examen oficial, y la comprensión auditiva se hace leyendo. Aprobar uno de estos simulacros no indica que se aprobaría el examen.
2. Hay partes enteras con preguntas inválidas: varias respuestas correctas con una sola aceptada, preguntas que no piden nada y textos con oraciones omitidas cuya clave no es coherente.
3. Los módulos enseñan gramática de nivel A2 y prometen cerrar en B1, B1+ y B2. Con 5 horas a la semana, el calendario de 28 semanas suma 140 horas; subir un nivel completo cada 8 semanas no es realista.
4. El plan exige 60 minutos diarios, pero cada lección tiene material para unos 5 a 10 minutos.
5. La prueba de ubicación se aplica una sola vez y hoy ubicaría de más: sus bloques "B1+" y "B2" miden gramática de B1.

Nada de esto impide empezar a construir la app. Sí obliga a fijar antes el formato del contenido y su validación automática, para no cargar a la app contenido que después haya que retirar.

**Límites (honestidad).** No revisé todas las preguntas una por una: leí completos los dos simulacros de B2 First (Reading and Use of English), el módulo 1, la prueba de ubicación y la rúbrica, y medí el resto con scripts. Las longitudes oficiales salen de la prueba de muestra incluida en cada manual, una por examen, así que son aproximadas. Las horas de estudio por nivel de Cambridge para A2 (180 a 200) y B1 (350 a 400) vienen de una guía de Cambridge localizada en una búsqueda anterior de esta sesión; la cifra de B2 (500 a 600) es la que Cambridge publica habitualmente y no la pude volver a abrir hoy. No probé audio ni un teléfono real.

## 2. Pruebas y mediciones corridas

| Comando o medición | Resultado |
|---|---|
| `flutter test --exclude-tags hallazgo` (app) | 3033 pasan, 14 omitidas. **Corrección:** antes se reportó que Flutter no estaba instalado; sí lo está, en `/home/user/tools/flutter/bin` |
| `flutter analyze` (app) | Sin errores ni advertencias; 7 avisos informativos fuera de inglés (4 en `alimentacion/pantallas/historial_completo.dart`, 1 en `finanzas/pantallas/ajustes_avisos.dart`, 2 en una prueba) |
| `bash supabase/tests/correr.sh` | 4029 afirmaciones correctas; falla `99_cuidados_recordatorios.sql` (conocida: la función usa `now()` y la prueba usa fechas fijas) |
| Código de inglés en la app o en el servidor | No existe: ninguna tabla `ing_*`, ninguna pantalla. El sistema de diseño ya tiene el submódulo `ingles` (personalidad lúdica, acento naranja) |
| Palabras por parte en cada simulacro frente a la muestra oficial | Tablas de ING-B1 |
| Oraciones en inglés de 7 palabras o más repetidas entre archivos | 95 (tabla de ING-I1) |
| Densidad de las lecciones de los módulos 1 a 4 | Tabla de ING-B4 |

## 3. Hallazgos bloqueantes

### ING-B1. Los simulacros "completos" no representan al examen oficial

**Evidencia: longitud.** Palabras de la parte completa (texto, preguntas y opciones). La columna oficial es la página de la prueba de muestra del manual.

| Examen y parte | Muestra oficial | Forma A | Forma B | Veces más corto |
|---|---|---|---|---|
| B2 First · Reading 5 (texto largo, opción múltiple) | ≈ 1,030 (el texto solo, ≈ 700) | 311 (texto 137) | 316 (texto 114) | 3.3 (texto: 5 a 6) |
| B2 First · Reading 6 (oraciones omitidas) | ≈ 670 | 239 | 199 | 3 |
| B2 First · Reading 7 (correspondencia) | ≈ 770 | 305 | 289 | 2.6 |
| B2 First · Listening, guion completo | ≈ 3,200 | ≈ 480 | ≈ 510 | 6 |
| B1 Preliminary · Reading 2 (personas y textos) | ≈ 640 | 196 | 184 | 3.3 |
| B1 Preliminary · Reading 3 (texto y opción múltiple) | ≈ 670 (el texto solo, ≈ 390) | 254 (texto 100) | 253 (texto 100) | 2.6 (texto: 4) |
| B1 Preliminary · Listening, guion completo | ≈ 2,400 | ≈ 400 | ≈ 415 | 6 |
| TOEIC · Parte 3, cada conversación | ≈ 110 a 160 | ≈ 46 | — | 2.5 a 3.5 |
| TOEIC · Parte 4, cada charla | ≈ 100 a 140 | ≈ 38 | — | 3 |
| TOEIC · Parte 7, textos sencillos | 78 y 104 en los dos más cortos de la muestra | 28 a 66 | — | 2 o más |
| TOEIC · Parte 7, conjuntos de dos o tres textos | más de 160 en el fragmento extraído | 58 a 73 en total | — | más de 2 |

**Evidencia: modalidad.** Toda la comprensión auditiva se presenta como texto para leer. Eso mide lectura, no escucha.

**Evidencia: TOEFL.** Las longitudes sí caen en el rango de la especificación 2026 (textos de hasta 200 palabras, audio de hasta 250). Lo que no coincide es la estructura:
- "Completar palabras" se presenta como 30 raíces sueltas sin texto (`res_____`, `exp________`, `com_________`). La especificación la describe como completar palabras dentro de un texto, usando pistas de forma y sintaxis. Sin contexto, cada raíz admite varias palabras (*research, resource, respond*).
- "Leer en la vida diaria" usa conjuntos de 4 y 6 preguntas; la especificación indica conjuntos de 2 y 3.
- Reading y Listening oficiales son adaptativos en dos etapas (módulo de ruta y módulo inferior o superior). Los simulacros son lineales.

**Consecuencia.** El 80 % en estos simulacros se alcanza con mucho menos esfuerzo y tiempo que en el examen real. El semáforo diría "listo" a alguien que no lo está.
**Corrige:** contrato de formato por examen como datos (P1.1), validación de longitudes (P1.2), y reconstrucción por examen con fidelidad completa (fase 5). Mientras tanto, los documentos se reetiquetan como "formato reducido" (P0.1).

### ING-B2. Partes con preguntas inválidas

Ejemplos comprobados en los dos simulacros de B2 First (Reading and Use of English):

| Parte | Problema | Ejemplos |
|---|---|---|
| 1 (forma A) | Dos o tres opciones encajan | 4: *come* es la clave, pero *grown* y *developed* también encajan. 5: la clave es *repairing*, pero *designing* encaja igual |
| 1 (forma B) | Las opciones son formas del mismo verbo; la parte oficial mide vocabulario en contexto | 2 (*began, begun, beginning, begin*), 5, 7 y 8 |
| 2 (A y B) | Huecos de palabra de contenido con varias respuestas válidas; la clave acepta una sola | A-11 *develop* (también *have, get, acquire*); A-12 *through* (también *with, by*); B-16 *consult* (también *see, visit, call*); B-9, B-10, B-11, B-14, B-15 |
| 3 (A y B) | La respuesta es la misma palabra dada: no hay formación de palabra | A-18 HEALTH → *health*; A-19 ELECTRIC → *electric*; B-19 LEVEL → *level*; B-21 COMFORT → *comfort* |
| 4 (forma B) | La palabra clave ya está escrita fuera del hueco y la respuesta no la contiene | 26: IF, "If only Tom ___ ___" → *had studied* |
| 6 (A y B) | La clave coloca oraciones donde el texto no las sostiene | A-37: habla de "los sábados" antes de que el texto mencione el voluntariado. A-38: "varios de sus alumnos estudiaron ingeniería" aparece cuando Lucas aún no es maestro. B-41: "su primer entrenador" contradice que nunca tuvo uno. B-42: la sorpresa de sus amigos por contratar a alguien queda después de la carrera |

Otros casos:
- B1 Preliminary B, Reading 4: el hueco 16 está a media oración ("Learning to cook (16) ___ Many people think…") y la respuesta es una oración completa.
- TOEFL (A, B y práctica): "Completar palabras" sin contexto, como en ING-B1. En la práctica, la pista en español no coincide con la categoría de la palabra (*ach____* con la pista "logro" para el verbo *achieve*).

**Consecuencia.** Una respuesta correcta se califica como error, y se entrena una estrategia equivocada para el examen.
**Corrige:** tipos de pregunta con reglas comprobables en el validador (P1.2: V07 a V10), lista de respuestas aceptadas en huecos abiertos, y resolución a ciegas por un segundo agente antes de aprobar cualquier pregunta (P1.4).

### ING-B3. El nivel del contenido no coincide con el nivel que promete

**Evidencia.**
- El Anexo A de Hábitos es un plan de B1 a B2 en 24 semanas. Sobre ese plan se añadió un repaso de A1 a A2 de 4 semanas y la regla de subir un nivel cada bimestre: A2, B1, B1+ y B2 en 28 semanas.
- Los módulos redactados enseñan gramática de A2 con ejemplos de A2: presente simple y continuo (módulo 1), pasado simple y presente perfecto (módulo 2), *will* y *going to* (módulo 3), modales básicos (módulo 4). El repaso A1 → A2 repite esos mismos temas (presente simple, pasado simple, *going to*, *will*, presente continuo).
- 28 semanas × 5 días × 60 minutos = 140 horas. Cambridge estima de 180 a 200 horas guiadas acumuladas para llegar a A2, de 350 a 400 para B1 y de 500 a 600 para B2. De B1 a B2 hay unas 150 a 200 horas; de A2 a B1, otras tantas.
- El primer examen elegido (B1 Preliminary, bimestre 1) pide textos y tareas muy por encima de lo que enseñan los módulos 1 y 2.

**Consecuencia.** O las puertas de nivel se reprueban de forma sistemática (con la regla de bajar de nivel tras dos intentos), o se aprueban con pruebas internas fáciles y la etiqueta deja de significar B1 o B2. Las dos cosas van contra la regla del dueño de no sacrificar la realidad.
**Corrige:** escalera de escalones por bimestre con etiqueta del marco europeo solo al pasar la puerta de cada etapa (decisión D-ING-1), y matriz de niveles que alinea lecciones, ubicación, puertas y exámenes (P1.3).

### ING-B4. Se exigen 60 minutos diarios y hay material para 5 a 10

| Módulo | Palabras por lección (mediana) | Ejercicios con clave por lección (media) | Textos de escucha (palabras) |
|---|---|---|---|
| 1 | 62 | 1.4 | 36, 30, 30, 48 |
| 2 | 105 | 2.5 | 42, 33, 33, 40 |
| 3 | 89 | 2.5 | 38, 42, 38, 36 |
| 4 | 113 | 2.5 | 41, 43, 38, 57 |

Un texto de escucha de 40 palabras dura unos 15 segundos; el plan le asigna 10 minutos, más 10 de repetición. El bloque de traslado (25 minutos, solo audio) no se puede hacer sin audio. La especificación 5a hablaba de lecciones de 5 a 10 minutos y unos 15 minutos al día; después se aprobó una hora diaria y el contenido no creció.

**Consecuencia.** El requisito de "90 % de los minutos planeados" para subir de nivel no se puede cumplir estudiando: solo dejando correr el tiempo.
**Corrige:** plantilla de sesión de 60 minutos con mínimos por bloque que el validador comprueba (P1.1, P1.2: V20 y V21), audio del dispositivo (fase 3) y reescritura por semanas (fase 4).

### ING-B5. La prueba de ubicación es única, corta y ubica de más

**Evidencia.** `prueba-de-nivel.md` (v0.2) y su versión publicada (`prueba-ubicacion.html`):
- Preguntas por nivel: A1 5, A2 9, B1 9, B1+ 5, B2 7. Con 5 preguntas, una sola respuesta decide el nivel.
- El bloque "B1+" (16 a 20) mide *must*, primera condicional, *which*, estilo indirecto simple y *going to* + verbo: es A2 a B1.
- El bloque "B2" (21 a 25) mide pasiva en pasado, segunda condicional, pasado perfecto, orden de la pregunta indirecta y *give up*: es B1.
- La escucha es texto leído; no hay muestra de habla; la escritura depende de una persona revisora que no está definida.
- La regla aprobada es que se aplica una sola vez. La especificación 5a todavía dice que se repite a los 30 días.

**Consecuencia.** Una persona con B1 sólido sale ubicada en "B2" y empezaría en el módulo 5, saltándose cuatro módulos. La decisión no se puede repetir.
**Corrige:** banco nuevo con 12 preguntas por nivel alineadas a la matriz, audio real, zona de duda que ubica abajo con puerta rápida a las dos semanas, y descenso por evidencia en la primera prueba (P2.1, decisión D-ING-5). **Hasta entonces, la página publicada no debe usarse para decidir el nivel.**

## 4. Hallazgos importantes

### ING-I1. Las formas A y B no son independientes, y la práctica repite los simulacros

Oraciones en inglés de 7 palabras o más que aparecen en dos archivos:

| Archivos | Oraciones repetidas | Qué se repite |
|---|---|---|
| `toeic-bimestre-2.md` y `toeic-completo-lectura.md` | 41 | Preguntas de las partes 5 a 7 |
| `cambridge-b1-preliminary-A.md` y `-B.md` | 13 | Toda la Parte 1 de Listening |
| `b1-preliminary-practica-por-partes.md` y `cambridge-b1-preliminary-B.md` | 11 | Tareas de Writing y Speaking |
| `b2-first-practica-por-partes.md` y `cambridge-b2-first-B-escritura-habla.md` | 10 | Ensayo y tareas de Speaking |
| Las dos rondas de práctica de B2 First | 6 | Preguntas de Speaking |
| `toefl-ibt-A.md` con la práctica y con `toefl-ibt-B.md` | 5 y 4 | Frases de repetición y la primera pregunta de Listening |

**Consecuencia.** La segunda oportunidad de una evaluación no es una medición nueva: la persona ya vio las preguntas.
**Corrige:** comprobación de duplicados entre formas y entre banco de práctica y formas (P1.2: V18 y V19).

### ING-I2. Distractores absurdos que regalan la respuesta
En `toefl-ibt-B.md`, Listening tarea 1: "I shoe the horse", "Pens are written", "Lived well.", "Tiredness is a feeling." Nadie los elegiría. En el examen real, las opciones incorrectas son respuestas plausibles a otra pregunta parecida.
**Corrige:** regla de redacción en la habilidad y defensa de distractores en la revisión a ciegas (P1.4).

### ING-I3. No hay explicación por pregunta
Las prácticas traen una "regla por error" por sesión. Quien estudia solo necesita saber, en cada pregunta, por qué la correcta lo es y por qué falló la suya.
**Corrige:** campo obligatorio `porque` en cada pregunta objetiva (P1.1; V12).

### ING-I4. El contenido no es estructurado y las claves están a la vista
- Todo es Markdown con la respuesta junto a la pregunta, en al menos cuatro formatos (`→ **B**`, `**Respuesta: B**`, tablas, `**→ B**`). La app no puede consumirlo y el estudiante ve la clave.
- No hay ninguna comprobación automática. En esta misma sesión aparecieron tarde y a mano: una clave con patrón cíclico B-C-D-A (TOEIC, partes 3 y 4), 31 de 67 respuestas en B (TOEFL A), 20 de 25 en B (B1 A, Listening), las partes 2 y 3 de Listening de B1 intercambiadas, tres opciones donde el manual pide cuatro (TOEIC práctica), preguntas con dos opciones idénticas y una fila de clave escrita en la tabla equivocada.
- Varias de esas correcciones se hicieron con expresiones regulares sobre Markdown y dos veces dejaron archivos inconsistentes que hubo que restaurar.

**Corrige:** fuente única en datos con validación y exportación (P1.1 y P1.2). La posición de la opción correcta se sortea al compilar, con semilla fija, así que la clave deja de tener patrones por construcción.

### ING-I5. Escucha sin audio y habla sin revisión
La decisión de la fuente de audio lleva pendiente desde el inicio del bloque. La rúbrica dice que el habla se autoevalúa y que "la revisión" llega después, sin decir quién revisa.
**Corrige:** voz del dispositivo como fuente de audio (decisión D-ING-3, fase 3) y revisión cruzada en pareja con lista de cotejo (fase 6).

### ING-I6. La rúbrica reprueba el desempeño "sólido" sin decirlo
Con escala de 0 a 4 y umbral de 80 %, sacar 3 ("sólido") en todos los criterios da 75 % y no aprueba. En las pruebas objetivas de 3 o 4 preguntas, el 80 % equivale a no fallar ninguna. Es coherente con la exigencia del dueño, pero hoy no está escrito como consecuencia.
**Corrige:** decisión D-ING-6 (confirmar el significado de aprobar) y mínimo de 10 preguntas objetivas por habilidad en cada prueba de módulo (P1.1).

### ING-I7. La especificación 5a contradice decisiones posteriores
| Tema | Especificación 5a (v0.4) | Decidido después |
|---|---|---|
| Tiempo diario | Unos 15 minutos | 60 minutos, lunes a viernes |
| Punto de partida | B1 → B2 | Ubicación de A1 a B2 |
| Prueba de nivel | Se repite a los 30 días | Una sola vez |
| Exámenes simulados | Fuera del alcance | Construidos para cuatro exámenes |
| Audio | Fuera, falta decidir la fuente | Necesario para el bloque de traslado |

Además, las semanas se numeran distinto según el documento: los módulos usan 1 a 24 (módulo 3 = semanas 9 a 12), el calendario de niveles usa 28 con el repaso al inicio (bimestre 2 = semanas 13 a 20) y la rúbrica cita las semanas 4, 8, 12, 16, 20 y 24.
**Corrige:** especificación v0.5 del bloque (P0.3) después de las decisiones del dueño.

### ING-I8. Gobierno del bloque
- El bloque de inglés no aparece en el control de cambios del roadmap, aunque es el trabajo más grande de las últimas sesiones.
- `docs/contenido/` no está en las carpetas de ningún agente (roadmap, 11.2).
- Se creó la rama `claude/ubicacion-ingles` en el repositorio de Hábitos. Por D10 ese repositorio es historial archivado: todo vive en GRAVITY. La nota `especificacion-ubicacion-en-app.md` afirmaba que la app no tenía código; el módulo Hábitos existe en `app/lib/modulos/habitos` desde la Fase 3.
- La rama `claude/integracion-ingles-main` de GRAVITY contiene solo un commit de merge sobre `main` y sigue abierta.
- `CONTEXTO.md` tenía filas duplicadas y pasos de retoma ya cumplidos.
- La regla de redactar cada módulo solo después de aprobar el anterior convierte al dueño en cuello de botella de un tema que él mismo declara no dominar: los módulos 3 y 4 llevan pendientes desde su redacción.

**Corrige:** P0.1, P0.3 y P0.4, y decisión D-ING-4 (aprobar plantillas y muestras en lugar de cada documento).

### ING-I9. No hay equivalencia con las escalas oficiales
Ningún simulacro se traduce a la escala del examen (Cambridge English Scale, 10 a 990 de TOEIC, escala de TOEFL 2026). Está anotado como pendiente desde el inicio.
**Corrige:** semáforo de preparación por zonas, sin puntajes inventados, y verificación de cada escala en su fuente antes de mostrar cualquier conversión (fase 5).

## 5. Hallazgos menores

- **ING-M1.** Instrucciones y preguntas en español dentro de simulacros de examen (por ejemplo, Listening de B1 A). Los exámenes van completos en inglés. En las lecciones de A1 y A2, el apoyo en español sí conviene.
- **ING-M2.** Ortografía británica y americana mezcladas (*behaviour*, *programme* junto a formas americanas). Conviene una por examen: británica en Cambridge, americana en TOEIC y TOEFL.
- **ING-M3.** Las prácticas viven unas en la raíz y otras en `simulacros/`; los nombres no siguen un patrón.
- **ING-M4.** `toefl-ibt-A.md`, línea 82: falta un espacio antes de la opción A tras el último reordenamiento.
- **ING-M5.** Parte 4 de B2 First A: los huecos dibujan tres rayas para respuestas de cuatro palabras.
- **ING-M6.** `toeic-completo-lectura.md` tiene 9 textos sencillos en la Parte 7; el formato registrado indica 10.

## 6. Lo que está bien y se conserva

- Las reglas del dueño son claras y exigentes: puertas con 80 % por habilidad sin compensar, dos oportunidades, días de gracia, constancia medida.
- El ritmo semanal por enfoque (gramática, escucha, pronunciación, lectura y escritura, conversación) y la plantilla de lección son consistentes en los cuatro módulos.
- Todo el contenido es original: no hay preguntas copiadas de Cambridge ni de ETS.
- El número de preguntas por parte ya coincide con los manuales en B1 Preliminary, B2 First, TOEIC y TOEFL.
- Las reglas de emparejamiento en pareja (resultados individuales, nadie frena al otro) son correctas.
- La app tiene lo necesario para alojar el bloque: módulo Hábitos con rachas y día de gracia en `paquetes/habitos_dominio`, cola sin conexión, avisos discretos y el submódulo de diseño `ingles`.
- Hay un precedente dentro del proyecto para contenido con formato versionado y validador: `herramientas/biblia` y el formato `gravity-biblia-v1`.

## 7. En pocas palabras, para el dueño

1. Lo escrito sirve como borrador, no como medida. Hoy no conviene presentar ningún simulacro como "completo" ni usar la prueba de ubicación publicada.
2. El problema de fondo no es de cantidad sino de control: se produjo mucho sin una forma automática de comprobarlo. El plan pone primero esa forma de comprobar y después produce.
3. La promesa de un nivel del marco europeo por bimestre no se sostiene con 5 horas a la semana. La propuesta mantiene tu regla (cada bimestre subes un escalón si cumples todo) y reserva las etiquetas A2, B1 y B2 para cuando se pasa la puerta de cada etapa.
