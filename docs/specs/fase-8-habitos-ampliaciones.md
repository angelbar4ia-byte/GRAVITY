# Fase 8 · Bloque 5 — Hábitos: Inglés (en la app)

> **Versión 0.6** (17/nov/2026), **propuesta** para el dueño. La 0.5 es del 16/nov/2026; esta versión incorpora D-ING-11 a 15 (ver la lista de cambios de la 0.6, abajo). Paquete **P0.3** del plan de inglés (`docs/specs/fase-8-ingles-plan.md`, versión 0.6). Reescribe por completo la versión 0.4 (14/nov/2026), que quedó atrás respecto a las decisiones del dueño del 15 y 16/nov/2026. Es **solo especificación**: no hay código, ni SQL, ni cambios en ningún `pubspec.yaml`.
>
> **No cambia ninguna decisión confirmada.** D-ING-1 a 10 están en `docs/DECISIONES.md` (D29, líneas 555 a 571) y en el plan (4.1); las reglas de borde, en el plan (4.2). Lo que esta versión resuelve por su cuenta va marcado **Propuesta P5-nn** y se reúne, con lo que pasa si el dueño la veta, en la sección 13.
>
> **El curso no arranca hasta que la fase 6 del plan (pareja y corrección con IA) esté integrada** (D-ING-9 y D-ING-10). Esta especificación describe cómo funcionará el bloque cuando arranque; no cambia ese orden.
>
> **Base:** `CLAUDE.md`; `docs/DECISIONES.md` (D3, D5, D13, D21 y D29); `docs/ROADMAP.md` (11.1); el plan 0.6 (secciones 3, 4.1 y 4.2, fases 2, 3 y 6, anexos E y F); `docs/contenido/ingles/niveles-y-avance.md` 0.4 (secciones 3.6 y 8); los contratos `data/ingles/formatos/gravity-sesion-60.yaml`, `gravity-ubicacion.yaml` y `gravity-escalon.yaml`; `data/ingles/niveles.yaml`; el formato `docs/specs/fase-8-ingles-formato.md` 0.4 (secciones 5, 7 y 11); el motor de voz `docs/specs/fase-8-motor-de-voz.md` 0.1 (secciones 6, 10 y 12); la revisión `docs/revisiones/fase-8-ingles.md` (ING-I7 y los hallazgos que tocan la app); `docs/specs/fase-3-habitos.md`; y el código y las migraciones de Hábitos.
>
> **Cómo se marca lo que se afirma.** *Decidido*: lleva su fuente (D29, plan o sección). **Propuesta P5-nn**: decisión de esta versión, que el dueño puede vetar. `archivo:línea`: se comprueba leyendo ese archivo. **[consultado]**: lo leí el 16/nov/2026 en el paquete `speech_to_text` 7.5.0 de la caché de pub de este entorno (`app/pubspec.yaml:81`). Todo ejemplo numérico y de calendario se comprobó con un script.

**Lista de cambios de la versión 0.6** (sobre la 0.5; el detalle, en 11.3):

1. **Asistencia (D-ING-12):** 10 minutos por día y 3 días faltados por escalón; al cuarto, el escalón se repite. Reemplaza al 90 % de minutos y a los días de gracia por trimestre (3.3, 3.4, P5-30).
2. **Pruebas por unidad (D-ING-14):** cuatro por escalón, que cuentan para subir; el viernes es de repaso. Sustituye a P5-08 (3.6.1, P5-31).
3. **Sin conexión completo (D-ING-13):** qué se estudia sin red, qué la necesita, cola, instalación por adelantado y estados visibles (sección 9).
4. **Dictado local (D-ING-13)** como requisito de 5b y qué ve la persona si el equipo no lo garantiza (4.4).
5. **Texto y transcripción a la IA con permiso; voz solo en el dispositivo (D-ING-15)** (R4, 4.4, 7.1).
6. **Nota para el dueño** sobre los prefijos `hab_` e `ing_` (15).

**Lista de cambios de la versión 0.5** (el detalle, punto por punto, está en la sección 11):

1. De «lecciones de 5 a 10 minutos, B1 a B2» a la **sesión de 60 minutos** de la escalera de 13 escalones de 8 semanas (D-ING-1 y D-ING-2).
2. De «prueba de nivel que se repite a los 30 días» a la **ubicación única** de 12 preguntas por etapa, corregida después con **puerta anticipada** y **descenso por evidencia** (D-ING-5).
3. Las **puertas** pasan a ser una máquina de estados con tabla de transiciones, los casos de borde del plan 4.2 y los puntos que `niveles-y-avance.md` dejó para esta versión.
4. **Audio y habla** (antes fuera de alcance): lo que el curso pide al motor de voz, grabar la voz sin que salga del dispositivo y transcribirla en el dispositivo.
5. **Exámenes** (antes fuera de alcance): fidelidad, práctica por partes, semáforo y rótulo de los formatos reducidos.
6. **Pareja y corrección con IA**: solo lo que necesita el estudiante; el resto lo define P6.0.
7. **Modelo de datos nuevo:** doce tablas `ing_*` con las convenciones de `hab_*` (D21); el contenido ya no vive en tablas, sino compilado en `app/assets/ingles/`.
8. **Una sola numeración de semanas:** 1 a 8 dentro de cada escalón.
9. **Criterios de aceptación numerados** (CA-5a-01 y siguientes), cada uno con su prueba.

## 1. Resultado buscado y alcance

### 1.1 Qué entrega este bloque

**Resultado.** Una persona con Hábitos (el dueño, su pareja o un familiar) se **ubica una sola vez**, estudia **una hora diaria de lunes a viernes** con un contenido que ya viaja dentro de la app, y sube de escalón **solo si lo demuestra**, sin culpa y sin que su progreso salga del control de ella. Estudiar no usa la red; la única función que sí la usa, la corrección de escritura y habla de las puertas, es opcional y va por la función del asistente (D-ING-9).

| Sub-bloque | Qué entra | Sección |
|---|---|---|
| **5a Núcleo** | Perfil (escalón actual e historial), sesión del día por bloques, minutos y día completo, asistencia y faltas, repaso espaciado, mini prueba del viernes y pruebas por unidad, puertas como máquina de estados (con puerta anticipada y descenso por evidencia), pantallas | 3 |
| **5b Audio y habla** | Lo que el curso pide al motor de voz, grabar la voz (se queda en el dispositivo) y transcribirla en el dispositivo | 4 |
| **5c Ubicación** | Una sola vez por persona, 12 preguntas por etapa, pausar y reanudar, tabla de entrada, qué se guarda y cómo el servidor impide una segunda | 5 |
| **5d Exámenes** | Formas de las puertas y su fidelidad, práctica por partes, semáforo, rótulo de los formatos reducidos | 6 |
| **5e Pareja y corrección con IA** | Lo que necesita el estudiante; el resto lo define P6.0 | 7 |
| **Transversal** | Modelo de datos `ing_*`; sin conexión y sincronización; criterios de aceptación | 8 a 10 |

**Dónde vive cada cosa** (carpetas del agente `habitos`, `docs/ROADMAP.md` 11.2):

| Pieza | Carpeta | Estado |
|---|---|---|
| Dominio puro (sin dependencias), carpeta `ingles` | `paquetes/habitos_dominio/lib/src/ingles/` (el paquete no tiene dependencias: `paquetes/habitos_dominio/pubspec.yaml`) | Por escribir (P2.3) |
| Datos, casos de uso, estado y pantallas | `app/lib/modulos/habitos/ingles/` (carpeta nueva dentro de las propias) | Por escribir (P2.4) |
| Contenido compilado | `app/assets/ingles/` (lo escribe `compilar`; no se edita) | Por escribir (P1.2c) |
| Tablas `ing_*`, reglas por persona y pruebas SQL | `supabase/migrations/` y `supabase/tests/` | Por escribir (P2.2, agente `backend`) |
| Contenido fuente y herramienta | `data/ingles/` y `herramientas/ingles/` | Existen (P1.1 a P1.3) |

### 1.2 Qué queda fuera

| Queda fuera | Por qué o a dónde va |
|---|---|
| **Conversación con IA en vivo** y coach de inglés | La IA de este bloque solo corrige la escritura y el habla de las puertas (D-ING-9, plan 3.8). La conversación guiada del viernes es un guion sin IA (3.2) |
| **Pareja**: calendario compartido, reto semanal, revisión cruzada, qué ve cada quien del otro | P6.0 (`docs/specs/fase-8-habitos-pareja-y-correccion.md`, todavía sin escribir). Mientras tanto, **nada se comparte** (7) |
| **Conversión a las escalas oficiales** de Cambridge, TOEIC y TOEFL | Plan 3.4: solo se muestra cuando la escala esté verificada en su fuente (6.4) |
| **Interfaz bilingüe y alternancia de pantallas** (diseño de Hábitos, 5.3 y A.5) | Sigue fuera: D29 no la toca |
| **Inglés para el trabajo, series con subtítulos y niveles C1 en adelante** | Fuera de la escalera de D-ING-1 (llega a B2.4) |
| **Pausas del curso** (vacaciones, enfermedad) | No hay decisión del dueño: pregunta 1 (15). Mientras tanto, solo las tres faltas por escalón cubren un día perdido (3.4) |
| **Aviso del curso por Firebase o por el servidor** | Los recordatorios de Hábitos son locales (`docs/specs/fase-3-habitos.md`, regla 117) |
| **Inglés en la tablet pública de la casa** | D21: la pública no muestra nada de Hábitos en modo Casa (`docs/DECISIONES.md`, línea 477). La tablet personal funciona como el teléfono |
| **Paquetes nuevos** | Esta especificación no agrega ninguno. Grabar y transcribir los evalúa P3.2b y los aprueba el dueño (4) |

### 1.3 Reglas que no se rompen

| # | Regla | De dónde sale | Cómo se cumple aquí |
|---|---|---|---|
| R1 | **Ni dinero ni datos clínicos a la IA en la nube**; el filtro corre en el servidor antes de que salga texto; la clave del proveedor nunca va dentro de la app | D3 (`docs/DECISIONES.md`, línea 79), D29 (D-ING-9), plan 3.8 | El inglés no maneja dinero ni datos clínicos. Lo único que puede salir es el texto o la transcripción de una tarea que la persona entrega a propósito, por `supabase/functions/gravity-asistente` (7) |
| R2 | **Hábitos es personal**: cada persona ve solo lo suyo; la cuenta maestra no lo lee; ni el dueño ni la pareja leen lo ajeno | D5, D21 (línea 478), `docs/specs/fase-3-habitos.md` (convención 1) | Las tablas `ing_*` usan la misma regla que `hab_*`: `persona_id = persona_actual()` y `hab_activa(hogar_id)` (`supabase/migrations/20261105000000_habitos.sql:328-337`) (8.3) |
| R3 | **Las tablas de Hábitos no escriben en la bitácora**; el prefijo `habitos.*` es del servidor y está oculto al dueño y a la maestra | D21 (línea 478), `20261105000000_habitos.sql:426-455` | Ninguna tabla `ing_*` lleva trigger de bitácora, y el prefijo `ing_` se reserva igual que `hab_` (8.3, 14) |
| R4 | **Los textos que escribe, lo que dice y su voz grabada no salen del dispositivo**, salvo que **el texto y la transcripción** de una entrega pueden ir a la IA **con permiso en cada envío** y el filtro de D3. **La grabación de voz nunca sale** | D13, D21, plan 3.5 y 3.8; D-ING-13 y D-ING-15 | Texto, transcripción y grabación se guardan solo en el dispositivo (4, 7, 9.3). A la nube de Supabase solo van números; a la IA, solo el texto de esa entrega y con permiso (7.1) |
| R5 | **Estudiar no usa la red** | Plan 1 (punto 4) y 3.6 | Todo el curso instalado funciona con la red cortada (9.1) |
| R6 | **Tono sin culpa; una acción diaria en 3 toques o menos** | `.claude/agents/habitos.md`, `docs/DISENO_UX_UI.md` (flujo F2) | Catálogo cerrado de mensajes con revisión automática (3.8); Hoy → Inglés → Empezar (3.8) |
| R7 | **Sin contadores guardados:** rachas, minutos, escalón actual, tarjetas por vencer y semáforo **se calculan** desde los registros | `docs/specs/fase-3-habitos.md` (convención 3) | El servidor guarda hechos; el dominio calcula (8.1) |
| R8 | **Semana en lunes, fechas locales, UUID del dispositivo, enteros** | `docs/specs/fase-0-cimientos.md` (sección 4) | Los escalones empiezan en lunes (3.1); ninguna cifra es `double` en el dominio (2) |
| R9 | **Las etiquetas A1, A2, B1 y B2 se ganan solo en la puerta de la etapa y no hay etiqueta provisional** | D-ING-1, D-ING-10 | Mientras falte una corrección no se muestra veredicto ni etiqueta (3.7) |
| R10 | **Sin secretos ni datos reales en el repositorio** | `CLAUDE.md` | Los ejemplos de este documento son inventados |

## 2. Convenciones y palabras

Se aplican las convenciones de `docs/specs/fase-0-cimientos.md` (sección 4) y las de la Fase 3 (`docs/specs/fase-3-habitos.md`, sección 3). Las palabras son las del plan (sección 1), más las que esta versión necesita añadir.

| Palabra | Significa aquí |
|---|---|
| **Escalón** | Tramo de 8 semanas y 40 horas con su puerta al final. Son 13: A1.1, A1.2, A2.1 a A2.3, B1.1 a B1.4 y B2.1 a B2.4 (D-ING-1) |
| **Etapa** | A1, A2, B1 o B2. La etiqueta de una etapa se gana al pasar su puerta |
| **Puerta** | La prueba que hay que pasar para subir. Es **de escalón** (prueba propia de GRAVITY) o **de etapa** (forma completa con el formato de un examen oficial: A2.3, B1.4 y B2.4; la de A1.2 es una prueba interna). Son 13 puertas y 39 formas (plan 4.2) |
| **Ciclo** | Cada vez que la persona entra a un escalón, sea por primera vez, por subir, por bajar o por repetirlo. Una fila de `ing_escalones` (8.2) |
| **Semana 1 a 8** | La semana de un ciclo. La única numeración que existe. La **semana de práctica** que sigue a una puerta no aprobada **no es la semana 9**: es práctica (3.7) |
| **Día de estudio** | Lunes a viernes. El sábado y el domingo no lo son: no cuentan ni rompen nada. El domingo trae inglés ligero opcional que no cuenta (`docs/contenido/ingles/niveles-y-avance.md`, sección 5) |
| **Sub-bloque** | Cada una de las partes de la sesión: repaso, lección, pronunciación, producción y las tres del traslado (3.2) |
| **Turno de puerta** | Lo que se presenta de una puerta en un día. Una puerta de etapa dura lo que su examen y se reparte en 2 o 3 turnos (3.7) |
| **Caída** | No aprobar ninguna de las dos oportunidades de una puerta. «Dos bajas seguidas» (plan 4.2) son dos caídas seguidas (3.7) |
| **Baja por puerta / baja por evidencia** | Pasar al escalón de abajo tras una caída, o tras dos mini pruebas seguidas por debajo de 50 % (D-ING-5). La segunda **no** es una caída (P5-09) |
| **Repite** | Volver a empezar el mismo escalón (A1.1 tras una caída, o un escalón con la puerta aprobada pero sin asistencia o sin pruebas por unidad suficientes) |

**Convenciones de este bloque**

1. **Identificadores en español sin acentos** (`Escalon`, `EstadoCurso`, `diasFaltados`). Textos de la interfaz en español de México con acentos. El contenido está en inglés americano en el curso y británico en los exámenes de Cambridge, según su `variante` (plan 4.2).
2. **El dominio es Dart puro, sin dependencias y sin reloj propio:** recibe `hoy` y usa `soloDia`, `lunesDe`, `sumarDias`, `diasEntre` y `redondearMitadArriba` de `paquetes/habitos_dominio/lib/src/fecha.dart`. No reutiliza `calcularRachaDiaria` (`rachas.dart:24-61`): esa función cubre **por semana** y el inglés cubre **por escalón** (3.4).
3. **Enteros.** Porcentajes sin decimales (`aciertos × 100 ≥ umbral × preguntas`), sumas ponderadas de 0 a 400, minutos acreditados en **segundos**, y redondeo a la mitad hacia arriba cuando hace falta. Ninguna cifra es `double`.
4. **Las cifras de D29 viven en un solo lugar del dominio** (`ReglasIngles`: 80, 90 y 50 %, 8 de 10, 2 oportunidades, 10 minutos de tolerancia por día, 3 días faltados por escalón, 80 % de las pruebas por unidad, 35 y 60 minutos, 3 cajas, 40 tarjetas por bloque…) y una prueba las compara con `data/ingles/formatos/gravity-escalon.yaml` y `gravity-sesion-60.yaml` (CA-5a-02). Así el código no se separa del contrato.
5. **Ids estables.** UUID v5 para lo que no debe duplicarse al reintentar (el ciclo, el día de estudio, el bloque de un día, el intento de una puerta); UUID v4 para lo demás (`docs/specs/fase-3-habitos.md`, convención 5).
6. **Último cambio gana** solo en lo editable (ajustes del perfil y caché de tarjetas); lo demás es solo agregar (8.3).
7. **El contenido manda sobre la interfaz:** ninguna pantalla escribe «completo», «verificado» ni «aprobado» por su cuenta; muestra lo que dice el contenido compilado (V24 y V26 del formato, sección 11).

## 3. Sub-bloque 5a · Núcleo en la app

### 3.1 Perfil de la persona

El **perfil de inglés** no es una fila guardada: es una vista que el dominio **calcula** desde los registros (regla R7). Solo los ajustes de la persona (recordatorio, interruptor de la IA, versión del contenido) viven en `ing_perfil`.

| Dato del perfil | Cómo se obtiene | Tabla (8.2) |
|---|---|---|
| **Escalón actual** y su ciclo | La última fila de `ing_escalones` (la de `desde` más reciente) | `ing_escalones` |
| **Semana del ciclo** | `semana = (lunesDe(hoy) − desde) ÷ 7 + 1`. Entre 1 y 8 es la semana del escalón; más de 8 no es «semana 9»: es práctica o espera de corrección (3.7) | `ing_escalones` |
| **Historial** | Todas las filas de `ing_escalones` en orden: escalón, motivo de entrada y fecha de inicio | `ing_escalones` |
| **Etiquetas ganadas** | A1, A2, B1 o B2 está **ganada** si existe un intento aprobado de la puerta que cierra esa etapa (oportunidad 1 o 2, anticipada o puerta inmediata de B2). Una etiqueta **no se pierde** al bajar (plan 4.2) | `ing_intentos`, `ing_puntajes` |
| **Ubicación** | Su fila única, con el escalón de entrada | `ing_ubicaciones` |
| **Horas estudiadas** | Suma de `segundos` acreditados ÷ 3 600, junto a las horas nominales del escalón (40) | `ing_bloques` |
| **Racha y mejor racha** | 3.4 | `ing_sesiones`, `ing_bloques` |
| **Ajustes** | Hora del recordatorio, interruptor de la corrección con IA, versión del contenido compilado | `ing_perfil` |

**Cómo se muestra el nivel.** `A2 · escalón 1 de 3 · semana 4 de 8` y, aparte, `Etiquetas ganadas: A2 (12/feb/2027)`. **Nunca** `B1+`: D29 da etiquetas solo en las puertas de etapa y la escalera no tiene una puerta que la otorgue (`docs/contenido/ingles/niveles-y-avance.md`, sección 6; plan 4.2). Un escalón repetido se rotula «segunda vuelta».

**Motivos de entrada a un escalón** (`ing_escalones.entrada`): `ubicacion`, `sube`, `sube_anticipada`, `baja_por_puerta`, `baja_por_evidencia`, `repite_tras_caida` (solo A1.1, plan 4.2) y `repite_por_requisitos` (P5-13). Cada una es una fila nueva; nunca se edita una anterior.

**Propuesta P5-03 · Los escalones empiezan en lunes.** Un ciclo empieza **el primer lunes posterior** a la fecha en que se registra el cambio (el resultado de la ubicación, la aprobación de una puerta, una baja o un repite). Así la semana 1 es siempre una semana completa de lunes a viernes, `desde` es siempre un lunes (el servidor lo comprueba, 8.2) y nadie empieza a media semana con un día ya perdido. Si el veredicto de una puerta llega entre semana, esos días se cubren con repaso del escalón que termina (3.7).

**Propuesta P5-28 · El escalón actual y las etiquetas se calculan, no se guardan.** Si el dueño prefiere una columna `escalon_actual` en `ing_perfil`, hay que validar las transiciones en el servidor (una función como `hab_cambiar_modo`); con el cálculo, el servidor solo guarda hechos y dos equipos no se pueden desincronizar (9.4).

### 3.2 La sesión del día por bloques

Lo aprobado por el dueño (D-ING-2): **60 minutos de lunes a viernes**, en un **bloque principal de 35** y un **traslado de 25** (`data/ingles/formatos/gravity-sesion-60.yaml:31-35`). La app arma la sesión del día con el contenido compilado de la semana y el día del ciclo (3.1); no inventa nada.

| # | Sub-bloque | Min. | Lunes a jueves | Viernes | Sin audio (respaldo, 3.3) |
|---|---|---|---|---|---|
| 1 | **Repaso** | 5 | Tarjetas vencidas (3.5) | **Mini prueba** de 10 preguntas en su lugar (3.6) | Igual; además aquí se presentan las 8 tarjetas nuevas (3.5) |
| 2 | **Lección** | 10 | **Lun** gramática y vocabulario: explicación, 6 ejemplos, error común y 10 preguntas · **Mar** escucha: un audio propio con 10 preguntas · **Mié** pronunciación: explicación del sonido y 14 elementos · **Jue** lectura y escritura: un texto con 10 preguntas | **Conversación guiada** de 8 turnos (P5-17) | El martes muestra el guion como texto y queda marcada *sin audio* |
| 3 | **Pronunciación** | 8 | 12 elementos para oír y repetir | Igual | Se muestran escritos y se marcan |
| 4 | **Producción** | 12 | Tarea con consigna, lista de cotejo y respuesta modelo. La modalidad (escrita o hablada) la trae el contenido; el jueves es escrita | Monólogo o diálogo grabado (habla) | Igual |
| 5 | **Traslado · escucha** | 10 | Los **dos audios de la semana** (un monólogo y un diálogo), dos veces cada uno, sin preguntas. Son los mismos los cinco días | Igual | Aparece como *disponible cuando haya audio* y no cuenta minutos |
| 6 | **Traslado · repetición** | 10 | 20 frases para oír y repetir | Igual | Aparece como *disponible cuando haya audio* y no cuenta minutos |
| 7 | **Traslado · tarjetas** | 5 | Tarjetas en audio: las 8 nuevas del día | Sin tarjetas nuevas; repasa las del día | Aparece como *disponible cuando haya audio* y no cuenta minutos |

Fuente de la tabla: `docs/specs/fase-8-ingles-formato.md`, sección 7 (líneas 277 a 286), y `gravity-sesion-60.yaml` (bloques `principal`, `traslado`, `viernes`). Los mínimos de contenido (10 preguntas, 12 elementos, 20 frases…) son del formato y los comprueba la herramienta (V21 y V22); la app **no** los vuelve a comprobar.

**Cómo se comporta cada sub-bloque**

1. **Preguntas de la lección.** Cada una se contesta una vez, con retroalimentación inmediata: la respuesta correcta y su `porque`, y el `porque_no` de la opción elegida. Las opciones llegan **ya ordenadas** por el sorteo de `compilar` (V06): la app no las vuelve a mezclar, para que la posición de una opción no cambie entre dispositivos. Las respuestas escritas se comparan con `aceptadas` sin distinguir mayúsculas, espacios repetidos, apóstrofo recto o curvo, ni el punto o signo de interrogación final (`docs/specs/fase-8-ingles-formato.md:327`).
2. **Producción.** La persona escribe o graba; después ve el modelo y se autoevalúa con la lista de cotejo (marcas locales). La corrección con IA de una tarea **diaria** es opcional y no cuenta para ninguna puerta (7).
3. **Traslado.** Pensado para el camino al trabajo: la reproducción no depende de la pantalla (`docs/specs/fase-8-motor-de-voz.md`, sección 6.4). Hasta que P3.2b resuelva el servicio en primer plano, funciona con la app abierta.
4. **Orden.** La persona puede hacer los sub-bloques en el orden que quiera, y el traslado antes o después del principal. La app propone el siguiente pendiente con un solo botón.

**Propuesta P5-17 · La conversación guiada del viernes.** El formato dice *«diálogo guiado de 8 turnos con variantes»* y deja sin definir los campos del bloque, qué son las variantes y cuánto cuenta cada turno en V22 (`gravity-sesion-60.yaml:245-247`). Sin IA, es un **guion de 8 turnos de la persona**, cada uno precedido por una línea de la app:

- Cada turno trae: la **línea de la app** en inglés, dicha con una voz del guion (F1, F2, M1 o M2); la **indicación** en español de qué decir (*«Dile que te gusta trabajar desde casa»*); un **modelo** en inglés; **al menos 2 variantes** (otras formas válidas de decir lo mismo, cada una con otra estructura de las del escalón); y **1 o 2 puntos de cotejo** (*«Usé el presente continuo»*).
- **Un turno:** la app dice su línea › la persona **habla** (grabar es opcional) › ve el modelo y las variantes y marca el cotejo › *Siguiente*. Sin audio, la línea de la app se muestra escrita.
- **Cuenta 60 segundos por turno** (8 turnos son 8 minutos: el 80 % de los 10 declarados, dentro del 70 al 150 % de V22).
- Es una **práctica**, no una prueba: ninguna IA la califica y no cuenta para ninguna puerta; ensaya la tarea de habla que sigue en la producción del viernes.
- Se pide al formato 0.5 el bloque `conversacion` con esos campos (14). La conversación con IA en vivo queda fuera (1.2).

**La sesión de cada día es la del calendario del ciclo, no la «siguiente sin hacer».** La semana y el día salen de la fecha (3.1). Es la lectura de la regla del dueño *«si pierdes un día, no se recupera con dos bloques seguidos: al día siguiente se hace la lección que tocaba y el repaso espaciado de las palabras pendientes»* (`niveles-y-avance.md`, sección 5): el día siguiente trae **su** lección y su repaso recoge las tarjetas atrasadas (3.5).

**Propuesta P5-05 (parte 1) · Una sesión perdida se puede estudiar después, pero no suma.** Desde Progreso › Semanas, la persona puede abrir cualquier sesión de un día pasado de su ciclo como **práctica libre**. Esa práctica **no** suma minutos, **no** completa ese día y **no** quita una falta del escalón; sus tarjetas y sus repasos sí entran al repaso espaciado. Así la regla de no recuperar se cumple y el contenido no se pierde.

**Las ocho semanas de un escalón** (`data/ingles/niveles.yaml`, bloque `plan_de_las_8_semanas`, y plan 4.2):

| Semanas | Contenido | Mini prueba del viernes | Puerta anticipada |
|---|---|---|---|
| 1 a 7 | Cinco sesiones por semana con la plantilla de arriba (35 sesiones) | Sí (10 preguntas) | La semana 2 (3.7) |
| 8 | **Repaso y puerta.** Sesiones de repaso y, en los últimos días, los turnos de la puerta (3.7). La puerta cuenta dentro de las 40 horas (plan 4.2) | No: la puerta ocupa su lugar | No |

**Domingo.** Inglés ligero opcional (un versículo o una canción en inglés, o un resumen de la semana). No es día de estudio: no suma minutos, no completa nada y no se usa para cubrir un día perdido. Sin recordatorio por omisión.

### 3.3 Minutos y día completo

Dos preguntas distintas, que no se mezclan: **¿cuántos minutos cuentan?** (para la asistencia que pide subir, 3.4) y **¿está completo el día?** (para la constancia).

**Minutos planeados de un día** (decidido: 60 con audio, 35 sin audio; D-ING-2 y plan 4.2).

**Propuesta P5-04 · Cuántos minutos se planean y cuántos se acreditan.**

- **Planeados:** un día cuenta **35** si la app registró al menos un bloque ese día y **todos** se empezaron **sin audio** (la voz del curso no estaba disponible: `MotorVoz.disponibilidad(UsoVoz.curso, …)` del motor, sección 6.1 del motor de voz). En cualquier otro caso cuenta **60**, también el día en que no se estudió nada. Con el audio integrado antes del arranque (D-ING-9), los 35 minutos son solo un respaldo.
- **Acreditados:** cada sub-bloque acredita **sus minutos declarados × los elementos hechos ÷ los elementos que trae**, en segundos y redondeado a la mitad hacia arriba. Los minutos declarados son los del contenido (5, 10, 8, 12, 10, 10 y 5: `gravity-sesion-60.yaml`). El tiempo que la persona tarda no importa: importa lo que hizo. Dejar la app abierta no suma.
- **Límite conocido:** si el audio falla a media jornada, el día ya tiene un bloque con audio y sigue contando 60; lo cubre una de las tres faltas del escalón (3.4). Es el precio de una regla que no se puede inflar.

| Sub-bloque | Elementos | Cuenta como hecho cuando… | Notas |
|---|---|---|---|
| Repaso | Las tarjetas de la cola del bloque (hasta 40, 3.5) | Se contestó cada una | Cola vacía = hecho, con los 5 minutos: no tener tarjetas no se castiga |
| Mini prueba | 10 preguntas | Se contestó cada una | Aprobada o no, acredita lo contestado (3.6) |
| Lección | Sus preguntas (10 o más) | Se contestó cada una | La explicación no se puede medir; no es un elemento |
| Conversación guiada | Sus turnos (8 o más) | Se terminó cada turno | Viernes (3.2) |
| Pronunciación | 12 elementos o más | Se oyó y se marcó *Practicado* (o se grabó) | |
| Producción | 1 | Se **entregó** con una extensión mínima: la **mitad del mínimo de la etapa**, redondeada hacia arriba. Escrita: A1 15 palabras, A2 25, B1 40, B2 70. Hablada: A1 15 s, A2 23 s, B1 30 s, B2 45 s | Todo o nada; evita acreditar 12 minutos por escribir una palabra. Cifras de `gravity-sesion-60.yaml:177-182` |
| Traslado · escucha | 4 reproducciones (2 audios × 2) | Cada una terminó (`Fin.completa`) | |
| Traslado · repetición | Las frases de la sesión (20 o más) | Se oyó y se esperó el tiempo de repetirla | |
| Traslado · tarjetas | Las que trae la lista de audio | Se dijo cada una | Sin acción de calificar: es exposición (3.5) |
| Turno de puerta | 1 | Se terminó el turno | **Acredita 60 minutos** aunque dure menos o más (P5-15) |

**Día completo** (decidido: *un día está completo cuando se hacen el bloque principal y el traslado*; `niveles-y-avance.md`, sección 5).

**Propuesta P5-05 (parte 2) · Completo es completo.** Con audio, el día está completo cuando **todos los elementos de los siete sub-bloques** están hechos. Sin audio, los de los **cuatro** del principal (D-ING-2). El estado `completo` es estricto y solo gobierna el anillo de la sesión y la marca *Día completo*; **lo que cuenta para la constancia es la asistencia** (3.4), que tolera hasta 10 minutos por día (D-ING-12). Así, 11 de 12 elementos de pronunciación no completan el día, pero no lo pierden. El día de un turno de puerta está completo al terminar ese turno. La **fecha** de un bloque es la fecha local en que **empezó**: uno que cruza la medianoche cuenta en el día de inicio.

**Ejemplos** (comprobados con un script):

| Caso | Planeados | Lo mínimo que deja pasar la asistencia (3.4: 3 días en cero y el resto con 10 minutos de tolerancia) |
|---|---|---|
| Un escalón con audio: 8 semanas × 5 días × 60 | 2 400 min (40 h) | 37 × 50 = 1 850 min |
| Un escalón sin audio: 8 × 5 × 35 | 1 400 min (23.3 h) | 37 × 25 = 925 min |
| Mixto: 30 días con audio y 10 sin audio | 30 × 60 + 10 × 35 = 2 150 min | 27 × 50 + 10 × 25 = 1 600 min (las tres faltas caen en días con audio) |
| Un escalón con una semana de práctica (3.7), con audio | 2 700 min | 42 × 50 = 2 100 min |
| Un lunes: repaso completo, lección 10 de 10, pronunciación 9 de 12, producción entregada, traslado completo | 60 | Acredita 5 + 10 + 6 + 12 + 25 = **58 min**: el día queda **incompleto** (faltan 3 elementos) pero **asistido** (faltan 2 minutos, menos de 10) |

La asistencia se evalúa con enteros, **por día**: `faltante = segundosPlaneados − segundosAcreditados` (no menor que cero) y el día se asiste si `faltante ≤ 600` (3.4), sobre los días de estudio de la ventana que dice 3.7. El 90 % de los minutos que pedía la versión 0.5 **se retira** (D-ING-12).

**Propuesta P5-27 · Metas semanales, solo informativas.** Progreso muestra, por semana, **5 de 5 días completos**, **300 minutos** (175 sin audio) y **60 tarjetas repasadas** (las metas vigentes: `docs/contenido/ingles/CONTEXTO.md`, sección 2; que «60 tarjetas» sean repasos hechos y no tarjetas distintas es una interpretación mía). Ninguna bloquea nada: subir lo deciden los cuatro requisitos (3.7).

### 3.4 Asistencia, faltas y constancia (D-ING-12)

**Decidido (D-ING-12, 16/nov/2026; `docs/DECISIONES.md`, D29, línea 570):** *solo se pueden faltar 10 minutos por día y 3 días completos; pasado eso no se completa el curso y se repite.* El plan lo anota con una **lectura mía, a confirmar**: «el curso» es **el escalón** (plan 4.1, D-ING-12). Esta sección la sigue, y la pregunta 9 del apartado 15 pide confirmarla.

**Propuesta P5-30 · Cómo se cuenta la asistencia (por día y en total).** Reemplaza al 90 % de los minutos y a los días de gracia por trimestre de la versión 0.5 (P5-01 y P5-02 quedan **retiradas**: ya no hay trimestre).

1. **Por día.** `faltante = planeados − acreditados`, en segundos y sin bajar de cero (los planeados y los acreditados son los de 3.3: 60 minutos, o 35 sin audio, y lo que de verdad se hizo). El día queda **asistido** si el `faltante` es de **600 segundos o menos**. Los 10 minutos son de **cada día**: no se acumulan de un día al siguiente ni se pueden «ahorrar».
2. **En total.** Un día de estudio con más de 10 minutos de faltante, **estudie o no**, es un **día faltado**: se cuenta como un día completo, aunque se hayan estudiado 40 de 60 minutos (no hay crédito parcial: es la lectura más simple de *«3 días completos»*; pregunta 9b). Se cuentan **por ciclo de escalón** (la ventana de 3.7.5), no por trimestre. **Los tres primeros** días faltados del ciclo quedan **tolerados**; del cuarto en adelante, **excedidos**.
3. **Qué pasa al excederse.** El escalón **no se completa** y se **repite** (T15, con motivo `asistencia`; 3.7.4). No se corta el estudio: la persona sigue hasta la puerta, que le da información real y, si la aprueba, **gana la etiqueta de la etapa** (como en P5-13). Lo que cambia es que el escalón vuelve a empezar el lunes siguiente (segunda vuelta, con las faltas en cero) y que en su semana 2 queda la puerta anticipada como atajo.
4. **Sin culpa.** La app avisa **antes** (al usar la tercera falta: *«Hoy cuenta como tu falta número 3 de este escalón»*) y no reprocha después (catálogo en 3.8).

| Estado de un día de estudio | Cuándo |
|---|---|
| `asistido` | `faltante ≤ 600 s` (incluye el día `completo` de 3.3) |
| `faltado` | `faltante > 600 s` y es uno de los tres primeros del ciclo (**tolerado**) |
| `excedido` | `faltante > 600 s` y ya se usaron las tres |
| `abierto` | Es hoy y todavía no termina |
| `noAplica` | Sábado, domingo o un día anterior al inicio del curso |

**Ejemplo** (inicio el lunes 23/nov/2026, con audio). El miércoles 25/nov no se estudia: faltante 3 600 s, día faltado (1.ª falta). El miércoles 2/dic se acreditan 40 minutos: faltante 1 200 s, día faltado (2.ª). El jueves 10/dic, 55 minutos: faltante 300 s, **asistido**. El jueves 17/dic, 49 minutos: faltante 660 s, día faltado (3.ª). El viernes 8/ene/2027 no se estudia: **excedido**; el escalón se repetirá. Con 50 minutos justos (faltante 600 s) el día se asiste; con 49:59, no. **Sin audio** (35 planeados): 25 minutos asisten; 24:59, no.

**La racha de inglés** (P5-19) es el número de días de estudio seguidos `asistido` o `faltado`; el fin de semana no la rompe ni la suma; un `excedido` la rompe, y la **mejor racha nunca baja**. Usa los mensajes que ya existen (`MensajesHabitos.rachaRota`, *«Un día no borra lo que has avanzado. Retomemos hoy.»*: `paquetes/habitos_dominio/lib/src/mensajes.dart:3`). Progreso muestra **cuántas faltas quedan** en el escalón (*«Te quedan 2 de 3 faltas en este escalón»*); es un cálculo, no un contador guardado.

**Propuesta P5-19 · El inglés tiene su propia racha y no entra a la racha global de Hábitos.** La racha global promedia objetivos con **una** gracia por semana (`hab_ajustes.gracia_semanal`, `20261105000000_habitos.sql:66`); el inglés tiene **tres faltas por escalón**. Mezclarlas obligaría a elegir una de las dos reglas del dueño. La fila de Inglés en Hoy (3.8) muestra la racha del inglés; `evaluarDiaGlobal` (`rachas.dart:109-120`) no cambia. *Alternativa si se veta:* contar el día asistido de inglés como un elemento más del día global, con la gracia semanal.

**Requisitos 3 y 4 para subir, con una sola cuenta.** El dueño dijo cuatro requisitos: pruebas, evaluación de cierre, constancia y 90 % de minutos. D-ING-12 pide asistencia y la dice **junta**; la función `asistenciaDelCiclo` los evalúa a la vez: **constancia** = ningún día `excedido` (a lo más tres faltados) y **minutos** = todo día no faltado con faltante de 10 minutos o menos. Es todo o nada, como la dijo el dueño. La pantalla de resultado muestra los dos números por separado (faltas usadas y minutos acreditados) para que se entienda **cuál** faltó.

**Lo que no cambia.** El día en curso no se juzga hasta que termina (como el día de hoy en `rachas.dart:46-47`). Una sesión pasada estudiada después como práctica libre **no** suma (P5-05) y no quita una falta. Mientras no haya pausas (pregunta 1), una enfermedad también gasta las faltas.

### 3.5 Repaso espaciado de las tarjetas

**Qué es una tarjeta.** Una del contenido (`id`, `en`, `es`, `ejemplo`; el `id` es único en todo el curso y el ejemplo contiene la palabra: V23, `gravity-sesion-60.yaml:224-228`) o una **tarjeta de error** que nace de una pregunta fallada de la mini prueba (3.6): su frente es el enunciado y su reverso, la respuesta y el `porque`. El estado de una tarjeta **se calcula** reproduciendo sus repasos (más abajo); no hay contadores.

**Propuesta P5-06 · El algoritmo.** Los intervalos van en **días de estudio** (lunes a viernes): un día de estudio después del viernes es el lunes. Hay **tres cajas**, con intervalos de **1, 5 y 20** días de estudio, y tres calificaciones.

| Calificación | Efecto | Vence |
|---|---|---|
| **Otra vez** (no la supe) | Vuelve a la **caja 1** (como decía la versión 0.4: *«error lo regresa a un día»*) | El siguiente día de estudio |
| **Bien** | Sube **una** caja. Un *bien* en la caja 3 la **domina**: sale del repaso | Caja 1, 1 día de estudio · caja 2, 5 · caja 3, 20 |
| **Fácil** | Sube **dos** cajas (en la caja 2 o 3 la domina) | Igual |

- Una tarjeta **nueva** se presenta una vez (3.2) y entra a la **caja 1**; vence el siguiente día de estudio. Una tarjeta **dominada** no vuelve sola; sigue en *Mis tarjetas* y se puede **reactivar** (vuelve a la caja 1).
- La fecha del intervalo es la **fecha del repaso**, no la hora (P5-04: el día es la fecha local).
- **La tarjeta fallada reaparece una sola vez**, al final de la cola del mismo bloque. Ese segundo intento es práctica: no cambia la caja ni cuenta como elemento hecho.

**La cola del bloque de repaso.** Hasta **40 tarjetas** (7.5 segundos cada una en los 5 minutos del bloque). Orden fijo: por fecha de vencimiento (las más atrasadas primero), luego por caja y luego por `id`. Si hay más vencidas que lugares, el resto espera y la pantalla lo dice sin reproche (*«Hay 12 tarjetas esperando. Hoy repasamos las más antiguas»*). *Repasar más* es opcional, desde Tarjetas, y no suma minutos.

**Tarjetas nuevas por día.** **8 de lunes a jueves, 0 el viernes, 32 por semana** (`gravity-sesion-60.yaml:216-219`). Con audio se presentan en el sub-bloque *Traslado · tarjetas* (el contrato lo cuenta ahí de forma provisional: `:220-223`); sin audio, **al principio del repaso**, ocupando hasta 8 de los 40 lugares. Una nueva que no se presentó ese día **no se acumula** al día siguiente (regla de no recuperar, 3.2); la práctica libre de ese día sí puede presentarla. El viernes no hay repaso (la mini prueba ocupa su lugar): lo vencido espera al lunes.

**Por qué tres cajas y no ocho (cálculo mío, sin medir con personas).** Cada tarjeta nueva exige tantos repasos como cajas tenga. Con 32 tarjetas nuevas a la semana, unas 3 de error de la mini prueba y repaso solo de lunes a jueves, simulé 520 días de estudio (8 % de *otra vez* y 12 % de *fácil*):

| Escalera | Cola de 20 | Cola de 30 | Cola de 40 |
|---|---|---|---|
| 8 cajas (1, 2, 4, 7, 15, 30, 60, 120) | Rezago de unas 2 900 tarjetas | Unas 2 600 | Unas 2 100 |
| 4 cajas (1, 4, 14, 45) | Unas 1 900 | Unas 900 | Estable (38 repasos al día) |
| **3 cajas (1, 5, 20), con dominio** | Unas 1 200 | Al límite (31 vencidas al día y 3 de rezago) | **Estable: 28 vencidas al día y ningún rezago** |

El rezago es el promedio de los últimos 100 días de estudio de una simulación de 520. Con la cola de 40: aunque la persona falle el 15 % y los errores sean 6 por semana, el promedio sube a 42 vencidas al día con 3 de rezago; y tras una semana sin estudiar el rezago llega a 55 y se limpia en 3 días de repaso. **Una escalera larga no cabe en 5 minutos con 32 palabras nuevas a la semana**; por eso es corta y el piloto de A2.1 (P1.5) mide el número real de repasos al día. La pregunta 5 del apartado 15 es del dueño: pone el costo en el lugar correcto (menos tarjetas nuevas o más tiempo de repaso).

**Ejemplo comprobado** (una tarjeta que se presenta el lunes 23/nov/2026):

| Fecha | Qué pasa | Caja | Vence |
|---|---|---|---|
| lun 23/nov | Se presenta | 1 | mar 24/nov |
| mar 24/nov | *Bien* | 2 | mar 1/dic (5 días de estudio) |
| mar 1/dic | *Bien* | 3 | mar 29/dic (20 días de estudio) |
| mar 29/dic | *Bien* | **dominada** | — |
| mar 1/dic (si en vez de *bien* fuera *otra vez*) | *Otra vez* | 1 | mié 2/dic |
| vie 27/nov (otra tarjeta) | *Otra vez* | 1 | **lun 30/nov** |
| mar 24/nov (otra tarjeta) | *Fácil* desde la caja 1 | 3 | mar 22/dic |

**Convergencia entre equipos.** El estado de una tarjeta es el resultado de aplicar, en orden de (`ocurrido_en`, `id`), todos sus repasos de `ing_repasos` empezando por *nueva*. `ing_tarjetas` es solo una **caché** (8.2): si un equipo tiene repasos que la caché no refleja, el dominio la recalcula. Dos equipos que repasan la misma tarjeta el mismo día suben dos filas; el orden fijo los lleva al mismo estado (9.4).

### 3.6 La mini prueba del viernes

**Cambio de función (D-ING-14).** El examen del viernes es **de repaso**: no bloquea nada. Lo que bloquea son las **pruebas por unidad** (3.6.1). La mini prueba sigue igual y alimenta las tarjetas y el descenso por evidencia.

**Qué es.** Cada viernes de las semanas 1 a 7 la mini prueba ocupa el lugar del repaso: **10 preguntas de gramática y vocabulario** del escalón, y se **aprueba con 8** (`data/ingles/formatos/gravity-escalon.yaml:247-252`; la rúbrica solo califica ahí gramática y vocabulario, `docs/contenido/ingles/rubrica-evaluacion.md`, sección 1). En la semana 8 y en la semana de práctica no hay: ocupa su lugar la puerta (3.7).

**Dónde vive en el contenido.** El contrato deja pendiente dónde vive y cuántos minutos cuenta (`gravity-sesion-60.yaml:248-253`). Se pide al formato 0.5 (sección 14): el bloque `mini_prueba` de la sesión del viernes **referencia una forma de uso `mini`** (`mini-<escalon>-s<NN>`, formato 0.4, sección 5). Con la fórmula de V22 (40 segundos por pregunta de opción múltiple), 10 preguntas son 6.7 minutos: el 133 % de los 5 declarados, dentro de lo permitido.

**Cómo se presenta.** Una sola vez por semana, sin retroalimentación hasta terminar y sin cronómetro. Al terminar: *«8 de 10»*, y cuáles quedaron por reforzar, sin color de alarma (3.8).

**Propuesta P5-07 · Qué cuenta una mini prueba que no se aprueba.** La versión 0.3 de `niveles-y-avance.md` decía *«se repite la semana»* y la rúbrica 0.1 (sección 5), *«los errores vuelven como tarjetas»*. Se resuelve así:

| Resultado | Qué pasa |
|---|---|
| **8 a 10** (aprobada) | Cada error (de 0 a 2) vuelve como tarjeta |
| **5 a 7** (no aprobada) | **Cada error vuelve como tarjeta.** No se repite la semana. No gasta faltas (el día cuenta completo, 3.3) ni cambia los minutos. No cuenta para el descenso |
| **0 a 4** (por debajo de 50 %) | Lo anterior, y además **cuenta para el descenso por evidencia** (3.7) |

- **No se repite la semana.** Repetirla movería la puerta y los minutos planeados, y las 80, 200, 360 y 520 horas del dueño suponen aprobar a la primera (plan 4.2). La rúbrica y el descenso por evidencia (D-ING-5) ya cubren el caso.
- **Cada error vuelve como tarjeta** aunque la prueba se apruebe (la rúbrica lo pedía solo al reprobar; es lo mismo, aplicado siempre, porque un error es un dato). La tarjeta de error entra a la **caja 1** y vence el siguiente día de estudio, así que es lo primero del repaso del lunes (3.5). Si esa pregunta ya tiene su tarjeta, esa tarjeta vuelve a la caja 1; no se duplica.
- **Ninguna mini prueba toca la constancia.** Con esta lectura, la decisión del dueño del 14/nov *«la primera evaluación semanal fallida del bloque queda como día de gracia»* (`niveles-y-avance.md`, sección 9) se cumple en el espíritu: ninguna mini prueba fallida gasta una de las tres faltas del escalón (3.4), tampoco la primera. Si el dueño quería otra cosa, es la pregunta 3 del apartado 15.

**Qué se guarda.** Un sub-bloque `mini_prueba` en `ing_bloques` con `aciertos`, `preguntas` y `detalle` (la lista de preguntas con su acierto, para las tarjetas de error y para que calidad retire las preguntas que fallan sin razón: plan 9, riesgos).

### 3.6.1 Las pruebas por unidad (D-ING-14, P5-31)

**Decidido (D-ING-14, 16/nov/2026):** el examen del viernes es de repaso y **el escalón lleva pruebas por unidad que cuentan para subir** (pruebas intermedias que bloquean). **Esto sustituye mi propuesta P5-08 de la versión 0.5** (*«el escalón no lleva pruebas intermedias»*): el requisito 1 de `niveles-y-avance.md` (*«pruebas aprobadas»*) deja de estar cubierto por el 2 y vuelve a ser un requisito propio.

**Propuesta P5-31 · Qué es una unidad, qué contiene y qué pasa.** Lo que sigue lo defino yo; el dueño pidió solo que existan y que cuenten.

| Punto | Propuesta |
|---|---|
| **Unidad** | **Dos semanas.** **Cuatro por escalón**, el **viernes** de las semanas **2, 4, 6 y 7**. La cuarta cubre la semana 7 más un **repaso acumulado** de las tres anteriores, porque la semana 8 es de la puerta (3.7.7) |
| **Lugar en la sesión** | Ocupa el sub-bloque **Lección** (10 minutos declarados) de ese viernes, **en lugar de la conversación guiada**, que ese viernes se omite. La mini prueba del viernes sigue en el Repaso. Los minutos planeados no cambian (60) |
| **Contenido** | **20 preguntas objetivas**, que califica el programa (sin IA): 6 de gramática del tema, 4 de vocabulario, 5 de lectura (un texto) y 5 de escucha (un audio, dos reproducciones). **Sin audio:** 15 preguntas, sin la parte de escucha, con el mismo umbral. No hay escritura ni habla (esas las miden las puertas y no se pueden calificar sin la IA o la pareja). Con la fórmula de V22 (40 segundos por pregunta), 20 preguntas son 13.3 minutos, el 133 % de los 10 declarados; 15 son 10 |
| **Umbral** | **80 %**: `aciertos × 100 ≥ 80 × preguntas` (16 de 20; 12 de 15). Es el mismo umbral de la mini prueba y de la puerta (3.7.1) |
| **Cómo se presenta** | Como la mini prueba: una sola toma, sin retroalimentación hasta terminar, sin cronómetro, sin color de alarma. Al terminar: *«17 de 20»* y qué ideas quedaron por reforzar |
| **Si no se aprueba** | **Cada error vuelve como tarjeta** (caja 1, igual que P5-07). La prueba se **repite una vez**, el **lunes de la semana siguiente** (semanas 3, 5, 7 y 8), con la **forma de reserva** `b`, en el lugar de la Lección de ese lunes. No gasta faltas ni cambia los minutos. Si la repetición tampoco se aprueba, la unidad queda **no aprobada** |
| **Qué consecuencia tiene** | El curso **sigue** hasta la puerta (no se corta el estudio). Pero con **una unidad no aprobada el requisito 1 no se cumple**: aunque se apruebe la puerta, **no se sube y el escalón se repite** (T15 con motivo `pruebas`; la etiqueta de la etapa queda ganada, P5-13). La app lo dice desde el día de la repetición fallida, sin reproche (3.8) |
| **Cómo entra en los cuatro requisitos** | Es el **requisito 1**: *las cuatro unidades aprobadas, en el primer intento o en la repetición*. En la puerta anticipada y en la puerta inmediata de B2 se exigen solo las unidades **ya presentadas** antes del primer turno (en la semana 2, a lo más la primera); las no presentadas no se piden |
| **Segunda vuelta** | En un escalón que se repite, las formas se **intercambian**: la `b` es la principal y la `a` la repetición, para no repetir las mismas preguntas en el mismo orden |
| **Descenso por evidencia** | Una prueba por unidad **no** cuenta para él (T06 sigue siendo de las mini pruebas): evita bajar a alguien por una sola prueba más larga |

**Qué se guarda.** No hay tabla nueva: un tramo de `ing_bloques` con `bloque = 'prueba_unidad'` (un solo tramo, no se reanuda), con `unidad` (1 a 4), `intento` (1 o 2), `forma_id`, `aciertos`, `preguntas` y `detalle` (8.2). Una unidad está aprobada si **algún** tramo de esa unidad dentro del ciclo cumple el umbral; se calcula, no se guarda (convención 6). Viaja por el tipo de cola que ya existe para los bloques (`habitos.ingles_bloque`, nivel 2: 9.2).

**Costo de contenido (aviso).** Son **8 formas por escalón** (4 unidades × `a` y `b`), 160 preguntas por escalón y unas **2 080** en los 13 escalones, además de las de la sesión y las puertas. Se pide al formato 0.5 el bloque `prueba_unidad` y a la habilidad `simulacro-examen-idioma` que las produzca (14); es una carga que el plan no tenía contada. *Si el dueño la considera excesiva:* **dos** pruebas por escalón (semanas 4 y 7, de cuatro semanas cada una; 80 preguntas y 1 040 en total) o **una sola forma por unidad** con la repetición el mismo viernes de la semana siguiente con las preguntas reordenadas (peor medida, la mitad del contenido). Es la pregunta 3.

### 3.7 Las puertas: máquina de estados

**3.7.1 Qué es una puerta y cómo se aprueba** (decidido: D-ING-1 y D-ING-6; `data/ingles/formatos/gravity-escalon.yaml:140-158`)

- Toda puerta mide las **cuatro habilidades**: lectura, escucha, escritura y habla. Se aprueba con **80 % o más en cada una, sin compensar** una con otra. La parte *Use of English* de B2 cuenta dentro de lectura (`gravity-escalon.yaml:131-139`).
- **Lectura y escucha** (objetivas): 10 preguntas o más por habilidad. Se aprueba con `aciertos × 100 ≥ 80 × preguntas` (con 10, 8).
- **Escritura y habla** (rúbrica de 0 a 4): se aprueba si la **suma ponderada es de 320 o más sobre 400 y** «gramática del tema» tiene **3 o más**. Sacar 3 en todo da 300 y **no** aprueba (`gravity-escalon.yaml:151-158`).
- **Propuesta P5-16 · Sin crédito parcial en lo objetivo.** Cada pregunta objetiva vale 1 o 0 y cada una pesa lo mismo, sin importar los puntos que le dé el examen oficial. Se deja el 0.5 de la rúbrica 0.1 (sección 3.1): lo calificaba una persona que decidía qué es «casi correcto», y aquí califica el programa con `aceptadas`; el formato 0.4 (sección 13) ya lo excluía en las transformaciones. La gradación sí existe en escritura y habla: la escala de 0 a 4 por criterio. `rubrica-evaluacion.md` debe ajustarse (14).
- **Aviso en todo resultado:** *«Aprobar la puerta no equivale a aprobar el examen oficial: el 80 % por habilidad es un margen de seguridad propio de GRAVITY»* (`gravity-escalon.yaml:123-125`).

**3.7.2 Los estados**

| Estado | Significa |
|---|---|
| `sinUbicar` | Nunca se ha ubicado |
| `ubicando` | Respondió algo de la ubicación y no la cerró |
| `ubicado` | La ubicación está guardada; el primer escalón empieza el lunes siguiente |
| `cursando(N, s)` | En el escalón N, semana s de 1 a 8 |
| `puerta(N, k)` | Presentando la oportunidad k (1 o 2) de la puerta de N: del primer al último turno |
| `enCorreccion(N, k)` | Presentó todos los turnos y falta la corrección de escritura o habla |
| `practica(N)` | Una o más semanas de práctica tras no aprobar la oportunidad 1 |
| `revisionPendiente` | Dos caídas seguidas: espera a que la persona confirme que revisó su plan |
| `cursoCompleto` | Aprobó la puerta de B2.4 (o la puerta inmediata de B2) |

**3.7.3 Tabla de transiciones.** *Fila nueva* es lo único que se escribe (8.2); el estado siguiente se calcula. «Lunes siguiente» es P5-03. Una **caída** es no aprobar la oportunidad 2; las *caídas seguidas* son las que hay desde la última puerta aprobada.

| # | Desde | Evento o condición | Hacia | Fila nueva |
|---|---|---|---|---|
| T01 | `sinUbicar` | Abre la ubicación y confirma | `ubicando` | — |
| T02 | `ubicando` | Responde una pregunta | `ubicando` | `ing_ubicacion_respuestas` |
| T03 | `ubicando` | Termina (primera etapa no alcanzada, o terminó B2) | `ubicado` | `ing_ubicaciones` y `ing_escalones` (entrada `ubicacion`) |
| T04 | `ubicado` | Llega el lunes de inicio | `cursando(N₀, 1)` | — |
| T05 | `cursando(N, s)`, s < 8 | Termina la semana | `cursando(N, s+1)` | — |
| T06 | `cursando(N, s)`, N ≠ A1.1 | La mini prueba del viernes queda por debajo de 50 % y la anterior del ciclo también | `cursando(N−1, 1)` el lunes siguiente | `ing_escalones` (`baja_por_evidencia`) |
| T07 | `cursando(A1.1, s)` | Lo mismo que T06 | `cursando(A1.1, s)` | — (no hay escalón abajo; se muestra el mensaje) |
| T08 | `cursando(N, 2)` | Presenta la puerta anticipada y aprueba con el 90 %, con asistencia y unidades de lo cursado | `cursando(N+1, 1)` el lunes siguiente; si N es B2.4, `cursoCompleto` | `ing_intentos` (`anticipada`) y `ing_escalones` (`sube_anticipada`) |
| T09 | `cursando(N, 2)` | Presenta la anticipada y no aprueba, o no cumple asistencia o unidades | `cursando(N, 2)` | `ing_intentos` (sin efecto, no gasta oportunidades) |
| T10 | `cursando(B2.1, 1 o 2)` | Entró por ubicación B2 y presenta la puerta inmediata de la etapa B2 con el 90 % y los requisitos | `cursoCompleto` (si no aprueba, sigue igual) | `ing_intentos` (`anticipada_b2`) |
| T11 | `cursando(N, 8)` | Empieza el primer turno de la puerta | `puerta(N, 1)` | `ing_intentos` (`oportunidad_1`) |
| T12 | `puerta(N, k)` | Presentó todos los turnos y falta alguna corrección | `enCorreccion(N, k)` | `ing_entregas` |
| T13 | `puerta(N, k)` o `enCorreccion(N, k)` | Están calificadas las cuatro habilidades | Se evalúa (T14 a T18) | `ing_puntajes` |
| T14 | Evaluación de k = 1 o 2 | **Aprobada** y cumple unidades, constancia y minutos | `cursando(N+1, 1)` el lunes siguiente; si N es B2.4, `cursoCompleto` | `ing_escalones` (`sube`). Caídas seguidas = 0 |
| T15 | Evaluación de k = 1 o 2 | **Aprobada**, pero falta alguno de los otros tres requisitos (unidades, constancia o minutos) | `cursando(N, 1)` (segunda vuelta) el lunes siguiente | `ing_escalones` (`repite_por_requisitos`; el motivo, `pruebas` o `asistencia`, se **calcula** y se muestra, no se guarda). Caídas seguidas = 0. Si es puerta de etapa, la etiqueta queda ganada |
| T16 | Evaluación de k = 1 | No aprobada | `practica(N)` | — |
| T17 | Evaluación de k = 2 | No aprobada, N ≠ A1.1 | `cursando(N−1, 1)` el lunes siguiente (o `revisionPendiente`) | `ing_escalones` (`baja_por_puerta`). Caídas seguidas + 1 |
| T18 | Evaluación de k = 2 | No aprobada, N = A1.1 | `cursando(A1.1, 1)` el lunes siguiente (o `revisionPendiente`) | `ing_escalones` (`repite_tras_caida`). Caídas seguidas + 1 |
| T19 | `practica(N)` | Pasó al menos una semana de práctica y llega su último día | `puerta(N, 2)` | `ing_intentos` (`oportunidad_2`) |
| T20 | `revisionPendiente` | La persona confirma que revisó su plan | `cursando(destino, 1)` | La fila de T17 o T18 se escribe ahora, con `tras_revision` verdadero. Caídas seguidas = 0 |

Si T17 o T18 dejan **dos caídas seguidas**, el destino no se escribe hasta T20. Cualquier puerta aprobada (T08, T10, T14 y T15) pone en cero las caídas seguidas; el descenso por evidencia (T06) **no las toca** (P5-09).

**3.7.4 El veredicto de una oportunidad (P5-13).** Se **sube** solo si se cumplen los cuatro requisitos del dueño (`niveles-y-avance.md`, sección 4): (1) *pruebas aprobadas*: las **cuatro pruebas por unidad** (3.6.1, P5-31, D-ING-14); (2) la **puerta aprobada** (3.7.1); (3) la **constancia**: a lo más tres días faltados (3.4, D-ING-12); y (4) los **minutos**: ningún día con más de 10 minutos de faltante fuera de esos tres (3.4). El 90 % de los minutos de la versión 0.5 se retiró. La pantalla de resultado dice **cuál faltó** (el registro de `niveles-y-avance.md`, sección 7: *«subió o no subió, con el requisito que faltó»*).

**Propuesta P5-13 · Puerta aprobada sin unidades, sin constancia o sin minutos: el escalón se repite.** El dueño dijo *«si no cumples uno, no subes, aunque cumplas los otros tres»*; no dijo qué pasa después. Se propone **T15**: no se baja ni se gasta una oportunidad: se vuelve a cursar el escalón (segunda vuelta) con unidades y faltas en cero, y en su semana 2 queda la **puerta anticipada** como atajo para quien ya lo domina. **La etiqueta de la etapa se gana al aprobar la puerta**, aunque el escalón se repita: la etiqueta mide el nivel y el escalón mide la asistencia y las unidades. D-ING-12 dice lo mismo para las faltas: *«se repite»* (la lectura «el escalón» está a confirmar, pregunta 9). *Si se veta:* extender el escalón con semanas completas hasta cubrir lo que falta (las faltas no se pueden recuperar). Es la pregunta 2.

**3.7.5 La ventana de asistencia y de unidades.** Se miden sobre los **días de estudio del ciclo**:

| Presentación | Va desde… | …hasta |
|---|---|---|
| Oportunidad 1 | El lunes de la semana 1 | El día del último turno de la puerta |
| Oportunidad 2 | Igual | El día del último turno, con las semanas de práctica incluidas |
| Anticipada y puerta inmediata de B2 | El lunes de la semana 1 | El día **anterior** al primer turno |

Un día de la ventana que es hoy y no termina no se juzga. Si los minutos planeados de la ventana son cero (por ejemplo, la puerta inmediata de B2 el primer día), el requisito se da por cumplido.

**3.7.6 La semana de práctica (P5-14).** Decidido: entre las dos oportunidades pasa **al menos una semana de práctica** (plan 3.1) y, tras una caída, se repite *«desde las habilidades no alcanzadas»*. Propuesta de cómo se arma, sin pedir contenido nuevo:

- **Empieza el lunes siguiente** al veredicto de la oportunidad 1 y dura **una semana** (la persona puede añadir más semanas, de una en una, antes de presentar la oportunidad 2; no hay tope). **No es la semana 9**: se rotula «Práctica».
- Cada día se arma con **sesiones ya estudiadas** de las semanas 1 a 7 del escalón. Las habilidades no alcanzadas se ordenan de menor a mayor porcentaje (empate: lectura, escucha, escritura, habla) y cada una elige el día de enfoque que la entrena: **escucha → martes** (`escucha`), **lectura y escritura → jueves** (`lectura_escritura`), **habla → viernes** (`conversacion`) y miércoles (`pronunciacion`) (los identificadores de `data/ingles/niveles.yaml:725-730`; el contrato los deja pendientes, `gravity-sesion-60.yaml:175-176`). Los días se reparten por turnos entre esas habilidades y, dentro de cada una, se elige la sesión más antigua que todavía no se repitió en esta práctica.
- Los **últimos días** de la semana son los turnos de la oportunidad 2 (3.7.7). No hay mini prueba.
- Cuentan para la asistencia como cualquier día (`origen = 'practica'` en `ing_sesiones`): **no traen faltas nuevas**, se suman a las del ciclo (el tope sigue siendo tres). El **repaso del escalón de abajo** tras una baja se cumple de dos maneras: el escalón se cursa completo, con la anticipada de la semana 2 como atajo, y Progreso marca las habilidades que quedaron sin alcanzar para que la persona las priorice en su producción diaria.

**3.7.7 Turnos y calendario de la semana 8 (P5-15).** La puerta **cuenta dentro de las 40 horas** y, si es de etapa, **se reparte en varias sesiones de la semana 8** (plan 4.2). Se presenta en **turnos**: cada uno junta secciones consecutivas del contrato **sin partir una sección ni un papel**, hasta **90 minutos**; los turnos ocupan los **últimos días** de la semana, uno por día, hasta el viernes.

| Puerta | Secciones y minutos del contrato | Turnos |
|---|---|---|
| **De escalón** (A1.1, A1.2, A2.1, A2.2, B1.1 a B1.3, B2.1 a B2.3) | Sin minutos declarados todavía (`gravity-escalon.yaml:42-76`) | **1** turno, el viernes. Se pide a la herramienta que la forma estime 60 minutos o menos (14) |
| **A2.3 · A2 Key** | Lectura 40 y escritura 20 (un solo papel de 60), escucha 30, habla 10 como máximo (`data/ingles/formatos/cambridge-a2-key.yaml`, secciones `reading`, `writing`, `listening` y `speaking`) | **2:** jueves (90), viernes (10) |
| **B1.4 · B1 Preliminary** | Lectura 45, escritura 45, escucha 30, habla 12 como máximo (`cambridge-b1-preliminary.yaml`) | **2:** jueves (90), viernes (42) |
| **B2.4 · B2 First** | Lectura y *Use of English* 75, escritura 80, escucha 40, habla 14 (`cambridge-b2-first.yaml`) | **3:** miércoles (75), jueves (80), viernes (54) |

Los minutos salen del **contrato compilado**, no del código. **El día de un turno acredita 60 minutos** al terminarlo y queda completo (3.3), aunque el turno dure 10 o 80: así las cinco sesiones de la semana siguen sumando los 300 minutos planeados. El primer turno **empieza la oportunidad**; desde ahí el estado es `puerta(N, k)`. Un turno corre en **modo examen** (6.3): al salir de la app no se detiene el reloj, y al volver se continúa con el tiempo que quede o se cierra con lo contestado; **no hay reinicio**. Un turno que no se presenta en su día **no caduca**: se ofrece el siguiente día de estudio, y el día en que faltó queda sin completar (3.4). Las partes de habla en pareja de los exámenes (A2 Key parte 2, B1 partes 3 y 4, B2 parte 3) las resuelve P6.0 (7).

**3.7.8 La puerta anticipada (P5-11).** Decidido (D-ING-5, plan 3.3): en la **semana 2** del escalón que se cursa se puede presentar su puerta; con **90 % o más en cada habilidad** se pasa al siguiente escalón y **no se gasta ninguna de las dos oportunidades**. El contrato deja pendientes cómo se aplica a escritura y habla, y las veces y la forma (`gravity-escalon.yaml:229-241`). Se propone:

| Punto | Propuesta |
|---|---|
| **Cuándo y cuántas veces** | De lunes a viernes de la semana 2 del ciclo, **una sola vez por ciclo**. En la segunda vuelta de un escalón vuelve a estar disponible |
| **Forma** | La de **reserva** (C) de esa puerta (3.7.11) |
| **90 % en lectura y escucha** | `aciertos × 10 ≥ preguntas × 9`: con 10 preguntas, 9; con 12, 11; con 15, 14 |
| **90 % en escritura y habla** | Suma ponderada **de 360 o más sobre 400**. La condición de *gramática del tema ≥ 3* queda **cubierta por los pesos de la rúbrica**: con 2 en gramática, el máximo posible es 320 en escritura (2×40 + 4×60) y 330 en habla (2×35 + 4×65), por debajo de 360. La app la comprueba de todos modos |
| **Asistencia y unidades** | **Los mismos umbrales, sobre lo cursado** (ventana de 3.7.5): a lo más tres días faltados, los demás con 10 minutos o menos de faltante, y las unidades ya presentadas aprobadas (por ejemplo, con 10 días de estudio, a lo más 3 faltados y 7 con 50 minutos o más). Quien no estudia no demuestra nada, aunque acierte. *Si se veta:* basta el 90 % por habilidad. Es la pregunta 6 |
| **Efecto** | Aprobada con requisitos: sube (T08). En cualquier otro caso no pasa nada (T09) y la persona ve su resultado por habilidad como información |
| **Calendario** | Sus turnos (3.7.7) ocupan días de la semana 2, uno por día, terminando a más tardar el viernes, y cuentan 60 minutos cada uno |
| **Etiqueta** | Si el escalón cierra una etapa (A2.3, B1.4, B2.4), aprobar la anticipada **gana la etiqueta** |

**La puerta inmediata de B2.** La ubicación de quien alcanza B2 lo deja en B2.1 *«con derecho a presentar de inmediato la puerta de la etapa B2»* (plan 3.3, `gravity-ubicacion.yaml:258-261`). Se trata como una anticipada de la puerta de **B2.4** (forma completa tipo B2 First): disponible **desde el primer día hasta el fin de la semana 2** de B2.1, una vez, con el **90 %** por habilidad (D29: *quien demuestre el nivel antes avanza con 90 %*; saltar cuatro escalones no puede pedir menos que saltar uno), sin gastar oportunidades. Aprobada, gana la etiqueta B2 y el curso termina (T10); no aprobada, la persona sigue en B2.1, donde también tiene su anticipada normal en la semana 2.

**3.7.9 El descenso por evidencia (P5-09).** Decidido (D-ING-5): **dos mini pruebas seguidas por debajo de 50 % bajan un escalón, sin penalización**. «Por debajo de 50 %» es `aciertos × 2 < preguntas`: con 10 preguntas, de 0 a 4 aciertos (5 de 10 **no** está por debajo). Se aclara:

- **«Seguidas»** son las **dos últimas mini pruebas presentadas del ciclo**; una aprobada o de 5 a 7 entre medias las separa. La cuenta **empieza en cero** en cada ciclo, suba o baje la persona.
- Entra en vigor **el lunes siguiente** (P5-03): la persona termina esa semana donde está.
- **No cuenta como una de las «dos bajas seguidas»** (3.7.10): es una corrección de la ubicación *sin penalización*, y contarla sería penalizarla. La puerta aprobada tampoco se ve afectada.
- **En A1.1 no hay escalón abajo** (T07): nada cambia y se muestra el mensaje de apoyo.
- Puede bajar a un escalón por debajo del de la ubicación (la persona que entró en B1.1 puede acabar en A2.3). Para volver a subir debe aprobar su puerta, que no había presentado.
- Progreso muestra *«Mini pruebas por debajo de 50 %: 1 de 2»*, sin alarma, para que la regla sea transparente.

**3.7.10 Dos caídas seguidas (P5-10).** Decidido: *«dos bajas seguidas: el dueño revisa el plan con la persona (horario, carga, método); la exigencia no baja»* (`niveles-y-avance.md`, sección 3.3) y, en A1.1, *«a la segunda caída seguida»* (plan 4.2). Aquí una baja seguida es una **caída** (no aprobar la oportunidad 2) y el descenso por evidencia no cuenta (P5-09). Al llegar a dos caídas seguidas, el destino del escalón no se abre (T20): la pantalla muestra una tarjeta *«Toca revisar el plan: horario, carga y método. La meta es la misma; cambiamos el camino»* con las tres preguntas y el botón *«Ya lo revisé»*. **La app no avisa a nadie:** Hábitos es personal y el dueño no lee lo de otras personas (D21, `docs/DECISIONES.md:478`); lo que la persona decida compartir es de P6.0. Qué hacer para que el dueño se entere sin romper D21 es la pregunta 4.

**3.7.11 La forma que toca y la forma de reserva (P5-12).** Cada puerta tiene **tres formas** (plan 4.2: dos oportunidades y una de reserva), sin unidades en común (V20). El contrato deja pendiente cuándo se usa la de reserva (`gravity-escalon.yaml:226-228`). Con las formas A, B y C del contenido:

1. **Puerta anticipada y puerta inmediata de B2:** la de reserva (**C**).
2. **Oportunidades 1 y 2:** la **primera forma que esta persona no haya presentado en esa puerta**, en el orden A, B, C. Normalmente, A y B.
3. **Si ya presentó las tres** (segunda vuelta, baja y regreso): la que presentó **hace más tiempo** (empate: A, B, C). La pantalla avisa *«Esta forma ya la presentaste»* y el intento lo registra.
4. **Una forma ausente del contenido instalado** (retirada, V25) se **salta**; si no queda ninguna, la puerta no se ofrece y la pantalla dice que el contenido se está actualizando.

La reserva, entonces, **se usa en tres casos**: la anticipada, el reemplazo de una forma retirada y la repetición de un escalón. Que la persona vea de nuevo una forma tras tres presentaciones es un **límite conocido** de 3 formas por puerta (plan 4.2); un cuarto juego de formas costaría 13 formas más y es del dueño.

**3.7.12 Los casos de borde del plan (sección 4.2) y cómo los cumple la máquina**

| Caso del plan | Cómo queda |
|---|---|
| El último escalón de cada etapa **no** tiene además otra puerta | La puerta de etapa **es** la de A2.3, B1.4 y B2.4; la de A1.2 es la prueba interna. Una sola función `puertaDe(escalon)` devuelve el tipo y el contrato: 13 puertas, 39 formas |
| Primera oportunidad al final de la semana 8 | T11 y 3.7.7 |
| Fallar las dos oportunidades en A1.1 | T18: se repite A1.1 y, a la segunda caída seguida, `revisionPendiente` |
| Bajar a un escalón que cierra una etapa | T17: la etiqueta **ya ganada se conserva** (se deriva de los intentos, 3.1), se repite ese escalón y se vuelve a presentar su puerta |
| La puerta cuenta dentro de las 40 horas | 3.7.7: el día de un turno acredita 60 minutos |
| B1+ no se otorga | 3.1: se muestra «B1 · escalón 2 de 4» |
| Etiquetas «sin audio» y 35 minutos | 3.3: solo respaldo si el audio falla; sin audio las puertas, la ubicación y la escucha no se ofrecen (4) |
| Inglés americano en el curso y británico en Cambridge; los cuatro temas movidos; `needn't`; los mínimos recalibrados | Son de contenido: la app lee la `variante` del contenido compilado y no decide nada de esto |

**3.7.13 Sin la IA activada: pareja, o espera (D-ING-11, P5-24).** La escritura y el habla de las puertas las corrige una IA, opcional por función (D-ING-9). **Decidido por el dueño (D-ING-11): si la persona no activa la IA, la escritura y el habla de la puerta van a la pareja y a la IA, o esperan a que la IA se active. Lectura y escucha siguen (se califican en el dispositivo). No hay autocalificación:** la lista de cotejo de la persona nunca decide un puntaje de puerta.

- **Lectura y escucha** se presentan y califican siempre, con o sin IA.
- **Escritura y habla** se entregan igual. Con la IA activada, se corrigen con ella (7.1). Sin ella, la entrega queda en `enCorreccion` hasta que **(a)** la persona active la IA, o **(b)** llegue la corrección de la pareja y de la IA que define P6.0 (con consentimiento, 7.2). Una puerta no tiene veredicto hasta tener las cuatro habilidades calificadas por alguien distinto de quien la presenta.
- Un equipo que no pueda grabar y transcribir (4.4) puede presentar lectura y escucha; el habla espera a otro equipo (el teléfono).
- Mientras falte una corrección **no se muestra veredicto ni etiqueta** (D-ING-10); se ven los resultados objetivos como resultados, no como veredicto. Los días de espera se cubren con sesiones de repaso del escalón (armadas como las de la práctica, sin elegir habilidad) que cuentan para la constancia y los minutos del ciclo; el veredicto mueve a la persona el lunes siguiente (T13 a T18).
- La pantalla lo explica sin reproche: *«Tu lectura y tu escucha ya están. Falta la corrección de tu escritura y tu habla: activa la corrección o espera a la de tu pareja.»* Cómo se reparten las entregas entre pareja e IA y qué ve cada quien es de P6.0.

### 3.8 Pantallas, flujos y tono

**Pantallas.** Rutas nuevas **relativas a `/habitos`**, que se suman a `rutasHabitos()` (`app/lib/modulos/habitos/habitos.dart:47-117`). Personalidad *lúdica*, acento naranja y progreso por niveles (`docs/DISENO_UX_UI.md`, sección 5, línea 110).

| Pantalla | Ruta | Qué muestra |
|---|---|---|
| **Fila de Inglés en Hoy** | (dentro de Hoy) | *«Inglés · tu sesión de hoy»*, partes hechas (*3 de 7*) y la racha. Sin curso empezado, la tarjeta *Tu punto de partida* (solo con `INGLES_ARRANQUE`, 7) |
| **Inicio de inglés** | `ingles` | Nivel (3.1), la sesión de hoy con sus sub-bloques y un solo botón *Continuar*, tarjetas esperando, racha y faltas que quedan, aviso de requisito en riesgo |
| **Sesión del día** | `ingles/sesion` | Los sub-bloques (3.2) con su estado; cada uno abre su pantalla: repaso, mini prueba, lección, conversación, pronunciación, producción y las tres del traslado (modo de audio y manos libres) |
| **Tarjetas** | `ingles/tarjetas` | Repasar (la cola de 3.5), *Mis tarjetas* por caja y dominadas, reactivar |
| **Progreso y puertas** | `ingles/progreso` | Requisitos del escalón (unidades, puerta, faltas usadas, minutos), calendario de asistencia, metas semanales, mini pruebas (*1 de 2 por debajo de 50 %*), pruebas por unidad (*2 de 4 aprobadas*), puertas (oportunidad, anticipada disponible), historial, etiquetas, sesiones pasadas (práctica libre) |
| **Ubicación** | `ingles/ubicacion` | 5 |
| **Puerta** | `ingles/puerta` | Turnos en modo examen y resultado con el requisito que faltó (3.7, 6) |
| **Exámenes** | `ingles/examenes` | Práctica por partes, simulacros y semáforo (6) |
| **Entregas** | `ingles/entregas` | Entregar una tarea y ver su corrección (7) |
| **Ajustes › Inglés** | `ajustes/ingles` (de plataforma) | Hora del recordatorio, corrección con IA, conservar grabaciones, borrar mis datos de inglés |

**Dispositivos.** Teléfono y **tablet personal** (como el teléfono, D21): todo. **Laptop:** todo lo que no pida micrófono; sin micrófono ni transcripción local utilizable, las tareas de habla y las puertas no se ofrecen y se pide pasar al teléfono (`app/lib/modulos/gravity/conversacion/voz.dart:152-156` solo ofrece el micrófono en Android). **Tablet pública de la casa: no** (D21, `docs/DECISIONES.md:477`).

**Propuesta P5-26 · El inglés no se ofrece en la tablet pública.** D21 permite ahí solo *Hoy* sin lo sensible y el lector, con nombre y PIN; una sesión de una hora con grabación de voz en un equipo de todos no entra en eso.

**Flujos** (la regla es *3 toques o menos* para la acción diaria; `docs/DISENO_UX_UI.md`, flujo F2):

| # | Flujo | Pasos | Toques |
|---|---|---|---|
| F-I1 | Empezar la sesión de hoy | Hoy › fila de Inglés › *Continuar* (abre el primer sub-bloque pendiente) | 2 |
| F-I2 | Repasar tarjetas | Sesión › Repaso › *Otra vez / Bien / Fácil* en cada tarjeta | 1 por tarjeta |
| F-I3 | Hacer el traslado | Inglés › Traslado › ▶ (sigue solo de un audio al siguiente) | 2 |
| F-I4 | Entregar la tarea de producción | Producción › escribir o grabar › *Entregar* | 1 tras escribir |
| F-I5 | Presentar un turno de puerta | Progreso › Puerta › *Empezar turno* (con la advertencia del modo examen) | 3 |

**Estados** (principio 8 de `docs/DISENO_UX_UI.md`):

| Estado | Mensaje y acción |
|---|---|
| Vacío (sin curso) | *«Empecemos por saber dónde estás»* · *Tu punto de partida* |
| Cargando contenido | El contenido está dentro de la app: no hay espera de red; solo la lectura del recurso |
| Sin conexión | *«Sin conexión: tu avance se guarda y se sincroniza después»* (`diseno-app-habitos.md`, G.7). Todo el curso sigue |
| Error al guardar | Se conserva en la cola (9.2); *«No pudimos subirlo todavía; sigue guardado»* |
| Sin audio | *«Falta una voz en inglés»* con los pasos del motor de voz (su sección 5.5) y *Reintentar* |

**Tono sin culpa.** Todo texto sobre un día perdido, una mini prueba, una puerta o una baja sale de un **catálogo cerrado** (`MensajesIngles`, en el dominio, junto a `MensajesHabitos`) con la misma revisión automática: ninguna de las palabras de `MensajesHabitos.prohibidas` (*fallaste, fracaso, perdiste, culpa, castigo, vergüenza* y `!`; `mensajes.dart:25-27`), sin rojo y sin alarma. Se reutilizan `rachaRota` y `graciaUsada`.

| Situación | Texto |
|---|---|
| Se usó la tercera falta | *«Hoy cuenta como tu falta número 3 de este escalón. Mañana seguimos.»* |
| Falta cuarta (el escalón se repetirá) | *«Este escalón se va a repetir; la puerta te dice cuánto ya sabes. Hoy puedes seguir.»* |
| Unidad no aprobada tras la repetición | *«Esta unidad quedó pendiente. Vuelve como tarjetas y seguimos con el escalón.»* |
| Mini prueba no aprobada | *«Quedaron algunas ideas por reforzar. Vuelven mañana como tarjetas.»* |
| Descenso por evidencia | *«Vamos a afianzar el escalón anterior. Lo que ya sabes se queda contigo.»* |
| Puerta no aprobada (oportunidad 1) | *«Todavía no. Practicamos lo que falta y la presentas otra vez.»* |
| Baja por puerta | *«Volvemos un escalón para afianzar la base.»* |
| Dos caídas seguidas | *«Toca revisar el plan: horario, carga y método. La meta es la misma; cambiamos el camino.»* |
| Puerta aprobada y sube | *«Pasaste la puerta. Empiezas el siguiente escalón el lunes.»* |
| Aprobada, pero el escalón se repite | *«Aprobaste la puerta. Para subir también hacían falta la asistencia y las pruebas por unidad; repetimos el escalón y en la semana 2 puedes presentar la puerta anticipada.»* |
| Esperando corrección | *«Tu puerta está en corrección. En cuanto llegue, te decimos cómo te fue.»* |

**Propuesta P5-18 · Recordatorio local discreto.** Un solo tipo local `hab_ingles` con el título *«Es hora de tu práctica de inglés»* (32 caracteres, sin dígitos ni «$», como exige la regla 114 de `docs/specs/fase-3-habitos.md`). **Apagado por omisión:** se activa al elegir una hora en `ing_perfil`. Acciones *Empezar* (abre la app) y *Posponer 10 min*; **no hay *Hecho***, porque una sesión pide la app. Respeta las horas silenciosas, se programa en el teléfono como el resto de los recordatorios de Hábitos (regla 113) y se puede silenciar (pedido a `backend` y `plataforma`, 14).

**Inglés no es un dato sensible en el sentido de D13**: no usa la sección reservada, el PIN adicional ni `FLAG_SECURE`. Lo que sí es personal (R2) y lo que no sale del dispositivo (R4) está en 8 y 9.

## 4. Sub-bloque 5b · Audio y habla

El motor de voz de GRAVITY, sus tres fuentes (voz del dispositivo, modelo descargable y audio pregrabado) y su interfaz están en `docs/specs/fase-8-motor-de-voz.md` (sección 3.2 para las firmas y 6.1 para lo que el curso le pide). **No se repiten aquí.** Esta sección dice qué pide el curso, cómo se graba la voz y cómo se transcribe.

**4.1 Quién usa el audio en el curso**

| Sub-bloque o pantalla | Llama al motor | Reproducciones y velocidad |
|---|---|---|
| Traslado · escucha | `reproducir` de cada audio de la semana | 2 por audio (`gravity-sesion-60.yaml`, `traslado-audio`); 1.0 o 0.8 a elección (la política es de P3.1) |
| Traslado · repetición | `decir` de cada frase; espera `terminada` y entonces da el tiempo de repetirla | Una por frase |
| Traslado · tarjetas | `decir` de la palabra y su ejemplo; la traducción en español solo si hay voz en español (propuesta de P3.1; sin ella, la tarjeta dice solo lo que está en inglés) | Una |
| Lección del martes | `reproducir` del audio propio, con el guion **oculto hasta contestar** | Las que declare la unidad; si no declara, 2 (el contrato deja el punto pendiente: `gravity-sesion-60.yaml:63-67`) |
| Pronunciación y conversación guiada | `decir` de cada elemento o turno de la app, con la voz que corresponda | Una por elemento |
| **Ubicación y escucha de las puertas** | `reproducir` en **modo examen** con `soloFuente` congelada (4.2) | Las del contrato de la puerta (Cambridge 2, TOEIC 1); ubicación, 2 (5) |

**4.2 Lo que el curso pide al motor** (todo está en el motor; aquí solo se enlaza lo que el curso necesita y qué hace con ello)

1. **Saber si hay audio** con `disponibilidad(UsoVoz.curso, variante, vocesNecesarias)` antes de ofrecer la ubicación, una puerta o el traslado (motor, 6.1, fila *Saber si hay audio*; criterios 33 y 43). Sin audio: 3.3 y 3.7.13.
2. **Fuente congelada y registrada en las pruebas con valor.** Dentro de la ubicación, una puerta o un simulacro, **todas** las reproducciones usan la misma fuente (`soloFuente`), y el intento guarda la fuente y el acento usados (`Reproduccion.fuente`, `Guion.variante`). El motor lo pidió a este bloque (`docs/specs/fase-8-motor-de-voz.md`, 6.2, punto 2): se cumple con `fuente_audio` y `variante_audio` en `ing_ubicaciones` e `ing_intentos` (8.2). Si falta el acento de la prueba (voces británicas en una forma de Cambridge), la pantalla avisa y el intento lo registra.
3. **Reproducciones según el contrato:** el curso llama `reproducir` el número de veces que dice el contenido y no más; el motor no las cuenta (6.1).
4. **Guion oculto hasta contestar:** `Avance` lleva turno y voz, nunca el texto (criterio 5 del motor). En la ubicación no se muestra nunca (5).
5. **Una sola voz a la vez** y el dictado detiene al motor (criterio 38).
6. **Velocidades 0.8 y 1.0:** ningún contrato las declara hoy (motor, 6.1). El curso ofrece las dos fuera del modo examen; si P3.1 las quiere por contrato, se pide el campo al formato (14).
7. **Sin conexión:** la reproducción no usa la red (R8 del motor). El curso no importa nada de red en sus pantallas de audio (CA-5b-08).

**4.3 Grabar la voz: la grabación se queda en el dispositivo**

Se usa en la **producción hablada**, en los **turnos de habla de una puerta**, y de forma opcional en la repetición de frases y en la pronunciación. El motor **no** graba (motor, 6.3); lo hace el reproductor del curso (P3.2b), y **el paquete de grabación lo evalúa P3.2b y lo aprueba el dueño**: esta especificación no lo elige ni agrega ninguno.

1. **Permiso.** `RECORD_AUDIO` ya está declarado para el dictado (`app/android/app/src/main/AndroidManifest.xml:19`). Se pide **solo al tocar *Grabar***, nunca al abrir la pantalla.
2. **Flujo.** Consigna visible › *Grabar* › cuenta atrás de 3 segundos › grabación con indicador, tiempo y *Terminar* › escuchar › *Entregar* o *Grabar otra vez*. El **tope** de una toma es 1.5 veces el máximo de la etapa (A1 68 s, A2 90 s, B1 135 s, B2 180 s; `gravity-sesion-60.yaml:177-182`).
3. **Tomas.** Hasta **3** en una tarea diaria; **1** en un turno de puerta, con una advertencia antes de empezar (la regla de no reiniciar). Si una toma de puerta dura menos de la mitad del mínimo de la etapa (3.3), por un fallo técnico, se permite repetirla **una** vez.
4. **Dónde queda.** En una **carpeta privada** de la app, nunca en el almacenamiento compartido ni en la galería, con un nombre que es un UUID. **No se sube a ningún servidor** (R4) y se pide a plataforma que quede **fuera de la copia de seguridad automática de Android**.
5. **Cuánto dura (Propuesta P5-23).** Las de tareas diarias, **30 días**; las de una puerta, **hasta 30 días después del veredicto**; la persona puede borrar cualquiera antes, y en Ajustes › Inglés puede elegir *borrar al entregar*. Se borran siempre al salir, al detectar una baja o al quitar a la persona de una tablet (gancho de `LimpiezaLocal.registrar`: `app/lib/nucleo/seguridad/limpieza_local.dart:63`) y con *Borrar mis datos* (P5-20).
6. **La voz no identifica ni autoriza** (motor, R2). Ninguna pantalla compara la voz con la de nadie.

**4.4 Transcribir en el dispositivo**

La transcripción sirve para dos cosas: que la persona vea y se autoevalúe sobre **lo que dijo**, y que lo único que sale hacia la corrección con IA, si ella lo decide, sea **ese texto y no el audio** (plan 3.8). Debe ser en **inglés** (`en-US` o `en-GB` según la `variante` del contenido), **sin red** y de **30 a 180 segundos**.

**Lo que se comprobó leyendo el código** (y que obliga a no confiar en una bandera):

| Hallazgo | Dónde |
|---|---|
| El dictado de hoy es `VozEntradaTelefono`: español de México, **30 segundos**, se detiene a los **4 segundos** de silencio y **no pide reconocimiento local** | `app/lib/modulos/gravity/conversacion/voz.dart:67-72` |
| **[consultado]** `speech_to_text` 7.5.0 con `onDevice: true` usa el reconocedor local de Android **solo en Android 12 o posterior y si está disponible**; **si no, usa el reconocedor por omisión del sistema** y solo le pasa una *indicación* de preferir el modo sin conexión (`EXTRA_PREFER_OFFLINE`), que según la documentación de Android puede no tener efecto y, según el teléfono, el audio puede viajar a un servicio en la nube. La documentación de Dart dice que el intento fallaría; el código nativo no lo hace | `speech_to_text-7.5.0/android/src/main/kotlin/com/csdcorp/speech_to_text/SpeechToTextPlugin.kt:622-637` y `:688`; `speech_to_text-7.5.0/lib/speech_to_text.dart:425-428` |
| **[consultado]** El README del paquete dice que sirve para *«comandos y frases cortas, no conversión continua»*: una transcripción de 45 a 180 segundos **no está probada** | `speech_to_text-7.5.0/README.md:8-10` |
| El reconocimiento transcribe **mientras se habla**, no un archivo ya grabado; y grabar un archivo y reconocer a la vez compiten por el micrófono | Diseño del paquete (README) y motor de voz, 6.3; no se sabe si funciona junto en el Galaxy A52 |

**Requisito de 5b (D-ING-13) · El dictado y la transcripción funcionan sin red.** Hay dos usos: **transcribir** lo que la persona dice en una tarea o turno de habla, y **dictar** el texto de una tarea diaria de escritura (en una **puerta** de escritura se teclea: dictar la convertiría en una prueba de habla; así lo propone P6.0, 6.1). **En modo avión los dos tienen que producir texto**, y ninguno puede caer, sin que la persona lo sepa, en un reconocedor que use la red. No se reutiliza `VozEntradaTelefono` (español de México, 30 segundos, sin modo local: `voz.dart:67-72`): el inglés lleva su propia entrada, con `onDevice: true`, `localeId` de la variante (`en-US` o `en-GB`), tope de 180 segundos y reinicio por tramos si el reconocedor corta antes (V-b2).

**Propuesta P5-22 · La transcripción es solo en el dispositivo, o no es.** Se mantiene y ahora es requisito:

- **Antes de ofrecerla** (y antes de cada turno de puerta de habla) la app **comprueba** que el equipo puede reconocer inglés **en el dispositivo**: Android 12 o posterior, reconocimiento local disponible y paquete de inglés sin conexión instalado. **Si no puede garantizarlo, no ofrece transcribir ni dictar:** el habla pasa a **autoevaluación con la lista de cotejo**, no se manda habla a la IA y la puerta de habla no se presenta en ese equipo (3.7.13).
- **El paquete no lo puede garantizar por sí solo** [consultado, `speech_to_text` 7.5.0]: su API en Dart **no devuelve** si el reconocimiento fue local; `locales()` lista idiomas que el equipo «puede reconocer», sin decir que sea sin red (`speech_to_text-7.5.0/lib/speech_to_text.dart:590-607`); y con `onDevice: true` el código nativo solo crea el reconocedor local si es Android 12 o posterior y existe (`speech_to_text-7.5.0/android/src/main/kotlin/com/csdcorp/speech_to_text/SpeechToTextPlugin.kt:623-625`), y si no, usa el del sistema con la indicación `EXTRA_PREFER_OFFLINE` (`:688`). Por eso **la garantía se pide a `plataforma` como una comprobación nativa mínima** (`SpeechRecognizer.isOnDeviceRecognitionAvailable`, la misma que el paquete usa por dentro, más la comprobación del paquete de inglés) **y se confirma en el equipo con una prueba de modo avión** (V-b1, V-b5). El resultado de esa prueba se guarda **en el dispositivo** (`verificado`, `no_verificado`, `sin_probar`), no en la nube, porque es una propiedad del teléfono.
- **Qué ve la persona** si el equipo no lo garantiza (nunca un error técnico, y sin que parezca culpa suya):

| Situación | Qué ve | Qué puede hacer |
|---|---|---|
| Local garantizado y verificado | El botón *Dictar* con una marca *Sin conexión* | Dictar o grabar |
| Android anterior a la 12, o reconocimiento local no disponible | *«Este teléfono no puede dictar en inglés sin conexión. Puedes escribir.»* y **no hay botón de micrófono** | Escribir; en una tarea de habla, hablar y autoevaluarse con la lista de cotejo (sin transcripción); la **puerta de habla no se presenta aquí** y sí en otro equipo (3.7.13) |
| Falta el paquete de inglés sin conexión | *«Falta instalar el inglés para dictar sin conexión.»* con *Cómo instalarlo*: los pasos de los ajustes del sistema (que necesitan red **una vez**) | Lo mismo que arriba hasta que esté instalado, y *Comprobar de nuevo* |
| No se ha probado en este equipo | *«Probemos tu dictado: activa el modo avión y di una frase.»* | Hacer la prueba (30 segundos) o escribir |
| Falta el permiso del micrófono | Se pide **al tocar** *Dictar* o *Grabar*, no antes (4.3) | Conceder o escribir |
| El reconocedor no entendió | *«No te escuché bien. Repite o escribe.»* | Repetir o escribir |

- **Qué ve la persona del texto:** lo reconocido. En una tarea diaria lo puede **corregir** (un error del reconocedor no es un error suyo); en un **turno de puerta no se edita**: lo que se reconoció es lo que se entrega. Cómo trata la IA los errores de reconocimiento lo define P6.0 (6.2 de esa especificación).
- **Texto, transcripción y voz (D-ING-13 matizada por D-ING-15).** El **texto escrito y la transcripción** se guardan en el dispositivo y **pueden salir hacia la IA**, solo con **permiso en cada envío** y el filtro de D3 (7.1). **La grabación de voz se queda siempre en el dispositivo**; el envío de audio queda como decisión futura (`docs/specs/fase-8-habitos-pareja-y-correccion.md`, 5.1 y 6.6). La **transcripción en sí es siempre local**: lo que sale es su texto, no la voz.
- **Dónde queda:** en el dispositivo, con la entrega, con la misma retención que la grabación. La nube recibe números (8.2).
- **La pronunciación** (25 % de la nota de habla, `gravity-escalon.yaml:179-185`) **no se puede juzgar bien desde un texto** (plan 3.8). Qué hacer con ese criterio es de P6.0; la app guarda, por criterio, **de dónde viene el puntaje** (`ia`, `pareja` o `programa`) para que cualquiera de las decisiones quepa sin cambiar tablas (8.2).

**4.5 Lo que no se verificó, y cómo verificarlo** (no se pudo instalar ni correr nada aquí)

| # | Pendiente | Cómo |
|---|---|---|
| V-b1 | Qué versión de Android tiene el Galaxy A52 del dueño y si ofrece reconocimiento local de inglés | `adb shell getprop ro.build.version.release` y una prueba de 60 s con el modo avión puesto |
| V-b2 | Si una transcripción de 60 a 180 s sale completa o hay que partirla en tramos | La misma prueba, contando palabras dichas contra reconocidas |
| V-b3 | Si se puede **grabar un archivo y reconocer a la vez** | Prototipo en P3.2b. Si no se puede, la decisión es del dueño: *oírse* (archivo, sin IA) o *ser corregido por la IA* (transcripción, sin archivo) |
| V-b4 | Micrófono y reconocimiento en Windows | `voz.dart:152-156` no los ofrece; se mide en P3.2b |
| V-b5 | Que el dictado y la transcripción **no usen la red**: ni en el equipo del dueño ni en los de la pareja | Modo avión, tres frases y una tarea de 60 s sin que falle; además, con el tráfico del teléfono medido (por ejemplo, el contador de datos de la app) en cero. Si falla, ese equipo queda como *no verificado* |

## 5. Sub-bloque 5c · Ubicación

**5.1 Lo decidido** (D-ING-5, plan 3.3 y contrato `data/ingles/formatos/gravity-ubicacion.yaml`)

| Regla | Valor |
|---|---|
| Cuándo se aplica | **Una sola vez por persona**, dentro de la app (`gravity-ubicacion.yaml:224-231`) |
| Preguntas | **12 por etapa** (6 de gramática y vocabulario, 3 de lectura y 3 de escucha con audio): 48 en total, en una forma fija de uso `ubicacion` (el banco tiene 72, 18 por etapa) |
| Se alcanza una etapa con | **10 de 12** y con **todas las anteriores** alcanzadas (`:215-220`) |
| Cuándo se deja de preguntar | Después de la **primera etapa no alcanzada** (`:221-223`) |
| Escucha | Con audio real. **No se abre hasta que el audio funcione en el dispositivo** (`:232-234`) |
| Qué **no** mide | Escritura ni habla. Una ubicación sin ellas puede ubicar de más; la primera puerta (80 % en las cuatro habilidades) lo corrige (5.7) |
| Servidor | Una persona solo puede tener **un** registro de ubicación |
| Unidades | No se usan en ningún otro lugar (V20) |

**Margen de error** (plan 3.3, cálculo binomial con preguntas independientes, comprobado): quien domina el 70 % de una etapa la alcanza el 25 % de las veces; quien domina el 90 % se queda fuera el 11 %; quien domina la mitad casi nunca la alcanza (2 %). Una prueba corta no da más precisión: por eso el resultado se corrige después con evidencia, no con otra ubicación.

**5.2 Lo que se resuelve en esta versión**

**Propuesta P5-21 · Un texto con tres preguntas y un audio con tres, que se oye dos veces.** El contrato dejó pendiente si las 3 preguntas de lectura y las 3 de escucha de cada etapa comparten un texto y un audio, y cuántas veces se oye (`gravity-ubicacion.yaml:62-63` y `:78-79`). Se adopta la propuesta de partida: **cada etapa lleva un texto de la longitud de su etapa con 3 preguntas y un audio con 3 preguntas**, y el audio se oye **hasta dos veces**, como en Cambridge y en el traslado del curso (TOEIC usa una; el contrato cita las dos opciones). Tres textos separados alargarían una prueba que ya llega a unos 51 minutos con los coeficientes de V22 (A1 9.8, A2 11.2, B1 13.5 y B2 16.7 minutos; estimación mía, no medida). Consecuencias para P2.1: la forma de 48 es 6 + 3 + 3 por etapa; el banco de 18 por etapa puede ser 6 + 6 + 6 (dos textos y dos audios de 3 preguntas) o 12 + 3 + 3; la elige P2.1 (`gravity-ubicacion.yaml:248-250` lo dejó pendiente). También son parte de esta propuesta: **sin cronómetro**, **sin retroalimentación** durante la prueba (no se dice si una respuesta fue correcta, ni se muestra el guion) y **sin la etiqueta de la etapa** en pantalla mientras se contesta (para no anclar: solo *«Parte 2»*).

**5.3 El flujo de pantallas** (ruta `ingles/ubicacion`)

1. **Antes de empezar.** Qué es, que se hace **una sola vez**, que dura **de unos 10 a unos 50 minutos según hasta dónde llegue** y que se puede pausar. Comprueba el audio (`disponibilidad`, 4.2): sin él, no hay botón de empezar y la pantalla explica cómo instalar una voz en inglés (motor, 5.5). Si hay conexión, comprueba además que el servidor **no tenga ya** una ubicación de esta persona (por ejemplo, hecha en otro equipo); si la tiene, muestra ese resultado y termina aquí. Sin conexión, avisa que no puede comprobarlo y deja continuar (5.8).
2. **Confirmar.** Un solo botón, *«Sí, empezar»*, con el aviso *«No se puede repetir»*. Es la única confirmación (T01).
3. **Pregunta.** Una por pantalla, con **cuatro opciones ya ordenadas** (V06). Las de lectura muestran el texto arriba mientras se contestan sus 3 preguntas; las de escucha, un botón ▶ con **dos reproducciones** (la segunda queda marcada; después no se puede volver a oír) y el guion **nunca** visible. La respuesta se elige y se confirma con *Siguiente*: **desde ahí es definitiva** (no hay *Atrás*) y se guarda en ese momento (T02).
4. **Pausar y reanudar, no reiniciar.** *Pausar* está siempre a la vista; salir de la app o mandarla a segundo plano pausa solo, y detiene el audio. Al volver, la prueba continúa **en la primera pregunta sin responder**; las reproducciones ya gastadas de un audio siguen gastadas. No existe ninguna acción de reiniciar. Como cada respuesta ya está en el servidor, también se reanuda **desde otro equipo o tras reinstalar** (con conexión).
5. **Fin de una etapa.** Sin mensaje: la prueba pasa a la siguiente o termina (5.4).
6. **Resultado.** *«Tu punto de partida: A2.1»* con una frase de contexto (*«Alcanzaste A1. Se ajusta con la práctica: si resulta corto o largo, hay una puerta anticipada y un descenso»*); los aciertos por etapa; y *Empezar mi primera semana* (el lunes siguiente, P5-03). Si alcanzó B2, además *«Presentar ahora la puerta de B2»* o *Ahora no* (3.7.8). Se escribe en este momento la ubicación y su primer escalón (T03).

**5.4 Cómo se decide** (decidido; el dominio recorre la forma sin conocer su contenido)

Se recorren las etapas A1, A2, B1 y B2 en ese orden. Al terminar las 12 preguntas de una etapa: con **10 o más aciertos** y todas las anteriores alcanzadas, la etapa se alcanza y sigue la siguiente; si no, la prueba **termina**. Las etapas que no se presentaron no tienen aciertos.

| Aciertos (A1 · A2 · B1 · B2) | Última etapa alcanzada | Qué pasó | Entra en |
|---|---|---|---|
| 7 | Ninguna | Termina tras A1 | **A1.1** |
| 11 · 8 | A1 | Termina tras A2 | **A2.1** |
| 12 · 10 · 7 | A2 | Termina tras B1 | **B1.1** |
| 12 · 11 · 10 · 9 | B1 | Se presentan las cuatro; B2 no se alcanza | **B2.1** |
| 12 · 12 · 11 · 10 | B2 | Alcanza B2 | **B2.1**, con derecho a presentar la puerta de la etapa B2 |
| 9 | Ninguna | Un acierto por debajo del corte: termina tras A1 y **no se pregunta A2**, aunque la persona lo habría contestado bien | **A1.1** |

**La tabla de entrada** (decidido, plan 3.3; `gravity-ubicacion.yaml:251-261`): ninguna → A1.1; A1 → A2.1; A2 → B1.1; B1 → B2.1; B2 → B2.1 (con derecho a la puerta inmediata). Doce preguntas no bastan para dar B2 por ganado, y por eso B2 también entra en B2.1.

**5.5 Qué se guarda**

| Dónde | Qué |
|---|---|
| **Servidor** (`ing_ubicacion_respuestas`, 8.2) | Por cada pregunta contestada: su id, la etapa y si acertó |
| **Servidor** (`ing_ubicaciones`) | Una fila: etapa alcanzada, escalón de entrada, aciertos de cada etapa presentada, forma y su huella, versión del contenido, fuente y acento del audio, y cuándo empezó y terminó |
| **Servidor** (`ing_escalones`) | La primera fila del historial (entrada `ubicacion`) |
| **Solo el dispositivo** | Las reproducciones gastadas de cada audio y el puntero de «dónde voy» |
| **No se guarda** | La opción elegida (solo si acertó), el tiempo por pregunta, ni el texto de ninguna pregunta (el contenido está en la app) |

**5.6 Cómo el servidor impide una segunda ubicación** (lo escribe `backend`, P2.2; aquí el requisito y su prueba)

1. `persona_id` es **único** en `ing_ubicaciones` (8.2): una segunda fila de la misma persona da 23505, con cualquier `id`.
2. **Sin UPDATE, DELETE ni TRUNCATE** para `authenticated` ni para `service_role` en `ing_ubicaciones` ni en `ing_ubicacion_respuestas`: son de solo agregar (8.3). Así no se puede borrar la fila y volver a insertar.
3. `ing_ubicacion_respuestas` tiene **una sola fila por (persona, pregunta)**: una respuesta no se cambia.
4. Una restricción comprueba que la fila **sea coherente con sus propios números** (la etapa alcanzada es la más alta con 10 o más aciertos y todas las anteriores; las etapas no presentadas no tienen aciertos). El servidor no conoce la clave de las preguntas, así que no puede comprobar que los aciertos sean ciertos: la ubicación se corrige con evidencia, no con vigilancia.
5. La **única** forma de que desaparezca es *Borrar mis datos › todo* o la baja a los 90 días (P5-20, 8.3).

**Propuesta P5-20 · Borrar todos mis datos de Hábitos incluye el inglés y la ubicación.** Quien borra *todo* (`hab_borrar_mis_datos('todo')`, D21) pierde también su ubicación y puede ubicarse otra vez, porque no queda nada que corregir ni historial que proteger. Es el derecho a borrar de D21, no una forma de repetir la prueba. Hay una entrada en la bitácora sin contenido, la que ya deja esa función (`habitos.borrar_datos`).

**5.7 Cómo se corrige después** (decidido, D-ING-5)

- **No hay otra ubicación**: ninguna pantalla tiene un botón de repetir, y una prueba de código lo comprueba (CA-5c-11).
- **Hacia arriba:** la **puerta anticipada** de la semana 2 de cada escalón, con 90 % en cada habilidad y sin gastar oportunidades (3.7.8); quien entró en B2, además, la puerta inmediata de B2.
- **Hacia abajo:** el **descenso por evidencia**: dos mini pruebas seguidas por debajo de 50 % bajan un escalón sin penalización (3.7.9), o una caída en la puerta (3.7.3, T17).

**5.8 Casos de borde**

| Caso | Qué hace la app |
|---|---|
| El audio falla a media ubicación | Se detiene y deja pausar; no gasta una reproducción que no se oyó completa. Al volver el audio, continúa. La fuente congelada (4.2) no cambia a media prueba: si la fuente ya no sirve, se pausa hasta que vuelva |
| Hecha en un equipo, abierta en otro | Con conexión, la app lee `ing_ubicaciones` y `ing_ubicacion_respuestas` y se entera. Sin ella, ver la fila siguiente |
| Dos equipos sin conexión hacen la ubicación a la vez | El **primero en sincronizar gana**; el servidor rechaza al otro (23505). El segundo equipo **adopta la ubicación del servidor**, descarta la suya y lo dice sin culpa. Por eso la comprobación del paso 1 (5.3) existe |
| La persona borra los datos de la app a mitad | Con conexión, retoma desde el servidor (cada respuesta ya está allí). Sin conexión y sin lo subido, las respuestas que no llegaron se pierden y se vuelven a contestar: es el límite de no reiniciar sin red |
| Ubicación sin audio | No se abre (3.7.13, 4.2) |

## 6. Sub-bloque 5d · Exámenes

**6.1 Qué dice el contenido y qué hace la app con ello.** Cada **forma** compilada trae su `uso`, su `fidelidad` (`completa` o `reducida`, con la lista de `motivos` si es reducida), su `huella`, las secciones con sus minutos y si necesita audio. **La app nunca calcula la fidelidad: la lee** (`docs/specs/fase-8-ingles-formato.md`, secciones 1 y 5; V26).

| `uso` | Dónde se presenta | ¿Exige fidelidad completa? | ¿Para qué cuenta? |
|---|---|---|---|
| `ubicacion` | 5 | Sí (todas las partes de `gravity-ubicacion`) | Escalón de entrada |
| `mini` | 3.6 | Es de 10 preguntas | Descenso por evidencia y tarjetas de error |
| `escalon` | 3.7 | **Sí**: todas las partes de `gravity-escalon` | Puerta del escalón |
| `etapa` | 3.7 | **Sí. Si la forma instalada es reducida, la puerta no se ofrece** (D-ING-1: formato de examen oficial) | Puerta y etiqueta de la etapa |
| `simulacro` | 6.2 | No; si es reducida, se rotula (6.6) | Semáforo, solo si es completa |
| `practica` | 6.5 | Se evalúa solo sobre las partes que incluye | Precisión por parte; no cuenta para nada más |

**6.2 Las formas de las puertas y su fidelidad**

- **Puerta de etapa (A2.3, B1.4, B2.4):** tres formas de uso `etapa` con el contrato de su examen (`cambridge-a2-key`, `cambridge-b1-preliminary`, `cambridge-b2-first`), de fidelidad **completa**: número de unidades y preguntas del contrato, longitudes dentro del rango, escucha con audio y sin datos pendientes en las partes que usa (formato, sección 5). Los otros simulacros de esos exámenes son otras formas de uso `simulacro`, que no comparten nada con las de la puerta (V20).
- **Puerta de escalón y prueba interna de A1:** hoy el contrato `gravity-escalon` deja pendientes las cuatro partes (`gravity-escalon.yaml:42-76`) y por la regla del formato (sección 6.2, regla 4) **ninguna forma de escalón puede salir completa mientras sigan pendientes**. **Propuesta P5-29** para cerrarlas, dentro de lo decidido (D-ING-6: 10 preguntas objetivas o más por habilidad): **lectura**, 2 textos de la longitud de la etapa con 5 preguntas cada uno; **escucha**, 2 audios de la longitud de la etapa con 5 preguntas cada uno, que se oyen 2 veces; **escritura**, una tarea de la extensión de la etapa; **habla**, una tarea de la duración de la etapa (`gravity-sesion-60.yaml:177-182`). Con los coeficientes de V22 cabe en un turno de 60 minutos o menos (A2: unos 37; B2: unos 55; cálculo mío, suponiendo 12 minutos de escritura en A2 y 20 en B2, y 5 de habla). La extensión por etapa de la rúbrica (`gravity-escalon.yaml:176-178`) sale de la misma tabla. *Si se veta:* el contrato sigue pendiente y no hay puertas de escalón; lo resuelve quien reciba la decisión (14).
- **Qué se muestra** en una puerta: `Puerta de escalón` o `Puerta de etapa · A2 (tipo A2 Key)`, la fidelidad que dice el contenido y el aviso del 80 % (3.7.1).

**6.3 Modo examen** (puertas y simulacros completos; la política fina del reproductor es de P3.1, `docs/specs/fase-8-motor-de-voz.md`, 6.3). Lo que esta especificación exige:

1. **Tiempo oficial** por sección (los `minutos` del contrato compilado), con cuenta regresiva visible. Es un reloj **de pared**: no se detiene al salir de la app.
2. **Audio como el examen:** las reproducciones del contrato, **sin pausa y sin 0.8**, con la fuente congelada y registrada (4.2).
3. **Sin retroalimentación** hasta terminar la sección y sin guion.
4. **No se reinicia** una sección empezada: al volver se continúa con el tiempo que quede o se cierra con lo contestado.
5. Lo objetivo se califica **al cerrar la sección**, en el dispositivo; escritura y habla se entregan (7).

**6.4 El semáforo de preparación** (plan 3.4: *«rojo, menos de 60 % en alguna prueba; amarillo, de 60 a 79 %; verde, 80 % o más en todas las pruebas de dos formas completas, con audio y con el tiempo oficial»*). Una **prueba** es una sección del contrato (A2 Key y B1 Preliminary: lectura, escritura, escucha y habla; B2 First: lectura y *Use of English*, escritura, escucha y habla; TOEIC: escucha y lectura, o habla y escritura; TOEFL: lectura, escucha, escritura y habla). Su porcentaje es `aciertos ÷ preguntas` en lo objetivo y `suma ponderada ÷ 400` en escritura y habla (`ing_puntajes`).

**Propuesta P5-25 · Cómo se calcula.** Solo cuentan los intentos de **formas completas, en modo examen y con audio** (`ing_intentos` con `fidelidad = completa`; los intentos de puerta de etapa también cuentan para el examen que imitan). Se evalúa en este orden:

| # | Condición | Color |
|---|---|---|
| 1 | No hay ningún intento completo | **Sin datos** (gris) |
| 2 | En el intento completo **más reciente**, alguna prueba tiene **menos de 60 %** | **Rojo** (terracota, nunca rojo de alarma) |
| 3 | Hay **dos** intentos completos de **formas distintas** y en **cada uno** de los dos más recientes **todas** las pruebas tienen **80 % o más** | **Verde** |
| 4 | Cualquier otro caso | **Amarillo** |

Cada color va con **texto y la prueba más baja** (*«Tu prueba más baja: Escucha, 72 %»*), nunca solo color. Ejemplos con las cuatro pruebas de A2 Key: ningún intento → gris; una forma con 85, 90, 78 y 95 → amarillo; dos formas distintas con todo 80 o más → verde; esas mismas con un 58 en el habla de la más reciente → rojo; dos intentos de **la misma** forma con todo 80 o más → amarillo; solo formas reducidas → gris. **El semáforo no convierte a ninguna escala oficial** en esta versión (plan 3.4): la conversión se agrega cuando calidad la verifique en su fuente. Aviso fijo: *«Es una guía propia de GRAVITY: el 80 % por habilidad es un margen de seguridad, no el criterio del examen»* (plan, anexo E.2, punto 4).

Mientras el contrato de un examen tenga datos pendientes, sus formas salen **reducidas** y su semáforo, en gris. Hoy les pasa a TOEIC y TOEFL (el plan anota 24 datos pendientes, casi todos de esos dos: anexo A, fila P1.1a); TOEFL además es adaptativo (módulo de ruta y módulo inferior o superior) y su contrato no define el enrutamiento (`data/ingles/formatos/toefl-ibt-2026.yaml:25`, `:82`).

**6.5 La práctica por partes.** Desde el banco de cada parte (unidades de uso `practica`): la persona elige examen y parte, y hace de 1 a 12 unidades (plan 5.2). **Retroalimentación inmediata** (`porque` y `porque_no`), sin reloj, con el audio según el contrato y 0.8 opcional. Se ofrecen primero las unidades que no hizo; si no quedan, puede repetirlas y se marcan *repetidas*. Se guarda en `ing_practicas` (aciertos y preguntas por unidad). Una práctica de una sola parte puede ser completa en esa parte y se rotula *«Parte completa»*; **no cuenta** para minutos, día completo ni constancia (son extras, como el domingo), ni para el semáforo. Las rutas se abren por escalón: **TOEIC desde B1.2 y TOEFL desde B2.1** (plan 3.1) y, por propuesta, **A2 Key desde A2.1, B1 Preliminary desde B1.1 y B2 First desde B2.1**; es una tabla de `ReglasIngles`. No son puertas y no afectan al curso (CA-5d-09).

**6.6 Cómo se rotulan los simulacros de formato reducido.** Toda forma muestra una marca de **texto e icono**, *Formato completo* o *Formato reducido*, y la fidelidad sale **solo** del contenido compilado. En una reducida, un detalle *Por qué es reducido* lista sus `motivos` en español (por ejemplo: *«Los textos son más cortos que los del examen: Reading 3»*, *«Sin audio real: la escucha se lee»*, *«Faltan partes: Speaking»*, *«El contrato del examen todavía tiene datos pendientes»*). Antes de empezar un simulacro reducido, la pantalla dice lo que decían los documentos tras P0.1: *«Formato reducido: mismo número de preguntas, textos más cortos y sin audio. Sirve para practicar, no para saber si estás listo»*. Una forma reducida **nunca** alimenta una puerta ni el semáforo, y ninguna pantalla escribe «completo» ni «verificado» por su cuenta (CA-5d-01).

## 7. Sub-bloque 5e · Pareja y corrección con IA

**La especificación de la pareja y de la corrección con IA es P6.0** (`docs/specs/fase-8-habitos-pareja-y-correccion.md`, versión 0.2, ya escrita y en revisión; plan, fase 6). Esta sección se alineó con ella el 17/nov/2026 y la sigue en lo que decide (5.1, 5.2 y 6). Allí se decide qué sale hacia la IA, cómo se califica con la rúbrica, qué se hace con la pronunciación, la calibración, la revisión cruzada y qué ve cada quien del otro. **Aquí solo va lo que necesita el estudiante**, para que 5a a 5d no dependan de adivinar P6.0, y la lista de lo que queda condicionado a ella.

**7.1 Lo que necesita el estudiante**

| Qué | Cómo |
|---|---|
| **Activar la corrección** | **Dos** interruptores en Ajustes › Inglés (`ing_perfil`, 8.2), **apagados por omisión**: `correccion_ia_escritura` y `correccion_ia_habla` (propuesta P6-16 de P6.0; el segundo cubre también la conversación de habla). Es la forma de la regla *«IA opcional por función»* (D-ING-9) |
| **Entregar una tarea** | Desde el bloque de producción (tarea diaria) o desde un turno de puerta: escritura (el texto) o habla (la grabación y su transcripción, 4.3 y 4.4) › *Entregar*. Una entrega no se edita después. En una **tarea diaria** la corrección con IA es opcional (*Pedir corrección*) y **no cuenta para ninguna puerta**; en una **puerta** la corrige la IA o, si la persona no la activó, la pareja y la IA; nunca la persona misma (3.7.13) |
| **Saber qué se envía** | Antes de enviar, una pantalla dice qué sale y a dónde: *«Se enviará este texto para corregirlo. No se envía tu voz.»* y un botón *Enviar* / *Ahora no*. **El permiso se pide en cada envío** y no se recuerda (D-ING-15) |
| **Ver una corrección** | Pantalla con los criterios de la rúbrica (0 a 4 cada uno), la suma sobre 400, «gramática del tema» y las observaciones; y al lado, su **autoevaluación con la lista de cotejo**. Las observaciones se guardan solo en el dispositivo |
| **Esperar** | Estado `enCorreccion` (3.7.2): sin veredicto ni etiqueta (D-ING-10). Sin conexión, la entrega queda guardada como *lista para enviar*; **al volver la red no sale sola**: la persona confirma el permiso de ese envío (9.7) |
| **Límites** | Si el servidor limita el uso (P6.2), la pantalla lo dice sin reproche y la entrega espera |

**Qué viaja a la IA y qué no** (D3, D21, plan 3.8). Viaja **solo** el texto escrito o la transcripción de **esa** entrega, el id de la rúbrica y el escalón (para el nivel de exigencia); lo arma una estructura cerrada que no incluye ningún dato de otro módulo, el nombre ni el correo de la persona (CA-5e-02). El filtro de D3 corre **en el servidor** antes de que salga texto (`docs/ROADMAP.md`, control de cambios, versión 1.7) y la clave del proveedor **nunca va en la app**: la llamada es a la función `supabase/functions/gravity-asistente` con la sesión de la persona (`supabase/functions/gravity-asistente/index.ts:5-8`). El **audio nunca** sale (4.3). **Permiso por envío (D-ING-15):** nada sale sin que la persona lo acepte esa vez. **En el proveedor** queda lo que diga su política de datos **[no verificado]**; el nivel gratuito de algunos proveedores puede usar lo enviado, y eso lo trata P6.0 (5.1).

**Qué se guarda y dónde** (D21: Hábitos es personal, la cuenta maestra no lo lee; las tablas `hab_*` y `ing_*` no escriben en la bitácora):

| Dato | Dispositivo | Nube (`ing_*`, en claro, por persona) |
|---|---|---|
| Contenido del curso y sus claves | Sí (`app/assets/ingles/`) | No |
| Progreso: escalones, sesiones, bloques, repasos, tarjetas, intentos, puntajes, ubicación | Copia local | **Sí** (8) |
| **Texto escrito, transcripción y observaciones de la corrección** | **Sí, solo aquí** | **No** |
| **Grabaciones de voz** | **Sí, solo aquí** | **Nunca** |
| Metadatos de una entrega (tipo, palabras o segundos, contexto) | Sí | Sí, **sin el texto** (`ing_entregas`) |
| Puntajes de una corrección (por criterio y suma) | Sí | Sí (`ing_puntajes`) |
| Lo que se manda a la IA | No se conserva | No se conserva (el servidor no lo guarda) |

Que lo escrito y lo grabado **no se vea en la laptop ni se respalde en la nube** es lo más prudente para texto y voz personales mientras no se elija un modo de D13 para ellos; si el dueño lo quiere distinto, es la pregunta 7.

**7.2 Lo que queda condicionado a P6.0** (esta versión no lo decide ni lo construye)

1. El formato de lo que se manda a la función y de lo que vuelve (criterios, escala, límites, coste, versión de la rúbrica).
2. **La pronunciación**: qué se hace con un criterio que un texto no juzga (4.4).
3. **El habla en pareja** de los exámenes (A2 Key parte 2, B1 partes 3 y 4, B2 parte 3) cuando no hay otra persona.
4. Cómo llegan la escritura y el habla de la puerta a la **pareja** cuando la persona no activa la IA (D-ING-11): qué ve ella, con qué consentimiento y qué rúbrica usa. Aquí: la entrega espera en `enCorreccion` (3.7.13).
5. Cómo trata la IA los errores del reconocedor de voz (4.4).
6. **Pareja:** calendario compartido si coinciden de escalón, reto semanal que no depende del nivel, revisión cruzada, qué ve cada quien del otro **con consentimiento**, y los emparejamientos de escalones distintos (plan 3.7). **Mientras P6.0 no exista, ninguna pantalla ni tabla de este bloque comparte nada**: el dueño no lee lo de la pareja ni al revés (CA-5m-02).
7. La **calibración** de la IA contra revisión humana antes de confiar en ella (P6.4) y las tablas de pareja y consentimiento (P6.1), con la misma regla: la cuenta maestra no lee (D21).

**7.3 Las condiciones del arranque del curso** (D-ING-9 y D-ING-10; plan 3.8 y fase 6)

- **El curso no empieza hasta que la fase 6 del plan esté integrada**; no hay etiqueta provisional, porque nadie empieza antes. Se mantienen D3, D21 y que la clave del proveedor nunca va dentro de la app.
- **Cómo se impone en la app (Propuesta P5-24, parte 2):** una **bandera de compilación `INGLES_ARRANQUE`**, apagada por omisión, junto a las que ya lee `ConfiguracionEntorno` (`app/lib/nucleo/configuracion/configuracion_entorno.dart:6-20`). Apagada, **no se ofrece nada que empiece el curso**: ni *Tu punto de partida*, ni la ubicación, ni la sesión; el contenido puede estar ya en `app/assets/ingles/` (el piloto) sin ninguna entrada que lo abra. La enciende el arquitecto cuando P6.1 a P6.4 estén integradas, estén cumplidos los pendientes del dueño que ya figuran en el roadmap (la **clave de Gemini**, el **despliegue de la función del asistente** y el **proyecto de Google Cloud**: `docs/ROADMAP.md`, control de cambios, versión 1.7; `docs/DECISIONES.md:568`) y el dueño lo apruebe.
- **El curso funciona sin IA.** Sesiones, tarjetas, mini pruebas, ubicación, práctica por partes y la lectura y escucha de las puertas no la usan (plan, sección 1, punto 4). La escritura y el habla de las puertas las corrige la IA, o la pareja y la IA, o esperan (D-ING-11, 3.7.13).

## 8. Modelo de datos `ing_*`

Es la **propuesta** de tablas que escribirá `backend` en P2.2. No contiene SQL: dice qué es cada tabla, sus columnas, tipos, claves y restricciones, y sigue las convenciones de las `hab_*` (`supabase/migrations/20261105000000_habitos.sql`, `20261106000000_habitos_sensibles.sql` y `20261107000000_habitos_endurecimiento.sql`). **Doce tablas** en lugar de las cinco de la versión 0.4: el contenido ya no vive en tablas (`ing_unidades` e `ing_lecciones` desaparecen: están en `app/assets/ingles/`, 8.5).

**8.1 Convenciones que se copian de `hab_*`**

| # | Convención | De dónde | Aplicación |
|---|---|---|---|
| 1 | Toda tabla lleva `hogar_id` y `persona_id`; **los pone el servidor** al insertar y no cambian | `hab_propio()`, `20261105000000_habitos.sql:276-314` | La app no los manda (CA-5m-08) |
| 2 | Lectura y escritura solo de lo propio: `persona_id = persona_actual()` y `hab_activa(hogar_id)` | `:318-341` | 8.3 |
| 3 | Privilegios **por columna**, revocados a `PUBLIC`, `anon` y `authenticated` antes de conceder; `service_role` solo lee | `:568-625`; convención 12, `:11` | Los `grant insert` repiten la lista completa de columnas |
| 4 | UUID generado en el dispositivo; **v5** donde dos equipos deben converger | `docs/specs/fase-3-habitos.md`, convención 5 | La columna *Id* de cada tabla lo dice |
| 5 | Editable: `modificado_en` (reloj del dispositivo) y `actualizado_en` (servidor); el último gana. **Solo agregar:** `ocurrido_en` (dispositivo, no más de 5 minutos en el futuro) y `recibido_en` (servidor) | `hab_propio` y `fin_una_vez` | 8.3 |
| 6 | **Sin contadores guardados** | `docs/specs/fase-3-habitos.md`, convención 3 | Nada de «racha», «escalón actual» ni «minutos» como columna |
| 7 | Sin trigger de bitácora; el prefijo del servidor queda reservado | D21; `:426-455` | 8.3 |
| 8 | Cuota de filas por persona y tabla | `hab_cuota_filas`, `20261107000000_habitos_endurecimiento.sql:189-224` | 8.3 |

**Columnas comunes.** Todas las tablas llevan: `hogar_id uuid not null → hogares` y `persona_id uuid not null → personas` (las pone el servidor) y, salvo `ing_perfil` e `ing_tarjetas`, `ocurrido_en timestamptz not null` y `recibido_en timestamptz not null default now()`. `ing_perfil` e `ing_tarjetas` llevan `modificado_en timestamptz not null` y `actualizado_en timestamptz not null default now()`. Las claves compuestas `(persona_id, id)` se declaran únicas para que las llaves foráneas **no crucen personas**, como `hab_objetivos_persona_id_key` (`:127`).

**8.2 Las tablas.** «Solo agregar» = sin UPDATE ni DELETE (8.3). Las columnas de texto con lista cerrada llevan `check … in (…)`.

**`ing_perfil`** · editable · una fila por persona (se crea al primer uso; la app solo hace UPDATE de sus columnas)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `persona_id` | uuid | **PK** |
| `correccion_ia_escritura`, `correccion_ia_habla` | boolean | not null, default `false` cada una (7.1; propuesta P6-16 de P6.0, que reemplaza al único `correccion_ia`) |
| `recordatorio_hora` | time | nulo = sin recordatorio (P5-18) |
| `conservar_grabaciones` | text | not null, default `30_dias`; `30_dias` o `al_entregar` (P5-23) |
| `contenido_version` | text | nulo; hasta 40 caracteres. La versión del contenido compilado que **este equipo reportó** (8.5) |
| `contenido_huella` | text | nulo; hasta 64 caracteres |

**`ing_escalones`** · solo agregar · el historial de ciclos (3.1)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v5 de la persona, el ciclo del que se sale y el motivo: la misma transición vista por dos equipos es **la misma fila** |
| `escalon` | text | not null; una de las 13 etiquetas (`A1.1` … `B2.4`) |
| `entrada` | text | not null; `ubicacion`, `sube`, `sube_anticipada`, `baja_por_puerta`, `baja_por_evidencia`, `repite_tras_caida`, `repite_por_requisitos` |
| `desde` | date | not null; **lunes** (`extract(isodow from desde) = 1`) |
| `tras_revision` | boolean | not null, default `false` (T20) |
| — | único | `(persona_id, desde)`: nadie entra a dos escalones el mismo lunes. Si dos equipos deciden transiciones distintas, el segundo da 23505 y adopta la del servidor (9.5). Único `(persona_id, id)` |

**`ing_ubicacion_respuestas`** · solo agregar · una respuesta por pregunta (5)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v5 de la persona y la pregunta |
| `pregunta_id` | text | not null; el id de la pregunta del contenido (1 a 80 caracteres) |
| `etapa` | text | not null; `A1`, `A2`, `B1` o `B2` |
| `ok` | boolean | not null |
| — | único | `(persona_id, pregunta_id)`: **una respuesta no se cambia** |

**`ing_ubicaciones`** · solo agregar · **una sola por persona** (5.6)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK** (la cola inserta con `ON CONFLICT (id) DO NOTHING`) |
| `persona_id` | uuid | **único**: la regla de «una sola» |
| `etapa_alcanzada` | text | nulo = ninguna; `A1`, `A2`, `B1` o `B2` |
| `escalon_de_entrada` | text | not null; una de las 13 etiquetas, coherente con la etapa (tabla de 5.4) |
| `aciertos_a1`, `aciertos_a2`, `aciertos_b1`, `aciertos_b2` | smallint | nulos si la etapa no se presentó; de 0 a 12 |
| `forma_id`, `forma_huella`, `contenido_version` | text | not null |
| `fuente_audio` | text | not null; `pregrabado`, `modelo` o `dispositivo` (motor, 6.2) |
| `variante_audio` | text | not null; `en-US` o `en-GB` |
| `iniciada_en`, `terminada_en` | timestamptz | not null; `terminada_en ≥ iniciada_en` |
| — | check de coherencia | La etapa alcanzada es la más alta con 10 o más aciertos y todas las anteriores; las no presentadas no tienen aciertos (5.6, punto 4) |

**`ing_sesiones`** · solo agregar · **una por día de estudio** con trabajo (3.3)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v5 de la persona y la fecha |
| `escalon_registro_id` | uuid | not null; llave `(persona_id, escalon_registro_id) → ing_escalones`: el ciclo del día |
| `fecha` | date | not null; lunes a viernes (`isodow` de 1 a 5). **Único** `(persona_id, fecha)` |
| `origen` | text | not null; `curso`, `practica`, `puerta` o `espera` (3.7) |
| `semana`, `dia` | smallint | not null; de 1 a 8 y de 1 a 5: la **sesión de contenido** que se hizo (en la práctica es la que se repitió, por eso `dia` no tiene por qué coincidir con el día de la `fecha`) |
| `contenido_version`, `sesion_huella` | text | `contenido_version` not null; `sesion_huella` nula. Para saber con qué contenido se estudió |
| — | único | `(persona_id, id)` |

**`ing_bloques`** · solo agregar · **un tramo de trabajo** de un sub-bloque (3.3). Cada vez que la persona sale de un sub-bloque se escribe un tramo con lo que hizo; el trabajo del día es la **suma** de sus tramos, así que dos equipos o una pausa no necesitan editar nada. La mini prueba, la prueba por unidad y los turnos de puerta son **un solo tramo** y no se reanudan

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v4 del dispositivo |
| `sesion_id` | uuid | not null; llave `(persona_id, sesion_id) → ing_sesiones` |
| `bloque` | text | not null; `repaso`, `mini_prueba`, `leccion`, `conversacion`, `pronunciacion`, `produccion`, `traslado_audio`, `traslado_repeticion`, `traslado_tarjetas`, `puerta_turno` o `prueba_unidad` (3.6.1) |
| `audio` | boolean | not null; si había audio del curso disponible **al empezar** el tramo (3.3) |
| `elementos_hechos`, `elementos_total` | smallint | not null; `elementos_total > 0` y `0 ≤ elementos_hechos ≤ elementos_total` |
| `segundos` | smallint | not null; de 0 a 3 600: los segundos **acreditados en este tramo** (3.3). El dominio los topa en los minutos declarados del sub-bloque |
| `aciertos`, `preguntas` | smallint | nulos, o ambos; `aciertos ≤ preguntas` (lección, mini prueba y prueba por unidad) |
| `unidad` | smallint | nulo; **solo** con `bloque = 'prueba_unidad'`, y entonces no nulo: de 1 a 4 (3.6.1, D-ING-14) |
| `intento` | smallint | nulo; **solo** con `bloque = 'prueba_unidad'`, y entonces no nulo: 1 o 2 |
| `forma_id` | text | nulo; **solo** con `bloque = 'prueba_unidad'`: la forma usada (`a` o `b`), de hasta 80 caracteres |
| `detalle` | jsonb | nulo; lista de hasta 2 KB; en la mini prueba, `[{p, ok}]` (3.6) |

**`ing_tarjetas`** · **editable, y es solo una caché** de `ing_repasos` (3.5) · se escribe **únicamente** con `ing_guardar_tarjetas` (8.4), no con INSERT o UPDATE directos

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `persona_id`, `tarjeta_id` | uuid, text | **PK compuesta**; `tarjeta_id` es el id de la tarjeta del curso o `err:<id de la pregunta>` (hasta 80 caracteres) |
| `origen` | text | not null; `curso` o `error` |
| `estado` | text | not null; `activa` o `dominada` |
| `caja` | smallint | not null; de 1 a 3 |
| `vence` | date | nulo si está dominada |
| `ultimo_repaso` | date | nulo |

**`ing_repasos`** · solo agregar · **la verdad** del repaso espaciado

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v4 |
| `tarjeta_id` | text | not null; como en `ing_tarjetas` |
| `fecha` | date | not null; la fecha local del repaso (de ella salen los intervalos) |
| `calidad` | text | not null; `introducida`, `otra_vez`, `bien`, `facil` o `reactivada` |
| `origen` | text | not null; `repaso`, `traslado`, `mini_prueba` o `libre` |
| `sesion_id` | uuid | nulo; llave `(persona_id, sesion_id) → ing_sesiones` |

**`ing_intentos`** · solo agregar · una presentación de una forma completa: una oportunidad, una anticipada o un simulacro (3.7, 6)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v5 de la persona, el ciclo y el tipo para una puerta (un tipo **una vez por ciclo**); v4 para un simulacro |
| `tipo` | text | not null; `oportunidad_1`, `oportunidad_2`, `anticipada`, `anticipada_b2` o `simulacro` |
| `escalon_registro_id` | uuid | nulo solo en el simulacro: `(tipo = 'simulacro') = (escalon_registro_id is null)`; llave `(persona_id, escalon_registro_id) → ing_escalones` |
| `formato`, `forma_id`, `forma_huella`, `contenido_version` | text | not null (el contrato, la forma, su huella y la versión del contenido) |
| `fidelidad` | text | not null; `completa` o `reducida` (lo que dijo el contenido) |
| `modo_examen` | boolean | not null |
| `fuente_audio`, `variante_audio` | text | nulos si la forma no tiene audio; mismas listas que en `ing_ubicaciones` |
| `iniciado_en` | timestamptz | not null |
| — | único parcial | `(persona_id, escalon_registro_id, tipo)` donde `escalon_registro_id` no es nulo |

**`ing_puntajes`** · solo agregar · el resultado de **una sección** de un intento. Una corrección posterior es **una fila nueva** con `corrige_a` (el registro no se edita: `niveles-y-avance.md`, sección 7)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v4 |
| `intento_id` | uuid | not null; llave `(persona_id, intento_id) → ing_intentos` |
| `seccion` | text | not null; el id de la sección del contrato (`reading`, `listening`, `reading-use-of-english`…) |
| `habilidad` | text | not null; `lectura`, `escucha`, `escritura` o `habla` |
| `aciertos`, `preguntas` | smallint | **o** estos dos (lo objetivo) **o** los dos de abajo, nunca los cuatro: `aciertos ≤ preguntas` |
| `suma_ponderada`, `gramatica_del_tema` | smallint | de 0 a 400 y de 0 a 4 (escritura y habla) |
| `criterios` | jsonb | nulo; hasta 1 KB: `{criterio: {p: 0 a 4, o: "ia" o "auto"}}`, el origen de cada puntaje (4.4) |
| `origen` | text | not null; `programa` (objetivo) o `ia` (escritura y habla) |
| `rubrica_version` | text | nulo |
| `entrega_id`, `corrige_a` | uuid | nulos; `entrega_id` llave a `ing_entregas`; `corrige_a` a otra fila de esta tabla |
| — | único parcial | `(intento_id, seccion)` donde `corrige_a` es nulo: un puntaje original por sección; el vigente es el último de la cadena |

**`ing_entregas`** · solo agregar · los **metadatos** de una tarea entregada (el texto y la voz **no se guardan aquí**, R4; el texto puede ir a la IA con permiso, 7.1)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v4 |
| `tipo` | text | not null; `escritura` o `habla` |
| `contexto` | text | not null; `puerta` o `tarea_diaria`; `(contexto = 'puerta') = (intento_id is not null)` |
| `intento_id`, `sesion_id` | uuid | nulos; llaves compuestas a `ing_intentos` e `ing_sesiones` |
| `palabras` | smallint | solo en escritura; ≥ 0 |
| `segundos` | smallint | solo en habla; ≥ 0 |
| `transcrita_en_dispositivo` | boolean | not null, default `false` (4.4) |
| `con_ia` | boolean | not null: si la persona la envió a corrección (7.1) |

**`ing_practicas`** · solo agregar · práctica por partes de un examen (6.5)

| Columna | Tipo | Restricciones y nota |
|---|---|---|
| `id` | uuid | **PK**; v4 |
| `formato`, `parte`, `unidad_id` | text | not null |
| `aciertos`, `preguntas` | smallint | not null; `0 ≤ aciertos ≤ preguntas` |
| `repetida` | boolean | not null, default `false` |
| `fidelidad`, `contenido_version` | text | not null; `completa` o `reducida`; la versión del contenido |

**8.3 Reglas por persona, solo agregar, bitácora, borrado y cuotas**

**Reglas por persona (D5, D21).** Las doce tablas usan la misma regla que `hab_*` (`20261105000000_habitos.sql:318-341`): se lee y se escribe lo propio si `hab_activa(hogar_id)`, es decir, con **membresía vigente de dueño, coadministrador o familiar que no sea la cuenta maestra** (`docs/specs/fase-3-habitos.md`, 4.4, línea 176). Por tanto: el **dueño y la pareja solo ven lo propio**; la **cuenta maestra, el cuidador, la cuenta Hogar y `anon` no leen ni escriben nada**; una persona dada de baja pierde el acceso al instante y sus filas se conservan sin acceso y se borran a los 90 días.

| Tabla | Leer | Insertar | Cambiar | Borrar |
|---|---|---|---|---|
| Las **diez de solo agregar** (`ing_escalones`, `ing_ubicacion_respuestas`, `ing_ubicaciones`, `ing_sesiones`, `ing_bloques`, `ing_repasos`, `ing_intentos`, `ing_puntajes`, `ing_entregas`, `ing_practicas`) | Lo propio | La app, sin las columnas del servidor | **Nadie** | **Nadie** desde la app; solo las dos funciones de abajo |
| `ing_perfil` | Lo propio | La app (primer uso) | Solo `correccion_ia_escritura`, `correccion_ia_habla`, `recordatorio_hora`, `conservar_grabaciones`, `contenido_version`, `contenido_huella` y `modificado_en`; el último gana | Solo las dos funciones |
| `ing_tarjetas` | Lo propio | **Solo** `ing_guardar_tarjetas` | **Solo** `ing_guardar_tarjetas` | Solo las dos funciones |

**Solo agregar de verdad.** Las diez bloquean UPDATE, DELETE y TRUNCATE para `authenticated` **y** para `service_role`, y no se les concede el privilegio. Ojo: `impedir_cambios_solo_agregar()` (`20261020000000_base.sql:289-302`) bloquea *«a cualquier rol, también el dueño de la tabla»*; si se usa tal cual, **ni siquiera `hab_borrar_datos_de` podría borrar** al dar de baja a alguien ni al *Borrar mis datos*. Se pide a `backend` una **variante** que deje pasar solo a esas dos funciones del servidor (14).

**Idempotencia de la cola.** Como en los libros solo agregar de Finanzas (`fin_una_vez`, modo `estricto`: `20261021000000_finanzas_mvp1.sql:1001-1033`): **mismo id y mismo contenido** no inserta nada y no falla; **mismo id con otro contenido** da 23505 (un duplicado real que requiere atención); las columnas que pone el servidor (`recibido_en`) no se comparan.

**Bitácora (D21).** Ninguna tabla `ing_*` lleva trigger de bitácora. Las protecciones de D21 están escritas para el prefijo `hab_` (`20261105000000_habitos.sql:426-455`): la política `bitacora_agregar` rechaza una `tabla` que empiece por `hab_` y `puede_ver_entrada_bitacora` oculta al dueño y a la maestra esas entradas. **`ing_` quedaría fuera de las dos**, así que se pide a `backend` **reservar también el prefijo `ing_`** en ambas (14). No hay constancias nuevas: la única es la de `hab_borrar_mis_datos` (`habitos.borrar_datos`, sin contenido).

**Borrado.** `hab_borrar_datos_de(…, 'todo')` y `hab_limpiar` se amplían para borrar las doce tablas (los alcances `sensibles` y `diario` no las tocan). La baja se borra a los 90 días desde `desactivada_en` (`20261107000000_habitos_endurecimiento.sql:152-181`). Quien borra *todo* puede ubicarse otra vez (P5-20).

**Cuotas por persona y tabla (propuesta; `54000` al pasarlas, como `hab_cuota_filas`).** `ing_escalones` 300 · `ing_ubicacion_respuestas` 48 · `ing_ubicaciones` 1 · `ing_sesiones` 3 000 · `ing_bloques` 40 000 · `ing_repasos` 60 000 · `ing_tarjetas` 15 000 · `ing_intentos` 600 · `ing_puntajes` 4 000 · `ing_entregas` 4 000 · `ing_practicas` 20 000. Salen de tres años de estudio con más del doble de holgura (por ejemplo, 40 repasos al día de lunes a jueves son unos 8 300 al año y unos 25 000 en tres).

**8.4 Lo que se pide al servidor** (resumen para P2.2)

1. **`ing_propio()`**: pone `persona_id`, `hogar_id` y `recibido_en`, y limita `ocurrido_en` a 5 minutos en el futuro (como `hab_propio`).
2. **Solo agregar** con su variante para el borrado de las dos funciones (8.3).
3. **`ing_guardar_tarjetas(p_tarjetas jsonb)`**: hasta 100 por llamada, idempotente, el último gana por `modificado_en`, con los rangos de la tabla; `security definer` y con el mismo cuidado que `hab_subir_sobres` (`20261107000000_habitos_endurecimiento.sql:15-86`). Se llama desde la cola como una función (`funciones` de `EnviadorSupabase`).
4. **Ampliar** `hab_borrar_datos_de`, `hab_limpiar`, la bitácora (prefijo `ing_`) y `avisos_actualizar_preferencias` para aceptar el tipo silenciable `hab_ingles` (`20261105000000_habitos.sql:529-537`).
5. **Cuotas** (8.3) y **checks** de rango, lista cerrada y coherencia (5.6).
6. **Pruebas SQL** (CA-5m): RLS de las doce, solo agregar, ubicación única, borrado, bitácora y cuotas, en `supabase/tests/` con el siguiente número libre (hoy el último es `116_alimentacion_reclasificar.sql`).

**8.5 Qué contenido viaja dentro de la app y qué se sincroniza**

| Qué | Dónde | Notas |
|---|---|---|
| **Contenido compilado** de lo que está en `revisado` o `aprobado` (V25): el curso por escalón (8 semanas × 5 sesiones, guiones de audio, tarjetas y mini pruebas), las formas de las puertas, la ubicación, los simulacros y el banco de práctica por partes | `app/assets/ingles/`: `indice.json` y recursos `.json.gz` por escalón, forma y parte. Lo escribe `compilar` (P1.2c); **no se edita a mano** | Incluye las **claves**: hacen falta para calificar sin red (R5). No son un secreto; la ubicación y las puertas se corrigen con evidencia, no con vigilancia (5.6). El tamaño lo dirá `informe`; **[sin medir]** |
| **Audio pregrabado** (vía C) y **modelos de voz** (vía B) | No van en `assets`: paquetes descargables por escalón, que caducan si cambia el guion (`huella_guion`) | `docs/specs/fase-8-motor-de-voz.md`, 4.2 y 4.3 |
| **Versión del contenido** | `indice.json` (`version` y `huella`). La app la reporta en `ing_perfil`; cada sesión, intento y ubicación guarda la versión y la huella de **lo que se usó** | Un id de sesión o de forma **no cambia** entre versiones; si se retira una forma, queda en la lista de retiradas del índice y 3.7.11 la salta |
| **Se sincroniza (nube, en claro, por persona)** | Las doce tablas `ing_*` | 8.2 |
| **Se queda en el dispositivo** (el texto y la transcripción pueden ir a la IA con permiso en cada envío, D-ING-15; la grabación, nunca) | Texto escrito, transcripciones, observaciones de la IA, grabaciones, reproducciones gastadas de la ubicación y el puntero de «dónde voy» | R4, 7.1 |

## 9. Sin conexión y sincronización

**9.1 Qué se estudia sin red (D-ING-13).** **Estudiar sin conexión funciona completo.** Es decir: lo que el dueño ve en la mesa de estudio, en el tren o en un hotel, **no pide red en ningún paso**. Todo el curso está compilado dentro de la app (`app/assets/ingles/`, 8.5) y todo lo que se escribe se guarda primero en el teléfono (9.2).

| Qué | Sin red | Cómo se garantiza |
|---|---|---|
| **El curso instalado:** los 13 escalones, sus 8 semanas, las puertas, las pruebas por unidad y la práctica por partes | **Sí** | Contenido y claves en `app/assets/ingles/`; ninguna pantalla espera a la red para cargarlo (CA-5s-06, CA-5s-15) |
| **La ubicación** (12 preguntas por etapa) | **Sí**, ya empezada | Para **empezar**, con red, se comprueba que no exista otra (5.3); sin red no se bloquea: se empieza y, si al volver hay otra, gana la primera (5.8) |
| **La sesión del día** completa: repaso, lección, pronunciación, producción y traslado | **Sí** | Cada tramo va a la base local (3.3) |
| **Las tarjetas** y el repaso espaciado | **Sí** | La caja y la fecha de cada tarjeta se calculan en el teléfono (3.5) |
| **Las mini pruebas y las pruebas por unidad** (con su repetición) | **Sí** | Las corrige el programa, sin IA (3.6, 3.6.1) |
| **La voz del motor** (traslado, ejemplos, el guion de los audios) | **Sí**, con una voz en inglés instalada | La reproducción no usa la red (R8 del motor); si falta la voz, el traslado queda *disponible cuando haya audio* (3.2) |
| **Grabar** | **Sí** | La grabación es local (4.3) |
| **Dictar y transcribir** | **Sí**, si el equipo reconoce inglés en el dispositivo (4.4) | Es **requisito de 5b** (D-ING-13); si el equipo no lo garantiza, la persona ve qué hacer (tabla de 4.4) |
| **Los turnos de una puerta y de un simulacro** | **Sí** | Se **presentan** sin red; lo que necesita red es la corrección (siguiente tabla) |
| **Progreso, racha, faltas, metas y calendario** | **Sí** | Son cálculos sobre los datos locales (3.4, 3.8) |
| **Ajustes de Inglés** (recordatorio, retención de grabaciones, interruptores de IA) | **Sí** | Se guardan en `ing_perfil` local y suben por la cola (el último gana, 9.4) |

**Lo que sí necesita red** (y qué pasa mientras no la hay):

| Qué | Por qué | Qué ve y qué se guarda |
|---|---|---|
| **Corrección con IA** de la escritura y del habla (D-ING-15) | La hace una función en la nube | La entrega queda **guardada en el teléfono como *lista para enviar***. **No se envía sola** al volver la red: como cada envío pide permiso, la persona lo confirma entonces (9.7) |
| **Revisión de la pareja** | Los puntajes del revisor los escribe el servidor (P6.0, 4.3 y 8.4) | La revisión queda guardada en el teléfono del revisor *lista para enviar* y sube al volver la red; la voz nunca sale |
| **Sincronizar entre equipos** | Es la cola contra Supabase (9.2) | *Por subir: N*; todo sigue en el teléfono |
| **Descargas** (voces del sistema, paquete de inglés para dictar, una versión nueva del contenido) | Son archivos | Solo con **aviso y tamaño**, nunca solas (motor, 4.2); si se corta, **no queda nada a medias** (9.6) |
| **Comprobar que no hay otra ubicación** | Consulta al servidor | Se hace al empezar si hay red; sin red se omite sin bloquear |

**9.2 La cola sin conexión.** Todo lo que el inglés escribe pasa **primero por la base local y la cola** (`app/lib/nucleo/cola/`), con la sesión de la persona; nunca se escribe en el servidor directamente.

**Hallazgo que obliga a pedirlo:** hoy Hábitos escribe sus tablas con `upsert` directo (`app/lib/modulos/habitos/datos/repositorio.dart:49-77`), y la cola solo conoce las tablas de Finanzas (`tablasDeLaCola`, `app/lib/app/arranque.dart:120`) y dos funciones de Hábitos, la de sobres y la de borrado (`:224-227`). La especificación de la Fase 3 pide una prueba `cola_hab_test.dart` (criterio 10) que no existe en `app/test/` (se comprobó con una búsqueda el 16/nov/2026). El inglés **no** puede escribir directo: estudia sin red. Los tipos son personales (el prefijo `habitos.` ya lo es: `app/lib/nucleo/cola/cola_sin_conexion.dart:61-69`), así que **nunca** suben con el origen de la tablet de la casa (`enviador_supabase.dart:111-120`).

| Tipo de cola | Destino | Mecanismo | Nivel de subida |
|---|---|---|---|
| `habitos.ingles_perfil` | `ing_perfil` | Insertar la primera vez; `actualizaciones` después | 0 |
| `habitos.ingles_escalon` | `ing_escalones` | Insertar (`ON CONFLICT (id) DO NOTHING`) | 0 |
| `habitos.ingles_ubicacion_respuesta` | `ing_ubicacion_respuestas` | Insertar | 0 |
| `habitos.ingles_practica` | `ing_practicas` | Insertar | 0 |
| `habitos.ingles_tarjetas` | Función `ing_guardar_tarjetas` | `funciones` de `EnviadorSupabase` | 0 |
| `habitos.ingles_ubicacion` | `ing_ubicaciones` | Insertar | 1 |
| `habitos.ingles_sesion` | `ing_sesiones` | Insertar | 1 |
| `habitos.ingles_intento` | `ing_intentos` | Insertar | 1 |
| `habitos.ingles_bloque` | `ing_bloques` | Insertar | 2 |
| `habitos.ingles_repaso` | `ing_repasos` | Insertar | 2 |
| `habitos.ingles_entrega` | `ing_entregas` | Insertar | 2 |
| `habitos.ingles_puntaje` | `ing_puntajes` | Insertar | 3 |

Los niveles siguen las llaves foráneas (una sesión antes que sus bloques; un intento antes que sus puntajes y entregas; una entrega antes del puntaje que la cita), como `nivelesDeSubidaFinanzas` (`contrato_servidor.dart:83-126`). Si algo llega antes que su dependencia (23503), **se reintenta sin detener la ronda** (comportamiento actual de la cola). La app **no manda** `recibido_en` ni lo que ponen los triggers (`columnasQuePoneElServidor`); la prueba `app/test/nucleo/cola/contrato_servidor_test.dart` ya lee las migraciones y falla si la tabla de columnas o la de niveles dejan de coincidir con el servidor, y se amplía a `ing_*` (CA-5m-08).

**Orden, reintentos y estados de un evento.** Se comprobó leyendo `app/lib/nucleo/cola/cola_sin_conexion.dart` el 17/nov/2026:

1. **Orden de subida:** cada ronda sube primero los tipos de **nivel menor** y, dentro de un nivel, **en el orden en que se crearon** (`:422-429`). Un tipo de nivel bajo creado después pasa primero; el reintento por dependencia cubre el resto (`:25-29`).
2. **Falla pasajera** (sin señal, servidor ocupado): se programa el reintento con **espera creciente** (5 segundos, ×2, tope de 30 minutos: `PoliticaReintentos`, `:164-181`) y **se detiene la ronda**. Tras **20 intentos** sin respuesta clara el evento pasa a *requiere atención* (`:263`).
3. **Falta de dependencia** (23503): se reintenta con la misma espera, **sin detener la ronda** y sin ir a *requiere atención* hasta pasar **100 intentos**, unos dos días (`:264` y `:287-292`).
4. **El servidor lo rechaza** (permisos, datos inválidos, 23505 distinto del propio): pasa a *requiere atención*, **no se pierde ni se reintenta solo** (`:17-18`).
5. **El orden real de lo ocurrido** lo da `ocurrido_en` (reloj del teléfono) y, en empate, el `id` (9.5); el orden de **subida** solo importa para las llaves foráneas. Las pantallas se alimentan de la base local, así que **no esperan a la subida**.
6. **Si se cierra la app o se apaga el teléfono sin red**, nada se pierde: la cola vive en la base local (`Pendientes`, `base_local.dart:44-79`) y retoma al abrir.

**9.3 Dónde vive cada dato en el dispositivo.** Como en la Fase 3, la verdad vive en **dos lugares**: la base local, que alimenta las pantallas y funciona sin señal, y Supabase, para sincronizar entre equipos (`docs/specs/fase-3-habitos.md`, sección 4, línea 81).

- La base local de hoy (`gravity.sqlite`, drift) tiene **una sola tabla, `Pendientes`** (`app/lib/nucleo/base_local/base_local.dart:44-79`, `schemaVersion` 3 en `:91`). El inglés necesita **tablas locales espejo de las doce** y una migración local; es un pedido a `plataforma` (14), porque `app/lib/nucleo` es suya.
- **Lo que no va a la nube** (R4) vive en la base local y en una carpeta privada: textos, transcripciones, observaciones de la IA y grabaciones. Una limpieza (`LimpiezaLocal.registrar`, `limpieza_local.dart:63`) lo borra **al salir, al detectar una baja y al quitar a la persona de la tablet**, y *Borrar mis datos* también (P5-20).
- **Subida y bajada.** Sube por la cola. Baja al abrir Inglés y tras sincronizar: lo nuevo de las diez de solo agregar por `recibido_en` y lo editable por `actualizado_en`; cada fila se deduplica por `id`. Las diez se mezclan sin reglas de fusión (9.4).

**9.4 Por qué lo solo-agregar no genera conflictos**

1. **Cada fila nace con un UUID del dispositivo** y la cola inserta con `ON CONFLICT (id) DO NOTHING`: reenviar tras una respuesta perdida **no duplica** (`app/lib/nucleo/cola/enviador_supabase.dart`, documentación de la clase).
2. **Nada se edita:** dos equipos producen filas **disjuntas** y la verdad es su unión. No hay nada que fusionar.
3. **Lo derivado se recalcula** de la unión con funciones puras: escalón actual, constancia, minutos, racha, tarjetas por vencer, semáforo (R7). Dos equipos con las mismas filas dan el mismo resultado. Los minutos de un bloque son la **suma de tramos**; un tramo duplicado es el mismo `id`.
4. **El estado de una tarjeta es un reproceso ordenado** (`ocurrido_en`, `id`) de sus repasos (3.5); `ing_tarjetas` es una caché que se recalcula.
5. **Lo único editable** (`ing_perfil` y la caché de tarjetas) se resuelve con *el último gana* por `modificado_en` y un tope de 5 minutos en el futuro (`hab_propio`, `20261105000000_habitos.sql:299-312`).
6. **Las pocas restricciones de unicidad** (una ubicación por persona, una respuesta por pregunta, una sesión por día, un ciclo por lunes, un intento de cada tipo por ciclo) se resuelven con **el primero que llega gana**; el que pierde recibe 23505, queda en *requiere atención*, **adopta la fila del servidor** y se lo dice a la persona sin reproche (9.5).

**9.5 Dos equipos y casos raros**

| Caso | Qué pasa |
|---|---|
| El mismo día en el teléfono y en la laptop | La sesión del día tiene el mismo `id` (v5 de persona y fecha); los tramos de bloque se suman; los repasos se entrelazan por (`ocurrido_en`, `id`) |
| Dos equipos con **transiciones distintas** del mismo ciclo (uno sube, otro repite) | El segundo `ing_escalones` del mismo lunes da 23505; ese equipo recalcula con la fila del servidor |
| Dos ubicaciones sin conexión | 5.8 |
| Un equipo con otra versión del contenido | Los ids de sesión y de forma no cambian; cada fila guarda versión y huella; 3.7.11 salta lo retirado |
| Reloj del dispositivo mal puesto | `ocurrido_en` más de 5 minutos en el futuro se ajusta a la hora del servidor; el desempate por `id` mantiene el orden determinista. Un reloj atrasado reordena repasos del mismo día sin cambiar su `fecha` |
| Una entrega o una corrección en espera | Se conserva local como *lista para enviar* hasta que la persona confirme el envío con red (D-ING-15); la cola no la manda a *requiere atención* por falta de red |
| Tablet pública | No ofrece inglés (P5-26): no hay cola de inglés ahí |

**9.6 Cómo se instala el contenido por adelantado (propuesta P5-32).** Todo el curso viaja **dentro de la app**: instalar o actualizar la app con Wi-Fi **es** instalar el curso (8.5). No hay descargas de lecciones durante el estudio. Lo único que depende del equipo y no de la app son la **voz en inglés** y el **paquete de reconocimiento de inglés**: los instala el sistema, no la app **[no verificado: que la app pueda iniciar esas descargas; se asume que solo puede guiar a la persona a los ajustes]**.

La pantalla **Listo para estudiar sin conexión** (Ajustes › Inglés, y una invitación una sola vez antes de la primera sesión) revisa cinco cosas y marca cada una como lista o pendiente, con el paso exacto que falta y sin color de alarma:

| # | Se revisa | Lista cuando | Si falta |
|---|---|---|---|
| 1 | **Contenido del curso** | La versión y la huella del contenido instalado (`contenido_version` y `contenido_huella` de `ing_perfil`) coinciden con las del índice compilado, y el índice cubre los 13 escalones | *«Hay contenido nuevo»*: actualizar la app con Wi-Fi |
| 2 | **Voz en inglés** | `MotorVoz.disponibilidad(UsoVoz.curso, …)` es positiva (motor de voz, 6.1) | Los pasos de instalar una voz (motor, 5.5). El estudio sigue; el traslado espera (3.2) |
| 3 | **Dictado en el dispositivo** | La comprobación de 4.4 está *verificada* | La tabla de 4.4 |
| 4 | **Permiso del micrófono** | Concedido (opcional: se pide al grabar) | Se pide al tocar *Grabar* |
| 5 | **Lo que falta por subir** | *Por subir: 0*, o el número y la fecha de la última subida | Nada que hacer: se sube solo. Es informativo |

Reglas de toda descarga (de las voces o del contenido, si el dueño agrega paquetes de audio después): **se pide con el tamaño y la opción de esperar a Wi-Fi; no se hace sola; no deja el contenido a medias**: un paquete se instala **completo o no se instala**, y lo que ya servía sigue sirviendo hasta que el nuevo esté completo (CA-5s-16). Una semana típica de viaje (cinco sesiones) no necesita nada más que lo de la tabla.

**9.7 Qué ve la persona según su conexión (propuesta P5-33).** Salen de un catálogo cerrado (`MensajesIngles`, 3.8), sin palabras de `MensajesHabitos.prohibidas`. El estado sale de lo que ya existe: `ResumenConexion` (`app/lib/nucleo/conectividad/conectividad.dart:117`), `hayRedProvider` (`:76`) y `porSubirProvider` (`:156`). **Ninguna pantalla de estudio espera a la red ni muestra un cargando por ella.**

| Estado | Dónde se ve | Texto |
|---|---|---|
| En línea y todo subido | En ninguna parte (silencio) | — |
| **Sin conexión** | Una cinta pequeña y neutra arriba de Inicio de inglés y de Progreso | *«Sin conexión: tu avance se guarda y se sincroniza después»* |
| **Por subir** (N > 0) | Progreso y Ajustes › Inglés | *«3 cosas por subir. Se suben solas cuando haya conexión.»* |
| **Necesita atención** (eventos rechazados) | Ajustes › Inglés, con *Ver* | *«Algo no pudo subir. Tu estudio está a salvo en este teléfono.»* |
| **Lista para enviar** (corrección con IA o revisión de la pareja, sin red o sin permiso aún) | En la entrega y en Progreso | *«Tu entrega está lista para enviar. Cuando haya conexión te pedimos permiso.»* |
| **Esperando la corrección** (ya enviada) | En la entrega, con `enCorreccion` (3.7.2) | *«Tu entrega espera su corrección. No tienes que hacer nada.»* |
| **Contenido por actualizar** | Ajustes › Inglés | *«Hay contenido nuevo. Actualiza la app con Wi-Fi.»* |
| **Sin voz o sin dictado local** | En el sub-bloque que lo usa | Los textos de 3.8 y 4.4 |

## 10. Criterios de aceptación

Cada criterio se comprueba con una prueba concreta, que incluye **al menos un caso malo** (el dato cambiado que debe rechazarse). Dónde van:

- **Dominio:** `paquetes/habitos_dominio/test/ingles/` · `cd paquetes/habitos_dominio && dart test`.
- **App:** `app/test/modulos/habitos/ingles/` y, donde dice *(plataforma)*, `app/test/nucleo/` · `cd app && flutter analyze && flutter test --exclude-tags hallazgo`.
- **Servidor:** `supabase/tests/` con el siguiente número libre (hoy el último es el 116), `bash supabase/tests/correr.sh`.
- **Manual (A52):** las hace el dueño o calidad, con el Galaxy A52; se anotan en `docs/revisiones/`.

Numeración: `CA-5a-nn` núcleo, `CA-5b-nn` audio y habla, `CA-5c-nn` ubicación, `CA-5d-nn` exámenes, `CA-5e-nn` pareja y corrección con IA, `CA-5m-nn` modelo de datos y `CA-5s-nn` sin conexión. Los ejemplos numéricos son los de las secciones citadas y están comprobados con un script. Los archivos de prueba son nombres propuestos.

**5a · Núcleo en la app** (sección 3)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5a-01 | **Escalera:** los 13 escalones salen de una sola tabla del dominio con su etapa, su orden, sus horas acumuladas (40 por escalón; 80, 200, 360 y 520 al pasar la puerta de etapa) y su tipo de puerta (A1.2 interna; A2.3, B1.4 y B2.4 de etapa; el resto, de escalón). `anterior(A1.1)` y `siguiente(B2.4)` no existen; `siguiente(B1.4)` es B2.1 | `escalera_test.dart` |
| CA-5a-02 | **Las cifras de D29 viven en un solo lugar:** `ReglasIngles` (80, 90 y 50 %; 8 de 10; 2 oportunidades; 10 minutos de tolerancia por día; 3 días faltados por escalón; 80 % en las pruebas por unidad; 35 y 60 minutos; 3 cajas; 40 tarjetas; 8 nuevas) **coincide con** `data/ingles/formatos/gravity-escalon.yaml` y `gravity-sesion-60.yaml` (las cifras de asistencia y de unidades se piden a esos contratos, 14). Caso malo: cambiar una cifra en el dominio rompe la prueba | `reglas_coinciden_con_contratos_test.dart` (lee los YAML del repositorio) |
| CA-5a-03 | **Perfil:** el escalón actual es la fila de `ing_escalones` con `desde` más reciente; la semana es `(lunesDe(hoy) − desde) ÷ 7 + 1`; con semana mayor que 8 el estado es práctica o espera, **nunca «semana 9»** | `perfil_test.dart` |
| CA-5a-04 | **Etiquetas:** se muestra «B1 · escalón 2 de 4» y **nunca «B1+»**; una etiqueta está ganada si hay un intento aprobado de la puerta que cierra su etapa, y **se conserva al bajar** | `perfil_test.dart` |
| CA-5a-05 | **Inicio en lunes:** un cambio de escalón registrado el jueves 26/nov/2026 empieza el lunes 30/nov; uno registrado el lunes 23/nov empieza el lunes 30/nov (el primer lunes **posterior**). `desde` nunca cae en otro día | `calendario_estudio_test.dart` |
| CA-5a-06 | **Sesión del día:** de lunes a jueves, siete sub-bloques de 5, 10, 8, 12, 10, 10 y 5 minutos (60); el viernes, mini prueba en lugar del repaso y conversación en lugar de la lección y **ninguna tarjeta nueva**; sin audio, solo los cuatro del principal (35) | `sesion_del_dia_test.dart` |
| CA-5a-07 | **Minutos planeados** (P5-04): con audio 2 400 min por escalón (mínimo que deja pasar la asistencia, 1 850); sin audio 1 400 (925); mixto de 30 días con audio y 10 sin él, 2 150 (1 600); con una semana de práctica, 2 700 (2 100) | `minutos_test.dart` |
| CA-5a-08 | **Acreditación proporcional:** el lunes del ejemplo (pronunciación 9 de 12) acredita 58 minutos; ningún sub-bloque acredita más que sus minutos declarados aunque tenga varios tramos | `minutos_test.dart` |
| CA-5a-09 | **Producción mínima:** una entrega por debajo de la mitad del mínimo de la etapa (A1 15 palabras y 15 s; A2 25 y 23; B1 40 y 30; B2 70 y 45) **no** acredita; en el mínimo, sí | `minutos_test.dart` |
| CA-5a-10 | **Día completo** (P5-05): con audio exige todos los elementos de los siete sub-bloques; sin audio, los de los cuatro del principal; 11 de 12 elementos de pronunciación **no** lo completan; un bloque que empieza el martes 23:55 y termina el miércoles cuenta en el martes | `dia_completo_test.dart` |
| CA-5a-11 | **Modo del día:** con un solo bloque empezado con audio, el día cuenta 60; con todos sin audio, 35; sin ningún bloque, 60 | `dia_completo_test.dart` |
| CA-5a-12 | **Sesión pasada, práctica libre:** no suma minutos, no completa el día, no quita una falta ni la gasta; sus repasos sí entran a `ing_repasos` | `sesion_libre_test.dart` |
| CA-5a-13 | **Asistencia por día** (P5-30): con 60 planeados, un día con 50 minutos acreditados (faltante 600 s) queda `asistido` y con 49:59 queda `faltado`; sin audio (35), 25:00 asiste y 24:59 no; los 10 minutos **no se acumulan** (dos días con 9 minutos de faltante no dan 18 de crédito); el ejemplo de 3.3 (58 minutos, 3 elementos sin hacer) es `asistido` e incompleto | `asistencia_dia_test.dart` |
| CA-5a-14 | **Faltas del escalón** (P5-30): con inicio el 23/nov/2026, faltan el 25/nov (0 min), el 2/dic (40 min), el 10/dic (55 min) y el 17/dic (49 min), y el 8/ene/2027 no se estudia: el 25/nov, el 2/dic y el 17/dic son `faltado`, el 10/dic `asistido` y el 8/ene `excedido`; el cálculo es por ciclo (un escalón nuevo o una segunda vuelta empieza en cero); **no hay trimestres**: el 24/feb/2027 no recibe faltas nuevas | `faltas_escalon_test.dart` |
| CA-5a-15 | **Racha de inglés:** el fin de semana no rompe ni suma; el día en curso no rompe; un día `faltado` (tolerado) no la rompe y un `excedido` sí, con *«Un día no borra lo que has avanzado. Retomemos hoy.»*; la mejor racha no baja | `racha_ingles_test.dart` |
| CA-5a-16 | **Constancia y minutos del escalón:** cumplidas si ningún día de la ventana (3.7.5) queda `excedido`; las tres ventanas (oportunidad 1, 2 y anticipada) dan resultados distintos con los mismos datos; una semana de práctica suma días pero no agrega faltas permitidas | `constancia_test.dart` |
| CA-5a-17 | **Asistencia con enteros:** `faltante` en segundos, 600 asiste y 601 no; con planeados en cero (puerta inmediata de B2, primer día) se da por cumplido; **caso malo:** el 90 % de la versión 0.5 (2 160 de 2 400 min) **no** pasa como regla: un escalón con 37 días de 50 minutos y 3 en cero **sí** pasa, y uno con 4 días en cero **no** | `asistencia_test.dart` |
| CA-5a-18 | **Metas semanales** (P5-27): 5 de 5 días, 300 minutos (175 sin audio) y 60 repasos se calculan y **no bloquean** ninguna transición | `metas_test.dart` |
| CA-5a-19 | **Repaso espaciado** (P5-06): *otra vez* → caja 1; *bien* → +1; *fácil* → +2; *bien* en la caja 3 → dominada. El ejemplo de 3.5 da las fechas 24/nov, 1/dic, 29/dic, 2/dic y 22/dic | `repaso_espaciado_test.dart` |
| CA-5a-20 | **Días de estudio:** un *otra vez* el viernes 27/nov/2026 vence el lunes 30/nov; sábado y domingo no cuentan para ningún intervalo | `repaso_espaciado_test.dart` |
| CA-5a-21 | **Cola del repaso:** hasta 40; orden por vencimiento, caja e `id`; la fallada reaparece **una vez** sin cambiar la caja ni contar como elemento; sin audio, las 8 nuevas van primero | `cola_repaso_test.dart` |
| CA-5a-22 | **Tarjetas nuevas:** 8 de lunes a jueves, 0 el viernes, 32 por semana; la de un día no presentado no se acumula | `cola_repaso_test.dart` |
| CA-5a-23 | **Convergencia:** dos equipos con repasos intercalados de la misma tarjeta llegan al **mismo estado**, en cualquier orden de llegada; repetir un repaso es idempotente | `repaso_convergencia_test.dart` |
| CA-5a-24 | **Carga sostenible:** una simulación de 520 días de estudio con 32 nuevas a la semana, 3 errores semanales, 8 % de *otra vez* y 12 % de *fácil* (generador propio de semilla fija) deja un rezago promedio de **5 tarjetas o menos** con la cola de 40; con una escalera de 8 cajas, la prueba **falla** (el caso malo) | `repaso_carga_test.dart` |

**5a · Núcleo en la app** (continuación: mini prueba, puertas y pantallas)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5a-25 | **Mini prueba:** 10 preguntas; 8 aprueba y 7 no; «por debajo de 50 %» es `aciertos × 2 < preguntas`: **4 de 10 sí, 5 de 10 no** | `mini_prueba_test.dart` |
| CA-5a-26 | **Qué cuenta una mini prueba no aprobada** (P5-07): cada error crea una tarjeta de error en la **caja 1** que vence el siguiente día de estudio (y no se duplica); **no se repite la semana**; no gasta faltas ni cambia los minutos; con 5 a 7 aciertos **no** cuenta para el descenso | `mini_prueba_test.dart` |
| CA-5a-27 | **Descenso por evidencia** (P5-09): dos mini pruebas seguidas de 0 a 4 aciertos en el mismo ciclo bajan un escalón el lunes siguiente (T06); una de 5 a 7 o una aprobada entre medias lo impide; la cuenta empieza en cero en cada ciclo; en A1.1 no hay cambio (T07); **no cuenta como caída** | `descenso_test.dart` |
| CA-5a-28 | **Aprobar una puerta:** 80 % por habilidad **sin compensar** (100, 100, 100 y 79 no aprueba); en 10 preguntas, 8 aprueba y 7 no; escritura con 320 de 400 y gramática 3 aprueba; **3 en todo (300) no**; 320 con gramática 2 no; habla con 330 y gramática 2 no | `aprobar_puerta_test.dart` |
| CA-5a-29 | **Sin crédito parcial** (P5-16): cada pregunta objetiva vale 1 o 0 y pesa lo mismo, también en las partes de *Use of English* de B2 | `aprobar_puerta_test.dart` |
| CA-5a-30 | **Máquina de estados:** una prueba por **cada fila de la tabla de 3.7.3 (T01 a T20)**, con el estado de partida, el evento y la fila nueva que se escribe | `puertas_estados_test.dart` (dirigida por tabla) |
| CA-5a-31 | **Dos oportunidades y práctica:** la oportunidad 2 no se ofrece antes de pasar al menos una semana de práctica; la oportunidad 1 es al final de la semana 8; el estado entre ellas es `practica` y **no** se numera como semana 9 | `practica_test.dart` |
| CA-5a-32 | **Armado de la práctica:** las habilidades no alcanzadas se ordenan de menor a mayor porcentaje (empate: lectura, escucha, escritura, habla); escucha usa el martes, lectura y escritura el jueves, habla el viernes y el miércoles; se elige la sesión más antigua no repetida; los últimos días son los turnos | `practica_test.dart` |
| CA-5a-33 | **Caídas seguidas** (P5-10): la segunda caída lleva a `revisionPendiente` y el destino no se escribe hasta confirmar (T20); aprobar una puerta o una anticipada pone la cuenta en cero; un descenso por evidencia **no la toca**; en A1.1 la primera caída repite A1.1 | `caidas_test.dart` |
| CA-5a-34 | **Bajar a un escalón que cierra una etapa:** la etiqueta ganada se conserva y se vuelve a presentar su puerta | `puertas_estados_test.dart` |
| CA-5a-35 | **Subir exige los cuatro requisitos** (P5-13): unidades, puerta, constancia y minutos; si falta una unidad, la constancia o los minutos, el escalón se repite (T15), no se baja ni se gasta oportunidad, y la etiqueta de la etapa queda ganada; la pantalla dice cuál faltó | `requisitos_subir_test.dart` |
| CA-5a-36 | **Puerta anticipada** (P5-11): solo en la semana 2, una vez por ciclo, con la forma de reserva; 90 % es 9 de 10, 11 de 12 y 14 de 15, y 360 de 400; con 2 en gramática el máximo es 320 (escritura) y 330 (habla), por debajo de 360; asistencia y unidades de lo cursado (con 10 días de estudio, a lo más 3 faltados); no gasta oportunidades | `puerta_anticipada_test.dart` |
| CA-5a-37 | **Puerta inmediata de B2:** solo con ubicación B2, una vez, del primer día al fin de la semana 2, con el 90 %; aprobada termina el curso y gana la etiqueta B2 (T10); no aprobada no cambia nada | `puerta_anticipada_test.dart` |
| CA-5a-38 | **Forma que toca** (P5-12): anticipada → C; oportunidades → la primera no presentada en A, B, C; con las tres presentadas, la de hace más tiempo; una forma retirada se salta; sin ninguna, la puerta no se ofrece | `forma_que_toca_test.dart` |
| CA-5a-39 | **Turnos** (P5-15): A2 Key en 2 turnos de 90 y 10 minutos; B1 Preliminary en 2 de 90 y 42; B2 First en 3 de 75, 80 y 54; una puerta de escalón en 1; ningún turno parte una sección ni un papel; el día de un turno acredita 3 600 segundos y queda completo | `turnos_puerta_test.dart` |
| CA-5a-40 | **Turno no presentado:** no caduca, se ofrece el siguiente día de estudio y el día en que faltó queda sin completar | `turnos_puerta_test.dart` |
| CA-5a-41 | **Sin IA, no hay autocalificación** (P5-24, D-ING-11): con el interruptor apagado, lectura y escucha de una puerta se presentan y califican; escritura y habla se entregan y quedan en `enCorreccion`; ninguna ruta ni caso de uso acepta un puntaje de escritura o habla de la propia persona; al activar la IA, las entregas en espera se **ofrecen para enviar** y salen solo con el permiso de cada envío (D-ING-15) | `puerta_sin_ia_test.dart` (app) y `aprobar_puerta_test.dart` |
| CA-5a-42 | **En corrección:** no hay veredicto ni etiqueta; los días de espera quedan como `espera` y cuentan para la constancia y los minutos del ciclo | `en_correccion_test.dart` |
| CA-5a-43 | **3 toques o menos:** de Hoy a estar dentro del primer sub-bloque pendiente hay 2 toques; *Continuar* abre el siguiente pendiente; las rutas de 3.8 existen | `toques_ingles_test.dart` (como `app/test/modulos/habitos/toques_habitos_test.dart`) |
| CA-5a-44 | **Sin culpa:** ningún texto del catálogo `MensajesIngles` contiene una palabra de `MensajesHabitos.prohibidas` ni usa rojo; los textos de 3.8 salen del catálogo | `mensajes_ingles_test.dart` |
| CA-5a-45 | **Recordatorio local** (P5-18): *«Es hora de tu práctica de inglés»* (32 caracteres, sin dígitos ni «$»), apagado por omisión, respeta las horas silenciosas, solo *Empezar* y *Posponer 10 min* (sin *Hecho*) | `avisos_discretos_ingles_test.dart` |
| CA-5a-46 | **Racha global intacta** (P5-19): `evaluarDiaGlobal` da lo mismo con y sin inglés; Hoy muestra la fila de Inglés con **su** racha | `racha_global_intacta_test.dart` y prueba de widget |
| CA-5a-47 | **Roles y dispositivos:** dueño, coadministrador y familiar ven Inglés; cuidador, Hogar y la cuenta maestra no; la tablet **pública no** lo ofrece (P5-26) y la **personal** funciona como el teléfono | `ingles_por_rol_test.dart` *(plataforma)* |
| CA-5a-48 | **Calendario:** sábado y domingo no son días de estudio; el inglés ligero del domingo no suma ni cubre un día | `calendario_estudio_test.dart` |
| CA-5a-49 | **Repetir por asistencia** (D-ING-12, P5-30): con cuatro días faltados la puerta aprobada **no** sube: se aplica T15, el escalón se repite el lunes siguiente con las faltas y las unidades en cero, y la etiqueta de la etapa queda ganada; con tres días faltados **sí** sube; el aviso de la tercera falta sale **antes** y ningún texto usa palabras prohibidas | `repetir_por_asistencia_test.dart` y `mensajes_ingles_test.dart` |
| CA-5a-50 | **Unidad** (P5-31): el viernes de las semanas 2, 4, 6 y 7 la Lección es una prueba de 20 preguntas (15 sin audio); aprueba con 16 de 20 (12 de 15) y no con 15 de 20; acredita 10 × hechas ÷ total minutos; la conversación guiada de ese viernes se omite | `prueba_unidad_test.dart` |
| CA-5a-51 | **Repetición de la unidad:** una unidad no aprobada vuelve como tarjetas de error y se repite **una vez** el lunes siguiente (semanas 3, 5, 7 y 8) con la forma `b`; la repetición no gasta faltas; si tampoco se aprueba la unidad queda no aprobada y el curso **sigue** hasta la puerta | `prueba_unidad_repeticion_test.dart` |
| CA-5a-52 | **Las unidades cuentan para subir** (D-ING-14): con tres unidades aprobadas y una no, aunque la puerta se apruebe con todo lo demás cumplido, **no se sube** (T15, motivo `pruebas`); con las cuatro, sí; en la anticipada solo se exigen las ya presentadas antes del primer turno; una unidad aprobada en la repetición cuenta | `unidades_requisito_test.dart` |
| CA-5a-53 | **La mini prueba del viernes es de repaso:** reprobarla no bloquea la subida ni toca las unidades; el descenso por evidencia sigue usando solo mini pruebas | `mini_prueba_repaso_test.dart` |
| CA-5a-54 | **Segunda vuelta:** en un escalón que se repite, la forma `b` es la principal y la `a` la repetición | `prueba_unidad_vuelta_test.dart` |

**5b · Audio y habla** (sección 4)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5b-01 | **Sin audio:** con `disponibilidad` negativa, el traslado aparece como *«disponible cuando haya audio»* y no cuenta minutos, y la ubicación y las puertas **no se ofrecen**; el principal sí; el martes muestra el guion como texto marcado *sin audio*; la pantalla explica cómo instalar una voz | `audio_disponibilidad_test.dart` (motor falso) |
| CA-5b-02 | **Con audio:** cada uso pasa `UsoVoz.curso` y la `Variante` del contenido; la ubicación, las puertas y los simulacros usan `soloFuente` **congelada** y guardan `fuente_audio` y `variante_audio` en su fila | `audio_fuente_congelada_test.dart` |
| CA-5b-03 | **Reproducciones por contrato:** el curso llama `reproducir` exactamente el número que dice el contenido (traslado 2; ubicación 2; Cambridge 2; TOEIC 1) y no más | `reproducciones_test.dart` (fuente falsa que cuenta) |
| CA-5b-04 | **Guion oculto:** ningún evento de avance ni pantalla de pregunta contiene el texto del guion antes de contestar; en la ubicación, nunca | `guion_oculto_test.dart` |
| CA-5b-05 | **Grabar:** el permiso se pide solo al tocar *Grabar*; el tope es 1.5 veces el máximo de la etapa; 3 tomas en una tarea diaria, 1 en un turno de puerta (y una repetición si dura menos de la mitad del mínimo); el archivo queda en la carpeta privada | `grabacion_flujo_test.dart` (grabadora falsa) |
| CA-5b-06 | **La grabación no sale:** al entregar con IA activada, ninguna petición HTTP contiene bytes de audio ni la ruta del archivo; lo que viaja es **solo texto y solo tras el permiso de ese envío** (sin permiso, ninguna petición sale) | `grabacion_no_sale_test.dart` (cliente simulado) |
| CA-5b-07 | **Transcripción solo en el dispositivo** (P5-22, requisito D-ING-13): si el equipo no garantiza reconocimiento local (Android 12 o posterior, local disponible, paquete de inglés), **no se ofrece transcribir**, el habla pasa a autoevaluación y no va a la IA; en un turno de puerta el texto **no se edita**; en una tarea diaria, sí | `transcripcion_local_test.dart` (reconocedor falso) |
| CA-5b-08 | **Sin red en el audio:** ningún archivo de las pantallas y servicios de audio de `app/lib/modulos/habitos/ingles/` importa `package:http` ni usa `HttpClient`, `Socket` o `WebSocket` (la llamada de entrega a la IA vive en un archivo aparte) | Prueba de código fuente (como `app/test/diseno/guardia_sin_colores_fijos_test.dart`) |
| CA-5b-09 | **Retención y borrado:** las grabaciones de tareas diarias se borran a los 30 días (o al entregar, si así se eligió); las de puerta, 30 días después del veredicto; salir, la baja y quitar a la persona de la tablet las borran todas (`LimpiezaLocal.registrar`), y *Borrar mis datos* también | `limpieza_grabaciones_test.dart` |
| CA-5b-10 | **Sin micrófono** (Windows hoy): no se ofrecen las tareas de habla ni las puertas y se pide pasar al teléfono | `habla_sin_microfono_test.dart` |
| CA-5b-11 | **En el Galaxy A52** (V-b1 a V-b3 y V-b5 de 4.5): versión de Android, transcripción de 60 s en modo avión y si se puede grabar y reconocer a la vez; el resultado se anota | Manual (calidad), en `docs/revisiones/` |
| CA-5b-12 | **Dictado y transcripción sin red** (D-ING-13): con `HttpOverrides` que falla cualquier conexión y un reconocedor local falso, dictar una tarea diaria de escritura y transcribir un turno de habla producen texto y se guardan; **caso malo:** un reconocedor falso que intenta abrir una conexión hace fallar la prueba | `dictado_local_test.dart` y manual con modo avión (A52, V-b5) |
| CA-5b-13 | **Qué ve la persona sin garantía local:** Android 11, reconocimiento local no disponible, falta el paquete de inglés y *no probado* dan cada uno su mensaje de 4.4, **sin botón de micrófono** salvo el caso *no probado*; la tarea de habla pasa a autoevaluación; la puerta de habla no se ofrece en ese equipo; ningún mensaje contiene palabras de `MensajesHabitos.prohibidas` | `dictado_estados_test.dart` (comprobación nativa falsa) |
| CA-5b-14 | **Nunca cae a la nube:** la entrada de inglés llama a `listen` solo con `onDevice: true` y solo si la comprobación nativa dio *local*; una guardia de código fuente rechaza cualquier otra llamada a `SpeechToText` en `app/lib/modulos/habitos/ingles/` | `guardia_dictado_test.dart` |

**5c · Ubicación** (sección 5)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5c-01 | **Una sola ubicación por persona:** un segundo `INSERT` de la misma persona con **otro** `id` da 23505; con el mismo `id` y el mismo contenido no hace nada | `supabase/tests/<n>_ingles_ubicacion.sql` |
| CA-5c-02 | **Sin cambios ni borrado:** UPDATE, DELETE y TRUNCATE sobre `ing_ubicaciones` e `ing_ubicacion_respuestas` se rechazan para `authenticated` y `service_role` | SQL |
| CA-5c-03 | **Una respuesta por pregunta:** una segunda fila de la misma persona y pregunta se rechaza | SQL |
| CA-5c-04 | **Coherencia:** una ubicación con `etapa_alcanzada` A2 y `aciertos_a2` de 9, o con aciertos en una etapa no presentada, se rechaza | SQL (checks) |
| CA-5c-05 | **Forma de 48:** 4 etapas con 12 preguntas cada una, 6 de gramática y vocabulario, 3 de lectura (un texto) y 3 de escucha (un audio); la forma instalada tiene `uso: ubicacion` y fidelidad `completa` | `ubicacion_forma_test.dart` (sobre el contenido compilado de prueba) |
| CA-5c-06 | **Corte y parada** (los seis casos de 5.4): 10 de 12 alcanza y 9 no; la prueba termina tras la primera etapa no alcanzada y no pregunta las siguientes | `ubicacion_test.dart` |
| CA-5c-07 | **Tabla de entrada:** ninguna → A1.1; A1 → A2.1; A2 → B1.1; B1 → B2.1; B2 → B2.1 con derecho a la puerta inmediata | `ubicacion_test.dart` |
| CA-5c-08 | **Pausar y reanudar, no reiniciar:** cerrar la app a mitad y volver continúa en la primera pregunta sin responder; las reproducciones gastadas siguen gastadas; no hay *Atrás*; una respuesta confirmada no cambia; desde otro equipo se reanuda con las respuestas del servidor | `ubicacion_pantalla_test.dart` |
| CA-5c-09 | **Sin retroalimentación** (P5-21): no se dice si una respuesta fue correcta, no se muestra la etapa, el audio se oye hasta 2 veces y el guion nunca es visible | `ubicacion_pantalla_test.dart` |
| CA-5c-10 | **Acceso:** sin audio no se abre; con conexión comprueba que el servidor no tenga ya una ubicación y, si la tiene, muestra ese resultado y no ofrece la prueba | `ubicacion_acceso_test.dart` |
| CA-5c-11 | **No existe repetir ni reiniciar:** ninguna ruta, botón ni caso de uso crea otra ubicación cuando ya hay una | `sin_repetir_ubicacion_test.dart` (barrido de rutas y casos de uso) |
| CA-5c-12 | **Dos equipos sin red:** el segundo recibe 23505, **adopta la ubicación del servidor**, descarta la suya y lo dice sin culpa | `ubicacion_conflicto_test.dart` (servidor simulado: `app/test/nucleo/cola/postgrest_simulado.dart`) |
| CA-5c-13 | **Borrar todo permite otra:** tras `hab_borrar_datos_de(…, 'todo')` el `INSERT` de una ubicación pasa (P5-20) | SQL |
| CA-5c-14 | **Qué se guarda:** por pregunta, su id, la etapa y si acertó; en la fila, forma, huella, versión del contenido, fuente y acento; **no** la opción elegida ni el texto | `contrato_servidor_ingles_test.dart` |

**5d · Exámenes** (sección 6)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5d-01 | **La fidelidad sale solo del contenido:** con un JSON `reducida` la pantalla dice *Formato reducido* con sus `motivos`; con uno `completa`, *Formato completo*; ningún texto de las pantallas de inglés escribe «completo» ni «verificado» por su cuenta | `fidelidad_texto_test.dart` (más una guardia de cadenas) |
| CA-5d-02 | **Una puerta de etapa con forma reducida no se ofrece** y la pantalla dice que se está preparando | `puerta_fidelidad_test.dart` |
| CA-5d-03 | **Rótulo:** una forma reducida muestra marca de texto e icono, *Por qué es reducido* y la advertencia de 6.6 antes de empezar | Prueba de widget |
| CA-5d-04 | **Semáforo** (P5-25), en orden: sin intentos completos → gris; el más reciente con una prueba por debajo de 60 % → rojo; dos intentos de formas distintas con todo 80 o más en ambos → verde; lo demás → amarillo. Casos: ninguno, 85-90-78-95, dos formas con todo 80 o más, esas con un 58 en el habla más reciente, dos intentos de la misma forma, solo reducidas | `semaforo_test.dart` |
| CA-5d-05 | **Solo cuentan formas completas, en modo examen y con audio;** el intento de la puerta de A2.3 cuenta para el semáforo de A2 Key | `semaforo_test.dart` |
| CA-5d-06 | **Sin conversión a escalas oficiales:** no existe ninguna función ni pantalla que muestre un puntaje oficial de Cambridge, TOEIC o TOEFL | Guardia de código fuente y de cadenas |
| CA-5d-07 | **Práctica por partes:** de 1 a 12 unidades; primero las no hechas; las repetidas se marcan; no suma minutos, día completo ni constancia; no alimenta el semáforo | `practica_examen_test.dart` |
| CA-5d-08 | **Modo examen:** reloj de pared con el tiempo oficial; audio sin pausa ni 0.8; sin retroalimentación; no se reinicia; al volver con el tiempo agotado, la sección se cierra con lo contestado | `modo_examen_test.dart` (reloj simulado) |
| CA-5d-09 | **TOEIC y TOEFL son rutas opcionales:** se abren desde B1.2 y B2.1, no son puertas y no cambian la constancia, los minutos ni el escalón | `rutas_examen_test.dart` |
| CA-5d-10 | **Contrato con datos pendientes:** mientras `toefl-ibt-2026` los tenga, sus formas salen reducidas y su semáforo, gris | `semaforo_test.dart` sobre el contenido real |

**5e · Pareja y corrección con IA** (sección 7)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5e-01 | **Entregar una tarea escrita:** el texto queda **solo** en el dispositivo; la carga de `ing_entregas` en la cola no contiene el texto | `entrega_local_test.dart` |
| CA-5e-02 | **Lo que viaja a la IA** es una estructura cerrada (texto o transcripción de esa entrega, id de la rúbrica y escalón, y la marca del permiso de ese envío; sin permiso no se arma); no puede incluir campos de otros módulos, el nombre ni el correo, ni audio | `payload_ia_test.dart` (el tipo de la carga y una lista blanca de campos) |
| CA-5e-03 | **Ver una corrección:** se guardan los puntajes por criterio con su origen (`ia` o `auto`) en `ing_puntajes`; las observaciones, solo locales | `correccion_guardada_test.dart` |
| CA-5e-04 | **Interruptor apagado por omisión:** sin él no se ofrece enviar una entrega ni presentar una puerta | `correccion_interruptor_test.dart` |
| CA-5e-05 | **Arranque:** con `INGLES_ARRANQUE` apagada no hay *Tu punto de partida*, ni ubicación, ni sesión; encendida, sí | `arranque_ingles_test.dart` |
| CA-5e-06 | **Nada se comparte:** ninguna ruta, pantalla ni tabla de este bloque muestra datos de otra persona (con CA-5m-02) | Barrido de rutas y pruebas SQL |
| CA-5e-07 | **Entrega en espera sin red:** la petición se conserva y se reintenta; no pasa a *requiere atención* por falta de red | `entrega_sin_red_test.dart` |

**5m · Modelo de datos** (sección 8)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5m-01 | **Lo propio:** una persona no lee ni inserta filas de otra en ninguna de las doce tablas | SQL `<n>_ingles_rls.sql` |
| CA-5m-02 | **Nadie lee lo ajeno:** el dueño no lee lo de la pareja ni al revés; la cuenta maestra, el cuidador, la cuenta Hogar y `anon` no leen ni escriben nada; una persona dada de baja pierde el acceso | SQL `<n>_ingles_rls.sql` (como `89_habitos_rls.sql`) |
| CA-5m-03 | **Solo agregar:** UPDATE, DELETE y TRUNCATE sobre las diez tablas se rechazan para `authenticated` y `service_role` | SQL `<n>_ingles_solo_agregar.sql` |
| CA-5m-04 | **Borrado:** `hab_borrar_mis_datos('todo')` borra las doce; `hab_limpiar` las borra a los 90 días de la baja; los alcances `sensibles` y `diario` no las tocan; ningún otro camino borra | SQL `<n>_ingles_borrado.sql` |
| CA-5m-05 | **Bitácora:** ninguna tabla `ing_*` escribe en ella; `bitacora_agregar` rechaza una `tabla` con prefijo `ing_`; el dueño y la cuenta maestra no ven entradas de `ing_` | SQL (amplía `supabase/tests/30_bitacora.sql`) |
| CA-5m-06 | **Rangos y listas:** `desde` que no es lunes, `fecha` de sábado, `semana` 9, `aciertos` mayor que `preguntas`, `caja` 4, un `bloque` desconocido, una `entrada` desconocida, una `unidad` 5, un `intento` 3 y una `unidad` en un bloque que no es `prueba_unidad` se rechazan | SQL |
| CA-5m-07 | **Idempotencia:** mismo `id` y mismo contenido no inserta ni falla; mismo `id` con otro contenido da 23505 | SQL |
| CA-5m-08 | **Contrato de columnas:** la app no manda `persona_id`, `hogar_id` ni `recibido_en`; la tabla de columnas y la de niveles de la cola coinciden con las migraciones | `contrato_servidor_ingles_test.dart` (amplía `app/test/nucleo/cola/contrato_servidor_test.dart`) *(plataforma)* |
| CA-5m-09 | **Cuotas:** al pasar el tope de una tabla, el `INSERT` da `54000` | SQL |
| CA-5m-10 | **`ing_guardar_tarjetas`:** hasta 100 por llamada, idempotente, el último gana por `modificado_en`, rangos válidos; la app **no** puede escribir `ing_tarjetas` directo | SQL |
| CA-5m-11 | **Último cambio gana** en `ing_perfil`: un UPDATE con `modificado_en` más viejo se ignora; uno en el futuro lejano se ajusta | SQL |
| CA-5m-12 | **Listas cerradas iguales:** los escalones, entradas, bloques y tipos que usa la app son los de los `check` de las migraciones | `listas_cerradas_test.dart` (lee las migraciones) |
| CA-5m-13 | **Sin datos reales:** ningún archivo de prueba ni de ejemplo contiene nombres, correos ni claves reales | Revisión de calidad |

**5s · Sin conexión y sincronización** (sección 9)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-5s-01 | **Se estudia sin red:** con `HttpOverrides` que falla cualquier conexión, cada sub-bloque de la sesión del día se completa, deja su tramo en la base local y su registro en la cola | `sin_red_ingles_test.dart` |
| CA-5s-02 | **Todo por la cola:** cada escritura usa un tipo `habitos.ingles_*` con su tabla, función y nivel; ningún archivo de inglés llama `from('ing_…')` fuera del enviador de la cola | `cola_ingles_test.dart` y guardia de código fuente |
| CA-5s-03 | **Orden por niveles:** una sesión sube antes que sus bloques y un intento antes que sus puntajes; si algo llega antes que su dependencia (23503), se reintenta sin detener la ronda | `cola_ingles_test.dart` (servidor simulado) |
| CA-5s-04 | **Sin duplicar:** reenviar tras una respuesta perdida no crea una segunda fila | `cola_ingles_test.dart` |
| CA-5s-05 | **Dos equipos convergen:** la unión de repasos y tramos da el mismo estado en los dos; una ubicación o un ciclo en conflicto se resuelve con la fila del servidor | `sincronia_ingles_test.dart` |
| CA-5s-06 | **Contenido instalado:** el curso, las formas y la práctica se cargan de `app/assets/ingles/` sin red; una semana completa se estudia en modo avión | `assets_ingles_test.dart` y manual (A52) |
| CA-5s-07 | **La falta de red no manda a «requiere atención»:** un fallo de red se reintenta con la espera creciente de la cola | `cola_ingles_test.dart` |
| CA-5s-08 | **Tablet pública:** no hay tipos de inglés en su cola y no se ofrece el inglés | `ingles_por_rol_test.dart` *(plataforma)* |
| CA-5s-09 | **Todo lo de la tabla «sí» de 9.1 se completa sin red:** con `HttpOverrides` que falla cualquier conexión se hace una ubicación, una sesión de cinco días, tarjetas, una mini prueba, una prueba por unidad con su repetición, un turno de puerta y una práctica por partes; **caso malo:** un servicio que intente abrir una conexión hace fallar la prueba | `sin_red_ingles_test.dart` y manual con modo avión (A52) |
| CA-5s-10 | **La cola en modo avión:** tras 30 eventos sin red de todos los tipos, al volver la red suben por niveles y por orden de creación, sin duplicados; si se cierra la app a la mitad, nada se pierde y retoma al abrir | `cola_ingles_test.dart` (base local en archivo, servidor simulado) |
| CA-5s-11 | **Reintentos:** la espera sigue 5 s, 10 s, 20 s… con tope de 30 minutos; tras 20 fallas de red el evento pasa a *requiere atención* y tras 100 faltas de dependencia (23503) también; un rechazo del servidor pasa directo | `cola_ingles_test.dart` (reloj falso) |
| CA-5s-12 | **Entregas en espera:** sin red, la entrega queda *lista para enviar*; al volver la red **no sale sola**: pide el permiso de ese envío; sin permiso no sale ninguna petición | `entrega_lista_test.dart` |
| CA-5s-13 | **Listo para estudiar sin conexión** (P5-32): cada uno de sus cinco puntos refleja el estado real (voz ausente, dictado no verificado, contenido con otra huella, cola con eventos); lo pendiente trae su paso exacto y ningún texto usa palabras prohibidas | `listo_sin_conexion_test.dart` |
| CA-5s-14 | **Estados de conexión** (P5-33): sin conexión, por subir, necesita atención, lista para enviar, esperando corrección y contenido por actualizar muestran su texto de 9.7; ninguna pantalla de estudio muestra un cargando por la red | `estados_conexion_test.dart` |
| CA-5s-15 | **El curso completo está dentro de la app:** el índice compilado trae, para los 13 escalones, las 8 semanas, las puertas, las cuatro unidades con sus formas `a` y `b` y la práctica; una pieza ausente se lista; **caso malo:** quitar una forma hace fallar la prueba | `assets_ingles_test.dart` |
| CA-5s-16 | **Una descarga no deja nada a medias:** si se corta, el contenido anterior sigue sirviendo y no se queda un paquete incompleto (aplica a cualquier paquete que se agregue) | `descarga_ingles_test.dart` (red falsa que se corta) |

**Cómo se cuenta.** 5a: 54 · 5b: 14 · 5c: 14 · 5d: 10 · 5e: 7 · 5m: 13 · 5s: 16 · **128 en total.**

## 11. Cambios frente a la versión 0.4

**11.1 Punto por punto.** La versión 0.4 sigue en el historial de git (`git show HEAD:docs/specs/fase-8-habitos-ampliaciones.md`). Las cinco primeras filas son las contradicciones de **ING-I7** (`docs/revisiones/fase-8-ingles.md`, líneas 168 a 178); la sexta es su observación sobre la numeración de semanas.

| # | La versión 0.4 decía | La versión 0.5 | Fuente |
|---|---|---|---|
| 1 | **Tiempo diario:** *«unas 15 minutos al día»* y lecciones de 5 a 10 minutos | **60 minutos de lunes a viernes**: bloque principal de 35 y traslado de 25, con mínimos de contenido que una herramienta comprueba (3.2) | D-ING-2; ING-I7 (fila 1) y ING-B4 |
| 2 | **Punto de partida:** B1 → B2, tomado del Anexo A | **Ubicación de A1 a B2** y una escalera de **13 escalones** de 8 semanas (3.1, 5) | D-ING-1 y D-ING-5; ING-I7 (fila 2) y ING-B3 |
| 3 | **Prueba de nivel:** corta, para confirmar B1; *«se puede repetir después de 30 días»* | **Una sola vez**, 12 preguntas por etapa; el servidor impide una segunda; se corrige con la puerta anticipada y el descenso por evidencia (5, 3.7) | D-ING-5; ING-I7 (fila 3) y ING-B5 |
| 4 | **Exámenes simulados:** fuera del alcance | **Dentro** (5d): formas de las puertas con fidelidad calculada por la herramienta, práctica por partes, semáforo y rótulo de los reducidos | D-ING-1; ING-I7 (fila 4) y ING-B1 |
| 5 | **Audio:** fuera, falta decidir la fuente | **Dentro** (5b): las tres vías detrás del motor de voz; sin audio, la ubicación y las puertas no se abren | D-ING-3; ING-I7 (fila 5) e ING-I5 |
| 6 | **Numeración de semanas:** los módulos usan 1 a 24, el calendario de niveles 28 y la rúbrica cita las semanas 4, 8, 12, 16, 20 y 24 | **Una sola: semanas 1 a 8 dentro de cada escalón.** La semana de práctica no es la 9; el calendario global se deriva y nunca es una regla (2, 3.1) | ING-I7 (último párrafo); plan, P0.3 |
| 7 | **Ruta:** B1 → B2 con unidades temáticas y lecciones cortas (5 a 10 minutos) | Sesión por día y semana con siete sub-bloques (3.2); el temario sale de `data/ingles/niveles.yaml` | Plan 3.2 |
| 8 | **Repaso espaciado:** *«intervalo creciente según acierto»*, sin algoritmo | Tres cajas (1, 5 y 20 días de estudio), tres calificaciones, cola de 40 y 8 tarjetas nuevas de lunes a jueves; una escalera larga **no cabe** en 5 minutos (3.5) | P5-06; `gravity-sesion-60.yaml` |
| 9 | **Métricas:** palabras aprendidas, minutos, racha y precisión por unidad | Minutos acreditados, día completo, asistencia, racha propia con tres faltas por escalón, metas semanales, porcentaje por habilidad y mini pruebas (3.3, 3.4, 3.8) | `niveles-y-avance.md`, secciones 4 y 5 |
| 10 | **Sin conexión:** *«el progreso se guarda local y se sincroniza como el resto de Hábitos»* | Todo por la cola con tipos `habitos.ingles_*`. **Hallazgo:** el resto de Hábitos escribe directo, no por la cola (9.2) | `repositorio.dart:49-77`; `arranque.dart:120` |
| 11 | **Regla:** *«no se envía a ningún servicio de IA en esta etapa; sin llamadas de red para estudiar»* | Estudiar sigue sin red. La **escritura y el habla de las puertas** las corrige una IA, opcional por función, y el curso no arranca hasta que esté integrada (7) | D-ING-9 y D-ING-10 |
| 12 | **Conversación guiada y redacciones corregidas con IA:** después de la Fase 6 | La conversación guiada del viernes es un **guion sin IA** (P5-17); la corrección con IA de las tareas de las puertas es 5e y P6.0 | D-ING-9 |
| 13 | **Pareja:** el progreso es privado; el reto con la pareja, para un bloque posterior | Igual: **nada se comparte** hasta P6.0 (7.2) | Plan 3.7 |
| 14 | **Datos:** `ing_unidades`, `ing_lecciones`, `ing_tarjetas`, `ing_sesiones` e `ing_prueba`, con RLS por persona y solo agregar en sesiones y pruebas | **Doce tablas** `ing_*`; el contenido ya no vive en tablas sino compilado en `app/assets/ingles/`; la ubicación es única por persona (8) | Plan 3.6; D21 |
| 15 | **Racha y área:** ¿hábito de Hábitos o área aparte? Propuesta: área propia con su racha | **Racha propia** con 3 faltas por escalón (la 0.5 decía 3 gracias por trimestre), fuera de la racha global (P5-19, P5-30) | `niveles-y-avance.md`, sección 5 |
| 16 | **Criterios de aceptación (borrador):** cinco, entre ellos *«la prueba de nivel … se puede repetir después de 30 días»* y *«una lección de 5 a 10 minutos»* | **128 numerados**, cada uno con su prueba (10) | Plan P0.3 |
| 17 | **Cinco preguntas al dueño** (alcance, quién escribe el contenido, lecciones por semana, repaso diario, área propia) | Respondidas o superadas por D29: 1 (alcance), superada porque el alcance es mayor; 2 (quién escribe), por D-ING-4; 3 (lecciones por semana), **5 días de 60 minutos**; 4 (repaso diario), repaso diario con recordatorio opcional (P5-18); 5 (área propia), racha propia (P5-19) | D29 |
| 18 | **Cabecera:** *«módulos 1 y 2 aprobados; módulo 3 en revisión; rúbrica en revisión»* | Los módulos son semilla de B1.1 y B1.2 y la rúbrica se ajusta (14); el contenido se aprueba por muestras (D-ING-4) | Plan 7 |

**11.2 Cómo se resolvió cada punto de «Para P0.3»** (`docs/contenido/ingles/niveles-y-avance.md`, sección 8, y plan 4.2, último párrafo)

| Punto pendiente | Resolución | Dónde |
|---|---|---|
| Qué pruebas intermedias lleva el escalón (hoy ninguna) | **Cuatro pruebas por unidad que bloquean** (D-ING-14); la 0.5 proponía ninguna (P5-08) y se **retiró** | P5-31, 3.6.1; pregunta 3 |
| Qué más cuenta una mini prueba fallida (0.3: *se repite la semana*; rúbrica: *los errores vuelven como tarjetas*) | **Los errores vuelven como tarjetas**, siempre; **no se repite la semana**; no gasta faltas; menos de 50 % cuenta para el descenso | P5-07, 3.6 |
| Si la puerta cuenta dentro de las 40 horas y cómo se reparte en sesiones | **Sí cuenta** (plan 4.2). Se reparte en turnos de hasta 90 minutos en los últimos días de la semana 8 | P5-15, 3.7.7 |
| Qué semana y con qué forma se usa la puerta anticipada | **Semana 2**, una vez por ciclo, con la forma de **reserva** | P5-11, 3.7.8 |
| Cómo se aplica el 90 % a escritura y habla | **360 o más sobre 400**; *gramática del tema ≥ 3* queda implícita por los pesos | 3.7.8 |
| Qué asistencia y unidades se piden a quien pasa por ella | Los **mismos umbrales sobre lo cursado** hasta ese día | P5-11, 3.7.5 y 3.7.8; pregunta 6 |
| Cuándo se usa la forma de reserva | **Anticipada**, reemplazo de una forma retirada y repetición de un escalón | P5-12, 3.7.11 |
| Si el descenso por evidencia cuenta como una de las dos bajas seguidas | **No cuenta** | P5-09, 3.7.9–3.7.10 |
| Qué es un trimestre | **Ya no hay trimestre**: D-ING-12 cuenta por escalón (P5-01 retirada) | P5-30, 3.4 |
| Crédito parcial | **No hay** en lo objetivo | P5-16, 3.7.1 |
| Estructura de la conversación guiada del viernes | **Guion de 8 turnos** con modelo, variantes y cotejo, sin IA, 60 segundos por turno | P5-17, 3.2 |
| Cómo se cuentan «día completo» y el 90 % mientras la app no tenga audio | **Solo el principal**: 35 minutos planeados por día y día completo con los cuatro sub-bloques; el resto, respaldo | P5-04 y P5-05, 3.3 |
| Si las 3 preguntas de lectura y las 3 de escucha de la ubicación comparten un texto y un audio | **Sí**, y el audio se oye dos veces | P5-21, 5.2 |
| Contradicciones de ING-I7 y numeración de semanas | Tabla 11.1, filas 1 a 6 | 11.1 |

**11.3 Cambios de la versión 0.5 a la 0.6** (17/nov/2026; decisiones del dueño D-ING-12 a 15, `docs/DECISIONES.md:570-571`, plan 4.1, y `docs/specs/fase-8-habitos-pareja-y-correccion.md` 0.2)

| # | La versión 0.5 decía | La versión 0.6 | Fuente |
|---|---|---|---|
| 1 | **90 % de los minutos** del ciclo (con enteros) y **tres días de gracia por trimestre**, con trimestres de 13 semanas (P5-01, P5-02) | **Asistencia:** hasta 10 minutos de faltante por día y a lo más tres días faltados por escalón; al cuarto, el escalón se repite. **Se retira el trimestre**, la gracia y el 90 % (P5-30) | D-ING-12; 3.3 y 3.4 |
| 2 | **Un día incompleto** (11 de 12 elementos) solo se cubría con un día de gracia | Es **asistido** si faltan 10 minutos o menos; `completo` sigue siendo estricto para el anillo | D-ING-12; 3.3 |
| 3 | **Ninguna prueba intermedia que bloquee** (P5-08) | **Cuatro pruebas por unidad** que cuentan para subir (P5-31); el viernes sigue siendo de repaso | D-ING-14; 3.6.1 |
| 4 | Requisitos para subir: puerta, constancia y minutos (el 1.º cubierto por el 2.º) | **Cuatro propios:** unidades, puerta, constancia (≤ 3 faltas) y minutos (≤ 10 por día) | D-ING-12 y 14; 3.7.4 |
| 5 | **Sin conexión:** una lista corta y la cola | Sección 9 completa: qué se estudia sin red, qué la necesita, orden y reintentos verificados en la cola, **instalación por adelantado**, estados visibles y criterios de modo avión | D-ING-13; 9 |
| 6 | **Dictado y transcripción:** condición de P5-22, sin requisito de red ni mensajes | **Requisito de 5b:** funcionan sin red; si el equipo no garantiza el modo local, la persona ve qué hacer (tabla de 4.4); hallazgo sobre `speech_to_text` completado | D-ING-13; 4.4 |
| 7 | Texto, transcripción y voz: **solo en el dispositivo** (salvo lo que decidiera P6.0) | **Texto y transcripción pueden ir a la IA con permiso en cada envío y el filtro de D3; la voz nunca sale** | D-ING-15; R4, 4.4 y 7.1 |
| 8 | Un interruptor `correccion_ia` | Dos: `correccion_ia_escritura` y `correccion_ia_habla` | P6-16 de P6.0; 7.1, 8.2 |
| 9 | Una entrega sin red *se reintentaba al volver la red* | Queda *lista para enviar* y **no sale sola**: se pide permiso otra vez | D-ING-15; 7.1, 9.1 |
| 10 | Modelo `ing_bloques` sin pruebas por unidad | Bloque `prueba_unidad` con `unidad`, `intento` y `forma_id`; sin tabla nueva | 3.6.1, 8.2 |

## 12. Decisiones que ya están tomadas

Nada de esta lista se cambia aquí. Donde una propuesta de esta versión toca una de ellas, dice cómo la cumple, no cómo la cambia.

| Decisión | Fuente | Dónde se aplica |
|---|---|---|
| **D-ING-1:** escalera de 13 escalones de 8 semanas y 40 horas; la etiqueta se gana en la puerta de la etapa (A2 Key, B1 Preliminary, B2 First) a las 200, 360 y 520 horas; subir solo si se cumple todo; **dos oportunidades** por puerta y, si no se aprueba ninguna, **se baja un escalón** | `docs/DECISIONES.md:560`; plan 3.1 y 4.1 | 3.1, 3.7 |
| **D-ING-2:** la hora diaria se llena con práctica, con **mínimos de contenido**; mientras la app no tenga audio, **solo cuenta el bloque principal (35 min)** y el 90 % se calcula sobre eso | `docs/DECISIONES.md:561`; plan 4.1 | 3.2, 3.3 |
| **D-ING-3:** las tres vías de audio y el motor de voz de GRAVITY | `docs/DECISIONES.md:562`; plan 3, fase 3 | 4 |
| **D-ING-4:** el dueño aprueba plantillas y muestras | `docs/DECISIONES.md:563` | Contenido; no es de la app |
| **D-ING-5:** ubicación **única** de 12 preguntas por etapa (6 + 3 + 3), 10 de 12 y todas las anteriores; **puerta anticipada** en la semana 2 con 90 % por habilidad sin gastar oportunidades; **descenso por evidencia** con dos mini pruebas seguidas por debajo de 50 % | `docs/DECISIONES.md:564`; plan 3.3 | 3.7.8, 3.7.9, 5 |
| **D-ING-6:** aprobar escritura y habla es promedio ponderado de 80 % y «gramática del tema» en 3 o más de 4; las pruebas objetivas llevan 10 preguntas o más por habilidad | `docs/DECISIONES.md:565`; plan 4.1 | 3.7.1 |
| **D-ING-7:** el curso arranca por A2.1 y la ubicación | `docs/DECISIONES.md:567` | Orden de producción; no es de la app |
| **D-ING-8:** borrar dos ramas (sin ejecutar) | `docs/DECISIONES.md:569` | No aplica |
| **D-ING-9:** la escritura y el habla de las puertas las corrige una **IA, opcional por función**; D3, D21 y la clave fuera de la app se mantienen | `docs/DECISIONES.md:568`; plan 3.8 | 3.7.13, 7 |
| **D-ING-10:** el curso **no arranca** hasta que la fase 6 esté integrada; **ninguna etiqueta provisional** | `docs/DECISIONES.md:568`; plan 4.1 | 3.7.13, 7.3 |
| **D-ING-11 (coordinador, tras esta redacción):** si la persona no activa la IA, la escritura y el habla de la puerta van a la pareja y a la IA, o esperan a que la IA se active; lectura y escucha siguen; no hay autocalificación | Mensaje del coordinador del 16/nov/2026; aún no figura en `docs/DECISIONES.md` | 3.7.13, 7.1, 7.2 |\n| **Plan 4.2:** la puerta de etapa **es** la del último escalón (13 puertas, 39 formas); primera oportunidad al final de la semana 8; fallar las dos en A1.1 repite A1.1 y la segunda caída seguida lleva a revisar el plan; bajar a un escalón de cierre conserva la etiqueta; la puerta cuenta dentro de las 40 horas; B1+ no se otorga; los 35 minutos solo de respaldo | Plan, sección 4.2 | 3.7.12 (una fila por caso) |
| **D-ING-12:** solo se pueden faltar **10 minutos por día** y **3 días completos**; pasado eso no se completa el curso y se repite (**lectura mía, a confirmar:** el escalón) | `docs/DECISIONES.md:570`; plan 4.1 | 3.3, 3.4, 3.7.4, 3.7.5; pregunta 9. En la práctica reemplaza al 90 % de minutos y a los días de gracia por trimestre de D-ING-2 y de las reglas anteriores (lectura mía, pregunta 9c) |
| **D-ING-13:** estudiar **sin conexión debe funcionar completo**; el **dictado funciona en modo local** | `docs/DECISIONES.md:570`; plan 4.1 | 4.4, 9 |
| **D-ING-14:** el examen del viernes es **de repaso**; el escalón lleva **pruebas por unidad que cuentan para subir** | `docs/DECISIONES.md:570`; plan 4.1 | 3.6, 3.6.1, 3.7.4, 8.2 |
| **D-ING-15:** el texto escrito lo corrige una **IA en la nube**, sin tiempo real, **con permiso en cada envío** y el filtro de D3; el habla es una **conversación con la IA** que empieza por texto (el teléfono transcribe, solo el texto va a la IA); **la grabación de voz se queda en el dispositivo**; matiza D-ING-13 | `docs/DECISIONES.md:571`; plan 4.1 | R4, 4.4, 7.1 |
| **Reglas del dueño vigentes:** 60 minutos de lunes a viernes; un día completo es principal más traslado; **tres días de gracia por trimestre, sin acumularse** y los cuatro requisitos para subir (pruebas, evaluación de cierre, constancia y 90 % de minutos), **que D-ING-12 y D-ING-14 precisan en la 0.6**: tres días faltados por escalón y 10 minutos por día en lugar de la gracia y del 90 %, y pruebas por unidad en lugar de «pruebas» sin definir (lectura mía, preguntas 3 y 9); *«si pierdes un día, no se recupera con dos bloques seguidos»* | `docs/contenido/ingles/niveles-y-avance.md`, secciones 4 y 5; `CONTEXTO.md` | 3.3, 3.4, 3.7.4 |
| **D3:** nada de dinero ni datos clínicos a la IA en la nube; el modelo no ve cifras | `docs/DECISIONES.md:77-87` | R1, 7.1 |
| **D5 y D21:** Hábitos es personal; la cuenta maestra no lo lee; las tablas `hab_*` no escriben en la bitácora; la tablet personal funciona como el teléfono y la pública no muestra Hábitos | `docs/DECISIONES.md:111-142` y `:470-480` | R2, R3, 3.8, 8.3 |
| **D13:** dos modos para lo sensible (nube cifrada o solo teléfono); el inglés no es de esos dos tipos, y lo que no sale del dispositivo no sale | `docs/DECISIONES.md:291-302` | 7.1 |
| **D1 y D10:** una sola app y todo en el repositorio GRAVITY | `docs/DECISIONES.md:38` y `:243` | El módulo vive en `app/lib/modulos/habitos/` |

## 13. Propuestas de esta versión

Todo lo que esta versión resuelve por su cuenta, en un solo lugar, para que el dueño pueda **vetar** cualquiera. Si veta una, lo que cambia es lo de la última columna; el resto del documento sigue en pie.

| # | Propuesta | Dónde | Si se veta |
|---|---|---|---|
| P5-01 | ~~Un trimestre son 13 semanas~~ **Retirada en la 0.6:** D-ING-12 cuenta por escalón | 3.4 | Volver a trimestres si el dueño conserva los días de gracia (pregunta 9c) |
| P5-02 | ~~La app cubre con gracia los tres primeros días~~ **Reemplazada** por P5-30: los tres primeros días faltados del ciclo quedan tolerados, solos y en orden | 3.4 | La persona elige qué días cubrir (un toque más) |
| P5-03 | Un escalón empieza el primer lunes posterior al cambio | 3.1 | Empezar el mismo día, con una primera semana parcial |
| P5-04 | Planeados: 60 min por día, o 35 si todos los bloques del día fueron sin audio. Acreditados: proporcionales a lo hecho, en segundos | 3.3 | Medir por reloj, o todo o nada por sub-bloque |
| P5-05 | Día completo es todo; la fecha es la de inicio del bloque; una sesión pasada se estudia libre y no suma | 3.2, 3.3 | Una tolerancia (por ejemplo, 90 % de los elementos) |
| P5-06 | Repaso: tres cajas (1, 5 y 20 días de estudio), tres calificaciones, cola de 40 | 3.5 | Menos tarjetas nuevas o más tiempo de repaso (pregunta 5) |
| P5-07 | Los errores de una mini prueba vuelven como tarjetas; no se repite la semana; no toca la constancia | 3.6 | Repetir la semana: mueve la puerta y los minutos (pregunta 3) |
| P5-08 | ~~El escalón no lleva pruebas intermedias~~ **Sustituida** por P5-31 (D-ING-14) | 3.6.1 | — |
| P5-09 | El descenso por evidencia se cuenta dentro de un ciclo, no es una caída y en A1.1 no hace nada | 3.7.9 | Contarlo como caída |
| P5-10 | Dos caídas seguidas detienen el curso hasta que la persona confirma que revisó su plan; no se avisa a nadie | 3.7.10 | Avisar al dueño con consentimiento (pregunta 4) |
| P5-11 | Anticipada: semana 2, una vez por ciclo, forma de reserva, 90 % (360 de 400), asistencia y unidades de lo cursado; puerta inmediata de B2 como anticipada de B2.4 | 3.7.8 | Basta el 90 % por habilidad (pregunta 6) |
| P5-12 | Forma que toca: la anticipada usa la reserva; las oportunidades, la primera no presentada; con las tres vistas, la de hace más tiempo | 3.7.11 | Un cuarto juego de formas (13 más) |
| P5-13 | Se sube con unidades, puerta, constancia y minutos; con la puerta aprobada y sin uno de los otros, el escalón se repite; la etiqueta se gana con la puerta | 3.7.4 | Extender el escalón por semanas completas (pregunta 2) |
| P5-14 | La semana de práctica se arma con sesiones del escalón según la habilidad no alcanzada | 3.7.6 | Contenido propio de práctica |
| P5-15 | Turnos de hasta 90 minutos sin partir una sección; el día de un turno acredita 60 | 3.7.7 | Otro reparto de las secciones |
| P5-16 | Sin crédito parcial en lo objetivo | 3.7.1 | Un 0.5 que alguien tendría que decidir |
| P5-17 | Conversación guiada del viernes: guion de 8 turnos con modelo, variantes y cotejo, sin IA | 3.2 | Otra estructura, o IA en vivo después de P6.0 |
| P5-18 | Recordatorio local `hab_ingles`, apagado por omisión | 3.8 | Sin recordatorio, o encendido por omisión |
| P5-19 | El inglés tiene su propia racha (días asistidos o tolerados) y no entra a la racha global | 3.4 | Contar el día asistido como un elemento más de la global |
| P5-20 | *Borrar mis datos › todo* borra también el inglés y la ubicación | 5.6 | Conservar la ubicación (no cabe con el derecho a borrar de D21) |
| P5-21 | Ubicación: un texto con 3 preguntas y un audio con 3 que se oye dos veces; sin cronómetro ni retroalimentación; respuestas de una en una al servidor; comprobación al empezar si hay red | 5.2, 5.3 | Tres textos y tres audios, una reproducción, o con retroalimentación |
| P5-22 | La transcripción y el dictado son solo en el dispositivo y funcionan sin red (D-ING-13), comprobados antes con una verificación nativa y una prueba de modo avión; si no se puede garantizar, el habla pasa a autoevaluación y la persona ve qué hacer | 4.4 | Permitir reconocimiento en la nube (rompe D-ING-13 y D-ING-15) |
| P5-23 | Grabaciones: carpeta privada, fuera de la copia de Android, 30 días (o hasta 30 días tras el veredicto en una puerta) | 4.3 | Otra retención |
| P5-24 | Sin la IA activada, escritura y habla de la puerta esperan (pareja e IA, o activación; D-ING-11) y lectura y escucha siguen; sin autocalificación; mientras falte, no hay veredicto; `INGLES_ARRANQUE` apagada impide empezar el curso | 3.7.13, 7.3 | Una etiqueta provisional (D-ING-10 la prohíbe) |
| P5-25 | Semáforo por tabla de cuatro condiciones, solo con formas completas, en modo examen y con audio; la práctica por partes no suma | 6.4, 6.5 | Otra regla de colores |
| P5-26 | El inglés no se ofrece en la tablet pública | 3.8 | Permitirlo con nombre y PIN |
| P5-27 | Metas semanales (5 días, 300 minutos, 60 repasos) informativas | 3.3 | Que alguna bloquee |
| P5-28 | El escalón actual y las etiquetas se calculan; no se guardan | 3.1 | Una columna `escalon_actual` y una función que valide transiciones |
| P5-29 | Puerta de escalón: 2 textos × 5 preguntas, 2 audios × 5 preguntas, una tarea de escritura y una de habla, en 60 minutos o menos | 6.2 | El contrato `gravity-escalon` sigue pendiente y no hay puertas de escalón |
| P5-30 | **Asistencia:** hasta 10 minutos de faltante por día; a lo más 3 días faltados por escalón (día entero, sin crédito parcial); al cuarto el escalón se repite; reemplaza al 90 % de minutos y a los días de gracia por trimestre | 3.3, 3.4 | Solo cuenta lo que falta, con un tope de 180 minutos (pregunta 9b); o conservar los días de gracia por trimestre además (9c) |
| P5-31 | **Pruebas por unidad:** cuatro por escalón (viernes de las semanas 2, 4, 6 y 7), 20 preguntas objetivas (15 sin audio), 80 %, una repetición el lunes siguiente con forma de reserva, sin tabla nueva (`ing_bloques`); si no se aprueban, no se sube | 3.6.1, 8.2 | Dos pruebas por escalón, o una sola forma por unidad (pregunta 3) |
| P5-32 | **Instalar por adelantado:** el curso viaja dentro de la app; la pantalla *Listo para estudiar sin conexión* revisa contenido, voz, dictado local, micrófono y lo que falta por subir; las descargas son con aviso y no dejan nada a medias | 9.6 | Descarga automática con Wi-Fi |
| P5-33 | **Estados de conexión** con textos cerrados, sin cargando por la red; una entrega queda *lista para enviar* y no sale sola | 9.7 | Reenviar solo al volver la red (rompe el permiso por envío de D-ING-15) |

**Revisión contra las decisiones.** El autor revisó esta lista contra `docs/DECISIONES.md` (D3, D5, D13, D21 y D29, con D-ING-11 a D-ING-15) y contra el plan 0.6 (secciones 3, 4.1 y 4.2), a mano y con un script (cifras, citas de línea y numeración de criterios). Ninguna propuesta cambia una decisión confirmada: las que parecían rozar una (la anticipada de B2, el descenso frente a las bajas seguidas, el 35 de respaldo) **la cumplen con una lectura explícita** que está en su sección. La revisión de calidad la repite.

## 14. Pedidos a otras áreas

Esta especificación escribe en un solo archivo. Lo que necesita de otras áreas y de otros paquetes de `habitos` se pide aquí.

| Área | Pedido | Sección |
|---|---|---|
| **backend** (P2.2) | Migración con las **doce tablas** `ing_*` de 8.2 (columnas, tipos, llaves compuestas, `check` de rango, lista y coherencia, único parcial); `ing_propio()` y el solo agregar con **variante para el borrado** de las dos funciones (nota de 15: sin esto, «Borrar mis datos» falla); `ing_bloques` con `prueba_unidad`, `unidad`, `intento` y `forma_id` (8.2); idempotencia estricta; cuotas | 8.2, 8.3 |
| **backend** | `ing_guardar_tarjetas(p_tarjetas jsonb)`; ampliar `hab_borrar_datos_de` y `hab_limpiar` a las doce tablas; **reservar el prefijo `ing_`** en `bitacora_agregar` y en `puede_ver_entrada_bitacora`; aceptar `hab_ingles` en `avisos_actualizar_preferencias` | 8.3, 8.4 |
| **backend** | Pruebas SQL de CA-5c-01 a 04 y 13 y de CA-5m-01 a 11; entrada en `supabase/README.md` (qué ve y qué no ve el servidor; columnas que pone el servidor) | 10 |
| **plataforma** | **Tablas locales** espejo de las doce y migración de `BaseLocal` (hoy solo `Pendientes`, `schemaVersion` 3) | 9.3 |
| **plataforma** | Tipos `habitos.ingles_*` en `tablasDeLaCola` y `funciones`, sus niveles de subida y `columnasQuePoneElServidor`; ampliar `contrato_servidor_test.dart` | 9.2 |
| **plataforma** | `LimpiezaLocal.registrar` para las filas locales y las grabaciones; carpeta privada; **grabaciones fuera de la copia automática de Android**; el servicio en primer plano del traslado (P3.2b) | 4.3, 9.3 |
| **plataforma** | Bandera de compilación **`INGLES_ARRANQUE`** (apagada) en `ConfiguracionEntorno`; recordatorio local `hab_ingles` con sus acciones; rutas `ingles/…` y `Ajustes › Inglés`; el inglés fuera de la tablet pública | 3.8, 7.3 |
| **plataforma** y **dueño** | Los **paquetes de grabación y de transcripción** los evalúa P3.2b y los aprueba el dueño; nada se agrega en esta versión | 4.3, 4.4 |
| **plataforma** | **Comprobación nativa del reconocimiento local** (`SpeechRecognizer.isOnDeviceRecognitionAvailable`, Android 12 o posterior, y paquete de inglés instalado) detrás de una interfaz, para que el dictado y la transcripción de inglés la usen; el resultado de la prueba de modo avión se guarda en el dispositivo | 4.4, 9.6 |
| **asistente** | `habitos.ingles_hoy` (`soloLocal`, solo lectura) y la orden de abrir inglés; OpenAPI de lo nuevo (P2.5); en el motor de voz, lo que pide 4.2 (fuente congelada y registrada) | 3.8, 4.2 |
| **asistente** | La corrección con rúbrica en `supabase/functions/gravity-asistente`, con el filtro de D3 (P6.2): fuera de esta versión | 7 |
| **diseno** | Componentes: anillo de la sesión, barra de requisitos (unidades, puerta, faltas y minutos), cinta de conexión y pantalla *Listo para estudiar sin conexión*, tarjeta de repaso que se voltea con tres botones, línea de escalones, marca de fidelidad con texto e icono, semáforo de examen; estados vacío, sin conexión y error | 3.8, 6 |
| **habitos** (formato 0.5, P1.2c) | El bloque **`mini_prueba`** que referencia una forma de uso `mini`; el bloque **`conversacion`** con sus campos (P5-17); la estimación de minutos de ambos; velocidades por contrato si P3.1 las quiere | 3.2, 3.6 |
| **habitos** (`compilar`) | `indice.json` con versión y huella, lista de formas retiradas, `fidelidad.motivos`, la **oportunidad** (A, B o C) de cada forma, minutos y `papel` por sección, `huella_guion` | 6.1, 8.5 |
| **habitos** (contratos) | `gravity-ubicacion.yaml`: aplicar P5-21 (un texto y un audio con 3 preguntas, `reproducciones: 2`, retirar los `pendiente` de lectura y escucha). `gravity-sesion-60.yaml`: las cifras de asistencia (10 minutos por día, 3 días faltados por escalón). `gravity-escalon.yaml`: P5-29, P5-12, P5-11, P5-07 y P5-31 (bloque `prueba_unidad`: 4 por escalón, formas `a` y `b`, 20 preguntas, 15 sin audio, 80 %; y minutos 13.3 de la Lección del viernes), y retirar la nota de quién califica (D-ING-9). Una comprobación V27 de que una forma de escalón estime 60 minutos o menos | 5.2, 6.2 |
| **habitos** (rúbrica) | `rubrica-evaluacion.md`: mini pruebas de 10 preguntas y 8 de 10; sin pruebas de módulo; **sin crédito parcial**; la extensión es la de la etapa y la regla del 1 en coherencia para un texto corto; la autoevaluación del habla ya no decide (D-ING-9) | 3.7.1 |
| **habitos** (`niveles-y-avance.md` 0.5) | El requisito 1 son las pruebas por unidad (D-ING-14); ya no hay trimestre (D-ING-12); las mini pruebas son de repaso; las dos bajas seguidas | 3.4, 3.6, 3.6.1 |
| **calidad** | Revisar esta especificación contra `DECISIONES.md` y el plan; hacer las mediciones V-b1 a V-b5 en el Galaxy A52; verificar las escalas oficiales antes de cualquier conversión; **comprobar que `cola_hab_test.dart` (Fase 3, criterio 10) no existe** | 4.5, 6.4, 9.2 |
| **arquitecto** | Registrar como **decisión nueva (propuesta D30)** las propuestas P5-01 a P5-29 que el dueño apruebe; fila de P0.3 en el control de cambios del roadmap; lanzar **P2.2 y P2.3** (dependían de esta especificación); decidir cuándo se enciende `INGLES_ARRANQUE` | 13, 7.3 |

## 15. Preguntas para el dueño

> **Respondidas el 17/nov/2026 (D-ING-16):** la 3 (cuatro pruebas por unidad, versión completa) y la 9 (a: repetir el curso es repetir el escalón; b: un día con más de 10 minutos faltantes cuenta como día faltado entero; c: los 3 días valen por escalón y reemplazan a los de trimestre). Las demás siguen abiertas.

Solo las que de verdad cambian el diseño. Cada una trae mi recomendación. **Si no respondes, vale lo que dice el documento**, que coincide con la recomendación salvo en la pregunta 1 (hoy no hay pausas, sección 1.2). Las preguntas 8 y 9 son nuevas de esta versión: salen de D-ING-12 y D-ING-14.

| # | Pregunta | Por qué cambia el diseño | Recomendación |
|---|---|---|---|
| 1 | **Vacaciones y enfermedad.** ¿Admite el curso pausas que no cuenten como días faltados? Hoy solo las **tres faltas por escalón** (3.4) cubren un día sin estudiar: una semana de enfermedad las agota y el escalón se repite (T15) | Agrega una tabla `ing_pausas` (con los motivos de `hab_pausas`: descanso, viaje, salud, otra) y un parámetro en 3.3 y 3.4: un día en pausa no cuenta ni como día de estudio ni en los minutos planeados | **Sí, con tope** (por ejemplo, 10 días de estudio por escalón). Tú decides el tope. Mientras no respondas, no hay pausas |
| 2 | **Puerta aprobada, pero sin las pruebas por unidad, la asistencia o los minutos.** Dijiste que entonces no se sube. ¿Qué pasa? Propongo que **el escalón se repite** (con la puerta anticipada de la semana 2 como atajo) y que la etiqueta de la etapa queda ganada | Define T15. La alternativa es alargar el escalón con semanas completas; las faltas no se pueden recuperar | **Repetir el escalón** |
| 3 | **Pruebas por unidad (D-ING-14).** Propuse **cuatro por escalón** (viernes de las semanas 2, 4, 6 y 7), de **20 preguntas objetivas** con umbral del **80 %**, **una repetición** el lunes siguiente con una forma de reserva y, si tampoco se aprueba, el escalón se repite aunque se apruebe la puerta (3.6.1). ¿Te parece bien la medida? ¿Y que una unidad fallida **no corte** el estudio hasta la puerta? | Pide **8 formas por escalón y unas 2 080 preguntas** en total (3.6.1): es una carga de contenido que el plan no tenía contada | **Sí a lo propuesto.** Si la carga es demasiada: **dos pruebas por escalón** (semanas 4 y 7) o una sola forma por unidad. Y tu decisión del 14/nov *«la primera evaluación semanal fallida queda como día de gracia»* **se retira**: no hay días de gracia (pregunta 9) y ninguna mini prueba gasta faltas |
| 4 | **Dos caídas seguidas en otra persona.** Si tu pareja o un familiar llega a dos caídas seguidas, la regla dice que *el dueño revisa el plan*; pero Hábitos es personal y no puedes leer lo suyo (D21). ¿Cómo te enteras? | Cambia 3.7.10 y lo que defina P6.0 sobre consentimiento | La app **no avisa a nadie**; la persona lo ve y lo habla contigo si quiere. P6.0 puede añadir un aviso **con su consentimiento** |
| 5 | **Cuántas tarjetas y cuántos repasos.** Con 32 tarjetas nuevas a la semana, un repaso de 5 minutos solo sostiene **tres repasos por tarjeta** (a 1, 5 y 20 días de estudio). Más repasos por tarjeta (más memoria a largo plazo) exigen menos tarjetas nuevas (por ejemplo, de 8 a 5 al día) o más tiempo de repaso | Cambia 3.5 y los mínimos del contenido (8 por sesión) | Dejar las tres cajas y **medir en el piloto de A2.1** antes de tocar el contenido |
| 6 | **Puerta anticipada: ¿también asistencia y unidades?** Quien se ubicó bajo y presenta la puerta en la semana 2 ¿debe haber cumplido la asistencia y las unidades ya presentadas, o basta con el 90 % en cada habilidad? | Cambia T08 y 3.7.5 | **Sí piden lo mismo**, sobre lo cursado: quien no estudia no demuestra nada |
| 7 | **Lo que escribes, lo que dices y tu voz, en el dispositivo.** D-ING-15 ya permite que **el texto y la transcripción** vayan a la IA con permiso en cada envío; la grabación nunca sale. Lo que queda por decidir: ¿aceptas que los textos, las transcripciones y las grabaciones **no se vean en la laptop ni se respalden en la nube de GRAVITY**? | La alternativa es un tercer modo cifrado como el del diario de oración (D13), con su llave, su frase y más trabajo | **Sí, solo en el dispositivo** |
| 8 | **Un día con 11 de 12 elementos de pronunciación.** *Resuelta por D-ING-12*: cuenta como **asistido** porque faltan menos de 10 minutos; sigue sin ser `completo` en el anillo de la sesión (3.3) | Nada que decidir; se deja por si quieres otra tolerancia | Dejar los 10 minutos |
| 9 | **Cómo leo D-ING-12 (asistencia).** (a) *«Repetir el curso»*: ¿quieres decir **el escalón**? (b) *«3 días completos»*: ¿un día en que estudiaste 40 de 60 minutos **cuenta como día faltado entero** (propuesta) o solo cuenta lo que falta, con un tope de 180 minutos faltados en el escalón? (c) ¿Los **tres días por escalón reemplazan** a los tres días de gracia por trimestre de las reglas anteriores (propuesta), o quieres las dos reglas? | (a) Cambia T15 y el tamaño del castigo: repetir 8 semanas; (b) cambia el cálculo de 3.4 y el ejemplo; (c) con las dos reglas habría dos contadores y dos mensajes, y la racha se complica | (a) **Sí, el escalón.** (b) **Día entero**: es lo que dice la frase. (c) **Reemplazan**: una sola regla, más sencilla de entender |

**Nota para el dueño · por qué el prefijo `hab_` importa (hallazgo del 17/nov/2026, sin SQL).** Las reglas de **privacidad** y de **solo agregar** del servidor se escribieron buscando tablas cuyo nombre empieza por `hab_`. Las del inglés empiezan por `ing_`. Si se crean sin ampliar esas reglas pasan dos cosas, y ninguna es un detalle:

1. **La bitácora.** Hoy el servidor impide anotar en la bitácora cualquier tabla `hab_` y oculta esas entradas al dueño y a la cuenta maestra (`supabase/migrations/20261105000000_habitos.sql:426-455`). Con `ing_`, **esa protección no las cubriría**: lo que se haga en el inglés podría aparecer en una bitácora que ve alguien más. Es justo lo que D21 prohíbe.
2. **«Solo agregar» y el borrado.** La regla que impide editar o borrar filas (para que el historial no se altere) bloquea **a todos, incluso a las funciones de borrado** (`supabase/migrations/20261020000000_base.sql:289-302`). Las tablas del inglés son de solo agregar, así que **«Borrar mis datos» y la limpieza a los 90 días de una baja fallarían** al llegar a la primera de ellas: la persona pediría borrar y no se borraría.

**Qué hay que ampliar** (lo hace `backend` en P2.2, antes de crear una sola tabla; 8.3 y 8.4): (a) que las protecciones de la bitácora cubran también el prefijo `ing_`; (b) una variante de «solo agregar» que deje pasar **únicamente** a las dos funciones de borrado; (c) que esas dos funciones incluyan las tablas `ing_`; y (d) pruebas del servidor que lo comprueben (CA-5m-03, 04 y 05). **Alternativa:** poner a las tablas nombres `hab_ingles_…`: cubre (a) sin tocar la regla, pero **no** resuelve (b) ni (c), y alarga todos los nombres. **Recomiendo ampliar las reglas** y no cambiar los nombres. Si no se hace, el curso **no debe arrancar** (es un requisito de P2.2).

## 16. Historial de versiones

Este archivo contiene **solo el bloque 5** de la Fase 8; los demás bloques viven en sus propios `fase-8-*`.

| Versión | Fecha | Cambio |
|---|---|---|
| **0.6** | 17/nov/2026 | Esta versión. Incorpora D-ING-12 a 15 (`docs/DECISIONES.md`, D29, líneas 570 y 571; plan 4.1): **asistencia** (10 minutos por día y 3 días faltados por escalón; reemplaza al 90 % de minutos y a los días de gracia por trimestre; P5-30), **sin conexión** completo (9.1, 9.2, 9.6 y 9.7), **dictado local** como requisito de 5b (4.4), **pruebas por unidad** que cuentan para subir (3.6.1; sustituye a P5-08; P5-31), **texto y transcripción a la IA con permiso en cada envío y voz solo en el dispositivo** (D-ING-15, 4.4 y 7.1) y la nota sobre los prefijos `hab_` e `ing_` (15). Alineada con `fase-8-habitos-pareja-y-correccion.md` 0.2 |
| 0.5 | 16/nov/2026 | Versión anterior (P0.3): reescritura completa en los sub-bloques 5a a 5e, modelo de datos `ing_*`, sin conexión y criterios numerados. Resuelve ING-I7 y los puntos «Para P0.3» de `niveles-y-avance.md` |
| 0.4 | 14/nov/2026 | Módulos 1 y 2 aprobados por el dueño. Módulo 3 (planes y metas) redactado, en revisión. Rúbrica de evaluación (`docs/contenido/ingles/rubrica-evaluacion.md`) en revisión: la evaluación del estudiante se mide con ella y no es certificación oficial. Los módulos 4 a 6 se redactan después de cada aprobación. El 15/nov/2026 se le añadió un aviso: quedó atrás respecto a las decisiones posteriores del dueño |
| 0.3 | 14/nov/2026 | Módulo 1 aprobado |
| 0.2 | 14/nov/2026 | Alcance 5a aprobado por el dueño. Contenido en `docs/contenido/ingles/`. Decisiones tomadas por omisión, pendientes de confirmar: 5 días a la semana, unos 15 minutos al día, recordatorio local discreto, inglés como área propia con su racha. Fuente: `docs/modulos/habitos/diseno-app-habitos.md` §5.3 y Anexo A (plan de 24 semanas B1 → B2). Base: `fase-3-habitos.md`, D21 y las reglas de D3 y D6 |
