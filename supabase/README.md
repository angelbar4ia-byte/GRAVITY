# Supabase de GRAVITY

Base de datos, reglas por rol (RLS) y, desde la Fase 2, funciones de servidor. Los permisos viven aquí (D5, D7): aunque la app falle, nadie lee ni escribe lo que su rol no permite.

| Ruta | Qué es |
|---|---|
| `migrations/` | SQL solo hacia adelante, `AAAAMMDDHHMMSS_descripcion.sql` |
| `seed.sql` | Datos de ejemplo **ficticios**, solo para desarrollo local y pruebas |
| `tests/` | Pruebas SQL de las reglas por rol y `correr.sh` |
| `functions/` | Funciones de servidor (Fase 2) |

## Esquema base (Fase 0)

Migración `20261020000000_base.sql`:

| Tabla | Qué guarda | Quién la ve |
|---|---|---|
| `hogares` | Hogar | Sus miembros; el dueño cambia el nombre |
| `personas` | Persona con cuenta (`usuario_id` → `auth.users`) y nombre visible. Se crea sola al registrarse. No se borra | Cada quien a sí mismo; el dueño a los miembros de su hogar |
| `membresias` | Rol de la persona en el hogar (`dueno`, `coadministrador`, `familiar`, `cuidador`, `casa`), `activa`, `desde`, `hasta` y, desde la Fase 1, `es_maestra` (D19) | Cada quien las suyas; el dueño todas. El dueño cambia roles y da de baja (no a sí mismo, ni nombra otro dueño). No se borran |
| `permisos_rol` | Matriz rol × módulo × acción con su `alcance` | Cualquier sesión (espejo de la app). Solo cambia por migración |
| `invitaciones` | Invitación a un hogar: correo, rol, **hash** del token, expiración, aceptación, revocación | Solo el dueño |
| `dispositivos` | Dispositivos de cada persona y su token de avisos (FCM) | Cada quien los suyos |
| `bitacora` | Auditoría **solo agregar**: quién (`persona_id`), qué (`accion`), cuándo (`ocurrido_en`, `registrado_en`), `tabla`, `registro_id`, `detalle`. `accion` en minúsculas (`^[a-z][a-z0-9_.]*$`, p. ej. `entrega_de_turno`, `gravity.abrir`); `insertar`, `actualizar` y `borrar` están **reservadas** a los triggers | Cada quien lo que él hizo; el dueño lo del hogar **salvo** el historial de GRAVITY (`gravity.*`, D18) y las finanzas de libros que no lleva (D19); la cuenta maestra todo (ver Finanzas) |

La tabla de muestra `finanzas_muestra` de la Fase 0 se borró en la Fase 1 (la reemplazan las tablas `fin_*`).

**Matriz (`permisos_rol`).** Es la de `docs/specs/fase-0-cimientos.md`, sección 5, con una columna `alcance`:

| Alcance | Significa | Ejemplo |
|---|---|---|
| `total` | Todo el módulo en el hogar | Dueño en Cuidados, Casa y Ajustes |
| `propio` | Solo los registros de la persona | Hábitos para todos (ni el dueño ve los de otros, D13); Ajustes "lo propio"; GRAVITY (D18) y Finanzas (D19, por libro) |
| `restringido` | Un subconjunto que el módulo define en su fase (la `nota` dice cuál) | Cuidador en Cuidados: "su turno" (Fase 5) |

Sin fila = sin acceso. `restringido` tampoco da acceso mientras el módulo no defina su regla en su fase: hoy el coadministrador **no** entra a Cuidados (hasta que exista el consentimiento, Fase 5), el cuidador **no lee** Finanzas (solo escribirá sus gastos de cuidado, Fase 5) y su GRAVITY `restringido` (D18: sus solicitudes y recordatorios) espera su regla propia.

El módulo `gravity` no está en la sección 5; se alineó con el espejo de la app en la revisión de la Fase 0 (hallazgo I1). Con D18 (migración de la Fase 1): dueño, coadministrador, familiar y casa `propio` (cada quien su historial); cuidador `restringido` en leer y escribir. Con D19, Finanzas es `propio` para dueño y coadministrador (leer, escribir y administrar): qué libro ve cada quien lo decide `fin_puede()`. La matriz queda con **59 filas**. Si cambias la matriz, cambia también el espejo (`app/lib/nucleo/permisos/permisos.dart`): la prueba `app/test/revision_calidad/i1_matriz_espejo_servidor_test.dart` lee los `insert into public.permisos_rol` de **todas** las migraciones y compara las acciones (no el alcance). Usa solo `total`, `propio` o `restringido` (el dominio no acepta otros y la prueba de la app solo reconoce esos).

**Funciones para las reglas** (SECURITY DEFINER, `search_path` vacío; las pueden usar las reglas de cualquier tabla):

| Función | Devuelve |
|---|---|
| `persona_actual()` | `personas.id` de la sesión |
| `rol_en_hogar(hogar)` | Rol **vigente** de la sesión en el hogar (nulo si no es miembro o está dado de baja) |
| `alcance(hogar, modulo, accion)` | `total`, `propio`, `restringido` o nulo |
| `puede(hogar, modulo, accion)` | Verdadero **solo** con alcance `total` |
| `puede_sobre(hogar, modulo, accion, persona)` | `total`, o `propio` si el registro es de la sesión |
| `puede_ver_persona(persona)` | Para la regla de `personas`. Desde la Fase 1 también: quien comparte un libro de Finanzas ve a sus miembros y a su titular; la cuenta maestra a todos los del hogar |
| `mis_permisos(hogar)` | Los permisos del rol de la sesión (espejo para la app) |

Un módulo o acción mal escrito en una regla **lanza error** en lugar de negar en silencio.

**Operaciones (RPC) para la app:** `crear_hogar(nombre)` (quien lo crea queda como dueño); `crear_invitacion(hogar, correo, rol, dias)` (solo dueño; devuelve el token **una vez**); `aceptar_invitacion(token)` (correo confirmado igual al invitado); `revocar_invitacion(id)`.

**Solo agregar.** `impedir_cambios_solo_agregar()` es un trigger reutilizable que bloquea UPDATE, DELETE y TRUNCATE para cualquier rol, también para el dueño de la tabla. La bitácora además no tiene reglas de UPDATE ni DELETE ni esos privilegios. Los cambios de `hogares`, `membresias`, `invitaciones` y de todas las tablas `fin_*` se registran solos con `registrar_cambio_en_bitacora()`.

**Privilegios.** Supabase concede todo por defecto a `anon` y `authenticated`; la migración revoca y concede solo lo necesario, por columna cuando aplica (p. ej. nadie puede fijar `persona_id` ni `registrado_en` de la bitácora: los pone el servidor). `anon` no tiene acceso a nada.

**Red de seguridad para lo que se cree después** (hallazgo M1), por si una migración olvida revocar: las funciones nuevas no se pueden ejecutar desde `PUBLIC` ni `anon` (PostgreSQL da `EXECUTE` a `PUBLIC` en todos los esquemas, por eso se revoca sin `in schema`); las tablas nuevas no dan nada a `anon`, ni `TRUNCATE`, `REFERENCES` o `TRIGGER` a `authenticated`, ni `TRUNCATE` a `service_role`. Ojo: una función nueva en `public` **sí** la ejecuta `authenticated` (privilegio de Supabase) y queda expuesta como RPC: revoca si no es para la app.

**Bitácora.** Las entradas automáticas (`insertar`, `actualizar`, `borrar`) solo las escribe `registrar_cambio_en_bitacora()`; la regla de inserción las rechaza para cualquier sesión de la app, también la cuenta Casa (hallazgo M2). El formato de `accion` impide acciones parecidas (`Borrar`, ` borrar`, letras de otro alfabeto) para todos, también `service_role`.

## Finanzas (Fase 1)

Migración `20261021000000_finanzas_mvp1.sql`, según `docs/specs/fase-1-finanzas.md` v0.2 (secciones 4.1 a 4.5), D18 y D19. Todas las tablas `fin_*` llevan `hogar_id`, RLS, privilegios por columna y bitácora automática. Dinero en `bigint` de centavos; porcentajes y tasas en puntos base (`integer`, 2000 = 20 %).

### Libros (D19)

| Tabla | Qué guarda |
|---|---|
| `fin_libros` | `id`, `hogar_id`, `nombre`, `tipo` (`personal`, `compartido`, `representado`), `titular_id` (obligatorio en personal y representado, nulo en compartido), `activo`, `creado_por`, `creado_en`. Un personal por persona y hogar |
| `fin_libro_miembros` | `id`, `hogar_id`, `libro_id`, `persona_id`, `papel` (`titular`, `miembro`, `albacea`, `albacea_suplente`), `desde`, `hasta`. Personal: solo su titular. Compartido: `miembro`. Representado: 1 `albacea` y, opcional, 1 `albacea_suplente` vigentes. Solo adultos con Finanzas (dueño o coadministrador). No se borran: se cierra `hasta` |

- El **libro personal** lo crea el servidor al dar un rol con Finanzas (al crear el hogar, al aceptar una invitación de coadministrador o al cambiar el rol), con sus cuentas de sistema **Ajustes**, **Apertura** y **Por clasificar** y su fila de `fin_parametros`. La app lo busca (`tipo = 'personal'` y `titular_id` = su persona); no lo crea.
- Un **compartido** lo crea cualquier adulto con Finanzas (insert en `fin_libros`); quien lo crea queda como miembro y agrega a los demás.
- El **representado** (papá, sin cuenta) se crea con `fin_crear_libro_representado(hogar, nombre_titular, nombre_libro, libro_id)` (solo el dueño; crea la persona sin cuenta; quien lo crea queda como albacea; con `libro_id` es idempotente).

### Tablas de Finanzas

| Tabla | Es de | Escribe | Notas |
|---|---|---|---|
| `fin_categorias` | hogar | `administrar` | Árbol común de 3 niveles; único (`hogar_id`, `padre_id`, `nombre`); se borra solo sin datos, con datos `archivada` |
| `fin_cuentas` | libro, o **hogar** si es `de_gasto` o `gasto_financiero` | `administrar` | `clase` y `liquida` generadas; único (`hogar_id`, `libro_id`, `nombre`); cerrar o archivar solo con saldo cero (confirmado y con pendientes); borrar solo sin movimientos; las de sistema no cambian de tipo ni de estado. `titular_id` de la v0.1 lo reemplaza `libro_id` |
| `fin_parametros` | libro (PK `libro_id`) | `administrar` (UPDATE) | Nace con los valores por defecto (5.6 bis, 5.9 bis) y los ids de las cuentas de sistema, que no cambian |
| `fin_movimientos` | sus **dos** libros | `escribir` en cada libro que toca | **Solo agregar.** Validación de 4.3; `libro_origen_id` y `libro_destino_id` los pone el servidor; `en_nombre_de` (albacea, motivo obligatorio) |
| `fin_ingresos`, `fin_vigencias_ingreso` | libro | `administrar` | Vigencias: `forma` `semanal`/`catorcenal`/`quincenal`/`mensual`/`cada_meses` (+ `intervalo_meses`), `dias_mes` con uno o varios días (`{1,11}`; 0 = último); no se traslapan; `libro_id` de la vigencia lo pone el servidor |
| `fin_compromisos`, `fin_sobres` | libro | `administrar` | Su cuenta es una cuenta de gasto del hogar; `regla_inhabil` por compromiso (por defecto `sin_cambio`) |
| `fin_deudas` | libro | `administrar` | Cuenta pasivo del mismo libro; tasa > 0 solo en `con_costo`; `grupo_prioritario` + `orden_grupo`; `regla_inhabil` (por defecto `sin_cambio`) |
| `fin_dias_inhabiles` | hogar | `administrar` | `revisado_por`/`revisado_en` los pone el servidor al cambiar `activo` |
| `fin_semanas` | libro | `escribir` | Lunes; única por (`libro_id`, `semana_inicio`); cascada `remanente_plan = ingreso − presupuesto − deuda_plan` (check); `activada_por/en` y `reaperturas` los pone el servidor |
| `fin_partidas_semana`, `fin_abonos_semana` | libro de su semana | `escribir` | No cambian si la semana está cerrada |
| `fin_ocurrencias` | libro | `escribir` | Única por (`libro_id`, `origen`, `origen_id`, `fecha_programada`). En semana cerrada no se agregan ni cambian fecha o monto (el estado y el movimiento sí) |
| `fin_cierres`, `fin_cierre_partidas`, `fin_cierre_abonos` | libro de su semana | `escribir` | **Solo agregar.** `version` = reaperturas + 1; `patrimonio = activos − pasivos`; `diferido` generado. Las tres llevan `id` (para la cola) |
| `fin_conciliaciones` | libro de su cuenta | `escribir` | **Solo agregar.** `diferencia` generada; con diferencia exige el ajuste (contra Ajustes del libro, mismo monto, fecha y dirección) y motivo |
| `fin_importaciones` | hogar | `administrar` | **Solo agregar.** `detalle` hasta 256 KB (no se copia a la bitácora) |

**Vistas** (`security_invoker`, respetan la RLS): `fin_v_saldos` (`hogar_id`, `libro_id`, `cuenta_id`, `nombre`, `tipo`, `clase`, `liquida`, `estado`, `saldo_centavos` confirmado con el signo de su clase, `saldo_con_pendientes_centavos`; las cuentas de gasto del hogar salen una vez por libro) y `fin_v_gasto_semana` (`hogar_id`, `libro_id`, `semana_inicio`, `cuenta_id`, `nombre`, `tipo`, `gasto_centavos`).

### Quién ve y escribe qué

| Función | Devuelve |
|---|---|
| `fin_puede(libro, accion)` | `leer`: miembro vigente o cuenta maestra. `escribir`: titular, miembro o albacea (el suplente solo si no hay albacea vigente), con el libro activo. `administrar`: titular de un personal, miembro de un compartido, albacea de un representado. Siempre exige un rol con Finanzas |
| `fin_puede_hogar(hogar, accion)` | Lo del hogar (categorías, cuentas de gasto, días inhábiles, importaciones): rol con Finanzas; la maestra además lee |
| `fin_es_miembro(libro)` | Miembro vigente del libro |
| `es_cuenta_maestra(hogar)` | La sesión es la cuenta maestra vigente |
| `puede_ver_entrada_bitacora(...)` | Regla de lectura de la bitácora (abajo) |

- Dueño y coadministrador: su libro y los compartidos de los que son miembros; la pareja **no** ve el libro personal del dueño, ni al revés. Familiar, cuidador y casa: nada de `fin_*`.
- **Cuenta maestra** (`membresias.es_maestra`): una por hogar, solo dueño o coadministrador, la asigna el dueño con `asignar_cuenta_maestra(hogar, persona)` (nulo la quita). Lee todo (libros, bitácora, historial de GRAVITY); nunca escribe en lo ajeno. La app llama `fin_registrar_consulta_maestra(libro)` al abrir un libro ajeno (acción `finanzas.consulta_maestra`, visible para quienes llevan ese libro). `cuenta_maestra(hogar)` dice a cualquier miembro si existe y de quién es.
- **Bitácora:** cada quien ve lo suyo; la maestra todo; las entradas `gravity.*` solo su autor (D18); las de `fin_*` y `finanzas.*`, quien puede leer su libro (o, si son del hogar, quien tiene Finanzas); lo demás (membresías, invitaciones…), el dueño.

### Contrato para la app (cola sin conexión y repositorios)

- **Idempotencia.** Todas las tablas `fin_*` tienen `id`. La cola sube con `upsert(onConflict: 'id', ignoreDuplicates: true)` (`INSERT … ON CONFLICT (id) DO NOTHING`):
  - Mismo `id` y mismo contenido: **no inserta nada y no falla** (0 filas; también con `INSERT` simple). Vale aunque desde entonces la cuenta se haya congelado, el movimiento ya tenga anulación o la semana se haya cerrado.
  - Mismo `id` con **otro contenido** en los libros solo agregar (`fin_movimientos`, `fin_conciliaciones`, `fin_cierres*`, `fin_importaciones`): **23505** con `ON CONFLICT DO NOTHING` o sin él (el cambio no se pierde en silencio: queda en "requiere atención"). En configuración y plan, `ON CONFLICT DO NOTHING` lo ignora si pasa las validaciones (para editar se usa `UPDATE` o `upsert` sin `ignoreDuplicates`).
  - No se comparan las columnas que pone el servidor: `recibido_en`, `libro_*` derivados, generadas, `creado_en`/`cerrado_en`.
- **Movimientos:** `registrado_en` es **obligatorio** (si faltara, cada reenvío sería distinto). No mandes `recibido_en`, `libro_origen_id` ni `libro_destino_id` (no tienen permiso de columna). `registrado_por` y `realizado_por` toman la sesión por omisión.
- **Columnas que la app puede mandar y el servidor sobrescribe:** `fin_cuentas.creada_por`, `fin_dias_inhabiles.revisado_por/revisado_en`, `fin_semanas.activada_por/activada_en`. `cerrado_en` y `creado_en` de cierres, conciliaciones e importaciones sí se aceptan del dispositivo.
- **Orden de subida:** cuentas → movimientos; el movimiento de **ajuste** antes que su **conciliación**; **cierre** (y sus partidas y abonos) antes de cambiar la semana a `cerrada`; reabrir = `UPDATE` solo del `estado` (a `activa`, `pendiente_ingreso` o `por_cerrar`).
- **Errores:** `23503` = falta algo de lo que depende (otra cuenta, el original de una anulación…; la cola reintenta). `23505` = duplicado o mismo id con otro contenido. `23514` = check de la tabla (monto, motivo, lunes, cascada…). `22023` = regla de negocio (combinación de cuentas, libro equivocado, papel…). `55000` = estado (cuenta no activa, semana cerrada). `42501` = sin permiso o columna que no cambia. Ninguno es de las clases que la cola reintenta (08, 40001, 40P01, 53, 57).
- **Entre libros:** solo `transferencia` y `pago_deuda` (y su anulación) cruzan de un libro a otro; se ven desde los dos. Ojo para el cuadre por libro: una aportación cambia el patrimonio de cada libro sin pasar por el resultado.

## Pruebas

```bash
supabase/tests/correr.sh            # resumen por archivo
supabase/tests/correr.sh -v         # cada afirmación
supabase/tests/correr.sh 20_finanzas_roles.sql 27_finanzas_idempotencia.sql
```

Crea una base desechable, aplica `tests/00_emulacion_supabase.sql` (roles `anon`, `authenticated`, `service_role`, `auth.users` y `auth.uid()` como en Supabase), las migraciones (cada una en su transacción), `seed.sql` y `tests/01_utilidades.sql`; luego corre cada `tests/NN_*.sql` (de 10 a 99) dentro de `begin … rollback`. Sale con error si algo falla.

| Archivo | Comprueba |
|---|---|
| `10_esquema.sql` | RLS en **todas** las tablas de `public` (también las futuras); funciones SECURITY DEFINER con `search_path`; `anon` sin privilegios; nadie con TRUNCATE; matriz (59 filas, D18 y D19) y su alineación con la app (I1); persona automática al registrarse; privilegios por omisión de lo que se cree después (M1); las 21 tablas `fin_*` con `hogar_id` y bitácora, los libros solo agregar sin UPDATE/DELETE/TRUNCATE ni reglas para eso, vistas con `security_invoker`, una cuenta maestra por hogar |
| `20_finanzas_roles.sql` | **Criterio 26 con D19:** cada quien ve y registra en su libro y en los compartidos; la pareja no ve el libro personal de la dueña (en ninguna tabla ni vista) ni al revés; la aportación al compartido se ve desde los dos libros; familiar, cuidador y casa no ven nada de `fin_*` (tablas, vistas, bitácora) ni escriben; nadie registra a nombre de otro; la baja quita el acceso |
| `21_finanzas_albacea.sql` | **D19:** el albacea registra en nombre de Papá con motivo (sin motivo falla); con albacea vigente el suplente solo lee; máximo un albacea y un suplente, solo adultos con Finanzas; si el albacea deja el cargo, el suplente escribe; `fin_crear_libro_representado` (solo dueño, idempotente) |
| `22_finanzas_solo_agregar.sql` | **Criterios 25, 9 y 16:** nadie (ni dueña, ni `service_role`, ni `postgres`) edita, borra ni vacía movimientos, conciliaciones, cierres o importaciones; un gasto de una semana cerrada se corrige con anulación y contraasiento y la semana se recalcula; la foto del cierre no cambia; reglas de la anulación |
| `23_finanzas_libro.sql` | Sección 4.3: cada combinación válida e inválida por tipo, montos, cuentas inexistentes o de otro hogar, movimientos entre libros, columnas que pone el servidor, pendientes y cuentas congeladas |
| `24_finanzas_cuentas.sql` | **Criterio 15:** no se borra una cuenta con movimientos; se cierra o archiva solo con saldo cero; cuentas de sistema; tipos y libros; categorías de 3 niveles, se borran solo sin datos y se archivan |
| `25_finanzas_conciliacion.sql` | **Criterio 14:** la conciliación con diferencia exige su ajuste con motivo (dirección, monto y fecha correctos), queda en la bitácora y el ajuste se ve |
| `26_finanzas_semanas.sql` | **Criterio 24:** cierre con pendientes, la semana cerrada no cambia, se reabre (solo el estado, en la bitácora) y se vuelve a cerrar con la versión 2 del cierre |
| `27_finanzas_idempotencia.sql` | **Criterio 27:** reenviar el mismo id con el mismo contenido no duplica ni falla (con y sin `ON CONFLICT DO NOTHING`, también anulaciones, aperturas y partidas de semanas ya cerradas); con otro contenido, 23505 |
| `28_finanzas_maestra.sql` | **D19 y D18:** la cuenta maestra lee todo y no escribe en lo ajeno; sus consultas quedan en la bitácora; cualquier miembro ve que existe; solo el dueño la asigna (nunca familiar ni Casa); la dueña ya no ve el historial de GRAVITY ni las finanzas personales de otros en la bitácora |
| `29_finanzas_configuracion.sql` | Pensión de Papá (días 1 y 11) y apoyo bimestral; vigencias sin traslape; ingresos, deudas (grupo prioritario, tasas), compromisos y sobres; `regla_inhabil` por defecto `sin_cambio`; parámetros por libro; días inhábiles; libros compartidos e inactivos; libro personal automático |
| `30_bitacora.sql` | Nadie la actualiza, borra ni vacía (cada rol, `service_role` y el dueño de la tabla); cada quien agrega solo a su nombre y en su hogar; nadie usa las acciones reservadas a los triggers (M2) |
| `40_aislamiento_hogares.sql` | Una persona de otro hogar no ve ni toca nada |
| `50_invitaciones.sql` | Solo el dueño las ve y crea; token solo en hash; correo confirmado; expiración, revocación y reuso; volver al hogar con la membresía vencida (M3) |
| `60_anon.sql` | Sin sesión no se ve ni se ejecuta nada, aun con un `sub` falsificado |
| `70_membresias_personas.sql` | El cuidador no ve a la familia y su GRAVITY es restringido (D18); el coadministrador no entra a Cuidados; el dueño, GRAVITY propio (D18); quien comparte un libro ve a sus miembros (D19); roles, bajas y fechas de fin; lo propio; dispositivos |

Los casos de la revisión de calidad de la Fase 0 (`docs/revisiones/fase-0.md`: I1, M1, M2 y M3) viven en estos archivos con la clave del hallazgo al inicio de su descripción (p. ej. `M2: …`); `hallazgos_fase0.sql` ya no existe.

**Requisitos:** PostgreSQL 15 o superior con el servidor (`initdb`, `pg_ctl`). En Ubuntu: `apt-get install postgresql-16`. El script busca los binarios en el PATH, con `pg_config` o en `/usr/lib/postgresql/*/bin` (o usa `PG_BIN`). El clúster temporal solo escucha por un socket en `/tmp/gravity-pg.*` y se borra al terminar; como root corre el servidor con el usuario `postgres`. En Windows, córrelo en WSL.

**Variables:** `GRAVITY_PG_URL` usa un servidor existente en lugar del clúster temporal (crea y borra una base de prueba; p. ej. el Postgres de Supabase local, `postgresql://postgres:postgres@127.0.0.1:54322/postgres`); `GRAVITY_PG_MANTENER=1` deja el clúster encendido para revisarlo.

**Ayudantes** (`tests/01_utilidades.sql`): `pruebas.como('correo')`, `pruebas.como_anon()`, `pruebas.como_servicio()`, `pruebas.como_postgres()`, `pruebas.ok`, `pruebas.igual`, `pruebas.cuenta(sql)`, `pruebas.afecta(sql)`, `pruebas.falla(sql, desc, sqlstate)`; de Finanzas: `pruebas.libro_personal('correo')`, `pruebas.cuenta_sistema(libro, tipo)` y `pruebas.registrar(tipo, origen, destino, monto, …)` (inserta un movimiento como la sesión y devuelve su id, o nulo si el servidor no insertó nada por ser un reenvío idéntico).

## Datos de ejemplo (`seed.sql`)

Hogar Ejemplo, el hogar de Ana y Alex del diseño de FINANZAS: `ana@` dueña, `alex@` coadministrador (la pareja), `carla@` familiar, `diana@` cuidador, `casa@` casa y `marta@` coadministrador con la **cuenta maestra** (cuenta aparte, como recomienda D19); "Papá (ejemplo)" es la persona bajo cuidado, **sin cuenta**. Hogar Vecino (`elena@`, dueña) y `nuevo@` sin hogar con una invitación pendiente (token `token-de-ejemplo-solo-local`). Todos en `@ejemplo.test`.

Finanzas (montos inventados, inspirados en el ejemplo 5.6 bis): libros personales de Ana, Alex y Marta (los crea el servidor), "Gastos de la casa" (`f100…0001`, compartido por Ana y Alex) y "Papá (ejemplo)" (`f100…0002`, representado: Ana albacea, Alex suplente) con su pensión los días 1 y 11 (siguiente día hábil) y un apoyo bimestral. Árbol común de 21 categorías y 12 cuentas de gasto del hogar; cuentas, ingresos, compromisos, sobres, deudas (grupo prioritario), aperturas, gastos, aportaciones al compartido, movimientos en nombre de Papá, una conciliación con ajuste, la semana del 12/oct cerrada con su cierre y la del 19/oct activa, ocurrencias, días inhábiles y una importación. El seed carga cada parte "como" quien lo haría en la app (pasa por las mismas validaciones del servidor). Las cuentas **no tienen contraseña**: nadie puede entrar con ellas aunque el seed llegara por error a un proyecto real. Para entrar en Supabase local, ponles contraseña en Studio (*Authentication › Users*) o crea tus propias cuentas.

## Aplicar las migraciones al proyecto real

**Nunca** apliques `seed.sql` ni `tests/` al proyecto real.

**Con la CLI de Supabase (recomendado):**

```bash
supabase login
supabase init                         # solo si falta supabase/config.toml; revisa con git status que no toque migrations ni seed
supabase link --project-ref <ref-del-proyecto>
supabase db push --dry-run            # muestra qué migraciones aplicaría
supabase db push                      # sin --include-seed
```

La CLI guarda el historial en `supabase_migrations.schema_migrations` y aplica cada migración en una transacción. Desde la laptop usa la conexión *Session pooler* si la directa (IPv6) no conecta.

**Con el editor SQL del panel:** pega cada archivo de `migrations/` en orden y ejecútalo completo. Como así no queda historial, si después usas la CLI marca las ya aplicadas: `supabase migration repair --status applied 20261020000000`.

**Después de aplicar la base:**
- En *Authentication › Providers › Email* mantén **Confirm email** activo: `aceptar_invitacion` exige correo confirmado.
- Crea tu cuenta y tu hogar: desde la app, con `crear_hogar('Nombre')` (quien lo llama queda como dueño). Si aún no hay pantalla para eso, en el editor SQL (que corre sin sesión de usuario):

  ```sql
  with h as (insert into public.hogares (nombre) values ('Mi hogar') returning id)
  insert into public.membresias (hogar_id, persona_id, rol)
  select h.id, p.id, 'dueno'
  from h, public.personas p join auth.users u on u.id = p.usuario_id
  where u.email = 'tu-correo@ejemplo.test';  -- cambia por el correo de tu cuenta
  ```

  Luego invita a los demás con `crear_invitacion` desde la app.
- Las cuentas que ya existían antes de la migración reciben su persona automáticamente.
- Con `20261021000000_finanzas_mvp1.sql` (Finanzas), el dueño y el coadministrador reciben solos su libro personal (también los que ya existían). El libro compartido lo crea la app; el de papá, `fin_crear_libro_representado()`; la cuenta maestra, `asignar_cuenta_maestra()` (los tres, desde la app con la sesión del dueño).

**Desarrollo con Supabase local** (Docker): `supabase start` y `supabase db reset` (migraciones + seed). `supabase/.branches` y `supabase/.temp` están ignoradas por git.

**Nota:** `20261020000000_base.sql` se corrigió en el mismo archivo tras la revisión de calidad de la Fase 0, y `20261021000000_finanzas_mvp1.sql` se ha ajustado en su archivo durante la Fase 1, porque ninguna se ha aplicado al proyecto real. Si ya la tenías en Supabase local, corre `supabase db reset`. Desde que se aplique al proyecto real, todo cambio va en una migración nueva.

## Convenciones para migraciones nuevas

1. Archivo nuevo `AAAAMMDDHHMMSS_descripcion.sql`; nunca editar una migración ya aplicada. Compatible con PostgreSQL 15.
2. Cada tabla nueva: `enable row level security`; `revoke all … from public, anon, authenticated, service_role` y `grant` explícito (por columna si hay columnas que pone el servidor); reglas `to authenticated` con `puede()` / `puede_sobre()` / `alcance()`.
3. Funciones SECURITY DEFINER con `set search_path = ''` y nombres calificados; `revoke execute … from public, anon, authenticated` y `grant` a quien corresponda (en `public`, `authenticated` las recibe por omisión y quedan como RPC).
4. Dinero en `bigint` de centavos; fechas `date` / `timestamptz`; UUID que puede generar el dispositivo (cola sin conexión idempotente).
5. Libros solo-agregar: sin reglas ni privilegios de UPDATE/DELETE y los dos triggers de `impedir_cambios_solo_agregar()` (fila y TRUNCATE), como en `bitacora` y en los libros de Finanzas. Con la cola sin conexión: trigger `fin_una_vez('estricto', <columnas del servidor>)` (o uno propio, como el de `fin_movimientos`) para que un reenvío idéntico no falle.
9. Los errores de los triggers usan 23xxx, 22xxx, 42501 o 55000; nunca clases que la cola reintenta (08, 40001, 40P01, 53, 57). 23503 solo para "falta algo de lo que depende" (la cola lo reintenta).
10. Dentro de un `IF` de PL/pgSQL, envuelve cada `CASE` en paréntesis (si no, su `THEN` corta la condición). Un trigger compartido por varias tablas no lee en una misma expresión columnas que solo tiene una de ellas.
6. Cambios que importan: trigger `registrar_cambio_en_bitacora('hogar_id', <columnas a omitir>)`. Las entradas que agregue la app usan acciones propias en minúsculas (nunca `insertar`, `actualizar` ni `borrar`).
7. Pruebas nuevas en `tests/NN_*.sql`. Las de `10_esquema.sql` y `60_anon.sql` ya revisan solas que toda tabla nueva tenga RLS y que `anon` no la vea.
8. Si la migración llena una tabla de catálogo, agrégala a `$script:TablasDeMigracion` en `herramientas/respaldo/respaldo_comun.ps1`.

## Pendientes conocidos

| De la revisión | Qué | Cuándo |
|---|---|---|
| M2 (parte 2) | Límite de entradas por persona en la bitácora (hoy cada miembro puede agregar sin límite, hasta 32 KB por entrada). Conviene hacerlo junto con la cola sin conexión de la app (I4, M16), para que un rechazo no se pierda en silencio, y con un trigger por sentencia (una inserción en lote se salta un conteo por fila) | Fase 1 |
| M4 | Hogar preferido o función `mi_perfil()` para que la app no elija al azar entre dos hogares | Con plataforma |
| M13 | Un mismo token de avisos puede quedar a nombre de varias personas (tablet compartida): token único global con una función que lo reasigne, o avisos de la tablet solo a la cuenta Casa | Fase 2 |
| M15 | Mantener activa la confirmación de correo en Supabase Auth (`aceptar_invitacion` confía en ella) | Al crear el proyecto (dueño) |
| Fase 1 | Las reglas de `fin_*` llaman `fin_puede()` por fila; con muchos datos conviene cambiarlas por una lista de libros legibles calculada una vez por consulta | Si la pantalla de movimientos pasa de 2 s |
| Fase 1 | Cualquier miembro puede agregar a la bitácora una entrada con `tabla` `fin_*` y un `libro_id` en el detalle; la verán quienes lean ese libro (con su autor real). Restringir `tabla` en las entradas que agrega la app | Con M2 (parte 2) |
| Fase 5 | Gastos de cuidado de la cuidadora (`finanzas` × `escribir` restringido) y GRAVITY restringido de la cuidadora: necesitan su regla propia (hoy no escriben) | Fase 5 |

## Respaldos

Ver `herramientas/respaldo/README.md` (respaldo diario cifrado desde la laptop y restauración).
