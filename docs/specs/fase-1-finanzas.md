# Especificación — Fase 1: Finanzas MVP 1

> Versión 0.5 (23/oct/2026, 2.ª ronda del dueño): **salir de un compartido ya no lo archiva, lo deja privado** (regla 60), el último miembro no puede salirse, quitar a otro con menos de 2 también lo deja privado, la lista de adultos con Finanzas (`fin_adultos_con_finanzas`) para elegir a quién agregar y el aviso informativo del saldo al salirse. Versión 0.4 (23/oct/2026): incorpora la **revisión de calidad de la Fase 1** (`docs/revisiones/fase-1.md`), las **salvaguardas del servidor** (`supabase/README.md`: consulta registrada de la cuenta maestra, libro de papá, libros compartidos, configuración del hogar) y las **respuestas del dueño del 23/oct** (sección 9.0 bis y D14, D18 y D19) en las reglas (sección 5), las pantallas (6) y los criterios (7). Versión 0.3 (22/oct/2026): reglas (sección 5), pantallas (6) y criterios de aceptación (7) para **libros, albaceas, cuenta maestra, grupo de deudas prioritarias e ingresos de papá** (D19), el **contrato con el servidor** (D17 y `supabase/README.md`, "Finanzas (Fase 1)") y los ids estables para reintentar. Versión 0.2 (21/oct/2026): incorpora las respuestas del dueño (sección 9.0 y **D19**: finanzas por persona, cuentas compartidas, albaceas y cuenta maestra). Versión 0.1 (20/oct/2026). Base: diseño de FINANZAS v23 (`docs/modulos/finanzas/ESTRUCTURA_APP_PRESUPUESTO_SEMANAL.md`, secciones 1 a 4, 5.0 a 5.2, 5.6, 5.6 bis, 5.9 bis, 7, 8 bis, 9, 10 y 12), `docs/ROADMAP.md` (secciones 4 y 5), `docs/DECISIONES.md` (D3, D4, D5, D7, D17 y D19) y `docs/DISENO_UX_UI.md` (secciones 8, 9, 13 y 14). Se aplican todas las convenciones de `docs/specs/fase-0-cimientos.md`, sección 4.
>
> Las preguntas para el dueño están en la **sección 9**. Lo que el diseño dejó ambiguo se resolvió con la interpretación más conservadora y se marca como **(interpretación)**; cada una tiene su pregunta.
>
> La lógica está en `paquetes/finanzas_dominio` (Dart puro, **236 pruebas** en verde con los ejemplos numéricos del diseño, el cuadre por libro, los calendarios de papá y los libros compartidos). La app (`app/lib/modulos/finanzas`) tiene **197 pruebas propias** en `app/test/modulos/finanzas` (casos de uso, contrato con el servidor, pantallas, libros compartidos, hojas del (+) y la revisión de calidad).
>
> **Qué cambió en la v0.5 (endurecimiento 1b, N2 a N5):** reglas 50 (motivo de 3 caracteres visibles), 70 (nueva: el motivo), 71 (nueva: nombrar albacea o suplente con `fin_nombrar_albacea`) y 72 (nueva: refresco tras una baja o un cambio de rol y la bitácora); criterios 47 (ajustado) y 62 a 64 (nuevos).
>
> **Qué cambió en la v0.5 (24/oct, importar con archivos no confiables):** regla 64 (remite a la 69) y regla 69 (nueva: topes y tratamiento hostil del archivo elegido, X1 a X5); criterios 51 (ajustado) y 61 (nuevo). **Qué cambió en la v0.5 (23/oct, 2.ª ronda):** regla 60 (reescrita: salirse, sacar y archivar), regla 62 (el chip *Cuenta nueva* siempre visible) y regla 68 (nueva: adultos con Finanzas del hogar); pantalla *Libros y albaceas* (6.1) y la marca *Archivado* (6); criterio 48 (ajustado) y 59 y 60 (nuevos). Las secciones 4.5, 9.0 y 9.0 bis no cambian.
>
> **Qué cambió en la v0.4:** reglas 15, 17, 22, 45, 50, 51, 53, 55 y 56 (reescritas) y 60 a 67 (nuevas); pantallas 6 (marcas del selector, portada de la cuenta maestra, hoja (+) con cuenta existente, importar con selector de archivos, libros y albaceas, regla de día inhábil por deuda), 6.2 y 6.3; criterios 15, 26, 35, 38 y 42 (ajustados) y 45 a 58 (nuevos). Las secciones 4.5, 9.0 y 9.0 bis no cambian.
>
> **Qué cambió en la v0.3:** reglas 44 a 59 (nuevas), pantallas 6.1 a 6.3, criterios 26 (corregido por D19) y 31 a 44 (nuevos), correcciones menores de la sección 4.1 (columnas que pone el servidor) y de 9.1 (filas superadas por 9.0). La sección 4.5 y la 9.0 no cambian.

---

## 1. Resultado utilizable

**Saber cuánto entra, cuánto sale y cuánto queda en la semana.**

- **Laptop (Dueño):** configuras tus cuentas, ingresos, compromisos, deudas y sobres con el asistente de 5 pasos; activas la semana y ves la cascada **ingreso → presupuesto → deuda → remanente** con semáforos; registras y anulas movimientos; concilias el efectivo; cierras la semana con la revisión de 3 minutos; ves el balance, el estado de resultados y el flujo de las próximas semanas con su alerta.
- **Teléfono (Dueño):** registras un gasto en **menos de 10 segundos** (también sin señal) y un ingreso extra; ves el resumen de la semana con su semáforo y los movimientos recientes.
- **Teléfono y laptop (Pareja, coadministrador):** lleva **su propio libro** (su presupuesto, sus cuentas) y registra en las **cuentas compartidas**; no ve las finanzas personales del dueño (D19, P1).
- **Libro de papá:** lo llevan sus albaceas (1 o 2); pensión los días 1 y 11 y apoyo 60+ cada bimestre (P5, P15).
- **Cuenta maestra:** ve todo en solo lectura (D19).

---

## 2. Alcance

### 2.1 Entra en el MVP 1

| Submódulo | Qué entra | Diseño |
|---|---|---|
| Libros (D19) | **Libro personal** por adulto, **libros compartidos** con sus miembros, **libro de papá** con 1 o 2 albaceas que registran en su nombre (motivo y bitácora) y **cuenta maestra** de solo lectura | Sección 4.5 |
| Hogar y perfiles | Personas y roles de D5 (ya creados en la Fase 0); parámetros de Finanzas del hogar (meta de remanente, ahorro mínimo con deuda, tope de arrastre, umbrales de semáforo, cierre automático) | 5.0, 5.6 bis punto 9 |
| Cuentas y libro | Cuentas por clase (activos, pasivos, ingresos, gastos) con su ciclo de vida; libro **solo-agregar** con partida doble simplificada; anulación con contraasiento; saldo confirmado, balance, estado de resultados, disponible y patrimonio; conciliación de saldo con ajuste | 5.0 bis, 5.0 bis 2 |
| Ingresos | Por libro: forma (semanal, catorcenal, quincenal, mensual con **varios días fijos**, por ejemplo 1 y 11, y **cada N meses**, por ejemplo bimestral) y día de pago, neto, certeza, vigencias; **extras** con su fecha real; regla de fin de semana y festivos | 5.1; 5.1 bis puntos 2, 4 y 5 |
| Gastos | Captura manual; árbol de categorías de 3 niveles (sistema y propias; ocultar, archivar, eliminar sin datos); cada categoría principal es una cuenta de gasto; **división por líneas**; "Por clasificar"; gastos con tarjeta (suben la deuda) | 5.2 |
| Compromisos y deudas (mínimo para la cascada) | Gastos fijos y reservas con frecuencia y fecha; deudas con abono planeado, tipo (con costo, familiar, MSI), tasa, mínimo y prioridad manual | 5.3 (solo lo necesario), 5.6 bis punto 3 |
| Presupuesto semanal | Asistente de arranque (5 pasos); plan con la cascada; techo y meta de 20 %; destino del remanente; cierre con sobregasto, abono diferido y déficit; arrastre; propuestas de recorte; vistas por semana, catorcena, quincena y mes | 5.6, 5.6 bis |
| Flujo | Calendario de flujo de 4 a 8 semanas con peor caso diario y **alerta de flujo** dentro de la app | 4; 5.1 bis punto 9; 5.6 bis punto 4 |
| Tablero | Cascada planeado contra real; partidas con semáforo; lo que vence esta semana; indicadores del MVP 1: remanente, carga de deuda, cumplimiento del presupuesto y patrimonio | 5.9 bis puntos 2 y 3 |
| Días inhábiles | Precarga de festivos oficiales (LFT art. 74) por año, que el dueño revisa y activa; días propios | 5.1; decisiones 44 y 55 |
| Datos semilla | Importar la hoja **Categorías** de `data/DATOS_SEMILLA_PRESUPUESTO.xlsx` (o su CSV) | 10 (MVP 1); 6.11 |

### 2.2 Queda fuera (y a dónde va)

| Queda fuera | Va a |
|---|---|
| Captura por voz, foto, OCR y QR | Fase 8+ (el modelo ya guarda la vía de captura) |
| Del modo Pareja y Familiar: transferencias entre miembros **con confirmación**, deudas internas, aportación proporcional (IN11), reporte de auditoría Excel/CSV; finanzas de los familiares | Fase 8+ (el dominio ya maneja estados `pendiente` y confirmaciones). Libros personales, compartidos, albaceas y cuenta maestra **sí entran** (D19) |
| Deudas a detalle: estados de cuenta, estimador de tasa, MSI a detalle, simulador y estrategias, beneficios de tarjetas | Fase 2 y 8+ |
| Ahorro con métodos, fondo de emergencia, alertas con notificaciones (teléfono, avisos al instante y pulsera) | Fase 2 |
| Previsión (sobres 5.6 ter), bienes, inversión, objetivos | Fase 8+ |
| Ingresos variables (base prudente y nivelación), vales de despensa, préstamo recibido (`ingreso_financiado`), recibo de nómina | Fase 2 o 8+ (nadie tiene ingreso variable: P15) |
| Conciliación renglón por renglón con estados de cuenta; exportar a Excel o CSV | Fase 8+ |
| Gastos de cuidado registrados por la cuidadora | Fase 5 |
| Cualquier análisis de dinero con IA en la nube | **Nunca** (D3) |

---

## 3. Convenciones propias de Finanzas

Además de la sección 4 de la Fase 0:

1. **Fuente de los cálculos:** `paquetes/finanzas_dominio`. La app calcula en el dispositivo con la copia local; el servidor guarda, valida la integridad (restricciones, triggers y RLS) y no repite la lógica del motor.
2. **Redondeo R1:** al centavo más cercano; los medios centavos se alejan de cero (`dividirRedondeando`).
3. **Redondeo R2:** los equivalentes se guardan exactos como **monto anual en centavos** y se redondean una sola vez; los renglones de un total se reparten por **mayor resto** para que sumen exacto. La cascada se calcula con los totales ya redondeados (`remanente = ingreso − presupuesto − deuda`), así siempre cuadra en pantalla.
4. **Porcentajes y tasas** en **puntos base** (`int`): 2000 = 20.00 %; 4800 = 48 % anual. Los semáforos comparan la fracción exacta, no el porcentaje redondeado.
5. **Dos fechas por movimiento:** `fecha` (económica: define la semana) y `registrado_en` (cuándo se capturó). El servidor agrega `recibido_en`.
6. **Vista devengada** para planear y cerrar la semana; **vista de flujo** (fechas reales) para la caja y la alerta.
7. **Semana fija en lunes** (convención de GRAVITY), aunque el diseño la permitía configurable (pregunta P11).
8. **Identificadores de dominio** en español sin acentos (`Movimiento`, `cerrarSemana`); tablas con prefijo `fin_`.
9. **Ids estables (UUID v5):** lo que se puede repetir (reintentar sin señal, tocar dos veces, volver a importar) no usa un UUID al azar: su id sale de una clave que dice **qué** es (`ClavesId` en `app/lib/modulos/finanzas/datos/ids.dart`). Así el reintento llega con el mismo id y el servidor no hace nada, en lugar de chocar con un único (`anula_a`, `(hogar_id, padre_id, nombre)`, `(semana_id, origen, origen_id)`…) y quedar en "requiere atención". Lo que es siempre nuevo (un gasto, un ingreso extra) sigue con UUID v4.
10. **Contrato de columnas:** la app nunca manda `recibido_en`, `libro_origen_id`, `libro_destino_id`, `reaperturas` ni las columnas generadas; manda siempre `registrado_en`; `fin_cuentas.libro_id` va nulo solo en las cuentas de gasto; `fin_libro_miembros.desde` y `hasta` son `timestamptz`; los parámetros del libro se cambian con `UPDATE` (la fila la crea el servidor con el libro).

---

## 4. Modelo de datos (Supabase, para el agente backend)

Todas las tablas llevan `hogar_id uuid not null references public.hogares`, RLS activado y trigger de bitácora (`registrar_cambio_en_bitacora`). Dinero en `bigint` de centavos con `check`; porcentajes y tasas en `integer` de puntos base. Los `id` son UUID generados en el dispositivo (con `default gen_random_uuid()` para lo que se cree en el servidor). Se borra la tabla de muestra `finanzas_muestra` de la Fase 0.

### 4.1 Tablas

| Tabla | Campos principales | Notas |
|---|---|---|
| `fin_parametros` | `hogar_id` (PK), `meta_remanente_pb` (2000), `ahorro_minimo_con_deuda_pb` (0), `tope_arrastre_semanas` (2), `partida_ambar_pb` (8000), `partida_rojo_pb` (10000), `remanente_verde_pb` (2000), `remanente_ambar_pb` (1000), `carga_ambar_pb` (2000), `carga_rojo_pb` (3500), `cumplimiento_verde_pb` (9000), `cumplimiento_ambar_pb` (7000), `cierre_automatico_dias` (3), `cuenta_ajustes_id`, `cuenta_apertura_id`, `cuenta_por_clasificar_id` | Una fila por hogar; valores por defecto de 5.6 bis y 5.9 bis |
| `fin_categorias` | `id`, `padre_id` (self), `nivel` (1 a 3, check), `nombre`, `icono`, `color`, `naturaleza` (texto de la plantilla: fija, variable, mixta, eventual…), `prioridad` (`necesario`/`deseable`/`discrecional`), `protegida` (bool), `es_del_sistema`, `oculta`, `archivada`, `posiblemente_deducible`, `cuenta_gasto_id` | Único (`hogar_id`, `padre_id`, `nombre`). Se borra solo sin datos (FK `restrict`); con datos se archiva (5.2) |
| `fin_cuentas` | `id`, `libro_id` (nulo **solo** en `de_gasto` y `gasto_financiero`), `nombre`, `tipo` (`efectivo`, `banco`, `ahorro`, `inversion`, `por_cobrar`, `tarjeta`, `prestamo`, `origen_ingreso`, `de_gasto`, `gasto_financiero`, `por_clasificar`, `ajustes`, `apertura`), `clase` (columna generada desde `tipo`: `activo`, `pasivo`, `ingreso`, `gasto`, `ajuste`, `apertura`), `liquida` (generada), `estado` (`activa`/`congelada`/`cerrada`/`archivada`), `categoria_id`, `titular_id` (persona; nulo = del hogar), `limite_centavos` (tarjetas, opcional), `creada_por`, `creada_en` | Único (`hogar_id`, `nombre`). Cerrar o archivar solo con saldo cero (trigger). Las de `ajustes`, `apertura` y `por_clasificar` se crean solas con el hogar |
| `fin_movimientos` | `id` (UUID del dispositivo), `tipo` (`apertura`, `ingreso`, `gasto`, `reembolso`, `transferencia`, `pago_deuda`, `reclasificacion`, `ajuste`, `anulacion`), `fecha` (date), `registrado_en`, `recibido_en` (lo pone el servidor; la app **no** lo manda), `libro_origen_id` y `libro_destino_id` (los pone el servidor; la app tampoco), `registrado_en` (obligatorio), `cuenta_origen_id`, `cuenta_destino_id`, `monto_centavos` (> 0), `categoria_id` (subcategoría o detalle), `grupo_id` (ticket dividido; capital + intereses), `realizado_por`, `registrado_por` (= `persona_actual()`), `via` (`manual`/`voz`/`imagen`/`qr`/`importacion`), `nota` (≤ 200), `motivo` (≤ 200), `anula_a` (FK a sí misma), `estado_inicial` (`confirmado`/`pendiente`) | **Solo agregar:** trigger `impedir_cambios_solo_agregar` (UPDATE, DELETE, TRUNCATE). Trigger de validación al insertar (sección 4.3). Checks: origen ≠ destino; `motivo` obligatorio en `ajuste` y `anulacion`; `anula_a` solo en `anulacion`. Índice único en `anula_a` (en el MVP 1 no hay anulaciones rechazadas). Índices por (`hogar_id`, `fecha`), por cuenta y por `grupo_id` |
| `fin_ingresos` | `id`, `persona_id`, `nombre`, `tipo` (`salario`/`independiente`/`prestaciones`/`pension`/`otro`), `cuenta_origen_id` (origen de ingreso), `cuenta_destino_id` (activo), `certeza` (`segura`/`probable`/`incierta`), `activo` | Los extras no tienen configuración: son movimientos `ingreso` desde la cuenta "Extras" |
| `fin_vigencias_ingreso` | `id`, `ingreso_id`, `monto_neto_centavos`, `forma` (`semanal`/`catorcenal`/`quincenal`/`mensual`), `dia_semana`, `dias_mes` (`smallint[]`; 0 = último día), `fecha_ancla`, `regla_inhabil` (`siguiente_dia_habil`/`dia_habil_anterior`/`sin_cambio`), `desde`, `hasta` | Un cambio de neto crea una vigencia nueva; de la anterior solo se cierra `hasta` (5.1 bis, punto 2) |
| `fin_compromisos` | `id`, `nombre`, `tipo` (`fija`/`reserva`), `cuenta_gasto_id`, `categoria_id`, `monto_centavos`, `frecuencia` (`semanal`…`anual`, `diaria` con `dias_activos`), calendario (`forma` incluida `cada_meses`, `dia_semana`, `dias_mes`, `fecha_ancla`, `intervalo_meses`), `regla_inhabil` (por defecto `sin_cambio`), `protegida`, `prioridad`, `desde`, `hasta`, `activo` | Renta, servicios, reservas (placas, predial) |
| `fin_sobres` | `id`, `cuenta_gasto_id`, `nombre`, `monto_semanal_centavos`, `protegida`, `prioridad`, `piso_minimo_centavos`, `modo_arrastre` (`arrastrar`/`al_remanente`), `activo` | Partidas variables por rubro |
| `fin_deudas` | `id`, `nombre`, `tipo` (`con_costo`/`familiar`/`msi`), `cuenta_pasivo_id` (tarjeta o préstamo), `abono_centavos`, `frecuencia`, calendario (como compromisos), `minimo_centavos`, `tasa_anual_pb` (check: > 0 en `con_costo`; 0 en las demás), `prioridad_manual`, `activa` | El saldo sale del libro (cuenta pasivo). La Fase 2 amplía esta tabla |
| `fin_dias_inhabiles` | `id`, `fecha`, `nombre`, `tipo` (`festivo_oficial`/`personal`), `fuente`, `activo`, `revisado_por`, `revisado_en` | Único (`hogar_id`, `fecha`) |
| `fin_semanas` | `id`, `semana_inicio` (date, check lunes: `extract(isodow from semana_inicio) = 1`), `estado` (`borrador`/`activa`/`pendiente_ingreso`/`por_cerrar`/`cerrada`), `metodo` (`sobres`), `ingreso`, `presupuesto`, `deuda_plan`, `remanente_plan`, `meta_remanente_pb`, `ahorro_minimo_con_deuda_pb`, `techo`, `activada_por`, `activada_en`, `reaperturas` (las pone el servidor) | Único (`hogar_id`, `semana_inicio`). Es la foto del plan; cambia solo mientras no esté cerrada |
| `fin_partidas_semana` | `id`, `semana_id`, `origen` (`compromiso`/`sobre`), `origen_id`, `cuenta_gasto_id`, `tipo` (`fija`/`variable`/`reserva`), `asignado`, `arrastre_recibido`, `protegida`, `prioridad`, `piso_minimo`, `modo_arrastre` | `asignado` ya repartido por mayor resto |
| `fin_abonos_semana` | `id`, `semana_id`, `deuda_id`, `abono_planeado`, `minimo`, `extra_planeado` | |
| `fin_cierres` | `id`, `semana_id`, `version` (único con `semana_id`), `ingreso_real`, `gasto_real`, `abono_real`, `abono_diferido`, `abono_extra_real`, `ahorro_real`, `deficit`, `arrastre_siguiente`, `accion_elegida`, `con_pendientes`, `activos`, `pasivos`, `patrimonio`, `cerrado_por`, `cerrado_en` | **Solo agregar** (foto del cierre y del balance). Reabrir y volver a cerrar crea la versión siguiente |
| `fin_cierre_partidas` | `id`, `libro_id`, `cierre_id`, `partida_id`, `gastado`, `arrastre_siguiente`, `al_remanente` | Solo agregar |
| `fin_cierre_abonos` | `id`, `libro_id`, `cierre_id`, `deuda_id`, `planeado`, `real`, `minimo`, `diferido` (generado: planeado − real) | Solo agregar; es el `AbonoDiferido` del diseño |
| `fin_ocurrencias` | `id`, `origen` (`ingreso`/`compromiso`/`deuda`), `origen_id`, `fecha_programada`, `fecha_ajustada`, `monto_esperado`, `estado` (`esperada`/`cumplida`/`parcial`/`retrasada`/`no_llegara`/`omitida`), `movimiento_id` | Horizonte de 13 semanas; al cambiar la configuración se regeneran las que siguen `esperada` |
| `fin_conciliaciones` | `id`, `cuenta_id`, `fecha`, `saldo_declarado`, `saldo_calculado`, `diferencia` (generada), `ajuste_movimiento_id`, `motivo`, `persona_id`, `creado_en` | Solo agregar |
| `fin_importaciones` | `id`, `archivo`, `hoja`, `filas_leidas`, `filas_creadas`, `filas_omitidas`, `detalle` (jsonb), `persona_id`, `creado_en` | Solo agregar |

**Vistas de apoyo** (con `security_invoker = true`, para que respeten la RLS): `fin_v_saldos` (saldo confirmado por cuenta con el signo de su clase) y `fin_v_gasto_semana` (gasto neto por cuenta de gasto y semana).

**Para la Fase 8 (no se crea ahora):** `fin_confirmaciones` (movimiento, resultado, por, en_nombre_de, motivo, fecha_hora; solo agregar), deudas internas y metas de aportación.

**Cambios por D19 (sección 4.5):** las tablas de configuración, plan, conciliaciones, cierres y ocurrencias llevan `libro_id`; `fin_cuentas.titular_id` se reemplaza por `libro_id`; `fin_semanas` es única por (`libro_id`, `semana_inicio`); `fin_parametros` es por libro (con los valores del hogar como plantilla); `fin_movimientos` agrega `en_nombre_de` (persona, para el albacea) y su `motivo` es obligatorio cuando `en_nombre_de` no es nulo; `fin_vigencias_ingreso.forma` agrega `cada_meses` con `intervalo_meses`; `fin_deudas` agrega `grupo_prioritario` (bool) y `orden_grupo`.

### 4.2 Reglas por rol (RLS), con las funciones de la Fase 0

| Tabla | Leer | Insertar | Cambiar | Borrar |
|---|---|---|---|---|
| `fin_movimientos`, `fin_conciliaciones`, `fin_cierres*`, `fin_importaciones` | `puede(hogar_id, 'finanzas', 'leer')` | `puede(…, 'escribir')` y `registrado_por = persona_actual()` | **Nadie** (trigger) | **Nadie** (trigger) |
| Configuración: `fin_parametros`, `fin_categorias`, `fin_cuentas`, `fin_ingresos`, `fin_vigencias_ingreso`, `fin_compromisos`, `fin_sobres`, `fin_deudas`, `fin_dias_inhabiles` | `puede(…, 'leer')` | `puede(…, 'administrar')` | `puede(…, 'administrar')` | Solo `fin_categorias` y `fin_cuentas` sin datos (FK `restrict`), con `administrar` |
| Plan: `fin_semanas`, `fin_partidas_semana`, `fin_abonos_semana`, `fin_ocurrencias` | `puede(…, 'leer')` | `puede(…, 'escribir')` | `puede(…, 'escribir')`, nunca si la semana está `cerrada` (trigger) | Nadie |

**Con D19 la condición cambia:** en lugar de `puede(hogar_id, 'finanzas', …)` se usa `fin_puede(libro_id, accion)` (sección 4.5): ver su libro, los compartidos de los que es miembro y, para los albaceas, el libro de papá; la cuenta maestra solo lee todo. **Dueño y coadministrador** tienen Finanzas con alcance **propio** (cada uno su libro); **familiar, cuidador y casa** no ven nada de Finanzas (el cuidador registrará gastos de cuidado en la Fase 5 por una regla `restringida` propia, como pendientes en el libro de papá). Permisos de columna explícitos como en la migración base.

### 4.3 Validación en el servidor al insertar un movimiento

El trigger repite las reglas que no dependen de cálculos (la tabla de combinaciones es la de `libro.dart`):

| Tipo | Origen → destino |
|---|---|
| `apertura` | apertura → activo, o pasivo → apertura (una por cuenta) |
| `ingreso` | origen de ingreso → activo |
| `gasto` | activo o pasivo → gasto |
| `reembolso` | gasto → activo o pasivo |
| `transferencia` | activo → activo |
| `pago_deuda` | activo → pasivo |
| `reclasificacion` | "Por clasificar" → gasto |
| `ajuste` | ajustes → activo o pasivo, o activo o pasivo → ajustes |
| `anulacion` | el original con origen y destino invertidos, mismo monto; el original no es una anulación y no tiene otra |

Además: ambas cuentas son del mismo hogar y están `activa` (una anulación también acepta `congelada`). Un movimiento con `estado_inicial = pendiente` no cambia el saldo confirmado (en el MVP 1 todos nacen confirmados).

### 4.4 Lo que el dominio ya modela

| Diseño (sección 7) | Dominio (`finanzas_dominio`) |
|---|---|
| Cuenta, ClaseCuenta | `Cuenta`, `TipoCuenta`, `ClaseCuenta`, `EstadoCuenta` |
| Movimiento, Confirmación, Conciliación | `Movimiento`, `TipoMovimiento`, `Confirmacion`, `Conciliacion`, `LibroMovimientos` |
| ConfigIngreso, Ocurrencia, DíaInhábil | `CalendarioPago`, `FechaPago`, `DiaInhabil`, `CalendarioDiasInhabiles` |
| PresupuestoSemana, PartidaPresupuesto | `PlanSemanal`, `PartidaPlan`, `IngresoPlan`, `DeudaPlan`, `ParametrosPlan` |
| CierreSemana, AbonoDiferido | `CierreSemanal`, `CierrePartida`, `AbonoReal` |
| Balance, estado de resultados, CierrePeriodo | `Balance`, `EstadoResultados` |
| ProyeccionFlujo | `ProyeccionFlujo`, `DiaFlujo`, `FlujoSemana` |

### 4.5 Libros, albaceas y cuenta maestra (D19)

| Tabla | Campos principales | Notas |
|---|---|---|
| `fin_libros` | `id`, `hogar_id`, `nombre`, `tipo` (`personal`/`compartido`/`representado`), `titular_id` (persona; obligatorio en `personal` y `representado`, nulo en `compartido`), `activo`, `creado_por`, `creado_en` | Un libro `personal` por persona y hogar (único). `representado` = el de papá (persona bajo cuidado, sin cuenta) |
| `fin_libro_miembros` | `libro_id`, `persona_id`, `papel` (`titular`/`miembro`/`albacea`/`albacea_suplente`), `desde`, `hasta` | El titular de un libro personal es su único miembro. En un `representado`: 1 albacea y, opcional, 1 suplente (máximo 2). Los compartidos tienen 2 o más miembros adultos |
| `membresias.es_maestra` (columna en la tabla de la Fase 0) | `bool`, default `false` | Una sola por hogar (índice único parcial); solo el dueño la asigna (función `asignar_cuenta_maestra`) |

**Funciones (security definer, `search_path` fijo, como las de la Fase 0):**

- `fin_es_miembro(libro_id)`: la persona actual es miembro vigente del libro (cualquier papel).
- `fin_puede(libro_id, accion)`: `leer` → miembro o cuenta maestra; `escribir` → miembro (titular, miembro o albacea; el suplente solo si no hay albacea vigente); `administrar` → titular de un `personal`, cualquier miembro adulto de un `compartido`, albacea de un `representado`. La cuenta maestra **nunca** escribe en libros de los que no es miembro. Además se exige que el rol tenga Finanzas (`permisos_rol` con alcance `propio`).
- `fin_registrar_consulta_maestra(libro_id)`: la app la llama al abrir un libro ajeno con la cuenta maestra; deja la consulta en la bitácora (acción `finanzas.consulta_maestra`).

**Reglas:**

1. Las cuentas son del libro (`libro_id`); una transferencia entre libros (aportación a un compartido) es un solo movimiento con origen en un libro y destino en otro, y se ve desde los dos. El nombre de una cuenta de otro libro no se ve si no eres miembro (la app muestra *"Aportación de Ana"*).
2. Las categorías y las cuentas de gasto son del **hogar** (árbol común); cada libro tiene su presupuesto con sus sobres.
3. Un movimiento con `en_nombre_de` lo registra un albacea en el libro `representado`; `motivo` obligatorio; queda en la bitácora con quién y en nombre de quién.
4. **Grupo de deudas prioritarias (P12):** el titular elige qué deudas forman el grupo y su orden. El remanente (después de la meta de ahorro) y el abono que libera una deuda liquidada van a la siguiente deuda del grupo; cuando el grupo queda pagado, ese dinero va a **ahorro**. Se muestra en la revisión semanal.
5. **Día inhábil por compromiso (P13):** cada compromiso y deuda trae su `regla_inhabil`; por defecto `sin_cambio` (se puede pagar en fin de semana). Solo el pago a **la caja** usa `siguiente_dia_habil` (se configura con los datos del dueño, no en el repositorio).
6. Ingresos de papá (P15): `mensual` con `dias_mes = {1, 11}` y `siguiente_dia_habil`; apoyo 60+ con `cada_meses`, `intervalo_meses = 2`, certeza `probable` y la fecha que capture el dueño.

---

## 5. Reglas de negocio

### Semana, fechas y dinero
1. La semana va de **lunes a domingo**; cada movimiento pertenece a la semana de su **fecha**, no de su captura (5.6 bis punto 2; decisión 43).
2. Dinero en centavos con los redondeos R1 y R2 (sección 3).
3. **Equivalentes semanales** (sección 4): semanal = monto; catorcenal = monto × 26 ÷ 52; quincenal = × 24 ÷ 52; mensual = × 12 ÷ 52; bimestral, trimestral y semestral = × (12/n) ÷ 52; anual = ÷ 52; diaria = monto × días activos.
4. **Vistas por periodo** (5.6 bis punto 2): el presupuesto se prorratea con catorcena = semanal × 2, quincena = × 52 ÷ 24 y mes = × 52 ÷ 12 (calculados desde el monto anual exacto); el gasto real sale siempre de las fechas de los movimientos. Quincenas del calendario: 1–15 y 16–fin **(interpretación)**.

### Calendario
5. Un pago que cae en **sábado, domingo o día inhábil** pasa al **siguiente día hábil**; configurable por ingreso (anterior o sin cambio) (5.1; decisión 44).
6. Los días inhábiles son **solo los festivos oficiales** (decisión 55): la app precarga por año los del artículo 74 de la Ley Federal del Trabajo (sin jornadas electorales) y el dueño los **revisa y activa**; puede agregar días propios.
7. Los **pagos que salen** (renta, servicios, deudas) se quedan en su fecha por defecto **(interpretación conservadora; pregunta P13)**.
8. Un día 29, 30 o 31 que el mes no tiene se paga el **último día** del mes **(interpretación)**.

### Libro y cuentas
9. **Partida doble simplificada:** cada movimiento tiene origen y destino con el mismo monto, según la tabla de 4.3 (5.0 bis 2 punto 2). Una compra con tarjeta sube la deuda y no baja el efectivo; el pago de capital baja ambos; los intereses son **gasto financiero** aparte.
10. **Solo agregar:** nada se edita ni se borra. Se corrige con **anulación**: contraasiento con origen y destino invertidos, mismo monto y **motivo obligatorio** (5.0 bis). Solo hay anulación total; para devolver una parte se usa un **reembolso**, que baja el gasto y no es ingreso (5.1 bis punto 1).
11. El contraasiento lleva la **misma fecha económica** que el original, así la semana del original se recalcula; las fotos de cierre guardadas no cambian **(interpretación; pregunta P14)**.
12. Mismo id y mismo contenido = no pasa nada (cola sin conexión idempotente); mismo id con otro contenido = error.
13. Saldo = saldo inicial + entradas − salidas, con el signo de su clase; el saldo inicial es un movimiento de **apertura** con fecha, uno por cuenta (5.0 bis 2 punto 5).
14. Se muestran: **saldo confirmado**, **disponible** (efectivo y bancos), **patrimonio** (activos − pasivos) y el **cuadre** (patrimonio = inicial + resultado + ajustes; si no, "descuadre") (5.0 bis 2 puntos 3 y 7).
15. Una cuenta de **activos o pasivos** se **cierra o archiva solo con saldo cero**; las de **gasto e ingreso** se cierran o archivan **sin pedir saldo cero** (respuestas del 23/oct): ya no admiten movimientos nuevos, pero lo anterior se puede anular. Se **elimina solo si no tiene movimientos**; congelada no admite movimientos nuevos (5.0 bis 2 punto 5).
16. **Conciliación:** se declara el saldo real; si hay diferencia, se registra un **ajuste** con motivo en la cuenta Ajustes, visible siempre (5.0 bis 2 punto 6). Para el efectivo se propone al cierre semanal.
17. "Por clasificar" es gasto pero no entra a los reportes por rubro; se clasifica con un movimiento de **reclasificación** (5.0 bis 2 punto 5). **La categoría de un gasto es opcional**: sin ella el gasto queda en "Por clasificar" (el árbol de categorías viene precargado).

### Ingresos y gastos
18. Se trabaja con el **neto**; un cambio de neto crea una **vigencia nueva** y no toca el historial (5.1 bis punto 2).
19. Los ingresos `incierta` no cuentan; se muestran como **ingreso potencial**. `segura` y `probable` sí cuentan (5.1; 5.6 bis punto 3).
20. Los **extras** se registran con su fecha real y cuentan en la semana en que llegan; su reparto sigue la cascada (5.1 bis punto 4).
21. Un mes con tres catorcenas o cinco semanas **no es extra**: ya está en el equivalente semanal; el flujo lo muestra tal cual (5.1 bis punto 4; 5.6 bis caso límite 2).
22. Todo gasto sale de una **cuenta existente del libro activo** (efectivo, banco o tarjeta; regla 62) y entra a una **cuenta de gasto** por rubro; las subcategorías son su desglose; un ticket con varios rubros se **divide por líneas** con el mismo `grupo_id` (5.2).
23. Las categorías se crean, ocultan, renombran, mueven y **eliminan solo sin datos**; con datos se archivan o se fusionan (5.2; decisión 17).
24. Pagos de deuda, ahorro e inversión **no son categorías de gasto** (5.2).

### Presupuesto y cascada
25. **Cascada** (5.6 bis punto 4; decisión 45): ingreso (seguros y probables) − presupuesto (fijos + variables + reservas) − deuda planeada = **remanente**.
26. **Meta de remanente: 20 %** del ingreso; **techo** = ingreso − deuda planeada − meta (5.6 bis punto 4, paso 7; decisión 46).
27. **Destino del remanente** (5.6 bis punto 7; decisiones 46 y 51): primero **abono extra** a deudas con costo por **mayor tasa** (desempate: más interés en pesos), después **préstamos familiares**; las compras a **MSI no reciben extra**; sin deuda, va a **ahorro**. La prioridad manual pasa por encima del costo. **Ahorro mínimo con deuda: 0 %** (porcentaje del remanente, **interpretación**).
28. Una deuda con costo exige su **tasa anual**; préstamos familiares y MSI van sin tasa. La mensualidad de MSI cuenta completa como mínimo.
29. **Sobregasto** (5.6 bis punto 6): baja primero el **remanente**, después el **abono planeado** (lo no abonado queda como **abono diferido** y no reduce el saldo) y al final queda un **déficit**.
30. **Qué abono se reduce primero:** préstamos familiares; luego, en tarjetas y créditos, lo que pasa del mínimo, de menor a mayor costo; al final los **mínimos** (las mensualidades MSI al último, **interpretación**). Un abono bajo el mínimo exigible muestra **alerta roja**.
31. **Gastos protegidos** (renta, servicios y cuidados de largo plazo) nunca se recortan solos; la app **propone** recortes en lo discrecional, luego lo deseable y al final lo necesario, respetando el piso mínimo y lo ya gastado (5.6 bis punto 6, regla 5).
32. **Arrastre** (decisión 49): el sobrante de un **sobre** pasa a la semana siguiente hasta **2 semanas de su monto** (2 × asignado semanal); el exceso va al remanente. Gastar lo arrastrado no es sobregasto **(interpretación del tope por monto; pregunta P12)**.
33. **Cierre en vista devengada** **(interpretación)**: en fijos y reservas, lo asignado se da por consumido y solo cuenta la diferencia del pago real (una luz $200 más cara es sobregasto; pagar la renta completa no lo es); en sobres cuenta lo gastado. Un ingreso que no llegó resta completo en la semana en que debía llegar.
34. **Estados de la semana:** `borrador` → `activa` → `por cerrar` → `cerrada` (y `pendiente de ingreso` si se retrasa uno). Se cierra el lunes al abrir la app o con *Cerrar semana*; sin cerrar en **3 días**, se cierra con pendientes marcados; se reabre con confirmación y queda en la bitácora (5.6 bis punto 8; 5.9 bis punto 4).
35. Al cerrar, la app **propone** aplicar el remanente (abono extra o ahorro); al confirmar se crea el movimiento. **La app no mueve dinero sola** (5.6 bis punto 6, regla 6).
36. Cambios al plan a mitad de semana valen **de ahí en adelante**; una semana cerrada se corrige solo con anulación y contraasiento.
37. **Proyección de salida de deuda** (ilustrativa): interés semanal simple = saldo × tasa ÷ 52; el abono de una deuda ya liquidada se libera al volver a armar el plan, no solo.

### Flujo, indicadores y privacidad
38. **Calendario de flujo** de 4 a 8 semanas: saldo actual + ingresos seguros − pagos programados; si en un día hay entradas y salidas, **primero las salidas** (peor caso) y también el saldo al cierre; los `probable` van aparte (5.1 bis punto 9).
39. **Alerta de flujo** dentro de la app si el peor caso baja de cero (o del mínimo configurable). Nunca propone usar una tarjeta con intereses para tapar el hueco.
40. **Semáforos** (valores por defecto editables): partida verde hasta 80 %, ámbar hasta 100 %, rojo arriba; remanente verde ≥ 20 %, ámbar ≥ 10 %; carga de deuda verde < 20 %, ámbar ≤ 35 %, rojo arriba; cumplimiento verde ≥ 90 %, ámbar ≥ 70 %. Nunca dependen solo del color (5.6 bis punto 10; 5.9 bis puntos 3 y 5).
41. Los meses tienen 4 o 5 lunes: los resúmenes mensuales se muestran **por semanas con promedio semanal** (5.9 bis punto 5).
42. **D3:** el dinero nunca va a la IA en la nube ni a las bocinas. Las herramientas de GRAVITY de Finanzas son `soloLocal`.
43. **Privacidad en pantalla:** montos ocultables (modo privado) y sin montos en la pantalla bloqueada ni en la pulsera (`DISENO_UX_UI.md`, sección 21; decisión 68 de FINANZAS).

### Libros, albaceas y cuenta maestra (D19)

44. **Libro personal:** cada adulto con Finanzas (dueño o coadministrador) lleva el suyo; lo **crea el servidor** al darle el rol y la app lo busca (no lo crea). La pareja no ve el libro personal del dueño ni al revés (P1).
45. **Libro compartido** (p. ej. "Gastos de la casa"): lo crea un adulto con Finanzas con **2 o más miembros adultos** y queda como su **administrador** (regla 60); cualquier miembro registra. Su id sale del nombre: crearlo dos veces no lo duplica.
46. **Árbol común, presupuesto propio:** las categorías y sus cuentas de gasto son del hogar; cada libro tiene sus sobres, su plan y su gasto (en la cuenta de gasto del hogar cada libro ve **solo lo que gastó él**).
47. **Entre libros** cruzan **solo** la transferencia y el pago de deuda (y su anulación): una aportación a un compartido o el pago de una deuda de otro libro. Es un solo movimiento que se ve desde los dos libros; la cuenta del otro lado aparece como una cuenta virtual con el nombre del libro (*"Aportación de Ana"*) y, si no eres miembro, sin su nombre. Cualquier otro tipo entre libros se rechaza.
48. **Cuadre por libro:** `patrimonio final = inicial + resultado + ajustes + aportaciones recibidas − aportaciones entregadas`. Una aportación cambia el patrimonio de cada libro **sin pasar por el resultado**: no es ingreso de quien la recibe ni gasto de quien la entrega. Anular una aportación la descuenta de su mismo lado. Ejemplo: Ana aporta $2,000 a la casa; el patrimonio de Ana baja $2,000 sin gasto, el de la casa sube $2,000 sin ingreso, y los dos libros cuadran.
49. **Libro de papá** (persona representada, sin cuenta): lo crea el **dueño** con `fin_crear_libro_representado`; quien lo crea queda como **albacea** y puede haber un segundo adulto como **suplente** (máximo 2). Su id sale del nombre de la persona (reintentar no crea otra persona).
50. **En nombre de papá:** **todo** movimiento que toque el libro lleva `en_nombre_de` = papá, `realizado_por` = papá, `registrado_por` = quien captura y un **motivo obligatorio**: el saldo inicial (apertura), el ingreso, el gasto, el ajuste de una conciliación, la reclasificación, el abono y el ahorro del remanente, una **aportación o un pago de deuda desde otro libro** y la **anulación**; si no, el servidor rechaza con 23514. La app lo pide siempre y con **al menos 3 caracteres visibles** (regla 70); el saldo inicial y una conciliación sin diferencia usan el motivo por omisión *"Saldo inicial"* y *"Conciliación sin diferencia"*. Todo queda en la bitácora con quién y en nombre de quién; una salida hacia un libro personal deja además la entrada `finanzas.salida_libro_representado`, que ve quien lleva el libro de papá.
51. **Suplente:** lee siempre; **escribe y administra solo si no hay albacea vigente** (D17). El albacea es **vigente** solo si su cargo está abierto **y** sigue siendo un adulto del hogar con Finanzas (membresía activa); si se va o pierde el rol, el suplente escribe al instante. Quien no es el dueño no ve las membresías de los demás, así que la app **le pregunta al servidor** (`fin_puede`, `escribir` y `administrar`) por los libros donde es suplente y usa esa respuesta; sin respuesta, el espejo por fechas. Con albacea vigente, la app no le muestra botones de escribir.
52. **Ingresos de papá (P15):** la **pensión** es mensual en los días **1 y 11** (dos pagos al mes = 24 al año, equivalente semanal × 24 ÷ 52) con *siguiente día hábil* si cae en fin de semana o festivo; el **apoyo 60+** es *cada 2 meses* (`cada_meses`, `intervalo_meses = 2`), certeza *probable*, desde la fecha de un pago que ya conozca el dueño. La app **ofrece la forma ya llena y no inventa montos ni fechas**: el neto y la fecha los captura el dueño. Ejemplo: $3,200 por pago de pensión son $1,476.92 por semana.
53. **Día inhábil por origen (P13):** la regla se guarda siempre (`regla_inhabil`): un **ingreso** pasa por omisión al *siguiente día hábil*; un **compromiso** o una **deuda** se queda **en su fecha** (`sin_cambio`). La regla **se elige por deuda** en su formulario (*En su fecha*, *Siguiente día hábil* o *Día hábil anterior*); el dueño la usa solo en su crédito automotriz (la caja), que se configura en la app y **no se guarda en el repositorio**. Una regla elegida manda sobre la de omisión.
54. **Grupo de deudas prioritarias (P12, P19):** el titular elige qué deudas lo forman y su orden. El abono extra va **solo** a las deudas del grupo, en ese orden; primero se aparta el ahorro mínimo (porcentaje del remanente); el **abono que libera una deuda liquidada** pasa a la siguiente del grupo; cuando todo el grupo queda pagado, el remanente y los abonos liberados van a **ahorro**. Las deudas fuera del grupo siguen con su abono planeado y su mínimo, sin extra. Sin grupo rige la regla 27 (por costo). La app **propone** en la revisión semanal y la persona confirma (regla 35).
55. **Cuenta maestra con login propio (23/oct):** una por hogar. Como cada persona tiene un solo login, es **otra persona con su propia cuenta**, que crea el dueño (rol coadministrador con la marca de maestra); **no se prohíbe** que el dueño sea también la maestra con su propia persona. **Es de solo lectura total**: no registra nada, tampoco lo suyo (lo suyo lo registra el dueño con su cuenta normal), no tiene (+) ni órdenes de voz o escritas que abran una hoja de registro, y no ve Ajustes, Importar ni el asistente; tampoco tiene libro personal ni es miembro de un compartido (el servidor lo rechaza con 42501). Entra por la **portada** (regla 56). Si el dueño es también la maestra, escribe en lo suyo como dueño y en lo ajeno solo lee.
56. **Cada consulta queda en la bitácora y habilita la lectura (I2):** para leer el **contenido** de un libro ajeno (cuentas, movimientos, plan, cierres) la cuenta maestra debe tener una **consulta registrada en los últimos 30 minutos**; sin ella el servidor **filtra en silencio** (no da error: devuelve vacío). Sin consulta solo ve la **portada**: los libros y quién los lleva, las personas, las categorías y las cuentas de gasto del hogar. Por eso el orden es: (1) llamar a `fin_registrar_consulta_maestra(libro)` **antes** de pedir los datos de ese libro, (2) recargar con la consulta vigente, (3) si el libro ajeno vuelve vacío (todo libro tiene al menos sus cuentas técnicas), la consulta venció: registrar otra vez y recargar, una sola vez más; si sigue vacío o no se pudo registrar, **no se muestra el libro** (con *Reintentar*, sin reintentos automáticos). Mientras el libro siga abierto la app **renueva la consulta cada 25 minutos** y recarga, sin tapar la pantalla ni avisar; al cerrar el libro la renovación se detiene. Abrir un libro propio no registra nada (la función devuelve `false`). Cada persona ve en *Ajustes de Finanzas › Privacidad* que la cuenta maestra existe y quién es.
57. **Permisos en la interfaz:** la pantalla esconde lo que no corresponde con el espejo de `fin_puede` más la matriz por rol (`puedeSobre`); **la verdad está en el servidor** (RLS). Familiar, cuidador y Casa no ven nada de Finanzas; las secciones de configuración (asistente, importar y ajustes) piden la acción *administrar* en la ruta (`exigeAccion`).
58. **Ids estables y reintentos:** llevan id derivado la **anulación** (del movimiento original: hay a lo más una por movimiento, y "Deshacer" repetido avisa *"Ese movimiento ya está anulado"*), las **categorías y cuentas de gasto importadas** (del hogar y su ruta en el árbol), la **semana** (libro y lunes), sus **partidas y abonos**, el **cierre** (semana y versión), los **renglones del cierre**, los movimientos del **remanente** (cierre y destino), las **ocurrencias**, los **días inhábiles** (hogar y fecha), los **libros compartido y de papá** y los **miembros**. Reintentar nunca choca con `anula_a` ni con los únicos.
59. **Cierre de semana en el servidor:** primero se guarda el **cierre** (versión `reaperturas + 1`, con sus partidas y abonos, cada renglón con su id) y **después** la semana pasa a `cerrada`; hacerlo al revés da 55000. **Reabrir** solo cambia el estado, necesita señal y confirmación, queda en la bitácora y suma una reapertura: el siguiente cierre es la versión siguiente. En una semana cerrada, el plan no cambia.
60. **Libros compartidos: administrador, visibilidad y salida (23/oct, 2.ª ronda):** quien lo crea es su **administrador** (`creado_por`): agrega y saca miembros, decide si es **pública o privada** y lo archiva o reactiva; el dueño del hogar también cambia la membresía si es miembro. Al crearlo se elige **Privada** (por omisión: la ven y escriben sus miembros; la lee también la cuenta maestra con consulta; **el dueño no entra si no es miembro**) o **Pública** (además la **leen**, sin escribir, los adultos con Finanzas del hogar; la maestra sigue necesitando la consulta). **Cualquier miembro puede salirse** cuando quiera (*Salir del libro*), **menos el último**: su fila deja de ser vigente al instante (la hora la pone el teléfono) y lo que registró queda en el historial. **Si al salirse (o al ser sacado) quedan menos de 2 miembros, el presupuesto NO se archiva: pasa a privado y sigue activo** para quien se queda, que queda como administrador (el servidor lo hace en el mismo cambio: `visibilidad = 'privada'`, `creado_por` = el que queda; la app lo refleja y relee). Si se sale el administrador y quedan 2 o más, el cargo pasa al miembro vigente más antiguo. El **último miembro** no puede salirse (22023: *"El último miembro de un libro compartido no puede salirse"*); para dejar de usarlo lo **archiva**, que es solo una acción explícita del administrador (nunca ocurre sola). Quien se salió no reabre su fila: el administrador le agrega una fila nueva. Al salirse, si el presupuesto tiene un saldo distinto de cero, la app muestra un **aviso informativo, sin bloquear**: *"El presupuesto tiene $X; lo que aportaste se queda aquí"* ($X se oculta si los montos están ocultos). Un libro **archivado** es de **solo lectura para todos** (sus miembros y la maestra lo leen; nadie registra); solo su administrador lo reactiva. La app esconde o deshabilita lo que no corresponde y marca el libro como *Pública/Privada*, *Archivado* o *Solo lectura*; un administrador que queda solo ve el aviso *"Eres el último miembro"* en lugar de *Salir del libro*.
61. **Configuración del hogar (M6):** categorías, cuentas de gasto, días inhábiles e importaciones las hacen el **dueño y la pareja**; la cuenta maestra que no es la dueña solo las lee y la app no le muestra esas acciones.
62. **Hoja (+) Gasto: cuenta existente (23/oct):** el gasto sale de una **cuenta existente del libro activo**; la hoja no inventa ni mezcla cuentas de otros libros. Si el libro **no tiene ninguna**, ofrece *Crear cuenta nueva* ahí mismo (nombre, tipo —efectivo, banco o tarjeta— y saldo inicial opcional; en una tarjeta es lo que se debe) y, al crearla, sigue con el gasto sin salir de la hoja. Con cuentas, queda un chip *Cuenta nueva* al final. Solo quien administra el libro crea cuentas; a los demás se les dice a quién pedírsela. El **ingreso extra** funciona igual (efectivo o banco).
63. **Categoría opcional:** la hoja solo preselecciona la **última categoría que usó la persona**; sin historial no hay ninguna elegida, y tocar la elegida otra vez la quita: el gasto queda en *Por clasificar* (regla 17).
64. **Importar datos con selector de archivos:** *Elegir archivo…* abre el selector del sistema (`file_picker`; `.xlsx` o `.csv`) y no se escribe una ruta; al elegir se muestra la vista previa. En Android el sistema entrega nombre y bytes, no una ruta que se pueda abrir. Un archivo de más de 10 MB o de otro tipo se rechaza con su explicación. El archivo semilla (`data/DATOS_SEMILLA_PRESUPUESTO.xlsx`, sin autor en sus propiedades) sigue importando igual. **El archivo elegido es NO confiable** (viene de un correo o una descarga): ver la regla 69.
65. **Orden "registrar gasto":** para abrir la hoja por voz o escrito hay que decir el verbo (*"registrar gasto"*); la palabra "gasto" suelta no abre nada (lo resuelve el asistente de GRAVITY, no esta app).
66. **Montos ocultos:** los montos se abren ocultos y vuelven a ocultarse solos tras unos minutos sin uso; la marca *Montos ocultos · Toca para ver* aparece junto a los montos (encabezado de la laptop, Semana y Movimientos del teléfono) y *Mostrar* pide el PIN o la huella. Las cifras de dinero de las tarjetas de indicador se ocultan solas; los porcentajes quedan visibles.
67. **Revisión de calidad de la Fase 1 (letra grande, errores y datos del equipo):** con letra al **200 %** en 360 dp (teléfono) y 900 dp (laptop) nada se desborda; en la hoja (+) **Guardar** queda siempre a la vista y sin desplazarse (barra fija abajo, teclado compacto de 48 dp; 360 × 800 y 411 × 850) y, con letra grande, apila *Guardar* sobre *Cancelar*. **Sin reintentos automáticos:** una carga que falla muestra el error al instante con *Reintentar* (sin "Cargando" durante unos 40 s). Un monto con coma decimal se lee como pesos (*"12,5"* = $12.50; *".5"* = $0.50; lo ambiguo, como *"1,2345"*, se rechaza). La copia local de Finanzas (`finanzas.copia.<persona>`) se borra al salir, en una baja y al quitar a la persona de la tablet. `miembros.hasta` es **exclusivo** (el día del cambio de albacea escribe el suplente) y las vigencias de ingreso son **inclusivas**. Dos pagos de un mismo ingreso que caen el mismo día (30 y último en febrero) se marcan juntos y la ocurrencia vale los dos.

68. **Adultos con Finanzas del hogar (23/oct, 2.ª ronda):** cualquier adulto con Finanzas (no solo el dueño) puede ver quiénes son los demás —**solo nombres**, nunca la cuenta maestra— para invitarlos a un compartido que administra o elegirlos como suplente de papá. La app llama a `fin_adultos_con_finanzas(p_hogar_id)` en cada carga (devuelve `persona_id`, `nombre_visible` y `rol`, ordenada por nombre) y la guarda en la copia para trabajar sin señal; si la función no responde, usa las membresías que la sesión alcanza a leer.
69. **Importar: el archivo es entrada hostil (Fase 1b, hallazgos X1 a X5).** Un `.xlsx` es un ZIP: el lector (`lector_xlsx.dart`) nunca confía en lo que el archivo dice de sí mismo y rechaza con un `ErrorArchivo` corto (sin trazas, sin rutas, sin detalles del sistema) todo lo que pase de estos **topes**, pensados para una hoja de categorías (el archivo semilla real usa menos de 2 % de cada uno): **archivo** 10 MB, revisado por su tamaño **antes** de leerlo y, si el tamaño no se sabe, leyéndolo por pedazos y cortando al pasar el tope; **descomprimido** 4 MiB por componente y 6 MiB en total, descomprimiendo por pedazos y cortando al pasar el tope (una "bomba" de unos KB no llega a reservar memoria); **razón de compresión** 100 a 1 en componentes de más de 256 KB; **componentes del ZIP** 1000 y **hojas** 256; **filas** 100,000, **columnas** 200 y **caracteres por celda** 1,000 (también en CSV, cuyas líneas se cuentan antes de armar la tabla). Se leen solo el libro, sus relaciones, las cadenas compartidas y la hoja pedida. **Nada se ejecuta ni se sigue:** las fórmulas no se evalúan (se lee el valor guardado), no se abren relaciones ni libros externos (`TargetMode="External"`), no hay DTD ni entidades definidas por el archivo, y ninguna entrada del ZIP toca el disco (`../` o una ruta absoluta solo son llaves en memoria). **Tiempo lineal:** el XML se recorre en una pasada; una etiqueta sin cerrar se rechaza de inmediato, no una vez por cada apertura. **Errores claros** ante ZIP dañado o truncado, tamaños que mienten, datos que no son "deflate", componentes con contraseña, cadenas compartidas fuera de rango y referencias de carácter imposibles. Solo se aceptan `.xlsx` y `.csv`.
70. **El motivo necesita 3 caracteres visibles (N2):** en el libro de papá, en las **anulaciones**, en los **ajustes** y en las **conciliaciones con diferencia**, el motivo vale solo con **al menos 3 caracteres visibles** una vez quitados los espacios, tabuladores, saltos de línea, espacios Unicode (no separable, ideográfico, de ancho cero…) e invisibles (guion blando, marcas de dirección, relleno hangul, braille en blanco, orden de bytes…). Es el mismo criterio de `fin_motivo_valido` en el servidor; si no, el servidor rechaza con 23514 y, con un movimiento en la cola sin conexión, quedaría en "requiere atención". Por eso la app lo valida **antes**: `motivoValido` en el dominio (el libro rechaza el movimiento, que no llega a la cola), el servicio con el mensaje *"El motivo necesita al menos 3 caracteres visibles (los espacios no cuentan)"*, y los formularios (hoja (+), movimiento, conciliación, anulación) con la ayuda *"Al menos 3 letras o números"* y el botón apagado mientras no alcance. Lo ya guardado nunca se rechaza al cargarlo.
71. **Nombrar albacea o suplente (N4):** si el cargo de albacea o de suplente del libro de papá queda **vacío** —o lo ocupa alguien que ya no es adulto con Finanzas del hogar—, el **dueño** lo nombra en *Ajustes › Libros y albaceas* (botones *Nombrar albacea* y *Nombrar suplente* en ese libro, solo para él) eligiendo entre los adultos con Finanzas que todavía no lo llevan. La app llama a `fin_nombrar_albacea(p_libro_id, p_persona_id, p_papel)`, **la única puerta**: un INSERT directo en `fin_libro_miembros` ya no pasa (42501), así que el suplente que se elige al **crear** el libro también entra por la función. Avisa antes lo que el servidor rechazaría con 22023: el cargo ya lo ocupa alguien, la persona ya lleva el libro con otro cargo, no es adulto con Finanzas o es la persona representada. El servidor deja la entrada `finanzas.albacea_nombrado`. El dueño solo ve el libro de papá si es su miembro.
72. **Refresco tras una baja o un cambio de rol (N5) y bitácora (N1):** si el administrador de un compartido deja de ser adulto con Finanzas, el servidor pasa `creado_por` al miembro más antiguo y, con menos de 2 vigentes, deja el libro privado. La app lo ve al **volver a pedir** lo del servidor: `refrescarFinanzas(contenedor)` (que la plataforma llama tras dar de baja a alguien o cambiar su rol) y, además, *Ajustes de Finanzas* recarga cada vez que se abre. Las salidas del libro de papá hacia cualquier otro libro dejan un aviso para el suplente (lo hace el servidor; sin cambio en la interfaz). **La app nunca escribe directo en la bitácora** (tope de 500 entradas por persona al día y 4 KB por entrada; 54000): las entradas las deja el servidor con triggers y funciones, y una prueba revisa que ningún archivo del módulo nombre la tabla.

---

## 6. Pantallas

Siguen `DISENO_UX_UI.md` (sección 8 dentro de un módulo en la laptop; sección 9 y flujo F1 en el teléfono), con el tema base en esta fase (el pulido es la Fase 4). Personalidad de Finanzas: "precisa y serena", números de ancho fijo. Todas tienen estados **vacío, cargando, sin conexión y error**, y montos ocultables. Usan los gadgets de diseno (`package:gravity/diseno/diseno.dart`): Cascada, Medidor de presupuesto, Teclado de monto, Selector de libro con su marca, Tabla densa, Tarjeta de indicador y el aviso *"Guardado · Deshacer"*.

**Libro activo (D19).** Toda pantalla de Finanzas trabaja sobre **un libro**, que se elige en el selector (chips o menú): *Mi libro*, los compartidos, el de papá (con la marca **Albacea**) y, para la cuenta maestra, los ajenos con la marca **Solo lectura**. Los compartidos llevan además la marca **Privada** (candado con persona) o **Pública** (globo) —siempre con texto— y **Archivado** (solo lectura para todos; solo si el administrador lo archivó: salirse alguien ya no lo archiva); quien lee un compartido público sin ser miembro lo ve como **Solo lectura · libro público**. Debajo del título va la marca del libro: *"En nombre de Papá · cada movimiento pide motivo y queda en la bitácora"*, *"Solo lectura · cuenta maestra: puedes ver, no registrar"* o *"Solo lectura · libro público: puedes ver, no registrar"*. Cambiar de libro cambia la semana, las cuentas y el presupuesto.

**Portada de la cuenta maestra (regla 56).** Al entrar, la cuenta maestra no abre ningún libro: ve la lista de los libros del hogar y quién los lleva (con su visibilidad y si están archivados). **Abrir uno registra la consulta** y recién entonces se leen sus datos; el botón *Todos los libros* vuelve a la portada. Los montos y movimientos de un libro nunca se muestran antes de registrar la consulta.

### 6.1 Laptop

La laptop es la versión completa (D4): barra lateral de 300 px con el selector de libro y las secciones (en una ventana angosta pasa a menú). Las secciones de configuración solo aparecen a quien administra el libro.

| Pantalla | Contenido | Acción principal |
|---|---|---|
| **Tablero** (inicio, `/finanzas`) | Cascada planeado contra real (gadget Cascada), medidor por partida, lo que vence esta semana (día hábil ajustado), alerta de flujo, cuatro indicadores del MVP 1, siguiente mejor acción | Registrar movimiento (Ctrl + N), si puede escribir |
| **Semana** | Selector de semana y de periodo (semana, catorcena, quincena, mes); cascada; partidas con asignado, arrastre, gastado, restante y semáforo; abonos; flujo de 4 a 8 semanas; **revisión semanal** (F5): conciliar efectivo → desvíos (las 3 partidas que más se movieron) → propuesta de la semana siguiente → aplicar remanente → cerrar | Cerrar semana |
| **Movimientos** | Tabla paginada (30 a 50 filas) con filtros por fecha, cuenta, categoría, tipo y estado; detalle en panel lateral con su contraasiento y su bitácora; una aportación entre libros se ve en los dos (*"Aportación de Ana"*) | Anular (pide motivo) |
| **Cuentas** | Agrupadas en Activos y Pasivos con saldo; detalle con movimientos; **Balance** con el **cuadre del libro** (inicial + resultado + ajustes + aportaciones recibidas − entregadas) y **Estado de resultados** con selector de periodo; conciliar; cerrar o archivar (los activos y pasivos, con saldo cero; las de gasto e ingreso, sin pedirlo) | Nueva cuenta |
| **Ingresos** | Por persona con su equivalente semanal; ficha con vigencias; calendario de ingresos (semanal, catorcenal, quincenal, mensual con 1 o 2 días fijos y cada N meses); extras. En el libro de papá, los botones **Pensión** (días 1 y 11) y **Apoyo 60+** (bimestral, probable) abren el ingreso con su forma ya llena y **sin monto ni fecha** | Nuevo ingreso |
| **Gastos y categorías** | Árbol de 3 niveles con prioridad, protección y cuenta de gasto; gasto por categoría en el periodo | Nueva categoría |
| **Compromisos y deudas** | Fijos y reservas con frecuencia y próxima fecha (en su fecha por omisión); deudas con abono, mínimo, tasa, saldo, **regla de día inhábil propia** (por omisión *En su fecha*; *Siguiente día hábil* se elige deuda por deuda) y **grupo prioritario** (casilla y orden con subir y bajar); *Orden del abono extra* que explica quién recibe el remanente | Nuevo compromiso |
| **Asistente de arranque** | 5 pasos (libro y cuentas, ingresos, compromisos y deudas, meta, sobres hasta el techo) con resumen como el ejemplo de 5.6 bis y botón *Activar semana*; lo omitido no bloquea; en el libro de papá ofrece sus ingresos; enlaza a *Libros compartidos y de papá* | Activar semana |
| **Importar datos** | *Elegir archivo…* (selector del sistema; `.xlsx` o `.csv`, sin escribir una ruta) → vista previa (creadas, omitidas y por qué) → confirmar → resumen; reimportar no duplica | Importar |
| **Ajustes de Finanzas** | **Presupuesto del libro:** meta, ahorro mínimo con deuda, tope de arrastre, cierre automático y umbrales de semáforo (por libro). **Días inhábiles** del hogar por año (precarga de festivos inactivos que el dueño activa; días propios). **Libros y albaceas:** lista con sus miembros, papeles y marcas (*Privada/Pública*, *Archivado*, *administrador*); nuevo libro compartido (nombre, **Privada** —por omisión— o **Pública**, y miembros; quien lo crea es el administrador); el **administrador** abre *Administrar* (visibilidad, agregar y sacar miembros entre los adultos con Finanzas del hogar, archivar y reactivar; avisa si al sacar a alguien el presupuesto queda privado) y **cualquier miembro menos el último** tiene *Salir del libro* (avisa que el presupuesto queda privado para quien se queda y, si hay saldo, cuánto tiene); libro de papá (nombre, albacea = quien lo crea y suplente opcional; solo el dueño). **Privacidad:** si existe la cuenta maestra y quién es. La cuenta maestra que no es la dueña no ve esta pantalla | Guardar |

### 6.2 Teléfono y tablet

| Rol | Pantalla | Contenido |
|---|---|---|
| Dueño y Pareja | **(+) Gasto** (F1) | Teclado numérico ya abierto → categoría **opcional** (la última que usó la persona preseleccionada y 5 sugeridas; sin ella queda *Por clasificar*) → cuenta **existente** del libro activo (la última usada; si no hay ninguna, *Crear cuenta nueva* ahí mismo) → Guardar → aviso *"Guardado · Deshacer"* (deshacer = anulación con motivo "Deshecho al capturar"). Si hay varios libros donde escribe, se elige el libro (chips). En el libro de papá pide el **motivo** y el gasto va en su nombre. Sin señal: *"Guardado en el teléfono; se sube al volver la señal"*. Meta: **menos de 10 s** |
| Dueño y Pareja | **(+) Ingreso extra** | Monto → cuenta existente (o *Crear cuenta nueva*) → fecha (hoy) → Guardar (mismo aviso) |
| Dueño y Pareja | **Finanzas › Semana** | Libro activo, cascada resumida con semáforo, alerta de flujo, partidas con medidor, movimientos recientes |
| Dueño y Pareja | **Finanzas › Movimientos** | Lista corta del libro; anular con motivo si puede escribir |
| Cuenta maestra | Portada de libros y, al abrir uno, lo mismo que arriba, **sin (+) ni Anular** | Solo lectura total; la consulta queda en la bitácora y habilita la lectura 30 minutos |

Las secciones de la laptop (Cuentas, Ingresos, Gastos y categorías, Compromisos y deudas, asistente, importar y ajustes) **no existen en el teléfono**: abrirlas regresa al inicio del módulo (D4). Familiar, cuidador y Casa no ven Finanzas.

### 6.3 Quién ve y hace qué en la interfaz

| Quién | Ve | Escribe | Configura |
|---|---|---|---|
| Titular de su libro personal | Su libro, los compartidos de los que es miembro y, si es albacea, el de papá | Sí, en esos libros | Su libro y los compartidos; el hogar (categorías, días inhábiles, importar) |
| Albacea | Libro de papá | Sí, **en su nombre y con motivo** | Sí |
| Suplente | Libro de papá | **Solo sin albacea vigente** | Solo sin albacea vigente |
| Pareja | Su libro y los compartidos de los que es miembro, más los **públicos** (solo lectura); **no** el personal del dueño | Sí, en lo suyo y en los compartidos de los que es miembro | Su libro; el hogar (categorías, días inhábiles, importar) |
| Administrador de un compartido (quien lo creó) | Su compartido | Sí | Visibilidad, miembros, archivar y reactivar |
| Cuenta maestra (otra persona) | Todos los libros, con consulta registrada | **Nada, tampoco lo suyo** | Nada |
| Dueño que es también la maestra | Todos los libros (los ajenos con consulta) | Sí, en lo suyo | Lo suyo y el hogar |
| Familiar, cuidador, Casa | Nada de Finanzas | No | No |


---

## 7. Criterios de aceptación

Las pruebas del dominio están en `paquetes/finanzas_dominio/test/` (`dart test`, 236 en verde hoy) y las de la app en `app/test/modulos/finanzas/` (`flutter test`, 197 en verde hoy: `casos_de_uso_test.dart`, `contrato_servidor_test.dart`, `pantallas_test.dart`, `libros_compartidos_test.dart`, `hojas_y_libros_test.dart` y `revision_fase1_test.dart`).

| # | Criterio (prueba del diseño) | Cómo se comprueba |
|---|---|---|
| 1 | **5.6 bis-1:** ingreso $7,384.62; presupuesto $5,472.31; deuda $392.31; remanente $1,520.00 (20.58 %); meta $1,476.92; techo $5,515.39 | `presupuesto_test.dart` ✔ |
| 2 | **5.6 bis-2:** sobregasto $300 → remanente $1,220.00; $1,800 → remanente $0, abono $112.31, diferido $280.00; $2,000 → abono $0, déficit $87.69 | `presupuesto_test.dart` ✔ |
| 3 | **5.6 bis-3:** el sueldo del sábado 31/oct pasa al lunes 2/nov; la semana del 26/oct entra $0 y sale $8,000, con alerta de flujo | `flujo_test.dart` ✔ + prueba de la pantalla Semana |
| 4 | **5.6 bis-4:** periodo quincenal = semanal × 52 ÷ 24 ($11,856.67); gasto real por las fechas de la quincena | `presupuesto_test.dart`, `semana_test.dart` ✔ |
| 5 | **5.6 bis-5:** un ingreso `incierta` no cambia el cálculo y aparece como potencial | `presupuesto_test.dart` ✔ |
| 6 | **5.6 bis-6:** abono a tarjeta bajo el mínimo → alerta roja | `presupuesto_test.dart` ✔ + prueba de widget |
| 7 | **5.6 bis-7:** los protegidos no aparecen en las propuestas de recorte | `presupuesto_test.dart` ✔ |
| 8 | **5.6 bis-8:** al cerrar, abono extra a la tarjeta (mayor costo) y familiares al final; el préstamo familiar no crece al diferir | `presupuesto_test.dart`, `proyeccion_deuda_test.dart` ✔ + bitácora (prueba SQL) |
| 9 | **5.6 bis-9:** corregir un gasto de una semana cerrada genera anulación y contraasiento y recalcula la semana | `libro_test.dart` ✔ + prueba SQL de solo agregar |
| 10 | **5.6 bis-10:** tarjeta liquidada en la semana 4, préstamo familiar en la 5 y ahorro de $1,520.00 desde la 6 (tolerancia de centavos) | `proyeccion_deuda_test.dart` ✔ |
| 11 | **5.6 bis-11:** el cálculo funciona sin internet y la pantalla principal abre en menos de 2 s con un año de datos de prueba | Prueba de rendimiento en modo de lanzamiento en el Galaxy A52 y en la laptop |
| 12 | **5.0 bis 2-1:** activos $22,980; pasivos $2,300; patrimonio $20,680; resultado $7,880; cuadre en cero | `libro_test.dart` ✔ |
| 13 | **5.0 bis 2-2 a 2-4 y 2-7:** tarjeta sube el pasivo sin bajar el efectivo; aportación a ahorro no cambia el patrimonio; un pendiente no altera el saldo confirmado (la prueba 2-4, préstamo entre miembros, es de la Fase 8) | `libro_test.dart` ✔ |
| 14 | **5.0 bis 2-5:** una conciliación con diferencia crea un ajuste con motivo, en bitácora y visible | `libro_test.dart` ✔ + prueba SQL |
| 15 | **5.0 bis 2-6:** no se borra una cuenta con movimientos; una de activos o pasivos sí se cierra con saldo cero y no sin él; una de gasto o ingreso se archiva con saldo, ya no admite movimientos y lo anterior se puede anular (regla 15) | `libro_test.dart` ✔, `respuestas_dueno_test.dart` ✔, `libros_compartidos_test.dart` ✔ + prueba SQL (FK `restrict` y trigger) |
| 16 | **5.0 bis 2-8:** el balance de un cierre guardado no cambia con correcciones posteriores | `libro_test.dart` ✔ + `fin_cierres` solo agregar |
| 17 | **IN1:** quincenal $6,000, catorcenal $5,000 y mensual $2,000 → $2,769.23, $2,500.00 y $461.54 por semana | `frecuencia_test.dart` ✔ |
| 18 | **IN2:** la quincena del 31/oct/2026 se paga el lunes 2/nov | `calendario_test.dart` ✔ |
| 19 | **IN8:** un reembolso médico baja el gasto de Salud y no sube el ingreso | `libro_test.dart` ✔ |
| 20 | **IN9:** un mes con tres catorcenas no se trata como extra | `calendario_test.dart` ✔ + texto en la pantalla Ingresos |
| 21 | **IN10:** calendario del ejemplo: peor caso de −$1,350 el lunes 2/nov y aviso anticipado | `flujo_test.dart` ✔ |
| 22 | **T1 y T2 (5.9 bis):** remanente 20.58 % y carga 5.31 % en verde; con $300 de más en Alimentación, 16.52 % en ámbar con la categoría y el monto | `presupuesto_test.dart` ✔ + prueba de widget |
| 23 | **T8:** un mes con 5 lunes se muestra por semanas con promedio semanal | Prueba de widget del tablero |
| 24 | **T9:** una semana sin cerrar 3 días se cierra con pendientes marcados y se puede reabrir | Prueba del caso de uso + prueba SQL |
| 25 | **Libro solo-agregar:** nadie (ni el dueño) puede editar ni borrar un movimiento, una conciliación o un cierre | Pruebas SQL |
| 26 | **Roles (D19, corregido en la v0.3 y la v0.4):** dueño y coadministrador escriben en **su** libro y en los compartidos de los que son miembros y no ven lo personal del otro; los compartidos públicos los leen sin escribir; familiar, cuidador y casa no ven nada de Finanzas, **comprobado en el servidor** | Pruebas SQL de RLS + `libros_test.dart` ✔ + `finanzas_por_rol_test.dart` (plataforma) ✔ |
| 27 | **Sin conexión:** un gasto registrado sin señal se sube al volver; reintentar no lo duplica (mismo UUID) | Pruebas de la cola + prueba SQL de idempotencia |
| 28 | **F1:** registrar un gasto en el teléfono toma menos de 10 s | Prueba de widget (pasos) + medición manual en el A52 |
| 29 | **Importación:** la hoja Categorías crea el árbol de 3 niveles con su naturaleza y su cuenta de gasto; reimportar no duplica | Prueba del importador con el archivo semilla |
| 30 | **D3:** ninguna herramienta de Finanzas envía montos a la IA (todas `soloLocal`) | Prueba del registro de herramientas |
| 31 | **Libros (regla 44 a 46):** la pareja no ve ni registra en el libro personal del dueño; ve y registra en el compartido; cada libro ve solo su gasto en la cuenta de gasto del hogar | `libros_test.dart` ✔, `casos_de_uso_test.dart` ✔ + pruebas SQL de RLS |
| 32 | **Aportación entre libros (regla 47 y 48):** Ana aporta $2,000 a la casa y paga $500 de la tarjeta compartida; el patrimonio de cada libro cambia sin pasar por su resultado (`inicial + resultado + recibidas − entregadas`) y los dos cuadran; anular la aportación la descuenta de su mismo lado | `cuadre_entre_libros_test.dart` ✔, `casos_de_uso_test.dart` ✔ |
| 33 | **Solo cruzan transferencia y pago de deuda (regla 47):** un ingreso, una apertura o un ajuste entre libros se rechaza; el gasto a una cuenta de gasto del hogar no es un cruce | `cuadre_entre_libros_test.dart` ✔ + prueba SQL del trigger |
| 34 | **Albacea (reglas 49 a 51):** el gasto en el libro de papá exige motivo y va en su nombre (`en_nombre_de`, `realizado_por` = papá, `registrado_por` = el albacea); el contraasiento también; el suplente lee y **no escribe** con albacea vigente, y escribe y administra sin él | `libros_test.dart` ✔, `casos_de_uso_test.dart` ✔ |
| 35 | **Cuenta maestra (reglas 55 y 56, reescrito en la v0.4):** entra por la portada sin dejar consulta; abrir un libro ajeno llama a `fin_registrar_consulta_maestra` (una vez por libro abierto); no escribe ni ve botones de escribir, tampoco en lo suyo; el dueño que es también la maestra escribe en lo suyo; *Privacidad* dice quién es | `pantallas_test.dart` ✔, `libros_compartidos_test.dart` ✔, `contrato_servidor_test.dart` ✔ + pruebas SQL |
| 36 | **Grupo de deudas prioritarias (regla 54):** el remanente después del ahorro mínimo y el abono liberado van a la siguiente deuda del grupo; con el grupo pagado, a ahorro; las deudas fuera del grupo no reciben extra | `grupo_prioritario_test.dart` ✔ + casilla y orden en *Compromisos y deudas* |
| 37 | **Ingresos de papá (regla 52):** la pensión de los días 1 y 11 pasa al siguiente día hábil (1/nov/2026, domingo, se paga el lunes 2; 11/oct, domingo, el lunes 12); el apoyo 60+ es bimestral y probable; $3,200 por pago dan $1,476.92 por semana; la plantilla no trae monto ni fecha y el apoyo exige la fecha de un pago conocido | `calendario_d19_test.dart` ✔, `pantallas_test.dart` ✔ |
| 38 | **Día inhábil por origen (regla 53):** sin regla elegida, un ingreso pasa al siguiente día hábil y una renta o una deuda se quedan en su fecha; la regla elegida **por deuda** manda; se guarda siempre la regla efectiva | `calendario_d19_test.dart` ✔, `contrato_servidor_test.dart` ✔, `hojas_y_libros_test.dart` ✔ |
| 39 | **Ids estables (regla 58):** la anulación de un movimiento tiene el mismo id en cualquier dispositivo y es única (anular o deshacer dos veces avisa y no duplica); importar la hoja Categorías en dos dispositivos da los mismos ids; reimportar no duplica; la semana, sus partidas y el cierre salen del libro y el lunes | `casos_de_uso_test.dart` ✔, `pantallas_test.dart` ✔ |
| 40 | **Cierre en el servidor (regla 59):** el cierre (versión `reaperturas + 1`, renglones con id) se guarda antes de cerrar la semana; reabrir suma una reapertura y el cierre siguiente es la versión 2 con otro id; reintentar el cierre no duplica sus renglones; aplicar el remanente dos veces no duplica | `seguimiento_test.dart` ✔, `casos_de_uso_test.dart` ✔, `contrato_servidor_test.dart` ✔ |
| 41 | **Contrato de columnas (convención 10):** un movimiento sube con `registrado_en` y sin `recibido_en`, `libro_origen_id` ni `libro_destino_id`; solo las cuentas de gasto van sin libro; `desde` y `hasta` de los miembros son `timestamptz`; los parámetros se cambian con `UPDATE` sin las cuentas de sistema; los renglones del cierre llevan `id` y `libro_id` y no `diferido` | `contrato_servidor_test.dart` ✔ |
| 42 | **Libro de papá y compartidos (reglas 45 y 49):** crearlos dos veces no los duplica; quien crea el de papá queda como albacea y el suplente entra por miembros; la RPC recibe `p_hogar_id`, `p_nombre_titular`, `p_nombre_libro` y `p_libro_id`; el compartido manda su `visibilidad` | `casos_de_uso_test.dart` ✔, `contrato_servidor_test.dart` ✔, `pantallas_test.dart` ✔ |
| 43 | **Ajustes (6.1):** la meta de remanente se guarda por libro y un valor fuera de 0 a 100 no; la precarga de festivos nace inactiva y activar uno deja quién y cuándo; un libro compartido nuevo queda elegido | `pantallas_test.dart` ✔ |
| 44 | **Rutas y dispositivos (regla 57):** el asistente, importar y ajustes exigen *administrar*; en el teléfono las secciones de la laptop regresan al inicio del módulo; la pareja abre el asistente de su libro; la cuenta maestra que no es la dueña no abre ninguno | `pantallas_test.dart` ✔ |
| 45 | **Solo lectura total (reglas 55 y 61):** la cuenta maestra que no es la dueña no crea libros, categorías, días inhábiles ni cuentas, no cambia el estado de una cuenta ni registra en un libro propio; no ve el (+); el dueño-maestro sí escribe en lo suyo | `libros_compartidos_test.dart` ✔, `pantallas_test.dart` ✔ |
| 46 | **Consulta registrada (regla 56):** la consulta se registra **antes** de pedir los datos del libro ajeno; sin ella el servidor devuelve vacío; un resultado vacío de un libro ya consultado renueva la consulta y recarga; se renueva a los 25 minutos sin tapar la pantalla; al salir de Finanzas se detiene; si no se puede registrar, el libro no se muestra y hay *Reintentar* (sin ciclos); abrir lo propio devuelve falso | `revision_fase1_test.dart` ✔ |
| 47 | **Libro de papá, todo con motivo (regla 50):** gasto, ingreso extra, remanente, saldo inicial, conciliación, aportación desde un libro personal y anulación exigen motivo de 3 caracteres visibles y van en su nombre; la hoja (+) lo pide siempre | `revision_fase1_test.dart` ✔, `casos_de_uso_test.dart` ✔ |
| 48 | **Compartidos (regla 60):** se crean privados (o públicos si se elige); quien los crea es el administrador; solo él cambia la visibilidad, agrega y saca miembros (nunca menos de 2), archiva y reactiva; cualquier miembro se sale, menos el último; si quedan menos de 2 el presupuesto pasa a privado y sigue activo (no se archiva) con el que queda como administrador, y sacar a otro con 2 miembros hace lo mismo; el administrador que se sale pasa el cargo; un archivado (solo por decisión del administrador) nadie lo escribe; el adulto que lo lee sin ser miembro es lector; el selector marca *Privada/Pública*, *Archivado* y *Solo lectura* | `respuestas_dueno_test.dart` (dominio) ✔, `libros_compartidos_test.dart` ✔, `hojas_y_libros_test.dart` ✔, `contrato_servidor_test.dart` ✔ |
| 49 | **Suplente según el servidor (regla 51):** con el albacea activo el suplente solo lee; si el albacea ya no es adulto con Finanzas, escribe y administra; la app lo pregunta a `fin_puede` solo para el suplente | `libros_compartidos_test.dart` ✔, `contrato_servidor_test.dart` ✔ |
| 50 | **Hoja (+) (reglas 62 y 63):** el gasto sale de las cuentas del libro activo y no de otros; sin cuentas ofrece *Crear cuenta nueva* (nombre, tipo y saldo inicial opcional, con su apertura) y sigue con el gasto; un nombre repetido se explica; la categoría es opcional y sin ella queda en *Por clasificar*; el ingreso extra funciona igual | `hojas_y_libros_test.dart` ✔ |
| 51 | **Importar con selector (regla 64):** el selector entrega el archivo semilla real y se llega a la vista previa, la confirmación y el resumen sin escribir una ruta; cancelar no hace nada; un archivo de otro tipo se explica; reimportar no duplica | `pantallas_test.dart` ✔ |
| 61 | **Archivo no confiable (regla 69):** un `.xlsx` de unos KB que se expande a decenas de MB, un componente que comprime más de 100 a 1, demasiados componentes, un número de fila o de columna enorme, una celda de más de 1,000 caracteres, un CSV de millones de renglones, celdas o filas sin cerrar (tiempo lineal), un archivo de 3 GB (se rechaza por su tamaño sin leerlo), un tamaño comprimido que miente, datos que no son "deflate", un ZIP truncado o aleatorio, un componente con contraseña y una referencia de carácter imposible se rechazan con un `ErrorArchivo` corto y sin trazas; las fórmulas no se evalúan, una relación externa no se sigue y las entidades no se expanden; el archivo semilla real sigue importando | `f1b_importar_no_confiable_test.dart` ✔ (X1 a X5), `importador_no_confiable_test.dart` ✔ |
| 62 | **Motivo de 3 caracteres visibles (reglas 50 y 70):** vacío, espacios, 1 o 2 letras, invisibles de Unicode y mezclas como *" a b "* se rechazan en el gasto, el ingreso extra y la aportación del libro de papá, en la anulación y en la conciliación con diferencia (sin diferencia no pide nada); *"Pan"* pasa aunque lleve espacios; el movimiento con motivo corto no entra a la cola sin conexión; la hoja (+) y el diálogo de anular dejan el botón apagado hasta alcanzar los 3; un libro restaurado no rechaza motivos viejos | `motivo_test.dart` (dominio) ✔, `endurecimiento_1b_test.dart` ✔, `contrato_servidor_test.dart` ✔ |
| 63 | **Nombrar albacea o suplente (regla 71):** el dueño nombra al suplente de un libro nuevo y el cargo ocupado no se vuelve a nombrar; la pareja y la maestra no; se avisa si la persona es la representada, ya lleva el libro, no es adulto o el libro no es de papá; si el albacea o el suplente ya no es adulto con Finanzas el cargo se considera vacío y el viejo se cierra; Ajustes ofrece los botones solo al dueño; el suplente de un libro nuevo entra por `fin_nombrar_albacea` y no por INSERT, con `p_papel` en snake_case | `endurecimiento_1b_test.dart` ✔, `contrato_servidor_test.dart` ✔ |
| 64 | **Refresco y bitácora (regla 72):** `refrescarFinanzas` vuelve a pedir lo del servidor y ve el cambio de administrador y de visibilidad de un compartido; sin Finanzas abierto no hace nada y sin señal no lanza; abrir Ajustes recarga y muestra al nuevo administrador; ningún archivo del módulo escribe en la bitácora ni la cola la nombra | `endurecimiento_1b_test.dart` ✔ |
| 52 | **Dos pagos el mismo día y vigencias (regla 67):** la ocurrencia de un ingreso con dos pagos el 28/feb vale los dos; `miembros.hasta` es exclusivo y las vigencias de ingreso, inclusivas | `revision_fase1_test.dart` ✔, `libros_test.dart` y `calendario_d19_test.dart` (dominio) ✔ |
| 53 | **Coma decimal (regla 67):** *"12,5"* = $12.50, *".5"* = $0.50, *"1,234"* = $1,234.00 y lo ambiguo (*"1,2345"*, *"85.555"*) se rechaza | `revision_fase1_test.dart` ✔ |
| 54 | **Letra grande (regla 67):** con letra al 200 % en 360 dp, *Guardar* de las hojas (+) se ve, cabe y queda arriba de *Cancelar*; con letra normal van en una fila; con el teclado del sistema abierto la barra queda encima; la fila de un movimiento no se desborda y *Anular* sigue disponible | `revision_fase1_test.dart` ✔ + pruebas de calidad `f1_i6`, `f1_i7` y `f1_i8` |
| 55 | **Sin reintentos automáticos (regla 67):** una carga que falla queda en error al instante y se reintenta a mano | `revision_fase1_test.dart` ✔ |
| 56 | **Copia local (regla 67):** `finanzas.copia.<persona>` se borra al salir, al quitar a la persona de la tablet y aunque el almacén falle; la de otra persona no | `revision_fase1_test.dart` ✔ + `f1_m5` (calidad) |
| 57 | **Montos ocultos (regla 66):** la marca *Montos ocultos · Toca para ver* aparece mientras lo estén y *Mostrar* pide el PIN o la huella | pruebas de diseno y de plataforma ✔ |
| 58 | **Deuda con su regla de día inhábil (regla 53):** el formulario trae *En su fecha*; con *Siguiente día hábil* el pago de un día inhábil pasa al siguiente hábil y con *En su fecha* no se mueve | `hojas_y_libros_test.dart` ✔ |
| 59 | **Salir y adultos del hogar (reglas 60 y 68, 2.ª ronda):** al salirse con 2 miembros el libro queda privado y activo, quien se queda es el administrador y el que salió pierde el acceso (en un público lo lee como lector); el último miembro no puede salirse y puede archivar; el aviso dice *"queda privado para quien se queda"* y, con saldo, *"El presupuesto tiene $X; lo que aportaste se queda aquí"*; sacar a otro con 2 miembros avisa y deja el libro privado; quien administra elige a quién agregar entre los adultos con Finanzas del hogar aunque no sea el dueño | `respuestas_dueno_test.dart` (dominio) ✔, `libros_compartidos_test.dart` ✔, `hojas_y_libros_test.dart` ✔ |
| 60 | **Lista de adultos (regla 68):** `fin_adultos_con_finanzas` se llama con `p_hogar_id`, alimenta `adultosConFinanzas` y los nombres, se guarda en la copia sin señal y, si no responde, se usan las membresías | `contrato_servidor_test.dart` ✔ |

---

## 8. Trabajo por agente

| Agente | Entrega | Carpetas |
|---|---|---|
| **finanzas** | Ya entregado: `finanzas_dominio` con pruebas (incluye el cuadre por libro) y, en la app, casos de uso, repositorios (memoria y Supabase), pantallas de laptop y teléfono, asistente de arranque, importador, ajustes de Finanzas y las conexiones de `pantallas_externas.dart`. Alcance de la Fase 1: casos de uso (registrar gasto, anular, armar y cerrar semana, conciliar, importar categorías), repositorios contra la base local y Supabase, pantallas de laptop y teléfono de la sección 6, asistente de arranque e importador | `paquetes/finanzas_dominio`, `app/lib/modulos/finanzas` |
| **backend** | Migración con las tablas de 4.1, borrado de `finanzas_muestra`, triggers (solo agregar, validación de 4.3, saldo cero para cerrar, semana cerrada), RLS de 4.2, vistas `fin_v_*`, cuentas de sistema al crear el hogar, datos de ejemplo en `seed.sql` (el hogar ficticio de Ana y Alex) y pruebas SQL de los criterios 9, 14, 15, 16, 24 a 27 | `supabase/` |
| **diseno** | Gadgets **Cascada** y **Medidor de presupuesto**; componentes **Monto** (ancho fijo, modo oculto), **Semáforo** con texto o icono, **Registro rápido (+)** con teclado numérico y deshacer; personalidad de Finanzas; maquetas de Tablero, Semana y (+) Gasto | `app/lib/diseno`, `app/assets` |
| **plataforma** (apoyo) | Rutas de Finanzas por rol; la cola sin conexión acepta movimientos de Finanzas (idempotente por UUID) | `app/lib/app`, `app/lib/nucleo` |
| **asistente** (apoyo) | Herramientas de navegación a Finanzas (*"abre presupuesto"*), marcadas `soloLocal`; operaciones de Finanzas en `api/openapi.yaml` | `app/lib/nucleo/herramientas`, `api/` |
| **calidad** | Revisión de cierre: pruebas, RLS, D3 y accesibilidad | `docs/revisiones/` |

---

## 9. Preguntas para el dueño

Cada pregunta trae la **propuesta por defecto** con la que se construye si no hay respuesta. Ninguna bloquea programar.

### 9.0 Respuestas del dueño (21/oct/2026)

| # | Respuesta | Qué cambia |
|---|---|---|
| — | Finanzas propias por usuario, cuentas compartidas para pagos y uno o dos albaceas; cada quien ve lo suyo y una cuenta maestra ve todo | **D19** y sección 4.5; entran al MVP 1 |
| **P1** | La pareja ve **su** presupuesto y las cuentas compartidas | Su propio libro; no ve el libro personal del dueño |
| **P2** | (Se sigue de P1) La pareja registra en su libro y en los compartidos | Alcance `propio` en Finanzas para el coadministrador |
| **P4** | Uno o dos albaceas | Albacea y suplente en el libro de papá |
| **P5** | Sí: el dinero de papá se lleva en la app (se sigue de P15) | Libro `representado` con sus albaceas |
| **P12** | Se elige un **grupo de deudas prioritarias**; se abona a esas; cuando se pagan, el dinero pasa a **ahorro** | Regla 4 de la sección 4.5. El tope de arrastre se queda en la propuesta (2 × semanal) y los protegidos en renta, servicios y cuidados, hasta que digas otra cosa |
| **P13** | Solo **la caja** pasa al siguiente día hábil; los demás pagos se quedan en su fecha | Regla 5 de la sección 4.5 (confirmado el 23/oct: "la caja" es la Caja Popular Mexicana, el crédito automotriz del dueño) |
| **P15** | Nadie tiene ingreso variable. Papá recibe su **pensión los días 1 y 11** (si cae en fin de semana o festivo, el siguiente día hábil) y **apoyo 60+ cada bimestre** | Base prudente fuera del MVP 1; forma `cada_meses` y varios días fijos al mes (regla 6) |
| **P19** | (Se sigue de P12) La deuda liquidada libera su abono hacia el grupo prioritario y luego a ahorro | Regla 4 de la sección 4.5 |

### 9.0 bis Respuestas del dueño (23/oct/2026)

Detalle y razones en `docs/DECISIONES.md` (D14, D18 y D19).

| Tema | Respuesta | Qué cambia |
|---|---|---|
| Cuenta maestra | Login distinto del suyo; no se prohíbe que el dueño sea maestro; solo lectura total | La maestra no registra nada; la crea el dueño como persona propia |
| Libro compartido | Quien lo crea es el administrador; cualquiera puede salirse; pública o privada a elección del creador; el dueño no entra si no es miembro | Columna `visibilidad` en `fin_libros`; salir con 2 miembros archiva el libro |
| Libro de papá | Toda salida con motivo y en su nombre | Ya implementado |
| Configurar el hogar | Dueño y pareja | Sin cambio |
| Cuentas de gasto | Se archivan al cerrar la cuenta | El saldo cero solo aplica a activos y pasivos |
| P13, "la caja" | Caja Popular Mexicana, crédito automotriz | Única deuda con siguiente día hábil |
| Importar | Con selector de archivos | Dependencia `file_picker` |
| Orden "registrar gasto" | Hay que decir el verbo | "gasto" suelto no abre nada |
| Gastos y cuentas | Cuenta existente; si no hay, "Crear cuenta nueva"; categoría opcional | La hoja (+) lo ofrece |
| Tablets | Cuenta del equipo = Casa con nombre "Hogar"; bandeja de salida sin pedir PIN otra vez | D14 |
| Salir de un compartido (2.ª ronda, 23/oct) | Con menos de 2 miembros el presupuesto **pasa a privado**, no se archiva; el último miembro no puede salirse; si se sale el administrador, el cargo pasa al más antiguo | Regla 4.5 y D19 |
| Adultos con Finanzas | Cualquier adulto con Finanzas ve los nombres de los demás para invitarlos | Función de servidor nueva |
| Chip "Cuenta nueva" | Siempre visible | Como está |
| Hora al salirse | La del teléfono | Sin cambio |
| PIN | 6 dígitos para quien ve dinero; al entrar con PIN en la tablet, los montos se ven de una vez | D18 |
| Bandeja de salida | Se prueba; si no, permiso de subida acotado | D14 |
| Maestra | Solo lectura; más adelante se verá si también edita | Sin cambio |
| Aprobación de la v0.3 | El dueño pidió que se le explique la pregunta (explicada el 23/oct) | Pendiente |
| Cambio de ingreso | El dueño pidió que se le explique | Pendiente |

Las demás preguntas siguen con su propuesta por defecto.

### 9.1 Roles y permisos financieros entre miembros (5.0 ter → D5)

> **Nota de la v0.3:** las filas P1 a P5 de esta sección se escribieron antes de D19 y quedaron **superadas por la sección 9.0** (cada quien lleva su libro, la pareja registra en el suyo y en los compartidos, el libro de papá lo llevan 1 o 2 albaceas). Se dejan por el historial; manda 9.0. P3 y P6 a P9 siguen para la Fase 8 y la Fase 5.

Los roles del diseño de FINANZAS se acomodan así a los de GRAVITY (D5):

| Rol en FINANZAS (5.0 ter) | Rol en GRAVITY (D5) | En el MVP 1 |
|---|---|---|
| Administrador | **Dueño** | Todo |
| Miembro adulto | **Coadministrador** (pareja) | Su libro y los compartidos (D19; P1, P2) |
| Solo lectura | **Cuenta maestra** en lo ajeno (D19) | Lee todo, no escribe en lo ajeno |
| Dependiente | Familiar sin dinero; papá (persona bajo cuidado) sin cuenta | Sin acceso a Finanzas |
| **Albacea** | No es un rol: una marca sobre un adulto (dueño o coadministrador), con suplente | Lleva el libro de papá (D19; P4, P5); las confirmaciones son de la Fase 8 |
| — | Cuidador | Sin acceso; en la Fase 5 registra gastos de cuidado |

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P1** | ¿Qué ve la pareja? D5 dice "presupuesto solo lectura"; la matriz de la Fase 0 y el diseño (transparencia total, 5.0 bis) le dejan leer **todo** Finanzas: movimientos, cuentas y saldos | Lo que ya aprobó la Fase 0: **lee todo Finanzas**. Si prefieres solo el presupuesto, se cambia la regla del servidor a "restringido" (resumen de la semana, partidas y cierres) |
| **P2** | ¿La pareja **registra** gastos? ¿En qué cuentas: solo las suyas, las del hogar o ambas? | En el MVP 1 **no registra**. Si quieres que registre desde ya: solo en sus propias cuentas y en las cuentas de gasto del hogar, como aportación a su nombre |
| **P3** | Si la pareja registra en una cuenta que es tuya (por ejemplo, tu tarjeta), ¿hace falta que **tú confirmes**? | Sí: queda `pendiente` hasta que lo confirmes (5.0 ter); no cambia tu saldo confirmado mientras tanto |
| **P4** | ¿Quién es el **albacea** y quién el **suplente**? | Albacea: tú. Suplente: la pareja. Se activa con el modo Pareja (Fase 8) |
| **P5** | ¿El dinero de **papá** (pensión, cuentas) se administra en la app? Si sí, ¿quién actúa en su nombre? | Por ahora **no**. Si sí, sus cuentas serían del hogar con el albacea como quien registra y confirma en su nombre, con motivo y bitácora |
| **P6** | Los **gastos de cuidado** que registre la cuidadora (Fase 5), ¿entran al presupuesto directo o esperan tu confirmación? ¿De qué cuenta salen (caja chica en efectivo)? | Entran como **pendientes** a una cuenta "Caja de cuidados" y cuentan cuando tú (o el albacea) los confirmas |
| **P7** | ¿La **hermana** comparte gastos de cuidado? ¿Ve el resumen mensual del costo del cuidado? (pendiente de D5) | No ve dinero hasta que lo decidas |
| **P8** | ¿Mantienes las salvaguardas del albacea (decisión 28): motivo obligatorio, aviso, suplente, no ser la única confirmación de lo propio y cambio de albacea confirmado por otro adulto? | Sí, todas activas (se usan desde la Fase 8) |
| **P9** | Confirmaciones pendientes (decisión 30): recordatorio a las 24 horas, aviso al albacea a los 3 días, nunca se confirma sola. ¿Bien? | Sí (Fase 8) |

### 9.2 Decisiones "por defecto" de 12.1 que tocan el MVP 1

| # | Decisión | Propuesta |
|---|---|---|
| **P10** | **23 (pila)** decía Flutter + Firebase; **D7** la cambió a **Supabase** (Firebase solo para avisos y reparto). ¿Confirmas que la 23 queda reemplazada? | Sí, manda D7 |
| **P11** | **24 (rendimiento):** abrir en menos de 2 s y registrar un gasto en menos de 10 s, medido en el Galaxy A52. Y, ligado a 43: ¿la semana queda **fija en lunes** (convención de GRAVITY) o la quieres configurable? | Metas tal cual; semana fija en lunes |
| **P12** | **49 (arrastre):** "el sobrante pasa a la semana siguiente hasta 2 semanas". Lo interpreté como **tope de monto**: lo acumulado en un sobre no pasa de 2 veces su monto semanal y el exceso va al remanente. La otra lectura es de **tiempo**: cada sobrante dura 2 semanas y luego se va. ¿Cuál? ¿Y la lista de **protegidos** es renta, servicios y cuidados de largo plazo, o agregas otros (por ejemplo, colegiaturas o medicinas)? | Tope de monto (2 × semanal); protegidos: renta, servicios y cuidados |
| **P13** | **44 (fin de semana):** para **ingresos** el pago pasa al siguiente día hábil. Para **pagos que salen**, el diseño se contradice (en 5.1 bis la renta del domingo pasa al lunes; en 5.6 bis sale el domingo). ¿Qué hago con las salidas? | Se quedan en su fecha (lo más prudente para la caja); configurable por compromiso |
| **P14** | Al **anular** un movimiento de una semana ya cerrada, ¿el contraasiento corrige **esa** semana (misma fecha) o la **actual**? | Esa semana (misma fecha); la foto del cierre guardado no cambia |
| **P15** | **50 (asistente de 5 pasos):** ¿bien así? ¿Alguien del hogar tiene **ingreso variable** (comisiones, ventas)? Si sí, el método de base prudente (12 semanas × 80 %) entra al MVP 1; si no, se queda para después | 5 pasos; base prudente después |
| **P16** | Umbrales de semáforo (pendiente 23) y **cierre automático a los 3 días** (5.9 bis): ¿los dejas así? | Sí |

### 9.3 Otras interpretaciones conservadoras (confirmar)

| # | Tema | Cómo quedó |
|---|---|---|
| **P17** | **Ahorro mínimo con deuda** (0 %): ¿porcentaje del remanente o del ingreso? | Del **remanente**: nunca quita dinero al presupuesto ni a los abonos |
| **P18** | **Mensualidades MSI** al reducir abonos por sobregasto | Se reducen al último (no pagarlas puede costar la promoción) |
| **P19** | **Deuda liquidada:** su abono planeado no pasa solo a otra deuda ni a ahorro; se libera al rearmar el plan (así da el ejemplo del diseño: $160.09 de ahorro en la semana 5) | Se propone en la revisión semanal; tú confirmas |
| **P20** | **Cierre en vista devengada** para fijos y reservas (regla 33) e **ingreso faltante** completo en la semana en que debía llegar | Así |
| **P21** | **Quincenas** del calendario (1–15 y 16–fin) para ver los datos por quincena, sin importar el día exacto de pago | Así |
| **P22** | **Festivos oficiales:** la precarga es la del artículo 74 de la LFT, sin Jueves y Viernes Santo ni 12 de diciembre (son inhábiles bancarios, no festivos oficiales) y sin jornadas electorales, que agregas a mano. ¿Bien? | Así; la revisas cada año antes de activarla |

### 9.4 Datos para usar la app con tu información (no bloquean)

Tus ingresos reales (pendiente 24 de FINANZAS), tus compromisos fijos con montos y fechas (agua, luz, predial, seguros: pendiente 19), los saldos de apertura de cada cuenta, las tasas y abonos de tus deudas (pendientes 8 y 12) y tus categorías propias. Todo se captura en la app; **nada de eso va al repositorio**.

---

## 10. Observaciones sobre el diseño (para corregir en FINANZAS)

1. **Abonos del ejemplo (5.6 bis punto 5):** $276.92 + $115.38 = $392.30, pero el total dice $392.31 (lo exacto). Con la regla R2 el préstamo familiar queda en **$115.39**.
2. **Presupuesto mensual (5.6 bis punto 5):** el diseño da $23,713.34 (del semanal ya redondeado); con la suma exacta es **$23,713.33**. Igual pasa con la tabla de salida de deuda ($727.02 y $124.49 contra $727.01 y $124.48): diferencias de un centavo, dentro de la tolerancia del diseño.
3. **15/nov/2026:** el diseño dice que la quincena del domingo 15 se paga el lunes 16, pero el **lunes 16/nov/2026 es festivo oficial** (tercer lunes de noviembre); con la decisión 55 se paga el **martes 17**.
4. **Renta del 1/nov:** 5.1 bis (punto 9) la mueve al lunes y 5.6 bis (punto 5) no (pregunta P13).
5. **Decisión 23 y sección 8 bis** hablan de Firebase como base de datos; D7 la reemplazó por Supabase (pregunta P10).
6. La sección 7 lista dos veces el campo `estado` en `Movimiento`; aquí queda uno solo (`estado_inicial`) y el estado vigente sale de las confirmaciones.
7. **Errores de la v0.2 corregidos en la v0.3:** el criterio 26 decía que el coadministrador "lee y no escribe" (D19 lo cambió: escribe en su libro); 4.1 no incluía `libro_id` ni `id` en los renglones del cierre ni las columnas que pone el servidor (`recibido_en`, `libro_origen_id`, `libro_destino_id`, `reaperturas`, `diferido`); y 9.1 seguía con las filas P1 a P5 anteriores a D19.
8. **Resuelto el 23/oct (P13):** "la caja" es la Caja Popular Mexicana, el crédito automotriz del dueño; es la única deuda con *siguiente día hábil* y se configura en la app (nada de eso se guarda en el repositorio).

---

## 11. Lo que necesita el dueño del proyecto

1. **Aprobar** esta especificación (o marcar cambios).
2. Responder las preguntas de la sección 9; mientras tanto se construye con las propuestas por defecto.
3. Para usarla con tus datos: lo de 9.4, cuando quieras.
