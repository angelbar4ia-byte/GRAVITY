# Plan de ejecución — Fase 8, bloque 5 (Hábitos · Inglés)

> Versión 0.1 (14/nov/2026). **Propuesta para aprobación del dueño.**
> Ejecuta: el equipo de agentes del roadmap (sección 11), todos en **Sonnet 5.5** por la regla 11.1.10. Orquesta e integra: el arquitecto.
> Base: revisión `docs/revisiones/fase-8-ingles.md` (5 bloqueantes, 9 importantes) y formato `docs/specs/fase-8-ingles-formato.md`.
> No cambia ninguna decisión confirmada por su cuenta: lo que requiere al dueño está en la sección 4.

## 1. Resultado que se busca

Un programa de inglés dentro de GRAVITY (módulo Hábitos) que:

1. Ubica a cada persona **una sola vez** y con justicia.
2. Le da **una hora diaria de práctica real**, no una hora de reloj.
3. Le dice **la verdad** sobre su nivel y sobre si está lista para un examen.
4. Funciona **sin conexión** y sin IA, como pide la especificación 5a.
5. Se produce y se revisa con agentes Sonnet **sin depender de que alguien lea cada pregunta**.

Palabras que usa este plan:

| Palabra | Significa |
|---|---|
| Escalón | Tramo de 8 semanas con su prueba al final. Cada bimestre se sube un escalón si se cumple todo |
| Etapa | Nivel del marco europeo: A1, A2, B1 o B2. Una etapa tiene de 2 a 4 escalones |
| Puerta | La prueba que hay que pasar para subir: de escalón (interna) o de etapa (con formato de examen oficial) |
| Unidad | Un texto, audio o consigna con sus preguntas |
| Forma | Una prueba armada con unidades. Dos formas del mismo examen no comparten nada |
| Fidelidad | Cuánto se parece una forma al examen oficial: completa o reducida. La calcula la herramienta |
| Resolución a ciegas | Otro agente contesta la prueba sin ver la clave; si no coincide, la pregunta se corrige o se retira |

## 2. Principios

1. **Primero los rieles, después el contenido.** Hasta ahora se escribió mucho sin forma de comprobarlo. Se construye primero el formato y el validador; después se produce.
2. **Lo que no se mide, no se afirma.** Ningún documento dice "completo" o "verificado" a mano. El estado lo calcula la herramienta.
3. **Una sola fuente.** El contenido vive en datos (`data/ingles/`). El cuaderno del estudiante, la clave y lo que carga la app se generan de ahí.
4. **Fidelidad por contrato.** Cada examen tiene su contrato tomado del manual oficial: partes, preguntas, opciones, longitud de textos, tiempos y número de veces que se oye el audio.
5. **Nadie revisa su propio trabajo.** Toda pregunta objetiva se resuelve a ciegas por otro agente antes de llegar a la app.
6. **Las etiquetas A2, B1 y B2 se ganan en una puerta, no en un calendario.**
7. **El dueño aprueba plantillas y muestras, no cada documento.** Puede vetar cualquier pieza cuando quiera.

## 3. Diseño propuesto

### 3.1 Escalera de niveles

Se conserva la regla del dueño: **cada bimestre se sube si se cumple todo; si no, no se sube**. Lo que cambia es qué se sube: un **escalón**. La etiqueta del marco europeo se obtiene al pasar la puerta de la etapa, que tiene formato de examen oficial.

| Etapa | Escalones (8 semanas cada uno) | Puerta de la etapa |
|---|---|---|
| A1 | A1.1, A1.2 | Prueba interna de A1 |
| A2 | A2.1, A2.2 | Forma completa tipo **A2 Key** |
| B1 | B1.1, B1.2, B1.3 | Forma completa tipo **B1 Preliminary** |
| B2 | B2.1, B2.2, B2.3, B2.4 | Forma completa tipo **B2 First** |

- Los seis módulos del Anexo A (y los temas ya aprobados de los módulos 1 y 2) son la etapa B1: B1.1 = módulos 1 y 2, B1.2 = módulos 3 y 4, B1.3 = módulos 5 y 6. Se reescriben con profundidad de B1 y con la plantilla de 60 minutos.
- El repaso A1 → A2 de un mes deja de ser un bloque para todos: quien salga ubicado en A2 hace los escalones de A2; quien salga en B1 con huecos de A2 recibe repaso dirigido en sus primeras semanas.
- TOEIC y TOEFL son rutas de preparación opcionales que se abren desde B1.2 y B2.1. No son puertas.
- El temario de cada escalón está en el anexo B.

**Tiempos honestos**, con 5 horas a la semana (40 horas por escalón) y aprobando todo a la primera:

| Empiezas en | Para llegar a | Escalones | Semanas | Horas | Horas guiadas acumuladas que estima Cambridge para ese nivel |
|---|---|---|---|---|---|
| Cero | A2 | 4 | 32 | 160 | 180 a 200 |
| A2 | B1 | 3 | 24 | 120 (280 acumuladas) | 350 a 400 |
| B1 | B2 | 4 | 32 | 160 (440 acumuladas) | 500 a 600 |

El plan es más rápido que la estimación de Cambridge. Lo normal será repetir algún escalón, y eso no es un fracaso: es lo que dice la medición.

### 3.2 Sesión de 60 minutos real

Se respetan los tiempos aprobados (principal 35: repaso 5, lección 10, pronunciación 8, producción 12; traslado 25: escucha 10, repetición 10, tarjetas 5). Cada bloque tiene **mínimos de contenido** que el validador comprueba: por ejemplo, 10 preguntas en la lección del lunes, audio de 200 a 350 palabras en B1, 12 frases para repetir y una tarea de producción con lista de cotejo y respuesta modelo. Detalle en el formato, sección 7.

### 3.3 Ubicación: una vez, pero justa

- **48 preguntas**, 12 por etapa (6 de gramática y vocabulario, 3 de lectura, 3 de escucha con audio), alineadas al temario. Una etapa se alcanza con 10 de 12 y con todas las anteriores alcanzadas. La app deja de preguntar tras la primera etapa no alcanzada.
- El resultado decide **la etapa de entrada**: se empieza en el primer escalón de la etapa siguiente a la última alcanzada.
- No se repite. Los errores de ubicación se corrigen con evidencia, no con otra prueba de ubicación:
  - **Hacia arriba, puerta anticipada:** en la semana 2 de un escalón se puede presentar su puerta. Con 90 % o más en cada habilidad se pasa al siguiente escalón. No gasta ninguna de las dos oportunidades.
  - **Hacia abajo, descenso por evidencia:** dos mini pruebas seguidas por debajo de 50 % bajan un escalón, sin penalización.
- Las preguntas de ubicación no se usan en ningún otro lugar.
- En el servidor, una persona solo puede tener un registro de ubicación.

### 3.4 Exámenes

- Cada examen tiene contrato, banco por parte con longitud oficial, práctica por partes y dos formas completas más una de reserva.
- Lo que hoy existe se reetiqueta como **formato reducido** y sirve de práctica mientras se construyen las formas completas.
- **Semáforo de preparación por zonas**, sin puntajes inventados: rojo (menos de 60 % en alguna prueba), amarillo (60 a 79 %), verde (80 % o más en todas las pruebas de dos formas completas, con audio y con el tiempo oficial). La conversión a la escala de cada examen solo se muestra cuando esa escala esté verificada en su fuente.
- TOEFL iBT 2026 se rehace en tres puntos: "Completar palabras" con texto, conjuntos de 2 y 3 preguntas, y dos etapas (módulo de ruta y módulo inferior o superior).

### 3.5 Audio y habla

- **Audio:** la voz del propio dispositivo lee los guiones (paquete `flutter_tts`). Cuesta cero, funciona sin conexión y no tiene licencias que resolver porque los guiones son propios. Detrás de una interfaz, para poder cambiarlo por audio grabado sin tocar el contenido. El guion no se muestra hasta después de contestar.
- **Habla:** grabación local (no sale del dispositivo), autoevaluación con lista de cotejo y respuesta modelo. La revisión cruzada en pareja llega en la fase 6.

### 3.6 En la app

- **Servidor:** tablas `ing_*` (perfil, ubicación única, sesiones, tarjetas, pruebas) con reglas por persona como las de `hab_*`. Solo-agregar en ubicación, sesiones y pruebas. La cuenta maestra no las lee (D21).
- **Dominio:** `paquetes/habitos_dominio`, carpeta `ingles`: repaso espaciado, sesión completa y minutos, reglas de puertas, ubicación, puerta anticipada y descenso.
- **Pantallas:** Inicio de inglés, Ubicación, Sesión del día por bloques, Tarjetas, Progreso y puertas. El contenido viaja dentro de la app (`app/assets/ingles/`), así que estudiar no usa la red.

### 3.7 Pareja

Cada quien tiene su ruta. Si coinciden de escalón, comparten calendario y actividades. Si no, cada uno sigue la suya y hay un reto semanal que no depende del nivel. Es la fase 6 y necesita su propia especificación, porque hoy el progreso es privado.

## 4. Decisiones que necesita el dueño

| # | Decisión | Recomendación | Mientras no respondas |
|---|---|---|---|
| D-ING-1 | Escalera de 11 escalones; la etiqueta del marco europeo se obtiene en la puerta de la etapa | **Sí.** Mantiene tu regla y hace verdadera la etiqueta | No se redacta contenido nuevo de curso |
| D-ING-2 | Hora diaria con la plantilla nueva. Mientras no haya audio, cuenta solo el bloque principal (35 minutos) y el requisito del 90 % se calcula sobre eso | **Sí** | Igual que D-ING-1 |
| D-ING-3 | Audio con la voz del dispositivo (`flutter_tts`) | **Sí.** Se puede cambiar después por audio grabado | La escucha sigue en texto y los simulacros quedan como reducidos |
| D-ING-4 | Apruebas plantillas y muestras; el contenido pasa con validación, revisión a ciegas y muestreo de calidad | **Sí.** Hoy los módulos 3 y 4 esperan tu lectura y tú mismo dices que no es tu tema | Cada pieza espera tu aprobación, como ahora |
| D-ING-5 | Ubicación única con puerta anticipada y descenso por evidencia | **Sí.** Y no usar la página publicada para decidir el nivel hasta la versión 3 | La ubicación no se construye |
| D-ING-6 | En escritura y habla, aprobar es promedio de 3.2 sobre 4 y ningún criterio debajo de 3: sacar 3 en todo **no** aprueba. Pruebas objetivas de 10 preguntas o más por habilidad | **Confirmar.** Es lo que ya dice el 80 %, escrito con todas sus letras | Se aplica el 80 % como está |
| D-ING-7 | Orden: primero B1.1 y la ubicación; después A2.1. Exámenes: B1 Preliminary, A2 Key, TOEIC, B2 First, TOEFL | **Sí.** Se reordena con el resultado real de la ubicación | Se sigue este orden |
| D-ING-8 | Borrar la rama `claude/ubicacion-ingles` del repositorio archivado de Hábitos y la rama `claude/integracion-ingles-main`. Llevar el trabajo a `main` por pull request cuando lo pidas | **Sí** | Las ramas quedan como están |

Las que se aprueben se registran en `docs/DECISIONES.md` como una decisión nueva (D29).

## 5. Cómo se ejecuta con Sonnet

### 5.1 Quién hace qué

| Agente | En este bloque | Carpetas para este bloque |
|---|---|---|
| **arquitecto** | Orquesta, lanza paquetes, integra, corre todas las pruebas, hace commit, mantiene este plan, el roadmap y las habilidades | Todo (integración), `.claude/skills/` |
| **habitos** | Formato, herramienta, contenido, dominio y pantallas de inglés | `data/ingles/`, `herramientas/ingles/`, `docs/contenido/ingles/`, `docs/specs/fase-8-habitos-*`, `docs/specs/fase-8-ingles-formato.md`, `paquetes/habitos_dominio/`, `app/lib/modulos/habitos/` |
| **calidad** | Resolución a ciegas, muestreo y revisión de cierre | `docs/revisiones/` (las respuestas a ciegas van en `docs/revisiones/ingles/`) y pruebas en `test/` |
| **backend** | Tablas `ing_*`, reglas por persona y pruebas SQL | `supabase/` |
| **plataforma** | Recursos de la app, cola sin conexión, recordatorio, paquete de voz y permisos | Las suyas |
| **diseno** | Componentes del submódulo `ingles` | Las suyas |
| **asistente** | Herramientas de GRAVITY y OpenAPI de lo nuevo | Las suyas |

Todos los agentes ya están fijados en Sonnet 5.5 en su definición. La sesión que orquesta también puede ser Sonnet: este plan convierte cada juicio en una regla o en una comprobación, para no depender de un modelo más fuerte.

### 5.2 Forma de un paquete

- Un paquete cabe en una sola corrida de un agente: una semana de curso (5 sesiones), una parte de un examen (hasta 12 unidades) o un módulo de código con sus pruebas. Si no cabe, se parte.
- Todo paquete de contenido recorre el mismo camino: **autor → `validar` → cuaderno → revisor a ciegas → `comparar` → correcciones → integración**.
- Un commit por paquete, hecho por el arquitecto.

### 5.3 Encargo tipo

```
Ejecuta el paquete <ID> del plan de inglés.

Lee primero, en este orden:
1. CLAUDE.md y docs/ROADMAP.md, sección 11.1.
2. docs/specs/fase-8-ingles-plan.md: secciones 2 y 5, y la ficha del paquete <ID>.
3. docs/specs/fase-8-ingles-formato.md.
4. <entradas propias del paquete>.

Tus carpetas para este paquete: <lista>. No escribas fuera de ellas.
Entregables: <lista>.
Hecho cuando: <comandos y resultado esperado>.
No hagas commit. No cambies decisiones: si te falta una, detente y dilo en el reporte.
Reporte: el de la sección 5.4 del plan.
```

Para el revisor a ciegas, el encargo solo incluye la ruta del cuaderno exportado y la del archivo de respuestas que debe escribir. No recibe la ruta de las fuentes.

### 5.4 Reporte de cada agente

1. Qué hizo, en tres líneas.
2. Archivos creados o cambiados.
3. Comandos corridos y su salida final, pegada tal cual.
4. Conteos: unidades, preguntas, palabras por estímulo, minutos estimados (salida de `informe`).
5. Lo que no pudo hacer y por qué.
6. Preguntas para el dueño.

### 5.5 Hecho cuando

| Tipo de paquete | Condiciones |
|---|---|
| Contenido | `validar` sin errores · revisión a ciegas sin disputas abiertas · sin duplicados (V19, V20) · reporte con la salida de `informe` · ningún estado escrito a mano por encima de `validado` |
| Herramienta | `dart analyze` sin problemas · `dart test` en verde, con al menos un caso malo por cada comprobación · los ejemplos patrón pasan |
| App | `flutter analyze` sin errores · `flutter test --exclude-tags hallazgo` en verde · pruebas nuevas para cada criterio de la especificación |
| Servidor | Migraciones aplican en limpio · `bash supabase/tests/correr.sh` en verde |
| Cierre de fase | Revisión de calidad en `docs/revisiones/` sin bloqueantes abiertos |

Flutter y Dart están en `/home/user/tools/flutter/bin`.

### 5.6 Reglas que salen de los errores de esta etapa

1. **No afirmes sin respaldo.** "Verificado" lleva la página del manual o el comando. Si no pudiste comprobar algo, se queda como pendiente.
2. **No edites contenido con expresiones regulares.** Se edita la fuente, se valida y se exporta. Dos correcciones masivas sobre Markdown dejaron archivos inconsistentes.
3. **No escribas letras de respuesta.** La correcta es la primera opción de la fuente; el sorteo es de la herramienta.
4. **Si una pregunta se puede discutir, está mal.** Ante una disputa no se argumenta: se reescribe o se retira.
5. **Distractores plausibles.** Cada opción incorrecta es la respuesta correcta a una pregunta parecida o un error típico del nivel. Nunca una frase absurda.
6. **Huecos abiertos: palabras gramaticales y todas las respuestas válidas.** Si caben más de tres palabras de contenido, el hueco está mal elegido.
7. **Nada se usa dos veces.** Ni entre formas, ni entre práctica y forma, ni entre ubicación y lo demás.
8. **Longitud del contrato o etiqueta de reducido.** No hay término medio.
9. **Lo generado no se toca.** Si el cuaderno está mal, se corrige la fuente.
10. **Si falta una decisión del dueño, el paquete se detiene.** No se asume.
11. **El revisor no ve la clave.** Y el autor no resuelve su propia prueba.
12. **Si el contenido cambia después de la revisión, la revisión caduca.** Lo detecta la huella.

### 5.7 Paralelismo e integración

- Hasta 4 agentes a la vez, siempre en carpetas distintas.
- Los subpaquetes de la herramienta van en serie. Las semanas del curso y las partes de un examen pueden ir en paralelo.
- Al integrar, el arquitecto corre `validar` sobre todo `data/ingles` (los duplicados solo se ven en conjunto), la suite de la app si hubo código, y actualiza el estado en este plan.
- Si un paquete falla dos veces su condición de hecho, no se intenta una tercera: el arquitecto revisa el encargo.

## 6. Fases y paquetes

### Resumen

| Fase | Para qué | Paquetes | Necesita del dueño |
|---|---|---|---|
| 0 · Orden y decisiones | Dejar de afirmar lo que no es cierto y destrabar decisiones | P0.1 a P0.4 | D-ING-1 a 8 |
| 1 · Rieles | Formato, contratos, herramienta, niveles, revisión a ciegas y piloto | P1.1 a P1.5 | Aprobar el piloto |
| 2 · Ubicación y núcleo en la app | Ubicarse una vez y estudiar la sesión del día | P2.1 a P2.6 | Proyecto de Supabase (pendiente desde la Fase 0) |
| 3 · Audio y habla | Escuchar de verdad; traslado solo con audio; grabarse | P3.1 a P3.3 | D-ING-3 y probar en el teléfono |
| 4 · Curso por escalones | Producir el curso, siempre dos semanas por delante de quien estudia | Por semana | Muestreo |
| 5 · Exámenes | Formas con fidelidad completa y semáforo | Por examen y parte | Muestreo |
| 6 · Pareja y extras | Estudiar juntos, revisión cruzada, IA opcional | Por definir | Especificación propia |

### Fase 0 · Orden y decisiones

**P0.1 · Etiquetas honestas** · habitos
- Entradas: revisión ING-B1 e ING-B5.
- Hace: en el bloque de contexto de cada simulacro y de cada práctica, cambia "completo" por "formato reducido: mismo número de preguntas, textos más cortos y sin audio". En `prueba-de-nivel.md` añade "en revisión: no usar para decidir el nivel". Corrige ING-M4. No toca preguntas.
- Hecho cuando: ningún encabezado de `docs/contenido/ingles/` afirma formato completo; el aviso está en la prueba. La página publicada la actualiza el arquitecto.

**P0.2 · Decisiones del dueño** · arquitecto
- Hace: recoge las respuestas de la sección 4, las registra aquí y en `docs/DECISIONES.md` (D29) y ajusta el resto del plan.

**P0.3 · Especificación v0.5 del bloque** · habitos (redacta), arquitecto (integra) · depende de P0.2
- Hace: reescribe el bloque 5 de `docs/specs/fase-8-habitos-ampliaciones.md` en sub-bloques (5a núcleo en la app, 5b audio y habla, 5c ubicación, 5d exámenes, 5e pareja). Resuelve las contradicciones de ING-I7, fija el modelo de datos `ing_*`, numera los criterios de aceptación y deja una sola numeración de semanas (1 a 8 dentro de cada escalón).
- Hecho cuando: cada criterio se puede probar; calidad no encuentra contradicciones con `DECISIONES.md`.

**P0.4 · Ramas** · arquitecto · depende de D-ING-8
- Hace: borra las dos ramas indicadas y, cuando el dueño lo pida, abre el pull request a `main`.

### Fase 1 · Rieles

**P1.1 · Contratos de formato** · habitos
- Entradas: manuales oficiales citados en `formatos-oficiales.md`, más el manual de A2 Key.
- Hace: `data/ingles/formatos/` con `cambridge-a2-key`, `cambridge-b1-preliminary`, `cambridge-b2-first`, `toeic-lr`, `toeic-sw`, `toefl-ibt-2026`, `gravity-sesion-60`, `gravity-ubicacion` y `gravity-escalon`. Cada dato con la página del manual. Lo que no se pueda leer queda como pendiente; no se completa de memoria.
- Hecho cuando: `validar data/ingles/formatos` sin errores y calidad contrasta 10 datos al azar de cada contrato con el PDF.

**P1.2 · Herramienta `herramientas/ingles`** · habitos · tres subpaquetes en serie
- P1.2a: modelo, lectura de YAML, comprobaciones V01 a V14 y estados básicos (V24), orden `validar`.
- P1.2b: contratos y fidelidad (V15 a V20), orden `informe`.
- P1.2c: `exportar` con sorteo (V06, V26), `comparar` con huella (V24), sesiones (V21 a V23) y `compilar` (V25).
- Hecho cuando: lo de "Herramienta" en 5.5, y `README.md` con todas las órdenes.

**P1.3 · Matriz de niveles** · habitos; revisa calidad · depende de D-ING-1
- Hace: `data/ingles/niveles.yaml` con los 11 escalones (gramática, funciones, vocabulario y descriptores "puedo" por habilidad), las listas controladas, y `niveles-y-avance.md` en versión 0.4 con la escalera, la puerta anticipada y el descenso.
- Hecho cuando: cada tema de gramática es "nuevo" en un solo escalón; cada escalón tiene descriptores para las cuatro habilidades; calidad contrasta 10 temas al azar con el manual del examen de su etapa.

**P1.4 · Revisión a ciegas y habilidades** · calidad (protocolo), arquitecto (habilidades)
- Hace: una corrida de punta a punta con un ejemplo patrón (exportar, resolver, comparar). Crea la habilidad `leccion-idioma` (cómo redactar una sesión) junto a `simulacro-examen-idioma`, ya actualizada.
- Hecho cuando: la revisión queda escrita en `data/ingles/revisiones/` y una disputa provocada a propósito se detecta.

**P1.5 · Piloto vertical** · habitos, calidad y dueño · depende de P1.1 a P1.4, D-ING-1, D-ING-2 y D-ING-4
- Hace: (1) la semana 1 de B1.1 completa, con la plantilla de 60 minutos; (2) una unidad de Reading 3 y una de Listening 3 de B1 Preliminary con longitud oficial; (3) 12 preguntas de ubicación, 3 por etapa.
- Hecho cuando: todo en `revisado`; cuadernos exportados; el dueño aprueba la plantilla o pide cambios en una sola ronda.

### Fase 2 · Ubicación y núcleo en la app

**P2.1 · Prueba de ubicación, versión 3** · habitos; calidad resuelve a ciegas con dos agentes distintos · depende de P1.3 y P1.5
- Hace: banco de 72 preguntas (18 por etapa) y forma de 48, con el contrato `gravity-ubicacion`.
- Hecho cuando: las dos resoluciones a ciegas coinciden con la clave en todas las preguntas; V20 sin errores.

**P2.2 · Servidor** · backend · depende de P0.3
- Hace: migración con las tablas `ing_*`, reglas por persona y pruebas SQL: otra persona no lee, la cuenta maestra no lee, una segunda ubicación se rechaza, no hay edición ni borrado en ubicación, sesiones y pruebas.

**P2.3 · Dominio** · habitos · depende de P0.3
- Hace: repaso espaciado, sesión completa y minutos, puertas (80 % por habilidad, dos oportunidades, días de gracia, 90 % de minutos), ubicación, puerta anticipada y descenso. Con pruebas de los casos límite.

**P2.4 · Pantallas y plataforma** · habitos, diseno y plataforma · depende de P2.2, P2.3 y `compilar`
- Hace: Inicio de inglés, Ubicación (se puede pausar y reanudar, no reiniciar), Sesión del día, Tarjetas y Progreso. Recursos en `app/assets/ingles/`, cola sin conexión y recordatorio local discreto. Sin audio, el traslado aparece como "disponible cuando haya audio" y no cuenta minutos.

**P2.5 · Herramientas y API** · asistente
- Hace: `habitos.ingles_hoy`, navegación y OpenAPI de lo nuevo.

**P2.6 · Revisión de calidad de la fase** · calidad
- Revisa: privacidad (Hábitos es personal), reglas por persona, una sola ubicación, estudio sin red y accesibilidad.

### Fase 3 · Audio y habla · depende de D-ING-3

- **P3.1 · Especificación** · plataforma y habitos: interfaz de fuente de audio, reproductor (reproducciones según contrato, velocidad 0.8 y 1.0, guion oculto hasta contestar) y grabación local.
- **P3.2 · Construcción** · plataforma (paquete y permisos) y habitos (bloques de escucha, repetición y traslado solo con audio), con una fuente de audio simulada para las pruebas.
- **P3.3 · Verificación en dispositivo** · dueño: voces en inglés instaladas en el Galaxy A52 y en Windows, sin conexión. Conviene hacerla antes de producir muchos guiones.

### Fase 4 · Curso por escalones · depende de aprobar el piloto

- **Unidad de trabajo:** una semana. El autor (habitos) entrega 5 sesiones, 2 audios de traslado, 32 tarjetas y la mini prueba. El revisor (calidad) la resuelve a ciegas.
- **Por escalón:** 8 semanas más su puerta, con tres formas (dos oportunidades y una reserva).
- **Orden inicial:** B1.1, A2.1, B1.2, A2.2, B1.3, A1.1, A1.2, B2.1 a B2.4. Tras la ubicación real del dueño y de su pareja, sube al frente el escalón donde caiga cada uno.
- **Ritmo:** el contenido va dos semanas por delante de quien estudia. No hace falta terminar el curso para empezar a usarlo.
- **Semillas:** los módulos 1 y 2 aprobados dan los temas de B1.1; el 3 y el 4, de B1.2.

### Fase 5 · Exámenes · depende de la fase 1

Cuatro pasos por examen, cada uno por partes:
1. **Triaje** de lo que existe: cada pregunta se conserva, se corrige o se descarta al pasarla a unidades (sección 7).
2. **Banco por parte** con la longitud del contrato.
3. **Dos formas completas y una de reserva**, que no comparten nada entre sí ni con el banco de práctica.
4. **Práctica por partes** generada desde el banco.

Orden: B1 Preliminary (también es la puerta de B1), A2 Key (puerta de A2), TOEIC Listening y Reading, B2 First (puerta de B2), TOEFL iBT 2026, TOEIC Speaking y Writing.

### Fase 6 · Pareja y extras

Especificación primero: emparejamiento por escalón, actividades en pareja, revisión cruzada de habla y escritura con lista de cotejo, y qué ve cada quien del otro, con consentimiento. La corrección con IA es opcional y posterior; no toca dinero ni datos clínicos, pero necesita su propia especificación.

## 7. Qué pasa con lo que ya existe

| Documento | Destino |
|---|---|
| `modulo-1.md`, `modulo-2.md` (aprobados) | Semilla de temas de B1.1. Se conservan como historial; el contenido ampliado vive en `data/ingles/curso/b1-1/` |
| `modulo-3.md`, `modulo-4.md` | Semilla de B1.2. Con D-ING-4 no necesitan aprobación por separado |
| `prueba-de-nivel.md` y `prueba-ubicacion.html` | Aviso de "en revisión" (P0.1). Se retiran al publicar la versión 3 (P2.1) |
| `rubrica-evaluacion.md` | Se conserva. Se ajusta con D-ING-6 y da origen a las listas de cotejo |
| `niveles-y-avance.md` | Versión 0.4 con la escalera (P1.3) |
| `formatos-oficiales.md` | Su contenido pasa a los contratos (P1.1) |
| B1 Preliminary A y B | Sus preguntas válidas pasan al banco como práctica reducida. Las formas completas se escriben nuevas |
| B2 First A y B | Partes 2, 3 y 6 se rehacen. Partes 1, 4, 5 y 7 se corrigen; por su dificultad sirven como práctica de B1 |
| TOEIC completo | Partes 1, 2 y 5 se conservan. Partes 3, 4, 6 y 7 se amplían a la longitud del contrato. Se eliminan las 41 oraciones repetidas con `toeic-bimestre-2.md` |
| TOEFL A y B | "Completar palabras" se rehace con texto. El resto se reorganiza en conjuntos de 2 y 3 y se reescriben los distractores absurdos |
| Prácticas por partes (cinco documentos) | Se regeneran desde el banco. Hasta entonces quedan como reducidas |
| `guia-multiexamen.md`, `cambridge-y-toefl.md`, `toeic.md`, `simulacros/bimestre-3.md`, `cobertura-practica.md` | Los sustituyen la especificación v0.5 y el `informe` de la herramienta. Se archivan |

## 8. Orden y primer lote

**Ruta crítica hasta el primer uso real** (el dueño y su pareja se ubican en la app y empiezan su escalón):

```
D-ING-1,2,4,5 ─► P1.3 ─► P1.5 (piloto) ─► P2.1 (ubicación) ─┐
P1.1 ─► P1.2a ─► P1.2b ─► P1.2c ─────────────────────────────┼─► P2.4 (pantallas) ─► primer uso
P0.3 ─► P2.2 (servidor) y P2.3 (dominio) ────────────────────┘
En paralelo: fase 4 (primeras dos semanas de B1.1 y de A2.1) y, con D-ING-3, fase 3 (audio)
```

**Primer lote, sin esperar ninguna decisión:** P0.1, P1.1, P1.2a y P1.4.
**Segundo lote, con D-ING-1, 2 y 4:** P1.2b, P1.2c, P1.3, P0.3 y P1.5.

## 9. Riesgos

| Riesgo | Cómo se controla |
|---|---|
| El volumen es grande: 11 escalones y 6 exámenes | Producir por delante de quien estudia, no todo antes de empezar. Priorizar por la ubicación real |
| Preguntas de B2 escritas por agentes | Ejemplos patrón, resolución a ciegas doble en ubicación y puertas, muestreo del dueño con el cuaderno |
| La voz del dispositivo suena mal o no está instalada | Interfaz de fuente de audio y verificación temprana (P3.3) |
| No hay población para calibrar la dificultad | Zonas en lugar de puntajes; ubicación corregida con evidencia; registro de aciertos por pregunta para retirar las que fallen sin razón |
| La especificación de TOEFL 2026 puede cambiar | Contrato con fecha de consulta; se revisa antes de producir sus formas |
| El dueño como cuello de botella | D-ING-4 |
| Documentos que se contradicen | Una fuente y un informe generado |
| Derechos de autor | Todo el contenido es propio. Los contratos citan la página del manual; no copian texto |

## 10. Cuándo se da por cerrado el bloque

- `validar` sin errores en todo `data/ingles`.
- Toda pregunta objetiva que llega a la app tiene revisión a ciegas vigente.
- Ningún duplicado entre formas ni entre ubicación, puertas y práctica.
- Toda forma dice su fidelidad, calculada por la herramienta.
- Toda sesión estima entre 54 y 66 minutos.
- Una sola ubicación por persona, comprobada en el servidor.
- Suites de la app, del dominio y del servidor en verde, y revisión de calidad sin bloqueantes.

## Anexo A. Estado de los paquetes

| Paquete | Estado | Nota |
|---|---|---|
| Revisión del bloque | Hecho (14/nov/2026) | `docs/revisiones/fase-8-ingles.md` |
| Formato `gravity-ingles-v1` | Propuesto (14/nov/2026) | `docs/specs/fase-8-ingles-formato.md` |
| Ejemplos patrón | En curso | `data/ingles/ejemplos/` |
| Habilidad `simulacro-examen-idioma` | En curso | Con las reglas de 5.6 |
| P0.1 a P0.4, fases 1 a 6 | Pendientes | Esperan la orden del dueño |

## Anexo B. Temario por escalón (propuesta para P1.3)

| Escalón | Gramática nueva | Puedo… | Origen |
|---|---|---|---|
| A1.1 | *to be*, pronombres, *a / an / the*, plurales, *this / that*, posesivos, *there is / are*, presente simple en afirmativa; números, horas y fechas | Presentarme y hablar de mi familia y mis cosas | Repaso R1 |
| A1.2 | Presente simple en negativa y pregunta, adverbios de frecuencia, *can*, *like + -ing*, imperativos, preposiciones de lugar y tiempo, *some / any* | Describir mi día y pedir datos simples | Repaso R2 |
| A2.1 | Presente simple y continuo, pasado simple, *was / were*, contables e incontables, comparativos y superlativos, *going to* | Contar lo que hice, comparar y hablar de planes | Repaso R3 |
| A2.2 | Presente perfecto (experiencias; *just, already, yet*), *will*, *have to / must / should*, pasado continuo, primera condicional (inicio), *too / enough*, relativos (inicio) | Contar experiencias, dar consejos y predecir. **Puerta A2** | Repaso R4 |
| B1.1 | Presentes a fondo (estado y acción, situaciones temporales), pasado simple y continuo, presente perfecto frente a pasado simple, *for / since*, *used to*, preguntas de sujeto | Describir rutinas, salud y experiencias con detalle | Módulos 1 y 2 |
| B1.2 | Futuros (*will*, *going to*, presente continuo, oraciones de tiempo), primera condicional, modales de obligación, consejo, permiso y habilidad, preguntas indirectas, verbo + *-ing* o infinitivo, correos de trabajo | Explicar planes y metas; resolver situaciones de trabajo | Módulos 3 y 4 |
| B1.3 | Comparaciones (*as… as*, *much / far*), pasiva en presente y pasado, segunda condicional, pasado perfecto, estilo indirecto, relativas, verbos frasales frecuentes | Opinar y defender una idea; contar una historia de dos minutos. **Puerta B1** | Módulos 5 y 6 |
| B2.1 | Presente perfecto continuo, tiempos narrativos, futuro continuo y perfecto, *used to / would / be used to* | Narrar con matices; hablar de cambios y tendencias | Nuevo |
| B2.2 | Modales de deducción en presente y pasado, tercera condicional y mixtas, *wish / if only* | Especular, lamentar y plantear hipótesis | Nuevo |
| B2.3 | Pasiva avanzada (*have something done*, pasiva con verbos de opinión), gerundios e infinitivos, verbos de reporte, relativas y participios | Informar, reportar y describir procesos | Nuevo |
| B2.4 | Conectores de contraste, causa y propósito; énfasis (*what I need is…*); formación de palabras; colocaciones y verbos frasales por tema | Argumentar por escrito (ensayo, informe, reseña) y en debate. **Puerta B2** | Nuevo |
