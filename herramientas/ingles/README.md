# Herramienta del contenido de inglés

Valida el contenido de `data/ingles/` (formato `gravity-ingles-v1`, especificación
en `docs/specs/fase-8-ingles-formato.md`; plan en `docs/specs/fase-8-ingles-plan.md`).
Misma forma de paquete que `herramientas/biblia`. Única dependencia: `yaml`.

Estado: **P1.2a**. Solo existe la orden `validar`. `exportar`, `comparar`,
`compilar` e `informe` llegan en P1.2b y P1.2c.

```
cd herramientas/ingles
dart run bin/ingles.dart validar [ruta]   # por defecto, data/ingles desde la raíz del repositorio
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
| V24 | Solo la parte sin revisiones: un archivo en `validado` no puede tener errores; `revisado` y `aprobado` no existen todavía | `v24_estados.dart` |

Un archivo en `retirado` solo pasa V01 y V02.

### Sin contrato y sin niveles

Si falta el contrato de una unidad (por ejemplo `gravity-sesion-60`), `validar`
avisa "sin contrato" y sigue sin aplicar las reglas que dependen de él. Si falta
`data/ingles/niveles.yaml`, avisa "sin niveles". En `borrador` es aviso; de
`validado` en adelante, error. La herramienta no inventa ninguno de los dos.

## Diseño (para P1.2b y P1.2c)

```
lib/src/
  hallazgo.dart              Hallazgo {archivo, id, codigo, gravedad, mensaje}
  texto.dart                 contarPalabras, palabrasDeExamen, normalizarRespuesta, normalizarOpcion
  contexto.dart              contratos, niveles e ids de todo el conjunto
  modelo/                    un modelo por tipo de archivo y por tipo de pregunta
    leer.dart                leerTexto / leerMapa: YAML -> modelo (+ V01)
    archivo.dart             Unidad, Forma, Sesion, ArchivoFormato, ArchivoNiveles
    pregunta.dart            sealed Pregunta: los 15 tipos de la tabla 4.2
    formato.dart             Formato > Seccion > Parte (los campos de 6.1) y `datos` en bruto
    niveles.dart             Niveles (ver "Lo que el formato no fija")
  comprobaciones/vNN_*.dart  una función pura por comprobación: (Archivo, Contexto) -> List<Hallazgo>
  datos/palabras_gramaticales.dart   lista de V09, por categoría
  validador.dart             orquesta las comprobaciones y lee carpetas
```

Reglas del paquete:

- **Una sola función para cada cosa de texto.** `contarPalabras` cuenta cada
  secuencia de letras, dígitos, apóstrofos o guiones. `contarPalabrasExamen`
  cuenta una contracción como dos. `normalizarRespuesta` compara una respuesta
  escrita como dice la sección 9 del formato. `normalizarOpcion` compara
  opciones entre sí (V03).
- Una comprobación nueva es un archivo en `comprobaciones/` y una línea en la lista
  `comprobaciones` de `validador.dart`.
- El modelo guarda el contenido tal como se escribió; no sortea ni calcula
  letras de respuesta (eso es de `exportar`).

## Lo que el formato no fija (y esta versión supone)

- **`niveles.yaml`:** el formato (sección 8) no da los nombres de los campos. Se
  leen `niveles`, `escalones`, `habilidades`, `focos` y `temas`, como lista de
  textos o de bloques con `id`. Si P1.3 elige otros, se cambia en
  `modelo/niveles.dart`.
- **Palabras de una transformación:** ningún contrato trae el campo; rige "de 2 a
  5" de la tabla 4.2, salvo que la parte declare `palabras_respuesta`.
- **`habilidad` es obligatoria** en toda pregunta (el formato la muestra siempre,
  pero no lo dice).
- Sin contrato, o con contrato que no da `opciones`, V03 aplica 3 o 4 solo si no
  hay contrato; con un dato pendiente no decide.
