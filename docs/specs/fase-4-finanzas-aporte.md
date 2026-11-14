# Fase 4 (Pulido 1): aporte de Finanzas

> Aporte del agente finanzas para `docs/specs/fase-4-pulido.md` (lo escribe diseno). Borrador del 6/nov/2026, para aprobación del dueño. Fuentes: ROADMAP sección 7, `fase-1-finanzas.md` (reglas 50, 62, 63; criterios 11, 28; tabla de pantallas), `fase-2-finanzas.md` (sección 11), y `docs/revisiones/fase-1.md`, `fase-1b.md`, `fase-2.md`.
> Alcance: solo lo de Finanzas. El estilo visual y los gadgets son de diseno; los ajustes de plataforma (Ajustes › Personas y › Notificaciones) los hospeda plataforma.

## 1. Meta: registrar un gasto en menos de 10 s (teléfono)

**Flujo exacto** (hoja (+) Gasto, spec fase 1, tabla de pantallas):

| Paso | Qué hace la persona | Toques | Tiempo objetivo |
|---|---|---|---|
| 1 | Desbloquea y abre la app; el (+) está en la pantalla de inicio de Finanzas | 1 (el (+)) | 2,0 s |
| 2 | Teclado numérico ya abierto: escribe el monto (ej. 185,50) | 4 a 6 | 3,0 s |
| 3 | Cuenta: la última usada ya viene marcada; solo la cambia si hace falta | 0 (1 si cambia) | 0,5 s |
| 4 | Categoría opcional: la última o una de las 5 sugeridas; sin tocar queda *Por clasificar* | 0 o 1 | 1,0 s |
| 5 | Guardar (visible sin desplazar la hoja) | 1 | 0,5 s |
| 6 | Aviso *"Guardado · Deshacer"* | 0 | hasta 3,0 s de margen |

Caso base: **2 toques fijos** (el (+) y Guardar) más los dígitos del monto. Caso con cambio de cuenta y categoría: **4 toques fijos** más los dígitos. El monto no cuenta como toque de decisión.

**Criterios medibles**

- **F4-1.1** Con la hoja abierta y la última cuenta usada, el flujo base (monto de 3 a 6 dígitos, sin cambiar cuenta ni categoría) requiere **no más de 2 toques fuera del teclado numérico**. Prueba de widget que cuenta toques (cierra la parte "Parcial" del criterio 28 de fase 1).
- **F4-1.2** Con cambio de cuenta y de categoría, **no más de 4 toques fuera del teclado**.
- **F4-1.3** Guardar queda visible sin desplazar en 360 × 800 dp y en 411 × 850 dp, con letra 1.0 y 1.3 (y con letra 2.0 la fila Cancelar/Guardar no se corta). Esto ya lo cubre `f1_i6` e `f1_i8`; se mantiene como guardia.
- **F4-1.4** **Medición en el Galaxy A52**, modo lanzamiento (`flutter run --release`), app ya instalada, pantalla desbloqueada, app cerrada del todo (no en segundo plano):
  - Cronómetro externo (el de otro teléfono o grabación de pantalla a 60 fps y conteo de cuadros). Inicio: dedo toca el ícono de la app. Fin: aparece el aviso *"Guardado · Deshacer"*.
  - **10 repeticiones** con señal y **10 sin señal** (modo avión), montos distintos, alternando con y sin cambio de cuenta y categoría.
  - Se aprueba si la **mediana es 8 s o menos** y **ninguna repetición pasa de 10 s** en el flujo base; en el flujo con cambios, la mediana es 10 s o menos.
  - Sin señal el aviso debe decir *"Guardado en el teléfono; se sube al volver la señal"* y el tiempo hasta verlo no puede superar al de con señal por más de 0,5 s (guardar es siempre local primero).
  - Se anota en `docs/revisiones/` (calidad) con la tabla de las 20 corridas y el modelo y versión de Android.
- **F4-1.5** Prueba automática de apoyo: `registrar gasto` en la capa de servicio con la base local en memoria tarda **menos de 150 ms** (medido en la laptop); si no, el cuello de botella está en la interfaz y no en el guardado.

## 2. Meta: abrir la app en menos de 2 s

**Qué carga al arranque (en este orden, hasta el primer cuadro útil)**

1. Sesión: leer del almacén seguro la sesión guardada y el rol (sin llamada de red; si hay que renovar el token se hace en segundo plano).
2. Base local: abrir la base y leer **solo** lo que pinta la pantalla de inicio de Finanzas: resumen de la semana en curso (ya calculado por el dominio), semáforo y los **5 movimientos más recientes** del libro activo.
3. Cola sin conexión: solo leer el **conteo** de pendientes para el indicador.

**Qué se difiere (después del primer cuadro)**

- Sincronización con Supabase y subida de la cola.
- Calendario de recordatorios locales (`calcularRecordatorios`) y registro del token de avisos.
- Cálculo de deudas, ahorro, vencimientos y alertas (se calculan al entrar en esas pantallas o en una tarea de baja prioridad).
- Lista completa de movimientos, categorías y compromisos (paginados al entrar).
- Resumen de otros libros (compartido, papá) hasta que se pidan o el libro activo cambie.
- Inicialización de Firebase y de cualquier servicio de plataforma que no pinte nada.

**Criterios medibles**

- **F4-2.1** Con un año de datos de prueba (criterio 11 de fase 1: unos 3 000 movimientos, 12 meses de cierres) en el Galaxy A52, modo lanzamiento, app cerrada del todo: desde el toque en el ícono hasta el primer cuadro con la tarjeta de la semana y los 5 movimientos, **mediana de 2,0 s o menos y ninguna corrida sobre 2,5 s** (arranque en frío, 10 corridas, con y sin señal).
- **F4-2.2** Arranque en caliente (app en segundo plano): **1,0 s o menos**.
- **F4-2.3** En la laptop Windows (arranque en frío, año de datos): **2,0 s o menos** hasta ver la pantalla de Finanzas con cifras.
- **F4-2.4** Sin señal el arranque no espera a la red: la diferencia entre con y sin señal es **menor de 0,3 s** (si hay espera por red, es un defecto).
- **F4-2.5** Medición con las marcas de tiempo de `Timeline` o `FlutterTimeline` (inicio del proceso, primer cuadro, pantalla con datos) además del cronómetro externo, para ubicar qué tramo se pasa. Se registra en la revisión de calidad.
- **F4-2.6** Guardia automática: una prueba cuenta que, al arrancar, Finanzas **no** hace consultas de deudas, ahorro, vencimientos ni de libros distintos al activo antes del primer cuadro.
- **F4-2.7** Con 3 000 movimientos la lista de movimientos pinta de forma perezosa (solo lo visible); no se construyen 3 000 filas.

## 3. Pendientes de Finanzas: inventario

Cada uno con su criterio. Entre paréntesis, el origen.

### 3.1 Motivo de 3 caracteres en los formularios; subrayados no aplican (N2, fase 1b)

El servidor ya exige 3 caracteres visibles (backend + finanzas, cerrado en el dominio y validado en los formularios). Falta pulir lo que ve la persona.

- **F4-3.1.1** Todos los formularios con motivo (anular, contraasiento, libro de papá, albacea, ajuste de saldo, retiro de ahorro) muestran el contador *"mínimo 3 letras"* y el error en español claro si el texto tiene menos de 3 caracteres visibles. Espacios, tabuladores, saltos de línea y caracteres invisibles no cuentan.
- **F4-3.1.2** El texto del motivo se recorta (espacios al inicio y al final) antes de contar y antes de guardar; el servidor y la app coinciden en el conteo (prueba con las mismas cadenas hostiles de N2).
- **F4-3.1.3** "Subrayados no aplican": los guiones bajos o subrayados (`___`, `...`, `---`) y la repetición de un solo carácter (`aaa`) **no** se aceptan como motivo válido. Regla propuesta: de los 3 caracteres, al menos **2 son letras o dígitos** y no todos son iguales. Se aplica igual en la app y en el servidor (pedir a backend la misma regla en la función de validación; ver pregunta Q2).

### 3.2 Cifras reales de Finanzas en "Hoy", "Mi semana" y el chip "Cuenta nueva" (I9, fase 2 sección 8, regla 50)

I9 quedó cerrado en lo básico ("Sin datos todavía" con sesión real), pero "Hoy" aún no muestra el resumen real.

- **F4-3.2.1** **Hoy (teléfono y laptop):** la tarjeta de Finanzas muestra el **resumen por libro** (personal, compartido, papá según los libros a los que la persona tiene acceso): disponible de la semana, semáforo y número de alertas críticas abiertas. **Filtrado por rol y por permiso del libro en la consulta**, no solo al pintar: el Dueño ve sus libros y los que comparte; la Pareja los suyos y el compartido; la cuidadora no ve la tarjeta. La Pareja jamás ve el libro personal del Dueño ni al revés.
- **F4-3.2.2** **Montos ocultables:** con los montos ocultos (D-privacidad, PIN) la tarjeta muestra *"Montos ocultos"* y el semáforo, **sin cifras en el texto ni en el lector de pantalla** (misma guardia que `f1b_montos_semantica_test`, ahora con datos reales). Al volver a verlos se pide el PIN.
- **F4-3.2.3** **Sin datos o sin permiso:** sin movimientos en la semana dice *"Sin datos todavía"*; sin acceso a un libro, el libro no aparece (nunca "0,00").
- **F4-3.2.4** **Mi semana:** muestra las cifras reales del libro activo (ingreso de la semana, presupuesto, deuda, remanente y semáforo) con el mismo cálculo del dominio que Finanzas; una prueba compara que "Hoy", "Mi semana" y la pantalla Semana de la laptop dan **las mismas cifras al centavo** para los mismos datos.
- **F4-3.2.5** **Chip "Cuenta nueva"** (fase 1, tabla 448, "siempre visible"): sigue visible en la hoja (+) y, al crear la cuenta, se selecciona sola y el flujo de gasto continúa sin perder el monto escrito. En letra 2.0 y 360 dp el chip no se corta ni empuja el botón Guardar fuera de vista.
- **F4-3.2.6** Las cifras de ejemplo (`ResumenGravity.ejemplo`) solo aparecen en modo demostración, nunca con sesión real; guardia de prueba existente se mantiene.
- **F4-3.2.7** Dinero fuera de la IA (D3): ninguna de estas tarjetas pasa cifras a `paraIa` ni a las bocinas.

### 3.3 Refresco de compartidos al dar de baja (cuando exista Ajustes › Personas)

- **F4-3.3.1** Al dar de baja a una persona (o quitarle el acceso a un libro compartido) en Ajustes › Personas, en el dispositivo del que baja la sesión: se invalidan los proveedores de Finanzas, el libro compartido desaparece de "Hoy" y de la lista de libros **en menos de 2 s** sin reiniciar la app, y lo pendiente de la cola pasa a "requiere atención" (comportamiento de `alQuitarPersona`).
- **F4-3.3.2** En los dispositivos de las demás personas, al sincronizar el libro compartido el cambio de miembros se refleja en la siguiente sincronización o al abrir la app (no se promete tiempo real).
- **F4-3.3.3** Prueba con dos sesiones simuladas: tras la baja, la persona dada de baja no ve ninguna cifra del libro ni siquiera desde caché local.
- Dependencia: la pantalla Ajustes › Personas la hospeda plataforma. Si no existe al cerrar la Fase 4, el criterio queda para después (ver sección 4).

### 3.4 Emitir avisos con `fin_emitir_aviso` desde la app (fase 2 sección 11; F2-3)

- **F4-3.4.1** La app emite los avisos que solo ella puede calcular (**flujo negativo previsto** y **abono bajo el mínimo**) llamando a `fin_emitir_aviso` al cerrar el cálculo de la semana y al guardar un movimiento que cambie el resultado.
- **F4-3.4.2** Idempotencia: la clave del aviso es estable (tipo + objeto + semana), de modo que repetir el cálculo **no** crea un segundo aviso (el servidor ya garantiza idempotencia por `(persona, clave)`); prueba de 5 llamadas seguidas = 1 aviso.
- **F4-3.4.3** Sin señal: la emisión **no se encola con dinero**; el aviso se emite al volver la señal con el cálculo vigente de ese momento, y el título sigue siendo discreto (sin cifras, D20).
- **F4-3.4.4** No emite si la persona no puede escribir en ese libro; respeta el tope de 60 claves por 24 h (si el servidor responde que se alcanzó, la app lo registra y no reintenta en bucle).
- **F4-3.4.5** Mitigación de F2-3 (un miembro podría emitir avisos falsos): el aviso crítico que se recibe de otra persona del libro se muestra con el nombre de quien lo emitió y no mueve nada en las cifras. La validación de `objeto_id` contra el libro es de backend (ver sección 6).

### 3.5 Redondeo, sobrante, sobre y extras conectados al cierre de semana (fase 2 sección 11, decisión c)

El dominio ya los calcula; falta conectarlos al cierre.

- **F4-3.5.1** Al cerrar la semana, el cierre aplica en este orden y lo guarda en el libro de cierres: **extras** (porcentaje de ingreso extra al ahorro), **sobre** (sobrante de sobres con arrastre de hasta 2 semanas de su monto, regla 32), **sobrante** (remanente a ahorro) y **redondeo** (diferencia al peso entero de los gastos de la semana hacia ahorro).
- **F4-3.5.2** Cada uno se registra como movimiento de ahorro con su origen visible y se puede **deshacer con anulación y contraasiento** (nunca se borra); el cierre es idempotente: cerrar dos veces la misma semana no duplica aportaciones.
- **F4-3.5.3** Los ejemplos numéricos A1 y A2 siguen pasando sin cambiar cifras (colchón en la semana 5, celular en la 34, fondo en la 41) con el cierre conectado; `dart test` de `finanzas_dominio` en verde.
- **F4-3.5.4** Con la marca de esencial por partida guardada en el cierre, el "gasto esencial" deja de decir *"según tu plan"* y sale real (decisión b de la sección 11 de fase 2). Cierra el cálculo del fondo de emergencia.
- **F4-3.5.5** Las aportaciones automáticas del cierre **no** piden señal por separado: se calculan en el teléfono o la laptop y suben con el cierre; si no hay señal, el cierre se guarda local y sube después en el orden de la cola (cuentas, movimientos, conciliaciones, cierres). Conflicto: nunca se pierde un cierre; si el servidor lo rechaza, queda en "requiere atención" con mensaje claro.

### 3.6 Simulación de la proyección y de la tarjeta de abono extra a letra 2.0 en 360 dp

La simulación semana a semana A1/A2 y la proyección ya están hechas y probadas en el dominio (actualización 1/nov). Queda la **pantalla** a tamaño de letra grande (la sección "Sin verificar" de fase 2).

- **F4-3.6.1** En 360 × 800 dp con letra **2.0**: la proyección y la tarjeta *"¿y si abono $X extra?"* (criterio 14) se leen y se usan sin desbordes (`RenderFlex overflow` = 0), con desplazamiento vertical y botón de acción visible tras desplazar; el campo de monto no queda tapado por el teclado.
- **F4-3.6.2** Las vistas nuevas de Fase 2 (Deudas, Ahorro y fondo, Vencimientos, hoja de pago, formularios de estado de cuenta, MSI, tasa, bolsa, aportación y retiro) pasan la misma prueba en 360 dp con letra 2.0 y en 900 dp (ventana de la laptop) con letra 1.5. Se agrega un archivo de prueba por pantalla al estilo de `f1_i6_letra_grande_telefono_test.dart`.
- **F4-3.6.3** Con montos ocultos, la tarjeta de abono extra no muestra cifras (ni la proyección) en texto ni en semántica.
- **F4-3.6.4** El resultado de la proyección coincide al centavo con el del dominio para los ejemplos del diseño (comparación de la pantalla contra el cálculo directo).

### 3.7 Estados de cuenta, aportaciones y retiros: piden señal (decisión aprobada 31/oct, sección 11 punto a)

- **F4-3.7.1** Sin señal, al intentar guardar un estado de cuenta, una aportación o un retiro de ahorro, la app **no guarda nada** y muestra, en el mismo formulario y sin perder lo escrito: *"Esto necesita conexión: el servidor liga el movimiento al guardarlo. Tus datos siguen aquí; intenta de nuevo cuando tengas señal."* con botón *Reintentar*.
- **F4-3.7.2** La hoja detecta la falta de señal **antes** de que la persona llene todo cuando se puede (aviso al abrir el formulario: *"Sin señal: podrás revisar, pero no guardar"*), y el botón Guardar se deshabilita con la razón visible, no en silencio.
- **F4-3.7.3** Si la señal se cae a mitad del guardado, no queda un movimiento a medias: el servidor responde todo o nada; la app no reintenta sola con el mismo id sin avisar, y al reintentar no duplica (idempotencia por id).
- **F4-3.7.4** Prueba en modo avión en el A52: los tres formularios muestran el mensaje, no hay pendientes en la cola, el dinero no cambia.
- **F4-3.7.5** Gasto, ingreso extra y pago de deuda sí siguen funcionando sin señal (cola); la distinción se explica una vez en *Ajustes › Finanzas* ("Qué funciona sin señal").

## 4. Qué entra en la Fase 4 y qué queda para después

| # | Pendiente | Decisión | Razón corta |
|---|---|---|---|
| 1 | Meta de 10 s (sección 1) | **Entra** | Meta de la fase en el roadmap; medición en el A52 |
| 2 | Meta de 2 s (sección 2) | **Entra** | Meta de la fase; el diferido de carga es trabajo propio |
| 3.1 | Motivo de 3 caracteres y subrayados | **Entra** | Corrección chica; ya cerrada en servidor, falta que la app lo explique |
| 3.2 | Cifras reales en Hoy, Mi semana, chip Cuenta nueva | **Entra** | Es lo primero que se ve; hoy "Hoy" dice "Sin datos todavía" con datos reales |
| 3.3 | Refresco al dar de baja | **Entra solo si** existe Ajustes › Personas (plataforma); si no, **después** | Depende de una pantalla que no es de Finanzas |
| 3.4 | `fin_emitir_aviso` desde la app | **Entra** | Sin esto las alertas críticas de flujo negativo y abono bajo no se emiten |
| 3.5 | Redondeo, sobrante, sobre y extras al cierre | **Entra** | El dominio está listo; sin cierre el ahorro no crece solo y el fondo usa "según tu plan" |
| 3.6 | Letra 2.0 en 360 dp (proyección y abono extra) | **Entra** | Acordado como criterio de aceptación (I6 a I8); sin verificar aún |
| 3.7 | Mensaje claro sin señal en estados de cuenta, aportaciones y retiros | **Entra** | Decisión del dueño ya aprobada; falta el mensaje y la prueba |
| 5 | Preferencias de avisos de Finanzas en Ajustes › Notificaciones | **Entra la sección de Finanzas**; la pantalla es de plataforma | Lo pidió la sección 11 de fase 2 |
| 6 | Conector de `consultaLocal` en la barra de órdenes | **Después (Fase 6)** | Es del asistente; no estorba al uso diario |
| 7 | Modo Pareja y Familiar restante, conciliación con estados de cuenta, simulador de deudas, inversión, reportes, voz e imagen | **Después (Fase 8+)** | Ya están en el roadmap como ampliaciones |
| 8 | Recordatorios locales más agresivos (F2-6: programar todos los "días antes") | **Entra** si el dueño responde Q4 con sí; si no, después | Barato y evita avisos perdidos sin señal |
| 9 | Argon2 o más vueltas de PBKDF2 (M9') | **Después**, plataforma | No es de Finanzas |

## 5. Preguntas al dueño (con propuesta por defecto)

1. **Q1. Medición de las metas.** ¿Aceptas medirlas con la mediana de 10 corridas (8 s para el gasto base, 2 s para abrir) y que ninguna pase de 10 s y 2,5 s? *Propuesta por defecto:* sí, tal como está.
2. **Q2. Motivo válido.** ¿Mínimo 3 caracteres, con al menos 2 letras o dígitos y no todos iguales, igual en la app y en el servidor? *Propuesta por defecto:* sí. Alternativa: solo 3 caracteres visibles como hoy.
3. **Q3. Qué ve "Hoy" de un libro compartido.** ¿La Pareja ve en "Hoy" las cifras del libro compartido (disponible y semáforo) o solo "hay avisos"? *Propuesta por defecto:* ve disponible y semáforo del compartido, nunca el personal del otro ni el de papá si no es albacea.
4. **Q4. Avisos sin señal.** ¿Programamos en el teléfono todos los recordatorios "días antes" de los próximos vencimientos (no solo el más próximo) para que lleguen aunque no haya señal por días (F2-6)? *Propuesta por defecto:* sí.
5. **Q5. Orden del cierre de semana.** ¿Extras, sobre, sobrante y redondeo en ese orden, con el redondeo al final y solo si queda disponible? *Propuesta por defecto:* sí, y el redondeo nunca deja la semana en negativo.
6. **Q6. Si Ajustes › Personas no llega en la Fase 4,** ¿dejamos el refresco al dar de baja (3.3) para después? *Propuesta por defecto:* sí, queda para después.

## 6. Lo que Finanzas pide a otras áreas

- **diseno:** estados visuales (oculto, sin datos, sin señal, error) de la tarjeta de Finanzas en "Hoy"; mensaje de "necesita conexión" como componente; tamaños de chip y fila Cancelar/Guardar flexibles para letra 2.0.
- **plataforma:** Ajustes › Personas (baja con invalidar proveedores), Ajustes › Notificaciones (hospedar la sección de Finanzas), diferir inicializaciones de arranque (Firebase, registro de token), herramienta de medición de arranque en frío en el A52.
- **backend:** misma regla de motivo (3.1.3) en la función de validación; validar `objeto_id` de `fin_emitir_aviso` contra el libro (F2-3); ajustar `enviar-avisos` para anotar rechazos 4xx distintos del token (F2-1).
- **calidad:** medición en el Galaxy A52 (F4-1.4 y F4-2.1), pruebas de letra 2.0 por pantalla, pruebas de dos sesiones para la baja de personas.

## 7. Hecho cuando (Finanzas, Fase 4)

- Los criterios F4-1 a F4-3 marcados como "Entra" pasan; `flutter analyze` y `flutter test` de la app, y `dart test` de `finanzas_dominio`, en verde.
- Medición en el A52 anotada: gasto en 10 s o menos y abrir en 2 s o menos, con y sin señal.
- Ninguna cifra de Finanzas en "Hoy" ni en "Mi semana" es de ejemplo cuando hay sesión real; ninguna aparece con los montos ocultos.
