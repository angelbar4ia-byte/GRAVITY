# Especificación — Fase 4: Pulido 1

> Versión 0.1 (6/nov/2026), **borrador para aprobación del dueño**. Base: `docs/ROADMAP.md` (sección 7 y 11.4), `docs/DECISIONES.md` (D12, D14, D15, D16, D20 y D21), `docs/DISENO_UX_UI.md` v0.6 (secciones 4 a 6, 18 a 21), las revisiones de calidad de las fases 1, 1b, 2 y 3 (`docs/revisiones/`) y las especificaciones de las fases 1 a 3. Se aplican las convenciones de `docs/specs/fase-0-cimientos.md`, sección 4.
>
> Las preguntas para el dueño están en la **sección 12**, cada una con su propuesta por defecto. Lo que quedó ambiguo se marca **(interpretación)**.
>
> **Qué ya existe y NO se vuelve a hacer** (`app/lib/diseno`): las capas 1 a 4 (`Estilo`, `ValoresDiseno`, `PersonalidadModulo`, `ModoClaroOscuro` con horario 07:00 a 19:00 editable), el estilo **Futurista** de día y de noche, la excepción de alto contraste de Cuidados y bici, los componentes base (tarjeta de módulo, monto ocultable, semáforo, barra de progreso, tarjeta de confirmación, estado vacío, núcleo animado que respeta "reducir movimiento"), los gadgets de Finanzas (medidor, cascada, escalera del fondo, barra de límite, tarjeta de deuda, línea de vencimientos, bolsa de ahorro, orden de pago, teclado de monto) y los de Hábitos (anillos del día, medidor de carga, fila de hábito, chip de racha, calendario de constancia, contador de días libres, SOS, lector, plan, devocional). Fuentes incluidas hoy: Chakra Petch, IBM Plex Sans e IBM Plex Mono. Esta fase **amplía** esas piezas; no las duplica.

---

## 1. Resultado utilizable

**Que la app se vea como tú quieres, se sienta rápida y deje de estorbar en el uso diario.**

- **Eliges el estilo** (Futurista, Minimalista, Claro sereno, Glass, Swagger y Arquitectónico) en *Ajustes › Apariencia* con vista previa en vivo y **sin reiniciar**. El día y la noche cambian solos con la hora (claro de 07:00 a 19:00 por defecto) y nunca a mitad de una acción.
- **Cada módulo tiene su carácter** (Finanzas precisa y serena; Hábitos contemplativa, sport, lúdica o empática), sin volverse "tutifruti": una sola personalidad por pantalla, y Cuidados y bici siempre en alto contraste.
- **La pantalla principal de GRAVITY, Finanzas y Hábitos** usan los seis estilos con la misma estructura. Ninguna pantalla trae colores ni fuentes fijas.
- **Lo que estorba, corregido:** la lista de pendientes de interfaz de las fases 1 a 3 (sección 2.3) se atiende en el orden que ahí se decide.
- **Rápida de verdad:** abre en menos de 2 s, registrar un gasto toma menos de 10 s y la acción diaria de Hábitos, 3 toques o menos, **medido en tu Galaxy A52 y en la laptop** (sección 7).
- **Accesible de verdad:** zonas táctiles de 48 dp, lector de pantalla, letra al 200 % sin cortes a 360 dp y a 900 dp, y nada que dependa solo del color (sección 8).

**Regla de oro de la fase (D3, D13, D14):** ningún estilo, gadget, vista previa, captura de prueba, aviso o medición lleva dinero, datos clínicos ni datos sensibles de Hábitos reales ni en claro donde no deben. El tema es solo apariencia: **cambiarlo nunca cambia qué datos se muestran ni a quién** (sección 9).

---

## 2. Alcance

### 2.1 Entra en el Pulido 1

| Área | Qué entra | Diseño |
|---|---|---|
| Sistema de estilos | Los **cinco estilos que faltan** (sección 4.1), cada uno con versión de día y de noche; el selector *Elegir otro estilo* por módulo (hoy solo existen *Automática* e *Igual al estilo global*); vista previa en vivo; las propiedades nuevas del tema (esmerilado, retícula, borde, sombra, fondo) con valor por omisión que deja el Futurista intacto | UX/UI 4 |
| Fuentes | Manrope (B), DM Sans (C), Space Grotesk (D, con IBM Plex Mono), Plus Jakarta Sans (E), Anton (F) e Inter (lectura y teléfono), **incluidas en el proyecto** con licencia libre (SIL OFL), solo los caracteres que la app usa (latín con acentos, ñ, ¿ ¡ y $); nada se descarga al usar la app | UX/UI 18 |
| Personalidad | Aplicar la tabla de la sección 5 del diseño a **todos** los módulos y submódulos que ya existen (GRAVITY, Finanzas, los cinco submódulos de Hábitos, Desarrollador) y dejar **definidas y probadas** las de Cuidados y Alimentación/Casa para cuando lleguen sus fases | UX/UI 5 |
| Gadgets | Catálogo visible en *Ajustes › Apariencia › Gadgets* (laptop) con datos de ejemplo en el estilo activo; los gadgets que faltan (sección 5.2) | UX/UI 6 |
| Pantallas | Auditoría y ajuste de la pantalla principal de GRAVITY (laptop), **Hoy** (teléfono) y el modo Casa (General), **todas las pantallas de Finanzas** (fases 1 y 2) y **todas las de Hábitos** (fase 3) con los seis estilos y las dos versiones (sección 6) | UX/UI 7 a 9, 13 |
| Lo que estorba | Los pendientes de interfaz que la sección 2.3 marca **Entra** | ROADMAP 11.4 |
| Rendimiento | Las tres metas y su medición en el A52 y en la laptop; presupuesto de cuadros y de tamaño (sección 7) | ROADMAP 7 |
| Accesibilidad | Matriz de pruebas por estilo, pantallas y tamaño de letra (sección 8) | UX/UI 20 |
| Privacidad en pantalla | Bloqueo de capturas en Windows; los estilos no filtran lo oculto; vista previa solo con datos de ejemplo (sección 9) | UX/UI 21 |
| De "después" | Lo urgente que el dueño indique (pregunta P9). Propuesta: la sección 2.4 | ROADMAP 7 |

### 2.2 Queda fuera (y a dónde va)

| Queda fuera | Va a |
|---|---|
| Pantallas **funcionales** de Cuidados, Alimentación y Casa; sus gadgets conectados a datos | Fases 5, 6 y 7. Aquí solo los componentes visuales con datos de ejemplo (sección 5.2) y las reglas de personalidad ya probadas |
| Entrenamiento, bici y música, inglés y modo traslado de Hábitos (pantallas y lógica) | Fase 8+ (Hábitos). La personalidad *sport* y *lúdica* se define y se prueba con componentes de muestra; no se construyen las pantallas |
| Reloj Wear OS y app propia de la pulsera | Ampliaciones (D15, nivel 2). La pulsera sigue en el nivel 1: solo avisos |
| App Android con widgets de pantalla de inicio | Fase 8+ |
| Atajos de teclado editables (UX/UI 15) | Después, salvo que el dueño lo pida (P9) |
| Hitos de **salud** de Hábitos (qué mejora el cuerpo y cuándo) y línea de ayuda | Cuando el dueño dé la fuente oficial y verifique la línea (fase 3, P16) |
| Texto de RVR1909 y KJV | El dueño entrega los archivos (fase 3, P10); la interfaz del lector se termina con texto ficticio de prueba |
| Voces, IA, conversación de GRAVITY, control de la laptop, puente de casa | Fase 6 |
| Cuenta maestra que también edita; vigencias de un ingreso; consulta registrada en el historial de GRAVITY | Decisiones del dueño / Fase 6 |
| Cualquier análisis de dinero o de salud con IA en la nube | **Nunca** (D3, D13) |
| Un editor de estilos propio (que el usuario cree colores a su gusto) | Ampliaciones; la arquitectura lo permite pero no se ofrece |

### 2.3 Lo que estorba: lista de pendientes de interfaz y su decisión

Sale de `docs/revisiones/fase-1.md`, `fase-1b.md`, `fase-2.md` y `fase-3.md`, de las secciones "Pendiente de interfaz" de las especificaciones de las fases 2 y 3 y de la fila "Siguiente ronda" del ROADMAP (11.4). **Prioridad:** A = estorba cada día o frena el uso con la familia; B = estorba de vez en cuando; C = pulido. **Decisión (propuesta):** *Entra* o *Después*.

| # | Pendiente | Origen | Prio. | Decisión | Agente | Nota |
|---|---|---|---|---|---|---|
| E1 | **Indicador "En línea" con conectividad real** (hoy `enLinea` vale `true` fijo en `resumen_gravity.dart`); estados: En línea, Sin conexión, Sincronizando y "N por subir" (bandeja), con texto e icono | ROADMAP 11.4 | A | **Entra** | plataforma (proveedor) + diseno (indicador) | Una pantalla que dice "en línea" sin estarlo es peor que no decir nada |
| E2 | **Cifras reales de Finanzas en "Hoy"** (laptop y teléfono): conectar `finanzas.resumen_semana` al resumen de GRAVITY, por libro y por rol | ROADMAP 11.4; fase 2, 5.6 | A | **Entra** | plataforma (proveedor) + finanzas + diseno | Las consultas locales ya existen (fase 2, sección 11); falta el conector |
| E3 | **Pantalla "Tengo una invitación"** y *Ajustes › Personas* con el esquema del servidor (dar de baja, cambiar de rol; ahí se conecta `refrescarFinanzas`) | ROADMAP 11.4; fase 1b | A | **Entra** | plataforma + diseno | Sin ella no se puede dar de alta a la pareja ni a la familia con datos reales (F6 del diseño) |
| E4 | **Editar bloques de agenda y objetivos** (hoy solo se crean) | Fase 3, interfaz | A | **Entra** | habitos | Hay que borrar y rehacer para corregir un error; con deshacer y sin romper rachas |
| E5 | **Doble PIN en "Mis datos de Hábitos"** (la puerta reservada y la acción piden el PIN cada una) | Fase 3, F3-15 | A | **Entra** | plataforma + habitos | Una sola verificación vigente 2 minutos por pantalla reservada |
| E6 | **Chip "Cuenta nueva"** siempre visible en la hoja (+) Gasto, aunque ya haya cuentas; estorba al flujo de menos de 10 s | Fase 1, decisiones ("como está") | B | **Entra** | finanzas | Se vuelve un "+ Cuenta" al final de la lista (48 dp); solo destacado si el libro no tiene cuentas |
| E7 | **Flujo de activar la nube cifrada** de Hábitos: frase de 12 palabras, confirmación de 3 palabras, `hab_guardar_llave`, `hab_cambiar_modo`, volver a "solo teléfono", añadir la laptop con la frase, "Reiniciar la nube" y detectar `epoca_nube` | Fase 3, criterios 36 y 43; D21 | B | **Entra, al final y apagado por omisión** (P5) | plataforma + habitos + diseno | El servidor está listo y probado. El dueño decidió "solo teléfono por ahora"; la pantalla se construye para no dejar la función a medias, pero no cambia el modo por omisión |
| E8 | **Subrayados y notas en el lector** (6 colores sin texto; notas cifradas y sensibles) | Fase 3, interfaz | B | **Entra** | habitos + diseno | Se termina y se prueba con un texto ficticio; el texto real depende del dueño |
| E9 | **Motivos, disparadores, reemplazos y listas de azúcar** en la configuración de hábitos a eliminar | Fase 3, interfaz | B | **Entra** | habitos + diseno | Los motivos aparecen en el SOS; son datos sensibles (cifrados) |
| E10 | **Hitos de constancia en el panel** (cigarrillo 1, 3, 7, 14, 30, 60, 90, 180 y 365 días; azúcar 3, 7, 14 y 30), "visto" una sola vez | Fase 3, interfaz | B | **Entra** | habitos + diseno | Solo constancia; los de salud quedan fuera (sección 2.2) |
| E11 | **Recordatorio de dar** opcional (apagado; día y hora; texto genérico "Recordatorio", sin montos) | Fase 3, interfaz | C | **Entra** | habitos | Hábitos no maneja dinero |
| E12 | **Aviso de la revisión semanal en el teléfono** con versión corta | Fase 3, interfaz | C | **Entra** | habitos + diseno | |
| E13 | **Preferencias de avisos de Finanzas** en *Ajustes › Notificaciones* | Fase 2, sección 11 | B | **Entra** | plataforma + finanzas | Hoy los tipos, días antes y silencio no se editan en pantalla |
| E14 | **PIN fuera del hilo de la pantalla** (`Isolate`) y medición en el A52 (≥ 600 000 vueltas o Argon2) | Fase 1b, M9'; fase 3 | A | **Entra** (como meta de rendimiento, sección 7.4) | plataforma | Con más vueltas la entrada no puede congelar la pantalla |
| E15 | **Bloqueo de capturas y miniaturas en Windows** (`SetWindowDisplayAffinity`) | Fase 1b, W1 | B | **Entra** (P7) | plataforma | FLAG_SECURE ya cubre Android |
| E16 | **Conectar redondeo, sobrante, sobre y extras al cierre de semana**; emitir avisos de la app con `fin_emitir_aviso` | Fase 2, actualización 1/nov | B | **Entra** | finanzas | Completa la fase 2; sin ello el ahorro "propone" menos de lo que el diseño promete |
| E17 | **Pruebas de pantalla pendientes** de la alerta de flujo en Semana y de la alerta roja del abono bajo el mínimo (criterios 3 y 6 de la fase 1), y letra 2.0 en 360 y 900 dp de las vistas de la fase 2 | Fase 1 y 2 (calidad) | B | **Entra** | calidad + finanzas | Hoy ni siquiera aparece la tarjeta de alerta con los datos de ejemplo |
| E18 | **Mensaje del texto bíblico ausente**: el lector vacío dice qué falta y a quién avisar, con el diseño del estilo activo | Fase 3, criterio 29 | C | **Entra** | habitos + diseno | |
| E19 | Bandeja de avisos **acotada** (paginada) antes de la Fase 5 | ROADMAP 11.4 | C | **Después (Fase 5)** | plataforma | Aún no hay volumen que lo justifique |
| E20 | Cómo cambia un ingreso (**vigencias**), si la cuenta maestra edita, limitar sus consultas repetidas | ROADMAP 11.4 | C | **Después** | dueño decide | No son de interfaz; esperan una respuesta |
| E21 | Consulta registrada de la maestra en el historial de GRAVITY | Fase 2, regla 52 | C | **Después (Fase 6)** | asistente | El historial no existe aún |
| E22 | Anotar `rechazado` en la Edge Function `enviar-avisos` para los 4xx; Deno real, `pg_net` y Vault | Fase 2 (calidad) | C | **Después** | backend / dueño | No es de interfaz; depende del Firebase del dueño |
| E23 | Lector de la ficha de deudas por posición de columna; hojas de beneficios | Fase 2 | C | **Después (Fase 8)** | finanzas | |
| E24 | Hitos de salud y línea de ayuda de Hábitos | Fase 3 | C | **Después** | dueño | Falta la fuente oficial |

**Cómo se acotan:** los **A** entran todos y son lo primero que se hace (etapa 3 de la sección 11). Si el tiempo aprieta, se recorta de abajo hacia arriba: E18, E12, E11, E7, E9. Ningún **A** se recorta.

### 2.4 Lo que se trae de "después" (propuesta)

1. **Componentes visuales** (sin datos reales) de los gadgets de Cuidados, bici, entrenamiento y Alimentación (sección 5.2), para dejar probado el alto contraste y la letra grande antes de las fases 5 a 8.
2. **Preferencias de avisos de Hábitos** en la misma pantalla que las de Finanzas (E13).
3. Cualquier otro que el dueño pida en P9; cada uno entra con su criterio de aceptación antes de empezar.

---

## 3. Convenciones propias de la Fase 4

Además de las de la sección 4 de la Fase 0:

1. **Las pantallas no usan colores, fuentes ni medidas fijas.** Todo sale de `ValoresDiseno` (por el tema). Una guardia automática (criterio 4) lo vigila.
2. **Un estilo es un juego de valores.** Agregar uno es agregar un archivo en `app/lib/diseno/estilos/` y registrarlo en el catálogo; si hace falta tocar una pantalla, el estilo está mal hecho.
3. **El tema es solo apariencia.** No decide qué datos se ven, a quién ni cuándo. Ningún código de estilo lee datos de módulos ni del usuario.
4. **Estilo y claro/oscuro se guardan por persona** en el dispositivo (preferencia no sensible). La tablet pública (Hogar) tiene el suyo; al entrar una persona con su PIN se aplica el de ella y al volver al modo Casa regresa el de Hogar *(interpretación; P3)*.
5. **Contraste:** texto 4.5:1 o más en todo estilo, versión y personalidad; texto grande (24 px o 19 px en negrita) y componentes (bordes de controles, iconos con significado) 3:1; **alto contraste = 7:1** *(propuesta; P6)*. Se calcula con `contraste.dart` sobre el color **real** de la superficie (en Glass, contra el peor fondo posible).
6. **Nada depende solo del color.** Semáforo, racha, avance y alertas llevan texto o icono además del color en todos los estilos.
7. **Reducir movimiento:** toda animación nueva (respiración de B, brillos de F, destellos de E, anillos, escaneo del cianotipo) se detiene con la opción del sistema; la información se conserva.
8. **Lo oculto se sustituye, no se difumina.** Un monto o un dato sensible oculto es **otro texto** (`••••`), nunca un desenfoque ni una opacidad sobre la cifra real, tampoco en Glass.
9. **Las fuentes viajan en el proyecto** (carpeta `app/assets/fonts/`, declaradas en `flutter:` de `pubspec.yaml`), con su archivo de licencia; no se usa `google_fonts` ni se pide nada a la red. Cada familia se registra en `licencias.dart`.
10. **Cifras de ancho fijo** en todo monto (UX/UI 18): si la fuente de números del estilo no trae cifras tabulares, el monto usa la fuente de números de respaldo (IBM Plex Mono o Inter con cifras tabulares) *(interpretación)*.
11. **Los datos de ejemplo de las vistas previas, los gadgets del catálogo y las capturas de prueba son ficticios** (el hogar de ejemplo de `seed.sql`). Ninguna prueba abre `data/personal/`.
12. **Medir antes de optimizar:** ninguna optimización de rendimiento se acepta sin la medición "antes y después" en el mismo equipo.
13. **Identificadores** en español sin acentos (`estiloGlass`, `OpcionPersonalidad.otroEstilo`); ids de estilo estables para guardar la preferencia: `futurista`, `minimalista`, `claro`, `glass`, `swagger`, `arquitectonico_cianotipo`, `arquitectonico_papel`.

---

## 4. Sistema de estilos

### 4.1 Lista de estilos y su orden

El orden va de **menor a mayor riesgo técnico**, para que cada paso valide el sistema antes del siguiente y el estilo más costoso no frene a los demás. **Puerta de aprobación:** al terminar cada estilo se muestran sus capturas (laptop, teléfono y tablet; día y noche) al dueño; si no le gusta, se ajusta antes de seguir.

| Orden | Estilo (id) | Fuentes | Cómo se ve (resumen del lienzo) | Dónde se ofrece | Lo delicado |
|---|---|---|---|---|---|
| 1 | **A · Futurista** (`futurista`), por defecto, **ya hecho** | Chakra Petch, IBM Plex | Noche: casi negro, líneas finas cian (#35d4f0), anillos que giran. Día: fondo claro, azul petróleo (#0a7f99) | Todos | Solo se revisa con la matriz de accesibilidad nueva; no se rehace |
| 2 | **B · Minimalista** (`minimalista`) | Manrope | Tarjetas redondeadas, mucho aire, círculo que "respira" | Todos | Cifras tabulares de Manrope (convención 10) |
| 3 | **C · Claro sereno** (`claro`) | DM Sans | Fondo claro, GRAVITY en una franja superior. En noche usa un gris cálido oscuro (no negro puro) | Todos | Es "para el día": su versión de noche debe ser digna, no un parche |
| 4 | **F · Swagger** (`swagger`) | Anton (números y títulos), Inter | Negro y blanco con un neón, letra condensada, etiquetas tipo sticker | Todos; es la base de la personalidad *sport* y del aspecto de *Ajustes › Desarrollador* (D16) | Contraste del neón sobre negro y sobre blanco; Anton solo en títulos y cifras grandes, nunca en párrafos |
| 5 | **E · Glass** (`glass`) | Plus Jakarta Sans | Paneles translúcidos y esmerilados sobre un fondo de color difuminado; noche y día | **Esmerilado completo solo en laptop y tablet.** En el teléfono, versión translúcida **sólida** sin `BackdropFilter` (UX/UI 4) | Contraste sobre fondo cambiante, rendimiento (sección 7.5), lo oculto no se difumina (convención 8) |
| 6 | **D · Arquitectónico** (`arquitectonico_cianotipo` y `arquitectonico_papel`) | Space Grotesk, IBM Plex Mono | Retícula de fondo, ejes con globos (A, B, C), cotas como barras de avance, cajetín con proyecto, plano, escala y usuario, flecha de norte | Laptop y tablet; en el teléfono sin retícula ni cajetín (versión simple) | Es el que más decora: la decoración se apaga sola donde el contraste o el espacio lo exigen (Cuidados, bici, letra grande) |

*Si hay que recortar, el Arquitectónico es el último en entrar (P1).*

Qué agrega cada estilo al tema: `ValoresDiseno` gana propiedades con valor por omisión neutro, para que el Futurista no cambie: `esmeriladoRadio` (0 = sin esmerilado), `translucidez`, `fondoDecorado` (degradado, retícula o nada), `grosorBorde`, `sombra`, `forma` (esquinas) y `etiquetaSticker`. La decoración que no es información (retícula, cajetín, brillo) se declara con `decoracion` y se apaga en alto contraste.

### 4.2 Claro / oscuro automático (capa 4)

1. **Por hora:** claro de 07:00 a 19:00, editable por persona; intervalo [inicio, fin). Alternativa *según el amanecer y el atardecer* **no entra** (necesita ubicación; P8).
2. Opciones fijas: *Automático por hora*, *Del sistema*, *Siempre claro*, *Siempre oscuro*.
3. **El cambio es suave** (fundido de hasta 300 ms; sin fundido con "reducir movimiento") y **nunca a mitad de una acción**: si hay una hoja, un formulario con datos, el teclado abierto o una sesión de bici/lectura en curso, el cambio **espera** a que se cierre y, si pasa más de 30 minutos, se aplica al siguiente cambio de pantalla.
4. **Excepciones por función** (ya existen; se prueban con los seis estilos): Cuidados siempre claro y de alto contraste y sin decoración; la bici siempre alto contraste (de día y de noche).
5. La hora la da el reloj del dispositivo en su zona; las pruebas usan un reloj falso.

### 4.3 Personalidad por módulo (capa 3)

Se aplica la tabla de la sección 5 del diseño. Cada personalidad solo **sustituye** acento, densidad, ritmo de animación, escala de lectura, fuente de números y banderas de contraste; nunca estructura.

| Módulo / submódulo | Personalidad | Qué se verifica |
|---|---|---|
| GRAVITY | Asistente | El estilo completo, núcleo animado |
| Finanzas | Precisa y serena | Acento índigo, cifras de ancho fijo, poca animación |
| Hábitos · Espiritual | Contemplativa | Acento violeta, letra de lectura mayor, sin animación |
| Hábitos · Entrenamiento y bici | Sport (base: Swagger) | Neón, números enormes, alto contraste (probado con los seis estilos) |
| Hábitos · Inglés | Lúdica | Acento naranja, progreso por niveles |
| Hábitos a eliminar | Empática | Terracota (**nunca rojo de alarma**), contador grande, SOS siempre visible |
| Cuidados | Clara y cálida | Rosa oscuro, letra y botones grandes, alto contraste, sin decoración (probada; la pantalla llega en la Fase 5) |
| Alimentación / Casa | Cálida y práctica | Ámbar, letra grande para cocinar (probada; la pantalla llega en la Fase 7) |
| Ajustes › Desarrollador | Técnica | Estilo Swagger UI con los colores del estilo activo |

**Hábitos conserva sus colores por área** (violeta, verde, naranja, azul verdoso, gris azulado y terracota); en todo estilo, cada color de área como **texto** debe pasar 4.5:1 sobre la superficie, usando una variante de texto del acento si hace falta (sin cambiar el matiz que reconoce la persona).

En *Ajustes › Apariencia*, cada módulo tiene tres opciones: **Automática**, **Igual al estilo global** y **Elegir otro estilo** (lista de los seis, con vista previa). Se guarda por persona. Las excepciones por función (Cuidados, bici) **no se pueden apagar**.

---

## 5. Gadgets

### 5.1 Reglas

Cada gadget responde una pregunta (UX/UI 6), toma el estilo activo y la personalidad de su módulo, y trae: tamaño compacto y amplio, estados vacío, cargando, sin conexión y error, versión con montos ocultos (si lleva dinero) y descripción para el lector de pantalla con **palabras** ("Espiritual, 2 de 3 hechos"), no solo números. En teléfono, tablet y reloj gana el gadget; en la laptop, la tabla completa.

### 5.2 Catálogo

| Gadget | Módulo | Estado | Fase 4 |
|---|---|---|---|
| Medidor de presupuesto, Cascada, Escalera del fondo, Barra de límite, Tarjeta de deuda, Línea de vencimientos, Bolsa de ahorro, Orden de pago | Finanzas | Hechos (fases 1 y 2) | Se prueban con los seis estilos; Cascada y Medidor ganan su versión "Swagger" (cifras grandes) |
| Anillos del día, Medidor de carga, Contador de días libres + SOS, Calendario de constancia, Chip de racha | Hábitos | Hechos (fase 3) | Se prueban con los seis estilos y las personalidades; **hitos de constancia** (E10) |
| Núcleo de GRAVITY | GRAVITY | Hecho (anillos) | Se agregan **dos variantes** del núcleo por estilo: la propia de cada estilo (B respira, E flota, D es un plano con cotas, F pulsa) *(interpretación; el diseño solo dice "más opciones después", D12)* |
| **Velocímetro y cronómetro** | Bici | **Nuevo, solo visual** | Números enormes, alto contraste, sin información que obligue a leer en movimiento. Datos de ejemplo; se conecta en la Fase 8 |
| **Serie y descanso** | Entrenamiento | **Nuevo, solo visual** | Idem; para la tablet en Gimnasio |
| **Reloj del turno** | Cuidados | **Nuevo, solo visual** | Siempre alto contraste, claro y sin decoración; textos impersonales ("¿Cómo comió?") |
| **Menú y lista de compras** | Alimentación / Casa | **Nuevo, solo visual** | Letra grande para cocinar; sin precios ni dinero |
| **Indicador de conexión** | GRAVITY | **Nuevo** (E1) | Texto + icono; estados de la sección 2.3 |

Los cuatro gadgets "solo visual" **no llevan lógica**, ni lectura de bases, ni rutas; viven en `app/lib/diseno/gadgets/` con un `ejemplo()` para el catálogo. Si el dueño prefiere esperar a cada fase, se recortan sin costo (P4).

---

## 6. Pantallas a las que se aplica el sistema

"Aplicar" significa: la pantalla se ve bien y cumple la accesibilidad con **los seis estilos, día y noche**, en teléfono (360 dp), laptop (900 dp y 1366 dp) y, donde existe, tablet; usa solo valores del tema; y muestra los estados vacío, cargando, sin conexión y error.

| Área | Pantallas | Dueño de la pantalla |
|---|---|---|
| **GRAVITY** | Pantalla principal de la laptop (paneles, núcleo, barra de órdenes, barra de módulos, modo privado, indicador de conexión), **Hoy** del teléfono, modo Casa de la tablet (General) | diseno |
| **Ajustes** | Apariencia (estilo, claro/oscuro, personalidad por módulo, catálogo de gadgets, vista previa), Desarrollador (colores del estilo), Notificaciones, Personas, Privacidad | diseno (Apariencia), plataforma (el resto) |
| **Finanzas** | Tablero, Semana, Movimientos, Cuentas, Ingresos, Gastos y categorías, Importar, Deudas (con Orden de pago y Calendario), Ahorro, Bandeja de avisos, hojas (+) Gasto e Ingreso extra, Registrar pago, selector de libro; teléfono: Pagos, Ahorro, Hoy | finanzas (con los componentes de diseno) |
| **Hábitos** | Hoy, Agenda, Objetivos y su asistente, hábitos a eliminar (panel, registro, SOS), Espiritual (lector, planes, devocional, oración), Progreso, Revisión semanal, asistente de configuración, Mis datos | habitos (con los componentes de diseno) |

**Cómo se hace sin pisar carpetas:** diseno entrega la guardia (criterio 4), los componentes y el informe de lo que se rompe por pantalla; los arreglos dentro de `app/lib/modulos/finanzas`, `habitos` o `ajustes` los hace su agente (sección 11). Lo que diseno ve mal y no puede arreglar lo pide en su reporte.

---

## 7. Metas de rendimiento y cómo se miden

**Equipos:** el **Galaxy A52** del dueño (compilación `--release`, sin depurador, batería no en ahorro, sesión ya iniciada) y la **laptop Windows** del dueño (compilación `--release`). Si no se dispone del equipo, la medición se declara **no hecha**; el criterio queda "Manual pendiente" y no se da por cumplido con un emulador.

**Datos de prueba:** un hogar ficticio con **un año de datos** (52 semanas cerradas, unos 3 000 movimientos en 3 libros, 12 deudas, 4 bolsas; Hábitos con 365 días de registro en 8 objetivos, 2 hábitos a eliminar con sensibles cifrados). Lo genera una función de prueba (`app/test/rendimiento/datos_un_ano.dart`, **calidad**), con una opción para cargarlo en el repositorio en memoria del equipo real desde *Ajustes › Desarrollador* (laptop). Nada real.

### 7.1 Abrir la app en menos de 2 s

- **Definición:** desde el toque del icono (o el doble clic en Windows) con la app **cerrada** (arranque en frío) hasta que **Hoy** (teléfono) o la **pantalla principal** (laptop) muestran su primer contenido útil: encabezado, el gadget de la semana con datos y los hábitos de hoy. La pantalla de arranque no cuenta como "lista".
- **Meta:** mediana de 10 corridas **≤ 2.0 s** y peor corrida **≤ 3.0 s**, con un año de datos, con señal y sin señal. Lo mismo en la laptop.
- **Medición en el A52:** `adb shell am force-stop <paquete>`; luego `adb shell am start -W -n <paquete>/.MainActivity` (campo `TotalTime`) **más** la marca interna de "primera pantalla útil"; 10 corridas, se anota mediana y peor. Además `flutter run --profile --trace-startup` (genera `start_up_info.json` con `timeToFirstFrameMicros`).
- **Medición en la laptop:** el mismo `--trace-startup` en `--release` y cronómetro de pantalla (grabación de video a 60 fps, cuadro a cuadro) en 5 corridas.
- **Marca interna (plataforma):** un `MedidorArranque` local (nunca se envía a ninguna parte) anota la hora de `main()` y la de "primera pantalla útil" y la muestra en *Ajustes › Desarrollador › Rendimiento* (laptop, rol Dueño).
- **Qué ayuda a cumplirla (guía, no obligación):** primer cuadro con el esqueleto del estilo activo sin esperar a los datos; el estilo y el modo claro/oscuro leídos de preferencias locales antes del primer cuadro (sin parpadeo del estilo por omisión); fuentes empaquetadas (nada de red); la sincronización y la reprogramación de recordatorios **después** de la primera pantalla; los gadgets cargan sus datos de forma diferida y solo los visibles.

### 7.2 Registrar un gasto en menos de 10 s

- **Definición:** el flujo F1 del diseño, desde la pestaña **Hoy** con la app abierta y desbloqueada hasta el aviso *"Guardado · Deshacer"*: (+) → Gasto → monto → categoría (la última, preseleccionada) → cuenta (la última) → Guardar. Con y sin señal.
- **Meta:** mediana de 10 repeticiones **≤ 10 s** y peor **≤ 15 s** en el A52, con una mano. En la laptop: **Ctrl+N → monto → Enter** en **≤ 10 s** (peor ≤ 15 s). Con los seis estilos (el estilo no puede alargar el flujo: se mide con Futurista y con Swagger, el de números más grandes).
- **Toques (prueba automática):** como máximo **3 toques fijos** (el (+), *Gasto* y *Guardar*) más las pulsaciones del monto, con el teclado numérico ya abierto, la categoría y la cuenta preseleccionadas, y **Guardar visible sin desplazar la hoja** (corrección I8 de la fase 1) con letra 1.0 y 1.3.
- **Medición manual:** dos personas (dueño y pareja), cronómetro en mano o video, 10 repeticiones cada una; se anota mediana y peor. En la tablet pública, el flujo con nombre y PIN queda aparte (no entra en la meta).

### 7.3 Acción diaria de Hábitos en 3 toques o menos

- **Cuenta de toques:** cada pulsación en pantalla desde que la app está **abierta y desbloqueada en la pestaña Hoy** (el icono de la app y la huella cuentan aparte: el icono es 1; la huella o el PIN no cuentan como toques).
- **Meta (todas con prueba automática de pasos):**
  - Marcar un hábito: *Hecho* = **1 toque** (o deslizar).
  - Posponer u omitir: **≤ 2 toques**.
  - Hábito con cantidad (agua, páginas): *Hecho* → cantidad → confirmar = **≤ 3 toques**.
  - Registrar un consumo (cigarrillo o azúcar): **(+) → el hábito = 2 toques**; **SOS: 1 toque** desde Hoy.
  - Desde el aviso del teléfono: *Hecho* en la propia notificación = **1 toque**, sin abrir la app y sin dato sensible (D21).
- **Medición manual en el A52:** abrir la app desde el icono y marcar un hábito: **≤ 3 toques** y **≤ 6 s**, 10 repeticiones.

### 7.4 Metas complementarias

| Meta | Valor | Cómo se mide |
|---|---|---|
| Entrar con PIN sin congelar la pantalla (E14) | Ningún cuadro mayor a 100 ms durante la derivación; entrada **≤ 1.5 s** en el A52 con las vueltas que se decidan (P10) | `Timeline` en `--profile` en el A52 + prueba de que la derivación corre en un `Isolate` |
| Cambiar de estilo | **≤ 300 ms** en la laptop y **≤ 500 ms** en el A52 hasta que la pantalla actual se ve con el estilo nuevo; sin perder el estado (desplazamiento, texto escrito) | `Timeline` en `--profile`; prueba de widget que mide cuadros |
| Cuadros lentos al usar Hoy (desplazar 30 s, cambiar de pestaña) con Futurista de noche | ≤ 5 % de cuadros > 16.7 ms en la laptop; ≤ 10 % en el A52 | `flutter run --profile` + DevTools (Performance); resumen de cuadros |
| Núcleo animado y respiración | Con la pantalla principal abierta 60 s, el uso de CPU del proceso no pasa de 15 % en la laptop; con "reducir movimiento" la animación se detiene y el CPU baja a casi cero | Administrador de tareas / `adb shell dumpsys cpuinfo` |
| Tamaño | Las fuentes nuevas pesan **≤ 3 MB en total** (subconjunto); el APK `--release` no crece más de **5 MB** por esta fase respecto al cierre de la Fase 3 | `flutter build apk --analyze-size`; suma de `assets/fonts` |

### 7.5 Glass

El esmerilado cuesta. En la laptop y la tablet se limita a **un máximo de 3 capas esmeriladas visibles** a la vez y se apaga solo si la medición de cuadros baja de 45 por segundo durante 5 s (queda la versión translúcida sólida y un aviso en *Apariencia*). En el teléfono nunca se usa `BackdropFilter`.

---

## 8. Accesibilidad

Reglas de `DISENO_UX_UI.md` sección 20, medidas con una **matriz**: pantallas clave × 6 estilos (7 contando las dos variantes del Arquitectónico) × día y noche.

1. **Zonas táctiles de 48 dp o más** y etiquetas en todo lo tocable (`androidTapTargetGuideline`, `labeledTapTargetGuideline`). Las acciones principales al alcance del pulgar.
2. **Contraste** (`textContrastGuideline` y la tabla de contraste de `contraste.dart`): texto 4.5:1; componentes 3:1; alto contraste 7:1. También el **foco del teclado** en la laptop (anillo de foco visible a 3:1, orden de tabulación lógico).
3. **Lector de pantalla (TalkBack en el A52, Narrator en la laptop):** cada gadget y cada fila anuncian **nombre, valor y estado** en palabras; las filas de Hoy anuncian pendiente o hecho y se pueden activar (F3-12, ya corregido, se vuelve prueba permanente); los montos ocultos dicen "Monto oculto" sin cifra; los semáforos dicen su estado; el orden de lectura sigue el orden visual; las decoraciones (retícula, cajetín, brillos) están **excluidas** del árbol semántico.
4. **Letra al doble (2.0) sin cortes:** teléfono a **360 dp** y laptop desde **900 dp**, con los seis estilos (Anton es angosta y Plus Jakarta es ancha: se prueban ambas). Sin desbordes (`RenderFlex overflowed` es fallo), sin texto de acción cortado, el botón principal visible o alcanzable desplazando, y con letra grande las tres columnas de la pantalla principal se apilan.
5. **Nada depende solo del color:** semáforo, racha, avance, alertas, niveles de alerta y estados del indicador de conexión llevan texto o icono. Prueba: cada gadget con color de estado trae una etiqueta de texto o un icono distinto por estado. Revisión manual en escala de grises y con simulación de daltonismo en una pantalla de cada módulo.
6. **Reducir movimiento:** probado con `disableAnimations` en cada estilo (convención 7).
7. **Alto contraste por función:** Cuidados (claro, 7:1, sin decoración) y bici (7:1, de día y de noche) pasan la matriz con los seis estilos; el estilo no puede bajar el contraste (UX/UI 20): si un estilo no lo cumple en un módulo, ese módulo usa su variante de alto contraste.
8. **Cuidador:** letra grande por defecto (propuesta del diseño); se verifica con el componente "Reloj del turno".
9. **Seguro al manejar o en la bici:** las pantallas en movimiento no piden leer; botones enormes; sin información que solo aparezca en pantalla.

---

## 9. D3, D13 y D14 en la interfaz

Esta fase toca lo que se ve; por eso el cuidado es de **qué se ve y dónde queda**.

1. **Capturas (D3, D13):**
   - Android: `FLAG_SECURE` ya cubre `/finanzas/*`, la bandeja de avisos y las pantallas reservadas de Hábitos (fases 1b y 3); las pantallas **nuevas** de esta fase quedan cubiertas por la misma regla de rutas (criterio 49). El vistazo reciente del sistema no muestra dinero ni datos sensibles.
   - Windows (E15): `SetWindowDisplayAffinity` con `WDA_EXCLUDEFROMCAPTURE` mientras la ruta sea sensible (Finanzas, Hábitos reservado, Cuidados); capturas y miniaturas de la barra de tareas salen negras. No protege contra una foto con otro aparato: se dice en *Ajustes › Privacidad*.
   - **Las capturas que genera el proyecto** (pruebas doradas, cuadros del lienzo, vistas previas) usan **solo datos ficticios**; una guardia revisa que las pruebas doradas no importen nada de `data/personal/`.
2. **Lo oculto no se difumina (convención 8):** con el modo privado, los montos ocultos automáticos o la puerta reservada, la cifra **no está en el árbol** (ni visual ni semántico) en ninguno de los seis estilos, Glass incluido. Prueba por estilo.
3. **Avisos (D3, D20):** la *vista previa de aviso* de *Ajustes › Notificaciones* usa solo los títulos del catálogo cerrado (sin dígitos, sin "$", sin nombres, máximo 40 caracteres). El estilo no cambia el texto de ningún aviso ni agrega cuerpo. La pulsera sigue en el nivel 1, sin montos.
4. **IA (D3, D13):** ninguna captura, valor de tema, medición de rendimiento ni prueba de accesibilidad se envía a la IA en la nube ni a servicios externos. El `MedidorArranque` es local. Sin paquetes de analítica ni de reporte de fallas con pantallas. La guardia de D3 de la Fase 1 se amplía para vigilar `app/lib/diseno`.
5. **Tablet pública (D14):** en modo Casa, **ningún estilo ni contexto** muestra dinero ni datos clínicos ni nada de Hábitos; los gadgets de Finanzas y Hábitos no están disponibles en el catálogo de la tablet pública. Prueba: se monta el modo Casa con los seis estilos y no aparece ningún `MontoOcultable`, gadget de Finanzas ni de Hábitos. Cambiar de usuario aplica el estilo de la persona **solo después del PIN**, y al volver al modo Casa (2 minutos) regresa al de Hogar. Los nombres de las personas que aparecen en el selector son los permitidos, no más.
6. **Hábitos sensibles (D13, D21):** en las personalidades contemplativa y empática, el diario, las peticiones, las notas del lector, los motivos y los consumos se muestran solo con la llave y detrás de la puerta reservada; en Glass, un panel translúcido **nunca** deja ver contenido reservado detrás (la puerta cubre con un fondo opaco). La *vista previa* del estilo en *Apariencia* no incluye Hábitos reservado.
7. **Recordatorios:** el estilo no cambia los avisos locales (título "Recordatorio", cuerpo vacío para lo sensible, sin acciones que escriban desde la pantalla bloqueada).
8. **Sin secretos ni datos reales en el repositorio.** Las fuentes llevan su licencia; ninguna fuente tiene datos de uso.
9. **El dueño ve el catálogo de gadgets y la vista previa con datos de ejemplo**, nunca con sus datos, por si alguien mira la pantalla o se captura.

---

## 10. Criterios de aceptación

Pruebas de diseño en `app/test/diseno/` (`flutter test`); de rendimiento en `app/test/rendimiento/`; de accesibilidad en `app/test/accesibilidad/`; las doradas en `app/test/diseno/doradas/`. Lo que necesita un equipo real se marca **Manual** y lo mide calidad con el dueño.

### 10.1 Sistema de estilos

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 1 | **Fases anteriores intactas:** las suites de las fases 0 a 3 (dominio, app, SQL, respaldo, APIs) siguen en verde y `flutter analyze` sin problemas | Suites existentes |
| 2 | **Catálogo:** `estilosIncluidos` trae los seis estilos (el Arquitectónico con sus dos variantes), cada uno con versión de día y de noche; el por omisión sigue siendo Futurista; un id desconocido regresa el Futurista | `catalogo_test.dart` |
| 3 | **Cambio sin reiniciar:** con una pantalla montada, elegir otro estilo cambia colores, fuentes y formas en el mismo cuadro y **conserva el estado** (desplazamiento, texto escrito en un formulario, hoja abierta); la preferencia se guarda por persona y se recupera al reabrir | `cambio_estilo_test.dart` |
| 4 | **Sin valores fijos:** ningún archivo de `app/lib/modulos/**` ni de `app/lib/diseno/{componentes,gadgets,habitos}` usa `Color(0x…)`, `Colors.*` (salvo `transparent`) ni `fontFamily`/`TextStyle` con fuente literal; la lista de excepciones es corta, nombrada y con su razón | `guardia_sin_colores_fijos_test.dart` |
| 5 | **Agregar un estilo no toca pantallas:** se registra un estilo falso en un catálogo de prueba y se montan, sin ningún cambio de código, la pantalla principal, Hoy, el Tablero de Finanzas y Hoy de Hábitos | `estilo_nuevo_test.dart` |
| 6 | **Contraste de los valores de diseño:** para cada estilo y versión se calculan los pares texto/fondo, texto/panel, texto fuerte/panel, texto tenue/panel, etiqueta/panel y `sobreAcento`/acento: todos ≥ 4.5:1; borde y acento como componente ≥ 3:1; estados éxito/alerta/peligro como texto ≥ 4.5:1 | `contraste_valores_test.dart` |
| 7 | **Contraste con personalidad:** para cada estilo × cada personalidad (Finanzas índigo, las seis áreas de Hábitos, Cuidados rosa oscuro, Alimentación ámbar, sport) el acento usado como **texto** pasa 4.5:1 sobre la superficie real; si no, se usa la variante de texto del acento | `contraste_personalidad_test.dart` |
| 8 | **Glass, peor caso:** el texto sobre un panel Glass pasa 4.5:1 contra los dos extremos del fondo difuminado (el más claro y el más oscuro posibles); en el teléfono no hay `BackdropFilter` en ninguna pantalla | `contraste_glass_test.dart` |
| 9 | **Alto contraste por función:** Cuidados (siempre claro, sin decoración, 7:1) y bici (7:1 de día y de noche) con los seis estilos; el usuario no puede apagar la excepción | `alto_contraste_test.dart` |
| 10 | **Claro/oscuro por hora:** con reloj falso, 06:59 es oscuro y 07:00 claro; 18:59 claro y 19:00 oscuro; un horario editable (p. ej. 06:30 a 18:00) y uno que cruza la medianoche; el modo *Del sistema* y los fijos; el cambio **espera** si hay hoja, formulario con datos, teclado o sesión en curso y se aplica al cerrarlos | `modo_claro_oscuro_test.dart` (ampliada) |
| 11 | **Reducir movimiento:** con `disableAnimations`, ninguna animación de los seis estilos ni de los gadgets sigue corriendo (`pumpAndSettle` termina) y la información se conserva | `reducir_movimiento_test.dart` |
| 12 | **Fuentes:** todas las familias del catálogo están en `assets/fonts/` y declaradas en `pubspec.yaml`, cada una con su licencia en `licencias.dart`; no hay `google_fonts` ni acceso a la red; suman ≤ 3 MB; los caracteres `á é í ó ú ñ ü ¿ ¡ $ %` se dibujan (no hay cuadros vacíos) | `fuentes_test.dart` |
| 13 | **Cifras de ancho fijo:** los dígitos 0 al 9 de cada fuente de números usada en montos miden lo mismo (o el monto usa la fuente de respaldo) | `cifras_tabulares_test.dart` |
| 14 | **Variantes del Arquitectónico:** cianotipo y papel existen, con día y noche; la decoración (retícula, cajetín, flecha de norte) se apaga en alto contraste y con letra a 2.0; en el teléfono no hay cajetín | `arquitectonico_test.dart` |
| 15 | **Desarrollador:** *Ajustes › Desarrollador* toma los colores del estilo activo con la personalidad técnica; solo laptop y rol Dueño (como en D16) | `desarrollador_estilo_test.dart` + prueba de rutas de plataforma |
| 16 | **Aprobación visual:** capturas doradas de la pantalla principal (laptop), Hoy (teléfono), Tablero de Finanzas y Hoy de Hábitos × 6 estilos × día y noche coinciden con las aprobadas; el dueño aprobó cada estilo al terminarlo | `doradas_test.dart` + aprobación del dueño (Manual) |

### 10.2 Personalidad y gadgets

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 17 | **Tabla de personalidad:** cada módulo y submódulo de la sección 4.3 toma su acento, densidad, ritmo y escala; Hábitos conserva sus colores por área; el terracota nunca es rojo de alarma y no hay rojo de alerta en hábitos a eliminar | `personalidad_test.dart` |
| 18 | **Tres opciones por módulo:** *Automática*, *Igual al estilo global* y *Elegir otro estilo* funcionan, se guardan por persona y no apagan las excepciones por función | `ajustes_apariencia_test.dart` |
| 19 | **Una personalidad por pantalla:** en una pantalla de un módulo solo hay un acento de módulo más el semáforo (Hoy de GRAVITY, que junta módulos, usa el acento de cada tarjeta dentro de ella) | Revisión visual del dueño (Manual) + `personalidad_test.dart` |
| 20 | **Catálogo de gadgets:** *Ajustes › Apariencia › Gadgets* muestra cada gadget con datos ficticios en el estilo activo, en tamaño compacto y amplio; todos pasan la matriz de accesibilidad | `catalogo_gadgets_test.dart` |
| 21 | **Gadgets nuevos solo visuales:** Velocímetro y cronómetro, Serie y descanso, Reloj del turno y Menú y lista de compras no importan ningún módulo ni base de datos ni tienen rutas; pasan 48 dp, contraste, letra 2.0 y lector; Reloj del turno y Velocímetro se ven igual de legibles en los seis estilos | `gadgets_visuales_test.dart` |
| 22 | **Gadgets con estados:** cada gadget tiene vacío, cargando, sin conexión y error; los de dinero, versión con montos ocultos sin cifra en el árbol | `estados_gadgets_test.dart` |
| 23 | **Anillos y núcleo:** los anillos del día dicen su valor en palabras; el núcleo tiene una variante por estilo y se detiene con reducir movimiento | `nucleo_test.dart` |

### 10.3 Pantallas y lo que estorba

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 24 | **Pantallas con los seis estilos:** las pantallas de la sección 6 se montan con los seis estilos, día y noche, en 360 dp, 900 dp y 1366 dp sin desbordes, con sus cuatro estados | `matriz_pantallas_test.dart` |
| 25 | **E1, indicador real:** el indicador refleja la conectividad del equipo y la bandeja ("3 por subir"), con texto e icono; sin conexión dice "Sin conexión" y la app sigue funcionando | `indicador_conexion_test.dart` + prueba de plataforma |
| 26 | **E2, cifras reales en Hoy:** el dueño ve un renglón por libro con semáforo y porcentaje; el albacea además el de papá; la pareja no ve el libro personal del dueño; la maestra no ve cifras; familiar, cuidador y Casa no ven nada; funciona sin señal y respeta los montos ocultos | `hoy_finanzas_test.dart` + `finanzas_por_rol_test.dart` (criterio 51 de la fase 2) |
| 27 | **E3, invitación y personas:** "Tengo una invitación" acepta una invitación válida, rechaza una vencida o usada y no deja pasar a otro rol; *Personas* da de baja y cambia el rol, y la persona dada de baja pierde el acceso al instante y se actualizan sus libros | `invitacion_test.dart`, `personas_test.dart` + prueba SQL existente |
| 28 | **E4, editar:** un bloque de agenda y un objetivo se editan y se pueden deshacer; editar no rompe la racha ni el historial (el libro/registro de cumplimiento no cambia) | `editar_bloque_test.dart`, `editar_objetivo_test.dart` |
| 29 | **E5, un solo PIN:** en *Mis datos de Hábitos* se pide el PIN una vez por visita (vigente 2 minutos) y no dos; sin PIN no se ve nada; FLAG_SECURE y modo privado activos | `mis_datos_pin_test.dart` |
| 30 | **E6, chip de cuenta:** con cuentas existentes, "+ Cuenta" queda al final de la lista y no es el primer elemento enfocable; sin cuentas se destaca; Guardar sigue visible sin desplazar | `hoja_gasto_test.dart` |
| 31 | **E7, nube cifrada:** activar con frase de 12 palabras (se confirman 3 al azar; sin acentos y en mayúsculas se acepta), volver a "solo teléfono", reiniciar y añadir la laptop con la frase; el modo por omisión sigue siendo "solo teléfono"; nada sale hasta activarla; la frase nunca se guarda ni se registra | `nube_cifrada_flujo_test.dart` + `f3_cripto_test.dart` existente |
| 32 | **E8, lector:** subrayado de 6 colores y marcador (sin texto, en claro); notas cifradas y sensibles; cambiar de versión conserva todo por referencia; el texto ficticio de prueba basta; sin texto instalado el lector explica qué falta (E18) | `lector_marcas_test.dart` |
| 33 | **E9 a E12, Hábitos:** motivos, disparadores, reemplazos y listas de azúcar se editan y aparecen los motivos en el SOS; los hitos de constancia salen una sola vez y no hay hitos de salud; el recordatorio de dar está apagado por omisión, usa el texto genérico y no lleva montos; el aviso de la revisión semanal tiene versión corta | `configuracion_eliminar_test.dart`, `hitos_panel_test.dart`, `recordatorio_dar_test.dart`, `aviso_revision_test.dart` |
| 34 | **E13, preferencias de avisos:** días antes, horas silenciosas, críticas en silencio, tope diario y tipos silenciados se editan y se validan (tope de 0 a 10, horas coherentes); cada quien las suyas | `preferencias_avisos_test.dart` + prueba SQL existente |
| 35 | **E16, ahorro al cierre:** redondeo, sobrante, sobre por categoría y extras se descuentan de la aportación sugerida al armar el reparto y se confirman en la revisión semanal; confirmar dos veces no duplica; los avisos de la app se emiten por `fin_emitir_aviso` | `cierre_ahorro_test.dart` |
| 36 | **E17, pruebas pendientes:** la tarjeta de alerta de flujo aparece en Semana con datos que la provocan; el abono bajo el mínimo muestra la alerta roja; las vistas de la fase 2 pasan letra 2.0 a 360 y 900 dp | `semana_alerta_test.dart`, `deudas_alerta_test.dart`, `letra_grande_fase2_test.dart` |

### 10.4 Rendimiento

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 37 | **Abrir en menos de 2 s:** mediana ≤ 2.0 s y peor ≤ 3.0 s en 10 corridas en frío con un año de datos, en el A52 y en la laptop (sección 7.1) | **Manual** (calidad con el dueño) + `arranque_perfil_test.dart` que falla si la primera pantalla útil exige más de 10 cuadros de construcción o espera una consulta de red |
| 38 | **Registrar un gasto en menos de 10 s:** mediana ≤ 10 s y peor ≤ 15 s (A52, una mano); Ctrl+N → monto → Enter ≤ 10 s en la laptop; ≤ 3 toques fijos; Guardar visible sin desplazar con letra 1.0 y 1.3 | **Manual** + `flujo_f1_test.dart` (cuenta de toques y de desplazamientos) |
| 39 | **Acción diaria de Hábitos en ≤ 3 toques:** los cinco casos de la sección 7.3; manual: icono y marcar ≤ 3 toques y ≤ 6 s | `toques_habitos_test.dart` + **Manual** |
| 40 | **Metas complementarias:** PIN en `Isolate` sin cuadros > 100 ms y ≤ 1.5 s en el A52; cambio de estilo ≤ 300 ms (laptop) y ≤ 500 ms (A52); cuadros lentos ≤ 5 % y ≤ 10 %; CPU del núcleo ≤ 15 %; tamaño de fuentes ≤ 3 MB y APK ≤ +5 MB; Glass con tope de 3 capas y apagado automático | **Manual** + `pin_isolate_test.dart`, `tamano_test.dart`, `glass_capas_test.dart` |
| 41 | **Las mediciones quedan documentadas:** una tabla con equipo, fecha, versión, datos, cada corrida, mediana y peor, en el informe de calidad de la fase | Revisión de `docs/revisiones/fase-4.md` |

### 10.5 Accesibilidad

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 42 | **Guías de Flutter en la matriz:** `androidTapTargetGuideline`, `labeledTapTargetGuideline` y `textContrastGuideline` pasan en las pantallas de la sección 6 × 6 estilos × día/noche, en teléfono y laptop | `matriz_accesibilidad_test.dart` |
| 43 | **Letra 2.0:** las pantallas de la sección 6 con letra al 200 % en **360 dp** y en **900 dp**, con cada estilo, sin desbordes ni texto de acción cortado; el botón principal visible o alcanzable; la pantalla principal apila sus tres columnas | `letra_grande_matriz_test.dart` |
| 44 | **Lector de pantalla:** cada gadget y fila tiene nombre, valor y estado en palabras; los montos ocultos dicen "Monto oculto" sin cifra; las decoraciones están fuera del árbol semántico; el orden de lectura es el visual | `semantica_gadgets_test.dart`, `semantica_decoracion_test.dart` + **Manual** (TalkBack en el A52 y Narrator en la laptop: registrar un gasto y marcar un hábito sin ver la pantalla) |
| 45 | **No solo color:** cada estado de color tiene texto o icono distinto en los seis estilos; revisión en escala de grises | `no_solo_color_test.dart` + **Manual** |
| 46 | **Foco del teclado (laptop):** anillo de foco a 3:1 y orden de tabulación lógico en las pantallas principales, con los seis estilos | `foco_teclado_test.dart` |

### 10.6 Privacidad y datos sensibles

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 47 | **Lo oculto no está en el árbol:** con montos ocultos, modo privado o puerta reservada, la cifra no aparece ni en el árbol visual ni en el semántico con ninguno de los seis estilos (Glass incluido) | `oculto_por_estilo_test.dart` |
| 48 | **Tablet pública:** el modo Casa con los seis estilos no tiene dinero, datos clínicos ni nada de Hábitos; sus gadgets no incluyen Finanzas ni Hábitos; el estilo de la persona solo se aplica tras el PIN | `modo_casa_estilos_test.dart` |
| 49 | **Capturas:** las rutas nuevas llevan FLAG_SECURE; en Windows la ventana se excluye de la captura mientras la ruta sea sensible (con un canal falso en la prueba); las pruebas doradas y las vistas previas usan datos ficticios y no importan `data/personal/` | `pantalla_segura_fase4_test.dart`, `doradas_ficticias_test.dart` + **Manual** (Win+Shift+S y Recortes: sale negro) |
| 50 | **D3 y D13 en el diseño:** `app/lib/diseno` no importa clientes de IA, analítica ni red; los avisos de la vista previa usan solo el catálogo cerrado; el medidor de arranque es local | `d3_diseno_test.dart` (guardia ampliada) |
| 51 | **Hábitos reservado en los estilos:** las pantallas reservadas se cubren con fondo opaco (no translúcido) y no aparecen en la vista previa de estilos | `reservado_estilos_test.dart` |

### 10.7 Entrega

| # | Criterio | Cómo se comprueba |
|---|---|---|
| 52 | **Documentos al día:** `DISENO_UX_UI.md` (versión 0.7 con lo decidido), `supabase/README.md` si hay cambios de servidor, y el estado de la fase en el ROADMAP lo actualiza el arquitecto | Revisión del arquitecto |
| 53 | **Calidad:** `docs/revisiones/fase-4.md` con las pruebas corridas, las mediciones del A52 y de la laptop y 0 bloqueantes | Revisión de calidad |

---

## 11. Trabajo por agente

El ROADMAP (11.3) asigna a la Fase 4 solo a **diseno** y **plataforma**. Los pendientes E4 a E6, E8 a E13, E16 y E17 están en carpetas de **finanzas** y **habitos**: se **propone** al arquitecto sumarlos a la Fase 4 (decisión nueva, sección 13).

| Agente | Entrega | Carpetas |
|---|---|---|
| **diseno** | Propiedades nuevas del tema y los cinco estilos en el orden de 4.1 (con día y noche), fuentes con licencia, selector *Elegir otro estilo*, vista previa en vivo y *Apariencia › Gadgets*; transición suave y regla "no a mitad de una acción"; los gadgets nuevos (sección 5.2) y las variantes del núcleo; indicador de conexión; componentes de las pantallas de E3, E7 a E12 (hoja de frase, hitos, lista de motivos); guardias (4, 5, 12 y 13) y matrices (6 a 9, 24, 42 a 47, 51); pruebas doradas; informe de lo que se rompe por pantalla | `app/lib/diseno`, `app/lib/modulos/gravity/pantalla`, `app/assets`, sección `flutter:` de `app/pubspec.yaml`, `app/test/diseno`, `app/test/accesibilidad` |
| **plataforma** | Proveedor de conectividad y bandeja (E1), conector de "Hoy" con finanzas (E2), *Tengo una invitación* y *Personas* (E3), un solo PIN (E5), flujo de la nube cifrada con la frase (E7, junto con habitos), preferencias de avisos (E13), PIN en `Isolate` y su medición (E14), bloqueo de capturas en Windows (E15), `MedidorArranque` y *Desarrollador › Rendimiento*, optimizaciones de arranque (sección 7.1), restauración del estilo antes del primer cuadro | `app/lib/app`, `app/lib/nucleo`, `app/lib/modulos/ajustes`, `app/pubspec.yaml`, `app/android`, `app/windows` |
| **finanzas** *(propuesto sumarla)* | E2 (lado de datos), E6, E13 (lado de Finanzas), E16 y E17; ajustar sus pantallas a los seis estilos con lo que reporte diseno; cifra del flujo F1 | `paquetes/finanzas_dominio`, `app/lib/modulos/finanzas`, `docs/specs/fase-2-*` |
| **habitos** *(propuesto sumarla)* | E4, E5, E7 (lado de Hábitos), E8 a E12 y E18; ajustar sus pantallas a los seis estilos; criterios 28, 29, 32 y 33 | `paquetes/habitos_dominio`, `app/lib/modulos/habitos`, `docs/specs/fase-3-*` |
| **backend** | Sin migraciones esperadas. Apoya si E3 pide un cambio de servidor o si la prueba de rendimiento necesita un conjunto de datos de ejemplo en `seed.sql` | `supabase/` |
| **asistente** | Solo si P9 trae órdenes nuevas; las órdenes *"cambia el estilo a…"* y *"modo privado"* quedan como idea (sin dinero, solo navegación) | `app/lib/nucleo/herramientas`, `app/lib/modulos/gravity/ordenes`, `api/` |
| **calidad** | Datos de un año (`datos_un_ano.dart`), mediciones en el A52 y en la laptop (secciones 7 y 10.4), TalkBack y Narrator, revisión de D3, D13 y D14 (sección 9), informe `docs/revisiones/fase-4.md` | `docs/revisiones/`, pruebas en `test/` |

### Orden sugerido

1. **Base:** propiedades nuevas del tema, fuentes y las guardias 4, 5, 6, 12 y 13 (sin tocar el Futurista).
2. **Estilos 2 y 3** (B, C) con su puerta de aprobación; matriz de accesibilidad.
3. **Lo que estorba, prioridad A** (E1 a E5, E14), en paralelo con 2.
4. **Estilos 4, 5 y 6** (F, E, D), cada uno con su puerta de aprobación; personalidad *sport*, alto contraste de Cuidados y bici.
5. **Gadgets nuevos** y catálogo; E6 a E13, E16, E17.
6. **E7** (nube cifrada) y E15 (capturas en Windows).
7. **Rendimiento:** datos de un año, `MedidorArranque`, mediciones en el A52 y en la laptop, ajustes.
8. **Calidad** y cierre.

Lo que depende del dueño (el Galaxy A52 y la laptop para medir, aprobar cada estilo, los archivos de la Biblia, Firebase) **no bloquea**: se construye y se prueba con equipos de prueba y datos ficticios, y las mediciones reales quedan como "Manual pendiente".

---

## 12. Preguntas para el dueño

Cada pregunta trae la **propuesta por defecto** con la que se construye si no hay respuesta. Ninguna bloquea programar.

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P1** | ¿Entran **los cinco estilos** en esta fase y en qué orden? Si el tiempo aprieta, ¿cuál sacrificas primero? | Todos, en el orden **Minimalista, Claro sereno, Swagger, Glass, Arquitectónico**; si hay que recortar, el **Arquitectónico** (el más decorado) |
| **P2** | ¿Apruebas cada estilo al terminarlo, viendo capturas de laptop, teléfono y tablet (día y noche)? | **Sí**, una puerta de aprobación por estilo; no se sigue con el siguiente sin tu visto bueno |
| **P3** | El estilo y el claro/oscuro, ¿son **por persona** (cada quien el suyo) y la tablet de la casa tiene el suyo? | **Sí**: por persona en su dispositivo; la tablet pública (Hogar) con el suyo, y al entrar con PIN se aplica el de la persona |
| **P4** | Los gadgets de Cuidados, bici, entrenamiento y Alimentación, ¿se hacen ahora **solo como diseño visual** con datos de ejemplo, o esperan a su fase? | **Ahora, solo visual**, para dejar probado el alto contraste y la letra grande; se conectan en las fases 5, 7 y 8 |
| **P5** | La **nube cifrada** de Hábitos: ¿se construye la pantalla ahora aunque sigas en "solo teléfono"? | **Sí, al final de la fase y apagada por omisión**; si prefieres esperar, E7 pasa a "después" sin afectar nada más |
| **P6** | ¿Qué es "alto contraste" para Cuidados y la bici? | **7:1** en texto (el nivel AAA), sin decoración; en vez de solo 4.5:1 |
| **P7** | ¿Quieres que la laptop **bloquee capturas y miniaturas** de Finanzas, Hábitos reservado y Cuidados (como el teléfono)? | **Sí**; se dice en *Privacidad* que no impide una foto con otro aparato |
| **P8** | ¿El claro/oscuro puede seguir también **el amanecer y el atardecer**? | **No** en esta fase (necesita ubicación); se queda la hora editable (07:00 a 19:00) |
| **P9** | ¿Hay algo de "después" que te haya **resultado urgente** al usar la app? (Candidatos: atajos de teclado editables, widgets de Android, hitos de salud, el simulador de deudas, bandeja acotada.) | **Ninguno** además de los de la sección 2.4. Dime cuáles quieres y entran con su criterio de aceptación |
| **P10** | PIN: ¿cuántas vueltas (o Argon2) ponemos si el A52 las aguanta en menos de 1.5 s? | **600 000 vueltas** en un `Isolate`; si el A52 tarda más, se baja a lo que alcance en 1.5 s y se anota. Medición en tu teléfono |
| **P11** | ¿Mides tú o con quién los tiempos de **arranque, gasto y hábito** en el A52 y en la laptop (10 corridas)? ¿Me das un día con ambos equipos? | Calidad prepara una hoja de medición de 15 minutos por equipo y tú (o quien tú digas) corre los pasos; sin tu medición los criterios 37 a 40 quedan "Manual pendiente" |
| **P12** | La **vista previa de estilos** y el **catálogo de gadgets**: ¿van siempre con datos de ejemplo, aunque quieras ver tus cifras? | **Siempre datos de ejemplo** (por si alguien mira o se captura); tus cifras reales se ven en las pantallas normales |
| **P13** | El **chip "Cuenta nueva"** se vuelve un "+ Cuenta" al final de la lista: ¿bien? | **Sí**, destacado solo cuando el libro no tiene cuentas |
| **P14** | Los gadgets con **animación propia por estilo** (respiración, flotar, plano con cotas): ¿o prefieres que el núcleo sea el mismo anillo en todos? | **Una variante por estilo**; el anillo del Futurista queda como la opción por omisión y se puede fijar en Apariencia |

### 12.1 Datos y cosas para usarla (no bloquean)

1. **El Galaxy A52 y la laptop** para las mediciones de la sección 7, con la sesión iniciada.
2. **Tu aprobación visual** de cada estilo (P2) y del catálogo de gadgets.
3. **Los archivos de RVR1909 y KJV de dominio público** (fase 3, P10), para ver el lector con texto real; mientras tanto, texto ficticio.
4. **Una fuente oficial y la línea de ayuda** para los hitos de salud (fase 3, P16), si los quieres.
5. **Proyecto de Firebase y Supabase reales** (pendientes de fases anteriores), para probar las notificaciones y la invitación (E3) con tus cuentas.

---

## 13. Observaciones y decisiones propuestas

1. **Propuesta de decisión D22 (apariencia):** los seis estilos con sus ids; estilo y claro/oscuro por persona; las excepciones de Cuidados y bici no se pueden apagar; lo oculto se sustituye y no se difumina; el tema es solo apariencia y nunca cambia qué datos se ven. Se registra cuando el dueño apruebe esta especificación.
2. **Cambio al ROADMAP 11.3:** sumar a **finanzas** y **habitos** a la Fase 4 para los pendientes de interfaz de sus módulos (sección 11); hoy solo figuran diseno y plataforma.
3. **`DISENO_UX_UI.md`:** sección 4 dice que Glass "en el teléfono" usa versión translúcida sólida; se confirma y se agrega el tope de capas (7.5). La sección 13 menciona "Alertas" de Finanzas como pantalla de la Fase 2: en la app son la *Bandeja de avisos*. La sección 21 pide letra 2.0 "desde 900 dp en la laptop": se mantiene.
4. **Sobre el boceto del lienzo:** los bocetos son referencia de apariencia con datos de ejemplo; donde difieran de este texto, manda este texto y se ajusta el diseño.
5. **Fuentes:** Chakra Petch, IBM Plex, Manrope, DM Sans, Space Grotesk, Plus Jakarta Sans, Anton e Inter son de licencia libre (SIL OFL) *(verificar la versión y el archivo de licencia al incluirlas)*. Se incluyen solo los pesos usados.
6. **Dos riesgos de rendimiento conocidos:** el esmerilado de Glass y la suma de animaciones (núcleo, respiración, cianotipo) en equipos modestos como el A52; por eso los topes y el apagado automático de 7.5 y la medición de CPU de 7.4.
7. **Lo que esta fase no mide:** la duración de la batería. Si el dueño nota que el teléfono gasta más con algún estilo, se anota y se mide con `adb shell dumpsys batterystats` en una fase posterior.
8. **Qué se supone de las fases anteriores:** que las suites de las fases 0 a 3 siguen en verde (criterio 1) y que los hallazgos cerrados de las revisiones (I6 a I10 de la fase 1, F3-12 de la fase 3) se vuelven pruebas permanentes de la matriz de accesibilidad.

---

## Control de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 0.1 | 6/nov/2026 | Borrador inicial: alcance, lista y orden de estilos, lo que estorba con decisión, metas de rendimiento con su medición, accesibilidad, D3/D13/D14, 53 criterios, trabajo por agente y 14 preguntas |
