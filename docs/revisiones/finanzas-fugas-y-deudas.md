# Revisión — Fugas silenciosas y deuda buena o mala (Finanzas)

Autor: agente finanzas · Fecha: 18/nov/2026 · Versión 0.3 (fuentes verificadas en gob.mx y bbva.com; respuestas del dueño incorporadas) · Estado: **propuesta para el dueño; sin código**.
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
| Web | Definiciones de hormiga, fantasma, vampiro y zombi; criterios de deuda buena y mala; límites de endeudamiento; MSI y tarjetas con intereses; cancelación de cobros (sección 5: lo verificado y lo no encontrado) |

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
| F-8 | M | Las **comisiones, anualidades e intereses** sí existen como gasto financiero, pero no hay regla de "constante y que crece", ni reporte que los junte (el diseño menciona un reporte de comisiones por banco, no construido). Tampoco hay detección de **servicios del hogar que se inflan** (luz, agua, gas) ni de **intereses por pagar solo el mínimo**, que el dueño pidió dentro de vampiro. | Se definen cuatro vías de vampiro (financiero constante, cobro que crece, servicio contra su mediana e intereses por el mínimo) y un reporte. |
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
| D-5 | M | Los umbrales de carga de deuda (20 y 35 %) están en el diseño como "ejemplo" y como valores por defecto, sin fuente. **Verificado:** Condusef recomienda no pasar de 30 % del ingreso y BBVA, de 30 a 35 % (W6). El "35 a 40 %" no se encontró en página primaria. | Se conservan los valores editables y se pregunta al dueño si baja el rojo a 30 % (pregunta 5 de la especificación). |
| D-6 | M | No hay umbral para las MSI como parte del ingreso. El 10 % es la opinión de una especialista que cita la prensa; **no lo encontré en una página primaria** (W7b). Sí está verificado el criterio cualitativo de Condusef: MSI solo para productos cuya vida útil supere la duración de la deuda (W7). | Se propone 10 % y 20 % como **[Propuesta]**; el plazo contra la vida útil queda con fuente. |
| D-7 | M | `fin_estados_cuenta` es captura manual: si no se captura, no hay datos de intereses ni de pago mínimo. | Una señal sin dato se muestra como "sin dato", nunca como "todo bien". |
| D-8 | M | El crédito automotriz no tenía propósito en el diseño. | **Resuelto por el dueño (18/nov/2026):** herramienta de trabajo, propósito `genera_ingreso`. La tarjeta con intereses es deuda mala y una deuda mala solo avisa. |
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

## 5. Fuentes en la web: verificación del 18/nov/2026

**Cómo se verificó.** Se abrieron y leyeron completas las páginas de `www.gob.mx` (Condusef, Profeco, PENSIONISSSTE) y `www.bbva.com`. **No estuvieron al alcance** `condusef.gob.mx`, `revista.condusef.gob.mx` (donde están las definiciones de la revista de Condusef) y los medios (El Imparcial, Expansión, Uno TV, Portafolio, Mercado Pago). Lo que solo salía de esos sitios queda **no encontrado** y su dato es **[Propuesta]**. Las citas son literales y breves; el detalle completo está en la sección 13 de la especificación.

| Clave | Dato | Estado | Fuente y texto citado |
|---|---|---|---|
| W1 | Definición de gasto hormiga y ejemplos | **Verificada** | Condusef, [gob.mx, 25/feb/2022](https://www.gob.mx/condusef/articulos/cuida-tu-bolsillo-de-los-gastos-hormiga?idiom=es): "Nombramos gastos hormiga a esos pequeños consumos diarios que realizamos sin pensar que al final del día afectan nuestras finanzas." Ejemplos de $20, $30, $15 y $25 que suman "90 pesos diarios". Condusef, [gob.mx, 14/may/2020](https://www.gob.mx/condusef/es/articulos/gastos-chiquitos-que-salen-caro): incluye también "plataformas de streaming… Uber, DiDi… Spotify" |
| W1b | Rangos por compra (café 12 a 90, bebidas 10 a 60, comida 35 a 170) | **No encontrada** | Solo prensa. El tope de $150 sigue siendo propuesta |
| W2 | Hormigas de más de 12 % del ingreso anual | **Verificada solo como cita de BBVA**; **no encontrada** en Condusef | [BBVA México](https://www.bbva.com/es/mx/salud-financiera/como-entender-y-controlar-los-gastos-hormiga-en-mexico/): "Según datos de la… (CONDUSEF), los 'gastos hormiga' pueden llegar a representar más del 12% de los ingresos anuales de una persona." |
| W3 | Fantasma y vampiro | **Verificada; las fuentes se contradicen** | [BBVA Perú](https://www.bbva.com/es/pe/salud-financiera/que-son-los-gastos-hormiga-fantasma-y-vampiro-y-como-identificarlos/): fantasma = "gastos en los que incurrimos sin darnos cuenta" (streaming, gimnasio sin usar); vampiro = fijos difíciles de detectar, con "fugas de agua, gas… instalaciones de luz". [BBVA México](https://www.bbva.com/es/mx/salud-financiera/detox-financiero-redirige-el-presupuesto-para-construir-bienestar/): "vampiros de suscripción: apps, plataformas de streaming o membresías que ya no se usan, pero siguen generando cargos automáticos". [PENSIONISSSTE](https://www.gob.mx/pensionissste/es/articulos/llegas-al-fin-de-la-quincena-sin-dinero-identifica-los-tipos-de-gastos-que-afectan-tu-presupuesto?idiom=es): fantasma = "pagos recurrentes que olvidamos… se deducen automáticamente" |
| W4 | "Gasto zombi" | **No encontrada** | Búsqueda en gob.mx, bbva.com y bbva.mx sin resultados. La definición es la del dueño |
| W5 | Deuda buena y mala | **Verificada (BBVA)**; la definición de Condusef **no encontrada** | [BBVA México](https://www.bbva.com/es/mx/salud-financiera/como-tener-una-deuda-sana-sostenible/): buena = "beneficios a largo plazo… créditos educativos, hipotecarios"; mala = "se rebasa la capacidad de pago o se adquiere sin una evaluación adecuada, generalmente para gastos no esenciales… el uso de un crédito para cubrir otro" |
| W6 | Límite de endeudamiento | **Verificado el 30 %**; el **35 a 40 %** no encontrado | Condusef, [gob.mx](https://www.gob.mx/condusef/prensa/condusef-recomienda-a-instituciones-financieras-cautela-en-el-otorgamiento-de-creditos) (sin fecha visible; cifras de la CNBV a dic/2012): "no supere el 30% de sus ingresos". BBVA: "entre el 30% y el 35% del ingreso" |
| W7 | MSI y vida útil | **Verificada** | Condusef, [gob.mx, 10/nov/2026](https://www.gob.mx/condusef/articulos/en-este-buen-fin-compra-con-conciencia?idiom=es): "Los Meses sin intereses se recomiendan para productos con una vida útil que supere la duración de la deuda" |
| W7b | MSI hasta 10 % del ingreso (especialista) | **No encontrada** | Solo prensa |
| W8 | Pago mínimo, intereses y MSI | **Verificada** | [BBVA](https://www.bbva.com/es/salud-financiera/que-es-el-pago-minimo-y-el-pago-para-no-generar-intereses-en-una-tarjeta-de-credito/): "Pagar sólo el mínimo aumenta el tiempo para liquidar el crédito e incrementa el costo financiero." |
| W9 | Cancelar un cobro: folio y queja | **Verificada** | Profeco, [gob.mx, 5/may/2026](https://www.gob.mx/profeco/prensa/profeco-orienta-a-la-poblacion-ante-cobros-automaticos-injustificados-al-cancelar-un-servicio?state=published): "los proveedores deben proporcionar a las personas un folio o número tras realizar la solicitud de cancelación"; la queja pide el "folio de cancelación". Profeco, [gob.mx](https://www.gob.mx/profeco/prensa/que-las-suscripciones-digitales-no-afecten-tu-presupuesto-profeco-te-orienta?idiom=es): "Si dos o más opciones resultan afirmativas, hay que considerar la cancelación inmediata." |

**Qué cambió respecto de la primera versión (que salió de resúmenes de búsqueda):** el 30 % de Condusef pasó de "dos notas que se contradicen" a verificado; el 35 a 40 % y el 10 % de MSI se quedan sin página primaria; los rangos de compra de la prensa no se encontraron, pero sí unos ejemplos de Condusef más bajos ($15 a $30); el 12 % está verificado solo como cita de BBVA; "zombi" sigue sin fuente; y apareció una fuente para el folio de cancelación (Profeco) y otra para MSI contra vida útil (Condusef). No encontré un umbral de CAT ni de cuántos MSI a la vez; esos números siguen como propuesta.

## 6. Decisión nueva propuesta (para el arquitecto)

**D30 (propuesta).** Finanzas clasifica los gastos en cuatro fugas (hormiga, fantasma, vampiro, zombie) y las deudas en buena, en vigilancia o mala, **solo con reglas locales** sobre el libro de la persona. Una fuga principal por cobro; la persona decide y puede corregir; nada va a la IA en la nube ni a las bocinas (D3, D6). Aclaración a D3: el **comercio** cuenta como dato de dinero y no sale del dispositivo.

## 7. Qué recomiendo

1. Aprobar la especificación `fase-8-fugas-y-deudas.md` (v0.3) como **bloque 6** de la Fase 8, después de que el dueño responda las preguntas abiertas de su sección 12.2.
2. Construir primero el dominio puro (reglas y pruebas), luego la migración, luego las pantallas de la laptop y al final el teléfono.
3. No activar ninguna ayuda de IA en este bloque.
