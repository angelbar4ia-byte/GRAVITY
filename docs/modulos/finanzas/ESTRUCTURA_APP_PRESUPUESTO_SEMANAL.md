# App móvil de Presupuesto Semanal — Individual · Pareja · Familiar

> Documento de estructura funcional. Va de la **idea general** a lo **particular**: primero la visión y la lógica del sistema, después cada módulo con su propósito, datos, reglas y pantallas, y al final el módulo de Alimentación (menús y lista de compras), que parte de la tabla de ejemplo `PRESUPUESTO DE ALIMENTOS.xlsx`.
>
> **Versión 23 (19/oct/2026):** incorpora las decisiones del equipo: seguimiento manual de inversión (conexión a cuentas después), múltiples métodos de ahorro, **transparencia total** entre miembros con transferencias y auditoría, captura por 4 vías (manual, voz, imagen, precios de supermercados), moneda MXN, **Android primero** con cuenta en la nube, y modelo gratuito con suscripción posterior. Ver la sección 12 para el resumen de decisiones. **Novedades de la versión 3:** albacea y confirmaciones (5.0 ter), bitácora y reporte de auditoría en Excel/CSV (5.9), categorías eliminables si no tienen datos (5.2), catorcena como frecuencia, pros y contras de tecnología, recomendación para voz e imagen y modelo de suscripción (8 bis), e investigación de fuentes de precios y comercios de San Miguel de Allende, Comonfort y Celaya (6.11). **Novedades de la versión 4:** ruta de **costo cero** para la app, la nube, la voz y el OCR (8 bis); respuesta sobre las tiendas en línea y datos semilla en un libro Excel (6.11); y préstamos entre familiares **siempre sin interés** (5.0 ter). **Novedades de la versión 5:** se decide **Firebase Spark** y la pila **Flutter + Firebase**, con instalación directa del APK para pruebas y metas de rendimiento (8 bis); y se agrega el **plan de nutrición y la conexión con una app de hábitos** (6.12). **Novedades de la versión 6:** el plan de nutrición será **híbrido** y sin nutriólogo por ahora; se agrega la **inteligencia artificial** para recetas y para **inventario con foto del refrigerador** (6.13), la **conexión con una app de cuidados paliativos en casa** (6.14) y una **ficha para anotar la app de hábitos** (6.15). **Novedades de la versión 7:** **Claude (API de Anthropic)** como opción de IA, con su costo y su requisito de servidor (6.13); la **conexión entre las dos apps** con un contrato aparte e instrucciones para pegar en cada sesión de Claude Code (6.16, archivo `CONTRATO_CONEXION_APPS.md`); y la nota de que **las fases pueden rediseñarse** (10). **Novedades de la versión 8:** se empieza la IA con **Gemini**, y se aclara que la suscripción **Google AI Pro no cubre la API** (6.13); la **app de cuidados ya existe** (en su fase 3, rediseñable) y se conectará con el contrato (6.14); el **Excel nuevo** se revisará cuando se suba. Ambas apps se programarán con Claude Code. **Novedades de la versión 9:** el **motor de presupuesto semanal a detalle** (5.6 bis): definición de semana, algoritmo, ejemplo con números, cierre y reservas, asistente de arranque, modelo de datos y pruebas. **Novedades de la versión 10:** la dispersión del dinero en cascada **INGRESO → PRESUPUESTO → DEUDA → remanente a AHORRO** y las reglas de sobregasto (5.6 bis); la **forma de ingreso y día de pago por miembro**, con los pagos de fin de semana pasados al lunes (5.1 y 5.6 bis); y la **contabilidad básica con el detalle de cuentas** (5.0 bis 2). **Novedades de la versión 11:** la regla **primero pagar la deuda y después ahorrar**; la **prioridad de pago entre deudas por costo** (no por tamaño) con los préstamos familiares al último; el **estimador de tasa e intereses** con estados de cuenta, sin acceso a la banca móvil (5.3); y los **festivos pasan al siguiente día hábil** (5.1). **Novedades de la versión 12:** **todo el remanente paga deuda con costo** y las compras a **meses sin intereses (MSI) no reciben abono extra**; la **cartera real del hogar** (Nu, BBVA, Banamex, Mercado Pago, Stori y el crédito automotriz de Caja Popular Mexicana); el módulo de **tarjetas, MSI y beneficios** (5.3 bis) con el libro `FICHA_DEUDAS_Y_TARJETAS.xlsx`; y solo **festivos oficiales** en el calendario (5.1). **Novedades de la versión 13:** los **beneficios de tus tarjetas verificados en los sitios oficiales** y las reglas que la app debe aplicar por ellos (5.3 bis, punto 7); el detalle está en la hoja *Beneficios* de `FICHA_DEUDAS_Y_TARJETAS.xlsx`. **Novedades de la versión 14:** **captura de gastos por voz a detalle** (5.2): voz en el teléfono, varios gastos por frase y siempre con tarjeta de confirmación; **asistente de menús por monto a detalle** (6.5 bis): tres costos (teórico, de compra y neto con despensa) y tres perfiles de menú; y confirmado **Stori Green** y **Costco Banamex $650 al año** (5.3 bis). **Novedades de la versión 15:** el **inventario cuenta en el menú** (lo que ya hay no entra al monto, 6.5 bis) y el **simulador y las estrategias de pago de deudas a detalle** (5.3 ter), con ejemplo numérico, escenarios, reglas de seguridad y pruebas. **Novedades de la versión 16:** la exploración de **cuándo conviene liquidar primero la deuda pequeña**: costo efectivo con cargos fijos, prueba de la pequeña y ejemplos (5.3 ter, punto 11). **Novedades de la versión 17:** **inversión a detalle** (5.4 bis), **ahorro a detalle** con fondo de emergencia por niveles y reparto por orden (5.5 bis), y **objetivos y plan a detalle** con viabilidad, escenarios y plan del hogar (5.7 bis). **Novedades de la versión 18:** **gastos previsibles y cuenta de previsión** para refrendo, predial, agua y seguro, **imprevistos y gastos extra** (5.6 ter); fondo de emergencia **ampliable a 6 meses y a 1 año** (5.5 bis); y el **mapa de avance** de lo que falta (12.3). **Novedades de la versión 19:** **seguimiento, reportes, alertas y notificaciones a detalle** (5.9 bis): tres niveles de lectura, nueve indicadores de salud financiera con ejemplo, revisión semanal de 3 minutos, catálogo de reportes y de alertas, y reglas de notificación. **Novedades de la versión 20:** **ingresos a detalle** (5.1 bis): tipos y lo que no es ingreso, neto y descuentos de nómina, ingresos variables con dos métodos y ejemplos, extras con la cascada, vales de despensa, préstamos recibidos y otorgados, aportación proporcional en pareja y **calendario de flujo con peor caso**. **Novedades de la versión 21:** **estados de cuenta de débito, depósitos y movimiento de efectivo** (5.0 bis 3): origen del efectivo, ruta del dinero, conciliación renglón por renglón con Banamex y BBVA, fecha de operación y de aplicación, y depósitos por identificar. **Novedades de la versión 22:** **seguridad, privacidad y respaldo a detalle** (8 ter): capas de protección, roles aplicados en el servidor, teléfono perdido, respaldo cifrado, borrado de cuenta, requisitos verificados de Google Play y de la ley mexicana de datos personales de 2025, y pruebas. **Novedades de la versión 23:** **bienes (vehículo y vivienda) a detalle** (5.6 quater): fichas, partidas sugeridas que se vuelven sobres de previsión, **costo de tenencia contra salida de efectivo** con ejemplo, mantenimiento por kilómetros, contabilidad, documentos, alertas y reporte por bien.

---

## 1. Visión

**Objetivo:** conocer perfectamente las finanzas personales, de pareja y familiares, y convertir ese conocimiento en un **plan semanal** que ayude a alcanzar objetivos.

**Problema que resuelve:** una familia puede tener uno o varios ingresos que llegan en periodos distintos (semanal, quincenal, mensual, irregular) y pagos que vencen en periodos también distintos (renta mensual, tarjeta cada 30 días, transporte diario, comida semanal). Hoy eso se maneja "de memoria" o en hojas de cálculo sueltas. La app unifica todo en **una sola unidad de tiempo: la semana**.

**Principios de diseño**

1. **La semana es la unidad de control.** Todo ingreso y todo compromiso se traduce a su efecto semanal.
2. **De lo general a lo particular.** Primero la foto completa (cuánto entra, cuánto se compromete, cuánto queda); después el detalle (qué se compra, qué se come).
3. **Un hogar, tres modos.** Misma estructura, distinta configuración: Individual, Pareja, Familiar.
4. **Planear antes que registrar.** El presupuesto se arma *antes* de la semana; los gastos reales se comparan contra él.
5. **Mobile first.** Captura en menos de 10 segundos, pantallas de una sola decisión, pasos cortos para lo complejo.
6. **Los módulos se alimentan entre sí.** Un préstamo en Deudas genera su pago en Gastos fijos; un ingreso extra puede proponerse a Ahorro; el monto de Alimentación sale del presupuesto semanal.

---

## 2. Modos de uso: Individual, Pareja, Familiar

Todo vive dentro de un **Hogar** (la entidad que agrupa finanzas). El modo define quién participa y cómo se reparte.

| Aspecto | Individual | Pareja | Familiar |
|---|---|---|---|
| Miembros | 1 | 2 adultos | 2+ adultos y dependientes (hijos, otros) |
| Ingresos | Propios | Cada uno los suyos + opción de "bolsa común" | Varios aportantes, con periodos distintos |
| Gastos | Propios | Personales + compartidos | Compartidos + personales por miembro + de dependientes |
| Gastos compartidos | N/A | **Cuentas de gasto independientes** (una por rubro: Alimentación, Servicios, etc.). Cada miembro decide **a qué cuenta aporta** y con cuánto; no se exige 50/50 | Igual: **cada miembro aporta a las cuentas de gasto** con lo que paga. Aportar distinto monto es normal y queda registrado |
| Transparencia | Total (solo él/ella) | **Transparencia total:** cada miembro ve todos los movimientos, tanto de cuentas individuales como compartidas | **Transparencia total** entre adultos; los roles definen quién puede registrar o editar |
| Presupuesto | Uno | Tres niveles: **Yo / Tú / Nosotros** | Niveles: **Hogar / cada adulto / cada dependiente** |
| Alimentación | Porciones de 1 persona | Porciones por persona | Porciones por persona, con edades y preferencias |

**Reglas clave**

- Un usuario puede pertenecer a más de un hogar (por ejemplo, su presupuesto individual y el familiar).
- Cada movimiento tiene un **ámbito**: `personal` o `compartido`.
- **Cada rubro de gasto es una cuenta independiente** (ver 5.0 bis). En lugar de dividir cada gasto con una regla fija, **cada miembro aporta a la cuenta que decide**. Ejemplo en Alimentación de una familia: un miembro compra la leche ($45) y otro compra el pan ($80). Los montos son distintos, pero **ambos aportaron a la cuenta "Alimentación"**; la cuenta suma $125 y muestra cuánto puso cada quien.
- Una **meta de aportación** por miembro (opcional) permite comparar lo aportado contra lo esperado, sin obligar a que sea igual.
- Un dependiente (hijo) no tiene login; es un perfil que acumula gastos y porciones de comida.
- Cambiar de modo (Individual → Pareja → Familiar) no debe perder historial.

---

## 3. Mapa general del sistema

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │                           HOGAR / PERFILES                          │
 └───────────────┬─────────────────────────────────────────────────────┘
                 │
   ┌─────────────▼─────────────┐
   │ 1. INGRESOS               │  cuánto entra y cuándo
   └─────────────┬─────────────┘
                 │ ingreso semanal equivalente
   ┌─────────────▼─────────────┐   ┌────────────────────┐
   │ 2. GASTOS (fijos/variables)│◄──│ 3. DEUDAS          │  pagos obligatorios
   └─────────────┬─────────────┘   └────────────────────┘
                 │
   ┌─────────────▼─────────────┐   ┌────────────────────┐
   │ 6. PRESUPUESTO SEMANAL    │◄──│ 4. INVERSIÓN       │  aportaciones planeadas
   │    (motor de la app)      │◄──│ 5. AHORRO          │
   └─────────────┬─────────────┘   └────────────────────┘
                 │ monto asignado por categoría
   ┌─────────────▼─────────────┐
   │ 8. ALIMENTACIÓN           │  monto semanal → menú → lista de compras
   └─────────────┬─────────────┘
                 │
   ┌─────────────▼─────────────┐   ┌────────────────────┐
   │ 9. SEGUIMIENTO / REPORTES │◄──│ 7. OBJETIVOS / PLAN│
   └───────────────────────────┘   └────────────────────┘
```

**Flujo de uso típico**

1. **Configurar** (una vez): hogar, miembros, ingresos, compromisos fijos, deudas, objetivos.
2. **Planear** (cada semana, ~3 min): la app propone el presupuesto semanal; el usuario ajusta.
3. **Ejecutar** (diario): registrar gastos reales; en Alimentación, seguir el menú y la lista.
4. **Revisar** (fin de semana): comparar plan vs. real, ver desviaciones y avance de objetivos.

---

## 4. Concepto central: la semana como unidad

Cada ingreso y cada pago tiene una **frecuencia**. La app calcula su **equivalente semanal** y, además, sabe **en qué semana cae el flujo real**.

| Frecuencia | Equivalente semanal | Observación |
|---|---|---|
| Semanal | monto | |
| Quincenal | monto × 24 / 52 | 24 quincenas al año |
| Catorcenal | monto × 26 / 52 (= monto ÷ 2) | 26 catorcenas al año (cada 14 días); algunos meses tienen 3 pagos |
| Mensual | monto × 12 / 52 | |
| Bimestral / trimestral / semestral | monto × (12/n) / 52 | |
| Anual | monto / 52 | |
| Diaria (ej. pasaje) | monto × días_activos_por_semana | |
| Irregular / eventual | promedio móvil o monto manual | |

Se manejan **dos vistas** de lo mismo, porque ambas son necesarias:

- **Vista devengada (equivalente semanal):** sirve para planear y comparar semanas entre sí. Ejemplo: renta de $8,000/mes ≈ $1,846/semana.
- **Vista de flujo (caja real):** sirve para no quedarse sin dinero. Ejemplo: la renta se paga completa el día 1; esa semana el flujo es negativo aunque el equivalente semanal sea moderado.

> **Regla de oro:** el presupuesto se *planea* con la vista devengada y se *valida* con la vista de flujo (calendario de entradas y salidas). Si una semana de flujo no alcanza, la app avisa y propone **reservas** (apartar un poco cada semana para el pago grande que viene).

---

## 5. Módulos

Cada módulo se describe con: **para qué existe**, **qué datos guarda**, **reglas**, **pantallas** y **qué conecta con otros módulos**.

### 5.0 Hogar y perfiles (base)

- **Para qué:** definir quién participa y cómo se reparte el dinero. Sin esto no hay modo Pareja ni Familiar.
- **Datos:** hogar (nombre, modo, moneda, día de inicio de semana), miembros (nombre, rol, edad, tipo: adulto/dependiente), cuentas de gasto del hogar (una por rubro) y metas de aportación opcionales por miembro, roles y permisos.
- **Reglas:** el día de inicio de semana es configurable (lunes por defecto); toda la app respeta esa semana.
- **Pantallas:** onboarding de 4 pasos (modo → miembros → moneda/semana → cuentas de gasto y metas de aportación opcionales), gestión de miembros.

### 5.0 bis CUENTAS, TRANSFERENCIAS Y AUDITORÍA

**Para qué:** que la app refleje **el ingreso de cada individuo** y muestre **transparencia total del movimiento del dinero**, ya sea en una cuenta compartida o individual. Permite **intercambiar dinero entre familiares** dejando todo registrado, para que al final las finanzas estén **auditadas y controladas**. Este módulo es la columna vertebral que hace confiable a todos los demás.

**Tipos de cuenta**

| Cuenta | Descripción |
|---|---|
| **Individual** | Pertenece a un miembro (su sueldo, su efectivo, su banco) |
| **Compartida** | Pertenece a la pareja o al hogar (gastos comunes) |
| **De gasto (por rubro)** | Una cuenta independiente por cada rubro del hogar (Alimentación, Servicios, Transporte, Salud…). **Los miembros aportan a ella** con lo que pagan o transfieren; ver abajo |
| **Efectivo / cartera** | Dinero físico, por miembro o del hogar |
| **Tarjeta de crédito** | Se vincula al módulo Deudas |
| **Ahorro** | Cuenta de ahorro con su método (ver 5.5) |
| **Inversión** | Seguimiento manual de aportaciones (ver 5.4) |

Cada cuenta tiene dueño(s), saldo inicial y saldo actual calculado a partir de sus movimientos. Hoy los saldos son **manuales** (la app los calcula con lo que se registra); más adelante podrán **conectarse a cuentas reales**.

**Cuentas de gasto: cada rubro es una cuenta y cada miembro decide a cuál aportar**

- En el hogar (pareja o familia) cada rubro funciona como una **cuenta independiente**: *Alimentación, Servicios, Transporte, Salud, Entretenimiento, Vestimenta, Cuidado personal* y las que el hogar cree.
- **Aportar** significa que un miembro paga un gasto de ese rubro con su dinero (o transfiere dinero a la cuenta). El movimiento queda en la cuenta del rubro y **a nombre de quien aportó**.
- **Ejemplo (Alimentación):** el miembro A compra leche por $45 y el miembro B compra pan por $80. Cada compra se registra como aportación a la cuenta *Alimentación*:

| Miembro | Compra | Aportó a Alimentación |
|---|---|---|
| A | Leche | $45 |
| B | Pan | $80 |
| **Cuenta Alimentación** | | **$125 gastados · A $45 · B $80** |

- La cuenta del rubro muestra el **total gastado**, el **presupuesto de la semana**, lo **restante** y la **aportación de cada miembro** (monto y porcentaje). Así se ve la contribución real de cada quien sin forzar una división igual.
- Cada miembro **elige a qué cuenta aportar** al registrar: no depende de una regla fija del hogar.
- Opcionalmente se define una **meta de aportación** (por ejemplo, "A aporta 40% y B 60% a Servicios"); la app solo compara lo real contra la meta y lo muestra. Si el hogar quiere equilibrar diferencias, usa una **compensación** (ver transferencias).
- Los gastos **personales** (de un miembro, solo para él o ella) van a su cuenta individual y no aparecen como aportación al hogar.
- Cada cuenta de gasto es la que **recibe el presupuesto semanal** del rubro (ver 5.6) y la que alimenta los reportes por categoría.

**Libro de movimientos (ledger).** Todo lo que pasa es un asiento con: fecha y hora, cuenta origen, cuenta destino, monto, categoría, **quién lo realizó**, **quién lo registró**, vía de captura (manual / voz / imagen / QR), evidencia (foto de ticket) y estado. Ingresos, gastos, pagos de deuda, aportaciones a ahorro y transferencias **comparten el mismo libro**.

**Transferencias entre familiares**

| Tipo | Qué pasa |
|---|---|
| **Aportación a cuenta compartida** | Un miembro pasa dinero de su cuenta a la del hogar |
| **Préstamo entre familiares** | Crea una **deuda interna** (quién debe a quién, monto, fechas de devolución). Siempre **sin interés** (ver 5.0 ter) |
| **Apoyo / regalo** | Se transfiere sin devolución; queda anotado como apoyo |
| **Reembolso** | Se compensa un gasto que alguien pagó por otro |
| **Compensación (opcional)** | Si los miembros deciden equilibrar lo aportado a una cuenta de gasto, se registra una transferencia que lo compensa. No es obligatoria: aportar montos distintos es válido |

- Flujo: el emisor **registra** la transferencia y el receptor **confirma**. **Toda transferencia y todo préstamo entre familiares se confirma siempre**, sin importar el monto y también si fue **en efectivo**. Si el receptor no puede confirmar, **el albacea puede confirmar en su nombre** (ver 5.0 ter) y queda anotado en la **bitácora**.
- Mientras no se confirme queda `pendiente` y aparece como "por confirmar" sin modificar los saldos confirmados; si hay diferencia, `en revisión`; si el receptor la rechaza, `rechazada`.
- Una transferencia interna **no es ingreso ni gasto del hogar**; solo mueve dinero entre cuentas. Así los reportes no se inflan.

**Transparencia total (regla central)**

- Todos los adultos del hogar ven **todos los movimientos**, individuales y compartidos.
- Vista **por individuo:** cuánto ingresa, cuánto gasta, cuánto aporta al hogar, cuánto debe o le deben, su saldo.
- Vista **del hogar:** suma de cuentas, movimientos compartidos y deudas internas.
- Los dependientes ven lo que el administrador del hogar defina.
- Quién puede hacer qué, el rol de **albacea** y las confirmaciones se describen en **5.0 ter**.

**Auditoría y control**

- **Los movimientos no se borran:** se **anulan** con un contraasiento, un motivo obligatorio y, cuando involucran a otra persona, su **confirmación** (ver 5.0 ter).
- **Bitácora:** registro permanente de cada acción: quién la hizo, cuándo, qué cambió (valor anterior y nuevo), el motivo y si actuó **como albacea en nombre de otro miembro**. Nadie puede editarla ni borrarla.
- **Conciliación:** el usuario declara el saldo real de una cuenta; la app lo compara con el calculado y, si hay diferencia, pide registrar un **ajuste explícito** con su motivo.
- **Cierre semanal y mensual:** cuadre de cuentas, pendientes por confirmar y deudas internas.
- **Reporte de auditoría exportable en Excel o CSV**, con periodo configurable (semana, catorcena, quincena, mes, semestre, año o rango de fechas), por miembro o por cuenta (contenido en 5.9).
- **Saldos entre miembros:** "quién debe a quién" siempre visible.

**Reglas**

```
saldo_cuenta  = saldo_inicial + Σ entradas − Σ salidas
dinero_hogar  = Σ saldo de todas las cuentas (menos lo que se debe en tarjetas)
```

**Pantallas:** lista de cuentas con saldo, detalle de cuenta con movimientos, "Transferir" (cuenta origen → destino), bandeja de pendientes por confirmar, "Quién debe a quién", conciliación, reporte de auditoría.

**Se conecta con:** todos los módulos (cada ingreso, gasto, pago o aportación afecta una cuenta).

### 5.0 bis 2 CONTABILIDAD BÁSICA Y DETALLE DE CUENTAS

**Para qué:** dar a la app una **contabilidad básica** que responda tres preguntas, siempre con los mismos números: **¿qué tengo?** (Activos), **¿qué debo?** (Pasivos) y **¿qué entra y qué sale?** (Ingresos y Egresos). Con eso se calcula el **patrimonio neto** y se comprueba que todo **cuadre**.

> **Ecuación base:** `Activos − Pasivos = Patrimonio neto`. El patrimonio neto cambia solo por el **resultado** del periodo (ingresos − gastos) y por los ajustes explícitos.

**1. Las clases de cuenta** (tu modelo: *dos tipos de egresos y un activo*)

| Clase | Pregunta que responde | Qué incluye | Cuentas de 5.0 bis |
|---|---|---|---|
| **Activos** | ¿Qué tengo? | Efectivo, bancos, **ahorro**, inversión, **por cobrar** (préstamos que hice a familiares) y **bienes** (valor estimado, 5.6 quater) | Efectivo, individual, compartida, ahorro, inversión |
| **Pasivos** | ¿Qué debo? | Tarjetas, préstamos, créditos y **deuda interna por pagar** a familiares | Tarjeta de crédito y deudas (5.3) |
| **Ingresos** | ¿Qué entra? | Salario, extras, rendimientos | Orígenes de las entradas (5.1) |
| **Egreso tipo 1: Gasto** | ¿Qué consumo? | Todo el **presupuesto**: fijos, variables y reservas | **Cuentas de gasto** por rubro |
| **Egreso tipo 2: Pago de deuda** | ¿Qué abono a lo que debo? | **Capital** pagado (baja un pasivo). Los **intereses y cargos** se anotan como **gasto financiero** | Deudas (5.3) |
| **Patrimonio neto** | ¿Cuánto valgo? | Se **calcula**: activos − pasivos | No es una cuenta que se capture |

Nota de precisión: un pago de capital de deuda **sale de la caja pero no es un gasto**: baja lo que se debe. Por eso se separa del gasto y no disminuye el patrimonio; sí lo disminuyen los **intereses y cargos**.

**2. Partida doble simplificada: de dónde sale y a dónde entra**

Cada movimiento del libro tiene **origen** y **destino** con el mismo monto. Así nada aparece ni desaparece sin explicación y las cuentas siempre cuadran. El usuario solo ve "de dónde salió" y "a dónde fue".

| Movimiento | Sale de | Entra a | Activos | Pasivos | Resultado |
|---|---|---|---|---|---|
| Sueldo | Ingreso: salario | Banco | sube | — | Ingreso + |
| Ingreso extra | Ingreso: extras | Banco o efectivo | sube | — | Ingreso + |
| Gasto con efectivo o débito | Efectivo o banco | Gasto: rubro | baja | — | Gasto + |
| Gasto con tarjeta | Tarjeta (deuda) | Gasto: rubro | — | sube | Gasto + |
| Pago de tarjeta (capital) | Banco | Tarjeta | baja | baja | — |
| Intereses y cargos | Banco | Gasto: financiero | baja | — | Gasto + |
| Aportación a ahorro o inversión | Banco | Ahorro o inversión | se mueve | — | — |
| Retiro de ahorro | Ahorro | Banco | se mueve | — | — |
| Transferencia entre cuentas propias | Cuenta A | Cuenta B | se mueve | — | — |
| Depósito de efectivo a una cuenta propia (5.0 bis 3) | Efectivo | Banco | se mueve | — | — |
| Retiro de efectivo (5.0 bis 3) | Banco | Efectivo | se mueve | — | — |
| Pago en efectivo a una tarjeta o préstamo (5.0 bis 3) | Efectivo | Tarjeta o préstamo | baja | baja | — |
| Préstamo recibido (banco) | Préstamo | Banco | sube | sube | — |
| Pago de préstamo (capital) | Banco | Préstamo | baja | baja | — |
| Préstamo a un familiar | Banco o efectivo | Por cobrar | se mueve | — | — |
| Devolución de un familiar | Por cobrar | Banco | se mueve | — | — |
| Préstamo recibido de un familiar | Deuda interna | Banco | sube | sube | — |
| Apoyo a alguien fuera del hogar | Banco | Gasto: apoyos | baja | — | Gasto + |
| Rendimiento de inversión | Ingreso: rendimientos | Inversión | sube | — | Ingreso + |
| Ajuste de conciliación | Ajuste | Cuenta | sube o baja | — | Ajuste ± |

- **Una compra con tarjeta no baja tu efectivo**: sube lo que debes; el efectivo baja cuando **pagas** la tarjeta.
- **Anulación:** el mismo movimiento con origen y destino invertidos (5.0 bis).
- **Préstamos entre miembros (sin interés):** en la **vista del hogar** se cancelan (lo que A tiene por cobrar es lo que B debe); en la **vista individual** cada uno ve lo suyo.
- **Aportar a la cuenta de gasto de un rubro** (el ejemplo de la leche y el pan) es un **gasto**: el origen es la cuenta del miembro que pagó y el destino, el rubro.

**3. Ejemplo numérico (verificado)**

*Apertura:* Banco $5,000 · Efectivo $800 · Ahorro $10,000 · Tarjeta (deuda) $3,000 → Activos $15,800; Pasivos $3,000; **Patrimonio $12,800**.

| # | Movimiento | Efecto |
|---|---|---|
| 1 | Sueldo $9,000 al banco | Banco +9,000 · Ingreso +9,000 |
| 2 | Súper $620 en efectivo | Efectivo −620 · Gasto (Alimentación) +620 |
| 3 | Ropa $400 con tarjeta | Tarjeta +400 · Gasto (Vestimenta) +400 |
| 4 | Pago de tarjeta $1,200 desde el banco: **capital $1,100 e intereses $100** | Banco −1,200 · Tarjeta −1,100 · Gasto financiero +100 |
| 5 | Aportación al ahorro $1,500 desde el banco | Banco −1,500 · Ahorro +1,500 |

*Cierre:* Banco **$11,300** · Efectivo **$180** · Ahorro **$11,500** · Tarjeta (deuda) **$2,300**.

| Verificación | Cálculo | Resultado |
|---|---|---|
| Activos | 11,300 + 180 + 11,500 | **$22,980** |
| Pasivos | | **$2,300** |
| Patrimonio al cierre | 22,980 − 2,300 | **$20,680** |
| Resultado del periodo | Ingresos 9,000 − Gastos (620 + 400 + 100) | **$7,880** |
| Cuadre | 12,800 + 7,880 | **$20,680** ✔ |

Si el cuadre falla, la app lo marca como **"descuadre"** y pide revisar o registrar un ajuste (punto 6).

**4. Las tres vistas contables**

| Vista | Qué muestra | Cómo se arma |
|---|---|---|
| **Estado de resultados** | Ingresos − Gastos (con **gasto financiero** aparte) = resultado, por periodo | Movimientos con origen o destino de ingreso o gasto |
| **Balance** | Activos, pasivos y patrimonio a una fecha | Saldos de las cuentas |
| **Flujo de efectivo** | Entradas y salidas de dinero por semana, con saldo proyectado | Movimientos y ocurrencias futuras (5.6 bis) |

Se pueden ver **por miembro** o **del hogar** (con los préstamos y transferencias entre miembros cancelados), y por semana, catorcena, quincena o mes. El balance de cada cierre se guarda como **foto** para ver la **tendencia del patrimonio**.

**5. Ciclo de vida y reglas de una cuenta**

| Tema | Regla |
|---|---|
| Creación | Nombre, **clase**, tipo (5.0 bis), dueño(s), saldo inicial **con fecha** y visibilidad. El saldo inicial es un movimiento de apertura (no se edita) |
| Estados | `activa` → `congelada` (no admite movimientos nuevos, sigue visible) → `cerrada` (saldo en cero) |
| Borrado | **No se borran** cuentas con movimientos; se **cierran** o se **archivan**. Sin movimientos sí se pueden eliminar (como las categorías, 5.2) |
| Saldo de efectivo o banco negativo | La app lo **permite pero avisa** ("revisa la captura o registra el ingreso faltante") |
| Tarjetas | El saldo es **deuda** y se muestra como pasivo; datos de 5.3: límite, corte, fecha límite y pago mínimo. Crédito disponible = límite − saldo |
| Compartidas | Varios dueños; todos ven todo (transparencia total); aportes por miembro (5.0 bis) |
| **Cuenta "Por clasificar"** | Para capturar rápido sin categoría; la app recuerda clasificar y **no entra a los reportes por rubro** hasta clasificarla |
| **Cuenta "Ajustes"** | Recibe las diferencias de conciliación; **siempre visible** en la auditoría |
| Moneda | **MXN** (otras monedas, fuera de alcance inicial) |

**6. Conciliación paso a paso**

1. El usuario elige la cuenta y escribe el **saldo real** (del banco, de la cartera o del estado de cuenta).
2. La app compara con el **saldo calculado** y muestra la **diferencia**.
3. Si hay diferencia, ayuda a encontrarla: **movimientos sin confirmar**, posibles duplicados, importes parecidos o capturas faltantes.
4. Si no se encuentra, se registra un **ajuste** con motivo obligatorio en la cuenta **Ajustes**; requiere confirmación si afecta una cuenta de otra persona (5.0 ter).
5. Queda en la bitácora y en el reporte de auditoría.

*Para conciliar **renglón por renglón** con el estado de cuenta, ver 5.0 bis 3.*

Para el **efectivo**, la app propone conciliar al **cierre semanal** (la diferencia suele ser gasto hormiga sin capturar).

**7. Saldos que muestra la app**

| Saldo | Qué incluye |
|---|---|
| **Saldo confirmado** | Solo movimientos confirmados |
| **Saldo con pendientes** | Suma lo `pendiente` de confirmar (transferencias y préstamos); se muestra con una marca |
| **Disponible del hogar** | Σ saldos de activos **líquidos** (efectivo y bancos), sin ahorro ni inversión |
| **Patrimonio neto** | Activos − pasivos |

**8. Pantallas:** lista de cuentas agrupada por **Activos / Pasivos**; detalle de cuenta con movimientos y saldo; **"Balance"** y **"Estado de resultados"** con selector de periodo (semana, catorcena, quincena, mes); **"Transferir"** con origen → destino; bandeja de pendientes por confirmar; **conciliación**; alerta de **descuadre**; tendencia del patrimonio.

**9. Casos límite**

1. **Gasto con tarjeta de un miembro que lo paga otro:** la tarjeta es de uno; el pago lo hace el otro; se registra como **transferencia o aporte** (con confirmación) y luego el pago de capital.
2. **Reembolso de un gasto ya registrado:** se anula parcialmente el gasto (contraasiento por el monto) o se registra como **reembolso** (5.0 bis).
3. **Pago parcial de varias compras con tarjeta:** el pago va a la tarjeta, no a compras individuales.
4. **Intereses que la app no conoce:** el usuario los captura del estado de cuenta; si no los captura, la conciliación mostrará la diferencia.
5. **Cuenta compartida con retiro de un miembro:** se **congela**, se reparte el saldo con transferencias confirmadas y se **cierra**.
6. **Transferencia rechazada:** el dinero **vuelve** al origen con un contraasiento y queda en la bitácora.
7. **Préstamo a un familiar que luego se perdona:** se registra como **apoyo** (gasto) con motivo y confirmación.

**10. Pruebas de aceptación**

1. Con el ejemplo del punto 3: **Activos $22,980; Pasivos $2,300; Patrimonio $20,680; Resultado $7,880**, y el cuadre da **cero** de diferencia.
2. Una compra con tarjeta **sube el pasivo** y no baja el efectivo; el pago de capital baja ambos.
3. Una aportación a ahorro **no cambia** el patrimonio.
4. En la vista del hogar, un préstamo entre miembros **no cambia** los totales; en la individual, sí.
5. Una conciliación con diferencia crea un movimiento en **Ajustes**, con motivo y bitácora, y aparece en la auditoría.
6. No se puede **borrar** una cuenta con movimientos; sí **cerrarla** con saldo cero.
7. Una transferencia `pendiente` no altera el **saldo confirmado** pero sí el **saldo con pendientes**.
8. El balance de un cierre guardado **no cambia** aunque se corrijan movimientos después (la corrección genera un asiento nuevo).

### 5.0 bis 3 ESTADOS DE CUENTA, DEPÓSITOS Y MOVIMIENTO DE EFECTIVO (a detalle)

**Para qué:** que la persona vea **de dónde viene el efectivo, a qué cuenta propia lo llevó (por ejemplo, Banamex o BBVA) y a dónde se movió después**, y que lo que dice el banco **coincida con lo que dice la app**. Se agregó el 19/oct/2026 porque la revisión mostró un hueco.

**Lo que el documento ya cubría y lo que faltaba**

| Tema | Antes | Hueco |
|---|---|---|
| **Estados de cuenta de tarjetas y créditos** | Sí (5.3): calibran el estimador de tasa e intereses; captura manual, foto con lectura en el teléfono o archivo | — |
| **Conciliación de una cuenta** | Sí (5.0 bis 2, punto 6): se escribe el **saldo real** y la app busca la diferencia | Solo compara el **saldo final**, no cada renglón |
| **Estados de cuenta de débito y ahorro** (Banamex, BBVA, Nu, Mercado Pago, Stori) | No | Faltaba leer los **movimientos** y cotejarlos |
| **Depósito y retiro de efectivo entre mis cuentas** | Solo "transferencia entre cuentas propias" | Faltaban el **origen del efectivo**, el canal, la comisión y la ruta |

**1. Operaciones con efectivo**

| Operación | Sale de | Entra a | Qué pide la app |
|---|---|---|---|
| **Depósito de efectivo** a mi cuenta | Efectivo | Banco (Banamex, BBVA…) | Monto, cuenta destino, canal, **origen del efectivo**, propósito (opcional), foto de la ficha (opcional) |
| **Retiro de efectivo** | Banco | Efectivo | Monto, cuenta, canal |
| **Pago en efectivo a una tarjeta o préstamo** | Efectivo | Tarjeta o préstamo | Fecha de operación y, después, **fecha de aplicación** |
| **Efectivo recibido y no registrado antes** | Ingreso | Efectivo | Tipo de ingreso (se vuelve ingreso con su fecha, 5.1 bis) |

Los **depósitos y retiros son traslados de activo a activo** (5.0 bis 2): no son ingreso ni gasto. Lo que **sí** es gasto financiero es la **comisión**, si el banco o el canal la cobra (se captura o se detecta en el estado de cuenta).

**2. Origen del efectivo (obligatorio al depositar)**

Un depósito en efectivo, en el estado de cuenta, **no dice de dónde venía el dinero**. La app lo pregunta con una lista corta:

| Origen | Qué hace |
|---|---|
| **Retiro previo del banco** | Enlaza con el retiro y no cuenta nada nuevo |
| **Sueldo, venta, propina u otro ingreso en efectivo** | Si ya estaba registrado, solo lo mueve; si no, **crea el ingreso** (5.1 bis) |
| **Cobro de un préstamo que hice** | Baja la cuenta por cobrar (5.1 bis, punto 7) |
| **Regalo o apoyo** | Crea ingreso extra |
| **Venta de un bien** | Movimiento de activo (5.1 bis) |
| **Sobrante de gastos** | Devuelve el efectivo sobrante a la cuenta |
| **Otro** | Descripción libre |

**Regla de no duplicar:** la app compara el depósito con el **saldo de efectivo registrado**. Si el depósito es **mayor** que el efectivo que la app conocía, pregunta **de dónde salió la diferencia** y la registra como ingreso o como ajuste; **nunca** deja el efectivo en negativo en silencio.

**Ejemplo:** efectivo registrado **$1,800**; depósito de **$3,000** en BBVA. La app pregunta por los **$1,200** que faltan. La persona responde "ventas en efectivo sin registrar": se crea un **ingreso extra de $1,200**, el efectivo queda en $0 y BBVA sube $3,000. Los $1,200 siguen la cascada de extras (5.1 bis, punto 4).

**3. Ruta del dinero (adónde se movió)**

El dinero no tiene "etiqueta" por peso; lo que la app sabe es **qué movimientos enlazó la persona**. Por eso ofrece dos vistas **honestas**:

1. **Cadena de movimientos:** para cada depósito muestra su **origen declarado** y, a partir de la cuenta, **las salidas posteriores** en orden (pagos de tarjeta, renta, súper…). Es una **lectura cronológica**, no una trazabilidad exacta por peso, y así se rotula.
2. **Propósito del depósito (opcional):** al depositar, la persona puede decir **"para pagar la Costco"** o **"para la renta"**. La app compara después **lo planeado contra lo usado** ("depositaste $3,000 para la Costco; se pagaron $2,800 y quedan $200 en la cuenta").

**Resumen por banco** (por periodo): efectivo depositado, retirado, comisiones y **a dónde salió el dinero** de esa cuenta (deudas, gastos, ahorro). Sirve para ver cuánto efectivo se movió por **Banamex** y cuánto por **BBVA**.

Sugerencia opcional: si la persona suele depositar para **pagar una tarjeta del mismo banco** (Costco y Joy en Banamex, Azul en BBVA), la app ofrece **atajos de ese par**. Tiempos y comisiones de cada canal **se verifican con el banco**; la app no los supone.

**4. Fecha de operación y fecha de aplicación**

Cada depósito y cada pago a una deuda llevan **dos fechas**:

| Fecha | Qué es |
|---|---|
| **Operación** | Cuando la persona lo hizo |
| **Aplicación** | Cuando el banco lo **reflejó** (se toma del estado de cuenta o la persona la captura) |

Importa en las **tarjetas** (5.3): si el pago se hizo **antes de la fecha límite pero se aplicó después**, puede generar intereses. La app **avisa** cuando la aplicación es posterior a la fecha límite y se lo muestra al **estimador de intereses**.

**5. Estados de cuenta de débito y ahorro**

**Cómo entran** (igual que en 5.3, **sin entrar a la banca móvil ni pedir contraseñas**):

| Vía | Costo | Etapa |
|---|---|---|
| **1. Captura manual** de saldo inicial, final y totales | Cero | Primera |
| **2. Foto o PDF** leído en el teléfono, con pantalla de confirmación | Cero | Segunda |
| **3. Archivo descargado por la persona** (PDF, CSV o Excel, según lo que ofrezca cada banco) | Cero | Tercera |

Qué formatos ofrecen **Banamex y BBVA** y cómo vienen sus conceptos **no está verificado**; se define con los **estados de cuenta de ejemplo** (pendiente 9 de 12.2).

**Conciliación renglón por renglón.** La app lee cada línea (fecha, concepto, cargo, abono y saldo) y la **empareja** con los movimientos de la app por **monto**, **fecha** (con una tolerancia de unos días, editable) y **concepto**:

| Resultado | Qué significa | Qué ofrece la app |
|---|---|---|
| **Conciliado** | Hay un movimiento igual | Marcarlo como verificado |
| **Falta en la app** | El banco lo registró y la app no | **Crear el movimiento** con una categoría sugerida |
| **Falta en el banco** | La app lo tiene y el banco aún no | Dejarlo **pendiente** (puede no haberse aplicado) |
| **Monto distinto** | Existe pero cambia el importe | Corregir con anulación y contraasiento |
| **Posible duplicado** | Dos movimientos parecidos | Revisar |
| **Depósito en efectivo sin origen** | Abono que parece depósito de efectivo | Preguntar el **origen** (punto 2) |

La app **aprende**: si la persona clasifica "suscripción" de un renglón, la próxima vez propone la misma categoría.

**Ejemplo con un estado de BBVA de una semana** (valores ilustrativos). Saldo inicial **$1,000**:

| Fecha | Concepto | Importe | Resultado |
|---|---|---|---|
| Lun 19 oct | Depósito en efectivo | +$3,000.00 | Conciliado con el depósito registrado |
| Mar 20 oct | Compra con débito | −$620.00 | Conciliado con el gasto del súper |
| Mié 21 oct | Pago a tarjeta | −$1,500.00 | Conciliado con el pago a la deuda |
| Jue 22 oct | Cargo de suscripción | −$89.00 | **Falta en la app** → se crea el gasto |

Saldo final del estado: **$1,791.00**. Antes de conciliar, la app calculaba **$1,880.00** (faltaba el cargo de $89); al crear el movimiento, **cuadra** con el banco.

**Duplicados y privacidad:**

- Importar **el mismo estado dos veces** se detecta (periodo, cuenta y huella del archivo) y no duplica movimientos.
- Los estados de cuenta son **datos sensibles**: se leen **en el teléfono** y **nunca se envían a servicios de IA** (6.13).
- Por defecto **no se guarda el archivo original**: solo los renglones y su estado de conciliación (opcionalmente, el archivo, si la persona lo pide).

**6. Depósitos por identificar**

Un abono sin origen, o un depósito en efectivo sin explicar, queda en una **bandeja "Por identificar"**, **visible en la auditoría** (5.9). La revisión semanal de 5.9 bis agrega el paso **"identificar depósitos"**. Esto sirve también como **registro propio** del origen de tu dinero.

**7. Comisiones y cargos bancarios**

Las comisiones por **depósito, retiro, cajero o transferencia** (si existen) se registran como **gasto financiero** (5.0 bis 2). Un reporte opcional las suma **por banco y por canal** para ver **cuánto cuesta mover el efectivo**.

**8. Voz y captura rápida**

Se agregan verbos a la captura por voz (5.2): **"deposité tres mil en BBVA"**, **"retiré quinientos de Banamex"**, **"pagué la Costco en efectivo"**. Siempre con tarjeta de confirmación y pidiendo el **origen** si falta.

**9. Pantallas:** **Depositar efectivo** (monto, cuenta, origen, propósito, foto), **Ruta del dinero** (cadena y propósito contra uso), **Importar estado de cuenta** (3 pasos), **Conciliar renglones** (deslizar para aceptar o crear), **Por identificar** y **Resumen por banco**.

**10. Datos nuevos:** `Movimiento` con tipo `deposito_efectivo` o `retiro_efectivo` y los campos `canal`, `origen_efectivo`, `proposito_id`, `fecha_operacion`, `fecha_aplicacion` y `evidencia`; `EstadoCuentaImportado` (cuenta, periodo, saldo inicial y final, huella, vía de captura); `RenglonEstadoCuenta` (estado, fechas, concepto, cargo, abono, saldo, movimiento_id, resultado) y `ReglaConcepto` (patrón, categoría o tipo, aprendida o fija).

**11. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| EC1 | Depósito de $3,000 con $1,800 de efectivo registrado | Pregunta por los **$1,200**; con "ventas" crea un ingreso extra de $1,200 y el efectivo queda en $0 |
| EC2 | Depósito con origen "retiro previo" | Se enlaza con el retiro y no crea ingreso |
| EC3 | Depósito con propósito "pagar la Costco" por $3,000 y pagos por $2,800 | Muestra **$2,800 usados** y **$200** en la cuenta |
| EC4 | Estado de BBVA del ejemplo | Tres renglones conciliados, uno **falta en la app**; el saldo final cuadra en **$1,791.00** |
| EC5 | Importar el mismo estado dos veces | Avisa que ya se importó y no duplica |
| EC6 | Pago a tarjeta hecho el viernes (fecha límite) y aplicado el lunes | Aviso de **aplicación posterior a la fecha límite** |
| EC7 | Abono en efectivo sin origen | Pasa a **Por identificar** y se ve en la auditoría |
| EC8 | Comisión de depósito en el estado de cuenta | Se crea un **gasto financiero** y entra al reporte de comisiones |
| EC9 | Dictar "deposité tres mil en BBVA" | Tarjeta de confirmación con monto, cuenta y pregunta del origen |
| EC10 | Estado de cuenta leído por foto | Nada se guarda hasta confirmar; el archivo no se envía a ninguna IA |

**Lo que no se asume:** cómo nombra cada banco sus conceptos, los formatos de archivo que ofrece, ni los tiempos o comisiones de cada canal de depósito. Se confirman con tus estados de cuenta de Banamex y BBVA.

### 5.0 ter ROLES, PERMISOS, ALBACEA Y CONFIRMACIONES

**Para qué:** definir quién puede hacer qué y asegurar que **todo movimiento que involucra a otra persona quede confirmado y anotado en la bitácora**, incluso cuando alguien no puede confirmar por sí mismo.

**Roles del hogar**

| Rol | Descripción |
|---|---|
| **Administrador** | Quien crea el hogar; configura miembros, cuentas y reglas |
| **Albacea** | Un miembro designado por el hogar para confirmar y gestionar por quien no pueda (ver abajo) |
| **Miembro adulto** | Registra y consulta; maneja sus propias cuentas |
| **Dependiente** | Perfil sin acceso propio (por ejemplo, hijos); ve lo que defina el administrador |
| **Solo lectura** | Consulta; no registra |

El administrador y el albacea pueden ser la misma persona o dos distintas.

**El albacea**

- **Se elige a un miembro como albacea** al configurar el hogar y se puede cambiar después. Opcionalmente se nombra un **albacea suplente**, para cuando el albacea sea parte del movimiento o no esté disponible.
- Sirve cuando un miembro **no puede confirmar o gestionar por sí mismo** (por ejemplo, una persona en cuidados de largo plazo, un menor o quien no usa teléfono) y para que el hogar no quede bloqueado esperando una confirmación.
- **Puede:** confirmar transferencias y préstamos, confirmar anulaciones y ajustes, y registrar movimientos de los miembros que no pueden hacerlo.
- **Nota:** en el lenguaje legal mexicano, "albacea" es quien ejecuta una sucesión. En la app es **solo un rol funcional del hogar**, sin efecto legal; no sustituye poderes, tutela ni testamentos.

**Salvaguardas propuestas (por validar)**

1. Cada acción del albacea queda en la bitácora como *"confirmado por [albacea] en nombre de [miembro]"*, con **motivo obligatorio**.
2. Se **notifica** al miembro afectado cuando es posible, y todos los adultos lo ven (transparencia total).
3. El albacea **no puede ser la única confirmación de un movimiento en el que él mismo es parte**: confirma la contraparte o el suplente.
4. Cambiar de albacea queda en la bitácora y requiere la confirmación de otro adulto.
5. El albacea no puede editar ni borrar la bitácora.

**Qué requiere confirmación**

| Movimiento | Quién confirma | Si no está disponible |
|---|---|---|
| **Transferencia entre miembros** (aportación, préstamo, apoyo, reembolso, compensación), **siempre**, sin importar el monto y también en efectivo | El receptor | El albacea, en nombre del receptor |
| **Préstamo entre familiares**, **siempre**, también en efectivo | Quien recibe (acepta monto y condiciones) | El albacea |
| **Anulación o ajuste** de un movimiento confirmado que involucra a otra persona (transferencias, aportaciones a cuentas de gasto o compartidas, deudas internas) | La persona o personas afectadas | El albacea |
| **Anulación de un movimiento puramente personal** (cuenta individual, sin terceros) | No requiere; el autor anula con motivo y queda visible para todos | — |
| **Conciliación con diferencia** en una cuenta compartida | Otro adulto | El albacea |

**Estados:** `pendiente` → `confirmada` / `rechazada` / `en revisión` → `anulada`. Un movimiento pendiente no cambia los saldos confirmados.

**Préstamos entre familiares: siempre sin interés.** La deuda interna es solo el **capital pendiente**: no se calculan intereses. Se paga por abonos o en una fecha acordada, el saldo baja con cada abono y **cada pago se confirma** igual que una transferencia (por el receptor o, en su nombre, por el albacea).

**Matriz de permisos (propuesta)**

| Acción | Administrador | Albacea | Adulto | Dependiente | Solo lectura |
|---|---|---|---|---|---|
| Ver los movimientos del hogar (transparencia total) | ✔ | ✔ | ✔ | Lo que defina el administrador | ✔ |
| Registrar en sus propias cuentas | ✔ | ✔ | ✔ | ✖ | ✖ |
| Registrar por un miembro que no puede hacerlo | ✖ | ✔ | ✖ | ✖ | ✖ |
| Confirmar transferencias dirigidas a él | ✔ | ✔ | ✔ | ✖ | ✖ |
| Confirmar en nombre de otro miembro | ✖ | ✔ | ✖ | ✖ | ✖ |
| Invitar o retirar miembros y crear cuentas del hogar | ✔ | ✖ | ✖ | ✖ | ✖ |
| Designar o cambiar al albacea | ✔ (con confirmación de otro adulto) | ✖ | ✖ | ✖ | ✖ |
| Exportar el reporte de auditoría | ✔ | ✔ | ✔ | ✖ | ✔ |

Si el administrador es también el albacea, tiene ambas columnas.

**Pantallas:** configuración de roles y albacea, **bandeja de confirmaciones pendientes** (con el botón "Confirmar como albacea"), historial de bitácora por movimiento.

**Se conecta con:** Cuentas y transferencias (5.0 bis), reporte de auditoría (5.9) y Cuidados de largo plazo (5.2).

### 5.1 INGRESOS

**Para qué:** saber cuánto entra, de quién, con qué certeza y en qué fecha. Es la base de todo el presupuesto: sin ingresos confiables no hay plan.

**Tipos** (los tres originales, más precisiones)

| Tipo | Naturaleza | Ejemplos |
|---|---|---|
| **Salario** | Recurrente, predecible | Sueldo semanal/quincenal/mensual, honorarios fijos, pensión |
| **Préstamos recibidos** | Entrada de dinero que **genera una deuda** | Préstamo bancario, préstamo familiar |
| **Extras** | Eventual, variable | Bono, aguinaldo, venta, trabajo extra, reembolso, regalo |

> **Punto crítico:** un préstamo recibido **no es ingreso real**: es una entrada de caja que crea una obligación. La app lo registra en Ingresos (porque entra dinero) pero lo marca como `ingreso_financiado` y **crea automáticamente la deuda** en el módulo Deudas. En los reportes se separa "ingreso propio" de "dinero prestado" para no inflar la capacidad de gasto.

**Datos por ingreso:** nombre, tipo, miembro que lo recibe, **cuenta destino** (individual o compartida), monto, moneda, frecuencia, fecha del próximo pago, **certeza** (`segura` / `probable` / `incierta`), ¿es neto o bruto?, ¿es compartido con el hogar?, fecha de fin (si aplica).

**Reglas**

- Un hogar puede tener **N ingresos con calendarios distintos**; la app los consolida en el calendario semanal.
- Los ingresos `inciertos` **no se cuentan** en el presupuesto base; se muestran como "ingreso potencial".
- Si un ingreso se retrasa o no llega, se marca `pendiente` y el presupuesto se recalcula.
- Los extras proponen una **distribución** que sigue la cascada de 5.6 bis y 5.1 bis (punto 4), editable.

**Forma de ingreso y día de pago (la configura cada miembro)**

| Forma | Qué configura el miembro | Fechas de pago |
|---|---|---|
| **Semanal** | Día de la semana | Cada semana en ese día |
| **Catorcenal** | Fecha ancla | Cada 14 días desde la ancla |
| **Quincenal** | Los dos días del mes (por defecto 15 y último) | Dos veces al mes |
| **Mensual** | Día del mes o "último día" | Una vez al mes |
| **Extra** | Ninguno | **Cualquier día**; se registra con su fecha real |

- **Regla de fin de semana y festivos:** si la fecha de pago cae en **sábado, domingo o día festivo, el pago pasa al siguiente día hábil** (el lunes, si es fin de semana). Es configurable por ingreso (alternativas: día hábil anterior o sin cambio). Los festivos salen de un **calendario de días inhábiles editable**: **solo los festivos oficiales de México** (decisión del 15/oct/2026). Se precarga por año y el usuario lo **revisa**, porque cambia cada año (verificar las fuentes oficiales al construirlo).
- **Periodo de visualización:** cada miembro elige ver sus datos por **semana, catorcena, quincena o mes**. El hogar mantiene además la vista semanal base. Cómo se calcula cada vista está en 5.6 bis.
- Un miembro puede tener **varios ingresos con formas distintas** (por ejemplo, sueldo quincenal y comisión mensual).
- Los **extras** se cuentan en la semana en que llegan; aumentan el remanente de esa semana y proponen su distribución (5.6 bis, punto 7).

**Pantallas:** lista por miembro, alta rápida de ingreso, calendario de ingresos, "ingreso semanal equivalente" por miembro y total.

**Se conecta con:** Presupuesto (techo de gasto), Deudas (préstamos), Ahorro (extras), Objetivos (capacidad).

### 5.1 bis INGRESOS A DETALLE

**Para qué:** que la app sepa **cuánto entra de verdad, cuándo y con qué seguridad**, para que el presupuesto no se arme sobre dinero que no va a llegar. Esta sección baja a detalle lo básico de 5.1: tipos, ingresos variables, extras, préstamos, reembolsos, aportación al hogar y calendario de flujo.

**1. Tipos de ingreso y cómo se tratan**

| Tipo | Ejemplos | Cómo entra al presupuesto |
|---|---|---|
| **Salario** | Sueldo semanal, catorcenal, quincenal o mensual | Equivalente semanal (sección 4); `segura` |
| **Independiente o negocio** | Honorarios, ventas, comisiones, propinas | Si es **variable**, con el método del punto 3 |
| **Prestaciones** | Aguinaldo, reparto de utilidades, fondo de ahorro | **Ingreso con fecha** (punto 4); no se prorratea por defecto |
| **Pensión y apoyos** | Pensión, becas, apoyos, ayuda familiar recurrente | `segura` o `probable`, según la persona |
| **Vales y monederos** | Vales de despensa | **Medio restringido** (punto 6) |
| **Extras** | Bono, venta de un objeto, trabajo extra, devolución de impuestos, regalo | Se cuentan **en la semana en que llegan** (punto 4) |
| **Préstamos recibidos** | Préstamo bancario o familiar | **No son ingreso**: crean deuda (punto 7) |

**Lo que no es ingreso** y la app no debe contar como tal:

| Entrada de dinero | Por qué no es ingreso | Cómo se registra |
|---|---|---|
| **Reembolso** de un gasto (trabajo, seguro médico) | Es el regreso de un gasto ya hecho | **Baja el gasto** de esa categoría; no sube el ingreso |
| **Transferencia de otro miembro** del hogar | Es dinero que ya era del hogar | Transferencia confirmada (5.0 bis) |
| **Cobro de un préstamo que el hogar hizo** | Regresa un activo | Baja la cuenta por cobrar (punto 7) |
| **Venta de un bien** (auto, equipo) | Convierte un activo en efectivo | Movimiento de activo; la ganancia o pérdida se anota aparte |

**2. Bruto, neto y descuentos de nómina**

- La app trabaja **con el neto**: lo que **de verdad llega a la cuenta**.
- Si la persona quiere, captura el **recibo de nómina** (bruto, descuentos y neto) para ver a dónde se va; es **opcional**.
- **Descuentos que son deuda** (por ejemplo, un crédito de vivienda o de consumo que se descuenta por nómina): se registran como **deuda con "pago por nómina"** (5.3). La cuota **no vuelve a pagarse** en la cascada; sí cuenta como **carga de deuda** y su saldo baja con cada recibo.
- Si el neto **cambia** (aumento, descuento nuevo), se crea una **nueva vigencia** del ingreso; el historial anterior no se toca.

**3. Ingresos variables (el caso difícil)**

**Problema:** un ingreso que sube y baja no se puede prorratear como un sueldo. Se ofrecen **dos métodos** y la app **recomienda uno** según el peso del ingreso variable.

| Método | Cómo funciona | Cuándo conviene |
|---|---|---|
| **A. Base prudente** *(por defecto)* | La **base semanal** = promedio de las **últimas 12 semanas × 80 %** (factor de prudencia editable). Lo que llega por encima de la base se trata como **extra** | El ingreso variable es **menos de 30 %** del total del hogar |
| **B. Nivelación** | El ingreso variable entra a una **bolsa de nivelación** y el presupuesto recibe **un "sueldo" semanal fijo** igual a la base | El ingreso variable es **30 % o más** del total, o es el principal |

**Ejemplo del método A** (12 semanas de ingreso variable, valores ilustrativos): $900, $0, $1,200, $600, $0, $1,500, $800, $300, $1,100, $0, $1,000 y $700. Suman **$8,100**; el promedio es **$675**; la **base** es **$675 × 80 % = $540** por semana.

- Semana con **$1,200**: se cuentan $540 de base y **$660 como extra** que sigue la cascada del punto 4.
- Semana con **$0**: faltan $540 de lo esperado, y se absorbe con las reglas de sobregasto de 5.6 bis (remanente, abono planeado y, al final, déficit).

**Ejemplo del método B** con la **misma base de $540**, una bolsa inicial de **$1,000** y una **meta de la bolsa de 4 semanas de base ($2,160)**:

| Semana | Ingreso real | "Sueldo" pagado al presupuesto | Saldo de la bolsa |
|---|---|---|---|
| 1 | $900 | $540 | $1,360 |
| 2 | $0 | $540 | $820 |
| 3 | $1,200 | $540 | $1,480 |
| 4 | $600 | $540 | $1,540 |
| 5 | $0 | $540 | $1,000 |
| 6 | $1,500 | $540 | $1,960 |
| 7 | $800 | $540 | $2,220 → **$60 sobre la meta pasan a extra**, queda $2,160 |
| 8 | $300 | $540 | $1,920 |

La bolsa **nunca baja de $820**, así que el presupuesto recibe el mismo monto cada semana. Si la bolsa **cae por debajo de una semana de base**, la app **baja el "sueldo"** de la semana siguiente y lo avisa (con el mismo orden de protección de gastos de 5.6 bis).

**Regla:** ningún método cuenta como ingreso lo que **todavía no llegó**; la base es una **estimación prudente** y se recalcula cada semana.

**4. Extras, aguinaldo y otros ingresos con fecha**

- **Los extras siguen la cascada de 5.6 bis, punto 7**, no un reparto fijo:
  1. Completar los **sobres de previsión** que no alcanzan (5.6 ter).
  2. **Deuda con costo**, por mayor tasa efectiva (5.3 ter).
  3. **Préstamos familiares.**
  4. **Ahorro** por el orden de 5.5 bis (cuando ya no hay deuda).
  5. Una **parte libre** (premio o gasto personal), configurable. **Por defecto 0 %**, en línea con tu decisión de pagar primero la deuda.
- **Aguinaldo, reparto de utilidades y fondo de ahorro:** se capturan con su **fecha esperada** y su **monto estimado**, y la app los marca `probable` hasta que llegan. **La app no calcula lo que te corresponde:** tú capturas el monto; **verifica las fechas y las reglas con tu empleador o con la ley**. Mientras no llegan, **no se cuentan** en el presupuesto.
- Antes de que llegue, el simulador puede mostrar el **efecto esperado** ("con tu aguinaldo estimado, la tarjeta A queda en cero en la semana X"), rotulado como **proyección**.
- **Un mes con tres catorcenas** (o con 5 semanas): ya está dentro del equivalente semanal, así que la app **no lo trata como extra** y lo explica ("el tercer pago ya estaba en tu base").

**5. Ingreso esperado, recibido y retrasado**

Cada ingreso genera una `Ocurrencia` (7) con estos estados:

| Estado | Qué significa | Qué hace la app |
|---|---|---|
| **Esperado** | Aún no llega su fecha | Cuenta en el calendario de flujo |
| **Recibido** | Llegó completo | Se confirma con un toque o por el depósito capturado |
| **Parcial** | Llegó menos de lo esperado | Pregunta el motivo y recalcula con lo recibido |
| **Retrasado** | Pasó la fecha sin llegar | Alerta al siguiente día hábil; la semana pasa a `pendiente de ingreso` (5.6 bis) |
| **No llegará** | La persona lo declara perdido | Se cierra y se recalcula el plan |

- La regla de **fin de semana y festivo al siguiente día hábil** (5.1) aplica a todos los ingresos.
- Si el depósito **no coincide** con lo esperado, la app pregunta ("¿el neto cambió o faltó algo?") y ofrece crear una **nueva vigencia**.
- **Evidencia opcional:** foto del recibo de nómina o del comprobante, ligada al movimiento.

**6. Vales de despensa y medios restringidos**

Los vales y otros monederos **solo sirven para ciertos gastos** y ciertos comercios. En la app son una **cuenta de tipo "monedero restringido"** (5.0 bis) con su **categoría permitida** (por ejemplo, Alimentación).

- **Suman al monto semanal de comida** del asistente de menús (6.5 bis), pero la lista de compras **separa lo que se puede pagar con vales** y marca los comercios que los aceptan (**los captura la persona**; la app no asume cuáles son).
- **No se pueden usar** para pagar deudas, previsión ni gastos fuera de su categoría; la app lo avisa.
- Si **venció o sobró** saldo, lo muestra como "por vencer" con alerta.

**7. Préstamos recibidos y otorgados**

**Préstamo recibido** (5.1, punto crítico): se registra en Ingresos como `ingreso_financiado` y **crea la deuda** (5.3). Datos extra:

| Dato | Para qué |
|---|---|
| **Destino del dinero** (pagar deuda, comprar algo, gasto corriente) | Aviso si se usa para **gasto corriente**: es una señal de riesgo |
| **Acreedor y condiciones** | Con familiares, **siempre sin interés** (5.0 ter) |
| **Cuota y fecha** | Entra a la deuda y a la cascada |

**Préstamo otorgado por el hogar** (le prestas a alguien): es un **activo** (**cuenta por cobrar**) con su fecha acordada; **no es gasto**. Cuando lo devuelven, **baja la cuenta por cobrar**; no es ingreso. Se muestra aparte para no contarlo como dinero disponible.

**8. Pareja y familia: aportación al hogar**

Cada miembro **ve el ingreso de todos** (transparencia total, 5.0 bis). Para financiar los gastos del hogar, cada quien elige **cómo aporta**:

| Modo | Qué hace |
|---|---|
| **Todo al hogar** | Todo su ingreso va a la cuenta compartida |
| **Porcentaje** | Un porcentaje de cada ingreso |
| **Monto fijo semanal** | Una cantidad por semana |
| **Proporcional al ingreso** | Cada quien aporta su parte del gasto total según lo que gana |

**Ejemplo del modo proporcional** con las cifras de 5.6 bis: el hogar necesita **$5,864.62** por semana (presupuesto de $5,472.31 más deuda de $392.31). La persona A gana **$4,500** y la persona B, **$2,884.62** (total $7,384.62).

| Miembro | Ingreso semanal | Parte | Aporta al hogar | Le queda |
|---|---|---|---|---|
| A | $4,500.00 | 60.94 % | **$3,573.75** | $926.25 |
| B | $2,884.62 | 39.06 % | **$2,290.87** | $593.75 |

Lo que **queda** a cada quien es **dinero personal** (seguirá visible para todos, pero lo gasta cada quien). Cada miembro puede **cambiar la cuenta de gasto** a la que contribuye (5.0 bis); el modo solo **sugiere** el monto. Los cambios de modo **se confirman entre los miembros** y quedan en la bitácora.

**9. Calendario de flujo (la vista de caja)**

La app proyecta el **saldo día por día** durante las **próximas 4 a 8 semanas**: saldo actual + ingresos **seguros** esperados − pagos programados (deuda, previsión, compromisos). Los ingresos `probables` se dibujan **aparte** (línea punteada) y **no entran en la línea base**.

**Regla prudente:** si en un mismo día hay entradas y salidas, la app **supone primero las salidas** (peor caso) y muestra también el saldo **al cierre del día**.

**Ejemplo con la regla de fin de semana** (valores ilustrativos): el saldo del jueves 29 de octubre de 2026 es **$2,600**. La quincena del **sábado 31** y la renta del **domingo 1 de noviembre** **pasan al lunes 2** (5.1).

| Día | Evento | Saldo en el peor caso | Saldo al cierre |
|---|---|---|---|
| Jue 29 oct | — | $2,600 | $2,600 |
| Vie 30 oct | Mínimo de tarjeta −$450 | $2,150 | $2,150 |
| Lun 2 nov | Renta −$3,500 y sueldo +$6,000 | **−$1,350** | **$4,650** |

La app **avisa con anticipación**: "el lunes 2 el saldo puede quedar en −$1,350 en el peor caso". Opciones: **mover la fecha de la renta** si el arrendador lo permite, **apartar** dinero desde antes, o **confirmar la hora** a la que suele llegar el sueldo. **Nunca propone usar una tarjeta con intereses** para tapar el hueco (5.3 bis).

**10. Cambios grandes de ingreso**

| Evento | Qué hace la app |
|---|---|
| **Aumento o baja** | Nueva vigencia; recalcula el plan desde la fecha |
| **Pérdida de un ingreso** | Cierra la vigencia, corre la **prueba de estrés** (5.3 ter), propone el **modo ingreso reducido** (pausar metas sin fecha, proteger gastos y mínimos de deuda) y muestra **cuántas semanas cubre el fondo** (5.5 bis) |
| **Ingreso nuevo** | Se agrega con certeza `probable` hasta que llegue el primer pago |
| **Ingreso que termina** | Fecha de fin; la alerta avisa **4 semanas antes** |

**11. Pantallas:** lista por miembro con equivalente semanal, alta rápida (con voz: "me pagaron mil quinientos"), ficha del ingreso con historial de vigencias, calendario de ingresos, **calendario de flujo con saldo proyectado**, bolsa de nivelación, aportación al hogar y confirmación de extras con su reparto.

**12. Datos nuevos:** `VigenciaIngreso` (ingreso_id, monto neto, desde, hasta), `DescuentoNomina` (ingreso_id, concepto, monto, deuda_id), `BaseVariable` (ingreso_id, método, factor, base semanal), `BolsaNivelacion` (saldo, meta, sueldo semanal), `DistribucionExtra` (extra_id, destino, monto), `AportacionHogar` (miembro, modo, valor) y `ProyeccionFlujo` (fecha, saldo peor caso, saldo al cierre).

**13. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| IN1 | Quincenal $6,000, catorcenal $5,000 y mensual $2,000 | Equivalentes **$2,769.23**, **$2,500.00** y **$461.54** por semana |
| IN2 | Quincena del 31 de octubre de 2026 (sábado) | Se paga el **lunes 2 de noviembre** |
| IN3 | Préstamo recibido de $10,000 | Crea la deuda y **no** cuenta como ingreso propio |
| IN4 | Crédito con descuento de nómina | La cuota **no se paga otra vez** en la cascada y cuenta en la carga de deuda |
| IN5 | Doce semanas variables que suman $8,100 | Promedio **$675** y base de **$540** |
| IN6 | Semana variable de $1,200 con base de $540 | **$660** de extra siguen la cascada |
| IN7 | Método B con las ocho semanas del ejemplo | Bolsa mínima **$820**; **$60** de excedente en la semana 7 |
| IN8 | Reembolso de un gasto médico | **Baja el gasto** de Salud; el ingreso no cambia |
| IN9 | Mes con tres catorcenas | No se trata como extra y se explica |
| IN10 | Calendario del ejemplo | Peor caso de **−$1,350** el lunes 2 y aviso anticipado |
| IN11 | Aportación proporcional con $4,500 y $2,884.62 | **$3,573.75** y **$2,290.87** (suman $5,864.62) |
| IN12 | Se pierde un ingreso | Prueba de estrés, modo ingreso reducido y semanas de fondo cubiertas |
| IN13 | Vales de despensa | Suman al monto de comida y no pagan deuda ni previsión |

**Lo que no se asume:** que un ingreso variable se repita, que un depósito llegue a la hora esperada, ni las reglas de aguinaldo, utilidades o descuentos de tu empleo (se capturan, no se calculan).

### 5.2 GASTOS

**Para qué:** saber en qué se va el dinero y distinguir lo **inevitable** de lo **ajustable**. Es el módulo que más se usa a diario.

**Categorías y subcategorías (ampliadas)**

La app trae un **árbol de categorías base** que el hogar puede usar tal cual, ajustar o ampliar. Tiene **hasta 3 niveles**: categoría → subcategoría → detalle. Los 7 rubros originales se conservan; se agregan **Limpieza y mantenimiento del hogar** y otros rubros frecuentes.

| Categoría | Subcategorías sugeridas | Naturaleza típica |
|---|---|---|
| **Vivienda y servicios** | Renta o hipoteca, cuota de mantenimiento o condominio, predial, luz, agua, gas, internet, telefonía fija, televisión de paga, seguro del hogar | Fija |
| **Limpieza y mantenimiento del hogar** *(nueva)* | Productos de limpieza (detergentes, desinfectantes, limpiadores), papel higiénico y desechables, bolsas de basura, utensilios de limpieza, lavandería y tintorería, servicio doméstico o de limpieza, fumigación y control de plagas, reparaciones (plomería, electricidad, pintura), jardinería, menaje y artículos del hogar, decoración | Mixta |
| **Alimentación** | Despensa y abarrotes, frutas y verduras, carnes y pescados, lácteos y huevo, panadería y tortillería, bebidas, congelados, snacks y dulces, comidas fuera, comida a domicilio, café y colaciones, alimentación especial (dietas, suplementos) | Variable (ver 5.8) |
| **Transporte** | Combustible, transporte público, taxi y apps de transporte, estacionamiento y peajes, mantenimiento del vehículo, refacciones y llantas, seguro vehicular, verificación y trámites del vehículo, multas | Mixta |
| **Salud** | Consultas y especialistas, medicinas, estudios y laboratorio, dental, oftalmología y lentes, seguro médico, hospital y urgencias, terapias y rehabilitación, salud mental, vacunas y prevención, **Cuidados de largo plazo y paliativos** *(ver abajo)* | Recurrente y eventual |
| **Educación** | Colegiaturas, útiles y libros, uniformes, cursos y talleres, transporte escolar, actividades extracurriculares, idiomas | Recurrente |
| **Hijos y familia** | Guardería o cuidado de menores, pañales y artículos de bebé, juguetes, gastos personales de los hijos, apoyo a otros familiares | Mixta |
| **Entretenimiento** | Salidas, cine y eventos, streaming y suscripciones, videojuegos, hobbies, viajes y vacaciones, deportes | Discrecional |
| **Vestimenta** | Ropa, calzado, accesorios, uniformes de trabajo, arreglos y costura | Eventual |
| **Cuidado personal** | Higiene personal, estética y peluquería, cosméticos, gimnasio y deporte, bienestar | Mixta |
| **Mascotas** | Alimento, veterinario y vacunas, estética, accesorios | Mixta |
| **Tecnología y comunicaciones** | Telefonía móvil, equipos y reparaciones, software y aplicaciones, accesorios | Mixta |
| **Seguros, impuestos y trámites** | Seguros de vida, impuestos, comisiones bancarias, intereses y cargos financieros, documentos y trámites, asesoría legal o contable | Fija y eventual |
| **Regalos, donativos y eventos** | Regalos, celebraciones y fiestas, donativos | Eventual |
| **Imprevistos y otros** | Imprevistos, otros sin clasificar | Eventual |

> **Importante:** los **pagos de deudas, el ahorro y la inversión no son categorías de gasto**; viven en sus módulos (5.3, 5.5, 5.4). Lo que sí aparece como gasto son los **intereses y comisiones** que esas deudas generan.

**Caso especial: Cuidados de largo plazo y paliativos (dentro de Salud)**

Pensado para hogares que cuidan a un familiar con una condición como **Alzheimer** u otra enfermedad crónica, degenerativa o terminal. Es un gasto de **alto monto, continuo y que cambia con las etapas de la enfermedad**, por eso se detalla con un tercer nivel:

| Detalle (nivel 3) | Ejemplos |
|---|---|
| Cuidador o enfermería | Por horas, por turno, a domicilio |
| Medicamentos de uso continuo y control de síntomas | Tratamientos recetados, control del dolor |
| Insumos de cuidado diario | Pañales para adulto, protectores, cremas, apósitos, guantes, toallas húmedas |
| Equipos y mobiliario | Cama hospitalaria, colchón antiescaras, silla de ruedas, andadera, grúa de traslado, oxígeno |
| Terapias | Ocupacional, física, cognitiva o de estimulación, de lenguaje |
| Consultas y seguimiento | Neurología, geriatría, psiquiatría, medicina paliativa, nutrición |
| Alimentación especial | Espesantes, suplementos, dietas indicadas |
| Seguridad y adecuaciones del hogar | Barandales, cerraduras y sensores, rampas, adecuaciones del baño |
| Centro de día, estancia o residencia | Cuotas de estancia temporal o permanente |
| Traslados y acompañamiento médico | Transporte adaptado, acompañante a consultas |
| Apoyo emocional y respiro para cuidadores | Psicología, grupos de apoyo, relevo del cuidador |
| Documentos y asesoría legal | Poderes, voluntades anticipadas, seguros |

**Cómo se comporta esta subcategoría**

- **Para quién (beneficiario):** cada gasto puede etiquetar al miembro al que beneficia, de modo que la app sepa **cuánto cuesta el cuidado de esa persona** por semana y acumulado.
- **Cuenta de gasto propia:** el hogar puede **promover** esta subcategoría a una **cuenta de gasto independiente** con su presupuesto, y los familiares **aportan a ella** (ver 5.0 bis). La transparencia total hace visible quién aporta qué al cuidado.
- **Reserva y presupuesto vivo:** se recomienda una bolsa de ahorro de reserva para cuidados y una **revisión periódica del presupuesto**, porque los costos suelen cambiar con la etapa de la enfermedad.
- **Compras recurrentes y precios:** pañales, medicinas e insumos entran al **historial y comparación de precios** (6.10) para detectar dónde conviene comprarlos.
- **Gastos médicos deducibles:** los gastos de salud pueden marcarse como **posiblemente deducibles** y adjuntar su comprobante. Es solo un apoyo informativo: se recomienda confirmarlo con un contador.

**Crear y administrar categorías propias**

- El hogar puede **crear categorías, subcategorías y detalles propios** (hasta 3 niveles) en cualquier momento, desde el alta de un gasto ("+ Nueva categoría") o desde Ajustes.
- Al crear una categoría se define: **nombre, ícono, color, naturaleza** (fija o variable), **prioridad** (necesario, deseable o discrecional), si tendrá **cuenta de gasto propia** y un **presupuesto semanal sugerido** (opcional).
- Las categorías del sistema se pueden **ocultar, renombrar o reorganizar**.
- **Eliminar:** una categoría o subcategoría (del sistema o propia) se puede **eliminar definitivamente si no tiene datos cargados**: ni movimientos, ni presupuestos, ni subcategorías con datos. La eliminación queda en la **bitácora**. Las del sistema eliminadas se pueden restaurar desde la plantilla.
- Las que **ya tienen datos no se borran**: se **archivan**, o se **fusionan** con otra moviendo su historial (con registro en la bitácora).
- Se puede **mover una subcategoría** a otra categoría; los reportes se recalculan sin perder el historial.
- **Plantillas de arranque** para no empezar desde cero: *persona que vive sola, pareja, familia con hijos, hogar con persona en cuidados de largo plazo, hogar con vehículo, hogar con mascotas*.
- Los reportes **consolidan hacia arriba**: cada subcategoría suma a su categoría y cada categoría a su cuenta de gasto.

**Categorías y cuentas de gasto**

- Cada **categoría principal** funciona, por defecto, como una **cuenta de gasto independiente** del hogar (ver 5.0 bis), y las subcategorías son su **desglose** interno.
- Una **subcategoría puede promoverse a cuenta propia** (por ejemplo, *Cuidados de largo plazo y paliativos*) y una **categoría creada por el usuario** puede tener su cuenta desde el inicio.
- **Compras con varios rubros** (por ejemplo, un ticket del súper con comida y limpieza): el gasto se **divide por líneas**, y cada línea va a su categoría y a su cuenta de gasto. La app sugiere la categoría según el producto; el usuario confirma.

**Clasificación transversal (muy importante para decidir recortes)**

- **Fijo / Variable:** monto constante vs. monto que cambia.
- **Necesario / Deseable / Discrecional:** qué se puede recortar si la semana aprieta.
- **Recurrente / Eventual:** si se repite o es un golpe aislado (ej. una consulta médica).
- **Personal / Compartido:** para saber qué es de una persona y qué es del hogar.
- **Para quién (beneficiario):** a qué miembro beneficia el gasto (útil para hijos, adultos mayores o personas en cuidados).
- **Etiquetas libres:** marcas transversales como *vacaciones* o *remodelación*, que cruzan varias categorías.
- **Posiblemente deducible:** marca informativa para gastos que podrían declararse (por ejemplo, salud y educación); se recomienda confirmarlo con un contador.

**Datos por gasto:** monto, categoría y subcategoría (hasta 3 niveles), **para quién (beneficiario)**, etiquetas libres, fecha, miembro que pagó, método de pago (efectivo, débito, tarjeta de crédito → se vincula a Deudas), ¿compartido?, ¿privado?, nota, foto de ticket (opcional).

**Reglas**

- Un gasto pagado con **tarjeta de crédito no sale del dinero de la semana**, sino que **aumenta el saldo de la deuda** y reduce el límite disponible. La app muestra ambos efectos: "gastaste $500 (presupuesto) → deuda de tarjeta +$500".
- Los gastos fijos se generan automáticamente según su frecuencia (no se capturan cada vez).
- Los gastos eventuales de alto monto (salud, vestimenta) se cubren con **reservas semanales** (ver 5.6).
- Captura rápida: monto → categoría (atajos de las 3 más usadas) → listo.
- **Cuatro vías de captura** (ver sección 6.9): manual, voz, imagen (captura, foto, cámara con detección de texto, QR) y precios de supermercados. Siempre se **confirma antes de guardar**.
- Todo gasto **sale de una cuenta de origen** (individual, compartida, efectivo o tarjeta) y **se aporta a una cuenta de gasto** (el rubro). El miembro elige a cuál aportar; el movimiento queda a su nombre en el libro.

**Pantallas:** captura rápida, lista semanal por categoría, "pendientes de pago" (fijos próximos), vista Yo / Pareja / Hogar.

**Captura de gastos por voz (a detalle)**

La voz es la vía más rápida para anotar un gasto **en el momento** (en la fila de la caja, caminando, manejando con manos libres). El objetivo es que dictar una frase natural tome menos de **10 segundos** y que lo que se guarde sea correcto después de **un solo toque de confirmación**.

*Flujo:* botón de micrófono (siempre visible en la captura rápida) → el usuario habla → la app muestra el **texto reconocido** → una **tarjeta de confirmación** con los campos detectados → "Guardar" o corregir un campo con un toque.

| Etapa | Qué hace | Dónde se procesa |
|---|---|---|
| **1. Escuchar** | Convierte voz a texto en español de México | En el teléfono (sin audio guardado) |
| **2. Normalizar** | Pasa "ciento cincuenta", "mil doscientos" o "doscientos y medio" a número; reconoce "pesos", "varos" y "lucas" como moneda | Reglas locales |
| **3. Extraer campos** | Monto, concepto, categoría, cuenta de origen, quién pagó, comercio, fecha y para quién | Reglas locales + diccionario del hogar |
| **4. Resolver ambigüedad** | Si falta o es dudoso un campo, lo marca en amarillo y pregunta solo eso | Pantalla de confirmación |
| **5. Aprender** | Si el usuario corrige, la app recuerda la asociación para la próxima vez | Local, por hogar |

**Qué entiende la frase (campos y palabras clave)**

| Campo | Cómo se dice | Ejemplo | Si falta |
|---|---|---|---|
| **Monto** | Número + "pesos" (o solo el número) | "ciento cincuenta pesos" | Obligatorio: la app lo pide |
| **Concepto / categoría** | Palabra del catálogo, de las subcategorías o un apodo aprendido | "gasolina", "tortillas", "pañales" | Propone la categoría más probable y pide confirmar |
| **Cuenta de origen** | "con la tarjeta de Ana", "en efectivo", "con la Nu", "de la cuenta compartida" | "con la Costco" | Usa la cuenta predeterminada del miembro |
| **Quién pagó** | Por defecto, quien dicta; o "pagó Alex" | "pagó Alex" | Quien dicta |
| **Cuenta de gasto a la que aporta** | Por defecto, la categoría; o "de la bolsa de cuidados" | "a cuidados de papá" | Categoría del concepto |
| **Comercio** | "en Soriana", "en la farmacia" | "en Costco" | Se deja vacío o se infiere del historial |
| **Fecha** | "hoy" (por defecto), "ayer", "el lunes", "antier" | "ayer" | Hoy |
| **Para quién (beneficiario)** | "para papá", "de los niños" | "medicinas para papá" | Vacío |

**Frases de ejemplo y resultado**

| Frase dictada | Resultado propuesto |
|---|---|
| "Gasté 150 pesos en gasolina con la tarjeta de Ana" | $150 · Transporte → Combustible · origen: tarjeta de Ana (aumenta su deuda, no sale de la semana) |
| "Leche cuarenta y cinco y pan ochenta, en efectivo" | **Dos gastos:** $45 leche y $80 pan, ambos a Alimentación (cuenta de gasto $125), origen efectivo |
| "Ayer pagué mil doscientos de luz" | $1,200 · Vivienda y servicios → Luz · fecha de ayer; si ya existe el gasto fijo de luz, **lo vincula** en vez de duplicarlo |
| "Doscientos ochenta de pañales para papá con la compartida" | $280 · Salud → Cuidados de largo plazo → Insumos de cuidado diario · beneficiario: papá · origen: cuenta compartida |
| "Cien pesos de tacos" | $100 · Alimentación → Comidas fuera · pregunta solo la cuenta si no hay predeterminada |

**Reglas de seguridad y calidad**

1. **Nunca se guarda sin confirmar.** La tarjeta de confirmación muestra el **monto en grande** y lo lee en voz alta si el usuario lo pide, porque el error más caro es una cifra mal entendida ("quince" contra "cincuenta").
2. **Alerta de monto atípico:** si el monto es mucho mayor que el habitual de esa categoría, pide confirmar el número otra vez.
3. **Varios gastos en una frase** se separan por "y" o por pausas y se muestran como una lista editable.
4. **Compras con varios rubros** ("súper: ochocientos de comida y ciento veinte de limpieza") se dividen por líneas, igual que un ticket (5.2).
5. **Anular por voz:** "borra el último gasto" solo **propone anularlo**; la anulación se hace con contraasiento y queda en la bitácora (5.9). No se borra nada.
6. **Duplicados:** si hay un gasto igual (mismo monto, categoría y hora cercana), avisa antes de guardar.
7. **Roles:** quien no tiene permiso de captura solo puede dictar un **borrador** que el albacea o el titular confirman (5.0 ter).
8. **Privacidad:** el audio **no se guarda ni se envía**. Lo que sale del teléfono, solo si el usuario lo permite, es **texto sin cuentas ni datos personales** para frases complejas (8 bis).
9. **Sin conexión:** debe funcionar sin internet con el reconocimiento del teléfono; si el español de México no está disponible sin conexión en ese equipo, la app lo avisa y ofrece descargar el paquete de idioma o dictar con conexión.
10. **Respaldo:** si el reconocimiento falla dos veces, la app ofrece el teclado con la **captura rápida** (monto → categoría).

**Vocabulario del hogar:** cada hogar tiene un diccionario propio de **apodos** ("la azul" = tarjeta Azul BBVA, "la compartida", "el súper de siempre") y de **sinónimos** de categorías ("el chofer" = taxi y apps). Se llena solo con las correcciones y se puede editar en Ajustes.

**Pruebas de aceptación de la voz**

| # | Prueba | Resultado esperado |
|---|---|---|
| V1 | Dictar "gasté 150 pesos en gasolina con la tarjeta de Ana" | Tarjeta con $150, Combustible y tarjeta de Ana, lista para confirmar |
| V2 | Dictar dos gastos en una frase | Dos filas editables que suman a la misma cuenta de gasto |
| V3 | Dictar "quince" cuando era "cincuenta" y corregir el monto | El monto se corrige con un toque y la app aprende el caso |
| V4 | Dictar sin internet | Se reconoce y se guarda localmente; se sincroniza al volver la conexión |
| V5 | Decir "borra el último gasto" | Propone anular; al confirmar, queda contraasiento y nota en la bitácora |
| V6 | Dictar con un rol sin permiso de captura | Queda como borrador pendiente de confirmar |
| V7 | Dictar un gasto fijo ya programado | Se vincula al gasto fijo y no se duplica |

**Fases:** la voz de **frases simples** (monto + categoría + cuenta) entra con la captura rápida de Gastos; el **diccionario del hogar, los varios gastos por frase y los beneficiarios** llegan después; las **frases complejas con ayuda de IA** son opcionales y con permiso (6.13).


**Se conecta con:** Presupuesto (consumo de cada partida), Deudas (pagos con tarjeta), Alimentación (compras reales).

### 5.3 DEUDAS

**Para qué:** conocer exactamente cuánto se debe, cuánto cuesta deber y en cuánto tiempo se sale. Las deudas son **compromisos que ocupan ingreso futuro**; sin verlas el presupuesto se engaña.

**Tipos** (los tres originales)

| Tipo | Características clave |
|---|---|
| **Préstamos** | Saldo, tasa, plazo, cuota fija, acreedor (banco, persona) |
| **Tarjetas de crédito** | Saldo, límite, tasa, **fecha de corte** y **fecha límite de pago**, pago mínimo, pago para no generar intereses |
| **Créditos** (hipotecario, auto, nómina, departamentales) | Saldo, tasa, mensualidades restantes, seguro asociado |

**Datos por deuda:** acreedor, tipo, monto original, saldo actual, tasa (anual y/o CAT), pago periódico, frecuencia, próxima fecha de pago, plazo restante, miembro responsable, ¿compartida?

**Reglas y cálculos**

- **Pago semanal equivalente** de cada deuda → entra al presupuesto como partida obligatoria (antes que gustos).
- **Carga de deuda** = pagos de deuda semanales ÷ ingreso semanal. La app la muestra como semáforo (ej. verde < 20%, ámbar 20–35%, rojo > 35%; umbrales configurables).
- **Prioridad de pago:** ver "Prioridad de pago entre deudas" más abajo (decisión del 15/oct/2026: por **costo**, con los préstamos familiares al último).
- **Simulador:** "si pago $X extra por semana, ¿cuándo salgo y cuánto ahorro en intereses?"
- **Tarjetas:** alerta de corte y fecha límite; sugerir pagar el total para evitar intereses; mostrar **uso del límite** (ideal < 30%).
- Cada pago registrado actualiza saldo (capital vs. interés).
- **Abono planeado y abono real:** el plan fija un abono; el real puede ser menor si el gasto se pasa del presupuesto (5.6 bis, punto 6). Lo no abonado queda como **abono diferido**, **no reduce el saldo** y, en tarjetas y créditos, **puede aumentar la deuda** por intereses y cargos. En préstamos entre familiares (sin interés) el saldo no crece. Si el abono queda **por debajo del mínimo exigible**, la app lo marca en rojo.
- **Naturaleza contable:** el pago de **capital** es un egreso tipo 2 que baja un pasivo; los **intereses y cargos** son gasto financiero (5.0 bis 2).

**Prioridad de pago entre deudas (decisión del 15/oct/2026)**

1. **Siempre primero los pagos mínimos** (o los abonos acordados) de todas las deudas.
2. El **abono extra** (el remanente, ver 5.6 bis) se aplica por **costo y no por tamaño** (el costo incluye los cargos fijos que se evitan al cerrar la cuenta, 5.3 ter, punto 11): a la deuda donde **cada peso pagado ahorra más intereses**, es decir, la de **mayor tasa efectiva** (la tasa declarada o la **estimada** por la app, ver abajo). El **saldo** y el **interés mensual en pesos** se muestran siempre, sirven de desempate y de base para calcular cuánto tarda en liquidarse cada deuda.
3. Las deudas **sin costo** reciben el extra **al final**: primero las deudas **con costo** (tarjetas y créditos con interés, por tasa) y **después los préstamos entre familiares** (sin interés). Solo reciben abono extra las deudas con tasa mayor que cero y, al final, los préstamos familiares.
4. El usuario puede **fijar una prioridad manual** si hay una razón (cargos por pago tardío, tarjeta cerca del límite, un acuerdo).
5. Las compras a **meses sin intereses (MSI)** **no reciben abono extra**: se pagan en sus mensualidades programadas, porque adelantarlas no ahorra intereses (ver 5.3 bis). Ese dinero se usa en una deuda con costo o, si no hay, va a ahorro.
6. En el **crédito automotriz** (cuota fija con interés), el extra solo se aplica si el contrato permite **pago anticipado a capital** y sin comisión que supere el ahorro; la app registra si el extra reduce plazo o cuota (**verificar con la caja**).

**¿Por qué por tasa y no por el monto de intereses?** Ejemplo ilustrativo con cuatro tarjetas y un abono extra de $1,500 al mes (pago mínimo supuesto: interés del mes más 1 % del saldo inicial; cuota total fija de $3,530 al mes; detalle en 5.3 ter):

| Tarjeta | Saldo | Tasa anual | Interés mensual en pesos |
|---|---|---|---|
| A | $20,000 | 45 % | $750 |
| B | $5,000 | 60 % | $250 |
| C | $12,000 | 38 % | $380 |
| D | $8,000 | 30 % | $200 |

| Orden en que se paga el extra | Interés total pagado hasta liquidar todo |
|---|---|
| **Mayor tasa primero** (B, A, C, D) | **≈ $14,112** |
| Mayor interés en pesos primero (A, C, B, D) | ≈ $15,183 |
| Mayor saldo primero (A, C, D, B) | ≈ $15,430 |
| Menor saldo primero (B, D, C, A) | ≈ $15,617 |

La tarjeta A genera **más intereses en pesos**, pero la B cobra **más por cada peso adeudado**, y pagarla primero ahorra más. **Tu criterio** ("pagar primero la de mayor monto si genera más intereses") **coincide cuando el monto y la tasa van juntos**: si la tarjeta grande también es la de mayor tasa, será la primera. Cuando no, gana la tasa. La simulación es **ilustrativa**; con tus datos reales el simulador de abajo muestra la comparación.

**Estimador de tasa e intereses**

**Lo que no hace:** no entra a la banca móvil ni pide contraseñas del banco. Es un riesgo de seguridad y suele ir contra los términos de los bancos.

| Vía para obtener los datos | Costo | Etapa |
|---|---|---|
| **1. Captura manual** de los datos clave del estado de cuenta | Cero | Primera |
| **2. Foto o PDF del estado de cuenta leído en el teléfono** (OCR) con pantalla de confirmación | Cero (ML Kit en el teléfono, ya previsto en 8 bis) | Segunda |
| **3. Archivo (PDF o CSV) descargado por el usuario** desde su banca y cargado en la app | Cero | Tercera |
| **4. Conexión directa con el banco** | Por ahora no | Futuro |

Sobre la conexión directa: la Ley Fintech prevé que las entidades compartan información mediante interfaces (API), pero en el artículo de 2020 que revisé las reglas para **datos de cuentas de clientes** todavía estaban **pendientes**. **No verifiqué el estado actual**; se revisa cuando se decida conectar cuentas reales (decisión 1).

Los estados de cuenta son **datos sensibles**: se leen **en el teléfono** y **nunca se envían a servicios de IA** (6.13).

**Cómo aprende la app, en cuatro pasos**

1. **Calibración** con uno o dos estados de cuenta: fecha de corte y límite de pago, saldo inicial y final, compras, pagos, **intereses cobrados**, comisiones y cargos, tasa anual y CAT (si aparecen), pago mínimo y pago para no generar intereses.
2. **Tasa implícita:** tasa diaria = intereses cobrados ÷ suma de los saldos diarios sujetos a interés; tasa anual estimada = tasa diaria × 365. Si el estado de cuenta trae la tasa declarada, se compara.
3. **Cálculo propio:** con las **compras y pagos que el usuario registra**, la app reconstruye el saldo diario y **estima el interés del ciclo** = saldo diario sujeto a interés × tasa diaria. Se muestra siempre como **"estimado"**.
4. **Verificación:** al capturar el siguiente estado de cuenta, compara lo estimado con lo cobrado. Si la diferencia está dentro de **±5 %**, queda como está; si no, pide revisar (cargos, comisiones, impuestos, promociones) y **recalibra**. La diferencia se registra como **ajuste de gasto financiero** (5.0 bis 2).

Reglas del modelo:

- **Periodo sin intereses:** si se pagó el **total** (pago para no generar intereses) antes de la fecha límite, ese ciclo **no genera interés sobre compras**; el modelo lo maneja con una bandera por tarjeta. Cada banco tiene reglas propias, por eso se **calibra con estados de cuenta** y las cifras son **estimaciones**, no el saldo oficial.
- **Préstamos y créditos con cuota fija:** la tasa se deduce del saldo, la cuota y el plazo restante.
- **Préstamos familiares:** tasa cero; no se estima nada.

**Pantallas:** resumen de deuda total, tarjeta por deuda (saldo, próximo pago, progreso), simulador de pagos extra, calendario de vencimientos.

**Se conecta con:** Ingresos (préstamos recibidos crean deuda), Gastos (pagos y compras con tarjeta), Presupuesto (partida obligatoria), Objetivos ("liquidar tarjeta X").

### 5.3 bis TARJETAS, MESES SIN INTERESES Y BENEFICIOS

**Para qué:** tener claro cómo se usa cada tarjeta y cada crédito: qué se debe, qué cuesta, cuándo vence y qué beneficios se pueden aprovechar **sin pagar intereses**. Es la parte de 5.3 que baja a las instituciones reales del hogar.

**1. Cartera inicial del hogar** (según lo indicado el 15/oct/2026)

| Institución | Cuenta | Tarjeta de crédito | Crédito |
|---|---|---|---|
| **Nu** | Sí | Nu | — |
| **BBVA** | Sí | Azul BBVA | — |
| **Banamex** | Sí | Costco Banamex y Joy Banamex | — |
| **Mercado Pago** | Sí | Mercado Pago | — |
| **Stori** | Sí | Stori | — |
| **Caja Popular Mexicana** | — | — | Crédito automotriz |

Para capturar sus datos se usa el libro **`FICHA_DEUDAS_Y_TARJETAS.xlsx`** (instituciones, tarjetas, crédito automotriz, compras a MSI, beneficios y estados de cuenta). La app podrá **importarlo** como carga inicial, igual que los datos semilla de 6.11.

**2. Compras a meses sin intereses (MSI)**

- Una compra a MSI es una **deuda con tasa cero** y mensualidades programadas: **no recibe abono extra**, porque adelantarla **no ahorra intereses**. Ese dinero va a una deuda con costo o, si no hay, a ahorro (regla de 5.6 bis, punto 7).
- **Sí cuenta** en la **carga de deuda** y en el **presupuesto de deuda** de cada semana (la mensualidad entra en el egreso tipo 2).
- Ocupa **límite de crédito** durante todo el plazo (normalmente por el saldo pendiente; **verificar con cada emisor**).
- Datos: tarjeta, comercio, descripción, fecha de compra, monto total, número de mensualidades, mensualidades pagadas y restantes, saldo pendiente.
- La app muestra el **calendario de mensualidades** y avisa cuando se acumulan muchas en un mismo mes (flujo, 5.6 bis).
- Adelantar un MSI solo se propone si el usuario lo pide, por ejemplo para **liberar límite**.
- Cuidado: si una tarjeta tiene **saldo con intereses**, el orden en que el banco aplica los pagos puede cambiar el efecto; la app no lo asume y lo calibra con los estados de cuenta (5.3).

**3. Los beneficios solo valen si no se pagan intereses**

Regla central: un beneficio (cashback, puntos, descuento) **casi siempre vale menos que los intereses** de un saldo con costo. Por eso:

1. La app **no recomienda** una tarjeta para compras nuevas si tiene **saldo que genera intereses** (además, en muchas tarjetas se pierde el periodo sin intereses; **verificar cada una**).
2. Las compras que buscan beneficios deben **estar dentro del presupuesto** de su rubro: **la app no empuja a gastar más** para ganar puntos.
3. Cada beneficio se anota con su **fuente** (sitio oficial del emisor o contrato) y su **fecha de verificación**; **sin fuente no se usa para recomendar**. Los beneficios cambian con frecuencia.

**Tipos de beneficio:** cashback (%), puntos (con su valor estimado por punto), MSI en comercios o bancos, descuentos por categoría o comercio, seguros, exención de anualidad, promociones temporales con tope y vigencia.

**Datos de cada beneficio:** tarjeta, tipo, categoría o comercio, valor, tope mensual, vigencia, condiciones, fuente y fecha de verificación.

**4. Qué tarjeta usar en cada compra: "¿Con cuál pago?"**

Al capturar un gasto, la app sugiere la tarjeta (o el medio de pago) con este orden:

| Paso | Regla |
|---|---|
| 1. Descartar | Tarjetas con **saldo con intereses**, con el **límite casi agotado** (aviso arriba de 30 %) o **congeladas** |
| 2. Calcular el beneficio neto | Monto × (cashback % + valor de los puntos), respetando el **tope mensual** y las condiciones; si no hay beneficio verificado, vale cero |
| 3. Desempatar por **días de financiamiento** | Más días entre la compra y la **fecha límite de pago** |
| 4. MSI | Si el comercio ofrece MSI y la mensualidad **cabe en el presupuesto de deuda**, se muestra como opción, nunca como obligación |
| 5. Mostrar | Una sugerencia y las alternativas, con el **beneficio estimado en pesos** y los días de financiamiento; el usuario decide |

**Días de financiamiento** (ejemplo ilustrativo): una tarjeta con **corte el día 10** y **fecha límite el día 30**.

| Fecha de compra | Se cobra en el corte del | Fecha límite | Días para pagar |
|---|---|---|---|
| 10/oct | 10/oct | 30/oct | **20** |
| 11/oct | 10/nov | 30/nov | **50** |

La compra **un día después del corte** da casi **30 días más** que la del día del corte. Los días de corte y de límite se capturan de cada tarjeta, porque varían por emisor.

**5. Contabilidad de los beneficios**

- El **cashback abonado** se registra como **ingreso** tipo "beneficios" cuando llega al estado de cuenta o a la cuenta (5.0 bis 2).
- Los **puntos** no se cuentan en la contabilidad hasta que se **canjean**; antes se muestran aparte como valor estimado.
- La **anualidad** es un **gasto** (financiero); si se exonera por consumo, la app muestra cuánto falta para lograrlo.

**6. Pantallas:** "Mis tarjetas" (límite usado, corte, fecha límite, mínimo, pago para no generar intereses, MSI y beneficios), **"¿Con cuál pago?"** dentro de la captura de gasto, "Beneficios del mes" (obtenidos, topes y perdidos por no usar la tarjeta indicada), calendario de cortes y fechas límite, y detalle de MSI.

**7. Lo que se verificó en los sitios oficiales (15/oct/2026)**

Resumen de las páginas oficiales de cada emisor; el detalle, con cada fuente, está en la hoja *Beneficios* de la ficha. Los beneficios cambian: se vuelven a verificar antes de usarlos.

| Tarjeta | Anualidad o comisión fija | Beneficio principal publicado | Para tener presente |
|---|---|---|---|
| **Costco Banamex** | **$650 al año** (confirmado por el equipo; equivale a $54.17 al mes) | **Reembolso anual**: 5 % gasolina Costco (tope $10,000 al mes), 4 % educación (tope $20,000), 3 % Costco, 2 % restaurantes, streaming, TV e internet, 1 % lo demás; **2.3 %** de ahorro en Costco México | Se abona en el **corte de diciembre** y **solo si la tarjeta está al corriente**. La parcialización en Costco (9.90 %) **no es MSI** |
| **Joy Banamex** | Sin comisión por administración | **Sin recompensas**; seguros Mastercard y 2x1 en Cinépolis | **Comisión por inactividad de $149 + IVA al mes**: se evita con compras de **al menos $300 al mes**, y los MSI **no cuentan** |
| **Azul BBVA** | $748 + IVA al año (la página no describe cómo exentarla) | **9 % en Puntos BBVA** (la página no da el valor en pesos del punto) y seguros (equipaje, compra protegida, protección de precios) | Los **MSI no acumulan puntos**; los puntos vencen a los 13 meses; el canje exige estar al corriente |
| **Nu** | Sin anualidad | MSI con comercios aliados; fecha límite de pago elegible desde la app | No se mencionan cashback ni puntos en las páginas consultadas |
| **Mercado Pago** | Sin anualidad | Hasta 24 MSI en productos seleccionados de Mercado Libre | La página de beneficios del sitio de ayuda bloqueó el acceso automático: revísala tú |
| **Stori** | $0 de por vida | Tu tarjeta es **Green** (confirmado): sin cashback listado; MSI en cientos de comercios | La Black sí da 1 % de cashback, pero **no es la tuya**; no se cuenta ningún cashback de Stori |

**CAT y tasas publicados** (útiles como punto de partida del estimador de 5.3; la tasa de tu estado de cuenta manda): Costco Banamex, CAT promedio 79.9 % sin IVA y tasa promedio ponderada 58.29 % (calculado el 27/jul/2026); Azul BBVA, CAT promedio 89.4 % sin IVA y tasa promedio ponderada 59.52 % (calculado el 13/jul/2026). Ambas son tasas **variables**.

**Reglas que la app debe aplicar por estos hallazgos**

1. **MSI y beneficios:** cada tarjeta lleva la bandera *"los MSI acumulan beneficios"* (sí/no). Si es no (Azul BBVA), la sugerencia "¿Con cuál pago?" **no cuenta el beneficio** de una compra a MSI.
2. **Comisión por inactividad (Joy):** la app recuerda la **compra mínima de $300 al mes** y avisa si faltan pocos días; no recomienda gastar más: basta con **mover una compra normal** a esa tarjeta, y **sin MSI**.
3. **Beneficios condicionados a estar al corriente** (reembolso de Costco, canje de Puntos BBVA): si hay un pago vencido, la app avisa que **se puede perder el beneficio**.
4. **Compras diferidas, pagos fijos y parcialización** (Nu, Banamex, Costco) **son deuda con costo, no MSI**: sí reciben abono extra según su tasa (5.3).
5. **Costos fijos** (anualidad de BBVA y comisión anual de Costco de $650, que la app prorratea a $12.50 por semana): se registran como **gasto financiero** y se reservan en el presupuesto.
6. **Reembolso anual de Costco:** se muestra como **beneficio por recibir en diciembre**, con el avance por categoría y los topes mensuales; se registra como ingreso cuando se abona.

**Lo que no pude verificar:** el valor en pesos de un punto BBVA; la comisión de 5.50 % y 7 % que la página de BBVA muestra junto a los MSI (no aclara a qué compras aplica); cashback o puntos en Nu y Mercado Pago; y los documentos de costos y comisiones de Nu y de Stori.

**8. Pruebas de aceptación**

1. Una tarjeta con saldo con intereses **no aparece** como sugerencia de compra.
2. Con dos tarjetas sin intereses y el mismo beneficio, gana la que da **más días de financiamiento**.
3. Un beneficio **sin fuente** o con la vigencia vencida **no se usa**.
4. Una compra a MSI **no recibe** abono extra y aparece en el calendario; su mensualidad sube el egreso tipo 2.
5. El beneficio estimado **respeta el tope mensual**.
6. El cashback abonado crea un **ingreso** y los puntos sin canjear **no**.
7. Una compra a MSI en una tarjeta marcada *"MSI no acumula"* **no suma beneficio** en la sugerencia.
8. Con Joy, a **cinco días del cierre del mes** sin compras de $300, aparece el recordatorio de la comisión por inactividad.
9. Con un pago vencido en Costco o BBVA, aparece el aviso de que **el beneficio puede perderse**.

### 5.3 ter SIMULADOR Y ESTRATEGIAS DE PAGO DE DEUDAS (a detalle)

**Para qué:** que la persona vea **la fecha en que sale de cada deuda**, **cuánto le cuesta deber** y **qué pasa si cambia algo** (más abono, menos ingreso, una compra grande). Esta sección baja a detalle el simulador mencionado en 5.3 y usa las reglas de prioridad ya decididas (5.3), la cascada INGRESO → PRESUPUESTO → DEUDA → remanente (5.6 bis) y los datos de tarjetas y MSI (5.3 bis).

**Preguntas que responde**

1. ¿En qué semana quedo libre de cada deuda y de todas?
2. ¿Cuánto pago en intereses y cuánto me ahorro con el abono extra?
3. ¿A qué deuda le conviene el extra esta semana?
4. ¿Qué pasa si mi ingreso baja, si pago de más o si me atraso?
5. ¿Me conviene liquidar con ahorros, consolidar deudas o adelantar el crédito del auto?

**1. Datos de entrada**

| Dato | De dónde sale |
|---|---|
| Saldo, tasa efectiva (declarada o estimada), pago mínimo, fecha de corte y límite de pago | Ficha de cada deuda (5.3, 5.3 bis) |
| Calendario de **MSI** (mensualidades restantes) | 5.3 bis; se pagan en su calendario y **no reciben extra** |
| **Abono extra disponible** por semana | Remanente proyectado del motor semanal (5.6 bis), editable en el simulador |
| Ingresos futuros conocidos y días de pago | 5.1, con la regla de fin de semana y festivo al siguiente día hábil |
| Condiciones del crédito automotriz (pago anticipado, comisión) | Ficha del crédito (pendiente 11 de 12.2) |

**2. Cómo calcula (motor semanal)**

Simula **semana a semana** hasta que todas las deudas llegan a cero:

1. **Interés diario** = saldo × tasa anual ÷ 365, sumado a lo largo de la semana. En tarjetas respeta el **periodo sin intereses** si se pagó el total antes de la fecha límite (5.3).
2. **Pagos programados** en su fecha, pasados al siguiente día hábil si caen en fin de semana o festivo oficial.
3. **Primero los mínimos** de todas las deudas.
4. **El extra** va a la deuda con **mayor tasa efectiva**; los préstamos familiares quedan al final y los MSI no reciben nada (5.3).
5. **Efecto cascada:** cuando una deuda llega a cero, **su pago programado se suma al extra** y pasa a la siguiente. Es lo que acorta el plan.
6. Resultado: semana de libertad por deuda, intereses totales, pago total y **ahorro frente a pagar solo mínimos**.

Todo es **estimado** y así se rotula: depende de que la tasa estimada sea correcta (se recalibra con cada estado de cuenta, 5.3).

**3. Estrategias que compara**

| Estrategia | Qué hace | Cuándo se recomienda |
|---|---|---|
| **Solo mínimos** | Paga lo mínimo de todo | Es la **línea base** para medir el ahorro; no se recomienda |
| **Mayor tasa primero** *(por defecto)* | El extra va a la deuda más cara por peso adeudado | Casi siempre: **paga menos intereses** |
| **Menor saldo primero** | Liquida deudas pequeñas para liberar pagos y motivarse | Si la persona prefiere ver victorias rápidas; la app muestra **cuánto más cuesta** frente a mayor tasa |
| **Mayor interés en pesos primero** | Ataca la que más intereses genera en pesos | Se muestra para comparar; solo coincide con la de mayor tasa si saldo y tasa van juntos |
| **Manual** | La persona fija el orden | Cargos por atraso, tarjeta cerca del límite o un acuerdo (5.3, regla 4) |

**4. Ejemplo con las cuatro tarjetas de 5.3**

Mismas tarjetas (A, B, C y D de 5.3), con una **cuota total fija** igual a los mínimos del primer mes ($2,030) más **$1,500** de extra, es decir **$3,530 al mes** (≈ **$814.62 por semana**). Mínimo supuesto: interés del mes más 1 % del saldo inicial. El ejemplo usa meses para que se lea fácil; la app lo hace por semana.

| Estrategia | Meses para salir de todo | Intereses totales | Ahorro frente a solo mínimos |
|---|---|---|---|
| Solo mínimos ($2,030 fijos) | 42 | ≈ $40,228 | — |
| **Mayor tasa primero** | **17** | **≈ $14,112** | **≈ $26,116** |
| Mayor interés en pesos primero | 18 | ≈ $15,183 | ≈ $25,045 |
| Menor saldo primero | 18 | ≈ $15,617 | ≈ $24,611 |

Calendario con **mayor tasa primero**: la tarjeta **B** se liquida en el mes **4**, la **A** en el **12**, la **C** en el **15** y la **D** en el **17**. Cuando B se liquida, sus $300 del mínimo pasan al extra de A.

**5. Escenarios "¿y si…?"**

| Escenario | Qué muestra el simulador |
|---|---|
| **Más o menos extra** (control deslizante) | Semana de libertad e intereses con cada monto; el punto donde un peso más ya ahorra poco |
| **Baja el ingreso** (por ejemplo, −20 %) | **Prueba de estrés:** si aún se cubren mínimos, gastos protegidos y mensualidades de MSI; si no, avisa **antes** de que ocurra |
| **Nueva compra a MSI** | Cuánto sube la carga mensual y cuánto retrasa el plan; no recibe extra |
| **Pago tardío** | Interés moratorio y comisión que declara el contrato, más el aviso de que **se puede perder un beneficio** (5.3 bis) |
| **Liquidar con ahorro** | Compara el **rendimiento del ahorro** contra la **tasa de la deuda**; si la deuda es más cara, conviene liquidar, **sin tocar el colchón mínimo** (regla 2 de abajo) |
| **Consolidar o transferir saldo** | Costo total con la nueva tasa, comisión por apertura y vigencia de la promoción, contra seguir como está; solo se sugiere si el **costo total baja** |
| **Adelantar el crédito del auto** | Solo si el contrato permite pago anticipado; muestra ahorro de intereses menos comisión (reduce plazo o reduce cuota, 5.3) |

**6. Reglas de seguridad del simulador**

1. **Los mínimos siempre se pagan primero**; ningún escenario los sacrifica.
2. **Colchón mínimo:** el simulador no propone usar el ahorro por debajo de **dos semanas de gastos protegidos** (renta, servicios, cuidados; por defecto, editable).
3. No sugiere **tomar nuevo crédito** sin mostrar su **CAT y su costo total**.
4. Las cifras son **estimaciones con tus datos**, no asesoría financiera; la tasa real manda.
5. Con deudas **sin costo** (préstamos familiares), no hay urgencia por tasa: se pagan en el acuerdo y al final del extra.
6. No empuja a gastar más para obtener beneficios de tarjeta (5.3 bis).

**7. Alertas**

Corte y límite de pago de cada tarjeta, uso del límite superior a 30 %, **mínimo en riesgo** en la prueba de estrés, interés estimado del mes, cambio de la **semana de libertad** (adelantada o atrasada), deuda liquidada y **hitos** (por ejemplo, 25 %, 50 % y 75 % del saldo original pagado).

**8. Pantallas**

| Pantalla | Contenido |
|---|---|
| **Panorama de deuda** | Total, costo semanal de deber (intereses estimados), carga de deuda con semáforo |
| **Plan de salida** | Línea de tiempo por deuda con su semana de libertad |
| **Simulador** | Control deslizante del extra, comparador de estrategias y escenarios |
| **Consolidación** | Comparación de costo total entre seguir y cambiar |
| **Calendario de vencimientos** | Cortes, límites de pago y mensualidades con día hábil ajustado |

**9. Datos nuevos**

`PlanDeuda` (hogar, estrategia, extra semanal, fecha de cálculo), `PlanDeudaSemana` (semana, deuda, pago programado, extra, interés estimado, saldo final), `EscenarioSimulacion` (parámetros y resultados guardados para comparar) y `ColchonMinimo` (semanas de gastos protegidos). Los planes **no modifican saldos**: solo los pagos registrados lo hacen.

**10. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| D1 | Las cuatro tarjetas con $3,530 al mes y mayor tasa primero | Libre en **17 meses** con intereses ≈ **$14,112** |
| D2 | Mismas tarjetas, solo mínimos | **42 meses** e intereses ≈ **$40,228** |
| D3 | Liquidar B | El pago de B pasa a A el mismo ciclo |
| D4 | Una compra a MSI entre las deudas | Paga su calendario y **no recibe extra** |
| D5 | Un préstamo familiar sin interés | Recibe extra **al último** |
| D6 | Pago programado en sábado | Se mueve al **lunes** (o al siguiente día hábil si es festivo) |
| D7 | Remanente en cero | Solo mínimos y aviso de que no hay extra |
| D8 | Ingreso −20 % con mínimos no cubiertos | Alerta **antes** del vencimiento |
| D9 | Ahorro que rinde menos que la tasa de una tarjeta | Sugiere liquidar solo lo que deja el **colchón mínimo** |
| D10 | Tarjeta de $15,000 al 45 % y otra de $1,500 al 38 % sin cargos (extra $600 al mes) | Grande primero: ≈ $5,651; pequeña primero: ≈ $5,807; la app ofrece la pequeña como opción **por ≈ $156 más** |
| D11 | La misma tarjeta pequeña con comisión de $60 al mes y **cerrar al liquidar** marcado | La pequeña va **primero**; costo total ≈ $5,774 contra ≈ $6,671 |
| D12 | Igual que D11 pero **sin** marcar cerrar al liquidar | El cargo no influye en el orden: va la grande primero |

**11. ¿Conviene liquidar primero la deuda pequeña? (exploración del 17/oct/2026)**

La idea: *"si la deuda pequeña casi no genera intereses, quizá conviene quitarla primero para no pagar los intereses más altos de la grande"*. Hay que separar dos cosas, porque la intuición mezcla efectos que la matemática separa.

**a) Lo que NO cambia: la liberación de flujo ya está en el cálculo.** Cuando una deuda se liquida, su pago pasa al extra (efecto cascada, punto 2). Eso ocurre **igual** con cualquier orden, porque el dinero total es el mismo. Por eso, con **costos solo por interés**, pagar primero la de mayor tasa gasta **menos** en intereses, aunque la pequeña se acabe antes. Ejemplo (una tarjeta grande de $15,000 al 45 % y otra pequeña de $1,500 al 38 %, extra de $600 al mes, cuota total fija):

| Orden | Pequeña liquidada en el mes | Intereses totales |
|---|---|---|
| **Grande primero** (mayor tasa) | 17 | **≈ $5,651** |
| Pequeña primero | **3** | ≈ $5,807 |

Quitar la pequeña primero **cuesta ≈ $156 más** en intereses a cambio de **cerrar una deuda en 3 meses** (una cuenta menos que vigilar). Es una **ventaja de ánimo y de orden, no de dinero**; la app la muestra así y deja decidir.

**b) Lo que SÍ cambia el orden: los costos fijos que se evitan al cerrar la deuda.** Una deuda pequeña puede ser **más cara por peso** de lo que su tasa dice si trae un **cargo fijo** (comisión mensual, anualidad, seguro, cargo por inactividad) que **desaparece solo si la cuenta se cierra**. Por eso el cálculo usa el **costo efectivo por peso**:

**Costo efectivo anual = tasa anual + (cargos fijos mensuales evitables × 12 ÷ saldo)**

Ejemplo con la misma tarjeta pequeña, pero con una **comisión fija de $60 al mes** (equivale a 48 puntos más sobre $1,500, es decir, **86 % efectivo**, contra 45 % de la grande):

| Orden | Pequeña liquidada en el mes | Intereses | Cargos fijos | **Costo total** |
|---|---|---|---|---|
| Grande primero | 17 | $5,651 | $1,020 | **$6,671** |
| **Pequeña primero** | **3** | $5,594 | $180 | **$5,774** |

Aquí **sí conviene la pequeña primero** y el ahorro es de **≈ $897**. Si la comisión fuera de solo $20 al mes, el efectivo sería ≈ 54 %, que aún supera 45 %, y también ganaría la pequeña. **Regla:** va primero la deuda con mayor **costo efectivo**, no la de mayor tasa declarada.

**Cuidado: pagar el saldo no elimina el cargo; cerrar la cuenta sí.** La anualidad de **Azul BBVA** ($748 + IVA) o el cargo anual de **Costco Banamex** ($650) **siguen aunque el saldo sea cero**, y las tarjetas se conservan por sus beneficios (5.3 bis). Por eso la app **solo cuenta un cargo como evitable** si la persona marca **"cerrar la cuenta al liquidarla"**; si no, el cargo es un costo fijo que **no influye en el orden**, solo se reserva en el presupuesto.

**c) Otras razones para adelantar la pequeña** (se muestran como motivo, con su costo en pesos, y **no cambian el orden solas**):

| Motivo | Cómo lo trata la app |
|---|---|
| **Piso en el pago mínimo** (el banco exige un piso en pesos, aunque el saldo sea bajo) | Si el piso es alto frente al saldo, se cuenta como flujo atrapado; se prueba en la simulación |
| **Riesgo de atraso o beneficio por perder** (5.3 bis) | Se agrega al costo el valor del beneficio en riesgo, solo si el usuario lo marca |
| **Promoción que vence** (tasa baja que sube en una fecha) | La tasa efectiva cambia desde esa fecha y el orden se recalcula |
| **Uso del límite alto en la tarjeta pequeña** | Aviso informativo; no cambia el orden |
| **Cerrar para simplificar** | Opción **"cerrar pronto"** con su costo adicional ya calculado |

**d) Cómo decide el motor (prueba de la pequeña).** Después de ordenar por costo efectivo, para cada deuda con **saldo menor al extra de 8 semanas** (valor por defecto, editable) el motor compara dos simulaciones completas:

1. **Plan base:** orden por costo efectivo.
2. **Plan "cerrar la pequeña primero".**

| Resultado de la comparación | Qué hace la app |
|---|---|
| El plan de la pequeña **cuesta menos** (por ejemplo, por cargos fijos evitados) | Lo adopta como orden y explica por qué |
| Cuesta **más, pero la diferencia es pequeña** (menos de $300 o 1 % del costo total, el que sea mayor; por defecto) | Ofrece **"cerrar la pequeña primero por $X más"** como opción, **sin imponerla** |
| Cuesta **mucho más** | Mantiene el plan base y no la ofrece |

Con pocas deudas (hasta 6) el motor prueba **todas las combinaciones de orden** y se queda con la de menor costo total; con más, usa el orden por costo efectivo y la prueba de la pequeña.

**Lo que no se asume:** que la tasa estimada sea exacta, que la tarjeta no cambie condiciones, ni que el ingreso futuro sea fijo. Por eso el plan se **recalcula cada semana** con lo registrado de verdad.

### 5.4 INVERSIÓN *(propuesta, con decisión de alcance)*

> **Decisión:** por ahora el **seguimiento es manual** (el usuario captura aportaciones y valor actual). **Más adelante** se conectará con cuentas reales. El modelo de datos se diseña desde ya con "cuenta de inversión" para que esa conexión no obligue a rehacer nada.

**Para qué:** que el dinero **trabaje** para objetivos de mediano y largo plazo, una vez cubiertas las obligaciones y el fondo de emergencia. La app **no es una plataforma de inversión**: es el lugar donde se **planea y se da seguimiento** a lo aportado.

**Qué registra**

- Instrumentos (CETES, fondos, acciones/ETF, plan de retiro, bienes, negocio propio) como **cuentas de inversión** con su nombre y plazo.
- **Aportaciones** periódicas (semanal/quincenal/mensual) y su equivalente semanal.
- Valor actual (captura manual o periódica) y rendimiento estimado.
- Objetivo asociado (retiro, estudios de hijos, enganche) y horizonte.

**Reglas**

- **Orden de prioridad** (decisión del 15/oct/2026, ver 5.4 bis y 5.5 bis): 1) gastos esenciales, 2) pagos obligatorios de deuda, 3) **deuda con costo** y préstamos familiares, 4) fondo de emergencia, reservas y metas con fecha, 5) inversión.
- Si el usuario tiene deudas con tasa alta, la app advierte que pagar esa deuda suele rendir más que invertir.
- Mostrar aportación acumulada vs. valor actual y **% de avance hacia el objetivo**.

**Pantallas:** lista de cuentas de inversión, alta de aportación planeada, avance por objetivo.

**Se conecta con:** Presupuesto (partida "inversión"), Objetivos.

### 5.4 bis INVERSIÓN A DETALLE

**Para qué:** que el dinero que ya cubrió deudas, colchón y metas con fecha **trabaje a largo plazo**, y que el hogar vea **cuánto aportó, cuánto vale hoy y si va rumbo a su objetivo**. La app **no vende ni recomienda productos**: registra, calcula y avisa riesgos.

**1. Cuándo se activa (la "puerta" de la inversión)**

La inversión **sigue el orden ya decidido** (primero deuda, después ahorro; 5.3, 5.5 y 5.6 bis). El asistente solo propone aportar cuando se cumplen estas cuatro condiciones:

| # | Condición | Si no se cumple |
|---|---|---|
| 1 | **Sin deuda con costo** y sin préstamos familiares pendientes (los MSI no cuentan, 5.3 bis) | El remanente va a deuda (5.6 bis) |
| 2 | **Fondo de emergencia completo** a la meta elegida (**3 meses por defecto, confirmado el 17/oct/2026**, ampliable a 6 meses o 1 año; 5.5 bis) | El remanente va al fondo |
| 3 | **Reservas y metas con fecha** al corriente (5.5 bis) y la **cuenta de previsión** fondeada (5.6 ter) | Tienen prioridad sobre la inversión |
| 4 | El objetivo de la inversión tiene **horizonte** (cuándo se necesitará el dinero) | Se pide antes de crear la cuenta |

La persona puede **forzar una aportación** aunque no se cumplan; la app muestra el costo (por ejemplo, "esta deuda cuesta 45 % al año") y lo **registra en la bitácora**. No bloquea: **informa**.

**2. Tipos de cuenta de inversión**

| Tipo | Ejemplos | Qué se captura de más |
|---|---|---|
| **Renta fija** | CETES y otros valores de deuda, pagarés | Plazo, tasa pactada, fecha de vencimiento |
| **Fondos** | Fondos de deuda o de inversión | Comisión anual, días para retirar |
| **Renta variable** | Acciones, ETF | Instrumento, número de títulos |
| **Retiro** | Aportaciones voluntarias a Afore, planes de retiro | Titular, condiciones de retiro (**verificar con fuente oficial** los beneficios fiscales; la app no los asume) |
| **Bienes** | Terreno, equipo de trabajo (los bienes de uso, como el vehículo y la casa, están en 5.6 quater) | Valor estimado y fecha del avalúo |
| **Negocio propio** | Capital puesto en un negocio | Aportaciones y retiros del negocio |
| **Otro** | Cualquier instrumento no listado | Descripción libre |

**3. Datos por cuenta de inversión**

Nombre, institución, tipo, moneda (MXN por ahora), fecha de apertura, **plazo**, **liquidez** (días para tener el dinero), **riesgo** (bajo, medio o alto, elegido por la persona), titular o **propietarios** (individual o compartida), **objetivo asociado**, aportaciones (con fecha y origen), **valor actual con su fecha de captura**, comisiones e impuestos que se paguen, y notas. **Ningún dato es obligatorio salvo nombre, tipo y objetivo**: se puede empezar con poco y completarlo después.

**4. Cómo se trata en la contabilidad (5.0 bis 2)**

- Una **aportación** es un traslado **de activo a activo** (de la cuenta bancaria a la cuenta de inversión). **No es gasto ni pago de deuda**: no baja el remanente por segunda vez.
- Un **rendimiento** que se retira o se paga es **ingreso financiero**. El **cambio de valor sin retirar** se muestra como **ajuste de valuación** y solo mueve el patrimonio; **no entra al presupuesto semanal** (no se gasta lo que aún no se retira).
- **Comisiones e impuestos** son gasto financiero.
- Un **retiro** regresa dinero a una cuenta; la parte que excede lo aportado es rendimiento.

**5. Cálculos**

| Cálculo | Fórmula o regla |
|---|---|
| **Aportado** | Suma de aportaciones menos retiros del capital |
| **Ganancia o pérdida** | Valor actual − aportado |
| **Rendimiento anualizado estimado** | Con las **fechas** de cada aportación (rendimiento ponderado en el tiempo); se rotula "estimado" |
| **Avance al objetivo** | Valor actual ÷ monto del objetivo |
| **Proyección** | Con aportación semanal y **rendimiento anual supuesto que escribe la persona** (la app **no trae tasas por defecto**) y una **inflación supuesta** opcional para ver el resultado en pesos de hoy |
| **Valor viejo** | Si el valor no se actualiza en **35 días** (por defecto), se marca "por actualizar" y no se usa para decir que va bien o mal |

**Ejemplo ilustrativo** (los supuestos son de ejemplo, **no un pronóstico ni una recomendación**): aportación de **$300 por semana**, rendimiento anual supuesto de **8 %**, inflación supuesta de **4 %**.

| Años | Aportado | Valor proyectado | En pesos de hoy (aprox.) |
|---|---|---|---|
| 1 | $15,600 | ≈ $16,228 | — |
| 3 | $46,800 | ≈ $52,848 | — |
| 5 | $78,000 | ≈ $95,816 | ≈ $85,970 |
| 10 | $156,000 | ≈ $238,714 | — |

La pantalla muestra siempre **tres escenarios que escribe la persona** (por ejemplo, 4 %, 8 % y 0 %) y el escenario de **0 %** como piso, para que se vea que el resultado **puede ser menor**.

**6. Reglas de seguridad y avisos**

1. **Sin promesas:** nunca dice que un rendimiento está garantizado; todo lo proyectado se rotula "supuesto".
2. **Horizonte contra riesgo:** si el objetivo es en **menos de un año** y la cuenta es de **riesgo alto**, aparece un aviso.
3. **Liquidez contra fecha:** si el dinero tarda más en liberarse que lo que falta para el objetivo, aviso.
4. **Concentración:** si una sola cuenta tiene **más de la mitad** del total invertido, aviso informativo.
5. **El fondo de emergencia no se invierte** en cuentas de riesgo medio o alto; si la persona lo hace, queda registrado y se avisa.
6. **No conecta con la banca** por ahora (5.3); la conexión futura queda lista en el modelo de datos (7).
7. La app **no es asesoría financiera**; lo dice donde se muestran las proyecciones.

**7. Pareja y familia**

Cuentas **individuales o compartidas**, con transparencia total (5.0 bis); el **portafolio del hogar** suma todas y muestra la parte de cada miembro. Para hijos, la cuenta tiene **titular menor de edad** y objetivo "estudios", y no cuenta como patrimonio libre del adulto. Un retiro de una cuenta compartida **pide confirmación** del resto de los titulares (5.0 ter).

**8. Pantallas:** lista de cuentas con valor y avance, ficha de cuenta (gráfica aportado contra valor), alta de aportación planeada, proyección con tres escenarios, "puerta de inversión" (qué condiciones faltan) y portafolio del hogar.

**9. Datos nuevos:** `CuentaInversion`, `AportacionInversion`, `ValorInversion` (valor y fecha de captura), `RetiroInversion` y `SupuestoProyeccion` (rendimiento e inflación escritos por la persona).

**10. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| I1 | Hay una tarjeta con interés | La app propone pagarla; no propone invertir |
| I2 | Sin deuda y con el fondo de emergencia incompleto | Propone completar el fondo |
| I3 | Aportar $300 por semana con 8 % supuesto, 5 años | Valor proyectado ≈ $95,816; aportado $78,000 |
| I4 | Mismo caso con 0 % | Valor igual a lo aportado ($78,000) |
| I5 | Valor sin actualizar por 40 días | Se marca "por actualizar" y no se juzga el rendimiento |
| I6 | Objetivo en 6 meses con cuenta de riesgo alto | Aviso de horizonte |
| I7 | Aportación forzada con deuda cara | Se permite, muestra el costo y queda en la bitácora |
| I8 | Retiro de cuenta compartida | Pide confirmación de los otros titulares |

### 5.5 AHORRO *(propuesta, con decisión de alcance)*

> **Decisión:** la app ofrece **varios métodos de ahorro**. El flujo es: **1) se crea la cuenta de ahorro → 2) se define el método → 3) se configuran sus parámetros → 4) se ve la proyección → 5) se activa.** Una misma cuenta puede combinar métodos (ej. fondo de emergencia = monto fijo + porcentaje de extras).

**Métodos de ahorro disponibles**

| Método | Cómo funciona | Ideal para |
|---|---|---|
| **Págate primero (% del ingreso)** *(opcional)* | Al llegar un ingreso se aparta un porcentaje (ej. 10%) antes de gastar | Ingresos regulares |
| **Monto fijo semanal** | Una cantidad constante cada semana | Hábito sencillo |
| **Meta con fecha** | Se define meta y fecha; la app calcula `(meta − saldo) ÷ semanas restantes` | Compras o viajes |
| **Reto de 52 semanas** | Aportación creciente (semana 1 = $X, semana 2 = 2X…) | Motivación y constancia |
| **Redondeo** | Cada gasto se redondea (ej. $47 → $50) y la diferencia se aparta | Ahorro "sin sentirlo" |
| **Sobrante semanal** | Lo que no se gastó del presupuesto de la semana pasa a ahorro | Semanas variables |
| **Sobre por categoría** | Lo no gastado de una categoría (ej. entretenimiento) se aparta | Ahorro por recorte |
| **Porcentaje de extras** | Un % de bonos, aguinaldo o ingresos eventuales | Ingresos irregulares |

**Pasos del asistente "Nueva cuenta de ahorro":** nombre y propósito → tipo de bolsa (emergencia, reserva, meta) → ¿individual o compartida? → método(s) → parámetros → proyección ("llegarás a $X el día Y") → activar.

**Seguimiento (por ahora manual):** cada semana la app indica "debes apartar $X"; el usuario **confirma** la aportación (queda en el libro de movimientos) o la pospone y se acumula como pendiente.

**Para qué:** crear colchones y apartar dinero con propósito. Es lo que le da **tranquilidad** al hogar y absorbe los imprevistos.

**Tipos de bolsa de ahorro**

| Bolsa | Propósito |
|---|---|
| **Fondo de emergencia** | 3–6 meses de gastos esenciales (la app calcula la meta con los gastos reales) |
| **Reservas** | Gastos grandes previsibles: seguro anual, regreso a clases, predial, vacaciones, regalos |
| **Metas** | Compras con fecha: celular, enganche, viaje |

**Datos por bolsa:** nombre, meta ($), fecha objetivo, saldo actual, aportación semanal sugerida, ¿compartida?

**Reglas**

- **Aportación sugerida** = (meta − saldo) ÷ semanas restantes.
- **Método por defecto: remanente, después de pagar la deuda (decisión del 15/oct/2026).** El ahorro es lo que sobra después del presupuesto y de la deuda, y **empieza cuando ya no hay deuda con costo ni préstamos familiares** (las compras a MSI no cuentan: no se adelantan); mientras la haya, el remanente se usa como **abono extra** (5.6 bis). La **meta es que el remanente llegue a 20 % del ingreso**. Si el usuario quiere apartar algo mientras paga, configura un **ahorro mínimo con deuda** (por defecto 0 %). *Págate primero* y los demás métodos siguen disponibles como opción por cuenta de ahorro.
- Los **extras** proponen enviar un porcentaje a ahorro automáticamente.
- Retirar de una bolsa pide confirmar el motivo (y se registra).

**Pantallas:** bolsas con barra de progreso, "¿cuánto debo apartar esta semana?", historial de aportaciones.

**Se conecta con:** Presupuesto (partida "ahorro"), Gastos (reservas se consumen al pagar el gasto grande), Objetivos.

### 5.5 bis AHORRO A DETALLE

**Para qué:** que el remanente que ya no necesita pagar deuda se reparta **con orden y con propósito**, y que el hogar sepa **cuánto colchón tiene en semanas de vida**, no solo en pesos.

**1. Dónde entra el ahorro en la cascada**

INGRESO → PRESUPUESTO → DEUDA → **remanente** (5.6 bis). Con deuda con costo, **todo el remanente va a deuda** (decisión del 15/oct/2026). Cuando ya no hay deuda con costo ni préstamos familiares, el remanente **se reparte entre las bolsas de ahorro** con las reglas de abajo. El método "págate primero" queda **desactivado mientras haya deuda con costo**.

**Gastos anuales conocidos (decisión del 17/oct/2026):** el **refrendo, el predial, el agua potable y el seguro** **no son ahorro**: son **gastos previsibles** que se apartan **dentro del presupuesto** en la **cuenta de previsión** (5.6 ter), **desde el primer día y también mientras haya deuda**. Las **reservas de ahorro** de este capítulo son para gastos **deseados o con fecha elegida** (vacaciones, regalos, regreso a clases).

**2. Fondo de emergencia por niveles**

La meta se calcula con los **gastos esenciales reales** (promedio de las últimas 8 semanas, incluyendo los **gastos protegidos** como renta, servicios y cuidados, 5.6 bis) y se llena **por niveles**:

| Nivel | Cubre | Para qué |
|---|---|---|
| **1. Colchón** | 2 semanas de gastos esenciales | Un imprevisto chico sin endeudarse |
| **2. Mes** | 4 semanas | Un mes sin ingreso extra |
| **3. Tres meses** *(meta por defecto)* | 13 semanas | Una pérdida de empleo corta |
| **4. Seis meses** | 26 semanas | Hogares de **un solo ingreso**, con dependientes o ingresos variables |
| **5. Un año** | 52 semanas | Ingreso muy variable, negocio propio u obligaciones de largo plazo |

**Confirmado el 17/oct/2026:** la meta es de **3 meses** y es **ampliable a 6 meses y a 1 año**. La app **sugiere** el nivel 4 si hay un solo ingreso, ingresos variables o **dependientes con cuidados permanentes** (por ejemplo, un familiar con cuidados de largo plazo, 5.2); la persona decide. El colchón se compara con el gasto esencial: la pantalla dice **"tienes X semanas cubiertas"**.

**3. Reservas, metas y su orden**

| Bolsa | Aportación semanal | Ejemplo |
|---|---|---|
| **Reserva** (gasto deseado con fecha) | Monto anual ÷ 52 | Vacaciones y regalos de $5,200 → **$100**; regreso a clases de $7,800 → **$150** |
| **Meta con fecha** | (meta − saldo) ÷ semanas restantes | Celular de $9,000 en 30 semanas con $1,500 ya reunidos → **$250** |
| **Meta sin fecha** | La persona fija un monto o un porcentaje | Viaje, mejora del hogar |
| **Fondo de emergencia** | Lo que falta para el nivel elegido, repartido en el tiempo que quede | Ver el ejemplo |

**Orden por defecto del reparto** (se puede cambiar):

1. **Fondo de emergencia, nivel 1.**
2. **Reservas** (siempre que ya estén como bolsa).
3. **Metas con fecha** (solo lo necesario para llegar a tiempo).
4. **Fondo de emergencia hasta la meta elegida.**
5. **Metas sin fecha e inversión** (5.4 bis).

**4. Ejemplo con el remanente de 5.6 bis**

Remanente de **$1,520 por semana**; esenciales de **$3,500 por semana** (supuesto de ejemplo); reservas de **$250 por semana** (las dos de arriba); el refrendo, el predial, el agua y el seguro **ya están dentro del presupuesto** (5.6 ter); celular de **$9,000** en 30 semanas; meta de emergencia de **3 meses = $45,500** (13 semanas de esenciales) y colchón de **$7,000**.

| Hito (semanas de ahorro) | Qué pasa | Semana global (ahorro empieza en la 6) |
|---|---|---|
| Semanas 1 a 4 | Todo va al **colchón** ($6,080) | 6 a 9 |
| Semana 5 | Se completa el colchón ($7,000) y se arranca con reservas y celular | 10 |
| Después | Reservas $250 + celular $250 + **fondo $1,020** por semana | — |
| **Semana 34** | **Celular** completo | 39 |
| **Semana 41** | **Fondo de emergencia** completo ($45,500) | 46 |

A partir de la semana 41 de ahorro, esos $1,020 pasan al orden 5 (inversión y metas sin fecha).

**¿Y si el celular se quiere en 12 semanas?** Requiere **$625 por semana** en vez de $250. El plan lo muestra con su costo:

| | Celular completo | Fondo completo | Fondo en la semana 17 de ahorro |
|---|---|---|---|
| Plan base ($250 por semana, 30 semanas) | Semana 34 | Semana 41 | **$19,340** |
| Celular en 12 semanas ($625 por semana) | Semana 17 | Semana 41 | **$15,090** |

El fondo queda completo **en la misma semana**, pero durante varias semanas hay **$4,250 menos de colchón**. Acelerar una meta **no retrasa el total**: **retrasa las otras** y baja el colchón en el camino. La app lo explica así.

**5. Métodos y cómo se combinan**

- Cada bolsa puede combinar varios métodos (5.5), pero **la suma de aportaciones sugeridas no puede pasar del remanente disponible**; si pasa, se aplica el orden del punto 3.
- Los métodos "redondeo", "sobrante semanal" y "sobre por categoría" **alimentan la misma bolsa** y se **descuentan** de la aportación sugerida para no apartar dos veces.
- **Reto de 52 semanas:** si el remanente no alcanza una semana, la app lo marca **"pospuesto"** y deja ponerse al corriente; no lo da por fallado.

**6. Confirmación semanal y atrasos**

Cada semana la app propone el reparto y la persona **confirma**. Si el remanente real es menor, **recorta de abajo hacia arriba** del orden (primero las metas sin fecha, al final el colchón). Lo no aportado queda como **pendiente por bolsa**, **sin intereses ni castigo**, con opciones: recuperarlo en varias semanas, mover la fecha o bajar la meta.

**7. Retiros**

| Tipo | Qué pide la app |
|---|---|
| **Uso previsto** (se paga el seguro con su reserva) | Elegir el gasto; se registra y la bolsa baja |
| **Emergencia** (se usa el fondo) | Motivo; al retirar, la app **recalcula el plan para reponerlo** primero |
| **Cambio de destino** | Motivo y confirmación; queda en la bitácora |

En **bolsas compartidas**, un retiro pide **confirmación del resto de los titulares** (5.0 ter).

**8. Ahorro contra deuda**

Si hay **deuda con costo**, la app **no** propone aportaciones nuevas a ahorro: todo el remanente va a deuda (decisión del 15/oct/2026; el ahorro mínimo con deuda es 0 %). Si ya hay ahorro y existe una deuda cara, el simulador de 5.3 ter compara el **rendimiento del ahorro** (si la persona lo captura) con la **tasa de la deuda** y sugiere usar lo que **supera el colchón mínimo**.

**9. Pantallas:** tablero de bolsas con "semanas cubiertas", plan semanal con el reparto, asistente de reparto con "¿y si…?", pendientes por bolsa, historial de retiros y reposición.

**10. Datos nuevos:** `BolsaAhorro` (tipo, meta, fecha, prioridad, propietarios), `AportacionAhorro` (semana, bolsa, monto, confirmada o pendiente), `RetiroAhorro` (tipo, motivo, confirmaciones), `NivelEmergencia` y `ReservaGastoAnual` (gasto anual, fecha, semanas restantes).

**11. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| A1 | Remanente de $1,520, esenciales de $3,500 y las bolsas del ejemplo | Colchón completo en la semana 5 de ahorro; celular en la 34; fondo en la 41 |
| A2 | Pedir el celular en 12 semanas | Aporta $625; fondo igual en la semana 41 con $15,090 en la semana 17 |
| A3 | Remanente menor al sugerido | Recorta de abajo hacia arriba y deja pendiente sin castigo |
| A4 | Retiro de emergencia | Pide motivo y recalcula la reposición del fondo |
| A5 | Regreso a clases de $7,800 | Aparta $150 por semana |
| A6 | Meta con fecha y saldo de $1,500 de $9,000 en 30 semanas | Aporta $250 por semana |
| A7 | Hay deuda con costo | No se proponen aportaciones nuevas a ahorro; todo el remanente va a deuda |
| A8 | Retiro de bolsa compartida | Pide confirmación de los demás titulares |

### 5.6 PRESUPUESTO SEMANAL (motor de la app)

**Para qué:** convertir todo lo anterior en un **plan ejecutable**: cuánto se asigna a cada concepto esta semana.

**Cómo se arma (en pasos)**

1. **Ingreso de la semana** = ingresos seguros y probables (vista devengada o de flujo).
2. **Presupuesto (egreso tipo 1):** gastos fijos (renta, servicios), variables (alimentación, transporte, salud, discrecionales) y reservas de pagos grandes.
3. **Deuda (egreso tipo 2):** abonos planeados a deudas, antes de ahorrar.
4. **Remanente:** lo que sobra de ingreso − presupuesto − deuda; la meta es **20 % del ingreso**. **Primero paga deuda extra; cuando ya no hay deuda, va a ahorro (activo).**
5. **Si me salgo del presupuesto:** baja primero el remanente (abono extra o ahorro); si se pasa más, baja el abono planeado a la deuda y esta puede crecer. Detalle y ejemplo en 5.6 bis.

**Métodos de presupuesto soportados** (el usuario elige uno como base)

| Método | Idea |
|---|---|
| **Por categorías (sobres)** | Monto fijo por categoría y semana |
| **50/30/20 adaptado** | 50% necesidades, 30% deseos, 20% ahorro/deuda (porcentajes editables) |
| **Base cero** | Cada peso tiene un destino; ingreso − asignado = 0 |
| **Por objetivo** | Se parte de la meta y se calcula cuánto debe asignarse |

**Niveles:** Individual → (Yo) · Pareja → (Yo / Tú / Nosotros) · Familiar → (Hogar / cada adulto / dependientes). Cada **cuenta de gasto** del hogar (por rubro) recibe su monto semanal y los miembros aportan a ella con sus compras o transferencias; el presupuesto muestra cuánto va gastado y quién aportó.

**Reglas**

- Cada partida muestra: `asignado`, `gastado`, `restante`, `% usado` con semáforo.
- **Arrastre (rollover) configurable:** lo que sobra en una categoría puede pasar a la siguiente semana, al ahorro, o perderse.
- **Revisión semanal:** al cierre, la app compara plan vs. real y propone ajustar la siguiente semana.
- Si un ingreso se retrasa, el presupuesto se **recalcula** y se priorizan las partidas por importancia.

**Pantallas:** presupuesto de la semana (resumen + partidas), asistente de armado paso a paso, comparativo plan vs. real, calendario de flujo.

### 5.6 bis MOTOR DE PRESUPUESTO SEMANAL A DETALLE

> **Actualización de la versión 10 (decisiones del 15/oct/2026):** la semana inicia en **lunes**; cada miembro configura **su forma de ingreso y su día de pago** y la app presenta los datos en ese periodo; si un pago cae en **fin de semana pasa al lunes**; y el dinero se **dispersa en cascada: INGRESO → PRESUPUESTO → DEUDA → remanente**, que **primero paga deuda y, cuando ya no hay deuda, va a AHORRO** (versión 11). Esta versión reemplaza el modelo "págate primero" de la versión 9. Los montos del ejemplo son **ilustrativos**, en MXN.

**1. La cascada: cómo se dispersa el dinero**

```text
INGRESO
  − PRESUPUESTO   (egreso tipo 1: gastos, incluye fijos, variables y reservas)
  − DEUDA         (egreso tipo 2: abonos planeados a deudas)
  = REMANENTE
        ├─ mientras haya deuda con costo (y después préstamos familiares)  →  ABONO EXTRA (5.3)
        └─ si no, o solo quedan MSI  →  AHORRO (activo), hasta la meta
```

| Paso | Qué es | Naturaleza contable (ver 5.0 bis 2) |
|---|---|---|
| **Ingreso** | Lo que entra, por miembro y por fecha | Ingreso |
| **Presupuesto** | Lo que se gasta: compromisos fijos, variables y reservas de pagos grandes | **Egreso tipo 1: Gasto** |
| **Deuda** | Abonos planeados a deudas, **incluidas las mensualidades de MSI** (capital; los intereses y cargos cuentan como gasto financiero) | **Egreso tipo 2: Pago de deuda** (baja un pasivo) |
| **Remanente** | Lo que queda; mientras haya deuda es **abono extra** y, sin deuda, **ahorro** | Egreso tipo 2 (con deuda) o **Activo** (sin deuda) |

Idea de fondo: **primero se paga la deuda y después se ahorra**; ahorro y abonos extra son **lo que sobra después de vivir**, no un pago adelantado. Por eso, **si el gasto real se pasa del presupuesto, primero se reduce el remanente (el abono extra o el ahorro); si se pasa más, se reduce el abono planeado a la deuda** (y la deuda puede crecer). Ver el punto 6.

**2. Qué es "una semana" y cómo se ven los periodos de pago**

| Regla | Definición |
|---|---|
| Inicio de semana | **Lunes** (configurable por hogar) |
| Pertenencia | Cada movimiento pertenece a la semana de su **fecha**, no de cuándo se capturó |
| Pago en **fin de semana o festivo** | **Pasa al siguiente día hábil** (el lunes, si cae en sábado o domingo); regla del usuario, configurable por ingreso. Los festivos salen de un **calendario de días inhábiles** editable (5.1) |
| Quincena | Días fijos que configura el miembro (por defecto **15 y último día del mes**) |
| Catorcena | Cada 14 días desde una **fecha ancla** que fija el miembro |
| Extras | **Cualquier día**; se registran con su fecha real y cuentan en la semana en que llegan |
| **Periodo de visualización** | Cada miembro elige cómo ver sus datos: **semana, catorcena, quincena o mes** (ver 5.1); el hogar tiene además una vista base semanal |

**Cómo se calcula cada vista** (presupuesto y gasto real)

| Vista | Presupuesto del periodo | Gasto y flujo real |
|---|---|---|
| Semana | Presupuesto semanal | Movimientos con fecha de lunes a domingo |
| Catorcena | Semanal × 2 | Movimientos de esos 14 días |
| Quincena | Semanal × 52 ÷ 24 | Movimientos entre las fechas de la quincena |
| Mes | Semanal × 52 ÷ 12 | Movimientos del mes natural |

El **presupuesto** se prorratea con esos factores (los mismos de la sección 4); el **gasto y el flujo reales** salen siempre de las **fechas de los movimientos**, así que no dependen de que las semanas coincidan con el mes.

**3. Entradas del motor**

| Entrada | De dónde viene | Cómo cuenta |
|---|---|---|
| Ingresos | 5.1 | Solo `segura` y `probable`; la `incierta` se muestra aparte como potencial |
| Presupuesto fijo | 5.2 (gastos fijos) | Se convierte en **ocurrencias** con fecha |
| Presupuesto variable | Cuentas de gasto por rubro | Monto semanal por rubro (sobres) |
| Reservas | Pagos grandes futuros | Se aparta un monto semanal hasta el vencimiento; cuentan como **presupuesto** |
| Deuda | 5.3 | Abono planeado por deuda, con su fecha |
| Meta de remanente | 5.5 | **20 % del ingreso** (configurable); es una **meta**, no un apartado previo; su destino es **deuda primero, ahorro después** |
| Sobrantes de semanas anteriores | Cierre semanal | Según la regla de arrastre |

**4. Algoritmo (en el orden en que se calcula)**

1. **Ocurrencias:** de cada ingreso y compromiso recurrente se generan las fechas de las próximas **13 semanas**, aplicando la regla de fin de semana, y se actualizan al cambiar algo.
2. **Ingreso devengado** = Σ equivalentes semanales de ingresos seguros y probables (sección 4 del documento).
3. **Presupuesto** = Σ gastos fijos + Σ asignado a variables + Σ reservas.
4. **Deuda planeada** = Σ equivalentes semanales de los abonos.
5. **Remanente planeado** = ingreso − presupuesto − deuda planeada.
6. **Destino del remanente:** (a) mientras exista deuda **con costo** (y después préstamos familiares), es **abono extra** según la prioridad de 5.3; las compras a **MSI** no reciben extra; (b) cuando ya no hay deuda, va a **ahorro** hasta la meta, y el excedente queda libre o se propone para objetivos (5.7). Con un **ahorro mínimo con deuda** configurable (por defecto 0 %), una parte va a ahorro desde el inicio.
7. **Techo de presupuesto** (ayuda para armar el plan) = ingreso − deuda planeada − **meta de remanente (20 %)**. Si el presupuesto está bajo el techo, la meta se cumple.
8. **Remanente real** al cierre = ingreso real − gasto real − abono planeado real. Se aplica según el punto 6 o se absorbe el sobregasto (punto 6 del documento, "Si me salgo del presupuesto").
9. **Vista de flujo:** con las mismas ocurrencias, en su **fecha real**, calcula entradas, salidas y **saldo proyectado** de las cuentas por semana.
10. **Alerta de flujo:** si el saldo proyectado de alguna semana baja de cero (o del mínimo configurable), avisa con anticipación.

**5. Ejemplo con números (hogar de Ana y Alex)**

| Concepto | Monto y frecuencia | Equivalente semanal |
|---|---|---|
| Ingreso: sueldo de Ana (neto) | $9,000 quincenal | $4,153.85 |
| Ingreso: sueldo de Alex (neto) | $14,000 mensual | $3,230.77 |
| **INGRESO semanal** | | **$7,384.62** |
| Renta | $8,000 mensual | $1,846.15 |
| Luz | $900 bimestral | $103.85 |
| Agua | $300 mensual | $69.23 |
| Internet | $400 mensual | $92.31 |
| Celular | $350 mensual | $80.77 |
| Reserva: placas y predial | $1,560 anual | $30.00 |
| Variables: Alimentación $1,500 · Transporte $700 · Salud $300 · Limpieza $150 · Cuidado personal $150 · Entretenimiento $250 · Vestimenta $200 | | $3,250.00 |
| **PRESUPUESTO (egreso tipo 1)** | | **$5,472.31** |
| Tarjeta de crédito (abono acordado; saldo $6,000, tasa 48 % anual) | $1,200 mensual | $276.92 |
| Préstamo familiar (sin interés; saldo $3,000) | $500 mensual | $115.38 |
| **DEUDA (egreso tipo 2)** | | **$392.31** |
| **REMANENTE → abono extra a deuda** (ahorro cuando ya no hay deuda) | 7,384.62 − 5,472.31 − 392.31 | **$1,520.00 (20.6 % del ingreso)** |

- **Meta de remanente:** 20 % de $7,384.62 = **$1,476.92**. El plan la supera por **$43.08**.
- **Techo de presupuesto:** 7,384.62 − 392.31 − 1,476.92 = **$5,515.39**; el presupuesto armado ($5,472.31) queda por debajo.
- **Resultado del periodo** (ingreso − gasto) = **$1,912.31** (25.9 %). Se reparte entre el **capital pagado de deuda** (baja un pasivo) y, cuando ya no hay deuda, el **ahorro** (sube un activo): **las dos cosas aumentan el patrimonio**.
- **Mientras haya deuda, el remanente la paga:** los $1,520.00 semanales se aplican como **abono extra**, primero a la **tarjeta** (la de mayor costo) y al final al **préstamo familiar**.

**Salida de deuda del ejemplo** (ilustrativa; interés semanal simple = saldo × 48 % ÷ 52):

| Semana | Saldo de la tarjeta | Saldo del préstamo familiar | Ahorro de la semana |
|---|---|---|---|
| Inicio | $6,000.00 | $3,000.00 | — |
| 1 | $4,258.46 | $2,884.62 | $0 |
| 2 | $2,500.85 | $2,769.24 | $0 |
| 3 | $727.02 | $2,653.86 | $0 |
| 4 | $0 | $1,475.29 | $0 |
| 5 | $0 | $0 | $160.09 |
| 6 en adelante | $0 | $0 | $1,520.00 por semana (20.6 %) |

En unas **cinco semanas** se sale de deuda y **desde la sexta el ahorro supera la meta de 20 %**. Intereses pagados en ese lapso: unos **$124.49** (estimación del ejemplo).

**Equivalencias por periodo** (mismo ejemplo): ingreso quincenal $16,000.00, catorcenal $14,769.23 y mensual $32,000.00; presupuesto quincenal $11,856.67, catorcenal $10,944.62 y mensual $23,713.34.

**La misma familia en la vista de flujo** (semanas del 26/oct al 8/nov/2026, regla "fin de semana pasa al lunes"):

| Fecha | Evento | Monto |
|---|---|---|
| Sáb 31/oct → **lun 2/nov** | Quincena de Ana (último día del mes) | +$9,000 |
| Sáb 31/oct → **lun 2/nov** | Sueldo de Alex (último día del mes) | +$14,000 |
| Dom 1/nov | Renta | −$8,000 |

Semana del 26/oct al 1/nov: **entra $0** y sale la renta; el saldo de las cuentas debe cubrir **$8,000 más los gastos de la semana** antes del lunes. Semana del 2 al 8/nov: **entran $23,000**. El equivalente semanal ($7,384.62) no muestra esto; por eso la alerta de flujo avisa **con anticipación**. Otro caso: la quincena del **domingo 15/nov** se paga el **lunes 16/nov**.

**6. Si me salgo del presupuesto (regla de sobregasto)**

Con el plan del ejemplo (remanente planeado $1,520.00, que mientras haya deuda es abono extra; abono planeado $392.31):

| Sobregasto del presupuesto | Remanente (abono extra, o ahorro sin deuda) | Abono planeado a deuda | Qué pasa |
|---|---|---|---|
| Ninguno | $1,520.00 (20.6 %) | $392.31 | Se cumple el plan |
| **$300** | **$1,220.00** (16.5 %) | $392.31 | **Remanente menos** (abono extra o ahorro) |
| **$1,800** | $0 | **$112.31** | Se agota el remanente y **abono menos a la deuda**; los **$280.00** no abonados quedan como **abono diferido** |
| **$2,000** | $0 | $0 | Se agota el remanente, no se abona y faltan **$87.69**: es un **déficit** que se cubre con saldo de cuentas o con **nueva deuda** |

Reglas:

1. **Orden de absorción:** primero el **remanente** (abono extra o ahorro), luego el **abono planeado a deuda**, luego el **déficit**.
2. Lo no abonado **no reduce el saldo** de la deuda. La deuda **crece** solo por **intereses y cargos** (tarjetas y créditos, capturados de su estado de cuenta) o porque el déficit se cubrió con **crédito**; en **préstamos entre familiares (sin interés)** el saldo **no crece**, solo se retrasa.
3. **Qué abono se reduce primero** (decisión del usuario): primero los **préstamos familiares** (siempre los últimos en pagarse); entre tarjetas y créditos, los de **menor costo por peso**; los **pagos mínimos** se protegen hasta el final.
4. **Alerta de pago mínimo:** si el abono real a una tarjeta o crédito queda **por debajo del mínimo exigible**, la app avisa con color rojo, porque puede generar cargos.
5. Los gastos **protegidos** (renta, servicios y **cuidados de largo plazo y paliativos**) **nunca** se recortan automáticamente; la app **propone** recortes en lo discrecional y el usuario decide.
6. La app **no mueve dinero sola**: propone y el usuario confirma.

**7. Meta de 20 % y regla "primero la deuda, después el ahorro"** *(confirmada el 15/oct/2026)*

1. **Pagos mínimos** y abonos acordados de todas las deudas, siempre.
2. **Remanente → abono extra** a la deuda **con costo** de **mayor tasa efectiva** (declarada o estimada), según 5.3. Después, a los **préstamos familiares** (sin interés), que quedan al final.
3. **Cuando ya no hay deuda con costo ni préstamos familiares**, el remanente va a **ahorro** hasta la meta de **20 % del ingreso**; lo que exceda se propone para objetivos (5.7) o queda libre. Las compras a **meses sin intereses (MSI)** **no bloquean el ahorro**: se pagan en sus mensualidades y no reciben extra.
4. **Ahorro mínimo con deuda:** parámetro del hogar, **0 % por defecto** (todo el remanente paga deuda; **confirmado el 15/oct/2026**). Si el usuario quiere apartar algo mientras paga, lo configura.
5. **Deuda nueva:** el ahorro ya acumulado **no se toca**; el remanente vuelve a pagar deuda.
6. La app **propone y el usuario confirma**; nunca mueve dinero sola.

**Indicadores:** *tasa de remanente* (remanente ÷ ingreso, meta 20 %), *tasa de ahorro* (ahorro ÷ ingreso), *tasa de patrimonio* (resultado ÷ ingreso, incluye el capital pagado) y **semanas para salir de deuda** (con el simulador de 5.3).

**8. Cierre semanal, arrastre y ajustes**

| Tema | Regla *(por defecto)* |
|---|---|
| Estados de la semana | `borrador` → `activa` → `por cerrar` → `cerrada` |
| Cuándo se cierra | El **lunes** al abrir la app, o con *Cerrar semana*; se puede reabrir con confirmación y queda en la bitácora |
| Sobrante de una cuenta de gasto | Pasa a la semana siguiente hasta **2 semanas** de su monto; el exceso va al remanente |
| Remanente de la semana | Se **propone** aplicarlo según el punto 7 (primero abono extra a deuda; ahorro cuando ya no hay deuda); el usuario confirma. Al confirmar se crea un movimiento de la cuenta a la de ahorro o a la deuda |
| Cambios al plan a mitad de semana | Solo afectan **de ahí en adelante**; lo ya gastado no se reescribe |
| Correcciones a semanas cerradas | Con **anulación y contraasiento** (5.0 bis); no se edita el movimiento original |
| Ingreso retrasado | La semana pasa a `pendiente de ingreso`; se recalcula con lo que sí hay y se activa la alerta de flujo |

**9. Asistente de arranque (5 pasos, unos 5 minutos)**

| Paso | Qué se pide | Qué se puede omitir |
|---|---|---|
| 1. Hogar | Modo (Individual / Pareja / Familiar), nombres, inicio de semana (lunes) | Foto, color |
| 2. Ingresos | Por miembro: **forma de ingreso** (semanal, catorcenal, quincenal, mensual), **día de pago**, monto neto y periodo en que quiere ver sus datos | Certeza (se asume `segura`) |
| 3. Compromisos | Renta, servicios y **deudas** con monto, frecuencia y fecha | Detalle por servicio |
| 4. Meta | **Meta de remanente (20 %)**, la regla *primero deuda, después ahorro* y la prioridad entre deudas (por costo) | Objetivos concretos |
| 5. Variables | Montos semanales sugeridos hasta el **techo de presupuesto**; el usuario ajusta | Rubros que no use |

Al final muestra el **resumen como el ejemplo del punto 5** y el botón *Activar semana*. Lo no capturado se completa después, sin bloquear.

**10. Pantalla principal "Esta semana"**

```text
┌──────────────────────────────────────┐
│  Semana 26 oct – 1 nov     ◀  ▶      │
│  Ver por: [Semana] Catorcena Quincena Mes │
├──────────────────────────────────────┤
│  INGRESO      $7,385                 │
│  − PRESUPUESTO $5,472   gastado $1,820 (33%) │
│  − DEUDA       $392                  │
│  = REMANENTE  $1,520 → deuda extra (20.6%) │
├──────────────────────────────────────┤
│  Alimentación   $620 / $1,500    🟢  │
│  Transporte     $510 / $700      🟡  │
│  Salud          $0   / $300      🟢  │
├──────────────────────────────────────┤
│  ⚠ Semana del 26 oct: no entra ingreso; renta $8,000 el 1 nov │
├──────────────────────────────────────┤
│  [ + Gasto ]  [ + Ingreso ]  [ Cerrar ] │
└──────────────────────────────────────┘
```

Semáforo por partida: verde hasta 80 % usado, amarillo de 80 % a 100 %, rojo por encima (configurable). Un toque en una línea abre sus movimientos; todo se captura sin salir de la pantalla (8).

**11. Datos que necesita el motor** (ver también la sección 7)

| Entidad | Campos principales |
|---|---|
| **ConfigIngreso** | id, miembro_id, forma (semanal/catorcenal/quincenal/mensual/extra), día_de_pago (día de la semana, días del mes o fecha ancla), regla_fin_de_semana_y_festivos (siguiente_día_hábil/día_hábil_anterior/sin_cambio), periodo_visualización |
| **Ocurrencia** | id, hogar_id, origen (ingreso/gasto_fijo/deuda/reserva), origen_id, fecha_programada, fecha_ajustada, monto_esperado, estado (esperada/cumplida/omitida/pendiente), movimiento_id |
| **PresupuestoSemana** | id, hogar_id, semana_inicio, estado, método, ingreso, presupuesto, deuda_plan, remanente_plan, meta_remanente_pct, ahorro_mínimo_con_deuda_pct, techo, creado_en |
| **PartidaPresupuesto** | id, presupuesto_semana_id, cuenta_gasto_id, asignado, arrastre_recibido, protegida, piso_mínimo |
| **ReservaPago** | id, hogar_id, concepto, monto_objetivo, fecha_vencimiento, acumulado, cuenta_destino_id |
| **AbonoDiferido** | id, deuda_id, semana_inicio, monto_planeado, monto_abonado, diferido |
| **CierreSemana** | id, presupuesto_semana_id, ingreso_real, gasto_real, abono_real, abono_extra_real, ahorro_real, déficit, acción_elegida, cerrado_por, fecha |

Los **saldos y el gastado** no se guardan como campos editables: se calculan desde el libro de movimientos (8 bis); los resúmenes por semana se **precalculan** para abrir rápido.

**12. Casos límite**

1. Ingreso único que cae el lunes tras un fin de semana: la semana anterior tiene flujo cero; ver el ejemplo del punto 5.
2. **Mes con 5 semanas o con 3 pagos de catorcena:** el equivalente semanal los reparte; el flujo los muestra tal cual.
3. Ingreso **irregular**: promedio móvil de las últimas 8 semanas o monto conservador manual.
4. **Pareja con distinto periodo de pago:** cada ingreso entra en su cuenta y fecha; el hogar los suma por semana; cada miembro ve **su** periodo.
5. **Extra** recibido a mitad de semana: sube el remanente de esa semana; se propone repartirlo (punto 7).
6. **Cambio de modo** (Individual → Pareja): se conservan los datos; se agrega el segundo miembro y se pregunta qué se comparte.
7. **Primera semana incompleta:** se prorratea por días o se arranca la semana siguiente (a elegir).
8. **Gastos en efectivo sin captura:** al cerrar, la app sugiere un **ajuste por diferencia de efectivo**, visible en la auditoría.
9. **Sin deudas:** la línea DEUDA queda en cero y todo el remanente va a ahorro.
10. **Deuda nueva mientras se ahorra:** el ahorro acumulado no se toca; el remanente vuelve a pagar deuda.

**13. Pruebas de aceptación del motor** (para Claude Code)

1. Con el ejemplo del punto 5: **ingreso $7,384.62; presupuesto $5,472.31; deuda $392.31; remanente planeado $1,520.00 (20.58 %)**; techo $5,515.39 (tolerancia de un centavo).
2. Sobregasto de **$300 → remanente $1,220.00**; de **$1,800 → remanente $0, abono $112.31, abono diferido $280.00**; de **$2,000 → remanente $0, abono $0, déficit $87.69**.
3. Con "fin de semana pasa al lunes": el sueldo del sábado 31/oct se registra el **lunes 2/nov**; la semana del 26/oct al 1/nov muestra **entra $0 y sale $8,000**, y activa la alerta de flujo si el saldo no alcanza.
4. Un miembro con periodo **quincenal** ve su presupuesto como semanal × 52 ÷ 24 y su gasto real por las fechas de la quincena.
5. Un ingreso `incierto` no cambia el cálculo y aparece como potencial.
6. Un abono a tarjeta por debajo del mínimo exigible muestra la alerta roja.
7. Los gastos protegidos no aparecen en las propuestas de recorte.
8. Cerrar la semana propone aplicar el remanente como abono extra a la tarjeta (mayor costo) y deja los préstamos familiares al final; queda en la bitácora; la deuda sin interés (familiar) **no crece** al diferir un abono.
9. Corregir un gasto de una semana cerrada genera anulación y contraasiento; los totales se recalculan.
10. **Salida de deuda del ejemplo:** tarjeta liquidada en la **semana 4**, préstamo familiar en la **semana 5** y, desde la **semana 6**, ahorro de **$1,520.00** por semana (tolerancia de centavos por redondeo).
11. El cálculo funciona **sin internet** y la pantalla principal abre en menos de 2 segundos con un año de datos de prueba.

### 5.6 ter GASTOS PREVISIBLES, CUENTA DE PREVISIÓN E IMPREVISTOS (a detalle)

**Para qué:** que los gastos que **no son mensuales pero sí seguros** (refrendo, predial, agua potable, seguro) **no caigan como sorpresa**, y que lo que **sí es sorpresa** tenga su propio lugar sin romper el plan. Responde a la pregunta del equipo: *¿los gastos anuales se prorratean en una cuenta de previsión, entran como gasto no programado o se programan?* **La respuesta es que son tres cosas distintas y la app necesita las tres.**

**1. Cuatro clases de gasto según su certeza**

| Clase | Qué es | Ejemplos | Cómo entra en la app |
|---|---|---|---|
| **A. Programado periódico** | Monto y fecha conocidos, cada mes o menos | Renta, internet, cuota del crédito, colegiatura mensual | **Presupuesto semanal** (equivalente semanal) y pago en su fecha (4, 5.2) |
| **B. Previsible no periódico** | **Se sabe que llega**, con fecha y monto conocidos o aproximados, cada varios meses o cada año | **Refrendo, predial, agua potable, seguro** | **Cuenta de previsión** (punto 2) |
| **C. Imprevisto** | **No se sabe cuándo ni cuánto**, pero siempre pasa algo | Reparación del auto, una medicina urgente, una multa | **Partida "Imprevistos"** del presupuesto (punto 4) y, si es grande, **fondo de emergencia** |
| **D. Extra deseado** | Se quiere, pero no es obligatorio | Un regalo, un viaje, un aparato | **Meta o reserva de ahorro con fecha** (5.5 bis); si se compra sin planear, **gasto extra** (punto 5) |

**2. Cuenta de previsión (para la clase B)**

Es un **apartado del hogar** donde cada gasto previsible tiene su **sobre virtual**. Cada semana el presupuesto **reserva** una parte; cuando llega el vencimiento, se paga **desde el sobre**.

- **Aportación semanal** = monto del gasto ÷ semanas que faltan para el vencimiento. En el primer ciclo es mayor (hay que ponerse al corriente); después es **monto anual ÷ 52**.
- **Dónde está el dinero:** puede estar en cualquier cuenta del hogar. La app solo **aparta**: en cada cuenta se ve **"saldo"**, **"apartado"** y **"disponible real" = saldo − apartado**. Si el hogar prefiere una cuenta o un apartado bancario aparte, se puede asociar como destino.
- **Vive dentro del presupuesto, no en el ahorro.** La aportación semanal es un **compromiso del presupuesto** (egreso tipo 1) **desde el primer día**, incluso **mientras hay deuda**, porque estos pagos llegan de todos modos y, si no se aparta, **se vuelven deuda nueva**. Al terminar la deuda **sigue igual**.
- **Contabilidad (5.0 bis 2):** la aportación es un **traslado a un apartado** (no baja el patrimonio); el **gasto se reconoce al pagar**. En los **reportes de gasto** el costo se muestra **devengado** (la parte semanal) por defecto, y en la vista de **flujo**, en la semana del pago. **El mismo dinero no se cuenta dos veces:** el pago sale del sobre y no vuelve a restar al presupuesto de esa semana.
- **Vencimiento ajustado:** si la fecha cae en fin de semana o festivo oficial, se mueve al siguiente día hábil (5.1).
- **Si el sobre no alcanza al vencer** (por ejemplo, el monto subió): la app avisa **antes** con semanas de anticipación y propone la diferencia semanal; si no llega a tiempo, el faltante se toma del **remanente**, luego del **abono planeado** (5.6 bis), nunca de los gastos protegidos.
- **Si sobra** (el monto fue menor): lo que queda en el sobre **pasa al ciclo siguiente** o al **remanente**, a elección.
- **Aprendizaje:** si un **gasto no programado** se repite en el mismo mes del año siguiente, la app sugiere **convertirlo en previsible** y apartar para él.

**Ejemplo con los cuatro gastos del hogar** (**montos y fechas ilustrativos**; los reales se capturan en la ficha). Hoy es la semana 1, no hay nada apartado:

| Gasto | Monto | Vence en la semana | Aportación semanal en el primer ciclo | Aportación semanal después |
|---|---|---|---|---|
| Predial | $1,560 | 12 | $130.00 | $30.00 |
| Agua potable | $780 | 8 | $97.50 | $15.00 |
| Refrendo | $1,300 | 20 | $65.00 | $25.00 |
| Seguro | $6,240 | 30 | $208.00 | $120.00 |

| Semanas | Aportación total a la cuenta de previsión | Por qué baja |
|---|---|---|
| 1 a 8 | **$500.50** | Todos están en su primer ciclo |
| 9 a 12 | $418.00 | El agua ya se pagó |
| 13 a 20 | $318.00 | El predial ya se pagó |
| 21 a 30 | $278.00 | El refrendo ya se pagó |
| 31 en adelante | **$190.00** | Todos pasan a ÷ 52 (**$9,880 al año**) |

El **primer año cuesta más** por el arranque; la app lo dice así. Si **$500.50 por semana no cabe** en el presupuesto, se ofrece: **mover la fecha de pago** si el trámite lo permite, **pagar en parcialidades o a meses sin intereses** si el proveedor lo ofrece (5.3 bis, y con la regla de que **no se adelantan**), **recortar una categoría** o **cubrir la diferencia con el remanente**. Si el municipio, el estado o la aseguradora ofrecen **descuento por pago anticipado o de contado**, **verifícalo con el proveedor**: la app compara el descuento contra el costo de apartar el dinero, pero **no asume** descuentos.

**3. Vínculo con los bienes (vehículo y casa)**

Cada gasto previsible puede **ligarse a un bien**. Al dar de alta un **vehículo**, la app sugiere partidas como refrendo, verificación, seguro, servicio y llantas; al dar de alta la **vivienda**, sugiere predial, agua, seguro del hogar y mantenimiento mayor. Son **sugerencias**: la persona acepta, cambia o descarta cada una. El **crédito automotriz** (5.3) se liga al mismo vehículo para ver **todo lo que cuesta tenerlo**.

**4. Imprevistos (clase C)**

- **Partida "Imprevistos"** en el presupuesto, con monto semanal pequeño. Valor inicial por defecto: **2 % del ingreso semanal**; luego la app propone el **promedio real de las últimas 8 semanas**. Editable.
- Lo que **no se gasta** al cierre de la semana **vuelve al remanente** (y con deuda, **va a deuda**), así que la partida no "se pierde".
- Un gasto no programado se captura normal; la app pregunta **"¿era previsible?"** (sí → propone convertirlo; no → queda como imprevisto).
- **Orden de absorción** (5.6 bis): primero la partida Imprevistos, luego el remanente, luego el abono planeado y, al final, déficit. **Con deuda**, el fondo de emergencia aún no existe; **sin deuda**, un imprevisto **grande** (más de 4 veces la partida, por defecto) se toma del **fondo de emergencia** y la app **recalcula cómo reponerlo** (5.5 bis, punto 7).

**5. Gasto extra (clase D)**

Un gasto deseado y no planeado se registra como **gasto extra** de su categoría discrecional. La app **muestra su efecto en el plan** ("este gasto retrasa el celular 2 semanas") **antes de guardarlo si se captura con calma**, y **después** si se captura por voz o foto (la captura nunca se bloquea).

**6. ¿Qué se programa?**

**Todo lo de las clases A y B se programa** (queda en el **calendario de compromisos** con su fecha y su monto). Lo de la clase C **no**: se cubre con la partida y el fondo. La app usa el calendario para avisar **semanas antes** de cada vencimiento.

**7. Pantallas:** **calendario de compromisos** (A y B por semana), **sobres de previsión** con barra de avance y "vence en X semanas", ficha del bien (vehículo o casa) con sus gastos sugeridos, partida de imprevistos con promedio real, aviso "el sobre no alcanza".

**8. Datos nuevos:** `GastoPrevisible` (concepto, bien_id, monto estimado, fecha de vencimiento, ciclo, categoría), `SobrePrevision` (gasto_id, saldo apartado, aportación semanal, estado) y `Bien` (tipo, nombre, datos de control). La aportación semanal genera una `Ocurrencia` de origen "reserva" (7).

**9. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| P1 | Los cuatro gastos del ejemplo, semana 1, sin apartado | Aportación de **$500.50** por semana en las semanas 1 a 8 |
| P2 | Se paga el agua en la semana 8 | La aportación baja a **$418.00** desde la semana 9 |
| P3 | Régimen estable (todos en ciclo ÷ 52) | **$190.00** por semana; **$9,880** al año |
| P4 | Pagar el predial desde su sobre | El gasto se registra, el sobre baja y **no se resta otra vez** del presupuesto de la semana |
| P5 | Vencimiento en sábado | Se mueve al siguiente día hábil |
| P6 | Monto del seguro sube $600 a 10 semanas del vencimiento | Aviso con la nueva aportación semanal |
| P7 | Gasto no programado repetido en el mismo mes del año siguiente | La app sugiere convertirlo en previsible |
| P8 | Imprevisto grande sin deuda | Se toma del fondo de emergencia y se recalcula la reposición |
| P9 | Semana con imprevistos sin gastar | Lo no gastado vuelve al remanente (o a deuda si la hay) |

### 5.6 quater BIENES: VEHÍCULO Y CASA (a detalle)

**Para qué:** que el hogar vea **cuánto cuesta realmente tener** su vehículo y su vivienda, que los gastos que llegan por **tenerlos** (refrendo, seguro, predial, agua, servicio, mantenimiento) **se aparten solos** en la cuenta de previsión (5.6 ter) y que ningún vencimiento pase sin aviso. Un **bien** es la "ficha" a la que se ligan esos gastos, el crédito y los documentos.

**1. Tipos de bien**

| Tipo | Ejemplos | Notas |
|---|---|---|
| **Vehículo** | Auto, moto | Puede tener un **crédito ligado** (5.3: el crédito automotriz de Caja Popular Mexicana) |
| **Vivienda** | Casa o departamento, **propio, rentado o familiar** | Puede tener hipoteca o contrato de renta |
| **Otro** | Terreno, local, equipo de trabajo | Ficha simple: valor, seguro y gastos |

Un bien puede ser **individual** o **del hogar**, con sus **propietarios** y quién lo **usa** (5.0 bis).

**2. Ficha del vehículo**

| Grupo | Datos |
|---|---|
| **Identidad** | Alias, marca, modelo, año, placas, conductor habitual |
| **Compra** | Fecha, valor de compra, **crédito ligado** |
| **Valor** | **Valor estimado actual**, con **fecha y fuente** que escribe la persona (una guía de precios, una cotización) |
| **Seguro** | Aseguradora, póliza, **vigencia**, prima, forma de pago, deducible |
| **Trámites** | **Refrendo** (monto y vencimiento) y **verificación** (fecha y periodicidad). **Los montos y las fechas los captura la persona**: las reglas cambian por estado y la app **no las asume** |
| **Mantenimiento** | Servicio **cada X kilómetros o Y meses, lo que ocurra primero**, costo estimado del servicio, llantas y batería |
| **Uso** | Kilometraje (opcional) y combustible habitual |
| **Documentos** | Foto de la tarjeta de circulación y de la póliza (punto 8) |

**3. Ficha de la vivienda**

| Grupo | Datos |
|---|---|
| **Identidad** | Alias, dirección (opcional), tipo (propia, rentada o familiar) |
| **Propia** | **Predial** (monto y vencimiento), **agua potable** (periodicidad y monto), seguro del hogar, hipoteca ligada, valor estimado con fecha y fuente |
| **Rentada** | Renta, **vigencia del contrato**, aumento anual esperado, **depósito en garantía** |
| **Mantenimiento mayor** | Impermeabilización, pintura, boiler, bomba, etc., con **cada cuántos años** y costo estimado |
| **Adecuaciones por cuidados** | Rampas, barandales y otras (5.2, "Seguridad y adecuaciones del hogar") |

El **depósito en garantía** es un **activo por cobrar** al arrendador (5.0 bis 2): **no es gasto**; al recuperarlo, baja la cuenta por cobrar (5.1 bis).

**4. Gastos sugeridos al dar de alta un bien**

La app **sugiere** las partidas; la persona **acepta, cambia o descarta** cada una. Las aceptadas se vuelven **gastos previsibles** con su sobre (5.6 ter) o **imprevistos** (clase C).

| Bien | Partidas sugeridas | Clase (5.6 ter) | Ciclo sugerido |
|---|---|---|---|
| **Vehículo** | Seguro | B, previsible | Anual o la vigencia |
| | Refrendo | B | Anual |
| | Verificación | B | Según tu estado (lo captura la persona) |
| | Servicio de mantenimiento | B | Por kilómetros o por meses |
| | Llantas y batería | B | Cada cierto tiempo |
| | Combustible, estacionamiento y peajes | A, programado variable | Semanal (Transporte, 5.2) |
| | Multas, grúa, reparación inesperada | C, imprevisto | Partida de imprevistos |
| **Vivienda propia** | Predial | B | Anual |
| | Agua potable | B | Según tu contrato |
| | Seguro del hogar | B | Anual |
| | Mantenimiento mayor | B | Cada X años |
| **Vivienda rentada** | Renta | A | Mensual |
| | Aumento de renta | Aviso | A la renovación |

Los **gastos de cada bien** quedan **etiquetados con el bien** en "para quién" (5.2), así que el reporte por bien funciona **con la captura normal**.

**5. Costo de tener el bien (el número que casi nadie conoce)**

La app muestra dos cifras distintas por semana:

| Cifra | Qué incluye |
|---|---|
| **Costo de tenencia** | Combustible, seguro, refrendo, verificación, servicio, llantas **y los intereses** del crédito; **no incluye el capital**, que baja deuda (5.3) |
| **Salida de efectivo** | El costo de tenencia **más el capital** del crédito |

**Ejemplo con un vehículo** (**valores ilustrativos**, no son tus datos):

| Concepto | Por semana |
|---|---|
| Combustible | $450.00 |
| Seguro ($6,240 al año) | $120.00 |
| Refrendo ($1,300 al año) | $25.00 |
| Verificación ($520 al año) | $10.00 |
| Servicio ($2,080 cada 26 semanas) | $80.00 |
| Llantas ($5,200 cada 2 años) | $50.00 |
| Intereses del crédito | $140.00 |
| **Costo de tenencia** | **$875.00** (≈ $45,500 al año) |
| Capital del crédito | $760.00 |
| **Salida de efectivo** | **$1,635.00** |

La diferencia importa: **$760** de la salida **no son un gasto**, son deuda que baja y patrimonio que sube; los **$875** sí son el costo real de usar el vehículo.

**6. Mantenimiento por kilómetros o por tiempo**

- La persona declara el servicio "cada X km o Y meses, lo que ocurra primero". La **aportación semanal** = costo del servicio ÷ semanas entre servicios (por ejemplo, $2,080 ÷ 26 = **$80**).
- Si captura el **kilometraje** (opcional, al cargar combustible o al hacer un servicio), la app **proyecta la fecha** del siguiente servicio con el ritmo real de uso.
- Si el servicio se hace **antes o después**, el sobre se **recalcula**.

**7. Contabilidad y patrimonio**

- Un bien es un **activo no líquido** con un **valor estimado que escribe la persona**; **la app no calcula depreciación sola**.
- El patrimonio se muestra **sin bienes** (lo que se puede gastar) y **con bienes** (5.0 bis 2); el **disponible del hogar** **no incluye** bienes.
- El **crédito ligado** es un pasivo; el patrimonio del bien es **valor estimado − saldo del crédito**.
- Si el valor no se actualiza en **12 meses** (por defecto), se marca **"por actualizar"**.
- **Vender el bien:** el precio entra a una cuenta (5.1 bis, "venta de un bien"); la **ganancia o pérdida** es la diferencia contra su valor registrado y se **anota aparte**; si había crédito, se **liquida** con ese dinero o con otro, y el simulador muestra el efecto (5.3 ter).

**8. Documentos del bien**

Fotos de la tarjeta de circulación, la póliza, el contrato de renta o el recibo de predial, **ligadas al bien** y no al movimiento. **Se guardan mientras el bien esté activo** (no aplica el límite de 12 meses de las fotos de tickets, 8 ter), **cifradas en el teléfono** y se comparten con el hogar **solo si la persona lo permite**. Son datos **sensibles** (placas, direcciones); no se envían a servicios de IA.

**9. Crédito ligado y seguro obligatorio**

El crédito automotriz se **liga al vehículo**: se ve **todo lo que cuesta tenerlo** (punto 5). Si el contrato **exige seguro vigente** (**verifícalo en tu contrato**), la app **alerta antes del vencimiento** del seguro; la persona lo marca en la ficha, la app **no lo supone**. Las condiciones de pago anticipado (pendiente 11) se anotan en la misma ficha.

**10. Alertas** (se suman al catálogo de 5.9 bis)

| Alerta | Nivel | Cuándo avisa por defecto |
|---|---|---|
| Seguro, refrendo o verificación por vencer | Importante | 4 semanas y 1 semana antes |
| Servicio del vehículo próximo | Informativa | Por kilometraje proyectado o por fecha |
| Predial o agua por vencer | Importante | 4 semanas y 1 semana antes |
| Fin de vigencia del contrato de renta | Informativa | 8 semanas antes |
| Valor del bien por actualizar | Informativa | A los 12 meses |

**11. Reporte "Costo por bien"**

Por periodo: gasto de cada bien, **intereses y capital** del crédito ligado, **costo por semana y por año**, y qué parte viene de **sobres de previsión** y cuál de **gasto variable**. Permite comparar **conservar o cambiar** el vehículo con los números del hogar.

**12. Pantallas:** lista de bienes con su costo semanal, ficha del vehículo, ficha de la vivienda, **asistente de alta** (datos mínimos → partidas sugeridas → montos y fechas), calendario de vencimientos por bien y reporte "Costo por bien".

**13. Datos nuevos:** `Bien` (tipo, alias, propietarios, usuario habitual, valor estimado, fecha y fuente del valor), `BienVehiculo` (marca, modelo, año, placas, kilometraje), `BienVivienda` (tipo de tenencia, contrato, vigencia, depósito), `ServicioBien` (bien, intervalo en kilómetros o meses, costo, último y próximo), `LecturaOdometro` (bien, fecha, kilometraje) y `DocumentoBien` (bien, tipo, archivo local, permiso de compartir). `GastoPrevisible` ya lleva `bien_id` (5.6 ter) y el crédito se liga con `deuda_id`.

**14. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| BI1 | Alta de un vehículo | Sugiere las partidas del punto 4; las aceptadas crean sus sobres |
| BI2 | Ejemplo del punto 5 | Costo de tenencia **$875.00** por semana, salida de efectivo **$1,635.00** |
| BI3 | Pagar el seguro desde su sobre | Se registra el gasto con la etiqueta del bien y baja el sobre; el reporte por bien se actualiza |
| BI4 | Seguro por vencer en 4 semanas con crédito que lo exige | Alerta marcada como obligatoria por el contrato |
| BI5 | Servicio de $2,080 cada 26 semanas | Aportación de **$80** por semana |
| BI6 | Vivienda rentada con depósito de $8,000 | Se crea una **cuenta por cobrar**, no un gasto |
| BI7 | Vender el vehículo | Calcula ganancia o pérdida contra el valor registrado y liquida el crédito |
| BI8 | Valor sin actualizar por 12 meses | Marca **"por actualizar"** |
| BI9 | Gasolina etiquetada al vehículo | Aparece en el costo por bien |
| BI10 | Contrato de renta que termina en 8 semanas | Aviso de fin de vigencia y de posible aumento |

**Lo que no se asume:** los montos, las fechas ni las reglas de refrendo y verificación de tu estado, el valor de mercado del bien, ni que tu contrato exija seguro. Todo se captura o se confirma con tus documentos.

### 5.7 OBJETIVOS Y PLAN

**Para qué:** que el presupuesto no sea solo control, sino **dirección**. Responde "¿cómo llego a lo que quiero con lo que gano?"

**Tipos de objetivo:** ahorrar una cantidad, liquidar una deuda, formar fondo de emergencia, comprar algo en una fecha, reducir un gasto, alcanzar un nivel de inversión.

**Datos:** nombre, tipo, monto meta, fecha objetivo, prioridad, miembros involucrados, módulo origen (Ahorro/Deuda/Inversión).

**Cómo funciona**

- La app calcula **viabilidad**: ¿alcanza el ingreso para esta meta junto con las demás? Si no, ofrece escenarios: *extender fecha*, *aumentar aportación*, *recortar categoría X*, *aumentar ingreso*.
- **Priorización** de objetivos cuando compiten por los mismos recursos.
- **Línea de tiempo** con hitos y avance; celebra metas cumplidas.
- En modo Pareja/Familiar: objetivos **compartidos** con aportación de cada miembro.

**Pantallas:** lista de objetivos con avance, asistente "crear plan" (meta → escenarios → elegir), simulador "¿y si...?".

### 5.7 bis OBJETIVOS Y PLAN A DETALLE

**Para qué:** juntar en **un solo plan** todo lo que el hogar quiere lograr (salir de deudas, formar el colchón, comprar algo, invertir) y **decir con números si alcanza, en qué orden y para cuándo**. El plan **no inventa dinero**: reparte el remanente que calcula el motor semanal (5.6 bis).

**1. Qué es un objetivo**

| Tipo | De dónde viene | Ejemplo |
|---|---|---|
| **Liquidar deuda** | Deudas (5.3 ter) | "Salir de la tarjeta A" |
| **Fondo de emergencia** | Ahorro (5.5 bis) | "Tres meses cubiertos" |
| **Reserva** | Ahorro (5.5 bis) | "Seguro anual" |
| **Meta con fecha** | Ahorro | "Celular en 30 semanas" |
| **Inversión** | Inversión (5.4 bis) | "Enganche en 5 años" |
| **Reducir un gasto** | Presupuesto | "Bajar entretenimiento $200 por semana" |
| **Aumentar un ingreso** | Ingresos | "Ingreso extra de $500 por semana" |

Datos de cada uno: nombre, tipo, monto meta, fecha (si tiene), prioridad, miembros involucrados, **dueño** (individual, pareja o familia) y su módulo de origen.

**2. El plan: una sola línea de tiempo**

El plan toma el remanente proyectado de cada semana y lo reparte **en el orden de la cascada**:

1. **Deudas con costo** (por costo efectivo, 5.3 ter).
2. **Préstamos familiares.**
3. **Fondo de emergencia, nivel 1.**
4. **Reservas.**
5. **Metas con fecha** (lo necesario para llegar a tiempo).
6. **Fondo de emergencia hasta la meta.**
7. **Metas sin fecha e inversión.**

Cuando un objetivo se completa, **su aportación pasa al siguiente** (efecto cascada, igual que en las deudas). El plan se **recalcula cada semana** con lo registrado de verdad, no con lo que se pensó.

**3. Viabilidad**

La app compara, **semana por semana**, la **suma de aportaciones que piden los objetivos** contra el **remanente proyectado**. Resultado por objetivo:

| Semáforo | Significa | Qué hace la app |
|---|---|---|
| **Verde** | Llega a la fecha con el orden actual | Muestra la semana de cumplimiento |
| **Ámbar** | Llega, pero **retrasa a otro objetivo** o deja poco margen (menos de 10 % del remanente, por defecto) | Muestra a quién retrasa |
| **Rojo** | **No llega** a la fecha con lo disponible | Ofrece los escenarios de abajo |

**Escenarios cuando no alcanza** (cada uno muestra su efecto en fecha y en monto):

| Escenario | Qué calcula |
|---|---|
| **Mover la fecha** | Nueva fecha con la aportación disponible |
| **Subir la aportación** | Cuánto más por semana y de dónde saldría |
| **Recortar una categoría** | Cuánto liberaría recortar X por ciento de una categoría (5.2) |
| **Subir el ingreso** | Cuánto ingreso extra haría falta |
| **Cambiar el orden** | Qué objetivo adelanta y a cuál retrasa |

**4. Ejemplo con el plan del hogar**

Con los datos de 5.6 bis y 5.5 bis (remanente de **$1,520** por semana, tarjeta liquidada en la semana 4, préstamo familiar en la 5):

| Semanas globales | Objetivo que recibe el remanente | Qué ocurre |
|---|---|---|
| 1 a 4 | **Liquidar la tarjeta** | La tarjeta queda en cero en la semana 4 |
| 5 | **Préstamo familiar** (sin interés) | Queda en cero en la semana 5 |
| 6 a 10 | **Colchón (nivel 1)** | $7,000 en la semana 10 |
| 10 a 39 | Reservas, **celular** y fondo | Celular completo en la semana 39 |
| 10 a 46 | **Fondo de emergencia** | Tres meses cubiertos en la semana 46 |
| 47 en adelante | **Inversión** y metas sin fecha | La puerta de inversión se abre (5.4 bis) |

Si se pide el celular en 12 semanas, el semáforo pasa a **ámbar**: llega, pero el **colchón queda $4,250 más bajo** en la semana 17 de ahorro (semana global 22) y el fondo termina igual (5.5 bis, punto 4).

**5. Pareja y familia**

- Los objetivos pueden ser **individuales, de pareja o familiares**. En los compartidos se define **cómo aporta cada quien**: **partes iguales**, **proporcional al ingreso** o **monto fijo por persona**.
- Un objetivo compartido **se activa cuando los miembros lo confirman**; en caso de ausencia, el **albacea** puede confirmar (5.0 ter), con registro en la bitácora.
- El plan **no mezcla en silencio**: cada aportación indica **de quién es** (transparencia total, 5.0 bis).
- Si dos miembros piden cosas contrarias, la app **muestra el conflicto** (por ejemplo, "dos metas necesitan el mismo remanente") y propone el orden; **decide el hogar**, no la app.

**6. Seguimiento**

| Elemento | Qué muestra |
|---|---|
| **Avance** | Porcentaje, monto y semanas que faltan |
| **Plan contra real** | Lo planeado esa semana contra lo aportado |
| **Atraso** | Cuánto se movió la fecha y por qué |
| **Hitos** | 25 %, 50 % y 75 % de cada objetivo, y el cierre |
| **Cierre** | Al cumplirse, queda en el historial con la fecha real |

Las celebraciones son **discretas** y se pueden apagar. La app **explica cada cambio de fecha** con una frase ("subió el gasto en alimentación; se retrasó el celular una semana").

**7. Reglas**

1. Un objetivo **no puede pedir** dinero que ya prometió otro; la suma siempre cabe en el remanente.
2. **Los gastos protegidos y los mínimos de deuda** nunca se sacrifican por un objetivo.
3. Se pueden **pausar** objetivos sin perder su historial.
4. Cambiar la prioridad o la fecha **queda en la bitácora**.
5. Un objetivo sin dato mínimo (monto o fecha, según tipo) **no entra al plan** hasta completarlo.

**8. Pantallas:** lista de objetivos con semáforo, **línea de tiempo del plan** (barras por objetivo), asistente "crear objetivo" (tipo → monto y fecha → viabilidad → escenarios → confirmar), simulador "¿y si…?", conflictos entre miembros, historial de cumplidos.

**9. Datos nuevos:** `Objetivo` (tipo, monto, fecha, prioridad, dueño, módulo de origen, estado), `ObjetivoParticipante` (miembro y regla de aporte), `PlanSemana` (semana, objetivo, aportación planeada y real) y `EscenarioPlan` (parámetros y resultado guardado).

**10. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| O1 | Ejemplo del punto 4 | Tarjeta en la semana 4, préstamo en la 5, colchón en la 10, celular en la 39 y fondo en la 46 |
| O2 | Celular en 12 semanas | Semáforo ámbar; colchón $4,250 menor en la semana 22 global; fondo igual |
| O3 | Meta que pide más que el remanente | Semáforo rojo con los cinco escenarios |
| O4 | Objetivo compartido | No se activa hasta confirmar los miembros; el albacea puede confirmar con registro |
| O5 | Liquidar un objetivo | Su aportación pasa al siguiente |
| O6 | Semana con gasto mayor al presupuesto | El plan se recalcula y explica el atraso |
| O7 | Aportación compartida proporcional al ingreso | Cada miembro ve su parte y de quién es cada aporte |
| O8 | Objetivo en pausa | No recibe aportación y conserva su historial |

### 5.8 ALIMENTACIÓN: monto semanal → menú → lista de compras

Este es el módulo más detallado y se describe completo en la **sección 6**, porque parte de la tabla de ejemplo.

### 5.9 SEGUIMIENTO, REPORTES Y ALERTAS

**Para qué:** convertir los datos en comprensión.

- **Tablero semanal:** ingresos, comprometido, gastado, disponible, ahorro de la semana.
- **Salud financiera:** carga de deuda, tasa de ahorro, meses de fondo de emergencia, cumplimiento del presupuesto.
- **Reportes:** por categoría, por miembro, plan vs. real, tendencia de 4/12 semanas, "a dónde se fue el dinero".
- **Alertas** (configurables): vencimiento de pagos, corte de tarjeta, categoría al 80%, ingreso retrasado, meta en riesgo, semana con flujo negativo.
- **Exportar:** **Excel o CSV**, con el mismo selector de periodo.

**Reporte de auditoría (Excel o CSV)**

- **Periodo configurable:** semana, catorcena, quincena, mes, semestre, año o **rango de fechas** a elección. También se puede filtrar por miembro, por cuenta o por cuenta de gasto.
- **Formato:** un archivo **Excel (.xlsx) con una hoja por tabla**, o **CSV** (un archivo por tabla, agrupados en un solo paquete, porque un CSV no admite varias hojas).
- **Contenido:**

| Hoja | Qué contiene |
|---|---|
| **Resumen** | Hogar, periodo, quién lo generó y cuándo, folio; totales de ingresos, gastos, aportaciones, transferencias, ahorro y deuda; saldo inicial y final por cuenta; diferencias de conciliación |
| **Movimientos** | Todos los asientos: fecha y hora, cuenta origen y destino, monto, categoría y subcategoría, quién lo realizó, quién lo registró, vía de captura, estado y si tiene evidencia |
| **Aportaciones** | Por cuenta de gasto y por miembro: monto y porcentaje, frente a la meta si existe |
| **Transferencias y préstamos** | Emisor, receptor, tipo, monto, estado, quién confirmó y si fue **el albacea en nombre del miembro**, y fecha de confirmación |
| **Deudas internas** | Saldos y quién debe a quién |
| **Anulaciones y ajustes** | Movimiento original, contraasiento, motivo y quién confirmó |
| **Conciliaciones** | Saldo declarado frente al calculado, diferencia y ajuste |
| **Bitácora** | Cada acción del periodo: quién, cuándo, valor anterior y nuevo, motivo y *"como albacea en nombre de"* |

- **Reglas:** incluye siempre los movimientos anulados (marcados como tales); montos en MXN; fechas en un formato único; encabezados en español; cada fila lleva el identificador del movimiento para poder rastrearlo.

---

### 5.9 bis SEGUIMIENTO, REPORTES, ALERTAS Y NOTIFICACIONES (a detalle)

**Para qué:** que la persona entienda **en 10 segundos cómo va la semana**, **en 3 minutos qué pasó y qué ajustar**, y **en una revisión mensual hacia dónde va el hogar**. Pocos números, cada uno con su **acción**; nada de tableros que nadie lee.

**1. Tres niveles de lectura**

| Nivel | Pregunta | Dónde | Tiempo |
|---|---|---|---|
| **Hoy** | ¿Qué tengo que hacer? | Pantalla de inicio | 10 segundos |
| **Semana** | ¿Cómo voy y qué ajusto? | Revisión semanal | 3 minutos |
| **Panorama** | ¿Hacia dónde vamos? | Reportes y salud financiera | Cuando se quiera |

**2. Pantalla de inicio ("Hoy")**

1. **Tarjeta de la semana** con la cascada de 5.6 bis: **ingreso → presupuesto → deuda → remanente**, cada renglón con **planeado**, **real** y **semáforo**.
2. **Esta semana vence:** pagos de deuda, cortes y límites de tarjeta, y **sobres de previsión** (5.6 ter), con el día hábil ya ajustado.
3. **Pendientes:** movimientos por confirmar, transferencias sin aceptar y conciliación de efectivo.
4. **Siguiente mejor acción:** una sola sugerencia (por ejemplo, "abonar $X extra a la tarjeta B").
5. **Botón de captura** siempre visible (teclado, voz, foto; 5.2).

**3. Indicadores de salud financiera (fórmula, semáforo y acción)**

Los umbrales son **valores por defecto** y se pueden cambiar.

| Indicador | Fórmula | Verde | Ámbar | Rojo | Acción que ofrece |
|---|---|---|---|---|---|
| **Remanente** | Remanente ÷ ingreso de la semana | ≥ 20 % | 10 % a 20 % | < 10 % | Ver qué categoría se pasó |
| **Carga de deuda** | Pagos de deuda semanales ÷ ingreso semanal | < 20 % | 20 % a 35 % | > 35 % | Abrir el simulador (5.3 ter) |
| **Cumplimiento del presupuesto** | Partidas dentro de lo asignado ÷ total de partidas | ≥ 90 % | 70 % a 90 % | < 70 % | Revisar partidas pasadas |
| **Semanas de fondo cubiertas** | Saldo del fondo de emergencia ÷ gasto esencial semanal | ≥ meta elegida | 50 % a 100 % de la meta | < 50 % | Ver plan de reposición (5.5 bis) |
| **Uso del límite de tarjetas** | Saldo ÷ límite, por tarjeta y total | < 30 % | 30 % a 60 % | > 60 % | Ver cuál pagar (5.3 ter) |
| **Costo de deber** | Intereses y cargos **estimados** de la semana | — | — | — | Comparar con el mes anterior |
| **Previsión al corriente** | Sobres con su aportación al día ÷ total de sobres | 100 % | 80 % a 99 % | < 80 % | Ver el sobre atrasado (5.6 ter) |
| **Patrimonio neto** | Activos − pasivos (5.0 bis 2) | Sube | Igual | Baja | Ver qué lo movió |
| **Semana libre de deuda** | Estimación del motor (5.3 ter) | Se adelanta | Igual | Se atrasa | Ver el cambio |

**Ejemplo con los números de 5.6 bis** (ingreso de **$7,384.62**, presupuesto de **$5,472.31**, deuda de **$392.31**, remanente de **$1,520.00**):

| Indicador | Valor | Semáforo |
|---|---|---|
| Remanente | 1,520.00 ÷ 7,384.62 = **20.58 %** | Verde |
| Carga de deuda | 392.31 ÷ 7,384.62 = **5.31 %** | Verde |

Si Alimentación se pasa **$300** (caso de 5.6 bis), el remanente real queda en **$1,220.00 = 16.52 %** y pasa a **ámbar**; la app dice **dónde** y **cuánto** y ofrece compensar con la partida de imprevistos o la semana siguiente.

**4. Revisión semanal (el ritual de 3 minutos)**

Se ofrece al **cierre de la semana** (domingo por la noche o lunes temprano, a elección). Pasos:

1. **Conciliar el efectivo** (5.0 bis 2): la diferencia suele ser gasto hormiga sin capturar.
2. **Confirmar pendientes** (movimientos y transferencias; el albacea puede confirmar, 5.0 ter).
3. **Ver desvíos:** las **tres** partidas que más se movieron, con la causa más probable ("compra grande en el súper").
4. **Aceptar o ajustar** lo que propone la app para la semana siguiente (5.6 bis, punto 8).
5. **Cerrar la semana:** se guarda el `CierreSemana` y arranca la nueva.

Estados de la semana: los de 5.6 bis, punto 8 (`activa`, `por cerrar` y `cerrada`). Se cierra al abrir la app el lunes o con *Cerrar semana*; si la persona no la cierra en **3 días** (por defecto), la app la **cierra con pendientes marcados**; nada se pierde y se puede reabrir con anulación y contraasiento (5.0 bis).

**5. Reportes**

| Reporte | Contenido | Periodos |
|---|---|---|
| **Plan contra real** | Asignado, gastado y diferencia por partida | Semana, 4 semanas, mes |
| **Por categoría** | Árbol de 3 niveles con detalle al tocar (5.2) | Cualquier periodo |
| **Por miembro** | Aportado y gastado por persona, con transparencia total | Cualquier periodo |
| **A dónde se fue el dinero** | Del ingreso a presupuesto, deuda, previsión y ahorro (gráfica de cascada) | Semana, mes, año |
| **Tendencia** | Ingreso, gasto y remanente | 4, 12 y 52 semanas |
| **Deudas** | Saldo, intereses pagados, semana libre de deuda | Mes, año |
| **Ahorro e inversión** | Aportado, valor y avance por objetivo | Mes, año |
| **Patrimonio** | Activos, pasivos y patrimonio con su evolución | Mes, año |
| **Alimentación** | Plan contra real de comida, precios y desviación (6.10) | Semana, mes |
| **Previsión** | Sobres, aportaciones y vencimientos próximos | Año |
| **Auditoría** | Movimientos con evidencia y bitácora (5.9) | Semana a rango libre |

**Reglas de lectura:**

- **Los meses tienen 4 o 5 lunes**, así que los reportes mensuales se muestran **por semanas** y con **promedio semanal**; así los meses no se comparan injustamente.
- Un **selector** cambia entre **devengado** y **flujo** (4, 5.0 bis 2); el valor por defecto está rotulado en pantalla.
- Cada cifra se puede **tocar** para ver los movimientos que la forman.
- **Exportar** a Excel o CSV con el mismo selector de periodo (5.9).
- Las gráficas son **simples**: barras (plan contra real), líneas (tendencias), cascada (a dónde se fue) y barras apiladas (composición). **Nunca dependen solo del color**: el semáforo también lleva texto o icono.

**6. Alertas**

Cada alerta tiene **nivel**, **cuándo avisa** (valor por defecto) y un **botón de acción**.

| Grupo | Alerta | Nivel | Cuándo avisa por defecto | Acción |
|---|---|---|---|---|
| **Vence dinero** | Pago de deuda | Crítica | 3 días y 1 día antes | Registrar pago |
| | Corte y límite de pago de tarjeta | Crítica | 3 días y 1 día antes del límite | Ver cuánto pagar |
| | Sobre de previsión por vencer | Importante | 4 semanas y 1 semana antes | Ver sobre |
| | Sobre que no alcanza | Importante | Al detectarlo | Ver diferencia semanal |
| **Presupuesto** | Partida al 80 % | Informativa | Al llegar | Ver partida |
| | Partida al 100 % | Importante | Al llegar | Mover o aceptar |
| | Gasto protegido en riesgo | Crítica | Al detectarlo | Ver cómo cubrirlo |
| **Flujo** | Ingreso retrasado | Importante | Siguiente día hábil | Reprogramar |
| | Semana con flujo negativo | Crítica | Al proyectarse | Ver escenarios |
| **Deuda** | Uso del límite arriba de 30 % | Informativa | Al cruzar | Ver tarjeta |
| | Interés estimado distinto al cobrado (más de ±5 %, 5.3) | Importante | Al capturar el estado de cuenta | Revisar |
| | Mínimo en riesgo (prueba de estrés, 5.3 ter) | Crítica | Al detectarlo | Ver simulación |
| **Ahorro y metas** | Aportación pendiente | Informativa | Al cierre semanal | Confirmar o posponer |
| | Meta en riesgo (semáforo rojo, 5.7 bis) | Importante | Al cambiar | Ver escenarios |
| | Fondo de emergencia bajo | Importante | Al bajar de la meta | Ver reposición |
| **Precios e inventario** | Precio superior (6.10) | Informativa | Al capturar | Ver comercios |
| | Perecedero por vencer (6.13) | Informativa | 2 días antes | Ver platillos |
| **Cuentas** | Transferencia sin confirmar más de 48 horas | Importante | A las 48 horas | Confirmar |
| | Conciliación pendiente | Informativa | Al cierre semanal | Conciliar |
| **Sistema** | Valor de inversión por actualizar (5.4 bis) | Informativa | A los 35 días | Actualizar |
| | Sincronización pendiente o respaldo atrasado | Importante | Al detectarlo | Ver estado |
| **Bienes** | Seguro, refrendo, verificación, predial o agua por vencer; servicio próximo; fin de contrato de renta (5.6 quater) | Importante o informativa | 4 semanas y 1 semana antes (renta, 8 semanas) | Ver bien |

**7. Notificaciones**

**Canales:**

- **Recordatorios locales** (programados en el propio teléfono, **sin servidor** y sin costo): vencimientos, cierre de semana, resumen del lunes.
- **Avisos entre miembros** (confirmaciones, transferencias, albacea): por el servicio de notificaciones de Firebase, que ya forma parte de la pila (8 bis). **Verificar sus condiciones vigentes** antes de lanzar.
- **Dentro de la app:** una **bandeja** con todo lo avisado y lo pendiente.

**Reglas:**

1. **Resumen del lunes** (por defecto, 8:00): ingreso esperado, compromisos y lo que vence esa semana.
2. **Recordatorio de cierre** (por defecto, domingo 19:00) para la revisión de 3 minutos.
3. **Horas silenciosas** por defecto de **22:00 a 07:00**; solo pasan las críticas si la persona lo permite.
4. **Tope diario:** como máximo **3 avisos** no críticos al día (por defecto); el resto se agrupa en el resumen.
5. **Pantalla bloqueada sin montos** por defecto ("vence un pago de tarjeta"); se puede cambiar.
6. Cada aviso se puede **posponer** (1 hora, mañana) o **silenciar por tipo**.
7. **Cada miembro elige los suyos.** Los vencimientos de **cuentas o deudas compartidas** llegan a **todos los titulares**; las confirmaciones pendientes llegan al miembro y, si no responde, al **albacea** (5.0 ter).
8. En **Android**, el sistema pide **permiso para notificar** y puede **retrasar recordatorios** por ahorro de batería; por eso **toda alerta crítica también aparece al abrir la app**, y la app explica cómo permitir las notificaciones.
9. **Agregar al calendario del teléfono** (opcional, por vencimiento): se crea el evento **sin monto** por defecto.

**8. Pantallas:** inicio con la cascada y lo que vence, revisión semanal en cinco pasos, salud financiera con sus nueve indicadores, catálogo de reportes con selector de periodo, bandeja de alertas, ajustes de notificaciones (horarios, tope, qué mostrar), calendario de compromisos.

**9. Datos nuevos:** `Alerta` (tipo, nivel, regla, entidad, fecha, estado, acción), `ReglaAlerta` (tipo, umbral, anticipación, miembros), `PreferenciaNotificacion` (miembro, horas silenciosas, tope, mostrar montos), `Notificacion` (alerta_id, canal, enviada, leída, pospuesta), `IndicadorSemana` (semana, indicador, valor, semáforo) y `ReporteGuardado` (tipo, filtros, periodo).

**10. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| T1 | Semana de 5.6 bis | Remanente **20.58 %** (verde) y carga de deuda **5.31 %** (verde) |
| T2 | Alimentación se pasa $300 | Remanente **16.52 %** (ámbar) y alerta con la categoría y el monto |
| T3 | Pago de tarjeta con límite el viernes | Aviso 3 días y 1 día antes, con el día hábil ajustado |
| T4 | Teléfono con ahorro de batería que retrasa el aviso | La alerta crítica aparece al abrir la app |
| T5 | Ocho avisos informativos en un día | Se muestran 3 y el resto va al resumen |
| T6 | Aviso a las 23:00 | Espera a las 07:00; una crítica pasa solo si está permitido |
| T7 | Transferencia sin confirmar 48 horas | Aviso al miembro y, sin respuesta, al albacea |
| T8 | Reporte mensual con 5 lunes | Se muestra por semanas con promedio semanal |
| T9 | Semana sin cerrar por 3 días | Se cierra con pendientes marcados y se puede reabrir |
| T10 | Notificación en pantalla bloqueada | No muestra montos por defecto |

**Lo que no se asume:** que los umbrales sirven igual a todos los hogares (por eso son editables), que el teléfono entregue el aviso a tiempo, ni que un indicador en verde signifique que no hay riesgos. Los indicadores **orientan**, no sustituyen la decisión de la persona.

---

## 6. Módulo de Alimentación a detalle (parte de la tabla de ejemplo)

### 6.1 Qué hace la tabla de ejemplo

El Excel `PRESUPUESTO DE ALIMENTOS.xlsx` ya modela, en pequeño, el corazón del módulo. Tiene **4 hojas**, que corresponden a entidades de la app:

| Hoja del Excel | Qué contiene | Entidad en la app |
|---|---|---|
| **MENU SEMANAL** | Cuadrícula día × tiempo de comida (almuerzo, comida, merienda, cena) con la clave del platillo (`SNK-001`, `SAN-001`) | **Plan de menú semanal** |
| **RECETA** | Estructura **padre → hijo**: cada platillo (clave) se compone de ingredientes (claves), con unidad, cantidad, **rendimiento**, precio e importe | **Platillos, ingredientes y receta** |
| **PORCIONES** | Cuántas porciones de cada platillo consume cada integrante (Ana, Alex) | **Porciones por persona** |
| **PRESUPUESTO SEMANAL** | Porciones familiares totales por platillo (ej. `SAN-001` = 3, `SNK-001` = 2) | **Demanda semanal → lista de compras** |

### 6.2 La lógica de costeo (lo que ya resuelve el Excel)

- Cada **ingrediente** se compra en una presentación (ej. *yogurt griego 650 g*, *precio $55*).
- El **rendimiento** indica **cuántas porciones salen de esa presentación** (ej. un yogurt de 650 g rinde 4 porciones).
- Por tanto, el consumo por porción es `cantidad = 1 / rendimiento` de la presentación, y el costo por porción es `importe = cantidad × precio`.
- El **costo del platillo** = suma de importes de sus ingredientes.

```
costo_porcion_ingrediente = precio_presentacion / rendimiento
costo_platillo            = Σ costo_porcion_ingrediente
costo_semanal_platillo    = costo_platillo × porciones_familiares_totales
presupuesto_semanal_comida = Σ costo_semanal_platillo
```

**Ejemplo con los datos del Excel:** el *Sándwich de jamón de pavo* usa jitomate (29 ÷ 48), lechuga (40 ÷ 16), mayonesa (61 ÷ 28), jamón (44 ÷ 16), pan (61 ÷ 9) y queso panela (57 ÷ 10); la suma de esas porciones da el costo de **1 sándwich**. Si la familia consume 3 porciones en la semana, el costo semanal es 3 veces ese valor.

### 6.3 La idea de la app (invertir el flujo)

El Excel va **del menú al costo**. La app debe poder ir también **del costo al menú**:

> *"Tengo $X por semana para comer → dame opciones de menú → dame la lista de insumos a comprar."*

> **Catálogo (decisión):** conviven **dos catálogos**: uno **base** que trae la app (platillos e ingredientes comunes con precios de referencia) y uno **propio** del usuario o del hogar. El usuario puede usar el base tal cual, **copiarlo y modificarlo**, o crear lo suyo desde cero (como hizo en su Excel con claves `SAN-001`, `SNK-001`).

### 6.4 Flujo por pasos (para no abrumar al usuario)

El proceso completo es grande, así que se divide en **7 pasos cortos**, cada uno con una sola decisión. El usuario puede detenerse en cualquiera y retomar después.

| Paso | Pantalla | Decisión del usuario | Resultado |
|---|---|---|---|
| **1. Monto** | "¿Cuánto vas a gastar en comida esta semana?" (sugerido desde el Presupuesto, editable) | Confirmar o ajustar monto | Techo semanal |
| **2. Personas** | ¿Quiénes comen? ¿Cuántos tiempos de comida por día? ¿Qué días? | Marcar integrantes y tiempos | Número de porciones necesarias |
| **3. Preferencias** | Restricciones y gustos: alergias, vegetariano, "sin cerdo", ingredientes que no gustan, objetivo (económico, saludable, rápido) | Marcar filtros | Catálogo filtrado |
| **4. Opciones de menú** | La app propone **2–3 menús completos** (ej. "Económico", "Balanceado", "Variado") con su costo | Elegir uno | Menú base |
| **5. Ajustar menú** | Cuadrícula día × tiempo; tocar una casilla para **cambiar platillo** por otro del mismo tipo y ver cómo cambia el costo | Ajustar | Menú final |
| **6. Lista de compras** | Ingredientes **consolidados**, agrupados por sección del súper (frutas y verduras, lácteos, abarrotes, carnes…), con cantidad y costo | Revisar y descontar lo que ya tiene en casa | Lista final |
| **7. Compra y cierre** | Marcar lo comprado, registrar el **gasto real** (se envía a Gastos → Alimentación) | Confirmar compra | Plan vs. real |

### 6.5 Cómo la app "propone" menús dentro de un monto

Lógica de generación (reglas, no magia):

1. Calcular **presupuesto por porción-día**: `monto ÷ (personas × tiempos × días)`.
2. Filtrar el catálogo de platillos por preferencias/restricciones y por tiempo de comida (almuerzo, comida, merienda, cena).
3. **Armar el menú** eligiendo platillos que:
   - Mantengan el costo total ≤ monto.
   - **Compartan ingredientes** entre sí (menos desperdicio y menos compra; ej. el pan y el jamón sirven a varios platillos).
   - Eviten repetir el mismo platillo más de N veces seguidas (variedad).
4. Ofrecer **variantes de menú** (económico / balanceado / variado) como se indica en el paso 4.
5. Si el monto **no alcanza**, proponer: bajar porciones, sustituir ingredientes caros, reducir tiempos de comida o aumentar el monto.
6. Si **sobra**, proponer: mejorar platillos, agregar fruta/proteína, o mandar el excedente a ahorro.

### 6.5 bis Asistente de menús por monto (a detalle)

Esta sección baja a detalle el flujo de 6.4 y las reglas de 6.5. Es el corazón de Alimentación: **de un monto semanal salen 2 o 3 menús completos y una lista de compras**, en pasos cortos y sin obligar a terminar de una vez.

**1. Datos de entrada**

| Dato | De dónde sale | Si falta |
|---|---|---|
| **Monto semanal de comida** | Presupuesto (5.6 bis), editable en el paso 1 | Se pide |
| **Porciones por persona** | Hoja PORCIONES de la tabla de ejemplo: cada integrante y cuántas porciones de cada platillo | Se usa 1 porción por tiempo de comida |
| **Tiempos de comida y días** | Paso 2 (almuerzo, comida, merienda y cena; lunes a domingo) | Se asume 7 días y los tiempos usados la semana anterior |
| **Catálogo de platillos y recetas** | Base + propio (6.3), con padre → hijo y rendimiento (6.2) | Solo se proponen los platillos con receta completa y precio |
| **Precios** | Historial por comercio (6.10); si no hay, precio semilla marcado "por confirmar" | Se avisa cuántos precios están viejos |
| **Despensa** | Lo que sobró de compras anteriores (6.7 y 6.13) | Se asume vacía |
| **Reglas del plan de nutrición y restricciones** | 6.12 y filtros del paso 3 | Sin filtros |

**2. Tres costos que la app siempre distingue**

| Costo | Qué es | Para qué sirve |
|---|---|---|
| **Teórico (por consumo)** | Suma de porciones consumidas × costo por porción (6.2) | Comparar platillos y semanas |
| **De compra** | Presentaciones **enteras** que hay que comprar (se redondea hacia arriba) | Saber cuánto dinero sale de la cartera |
| **De compra neto** | Costo de compra **menos lo que ya hay en la despensa** | Lo que realmente se paga esta semana |

**Ejemplo con los datos reales de tu Excel** (3 porciones de `SAN-001` y 2 de `SNK-001`):

- **Costo teórico:** 3 × $20.51 + 2 × $56.92 = **$175.37**.
- **Costo de compra:** cada ingrediente se compra en presentación entera (1 jitomate de 1 kg, 1 lechuga, 1 mayonesa, 1 jamón, 1 pan, 1 queso, 1 yogurt, 1 de uvas, 1 de fresas, 1 de arándanos, 1 avena, 1 girasol, 1 linaza y 1 chía) = **$977.50**.
- **Diferencia:** **$802.13** queda como **sobrante en la despensa** (por ejemplo, del jitomate sobran 45 de 48 porciones, de los arándanos 32 de 34 y de la mayonesa 25 de 28).

Esto muestra por qué la app **no puede comparar solo el costo teórico con el monto**: con un monto de $200 el menú "cabe" en costo teórico, pero **no alcanza para comprar**. Y también muestra por qué **compartir ingredientes y usar la despensa** es lo que hace baratos a los menús reales: a la segunda semana, con esa despensa, el costo de compra neto sería mucho menor (salvo lo perecedero que se eche a perder).

**3. Cómo se compara contra el monto (modo de comparación)**

| Modo | Compara el monto con… | Cuándo conviene |
|---|---|---|
| **Por compra** *(propuesto por defecto en las primeras semanas)* | Costo de compra neto | Hogares que arrancan: es el dinero que sale |
| **Por consumo** | Costo teórico + una **reposición de despensa** semanal estimada | Hogares con despensa ya formada, para ver el gasto "parejo" semana a semana |

La app **explica el modo elegido** en la pantalla y deja cambiarlo. **Confirmado el 17/oct/2026:** se compara **por compra**.

**El inventario cuenta (decisión del 17/oct/2026):** si ya hay en la despensa **jamón, mayonesa** u otro ingrediente, **no entra al monto**: la lista de compras solo incluye lo que **falta**, y el costo de compra neto resta lo que ya hay. Reglas: (1) se descuenta **solo la cantidad que cubre la receta**; si el jamón alcanza para dos sándwiches y se necesitan tres, se compra lo que falta; (2) los **perecederos vencidos o por vencer** no se cuentan como disponibles (vida útil, 6.13); (3) el inventario se actualiza con las compras cerradas, con lo que se cocina y con la foto del refrigerador (6.13); (4) el menú **prefiere platillos que gastan lo que ya hay** antes de que caduque.

**4. Algoritmo de armado de menús (reglas, no magia)**

1. **Casillas:** se crea la cuadrícula día × tiempo con las porciones necesarias.
2. **Candidatos:** se filtra el catálogo por tiempo de comida, restricciones, reglas del plan (6.12) y que tengan precio vigente.
3. **Puntaje de cada platillo** para una casilla = (a) **costo de compra marginal** (lo que agregaría a la lista, considerando lo que **ya está en la lista o la despensa**), más (b) **penalización por repetición** (el mismo platillo más de N veces seguidas), más (c) **ajuste por reglas del plan** (por ejemplo, proteína suficiente, verdura diaria) y (d) **bonus por perecederos próximos a caducar** que ya se tienen.
4. **Perfiles de menú** (paso 4): el mismo método con pesos distintos.

| Perfil | Prioriza | Cuidado |
|---|---|---|
| **Económico** | Menor costo de compra y más ingredientes compartidos | Puede repetir platillos; se limita con N |
| **Balanceado** | Reglas del plan de nutrición y variedad de grupos | Cuesta más; se muestra la diferencia contra el económico |
| **Variado** | Máxima variedad de platillos | Suele cuestar más y generar más sobrante |

5. **Cierre de ajuste:** mientras el costo supere el monto, se sustituye el platillo con **mayor ahorro por cambio** (menos calidad percibida perdida); mientras sobre dinero, se **mejora** el platillo con mejor relación beneficio/costo.
6. **Consolidación y redondeo** a presentaciones enteras (6.7), restando despensa.
7. **Verificación final:** costo de compra neto ≤ monto (o se muestra el faltante y las opciones de 6.5, puntos 5 y 6).

**5. Si no alcanza o si sobra**

| Situación | Opciones que ofrece la app |
|---|---|
| **No alcanza** | Quitar un tiempo de comida, bajar porciones, sustituir ingredientes caros (con el ahorro de cada cambio), cambiar el comercio (mejor precio por producto, 6.10), usar más despensa o subir el monto (muestra de dónde saldría, según el Presupuesto) |
| **Sobra** | Mejorar un platillo, agregar fruta o proteína, **guardar el excedente para la semana siguiente** o mandarlo al remanente (5.6 bis) |
| **Hay sobrante grande en la despensa** | Propone menús de "aprovechar la despensa" para la semana siguiente |

**6. Lista de compras**

- Agrupada por **sección del súper** con los prefijos de 6.6, con cantidad, presentación, precio de referencia y **comercio sugerido** (6.10).
- Cada renglón muestra **"ya tienes"** si la despensa cubre la cantidad, y se puede marcar como comprado, cambiar de marca o de presentación (se recalcula el rendimiento).
- Si el comercio sugerido cambia **más de un 15 %** el total, la app lo avisa antes de ir al súper (umbral por defecto, editable).
- **Dividir en varias compras** (por ejemplo, perecederos a mitad de semana).
- Al **cerrar la compra**, se envía a Gastos → Alimentación el **gasto real** (dividido por líneas si el ticket trae varios rubros), se actualizan los precios y la despensa, y se calcula **plan contra real**.

**7. Pantallas de los 7 pasos**

| Paso | Pantalla | Elemento clave |
|---|---|---|
| 1 | Monto | Control deslizante con monto sugerido, mínimo viable y "último gasto real" |
| 2 | Personas y tiempos | Casillas por persona y día |
| 3 | Preferencias | Filtros y chips de restricciones |
| 4 | Opciones de menú | Tres tarjetas con costo, costo por persona y semáforo contra el monto |
| 5 | Ajustar menú | Cuadrícula editable con el costo actualizándose |
| 6 | Lista de compras | Secciones, "ya tienes", comercio sugerido |
| 7 | Compra y cierre | Marcar lo comprado y registrar el gasto real |

**8. Datos nuevos que necesita**

`PlanMenu` (semana, monto, modo de comparación, perfil elegido), `PlanMenuCasilla` (día, tiempo, platillo, porciones), `ListaCompra` y `ListaCompraRenglon` (ingrediente, presentación, cantidad, precio de referencia, comercio, comprado), `Despensa` (ingrediente, porciones restantes, fecha de compra, caducidad estimada) y `CompraReal` (vínculo con el gasto). Se detallan en la sección 7.

**9. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| M1 | Menú con 3 `SAN-001` y 2 `SNK-001` con precios del Excel | Costo teórico **$175.37**, costo de compra **$977.50** |
| M2 | Mismo menú con despensa vacía y monto de $200 | Aviso: alcanza en costo teórico, **no** en compra; ofrece opciones |
| M3 | Segunda semana con la despensa de la primera | El costo de compra neto baja y la lista marca "ya tienes" |
| M4 | Restricción "sin lácteos" | `LAC-001`, `LAC-002` y los platillos que los usan desaparecen de las propuestas |
| M5 | Subir el monto | La app propone mejorar platillos o guardar el excedente |
| M6 | Cambiar un platillo en el paso 5 | El costo y la lista se recalculan al instante |
| M7 | Cerrar la compra con un ticket de otra cifra | El gasto real se registra y se muestra plan contra real |
| M8 | Precio viejo (más de 30 días, valor por defecto) | Se marca "por confirmar" y se avisa antes de dar el menú como definitivo |

**Lo que no se asume:** que todo lo sobrante se conserva. Los **perecederos** tienen **vida útil estimada**; la app no los cuenta como despensa aprovechable después de ese plazo, y lo que se echa a perder se registra como **desperdicio**. Los valores de vida útil se capturan en el catálogo y son **por confirmar**; no se inventan.

### 6.6 Entidades y claves (extendiendo el Excel)

El Excel ya usa **claves con prefijo** (`SAN-`, `SNK-`, `VER-`, `FRU-`, `LAC-`, `SEM-`, `PAN-`, `EMB-`, `ADE-`, `ENS-`). Se recomienda **mantener esa convención**, porque permite agrupar por sección del súper:

| Prefijo | Significado | Sección de compra |
|---|---|---|
| `VER` | Verduras | Frutas y verduras |
| `FRU` | Frutas | Frutas y verduras |
| `LAC` | Lácteos | Refrigerados |
| `EMB` | Embutidos | Refrigerados / carnes frías |
| `PAN` | Panadería | Panadería |
| `SEM` | Semillas y cereales | Abarrotes |
| `ADE` | Aderezos y condimentos | Abarrotes |
| `SAN` | Sándwiches (platillo) | — |
| `SNK` | Snacks / bowls (platillo) | — |
| `ENS` | Ensaladas (platillo) | — |

**Platillo** = nodo "padre". **Ingrediente** = nodo "hijo". Un platillo puede contener a otro (ej. un combo contiene un sándwich) → la estructura **padre-hijo** del Excel soporta recetas anidadas.

### 6.7 Cálculos adicionales que conviene incluir

- **Consolidación de insumos:** sumar la cantidad de un mismo ingrediente en todos los platillos de la semana y **redondear hacia arriba a presentaciones enteras** (no se compra 0.4 de un frasco). El costo real de compra será mayor que el costo "por porción" por el sobrante; la app debe mostrar ambos: **costo teórico** y **costo de compra**.
- **Inventario / despensa:** lo que sobra de una presentación (ej. media mayonesa) se descuenta de la siguiente lista.
- **Desperdicio:** estimación opcional por ingrediente perecedero.
- **Equivalencias de unidad:** kg, g, pieza, frasco; normalizar para sumar.
- **Costo por persona y por día:** útil para comparar semanas.
- **Precios actualizables:** el precio de cada ingrediente tiene fecha; la app avisa cuando está "viejo" y permite actualizarlo (manual, o por foto del ticket más adelante).
- **Información nutricional (fase posterior):** calorías/macros por platillo para planes saludables.

### 6.8 Pantallas clave del módulo

- **Catálogo de ingredientes** (precio, presentación, rendimiento).
- **Catálogo de platillos/recetas** (ingredientes, porciones, costo, tiempo de comida).
- **Asistente semanal** (los 7 pasos).
- **Menú semanal** (cuadrícula día × tiempo, equivalente a la hoja MENU SEMANAL).
- **Lista de compras** (agrupada por sección, con casillas).
- **Plan vs. real de alimentación.**

### 6.9 Captura de datos y precios (4 vías)

La misma lógica sirve para **gastos, tickets, ingredientes y precios**. El usuario elige la vía que le acomode; la app **siempre muestra lo detectado y pide confirmación** antes de guardar (el reconocimiento puede fallar).

| Vía | Cómo funciona | Ejemplo |
|---|---|---|
| **1. Manual** | Formularios rápidos con autocompletado de ingredientes, categorías y tiendas | Escribir "jitomate roma, 1 kg, $29" |
| **2. Voz** | Se dicta una frase en español; la app la interpreta (monto, concepto, categoría, cuenta) y la muestra para confirmar | "Gasté 150 pesos en gasolina con la tarjeta de Ana" |
| **3. Imagen** | Ver abajo | Foto de un ticket |
| **4. Precios de supermercados** | Ver abajo | Comparar dónde cuesta menos la lista |

**Imagen (3 modalidades de entrada)**

- **Captura de pantalla:** se importa una imagen (ticket digital, carrito de una app de súper) y se extrae el texto.
- **Foto:** se fotografía un ticket, factura o etiqueta; se detectan productos, cantidades y precios.
- **Cámara con detección de texto:** lectura en vivo (OCR) apuntando a la etiqueta de precio del anaquel.
- **QR:** se escanea el QR del ticket o comprobante; según el comercio puede traer datos como emisor, fecha y total, y el detalle de conceptos depende de lo que incluya el comprobante. Como extensión natural, el **código de barras** identifica el producto exacto.
- El resultado alimenta: **gasto real** (Gastos y Alimentación), **precio de ingrediente** (con fecha y tienda) y **evidencia** adjunta al movimiento.

**Precios de supermercados**

- **Fuentes (de más a menos control):** 1) precios capturados por el propio usuario (manual, voz, imagen); 2) catálogo base de la app; 3) precios aportados por otros usuarios de la misma región; 4) fuentes públicas (PROFECO, SNIIM, INEGI y Open Food Facts; ver 6.11). *Antes de usar fuentes externas hay que verificar su disponibilidad y sus condiciones de uso.*
- Cada precio guarda: **tienda, ciudad, fecha, fuente y confianza**. Los precios viejos se marcan para actualizar.
- Se **normaliza por unidad** (precio por kg, litro o pieza) para poder comparar presentaciones distintas.
- **Uso en la app:** estimar el costo de un menú, sugerir sustitutos más baratos y proponer **en qué tienda conviene comprar** cada producto de la lista. La comparación contra compras anteriores, las alertas de precio superior y la curva de ahorro o sobregasto se describen en **6.10**.

### 6.10 Inventario e histórico de precios: comparación, alertas y curva de desviación

**Para qué:** que al ir al supermercado, o al hacer **cualquier otra compra**, la app compare el precio que se ve en ese momento contra **lo que se pagó antes**, identificando **en qué comercio**, y avise cuando el precio es superior. Con el tiempo, el historial permite entender la **curva de desviación**: cuánto se ahorra o se sobregasta por el precio.

> Este módulo es **transversal**: sirve para alimentos, limpieza, farmacia, ropa o cualquier producto que se compre con frecuencia. No se limita a ingredientes de recetas.

**Qué se guarda (inventario de precios)**

- **Comercio:** nombre, cadena, sucursal, ciudad y, opcionalmente, ubicación.
- **Producto:** nombre normalizado, marca, presentación, unidad de medida y, si existe, código de barras.
- **Registro de precio:** producto, comercio, precio pagado o visto, cantidad, **precio por unidad normalizado** (por kg, litro o pieza), fecha, vía de captura (manual, voz, imagen, QR, ticket) y si estaba en **promoción**.
- **Historial completo:** los precios **no se sobrescriben**; cada compra o captura agrega un punto a la serie del producto en ese comercio (igual que el libro de movimientos: no se borra, se corrige con anulación).
- **Existencias (despensa):** cuánto queda en casa de cada producto, para no comprar de más y descontarlo de la lista (ver 6.7).

**Precio de referencia (contra qué se compara).** El usuario elige uno; por defecto se muestran los dos primeros:

| Referencia | Significado |
|---|---|
| **Último pagado en este comercio** | Lo que costó la última vez en la misma tienda |
| **Último pagado en cualquier comercio** | La compra más reciente, sin importar dónde |
| **Promedio de las últimas N compras** | Precio típico (ej. últimos 90 días) |
| **Mínimo histórico** | El precio más bajo que se ha pagado |
| **Mejor precio vigente en otro comercio** | El más barato conocido y reciente |

**Identificación del producto y del precio (cámara y lector)**

El objetivo es que **un solo escaneo identifique el producto y capture su precio**, con el menor esfuerzo posible. La app combina varios métodos y **elige el mejor disponible**; si uno falla, pasa al siguiente.

| Método | Qué identifica | Cómo funciona |
|---|---|---|
| **Lector de código de barras** | Producto exacto (marca, presentación) | Se escanea el código del empaque o de la etiqueta del anaquel; se busca en el catálogo de productos. Es el método **más confiable** |
| **Lectura de la etiqueta de precio (OCR)** | Precio, precio por unidad y, muchas veces, nombre del producto | La cámara lee en vivo el texto de la etiqueta del anaquel |
| **Escaneo en un paso** | Producto **y** precio | Al apuntar a la etiqueta del anaquel, el código de barras da el producto y el texto da el precio |
| **Reconocimiento por cámara del empaque** | Producto, de ser posible | Se apunta al envase; la app lee su texto (marca, nombre, contenido) y lo compara con el catálogo. Es un método de **mejor esfuerzo**: siempre pide confirmación |
| **Productos sin código** (frutas, verduras, granel) | Producto y precio por kg | Se elige de una lista visual o se lee el **código de la báscula o PLU**; el precio se toma del peso y la etiqueta |
| **QR del ticket o comprobante** | Comercio, fecha y total; el detalle depende del comprobante | Complementa o confirma lo capturado en el anaquel (ver 6.9) |
| **Manual o voz** | Cualquier producto | Respaldo cuando lo demás no funciona |

**Reglas de identificación**

- La app muestra siempre **lo detectado con un nivel de confianza** (producto, presentación y precio) y **pide confirmación con un toque**. Nada se guarda sin confirmar si la confianza es baja.
- Un **producto desconocido** se completa una sola vez (nombre, marca, presentación); queda en el catálogo del hogar y se reconoce las siguientes veces. Las correcciones del usuario se guardan como **alias** para mejorar la coincidencia.
- **Precio de anaquel vs. precio en caja:** el precio escaneado en el anaquel puede diferir del cobrado. Al registrar el ticket (foto o QR) la app **concilia** ambos y deja como válido el precio cobrado, avisando si hubo diferencia.
- Se procesa **en el teléfono** siempre que sea posible, para que funcione sin internet y proteger la privacidad. Qué parte pasa por la nube es una decisión pendiente (ver 12.2).
- El **resultado alimenta directamente** la tarjeta de comparación y las alertas de abajo.

**Fases:** el **lector de código de barras** y el historial manual entran con Alimentación (Fase 3); la **lectura de etiquetas por cámara, el escaneo en un paso y el reconocimiento del empaque** llegan en la Fase 5.

**Flujo "En el súper" (comparación al momento de comprar)**

1. El usuario abre el modo **En el súper** (o la lista de compras) y **apunta la cámara** a la etiqueta o al producto, o escanea el código de barras; si no es posible, dicta o escribe el precio.
2. La app **identifica el producto** y lo confirma con el usuario.
3. Muestra una **tarjeta de comparación**:

```
Yogurt griego 650 g · Comercio actual: Súper A · $62.00
├─ Último pagado aquí:        $55.00   (hace 12 días)  ▲ +12.7 %
├─ Último pagado en Súper B:  $53.00   (hace 5 días)   ▲ +17.0 %
├─ Promedio 90 días:          $56.00                    ▲ +10.7 %
└─ Mínimo histórico:          $49.00   (Súper C)       ▲ +26.5 %
⚠ Precio superior: en Súper B lo pagaste $9.00 más barato
```

4. El usuario decide: **comprar**, **buscar sustituto** (producto de menor precio por unidad) o **dejarlo para otro comercio**.
5. Al confirmar la compra, el precio se **agrega al historial** automáticamente.

**Alertas de precio**

| Alerta | Cuándo se dispara | Ejemplo |
|---|---|---|
| **Precio superior** | El precio es mayor que la referencia por encima de un umbral (configurable: p. ej. **+5 %** ámbar, **+10 %** rojo) | "Está 12 % arriba de lo que pagaste" |
| **Mejor precio** | El precio iguala o baja del mínimo histórico | "Es el precio más bajo que has visto" |
| **Mejor comercio** | Otro comercio tiene el producto más barato recientemente | "En Súper B costó $9 menos" |
| **Precio desactualizado** | El último precio conocido es muy viejo | "No tienes precio de este producto desde hace 60 días" |
| **Lista de compras por encima** | El total estimado supera el de la última compra similar o el monto semanal | "Tu lista cuesta $180 más que la semana pasada" |

Las alertas se pueden silenciar por producto o categoría y ajustar el umbral.

**Curva de desviación (ahorro o sobregasto)**

Cada línea comprada se compara contra su precio de referencia:

```
desviación_línea  = (precio_unitario_pagado − precio_unitario_referencia) × cantidad
desviación_semana = Σ desviación_línea
desviación_%      = desviación_semana ÷ (gasto a precio de referencia)
```

- **Desviación positiva = sobregasto** (se pagó más que la referencia); **negativa = ahorro**.
- **Curva semanal:** línea con la desviación de cada semana y la **desviación acumulada**, para ver si el hogar compra cada vez mejor o peor.
- **Por producto, categoría y comercio:** qué productos subieron más, qué comercio resulta más caro o más barato para la misma canasta.
- **Índice de precios del hogar ("inflación personal"):** costo de la misma canasta de productos en el tiempo, comparado con un periodo base.
- **Efecto precio vs. efecto cantidad:** si el gasto de Alimentación se pasó del presupuesto, la app separa cuánto fue porque **los precios subieron** y cuánto porque **se compró más**.

```
variación_gasto = efecto_precio + efecto_cantidad
efecto_precio   = Σ (precio_actual − precio_anterior) × cantidad_actual
efecto_cantidad = Σ (cantidad_actual − cantidad_anterior) × precio_anterior
```

**Reglas**

- Siempre se compara **precio por unidad normalizada** (por kg, litro o pieza); no se comparan presentaciones distintas por precio total.
- Las **promociones** se marcan y, por defecto, no sustituyen al precio habitual como referencia.
- Todo precio leído por imagen o voz se **confirma antes de guardarse** (el OCR puede equivocarse).
- Un precio muy viejo se muestra con aviso de antigüedad y no se usa como única referencia.
- Si el comercio no está identificado, la compra se guarda como "sin comercio" y se invita a completarlo.
- Los precios aportados por **otros usuarios** (comunidad) son opcionales y anónimos; los del propio hogar tienen siempre prioridad.

**Pantallas:** ficha de producto con **gráfica de historial por comercio**, modo **En el súper** (cámara, tarjeta de comparación y semáforo), lista de compras con precio de referencia y **mejor comercio sugerido** por producto, reporte de **desviación** (curva semanal, ranking de productos y comercios, índice del hogar), gestión de comercios.

**Se conecta con:** Alimentación (el costo de los platillos se actualiza con el último precio), Gastos (cada ticket genera puntos de precio), Presupuesto (explica desviaciones por precio), Cuentas de gasto (la desviación se atribuye al rubro).

**Fases:** el **historial manual con comparación y alerta de precio superior** entra junto con Alimentación (Fase 3); la **captura por cámara, voz y QR** y la **curva de desviación avanzada** llegan en la Fase 5.

### 6.11 Fuentes de precios en México y comercios de la zona (investigación)

> Investigación hecha el **14/oct/2026** con información pública. Los datos de comercios vienen de Google Maps y pueden cambiar. Las condiciones de cada fuente se revisaron de forma general: **hay que verificarlas antes de integrarlas.**

**A. Fuentes de precios**

| Fuente | Qué ofrece | Lo que se encontró | Uso recomendado |
|---|---|---|---|
| **PROFECO, Quién es Quién en los Precios** (qqp.profeco.gob.mx) | Precios de unos 3,000 productos básicos; filtra por estado, ciudad y municipio; muestra tiendas, precio mínimo y máximo y fecha de monitoreo; permite armar y descargar listas | Los textos consultados no mencionan datos abiertos ni API | **Referencia para el usuario.** Antes de integrarla, preguntar a PROFECO si permite reutilizar sus datos |
| **PROFECO histórico en datos abiertos** (datamx.io y api.datos.gob.mx) | Registro de más de 2,000 productos desde 2015 | **Última actualización: 28/jul/2019** y sin licencia indicada | **No sirve como fuente vigente**; solo para pruebas con datos históricos |
| **SNIIM** (Secretaría de Economía) | Precios del día en centrales de abasto: frutas, hortalizas, huevo, granos, carnes y pescado | No se encontró API ni descarga masiva en la página principal; no se confirmó si cubre Guanajuato o el Bajío | Referencia de **precio mayorista** para frutas y verduras, a verificar |
| **INEGI, API de Indicadores (INPC)** | Series de inflación; el área geográfica (nacional, estatal o municipal) depende del indicador | Requiere token de registro; no se confirmó el INPC para ciudades de la zona ni las condiciones de uso | Comparar el **índice de precios del hogar** (6.10) contra la inflación oficial |
| **Open Food Facts** | Base abierta de productos por código de barras (nombre, marca, contenido, imágenes) | Datos bajo licencia ODbL y DbCL; imágenes CC BY-SA; exige identificarse con un User-Agent; límite de unas **15 consultas por minuto** por producto; lo aportan voluntarios, **sin garantía de exactitud**; para uso intenso recomiendan descargar los archivos completos | **Identificar el producto a partir del código de barras.** No trae precios por tienda. Verificar cuántos productos mexicanos tiene y complementar con el catálogo propio |
| **Open Prices** (de Open Food Facts) | Precios colaborativos: producto, precio, tienda, ciudad, fecha y evidencia (ticket o etiqueta) | Datos bajo licencia ODbL; se descarga un archivo completo (Parquet, unos 32 MB, actualizado a diario) y se contribuye desde la app de Open Food Facts. **No se sabe cuántos precios hay en México** | Fuente **complementaria gratuita**, y destino **opcional** si el hogar quiere compartir sus precios. Verificar la cobertura de la zona |
| **Sitios web de las cadenas** (Walmart, Bodega Aurrerá, Sam's Club) | Precios en línea | **No se encontró una API pública ni un programa de datos para consumidores**; solo aparecieron extractores de terceros. No se pudieron leer los términos de uso (ver abajo) | **No extraer datos de forma automática.** Usar las capturas del hogar |
| **Capturas del propio hogar** (ticket, etiqueta, QR, voz) | Precio real pagado, con comercio y fecha | Fuente propia | **Fuente principal**: es la que mejor refleja las tiendas de la zona |

**Conclusión:** para San Miguel de Allende, Comonfort y Celaya, la base serán **las capturas del propio hogar**; PROFECO sirve como **referencia**, Open Food Facts para **reconocer productos** y SNIIM e INEGI como **contexto** (mayoreo e inflación).

**¿Las tiendas en línea (Walmart, Bodega Aurrerá, Sam's Club) comparten su información?** No encontré que lo hagan. Lo que sí se verificó:

- **No hay API pública ni programa de datos para consumidores.** La búsqueda solo devolvió extractores hechos por terceros; no apareció un portal oficial para desarrolladores de Walmart de México, Bodega Aurrerá o Sam's Club.
- **robots.txt de walmart.com.mx:** pide a los programas automáticos no entrar al carrito, la cuenta, el pago ni a las búsquedas (con una excepción), y publica mapas del sitio. Es una **indicación técnica, no una autorización ni una prohibición legal**.
- **No pude leer los términos y condiciones.** La página de Bodega Aurrerá que abrí devolvió "esta página ya no existe", así que **no puedo afirmar qué dicen** sobre copiar datos. Tampoco revisé específicamente el sitio de Sam's Club.
- **Precio en línea y precio en tienda pueden diferir.** La app toma como válido el precio que el usuario ve y paga en la tienda.

**Recomendación:** no extraer datos de forma automática. Si algún día se quisiera, hacerlo solo con **autorización por escrito** de la cadena. Mientras tanto, **la fuente principal son las fotos y capturas del hogar**, y PROFECO y Open Prices sirven de apoyo.

**B. Comercios de la zona (punto de partida)**

Sirve para precargar el catálogo de comercios. No es una lista exhaustiva. En la búsqueda **no apareció** un Costco ni un Sam's Club en San Miguel de Allende; los más cercanos que aparecieron están en Celaya.

| Municipio | Comercio | Tipo | Ubicación de referencia |
|---|---|---|---|
| San Miguel de Allende | City Market | Supermercado gourmet (grupo La Comer) | Salida a Celaya 82, La Lejona |
| San Miguel de Allende | La Comer | Supermercado | Carretera a Celaya 2, La Lejona |
| San Miguel de Allende | Soriana Súper | Supermercado | Libramiento José Manuel Zavala 165, La Luciérnaga |
| San Miguel de Allende | Bodega Aurrera | Tienda de descuento (Walmart) | Camino Real a la Estación 2, Centro |
| San Miguel de Allende | Mercado Ignacio Ramírez | Mercado (frescos, comida y artesanías) | Colegio s/n, Centro |
| San Miguel de Allende | Mercado de San Juan de Dios | Mercado local | San Rafael 7, Centro |
| San Miguel de Allende | Mercado Sano | Mercado de productos saludables | Ancha de San Antonio 123 |
| Comonfort | Mi Bodega Aurrera | Tienda de descuento | Salida a Celaya 1C, Centro |
| Comonfort | Neto | Autoservicio pequeño | Vicente Guerrero 46, Centro |
| Comonfort | Abarrotes de barrio (por ejemplo "El Profe", "El Grangenito", "Doña Chuy") | Tienda de barrio | Varias |
| Celaya | Costco Wholesale | Club de precios | Av. Tecnológico 651 |
| Celaya | Sam's Club | Club de precios | Av. Irrigación 200 |
| Celaya | Walmart (2 sucursales) | Hipermercado | Av. Irrigación 200 y Eje Nor-Poniente 801 |
| Celaya | Chedraui Celaya Campestre | Supermercado | Puerta de Oro del Bajío 203 |
| Celaya | Soriana Híper (3 sucursales) | Hipermercado | 12 de Octubre 200; Av. México-Japón con Av. Tecnológico; Av. Juan José Torres Landa 107 |
| Celaya | Bodega Aurrera | Tienda de descuento | Francisco Juárez Albino García 514 |
| Celaya | Mercado Hidalgo | Mercado | Blvd. Adolfo López Mateos, Centro |

**Qué implica para la app**

- **Cadena y sucursal:** varias cadenas (Bodega Aurrera, Soriana, Walmart, La Comer) tienen tiendas en más de un municipio. El comercio se modela como **cadena → sucursal**, porque el precio puede cambiar de una sucursal a otra.
- **Comonfort** tiene pocas cadenas (Bodega Aurrera y Neto) y muchas tiendas de barrio: debe poder registrarse un comercio genérico ("Tienda de barrio") sin código de barras.
- **Mercados:** los precios no siempre están etiquetados y varían por puesto; conviene capturarlos por **voz o manualmente, en precio por kilo**, y registrar el puesto o la zona del mercado.
- **Comparar entre municipios:** al planear la compra grande, la app puede comparar Celaya (clubes de precios e hipermercados) contra lo local. Una mejora futura es sumar el **costo del traslado** (gasolina y tiempo) a esa comparación.
- **Arranque:** cada hogar marca como favoritos los **6 a 8 comercios** que de verdad usa; el resto se agrega al comprar.

**C. Datos semilla (libro Excel incluido)**

Se entrega el libro **DATOS_SEMILLA_PRESUPUESTO.xlsx** para precargar la app. **No trae precios inventados:** los únicos precios son los de tu Excel (sin fecha ni comercio), y tampoco trae códigos de barras, porque se capturan al escanear.

| Hoja | Contenido |
|---|---|
| **Comercios** | 19 comercios de San Miguel de Allende, Comonfort y Celaya, más 3 genéricos (tienda de barrio, mercado o tianguis, sin comercio), con columnas para marcar **favorito** y **verificado** |
| **Categorías** | El árbol completo de 5.2 (128 filas), con Limpieza del hogar y Cuidados de largo plazo |
| **Productos base** | 90 productos básicos con clave, categoría, unidad y presentación sugerida; **14 llevan el precio de tu Excel** |
| **Platillos y recetas** | Las recetas de tu Excel (`SAN-001`, `SNK-001`) con el costo por porción calculado por fórmula; `ENS-001` sin ingredientes |
| **Porciones** y **Costo semanal** | Reproducen tu hoja PRESUPUESTO SEMANAL: el costo semanal total sale por fórmula |
| **Historial de precios** | Tabla vacía lista para capturar, con listas desplegables de comercio y producto |
| **Claves** | Prefijos de claves; los de tu Excel y los nuevos (`ABA`, `CAR`, `BEB`, `LIM`, `HIG`, `CUI`) |

**Cómo se construye la base de precios con imágenes (en el comercio y en casa)**

1. **En casa, con el ticket:** se fotografía el ticket de la compra; la app lee las líneas (OCR en el teléfono), el usuario **confirma** y se crean los precios con comercio y fecha.
2. **En la tienda, con la etiqueta o el código de barras:** se escanea, la app compara contra lo anterior (6.10) y, al comprar, guarda el precio.
3. **Producto nuevo:** la primera vez se pide nombre y presentación; se guardan el código de barras y los alias para reconocerlo después.
4. **Con unas semanas de uso** ya habrá historial de los productos que se compran con frecuencia, y las alertas de precio superior empiezan a servir.
5. Las **fotos se quedan en el teléfono**; a la nube solo suben los datos de texto.

**Platillos del Bajío:** pendiente validarlos con el hogar (por ejemplo, enchiladas mineras, gorditas, caldo de pollo o huevo a la mexicana). No vienen en el libro.

### 6.12 Plan de nutrición y conexión con una app de hábitos

> **Estado (v6):** se eligió el escenario **C (híbrido)**. Por ahora **no hay nutriólogo**: las reglas del plan (restricciones, alergias, preferencias) las define el usuario. Las dos apps se programarán con Claude Code; la de hábitos **hoy solo existe en papel** (ver 6.15).

**Dos papeles distintos**

| Papel | Responde a | Qué hace |
|---|---|---|
| **Plan** (qué comer) | "¿Qué como esta semana?" | Define reglas, esquema de comidas, platillos y recetas; propone menús; calcula costo y lista de compras |
| **Seguimiento** (cómo voy) | "¿Lo cumplí?" | Registra qué se comió, hábitos, agua y peso; mide constancia y cumplimiento |

**Quién diseña el plan: tres escenarios**

| Escenario | Cómo funciona | Pros | Contras |
|---|---|---|---|
| **A. Esta app diseña** *(punto de partida)* | Arma menús y recetas dentro de las reglas del plan, con presupuesto, precios y despensa; la app de hábitos da seguimiento | Es la única que conoce el presupuesto, los precios por comercio y la despensa: menú y compra salen juntos | Hay que construir el catálogo de platillos; si hay metas nutricionales numéricas, las debe definir un profesional o la otra app |
| **B. La app de hábitos o nutrición diseña** | Esa app define el plan; esta lo importa y lo convierte en menú costeado y lista de compras | Aprovecha una herramienta que ya sabe de nutrición | Depende de que esa app permita exportar el plan; no conoce los platillos ni los precios locales |
| **C. Híbrido** | El usuario, un profesional o la otra app definen **reglas**; esta app propone menús que las cumplan; la otra mide el cumplimiento | Reparte bien las responsabilidades y sirve con cualquier app | Exige acordar un formato de intercambio |

**Decisión:** **escenario C (híbrido)**. El usuario define las **reglas**; esta app propone menús que las cumplen, con presupuesto, precios y despensa; la app de hábitos mide el cumplimiento. Como el formato de intercambio es neutro, se puede pasar a A o B sin rehacer nada.

**Regla de seguridad.** El plan nutricional lo define **el usuario o un profesional de la salud**. La app propone menús **dentro de esos límites** y **no da indicaciones médicas** ni calcula dietas por su cuenta. Los casos especiales (por ejemplo, la alimentación de una persona con Alzheimer: texturas, espesantes y restricciones) **deben venir indicados por el profesional**; se registran en las reglas del plan y en *Alimentación especial* (5.2).

**Sin nutriólogo (por ahora):** la app **no fija metas numéricas** (calorías, proteínas) ni dietas terapéuticas; solo aplica las reglas simples que escribe el usuario. Si más adelante participa un profesional, sus indicaciones se cargan como reglas con autor "profesional".

**Cómo propone el menú de acuerdo con el plan**

1. Lee las reglas: restricciones, alergias, preferencias, tiempos de comida por día y, si existen, metas definidas por el profesional.
2. Filtra el catálogo de platillos por esas reglas y por tiempo de comida.
3. Arma el menú dentro del presupuesto semanal (6.5), compartiendo ingredientes para reducir compra y desperdicio.
4. Muestra un **semáforo de cumplimiento**: ✔ cumple, ⚠ requiere sustitución, ✖ no cumple.
5. Permite **sustituciones equivalentes** (por ejemplo, cambiar una proteína por otra) y muestra el efecto en el costo.
6. Si el plan trae metas numéricas (calorías, proteínas), **las muestra pero no las calcula**, salvo que el platillo traiga datos nutricionales (fase posterior, 6.7).
7. Genera la lista de compras con precios y el mejor comercio (6.10).

**Formato de intercambio del plan (neutro, versionado)**

Sirve en las dos direcciones. El formato principal es **JSON**; para personas, el mismo contenido en **Excel o CSV**, con hojas como las del libro de datos semilla.

| Bloque | Contenido |
|---|---|
| **Metadatos** | Versión del formato, fecha, vigencia, autor del plan (usuario, profesional o app) e integrante al que aplica |
| **Reglas** | Restricciones, alergias, preferencias, ingredientes excluidos, observaciones del profesional y metas opcionales |
| **Esquema semanal** | Días por tiempos de comida, con el tipo de platillo requerido (por ejemplo, "proteína y verdura") o un platillo fijo |
| **Platillos** | Clave, nombre, tiempo de comida, porciones, etiquetas, ingredientes (clave, cantidad, unidad) y equivalencias permitidas |
| **Seguimiento (de regreso)** | Por día y tiempo de comida: cumplido, parcial, sustituido u omitido, platillo real y nota; opcional: peso y agua |

**Cómo conectar las dos apps sin costo**

| Vía | Qué permite | Pros | Contras |
|---|---|---|---|
| **1. Archivo compartido** (JSON o Excel/CSV) con "Compartir" de Android | Enviar el plan y recibir el seguimiento | Costo cero; sin infraestructura; sirve con cualquier app que acepte el archivo | Es manual |
| **2. Enlaces entre apps** | Abrir la otra app en una pantalla concreta ("Plan de hoy", "Registrar comida") | Cero costo; fluido | Cada app debe habilitar sus enlaces |
| **3. Mismo proyecto de Firebase y misma cuenta** (si las dos apps son tuyas) | Compartir plan y seguimiento en tiempo real | Automático; sin servidores nuevos | Comparten la cuota gratuita; hay que cuidar las reglas de seguridad |
| **4. Health Connect de Android** | Compartir, con permiso del usuario, registros de **nutrición, hidratación y peso** entre apps | Plataforma de Android para datos de salud; compatible con Android 9 o superior; los registros de nutrición admiten tipo de comida y nutrientes como calorías y macronutrientes | **No transporta recetas, platillos ni presupuesto.** Si la app de hábitos usa Google Fit, esa API tiene soporte solo hasta finales de 2026. No encontré costo para desarrolladores en la documentación consultada: verifica las políticas de Google Play al publicar |

**Recomendación:** empezar con **1 (archivo JSON) y 2 (enlaces)**, que sirven con cualquier app; si las dos apps son tuyas, pasar a **3**; y usar **4** solo para peso, agua y comidas registradas, si la app de hábitos lo soporta.

**Datos que esta app necesita para trabajar con un plan** (en gran parte ya previstos): etiquetas de platillos (tiempo de comida, tipo y alérgenos), equivalencias, tipo de ingrediente, restricciones por integrante y porciones por integrante (6.1).

### 6.13 Inteligencia artificial: recetas e inventario con foto del refrigerador

**Principio:** la IA **propone**; la persona **confirma**. Ningún resultado de IA se guarda sin pasar por una pantalla de revisión (igual que la captura de 6.9). Y lo que debe ser exacto **no lo calcula la IA**: costos, totales, presupuesto y cumplimiento de alergias los calcula la app con reglas fijas.

**A. Recetas y menús con IA**

| Uso | Qué hace la IA | Qué hace la app (sin IA) |
|---|---|---|
| Sugerir platillos | Propone platillos nuevos o variantes con lo que hay en la despensa y las reglas del plan | Calcula costo por porción con los precios del historial (6.10) y lo compara con el presupuesto |
| Sustituir ingredientes | Sugiere equivalentes | Verifica alergias y exclusiones con **reglas fijas** y muestra el efecto en el costo |
| Aprovechar lo que hay | "Con esto en el refri, ¿qué cocino?" | Marca qué falta y lo agrega a la lista de compras |
| Redactar la receta | Pasos y tiempos | Guarda la receta como **platillo del catálogo**, marcada como "generada por IA" y pendiente de revisión |

Reglas: la IA recibe solo las **reglas del plan** y los **ingredientes**, nunca datos financieros ni de salud; toda receta nueva requiere **aprobación** antes de entrar al catálogo; y para el caso del familiar con Alzheimer, **la IA no propone texturas ni dietas especiales**: eso queda en las reglas que escribe el usuario (6.12).

**B. Inventario con foto del refrigerador**

1. Tomas una o varias fotos (puerta abierta, estantes, cajones).
2. La IA detecta **productos y cantidad aproximada**.
3. La app los empata con el catálogo de **Productos base** (clave, unidad).
4. Pantalla de revisión: corregir, quitar, agregar o fusionar; lo que no reconoce queda como "sin identificar".
5. Al confirmar, se actualiza **Existencia (despensa)** y el menú y la lista de compras dejan de pedir lo que ya hay.

Límites que hay que asumir: los empaques tapados, las bolsas y los recipientes sin etiqueta se identifican mal; la cantidad es **estimada**; y la **caducidad** no se lee con confiabilidad. Por eso siempre hay confirmación, y el código de barras (6.9) sigue como vía exacta. Se puede mejorar enseñando a la app: cada corrección se guarda como alias del producto.

**Dónde corre la IA (costo cero y privacidad)**

| Opción | Pros | Contras |
|---|---|---|
| **En el teléfono** (ML Kit: códigos de barras y texto, ya previstos) | Sin costo, sin red, privado | Reconoce texto y códigos, **no** entiende un refrigerador completo ni genera recetas |
| **IA en la nube con plan gratuito** (Gemini mediante Firebase AI Logic; la documentación de Firebase indica que su nivel gratuito **no pide forma de pago y el proyecto sigue en Spark**) | Entiende fotos y redacta recetas; sin costo inicial | **Límites del nivel gratuito**: esa página no da cifras, hay que consultarlas al momento de construir. La documentación de Gemini consultada **no aclara cómo se usan los datos en el nivel gratuito**; para el nivel de pago sí dice que no se usan para mejorar productos de Google. Verificar en los términos antes de enviar fotos |
| **Modelo pequeño en el teléfono** | Privado | Pesado y más lento; no recomendable en teléfonos de gama baja |
| **Claude (API de Anthropic)** | Muy buena comprensión de fotos y redacción de recetas en español; el mismo proveedor con el que programas | **No es gratuita**: según la página de precios de Anthropic, los usuarios nuevos reciben solo "una pequeña cantidad de créditos" de prueba. La **llave de la API es un secreto** y **no debe ir dentro de la app**: hace falta un **servidor propio** que la guarde, y eso puede salir del plan sin costo (ver abajo) |

**Decisión (14/oct/2026): se empieza con Gemini.** Sobre tu suscripción **Google AI Pro**: según la documentación de planes de Google para desarrolladores, los beneficios de esos planes **aplican solo dentro de la interfaz web de Google AI Studio**; el uso directo de la API se **factura y administra por separado**. Es decir, **la suscripción en sí no cubre las llamadas que haga la app**, pero **sí incluye un beneficio aparte** (ver el punto 2). Lo que hay: (1) el **nivel gratuito de la API** (con límites por modelo y sin tarjeta); (2) **verificado el 15/oct/2026:** el anuncio de Google (27/ene/2026) dice que **AI Pro incluye US$10 al mes en créditos de Google Cloud**, aplicables a la **API de Gemini**. **No son automáticos**: se activan en *Google Developer Program → My benefits* con una **cuenta de facturación de Google Cloud** (normalmente con tarjeta). Un artículo de terceros indica que cada crédito mensual **vence al año**. **No verifiqué** si vincular facturación afecta el plan Spark del proyecto de Firebase; si decides usarlos, **configura un límite de gasto**; y (3) **usar AI Studio a mano** (sin API) para generar recetas o probar fotos del refrigerador, y pegar el resultado en la app. Para aprovechar el nivel gratuito, crea la llave de la API en AI Studio; **no vincules una llave de pago** si quieres evitar cobros. Esto es lo que dice la documentación consultada hoy; los planes y límites cambian, así que se verifica de nuevo al construir.

**Costo de Claude (dato de la página de precios, a verificar al construir):** el modelo más económico listado, **Claude Haiku 5.5**, cuesta **US$0.10 por millón de tokens de entrada y US$0.50 por millón de salida** (para entradas de hasta 100 000 tokens). La página no da el precio por imagen. **Estimación mía, no verificada:** una consulta con una foto y una respuesta corta sería de unas pocas milésimas de dólar o menos; con uso familiar, centavos al mes. Aun así **no es cero**, y exige tarjeta o créditos prepagados en la cuenta de la API.

**Tres formas de usar Claude sin poner la llave en la app**

| Forma | Pros | Contras |
|---|---|---|
| **1. Servidor propio** (por ejemplo, una función en la nube) que guarda la llave y recibe las peticiones de la app | La llave está protegida; se puede limitar el uso por persona | Según tengo entendido, las funciones de Firebase **requieren pasar del plan Spark al Blaze** (con tarjeta); **verificar** antes de decidir. Hay otras opciones de hosting con plan gratuito |
| **2. Llave personal de cada usuario**, escrita en los ajustes y guardada en el almacenamiento seguro del teléfono | Sin servidor y sin costo para ti; cada quien paga lo suyo | Complica la experiencia; si el teléfono se pierde, hay que revocar la llave |
| **3. Prueba solo en tus dispositivos**, con tu llave en una variable local (no en el APK distribuido) | Sirve para **probar la idea** sin infraestructura | **Nunca** se publica así: el APK se puede abrir y extraer la llave |

**Recomendación por etapas:** (1) en las pruebas, **opción 3** o IA en el teléfono para lo básico; (2) para uso real de la familia, **opción 2** (tu propia llave, con límite de gasto mensual configurado en la consola de Anthropic) o la **opción 1** si decides aceptar el plan Blaze; (3) si se vuelve suscripción, el servidor propio es la vía. **Mientras no haya internet o se agote el crédito, la app sigue funcionando** con captura manual y código de barras. Los datos financieros, los datos de salud y las notas del paciente **nunca** se envían a Claude ni a otra IA (6.13, 6.14). Antes de enviar fotos, revisar los términos de uso y de privacidad del proveedor elegido.

**Recomendación general (antes de elegir proveedor):** recetas y foto del refrigerador con **IA en la nube**, como función **opcional y apagada por defecto**, con aviso claro de qué se envía; todo lo demás, en el teléfono. Se puede empezar con el **nivel gratuito de Gemini** (para no gastar) y **cambiar a Claude** cuando se decida pagar, si la capa de IA se diseña **intercambiable** (una interfaz propia con un proveedor detrás). Esto evita atarse a uno.

**Privacidad de las fotos:** que no aparezcan personas, documentos ni pantallas; se envía una copia reducida, no se guarda en la nube y se borra del teléfono al confirmar, si el usuario lo decide.

### 6.14 Conexión con una app de cuidados paliativos en casa

**Contexto:** un familiar (el papá) tiene Alzheimer y se atiende en casa. Hoy los cuidados son gasto (5.2) y una restricción de alimentación. Una app de cuidados cubriría lo clínico y diario (medicamentos, rutinas, bitácora del cuidador); esta app cubre **el dinero y la comida**. **Cada una hace lo suyo y se conectan con un contrato claro.**

| Qué viaja | De → a | Cómo se usa |
|---|---|---|
| **Gastos de cuidado** (medicamentos, pañales, material, cuidador) | Cuidados → esta app | Se convierten en movimientos de la categoría *Cuidados de largo plazo y paliativos* (5.2), con confirmación |
| **Necesidades de alimentación** (texturas, espesantes, restricciones, horarios) | Cuidados → esta app | Entran como **reglas del plan** (6.12), solo si las indica un profesional o el cuidador responsable; la app **no las inventa** |
| **Seguimiento de comidas** (comió, comió poco, rechazó) | Esta app → Cuidados | Se registra en el seguimiento de comidas |
| **Resumen de costo mensual del cuidado** | Esta app → familia | Alimenta el reporte y la visión de cuánto cuesta el cuidado en el tiempo |

**Reglas de privacidad.** Es **información de salud**, la más sensible del sistema: solo viaja lo **mínimo necesario**; esta app **no guarda notas clínicas ni diagnósticos**, solo restricciones de alimentación y gastos; el acceso es por rol (5.0 ter), con **consentimiento** de la familia; todo cambio queda en la bitácora; y los datos de salud no se envían a servicios de IA (6.13).

**Cómo conectarlas** (mismo orden que 6.12): archivo compartido o exportación → enlaces entre apps → mismo proyecto de Firebase si ambas son tuyas, con **reglas de seguridad separadas** para los datos clínicos. Hay que definir si la app de cuidados es una **nueva** (también con Claude Code) o una **existente**; esa respuesta cambia el método (12.2).

### 6.15 Ficha para anotar la app de hábitos (hoy en papel)

Para que cuando se programe la otra app con Claude Code ya exista su documento, conviene escribir **un segundo .md** con la misma lógica que este (de lo general a lo particular). Esta ficha es el contenido mínimo para que las apps **se entiendan**.

| Qué anotar | Ejemplo / qué decidir |
|---|---|
| **Propósito** de la app de hábitos | Seguimiento de hábitos, alimentación, agua, peso, rutinas de ejercicio con IA y otras actividades |
| **Quién diseña qué** | Esta app: menús, recetas, costo y compras. La de hábitos: cumplimiento y constancia. Ejercicio con IA: solo la de hábitos |
| **Datos que recibe de esta app** | Plan semanal (formato 6.12) |
| **Datos que devuelve** | Seguimiento por día y tiempo de comida: cumplido, parcial, sustituido, omitido; peso y agua |
| **Health Connect** | Es de **las dos apps**, pero con una **regla de un solo escritor** por tipo de dato (por ejemplo, el peso y el ejercicio los escribe la de hábitos; las comidas, esta app), para no duplicar registros |
| **Vía de conexión** | Archivo JSON y enlaces entre apps al inicio; mismo Firebase después |
| **Reglas de privacidad** | Qué datos de salud se comparten y con qué permiso |
| **Hábitos como papel hoy** | Lista de hábitos que llevas en papel (nombre, frecuencia, cómo se marca) para convertirlos en la primera versión |

**Cómo pasar lo que hoy llevas en papel:** (1) escribe cada hábito en una fila con nombre, frecuencia y qué cuenta como cumplido; (2) escribe tus tiempos de comida por día; (3) anota las restricciones y alergias de cada persona; (4) con eso se arma el primer plan en el formato de 6.12 y se prueba a mano con el APK. Cuando quieras, puedo redactar ese segundo .md.

### 6.16 Cómo conectar las dos apps: instrucciones para Claude Code

Las dos apps se programan con Claude Code, cada una en su propia sesión. Para que se entiendan hay que darles **el mismo contrato** y **una instrucción a cada una**. Todo está en el archivo **`CONTRATO_CONEXION_APPS.md`**, que se entrega junto con este documento.

| Qué hay en el contrato | Para qué |
|---|---|
| Reparto de responsabilidades (quién es dueña de qué dato) | Evitar duplicar o contradecirse; **un solo escritor por dato** |
| Formato JSON del **plan** (Presupuesto → Hábitos) y del **seguimiento** (Hábitos → Presupuesto) con versión | Intercambio por archivo, sin servidores |
| Enlaces entre apps (`presupuesto://` y `habitos://`) | Abrir la otra app en la pantalla correcta |
| Reglas de Health Connect | Peso, agua y comidas, con permiso y un solo escritor |
| Privacidad | Sin dinero ni datos clínicos; todo archivo importado se valida |
| **8 pruebas de aceptación** | Saber cuándo la conexión funciona |
| **Dos instrucciones para pegar**, una por sesión de Claude Code | Que cada app implemente su parte |

**Cómo usarlo, en orden**

1. Poner `CONTRATO_CONEXION_APPS.md` en la carpeta de **ambos** proyectos (junto con el .md de cada app).
2. En la sesión de **Presupuesto**, pegar la instrucción 8.1; en la de **Hábitos**, la 8.2.
3. Probar primero **a mano con archivos** (exportar de una, importar en la otra) con el APK directo y dos teléfonos.
4. Cuando funcione, agregar enlaces y Health Connect.
5. Si algo del contrato cambia, **cambiarlo primero en el archivo** y avisar a las dos sesiones; no dejar que cada una lo cambie por su lado.

**Con IA (Claude):** cada app puede tener su propia IA (Hábitos para ejercicio y rutinas; Presupuesto para recetas e inventario), pero **no se pasan datos de IA entre apps**: se pasa solo el plan y el seguimiento en el formato del contrato. Así cada app sigue funcionando si se cambia de proveedor de IA.

---

## 7. Modelo de datos (resumen)

| Entidad | Campos principales |
|---|---|
| **Hogar** | id, nombre, modo, moneda, día_inicio_semana |
| **MetaAportación** | id, cuenta_gasto_id, miembro_id, porcentaje_o_monto (opcional) |
| **Miembro** | id, hogar_id, nombre, rol (administrador/adulto/solo_lectura), es_albacea, es_albacea_suplente, tipo (adulto/dependiente), fecha_nac |
| **Ingreso** | id, miembro_id, tipo, monto, frecuencia, próxima_fecha, certeza, es_financiado, compartido |
| **Cuenta** | id, hogar_id, tipo (individual/compartida/**de_gasto**/efectivo/tarjeta/ahorro/inversión), categoría_id (si es de gasto), dueños, saldo_inicial, saldo_actual, método_ahorro (si aplica), clase, estado (activa/congelada/cerrada/archivada), fecha_saldo_inicial, visibilidad |
| **Movimiento (libro)** | id, fecha_hora, cuenta_origen, cuenta_destino, monto, tipo (ingreso/gasto/pago_deuda/aporte/transferencia), categoría_id, realizado_por, registrado_por, vía_captura, evidencia, estado (confirmado/pendiente/en_revisión/anulado), movimiento_anulado_id, clase_origen, clase_destino, anula_a (movimiento_id), estado (pendiente/confirmado/anulado) |
| **Transferencia** | id, movimiento_id, tipo (aportación/préstamo/apoyo/reembolso/compensación), emisor, receptor, confirmada_por, fecha_confirmación |
| **DeudaInterna** | id, acreedor_miembro, deudor_miembro, monto, saldo, fechas_devolución |
| **Confirmación** | id, entidad (transferencia/préstamo/anulación/ajuste/conciliación), entidad_id, requerida_a (miembro), confirmada_por, en_nombre_de, como (propio/albacea), estado (pendiente/confirmada/rechazada), motivo, fecha_hora |
| **Conciliación** | id, cuenta_id, fecha, saldo_declarado, saldo_calculado, diferencia, ajuste_movimiento_id, motivo |
| **Bitácora** | id, entidad, entidad_id, acción, campo, valor_anterior, valor_nuevo, motivo, usuario, actuó_como (propio/albacea), en_nombre_de, fecha_hora (solo se agrega; no se edita ni se borra) |
| **ReporteAuditoría** | id, hogar_id, folio, periodo_tipo (semana/catorcena/quincena/mes/semestre/año/rango), fecha_inicio, fecha_fin, filtro (miembro/cuenta), formato (xlsx/csv), generado_por, fecha_hora |
| **MétodoAhorro** | id, bolsa_id, tipo (porcentaje/fijo/meta_fecha/reto_52/redondeo/sobrante/sobre_categoría/extras), parámetros, activo |
| **Producto** | id, nombre_normalizado, marca, presentación, unidad, ingrediente_id (opcional), categoría_id, imagen (opcional) |
| **CódigoProducto** | id, producto_id, tipo (código_barras/PLU/QR), valor |
| **AliasProducto** | id, producto_id, texto_alias, origen (corrección_usuario/OCR) |
| **Comercio** | id, cadena_id (la cadena es el comercio padre; la sucursal es el hijo), nombre, tipo (supermercado/club_de_precios/tienda_de_descuento/mercado/tienda_de_barrio), sucursal, municipio, ubicación (opcional), favorito |
| **PrecioProducto** | id, producto_id, comercio_id, precio_pagado, cantidad, precio_unitario_normalizado, fecha, fuente (manual/voz/imagen/qr/ticket/catálogo/público), en_promoción, confianza, movimiento_id (si viene de una compra) |
| **ConfigAlertaPrecio** | id, hogar_id, referencia (último_comercio/último_general/promedio_N/mínimo/mejor_vigente), umbral_ámbar_%, umbral_rojo_%, producto_o_categoría (opcional), silenciada |
| **AlertaPrecio** | id, producto_id, comercio_id, tipo (superior/mejor_precio/mejor_comercio/desactualizado/lista), precio_visto, precio_referencia, diferencia_%, fecha |
| **Existencia (despensa)** | id, hogar_id, producto_id, cantidad, unidad, fecha_actualización |
| **Gasto** | id, aportado_por (miembro_id), cuenta_gasto_id (rubro al que aporta), cuenta_origen_id (de dónde salió el dinero), categoría_id (hasta 3 niveles), beneficiario_id, etiquetas, monto, fecha, método_pago, compartido, vía_captura, nota |
| **GastoLínea** | id, gasto_id, producto_id (opcional), categoría_id, cuenta_gasto_id, cantidad, monto |
| **Categoría** | id, nombre, padre_id, nivel (1–3), ícono, color, naturaleza (fijo/variable), prioridad (necesario/deseable/discrecional), es_del_sistema, archivada, crea_cuenta_gasto, posiblemente_deducible |
| **Etiqueta** | id, hogar_id, nombre |
| **PlantillaCategorías** | id, nombre, árbol_de_categorías |
| **GastoRecurrente** | id, categoría_id, monto, frecuencia, próxima_fecha |
| **Deuda** | id, tipo, acreedor, saldo, tasa, pago, frecuencia, próxima_fecha, límite (tarjeta), corte, fecha_límite, es_msi, tasa_cero, acepta_abono_extra, prioridad_pago, institución_id |
| **PagoDeuda** | id, deuda_id, fecha, monto, capital, interés |
| **EstadoCuenta** | id, deuda_id, fecha_corte, fecha_límite, saldo_inicial, saldo_final, compras, pagos, intereses, cargos, tasa_declarada, cat, pago_mínimo, pago_sin_intereses, origen (manual/ocr/archivo), confirmado |
| **TasaEstimada** | id, deuda_id, vigente_desde, tasa_diaria, tasa_anual, método (estado_de_cuenta/cuota_plazo/declarada), error_último_ciclo_pct |
| **PrioridadDeuda** | id, hogar_id, deuda_id, orden, criterio (costo/manual), fijada_por_usuario |
| **DíaInhábil** | id, fecha, tipo (festivo_oficial/inhábil_bancario/personal), fuente, activo |
| **Institución** | id, hogar_id, nombre, tipo (banco/fintech/caja_popular/otro) |
| **CompraMSI** | id, tarjeta_id, comercio, descripción, fecha_compra, monto_total, mensualidades, pagadas, mensualidad, saldo_pendiente |
| **BeneficioTarjeta** | id, tarjeta_id, tipo (cashback/puntos/msi/descuento/seguro/anualidad/promoción/otro), categoría_o_comercio, valor, tope_mensual, vigente_desde, vigente_hasta, condiciones, acumula_en_msi (sí/no), requiere_al_corriente (sí/no), fuente, fecha_verificación |
| **BeneficioObtenido** | id, beneficio_id, movimiento_id, monto_estimado, monto_abonado, fecha_abono, canjeado (puntos) |
| **CuentaInversión** | id, nombre, instrumento, aportación, frecuencia, valor_actual, objetivo_id |
| **BolsaAhorro** | id, nombre, tipo, meta, saldo, fecha_objetivo, aportación_sugerida |
| **Objetivo** | id, tipo, meta, fecha, prioridad, origen (ahorro/deuda/inversión) |
| **Ingrediente** | id, clave, nombre, unidad, presentación, rendimiento, precio, fecha_precio, sección |
| **Platillo** | id, clave, nombre, tiempo_comida, porciones_base, etiquetas |
| **RecetaItem** | platillo_id (padre), ingrediente_id (hijo), cantidad |
| **MenuSemana** | id, hogar_id, semana, monto_objetivo |
| **MenuCelda** | menu_id, día, tiempo_comida, platillo_id |
| **PorcionPersona** | menu_id, miembro_id, platillo_id, porciones |
| **ListaCompra** | menu_id, ingrediente_id, cantidad_necesaria, presentaciones_a_comprar, costo, comprado |
| **PlanNutricional** | id, hogar_id, miembro_id, vigencia_desde, vigencia_hasta, autor (usuario/profesional/app), versión_formato, observaciones |
| **ReglaPlan** | id, plan_id, tipo (restricción/alergia/preferencia/exclusión/meta), valor, tiempo_comida (opcional) |
| **PlanComida** | id, plan_id, día, tiempo_comida, tipo_requerido o platillo_id |
| **SeguimientoComida** | id, plan_comida_id, fecha, estado (cumplido/parcial/sustituido/omitido), platillo_real_id, nota, fuente (esta app/app de hábitos/Health Connect) |
| **CapturaIA** | id, hogar_id, tipo (receta/foto_refrigerador), entrada_ref, resultado, estado (pendiente/confirmada/descartada), modelo, fecha |
| **ConexionExterna** | id, hogar_id, app (hábitos/cuidados/Health Connect), vía (archivo/enlace/Firebase/Health Connect), permisos, última_sincronización |
| **Ocurrencia** | id, hogar_id, origen (ingreso/gasto_fijo/deuda/reserva), origen_id, fecha_programada, fecha_ajustada, monto_esperado, estado (esperada/cumplida/omitida/pendiente), movimiento_id |
| **PresupuestoSemana** | id, hogar_id, semana_inicio, estado, método, ingreso, presupuesto, deuda_plan, remanente_plan, meta_remanente_pct, ahorro_mínimo_con_deuda_pct, techo, creado_en |
| **PartidaPresupuesto** | id, presupuesto_semana_id, cuenta_gasto_id, asignado, arrastre_recibido, protegida, piso_mínimo |
| **ReservaPago** | id, hogar_id, concepto, monto_objetivo, fecha_vencimiento, acumulado, cuenta_destino_id |
| **CierreSemana** | id, presupuesto_semana_id, ingreso_real, gasto_real, abono_real, abono_extra_real, ahorro_real, déficit, acción_elegida, cerrado_por, fecha |
| **ConfigIngreso** | id, miembro_id, forma (semanal/catorcenal/quincenal/mensual/extra), día_de_pago (día de la semana, días del mes o fecha ancla), regla_fin_de_semana_y_festivos (siguiente_día_hábil/día_hábil_anterior/sin_cambio), periodo_visualización |
| **AbonoDiferido** | id, deuda_id, semana_inicio, monto_planeado, monto_abonado, diferido |
| **ClaseCuenta** | cuenta_id, clase (activo/pasivo/ingreso/gasto/pago_deuda), subclase (efectivo/banco/ahorro/inversión/por_cobrar/tarjeta/préstamo/deuda_interna/gasto_financiero/ajuste), líquida (sí/no) |
| **CierrePeriodo** | id, hogar_id, periodo_tipo, fecha_inicio, fecha_fin, activos, pasivos, patrimonio, resultado, cuadre_ok, cerrado_por, fecha |

---

## 8. Experiencia móvil (principios)

- **Navegación inferior de 5 pestañas:** Inicio · Presupuesto · Registrar (+) · Metas · Más.
- **Botón "+" siempre visible** para registrar gasto/ingreso en pocos toques.
- **Selector de nivel arriba** (Yo / Pareja / Hogar) que filtra toda la app.
- **Asistentes por pasos** (armar presupuesto, plan de alimentación, crear objetivo): una decisión por pantalla, progreso visible, se puede pausar y retomar.
- **Semáforos y barras** en lugar de tablas; el detalle es opcional (tocar para profundizar).
- **Notificaciones útiles, no ruidosas:** solo vencimientos, desvíos y logros.
- **Modo offline** para captura; sincroniza después.
- **Accesibilidad:** textos legibles, contraste, montos formateados por moneda.

---

## 8 bis. Plataforma, nube y sincronización

**Plataforma:** **Android primero**; iOS después. Conviene elegir desde el inicio una tecnología que permita reutilizar la lógica en iOS (por ejemplo, un enfoque multiplataforma) para no rehacer el producto.

**Datos:** la app es **offline-first**: guarda todo en una base local del teléfono y sincroniza cuando hay conexión.

**Sincronización entre miembros del hogar — dos caminos**

| Camino | Cómo funciona | Ventajas | Limitaciones |
|---|---|---|---|
| **Cuenta en la nube** *(camino principal)* | Cada usuario tiene cuenta; el hogar se comparte y los dispositivos sincronizan por internet | Funciona en cualquier lugar, respaldo, simple de usar | Requiere servidor y conexión; costo de nube |
| **Mismo WiFi (sincronización local)** *(opcional, más adelante)* | Los teléfonos se descubren en la red local y se sincronizan directamente | Sin internet, datos no salen de casa | Es **técnicamente posible**, pero ambos teléfonos deben estar en la misma red al mismo tiempo; algunos routers aíslan dispositivos; Android limita procesos en segundo plano; hay que resolver **conflictos de edición** |

**Recomendación:** empezar con la **nube**. Diseñar los datos desde ahora como un **registro de eventos con identificadores únicos y marcas de tiempo** (el libro de movimientos ya funciona así), para que después se pueda añadir la sincronización por WiFi sin cambiar el modelo. La transparencia total y la auditoría se apoyan en el mismo registro.

### Opciones de desarrollo y nube: pros y contras (para decidir)

> Comparación pensada para este proyecto: Android primero e iOS después, funcionamiento sin conexión, libro de movimientos con auditoría, y cámara, código de barras y voz. Las capacidades y los costos de cada herramienta cambian: **antes de decidir conviene verificar versiones y precios vigentes.**

**A. App móvil**

| Opción | Pros | Contras | Encaja cuando |
|---|---|---|---|
| **Android nativo** (Kotlin y Jetpack Compose) | Mejor acceso a cámara, voz y rendimiento; experiencia más fluida en Android | **iOS obliga a rehacer la app**: dos bases de código y doble costo | Solo se piensa en Android a largo plazo, o el equipo es experto en Android |
| **Flutter** (Dart) | Un solo código para Android e iOS; interfaz uniforme; buenos paquetes para cámara, códigos de barras y base local | Lenguaje menos común; algunas novedades del sistema tardan en llegar; app algo más pesada | Se quiere Android ya e iOS después con un solo equipo |
| **React Native** (JavaScript o TypeScript) | Un solo código; muchos desarrolladores y librerías; mismo lenguaje que un backend en JavaScript | Cámara y códigos de barras dependen de módulos nativos; más piezas que mantener en cada actualización | El equipo ya domina JavaScript o TypeScript |
| **Kotlin Multiplatform** | Comparte la lógica entre Android e iOS conservando interfaz nativa; sobre Kotlin | Ecosistema más joven, con menos ejemplos y paquetes; exige conocer ambas plataformas | El equipo es de Kotlin y quiere control fino |
| **App web instalable (PWA)** | Un solo código, sin tiendas de aplicaciones; se actualiza al instante | Acceso limitado a cámara, voz, segundo plano y notificaciones; base local menos robusta; peor experiencia sin conexión | Solo como prototipo o panel complementario |

**B. Nube y base de datos**

| Opción | Pros | Contras |
|---|---|---|
| **Firebase** (Firestore y autenticación) | Persistencia sin conexión y sincronización **ya integradas**; autenticación lista; rápido para empezar | Base NoSQL: los reportes por periodo y las sumas son más limitados; el costo crece con las lecturas; **dependencia de un solo proveedor** y migración difícil; un libro auditable exige disciplina |
| **Supabase** (PostgreSQL y autenticación) | **Base relacional**: encaja con cuentas, movimientos, aportaciones, confirmaciones y reportes; seguridad por fila para separar hogares; código abierto y **se puede autoalojar**; exportar a Excel o CSV es directo | La sincronización sin conexión **no viene integrada** (hay que usar una librería o construirla); hay que diseñar y mantener el esquema |
| **Backend propio** (API y PostgreSQL en un servidor) | Máximo control, datos en infraestructura propia y costo predecible | Autenticación, respaldos, seguridad y monitoreo corren **por tu cuenta**; requiere desarrollador de backend |
| **Solo local con sincronización directa** (mismo WiFi) | Privacidad total y funciona sin internet | Conflictos de edición; sin respaldo si se pierde el teléfono; poco práctico para el modo familiar |

**Decisión:** ver **"Pila elegida y cómo evitar que la app sea lenta"** más abajo: Flutter, Firebase Spark y copia local, por costo cero y rapidez.

### Voz, OCR y reconocimiento: dónde se procesa (recomendación)

**Principio:** **en el teléfono por defecto; en la nube solo con permiso y para lo que el teléfono no resuelva bien.** Se evaluó por privacidad, costo y funcionalidad. *Esta tabla es la versión completa, con opciones de nube que cuestan; la versión sin costo está en "Ruta de costo cero" (D).*

| Función | Dónde procesarla (recomendado) | Privacidad | Costo | Funcionalidad |
|---|---|---|---|---|
| **Lector de código de barras** | En el dispositivo | Nada sale del teléfono | Sin costo por uso | Rápido y funciona sin internet |
| **Lectura de texto (OCR) de etiquetas y tickets** | En el dispositivo primero; nube opcional para tickets difíciles | Un ticket puede mostrar nombre o parte de una tarjeta: en la nube solo con permiso y recortando lo sensible | Local: sin costo por uso. Nube: costo por imagen | El OCR local basta para etiquetas claras; los tickets arrugados o largos mejoran con la nube |
| **Voz (dictado)** | Reconocimiento del dispositivo, e interpretación de la frase con reglas locales | El audio no se guarda ni se envía por defecto | Sin costo por uso en local | Suficiente para frases simples; la disponibilidad sin conexión **depende del teléfono y del idioma** (verificar español de México) |
| **Voz con frases complejas** | Nube opcional, enviando **solo el texto, nunca el audio** | Se envía únicamente lo dictado, y con permiso | Costo por uso | Entiende mejor frases largas o ambiguas |
| **Reconocer el producto por la imagen del empaque** | Código de barras y OCR local primero; nube solo como último recurso | Foto del producto, poco sensible | Costo por uso: **candidato a plan de pago** | Menos preciso; **siempre se confirma** |

**Reglas de privacidad**

- **Consentimiento por función:** las que usan la nube están apagadas hasta que el usuario las activa, y la app avisa cuando se usan.
- **Enviar lo mínimo:** texto en lugar de audio; recorte del precio o del producto en lugar del ticket completo.
- **No guardar audio ni imágenes** en el proveedor; confirmarlo en el contrato con cada proveedor.
- **Datos sensibles:** los datos de salud (por ejemplo, los cuidados de un familiar) y los financieros se tratan con cuidado reforzado. Antes de lanzar, revisar la normativa mexicana vigente de protección de datos personales y el aviso de privacidad; conviene **asesoría legal**.
- **Siempre se confirma** lo detectado antes de guardarlo.

**Relación con la suscripción:** lo que se procesa en el dispositivo no tiene costo por uso y puede ir en el plan gratuito; lo que usa la nube es candidato a cuota o plan de pago.

### Ruta de costo cero (decisiones 4 y 5)

> **Objetivo:** construir y usar la app **sin pagar** por la nube ni por servicios de inteligencia artificial, y dejar el costo para cuando haya suscripciones. Las cifras de las tablas se consultaron el **14/oct/2026** en las páginas oficiales de cada servicio; **cambian con frecuencia, así que verifícalas antes de decidir.**

**Principio:** todo lo que "piensa" (código de barras, texto de fotos, voz) ocurre **en el teléfono**. La nube se usa **solo para sincronizar datos de texto** entre los miembros del hogar. Las **fotos se quedan en el teléfono**: no suben a la nube. Así no hay costo por uso y se respetan los límites gratuitos.

**A. Herramientas y publicación**

| Concepto | Costo | Lo que se verificó |
|---|---|---|
| Herramientas de desarrollo (Flutter, React Native, Android Studio, SQLite) | Sin costo de licencia | Son herramientas abiertas o gratuitas; confirmar términos al elegir |
| Publicar en Google Play | **US$25, pago único** | Confirmado en la ayuda de Google Play Console. Exige verificar identidad |
| Requisito para cuentas personales nuevas de Play | Sin costo, pero **toma 14 días y 12 personas** | Las cuentas personales creadas después del 13/nov/2023 deben hacer una **prueba cerrada con al menos 12 testers durante 14 días continuos** antes de pasar a producción; si el número baja de 12, el conteo se reinicia |
| **Alternativa sin pagar nada: instalar el APK directamente** en los teléfonos del hogar | **$0** | Es posible en Android, pero sin actualizaciones automáticas ni la confianza de la tienda; sirve para arrancar con la familia y los primeros usuarios |
| iOS (después) | Cuota anual de Apple | No se consultó el monto; verificarlo cuando llegue el momento |

**B. Nube gratuita para sincronizar**

| Servicio | Cuotas sin costo | Cosas a cuidar |
|---|---|---|
| **Firebase, plan Spark** (Firestore y autenticación) | 1 GiB de almacenamiento; **50 mil lecturas, 20 mil escrituras y 20 mil borrados por día**; 10 GiB de salida de red al mes; **no pide tarjeta** | La autenticación por **teléfono (SMS) no está en el plan sin costo**: usar correo o cuenta de Google. Al rebasar las cuotas, el servicio se limita en lugar de cobrar |
| **Supabase, plan Free** (PostgreSQL y autenticación) | Base de **500 MB**, 1 GB de archivos, 5 GB de transferencia, hasta 2 proyectos, 50 mil usuarios activos al mes | **Se pausa tras una semana sin actividad** y **no incluye respaldos automáticos**; la sincronización sin conexión no viene integrada |

**¿Alcanza para un hogar?** Estimación propia: un hogar de 5 personas que registre unos 50 movimientos al día, con unas 4 escrituras por movimiento (movimiento, saldo, bitácora, confirmación), usaría alrededor de **200 escrituras diarias**, es decir, **cerca del 1 % del límite de 20 mil**. Como la app guarda una copia local, la mayoría de las lecturas no tocan la nube. El límite se compartiría entre **todos los hogares** del mismo proyecto: ahí empezaría el costo, y ahí encaja la suscripción.

**C. Tres rutas de costo cero**

| Ruta | Cómo funciona | Pros | Contras |
|---|---|---|---|
| **A. Solo teléfono + APK** | Cada teléfono guarda sus datos; se comparten por exportación (Excel/CSV) o, más adelante, por el mismo WiFi | **$0 absoluto**; privacidad total | Sin sincronización automática; el modo familiar con transparencia total es incómodo |
| **B. Nube gratuita** *(recomendada)* | Teléfono + base local, y Firebase Spark o Supabase Free para sincronizar | $0 mientras el uso sea pequeño; sincronización entre miembros; respaldo | Dependes de los límites y condiciones del proveedor |
| **C. Servidor propio en casa** | Un equipo siempre encendido (por ejemplo, una mini PC) como servidor | Sin renta de nube; datos en casa | Hay que mantenerlo, protegerlo y abrir el acceso desde fuera; **no es $0** si hay que comprar el equipo |

**Decisión (14/oct/2026):** **Ruta B con Firebase Spark**, elegida por ti. Se prueba primero instalando el **APK directamente** en tus dispositivos; la cuenta de Play Console ya existe y se usará después. Con Spark, la autenticación se hace con correo o cuenta de Google (el SMS no está incluido sin costo), y los reportes y la auditoría se calculan en el teléfono. Para no quedar atado al proveedor: identificadores únicos en cada movimiento y **exportación a Excel o CSV como respaldo** (ya prevista en 5.9).

**D. Voz, OCR y reconocimiento sin costo (decisión 5, relacionada con la 4)**

| Función | Cómo hacerla sin costo | Lo que se verificó | Límites |
|---|---|---|---|
| **Código de barras** | Lector de **Google ML Kit**, en el teléfono | La documentación de ML Kit indica que el procesamiento ocurre en el dispositivo y que funciona sin conexión | No encontré un costo por uso en la documentación consultada; verifica sus términos vigentes |
| **Texto de etiquetas y tickets (OCR)** | **ML Kit de reconocimiento de texto**, con el modelo **dentro de la app** | Soporta escritura **latina** (sirve para español) y tiene opción empaquetada, disponible de inmediato | Los tickets largos o arrugados salen peor: siempre se **confirma** antes de guardar |
| **Voz** | 1) Reconocedor de voz **del propio teléfono**; 2) alternativa: **Vosk**, motor abierto | Android documenta un reconocedor en el dispositivo (desde Android 12); la disponibilidad del idioma y la descarga del modelo **dependen del teléfono**. Vosk ofrece un **modelo pequeño en español de 39 MB**, con licencia Apache 2.0 | Menor precisión que los servicios en la nube; Vosk suma peso a la app |
| **Interpretar la frase** ("gasté 150 en gasolina") | **Reglas locales**: se detecta el monto y se busca la palabra en un diccionario de categorías y productos | Usa las hojas **Categorías** y **Productos base** del libro de datos semilla | Funciona con frases sencillas; si no entiende, pide completar a mano |
| **Reconocer un producto por la foto del empaque** | **No incluirlo** en la etapa sin costo; usar código de barras, OCR y lista | Requiere servicios de pago por uso | Se deja como mejora de pago más adelante |
| **Identificar producto por código de barras** | Catálogo propio del hogar + **Open Food Facts** (gratuito) | Límite de unas 15 consultas por minuto y datos aportados por voluntarios | Cobertura de productos mexicanos por verificar |

**Cómo se relacionan las decisiones 4 y 5:** la ruta de costo cero usa **la misma idea en ambas**: procesar en el teléfono y subir solo texto. Por eso la voz y el OCR **no necesitan servidor**, y la nube gratuita solo sincroniza movimientos, precios y confirmaciones.

**Lo que NO es gratis (para tenerlo presente):** la cuota única de Google Play (US$25) si se publica en la tienda, la cuota anual de Apple al llegar a iOS, y cualquier servicio de reconocimiento en la nube. Ninguno es necesario para arrancar con la ruta B y el APK directo.

### Pila elegida y cómo evitar que la app sea lenta

**Pila (Firebase Spark lo decidiste tú; el resto lo elegí con el criterio de costo cero y rapidez en Android):**

| Capa | Elección | Por qué |
|---|---|---|
| **App móvil** | **Flutter (Dart)** | Un solo código para Android hoy e iOS después; compila a código nativo. Los plugins de Firebase para Flutter (**FlutterFire**) los publica la propia cuenta de Firebase en GitHub, con licencia abierta BSD-3, e incluyen `cloud_firestore` y `firebase_auth` para Android e iOS |
| **Datos y sincronización** | **Cloud Firestore (plan Spark)** | La **persistencia sin conexión viene activada por defecto en Android e iOS**: la app lee, escribe y consulta sin red y sincroniza al reconectar. La caché por defecto es de unos 100 MB (dato del ejemplo de la documentación) |
| **Inicio de sesión** | Firebase Authentication con **correo o cuenta de Google** | El SMS no está incluido en el plan sin costo |
| **Voz y OCR** | En el teléfono (ML Kit; reconocedor de voz del teléfono; Vosk opcional) | Sin costo por uso y sin red |
| **Reportes** | En el teléfono, con la copia local y resúmenes semanales precalculados | Menos lecturas y más rapidez |
| **Fotos** | Se quedan en el teléfono | No gastan cuota de la nube |
| **Distribución** | **APK directo** ahora; Play Console después | Cero costo para probar |

**Por qué Flutter.** **Kotlin nativo** sería el más rápido y el de acceso más directo a cámara, voz y Health Connect, pero obligaría a **rehacer la app para iOS**. **React Native** también sirve, pero aquí cuenta que Firebase mantiene oficialmente FlutterFire. En ambos casos, los paquetes para ML Kit y Health Connect suelen ser de la comunidad: conviene **verificar que estén al día** antes de depender de ellos. Si algún día se decide solo Android con máxima velocidad, Kotlin nativo es la alternativa; si quien programa domina otra herramienta, la pila se reevalúa.

**Regla de diseño por Firestore:** cuando varios cambios tocan el mismo documento, **gana la última escritura**. Por eso los **saldos no se guardan como un campo editable**: cada movimiento es un documento que **no se edita** (se anula con un contraasiento) y el saldo se **calcula**. Es la misma lógica del libro de movimientos y de la bitácora.

**Cómo evitar que la app sea lenta** (metas propuestas, por medir):

| Práctica | Para qué |
|---|---|
| Probar en **modo de lanzamiento** (no en depuración) y en un **teléfono de gama baja** | La depuración siempre es más lenta; el mejor teléfono esconde los problemas |
| **Copia local primero**: la pantalla se pinta con datos locales y la nube actualiza después | Se siente inmediata, aun sin internet |
| **Listas paginadas** (30 a 50 filas por vez) en movimientos, productos e historial | Evita cargar miles de filas |
| **Resúmenes precalculados** por semana y por cuenta | No sumar miles de movimientos al abrir |
| **Consultas acotadas** por hogar y por periodo, con índices | Menos lecturas y respuesta rápida |
| OCR, códigos de barras y voz **fuera del hilo de la interfaz** | La pantalla no se congela mientras la cámara trabaja |
| **Fotos comprimidas** y miniaturas en las listas | Menos memoria y menos espacio |
| Modelo de voz **opcional**, descargado bajo demanda | La app no pesa de entrada |
| Vigilar las **cuotas** del proyecto en la consola de Firebase | Detectar consumo antes de rebasar el límite |

**Metas:** abrir la app en **menos de 2 segundos** en un teléfono de gama media, capturar un gasto en **menos de 10 segundos** (ver 8) y desplazar las listas sin tirones. Son metas propuestas; hay que medirlas en tus dispositivos.

**Instalar directo en tus dispositivos (prueba)**

1. Generar el **APK en modo de lanzamiento**, firmado con una **llave propia**. Guárdala bien: hace falta para actualizar la app y, después, para subirla a Play.
2. Pasarlo al teléfono (cable, Drive o mensajería) y **permitir la instalación desde fuentes desconocidas** solo para la app desde la que lo abres.
3. Instalarlo. Para actualizar, instalar un APK con el **mismo identificador de paquete**, la **misma firma** y un **número de versión mayor**.
4. Probar con **dos dispositivos y cuentas distintas** para revisar transferencias, confirmaciones y el albacea, y con **modo avión** para comprobar el funcionamiento sin conexión.
5. Cargar los **datos semilla** (libro Excel de 6.11) con una función de importación.
6. Cuando esté lista, subirla a Play Console. Según el tipo de cuenta, para pasar a producción puede exigirse la **prueba cerrada** con 12 personas durante 14 días (ver 12.2).

**Seguridad:** cifrado en tránsito y en reposo, bloqueo por huella/PIN, roles por hogar (administrador, albacea, miembro adulto, dependiente y solo lectura; ver 5.0 ter) y respaldo de datos.

**Moneda:** **MXN** al inicio; el modelo guarda la moneda por hogar para ampliar después.

**Modelo de negocio:** **gratuito al inicio**, **suscripción posterior**. Se recomienda construir con **planes y funciones activables** desde el comienzo, para cambiar a suscripción sin rehacer nada. Funciones con costo real de operación (candidatas a plan de pago): voz e imagen/OCR sin límite, precios de supermercados, más de N miembros, sincronización en nube extendida, reportes de auditoría avanzados y conexión con cuentas reales. Conviene decidir y comunicar **desde el inicio** qué núcleo se mantiene gratuito.

**Opciones de suscripción (aún sin definir).** Tres formas habituales para decidir, sin compromiso:

| Opción | Cómo funciona | Pros | Contras |
|---|---|---|---|
| **Por funciones** | El núcleo es gratis (registro manual, cuentas, presupuesto, bitácora, categorías y exportación); se paga por voz e imagen en la nube, precios de comunidad y conexión con cuentas reales | Claro de explicar; cobra lo que cuesta dinero cada vez que se usa | Hay que cuidar que lo "de confianza" (auditoría) no quede detrás de un muro de pago |
| **Por límites** | Todo disponible, con topes (miembros, meses de historial, escaneos por mes) | Los usuarios prueban todo | Los topes frustran y pueden chocar con la transparencia total |
| **Por hogar** | Gratis individual; de pago para pareja o familia | Sencillo y alineado con los costos de nube del modo compartido | Puede frenar justo a las parejas y familias, que son el diferenciador |

**Propuesta:** mantener gratis lo que crea hábito y confianza, y cobrar lo que genera costo en cada uso. **Decisión pendiente.**

---

## 8 ter. Seguridad, privacidad y respaldo (a detalle)

**Para qué:** esta app guarda **dinero, deudas, estados de cuenta y, por la conexión con la app de cuidados, información cercana a la salud**. Esta sección fija **cómo se protege**, **qué se hace si algo sale mal** y **cómo se respalda y se borra**. Se agregó el 19/oct/2026 porque faltaba en el documento.

**1. Principios**

1. **Lo mínimo necesario:** solo se guarda lo que la función necesita.
2. **En el teléfono por defecto; en la nube solo lo que hace falta** para compartir con el hogar (8 bis).
3. **La seguridad vive en el servidor, no en la pantalla:** los roles y permisos (5.0 ter) se **vuelven a comprobar en las reglas de la base de datos**; ocultar un botón no protege nada.
4. **Nada de secretos en el APK:** ninguna llave de servicio ni de IA viaja en la app (6.13).
5. **El libro no se edita:** los movimientos y la bitácora **solo se agregan** (5.0 bis); se corrige con anulación y contraasiento.
6. **El usuario manda sobre sus datos:** puede **exportarlos, corregirlos, borrar su cuenta** y apagar lo opcional.

**2. Capas de protección**

| Capa | Qué se hace | Estado |
|---|---|---|
| **Cuenta** | Correo o Google (8 bis). Con Google, se recomienda activar su **verificación en dos pasos** | Decidido |
| **Bloqueo de la app** | **Huella, rostro o PIN** al abrir y tras **1 minuto** en segundo plano (por defecto, editable) | Por defecto |
| **Pantalla** | Se **oculta la vista previa** en el selector de aplicaciones; **bloqueo de capturas** opcional | Por defecto / opcional |
| **Datos en el teléfono** | Base local **cifrada**, con la llave en el **almacén seguro de Android** | **Propuesta a validar al construir** |
| **Datos en la nube** | Cifrado en tránsito y **en reposo** (verificado abajo) | Verificado |
| **Reglas de acceso** | Por **hogar y rol**; solo-agregar para movimientos y bitácora; pruebas de las reglas con el emulador antes de cada versión | Diseño |
| **Verificación de la app** | Opcional: comprobar que quien llama es la app original (**App Check**) | **Por verificar** límites y costo |
| **Secretos** | Llaves de IA en un servidor propio, nunca en la app (6.13) | Decidido |

**Si se olvida el PIN:** se vuelve a entrar con la **cuenta** (correo o Google); **no hay forma de saltar el bloqueo** sin ella.

**3. Roles aplicados en el servidor**

Las reglas replican la **matriz de 5.0 ter** (administrador, albacea, miembro adulto, dependiente y solo lectura). En particular:

- Un **dependiente** o **solo lectura** **no puede escribir** movimientos aunque llame a la base directamente.
- **Nadie puede editar ni borrar** un movimiento ni la bitácora, **ni siquiera el administrador**.
- Las **confirmaciones** (transferencias, préstamos, anulaciones) **no se pueden confirmar con el mismo usuario que las crea**, salvo el albacea en nombre de otro miembro con registro (5.0 ter).

**4. Dispositivos y teléfono perdido**

| Situación | Qué hace la app |
|---|---|
| **Dispositivos con sesión** | Lista con nombre, última actividad y botón **"Cerrar sesión en este dispositivo"** |
| **Dispositivo nuevo** | Aviso a los administradores del hogar y registro en la bitácora de seguridad |
| **Teléfono perdido o robado** | Desde **otro dispositivo o la web**, cerrar todas las sesiones y cambiar la contraseña; los datos locales siguen **cifrados y bajo bloqueo** |
| **Intentos fallidos de PIN** | Espera creciente entre intentos; **borrado local tras 10 fallos** (opcional, desactivado por defecto) |

**5. Respaldo y restauración**

**La sincronización en la nube no es un respaldo:** si algo se borra o se daña, **también se sincroniza**. Por eso hay **respaldo del hogar** aparte.

| Elemento | Regla |
|---|---|
| **Respaldo del hogar** | Archivo con todos los datos, **cifrado con una contraseña elegida por la persona**; lo genera la app y **ella decide dónde guardarlo** (la app no lo sube sola a servicios de terceros) |
| **Recordatorio** | **Mensual**, por defecto |
| **Exportación para lectura** | Excel o CSV con selector de periodo (5.9) |
| **Restauración** | Sobre un **hogar vacío** (por defecto); **no se fusiona** con datos existentes para no duplicar. Pide contraseña y valida el archivo |
| **Sello de integridad** *(propuesta)* | Al **cerrar cada semana** se guarda una huella de sus movimientos; el respaldo la incluye y la restauración **verifica que nada se alteró** |
| **Copias automáticas del servidor** | **No se asumen** en la ruta sin costo (por verificar); mientras tanto, el respaldo del hogar es el de la app |

**6. Privacidad y borrado**

**Qué se guarda y por cuánto tiempo (valores por defecto, editables):**

| Dato | Retención |
|---|---|
| Movimientos, bitácora y ajustes | **Mientras exista el hogar** (son el libro) |
| **Fotos de tickets y comprobantes** | **12 meses** y luego se eliminan; el movimiento queda |
| **Archivos de estados de cuenta** | **No se guardan** (5.0 bis 3); solo los renglones |
| **Audio de la voz** | **No se guarda ni se envía** (5.2) |
| **Fotos del refrigerador** | Se borran al terminar (6.13) |
| **Datos de cuidados** | Mínimo necesario, sin notas clínicas (6.14) |

**Borrar la cuenta de un miembro** (una necesidad real de la tienda y de la ley, ver abajo):

1. El miembro puede **pedirlo dentro de la app** y desde una **página web**.
2. Antes se ofrece **exportar** sus datos.
3. Se elimina su **acceso y sus datos personales** (nombre, correo, foto).
4. Los **movimientos del hogar en que participó se conservan** con el nombre **"Miembro eliminado"**, porque son parte del **libro y de la bitácora del hogar**. **Esto se avisa antes** y queda escrito en el aviso de privacidad.
5. Si lo pide el **administrador del hogar entero**, se borra todo tras **30 días de gracia** para poder cancelar.

**Derechos sobre los datos** (acceso, rectificación, cancelación y oposición): **acceso** = exportar; **rectificación** = editar el perfil y corregir con anulación; **cancelación** = borrar la cuenta; **oposición** = apagar usos opcionales (IA, fotos, análisis).

**Consentimiento por separado** para lo opcional: IA (6.13), fotos del refrigerador, conexión con la app de cuidados (6.14) y cualquier envío fuera del teléfono. **Cada uno se puede retirar** sin perder la función básica.

**Menores y dependientes:** un menor **no abre cuenta propia**; un adulto del hogar captura lo que le corresponde y el menor tiene a lo mucho una **vista simple** (5.0 ter).

**7. Requisitos legales y de la tienda (verificados el 19/oct/2026)**

| Tema | Qué se verificó | Qué implica para la app |
|---|---|---|
| **Google Play: borrado de cuenta** | Si la app permite **crear una cuenta**, debe ofrecer una **ruta dentro de la app** para pedir el borrado de la cuenta y los datos asociados, **y un enlace web** para hacerlo sin reinstalar. Puede conservarse algo por seguridad, fraude o ley, **si se informa claramente** | Pantalla "Borrar mi cuenta" y página web de solicitud, con lo que se conserva dicho en el aviso |
| **Google Play: formulario de seguridad de datos** | Se exige declarar qué datos se recopilan y cómo se borran | Llenarlo con lo de esta sección |
| **Ley mexicana de datos personales** | La **nueva Ley Federal de Protección de Datos Personales en Posesión de los Particulares** se publicó en el DOF el **20/mar/2025** y entró en vigor al día siguiente; la autoridad es ahora la **Secretaría Anticorrupción y Buen Gobierno**; los derechos **ARCO** siguen; el aviso debe señalar los **datos sensibles** (entre ellos la **salud**) y las finalidades que requieren consentimiento | **Aviso de privacidad** (versión simple en la app y completa en la web), consentimiento para lo opcional y manejo reforzado de los datos de cuidados |
| **Cifrado en la nube** | La documentación de Google indica que **Firestore cifra todos los datos almacenados por defecto**, sin configuración | Se confía en ello y se agregan las reglas de acceso |

> **Aviso:** esto es un **resumen informativo**, no asesoría legal. Si la app va a **publicarse para terceros** (no solo tu familia), conviene que **un abogado revise el aviso de privacidad y el borrado de cuentas** antes de lanzar. Si la usa solo tu familia, el alcance puede ser distinto; **confírmalo**.

*Fuentes:* [Google Play: requisitos de borrado de cuenta](https://support.google.com/googleplay/android-developer/answer/13327111) · [Garrigues: nueva LFPDPPP en México](https://www.garrigues.com/es_ES/noticia/mexico-nueva-ley-federal-proteccion-datos-personales-posesion-particulares-introduce) · [Google Cloud: cifrado de Firestore](https://docs.cloud.google.com/firestore/docs/server-side-encryption).

**8. Modelo de amenazas sencillo**

| Amenaza | Qué la frena |
|---|---|
| Teléfono perdido o robado | Bloqueo, base cifrada, cierre remoto de sesiones |
| Teléfono desbloqueado en manos de otra persona | Bloqueo tras 1 minuto, vista previa oculta, exportar pide biometría |
| Cuenta comprometida | Verificación en dos pasos de Google, aviso de dispositivo nuevo, cierre de sesiones |
| Un miembro que quiere ocultar o cambiar algo | Libro solo-agregar, bitácora, transparencia total |
| Error humano (borrar o capturar mal) | Anulación con contraasiento y respaldo del hogar |
| Reporte compartido a quien no debe | Advertencia al exportar, folio y quién lo generó (5.9) |
| Llave de IA expuesta | Nunca en la app; servidor propio (6.13) |
| App falsa o modificada | App Check, **por verificar** (no aplica al APK de prueba) |

**9. Pantallas:** ajustes de seguridad (bloqueo, tiempo, capturas, dispositivos), respaldo del hogar (crear, programar, restaurar), **Borrar mi cuenta**, privacidad y consentimientos, bitácora de seguridad.

**10. Datos nuevos:** `Dispositivo` (usuario, nombre, última actividad, estado), `EventoSeguridad` (tipo, usuario, dispositivo, fecha), `Consentimiento` (usuario, finalidad, fecha, vigente), `SolicitudBorrado` (usuario, alcance, estado, fecha de gracia), `RespaldoHogar` (fecha, versión, huella) y `SelloIntegridad` (semana, huella).

**11. Pruebas de aceptación**

| # | Prueba | Resultado esperado |
|---|---|---|
| SG1 | App en segundo plano más de 1 minuto | Pide huella, rostro o PIN |
| SG2 | Olvidar el PIN | Se recupera entrando con la cuenta; sin ella, no |
| SG3 | Un dependiente intenta escribir un movimiento llamando directo a la base | **Rechazado por las reglas** |
| SG4 | Intentar editar o borrar un movimiento (incluso como administrador) | **Rechazado**; solo anulación con contraasiento |
| SG5 | Iniciar sesión en un dispositivo nuevo | Aviso a los administradores y registro |
| SG6 | Cerrar todas las sesiones desde otro dispositivo | El teléfono perdido pierde acceso |
| SG7 | Crear un respaldo cifrado y restaurarlo en un hogar vacío | Quedan los mismos movimientos y el sello de cada semana verifica |
| SG8 | Restaurar sobre un hogar con datos | La app **no fusiona** y lo explica |
| SG9 | Un miembro borra su cuenta | Se eliminan sus datos personales, sus movimientos quedan como "Miembro eliminado" y se avisó antes |
| SG10 | Retirar el consentimiento de IA | La función se apaga y lo básico sigue funcionando |
| SG11 | Exportar reportes | Advertencia, biometría y folio con quién lo generó |

**Lo que no se asume:** que el cifrado local con la llave del sistema funcione igual en todos los teléfonos (se valida al construir), que las copias automáticas del servidor sean gratis, ni que la ley aplique igual a un uso solo familiar. Los puntos "por verificar" se cierran **antes de publicar** fuera de la familia.

---

## 9. Reglas transversales

1. **Nada se captura dos veces:** un préstamo recibido crea su deuda; un pago de tarjeta se refleja en Deudas y Gastos; la compra del súper se refleja en Alimentación y Gastos.
2. **Todo tiene fecha y miembro** (quién, cuándo).
3. **Moneda única por hogar: MXN al inicio** (multi-moneda queda fuera del alcance inicial).
4. **Bitácora:** toda acción relevante (ingresos, deudas, ajustes, anulaciones, confirmaciones) queda en la bitácora, que no se edita ni se borra.
5. **Transparencia total en Pareja/Familiar:** todos los adultos ven todos los movimientos; nada se borra, solo se anula con motivo, y todo cambio queda en la bitácora.
5b. **Transferencias y préstamos siempre confirmados:** el dinero que cambia de manos entre familiares, también en efectivo, queda anotado y confirmado por el receptor o, en su nombre, por el albacea (ver 5.0 ter).
6. **Datos sensibles:** cifrado en tránsito y en reposo; bloqueo por biometría. Detalle, respaldo y borrado de cuenta en la sección 8 ter.

---

## 10. Hoja de ruta sugerida (por fases)

> **Las fases son una propuesta, no un compromiso.** Se pueden **reordenar o rediseñar** según lo que se aprenda con las pruebas. Reglas para mover piezas sin romper nada: (1) el **libro de movimientos y las cuentas** van primero, porque todo depende de ellos; (2) la **IA y la conexión entre apps** son opcionales y pueden entrar en cualquier fase, siempre que la app funcione sin ellas; (3) cada fase termina con algo **usable** en tus teléfonos; (4) lo que se mueva se registra en 12.1.

| Fase | Alcance | Resultado |
|---|---|---|
| **MVP 1** *(Android)* | Hogar (modo Individual), **Cuentas y libro de movimientos**, Ingresos, Gastos (captura manual), Presupuesto semanal, tablero; cuenta en la nube (Firebase Spark); **importación de los datos semilla** (Excel/CSV); instalación directa del APK para pruebas | Saber cuánto entra, cuánto sale y cuánto queda |
| **MVP 2** | Deudas (préstamos y tarjetas), **Ahorro con métodos**, alertas de vencimiento | Ver compromisos y apartar dinero |
| **Fase 3** | **Alimentación** (catálogo base + propio, recetas, menú manual, lista de compras), **historial de precios por comercio con comparación y alerta de precio superior**, **lector de código de barras** | Costeo y compras de la semana |
| **Fase 4** | Modo Pareja y Familiar: cuentas individuales y compartidas, **transferencias con confirmación, albacea, transparencia total, bitácora y reporte de auditoría en Excel/CSV** | Finanzas compartidas y controladas |
| **Fase 5** | **Captura por voz e imagen en el teléfono, sin costo** (foto, cámara con OCR, QR) y **precios de supermercados**; **curva de desviación y modo "En el súper"** con **cámara (etiquetas y reconocimiento del empaque)**; asistente de menús por monto; Objetivos y escenarios | El plan "inteligente" |
| **Fase 6** | iOS, inversión (seguimiento manual → conexión con cuentas reales), reportes avanzados, información nutricional, **plan de nutrición y conexión con la app de hábitos** (archivo y enlaces primero), sincronización por WiFi, **suscripción** | Profundización y monetización ; **IA opcional** (recetas y foto del refrigerador, 6.13); **conexión con la app de cuidados paliativos** (6.14) |

---

## 11. Observaciones sobre el Excel de ejemplo (a corregir al migrar)

Durante la revisión de `PRESUPUESTO DE ALIMENTOS.xlsx` se detectó lo siguiente:

1. **MENU SEMANAL:** la clave del platillo y su nombre están en columnas distintas solo para el lunes; martes a viernes están vacíos. La app debe guardar **un platillo por celda** (día × tiempo).
2. **RECETA:** el queso panela (`LAC-001`) aparece con padre `SAN-002`, que no existe como platillo; probablemente debía ser `SAN-001`, o falta definir el platillo `SAN-002`.
3. **RECETA:** el cálculo del sándwich suma las filas 3 a 8, es decir, incluye el queso panela (`SAN-002`). Hay que confirmar si el queso forma parte del sándwich de jamón de pavo o de otro platillo.
4. **RECETA:** `ENS-001 ATUN` está solo como encabezado, sin ingredientes ni cantidades.
5. **RECETA:** la hoja usa dos columnas de clave (`HIJO` y `CLAVE`) con el mismo valor; en la app basta una sola.
6. **Rendimientos con unidad ambigua:** algunos rendimientos están en porciones de platillo (ej. pan 18 rebanadas → 9 sándwiches) y otros en consumo de presentación (ej. arándanos 1.36 kg → 34). Conviene definir **una convención única**: "*esta presentación rinde N porciones de platillo*".
7. **PORCIONES y PRESUPUESTO SEMANAL:** el total familiar es la suma de porciones por persona (Ana 1 + Alex 2 = 3 sándwiches; 1 + 1 = 2 bowls). Esto debe ser un **cálculo automático**, no una captura aparte.
8. **Faltan precios de ingredientes con fecha**, y la hoja no incluye el **monto semanal objetivo**, que es el dato de partida de la app.
9. **Faltan los resultados totales:** costo semanal total y lista de compras consolidada; son justamente las salidas que la app debe generar.

---

## 12. Decisiones tomadas y pendientes

### 12.1 Decisiones tomadas (14/oct/2026)

| # | Tema | Decisión | Dónde se refleja |
|---|---|---|---|
| 1 | Inversión | Seguimiento **manual** por ahora; **conexión con cuentas** más adelante | 5.4 |
| 2 | Ahorro | **Varios métodos**; se crea la cuenta de ahorro y se define el método | 5.5 |
| 3 | Pareja y familia | Ingreso por individuo y **transparencia total** de movimientos (cuenta compartida o individual); **transferencias entre familiares** anotadas y **auditoría** final. Los gastos compartidos funcionan como **cuentas de gasto independientes por rubro**: cada miembro decide a cuál aportar y con cuánto (ej. uno compra leche y otro pan, ambos aportan a *Alimentación*) | 2, 5.0 bis, 9 |
| 4 | Catálogo de alimentación | **Ambas:** catálogo base de la app + platillos e ingredientes propios del usuario | 6 |
| 5 | Captura y precios | **4 vías:** manual, voz, imagen (captura, foto, cámara con OCR, QR) y precios de supermercados | 6.9 |
| 6 | Moneda | **MXN** al inicio | 8 bis |
| 7 | Plataforma y sincronización | **Android primero**, iOS después; **cuenta en la nube** y, opcional más adelante, sincronización por mismo WiFi | 8 bis |
| 8 | Modelo de negocio | **Gratuito ahora**, **suscripción** posterior | 8 bis |
| 9 | Precios | **Inventario e histórico de precios por comercio**, con comparación contra compras anteriores, **alerta de precio superior** y **curva de desviación** (ahorro o sobregasto); aplica a cualquier compra, no solo alimentos | 6.10 |
| 10 | Categorías y cuentas de gasto | Árbol de categorías ampliado (hasta 3 niveles), con **Limpieza y mantenimiento del hogar** y **Cuidados de largo plazo y paliativos** en Salud; el hogar puede **crear categorías y subcategorías**. Cada categoría principal es una **cuenta de gasto** por defecto y una subcategoría puede promoverse a cuenta propia; las compras con varios rubros se **dividen por líneas** | 5.2, 5.0 bis |
| 11 | Identificación de productos | Identificar con **cámara** si es posible, o con **lector de código de barras**, capturando **producto y precio** en un solo escaneo, con confirmación | 6.10 |
| 12 | Roles y albacea | Se puede elegir **un miembro albacea** que confirma por los demás; todo queda en la **bitácora** | 5.0 ter |
| 13 | Transferencias y préstamos entre familiares | **Siempre se confirman**, también los de efectivo; el albacea puede confirmar en nombre del miembro; los préstamos entre familiares son **sin interés** | 5.0 bis, 5.0 ter |
| 14 | Anulaciones y ajustes | Requieren confirmación cuando involucran a otra persona; el albacea puede confirmar por los miembros; queda en la bitácora | 5.0 ter |
| 15 | Reporte de auditoría | Periodo configurable (semana, catorcena, quincena, mes, semestre, año o rango de fechas); entrega en **Excel o CSV** | 5.9 |
| 16 | Región inicial | **San Miguel de Allende, Comonfort y Celaya (Gto.)** | 6.11 |
| 17 | Categorías | También se pueden **eliminar** categorías y subcategorías **si no tienen datos cargados** | 5.2 |
| 18 | Costo cero | La app y la nube deben **no costar**: todo se procesa en el **teléfono** y la nube gratuita solo **sincroniza texto**; las fotos se quedan en el teléfono | 8 bis |
| 19 | Fuente principal de precios | **Fotos y capturas del hogar** (en el comercio y en casa), con **datos semilla** en un libro Excel | 6.11 |
| 20 | Préstamos entre familiares | Siempre **sin interés** | 5.0 ter |
| 21 | Nube | **Firebase Spark** (Firestore y Authentication con correo o cuenta de Google) | 8 bis |
| 22 | Distribución inicial | **Instalar el APK directamente** en tus dispositivos para probar; Play Console después (la cuenta ya existe) | 8 bis |
| 23 | Pila de desarrollo *(por defecto)* | **Flutter (Dart)** con Firebase; voz, OCR y fotos en el teléfono | 8 bis |
| 24 | Rendimiento *(por defecto)* | Copia local primero, listas paginadas, resúmenes precalculados y pruebas en gama baja; metas: abrir en menos de 2 s y capturar un gasto en menos de 10 s | 8 bis |
| 25 | Voz, OCR y reconocimiento *(por defecto)* | Todo en el teléfono; el reconocimiento de empaques por foto queda para más adelante | 8 bis |
| 26 | Fuentes de precios *(por defecto)* | Capturas del hogar; **no extraer datos** de tiendas en línea; compartir con Open Prices queda **apagado** | 6.11 |
| 27 | Suscripción *(por defecto)* | **Por funciones:** gratis el núcleo, incluidas voz y OCR en el teléfono; de pago más adelante lo que cueste en la nube (reconocimiento de empaques, conexión con cuentas reales, respaldos y fotos en la nube) | 8 bis |
| 28 | Albacea *(por defecto)* | Salvaguardas **activas**: motivo obligatorio, aviso al miembro, suplente, no ser la única confirmación de lo propio y cambio de albacea confirmado por otro adulto | 5.0 ter |
| 29 | Dependientes *(por defecto)* | Si tienen acceso, ven solo **sus propios** gastos y porciones; el administrador puede ampliar | 5.0 ter |
| 30 | Confirmaciones pendientes *(por defecto)* | Recordatorio a las **24 horas**; a los **3 días** se avisa al albacea; **nunca se confirma sola** | 5.0 ter |
| 31 | Plan de nutrición | **Escenario C (híbrido):** el usuario define reglas, esta app propone menús, la app de hábitos mide el cumplimiento; **sin nutriólogo por ahora**, sin metas numéricas | 6.12 |
| 32 | Desarrollo | **Ambas apps con Claude Code** | 8 bis |
| 33 | Play Console | Cuenta **personal creada después del 13/nov/2023**: para producción hace falta la **prueba cerrada (12 personas, 14 días seguidos)**; mientras tanto, APK directo | 8 bis |
| 34 | Health Connect | Lo usan **las dos apps**, con **un solo escritor por tipo de dato** | 6.15 |
| 35 | IA | Para **recetas** y **foto del refrigerador**; opcional, apagada por defecto, con revisión previa; nunca con datos financieros ni de salud | 6.13 |
| 36 | Cuidados paliativos | Se prevé **conectar una app de cuidados** para el familiar con Alzheimer; solo viaja lo mínimo, sin notas clínicas | 6.14 |
| 37 | Fases | Las fases de la hoja de ruta **pueden rediseñarse**; se mantiene el orden mínimo de libro de movimientos primero y funciones opcionales después | 10 |
| 38 | IA con Claude | Se contempla **Claude** como proveedor, con capa de IA **intercambiable**; no es gratuito y la llave **no va en la app** (servidor propio o llave personal) | 6.13 |
| 39 | Conexión entre apps | Un **contrato común** (`CONTRATO_CONEXION_APPS.md`) con instrucciones para cada sesión de Claude Code | 6.16 |
| 40 | Proveedor de IA inicial | **Gemini** con el nivel gratuito de la API; la suscripción Google AI Pro **no cubre la API directamente**, pero da **US$10/mes en créditos de Cloud** que hay que activar (6.13); capa de IA intercambiable para pasar a Claude después | 6.13 |
| 41 | App de cuidados | **Ya existe**, está en su **fase 3** y se **puede rediseñar** para conectarse mediante el contrato; su documento se aportará más adelante | 6.14 |
| 42 | Excel modificado | Se subirá **más adelante** para actualizar el libro de datos semilla | 6.11 |
| 43 | Semana | Inicia en **lunes** (confirmado; configurable por hogar); cada movimiento pertenece a la semana de su fecha | 5.6 bis |
| 44 | Pagos en fin de semana y festivos | Si un pago cae en **fin de semana o festivo pasa al siguiente día hábil**; configurable por ingreso; calendario de días inhábiles editable | 5.1, 5.6 bis |
| 45 | Dispersión del dinero | **INGRESO → PRESUPUESTO → DEUDA → remanente** (abono extra a deuda y, sin deuda, ahorro); si el gasto se pasa del presupuesto baja primero el remanente y después el abono a la deuda, que puede crecer | 5.6 bis |
| 46 | Meta y orden del remanente | **Meta: remanente de 20 % del ingreso**; **todo el remanente paga deuda con costo y después préstamos familiares; luego se ahorra**; ahorro mínimo con deuda **0 %** (confirmado) | 5.6 bis |
| 47 | Ingresos por miembro | Cada miembro configura su **forma de ingreso** (semanal, catorcenal, quincenal, mensual) y su **día de pago**; los **extras** llegan **cualquier día**; la app muestra los datos en **su periodo** | 5.1 |
| 48 | Contabilidad básica | **Dos tipos de egreso (gasto y pago de deuda) y un activo (ahorro)**, dentro de una contabilidad básica de activos, pasivos, ingresos, egresos y patrimonio, con partida doble simplificada | 5.0 bis 2 |
| 49 | Arrastre y protegidos *(por defecto)* | El sobrante de una cuenta de gasto pasa a la semana siguiente hasta **2 semanas**; renta, servicios y **cuidados paliativos** no se recortan solos; la app propone y el usuario confirma | 5.6 bis |
| 50 | Asistente de arranque *(por defecto)* | **5 pasos**, unos 5 minutos; lo omitido se completa después sin bloquear | 5.6 bis |
| 51 | Prioridad de pago entre deudas | Primero los mínimos; el abono extra por **costo (mayor tasa efectiva)**, no por tamaño; **préstamos familiares al último**; las compras a **MSI no reciben extra**; prioridad manual posible | 5.3 |
| 52 | Estimador de intereses | La app **estima la tasa**: calibra con estados de cuenta (manual, foto con OCR o archivo) y luego calcula con los pagos registrados; **sin acceso a la banca móvil ni contraseñas** | 5.3 |
| 53 | Cartera del hogar | Cuentas en **Nu, BBVA, Banamex, Mercado Pago y Stori**; tarjetas **Mercado Pago, Nu, Stori, Azul BBVA, Costco Banamex y Joy Banamex**; crédito automotriz en **Caja Popular Mexicana** | 5.3 bis |
| 54 | Beneficios de tarjetas | La app ayuda a **aprovechar los beneficios sin pagar intereses**: no recomienda tarjetas con saldo con intereses y no empuja a gastar más; cada beneficio lleva fuente y fecha | 5.3 bis |
| 55 | Días inhábiles | **Solo festivos oficiales** de México | 5.1 |
| 56 | Tarjetas Stori y Costco | Stori es **Green** (sin cashback); Costco Banamex cuesta **$650 al año** | 5.3 bis |
| 57 | Captura de gastos por voz | Voz en el teléfono, reglas locales, **siempre con tarjeta de confirmación**, varios gastos por frase, diccionario del hogar y anulación solo por contraasiento | 5.2 |
| 58 | Asistente de menús | Tres costos (teórico, de compra y neto con despensa), tres perfiles de menú y comparación **por compra** por defecto | 6.5 bis |
| 59 | Inventario en el menú | Lo que ya hay en la despensa **no entra al monto**; solo se compra lo que falta; modo de comparación **por compra** confirmado | 6.5 bis |
| 60 | Simulador de deudas | Mayor tasa primero por defecto; comparador de estrategias; **colchón mínimo de 2 semanas** de gastos protegidos (por defecto); el plan se recalcula cada semana | 5.3 ter |
| 61 | Deuda pequeña primero | El orden usa el **costo efectivo** (tasa + cargos fijos evitables al cerrar la cuenta); la pequeña se ofrece como opción si cuesta poco más; pagar el saldo no elimina el cargo, **cerrar sí** | 5.3 ter |
| 62 | Inversión | La inversión se activa solo después de deuda, fondo de emergencia, reservas y metas con fecha; se puede forzar con aviso y bitácora; **sin tasas por defecto**, solo supuestos que escribe la persona | 5.4 bis |
| 63 | Ahorro | Fondo de emergencia **por niveles** (2, 4, 13 y 26 semanas), meta por defecto de 3 meses; orden de reparto de 5 pasos; las reservas anuales se **prorratean dentro del presupuesto** mientras haya deuda | 5.5 bis |
| 64 | Objetivos y plan | Un solo plan con la cascada del hogar, recalculado cada semana; semáforo verde, ámbar y rojo; objetivos compartidos se activan con confirmación | 5.7 bis |
| 65 | Inversión | El fondo de emergencia debe estar **completo a 3 meses** antes de invertir | 5.4 bis |
| 66 | Fondo de emergencia | Meta de **3 meses**, ampliable a **6 meses** y a **1 año**; el colchón de 2 semanas **no** se llena antes de la deuda (todo el remanente va a deuda) | 5.5 bis |
| 67 | Gastos previsibles | **Cuenta de previsión** dentro del presupuesto para **refrendo, predial, agua potable y seguro**; imprevistos con partida propia (2 % por defecto); extras con su efecto en el plan | 5.6 ter |
| 68 | Seguimiento y notificaciones | Tres niveles de lectura (hoy, semana, panorama); nueve indicadores con semáforo editable; revisión semanal de 3 minutos; alertas con nivel y acción; recordatorios locales sin servidor; **máximo 3 avisos no críticos al día**, horas silenciosas de 22:00 a 07:00 y montos ocultos en pantalla bloqueada (por defecto) | 5.9 bis |
| 69 | Ingresos a detalle | Se trabaja con el **neto**; ingresos variables con **base prudente** (12 semanas × 80 %) o **nivelación** según su peso (30 %); los **extras siguen la cascada** con parte libre de 0 % por defecto; reembolsos bajan el gasto y no son ingreso; calendario de flujo con **peor caso** en cada día | 5.1 bis |
| 70 | Efectivo y estados de cuenta | Depósitos y retiros de efectivo como traslados con **origen obligatorio**; ruta del dinero **honesta** (cadena y propósito, no por peso); conciliación **renglón por renglón** con estados de cuenta de débito (manual, foto o archivo, sin entrar a la banca); fecha de operación y de aplicación; el archivo original **no se guarda** por defecto | 5.0 bis 3 |
| 71 | Seguridad, privacidad y respaldo | Reglas de acceso **en el servidor** y libro **solo-agregar**; bloqueo con huella o PIN a 1 minuto; respaldo del hogar **cifrado con contraseña** y restauración solo en hogar vacío; borrado de cuenta dentro de la app y en la web, con movimientos conservados como "Miembro eliminado"; consentimiento por separado para lo opcional | 8 ter |
| 72 | Bienes | Ficha de **vehículo y vivienda** con partidas sugeridas que se vuelven sobres de previsión; **costo de tenencia** (con intereses, sin capital) separado de la **salida de efectivo**; valor estimado **escrito por la persona**, sin depreciación automática; documentos guardados mientras el bien esté activo | 5.6 quater |

*Las decisiones marcadas como "por defecto" las propuse yo con el criterio de costo cero y rapidez en Android; puedes cambiarlas.*

### 12.2 Pendientes por definir

1. **Excel nuevo:** lo subirás más adelante; entonces se analiza y se actualiza el libro de datos semilla (6.11).
2. **App de cuidados (6.14):** ya existe (fase 3, rediseñable). Falta subir su documento para definir qué datos exporta y cómo se conecta (agregar su sección al contrato). ¿Quién captura los gastos y las comidas del papá?
3. **Reglas del plan (6.12):** escribir restricciones, alergias, preferencias y tiempos de comida de cada integrante (ver 6.15).
4. **Hábitos en papel (6.15):** pasar la lista a filas; opcionalmente, redactar el segundo .md.
5. **IA (6.13):** al construirla, verificar los límites actuales del nivel gratuito de Gemini y sus términos de privacidad (uso de datos). Más adelante, decidir si se pasa a Claude y con llave personal o servidor propio.
6. **Contrato de conexión (6.16):** revisarlo y confirmar que las rutas de enlace y los campos sirven; luego pegar las instrucciones en cada sesión.
7. **Prueba cerrada de Play (8 bis):** pensar a qué 12 personas se invitará (familia, amigos) para cuando se quiera publicar.
8. **Ficha de deudas y tarjetas (5.3 bis):** llenar `FICHA_DEUDAS_Y_TARJETAS.xlsx` (límite, saldo, tasa y CAT, corte, fecha límite, MSI) y subirla.
9. **Estados de cuenta de ejemplo (5.3 y 5.0 bis 3):** uno de cada institución (Nu, BBVA, Banamex, Mercado Pago, Stori y Caja Popular Mexicana), **empezando por las cuentas de débito de Banamex y BBVA donde depositas**, y de ser posible uno con un **depósito en efectivo**, con los datos personales tapados, para definir qué campos leer.
10. **Beneficios de tus tarjetas (5.3 bis):** ya verificados en los sitios oficiales (hoja *Beneficios*). Confirmado: **Stori Green** y **Costco $650 al año**. Falta: revisar la página de beneficios de Mercado Pago y leer los documentos de costos de Nu y Stori.
11. **Crédito automotriz (5.3):** ¿permite pagos anticipados a capital y con qué condiciones o comisión?
12. **MSI actuales:** ¿tienes hoy compras a meses sin intereses? Capturarlas en la hoja MSI de la ficha.
13. **Decisiones por defecto (12.1):** revisar las marcadas como "por defecto".
14. **Menús por monto (6.5 bis):** el modo **por compra** y el descuento del inventario ya están confirmados; falta confirmar el umbral de aviso de cambio de comercio (15 %) y la vida útil de perecederos (30 días para precios).
15. **Voz (5.2):** probar dictado real en tu teléfono y pasar la lista de palabras propias del hogar (comercios, apodos de cuentas).
16. **Simulador de deudas (5.3 ter):** confirmar el colchón mínimo (2 semanas de gastos protegidos por defecto) y los hitos de avance; cuando llenes la ficha, el simulador usará tus saldos y tasas reales.
17. **Deuda pequeña (5.3 ter, punto 11):** confirmar los umbrales por defecto (saldo menor al extra de 8 semanas; diferencia menor a $300 o 1 %), y decidir qué tarjetas cerrarías al liquidarlas (el cargo de cada una está en la ficha).
18. **Inversión (5.4 bis):** ¿qué instrumentos usas hoy (para dar de alta cuentas reales)? *(La condición de 3 meses de fondo ya está confirmada.)*
19. **Gastos previsibles (5.6 ter):** para **refrendo, predial, agua potable y seguro**, anota **monto, fecha de vencimiento y cada cuánto se paga** (el agua, ¿anual o por bimestre?); ¿el refrendo y el seguro son del **vehículo del crédito automotriz**? ¿Hay más gastos así (verificación, seguro del hogar, colegiatura anual)?
20. **Fondo de emergencia (5.5 bis):** confirmado en 3 meses, ampliable a 6 meses y a 1 año. Falta decidir **cuándo** ampliarlo (por defecto, la app lo sugiere si hay un solo ingreso o cuidados permanentes).
21. **Objetivos (5.7 bis):** ¿cómo reparten sus aportaciones en pareja o familia (iguales, proporcional al ingreso o monto fijo)? ¿Qué objetivos tienes hoy y con qué fechas?
22. **Notificaciones (5.9 bis):** ¿a qué hora quieres el resumen del lunes y el recordatorio de cierre (por defecto lunes 8:00 y domingo 19:00)? ¿Quieres ver montos en la pantalla bloqueada (por defecto no)? ¿Qué alertas prefieres apagar?
23. **Indicadores (5.9 bis):** revisar los umbrales por defecto de la tabla de salud financiera (remanente 20 % y 10 %, carga de deuda 20 % y 35 %, uso de tarjeta 30 % y 60 %).
24. **Tus ingresos reales (5.1 bis):** ¿qué ingresos tiene cada miembro (tipo, forma de pago, día y neto)? ¿Hay descuentos por nómina que sean deuda? ¿Hay vales de despensa, aguinaldo u otras prestaciones, y en qué fechas?
25. **Ingresos variables y extras (5.1 bis):** ¿alguien tiene ingreso variable? Si sí, ¿qué porcentaje del total es? Confirmar el factor de prudencia de 80 %, el umbral de 30 % para pasar al método de nivelación y la parte libre de los extras (0 % por defecto).
26. **Efectivo y estados de cuenta (5.0 bis 3):** ¿de dónde viene normalmente el efectivo que depositas (ventas, sueldo en efectivo, cobros)? ¿Depositas por cajero, ventanilla o corresponsal? ¿Qué archivos te deja descargar Banamex y BBVA (PDF, CSV, Excel)? ¿Quieres indicar el **propósito** al depositar?
27. **Seguridad (8 ter):** ¿1 minuto de auto-bloqueo te parece bien? ¿Quieres bloquear las capturas de pantalla? ¿Activamos el borrado local tras 10 intentos fallidos (apagado por defecto)? ¿Cuánto tiempo guardar las fotos de tickets (12 meses por defecto)?
28. **Aviso de privacidad y lanzamiento (8 ter):** decidir si la app será **solo para tu familia** o se publicará para terceros; en ese caso, revisión legal del aviso y del borrado de cuentas antes de lanzar.
29. **Desarrollo guiado por especificaciones (anotado el 19/oct/2026):** cuando se junten los repositorios, convertir el paquete final al formato SDD: **constitución** compartida, **especificación por módulo** (historias y criterios de aceptación tomados de las pruebas de este documento, con sus preguntas abiertas marcadas), **plan y tareas** por repositorio, y el contrato entre apps como archivo común. *Por ahora solo queda anotado.*
30. **Tus bienes (5.6 quater):** ¿cuántos vehículos tienes? Para cada uno: modelo y año, vigencia y prima del seguro, monto y vencimiento del refrendo, periodicidad de la verificación, cada cuánto le haces servicio y cuánto cuesta. ¿Tu crédito automotriz exige seguro vigente? De la vivienda: ¿es propia, rentada o familiar? Predial, agua y, si rentas, vigencia del contrato y depósito.

### 12.3 Mapa de avance y lo que falta (17/oct/2026)

| Parte del documento | Estado | Qué falta |
|---|---|---|
| 1 a 4: visión, modos, mapa, semana | Listo | — |
| 5.0 Hogar y perfiles | **Básico** | Asistente de arranque del hogar (personas, dependientes, bienes) |
| 5.0 bis, 5.0 bis 2, 5.0 bis 3, 5.0 ter: cuentas, contabilidad, estados de cuenta y efectivo, roles | A detalle | Falta ver los formatos reales de Banamex y BBVA |
| 5.1, 5.1 bis: ingresos | A detalle | — |
| 5.2 Gastos | Categorías y voz a detalle | Captura por foto de ticket y QR, gastos recurrentes, **quién le debe a quién** entre miembros, corrección de gastos |
| 5.3, 5.3 bis, 5.3 ter: deudas | A detalle | Llenar la ficha con tus datos reales |
| 5.4 bis, 5.5 bis: inversión y ahorro | A detalle | — |
| 5.6, 5.6 bis, 5.6 ter: presupuesto y previsión | A detalle | — |
| 5.7, 5.7 bis: objetivos y plan | A detalle | — |
| 5.9, 5.9 bis: seguimiento, reportes y alertas | A detalle | — |
| 6 Alimentación | A detalle | Pantallas de alimentación; tu Excel modificado |
| 7 Modelo de datos | Resumen | **Consolidarlo** con las entidades nuevas (previsión, objetivos, plan, inversión, deuda) |
| 8 Experiencia móvil | Principios | **Pantallas y navegación** (bocetos) |
| Seguridad, privacidad y respaldo | A detalle (8 ter) | Validar al construir el cifrado local y revisar el aviso de privacidad con un abogado si se publica para terceros |
| Notificaciones y calendario | A detalle (5.9 bis) | — |
| Bienes (vehículo y casa) | A detalle (5.6 quater) | Datos reales del vehículo y la vivienda |
| **Impuestos y comprobantes** | **No existe (opcional)** | Facturas y gastos deducibles; **verificar con un contador** antes de prometer algo |
| 10 Hoja de ruta | Desactualizada | Rediseñar fases y definir el **MVP** (la primera versión que ya sirve) |
| Instrucciones por módulo para Claude Code | **No existe** | Un paquete de instrucciones por módulo para programar la app |

**Orden propuesto para seguir:** (1) bienes; (2) modelo de datos consolidado; (3) pantallas y navegación; (4) hoja de ruta con MVP; (5) paquete para Claude Code y para unir los repositorios.

**Decisión del 19/oct/2026:** con **bienes** se cierra el diseño funcional por módulos. Lo que sigue queda **pendiente hasta que se junten los repositorios**: (1) **modelo de datos consolidado**, (2) **pantallas y navegación**, (3) **hoja de ruta con la primera versión que ya sirve**, y (4) el **paquete en formato SDD** con el contrato entre apps actualizado (pendiente 29).

*Nota (19/oct/2026): el paquete del paso (5) se organizará con el formato de desarrollo guiado por especificaciones cuando se junten los repositorios (pendiente 29).*

---

*Fin del documento (versión 23). Próximo paso: juntar los repositorios y completar lo pendiente de 12.3.*
