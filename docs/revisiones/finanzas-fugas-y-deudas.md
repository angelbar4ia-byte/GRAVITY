# Revisión — Fugas silenciosas y deuda buena o mala (Finanzas)

Autor: agente finanzas · Fecha: 18/nov/2026 · Estado: **propuesta para el dueño; sin código**.
Petición (textual, resumen): clasificar los gastos en cuatro fugas (hormiga, fantasma, vampiro, zombie) y distinguir la deuda buena (por ejemplo, meses sin intereses para un objetivo específico) de la mala, avisando cuándo una se vuelve la otra.
Especificación que resulta de esta revisión: `docs/specs/fase-8-fugas-y-deudas.md`.

## 1. Qué se revisó

| Fuente | Qué miré |
|---|---|
| Decisiones | `docs/DECISIONES.md` D1 a D29, sobre todo D3, D4, D5, D6, D14, D18, D19, D20, D24, D25 |
| Convenciones | `docs/specs/fase-0-cimientos.md`, sección 4 |
| Diseño | `docs/modulos/finanzas/ESTRUCTURA_APP_PRESUPUESTO_SEMANAL.md` (v23): 5.0 bis a 5.0 ter, 5.2, 5.3, 5.3 bis, 5.3 ter, 5.9 bis |
| Especificaciones | `fase-1-finanzas.md`, `fase-2-finanzas.md`, `fase-8-finanzas-ampliaciones.md`, `fase-8-deudas-intereses.md`, `fase-8-patrimonio.md`, `fase-8-reportes-imagen-voz.md`, `fase-4-vista-temporal.md` |
| Código | `paquetes/finanzas_dominio/lib/src` (libro, categorías, deudas_detalle, estrategias_deuda, alertas, indicadores, reportes, ahorro_datos) y `app/lib/modulos/finanzas` |
| Servidor | Migraciones de Finanzas `20261021` a `20261137` y `avisos` (`20261102`, `20261103`) |
| Web | Definiciones de gasto hormiga, fantasma y vampiro, y criterios de deuda buena y mala (sección 5 de este documento) |

No hay código de fugas ni de deuda buena o mala en ninguna parte. Una búsqueda de "hormiga", "fantasma", "vampiro" y "zombie" en `docs`, `app/lib`, `paquetes` y `supabase` solo encuentra dos frases del diseño sobre el efectivo ("la diferencia suele ser gasto hormiga sin capturar", 5.0 bis 2 y 5.9 bis) y una nota de prueba del libro.

## 2. Qué cubre ya lo que existe

| Pieza existente | Dónde | Sirve para |
|---|---|---|
| Prioridad de cada categoría (`necesario`, `deseable`, `discrecional`) y naturaleza (fija, variable) | `fin_categorias`; `Categoria` en `categorias.dart`; diseño 5.2 | Excluir lo necesario de "hormiga" y separar lo recortable |
| Árbol de categorías con "Snacks y dulces", "Café y colaciones", "Comidas fuera", "Streaming y suscripciones", "Comisiones bancarias", "Intereses y cargos financieros" | Diseño 5.2 | Punto de partida de las reglas por categoría |
| Gastos fijos y reservas con frecuencia y fecha | `fin_compromisos`, `Compromiso` | Cobros recurrentes que la persona sí declaró |
| Ocurrencias esperadas de ingresos, compromisos y deudas (13 semanas) | `fin_ocurrencias` | Saber si una mensualidad se pagó a tiempo (estado `cumplida`, `retrasada`) |
| Intereses y cargos de cada corte (`intereses_centavos`, `cargos_centavos`, tasa y CAT) y pagos mínimo y sin intereses | `fin_estados_cuenta` (captura manual) | Señales de vampiro financiero y de pago mínimo |
| Costo estimado de deber por semana | `costoDeDeber` en `deudas_detalle.dart` | Costo de intereses (solo deudas con tasa) |
| Anualidad y comisión fija como gasto financiero, prorrateada por semana | Diseño 5.3 bis, regla 5 | Vampiro de tipo anualidad |
| Comisión por inactividad de una tarjeta (regla de la compra mínima) | Diseño 5.3 bis, regla 2 | Caso límite entre vampiro y zombie |
| Compra a MSI como deuda de tasa cero, con mensualidades, sin abono extra, que ocupa límite y cuenta en la carga de deuda | `fin_msi`, `Msi`, `mensualidadesMsi`, `pendienteDeMsi`, `usoDelLimite` | Base de la deuda buena |
| Semáforo de carga de deuda (verde menor de 20 %, ámbar de 20 a 35 %, rojo mayor de 35 %) y de uso del límite (30 y 60 %) | `Umbrales` en `indicadores.dart`; `fin_parametros` | Dos de los criterios de deuda buena o mala ya existen y son editables |
| Aviso "cuando se acumulan muchas MSI en un mismo mes" | Diseño 5.3 bis, punto 2 | Idea inicial de la señal de acumulación (sin número) |
| Objetivos con apartado de ahorro, bienes con valor y fecha de captura | `fin_objetivos`, `fin_bienes` (Fase 8, bloque 3) | Un objetivo y un bien contra los que declarar el propósito de una deuda |
| Reportes de gasto por categoría y por semanas | `reportes.dart` | Base del reporte de fugas |
| Alertas con catálogo cerrado, texto de hasta 40 caracteres sin cifras ni nombres | `TipoAlerta`, `avisos`, D20 | Forma de avisar sin romper D3 |
| Conciliación del estado de cuenta (coincide, falta en la app, falta en el banco), con el ejemplo "Cargo de suscripción: falta en la app" | Diseño 5.0 bis 3; Fase 8 bloque 1 | Fuente natural de cobros fantasma (pendiente por falta de la lista de bancos) |

## 3. Hallazgos

Severidad: **A** = sin esto la petición no se puede cumplir; **M** = se puede, pero con una solución menos buena; **B** = detalle o riesgo menor.

### 3.1 Qué falta para las fugas

| # | Sev. | Hallazgo | Consecuencia |
|---|---|---|---|
| F-1 | A | No existe ninguna clasificación de fugas, ni regla, ni pantalla, ni aviso. | Hay que especificarlo y construirlo entero (ver la especificación). |
| F-2 | A | `fin_movimientos` no tiene columna de **comercio** (ni etiquetas ni beneficiario), aunque el diseño 5.2 dice que cada gasto lleva comercio y etiquetas y que la voz extrae el comercio. Solo hay `nota` (200 caracteres). En `fin_msi` sí hay comercio. | Reconocer que dos cargos son "el mismo cobro" solo con categoría y monto confunde servicios distintos. Se propone agregar un campo opcional `comercio` a los movimientos nuevos (sin tocar los anteriores). La hormiga se puede detectar sin comercio (por subcategoría); fantasma, vampiro y zombie funcionan mejor con él. |
| F-3 | A | No existe el concepto de **suscripción** ni de **cobro automático**. `fin_compromisos` cubre gastos fijos (renta, servicios), pero no guarda comercio, si se usa, ni si se canceló. Las suscripciones solo son una subcategoría de Entretenimiento ("Streaming y suscripciones"). | No hay dónde anotar "esto lo uso" o "esto ya lo cancelé". Se propone una tabla de **patrones de cobro** que se detecta del libro y se liga, si existe, a un compromiso. |
| F-4 | A | No hay ningún dato de **uso** (si la persona usa o no un servicio). La app no puede saberlo sola. | Zombie solo puede salir de lo que la persona responde. Se propone una pregunta breve y espaciada, "¿Lo usaste?". Sin respuesta no se acusa. |
| F-5 | M | El libro es **solo-agregar**: una clasificación no puede editarse en el movimiento. | La clasificación vive en tablas aparte, también solo-agregar, con corrección por una fila nueva que reemplaza a la anterior (análogo al contraasiento). Es compatible con las reglas de oro. |
| F-6 | M | El orden de prioridad entre fugas no existe y las fuentes públicas se traslapan: unas llaman "vampiro" a la suscripción olvidada y otras la llaman "fantasma". Lo que escribió el dueño las separa mejor, pero un mismo cobro (por ejemplo, una suscripción olvidada que además subió de precio) cumple varias definiciones. | Se fija una sola fuga principal por cobro con un árbol de decisión (especificación, sección 3). |
| F-7 | M | La **conciliación con el estado de cuenta en PDF** (la fuente más fiable de cobros fantasma, porque trae lo que el banco cobró y la persona nunca capturó) está pendiente: falta la lista de bancos (Fase 8, bloque 1). `fin_estados_cuenta.via` solo admite `manual`. | La detección de fantasmas empieza con lo que haya en el libro (importación del estado, captura manual) y mejora cuando llegue el PDF. Dependencia declarada. |
| F-8 | M | Las **comisiones, anualidades e intereses** sí existen como gasto financiero, pero no hay regla de "constante y que crece", ni reporte que los junte (el diseño menciona un reporte de comisiones por banco, no construido). | Se define el vampiro financiero y el vampiro creciente, y un reporte. |
| F-9 | M | Los **avisos** son un catálogo cerrado en tres lugares: `TipoAlerta` (Dart), la restricción `check` de `avisos.tipo` y las funciones `avisos_severidad` y `avisos_tipo_emitible`. Agregar tipos exige migración y cambio de la app. | Se proponen cuatro tipos nuevos con texto genérico (sin cifras ni nombres). |
| F-10 | B | La conciliación de efectivo del cierre semanal ya dice que la diferencia suele ser gasto hormiga, pero no la mide. | La hormiga la medirá de forma explícita. |
| F-11 | B | Para un libro **compartido** (por ejemplo, "Gastos de la casa") varias personas pueden contestar la misma pregunta de uso. | Gana la última respuesta y queda el historial de quién y cuándo. |

### 3.2 Qué falta para deuda buena y mala

| # | Sev. | Hallazgo | Consecuencia |
|---|---|---|---|
| D-1 | A | No existe el **propósito u objetivo declarado** de una deuda. `fin_msi` guarda comercio y descripción; `fin_objetivos` solo se liga a un apartado de ahorro; `fin_bienes` no se liga a deudas. | Sin objetivo no hay deuda buena. Se propone una declaración de propósito por deuda (solo-agregar), ligable a un objetivo o a un bien. |
| D-2 | A | No hay clasificación buena o mala ni su semáforo. El diseño trata un MSI como "deuda con tasa cero", sin juicio. | Se especifican criterios, semáforo y señales de cambio. |
| D-3 | A | No hay señales de **deterioro**: ni "MSI encadenados", ni "pagó solo el mínimo", ni "intereses en la tarjeta con MSI", ni cuántos MSI hay a la vez. Los datos para varias existen (`fin_estados_cuenta`, `fin_ocurrencias`, `fin_msi.fecha_compra`) pero nadie las calcula. | Se definen como reglas de dominio puro, con umbrales propuestos. |
| D-4 | M | "Costo financiero total" de un MSI es cero por diseño (tasa cero), así que no distingue una compra con sobreprecio. El diseño no guarda el precio de contado. | Se propone un campo opcional `precio_contado_centavos`; si se captura y el total a meses lo supera, se avisa. Sin ese dato, no se dice nada (no se inventa). |
| D-5 | M | Los umbrales de carga de deuda (20 y 35 %) están en el diseño como "ejemplo" y como valores por defecto, sin fuente. Las fuentes consultadas dan 30 % y 35 a 40 % (sección 5). | Se conservan los editables que ya hay y se cita la fuente con su reserva. |
| D-6 | M | No hay umbral para las MSI como parte del ingreso. La fuente encontrada es la opinión de una especialista (10 %), no una norma. | Se propone 10 % y 20 %, marcados como propuesta sin verificar. |
| D-7 | M | `fin_estados_cuenta` es captura manual: si no se captura, no hay datos de intereses ni de pago mínimo. | Una señal sin dato se muestra como "sin dato", nunca como "todo bien". |
| D-8 | M | La deuda mayor del hogar de ejemplo (el crédito automotriz) no tiene propósito en el diseño. Un auto se deprecia; según la fuente de Condusef puede ser deuda buena si genera ingreso o es herramienta de trabajo, y mala si es consumo. | Decisión del dueño (pregunta 5 de la especificación). |
| D-9 | B | Las deudas entre familiares (tasa cero, sin costo) no son ni buenas ni malas por costo. | Se marcan "Sin costo" y no entran al semáforo de calidad, pero sí a la carga total. |

### 3.3 Choques y encajes con las decisiones D1 a D29

| # | Sev. | Decisión | Hallazgo |
|---|---|---|---|
| C-1 | A | **D3** | D3 prohíbe que el modelo de IA en la nube vea "cifras, cuentas, precios ni comercios". Por eso **el comercio de un cobro tampoco puede ir a la nube**. La clasificación es local y por reglas. Cualquier ayuda de IA solo puede ser local en la laptop (opción futura de D3) y opcional. |
| C-2 | M | **D3 y diseño 5.2, regla 8** | La regla dice que, con permiso, puede salir "texto sin cuentas ni datos personales" para frases complejas. Un comercio es dato de dinero según D3. **Propuesta:** aclarar que ese texto nunca contiene comercio, monto ni cuenta. Es una aclaración, no un cambio de D3. |
| C-3 | A | **D5 y D19** | Cada persona ve su libro; Papá lo llevan sus albaceas; la cuenta maestra solo lee con consulta registrada; familiar, cuidador y Casa no ven Finanzas. Las tablas nuevas deben usar las mismas funciones (`fin_puede`, `fin_deudas_puede_ver`). Compatible. |
| C-4 | M | **D4** | La laptop es el sistema completo; el teléfono, lo mínimo. En el teléfono solo se ve el estado y se contesta la pregunta de uso; declarar el propósito de una deuda es de la laptop (igual que los formularios de deuda de la Fase 2). |
| C-5 | M | **D14 y D6** | La tablet pública y las bocinas no muestran ni dicen nada de esto. |
| C-6 | M | **D20** | Los avisos van con texto de catálogo, sin cifras, sin comercio, sin nombres, y por FCM solo viaja `{v, id}`. Las alertas nuevas lo respetan. |
| C-7 | M | **D24** | La vista temporal de Finanzas de Papá para el familiar no incluye las pantallas nuevas (propuesta: se quedan fuera para no ampliar lo autorizado). |
| C-8 | B | **D18** | Los montos se ocultan solos a los pocos minutos; las pantallas nuevas usan el mismo componente de monto. |
| C-9 | B | **D25** | Se mantiene el límite de avisos no críticos por día; las preguntas de uso se juntan en una revisión mensual en lugar de avisos sueltos. |
| C-10 | B | **ROADMAP** | El bloque no tiene lugar en la Fase 8 (los bloques 1 a 5 ya están asignados). Se propone llamarlo **bloque 6** y que el arquitecto lo apruebe. |

Ninguna decisión confirmada se contradice; solo hay una aclaración propuesta (C-2) y una nueva decisión propuesta (sección 6).

## 4. Qué NO se puede resolver solo con reglas (límites honestos)

1. **Saber si algo se usa.** La app no ve el uso. Solo la respuesta de la persona o un dato que ella capture.
2. **"Lo que ya no sirve".** Es un juicio de la persona; la app solo detecta candidatos (dos cobros parecidos, un plan viejo del mismo comercio).
3. **Que el objetivo de una deuda siga existiendo.** Lo declara la persona; se puede ligar a un bien u objetivo de la app, que sí cambian de estado.
4. **Una "deuda buena" no es una garantía.** Un MSI que cumple todo hoy puede ser mala decisión si la persona pierde ingreso; el semáforo describe riesgo observable, no futuro.

## 5. Fuentes en la web (consulta del 18/nov/2026)

**Límite de la consulta:** el entorno no permitió abrir las páginas (los sitios están fuera de la red permitida de la sesión: error de resolución de nombre). Lo que sigue sale de los **resúmenes de resultados de búsqueda**, no de leer cada página, y ninguna cifra se verificó en la fuente primaria. Todo lo que se cita se marca así en la especificación.

| Clave | Dato | Fuente (enlace) | Estado |
|---|---|---|---|
| W1 | Gasto hormiga según Condusef: "pequeños desembolsos cotidianos que, sumados, representan una fuga importante". Ejemplos laborales con rango por compra: café de 12 a 90 pesos, bebidas de 10 a 60, comida de 35 a 170. | [El Imparcial, 5/jun/2024](https://www.elimparcial.com/dinero/2024/06/05/gastos-hormiga-que-realizas-en-el-trabajo-y-como-evitarlos/); [Mercado Pago](https://www.mercadopago.com.mx/blog/gastos-hormiga); [Condusef vía Banorte (PDF)](https://www.banorte.com/cms/CONDUSEF/2022/septiembre/cuida-tu-salud-evita-gastos-hormiga.pdf) | Rangos citados por prensa; no abrí el PDF |
| W2 | Los gastos hormiga pueden pasar de 12 % del ingreso anual (notas que citan a Condusef). | [El Imparcial, 6/abr/2024](https://www.elimparcial.com/dinero/2024/04/06/3-consejos-para-eliminar-completamente-los-gastos-hormiga-segun-la-condusef/) | Cita de prensa; **sin verificar** |
| W3 | Fantasma: cobros periódicos y automáticos de monto bajo que pasan inadvertidos aunque ya no se usen; vampiro: flujo constante de dinero que se va sin notarse. Las fuentes los traslapan. | [Uno TV](https://www.unotv.com/negocios/los-3-enemigos-que-podrian-dejarte-en-ceros-este-diciembre-hormiga-fantasma-y-vampiro/); [Mercado Pago, vampiro](https://www.mercadopago.com.mx/blog/que-son-los-gastos-vampiro); [Portafolio](https://www.portafolio.co/mis-finanzas/ahorro/que-es-el-gasto-vampiro-puede-estar-arruinando-su-economia-y-no-lo-sabe-641774) | Definiciones de divulgación, no normativas |
| W4 | **"Gasto zombie": no encontré ninguna fuente** que lo defina en México. | Búsqueda sin resultados | La definición es la del dueño |
| W5 | Deuda buena según Condusef: ayuda a incrementar el patrimonio, generar ingresos futuros o dar protección financiera, con beneficio que dura años y supera el costo; mala: financia consumo innecesario, bienes que se deprecian rápido o gastos cotidianos. | [El Imparcial, 13/jul/2026](https://www.elimparcial.com/dinero/2026/07/13/condusef-explica-cuando-una-deuda-es-buena-y-cuando-puede-afectar-tus-finanzas-estas-son-las-diferencias-que-debes-conocer/) | Prensa que cita a Condusef; sin verificar |
| W6 | Límite de deuda: Condusef recomienda que los pagos no pasen de 35 a 40 % del ingreso mensual (otra nota dice 30 %); en 2023 propuso un tope legal de 35 %, sin evidencia de que se aprobara. | [Expansión, 25/oct/2023](https://expansion.mx/economia/2023/10/25/condusef-limitar-endeudamiento-mexicanos); [El Imparcial, 2/abr/2024](https://www.elimparcial.com/dinero/2024/04/02/5-pasos-para-conocer-cual-es-tu-capacidad-de-endeudamiento/) | Dos cifras distintas; sin verificar |
| W7 | MSI: una especialista (Paulina Casso) sugiere que las compras solo a meses sin intereses no pasen de 10 % del ingreso mensual. Es opinión de una especialista, no de Condusef. | [El Imparcial, 4/feb/2026](https://www.elimparcial.com/dinero/2026/02/04/cuanto-de-tu-sueldo-es-seguro-destinar-a-compras-a-meses-sin-intereses-esta-es-la-regla-para-no-endeudarte-de-mas/) | Opinión; sin verificar |

No encontré una fuente que dé el costo oculto típico de un MSI (sobreprecio frente al precio de contado), ni un umbral de "cuántos MSI a la vez". Esos números se dejan como propuesta sin fuente.

## 6. Decisión nueva propuesta (para el arquitecto)

**D30 (propuesta).** Finanzas clasifica los gastos en cuatro fugas (hormiga, fantasma, vampiro, zombie) y las deudas en buena, en vigilancia o mala, **solo con reglas locales** sobre el libro de la persona. Una fuga principal por cobro; la persona decide y puede corregir; nada va a la IA en la nube ni a las bocinas (D3, D6). Aclaración a D3: el **comercio** cuenta como dato de dinero y no sale del dispositivo.

## 7. Qué recomiendo

1. Aprobar la especificación `fase-8-fugas-y-deudas.md` como **bloque 6** de la Fase 8, después de que el dueño responda las preguntas de su sección 12.
2. Construir primero el dominio puro (reglas y pruebas), luego la migración, luego las pantallas de la laptop y al final el teléfono.
3. No activar ninguna ayuda de IA en este bloque.
