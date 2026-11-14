# Especificación — Formato de contenido `gravity-ingles-v1`

> Versión 0.1 (14/nov/2026), **propuesta**. Parte del plan `docs/specs/fase-8-ingles-plan.md` (paquetes P1.1 y P1.2). Nace de la revisión `docs/revisiones/fase-8-ingles.md` (hallazgos ING-B1, ING-B2, ING-B4, ING-I1, ING-I3 e ING-I4).
> Precedente en el proyecto: `herramientas/biblia` y el formato `gravity-biblia-v1` (contenido con formato versionado, validador en Dart y salida a `app/assets`).

## 1. Para qué sirve

Hoy el contenido de inglés es Markdown con la respuesta junto a la pregunta. La app no puede leerlo, el estudiante ve la clave y nada se comprueba solo. Este formato fija **una sola fuente** en datos, de la que salen tres cosas:

| Salida | Para quién | Dónde |
|---|---|---|
| Cuaderno sin respuestas y clave con explicaciones (Markdown) | El dueño que revisa y el agente que resuelve a ciegas | `docs/contenido/ingles/generado/` |
| Contenido compilado (JSON comprimido) | La app, sin conexión | `app/assets/ingles/` |
| Informe de cobertura y fidelidad | El arquitecto y calidad | Salida de la herramienta |

Reglas de base:
1. Las fuentes se escriben a mano (o las escribe un agente). Lo generado **nunca** se edita a mano.
2. Ninguna fuente dice "completo", "verificado" ni "aprobado por su cuenta": el estado y la fidelidad los calcula la herramienta (V24 a V26).
3. La letra de la opción correcta no existe en la fuente. Se sortea al exportar y al compilar (V06).

## 2. Carpetas

```
data/ingles/
  LEEME.md
  niveles.yaml                         escalera, temario y listas controladas
  formatos/<formato>.yaml              contrato de cada examen y de las plantillas propias
  unidades/<formato>/<parte>/<id>.yaml banco: un estímulo con sus preguntas
  formas/<formato>/<id>.yaml           una prueba: lista ordenada de unidades
  curso/<escalon>/semana-NN/<dia>.yaml una sesión diaria
  revisiones/<id-de-unidad>/           resultados de la resolución a ciegas (los escribe la herramienta)
  ejemplos/                            unidades patrón; también son casos de prueba del validador
herramientas/ingles/                   paquete Dart: validar, exportar, compilar, comparar, informe
docs/contenido/ingles/generado/        cuadernos y claves exportados (no editar)
app/assets/ingles/                     contenido compilado (no editar)
```

Las fuentes van en YAML porque los textos largos y los guiones se leen y se revisan mejor en bloques de texto que en JSON.

## 3. Encabezado común y estados

Todo archivo de `data/ingles/` empieza así:

```yaml
esquema: gravity-ingles-v1
tipo: unidad          # unidad | forma | sesion | formato | niveles
id: cam-b1-r3-0001    # minúsculas, dígitos y guiones; único en todo data/ingles
estado: borrador      # borrador | validado | revisado | aprobado | retirado
```

| Estado | Significa | Quién lo pone | Qué exige la herramienta |
|---|---|---|---|
| `borrador` | Escrito, sin comprobar | Autor | Nada |
| `validado` | Pasa todas las comprobaciones automáticas | Autor, tras correr `validar` | Cero errores |
| `revisado` | Resuelto a ciegas por otro agente y sin disputas abiertas | Integrador | Revisión vigente (misma huella del contenido) con todas las preguntas en `coincide` o `resuelto` |
| `aprobado` | Visto bueno del dueño o de calidad por muestreo | Arquitecto | Estar en `revisado` |
| `retirado` | Ya no se usa; se conserva por historial | Arquitecto | No se compila |

Solo `revisado` y `aprobado` llegan a la app.

## 4. Unidad: un estímulo con sus preguntas

```yaml
esquema: gravity-ingles-v1
tipo: unidad
id: cam-b1-r3-0001
estado: borrador
formato: cambridge-b1-preliminary   # id de formatos/; en el curso: gravity-sesion-60
parte: reading-3                    # id de parte del contrato
nivel: B1                           # A1 | A2 | B1 | B2
variante: en-GB                     # en-GB | en-US
origen: nuevo                       # nuevo | migrado:<archivo.md>
estimulo:
  tipo: texto                       # texto | audio | imagen | consigna | ninguno
  titulo: "A year without my car"
  texto: |
    Párrafos del texto en inglés…
preguntas:
  - id: cam-b1-r3-0001-a
    tipo: opcion_multiple
    habilidad: lectura
    foco: actitud_opinion
    enunciado: "How did the writer feel when she first sold her car?"
    opciones:
      - texto: "worried about how she would manage"      # la primera es SIEMPRE la correcta
        porque: "Párrafo 1: 'I spent the first week wondering how I would cope'."
      - texto: "pleased to be saving money"
        porque_no: "El ahorro aparece en el párrafo 3, como algo que descubrió después."
      - texto: "angry with her neighbours"
        porque_no: "Los vecinos la ayudan; no hay enojo en el texto."
      - texto: "proud of helping the environment"
        porque_no: "Dice que no lo hizo por el ambiente."
```

### 4.1 Estímulos

| `tipo` | Campos | Reglas |
|---|---|---|
| `texto` | `titulo` (opcional), `texto` | Longitud dentro del rango del contrato (V15) |
| `audio` | `guion` (lista de turnos con `voz` y `texto`), `reproducciones` | Voces: `F1`, `F2`, `M1`, `M2`, `N` (narrador). El cuaderno no imprime el guion (V16) |
| `imagen` | `descripcion`, `archivo` (opcional) | Mientras no haya archivo, la app muestra la descripción y la forma no puede ser de fidelidad completa |
| `consigna` | `texto` | Para tareas de escritura y habla |
| `ninguno` | — | Preguntas sueltas (por ejemplo, oraciones de la Parte 5 de TOEIC) |

### 4.2 Tipos de pregunta

| `tipo` | Para qué | Campos propios | Regla clave |
|---|---|---|---|
| `opcion_multiple` | Lectura, escucha, gramática | `enunciado`, `opciones` | La primera opción es la correcta; 3 o 4 según el contrato (V03, V04) |
| `hueco_opciones` | Texto con huecos y opciones (Cambridge, TOEIC 5 y 6) | `hueco`, `opciones` | El texto marca los huecos como `{1}`, `{2}`… |
| `hueco_abierto` | Una palabra por hueco | `hueco`, `aceptadas`, `clase` | Se listan **todas** las respuestas válidas; `clase: gramatical` donde el contrato lo pide (V09) |
| `formacion_palabra` | Palabra derivada | `hueco`, `base`, `aceptadas` | Ninguna aceptada es igual a la base (V07) |
| `transformacion` | Segunda oración con palabra clave | `original`, `clave`, `antes`, `despues`, `aceptadas` | La clave va dentro de la respuesta y no fuera (V08) |
| `oracion_omitida` | Texto con oraciones quitadas | `oraciones` (cada una con `hueco` y `ancla`, o `sobrante: true` y `porque_no`) | Cada oración declara la pista de cohesión que la fija (V10) |
| `correspondencia` | ¿En qué texto se dice…? | `enunciado`, `respuesta`, `evidencia` | La unidad lleva `textos` con id (V11) |
| `emparejar` | Personas con textos, hablantes con frases | `elemento`, `respuesta`, `evidencia` | La unidad lleva `opciones` con id; las sobrantes llevan `porque_no` |
| `completar_nota` | Notas con huecos al escuchar | `hueco`, `aceptadas` | Una a tres palabras o un número, tal como se oye |
| `completar_palabras` | Palabras cortadas dentro de un texto (TOEFL) | — (los huecos van en el texto: `im{prove}`) | Siempre con texto alrededor (V14) |
| `ordenar_palabras` | Construir una oración | `palabras`, `aceptadas` | — |
| `respuesta_corta` | Ejercicios del curso (transformar, traducir) | `enunciado`, `aceptadas` | — |
| `repetir` | Escuchar y repetir | `frases` | — |
| `pronunciacion` | Pares mínimos, sílaba tónica | `foco`, `elementos` | — |
| `produccion` | Escritura o habla | `modalidad`, `consigna`, `extension`, `puntos_obligatorios`, `cotejo`, `modelo`, `errores_tipicos` | Siempre con lista de cotejo y respuesta modelo |

Toda pregunta objetiva lleva `porque` (por qué esa es la respuesta, con la evidencia del estímulo). En el curso, cada distractor lleva además `porque_no` (V12).

Ejemplo de hueco abierto y de formación de palabra, tal como deben quedar:

```yaml
preguntas:
  - id: cam-b2-ue2-0001-3
    tipo: hueco_abierto
    hueco: 3
    clase: gramatical
    aceptadas: ["who", "that"]
    porque: "Pronombre relativo de persona, sujeto de 'enjoy'."
  - id: cam-b2-ue3-0001-2
    tipo: formacion_palabra
    hueco: 2
    base: "HEALTH"
    aceptadas: ["unhealthy"]
    porque: "Hace falta un adjetivo negativo: el texto habla de hábitos que hacen daño."
```

## 5. Forma: una prueba

```yaml
esquema: gravity-ingles-v1
tipo: forma
id: cam-b1-preliminary-forma-a
estado: borrador
formato: cambridge-b1-preliminary
uso: simulacro        # ubicacion | mini | escalon | etapa | simulacro | practica
semilla: 2026111401   # fija el sorteo de opciones y de letras
secciones:
  - parte: reading-1
    unidades: [cam-b1-r1-0001, cam-b1-r1-0002, cam-b1-r1-0003, cam-b1-r1-0004, cam-b1-r1-0005]
  - parte: reading-3
    unidades: [cam-b1-r3-0001]
```

La **fidelidad** de una forma no se escribe: la calcula la herramienta. Es `completa` solo si cada parte tiene el número de unidades y de preguntas del contrato, todos los estímulos están dentro de su rango de palabras y las partes de escucha tienen audio. En cualquier otro caso es `reducida`, y así se muestra en el cuaderno y en la app.

## 6. Contrato de formato

Un archivo por examen, escrito a partir del manual oficial y con la página de donde sale cada dato. También hay contratos propios: `gravity-sesion-60` (sesión diaria), `gravity-ubicacion`, `gravity-escalon` (puerta de escalón).

```yaml
esquema: gravity-ingles-v1
tipo: formato
id: cambridge-b1-preliminary
estado: borrador
nombre: "Cambridge B1 Preliminary"
fuente:
  titulo: "B1 Preliminary — Handbook for teachers"
  url: "https://www.cambridgeenglish.org/Images/168150-b1-preliminary-teachers-handbook.pdf"
  consultado: 2026-11-14
variante: en-GB
idioma_instrucciones: en
secciones:
  - id: reading
    minutos: 45
    partes:
      - id: reading-3
        tarea: "Texto largo con cinco preguntas de cuatro opciones"
        tipo_pregunta: opcion_multiple
        unidades: 1
        preguntas_por_unidad: 5
        opciones: 4
        palabras_estimulo: {min: 330, max: 430}
        pagina_manual: 20
  - id: listening
    minutos: 30
    partes:
      - id: listening-3
        tarea: "Notas con seis huecos"
        tipo_pregunta: completar_nota
        unidades: 1
        preguntas_por_unidad: 6
        reproducciones: 2
        palabras_estimulo: {min: 250, max: 330}
        pagina_manual: 45
```

Rangos iniciales de palabras, medidos en la prueba de muestra de cada manual (el paquete P1.1 los confirma, con página, antes de fijarlos):

| Examen | Parte | Palabras del estímulo |
|---|---|---|
| B1 Preliminary | Reading 1 (cada texto corto) | 20 a 60 |
| | Reading 2 (cinco descripciones y ocho textos, en total) | 520 a 680 |
| | Reading 3 | 330 a 430 |
| | Reading 4 (texto y ocho oraciones) | 300 a 400 |
| | Reading 5 y Reading 6 (cada texto) | 100 a 150 |
| | Listening completo (guion) | 2,000 a 2,600 |
| B2 First | Use of English 1, 2 y 3 (cada texto) | 150 a 190 |
| | Reading 5 | 550 a 700 |
| | Reading 6 (texto y siete oraciones) | 550 a 650 |
| | Reading 7 (textos en total) | 550 a 700 |
| | Listening completo (guion) | 2,600 a 3,200 |
| TOEIC | Parte 3 (cada conversación) | 90 a 150 |
| | Parte 4 (cada charla) | 90 a 140 |
| | Parte 6 (cada texto) | 80 a 130 |
| | Parte 7, texto sencillo | 80 a 300 |
| | Parte 7, conjunto de dos o tres textos (en total) | 250 a 450 |
| TOEFL iBT 2026 | Lectura (cada texto) | 15 a 200 |
| | Escucha (cada audio) | hasta 250 |

## 7. Sesión del curso (60 minutos)

Respeta los tiempos aprobados por el dueño: bloque principal de 35 minutos (repaso 5, lección 10, pronunciación 8, producción 12) y traslado de 25 (escucha 10, repetición 10, tarjetas 5).

```yaml
esquema: gravity-ingles-v1
tipo: sesion
id: b1-1-s01-lun
estado: borrador
escalon: B1.1
semana: 1
dia: lunes                # lunes | martes | miercoles | jueves | viernes
enfoque: gramatica_vocabulario
titulo: "Rutinas: lo que hago siempre y lo que hago ahora"
puedo: "Puedo contar mi rutina y decir qué estoy haciendo en este momento."
temas: [gram.presente_simple_vs_continuo]
bloques:
  - tipo: repaso          # lo arma la app con las tarjetas pendientes
    minutos: 5
  - tipo: leccion
    minutos: 10
    explicacion: |
      Explicación en español, corta y con el porqué…
    ejemplos:
      - {en: "I usually walk to work, but today I'm taking the bus.", es: "Normalmente camino al trabajo, pero hoy voy en autobús."}
    error_comun: {mal: "I am usually walking to work.", bien: "I usually walk to work.", porque: "Las rutinas van en presente simple."}
    preguntas: []         # 10 o más
  - tipo: pronunciacion
    minutos: 8
    foco: "final -s: /s/, /z/, /ɪz/"
    elementos: []         # 10 o más
  - tipo: produccion
    minutos: 12
    tarea: {}             # pregunta de tipo produccion
  - tipo: traslado
    minutos: 25
    audio: b1-1-s01-audio-a   # unidad de audio de la semana
    frases: []                # 12 o más para repetir
tarjetas: []                  # 8 por sesión de lunes a jueves
```

Mínimos por bloque (V21). El viernes cambia la lección por conversación guiada y la mini prueba ocupa el lugar del repaso, como ya está aprobado.

| Bloque | Lunes: gramática y vocabulario | Martes: escucha | Miércoles: pronunciación | Jueves: lectura y escritura | Viernes: conversación |
|---|---|---|---|---|---|
| Lección (10) | Explicación, 6 ejemplos, error común y 10 preguntas | Audio propio con 8 preguntas | Explicación del sonido y 12 elementos | Texto con 6 preguntas | Diálogo guiado de 8 turnos con variantes |
| Pronunciación (8) | 10 elementos | 10 elementos | 10 elementos | 10 elementos | 10 elementos |
| Producción (12) | Tarea con cotejo y modelo | Igual | Igual | Tarea escrita con cotejo y modelo | Monólogo o diálogo grabado |
| Traslado (25) | Audio de la semana, 12 frases, tarjetas | Igual | Igual | Igual | Igual |
| Tarjetas nuevas | 8 | 8 | 8 | 8 | 0 |
| Mini prueba | — | — | — | — | 10 preguntas, se aprueba con 8 |

Cada semana tiene al menos dos audios de traslado distintos. Longitudes por etapa:

| Etapa | Lectura (palabras) | Audio (palabras) | Escritura (palabras) | Habla (segundos) |
|---|---|---|---|---|
| A1 | 60 a 120 | 60 a 120 | 30 a 50 | 30 a 45 |
| A2 | 120 a 200 | 120 a 200 | 50 a 80 | 45 a 60 |
| B1 | 200 a 350 | 200 a 350 | 80 a 120 | 60 a 90 |
| B2 | 350 a 550 | 350 a 500 | 140 a 190 | 90 a 120 |

Cálculo de minutos (V22): opción múltiple o hueco, 40 segundos; respuesta corta, ordenar o transformar, 60; escucha, palabras ÷ 150 por el número de reproducciones, más 40 por pregunta; cada frase para repetir, 30; cada elemento de pronunciación, 30; cada tarjeta nueva, 30; producción, los minutos declarados si trae consigna, cotejo y modelo. El tiempo estimado de cada bloque debe llegar al 70 % del declarado, y el total quedar entre 54 y 66 minutos.

## 8. Niveles

`data/ingles/niveles.yaml` contiene la escalera (escalones y etapas), el temario de cada escalón y las listas controladas de `habilidad`, `foco` y `temas`. Su contenido se define en el plan (sección 3.1 y paquete P1.3).

## 9. Resolución a ciegas

1. El integrador exporta el cuaderno de la unidad o de la forma, sin respuestas.
2. Un agente distinto del autor recibe **solo** el cuaderno y escribe un archivo de respuestas:

```yaml
objeto: cam-b1-r3-0001
agente: calidad
fecha: 2026-11-15
respuestas:
  cam-b1-r3-0001-a: {respuesta: "B", seguridad: alta, otras_validas: []}
  cam-b1-r3-0001-b: {respuesta: "D", seguridad: media, otras_validas: ["A"], nota: "A también se puede defender por la línea 12."}
observaciones:
  - "El párrafo 4 repite la idea del 2; el texto se puede acortar."
```

3. `comparar` cruza las respuestas con la fuente y escribe el resultado en `data/ingles/revisiones/<id>/`, con la **huella** del contenido revisado. Cada pregunta queda en `coincide`, `disputa` (respuesta distinta, o el revisor declara otra opción válida) o `resuelto` (disputa cerrada con un cambio y una nueva revisión).
4. Si la unidad cambia después, la huella deja de coincidir y la revisión caduca (V24).

En huecos abiertos, formación de palabra y transformaciones, el revisor escribe todas las respuestas que considere válidas; las que falten en `aceptadas` son disputa.

## 10. Herramienta `herramientas/ingles`

Paquete Dart, con la misma forma que `herramientas/biblia` (`bin/`, `lib/`, `test/`, `pubspec.yaml`, `README.md`).

```
cd herramientas/ingles
dart run bin/ingles.dart validar [ruta]                    # V01 a V26; sale con 1 si hay errores
dart run bin/ingles.dart exportar <id> [--clave]           # cuaderno y clave en docs/contenido/ingles/generado/
dart run bin/ingles.dart comparar <id> <respuestas.yaml>   # escribe la revisión y la huella
dart run bin/ingles.dart compilar                          # app/assets/ingles/*.json.gz (solo revisado y aprobado)
dart run bin/ingles.dart informe                           # cobertura por escalón y fidelidad por forma
dart test
```

## 11. Catálogo de comprobaciones

Error = impide `validado`. Aviso = se reporta y no impide.

| Código | Qué comprueba | Tipo |
|---|---|---|
| V01 | Esquema: campos obligatorios, tipos y valores de las listas controladas | Error |
| V02 | Identificadores únicos en todo `data/ingles`; el id de cada pregunta empieza con el de su unidad; toda referencia existe | Error |
| V03 | Número de opciones según el contrato de la parte; opciones distintas entre sí (sin contar mayúsculas, espacios ni puntuación) | Error |
| V04 | Una sola correcta: la primera opción, con `porque`; en preguntas abiertas, `aceptadas` no vacía | Error |
| V05 | En partes de 8 preguntas o más, la correcta es la opción más larga en menos de la mitad | Aviso |
| V06 | Sorteo de la posición de la correcta con la semilla de la forma, reparto equilibrado y sin tres iguales seguidas; `orden_fijo: true` conserva el orden y exige `correcta` | Error |
| V07 | Formación de palabra: ninguna respuesta aceptada es igual a la base | Error |
| V08 | Transformación: cada aceptada contiene la palabra clave sin cambios y tiene las palabras que pide el contrato; la clave no aparece en `antes` ni en `despues` | Error |
| V09 | Hueco abierto: cada aceptada es una sola palabra; con `clase: gramatical`, pertenece a la lista de palabras gramaticales | Error |
| V10 | Oraciones omitidas: número de oraciones igual a huecos más sobrantes del contrato; `ancla` en cada colocada y `porque_no` en cada sobrante | Error |
| V11 | Correspondencia y emparejar: la respuesta apunta a un texto u opción existente y trae `evidencia`; ningún texto concentra más de la mitad de las respuestas | Error y aviso |
| V12 | `porque` de al menos 6 palabras en toda pregunta objetiva; en el curso, `porque_no` en cada distractor | Error |
| V13 | `nivel`, `habilidad`, `foco` y `temas` pertenecen a `niveles.yaml` | Error |
| V14 | Completar palabras: cada hueco oculta de 2 a 8 letras y hay al menos 4 palabras completas por cada hueco | Error |
| V15 | Palabras del estímulo dentro del rango del contrato; fuera de rango, la forma queda como `reducida` | Aviso en la unidad; decide la fidelidad de la forma |
| V16 | Audio: voces declaradas, `reproducciones` igual al contrato; el cuaderno no imprime el guion | Error |
| V17 | En formas de examen, enunciados y opciones en inglés (detecta palabras en español) | Error |
| V18 | No se mezclan grafías británicas y americanas de la lista de control en una unidad | Aviso |
| V19 | Ningún estímulo ni enunciado se repite entre unidades (similitud de 0.85 o más); una unidad no aparece en dos formas del mismo formato, ni en práctica y en forma | Error |
| V20 | Las unidades de ubicación y de puertas no se usan en ningún otro lugar | Error |
| V21 | Cada sesión cumple los mínimos por bloque de la sección 7 | Error |
| V22 | Minutos estimados por bloque al 70 % o más del declarado; total entre 54 y 66 | Error |
| V23 | Tarjetas: id único en el curso, traducción presente y `ejemplo` que contiene la palabra | Error |
| V24 | Estados: `validado` sin errores; `revisado` con revisión a ciegas vigente (misma huella) y sin disputas; `aprobado` solo desde `revisado` | Error |
| V25 | Solo se compila lo que está en `revisado` o `aprobado` | Error |
| V26 | Los encabezados de estado, fidelidad y audio de lo exportado los escribe la herramienta | Error |

## 12. Lo que queda fuera de esta versión

- Archivos de audio grabado y fotografías. El audio se genera en el dispositivo a partir del guion (plan, fase 3). Las imágenes se describen en texto hasta que haya archivos con licencia clara.
- Calificación con IA de escritura y habla. Se evalúa con lista de cotejo, modelo y revisión en pareja; la IA se especifica aparte, después de la Fase 6.
- Otros idiomas. El formato no depende del inglés: bastará otra carpeta (`data/<idioma>/`) y sus contratos cuando el dueño lo pida.
