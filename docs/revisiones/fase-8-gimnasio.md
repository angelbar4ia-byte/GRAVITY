# Revisión de calidad — Fase 8, bloque 7 (Hábitos · Mi gimnasio), cierre G6

Revisor: agente `calidad` · Fecha: 24/nov/2026 · Árbol: `adc1def` (rama `claude/zen-pasteur-b0jblz`), más el trabajo sin confirmar de otros agentes (bicicleta y diseño), que no se revisó.
Alcance: `docs/specs/fase-8-habitos-gimnasio.md` (secciones 12 fila G6, 13, 14, 15, 21, 22 y 23), el dominio `paquetes/habitos_dominio/lib/src/gimnasio/`, la migración `supabase/migrations/20261152000000_habitos_gimnasio.sql` y las pruebas SQL 122 a 127, `app/lib/nucleo/gimnasio/`, `app/lib/modulos/habitos/gimnasio/`, `app/lib/diseno/gimnasio/`, `app/lib/app/gimnasio/`, la parte nativa (`MainActivity.kt`, `AndroidManifest.xml`), el catálogo de la IA en la nube y la función `gravity-asistente`.
Método: leí el código y lo contrasté con la especificación; recalculé valores con un script aparte que no lee el dominio; busqué una cadena marcada en todo lo que se guarda y se envía; probé la base con una persona atacante; y, donde encontré un defecto, escribí la prueba que lo demuestra.

## 1. Veredicto

**No se puede dar por cerrado en lo técnico todavía, pero está cerca.** No hay hallazgos bloqueantes de privacidad ni de permisos: ninguna molestia ni dato de salud sale del equipo, el catálogo de la IA en la nube no menciona el entrenamiento, el servidor aísla bien a cada persona, la accesibilidad cumple en las diez pantallas y el dominio da las mismas cifras que recalculé a mano. Quedan **1 hallazgo alto y 4 medios de código** (sección 3), más la revisión del contenido por un profesional (CA-G-45, G6-M5), que es manual.

Lo que más pesa:

1. **Sin señal, la sesión no se puede abrir ni cerrar (G6-A1, alto).** La especificación dice que «todo lo de la sesión funciona sin red» (R7, 9.1, CA-G-32), pero `ServicioGimnasio` lee y escribe la agenda y los registros de Hábitos directo a Supabase, sin protección. Las pruebas de G5 usan siempre repositorios en memoria y no lo ven. Lo hecho no se pierde (la sesión queda guardada en el teléfono antes de que falle), pero «Entrenamiento de hoy», «Empezar» y «Terminé la sesión» fallan sin conexión.
2. **Una persona del hogar puede saber si otra entrenó un día dado (G6-M1, medio).** Las llaves primarias de las sesiones y las series son solo `id`, y esos ids se pueden calcular. Lo probé con una base real: da `23505` cuando la otra persona tiene esa sesión.
3. **El modo foco deja una huella en el servidor (G6-M2, medio):** `semana_tipo = 'foco'` sube en claro, y esa palabra sale de un hábito a eliminar, que el dueño quiso tener solo en el teléfono.
4. **Falta el aviso del banco (G6-M3, medio)** que pide la especificación antes de usar fondos, subidas, sentadilla o puente apoyado en el banco inclinado.
5. **Con la hora de dormir pasada la medianoche el aviso de cercanía sale siempre (G6-M4, medio).**

Además, hay una **alerta de integración** que no es del gimnasio: el trabajo sin confirmar de la bicicleta exporta `fechaIso` y `horaTexto` desde `habitos_dominio` y **la app deja de compilar** (sección 2). Hay que resolverlo antes de integrar.

## 2. Pruebas y mediciones corridas

| Comando o medición | Resultado |
|---|---|
| `bash supabase/tests/correr.sh` (al empezar la revisión) | **Todo pasa: 78 archivos, 5169 afirmaciones** (122 a 127 son las del gimnasio). Fue antes de la migración de la bicicleta |
| `cd paquetes/habitos_dominio && dart test` | **354 pasan, 0 fallan.** Incluyen las 24 nuevas de este informe (`test/gimnasio/revision_g6_test.dart`) y las de la bicicleta de otro agente |
| `flutter test --exclude-tags hallazgo` en **una copia limpia de `adc1def`** más mis pruebas nuevas | **4350 pasan, 31 omitidas, 0 fallan** (una sola corrida de la suite completa) |
| Mis 4 archivos nuevos de la app, con y sin la etiqueta | 31 pasan; con la etiqueta `hallazgo`, **4 fallan a propósito** (G6-A1 ×2, G6-M3, G6-M4) |
| `cd api && npm run verificar` | **Al día** (`fnv1a32:382d5773`) |
| `flutter analyze` / `dart analyze` de mis archivos | Sin avisos nuevos |
| Sondeos SQL propios (`G6-M1`, restricciones de los dos jsonb, fecha futura) contra la base de pruebas | Resultados en G6-M1 y en B3 |
| Recálculo independiente (script en Python que aplica las fórmulas de 5.5, 5.6, 5.8 y 5.9) | Coincide con el dominio en todo (sección 4) |
| Barrido de invariantes: 1024 inventarios × 3 plantillas × 10 zonas × 3 intensidades × 3 versiones (285 696 sesiones, en un script aparte; la prueba incluida corre la versión estándar, 95 232) | 0 violaciones: ninguna usa equipo ausente o futuro ni una zona con molestia moderada o fuerte; toda sesión con menos de 3 ejercicios dice `sin_equipo_suficiente` |
| Kotlin de la pantalla encendida | Revisado a mano; no se puede compilar aquí (sección 6) |

**No se pudo comprobar:** nada en un aparato (A52, tablet) ni contra un Supabase real; la compilación del Kotlin; la lectura bajo el sol; TalkBack real. La lista de lo que hay que medir está en la sección 8.

**Alerta de integración (no es del gimnasio).** En el árbol de trabajo actual, `flutter test` no compila: `horaTexto` y `fechaIso` están importados dos veces (`app/lib/modulos/habitos/gimnasio/pantallas/comun.dart` y `datos/conversion_gimnasio.dart` frente a `paquetes/habitos_dominio/lib/src/bici/tipos_bici.dart`, que el barril `habitos_dominio.dart` ya exporta). Es trabajo sin confirmar de la bicicleta. Se resuelve renombrando o con `hide` en el barril, y hay que hacerlo antes del commit. Por eso corrí la app en una copia limpia de `HEAD`. Revisé también que la migración `20261153` de la bicicleta conserva el alcance `entrenamiento` y los topes de las seis tablas `hab_ent_*`.

## 3. Hallazgos

### Bloqueantes

Ninguno de privacidad, permisos ni seguridad.

### Altos

#### G6-A1. Sin señal no se puede abrir ni terminar una sesión

**Qué pasa.** `ServicioGimnasio` usa los dos repositorios de Hábitos que en la app real son directos a la red (`RepositorioAgendaSupabase` y `RepositorioHabitosSupabase`) y no atrapa los errores:

- `entrenamientoDe` (`app/lib/modulos/habitos/gimnasio/casos_uso/servicio_gimnasio.dart:429`) llama a `agenda.ajustes()` (línea 450) y, vía `bloqueDe` y `_ocupados`, a `agenda.bloques()` (líneas 339 y 346). Sin red lanza, y E1, E4 y E5 caen en su estado de error («No se pudo cargar el entrenamiento de hoy»).
- `terminarSesion` (línea 727) guarda la sesión local primero, pero después llama a `_registrarDia` (línea 792) y `_asegurarObjetivo` (línea 619), que usan `registros.guardarRegistro`, `registros.objetivos()` y `registros.guardarObjetivo`. Sin red lanza **después** de guardar; la pantalla (`sesion_en_curso.dart:216`, `_terminar`) no atrapa la excepción, así que no sale el mensaje ni se vuelve a Hoy. El botón *Hecho* de Hoy (`marcarHecho`, `hoy_gimnasio.dart:97`) tiene el mismo problema.
- Es el patrón que la especificación prohíbe copiar (H-12, R-10, 9.1).

**Efecto.** En un cuarto sin señal (o con Wi-Fi sin internet) la persona no puede empezar la sesión del día ni cerrarla. **No se pierde nada:** la sesión y las series quedan en el teléfono (la prueba de control lo demuestra).

**Cómo reproducirlo.** `cd app && flutter test test/revision_calidad/g6_gimnasio_sin_red_test.dart` (usa repositorios que lanzan `SocketException`). Con la etiqueta `hallazgo`: «abrir lo de hoy sin red no lanza» y «terminar la sesión sin red no lanza» **fallan**; el control «la sesión SÍ queda guardada» pasa.

**Corrección propuesta.**
1. En `entrenamientoDe`, `bloqueDe` y `_ocupados`, atrapar el fallo de la agenda y seguir con `AjustesHab()` por omisión y sin bloques (la sesión se arma con el plan y el equipo locales).
2. En `_registrarDia`, atrapar el fallo y dejar el registro del día en la cola con un tipo `habitos.registro` (o reintentarlo al volver la señal), como ya hace la sesión. Mientras tanto, que la pantalla vuelva a Hoy igual.
3. Una prueba de G5 con repositorios que lanzan, para que no se repita.

**Si el dueño decide que basta con «necesita señal»**, hay que decirlo en la especificación (CA-G-32 y 9.1) y poner un mensaje claro en la pantalla; hoy ni lo uno ni lo otro.

### Medios

#### G6-M1. Una persona del hogar puede saber si otra entrenó un día (llave primaria global)

**Qué pasa.** En `20261152000000_habitos_gimnasio.sql`, las líneas 87, 104 y 135 declaran `id uuid primary key` en `hab_ent_bandas`, `hab_ent_sesiones` y `hab_ent_series`. La llave es global, no por persona. Los ids de sesión y de serie son UUID v5 de datos que no son secretos: persona, fecha y plantilla (el espacio de nombres está en `app/lib/nucleo/gimnasio/ids_gimnasio.dart:16`, y el id de persona lo ve cualquiera del hogar). Alex (pareja) puede insertar una fila suya con el id calculado de la sesión de Ana: si Ana la tiene, recibe `23505 duplicate key` y si no, entra. Un bit por intento sobre «¿entrenó Ana el día D con la plantilla X?». Lo mismo con series (se calcula con el id de la sesión y los ids públicos del catálogo).

**Por qué importa.** Rompe la regla «cada persona ve solo lo suyo» (D5, R2 y 9) con una fuga pequeña pero real entre las personas que más se ven entre sí. Las tablas `hab_*` ya existentes no la tienen porque sus ids son v4.

**Cómo reproducirlo.** Probado contra la base de pruebas: `23505 | duplicate key value violates unique constraint "hab_ent_sesiones_pkey"`. La prueba, con el estilo de `supabase/tests`, está en `app/test/revision_calidad/g6_sonda_pk_global.sql` (instrucciones dentro: copiarla como el siguiente `NNN_hab_ent_sin_sonda.sql` y correr `bash supabase/tests/correr.sh NNN_*.sql`). Hoy falla con «HALLAZGO G6-M1»; con la corrección pasa (lo comprobé).

**Corrección propuesta (backend + plataforma).** Llaves por persona:

```sql
alter table public.hab_ent_sesiones drop constraint hab_ent_sesiones_pkey, add primary key (persona_id, id);
alter table public.hab_ent_series   drop constraint hab_ent_series_pkey,   add primary key (persona_id, id);
alter table public.hab_ent_bandas   drop constraint hab_ent_bandas_pkey,   add primary key (persona_id, id);
```

Las llaves foráneas ya apuntan a `(persona_id, id)`, así que siguen. Hay que cambiar `onConflict` a `persona_id,id` en `destinosUpsertGimnasio` (`app/lib/nucleo/cola/contrato_gimnasio.dart`) y los `on conflict (id)` de la prueba 127. Es una migración nueva (no se edita la 20261152).

#### G6-M2. El modo foco deja una huella en el servidor

**Qué pasa.** `semana_tipo` admite `foco` (spec 4.2, PG-11) y `iniciarSesion` lo guarda tal cual (`servicio_gimnasio.dart:656`). Esa fila sube en claro al hogar. «Foco» solo ocurre mientras hay un plan de hábito a eliminar con Día D, y esa información es de `habitos_sensibles`, que el dueño puede mantener solo en el teléfono (D21). El servidor aprende **las semanas** en que la persona estuvo en foco, aunque no el hábito. El generador nunca sabe la causa (eso sí se cumple), pero la fecha sí viaja.

**Cómo reproducirlo.** `flutter test test/revision_calidad/g6_gimnasio_privacidad_test.dart` → grupo «G6-M2» (caracterización: pasa y documenta que sale `foco`). No es un error de código: es lo que dice la especificación, pero la sección 15 no lo lista como riesgo.

**Corrección propuesta (decisión del dueño).** Subir `carga` en lugar de `foco` (el historial local sí distingue el foco), o aceptar el riesgo y anotarlo en la sección 15. Recomiendo lo primero.

#### G6-M3. Falta el aviso del banco antes de la primera vez

**Qué pasa.** La especificación (3.2, fila del banco) pide mostrar «revisa la capacidad y la estabilidad del banco» **antes de la primera vez** y pedir que la persona lo confirme. No existe: `CodigoAviso` no tiene un código del banco y ningún texto fijo lo dice. Solo hay «Revisa que el banco esté firme» dentro de la explicación de *fondos* y *subidas*. Los campos `banco_plano` y `capacidad_banco_kg` se piden en el inventario pero ninguna regla los usa. Fondos, subidas, sentadilla al banco y puente en el banco inclinado dependen de él.

**Cómo reproducirlo.** `flutter test test/revision_calidad/g6_gimnasio_contenido_test.dart` → «G6-M3» (con la etiqueta `hallazgo`) **falla**; el control de que la explicación diga «firme» pasa.

**Corrección propuesta.** Un `CodigoAviso.banco` (primera sesión que lo use y cada 4 semanas, como la banda) con un texto del catálogo y un botón «Ya lo revisé» que se guarda; y que la capacidad confirmada sea un dato visible.

#### G6-M4. Aviso de dormir con la hora de dormir pasada la medianoche

**Qué pasa.** `avisoDormir` (`paquetes/habitos_dominio/lib/src/gimnasio/ventana.dart:147`) calcula `dormirMin − finMin`. Con `hab_ajustes.dormir` a las 00:30 (30 minutos) y una sesión que termina a las 20:15, da −1185 y **avisa siempre**. La columna `dormir` es `time` sin restricción (acepta 00:00 a 03:00). Lo mismo le pasa al hueco libre (`_libreDesde`, `_hueco`).

**Cómo reproducirlo.** `flutter test test/revision_calidad/g6_gimnasio_privacidad_test.dart` → «G6-M4» (etiqueta `hallazgo`) **falla**; el control con dormir a las 22:00 pasa (105 min sin aviso, 30 min con aviso).

**Corrección propuesta.** Si `dormirMin <= despertarMin`, sumar 1440 a `dormirMin` antes de restar; igual en el cálculo del hueco.

#### G6-M5. Contenido que debe revisar un profesional (CA-G-45)

No es un defecto de código: es el contenido que, desde mi lectura y sin diagnosticar nada, **que lo revise un profesional** antes de pasar de `borrador` a `revisado`. Está al detalle en la sección 5.

### Bajos

- **G6-B1. Texto muerto.** `MensajesGimnasio.molestiaCambio` no se usa en la app (solo está en la lista de la prueba) y no menciona a un profesional; los textos que sí se ven (`TextosGimnasio.molestiaModerada`, `molestiaLeve`, `molestiaFuerte`) sí lo mencionan. Quitarlo o usarlo.
- **G6-B2. Ortografía.** `semanaDeDescargaBanner` termina sin punto («Es parte del plan»); `molestiasSoloAqui` también.
- **G6-B3. Texto libre en el servidor.** `hab_ent_inventario.notas`, los puestos `otro:<texto>`, `hab_ent_bandas.nombre` y las fichas de `confirmado` aceptan texto corto; los ids de catálogo, `sustituye_a` y `variante_id` solo se limitan por forma. Lo probé: el servidor acepta `{"rodilla": true}`, `{"nota":"rodilla_derecha_duele"}`, `otro:me duele la rodilla` y una banda llamada «para mi hombro lesionado». La lista negra de claves de `hab_ent_validar_inventario` no incluye partes del cuerpo. La app no manda eso (no usa `notas`), pero el nombre del puesto y el de la banda son libres en pantalla sin aviso. Es el riesgo R-7 ya aceptado; sugiero una línea «No escribas datos de salud aquí» y agregar `rodilla|hombro|espalda|cadera|tobillo|codo|muneca|cuello` a la lista negra.
- **G6-B4. Huellas visibles en capturas.** «Con precaución» y el aviso del dolor fuerte salen en E4 y E5, que se pueden capturar (solo E9 lleva FLAG_SECURE). Revelan que hay una molestia, no cuál. La especificación dice que el resto del entrenamiento no es sensible; lo dejo anotado.
- **G6-B5. R-8 sin cumplir del todo.** «Las molestias se pierden si se pierde el teléfono → se avisa al activarlas» no está en la pantalla de molestias, y no encontré el respaldo local cifrado con frase que menciona 4.3.
- **G6-B6. La especificación se contradice** en la tablet pública: CA-G-38 dice «ve la sesión y el historial no sensibles» y 7.1 oculta E7 (historial) en la pública. El código sigue 7.1.
- **G6-B7. Aviso de molestia fuerte.** Remite «a un médico o a un entrenador» (palabras de la especificación). Para dolor fuerte, súbito o con otro síntoma, un entrenador no es quien debe valorar; el profesional puede preferir decir solo «a un médico».
- **G6-B8. La lista negra de contenido médico compara palabras enteras** (`palabrasMedicasEn`). Atrapa «lesión» pero no «lesionarte». Mi prueba por raíces (30 raíces: lesion, diagnos, tratam, terap, tendin, inflam, garantiz, promet…) sobre todo el catálogo y los mensajes da **0 hallazgos**; recomiendo pasar la prueba de G1 a raíces.
- **G6-B9. La serie de aproximación no cuenta en la duración estimada** (adrede, spec 3.6); suma uno o dos minutos reales.

## 4. Corrección del dominio (recalculada a mano)

Script independiente (Python, solo con las fórmulas de la especificación) contra el dominio; coinciden todas las cifras. Las pruebas están en `paquetes/habitos_dominio/test/gimnasio/revision_g6_test.dart`.

| Valor | Especificación | Mi cálculo | Dominio |
|---|---|---|---|
| A corta / estándar / larga sin extras | 29.3 / 35.3 / 48.4 | 1758 s / 2118 s / 2904 s | igual |
| A larga con extras | 60.9 | 3654 s | igual |
| B corta / estándar / larga con extras | 29.3 / 35.3 / 61.3 | 1758 s / 2118 s / 3678 s | igual |
| B larga sin bandas | 54.4 | 54.4 | igual |
| C corta (sin patada) / estándar / larga | 31.2 / 45.8 / 63.1 | 1875 s / 2748 s / 3789 s (con la patada «por pierna») | igual |
| A lunes 19:15 → B miércoles 19:15 | 48 h, cumple | 48.0 h | cumple, sin aviso |
| C martes 19:15 → ruta sábado 8:00 | 84 h 45 min | 84.75 h | sin aviso |
| C jueves 19:15 → ruta | 36 h 45 min, avisa | 36.75 h | 2205 min, avisa (`versionCorta`, `dejarComoEsta`) |
| C viernes 20:00 → ruta | 12 h, avisa | 12.0 h | 720 min; propone `moverAlJueves` primero |
| A 20:00 → B 19:00 (47 h) / B 18:59 | cumple / avisa | 47 h / 46 h 59 min | cumple / 1 aviso |
| Ciclo 3 + 1 desde el lunes 30/nov/2026 | descarga el 21/dic; ciclo nuevo el 28/dic | 1, 2, 3, **4**, 1 | igual; el 27/dic también es descarga |
| Descarga | 2 series, mínimo del rango, una placa menos | — | igual (`series 2`, `repsAlMinimo`, `bajarUnPaso`) |
| Reentrada: 6, 7, 13, 14, 55, 56 días | normal, repite, repite, reentrada, reentrada, desde cero | — | igual |
| Doble progresión: 12-12-12 esfuerzo 3 / 12-12-11 / 12-12-12 esfuerzo 5 | placa 6 y objetivo 10 / mantiene / mantiene | — | igual |
| Elegir versión: C con 75 y 70 min; A con 40 y 38 | larga, estándar, corta, ninguna | 73.1, 55.8, 39.3 | igual |
| Aviso de dormir (22:00, margen 90): fin 20:15, 20:30, 21:30 | no, no, sí (30 min) | — | igual (el hallazgo G6-M4 es solo con dormir pasada la medianoche) |

Observación (no es defecto): el principiante recibe 2 semanas de adaptación (2 series) y **solo 1 semana de carga completa** antes de la primera descarga del ciclo 3 + 1. Está en la especificación (5.9 y 5.11); lo dejo para que el dueño lo sepa.

## 5. Contenido (catálogo `borrador`)

Texto revisado: 100 textos del catálogo y los mensajes, y 379 textos de las pantallas. **Sin hallazgos** de diagnóstico, tratamiento, medicamento, dosis ni nombre de lesión (prueba por raíces); ningún texto culpa ni promete resultados («Pérdida de grasa» es solo una etiqueta de objetivo y la pantalla dice «no calcula calorías ni masa»); no hay signos de exclamación; los avisos de molestia que se ven mencionan «profesional», «médico» o «entrenador»; la guía dice abiertamente «Todavía no la revisa un entrenador».

Cifras para un principiante: repeticiones de 8 a 15, 3 series (2 en las 2 primeras semanas), descanso de 45 a 75 s, plancha de 30 a 45 s, subidas de 8 a 12 por pierna, calentamiento de 5 a 8 min, escalera de progresión acotada (techo +3 repeticiones una vez, hasta 4 series y hasta 5 en la larga, tempo 3-1-1, descanso nunca menor a 45 s). Me parecen sensatas.

**Que lo revise un profesional** (CA-G-45; no son diagnósticos, solo lo que me llamó la atención y por qué):

1. **Fondos en banco (A4)** y su variante `fondos_banco_piernas`. Es un ejercicio que se discute por la carga que pone en el hombro, se hace sobre el **banco inclinado** (no sobre un banco plano y fijo), y el generador **ofrece primero la variante más difícil** (piernas estiradas) a un principiante, porque toma la primera disponible sin mirar el nivel. La pista de técnica «Bajar más de lo que tu hombro cómodamente permite» es vaga. Decidir si se conserva, se empieza con rodillas flexionadas o se cambia.
2. **Bandas ancladas en la puerta o en la estación** (press, jalón, extensión de tríceps, face pull). El único texto de seguridad es «Revisa la banda… Asegura bien el ancla.» Falta, por ejemplo, de qué lado debe abrir la puerta y qué ancla aguanta. Y **dos bandas juntas** como peldaño de progresión.
3. **Sentadilla con banda pisada y sobre los hombros** (`sentadilla_banco_banda`): si la banda se suelta, sube hacia la cara y el cuello.
4. **«Sentadilla sin banco, con apoyo en una pared o ancla»** (`sentadilla_apoyo`): «ancla» es ambiguo; agarrarse de un ancla de puerta como apoyo puede ser peligroso. Dejar solo «pared».
5. **Subidas al banco, puente apoyado y sentadilla al banco sobre el banco inclinado:** estabilidad y altura del banco desconocidas (ver G6-M3).
6. **Paso de carga = una placa completa.** En ejercicios chicos (elevación lateral, curl, tríceps) una placa puede ser un salto grande; la regla «sube si todas las series llegan al máximo con esfuerzo 4 o menos» incluye el esfuerzo 4 («duro»). Que el profesional diga si conviene un paso menor o exigir esfuerzo 3.
7. **Descanso de 45 s** en la versión corta y en el objetivo «pérdida de grasa» para ejercicios de pierna (sentadilla, subidas): puede ser corto para un principiante.
8. **Aviso de dolor fuerte** (G6-B7): el orden «médico o entrenador».
9. **Hombro leve:** en el catálogo actual todas las variantes de empuje cargan el hombro, así que la alternativa «sin esa zona» no existe y salen todas «con precaución» (ya lo decía la sección 21). Que el profesional diga qué ofrecer.

## 6. Privacidad, servidor y plataforma: lo verificado

**Privacidad (D3, D6, D13, D21, PG-03).**
- Prueba de punta a punta nueva (`app/test/revision_calidad/g6_gimnasio_privacidad_test.dart`): molestia de rodilla moderada con nota marcada `G6-MARCA-RODILLA-ZZ9`; dos sesiones completas (una A y una C) con cambio de ejercicio por precaución (motivo local «molestia»), series y terminar. Se buscó la nota y las palabras `molest`, `rodilla`, `dolor` y `zona` en **todas las tablas de la base local, la cola de subida, lo que recibe un servidor simulado (todas las peticiones, su ruta y su cuerpo) y el almacén seguro**. Resultado: **0 apariciones**. El servidor recibió `motivo_cambio = "otra"`, ninguna ruta de molestias ni de `hab_sobres`.
- No hay columna, tabla ni cola de molestias; `hab_sobres.tipo` solo admite los dos tipos de la nube; el sobre `salud_local` está fuera de la subida diferida (`enviador_supabase.dart:192`) y de `admiteNube`.
- `allowBackup="false"` y reglas de extracción que excluyen todo: las molestias no entran en el respaldo de Android.
- El catálogo de la IA (`catalogo.json`) y `gravity-asistente` **no contienen** «entrenamiento», «gimnasio», «ejercicio», «molestia» ni `hab_ent`; la orden `habitos.abrir_entrenamiento` solo navega, no guarda historial y no está en el registro de la IA. Lo vigila `entrenamiento_sin_ia_test.dart`.
- Ninguna pantalla del gimnasio importa clientes de IA, de red directa ni de Health Connect. La única importación de Supabase del módulo es `datos/lector_gimnasio.dart`, que **solo lee** `hab_ent_*` bajo RLS. No hay `health` en `pubspec.yaml` ni en el manifiesto.
- No hay `print` ni registros con datos: los dos `debugPrint` de la pantalla encendida y del lector escriben el tipo del error, no el contenido.
- Notificación del descanso: «Termina tu descanso» (19 caracteres, sin dígitos), sin cuerpo ni nombres; solo teléfono y tablet personal, no la laptop ni la pública.

**Servidor (RLS).** Leí la migración como atacante y probé a Alex (pareja), Carla (familiar), Marta (cuenta maestra), Diana (cuidadora), la cuenta Casa, Elena (otro hogar), `anon` y `service_role`. Las pruebas 122 a 127 cubren que nadie lee ni escribe lo ajeno, las llaves foráneas compuestas no cruzan personas, el upsert sobre el id de otra persona da `42501`, `persona_id`, `hogar_id` y `actualizado_en` los pone el servidor, el último cambio gana, una fecha a 10 años se ajusta, el borrado cubre las seis tablas y la baja a 90 días, la cuota falla cerrado y el motivo «molestia» se rechaza. Mis sondeos sumaron: el `plan` rechaza claves extra, números fuera de rango y variantes con texto libre. La única fuga que encontré es G6-M1 (y los textos libres de G6-B3). `hab_borrar_datos_de` borra primero series y sesiones y luego bandas (el orden importa por las llaves).

**Roles y equipos.** Dueño, coadministrador y familiar abren las diez pantallas; cuidadora, Hogar y cuenta maestra no ven nada; las molestias no están en la laptop ni en la tablet pública; el texto «Todavía no está en la tablet de la casa» ya no existe (revisado con `grep` y por `gimnasio_por_rol_test.dart`); la retención de 10 minutos y su vuelta a 2 minutos están probadas en `gimnasio_tablet_test.dart`.

**Pantalla encendida (canal nativo), a mano.**
- `MainActivity.kt` agrega un segundo `MethodChannel` (`mx.segundocerebro.gravity/pantalla_encendida`, método `establecer`, argumento `encendida`) igual al de Dart; pone y quita `FLAG_KEEP_SCREEN_ON` en el hilo de interfaz; sin dato, devuelve el control al sistema (`?: false`), que es lo seguro; `onDestroy` la suelta; el canal de `FLAG_SECURE` queda intacto. Sintaxis y tipos correctos; no veo error de compilación.
- Ciclo de vida (`pantalla_encendida.dart`): contador de pedidos con época, suelta en `paused`, `hidden` y `detached`, y vuelve a pedir en `resumed`; `inactive` no cambia nada; si el canal falla, se anota y se sigue. La sesión la pide al empezar o retomar y la suelta al terminar, salir o cambiar de persona.
- **Sin permisos nuevos:** el manifiesto no cambió desde antes del gimnasio (`git log d9bacad..HEAD` vacío para `AndroidManifest.xml`, `pubspec.yaml`, `pubspec.lock` y `res/`).
- Riesgo que solo se ve en el aparato: si Android recrea la actividad con el mismo motor, la bandera se pierde y Dart cree que sigue encendida hasta el siguiente cambio de ciclo de vida.

**Dependencias.** Ninguna nueva: `pubspec.yaml`, `pubspec.lock` y el manifiesto no cambian desde la especificación. `npm run verificar` está al día.

## 7. Criterios de aceptación CA-G-01 a CA-G-45

Leyenda: **Sí** = cubierto por pruebas que pasan; **Sí (G6)** = además lo comprobé yo; **Parcial** = falta algo; **Manual** = solo en aparato o con una persona.

| CA | Estado | Evidencia o falta |
|---|---|---|
| G-01 a G-05 | Sí | `catalogo_test`, `confirmaciones_test`, `contenido_medico_test`; G6 agrega la revisión por raíces (G6-B8) |
| G-06 a G-09 | Sí (G6) | `generador_test`, `bandas_test`, `equipo_futuro_test`; G6 barrió 285 696 sesiones (0 violaciones) |
| G-10 a G-13 | Sí (G6) | Recalculado a mano: 11 tiempos, versiones, plan de 3, 4 y 5 días |
| G-14 y G-15 | Sí (G6) | 48 h con los casos de la sección 4; sesión perdida |
| G-16 a G-21 | Sí (G6 en 16, 18 y 19) | Doble progresión, descarga con fecha 30/nov, reentrada; escalera, foco y récords por G1 |
| G-22 a G-25 | Sí (G6 en 22 y 24) | Invariantes de molestias; aviso de dormir correcto con dormir a las 22:00 (falla solo pasada la medianoche: G6-M4) |
| G-26 a G-31 | Sí, con **G6-M1** | SQL 122 a 127 en verde; falta cubrir la llave primaria global |
| G-32 | **Parcial** | La cola y el id estable están probados; **sin red real la sesión no abre ni cierra (G6-A1)** |
| G-33 y G-34 | Sí | `pantallas_gimnasio_test`, `servicio_gimnasio_test` |
| G-35 | Sí / Manual | Temporizador, aviso y reducir movimiento probados; la llegada en segundo plano es manual (sección 8) |
| G-36 | Sí (G6) / Manual | Flujo completo con cola y servidor simulado: 0 apariciones; FLAG_SECURE y respaldo, manual |
| G-37 | Sí | `servicio_gimnasio_test` (agenda) |
| G-38 | Sí / Manual | Retención y reposo probados; texto viejo retirado; la tablet real es manual (G6-B6) |
| G-39 | Sí (G6) | `fuentes_gimnasio_test`, `entrenamiento_sin_ia_test`; revisado a mano |
| G-40 | Sí (G6) | Tono, signos y avisos discretos; 379 textos de pantalla sin culpa ni promesas |
| G-41 | **Sí (G6)** / Manual | Antes solo la sesión en curso; ahora las **10 pantallas**, en 360 dp (teléfono) y 1000 dp (laptop), con letra al 200 %, sin desbordes, objetivos táctiles de 48 dp, etiquetas y contraste (23 pruebas); lectura bajo el sol es manual |
| G-42 a G-44 | Sí | `gimnasio_por_rol_test`, modo foco, `ordenes_entrenamiento_test` |
| G-45 | **Manual, pendiente** | El dueño con su fisioterapeuta; ver la lista de la sección 5 |

## 8. Lo que solo se prueba en aparato (A52, tablet): lista breve y accionable

1. **Estimación contra el tiempo real.** Cronometrar una sesión A, una B y una C en versión estándar (estimadas 35.3, 35.3 y 45.8 min). Anotar la duración real y repetir hasta 3 sesiones: comprobar que la calibración cambia la estimación y que la tolerancia (33 a 50 min) se cumple.
2. **Aviso del descanso en segundo plano.** Activar el ahorro de batería, apagar la pantalla, descanso de 60 s: medir el retraso en 10 intentos con la app abierta, en segundo plano y deslizada fuera de recientes. Probar con el permiso de notificaciones negado (el temporizador debe seguir en pantalla), con horas silenciosas (sin sonido) y en la tablet personal.
3. **Vibración.** Corta, una sola vez, al terminar el descanso: en el bolsillo, sobre el banco, con la vibración táctil del sistema apagada; en la tablet sin motor debe quedar solo la marca visual.
4. **FLAG_SECURE.** Entrar a molestias (E9): captura de pantalla negra o rechazada, grabación de pantalla, vista de «recientes» en blanco, y que se **libere** al salir. Confirmar que E4 y E5 sí se pueden capturar (G6-B4) y que el modo privado oculta E9.
5. **Pantalla encendida 45 min.** En el A52 y la tablet personal: iniciar una sesión y dejarla 45 min sin tocar el teléfono salvo para las series; confirmar que no se apaga, anotar el consumo de batería, y que **sí** se apaga sola al terminar, al salir, al pasar a segundo plano y después de cerrar la app con deslizar. En la laptop no debe pedirse.
6. **Retención de la tablet.** Tablet pública con nombre y PIN, sesión en curso: sin tocar 9 min (sigue), 11 min (vuelve a Casa y la sesión queda `en_curso`), y un toque cada 5 min (no vuelve). Retomar con el PIN. Mientras tanto, comprobar que la cuenta Casa no ve nada de dinero ni de otra persona. En la tablet personal, que pida el PIN pasados 10 min.
7. **TalkBack y NVDA/Narrador.** E1, E4, E5 y E9: la serie anuncia «Serie 2 de 3, 12 repeticiones, placa 3, pendiente»; el temporizador anuncia cada 15 s y al terminar; − y + etiquetados; orden del foco; «Contenido en revisión» anunciado. Con la letra del sistema al 200 % y «tamaño de pantalla» grande en el A52.
8. **Legibilidad.** Bajo el sol o con la luz del gimnasio y con las manos mojadas: ✓ de 64 dp, números del temporizador y contraste de la personalidad Sport.
9. **El aparato real (F-E5).** Confirmar placas de la pila, kilos por placa, relación de la polea, puestos extra, anclaje seguro en la estación, banco plano y su capacidad, tobillera: y que las variantes `estacion` **no** aparezcan hasta confirmarlas.
10. **Sin red de verdad (G6-A1).** Modo avión: abrir Hoy, empezar, registrar 3 series, terminar; volver la señal y comprobar que sube **una sola vez** y sin duplicados. Repetir con Wi-Fi sin internet.
11. **Respaldo de Android.** `adb shell bmgr` o una restauración de prueba: el sobre de molestias no debe volver tras reinstalar.
12. **Hora de dormir pasada la medianoche** (G6-M4) y con el reloj en 12/24 horas.

## 9. Preguntas para el dueño

1. **G6-A1:** ¿la sesión del gimnasio debe funcionar de verdad sin señal (como dice la especificación) o basta con que avise «necesita conexión»? Recomiendo lo primero.
2. **G6-M1:** ¿apruebas la migración nueva con llaves por persona? Cambia `onConflict` en la app y en la prueba 127.
3. **G6-M2:** ¿se sube `carga` en lugar de `foco` (recomendado) o se acepta que el servidor sepa las semanas de foco?
4. **G6-M3 y la sección 5:** ¿se lo llevas al fisioterapeuta con la lista de 9 puntos? Los puntos 1 a 4 son los que más cambian el contenido.
5. **G6-B6:** ¿la tablet pública ve el historial (CA-G-38) o no (7.1)?
6. Pendientes de G5 que conviene decidir ya (sección 23): si una semana es «de foco» cuando cualquier día lo está, y si *Hecho* sin series cuenta para el objetivo «Entrenamiento».

## 10. Archivos nuevos de esta revisión (todos en las carpetas de calidad y de pruebas del dominio)

- `docs/revisiones/fase-8-gimnasio.md` (este informe).
- `app/test/revision_calidad/g6_gimnasio_privacidad_test.dart`: privacidad de punta a punta, huella del foco (M2) y aviso de dormir (M4, etiquetada).
- `app/test/revision_calidad/g6_gimnasio_accesibilidad_test.dart`: 10 pantallas × 2 anchos al 200 % + contraste.
- `app/test/revision_calidad/g6_gimnasio_sin_red_test.dart`: G6-A1 (2 etiquetadas y 1 de control).
- `app/test/revision_calidad/g6_gimnasio_contenido_test.dart`: G6-M3 (etiquetada) y control de borrador.
- `app/test/revision_calidad/g6_sonda_pk_global.sql`: G6-M1 (prueba SQL; hoy falla; ver instrucciones dentro).
- `paquetes/habitos_dominio/test/gimnasio/revision_g6_test.dart`: recálculo independiente, invariantes y contenido por raíces (24 pruebas, todas pasan).

Comandos: `cd app && flutter test test/revision_calidad/g6_gimnasio_privacidad_test.dart test/revision_calidad/g6_gimnasio_accesibilidad_test.dart test/revision_calidad/g6_gimnasio_sin_red_test.dart test/revision_calidad/g6_gimnasio_contenido_test.dart` (con `--exclude-tags hallazgo` para saltar las que fallan hasta que se corrijan) y `cd paquetes/habitos_dominio && dart test test/gimnasio/revision_g6_test.dart`.
