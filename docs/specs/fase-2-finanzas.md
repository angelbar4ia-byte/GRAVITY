# Especificación — Fase 2: Finanzas MVP 2

> Versión 0.1 (31/oct/2026), **borrador para aprobación del dueño**. Base: `docs/ROADMAP.md` (secciones 5, 11 y 11.4 "Siguiente ronda"), `docs/DECISIONES.md` (D3, D5, D15, D17, D18 y D19), el diseño de FINANZAS v23 (`docs/modulos/finanzas/ESTRUCTURA_APP_PRESUPUESTO_SEMANAL.md`, secciones 5.3, 5.3 bis, 5.5, 5.5 bis y 5.9 bis), `docs/DISENO_UX_UI.md` (secciones 12 y 17) y la especificación de la Fase 1 (`docs/specs/fase-1-finanzas.md` v0.5), de la que **hereda todo**: libros (D19), libro solo-agregar, ids estables, cuenta maestra, albaceas, montos ocultos, cola sin conexión. Se aplican las convenciones de `docs/specs/fase-0-cimientos.md`, sección 4, y las de la sección 3 de la Fase 1.
>
> Las preguntas para el dueño están en la **sección 9**, cada una con su propuesta por defecto. Lo que el diseño dejó ambiguo se resolvió con la interpretación más conservadora y se marca como **(interpretación)**.
>
> **Qué ya existe y NO se vuelve a hacer:** en `paquetes/finanzas_dominio` están `DeudaPlan`/`Deuda` (tipo `conCosto`/`familiar`/`msi`, abono, mínimo, tasa, prioridad manual, **grupo prioritario**, regla de día inhábil por deuda), `ordenDeAbonoExtra`, el reparto del abono extra, `proyectarSalidaDeDeuda`, los indicadores de carga de deuda y la alerta roja de abono bajo el mínimo; en la base, `fin_deudas`, `fin_ocurrencias`, `dispositivos` (con `token_avisos`) y las entradas de bitácora `finanzas.salida_libro_representado`. La Fase 2 **amplía** esas piezas; no las duplica.

---

## 1. Resultado utilizable

**Saber cuánto debo y a quién pagar primero, cuánto colchón tengo en semanas y enterarme a tiempo de lo que vence, sin que el aviso diga cuánto ni a quién.**

- **Laptop (Dueño, Pareja, albaceas):** das de alta tarjetas, préstamos, créditos y compras a MSI (o importas tu ficha); ves el **orden de pago por costo** explicado, el costo estimado de deber, el uso del límite de cada tarjeta y el calendario de vencimientos; registras un pago separando capital, intereses y cargos; creas **bolsas de ahorro** con sus métodos y el **fondo de emergencia por niveles** ("tienes X semanas cubiertas"); confirmas cada semana el reparto del remanente; configuras **qué te avisan, cuántos días antes y cuándo no molestar**.
- **Teléfono (Dueño, Pareja):** ves los **próximos pagos**, el **avance del ahorro** y la **bandeja de avisos**; recibes los avisos **al instante** (Firebase) y como **recordatorios locales**, también sin señal; desde el aviso registras el pago en pocos toques. La **pulsera** (nivel 1) muestra el mismo aviso como texto corto con vibración.
- **Pantalla "Hoy" de GRAVITY:** por primera vez con **cifras reales** de Finanzas: el resumen de la semana por libro, filtrado por tu rol, calculado en el dispositivo.
- **Suplente de papá:** recibe un aviso discreto cuando el albacea mueve dinero del libro de papá a otro libro.
- **Dueño:** recibe el aviso cuando la base de datos llega al **80 %** de su cupo gratuito.

**Regla de oro de la fase (D3):** un aviso **nunca** lleva montos, saldos, nombres de cuentas, tarjetas, deudas, comercios ni personas: ni en el teléfono, ni en la pantalla bloqueada, ni en la pulsera, ni en lo que viaja por Firebase. El detalle solo existe dentro de la app, después de desbloquear.

---

## 2. Alcance

### 2.1 Entra en el MVP 2

| Submódulo | Qué entra | Diseño |
|---|---|---|
| Deudas a detalle | Clases de deuda (tarjeta, préstamo, crédito, MSI, familiar) con acreedor, monto original, tasa y CAT, corte y fecha límite de pago, límite de la tarjeta, mínimo y regla de día inhábil; **orden de pago por costo explicado**; costo estimado de deber; **uso del límite**; calendario de vencimientos; registro de **pago con capital, intereses y cargos**; "¿y si abono $X extra?" con la proyección que ya existe | 5.3 |
| Tarjetas y MSI | Compras a **MSI** (sin abono extra, ocupan límite, cuentan en la carga de deuda, calendario de mensualidades); **estado de cuenta capturado a mano** (corte, límite de pago, mínimo, pago para no generar intereses, intereses y cargos del corte) | 5.3 bis, puntos 2 y 6 |
| Importar la ficha | Importar tarjetas, crédito automotriz y MSI desde `FICHA_DEUDAS_Y_TARJETAS.xlsx` con vista previa, como la Fase 1 con las categorías (y con las mismas protecciones contra archivos no confiables, regla 69 de la Fase 1) | 5.3 bis, punto 1 |
| Ahorro | **Bolsas** (fondo de emergencia, reservas, metas con y sin fecha) con sus **8 métodos**; reparto semanal con orden y recorte de abajo hacia arriba; **confirmación semanal**; pendientes por bolsa sin castigo; retiros de 3 tipos con motivo; ahorro frente a deuda | 5.5, 5.5 bis |
| Fondo de emergencia | **5 niveles** (2, 4, 13, 26 y 52 semanas de gasto esencial), meta por defecto de 3 meses, sugerencia del nivel 4, **semanas cubiertas** con semáforo y reposición tras un retiro | 5.5 bis, puntos 2 y 7 |
| Indicadores nuevos | Semanas de fondo cubiertas, uso del límite de tarjetas, costo de deber y semana libre de deuda en el Tablero | 5.9 bis, punto 3 |
| Alertas de vencimiento y de presupuesto | Catálogo de alertas de la sección 5.4 (pago de deuda, límite de tarjeta, pago vencido, partidas al 80 y 100 %, gasto protegido en riesgo, flujo negativo, ingreso retrasado, uso del límite, fondo bajo, aportación pendiente, conciliación pendiente) con nivel, días antes, horas silenciosas y tope diario | 5.9 bis, puntos 6 y 7 |
| Notificaciones | **Recordatorios locales** (sin servidor), **avisos al instante** por Firebase Cloud Messaging con tokens por persona y dispositivo, **bandeja** dentro de la app, canales discretos en Android, preferencias por persona, avisos a la **pulsera** (D15, nivel 1) | 5.9 bis, punto 7; `DISENO_UX_UI.md` 12 y 17 |
| Servidor de avisos | Tablas `avisos*`, funciones, tareas programadas y una **Edge Function** que envía por FCM; **aviso al 80 % de la base** | sección 4 |
| "Hoy" con cifras reales | Herramienta `finanzas.resumen_semana` (solo local) que alimenta el resumen de GRAVITY, por libro y filtrada por rol | ROADMAP 11.4 |
| Aviso al suplente de papá | Notificación discreta cuando una salida del libro de papá va a otro libro (la entrada de bitácora ya existe, Fase 1b N3) | ROADMAP 11.4; D17 |

### 2.2 Queda fuera (y a dónde va)

| Queda fuera | Va a |
|---|---|
| **Simulador completo de estrategias** (avalancha, bola de nieve, escenarios, prueba de estrés del mínimo), alerta "mínimo en riesgo" por estrés | Fase 8+ (5.3 ter). La Fase 2 solo trae el "¿y si abono $X extra?" con el motor actual |
| **Estimador de tasa e intereses con estados de cuenta**, OCR de estados de cuenta, archivos PDF/CSV del banco, alerta "interés estimado distinto al cobrado" | Fase 8+ (5.3). Aquí el estado de cuenta se **captura a mano** y la tasa es la declarada |
| **Beneficios de tarjetas** ("¿Con cuál pago?", cashback, puntos, comisión por inactividad de Joy, reembolso de Costco), días de financiamiento | Fase 8+ (5.3 bis, puntos 3 a 5). **No se muestra ningún beneficio sin fuente verificada** |
| Inversión, bienes, previsión (sobres de 5.6 ter), alertas de bienes, de precios e inventario y de valor de inversión | Fase 8+ |
| **Confirmación de los demás titulares** al retirar de una bolsa compartida (5.5 bis, punto 7; prueba A8) | Fase 8 (confirmaciones). Aquí: cualquier miembro retira y los demás reciben un aviso informativo (regla 40; pregunta P7) |
| Transferencia pendiente de confirmar más de 48 horas (alerta de Cuentas) | Fase 8 (confirmaciones) |
| Alertas de sistema "sincronización pendiente" y "respaldo atrasado" | Fase 4 (plataforma). La infraestructura de avisos de esta fase ya las admite |
| Agregar vencimientos al calendario del teléfono (5.9 bis, punto 9) | Fase 8+ |
| **App propia de la pulsera/reloj** y botones en el aviso de la pulsera | Ampliaciones (D15, nivel 2: solo con Wear OS) |
| Avisos push en la laptop con la app cerrada | No se hace (D4: la laptop configura, el teléfono recibe). Con la app abierta: bandeja y aviso de Windows en vivo (regla 44) |
| **Consulta registrada de la cuenta maestra en el historial de GRAVITY** | **Fase 6.** El historial de GRAVITY todavía no existe; ver regla 52 y pregunta P12 |
| Ingresos variables, cómo cambia un ingreso (vigencias), PIN en un `Isolate`, Personas y "Tengo una invitación" | Otras áreas o pendientes del dueño (ROADMAP 11.4); no son de esta fase de Finanzas |
| Cualquier análisis de dinero con IA en la nube | **Nunca** (D3) |

---

## 3. Convenciones propias de la Fase 2

Además de la sección 3 de la Fase 1 (centavos, R1 y R2, puntos base, semana en lunes, ids estables, contrato de columnas):

1. **Todo por libro (D19).** Cada deuda, MSI, estado de cuenta, bolsa, aportación y retiro pertenece a un libro y se lee y escribe con `fin_puede(libro_id, …)`. Los avisos se dirigen a **personas**, que se calculan en el servidor desde la membresía del libro (nunca los elige el cliente).
2. **El saldo siempre sale del libro.** Una bolsa es una **cuenta de tipo `ahorro`** del libro; una deuda es una **cuenta pasivo**. No se guardan saldos en tablas nuevas. Aportar es una `transferencia` (activo → ahorro), retirar es otra (ahorro → activo) y pagar es un `pago_deuda`; todo con el libro solo-agregar y las anulaciones de siempre.
3. **Ids estables (UUID v5, convención 9 de la Fase 1):** llevan id derivado la aportación de ahorro (libro, semana y bolsa), el movimiento de esa aportación (de la aportación), el estado de cuenta (deuda y corte), las cuentas pasivo de un MSI (del MSI), los avisos (de su `clave`) y el registro de un dispositivo (del token). Reintentar nunca duplica.
4. **El motor sigue en Dart.** El servidor no repite el cálculo del presupuesto, del ahorro ni del flujo. Lo que el servidor sí calcula solo con fechas y estados (sin dinero) son los **vencimientos**, el **silencio**, el **tope diario** y el **80 % de la base** (sección 4.3).
5. **Los avisos no llevan dinero por construcción.** La tabla `avisos` no tiene columnas de monto, de nombre ni de texto libre; el texto de cada aviso es de un **catálogo cerrado** que vive en el código de la app (`TextoAviso`, sección 5.4) y se arma en el dispositivo.
6. **Redondeos:** R1 y R2 de siempre. En las cuotas que se reparten (MSI, meta con fecha) **la última absorbe la diferencia** para que la suma sea exacta (regla 12).
7. **Fecha y hora de los avisos:** `timestamptz`; el silencio y el tope diario se calculan en la **zona horaria de la persona** (`America/Mexico_City` por defecto).
8. **Identificadores** en español sin acentos (`BolsaAhorro`, `repartirAhorro`, `programarAvisos`); tablas `fin_*` para lo financiero y `avisos*` para la infraestructura que Hábitos y Cuidados reutilizarán (sección 4.1; **propuesta de decisión D20**, pregunta P13).

---

## 4. Modelo de datos (Supabase, para el agente backend)

Todas las tablas llevan `hogar_id uuid not null references public.hogares`, RLS activado, privilegios por columna y trigger de bitácora donde la Fase 1 lo pone (`registrar_cambio_en_bitacora`). Dinero en `bigint` de centavos con `check`; tasas y porcentajes en `integer` de puntos base. Migración nueva, **no se edita ninguna de las siete existentes**: `20261101000000_finanzas_fase2.sql` (deudas y ahorro) y `20261102000000_avisos.sql` (avisos, dispositivos, tareas), o el siguiente número libre.

### 4.1 Tablas nuevas y cambios

| Tabla | Campos principales | Notas |
|---|---|---|
| `fin_deudas` (cambios) | Agrega: `clase` (`tarjeta`/`prestamo`/`credito`/`msi`/`familiar`, obligatoria), `acreedor` (texto ≤ 80; "BBVA", "Caja Popular Mexicana"), `monto_original_centavos` (nulo permitido), `cat_pb` (nulo), `corte_dia` (1 a 31; 0 = último día; solo tarjetas), `permite_pago_anticipado` (bool nulo: "verificar con la caja", 5.3 punto 6), `extra_reduce` (`plazo`/`cuota`/nulo) | Check de coherencia: `clase = 'msi'` ⇔ `tipo = 'msi'`; `clase = 'familiar'` ⇔ `tipo = 'familiar'`; tarjeta, préstamo y crédito ⇔ `tipo = 'con_costo'`. Las filas de la Fase 1 se rellenan: `con_costo` → `credito`, salvo que su cuenta pasivo sea de tipo `tarjeta` (→ `tarjeta`). La **fecha límite de pago** es el calendario que la deuda ya tiene; el **límite de crédito** es `fin_cuentas.limite_centavos` de su cuenta pasivo |
| `fin_msi` | `id`, `libro_id`, `deuda_id` (único; la deuda `msi`), `tarjeta_deuda_id` (deuda de clase `tarjeta`, nula si esa tarjeta no está en la app), `cuenta_pasivo_id` (**cuenta propia del MSI**, tipo `prestamo`; su saldo es lo que falta pagar), `comercio` (≤ 80), `descripcion` (≤ 120), `fecha_compra`, `monto_total_centavos` (> 0), `mensualidades` (2 a 48), `activo` | Comercio y descripción son datos del libro (RLS), **jamás** salen en un aviso. La mensualidad es `abono_centavos` de la deuda; las pagadas y las restantes **salen de las ocurrencias** cumplidas, no se guardan |
| `fin_estados_cuenta` | `id` (derivado de deuda y corte), `libro_id`, `deuda_id`, `fecha_corte`, `fecha_limite_pago`, `saldo_al_corte_centavos`, `pago_minimo_centavos`, `pago_sin_intereses_centavos`, `intereses_centavos` (0), `cargos_centavos` (0), `tasa_declarada_pb` (nula), `cat_pb` (nulo), `via` (`manual`), `registrado_por`, `registrado_en` | **Solo agregar.** Para un mismo corte vale el registro más reciente (se corrige agregando otro). Es captura manual: no hay estimador (sección 2.2) |
| `fin_bolsas_ahorro` | `id`, `libro_id`, `nombre` (≤ 80), `tipo` (`fondo_emergencia`/`reserva`/`meta_fecha`/`meta_libre`), `cuenta_id` (cuenta tipo `ahorro` del libro), `meta_centavos` (nula en el fondo, que la calcula el motor), `monto_anual_centavos` (reserva), `fecha_meta` (meta con fecha), `nivel_meta` (1 a 5, solo fondo; 3 por defecto), `aporte_fijo_centavos`, `aporte_pb` (meta libre: monto o porcentaje del remanente), `metodos` (`text[]` de la lista de la regla 25), `redondeo_multiplo_centavos` (1000), `reto_base_centavos`, `prioridad` (orden dentro de su grupo), `activa` | Un solo fondo activo por libro (índice único parcial). Cambiar la configuración vale de ahí en adelante; el historial son los movimientos |
| `fin_aportaciones_ahorro` | `id` (derivado), `libro_id`, `semana_id`, `bolsa_id`, `sugerido_centavos`, `aportado_centavos` (0), `pendiente_centavos` (generada: sugerido − aportado, nunca negativa), `estado` (`propuesta`/`confirmada`/`pospuesta`/`omitida`), `movimiento_id` (nulo hasta confirmar), `confirmada_por`, `confirmada_en` | Único (`semana_id`, `bolsa_id`). Cambia solo mientras la semana no esté cerrada, salvo confirmar la aportación de la semana recién cerrada (el cierre propone el reparto, regla 30). `movimiento_id` y `aportado` no se tocan una vez puestos |
| `fin_retiros_ahorro` | `id`, `libro_id`, `bolsa_id`, `movimiento_id` (único), `tipo` (`uso_previsto`/`emergencia`/`cambio_destino`), `motivo` (≥ 3 caracteres visibles, `fin_motivo_valido`), `bolsa_destino_id` (solo en cambio de destino), `registrado_por`, `registrado_en` | **Solo agregar.** En el libro de papá el movimiento ya exige `en_nombre_de` y motivo (regla 50 de la Fase 1) |
| `fin_parametros` (cambios) | Agrega: `orden_ahorro` (`text[]`, por defecto `{fondo_n1,reservas,metas_fecha,fondo_meta,metas_libres}`), `dependientes_cuidados` (bool, 0; lo declara la persona, **no se infiere**), `esenciales_incluyen_minimos` (bool, true; pregunta P9), `dias_aviso_deuda` (`smallint[]`, `{3,1}`) | Por libro, como el resto de los parámetros |
| `dispositivos` (cambios) | Agrega: `tipo` (`telefono`/`tablet_personal`/`tablet_publica`/`laptop`), `recibe_avisos` (bool; **falso** por omisión en tablet personal y laptop, **siempre falso** en tablet pública, trigger), `ultimo_envio_en`, `fallos` (contador); el `token_avisos` pasa a **único global** | Cierra M13: un token solo está a nombre de una persona; entrar con otra cuenta lo reasigna (función `registrar_dispositivo`) |
| `avisos_preferencias` | `persona_id` (PK), `hogar_id`, `zona_horaria` (`America/Mexico_City`), `silencio_desde` (22:00), `silencio_hasta` (07:00), `criticas_en_silencio` (false), `tope_no_criticas` (3), `hora_vencimientos` (09:00), `resumen_lunes` (08:00), `recordatorio_cierre_dia` (7 = domingo) y `recordatorio_cierre_hora` (19:00), `tipos_silenciados` (`text[]`), `pulsera_texto_corto` (true) | Una fila por persona (la crea el servidor al darle un rol con Finanzas; la app solo hace UPDATE). Cada quien las suyas |
| `avisos` | `id`, `hogar_id`, `persona_id` (destinatario), `modulo` (`finanzas`/`sistema`), `tipo` (catálogo cerrado, `check`), `severidad` (`critica`/`importante`/`informativa`), `clave` (texto ≤ 120, único con `persona_id`: idempotencia), `libro_id` (nulo en `sistema`), `objeto_tipo` (`deuda`/`ocurrencia`/`partida`/`bolsa`/`semana`/`libro`/`movimiento`) y `objeto_id`, `programado_para`, `enviar_en`, `estado` (`pendiente`/`enviada`/`agrupada`/`cancelada`/`leida`/`resuelta`/`pospuesta`), `enviada_en`, `leida_en`, `resuelta_en`, `creado_en` | **Sin columnas de monto, de nombre ni de texto libre.** Los destinatarios los fija el servidor. Se limpia a los 90 días (regla 48). Cada persona lee solo los suyos |
| `avisos_entregas` | `id`, `aviso_id`, `dispositivo_id`, `enviada_en`, `resultado` (`ok`/`token_invalido`/`error`), `codigo` | Solo agregar; sirve para no reenviar y para borrar tokens muertos |
| `avisos_sistema` | `clave` (PK), `valor` (jsonb corto) | Una fila: `limite_base_bytes` (524 288 000 = 500 MB, el cupo del plan gratuito *(verificar el cupo vigente)*) y los umbrales 80 y 90 % |

**Vistas de apoyo** (`security_invoker = true`): `fin_v_deuda_resumen` (saldo por deuda desde el libro, MSI pendiente por tarjeta) y `fin_v_bolsa_saldo` (saldo por bolsa). No guardan nada.

**Cambios al enum de `fin_ocurrencias.origen`:** sin cambio (`ingreso`/`compromiso`/`deuda`); las mensualidades de MSI son ocurrencias de su deuda.

### 4.2 Reglas por rol (RLS)

| Tabla | Leer | Insertar | Cambiar | Borrar |
|---|---|---|---|---|
| `fin_msi`, `fin_bolsas_ahorro`, `fin_deudas` (columnas nuevas) | `fin_puede(libro_id,'leer')` | `fin_puede(…,'administrar')` | `fin_puede(…,'administrar')` | Nadie (se desactiva con `activa`) |
| `fin_estados_cuenta`, `fin_retiros_ahorro` | `fin_puede(…,'leer')` | `fin_puede(…,'escribir')` y `registrado_por = persona_actual()` | **Nadie** (trigger `impedir_cambios_solo_agregar`) | **Nadie** |
| `fin_aportaciones_ahorro` | `fin_puede(…,'leer')` | `fin_puede(…,'escribir')` | `fin_puede(…,'escribir')`, nunca `movimiento_id` ni `aportado` ya puestos | Nadie |
| `avisos`, `avisos_preferencias` | Solo `persona_id = persona_actual()` | **Nadie directo**: solo las funciones de 4.3 | La propia persona puede cambiar únicamente `estado` (leída, pospuesta) y `enviar_en` (posponer) de **sus** avisos y sus preferencias, por función | Nadie (limpieza del servidor) |
| `avisos_entregas`, `avisos_sistema` | Nadie desde la app (solo `service_role`) | Solo `service_role` | Nadie | Solo `service_role` |
| `dispositivos` | Cada quien los suyos | Por `registrar_dispositivo` | Cada quien los suyos | Cada quien los suyos |

**Libro archivado:** todas las tablas de libro son de solo lectura si el libro está archivado (como en la Fase 1). **La cuenta maestra** lee con la consulta registrada (regla 56 de la Fase 1) y **nunca recibe avisos de dinero**: no es destinataria de ningún tipo de `modulo = 'finanzas'`. Familiar, cuidador y Casa no ven ni reciben nada de Finanzas.

### 4.3 Funciones, tareas y Edge Function

**Funciones (security definer, `search_path` fijo, como las de la Fase 0):**

- `registrar_dispositivo(p_token, p_plataforma, p_nombre, p_tipo)`: da de alta o **reasigna** el token a la persona actual (borra el vínculo anterior; cierra M13), con id derivado del token; una tablet pública nunca queda con `recibe_avisos`. `quitar_dispositivo(p_token)`: al cerrar sesión, al quitar a la persona de la tablet y en una baja.
- `fin_emitir_aviso(p_libro_id, p_tipo, p_objeto_tipo, p_objeto_id, p_clave)`: la usa la **app** para los avisos que solo el motor sabe calcular (partida al 80 y 100 %, gasto protegido en riesgo, flujo negativo, uso del límite, fondo bajo, aportación y conciliación pendientes). Valida `fin_puede(libro,'escribir')`, que el `tipo` esté en la lista de los emitibles por la app, **calcula los destinatarios** (regla 41), aplica el silencio y el tope (4.3.1) e inserta de forma idempotente por `clave`. Tope propio: 60 emisiones por persona al día (22023 al pasarlo).
- `avisos_marcar(p_aviso_id, p_accion)` con `leida`, `resuelta` o `posponer_1h` / `posponer_manana`.
- `avisos_actualizar_preferencias(…)`: valida rangos (tope de 0 a 10, horas coherentes).
- `fin_aviso_salida_representado(…)`: llamada **dentro de la misma función** que ya deja la entrada `finanzas.salida_libro_representado` (N3, Fase 1b); inserta un aviso `salida_libro_representado` para el **suplente vigente** (no para quien capturó). Sin suplente vigente no hace nada. Retiro de una bolsa de un libro compartido: aviso `retiro_bolsa_compartida` a los **otros** miembros.
- `avisos_revisar_base()`: ver "Aviso al 80 % de la base".

**4.3.1 Programación de alertas de vencimiento (tarea de SQL, cada hora).** `avisos_generar_vencimientos()` recorre `fin_ocurrencias` de origen `deuda` en estado `esperada` o `retrasada` con `fecha_ajustada` en los próximos 7 días (más las vencidas de ayer y antier) y, para cada destinatario del libro:

1. Calcula las fechas de aviso con `dias_aviso_deuda` (por defecto 3 y 1 días antes de `fecha_ajustada`, a la `hora_vencimientos` de la persona). Si la fecha de aviso ya pasó, **no se recupera** lo atrasado: solo se crea el aviso más próximo que aún no pasó (sin avalancha al abrir una deuda nueva).
2. **Pago vencido:** si la `fecha_ajustada` ya pasó y sigue `esperada`, la ocurrencia pasa a `retrasada` y se crea un aviso crítico `pago_vencido` (uno al día siguiente y otro a los 3 días; luego se calla).
3. **Ingreso retrasado:** ocurrencias de origen `ingreso` sin cumplir al siguiente día hábil de su fecha: aviso `ingreso_retrasado` (importante, uno).
4. `clave = tipo:objeto_id:fecha_ajustada:n` → la misma ocurrencia nunca avisa dos veces el mismo paso; si la fecha de la ocurrencia cambia (la app regenera las ocurrencias, regla 36), los avisos `pendiente` del paso viejo se **cancelan** y se crean los nuevos.
5. **Silencio:** si `enviar_en` cae en horas silenciosas y la persona no permite críticas, pasa a `silencio_hasta` (07:00); las críticas con `criticas_en_silencio` verdadero salen a su hora.
6. **Tope diario:** del tercer aviso **no crítico** del día (por zona horaria de la persona) en adelante, el aviso queda `agrupada`: se ve en la bandeja y entra en el siguiente resumen, pero no suena. Los recordatorios fijos (resumen del lunes y cierre) no cuentan.
7. Los pagos con `monto_esperado` en cero no avisan.

**Edge Function `enviar-avisos`** (`supabase/functions/enviar-avisos/`, TypeScript sobre Deno; la invoca `pg_cron` + `pg_net` cada 5 minutos con la clave de servicio guardada en el Vault de Supabase, nunca en el repositorio):

1. Toma con `select … for update skip locked` hasta 200 avisos `pendiente` con `enviar_en <= now()` de personas con `recibe_avisos` en al menos un dispositivo.
2. Para cada aviso lee los tokens de la persona (`service_role`), **excluyendo** `tablet_publica` y los equipos con `recibe_avisos = false`.
3. Envía por **FCM HTTP v1** un mensaje **solo de datos**, prioridad alta, con `collapse_key = clave`: `{ "v": "1", "id": "<uuid del aviso>" }`. **Nada más**: ni tipo, ni libro, ni persona, ni texto. Google solo ve un identificador opaco. El dispositivo, al recibirlo, lee su propia fila de `avisos` (RLS) para saber el tipo y arma el texto del catálogo; sin señal o sin sesión (p. ej. tablet bloqueada con PIN) muestra el aviso genérico *"Tienes un aviso de GRAVITY"* (regla 43).
4. Registra el resultado en `avisos_entregas`; marca el aviso `enviada`; si FCM responde `UNREGISTERED` borra el token; tras 5 fallos seguidos de un token lo desactiva.
5. Secretos: la cuenta de servicio de Firebase va en `supabase secrets set FCM_SERVICE_ACCOUNT=…`; el proyecto de Firebase lo crea el dueño (ROADMAP: pendiente de la Fase 0). **Sin ese secreto la función no envía y la app sigue funcionando** con recordatorios locales y bandeja.
6. Reintento: un aviso cuyo envío falla por error del servidor se reintenta a los 5, 15 y 60 minutos y se da por enviado-sin-entrega (queda en la bandeja).

Costo: FCM, pg_cron, pg_net y las Edge Functions están en el plan gratuito; 288 invocaciones al día quedan muy por debajo del cupo *(verificar las condiciones vigentes de Supabase y Firebase antes de lanzar)*.

**Aviso al 80 % de la base (`avisos_revisar_base`, diario a las 06:00).** Lee `pg_database_size(current_database())` y `limite_base_bytes`; con ≥ 80 % crea un aviso `base_80` (importante) para cada **dueño** del hogar y con ≥ 90 % uno `base_90` (crítico); uno por día como máximo mientras siga arriba. Texto: *"Revisa el almacenamiento de GRAVITY"*. Dentro de la app, *Ajustes › Copias de seguridad* muestra el porcentaje y las tablas más grandes (la bitácora y los avisos) y la **limpieza**: `avisos` y `avisos_entregas` de más de 90 días se borran solos cada noche; la bitácora **no se toca** (es solo agregar, D17). Esto cierra el pendiente M2 (parte 2) de `supabase/README.md`.

**Retención:** `avisos` de más de 90 días y `avisos_entregas` de más de 30 se borran con una tarea nocturna (única excepción al "nadie borra", porque no son libro contable).

---

## 5. Reglas de negocio

### 5.1 Deudas a detalle

1. **Clases de deuda** (5.3): *tarjeta* (límite, corte, fecha límite de pago, mínimo, pago para no generar intereses), *préstamo* y *crédito* (hipotecario, automotriz, nómina, departamental: cuota fija, tasa, pagos restantes opcionales), *MSI* (regla 10) y *familiar* (sin tasa). Los tipos `con_costo`, `familiar` y `msi` de la Fase 1 no cambian.
2. **Datos mínimos y no inventados:** una deuda con costo exige su tasa anual declarada (Fase 1, regla 28); el límite, el CAT, el monto original y las fechas son opcionales y, si faltan, la pantalla pide capturarlos en lugar de calcular con un supuesto. **La app no trae tasas, anualidades ni beneficios de ningún banco**: salen de la ficha o de lo que captura la persona.
3. **Saldo:** el del libro (cuenta pasivo). Una deuda sin saldo (cero) se marca *Liquidada* y la app sugiere archivarla; su abono liberado sigue la regla 54 de la Fase 1.
4. **Registrar un pago** (hoja con *Capital*, *Intereses* y *Cargos*): el capital es un `pago_deuda` (activo → pasivo); los intereses y cargos que **se pagan junto con el pago** son un `gasto` (activo → cuenta de gasto financiero) con el mismo `grupo_id`. Los intereses y cargos que **el banco ya sumó a la tarjeta** al corte se registran al capturar el estado de cuenta (regla 9) como `gasto` desde la cuenta pasivo, y el pago entero se captura como capital **(interpretación; pregunta P10)**. Un pago de una deuda de otro libro cruza de libro como en la Fase 1 (regla 47). La ocurrencia del pago se marca `cumplida` con su `movimiento_id` y, si se pagó menos del mínimo, `parcial` y alerta roja (regla 30 de la Fase 1).
5. **Orden de pago por costo** (5.3, decisión del 15/oct): (1) siempre los **mínimos** de todas; (2) el **abono extra** pasa por la prioridad manual, luego por el **grupo prioritario** (regla 54 de la Fase 1) y, sin grupo, por **mayor tasa efectiva** (desempate: más interés en pesos); (3) los préstamos familiares al final; (4) los **MSI no reciben extra**. La pantalla muestra el orden **con el motivo de cada lugar** ("manual", "grupo, lugar 2", "tasa 60 %", "familiar: al final", "MSI: no recibe extra") y la comparación de cuánto ahorra frente a pagar por saldo, con la proyección actual. El ejemplo de las cuatro tarjetas de 5.3 es **ilustrativo**: el criterio solo exige el orden B, A, C, D (criterio 4).
6. **Costo de deber (estimado):** interés semanal simple = saldo × tasa ÷ 52 por deuda con costo, repartido por mayor resto (R2); siempre rotulado *estimado*. Con las cuatro tarjetas de 5.3: $364.62 por semana (criterio 5).
7. **Uso del límite:** (saldo de la tarjeta + saldo pendiente de sus MSI) ÷ límite; verde < 30 %, ámbar de 30 a 60 %, rojo > 60 %, comparando la **fracción exacta** (convención 4 de la Fase 1) y por tarjeta y total. Sin límite capturado no se calcula: dice *"Captura el límite de esta tarjeta"*. Que los MSI ocupen límite es una bandera de la tarjeta **(verificar con cada emisor; pregunta P8)**.
8. **Próximo pago y "Ver cuánto pagar":** muestra el abono planeado, el mínimo y el **pago para no generar intereses del último estado de cuenta capturado** si su `fecha_limite_pago` es hoy o futura; si no hay estado vigente dice *"Captura tu estado de cuenta para ver el pago sin intereses"*; **nunca lo calcula con suposiciones**. Sugiere pagar el total cuando existe.
9. **Estado de cuenta capturado a mano:** corte, límite de pago, saldo, mínimo, pago sin intereses, intereses y cargos del corte y, si aparecen, tasa y CAT. Los intereses y cargos pueden registrarse como gasto financiero con un toque (confirmación, no automático). Si la tasa declarada del estado difiere de la de la deuda, la app **avisa y pide confirmar** el cambio (no lo cambia sola).
10. **MSI:** una compra a MSI es una deuda `msi` con su cuenta pasivo propia: la compra es un `gasto` desde esa cuenta (el pasivo sube por el total); cada mensualidad es un `pago_deuda`. Mensualidad = total ÷ meses (R1); **la última absorbe la diferencia** (3 meses de $1,000: $333.33, $333.33 y $333.34). No recibe abono extra; **cuenta completa en la carga de deuda**; ocupa límite según la regla 7; el calendario de mensualidades muestra el total de cada mes. Adelantar un MSI solo se ofrece si la persona lo pide (para liberar límite), con confirmación.
11. **Compras diferidas, pagos fijos y parcialización** (Nu, Banamex, Costco) **no son MSI**: son deuda con costo y reciben extra por tasa (5.3 bis, regla 4).
12. **Crédito automotriz (la caja):** el extra solo se propone a capital si `permite_pago_anticipado` es verdadero; si es nulo, la app dice *"Verifica con la caja si permite pago anticipado a capital"* y no lo propone. Su regla de *siguiente día hábil* sigue siendo de la Fase 1 (regla 53) y se configura en la app.
13. **"¿Y si abono $X extra por semana?"**: reutiliza `proyectarSalidaDeDeuda`; muestra la semana libre de deuda y los intereses estimados que ahorra frente al plan base, rotulado *ilustrativo*. No es el simulador de 5.3 ter.
14. **Importar la ficha:** `FICHA_DEUDAS_Y_TARJETAS.xlsx` (de `data/personal/`, ignorada por git) se elige con el selector de archivos; las hojas de tarjetas, crédito automotriz y MSI producen deudas, cuentas pasivo y MSI en una **vista previa** que la persona confirma (lo omitido se explica); reimportar no duplica (ids derivados). El importador es **entrada hostil** (misma regla 69 de la Fase 1: topes, sin fórmulas, sin relaciones externas). **Las pruebas usan una ficha ficticia generada por la propia prueba; ninguna prueba abre `data/personal/`.** Las hojas de beneficios y estados de cuenta de la ficha no se importan en esta fase.

### 5.2 Ahorro y fondo de emergencia

15. **Bolsa = cuenta de ahorro del libro.** Tipos: *fondo de emergencia* (uno por libro), *reserva* (gasto deseado con fecha), *meta con fecha* y *meta sin fecha*. El **refrendo, el predial, el agua y el seguro no son ahorro** (son previsión, 5.6 ter, fuera de esta fase). Crear una bolsa crea su cuenta `ahorro` (con saldo inicial opcional como apertura). Una bolsa en el libro de papá y en un compartido es posible; en el de papá cada movimiento va en su nombre y con motivo (regla 50 de la Fase 1).
16. **Ahorro frente a deuda** (5.5 bis, punto 8; prueba A7): mientras haya **deuda que reciba abono extra** —una deuda con costo o un préstamo familiar del orden de la regla 5; **los MSI no cuentan**— el reparto sugerido vale **cero** y la app no propone aportaciones nuevas; todo el remanente va a deuda. Dos excepciones que ya existen: (a) el **ahorro mínimo con deuda** (parámetro del libro, 0 % por defecto) se aparta primero y va al colchón (nivel 1); (b) con **grupo prioritario pagado** el remanente va a ahorro aunque queden deudas fuera del grupo (regla 54 de la Fase 1, respuesta P12 y P19 del dueño). Aportar a mano a una bolsa con deuda cara pendiente **se permite**, mostrando antes el costo estimado semanal de deber y dejando el aviso en pantalla (prueba I7 del diseño).
17. **Fondo de emergencia por niveles** (5.5 bis, punto 2):

| Nivel | Semanas de gasto esencial | Con $3,500 de esenciales por semana |
|---|---|---|
| 1. Colchón | 2 | $7,000 |
| 2. Mes | 4 | $14,000 |
| 3. Tres meses (por defecto) | 13 | $45,500 |
| 4. Seis meses | 26 | $91,000 |
| 5. Un año | 52 | $182,000 |

18. **Gasto esencial semanal** = promedio de las **últimas 8 semanas con cierre** del gasto real en las partidas **protegidas** y en las categorías de prioridad `necesario`, más —si `esenciales_incluyen_minimos`— los **pagos mínimos de deuda** (equivalente semanal, R2). Si hay menos de 8 semanas cerradas se usan las que haya; si no hay ninguna, se usa el **presupuesto semanal** de esas mismas partidas, rotulado *"según tu plan"* **(interpretación; pregunta P9)**. La meta en pesos es `semanas del nivel × esencial semanal` (R1). Nunca se inventa un dato: sin partidas ni historial, la pantalla pide armar el presupuesto.
19. **Semanas cubiertas** = saldo del fondo ÷ gasto esencial semanal, con un decimal hacia abajo (*"tienes 3.0 semanas cubiertas"*). Semáforo (5.9 bis): verde ≥ la meta elegida, ámbar de 50 % a menos de 100 % de la meta, rojo < 50 %, sobre la **fracción exacta**. Sin gasto esencial calculado no hay semáforo.
20. **Nivel sugerido:** el nivel 4 se **sugiere** (la persona decide) si el libro tiene **un solo ingreso activo**, algún ingreso `probable` o `incierta` como único sustento, o si la persona declaró `dependientes_cuidados` (casilla en el asistente del fondo; no se infiere de otros libros).
21. **Aportación de cada bolsa** (5.5 bis, punto 3): *reserva* = monto anual ÷ 52 (R2); *meta con fecha* = (meta − saldo) ÷ semanas restantes, mínimo 1 semana (la última aportación absorbe la diferencia); *meta sin fecha* = monto fijo o porcentaje del remanente; *fondo* = lo que falta para el nivel elegido, repartido en las semanas que la persona decida (por defecto, lo que alcance el orden). Una meta con fecha vencida pide una fecha nueva; no aporta.
22. **Orden por defecto del reparto** (editable, `orden_ahorro`): (1) fondo hasta el nivel 1; (2) reservas; (3) metas con fecha (solo lo necesario para llegar); (4) fondo hasta la meta elegida; (5) metas sin fecha. Si lo sugerido suma más que el remanente disponible, se **recorta de abajo hacia arriba**; el colchón es lo último que se recorta (prueba A3).
23. **Aceleración y su costo:** al pedir una meta en menos semanas, el plan muestra cuánto sube la aportación, qué otras bolsas retrasa y cuánto colchón baja en el camino (ejemplo: el celular en 12 semanas pide $625 en vez de $250).
24. **Pendiente por bolsa:** lo no aportado queda como *pendiente* **sin intereses ni castigo**, con tres salidas: recuperarlo repartido en varias semanas, mover la fecha o bajar la meta. El **reto de 52 semanas** marca la semana como *pospuesta*, no como fallada.
25. **Los 8 métodos** (5.5), todos con suma **limitada por el remanente** y todos como **sugerencia que la persona confirma** (la app nunca mueve dinero sola):

| Método | Sugerencia de la semana |
|---|---|
| Págate primero | % del ingreso que llegó; **apagado mientras la regla 16 diga cero** |
| Monto fijo semanal | La cantidad configurada |
| Meta con fecha | Regla 21 |
| Reto de 52 semanas | Semana *k* × la base (con base $10: $10 la semana 1 y $520 la 52; suma $13,780) |
| Redondeo | Suma de lo que falta para llegar al siguiente múltiplo (por defecto $10, hacia arriba) en cada **gasto de la semana** (se calcula al armar el reparto, no al capturar el gasto) |
| Sobrante semanal | Lo no gastado del presupuesto de la semana anterior (el remanente positivo del cierre) |
| Sobre por categoría | Lo no gastado de una categoría elegida |
| Porcentaje de extras | % de los ingresos extra de la semana |

    Los métodos redondeo, sobrante, sobre y extras **alimentan la misma bolsa y se descuentan de la aportación sugerida** para no apartar dos veces (5.5 bis, punto 5).
26. **Confirmación semanal:** el paso *"Aplicar remanente"* de la revisión semanal (Fase 1, regla 35) muestra el reparto por bolsa; la persona confirma (cada bolsa o todas), pospone u omite. Confirmar crea la `transferencia` (activo → bolsa) con id derivado y deja `aportado`, `movimiento_id` y `confirmada_por`. Aplicarla dos veces no duplica.
27. **Retiros** (5.5 bis, punto 7): *uso previsto* (elegir el gasto; la bolsa baja), *emergencia* (motivo; el plan **repone el fondo primero** hasta el saldo que tenía antes del retiro) y *cambio de destino* (a otra bolsa, con motivo y confirmación). El motivo vale con **3 caracteres visibles** (regla 70 de la Fase 1); queda en `fin_retiros_ahorro` y en la bitácora. Un retiro no es ingreso y no cambia el patrimonio (es una transferencia entre activos).
28. **Bolsa de un libro compartido:** cualquier miembro aporta y retira (D19: cualquier miembro registra); como la confirmación de los demás titulares es de la Fase 8, **todo retiro avisa a los otros miembros** (regla 40) y queda con quién lo hizo.
29. **Cuadre:** aportar y retirar son transferencias entre activos del mismo libro: el patrimonio y el cuadre de la Fase 1 no cambian. Las aportaciones a la bolsa de **otro libro** son una aportación entre libros (Fase 1, reglas 47 y 48).
30. **Cierre de semana:** el cierre ya guarda `ahorro_real`; la Fase 2 agrega al paso de la revisión las aportaciones propuestas y confirmadas de esa semana. Una aportación confirmada después del cierre se registra con la fecha de la semana cerrada y no cambia la foto del cierre (Fase 1, regla 11).

### 5.3 Indicadores nuevos del Tablero

31. **Semanas de fondo cubiertas** (regla 19), **uso del límite de tarjetas** (regla 7), **costo de deber** (regla 6, comparado con la semana anterior) y **semana libre de deuda** (estimación del motor: *se adelanta / igual / se atrasa* frente a la última vez que se calculó, guardada en la copia local). Cada uno con semáforo y texto o icono, nunca solo color, y los montos ocultables. Las tarjetas de indicador ocultan solas sus cifras de dinero (regla 66 de la Fase 1); los porcentajes y las semanas quedan visibles.

### 5.4 Alertas

32. **Catálogo de la Fase 2** (subconjunto de 5.9 bis, punto 6; cada alerta con nivel, momento y botón de acción). **Origen** dice quién la genera: *servidor* (fechas y estados, sección 4.3.1), *app* (el motor, por `fin_emitir_aviso`) o *local* (programado en el teléfono, sin servidor).

| Alerta (`tipo`) | Nivel | Cuándo avisa (por defecto) | Origen | Destinatarios | Acción |
|---|---|---|---|---|---|
| Pago de deuda (`pago_proximo`) | **Crítica** | 3 y 1 días antes | servidor + local | Miembros del libro | Registrar pago |
| Límite de pago de tarjeta (`limite_tarjeta`) | **Crítica** | 3 y 1 días antes de la fecha límite | servidor + local | Miembros del libro | Ver cuánto pagar |
| Pago vencido sin registrar (`pago_vencido`) | **Crítica** | Al día siguiente y a los 3 días | servidor | Miembros del libro | Registrar pago |
| Gasto protegido en riesgo (`protegido_riesgo`) | **Crítica** | Al detectarlo | app | Miembros del libro | Ver cómo cubrirlo |
| Semana con flujo negativo (`flujo_negativo`) | **Crítica** | Al proyectarse | app | Miembros del libro | Ver escenarios |
| Abono bajo el mínimo (`abono_bajo_minimo`) | **Crítica** | Al armar o cerrar el plan | app | Miembros del libro | Ver deudas |
| Partida al 100 % (`partida_100`) | Importante | Al llegar | app | Quien registró y titular | Mover o aceptar |
| Ingreso retrasado (`ingreso_retrasado`) | Importante | Siguiente día hábil | servidor | Titular / albacea | Reprogramar |
| Fondo de emergencia bajo (`fondo_bajo`) | Importante | Al caer a rojo o bajar de un nivel ya alcanzado; una vez por semana como máximo | app | Titular | Ver reposición |
| Salida del libro de papá (`salida_libro_representado`) | Importante | Al ocurrir | servidor | **Suplente** vigente | Ver movimiento |
| Base de datos al 80 % (`base_80`) y 90 % (`base_90`, crítica) | Importante / crítica | Diario mientras siga arriba | servidor | **Dueño** | Ver almacenamiento |
| Partida al 80 % (`partida_80`) | Informativa | Al llegar | app | Quien registró | Ver partida |
| Uso del límite arriba de 30 % (`uso_limite`) | Informativa | Al cruzar | app | Titular | Ver tarjeta |
| Aportación pendiente (`aportacion_pendiente`) | Informativa | Al cierre semanal | local | Titular | Confirmar o posponer |
| Conciliación pendiente (`conciliacion_pendiente`) | Informativa | Al cierre semanal | local | Titular | Conciliar |
| Retiro de una bolsa compartida (`retiro_bolsa_compartida`) | Informativa | Al ocurrir | servidor | Los otros miembros | Ver movimiento |
| Resumen del lunes (`resumen_lunes`) | Informativa (fija) | Lunes 8:00 | local | Cada persona | Abrir Hoy |
| Recordatorio de cierre (`recordatorio_cierre`) | Informativa (fija) | Domingo 19:00 | local | Cada persona | Revisión semanal |

33. **Qué cuenta como "alerta crítica"** (propuesta por defecto, pregunta P3): las que, si no se atienden a tiempo, **cuestan dinero** o dejan sin cubrir algo protegido: pago de deuda, límite de tarjeta, pago vencido, gasto protegido en riesgo, flujo negativo y abono bajo el mínimo (y la base al 90 %). Todo lo demás es importante o informativo. El **gasto protegido en riesgo** significa que el peor caso del flujo (regla 38 de la Fase 1) no alcanza a cubrir una partida protegida que vence en los próximos 7 días **(interpretación)**.
34. **Días antes:** 3 y 1 (por persona, `dias_aviso_deuda`); se pueden poner de 0 a 3 avisos entre 0 y 14 días. Aviso del mismo día: no por defecto.
35. **Horas silenciosas:** de 22:00 a 07:00 por defecto. **Las críticas tampoco suenan en ese horario** salvo que la persona lo permita; esperan a las 07:00 y, de todos modos, aparecen al abrir la app (regla 8 de 5.9 bis, punto 7) **(pregunta P4)**.
36. **Tope diario:** 3 avisos no críticos al día; el resto se agrupa (4.3.1, punto 6). Las críticas no tienen tope.
37. **Posponer y silenciar:** cada aviso se pospone **1 hora** o **hasta mañana** (acción del propio aviso y de la bandeja) o se **silencia su tipo** (`tipos_silenciados`); una crítica silenciada igual aparece en la bandeja y en Hoy.
38. **Resolverse solas:** al registrar el pago (la ocurrencia pasa a `cumplida`) los avisos pendientes de esa ocurrencia se **cancelan** en el servidor y la app borra la notificación local con la misma `clave`. Al sincronizar, la app cancela cualquier recordatorio local cuyo aviso ya no esté `pendiente`.
39. **Cada alerta crítica también aparece al abrir la app** (banner arriba de Hoy y del Tablero con su acción), aunque el sistema haya retrasado o bloqueado la notificación.
40. **Aviso al suplente y retiros compartidos:** las salidas del libro de papá hacia **cualquier otro libro** (transferencia o pago de deuda) avisan al suplente vigente con *"Hay un movimiento por revisar"*; el detalle (a dónde, cuánto, motivo, quién) lo ve en la bandeja desde la entrada de bitácora que ya puede leer (N3). El retiro de una bolsa compartida avisa del mismo modo a los otros miembros. No avisan al que hizo el movimiento.
41. **Destinatarios (los calcula el servidor):** libro personal → su titular; libro compartido → **todos** los miembros vigentes (5.9 bis, punto 7); libro de papá → el albacea vigente y, si no hay albacea vigente, el suplente (más el aviso de salida de la regla 40). **Nunca la cuenta maestra**, ni familiar, cuidador o Casa.

### 5.5 Notificaciones: discreción, dispositivos y pulsera

42. **Catálogo cerrado de textos** (`TextoAviso`, en `finanzas_dominio`; lo pasa a Flutter la plataforma). Título corto de **máximo 40 caracteres**, **sin dígitos, sin "$", sin nombres propios**; palabras relativas (hoy, mañana) sí:

| `tipo` | Texto (título) |
|---|---|
| `pago_proximo` | Tienes un pago próximo |
| `limite_tarjeta` | Vence un pago de tarjeta |
| `pago_vencido` | Hay un pago sin registrar |
| `protegido_riesgo` | Un gasto protegido necesita atención |
| `flujo_negativo` | Revisa el flujo de la semana |
| `abono_bajo_minimo` | Revisa tus pagos de deuda |
| `partida_100` | Revisa una categoría |
| `partida_80` | Una categoría se acerca a su límite |
| `ingreso_retrasado` | Un ingreso no ha llegado |
| `fondo_bajo` | Revisa tu ahorro |
| `uso_limite` | Revisa el uso de una tarjeta |
| `aportacion_pendiente` | Hay ahorro por confirmar |
| `conciliacion_pendiente` | Falta conciliar el efectivo |
| `salida_libro_representado`, `retiro_bolsa_compartida` | Hay un movimiento por revisar |
| `resumen_lunes` | Tu resumen de la semana está listo |
| `recordatorio_cierre` | Es hora de cerrar la semana |
| `base_80`, `base_90` | Revisa el almacenamiento de GRAVITY |
| (sin sesión o sin señal) | Tienes un aviso de GRAVITY |

    El cuerpo del aviso va **vacío**; el detalle solo está en la app. La pantalla bloqueada y la pulsera ven lo mismo. La prueba del criterio 31 impide, con una revisión automática, que el catálogo tenga dígitos, "$" o más de 40 caracteres, y que ningún archivo del módulo arme un aviso con datos de la base.
43. **Qué viaja por Firebase:** solo `{v, id}` (regla de 4.3). Nunca monto, tipo, libro, persona, cuenta ni comercio. El dispositivo busca el aviso en Supabase con su sesión; si no puede, muestra el texto genérico. **Las bocinas y la IA en la nube nunca reciben nada de esto** (D3, D6).
44. **Dónde se recibe (D4):** *teléfono* (push y locales); *tablet personal* (opcional, apagado por omisión, con su PIN; la sesión cifrada con el PIN hace que sin PIN el texto sea el genérico); *tablet pública de la casa*: **ningún aviso de dinero, nunca** (el servidor ni siquiera le manda); *laptop*: sin push; con la app abierta, la bandeja se actualiza en vivo (Supabase Realtime) y se muestra un aviso de Windows con el mismo texto del catálogo.
45. **Recordatorios locales** (sin servidor, sin costo, funcionan sin señal): vencimientos de deudas de los próximos 14 días según la copia local, resumen del lunes y recordatorio de cierre. Se reprograman al abrir la app, al sincronizar, al cambiar las preferencias y al reiniciar el teléfono (`RECEIVE_BOOT_COMPLETED`). Usan **alarmas inexactas** (ventana de unos minutos): no se pide el permiso de alarmas exactas. **El id de la notificación local es un hash de la `clave` del aviso**, así que si el mismo aviso llega por Firebase y por el recordatorio local, **uno reemplaza al otro** y la persona ve una sola notificación.
46. **Android:** permiso `POST_NOTIFICATIONS` (Android 13 o más) que se pide **al activar los avisos**, con una explicación previa, no al abrir la app; si lo niega, Ajustes › Notificaciones lo explica y abre la configuración del sistema; los avisos siguen en la bandeja y en Hoy. **Cuatro canales** con nombres discretos: *Finanzas · Urgentes* (importancia alta, vibración doble larga), *Finanzas · Avisos* (alta, vibración corta), *Finanzas · Informativos* (por omisión, sin sonido) y *Finanzas · Resumen* (baja). Visibilidad de pantalla bloqueada `PRIVATE` con una versión pública *"GRAVITY · tienes un aviso"* para los equipos que sí la respetan; el título ya es discreto para los que no. Sin Google Play Services, o sin Firebase configurado, solo funcionan los recordatorios locales y la bandeja (la app dice por qué).
47. **Pulsera, nivel 1 (D15):** hereda la notificación del teléfono, así que lleva el mismo título corto y vibra con el patrón que su app asigne a las notificaciones de GRAVITY. **No se promete botón ni patrón de vibración propio** (a verificar con el modelo exacto). Ajustes › Notificaciones trae una guía corta para permitir las notificaciones de GRAVITY en la app de la pulsera y un botón *Enviarme un aviso de prueba* con el texto genérico. La opción `pulsera_texto_corto` mantiene el título ≤ 40 caracteres y el cuerpo vacío (hoy no hay otra variante).
48. **Preferencias por persona** (`avisos_preferencias`): tipos activos, días antes, horas silenciosas, críticas en silencio, tope diario, hora de los vencimientos, resumen del lunes y recordatorio de cierre. Cada quien las suyas; la cuenta maestra no tiene. **Retención:** los avisos de más de 90 días se borran; la bandeja guarda lo último.
49. **Límites:** una persona no puede provocar más de 60 emisiones al día; la Edge Function no envía más de 200 avisos por corrida; la bitácora **no** recibe una entrada por aviso (solo las ya existentes de la Fase 1b), para no engordar la base.

### 5.6 "Hoy" con cifras reales

50. **Herramienta `finanzas.resumen_semana`** (solo local, D3): calcula en el dispositivo, con la copia local y sin señal, el `ResumenFinanzasSemana` que ya espera GRAVITY (`resumen_gravity.dart`), **por libro**: semáforo del remanente y su porcentaje, ingreso, presupuesto, deuda y remanente planeados contra reales, lo que vence esta semana (conteo y el próximo día hábil), semanas de fondo cubiertas y las alertas críticas abiertas. Un libro por renglón (*Mi libro*, los compartidos, el de papá con la marca *Albacea*).
51. **Filtrado por rol** (`vistaResumen` + `fin_puede`): Dueño y Pareja ven sus libros y los compartidos de los que son miembros; el albacea ve además el de papá (el suplente sin albacea vigente, también); **la cuenta maestra no ve cifras en Hoy** (solo cuántos libros hay y el aviso *"Abre un libro para consultarlo"*, porque leer lo ajeno exige la consulta registrada); familiar, cuidador y Casa ven **nada** de Finanzas, ni en Hoy ni en la tablet pública. Los montos respetan el modo oculto y la marca *Montos ocultos · Toca para ver* (regla 66 de la Fase 1). **El resumen financiero nunca se lee en voz alta ni va a bocinas** (D3, D6): las órdenes sobre Finanzas se responden en pantalla.

### 5.7 Consulta registrada de la cuenta maestra en el historial de GRAVITY

52. **No aplica todavía.** El historial de GRAVITY (D18: "cada quien solo lo suyo; la cuenta maestra ve todo") se construye en la **Fase 6**; hoy no existe ninguna tabla que consultar. Lo que sí queda definido ahora para no rehacerlo: cuando exista, leer el historial de otra persona exigirá **la misma consulta registrada** (acción `gravity.consulta_maestra`, vigencia de 30 minutos, renovación por la app cada 25, entrada en la bitácora y filtrado silencioso sin ella), generalizando `fin_registrar_consulta_maestra(libro_id)` en una función por módulo. **Propuesta de interpretación:** se deja como requisito de la Fase 6 (pregunta P12) y esta fase solo entrega el aviso de privacidad ya existente en *Ajustes › Privacidad*. Lo que **sí** queda de Finanzas para la siguiente ronda es la limitación de consultas repetidas de la maestra (propuesta del README del servidor: no repetir la entrada si ya hay una de esa persona y ese libro en el último minuto), que se aprueba aparte.

---

## 6. Pantallas

Siguen `DISENO_UX_UI.md` (sección 8 en la laptop, sección 9 en el teléfono) y las de la Fase 1: **libro activo** en el selector, estados vacío, cargando, sin conexión y error, montos ocultables, letra al 200 % sin desbordes, sin reintentos automáticos. La personalidad de Finanzas sigue siendo "precisa y serena". Los gadgets nuevos los entrega diseno (sección 8).

### 6.1 Laptop

| Pantalla | Contenido | Acción principal |
|---|---|---|
| **Deudas** (nueva; sustituye la parte de deudas de *Compromisos y deudas*) | Resumen: deuda total, **costo estimado de deber por semana**, carga de deuda con semáforo, uso del límite total. Pestañas *Tarjetas*, *Préstamos y créditos*, *MSI* y *Familiares*. Cada deuda: acreedor, saldo (del libro), tasa, interés mensual estimado, próximo pago con día hábil ajustado, progreso. **Detalle de tarjeta:** límite usado con barra y semáforo, corte, fecha límite, mínimo, pago sin intereses del último estado de cuenta, sus MSI y sus estados de cuenta | Registrar pago |
| **Orden de pago** (dentro de Deudas) | Lista ordenada con el **motivo de cada lugar** (manual, grupo, tasa, familiar, MSI sin extra), prioridad manual y grupo prioritario (subir y bajar, como en la Fase 1), comparación de ahorro frente a otros órdenes, y el cuadro *"¿Y si abono $X extra por semana?"* con la semana libre de deuda | Fijar prioridad |
| **Calendario de vencimientos** (Deudas y Tablero) | Cortes, fechas límite y mensualidades de MSI de 4 a 8 semanas junto al flujo, con el total de MSI por mes | — |
| **Nueva deuda / Nuevo MSI** | Formularios con la clase, los datos de la regla 1 y la regla de día inhábil; el MSI crea su cuenta pasivo; *Importar ficha…* abre el selector de archivos | Guardar |
| **Registrar pago** (hoja) | *Capital*, *Intereses* y *Cargos*; cuenta de origen; fecha; motivo cuando el libro es el de papá; muestra el mínimo y el pago sin intereses vigente; aviso rojo si queda bajo el mínimo | Guardar con *Guardado · Deshacer* |
| **Estado de cuenta** (hoja) | Captura manual de la regla 9; casilla *Registrar los intereses y cargos como gasto financiero* | Guardar |
| **Ahorro** (nueva) | Tablero de bolsas con barra de progreso y **"tienes X semanas cubiertas"**; el **fondo por niveles** como escalera de 5 peldaños con el actual marcado, la meta elegida, la sugerencia del nivel 4 y el semáforo; plan de la semana con el reparto y sus pendientes; historial de aportaciones y retiros | Confirmar reparto |
| **Nueva bolsa de ahorro** (asistente) | Propósito → tipo (fondo, reserva, meta) → métodos → parámetros → **proyección** (*"llegarás a $X el día Y"*) → activar; para el fondo: nivel, casilla de dependientes con cuidados y lo que cubre en semanas | Activar |
| **¿Y si…?** | Acelerar una meta con su costo (qué retrasa y cuánto colchón baja) | Aplicar |
| **Retiro** (hoja) | Tres tipos; motivo obligatorio (3 caracteres visibles); muestra cómo se repondrá el fondo | Retirar |
| **Revisión semanal** (cambia) | El paso *Aplicar remanente* ahora muestra el reparto por bolsa (confirmar, posponer, omitir) | Cerrar semana |
| **Tablero** (cambia) | Suma los 4 indicadores nuevos (regla 31), las alertas críticas abiertas con su acción y el próximo vencimiento | Registrar movimiento |
| **Bandeja de avisos** | Lista con nivel (texto + icono), tipo, libro y fecha; al tocar muestra **el detalle con montos** (ocultos hasta mostrarlos), la acción y *Posponer* / *Silenciar este tipo* / *Hecho* | Ejecutar la acción |
| **Ajustes › Notificaciones** (Plataforma lo hospeda; Finanzas trae su sección) | Interruptores por tipo agrupados como en 5.4 con su nivel, **días antes**, **horas silenciosas**, críticas en silencio, tope diario, hora de vencimientos, resumen del lunes y cierre; **vista previa** de cómo se verá en la pantalla bloqueada y en la pulsera; estado del permiso de Android, de Firebase y de los dispositivos que reciben; *Enviarme un aviso de prueba*; guía de la pulsera | Guardar |
| **Ajustes › Copias de seguridad** (cambia) | Porcentaje usado de la base, tablas más grandes, estado de la limpieza | — |

### 6.2 Teléfono y tablet personal

| Rol | Pantalla | Contenido |
|---|---|---|
| Dueño, Pareja, albacea | **Finanzas › Pagos** (nueva, solo lectura) | Próximos pagos ordenados por fecha con día hábil ajustado, uso del límite por tarjeta y las mensualidades de MSI del mes; **sin** formularios de deuda (D4) |
| Dueño, Pareja, albacea | **Finanzas › Ahorro** (nueva, solo lectura) | Bolsas con barra de progreso, semanas cubiertas y semáforo del fondo, y el reparto confirmado de la semana |
| Dueño, Pareja, albacea | **Bandeja de avisos** | Igual que en la laptop; las acciones abren la hoja de registro |
| Dueño, Pareja, albacea | **Registrar pago** (hoja corta, desde el aviso o desde Pagos) | Monto precargado con el abono planeado, cuenta de origen (la última usada), fecha; capital solamente (intereses y cargos en la laptop). Mismo aviso *Guardado · Deshacer* y misma cola sin conexión; menos de 10 s |
| Dueño, Pareja | **Hoy** (GRAVITY) | Tarjeta de Finanzas con el resumen por libro (regla 50) y las alertas críticas abiertas |
| Dueño, Pareja | **Ajustes › Notificaciones** | Permiso de Android, horas silenciosas, tope, tipos silenciados y *Aviso de prueba* (el resto de las preferencias se edita también aquí, por ser quien recibe) |
| Cuenta maestra | Portada de libros; sin avisos de dinero, sin Hoy con cifras | Igual que en la Fase 1 |
| Familiar, cuidador, Casa | Nada de Finanzas | — |

Las pantallas de Deudas, Ahorro (configuración), Orden de pago, asistentes, estados de cuenta y la importación de la ficha **no existen en el teléfono**: abrirlas regresa al inicio del módulo (D4).

### 6.3 Notificación de ejemplo (lo que ve cada superficie)

| Superficie | Qué ve |
|---|---|
| Pantalla bloqueada del teléfono | *"Tienes un pago próximo"* · sin cuerpo · canal *Finanzas · Urgentes* |
| Pulsera | *"Tienes un pago próximo"* y vibración; sin botones |
| Al tocar el aviso (con el teléfono desbloqueado) | La bandeja con *Pago de deuda · tarjeta X · vence el jueves 12/nov · $… (oculto)* y *Registrar pago* |
| Firebase / Google | `{"v":"1","id":"<uuid>"}` |
| Bocinas / IA en la nube | Nada |

---

## 7. Criterios de aceptación

Las pruebas del dominio van en `paquetes/finanzas_dominio/test/` (`dart test`); las de la app, en `app/test/modulos/finanzas/` (`flutter test`); las SQL, en `supabase/tests/` con el siguiente número libre. Los ejemplos numéricos son los del diseño; donde el diseño es **ilustrativo** (tarjetas de 5.3) o cuenta las semanas de otro modo (A1 y A2 de 5.5 bis, ver observación 4 de la sección 10), la prueba fija lo que se indica.

| # | Criterio (prueba del diseño) | Cómo se comprueba |
|---|---|---|
| 1 | **Fase 1 intacta:** los 236 + 1494 + 1597 de la Fase 1 siguen en verde; `fin_deudas` conserva sus filas con su `clase` rellenada | Suites existentes + prueba SQL de la migración |
| 2 | **Clases de deuda:** una `msi` exige `tipo = msi`; una `familiar`, `tipo = familiar`; tarjeta, préstamo y crédito exigen `con_costo` con tasa; la tasa de una `msi` o `familiar` es cero | `deudas_test.dart` + prueba SQL |
| 3 | **5.3, mínimos primero:** el extra no se aplica hasta cubrir los mínimos de todas las deudas | `deudas_test.dart` |
| 4 | **5.3, orden por costo:** tarjetas A ($20,000 al 45 %), B ($5,000 al 60 %), C ($12,000 al 38 %) y D ($8,000 al 30 %) → extra en el orden **B, A, C, D**; con prioridad manual en D, D primero; un préstamo familiar al final; un MSI nunca; con grupo prioritario manda el grupo (Fase 1) | `deudas_test.dart` |
| 5 | **Costo de deber:** con esas cuatro tarjetas, interés semanal estimado de $364.62 (suma exacta 18,960 ÷ 52) y los renglones suman exacto (R2); intereses mensuales de referencia $750, $250, $380 y $200 | `deudas_test.dart` |
| 6 | **Uso del límite:** límite $30,000 y saldo $8,999 → verde (29.997 %); saldo $9,000 → ámbar (30 %); con $6,000 de MSI pendiente sobre $9,000 → 50 %, ámbar; sobre 60 % → rojo; sin límite → no calcula y lo dice | `deudas_test.dart` |
| 7 | **5.3 bis-4, MSI:** un MSI no recibe extra, aparece en el calendario y su mensualidad suma a la carga de deuda; $6,000 a 12 meses = $500; $1,000 a 3 meses = $333.33 + $333.33 + $333.34 | `deudas_test.dart`, `presupuesto_test.dart` |
| 8 | **MSI en el libro:** la compra sube el pasivo propio del MSI por el total; cada mensualidad lo baja; el saldo pendiente sale del libro y no se guarda; las pagadas y restantes salen de las ocurrencias | `deudas_test.dart` + pantalla Deudas |
| 9 | **5.3, pago con capital e intereses:** capital en un `pago_deuda` e intereses y cargos en `gasto` financiero con el mismo `grupo_id`; el capital baja el pasivo y los intereses suben el gasto; el cuadre sigue en cero | `libro_test.dart` + `deudas_test.dart` |
| 10 | **5.3, abono bajo el mínimo:** un pago menor al mínimo deja la ocurrencia `parcial`, la alerta roja y el aviso crítico `abono_bajo_minimo` | `deudas_test.dart` + prueba de widget |
| 11 | **Sin inventar datos:** sin estado de cuenta vigente la pantalla no muestra "pago sin intereses" y pide capturarlo; sin tasa una deuda con costo no se guarda; el crédito sin `permite_pago_anticipado` no recibe extra y dice qué verificar | `deudas_test.dart`, `pantallas_deudas_test.dart` |
| 12 | **Estado de cuenta solo agregar:** nadie edita ni borra; el último registro de un corte es el vigente; una tasa distinta pide confirmación y no cambia sola | Pruebas SQL + `deudas_test.dart` |
| 13 | **Importar la ficha:** una ficha ficticia produce tarjetas, crédito automotriz y MSI en la vista previa; reimportar no duplica; el archivo hostil se rechaza con las protecciones de la Fase 1; ninguna prueba abre `data/personal/` | `importar_ficha_test.dart` |
| 14 | **¿Y si abono $X extra?** con la proyección de la Fase 1 adelanta la semana libre de deuda y baja los intereses estimados, rotulado *ilustrativo* | `proyeccion_deuda_test.dart` (ampliada) + widget |
| 15 | **5.5 bis, A5 y A6, aportaciones:** reserva de $5,200 al año = $100 por semana; regreso a clases de $7,800 = $150; meta de $9,000 con $1,500 en 30 semanas = $250; en 12 semanas = $625 | `ahorro_test.dart` |
| 16 | **Fondo por niveles:** con $3,500 de esenciales las metas son $7,000, $14,000, $45,500, $91,000 y $182,000; saldo de $10,500 = *3.0 semanas cubiertas* | `ahorro_test.dart` |
| 17 | **Semáforo del fondo:** meta de 3 meses ($45,500): $45,500 verde; $22,750 (50 %) ámbar; $22,749 rojo | `ahorro_test.dart` |
| 18 | **Gasto esencial:** promedio de las últimas 8 semanas cerradas de partidas protegidas y categorías `necesario` (más mínimos de deuda si la casilla está activa); con 3 semanas usa 3; sin ninguna usa el plan y dice *"según tu plan"*; sin plan no inventa | `ahorro_test.dart` |
| 19 | **Nivel 4 sugerido:** un solo ingreso, ingreso `probable`/`incierta` como único sustento, o `dependientes_cuidados` activa → se sugiere sin imponerlo | `ahorro_test.dart` |
| 20 | **5.5 bis, A1:** remanente $1,520, esenciales $3,500, colchón de $7,000, reservas $250, celular $9,000 en 30 semanas con $1,500, fondo de $45,500 → colchón completo en la semana 5 de ahorro, celular en la 34 y fondo en la 41; en la semana 17 el fondo vale $19,340 | `ahorro_test.dart` (ver observación 4) |
| 21 | **5.5 bis, A2:** pedir el celular en 12 semanas aporta $625 y el fondo se completa en la **misma** semana 41, con menos colchón en el camino ($15,090 en la semana 17); el plan muestra qué retrasa | `ahorro_test.dart` (ver observación 4) |
| 22 | **5.5 bis, A3:** con un remanente menor al sugerido se recorta de abajo hacia arriba (metas sin fecha primero, colchón al final) y lo no aportado queda como pendiente sin castigo | `ahorro_test.dart` |
| 23 | **5.5 bis, A7 y regla 16:** con una deuda con costo en el orden de abono extra no se proponen aportaciones nuevas (todo a deuda); con solo MSI sí; con grupo prioritario pagado sí; el ahorro mínimo con deuda va primero al colchón; aportar a mano se permite con el costo a la vista | `ahorro_test.dart`, `grupo_prioritario_test.dart` |
| 24 | **Métodos:** reto de 52 semanas con base $10: $10, …, $520 y suma $13,780, la semana sin remanente queda *pospuesta*; redondeo de $47, $123.50 y $80 a múltiplos de $10 = $3 + $6.50 + $0 = $9.50; sobrante, sobre por categoría y extras se descuentan de la aportación sugerida; págate primero apagado con deuda | `ahorro_test.dart` |
| 25 | **Confirmación semanal:** confirmar crea la `transferencia` con id derivado; confirmar dos veces no duplica; posponer no mueve dinero; el pendiente de la bolsa no genera intereses | `ahorro_test.dart`, `casos_de_uso_ahorro_test.dart` |
| 26 | **5.5 bis, A4, retiro de emergencia:** exige motivo de 3 caracteres visibles, deja el retiro en `fin_retiros_ahorro` y la bitácora y recalcula la reposición (el fondo pasa a ser lo primero hasta recuperar el saldo previo); no cambia el patrimonio | `ahorro_test.dart` + prueba SQL |
| 27 | **Bolsas en libros compartidos y de papá:** cualquier miembro retira de una bolsa compartida y los otros reciben el aviso `retiro_bolsa_compartida`; en el libro de papá todo va en su nombre y con motivo | `casos_de_uso_ahorro_test.dart` + prueba SQL |
| 28 | **RLS de deudas y ahorro:** la pareja no ve las deudas, bolsas ni estados de cuenta del libro personal del dueño; la maestra lee solo con consulta y no escribe; el suplente sin albacea vigente escribe; familiar, cuidador y Casa no ven nada; las tablas solo agregar rechazan UPDATE y DELETE | Pruebas SQL |
| 29 | **Indicadores nuevos:** semanas cubiertas, uso del límite, costo de deber y semana libre de deuda salen en el Tablero con semáforo, texto o icono y montos ocultables | Pruebas de widget |
| 30 | **Cuadre intacto:** aportar y retirar de una bolsa del mismo libro no cambian el patrimonio ni el resultado; el cuadre por libro de la Fase 1 sigue en cero | `cuadre_entre_libros_test.dart` (ampliada) |
| 31 | **D3, catálogo discreto:** ningún texto de `TextoAviso` tiene dígitos, "$" ni más de 40 caracteres; no hay nombres de cuentas, tarjetas, deudas, comercios ni personas; ningún archivo del módulo arma un aviso con datos de la base ni lo manda a un servicio | `avisos_discretos_test.dart` |
| 32 | **D3, nada por Firebase:** el cuerpo enviado por la Edge Function es exactamente `{v, id}` con prioridad alta; no lleva tipo, libro, persona ni texto; la tabla `avisos` no tiene columnas de monto, nombre ni texto libre | Prueba de la Edge Function (Deno) + prueba SQL del esquema |
| 33 | **D3, herramientas y voz:** `finanzas.resumen_semana`, `finanzas.proximos_pagos` y `finanzas.ahorro_avance` son `soloLocal`; ningún aviso ni resumen de dinero llega a las bocinas o a la IA en la nube | Prueba del registro de herramientas (como el criterio 30 de la Fase 1) |
| 34 | **Vencimientos, días antes:** un pago el jueves 12/nov/2026 genera avisos el lunes 9/nov y el miércoles 11/nov a las 9:00; si la deuda se da de alta el 11/nov solo se crea el del 11; no se envía una avalancha de atrasados | `alertas_test.dart` + `83_avisos_generacion.sql` |
| 35 | **Pago vencido:** un pago `esperada` pasado su día pasa a `retrasada` y genera un aviso crítico al día siguiente y otro a los 3 días; luego se calla; registrar el pago cancela los pendientes | `alertas_test.dart` + prueba SQL |
| 36 | **Idempotencia:** correr `avisos_generar_vencimientos()` dos veces no duplica; cambiar la fecha de la ocurrencia cancela los avisos viejos y crea los nuevos; la misma `clave` no se inserta dos veces | Prueba SQL |
| 37 | **Horas silenciosas:** un aviso crítico programado a las 23:00 sale a las 07:00; con `criticas_en_silencio` sale a su hora; los no críticos nunca suenan de noche | `alertas_test.dart` + prueba SQL |
| 38 | **Tope diario:** con 4 avisos no críticos el mismo día salen 3 y el cuarto queda `agrupada` y visible en la bandeja; las críticas y los recordatorios fijos no cuentan; el día se mide en la zona de la persona | `alertas_test.dart` + prueba SQL |
| 39 | **Destinatarios:** libro compartido → todos los miembros vigentes; personal → el titular; papá → el albacea (o el suplente sin albacea vigente); **nunca** la maestra, familiar, cuidador ni Casa; nadie elige destinatarios desde la app | Prueba SQL |
| 40 | **Aviso al suplente:** una salida del libro de papá a otro libro avisa al suplente vigente (y no a quien la hizo); sin suplente vigente no pasa nada; la entrada de bitácora de la Fase 1b sigue igual | Prueba SQL (amplía `21_finanzas_albacea.sql`) |
| 41 | **Alertas desde la app:** partida al 80 y 100 %, flujo negativo, protegido en riesgo y fondo bajo se evalúan con el motor al registrar, cerrar y sincronizar y llegan por `fin_emitir_aviso`; un tipo no emitible o más de 60 al día se rechaza | `alertas_test.dart`, `avisos_finanzas_test.dart` + prueba SQL |
| 42 | **Dispositivos y tokens:** `registrar_dispositivo` reasigna el token a la persona actual (M13); una tablet pública nunca recibe avisos de dinero; la tablet personal está apagada por omisión; un token inválido se borra | Prueba SQL + `avisos_finanzas_test.dart` |
| 43 | **Recordatorios locales:** sin señal se programan los vencimientos de 14 días, el resumen del lunes y el cierre; se reprograman al reiniciar y al cambiar las preferencias; la misma `clave` en el push y en el local muestra una sola notificación | `avisos_finanzas_test.dart` (con un programador falso) + medición manual en el A52 |
| 44 | **Android:** el permiso de notificaciones se pide al activar los avisos y no al abrir; si se niega, Ajustes lo explica y la bandeja sigue; los 4 canales existen con importancia y vibración correctas; sin Firebase configurado la app funciona con locales | `avisos_finanzas_test.dart` + prueba de plataforma + medición manual |
| 45 | **Pulsera:** en el A52 con la pulsera real, el aviso de prueba llega con el título corto, sin cuerpo y sin montos; se anota el modelo y si vibra (pendiente de D15) | Medición manual (calidad) |
| 46 | **Bandeja:** muestra nivel con texto e icono, el detalle con montos ocultos hasta mostrarlos, y *Posponer 1 hora / hasta mañana*, *Silenciar este tipo* y *Hecho*; una crítica silenciada sigue en la bandeja; toda crítica aparece como banner al abrir la app | Pruebas de widget |
| 47 | **Preferencias:** cada persona edita solo las suyas; rangos inválidos (tope fuera de 0 a 10, horas incoherentes) se rechazan; la maestra no tiene preferencias de dinero | Pruebas SQL + de widget |
| 48 | **Aviso al 80 % de la base:** con la base al 79 % no avisa; al 80 % avisa al dueño (no a la pareja ni a la maestra); al 90 % es crítico; uno al día; con el límite configurado | `84_avisos_base_80.sql` (con tamaño simulado) |
| 49 | **Retención:** `avisos` de más de 90 días y `avisos_entregas` de más de 30 se borran; nada más se borra; la bitácora no crece por cada aviso | Prueba SQL |
| 50 | **Edge Function:** respeta `skip locked` (dos corridas a la vez no duplican), reintenta a los 5, 15 y 60 minutos, no envía a `tablet_publica` ni a dispositivos con `recibe_avisos = false` y, sin el secreto, no envía y no falla la base | Prueba de la Edge Function (Deno) con FCM simulado |
| 51 | **Hoy con cifras reales:** el dueño ve un renglón por libro con semáforo y porcentaje; el albacea ve además el de papá; la pareja no ve el libro personal del dueño; la maestra no ve cifras; familiar, cuidador y Casa no ven nada; funciona sin señal y respeta los montos ocultos | `hoy_finanzas_test.dart` + `finanzas_por_rol_test.dart` (plataforma) |
| 52 | **Hoy sin fugas:** el resumen no pasa por la IA, ni por las bocinas, ni por la tablet pública; la herramienta es `soloLocal` | Prueba del registro de herramientas |
| 53 | **Teléfono, solo lectura:** *Pagos* y *Ahorro* no tienen formularios de deuda ni de configuración; las pantallas de la laptop regresan al inicio; *Registrar pago* funciona sin señal y sin duplicar al reintentar | Pruebas de widget y de la cola |
| 54 | **Registrar pago desde el aviso:** tocar el aviso con el teléfono bloqueado pide la huella o el PIN antes de mostrar el detalle; el monto aparece oculto hasta mostrarlo; el pago se registra en menos de 10 s | Prueba de widget (pasos) + medición manual en el A52 |
| 55 | **Letra grande y sin reintentos automáticos** (regla 67 de la Fase 1) en Deudas, Ahorro, Bandeja y Notificaciones, a 360 y 900 dp con letra al 200 % | `revision_fase2_test.dart` |
| 56 | **Consulta de la maestra en el historial de GRAVITY:** documentada como requisito de la Fase 6 (regla 52); esta fase no agrega ninguna tabla para ello | Revisión de la especificación (aprobación del dueño, P12) |
| 57 | **Contrato de columnas:** la app no manda `recibido_en`, `estado`, `enviada_en`, `persona_id` ni destinatarios de un aviso; las tablas solo agregar llevan `registrado_en`; `fin_aportaciones_ahorro.pendiente_centavos` no se manda (es generada) | `contrato_servidor_test.dart` (ampliada) |

---

## 8. Trabajo por agente

| Agente | Entrega | Carpetas |
|---|---|---|
| **finanzas** | **Dominio (Dart puro, con las pruebas de la sección 7):** `deudas.dart` (resumen por deuda, orden de pago con motivos, costo de deber, uso del límite, calendario de vencimientos, MSI), `ahorro.dart` (bolsas, niveles, gasto esencial, semanas cubiertas, reparto con orden y recorte, 8 métodos, retiros y reposición), `alertas.dart` (catálogo, evaluación con el motor, `programarAvisos` con días antes, silencio y tope, destinatarios esperados) y `TextoAviso` con su revisión de discreción. **App:** casos de uso (registrar pago, estado de cuenta, MSI, importar la ficha, armar y confirmar el reparto de ahorro, retiros, emitir avisos, programar locales), repositorios (memoria y Supabase), pantallas de laptop y teléfono de la sección 6, la herramienta `finanzas.resumen_semana` y la conexión al resumen de GRAVITY, Bandeja de avisos y la sección de Finanzas de *Notificaciones*. **Especificación** | `paquetes/finanzas_dominio`, `app/lib/modulos/finanzas`, `docs/specs/fase-2-*` |
| **backend** | Migraciones de 4.1 (cambios a `fin_deudas`, `fin_parametros`, `dispositivos`; tablas `fin_msi`, `fin_estados_cuenta`, `fin_bolsas_ahorro`, `fin_aportaciones_ahorro`, `fin_retiros_ahorro`, `avisos*`), RLS y triggers de 4.2, vistas, funciones de 4.3 (`registrar_dispositivo`, `quitar_dispositivo`, `fin_emitir_aviso`, `avisos_marcar`, `avisos_actualizar_preferencias`, avisos de salida y de retiro compartido, `avisos_generar_vencimientos`, `avisos_revisar_base`), tareas `pg_cron`, **Edge Function `enviar-avisos`** con sus pruebas, retención, datos de ejemplo en `seed.sql` (el hogar ficticio) y pruebas SQL de los criterios 2, 12, 26 a 28, 32, 34 a 42, 47 a 49 y 57. Documenta en `supabase/README.md` los secretos que debe poner el dueño | `supabase/` |
| **plataforma** | `firebase_messaging` y `flutter_local_notifications` (Android; Windows solo toast con la app abierta), permiso `POST_NOTIFICATIONS` pedido al activar los avisos, **4 canales discretos**, registro y baja del token con `registrar_dispositivo`/`quitar_dispositivo` (al entrar, salir, quitar de la tablet y baja), manejador de datos en segundo plano que busca el aviso y arma el texto del catálogo (o el genérico), identificador local derivado de la `clave`, recordatorios locales con alarmas inexactas y reprogramación al reiniciar, abrir el aviso con PIN o huella, suscripción en vivo de la bandeja en la laptop, **Ajustes › Notificaciones** (permiso, preferencias por persona, vista previa, aviso de prueba, guía de la pulsera) y Ajustes › Copias de seguridad con el porcentaje de la base, ruta `/finanzas/avisos/:id`, el proveedor de "Hoy" y las rutas por rol | `app/lib/app`, `app/lib/nucleo`, `app/lib/modulos/ajustes`, `app/pubspec.yaml`, `app/android` |
| **diseno** | Gadgets nuevos: **Escalera del fondo** (5 niveles con el actual y la meta), **Barra de límite** (uso con semáforo y marcas de 30 y 60 %), **Tarjeta de deuda** (acreedor, saldo, tasa, próximo pago), **Línea de vencimientos** (calendario de 4 a 8 semanas con MSI por mes), **Bolsa de ahorro** (progreso y pendiente), **Orden de pago** (lista con el motivo de cada lugar), **Chip de nivel de alerta** (texto + icono) y **Vista previa de aviso** (pantalla bloqueada y pulsera); maquetas de Deudas, Ahorro, Bandeja y Notificaciones; estados vacío, cargando, sin conexión y error | `app/lib/diseno`, `app/assets` |
| **asistente** (apoyo) | Herramientas `finanzas.proximos_pagos` y `finanzas.ahorro_avance` (`soloLocal`; respuesta a la pantalla, nunca a voz ni a la IA), órdenes *"qué vence esta semana"* y *"abre deudas / ahorro / avisos"*, y las operaciones nuevas (RPC y tablas) en `api/openapi.yaml` | `app/lib/nucleo/herramientas`, `api/` |
| **calidad** | Revisión de cierre: D3 en los avisos y en Firebase, RLS, discreción en pantalla bloqueada y pulsera, medición en el A52 con la pulsera real, accesibilidad y letra grande | `docs/revisiones/` |

**Orden sugerido:** (1) dominio y especificación aprobada; (2) migraciones y RLS; (3) pantallas de Deudas y Ahorro sobre la base local; (4) infraestructura de avisos (servidor, Edge Function, plataforma); (5) alertas y "Hoy"; (6) calidad. Lo que depende del dueño (proyecto de Firebase, cuenta de servicio, la pulsera) **no bloquea**: sin él todo funciona con recordatorios locales y bandeja.

---

## 9. Preguntas para el dueño

Cada pregunta trae la **propuesta por defecto** con la que se construye si no hay respuesta. Ninguna bloquea programar.

### 9.1 Avisos y alertas

| # | Pregunta | Propuesta por defecto |
|---|---|---|
| **P1** | ¿Cuántos días antes avisamos de un pago de deuda o del límite de una tarjeta? | **3 días y 1 día antes**, a las 9:00 (como el diseño), más el aviso del día siguiente si no se registró. Cada quien lo cambia en *Notificaciones*. ¿Quieres también un aviso el mismo día? |
| **P2** | ¿Cuál es tu horario sin molestar? | **22:00 a 07:00**, igual que el diseño y la sección 17 de `DISENO_UX_UI.md` |
| **P3** | ¿Qué cuenta como "alerta crítica"? | Las que **cuestan dinero si no se atienden**: pago de deuda, límite de tarjeta, pago vencido, gasto protegido en riesgo, flujo negativo y abono bajo el mínimo (y la base al 90 %). Importantes: partida al 100 %, ingreso retrasado, fondo bajo, salida del libro de papá y base al 80 %. Informativas: el resto |
| **P4** | ¿Las críticas deben sonar **también en las horas silenciosas**? (Medicamentos sí lo harán en Cuidados; el dinero no es una urgencia de salud.) | **No**: esperan a las 07:00 y aparecen al abrir la app. Con el margen de 3 y 1 días no se pierde nada. Se puede activar por persona |
| **P5** | ¿Cuántos avisos no críticos al día? | **3**; el resto se agrupa en la bandeja y en el resumen |
| **P6** | ¿Avisamos también de pagos fijos (renta, servicios, seguros)? El diseño solo trae deudas, tarjetas y sobres de previsión (que son de la Fase 8) | **No en la Fase 2**; sí en Hoy ("esta semana vence"). Si los quieres con aviso, se agrega como tipo *importante*, 1 día antes, apagado por omisión |
| **P7** | Retiro de una bolsa **compartida**: el diseño pide la confirmación de los demás titulares, que es de la Fase 8. ¿Basta con avisarles? | **Sí**: cualquier miembro retira y los demás reciben el aviso informativo; las confirmaciones llegan en la Fase 8 |
| **P8** | ¿Las compras a MSI **ocupan el límite** de la tarjeta? (5.3 bis: "verificar con cada emisor") | **Sí** por omisión, con una casilla por tarjeta para cambiarlo |
| **P9** | El **gasto esencial** del fondo, ¿incluye los **pagos mínimos de deuda**? Y, con menos de 8 semanas de historial, ¿usamos el plan? | **Sí** incluye los mínimos (si no, el colchón quedaría corto mientras debes); con poca historia usa las semanas que haya y, sin ninguna, el plan rotulado *"según tu plan"* |
| **P10** | Intereses y cargos que **el banco suma al corte**, ¿los registramos al capturar el estado de cuenta (como gasto financiero desde la tarjeta) y el pago entero como capital? | **Sí**: así el saldo de la tarjeta coincide con el del estado de cuenta |
| **P11** | **Tablet personal:** ¿recibe avisos de dinero? **Laptop:** ¿avisos de Windows con la app abierta? | Tablet personal **apagada** por omisión (se prende por equipo); laptop **sí** con la app abierta, sin push cerrada. La tablet pública, **nunca** |
| **P12** | **Consulta de la cuenta maestra en el historial de GRAVITY:** no hay historial todavía (Fase 6). ¿Lo dejamos como requisito de esa fase con la misma regla (30 minutos, bitácora, filtrado silencioso)? | **Sí**, en la Fase 6. Hoy no se construye nada. ¿Y quieres limitar las consultas repetidas de la maestra (una entrada por minuto y libro)? Propuesta: **sí** |
| **P13** | La infraestructura de avisos (`avisos*`, `dispositivos`, Edge Function) la usarán Hábitos y Cuidados. ¿Aprobamos nombrarla **sin** el prefijo `fin_` y registrarla como **D20**? | **Sí**, con el catálogo cerrado de textos y la regla "sin montos ni nombres" como parte de D20 |
| **P14** | **Cupo de la base:** ¿qué cupo tiene tu proyecto de Supabase? Se usa 500 MB (plan gratuito). ¿Avisamos al 80 % y al 90 %? | **500 MB; 80 % importante y 90 % crítico**, solo al dueño. Ajustable en `avisos_sistema` |
| **P15** | Montos del **redondeo** y del **reto de 52 semanas** | Múltiplo de $10 hacia arriba; la base del reto la elige la persona |
| **P16** | ¿Importamos de la ficha también las hojas de beneficios y estados de cuenta? | **No en esta fase** (los beneficios necesitan fuente verificada y son de la Fase 8+); los estados de cuenta se capturan a mano |

### 9.2 Datos y cuentas para usarla (no bloquean)

1. **Proyecto de Firebase** con una app Android y la **cuenta de servicio** (la pone el dueño en los secretos de Supabase; nada de eso va al repositorio). Sin ella, solo recordatorios locales y bandeja.
2. **Tu ficha de deudas y tarjetas** (`data/personal/FICHA_DEUDAS_Y_TARJETAS.xlsx`, ignorada por git): tarjetas con límite, corte, fecha límite, mínimo y tasa; el crédito automotriz (¿permite pago anticipado a capital?); y las compras actuales a MSI (pendientes 8 y 12).
3. **La pulsera:** marca y modelo exactos (D15) y confirmar en tu teléfono que su app permite notificaciones de GRAVITY. Hasta entonces, el aviso de prueba sirve para comprobarlo.
4. **El gasto esencial real:** se aprende solo con ocho semanas cerradas; mientras tanto se usa el presupuesto que armaste.

---

## 10. Observaciones sobre el diseño y la Fase 1 (para corregir en FINANZAS)

1. **Notificaciones "discretas" y Firebase:** el diseño (5.9 bis, punto 7, regla 5) habla de la pantalla bloqueada, pero no de lo que ve Google al entregar el aviso. Esta especificación manda solo un identificador opaco y arma el texto en el dispositivo (reglas 42 y 43); conviene registrarlo como parte de D20.
2. **Recordatorios locales y push a la vez:** el diseño los presenta como canales distintos; aquí cubren lo mismo y se deduplican por la `clave` (regla 45).
3. **5.9 bis, punto 6, "Fondo de emergencia bajo — al bajar de la meta":** literalmente avisaría cada semana mientras el fondo se llena. Se interpretó como "al caer a rojo o bajar de un nivel ya alcanzado, una vez por semana" (regla 32).
4. **5.5 bis, A1 y A2:** la tabla del diseño cuenta *semanas de ahorro* con un desfase de una semana en el celular de A2 (12 semanas de $625 desde la semana 5 terminan en la 16, no en la 17) y el saldo del fondo en la semana 17 ($15,090) depende de cómo se reparte la semana en que se completa el colchón. La prueba reproduce los hitos de A1 (semana 5, 34 y 41; $19,340) y, para A2, fija el criterio "el fondo se completa en la misma semana" y documenta la diferencia de una semana si el motor la tiene.
5. **5.5 bis frente a la regla 54 de la Fase 1:** el diseño dice que el ahorro empieza cuando ya no hay deuda con costo; el dueño (P12 y P19) pidió que, al pagarse el **grupo prioritario**, el dinero pase a ahorro aunque queden deudas fuera del grupo. Manda la respuesta del dueño (regla 16).
6. **5.3, "Cada pago registrado actualiza saldo (capital vs. interés)":** requiere decidir quién registra los intereses que el banco suma al corte; se resolvió en la regla 4 y la P10.
7. **La función de aviso de la Fase 1b (N3)** deja la entrada en la bitácora pero el aviso "con notificación" quedó para esta fase (`supabase/README.md`); aquí se agrega dentro de la misma función (4.3).
8. **El tamaño de la base** crece con la bitácora, que es solo agregar; esta fase no la limpia (D17). La retención de 90 días aplica solo a `avisos`.

---

## 11. Lo que necesita el dueño del proyecto

1. **Aprobar** esta especificación (o marcar cambios) y contestar la sección 9; mientras tanto se construye con las propuestas por defecto.
2. **Crear el proyecto de Firebase** y la cuenta de servicio, y ponerla en los secretos de Supabase (se explica en `supabase/README.md` cuando backend la entregue). Sin esto la app avisa con recordatorios locales y bandeja.
3. **Llenar la ficha de deudas y tarjetas** y confirmar los datos de la pulsera (9.2).
4. Para la medición final: un Galaxy A52 con la pulsera enlazada (criterios 43 a 45 y 54).

## 11. Estado de la implementación (finanzas, 1/nov/2026)

- **Dominio (`paquetes/finanzas_dominio`)**: deudas a detalle (`deudas_detalle.dart`), ahorro y fondo (`ahorro.dart`, `ahorro_datos.dart`) y alertas y avisos discretos (`alertas.dart`) con pruebas (`deudas_test`, `ahorro_test`, `alertas_test`, `avisos_discretos_test`). `Deuda` y `ParametrosFinanzas` traen los campos nuevos de las migraciones de backend.
- **App**: repositorios (memoria y Supabase) y `ServicioDeudasAhorro` (`servicio_fase2.dart`); pantallas Deudas, Ahorro y fondo y Vencimientos (laptop y teléfono), hoja corta de pago, formularios (estado de cuenta, MSI, tasa, bolsa, aportación, retiro), importador de la ficha (`lector_ficha.dart`, con ficha ficticia en las pruebas), detalle de avisos para la bandeja, fuente de vencimientos para los recordatorios locales y consultas locales de las herramientas `finanzas.resumen_semana`, `finanzas.proximos_pagos` y `finanzas.ahorro_avance`.
- **Decisiones de implementación (para aprobar)**: (a) los estados de cuenta, aportaciones y retiros **necesitan señal** (el servidor liga cada uno a su movimiento; no van por la cola sin conexión); (b) el gasto esencial sale "según tu plan" hasta que el cierre guarde la marca de esencial por partida; (c) del ahorro, la app propone con montoFijo, reto de 52 semanas y los montos de reserva, meta con fecha y fondo; redondeo, sobrante, sobre y porcentaje de extras están en el dominio y se conectan al cierre en la siguiente ronda; (d) las columnas de la ficha se leen por posición según el encabezado de la ficha de ejemplo; una celda `0.18` sin "%" se toma como 18 %.
- **Pendiente**: simulación semana a semana de los ejemplos A1/A2 (criterios 20 a 24), proyección "¿y si abono $X extra?" en pantalla (criterio 14), preferencias de avisos en Ajustes › Notificaciones (la hospeda plataforma), el aviso emitido por la app (`fin_emitir_aviso`) y el conector de `consultaLocal` en la barra de órdenes.

---

## Aprobación del dueño (31/oct/2026)

El dueño aprobó las propuestas por defecto de la sección 9 (P1 a P16), la infraestructura de avisos como **D20** y que los estados de cuenta, aportaciones y retiros de ahorro pidan señal (sección 11).

**Actualización 1/nov/2026:** la simulación semana a semana de A1/A2 (colchón en la semana 5, celular en la 34 y fondo en la 41) y la proyección "¿y si abono $X extra?" ya están hechas y probadas (criterios 14 y 20 a 24). Siguen pendientes: preferencias de avisos de Finanzas en Ajustes, emitir avisos desde la app con `fin_emitir_aviso`, y conectar redondeo, sobrante, sobre y extras al cierre de semana.
