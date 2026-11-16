# Herramienta del contenido de inglés

Valida el contenido de `data/ingles/` (formato `gravity-ingles-v1`, especificación
en `docs/specs/fase-8-ingles-formato.md`; plan en `docs/specs/fase-8-ingles-plan.md`).
Misma forma de paquete que `herramientas/biblia`. Única dependencia: `yaml`.

Estado: **P1.2b**. Hay dos órdenes: `validar` (V01 a V20, sin V06) e `informe`.
`exportar`, `comparar` y `compilar`, y con ellas V06, V21 a V23, V25 y V26 y la
parte de V24 que depende de las revisiones, llegan en P1.2c.

```
cd herramientas/ingles
dart run bin/ingles.dart validar [ruta]   # por defecto, data/ingles desde la raíz del repositorio
dart run bin/ingles.dart informe [ruta]   # idem
dart analyze
dart test
```

(Con Flutter: `export PATH=/home/user/tools/flutter/bin:$PATH`.)

## `validar [ruta]`

Lee los `.yaml` de la ruta (o un solo archivo). Ignora lo que no sea `.yaml`, las
carpetas ocultas y `revisiones/` (lo que escribirá `comparar` tiene otra forma).
Imprime una línea por hallazgo y un resumen:

```
ejemplos/x.yaml [id-de-la-pregunta] V03 error: tiene 3 opciones y el contrato de "reading-3" pide 4
Resumen: 15 archivos leídos, 0 errores, 4 avisos.
```

Sale con 1 si hay errores, con 64 si el uso es incorrecto y con 66 si la ruta no existe.

### Comprobaciones de esta versión

| Código | Qué comprueba | Archivo |
|---|---|---|
| V01 | Esquema: campos obligatorios, tipos y listas controladas (la lectura de `lib/src/modelo/` los deja como hallazgos) | `v01_esquema.dart` |
| V02 | Ids únicos en todo el conjunto, prefijo del id de pregunta, referencias (contrato, parte, unidades de una forma, audios de una sesión, marcas de hueco) | `v02_identificadores.dart` |
| V03 | Número de opciones según el contrato; opciones distintas | `v03_opciones.dart` |
| V04 | Una sola correcta (la primera, con `porque`); `aceptadas` no vacía | `v04_una_correcta.dart` |
| V05 | La correcta no es la más larga en la mitad o más de las preguntas de una parte de 8 o más (aviso) | `v05_longitud_correcta.dart` |
| V06 | **No está**: pertenece a `exportar` (P1.2c) | |
| V07 | Formación de palabra: ninguna aceptada igual a la base | `v07_formacion_palabra.dart` |
| V08 | Transformación: clave sin cambios en la respuesta, de 2 a 5 palabras (o lo que diga el contrato), clave ausente de `antes` y `despues` | `v08_transformacion.dart` |
| V09 | Hueco abierto: una sola palabra; con `clase: gramatical`, de la lista de `lib/src/datos/palabras_gramaticales.dart` | `v09_hueco_abierto.dart` |
| V10 | Oraciones omitidas: número según el contrato, `ancla` en cada colocada, `porque_no` en cada sobrante | `v10_oraciones_omitidas.dart` |
| V11 | Correspondencia y emparejar: la respuesta existe y trae `evidencia`; sobrantes con `porque_no`; concentración (aviso) | `v11_correspondencia.dart` |
| V12 | `porque` de 6 palabras o más en toda pregunta objetiva; en el curso, `porque_no` en cada distractor | `v12_porque.dart` |
| V13 | `nivel`, `escalon`, `habilidad`, `foco` y `temas` están en `niveles.yaml` | `v13_niveles.dart` |
| V14 | Completar palabras: segunda mitad oculta, de 2 a 8 letras, 4 palabras completas por hueco | `v14_completar_palabras.dart` |
| V15 | Palabras del estímulo dentro del rango del contrato de la parte (**aviso**; con la parte pendiente, aviso de "rango pendiente") | `v15_longitud.dart` |
| V16 | Audio: voces de la lista y `reproducciones` igual a las del contrato (error) | `v16_audio.dart` |
| V17 | En unidades de examen, enunciados y opciones en inglés: dos o más señales de español en un mismo texto (error). Señal: una palabra de la lista de palabras funcionales o una palabra en minúscula con tilde española o eñe | `v17_idioma.dart` |
| V18 | Grafías británicas y americanas mezcladas, o distintas de la `variante` declarada (**aviso**) | `v18_grafias.dart` |
| V19 | Duplicados: una oración de 7 palabras o más en dos archivos; dos estímulos con Jaccard de 0.85 o más; una unidad en dos formas (error) | `v19_duplicados.dart` |
| V20 | Las unidades de formas de uso `ubicacion`, `escalon` o `etapa` no se usan en ningún otro lugar (error) | `v20_exclusivas.dart` |
| V24 | Solo la parte sin revisiones: un archivo en `validado` no puede tener errores; `revisado` y `aprobado` no existen todavía | `v24_estados.dart` |

Un archivo en `retirado` solo pasa V01 y V02, y no cuenta como fuente ni como
uso para V19 y V20.

### Sin contrato y sin niveles

Si falta el contrato de una unidad (por ejemplo `gravity-sesion-60`), `validar`
avisa "sin contrato" y sigue sin aplicar las reglas que dependen de él (V15 y la
comparación de reproducciones de V16 callan: ya lo dice V02). Si falta
`data/ingles/niveles.yaml`, avisa "sin niveles". En `borrador` es aviso; de
`validado` en adelante, error. La herramienta no inventa ninguno de los dos.

### V15 · cómo se cuentan las palabras de un estímulo

Con la regla de `contarPalabras` (cada secuencia de letras, dígitos, apóstrofos o
guiones). Lo que se mide depende del estímulo (`lib/src/medidas.dart`):

| Estímulo | Palabras |
|---|---|
| `texto` o `consigna` | Su texto, con los números de hueco (`{1}` cuenta una) y con una palabra cortada de `completar_palabras` (`la{yer}`) contada una vez; **más** el material de lectura de las preguntas: los `textos` y `opciones` con id de la unidad, la descripción (`elemento`) de cada persona de un emparejar y las oraciones disponibles de unas oraciones omitidas (también la sobrante). Es como los miden los contratos ("texto 479 palabras más siete oraciones 90") |
| `audio` | Solo los turnos de habla: la voz `N` (narrador) no cuenta |
| `ninguno` | La oración `original` de cada transformación, una medida por pregunta (así mide el contrato de B2 First, parte 4) |
| `imagen` | Nada que medir |

Fuera de rango es un aviso en la unidad (`tiene 412 palabras y el contrato de
"reading-3" pide 300 a 400 (medido)`). Si el contrato marca la parte como
`pendiente`, el aviso es siempre de "rango pendiente", con la cifra y el rango
provisional, aunque la cifra quepa.

### V16 · voces y reproducciones

Un audio (`estimulo.tipo: audio`) usa solo las voces `F1`, `F2`, `M1`, `M2` y `N` (el
narrador), y su `reproducciones` es igual a la de la parte del contrato, si la parte la
declara. La lectura del archivo ya rechaza (V01) una `voz` fuera de la lista, como rechaza
un `nivel` o un `estado` inválidos; V16 la comprueba otra vez con su propio código, porque
así está en el catálogo, y por eso una voz mal escrita sale dos veces: una como V01 (por
turno) y otra como V16 (por audio). "El cuaderno no imprime el guion" es de `exportar`.

### V17 · método y lista

Cada enunciado y cada opción se parte en palabras (`palabrasDe`: minúsculas, sin
apóstrofos de los bordes) y se busca cada una en
`lib/src/datos/palabras_espanolas.dart`. **Dos o más palabras distintas** de la
lista en un mismo texto son un error; una sola no, porque un nombre propio o un
préstamo (`El Paso`, `en route`) trae una. **Segunda señal** (la agregó quien integró
el paquete, tras sembrar `Ella no pudo pagar la reparación del coche` y no detectarse):
una palabra en minúscula con á, é, í, ó, ú o ñ cuenta también, salvo los préstamos de
`prestamosConTilde` (`café`, `résumé`, `piñata`). Los nombres propios (`José`, `García`)
quedan fuera por su mayúscula inicial. Se mira solo lo que el candidato lee
como pregunta (`lib/src/contenido.dart`, `enunciadosYOpciones`): enunciados,
opciones de respuesta, la oración original y las dos mitades de una
transformación, las oraciones disponibles de unas oraciones omitidas, la
descripción de un emparejar y los textos y opciones con id de la unidad. **No** se
mira el estímulo (un texto largo con nombres propios sumaría falsas alarmas), ni
las explicaciones. Se salta el formato `gravity-sesion-60` y las sesiones, que
mezclan español a propósito. Las formas no tienen enunciados propios: se
comprueban a través de sus unidades.

**La lista** (126 palabras, por categoría) es de palabras funcionales (artículos,
preposiciones, conjunciones, pronombres, interrogativos y verbos muy frecuentes)
que **no sean también inglesas**. Por eso no están, cada una con su razón en
`palabrasEspanolasExcluidas`:

- las que pidió el encargo evitar: `a`, `he`, `no`, `me`, `pan`, `sin`;
- las que son palabras inglesas con otro sentido: `con` (estafa), `son` (hijo),
  `come`, `sale` (venta), `era` (época), `hay` (heno), `dice` (dados), `van`, `ante`,
  `contra`, `solo`, `don`, `nada`, `algo` (jerga de informática), `todo` (the todo list), `ya`, `yo`, `ha`;
- las letras sueltas (`y`, `o`, `u`, `e`);
- las que en minúsculas coinciden con un nombre, una sigla o una nota musical:
  `la` (LA), `lo`, `le`, `les`, `se` (SE), `te`, `ti`, `mi`, `si`, `nos`, `os`,
  `un` (UN), `al` (Al), `ella` (Ella), `su`, `sus`, `tu`, `mis`, `ni`.

Las formas con tilde (`qué`, `más`, `está`, `también`) casi nunca chocan con el
inglés y por eso abundan. Límite conocido: un nombre propio con dos palabras de la lista
(`Juan de los Santos`) da una falsa alarma; se reescribe el nombre. Se comprobó contra 30 662 palabras de inglés del
repositorio: las de la lista aparecen 9 veces, todas en notas en español dentro de
líneas mezcladas; `a` aparece 1 238 veces. Las pruebas vigilan que ninguna palabra
excluida esté en la lista ni sea una palabra gramatical del inglés.

### V18 · método y lista

Se juntan los textos en inglés de la unidad o la sesión (`textosIngles`: títulos,
estímulo con la voz del narrador, material de lectura, enunciados, opciones,
frases, ejemplos y tarjetas; **no** `porque`, `porque_no`, `evidencia`, `ancla` ni
`aceptadas`, que citan las dos grafías o las listan a propósito) y se cuentan las
palabras que están en `lib/src/datos/grafias.dart`: británicas por un lado,
americanas por otro. Una palabra con guion se mira entera y, si no está, por
partes. Hay dos avisos:

- **Mezcla:** palabras de las dos listas en el mismo archivo.
- **Variante:** la grafía dominante (la que tiene más apariciones; con empate no hay
  dominante) no coincide con la `variante` declarada.

La lista tiene 203 parejas, con cada inflexión escrita una por una (regla
`-our/-or`, `-re/-er`, `-ise/-ize`, `-yse/-yze`, `-ll-/-l-`, `-ence/-ense`, `-ogue/-og`
y palabras sueltas como `grey/gray`). **Una forma que es correcta en las dos
variantes no prueba nada**: `tire`, `check`, `program`, `meter`, `story` (americanas
que en Gran Bretaña tienen otro uso) y `cancelled` (británica que también se usa en
Estados Unidos) están en `americanasAmbiguas` y `britanicasAmbiguas`, y de esos pares
solo cuenta la otra forma. Se aplica también a las sesiones, que declaran su
`variante`. No sabe nada de las palabras que no están en la lista ni de los nombres
propios.

### V19 · método

Se calcula una vez para todo el conjunto (`lib/src/duplicados.dart`). Solo entran
las unidades y las sesiones que no estén `retiradas`. Cada hallazgo se reporta en
**los dos archivos** del par (como V02 con los ids): ninguno de los dos puede darse por
bueno mientras el otro lo copie.

- **a · Oraciones.** Se parten los textos (`dividirOraciones`: corta tras `.`, `!`, `?`
  y en cada línea en blanco; un salto de línea suelto no corta) y cada oración se
  normaliza (`claveDeOracion`: sin marcas de hueco, en minúsculas, sin puntuación y con
  apóstrofo recto). Una oración de **7 palabras o más** que está en dos archivos
  distintos es un error. Una oración repetida dentro de un mismo archivo no cuenta. De
  una unidad se miran el estímulo (en un audio, solo el habla), el material de lectura y
  los enunciados, **no** las opciones de respuesta; de una sesión, los ejemplos, los
  enunciados, la pronunciación, la tarea, las frases del traslado y las tarjetas.
  **Excepción:** una oración de una sesión que está en uno de **sus propios audios** de
  traslado (los que lista en `audios`) sale de ese audio, que es lo que el método pide
  (repetir frases del audio), y no se cuenta.
- **b · Similitud.** El estímulo de cada unidad (texto, consigna o habla) se pasa a su
  conjunto de **trigramas de palabras** (cada tres palabras seguidas, normalizadas como
  arriba; un texto de una o dos palabras da un solo trigrama) y se compara cada par con la
  **similitud de Jaccard**: comunes ÷ (los de uno + los del otro − comunes). Con **0.85 o
  más** es un error (el 0.85 exacto cuenta). Para no comparar todos con todos, un índice de
  trigramas solo mira los pares que comparten alguno. Si dos textos son casi idénticos
  comparten también muchas oraciones; se reporta la regla b, con el número de oraciones
  que además comparten, y no la a.
- **c · Formas** (`v19_duplicados.dart`). Una unidad que aparece en dos formas (de
  cualquier uso, incluida la práctica, `uso: practica`), o dos veces en la misma forma
  (aunque sea en dos secciones; si no, una forma llegaría a las unidades del contrato
  repitiendo una). Los pares en que alguna de las dos formas es de uso `ubicacion`,
  `escalon` o `etapa` los dice V20, con su razón.

### V20 · método

Para cada forma de uso `ubicacion`, `escalon` o `etapa` (`usosExclusivos`), cada unidad
suya no puede estar en otra forma ni entre los `audios` del traslado de una sesión (la
única forma en que una sesión remite a una unidad). Se reporta en los dos lados: en la
forma reservada ("también la usa…") y en la forma o sesión que la usa ("reservada para la
forma…"). Dos formas de uso exclusivo que comparten una unidad se reportan entre sí.

## `informe [ruta]`

Lo que hay frente a lo que pide cada contrato. **No es una validación:** lee lo que haya
y lo cuenta; sale con 0 siempre que pueda leer la ruta (66 si no existe, 64 si el uso es
incorrecto). Tiene tres secciones:

1. **Cobertura por contrato y parte.** Una línea por cada parte de cada contrato:
   unidades y preguntas **que hay / que pide el contrato para una forma** (`?` si el
   contrato no lo da), mínimo, mediana y máximo de las palabras de los estímulos
   (`medidasDeEstimulo`) y el rango del contrato con su origen y si está pendiente. Cuenta
   las unidades que no están retiradas, como las cuenta el contrato: un archivo con
   `estimulo: ninguno` aporta tantas unidades como preguntas lleve, las oraciones omitidas
   aportan una pregunta por oración colocada y completar palabras, una por hueco. Al final,
   las unidades de formatos sin contrato.
2. **Fidelidad de las formas.** Por cada forma, `completa` o `reducida` y los motivos. O
   `sin formas`.
3. **Cobertura por escalón.** Si hay `niveles.yaml`: por cada escalón, las **sesiones** que
   dicen ser de él (campo `escalon`), los audios de traslado que usan y, por habilidad, las
   sesiones o audios con al menos una pregunta de esa habilidad y cuántas preguntas son
   (el orden de las habilidades es el de `niveles.yaml`). Si no hay, `sin niveles`.
   Las unidades de examen no entran: declaran su etapa (`nivel`), no su escalón.

### Fidelidad de una forma

La calcula `calcularFidelidad(forma, contexto)` (`lib/src/fidelidad.dart`), con el
contrato del formato de la forma. Es `completa` solo si, **para cada parte del contrato**:

- la forma la usa, con el número de unidades y de preguntas del contrato (si el contrato da
  un rango, cualquier valor dentro) y cada unidad con las preguntas por unidad que pide;
- todos los estímulos están dentro de su rango de palabras (las mismas medidas de V15);
- si es de escucha (por su `tipo_estimulo: audio`, por declarar `reproducciones` o por el
  nombre de su sección), cada unidad tiene un estímulo de audio con guion de habla y se oye
  las veces que pide el contrato;
- el contrato no marca la parte como `pendiente`.

Además impiden la fidelidad completa: una unidad con estímulo de imagen sin `archivo`
(formato, 4.1), una unidad retirada, una unidad de otra parte o de otro formato, una
unidad que no existe, una unidad repetida en la parte y una parte en más de una sección.
Una forma que no usa alguna parte del contrato es `reducida`: "faltan N partes" (todas
juntas y al principio). Sin contrato es `reducida`; la herramienta no inventa ninguno.

## Diseño (para P1.2c)

```
lib/src/
  hallazgo.dart              Hallazgo {archivo, id, codigo, gravedad, mensaje}
  texto.dart                 contarPalabras, palabrasDe, palabrasDeExamen, contarPalabrasEstimulo,
                             dividirOraciones, claveDeOracion, normalizarRespuesta, normalizarOpcion
  contexto.dart              contratos, niveles e ids de todo el conjunto; duplicados y usos (se calculan al pedirlos)
  medidas.dart               palabras de un estímulo, unidades y preguntas que aporta una unidad, rangos
  contenido.dart             de dónde sale el texto en inglés de cada regla (V17, V18, V19)
  duplicados.dart            IndiceDuplicados: oraciones repetidas y similitud de Jaccard (V19 a y b)
  usos.dart                  en qué formas y sesiones se usa cada unidad (V19 c y V20)
  fidelidad.dart             calcularFidelidad
  informe.dart               Informe: cobertura, fidelidad y escalones, y su texto
  modelo/                    un modelo por tipo de archivo y por tipo de pregunta
    leer.dart                leerTexto / leerMapa: YAML -> modelo (+ V01)
    archivo.dart             Unidad, Forma, Sesion, ArchivoFormato, ArchivoNiveles
    pregunta.dart            sealed Pregunta: los 15 tipos de la tabla 4.2
    formato.dart             Formato > Seccion > Parte (los campos de 6.1) y `datos` en bruto
    niveles.dart             Niveles (ver "Lo que el formato no fija")
  comprobaciones/vNN_*.dart  una función pura por comprobación: (Archivo, Contexto) -> List<Hallazgo>
  datos/palabras_gramaticales.dart   lista de V09, por categoría
  datos/palabras_espanolas.dart      lista de V17 y las palabras excluidas con su razón
  datos/grafias.dart                 lista de V18 y las formas ambiguas
  validador.dart             orquesta las comprobaciones y lee carpetas
```

Reglas del paquete:

- **Una sola función para cada cosa de texto.** Hay una sola tokenización (`_palabras`, en
  `texto.dart`): `contarPalabras` cuenta cada secuencia de letras, dígitos, apóstrofos o
  guiones; `palabrasDe` las devuelve para comparar; `contarPalabrasExamen` cuenta una
  contracción como dos; `contarPalabrasEstimulo` une las palabras cortadas;
  `normalizarRespuesta` compara una respuesta escrita como dice la sección 9 del formato;
  `normalizarOpcion` compara opciones entre sí (V03).
- Una comprobación nueva es un archivo en `comprobaciones/` y una línea en la lista
  `comprobaciones` de `validador.dart`.
- Lo que solo se ve en conjunto (V19, V20) lo calcula el `Contexto` una vez, al pedirlo.
- El modelo guarda el contenido tal como se escribió; no sortea ni calcula letras de
  respuesta (eso es de `exportar`). `calcularFidelidad` y `Informe` están listos para que
  `exportar` y `compilar` los usen.

## Lo que el formato no fija (y esta versión supone)

- **`niveles.yaml`:** el formato (sección 8) no da los nombres de los campos. Se leen
  `niveles`, `escalones`, `habilidades`, `focos` y `temas`, como lista de textos o de
  bloques con `id`. Si P1.3 elige otros, se cambia en `modelo/niveles.dart`.
- **Palabras de una transformación:** ningún contrato trae el campo; rige "de 2 a 5" de la
  tabla 4.2, salvo que la parte declare `palabras_respuesta`.
- **`habilidad` es obligatoria** en toda pregunta (el formato la muestra siempre, pero no lo
  dice).
- Sin contrato, o con contrato que no da `opciones`, V03 aplica 3 o 4 solo si no hay
  contrato; con un dato pendiente no decide nada.
- **Qué mide V15** (sección 6.2 solo dice "en un texto, sus palabras; en un audio, el habla"):
  el material de lectura cuenta como estímulo (ver arriba), la oración original de unas
  transformaciones es su estímulo (el contrato de la parte 4 de B2 First lo mide así) y una
  `consigna` se mide igual que un texto (los contratos de escritura traen su rango).
- **Qué es "una parte de escucha"** en la fidelidad: lo que el contrato marca con
  `tipo_estimulo: audio`, con `reproducciones` o en una sección llamada `listening` o
  `escucha`. La parte 1 de TOEIC Listening es `tipo_estimulo: imagen` con una
  reproducción (una foto y cuatro enunciados hablados): el formato no deja poner imagen y
  audio en la misma unidad, así que ninguna forma de esa parte puede ser completa todavía.
- **"Cada parte tiene el número de unidades y de preguntas"** (sección 5) se lee como cada
  parte **del contrato**: una forma que omite una parte es `reducida`.
- **V19 y las sesiones:** el formato dice "entre unidades"; aquí las sesiones también son
  fuente (con las excepciones de arriba), porque así lo pidió el encargo.
