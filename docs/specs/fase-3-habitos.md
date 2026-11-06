# Especificación — Fase 3: Hábitos MVP

> Versión 0.2 (1/nov/2026): incorpora las respuestas del dueño (D21 confirmada): sensibles solo teléfono por ahora, frase de 12 palabras, tablet personal como el teléfono y pública sin nada, copia diaria con aviso a la pareja, baja con borrado a los 90 días, fecha de inicio de los planes fijada por cada miembro. Versión 0.1: borrador. Base: `docs/ROADMAP.md` (secciones 6, 11 y 11.4), `docs/DECISIONES.md` (D1, D3, D5, D13, D14, D15, D17, D18, D19 y D20), el diseño de HÁBITOS v1.18 (`docs/modulos/habitos/diseno-app-habitos.md`: secciones 3, 4, 5.1, 5.6, 6, 7.1, 7.2 y 10; Anexo D espiritual; Anexo F hábitos a eliminar; Anexo G, pantallas G.10.1 Hoy y G.10.3 panel de hábito a eliminar; Anexo H, etapas 1 a 5), `docs/DISENO_UX_UI.md` (secciones 5, 6, 9, 11, 12, 17, 20 y 21) y la especificación de la Fase 2 (`docs/specs/fase-2-finanzas.md`), de la que **reutiliza la infraestructura de avisos (D20)**. Se aplican las convenciones de `docs/specs/fase-0-cimientos.md`, sección 4.
>
> Las preguntas para el dueño están en la **sección 9**, cada una con su propuesta por defecto. Lo que el diseño dejó ambiguo se resolvió con la interpretación más conservadora y se marca como **(interpretación; P#)**.
>
> **Qué cambia respecto del diseño por D1.** El diseño v1.18 era una app Android aparte con Firebase. En GRAVITY: base local (drift) como fuente principal y Supabase (D7) para sincronía y laptop; **no hay archivos JSON ni enlaces `habitos://` entre módulos** (D1); la sección 5.8 y el Anexo B (conexión con Presupuesto) y el paso 12 del asistente **no se construyen**: Alimentación llegará a Hábitos dentro de la app en la Fase 7. La IA, el coach y todo lo que mande datos de Hábitos a un servicio de IA **no existen** en esta fase.
>
> **Qué ya existe y NO se vuelve a hacer:** la matriz `permisos_rol` ya tiene `habitos` con alcance `propio` para dueño, coadministrador y familiar (ni el dueño ve lo de otros, D13); `dispositivos` con `tipo` y `recibe_avisos`; `avisos_preferencias` (zona horaria, horas silenciosas, `tipos_silenciados`); `registrar_dispositivo`; la sesión y el PIN, el bloqueo del teléfono (1 min), los montos ocultos y FLAG_SECURE; la cola sin conexión por persona; el registro de herramientas de GRAVITY (`habitos.*` ya se admite en el formato); el catálogo discreto y su revisión automática (`TextoAviso`, `avisos_discretos_test`), los canales y el permiso `POST_NOTIFICATIONS` de Fase 2. La Fase 3 los **usa**; no los duplica.

---

## 1. Resultado utilizable

**Saber qué toca hoy y marcarlo en pocos toques, dejar el cigarrillo y el exceso de azúcar con un plan propio y una ayuda a un toque cuando llega el antojo, leer la Biblia con un plan y orar, y cerrar la semana con una revisión tranquila, sin culpa y sin que nada sensible salga del control de la persona.**

- **Laptop (Dueño, Pareja, Familiar con laptop):** haces el **asistente de configuración**; creas objetivos con el **asistente SMART**; armas la **agenda** (día, semana y mes) con huecos libres y conflictos; configuras el plan de cigarrillo y de azúcar y ves los **patrones** (si el modo de ese dato es *cifrado en la nube*); lees la Biblia (RVR1909 y KJV), llevas un **plan de lectura**, escribes el **devocional** y el **diario de oración**; ves el **progreso** y haces la **revisión semanal** del sábado.
- **Teléfono:** abres **Hoy** y marcas, pospones u omites (1 toque); registras un cigarrillo o una porción de azúcar en **1 toque con Deshacer**; pides ayuda con **"Tengo un antojo" (SOS)** en 1 toque desde Hoy, el (+) o un atajo; lees, haces el devocional y oras; recibes **recordatorios locales con acciones**, también sin señal, y el aviso de la revisión semanal.
- **Sin culpa:** ninguna pantalla pinta de rojo un día fallado ni dice "fallaste"; la racha rota se llama *"retomemos"*; el **día de gracia** protege la racha; las recaídas son datos para ajustar el plan.
- **Dos modos para lo sensible (D13):** el diario de oración y los hábitos a eliminar se guardan **cifrados en la nube** (se cifran en el dispositivo; la llave la guarda solo la persona, con una **frase de recuperación**) o **solo en el teléfono**. Por defecto, **solo en el teléfono**.

**Reglas de oro de la fase (D3, D13, D14):** (1) **nada de Hábitos va a la IA en la nube, a las bocinas ni a la tablet pública**; (2) **un aviso o recordatorio de un hábito sensible nunca dice cuál hábito es ni cuántos**; (3) **ni el servidor, ni el dueño del proyecto, ni la cuenta maestra, ni el dueño del hogar** pueden leer lo sensible de otra persona; (4) el ahorro de los hábitos eliminados se queda dentro de Hábitos y **no se comparte con Finanzas**; (5) **el aviso o texto no culpa**.

---

## 2. Alcance

### 2.1 Entra en el MVP de Hábitos

| Módulo | Qué entra | Diseño |
|---|---|---|
| **Núcleo** | Objetivos de 3 tipos (construir hábito, alcanzar meta, proyecto) con **asistente SMART** y plantillas; **Hoy** (tarjeta *Sigue*, lista por franja, hecho / posponer / omitir con Deshacer); registro; **rachas con día de gracia**, racha global y mínimos del día; pausas; **medidor de carga del día**; modo foco | 3, 4.1, 4.2, 6; G.10.1; H etapa 1 |
| **Hábitos a eliminar** | **Cigarrillo** y **azúcar**: configurar, **línea base de 7 días**, fases (línea base, reducción, preparación, **Día D**, libre, mantenimiento), registro en 1 toque con Deshacer, límites del día, semáforo del refresco ocasional, **recaídas sin culpa**, mejor racha y días libres acumulados, motivos, disparadores, reemplazos, "si… entonces", hitos de **constancia**, ahorro privado (oculto por defecto), patrones, apoyo | 5.6; F.1 a F.7, F.10 a F.15; G.10.3; H etapa 2 |
| **SOS "Tengo un antojo"** | Flujo de 6 pasos con temporizador de 10 minutos, registro rápido de 30 s y contador de antojos superados; en el teléfono desde Hoy, el (+) y un atajo con etiqueta discreta | F.5; H etapa 2 |
| **Agenda y asistente** | Vistas día, semana y mes; bloques recurrentes con excepciones; horario laboral fijo y traslado como bloques; búsqueda de huecos y conflictos; **asistente de configuración** (8 pasos, pausable) con semana tipo y medidor de carga; recordatorios locales con acciones | 7.1, 7.2; H etapa 3 |
| **Espiritual (MVP)** | **Lector** con **RVR1909 y KJV** (dominio público) sin conexión, cambio de versión sin perder notas, notas y subrayados; **planes de lectura** (ruta de inicio con Juan, Nuevo Testamento en 90 días, Salmos y Proverbios en 30, Biblia en un año canónica, por libro) con *ponerse al día*, *saltar* y *reiniciar*; **devocional** con plantilla (y versión breve); **diario de oración** (pendiente, en espera, respondida), listas de intercesión y temporizador; recordatorio de dar **opcional**; *Espiritual hoy* | 5.1; D.1 a D.4, D.6, D.7, D.12, D.14, D.17 (1 a 6 y 13); H etapa 4 |
| **Progreso y revisión** | Gráficas por área, calendario de constancia, rachas; **revisión semanal de los sábados** (aviso 15 minutos antes, pasos guiados, ajustes de la semana siguiente); metas de lectura de páginas como objetivos con plantilla | 4.3; F.6; H etapa 5 |
| **Datos sensibles (D13)** | Dos modos por tipo, cifrado de extremo a extremo, **frase de recuperación**, añadir laptop, cambiar de modo, reinicio, bloqueo de la sección, modo privado | D13; F.12; sección 4.2 a 4.4 |
| **Exportar y borrar** | Exportar mis datos de Hábitos (archivo, con aviso de privacidad) y borrar por tipo o todo | F.12 |
| **Recordatorios y herramientas** | Recordatorios locales discretos con acciones; atajos de pantalla de inicio; herramientas de GRAVITY solo locales (resumen de hoy y navegación) | G.6; D1 |

### 2.2 Queda fuera (y a dónde va)

| Queda fuera | Va a |
|---|---|
| **IA y coach** (rutinas, tutor, análisis de patrones, ayuda con la oración o el estudio), **mensajes a la IA en la nube** | Nunca para lo sensible (D3, D13); coach en GRAVITY, Fase 6 |
| **Conexión con Presupuesto** (plan de comidas, cumplimiento, archivos JSON, enlaces `habitos://`, Anexo B, paso 12 del asistente) | Cambia por D1: plan de comidas dentro de la app en la **Fase 7** |
| **Health Connect** (peso, agua, sueño, ejercicio) | Fase 8+ |
| Salud (sueño con plan de transición, entrenamiento, suplementos, medidas, citas médicas), bicicleta y música, inglés y **modo traslado** | Fase 8+ (etapas 6 a 8 del Anexo H). En la agenda solo existen el **horario laboral** y el **traslado como bloque** |
| **SOS por voz y por audio mientras se maneja**, widget de Android "Sigue / antojo", comandos de voz | Voz: Fase 6 (GRAVITY). Widget: Fase 4. El atajo de la pantalla de inicio sí entra |
| Estudios guiados, "de la Biblia a la práctica", estudio por métodos, memorización, ayuno, iglesia, concordancia, diccionarios, **comparador y lectura paralela**, audio, planes cronológico, temático y personalizado | Fase 8+ (etapas 9 y 11). Comparador, memorización y audio: v1.1 del área espiritual |
| **Versiones con licencia** (RVR1960, NVI) | Cuando el dueño resuelva la licencia (P10); el lector usa un proveedor intercambiable (regla 78) |
| **Modo pareja** (objetivos, peticiones y rachas compartidas, mensajes de ánimo, compañero de apoyo, "estoy orando por ti") | Fase 8+ (etapa 10). En esta fase **nada se comparte** con nadie |
| Revisión **mensual** y rueda de la vida, módulo de libros (biblioteca, citas), insignias y niveles | Fase 8+ (P19). Los libros se cubren con objetivos de páginas (regla 7) |
| Google Calendar (sincronía en ambos sentidos), turnos rotativos, widget | Fase 8+ |
| **Hitos de salud** (qué mejora en el cuerpo con el tiempo) y líneas de ayuda sin verificar | Se publican solo con una fuente oficial que el dueño valide (reglas 55 y 56; P16) |
| Avisos de Hábitos por Firebase | No en esta fase (regla 117; P15) |
| Dosis, medicamentos o recomendaciones médicas | **Nunca**: la app no recomienda ni dosifica (F.1) |

---

## 3. Convenciones propias de la Fase 3

Además de la sección 4 de la Fase 0 y las de la Fase 1 y 2 que apliquen:

1. **Personal por persona.** Todo registro de Hábitos es de **una persona** (`persona_id`). Ningún rol lee lo de otra persona: ni dueño, ni coadministrador, ni la cuenta maestra (D13, D19). Papá, la cuidadora y la cuenta Hogar no usan Hábitos.
2. **Día y semana.** El día es la **fecha local del dispositivo** (`date`, 00:00 a 23:59); la semana empieza en **lunes** (convención de la Fase 0). Las horas del día se guardan como `time` local sin zona; solo los instantes (`modificado_en`, `hecho_en`) llevan zona.
3. **Sin contadores guardados.** Rachas, mejor racha, días libres, promedios, semáforos, avance de planes, carga del día y ahorro **se calculan** desde los registros en el dominio; nunca se guardan. Así un reintento, una edición o un cambio de dispositivo no los desincroniza.
4. **Enteros.** Cantidades en `int` (cigarrillos, porciones, minutos, capítulos, páginas). Los promedios y los porcentajes se calculan en **centésimas enteras** y se redondean **a la mitad hacia arriba** (R1 de las fases anteriores). El dinero del ahorro, si se usa, va en centavos.
5. **Ids estables.** UUID v5 para lo que no debe duplicarse al reintentar: el registro de un elemento en un día (de `bloque_id` u `objetivo_id` y la fecha), la revisión de una semana, cada día de un plan de lectura (del plan y el número de día) y el documento cifrado (regla 90). Lo demás, UUID v4 del dispositivo.
6. **Último cambio gana** por `modificado_en` (reloj del dispositivo, con tope de 5 minutos en el futuro) para los datos en claro; los documentos cifrados se **fusionan por elemento** (regla 91).
7. **Identificadores** en español sin acentos (`HabitoEliminar`, `RachaHabito`, `faseDelHabito`, `ponerAlDia`). Tablas `hab_*` en el servidor.
8. **Textos sin culpa.** Toda cadena que la app muestre sobre un día fallado, una racha rota o una recaída sale de un **catálogo de mensajes** (`MensajesHabitos`, en el dominio) con una revisión automática: sin las palabras *fallaste, fracaso, perdiste, culpa, castigo, vergüenza*, sin signos de alarma y sin rojo (regla 21).
9. **Nada fijo en el código.** Horarios, cantidades, límites, porcentajes, plantillas de objetivos y de planes, listas de alimentos, el catálogo de técnicas del SOS y las listas de versículos viven en **plantillas y configuración** (archivos de datos versionados del módulo), no en las pantallas (Anexo H, regla técnica 1).
10. **Sensible es una propiedad del dato, no de la pantalla.** Un dato es sensible por su **tipo** (sección 4.2). Lo derivado de un dato sensible **hereda** su tipo y su modo: se calcula en el dispositivo y no se guarda en claro.

---

## 4. Modelo de datos

La verdad del dato vive en **dos lugares**: (a) la **base local** del dispositivo (drift), que funciona sin señal y es la fuente de las pantallas, y (b) Supabase, con RLS, para sincronizar entre teléfono y laptop. Lo **sensible** (4.2) además se cifra **antes** de salir del dispositivo.

### 4.1 Tablas en claro del servidor (backend)

Todas llevan `hogar_id uuid not null references public.hogares`, `persona_id uuid not null references public.personas` (por defecto `public.persona_actual()`), RLS activado, privilegios por columna y **sin** trigger de bitácora (regla 98). Fechas `date`, horas `time`, instantes `timestamptz`. Migraciones nuevas, sin editar ninguna existente: `20261105000000_habitos_nucleo.sql` y `20261106000000_habitos_cifrado.sql` (o el siguiente número libre). Todas las tablas de abajo traen `modificado_en timestamptz not null` (lo manda el dispositivo; trigger `hab_ultimo_gana`, convención 6) y `actualizado_en timestamptz not null default now()` (lo pone el servidor; sirve para la sincronía por incremento).

| Tabla | Campos principales | Notas |
|---|---|---|
| `hab_ajustes` | `persona_id` (PK), `areas_activas text[]`, `minimos_modo` (`por_area`/`marcados`), `gracia_semanal smallint` (0 a 2; 1), `despertar time`, `dormir time`, `franjas jsonb` (cortes de mañana/trabajo/noche), `revision_dia smallint` (1 a 7; 6), `revision_hora time` (14:30), `revision_aviso_min smallint` (15), `dar_activo bool` (false), `dar_dia smallint`, `dar_hora time`, `versiones_biblia text[]` (`{rvr1909,kjv}`), `version_principal`, `version_secundaria`, `aviso_nombre_objetivos bool` (false), `etiqueta_atajo text` (`Pausa`), `bloqueo_reservado_min smallint` (2), `umbral_carga_pb smallint[2]` (`{5000,8500}`), `asistente jsonb` (pasos hechos, pausados y omitidos), `epoca_nube int` (0) | Una fila por persona con rol que tenga Hábitos; la crea el servidor (trigger como el de `avisos_preferencias_sincronizar`); la app solo hace UPDATE. **Sin ninguna palabra clave sensible**: los hábitos a eliminar no aparecen aquí |
| `hab_modos` | `persona_id`, `tipo` (`habitos_sensibles`/`diario_oracion`), `modo` (`solo_telefono`/`nube_cifrada`), `cambiado_en`; PK (`persona_id`, `tipo`) | Dos filas por persona, ambas `solo_telefono` al crearse. Solo cambia con `hab_cambiar_modo` (regla 89) |
| `hab_objetivos` | `id`, `titulo` (≤ 120), `area` (`espiritual`/`salud`/`educacion`/`personal`/`laboral`/`proyectos`), `tipo` (`construir`/`meta`/`proyecto`; **no existe** `eliminar`: ese tipo vive en el documento cifrado), `unidad` (≤ 20: `minutos`, `paginas`, `veces`, `capitulos`, `dias`, `pct`…), `meta_valor int` (> 0, nulo en `construir` sin cantidad), `frecuencia` (`diaria`/`dias_semana`/`n_por_semana`/`semanal`/`total`), `dias_semana smallint` (máscara lun = 1 a dom = 64), `veces_por_semana smallint`, `fecha_inicio`, `fecha_objetivo` (nula), `prioridad smallint`, `minimo bool`, `esencial bool`, `motivo` (≤ 200, nulo), `nombre_en_aviso bool` (false), `plantilla text` (nula), `estado` (`activo`/`pausado`/`logrado`/`archivado`), `hitos jsonb` (solo `proyecto`: lista de {id, titulo, fecha, hecho}) | Un objetivo **no** se borra desde la app: se archiva (ids y registros estables) |
| `hab_bloques` | `id`, `titulo` (≤ 120), `area`, `tipo` (`actividad`/`trabajo`/`traslado`/`revision`/`cita`), `objetivo_id` (nulo), `inicio time`, `duracion_min smallint` (0 a 1440), `dias smallint` (máscara), `cada_semanas smallint` (1), `desde date`, `hasta date` (nula), `minimo bool`, `esencial bool`, `recordar_min smallint` (nulo = sin recordatorio), `activo bool` | Bloque recurrente. Un bloque de un **hábito sensible** no se guarda aquí sino en el documento cifrado (regla 63) |
| `hab_registros` | `id` (UUID v5 del elemento y la fecha), `objetivo_id` (nulo), `bloque_id` (nulo), `fecha`, `estado` (`pendiente`/`hecho`/`parcial`/`omitido`/`pospuesto`), `valor int` (nulo), `movido_a time` (nulo), `motivo_omision` (nulo; lista cerrada `cansancio`/`sin_tiempo`/`imprevisto`/`otro`) | Check: al menos uno de `objetivo_id` o `bloque_id`. Único por (`persona_id`, `coalesce(bloque_id, objetivo_id)`, `fecha`). Deshacer = volver a `pendiente` |
| `hab_pausas` | `id`, `objetivo_id` (nulo = todos), `desde`, `hasta`, `motivo` (`descanso`/`viaje`/`salud`/`otra`) | Sin texto libre |
| `hab_planes_lectura` | `id`, `tipo` (`ruta_inicio`/`nt_90`/`salmos_proverbios_30`/`biblia_1_ano`/`libro`), `nombre` (≤ 80), `fecha_inicio`, `dias_semana smallint` (127), `version_biblica` (`rvr1909`/`kjv`), `estado` (`activo`/`pausado`/`terminado`/`archivado`), `libro smallint` (solo `libro`) | Un plan activo por objetivo de lectura; pueden convivir varios |
| `hab_plan_dias` | `plan_id`, `dia int` (1 a 400), `fecha`, `segmentos jsonb` (lista de {libro, cap_ini, cap_fin}), `estado` (`pendiente`/`hecho`/`parcial`/`saltado`), `hecho_en`; PK (`plan_id`, `dia`) | Se **materializa** al crear o reprogramar (≤ 400 filas). Crear va por `hab_crear_plan_lectura` (una sola transacción) |
| `hab_lecturas` | `id`, `fecha`, `libro smallint` (1 a 66), `cap_ini`, `cap_fin`, `minutos` (nulo), `plan_id` (nulo) | Lectura suelta o la que cierra un día del plan |
| `hab_marcas_biblia` | `id`, `tipo` (`subrayado`/`marcador`), `referencia` (código `libro:cap:ver_ini-ver_fin`), `color` (lista cerrada de 6, nulo en marcador) | **Sin texto libre.** Las notas del lector son sensibles (regla 85) |
| `hab_revisiones` | `id` (UUID v5 de la persona y la semana), `semana date` (lunes), `estado` (`pendiente`/`en_curso`/`completada`/`omitida`), `programada_para timestamptz`, `completada_en`, `resumen jsonb` (porcentajes por área **no sensible**), `ajustes jsonb` (lista de {accion, objeto_id}), `dar_cumplido bool` (nulo) | Único por (`persona_id`, `semana`). Las respuestas escritas van en el documento cifrado del diario (regla 97). Nada de `resumen` viene de un dato sensible |
| `hab_sobres` | Ver 4.2 | Documentos cifrados |
| `hab_llaves` | Ver 4.3 | Llave de datos envuelta |

**Vistas:** ninguna. **Datos de ejemplo:** `seed.sql` crea para el hogar ficticio objetivos, bloques, un plan y registros **inventados** de una persona de prueba y **sobres de bytes aleatorios** (nunca texto de hábitos reales).

### 4.2 Tipos sensibles y sobres cifrados (D13)

Hay **dos tipos sensibles**. Cada uno tiene su modo, su documento y su llave derivada:

| Tipo (`hab_modos.tipo`) | Qué contiene (todo lo siguiente es sensible) |
|---|---|
| **`habitos_sensibles`** | Los hábitos a eliminar (cigarrillo y azúcar): configuración (estrategia, fechas, Día D, porcentajes, motivos, disparadores, reemplazos, "si… entonces", listas verde / amarilla / roja, límite del refresco ocasional, precio y preferencia de ahorro, personas de apoyo), cierres de día, **registros de consumo**, **antojos y sesiones del SOS**, **recaídas**, hitos vistos, los **bloques y tareas de agenda** ligados a esos hábitos (cita médica, refuerzos, Día D) y los recordatorios de esos hábitos |
| **`diario_oracion`** | Peticiones de oración (con su estado y respuesta), listas de intercesión, **sesiones de oración**, **devocionales escritos**, **notas del lector** y las **respuestas escritas de la revisión semanal** |

**Qué no es sensible** (queda en claro con RLS propio): objetivos de los otros tipos, agenda no ligada a hábitos sensibles, registros de cumplimiento, planes de lectura y su avance, lecturas, subrayados y marcadores (sin texto), revisiones (sin texto), ajustes. **(interpretación; P1):** ampliar el diario a devocionales y notas mantiene los dos tipos de D13; si el dueño prefiere un tercer tipo (`diario_estudio`), es un valor más en la lista.

**Tabla `hab_sobres`** (sólo contiene lo cifrado):

| Campo | Contenido |
|---|---|
| `id uuid` | **Opaco**: primeros 16 bytes de `HMAC-SHA256(llave_de_ids, tipo ‖ clave_doc)`; el servidor no puede ligar un sobre a una fecha |
| `persona_id`, `hogar_id` | Dueña del sobre |
| `tipo` | `habitos_sensibles` o `diario_oracion` (el servidor solo ve el tipo, no la clase de registro) |
| `revision int` | Sube de 1 en 1 en cada versión; el servidor rechaza una menor o igual |
| `cifrado text` | base64url de `versión(1 byte) ‖ nonce(12) ‖ texto cifrado ‖ etiqueta(16)` (AES-256-GCM) |
| `llave_version int` | Versión de la llave de datos con la que se cifró |
| `eliminado bool` | Tumba (la limpieza nocturna borra las de más de 30 días) |
| `creado_en`, `actualizado_en` | Hora del **servidor** (el momento real de cada registro va dentro del sobre) |

**Documentos** (lo que cifra cada sobre; `clave_doc` solo existe dentro del cifrado): por tipo, un documento `config` (singleton), y documentos `dia:AAAA-MM-DD` (todo lo del día) y, en el diario, `peticiones:AAAA` (las peticiones por año de creación). Cada documento es un JSON `{v, elementos: {id: {clase, modificado_en, eliminado, datos}}}` de **máximo 64 KB**; si se acerca, se parte (`dia:AAAA-MM-DD:2`). Un **solo sobre por día y tipo** reduce lo que el servidor puede inferir (cuántos registros hubo y a qué hora) a "hubo actividad ese día".

**Cifrado (el dominio define el formato; la app implementa las primitivas con `pointycastle`, ya en el proyecto):** AES-256-GCM, nonce aleatorio de 96 bits, **datos asociados** `gravity-hab-v1|persona|tipo|id|revision` (impide cambiar un sobre de lugar). Llave por tipo = `HKDF-SHA256(llave_maestra, info = "gravity-hab/v1/" + tipo)`; llave de ids = `HKDF(…, "gravity-hab/v1/ids")`. El dominio expone una interfaz `Cifrador` (`cifrar`, `descifrar`, `derivar`) con una implementación **falsa para pruebas** y la app trae la real, con **vectores de prueba conocidos** (NIST para AES-GCM, RFC 5869 para HKDF, RFC 6070 para PBKDF2).

**Modos:**

| | `solo_telefono` | `nube_cifrada` |
|---|---|---|
| Dónde vive | Solo en el teléfono, en un almacén cifrado con una **llave local** (`llave_local`, 32 bytes aleatorios guardados en el almacén seguro: Keystore en Android) | En el teléfono y en la laptop, y los sobres en Supabase cifrados con la `llave_maestra` |
| Quién lo lee | Solo ese teléfono | Los dispositivos de la persona que tengan la `llave_maestra` (teléfono y laptop) |
| Servidor | No recibe nada (el trigger rechaza sobres de un tipo en este modo) | Recibe sobres opacos |
| Si se pierde el teléfono | Se pierde, salvo el **respaldo local cifrado** (sección 4.3, punto 8) | Se recupera con la frase en otro dispositivo |
| Laptop | No lo ve; la pantalla dice *"Este dato está solo en tu teléfono"* | Lo ve |

El almacén local de **ambos** modos guarda los documentos ya cifrados; las pantallas los descifran en memoria y no dejan texto claro en disco, en la cola sin conexión, en registros de fallas ni en copias de pantalla (reglas 93 y 100).

### 4.3 Llaves y recuperación (D13: "cómo respaldar la llave")

**Propuesta segura (interpretación; P2):**

1. **Frase de recuperación de 12 palabras**, generada en el teléfono con aleatoriedad del sistema, de una lista de 2048 palabras en español (formato BIP-39: 132 bits, de los cuales 4 son de verificación). *Verificar la licencia de la lista antes de incluirla; si no es adecuada, se genera una lista propia.*
2. **`llave_maestra`**: 32 bytes aleatorios, generados en el teléfono. **Envuelta** (AES-256-GCM) con una llave derivada de la frase con **PBKDF2-HMAC-SHA256, 600 000 vueltas** (parámetros guardados junto a la llave para poder subirlos; la plataforma mide el tiempo en el Galaxy A52 y puede cambiar a Argon2id). La llave envuelta, la sal y los parámetros se guardan en `hab_llaves`. **El servidor no puede abrirla** sin la frase.

| `hab_llaves` | Contenido |
|---|---|
| `persona_id` (PK), `hogar_id` | Dueña |
| `version int` | Versión de la envoltura |
| `kdf text`, `kdf_params jsonb`, `sal text` | Cómo se derivó la llave de la frase |
| `llave_envuelta text` | `llave_maestra` cifrada |
| `creado_en`, `rotada_en` | Fechas |

3. **Activar la nube** (desde el teléfono): se muestra la frase una vez, con FLAG_SECURE, sin copiar al portapapeles; la persona la **anota en papel** y confirma escribiendo **3 palabras al azar** (posiciones elegidas al azar). Sin esa confirmación no se activa.
4. **Añadir la laptop (u otro teléfono):** *Ajustes › Privacidad › Datos sensibles › Añadir este equipo* → escribe la frase → el equipo desenvuelve la `llave_maestra` y la guarda en el almacén seguro (Keystore; en Windows, el almacén de credenciales del usuario) protegida por el PIN o la huella de la app. Las tablets **no** reciben la llave (regla 111).
5. **Cambiar la frase** (con la llave en un dispositivo): se genera otra frase, se vuelve a envolver la misma `llave_maestra` y `version` sube; los datos **no** se recifran. Rotar la `llave_maestra` misma (recifrar todo) queda para el pulido.
6. **Verificar mi frase** (recordatorio cada 90 días, genérico): pide 3 palabras al azar; no muestra la frase.
7. **Perdí la frase:** si algún equipo conserva la `llave_maestra`, *Cambiar la frase* genera una nueva sin perder datos. Si **ningún equipo** la tiene, los datos de la nube **no se pueden recuperar** (D13): *Ajustes › Privacidad › Reiniciar la nube* (`hab_reiniciar_nube`) borra los sobres y la llave y vuelve a `solo_telefono`; lo que sólo estaba en el teléfono no cambia. Nadie, ni el dueño del proyecto, puede recuperar la frase.
8. **Respaldo local cifrado (modo `solo_telefono`):** *Exportar respaldo* genera un archivo cifrado con una llave derivada de una frase de recuperación (la misma frase de 12 palabras, que se genera también en este modo si la persona quiere respaldo) para guardarlo donde quiera. El respaldo automático de Android **no** incluye el almacén sensible (su llave está atada al hardware y no se restaura). Recordatorio semanal opcional y genérico *"Es hora de tu respaldo"*.

### 4.4 Reglas por rol (RLS)

| Tabla | Leer | Insertar / cambiar | Borrar |
|---|---|---|---|
| `hab_ajustes`, `hab_objetivos`, `hab_bloques`, `hab_registros`, `hab_pausas`, `hab_planes_lectura`, `hab_plan_dias`, `hab_lecturas`, `hab_marcas_biblia`, `hab_revisiones` | `persona_id = persona_actual()` y `hab_activa(hogar_id)` | Lo mismo; la app no manda `persona_id`, `actualizado_en` ni `hogar_id` (los pone el servidor); `hab_ajustes` y `hab_modos` solo UPDATE | La propia persona (sus datos son suyos; no son libro contable) |
| `hab_sobres` | Igual, y solo de tipos cuyo modo es `nube_cifrada` | Por `hab_subir_sobres` (4.5), no directo | Por `hab_cambiar_modo`, `hab_reiniciar_nube` y `hab_borrar_mis_datos` |
| `hab_llaves` | Solo la propia persona | Por `hab_guardar_llave` | Por `hab_reiniciar_nube` y `hab_borrar_mis_datos` |
| `hab_modos` | Propia | Por `hab_cambiar_modo` | — |

`hab_activa(hogar_id)` = la sesión tiene membresía vigente en el hogar con rol `dueno`, `coadministrador` o `familiar`, **la membresía no es cuenta maestra** y la matriz da `habitos` con alcance `propio`. Por tanto: **cuidador, Hogar (rol `casa`) y la cuenta maestra no leen ni escriben nada de Hábitos**; el dueño y el coadministrador solo ven **lo propio**; `anon` no tiene nada. Una persona dada de baja no lee ni escribe (sus filas quedan, inaccesibles; P21). Las tablas nuevas siguen las defensas de la Fase 0 (revocar a `PUBLIC` y `anon`; privilegios por columna).

### 4.5 Funciones del servidor (backend)

Todas `security definer`, `search_path` fijo, sin ejecución para `anon`:

- `hab_iniciar()` y trigger en `membresias`: crea `hab_ajustes` y las dos filas de `hab_modos` al dar un rol con Hábitos (y no a la cuenta maestra).
- `hab_cambiar_modo(p_tipo, p_modo, p_confirmar_borrado bool)`: pasar a `nube_cifrada` exige que exista `hab_llaves`; pasar a `solo_telefono` **borra físicamente** los sobres de ese tipo y exige `p_confirmar_borrado = true` (regla 89). Sube `epoca_nube` cuando borra.
- `hab_guardar_llave(p_version, p_kdf, p_kdf_params, p_sal, p_llave_envuelta)`: crea o, con `p_version = actual + 1`, reemplaza la envoltura.
- `hab_subir_sobres(p_sobres jsonb)`: hasta 50 sobres por llamada; valida el modo del tipo, la `revision` (sube de 1 en 1), el tamaño (≤ 64 KB) y la cuota (25 MB por persona; 22023 al pasarla *(ajustable en `avisos_sistema`)*). Devuelve los **conflictos** (sobres cuya revisión del servidor es mayor) para que el cliente descargue, fusione (regla 91) y suba la revisión siguiente. Idempotente: la misma revisión con el mismo contenido no hace nada.
- `hab_reiniciar_nube(p_tipo)` y `hab_borrar_mis_datos(p_alcance)` (`sensibles`, `diario` o `todo`; con `todo` también `hab_llaves`, y deja `hab_ajustes`): borrado físico; suben `epoca_nube`; **escriben una sola entrada de bitácora sin contenido** (`habitos.reiniciar_nube`, `habitos.borrar_datos`).
- `hab_crear_plan_lectura(p_plan jsonb, p_dias jsonb)`: crea el plan y sus días en una transacción (hasta 400 días); idempotente por `id`.
- `hab_limpiar()` (tarea nocturna junto a `avisos_limpiar`): borra tumbas de sobres de más de 30 días.
- **Último gana:** trigger `hab_ultimo_gana` en las tablas en claro (convención 6): un UPDATE con `modificado_en` más viejo se ignora sin error; uno más de 5 minutos en el futuro se ajusta a `now()`.
- **Avisos (D20):** ver 4.6.

### 4.6 Reutilización de la infraestructura de avisos (D20)

Lo que **reutiliza** Hábitos:

| Pieza de D20 | Cómo la usa Hábitos |
|---|---|
| `avisos_preferencias` | Lee `zona_horaria`, `silencio_desde` / `silencio_hasta` (22:00 a 07:00) y `tipos_silenciados` para programar sus **recordatorios locales**. **Backend:** (a) `avisos_preferencias_sincronizar` también crea la fila para quien tenga Hábitos aunque no tenga Finanzas (el **familiar** solo tiene Hábitos), nunca para la cuenta maestra; (b) `avisos_actualizar_preferencias` acepta en `tipos_silenciados` los tipos locales `hab_*` de la regla 114. El tope diario de no críticas **no aplica** (regla 116) |
| `dispositivos` y `registrar_dispositivo` | Sin cambios. Una **tablet pública nunca recibe** nada de Hábitos; la tablet personal tiene los recordatorios locales apagados por omisión (regla 113) |
| Catálogo cerrado y revisión de discreción | `TextoAvisoHabitos` en `habitos_dominio` (regla 114) con la misma prueba automática (`avisos_discretos_habitos_test`): ≤ 40 caracteres, sin dígitos, sin "$", sin nombres |
| Canales de Android, permiso `POST_NOTIFICATIONS`, deduplicación por `clave` (id de la notificación = hash de la `clave`), reprogramación al reiniciar | Mismo mecanismo; tres canales propios (regla 115) |
| Pulsera (nivel 1) | Recibe el mismo título corto del teléfono; sin botones prometidos (D15) |
| Tabla `avisos` y bandeja | **No se usan en la Fase 3**: los recordatorios son locales y no pasan por el servidor ni por Firebase (regla 117). Se deja para después (pareja, Fase 8) la ampliación de `avisos.modulo` con `habitos` |

---

## 5. Reglas de negocio

### 5.1 Objetivos y asistente SMART

1. **Tipos de la Fase 3:** *construir hábito* ("Leer 20 min al día": racha y % de cumplimiento), *alcanzar meta* ("Leer 300 páginas en 30 días": avance hacia el valor final) y *proyecto* (hitos completados). *Eliminar hábito* se crea solo desde su propio flujo (sección 5.3) y es sensible.
2. **Asistente SMART** (5 pasos, cada uno con su valor por defecto y *Decidir después*): **Específica** (título y área) → **Medible** (unidad y meta) → **Alcanzable** (frecuencia; avisa si el medidor de carga del día pasaría a *saturado*, regla 25) → **Relevante** (motivo opcional de hasta 200 caracteres) → **con fecha** (inicio y fecha objetivo opcional). El último paso muestra el resumen y *Crear*. Crear un objetivo toma ≤ 5 pantallas y funciona sin señal.
3. **Plantillas por área** (datos del módulo, no código): "Leer la Biblia" (liga a un plan de lectura), "Leer N páginas al día" (metas de lectura de libros), "Orar N minutos", "Hacer el devocional", y las que el dueño agregue. Las del Anexo D y F están en sus pantallas propias.
4. **Frecuencias:** `diaria`; `dias_semana` (días marcados); `n_por_semana` (N veces en la semana, 1 a 6); `semanal` (una vez a la semana); `total` (meta única con fecha).
5. **Ritmo necesario** (descomposición de una meta): para `meta` con fecha, `(meta − avance) ÷ días restantes`, redondeado **hacia arriba**, por día y por semana; se muestra como sugerencia ("necesitas unas N páginas al día"), nunca como obligación. El avance de un `proyecto` es `hitos hechos ÷ hitos` en porcentaje entero hacia abajo.
6. **Estados:** `activo`, `pausado`, `logrado`, `archivado`. Un objetivo `logrado` o `archivado` conserva todo su historial. No hay "borrar objetivo" desde la app.
7. **Libros (interpretación; P18):** no hay biblioteca ni citas. Un libro se sigue con un objetivo de *páginas* (plantilla) y, si la persona quiere, su título en el nombre del objetivo.
8. **El título y el motivo de un objetivo no sensible viajan en claro** al servidor. El asistente avisa: *"No escribas aquí nada que quieras mantener reservado; para eso están los hábitos a eliminar y el diario."* Los objetivos de tipo eliminar no se pueden crear desde aquí.

### 5.2 Hoy, registro, rachas y carga del día

9. **Qué aparece en Hoy:** (a) las ocurrencias de los **bloques** del día (por su recurrencia y excepciones) y (b) los **objetivos** programados ese día que no tienen bloque, al final de su franja. Ambos comparten el mismo registro (`hab_registros`). Las pausas (regla 17) quitan el elemento del día.
10. **Orden y franjas:** por hora; lo que no tiene hora va al final de su franja; empates por `prioridad` y luego por `id`. Franjas: *mañana* (hasta la entrada al trabajo o 12:00), *traslado y trabajo* (si hay horario laboral) y *noche* (desde la salida o 18:00); los cortes son configurables (`hab_ajustes.franjas`).
11. **Tarjeta "Sigue":** el bloque más cercano a la hora actual que no esté hecho ni omitido; si hay uno **en curso** (ya empezó y no terminó) muestra *En curso* y el tiempo transcurrido. Cambia sola al marcar o al pasar la hora. Un traslado no ofrece *Modo traslado* en esta fase (queda para la etapa 8).
12. **Acciones del elemento:** *Hecho*, *Posponer* y *Omitir*; todas con **Deshacer** unos segundos y con alternativa por botón para el lector de pantalla (no solo deslizar). **La acción diaria cuesta 3 toques o menos**: Hecho = 1 toque; Hecho con valor = 1 toque (valor precargado con la meta) o 3 si se cambia; desde la notificación = 1 toque.
13. **Posponer:** ofrece *10 minutos*, *1 hora*, *esta noche* y *mañana*. Los tres primeros dejan `movido_a` y el estado `pospuesto` hasta que se marque; *mañana* cierra el día como `pospuesto` (no cumplido, sin reproche).
14. **Omitir:** el motivo es opcional y de lista cerrada. Un día omitido no es un reproche: cuenta como día no cumplido para la racha (regla 16), que puede cubrir el día de gracia.
15. **Día cumplido de un objetivo:** `construir`/`meta` con cantidad: la suma de valores del día ≥ la meta del día; sin cantidad: estado `hecho`. `parcial` (hecho a medias) no cumple pero tampoco es "falla vergonzosa": lo señala una flecha, no el rojo.
16. **Estados de un día para la racha:** `cumplido`, `gracia` (cubierto por el día de gracia), `no_cumplido` (programado, no cumplido y sin gracia disponible), `no_aplica` (no estaba programado, antes de la fecha de inicio, objetivo pausado o en pausa, o día futuro). **Solo `no_cumplido` rompe la racha.** Hoy en curso no rompe nada hasta que termina el día.
17. **Pausas:** `hab_pausas` (descanso, viaje, salud u otra, de un objetivo o de todos) vuelven los días `no_aplica`: no suman ni rompen. Es el equivalente de "vacaciones o enfermedad" de la agenda.
18. **Día de gracia (interpretación; P12):** cada **semana** (lunes a domingo) la persona tiene `gracia_semanal` días de gracia (1 por defecto, de 0 a 2). La gracia se aplica **automáticamente al primer día `no_cumplido` de cada semana** y no suma a la racha (la racha no sube ese día, pero tampoco se rompe). Si una semana tiene más fallas que gracias, el segundo día no cumplido rompe la racha. La gracia **no se acumula** entre semanas ni se "gasta" de forma anticipada. Se muestra como *"Usaste tu día de gracia (martes)"*.
19. **Racha de un hábito diario:** número de días `cumplido` consecutivos, contando hacia atrás desde ayer más hoy si hoy ya está cumplido; los días `gracia` y `no_aplica` en medio **no la rompen** pero no suman. Al romperse la racha actual vale 0 y el texto es *"Retomemos hoy"*; la **mejor racha** es el máximo de todo el historial y **nunca baja**. Ejemplo: lunes, martes y miércoles cumplidos, jueves sin cumplir, viernes cumplido, con 1 gracia → jueves es `gracia` y la racha al viernes es **4**; si el sábado tampoco se cumple, el sábado rompe la racha (la gracia de la semana ya se usó).
20. **Frecuencias semanales:** para `n_por_semana` y `semanal` la racha cuenta **semanas** consecutivas con la meta cumplida; una semana incompleta la rompe. No hay día de gracia en ellas (la propia meta ya admite días sin cumplir) **(interpretación)**.
21. **Mensajes sin culpa:** los textos de racha rota, día omitido, saturación, plan atrasado y recaída salen de `MensajesHabitos` (convención 8). Ejemplos del diseño: *"Un día no borra lo que has avanzado. Retomemos hoy."*, *"Aprendamos de lo que pasó y ajustemos el plan."*, *"Hoy hay mucho. ¿Dejamos solo lo esencial?"*. La prueba automática verifica las palabras prohibidas y que ningún estado use el color de alerta roja para un día no cumplido (el semáforo de hábitos usa verde, ámbar y **terracota**).
22. **Racha global:** días en que se cumplieron los **mínimos del día**. Modo `por_area` (por defecto): por cada área activa con algo programado ese día, al menos un elemento cumplido. Modo `marcados`: todos los elementos marcados `minimo` y programados ese día. Un día sin ningún elemento programado es `no_aplica`. Aplican las pausas y el día de gracia (reglas 17 y 18). **Los hábitos a eliminar no cuentan** en la racha global (tienen la suya; así la racha global es la misma en todos los dispositivos, con o sin la llave) **(interpretación)**.
23. **Anillos del día:** por área, `cumplidos ÷ programados` del día (los hábitos a eliminar y lo sensible se excluyen).
24. **Hoy sin conexión:** marcar, deshacer y posponer funcionan sin señal (la base local es la fuente) y se suben por la cola al volver; `hab_registros` se reenvía con el mismo id.
25. **Medidor de carga del día:** `libres = (dormir − despertar) − minutos de bloques fijos (trabajo, traslado)`; `programados` = minutos de los demás bloques del día (los sensibles **no** cuentan, para que el medidor sea igual en todos los dispositivos). Con enteros: `programados × 100 < libres × 50` → *ligero*; `≤ libres × 85` → *equilibrado*; si no → *saturado*; con `libres ≤ 0` → *saturado*. Con *saturado* la app propone mover o acortar primero los bloques **no mínimos** de mayor duración, y protege las horas de sueño ("constancia sostenible, no llenar el día"). Los umbrales son parámetros (P13). Ejemplo con 200 minutos libres: 99 programados = ligero, 100 = equilibrado, 170 = equilibrado, 171 = saturado.
26. **Modo foco:** se activa por el calendario del hábito (regla 52) y también a mano. Con foco activo, Hoy muestra **solo lo esencial** (elementos con `esencial` y el registro del hábito) con un banner que lo explica, se reducen los recordatorios a los esenciales y se **pausan los incrementos** (cualquier meta con subida automática; hoy no hay ninguna, el gancho queda para sueño, entrenamiento e inglés). Al terminar, la app propone retomar de forma gradual.
27. **Primer uso y estados vacíos:** sin objetivos, *"Empecemos con uno pequeño. ¿Qué te gustaría lograr esta semana?"*; sin elementos hoy, *"Hoy está libre. ¿Agregamos algo pequeño?"*; todo hecho, cierre sobrio con vista previa de mañana; el primer uso invita al asistente de configuración.

### 5.3 Hábitos a eliminar: cigarrillo y azúcar

28. **Plantillas:** `cigarrillo` y `azucar`. El tipo `otro` del modelo no se ofrece en esta fase. **Todo** dato de esta sección vive en el documento cifrado del tipo `habitos_sensibles` (4.2) y en ninguna columna en claro.
29. **Flujo común** (F.2): línea base → estrategia → motivos → disparadores y plan "si… entonces" → reemplazos → apoyo → seguimiento → recaídas → mantenimiento. Cada paso tiene un valor por defecto y *Decidir después*; las fechas y metas se configuran en la app (F.15), nada va fijo en el código.
30. **Línea base:** 7 días (configurable de 3 a 14) desde `fecha_inicio`, **sin metas ni semáforo** ("Solo observamos"). Se registra cada consumo; la persona puede **cargar días anteriores** (editar la fecha y hora) para pasar lo que llevó en papel. Un día **tiene datos** si tiene al menos un registro o un **cierre de día** (*"Cero hoy"* o la cantidad). Un día sin registro y sin cierre es `sin_datos` y no entra al promedio ni cuenta como cero.
31. **Promedio de la línea base** (centésimas enteras) = `Σ consumos ÷ días con datos`; se calcula solo con **al menos 5 días con datos** (parámetro; P6). Con menos, la app dice *"Faltan algunos días para calcular tu promedio"* y ofrece **extender la línea base**, sin obligar. Ejemplo: 84 cigarrillos en 7 días con datos → 12.00; 50 en 5 → 10.00; 4 días con datos → no calcula.
32. **Fases del cigarrillo** (fechas calculadas desde `fecha_inicio` = I y `fecha_dia_d` = D; por defecto D = I + 28 días, editable; P5). Para una fecha `d`:

| Fase | Intervalo |
|---|---|
| `no_iniciado` | `d < I` |
| `linea_base` | `I ≤ d < I + 7` (la duración configurada) |
| `reduccion` | `I + 7 ≤ d < D − 7` |
| `preparacion` | `D − 7 ≤ d < D` (la reducción sigue vigente con el último límite) |
| `dia_d` | `d = D` |
| `libre` | `D < d < D + 28` (consolidación; el **modo foco** cubre `D ≤ d < D + 14`) |
| `mantenimiento` | `d ≥ D + 28` |

    Sin Día D (estrategia solo gradual o "de golpe" sin reducción previa), la fase `reduccion` o `libre` sigue las reglas de esa estrategia. Ejemplo con I = lunes 2/nov/2026 y D = 30/nov/2026: línea base 2 a 8/nov; reducción 9 a 22/nov; preparación 23 a 29/nov; Día D 30/nov; modo foco 30/nov a 13/dic; libre hasta el 27/dic; mantenimiento desde el 28/dic.
33. **Estrategias del cigarrillo:** `gradual_y_dejar` (la del plan inicial: línea base, reducción por etapas y Día D), `solo_gradual` y `de_golpe` (línea base y Día D). La persona elige; la app propone y la persona decide (F.14).
34. **Límite del día en reducción:** las etapas son **semanas** desde el fin de la línea base; cada una tiene un porcentaje de reducción (por defecto 25, 50 y 75, **ejemplo editable**; después de la última etapa se mantiene la última). `límite = promedio × (100 − pct) ÷ 100`, redondeado a la mitad hacia arriba, mínimo 0. Ejemplos: promedio 12.00 → 9, 6 y 3; promedio 10.00 → 8, 5 y 3.
35. **Hoy en reducción:** la tarjeta dice *"Hoy: X de Y"*. **Superar el límite no se pinta de rojo**: color suave y la pregunta *"¿Qué te ayudaría mañana?"*. Opcional: *"próximo permitido a las HH:MM"* (a partir del último registro y un intervalo que la persona define). La racha de reducción es de **días bajo la meta**.
36. **Preparación:** muestra la lista del Día D: elegir o confirmar la fecha, **cita médica** (se agrega a la agenda como bloque sensible), sacar cigarros, encendedores y ceniceros (casa, carro y trabajo), avisar a las personas de apoyo, preparar el SOS y los reemplazos. Cada tarea se marca a mano. **La app no recomienda tratamientos ni dosis**; sugiere hablar con un médico (F.4).
37. **Día D:** tarjeta especial con la lista del día, mensajes de apoyo, oración opcional y agenda ligera (modo foco). Cero cigarrillos como meta del día; si hay un registro, se aplica la regla 40.
38. **Mover el Día D** (o cualquier fecha del plan) pide confirmación y muestra qué cambia (fase, modo foco, recordatorios y bloques ligados). Si en la reducción no se logra el paso previsto, **no pasa nada**: se ajusta el paso y se mantiene el Día D salvo que la persona decida moverlo (F.14).
39. **Registro de consumo en 1 toque:** *Registrar* suma un cigarrillo (o una porción) con la hora actual; **Deshacer** unos segundos; después una hoja opcional con *disparador, ánimo y compañía* (todo opcional, nunca obligatorio). Mantener presionado un registro: editar la hora o eliminarlo. Los disparadores son una lista editable (por defecto: después de comer, café, estrés, traslado, reuniones, según F.4).
40. **Recaída (cigarrillo):** todo cigarrillo registrado en un día `d ≥ D` crea una **recaída** del día (una por día). La app muestra el mensaje de partida *"Una caída no borra lo avanzado"*, ofrece el protocolo (qué pasó, el disparador, un ajuste: más apoyo, otro reemplazo o un paso más pequeño) y una **acción concreta para hoy**. Nada de rojo, nada de "perdiste". Antes del Día D, un cigarrillo es solo un registro.
41. **Días libres, racha y mejor racha (cigarrillo, desde D):** un día es **libre** si no tiene registros (hoy cuenta como libre mientras no haya uno). `racha actual` = días libres consecutivos hasta hoy; `mejor racha` = el máximo histórico; `días libres acumulados` = total de días libres desde D. **Una recaída pone la racha actual en 0 sin tocar la mejor racha ni los acumulados.** Ejemplo: D = 30/nov; sin consumo hasta el 4/dic: al 4/dic racha 5, mejor 5, acumulados 5; un cigarrillo el 5/dic: racha 0, mejor 5, acumulados 5; el 6/dic libre: racha 1, mejor 5, acumulados 6.
42. **Varias recaídas:** con 3 o más días de recaída en 14 días (parámetro) la app sugiere con calidez **hablar con un profesional de la salud o con alguien de confianza**; no insiste ni bloquea.
43. **Azúcar (plan del usuario, F.14):** línea base de 7 días en **porciones** (bebidas azucaradas, postres y dulces, botanas) → plan activo de **alimentos muy regulados** (tres listas: verde = libre, amarilla = limitada con frecuencia, roja = evitar) y **refresco ocasional**. Las listas se **editan por la persona**; la plantilla inicial usa los ejemplos del diseño (fruta entera, verduras, agua, café o té sin azúcar como verde) marcados como *ejemplo editable, defínelas con un nutriólogo si puedes*. No hay metas de gramos ni de calorías y no se recomienda ninguna cifra (F.3 cita a la OMS solo como referencia general, la meta la fija la persona).
44. **Refresco ocasional:** la persona define **cuántas veces** permite (por semana o por mes; P7, sin valor por defecto: la app lo pregunta) y qué es una ocasión. Cada registro es **ocasión planeada** o **no planeada** (con porción y contexto opcional). Un antojo impulsivo envía primero al SOS de 10 minutos y luego decide.
45. **Semáforo del refresco ocasional** (en el periodo elegido, con `usadas` y `límite`, en enteros): **verde** si `usadas × 4 < límite × 3`; **ámbar** si `usadas × 4 ≥ límite × 3` y `usadas ≤ límite`; **terracota** si `usadas > límite`. Con límite 0: verde si no hay ninguna, terracota si hay una. El umbral del 75 % es un parámetro (P7). Ejemplos: límite 4 → 0 a 2 verde, 3 y 4 ámbar, 5 terracota; límite 1 → 0 verde, 1 ámbar, 2 terracota. El terracota no culpa: lleva a *"ajustar el plan"*. Si el refresco va en aumento semana tras semana, la revisión del sábado lo señala y propone endurecer la regla.
46. **Métricas del azúcar:** refrescos por periodo, % de ocasiones planeadas, días sin azúcar alta, antojos superados y tendencia. Los gramos son opcionales y no se estiman.
47. **Reemplazos, "si… entonces", motivos y disparadores:** listas editables de texto libre (cifradas). Los **motivos** aparecen en el SOS y en los momentos difíciles (F.2). Reemplazos sugeridos por la plantilla (agua, respiración, caminata corta, algo para masticar sin azúcar, llamar a alguien) son opciones, no recomendaciones médicas.
48. **Hitos de constancia (no de salud):** cigarrillo, días libres 1, 3, 7, 14, 30, 60, 90, 180 y 365; azúcar, días sin bebida azucarada 3, 7, 14 y 30. Se calculan; "visto" se guarda en el documento de configuración. **Los hitos de salud (qué mejora el cuerpo con el tiempo) no se incluyen** hasta que el dueño dé una fuente oficial verificada (regla 55).
49. **Ahorro privado (interpretación; P17):** oculto por defecto (se muestra solo si la persona lo activa en el hábito). Cigarrillo: la persona captura el precio de la cajetilla y cuántos trae; el ahorro de un día es `max(0, promedio de la línea base − consumo del día) × precio de la cajetilla ÷ cigarrillos por cajetilla`, en centavos, redondeado por día a la mitad hacia arriba y sumado, **solo con días con datos y desde que termina la línea base**. Ejemplo (precio inventado para la prueba, no es un dato real): promedio 12.00, cajetilla de $150.00 con 20 cigarrillos, un día sin consumo → $90.00. El precio y el ahorro viven en el documento cifrado; **no se envían a Finanzas, a la pareja, a la IA ni a los avisos**, y ninguna columna en claro lleva dinero. Azúcar: no calcula dinero (no hay precio estándar).
50. **Patrones:** gráficas por hora del día y día de la semana, lugares, ánimo, disparadores y compañía; se calculan en el dispositivo desde los documentos descifrados. Si el modo es `solo_telefono`, solo existen en el teléfono; en la laptop la pantalla explica por qué no están.
51. **Apoyo:** personas de apoyo (nombre y teléfono) guardadas cifradas; el SOS las llama con el marcador del teléfono (`tel:`), **sin enviar mensajes desde la app** ni compartir datos. Mensajes de ánimo de la pareja, compañero de rendición de cuentas y la pareja como apoyo son del modo pareja (Fase 8+).
52. **Modo foco del hábito:** del Día D a `D + duración` (14 días por defecto, editable; P5); lo activa el calendario y se puede apagar. El plan inicial lo recomienda por irritabilidad y cambios de sueño.
53. **Avisos de síntomas:** la pantalla de Día D y la de Apoyo dicen que son frecuentes al principio la irritabilidad, la ansiedad, la dificultad para concentrarse, más apetito y sueño alterado, y sugieren consultar si son intensos o si hay tristeza o ansiedad fuerte (F.4). **Es texto del diseño del dueño; no se amplía con contenido médico propio.**
54. **Si el seguimiento causa ansiedad u obsesión** la persona lo puede pausar (*Pausar el seguimiento*); la app recomienda apoyo profesional (F.3). Pausar no borra nada.
55. **Hitos de salud y datos médicos:** ningún dato médico (qué mejora en 24 horas, una semana o un mes) se escribe en el código hasta que el dueño entregue la fuente oficial (OMS o autoridad sanitaria) y la fecha en que la verificó (P16).
56. **Línea de ayuda:** el catálogo de apoyo tiene un campo `verificado_en`; **una línea de ayuda solo se muestra si tiene fecha de verificación**. El diseño menciona la Línea de la Vida de México (800 911 2000) *sin verificar*; el dueño o calidad la verifican antes del primer uso real (P16). Mientras no esté verificada, la pantalla de Apoyo dice *"Habla con tu médico o con alguien de confianza"*.
57. **Recaída del azúcar:** no hay "recaída" como evento; el terracota de la regla 45 y el ajuste del plan cubren ese papel.

### 5.4 SOS "Tengo un antojo"

58. **Dónde está:** en el teléfono, en **un toque** desde Hoy, el (+) y el panel del hábito, y como **atajo de la pantalla de inicio** (mantener presionado el icono). Está visible en todas las condiciones, incluso con el modo foco. En la laptop se abre desde el panel del hábito, solo si ese dato es visible allí (modo nube). El botón y el atajo se llaman por defecto **"Pausa"** (`etiqueta_atajo`, P8) para no anunciarle a quien mire; la persona puede cambiarlo a "Tengo un antojo".
59. **Flujo** (F.5; cada paso cabe en una pantalla y se puede cerrar):
    1. **Pausa:** *"Respira. Las ganas pasan; casi siempre duran pocos minutos."* (texto del diseño; editable) con respiración guiada visual.
    2. **Qué es:** cigarrillo, azúcar u otro hábito configurado (se salta si solo hay uno).
    3. **Elegir una técnica:** respiración guiada, beber agua, caminar 5 minutos, masticar algo sin azúcar, llamar o escribir a alguien de apoyo, un versículo y una oración corta. Las técnicas favoritas y los reemplazos de la persona van primero.
    4. **Temporizador de 10 minutos** (parámetro de 5 a 15): *"Si en 10 minutos sigue, repetimos."* Al terminar pregunta *"¿Sigue el antojo?"*: *Sigue* reinicia con otra técnica; *Ya pasó* cierra como superado.
    5. **Registro rápido** (30 segundos, todo opcional): intensidad de 1 a 5, disparador y qué hice.
    6. **Cierre:** reconocimiento sobrio; si pasó, suma al contador de **antojos superados**.
60. **Contenido a la vista (P8):** los **motivos** de la persona, una **colección de versículos de ánimo** (referencias que la persona elige y el texto sale del lector; por omisión unas pocas referencias de ejemplo, editables, P9), y la lista de apoyo. Nada de datos médicos nuevos.
61. **Resultado:** `superado` o `consumo`. Con `consumo` ofrece **registrar el consumo en un toque** y, si aplica (cigarrillo desde el Día D), el protocolo de recaída (regla 40) con el tono de la regla 21; nunca "perdiste".
62. **Funciona sin señal y sin permisos especiales.** Si el teléfono está bloqueado, el SOS pide la huella o el PIN de la app (es una sección reservada); la sesión del SOS no muestra el nombre del hábito en las apps recientes (FLAG_SECURE, regla 100). **Sin voz ni audio manejando** en esta fase (queda para GRAVITY, Fase 6): la app no pide mirar ni tocar la pantalla mientras se maneja, por eso el SOS **no ofrece** un modo para el coche hasta tener el de audio (Observación 5).

### 5.5 Agenda y asistente de configuración

63. **Bloques ligados a hábitos sensibles** (cita médica, refuerzos, tareas del Día D) existen **solo** en el documento cifrado y se muestran en la agenda únicamente en dispositivos que tengan la llave; en el calendario del dispositivo y en la laptop sin llave no aparecen. Sus recordatorios son siempre genéricos (regla 114).
64. **Vistas:** *Día* (línea de tiempo con los bloques y los huecos), *Semana* (columnas) y *Mes* (puntos por área, sin texto). Cada bloque lleva el color de su área **y un icono / texto** (nunca solo color), y su estado: pendiente, hecho, omitido o reprogramado.
65. **Bloques recurrentes con excepciones:** un bloque se repite por `dias` cada `cada_semanas` desde `desde` hasta `hasta`. Una **excepción** es un registro de ese día (`hab_registros`) con estado `omitido` o con `movido_a`; "editar solo esta vez" y "editar todas" son opciones distintas. Mover un bloque hecho no lo deshace.
66. **Horario laboral y traslado:** se capturan una vez (días, entrada, salida, descansos; traslado de ida y vuelta en minutos y si se va en auto o transporte) y generan bloques de tipo `trabajo` y `traslado` (fijos, visibles, no se marcan como cumplidos). El horario es **fijo**; los turnos rotativos quedan fuera. El diseño usa 7:00, 8:00, 18:00 y ~19:00 como **ejemplo de la plantilla**, no como valor por defecto.
67. **Búsqueda de huecos:** dado un bloque a crear con duración, el dominio devuelve los **huecos libres** del día (entre `despertar` y `dormir`, sin cruzar bloques) ordenados por cercanía a la hora que la persona prefiere; para un objetivo recurrente propone el hueco más estable de la semana. **Detección de conflictos:** avisa si un bloque se cruza con el trabajo, el traslado u otro bloque; el aviso no impide guardar.
68. **Asistente de configuración** (7.2 adaptado; **8 pasos**, 10 a 15 minutos, pausable, saltable): 1 *Perfil y áreas activas* (individual; "pareja" aparece como *próximamente*; se empieza con 2 o 3 áreas), 2 *Trabajo y traslado*, 3 *Tu día* (despertar y dormir; sin plan de transición), 4 *Espiritual* (versión principal y secundaria de la Biblia, ruta de inicio, hora del devocional, recordatorio de dar opcional), 5 *Hábitos a eliminar* (qué hábito, estrategia, fecha de inicio y Día D, límites, motivos y apoyo; o *Decidir después*), 6 *Revisión semanal* (día, hora y aviso previo), 7 *Privacidad* (los dos modos de D13 con su explicación y la frase si elige nube, bloqueo de la sección reservada, notificaciones discretas) y 8 *Resumen: semana tipo y carga*. **Omitidos por esta fase:** sueño con transición, salud, inglés, música y conexión con Presupuesto (D1). Cada paso propone un valor por defecto y siempre hay *Decidir después*; el estado se guarda en `hab_ajustes.asistente` para reanudar.
69. **Semana tipo (paso 8):** muestra todo lo programado y el medidor de carga por día; si algún día queda *saturado* sugiere empezar con menos. Los cambios importantes (p. ej. mover el Día D) piden confirmación y muestran qué planes se afectan. Se puede reconfigurar cualquier parte en cualquier momento.
70. **Recordatorios de bloque** (`recordar_min`): minutos de antelación configurables; acciones *Hecho*, *Posponer 10 min* y *Omitir* (regla 113). Un bloque sensible no ofrece *Hecho* en la notificación.
71. **Sincronía de la agenda:** `hab_bloques` y las excepciones suben por la cola; la laptop y el teléfono ven lo mismo (salvo lo sensible sin llave).
72. **Google Calendar y turnos rotativos:** no existen en esta fase.

### 5.6 Espiritual (MVP)

73. **Principios (D.1):** la Escritura es la fuente; los registros no miden la fe ni "puntúan"; sin culpa si se pierden días; privacidad máxima en oración y notas; sin IA.
74. **Espiritual hoy** (D.2), con un toque cada uno: (1) la **lectura del plan** de hoy, (2) el **devocional** del día, (3) las **peticiones de oración** del día (de la lista de intercesión de ese día de la semana, si se configuró), (4) nota rápida o gratitud, más el **versículo del día** y la racha suave (con día de gracia). Memorización y ayuno no existen aún.
75. **Versículo del día:** índice `días desde 2000-01-01 mod N` sobre una lista de referencias (la colección de ánimo o una lista de ejemplo editable; P9); el texto sale del lector en la versión principal. Determinista: el mismo día muestra el mismo versículo en todos los dispositivos.
76. **Referencias:** el dominio define `ReferenciaBiblica` (libro 1 a 66 en orden canónico protestante, capítulo, versículo inicial y final), con el **tratado de nombres** en español (Génesis… Apocalipsis, con abreviaturas habituales, sin acentos ni mayúsculas) y en inglés. Ejemplos que deben analizarse: `Juan 3:16`, `Jn 3:16-18`, `1 Corintios 13`, `1 Co 13:4–7`, `Sal 23`, `Génesis 1:1-2:3` (rango entre capítulos). Juan es el libro 43; el Nuevo Testamento tiene 27 libros y **260 capítulos**; el canon, 66 libros y **1 189 capítulos**.
77. **Lector:** libro, capítulo y versículos; versión principal y secundaria con **cambio rápido sin perder lugar, notas ni subrayados** (las marcas y notas se guardan por **referencia**, no por versión); si el versículo no existe en la otra versión (numeración distinta en algunos pasajes), la marca se muestra a nivel de capítulo con un aviso. Letra ajustable, modo oscuro y brillo bajo para leer de noche (personalidad contemplativa, sin animación). **Sin conexión** siempre: el texto va dentro de la app.
78. **Proveedor de versiones:** el lector accede a la Biblia mediante una interfaz `ProveedorBiblia` (versión, libros, capítulo, versículo, búsqueda); la Fase 3 trae dos implementaciones de **dominio público**, **Reina-Valera 1909** y **KJV**. Agregar RVR1960 o NVI (con licencia, P10) o API.Bible es agregar un proveedor, sin tocar pantallas, notas ni planes. **La edición exacta y el origen verificable del texto los confirma el dueño antes de incluirlo** (D.12; P10). Las licencias de cada texto se muestran en *Acerca del texto*.
79. **Texto bíblico dentro de la app:** como recurso comprimido (`app/assets/biblia/`, lo declara el agente que posee `app/assets`/`pubspec`, ver sección 8) y cargado a la base local; búsqueda por **referencia** y por **palabra** (sin acentos, sin mayúsculas, ordenando por libro). Sin concordancia con números Strong ni diccionario en esta fase.
80. **Subrayados y marcadores:** se eligen de **6 colores**; el significado del color lo define la persona. Los marcadores no llevan título libre. Van en claro (`hab_marcas_biblia`).
81. **Planes de lectura** (D.4; todos generados por un mismo algoritmo): se reparten los capítulos de la secuencia en `D` días de lectura: cada día recibe `N div D` capítulos y los primeros `N mod D` días uno más. Planes de la Fase 3:
    - **Ruta de inicio (21 días):** Juan, 1 capítulo por día, con devocional breve opcional (D.22, fase 1).
    - **Nuevo Testamento en 90 días:** 260 capítulos → 80 días de 3 y 10 de 2.
    - **Salmos y Proverbios en 30 días:** cada día 5 Salmos (150 en total) y un Proverbio (31 en total; el día 30 lee Proverbios 30 y 31) **(interpretación; P11)**.
    - **Biblia en un año (canónica, orden de los libros):** 1 189 capítulos en 365 días → 94 días de 4 y 271 de 3.
    - **Por libro:** el libro elegido, con el ritmo en capítulos por día que la persona fije.
    - **Cronológico, temático y personalizado:** fuera (necesitan un orden o una selección verificados, P11).
    - Por defecto los 7 días de la semana; la persona puede excluir días.
82. **Ponerse al día sin culpa (D.4):** si el plan se atrasa, la app ofrece tres salidas, ninguna con reproche: **Ponerme al día** (reparte los capítulos pendientes de días pasados entre los próximos `K` días, `K` a elección, sumados al ritmo normal y **sin mover la fecha final**), **Saltar** (marca los días pendientes como `saltado`; no cuentan en el porcentaje ni en la racha) y **Reiniciar el tramo** (los capítulos que faltan empiezan hoy y la fecha final se recorre). Ejemplo: Ruta de inicio (1 capítulo por día), hoy es el día 8 y los días 4 a 7 siguen pendientes (4 capítulos): con `K = 4` los días 8 a 11 leen 2 capítulos; con `K = 7`, los días 8 a 11 leen 2 y los días 12 a 14 leen 1.
83. **Avance de un plan:** capítulos leídos ÷ capítulos del plan sin contar los saltados, en porcentaje entero hacia abajo. Marcar el día completo es un toque; marcar por capítulo, opcional. Una lectura suelta fuera del plan se registra en `hab_lecturas`. **Racha de lectura:** por la regla 19 con el día de gracia.
84. **Devocional:** estructura **lectura → reflexión → aplicación → oración**; tipos *Devocional del plan* (sobre el pasaje del día), *Mi devocional* (plantilla propia: observación, aplicación, oración) y **breve** de 5 minutos (lectura, una pregunta y oración corta). Cada entrada guarda fecha, pasaje, reflexión, aplicación y oración, y puede ligarse a un objetivo. Los packs de terceros no existen (licencias).
85. **Notas del lector:** texto por referencia, con etiquetas (promesa, mandato, oración…). Son del tipo `diario_oracion` (4.2).
86. **Oración (D.7):** *diario de oración* con peticiones (texto, categoría, fecha, estado **pendiente, en espera o respondida**, fecha y nota de respuesta); *oraciones respondidas* ("para recordar la fidelidad de Dios"); *listas de intercesión* (familia, iglesia, enfermos, nación, trabajo; opcionalmente por día de la semana); *temporizador de oración* con registro de minutos; *guía ACTS* (adoración, confesión, gratitud, súplica) como estructura opcional. Todo es del tipo `diario_oracion`; **no se envía a ninguna IA**.
87. **Recordatorio de dar (opcional):** apagado por defecto; la persona lo programa con día y hora (p. ej. el día de pago). Texto genérico (*"Recordatorio"*), sin montos; Hábitos no maneja dinero (el diseño: "sin montos en Hábitos"). En la revisión semanal pregunta *"¿Se cumplió lo que decidiste esta semana?"* (sí / no / no aplica), sin cantidades.

### 5.7 Datos sensibles: modos, llaves y borrado (D13)

88. **Valor por defecto: `solo_telefono` para los dos tipos** (la propuesta más segura: nada sale del teléfono y no hay llave que perder en silencio; P1). El asistente (paso 7) y *Ajustes › Privacidad › Datos sensibles* explican las dos opciones con su consecuencia en una pantalla: *"En la nube cifrada puedes verlo también en la laptop y lo recuperas con tu frase; solo en el teléfono no sale de aquí y, si pierdes el teléfono, se pierde, salvo que tengas un respaldo."* La elección es **por tipo**.
89. **Cambiar de modo** (siempre desde un **teléfono**, con PIN o huella):
    - `solo_telefono → nube_cifrada`: crea la frase si no existe (sección 4.3), recifra los documentos con la llave maestra, sube los sobres por lotes y llama a `hab_cambiar_modo`. La laptop los verá al añadirla con la frase.
    - `nube_cifrada → solo_telefono`: el teléfono primero **descarga y descifra todo** lo que le falte; muestra el aviso *"Se borrará de la nube y la laptop dejará de verlo"*; pide PIN y confirmación; recifra con la llave local y llama a `hab_cambiar_modo(..., true)`, que borra los sobres. Los demás equipos detectan el cambio (`epoca_nube`) y **eliminan su copia local** de ese tipo.
    - Cambiar de modo **no** pierde datos si falla a medias: el estado anterior se conserva hasta que termina.
    - Desde la laptop solo se ve el estado y las instrucciones; no se puede convertir un dato en *solo teléfono* desde allí.
90. **Documentos y ids:** el id del sobre es `HMAC(llave_de_ids, tipo ‖ clave_doc)` (4.2); en `solo_telefono` se usa la misma estructura con la llave local (la conversión entre modos no cambia los documentos).
91. **Fusión de documentos:** al haber un conflicto de `revision` (dos dispositivos escribieron el mismo día), el cliente descarga, descifra, **une por elemento** (gana el elemento con `modificado_en` más reciente; una tumba más reciente que una edición elimina), sube la revisión siguiente. Es una función pura del dominio (`fusionarDocumentos`) con pruebas.
92. **Qué ve el servidor del modo nube:** el tipo, la cantidad y el tamaño de los sobres, y su hora de subida. **Subida diferida:** los sobres de `habitos_sensibles` se suben **en lote** (al cerrar el día y como máximo una vez cada 6 horas con señal, o al instante si la persona pulsa *Sincronizar*), con la hora del servidor, para que el servidor no vea cuándo ocurrió cada registro (interpretación; P2).
93. **Cola sin conexión:** guarda el sobre **ya cifrado**; jamás texto claro de un dato sensible. Los registros de fallas (Crashlytics) y los logs no incluyen contenido de documentos ni nombres de hábitos.
94. **Quién puede leer qué:** solo la persona, y solo en equipos que tengan su llave (nube) o su teléfono (local). El **dueño** del hogar no ve nada de Hábitos de otros; la **pareja** tampoco; la **cuenta maestra** no tiene Hábitos; el dueño del proyecto de Supabase ve únicamente sobres opacos.
95. **Borrar y exportar mis datos** (F.12): *Ajustes › Privacidad › Mis datos de Hábitos*. **Exportar:** genera un archivo (`.json` con esquema propio `gravity-habitos` v1) con los datos en claro y, por separado, los de cada tipo sensible que la persona elija; el archivo sensible puede **protegerse con la frase**; antes de compartir se muestra el aviso *"Este archivo contiene datos de salud y de oración; guárdalo en un lugar seguro y no lo envíes por mensajería."* **Borrar:** por tipo (sensibles, diario) o todo; pide PIN y escribir una palabra de confirmación; borra en el dispositivo y en la nube (`hab_borrar_mis_datos`) y deja constancia sin contenido en la bitácora. Esto no es un libro contable: se puede borrar.
96. **Importar un respaldo / exportación** propios: se valida contra el esquema, se muestra una pantalla de revisión con conteos y se pide confirmación; los archivos son **entrada hostil** (límite de 20 MB, texto plano, sin ejecutar nada), como en la regla 69 de la Fase 1.
97. **Revisión semanal y sensibles:** la parte que resume hábitos a eliminar se calcula en el dispositivo y se muestra solo si hay llave; sus respuestas escritas van al diario.
98. **Bitácora:** las tablas `hab_*` **no** tienen trigger de bitácora (registrar sus cambios dejaría al dueño ver cuándo la pareja registra algo). Solo las funciones de 4.5 que borran o reinician dejan una entrada **sin contenido**, con acciones `habitos.reiniciar_nube`, `habitos.borrar_datos`, `habitos.cambiar_modo` y `habitos.activar_cifrado`. **Backend:** el prefijo `habitos` queda reservado al servidor (como `finanzas*`) y la regla de lectura de la bitácora (`puede_ver_entrada_bitacora`) deja ver las entradas `habitos.*` **solo a quien las hizo**: ni el dueño ni la cuenta maestra.
99. **Respaldo de la laptop:** la copia diaria incluye los sobres tal cual (ilegibles sin la frase) y las tablas en claro (objetivos, agenda, cumplimiento…). **La copia contiene los datos no sensibles de las demás personas** (Observación 6; P20).
100. **Sección reservada:** el panel de hábitos a eliminar, el SOS, el registro de consumo, el diario de oración, el devocional escrito, las notas y *Mis datos* son una **sección reservada**: (a) piden PIN o huella al entrar si el bloqueo está activo (por defecto sí) y vuelven a pedirlo tras `bloqueo_reservado_min` minutos sin uso (2); (b) se abren con **FLAG_SECURE** (sin capturas ni vista previa en apps recientes); (c) ocultan su contenido con el **modo privado** de la laptop (*"Contenido reservado · Toca para ver"*); (d) no se muestran en el resumen de Hoy de GRAVITY ni en la tarjeta de la pantalla principal, solo un renglón genérico *"Hábito reservado"*. En Windows el bloqueo de capturas sigue pendiente (W1 del ROADMAP): la sección reservada se oculta con el modo privado y avisa que no puede impedir la captura de pantalla.
101. **Primer uso y confianza:** el asistente nunca activa la nube por sí solo ni sube nada sin que la persona la haya activado; la primera vez que se registra un consumo, un recuadro único explica dónde se guarda.

### 5.8 Roles, dispositivos y privacidad en pantalla

102. **Roles:** Hábitos lo usan `dueno`, `coadministrador` (cuenta de la pareja, **no** la maestra) y `familiar`, cada uno con lo propio. `cuidador`, `casa` (Hogar) y la cuenta maestra no ven el módulo ni su tarjeta en Hoy; papá no tiene cuenta (D5). La pantalla se arma según el rol (nada de pantallas vacías por permisos).
103. **La matriz de permisos no cambia** (ya tiene `habitos` = `propio`). Backend suma `hab_activa()` y excluye a la cuenta maestra del escribir **y** leer lo propio (no tiene Hábitos), porque la maestra es solo lectura total (D19) y Hábitos queda fuera de lo que ve.
104. **Teléfono:** lo completo de la fase (Hoy, (+), SOS, lector, devocional, oración, panel, agenda del día). **Laptop:** lo completo (configurar, planear, agenda, objetivos, revisión, gráficas), con lo sensible solo en modo nube y con la llave añadida.
105. **Tablet pública de la casa (D14):** no muestra ninguna pantalla de Hábitos en modo Casa. Con **nombre + PIN** puede abrir *Hoy* de esa persona **solo con lo no sensible** (marcar objetivos y bloques, leer) y el lector; la sesión dura esa acción o 2 minutos. **Nunca** muestra ni registra hábitos a eliminar, SOS, diario de oración, devocional escrito, notas, frases ni llaves, ni recibe recordatorios. Lo sensible no está en el almacén local de una tablet.
106. **Tablet personal (D21, respuesta del dueño):** se trata **como el teléfono** de la persona: tras su PIN muestra Hoy, agenda, lector, planes, progreso y, **si la persona le añadió la llave con su frase y el modo es nube cifrada**, también lo sensible (con la sección reservada, FLAG_SECURE y bloqueo a los 2 minutos). Los recordatorios locales vienen apagados por omisión y se encienden por equipo. La **pública** nunca muestra lo sensible (regla 105).
107. **Laptop y llave:** en la laptop la llave maestra, si se añadió, vive en el almacén de credenciales del usuario y requiere el PIN de la app tras el bloqueo por inactividad (la laptop se bloquea tras un rato, 2 por omisión en lo reservado).
108. **Notificaciones, bocinas e IA:** nada de Hábitos va a bocinas ni a la IA en la nube (D3, D6); en esta fase **no existe** voz de Hábitos. Las órdenes de GRAVITY sobre Hábitos sensibles **no se guardan en el historial** (regla 120).
109. **Pareja:** no se comparte nada. La pareja usa su propia cuenta y sus propios datos; el modo pareja (objetivos y devocional compartidos, apoyo) es Fase 8+. El dueño **no** ve lo de la pareja ni al revés.
110. **Personas bajo cuidado (papá):** no usan Hábitos; sin cuenta, no hay datos.
111. **La llave maestra** solo se añade en teléfonos, laptop y **tablets personales** (con la frase); **nunca** en la tablet pública.
112. **Baja de una persona (D21):** pierde el acceso al instante (D5); sus filas de Hábitos se **conservan sin acceso y se borran físicamente a los 90 días** (`hab_limpiar`); la persona puede exportar o borrar antes (`hab_borrar_mis_datos`).

### 5.9 Notificaciones y recordatorios (D20, D15)

113. **Recordatorios locales:** se programan **en el teléfono** a partir de la copia local (sin servidor, sin señal) para los próximos 7 días y se reprograman al abrir la app, al sincronizar, al cambiar ajustes y al reiniciar (`RECEIVE_BOOT_COMPLETED`), más una tarea diaria. Usan **alarmas inexactas** (ventana de unos minutos; no se pide el permiso de alarmas exactas; *Observación 7*). La **laptop no programa recordatorios**; la tablet personal los trae apagados. Acciones en la notificación: *Hecho*, *Posponer 10 min*, *Omitir* para lo no sensible (funcionan con la app cerrada y sin señal); lo **sensible** solo ofrece *Posponer 10 min* y al tocar abre la app tras el PIN: ninguna acción escribe un dato sensible desde la pantalla bloqueada.
114. **Catálogo cerrado de textos** (`TextoAvisoHabitos`, en `habitos_dominio`; ≤ 40 caracteres, **sin dígitos, sin "$", sin nombres de hábitos ni cantidades**):

| `tipo` local | Título |
|---|---|
| `hab_bloque` (bloque no sensible, por área o general) | Tu siguiente actividad empieza pronto |
| `hab_lectura` | Es hora de tu lectura |
| `hab_momento` (devocional u oración, si no se elige mostrar el nombre) | Es hora de tu momento tranquilo |
| `hab_reservado` (**cualquier** hábito sensible, cierre de día, recordatorio de dar, respaldo, verificar frase) | Recordatorio |
| `hab_revision_pre` (14:15) | Tu revisión semanal empieza pronto |
| `hab_revision` (14:30) | Es hora de tu revisión semanal |
| `hab_cierre_dia` (no sensible) | Es hora de cerrar tu día |
| (sin sesión o sin señal) | Tienes un aviso de GRAVITY |

    El cuerpo va vacío. **Nombre opcional (no sensible):** si la persona activa `nombre_en_aviso` en un objetivo no sensible, el título es el nombre del objetivo (recortado a 40 caracteres, la pulsera lo muestra corto); **nunca** para un hábito a eliminar ni para el diario. El tipo `hab_*` entra en `tipos_silenciados` (regla de 4.6).
115. **Canales de Android** (nombres discretos): *Hábitos · Recordatorios* (importancia alta, vibración corta), *Hábitos · Reservados* (alta, vibración corta, visibilidad `PRIVATE` con la versión pública *"Recordatorio"*, sin acciones que escriban) y *Hábitos · Revisión* (por omisión). El permiso `POST_NOTIFICATIONS` se pide al activar los recordatorios, con explicación previa (regla 46 de la Fase 2).
116. **Horas silenciosas y tope:** respeta las horas silenciosas de `avisos_preferencias` (22:00 a 07:00 por defecto): en ese horario el recordatorio llega **sin sonido ni vibración**, no se cancela. El **tope de 3 avisos no críticos al día no aplica** a los recordatorios de agenda: los programó la persona (como los recordatorios fijos de la Fase 2). En **modo foco** se reducen a los esenciales.
117. **Sin Firebase ni bandeja en esta fase:** los recordatorios de Hábitos no pasan por el servidor ni por FCM, así que Google no ve ni siquiera un identificador (**P15**: si el dueño pide un respaldo por Firebase para la revisión semanal, se agregaría `hab_revision_semanal` a `avisos` con `hab_emitir_aviso`, que solo avisa de una fecha y nunca de contenido). El historial de recordatorios locales no se sincroniza. Las acciones de *Hecho* y *Omitir* hechas desde la notificación se guardan localmente y suben por la cola.
118. **Pulsera (D15, nivel 1):** recibe el mismo título del teléfono, sin botones prometidos; el aviso de prueba de *Ajustes › Notificaciones* sirve para comprobarlo. No hay SOS ni anillos en la pulsera (nivel 2, Wear OS).
119. **Deduplicación:** la `clave` del recordatorio es `hab:{tipo}:{objeto}:{fecha}:{n}`; su hash es el id de la notificación local, así que un recordatorio reprogramado reemplaza al anterior.

### 5.10 Herramientas de GRAVITY

120. **Herramientas de `habitos`** (todas `soloLocal`; ninguna llama a la IA; el resultado va a la pantalla, **nunca** a voz ni a bocinas; las que muestran contenido filtran lo sensible y dicen *"Hábito reservado"*): `habitos.resumen_hoy` (cuántos elementos faltan hoy, el siguiente y la racha global; excluye lo sensible), `habitos.abrir_hoy`, `habitos.abrir_agenda`, `habitos.abrir_lector`, `habitos.abrir_espiritual`, `habitos.abrir_revision` y `habitos.abrir_pausa` (abre el SOS tras el PIN). **Ninguna escribe** (no hay *marcar hecho* por GRAVITY hasta la Fase 6). **Las órdenes que mencionen un hábito sensible o el diario no se guardan en el historial de GRAVITY** (se guarda *"Orden de Hábitos reservada"*). Se pide a **asistente** agregar `habitos` a `modulosSoloLocal` en el registro.
121. **"Hoy" de GRAVITY:** la tarjeta de Hábitos de la pantalla principal y de Hoy del teléfono usa `habitos.resumen_hoy` (3/5 elementos, siguiente actividad). Con la sesión sin llave solo cuenta lo no sensible.

### 5.11 Progreso y revisión semanal

122. **Progreso por área:** cumplimiento semanal = `cumplidos ÷ programados` de la semana por área, en porcentaje entero hacia abajo, de las últimas 8 a 12 semanas (barras). Una semana sin elementos programados es *sin dato*, no 0 %. Se excluyen los hábitos a eliminar y todo lo sensible; las lecturas (días, capítulos) salen de `hab_lecturas` y del plan.
123. **Calendario de constancia:** un cuadro por día con **símbolo y color** (cumplido, gracia, no cumplido —tono suave—, no aplica) para la racha global y por objetivo; el día de hoy aparece abierto. No hay insignias ni niveles en esta fase.
124. **Programación de la revisión:** el sábado a las 14:30 con aviso a las 14:15 (`revision_dia`, `revision_hora`, `revision_aviso_min`; P4), como bloque fijo de tipo `revision` en la agenda y tarjeta en Hoy. Revisa la semana de lunes a domingo **con lo que haya hasta ese momento**; lo del domingo se suma al recalcular y las respuestas se conservan. Si ese sábado no se puede, se **mueve** a otro día de la misma semana o hasta el miércoles siguiente sin consecuencias; si no se hace, un toque la marca `omitida`. **No hay racha de revisiones** (P4: moverla nunca resta nada).
125. **Pasos de la revisión** (4.3 del diseño, sin los que dependen de fases posteriores; duración 15 a 25 minutos): (1) **Resumen por área** —qué funcionó y qué no, con cifras y rachas, en lenguaje sin culpa—; (2) **Hábitos a eliminar** (solo si hay llave): tendencia, mejores y peores momentos, disparadores y un ajuste sugerido (regla 126); (3) **Espiritual**: días de lectura, capítulos, minutos de oración y peticiones respondidas, más las preguntas *¿qué aprendí?, ¿qué agradezco?, ¿qué pido?, ¿qué obedezco esta semana?* (respuestas al diario); (4) **Dar** (solo si está activado, regla 87); (5) **Ajustes de la próxima semana**: mover o acortar bloques, bajar una meta, pausar un objetivo o, con confirmación, mover el Día D. Los ajustes quedan en `hab_revisiones.ajustes` y se aplican al terminar. Los pasos de **inglés y de estudios bíblicos** no existen aún.
126. **Ajuste sugerido de un hábito a eliminar:** lo propone una tabla de reglas simples del dominio (más apoyo, otro reemplazo, un paso más pequeño, endurecer la regla del refresco si sube semana tras semana, mover el Día D) a partir del resumen; **la persona decide**, el texto sigue la regla 21 y **nunca** incluye consejo médico ni dosis.
127. **Resumen en el teléfono (P4):** el aviso de las 14:15 abre un resumen de solo lectura y la versión corta (preguntas reflexivas y *Cerrar la revisión*); los ajustes de la próxima semana y las gráficas completas son de la laptop.
128. **Qué guarda:** `hab_revisiones` con estado, fechas, `resumen` (porcentajes no sensibles) y `ajustes`; las respuestas escritas, en el documento del diario; el resumen sensible no se guarda (se recalcula con la llave).

---

## 6. Pantallas

Siguen `DISENO_UX_UI.md` (sección 8 en la laptop, sección 9 en el teléfono, 11 en la tablet) y el estilo Futurista con la **personalidad por módulo**: *Contemplativa* para Espiritual (violeta, letra de lectura más grande, sin animación), *Empática* para hábitos a eliminar (terracota, contador grande, SOS visible, sin culpa) y la de Hábitos para el resto. Todas con estados vacío, cargando, sin conexión y error; letra al 200 % sin desbordes; sin reintentos automáticos; zonas táctiles de 48 dp; acciones por deslizamiento con alternativa por botón.

### 6.1 Laptop

| Pantalla | Contenido | Acción principal |
|---|---|---|
| **Hoy** | Tarjeta *Sigue*, lista por franja con progreso, medidor de carga, anillos, versículo del día, banners (foco, revisión semanal, Día D) | Marcar |
| **Agenda** (día / semana / mes) | Bloques con color y texto, huecos libres, conflictos, medidor de carga por día, horario laboral y traslado | Nuevo bloque |
| **Objetivos** | Lista por área, detalle con racha / avance / ritmo necesario, **asistente SMART** de 5 pasos, pausas | Crear objetivo |
| **Hábitos a eliminar** (solo si el modo es nube y hay llave) | Panel: fase, tarjeta de estado de hoy, rachas, cuenta regresiva al Día D, ahorro (oculto), pestañas *Hoy / Patrones / Hitos / Apoyo / Motivos*, configurar hábito (línea base, estrategia, fechas, límites, listas, disparadores, reemplazos) | Registrar |
| **Espiritual** | *Espiritual hoy*; **Lector** (libro, capítulo, versión, notas, subrayados, búsqueda); **Planes de lectura** (crear, ver, ponerse al día); **Devocional**; **Oración** (diario, listas, respondidas, temporizador). Lo del diario aparece solo con la llave | Leer |
| **Progreso** | Cumplimiento semanal por área (barras, 8 a 12 semanas), calendario de constancia (cada día con símbolo y color: cumplido, gracia, no cumplido, no aplica), rachas, lecturas | — |
| **Revisión semanal** | Pasos guiados (regla 125); gráficas del resumen; ajustes de la próxima semana (mover bloques, bajar una meta) | Cerrar la revisión |
| **Asistente de configuración** | Los 8 pasos de la regla 68, pausable, con la semana tipo | Terminar |
| **Ajustes › Hábitos** | Áreas, gracia semanal, rango del día, revisión semanal, recordatorio de dar, etiqueta del atajo, notificaciones (permiso, horas silenciosas, aviso de prueba, guía de la pulsera) | Guardar |
| **Ajustes › Privacidad › Datos sensibles** | Estado por tipo (solo teléfono / nube), cambiar de modo (instrucciones), **Añadir este equipo** (frase), cambiar o verificar la frase, **Reiniciar la nube**, bloqueo de la sección reservada, **Mis datos de Hábitos** (exportar y borrar) | — |

Si un dato está en `solo_telefono`, su pantalla muestra una tarjeta sobria *"Este dato está solo en tu teléfono"* con un botón *Cómo activar la nube cifrada* y no muestra nada más.

### 6.2 Teléfono

| Pantalla | Contenido | Acción principal |
|---|---|---|
| **Hoy** (pestaña Hábitos / Hoy) | *Sigue*, lista, carga del día, versículo, botón **Pausa / Tengo un antojo** siempre visible (aun con foco), banners | Hecho (1 toque) |
| **(+)** | Registrar un objetivo hecho, un cigarrillo o una porción de azúcar (1 toque con Deshacer), **Pausa**, nuevo bloque rápido | — |
| **Agenda del día** | Línea de tiempo del día y de mañana | — |
| **Espiritual** | *Espiritual hoy*, lector, plan del día, devocional, oración (diario y temporizador) | Leer |
| **Panel de hábito a eliminar** | Zonas de G.10.3 por fase; **Registrar** y **Tengo un antojo** siempre visibles; pestañas internas; todo detrás de la sección reservada | Registrar |
| **SOS** | Los 6 pasos de la regla 59, pantalla completa, botones grandes, FLAG_SECURE | Elegir técnica |
| **Revisión semanal** | Aviso 14:15; resumen de solo lectura y versión corta (preguntas reflexivas y *Cerrar*); los ajustes de la próxima semana se hacen en la laptop (P4) | Cerrar |
| **Progreso** | Racha global, anillos, calendario de constancia de la semana | — |
| **Ajustes › Hábitos** | Recordatorios, permiso, horas silenciosas, etiqueta del atajo, sección reservada, **crear la frase / respaldo / cambiar de modo**, **Mis datos** | — |

La pantalla de **frase de recuperación** es solo del teléfono y se abre con FLAG_SECURE, sin copiar al portapapeles.

### 6.3 Tablet pública y personal

Ver reglas 105 y 106: nombre + PIN, *Hoy* y lector de lo no sensible, sin sección reservada; tras 2 minutos regresa al modo Casa o al bloqueo.

### 6.4 Notificación de ejemplo

| Superficie | Qué ve |
|---|---|
| Pantalla bloqueada (hábito sensible) | *"Recordatorio"* · canal *Hábitos · Reservados* · sin cuerpo · solo *Posponer 10 min* |
| Pantalla bloqueada (bloque no sensible) | *"Tu siguiente actividad empieza pronto"* · *Hecho / Posponer / Omitir* |
| Pulsera | El mismo título corto con vibración; sin botones |
| Firebase / Google | Nada (no se usa en esta fase) |
| Bocinas / IA en la nube | Nada |

---

## 7. Criterios de aceptación

Las pruebas del dominio van en `paquetes/habitos_dominio/test/` (`dart test`); las de la app, en `app/test/modulos/habitos/` (`flutter test`); las SQL, en `supabase/tests/` con los números `90_` en adelante. Los ejemplos numéricos son los de las reglas.

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | **Fase anterior intacta:** las suites de Finanzas y de la Fase 0 a 2 siguen en verde; la matriz de permisos y su espejo no cambian | Suites existentes |
| 2 | **Racha diaria:** días cumplidos consecutivos; un día `no_aplica` en medio no la rompe; el día en curso sin registrar no la rompe; la racha rota vale 0 y la **mejor racha nunca baja** | `rachas_test.dart` |
| 3 | **Día de gracia (reglas 18 y 19):** lunes, martes y miércoles cumplidos, jueves sin cumplir, viernes cumplido, gracia 1 → jueves = `gracia` y la racha al viernes es 4; si además el sábado no se cumple, la racha se rompe; la gracia se reinicia cada lunes y no se acumula (falla el domingo y falla el lunes siguiente: cada una se cubre con la de su semana); con gracia 0 el jueves rompe | `rachas_test.dart` |
| 4 | **Frecuencias semanales:** `n_por_semana` y `semanal` cuentan semanas; una semana incompleta rompe; no hay gracia | `rachas_test.dart` |
| 5 | **Pausas y pausado:** los días en pausa son `no_aplica`; un objetivo `pausado` no suma ni rompe; un día antes de `fecha_inicio` no rompe | `rachas_test.dart` |
| 6 | **Racha global:** modo `por_area` con dos áreas y una sin nada programado ese día; modo `marcados`; día sin elementos = `no_aplica`; los hábitos a eliminar no cuentan | `racha_global_test.dart` |
| 7 | **Estados del día de un objetivo con cantidad:** suma de valores ≥ meta cumple; `parcial` no cumple pero no se rotula como falla; omitir con y sin motivo | `registro_test.dart` |
| 8 | **Orden de Hoy y "Sigue":** por hora, sin hora al final de la franja, empates por prioridad e id; *Sigue* elige el más cercano no hecho; con uno en curso muestra *En curso* | `hoy_test.dart` |
| 9 | **Carga del día:** con 200 minutos libres, 99 programados = ligero, 100 = equilibrado, 170 = equilibrado, 171 = saturado; `libres ≤ 0` = saturado; los bloques sensibles no cuentan; la propuesta mueve primero los no mínimos más largos | `carga_dia_test.dart` |
| 10 | **Hoy sin conexión:** marcar y deshacer sin señal, y subir con el mismo id al volver; el reintento no duplica | `cola_hab_test.dart` (app) |
| 11 | **Asistente SMART:** 5 pasos, valores por defecto y *Decidir después*; el avisar de saturación; un objetivo `eliminar` no se puede crear; el ritmo necesario redondea hacia arriba (meta 300 páginas, 30 días → 10 por día) | `objetivo_smart_test.dart`, pantalla |
| 12 | **Fases del cigarrillo:** con I = 2/nov/2026 y D = 30/nov/2026: 2 a 8/nov línea base; 9 a 22/nov reducción; 23 a 29/nov preparación; 30/nov Día D; 30/nov a 13/dic modo foco; 1 a 27/dic libre; desde 28/dic mantenimiento; antes de I, `no_iniciado`; mover D recalcula todo | `fases_habito_test.dart` |
| 13 | **Promedio de la línea base:** 84 cigarrillos en 7 días con datos = 12.00; 50 en 5 = 10.00; 4 días con datos = no calcula; un día sin registro ni cierre no cuenta como cero; un cierre "cero" sí | `linea_base_test.dart` |
| 14 | **Límites de reducción:** promedio 12.00 → 9, 6 y 3; 10.00 → 8, 5 y 3; mínimo 0; después de la última etapa se mantiene | `reduccion_test.dart` |
| 15 | **Recaída y racha del hábito:** D = 30/nov sin consumo al 4/dic → racha 5, mejor 5, acumulados 5; un cigarrillo el 5/dic → racha 0, mejor 5, acumulados 5; 6/dic libre → racha 1, mejor 5, acumulados 6; antes del Día D un cigarrillo no es recaída; no hay mensaje de culpa | `recaidas_test.dart` |
| 16 | **Varias recaídas:** 3 días de recaída en 14 sugiere hablar con un profesional o alguien de confianza; con 2, no | `recaidas_test.dart` |
| 17 | **Semáforo del refresco:** límite 4 → 0, 1 y 2 verde; 3 y 4 ámbar; 5 terracota; límite 1 → 0 verde, 1 ámbar, 2 terracota; límite 0: 0 verde y 1 terracota; periodo semana o mes | `semaforo_azucar_test.dart` |
| 18 | **Ahorro:** promedio 12.00, cajetilla de $150.00 con 20, un día sin consumo = $90.00 (9 000 centavos); días sin datos y días de la línea base no suman; consumir más que el promedio suma 0 (no negativo); oculto por defecto; ninguna columna en claro lleva dinero | `ahorro_habito_test.dart` + prueba SQL del esquema |
| 19 | **Hitos de constancia:** cigarrillo en 1, 3, 7, 14, 30, 60, 90, 180 y 365 días libres; un hito se marca visto una vez; no hay hitos de salud | `hitos_test.dart` |
| 20 | **SOS:** pausa → qué es → técnica → temporizador de 10 min → registro → cierre; *Sigue* repite con otra técnica; `superado` suma al contador; `consumo` ofrece registrar en 1 toque y el protocolo de recaída si aplica; sin conexión funciona | `sos_test.dart` + pantalla |
| 21 | **SOS accesible:** visible en Hoy, (+) y el panel aun en modo foco; el atajo de la pantalla de inicio abre el SOS tras la huella o el PIN; la etiqueta por omisión es *Pausa* | Pruebas de widget + medición manual en el A52 |
| 22 | **Registro en 1 toque:** registrar un cigarrillo o una porción es un toque y se puede deshacer; la hoja de disparador / ánimo / compañía es opcional | Prueba de widget (pasos) |
| 23 | **Sin culpa:** ningún mensaje usa *fallaste, fracaso, perdiste, culpa, castigo, vergüenza*; ningún estado de día no cumplido, recaída o superar el límite usa rojo; la racha rota dice *Retomemos hoy* | `mensajes_sin_culpa_test.dart` + revisión de colores |
| 24 | **Agenda:** un bloque recurrente se expande por días y cada N semanas; una excepción omite o mueve solo ese día; un conflicto con trabajo, traslado u otro bloque se avisa sin impedir guardar; los huecos libres se ordenan por cercanía | `agenda_test.dart` |
| 25 | **Asistente de configuración:** 8 pasos, cada uno con valor por defecto y *Decidir después*; se pausa y se reanuda; la semana tipo muestra la carga; el paso de privacidad no activa la nube sin que la persona lo elija | `asistente_test.dart` (dominio) + pantalla |
| 26 | **Referencias bíblicas:** `Juan 3:16`, `Jn 3:16-18`, `1 Corintios 13`, `1 Co 13:4–7`, `Sal 23`, `Génesis 1:1-2:3` se analizan; Juan es el libro 43; el NT tiene 27 libros y 260 capítulos; el canon, 66 y 1 189 | `referencia_biblica_test.dart` |
| 27 | **Planes de lectura:** Ruta de inicio = Juan 1 a 21 en 21 días; NT en 90 días = 80 días de 3 y 10 de 2 (suma 260); Biblia en un año = 94 días de 4 y 271 de 3 (suma 1 189); Salmos y Proverbios = 5 Salmos y 1 Proverbio por día y el día 30 lee Proverbios 30 y 31; la suma de capítulos siempre coincide | `plan_lectura_test.dart` |
| 28 | **Ponerse al día sin culpa:** Ruta de inicio, hoy el día 8 y los días 4 a 7 pendientes: `K = 4` → los días 8 a 11 leen 2; `K = 7` → los días 8 a 11 leen 2 y los días 12 a 14, 1; la fecha final no cambia; **Saltar** marca `saltado` y no cuenta en el %; **Reiniciar** recorre la fecha final | `plan_lectura_test.dart` |
| 29 | **Lector y versiones:** cambiar de RVR1909 a KJV conserva el lugar, las notas y los subrayados (por referencia); un versículo que no existe en la otra versión muestra la marca a nivel de capítulo; funciona sin conexión; el proveedor es intercambiable (una versión falsa de prueba) | `lector_test.dart`, pantalla |
| 30 | **Texto de dominio público:** cada versión incluida muestra su licencia y origen en *Acerca del texto*; no se incluye RVR1960 ni NVI | Revisión de calidad + prueba de recursos |
| 31 | **Devocional y oración:** el devocional guarda fecha, pasaje, reflexión, aplicación y oración; las peticiones pasan de pendiente a en espera a respondida con fechas; el temporizador suma minutos; todo vive solo en el documento cifrado de `diario_oracion` | Pruebas de widget + de documentos |
| 32 | **Revisión semanal:** se programa el sábado a las 14:30 con aviso a las 14:15 (configurable); recorre los pasos de la regla 125 y guarda lo respondido; moverla dentro de la semana no cambia nada más; no hay racha de revisiones; el resumen sensible se calcula en el dispositivo | `revision_semanal_test.dart` + pantalla |
| 33 | **Progreso:** cumplimiento semanal por área, calendario de constancia con símbolo y color y rachas coinciden con los registros | `progreso_test.dart`, pantalla |
| 34 | **Cifrado de documentos:** AES-256-GCM con nonce aleatorio y datos asociados; un sobre movido a otro `id` o `revision` **no descifra**; los vectores NIST de AES-GCM, RFC 5869 de HKDF y RFC 6070 de PBKDF2 pasan | `cifrado_test.dart` (app) |
| 35 | **Frase y llave:** 12 palabras de una lista de 2048 con 4 bits de verificación; una frase con una palabra cambiada no pasa la verificación; envolver y desenvolver la llave maestra con la frase correcta funciona y con otra falla; cambiar la frase conserva la misma llave maestra y los datos | `frase_llave_test.dart` |
| 36 | **Modos (D13):** valor por defecto `solo_telefono` para los dos tipos; pasar a nube exige la frase confirmada con 3 palabras; pasar a solo teléfono descarga todo primero, borra los sobres y los otros equipos borran su copia; si falla a medias se conserva el estado anterior | `modos_sensibles_test.dart` + prueba SQL |
| 37 | **Fusión de documentos:** dos dispositivos escriben el mismo día; la fusión une por elemento, gana el más reciente, una tumba más reciente elimina; es conmutativa e idempotente | `fusion_documentos_test.dart` |
| 38 | **Nada en claro de lo sensible:** la cola sin conexión, la base local y el servidor no contienen texto de un dato sensible (se busca una cadena marcada en todo lo persistido); los registros de fallas no llevan contenido | `sin_claro_test.dart` (app) + prueba SQL del esquema |
| 39 | **Servidor solo ve sobres:** `hab_sobres` no tiene columnas de texto claro; el servidor rechaza sobres de un tipo en `solo_telefono`, una `revision` que no sube de 1 en 1, más de 64 KB y la cuota; el id no revela la fecha | Pruebas SQL `90_hab_sobres.sql` |
| 40 | **RLS de Hábitos:** el dueño no lee lo de la pareja ni al revés; el coadministrador no lee lo del dueño; la cuenta maestra, el cuidador, la cuenta Hogar y `anon` no leen ni escriben nada; lo propio sí; una persona dada de baja pierde el acceso | Pruebas SQL `91_hab_rls.sql` |
| 41 | **Último gana y rangos:** un UPDATE con `modificado_en` más viejo se ignora; uno en el futuro lejano se ajusta; `dias_semana`, `duracion_min`, `gracia_semanal`, `meta_valor` fuera de rango se rechazan | Pruebas SQL |
| 42 | **Bitácora:** las tablas `hab_*` no escriben en la bitácora; reiniciar la nube, borrar datos y cambiar de modo dejan una entrada sin contenido; el dueño y la cuenta maestra **no** ven entradas `habitos.*` de otros; nadie fuera del servidor usa la acción `habitos*` | Pruebas SQL (amplía `30_bitacora.sql`) |
| 43 | **Borrado y exportación:** `hab_borrar_mis_datos` por tipo y total borra físicamente y sube la época; el dispositivo la detecta y limpia su copia; la exportación se valida con el esquema y avisa del contenido; el archivo sensible se protege con la frase | Pruebas SQL + `mis_datos_test.dart` |
| 44 | **Importación hostil:** un respaldo de 21 MB, con campos inesperados o de otra versión mayor se rechaza; la revisión muestra conteos y pide confirmación | `importar_respaldo_test.dart` |
| 45 | **Preferencias de avisos:** el familiar (sin Finanzas) tiene su fila; la cuenta maestra no; `tipos_silenciados` acepta los tipos `hab_*` y rechaza otros | Pruebas SQL (amplía `87_avisos_ajustes.sql`) |
| 46 | **Discreción de los avisos (D3, D13):** ningún texto de `TextoAvisoHabitos` tiene dígitos, "$", nombres ni más de 40 caracteres; ningún hábito sensible llega con nombre o cantidad; ningún archivo del módulo arma un aviso con datos de la base ni lo envía a un servicio | `avisos_discretos_habitos_test.dart` |
| 47 | **Recordatorios locales:** sin señal se programan los próximos 7 días; se reprograman al reiniciar y al cambiar ajustes; la misma `clave` no duplica; en horas silenciosas llegan sin sonido; el modo foco deja solo los esenciales; un hábito sensible usa el canal *Reservados* y solo *Posponer* | `recordatorios_habitos_test.dart` (programador falso) + medición manual en el A52 |
| 48 | **Acciones de la notificación:** *Hecho* con la app cerrada y sin señal marca el elemento y sube después; un bloque sensible no ofrece *Hecho*; al tocar un aviso sensible se pide la huella o el PIN | Prueba de plataforma + medición manual |
| 49 | **Pulsera:** en el A52 con la pulsera real, el aviso de prueba llega con el título corto y sin cuerpo; se anota el modelo (pendiente de D15) | Medición manual (calidad) |
| 50 | **Tablet pública y personal (D21):** el modo Casa no muestra nada de Hábitos; la **pública** con nombre + PIN ve solo *Hoy* y el lector no sensibles y jamás lo sensible; la **personal** se comporta como el teléfono (lo sensible solo con la llave añadida y modo nube); a los 2 minutos regresa | Pruebas de widget (como el criterio 6 de la Fase 0) |
| 51 | **Roles y pantallas:** dueño, coadministrador y familiar ven Hábitos; cuidador, Hogar y la cuenta maestra no ven el módulo ni su tarjeta de Hoy; papá no tiene cuenta | `habitos_por_rol_test.dart` (plataforma) |
| 52 | **Sección reservada:** pide PIN o huella al entrar y tras 2 minutos; FLAG_SECURE en sus pantallas; el modo privado de la laptop oculta su contenido; la tarjeta de GRAVITY solo dice *"Hábito reservado"*; en Windows avisa que no puede impedir capturas | Pruebas de widget + medición manual |
| 53 | **Herramientas de GRAVITY:** `habitos.resumen_hoy` y las cinco `abrir_*` son `soloLocal`; no hay ninguna que escriba; el registro rechaza una que no sea local; el resultado no menciona hábitos sensibles | Prueba del registro de herramientas |
| 54 | **Historial de GRAVITY:** una orden que menciona un hábito sensible o el diario se guarda como *"Orden de Hábitos reservada"* | `ordenes_habitos_test.dart` (asistente) |
| 55 | **Sin fugas (D3, D6):** nada de Hábitos va a la IA en la nube, a bocinas ni a Finanzas; el módulo no importa ni lee `finanzas_dominio` | Prueba de dependencias + revisión de calidad |
| 56 | **Meta de uso (H.5 / G.10.1):** una acción diaria cuesta 3 toques o menos; marcar en Hoy 1 toque; la app abre en menos de 2 s en el A52 | Pruebas de widget (pasos) + medición manual |
| 57 | **Accesibilidad y letra grande:** cada fila anuncia su estado; las acciones por deslizar tienen botón; letra al 200 % en 360 dp en el teléfono y desde 900 dp en la laptop sin desbordes; nada depende solo del color | `revision_fase3_test.dart` |
| 58 | **Contrato de columnas:** la app no manda `persona_id`, `hogar_id`, `actualizado_en`, `creado_en` ni la hora del servidor de un sobre; los ids estables se derivan con UUID v5 | `contrato_servidor_hab_test.dart` |
| 59 | **Contenido médico:** una revisión automática impide que el módulo incluya hitos de salud, dosis o recomendaciones de medicamentos y que muestre una línea de ayuda sin `verificado_en` | `contenido_verificado_test.dart` |
| 60 | **Esquema de datos:** `hab_*` con RLS activado, sin `anon`, con los checks de rango; cualquier tabla nueva respeta la red de seguridad de la Fase 0 | Pruebas SQL (`10_esquema.sql` ampliado) |

---

## 8. Trabajo por agente

| Agente | Entrega | Carpetas |
|---|---|---|
| **habitos** | **Dominio (Dart puro, sin dependencias, con las pruebas de la sección 7):** `objetivos.dart` (objetivos, frecuencias, ritmo necesario, plantillas), `rachas.dart` (estados del día, gracia, pausas, rachas diaria / semanal / global), `hoy.dart` (elementos, franjas, *Sigue*), `carga_dia.dart`, `agenda.dart` (expansión, excepciones, huecos, conflictos), `asistente.dart`, `habito_eliminar.dart` (fases, línea base, límites, recaídas, semáforo, hitos, ahorro), `sos.dart` (estados y registro), `espiritual.dart` (referencias, canon, planes, ponerse al día, versículo del día, devocional y oración), `revision_semanal.dart`, `progreso.dart`, `mensajes.dart` y `TextoAvisoHabitos`, `documentos_cifrados.dart` (formato, `Cifrador` abstracto con un falso, fusión, ids), `frase.dart` (lista de palabras y verificación), `exportacion.dart`. **App:** repositorios (memoria, drift y Supabase), casos de uso (marcar / posponer / omitir, registrar consumo, SOS, planes, devocional, oración, revisión, cambiar de modo, añadir equipo, exportar / borrar), implementación real del `Cifrador` (AES-GCM / HKDF / PBKDF2 con `pointycastle`) con sus vectores, el almacén de documentos cifrados, las pantallas de la sección 6, las herramientas `habitos.*` y la tarjeta de Hábitos de Hoy (con `asistente`). **Especificación** | `paquetes/habitos_dominio`, `app/lib/modulos/habitos`, `docs/specs/fase-3-*` |
| **backend** | Migraciones de 4.1 a 4.5: tablas `hab_*` (ajustes, modos, objetivos, bloques, registros, pausas, planes, días, lecturas, marcas, revisiones, sobres, llaves) con RLS (`hab_activa`), privilegios por columna, `hab_ultimo_gana`, checks de rango; funciones `hab_iniciar` (trigger), `hab_cambiar_modo`, `hab_guardar_llave`, `hab_subir_sobres`, `hab_reiniciar_nube`, `hab_borrar_mis_datos`, `hab_crear_plan_lectura`, `hab_limpiar` y su tarea; **ajustes a D20** (`avisos_preferencias` para quien tenga Hábitos sin Finanzas, `tipos_silenciados` con los `hab_*`); **bitácora**: reservar `habitos*` y ocultar `habitos.*` al dueño y a la cuenta maestra; `seed.sql` ficticio; pruebas SQL de los criterios 18, 36, 38 a 43, 45, 58 y 60; entrada en `supabase/README.md` con la cuota y la advertencia de que el servidor nunca ve texto claro de lo sensible | `supabase/` |
| **plataforma** | Rutas por rol y por dispositivo para Hábitos (teléfono, laptop, tablets según reglas 105 y 106) y exclusión de la cuenta maestra, Hogar y cuidador; **recordatorios locales con acciones** (`flutter_local_notifications`) con acciones *Hecho / Posponer / Omitir* que funcionan con la app cerrada, los **tres canales**, reprogramación al reiniciar y tarea diaria, hash de la `clave`; atajos de la pantalla de inicio (*Pausa*, *Registrar*, *Hoy*); almacén seguro de la `llave_local` y la `llave_maestra` (Keystore y almacén de credenciales de Windows), protegido por PIN o huella; **sección reservada** (PIN al entrar, bloqueo a los 2 minutos, FLAG_SECURE, modo privado en la laptop, vista previa oculta); cola sin conexión que guarda sobres cifrados; **subida diferida** de sobres; sincronía por incremento (`actualizado_en`) y detección de `epoca_nube`; `Ajustes › Hábitos` y `Ajustes › Privacidad › Datos sensibles`; medir PBKDF2 (600 000) en el Galaxy A52; exclusión del almacén sensible del respaldo automático de Android; exportar y borrar; permisos de Android | `app/lib/app`, `app/lib/nucleo`, `app/lib/modulos/ajustes`, `app/pubspec.yaml`, `app/android` |
| **diseno** | Gadgets y componentes: **Anillos del día**, **Chip de racha** (número, día de gracia y *Retomemos*), **Fila con deslizar** (hecho / posponer / omitir con botón alterno), **Tarjeta Sigue**, **Medidor de carga del día**, **Contador de días libres + botón Pausa** (personalidad empática, terracota, nunca rojo), **Semáforo de hábitos** (verde, ámbar y terracota con texto), **Calendario de constancia**, **Temporizador del SOS** y **respiración guiada**, **Panel de hábito a eliminar** (G.10.3) y su tarjeta por fase, **Lector** (letra de lectura, modo oscuro, brillo bajo, sin animación), **Tarjeta de objetivo**, **Hoja inferior**, estados vacíos con mensajes sin culpa; maquetas de Hoy, Agenda, Espiritual, SOS y Revisión; el recurso de la Biblia en `app/assets/biblia/` (convertido por el script de importación, ver pedido a arquitecto) y su declaración en la sección `flutter:` del `pubspec.yaml` | `app/lib/diseno`, `app/assets` |
| **asistente** | Registro de `habitos.resumen_hoy` y las `habitos.abrir_*` (`soloLocal`, solo lectura / navegación), agregar `habitos` a `modulosSoloLocal`, órdenes de navegación (*"abre hoy"*, *"abre el lector"*, *"abre la revisión"*, *"pausa"*), **no guardar en el historial** las órdenes con hábitos sensibles, y las operaciones nuevas (RPC y tablas `hab_*`) en `api/openapi.yaml` | `app/lib/nucleo/herramientas`, `app/lib/modulos/gravity/ordenes`, `api/` |
| **calidad** | Revisión de cierre: D13 (nada en claro de lo sensible en disco, cola, servidor, fallas y copias de pantalla), RLS (ni el dueño ni la maestra ven lo de otros), frase y recuperación (prueba de pérdida), discreción de los recordatorios y la pulsera, mensajes sin culpa, **contenido médico y líneas de ayuda verificados**, licencias del texto bíblico, accesibilidad y letra grande, medición en el A52 (recordatorios con la app cerrada, SOS, 3 toques) | `docs/revisiones/` |

**Pedidos a otras áreas / al arquitecto**
1. **Arquitecto:** asignar una carpeta para el **script de importación** del texto bíblico (`herramientas/biblia/`), que convierte la edición confirmada por el dueño al formato propio (JSON comprimido por libro), valida los totales (66 libros, 1 189 capítulos) y deja la licencia y el origen en un archivo `LICENCIA`; el dueño confirma la edición y la fuente (P10) antes de correrlo.
2. **Arquitecto / backend:** la bitácora reserva `habitos*` y oculta `habitos.*` (regla 98); registrar en `docs/DECISIONES.md` la propuesta **D21** de la sección 10 (datos sensibles de Hábitos: frase, llaves y modos) cuando el dueño la apruebe.
3. **Plataforma:** el `Cifrador` real y el almacén local sensible van en la app; el dominio solo define el contrato.

**Orden sugerido:** (1) especificación aprobada y dominio (rachas, fases, planes, formato de documentos) con sus pruebas; (2) migraciones y RLS; (3) núcleo: objetivos, Hoy y registro sobre la base local; (4) hábitos a eliminar y SOS (el plan de cigarrillo es lo más urgente; la línea base se puede empezar en papel); (5) cifrado, modos y frase; (6) agenda, asistente y recordatorios; (7) espiritual; (8) progreso y revisión; (9) calidad. Lo que depende del dueño (texto bíblico confirmado, valores de P5 a P9, línea de ayuda verificada) **no bloquea**: hay valores por defecto y el contenido pendiente queda detrás de una bandera.

---

## 9. Preguntas para el dueño

Cada pregunta trae la **propuesta por defecto** con la que se construye si no hay respuesta. Ninguna bloquea programar.

### 9.1 Datos sensibles (D13)

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P1** | ¿Cuál es el valor por defecto de los dos modos? Y, ¿el diario de oración incluye los devocionales escritos y las notas del lector? | **`solo_telefono` para los dos tipos** (nada sale del teléfono hasta que lo actives) y, en el asistente de configuración, la app te explica la nube cifrada y lo eliges. El **diario de oración** incluye peticiones, listas, sesiones, **devocionales escritos, notas del lector y respuestas de la revisión semanal**. Los hábitos a eliminar quedan en el otro tipo. Pierdes lo del teléfono si lo pierdes sin respaldo; por eso se recomienda activar el respaldo cifrado |
| **P2** | ¿Cómo se respalda la llave de la nube? | **Frase de 12 palabras** que anotas en papel (confirmas 3 al azar), sin recuperación por nadie más; "Añadir la laptop" con la frase; "Verificar mi frase" cada 90 días; si pierdes frase y equipos, "Reiniciar la nube". Los sobres se suben **en lote** para que el servidor no vea la hora de cada registro. ¿Prefieres otra forma (por ejemplo, una contraseña tuya o un archivo de llave)? |
| **P3** | *Respondida (D21):* ¿la tablet puede mostrar lo sensible? | **Pública: nada. Personal: como el teléfono**, solo con la frase y el modo nube |
| **P20** | *Respondida (D21):* copia diaria con tablas en claro | **Sí**, con aviso a la pareja en *Ajustes › Privacidad* |
| **P21** | *Respondida (D21):* baja de una persona | **Se conservan sin acceso y se borran a los 90 días** |

### 9.2 Hábitos a eliminar (valores del plan; todo se edita en la app)

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P5** | **Fases del plan de cigarrillo:** línea base, reducción, Día D, foco, mantenimiento | Línea base **7 días**; reducción **3 semanas** al **25, 50 y 75 %** por debajo del promedio (ejemplo del diseño); preparación los **7 días antes** del Día D; **Día D = inicio + 28 días**; modo foco **14 días**; consolidación hasta **Día D + 28** y luego mantenimiento. ¿Tu fecha de inicio? ¿Mantienes 25 / 50 / 75 % y esa fecha de Día D? |
| **P6** | ¿Cuántos días con datos hacen falta para calcular el promedio de la línea base? | **5 de 7** (si faltan, se ofrece extender la línea base sin obligar) |
| **P7** | **Azúcar:** ¿cuántas veces al mes (o a la semana) es "ocasional" y qué es una ocasión? ¿Cuándo pasa a ámbar? | La app **te lo pregunta** (el diseño no da valor); ámbar a partir de **75 %** del límite y terracota al pasarlo; listas verde / amarilla / roja con los ejemplos del diseño y editables |
| **P8** | **SOS: qué muestra, tiempos y nombre** (propuesta del agente, el dueño la revisa; los textos viven en `habitos_dominio/lib/src/sos.dart` como datos) | Seis pasos con textos propios cortos y sin consejo médico: (1) *Pausa*: "Respira. Las ganas pasan; casi siempre duran pocos minutos." con respiración guiada; (2) *¿Con qué es el antojo?*; (3) *Elige algo pequeño para estos minutos* (respiración, beber agua, caminar 5 minutos, masticar algo sin azúcar, llamar a alguien de apoyo, un versículo y una oración corta; tus favoritas primero); (4) temporizador de **10 min** (5 a 15): "Si en 10 minutos sigue, repetimos." y la pregunta "¿Sigue el antojo?"; (5) registro opcional de 30 s (intensidad 1 a 5, disparador, qué hice); (6) cierre: "Lo atravesaste. Eso suma." o "Una caída no borra lo avanzado. ¿Qué te ayudaría mañana?". A la vista: **tus motivos**, un versículo de ánimo y tu persona de apoyo. Botón y atajo llamados **"Pausa"** |
| **P9** | **Versículos de ánimo** (propuesta del agente, el dueño la revisa) | Solo de RVR1909 y KJV (dominio público), **por referencia**; el texto sale del lector y una prueba verifica que cada referencia exista en el texto importado: Salmos 46:1, Salmos 121:1-2, Isaías 41:10, Josué 1:9, Filipenses 4:13, 1 Corintios 10:13, Gálatas 5:22-23. Datos en `versiculosAnimo`; el dueño agrega o quita |
| **P16** | **Hitos de salud y línea de ayuda:** ¿me das una fuente oficial verificada? ¿Confirmas el número de la Línea de la Vida (800 911 2000) del diseño? | **No se publica nada médico sin fuente verificada**: hitos de **constancia** sí; hitos de salud, no. La línea de ayuda **no se muestra** hasta que la verificas y la app guarda la fecha; mientras tanto dice *"Habla con tu médico o con alguien de confianza"* |
| **P17** | **Ahorro:** ¿se calcula contra el promedio de la línea base y queda dentro de Hábitos? | **Sí**, contra el promedio de la línea base, mínimo 0 por día, **oculto por defecto**, cifrado como el hábito y **nunca** hacia Finanzas, pareja, IA ni avisos |
| **P22** | **SOS al manejar:** hoy el SOS es visual. ¿Lo dejamos hasta que GRAVITY tenga voz? | **Sí** (Fase 6): mientras tanto la app no ofrece un modo para el coche |

### 9.3 Núcleo y agenda

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P4** | ¿Cómo prefieres hacer la **revisión semanal** en el teléfono? | Resumen y versión corta (preguntas reflexivas y cerrar) en el teléfono; la revisión completa (gráficas y ajustes de la semana siguiente) en la laptop |
| **P12** | **Día de gracia y racha global** | **1 día de gracia por semana**, aplicado solo al primer día no cumplido; **no hay gracia** en metas semanales; la racha global cuenta el **mínimo de un cumplido por cada área activa** con algo programado (o los elementos que marques como mínimos), **sin** los hábitos a eliminar |
| **P13** | **Medidor de carga del día** | *Ligero* por debajo del **50 %** de tu tiempo libre (despertar a dormir, menos trabajo y traslado), *equilibrado* hasta el **85 %** y *saturado* arriba |
| **P18** | **Libros** | Sin biblioteca ni citas: un objetivo de **páginas** con plantilla |
| **P19** | **Revisión mensual y rueda de la vida** (parte de la etapa 5 del Anexo H) | **Fase 8+**; la Fase 3 trae solo la revisión semanal |

### 9.4 Espiritual

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P10** | **Versiones de la Biblia:** ¿qué **edición exacta y fuente** de RVR1909 y KJV usamos? ¿Cómo se resuelve la licencia de RVR1960 y NVI? | Se arranca con **RVR1909 y KJV** (dominio público) en un proveedor intercambiable; el dueño confirma la edición y la fuente antes de incluir el texto. RVR1960 / NVI cuando resuelvas la licencia o el servicio (API.Bible) |
| **P11** | **Planes de lectura** | Ruta de inicio (Juan, 21 días), Nuevo Testamento en 90, Salmos y Proverbios en 30 (5 Salmos y 1 Proverbio al día), Biblia en un año en orden canónico y por libro; cronológico, temático y personalizado después |

### 9.5 Avisos

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P14** | **Recordatorios y horas** | Textos **discretos** del catálogo (sin nombres ni cantidades), nombre opcional solo en objetivos no sensibles, horas silenciosas **22:00 a 07:00** sin sonido, sin tope diario para lo que programas tú, alarmas inexactas (unos minutos de margen) |
| **P15** | ¿La revisión semanal debe avisar también **por Firebase** como respaldo? | **No**: ningún aviso de Hábitos viaja por Firebase; si lo quieres, se agrega solo el aviso de la revisión, sin contenido |
| **P24** | Etiqueta del atajo y del recordatorio de dar | **"Pausa"** y **"Recordatorio"** |

### 9.6 Datos y cuentas para usarla (no bloquean)

1. **La edición y fuente del texto de RVR1909 y KJV** (P10).
2. **Tus valores del plan** (P5, P7, P9) y tus **motivos**, que se capturan en la app, no en el repositorio.
3. **Una fuente oficial** para los hitos de salud y la confirmación de la línea de ayuda (P16).
4. **Un Galaxy A52** para medir los recordatorios con la app cerrada, el tiempo de PBKDF2 y la pulsera (criterios 21, 47 a 49 y 56).

---

## 10. Observaciones sobre el diseño y sobre otras fases

1. **D13 en "la nube cifrada".** Cifrar solo el contenido deja visible al servidor *cuándo* hay actividad. Esta especificación reduce la fuga con **un sobre por día y tipo**, ids opacos y **subida en lote**; aun así el servidor ve que hubo actividad ese día. Conviene registrarlo como **D21** (propuesta del agente de hábitos): *frase de recuperación de 12 palabras, llave maestra envuelta en el servidor, `solo_telefono` por defecto, tablets sin llave*, y que Calidad lo revise.
2. **Notas del lector, devocionales y respuestas de la revisión** se tratan como diario porque D.1 pide "privacidad máxima para oración, diario y notas". El ROADMAP y D13 solo nombran "el diario de oración"; es una ampliación conservadora (P1).
3. **Racha global con hábitos a eliminar:** el diseño (G.10.1) no los excluye; se excluyen para que la racha sea la misma con o sin la llave.
4. **La plantilla del cigarrillo (F.14) solapa** "reducción" y "preparación" en la semana 4; aquí son dos fases con intervalos disjuntos (regla 32) y las etapas de reducción siguen por semanas hasta el Día D.
5. **El SOS por voz y por audio manejando** (F.5, G.8) no está en esta fase; el diseño exige no pedir mirar la pantalla al manejar y el modo traslado es de la etapa 8. **Riesgo:** una persona que fuma al volante podría abrir el SOS visual. Mitigación: ninguna pantalla pide texto ni más de un toque, y el SOS por voz es prioridad en la Fase 6.
6. **La copia de seguridad diaria de la laptop** contiene las tablas en claro de todas las personas del hogar (P20); lo sensible solo como sobres. Aplica igual a Finanzas (Fase 1); aquí la sensibilidad es mayor.
7. **Recordatorios con alarmas inexactas:** Android puede retrasarlos varios minutos con el ahorro de batería; el diseño pide probar en el teléfono real y quitar la optimización de batería durante las pruebas (H.7). Si el dueño necesita puntualidad, se pide el permiso de alarmas exactas (queda por decidir con plataforma).
8. **El Anexo B y el paso 12 del asistente** del diseño (conexión con Presupuesto por archivos y enlaces) quedan **sustituidos por D1**; conviene actualizar el diseño de HÁBITOS (nota de cabecera).
9. **El Anexo H dice "PIN o biometría" en la etapa 0** y "respaldo y exportación local"; aquí ya existen (Fase 0) y se reutilizan.
10. **Versículos y hitos** son contenido: no se copian de memoria. El texto bíblico viene del archivo confirmado; los hitos de salud de F.4 esperan fuente verificada.
11. **Cifras de los planes de lectura** (260 capítulos del NT, 1 189 del canon) son datos conocidos; la prueba los comprueba contra el texto importado, que es la fuente.

## 11. Lo que necesita el dueño del proyecto

1. **Aprobar** esta especificación (o marcar cambios) y contestar la sección 9; mientras tanto se construye con las propuestas por defecto.
2. **Confirmar la edición y la fuente** de RVR1909 y KJV (P10) y **aprobar la propuesta D21** (observación 1).
3. **Decidir los valores de tu plan** de cigarrillo y azúcar (P5, P7, P9) cuando uses la app; no hacen falta para programar.
4. **Dar una fuente oficial** para los hitos de salud y **verificar la línea de ayuda** (P16); sin eso se muestran solo hitos de constancia.
5. Para la medición final: un **Galaxy A52 con la pulsera enlazada** (criterios 21, 47 a 49 y 56) y anotar el modelo de la pulsera (D15).

---

## Respuestas del dueño (1/nov/2026)

P1: sensibles solo en el teléfono por ahora (nube desactivada por omisión). P2: frase de 12 palabras. P3: **cambia** — la tablet **personal** funciona como el teléfono; la **pública** no. P5: la fecha de inicio la fija cada miembro. P8/P9: se propone el SOS y los versículos para su revisión. P20: la copia incluye las tablas en claro, con aviso a la pareja. P21: datos de una persona dada de baja se conservan sin acceso y se borran a los **90 días**. Detalle en D21.


### 11.1 Estado de la implementación (habitos, 6/nov/2026)

- **Hecho y probado:** dominio (`paquetes/habitos_dominio`, rachas, gracia, fases, línea base, recaídas, semáforo, ahorro, SOS, agenda, planes de lectura, fusión de documentos, avisos discretos); app (`app/lib/modulos/habitos`): Hoy, objetivos con asistente SMART y avance real, agenda con bloques, huecos, conflictos y carga del día, asistente de configuración de 8 pasos, hábitos a eliminar (configurar, registrar, Deshacer, fases, recaída sin culpa, semáforo, ahorro oculto), SOS con guardado cifrado del antojo, espiritual (lector con `gravity-biblia-v1`, planes con *ponerse al día*, devocional y oración cifrados), progreso, revisión semanal, exportar mis datos (lo reservado **solo con la frase**, F3-13) y recordatorios locales (F3-7); importador de la Biblia endurecido (F3-14).
- **Servidor listo, flujo de la app pendiente:** activar la **nube cifrada** (generar la frase, `hab_guardar_llave`, `hab_cambiar_modo`, subida de los documentos), volver a *solo teléfono*, **añadir otro equipo con la frase**, *Reiniciar la nube* y detectar el cambio de `epoca_nube` desde otro equipo. Las tablas y funciones existen y están probadas en SQL (`hab_guardar_llave`, `hab_cambiar_modo`, `hab_subir_sobres`, `hab_reiniciar_nube`, `hab_borrar_mis_datos`) y la plataforma tiene las llaves, los sobres y la subida diferida (`app/lib/nucleo/sensibles/`); falta la pantalla y el caso de uso que las unen (criterios 36 y 43 quedan **parciales**). Por decisión del dueño, por ahora usa **solo el teléfono**, el valor por defecto: nada sale del dispositivo.
- **Pendiente de contenido:** el texto de RVR1909 y KJV (edición, fuente y licencia por confirmar, P10); sin él, el lector dice que el texto aún no está instalado.
- **Pendiente de interfaz:** subrayados y notas dentro del lector, editar bloques y objetivos, hitos de constancia en el panel, motivos, disparadores y listas de azúcar en la configuración, recordatorio de dar, aviso de la revisión en el teléfono con versión corta.
