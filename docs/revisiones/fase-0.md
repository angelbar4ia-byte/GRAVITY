# Revisión de calidad — Fase 0: Cimientos

> Agente **calidad** · 20/oct/2026 · rama `claude/zen-pasteur-b0jblz`, commit `9ccb8eb`.
> Base: `CLAUDE.md`, `docs/DECISIONES.md` (D3, D5, D7, D13, D14, D16), `docs/ROADMAP.md` (secciones 3 y 11), `docs/specs/fase-0-cimientos.md` (secciones 4, 5 y 7) y `docs/DISENO_UX_UI.md`.

## 1. Veredicto

**No cerrar la Fase 0 todavía.** El servidor está sólido (RLS en todo, funciones seguras, invitaciones bien hechas, bitácora inmutable, aislamiento entre hogares) y el respaldo funciona de punta a punta. Pero la **app muestra dinero y datos de cuidados a roles que no los ven** y la **tablet compartida** tiene dos huecos que rompen la separación por persona (D5, D14). Son arreglos acotados.

| Gravedad | Cuántos | Con prueba que lo demuestra |
|---|---|---|
| Bloqueante | 3 (B1 a B3) | 3 de 3 |
| Importante | 9 (I1 a I9) | 6 de 9 |
| Menor | 17 (M1 a M17) | 2 (M1 y M2, en SQL) |

## 2. Pruebas corridas

| Comando | Resultado |
|---|---|
| `cd app && flutter analyze` | Sin problemas (también con las pruebas nuevas) |
| `cd app && flutter test` (lo entregado) | **288 pasan** |
| `cd app && flutter test --exclude-tags hallazgo` (con las pruebas de calidad agregadas) | 288 pasan: la línea base sigue en verde |
| `cd app && flutter test --tags hallazgo` | Fallan a propósito: demuestran B1 a B3 e I1 a I6 (sección 9) |
| `cd paquetes/finanzas_dominio && dart test` | **122 pasan** |
| `bash supabase/tests/correr.sh` | **7 archivos, 211 afirmaciones, todo pasa** |
| `bash supabase/tests/correr.sh hallazgos_fase0.sql` | Falla a propósito: 3 hallazgos menores abiertos (M1a, M1b, M2) |
| `cd api && npm run verificar` | Al día (`fnv1a32:119577fe`) |
| `cd api && npm run validar` | `openapi.yaml` válido (Redocly) |
| `bash herramientas/respaldo/probar_respaldo.sh` (extra, criterio 4) | **37 comprobaciones pasan** (pwsh 7, 7-Zip, GnuPG, PostgreSQL 16) |

Además corrí las guías de accesibilidad de Flutter (zona táctil de 48 dp, botones con etiqueta y contraste de texto) sobre "Hoy" del teléfono, el modo Casa, el diálogo del PIN, "Más" y la pantalla principal de la laptop: todo pasa salvo un contraste (M7).

## 3. Criterios de aceptación (especificación, sección 7)

| # | Criterio | Estado | Evidencia y observaciones |
|---|---|---|---|
| 1 | Entras con tu cuenta en la laptop y el teléfono | **Requiere al dueño** | Necesita el proyecto real de Supabase. `ServicioSesionSupabase` (entrar, iniciar, salir) no tenía pruebas; I3 agrega dos y encuentra un error |
| 2 | Cuidador solo ve Cuidados; Familiar no ve dinero, comprobado en el servidor | **Servidor: sí. App: no** | Servidor demostrado (`20_finanzas_muestra.sql`, `70_membresias_personas.sql`, `40_aislamiento_hogares.sql`). Navegación de la cuidadora correcta. Pero el Familiar ve el panel de Finanzas y el de Cuidados en "Hoy" y en la laptop (**B1**); la prueba existente pasa **en vacío** |
| 3 | Un registro sin internet se sube al volver la señal | **Parcial** | Demostrado con un enviador simulado (`cola_sin_conexion_test.dart`). El enviador real aún no tiene tipos (`tablasDeLaCola` vacío) y un registro se pierde si se envía sin sesión (**I4**) |
| 4 | Copia diaria que se puede restaurar | **Sí, en local** | `probar_respaldo.sh`: respaldo cifrado, dos ubicaciones, retención, fallas controladas y restauración idéntica tabla por tabla. Falta el simulacro en la laptop Windows con el proyecto real (dueño) |
| 5 | La app llega por App Distribution | **Requiere al dueño** | Sin `google-services.json` (correcto: no va en el repositorio) |
| 6 | Tablet: modo Casa sin dinero; PIN abre las pantallas de la persona; regresa a los 2 min | **No** | La pantalla del modo Casa no muestra dinero y el PIN y el regreso funcionan, pero: al regresar quedan abiertas las hojas de la persona (**B2**); cualquier huella abre a cualquiera (**B3**); el Familiar que entra con PIN ve dinero (**B1**); y el modo Casa es solo de interfaz (**I6**) |
| 7 | El estilo cambia sin reiniciar y el claro/oscuro cambia por hora | **Sí** | `cambio_estilo_test.dart`, `modo_claro_oscuro_test.dart` |
| 8 | Lo construido aparece en Ajustes › Desarrollador | **Sí** | `openapi.yaml` válido y al día, pruebas de la pantalla y de coherencia herramientas ↔ OpenAPI. Probar operaciones contra Supabase requiere el proyecto real |

**Pruebas que pasan en vacío o son frágiles**
- `app/test/app/navegacion_por_rol_test.dart:150` — `find.textContaining('Finanzas')` no encuentra la tarjeta de Finanzas del Familiar porque `TarjetaModulo` dibuja el título en mayúsculas ("FINANZAS · SEMANA") y porque la lista de "Hoy" construye sus tarjetas de forma perezosa. La tarjeta **sí** está (B1).
- `app/test/app/tablet_test.dart:64` y `:146` — mismo patrón sensible a mayúsculas. Hoy son válidas porque la pantalla del modo Casa no dibuja el resumen, pero se romperían en silencio. Propuesta: buscar por llave (`ValueKey('tarjeta-finanzas')`, `'panel-finanzas'`) o comparar en minúsculas.
- SQL: revisé las 55 llamadas a `pruebas.falla`; **todas** exigen el código de error esperado. Ninguna pasa en vacío.

## 4. Hallazgos bloqueantes

### B1. "Hoy" y la pantalla principal muestran dinero y cuidados a Familiar y Casa
- **Dónde:** `app/lib/modulos/gravity/pantalla/resumen_gravity.dart:191-193` (`resumenGravityProvider` siempre devuelve `ResumenGravity.ejemplo`, con `finanzas` y `cuidados`) y `:197-206` (`modulosBarraProvider` fijo con Finanzas, Cuidados y Ajustes); se pintan en `hoy_telefono.dart:34-35` y `pantalla_principal.dart:405, 438, 773`. El comentario de `resumen_gravity.dart:8-9` dice que "si un rol no puede ver dinero o cuidados, el campo va en null", pero nadie lo hace: ningún archivo sobrescribe esos proveedores por rol.
- **Escenario:** un Familiar entra en el teléfono, la laptop o la tablet (con su PIN) y ve "FINANZAS · SEMANA", el semáforo, "Quedan $ • • • • •" con botón **Mostrar** (en la laptop), "Presupuesto usado 62 %", "Vence la tarjeta de crédito", y el panel "CUIDADOS" con "Medicamento 20:00" y la entrega de turno. El núcleo le dice "a las 20:00 hay un medicamento en el turno". La cuenta Casa (laptop o teléfono) ve lo mismo, y en la laptop todos ven los botones FINANZAS, CUIDADOS y AJUSTES (al tocarlos el router los regresa). Hoy son datos de ejemplo, pero en cuanto la Fase 1 conecte el proveedor a datos reales, el dinero llega a la pantalla del Familiar. Rompe D5 y los criterios 2 y 6 en la interfaz.
- **Arreglo propuesto:** que el resumen dependa del rol efectivo: `finanzas` solo si `puedeAbrir(rol, Modulo.finanzas)`; `cuidados` solo si el rol lee Cuidados (para Casa, únicamente los recordatorios genéricos); cada aviso con su módulo para filtrarlo (el de la tarjeta es de Finanzas); el saludo del núcleo sin la frase de cuidados si el rol no los ve; `modulosBarraProvider` = `modulosNavegables(rol)` más Ajustes si `puedeAbrir(rol, Modulo.ajustes)`. Como `rolEfectivoProvider` vive en `app/`, lo más limpio es que plataforma lo conecte en `pantallas_externas.dart` (un `overrideWith` o un parámetro de rol) y diseno quite los valores fijos. Corregir también la prueba en vacío de `navegacion_por_rol_test.dart:150`.
- **Prueba:** `app/test/revision_calidad/b1_resumen_por_rol_test.dart` (7 casos: Familiar y Casa en teléfono y laptop, Familiar con PIN en la tablet, barra de módulos de Familiar y de Casa).
- **Agentes:** diseno (proveedores y pantallas) y plataforma (conexión con el rol y la prueba existente).

### B2. Al regresar solo al modo Casa quedan abiertas las hojas y diálogos de la persona
- **Dónde:** `app/lib/app/cascarones/cascaron_tablet.dart:44-48` (al vencer el tiempo solo llama a `volverAModoCasa`) y `:35` (`context.go`); las hojas y diálogos se abren en el navegador raíz (`hoja_registrar.dart:11-16`, `showModalBottomSheet`; lo mismo con `showDialog`), fuera del cascarón.
- **Escenario:** el Dueño entra con su PIN, abre (+) Registrar y se va. A los 2 minutos la tablet vuelve al modo Casa, pero la hoja con "Gasto" e "Ingreso extra" del Dueño sigue encima, al alcance de quien pase. En la Fase 1 esa hoja abre el registro de dinero. Criterio 6.
- **Arreglo propuesto:** al cambiar de persona (entrar, salir, vencer el tiempo) cerrar todo lo que esté sobre el cascarón, p. ej. `Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst)` antes de `context.go`, o abrir hojas y diálogos con el navegador del cascarón. Reiniciar también `montosVisiblesProvider` (M8).
- **Prueba:** `app/test/revision_calidad/b2_regreso_modo_casa_cierra_todo_test.dart`.
- **Agente:** plataforma.

### B3. En la tablet compartida, cualquier huella abre a cualquier persona
- **Dónde:** `app/lib/nucleo/tablet/controlador_tablet.dart:152-164` (`desbloquearConHuella` abre a la persona elegida si el sistema acepta *alguna* huella). El riesgo está reconocido en `app/lib/nucleo/seguridad/biometria.dart:3-5` y en `app/README.md`, pero la función está activa.
- **Escenario:** la cuidadora registra su dedo en la tablet (para entrar a su turno). El Dueño activa "huella" para sí. La cuidadora toca "Dueño", pone **su** dedo y entra como el Dueño: ve sus pantallas, y desde la Fase 1, su dinero. Lo mismo un hijo con el dedo registrado. Rompe D5 (cada quien ve solo lo de su rol); es el mismo principio de D5 sobre la voz: el equipo compartido no identifica a la persona.
- **Arreglo propuesto:** en la tablet compartida, la huella no basta para entrar: o se quita (solo PIN), o se usa como segundo paso junto con el PIN. Si el dueño quiere conservarla, limitarla a roles sin dinero ni datos clínicos (Familiar). Decisión del dueño (detalle propuesto de D14).
- **Prueba:** `app/test/revision_calidad/b3_huella_tablet_compartida_test.dart`.
- **Agente:** plataforma; **decisión del dueño** (pregunta 1).

## 5. Hallazgos importantes

### I1. La matriz espejo de la app no coincide con la del servidor
- **Dónde:** `app/lib/nucleo/permisos/permisos.dart:79, 91, 105, 122` frente a `supabase/migrations/20261020000000_base.sql:551, 570-572` (y `:524`).
- **Diferencias** (acciones por rol y módulo):

| Rol × módulo | App (espejo) | Servidor | Comentario |
|---|---|---|---|
| cuidador × finanzas | leer, escribir (`registroPropio`) | escribir (restringido; "nunca lee Finanzas") | **La app dice que la cuidadora lee Finanzas.** Hoy no se nota porque `accesoDirecto` es falso, pero cualquier código que use `puede(rol, finanzas, leer)` para mostrar dinero se lo mostraría (D5) |
| cuidador × gravity | nada | leer y escribir (propio) | El criterio 2 dice "solo ve Cuidados": ¿la cuidadora usa GRAVITY? |
| coadministrador × cuidados | leer (consentimiento) | leer y escribir (restringido) | ¿El coadministrador escribe en Cuidados con consentimiento? (Fase 5) |
| dueño × gravity (alcance) | total | leer y escribir propio; administrar total | Mismas acciones, distinto alcance: con "propio", ni el dueño ve el historial de GRAVITY de otros |

- **Arreglo propuesto:** `Alcance.registroPropio` → solo `{escribir}` (o un alcance "lo que registra", sin lectura del módulo); decidir gravity × cuidador y cuidados × coadministrador y alinear ambos lados. Dejar como guardia permanente una prueba que lea la migración y compare (la que agrego).
- **Prueba:** `app/test/revision_calidad/i1_matriz_espejo_servidor_test.dart`.
- **Agentes:** plataforma (espejo) y backend (matriz); dueño (preguntas 4 y 5).

### I2. PIN de la tablet: los intentos fallidos se olvidan al reiniciar y la espera no crece
- **Dónde:** `app/lib/nucleo/tablet/controlador_tablet.dart:71, 78-79, 127-149`.
- **Escenario:** alguien prueba PIN tras PIN del Dueño. Tras 5 fallos espera 30 s y sigue; un PIN de 4 dígitos se recorre en unas 17 horas como máximo. Si cierra y abre la app, el contador vuelve a cero: 5 intentos por reinicio, sin esperar.
- **Arreglo propuesto:** guardar fallos y bloqueo en el almacenamiento seguro (por persona); espera creciente (p. ej. 30 s, 1 min, 5 min, 15 min, 1 h) y aviso al Dueño tras muchos fallos; considerar PIN de 6 dígitos para roles con dinero.
- **Prueba:** `app/test/revision_calidad/i2_pin_intentos_test.dart` (reinicio y espera creciente).
- **Agente:** plataforma.

### I3. Una cuenta dada de baja abre la app con su rol anterior
- **Dónde:** `app/lib/nucleo/sesion/servicio_sesion_supabase.dart:143` (`iniciar()` atrapa cualquier error y usa la sesión guardada).
- **Escenario:** el Dueño da de baja a una cuidadora. Al abrir la app **con señal**, el servidor responde que no tiene rol (`ErrorSesion.sinRol`), pero la app abre con el rol de cuidadora guardado. El servidor sigue negando los datos (bien), pero la app muestra lo que tenga en el dispositivo; con la copia del día (D7) y la Fase 5 serían medicamentos y turnos. D5: "pierden el acceso de inmediato".
- **Arreglo propuesto:** usar la sesión guardada solo ante errores de red (`SocketException`, `TimeoutException`, `AuthRetryableFetchException`); con `sinRol` o un error de autenticación, borrar la sesión guardada (y la copia local) y cerrar sesión.
- **Prueba:** `app/test/revision_calidad/i3_sesion_dada_de_baja_test.dart` (falla el caso de la baja; el caso sin señal pasa y debe seguir pasando).
- **Agente:** plataforma.

### I4. La cola sin conexión puede perder registros: no está ligada a la sesión
- **Dónde:** `app/lib/main.dart:12` (procesa cada 30 s aunque nadie haya entrado), `app/lib/nucleo/cola/enviador_supabase.dart:45-49` (42501 → rechazado), `app/lib/nucleo/cola/cola_sin_conexion.dart:204-213` (rechazado no se reintenta) y la tabla `Pendientes` sin persona (`base_local.dart`).
- **Escenario:** el Dueño registra un gasto sin señal; la sesión se cierra (salió, o la renovación venció) antes de que vuelva la señal. La cola lo envía con la llave pública (anon), el servidor responde 42501 y el gasto queda **rechazado para siempre**, sin aviso. En un equipo compartido, lo que registró una persona se enviaría con la sesión de la siguiente (bitácora con otro nombre o rechazo). Criterio 3.
- **Arreglo propuesto:** guardar en cada registro el `usuario_id` de quien lo hizo; enviar solo si la sesión actual es de esa persona (si no, esperar); sin sesión, `reintentar`; mostrar los rechazados (p. ej. en el aviso "3 por subir") para que la persona decida. Opcional: límite de reintentos para errores permanentes no clasificados (M16).
- **Prueba:** `app/test/revision_calidad/i4_cola_sin_sesion_test.dart` (servidor HTTP local que responde como PostgREST).
- **Agente:** plataforma.

### I5. El registro de herramientas no impone D3 ni la matriz
- **Dónde:** `app/lib/nucleo/herramientas/registro_herramientas.dart:21-52` (solo valida nombre, prefijo, roles no vacíos y duplicados) y `:109-121` (`_motivo` solo mira la lista de roles que declara la herramienta).
- **Escenario:** en la Fase 1 alguien escribe `finanzas.resumen_semana` con `soloLocal: false` o con `roles: {dueno, familiar}`. El registro la acepta: el resultado con cifras iría a la IA en la nube (D3) o la herramienta existiría para el Familiar (D5). Hoy solo hay herramientas de navegación, así que no hay fuga actual.
- **Arreglo propuesto:** en `_indexar`, rechazar herramientas cuyos roles no puedan leer (o escribir, si `escribe`) su módulo según la matriz, y exigir `soloLocal` a toda herramienta de Finanzas o Cuidados que no sea de navegación (p. ej. que `HerramientaNavegacion` sea la única excepción).
- **Prueba:** `app/test/revision_calidad/i5_herramientas_d3_test.dart`.
- **Agente:** asistente.

### I6. Tablet: el modo Casa y el cambio de persona son solo de interfaz
- **Dónde:** `app/lib/app/sesion_efectiva.dart:19-30` (en la tablet arma el rol Casa sin mirar la cuenta real) y `app/lib/nucleo/tablet/controlador_tablet.dart:4-6`; `app/test/app/tablet_test.dart:48-56` prueba a propósito el modo Casa "aun con la cuenta del Dueño". Reconocido como pendiente en `app/README.md`.
- **Escenario:** si la tablet se configura con la cuenta del Dueño, todo lo que se consulte en modo Casa desde la Fase 1 corre en el servidor con permisos del Dueño (RLS deja ver dinero) y la "cuidadora con PIN" escribe como el Dueño (la bitácora pierde el nombre real, D5). Si se configura con la cuenta Casa, lo que el Dueño registre desde la tablet se rechaza (y con I4, se pierde). D14 dice que el modo Casa "usa la cuenta de rol Casa", pero nada lo exige.
- **Arreglo propuesto:** ya en la Fase 0, que la tablet solo presente el modo Casa con una cuenta de rol Casa (con otra cuenta, avisa y pide la cuenta Casa). Antes de llevar dinero a la tablet (Fase 1): sesión del servidor por persona (el pendiente del README: token de cada persona cifrado y desbloqueado con su PIN) y la cola ligada a esa persona (I4).
- **Prueba:** `app/test/revision_calidad/i6_tablet_cuenta_casa_test.dart` (contradice a propósito `tablet_test.dart:48-56`: decide el arquitecto con el dueño).
- **Agentes:** plataforma; backend cuando haya sesión por persona.

### I7. Datos reales del dueño en el repositorio
- **Dónde:** `data/FICHA_DEUDAS_Y_TARJETAS.xlsx` (versionado; `data/` solo ignora `data/personal/`).
- **Escenario:** las hojas Instituciones y Tarjetas contienen la lista real de instituciones, tarjetas y un crédito automotriz del dueño, con notas "Confirmado por ti". No hay saldos ni números de tarjeta (las cifras del crédito están en la columna de ejemplo). Va contra "sin datos reales en el repositorio" (CLAUDE.md). No revisé a fondo `DATOS_SEMILLA_PRESUPUESTO.xlsx` ni `PRESUPUESTO_DE_ALIMENTOS.xlsx` por privacidad: el dueño debe confirmar qué contienen.
- **Arreglo propuesto:** mover la ficha llena a `data/personal/` y dejar en `data/` una plantilla vacía; si el dueño lo pide, limpiar el historial de git (y el del repositorio FINANZAS de donde vino).
- **Agentes:** arquitecto con el dueño (pregunta 3).

### I8. Falta el bloqueo del teléfono con PIN o huella
- **Dónde:** `docs/ROADMAP.md` sección 3 lo incluye en la Fase 0 ("Teléfono: … bloqueo con PIN o huella"); `app/README.md` lo deja en pendientes. No está en los criterios de aceptación.
- **Escenario:** desde la Fase 1 el teléfono del Dueño tendrá dinero; sin bloqueo propio, cualquiera con el teléfono desbloqueado lo ve.
- **Arreglo propuesto:** bloqueo al abrir y al volver de segundo plano tras un tiempo, con PIN (hash, intentos persistentes, como I2) o huella (en un teléfono personal la huella sí sirve).
- **Agente:** plataforma (o pasar formalmente a la Fase 1).

### I9. Android respalda la base local en la nube de Google
- **Dónde:** `app/android/app/src/main/AndroidManifest.xml:6` (sin `android:allowBackup="false"` ni `dataExtractionRules`).
- **Escenario:** el respaldo automático de Android sube a Google Drive la base local (`gravity.sqlite`, con la cola de registros pendientes: gastos desde la Fase 1) y las preferencias. Choca con D13 ("solo en el teléfono: no sale del dispositivo", Fase 3). Además, `flutter_secure_storage` no se puede descifrar tras restaurar en otro equipo (las llaves del Keystore no viajan) y la app falla al leer.
- **Arreglo propuesto:** `android:allowBackup="false"` (o reglas que excluyan la base y el almacenamiento seguro).
- **Agente:** plataforma.

## 6. Hallazgos menores

| # | Dónde | Escenario | Propuesta | Agente |
|---|---|---|---|---|
| M1 | `supabase/migrations/20261020000000_base.sql:744-746` | La "red de seguridad" no sirve para funciones: un `REVOKE` por esquema no quita el `EXECUTE` que PUBLIC tiene por omisión; una función nueva en `public` queda ejecutable por anon. Una tabla nueva da `TRUNCATE` (salta RLS) a authenticated. Hoy `10_esquema.sql` lo atrapa al correr las pruebas | `alter default privileges for role postgres revoke execute on functions from public;` (sin `in schema`) y `alter default privileges in schema public revoke truncate on tables from authenticated;` | backend |
| M2 | `base_sql:664-668` (`bitacora_agregar`) | Cualquier miembro, incluso Casa, escribe entradas con `accion`, `tabla`, `registro_id` y `detalle` libres (hasta 32 KB): puede fabricar algo que parece hecho por los triggers ("borrar" en `finanzas_muestra`) y llenar la base gratis | Reservar `insertar`, `actualizar` y `borrar` a los triggers (check o prefijo `app.`), y límite por persona | backend |
| M3 | `base_sql:74, 478-482` | Una membresía con `activa` verdadera pero `hasta` vencido impide reinvitar ("Ya perteneces a este hogar"; el índice único también) | Al aceptar, cerrar la membresía vencida (`activa = false`) o tratar `hasta` vencido como inactiva | backend |
| M4 | `app/lib/nucleo/sesion/servicio_sesion_supabase.dart:35-39, 57` | Toma la primera membresía vigente sin orden. Cualquiera puede llamar `crear_hogar` y quedar como dueño de otro hogar: con dos hogares, la app elige rol y hogar al azar (el servidor protege los datos; la interfaz se confunde) | Función `mi_perfil()` con hogar preferido, o elegir hogar al entrar | plataforma y backend |
| M5 | `api/openapi.yaml` (`crear_hogar`) | Marca `x-roles: [dueno]`, pero cualquier cuenta puede crear un hogar | Documentar "cualquier cuenta (queda como dueño)" o restringirlo | asistente |
| M6 | `app/lib/nucleo/herramientas/navegacion.dart:156-163`, `interprete_ordenes.dart:103`, `barra_ordenes.dart:259` | La barra sugiere "Desarrollador" al Dueño en teléfono y tablet (el router luego lo regresa, D16: solo laptop); el texto de ayuda dice «abre presupuesto» a roles sin Finanzas | Pasar el dispositivo al intérprete; ayuda con un destino que el rol sí ve | asistente |
| M7 | Núcleo de la pantalla principal (`EN ESPERA`) | Contraste 4.37:1 de día (necesita 4.5:1, texto de 13 px). Las pruebas de pantalla usan la hora real (`horaActualProvider`): el resultado puede cambiar según la hora | Oscurecer el acento de día o subir el tamaño; fijar el reloj en las pruebas | diseno |
| M8 | `app/lib/diseno/proveedores.dart:228-263` | `montosVisiblesProvider` y `modoPrivadoProvider` no se reinician al cambiar de persona en la tablet: si el Dueño mostró los montos, siguen visibles para quien entre después | Reiniciar al cambiar `rolEfectivoProvider` o la persona | diseno y plataforma |
| M9 | `app/lib/app/tablet/detector_inactividad.dart:74`; sin `WidgetsBindingObserver` en la app | Sin manejo del ciclo de vida: al volver de segundo plano tras más de 2 min se ve la pantalla de la persona hasta que dispara el temporizador; la miniatura de "recientes" muestra esa pantalla (sin `FLAG_SECURE`). Los toques dentro de hojas y diálogos no reinician el tiempo | Al reanudar, comparar con la última actividad y volver al modo Casa; `FLAG_SECURE` con dinero o modo privado | plataforma |
| M10 | `app/lib/nucleo/sesion/servicio_sesion_demostracion.dart:14-34` y pruebas | Correos de ejemplo en dominios no reservados (`ejemplo.mx`, `ejemplo.com`, `b.mx`); el seed sí usa `.test` | Usar `ejemplo.test` (RFC 2606) en todo | plataforma y asistente |
| M11 | `herramientas/respaldo/respaldo_diario.ps1:164-167`; `restaurar.ps1:58`; `abrir_swagger.dart:104` | La clave de 7-Zip va en la línea de comandos (documentado); si el proceso muere quedan datos sin cifrar en `%TEMP%`; `npx http-server api` escucha en toda la red de casa | Borrar al inicio carpetas `gravity_respaldo_*` viejas de `%TEMP%`; sugerir `npx http-server api -a 127.0.0.1` | backend y asistente |
| M12 | `base_sql:678-685` | `finanzas_muestra` permite UPDATE y DELETE (documentado como muestra; contradice el libro solo-agregar) | Recordatorio: los movimientos de la Fase 1 con `impedir_cambios_solo_agregar` | backend (Fase 1) |
| M13 | `base_sql:239` | El mismo token de avisos puede quedar a nombre de varias personas (tablet compartida): en la Fase 2 los avisos del Dueño llegarían a la tablet | Token único global o avisos solo a la cuenta Casa en la tablet | backend y plataforma (Fase 2) |
| M14 | `app/lib/nucleo/herramientas/herramienta.dart:102-128` | `rol` y `confirmado` los pone quien llama; una excepción de una herramienta `soloLocal` sale sin sanear (podría llevar cifras) | Tomar el rol de la sesión dentro del registro; envolver excepciones de herramientas `soloLocal` | asistente (Fase 6) |
| M15 | Configuración de Supabase Auth | `aceptar_invitacion` confía en `email_confirmed_at`; si el proyecto confirma correos automáticamente, cualquiera con el token entra con un correo ajeno | Dejar **activa** la confirmación de correo (ya lo dice el README del respaldo) | dueño |
| M16 | `app/lib/app/arranque.dart:75-79, 89`; `enviador_supabase.dart:50-51` | En modo demostración la cola usa la base del dispositivo (el README dice "nada de lo de ejemplo se guarda"): si luego se configura Supabase, lo de ejemplo se sube. Errores permanentes no clasificados (p. ej. `PGRST204`, columna desconocida) se reintentan para siempre | Base en memoria en demostración; límite de reintentos con aviso | plataforma |
| M17 | `app/lib/app/dispositivo.dart:16-30` | La tablet se detecta por tamaño: un plegable abierto o una tablet personal entran como "tablet de la casa" (modo Casa) | Marcar el equipo como "tablet de la casa" en Ajustes (o al entrar con la cuenta Casa) | plataforma; dueño (pregunta 2) |

## 7. Lo que está bien (y conviene conservar)

- **Servidor:** RLS en las 8 tablas; reglas con `puede()` y `rol_en_hogar()`; todas las funciones `SECURITY DEFINER` con `search_path = ''` y nombres calificados; privilegios por columna; nada para anon (comprobado tabla por tabla); `TRUNCATE` negado a la API; la baja quita el acceso al instante; aislamiento entre hogares; `puede()` falla con nombres mal escritos en lugar de negar en silencio.
- **Invitaciones:** token de 244 bits, solo se guarda su SHA-256, vence (1 a 30 días), una sola pendiente por correo, exige correo **confirmado** e igual al invitado, no se reutiliza, no se puede invitar como dueño; el hash no llega a la bitácora.
- **Bitácora:** solo agregar incluso para `service_role` y para el dueño de las tablas (trigger para fila y `TRUNCATE`); quién y cuándo los pone el servidor.
- **Respaldo:** AES-256 (7-Zip con nombres cifrados o GnuPG), clave solo en variables de entorno y oculta en el registro, contraseña por `PGPASSWORD`, verificación al crear, dos ubicaciones, retención con mínimo, restauración solo en base vacía y en una transacción, con comparación de filas. Ni la clave ni cadenas de conexión aparecen en el repositorio.
- **Secretos:** no encontré llaves, tokens, JWT ni correos reales en el código; `.gitignore` cubre `.env*`, `google-services.json`, almacenes de llaves, `local.properties`, `key.properties` y `data/personal/` (comprobado con `git check-ignore`). La llave de servicio no está en la app.
- **PIN:** nunca se guarda el PIN: PBKDF2-HMAC-SHA256 con sal aleatoria y comparación en tiempo constante, en el almacenamiento seguro.
- **Herramientas:** el resultado de una herramienta `soloLocal` no puede llevar texto para la IA (constructor y saneado del registro); toda escritura pide confirmación.
- **Accesibilidad:** zonas táctiles de 48 dp, botones con etiqueta, montos ocultos también para el lector de pantalla ("Monto oculto"), semáforo con texto y no solo color, núcleo y barras que respetan "reducir movimiento", contraste revisado por estilo y personalidad.

## 8. Pruebas agregadas por calidad

Todas llevan la etiqueta `hallazgo` y el encabezado **"FALLA HOY A PROPÓSITO"**: demuestran el hallazgo y pasarán cuando se arregle. Mientras tanto la línea base se corre con `flutter test --exclude-tags hallazgo`.

| Archivo | Hallazgo | Casos | Hoy |
|---|---|---|---|
| `app/test/revision_calidad/b1_resumen_por_rol_test.dart` | B1 | 7 | 7 fallan |
| `app/test/revision_calidad/b2_regreso_modo_casa_cierra_todo_test.dart` | B2 | 1 | falla |
| `app/test/revision_calidad/b3_huella_tablet_compartida_test.dart` | B3 | 1 | falla |
| `app/test/revision_calidad/i1_matriz_espejo_servidor_test.dart` | I1 | 3 | 2 fallan (la lectura de la migración pasa) |
| `app/test/revision_calidad/i2_pin_intentos_test.dart` | I2 | 2 | 2 fallan |
| `app/test/revision_calidad/i3_sesion_dada_de_baja_test.dart` | I3 | 2 | 1 falla (el caso sin señal pasa y debe seguir pasando) |
| `app/test/revision_calidad/i4_cola_sin_sesion_test.dart` | I4 | 1 | falla |
| `app/test/revision_calidad/i5_herramientas_d3_test.dart` | I5 | 4 | 3 fallan (las de navegación siguen permitidas) |
| `app/test/revision_calidad/i6_tablet_cuenta_casa_test.dart` | I6 | 1 | falla |
| `supabase/tests/hallazgos_fase0.sql` | M1, M2 | 3 comprobaciones | falla con 3 abiertos; no entra en la corrida normal (`correr.sh hallazgos_fase0.sql`) |

**Pedido al arquitecto:** declarar la etiqueta en `app/dart_test.yaml` (`tags: {hallazgo: {}}`) para quitar el aviso de etiqueta no declarada; está fuera de mis carpetas.

## 9. Pedidos por agente

| Agente | Qué |
|---|---|
| **plataforma** | B1 (conectar el rol al resumen y la barra; corregir la prueba en vacío), B2, B3, I1 (espejo), I2, I3, I4, I6, I8, I9, M4, M8, M9, M10, M16, M17 |
| **diseno** | B1 (proveedores sin valores fijos de dinero y cuidados; avisos con módulo; saludo del núcleo), M7, M8 |
| **backend** | I1 (matriz), M1, M2, M3, M11 (temporales del respaldo), M12, M13 |
| **asistente** | I5, M5, M6, M11 (`http-server` local), M14 |
| **arquitecto** | Integrar los arreglos, `dart_test.yaml`, I7 con el dueño, decidir sobre `tablet_test.dart:48-56` frente a I6 |

## 10. Decisiones propuestas (para el dueño; no editan `DECISIONES.md`)

1. **D14 (detalle):** en la tablet compartida la huella no identifica a la persona: se usa solo como segundo paso del PIN o no se usa. *Por qué:* Android acepta cualquier dedo registrado (B3).
2. **D14 (detalle):** la tablet solo trabaja en modo Casa con la cuenta de rol Casa, y antes de llevar dinero a la tablet (Fase 1) el cambio de persona incluye la sesión del servidor de esa persona. *Por qué:* hoy la separación es solo de interfaz (I6).
3. **D1/D3:** el registro de herramientas rechaza las que no cumplen la matriz y exige `soloLocal` a las que leen datos de Finanzas o Cuidados. *Por qué:* la regla de D3 no puede depender de que cada autor recuerde la marca (I5).
4. **D17 (propuesta del backend):** la bitácora reserva las acciones de los triggers (`insertar`, `actualizar`, `borrar`). *Por qué:* M2.

## 11. Preguntas para el dueño

1. ¿Quitamos la huella de la tablet, o la dejamos solo como segundo paso del PIN? (B3)
2. ¿La tablet podrá usarse alguna vez con la cuenta de una persona (como tablet personal), o siempre es la tablet de la casa? (I6, M17)
3. `data/FICHA_DEUDAS_Y_TARJETAS.xlsx` tiene tu lista real de instituciones y tarjetas: ¿la movemos a `data/personal/` y limpiamos el historial? ¿Las otras dos hojas de `data/` tienen datos reales? (I7)
4. ¿La cuidadora usa GRAVITY (órdenes, voz) o solo Cuidados? El servidor le da GRAVITY "lo propio"; la app no. (I1)
5. ¿El coadministrador podrá **escribir** en Cuidados con consentimiento (como dice el servidor) o solo leer (como dice la app)? (I1)
6. ¿Qué espera quieres tras PINs fallidos en la tablet, y quieres un aviso cuando pase? Propuesta: 30 s, 1 min, 5 min, 15 min y aviso al Dueño. (I2)
7. Al crear el proyecto de Supabase, deja activa la confirmación de correo (M15).
