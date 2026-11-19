# Fase 8 · Finanzas: dispersión de ingresos con confirmación

> Borrador v1.0 (19/nov/2026) para aprobación del dueño. Paquete F8-6.4. Nace de un caso real: el dueño registró su **sueldo del viernes 13/nov** (semana anterior) como «ingreso extra»; en **Hoy** del teléfono «Quedan» marcaba 0.00 aunque ese dinero debía verse, y en movimientos aparecía «ingreso, deudas y remanente» sin que ninguna pantalla mostrara **cómo se reparte** (presupuesto, deuda, remanente) **antes** de aplicarlo. Base: D3/D6 (el dinero no va a IA ni a bocinas), D5 y D19 (roles y libros), diseño de FINANZAS 5.6 bis (la cascada, puntos 1, 6 y 7), 5.1 (extras) y 5.1 bis (punto 4), `fase-1-finanzas.md`, `fase-2-finanzas.md` y `docs/DISENO_UX_UI.md` (voz y estilos).

## Decisiones del dueño (18 y 19/nov/2026), confirmadas

1. **Ahora, con confirmación.** Cada ingreso muestra su reparto y la persona lo valida, lo edita o lo deja para después.
   *Lectura del arquitecto, **por confirmar con el dueño**:* la confirmación es lo normal y, cuando el ingreso **cubre todos los pagos de deuda y el presupuesto del periodo** (la deuda es menor que el ingreso), la dispersión puede ser **automática**. Los dos modos son un **parámetro**; la regla de cuándo es automática es la **pregunta abierta P1**.
2. **Lo no repartido se arrastra a la semana actual y cuenta en «Quedan»** de la semana actual.
3. **Aplica a TODOS los ingresos**, no solo a los extras (sueldos, pensión, apoyos y extras).
4. **Corregir el tipo de un ingreso** (el sueldo se registró como «extra»): hace falta poder pasarlo de ingreso extra a ingreso de un ingreso configurado (sueldo) **con el libro solo-agregar** (anulación y contraasiento), sin perder el historial.

## Alcance

1. Una **propuesta de reparto** para cada ingreso del libro, con la cascada del diseño: presupuesto de la semana → pagos de deuda (mínimos y abonos) → remanente (abono extra a la deuda de mayor costo o, sin deuda, ahorro).
2. La hoja **«Repartir ingreso»** (teléfono y laptop): propuesta editable con **Aceptar**, **Editar** y **Dejar para después**.
3. El estado **«Por repartir»** visible en Hoy, Semana (teléfono y laptop) y el tablero, y **«Quedan»** que incluye lo no repartido arrastrado.
4. **Corregir el tipo de un ingreso** con anulación y contraasiento.
5. Diseño del servidor (tablas y funciones) **sin migración escrita**; ver la sección 8.

Fuera de alcance: repartir ingresos de semanas anteriores a la activación (se dan por repartidos), repartir un préstamo recibido (no es ingreso: crea deuda, 5.1 bis punto 7), reparto entre libros (las aportaciones siguen siendo transferencias), voz e IA.

## Reglas

- **Dinero en centavos (`int`)**; las sumas de la propuesta usan los equivalentes exactos del plan y el reparto de redondeos R1 y R2 (`dinero.dart`): los renglones suman exactamente el total.
- **Semana de lunes a domingo; cada movimiento pertenece a la semana de su fecha** (5.6 bis, punto 2). El sueldo del viernes 13/nov es de la semana del 9 al 15/nov y **sigue siéndolo en sus reportes**; lo que no se reparte **se arrastra** a la semana actual solo para «Quedan» y «Por repartir».
- **Libro solo-agregar.** Repartir no edita el ingreso. Corregir su tipo agrega dos asientos con el mismo grupo y motivo.
- **La app propone y la persona confirma; nunca mueve dinero sola** (5.6 bis, puntos 6 y 7). Por eso, aun en modo automático, **solo se asigna lo comprometido** (presupuesto y pagos de deuda apartados); **el remanente queda «por repartir»** hasta que la persona lo confirma (P1).
- **Qué mueve dinero y qué no al confirmar:** los renglones de presupuesto y de «pago de deuda» **asignan** (no crean movimientos): el pago a la deuda se registra en su fecha con «Registrar pago» (Fase 8, pagos). Los renglones de **abono extra** (pago de deuda) y de **ahorro** (transferencia) **sí** crean movimientos (5.6 bis, punto 8), con ids estables para que repetir la confirmación no duplique.
- **Sin IA ni bocinas (D3, D6).** La propuesta se calcula en el dispositivo con el dominio puro. Ningún monto de este flujo sale a IA, bocinas ni tablet pública; con el modo privado los montos se ocultan igual que en el resto de Finanzas (`MontoOcultable`).
- **Voz:** de tú, breve y sin culpa. Ejemplos: «Repartir tu ingreso», «Esto es lo que propongo», «Aceptar», «Editar», «Dejar para después», «Quedó por repartir», «Listo: repartí tu ingreso» (sin monto en el aviso, para respetar el modo privado).

## Estados de un ingreso

| Estado | Qué significa | Cuenta en «Por repartir» | Cómo se llega |
|---|---|---|---|
| **Por repartir** | Entró y nadie lo repartió | Sí, completo | Al registrar el ingreso o al «Dejar para después» |
| **Propuesta** | Hay una propuesta guardada (con ediciones) sin confirmar | Sí, completo | La persona edita y sale sin aceptar |
| **Confirmado** | La persona aceptó el reparto | Solo el renglón «Por repartir», si lo hubo | Aceptar |
| **Automático** | Se aplicó solo (modo automático y el ingreso cubre todo) | Solo el renglón «Por repartir» (el remanente) | Al entrar el ingreso |
| **Anulado** | El ingreso se anuló o se corrigió su tipo | No | Anulación o corrección de tipo |

Un ingreso solo tiene **un reparto vigente** (índice único por movimiento). Cambiarlo después de confirmado es la **pregunta abierta P5**.

## La propuesta de reparto

Es la función `proponerDispersion` de `finanzas_dominio`. **No duplica reglas:** usa el plan semanal (`PlanSemanal`), el orden del abono extra (`ordenDeAbonoExtra`), el destino del remanente (`repartirRemanente`) y las propuestas de recorte (`proponerRecortes`).

**Entradas:** el ingreso (monto, fecha, si es sueldo configurado o extra), el plan de la semana del libro, las deudas con su saldo y los parámetros (`ParametrosDispersion`: modo, «desde», parte libre del extra, tope de ahorro).

**Salidas** (`PropuestaDispersion`): renglones (`LineaDispersion`) agrupados en partidas propuestas, pagos a deuda, abonos extra, ahorro y libre; el **remanente** y su destino; el **faltante** (cuánto no alcanzó) y lo que **queda por repartir**.

### Un sueldo (ingreso configurado que está en el plan)

Cubre su parte del presupuesto y de la deuda **de un periodo de su frecuencia** (una quincena, un mes…). Su parte es el monto planeado entre el ingreso anual total del plan, en exacto:

```text
cubre(partida o deuda) = anual(partida o deuda) × monto planeado del sueldo ÷ ingreso anual del plan
```

No depende de la frecuencia y funciona con varios sueldos en un libro. Lo que pasa de eso es **remanente**.

**Ejemplo** (hogar de Ana y Alex, 5.6 bis punto 5; ilustrativo): la quincena de Ana ($9,000) cubre **$6,669.38** de presupuesto (renta $2,250.00, etc.) y **$478.13** de deuda (tarjeta $337.50, préstamo familiar $140.63); el **remanente es $1,852.49**, que va a **abono extra a la tarjeta** (mayor costo). El sueldo mensual de Alex ($14,000) cubre $10,374.58 de presupuesto y $743.75 de deuda; remanente $2,881.67.

### Un extra (sin ingreso configurado)

Sin periodo que cubrir. Sigue 5.1 bis punto 4: (1) completar los sobres de previsión que no alcanzan, (2) deuda con costo por mayor tasa, (3) préstamos familiares, (4) ahorro, (5) parte libre (**0 % por defecto**).

### Destino del remanente (5.6 bis, punto 7)

1. Abono extra a la deuda **con costo** de mayor tasa (o el grupo de deudas prioritarias, si el libro lo tiene), sin pasar de su saldo. Después, préstamos familiares. Las compras a MSI no reciben extra.
2. Sin deuda (o ya pagada) → **ahorro**; con **tope de ahorro** (la meta), lo que lo pase queda **libre**.
3. **Ahorro mínimo con deuda** (parámetro del hogar, 0 % por defecto): esa parte del remanente va a ahorro desde el inicio.

### Si el ingreso no alcanza (lectura del arquitecto, P3)

Se financia en este orden y lo que falta se recorta del final hacia el principio: **partidas protegidas**, **mínimos de deuda**, **demás partidas** (necesarias primero, discrecionales al último), **abonos sobre el mínimo** (préstamos familiares primero en recortarse, luego la deuda de menor costo). Lo protegido solo se toca si no queda otra cosa. El **faltante** se muestra y no se inventa dinero (5.6 bis, punto 6: déficit).

### Editar la propuesta

La persona puede cambiar el monto de cualquier renglón (cero o más, sin pasar de lo que queda por repartir). Lo que quite **queda por repartir**; lo que sube a un renglón sale de lo que queda. **Aceptar** guarda los renglones con el sobrante como renglón «Por repartir».

## Lo no repartido y el arrastre

- Todo lo pendiente (ingresos «por repartir» o «propuesta» y los renglones «Por repartir» de los confirmados) **se arrastra a la semana actual** y se suma a «Quedan»: **Quedan = presupuesto de la semana − gastado + por repartir**.
- Solo la **semana de hoy y las siguientes** llevan el arrastre; una semana pasada conserva sus cifras de entonces. Un ingreso con fecha futura cuenta cuando llega su semana.
- Mientras no se reparta, el arrastre se repite semana tras semana (no caduca). Al repartir, se descuenta.
- **Lectura y pregunta abierta P6:** se suma completo, como pidió el dueño. Si el presupuesto de la semana ya salió de ese mismo dinero, la suma lo cuenta dos veces en la vista provisional; al confirmar deja de pasar.

## Corregir el tipo de un ingreso

Caso del dueño: el sueldo estaba como «ingreso extra».

1. En el movimiento (teléfono: menú de la fila; laptop: botón del detalle) → **«Cambiar tipo…»** → elegir el tipo nuevo: un **ingreso configurado** (sueldo, pensión…) u **ingreso extra** → motivo (obligatorio, mínimo 3 caracteres visibles).
2. La app agrega **dos asientos con el mismo grupo y motivo**: la **anulación** del original (contraasiento con su misma fecha) y un **ingreso nuevo** con el mismo monto, **la misma fecha económica**, la misma cuenta de destino y la cuenta de origen del tipo correcto. Nada se borra ni se edita.
3. Efectos: la semana del 9 al 15/nov deja de contar el extra y cuenta el sueldo como ingreso de su ingreso configurado (no se duplica); el ingreso nuevo nace **«por repartir»** y se reparte como **sueldo** (cubre presupuesto y deuda de su periodo).
4. **Si el ingreso ya está confirmado o automático**, la corrección **no se permite** hasta resolver P5 (los movimientos que el reparto creó siguen siendo reales).
5. En un libro **compartido**, si el ingreso lo registró otra persona, la anulación y el asiento nuevo nacen **pendientes** y los confirma esa persona (5.0 ter). En el libro de Papá van «en nombre de» con motivo.

## Permisos por rol (D5, D19; espejo de `fin_puede`)

| Quién | Ver «Por repartir» y la propuesta | Aceptar, editar, dejar para después | Cambiar tipo |
|---|---|---|---|
| Titular o miembro del libro (dueño, pareja) | Sí | Sí | Sí (su propio ingreso; el de otro, pendiente de confirmación) |
| Albacea (libro de Papá) | Sí | Sí, **en nombre de Papá y con motivo**; sale en la bitácora | Sí, en nombre de Papá con motivo |
| Suplente del albacea | Sí | Solo cuando el servidor lo dice (`fin_puede`, I4) | Igual |
| Cuenta maestra (D19) | Solo lectura con consulta registrada | **No** (sin botones) | No |
| Lector de un libro público | Lectura | No | No |
| Familiar, cuidador, Casa | No ven Finanzas | — | — |

El servidor vuelve a verificar todo con la misma función que ya protege el libro (`fin_puede(libro, 'escribir')`): la interfaz no es la barrera. El resumen de **Hoy** usa solo los libros que la persona lleva (no los de la maestra ni los públicos), como ya hace.

## Modelo de datos propuesto (sin migración escrita)

Tablas (prefijo `fin_`, con `hogar_id` y `libro_id`, RLS como el resto de Finanzas):

| Tabla | Campos principales |
|---|---|
| `fin_dispersiones` | `id uuid`, `hogar_id`, `libro_id`, `movimiento_id` (ingreso repartido; **único** mientras no esté anulada), `estado` (`por_repartir`, `propuesta`, `confirmada`, `automatica`, `anulada`), `modo` (`confirmacion`, `automatico`), `creada_en`, `resuelta_por`, `resuelta_en`, `en_nombre_de`, `motivo` |
| `fin_dispersion_lineas` | `id`, `dispersion_id`, `destino` (`presupuesto`, `pago_deuda`, `abono_extra`, `ahorro`, `libre`, `por_repartir`), `referencia_id` (partida o deuda), `etiqueta`, `monto bigint` (≥ 0), `movimiento_id` (el que creó, si movió dinero) |
| `fin_parametros` (columnas nuevas) | `dispersion_modo` (por omisión `confirmacion`), `dispersion_desde date` (se fija al activar la función: **lunes de la semana anterior**), `dispersion_parte_libre_pb`, `dispersion_tope_ahorro` |

Restricciones: `sum(monto)` de las líneas = monto del ingreso (el renglón «por repartir» absorbe el resto); una dispersión por `movimiento_id` vigente; si el ingreso se anula, un disparador pasa la dispersión a `anulada` (los movimientos que creó **no** se anulan solos: se avisa).

Funciones (todas `security definer` con `fin_puede`, idempotentes por UUID):

| Función | Qué hace |
|---|---|
| `fin_confirmar_dispersion(p_dispersion jsonb)` | En una transacción: guarda la dispersión y sus líneas, crea los movimientos de abono extra y ahorro (ids estables por dispersión y destino, estado confirmado) y devuelve la dispersión. Exige `en_nombre_de` y motivo en el libro de Papá. Rechaza si el ingreso está anulado, si ya tiene una dispersión vigente o si `sum(líneas)` no es el monto. |
| `fin_guardar_propuesta(p_dispersion jsonb)` | Guarda el estado `propuesta` (borrador editado); no crea movimientos. |
| `fin_corregir_tipo_ingreso(p_movimiento uuid, p_cuenta_origen uuid, p_motivo text, p_grupo uuid, p_id_anulacion uuid, p_id_nuevo uuid)` | Agrega anulación y asiento nuevo en una transacción (con el estado pendiente si involucra a otra persona); rechaza si el ingreso tiene una dispersión confirmada o automática. |
| `fin_ingresos_por_repartir(p_libro uuid)` | Lectura: ingresos desde `dispersion_desde` sin dispersión vigente o con renglón «por repartir» (solo para listas grandes; la app calcula con lo cargado). |

La aplicación automática se ejecuta **en el dispositivo** al cargar (misma regla que la propuesta) y llama a `fin_confirmar_dispersion` con `modo = automatico`; no hay trabajo de servidor que mire montos (D3).

## Pantallas

**Hoja «Repartir ingreso»** (la misma en teléfono y laptop, como la hoja de pago: hoja inferior en el teléfono, diálogo en la laptop):

```text
┌ Repartir ingreso ───────────────────────┐
│ Sueldo de Ana · vie 13 nov    $9,000.00 │
│ Esto es lo que propongo:                │
│ Presupuesto de la semana     $6,669.38 ›│
│   Renta … Alimentación … (renglones)    │
│ Pagos de deuda (apartados)     $478.13 ›│
│ Remanente                    $1,852.49  │
│   → Abono extra a Tarjeta    $1,852.49 ›│
│ Queda por repartir               $0.00  │
│ [Dejar para después] [Editar] [Aceptar] │
└─────────────────────────────────────────┘
```

- **Aceptar:** guarda y crea los movimientos de abono extra y ahorro; aviso «Listo: repartí tu ingreso» con **Deshacer** (anula los movimientos creados con la anulación normal y deja el ingreso «por repartir»).
- **Editar:** cada renglón muestra su monto y se toca para teclearlo; «Queda por repartir» se recalcula; el ahorro pide la cuenta de ahorro (si no hay, ese dinero queda por repartir y la hoja lo dice).
- **Dejar para después:** guarda como «Por repartir» (o «Propuesta» si hubo ediciones). Cierra la hoja sin culpa.
- Faltante: «Este ingreso no alcanza para todo: faltan $X» con los recortes propuestos; los protegidos no se tocan.
- Sin permiso de escribir: la hoja se abre en lectura y sin botones de acción.
- Meta: en el teléfono, de abrir a **Aceptar** en menos de 10 s sin editar.

**Teléfono (`DISENO_UX_UI.md` §9).** (1) **Hoy:** la tarjeta de Finanzas muestra **Quedan** con lo por repartir y, debajo, «Por repartir $X» que abre la hoja. (2) **Finanzas › Semana:** una tarjeta «Por repartir» arriba de la cascada con la lista de ingresos pendientes y el botón «Repartir» (alto táctil ≥ 48 dp). (3) **Movimientos:** el menú de la fila de un ingreso agrega «Cambiar tipo…».

**Laptop (§8).** (1) **Tablero y Semana:** la tarjeta «Por repartir» con los ingresos pendientes (estado, fecha, monto) y los botones «Repartir» y «Cambiar tipo». (2) **Movimientos:** el detalle de un ingreso agrega «Cambiar tipo…». (3) Atajo propuesto: **R** sobre un ingreso pendiente abre la hoja.

**Accesibilidad:** el estado se dice con texto («Por repartir», «Propuesta»), no solo con color; con montos ocultos no hay cifras en pantalla ni en el lector.

## Criterios de aceptación

1. Todo ingreso confirmado y no anulado del libro, con fecha desde `dispersion_desde`, aparece como **«Por repartir»** hasta que se reparte, sea sueldo o extra.
2. La propuesta de un **sueldo** cubre su parte del plan (fórmula anual); los renglones suman **exactamente** el total (R2). Ejemplo: quincena de Ana = presupuesto $6,669.38, deuda $478.13, remanente $1,852.49 a abono extra a la tarjeta.
3. La propuesta de un **extra** sigue 5.1 bis punto 4: sobres de previsión faltantes, deuda con costo por mayor tasa, familiares, ahorro y parte libre (0 % por defecto).
4. Sin deuda, todo el remanente va a ahorro; con **tope de ahorro**, el exceso queda libre; con **ahorro mínimo con deuda**, esa parte va a ahorro.
5. El abono extra **no pasa del saldo** de la deuda y el resto sigue la cascada.
6. Si el ingreso **no alcanza**, el faltante se informa, las partidas protegidas no se recortan y lo discrecional se recorta primero.
7. **Editar** no puede dejar renglones negativos ni pasar del monto; lo que se quita queda **por repartir**.
8. **Aceptar** guarda la dispersión y crea solo los movimientos de abono extra y ahorro, con ids estables: repetir Aceptar no duplica movimientos.
9. **Dejar para después** no crea movimientos y el ingreso sigue pendiente.
10. Lo pendiente **se arrastra a la semana actual y a las siguientes**, no a las pasadas, y no cuenta un ingreso de fecha futura antes de su semana.
11. **«Quedan» = presupuesto − gastado + por repartir**, igual en Hoy, Semana y el tablero, al centavo.
12. En modo con confirmación nada se aplica solo. En modo automático solo se asigna lo comprometido cuando el ingreso lo cubre todo; el remanente queda «por repartir» y no se crean movimientos.
13. **Corregir el tipo** agrega una anulación (misma fecha económica) y un ingreso nuevo con el mismo monto, fecha y cuenta de destino, con el mismo grupo y motivo; el saldo de la cuenta no cambia; el original no se edita.
14. Tras corregir, la semana del ingreso deja de contar el extra y no duplica el ingreso; el ingreso nuevo está «por repartir» y se reparte como sueldo.
15. No se corrige el tipo de algo que no es ingreso, de un ingreso ya anulado, de uno ya repartido, ni a un tipo igual o que no sea de origen de ingreso; el motivo es obligatorio.
16. **Permisos:** sin permiso de escribir (maestra, lector, libro archivado) no hay botones y el servicio rechaza la llamada; en el libro de Papá, el albacea confirma en su nombre con motivo; cada persona ve solo sus libros.
17. Nada de este flujo sale del dispositivo hacia IA, bocinas ni tablet pública; con montos ocultos no hay cifras.
18. La hoja funciona con letra grande y 360 × 800 dp sin cortar los botones (mismo marco que las hojas del (+)).

## Casos de prueba

**Dominio** (`paquetes/finanzas_dominio/test/dispersion_test.dart`, criterios 1–7, 10, 12–15): quincena de Ana y mensual de Alex con el plan del ejemplo; renta = $2,250.00 por quincena; los dos sueldos cubren el plan anual dentro del redondeo; sin deuda → ahorro; ahorro mínimo; abono extra topado por saldo; extra a tarjeta y luego familiar; extra con sobres de previsión; parte libre y tope de ahorro; ingreso corto con protegidas intactas y mínimo de tarjeta protegido; ingreso cero rechazado; editar (quitar, pasar de monto, negativo, mover entre renglones, inmutabilidad); modo automático (cubre todo / no cubre / por omisión es confirmación); arrastre (pasado, actual, futuro, confirmado con sobrante, propuesta, anulado, «desde», otro libro); corrección de tipo (asientos, saldo, extra de la semana, rechazos, motivo, doble corrección).

**App** (`app/test/modulos/finanzas/dispersion_test.dart`, criterios 8–11, 13, 16–18): servicio (aceptar crea abono extra y ahorro con ids estables, repetir no duplica, dejar para después, sin permiso, albacea con motivo, corregir tipo sobre el ingreso de las pruebas), «Quedan» en la tarjeta de Hoy y en cifras, la tarjeta «Por repartir» y la hoja en teléfono y laptop, letra grande, montos ocultos.

**Servidor** (cuando lo construya el backend): RLS (maestra y lector no escriben), unicidad por movimiento, suma de líneas, idempotencia de `fin_confirmar_dispersion`, anulación del ingreso que pasa la dispersión a `anulada`, y rechazo de la corrección de tipo si ya está repartido.

## Preguntas abiertas para el dueño

- **P1.** ¿Cuándo es automática? Lectura propuesta: modo automático **activado por el dueño** y el ingreso **cubre presupuesto y pagos de deuda del periodo**; entonces se asigna lo comprometido y **el remanente queda por repartir** (la app no mueve dinero sola). ¿O quieres que en modo automático también se aplique el abono extra o el ahorro?
- **P2.** ¿Desde cuándo? Propuesta: `dispersion_desde` = lunes de la semana anterior al activar (en tu caso, el 9/nov), para que tu sueldo del 13/nov aparezca y el historial anterior no se llene de pendientes. ¿Correcto?
- **P3.** Cuando el ingreso no alcanza, el orden de financiamiento propuesto es protegidas, mínimos de deuda, demás partidas, abonos sobre el mínimo. ¿Lo confirmas?
- **P4.** ¿El renglón «Pagos de deuda» debe crear el pago al confirmar, o basta con apartarlo y pagar en su fecha? Propuesta: **solo apartar**, porque el pago real ocurre en el banco y se registra con «Registrar pago».
- **P5 — RESPUESTA DEL DUEÑO (19/nov/2026): el reparto SE PUEDE CAMBIAR después de confirmado** (no solo deshacer). Pendiente de construir: una operación «cambiar reparto» que anule los movimientos que creó y registre los nuevos con el reparto editado (libro solo-agregar: anulación más movimientos nuevos, con motivo), idempotente y con control de versión si dos dispositivos lo editan a la vez; con eso también se podrá corregir el tipo de un ingreso ya repartido. Pregunta original: ¿Cómo se deshace o se cambia un reparto ya confirmado (y por tanto cómo se corrige el tipo de un ingreso ya repartido)? Propuesta: «Deshacer» anula los movimientos que creó y el ingreso vuelve a «por repartir»; hasta entonces no se permite cambiar el tipo.
- **P6.** «Quedan» suma el dinero por repartir completo. ¿Quieres que, para no contar dos veces, solo sume la parte que **no** cubre el presupuesto de la semana?
- **P7.** ¿Los ingresos de **Papá** (pensión y apoyo 60+) se reparten igual, con el albacea? Propuesta: sí, con la misma hoja, en su nombre y con motivo.

## Qué debe construir el backend después

1. La migración con `fin_dispersiones`, `fin_dispersion_lineas` y las columnas de `fin_parametros`, con RLS por `fin_puede` y los índices únicos de la sección 8.
2. Las funciones `fin_confirmar_dispersion`, `fin_guardar_propuesta` y `fin_corregir_tipo_ingreso` (y, si hace falta, `fin_ingresos_por_repartir`), con pruebas de RLS e idempotencia.
3. El repositorio de Supabase de la app que implemente `RepositorioDispersiones` (hoy solo existe la versión en memoria) y su cola sin conexión: confirmar y corregir tipo **necesitan señal** (como estados de cuenta y aportaciones), porque el servidor liga los movimientos al guardar.
4. Los avisos (sin cifras, D20): «Tienes un ingreso por repartir» con título de catálogo.

## Estado de la construcción

- **Hecho (19/nov/2026), paquete F8-6.4:**
  - Dominio puro: `paquetes/finanzas_dominio/lib/src/dispersion.dart` (`proponerDispersion`, `PropuestaDispersion`, `ingresosDelLibro`, `porRepartirArrastrado`, `quedanConPorRepartir`, `estadoAlRecibir`, `corregirTipoDeIngreso`). 36 pruebas en `test/dispersion_test.dart`; todo el paquete: 477 en verde.
  - App: `ServicioDispersion` (aceptar, dejar para después, deshacer, modo automático, cambiar tipo), hoja `HojaRepartirIngreso`, tarjeta `TarjetaPorRepartir` (teléfono: Finanzas › Semana; laptop: Tablero y Semana), diálogo «Cambiar tipo…» (menú de la fila del teléfono y detalle de la laptop), «Quedan» con lo por repartir (`CifrasSemana.quedan`, tarjeta de Hoy). 28 pruebas en `app/test/modulos/finanzas/dispersion_test.dart`.
  - Todo detrás de la interfaz `RepositorioDispersiones` (`datos/repositorio_dispersiones.dart`).
- **Hecho (19/nov/2026), paquete F8-6.5 (servidor y conexión):**
  - **Servidor:** migración `supabase/migrations/20261147000000_finanzas_dispersion.sql` y 190 pruebas SQL en `supabase/tests/118_finanzas_dispersion.sql` (ver `supabase/README.md`, «Dispersión de ingresos con confirmación»). Tablas `fin_dispersiones` y `fin_dispersion_lineas`; columnas `dispersion_*` en `fin_parametros`; RPC `fin_guardar_propuesta`, `fin_confirmar_dispersion` (idempotente; crea solo los movimientos de abono extra y ahorro), `fin_deshacer_dispersion`, `fin_corregir_tipo_ingreso`, `fin_dispersion_parametros_cambiar` y `fin_ingresos_por_repartir`; disparador que pasa el reparto a `anulada` cuando se anula el ingreso; permisos por rol con la regla de `fin_puede`; aviso `ingreso_por_repartir` (D20, sin cifras).
  - **App:** `RepositorioDispersionesSupabase` (`datos/repositorio_dispersiones_supabase.dart`) y el cambio de `repositorioDispersionesProvider` (Supabase con sesión real; memoria en demostración). Confirmar, deshacer y corregir el tipo **necesitan señal**: el servidor liga o anula los movimientos en la misma transacción y la app recarga el libro; el servicio ya no agrega esos movimientos por su cuenta (`RepositorioDispersiones.ligaMovimientos`). 17 pruebas en `app/test/modulos/finanzas/dispersion_servidor_test.dart`. El aviso también está en el catálogo de la app (`catalogo_avisos.dart`).
  - **Lecturas del diseño, por confirmar con el dueño:** (1) deshacer un reparto lo resuelve la RPC `fin_deshacer_dispersion` (no estaba en la lista del diseño) para que anular los movimientos y el reparto sea atómico (P5); (2) `fin_dispersiones` cambia de estado por transiciones controladas (no es solo-agregar estricta, como `fin_transferencias`) y los renglones de una **propuesta** se reemplazan al guardarla de nuevo, los de un reparto confirmado nunca; (3) la columna de los renglones se llama `monto_centavos` (convención del esquema; el diseño decía `monto`); (4) si se anula el ingreso, los movimientos del reparto siguen vigentes y solo queda la entrada de bitácora `finanzas.dispersion_anulada` (el diseño decía «se avisa»); (5) la cuenta de ahorro debe ser otra cuenta de dinero activa del **mismo libro**; (6) un ingreso con la anulación pendiente (compartido, 5.0 ter) no pasa su reparto a anulada hasta que exista la confirmación de movimientos en el servidor (hoy `estado_inicial` no cambia).
- **Pendiente:** el modo automático corre en el dispositivo al cargar (`aplicarAutomaticas`); falta engancharlo a la carga con datos reales y que la app emita `ingreso_por_repartir` al detectar un ingreso por repartir. Sin señal al abrir la app los repartos no se conocen (no hay copia local cifrada de `fin_dispersiones`): un ingreso ya repartido aparece «por repartir» hasta la próxima carga con señal y el servidor rechaza repartirlo dos veces. Las preguntas abiertas P1 a P7 siguen esperando al dueño.
- **No cubierto por pruebas de pantalla:** los botones ocultos para quien solo lee (cuenta maestra, lector, libro archivado); se cubre en el servicio (rechaza la llamada) y en el servidor (42501). El demo no trae un lector de un libro con ingresos.
- **Límites conocidos:** la propuesta no conoce los sobres de previsión que no alcanzan (`faltantePrevision` queda vacío hasta que el módulo de previsión, 5.6 ter, lo entregue); `api/openapi.yaml` no lista aún estas RPC.
