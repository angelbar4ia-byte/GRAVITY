# Especificación — Fase 8 · Bloque 6: Fugas silenciosas y deuda buena o mala (Finanzas)

> v0.3, 18/nov/2026 (v0.1 y v0.2 el mismo día; v0.3 verifica las fuentes en su página y incorpora las respuestas del dueño de la sección 12.1). **Propuesta para aprobación del dueño; sin código.** Base: `docs/revisiones/finanzas-fugas-y-deudas.md` (hallazgos F-1 a F-11, D-1 a D-9, C-1 a C-10), D3, D4, D5, D6, D14, D18, D19, D20, D24, D25 y el diseño de Finanzas v23 (5.2, 5.3, 5.3 bis, 5.9 bis). Nombre del archivo ajustable al esquema de fases; el bloque 6 lo asigna el arquitecto.
>
> **Convención de esta especificación.** Todo número de umbral lleva la etiqueta **[Propuesta]** (valor sugerido, editable por libro, sin fuente que lo respalde) o **[Fuente W#]** (clave de la sección 13: la página se abrió el 18/nov/2026 y el texto citado está ahí con su URL). Lo que no se encontró en una página alcanzable queda **[Propuesta]** y así se dice. Ningún umbral aquí es una norma. Los montos de los ejemplos son **ilustrativos e inventados** para probar las reglas; no son precios reales de ningún comercio.

## 1. Resultado utilizable

1. En **Finanzas › Fugas** (laptop) la persona ve cuánto se le va, por semana y por año, en cuatro tipos de fuga, con la lista de cobros que la app no sabe cómo clasificar y que necesitan una respuesta suya de dos toques.
2. Cada cobro cae en **una sola fuga principal**, con la regla que la puso ahí y un botón **"No es así"** si no cuadra. Corregir no borra nada: queda una fila nueva que reemplaza a la anterior.
3. En **Finanzas › Deudas** cada deuda muestra si es **buena**, **buena en vigilancia**, **mala** o **por declarar**, con las señales que lo explican. Una compra a meses sin intereses (MSI) con un objetivo declarado y al corriente es buena; la app avisa cuando se está volviendo mala.
4. En el teléfono se contesta la pregunta "¿Lo usaste?" y se ve el semáforo de cada deuda, sin formularios largos (D4).
5. Todo se calcula **en el dispositivo, con reglas**. Ningún comercio, monto ni cuenta va a la IA en la nube ni a las bocinas (D3, D6).

## 2. Principios y convenciones

1. **Libro solo-agregar.** Ninguna regla edita un movimiento. Las clasificaciones, respuestas y declaraciones son tablas aparte, también solo-agregar; lo vigente es la fila más reciente (misma técnica de los estados de cuenta, Fase 2).
2. **Dinero en centavos.** Entero. Los porcentajes se comparan con la **fracción exacta** (convención 4 de la Fase 1, `compararProporcion`); los puntos base redondeados hacia abajo solo se muestran. Los equivalentes por periodo usan la clase `Equivalente` y el reparto por mayor resto (R2) de `frecuencia.dart`.
3. **Semana en lunes.** Las ventanas se miden en semanas completas desde el lunes: **"4 semanas"** = las últimas 4 semanas de lunes a domingo terminadas; **"13 semanas"** = las últimas 13. El mes de referencia del ingreso es `ingreso semanal esperado × 52 ÷ 12`, redondeado (R1).
4. **Solo gastos vigentes.** Un gasto con contraasiento (anulación) **no cuenta**. Anular un gasto cambia las fugas de inmediato (criterio DF-12).
5. **Solo reglas, nada de IA.** Ver sección 9. La IA en la nube nunca ve nada de esto (D3, C-1).
6. **Una fuga principal por cobro.** Los totales de fugas nunca suman más que el gasto real (sin doble conteo).
7. **Falta dato no es "todo bien".** Si una regla necesita un dato que no existe (límite, estado de cuenta, precio de contado), la señal dice "sin dato" y no se evalúa.
8. **La persona manda.** La app propone y explica; no cancela nada, no mueve dinero y no bloquea un registro.
9. **Sin culpa.** Voz de la sección 10: describe lo que ve, ofrece una acción, no juzga a la persona.
10. **Identificadores** en español sin acentos (`PatronDeCobro`, `claseFuga`); textos de la interfaz con acentos.

## 3. Las cuatro fugas: definiciones operativas

Todas se calculan por **libro** (D19): el personal de cada quien, los compartidos de los que es miembro, y el de Papá solo para quien lo lleva.

### 3.0 Vocabulario de datos

| Término | Qué es |
|---|---|
| **Gasto vigente** | Movimiento `gasto` sin contraasiento. Los pagos de deuda, transferencias, ahorro e ingresos **nunca** son fuga (los intereses y cargos sí: son gasto financiero) |
| **Comercio normalizado** | Texto del comercio en minúsculas, sin acentos, sin números de referencia y pasado por el diccionario del hogar (5.2). Vacío si el gasto no lo trae |
| **Patrón de cobro** | Un cobro que se repite: mismo comercio normalizado y misma categoría (o, sin comercio, misma subcategoría y monto parecido). Se detecta solo y la persona puede crearlo a mano |
| **Cobro automático** | Cargo domiciliado o a tarjeta que no captura la persona: viene de una importación o conciliación, o la persona marcó "es un cargo automático" al registrarlo |
| **Recurrente** | Patrón con **al menos 3 cobros** en intervalos regulares **[Propuesta]**: semanal 7 ± 1 días, quincenal 15 ± 2, mensual 30 ± 3, bimestral 61 ± 4, anual 365 ± 7, y monto estable: cada cobro dentro de ± 10 % de la mediana **[Propuesta]** |
| **Reconocido** | La persona respondió "Sí, lo conozco" a la pregunta de reconocimiento, o el patrón nace de un compromiso que ella declaró (`fin_compromisos`) |
| **Uso** | Respuesta de la persona a "¿Lo usaste este periodo?": `lo_use`, `no_lo_use`. Solo cuenta lo que contestó |
| **Categoría recortable** | Categoría con prioridad `deseable` o `discrecional` y no protegida (existe en `fin_categorias`). Renta, servicios, medicinas y cuidados (`necesario` o protegida) no se consideran para hormiga, fantasma ni zombie |
| **Servicio del hogar** | Subcategoría de luz, agua o gas de "Vivienda y servicios" (editable por hogar; internet y telefonía fija se pueden agregar). Es necesario, así que solo puede ser **vampiro** por la regla V-C |
| **Mediana** | Mediana de los montos de los últimos periodos del mismo patrón (entero en centavos; con cantidad par, el promedio de los dos centrales, redondeado R1) |

### 3.1 HORMIGA: pequeño y frecuente

**Definición.** Gastos discrecionales de monto chico que se repiten tanto que, sumados, pesan, sin ser un cobro automático.
**Fuente conceptual [W1, verificada]:** Condusef, gob.mx: "Nombramos gastos hormiga a esos pequeños consumos diarios que realizamos sin pensar que al final del día afectan nuestras finanzas." Sus ejemplos suman $90 al día: café $20, torta $30, refresco $15 y boleada $25.
**Diferencia con Condusef:** la misma Condusef (W1, 2020) también llama "hormiga" a las suscripciones y aplicaciones (streaming, música, transporte por aplicación). Aquí las suscripciones **no** son hormiga porque son cobro automático y van por fantasma, zombie o vampiro; el transporte por aplicación sí puede ser hormiga.

Una **subcategoría** (nivel 2; si no hay, la categoría) es una **fuga hormiga** cuando, en las **últimas 4 semanas**, cumple las cuatro:

| # | Regla | Umbral |
|---|---|---|
| H1 | La categoría es recortable y los gastos **no** son cobro automático ni recurrentes contractuales | por categoría |
| H2 | Cada gasto vigente cuenta si su monto es **menor o igual** que el tope hormiga | **$150.00** (15 000 centavos) **[Propuesta]**. Los ejemplos de Condusef que sí pude verificar (W1) son de $15 a $30 cada uno; los rangos de "12 a 90" y "35 a 170" pesos que cita la prensa **no los encontré en una página de Condusef** (W1b). El tope de $150 queda como propuesta (pregunta 2) |
| H3 | Hay al menos **8 gastos** que cumplen H2 en las 4 semanas | 8 **[Propuesta]** |
| H4 | Los gastos aparecen en **3 de las 4 semanas o más** (descarta una sola semana de reunión, fiesta o viaje) | 3 de 4 **[Propuesta]** |
| H5 | La suma de esos gastos es **al menos 1 %** del ingreso mensual de referencia (descarta ruido que no pesa) | 100 pb **[Propuesta]** |

**Medida:** suma de las 4 semanas, promedio semanal (R2) y estimado anual (promedio semanal × 52).
**Alerta de conjunto (informativa):** si todas las hormigas juntas pasan de **5 %** del ingreso mensual de referencia **[Propuesta]**, el panel lo marca en ámbar con texto. La cifra de "12 % del ingreso anual" **está verificada solo como cita de BBVA México a Condusef** (W2); no la encontré en una página de Condusef, así que **no se usa como umbral**.

**Sin comercio:** la hormiga **no necesita comercio**. Funciona con lo que ya hay en el libro (categoría, monto, fecha).

**Ejemplos mexicanos (montos ilustrativos).** Café y pan dulce de camino al trabajo ($45, casi todos los días); refresco y papas en la tiendita ($28); taxi por aplicación de trayectos cortos que se podían caminar ($70, tres veces por semana); botana y cerveza individual de la tienda de conveniencia ($95).
**No son hormiga:** la despensa semanal (categoría necesaria), un solo gasto grande aunque sea innecesario, la colegiatura, los cobros de una suscripción (esos van por la sección 3.2 a 3.4).

### 3.2 FANTASMA: cobros que ni se recuerdan

**Definición del dueño:** cobros que ni se recuerdan ni se usan (suscripciones olvidadas, cargos automáticos).
**Regla medible:** un **patrón recurrente** (3.0) que es **cobro automático** y que **la persona no ha reconocido**.

| # | Regla | Umbral |
|---|---|---|
| F1 | Patrón recurrente (3 cobros regulares y monto estable) | 3 y ± 10 % **[Propuesta]** |
| F2 | Es cobro automático (viene de importación o conciliación, o marcado) | — |
| F3 | No está ligado a un compromiso declarado ni la persona lo ha reconocido | — |

**Estados de un fantasma candidato.** Al detectarlo nace **"Por reconocer"** (no se acusa). Se le pregunta una vez: *"Encontré un cobro que se repite. ¿Lo reconoces?"* con tres respuestas: **Sí, lo conozco** (sale de fantasma y entra al árbol de la sección 4 como recurrente reconocido), **No lo conocía** (queda **FANTASMA** confirmado; la acción sugerida es revisarlo con el banco o el comercio) y **Después** (sigue "Por reconocer" y se vuelve a ofrecer en la siguiente revisión mensual; **sin respuesta no se confirma nada**).
**Cobro tras una cancelación:** si la persona marcó un patrón como cancelado (3.4) y vuelve a aparecer un cobro del mismo patrón, nace **FANTASMA con la marca "cobrado tras cancelar"** (la acción sugerida es reclamarlo). La ayuda se basa en Profeco (W9, verificada): el proveedor debe dar un folio al cancelar, desinstalar la aplicación no detiene el cobro y, si el cobro sigue, la persona puede presentar una queja ante Profeco con identificación, contrato, **folio de cancelación**, comprobantes y el estado de cuenta. El texto de la app solo lo resume y manda a Profeco; no promete resultados.
**Nota sobre las definiciones del dueño:** su resumen pone las **comisiones bancarias que no se recuerdan** dentro de fantasma. Aquí una comisión de una cuenta o tarjeta **que sí está en la app** es vampiro (paso 1 del árbol), y una comisión **que la persona no reconoce** (de una cuenta que no registró) sí cae en fantasma por el paso 2. Se deja como pregunta 1.
**Medida:** monto por cobro, cadencia, equivalente semanal y anual (por `Equivalente`).
**Dependencia:** la fuente más fiable es el estado de cuenta (lo que el banco cobró y nunca se capturó). Mientras la conciliación en PDF siga pendiente (hallazgo F-7), el patrón se detecta con lo que haya en el libro, incluida la importación.

**Ejemplos (ilustrativos).** Un "seguro de celular" de $89 al mes que apareció en la tarjeta y que nadie recuerda haber contratado; el "plan premium" de una app que quedó después de la prueba gratis ($119 al mes); un cargo anual por antivirus ($799) que se renueva solo.

### 3.3 VAMPIRO: consumen de forma constante y crecen

**Definición del dueño:** consumen de forma constante y crecen: comisiones, intereses, anualidades, cargos que drenan.
Hay cuatro vías; basta una.

**V-A. Cargo financiero constante** (de una deuda o cuenta que la persona sí tiene en la app):

| # | Regla | Umbral |
|---|---|---|
| VA1 | Es interés, comisión o anualidad: los intereses y cargos de un estado de cuenta (`intereses_centavos`, `cargos_centavos`), o un gasto en "Comisiones bancarias" o "Intereses y cargos financieros", o la anualidad prorrateada (5.3 bis, regla 5) | — |
| VA2 | Aparece en **2 de los últimos 3 cortes o meses** **[Propuesta]** (constante). **Excepción (respuesta del dueño):** los **intereses cobrados por pagar solo el mínimo** (V-D) cuentan con **un solo corte** | 2 de 3; 1 en V-D |

**V-B. Cobro recurrente reconocido que crece:**

| # | Regla | Umbral |
|---|---|---|
| VB1 | Patrón recurrente reconocido en categoría recortable | — |
| VB2 | El último cobro supera al primero de los últimos 12 meses en **10 % o más**, o hubo **3 aumentos seguidos** | 10 % y 3 **[Propuesta]** |

El 10 % es un valor inicial **sin fuente** [Propuesta]; se podría comparar contra la inflación de INEGI (no consultada; pregunta 9).

**V-C. Servicio del hogar que se infla** (respuesta del dueño, 18/nov/2026): luz, agua y gas son necesarios y no se recortan, pero una cuenta que se infla es una fuga constante oculta en un costo fijo. Se detecta **contra su propia mediana**:

| # | Regla | Umbral |
|---|---|---|
| VC1 | Servicio del hogar (3.0) con **al menos 6 periodos** de historia en el libro (mensual, bimestral, según el patrón); con menos, "sin dato" | 6 periodos **[Propuesta]** |
| VC2 | Mediana de los **últimos 12 periodos** (o los que haya, mínimo 6) | 12 **[Propuesta]** |
| VC3 | **2 de los últimos 3 periodos** superan a la mediana en **25 % o más** (comparación exacta: `monto × 10 000 ≥ mediana × 12 500`) | 25 % y 2 de 3 **[Propuesta]** |

La acción sugerida es **revisar instalaciones y consumo** (fugas, equipos, tarifa), no cancelar. Estos servicios **nunca** son fantasma, zombie ni hormiga. Limitación honesta: el consumo cambia con la estación (calor, frío); si la persona marca "es por la temporada" el patrón queda en "Vigilar" y no se vuelve a proponer ese año. **Fuente conceptual [W3, verificada para Perú]:** BBVA Perú describe el vampiro como gasto fijo difícil de detectar, con ejemplos de "fugas de agua, gas, mal uso de electrodomésticos o problemas con las instalaciones de luz" y la acción "revisar las fuentes de energía y las instalaciones en casa"; el 25 % es propuesta.

**V-D. Intereses por pagar solo el mínimo** (respuesta del dueño): en un estado de cuenta con `intereses_centavos > 0`, si los pagos registrados entre el corte anterior y su fecha límite fueron **menores que el pago para no generar intereses** (o iguales al mínimo), esos intereses son **vampiro con la marca "por pagar solo el mínimo"**. Basta **un** corte **[Propuesta]**, porque la causa es visible. Acción sugerida: pagar el total del siguiente corte. **Fuente [W8, verificada]:** BBVA: "Pagar sólo el mínimo aumenta el tiempo para liquidar el crédito e incrementa el costo financiero."
**Medida:** costo de los últimos 12 meses y costo anual proyectado. Para intereses, se reutiliza `costoDeDeber` (marcado "estimado") y el dato real del estado de cuenta.

**Ejemplos (ilustrativos).** Los intereses del estado de una tarjeta ($350 un mes, $410 el siguiente); la comisión por inactividad de una tarjeta de crédito ($149 + IVA al mes, que el diseño 5.3 bis ya registra); la anualidad de una tarjeta ($748 + IVA al año); un plan de streaming que pasó de $199 a $219.

### 3.4 ZOMBIE: lo que sigue pagándose por inercia

**Definición del dueño:** cosas que ya no sirven o se siguen pagando por inercia: membresías sin uso, seguros duplicados, planes viejos.
**No encontré ninguna página** de Condusef, BBVA ni Profeco que defina "zombie" (W4): la definición es la del dueño (resumen en 12.1: cobros de cosas que ya no existen o no se usan, por ejemplo gimnasio, seguro de un auto vendido, líneas viejas). La regla depende de lo que la persona **responde**, porque la app no puede ver el uso (hallazgo F-4). Profeco sí da una lista de preguntas para decidir si un servicio sigue valiendo la pena, y dice que con **dos o más respuestas afirmativas** hay que considerar cancelar de inmediato (W9); sirve de apoyo a Z1, pero el 2 sigue siendo propuesta.

Un patrón **recurrente reconocido** es **ZOMBIE** si se cumple **cualquiera**:

| # | Regla | Umbral |
|---|---|---|
| Z1 | La persona respondió **"No lo usé"** a **2 preguntas seguidas** de uso, o marcó **"Ya no me sirve"** una vez | 2 respuestas **[Propuesta]** |
| Z2 | **Posible duplicado** (la app lo propone, la persona confirma): dos patrones recurrentes activos en la misma subcategoría de **seguros** (por ejemplo, dos seguros médicos o dos de celular) | confirmación obligatoria |
| Z3 | **Plan viejo** (la app lo propone, la persona confirma): dos patrones activos con el mismo comercio normalizado y montos distintos; el candidato es el patrón más antiguo | confirmación obligatoria |
| Z4 | **Cuenta o tarjeta que la persona ya no quiere** pero que sigue generando anualidad o comisión: la persona marca "ya no la quiero" | — |
| Z5 | **Lo cubierto ya no existe** (por ejemplo, seguro de un auto vendido, línea vieja): la persona marca "ya no existe". Si el patrón está ligado a un bien, la app lo propone, pero la persona confirma | confirmación obligatoria |

**Cuándo se pregunta el uso.** Una pregunta por patrón **una vez por periodo de su cadencia, como máximo una al mes** **[Propuesta]**; las anuales, una vez, **30 días antes** del cobro esperado. Las preguntas se juntan en **una revisión mensual** (D25): no son avisos sueltos. Sin respuesta, la pregunta no cuenta ni a favor ni en contra.
**Medida:** lo que costó en los últimos 12 meses y lo que costaría seguir un año; tras cancelar, lo que **se dejó de pagar** (cobros que ya no llegaron).
**Acción sugerida (respuesta del dueño): pedir la baja formal y exigir folio de cancelación.** Al marcar un zombie, la hoja dice: "Pide la baja formal al proveedor y guarda el folio de cancelación." Al marcar "Ya lo cancelé" se captura la **fecha** y el **folio** (hasta 40 caracteres, letras, números y guiones). Sin folio se permite guardar, pero el patrón queda como **"cancelado sin folio"** y la app lo muestra como pendiente de completar. Profeco (W9) dice que el proveedor debe dar un folio y que sirve de prueba si siguen los cobros; también que desinstalar la aplicación no detiene el cobro y que, si se pagó por un intermediario (por ejemplo una tienda de aplicaciones), cancelar solo en la aplicación no interrumpe el cobro. La cancelación se hace **fuera de la app**; si el patrón está ligado a un compromiso, se le pone `hasta` y el patrón deja de proponerse. Si después se cobra otra vez, ver "cobro tras una cancelación" en 3.2.
**Ejemplos (ilustrativos).** Gimnasio de $450 al mes al que no va desde hace dos meses; dos seguros de celular; el plan básico de una plataforma que sigue cobrándose después de contratar el plan familiar.

## 4. Cómo se clasifica sin ambigüedad

### 4.1 Una sola fuga principal: el árbol de decisión

Se aplica a cada **patrón de cobro** (o, para la hormiga, a cada subcategoría) **en este orden**; la primera respuesta "sí" decide y se detiene.

```
0. ¿Es un gasto vigente en una categoría recortable, un cargo financiero o un servicio del hogar? No -> NINGUNA.
1. ¿Es interés, comisión o anualidad de una deuda o cuenta que la persona tiene en la app?
     Sí -> ¿La persona dijo "ya no la quiero" (Z4)?  Sí -> ZOMBIE.   No -> VAMPIRO (V-A o V-D).
1b. ¿Es un servicio del hogar (luz, agua, gas) que se infla contra su mediana (VC1 a VC3)?
     Sí -> VAMPIRO (V-C).   No -> NINGUNA (los servicios no son fantasma, zombie ni hormiga).
2. ¿Es un cobro automático recurrente (F1 y F2)?
     No -> ve al paso 5.
     Sí -> ¿Está sin reconocer (F3)?                          Sí -> FANTASMA.
        -> ¿Z1, Z2, Z3, Z4 o Z5 confirmados por la persona?     Sí -> ZOMBIE.
        -> ¿Crece (VB2)?                                      Sí -> VAMPIRO (V-B).
        -> En otro caso                                      NINGUNA (recurrente sano).
5. ¿La subcategoría cumple H1 a H5?                           Sí -> HORMIGA.   No -> NINGUNA.
```

**Prioridad cuando varias definiciones caben:** **FANTASMA > ZOMBIE > VAMPIRO > HORMIGA**, con la excepción de los pasos 1 y 1b (un cargo financiero de una cuenta conocida y un servicio del hogar no son fantasma: se sabe de dónde vienen).

Por qué este orden: primero se necesita saber **si la persona sabe que existe el cobro** (fantasma); después **si le sirve** (zombie), porque cancelar resuelve también el aumento; después **si crece** (vampiro); y la **hormiga** solo es lo que queda cuando no hay un cobro automático de por medio.

| Caso | Fuga principal | Por qué |
|---|---|---|
| Streaming que subió de $199 a $219 y que dos veces "no lo usé" | **ZOMBIE** (no vampiro) | El paso de zombie va antes que el de crecimiento; cancelar resuelve ambos |
| El mismo streaming, usado cada semana | **VAMPIRO** (V-B) | Se usa, pero crece más de 10 % |
| Seguro de $89 que nadie reconoce, no usado | **FANTASMA** | Si no se reconoce, no se puede preguntar por su uso |
| Comisión por inactividad de una tarjeta que la persona quiere conservar | **VAMPIRO** (V-A) | La persona decide mantenerla; la acción es evitar la comisión con la compra mínima (5.3 bis) |
| La misma comisión de una tarjeta que "ya no quiero" | **ZOMBIE** (Z4) | La persona dice que ya no sirve; la acción es cerrarla |
| Café diario de $45, 20 veces en 4 semanas | **HORMIGA** | Discrecional, pequeño, frecuente, no automático |
| Recibo de agua que sube a $390 cuando su mediana de 12 periodos es $300 (dos de los tres últimos periodos sobre $375) | **VAMPIRO** (V-C) | Servicio necesario que se infla contra su mediana; la acción es revisar instalaciones |
| Intereses de $410 en un corte en el que se pagó solo el mínimo | **VAMPIRO** (V-D) | Intereses por pagar solo el mínimo; basta un corte |
| Seguro de un auto que ya se vendió, que la persona marca "ya no existe" | **ZOMBIE** (Z5) | La cosa cubierta ya no existe; acción: baja formal y folio |
| Suscripción de $89 al mes (recurrente) | nunca HORMIGA | Es cobro automático recurrente: va por el paso 2 |
| Despensa semanal de $900 | **NINGUNA** | Categoría necesaria y monto mayor que el tope |

### 4.2 Qué hace la persona cuando no cuadra

Cada fuga tiene el botón **"No es así"**, que abre una hoja con estas opciones (una sola decisión, dos toques):

| Opción | Efecto |
|---|---|
| **No es una fuga** | Clasificación `ninguna` por decisión de la persona; el patrón se marca **protegido** y la app deja de proponerlo (con el motivo en la bitácora) |
| **Es de otro tipo** | Elige una de las otras tres; queda la clasificación de la persona |
| **Lo cancelé** | Registra la fecha de cancelación (3.4) |
| **Lo necesito pero lo quiero revisar** | Pasa a "Vigilar" (sin fuga) y se pregunta de nuevo a los 3 meses |

Reglas de la decisión:
1. **La persona gana a la regla.** Una decisión de la persona no la deshace una regla. Solo un **cambio material** vuelve a preguntar (sin cambiar la etiqueta sola): el monto cambia 10 % o más, aparece un patrón nuevo con el mismo comercio, o pasan 12 meses.
2. **Motivo:** si la decisión contradice la regla, el motivo corto es obligatorio (3 a 200 caracteres, igual que un ajuste del libro). Al cambiar una categoría, el motivo es opcional.
3. **En nombre de Papá:** una decisión del albacea sobre el libro de Papá se guarda "en nombre de" con motivo, igual que un movimiento (D19).
4. **Libro compartido:** responde cualquier miembro adulto; vale la **última** respuesta y queda quién y cuándo.

### 4.3 Corrección con anulación y contraasiento

El libro de movimientos no se toca, y las clasificaciones se corrigen sin borrar:

1. **Un gasto mal capturado** (monto, duplicado): se **anula con contraasiento** como siempre (convención de la Fase 0). Las fugas se recalculan solas porque solo cuentan gastos vigentes.
2. **Un gasto en la categoría equivocada:** se corrige con un movimiento de **reclasificación** (ya existe). La fuga se recalcula.
3. **Una clasificación que la persona quiere cambiar:** se agrega una **fila nueva** en `fin_fuga_clasificaciones` con `reemplaza_a` apuntando a la anterior. La anterior **no se edita ni se borra** y el historial se ve en el panel de detalle. Una fila solo puede ser reemplazada una vez (índice único), como en la anulación del libro.
4. **Una respuesta equivocada** ("No lo usé" por error): se agrega una respuesta nueva con `reemplaza_a`; el conteo de las "2 seguidas" usa la última de cada periodo.
5. **Un propósito de deuda declarado mal:** se agrega otra declaración; vale la más reciente.

## 5. Deuda buena y mala

### 5.1 Qué se evalúa

| Clase de deuda | Qué pasa |
|---|---|
| **MSI** (compra a meses sin intereses) | Se evalúa completa (5.3 a 5.6) |
| **Préstamo y crédito con propósito declarado** (por ejemplo, el hipotecario o el de un auto). **Crédito automotriz del dueño: propósito `genera_ingreso`** (herramienta de trabajo; confirmado 18/nov/2026) | Se evalúa con las mismas señales de pago, plazo y carga; el costo financiero total viene de la tasa y el CAT capturados |
| **Tarjeta con saldo que genera intereses** (señal **T1**) | **Mala** (**confirmado por el dueño, 18/nov/2026**: tarjeta con intereses = deuda mala). BBVA (W5) pone como deuda mala "el uso de un crédito para cubrir otro" y las compras impulsivas con tarjeta |
| **Préstamo entre familiares** (sin costo) | **"Sin costo"**: no entra al semáforo de calidad, sí a la carga total (hallazgo D-9) |
| Deuda **sin propósito declarado** | **"Por declarar"** (gris con texto): no se juzga hasta que la persona declare para qué fue |

### 5.2 Declarar el propósito (objetivo)

La persona declara, **una vez por deuda** (y puede cambiarlo, con historial):

| Campo | Contenido |
|---|---|
| `proposito` | `bien_duradero` (equipo, mueble, electrodoméstico), `genera_ingreso` (herramienta de trabajo, negocio), `patrimonio` (vivienda), `educacion_o_salud` (educación, salud o protección), `emergencia` o `consumo` |
| `objetivo_texto` | Hasta 80 caracteres, **sin cifras** (el comercio y la descripción son datos del libro y jamás salen en un aviso) |
| `bien_id` / `objetivo_id` | Opcional: el bien (`fin_bienes`) o el objetivo (`fin_objetivos`) al que sirve la compra |
| `vida_util_meses` | Opcional: cuántos meses se espera que dure lo comprado |
| `precio_contado_centavos` | Opcional: lo que habría costado de contado; permite detectar un sobreprecio |
| `estado_objetivo` | `vigente`, `cumplido` (ya se tiene y se usa), `ya_no_existe` (vendido, devuelto, perdido) o `cambio` (ya no se quiere) |

Se alinea con lo que BBVA México publica (W5, verificada): la deuda buena aporta beneficios a largo plazo y ayuda a generar patrimonio; la mala se adquiere "generalmente para gastos no esenciales" o rebasa la capacidad de pago. La definición de Condusef (patrimonio, ingresos futuros, protección) que repite la prensa **no la encontré en una página alcanzable**.

### 5.3 Criterios y señales

Cada criterio da una señal con código, nivel y explicación. Los umbrales son **[Propuesta]** salvo donde se cita fuente.

| Código | Criterio | Verde | Ámbar | Rojo | Fuente o nota |
|---|---|---|---|---|---|
| **B1** | **Objetivo declarado** | Propósito distinto de `consumo`, objetivo `vigente` o `cumplido` | Sin propósito declarado ("por declarar", gris) | Propósito `consumo`, o `estado_objetivo` = `ya_no_existe` o `cambio` **con mensualidades pendientes** | W5: BBVA pone como buena la deuda con beneficios a largo plazo (créditos educativos, hipotecarios) y como mala la que se adquiere "generalmente para gastos no esenciales". El objetivo que ya no existe es la señal que pidió el dueño |
| **B2** | **Costo financiero total** (intereses + comisiones + anualidad atribuible, solo con dato) | MSI sin sobreprecio; o crédito con propósito `patrimonio` o `genera_ingreso` | **Sobreprecio**: el total a meses supera el `precio_contado_centavos` capturado | Tarjeta con intereses cobrados en el último estado (T1) | Sin precio de contado no se evalúa (no se inventa). Sin cifra de tope para el CAT: no hay fuente (pregunta 6) |
| **B3** | **Plazo** | Plazo menor o igual que la vida útil declarada y menor o igual a **18 meses** | Mayor de 18 meses | Plazo **mayor** que la vida útil declarada | **Verificado [W7]:** Condusef (10/nov/2026) recomienda MSI "para productos con una vida útil que supere la duración de la deuda"; de ahí sale el rojo. Los **18 meses** son propuesta sin fuente; el diseño admite hasta 48 |
| **B4a** | **Carga total de deuda** (pagos de deuda ÷ ingreso, existente) | menor de 20 % | de 20 % a 35 % | mayor de 35 % | Ya existe en `fin_parametros` (20 y 35 %, [Propuesta] heredada del diseño). **Verificado [W6]:** Condusef recomienda no pasar de **30 %** del ingreso; BBVA, entre **30 y 35 %**. El "35 a 40 %" no lo encontré en página primaria. Pregunta 5 |
| **B4b** | **MSI sobre el ingreso mensual** (suma de mensualidades de MSI ÷ ingreso mensual de referencia) | menor o igual a **10 %** | de 10 % a **20 %** | mayor de 20 % | 10 %: opinión de una especialista citada por prensa, **no encontrada en página primaria** (W7b); 20 %: propuesta sin fuente |
| **B4c** | **MSI activos a la vez** | 0 a 2 | 3 | 4 o más | Propuesta sin fuente (el diseño dice "muchas" sin número) |
| **B5** | **Bien que sirve** (lo comprado se usa) | `vigente` o `cumplido` | La persona marca "lo uso poco" | `ya_no_existe` o `cambio` | La declara la persona; la app no ve el uso |
| **B6a** | **Pagos al corriente** (mensualidades de `fin_ocurrencias`) | 0 atrasos en los últimos 6 pagos | 1 atraso | 2 o más | Propuesta |
| **B6b** | **Pago de la tarjeta del MSI** (con estados de cuenta) | Pagó el total sin intereses | Pagó menos que el total sin intereses y hubo intereses en 1 corte | **Solo el mínimo** o intereses en **2 cortes seguidos** | **Verificado [W8]:** el pago para no generar intereses incluye solo la mensualidad del mes de las compras a MSI; pagar solo el mínimo genera intereses. Sin estado capturado: "sin dato" |
| **B7** | **Uso del límite** (existente, con MSI pendiente) | menor de 30 % | de 30 % a 60 % | mayor de 60 % | Ya existe (`usoDelLimite`) |

### 5.4 Cuándo una deuda buena se está volviendo mala

Señales de deterioro. Cada una enciende un código visible en la tarjeta de la deuda:

| Código | Señal | Ámbar | Rojo |
|---|---|---|---|
| **M1** | **Rodar de un MSI a otro** (encadenamiento): se compra un MSI nuevo en la **misma tarjeta** cuando otro tiene **2 mensualidades pendientes o menos**, o terminó hace **30 días o menos** | 2 veces en 12 meses | 3 o más en 12 meses |
| **M2** | **Pago mínimo o intereses** en la tarjeta del MSI (B6b) | 1 corte con intereses | Solo el mínimo, o 2 cortes con intereses seguidos |
| **M3** | **El objetivo ya no existe** (B1 y B5) y quedan mensualidades | — | Siempre rojo si queda saldo |
| **M4** | **Peso sobre el ingreso**: B4a o B4b sobre su umbral | ámbar | rojo |
| **M5** | **Se acumulan varios MSI** (B4c) | 3 | 4 o más |
| **M6** | **Atrasos** (B6a) | 1 | 2 o más |
| **M7** | **Plazo mayor que la vida útil** (B3) o **sobreprecio** (B2) | sobreprecio | plazo mayor |
| **M8** | **Uso alto del límite** (B7) | 30 a 60 % | más de 60 % |

### 5.5 Semáforo de la deuda y cómo cambia

El nivel de una deuda es **el peor** de todas sus señales (como el semáforo existente de `Umbrales`). Etiquetas (siempre con texto además de color, regla de accesibilidad):

| Nivel | Etiqueta | Cuándo |
|---|---|---|
| Verde | **Deuda buena** | Todos los criterios aplicables en verde, con propósito declarado |
| Ámbar | **Buena, en vigilancia** | Alguna señal en ámbar y ninguna en rojo |
| Rojo | **Se volvió mala** | Alguna señal en rojo, o propósito `consumo`, o tarjeta con intereses |
| Gris | **Por declarar** | Sin propósito declarado y sin señal roja |

**Subir de nivel es inmediato; bajar exige 2 evaluaciones semanales seguidas** sin la señal (evita parpadeo) **[Propuesta]**.
**Cuándo se evalúa:** al abrir el libro, al guardar un pago, un estado de cuenta o un MSI, y en el cierre semanal del lunes.
**Qué sugiere (nunca decide):** una línea de acción por señal, por ejemplo "pagar el total en el próximo corte" (B6b), "no abrir otro MSI hasta liquidar uno" (M1, M5), "declarar para qué fue" (B1) o "abrir el simulador" (B4a, ya existe). El pago y la decisión son de la persona. **Respuesta del dueño: una deuda mala solo avisa** (aviso y sugerencia); no bloquea registrar nada ni pide una confirmación extra.
**Antes de un MSI nuevo:** la hoja de registro muestra una **vista previa** (sin bloquear): "con esta compra, tus MSI serían X % de tu ingreso y tendrías N a la vez", con el semáforo que quedaría. Solo es información.

### 5.5 bis Ejemplo (cifras ilustrativas)

Ingreso mensual de referencia $20,000. Una persona tiene un MSI de $12,000 a 12 meses ($1,000 al mes) para una laptop de trabajo (propósito `genera_ingreso`, vida útil declarada 48 meses), al corriente y con la tarjeta pagada en total: **Deuda buena** (plazo de 12 meses: menor que la vida útil de 48 y que el límite de 18 meses). Después compra un segundo MSI de $6,000 a 6 meses ($1,000 al mes): los MSI suman $2,000 al mes = **10 %** (verde, límite inclusive) y hay 2 activos (verde). Si luego compra un tercero de $1,200 a 6 meses ($200 al mes): $2,200 = **11 %** (ámbar, B4b) y 3 activos (ámbar, B4c): **"Buena, en vigilancia"**, con la sugerencia "no abrir otro MSI hasta liquidar uno". Si el siguiente estado de la tarjeta trae intereses y la persona solo paga el mínimo dos cortes seguidos (M2): **"Se volvió mala"**.

## 6. Modelo de datos propuesto (sin escribir la migración)

Migración propuesta: `20261146000000_finanzas_fugas_deudas.sql` (el número lo confirma el arquitecto; la última existente es `20261145`). Reglas comunes: `hogar_id` y `libro_id` con la misma llave foránea compuesta que el resto; UUID generado en el dispositivo; **ninguna tabla permite `update` ni `delete` a `authenticated`** (solo-agregar, la escritura entra por RPC); texto libre acotado; dinero en `bigint` centavos; fechas en `date` y `timestamptz`; la semana es derivada (lunes), no se guarda.

### 6.1 Cambios a tablas existentes

| Tabla | Cambio | Motivo |
|---|---|---|
| `fin_movimientos` | Columnas **nuevas y opcionales** `comercio text` (hasta 80 caracteres) y `cobro_automatico boolean default false`. Solo se llenan al insertar; no se agregan valores a movimientos existentes (el libro sigue solo-agregar) | F-2, F-3 |
| `fin_msi` | Columna opcional `precio_contado_centavos bigint check (> 0)` (se llena al crear el MSI; para corregir, se crea la declaración de propósito nueva) | D-4 |
| `avisos` | Agregar 4 tipos al `check` de `tipo` y a `avisos_severidad` y `avisos_tipo_emitible` (sección 8.3) | F-9 |
| `fin_parametros` | **No se toca**: los parámetros nuevos van en una tabla aparte para no ampliar los permisos de columna actuales | Menor riesgo |

### 6.2 Tablas nuevas

| Tabla | Para qué | Columnas principales |
|---|---|---|
| `fin_fuga_parametros` | Umbrales editables por libro (una fila por libro, creada con los valores por defecto). **Se cambian con `update` solo por RPC** (como `fin_parametros`) | `libro_id` (PK), `tope_hormiga_centavos` (15000), `hormiga_min_gastos` (8), `hormiga_min_semanas` (3), `hormiga_min_ingreso_pb` (100), `hormiga_conjunto_pb` (500), `recurrente_tolerancia_pb` (1000), `vampiro_crecimiento_pb` (1000), `zombie_respuestas` (2), `servicio_periodos_min` (6), `servicio_periodos_mediana` (12), `servicio_mediana_pb` (2500), `msi_ambar_pb` (1000), `msi_rojo_pb` (2000), `msi_activos_ambar` (3), `msi_activos_rojo` (4), `plazo_ambar_meses` (18), `baja_nivel_evaluaciones` (2) |
| `fin_patrones_cobro` | Un cobro que se repite o una subcategoría hormiga vigilada | `id`, `libro_id`, `clave` (comercio normalizado + categoría), `comercio_norm` (nulo permitido), `categoria_id`, `compromiso_id` (nulo), `cadencia` (`semanal`/`quincenal`/`mensual`/`bimestral`/`anual`/`irregular`), `automatico` (bool), `origen` (`detectado`/`manual`), `cancelado_en` (nulo), `protegido` (bool), `creado_por`, `creado_en`. Único `(libro_id, clave)` |
| `fin_fuga_clasificaciones` | Clasificación vigente y su historial | `id`, `libro_id`, `patron_id`, `fuga` (`hormiga`/`fantasma`/`vampiro`/`zombie`/`ninguna`), `origen` (`regla`/`persona`), `regla` (código: `H1`...`Z5`, `VA`, `VC`, `VD`), `reemplaza_a` (nulo; índice único cuando no es nulo), `motivo` (≤ 200; obligatorio si `origen = 'persona'` y contradice la regla), `decidido_por`, `en_nombre_de` (nulo; con motivo, como `fin_movimientos`), `decidido_en`. **Vigente** = la que ningún otro reemplaza |
| `fin_fuga_respuestas` | Reconocimiento y uso | `id`, `libro_id`, `patron_id`, `pregunta` (`reconoce`/`uso`/`ya_no_sirve`/`ya_no_existe`/`cancelado`/`temporada`), `respuesta` (`si`/`no`/`despues`), `folio` (nulo; hasta 40 caracteres `[A-Za-z0-9-]`, solo con `cancelado`), `periodo_lunes` (date, el lunes de la semana en que se contestó), `reemplaza_a`, `registrado_por`, `registrado_en` |
| `fin_deuda_propositos` | Propósito declarado de una deuda y estado del objetivo | `id`, `libro_id`, `deuda_id`, `proposito`, `objetivo_texto` (≤ 80), `bien_id` (nulo), `objetivo_id` (nulo), `vida_util_meses` (nulo), `estado_objetivo`, `reemplaza_a`, `declarado_por`, `declarado_en`. Vigente = la más reciente sin reemplazo |
| `fin_deuda_semaforo` | Historial de cambios de nivel (para avisar solo una vez y para la histéresis) | `id`, `libro_id`, `deuda_id`, `lunes` (date), `nivel` (`verde`/`ambar`/`rojo`/`gris`), `senales` (text[] con códigos B1 a M8), `calculado_en`. Solo se agrega cuando el nivel cambia |

**Nada de esto guarda IA ni salida a la nube.** Las columnas de texto (`objetivo_texto`, `motivo`, `comercio_norm`) son datos del libro: jamás aparecen en un aviso (D20).
**Costo de almacenamiento:** son filas pequeñas, una por patrón y por cambio. Se vigila con el aviso existente de 80 % de la base (`base_80`). Las fugas calculadas **no se guardan**: se derivan del libro al abrir.

### 6.3 RPC propuestas (escritura)

Todas `security definer`, con `search_path` vacío y validación del libro con `fin_puede`:

| RPC | Acción |
|---|---|
| `fin_fuga_responder(patron, pregunta, respuesta)` | Agrega una respuesta. Exige `fin_puede(libro, 'escribir')` |
| `fin_fuga_clasificar(patron, fuga, motivo)` | Agrega una clasificación de la persona (reemplaza la vigente). Exige `escribir`; para un libro representado, queda "en nombre de" con motivo |
| `fin_patron_crear(libro, comercio, categoria, cadencia, automatico)` | Crea un patrón a mano |
| `fin_patron_cancelar(patron, fecha, folio)` | Marca la cancelación (`cancelado_en`) y guarda el folio en la respuesta `cancelado` (puede ir vacío: "cancelado sin folio"); si hay compromiso ligado, le pone `hasta` por la RPC ya existente |
| `fin_deuda_declarar(deuda, proposito, objetivo_texto, bien, objetivo, vida_util, estado)` | Agrega una declaración de propósito. Exige `administrar` en el libro |
| `fin_fuga_parametros_cambiar(libro, ...)` | Cambia umbrales. Exige `administrar` |

## 7. Permisos por rol (D5, D19)

La verdad está en el servidor (RLS); el cliente solo lleva un espejo para ocultar.

**Lectura de las tablas nuevas:** solo con `fin_deudas_puede_ver(libro_id)` (la misma función que ya protege deudas y tarjetas: lee quien puede leer el libro y, en el libro de Papá, solo quien lo administra y la cuenta maestra con consulta vigente). **Escritura:** solo por RPC.

| Rol o figura | Ve las fugas y el semáforo | Responde y clasifica | Declara propósito y cambia umbrales |
|---|---|---|---|
| **Dueño** | Su libro y los compartidos de los que es miembro; el de Papá como albacea | Sí (su libro y compartidos) | Sí (`administrar`) |
| **Pareja (coadministrador)** | Su libro y los compartidos; **no** el libro personal del dueño | Sí | Sí |
| **Albacea de Papá** | El libro de Papá | Sí, "en nombre de" con motivo | Sí |
| **Suplente de Papá** | Lee el libro de Papá (regla de la Fase 1) | Solo si no hay albacea vigente | Solo si no hay albacea vigente |
| **Cuenta maestra** | **Solo lectura** con consulta registrada vigente; cada consulta va a la bitácora | **No** | **No** |
| **Familiar** | **No** (sin Finanzas, D5) | No | No |
| **Cuidador y Casa** | **No** | No | No |
| **Familiar con vista temporal de Papá (D24)** | **No**: estas pantallas quedan fuera de lo autorizado (propuesta, C-7) | No | No |

**Dispositivos:** la tablet pública del modo Casa y las bocinas no muestran ni dicen nada de esto (D14, D6). La pulsera, tampoco montos (sección 8).
**Cada persona ve solo lo suyo:** el dueño no ve las fugas del libro personal de la pareja ni al revés; en un compartido ven todos sus miembros.

## 8. Pantallas, avisos y voz

Se siguen `docs/DISENO_UX_UI.md`: Finanzas es **precisa y serena** (acento índigo, números de ancho fijo, poca animación); teléfono con gadgets antes que tablas; la laptop con tablas completas; zonas táctiles de 48 dp o más; nada depende solo del color; los montos se ocultan solos (D18) y siempre se confirma antes de escribir.

### 8.1 Laptop (sistema completo, D4)

| Pantalla | Contenido |
|---|---|
| **Finanzas › Fugas** (sección nueva en la barra lateral) | Encabezado "Lo que se va sin que lo notes": cuatro tarjetas (Hormiga, Fantasma, Vampiro, Zombie) con el monto de las 4 semanas, el estimado anual y el número de elementos; en la primera línea, **"Por revisar (N)"** con las preguntas pendientes. Debajo, una tabla por fuga con comercio, cadencia, monto por cobro, equivalente semanal, anual y la **regla** que la puso ahí (código y frase). Panel de detalle a la derecha: línea de tiempo de cobros, historial de clasificaciones (quién y cuándo) y los botones **"No es así"**, **"Lo reconozco" / "No lo conocía"**, **"Lo usé" / "No lo usé"** y **"Ya lo cancelé"** |
| **Revisión de fugas** (mensual, dentro de la revisión semanal del primer lunes del mes) | Una pregunta a la vez con dos botones grandes, con salto y "Después". Máximo 7 preguntas por revisión; el resto queda para el mes siguiente **[Propuesta]** |
| **Reporte de fugas** (en Reportes) | Por fuga y por mes **mostrado por semanas** con promedio semanal (los meses tienen 4 o 5 lunes, 5.9 bis); lo cancelado y "lo que se dejó de pagar"; exporta como el resto de reportes |
| **Finanzas › Deudas** (pestaña nueva **"Buena o mala"**) | Lista de deudas con la etiqueta de la sección 5.5, las señales que la explican (por código y frase), y las sugerencias. Gadget **"Tus MSI y tu ingreso"**: barra con las marcas de 10 % y 20 % y el número de MSI activos. Hoja **"Declarar para qué fue"** con los campos de 5.2 (solo laptop) |
| **Nuevo MSI** (hoja existente) | Campos nuevos opcionales: propósito, objetivo, vida útil y precio de contado; **vista previa** del efecto sobre el semáforo (5.5) |
| **Registrar gasto** (hoja existente) | Campo **Comercio** opcional (sugiere del diccionario del hogar) y casilla "Es un cargo automático". El registro rápido de menos de 10 s **no cambia**: ambos son opcionales |

### 8.2 Teléfono y tablet personal (lo mínimo, D4)

| Pantalla | Contenido |
|---|---|
| **Hoy** | Una tarjeta **"Revisa un cobro"** solo cuando hay preguntas: una pregunta y dos botones; sin cifras en la pantalla bloqueada |
| **Finanzas › Deudas** | Lista con el semáforo y la etiqueta de cada deuda; al tocar, las señales en texto. **Sin formularios de propósito** (se declaran en la laptop, como el resto de formularios de deuda de la Fase 2) |
| **Registrar gasto (+)** | Igual que hoy; el comercio es un campo opcional abajo |

### 8.3 Avisos (D20: catálogo cerrado, sin cifras ni nombres)

Cuatro tipos nuevos; texto de hasta 40 caracteres, sin dígitos, sin "$" y sin nombres. Origen `app` o `local` (se calculan en el dispositivo al abrir el libro y con el recordatorio del cierre semanal; no hay envío del servidor porque la clasificación es local).

| Tipo | Título propuesto | Nivel | Destino |
|---|---|---|---|
| `fuga_por_reconocer` | Hay un cobro por reconocer | importante | quien registró o titular (y el albacea en el libro de Papá) |
| `fuga_revision_mensual` | Tienes una revisión de cobros | informativa | titular |
| `deuda_en_vigilancia` | Revisa una deuda a meses | importante | titular |
| `deuda_se_volvio_mala` | Una deuda necesita atención | crítica | titular (y el suplente solo si el libro es de Papá y no hay albacea vigente) |

Se respetan el tope de 3 avisos no críticos al día y las horas silenciosas de 22:00 a 07:00 (5.9 bis). La clave de idempotencia lleva el objeto y el nivel (`deuda:{id}:rojo`), de modo que un mismo cambio avisa **una sola vez**. Al abrir el aviso se ve el detalle con montos (tras el PIN si están ocultos, D18).

### 8.4 Voz y herramientas de GRAVITY (D3, D6)

Textos de la app (sin culpa, breves, ofrecen una acción):

| Situación | Texto |
|---|---|
| Hormiga | "Estas compras chicas se repiten bastante. ¿Quieres verlas juntas?" |
| Fantasma | "Encontré un cobro que se repite y no tienes registrado. ¿Lo reconoces?" |
| Vampiro | "Este cobro sube cada vez. ¿Lo revisamos?" |
| Vampiro, servicio del hogar | "Este recibo viene más alto de lo normal. Conviene revisar instalaciones y consumo." |
| Vampiro, intereses por el mínimo | "Este corte tuvo intereses porque se pagó el mínimo. El siguiente se puede pagar completo." |
| Zombie | "No marcaste uso en este cobro las últimas veces. ¿Todavía lo quieres?" |
| Zombie, acción | "Pide la baja formal y guarda el folio de cancelación." |
| Pregunta de uso | "¿Lo usaste este mes?" |
| Deuda buena | "Esta compra a meses va al corriente y sirve para lo que dijiste." |
| En vigilancia | "Tienes varias compras a meses al mismo tiempo. Todas van al corriente; solo hay que vigilarlas." |
| Se volvió mala | "Esta compra a meses cambió: ya no tiene el objetivo que declaraste. Veamos opciones." |
| Sin dato | "Falta el estado de cuenta para saberlo." |

**Herramientas** (convención de la Fase 0): `fin_fugas_resumen` (`modulo: finanzas`, `roles: dueno, coadministrador`, `escribe: false`, `soloLocal: true`; entrega el resultado **directo a la pantalla**, sin pasar por el modelo) y `fin_fuga_marcar` (`escribe: true`, pide confirmación, `soloLocal: true`). Con el modo privado, en la tablet y **por bocinas nunca se dicen montos ni comercios**. El modelo de IA en la nube solo entiende "muéstrame mis fugas" y elige la herramienta; nunca ve cifras ni comercios.
**Orden escrita o por voz propuesta:** "ver fugas" y "ver mis deudas buenas y malas" (abren la pantalla). Marcar o cancelar solo se hace desde la pantalla (decisión de la persona con dos toques).

## 9. Ayuda de IA: ninguna en este bloque

1. **Clasificación:** reglas locales. No hay modelo.
2. **Qué no puede ir a la nube:** el comercio, el monto, la cuenta, la categoría y la cadencia de un cobro. D3 los considera datos de dinero, así que ni siquiera "texto sin cuentas" que incluya un comercio (aclaración propuesta C-2).
3. **Opcional y futura:** un modelo **local en la laptop** (la opción de D3) podría sugerir el nombre limpio de un comercio o la categoría de un cobro, siempre **marcado como sugerencia**, apagado por omisión, sin enviar nada fuera de la laptop y con confirmación de la persona. **No se construye en este bloque.**
4. **Catálogo local de servicios conocidos (sin IA):** un archivo en el repositorio con solo **nombres** de servicios comunes (streaming, música, almacenamiento, gimnasios, seguros) para normalizar el comercio. **Sin precios** (no se inventan). Lo llena el dueño; sin datos reales de personas.

## 10. Criterios de aceptación y casos de prueba

Las pruebas de dominio van en `paquetes/finanzas_dominio` (`dart test`), con los números de abajo; las de servidor en `supabase/tests`; las de interfaz en `app/test`. Ingreso mensual de referencia: ingreso semanal × 52 ÷ 12, redondeado.

### 10.1 Dominio: fugas

| # | Criterio | Caso |
|---|---|---|
| DF-1 | **Hormiga positiva** | Ingreso semanal $5,000 (mensual de referencia $21,666.67). 10 gastos de $45 en "Café y colaciones" repartidos en 4 semanas: suma $450 = 2.07 % del ingreso, 10 gastos, 4 de 4 semanas, categoría deseable, sin cobro automático. Resultado: HORMIGA; promedio semanal $112.50; estimado anual $5,850 |
| DF-2 | **Frecuencia insuficiente** | Mismo caso con 7 gastos: no es hormiga (H3) |
| DF-3 | **Monto sobre el tope** | 8 gastos de $151 (más que el tope de $150.00): ninguno cuenta (H2) |
| DF-4 | **Concentrados en una semana** | 8 gastos de $50 todos en una sola semana: no es hormiga (H4) |
| DF-5 | **No pesa** | Ingreso semanal $25,000 (mensual $108,333.33): 8 gastos de $20 = $160, menos del 1 % ($1,083.33): no es hormiga (H5) |
| DF-6 | **Categoría necesaria** | 12 gastos de $30 en una categoría `necesario`: no es hormiga (H1) |
| DF-7 | **Límite exacto del tope** | Un gasto de exactamente $150.00 cuenta; de $150.01 no |
| DF-8 | **Fantasma** | Cobros de $89 el 5 de agosto, 5 de septiembre y 5 de octubre (intervalos 31 y 30 días), sin compromiso, con `cobro_automatico`: patrón recurrente "Por reconocer". Con respuesta "No lo conocía": FANTASMA. Con "Sí, lo conozco" y "Lo usé": NINGUNA |
| DF-9 | **Monto estable** | Cobros de $89, $89 y $97 (8.99 % sobre la mediana): recurrente. Con $89, $89 y $99 (11.2 %): no es recurrente de monto fijo |
| DF-10 | **Sin respuesta no acusa** | Un fantasma candidato con "Después" cuatro veces seguidas sigue "Por reconocer" y no se cuenta como FANTASMA confirmado |
| DF-11 | **Prioridad** | Streaming de $199 que sube a $219 (10.05 %, es decir 20 × 10 000 ≥ 1 000 × 199) con dos respuestas "No lo usé": ZOMBIE, no VAMPIRO. Con uso confirmado: VAMPIRO (V-B). Con $218 (9.55 %): NINGUNA |
| DF-12 | **Corrección con anulación** | Con DF-1, anular 3 de los 10 gastos con contraasiento deja 7: deja de ser hormiga (DF-2); el libro conserva los 10 y las 3 anulaciones |
| DF-13 | **Cargo financiero** | Estados con intereses de $350 en el corte 1, $0 en el 2 y $410 en el 3: aparece en 2 de 3: VAMPIRO (V-A). Solo en 1 de 3: NINGUNA |
| DF-14 | **Zombie por respuesta** | Gimnasio de $450 al mes con "No lo usé" en dos preguntas seguidas: ZOMBIE; costo anual proyectado $5,400 |
| DF-15 | **Zombie por una respuesta alternativa** | "Ya no me sirve" una sola vez: ZOMBIE |
| DF-16 | **Duplicado exige confirmación** | Dos patrones de seguro de celular: la app propone duplicado pero **no clasifica** hasta que la persona confirma |
| DF-17 | **Cobro tras cancelar** | Patrón cancelado el 10 de septiembre y cobro el 5 de octubre: FANTASMA con la marca "cobrado tras cancelar" |
| DF-18 | **La persona gana** | Con "No es una fuga" (motivo "lo uso para trabajar"), la regla no vuelve a clasificarlo; un cambio de monto de 10 % o más solo vuelve a preguntar |
| DF-19 | **Una sola fuga** | La suma de las cuatro fugas nunca supera el gasto total del periodo; un cobro no aparece en dos |
| DF-20 | **Sin comercio** | La hormiga se detecta sin comercio; un patrón recurrente sin comercio se agrupa por subcategoría y monto, y la app lo dice |
| DF-21 | **Equivalentes** | $450 al mes = $103.85 a la semana con R2; los renglones suman exacto |
| DF-22 | **Semana en lunes** | Un gasto de domingo cuenta en la semana que empezó el lunes anterior; los totales de 4 semanas empiezan en lunes |
| DF-23 | **Servicio que se infla (V-C)** | Agua mensual con 12 periodos: 280, 290, 300, 300, 300, 300, 300, 310, 310, 320, 380 y 390 (mediana $300; el umbral es $375). Los 2 últimos periodos (380 y 390) superan $375 y el tercero (320) no: 2 de 3, VAMPIRO. Con 370 y 390 solo uno supera: NINGUNA. Con 5 periodos de historia: "sin dato" |
| DF-24 | **Servicio nunca es otra fuga** | Un recibo de luz recurrente, automático y sin reconocer no es FANTASMA ni ZOMBIE; solo puede ser VAMPIRO por V-C |
| DF-25 | **Intereses por pagar el mínimo (V-D)** | Estado con pago sin intereses $3,000, mínimo $300 e intereses $410; los pagos del ciclo anterior suman $300: VAMPIRO con la marca "por pagar solo el mínimo" con un solo corte. Con pagos de $3,000: sin esa marca |
| DF-26 | **Folio de cancelación** | Cancelar un patrón con folio `ABC-123` lo deja "cancelado"; sin folio, "cancelado sin folio" (pendiente). Un folio con espacios o más de 40 caracteres se rechaza |
| DF-27 | **Cosa que ya no existe (Z5)** | "Ya no existe" confirmado por la persona sobre un seguro de auto: ZOMBIE; sin confirmar, solo una propuesta |

### 10.2 Dominio: deuda buena y mala

Ingreso mensual de referencia $20,000.

| # | Criterio | Caso |
|---|---|---|
| DD-1 | **Deuda buena** | MSI de $12,000 a 12 meses ($1,000 al mes), propósito `genera_ingreso`, vida útil 48 meses, objetivo vigente, 0 atrasos, tarjeta pagada en total, límite usado de 20 %: verde, "Deuda buena" |
| DD-2 | **MSI sobre el ingreso** | $2,000 al mes (10 %): verde. $2,001: ámbar. $4,000 (20 %): ámbar. $4,001: rojo |
| DD-3 | **MSI activos** | 2 activos: verde; 3: ámbar; 4: rojo |
| DD-4 | **Carga total** | Pagos de deuda de $6,999 (34.99 %): ámbar; $7,000 (35 %): ámbar; $7,001: rojo (existente) |
| DD-5 | **Encadenamiento** | MSI A de 6 mensualidades con 5 pagadas (1 pendiente) y un MSI B comprado ese día en la misma tarjeta: 1 encadenamiento. Tres encadenamientos en 12 meses: rojo |
| DD-6 | **Objetivo que ya no existe** | MSI de $12,000 a 12 meses, objetivo marcado "vendido" con 5 mensualidades pendientes: rojo con la señal M3. Con 0 pendientes: no se enciende |
| DD-7 | **Solo el mínimo** | Estado con pago sin intereses $3,000 y mínimo $300; pagos entre el corte y la fecha límite suman $300: señal B6b roja |
| DD-8 | **Intereses en 2 cortes seguidos** | Intereses mayores que cero en dos estados seguidos con MSI activos: rojo (M2); en un solo corte: ámbar |
| DD-9 | **Plazo mayor que la vida útil** | MSI a 24 meses de algo con vida útil de 18: rojo (M7) |
| DD-10 | **Sobreprecio** | Precio de contado $10,000 y MSI de 10 mensualidades de $1,050 (total $10,500): ámbar. Sin precio de contado: sin evaluar y "sin dato" |
| DD-11 | **Tarjeta con intereses** | Tarjeta con intereses en el último estado: mala por omisión (T1) |
| DD-12 | **Por declarar** | MSI sin propósito: gris "Por declarar", no se juzga |
| DD-13 | **Préstamo familiar** | "Sin costo": no entra al semáforo de calidad, sí a la carga total |
| DD-14 | **Sin dato** | Sin estado de cuenta capturado, B6b dice "sin dato" y no suma al nivel |
| DD-15 | **Histéresis** | Una deuda en rojo que se queda sin señales rojas una semana sigue en rojo; baja tras 2 semanas seguidas |
| DD-16 | **Peor señal** | El nivel es el de la peor señal; un rojo y tres verdes dan rojo |
| DD-17 | **Vista previa** | Con 2 MSI de $1,000 al mes, un tercero de $200 muestra "11 %, 3 a la vez, ámbar" antes de guardar |
| DD-18 | **Solo reglas** | Ninguna función del dominio recibe ni devuelve datos a un servicio de IA (prueba estática de dependencias) |
| DD-19 | **Deuda mala solo avisa** | Con una deuda en rojo, registrar un MSI nuevo se puede guardar sin confirmación extra; solo se muestra la vista previa y se emite el aviso |
| DD-20 | **Crédito automotriz** | Con propósito `genera_ingreso`, vida útil mayor que el plazo, al corriente y carga menor de 20 %: verde. Sin propósito: gris |

### 10.3 Servidor (RLS)

| # | Criterio |
|---|---|
| SQ-1 | Las seis tablas nuevas tienen RLS y **ninguna** admite `update` ni `delete` a `authenticated` |
| SQ-2 | Familiar, cuidador y Casa no leen ninguna tabla nueva ni ejecutan ninguna RPC (D5) |
| SQ-3 | Dueño y pareja leen solo lo de su libro y los compartidos de los que son miembros; ninguno lee el libro personal del otro |
| SQ-4 | La cuenta maestra lee solo con consulta registrada vigente y **no escribe** |
| SQ-5 | En el libro de Papá, el albacea lee y escribe "en nombre de" con motivo; el suplente lee, y escribe solo sin albacea vigente; el familiar sin vista autorizada no lee nada (D24) |
| SQ-6 | `reemplaza_a` no admite dos reemplazos de la misma fila |
| SQ-7 | Una clasificación de la persona que contradice la regla exige motivo de 3 a 200 caracteres |
| SQ-8 | El texto de un aviso nuevo no pasa si lleva dígitos, "$" o más de 40 caracteres; ningún aviso trae comercio ni monto |
| SQ-9 | Un movimiento nuevo con `comercio` o `cobro_automatico` entra; ningún movimiento existente cambia (el libro sigue solo-agregar) |

### 10.4 Aplicación

| # | Criterio |
|---|---|
| UI-1 | Cada fuga y cada deuda muestran **texto además de color** (accesibilidad) y los montos respetan el modo oculto |
| UI-2 | El botón "No es así" abre la hoja con las 4 opciones; guardar la decisión toma 2 toques |
| UI-3 | Registrar un gasto en el teléfono sigue tomando menos de 10 segundos con el campo Comercio opcional vacío |
| UI-4 | El teléfono muestra el semáforo de las deudas y contesta preguntas de uso, pero **no** abre el formulario de propósito |
| UI-5 | La tablet pública, las bocinas y la vista temporal de Papá no muestran nada de este bloque |
| UI-6 | La revisión mensual hace como máximo 7 preguntas y permite "Después" |
| UI-7 | Los avisos usan solo el catálogo cerrado; el tope de avisos no críticos se respeta |
| UI-8 | Las herramientas de GRAVITY declaran `soloLocal: true`; con modo privado no se dicen montos |

## 11. Trabajo por agente

| Agente | Entrega |
|---|---|
| **finanzas** | Dominio puro (`fugas.dart`, `deuda_calidad.dart`, normalización de comercio, detección de patrones y señales) con las pruebas DF y DD; después, pantallas y herramientas |
| **backend** | Migración 6.1 y 6.2, RPC de 6.3 y pruebas SQ (permisos por rol, solo-agregar, avisos) |
| **diseno** | Tarjetas de fuga, gadget "Tus MSI y tu ingreso", etiqueta de deuda con semáforo y texto, tarjeta "Revisa un cobro" |
| **plataforma** | Los cuatro tipos de aviso en el catálogo y recordatorios locales; campo opcional de comercio en el registro rápido |
| **asistente** | Herramientas `fin_fugas_resumen` y `fin_fuga_marcar`; órdenes "ver fugas" y "ver mis deudas buenas y malas"; documentar en `api/` |
| **calidad** | Revisión al cierre: D3 (nada sale), D5 y D19 (roles), D20 (avisos), D24 (vista temporal) y accesibilidad |

Orden recomendado: dominio y pruebas → migración y RLS → pantallas de la laptop → teléfono → revisión de calidad.

## 12. Respuestas y preguntas abiertas

### 12.1 Respuestas del dueño (18/nov/2026)

| Tema | Respuesta | Dónde quedó |
|---|---|---|
| Campo **Comercio** y casilla "es un cargo automático" en el registro de gastos | Confirmado | 6.1, 8.1 |
| **Revisión mensual** de preguntas de uso; dos "No lo usé" seguidas = zombie | Confirmada | 3.4 (Z1) |
| **Crédito automotriz** | Herramienta de trabajo: propósito `genera_ingreso` | 5.1, DD-20 |
| **Tarjeta con intereses** | Deuda mala | 5.1, DD-11 |
| **Deuda mala** | Solo avisa; no bloquea ni pide confirmación extra | 5.5, DD-19 |
| **Vampiro** | Incluye los **servicios del hogar que se inflan** (luz, agua, gas), detectados contra su mediana, y los **intereses por pagar solo el mínimo** | 3.3 (V-C y V-D), DF-23 a DF-25 |
| **Zombi** | La acción sugerida es **pedir la baja formal y exigir folio de cancelación** | 3.4, DF-26 |
| Conciliación en PDF | Sin respuesta clara; se empieza con lo capturado (por confirmar) | F-7 |

**Definiciones del dueño** (resumen pegado de BBVA y Condusef; ver 13 para lo que sí se verificó): *hormiga*, compras pequeñas, diarias y no planificadas; *vampiro*, fugas constantes ocultas en costos fijos o intereses (servicios del hogar que se inflan, intereses por pagar solo el mínimo); *fantasma*, cargos recurrentes que no se recuerdan o se olvidaron (suscripciones, membresías, comisiones bancarias); *zombi*, cobros de cosas que ya no existen o no se usan (gimnasio, seguro de un auto vendido, líneas viejas). **Solución principal por tipo:** hormiga, límite semanal; vampiro, revisar instalaciones y pagar más del mínimo; fantasma, auditar el estado de cuenta y cancelar; zombi, pedir la baja formal y exigir folio de cancelación.

### 12.2 Preguntas que siguen abiertas

1. **Orden y comisiones.** ¿Confirma la prioridad fantasma, zombie, vampiro, hormiga? Su resumen pone las **comisiones bancarias que no se recuerdan** en fantasma, y su petición original las puso en vampiro: aquí una comisión de una cuenta registrada es vampiro y una que no se reconoce es fantasma (3.2). ¿Está bien así?
2. **Tope hormiga.** Los ejemplos de Condusef que verifiqué son de $15 a $30 cada uno (W1). ¿Mantiene el tope de **$150** por gasto, **8 gastos** en 4 semanas, **3 semanas de 4** y **1 %** del ingreso, o prefiere un tope menor? ¿Qué subcategorías de Alimentación son recortables?
3. **Servicios del hogar (V-C).** ¿Acepta **25 %** sobre la mediana en **2 de los últimos 3 periodos**, con mínimo de 6 periodos de historia? ¿Qué servicios más entran (internet, telefonía fija)? ¿La marca "es por la temporada" le parece suficiente para el clima?
4. **Intereses por el mínimo (V-D).** ¿Le parece bien que **un solo corte** baste, en lugar de "2 de 3"?
5. **Carga de deuda.** Condusef (verificado) recomienda no pasar de **30 %** y BBVA, de **30 a 35 %**; el diseño usa ámbar desde 20 % y rojo sobre 35 %. ¿Baja el rojo a 30 %? ¿Acepta **10 %** y **20 %** del ingreso mensual en MSI (el 10 % es de una especialista, sin página primaria) y **3** y **4** MSI a la vez?
6. **Costo financiero total.** No encontré un umbral confiable de CAT. ¿Quiere que el semáforo no juzgue el CAT y solo lo muestre?
7. **Libros compartidos y de Papá.** ¿Cualquier miembro responde y vale la última respuesta? ¿Las fugas de Papá las decide el albacea sin consultar al dueño si es otra persona?
8. **Roadmap.** ¿Bloque 6 de la Fase 8, antes o después del bloque 5 de inglés? ¿Quiere un formulario corto de propósito en el teléfono?
9. **Inflación.** ¿Quiere comparar el crecimiento de un cobro (V-B, 10 %) contra la inflación de INEGI? No la consulté.
10. **IA local.** ¿Se difiere por completo (propuesta) o quiere la opción futura de un modelo local en la laptop?
11. **Decisión.** ¿Confirma **D30** (reglas locales; una fuga principal por cobro; el comercio no sale del dispositivo) y la aclaración C-2 al texto de 5.2, regla 8?

## 13. Fuentes y su estado

Verificación del **18/nov/2026**: las páginas de `www.gob.mx` y `www.bbva.com` se abrieron y se leyeron completas; `condusef.gob.mx`, `revista.condusef.gob.mx` y los medios (El Imparcial, Expansión, Uno TV, Portafolio, Mercado Pago) **no estuvieron al alcance** de la sesión. Estado: **Verificada** = la página se abrió y el texto citado está en ella; **No encontrada** = no apareció en ninguna página alcanzable (el dato queda como [Propuesta]). Las citas son literales y breves.

| Clave | Dato | Estado y fuente | Texto citado | Uso |
|---|---|---|---|---|
| W1 | Qué es el gasto hormiga y ejemplos | **Verificada.** Condusef, gob.mx, 25/feb/2022: <https://www.gob.mx/condusef/articulos/cuida-tu-bolsillo-de-los-gastos-hormiga?idiom=es>. Condusef, gob.mx, 14/may/2020: <https://www.gob.mx/condusef/es/articulos/gastos-chiquitos-que-salen-caro> | "Nombramos gastos hormiga a esos pequeños consumos diarios que realizamos sin pensar que al final del día afectan nuestras finanzas." Ejemplos: café 20, torta 30, refresco 15, boleada 25: "90 pesos diarios… 2700 pesos". 2020: "golosinas, refrescos, frituras… dos o tres cafés diario" y "plataformas de streaming… Uber, DiDi… Spotify" | Definición de 3.1; Condusef también cuenta suscripciones como hormiga (diferencia explicada en 3.1) |
| W1b | Rangos por compra "café 12 a 90, bebidas 10 a 60, comida 35 a 170" | **No encontrada** en página alcanzable (solo prensa) | — | El tope de $150 queda **[Propuesta]** |
| W2 | Hormigas de más de 12 % del ingreso anual | **Verificada solo como cita de BBVA México:** <https://www.bbva.com/es/mx/salud-financiera/como-entender-y-controlar-los-gastos-hormiga-en-mexico/>. **No encontrada** en una página de Condusef | "Según datos de la… (CONDUSEF), los 'gastos hormiga' pueden llegar a representar más del 12% de los ingresos anuales de una persona." | No se usa como umbral |
| W3 | Definiciones de fantasma y vampiro | **Verificada, y se contradicen entre fuentes.** BBVA Perú: <https://www.bbva.com/es/pe/salud-financiera/que-son-los-gastos-hormiga-fantasma-y-vampiro-y-como-identificarlos/>. BBVA México (detox): <https://www.bbva.com/es/mx/salud-financiera/detox-financiero-redirige-el-presupuesto-para-construir-bienestar/>. PENSIONISSSTE, gob.mx: <https://www.gob.mx/pensionissste/es/articulos/llegas-al-fin-de-la-quincena-sin-dinero-identifica-los-tipos-de-gastos-que-afectan-tu-presupuesto?idiom=es>. Las definiciones de la revista de Condusef (2021 y 2022) **no se pudieron abrir** | BBVA Perú, fantasma: "gastos en los que incurrimos sin darnos cuenta"; ejemplo "membresía al gimnasio que no usas". Vampiro: "a pesar de ser fijos, no se pueden detectar fácilmente"; ejemplos "fugas de agua, gas, mal uso de electrodomésticos o problemas con las instalaciones de luz". BBVA México: "Eliminar 'vampiros de suscripción': apps, plataformas de streaming o membresías que ya no se usan, pero siguen generando cargos automáticos." PENSIONISSSTE, fantasma: "pagos recurrentes que olvidamos… se deducen automáticamente" | Contraste. BBVA México llama "vampiro" a la suscripción olvidada; BBVA Perú, al costo fijo oculto. Por eso se adoptan las definiciones del dueño. Apoya V-C |
| W4 | "Gasto zombi" | **No encontrada** (búsqueda en gob.mx, bbva.com y bbva.mx) | — | La definición es del dueño |
| W5 | Deuda buena y mala | **Verificada (BBVA México):** <https://www.bbva.com/es/mx/salud-financiera/como-tener-una-deuda-sana-sostenible/> y <https://www.bbva.com/es/mx/salud-financiera/deudas-buenas-o-deudas-malas-relevantes-en-una-estrategia-financiera/>. **La definición de Condusef** (patrimonio, ingresos) **no encontrada** en página alcanzable | "Deuda saludable o buena: Aquella que aporte beneficios a largo plazo, como el historial crediticio… créditos educativos, hipotecarios". "Deuda no saludable o mala: Surge cuando se rebasa la capacidad de pago o se adquiere sin una evaluación adecuada, generalmente para gastos no esenciales… el uso de un crédito para cubrir otro." "Las buenas ayudan a las personas a generar un patrimonio, las malas tienden a disminuir el ahorro" | Criterio B1, propósitos y señal M1 (rodar una deuda) |
| W6 | Límite de endeudamiento | **Verificada el 30 %:** Condusef, gob.mx (comunicado sin fecha visible; usa cifras de la CNBV a dic/2012): <https://www.gob.mx/condusef/prensa/condusef-recomienda-a-instituciones-financieras-cautela-en-el-otorgamiento-de-creditos>. BBVA México: página de W5 y la de la SNEF 2024. **El "35 a 40 %" no se encontró** en página alcanzable | Condusef: "el nivel de deuda que tenga una persona no supere el 30% de sus ingresos… si una persona gana $10,000 al mes, no deba más de $3,000". BBVA: "sus pagos mensuales no superan entre el 30% y el 35% del ingreso" y "no deben pasar del 30% de los ingresos" | B4a (pregunta 5). El 35 a 40 % queda **[Propuesta]** |
| W7 | MSI y vida útil | **Verificada.** Condusef, gob.mx, 10/nov/2026: <https://www.gob.mx/condusef/articulos/en-este-buen-fin-compra-con-conciencia?idiom=es> | "Los Meses sin intereses se recomiendan para productos con una vida útil que supere la duración de la deuda (línea blanca o tecnología, no para despensa o ropa)." | B3 (plazo contra vida útil) |
| W7b | MSI hasta 10 % del ingreso (especialista) | **No encontrada** en página alcanzable (solo prensa) | — | B4b queda **[Propuesta]** |
| W8 | Pago mínimo, intereses y MSI en tarjetas | **Verificada.** BBVA: <https://www.bbva.com/es/salud-financiera/que-es-el-pago-minimo-y-el-pago-para-no-generar-intereses-en-una-tarjeta-de-credito/> | "Pagar sólo el mínimo aumenta el tiempo para liquidar el crédito e incrementa el costo financiero." El pago para no generar intereses descuenta los saldos en "meses sin intereses" y suma "la mensualidad exacta que corresponda cubrir en ese mes". Sin el mínimo a tiempo: "cargos por pago tardío" y atraso en Buró | V-D, B6a, B6b |
| W9 | Cancelar un cobro: folio, plazos y queja | **Verificada.** Profeco, gob.mx, 5/may/2026: <https://www.gob.mx/profeco/prensa/profeco-orienta-a-la-poblacion-ante-cobros-automaticos-injustificados-al-cancelar-un-servicio?state=published>. Profeco, gob.mx: <https://www.gob.mx/profeco/prensa/que-las-suscripciones-digitales-no-afecten-tu-presupuesto-profeco-te-orienta?idiom=es> | "los proveedores deben proporcionar a las personas un folio o número tras realizar la solicitud de cancelación". "al menos cinco días naturales de anticipación" para avisar una renovación automática. "Desinstalar la aplicación o plataforma no detiene los cobros". Para la queja: "identificación oficial, contrato, folio de cancelación, comprobantes de pago y el estado de cuenta". Lista de preguntas de uso (cuándo se usó por última vez, si el costo subió y ya no vale lo que se paga): "Si dos o más opciones resultan afirmativas, hay que considerar la cancelación inmediata." | Acción del zombie (folio), cobro tras cancelar, apoyo a Z1 |

## Pendientes de la revisión de calidad del bloque 6 (F8-6.8)

- **H-09 (`fin_patron_crear` sin bloqueo asesor).** Dos dispositivos que detectan el mismo patrón a la vez: el segundo recibe 23505 en vez del id existente; el reintento funciona. Corrección propuesta: `pg_advisory_xact_lock(hashtextextended('fin_patron:' || p_libro || ':' || v_clave, 0))` antes de buscar. Exige redefinir la función completa en una migración nueva; queda pendiente por ser de bajo riesgo y sin pérdida de datos.
- **H-04 (un gasto, una sola fuga) — DECISIÓN DEL DUEÑO (20/nov/2026): se acepta esta solución** (no la regla estricta de prioridad). **Regla de presentación para la pantalla de fugas:** la tarjeta de una hormiga muestra el número de compras y el total del MISMO conjunto de gastos (`gastoIds` y `totalCentavos` de `FugaDetectada`, que salen de la misma lista), nunca el conteo con el que se decidió el hábito. Corregido: la hormiga mide el hábito de la categoría con todas sus compras chicas (H3 a H5) pero no cuenta los gastos que ya sostienen otra fuga confirmada (fantasma > zombi > vampiro > hormiga, sección 4.1).
- **H-02 (sin dato de pagos al corte).** Corregido: `CorteDeTarjeta.pagosAlCorteCentavos` es nulo si no se capturó; migración `20261150`. Los registros anteriores con 0 se leen como nulo en la vista de vigentes.
- **H-11.** El objetivo de una deuda tampoco admite «$» (igual que el servidor).

## Control de cambios

| Versión | Fecha | Cambio |
|---|---|---|
| 0.1 | 18/nov/2026 | Primera versión, propuesta para aprobación del dueño |
| 0.2 | 18/nov/2026 | Respuestas del dueño (12.1) y D30 registrada; el vampiro y el zombi por ajustar en 0.3 |
| 0.3 | 18/nov/2026 | Fuentes verificadas en gob.mx y bbva.com (sección 13: estado, URL y texto citado de cada una; lo no encontrado queda como propuesta). Respuestas del dueño en el cuerpo: vampiro con servicios del hogar que se inflan (V-C, contra su mediana) e intereses por pagar solo el mínimo (V-D); zombi con baja formal y folio de cancelación (Z5 y captura del folio); crédito automotriz como `genera_ingreso`; tarjeta con intereses como deuda mala; deuda mala solo avisa; Comercio, cargo automático y revisión mensual confirmados. Umbrales nuevos: servicios 25 % sobre la mediana en 2 de 3 periodos con mínimo de 6; intereses por el mínimo con un solo corte. Salta de 0.1 a 0.3 por indicación del arquitecto |
