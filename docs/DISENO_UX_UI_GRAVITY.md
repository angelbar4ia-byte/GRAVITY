# `# Diseño UX/UI de GRAVITY` 

```
> **Fuente movida (20/oct/2026, D10):** este archivo queda como historial. La
versión vigente está en el repositorio **GRAVITY**, carpeta `docs/`.
```

```
> **Versión 0.5 (20/oct/2026), borrador para definir juntos.** Documento común
de experiencia y diseño visual de toda la app: la **pantalla principal de
GRAVITY en la laptop**, las **pantallas de los módulos**, la **app del
teléfono**, la **tablet portátil de la casa** y la **pulsera (smart band)**. Las
pantallas de cada módulo siguen en sus diseños (FINANZAS, sección 8; HÁBITOS,
Anexo G) y deben respetar este documento.
>
```

```
> **(decidido)** = ya lo confirmaste. **(propuesto)** = sugerencia para revisar.
Las preguntas para definir están en la sección 22.
>
```

```
> **Bocetos para comparar** (lienzo privado): [GRAVITY — estilos de pantalla]
(https://claude.ai/artifact/M4y2F9SJJvqXVKXjDJ7rwT). Datos de ejemplo.
> - **Laptop, pantalla principal:** A futurista (**por defecto**), B
minimalista y E glass (noche o día). *(C claro y D arquitectónico se retiraron el
28/oct/2026; las letras de los estilos se reasignaron de la A a la N: ver 24.0.)*
```

```
> - **Teléfono:** Hoy del Dueño, Mi turno de la cuidadora, Registrar gasto y
Bici en vivo (personalidad sport).
```

```
> - **Módulos, gadgets y herramientas:** Finanzas › Semana, el catálogo de
gadgets y Ajustes › Desarrollador (APIs con Swagger UI).
```

```
> - **Tablet y smartwatch:** modo Casa de la tablet con contextos (noche o día,
en *Tweaks*) y cinco pantallas del reloj.
```

```
## 1. Lo que ya está decidido
```

```
| Tema | Decisión | Origen |
|---|---|---|
```

```
| Plataformas | Laptop Windows con el sistema completo; teléfono Android con lo
mínimo; **tablet portátil de la casa**; **pulsera smart band** (reloj Wear OS a
futuro) | D4, D14, D15 |
```

```
| Laptop | Pantalla principal de GRAVITY **tipo JARVIS** | D12 |
| Teléfono | **App normal**, sin pantalla tipo JARVIS; GRAVITY como botón de
micrófono | D12 |
```

- `| Estilo | **Configurable**; **por defecto, A · Futurista** | 20/oct/2026 | | Swagger | **Las dos cosas:** el estilo F "swagger" y la herramienta **Swagger UI** para documentar y probar las APIs | D16 |` 

- `| Claro / oscuro | **Automático según la hora**, además de las opciones fijas | 20/oct/2026 | | Personalidad | **Cambia por módulo y submódulo**, sin volverse "tutifruti": personalidad con uso y función | 20/oct/2026 |` 

- `| Gadgets | Medidores, contadores, anillos y relojes en lugar de pantallas planas | 20/oct/2026 |` 

- `| Voces | **Se pueden cambiar** | 20/oct/2026 |` 

- `| Tablet | **Portátil**, en horizontal y en vertical; **contextos ampliables**; sin vista en planta | D14 |` 

- `| Núcleo de GRAVITY | **Anillos que giran** (Futurista); más opciones después | 20/oct/2026 |` 

```
| Base | Material 3 | HÁBITOS G.1 |
```

```
| Colores de Hábitos por área | Espiritual violeta, Salud verde, Inglés naranja,
Personal azul verdoso, Laboral gris azulado, Hábitos a eliminar terracota (nunca
rojo de alarma) | HÁBITOS G.1 |
```

- `| Tono | Cercano y sin culpa: un fallo es un "ajuste", no un error | HÁBITOS G.1 y G.7 |` 

- `| Rapidez | Registrar un gasto en menos de 10 s; la acción diaria de Hábitos en 3 toques o menos | FINANZAS 1 y decisión 24; HÁBITOS 1 |` 

- `| Privacidad en pantalla | Montos ocultos en la pantalla bloqueada; notificaciones discretas en hábitos sensibles | FINANZAS decisión 68; HÁBITOS G.6 |` 

```
| Datos sensibles | Diario de oración y hábitos sensibles cifrados en la nube o
solo en el teléfono | D13 |
```

```
| Zonas táctiles | Mínimo 48 dp; acciones principales al alcance del pulgar |
HÁBITOS G.1 |
```

```
## 2. Principios (propuesto)
```

```
1. **Una app, varias formas de uso.** En la laptop se piensa y se planea; en el
teléfono se actúa; en la tablet se comparte la casa; en la pulsera se mira.
2. **Personalidad con propósito.** Cada cambio visual responde al uso: en la
bici, números enormes porque se ven de reojo y en movimiento; en Finanzas, calma
y precisión.
```

`3. **Cada persona ve solo lo suyo.** La interfaz se arma según el rol (D5): nada de pantallas vacías ni botones bloqueados por permisos.` 

```
4. **Primero lo de hoy.** Al abrir, lo que toca ahora; el detalle, a un toque o
un clic.
```

`5. **Gadgets antes que tablas en el teléfono, la tablet y el reloj; tablas completas en la laptop.**` 

```
6. **Siempre se confirma antes de escribir**, sobre todo lo que llega por voz o
por GRAVITY.
```

```
7. **Privacidad visible.** El dinero y los datos de cuidados se ocultan con un
toque o un atajo.
```

```
8. **Todo tiene estado** vacío, cargando, sin conexión y error, con un mensaje
claro y una acción.
```

```
9. **Accesible:** letra grande opcional, buen contraste, lector de pantalla,
nada que dependa solo del color.
```

```
---
```

```
## 3. Personas y contextos de uso (propuesto)
```

```
| Persona | Dónde | Contexto | Qué pide al diseño |
```

- `|---|---|---|---|` 

```
| **Tú, en la laptop** | Escritorio | Planear, revisar y configurar; sesiones
largas | Pantalla con mucha información, atajos de teclado, voz, paneles |
```

```
| **Tú, en el teléfono** | Súper, coche, bici, calle | Prisa, una mano, a veces
sin señal | Botón "+" siempre visible, registro en segundos, modo de solo audio
al manejar |
```

```
| **Tú, en la pulsera** | Bici, gimnasio, en movimiento | Un vistazo, sin manos
| Avisos cortos que se entienden solos |
```

```
| **Cualquiera, en la tablet** | Donde se lleve: cocina, gimnasio, recámara de
papá, sala | De pasada, con las manos ocupadas, varias personas | Contexto según
dónde se use, voz, cambio de usuario rápido |
| **Pareja** | Teléfono | Lo suyo y el resumen del presupuesto | Igual que el
tuyo, pero reducido |
```

```
| **Cuidadora** | Teléfono o tablet, en su turno | Atiende a una persona con
Alzheimer, con interrupciones constantes; quizá con poca experiencia en apps |
Botones grandes, pocas opciones, lenguaje simple, confirmar en un toque, todo en
"Mi turno" |
| **Hermana** | Teléfono o tablet, los martes | Llega después del turno de la
cuidadora | Entrar directo a la entrega de turno |
```

```
| **Familiares** | Teléfono | Sus hábitos | Lo más simple |
```

# `## 4. Sistema de estilos (configurable)` 

```
El aspecto se arma en **cuatro capas**. Así cada módulo tiene personalidad sin
que la app se vuelva un "tutifruti".
```

```
| Capa | Qué define | Quién la elige |
```

```
|---|---|---|
```

```
| **1. Base común** | Rejilla y márgenes, posición de la navegación y los
botones, tipografía de lectura, iconos, comportamiento (confirmar, deshacer),
accesibilidad | Fija: **no cambia nunca** |
| **2. Estilo** | Superficies, bordes, decoración, tipografía de títulos y
números, animación del núcleo | Tú, en Ajustes (global). **Por defecto:
Futurista** |
```

```
| **3. Personalidad del módulo** | Color de acento, gadgets, densidad, ritmo de
animación | Automática por módulo y submódulo; se puede fijar a mano (sección 5)
|
| **4. Claro / oscuro** | Fondo y contraste | Automático por hora, del sistema,
siempre claro o siempre oscuro |
```

```
**Estilos disponibles** (bocetos en el lienzo)
```

```
| Estilo | Cómo se ve | Dónde luce más |
|---|---|---|
| **A · Futurista (HUD) — por defecto** | Noche: fondo casi negro, líneas finas
cian, anillos que giran, letra técnica. Día: fondo claro con líneas azul
petróleo (ver la tablet en *Tweaks*) | Pantalla principal de GRAVITY, tablet,
reloj |
| **B · Minimalista** | Oscuro o claro, tarjetas redondeadas, círculo que
"respira" | Sesiones largas en los módulos |
| ~~C · Claro sereno~~ | **Retirado el 28/oct/2026** | — |
```

```
| ~~D · Arquitectónico~~ | **Retirado el 28/oct/2026** | — |
| **E · Glass** | Paneles translúcidos y esmerilados sobre un fondo de color
difuminado; versión de noche y de día | Laptop y tablet |
```

```
| **F · Swagger** | Con actitud: letra grande y condensada, negro y blanco con
un color neón, etiquetas tipo sticker | Personalidad sport (bici, entrenamiento)
y para quien la quiera global |
```

```
**Reglas (propuesto)**
- **Claro / oscuro automático por hora:** claro de 07:00 a 19:00 por defecto
(editable) o según el amanecer y el atardecer. El cambio es suave y nunca a
mitad de una acción. Cada estilo tiene su versión de día y de noche.
```

```
- **Excepciones por función:**
```

```
  - **Cuidados** usa siempre una variante clara y de alto contraste, sin
decoración, sea cual sea el estilo.
```

```
  - **La bici** usa siempre alto contraste, por el sol.
- **Glass en el teléfono:** sin el efecto de esmerilado, que gasta batería y
puede hacer lenta la app; se usa una versión translúcida sólida. El esmerilado
completo, solo en laptop y tablet.
```

```
- **Cómo se construye sin rehacer:** cada estilo es un juego de valores de
diseño (colores, tipografías, formas, sombras, animación, densidad) en el tema
central. La personalidad del módulo solo sustituye algunos de esos valores, y
las pantallas nunca usan colores fijos. Agregar un estilo nuevo no obliga a
tocar pantallas.
```

```
- **Por fases:** la Fase 0 arranca con el sistema de estilos y el Futurista (día
y noche). Los demás estilos, las personalidades y los gadgets llegan en el
Pulido 1 (ROADMAP).
```

```
## 5. Personalidad por módulo y submódulo (propuesto)
```

```
| Módulo / submódulo | Personalidad | Qué cambia | Por qué |
|---|---|---|---|
```

```
| **GRAVITY (pantalla principal)** | Asistente | El estilo elegido completo,
núcleo animado | Es la cara del sistema |
```

```
| **Finanzas** | Precisa y serena | Acento índigo, números de ancho fijo,
tablas, medidores, poca animación | Se lee con calma y sin errores |
| **Hábitos · Espiritual** | Contemplativa | Acento violeta, letra de lectura
```

```
más grande, sin animación | Lectura larga, a menudo de noche |
```

```
| **Hábitos · Entrenamiento y bici** | Sport (estilo F) | Neón, números enormes
y condensados, alto contraste, cronómetros | Se ve de reojo, en movimiento y al
sol |
```

- `| **Hábitos · Inglés** | Lúdica | Acento naranja, progreso por niveles | Motivación diaria |` 

- `| **Hábitos a eliminar** | Empática | Terracota, contador grande, botón SOS siempre visible | Momentos de antojo; sin culpa |` 

- `| **Cuidados** | Clara y cálida | Rosa oscuro, letra y botones grandes, alto contraste | Se usa con interrupciones; no puede haber confusión |` 

- `| **Alimentación / Casa** | Cálida y práctica | Ámbar, recetas paso a paso con letra grande y voz | Se usa cocinando, con las manos ocupadas |` 

```
| **Ajustes › Desarrollador** | Técnica | Estilo Swagger UI con los colores del
estilo activo | Consultar y probar APIs (sección 10) |
```

```
En Ajustes, cada módulo tiene tres opciones: **Automática** (la de la tabla),
**Igual al estilo global** o **Elegir otro estilo**.
```

# `## 6. Gadgets (propuesto)` 

```
Cada gadget responde a una pregunta concreta y toma el estilo activo y la
personalidad de su módulo. Se pueden poner en la pantalla principal de GRAVITY,
en "Hoy" del teléfono, en la tablet, en el reloj y como widgets de Android.
```

- `| Gadget | Módulo | Responde a |` 

- `|---|---|---|` 

- `| Medidor de presupuesto | Finanzas | ¿Cuánto llevo gastado y cuánto me queda? |` 

- `| Cascada | Finanzas | ¿A dónde va el ingreso de la semana? |` 

- `| Anillos del día | Hábitos | ¿Cómo voy hoy en cada área? |` 

- `| Contador de días libres + SOS | Hábitos a eliminar | ¿Cuántos días llevo? Tengo un antojo |` 

- `| Velocímetro y cronómetro | Bici | ¿A qué ritmo voy? |` 

- `| Serie y descanso | Entrenamiento | ¿Qué sigue y cuánto descanso? |` 

- `| Reloj del turno | Cuidados | ¿Quién está de turno y qué sigue? |` 

- `| Menú y lista de compras | Casa / Alimentación | ¿Qué comemos y qué falta? |` 

- `| Núcleo de GRAVITY | GRAVITY | ¿Me está escuchando? |` 

# `## 7. Laptop: pantalla principal de GRAVITY (propuesto)` 

|`┌────────────────`<br>`│ GRAVITY`<br>`├────────────────`|`──────────────────────────────────────────────────┐`<br>`mar 20 oct · 19:42            ● en línea │`<br>`────────────────────────────────────────────────┤`|
|---|---|
|`│ HOY`<br>`│ 20:00 Inglés`<br>`│ Hábitos 3/5`<br>`│`<br>`│ CUIDADOS`<br>`│ Turno: Ana`<br>|`┬┬`<br>`│                                │ FINANZAS       │`<br>`│                                │ Semana  ● verde│`<br>`│            núcleo             │ Quedan  $ •••  │`<br>`◯`<br>`│       (reacciona a la voz)     │                │`<br>`│                                │ AVISOS         │`<br>`│  "Buenas noches. Te faltan     │ Tarjeta vence  │`<br>|
|`│ Medic. 8 pm`<br>`✓`<br>`├────────────────`|`│   2 hábitos de hoy."           │ el viernes     │`<br>`┴────────────────────────────────┴────────────────┤`|
|`│ >  Escribe o ha                      🎤`<br>`────────────────`|`bla a GRAVITY…                    🎤   Ctrl+Espacio │`<br>`─────────────────────────────────────────────────`|
|`├`<br>`│  Finanzas · Háb`<br>`└────────────────`|`┤`<br>`itos · Cuidados · Alimentación · Casa · Ajustes   │`<br>`──────────────────────────────────────────────────┘`|



- `| Zona | Qué hace |` 

- `|---|---|` 

- `| **Núcleo central** | Animación que muestra el estado de GRAVITY: en espera,` 

```
escuchando, pensando o hablando |
```

```
| **Paneles y gadgets** | Resumen de cada módulo activo; se pueden mover,
cambiar u ocultar |
| **Barra de órdenes** | Texto y voz. En la Fase 0 solo navega (*"abre
presupuesto"*); en la Fase 6 conversa con IA |
| **Barra de módulos** | Abre cada módulo completo |
| **Atajo global** | Una combinación de teclas abre GRAVITY desde cualquier
parte de Windows (sección 15) |
```

```
| **Modo privado** | Un atajo oculta montos y datos de cuidados, por si alguien
está viendo |
```

```
## 8. Laptop: dentro de un módulo (propuesto)
```

- `**Barra lateral** con las secciones del módulo y, arriba, el botón **GRAVITY** para volver a la pantalla principal.` 

- `**Área principal** con tablas completas, filtros y la acción principal arriba a la derecha (p. ej. *Registrar movimiento*).` 

- `**Panel de detalle** a la derecha o como hoja, sin perder la tabla de vista.` 

- `Al entrar, la pantalla toma la **personalidad del módulo** (sección 5).` 

- `GRAVITY sigue disponible con el atajo global y con la barra de órdenes.` 

- `Si la ventana se hace angosta (p. ej. media pantalla), la barra lateral se vuelve menú y los paneles se apilan.` 

```
## 9. Teléfono: app normal (propuesto)
```

```
**Barra inferior según el rol**
```

```
| Rol | Pestañas |
|---|---|
| Dueño | Hoy · Finanzas · **(+)** · Hábitos · Más |
| Pareja | Hoy · Finanzas (resumen) · **(+)** · Hábitos · Más |
| Cuidador | Mi turno · Medicamentos · Comidas · Bitácora |
| Familiar | Hoy · Hábitos · Más |
```

- `**Hoy** junta lo del día de todos los módulos con sus gadgets. - **(+)** registra un gasto, un ingreso extra, un hábito o un consumo (cigarrillo o azúcar), y abre el SOS.` 

- `**GRAVITY en el teléfono:** un botón de micrófono arriba, sin pantalla especial.` 

```
- **Pantallas en movimiento** (bici, entrenamiento, modo traslado): ocupan toda
la pantalla con personalidad sport, botones enormes y nada que obligue a leer en
movimiento.
```

```
- **Cómo se juntan las navegaciones de los diseños anteriores.** FINANZAS
proponía *Inicio · Presupuesto · Registrar · Metas · Más* y HÁBITOS *Hoy ·
Agenda · Áreas · Progreso · Coach*. En la app única, Agenda, Áreas y Progreso
quedan dentro de Hábitos, Metas dentro de Finanzas, y el Coach pasa a GRAVITY.
```

```
--- ## 10. Laptop: Ajustes › Desarrollador, APIs con Swagger UI (D16)
```

- `**Qué es:** la consola donde se **consultan y prueban las APIs del sistema**, con la herramienta **Swagger UI** y la especificación en formato **OpenAPI**. Se ve con los colores del estilo activo (boceto *Laptop · Desarrollador*). - **Grupos:** herramientas de GRAVITY, base de datos, funciones del servidor y puente de casa (Home Assistant).` 

- `**Cada operación muestra:** método y ruta, qué hace, qué rol la puede usar, si **pide confirmación** y si **nunca pasa por la IA** (dinero, D3).` 

- `**Probar:** las llamadas se hacen con la sesión del Dueño; nada se ejecuta sin confirmación si escribe datos. - **Seguridad:** solo en la laptop y solo con rol Dueño. La especificación **no se publica en internet**.` 

```
- **Para qué sirve:** revisar qué puede hacer GRAVITY, conectar el puente de
casa y futuras integraciones, y que cada sesión de Claude Code tenga la API
documentada.
```

```
## 11. Tablet portátil de la casa (D14)
```

```
- **Dispositivo:** tablet Android **portátil**, compartida en la casa; se lleva
a donde se use. Es la misma app con diseño para tablet, en horizontal y en
vertical.
```

```
- **Modo Casa** (al encender y en reposo): rol Casa (D5). Muestra GRAVITY, lo de
hoy en la casa, la cocina, el turno de cuidados con recordatorios genéricos y
los avisos. Sin dinero ni datos clínicos.
```

```
- **Contextos (decidido, ampliables):** arriba se elige dónde se está usando.
Para empezar: **General · Cocina · Gimnasio · Cuidados**; se pueden agregar más
(p. ej. Estudio, Sala, Lectura, Cochera). Cada contexto define sus gadgets, el
tamaño de letra y la personalidad. Ejemplos: en Cocina, la receta paso a paso
con letra enorme y voz; en Gimnasio, la serie y el descanso; en Cuidados, "Mi
turno" (con la sesión de la cuidadora).
```

```
- **Cambio de usuario:** se toca un nombre y se entra con PIN o huella a las
pantallas de esa persona según su rol. Después de 2 minutos sin uso (editable)
regresa sola al modo Casa.
```

```
- **GRAVITY en la tablet:** botón **"Mantén para hablar"** siempre; la palabra
*"Gravity"* solo mientras carga, para no gastar batería *(propuesto)*. Aquí sí
hay conversación libre, algo que las bocinas Xiaomi no permiten (D6).
- **Vista en planta:** descartada.
```

```
## 12. Pulsera (smart band) y reloj (D15)
```

```
**Dispositivo actual:** una pulsera smart band, probablemente de la serie 4
(falta confirmar marca y modelo). Este tipo de pulsera no permite instalar apps
propias y normalmente solo muestra el texto de los avisos y vibra, sin los
botones de la app *(a verificar con el modelo exacto)*.
```

```
| Nivel | Qué incluye | Con tu pulsera |
|---|---|---|
```

```
| **1. Avisos** | Los avisos del teléfono llegan con texto corto y vibración;
con un reloj compatible, también con botones (*Hecho*, *Posponer*, *Ya se dio*)
| **Sí**, con texto y vibración |
```

```
| **2. App propia** | Pantallas y accesos rápidos: anillos del día, bici en
vivo, SOS antojo, medicamento de la cuidadora, serie y descanso | **No**:
requiere un reloj **Wear OS** |
```

```
**Reglas (propuesto)**
```

```
- **Avisos cortos que se entienden solos**, porque la pantalla es pequeña:
*"Inglés 20:00"*, *"Medicamento 20:00"*. Lo que requiere una acción se hace en
el teléfono.
```

```
- **Sin montos de dinero** en la pulsera ni en el reloj.
```

- `Los datos de la pulsera (pasos, ritmo cardiaco, sueño) entran a Hábitos por Health Connect si su app los comparte *(a verificar)*.` 

- `El boceto del reloj redondo queda como referencia para cuando haya un reloj Wear OS; las mismas reglas aplican.` 

```
## 13. Mapa de pantallas de las fases 0 a 3 (propuesto)
```

```
**Laptop (Dueño)**
```

```
| Módulo | Pantallas | Fase |
|---|---|---|
```

```
| GRAVITY | Pantalla principal | 0 |
```

```
| Ajustes | Personas y roles · Apariencia (estilo, claro/oscuro, personalidad
por módulo) · Voz · Privacidad (modo privado y datos sensibles, D13) · Copias de
seguridad · Notificaciones · **Desarrollador (APIs)** · Asistente de
configuración | 0 |
```

```
| Finanzas | Tablero · Semana · Movimientos · Cuentas · Ingresos · Gastos y
categorías · Importar datos | 1 |
```

```
| Finanzas | Deudas · Ahorro · Alertas | 2 |
```

```
| Hábitos | Hoy · Agenda · Objetivos · Hábitos a eliminar · Espiritual (lector,
planes, devocional, oración) · Progreso · Revisión semanal | 3 |
```

```
Cuidados, Casa y Alimentación aparecen cuando llegan sus fases (5, 6 y 7).
```

```
**Teléfono**
```

```
| Rol | Pantallas |
```

```
|---|---|
```

```
| Dueño | **Hoy** · **Finanzas:** resumen de la semana, próximos pagos, avance
de ahorro, movimientos recientes · **(+):** gasto, ingreso extra, hábito,
consumo, SOS · **Hábitos:** hoy, agenda del día, lectura (lector, devocional,
oración), panel de hábitos a eliminar · **Más:** cuidados (Fase 5), ajustes,
privacidad |
```

```
| Pareja | Como el Dueño, con el presupuesto solo de lectura |
```

```
| Cuidador (Fase 5) | **Mi turno:** entrega de turno, siguiente medicamento,
comidas, gasto de cuidado · **Medicamentos** · **Comidas** · **Bitácora** |
| Familiar | Hoy · Hábitos · Más |
```

```
**Tablet:** modo Casa con contextos, cambio de usuario y, por usuario, las
pantallas del teléfono con diseño de tablet.
```

```
**Pulsera:** avisos desde que existan las notificaciones (Fases 2 y 3); app
propia solo si después hay un reloj Wear OS.
```

```
## 14. Flujos clave (propuesto)
```

```
| # | Flujo | Pasos | Meta |
|---|---|---|---|
```

```
| F1 | **Registrar un gasto** (teléfono) | (+) → Gasto → monto (el teclado ya
está abierto) → categoría (la última preseleccionada y 5 sugeridas) → cuenta (la
última usada) → Guardar → aviso *"Guardado · Deshacer"* | Menos de 10 s |
| F2 | **Marcar un hábito** | Hoy → *Hecho* (o deslizar) → la racha se
actualiza, con deshacer. También desde la notificación o el reloj | 3 toques o
menos |
```

```
| F3 | **SOS "Tengo un antojo"** | Hoy, (+), widget o reloj → temporizador con
una alternativa → *"¿Lo superaste?"* Sí / No, sin culpa | Al alcance en 1 toque
|
```

```
| F4 | **Orden a GRAVITY** (laptop) | Ctrl+Espacio → escribir → sugerencias
mientras escribes → Enter. Si no entiende, muestra opciones parecidas. Desde la
Fase 6 conversa, y toda escritura pasa por la tarjeta de confirmación | — |
| F5 | **Revisión semanal de finanzas** (laptop) | Semana → Revisión semanal →
planeado contra real → desvíos → ajustar la siguiente semana → confirmar el
abono extra o el ahorro | Unos 3 min (FINANZAS 5.9 bis) |
```

```
| F6 | **Invitar a una persona** (laptop) | Ajustes → Personas y roles → Invitar
→ nombre y rol → invitación por correo → instala la app y entra → ve solo lo de
su rol. Dar de baja: un clic y confirmación; pierde el acceso al instante | — |
| F7 | **Cambio urgente de medicamento** (Fase 5) | Teléfono del Dueño: Más →
Cuidados → medicamento → suspender o agregar → nota → confirmar → aviso al
instante a la cuidadora de turno, que marca *Enterada* | — |
```

```
| F8 | **Usar la tablet** | Elegir contexto (Cocina, Gimnasio, Cuidados) → tocar
un nombre → PIN o huella → pantallas de esa persona → 2 min sin uso → modo Casa
| Menos de 5 s |
```

```
| F9 | **Cambiar el estilo** | Ajustes → Apariencia → estilo (vista previa en
```

```
vivo) → claro/oscuro (automático por hora) → personalidad por módulo | — |
| F10 | **Probar una API** (laptop) | Ajustes → Desarrollador → grupo →
operación → *Probar* → ver la respuesta | — |
```

```
**Sin señal:** lo registrado se guarda en el teléfono con el aviso *"Guardado en
el teléfono; se sube al volver la señal"*.
```

```
## 15. Atajos de teclado en la laptop (propuesto)
```

```
| Atajo | Acción |
```

- `|---|---|` 

```
| Ctrl + Espacio | Abrir GRAVITY desde cualquier parte de Windows |
| Ctrl + K | Barra de órdenes dentro de la app |
```

```
| Ctrl + N | Registrar un movimiento |
```

```
| Ctrl + Shift + O | Modo privado (ocultar montos y cuidados) |
```

```
| Ctrl + 1 a 5 | Ir a cada módulo |
```

```
| Esc | Volver a la pantalla principal de GRAVITY |
```

```
Todos se pueden cambiar en Ajustes.
```

```
## 16. Voz y personalidad de GRAVITY
```

```
- **Voces configurables (decidido):** en Ajustes → Voz se elige la voz (de las
disponibles en Windows, en Android o en el proveedor de voz), la velocidad y el
tono. **Cada persona elige la suya**; en la tablet, la voz cambia con el usuario
activo, y el modo Casa tiene su propia voz.
- **Trato (propuesto):** de tú con el Dueño, la pareja y los familiares. En
Cuidados, textos **impersonales** (*"¿Cómo comió?"*, *"Marcar como leída"*),
para no tener que elegir entre tú y usted con la cuidadora.
```

```
- **Carácter (propuesto):** tranquila, breve y precisa; sin culpa; el humor
ligero viene apagado y se puede activar.
```

```
- **Siempre dice lo que hizo** (*"Listo: registré $85 en Alimentación"*) y pide
confirmación antes de escribir.
```

```
- **Nunca dice montos en voz alta** con el modo privado activo, en el modo Casa
ni por las bocinas (D6).
```

```
- **Activación:** en la laptop, el atajo o la palabra *"Gravity"*; en la tablet,
*"Mantén para hablar"* y la palabra solo mientras carga; en las bocinas, *"Hey
Google"* con las frases fijas (D6).
```

```
## 17. Notificaciones (propuesto)
```

- `| Tipo | En la pantalla bloqueada y la pulsera | Al abrir |` 

- `|---|---|---|` 

- `| Pago próximo | *"Tienes un pago próximo"* | Detalle con monto |` 

- `| Categoría excedida | *"Revisa una categoría"* | Detalle |` 

```
| Hábito | *"Inglés · 20:00"* con *Hecho* y *Posponer* | — |
```

- `| Hábito sensible (cigarrillo, azúcar) | *"Recordatorio"* | Detalle |` 

- `| Medicamento (cuidadora de turno) | *"Medicamento de las 20:00"* con *Ya se dio* | Detalle |` 

- `| Cambio urgente (cuidadora de turno) | *"Hay una indicación nueva en Cuidados"* | Detalle |` 

- `Máximo 3 avisos no críticos al día y horas silenciosas de 22:00 a 07:00 (FINANZAS decisión 68).` 

- `**Medicamentos y cambios urgentes sí suenan en horas silenciosas** *(propuesto)*.` 

```
## 18. Sistema visual (por definir)
```

```
| Elemento | Propuesta | Nota |
```

```
|---|---|---|
```

- `| Color de GRAVITY | Cian (#35d4f0) de noche; azul petróleo (#0a7f99) de día | Estilo por defecto |` 

- `| Color por módulo | Finanzas índigo, Cuidados rosa oscuro, Alimentación ámbar, sport neón; Hábitos conserva sus colores por área | Sección 5 |` 

- `| Semáforo | Verde, ámbar y rojo en dinero y medicamentos; verde, ámbar y terracota en hábitos | El rojo, solo para alertas reales |` 

- `| Tipografía | Por estilo: Chakra Petch e IBM Plex (A), Manrope (B), DM Sans` 

- `(C), Space Grotesk e IBM Plex Mono (D), Plus Jakarta Sans (E), Anton (F, números y títulos). Lectura y teléfono: Inter. Números de ancho fijo en montos | — | | Iconos | Sobrios, de línea | Pregunta 2 |` 

- `| Montos | Formato de México: `$1,234.50`; ocultables | — |` 

- `| Densidad | Compacta en la laptop, cómoda en el teléfono, grande en la tablet, mínima en el reloj | — |` 

# `## 19. Componentes compartidos (propuesto)` 

- `**Tarjeta de resumen de módulo** y **gadgets** (sección 6).` 

- `**Tarjeta de confirmación:** cada escritura que llega por voz o por GRAVITY se muestra antes de guardarse.` 

- `**Registro rápido (+)** con teclado numérico grande, categorías sugeridas y deshacer.` 

- `**Monto** con modo oculto.` 

- `**Semáforo, barra de progreso y chip de racha.**` 

- `**Fila con deslizar:** hecho, posponer, omitir.` 

- `**Hoja inferior** para detalles sin salir de la pantalla.` 

- `**Aviso urgente de cuidados:** destacado, para cambios de medicamento.` 

- `**Selector de usuario y selector de contexto** (tablet).` 

- `**Operación de API** con método, ruta, rol y prueba (Desarrollador).` 

- `**Estado vacío** con una sola acción sugerida.` 

# `## 20. Accesibilidad y uso seguro` 

- `Zonas táctiles de 48 dp o más, buen contraste, letra ajustable y lector de pantalla.` 

- `Nada que obligue a mirar la pantalla al manejar o en la bici (modo de solo audio y reloj con un vistazo).` 

- `Para el rol Cuidador, letra grande por defecto *(propuesto)*.` 

- `Las animaciones se detienen si el sistema tiene activada la opción de reducir movimiento.` 

- `Ningún estilo puede bajar el contraste mínimo: si un estilo no lo cumple en un módulo, ese módulo usa su variante de alto contraste.` 

# `## 21. Privacidad en pantalla` 

- `Montos ocultables y modo privado en la laptop.` 

- `Modo Casa en la tablet sin dinero ni datos clínicos; lo personal solo tras PIN o huella.` 

- `Sin montos en la pulsera ni en el reloj.` 

- `Notificaciones discretas en dinero, hábitos sensibles y cuidados (sección 17). - PIN o huella en el teléfono; en la laptop, GRAVITY se bloquea tras un rato sin uso *(propuesto)*.` 

```
## 22. Preguntas para definir juntos
```

```
**Pulsera y tablet**
```

```
1. **Pulsera:** marca y modelo exactos (aparecen en su app del teléfono o en la
caja). ¿La cuidadora usa pulsera o reloj?
```

`2. **Contextos de la tablet:** además de General, Cocina, Gimnasio y Cuidados, ¿cuáles agregas?` 

```
3. ¿Iconos sobrios como en los bocetos, o prefieres emojis?
```

# `**GRAVITY**` 

`4. **Paneles al abrir la laptop:** ¿hoy, finanzas, hábitos, cuidados, avisos? ¿Agregas clima, correo u otro?` 

```
5. ¿GRAVITY te saluda en voz alta al encender la laptop?
```

```
**Colores, cuidadora y atajos**
```

```
6. Tamaño de letra cómodo para ti, para la lectura de la Biblia y para la
cuidadora.
```

```
7. ¿Algún color que te guste o quieras evitar?
```

```
8. ¿Qué tanto usa apps la cuidadora? ¿Letra grande desde el inicio?
```

`9. En el teléfono de la cuidadora, ¿la app se ve con el nombre "GRAVITY" o con otro más sencillo?` 

```
10. ¿Te sirven los atajos de la sección 15?
```

```
*Los roles y permisos financieros entre miembros (albacea, confirmaciones, qué
registra la pareja) no son de UX/UI: se definen en la especificación de
Finanzas.*
```

# `## Control de cambios` 

```
| Versión | Fecha | Cambio |
```

```
|---|---|---|
```

```
| 0.1 | 20/oct/2026 | Borrador inicial: lo ya decidido, principios, personas,
pantalla principal de la laptop, navegación del teléfono por rol, sistema visual
y preguntas |
```

```
| 0.2 | 20/oct/2026 | Bocetos A, B y C y recomendación de estilo; pantalla
dentro de un módulo; mapa de pantallas de las fases 0 a 3; flujos clave; atajos;
voz y personalidad de GRAVITY; notificaciones |
```

```
| 0.3 | 20/oct/2026 | Estilo configurable en cuatro capas; estilos D
arquitectónico, E glass y F swagger; claro/oscuro automático por hora;
personalidad por módulo y submódulo; gadgets; tablet maestra de la casa con
cambio de usuario; voces configurables; la pregunta sobre la pareja pasa a la
especificación de Finanzas |
```

```
| 0.4 | 20/oct/2026 | Futurista por defecto (con versión de día); Swagger como
estilo y como herramienta (Ajustes › Desarrollador, D16); tablet portátil con
contextos y sin vista en planta; smartwatch en dos niveles (D15) |
```

```
| 0.5 | 20/oct/2026 | Pulsera smart band en lugar de smartwatch (app propia solo
con reloj Wear OS); tablet en horizontal y vertical con contextos ampliables;
núcleo con anillos que giran. Ronda cerrada, en espera de nuevas instrucciones |
```


---

---

# Complemento v0.6 (28/oct/2026)

> **Qué es.** Secciones 23 a 26 agregadas al documento v0.5; además, los estilos C y D se retiraron en la sección 4. Decisión del usuario: **este documento manda** para las pantallas. El contrato de conexión v2.0 **no se modifica** (ver sección 25). **No hay bocetos nuevos en este complemento:** las pantallas de referencia son las del lienzo «GRAVITY — estilos de pantalla» citado al inicio.

## 23. Pantallas pendientes de diseño

Pantallas que los flujos de la sección 14 y el resto del documento mencionan, pero que **aún no tienen boceto**. Se diseñan después de elegir los estilos (sección 24).

| Id | Pantalla | Flujo o sección | Dispositivo |
|---|---|---|---|
| C01 | Ajustes › Apariencia (estilo, claro/oscuro, personalidad por módulo) | F9, sección 4 | Laptop · **boceto en el lienzo (shadcn)** |
| C02 | Ajustes › Personas y roles (invitar y dar de baja) | F6 | Laptop · **boceto en el lienzo (shadcn)** |
| C03 | Orden a GRAVITY con tarjeta de confirmación y modo privado | F4, secciones 7 y 16 | Laptop · **boceto en el lienzo (shadcn)** |
| C04 | Hábito a eliminar (panel) y SOS «Tengo un antojo» | F3 | Teléfono |
| C05 | Cambio urgente de medicamento (Dueño) | F7 | Teléfono |
| C06 | Cocina: receta paso a paso | Sección 11 | Tablet vertical |
| C07 | Cambio de usuario con PIN o huella | F8 | Tablet |

**También sin boceto:** Hábitos (agenda, lector bíblico, revisión semanal), Finanzas fuera de «Semana», Cuidados fuera de «Mi turno» y la bitácora, el asistente de configuración, y los estados vacíos y de error. Dependen de los diseños de cada módulo (FINANZAS sección 8; HÁBITOS Anexo G).

## 24. Estilos: catálogo vigente (A a N) y rondas del 28/oct/2026

### 24.0 Catálogo vigente: letras reasignadas el 28/oct/2026

Las letras se reasignaron de la A a la N, **ordenadas por familia**, y los bocetos del lienzo compartido van en **una sola línea** en ese mismo orden. **Desde aquí, las letras de este catálogo son las vigentes.** Las letras de los textos anteriores (secciones 4 a 18 y la historia de las rondas de más abajo) son las **antiguas**; la columna «Antes» da la equivalencia.

| Nueva | Estilo | Familia | Antes | Boceto en el lienzo |
|---|---|---|---|---|
| **A** | Futurista (HUD) — **por defecto** | Tecnológico | A | Sí |
| **B** | Terminal | Tecnológico | G | Sí |
| **C** | Instrumental | Tecnológico | K | Sí |
| **D** | AI-First | Tecnológico | P | Sí |
| **E** | Minimalista oscuro | Oscuro sobrio | B | Sí |
| **F** | Bento oscuro | Oscuro sobrio | I | Sí |
| **G** | Calma / Ambient | Oscuro sobrio | U | Sí |
| **H** | Glass (noche o día) | Cristal | E | Sí |
| **I** | Glassmorphism vivo | Cristal | M | Sí |
| **J** | Aurora | Cristal | H | Sí |
| **K** | Minimalismo / Flat | Claro plano | L | Sí |
| **L** | Neumorphism / Soft UI | Claro plano | N | Sí |
| **M** | Neo-brutal | Carácter fuerte | J | Sí |
| **N** | Swagger (sport, neón) | Carácter fuerte | F | Sí (y en «Bici en vivo» del teléfono) |

**Decidido (28/oct/2026): estilos de la pantalla de la laptop = A, B, C y J** (Futurista, Terminal, Instrumental y Aurora). El resto del catálogo queda disponible para otros dispositivos y para elegir en Apariencia. En el lienzo, la línea **«Estilos»** muestra el catálogo A a N, y la línea de debajo, **«Pantallas de laptop»**, muestra la pantalla principal en esos cuatro estilos junto con las demás pantallas de laptop.

**Retirados (sin letra):** Claro sereno (antes C), Arquitectónico (antes D), Bento claro (antes O), Editorial (antes Q), Orbital (antes R), Línea del día (antes S), Paleta de comandos (antes T) y Bento 3D con módulos movibles (antes V).

**Cómo se eligen:** el estilo es una opción de Ajustes › Apariencia (C01, sección 23), global o por módulo (sección 5). Cada estilo debe cumplir las reglas de la sección 4: versión de día y de noche, excepciones de Cuidados y bici, y contraste mínimo.

### 24.1 Historia de las rondas (letras antiguas)

**Decidido:** se retiran **C · Claro sereno** y **D · Arquitectónico** (también quitados del lienzo compartido). Quedan A, B, E y F, más las propuestas siguientes.

**Ronda 1: cinco estilos propuestos** (letras G a K, aplicados en la pantalla principal de la laptop del lienzo compartido):

| Estilo | Cómo se ve | Dónde luce más | Costo / riesgo |
|---|---|---|---|
| **G · Terminal** | Consola: monoespaciada, verde fósforo o ámbar sobre negro, texto primero | Laptop, Ajustes › Desarrollador | Poco amable para la cuidadora y la pareja; mejor solo en laptop |
| **H · Aurora** | Degradados de malla que se mueven despacio, paneles suaves y cálidos | Pantalla principal, tablet de la casa | Animación constante: gasta batería en teléfono y tablet; se parece a E |
| **I · Bento** | Tarjetas grandes con una protagonista en degradado, números enormes (oscuro) | Teléfono y tablet, «Hoy» | Pide diseñar la rejilla de cada pantalla |
| **J · Neo-brutal** | Bordes negros gruesos, sombras duras y color plano | Bici, gimnasio, hábitos y rachas | Cansa en lectura larga; se solapa con F |
| **K · Instrumental** | Tablero de cabina: medidores, agujas y relojes analógicos | Gadgets (sección 6), tablet, pulsera | Más trabajo por gadget |

**Ronda 2: cinco estilos pedidos por el usuario** (letras L a P, también aplicados en el lienzo):

| Estilo | Cómo se ve | Dónde luce más | Costo / riesgo |
|---|---|---|---|
| **L · Minimalismo / Flat** | Claro, colores planos, sin bordes ni sombras, mucho espacio y un solo acento | Finanzas, sesiones largas | Parecido a B; poca personalidad por módulo |
| **M · Glassmorphism** | Paneles translúcidos y esmerilados sobre degradado vivo de día | Laptop y tablet | Parecido a E; esmerilado solo en laptop y tablet (regla de la sección 4); contraste a vigilar |
| **N · Neumorphism (Soft UI)** | Relieves suaves del mismo color del fondo, botones que se hunden | Tablet de la casa, estado de ánimo calmo | Bajo contraste de bordes: exige texto oscuro y estados con icono; el menos accesible |
| ~~O · Bento Grid (claro)~~ | **Retirado el 28/oct/2026** | — | — |
| **P · AI-First** | La conversación y lo proactivo van al centro: resumen generado, sugerencias, «lo que hice por ti» y «necesita tu confirmación»; los módulos pasan a una barra lateral | Pantalla principal de la laptop; desde la Fase 6 | Depende de la IA (Fase 6); en Fase 0 solo navega. El dinero nunca pasa por la IA |

**Ronda 3: cinco estilos con otra estructura** (letras Q a U); el usuario retiró Q, R, S y T el 28/oct/2026 y queda **U**:

| Estilo | Cómo se ve | Dónde luce más | Costo / riesgo |
|---|---|---|---|
| ~~Q · Editorial / Revista~~ | **Retirado el 28/oct/2026** | — | — |
| ~~R · Orbital~~ | **Retirado el 28/oct/2026** | — | — |
| ~~S · Línea del día~~ | **Retirado el 28/oct/2026** | — | — |
| ~~T · Paleta de comandos~~ | **Retirado el 28/oct/2026** | — | — |
| **U · Calma / Ambient** | Casi sin interfaz: una frase grande, luz ambiental que respira y una línea de estado | Tablet de la casa, modo en reposo y Zero UI | Poca información a la vista; los módulos quedan detrás de «Módulos» |

**Retirados el 28/oct/2026 (a petición del usuario):** O (Bento claro), Q (Editorial), R (Orbital), S (Línea del día), T (Paleta de comandos) y V (Bento 3D con módulos movibles). Se quitaron del lienzo compartido. Quedan como candidatos: A, B, E, F, G, H, I, J, K, L, M, N, P y U.

**Solapes que conviene decidir:** L con B, M con E, J con F. Si se eligen ambos de un par, uno debe aportar algo que el otro no.

**Recomendación (propuesta):** A, K y P como candidatos principales para la pantalla principal de la laptop (Futurista, Instrumental y AI-First responden a «tipo JARVIS»); I para «Hoy» en teléfono y tablet; F para bici y entrenamiento. Neumorphism (N) solo con variante de alto contraste.

**Siguiente paso:** elegir un estilo global y una personalidad por módulo. Cada estilo debe cumplir las reglas de la sección 4: versión de día y de noche, excepciones de Cuidados y bici, contraste mínimo.

## 25. Diferencias con el contrato de conexión v2.0 (el contrato no se modifica)

Este documento describe **una sola app** (GRAVITY con módulos). El contrato v2.0 describe **tres apps independientes**. Estas son las diferencias de **pantalla** que hoy chocan con el contrato; ninguna se resuelve aquí.

| # | Lo que muestra este documento | Lo que dice el contrato v2.0 |
|---|---|---|
| 1 | La pantalla principal muestra Finanzas (aunque con monto oculto) | GRAVITY no ve dinero, cuentas ni precios (9.4) |
| 2 | La pantalla principal y el modo privado muestran Cuidados (turno, medicamento) | GRAVITY no ve datos clínicos de la persona bajo cuidado (9.4); la app de cuidados es externa y su esquema es borrador (6) |
| 3 | GRAVITY registra gastos por orden, con confirmación | GRAVITY solo abre pantallas por enlace, no escribe ni confirma (9.2) |
| 4 | Las herramientas de la API leen datos: `habitos.resumen_hoy`, `finanzas.saldo_categoria`, `cuidados.siguiente_medicamento` | GRAVITY no lee bases de datos de las otras apps (9.1) |
| 5 | Roles y personas con acceso a módulos (cuidadora, hermana, tablet Casa) | El contrato no define roles |
| 6 | Hábitos, Finanzas y Cuidados son módulos de una app | Cada app se instala y funciona sin las otras (2) y hay un solo escritor por dato (1) |
| 7 | El Coach pasa a GRAVITY (sección 9) | Hábitos conserva su pestaña Coach en su diseño (Anexo G) |
| 8 | La navegación del teléfono es por rol | Los diseños de Hábitos y Presupuesto tienen navegación propia |

**Lo que sí coincide:** IA solo por función y sin datos financieros ni de salud de terceros; confirmación antes de escribir; privacidad visible; funciona sin conexión; sin montos en la pulsera.

**Documentos de pantallas de las apps individuales** (`PANTALLAS_PENDIENTES.md` en HABITOS, `PANTALLAS_Y_NAVEGACION.md` en FINNZAS y `UX_PROVISIONAL.md` en este repositorio) describen el modelo de apps independientes. Quedan como referencia del modelo del contrato. Si se confirma el modelo de este documento, habrá que reconciliarlos.

## 26. Preguntas nuevas

1. ¿Los dos modelos (una app con módulos / tres apps del contrato) conviven, o uno reemplaza al otro? Define qué hacer con los documentos de HABITOS y FINNZAS.
2. De los estilos G a P, ¿cuáles pasan a ser opciones de la app y cuál es el predeterminado? ¿Qué hacemos con los solapes (L/B, M/E, O/I, J/F)?
3. Con el modo privado activo, ¿la tarjeta de confirmación (C03) pide «Mostrar para confirmar» o muestra el monto siempre en la confirmación?
4. En C04, ¿la cuenta atrás del SOS es de 10 minutos (como en Hábitos G.3.7) o editable?
5. En C07, ¿cuántos intentos de PIN antes de bloquear la tablet?
6. Zero UI: ¿qué automatizaciones quieres activar primero y cuáles señales tienes disponibles hoy (pulsera, puente de casa)?

## 27. Modos de interacción: voz (VUI) y Zero UI

Dos modos que el diseño debe contemplar además de la pantalla. Bocetos en el lienzo compartido: «VUI · Interfaz por voz» y «Zero UI · Sin pantalla».

### 27.1 VUI: interfaz por voz (propuesta)

- **Flujo en cinco pasos:** activar → escuchar → entender → confirmar → resultado. La pantalla muestra lo que se oyó, lo que se entendió y la tarjeta de confirmación; el resto pasa a segundo plano.
- **Activación por dispositivo:** laptop (Ctrl + Espacio o la palabra «Gravity»), tablet («Mantén para hablar»), teléfono (botón de micrófono), bocinas («Hey Google», solo frases fijas).
- **Reglas que ya fija este documento (sección 16):** voces configurables por persona; siempre dice lo que hizo; pide confirmación antes de escribir; **nunca dice montos** con el modo privado, en el modo Casa ni por las bocinas; trato de tú, y textos impersonales en Cuidados; sin conexión, solo órdenes locales.
- **Estados de la voz:** vacío («Di una orden»), escuchando, no entendí («No te entendí, ¿lo intento otra vez?»), sin permiso de micrófono (explicación y cómo concederlo), error.
- **Accesibilidad:** toda orden por voz tiene equivalente táctil o por teclado; el texto reconocido se ve antes de actuar; nada obliga a mirar la pantalla al manejar o en la bici.

### 27.2 Zero UI: sin pantalla (propuesta)

- **Idea:** GRAVITY actúa por contexto y automatización y reduce la interfaz a un aviso mínimo (vibración, voz breve o notificación) y a un registro de lo que hizo.
- **Cadena:** señales (hora, ritmo y GPS en bici, puente de casa, Health Connect, contexto de la tablet) → reglas de contexto → acción silenciosa → aviso mínimo.
- **Escenarios propuestos:** salida en bici (pasa a alto contraste), hora del medicamento (aviso a la cuidadora de turno, que confirma «Ya se dio»), cambio automático a oscuro por la hora, regreso al modo Casa tras 2 minutos sin uso, transición de dormir por bocina con frase fija, copia de seguridad a las 03:00 (aviso solo si falla).
- **Límites (obligatorios):** lo que escribe datos siempre pide confirmación (principio 6); dinero y medicamentos nunca se registran solos; el dinero no pasa por la IA; sin montos ni datos clínicos en la pulsera, las bocinas, la pantalla bloqueada ni el modo Casa; los medicamentos y los cambios urgentes suenan aun en horas silenciosas (sección 17).
- **Control:** cada automatización se enciende o apaga por módulo; una lista «Qué hizo GRAVITY» muestra lo ocurrido y permite deshacer.
- **Pendiente:** definir qué señales están realmente disponibles (por ejemplo, qué datos comparte la pulsera y qué expone el puente de casa) antes de comprometer escenarios.

## 28. shadcn/ui para complementar las pantallas (propuesta)

**Decisión del usuario (28/oct/2026):** usar **shadcn/ui** para complementar las pantallas.

### 28.1 Qué es y para qué se usa aquí

shadcn/ui no es una librería que se instala: es un conjunto de componentes (Card, Button, Badge, Tabs, Table, Switch, Select, Input, Alert, Dialog, Command, Sheet, Avatar, Separator…) que se **copian al proyecto**, construidos con React, Tailwind CSS y Radix UI, y se tematizan con **variables CSS** (`--background`, `--primary`, `--border`, `--radius`…). Aquí se usa para las pantallas de **laptop** que son formularios, tablas, diálogos y paletas; el núcleo animado y los gadgets siguen siendo propios de cada estilo.

### 28.2 Cómo se combina con los estilos

- Cada estilo (A a N) es un **tema de shadcn**: un juego de variables CSS. Cambiar de estilo cambia el tema, no los componentes.
- Los bocetos de C01, C02 y C03 usan los componentes de shadcn con el tema del estilo A (Futurista, noche). Para B, C o J basta sustituir las variables.
- Equivalencias: tarjeta de módulo → `Card`; chips de estado → `Badge`; selector de estilo → `RadioGroup` en tarjetas; Claro/oscuro → `Select` + `Switch`; personas y roles → `Table` + `Dialog`; confirmación de una orden → `Card` o `AlertDialog`; barra de órdenes y Ctrl + K → `Command`; panel lateral → `Sheet`; atajos → `Kbd`.
- Las reglas de la sección 4 siguen mandando: capas de estilo, excepciones de Cuidados y bici, y contraste mínimo.

### 28.3 Lo que implica para la arquitectura (sin decidir)

shadcn/ui es para **web (React)**. Esto afecta decisiones que siguen abiertas:

| Tema | Implicación |
|---|---|
| Laptop (Windows) | Encaja bien: una aplicación web de escritorio (por ejemplo con Tauri o Electron) con React, Tailwind y shadcn/ui |
| Android | shadcn/ui no corre en nativo. Opciones: la misma web como PWA o envuelta (Capacitor), o una interfaz móvil aparte con otro conjunto de componentes. El 3D y el esmerilado completo se evitan en teléfono (sección 4) |
| Tablet | Igual que Android |
| Apps independientes (Hábitos y Presupuesto) | Su diseño habla de Flutter. No usarían shadcn: la unidad visual se lograría con los **mismos tokens** (color, tipografía, radios), no con los mismos componentes |
| Stack de GRAVITY | Sigue **sin decidirse**. Esta sección solo registra que shadcn orienta la laptop hacia web con React |

### 28.4 Decisiones del 28/oct/2026 (sustituyen las preguntas anteriores)

1. **Teléfono y tablet son Flutter.** shadcn/ui (web) **no se usa como librería** en ellos: solo se toman sus patrones (insignias, pestañas segmentadas, tarjetas, hojas, búsqueda, interruptores) como inspiración.
2. **Los tokens son independientes por app y cambian según la función.** No hay un conjunto de tokens común obligatorio entre GRAVITY, Hábitos y Presupuesto.
3. **Se toman elementos de varios estilos** para mejorar la interfaz; no se exige un estilo único por app.
4. Pendiente: ¿qué otras pantallas de laptop quieres con shadcn (Finanzas › Semana, APIs o todas)?

## 29. Móvil: pantalla principal (3 propuestas de teléfono y 3 de tablet)

Propuestas en el lienzo compartido (filas «Móvil · Teléfono» y «Móvil · Tablet»). Son aproximaciones en HTML de lo que se construirá en Flutter; no son código final. Usan los mismos datos de ejemplo y no muestran dinero real (los montos van ocultos).

### 29.1 Teléfono (390 × 844), pantalla principal

Decisión del 28/oct/2026: se descartan las propuestas K (Flat claro) y N (Swagger) y se agregan D, G, H, I, J y L. Cada boceto lleva en el título la letra de su estilo.

| Estilo | Idea |
|---|---|
| D AI-First | Barra «¿Qué necesitas?» arriba con sugerencias; acento violeta-cian |
| F Bento oscuro | Mosaico de tarjetas, «Sigue» en degradado, anillo de hábitos |
| G Calma | Fondo azul profundo, tipografía ligera, paneles translúcidos y botones en píldora |
| H Glass noche/día | Capas translúcidas sobre degradado; en teléfono sin esmerilado |
| I Glassmorphism vivo | Manchas de color vivas con paneles translúcidos; sin esmerilado en teléfono |
| J Aurora | Fondo oscuro con banda de aurora, bordes y acentos verde menta |
| L Neumorphism | Claro, relieve suave; texto oscuro para mantener el contraste |

### 29.2 Tablet en horizontal, Modo Casa (1280 × 800)

Sin dinero ni datos clínicos; recordatorios solo genéricos; contextos General, Cocina, Gimnasio y Cuidados; cambio de usuario con PIN o huella; botón «Mantén para hablar». Mismos estilos que el teléfono, en orden alfabético: **D, F, G, H, I, J y L** (se descarta la propuesta C Instrumental). En tablet sí se permite el esmerilado real (H e I).

### 29.3 Preguntas

1. ¿Cuál propuesta de teléfono y cuál de tablet se quedan, o se combinan elementos?
2. ¿Los tokens de Cuidados (siempre claro y de alto contraste) se definen aparte de los del resto del teléfono?

## 30. Teléfono: bicicleta, entrenamiento y running (estilos F, J y N)

Fila nueva del lienzo compartido: tres pantallas en vivo, cada una en los estilos F Bento oscuro, J Aurora y N Swagger (9 bocetos de 390 × 844). Son propuestas de pantalla; el cálculo y el guardado dependen de la fuente de datos que se defina.

| Pantalla | Contenido del boceto |
|---|---|
| Bicicleta | Velocidad grande, distancia, tiempo, cadencia, pulso, gráfica de velocidad, Pausa / Vuelta / Terminar. Siempre alto contraste (sección 4) |
| Entrenamiento | Peso y repeticiones de la serie actual, descanso, siguiente ejercicio, series del ejercicio, Serie hecha / Saltar descanso / Terminar |
| Running | Ritmo grande, distancia, tiempo, pulso, cadencia, ritmo por kilómetro, Pausa / Vuelta / Terminar |

Segunda ronda (29/oct/2026): se conserva como bici N la versión mejorada sobre el diseño `TelBici` (personalidad sport / swagger) y las ocho pantallas restantes se rehacen con el mismo lenguaje:
- **Indicador principal** en arco con marcas, banda de zona objetivo, valor máximo y comparación con el promedio u objetivo.
- **Métricas** en tres tarjetas, barra de zonas de pulso y barra de meta.
- **Gráfica propia de cada pantalla:** perfil de elevación con tu posición (bici), series con esfuerzo 6–10 y siguiente ejercicio (entrenamiento), ritmo por kilómetro e intervalo siguiente (running).
- **Controles grandes**; «Terminar» exige mantener presionado para evitar toques accidentales.

Notas:
- Los datos de ejemplo son inventados; no hay datos de salud de terceros.
- Según el contrato v2.0, el ejercicio y las rutinas son de Hábitos y GRAVITY solo abre pantallas por enlace. Estas pantallas quedan como **propuesta visual**; quién las ofrece (GRAVITY o Hábitos) es una pregunta abierta, sin tocar el contrato.

## 31. Teléfono: idiomas (estilos D, F, G y M)

Fila del lienzo compartido con tres pantallas de inglés, cada una en D AI-First, F Bento oscuro, G Calma y M Neo-brutal (12 bocetos de 390 × 844). Decisión del 29/oct/2026: estos cuatro estilos sustituyen a F, J y N de la primera propuesta.

| Pantalla | Contenido del boceto |
|---|---|
| Lección del día | Progreso de 8 ejercicios, frase a traducir con audio normal y lento, respuesta armada con palabras, pista, precisión, XP y meta de minutos |
| Conversación | Role-play «En el café» por voz: burbujas, corrección marcada con pronunciación, objetivo de la escena, acento y fluidez, botón Hablar |
| Vocabulario | Tarjeta con palabra, fonética, significado y ejemplo; siguientes palabras, meta diaria y calificación Otra vez / Difícil / Bien / Fácil con intervalos |

Notas:
- Según el contrato v2.0, el inglés es de Hábitos y GRAVITY solo abre pantallas por enlace: son **propuesta visual**; queda abierto quién las ofrece.
- La conversación usaría un modelo de lenguaje: solo si el usuario lo activa (se ve en la etiqueta «IA activada por ti»), con lo mínimo necesario, sin nombres ni datos personales y sin la clave dentro de la app.
- Frases y datos de ejemplo inventados.

## 32. Teléfono: alimentación (estilos D, F, G y M)

Fila del lienzo compartido con cuatro pantallas, cada una en D AI-First, F Bento oscuro, G Calma y M Neo-brutal (16 bocetos de 390 × 844). Los estilos son una suposición (los mismos de idiomas) a confirmar.

| Pantalla | Contenido del boceto |
|---|---|
| Plan de hoy | Comidas por tiempo (desayuno, colación, comida, cena) con estado, la siguiente destacada, reglas del día, cumplidas, adherencia y racha |
| Marcar comida | Platillo del plan, alternativas, estado (cumplido, parcial, sustituido, omitido) y campo «platillo real» (máx. 200 caracteres) |
| Seguimiento semanal | Cuadrícula de 7 días por 4 comidas con estado, conteos, adherencia, aviso de privacidad y botón Compartir |
| Receta guiada | Paso actual en letra grande, temporizador, ingredientes del paso, siguiente paso, porciones y tiempo total; manos libres con voz («siguiente», «repite») y pantalla encendida |

Notas:
- Sin dinero, cuentas, precios, peso, agua ni datos clínicos, como en el contrato v2.0 (secciones 4 y 5). Los datos son ejemplos inventados.
- El plan y el seguimiento pertenecen a Presupuesto y Hábitos; son **propuesta visual** y queda abierto quién las ofrece (GRAVITY solo abre pantallas por enlace).
- Las recetas no llevan precios, costos ni datos de salud. De dónde salen las recetas (plan exportado, propias o de una fuente verificada) queda por definir.
- Falta, si se quiere, la pantalla de revisión al importar un plan (validar, vincular integrante y confirmar).

## 33. Teléfono: espiritual (estilos D, F, G y M)

Fila del lienzo compartido con tres pantallas, cada una en D AI-First, F Bento oscuro, G Calma y M Neo-brutal (12 bocetos de 390 × 844). Los estilos son una suposición (los mismos de alimentación) a confirmar.

| Pantalla | Contenido del boceto |
|---|---|
| Devocional del día | Pasaje (Salmo 46:10, Reina-Valera 1960), reflexión breve, pregunta para pensar, avance del plan de lectura, tiempo y racha; botones Marcar leído, Audio y Nota |
| Oración y silencio | Círculo de respiración (inhala 4 s, exhala 6 s), tiempo restante, intención, sonido (silencio, lluvia, piano), sesiones de la semana y racha |
| Diario de gratitud | Semana con días escritos, tres líneas de gratitud, cómo estuvo el día interior, aviso de privacidad y botones Guardar, Dictar y Cerrar |

Notas:
- Según el contrato v2.0, lo espiritual es de Hábitos y no se comparte: son **propuesta visual** y GRAVITY solo abriría pantallas por enlace.
- El diario se guarda solo en el teléfono: sin exportar, sin compartir y sin IA. Ningún dato espiritual viaja en el JSON de seguimiento.
- El pasaje y la tradición de ejemplo son una suposición; el contenido real y la versión de la Biblia quedan por definir con la persona usuaria.

## Control de cambios (complemento)

| Versión | Fecha | Cambio |
|---|---|---|
| 0.6 | 28/oct/2026 | Se retiran los estilos C y D; catálogo de estilos reasignado A a N (24.0), en una sola línea en el lienzo compartido; O, Q, R, S, T y V retirados; modos VUI y Zero UI (sección 27); shadcn/ui (sección 28); estilos de laptop A, B, C y J; pantallas pendientes de diseño (C01 a C07, sin bocetos); diferencias con el contrato v2.0; preguntas nuevas |
| 0.7 | 28/oct/2026 | Móvil en Flutter; tokens independientes por app y función; shadcn solo como inspiración de patrones (28.4); sección 29 con 3 propuestas de teléfono (F, K, N) y 3 de tablet (G, I, C) |
| 0.8 | 28/oct/2026 | Teléfono principal: se descartan K y N; se agregan D, G, H, I, J y L; los bocetos del lienzo llevan la letra del estilo |
| 0.9 | 28/oct/2026 | Tablet principal con los mismos estilos que el teléfono (D, F, G, H, I, J, L); filas del lienzo en orden alfabético; se descarta C en tablet |
| 1.0 | 29/oct/2026 | Sección 30: bicicleta, entrenamiento y running en estilos F, J y N |
| 1.1 | 29/oct/2026 | Bici N mejorada; pantallas de bici, entrenamiento y running rehechas en F, J y N con indicador en arco, zonas, meta y gráfica propia |
| 1.2 | 29/oct/2026 | Sección 31: pantallas de idiomas (lección, conversación y vocabulario) en F, J y N |
| 1.3 | 29/oct/2026 | Idiomas: estilos D, F, G y M (sustituyen a F, J y N) |
| 1.4 | 29/oct/2026 | Sección 32: pantallas de alimentación (plan de hoy, marcar comida y seguimiento semanal) en D, F, G y M |
| 1.5 | 29/oct/2026 | Alimentación: pantalla de receta guiada en D, F, G y M |
| 1.6 | 29/oct/2026 | Sección 33: pantallas espirituales (devocional, oración y silencio, diario de gratitud) en D, F, G y M |
