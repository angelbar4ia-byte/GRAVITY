# Fase 8 · Cuidados · Rutina física en cama de Papá (especificación)

> v0.2, 23/nov/2026. **Borrador para el dueño.** Solo especificación: no hay código, migraciones ni pruebas todavía. Base: D2, D3, D5, D6, D13, D14, D18, D20, D23 y D28 (`docs/DECISIONES.md`), `docs/specs/fase-5-cuidados.md` y el código de Cuidados ya construido. Se especifica a la par con el gimnasio propio del dueño (`fase-8-habitos-gimnasio.md`, otro agente); **este documento no depende de aquel ni lo usa**.
>
> **Hechos de partida (23/nov/2026).**
> 1. Papá tiene **sarcopenia**. **Hoy por la tarde es su primera cita con un fisioterapeuta, así que todavía no hay indicaciones.** Por eso esta especificación **no inventa ejercicios, series, cargas ni frecuencias**: el contenido de la rutina lo define el fisioterapeuta o el médico; la app solo lo guarda, lo recuerda y registra cómo salió.
> 2. Papá además tiene **Alzheimer** (ya consta en el repositorio: D5 `docs/DECISIONES.md:119`, D23 `:496`) y **le resulta complicado hacer la rutina por sí solo** (dato del dueño, 23/nov/2026). **Consecuencia de diseño: la rutina es siempre asistida.** La app **no se dirige a Papá**: la pantalla es para quien lo ayuda (cuidadora, dueño o hermana). Todo el documento está escrito con esa premisa.

## Cómo leer este documento

- **[V]** = verificado en el repositorio, con archivo y línea (las líneas son las de hoy; pueden moverse).
- **[P]** = propuesta de esta especificación; no existe todavía y el dueño la puede cambiar.
- **[D]** = decisión ya confirmada del dueño (con su fuente).
- Las rutas relativas son a `/home/user/gravity/`.

---

## 1. Alcance y lo que NO es

### 1.1 Qué es [P]

Una pequeña parte de **Cuidados** que permite a la familia:

1. **Capturar** la rutina física en cama (o sentado) que **indique un profesional**, con quién la indicó, cuándo, hasta cuándo vale y cuándo se revisa, y **cómo indicársela a Papá y apoyarlo**, tal como lo diga el profesional.
2. **Programarla** en los días y horas que se indiquen (sesiones **breves y fraccionables**), ligada a quien esté de turno (**Mi turno**) y a lo que la familia anote sobre cuándo Papá está mejor.
3. **Guiar a quien ayuda** (no a Papá), una instrucción corta a la vez y con letra grande, mostrando **solo lo que se capturó**.
4. **Registrar** cómo salió cada sesión (hecha, parcial, no quiso, se desorientó o se agitó, no se pudo) y las **señales** que se reportaron, y **avisar a la familia** si hubo alguna.
5. Mostrar un **historial neutro** (cuántas sesiones de cada tipo), sin rachas, sin metas y sin culpar a nadie.

### 1.2 Qué NO es [P]

- **No es una prescripción ni un consejo médico.** GRAVITY no indica, sugiere, ajusta ni evalúa ejercicios. No dice si algo está bien o mal hecho, ni si «va mejorando».
- **No hay catálogo de ejercicios, ni plantillas, ni «rutinas recomendadas», ni IA.** Cada ejercicio existe porque una persona de la familia lo escribió a partir de la indicación del profesional. Una rutina vacía es un estado válido y honesto.
- **La app no progresa la carga** (no sube series, repeticiones ni tiempos por sí sola). La progresión es una nueva indicación del profesional que la familia captura como **versión nueva**.
- **No interpreta señales.** Solo las registra y avisa. No dice «es normal» ni «es grave». **No deduce** el estado de ánimo, la lucidez ni la cooperación de Papá: eso lo anota una persona.
- **No es una app para Papá.** Papá no tiene cuenta (D5), no usa la pantalla y no se le muestran guías, resultados ni historial. No hay modo «para que lo siga él». Si Papá está presente, el modo privado oculta la pantalla.
- **Sin rachas, metas, puntos ni «días seguidos».** Una sesión que se mueve de hora o de día no «rompe» nada, porque no hay nada que romper. Una negativa de Papá no es un fallo de nadie.
- **Sin voz, sin sonidos propios y sin bocinas.** La guía no habla ni suena; ningún recordatorio de esta función se lee en voz alta ni sale por las bocinas (D6).
- **No guarda el diagnóstico** (no hay campo «diagnóstico» en esta función); el diagnóstico es dato clínico (D3) y vive donde ya vive.
- **No sustituye las citas del profesional.** Las visitas del fisioterapeuta se siguen registrando como **citas** de Cuidados (`cui_citas`, ya existe, [V] `supabase/migrations/20261121000000_cuidados_pendientes.sql:225-236`).
- **No calcula proteína, calorías ni suplementos.** Solo muestra, si la familia lo captura, lo que el profesional indicó sobre alimentación (sección 7).
- **No exporta, no imprime y no comparte** la rutina ni el historial por mensajería (persona bajo cuidado: sin envío por mensajería, [V] `docs/CONTRATO_CONEXION_APPS.md:139`).

### 1.3 Textos fijos de seguridad [P]

Los únicos textos clínicos-adyacentes que no vienen del profesional serían dos, y ambos requieren la aprobación del dueño (pregunta 4):

- «**Si es una emergencia, llama al 911.**» (número nacional de emergencias de México; no es consejo clínico).
- «**Indicación de [nombre], [fecha]. GRAVITY no la sugiere ni la modifica.**» (siempre visible, letra pequeña, en la guía y en la pantalla de la rutina).

Todo lo demás que ve la cuidadora sale de campos capturados por la familia, y cuando un campo está vacío la pantalla lo dice («El profesional no indicó señales para parar») en lugar de rellenarlo.

---

## 2. Hallazgos del código y del diseño que condicionan esta especificación

| # | Hallazgo | Fuente |
|---|---|---|
| H1 | La cuidadora ve «Mi turno»: tarjetas *Turno de hoy*, *Entrega de turno*, *Cambios urgentes* y una lista de accesos con botones grandes (64 dp de alto, letra 20). Una tarjeta nueva y un acceso nuevo encajan sin rediseñar. | [V] `app/lib/modulos/cuidados/pantallas/mi_turno.dart:19-35`, `:177-260`; `pantallas/comunes.dart:57` |
| H2 | El menú de Papá ya se ve **dentro de Cuidados**, solo lectura, con el perfil de Alimentación. Es el patrón para mostrar algo de otro módulo sin escribirlo. | [V] `app/lib/modulos/cuidados/pantallas/menu_papa.dart:1-39` |
| H3 | Los permisos de Cuidados los decide el servidor con `cui_perfil()` y `cui_puede(hogar, objeto, accion)`; la app lleva un espejo. `cui_puede` solo conoce ocho objetos (turnos, medicamentos, tomas, comidas, bitácora, entregas, cambios, gastos); cualquier otro devuelve falso. La versión vigente está en la migración 20261123 (con la regla de la cuenta maestra ajena). | [V] `supabase/migrations/20261123000000_cuidados_revision.sql:66-103`; `20261114000000_cuidados_esquema.sql:206-243`; espejo: `app/lib/modulos/cuidados/casos_uso/permisos_cuidados.dart:17-52` |
| H4 | Solo el dueño escribe medicamentos y turnos; la cuidadora y la hermana marcan tomas **solo si están de turno a la hora**; la pareja ve medicamentos, tomas, comidas y bitácora **solo con consentimiento**; la cuenta maestra ajena solo lee turnos; Casa no ve nada de lo clínico. | [V] `20261123000000_cuidados_revision.sql:75-103`; `20261118000000_cuidados_v12.sql:4-6` |
| H5 | La cuidadora lee de la bitácora **lo suyo y lo del dueño y la hermana**; lo de la pareja no (salvo instrucciones). | [V] `supabase/migrations/20261117000000_cuidados_v11.sql:1-10`; `20261120000000_cuidados_instrucciones.sql:38-43` |
| H6 | Quién está de turno sale de `cui_quien_en_turno(hogar, ts)`, en la zona del hogar; sin cuidadora ni hermana, el **dueño** es el turno residual (nunca queda vacío). Los recordatorios de toma los genera el **servidor** (cron cada 5 min) y llegan solo a quien está de turno; clave de deduplicación por persona. | [V] `20261114000000_cuidados_esquema.sql:325-352`; `20261117000000_cuidados_v11.sql:8-11`; `20261124000000_cuidados_recordatorios.sql:93-150`; spec Fase 5 §8i (`docs/specs/fase-5-cuidados.md:103-109`) |
| H7 | **Cambio urgente:** solo el dueño lo crea (RPC `cui_crear_cambio_urgente`, texto de 1 a 200), avisa **al instante** (severidad crítica) al cuidador de turno, sin texto en el aviso: el aviso apunta al objeto y la app lee el detalle con las reglas por rol. La cuidadora lo marca «Enterada». **No existe el camino contrario** (cuidadora → dueño). | [V] `20261115000000_cuidados_operaciones.sql:93-134`; `mi_turno.dart:134-175`; `20261113000000_cuidados_avisos.sql` |
| H8 | Los avisos salen de un **catálogo cerrado**: título de máximo 40 caracteres, sin dígitos, sin «$», sin nombres, cuerpo vacío; por Firebase solo viaja `{v, id}`. Los de Cuidados son genéricos («Hora de un recordatorio de cuidado», «Cambio urgente en los cuidados»). Agregar un tipo exige ampliar los `check` de `avisos` y la severidad (así lo hizo la migración de recordatorios). | [V] `app/lib/nucleo/avisos/catalogo_avisos.dart:1-8`, `:74-77`, `:128-129`; `20261124000000_cuidados_recordatorios.sql:17-41`; D20 `docs/DECISIONES.md:458-467` |
| H9 | La confirmación «Hecho» / «No se pudo» con nota existe como patrón en `nucleo/solicitudes`: *No se pudo* exige nota, máximo 200 caracteres. Pero es **solo en memoria** (Fase 1, datos de ejemplo); **no hay tabla de servidor** de solicitudes. | [V] `app/lib/nucleo/solicitudes/solicitudes.dart:5-9`, `:32-33`, `:52-66`; búsqueda en `supabase/migrations`: sin tabla |
| H10 | **Cuidados no usa la cola sin conexión hoy:** las acciones son llamadas directas al servidor (`_rpc`) y, sin señal, la app muestra «No se pudo guardar. Intenta de nuevo.». La cola tiene el prefijo `cuidados.` marcado como personal (en tablet pública pide nombre y PIN y deja lo no enviado **en claro** en la base local hasta 7 días). | [V] `app/lib/modulos/cuidados/datos/repositorio_supabase.dart:110-111`, `:391`; `pantallas/comunes.dart:15-37`; `app/lib/nucleo/cola/cola_sin_conexion.dart:59-66`, `:77-93` |
| H11 | Toda ruta bajo `/cuidados` está protegida contra capturas de pantalla (FLAG_SECURE) para quien ve datos clínicos; una ruta nueva bajo `/cuidados` lo hereda sin trabajo extra. | [V] `app/lib/app/pantalla_segura.dart:35-40` |
| H12 | Los datos de Cuidados están **en claro** en Supabase (sin cifrado de extremo a extremo); D13 solo cubre los datos sensibles de Hábitos. La revisión de la Fase 5 lo dejó como pregunta abierta al dueño y **sigue sin respuesta escrita** (pregunta 4 de su sección 7). La copia diaria de la laptop incluye las tablas en claro, cifrada (AES-256). | [V] `docs/revisiones/fase-5.md:82`, `:120`; D17 `docs/DECISIONES.md:378`; D21 `:481` |
| H13 | **`palabras_es` no es una herramienta de redacción.** `app/lib/nucleo/sensibles/palabras_es.dart` es la lista de 2048 palabras (BIP-39) de la frase de recuperación de Hábitos. Los mecanismos reales para que lo clínico no se filtre son: la bitácora de auditoría con **columnas omitidas** (medicamentos «sin nombre, dosis, horas ni notas»), el catálogo cerrado de avisos, las herramientas `soloLocal`, la pantalla segura y las reglas por rol. | [V] `palabras_es.dart:1-8`; `supabase/README.md:814`; `app/lib/nucleo/herramientas/herramienta.dart:25-30`; `supabase/functions/gravity-asistente/catalogo.json:100-101` (solo `cuidados.abrir`) |
| H14 | El perfil de Papá en Alimentación dice «Dieta alta en proteínas y aminoácidos; no puede comer alimentos duros» **sin cifras**; en `modelos.dart` de Alimentación no encontré campos de proteína ni de gramos. Ese perfil es dato clínico y lo edita solo el dueño. | [V] `app/lib/modulos/alimentacion/datos/perfiles.dart:22-30`; D23 `docs/DECISIONES.md:494-501`; `docs/specs/fase-4-alimentacion.md:91` |
| H15 | **No existe `paquetes/cuidados_dominio`** aunque el roadmap lo lista como carpeta del agente. Hoy la lógica pura de Cuidados vive en `app/lib/modulos/cuidados/casos_uso/` y `app/lib/nucleo/cuidados/`. Solo hay `finanzas_dominio` y `habitos_dominio`. | [V] `ls paquetes`; `docs/ROADMAP.md:227` |
| H16 | **Posible choque de dueño del dato:** el diseño de Hábitos dice que «Ejercicio, rutinas… » son de Hábitos y «no se comparte»; el contrato dice que los datos clínicos de la persona bajo cuidado son de la app de cuidados y que `persona_bajo_cuidado` va sin IA, sin Health Connect y con seguimiento registrado por el cuidador. D1: un solo escritor por tipo de dato. Esta especificación asigna la rutina de Papá a **Cuidados**. | [V] `docs/modulos/habitos/diseno-app-habitos.md:434`, `:890`; `docs/CONTRATO_CONEXION_APPS.md:36`, `:139`; D1 `docs/DECISIONES.md:53` |
| H17 | D3 sigue marcada «Confirmada (cuidados: propuesta)» y D6 como «Propuesta»: las reglas de privacidad de Cuidados que esta especificación aplica (nada a la IA ni a las bocinas, recordatorios genéricos) están aprobadas en la práctica por la Fase 5 pero **la parte de Cuidados de D3 no figura como confirmada**. | [V] `docs/DECISIONES.md:15`, `:21`, `:86` |
| H18 | El documento de la **app de cuidados actual** nunca llegó al repositorio; no pude comprobar si ya tiene algo parecido a una rutina de ejercicio. | [V] `docs/specs/fase-5-cuidados.md:3`, `:144`; `docs/CONTRATO_CONEXION_APPS.md:10` |
| H19 | **El Alzheimer de Papá ya está registrado** como dato del proyecto (rol «Persona bajo cuidado», perfil «Adulto mayor con Alzheimer» en Alimentación) y el diseño ya describe a la cuidadora como alguien que atiende «a una persona con Alzheimer, con interrupciones constantes». Lo nuevo del 23/nov es que le cuesta hacer la rutina solo. | [V] `docs/DECISIONES.md:119`, `:496`; `app/lib/modulos/alimentacion/datos/perfiles.dart:23`; `docs/DISENO_UX_UI.md:63` |
| H20 | **La tablet pública nunca recibe avisos personales** (D20) y los recordatorios locales de Cuidados **no se programan** en ella aunque la cuidadora esté dentro por PIN (F5-M7, cerrado). Esta función hereda ese comportamiento: ni sonido ni aviso de ejercicio en la tablet de la casa. | [V] `docs/DECISIONES.md:466`; `docs/revisiones/fase-5.md:161` |
| H21 | Fase 5 permitió **recordatorios genéricos en voz alta** para las tomas (sin nombre de medicamento ni de persona) y planeó mandarlos a las bocinas en la Fase 6. Para el ejercicio se propone **más estricto**: **ningún** recordatorio en voz alta ni en bocinas. | [V] `docs/specs/fase-5-cuidados.md:87`, `:103-109`; D6 `docs/DECISIONES.md:161` |

---

## 3. Modelo de datos propuesto [P]

Todo en Supabase con prefijo `cui_` (D2, D7), **dato clínico (D3)**. Convenciones de la Fase 0: UUID generados en el dispositivo, fechas `date`/`timestamptz`, semana en lunes, hora del hogar en la zona `cui_zona` ([V] `docs/specs/fase-0-cimientos.md:61-73`; `20261114000000_cuidados_esquema.sql:~190-204`). Sin dinero. Los nombres de columnas son propuesta; backend los afina.

**Principio:** el servidor guarda **texto libre escrito por la familia** y solo valida su forma (largo, cantidad, enumeraciones de estado). **No guarda cifras clínicas como números con significado** (no hay columnas `series` ni `repeticiones` ni `carga`): lo que dijo el profesional («3 de 8», «30 segundos», «lo que tolere») se escribe tal cual en `dosis_texto`. Así la app no puede calcular, comparar ni «progresar» nada clínico.

### 3.1 `cui_rutinas` (una fila por **versión**)

| Campo | Tipo y regla |
|---|---|
| `id` | uuid (dispositivo) |
| `hogar_id` | uuid |
| `version` | entero que sube de 1 en 1 por hogar (lo pone el servidor) |
| `nombre` | texto 1 a 80 (p. ej. el nombre que el dueño le dé) |
| `indicada_por` | texto 1 a 80: **nombre de quien la indicó** (fisioterapeuta o médico) |
| `indicada_por_tipo` | `fisioterapeuta` \| `medico` \| `otro` |
| `fecha_indicacion` | date, obligatoria |
| `vigente_desde` | date, la pone el servidor al publicar (por omisión hoy) |
| `vigente_hasta` | date, **opcional** («durante 4 semanas», si el profesional lo dijo) |
| `revision_en` | date, **opcional** (cuándo volver o revisar) |
| `duracion_texto` | texto ≤ 120, **opcional**: cuánto dura una sesión, **como lo dijo el profesional** |
| `fraccionamiento_texto` | texto ≤ 200, **opcional**: si la sesión se puede dividir en momentos del día y cómo, **solo si el profesional lo indicó** |
| `como_indicarle` | texto ≤ 300, **opcional**: **cómo dirigirse a Papá** (palabras, tono, gestos, una instrucción a la vez…), tal como lo indique el profesional |
| `como_motivarlo` | texto ≤ 300, **opcional**: **cómo animarlo**, tal como lo indique el profesional |
| `si_se_niega` | texto ≤ 500, **opcional**: **qué hacer si se niega o se desorienta**, tal como lo indique el profesional |
| `supervision_texto` | texto ≤ 200, **opcional**: qué supervisión requiere y si puede quedar solo un momento (**siempre asistida** salvo que el profesional diga lo contrario por escrito) |
| `senales_parar` | texto ≤ 500, **opcional**: señales para parar, **en palabras del profesional** |
| `si_ocurre` | texto ≤ 500, **opcional**: qué hacer si se cansa o hay dolor, **en palabras del profesional** |
| `aprobada_por`, `aprobada_en` | texto ≤ 80 y date, **opcionales**: nombre y fecha del **médico tratante** (neurólogo o geriatra) si dio su visto bueno. Se muestran, **no se exigen** salvo que el dueño lo decida (pregunta 2) |
| `alimentacion_indicada` | texto ≤ 300, **opcional**: lo que el profesional dijo de proteína o alimentación (sección 7) |
| `restricciones_horario` | texto ≤ 200, **opcional**: «antes o después de comer / de medicamentos», si lo dijo (se muestra, **no se aplica**) |
| `notas_profesional` | texto ≤ 500, opcional |
| `estado` | `borrador` \| `vigente` \| `reemplazada` \| `suspendida` \| `descartada` |
| `creada_por`, `creada_en`, `publicada_en`, `suspendida_en`, `suspendida_por` | los pone el servidor |

Reglas:

- **Una sola versión `vigente` por hogar** (índice único parcial). Publicar una versión nueva la deja `vigente` y la anterior `reemplazada`, **en la misma transacción**.
- Una versión **publicada es inmutable**: lo único que cambia después es su `estado` (a `reemplazada` o `suspendida`) por RPC, igual que `cui_cambios_guardar` solo deja cambiar `atendido_en` una vez ([V] `20261114000000_cuidados_esquema.sql:490-500`). Corregir un error de captura = versión nueva.
- Los **borradores** los edita solo el dueño por RPC (reemplazan sus filas hijas) y no los ve nadie más. Un borrador abandonado pasa a `descartada`; **ninguna fila se borra**. Así no queda texto clínico a medias en el teléfono: **el borrador vive en el servidor, no en el dispositivo**.
- Una rutina se puede **publicar incompleta** (por ejemplo sin `senales_parar`), pero la pantalla de publicación lo avisa campo por campo y la guía lo muestra como «El profesional no indicó…». No se bloquea: lo que falte es información que el dueño puede no tener aún.
- Mínimos para publicar: `nombre`, `indicada_por`, `fecha_indicacion` y **al menos un ejercicio**. Si el dueño activa «exigir visto bueno del médico tratante» (pregunta 2), también `aprobada_por` y `aprobada_en`.
- **Los campos `como_indicarle`, `como_motivarlo` y `si_se_niega` los escribe la familia a partir de lo que diga el profesional.** La app **no trae frases de ejemplo ni sugerencias** en esos campos: aparecen vacíos y, si se quedan vacíos, la guía dice «El profesional no indicó cómo dirigirse a Papá». Una frase inventada por el software para hablarle a una persona con Alzheimer sería contenido clínico no validado.

### 3.2 `cui_rutina_ejercicios` (hijas de una versión, en orden)

| Campo | Tipo y regla |
|---|---|
| `id`, `rutina_id`, `orden` | uuid, uuid, entero (1 a 12) |
| `grupo` | texto ≤ 40, opcional («Sesión A»); sirve si el profesional separa días distintos; vacío = todos los días |
| `nombre` | texto 1 a 80 |
| `postura` | texto ≤ 60 (atajos de captura «En cama» y «Sentado»; **texto libre**, p. ej. de lado, si el profesional lo indicó) |
| `dosis_texto` | texto ≤ 120: series, repeticiones o tiempo **como los dijo el profesional** |
| `descanso_texto` | texto ≤ 120, opcional |
| `como_indicarle` | texto ≤ 200, opcional: **qué decirle a Papá y cómo** para **este** ejercicio, tal como lo indique el profesional (sustituye al de la rutina si existe) |
| `como_hacerlo` | lista de 1 a 8 pasos, cada uno texto **≤ 120**, opcional: **lo que el profesional mostró o dijo**, dividido en pasos **muy cortos** para que la guía muestre **uno a la vez** |
| `apoyo` | texto ≤ 200, opcional: **cómo apoyarlo y de quién** («una persona al lado», «dos personas», dónde colocarse…), tal como lo indique el profesional |
| `material` | texto ≤ 120, opcional (bandas, pelota, almohada…): **solo si el profesional lo indicó** |
| `senales_parar` | texto ≤ 300, opcional: señales específicas de este ejercicio |
| `notas_profesional` | texto ≤ 300, opcional |

Si no hay `como_hacerlo`, la guía muestra el nombre, la postura y la dosis tal cual, y una línea: «Sin pasos capturados. Pregunta a la familia». **La app no acorta ni reescribe** los pasos que la familia escribió: si exceden el largo, la captura pide dividirlos.

### 3.3 `cui_rutina_programacion` (cuándo, por versión)

| Campo | Tipo y regla |
|---|---|
| `id`, `rutina_id` | uuid |
| `dia_semana` | 1 a 7 (1 = lunes), igual que `cui_turnos` ([V] `20261114000000_cuidados_esquema.sql:38-47`) |
| `inicio_min` | 0 a 1439 (minutos desde medianoche, zona del hogar) |
| `ventana_min` | 0 a 240, **opcional**: el hueco es una **ventana** que empieza en `inicio_min` y dura tanto; 0 = sin ventana. Lo fija la familia, no la app |
| `grupo` | texto ≤ 40, opcional: qué grupo de ejercicios toca en ese momento (vacío = todos); sirve para **fraccionar** la sesión en momentos del día |
| `ayuda_de` | `turno` (quien esté de turno; por omisión) \| `cuidadora` \| `dueno` |

Máximo 14 filas por versión; **puede haber varios huecos el mismo día** (fraccionar). «Frecuencia semanal y duración» que diga el profesional se traduce a filas de esta tabla y, si es una duración total, a `vigente_hasta`. La app **no propone** horarios ni deduce «la mejor hora»: el horario se escoge **a mano**, mirando la nota «Cuándo suele estar mejor» (sección 3.6) que la familia mantiene.

### 3.4 `cui_sesiones` (lo que pasó; **solo agregar**)

| Campo | Tipo y regla |
|---|---|
| `id` | uuid del dispositivo; la primera captura de un hecho usa un id **estable** (v5) para que reintentar no duplique ([V] `app/lib/modulos/cuidados/datos/modelos.dart:16-20`); una corrección usa un id nuevo |
| `hogar_id`, `rutina_id` | la **versión** que estaba vigente cuando se hizo |
| `programacion_id` | opcional (nulo = sesión no programada, «extra») |
| `fecha` | date (la de la sesión, en la zona del hogar) |
| `resultado` | `hecha` \| `parcial` \| `no_quiso` («no quiso / se negó») \| `se_desoriento` («se desorientó o se agitó») \| `no_se_pudo` (otra razón, p. ej. no había quién ayudara) |
| `ejercicios_hechos`, `ejercicios_total` | enteros opcionales, solo cuentan pasos de la guía (sin significado clínico) |
| `senales` | arreglo opcional con valores de la lista cerrada: `mareo`, `dolor`, `falta_aire`, `cansancio_extremo`, `caida`, y las propias de la demencia **`agitacion`**, **`angustia`**, **`desorientacion`**, más `otra` |
| `nota` | texto ≤ 200; **obligatoria** solo si `no_se_pudo` o si `senales` no está vacío ([V] patrón en `solicitudes.dart:52-66`); **opcional** y breve en `parcial`, `no_quiso` y `se_desoriento` (una negativa no debe exigir justificación) |
| `registrada_por`, `registrada_en` | los pone el servidor (la app no los manda, como en `cui_comidas`, [V] `20261114000000_cuidados_esquema.sql:386-420`) |

- **Solo agregar:** sin UPDATE ni DELETE ni TRUNCATE, con el mismo trigger `impedir_cambios_solo_agregar` de comidas y bitácora ([V] `20261114000000_cuidados_esquema.sql:~461-470`). La corrección es una fila nueva y **vale la más reciente** por (`programacion_id`, `fecha`), como en las comidas ([V] spec cabecera `:10-11` de esa migración).
- **`no_quiso` y `se_desoriento` son resultados normales de una sesión asistida, no fallos.** No generan aviso por sí solos, no exigen nota, no cuentan como «incumplimiento» en ninguna pantalla ni cálculo, y no se atribuyen a la cuidadora ni a Papá. Si hay señales, el aviso nace de las **señales**, no del resultado (5.3).
- La **lista de señales** es la que pidió el dueño como punto de partida más las de la demencia; el fisioterapeuta y el médico tratante pueden pedir otras (pregunta 4 y anexo). Cambiar la lista cerrada es una migración, no un dato.
- Tope: se suma a `cui_tope_diario` (300 registros propios en 24 h, [V] `:422-447`).

### 3.5 Cómo se relaciona con lo que ya existe

| Existente | Relación [P] |
|---|---|
| **Bitácora** (`cui_bitacora`, solo agregar, nota ≤ 500) | La nota de la sesión vive **en la sesión**; no se duplica en la bitácora. La cuidadora sigue pudiendo escribir una nota libre en la bitácora como siempre. La **bitácora de auditoría** (`public.bitacora`) recibe `cuidados.sesion_registrada` con **solo el resultado** (como `cuidados.toma_marcada`), sin nota, sin señales, sin nombres. |
| **Solicitudes de la cuidadora** (D5/D18: GRAVITY recuerda, ella confirma *Hecho / No se pudo* con nota) | Cada hueco programado aparece en «Mi turno» como un pendiente con **los mismos botones** y la misma regla de nota. Se agregan *Parcial*, *No quiso* y *Se desorientó o se agitó* (una negativa es un resultado normal, no un «No se pudo»). **No se usa `SolicitudGravity`** (es en memoria, H9, y su estado no tiene «parcial»): se imita su comportamiento con tabla de servidor propia. **GRAVITY (la IA) no interviene**: el recordatorio lo genera el servidor, no el modelo (D3). |
| **Cambios urgentes** (dueño → cuidadora) | Al publicar una versión nueva, el dueño puede marcar «Avisar a quien está de turno», que llama al **RPC existente** `cui_crear_cambio_urgente` con un texto **fijo y sin contenido clínico**: «La rutina de ejercicio cambió. Revísala en Mi turno.» (cabe en 200 caracteres; `cui_cambios_urgentes.texto` ya existe). Sin tipo de aviso nuevo para este caso. |
| **Señal reportada** (cuidadora → dueño) | Camino **nuevo** (H7): aviso crítico al dueño por RPC (sección 5.3). |
| **Citas** (`cui_citas`) | La cita del fisioterapeuta es una cita normal; la sesión de ejercicio **no** es una cita. |
| **Entrega de turno** (`cui_entregas`) | La tarjeta «Entrega de turno» de Mi turno muestra, **solo lectura**, una línea: «Ejercicio de hoy: hecha a las 11:00 / pendiente / hubo una señal registrada». Quien se va sigue escribiendo la nota de entrega a mano; **no se copia nada automáticamente** al texto de la entrega. |
| **Notas de la familia sobre la rutina** (`cui_ejercicio_notas`, 3.6) | Dónde se anota «cuándo suele estar mejor» y observaciones breves, **sin que la app deduzca nada**. |
| **Medicamentos y tomas** | No se mezclan. Mi turno ordena por hora lo programado (tomas, comidas, ejercicio) sin reglas entre ellos; `restricciones_horario` solo se muestra. |

### 3.6 `cui_ejercicio_notas` (lo que anota la familia; **solo agregar**)

| Campo | Tipo y regla |
|---|---|
| `id`, `hogar_id` | uuid, uuid |
| `tipo` | `mejor_momento` \| `observacion` |
| `texto` | texto 1 a 300 |
| `registrada_por`, `registrada_en` | los pone el servidor |

- `mejor_momento` guarda lo que la familia o la cuidadora **observan** sobre cuándo Papá está más tranquilo o con más claridad («por la mañana, después del desayuno»). Es **un dato escrito por una persona**; la app no lo calcula, no lo infiere de las sesiones y no lo usa para reprogramar nada. Se muestra en la tarjeta de Mi turno («Anotado por la familia: …») y en la pantalla de captura, para que el dueño elija el horario.
- **No forma parte de la versión de la rutina**: cambiarlo no crea versión nueva, porque no es una indicación del profesional. Vale la nota `mejor_momento` más reciente.
- Escriben el dueño, la cuidadora y la hermana (en turno); leen lo suyo y lo del dueño y la hermana, como la bitácora (`cui_autor_visible_cuidadora`, [V] `20261117000000_cuidados_v11.sql:16-33`), **sin límite de 7 días**; la pareja con consentimiento lee todo. Mismas reglas de solo agregar, tope diario y auditoría sin texto que el resto.

---

## 4. Quién ve y quién escribe (RLS por rol) [P]

Los permisos viven en el **servidor** (D5, D7). Se propone una función nueva `cui_ejercicio_puede(hogar, objeto, accion)` que **delegue en `cui_perfil` y `cui_es_maestra_ajena`** en lugar de ampliar `cui_puede`. Motivo: `cui_puede` ya se reemplazó tres veces (20261114, 20261118, 20261123) y reescribirla otra vez arriesga una regresión silenciosa de la matriz de Fase 5 (R8). El espejo en la app (`permisos_cuidados.dart`) agrega los objetos `rutina` y `sesiones` en paralelo, con una prueba que compara ambos.

| Perfil | Rutina: leer | Rutina: crear, editar borrador, publicar, suspender | Programación | Sesiones: leer | Sesiones: registrar |
|---|---|---|---|---|---|
| **Dueño** | todas las versiones y borradores | **sí** (única persona) | escribe | todo el historial | sí (cuando él ayuda) |
| **Pareja sin consentimiento** | no | no | no | no | no |
| **Pareja con consentimiento** | versiones publicadas (solo lectura) | no | lee | todo el historial (solo lectura) | no |
| **Cuidadora** (con perfil por turnos) | **solo la versión vigente** | no | lee la vigente | **últimos 7 días** (suyas y de dueño/hermana, con `cui_autor_visible_cuidadora`, [V] `20261117000000_cuidados_v11.sql:16-33`) | sí, **si está de turno ahora** |
| **Hermana** | solo la vigente | no | lee la vigente | últimos 7 días | sí, **si está de turno ahora** (`hermana_visita`) |
| **Cuenta maestra ajena** (D19) | no | no | no | no | no |
| **Casa / tablet pública sin PIN** | no | no | no | no | no |
| **Cuidador sin turnos**, dado de baja, otro hogar, `anon` | no (sin perfil) | no | no | no | no |

Reglas de detalle:

1. **Solo el dueño** crea y publica rutinas, porque lo que llega de la cita lo captura el dueño (o quien él decida más adelante, **cambio explícito**). Es la misma regla de medicamentos y turnos ([V] `20261123000000_cuidados_revision.sql:96-97`). La cuidadora **no ajusta** la rutina; si algo no funciona lo escribe en la nota de la sesión o en la bitácora (pregunta 3).
2. **Registrar sesiones:** el dueño siempre; la cuidadora y la hermana solo si `cui_quien_en_turno(hogar, now())` las devuelve (mismo criterio que marcar tomas, [V] `20261118000000_cuidados_v12.sql:4-6`). Fuera de turno: `42501`, el mismo mensaje exista o no el registro. Una sesión puede ser **programada** o **extra**.
3. **Historial:** solo agregar, nadie borra ni edita. Lo que registró alguien dado de baja queda **a su nombre** (D5, [V] `docs/DECISIONES.md:127`).
4. **Baja:** perder la membresía corta todo en la misma consulta, porque todas las reglas parten de `rol_en_hogar()` ([V] `supabase/README.md:779`).
5. **Escritura solo por RPC** (`cui_rutina_guardar_borrador`, `cui_rutina_publicar`, `cui_rutina_suspender`, `cui_registrar_sesion`): se revocan INSERT/UPDATE directos, como en tomas. La app no manda `registrada_por`, `*_en`, `version` ni `estado`.
6. **Consentimiento y dignidad de Papá:** no se agrega un consentimiento nuevo; estos datos caen bajo el que ya firma el albacea por Papá ([V] `docs/specs/fase-5-cuidados.md:45-50`). Papá no tiene cuenta ni perfil: **ninguna regla de esta función le da acceso a él** y no hay una vista «para el paciente». La rutina la **lleva** la persona que ayuda; quien registra la sesión es esa persona.
7. **Notas de la familia** (`cui_ejercicio_notas`, 3.6): escriben dueño, cuidadora y hermana (estas dos, en turno); lectura como la bitácora, sin límite de 7 días; pareja con consentimiento, solo lectura; el resto, nada.

---

## 5. Flujos y pantallas

Todas las pantallas viven bajo `/cuidados` (heredan la pantalla segura, H11) y usan la variante **clara y de alto contraste** de Cuidados, sin decoración ([V] `docs/DISENO_UX_UI.md:94`). Textos **impersonales** (*«¿Cómo salió?»*, *«Marcar como hecha»*, [V] `docs/DISENO_UX_UI.md:306`).

### 5.1 Dueño: capturar la rutina (laptop; en el teléfono solo suspender y registrar)

D4 deja la configuración de Cuidados en la laptop ([V] `docs/DECISIONES.md:98`); el teléfono del dueño conserva los cambios urgentes ([V] `:103-106`), por lo que **editar** la rutina es de laptop y **suspender** también puede hacerse desde el teléfono [P].

**Estado vacío (sin rutina)** [P]. Título: **«Sin indicaciones del profesional»**. Cuerpo: «Aquí aparecerá la rutina cuando la familia la capture a partir de lo que indique el fisioterapeuta o el médico. GRAVITY no sugiere ejercicios.» Un solo botón: **«Capturar indicaciones»**. Para la cuidadora el mismo estado dice: «Todavía no hay una rutina indicada. No hay nada que hacer aquí.», sin botones.

**Captura** [P], en seis pasos cortos, todos opcionales salvo los mínimos de 3.1:

1. *Quién la indicó*: nombre, tipo, fecha de la indicación y, si lo hay, el visto bueno del médico tratante.
2. *Cuándo*: duración de la sesión, si se fracciona, días y horas (filas de programación, con ventana si se desea), vigencia y fecha de revisión. La pantalla muestra al lado la nota «**Cuándo suele estar mejor**» (3.6) para elegir el horario a mano.
3. *Ejercicios*: uno por uno (nombre, postura, dosis tal como la dijo el profesional, **cómo indicarle**, pasos muy cortos, apoyo, material, señales, notas). Campos en blanco se quedan en blanco.
4. *Cómo dirigirse a Papá*: **cómo indicarle, cómo motivarlo y qué hacer si se niega o se desorienta**, y la supervisión. **Todos vacíos al empezar, sin ejemplos.**
5. *Cuándo parar y qué hacer*: señales, «si ocurre», alimentación indicada, restricciones de horario.
6. **Revisión de lo capturado**: una sola pantalla que **repite todo con letra grande** para leerlo de vuelta al profesional («Mostrar al profesional»: solo en pantalla, sin enviar). Lista lo que falta («Falta: señales para parar»). Botones: **Guardar como borrador** y **Publicar**.

Al publicar: la versión anterior pasa a *reemplazada*; opción «Avisar a quien está de turno» (3.5, cambio urgente existente). El historial de versiones queda visible solo para el dueño (y la pareja con consentimiento).

**Suspender** (en cualquier momento, también desde el teléfono): quita la tarjeta de Mi turno; no borra nada; pide motivo corto (3 a 200 caracteres, la misma validación de «motivo válido», [V] `docs/DECISIONES.md:391`) y avisa a quien esté de turno con el cambio urgente existente.

### 5.2 Quien ayuda (cuidadora, hermana o dueño): «Mi turno» y la guía

**Premisa:** la pantalla es **para quien ayuda**, nunca para Papá. Los textos se dirigen a esa persona y hablan de Papá en tercera persona; no hay botones ni mensajes pensados para que él los lea, toque o escuche. La app **no tiene** un modo «para que lo siga él».

**Tarjeta «Ejercicio» en Mi turno** [P], entre *Turno de hoy* y *Entrega de turno*. Solo aparece si hay versión vigente. Muestra:

- La próxima sesión programada de **su turno** («Hoy a las 11:00», o «Entre 11:00 y 12:00» si el hueco tiene ventana) y su estado (pendiente / hecha / parcial / no quiso / se desorientó o se agitó / no se pudo).
- «**Anotado por la familia: …**» con la nota `mejor_momento` más reciente, si existe (3.6). La app **no** la calcula.
- Botón grande **«Empezar»** (64 dp, letra 20 como el resto, [V] `comunes.dart:57`) y, a su lado, **«Hoy no»** (un toque + confirmar): registra *No quiso* o *No se pudo* sin pasar por la guía y sin exigir nota si es *No quiso*. **Decidir no hacerla hoy es una opción normal, no un trámite.**
- «Indicación de [nombre], [fecha]» y, si hay `vigente_hasta` o `revision_en` vencidas, la nota neutra de 5.5.
- **Una sesión pendiente se puede hacer en otro momento del mismo día** (el hueco sigue abierto hasta el final del día; la persona de turno que esté en ese momento puede hacerla, o fraccionarla en varios huecos). **Moverla no «rompe» nada**: no hay rachas ni metas (1.2).

**Guía paso a paso** [P] (pantalla propia, **una sola instrucción a la vez**):

1. **Pantalla de preparación** (antes de empezar el primer ejercicio): «Cómo dirigirse a Papá» (`como_indicarle` de la rutina), «Cómo apoyarlo» (`apoyo`), «Cómo animarlo» (`como_motivarlo`), «Supervisión» y el material. Todo **tal como se capturó**; los campos vacíos dicen «El profesional no indicó…». Sin imágenes ni animaciones inventadas.
2. **Un paso por pantalla.** Arriba, «Ejercicio 2 de 5 · paso 1 de 3» y el nombre (≥ 28 sp); debajo, **solo** el paso actual (≤ 120 caracteres, letra ≥ 28 sp), y debajo de él, en un bloque aparte, «**Qué decirle**» (`como_indicarle` del ejercicio) **solo si existe**. La postura, la dosis y el apoyo del ejercicio se ven en el encabezado, sin saturar.
3. Botones: **«Siguiente»**, **«Anterior»** y, **siempre visibles**, **«Se negó o se desorientó»** y **«Algo no va bien»** (con icono y texto: nada depende solo del color, [V] `docs/DISENO_UX_UI.md:50`).
4. **«Se negó o se desorientó»** abre una hoja con el `si_se_niega` del profesional (o «El profesional no indicó qué hacer en esta situación»), y tres botones: **«Reintentar más tarde hoy»** (cierra sin registrar y deja el hueco pendiente), **«Terminar aquí»** (registra *No quiso* o *Se desorientó o se agitó* con nota opcional) y **«Algo no va bien»**. La app **no insiste** ni propone convencerlo.
5. **«Algo no va bien»** abre la hoja de señales (5.3): casillas **Mareo, Dolor, Falta de aire, Cansancio extremo, Caída, Agitación, Angustia, Desorientación, Otra** (la última con texto), debajo el `senales_parar` y el `si_ocurre` del profesional **o** «El profesional no indicó qué hacer en esta situación. Avisa a la familia.», más el texto fijo del 911 (1.3). Botón único **«Terminar aquí y avisar»**: registra la sesión como *Parcial* (o *No se pudo* si no se hizo ningún ejercicio; *Se desorientó o se agitó* si se marcó alguna de las tres señales de demencia) con las señales y avisa al dueño (5.3). **La app no dice qué hacer**; solo muestra lo capturado.
6. Al terminar el último paso: «¿Cómo salió?» con **Hecha**, **Parcial**, **No quiso**, **Se desorientó o se agitó** y **No se pudo** (nota obligatoria solo en el último, opcional y breve en los demás). Si se elige *Se desorientó o se agitó*, se ofrece «¿Avisar a la familia?» (Sí registra las señales marcadas; No, solo el resultado).
7. La guía **no habla, no suena, no vibra, no tiene temporizador, puntaje, felicitaciones, comparaciones ni mensajes de ánimo propios** [P]. (Un mensaje de ánimo escrito por el software es contenido no validado y un sonido o una voz pueden agitar a una persona con Alzheimer; el ánimo viene de `como_motivarlo`, si el profesional lo indicó.) Un temporizador sería una ampliación futura y solo con la dosis capturada, nunca calculada.
8. Si se cierra la app a la mitad, **no se guarda nada** del avance en el dispositivo (ver 6.4); al volver empieza de cero.

### 5.3 Aviso a la familia ante una señal [P]

1. **Qué avisa:** `cui_registrar_sesion` con `senales` no vacío crea un **aviso al dueño**, de severidad **crítica** al inicio (no entra en el tope diario ni espera el silencio nocturno, como el cambio urgente, [V] `20261115000000_cuidados_operaciones.sql:119-130`; `catalogo_avisos.dart:128`). **Qué NO avisa:** *No quiso*, *Se desorientó o se agitó* sin señales marcadas, *Parcial* y *No se pudo*. Una negativa o una sesión que no salió **no activan ninguna alarma** ni quedan «pendientes de explicar».
2. **A quién:** el dueño siempre existe (un solo dueño activo por hogar, D17, [V] `docs/DECISIONES.md:377`), así que **no hay caso sin destinatario** (principio de la spec 5 §8g, [V] `docs/specs/fase-5-cuidados.md:111-114`). Si quien registra **es** el dueño, no se autoavisa. Destinatarios adicionales (hermana de turno, pareja con consentimiento) **solo si el dueño lo pide** (pregunta 4). Por omisión: solo el dueño.
3. **Cómo se ve:** el aviso **no lleva texto clínico ni el diagnóstico**. Se usa el **título único de la función** («**Hay un aviso en Cuidados**», 24 caracteres, sin dígitos ni nombres) y cuerpo vacío; apunta a la sesión (`objeto_tipo` nuevo `sesion_ejercicio`, `objeto_id` = sesión) y la app lee el detalle con las reglas por rol. Nada de «caída», «dolor», «agitación», «Alzheimer» ni «ejercicio» en pantalla bloqueada, en la pulsera ni en el push. Sin voz y sin bocinas (1.2).
4. **Deduplicación:** la clave es `sesion:<id>:<destinatario>` (patrón de `toma:<id>:<destinatario>`, [V] `20261124000000_cuidados_recordatorios.sql:127`).
5. **Atención:** el dueño abre el detalle, ve las señales y la nota y marca **«Enterado»**, que resuelve el aviso (patrón de `cui_atender_cambio_urgente`, [V] `20261115000000_cuidados_operaciones.sql:136-163`). Si nadie lo atiende en un tiempo editable (por omisión 15 minutos [P]), se **repite una vez** y se le muestra a quien ayuda «Sin respuesta aún; llama a la familia» (no más cascadas automáticas en la primera versión).
6. **Conexión con los «cambios urgentes» existentes** ([V] `mi_turno.dart:134-175`; `cui_crear_cambio_urgente`, dueño → quien está de turno): son **el camino de vuelta**. El camino de ida (quien ayuda → dueño) es nuevo (este aviso). Desde el detalle de la señal, el dueño tiene el botón **«Indicar a quien está de turno»**, que abre el cambio urgente ya existente con **su propio texto** (≤ 200 caracteres, escrito por él, p. ej. no continuar hoy o hablar con el profesional); quien está de turno lo recibe como cualquier cambio urgente («Cambio urgente en los cuidados») y lo marca *Enterada*. **La app no redacta ese texto.**
7. Una señal **no suspende** la rutina por sí sola: suspender es una decisión del dueño (5.1).

### 5.4 Recordatorio de la sesión [P]

- Un recordatorio **del servidor** (cron cada 5 min, mismo patrón que `cui_avisar_tomas_proximas`, [V] `20261124000000_cuidados_recordatorios.sql:93-150`) a quien esté de turno **al inicio del hueco** (`cui_quien_en_turno` a esa hora; si `ayuda_de` fija a la cuidadora o al dueño, solo a esa persona **si está de turno**; el dueño es el residual). Tipo nuevo `recordatorio_ejercicio`, **sin cálculo previo de filas** (a diferencia de las tomas, se resuelve en el momento a partir de la programación y de las sesiones ya registradas: no avisa si ya hay una sesión de ese hueco; no avisa si la versión está suspendida). **Un solo recordatorio por hueco**: no se repite ni se «escala», para no presionar.
- **Texto del push:** el **título único** «**Hay un aviso en Cuidados**»; el detalle («Hora de la sesión», la ventana, quién) solo dentro de la app. Severidad *importante*, sin tope diario. El texto del push **nunca** menciona ejercicio, Papá, diagnóstico ni horario.
- **Dignidad y privacidad:** **nunca** a la pareja ni a Casa; **ningún** recordatorio en voz alta ni en bocinas (decisión de esta función, más estricta que la de las tomas, H21); **sin sonidos en la tablet pública** (H20); la cuidadora que entra a la tablet con su PIN no recibe estos recordatorios allí.
- El aviso de cambio de rutina (5.1) usa el cambio urgente existente, no este tipo.

### 5.5 Vigencia y revisión vencidas [P]

- Pasada `vigente_hasta` o `revision_en`, la tarjeta de Mi turno y la pantalla de la rutina agregan **una línea neutra**: «Pasó la fecha de revisión indicada ([fecha]). Confirma con el profesional.» **La guía sigue disponible** (pregunta 7: la app no decide parar una rutina por sí sola).
- El dueño recibe un aviso **informativo** el día de la fecha, con el **mismo título único** «Hay un aviso en Cuidados», y puede publicar una versión nueva (con la fecha nueva) o suspender.

### 5.6 Historial neutro [P]

Pantalla «Historial» (dueño y pareja con consentimiento; quien ayuda ve la semana en curso y la pasada). **No evalúa a nadie:** ni a Papá, ni a la cuidadora, ni a la familia.

- **Lista cronológica** de sesiones: fecha, hora, quién la acompañó, resultado y, si hubo, «Señales: sí» (el detalle, solo al abrir). Sin colores como único portador de significado.
- **Semana (lunes a domingo):** siete casillas, cada una con texto: «Hecha», «Parcial», «No quiso», «Se desorientó o se agitó», «No se pudo», «Sin registro» o «Sin programar». Debajo, **conteos escritos sin razón ni porcentaje**: «Sesiones hechas: 3 · parciales: 1 · no quiso: 1 · se desorientó o se agitó: 0 · no se pudo: 0».
- **Cuatro semanas:** una fila por semana con esos mismos conteos. Sin eje recortado, **sin línea de tendencia, sin porcentajes, sin «X de Y», sin rachas, sin metas, sin colores de «semáforo»**, y «Aún no hay suficientes semanas» si hay menos de dos.
- **Regla de conteo** (función pura, probada): se cuenta **cada día con sesión por su último resultado**; el resultado de cada tipo se cuenta aparte y **ninguno se resta de otro**; «No quiso» y «Se desorientó o se agitó» **no son «incumplimiento»** y nunca se muestran en rojo ni con la palabra «falló», «faltó» o «incumplió»; «Sin registro» solo describe que no hay nada anotado ese día (puede ser que no se hizo, o que no se anotó). Las sesiones extra se cuentan igual. Si la versión cambió a mitad de semana, cada día usa su propia versión.
- **No hay comparación con otras personas, ni «mejora», ni «empeora», ni «promedio».** La app cuenta; no interpreta. Para evaluar el progreso está el profesional en la cita: el historial se le puede mostrar en pantalla.

---

## 6. Privacidad y seguridad

### 6.1 Lo que no sale del sistema [D/P]

- **Nada de esto va a la IA en la nube** (D3, [V] `docs/DECISIONES.md:78-87`; `CLAUDE.md`). **Ninguna herramienta del asistente** toca este módulo: hoy el catálogo solo tiene `cuidados.abrir` ([V] `catalogo.json:100-101`), todas las herramientas de Cuidados son `soloLocal` ([V] `herramienta.dart:25-30`). [P] Se agrega una prueba que falla si aparece una herramienta `cuidados.ejercicio*` o `cuidados.rutina*` en `catalogo.json` o en el registro.
- **Nada a las bocinas ni en voz alta** (D6, [V] `docs/DECISIONES.md:161`): ni recordatorios, ni la guía, ni respuestas. **Nada en la tablet pública sin PIN** (D14, [V] `:324-330`) y, con PIN, **sin sonidos** (H20).
- **El diagnóstico es dato clínico (D3):** nunca a la IA ni a una nube de IA, ni a las bocinas, ni por mensajería, ni en una notificación push con detalle. El push de esta función dice solo «Hay un aviso en Cuidados» (5.3, 5.4).
- **Sin Health Connect y sin envío por mensajería** (persona bajo cuidado, [V] `docs/CONTRATO_CONEXION_APPS.md:139`): la rutina y las sesiones **no se exportan, no se imprimen, no tienen botón Compartir y no se escriben en Health Connect**. «Mostrar al profesional» es solo pantalla. [P] Se prueba que no existe ninguna ruta de exportación en el módulo.
- **No se envía a Hábitos:** la rutina de Papá no es un «hábito», no vive en `hab_*` y no aparece en «Hoy» de Hábitos (H16). Tampoco al gimnasio del dueño.

### 6.2 En el servidor [P]

- RLS por rol (sección 4); tablas nuevas con RLS activado y privilegios por columna, como el resto de `cui_*` ([V] `20261114000000_cuidados_esquema.sql:523-540`, `:~600-680`).
- **Cifrado en reposo:** igual que el resto de Cuidados: **en claro dentro de la base** con reglas por rol y el cifrado del proveedor (esto último no está verificado en el repositorio). No se promete cifrado de extremo a extremo; esa decisión sigue pendiente para **todo** Cuidados (H12, pregunta 4 de la revisión de Fase 5) y esta función la hereda. Si el dueño decide cifrar de extremo a extremo la bitácora, esta función se evalúa en la misma decisión.
- **Auditoría sin texto clínico:** triggers `registrar_cambio_en_bitacora` con **todas las columnas de texto omitidas** (rutina, ejercicios, programación, sesiones). Solo quedan quién, cuándo y el estado o resultado ([V] patrón en `supabase/README.md:814`).
- **Avisos:** títulos del catálogo cerrado; ni nombres, ni señales, ni resultado en el aviso (D20, [V] `catalogo_avisos.dart:1-8`).
- **Copia diaria de la laptop:** incluye estas tablas en claro, cifrada (AES-256), como el resto de Cuidados ([V] `docs/DECISIONES.md:378`, `:481`). No se agrega nada fuera de la copia existente.

### 6.3 «Redacción de lo sensible» (aclaración)

`palabras_es` **no** es parte de esto (H13). Lo que impide que lo clínico aparezca donde no debe son, **en este orden**: el catálogo cerrado de avisos, las columnas omitidas de la auditoría, `soloLocal`, la pantalla segura de `/cuidados` y las reglas por rol. La especificación no introduce ningún mecanismo de redacción nuevo; **agrega pruebas** de que esos mecanismos cubren las tablas y los tipos nuevos (criterios 14 a 17).

### 6.4 En los dispositivos [P]

- **Teléfono de la cuidadora, de la hermana y del dueño:** la app **no guarda en disco** la rutina ni el historial; lee del servidor y los mantiene solo en memoria mientras la pantalla está abierta. **No usa la cola sin conexión** para sesiones (a diferencia del prefijo `cuidados.` pensado para ella, H10): sin señal, la sesión **no se guarda** y la app lo dice con claridad («Sin señal. No se guardó. Reintentar»), conservando lo ya escrito **solo en memoria** hasta que se cierre la pantalla. El id estable de la primera captura hace que reintentar sea seguro (3.4). Motivo: la cola dejaría la sesión, con sus señales, en claro en la base local (H10).
- **Tablet pública de la casa:** **no se guarda nada localmente y no suena nada.** El modo Casa no muestra la tarjeta ni la ruta (`esPantallaSensible`, [V] `pantalla_segura.dart:35-40`; Casa no tiene perfil en Cuidados). La cuidadora que entra con nombre y PIN al contexto «Cuidados» ([V] `app/lib/nucleo/tablet/usuarios_tablet.dart:22-27`) ve la tarjeta con las mismas reglas que en su teléfono; al pasar 2 minutos sin uso o salir, el estado en memoria se descarta y regresa al modo Casa.
- **Pantalla segura** (sin capturas) en todas las rutas nuevas, heredada (H11). **Modo privado** oculta la pantalla como el resto de Cuidados ([V] `docs/DISENO_UX_UI.md:165`).
- **Sin cuenta, sin sesión o sin perfil:** la app muestra «Sin acceso» como las demás pantallas de Cuidados ([V] `comunes.dart` `SinAccesoCuidados`).

### 6.5 Lo que se descarta en la primera versión (con motivo)

| Idea | Motivo |
|---|---|
| Foto de la hoja de indicaciones | Documento clínico en el almacenamiento de archivos; ni OCR ni IA están permitidos; el dueño la transcribe y conserva el papel |
| Voz que lee la guía en voz alta | La voz no se verificó como 100 % local; bocinas no (D6) |
| Temporizador y conteo de repeticiones | Obliga a interpretar la dosis; es una ampliación futura con la dosis capturada |
| Exportar o imprimir la rutina | Los datos clínicos no salen del sistema (misión del módulo, D2/D3) |
| Avisos a la pulsera con texto clínico | Nunca; solo el título genérico (D15, D20) |
| Una vista, pantalla o voz **para que Papá siga la rutina solo** | Le cuesta hacerla solo y tiene Alzheimer; una pantalla o voz propias podrían confundirlo o agitarlo; sería una decisión clínica |
| Mensajes de ánimo, felicitaciones, sonidos o vibración de «logro» | Contenido no validado y riesgo de agitación; el ánimo, si el profesional lo indica, viene de `como_motivarlo` |
| **Rachas, puntos, metas y «días seguidos»** | Con Papá castigan lo que no depende de nadie (una negativa, un mal día) y culpan a quien ayuda |
| Deducir «la mejor hora» de las sesiones | La app no interpreta estados de ánimo ni lucidez; lo anota una persona (3.6) |

---

## 7. Conexión con Alimentación, medicamentos y entrega de turno

### 7.1 Proteína y alimentación [P]

- **Dato mostrado, no calculado.** Si el profesional indicó algo sobre proteína o alimentación («meta de ___ al día», «distribuir en…»), el dueño lo escribe en `alimentacion_indicada` y se muestra en la pantalla de la rutina como «Alimentación indicada por el profesional» con la fecha y el nombre, **más un botón «Ver menú de Papá»** que lleva a la pantalla de solo lectura que ya existe ([V] `menu_papa.dart`).
- **La app no suma proteína del menú, no compara con la meta y no dice «falta proteína».** Alimentación no tiene hoy campos de proteína ni de gramos (H14); crearlos y validarlos clínicamente es una **decisión del dueño con el profesional** y, si se toma, se especifica en Alimentación (agente `alimentacion`), no aquí.
- **Si el profesional da una cifra, el dueño decide si la copia al perfil de Papá** (`ali_menus.perfil`, que él edita, [V] `docs/specs/fase-4-alimentacion.md:91`). Esta función no escribe en Alimentación (un solo escritor por tipo de dato, D1).
- **Suplementos** de Papá: siguen en Alimentación (D28, [V] `docs/DECISIONES.md:547`), con su propia confirmación. No se duplican aquí; si el profesional indica proteína en polvo u otro suplemento, se registra donde el dueño ya registra suplementos.

### 7.2 Medicamentos [P]

- Sin reglas cruzadas: la app no impide ni pospone una sesión por una toma, ni al revés. `restricciones_horario` solo se muestra.
- Pregunta para el profesional (anexo): si hay medicamentos o comidas cerca de los cuales evitar el ejercicio. Si responde, el dueño programa los horarios en consecuencia.

### 7.3 Entrega de turno [P]

- Línea de solo lectura en la tarjeta (3.5). Una señal reportada durante el turno se resalta («Hubo una señal registrada hoy») para quien entra, **sin repetir** qué señal; el detalle está en la sesión (7 días, regla de lectura de la sección 4).
- La nota de entrega la sigue escribiendo la persona. Una sesión *No quiso* o *Se desorientó o se agitó* se muestra con el mismo tono neutro que *Hecha*: «Ejercicio de hoy: no quiso a las 11:00». No se resalta como problema; lo único que se resalta es «Hubo una señal registrada hoy».

---

## 8. Accesibilidad y letra grande para quien ayuda [P, sobre decisiones existentes]

Basado en [V] `docs/DISENO_UX_UI.md:50`, `:63`, `:364`, `:375`:

1. **Letra grande por defecto** para el rol Cuidador; el contenido de la guía soporta escala 2.0 a 360 dp **sin recortes ni desbordes** (tamaño mínimo probado del proyecto).
2. **Botones de 64 dp o más** con texto y, cuando haya, icono; zonas táctiles ≥ 48 dp.
3. **Una instrucción por pantalla**, una sola acción principal, **instrucciones muy cortas** (≤ 120 caracteres, letra ≥ 28 sp), lenguaje simple e impersonal. Nada que dependa solo del color (el resultado siempre lleva texto). La pantalla se lee de un vistazo **mientras la persona está de pie junto a Papá**, sin tener que desplazarse.
4. **Contraste alto** (variante de Cuidados), sin animaciones obligatorias; se respetan «reducir movimiento» y el lector de pantalla (etiquetas semánticas en cada botón, en el orden ejercicio → pasos → acciones).
5. **Se usa con interrupciones y con las manos ocupadas:** «Anterior/Siguiente» a pie de pantalla, «Se negó o se desorientó» y «Algo no va bien» siempre visibles, y **registrar la sesión toma dos toques** (resultado + confirmar) cuando no hay nada que anotar. **«Hoy no» también toma dos toques y no pide justificación** cuando es una negativa.
6. **Sin sonido, voz ni vibración propios** en la guía (5.2): la persona que ayuda puede estar hablándole a Papá y un sonido de la app competiría con su voz.
7. En la **tablet** (contexto Cuidados) la misma guía en vertical u horizontal, con el nombre del ejercicio como título más grande.

---

## 9. Etapas y paquetes de trabajo

Ninguna etapa **publica contenido clínico**: el dueño es quien lo captura. Las etapas pueden construirse **antes** de tener las indicaciones, porque la estructura está vacía por diseño.

| Etapa | Contenido | Agentes | Salida |
|---|---|---|---|
| **E0 · Decisiones** | El dueño responde las preguntas 1 a 9 y va a la cita con el anexo (A y la parte específica de Alzheimer) | dueño, arquitecto | Esta especificación en v1.0 |
| **E1 · Servidor** | Migración nueva (siguiente número libre; hoy la última es `20261151000000`, [V] `ls supabase/migrations`): tablas 3.1 a 3.4 y 3.6, índice único de versión vigente, `cui_ejercicio_puede`, RPC de borrador, publicar, suspender y registrar sesión, triggers de solo agregar, auditoría sin texto, tope diario, tipos de aviso nuevos (`recordatorio_ejercicio`, `senal_ejercicio_cuidados`, `revision_rutina_cuidados`, **los tres con el mismo título «Hay un aviso en Cuidados»**; `objeto_tipo` `sesion_ejercicio`), función del recordatorio y su cron. Pruebas SQL nuevas (siguiente número libre; hoy el último es `121_`) y entrada en `supabase/README.md` | **backend** | Pruebas SQL en verde |
| **E2 · Lógica pura y espejo** | Casos de uso puros en `app/lib/modulos/cuidados/casos_uso/ejercicio_*.dart` (**no** se crea `paquetes/cuidados_dominio` salvo que el arquitecto lo decida, H15): próximo hueco de una persona de turno, validación de lo capturado, conteo de la tendencia, vigencia/revisión vencida. Espejo de permisos y modelos. Pruebas con `flutter test` | **cuidados** | Pruebas puras en verde |
| **E3 · Pantallas** | Estado vacío, captura y revisión (laptop), tarjeta y guía asistida (teléfono y tablet), hojas «Se negó o se desorientó» y «Algo no va bien», notas de la familia, historial neutro. Entradas en el acceso de gestión | **cuidados**, **diseno** (variante de alto contraste, escala 2.0, semántica, **sin sonido ni vibración propios**) | Pruebas de widgets en verde; revisión de diseño |
| **E4 · Avisos** | Títulos nuevos en el catálogo, canal y severidad, recordatorio por turno, aviso de señal al dueño, aviso de revisión, y el uso del cambio urgente existente al publicar o suspender | **plataforma** (catálogo, recepción, `Enterado`), **backend** (ya en E1) | Prueba de catálogo (≤ 40, sin dígitos, título único) y de recepción |
| **E5 · Calidad y dispositivos** | Revisión de privacidad (D3, D6, D14), roles (RLS), accesibilidad, y la lista «solo en dispositivo» (9.2). Cierre | **calidad**; el dueño con la cuidadora | Informe de revisión |

El agente **asistente** no participa: no hay herramientas de GRAVITY para esta función (criterio 14).

### 9.1 Criterios de aceptación

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | Sin rutina publicada, **nadie** ve ejercicios; el dueño ve «Sin indicaciones del profesional» con un solo botón y la cuidadora ve «Todavía no hay una rutina indicada» sin botones | Prueba de widgets por perfil |
| 2 | Una rutina **no se publica** sin `nombre`, `indicada_por`, `fecha_indicacion` ni un ejercicio; sí se publica sin `senales_parar` y la pantalla lo señala | Pruebas SQL (22023) y de widgets |
| 3 | La app **no precarga ejercicios** ni sugiere texto: no existe en el código ni en el servidor ningún catálogo, plantilla o semilla de ejercicios | Revisión de calidad y prueba que inspecciona `seed.sql`, `data/` y los textos de la app por cadenas de ejercicios conocidas del catálogo prohibido |
| 4 | Solo el dueño crea, edita borrador, publica y suspende; cuidadora, hermana, pareja (con y sin consentimiento), maestra ajena, Casa, otro hogar, cuidador sin turnos y `anon` reciben `42501` | Pruebas SQL de la matriz de la sección 4 |
| 5 | La cuidadora lee solo la versión vigente (no borradores ni anteriores) y solo 7 días de sesiones (las notas de la familia, sin ese límite); el dueño y la pareja con consentimiento leen el historial completo; la pareja sin consentimiento, nada | Pruebas SQL |
| 6 | Registrar una sesión: el dueño siempre; la cuidadora y la hermana solo estando de turno **ahora**; fuera de turno `42501` con el mismo mensaje exista o no la sesión | Pruebas SQL con horario fijo (lunes 9:00, 15:00; martes 15:00; domingo) |
| 7 | **Solo agregar:** UPDATE, DELETE y TRUNCATE sobre sesiones fallan; una versión publicada solo cambia de `estado`; la corrección es una fila nueva y vale la más reciente | Pruebas SQL |
| 8 | **Una sola versión vigente por hogar**; publicar deja la anterior `reemplazada` en la misma transacción | Prueba SQL (incluye intento concurrente) |
| 9 | Solo `no_se_pudo` y las sesiones con señales exigen nota (1 a 200); `no_quiso`, `se_desoriento` y `parcial` no la exigen; una señal o un resultado fuera de las listas cerradas falla (22023); las señales `agitacion`, `angustia` y `desorientacion` son válidas | Pruebas SQL y de widgets |
| 10 | Una sesión con señales crea un aviso **crítico** al dueño con el título único del catálogo y sin texto clínico; **`no_quiso`, `se_desoriento` sin señales, `parcial` y `no_se_pudo` no crean ningún aviso**; si quien la registra es el dueño no se autoavisa; reintentar no duplica (clave de deduplicación) | Pruebas SQL y de catálogo |
| 11 | El recordatorio llega **solo a quien está de turno** a esa hora; fuera de turno no llega nada; no llega si ya hay sesión de ese hueco, si la versión está suspendida, ni a pareja, maestra ni Casa; no se repite | Pruebas SQL del cron (patrón de `99_cuidados_recordatorios`) |
| 12 | Publicar o suspender con «Avisar» crea un cambio urgente con el texto fijo y avisa al cuidador de turno (o deja `para_persona` nula si no hay nadie) | Prueba SQL (patrón de `95_cuidados_turnos`) |
| 13 | La baja de una cuidadora corta su acceso a rutina y sesiones al instante y lo que registró queda a su nombre | Prueba SQL (patrón de `95_cuidados_baja`) |
| 14 | **Nada a la IA:** no existe herramienta del asistente `cuidados.ejercicio*` ni `cuidados.rutina*` y el contexto que arma el servidor no incluye estas tablas | Prueba Dart del registro y prueba Deno del contexto |
| 15 | **Auditoría sin texto clínico:** tras crear, publicar y registrar una sesión con señales, `public.bitacora` no contiene nombres de ejercicios, notas, señales ni el nombre del profesional | Prueba SQL (patrón de `95_cuidados_roles`: «lo clínico no se copia a la bitácora») |
| 16 | **Avisos genéricos:** los tres tipos de aviso nuevos usan el título «Hay un aviso en Cuidados» (≤ 40 caracteres, sin dígitos, sin «$», sin nombres ni la palabra Papá, ejercicio o diagnóstico) y cuerpo vacío | Prueba del catálogo (patrón de F5-M6) |
| 17 | **Sin salida del sistema:** no hay botón ni ruta de exportar, imprimir, compartir ni Health Connect para rutina o historial | Prueba de widgets y búsqueda en el módulo |
| 18 | **Pantalla segura:** `/cuidados/ejercicio…` queda protegida para quien ve lo clínico y no para Casa | Prueba de `esPantallaSensible` |
| 19 | **Tablet pública:** la ruta no existe en modo Casa; con la cuidadora dentro por PIN funciona; al salir no queda nada en la base local ni en la cola | Prueba de widgets del controlador de tablet y prueba de cola (ningún tipo `cuidados.` encolado) |
| 20 | **Sin señal:** no se guarda, el mensaje lo dice, y reintentar con el mismo id no duplica | Prueba de widgets con repositorio simulado y prueba SQL de idempotencia |
| 21 | **Historial neutro:** el conteo respeta lunes como inicio de semana, cuenta cada tipo de resultado por separado, **no produce razón «X de Y», porcentaje, racha, meta ni promedio**, no usa palabras de fallo («falló», «faltó», «incumplió»), y con menos de dos semanas dice que no hay suficientes datos | Pruebas puras del caso de uso, incluida una que busca esas palabras y esos formatos en los textos del módulo |
| 22 | **Letra grande:** guía, hojas «Se negó o se desorientó» y «Algo no va bien» y registro se ven sin desbordes a escala 2.0 en 360 dp; cada botón tiene etiqueta semántica; un paso de 120 caracteres cabe sin desplazarse | Pruebas de widgets con escala de texto |
| 23 | **Espejo = servidor:** la matriz de permisos de la app (rutina y sesiones) coincide con la del servidor | Prueba que enumera perfiles × acciones y compara con las expectativas del SQL |
| 24 | La cuenta maestra ajena no lee ni escribe nada de esta función | Prueba SQL (patrón de `95_cuidados_maestra`) |
| 25 | **Siempre asistida:** no existe ruta, pantalla ni perfil pensados para Papá; Papá no tiene cuenta; los textos de la guía se dirigen a quien ayuda | Prueba de rutas y de perfiles; revisión de textos por calidad |
| 26 | **Sin voz ni sonidos:** el módulo de ejercicio no importa el motor de voz ni reproduce audio, y no hay recordatorio de esta función en bocinas ni en la tablet pública | Búsqueda de imports en el módulo (prueba Dart); prueba de recordatorios (ningún destinatario Casa ni tablet pública) |
| 27 | **Una instrucción a la vez:** la guía muestra un solo paso por pantalla; los campos `como_indicarle`, `como_motivarlo` y `si_se_niega` empiezan vacíos y, vacíos, se muestran como «El profesional no indicó…» | Pruebas de widgets |
| 28 | **«Hoy no» y «No quiso»** se registran en dos toques sin nota, no generan aviso, y la tarjeta y la entrega de turno los muestran con el mismo tono que «Hecha» | Pruebas de widgets y SQL |
| 29 | **Sin rachas:** mover una sesión de hora o de día, o varias sesiones el mismo día (fraccionar), no cambia ningún conteo ni mensaje de forma punitiva; no existe ningún contador de «días seguidos» | Pruebas puras y búsqueda en el módulo |
| 30 | **Notas de la familia:** `mejor_momento` se muestra tal como se escribió, vale la más reciente, **no** se calcula a partir de las sesiones y no crea una versión nueva de la rutina | Pruebas SQL y de widgets |
| 31 | **Diagnóstico:** ningún campo, aviso ni auditoría de esta función contiene el diagnóstico de Papá; ninguna de sus tablas entra al contexto de la IA | Prueba SQL (auditoría y avisos) y prueba Deno del contexto |

### 9.2 Solo en dispositivo (no automatizable)

- La **guía a la luz de una recámara**, con letra del tamaño que el dueño elija, y con la cuidadora real (¿entiende el orden?, ¿alcanza el botón con una mano?).
- **Llegada del aviso crítico** al teléfono del dueño con la pantalla bloqueada: que solo diga el título genérico (FCM real; en la Fase 5 también quedó como verificación manual, [V] `docs/ROADMAP.md:282`).
- **Recordatorio a la hora** en el teléfono de la cuidadora (y que **no** llegue ni suene en la tablet de la casa).
- **La guía junto a Papá**, con la cuidadora real: ¿le sirve que haya una sola instrucción a la vez?, ¿el «Se negó o se desorientó» se alcanza a tocar sin soltarlo?, ¿la pantalla compite o ayuda con su voz?, ¿alguna palabra de la pantalla altera a Papá si la ve? (puede variar mucho por persona y día; no es automatizable).
- **Pantalla segura** (FLAG_SECURE) en el teléfono y la tablet reales.
- **Lectura de vuelta con el profesional:** que lo capturado coincide con lo indicado (es el control principal contra errores de transcripción, R1).
- Tiempo real para registrar una sesión (meta: menos de 10 segundos si no hay nota).

---

## 10. Riesgos

| # | Riesgo | Mitigación [P] |
|---|---|---|
| R1 | **Error de captura:** la familia transcribe mal lo que dijo el profesional | Pantalla de revisión que repite todo; «Mostrar al profesional»; nombre y fecha de la indicación siempre visibles; versiones inmutables y trazables; el anexo ayuda a pedir la indicación por escrito |
| R2 | **Rutina vieja:** se sigue usando después de su vigencia o revisión | Nota neutra visible, aviso al dueño, versión nueva fácil; **la app no decide** parar (pregunta 7) |
| R3 | **La app se entiende como prescripción** | Aviso permanente «Indicación de…», sin catálogo ni sugerencias, sin lenguaje de evaluación (sin «bien hecho», sin «mejora») |
| R4 | **Falta o exceso de avisos** (cansancio por alertas, o una señal sin atender) | Aviso crítico solo por señales, nunca por «no se pudo»; repetición única; la cuidadora ve «Sin respuesta aún» (**no hay avisos por incumplimiento**: decisión de esta función; la pregunta 8 solo revisa horas y sonido) |
| R5 | **Sin señal en casa:** la sesión no se guarda | Mensaje claro y reintento con id estable; sin cola por privacidad (H10). Si resulta frecuente, se decide una cola cifrada en una versión posterior |
| R6 | **Texto clínico en pantalla bloqueada o pulsera** | Catálogo cerrado y prueba de títulos; apertura del detalle solo dentro de la app |
| R7 | **Cuidadora con poca experiencia** y manos ocupadas | Una instrucción por pantalla, letra grande, dos toques para registrar, prueba con ella (9.2) |
| R8 | **Regresión de la matriz de Fase 5** al tocar `cui_puede` | Función de permisos aparte; las pruebas `95_` a `99_` deben seguir en verde |
| R9 | **Pantalla compartida** o captura de pantalla | Pantalla segura heredada; modo privado; nada en el modo Casa |
| R10 | **El profesional no indica ejercicios en cama** (otro tipo de terapia, o las sesiones las da él en casa) | El módulo queda vacío y honesto; las visitas del fisioterapeuta se registran como citas; no se construye nada «a medias» con contenido |
| R11 | **Choque de dueño del dato** con la rutina de Hábitos (H16) | Decisión explícita: es de Cuidados; nunca se usa un perfil `adulto` de Hábitos para Papá |
| R12 | **Datos clínicos en claro en el servidor** y en la copia (H12) | Mismo nivel que el resto de Cuidados; pregunta pendiente de la revisión de Fase 5 (cifrado extremo a extremo) que se resolvería para todo Cuidados |
| R13 | **El dueño carga solo con la captura** (tiempo, cansancio) | Campos opcionales; captura en seis pasos cortos; borrador en el servidor para continuar |
| R14 | Papá no quiere o no puede hacer la rutina ese día (Alzheimer, estado de ánimo) | «No quiso» y «Se desorientó o se agitó» son resultados normales, sin nota obligatoria ni aviso; el historial no culpa (5.6); no hay rachas |
| R15 | **La guía agita o confunde a Papá** (sonido, voz, pantalla frente a él, mensajes) | Sin voz, sonido, vibración ni mensajes propios; la pantalla es para quien ayuda; «Reintentar más tarde hoy» y «Hoy no» siempre disponibles; prueba con la cuidadora real (9.2) |
| R16 | **Instrucciones inventadas o mal dichas** para una persona con demencia (cómo indicarle, qué hacer si se niega) | Esos campos los escribe la familia **solo desde lo que dijo el profesional**, vacíos al inicio y sin ejemplos; la guía dice «El profesional no indicó…» si faltan; el anexo A pide el detalle; el médico tratante puede dar visto bueno (pregunta 2) |
| R17 | **Supervisión insuficiente** o riesgo de caídas en una sesión asistida | La app solo muestra la supervisión y el apoyo capturados y el texto fijo de emergencia; no decide quién puede dejarlo solo; se pregunta al profesional (anexo A) |
| R18 | **Papá no reconoce a quien lo ayuda** y se angustia | Es información que anota la familia (pregunta 1); `ayuda_de` permite fijar a la persona con quien coopera mejor, y si no está de turno no se avisa a otra (la sesión queda para cuando sí lo esté) |

---

## 11. Preguntas abiertas para el dueño (con mi recomendación)

1. **¿Quién ayuda en la práctica, en qué horarios, y Papá reconoce a esa persona?** ¿La cuidadora, tú, la hermana o varios? ¿Hay alguien con quien coopere mejor? ¿Cuándo está más tranquilo o con más claridad?
   *Recomendación:* por omisión «quien esté de turno» (`ayuda_de = turno`); tú siempre puedes registrar y cubres los huecos sin cuidadora; la hermana, en su turno. **Fija una persona (`ayuda_de`) solo si el profesional o la familia ven que con ella coopera mejor**, sabiendo que si no está de turno a esa hora no se avisa a otra. Lo que observen de «cuándo está mejor» se anota en las **notas de la familia** (3.6); la app no lo deduce. Horario y duración de cada sesión: lo que diga el fisioterapeuta hoy, en sesiones **breves y fraccionables**.

2. **¿Tiene el fisioterapeuta indicaciones específicas para personas con Alzheimer, y el médico tratante (neurólogo o geriatra) debe aprobar la rutina?**
   *Recomendación:* **pídelas hoy** (anexo A, parte 10: cómo darle instrucciones, qué hacer si se niega o se desorienta, supervisión, riesgo de caídas). Pide además el **visto bueno del médico tratante antes de publicar** una rutina; la app tiene campos para anotarlo y mostrarlo (`aprobada_por`, `aprobada_en`). **Por omisión la app no lo exige** (el dueño no debería quedar bloqueado en una cita pendiente); si prefieres exigirlo, se activa «exigir visto bueno del médico tratante» y no se publica sin él.

3. **¿Quien ayuda puede ajustar la rutina o solo registrar?**
   *Recomendación:* **solo registrar.** Ajustar es una indicación clínica; si algo no funciona, lo anota en la sesión, en las notas de la familia o en la bitácora, y tú decides si hay que hablar con el profesional y capturar una versión nueva.

4. **¿Qué señales deben avisar y a quién?** Partimos de mareo, dolor, falta de aire, cansancio extremo y caída, más las de la demencia (agitación, angustia, desorientación) y «otra». ¿Aprueban el texto fijo «Si es una emergencia, llama al 911»? ¿Se avisa además a la hermana de turno o a la pareja? ¿Una señal de agitación o desorientación debe avisar igual que una caída?
   *Recomendación:* toda señal avisa **solo a ti**, como aviso crítico y con el título único «Hay un aviso en Cuidados» (sin detalle en el push); el fisioterapeuta y el médico confirman o amplían la lista; apruebas el texto del 911; la hermana o la pareja se suman solo si tú lo pides. Si resulta demasiado, se baja la severidad de las tres señales de demencia a *importante* (no se decide aquí qué es grave). **«No quiso» y «se desorientó» sin señales marcadas no avisan.**

5. **¿Qué llevamos a la primera cita y quién captura?** ¿Va la cuidadora o la hermana? ¿Capturas tú en la laptop en la noche?
   *Recomendación:* ve con el anexo de este documento (pide **la indicación por escrito** y su fecha), lleva la lista de medicamentos y la descripción de un día típico (quién ayuda, la cama, la silla, cuándo está mejor Papá), y captura al llegar a casa: **mejor que la app no se use durante la cita**. **Si es posible, que la persona que más lo ayuda vaya a la cita o a la primera sesión**, para que el fisioterapeuta le enseñe cómo hacerlo. Si el profesional todavía no define rutina, no se captura nada: el estado vacío es correcto.

6. **¿La pareja ve la rutina y las sesiones?**
   *Recomendación:* sí, **solo lectura y solo con su consentimiento**, igual que medicamentos, comidas y bitácora. Sin consentimiento, nada.

7. **¿Qué hace la app cuando pasa la vigencia o la fecha de revisión?**
   *Recomendación:* **no decide parar.** Muestra una nota neutra, te avisa y deja la guía disponible hasta que tú publiques una versión nueva o suspendas (suspender sí quita la tarjeta). Si prefieres lo contrario (ocultar la guía al vencer), es un cambio pequeño pero lo debe decidir el dueño con el profesional.

8. **Recordatorios: ¿a qué horas y con qué sonido en el teléfono de quien ayuda?** (Ya está decidido que **no hay voz, bocinas ni sonidos en la tablet de la casa**, 5.4.)
   *Recomendación:* un solo recordatorio por hueco, con el título único «Hay un aviso en Cuidados» y el sonido normal del canal de Cuidados, solo al teléfono de quien está de turno; **sin avisos por incumplimiento** (solo el historial neutro), para no presionar a quien ayuda.

9. **Sin señal en casa, ¿aceptas que la sesión no se guarde y se reintente?**
   *Recomendación:* sí, en la primera versión, por privacidad (no dejar señales en claro en el teléfono). Si el Wi-Fi de casa falla seguido, se evalúa una cola cifrada en una versión posterior.

**Decisiones que propongo al arquitecto** (no las toma esta especificación): (a) confirmar la parte de Cuidados de D3 y la de D6 (H17); (b) dejar escrito que la rutina física de la persona bajo cuidado es de **Cuidados**, no de Hábitos (H16); (c) contestar la pregunta de cifrado de extremo a extremo de Cuidados (H12); (d) decidir si se crea `paquetes/cuidados_dominio` (H15); (e) fijar como regla de Cuidados que **ningún recordatorio ni guía de rutina física se dice en voz alta ni va a las bocinas** (H21), más estricta que la de las tomas.

---

## Anexo A · Qué preguntar al fisioterapeuta

Lista corta y práctica para la cita. Pide, si se puede, **la indicación por escrito con fecha y firma o nombre**. Cada punto dice en qué campo de la app se captura. **Recuerda decirle al profesional desde el principio que Papá tiene Alzheimer y que le cuesta hacer la rutina solo**: toda la rutina será **asistida** por otra persona. La parte 10 es específica de eso.

**1. El diagnóstico y el objetivo**
- ¿Qué busca esta rutina? (en palabras sencillas; para la nota del profesional) → `notas_profesional`.
- ¿Hay algo que Papá **no debe hacer**?

**2. Los ejercicios** (uno por uno; pídele que te los muestre y, si puede, que los escriba)
- ¿Cómo se llama cada ejercicio y cómo se hace, **paso por paso**? → `nombre`, `como_hacerlo`.
- ¿En qué postura: acostado, de lado, sentado en la cama, sentado en silla? → `postura`.
- ¿Cuántas **series y repeticiones**, o cuánto **tiempo**? ¿Cuánto **descanso** entre uno y otro? Pide que lo diga con números. → `dosis_texto`, `descanso_texto`.
- ¿Todos los días son iguales o hay «día A» y «día B»? → `grupo`.

**3. Cuándo y cuánto tiempo**
- ¿Cuántos días a la semana? ¿Qué días? ¿Mejor por la mañana o por la tarde? → programación.
- ¿Cuánto dura una sesión completa? ¿**Se puede dividir en varios momentos** del día (por ejemplo, en sesiones más breves)? ¿Cómo? → `duracion_texto`, `fraccionamiento_texto`.
- ¿Hay una **hora mejor** del día? ¿Conviene fijarla o ir viendo cuándo está más tranquilo? (la familia lo anota, la app no lo deduce.)
- ¿Por cuánto tiempo se sigue esta rutina antes de revisarla? → `vigente_hasta`.

**4. Quién ayuda y con qué**
- Como Papá no puede hacerlo solo: ¿cuántas personas hacen falta y **dónde se coloca la persona** que ayuda? ¿La ayuda debe ser de alguien con alguna preparación o puede ser la cuidadora? → `apoyo`.
- ¿Hace falta **material** (bandas, pelota, almohada, algo para apoyar los pies)? ¿Cuál exactamente, y de qué resistencia o tamaño si es el caso? → `material`.
- ¿Cómo debe estar la cama (altura, barandales, colchón) o la silla?

**5. Cuándo parar y qué hacer**
- ¿**Qué señales** significan parar? (¿mareo, dolor, falta de aire, cansancio extremo, caída, **agitación, angustia, desorientación**, otra?) → `senales_parar`, y la lista cerrada de señales.
- Si se **cansa** o tiene **dolor**: ¿qué se debe hacer exactamente? ¿Cuánto es «normal» y cuánto no? → `si_ocurre`.
- ¿**A quién avisar** y **cuándo llamar a emergencias**? ¿Cuál es el teléfono del profesional para dudas?
- Si Papá **no quiere** hacerlo ese día: ¿se intenta de nuevo, se salta, qué se hace? → `si_se_niega` (más detalle en la parte 10).

**6. Progresión y revisión**
- ¿Cómo y **cuándo sube la dificultad**? ¿Quién lo decide? (la respuesta se captura como **versión nueva**, nunca la cambia la app por sí sola).
- ¿Cuándo hay que **volver** a revisión? → `revision_en`.
- ¿Qué cambios se deben **avisarle** antes de la siguiente cita (por ejemplo, caídas, dolor nuevo, cambio de medicamentos)?

**7. Alimentación y proteína**
- ¿Se necesita **más proteína**? ¿Cuánta al día o por comida, y en qué momento (antes o después del ejercicio)? ¿Hay algún **suplemento** que recomiende? Pídele la cifra por escrito. → `alimentacion_indicada` (la cifra la copia el dueño a donde decida).
- ¿Hay **alimentos que evitar** o textura que cuidar?

**8. Medicamentos y horarios**
- ¿Hay medicamentos o comidas **cerca de los cuales** conviene evitar el ejercicio? → `restricciones_horario`.
- ¿El ejercicio cambia algo de los medicamentos actuales? (La pregunta es para el médico si el fisioterapeuta no lo sabe.)

**9. Seguimiento**
- ¿Qué conviene **anotar** en cada sesión para llevarlo a la siguiente cita? (la app solo guarda hecha / parcial / no quiso / se desorientó o se agitó / no se pudo, nota breve y señales; si hace falta otra cosa, anótala a mano).
- ¿Cuándo es la **próxima cita**? (se captura como cita de Cuidados.)

**10. Específico de Alzheimer** (la rutina será siempre asistida)
- **Cómo darle las instrucciones:** ¿con qué palabras, qué tono, qué gestos? ¿Una instrucción a la vez? ¿Es mejor **mostrarle** el movimiento, hacerlo juntos, o decirlo? ¿Conviene usar siempre las mismas palabras y el mismo orden? → `como_indicarle`.
- **Ejercicios más simples y repetitivos:** ¿cuáles son los más fáciles de seguir para él? ¿Es mejor pocos ejercicios que se repitan siempre en el mismo orden? ¿Qué **no** conviene pedirle por la confusión?
- **Cómo animarlo:** ¿qué ayuda y qué no (insistir, premiar, acompañar con algo conocido)? → `como_motivarlo`.
- **Si se niega:** ¿se insiste, se espera, se cambia de ejercicio, se deja para después? ¿Cuántas veces se intenta? → `si_se_niega`.
- **Si se desorienta, se angustia o se agita:** ¿qué hacer exactamente y cuándo parar por completo? ¿A quién avisar y cuándo llamar a emergencias? → `si_se_niega`, `senales_parar`.
- **Supervisión:** ¿puede quedarse solo un momento? ¿Debe haber siempre una persona al lado? → `supervision_texto`.
- **Riesgo de caídas:** ¿qué cuidar en la cama o la silla (altura, barandales, ropa, calzado)? ¿Cómo se prepara el espacio?
- **Duración de la atención:** ¿cuánto tiempo aguanta atento? ¿Mejor varias sesiones muy cortas? ¿Cuál es la duración máxima por sesión?
- **Momento del día:** ¿conviene la hora en que está mejor? ¿Es importante hacerlo siempre a la misma hora, o se puede mover si ese día está mal?
- **Si no reconoce a quien lo ayuda:** ¿qué se recomienda? ¿Conviene que lo haga siempre la misma persona?
- **Cómo enseñarle a la cuidadora (y a quien más lo ayude):** pídele que se lo **muestre en persona**; ¿puede la cuidadora **practicar con el terapeuta** en la cita o en una visita corta, **antes** de hacerlo sola con Papá? ¿Hay una forma de comprobar que lo está haciendo bien (por ejemplo, que la vea una vez)?
- **Médico tratante:** ¿recomienda consultarlo (neurólogo o geriatra) antes de empezar? ¿Qué le tendríamos que preguntar? → `aprobada_por`, `aprobada_en`.

### Qué llevar a la cita

- **Lista de medicamentos actuales** (la pantalla de Medicamentos de Cuidados la muestra) y la fecha del último cambio.
- **Estudios o notas médicas** que ya existan (para enseñárselos; no se guardan en la app).
- **Cómo es un día típico** de Papá: a qué hora se levanta, cuándo come, cuándo suele estar con más energía o más tranquilo, si hay horas con más confusión o agitación, y cómo reacciona cuando se le pide algo nuevo.
- **A la persona que más lo ayuda**, si puede ir (o que el dueño le cuente después lo que se dijo): quien hará la rutina debería escuchar las instrucciones y verlas en persona.
- **Quién ayuda y en qué horarios:** los turnos de la semana (los de la spec 5, sección 3).
- **Cómo es el espacio:** cama (alta o baja, con o sin barandal), silla disponible, espacio para trabajar de pie alrededor de la cama, material que ya haya en casa.
- **Caídas o sustos recientes** y dolores que Papá ha mencionado.
- Una **libreta o una nota** para escribir lo que se diga; **no hace falta capturar nada en la app durante la cita**.

### Hoja para tomar notas durante la cita

| Campo (se captura después en la app) | Lo que dijo el profesional |
|---|---|
| Quién la indicó y fecha | |
| Ejercicio 1: nombre, postura, pasos | |
| Ejercicio 1: series, repeticiones o tiempo, descanso | |
| Ejercicio 1: apoyo y material | |
| Ejercicio 2, 3… (mismo formato) | |
| Días y horas | |
| Vigencia y fecha de revisión | |
| Señales para parar (incluidas agitación, angustia, desorientación) | |
| Qué hacer si se cansa o hay dolor | |
| Alimentación y proteína indicada | |
| Restricciones de horario | |
| Duración de la sesión y si se puede dividir | |
| Hora mejor del día | |
| Cómo indicarle (palabras, tono, gestos) | |
| Cómo animarlo | |
| Qué hacer si se niega | |
| Qué hacer si se desorienta, se angustia o se agita | |
| Supervisión y riesgo de caídas | |
| Visto bueno del médico tratante (nombre y fecha) | |
| Cuándo volver y a quién avisar | |

---

## Anexo B · Texto de la pantalla vacía y de los avisos (para revisión)

Todos son propuesta; el catálogo de avisos los valida (≤ 40 caracteres, sin dígitos, sin nombres).

| Dónde | Texto |
|---|---|
| Pantalla vacía (dueño) | «Sin indicaciones del profesional» · «Aquí aparecerá la rutina cuando la familia la capture a partir de lo que indique el fisioterapeuta o el médico. GRAVITY no sugiere ejercicios.» · Botón «Capturar indicaciones» |
| Pantalla vacía (cuidadora) | «Todavía no hay una rutina indicada. No hay nada que hacer aquí.» |
| Aviso: hora de la sesión, señal reportada y revisión pendiente (los tres) | **«Hay un aviso en Cuidados»** (título único; el detalle solo se ve dentro de la app) |
| Cambio urgente al publicar o suspender | «La rutina de ejercicio cambió. Revísala en Mi turno.» |
| Pie de la guía | «Indicación de [nombre], [fecha]. GRAVITY no la sugiere ni la modifica.» |
| Campo vacío en la guía | «El profesional no indicó [señales para parar / qué hacer / apoyo / cómo dirigirse a Papá / qué hacer si se niega]» |
| Botones de la guía | «Siguiente» · «Anterior» · «Se negó o se desorientó» · «Algo no va bien» · «Hoy no» · «Reintentar más tarde hoy» · «Terminar aquí» · «Terminar aquí y avisar» |
| Resultados de la sesión | «Hecha» · «Parcial» · «No quiso» · «Se desorientó o se agitó» · «No se pudo» |
| Tarjeta de Mi turno | «Anotado por la familia: …» |
| Sin señal | «Sin señal. No se guardó. Reintentar» |
| Texto fijo de seguridad (pendiente de aprobación) | «Si es una emergencia, llama al 911.» |

---

## Control de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 0.1 | 23/nov/2026 | Primera versión: alcance sin contenido clínico inventado, modelo de datos, permisos por rol, flujos, privacidad, etapas, 24 criterios, 14 riesgos, 8 preguntas y anexo para la cita con el fisioterapeuta |
| 0.2 | 23/nov/2026 | Dato del dueño: Papá tiene Alzheimer y le cuesta hacer la rutina solo. La rutina es **siempre asistida** y la pantalla es para quien ayuda; guía de una instrucción a la vez con campos «cómo indicarle», «cómo motivarlo» y «qué hacer si se niega o se desorienta» (vacíos, sin ejemplos); cinco resultados de sesión (hecha, parcial, no quiso, se desorientó o se agitó, no se pudo) sin culpa; señales de la demencia; sesiones breves, fraccionables y con ventana; nota de la familia «cuándo suele estar mejor»; sin rachas, sin voz, sin sonidos ni bocinas; título único de aviso «Hay un aviso en Cuidados»; visto bueno opcional del médico tratante; criterios 25 a 31, riesgos R15 a R18, preguntas reorganizadas (9) y parte 10 del anexo A |
