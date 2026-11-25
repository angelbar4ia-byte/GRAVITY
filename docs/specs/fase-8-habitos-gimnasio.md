# Fase 8 · Bloque 7 — Hábitos: Mi gimnasio (entrenamiento propio, primera versión sin IA)

> **Versión 0.1** (23/nov/2026), **propuesta** para el dueño. El número de bloque (7) lo confirma el arquitecto. Es **solo especificación**: no hay código, ni SQL, ni pruebas, ni cambios en ningún `pubspec.yaml`. Escribe el agente `habitos`.
>
> **Base:** `CLAUDE.md`; `docs/DECISIONES.md` (D3, D5, D6, D13, D14, D15, D21 y D29 para el estilo de las decisiones); `docs/ROADMAP.md` (11.1, 11.2 y 11.4); `docs/specs/fase-0-cimientos.md` (sección 4); `docs/DISENO_UX_UI.md` (secciones 2, 4, 5, 6, 9, 11, 12, 17, 20 y 21); el diseño de Hábitos v1.18 (`docs/modulos/habitos/diseno-app-habitos.md`: 5.2 «Salud / Entrenamiento / Mi gimnasio», 7.1 Agenda, Anexo E música, G.3.8 «Entrenamiento de hoy», Anexo F modo foco, sección 10 privacidad, Anexo H etapa 6); `docs/specs/fase-3-habitos.md` y `docs/specs/fase-8-habitos-ampliaciones.md` (formato y estilo que se imitan); y el código real de `paquetes/habitos_dominio/`, `app/lib/modulos/habitos/` y `supabase/migrations/2026110*`.
>
> **Decisiones del dueño del 23/nov/2026 que esta especificación cumple** (no las cambia):
> 1. Inventario actual: estación multifuncional **Marcy MWM-7119** (pila de ~68 kg, poleas alta y baja, brazos de press, cojín de curl), **banco inclinado**, **caminadora** y, desde hoy, **bandas de resistencia**. Sin pesas libres.
> 2. La primera versión **funciona sin IA**, con reglas y contenido fijo: sesiones **A, B y C** del diseño con sustitución de ejercicios según el inventario, tres duraciones (30, 45 y 60 minutos), progresión por repeticiones, series, tempo y descanso (la pila es de ~68 kg), semanas de descarga y sesiones regenerativas.
> 3. La IA queda como **función opcional posterior**; sin molestias físicas ni datos de salud (sección 11).
> 4. «Equipo futuro» (mancuernas) se conserva **solo como dato**, no como generador.
> 5. Las molestias físicas se registran **solo en el dispositivo**.
>
> **Cómo se marca lo que se afirma.** *Decidido*: lleva su fuente. **VERIFICADO**: lo leí en el repositorio, con `archivo:línea`. **Propuesta PG-nn**: la resuelvo yo y el dueño puede vetarla; se reúnen en la sección 16. **[confirmar en el aparato]**: dato del equipo que el diseño no confirma y que la persona debe verificar con el aparato, el manual o la etiqueta; la app nunca lo da por cierto (3.1). No hay datos personales reales: todo ejemplo es inventado.

---

## 1. Resultado buscado y alcance

### 1.1 Qué entrega este bloque

**Resultado.** Abrir Hábitos y saber **qué entrenamiento toca hoy con el equipo que de verdad hay en casa**, hacerlo con un registro de una serie por toque y un temporizador de descanso, ver cómo se avanza semana a semana y recibir una semana de descarga cuando toca, **sin culpa, sin IA y sin que ninguna molestia física salga del dispositivo**.

| Parte | Qué entra | Sección |
|---|---|---|
| **Contenido** | Catálogo cerrado de aparatos, puestos, ejercicios con variantes por aparato (incluidas bandas), plantillas A, B y C, regenerativas, calentamiento y cierre | 3 |
| **Datos** | Inventario, perfil, plan semanal, sesiones y series (en claro, solo lo propio por RLS); molestias (solo en el dispositivo) | 4 |
| **Reglas (generador sin IA)** | Filtro por inventario, sustitución, bandas, tiempo estimado y tres versiones, 48 horas, descanso, progresión con pila limitada, descarga, reentrada, modo foco, molestias, ventana de prueba y aviso de sueño | 5 |
| **Registro** | Series, repeticiones, carga, esfuerzo percibido, récords e historial (todo calculado) | 6 |
| **Pantallas** | Inventario, plan de la semana, sesión en curso con temporizador, registro rápido, historial y récords, molestias, ajustes | 7 |
| **Conexiones** | Agenda, sueño, modo foco, Hoy, GRAVITY (navegación) y, a futuro, Health Connect | 8 |

**Dónde vive cada cosa** (carpetas del agente `habitos`, `docs/ROADMAP.md` 11.2):

| Pieza | Carpeta | Estado |
|---|---|---|
| Dominio puro (catálogo, generador, progresión, récords) | `paquetes/habitos_dominio/lib/src/gimnasio/` (el paquete no tiene dependencias: `paquetes/habitos_dominio/pubspec.yaml:12-13`) | Por escribir (G1) |
| Casos de uso, estado y pantallas | `app/lib/modulos/habitos/gimnasio/` (carpeta nueva dentro de las propias) | Por escribir (G5) |
| Tablas `hab_ent_*`, reglas y pruebas SQL | `supabase/migrations/` y `supabase/tests/` (agente `backend`) | Por escribir (G2) |
| Almacén local, cola, pantalla encendida | `app/lib/nucleo/` (agente `plataforma`) | Por escribir (G3) |
| Gadgets y componentes | `app/lib/diseno/` (agente `diseno`) | Por escribir (G4) |

### 1.2 Qué NO es (límites que se dicen en la app)

| No es | Cómo se dice y se cumple |
|---|---|
| **Consejo médico ni de un entrenador** | Es una **guía general que no sustituye a un profesional**. Se dice con ese texto al empezar (se pide «Entendido» y se guarda la fecha, 4.2), en *Ajustes › Mi gimnasio › Sobre esta guía* y como línea fija bajo el plan de la semana. Antes de empezar, si hay una condición médica o hace tiempo que no se entrena, recomienda consultar a un profesional; **no pregunta ni guarda condiciones médicas** |
| **Un diagnóstico** | Ante una molestia o lesión **no dice qué es ni cómo se llama**: ajusta el ejercicio y recomienda consultar a un médico o entrenador (diseño `diseno-app-habitos.md:200`). Una prueba automática impide palabras de diagnóstico, tratamiento, medicamento o dosis en todo el contenido (CA-G-03) |
| **Un plan de dieta o de calorías** | No calcula calorías, macros ni composición corporal (diseño `:285`) |
| **Un generador con IA** | En esta versión ninguna función llama a una IA (sección 11, CA-G-39) |
| **Un entrenador de ciclismo** | La ruta en bicicleta de los sábados es de otro bloque (Anexo E); aquí solo aparece como día del plan y como carga para las piernas (5.6) |
| **Un módulo de competencia** | Sin clasificaciones ni comparación con otras personas; nada se comparte con la pareja en esta versión (D21, `fase-3-habitos.md:369`, regla 109) |

### 1.3 Queda fuera

| Queda fuera | Va a |
|---|---|
| **IA que arma el plan** (diseño `:193`) | Función opcional posterior; solo se especifica qué se enviaría (sección 11) |
| **Mancuernas y demás «equipo futuro» como generador** (diseño `:211`) | Solo se guardan como dato (4.2, `estado = futuro`). Una versión posterior puede generar rutinas «para cuando tengas mancuernas» |
| **Health Connect** | A futuro, con permiso, solo el ejercicio hecho (8.4). Hoy no hay ninguna dependencia de Health Connect en la app (verificado, H-14) |
| **Ruta en bicicleta, visor de ruta y música** (Anexo E) | Otro bloque de Salud. Este documento solo reserva el sábado y la regla de las 48 horas |
| **Cardio con intervalos en la caminadora** (diseño `:208`) | Fuera: la caminadora se usa para calentar y para la regenerativa. El cardio suave matutino es un bloque de agenda normal (diseño `:566`) |
| **Sueño** (registro, plan de transición) | Etapa 6 del diseño, aparte. Aquí solo se lee la hora de dormir (8.2) |
| **Estructuras distintas de A, B y C** (cuerpo completo, torso y pierna, push, pull, legs: diseño `:544`) | Versión posterior |
| **Pareja y familiares** | Cada persona con Hábitos tiene su propio inventario y plan; no se comparten. La pareja usa el mismo módulo con sus propios datos |
| **Personas bajo cuidado** | No usan Hábitos (D5) |

### 1.4 Reglas que no se rompen

| # | Regla | De dónde sale | Cómo se cumple aquí |
|---|---|---|---|
| R1 | **Datos clínicos y dinero nunca a la IA en la nube ni a las bocinas** | D3, D6 | Ninguna función de este bloque llama a una IA ni habla por bocinas. Las molestias son datos clínicos de la persona: ni salen del dispositivo (9) |
| R2 | **Hábitos es personal**: cada persona ve solo lo suyo; la cuenta maestra no lo lee | D5, D21, `fase-3-habitos.md:66` | Las tablas `hab_ent_*` usan la misma regla que `hab_*`: `persona_id = persona_actual()` y `hab_activa(hogar_id)` (`supabase/migrations/20261105000000_habitos.sql:318-341`) |
| R3 | **Sin escritura en la bitácora y prefijo reservado** | D21, `20261105000000_habitos.sql:426-455` | Las tablas se llaman `hab_ent_*` **a propósito**: ya las cubre la regla que busca el prefijo `hab_` (PG-02, H-09) |
| R4 | **Sin contadores guardados**: rachas, récords, semana del ciclo, tipo de semana, carga sugerida y duración estimada **se calculan** | `fase-3-habitos.md:68` (convención 3) | El servidor guarda hechos (series hechas); el dominio calcula (4.4) |
| R5 | **Semana en lunes, UUID del dispositivo, enteros** | `fase-0-cimientos.md:61-72` | Los ciclos empiezan en lunes; ninguna cifra es `double` en el dominio; las cargas son enteros (PG-04) |
| R6 | **Tono sin culpa; acción diaria en 3 toques o menos** | `.claude/agents/habitos.md`, `fase-3-habitos.md:73` (convención 8) | Catálogo cerrado de mensajes con revisión automática (CA-G-40); marcar el día de entrenamiento como hecho en Hoy es **1 toque** y no obliga a registrar series (7.1) |
| R7 | **La app funciona completa sin IA y sin conexión** | `.claude/agents/habitos.md`; `fase-3-habitos.md:81` | Todo el generador es una función pura local; la sesión se entrena sin red (9.1) |
| R8 | **Nada fijo en el código de las pantallas**: horarios, cantidades y reglas son datos configurables | Diseño `:72` (principio 7); `fase-3-habitos.md:74` (convención 9) | El catálogo es un conjunto de datos versionados del módulo (PG-01); los valores de 5 se editan en Ajustes |
| R9 | **Sin secretos ni datos reales en el repositorio** | `CLAUDE.md` | Los ejemplos de este documento son inventados |

### 1.5 Lo verificado en el repositorio

| # | Hallazgo | Fuente |
|---|---|---|
| H-01 | El diseño define el inventario, el perfil (objetivo, nivel, días, duración, molestias), la **generación por IA** («la IA arma un plan semanal usando solo los aparatos del inventario»), la edición con alternativas por aparato, la progresión y la agenda | `diseno-app-habitos.md:185-196` |
| H-02 | Sesiones A (empuje), B (tirón) y C (pierna y core) con ejercicios, series y repeticiones; versiones de 30, 45 y 60 min; descanso 45–75 s; 48 h entre sesiones del mismo grupo; cierre de 5 min; calentamiento de 5–8 min en caminadora más movilidad | `diseno-app-habitos.md:226-248` |
| H-03 | Semana tipo de 3, 4 o 5 días con 2 regenerativos y bicicleta el sábado; es un borrador editable | `diseno-app-habitos.md:214-224` |
| H-04 | Lo único que el diseño dice del Marcy: pila de aprox. 68 kg (150 lb) **según el distribuidor**, poleas alta y baja, brazos de press y cojín de curl; **«confirmar en el aparato qué otras estaciones tiene»** | `diseno-app-habitos.md:206`, `:247` |
| H-05 | El diseño todavía dice **«Sin pesas libres por ahora (mancuernas, barras, discos, bandas o barra de dominadas)»**. La decisión del dueño del 23/nov/2026 agrega bandas: esa línea quedó atrás | `diseno-app-habitos.md:210` |
| H-06 | **Incoherencia del diseño sobre la ventana:** `:238` dice «el usuario aún no define horario»; `:243` dice «Plan del usuario: la mañana para devocional y cardio suave, la fuerza de noche después de las 19:00». El día tipo pone la fuerza de 19:15 a 20:15 y dormir a las 22:00 | `diseno-app-habitos.md:238`, `:243`, `:572`, `:577` |
| H-07 | **Choque con la bicicleta:** la sesión C (pierna) cae el **viernes** y la ruta de 4 h es el **sábado a las 8:00**; la regla de 48 h entre sesiones del mismo grupo no se cumple entre las dos (5.6) | `diseno-app-habitos.md:221-222`, `:232`, `:267` |
| H-08 | **Las duraciones de las etiquetas no salen de las plantillas del diseño:** con 4 ejercicios de 3 series, A y B estiman ~35 min como «estándar» (la etiqueta dice 45) (5.5) | `diseno-app-habitos.md:230-235`; cálculo en 5.5 |
| H-09 | La bitácora se protege **por el prefijo `hab_`** (la entrada de `bitacora_agregar` rechaza la tabla y `puede_ver_entrada_bitacora` la oculta); un prefijo distinto (como `ing_`) **no** queda cubierto sin ampliar la regla | `supabase/migrations/20261105000000_habitos.sql:426-455`; nota para el dueño de `fase-8-habitos-ampliaciones.md:1478-1483` |
| H-10 | El borrado de datos (`hab_borrar_datos_de`) y la cuota de filas (`hab_cuota_filas`) **listan las tablas a mano**: una tabla nueva debe agregarse a las dos listas; en `hab_cuota_filas` una tabla ausente da tope nulo | `supabase/migrations/20261106000000_habitos_sensibles.sql:266-286`; `20261107000000_habitos_endurecimiento.sql:189-224` |
| H-11 | Los tipos sensibles son **dos** y el servidor solo acepta sobres de esos dos (`check (tipo in ('habitos_sensibles','diario_oracion'))`); el enum de la app tiene los mismos dos valores | `20261106000000_habitos_sensibles.sql:17`; `app/lib/nucleo/sensibles/llaves_habitos.dart:31-37` |
| H-12 | Hábitos **escribe directo** con `upsert` y la cola sin conexión solo conoce las tablas de Finanzas y, de Hábitos, el envío de sobres cifrados; una sesión de gimnasio no puede depender de la red | `app/lib/modulos/habitos/datos/repositorio.dart:49-77`; `app/lib/app/arranque.dart:133` (`tablasDeLaCola = {...tablasColaFinanzas}`); `app/lib/nucleo/sensibles/subida_diferida.dart:18-21` |
| H-13 | **El modo foco no está conectado a Hoy ni a los recordatorios:** el dominio sabe calcularlo (`PlanCigarrillo.enFoco`, que solo usa la pantalla de Eliminar: `servicio_eliminar.dart:411`) y `filtrarFoco` existe, pero **ningún código de la app llama a `filtrarFoco`** (verificado por el arquitecto: solo se define en `hoy.dart:57`); el parámetro `modoFoco` de los recordatorios nunca se pasa con valor | `paquetes/habitos_dominio/lib/src/habito_eliminar.dart:53`; `hoy.dart:57`; `app/lib/modulos/habitos/casos_uso/servicio_eliminar.dart:411` (solo para el panel); búsqueda de `filtrarFoco` y `modoFoco:` en `app/lib` |
| H-14 | **No hay paquete de Health Connect, de pantalla encendida ni de vibración** en `app/pubspec.yaml`; sí hay `flutter_local_notifications` (línea 54) y `audioplayers` (línea 98) | `app/pubspec.yaml` |
| H-15 | **La tablet de la casa dice que la «Serie y descanso» no se muestra en el contexto Gimnasio** («Hábitos es personal»), mientras `DISENO_UX_UI.md` y D14 prevén ese gadget en el contexto Gimnasio | `app/lib/app/tablet/pantalla_modo_casa.dart:41-47`; `DISENO_UX_UI.md:131`, `:214`; `DECISIONES.md` D14 |
| H-16 | **La hora de dormir ya existe:** `hab_ajustes.despertar` y `dormir` (`time`), editables, y la agenda ya las usa para los huecos libres | `20261105000000_habitos.sql:67-68`, `:583`; `app/lib/modulos/habitos/casos_uso/servicio_agenda.dart:219-240` |
| H-17 | **Ya existen las piezas de agenda y carga que esta especificación reutiliza:** `BloqueRecurrente`, `huecosLibres`, `conflictos`, `medirCarga`, `lunesDe`, `mascaraDia`, `redondearMitadArriba`, `MensajesHabitos.prohibidas` y `TextoAvisoHabitos` | `paquetes/habitos_dominio/lib/src/agenda.dart:4`, `:45`, `:70`; `carga_dia.dart:12`; `fecha.dart:15-22`; `mensajes.dart:25-32` |
| H-18 | **La personalidad «Sport» ya existe** y `Submodulo.entrenamiento` ya la usa (acento neón, alto contraste, densidad grande, animación de 150 ms) | `app/lib/diseno/personalidad_modulo.dart:16`, `:127-135`, `:208` |
| H-19 | La sesión del día de Hábitos con un registro por elemento ya existe (`hab_registros`, único por elemento y fecha; estados `hecho`, `parcial`, `omitido`, `pospuesto`) | `20261105000000_habitos.sql:159-175`; `fase-3-habitos.md:93` |
| H-20 | Última prueba SQL: `121_finanzas_ingreso_anulado_con_reparto.sql`; última migración: `20261151000000_finanzas_ingreso_anulado_con_reparto.sql` (el siguiente número libre lo da el arquitecto al integrar) | `supabase/tests/`, `supabase/migrations/` |

### 1.6 Conflictos y desajustes con otras decisiones (para el arquitecto)

| # | Conflicto | Propuesta |
|---|---|---|
| C-1 | El diseño de Hábitos dice «la IA arma el plan» (H-01) y su hoja de ruta lo lista como «generador de rutinas» (`diseno-app-habitos.md:674`) | Actualizar el diseño: primera versión sin IA, IA opcional posterior. Se propone registrar la decisión nueva (sección 16) |
| C-2 | H-05: el diseño excluye las bandas | Actualizar `diseno-app-habitos.md:210-211` con el inventario del 23/nov/2026 |
| C-3 | **D21 fija dos tipos sensibles** (H-11); las molestias «solo en el dispositivo» no caben en ninguno sin riesgo de que se suban a la nube si la persona activa la nube del otro tipo | Un **tercer tipo local** que el servidor ya rechaza por diseño (PG-03). Es una ampliación de D21: requiere el visto bueno del dueño |
| C-4 | H-15: contradicción entre el código de la tablet y D14 | Aplicar 9.2 (personal como el teléfono; pública con nombre y PIN solo la parte no sensible) y retirar el texto «Todavía no está en la tablet» cuando se construya |
| C-5 | H-06 y H-07 (ventana y bicicleta) | Preguntas 4 y 6 de la sección 18 |
| C-6 | H-13: el modo foco no está conectado | Pedido a `habitos` (G5) y a `plataforma` (recordatorios), sección 17 |
| C-7 | Las carpetas del agente `habitos` no incluyen `app/assets` (es de `diseno`) | El catálogo se escribe como datos Dart en el dominio (PG-01); no hay pedido |

---

## 2. Convenciones y palabras

Se aplican las convenciones de `fase-0-cimientos.md` (sección 4) y las de la Fase 3 (`fase-3-habitos.md`, sección 3). Identificadores en español sin acentos (`Aparato`, `Puesto`, `Variante`, `PlantillaSesion`); textos de la interfaz en español de México con acentos y de tú.

| Palabra | Significa aquí |
|---|---|
| **Aparato** | Un equipo físico del inventario: la estación Marcy, el banco, la caminadora, las bandas |
| **Puesto** | Una estación de trabajo de un aparato: en el Marcy, «press», «polea alta», «polea baja», «cojín de curl» |
| **Accesorio** | Lo que habilita variantes sin ser un aparato: la banda, un **ancla** de puerta, la colchoneta, la tobillera de polea |
| **Ejercicio** | Un movimiento del catálogo («press de pecho»). Tiene una o más **variantes** |
| **Variante** | Una forma de hacer el ejercicio con un **equipo requerido** («press de pecho en la estación», «press de pecho con banda») |
| **Plantilla** | Una sesión del catálogo con **espacios** (*slots*) ordenados: **A** (empuje), **B** (tirón), **C** (pierna y core), **R1** y **R2** (regenerativas) |
| **Slot** | Un espacio de la plantilla con una lista **ordenada** de variantes candidatas; se ocupa con la primera cuyo equipo está disponible |
| **Versión** | **corta** (meta de ~30 min), **estándar** (~45) o **larga** (~60) de una plantilla (5.5) |
| **Plan semanal** | Qué plantilla toca cada día de la semana, con 3, 4 o 5 días (3 fuerza más 0, 1 o 2 regenerativas); el sábado es bicicleta y el domingo descanso |
| **Ciclo** | Bloque de semanas de carga seguido de una **semana de descarga** (por omisión 3 + 1) |
| **Carga** | Lo que se mueve: **pasos** de la pila (PG-04), el **nivel de banda** o el **peso corporal** |
| **Esfuerzo percibido** | Número de 1 a 5 que la persona da a una serie o a la sesión (PG-12): 1 muy ligero, 2 ligero, 3 moderado, 4 duro, 5 al límite |
| **Molestia** | Una molestia física que la persona registra **solo en su dispositivo**; no es un diagnóstico (4.3) |
| **Zona** | Región del cuerpo que un ejercicio carga o que una molestia afecta: del catálogo cerrado de 3.7 |

**Convenciones propias de este bloque**

1. **El dominio es Dart puro, sin dependencias y sin reloj propio:** recibe `hoy` y usa `soloDia`, `lunesDe`, `sumarDias`, `diasEntre`, `mascaraDia` y `redondearMitadArriba` de `paquetes/habitos_dominio/lib/src/fecha.dart`. Minutos como `int`; ninguna cifra es `double` (la duración estimada se calcula en segundos enteros).
2. **El generador es una función pura y determinista:** mismas entradas, mismas salidas. Sin azar, sin reloj, sin red. Es lo que permite probarlo con tablas de ejemplos (13).
3. **Ids estables.** El catálogo usa ids de texto en minúsculas sin acentos (`press_pecho_estacion`) que **nunca se reutilizan**; un ejercicio retirado queda marcado `retirado` para poder leer el historial. UUID v5 para lo que no debe duplicarse al reintentar (la sesión de un día y una plantilla, una serie); UUID v4 para lo demás (`fase-3-habitos.md:70`, convención 5).
4. **Último cambio gana** (`modificado_en`) en lo editable (perfil, plan, inventario, sesión y series); no hay filas solo-agregar en este bloque, para que «Borrar mis datos» y la limpieza de la baja funcionen sin una variante especial (H-09).
5. **Cada cifra de reglas vive en un solo lugar del dominio** (`ReglasGimnasio`: 45 a 75 s de descanso, 48 h con 60 min de tolerancia, ciclo 3 + 1, esfuerzo 1 a 5, margen de 90 min antes de dormir, 4 s por repetición, 45 s de cambio entre ejercicios…) y se edita en Ajustes donde dice 5.

---

## 3. Contenido: el catálogo (sin IA)

El contenido es **fijo y versionado** (`versionCatalogo`, entero). Cambia solo con una versión de la app; la persona no lo edita (sí edita su inventario, sus bandas, su plan y sus valores). Cada serie guardada anota la `catalogo_version` de su sesión para poder leer el historial aunque el catálogo cambie.

**Propuesta PG-01 · El catálogo son datos Dart del dominio** (`paquetes/habitos_dominio/lib/src/gimnasio/catalogo/`), como los textos del SOS (`fase-3-habitos.md:577`, P8: «los textos viven en `habitos_dominio/lib/src/sos.dart` como datos»). Así se prueba con `dart test` y no hace falta tocar `app/assets` (que es de `diseno`, C-7). *Si se veta:* JSON en `app/assets/gimnasio/` con un pedido a `diseno` y un validador.

**Propuesta PG-25 · Todo el catálogo nace «borrador sin revisar».** Cada ejercicio, variante y plantilla lleva `revision: borrador | revisado` y, mientras haya un `borrador`, la sesión muestra la línea «Contenido en revisión» y no se activa el plan sin que la persona la vea. La revisión por una persona competente (entrenador o fisioterapeuta) la pide la pregunta 1 de la sección 18 y se registra con fecha en `docs/revisiones/` (CA-G-45). **Esta especificación redacta la estructura y el contenido inicial; no lo valida un profesional.**

### 3.1 Estados de confirmación de un dato del equipo

Todo dato del catálogo de aparatos lleva su estado:

| Estado | Significa | Qué hace la app |
|---|---|---|
| `del_diseno` | Está en el diseño v1.18 (p. ej. «pila aprox. 68 kg según el distribuidor») | Se usa como **orientación** y se muestra con la marca «aprox.» |
| `confirmar` | No está en el diseño: **[confirmar en el aparato]** | Se pide a la persona en *Inventario › Confirmar en el aparato*; hasta entonces **no entra en ningún cálculo** (CA-G-04) |
| `confirmado` | La persona lo verificó y lo escribió (con fecha) | Entra en los cálculos |

### 3.2 Aparatos, puestos y accesorios iniciales

Los **ids son propuestos**; lo que dice «del diseño» sale de `diseno-app-habitos.md:206-211`.

| Id | Aparato / puesto | Grupos que trabaja | Carga | Estado |
|---|---|---|---|---|
| `marcy_mwm7119` | Estación multifuncional Marcy MWM-7119 | — | Pila | Del diseño |
| ↳ `marcy.press` | Puesto: brazos de press | pecho, hombro, tríceps | pasos de la pila | Del diseño |
| ↳ `marcy.polea_alta` | Puesto: polea alta | espalda, tríceps, hombro | pasos de la pila | Del diseño |
| ↳ `marcy.polea_baja` | Puesto: polea baja | espalda, hombro, glúteo | pasos de la pila | Del diseño |
| ↳ `marcy.cojin_curl` | Puesto: cojín de curl de bíceps | bíceps | pasos de la pila | Del diseño |
| ↳ `marcy.otros` | **Otros puestos** (extensión o desarrollador de piernas, etc.) | — | — | **[confirmar en el aparato]** (diseño `:206` y `:247`): la persona los agrega como puestos sueltos |
| `banco_inclinado` | Banco inclinado | — | Peso corporal | Del diseño |
| `caminadora` | Caminadora | — | — | Del diseño |
| `bandas` | Bandas de resistencia (lista de la persona, 4.2) | según la variante | Nivel de banda | **Nuevo (23/nov/2026)** |
| `ancla_puerta` | Ancla de puerta para bandas | — | — | **[confirmar]**: ¿hay una? |
| `colchoneta` | Colchoneta | — | — | **[confirmar]**: ¿hay una? |
| `tobillera_polea` | Correa o tobillera para la polea | — | — | **[confirmar]**: la patada de glúteo en polea baja la necesita |

**Datos del aparato que la app no puede inventar** (todos **[confirmar en el aparato]**; el diseño solo da «~68 kg según el distribuidor»):

| Dato | Para qué | Qué pasa mientras no se confirma |
|---|---|---|
| **Número de pasos (placas) de la pila** y **cuántos kg es un paso** | Convertir pasos a kg, saber cuándo se llega al **tope de la pila** | La carga se muestra como «placa 5» (no en kg) y **no se detecta el tope**: la progresión sin carga (5.8) se ofrece solo si la persona marca «ya estoy en la última placa» |
| **Si la polea es 1:1 o 2:1** (el peso que se siente puede ser la mitad del que marca la pila) | No comparar kg entre puestos | No se comparan cargas entre puestos distintos; cada puesto lleva su propio historial |
| **Puestos adicionales** del Marcy | Variantes con extensión de pierna, etc. | Solo se usan los cuatro puestos del diseño |
| **Punto de anclaje seguro para bandas en la estación** | Variantes con ancla `estacion` | **No se ofrecen**; quedan las de `pisar` y `puerta` (si hay ancla de puerta) |
| **Si el banco se ajusta a plano, su altura y la carga máxima que soporta** | Fondos en banco, subidas al banco y sentadilla al banco | Se muestra el aviso del fabricante «revisa la capacidad y la estabilidad del banco» antes de la primera vez y se pide confirmar |
| **Si la tobillera de la polea existe** | Patada de glúteo en polea baja | Se usa la variante con banda o sin equipo |

### 3.3 Ejercicios y variantes

Cada **ejercicio** lleva: `id`, nombre, **patrón** (empuje horizontal, empuje de hombro, jalón vertical, remo, flexión de codo, extensión de codo, sentadilla, subida, puente, patada, plancha), **grupos primarios** (para las 48 h), **zonas** que carga (3.7, para las molestias), explicación breve (hasta 280 caracteres), hasta 3 **errores comunes** (120 caracteres cada uno), `rango_reps` (mínimo y máximo) o `rango_segundos`, y `progresion` (`carga`, `repeticiones`, `tiempo`). Cada **variante** lleva: `id`, `requiere` (lista de ids de puesto, aparato o accesorio, **todos** necesarios), `ancla` (solo bandas: `pisar`, `puerta` o `estacion`), `nivel` de dificultad dentro del ejercicio y `mas_dificil` (id de otra variante, o nulo).

**Plantilla A · Empuje (pecho, hombro, tríceps).** Los ejercicios y las series y repeticiones de la columna «Del diseño» son los de `diseno-app-habitos.md:230`; las variantes con banda y sin aparato son **propuestas** y llevan `borrador` (PG-25).

| Slot | Del diseño (primera opción) | Segunda opción | Tercera opción |
|---|---|---|---|
| A1 Press de pecho · 3×10–12 | Press de pecho en la estación (`marcy.press`) | Press de pecho con banda (`ancla: puerta`, o `estacion` si se confirmó) | Flexiones inclinadas con las manos en el banco (peso corporal) |
| A2 Elevaciones laterales · 3×12–15 | En polea baja (`marcy.polea_baja`) | Con banda pisada (`ancla: pisar`) | — |
| A3 Extensión de tríceps · 3×12 | En polea alta (`marcy.polea_alta`) | Con banda anclada arriba (`puerta` o `estacion`) | Fondos en banco de rodillas flexionadas (ver A4) |
| A4 Fondos en banco · 3×8–12 | Fondos con peso corporal (`banco_inclinado`) | Fondos con rodillas flexionadas (más fáciles) | — |
| *Extra (versión larga)* | Flexiones inclinadas en el banco 3×8–12 | Plancha 3×30 s | — |

**Plantilla B · Tirón (espalda, bíceps, hombro posterior).**

| Slot | Del diseño | Segunda opción | Tercera opción |
|---|---|---|---|
| B1 Jalón al pecho · 3×10–12 | En polea alta | Con banda anclada arriba | — |
| B2 Remo sentado · 3×10–12 | En polea baja | Con banda (pisada, sentado en el suelo o el banco) | — |
| B3 Face pull · 3×12–15 | En polea alta | Con banda anclada a la altura del rostro | — |
| B4 Curl de bíceps · 3×10–12 | En el cojín (`marcy.cojin_curl`) | En polea baja | Con banda pisada |
| *Extra (versión larga)* | Remo con banda 3×12 | Plancha 3×30 s | — |

**Plantilla C · Pierna y core.**

| Slot | Del diseño | Segunda opción | Tercera opción |
|---|---|---|---|
| C1 Sentadilla hacia el banco · 3×12–15 | Con peso corporal (`banco_inclinado`) | Con banda pisada y sobre los hombros (más difícil) | Sentadilla sin banco, con apoyo en una pared o ancla |
| C2 Subidas al banco · 3×10 por pierna | Peso corporal (`banco_inclinado`) | — | — |
| C3 Puente de glúteo · 3×12–15 | Con apoyo en el banco | En el suelo con colchoneta | Con banda sobre las rodillas |
| C4 Patada de glúteo · 3×12 por pierna | En polea baja con tobillera | Con banda en el tobillo | Sin equipo, en cuadrupedia |
| C5 Plancha · 3×30–45 s | Sin equipo | — | — |

**Cómo se usa el orden.** El generador (5.3) toma la **primera** variante cuyo equipo está **disponible** (inventario, 5.2) y que no carga una zona con molestia activa en ese equipo (5.10). Las bandas **no desplazan** al Marcy cuando el Marcy está disponible, salvo en los casos de 5.4.

### 3.4 Versiones de la plantilla

Una **versión** cambia series, descanso, calentamiento, cierre y extras, no los ejercicios. Cada slot declara `esencial` (siempre entra) y `omitir_en_corta` (C4 «patada de glúteo»).

| Parámetro | Corta (meta ~30 min) | Estándar (~45) | Larga (~60) |
|---|---|---|---|
| Series por ejercicio | 3 | 3 (las del diseño) | 4 |
| Descanso entre series | 45 s | 60 s | 75 s |
| Calentamiento | 5 min | 6 min | 8 min |
| Cierre (estiramiento) | 3 min | 5 min | 5 min |
| Slots | Todos menos los `omitir_en_corta` | Todos | Todos más los **extras** disponibles |

El diseño dice «5–8 min» de calentamiento, «5 min» de cierre y «45–75 s» de descanso (`:226`, `:245-246`); la corta toma el cierre de 3 min como propuesta (PG-06).

### 3.5 Sesiones regenerativas (R1 y R2)

Del diseño (`diseno-app-habitos.md:250-255`): **20 a 40 minutos**, caminata suave en caminadora de 15 a 25 minutos, movilidad y estiramientos guiados (cadera, hombros, espalda), respiración y relajación y, opcional, oración o devocional al final. **Meta: recuperar, no rendir: no se mide por carga ni por intensidad.**

| Plantilla | Contenido inicial (propuesta, `borrador`) | Duración |
|---|---|---|
| **R1** (viernes en el plan de 4 y 5 días; martes en las variantes con C el jueves o el viernes) | Caminata suave 15 min; movilidad de cadera 5 min; movilidad de hombros 5 min; respiración 3 min | ~28 min |
| **R2** (jueves en el plan de 5 días; viernes si C es el jueves) | Caminata suave 20 min; movilidad de espalda 5 min; estiramientos 7 min; respiración y cierre 5 min | ~37 min |
| Sin caminadora | La caminata se cambia por marcha suave de la misma duración al aire libre o en el lugar | — |

Qué variante propone la app: la persona responde al abrir *«¿Cómo amaneciste? Descansado · Normal · Cansado»* (un toque); con **Cansado** propone R1 (la más corta). Cuando exista el registro de sueño (etapa 6 del diseño), la respuesta puede sugerirla la calidad de la noche anterior (`diseno-app-habitos.md:254`). **No hay series, cargas ni récords en una regenerativa:** solo se registran los minutos hechos y qué bloques completó.

### 3.6 Calentamiento y cierre

Del diseño: **5–8 minutos en caminadora a paso suave más movilidad de hombros y caderas** (`:226`) y **5 minutos de estiramiento** al cierre (`:246`). Propuestas: A y B movilizan hombros; C movilizan caderas; sin caminadora, marcha en el lugar; y **una serie de aproximación** (PG-20) en el primer ejercicio de cada sesión, con ~la mitad de la carga de trabajo, 8 repeticiones, sin contar para el volumen ni el récord.

### 3.7 Zonas

Catálogo cerrado de zonas, usado por los ejercicios (qué cargan) y por las molestias (qué afectan): `hombro`, `codo`, `muneca`, `cuello`, `espalda_alta`, `espalda_baja`, `cadera`, `rodilla`, `tobillo`, `otra`. Una molestia en una zona **marca con precaución** a los ejercicios que la cargan (5.10).

**Grupos musculares** (catálogo cerrado, para la regla de las 48 horas y para los aparatos): `pecho`, `espalda`, `hombro`, `triceps`, `biceps`, `cuadriceps`, `gluteo`, `core`. La bicicleta del sábado cuenta como `cuadriceps` y `gluteo` (5.6).

---

## 4. Modelo de datos

### 4.1 Qué se guarda y dónde

| Dato | Dónde vive | ¿Sale del dispositivo? | Quién lo ve |
|---|---|---|---|
| Catálogo (aparatos, ejercicios, plantillas) | Dentro de la app (datos del dominio) | No: viaja con la app | — |
| **Inventario** (qué aparatos y accesorios hay, sus confirmaciones, las bandas, el equipo futuro) | `hab_ent_inventario`, `hab_ent_bandas` | Sí, a **tu hogar** (Supabase con RLS) | Solo tú |
| **Perfil y plan semanal** | `hab_ent_perfil`, `hab_ent_plan_dias` | Sí, a tu hogar | Solo tú |
| **Sesiones y series** (qué hiciste, con qué carga, con qué esfuerzo) | `hab_ent_sesiones`, `hab_ent_series` | Sí, a tu hogar | Solo tú |
| **Récords, rachas, ciclo, tipo de semana, carga sugerida, duración estimada** | **No se guardan**: se calculan | — | — |
| **Molestias** | Almacén local cifrado del dispositivo (4.3) | **Nunca** | Solo tú, solo en ese equipo |
| Datos de salud para una IA | **No existe** en esta versión | — | — |

**Por qué sesiones y series en claro y no cifradas.** Son registros de cumplimiento como `hab_registros` (`fase-3-habitos.md:114`: «registros de cumplimiento… en claro con RLS propio»), la pantalla de la laptop debe poder mostrar el historial, y el dueño pidió «todo local o en tu hogar vía RLS por rol» y **solo** las molestias en el dispositivo. La pregunta 7 de la sección 18 deja abierta una opción más estricta.

### 4.2 Tablas del servidor `hab_ent_*` (backend, G2)

**Propuesta PG-02 · Prefijo `hab_ent_`.** Hereda las protecciones del prefijo `hab_` sin ampliar ninguna regla (H-09) y no necesita la variante de «solo agregar» que pide el inglés (`fase-8-habitos-ampliaciones.md:1478-1483`): las tablas son **editables** con último-gana y la persona puede borrar lo suyo, como `hab_registros`. *Si se veta:* otro prefijo exige ampliar la bitácora y las listas de H-10.

Todas llevan `hogar_id uuid not null → hogares` y `persona_id uuid not null → personas` (los pone el servidor con `hab_propio()`, como `hab_*`: `20261105000000_habitos.sql:276-314`), `modificado_en timestamptz not null` (el dispositivo; el servidor lo topa a 5 minutos en el futuro) y `actualizado_en timestamptz not null default now()`; RLS `persona_id = persona_actual()` y `hab_activa(hogar_id)`; privilegios por columna; **sin trigger de bitácora**; cuota de filas por tabla (H-10). Claves compuestas `(persona_id, id)` únicas para que las llaves foráneas no crucen personas.

**`hab_ent_perfil`** · una fila por persona (se crea al primer uso)

| Columna | Tipo | Notas |
|---|---|---|
| `persona_id` | uuid | **PK** |
| `dias_plan` | smallint | 3, 4 o 5; por omisión 3 |
| `version_pref` | text | `auto`, `corta`, `estandar`, `larga`; por omisión `auto` |
| `ventana` | text | `manana`, `noche` o `flexible`; por omisión `noche` (H-06, pregunta 6) |
| `noche_desde` | time | por omisión 19:00 (diseño `:243`) |
| `objetivo` | text | `fuerza`, `masa`, `perdida_grasa`, `salud_general`; por omisión `salud_general` (PG-21) |
| `nivel` | text | `principiante` o `intermedio`; por omisión `principiante` (PG-21) |
| `inicio_ciclo` | date | **lunes**; nulo = aún no empieza el plan |
| `ciclo_semanas` | smallint | 0 = sin descarga programada; de 3 a 8; por omisión 4 (3 + 1, PG-09) |
| `descanso_s` | smallint | nulo = el de la versión; de 30 a 120 (aviso fuera de 45–75) |
| `margen_dormir_min` | smallint | de 0 a 240; por omisión 90 (PG-15) |
| `prueba_desde` | date | nulo; inicio del periodo de prueba de la ventana |
| `prueba_ventana` | text | nulo, `manana` o `noche`: la ventana en prueba |
| `voz_descanso` | boolean | por omisión `false` (11, pregunta 8) |
| `aviso_visto_en` | timestamptz | nulo hasta que la persona toca «Entendido» (1.2) |

**`hab_ent_plan_dias`** · una fila por día de la semana

| Columna | Tipo | Notas |
|---|---|---|
| `dia_semana` | smallint | 1 (lunes) a 7 (domingo); **PK** `(persona_id, dia_semana)` |
| `tipo` | text | `A`, `B`, `C`, `R1`, `R2`, `bici` o `descanso` |
| `version` | text | `auto`, `corta`, `estandar` o `larga` |
| `hora` | time | nulo = la app propone con la agenda |

**`hab_ent_inventario`** · un aparato, puesto o accesorio por fila

| Columna | Tipo | Notas |
|---|---|---|
| `item_id` | text | de 1 a 60 caracteres; id del catálogo (`marcy.press`) **o** de un puesto suelto que la persona agregó (`otro:<texto corto>`); **PK** `(persona_id, item_id)` |
| `estado` | text | `disponible`, `no_disponible` (roto, ocupado, prestado) o `futuro` (solo dato: no genera nada) |
| `confirmado` | jsonb | hasta 2 KB; pares campo → valor confirmados (`pasos_max`, `kg_por_paso_x10`, `relacion_polea`, `capacidad_banco_kg`…) y fecha; **nada que no esté en la tabla de 3.2** |
| `notas` | text | hasta 200 caracteres |

**`hab_ent_bandas`** · las bandas de la persona

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v4 |
| `nombre` | text | de 1 a 40 caracteres (color o etiqueta) |
| `orden` | smallint | de 1 a 20: de la más ligera a la más fuerte, **la ordena la persona** |
| `resistencia_kg_x10` | smallint | nulo, o de 1 a 2 000: kg × 10 si la persona los lee de la etiqueta **[confirmar en la banda]** |
| `cantidad` | smallint | de 1 a 10 |
| `activa` | boolean | por omisión `true` |

**`hab_ent_sesiones`** · una por día y plantilla

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v5 de la persona, la fecha y la plantilla: dos equipos que registran la misma sesión convergen |
| `fecha` | date | **único** `(persona_id, fecha, plantilla)` |
| `plantilla` | text | `A`, `B`, `C`, `R1` o `R2` |
| `version` | text | `corta`, `estandar` o `larga` (en R1 y R2, la de duración) |
| `semana_tipo` | text | `carga`, `descarga`, `reentrada` o `foco` (lo que el dominio calculó ese día; sirve para el historial) |
| `ventana` | text | `manana` o `noche` (de la hora real de inicio; alimenta la prueba de la ventana) |
| `bloque_id` | uuid | nulo; llave `(persona_id, bloque_id) → hab_bloques` con `on delete set null` |
| `inicio`, `fin` | timestamptz | `fin` nulo mientras está en curso |
| `estado` | text | `en_curso`, `completa` o `parcial` (lo elige la persona al terminar, PG-13) |
| `esfuerzo`, `energia` | smallint | nulos, o de 1 a 5 |
| `plan` | jsonb | hasta 2 KB: lista de `{ejercicio, variante, series, reps_min, reps_max}` **tal como se planeó** (permite «hiciste 9 de 12 series» aunque cambien el catálogo o el inventario) |
| `catalogo_version` | smallint | not null |

**`hab_ent_series`** · una por serie hecha

| Columna | Tipo | Notas |
|---|---|---|
| `id` | uuid | **PK**, v5 de la persona, la sesión, el ejercicio, el número y el lado |
| `sesion_id` | uuid | llave `(persona_id, sesion_id) → hab_ent_sesiones` con `on delete cascade` |
| `ejercicio_id`, `variante_id` | text | de 1 a 60 caracteres; ids del catálogo |
| `n` | smallint | de 1 a 12: número de serie |
| `lado` | text | nulo, `izquierdo` o `derecho` (subidas y patadas por pierna) |
| `reps` | smallint | nulo, o de 0 a 100 |
| `segundos` | smallint | nulo, o de 0 a 900 (plancha) |
| `carga_pasos` | smallint | nulo, o de 0 a 60: paso de la pila (PG-04) |
| `banda_id` | uuid | nulo; llave `(persona_id, banda_id) → hab_ent_bandas` con `on delete set null` |
| `esfuerzo` | smallint | nulo, o de 1 a 5 |
| `descanso_real_s` | smallint | nulo, o de 0 a 900 (calibra el tiempo, 5.5) |
| `sustituye_a` | text | nulo; la variante que se cambió |
| `motivo_cambio` | text | nulo, `no_disponible`, `preferencia` u `otra`. **El motivo «molestia» no existe aquí a propósito** (PG-19, CA-G-27): si la persona cambia por una molestia, el servidor ve `otra` |

**Qué debe ampliar backend en lo ya existente** (H-10): agregar las seis tablas a la lista de `hab_borrar_datos_de` (alcance `todo`, y un alcance nuevo `entrenamiento`), a `hab_cuota_filas` (sugerido: sesiones 3 000, series 60 000, inventario 200, bandas 50, plan 7, perfil 1) y a la política de RLS y a los `grant` por columna de `20261105000000_habitos.sql:318-341` y `:568-625`; y confirmar que la baja con borrado a los 90 días (D21) las cubre.

### 4.3 Molestias: solo en el dispositivo (tercer tipo local)

**Propuesta PG-03 · Tercer tipo sensible `salud_local`, que no admite nube.** Hoy hay dos tipos (H-11) y cada uno se puede pasar a la nube cifrada. Si las molestias se guardaran dentro de `habitos_sensibles`, activar la nube para el cigarrillo las subiría **sin que la persona lo supiera**. El tercer tipo:

- usa el mismo almacén local de sobres y la **llave local** de la persona (`DocumentosSensibles`, `app/lib/modulos/habitos/datos/documentos_sensibles.dart:26-130`; `ElementoDoc` y `DocumentoSensible` del dominio, `documentos_cifrados.dart:85-118`);
- **no tiene modo**: es siempre `solo_telefono`, no hay fila en `hab_modos` ni botón para pasarlo a la nube;
- **el servidor ya lo rechaza**: `hab_sobres.tipo` solo admite los dos tipos existentes (H-11), así que aunque un error de la app intentara subirlo, el servidor lo niega (CA-G-28);
- entra en *Mis datos de Hábitos* (exportar y borrar) y en el respaldo local cifrado con la frase, como lo reservado (`fase-3-habitos.md:165`).

Documento `molestias` con elementos de clase `molestia`: `zona` (3.7), `intensidad` (1 leve, 2 moderada, 3 fuerte), `desde` (fecha), `hasta` (nula = activa), `nota` (hasta 200 caracteres, solo local). **Qué NO guarda el servidor, nunca:** ni la molestia, ni su zona, ni cuándo se registró. *Si se veta:* clase `molestia` dentro de `habitos_sensibles` con el aviso de que sigue el modo de ese tipo (peor para el pedido del dueño).

**Efecto de «solo en el dispositivo».** Las molestias de un equipo **no las conoce otro**. El generador las aplica **al abrir la sesión en el equipo donde se hace**, no al armar el plan (4.4). Si la persona entrena en una tablet que no las conoce, la tablet lo dice («Las molestias están solo en tu teléfono; aquí no se tienen en cuenta») y ofrece registrarlas allí (también solo en esa tablet).

### 4.4 Lo que se calcula y no se guarda

- **La sesión concreta** (qué variante ocupa cada slot, series, repeticiones, carga sugerida) se **deriva al abrirla** de (catálogo, inventario, molestias locales, versión, historial). No se guarda un «plan generado»: se guarda lo que se hizo y un resumen de lo planeado (`plan`, 4.2). Propuesta PG-05.
- **Semana del ciclo** = `(lunesDe(hoy) − inicio_ciclo) ÷ 7 + 1`, módulo `ciclo_semanas`; el **tipo de semana** (`carga`, `descarga`, `reentrada`, `foco`) sale de esa cuenta, del historial y del modo foco.
- **Récords, rachas, volumen, «mejor serie»** salen de `hab_ent_series`.
- **Duración estimada** sale del modelo de 5.5 con las cargas y el historial de descanso real.

---

## 5. Reglas del generador (sin IA)

Todas son **funciones puras del dominio** (`paquetes/habitos_dominio/lib/src/gimnasio/`) con valores en `ReglasGimnasio`. Donde dice «probable» es un valor propuesto que se edita en Ajustes o se calibra con el uso.

### 5.1 Entrada y salida

`generarSesion(plantilla, version, inventario, molestias, historial, hoy, modoFoco) → SesionPlanificada`, con: lista de `EjercicioPlanificado` (variante, series, rango de repeticiones o segundos, carga sugerida, descanso), `duracionEstimadaSeg`, `semanaTipo`, y `avisos` (lista cerrada de códigos: `sin_equipo_suficiente`, `slot_omitido`, `con_precaucion`, `tope_de_pila`, `cerca_de_dormir`, `modo_foco`…). **No lleva texto**: los textos salen del catálogo de mensajes (CA-G-40).

### 5.2 Filtro por inventario

Una variante está **disponible** si **todos** los ids de su `requiere` están en el inventario con `estado = disponible`, y, si es de banda, existe al menos una banda activa y el `ancla` que pide está disponible: `pisar` siempre; `puerta` solo si `ancla_puerta` está disponible; `estacion` solo si la persona **confirmó** el punto de anclaje seguro en la estación (3.2). Un aparato `futuro` o `no_disponible` **no cuenta**.

### 5.3 Ocupar un slot

1. Para cada slot, en orden, se toma la **primera** variante disponible que no tenga una molestia activa en una de sus zonas (5.10).
2. Si ninguna cumple, el slot **se omite** con el aviso `slot_omitido` y la razón (`sin_equipo` o `precaucion`).
3. Si tras ocupar los slots quedan **menos de 3 ejercicios**, el aviso es `sin_equipo_suficiente`: la app dice que con el inventario o las precauciones actuales no alcanza una sesión de fuerza y ofrece la **regenerativa** o ir a *Inventario*. **No inventa ejercicios.**
4. Si ningún aparato del Marcy está disponible, **A, B y C siguen** con las variantes de banda y de peso corporal (3.3); es el caso «sin estación» de CA-G-06.

### 5.4 Cómo entran las bandas

1. **Alternativa, no reemplazo.** Cada slot lista la variante del Marcy primero; la banda es la segunda o tercera opción (3.3). Con el Marcy disponible, **gana el Marcy**.
2. **Cuando el Marcy no está** (puesto `no_disponible`, ocupado por otra persona, de viaje, o la persona prefiere la banda en *Cambiar ejercicio*), la banda ocupa el slot.
3. **Como progresión del peso corporal.** En los slots de peso corporal (sentadilla, puente, fondos, subidas) la banda es la variante `mas_dificil`: se ofrece cuando la persona ya llegó al techo de repeticiones y series (5.8).
4. **Carga de banda.** Se registra la **banda usada** (`banda_id`); la progresión es **la siguiente banda en el orden de la persona** (`orden`), o **dos bandas juntas** como paso intermedio entre una banda y la siguiente. La app **no convierte** la resistencia de una banda a kg salvo que la persona haya capturado `resistencia_kg_x10` de la etiqueta.
5. **Seguridad (texto fijo, sin diagnóstico):** «Revisa la banda antes de usarla: sin grietas ni cortes. Asegura bien el ancla.» Se muestra la primera vez de cada variante de banda y cada 4 semanas.

### 5.5 Versiones y tiempo estimado

**Modelo de tiempo (VERIFICADO con un cálculo propio; PG-06).** Duración = calentamiento + Σ por ejercicio (`cambio` + series × (`trabajo` + `descanso`)) + cierre, en segundos enteros:

- `trabajo` = repeticiones medias × **4 s por repetición** (por pierna: ×2; plancha: los segundos del rango);
- `cambio` = **45 s** entre ejercicios (ajustar el pasador o la banda, cambiar de puesto);
- `descanso`, calentamiento y cierre = los de la versión (3.4).

| Plantilla | Corta | Estándar | Larga (4 series, sin extras) | Larga con extras |
|---|---|---|---|---|
| A · Empuje | 29.3 min | 35.3 min | 48.4 min | ≈ 60.9 min (con flexiones inclinadas y plancha) |
| B · Tirón | 29.3 min | 35.3 min | 48.4 min | ≈ 61.3 min (con remo con banda y plancha); sin bandas, ≈ 54.4 min |
| C · Pierna y core | 31.2 min (sin patada) | 45.8 min | 63.1 min | — |

**Lo que dice esto (hallazgo H-08).** Con las plantillas del diseño, **«estándar» no llega a 45 minutos en A y B** (35.3). La especificación no estira la sesión para que coincida con la etiqueta: **muestra la duración estimada real** y trata 30, 45 y 60 como **metas con tolerancia** (corta de 27 a 33, estándar de 33 a 50, larga de 48 a 65 minutos). Quien quiera 45 minutos en A o B elige **larga** o agrega series en Ajustes.

**Elegir la versión.** Con `version_pref = auto`, la app toma la **más larga cuya duración estimada más 10 minutos de margen cabe** en el hueco libre de la agenda (`huecosLibres`, `agenda.dart:45`). Si **ninguna cabe**, dice que no cabe una sesión de fuerza ese día y propone **mover el bloque** o la **regenerativa**; no hay una cuarta versión.

**Calibración.** Tras 3 sesiones con `descanso_real_s`, la app **sustituye** los 4 s por repetición y los 45 s de cambio por la **mediana de la persona** (redondeada a segundos enteros). Hasta entonces usa los valores de arriba.

### 5.6 Semana, 48 horas y la bicicleta

**Plan semanal por omisión (decisión del dueño, 24/nov/2026, editable):** la semana **reordenada** para que la pierna no choque con la ruta del sábado (ver 22).

| Días | Lunes | Martes | Miércoles | Jueves | Viernes | Sábado | Domingo |
|---|---|---|---|---|---|---|---|
| **3** | A | C | B | libre | libre | Bicicleta | Descanso |
| **4** | A | C | B | libre | R1 | Bicicleta | Descanso |
| **5** | A | C | B | R2 | R1 | Bicicleta | Descanso |

Las regenerativas ya no caen en martes: R1 es el viernes (suave, un día antes de la ruta) y R2, en el plan de 5 días, el jueves. Variantes que se conservan en el dominio (`planSemanal(dias, cEnJueves: true)` y `planSemanal(dias, cEnViernes: true)`, nunca juntas):

| Variante | Lunes | Martes | Miércoles | Jueves | Viernes | Con la ruta del sábado a las 8:00 |
|---|---|---|---|---|---|---|
| **C el jueves** (recomendación anterior, pregunta 4) | A | R1 (4 y 5 días) | B | C | R2 (5 días) | 36 h 45 min con C a las 19:15: **avisa** |
| **C el viernes** (tabla literal del diseño, `:218-222`) | A | R1 (4 y 5 días) | B | R2 (5 días) | C | 12 h 45 min con C a las 19:15: **avisa** y propone mover C al jueves |

**Regla de las 48 horas (Propuesta PG-07).** El diseño pide «al menos 48 h entre sesiones del mismo grupo muscular» (`:245`). Se lee así: entre dos sesiones que comparten un **grupo primario**, el **inicio a inicio** debe ser de al menos **48 h − 60 min de tolerancia** (47 h; editable). Los grupos de una sesión son la unión de los grupos primarios de sus ejercicios: A = {pecho, hombro, tríceps}; B = {espalda, hombro, bíceps}; C = {cuádriceps, glúteo, core}. **Avisa, no bloquea** (sin culpa).

| Caso (ejemplo inventado) | Intervalo | Resultado |
|---|---|---|
| A el lunes 20:00 y B el miércoles 19:15 | 47 h 15 min (comparten `hombro`) | Cumple |
| A el lunes 20:00 y B el miércoles 18:30 | 46 h 30 min | Aviso: «A y B comparten hombro; mejor 30 min más tarde» |
| A el lunes y B el martes a la misma hora | 24 h | Aviso |
| A el lunes 19:15 y B el miércoles 19:15 (semana por omisión) | 48 h (comparten `hombro`) | Cumple |
| C el martes 19:15 y la ruta del sábado a las 8:00 (semana por omisión) | 84 h 45 min | Cumple, sin aviso |
| Dos sesiones de fuerza el mismo día | — | Aviso y se propone otro día; **máximo una sesión de fuerza por día** |

**La bicicleta cuenta como piernas (H-07).** La ruta de 4 horas del sábado a las 8:00 carga cuádriceps y glúteo. Con la **semana por omisión** (C el martes a las 19:15) hay **84 h 45 min** hasta la ruta: **no sale aviso**. Si la persona mueve C a otro día, el generador avisa como antes: con C el **viernes a las 20:00** el intervalo es de **12 h** y propone, en orden, (a) **mover C al jueves**, (b) C en versión **corta** y (c) dejar el plan como está; con C el jueves quedan 36 h 45 min, el aviso sigue y la propuesta (a) ya no aparece. Es la **pregunta 4**, resuelta por el dueño el 24/nov/2026 con la semana reordenada (sección 22). El aviso **no bloquea** y no se esconde: sale tal cual en las variantes.

**Sesión perdida (PG-24).** Una sesión que no se hizo se puede **mover a un día libre de la misma semana** (respetando las 48 h, con aviso si no cumple) o **saltarse**; no se acumula ni se «recupera» con dos sesiones el mismo día. La progresión usa **la última vez que se hizo cada plantilla**, no el calendario (5.8), así que saltarse un día no rompe nada (diseño `:547`: «reprogramar sin romper el plan»).

### 5.7 Descanso entre series

Por omisión el de la versión (45, 60 o 75 s: dentro del rango **45 a 75 s** del diseño, `:245`). La persona puede cambiarlo en Ajustes de 30 a 120 s; fuera de 45–75 s hay un aviso, no un bloqueo. El temporizador de la sesión (7.2) usa este valor, y **+15 s / −15 s / Saltar** lo ajustan para esa serie.

### 5.8 Progresión con pila limitada (Propuesta PG-08)

La pila es de ~68 kg según el distribuidor [confirmar en el aparato], así que **la carga no puede ser la única palanca**. Se usa **doble progresión** y, al llegar al tope, una **escalera sin carga**.

**Regla base (carga disponible).** Cada ejercicio tiene un rango de repeticiones (p. ej. 10–12). Si, en la **última sesión** de esa plantilla, **todas las series llegaron al máximo del rango** y el **esfuerzo de la última serie fue ≤ 4** (si no se registró, se asume 3), la siguiente sesión **sube un paso de carga** y el objetivo vuelve al **mínimo** del rango.

| Ejemplo (inventado) | Resultado |
|---|---|
| Press de pecho, rango 10–12, placa 5: 12, 12, 12 con esfuerzo 3 | Sugiere **placa 6** y 10 repeticiones |
| 12, 12, 11 | Mantiene la placa 5; el objetivo es completar 12 en todas |
| 12, 12, 12 con esfuerzo 5 en la última | Mantiene la placa 5 (no se sube con esfuerzo al límite) |
| Sesión saltada | Sin cambio: se compara con la **última vez** que se hizo |

**Escalera sin carga** (cuando no hay un paso mayor: **solo** si la persona confirmó el número de pasos y está en el último, o marcó «ya estoy en la última placa»; o el ejercicio es de peso corporal o banda). Cada peldaño se agota antes de pasar al siguiente, y la sesión muestra por qué sube:

1. **Más repeticiones**: se amplía el techo del rango en 3 (10–12 pasa a 10–15).
2. **Más series**: de 3 a 4 (tope 5 en versión larga).
3. **Tempo más lento**: bajar en 3 s en lugar de 2 (se muestra «tempo 3-1-1»; las repeticiones del rango vuelven al mínimo).
4. **Menos descanso**: de 75 a 60 a 45 s.
5. **Variante más difícil** (`mas_dificil`): fondos con rodillas flexionadas → fondos con piernas estiradas; sentadilla al banco → sentadilla con banda (5.4).
6. **Banda siguiente** o **dos bandas** (5.4).

Mensaje al llegar al tope: «Llegaste al tope de la pila. Seguimos avanzando con más repeticiones y más control.» (sin culpa, sin signos de exclamación).

### 5.9 Descarga, reentrada y modo foco

**Semana de descarga (Propuesta PG-09).** Ciclo de **3 semanas de carga y 1 de descarga** (`ciclo_semanas = 4`, editable de 3 a 8, o 0 para ninguna). **Semana de descarga:** **2 series** por ejercicio, repeticiones en el mínimo del rango, **una placa menos** (o la banda anterior), **sin incrementos**, regenerativas intactas. **Cuenta como semana cumplida** para la racha. Ejemplo: plan que empieza el lunes **30/nov/2026**: semanas de carga 30/nov, 7/dic y 14/dic; **descarga la del 21/dic**; el ciclo siguiente empieza el 28/dic.

**Descarga sugerida antes de tiempo.** Si en **dos sesiones seguidas** el esfuerzo de la sesión fue **5**, la app **sugiere** una descarga ahora (la persona acepta o la pospone). **Nunca** la impone.

**Reentrada tras una pausa (Propuesta PG-10).** Se mide **desde la última sesión de fuerza**:

| Días sin sesión de fuerza | La semana siguiente |
|---|---|
| Menos de 7 | Normal |
| De 7 a 13 | Se repiten las cargas de la última vez, sin subir |
| 14 o más | **Semana de reentrada:** 2 series y **una placa menos** que la última vez |
| 56 (8 semanas) o más | Como la primera vez: cargas de prueba (5.12) |

Mensaje: «Retomemos con calma. Hoy cuenta empezar.» Las pausas declaradas (`hab_pausas`, motivo `salud`, `viaje`…) **no** cuentan como días sin sesión.

**Modo foco (Propuesta PG-11).** Dentro del modo foco de un hábito a eliminar (`diseno-app-habitos.md:1678`: «Pausa los incrementos de entrenamiento»), el generador **no sube carga, repeticiones ni series** (`incrementos = false`), el contador del ciclo **se detiene** (esas semanas no cuentan como de carga) y el tipo de semana es `foco`. La sesión **sigue disponible**: se sugiere la versión corta o la regenerativa, sin culpa. El generador solo recibe un **booleano** `modoFoco` (8.3): **nunca sabe qué hábito lo causó.**

### 5.10 Molestias y sustitución (sin diagnosticar)

Con una molestia **activa** (4.3) en una zona:

| Intensidad | Qué hace la app |
|---|---|
| 1 · leve | Los ejercicios que cargan esa zona se marcan **«con precaución»**; se ofrece una alternativa que no la cargue (si existe); la persona decide |
| 2 · moderada | Esos ejercicios **no se ocupan** automáticamente: se sustituye por la siguiente variante sin esa zona o se omite el slot; la persona puede volver a elegir uno con precaución |
| 3 · fuerte | Además se muestra el aviso: **«No sustituye a un profesional. Si el dolor es fuerte, aparece de golpe, no cede con el descanso o te acompaña otro síntoma, consulta a un médico o a un entrenador.»** y se propone la regenerativa |

Cada **14 días** sin cambios, la app pregunta «¿Sigue esta molestia?» (un toque: *Sigue* o *Ya no*). **Nunca** dice qué es, nunca nombra una lesión ni una causa, nunca recomienda un tratamiento ni un medicamento (CA-G-03). Al sustituir por una molestia, lo que viaja al servidor es la variante elegida y el motivo `otra` (4.2, PG-19).

**Cambiar ejercicio durante la sesión.** La lista de alternativas del slot (3.3) excluye la variante actual y las no disponibles; cada una dice por qué (`más fácil`, `más difícil`, `sin aparato`, `con precaución`). Lo elegido **para esa sesión** no cambia el plan.

### 5.11 Objetivo y nivel (Propuesta PG-21)

Solo cambian **valores por omisión**; no hay cálculos de masa ni de calorías.

| Valor | `salud_general` y `masa` | `fuerza` | `perdida_grasa` |
|---|---|---|---|
| Rango de repeticiones | El de la plantilla (10–15) | Mínimo −2 y máximo −2 (p. ej. 8–10) | El de la plantilla |
| Descanso por omisión | El de la versión | El de la versión +15 s (tope 75 s) | El de la versión −15 s (piso 45 s) |

`nivel = principiante`: las **2 primeras semanas** del plan son de **adaptación** (2 series por ejercicio, sin subir carga). `nivel = intermedio`: arranca en carga normal con la serie de aproximación.

### 5.12 Primer arranque: cargas de prueba (Propuesta PG-23)

Sin historial, la app no sugiere una carga: dice «Elige una carga con la que llegues a las repeticiones con esfuerzo 3 (moderado)» y la **primera serie hecha** fija el punto de partida. No hay una fórmula de «un máximo de una repetición».

### 5.13 Ventana de entrenamiento, periodo de prueba y sueño

**Periodo de prueba de 2 semanas en cada horario** (diseño `:239`). La app compara, por ventana, **sesiones cumplidas** entre planeadas, **energía percibida** (el promedio de `energia`, en centésimas enteras) y, cuando exista el registro de sueño, la calidad del sueño. **Propuesta PG-16 (regla de la sugerencia):**

1. Hacen falta **al menos 4 sesiones planeadas** en cada ventana; si no, «faltan datos».
2. Si la diferencia de **cumplimiento** es de **15 puntos porcentuales o más**, sugiere la de mayor cumplimiento.
3. Si no, y la diferencia de **energía media** es de **0.5 o más** (50 centésimas), sugiere la de mayor energía.
4. Si no, dice «no hay diferencia clara: conserva la que prefieras».

Ejemplo (inventado): noche con 6 planeadas y 5 hechas (83 %) y energías 4, 3, 4, 4, 3 (media 3.6); mañana con 6 planeadas y 3 hechas (50 %): la diferencia es de 33 puntos y **sugiere la noche**. La app **sugiere y la persona decide**; no cambia nada sola.

**Aviso de cercanía a la hora de dormir (Propuesta PG-15).** Con ventana de noche, si **fin estimado de la sesión > hora de dormir − `margen_dormir_min`** (90 por omisión), avisa: «Esta sesión termina cerca de tu hora de dormir. ¿La hacemos más corta?» y ofrece, en orden: **versión más corta**, **regenerativa**, **empezar antes** o **mover a la mañana**. Ejemplo con el día tipo del diseño (`:572`, `:577`): sesión de 19:15 a 20:15 con dormir a las 22:00 → quedan 105 min, **sin aviso**; una sesión estimada de 20:30 a 21:30 → quedan 30 min, **con aviso**. En la mañana, propone un calentamiento más largo (hasta 8 min) y que termine antes de la salida considerando el traslado (`:241`).

---

## 6. Registro, récords e historial

### 6.1 Qué se registra y con cuántos toques

| Qué | Cómo | Toques |
|---|---|---|
| **Una serie** | ✓ **«Hecha»**: guarda las repeticiones y la carga **sugeridas**. Para cambiarlas, − y + (sin teclado) antes o después | **1** |
| **Esfuerzo de un ejercicio** | Cinco botones 1 a 5 al terminar su última serie; opcional | 1 |
| **Terminar la sesión** | «Terminar» → «Terminé la sesión» o «Terminé una parte» (PG-13) | 2 |
| **Esfuerzo y energía de la sesión** | Dos filas de cinco botones; opcionales | 0 a 2 |
| **Marcar el día como hecho sin registrar series** | En Hoy, *Hecho* o deslizar sobre el bloque de entrenamiento | **1** |
| **Registrar después** | *Registrar lo que hice* → «Todo como estaba planeado» → Guardar | 3 |

**Propuesta PG-13 · Terminar es una elección.** Al terminar, la persona elige **«Terminé la sesión»** (el bloque queda `hecho`) o **«Terminé una parte»** (queda `parcial`), sin que la app juzgue cuántas series fueron. Así la versión corta no «se castiga» y no hay umbral que explicar. Escribe `hab_registros` como cualquier bloque (H-19).

### 6.2 Récords (calculados)

| Récord | Definición |
|---|---|
| **Mejor carga** | La carga más alta con al menos el **mínimo** del rango de repeticiones en una serie |
| **Mejores repeticiones** | Más repeticiones en una serie a una carga **igual o mayor** |
| **Mejor tiempo** | Plancha: más segundos en una serie |
| **Mejor banda** | La banda de mayor `orden` con el mínimo del rango |

Se calculan por **variante**, no mezclando puestos ni la polea con el cojín. Corregir o deshacer una serie **recalcula**. Un día más flojo **no quita** un récord. Mensajes: «Nuevo récord personal en press de pecho: placa 6.» (sin signos de exclamación, sin comparar con nadie).

### 6.3 Historial

Por **sesión** (fecha, plantilla, versión, duración, series hechas de las planeadas, esfuerzo, energía) y por **ejercicio** (carga o repeticiones por semana en barras sencillas, con texto alternativo). El tipo de semana (`descarga`, `foco`, `reentrada`) se anota para que una caída de carga **no se lea como retroceso**.

### 6.4 Racha del entrenamiento (Propuesta PG-14)

La persona tiene un **objetivo de Hábitos** «Entrenamiento» (área `salud`, tipo `construir`, frecuencia `n_por_semana` con meta igual al número de **sesiones de fuerza** del plan: 3). Aplica la regla existente de metas semanales: **cuenta semanas, una semana incompleta rompe y no hay día de gracia** (`fase-3-habitos.md:476`, criterio 4; `:588`, P12). Las **regenerativas** son un segundo objetivo opcional que **no** rompe la racha. La semana de descarga cuenta como cumplida; una pausa declarada deja las semanas en `no_aplica`. Las rachas no reciben texto de culpa: la racha rota dice lo de `MensajesHabitos.rachaRota` (`mensajes.dart:3`).

---

## 7. Pantallas y flujos

Siguen `DISENO_UX_UI.md`: **teléfono** (sección 9, lo que se hace en el momento), **laptop** (sección 8, planear y revisar) y **tablet** (sección 11). La **personalidad Sport** (neón, números enormes, alto contraste, animación de 150 ms: H-18) se usa **solo en las pantallas en movimiento** (sesión en curso y registro rápido: `DISENO_UX_UI.md:194`); el plan, el inventario, el historial y los ajustes usan la personalidad calma de Hábitos. Todas con estados **vacío, cargando, sin conexión y error** (`DISENO_UX_UI.md:49`) y sin reintentos automáticos.

### 7.1 Mapa de pantallas

| # | Pantalla | Teléfono | Laptop | Tablet personal | Tablet pública |
|---|---|---|---|---|---|
| E1 | **Hoy** · tarjeta «Entrenamiento de hoy» (plantilla, versión, hora, duración estimada) con **Empezar** y *Hecho* | Sí | Sí | Sí | Con nombre y PIN, sin molestias |
| E2 | **Mi gimnasio › Inventario** (aparatos, puestos, bandas, accesorios, equipo futuro, *Confirmar en el aparato*) | Sí | Sí (principal) | Sí | No |
| E3 | **Mi gimnasio › Plan de la semana** (3/4/5 días, versión, ventana, hora, *Poner en mi agenda*, aviso de 48 h) | Sí | Sí (principal) | Sí | No |
| E4 | **Sesión de hoy** (vista previa: calentamiento, ejercicios, series, carga sugerida, *Cambiar ejercicio*, *Versión corta*) | Sí | Sí | Sí | Sí |
| E5 | **Sesión en curso** (pantalla completa, Sport) | Sí | Solo ver | Sí | Sí |
| E6 | **Registro rápido** («Registrar lo que hice») | Sí | Sí | Sí | No |
| E7 | **Historial** (sesiones y ejercicios) | Sí | Sí (principal) | Sí | No |
| E8 | **Récords** | Sí | Sí | Sí | No |
| E9 | **Molestias** (solo en este equipo) | Sí | **No** (no están aquí) | Solo este equipo | **Nunca** |
| E10 | **Ajustes › Mi gimnasio** (valores de 5, aviso, sobre esta guía, mis datos) | Sí | Sí | Sí | No |

**Navegación.** Dentro de Hábitos: *Salud › Entrenamiento*, con las rutas nuevas `entrenamiento`, `entrenamiento/inventario`, `entrenamiento/plan`, `entrenamiento/sesion`, `entrenamiento/historial`, `entrenamiento/records`, `entrenamiento/molestias` (relativas a `/habitos`, como `rutasHabitos`: `app/lib/modulos/habitos/habitos.dart:49`). La barra de órdenes entiende *«abre entrenamiento»* (8.5).

### 7.2 Sesión en curso (E5)

```
┌──────────────────────────────────┐
│ ◀ Fuerza A · Empuje · estándar   │
│   ≈ 36 min · ejercicio 2 de 4    │
├──────────────────────────────────┤
│ Elevaciones laterales            │
│ Polea baja                       │
│                                  │
│  SERIE   2 / 3                   │
│  REPS    12      [−] [+]         │
│  CARGA   placa 3 [−] [+]         │
│                                  │
│  ┌────────────────────────────┐  │
│  │        ✓  HECHA            │  │
│  └────────────────────────────┘  │
│  Descanso   00:48   [+15] [Saltar]│
│  Siguiente: tríceps en polea alta │
│ [Cambiar ejercicio] [Versión corta]│
│ [Terminar]                        │
└──────────────────────────────────┘
```

- **Una pantalla, una decisión.** Ejercicio, serie, repeticiones, carga y un botón de ✓ de al menos **64 dp**; el resto, de 48 dp o más.
- **Temporizador de descanso.** Arranca al tocar ✓; **cuenta hacia un instante final** (no con un contador que se pierda al pausar la app); sobrevive a girar la pantalla y a que la app pase a segundo plano. Al terminar: **vibración corta y marca visual** (nunca solo sonido ni solo color), y, si la app está en segundo plano, una **notificación local discreta** con el texto del catálogo «Termina tu descanso» (PG-18). Opcional y apagado por omisión: voz local del dispositivo que dice el siguiente ejercicio (pregunta 8).
- **Cambiar ejercicio, Versión corta, Terminar** se alcanzan sin desplazarse. **Deshacer** de la última serie, siempre visible 5 s.
- **Sin conexión:** todo funciona; abajo, la cinta «Guardado en el teléfono; se sube al volver la señal» (`DISENO_UX_UI.md:284`).
- **Pantalla encendida durante la sesión:** pedido a `plataforma` (17); la sesión **no depende de ello** para guardar.
- **Datos que se muestran en la tablet:** el gadget **«Serie y descanso»** (`DISENO_UX_UI.md:131`) a escala de tablet, legible desde 2 m (números de más de 96 dp).

### 7.3 Flujos clave

| # | Flujo | Pasos | Meta |
|---|---|---|---|
| F-E1 | **Marcar el día** (sin registrar) | Hoy → *Hecho* sobre «Entrenamiento» → «Guardado · Deshacer» | **1 toque** (regla de las 3) |
| F-E2 | **Entrenar** | Hoy → *Empezar* → (calentamiento: *Listo*) → ✓ en cada serie → *Terminar* → *Terminé la sesión* | Empezar en **1 toque**; 1 por serie; terminar en 2 |
| F-E3 | **Registrar después** | Hoy → bloque → *Registrar lo que hice* → *Todo como estaba planeado* → editar lo distinto → Guardar | 3 toques si todo salió como se planeó |
| F-E4 | **Primera vez** | Entrenamiento → aviso «guía general que no sustituye a un profesional» → *Entendido* → Inventario (viene con el Marcy, el banco y la caminadora marcados) → *Agregar bandas* → Plan (3, 4 o 5 días) → *Poner en mi agenda* | Unos 3 minutos |
| F-E5 | **Confirmar un dato del aparato** | Inventario → Marcy → *Confirmar en el aparato* → campo con instrucción («mueve el pasador a la última placa y cuenta las placas») → Guardar | — |
| F-E6 | **Agregar una molestia** | Entrenamiento → Molestias → zona → intensidad → *Guardar* («solo en este equipo») | 3 toques |
| F-E7 | **Cambiar un ejercicio** | Sesión → *Cambiar ejercicio* → alternativas con motivo → elegir | 2 toques |
| F-E8 | **Semana de descarga** | Hoy el lunes: banner «Esta semana es de descarga: menos series para recuperar. Es parte del plan» | — |

### 7.4 Tono (catálogo, ejemplos)

Todo texto sobre un día no hecho, una racha rota o una molestia sale de un catálogo con revisión automática (convención 8 de la Fase 3, CA-G-40). Ejemplos (sin signos de exclamación, de tú): «Hoy toca Fuerza A. ¿Empezamos?», «Descanso terminado. Sigue el remo.», «Esta semana es de descarga. Es parte del plan.», «Un día no borra lo que has avanzado. Retomemos hoy.» (existente), «Gracias por avisar. Cambiamos este ejercicio por otro que no cargue esa zona. Esta guía no diagnostica.».

### 7.5 Laptop

La laptop es donde se **planea y se revisa** (D4): inventario con la tabla de confirmaciones, plan de la semana con el aviso de 48 h y la vista de carga del día, historial con gráficas más amplias, récords y ajustes. Puede **registrar después** (E6) y **ver** la sesión de hoy; no es el equipo para entrenar. **No muestra ni conoce las molestias** (4.3).

---

## 8. Conexiones

### 8.1 Agenda (diseño 7.1, `diseno-app-habitos.md:483`)

1. **El plan propone; la persona confirma** (como el asistente de configuración). *Poner en mi agenda* crea, para cada día de fuerza o regenerativa, un **bloque recurrente** en `hab_bloques` (`tipo = actividad`, `area = salud`, `objetivo_id` = el objetivo «Entrenamiento», `dias` con la máscara del día, `desde` = el lunes de inicio) con duración = **duración estimada de la versión + 10 minutos de margen**. No se agrega ninguna columna a `hab_bloques`: la sesión concreta se deriva del plan por la fecha (4.4).
2. **Dónde cae.** Con `ventana = noche`, el hueco es el primero libre a partir de `noche_desde` (19:00 por omisión, diseño `:243`) que quepa; con `manana`, el hueco antes de la salida (traslado) con calentamiento más largo; con `flexible`, el mejor de los dos según el día. Usa `huecosLibres` (`agenda.dart:45`), `conflictos` (`agenda.dart:70`) y `medirCarga` (`carga_dia.dart:12`) para mostrar el efecto en el medidor del día; **un conflicto avisa y no impide guardar** (`fase-3-habitos.md:496`, criterio 24).
3. **Terminar la sesión escribe el registro** del bloque (`hab_registros`: `hecho` o `parcial`, id v5 del bloque y la fecha), así Hoy, la racha y el progreso funcionan sin cambios (H-19).
4. **Periodo de prueba:** el plan puede alternar la ventana dos semanas y dos semanas y mostrar el resultado de 5.13.

### 8.2 Sueño

El módulo de sueño (registro y plan de transición) es la etapa 6 del diseño y **no está construido** (H-16). Este bloque lee una sola cosa, detrás de una interfaz: `FuenteHoraDormir.para(fecha) → minutos del día`. Hoy lee `hab_ajustes.dormir`; cuando exista el plan de transición escalonado, la interfaz devuelve la **hora de dormir de la semana en curso** sin tocar el generador. El aviso de cercanía es el de 5.13. La **calidad del sueño** de la noche anterior alimenta la sugerencia de la regenerativa (3.5) y la comparación de ventanas (5.13) **solo cuando exista**; mientras tanto la pantalla dice «sin dato».

### 8.3 Modo foco

El dominio **sabe** calcular si un plan de hábito a eliminar está en foco (`PlanCigarrillo.enFoco`, `habito_eliminar.dart:53`), pero **nadie lo conecta con el resto de la app** (H-13). Este bloque pide una interfaz **sin causa**: `ModoFocoActivo.para(fecha) → bool`. La implementa `habitos` en G5 con una **copia local** (no se sube) que se actualiza cuando la persona abre su sección reservada; sin la llave en ese equipo, el valor es `false` y se dice «No se pudo leer el modo foco en este equipo». El generador solo recibe el booleano (5.9). El mismo booleano lo puede usar Hoy (`filtrarFoco`, `hoy.dart:57`) y los recordatorios (`modoFoco`), pero eso es un trabajo aparte.

### 8.4 Health Connect (solo como futuro)

**No se implementa en este bloque.** Cuando se haga: **solo con permiso explícito**, pedido en el momento de usarlo, verificando antes que Health Connect esté disponible (en Android 13 o anterior es una app aparte: `diseno-app-habitos.md:844`), **solo se escribe el ejercicio hecho** (tipo entrenamiento de fuerza o caminata, hora de inicio y fin; la ruta de bicicleta es del otro bloque) y **nunca**: cargas, series, esfuerzo, molestias, notas, dinero ni datos clínicos. Es un interruptor por persona y por tipo de dato. No aplica a personas bajo cuidado (D5: no usan Hábitos). Hoy no hay paquete de Health Connect (H-14).

### 8.5 GRAVITY (navegación)

Se pide a `asistente` una herramienta `habitos.abrir_entrenamiento` (`soloLocal`, solo navegación, sin escribir) y la orden *«abre entrenamiento»*; el resumen `habitos.resumen_hoy` puede contar el bloque de entrenamiento como un elemento más (no sensible). **Ninguna herramienta devuelve cargas, series ni molestias**, y nada se dice por bocinas (D6, regla 108 de la Fase 3).

### 8.6 Música y bicicleta

La lista de música «entrenamiento de fuerza A, B y C» (`diseno-app-habitos.md:1431`) es del bloque de música; aquí solo se deja un botón **«Abrir mi lista»** para cuando exista, sin integrarlo.

---

## 9. Privacidad

| Qué | Regla |
|---|---|
| **Todo local o en tu hogar** | Inventario, perfil, plan, sesiones y series van a **tu hogar** por RLS (solo tú). Las molestias **nunca** salen del equipo (4.3) |
| **Molestias y salud NO salen a ninguna IA** | En esta versión no hay IA (sección 11). Si la hay después, las molestias, zonas, peso, sueño, esfuerzo, cargas y fechas **no se envían** (11) |
| **La cuenta maestra, el cuidador, Hogar y `anon`** | No leen ni escriben nada de `hab_ent_*` (misma regla que `hab_*`, `fase-3-habitos.md:176`); el dueño y el coadministrador solo ven **lo propio** |
| **Bitácora** | Las tablas no escriben en la bitácora y el prefijo `hab_` las oculta (H-09, CA-G-26) |
| **Lo que el servidor ve de una sustitución** | La variante elegida y el motivo `otra`, nunca «molestia». Aun así, un patrón de sustituciones puede **insinuar** una molestia: riesgo residual aceptado por quedar bajo RLS (sección 15, R-7) |
| **Notificaciones** | Textos discretos del catálogo, sin nombres de ejercicios ni cargas, sin dígitos (≤ 40 caracteres): «Tu siguiente actividad empieza pronto» (existente) y «Termina tu descanso» (nuevo) |
| **Datos de equipo** | La confirmación del aparato (pasos, kg) es dato del aparato, no de salud; va en claro al hogar |
| **Borrar y exportar** | *Mis datos de Hábitos* exporta y borra por tipo; el alcance `entrenamiento` borra las seis tablas, y las molestias se borran del equipo |
| **Capturas de pantalla** | Las pantallas de molestias llevan FLAG_SECURE y se ocultan en modo privado (como lo reservado, `fase-3-habitos.md:524`); el resto del entrenamiento no es sensible |
| **Tablet pública** | Con nombre y PIN solo la parte no sensible; **nunca** molestias; sin recordatorios (regla 105 de la Fase 3, 9.2) |

### 9.1 Sin conexión

Todo lo de la sesión funciona **sin red**: el catálogo viaja con la app, el generador es local, el registro va primero a la base local y a la cola (H-12). Lo que necesita red es solo sincronizar entre equipos. **Hallazgo:** hoy Hábitos escribe directo con `upsert` y la cola no conoce sus tablas (H-12), así que **el registro de la sesión no puede copiar ese patrón**: se pide a `plataforma` agregar a la cola los tipos `habitos.gim_perfil`, `habitos.gim_plan_dia`, `habitos.gim_inventario`, `habitos.gim_banda`, `habitos.gim_sesion` y `habitos.gim_serie` (todos personales: el prefijo `habitos.` ya lo es, `cola_sin_conexion.dart:61-69`), con orden de subida por llaves (perfil, inventario, bandas y plan, luego sesiones, luego series).

### 9.2 Tablets

- **Tablet personal** (del dueño o de la pareja): como el teléfono de la persona (D21; `fase-3-habitos.md:366`, regla 106). Entrena con su PIN y ve todo salvo las molestias de otro equipo.
- **Tablet pública de la casa** (contexto *Gimnasio*): con **nombre y PIN** abre *Entrenamiento de hoy* y la sesión **de esa persona** con lo no sensible (regla 105). Problema real: la sesión dura 30 a 60 minutos y la tablet regresa al modo Casa a los **2 minutos** sin uso. **Propuesta PG-17:** mientras haya una **sesión en curso** y un toque en los últimos **10 minutos**, la sesión retiene la pantalla (y se registra como uso); pasados 10 minutos sin tocar, vuelve a Casa y la sesión **queda guardada como `en_curso`** para retomarla con el PIN. Es un pedido a `plataforma` (17) y a resolver con la pregunta 3.

---

## 10. Accesibilidad y letra grande

Siguen `DISENO_UX_UI.md:360-366` y `fase-3-habitos.md:529` (criterio 57).

- **Letra al 200 %** en 360 dp en el teléfono sin desbordes: la sesión en curso desplaza solo el contenido secundario; el botón ✓ y el temporizador **nunca salen de la pantalla**. Desde 900 dp de ancho en la laptop.
- **Zonas táctiles de 48 dp** o más; en la sesión, **64 dp** para ✓ y para el temporizador (manos con sudor, uso con una mano). Los pasos − y + de repeticiones y carga son de 56 dp.
- **Nada depende solo del color:** el estado de una serie (hecha, pendiente, en descanso, con precaución) lleva **icono y texto**.
- **Alto contraste** en la sesión (la personalidad Sport ya lo declara: H-18) y comprobación con `contraste.dart` (`app/lib/diseno/contraste.dart`); en la luz de un gimnasio o un patio, el contraste se prueba en el aparato.
- **Lector de pantalla:** cada serie anuncia «Serie 2 de 3, 12 repeticiones, placa 3, pendiente»; el temporizador anuncia el tiempo cada 15 s y al terminar; los botones tienen etiquetas; las acciones por deslizamiento tienen botón (`DISENO_UX_UI.md:351`).
- **Sin gestos finos:** nada requiere deslizar ni pellizcar durante la sesión.
- **Reducir movimiento:** el temporizador deja de animar su aro y muestra solo el número.
- **Voz y vibración:** el fin del descanso usa **vibración y marca visual**, y la voz es opcional (pregunta 8).
- **Modo foco y carga:** en carga «saturada» (`medirCarga`), la sesión propone la versión corta (mensaje existente `MensajesHabitos.saturado`, `mensajes.dart:7`).

---

## 11. IA opcional (futura; fuera de esta versión)

**En esta versión ninguna función llama a una IA** (CA-G-39). Esta sección solo deja dicho, para que nadie decida después sin leerla, **qué se podría enviar y qué nunca**.

| | |
|---|---|
| **Qué haría** | Proponer un plan semanal o cambios al plan **escogiendo entre los ids del catálogo** disponibles |
| **Cuándo** | Función **opcional**, apagada por omisión, activada por persona y **por función** (diseño `:662`), con **permiso en cada envío** (como D-ING-15) |
| **Por dónde** | La función del asistente en el servidor, con el filtro de D3 y sin la clave dentro de la app |

| **Se enviaría** (lista cerrada) | **Nunca se enviaría** |
|---|---|
| Objetivo (`fuerza`, `masa`, `perdida_grasa`, `salud_general`) y nivel | Molestias, zonas, lesiones, notas de dolor |
| Días por semana y duración preferida | Peso, medidas, edad, sexo, talla |
| **Ids** de los aparatos, puestos y accesorios disponibles (no `futuro`) | Cargas, repeticiones, esfuerzo, récords, historial |
| Ids de las variantes disponibles | Sueño, hora de dormir, fechas, horarios de la agenda |
| | Nombre, hogar, ubicación, nada que identifique a la persona |

**Cómo se mantiene seguro.** (1) El modelo **solo elige ids**; no inventa ejercicios. (2) La respuesta pasa por un **validador local** (ids conocidos, equipo disponible, series y descansos en rango, 48 h, un máximo por día) y, si falla, se descarta. (3) Lo que se aplica se muestra primero como **propuesta** que la persona acepta. (4) **Después** de aceptarla, el filtro de molestias (5.10) corre **en el dispositivo**: la IA nunca sabe de ellas. (5) El filtro de D3 del servidor rechaza una carga con claves fuera de la lista. Si algo de esto no se puede cumplir, no se activa.

---

## 12. Etapas de construcción y paquetes de trabajo

Orden de las etapas del diseño (`diseno-app-habitos.md:2451-2452`, etapa 6 «Salud»), solo para entrenamiento y sin IA. **Ningún paquete necesita una dependencia nueva**: el temporizador usa instantes, la vibración usa `HapticFeedback` del propio Flutter y la notificación usa `flutter_local_notifications` (ya en `app/pubspec.yaml:54`). **Una excepción a decidir:** mantener la pantalla encendida durante la sesión pide un paquete o un canal nativo (H-14): lo evalúa `plataforma` y lo aprueba el dueño.

| Etapa | Paquete | Agente | Entrega | Depende de |
|---|---|---|---|---|
| **G0** | Aprobar esta especificación; responder las preguntas 1 a 3; decidir la propuesta D (sección 16) | arquitecto y dueño | Preguntas contestadas; decisión registrada | — |
| **G1** | **G1.1 Catálogo y validador** | habitos | Aparatos, ejercicios, variantes, plantillas, regenerativas, zonas, mensajes; prueba de integridad (CA-G-01 a 05) | G0 |
| | **G1.2 Generador y tiempo** | habitos | Filtro, slots, bandas, versiones, modelo de tiempo, 48 h, semana (CA-G-06 a 13) | G1.1 |
| | **G1.3 Progresión y ciclos** | habitos | Doble progresión, escalera, descarga, reentrada, foco, récords (CA-G-14 a 21) | G1.2 |
| | **G1.4 Molestias, ventana y sueño** | habitos | Filtro de molestias, ventana de prueba, aviso de dormir, regenerativa (CA-G-22 a 25) | G1.2 |
| **G2** | **Servidor** | backend | Migración `hab_ent_*`; ampliación de `hab_borrar_datos_de` y `hab_cuota_filas`; RLS; pruebas SQL (CA-G-26 a 31) | Spec aprobada |
| **G3** | **Plataforma** | plataforma | Tablas locales y tipos de cola; **tercer tipo `salud_local`** en el almacén de sobres; pantalla encendida; notificación local de descanso; retención de la tablet; FLAG_SECURE en molestias; rutas (CA-G-32, 35 a 38) | G2 (nombres de columnas) |
| **G4** | **Diseño** | diseno | Gadget «Serie y descanso», temporizador de descanso, selector de carga, tarjeta de aparato, línea de la semana, barras de historial, maquetas E1 a E10; estados vacío/cargando/sin conexión/error (CA-G-41) | Spec aprobada |
| **G5** | **App Hábitos** | habitos | Casos de uso y pantallas E1 a E10; conexión con Agenda, Hoy, sueño y modo foco; `ModoFocoActivo`; herramientas (CA-G-32 a 44) | G1, G3, G4 |
| **G6** | **Calidad** | calidad | Revisión de cierre, mediciones en el Galaxy A52 y en la tablet, sin IA ni Health Connect, contenido médico | G5 |
| **G7** | **Asistente** | asistente | `habitos.abrir_entrenamiento`, orden de navegación, OpenAPI de las tablas nuevas | G2 |
| *Después* | Health Connect (8.4); IA opcional (11); equipo futuro como generador; estructuras distintas de A, B, C | — | — | Decisión del dueño |

**Orden sugerido.** G0, luego **G1, G2 y G4 en paralelo**, después G3 y G5 (G5 puede empezar con un repositorio en memoria, como Hábitos hizo en la Fase 3: `app/lib/modulos/habitos/datos/repositorio.dart:16`), G7 cuando exista G2 y G6 al final. **Lo que depende del dueño no bloquea:** los datos del Marcy y las bandas se capturan en la app (F-E5) y el contenido sale marcado `borrador` hasta su revisión.

---

## 13. Criterios de aceptación

Dónde van las pruebas: **dominio** `paquetes/habitos_dominio/test/gimnasio/` (`cd paquetes/habitos_dominio && dart test`); **app** `app/test/modulos/habitos/gimnasio/` (`cd app && flutter analyze && flutter test`); **servidor** `supabase/tests/` con el siguiente número libre (hoy el último es el 121); **manual** en el Galaxy A52, la laptop y la tablet, anotado en `docs/revisiones/`. Los nombres de archivo son propuestas. Cada criterio incluye al menos un **caso malo**.

### 13.1 Catálogo (G1.1)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-G-01 | **Integridad del catálogo:** los ids son únicos y en minúsculas sin acentos; cada ejercicio tiene al menos una variante; cada id de `requiere` existe en aparatos, puestos o accesorios; los grupos y zonas son del catálogo; `reps_min < reps_max`; cada slot tiene al menos un candidato. **Caso malo:** una variante con un `requiere` inexistente falla la prueba | `catalogo_test.dart` |
| CA-G-02 | **Las sesiones del diseño están:** A, B y C tienen los slots, series y repeticiones de `diseno-app-habitos.md:230-232` (A1 press 3×10–12, A2 lateral 3×12–15, A3 tríceps 3×12, A4 fondos 3×8–12, B1 a B4, C1 a C5 con la plancha de 30 a 45 s) en la **primera** opción de cada slot | `catalogo_test.dart` |
| CA-G-03 | **Sin contenido médico:** ningún texto del módulo contiene diagnóstico, tratamiento, medicamento, dosis ni nombre de lesión (lista de palabras prohibidas); todo aviso de molestia incluye «profesional», «médico» o «entrenador». **Caso malo:** agregar «tendinitis» a un texto falla | `contenido_medico_test.dart` (como el criterio 59 de la Fase 3) |
| CA-G-04 | **«Confirmar en el aparato» no entra a los cálculos:** con `pasos_max` o `kg_por_paso` en estado `confirmar`, la carga se muestra en pasos, no hay conversión a kg y no se detecta el tope de la pila; al confirmarlos sí. **Caso malo:** la pila de 68 kg del diseño (`del_diseno`) se muestra «aprox.» y **no** se usa para detectar el tope | `confirmaciones_test.dart` |
| CA-G-05 | **Revisión:** un ejercicio, variante o plantilla `borrador` hace que la sesión muestre «Contenido en revisión»; con todo `revisado` desaparece. **Caso malo:** una variante nueva sin campo `revision` falla | `catalogo_test.dart` |

### 13.2 Generador (G1.2)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-G-06 | **Filtro por inventario:** con Marcy, banco y caminadora disponibles, A = press en la estación, lateral en polea baja, tríceps en polea alta y fondos; B = jalón, remo, face pull y curl en el cojín; C = sentadilla al banco, subidas, puente con apoyo en el banco, patada en polea baja (si hay tobillera; si no, con banda) y plancha. **Sin estación** (todos sus puestos `no_disponible`): A usa press con banda (si hay ancla) o flexiones inclinadas, lateral con banda pisada, tríceps con banda y fondos. **Sin Marcy y sin bandas:** A queda con flexiones inclinadas, fondos y plancha (3 ejercicios); si quedaran menos de 3, `sin_equipo_suficiente` y **no se inventa ninguno** | `generador_test.dart` |
| CA-G-07 | **Bandas y anclajes:** una variante con `ancla: puerta` **no** se ofrece sin `ancla_puerta`; con `ancla: estacion` no se ofrece si no se confirmó el punto de anclaje; `pisar` siempre; sin ninguna banda activa no se ofrece ninguna variante de banda. **Caso malo:** una banda con cantidad 0 o `activa = false` no cuenta | `bandas_test.dart` |
| CA-G-08 | **El Marcy gana:** con el Marcy disponible, ningún slot usa banda salvo por elección de la persona; con un puesto `no_disponible`, solo los slots de ese puesto cambian a banda | `generador_test.dart` |
| CA-G-09 | **Equipo futuro es solo dato:** un inventario con `mancuernas` en estado `futuro` genera **exactamente las mismas sesiones** que sin él, y la pantalla lo lista aparte («cuando lo tengas»). **Caso malo:** ninguna variante se ofrece por un aparato `futuro` | `equipo_futuro_test.dart` |
| CA-G-10 | **Tiempo estimado:** con los parámetros de 5.5, A, B y C dan corta 29.3, 29.3 y 31.2 min; estándar 35.3, 35.3 y 45.8; larga (4 series, sin extras) 48.4, 48.4 y 63.1; larga con extras 60.9 (A) y 61.3 (B). Las tolerancias (corta 27–33, estándar 33–50, larga 48–65) se cumplen; **caso malo:** un cambio de la regla de series que mueva A estándar fuera de 33–50 falla | `duracion_test.dart` |
| CA-G-11 | **Elegir versión** (duración estimada + 10 min de margen): para C, con un hueco de 75 min elige larga (63.1 + 10 = 73.1) y con 70 elige estándar (45.8 + 10 = 55.8); para A, con 40 min elige corta (29.3 + 10 = 39.3) y con 38 **no cabe ninguna** y propone mover el bloque o la regenerativa (no hay cuarta versión) | `version_test.dart` |
| CA-G-12 | **Calibración:** tras 3 sesiones con `descanso_real_s` y tiempos de repetición propios, la estimación usa la mediana de la persona; con menos de 3, usa los valores de 5.5 | `duracion_test.dart` |
| CA-G-13 | **Plan semanal 3, 4 y 5 días:** la función devuelve por omisión las tres filas de 5.6 (semana reordenada: A, C, B; R2 jueves y R1 viernes); sábado `bici` y domingo `descanso` en todos; las regenerativas ya no caen en martes; las variantes `cEnJueves` y `cEnViernes` devuelven las filas anteriores y no se pueden pedir juntas | `plan_semana_test.dart` |

### 13.3 Semana, progresión y ciclos (G1.2 y G1.3)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-G-14 | **48 horas:** los cuatro casos de 5.6 (47 h 15 min cumple; 46 h 30 min avisa; 24 h avisa; dos sesiones el mismo día avisa); la bicicleta del sábado a las 8:00 con C el viernes a las 20:00 (12 h) avisa y propone mover C al jueves, C corta o dejarlo; con C el jueves (36 h 45 min) avisa; **con la semana por omisión (C el martes, 84 h 45 min) no avisa**; **nunca bloquea** | `cuarenta_y_ocho_horas_test.dart` |
| CA-G-15 | **Sesión perdida:** saltar una sesión no cambia la carga sugerida (se compara con la última vez que se hizo); mover la sesión respeta las 48 h con aviso; no se permiten dos de fuerza en un día | `sesion_perdida_test.dart` |
| CA-G-16 | **Doble progresión:** los cuatro ejemplos de 5.8 (12-12-12 con esfuerzo 3 sube a la placa 6 con objetivo de 10; 12-12-11 mantiene; 12-12-12 con esfuerzo 5 mantiene; sesión saltada sin cambio); sin esfuerzo registrado se asume 3 | `progresion_test.dart` |
| CA-G-17 | **Escalera sin carga:** con el tope de la pila confirmado, los peldaños se aplican **en orden** (repeticiones, series, tempo, descanso, variante, banda) y ninguno se salta; sin confirmar el tope **no** se ofrece la escalera salvo que la persona marque «ya estoy en la última placa». **Caso malo:** subir una placa más allá de `pasos_max` falla | `progresion_test.dart` |
| CA-G-18 | **Descarga:** con inicio el lunes 30/nov/2026 y ciclo 3 + 1, las semanas 30/nov, 7/dic y 14/dic son de carga y la del 21/dic es de descarga (2 series, mínimo del rango, una placa menos, sin subir); la siguiente empieza el 28/dic; con `ciclo_semanas = 0` nunca hay descarga programada; dos sesiones seguidas con esfuerzo 5 **sugieren** una descarga y no la imponen | `descarga_test.dart` |
| CA-G-19 | **Reentrada:** 6 días, normal; 7 y 13, repetir cargas; 14, semana de reentrada (2 series, una placa menos); 56, cargas de prueba; una pausa declarada no cuenta como días sin sesión | `reentrada_test.dart` |
| CA-G-20 | **Modo foco:** con `modoFoco = true` no hay incrementos de carga, repeticiones ni series, el contador del ciclo no avanza y el tipo de semana es `foco`; la sesión sigue disponible con versión corta sugerida; al terminar el foco el ciclo retoma donde estaba. **Caso malo:** el generador no recibe ni expone qué hábito causó el foco | `modo_foco_test.dart` |
| CA-G-21 | **Récords:** mejor carga, mejores repeticiones, mejor tiempo y mejor banda por variante; corregir o deshacer una serie recalcula; un día más flojo no quita un récord; polea y cojín no se mezclan | `records_test.dart` |

### 13.4 Molestias, ventana y regenerativa (G1.4)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-G-22 | **Filtro por molestia:** con una molestia de `hombro` leve, el press de A queda «con precaución» y se ofrece una alternativa sin esa zona; moderada, se sustituye o se omite el slot; fuerte, además el aviso de consultar a un profesional y se propone la regenerativa; ninguna salida nombra una lesión ni un tratamiento | `molestias_test.dart` |
| CA-G-23 | **Ventana de prueba:** el ejemplo de 5.13 (noche 5 de 6 con energía media 3.6; mañana 3 de 6) sugiere la noche; con menos de 4 sesiones planeadas en una ventana dice «faltan datos»; con diferencias menores de 15 puntos y de 0.5 de energía dice «sin diferencia clara». **Caso malo:** nunca cambia la ventana sola | `ventana_prueba_test.dart` |
| CA-G-24 | **Aviso de dormir:** con `dormir` a las 22:00 y margen 90, una sesión que termina a las 20:15 no avisa (105 min) y una que termina a las 21:30 avisa (30 min) con las opciones en orden; cambiar el margen cambia el aviso | `aviso_dormir_test.dart` |
| CA-G-25 | **Regenerativa:** 20 a 40 min; R1 de ~28 min y R2 de ~37 min; sin series, cargas ni récords; «Cansado» propone R1; sin caminadora cambia a marcha suave | `regenerativa_test.dart` |

### 13.5 Servidor (G2)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-G-26 | **RLS:** el dueño no lee lo de la pareja ni al revés; el coadministrador no lee lo del dueño; la cuenta maestra, el cuidador, Hogar y `anon` no leen ni escriben nada de `hab_ent_*`; una persona dada de baja pierde el acceso. **Bitácora:** una entrada con tabla `hab_ent_series` es rechazada y no se muestra al dueño ni a la maestra | `supabase/tests/NNN_hab_ent_rls.sql` |
| CA-G-27 | **Esquema y rangos:** `dias_plan` solo 3, 4 o 5; `esfuerzo` y `energia` de 1 a 5; `carga_pasos` de 0 a 60; `reps` de 0 a 100; `motivo_cambio` solo `no_disponible`, `preferencia` u `otra` (**el valor `molestia` se rechaza**); `inicio_ciclo` solo un lunes; el servidor pone `persona_id`, `hogar_id` y `actualizado_en`; el último cambio gana por `modificado_en` y uno en el futuro lejano se ajusta | `supabase/tests/NNN_hab_ent_esquema.sql` |
| CA-G-28 | **Las molestias no llegan al servidor:** un sobre de tipo `salud_local` es **rechazado** por la restricción de `hab_sobres.tipo`; no existe columna de molestia, zona ni dolor en ninguna tabla `hab_ent_*` | `supabase/tests/NNN_hab_ent_sin_molestias.sql` |
| CA-G-29 | **Borrar mis datos:** `hab_borrar_mis_datos('todo')` y el alcance `entrenamiento` borran las seis tablas; el borrado de una baja a los 90 días las incluye; una tabla ausente de la lista falla la prueba (H-10) | `supabase/tests/NNN_hab_ent_borrado.sql` |
| CA-G-30 | **Cuotas:** superar el tope de filas de `hab_ent_series` da 54000; una tabla sin tope en `hab_cuota_filas` falla la prueba | `supabase/tests/NNN_hab_ent_cuotas.sql` |
| CA-G-31 | **Idempotencia:** insertar la misma sesión o serie con el mismo id v5 no duplica; con el mismo id y otro contenido gana el de `modificado_en` más reciente | `supabase/tests/NNN_hab_ent_idempotencia.sql` |

### 13.6 App y plataforma (G3 y G5)

| # | Criterio | Cómo se comprueba |
|---|---|---|
| CA-G-32 | **Sin conexión:** la sesión, el registro y el historial funcionan sin red; lo hecho se encola con los tipos `habitos.gim_*` y sube con el **mismo id** al volver la señal; el reintento no duplica. **Caso malo:** un registro escrito directo con `upsert` (patrón de H-12) falla la prueba de la cola | `cola_gimnasio_test.dart` (y ampliar `contrato_servidor_test.dart`) |
| CA-G-33 | **Pocos toques:** *Hecho* en Hoy es 1 toque; empezar la sesión desde Hoy es 1 toque; una serie es 1 toque (valores sugeridos); terminar es 2; registrar después con «Todo como estaba planeado» es 3 | `toques_gimnasio_test.dart` (pasos) |
| CA-G-34 | **Registro de series:** ✓ guarda lo sugerido; − y + cambian reps y carga sin teclado; deshacer quita la última serie; la fusión de dos equipos con series intercaladas converge al mismo estado | `registro_series_test.dart` |
| CA-G-35 | **Temporizador:** termina en el instante calculado aunque la app pase 30 s a segundo plano (reloj falso); sobrevive a girar la pantalla; +15 s, −15 s y Saltar; la notificación local usa el texto discreto del catálogo; con «reducir movimiento» no anima | `temporizador_test.dart` (reloj y programador falsos); **manual:** que llegue en segundo plano en el A52 (alarmas inexactas, riesgo R-5) |
| CA-G-36 | **Molestias solo locales:** se guardan solo en el almacén local cifrado con la llave local; ninguna cola ni consulta a la red las contiene (se busca una cadena marcada en todo lo persistido y en todo lo enviado con un cliente falso); el almacén de molestias no aparece en el respaldo automático de Android; la pantalla lleva FLAG_SECURE. **Caso malo:** activar la nube de `habitos_sensibles` no sube las molestias | `molestias_locales_test.dart`; **manual:** FLAG_SECURE |
| CA-G-37 | **Agenda:** con el día tipo del diseño (trabajo hasta las 18:00, traslado de 1 hora, llegada ~19:00) y ventana de noche, el plan de 3 días propone bloques a las 19:15 con duración = estimada + 10; un conflicto avisa sin impedir guardar; el medidor del día incorpora los minutos; terminar la sesión escribe `hecho` o `parcial` en `hab_registros` con el id v5 del bloque y la fecha | `agenda_gimnasio_test.dart` |
| CA-G-38 | **Tablets (D21):** la **pública** con nombre y PIN ve **solo** Hoy, Sesión de hoy y Sesión en curso (**ni el historial ni los récords**, ni el aviso de «nuevo récord» al terminar: eso se ve en el teléfono, la laptop o la tablet personal; corregido el 25/nov/2026) y **nunca** las molestias ni recibe recordatorios; la **personal** se comporta como el teléfono; una sesión en curso retiene la pantalla con un toque en los últimos 10 minutos y, pasados, vuelve a Casa y la sesión queda `en_curso`. **Caso malo:** el texto «Todavía no está en la tablet de la casa» (H-15) desaparece | pruebas de widget (como el criterio 50 de la Fase 3); **manual** en la tablet |
| CA-G-39 | **Sin IA ni Health Connect:** ningún archivo de `gimnasio` importa el cliente del asistente ni llama a `gravity-asistente`; un cliente HTTP falso no registra ninguna petición durante una sesión completa; no hay permiso de Health Connect en el manifiesto ni paquete en `pubspec.yaml` | `sin_ia_test.dart` (dependencias y cliente falso) + revisión de calidad |
| CA-G-40 | **Tono y mensajes:** ningún mensaje del módulo usa *fallaste, fracaso, perdiste, culpa, castigo, vergüenza* ni `!` (`MensajesHabitos.prohibidas`, `mensajes.dart:25`); los nuevos textos de avisos (`hab_descanso`) no tienen dígitos ni más de 40 caracteres; el aviso de molestia usa solo las plantillas del catálogo | `mensajes_gimnasio_test.dart` (amplía las pruebas de mensajes y de avisos discretos) |
| CA-G-41 | **Accesibilidad:** letra al 200 % en 360 dp (teléfono) y desde 900 dp (laptop) sin desbordes; ✓ y temporizador de 64 dp o más y resto de 48 dp o más; cada serie anuncia su estado con texto; nada depende solo del color; contraste mínimo del tema | `accesibilidad_gimnasio_test.dart` (como el criterio 57 de la Fase 3); **manual:** lectura bajo el sol |
| CA-G-42 | **Roles:** dueño, coadministrador y familiar ven el entrenamiento; cuidador, Hogar y la cuenta maestra no lo ven | `gimnasio_por_rol_test.dart` (plataforma) |
| CA-G-43 | **Modo foco conectado:** con `ModoFocoActivo = true` el generador no sube carga; sin la llave en el equipo devuelve `false` y la pantalla lo dice | `modo_foco_app_test.dart` |
| CA-G-44 | **Herramienta de GRAVITY:** `habitos.abrir_entrenamiento` es `soloLocal` y no escribe; ninguna herramienta devuelve cargas, series ni molestias | prueba del registro de herramientas |
| CA-G-45 | **Contenido revisado:** una persona competente revisa los ejercicios, las variantes y los avisos; la revisión queda con fecha en `docs/revisiones/` y el catálogo pasa de `borrador` a `revisado` | **Manual** (dueño y calidad) |

---

## 14. Pruebas: qué se automatiza y qué solo se prueba en el dispositivo

**Automatizable** (CA-G-01 a 34 y 37, 39 a 44): todo el dominio es una función pura probada con tablas de ejemplos; el servidor con pruebas SQL (`supabase/tests/correr.sh`); la app con pruebas de widgets y de casos de uso con **reloj, programador de notificaciones y cliente HTTP falsos**.

**Solo en dispositivo** (las hace el dueño o calidad, y se anotan en `docs/revisiones/`):

| Qué | Dónde | Por qué no se automatiza |
|---|---|---|
| El temporizador y su notificación **llegan con la app en segundo plano y la pantalla apagada** | Galaxy A52 | Android puede retrasar alarmas inexactas con el ahorro de batería (`fase-3-habitos.md:625`, observación 7) |
| **Pantalla encendida** durante 45 minutos | A52 y tablet | Depende del canal nativo |
| **Legibilidad al sol o con luz de gimnasio** y con manos mojadas | A52 y tablet | No se mide con una prueba de contraste |
| **FLAG_SECURE** en molestias; el almacén de molestias fuera del respaldo de Android | A52 | Es de plataforma |
| **La sesión retiene la tablet** y vuelve a Casa; el contexto Gimnasio | Tablet | Depende del dispositivo |
| **Los datos reales del Marcy** (pasos, kg, anclajes, banco) | En el aparato | Solo se verifican con el aparato en la mano |
| **Vibración** y voz opcional | A52 y tablet | Depende del hardware |
| **Revisión por una persona competente** del contenido | — | No es comprobable por código |

---

## 15. Riesgos

| # | Riesgo | Mitigación |
|---|---|---|
| R-1 | **El contenido de ejercicios se toma por consejo profesional.** Es una lista de ejercicios comunes, no una valoración | Línea fija «guía general que no sustituye a un profesional»; todo en `borrador` hasta una revisión (PG-25, pregunta 1); sin diagnósticos ni tratamientos (CA-G-03); la app no pregunta ni guarda condiciones médicas |
| R-2 | **Datos del Marcy sin confirmar** (pila, kg por placa, puestos, anclajes, banco) | Cada dato lleva estado; lo no confirmado no entra a ningún cálculo (CA-G-04); la persona los confirma en la primera sesión (F-E5) |
| R-3 | **Las duraciones del diseño no coinciden con las plantillas** (H-08) | Se muestra la duración estimada real; las etiquetas son metas con tolerancia; se calibra con el uso (5.5) |
| R-4 | **C el viernes y la bicicleta el sábado** (H-07): piernas sin las 48 h | Aviso, no bloqueo, con tres salidas; la semana por omisión (C el martes) ya no lo dispara (sección 22) |
| R-5 | **El temporizador en segundo plano llega tarde** (alarmas inexactas) | El temporizador cuenta contra un instante final; la notificación es una ayuda; con la app en pantalla es exacto; medición en el A52 |
| R-6 | **Frecuencia de una vez por semana por grupo muscular** (3 sesiones A, B, C): progresa despacio | Es el diseño del dueño; la escalera sin carga (5.8) y la estructura configurable posterior lo compensan; no es un error |
| R-7 | **Un patrón de sustituciones insinúa una molestia** en el servidor | RLS por persona; el motivo `molestia` no existe (CA-G-27); riesgo aceptado y mostrado en la pregunta 7 |
| R-8 | **Las molestias se pierden si se pierde el teléfono** (solo local) | Entran al respaldo local cifrado con la frase; se avisa al activarlas |
| R-9 | **El modo foco no está conectado** (H-13) | G5 lo conecta con una interfaz sin causa; mientras no esté, el generador funciona sin foco y la pantalla lo dice |
| R-10 | **Hábitos escribe directo y sin cola** (H-12) | El módulo usa la cola desde el inicio (CA-G-32); es un pedido a `plataforma` |
| R-11 | **Una banda desgastada o mal anclada se suelta** | Aviso fijo de revisión (5.4); las variantes de `estacion` no se ofrecen hasta confirmar el anclaje |
| R-12 | **Un ejercicio mal explicado se hace mal** | Explicación breve y errores comunes por ejercicio, revisados con el contenido (CA-G-45); sin videos ni imágenes en esta versión |
| R-13 | **El coach de GRAVITY (Fase 6) quiera estos datos** | La sección 11 fija lo que nunca se envía; cualquier función nueva entra por una especificación |
| R-14 | **La tablet pública regresa a Casa en plena sesión** | PG-17 y CA-G-38; la sesión queda guardada y se retoma con el PIN |

---

## 16. Propuestas de esta versión (y qué pasa si se vetan)

| # | Propuesta | Dónde | Si se veta |
|---|---|---|---|
| PG-01 | Catálogo como datos Dart del dominio | 3 | JSON en `app/assets/gimnasio/` con pedido a `diseno` |
| PG-02 | Prefijo `hab_ent_*`, tablas editables con último-gana | 4.2 | Otro prefijo exige ampliar bitácora y listas |
| PG-03 | Tercer tipo local `salud_local` para las molestias (no admite nube) | 4.3 | Clase dentro de `habitos_sensibles`, con el riesgo de subirse con la nube |
| PG-04 | La carga se guarda en **pasos** de la pila, no en kg; los kg solo si se confirmó cuánto vale un paso | 3.2, 4.2 | Pedir los kg desde el inicio |
| PG-05 | La sesión concreta se deriva al abrirla; no se guarda un plan generado | 4.4 | Guardar el plan generado (más historial, más desincronización) |
| PG-06 | Las etiquetas 30, 45 y 60 son metas con tolerancia y la duración real se muestra; modelo de tiempo y calibración; cierre de 3 min en la corta | 3.4, 5.5 | Fijar las series para llegar a 45 en A y B |
| PG-07 | 48 h inicio a inicio con 60 min de tolerancia; avisa, no bloquea; la bicicleta cuenta como piernas | 5.6 | Bloquear, o ignorar la bicicleta |
| PG-08 | Doble progresión (una sesión al máximo con esfuerzo ≤ 4) y escalera sin carga | 5.8 | Exigir dos sesiones seguidas |
| PG-09 | Descarga cada 4.ª semana (3 + 1), editable; sugerida antes con dos sesiones de esfuerzo 5 | 5.9 | Solo descarga reactiva |
| PG-10 | Reentrada por días sin sesión de fuerza (7, 14 y 56) | 5.9 | Siempre carga normal |
| PG-11 | Modo foco: sin incrementos y ciclo detenido, sin saber la causa | 5.9, 8.3 | Sin relación con el foco |
| PG-12 | Esfuerzo percibido de 1 a 5 | 2 | Escala de 1 a 10 |
| PG-13 | Al terminar, la persona elige «Terminé la sesión» o «Terminé una parte» | 6.1 | Un umbral de series hechas |
| PG-14 | La racha del entrenamiento es un objetivo `n_por_semana` de las sesiones de fuerza; las regenerativas no rompen | 6.4 | Una racha propia |
| PG-15 | Aviso si la sesión termina a menos de 90 minutos de dormir | 5.13 | Otro margen o sin aviso |
| PG-16 | Regla de la sugerencia de ventana (15 puntos, 0.5 de energía, 4 sesiones) | 5.13 | Otros umbrales |
| PG-17 | La sesión retiene la tablet 10 minutos desde el último toque | 9.2 | Que la sesión solo se haga en el teléfono o en la tablet personal |
| PG-18 | Texto de aviso discreto «Termina tu descanso» (tipo local `hab_descanso`) | 7.2 | Sin notificación de descanso |
| PG-19 | El motivo de cambio no incluye «molestia» | 4.2, 5.10 | Registrar el motivo real |
| PG-20 | Serie de aproximación en el primer ejercicio | 3.6 | Sin aproximación |
| PG-21 | Objetivo y nivel solo cambian valores por omisión; los principiantes tienen 2 semanas de adaptación | 5.11 | Quitar objetivo y nivel |
| PG-22 | Bandas: alternativa y progresión; carga = banda usada; sin convertir a kg si no se leyó la etiqueta | 5.4 | Solo bandas como alternativa |
| PG-23 | Primer arranque: la primera serie fija el punto de partida | 5.12 | Un protocolo de pruebas |
| PG-24 | Sesión perdida: se mueve o se salta, sin recuperarla ni acumularla | 5.6 | Recuperar con dos sesiones |
| PG-25 | Todo el catálogo nace `borrador` hasta una revisión | 3 | Publicar sin revisión (no se recomienda) |
| **D** (decisión nueva para `DECISIONES.md`) | **«Entrenamiento: primera versión sin IA, con reglas y contenido fijo; la IA queda como función opcional posterior; molestias solo en el dispositivo (tercer tipo local); bandas en el inventario»**, aplicada con el visto bueno del dueño del 23/nov/2026. Extiende D21 (un tercer tipo sensible local) | 1, 4.3, 11 | — |

---

## 17. Pedidos a otras áreas

| Área | Pedido | Sección |
|---|---|---|
| **backend** (G2) | Migración con las **seis** tablas `hab_ent_*` de 4.2 (checks de rango y de lista, claves compuestas, único `(persona_id, fecha, plantilla)`, RLS, privilegios por columna, `hab_propio()` y `hab_ultimo_gana`); ampliar `hab_borrar_datos_de` (alcance `todo` y alcance nuevo `entrenamiento`), `hab_cuota_filas` y la baja a 90 días; **no** crear columna ni tabla de molestias; pruebas SQL de CA-G-26 a 31; entrada en `supabase/README.md` (qué ve y qué no ve el servidor) | 4.2, 13.5 |
| **plataforma** (G3) | Tablas locales espejo y tipos de cola `habitos.gim_*` con niveles de subida (H-12); **tercer tipo local `salud_local`** en el enum y en el almacén de sobres, forzado a `solo_telefono`, excluido de la subida diferida y del respaldo de Android, con FLAG_SECURE y modo privado; mantener la pantalla encendida durante la sesión (paquete o canal nativo, lo aprueba el dueño); notificación local del descanso con el tipo `hab_descanso` en el catálogo discreto y en los canales de recordatorios; retención de la sesión en la tablet (PG-17) y quitar el texto de H-15; recordatorios con `modoFoco` real; rutas `entrenamiento/…`; roles | 4.3, 7, 9 |
| **diseno** (G4) | Gadget **Serie y descanso**, temporizador de descanso (instante final, sin animación con «reducir movimiento»), selector de carga con − y +, tarjeta de aparato con estado de confirmación, línea de la semana (con aviso de 48 h), barras de historial con texto alternativo, estados vacío, cargando, sin conexión y error; maquetas E1 a E10 en personalidad Sport donde corresponde (H-18) | 7, 10 |
| **asistente** (G7) | `habitos.abrir_entrenamiento` (`soloLocal`, sin escribir), orden *«abre entrenamiento»*, el bloque en `habitos.resumen_hoy` sin cargas ni molestias, y las tablas nuevas en `api/openapi.yaml` | 8.5 |
| **calidad** (G6) | Revisión de cierre: contenido médico, RLS, sin IA ni Health Connect (CA-G-39), molestias solo locales (CA-G-36), accesibilidad, mediciones en el A52 y la tablet, y el registro de la revisión del contenido por una persona competente | 13, 14 |
| **arquitecto** | Registrar la decisión **D** de la sección 16; actualizar el diseño (`diseno-app-habitos.md:193`, `:210-211`, `:674`) con el inventario con bandas y «sin IA primero»; confirmar el número de bloque; asignar migración y número de prueba SQL; en `docs/ROADMAP.md` 11.4, una fila para este bloque | 1.6, 16 |

---

## 18. Preguntas para el dueño

Solo las que de verdad cambian el diseño. Cada una trae mi recomendación. **Si no respondes, vale lo que dice el documento.** Las 1 a 3 conviene contestarlas antes de construir; las demás no bloquean.

| # | Pregunta | Por qué cambia el diseño | Recomendación |
|---|---|---|---|
| 1 | **¿Quién revisa el contenido de los ejercicios?** El catálogo (ejercicios, variantes con banda, plantillas, textos de molestias) lo redacta una IA sin ser profesional. ¿Lo revisa una persona competente (entrenador o fisioterapeuta) antes de usarlo? | Mientras no se revise, todo sale `borrador` y la sesión lo dice (PG-25, CA-G-45) | **Sí, una sola vez** (una hora o dos con el catálogo en mano) y registrar la fecha. Sin esa revisión se puede usar, con la línea «Contenido en revisión» |
| 2 | **Datos de tu equipo.** ¿Puedes verificar en el aparato: cuántas placas tiene la pila y cuántos kg es cada una, si la polea es 1:1 o 2:1, qué otros puestos tiene el Marcy, si hay punto de anclaje seguro para bandas, si el banco se ajusta a plano y cuánto aguanta, si hay tobillera para la polea? ¿Qué bandas tienes (cuántas, colores o etiquetas, resistencia) y hay ancla de puerta? | Hasta confirmarlos, la carga va en «placas», no hay tope de pila ni variantes con ancla en la estación (3.2) | Confirmarlos **en la primera sesión** (F-E5) y capturar las bandas en el inventario. Sin ancla de puerta ni punto en la estación, solo se usan bandas pisadas |
| 3 | **¿Qué tablet llevas al gimnasio: la pública de la casa («Hogar») o una personal?** | Con la **pública**, la sesión necesita retener la pantalla (PG-17) y solo ve lo no sensible; con la **personal**, funciona como el teléfono (9.2) | Cualquiera sirve. Si es la pública, aprobar PG-17 (10 minutos desde el último toque); si es la personal, no hace falta |
| 4 | **¿Mueves la sesión C (pierna) al jueves?** Con C el viernes por la noche y la ruta de 4 h el sábado a las 8:00 hay solo 12 horas de descanso para las piernas (H-07) | Cambia el plan por omisión y, en el de 5 días, mueve R2 al viernes | **Sí, al jueves** en los planes de 3, 4 y 5 días (en el de 5, R2 pasa al viernes). Si no, C el viernes con el aviso. *Superado el 24/nov/2026: el dueño eligió la semana reordenada (C el martes), sección 22.* |
| 5 | **Semana de descarga: ¿cada 4.ª semana (3 + 1) o solo cuando la app la sugiera?** | Cambia el ciclo por omisión (5.9) | **Cada 4.ª semana**, editable, y además sugerida antes si hay dos sesiones al límite. Tú decides en cada caso |
| 6 | **Ventana de prueba: ¿empezamos por la noche (tu plan del diseño: fuerza después de las 19:00, `:243`) o por la mañana?** El diseño se contradice (H-06) | Cambia el valor por omisión de `ventana` y el orden de las dos semanas de prueba | **Noche** dos semanas; luego la mañana solo si el sueño y la hora de despertar lo permiten (depende del plan de transición de sueño) |
| 7 | **¿Basta con que las molestias estén solo en el dispositivo?** Las cargas, series y esfuerzo van a tu hogar en claro (solo tú los ves). Un patrón de ejercicios sustituidos podría insinuar una molestia (R-7) | La alternativa es cifrar también las series con un sistema como el del diario (D13), con su frase y más trabajo | **Sí, basta.** Las molestias en el equipo (y en el respaldo con la frase); las series en tu hogar |
| 8 | **¿Tu nivel y tu objetivo de partida?** El diseño pide objetivo (fuerza, masa, pérdida de grasa, salud general) y nivel. Aquí solo cambian los valores por omisión (5.11). ¿Y quieres voz que anuncie el siguiente ejercicio en el descanso? | Cambia el rango de repeticiones y las semanas de adaptación; la voz depende del motor de voz | **Salud general y principiante** (2 semanas de adaptación) si llevas más de 3 meses sin entrenar con regularidad; si no, intermedio. **Voz apagada** hasta que el motor de voz esté probado |

---

## 19. Historial de versiones

Este archivo contiene **solo el bloque 7 de la Fase 8** (entrenamiento propio); la ruta en bicicleta y la música, el sueño y la IA opcional se especificarán aparte.

| Versión | Fecha | Cambio |
|---|---|---|
| **0.1** | 23/nov/2026 | Primera versión (agente `habitos`). Cumple las decisiones del dueño del 23/nov/2026: inventario con bandas, primera versión sin IA, IA opcional posterior, equipo futuro solo como dato y molestias solo en el dispositivo. Verificado contra el diseño v1.18, `fase-3-habitos.md`, `fase-8-habitos-ampliaciones.md` y el código de `paquetes/habitos_dominio`, `app/lib/modulos/habitos` y `supabase/migrations/2026110*` (20 hallazgos H-01 a H-20 y 7 conflictos C-1 a C-7). 25 propuestas PG-01 a PG-25 y 8 preguntas al dueño |


## 20. G0 cerrado (23/nov/2026): el dueño ordena construir

El dueño respondió «Comienza la construcción de gimnasio» (23/nov/2026) tras ver el resumen de esta especificación, **sin contestar una por una las preguntas de la sección 18**. Como el propio documento dice «si no respondes, vale lo que dice el documento», **el arquitecto toma como vigentes las recomendaciones** y las registra aquí para que nadie las vuelva a abrir por accidente:

- **Aprobadas por omisión (vetables en cualquier momento):** la especificación completa (PG-01 a PG-25), con la **propuesta D: tercer tipo sensible local `salud_local`** (extiende D21; las molestias nunca salen del dispositivo) y **PG-17** (la tablet pública retiene la sesión 10 min desde el último toque). Preguntas 4 (sesión C al jueves), 5 (descarga cada 4.ª semana), 6 (noche primero), 7 (molestias solo en el equipo) y 8 (salud general y principiante; voz en el descanso apagada).
- **Pregunta 1:** el contenido sale **`borrador`** y la sesión lo dice (PG-25, CA-G-45) hasta que una persona competente lo revise; el dueño tiene hoy su primera cita con un fisioterapeuta (23/nov/2026) y puede pedirle esa revisión; **no bloquea**.
- **Pregunta 2:** los datos del Marcy y las bandas se **capturan en la app** (F-E5); nada de ellos entra a un cálculo mientras esté «confirmar en el aparato». El dueño confirmó que el inventario es la Marcy, el banco inclinado, la caminadora y **bandas** (sin pesas libres).
- **Pregunta 3:** pendiente del dueño; no bloquea (G3 hace que funcione con la tablet pública y con una personal).
- **Fuera de alcance de esta construcción (no se agrega ningún paquete):** mantener la pantalla encendida (H-14) queda **sin hacer** hasta que `plataforma` lo evalúe y el dueño apruebe el paquete o el canal nativo.
- **Orden:** G1, G2 y G4 en paralelo; después G3 y G5; G7 cuando exista G2; G6 al final (sección 12).


## 21. Estado de la construcción (23/nov/2026)

**G1 (dominio), G2 (servidor) y G4 (diseño) hechos en lo técnico y verificados por el arquitecto**; G3 (plataforma), G5 (app), G6 (calidad) y G7 (asistente) sin hacer. Pruebas: `habitos_dominio` 228 (44 anteriores + 184), SQL 5169 afirmaciones (354 nuevas, migración `20261152`, pruebas 122 a 127), app 3990 (1295 en diseño y calidad). Nada probado en un aparato ni contra un Supabase real.

**Interpretaciones del agente de G1 que el dueño debe conocer** (informe de G1, vetables):
1. **Mover C al jueves NO resuelve la bicicleta del sábado:** con C el jueves a las 19:15 y la ruta el sábado a las 8:00 hay 36 h 45 min, menos de las 47 h de la regla; el aviso sigue (con C el viernes eran 12 h, ahora son 36). La pregunta 4 mejora el intervalo, no lo cierra; opciones: C corta, dejarlo, o la ruta más tarde.
2. Los tiempos de 5.5 se **truncan** a una décima (63.15 → 63.1); los extras de la sesión larga usan sus propias series (3); «3×12» va codificado 10–14 y «3×10 por pierna» 8–12 porque CA-G-01 exige `reps_min < reps_max`; la plancha extra de A y B es 30–30 s.
3. **CA-G-22 (hombro leve) no tiene alternativa sin esa zona en el catálogo real:** todas las variantes de press cargan el hombro; salen «con precaución». El agente no inventó diferencias clínicas; que haya alternativas lo decide la revisión del contenido (pregunta 1).
4. **CA-G-13** se cumplió con C el jueves (decisión del dueño); `cEnViernes: true` devuelve las filas literales de 5.6. *Nota del 24/nov/2026: superado por la decisión 3 de la sección 22; hoy la omisión es la semana reordenada y C el jueves es la variante `cEnJueves: true`.*
5. La calibración usa `tiempos` solo locales (no hay columna en 4.2); la progresión es una función pura del historial.

**Pedidos pendientes a otras etapas:** G3 (cola `habitos.gim_*` con el orden de subida del informe de G2, `salud_local`, retención de la tablet, FLAG_SECURE); G5 (armar `lunesEnFoco`, medir `tiempos`, ids UUID v5, mapear a las columnas de 4.2, reemplazar el gadget viejo `SerieDescanso`); G7 (documentar `hab_ent_*` en `api/openapi.yaml`). Decisiones de diseño: el acento de día de Sport pasó a `0xFF356000` (contraste 7.43:1); el catálogo de estilos tiene tres (Futurista, Glass, Bento en pausa), no cuatro.


## 22. Decisiones del dueño del 24/nov/2026

1. **Pantalla encendida durante la sesión (H-14): aprobado un canal nativo, sin paquete nuevo** (mismo tipo de canal que ya usa FLAG_SECURE). Se prueba en el Galaxy A52. La laptop y la tablet pública no lo necesitan.
2. **Molestias: sin PIN.** Basta FLAG_SECURE y modo privado (como pide 9 y como ya está en G3).
3. **Choque de 48 h con la bici: el dueño eligió la semana reordenada (24/nov/2026):** lunes A, martes C, miércoles B, jueves libre (descanso), viernes R1 (regenerativa suave), sábado bicicleta, domingo descanso. Por tamaño: **3 días** = A, C, B; **4 días** = además R1 el viernes; **5 días** = además R2 el jueves y R1 el viernes. Cumple la regla de 48 h sin excepciones: A lunes 19:15 → B miércoles 19:15 = 48 h (comparten hombro); C martes 19:15 → ruta sábado 8:00 = 84 h 45 min; A→C y C→B no comparten grupo. **Es el plan por omisión de `planSemanal(dias)`** y con él no sale el aviso de la bicicleta. **Variantes que quedan** (editables, con el aviso de siempre): `cEnJueves: true` (A-R1-B-C-R2: 36 h 45 min con la ruta, avisa) y `cEnViernes: true` (tabla literal del diseño A-R1-B-R2-C: 12 h 45 min, avisa y propone mover C al jueves). Queda abierta, solo si la persona elige una variante, la propuesta «mover C al martes» en el aviso de la bicicleta (ver `fase-8-habitos-bicicleta.md`, 12.2).
4. **Bicicleta:** primero la versión sin paquetes (B1 a B7) **y también** el mapa y el visor (V2), este último solo como **evaluación** de paquetes (licencia, compatibilidad y compilación; B8) y sin instalar nada en la app hasta que el dueño apruebe paquetes concretos. Ver `docs/specs/fase-8-habitos-bicicleta.md`.


## 23. G5 hecho y verificado (24/nov/2026)

Pantallas reales E1 a E10 (`app/lib/modulos/habitos/gimnasio/`), casos de uso, lector Supabase (solo lee, una vez por arranque, sin conexión sigue con lo local), modo foco con copia local, hora de dormir, Agenda y tarjeta en «Hoy». Suite de app 4326 pruebas en verde (92 nuevas), `flutter analyze` con los 7 avisos antiguos, `pubspec` y manifiesto sin cambios. Cuatro pruebas de G3 (`gimnasio_por_rol_test.dart`) pasaron de comprobar la maqueta «Pantalla provisional» a comprobar la pantalla real; ninguna expectativa de roles, equipos ni FLAG_SECURE se relajó. **Nada probado en aparato ni contra un Supabase real.**

**Pendiente de G5 (documentado, no bloquea):** «ya estoy en la última placa» (falta dónde guardarlo), pausas declaradas hacia el generador, cerrar o retomar una sesión que quedó en curso de un día anterior, cambiar ejercicio desde la vista previa, detalle de sesión en el historial, editar el tipo de día en el plan, ruta propia de «Mis datos de Hábitos»; paginación del lector sin desempate en empates de `modificado_en`. **Pedido a diseño:** retirar el gadget viejo `SerieDescanso` (`futuros.dart`) y pasar la maqueta de G4 a la semana reordenada. **Preguntas al dueño:** si una semana cuenta como «en foco» cuando cualquier día lo está, y si «Hecho» sin series cuenta para el objetivo «Entrenamiento».

**Falta de la construcción:** G6 (revisión de calidad y mediciones en el Galaxy A52 y la tablet) y la revisión del contenido de ejercicios por un profesional (CA-G-45).

## 24. Cierre de G6: sin señal, aviso del banco y dormir pasada la medianoche (24/nov/2026)

Corrección de los hallazgos G6-A1, G6-M3 y G6-M4 de `docs/revisiones/fase-8-gimnasio.md`. **Nada probado en aparato ni contra un Supabase real.**

- **G6-A1 (sin señal).** `ServicioGimnasio` ya no lanza si la agenda o los registros de Hábitos no responden. Al **abrir lo de hoy**, la agenda que no se puede leer se sustituye por los ajustes por omisión y ningún bloque (no se inventan huecos ocupados que no se vieron); la pantalla lo dice sin culpa («No pude leer tu agenda ahora; la hora es aproximada…») y la sesión se arma con el plan y el equipo de este equipo. Al **terminar** (y en *Hecho* y *Registrar lo que hice*), la sesión se guarda primero en el equipo, el registro del día y el objetivo «Entrenamiento» se intentan escribir como siempre y, si fallan, quedan en la cola con los tipos personales `habitos.registro` (upsert por `id`, último gana) y `habitos.objetivo` (insertar sin pisar, para no deshacer lo que la persona haya cambiado); el objetivo sube antes que el registro. La pantalla nunca muestra una excepción cruda: «No se pudo guardar en la nube; queda en este equipo y se enviará.» *Poner en mi agenda* sí necesita señal (la agenda vive en la nube): sin ella dice que el plan sigue en este equipo y que se intente con señal.
- **G6-M3 (aviso del banco).** Antes de la primera sesión que usa el banco (fondos, subidas, sentadilla al banco, puente apoyado) sale una tarjeta que recomienda comprobar en el aparato su capacidad y su estabilidad, con *Ya lo revisé*. **Una sola vez por persona**, guardado solo en este equipo (copia local, `gim_banco_revisado`); no impide empezar. Sale en E4 y en el calentamiento de E5.
- **G6-M4 (dormir pasada la medianoche).** `dormirNormalizadoMin` reduce la hora de dormir con módulo 1440 y toma la de la madrugada (00:00 hasta la hora de despertar) como del día **siguiente**; lo usan `avisoDormir` y el cálculo del hueco libre y del tiempo libre desde la hora del plan.


## 25. Decisiones del dueño del 25/nov/2026 (tras la revisión G6)

1. **M2, modo foco:** al servidor sube `carga`, **no** `foco`; el foco se calcula y se queda en el dispositivo (sin huella de cuándo empezó el hábito a eliminar). Cambia `servicio_gimnasio.dart` (~656) y su prueba.
2. **Tablet pública:** **no ve el historial ni los récords**; solo Hoy, Sesión de hoy y Sesión en curso (7.1 manda; CA-G-38 se corrige en ese sentido). El historial se ve en el teléfono o la laptop.
3. **Música:** el alcance de borrado `bicicleta` **no borra** `hab_musica_listas`. El dueño usará la música como **módulo propio** más adelante (cocinar, leer, bici, gimnasio, orar y quizá trabajar): la tabla es de ese módulo futuro, no de la bici ni del gimnasio.
4. **Pantalla encendida:** también en tablets Android (como está construido); se libera a los 10 minutos de inactividad.
5. **Semana «en foco»:** si cualquier día de la semana lo está (como está construido).
6. **«Hecho» sin series NO cuenta** para el objetivo «Entrenamiento»: para contar hay que registrar al menos una serie; «Hecho» sin series queda como nota de la sesión (cambia lo que hizo G5: 9, decisión propia 8 de la sección 23).
7. **A1 (sin señal):** la sesión sigue con lo local y encola lo pendiente (corrección en curso). **M1:** llaves por persona (hecho, migración 20261154). **Hábitos:** se corrigen en la misma tanda los ids de `hab_revisiones` y `hab_marcas_biblia`, que no incluían a la persona.

### 24.1 Decisiones del 25/nov/2026 aplicadas en la misma tanda

- **M2.** Al iniciar la sesión, `semana_tipo = foco` se guarda y se sube como `carga` (el check del servidor admite `carga`, `descarga`, `reentrada` y `foco`; no se tocó `supabase/`). El foco se calcula y se muestra en el dispositivo; la progresión ya no distingue localmente las sesiones hechas en foco.
- **«Hecho» sin series no cuenta.** `terminarSesion` solo escribe el registro del objetivo «Entrenamiento» (y lo crea) si la sesión tiene al menos una serie. Sin series, la sesión y el bloque de la agenda quedan hechos (la nota del día) y la pantalla dice: «Queda como nota del día. Para sumar a tu objetivo, registra al menos una serie.» (`ResultadoSesion.sinSeries`). Deshacer *Hecho* sin series tampoco toca el objetivo.
- **Tablet pública.** Sin historial ni récords (ya estaba así en `gimnasioDisponibleEn`); además, al terminar una sesión no muestra el aviso de «nuevo récord». CA-G-38 corregido.

