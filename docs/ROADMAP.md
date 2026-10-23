# Roadmap de GRAVITY (proyecto Segundo Cerebro)

> **Versión 0.9 (23/oct/2026), en ejecución.** El dueño del proyecto dio la orden de inicio el 20/oct/2026. Plan de ejecución de la app única (D1): la **laptop Windows** con el sistema completo y el **teléfono Android** con lo mínimo (D4). Las decisiones de arquitectura están en `DECISIONES.md`; el diseño visual se define en paralelo en `DISENO_UX_UI.md`.
>
> Fuente única: `GRAVITY/docs/ROADMAP.md` (D10 aplicada el 20/oct/2026). La ejecución la hace el **equipo de agentes** de la sección 11.

---

## 1. Cómo se construye

1. **Prioridad:** Finanzas (submódulos prioritarios) → Hábitos (módulos prioritarios) → lo demás.
2. **Funcional primero, pulido después.** Cada módulo pasa dos veces:
   - **Funcional:** hace lo que debe con datos reales, reglas correctas y pruebas de la lógica; pantallas sencillas con el tema base.
   - **Pulido:** se aplica el diseño UX/UI, se corrige lo que estorbe al usarlo y se agregan opciones y casos raros.
   - Para que el pulido no obligue a rehacer: colores, tipografías y espaciados salen de un **tema central** desde el primer día, y la lógica va separada de las pantallas.
3. **Cada fase termina con algo usable** en la laptop y en el teléfono reales (Windows y el Samsung Galaxy A52 de pruebas).
4. **Antes de programar cada fase, una especificación corta:** qué entra, modelo de datos, pantallas, criterios de aceptación (tomados de las pruebas de los diseños) y preguntas abiertas. Es el formato de desarrollo guiado por especificaciones que ya preveían FINANZAS (pendiente 29) y HÁBITOS (Anexo I).
5. **Laptop completa, teléfono mínimo (D4):** cada fase dice qué va en cada uno.
6. Todo cambio a este roadmap se anota en el control de cambios.

---

## 2. Vista general

| Fase | Qué | Resultado utilizable |
|---|---|---|
| **0** | Cimientos + pantalla principal de GRAVITY (sin IA) | Entrar con tu cuenta en laptop y teléfono; cada rol ve solo lo suyo |
| **1** | Finanzas MVP 1 | Saber cuánto entra, cuánto sale y cuánto queda en la semana |
| **2** | Finanzas MVP 2 | Ver deudas y compromisos, apartar ahorro y recibir alertas |
| **3** | Hábitos MVP | Objetivos, Hoy, cigarrillo y azúcar, agenda, espiritual y revisión semanal |
| **4** | Pulido 1 | Finanzas y Hábitos con el diseño UX/UI y los ajustes del uso real |
| **5** | Cuidados | Turnos, medicamentos, comidas de papá, bitácora y entrega de turno |
| **6** | GRAVITY asistente | Conversación con IA, voz, control de la laptop y bocinas Xiaomi |
| **7** | Alimentación | Menús, recetas, lista de compras y precios |
| 8+ | Ampliaciones | Lo demás de Finanzas, Hábitos y GRAVITY, por bloques (orden por definir) |

Orden de las fases 0 a 7 confirmado el 20/oct/2026 (sección 10).

---

## 3. Fase 0 — Cimientos

**Antes de empezar:** juntar los repositorios (D10, si se confirma), convertir el contrato v2.0 en reglas internas entre módulos (v3.0) y escribir la especificación de la fase.

**Incluye**
- Proyecto Flutter con dos salidas: **Windows (completa)** y **Android** (teléfono mínimo y tablet de la casa); estructura por módulos.
- **Sistema de estilos** (`DISENO_UX_UI.md`, sección 4): valores de diseño en el tema central, el estilo Futurista (por defecto, con versión de día y de noche) y claro/oscuro automático por hora.
- **Tablet portátil de la casa (D14):** diseño para tablet (horizontal y vertical), modo Casa con contextos y cambio de usuario con PIN o huella. El modo Casa se va llenando conforme entran los módulos.
- **APIs documentadas (D16):** especificación OpenAPI y consola Swagger UI en Ajustes › Desarrollador (laptop, rol Dueño); crece con cada fase.
- **Supabase (D7):** proyecto real y versión local para desarrollo; cuentas (correo o Google); tablas base de hogar, personas y roles; reglas por registro (RLS) para los roles de D5.
- **Firebase (D7):** avisos al instante (FCM), reporte de fallas (Crashlytics) y reparto de la app (App Distribution).
- **Teléfono:** cola local de registros para trabajar sin conexión y bloqueo con PIN o huella.
- **Laptop:** copia de seguridad diaria de la base de datos, más una copia cifrada fuera de la laptop.
- **Pantalla principal de GRAVITY en la laptop**, versión sin IA: saludo, fecha y hora, resumen del día (se llena conforme entran los módulos), acceso a los módulos y **barra de comandos** de texto para navegar (*"abre presupuesto"*). Estilo tipo JARVIS según `DISENO_UX_UI.md`.
- **Teléfono:** app normal con barra inferior según el rol, sin pantalla tipo JARVIS.

**Aceptación**
1. Entras con tu cuenta en la laptop y en el teléfono.
2. Una cuenta de prueba con rol Cuidador solo ve Cuidados (vacío). Una con rol Familiar no ve dinero, comprobado en el servidor y no solo en la pantalla.
3. Un registro hecho sin internet en el teléfono se sube al volver la señal.
4. La copia de seguridad diaria se genera y se puede restaurar en el entorno local.
5. La app llega a un teléfono de prueba por App Distribution.
6. En la tablet, el modo Casa no muestra dinero; al tocar un nombre y poner el PIN aparecen las pantallas de esa persona, y tras 2 minutos sin uso regresa sola al modo Casa.
7. El estilo se cambia en Ajustes sin reiniciar, y el claro/oscuro cambia solo según la hora.
8. Lo construido aparece documentado en Ajustes › Desarrollador y se puede probar desde ahí.

---

## 4. Fase 1 — Finanzas MVP 1 (funcional)

Base: diseño de FINANZAS v23, sección 10 (MVP 1).

| Submódulo | Laptop | Teléfono |
|---|---|---|
| Libros (D19): personal por adulto, compartidos (públicos o privados), libro de papá con albaceas y cuenta maestra de solo lectura | Completo | Ver el libro activo y cambiar de libro |
| Hogar y perfiles (con las personas de D5) | Alta y configuración | — |
| Cuentas y libro de movimientos (solo-agregar; se corrige con anulación y contraasiento) | Completo | Se alimenta al registrar |
| Ingresos (forma y día de pago por miembro, extras) | Completo | Registrar un ingreso extra |
| Gastos (captura manual, categorías de hasta 3 niveles, división por líneas) | Completo | **Registrar un gasto en menos de 10 s** |
| Presupuesto semanal (motor y cascada ingreso → presupuesto → deuda → remanente) | Completo | Resumen de la semana con semáforo |
| Tablero | Completo | — |
| Datos semilla (importar Excel/CSV) | Importación | — |

**Queda para después:** captura por voz e imagen (foto, OCR, QR), modo Pareja y Familiar completo, conciliación con estados de cuenta y reportes de auditoría.

**Definido (21 a 23/oct/2026, D18 y D19):**
- Finanzas **por persona** (cada quien su libro) y **cuentas compartidas** para pagos. Quien crea un compartido es su administrador y decide si es público o privado; cualquiera puede salirse, y con menos de 2 miembros el libro pasa a privado.
- **Libro de papá** con 1 o 2 albaceas: todo movimiento va en su nombre y con motivo; pensión los días 1 y 11 y apoyo 60+ cada bimestre.
- **Cuenta maestra** con login propio: solo lectura total, con consulta registrada (30 min, la app la renueva sola). Más adelante se decide si también puede editar.
- **Seguridad en pantalla:** montos ocultos automáticos tras 2 min sin uso, PIN de 6 dígitos para quien ve dinero, pantallas con dinero bloqueadas para capturas (FLAG_SECURE).
- **Tablets:** pública de la casa (cuenta "Hogar") y personal; **bandeja de salida** que sube sola lo registrado sin señal, a prueba.
- Especificación v0.5 (`docs/specs/fase-1-finanzas.md`); revisiones de calidad en `docs/revisiones/fase-1.md` y `fase-1b.md`.

**Aceptación:** las pruebas del motor de presupuesto (5.6 bis) y del libro de movimientos (5.0 bis) pasan; registrar un gasto en el teléfono toma menos de 10 s; la app abre en menos de 2 s (decisión 24 de FINANZAS).

**Para usarla con tus datos reales** (no bloquea programar): tus ingresos reales (pendientes 24 y 25 de FINANZAS) y revisar las decisiones marcadas "por defecto" (pendiente 13).

---

## 5. Fase 2 — Finanzas MVP 2 (funcional)

Base: diseño de FINANZAS v23, sección 10 (MVP 2).

| Submódulo | Laptop | Teléfono |
|---|---|---|
| Deudas: préstamos, tarjetas y MSI, con orden de pago por costo (5.3) | Completo | Ver los próximos pagos |
| Ahorro con métodos y fondo de emergencia por niveles (5.5 bis) | Completo | Ver el avance |
| Alertas de vencimiento (notificaciones del teléfono y avisos al instante) | Configurar | Recibirlas |

**Pulsera (D15, nivel 1):** las alertas llegan a la pulsera como avisos cortos con vibración, sin app propia.

**Queda para después:** simulador completo de estrategias de pago (5.3 ter), estimador de intereses con estados de cuenta, beneficios de tarjetas, inversión, bienes y previsión.

**Para usarla con tus datos reales:** llenar la ficha de deudas y tarjetas (pendiente 8) y las compras a MSI actuales (pendiente 12).

---

## 6. Fase 3 — Hábitos MVP (funcional)

Base: diseño de HÁBITOS v1.18, Anexo H, etapas 1 a 5 (la etapa 0 ya está cubierta por la Fase 0).

| Módulo | Laptop | Teléfono |
|---|---|---|
| Núcleo: objetivos (asistente SMART), Hoy, registro, rachas y carga del día | Crear y ajustar objetivos; ver el día | **Hoy:** marcar, posponer, omitir |
| Hábitos a eliminar: cigarrillo y azúcar (línea base, fases, Día D) | Configurar el plan; ver patrones | Registro en un toque; **SOS "Tengo un antojo"** |
| Agenda y asistente de configuración | Agenda completa y asistente | Ver el día; recordatorios con acciones |
| Espiritual (MVP): lector, plan de lectura, devocional y oración | Completo | Lector, devocional y oración |
| Progreso y revisión semanal (sábados) | Revisión y gráficas | Aviso y resumen |

Algunas funciones de Hábitos se usan **en el momento** y por eso van en el teléfono aunque no sean "lo mínimo": el SOS, el registro de consumo y la lectura espiritual (lector, devocional y oración).

**Aceptación:** los criterios de las etapas 1 a 5 del Anexo H y de las pantallas G.10.1 (Hoy) y G.10.3 (panel de hábito a eliminar).

**Decisiones de esta fase**
- **Diario de oración y hábitos sensibles: los dos modos (D13).** Cada tipo de dato sensible se puede guardar **cifrado en la nube** (se cifra en el teléfono antes de subirlo; solo tú lo lees, también en la laptop) o **solo en el teléfono** (no sale del dispositivo). Se elige en Ajustes; el valor por defecto se fija en la especificación de esta fase.
- **Licencias de la Biblia:** se arranca con versiones de dominio público (RVR1909 y KJV) mientras se resuelve RVR1960 y NVI (Anexo H, etapa 4).

---

## 7. Fase 4 — Pulido 1

- Aplicar el sistema de diseño de `DISENO_UX_UI.md` a la pantalla de GRAVITY, a Finanzas y a Hábitos.
- Agregar los demás estilos (minimalista, claro, arquitectónico, glass, swagger), la personalidad por módulo y submódulo, y los gadgets.
- Corregir la lista de "lo que estorba" juntada durante el uso real de las fases 1 a 3.
- Cumplir las metas de rendimiento: abrir en menos de 2 s, registrar un gasto en menos de 10 s y la acción diaria de Hábitos en 3 toques o menos.
- Traer de "después" lo que haya resultado urgente.

---

## 8. Fases siguientes (orden confirmado)

### Fase 5 — Cuidados (funcional)
- **Teléfono (cuidadoras):** mi turno y entrega de turno, horario de medicamentos y marcar los que ya se dieron, comidas de papá (comió, comió poco, rechazó), bitácora y gastos de cuidado.
- **Laptop (Dueño):** medicamentos, citas, turnos y cuidadoras, resumen y costos. Los gastos de cuidado pasan a Finanzas con confirmación.
- **Cambios urgentes** desde el teléfono del Dueño, con aviso al instante a la cuidadora de turno (D4). Recordatorios al teléfono de quien está de turno (D5).
- **Necesita:** el documento de la app de cuidados actual (pendiente 2 de FINANZAS) y las respuestas pendientes de D5. Mientras tanto se sigue usando la app actual.

### Fase 6 — GRAVITY asistente
- Conversación por texto con IA en la pantalla principal, con las herramientas de Finanzas, Hábitos y Cuidados según el rol; el dinero nunca pasa por la IA en la nube (D3).
- Voz en la laptop (escuchar y hablar).
- Control de la laptop con su lista cerrada de acciones (D8).
- Puente de casa en la laptop y bocinas Xiaomi con frases fijas (D6 y D9).
- En el teléfono: GRAVITY por voz como una función más de la app, sin pantalla tipo JARVIS.
- **Por decidir:** proveedor de IA (FINANZAS eligió empezar con Gemini en su nivel gratuito, decisión 40; HÁBITOS prefería Claude), la lista de acciones de la laptop (D8) y las frases de las bocinas (D6).

### Fase 7 — Alimentación
- Catálogo, recetas, menú, lista de compras (en el teléfono, para usarla en el súper), historial de precios con alerta y lector de código de barras (FINANZAS, fase 3 de su hoja de ruta).
- El plan de comidas llega directo a Hábitos (marcar cumplimiento) y a Cuidados (comidas de papá), ya dentro de la misma app y sin archivos.

### Fase 8+ — Ampliaciones
Por bloques, cada uno con su pasada funcional y su pulido.
- **Finanzas:** lo que falta del modo Pareja y Familiar (transferencias con confirmación, deudas internas, aportación proporcional, auditoría; los libros personales, compartidos y de papá con albaceas entran en la Fase 1 por D19), conciliación con estados de cuenta en la laptop (los archivos no se suben), simulador de deudas y estimador de intereses, beneficios de tarjetas, inversión, objetivos y plan, bienes y previsión, reportes, y voz e imagen en el teléfono.
- **Hábitos:** salud (sueño, entrenamiento, suplementos, medidas), bicicleta y música, inglés y modo traslado, estudios bíblicos ampliados, pareja, Health Connect y el coach, que pasa a ser parte de GRAVITY.
- **GRAVITY:** equipo dedicado para el puente de casa (D9, fase 2), micrófono propio en casa e IA local en la laptop para analizar dinero (D3).
- **Reloj Wear OS (D15, nivel 2):** app propia, solo si más adelante se cambia la pulsera por un reloj Wear OS.

---

## 9. En paralelo

- **`DISENO_UX_UI.md`:** se define contigo durante las fases 0 a 3 y se aplica en el Pulido 1. Mientras tanto, las pantallas usan el tema base.
- **Datos para usar la app con tu información** (no bloquean programar): los pendientes de la sección 12.2 de FINANZAS (ingresos, ficha de deudas, estados de cuenta de ejemplo, gastos previsibles, bienes) y las preguntas abiertas de la sección 12 de HÁBITOS.

---

## 10. Respuestas del dueño del proyecto (20/oct/2026)

| # | Pregunta | Respuesta |
|---|---|---|
| 1 | Orden después de Hábitos | **Sí:** Cuidados → GRAVITY asistente → Alimentación |
| 2 | Submódulos prioritarios de Finanzas | **MVP 1 y MVP 2**, tal como están en las fases 1 y 2 |
| 3 | Lectura espiritual en el teléfono | **Sí:** lector bíblico, devocional y oración también en el teléfono |
| 4 | Diario de oración y hábitos sensibles | **Ambos modos:** cifrado en la nube o solo en el teléfono, a elegir (D13) |

**Siguiente paso:** la construcción empieza con la Fase 0 cuando el dueño del proyecto dé la orden. Mientras tanto se trabaja en `DISENO_UX_UI.md`.

---

## 11. Equipo de agentes (ejecución en paralelo)

La ejecución la hace un equipo de agentes de Claude Code, **cada uno especializado en un área** y con carpetas propias para trabajar en paralelo sin chocar. Las instrucciones completas de cada agente están en `.claude/agents/<agente>.md`; esta sección es el resumen que manda.

### 11.1 Reglas comunes (todos los agentes)

1. **Leer primero:** `CLAUDE.md`, `docs/DECISIONES.md`, este roadmap, `docs/DISENO_UX_UI.md`, la especificación de la fase en `docs/specs/` y el diseño de su módulo en `docs/modulos/`.
2. **Especificación antes que código:** si la fase no tiene especificación, el agente del módulo la escribe primero (formato de `docs/specs/fase-0-cimientos.md`).
3. **Solo escribe en sus carpetas.** Si necesita algo de otra área, lo pide en su reporte; no lo resuelve por su cuenta.
4. **Convenciones** de `docs/specs/fase-0-cimientos.md`, sección 4: centavos, semana en lunes, UUID, libro solo-agregar, roles, herramientas, sin secretos.
5. **Pruebas que pasan** antes de entregar (`flutter analyze`, `flutter test`, `dart test`, pruebas SQL).
6. **No hace commits** cuando trabaja en paralelo: el **arquitecto** integra, revisa y hace commit.
7. **Decisiones nuevas:** las propone en su reporte; solo el arquitecto edita `docs/DECISIONES.md` y este roadmap, con aprobación del dueño cuando cambian algo confirmado.
8. **Reporte final:** qué hizo, archivos, pruebas y resultado, dependencias que agregó, pendientes y preguntas para el dueño.
9. Español en documentos e interfaz.
10. **Modelo:** todos los agentes usan **Sonnet 5.5** (`model: claude-sonnet-5-5` en el encabezado de cada definición de `.claude/agents/`), por decisión del dueño del 23/oct/2026. Para cambiarlo, se edita ese encabezado.

### 11.2 Los agentes

| Agente | Especialidad | Carpetas propias | Fases |
|---|---|---|---|
| **arquitecto** | Orquesta, integra, revisa, hace commit y mantiene decisiones, roadmap y especificaciones comunes | Todo (integración) | Todas |
| **plataforma** | App Flutter: cascarones por dispositivo (laptop, tablet, teléfono), router por rol, sesión, cola sin conexión, ajustes, tablet con cambio de usuario, Firebase (avisos, fallas, reparto), pulsera | `app/lib/app`, `app/lib/nucleo` (menos `herramientas`), `app/lib/modulos/ajustes` (menos `desarrollador`), dependencias de `app/pubspec.yaml` | 0, 2, 4, 5 |
| **diseno** | Sistema de estilos (4 capas), estilos, personalidad por módulo, componentes, gadgets, pantallas principales, accesibilidad | `app/lib/diseno`, `app/lib/modulos/gravity/pantalla`, `app/assets`, sección `flutter:` de `app/pubspec.yaml` | 0, 1, 3, 4 |
| **backend** | Supabase: esquema, migraciones, RLS por rol, funciones de servidor, pruebas SQL, respaldos | `supabase/`, `herramientas/respaldo` | 0, 1, 2, 3, 5 |
| **asistente** | GRAVITY: herramientas (D1, D3), barra de órdenes, IA y voz, control de la laptop (D8), APIs con OpenAPI y Swagger UI (D16) | `app/lib/nucleo/herramientas`, `app/lib/modulos/gravity/ordenes`, `app/lib/modulos/ajustes/desarrollador`, `api/` | 0, 6 |
| **finanzas** | Módulo Finanzas: especificación, dominio puro y pantallas | `paquetes/finanzas_dominio`, `app/lib/modulos/finanzas`, `docs/specs/fase-1-*`, `docs/specs/fase-2-*` | 0 (adelanto), 1, 2, 8 |
| **habitos** | Módulo Hábitos: especificación, dominio y pantallas | `paquetes/habitos_dominio`, `app/lib/modulos/habitos`, `docs/specs/fase-3-*` | 3, 8 |
| **cuidados** | Módulo Cuidados: turnos, medicamentos, comidas de papá, bitácora, cambios urgentes | `paquetes/cuidados_dominio`, `app/lib/modulos/cuidados`, `docs/specs/fase-5-*` | 5 |
| **casa** | Puente de casa (Home Assistant), bocinas Xiaomi, modo Casa | `casa/`, `app/lib/modulos/casa` | 6 |
| **alimentacion** | Menús, recetas, lista de compras y precios | `paquetes/alimentacion_dominio`, `app/lib/modulos/alimentacion`, `docs/specs/fase-7-*` | 7 |
| **calidad** | Revisión de cada fase: pruebas, seguridad, privacidad (D3, D13), roles (RLS) y accesibilidad | `docs/revisiones/`; pruebas en las carpetas `test/` | Cierre de cada fase |

### 11.3 Asignación por fase

| Fase | Agentes en paralelo | Cierre |
|---|---|---|
| 0 | plataforma, diseno, backend, asistente; **finanzas** adelanta la especificación de la Fase 1 y el dominio | calidad |
| 1 | finanzas, backend (esquema de Finanzas), diseno (pantallas y gadgets de Finanzas), plataforma (rutas, tablets, cola, seguridad), asistente (herramientas y APIs) | calidad |
| 2 | finanzas, backend (funciones de avisos), plataforma (avisos y pulsera) | calidad |
| 3 | habitos, backend, diseno | calidad |
| 4 | diseno, plataforma | calidad |
| 5 | cuidados, backend, plataforma | calidad |
| 6 | asistente, casa | calidad |
| 7 | alimentacion, finanzas, habitos | calidad |
| 8+ | según el bloque | calidad |

### 11.4 Estado de la ejecución

| Fase | Estado | Notas |
|---|---|---|
| 0 | **Cerrada en lo técnico** (20/oct/2026); falta lo del dueño | App con cascarones laptop/tablet/teléfono, navegación y resumen por rol, sesión, cola sin conexión por persona, tablet con cuenta Casa y PIN, bloqueo del teléfono, estilo Futurista día/noche, pantalla principal, barra de órdenes, Desarrollador; Supabase con RLS alineada; respaldo cifrado; OpenAPI. Revisión de calidad con sus hallazgos resueltos (`docs/revisiones/fase-0.md`, sección 11). Pruebas: 409 app, 249 SQL, 43 respaldo, 122 finanzas. **Falta del dueño:** proyecto de Supabase, proyecto de Firebase, Flutter en la laptop y las decisiones provisionales de D18 |
| 1 | **Construida, en revisión de calidad** (23/oct/2026) | Hecho por los cinco agentes: dominio (libros, cuadre entre libros, grupo de deudas prioritarias, ingresos con días fijos y cada N meses), módulo Finanzas (asistente de arranque, importar con selector de archivos, ajustes, tablero, semana, movimientos, hojas (+)), base de datos (libros, albaceas, cuenta maestra, salvaguardas, compartidos públicos o privados, 4 migraciones), gadgets y componentes de diseño, tablets y bandeja de salida, FLAG_SECURE, PIN de 6 dígitos, montos ocultos, órdenes de GRAVITY y APIs (versión 0.4.0). Última corrida completa: **224** pruebas de dominio, **1240** de la app, **1455** comprobaciones SQL, 44 de respaldo, APIs válidas. Calidad: primera revisión sin bloqueantes y con 11 importantes, ya corregidos; revisión corta (`fase-1b.md`) en curso. **Falta:** cerrar los hallazgos de la revisión corta, probar `flutter build` de Windows (file_picker) y de Android (FLAG_SECURE), y medir el arranque y el registro de un gasto en el Galaxy A52 (criterios 11 y 28) |
| Siguiente ronda | Pendiente | Pantalla "Tengo una invitación" (registro y aceptar invitación); indicador "En línea" con conectividad real; cifras reales de Finanzas en "Hoy"; cómo cambia un ingreso (vigencias: explicado, falta decidir si se endurece); decidir si la cuenta maestra también edita; acotar la bandeja de salida si calidad lo recomienda; aviso al suplente por notificaciones y consulta registrada en el historial de GRAVITY (Fase 2) |

---

## Control de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 0.1 | 20/oct/2026 | Primera versión: prioridad Finanzas → Hábitos, funcional primero y pulido después, pantalla principal de GRAVITY en la laptop y app normal en el teléfono |
| 0.2 | 20/oct/2026 | Aprobado: orden de las fases 5 a 7, Finanzas MVP 1 y 2 como prioritarios, lectura espiritual en el teléfono y los dos modos para datos sensibles (D13). La construcción espera la orden de inicio |
| 0.3 | 20/oct/2026 | Tablet de la casa (D14) y sistema de estilos en la Fase 0; los demás estilos, la personalidad por módulo y los gadgets en el Pulido 1; los roles financieros entre miembros se definen en la especificación de la Fase 1 |
| 0.4 | 20/oct/2026 | Futurista por defecto; tablet portátil con contextos; APIs documentadas con OpenAPI y Swagger UI desde la Fase 0 (D16); smartwatch: notificaciones desde la Fase 2 y app propia en las ampliaciones (D15) |
| 0.5 | 20/oct/2026 | Pulsera smart band en lugar de smartwatch (app propia solo con reloj Wear OS); tablet en horizontal y vertical con contextos ampliables |
| 0.6 | 20/oct/2026 | Orden de inicio. D10 aplicada (todo en GRAVITY). Sección 11: equipo de agentes especializados con sus instrucciones, asignación por fase y estado de la ejecución |
| 0.7 | 20/oct/2026 | Fase 0 integrada (estado en 11.4); especificación de la Fase 1 lista para aprobación |
| 0.8 | 20/oct/2026 | Fase 0 cerrada en lo técnico tras la revisión de calidad; decisiones provisionales en D18 |
| 0.9 | 23/oct/2026 | Fase 1 construida y en revisión de calidad. Decisiones del dueño D18 (confirmada) y D19 (finanzas por persona, cuentas compartidas, albaceas, cuenta maestra con login propio, compartidos públicos o privados). Tablets pública y personal con bandeja de salida; PIN de 6 dígitos y montos ocultos automáticos; agentes fijados en Sonnet 5.5 (regla 11.1.10); siguiente ronda definida |
