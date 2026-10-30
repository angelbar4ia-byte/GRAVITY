# Decisiones de arquitectura (SEGUNDO CEREBRO)

Registro de las decisiones que cambian cómo se conectan las piezas del sistema. Cada una dice **qué** se decidió, **por qué** y **qué cambia**.

Estados: **confirmada** (aprobada por el dueño del proyecto), **propuesta** (falta su visto bueno), **pendiente** (falta decidir).

Cuando las decisiones confirmadas cambian el contrato, se reescribe `CONTRATO_CONEXION_APPS.md` (siguiente versión: 3.0). Mientras tanto, **este archivo manda sobre el contrato v2.0** donde se contradigan.

**Fuente única:** `GRAVITY/docs/DECISIONES.md` (D10).

| # | Decisión | Estado |
|---|---|---|
| D1 | Una sola app modular | Confirmada |
| D2 | Cuidados entra como módulo | Confirmada |
| D3 | GRAVITY sí usa dinero, por rol y sin IA en la nube | Confirmada (cuidados: propuesta) |
| D4 | Laptop Windows con el sistema completo; teléfono con lo mínimo | Confirmada |
| D5 | Roles y personas | Confirmada (actualizada 21/oct; detalles pendientes) |
| D6 | Bocinas Xiaomi como medio de voz de GRAVITY | Propuesta |
| D7 | Servidor: Supabase (plan gratis); Firebase solo para avisos y reparto de la app | Confirmada |
| D8 | Reglas para controlar la laptop | Propuesta |
| D9 | Puente de casa (Home Assistant), empezando en la laptop | Confirmada (equipo dedicado: pendiente) |
| D10 | Todo el código y los documentos en el repositorio GRAVITY | Confirmada y aplicada |
| D11 | Prioridad Finanzas → Hábitos; funcional primero, pulido después | Confirmada |
| D12 | Laptop con pantalla principal de GRAVITY tipo JARVIS; teléfono como app normal | Confirmada |
| D13 | Datos sensibles de Hábitos: cifrados en la nube o solo en el teléfono, a elegir | Confirmada |
| D14 | Tablets: personal (dueño y pareja) y pública de la casa | Confirmada (actualizada 21/oct; identidad al registrar: propuesta) |
| D15 | Pulsera smart band (reloj Wear OS a futuro) | Confirmada (detalles propuestos) |
| D16 | APIs documentadas con OpenAPI y Swagger UI | Confirmada (detalles propuestos) |
| D17 | Reglas técnicas del servidor (Fase 0) | Propuesta |
| D18 | Decisiones de la revisión de la Fase 0 | Confirmada (21/oct; coadministrador y Cuidados hasta la Fase 5) |
| D19 | Finanzas por persona, cuentas compartidas, albaceas y cuenta maestra | Confirmada (21/oct; ampliada 23/oct; detalles propuestos) |

---

## D1. Una sola app modular — confirmada (20/oct/2026)

**Decisión.** SEGUNDO CEREBRO es **una sola app** con módulos:

| Módulo | Origen del diseño |
|---|---|
| Presupuesto y Alimentación | `FINANZAS/` (diseño v23) |
| Hábitos y Objetivos | `HABITOS/` (diseño v1.18) |
| Cuidados | App de cuidados existente (fase 3, rediseñable) — ver D2 |
| **GRAVITY** | `GRAVITY/` — capa central que une a los módulos (por diseñar) |

**Por qué.** Un asistente útil necesita ver el contexto, actuar y tener una sola memoria. Con apps separadas en Android, cada lectura o acción de GRAVITY sobre otra app requiere un puente nativo (Kotlin) en esa app; con el contrato v2.0, GRAVITY solo podía abrir pantallas por enlace.

**Reglas.**
- Cada módulo es dueño de sus datos: **un solo escritor por tipo de dato** (se mantiene la sección 1 del contrato v2.0).
- **GRAVITY no lee bases de datos.** Usa solo una lista cerrada de funciones ("herramientas") que cada módulo publica, p. ej. `habitos.resumen_hoy`, `presupuesto.agregar_a_lista`. Lo que no está en la lista no existe para GRAVITY. Toda escritura pide confirmación.
- Los módulos se activan por partes; la app funciona con cualquier combinación de módulos activos.
- **Familiares y cuidadores:** todos instalan la misma app y cada quien ve solo los módulos de su rol (D5); los permisos los aplica el servidor. Si hiciera falta, del mismo código se puede generar una versión aparte (p. ej. solo Hábitos).

**Qué cambia del contrato v2.0.**
- Las vías A (archivos JSON) y B (enlaces) **ya no se usan entre módulos del mismo usuario**: los datos se comparten dentro de la app. Se conservan para compartir con otras personas mientras no se decida otra cosa.
- La sección 9 (GRAVITY solo por enlaces) se reescribe con las herramientas de arriba.
- Los diseños de FINANZAS y HÁBITOS se conservan como especificación de su módulo.

---

## D2. Cuidados entra como módulo — confirmada (20/oct/2026)

**Decisión.** La app de cuidados deja de ser externa y se integra como módulo.

**Se mantiene del contrato v2.0.**
- Los datos clínicos de la persona bajo cuidado (diagnóstico, medicamentos, citas, comportamiento) **nunca van a la IA en la nube** y no se mezclan con Hábitos.
- Gastos de cuidado y necesidades de alimentación entran a Presupuesto **con confirmación** (sección 6).
- Acceso por rol y con consentimiento de quien representa a la persona; todo cambio queda en bitácora.

**Sincronización — propuesta.** Hay varios cuidadores en distintos teléfonos (D5), así que los datos de Cuidados **se sincronizan en la nube** (mismo servidor, D7), con reglas por rol. Siguen sin ir nunca a la IA en la nube.

---

## D3. GRAVITY y el dinero — confirmada (20/oct/2026)

**Decisión.** GRAVITY **sí** puede usar datos de dinero, **con restricción por rol** (D5) y **sin enviarlos nunca al modelo de IA en la nube**.

- El modelo en la nube solo entiende la pregunta y elige la herramienta. La herramienta de Presupuesto entrega su respuesta **directo a la pantalla o a la voz**, sin pasar por el modelo: el modelo nunca ve cifras, cuentas, precios ni comercios.
- Análisis con IA de los datos de dinero (p. ej. *"¿en qué puedo ahorrar?"*): solo con un modelo de IA **local en la laptop** (opción futura), nunca en la nube.
- **Nunca por bocinas** (D6).

**Cuidados — propuesta.** Misma regla que el dinero (solo dentro del dispositivo, solo roles autorizados). En bocinas, solo recordatorios **genéricos**, sin nombre del medicamento ni de la persona (p. ej. *"Hora del medicamento de las 8:00"*).

---

## D4. Laptop completa, teléfono mínimo — confirmada (20/oct/2026)

**Decisión.** La **laptop (Windows)** tiene el **sistema completo**: toda la planeación, la configuración y GRAVITY completo, que además **controla la computadora** (D8). El **teléfono** tiene **lo mínimo** para registrar y consultar el día. Mismo código Flutter: Windows recibe la versión completa y Android la reducida.

**Los datos viven en la nube (D7), no en la laptop.** La cuidadora y la familia los necesitan con la laptop apagada o fuera de casa, y la laptop se puede perder o descomponer. La laptop guarda **cada día una copia completa** de todo.

| Quién | En el teléfono (lo mínimo) | En la laptop |
|---|---|---|
| **Dueño** | Registrar gasto, marcar comidas y hábitos, plan del día, lista de compras, peso, sueño y ejercicio (Health Connect), recordatorios, GRAVITY por voz | **Todo lo demás:** presupuesto, estados de cuenta, menús y recetas, objetivos, reportes, configuración de Cuidados (medicamentos, citas, turnos), roles, GRAVITY completo, bocinas, copias de seguridad |
| **Pareja** | Lo suyo, más un resumen del presupuesto (solo lectura) | Solo si tiene su propia computadora |
| **Cuidadora y hermana** | **Todo su trabajo:** horario de medicamentos y marcar los que ya dieron, comidas de papá, bitácora, entrega de turno, gastos de cuidado | No la usan |
| **Familiares** | Sus hábitos y su plan del día | No la usan |

**Cambios urgentes desde el teléfono (Dueño).** Lo demás espera a la laptop.
- Suspender o agregar un medicamento, con nota para la cuidadora de turno (le llega un aviso al instante).
- Agregar algo a la lista de compras.
- Mover un recordatorio.

**Qué cambia en los diseños.** FINANZAS (v23) y HÁBITOS (v1.18) se pensaron como apps completas de teléfono: al actualizar sus .md se separa qué va en el teléfono y qué en la laptop.

---

## D5. Roles y personas — confirmada (20/oct/2026)

| Persona | Rol | Módulos | Dinero en GRAVITY | Cuidados |
|---|---|---|---|---|
| Usuario | **Dueño** | Todos | Sus finanzas, las compartidas y las de papá como albacea (D19) | Completo |
| Pareja | **Co-administrador** | Alimentación, su Hábitos, sus finanzas y las cuentas compartidas | Sus finanzas y las compartidas (D19) | Según consentimiento (Fase 5) |
| Otros familiares | **Familiar** | Su Hábitos y su parte de Alimentación | No | No |
| Papá (Alzheimer) | **Persona bajo cuidado** | No usa la app; sus datos viven en Cuidados | — | Titular de los datos |
| Cuidadora principal (por turnos; puede haber más) | **Cuidador** | Cuidados; GRAVITY solo para sus solicitudes y recordatorios; dispositivos de la casa | Solo los gastos de cuidado que registra | Su parte |
| Hermana (martes, después del turno de la cuidadora) | **Cuidador** (familiar) | Cuidados | Los gastos de cuidado que registra | Su parte |
| Esposo e hijos de la hermana | Sin cuenta | — | — | — |
| Cualquiera en casa (bocinas, D6) | **Casa** | Recetas, lista de compras, recordatorios generales | No | Solo recordatorios genéricos |

**Reglas.**
- Cada persona tiene **su propia cuenta**. Los roles se validan **en el servidor** (reglas de la base de datos), no solo en la pantalla.
- **Cuidadores:** los invita el Dueño y se pueden agregar más. Al darlos de baja pierden el acceso de inmediato; lo que registraron queda en la bitácora con su nombre.
- **Turnos:** Cuidados lleva el calendario de turnos. Los recordatorios de cuidados (medicamentos, comidas) llegan al teléfono de **quien está de turno**, y al cambiar de turno hay una **entrega de turno** (notas para quien sigue).
- **Comidas de papá:** el cuidador de turno ve el plan de comidas de papá (solo el de él, sin costos) y registra si comió, comió poco o rechazó; eso regresa a Alimentación (contrato v2.0, sección 6).
- La cuidadora **no ve nada de la familia** fuera de Cuidados (dinero, hábitos, menús de otros).
- Papá no tiene cuenta; los consentimientos sobre sus datos los da quien lo representa.
- La voz **no identifica de forma segura** a una persona: las bocinas siempre tienen el rol **Casa**.
- **Cada quien ve lo suyo** (21/oct/2026): el historial de GRAVITY y las finanzas personales son de cada persona, también para el dueño. Solo la **cuenta maestra** (D19) ve todo.
- **Cuidadora y GRAVITY** (21/oct/2026): GRAVITY le recuerda sus actividades y le hace solicitudes; ella las **confirma** (hecho, no se pudo, con nota). También usa los **dispositivos de la casa** (Fase 6). No conversa libremente con GRAVITY ni ve nada de la familia.

**Pendiente.**
- Si la hermana ve el **resumen mensual del costo del cuidado** (p. ej. si comparten gastos).
- Quién representa a papá para los consentimientos.
- Si papá vive en la casa de las bocinas (afecta qué recordatorios se dicen en voz alta y en qué bocina).

---

## D6. Bocinas Xiaomi como medio de voz de GRAVITY — propuesta

**Equipos.** Dos **Xiaomi Smart Speaker (IR Control)**, modelo L05G: traen **Google Assistant** y **Chromecast integrado** ([Xiaomi](https://www.mi.com/global/product/xiaomi-smart-speaker-ir-control/)). No está confirmado si recibirán Gemini para Home.

**Límite de Google.** Google no deja que otras apps reciban lo que se le dice libremente a sus bocinas: las acciones conversacionales de terceros se cerraron en 2023 y lo nuevo ([Gemini built in](https://9to5google.com/2026/05/21/gemini-built-in-will-bring-google-home-ai-to-more-third-party-speakers-this-year/)) es para fabricantes. Por estas bocinas GRAVITY **no tiene conversación libre**; se usa así:

| Dirección | Cómo | Ejemplos |
|---|---|---|
| **Pedirle a GRAVITY** | **Frases fijas**: rutina de Google Home con comando de voz propio → activa una escena virtual del puente de casa (D9) → GRAVITY ejecuta la herramienta | *"Hey Google, siguiente paso"*, *"paso anterior"*, *"repite el paso"*, *"qué cocino hoy"*, *"lee la lista de compras"*, *"qué toca hoy"* |
| **GRAVITY habla** | GRAVITY genera la voz y el puente de casa la envía a la bocina por Chromecast | Recordatorios, receta paso a paso, recomendaciones, respuesta a las frases fijas |
| **Control infrarrojo** (tele, aire) | Ya funciona con Xiaomi Home + Google Home | Que GRAVITY lo use: a verificar |

**Reglas.**
- Las frases fijas **no llevan datos libres**: *"agrega leche a la lista"* no se puede por la bocina; eso va por teléfono o laptop.
- Rol **Casa** (D5): **nada de dinero ni datos clínicos**; recordatorios de cuidados solo genéricos (D3). Lo que se dice a la bocina pasa por Google.
- Cada frase se asigna a una bocina concreta (p. ej. las de recetas a la de la cocina) para que GRAVITY responda donde la escucharon.
- Conversación libre por voz en casa: teléfono, laptop o, a futuro, un micrófono propio de GRAVITY (satélite de voz conectado al puente de casa).

**Otras vías.** Bocina Bluetooth conectada al teléfono o la laptop: disponible siempre. Alexa: solo si algún día se compra un Echo (skill propia con [API de recordatorios](https://developer.amazon.com/en-US/docs/alexa/smapi/alexa-reminders-overview.html)).

---

## D7. Servidor: Supabase (plan gratis) — confirmada (20/oct/2026)

*Historial: el mismo día se confirmó Firebase Blaze y luego se reemplazó por Supabase, al fijar como condiciones el costo cero y la laptop como centro del sistema (D4).*

**Decisión.** **Supabase en su plan gratis** es el servidor: base de datos compartida, cuentas, roles, archivos pequeños y una función de servidor que guarda la clave de la IA.

**Por qué.**
- **Funciona nativo en Windows** ([supabase_flutter](https://pub.dev/packages/supabase_flutter)). El SDK de Firebase para Windows es *"for development only"* ([FlutterFire](https://github.com/firebase/flutterfire)), y **Blaze no cambia eso**.
- **Costo cero sin tarjeta:** al llegar a un límite se restringe, no cobra.
- **Base de datos relacional (Postgres):** mejor para cuentas y reportes de dinero.
- Incluye funciones de servidor y 1 GB de archivos. Firebase gratis (Spark) no tiene funciones de servidor y, desde febrero de 2026, tampoco archivos ([FAQ de Firebase](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024?hl=es)).

**Arquitectura.**
- **Teléfono:** guarda los registros en el propio teléfono y los envía cuando hay señal; guarda una copia del plan del día.
- **Laptop:** app de Windows conectada directo a la base de datos.
- **Roles (D5):** reglas por registro de la base de datos (RLS), aplicadas en el servidor.
- **Herramientas de GRAVITY:** corren en el dispositivo con los permisos de quien la usa; las reglas por registro garantizan el rol. La regla de D3 (el dinero no pasa por la IA en la nube) se aplica en las herramientas. La función de servidor solo guarda la clave de la IA y envía avisos.
- **Recordatorios programados** (medicamentos, hábitos): notificaciones del propio teléfono, programadas a partir de los horarios y turnos sincronizados; funcionan sin internet.

**Límites del plan gratis y cómo se cubren** ([resumen de límites 2026](https://uibakery.io/blog/supabase-pricing)).

| Límite | Cómo se cubre |
|---|---|
| 500 MB de base de datos | Alcanza para años de registros de texto |
| 1 GB de archivos | Fotos comprimidas; las viejas se mueven a la laptop |
| Se pausa tras 7 días sin uso | Con uso diario no ocurre; si ocurre, los datos se conservan y se reactiva a mano |
| Sin copias de seguridad automáticas | La laptop hace una copia completa diaria, y otra cifrada fuera de la laptop (p. ej. disco externo) |
| Sin modo sin conexión incluido | El teléfono solo registra: cola local de registros. Si hiciera falta más: [PowerSync](https://docs.powersync.com/integration-guides/supabase-+-powersync) |

**Configuración.**
- **Un solo proyecto** para todo el sistema (reemplaza la vía D del contrato v2.0). Región: la de EE. UU. más cercana a México; se elige al crear y no se cambia sin migrar.
- La clave de la IA vive en los **secretos de la función de servidor**, nunca en las apps.
- **Desarrollo con Supabase local** en la laptop; los datos reales de la familia solo en el proyecto real.

**Papel de Firebase — confirmado.** No es la base de datos, pero se usa para lo que da **gratis sin Blaze**:
- **Avisos al instante (Firebase Cloud Messaging):** p. ej. a la cuidadora de turno cuando cambia un medicamento (cambios urgentes, D4), o al Dueño si un medicamento no se marcó a tiempo. Los envía la función de servidor de Supabase.
- **Reporte de fallas (Crashlytics)** en los teléfonos.
- **Reparto de la app (App Distribution)** a los teléfonos de la familia y las cuidadoras, sin publicarla en Google Play.

**Plan B: Firebase Blaze.** No se construye en paralelo (sería doble trabajo en datos, reglas y funciones). El acceso a datos de cada módulo va en una **capa separada** para que un cambio sea posible, aunque no automático (hay que migrar datos, reglas y funciones). Se considera solo si los límites del plan gratis no alcanzan o las pausas causan problemas. El costo no sería el motivo: con este uso (unas 6 personas, cientos de registros al día) Firestore quedaría muy por debajo de su cuota gratis diaria (50,000 lecturas y 20,000 escrituras), así que Blaze probablemente también costaría $0.

---

## D8. Control de la laptop — propuesta

- **Lista cerrada de acciones** (p. ej. abrir programas y archivos, buscar archivos, leer y redactar correos, abrir pantallas de los módulos). Lo que no está en la lista no se puede hacer.
- **Confirmación** antes de enviar, borrar, mover, instalar o pagar. GRAVITY **nunca** opera banca en línea ni compras.
- Lo que GRAVITY **lee** (correos, páginas web, archivos) es información, **nunca órdenes**: si un correo dice "borra tal carpeta", no se ejecuta.
- Bitácora de todas las acciones.

**Pendiente.** La lista concreta de acciones: qué programas, qué correo (Gmail u Outlook), calendario, etc.

---

## D9. Puente de casa — confirmada (20/oct/2026; fase 1 en la laptop)

**Por qué.** Chromecast solo funciona **dentro de la red de la casa**: el servidor en la nube no puede hablarle directo a las bocinas, y la laptop no está siempre encendida.

**Propuesta.** Un equipo pequeño **siempre encendido** en la red de casa con **Home Assistant**:
- Expone las frases fijas de GRAVITY a Google Home y envía la voz de GRAVITY a las bocinas (D6).
- Ejecuta las herramientas de GRAVITY con una **cuenta propia de rol Casa** (D5), así que nunca alcanza dinero ni datos clínicos.
- A futuro: satélites de voz, luces, control infrarrojo y otros aparatos de la casa.
- Conexión con Google: suscripción de Home Assistant Cloud (lo más simple) o configuración manual con un túnel seguro (gratis, más trabajo). **Nunca se abren puertos del router.**

**Fase 1 (elegida): la laptop como puente.** Home Assistant en una máquina virtual de Windows.
- Las bocinas solo responden con la laptop **encendida, sin suspender y en el Wi-Fi de casa**.
- La máquina virtual usa red en **modo puente** (bridge) para que encuentre las bocinas en la red de casa.
- Todo lo de esta fase se configura de modo que pase tal cual al equipo dedicado.

**Fase 2:** equipo dedicado siempre encendido.

**Pendiente.** Qué equipo usar en la fase 2 (Raspberry Pi, Home Assistant Green o mini PC) y qué conexión con Google (Home Assistant Cloud o túnel seguro).

---

## D10. Todo el código y los documentos en el repositorio GRAVITY — confirmada y aplicada (20/oct/2026)

*Aplicada al dar la orden de inicio: el dueño había propuesto GRAVITY como lugar del código. Desde ahora `GRAVITY/docs/` es la fuente única de decisiones, roadmap y diseño; las copias de SEGUNDO-CEREBRO quedan como historial.*

**Decisión propuesta.** El repositorio **GRAVITY** se vuelve el repositorio único de la app: código **y** documentos. Encaja con la idea de GRAVITY como "la app general", y el repositorio está prácticamente vacío (README, CLAUDE.md y una copia del contrato). El README de FINANZAS ya preveía juntar los repositorios.

**Condición.** Todo lo necesario para construir vive **en el mismo repositorio que el código**; si no, cada sesión de Claude Code tendría que manejar cuatro repositorios y los punteros de submódulos.

```
GRAVITY/
  app/          Flutter: Windows (completa) y Android (mínima)
  modulos/      presupuesto, alimentacion, habitos, cuidados, asistente
  supabase/     tablas, reglas por rol, funciones de servidor
  casa/         configuración de Home Assistant (D9)
  data/         datos semilla (data/personal/ ignorada por git)
  docs/
    DECISIONES.md
    CONTRATO (v3.0: reglas internas entre módulos)
    modulos/    diseño de cada módulo (desde FINANZAS y HABITOS; Cuidados y GRAVITY nuevos)
```

- Un `CLAUDE.md` general y uno por módulo; una sesión puede trabajar en un solo módulo sin perder el contexto común.
- **FINANZAS y HABITOS:** sus diseños se copian a `GRAVITY/docs/modulos/` y los repositorios quedan como historial (archivados, solo lectura). No se borra nada.
- **SEGUNDO-CEREBRO:** deja de ser la fuente; queda con un README que apunta a GRAVITY, o se archiva.

**Nombre:** la app se llama **GRAVITY**; "Segundo Cerebro" es el nombre del proyecto.

---

## D11. Prioridad y forma de construir — confirmada (20/oct/2026)

- **Orden:** Finanzas (MVP 1 y 2) → Hábitos (MVP) → Pulido 1 → Cuidados → GRAVITY asistente → Alimentación → ampliaciones. Confirmado el 20/oct/2026.
- **Inicio:** la construcción empieza cuando el dueño del proyecto dé la orden.
- **Funcional primero, pulido después:** cada módulo se construye primero funcional y luego se pule con el diseño UX/UI y lo aprendido al usarlo.
- Detalle por fases en `ROADMAP.md`.

---

## D12. Pantallas: GRAVITY tipo JARVIS en la laptop, app normal en el teléfono — confirmada (20/oct/2026)

- **Laptop:** la pantalla principal es GRAVITY tipo JARVIS. Desde ahí se abren los módulos.
- **Teléfono:** app normal, sin pantalla tipo JARVIS; GRAVITY es una función más (botón de micrófono).
- **Diseño UX/UI común:** se define en paralelo en `DISENO_UX_UI.md`.
- **Estilo configurable** (20/oct/2026): varios estilos (futurista, minimalista, claro, arquitectónico, glass, swagger), claro/oscuro automático por hora y personalidad por módulo y submódulo, sin perder una base común. **Voces configurables** por persona. Detalle en `DISENO_UX_UI.md`.
- **Estilo por defecto: Futurista** (20/oct/2026), con versión de día y de noche. La vista en planta de la tablet se descartó. **Núcleo:** anillos que giran; más opciones después.

---

## D13. Datos sensibles de Hábitos: dos modos — confirmada (20/oct/2026)

**Decisión.** El diario de oración y los hábitos sensibles (p. ej. cigarrillo) se pueden guardar de **dos formas**, a elegir en Ajustes por tipo de dato:

| Modo | Cómo funciona | Se ve en la laptop |
|---|---|---|
| **Cifrado en la nube** | Se cifra en el teléfono antes de subirlo a Supabase; la llave solo la tiene el usuario. Ni el servidor ni otros roles pueden leerlo | Sí |
| **Solo en el teléfono** | No sale del dispositivo; entra en la copia de seguridad local del teléfono | No |

- Ninguno de los dos modos se envía a la IA (D3 y diseño de HÁBITOS, sección 10).
- El valor por defecto se fija en la especificación de la Fase 3.
- Si se pierde la llave del modo cifrado, esos datos no se pueden recuperar: la especificación debe incluir cómo respaldar la llave.

---

## D14. Tablets: personal y pública de la casa — confirmada (20/oct/2026; actualizada 21/oct; detalles propuestos)

**Decisión.** Además de la laptop y los teléfonos, hay una **tablet Android portátil**, compartida en la casa, que **se lleva a donde se use**. Es la misma app, con diseño para tablet.

**Propuesto**
- **Modo Casa** en reposo: usa la cuenta de rol **Casa** (D5), sin dinero ni datos clínicos. Muestra GRAVITY, lo de hoy en la casa, la cocina, el turno de cuidados con recordatorios genéricos y los avisos.
- **Contextos** según dónde se use (confirmado, ampliables): para empezar General, Cocina, Gimnasio y Cuidados; se pueden agregar más. Cambian los gadgets, el tamaño de letra y la personalidad.
- **Orientación:** horizontal y vertical (confirmado).
- **Cambio de usuario:** cada persona entra con PIN o huella y ve sus pantallas según su rol; tras 2 minutos sin uso (editable) regresa al modo Casa. La cuidadora y la hermana pueden trabajar su turno desde ahí.
- **Micrófono propio de GRAVITY en casa:** botón "Mantén para hablar" y la palabra *"Gravity"* solo mientras carga, para cuidar la batería. Permite la conversación libre que las bocinas Xiaomi no permiten (D6).
- **Vista en planta:** descartada (20/oct/2026).

**Dos tipos de tablet (21/oct/2026).** Se elige al registrar el dispositivo en Ajustes › Dispositivos:

| Tipo | En reposo | Quién entra | Qué ve |
|---|---|---|---|
| **Personal** (del dueño y la pareja) | Pantalla de bloqueo con los perfiles permitidos; **no** tiene modo Casa | Solo las personas permitidas, con su **PIN** | Sus pantallas según su rol, dinero incluido; tras 2 min sin uso vuelve al bloqueo |
| **Pública de la casa** | Modo Casa (cuenta de rol Casa), sin dinero ni datos clínicos | Cualquiera ve lo de la casa; para **registrar** pide identidad | Lo de la casa; con PIN, las pantallas de la persona; tras 2 min vuelve al modo Casa |

**Identidad para registrar en la tablet pública — propuesta del arquitecto.**
- **Leer** lo de la casa (recetas, menú, lista de compras, recordatorios genéricos): sin identidad.
- **Registrar algo de la casa** (tachar la lista de compras, marcar un recordatorio genérico como hecho, agregar a la lista): **eliges tu nombre** sin PIN; queda en la bitácora como *"Ana, desde la tablet de la casa"*.
- **Registrar algo personal** (un gasto, un hábito, algo de Cuidados o de papá): **nombre + PIN**; la sesión dura solo esa acción o 2 minutos.
- Nunca se muestran saldos ni datos clínicos en el modo Casa; para verlos, la persona entra con su PIN.
- Solo **PIN** en las dos tablets (la huella queda para el teléfono personal).

**Respuestas del dueño (23/oct/2026).**
- La cuenta del equipo de las tablets es la cuenta de rol Casa y su **nombre visible es "Hogar"** (el rol sigue llamándose `casa` en el código).
- **Bandeja de salida:** un gasto registrado en la tablet pública, con nombre y PIN, y sin señal, **queda en la bandeja de salida y se sube solo cuando hay señal**, sin pedir el PIN otra vez. *(Propuesta técnica: la bandeja guarda el permiso de esa persona cifrado con la llave del dispositivo solo mientras haya algo por subir, lo borra al terminar y caduca a los 7 días; calidad lo revisa.)* *(23/oct/2026, 2.ª ronda: el dueño acepta probarla; si la revisión de calidad ve un riesgo que no se pueda aceptar, se pasa a un permiso de subida acotado que dé backend.)*

**Pendiente.** Qué contextos se agregan; confirmar la propuesta de identidad.

---

## D15. Smartwatch — confirmada (20/oct/2026; detalles propuestos)

**Decisión.** El sistema contempla un dispositivo de muñeca para pantallas de un vistazo. **Hoy es una pulsera smart band**, probablemente de la serie 4 (falta confirmar marca y modelo).

**Propuesto, en dos niveles**
1. **Notificaciones con acciones** (*Hecho*, *Posponer*, *Ya se dio*): salen de las notificaciones del teléfono, funcionan con casi cualquier reloj enlazado y casi no cuestan desarrollo. Disponibles desde que existan las alertas (Fases 2 y 3).
2. **App propia del reloj** (anillos del día, bici en vivo, SOS antojo, medicamento de la cuidadora, serie y descanso): solo si el reloj es **Wear OS**; va en las ampliaciones.

**Reglas.** Sin montos de dinero en el reloj (solo el semáforo); una pregunta y como máximo dos botones por pantalla; los datos del reloj (pasos, ritmo cardiaco, sueño) entran por Health Connect cuando el reloj los comparte.

**Con la pulsera actual:** solo el nivel 1, con texto y vibración (probablemente sin botones). El nivel 2 queda para cuando haya un reloj Wear OS.

**Pendiente.** Marca y modelo exactos de la pulsera; si la cuidadora usa pulsera o reloj.

---

## D16. APIs documentadas con OpenAPI y Swagger UI — confirmada (20/oct/2026; detalles propuestos)

**Decisión.** "Swagger" entra de dos formas: como **estilo** (F, con actitud; `DISENO_UX_UI.md`, sección 4) y como **herramienta**: las APIs del sistema se describen en **OpenAPI** y se consultan y prueban con **Swagger UI**.

**Propuesto**
- **Qué se documenta:** las herramientas de GRAVITY (D1), la base de datos (Supabase, D7), las funciones del servidor (clave de la IA y avisos) y el puente de casa (D9).
- **Dónde:** en la laptop, en Ajustes › Desarrollador, solo con rol Dueño. La especificación **no se publica en internet**.
- **Cada operación indica** su rol, si pide confirmación y si nunca pasa por la IA (D3).
- **Desde la Fase 0:** la especificación crece con cada fase y forma parte de la documentación que leen las sesiones de Claude Code.

---

## D17. Reglas técnicas del servidor (Fase 0) — propuesta

Propuestas por el agente backend al construir el esquema base; no cambian ninguna decisión confirmada.

- **Alcance en los permisos:** la matriz rol × módulo × acción lleva un `alcance` (total, propio o restringido). `puede()` solo da permiso con alcance total; "lo propio" y "su turno" se resuelven aparte, sin dar acceso de más.
- **Personas separadas de las cuentas:** si se borra una cuenta, la persona queda (sin cuenta) para que la bitácora conserve quién hizo qué.
- **Los hogares no se borran:** la bitácora los referencia.
- **Bitácora inmutable** incluso para la cuenta de servicio: sin UPDATE ni DELETE.
- **Un solo dueño activo por hogar;** transferir la propiedad requerirá una función específica.
- **Respaldo:** copia local y copia externa, ambas cifradas (AES-256); retención de 30 días con un mínimo de 7 copias.
- **Bitácora:** las acciones `insertar`, `actualizar` y `borrar` quedan reservadas a los triggers, y toda acción va en minúsculas (`^[a-z][a-z0-9_.]*$`).

**Fase 1 (21–22/oct/2026), con D19:**
- **Libro personal automático:** el servidor crea el libro personal (con sus cuentas Ajustes, Apertura y Por clasificar y sus parámetros) al dar un rol con Finanzas; el libro de papá solo lo crea el dueño con `fin_crear_libro_representado`.
- **Movimientos entre libros:** cada movimiento guarda el libro de cada lado y se ve desde los dos; solo `transferencia` y `pago_deuda` (y su anulación) cruzan de libro.
- **Cuenta maestra:** solo puede ser una cuenta de rol dueño o coadministrador (nunca familiar, cuidador ni Casa).
- **Idempotencia:** el mismo `id` con el mismo contenido no hace nada; con otro contenido es un duplicado (23505).
- **Cierre de semana:** exige antes el cierre de la versión siguiente; en una semana cerrada una ocurrencia puede cambiar su estado y su movimiento (un ingreso que llega tarde), no su fecha ni su monto.
- **Suplente del albacea:** escribe solo si no hay albacea vigente.
- **Alcances:** solo `total`, `propio` y `restringido`; lo particular de cada rol (p. ej. la bandeja de la cuidadora en GRAVITY) se resuelve por rol, no con alcances nuevos.

---

## D18. Decisiones de la revisión de la Fase 0 — confirmada (21/oct/2026)

Tomadas por el arquitecto con el criterio **más seguro** para cerrar los hallazgos de calidad (20/oct) y respondidas por el dueño (21/oct).

| Tema | Queda así |
|---|---|
| Huella en las tablets | **Solo PIN** en las dos tablets; la huella queda para el bloqueo del teléfono personal |
| Tablets (D14) | Dos tipos: **personal** (dueño y pareja, con PIN, sin modo Casa) y **pública de la casa** (modo Casa con cuenta de rol Casa; pide identidad para registrar). La sesión de cada persona se guarda cifrada con su PIN |
| Cuidadora y GRAVITY | **Restringido:** recibe solicitudes y recordatorios de GRAVITY y los confirma; usa los dispositivos de la casa (Fase 6). Sin Finanzas (solo registrará gastos de cuidado en la Fase 5) |
| Coadministrador (pareja) y Cuidados | Sin acceso hasta definir el consentimiento (Fase 5) |
| Historial de GRAVITY | **Cada quien solo lo suyo**, también el dueño; la **cuenta maestra** (D19) ve todo |
| PIN fallido | Espera de 30 s que se duplica hasta 15 min |
| Bloqueo del teléfono | Al abrir y tras 1 minuto en segundo plano |
| Confirmación de correo en Supabase | **Activa** (confirmado 23/oct) |
| PIN y montos ocultos (confirmado 23/oct) | El correo y la contraseña se piden **una vez por dispositivo**; la sesión sigue abierta. Tras unos minutos sin uso (2 por omisión, editable en Ajustes › Privacidad) **los montos se ocultan solos**; para volver a verlos se pide el **PIN** (o la huella en el teléfono). **PIN de 6 dígitos para quien ve dinero** (dueño y coadministradores, incluida la cuenta maestra); se rechazan los PIN triviales. En las tablets el PIN además elige a la persona, y **al entrar con su PIN la persona ve sus montos de una vez**, sin pedirlo otra vez |
| Captura de montos *(propuesta del arquitecto, sin confirmar)* | La coma decimal se lee como punto decimal ("12,5" = $12.50), no como separador de miles |
| Mediciones en el Galaxy A52 y la laptop | Sí, cuando sea posible; no es prioridad |
| Propiedades de los archivos `.xlsx` | Quitado el autor de `data/*.xlsx`; **el historial de git se conserva** |

---

## D19. Finanzas por persona, cuentas compartidas, albaceas y cuenta maestra — confirmada (21/oct/2026; detalles propuestos)

**Decisión del dueño.** Finanzas maneja las **finanzas propias de cada persona** y **cuentas compartidas** para hacer pagos, con **uno o dos albaceas**. Cada quien ve lo suyo y hay una **cuenta maestra** que ve todo.

- **Libros.** Cada persona adulta con Finanzas tiene su **libro** (cuentas, ingresos, compromisos, deudas, sobres y su presupuesto semanal). Hay además **libros compartidos** (por ejemplo, "Gastos de la casa") con sus miembros. Papá tiene su libro, que llevan sus albaceas.
- **Quién ve qué:** cada persona ve su libro y los compartidos de los que es miembro. La pareja ve **su presupuesto y las cuentas compartidas**, no las finanzas personales del dueño (y al revés).
- **Cuentas compartidas:** cualquier miembro registra pagos e ingresos en ellas; las aportaciones desde un libro personal son transferencias entre libros (se ven en los dos).
- **Albaceas (1 o 2, el segundo es suplente):** llevan el libro de papá y actúan **en su nombre** con motivo y bitácora (salvaguardas de la decisión 28 de FINANZAS). Ingresos de papá: **pensión los días 1 y 11** de cada mes (si cae en fin de semana o festivo, el siguiente día hábil) y **apoyo gubernamental 60+ cada bimestre**. Montos y fechas los captura el dueño; no se inventan.
- **Cuenta maestra — propuesta.** Una sola por hogar, la asigna el dueño. **Solo lee** todo (libros, historial de GRAVITY) y no escribe en lo ajeno; cada consulta a lo de otra persona queda en la bitácora y cada persona ve en Ajustes › Privacidad que la cuenta maestra existe. Se recomienda que sea una **cuenta aparte** del dueño, usada solo en la laptop.
- **D3 sigue igual:** nada de esto va a la IA en la nube ni a las bocinas.

**Qué cambia.** Los libros personales, los compartidos, los albaceas del libro de papá y la cuenta maestra entran al **MVP 1** (Fase 1). Las confirmaciones entre miembros, las deudas internas, la aportación proporcional y la auditoría siguen en la Fase 8. El dueño y la pareja pasan de "total" y "leer todo" a **alcance propio** en Finanzas y GRAVITY.

**Respuestas del dueño del 23/oct/2026 (revisión de calidad de la Fase 1).**

- **Cuenta maestra con login propio.** El dueño usa **su cuenta normal** para lo suyo y entra a la maestra con **un login distinto**. Como cada persona tiene un solo login, la maestra es **otra persona con su propia cuenta**, que crea el dueño (rol coadministrador con la marca de maestra). **No se prohíbe** que el dueño sea también la maestra con su propia persona.
- **La maestra es solo lectura total:** no registra nada, ni propio; lo suyo lo registra el dueño con su cuenta normal. No tiene (+) ni órdenes que abran una hoja de registro. *(Confirmado el 23/oct/2026; más adelante se verá si también puede editar.)*
- **Consulta registrada:** para leer el libro de otra persona, la maestra debe tener una consulta registrada (dura 30 min y la app la renueva sola mientras el libro está abierto; la persona no nota nada). Sirve para que cada consulta quede en la bitácora y los demás puedan ver quién miró y cuándo. Solo cambia el valor de la vigencia si el dueño lo pide.
- **Libros compartidos:**
  - **Quien lo crea es el administrador:** agrega y saca miembros, decide si es **pública o privada** y lo cierra.
  - **Cualquier miembro puede salirse** cuando quiera. **Si al salir queda menos de 2 miembros, el presupuesto NO se archiva: pasa a privado** (decidido el 23/oct/2026) y sigue activo para quien se queda, que queda como administrador. El que se sale pierde el acceso, y lo que registró queda en el historial. Archivar es solo una decisión explícita del administrador; el último miembro no puede salirse (archiva o cierra el libro).
  - **Si se sale el administrador,** el cargo pasa al miembro más antiguo (confirmado el 23/oct/2026). Si solo eran 2, el que queda es el administrador y el presupuesto pasa a privado.
  - **Ejemplo revisado y confirmado por el dueño (23/oct/2026):** Ana crea "Gastos de la casa" con Alex y es pública. Si Alex se sale, queda solo Ana, el presupuesto pasa a privado y sigue activo; Alex pierde el acceso y lo que registró queda en el historial; lo que aportó no se devuelve solo y, si hay saldo, la app avisa antes de salir sin bloquear. Si se sale Ana y solo eran 2, Alex queda como administrador y privado; con 3 o más, el cargo pasa al más antiguo. El último miembro no puede salirse: el administrador archiva o cierra el libro.
  - **Agregar miembros:** cualquier adulto con Finanzas puede ver quiénes son los adultos con Finanzas del hogar (solo nombres, nunca la cuenta maestra) para poder invitarlos a un compartido que administra.
  - **Privada** (por omisión): la ven y escriben sus miembros; la lee también la maestra. **Pública:** además la **leen** (no escriben) los adultos con Finanzas del hogar.
  - **El dueño no entra a un compartido privado del que no es miembro;** solo la maestra.
- **Libro de papá:** todo movimiento va **en nombre de papá y con motivo**; las salidas hacia un libro personal avisan al suplente.
- **Configuración del hogar** (categorías, días inhábiles, importar): la hacen el **dueño y la pareja**.
- **Cuentas de gasto:** se archivan al cerrar la cuenta o archivar su categoría (las de activos y pasivos siguen pidiendo saldo cero para cerrarse).
- **"La caja":** es la **Caja Popular Mexicana**, el crédito automotriz del dueño. Es la única deuda cuyo pago pasa al siguiente día hábil (se configura en la app; no se guarda en el repositorio).
- **Gastos y cuentas:** un gasto sale de una **cuenta existente**; si no hay ninguna, la hoja ofrece **"Crear cuenta nueva"**. La **categoría es opcional** (queda "Por clasificar"; el árbol de categorías viene precargado).
- **Importar datos:** con **selector de archivos**.
- **Orden de voz o escrita:** hay que decir **"registrar gasto"**; la palabra "gasto" suelta ya no abre nada.
- **Pendiente de explicar al dueño:** cómo cambia un ingreso y cómo afecta uno nuevo (vigencias); hasta que responda, la app sigue permitiendo editar una vigencia.
- **Segunda ronda del 23/oct/2026:** el chip "Cuenta nueva" de la hoja de gasto se ve **siempre**; la hora al salirse de un libro la pone el teléfono (no se pide función de servidor); la pantalla "Tengo una invitación" se construye en la siguiente ronda.


