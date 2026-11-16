# Especificación — Formato de contenido `gravity-ingles-v1`

> Versión 0.3 (15/nov/2026), **propuesta**. La 0.3 recoge lo que encontró el validador al leer los ejemplos y los contratos (informe del paquete P1.2a). Parte del plan `docs/specs/fase-8-ingles-plan.md` (paquetes P1.1 y P1.2). Nace de la revisión `docs/revisiones/fase-8-ingles.md` (hallazgos ING-B1, ING-B2, ING-B4, ING-I1, ING-I3 e ING-I4).
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
2. Ninguna fuente afirma por su cuenta que está "completa", "verificada" o "aprobada": el estado y la fidelidad los comprueba la herramienta (V24 a V26).
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
docs/revisiones/ingles/                respuestas de quien resuelve a ciegas (las guarda quien integra)
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
| `audio` | `guion` (lista de turnos con `voz` y `texto`), `reproducciones`, y `nota` si las preguntas son `completar_nota` | Voces: `F1`, `F2`, `M1`, `M2`, `N` (narrador). El cuaderno no imprime el guion (V16). `nota` es el texto con huecos `{1}`, `{2}`… que ve el estudiante mientras escucha |
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
| `transformacion` | Segunda oración con palabra clave | `original`, `clave`, `antes`, `despues`, `aceptadas` | La clave va dentro de la respuesta y no fuera; de 2 a 5 palabras, y una contracción cuenta como dos; se conservan las palabras del original que la clave no obliga a cambiar (V08) |
| `oracion_omitida` | Texto con oraciones quitadas | `oraciones` (cada una con `hueco` y `ancla`, o `sobrante: true` y `porque_no`) | Cada oración declara la pista de cohesión que la fija (V10) |
| `correspondencia` | ¿En qué texto se dice…? | `enunciado`, `respuesta`, `evidencia` | La unidad lleva `textos` con id (V11) |
| `emparejar` | Personas con textos, hablantes con frases | `elemento`, `respuesta`, `evidencia` | La unidad lleva `opciones` con id; las sobrantes llevan `porque_no` |
| `completar_nota` | Notas con huecos al escuchar | `hueco`, `aceptadas` | Una a tres palabras o un número, tal como se oye. Los huecos están en la `nota` del estímulo (V02 comprueba que cada `hueco` exista ahí) |
| `completar_palabras` | Palabras cortadas dentro de un texto (TOEFL) | `pistas` (una por hueco, en orden); los huecos van en el texto: `im{prove}` | Siempre con texto alrededor; la app muestra una casilla por letra oculta. Se oculta el final de la palabra según la regla `ocultar` del contrato; hoy, la segunda mitad, como criterio provisional (V14) |
| `ordenar_palabras` | Construir una oración | `palabras`, `aceptadas` | — |
| `respuesta_corta` | Ejercicios del curso (transformar, traducir) | `enunciado`, `aceptadas` | — |
| `repetir` | Escuchar y repetir | `frases` | — |
| `pronunciacion` | Pares mínimos, sílaba tónica | `foco`, `elementos` | — |
| `produccion` | Escritura o habla | `modalidad`, `consigna`, `extension`, `puntos_obligatorios`, `cotejo`, `modelo`, `errores_tipicos` | Siempre con lista de cotejo y respuesta modelo |

Toda pregunta lleva `habilidad` (de la lista de `niveles.yaml`). Toda pregunta objetiva lleva `porque` (por qué esa es la respuesta, con la evidencia del estímulo). En el curso, cada distractor lleva además `porque_no` (V12).

Tres precisiones de V12: (1) en `correspondencia` y `emparejar`, la `evidencia` cumple el papel del `porque` y también debe tener al menos 6 palabras; (2) en `completar_palabras`, la pregunta lleva su `porque` y cada pista lleva el suyo, pero el de la pista puede ser corto; (3) en las preguntas abiertas, `porque` explica también qué intento frecuente no vale.

**Unidades del contrato frente a archivos.** Un archivo es una unidad con un solo estímulo. Cuando el contrato pide varias «unidades» sin estímulo (las transformaciones de B2 First, las oraciones sueltas de TOEIC Parte 5), un archivo con `estimulo: ninguno` aporta tantas unidades como preguntas lleve. Cuando cada una tiene su propio estímulo (los extractos de Listening 1), cada una es su archivo. La fidelidad cuenta preguntas y estímulos por parte, no archivos.

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

La **fidelidad** de una forma no se escribe: la calcula la herramienta. Es `completa` solo si cada parte tiene el número de unidades y de preguntas del contrato, todos los estímulos están dentro de su rango de palabras, las partes de escucha tienen audio y el contrato no tiene datos pendientes en las partes que usa. En cualquier otro caso es `reducida`, y así se muestra en el cuaderno y en la app.

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

Los seis contratos de exámenes oficiales existen desde el 15/nov/2026 (paquete P1.1a), en `borrador`. **Los rangos de palabras viven solo ahí:** este documento ya no los repite, para que no haya dos fuentes.

### 6.1 Campos de una parte

| Campo | Qué es |
|---|---|
| `id` | `<sección>-<número de parte oficial>`. En B2 First, `use-of-english-1` a `-4` y `reading-5` a `-7`. Donde el examen no numera partes, el nombre de la tarea en inglés (TOEFL) o el rango de preguntas (`speaking-q1-2` en TOEIC) |
| `tarea`, `tipo_pregunta`, `tipo_estimulo`, `modalidad` | Qué se pide, con los tipos de la sección 4 |
| `unidades`, `preguntas_por_unidad`, `preguntas_total` | Cuántas unidades y preguntas. `preguntas_por_unidad` puede ser `{min, max}` cuando los conjuntos varían (Parte 7 de TOEIC) |
| `opciones`, `reproducciones`, `puntos_por_pregunta` | Opciones por pregunta, veces que se oye el audio y puntos, cuando el manual los da. `puntos_por_pregunta` es un número o un rango `{min, max}` (TOEIC Speaking y Writing se califica de 0 a 3, 4 o 5) |
| `clase`, `nota_clase` | `gramatical` en los huecos abiertos de Cambridge: el manual dice que miden sobre todo gramática y algo de vocabulario, y GRAVITY escribe solo huecos gramaticales para que cada uno tenga una respuesta única. V09 lo exige a las preguntas de esa parte |
| `palabras_estimulo` | `{min, max, origen}`. `origen: declarado` si el manual da la cifra; `origen: medido` si se contó en su prueba de muestra |
| `medido` | La medida de origen: `total` o `por_unidad`, `muestras`, `pagina` y `nota` |
| `palabras_respuesta`, `tiempos_segundos`, `tiempos_minutos`, `minutos_parte` | Para escritura, habla y transformaciones. `palabras_respuesta` es `{min, max}` o `{aprox}`; en las transformaciones de B2 First es `{min: 2, max: 5}`, que V08 lee |
| `pagina_manual` | Página del PDF (no la impresa) de donde sale el dato |
| `pendiente: true` y `nota` | El manual no da el dato, o el rango sale de muy pocas muestras |

En la sección: `minutos` (número o `{min, max}`), `preguntas_total` o `tareas_total`, y lo propio de cada examen (`minutos_router` y `minutos_modulo` en TOEFL, `minutos_grupo_de_tres` en Cambridge). En la raíz, `totales`.

### 6.2 Reglas de los rangos

1. **De dónde sale un rango.** Si el manual declara la longitud, se usa esa cifra. Si no, se cuenta en su prueba de muestra y el rango es la medida menos 15 % y más 15 %, redondeado a decenas.
2. **Qué se cuenta.** En un texto, sus palabras, con los números de hueco. En un audio, **solo los turnos de habla**: las frases del narrador y las instrucciones no cuentan (en el formato, los turnos con `voz: N`). La transcripción oficial de un Listening completo mide un 20 a 25 % más con el narrador que sin él.
3. **Contracciones.** Para contar las palabras de una respuesta, la contracción cuenta como dos (*I'd* = *I would*). El apóstrofo-s se parte solo tras un pronombre o adverbio de una lista corta (*it's*, *there's*, *what's*); un posesivo (*Maria's*) cuenta como una palabra. La regla es una heurística: la aplica una sola función del validador.
4. **Un dato pendiente no decide nada.** Mientras una parte tenga `pendiente: true`, la comprobación de longitud (V15) da aviso en lugar de error, y una forma que use esa parte no puede ser de fidelidad `completa`.

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
    audios: [b1-1-s01-audio-a, b1-1-s01-audio-b]   # los dos audios de la semana
    frases: []                # 20 o más para repetir
tarjetas: []                  # 8 por sesión de lunes a jueves
```

Mínimos por bloque (V21). El viernes cambia la lección por conversación guiada y la mini prueba ocupa el lugar del repaso, como ya está aprobado.

| Bloque | Lunes: gramática y vocabulario | Martes: escucha | Miércoles: pronunciación | Jueves: lectura y escritura | Viernes: conversación |
|---|---|---|---|---|---|
| Lección (10) | Explicación, 6 ejemplos, error común y 10 preguntas | Audio propio con 8 preguntas | Explicación del sonido y 12 elementos | Texto con 6 preguntas | Diálogo guiado de 8 turnos con variantes |
| Pronunciación (8) | 10 elementos | 10 elementos | 10 elementos | 10 elementos | 10 elementos |
| Producción (12) | Tarea con cotejo y modelo | Igual | Igual | Tarea escrita con cotejo y modelo | Monólogo o diálogo grabado |
| Traslado (25) | Los dos audios de la semana (dos veces cada uno), 20 frases para repetir y tarjetas en audio | Igual | Igual | Igual | Igual |
| Tarjetas nuevas | 8 | 8 | 8 | 8 | 0 |
| Mini prueba | — | — | — | — | 10 preguntas, se aprueba con 8 |

Cada semana tiene dos audios de traslado distintos (un monólogo y un diálogo), que se repiten durante la semana: volver a oír el mismo audio es parte del método. Longitudes por etapa:

| Etapa | Lectura (palabras) | Audio (palabras) | Escritura (palabras) | Habla (segundos) |
|---|---|---|---|---|
| A1 | 60 a 120 | 60 a 120 | 30 a 50 | 30 a 45 |
| A2 | 120 a 200 | 120 a 200 | 50 a 80 | 45 a 60 |
| B1 | 200 a 350 | 200 a 350 | 80 a 120 | 60 a 90 |
| B2 | 350 a 550 | 350 a 500 | 140 a 190 | 90 a 120 |

Cálculo de minutos (V22): explicación, palabras ÷ 150; cada ejemplo, 15 segundos; opción múltiple o hueco, 40; respuesta corta, ordenar o transformar, 60; escucha, palabras ÷ 150 por el número de reproducciones, más 40 segundos por pregunta; cada frase para repetir, 30; cada elemento de pronunciación, 30; cada tarjeta nueva, 15; repaso y tarjetas en audio, los minutos declarados; producción, los minutos declarados si trae consigna, cotejo y modelo. El tiempo estimado de cada bloque debe quedar entre el 70 % y el 150 % del declarado, y el total entre 54 y 66 minutos.

## 8. Niveles

`data/ingles/niveles.yaml` contiene la escalera (escalones y etapas), el temario de cada escalón y las listas controladas de `habilidad`, `foco` y `temas`. Su contenido se define en el plan (sección 3.1 y paquete P1.3). El validador espera estas claves de primer nivel, cada una como lista de textos o de bloques con `id`: `niveles`, `escalones`, `habilidades`, `focos` y `temas`. Si P1.3 elige otros nombres, se cambia en un solo archivo del validador.

## 9. Resolución a ciegas

1. El integrador exporta el cuaderno de la unidad o de la forma, sin respuestas.
2. Un agente distinto del autor recibe **solo** el cuaderno, dentro de su encargo, y devuelve sus respuestas en el reporte. Quien integra las guarda en `docs/revisiones/ingles/<objeto>-<agente>.yaml`:

```yaml
objeto: cam-b1-r3-0001
agente: calidad
fecha: 2026-11-15
archivos_abiertos: []      # lo que leyó además del cuaderno; debe quedar vacía
respuestas:
  cam-b1-r3-0001-a: {respuesta: "B", seguridad: alta, otras_validas: []}
  cam-b1-r3-0001-b: {respuesta: "D", seguridad: media, otras_validas: ["A"], nota: "A también se puede defender por la línea 12."}
observaciones:
  - "El párrafo 4 repite la idea del 2; el texto se puede acortar."
```

3. `comparar` cruza las respuestas con la fuente y escribe el resultado en `data/ingles/revisiones/<id>/`, con la **huella** del contenido revisado. Cada pregunta queda en `coincide`, `disputa` (respuesta distinta, o el revisor declara otra opción válida) o `resuelto` (disputa cerrada con un cambio y una nueva revisión).
4. Si la unidad cambia después, la huella deja de coincidir y la revisión caduca (V24).

En huecos abiertos, formación de palabra y transformaciones, el revisor escribe todas las respuestas que considere válidas; las que falten en `aceptadas` son disputa. En `oracion_omitida`, la respuesta es un mapa de hueco a letra; en `completar_palabras`, la lista de palabras completas en el orden del texto.

**Cómo se compara una respuesta escrita con `aceptadas`** (en `comparar` y en la app): sin distinguir mayúsculas, sin espacios repetidos, con apóstrofo recto o curvo, y sin el punto o el signo de interrogación final. Todo lo demás debe coincidir.

Un mismo archivo puede traer las respuestas de varias unidades, como documentos YAML separados por `---` (una ronda completa de un revisor).

Mientras no exista `exportar`, el cuaderno de los ejemplos patrón lo genera `herramientas/ingles/transitorio/cuaderno_ejemplos.py`, con las opciones en orden alfabético.

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

Error = impide `validado`. Aviso = se reporta y no impide. Cuando falta el contrato de una unidad (`sin contrato`, bajo V02) o falta `niveles.yaml` (`sin niveles`, bajo V13), es aviso en `borrador` y error desde `validado`.

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
| V14 | Completar palabras: cada hueco oculta la segunda mitad de la palabra (la mayor si el número de letras es impar), de 2 a 8 letras, y hay al menos 4 palabras completas por cada hueco | Error |
| V15 | Palabras del estímulo dentro del rango del contrato (en audio, solo los turnos de habla); fuera de rango, o con el rango pendiente, la forma queda como `reducida` | Aviso en la unidad; decide la fidelidad de la forma |
| V16 | Audio: voces declaradas, `reproducciones` igual al contrato; el cuaderno no imprime el guion | Error |
| V17 | En formas de examen, enunciados y opciones en inglés (detecta palabras en español) | Error |
| V18 | No se mezclan grafías británicas y americanas de la lista de control en una unidad | Aviso |
| V19 | Ningún estímulo ni enunciado se repite entre unidades (similitud de 0.85 o más); una unidad no aparece en dos formas del mismo formato, ni en práctica y en forma | Error |
| V20 | Las unidades de ubicación y de puertas no se usan en ningún otro lugar | Error |
| V21 | Cada sesión cumple los mínimos por bloque de la sección 7 | Error |
| V22 | Minutos estimados por bloque entre el 70 % y el 150 % del declarado; total entre 54 y 66 | Error |
| V23 | Tarjetas: id único en el curso, traducción presente y `ejemplo` que contiene la palabra o una forma suya | Error |
| V24 | Estados: `validado` sin errores; `revisado` con revisión a ciegas vigente (misma huella) y sin disputas; `aprobado` solo desde `revisado` | Error |
| V25 | Solo se compila lo que está en `revisado` o `aprobado` | Error |
| V26 | Los encabezados de estado, fidelidad y audio de lo exportado los escribe la herramienta | Error |

## 12. Ejemplos patrón

En `data/ingles/ejemplos/`. Marcan el nivel de calidad que se exige y sirven de casos buenos para las pruebas del validador.

| Archivo | Qué enseña |
|---|---|
| `cam-b1-r3-ejemplo.yaml` | Lectura de B1 Preliminary dentro del rango del contrato (394 palabras; rango 300 a 400), cinco preguntas en el orden del texto, la última global, y la razón de cada opción |
| `cam-b2-ue2-ejemplo.yaml` | Hueco abierto de B2 First solo con palabras gramaticales y con todas las respuestas válidas |
| `cam-b2-ue3-ejemplo.yaml` | Formación de palabras de B2 First: todas las respuestas transforman la base |
| `cam-b2-ue4-ejemplo.yaml` | Transformaciones con palabra clave de B2 First: marco que cierra las alternativas, todas las formas válidas y el intento frecuente que no vale |
| `cam-b2-r6-ejemplo.yaml` | Oraciones omitidas de B2 First (599 palabras): cada oración atada por los dos lados y una sobrante que contradice el texto |
| `toefl-r-palabras-ejemplo.yaml` | "Complete the Words" de TOEFL dentro de un texto, con una sola solución por hueco |
| `audio-b1-1-s01-a-ejemplo.yaml`, `audio-b1-1-s01-b-ejemplo.yaml` | Guiones de traslado de B1 (monólogo y diálogo) cargados de la gramática de la semana |
| `sesion-b1-1-s01-lun-ejemplo.yaml` | Sesión de lunes de 60 minutos: 11 preguntas con explicación, 12 elementos de pronunciación, tarea con cotejo y modelo, 20 frases y 8 tarjetas. Estimación: 59 minutos |

Los nueve están en `borrador`. Los escribió la sesión que hizo el plan. Dos agentes los resolvieron a ciegas el 15/nov/2026, uno tras otro: los dos coincidieron con la clave en las 40 preguntas. El primero defendió una segunda respuesta en 6 y el segundo en 2; todas se reescribieron (`docs/revisiones/ingles/ronda-1-resultado.md` y `ronda-2-resultado.md`). Las preguntas cambiadas en la ronda 2 esperan una tercera. Su cuaderno sin respuestas está en `docs/contenido/ingles/generado/cuaderno-ejemplos-patron.md`.

**Faltan patrones** de: texto con huecos y opciones (B2 First parte 1; TOEIC partes 5 y 6), correspondencia (B2 First parte 7), emparejar (B1 Preliminary, Reading 2), completar notas al escuchar (B1 Preliminary, Listening 3, con su `nota`), escucha con opción múltiple, las sesiones de martes a viernes (la del viernes además necesita definir su estructura de conversación guiada, que el formato todavía no fija), y las partes propias de TOEIC y de TOEFL. Se escriben con la regla "patrón antes que serie" del plan (sección 5.2).

## 13. Lo que queda fuera de esta versión

- Archivos de audio grabado y fotografías. El audio se genera en el dispositivo a partir del guion (plan, fase 3). Las imágenes se describen en texto hasta que haya archivos con licencia clara.
- Calificación con IA de escritura y habla. Se evalúa con lista de cotejo, modelo y revisión en pareja; la IA se especifica aparte, después de la Fase 6.
- Crédito parcial en las transformaciones. El examen oficial da dos puntos por pregunta, uno por cada mitad; aquí la pregunta se califica completa, que es más estricto.
- Otros idiomas. El formato no depende del inglés: bastará otra carpeta (`data/<idioma>/`) y sus contratos cuando el dueño lo pida.
