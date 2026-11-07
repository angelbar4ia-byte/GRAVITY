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
| `invitaciones` | Invitación a un hogar: correo, rol, **hash** del token, expiración, aceptación, revocación y, desde el 23/oct, `es_maestra` (la persona invitada será la cuenta maestra; solo con rol `coadministrador`) | Solo el dueño |
| `dispositivos` | Dispositivos de cada persona y su token de avisos (FCM) | Cada quien los suyos |
| `bitacora` | Auditoría **solo agregar**: quién (`persona_id`), qué (`accion`), cuándo (`ocurrido_en`, `registrado_en`), `tabla`, `registro_id`, `detalle`. `accion` en minúsculas (`^[a-z][a-z0-9_.]*$`, p. ej. `entrega_de_turno`, `gravity.abrir`); `insertar`, `actualizar` y `borrar` están **reservadas** a los triggers. Lo que la app escribe directo tiene **tope** (4 KB por entrada, 500 por persona en 24 horas; ver "Endurecimiento de la Fase 1b") | Cada quien lo que él hizo; el dueño lo del hogar **salvo** el historial de GRAVITY (`gravity.*`, D18) y las finanzas de libros que no lleva (D19); la cuenta maestra todo (ver Finanzas) |

La tabla de muestra `finanzas_muestra` de la Fase 0 se borró en la Fase 1 (la reemplazan las tablas `fin_*`).

**Matriz (`permisos_rol`).** Es la de `docs/specs/fase-0-cimientos.md`, sección 5, con una columna `alcance`:

| Alcance | Significa | Ejemplo |
|---|---|---|
| `total` | Todo el módulo en el hogar | Dueño en Cuidados, Casa y Ajustes |
| `propio` | Solo los registros de la persona | Hábitos para todos (ni el dueño ve los de otros, D13); Ajustes "lo propio"; GRAVITY (D18) y Finanzas (D19, por libro) |
| `restringido` | Un subconjunto que el módulo define en su fase (la `nota` dice cuál) | Cuidador en Cuidados: "su turno" (Fase 5) |

Sin fila = sin acceso. `restringido` tampoco da acceso mientras el módulo no defina su regla en su fase: hoy el coadministrador **no** entra a Cuidados (hasta que exista el consentimiento, Fase 5), el cuidador **no lee** Finanzas (solo escribirá sus gastos de cuidado, Fase 5) y su GRAVITY `restringido` (D18: sus solicitudes y recordatorios) espera su regla propia.

El módulo `gravity` no está en la sección 5; se alineó con el espejo de la app en la revisión de la Fase 0 (hallazgo I1). Con D18 (migración de la Fase 1): dueño, coadministrador, familiar y casa `propio` (cada quien su historial); cuidador `restringido` en leer y escribir. Con D19, Finanzas es `propio` para dueño y coadministrador (leer, escribir y administrar): qué libro ve cada quien lo decide `fin_puede()`. La matriz queda con **61 filas** (59 más las 2 del familiar en Cuidados, Fase 5). Si cambias la matriz, cambia también el espejo (`app/lib/nucleo/permisos/permisos.dart`): la prueba `app/test/revision_calidad/i1_matriz_espejo_servidor_test.dart` lee los `insert into public.permisos_rol` de **todas** las migraciones y compara las acciones (no el alcance). Usa solo `total`, `propio` o `restringido` (el dominio no acepta otros y la prueba de la app solo reconoce esos).

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

**Bitácora.** Las entradas automáticas (`insertar`, `actualizar`, `borrar`) solo las escribe `registrar_cambio_en_bitacora()`; la regla de inserción las rechaza para cualquier sesión de la app, también la cuenta Casa (hallazgo M2). El formato de `accion` impide acciones parecidas (`Borrar`, ` borrar`, letras de otro alfabeto) para todos, también `service_role`. Desde la Fase 1 también están reservadas al servidor las acciones `finanzas*` y las entradas de tablas `fin_*` (hallazgo I5 de la revisión de la Fase 1). Desde la Fase 1b lo que la app escribe directamente en la bitácora tiene tope por persona (hallazgo N1): 4 KB por entrada y 500 entradas en 24 horas, con 54000 al excederlo; los triggers, las funciones del servidor y `service_role` no cuentan ni se limitan.

## Finanzas (Fase 1)

Migraciones `20261021000000_finanzas_mvp1.sql` (tablas, reglas y triggers), según `docs/specs/fase-1-finanzas.md` v0.2 (secciones 4.1 a 4.5), D18 y D19, `20261023000000_finanzas_salvaguardas.sql` (hallazgos I1 a I5, M6 y M10 de la revisión de calidad, `docs/revisiones/fase-1.md`) y `20261024000000_finanzas_respuestas_dueno.sql` (respuestas del dueño del 23/oct: cuenta maestra con login propio y solo lectura, libros compartidos privados o públicos, cuentas de periodo) `20261025000000_finanzas_compartidos_privados.sql` (2.ª ronda del 23/oct: un compartido que se queda con menos de 2 miembros pasa a privado y sigue activo, el último miembro no se sale, y `fin_adultos_con_finanzas`) `20261026000000_finanzas_endurecimiento_1b.sql` (hallazgos N1 a N5 de la revisión `docs/revisiones/fase-1b.md`: tope de la bitácora, motivo de 3 caracteres visibles, aviso de toda salida del libro de papá, `fin_nombrar_albacea` y relevo del administrador por baja) y `20261027000000_finanzas_portada_representado.sql` (el dueño del hogar ve siempre la portada del libro de papá); ver las secciones "Respuestas del dueño del 23/oct", "Endurecimiento de la Fase 1b" y "Portada del libro de papá para el dueño". Todas las tablas `fin_*` llevan `hogar_id`, RLS, privilegios por columna y bitácora automática. Dinero en `bigint` de centavos; porcentajes y tasas en puntos base (`integer`, 2000 = 20 %).

### Libros (D19)

| Tabla | Qué guarda |
|---|---|
| `fin_libros` | `id`, `hogar_id`, `nombre`, `tipo` (`personal`, `compartido`, `representado`), `titular_id` (obligatorio en personal y representado, nulo en compartido), `activo`, `visibilidad` (`privada` por omisión | `publica`, solo en compartidos), `creado_por`, `creado_en`. Un personal por persona y hogar |
| `fin_libro_miembros` | `id`, `hogar_id`, `libro_id`, `persona_id`, `papel` (`titular`, `miembro`, `albacea`, `albacea_suplente`), `desde`, `hasta`. Personal: solo su titular. Compartido: `miembro`. Representado: 1 `albacea` y, opcional, 1 `albacea_suplente` vigentes. Solo adultos con Finanzas (dueño o coadministrador). No se borran: se cierra `hasta` |

- El **libro personal** lo crea el servidor al dar un rol con Finanzas (al crear el hogar, al aceptar una invitación de coadministrador o al cambiar el rol), con sus cuentas de sistema **Ajustes**, **Apertura** y **Por clasificar** y su fila de `fin_parametros`. La app lo busca (`tipo = 'personal'` y `titular_id` = su persona); no lo crea.
- Un **compartido** lo crea cualquier adulto con Finanzas que **no sea una cuenta maestra de solo lectura** (insert en `fin_libros`); quien lo crea queda como miembro y como su **administrador** (`creado_por`) y agrega a los demás.
- El **representado** (papá, sin cuenta) se crea con `fin_crear_libro_representado(hogar, nombre_titular, nombre_libro, libro_id)` (solo el dueño; crea la persona sin cuenta; quien lo crea queda como albacea; con `libro_id` es idempotente).

### Tablas de Finanzas

| Tabla | Es de | Escribe | Notas |
|---|---|---|---|
| `fin_categorias` | hogar | `administrar` | Árbol común de 3 niveles; único (`hogar_id`, `padre_id`, `nombre`); se borra solo sin datos, con datos `archivada`. **Archivar una categoría archiva su cuenta de gasto** (si ninguna otra categoría activa la usa) y desarchivarla la reactiva |
| `fin_cuentas` | libro, o **hogar** si es `de_gasto` o `gasto_financiero` | `administrar` | `clase` y `liquida` generadas; único (`hogar_id`, `libro_id`, `nombre`); cerrar o archivar **solo con saldo cero (confirmado y con pendientes) las cuentas de activo y pasivo**; las de gasto e ingreso son de periodo y se cierran o archivan con saldo; borrar solo sin movimientos (en una cuenta archivada de gasto o ingreso sí se anula un movimiento); las de sistema no cambian de tipo ni de estado. `titular_id` de la v0.1 lo reemplaza `libro_id` |
| `fin_parametros` | libro (PK `libro_id`) | `administrar` (UPDATE) | Nace con los valores por defecto (5.6 bis, 5.9 bis) y los ids de las cuentas de sistema, que no cambian |
| `fin_movimientos` | sus **dos** libros | `escribir` en cada libro que toca | **Solo agregar.** Validación de 4.3; `libro_origen_id` y `libro_destino_id` los pone el servidor; en el libro de Papá **todo** movimiento lleva `en_nombre_de` y motivo (I3) |
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
| `fin_puede(libro, accion)` | `leer`: miembro vigente; la cuenta maestra **con una consulta registrada en ese libro en los últimos 30 minutos** (I2; también si el libro es público); y, en un compartido **público**, todo adulto con Finanzas del hogar. `escribir`: titular, miembro o albacea (el suplente solo si no hay albacea vigente), con el libro activo (archivado = solo lectura). `administrar`: titular de un personal, miembro de un compartido (si está archivado, solo quien lo creó, para reactivarlo), albacea de un representado. Siempre exige un rol con Finanzas. **La cuenta maestra que no es la dueña nunca escribe ni administra.** El albacea es **vigente** solo si sigue siendo adulto con Finanzas en el hogar (I4) |
| `fin_puede_hogar(hogar, accion)` | Lo del hogar (categorías, cuentas de gasto, días inhábiles, importaciones): rol con Finanzas; la maestra además lee, pero **si no es la dueña no escribe ni cambia nada** (M6, D19 del 23/oct) |
| `fin_solo_lectura(hogar)` | La sesión es la cuenta maestra y no es la dueña: en Finanzas solo lee |
| `fin_puede_salir(libro)` | La sesión es miembro vigente de un compartido (con rol vigente en el hogar): puede cerrar su propia membresía, **siempre**, también si el libro está archivado; con menos de 2 miembros el libro pasa a privado (no se archiva), salvo el último miembro, que no puede salirse |
| `fin_adultos_con_finanzas(hogar)` | Filas `(persona_id, nombre_visible, rol)` de los adultos con Finanzas del hogar (el dueño y los coadministradores vigentes, **sin** la cuenta maestra que no es la dueña; nunca familiar, cuidador ni casa), ordenadas por nombre. La ve cualquier adulto con Finanzas del hogar (también la maestra, que no aparece en la lista); para cualquier otra sesión devuelve cero filas, sin error. Incluye a la propia sesión. Solo `authenticated` la ejecuta: sirve para elegir a quién agregar a un compartido |
| `fin_es_miembro(libro)` | Miembro vigente del libro |
| `es_cuenta_maestra(hogar)` | La sesión es la cuenta maestra vigente |
| `puede_ver_entrada_bitacora(...)` | Regla de lectura de la bitácora (abajo) |

- Dueño y coadministrador: su libro y los compartidos de los que son miembros; la pareja **no** ve el libro personal del dueño, ni al revés. Familiar, cuidador y casa: nada de `fin_*`.
- **Cuenta maestra** (`membresias.es_maestra`): una por hogar, solo dueño o coadministrador. Desde el 23/oct (D19) es **otra persona con su propio login**: el dueño la invita con `crear_invitacion(..., p_es_maestra => true)` (rol `coadministrador`, con un correo que no sea de un miembro del hogar) y al aceptar queda como coadministrador con `es_maestra`, **sin libro personal** y sin poder ser miembro de ningún libro. **Si no es la dueña es de SOLO LECTURA TOTAL en Finanzas:** `fin_puede(libro, 'escribir' | 'administrar')` y `fin_puede_hogar` de escribir o administrar son falsos para ella en cualquier libro (el INSERT, UPDATE o RPC da 42501 o no afecta filas; la cola la manda a "requiere atención"). El dueño también puede ser la maestra con su propia persona (`asignar_cuenta_maestra`): en lo suyo sigue escribiendo. Quitar o cambiar la cuenta maestra deja la entrada `finanzas.maestra_asignada` (anterior, nueva y quién invitó), que ve todo adulto con Finanzas (M10). Hoy la maestra no ve nada de Cuidados ni de Hábitos (su rol es coadministrador: Cuidados no, Hábitos solo lo propio).
  - **Sin consulta ve solo la portada:** los libros y quién los lleva (`fin_libros`, `fin_libro_miembros`), los nombres de las personas, las categorías y las cuentas de gasto del hogar, y lo que no es de Finanzas (historial de GRAVITY, membresías…).
  - **Para leer el contenido de un libro ajeno** (cuentas, movimientos, plan, cierres, saldos, su bitácora) debe llamar antes `fin_registrar_consulta_maestra(libro)`: deja la entrada `finanzas.consulta_maestra` (visible para quienes llevan ese libro) y **habilita la lectura de ese libro por 30 minutos** (I2). Es por libro y por persona; pasado el tiempo hay que llamarla otra vez (cada llamada queda en la bitácora). Sin consulta vigente el servidor no devuelve filas ajenas (no da error: filtra). Lo propio no se registra (devuelve falso).
  - `cuenta_maestra(hogar)` dice a cualquier miembro si existe y de quién es.
- **Bitácora:** cada quien ve lo suyo; las entradas `gravity.*` solo su autor y la maestra (D18); las de `fin_*` y `finanzas*`, quien puede leer su libro (la maestra, solo con consulta vigente) o, si son del hogar, quien tiene Finanzas; lo demás (membresías, invitaciones…), el dueño y la maestra. **Escribir** entradas `finanzas*` o de tablas `fin_*` es solo del servidor (triggers y funciones `SECURITY DEFINER`): un miembro que las inserte directo recibe 42501 (I5). El límite de entradas por persona sigue pendiente (M2, parte 2).
- **Libro compartido** (D19, respuestas del dueño del 21 y 23/oct): ver "Respuestas del dueño del 23/oct" abajo. En corto: quien lo crea es su **administrador** (agrega y saca miembros, cambia la `visibilidad`, lo archiva); **cualquier miembro puede salirse siempre**; si al salir (o ser sacado) quedan menos de 2 miembros vigentes el libro **pasa a privado y sigue activo**, y quien queda es el administrador; el **último** miembro no puede salirse (22023); archivar es solo una decisión explícita del administrador.
- **Portada del libro de papá para el dueño:** el dueño del hogar ve siempre, aunque no sea miembro, la fila de `fin_libros` y las de `fin_libro_miembros` de los libros **representados** de su hogar (ver abajo); nada más.
- **Libro representado (Papá)** (I3 e I4): todo movimiento que toque su libro (apertura, ingreso, gasto, ajuste de conciliación, reclasificación, aportación o pago de deuda desde otro libro y **también la anulación**) lleva `en_nombre_de` = su titular **y motivo no vacío**; si no, 23514. Una salida hacia un libro personal deja además la entrada `finanzas.salida_libro_representado` (monto, motivo, quién), que ven quienes llevan el libro de Papá. Albacea y suplente cuentan solo si su membresía del hogar sigue activa y con Finanzas: si el albacea se va, el suplente escribe y administra al instante.

### Respuestas del dueño del 23/oct (migración `20261024000000_finanzas_respuestas_dueno.sql`)

Cambian lo que se construyó para los hallazgos I1, I2 y M6; las migraciones anteriores no se tocaron (la nueva reemplaza las funciones y reglas).

**1. Cuenta maestra con login propio y solo lectura**

- Es otra persona (rol `coadministrador` + `es_maestra`) que crea el dueño: `crear_invitacion(hogar, correo, 'coadministrador', vigencia_dias default 7, p_es_maestra default false)` (nombres y orden de los parámetros; la firma de 4 parámetros desapareció, los llamados con 3 o 4 siguen valiendo). Solo el dueño; con `p_es_maestra` el rol debe ser `coadministrador` y el correo no puede ser de un miembro vigente del hogar (22023). Devuelve `(invitacion_id, token, expira)` como antes; el token se muestra una vez.
- `aceptar_invitacion(token)` crea la membresía con `es_maestra`, quita la marca a la maestra anterior (si la había) y deja `finanzas.maestra_asignada` (`anterior_persona_id`, `nueva_persona_id`, `invitada_por`). Esa persona **no recibe libro personal** y no puede agregarse a un libro (`fin_libro_miembros`: 22023).
- Mientras no sea la dueña es de **solo lectura total** (`fin_solo_lectura(hogar)`): `fin_puede` y `fin_puede_hogar` de `escribir` y `administrar` son falsos en cualquier libro y para lo del hogar; tampoco crea libros compartidos. Para leer libros ajenos sigue necesitando `fin_registrar_consulta_maestra(libro)` (30 minutos); un libro público también exige la consulta.
- `asignar_cuenta_maestra(hogar, persona)` sigue existiendo (solo dueño): la dueña puede nombrarse a sí misma (en lo suyo sigue escribiendo), o a un coadministrador vigente **que no lleve libro propio**; a uno que sí lo lleva (como Alex) lo rechaza con 22023. Con nulo la quita. Todo cambio queda en `finanzas.maestra_asignada`.
- Qué NO ve la maestra en este paso: nada de Cuidados ni de Hábitos (su rol no los tiene); las notas clínicas de Cuidados (Fase 5) deberán seguir sin ser leídas por ella cuando existan sus tablas.

**2. Libros compartidos: administrador, visibilidad, salida y archivo** (la salida y el archivo se corrigieron en la 2.ª ronda, migración `20261025000000`)

| Regla | Detalle |
|---|---|
| Administrador | Quien crea el libro (`creado_por`) lo administra: agrega y saca miembros, cambia `visibilidad`, lo archiva. La API no puede cambiar `creado_por` (42501): solo el servidor |
| Visibilidad | `privada` (por omisión): leen y escriben sus miembros; la maestra lee con consulta. `publica`: además **leen, no escriben,** los adultos con Finanzas del hogar (con alcance `propio` o `total`); quien la lee también ve a los miembros. Solo la cambia el administrador (42501 a otro miembro) |
| Dueño del hogar | **No entra** a un compartido privado del que no es miembro (no lo ve ni lo cambia); la única portada que ve sin ser miembro es la del libro **representado** de papá. Si es miembro, puede agregar y sacar aunque no lo haya creado |
| Salirse | Cualquier miembro, siempre: `UPDATE fin_libro_miembros SET hasta = now()` de su propia fila, también con el libro archivado. No puede volver a abrir su fila (ni con `upsert`): lo reingresa el administrador con una fila nueva |
| Menos de 2 | Si al salirse (o ser sacado) quedan menos de 2 miembros vigentes (adultos con Finanzas), el libro **no se archiva**: pasa a `visibilidad = 'privada'`, sigue `activo = true` y quien queda es el administrador (`creado_por`). Sin error |
| El último | El último miembro vigente **no puede salirse** ni lo saca nadie (tampoco `service_role`): **22023** "El último miembro de un libro compartido no puede salirse", con la pista de archivarlo. Si el libro ya no se usa, el administrador lo archiva |
| Relevo | Si se sale (o sacan) a quien lo administra, o éste ya no es adulto del hogar con Finanzas, `creado_por` pasa al miembro vigente **más antiguo** (`desde`, luego `id`; **confirmado el 23/oct**). Si solo queda uno, él es el administrador. La fecha `desde` de una fila solo la cambia el administrador o el dueño |
| Quitar a otro | Solo el administrador (o el dueño si es miembro). Si deja menos de 2 vigentes se trata **igual que salirse** (pasa a privado; ya no da 22023), salvo que no quede nadie |
| Archivar | **Solo** el administrador, a mano (`UPDATE activo = false`); nunca ocurre solo. Archivado: se lee y no se registra. Lo reactiva (`activo = true`) solo su administrador, sin exigir 2 miembros; mientras tanto solo él lo administra; los demás solo leen y pueden salirse (si es el último, no) |
| Efectos de una salida | En el mismo UPDATE del `hasta`, el servidor cambia `fin_libros.creado_por` (si hace falta) y `visibilidad` (si quedan menos de 2); cada cambio de `fin_libros` queda en la bitácora. La hora de `hasta` la manda el dispositivo |

**3. Cuentas.** El saldo cero para cerrar o archivar una cuenta aplica **solo a activos y pasivos**. Las de gasto e ingreso se cierran o archivan con saldo, y en ellas se puede anular un movimiento aunque estén archivadas (la anulación no suma gasto nuevo). Archivar una categoría con datos **archiva su cuenta de gasto** si ninguna otra categoría activa la usa; desarchivarla (la categoría vuelve a `activa`) la reactiva. La maestra no hace nada de esto.

**4. Tablet.** La cuenta del equipo (`casa@`) tiene rol `casa` y su identificador no cambia; su nombre visible es **"Hogar"**.

**5. Bandeja de salida de la tablet.** El servidor no necesita nada nuevo: Supabase Auth renueva la sesión con el token de refresco (no caduca salvo que se configure caducidad por tiempo o inactividad; déjalo así) y el JWT de 1 hora lo renueva la app. Lo que sube una persona dada de baja se rechaza con 42501 (RLS) y la cola lo deja en "requiere atención".

### Endurecimiento de la Fase 1b (migración `20261026000000_finanzas_endurecimiento_1b.sql`)

Hallazgos N1 a N5 de la revisión de calidad (`docs/revisiones/fase-1b.md`). Los criterios son **por defecto y provisionales** hasta que responda el dueño (se anotan abajo para D17 y D19). Pruebas: `36_finanzas_endurecimiento_1b.sql` (nacieron en `hallazgos_fase1b.sql`, que ya no existe).

| Hallazgo | Qué hace el servidor | Qué pasa al excederlo o violarlo |
|---|---|---|
| **N1** y N1b: tope de la bitácora | Trigger **por sentencia** (`bitacora_tope`) sobre `public.bitacora`: lo que la **app** (rol `authenticated`) escribe directo tiene como máximo **4096 bytes** en `detalle` por entrada y **500 entradas por persona en 24 horas** (cuenta las entradas propias de la app: ni `insertar`/`actualizar`/`borrar`, ni `finanzas*`, ni tablas `fin_*`). Vale igual para familiar, cuidador y la cuenta Hogar. **No limita** a los triggers, a las funciones `SECURITY DEFINER` ni a `service_role` (el vaciado de la cola sin conexión genera entradas automáticas y no se afecta: 520 movimientos de una vez pasan sin tope) | **54000** (`program_limit_exceeded`) con mensaje y pista; la sentencia entera se deshace (no se guarda ninguna de sus entradas). No es de las clases que la cola reintenta (08, 40001, 40P01, 53, 57): lo rechazado queda en "requiere atención" |
| **N2**: motivo | `fin_motivo_valido(texto)`: al menos **3 caracteres visibles** tras quitar espacio en blanco ASCII y Unicode (tabulador, saltos de línea, NBSP, espacios de ancho fijo, separadores de línea y párrafo, ideográfico) y caracteres invisibles (ancho cero, marcas de dirección, soft hyphen, BOM, rellenos de Hangul, braille en blanco). Aplica en el **libro de papá** (`en_nombre_de`), **anulaciones**, **ajustes**, cualquier movimiento con `en_nombre_de` y **conciliaciones con diferencia**. Va en triggers (`fin_c_motivo` y `fin_b_representado`), **no** en un CHECK nuevo: los CHECK corren también al restaurar una copia y rechazarían motivos viejos cortos; los CHECK de siempre (no vacío tras `btrim`) siguen. Un reenvío idéntico de algo ya guardado no se rechaza | **23514** "El motivo necesita al menos 3 caracteres visibles". El sentido no se juzga ("..." cuenta) |
| **N3**: salida de papá | Toda salida del libro de papá hacia **cualquier otro libro** (personal o compartido; `transferencia` o `pago_deuda`) deja la entrada `finanzas.salida_libro_representado` (monto, motivo, quién, libro de destino), que ven quienes pueden leer el libro de papá (el suplente) y, como siempre, quienes leen el libro de destino. Un gasto de papá hacia una cuenta de gasto del hogar no es una salida de libro | — (aviso con notificación en la Fase 2) |
| **N4**: albacea | `fin_nombrar_albacea(p_libro_id uuid, p_persona_id uuid, p_papel text default 'albacea') -> uuid` (id de la fila de `fin_libro_miembros`). **Solo el dueño del hogar.** Nombra albacea o suplente de un libro representado cuyo cargo está vacío (nadie vigente que siga siendo adulto con Finanzas); si el cargo lo tiene abierto alguien que ya no es adulto con Finanzas, lo cierra. Deja `finanzas.albacea_nombrado` (`libro_id`, `persona_id`, `papel`, `anterior_persona_id`). Un INSERT directo en `fin_libro_miembros` sigue sin pasar para el dueño (RLS): la única puerta es la función | 42501 a quien no es dueño (también si el libro no existe, para no revelar libros); 22023 si el libro no es representado, el cargo no es `albacea`/`albacea_suplente`, la persona no es adulto con Finanzas del hogar o es la persona representada, el cargo ya lo ocupa alguien, o la persona ya lleva el libro con otro cargo |
| **N5**: baja del administrador | Trigger `fin_z_relevo_administrador` sobre `membresias` (al cambiar `rol`, `activa` o `hasta`): si la persona deja de ser adulto con Finanzas del hogar, en cada compartido que administraba o donde es miembro vigente el servidor pasa `creado_por` al miembro vigente **más antiguo** (`desde`, luego `id`) si el administrador ya no es miembro vigente, y, si quedan menos de 2 vigentes, deja el libro **privado**. Nunca archiva. Es el mismo criterio de cuando alguien se sale. Queda en la bitácora por el trigger de `fin_libros` | Sin nadie vigente a quien pasarle el cargo, no cambia nada (no falla) |

**Acciones de bitácora y códigos nuevos (para el asistente, que los anota en `api/`):**
- Acción nueva, reservada al servidor: `finanzas.albacea_nombrado` (`tabla` `fin_libro_miembros`).
- Cambia el alcance de `finanzas.salida_libro_representado`: ahora cubre toda salida del libro de papá hacia otro libro, no solo el personal.
- Operación nueva: `POST /rest/v1/rpc/fin_nombrar_albacea` con `p_libro_id`, `p_persona_id`, `p_papel` (por omisión `albacea`); responde el uuid de la fila nueva.
- Código nuevo: **54000** al escribir en `public.bitacora` (tope de N1).
- `23514` se amplía: el motivo de anulaciones, ajustes, movimientos en nombre de otra persona y conciliaciones con diferencia necesita 3 caracteres visibles.

**Lo que NO cubre el tope de N1 (límites declarados):** las entradas **automáticas** (`insertar`/`actualizar`/`borrar`) no tienen tope: crecen con los cambios reales de datos, pero alguien con una cuenta de la familia que haga cambios en bucle sobre sus propias filas puede engordar la bitácora. Tampoco topa lo que escriben las funciones del servidor a petición de una persona; en `fin_registrar_consulta_maestra` ya se resolvió en la Fase 2 (una entrada por minuto y libro). Mitigaciones pendientes: el aviso al 80 % de la base (necesita la función de servidor de la Fase 2) y un límite de peticiones en el proyecto de Supabase.

### Portada del libro de papá para el dueño (migración `20261027000000_finanzas_portada_representado.sql`)

`fin_nombrar_albacea` (N4) deja al dueño volver a nombrar albacea o suplente, pero si el dueño no es miembro del libro de papá no lo veía y la app no podía ofrecerle el botón. Criterio **provisional para D19** (el dueño normalmente lleva el libro de papá como albacea):

- El **dueño del hogar** (rol `dueno` vigente) lee siempre, aunque no sea miembro, la **portada** de los libros de tipo `representado` **de su hogar**: la fila de `fin_libros` (nombre, titular, activo, quién lo creó) y todas las filas de `fin_libro_miembros` del libro (quién es o fue albacea y suplente, con sus fechas). Se logra con una cláusula más en las reglas de lectura `fin_libros_leer` y `fin_libro_miembros_leer` (sin tablas, columnas ni funciones nuevas: **no cambia la lista de operaciones de la API**).
- **Nada más:** ni cuentas, ni movimientos, ni plan, ni saldos (`fin_v_saldos`, `fin_v_gasto_semana`), ni la bitácora del libro. Eso sigue exigiendo ser albacea o suplente vigente (`fin_puede(libro, 'leer')` no cambia y sigue negando leer, escribir y administrar al dueño no miembro).
- **Solo lectura:** no cambia el libro ni sus miembros (0 filas); un INSERT directo en `fin_libro_miembros` sigue dando 42501. Para volver a llevar el libro, el dueño usa `fin_nombrar_albacea` (con lo que ya es albacea y lee todo).
- **Solo el dueño:** no el coadministrador, ni familiar, cuidador o casa. La **cuenta maestra que no es la dueña** no cambia: ya veía la portada de todos los libros y el contenido solo con consulta registrada (la dueña que además es maestra ve la portada y, sin consulta, no el contenido).
- **Solo `representado`:** los compartidos privados y los libros personales siguen sin verse para quien no es miembro (D19). **Solo su hogar:** la dueña de otro hogar no ve nada.
- La app debe leer la portada con un `select` normal a `fin_libros` y `fin_libro_miembros` (los mismos que ya usa); el dueño no miembro recibirá ahora la fila del libro de papá, que antes no le llegaba.

### Criterios provisionales de la revisión de la Fase 1 (esperan al dueño; para D17 y D19)

| Hallazgo | Criterio con el que se construyó | Pregunta al dueño |
|---|---|---|
| I1 | **Respondida el 23/oct (2.ª ronda incluida).** Solo el administrador (quien lo creó) agrega y saca a otros; cualquiera se sale siempre; con menos de 2 el libro pasa a privado y sigue activo (no se archiva); el último miembro no se sale; quitar a otro con menos de 2 se trata igual | — |
| I2 | **Respondida el 23/oct.** La lectura de un libro ajeno por la cuenta maestra exige una consulta registrada por ella en ese libro, con vigencia de 30 minutos (también si el libro es público); sin consulta solo ve la portada. El dueño **puede** ser además la maestra con su propia persona (queda anotado) | — |
| I3 | Todo movimiento del libro de Papá lleva `en_nombre_de` y motivo; la salida hacia un libro personal deja una entrada propia en la bitácora que ve el suplente (el aviso con notificación, en la Fase 2) | ¿Toda salida hacia un libro personal debe avisar al suplente? |
| I4 | Albacea y suplente cuentan solo si su membresía del hogar sigue activa y con Finanzas; si el albacea sale, el suplente escribe | — |
| I5 | Las acciones `finanzas*` y las tablas `fin_*` de la bitácora son solo del servidor | — |
| M6 | **Superado el 23/oct.** La cuenta maestra que no es la dueña no escribe nada en Finanzas (solo lectura total); la pareja sí configura lo del hogar | ¿Solo el dueño configura lo del hogar? |
| Relevo | Si se sale quien creó un compartido, `creado_por` pasa al miembro vigente más antiguo (`desde`). **Confirmado el 23/oct** | — |
| Dueño y privados | El dueño no entra a un compartido privado donde no es miembro; para que pueda sacar a alguien debe ser miembro. **Confirmado el 23/oct:** solo la maestra lo lee | — |
| Maestra y públicos | La maestra necesita la consulta registrada incluso para un compartido público | ¿Un compartido público debería leerlo sin consulta? |
| Último miembro | Error 22023 al intentar salirse el último miembro vigente (tampoco lo saca nadie); código elegido por backend, la app lo muestra como "archívalo si ya no lo usas" | ¿Basta el mensaje, o conviene archivar solo? (el dueño decidió: no archivar solo) |
| N1 | Tope de lo que la app escribe en la bitácora: 4 KB por entrada y 500 por persona en 24 horas; no limita a triggers, funciones del servidor ni `service_role` | ¿Son correctos 500 al día y 4 KB? (ajustable en `bitacora_tope_por_persona`) |
| N2 | El motivo exige 3 caracteres visibles | ¿Largo mínimo distinto de 3? ¿Debe pedir al menos una letra o dígito? |
| N3 | Toda salida del libro de papá hacia otro libro (no solo personal) avisa al suplente | ¿Es lo que quiere el dueño? (pregunta 3 de la revisión) |
| N4 | El dueño del hogar puede volver a nombrar albacea o suplente de un cargo vacío, con entrada en la bitácora | ¿Debe poder además reemplazar a un albacea que sigue vigente? (hoy no) |
| Portada de papá | El dueño del hogar ve siempre la fila del libro representado y sus miembros aunque no sea miembro, nada más (ni cuentas, ni movimientos, ni plan) | ¿Debe ver también otra cosa del libro de papá sin ser albacea (p. ej. solo los totales)? Hoy no |
| N5 | Si el administrador de un compartido deja de ser adulto con Finanzas, el cargo pasa al miembro vigente más antiguo | ¿Pasa solo, o lo elige alguien? (pregunta 5 de la revisión) |

### Garantía y límites del "solo agregar" (M13)

`impedir_cambios_solo_agregar()` y la falta de permisos impiden editar, borrar o vaciar un libro (movimientos, conciliaciones, cierres, importaciones, bitácora) a **cualquier rol de la API**, incluidos `service_role` y el dueño de la tabla en una sesión normal. No es una barrera contra quien administra la base: el dueño de las tablas (`postgres` o `supabase_admin`) puede deshabilitar los triggers, cambiar el esquema o borrar la tabla. Esa puerta es del dueño del proyecto, no de la app; por eso la copia diaria cifrada (`herramientas/respaldo`) es parte de la garantía: guarda la copia fuera de la base y de la laptop, y no compartas la contraseña de la base ni la llave `service_role`.

### Contrato para la app (cola sin conexión y repositorios)

- **Idempotencia.** Todas las tablas `fin_*` tienen `id`. La cola sube con `upsert(onConflict: 'id', ignoreDuplicates: true)` (`INSERT … ON CONFLICT (id) DO NOTHING`):
  - Mismo `id` y mismo contenido: **no inserta nada y no falla** (0 filas; también con `INSERT` simple). Vale aunque desde entonces la cuenta se haya congelado, el movimiento ya tenga anulación o la semana se haya cerrado.
  - Mismo `id` con **otro contenido** en los libros solo agregar (`fin_movimientos`, `fin_conciliaciones`, `fin_cierres*`, `fin_importaciones`): **23505** con `ON CONFLICT DO NOTHING` o sin él (el cambio no se pierde en silencio: queda en "requiere atención"). En configuración y plan, `ON CONFLICT DO NOTHING` lo ignora si pasa las validaciones (para editar se usa `UPDATE` o `upsert` sin `ignoreDuplicates`).
  - No se comparan las columnas que pone el servidor: `recibido_en`, `libro_*` derivados, generadas, `creado_en`/`cerrado_en`.
- **Movimientos:** `registrado_en` es **obligatorio** (si faltara, cada reenvío sería distinto). No mandes `recibido_en`, `libro_origen_id` ni `libro_destino_id` (no tienen permiso de columna). `registrado_por` y `realizado_por` toman la sesión por omisión.
- **Columnas que la app puede mandar y el servidor sobrescribe:** `fin_cuentas.creada_por`, `fin_dias_inhabiles.revisado_por/revisado_en`, `fin_semanas.activada_por/activada_en`. `cerrado_en` y `creado_en` de cierres, conciliaciones e importaciones sí se aceptan del dispositivo.
- **Orden de subida:** cuentas → movimientos; el movimiento de **ajuste** antes que su **conciliación**; **cierre** (y sus partidas y abonos) antes de cambiar la semana a `cerrada`; reabrir = `UPDATE` solo del `estado` (a `activa`, `pendiente_ingreso` o `por_cerrar`).
- **Errores:** `23503` = falta algo de lo que depende (otra cuenta, el original de una anulación…; la cola reintenta). `23505` = duplicado o mismo id con otro contenido. `23514` = check de la tabla o falta `en_nombre_de`/motivo en el libro de Papá (monto, motivo de 3 o más caracteres visibles, lunes, cascada…). `22023` = regla de negocio (combinación de cuentas, libro equivocado, papel…). `55000` = estado (cuenta no activa, semana cerrada). `42501` = sin permiso o columna que no cambia. `54000` = tope de la bitácora (solo al escribir directo en `public.bitacora`). Ninguno es de las clases que la cola reintenta (08, 40001, 40P01, 53, 57).
- **Entre libros:** solo `transferencia` y `pago_deuda` (y su anulación) cruzan de un libro a otro; se ven desde los dos. Ojo para el cuadre por libro: una aportación cambia el patrimonio de cada libro sin pasar por el resultado.

## Fase 2: deudas, ahorro y avisos (D20, propuesta)

Migraciones `20261101000000_finanzas_fase2.sql` (deudas ampliadas, MSI, estados de cuenta, ahorro) y `20261102000000_avisos.sql` (infraestructura de avisos), y la Edge Function `functions/enviar-avisos/`. Especificación: `docs/specs/fase-2-finanzas.md` (secciones 4 y 5). Se construyó con las **propuestas por defecto** de la sección 9 mientras el dueño responde.

### Deudas y ahorro (`20261101000000`)

| Objeto | Qué es |
|---|---|
| `fin_deudas` (columnas nuevas) | `clase` (`tarjeta`/`prestamo`/`credito`/`msi`/`familiar`, obligatoria), `acreedor`, `monto_original_centavos`, `cat_pb`, `corte_dia` (0 = último día; solo tarjetas), `permite_pago_anticipado` (nulo = verificar), `extra_reduce` (`plazo`/`cuota`). Checks: `msi` <=> tipo `msi`, `familiar` <=> tipo `familiar` (23514). Las filas de la Fase 1 se rellenaron. Si el INSERT no trae `clase` (cola vieja) el servidor la deduce (con_costo en cuenta `tarjeta` = tarjeta, si no credito) |
| `fin_parametros` (columnas nuevas) | `orden_ahorro`, `dependientes_cuidados`, `esenciales_incluyen_minimos`, `dias_aviso_deuda` (0 a 3 días entre 0 y 14, sin repetir) |
| `fin_msi` | Compra a MSI: su deuda (`clase msi`), su tarjeta opcional, su cuenta pasivo **propia** (tipo `prestamo`, única), comercio y descripción (datos del libro: jamás salen en un aviso), 2 a 48 mensualidades |
| `fin_estados_cuenta` | **Solo agregar.** Estado de cuenta capturado a mano de una tarjeta; para un mismo corte vale el más reciente (`fin_v_estados_cuenta_vigentes`). `registrado_por` a nombre propio, `registrado_en` lo manda el dispositivo, `recibido_en` lo pone el servidor |
| `fin_bolsas_ahorro` | Bolsa = cuenta de tipo `ahorro` del libro (única). Un solo fondo de emergencia activo por libro. Tipo, cuenta y libro no cambian. Métodos: `pagate_primero`, `monto_fijo`, `meta_fecha`, `reto_52_semanas`, `redondeo`, `sobrante_semanal`, `sobre_categoria`, `porcentaje_extras` |
| `fin_aportaciones_ahorro` | Reparto semanal por bolsa. `pendiente_centavos` es **generada** (no se manda). `confirmada` <=> lleva `movimiento_id` (una transferencia hacia la cuenta de la bolsa) y `aportado > 0`; `confirmada_por/en` los pone el servidor; `movimiento_id` y `aportado` no se tocan una vez puestos (42501); en una semana cerrada solo se confirma (55000 para lo demás) |
| `fin_retiros_ahorro` | **Solo agregar.** Retiro de una bolsa (`uso_previsto`/`emergencia`/`cambio_destino`), un retiro por movimiento (una transferencia **desde** la cuenta de la bolsa); motivo con 3 caracteres visibles (23514) |
| Vistas | `fin_v_deuda_resumen` (saldo por deuda y MSI pendiente por tarjeta), `fin_v_bolsa_saldo`, `fin_v_estados_cuenta_vigentes`; todas `security_invoker`, no guardan saldos |

RLS: todo con `fin_puede(libro, …)` (leer; las tablas de configuración, administrar; estados y retiros, escribir a nombre propio). Libro archivado: solo lectura. Maestra: lee con consulta registrada y nunca escribe. Familiar, cuidador y Casa no ven nada. Convención 12: los `grant insert` de `fin_deudas` y `fin_parametros` repiten la lista completa.

### Avisos (`20261102000000`)

| Objeto | Qué es |
|---|---|
| `avisos` | Sin columnas de monto, nombre ni texto libre. `tipo` de catálogo cerrado (19 tipos), `severidad` fija por tipo (`avisos_severidad`), `clave` (minúsculas, dígitos y `_ : . -`, ≤ 120, única con `persona_id`: idempotencia), `libro_id` solo en `finanzas`, `estado`, `enviar_en`. El `id` se deriva de (persona, clave). La persona solo lee los suyos (RLS); **nadie escribe directo**: solo las funciones. Entra a Realtime si el proyecto lo tiene |
| `avisos_preferencias` | Una fila por persona con Finanzas (la crea y la quita el servidor al cambiar su rol; la cuenta maestra que no es la dueña no tiene). Zona horaria, silencio (22:00 a 07:00), `criticas_en_silencio`, tope de no críticas (3), `hora_vencimientos` (09:00), resumen del lunes, recordatorio de cierre, `tipos_silenciados`, `pulsera_texto_corto` |
| `avisos_entregas`, `avisos_sistema` | Solo `service_role`. `avisos_sistema`: `limite_base_bytes` (500 MB), `umbral_aviso_pct` (80), `umbral_critico_pct` (90); la restauración la deja como la migración (está en `TablasDeMigracion` del respaldo) |
| `dispositivos` (cambios) | `tipo` (`telefono`/`tablet_personal`/`tablet_publica`/`laptop`), `recibe_avisos` (teléfono sí por omisión; tablet personal y laptop no; **tablet pública nunca**, trigger), `ultimo_envio_en`, `fallos`. **Token único global** (cierra M13). Ya no se inserta directo ni se cambia el token: solo `registrar_dispositivo` |

**Claves de los avisos de vencimiento** (`tipo:objeto_id:fecha_ajustada:n`; `objeto_id` = id de la ocurrencia): en los avisos previos (`pago_proximo` o `limite_tarjeta`) **`n` = los días antes** (con 3 y 1: `…:3` y `…:1`, no el paso 1, 2); en `pago_vencido`, `n` = los días después (`1` y `3`); en `ingreso_retrasado`, `1`. El `id` del aviso es `md5('aviso:'||persona_id||':'||clave)::uuid`. `dispositivos.recibe_avisos` se cambia con `UPDATE … WHERE token_avisos = …` (solo `nombre`, `ultimo_uso` y `recibe_avisos` tienen permiso de UPDATE, solo de los propios; en tablet pública el trigger lo deja en falso).

**Funciones para la app (`authenticated`)**

| Función | Qué hace / errores |
|---|---|
| `registrar_dispositivo(p_token, p_plataforma, p_nombre default null, p_tipo default 'telefono') -> uuid` | Da de alta o **reasigna** el token a la persona de la sesión (id derivado del token); registrar de nuevo no apaga la elección de la persona. 42501 sin sesión; 22023 si el token, la plataforma o el tipo no valen |
| `quitar_dispositivo(p_token) -> boolean` | Borra el token de la persona (cerrar sesión, quitar de la tablet, baja) |
| `fin_emitir_aviso(p_libro_id, p_tipo, p_objeto_tipo, p_objeto_id, p_clave) -> integer` | Para lo que solo el motor sabe: `protegido_riesgo`, `flujo_negativo`, `abono_bajo_minimo`, `partida_100`, `partida_80`, `fondo_bajo`, `uso_limite`, `aportacion_pendiente`, `conciliacion_pendiente`. Exige `escribir` en el libro (42501); tipo no emitible, clave o más de **60 al día** por persona: 22023. Calcula los destinatarios y devuelve cuántos avisos creó (idempotente por clave: 0 si ya existía) |
| `avisos_marcar(p_aviso_id, p_accion)` | `leida`, `resuelta`, `posponer_1h`, `posponer_manana` (vuelve a salir a esa hora). El aviso ajeno: 42501 |
| `avisos_porcentaje_base() -> numeric` (`20261103`) | Solo el dueño (42501 a otros): porcentaje de la base usado (1 decimal), y nada más de `avisos_sistema`. Para Ajustes › Copias de seguridad |
| `avisos_actualizar_preferencias(…)` | Parámetros nombrados, nulos = no cambia. Tope 0 a 10, zona real, día 1 a 7, tipos del catálogo: 22023. Sin preferencias (maestra, familiar…): 42501 |

**Destinatarios (los calcula el servidor, regla 41):** libro personal = su titular; compartido = todos los miembros vigentes; papá = el albacea vigente y, sin él, el suplente. `partida_80` = quien registró; `partida_100` = quien registró y el titular. **Nunca** la cuenta maestra que no es la dueña, ni familiar, cuidador o Casa. Aviso `salida_libro_representado` = el suplente vigente (no a quien hizo el movimiento), dentro de la misma función que deja la entrada N3 de la bitácora. `retiro_bolsa_compartida` = los otros miembros. `base_80`/`base_90` = el dueño de cada hogar.

**Silencio y tope:** las críticas y las demás no suenan de 22:00 a 07:00 (hora de la persona) salvo `criticas_en_silencio` (solo críticas); esperan a las 07:00. Del 4.º aviso no crítico del día (por zona de la persona) en adelante, el aviso queda `agrupada` (visible en la bandeja, no suena); las críticas y los recordatorios fijos no cuentan. Un tipo silenciado también queda `agrupada`.

**Tareas (pg_cron, solo si el proyecto lo tiene; la migración las programa y, si no hay pg_cron, avisa con un NOTICE):**

| Tarea | Cuándo | Qué hace |
|---|---|---|
| `avisos-vencimientos` | cada hora | `avisos_generar_vencimientos()`: retrasa los pagos de deuda cuyo día pasó; avisos de 3 y 1 días antes (`dias_aviso_deuda`) a la hora de cada persona, **solo los que aún no pasaron**; vencidos: al día siguiente y a los 3 días; ingreso sin llegar al siguiente día hábil; cancela los de una fecha vieja; un pago con monto cero no avisa. Tipo `limite_tarjeta` si la deuda es tarjeta, si no `pago_proximo` |
| `avisos-base` | diaria, 12:00 UTC (06:00 de México) | `avisos_revisar_base()`: 80 % importante, 90 % crítico, solo al dueño, uno por día |
| `avisos-limpieza` | diaria, 09:30 UTC | `avisos_limpiar()`: borra avisos de más de 90 días y entregas de más de 30 (única excepción al "nadie borra"; la bitácora no se toca, y no crece por cada aviso) |
| `avisos-enviar` | cada 5 minutos | `avisos_invocar_enviar()` llama (pg_net) a la Edge Function con la clave de servicio **del Vault**. Sin esos secretos no hace nada |

Cuando se resuelve el pago (la ocurrencia deja de estar `esperada`/`retrasada`) o cambia su fecha, un trigger cancela los avisos pendientes de esa ocurrencia (regla 38).

**Consultas repetidas de la maestra (P12 por defecto):** `fin_registrar_consulta_maestra` no repite la entrada de bitácora si ya hay una de esa persona y ese libro en el último minuto (la consulta sigue vigente).

### Endurecimiento de la Fase 2 (`20261104000000_finanzas_fase2_endurecimiento.sql`)

Revisión `docs/revisiones/fase-2.md`; criterios por defecto, **provisionales** (para D20). Pruebas: `88_finanzas_fase2_endurecimiento.sql` (`hallazgos_fase2.sql` se retiró).

| Hallazgo | Qué hace el servidor |
|---|---|
| **F2-1** push que se apaga | `avisos_registrar_entrega`: solo cuentan como fallo los resultados definitivos. `token_invalido` borra el token; el resultado nuevo **`rechazado`** suma y 5 apagan `recibe_avisos`; **`error`** (5xx, cuota, red) reintenta sin sumar. `registrar_dispositivo` (la app lo llama al abrir) **reactiva** `recibe_avisos` y reinicia `fallos` si el equipo es un **teléfono**; la tablet personal conserva su elección y la pública nunca recibe. Si ya había un dispositivo con ese token (aunque su id no fuera el derivado) se actualiza, no se duplica |
| **F2-5** llaves | `fin_retiros_ahorro.bolsa_destino_id` ahora es llave compuesta `(libro_id, bolsa_destino_id)` y distinta de la bolsa de origen (23503 / 23514). Revisadas las demás llaves de la Fase 2 (msi, estados, bolsas, aportaciones): ya eran compuestas con `libro_id` |
| **F2-3** emisión | `fin_emitir_aviso`: `objeto_id` debe ser del libro del aviso (deuda, ocurrencia, partida, bolsa, semana, libro, movimiento que lo toca; 22023); quien emite debe ser miembro con permiso de escribir y destinatario válido (42501; no la maestra); `flujo_negativo` y `abono_bajo_minimo` se limitan a **5 por día y libro** (22023, repetir una clave no cuenta); lo demás sigue en 60 por persona. **Lo ideal** es que solo el motor del servidor emita críticas; se decide en la siguiente ronda |
| **F2-4** (de la misma revisión) | `avisos_actualizar_preferencias` rechaza horas silenciosas con inicio igual al fin (22023) |

### Edge Function `enviar-avisos`

`supabase/functions/enviar-avisos/` (TypeScript, Deno): reclama con `avisos_reclamar` (`select … for update skip locked`, hasta **200** por corrida, marca el lote 3 minutos: dos corridas a la vez no duplican), manda por **FCM HTTP v1** un mensaje **solo de datos** `{ "v": "1", "id": "<uuid del aviso>" }` con prioridad alta (sin `notification`, sin tipo, libro, persona ni texto), registra cada entrega y el resultado. Nunca incluye `tablet_publica`, equipos con `recibe_avisos = false` ni personas dadas de baja. `UNREGISTERED` borra el token; un resultado `rechazado` (fallo definitivo distinto del token) suma y 5 seguidos desactivan el equipo; los errores transitorios (`error`: 5xx, cuota, red) NO suman (F2-1) y reintenta a los 5, 15 y 60 minutos y luego se da por enviado sin entrega (queda en la bandeja). **Desviación de la especificación:** `collapse_key` es el `id` del aviso (opaco), no la `clave`, porque la clave dice el tipo y la fecha y no debe verla Google.

**Lo que debe poner el dueño (nada de esto va al repositorio):**

1. Proyecto de Firebase con una app Android y su **cuenta de servicio**: `supabase secrets set FCM_SERVICE_ACCOUNT='<JSON>'`. Sin ese secreto la función no envía y no falla; la app sigue con recordatorios locales y bandeja.
2. `supabase functions deploy enviar-avisos`.
3. En el Vault de Supabase: `select vault.create_secret('https://<ref>.supabase.co', 'gravity_project_url');` y `select vault.create_secret('<clave service_role>', 'gravity_service_role_key');` (la tarea `avisos-enviar` los lee).
4. Activar las extensiones `pg_cron` y `pg_net` (Database › Extensions) **antes** de aplicar `20261102…`, o volver a correr el bloque final de esa migración después.
5. Verificar el cupo vigente de la base y de las funciones del plan gratuito (`avisos_sistema.limite_base_bytes`).

**Probar la función sin Deno:** `node --experimental-strip-types --test supabase/functions/enviar-avisos/enviar_test.ts` (Node 22 o superior; las pruebas usan solo `node:test` y un FCM simulado) o `deno test supabase/functions/enviar-avisos/enviar_test.ts`. 9 pruebas: cuerpo exactamente `{v, id}`, prioridad alta, sin `notification`, entregas, `UNREGISTERED`, errores, red caída, sin avisos no pide token, tope de 200, JWT RS256. (El archivo `index.ts`, que usa `Deno.serve`, solo se comprueba con Deno.)

## Fase 3: Hábitos (D13, D21 propuesta)

Migraciones `20261105000000_habitos.sql` (tablas `hab_*` en claro, por persona) y `20261106000000_habitos_sensibles.sql` (sobres cifrados, llaves, modos y borrado). Especificación: `docs/specs/fase-3-habitos.md`. Decisiones del dueño (commit `42f5251`): lo sensible es **solo teléfono** por omisión (la nube está apagada); frase de **12 palabras**; la **tablet personal** funciona como el teléfono (registra su dispositivo y puede subir y leer sobres cifrados) y la **pública nunca**; los datos de quien se da de baja **se conservan sin acceso y se borran a los 90 días**.

**Quién tiene Hábitos** (`hab_miembro_activo`, `hab_activa(hogar)`): dueño, coadministrador y familiar con membresía vigente (la matriz ya daba `habitos` = `propio`; no cambió, y la prueba I1 espejo sigue igual). **Quedan fuera** la cuenta maestra que no es la dueña (una dueña que además es maestra conserva el suyo), el cuidador, Hogar (tablet pública) y papá. Todo registro es de **una persona**: ni el dueño, ni la pareja, ni la maestra, ni otro hogar leen lo ajeno. `anon` no tiene nada.

| Objeto | Qué es |
|---|---|
| `hab_ajustes`, `hab_modos` | Una fila de ajustes y dos de modos por persona, creadas por el servidor al dar el rol (`hab_iniciar`). La app solo hace UPDATE de los ajustes (no de `epoca_nube`); el modo solo cambia con `hab_cambiar_modo`. Ambos modos nacen `solo_telefono` |
| `hab_objetivos`, `hab_bloques`, `hab_registros`, `hab_pausas`, `hab_planes_lectura`, `hab_plan_dias`, `hab_lecturas`, `hab_marcas_biblia`, `hab_revisiones` | Datos no sensibles. La app **no manda** `persona_id`, `hogar_id` ni `actualizado_en` (sin permiso de columna; los pone el servidor). Las llaves hacia objetivos, bloques y planes son compuestas con `persona_id` (no se apunta a lo de otra persona). Un registro por elemento y día (23505) y al menos objetivo o bloque (23514). Se borran por la persona, no son libro contable |
| Último gana (`hab_a_propio`) | Un UPDATE con `modificado_en` más viejo se **ignora sin error** (0 filas); uno a más de 5 minutos en el futuro se ajusta a la hora del servidor |
| Sin bitácora | Las tablas `hab_*` no tienen trigger de bitácora. El prefijo `habitos*` queda **reservado al servidor** (la app que lo escriba recibe 42501) y las entradas `habitos.*` solo las ve quien las hizo (ni el dueño ni la maestra). No cuentan para el tope de 500 de la bitácora |
| `hab_sobres` | Solo texto cifrado: `id` opaco, `tipo`, `revision`, `cifrado` (base64url, ≤ 64 KB), `llave_version`, `eliminado`, horas **del servidor**. Sin fecha ni clase de registro. Solo se leen en modo `nube_cifrada`; se escriben solo con `hab_subir_sobres` |
| `hab_llaves` | La llave maestra **envuelta** con la frase (kdf `pbkdf2-hmac-sha256` o `argon2id`, parámetros, sal). El servidor no puede abrirla |

**Funciones para la app (`authenticated`)**

| Función | Qué hace / errores |
|---|---|
| `hab_crear_plan_lectura(p_plan jsonb, p_dias jsonb) -> uuid` | Plan y hasta 400 días en una transacción; idempotente por `id` del plan. 22023 con más de 400 días |
| `hab_guardar_llave(p_version, p_kdf, p_kdf_params, p_sal, p_llave_envuelta)` | Crea (versión 1) o reemplaza (versión actual + 1) la llave envuelta; repetir lo mismo no hace nada; otra versión: 22023. Al crearla deja `habitos.activar_cifrado` sin contenido |
| `hab_cambiar_modo(p_tipo, p_modo, p_confirmar_borrado default false)` | A `nube_cifrada` exige la llave guardada (55000). A `solo_telefono` **borra físicamente** los sobres de ese tipo, exige `p_confirmar_borrado = true` (22023) y sube `epoca_nube`. Deja `habitos.cambiar_modo` |
| `hab_subir_sobres(p_sobres jsonb) -> jsonb` | Hasta **50** por llamada (cada uno `id`, `tipo`, `revision`, `cifrado`, `llave_version`, `eliminado`). Solo de tipos en `nube_cifrada` (22023), revisión nueva o +1 (22023 si salta), ≤ 64 KB (23514), cuota de 25 MB por persona (`avisos_sistema.habitos_cuota_bytes`; 22023). Responde `{aceptados, conflictos: [{id, revision}]}`: un conflicto es un sobre cuya revisión del servidor es igual o mayor y con otro contenido (el cliente descarga, fusiona y sube la siguiente). Idempotente. Un sobre de otra persona: 42501 |
| `hab_reiniciar_nube(p_tipo default 'todos')` | Perdí la frase y ningún equipo tiene la llave: borra los sobres, vuelve a `solo_telefono` y borra la llave cuando ya nada usa la nube. Deja `habitos.reiniciar_nube` |
| `hab_borrar_mis_datos(p_alcance)` | `sensibles`, `diario` o `todo` (con `todo` también la llave y las tablas en claro; deja los ajustes y pone los modos en solo teléfono). Deja `habitos.borrar_datos` |

Todas exigen Hábitos en el hogar (42501 a la maestra, el cuidador, Hogar y quien no tiene sesión). **Las constancias de bitácora no llevan contenido** (`detalle` vacío, sin tabla). El servidor **no sabe** en qué dispositivo corre la llamada: que la tablet pública nunca reciba la llave es regla de la app (la llave viaja solo a teléfono, tablet personal y laptop).

**Avisos y Hábitos:** `avisos_preferencias_sincronizar` crea la fila también para quien solo tiene Hábitos (el familiar), nunca para la maestra no dueña; `avisos_actualizar_preferencias` acepta en `tipos_silenciados` los tipos locales `hab_bloque`, `hab_lectura`, `hab_momento`, `hab_reservado`, `hab_revision_pre`, `hab_revision` y `hab_cierre_dia`. Los recordatorios de Hábitos son locales (no usan `avisos` ni Firebase).

**Limpieza (`hab_limpiar`, diaria, pg_cron `hab-limpieza`, 09:45 UTC):** borra las tumbas de sobres de más de 30 días y **todo lo de Hábitos de quien lleva más de 90 días dado de baja** (sin ninguna membresía vigente); hasta entonces se conserva sin acceso. Si vuelve al hogar antes, recupera su acceso y sus datos.

**La copia de seguridad** incluye los sobres tal cual (ilegibles sin la frase) y las tablas en claro, así que la copia contiene los datos no sensibles de las demás personas del hogar (observación 6 de la especificación).

### Endurecimiento de Hábitos (`20261107000000_habitos_endurecimiento.sql`)

Revisión `docs/revisiones/fase-3.md`; criterios por defecto, **provisionales**. Pruebas: `91_habitos_endurecimiento.sql` y ajustes en la 90 (`hallazgos_fase3.sql` se retiró).

| Hallazgo | Qué hace el servidor |
|---|---|
| **F3-2** subida de sobres | `hab_subir_sobres` acepta cualquier revisión **mayor** que la del servidor (ya no exige +1: la cola puede saltar intermedias). Igual o menor con otro contenido = **conflicto** devuelto en `conflictos` sin abortar el lote (los demás sobres entran). Mismo contenido y revisión = no hace nada |
| **F3-3** (alias) | `hab_llaves.kdf` acepta `pbkdf2-sha256` además de `pbkdf2-hmac-sha256` y `argon2id` |
| **F3-4** bitácora | Las constancias `habitos.*` son **una por acción, persona y minuto**: 600 llamadas a `hab_borrar_mis_datos` dejan una sola |
| **F3-5** baja | `membresias.desactivada_en` (la pone un trigger al pasar `activa` a falso, al fijar `hasta` o al crear una membresía inactiva; se borra al volver). `hab_limpiar` borra lo de Hábitos **90 días después de la baja más reciente** en todos los casos (`activa = false` con `hasta` nulo, o `hasta` vencido). Quien sigue o vuelve al hogar no se toca |
| **F3-9** | `hab_hogar_de(persona)` solo contesta por la propia sesión (nulo para cualquier otra persona, aunque sea del mismo hogar); las funciones del servidor sin sesión siguen igual |
| **F3-10** cuota de filas | Por persona: 2 000 objetivos, 5 000 bloques, 20 000 registros, 500 pausas, 100 planes, 40 000 días de plan, 20 000 lecturas, 20 000 marcas y 600 revisiones. Se revisa por sentencia (trigger `hab_z_cuota`); al pasarla **54000** con pista (no se reintenta). Los sobres siguen con su cuota de 25 MB |

## Fase 4: Alimentación (D23) y motivo (F4-M1)

Migración `20261108000000_alimentacion.sql`, según `docs/specs/fase-4-alimentacion.md` (secciones 4 y 6) y `docs/revisiones/fase-4.md` (F4-B1, F4-M1). Dos menús por hogar: `papa` (con su **perfil clínico**, dato D3) y `pareja` (el del dueño y su pareja).

**Los permisos los decide `ali_puede(hogar, menu, objeto, accion)`, no `permisos_rol`** (la matriz no distingue menús ni el ajuste del 6/nov; su fila de Casa y la del familiar siguen como estaban, y actualizarlas con su espejo en la app es del arquitecto, F4-A2/A3). `objeto`: `platillos`, `menu`, `perfil`, `suplementos`, `compras`; `accion`: `leer` o `escribir`.

| Quién | Menú de Papá | Menú de la pareja | Perfil de Papá | Suplementos | Platillos | Comprado / lista |
|---|---|---|---|---|---|---|
| Dueño | ve y edita | ve y edita | **edita** | edita | edita | marca ambas |
| Pareja (coadministrador) | ve y edita | ve y edita | ve | edita | edita | marca ambas |
| Familiar | **ve y edita** | nada | ve | ve | ve | ninguna (por confirmar) |
| Cuidadora | solo ve | nada | ve | ve | ve | ve la de Papá |
| Cuenta maestra (no dueña) | solo ve | solo ve | ve | ve | ve | ve ambas, no marca |
| Casa (tablet pública) | **nada** | nada | nada | nada | nada | nada |

Una dueña que además es maestra conserva sus permisos de dueña. Otro hogar y `anon`: nada.

| Tabla | Qué guarda |
|---|---|
| `ali_platillos` | `id`, `hogar_id`, `nombre`, `ingredientes` (jsonb: `[{nombre, cantidad, unidad, seccion}]`, ≤ 16 KB), `duros text[]` |
| `ali_menus` | PK (`hogar_id`, `menu`) y `perfil` jsonb (≤ 8 KB). El de Papá es dato clínico |
| `ali_menu` | `menu`, `semana` (lunes), `dia` 0 a 6, `tiempo` (`desayuno`/`comida`/`cena`/`colacion`), `platillo_id` (llave compuesta con el hogar). Única por (hogar, menu, semana, día, tiempo) |
| `ali_suplementos` | `menu`, `nombre`, `dosis`, `horario` |
| `ali_compras_marcas` | PK (hogar, menu, semana, `clave` = `nombre|unidad`); fila presente = comprado |

`actualizado_por/en` y `marcado_por/en` los pone el servidor (la app no los manda). **Sin precios ni dinero**, **sin bitácora** (el perfil clínico no se copia a otra parte) y cuota de filas por hogar (2 000 platillos, 20 000 entradas de menú, 200 suplementos, 20 000 marcas; 54000). Ninguna función ni vista usa estos datos para la IA o las bocinas. Sin permiso, el INSERT da 42501 y la lectura devuelve cero filas. Convención 12: los `grant` repiten la lista completa.

**F4-M1:** `fin_motivo_valido` ahora es igual que `motivoValido` de la app: 3 caracteres visibles, al menos 2 que no son puntuación ni símbolos y no todos iguales (`___`, `...`, `---`, `aaa` ya no valen). La puntuación se define por lista, no por la configuración regional. Esto afecta solo a los triggers de motivo (libro de papá, anulaciones, ajustes, conciliaciones, retiros de ahorro).

**Pendiente:** `fin_vistas_solicitadas` (D24, vista temporal de Finanzas de Papá para el familiar) cuando haya pantalla; no se construyó en esta migración.

## Pruebas

```bash
supabase/tests/correr.sh            # resumen por archivo
supabase/tests/correr.sh -v         # cada afirmación
supabase/tests/correr.sh 20_finanzas_roles.sql 27_finanzas_idempotencia.sql
```

Crea una base desechable, aplica `tests/00_emulacion_supabase.sql` (roles `anon`, `authenticated`, `service_role`, `auth.users` y `auth.uid()` como en Supabase), las migraciones (cada una en su transacción), `seed.sql` y `tests/01_utilidades.sql`; luego corre cada `tests/NN_*.sql` (de 10 a 99) dentro de `begin … rollback`. Sale con error si algo falla.

| Archivo | Comprueba |
|---|---|
| `10_esquema.sql` | RLS en **todas** las tablas de `public` (también las futuras); funciones SECURITY DEFINER con `search_path`; `anon` sin privilegios; nadie con TRUNCATE; matriz (61 filas, D18, D19 y Cuidados) y su alineación con la app (I1); persona automática al registrarse; privilegios por omisión de lo que se cree después (M1); las 21 tablas `fin_*` con `hogar_id` y bitácora, los libros solo agregar sin UPDATE/DELETE/TRUNCATE ni reglas para eso, vistas con `security_invoker`, una cuenta maestra por hogar; triggers de las salvaguardas y ayudantes internos que la API no puede ejecutar; la columna `fin_libros.visibilidad`, `invitaciones.es_maestra` y una sola `crear_invitacion` (5 parámetros) |
| `20_finanzas_roles.sql` | **Criterio 26 con D19:** cada quien ve y registra en su libro y en los compartidos; la pareja no ve el libro personal de la dueña (en ninguna tabla ni vista) ni al revés; la aportación al compartido se ve desde los dos libros; familiar, cuidador y casa no ven nada de `fin_*` (tablas, vistas, bitácora) ni escriben; nadie registra a nombre de otro; la baja quita el acceso |
| `21_finanzas_albacea.sql` | **D19:** el albacea registra en nombre de Papá con motivo (sin motivo falla); con albacea vigente el suplente solo lee; máximo un albacea y un suplente, solo adultos con Finanzas; si el albacea deja el cargo, el suplente escribe; `fin_crear_libro_representado` (solo dueño, idempotente) |
| `22_finanzas_solo_agregar.sql` | **Criterios 25, 9 y 16:** nadie (ni dueña, ni `service_role`, ni `postgres`) edita, borra ni vacía movimientos, conciliaciones, cierres o importaciones; un gasto de una semana cerrada se corrige con anulación y contraasiento y la semana se recalcula; la foto del cierre no cambia; reglas de la anulación |
| `23_finanzas_libro.sql` | Sección 4.3: cada combinación válida e inválida por tipo, montos, cuentas inexistentes o de otro hogar, movimientos entre libros, columnas que pone el servidor, pendientes y cuentas congeladas |
| `24_finanzas_cuentas.sql` | **Criterio 15 con D19 (23/oct):** no se borra una cuenta con movimientos; activos y pasivos se cierran o archivan solo con saldo cero (confirmado y con pendientes), las de gasto e ingreso con saldo; la anulación en una cuenta archivada de gasto o ingreso; cuentas de sistema; tipos y libros; categorías de 3 niveles, se borran solo sin datos, se archivan **y archivan su cuenta de gasto** (no si otra categoría activa la usa; se reactiva al desarchivar); la maestra no cambia nada |
| `25_finanzas_conciliacion.sql` | **Criterio 14:** la conciliación con diferencia exige su ajuste con motivo (dirección, monto y fecha correctos), queda en la bitácora y el ajuste se ve |
| `26_finanzas_semanas.sql` | **Criterio 24:** cierre con pendientes, la semana cerrada no cambia, se reabre (solo el estado, en la bitácora) y se vuelve a cerrar con la versión 2 del cierre |
| `27_finanzas_idempotencia.sql` | **Criterio 27:** reenviar el mismo id con el mismo contenido no duplica ni falla (con y sin `ON CONFLICT DO NOTHING`, también anulaciones, aperturas y partidas de semanas ya cerradas); con otro contenido, 23505 |
| `28_finanzas_maestra.sql` | **D19, D18, I2, M6 y M10 con las respuestas del 23/oct:** la cuenta maestra ve la portada sin consulta y el contenido de un libro ajeno solo con una consulta registrada y vigente (30 minutos, por libro y por persona; vence; la de otra persona no sirve; no se la escribe a mano); **es de solo lectura total** (ningún INSERT, UPDATE ni función escribe en lo ajeno ni en lo del hogar, y tampoco en un libro compartido donde alguien la quisiera); la dueña como maestra sí escribe en lo suyo; solo el dueño la asigna (nunca familiar ni Casa; no a quien lleva libro propio, como Alex) y el cambio queda en la bitácora para todo adulto con Finanzas; la dueña ya no ve el historial de GRAVITY ni las finanzas personales de otros |
| `29_finanzas_configuracion.sql` | Pensión de Papá (días 1 y 11) y apoyo bimestral; vigencias sin traslape; ingresos, deudas (grupo prioritario, tasas), compromisos y sobres; `regla_inhabil` por defecto `sin_cambio`; parámetros por libro; días inhábiles; libros compartidos e inactivos; libro personal automático |
| `30_bitacora.sql` | Nadie la actualiza, borra ni vacía (cada rol, `service_role` y el dueño de la tabla); cada quien agrega solo a su nombre y en su hogar; nadie usa las acciones reservadas a los triggers (M2); **I5:** las acciones `finanzas*` y las tablas `fin_*` (con mayúsculas, espacios o `public.`) son solo del servidor, para todo rol de la app |
| `31_finanzas_representado.sql` | **I3 e I4:** todo movimiento del libro de Papá (también ingreso, apertura, reclasificación y anulación) lleva `en_nombre_de` y motivo; la salida hacia un libro personal deja su entrada en la bitácora, que ve el suplente; el albacea dado de baja o sin Finanzas deja de contar y el suplente escribe |
| `32_finanzas_compartido.sql` | **I1 con las respuestas del 23/oct:** la pareja no saca a la dueña (ni moviendo su fecha de inicio); solo el administrador (quien lo creó) o el dueño miembro agrega y saca; cualquier miembro se sale siempre; con menos de 2 vigentes (al salirse o al ser sacado) el libro pasa a **privado y sigue activo** (nunca se archiva solo) y quien queda es el administrador; el último miembro no puede salirse (22023, tampoco lo saca el servidor); archivar es solo a mano, el archivado se lee sin registrar y lo reactiva solo su administrador; si se sale el creador, o ya no es adulto del hogar, `creado_por` pasa al miembro vigente más antiguo (y nadie se adelanta cambiando su `desde`); las bajas del hogar cuentan como ausencia; quien se salió no vuelve a entrar (tampoco con `upsert`); la maestra no es miembro |
| `33_finanzas_visibilidad.sql` | **Visibilidad de los compartidos (23/oct):** privada por omisión; solo el administrador la cambia; en privado leen y escriben los miembros, el resto del hogar (también el dueño) no ve nada y la maestra lee con consulta; en público leen (no escriben) los adultos con Finanzas, ven a los miembros y siguen sin poder agregar movimientos ni cuentas; quien no tiene Finanzas (familiar) no lo lee aunque sea público; los libros personales y el de Papá solo pueden ser privados (23514); al salirse o sacar a alguien de uno público y quedar menos de 2, pasa a privado y deja de leerlo el resto del hogar; archivado y público se lee en solo lectura |
| `35_finanzas_adultos.sql` | **`fin_adultos_con_finanzas`:** la ven el dueño, el coadministrador y la maestra (que no aparece); devuelve dueño y coadministradores con su nombre y rol; nunca la maestra no dueña, familiar, cuidador, casa ni Papá; cero filas para familiar, cuidador, casa, otro hogar, sin hogar y hogar nulo; anon y `service_role` no la ejecutan; las bajas y los cambios de rol la actualizan; la dueña que además es maestra aparece |
| `36_finanzas_endurecimiento_1b.sql` | **N1 a N5 de la revisión 1b:** el tope de la bitácora (4 KB y 500 por persona en 24 horas; familiar y Hogar; por persona; las de más de 24 h no cuentan; las automáticas no cuentan ni se limitan; `service_role` sin tope; I5 sigue); el motivo con tabuladores, saltos, espacios Unicode e invisibles en gasto de papá, anulación, ajuste y conciliación (y los controles: un gasto normal con motivo corto, un reenvío idéntico); toda salida del libro de papá avisa al suplente, también hacia un compartido; `fin_nombrar_albacea` (solo el dueño, cargo vacío, cargo de quien se fue, errores, sin sesión ni `service_role`); el relevo del administrador por baja o cambio de rol, el paso a privado y la baja sin nadie a quien pasar el cargo |
| `37_finanzas_portada_representado.sql` | **Portada del libro de papá:** el dueño que no es miembro ve la fila del libro representado y las de sus miembros (y los nombres de esas personas) y **nada más** (ni cuentas, movimientos, saldos, plan, cierres, conciliaciones ni bitácora del libro); no escribe (0 filas; el insert directo da 42501) y `fin_puede` sigue negando; no ve compartidos privados ni libros personales de otros; la dueña de otro hogar no ve el libro de este ni al revés; coadministrador no miembro, familiar, cuidador y Hogar no ven nada; la maestra no cambia (portada sí, contenido solo con consulta); sin sesión no se lee; con la portada la dueña se nombra albacea y lee todo; la dueña-maestra ve la portada pero no el contenido sin consulta |
| `82_avisos_rls.sql` | **D20, criterios 32 (esquema), 39, 41, 42, 47:** `avisos` sin columnas de monto, nombre ni texto libre; tipo y clave de catálogo cerrado; nadie inserta, cambia ni borra directo; la pareja, otro hogar y una familiar no ven avisos; quién tiene preferencias (no la maestra, ni familiar, cuidador o Casa) y que se crean y se quitan con el rol; cambiar las propias con rangos (tope, zona, día, tipos); dispositivos: teléfono sí, tablet personal y laptop no, tablet pública nunca, reasignación del token (M13), sin insert directo; `fin_emitir_aviso` (permisos, tipos emitibles, clave, objeto, idempotencia, destinatarios de compartido, de papá y de `partida_80`, tope de 60 al día) |
| `83_avisos_generacion.sql` | **Criterios 34 a 38:** 3 y 1 días antes a las 9:00; una deuda dada de alta el 11/nov solo crea el del 11; idempotencia; cambiar la fecha cancela y recrea; registrar el pago cancela; pago vencido (retrasada, aviso al día siguiente y a los 3 días, luego se calla); monto cero no avisa; ingreso retrasado; compartido = todos y cada quien a su hora; horas silenciosas (críticas, `criticas_en_silencio`, no críticas, madrugada); tope diario (4.º agrupado, críticas y recordatorios no cuentan, día en la zona de la persona); tipo silenciado; `avisos_marcar` |
| `84_avisos_base_80.sql` | **Criterio 48:** al 79 % no avisa; al 80 % avisa solo a los dueños (importante); al 90 % crítico; uno al día; límite configurable (y en cero no falla); sale a las 07:00 por el silencio; dueño de baja no recibe; la app no ejecuta estas funciones |
| `85_finanzas_fase2.sql` | **Criterios 1, 2, 12, 26, 27, 28, 57:** clases de deuda y sus checks (clase por omisión), parámetros nuevos, MSI, estados de cuenta solo agregar (vigente, idempotencia, 23505), bolsas (un fondo, cuenta de ahorro, campos por tipo, métodos, tipo fijo), aportaciones (pendiente generada, confirmar, semana cerrada, inmutables), retiros (motivo de 3 caracteres, desde la bolsa, uno por movimiento, solo agregar), saldos desde el libro; la pareja, familiar, cuidadora, Casa y otro hogar no ven nada; la maestra con consulta lee y nunca escribe; columnas que pone el servidor |
| `86_avisos_envio.sql` | **Criterios 27, 40, 42, 49, 50:** `avisos_reclamar` (un renglón por aviso y dispositivo, no se reclama dos veces, se libera a los 3 minutos, tablet pública y tablet personal apagada nunca, baja no recibe, solo `service_role`), entregas (token inválido se borra, 5 fallos desactivan), reintentos a los 5, 15 y 60 minutos, retención de 90 y 30 días sin tocar la bitácora, aviso al suplente de papá (no a quien hizo el movimiento; sin suplente nada), aviso del retiro de una bolsa compartida, una consulta de la maestra por minuto y libro |
| `88_finanzas_fase2_endurecimiento.sql` | **F2-1, F2-3, F2-4, F2-5:** errores transitorios no apagan el push, los rechazos sí (5), reactivación del teléfono (no de tablet pública ni la elección de la tablet personal), llave compuesta del destino del retiro, objeto del aviso del libro, solo miembros emiten, 5 críticas por día y libro, horas silenciosas coherentes |
| `89_habitos_rls.sql` | **Hábitos, lo propio:** cada quien ve solo lo suyo (dueña, pareja, familiar); la dueña no ve lo de la pareja ni la familiar; la cuenta maestra, la cuidadora, Hogar, otro hogar y anon no leen ni escriben nada; la app no manda persona, hogar ni actualizado_en; el servidor deja los registros a nombre propio; llaves compuestas (no se apunta a lo de otro); un registro por elemento y día; último cambio gana (más viejo se ignora, futuro lejano se ajusta); ajustes y modos; plan de lectura idempotente; quién tiene Hábitos (maestra fuera, dueña-maestra no); sin bitácora y `habitos*` reservado y oculto; baja: sin acceso al instante, conserva y borra a los 90 días |
| `90_habitos_sensibles.sql` | **Sensibles:** `hab_sobres` solo cifrado y horas del servidor; nadie escribe directo; la pareja y la maestra no ven sobres ni llaves; llaves (versión 1, +1, idempotente, constancia sin contenido); modos (55000 sin llave, volver a solo teléfono exige confirmación y borra, sube la época); subida en lote (50, idempotente, +1, conflictos, base64url, 64 KB, cuota, sobre ajeno 42501, tumbas); reiniciar la nube y borrar mis datos (con constancia); limpieza de tumbas; la tablet personal registra su dispositivo |
| `91_habitos_endurecimiento.sql` | **F3-3 a F3-10:** alias del KDF; 600 borrados dejan una constancia; `hab_hogar_de` no revela el hogar de otros; cuota de filas por persona (2 000 objetivos, por persona); baja con `activa = false` y con `hasta` vencido se borra a los 90 días desde `desactivada_en`; volver al hogar borra la fecha de baja |
| `92_alimentacion.sql` | **D23:** cada rol contra cada tabla: dueña y pareja editan los dos menús, el perfil clínico de Papá solo lo edita el dueño; la familiar edita el menú de Papá y no ve nada de la pareja ni la lista de compras; la cuidadora solo ve a Papá y su lista; la maestra solo lee los dos; Casa, otro hogar y anon, nada; lo que pone el servidor; llaves e índices del menú; la dueña-maestra conserva sus permisos; sin precios, sin bitácora, cuota de filas. (F4-M1 está en la 36.) |
| `34_finanzas_maestra_login.sql` | **Cuenta maestra con login propio (23/oct):** la invitación del dueño con `es_maestra` (solo el dueño la crea, solo con rol coadministrador, con un correo de fuera del hogar; se revoca al reinvitar; la vencida no sirve); al aceptarla no se crea libro personal, es solo lectura total, no es miembro de nada, no ve Cuidados ni Hábitos y sigue necesitando la consulta de 30 minutos; reemplaza a la anterior con su entrada en la bitácora |
| `40_aislamiento_hogares.sql` | Una persona de otro hogar no ve ni toca nada |
| `50_invitaciones.sql` | Solo el dueño las ve y crea; token solo en hash; correo confirmado; expiración, revocación y reuso; volver al hogar con la membresía vencida (M3) |
| `60_anon.sql` | Sin sesión no se ve ni se ejecuta nada, aun con un `sub` falsificado |
| `70_membresias_personas.sql` | El cuidador no ve a la familia y su GRAVITY es restringido (D18); el coadministrador no entra a Cuidados; el dueño, GRAVITY propio (D18); quien comparte un libro ve a sus miembros (D19); roles, bajas y fechas de fin; lo propio; dispositivos |

| `80_calidad_fase1.sql` | Guardias de la revisión de calidad de la Fase 1: escalada, roles sin Finanzas, solo agregar (con TRUNCATE en cascada), cruce entre libros, reenvío de otra persona |
| `81_calidad_fase1b.sql` | Guardias de la revisión de calidad de la Fase 1b (las escribe calidad): intentos de romper las reglas del 23/oct (cuenta maestra con login propio, compartidos, libro de Papá, bitácora); no dependen de que un compartido se archive. Sus hallazgos abiertos (N1 a N5) ya se cerraron en `36_finanzas_endurecimiento_1b.sql` y `hallazgos_fase1b.sql` se retiró |
| `95_cuidados_roles.sql` | **Fase 5, criterios 2 y 6:** cada rol ve y escribe lo que la spec 5 §5 permite (dueña, pareja sin y con consentimiento, maestra, hermana, cuidadora); la cuidadora no ve Finanzas, Hábitos, miembros ni la bitácora de auditoría de la familia; Casa (tablet y bocinas), otro hogar, sin hogar y `anon` no ven nada; comidas, bitácora y entregas solo agregar; el servidor pone quién y cuándo; lo clínico no se copia a la bitácora de auditoría ni a los avisos |
| `95_cuidados_turnos.sql` | **Criterios 1 y 4:** `cui_quien_en_turno` con el horario de la spec §3 (límites exactos, zona del hogar, domingo del dueño) y turno residual del dueño (sin cuidadora ni hermana devuelve al dueño); la toma de las 8:00 del lunes va al dueño; marcar "dado" solo la cuidadora a la hora de su turno o el dueño, nunca la hermana ni la pareja; cada marca en la bitácora sin datos clínicos; cambio urgente del dueño con aviso crítico inmediato solo al cuidador de turno |
| `95_cuidados_resumen.sql` | **Criterio 3:** gastos de cuidado pendientes/confirmados/rechazados; el resumen mensual excluye a la pareja y al dueño; la hermana lo ve solo con la autorización del albacea (no la pareja, la maestra, la cuidadora, Casa ni `anon`); lo retira de inmediato; devuelve solo totales |
| `95_cuidados_baja.sql` | **Criterio 5:** la baja (con `activa = false` o `hasta = now()`) corta todo en la misma transacción, también el resumen autorizado; cancela sus avisos; lo que registró queda a su nombre; un cuidador sin turnos no tiene acceso |

Los casos de la revisión de calidad de la Fase 0 (`docs/revisiones/fase-0.md`: I1, M1, M2 y M3) y de la Fase 1 (`docs/revisiones/fase-1.md`: I1 a I5, M6 y M10) viven en estos archivos con la clave del hallazgo al inicio de su descripción (p. ej. `M2: …`, `I2: …`); `hallazgos_fase0.sql` y `hallazgos_fase1.sql` ya no existen.

**Requisitos:** PostgreSQL 15 o superior con el servidor (`initdb`, `pg_ctl`). En Ubuntu: `apt-get install postgresql-16`. El script busca los binarios en el PATH, con `pg_config` o en `/usr/lib/postgresql/*/bin` (o usa `PG_BIN`). El clúster temporal solo escucha por un socket en `/tmp/gravity-pg.*` y se borra al terminar; como root corre el servidor con el usuario `postgres`. En Windows, córrelo en WSL.

**Variables:** `GRAVITY_PG_URL` usa un servidor existente en lugar del clúster temporal (crea y borra una base de prueba; p. ej. el Postgres de Supabase local, `postgresql://postgres:postgres@127.0.0.1:54322/postgres`); `GRAVITY_PG_MANTENER=1` deja el clúster encendido para revisarlo.

**Ayudantes** (`tests/01_utilidades.sql`): `pruebas.como('correo')`, `pruebas.como_anon()`, `pruebas.como_servicio()`, `pruebas.como_postgres()`, `pruebas.ok`, `pruebas.igual`, `pruebas.cuenta(sql)`, `pruebas.afecta(sql)`, `pruebas.falla(sql, desc, sqlstate)`; `pruebas.nuevo_adulto('correo', nombre, rol, hogar)` (crea una cuenta confirmada con su membresía; por omisión coadministrador en Hogar Ejemplo: el tercer adulto de las pruebas de libros compartidos); de Finanzas: `pruebas.libro_personal('correo')`, `pruebas.cuenta_sistema(libro, tipo)` y `pruebas.registrar(tipo, origen, destino, monto, …)` (inserta un movimiento como la sesión y devuelve su id, o nulo si el servidor no insertó nada por ser un reenvío idéntico).

## Datos de ejemplo (`seed.sql`)

Hogar Ejemplo, el hogar de Ana y Alex del diseño de FINANZAS: `ana@` dueña, `alex@` coadministrador (la pareja), `carla@` familiar, `diana@` cuidador, `casa@` rol casa (la cuenta del equipo de la tablet; su nombre visible es **"Hogar"**) y `marta@` coadministrador con la **cuenta maestra** con su propio login (solo lectura, sin libro personal; es el ejemplo de lo que el dueño crea con una invitación); "Papá (ejemplo)" es la persona bajo cuidado, **sin cuenta**. Hogar Vecino (`elena@`, dueña) y `nuevo@` sin hogar con una invitación pendiente (token `token-de-ejemplo-solo-local`). Todos en `@ejemplo.test`.

Finanzas (montos inventados, inspirados en el ejemplo 5.6 bis): libros personales de Ana y Alex (los crea el servidor; Marta no lleva libro), "Gastos de la casa" (`f100…0001`, compartido **privado** por Ana y Alex) y "Papá (ejemplo)" (`f100…0002`, representado: Ana albacea, Alex suplente) con su pensión los días 1 y 11 (siguiente día hábil) y un apoyo bimestral. Árbol común de 21 categorías y 12 cuentas de gasto del hogar; cuentas, ingresos, compromisos, sobres, deudas (grupo prioritario), aperturas, gastos, aportaciones al compartido, movimientos en nombre de Papá, una conciliación con ajuste, la semana del 12/oct cerrada con su cierre y la del 19/oct activa, ocurrencias, días inhábiles y una importación. El seed carga cada parte "como" quien lo haría en la app (pasa por las mismas validaciones del servidor). Las cuentas **no tienen contraseña**: nadie puede entrar con ellas aunque el seed llegara por error a un proyecto real. Para entrar en Supabase local, ponles contraseña en Studio (*Authentication › Users*) o crea tus propias cuentas.

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

**Nota:** `20261020000000_base.sql` se corrigió en el mismo archivo tras la revisión de calidad de la Fase 0, y `20261021000000_finanzas_mvp1.sql` se ajustó en su archivo durante la Fase 1, porque ninguna se ha aplicado al proyecto real. Las correcciones de la revisión de calidad de la Fase 1 ya van en una migración nueva (`20261023000000_finanzas_salvaguardas.sql`). Si ya la tenías en Supabase local, corre `supabase db reset`. Desde que se aplique al proyecto real, todo cambio va en una migración nueva.

## Convenciones para migraciones nuevas

1. Archivo nuevo `AAAAMMDDHHMMSS_descripcion.sql`; nunca editar una migración ya aplicada. Compatible con PostgreSQL 15.
2. Cada tabla nueva: `enable row level security`; `revoke all … from public, anon, authenticated, service_role` y `grant` explícito (por columna si hay columnas que pone el servidor); reglas `to authenticated` con `puede()` / `puede_sobre()` / `alcance()`.
3. Funciones SECURITY DEFINER con `set search_path = ''` y nombres calificados; `revoke execute … from public, anon, authenticated` y `grant` a quien corresponda (en `public`, `authenticated` las recibe por omisión y quedan como RPC).
4. Dinero en `bigint` de centavos; fechas `date` / `timestamptz`; UUID que puede generar el dispositivo (cola sin conexión idempotente).
5. Libros solo-agregar: sin reglas ni privilegios de UPDATE/DELETE y los dos triggers de `impedir_cambios_solo_agregar()` (fila y TRUNCATE), como en `bitacora` y en los libros de Finanzas. Con la cola sin conexión: trigger `fin_una_vez('estricto', <columnas del servidor>)` (o uno propio, como el de `fin_movimientos`) para que un reenvío idéntico no falle.
6. Cambios que importan: trigger `registrar_cambio_en_bitacora('hogar_id', <columnas a omitir>)`. Las entradas que agregue la app usan acciones propias en minúsculas (nunca `insertar`, `actualizar` ni `borrar`, ni un prefijo reservado como `finanzas`, ni una tabla `fin_*`: son del servidor).
7. Pruebas nuevas en `tests/NN_*.sql`. Las de `10_esquema.sql` y `60_anon.sql` ya revisan solas que toda tabla nueva tenga RLS y que `anon` no la vea.
8. Si la migración llena una tabla de catálogo, agrégala a `$script:TablasDeMigracion` en `herramientas/respaldo/respaldo_comun.ps1`.
9. Los errores de los triggers usan 23xxx, 22xxx, 42501 o 55000; nunca clases que la cola reintenta (08, 40001, 40P01, 53, 57). 23503 solo para "falta algo de lo que depende" (la cola lo reintenta).
10. Dentro de un `IF` de PL/pgSQL, envuelve cada `CASE` en paréntesis (si no, su `THEN` corta la condición). Un trigger compartido por varias tablas no lee en una misma expresión columnas que solo tiene una de ellas.
11. Corregir una función o regla de una migración ya revisada: migración nueva con `create or replace function` (y `drop policy` + `create policy`), no editar la anterior (así se hizo con `20261023000000_finanzas_salvaguardas.sql`).
12. Si una migración nueva agrega columnas a una tabla `fin_*`, el `grant insert (…)` repite **la lista completa** de columnas (los permisos por columna se suman, así que es equivalente): las pruebas de la app (`contrato_servidor_test`, `f1_g3_filas_caben_en_los_permisos_test`) leen las migraciones y toman el último `grant insert` de cada tabla. Así se hizo con `fin_libros.visibilidad`.

## Pendientes conocidos

| De la revisión | Qué | Cuándo |
|---|---|---|
| M2 (parte 2) | **Hecho para lo que la app escribe directo** (N1, migración `20261026`): 4 KB por entrada y 500 por persona en 24 horas, con trigger por sentencia. El aviso al 80 % y al 90 % de la base ya existe (`avisos_revisar_base`, Fase 2). Falta valorar un tope para las entradas automáticas | Decisión del dueño |
| M4 | Hogar preferido o función `mi_perfil()` para que la app no elija al azar entre dos hogares | Con plataforma |
| M13 | **Cerrado en la Fase 2:** token único global y `registrar_dispositivo` lo reasigna; la tablet pública nunca recibe avisos | — |
| M15 | Mantener activa la confirmación de correo en Supabase Auth (`aceptar_invitacion` confía en ella) | Al crear el proyecto (dueño) |
| Fase 1 | Las reglas de `fin_*` llaman `fin_puede()` por fila; con muchos datos conviene cambiarlas por una lista de libros legibles calculada una vez por consulta | Si la pantalla de movimientos pasa de 2 s |
| Fase 1 | La cuenta maestra lee el **historial de GRAVITY** (entradas `gravity.*`) sin consulta registrada: hoy es solo bitácora. Cuando exista la tabla del historial, debe seguir el mismo patrón que los libros (consulta registrada, vigencia de 30 minutos) | Fase 2 |
| Fase 1 | El dueño del hogar **no entra** a un compartido privado del que no es miembro (respuesta del 23/oct) y solo cambia la membresía de otros si es miembro. Si en la práctica debe poder administrar cualquier compartido, hace falta una función `SECURITY DEFINER` con entrada en la bitácora | Si el dueño responde que sí |
| Fase 1 | La maestra lee entradas de la bitácora que no son de Finanzas (membresías, invitaciones, `gravity.*`) y leerá también las de Cuidados cuando existan: hay que revisar con la Fase 5 que las notas clínicas no entren en esa regla | Fase 5 |
| Fase 1 | La matriz da a la maestra (rol coadministrador) Alimentación y Casa con alcance total: cuando esos módulos existan, decidir si la cuenta maestra debe ser solo lectura también ahí | Fases 4 y 6 |
| Fase 1 | `fin_vigencias_ingreso` (traslapes y endurecimiento de vigencias) queda **sin cambios** hasta que respondan finanzas y plataforma | Cuando respondan |
| Fase 5 | Gastos de cuidado de la cuidadora (`finanzas` × `escribir` restringido) y GRAVITY restringido de la cuidadora: necesitan su regla propia (hoy no escriben) | Fase 5 |

## Respaldos

Ver `herramientas/respaldo/README.md` (respaldo diario cifrado desde la laptop y restauración).


## Vista temporal de Finanzas de Papá (Fase 4, D24)

Migración `20261110000000_fin_vista_papa.sql`, pruebas `93_fin_vista_papa.sql`. El familiar no tiene dinero de forma permanente: pide la vista con `fin_pedir_vista_papa(motivo)`, el dueño la responde con `fin_responder_vista(solicitud, 'autorizar' | 'rechazar' | 'cancelar')` y la autorización dura 30 minutos (`vigente_hasta`). `fin_vista_papa_vigente()` dice si la hay; `fin_puede(libro, 'leer')` la usa para el libro representado, y el servidor niega al pasar `vigente_hasta` o cancelar. `fin_vistas_vencer()` (solo servidor, `pg_cron` cada 5 min) marca `vencida`. La tabla `fin_vistas_solicitadas` (27.ª tabla `fin_*`) solo cambia por RPC y su bitácora no lleva motivo, montos ni cuentas. Aviso al dueño: tipo `solicitud_vista` (crítico). Contrato completo: `docs/specs/fase-4-vista-temporal.md`, sección 6.


## Cuidados (Fase 5)

Migraciones `20261113000000_cuidados_avisos.sql`, `20261114000000_cuidados_esquema.sql`, `20261115000000_cuidados_operaciones.sql`, `20261116000000_cuidados_matriz.sql` y `20261117000000_cuidados_v11.sql`; pruebas `95_cuidados_*.sql`; según `docs/specs/fase-5-cuidados.md` v1.1 (turnos §3, consentimientos §4, permisos §5, criterios §7). **Los permisos los decide `cui_puede()`, no `permisos_rol`** (la matriz es solo el espejo de la app). Los medicamentos, las comidas y la bitácora de cuidados son **datos clínicos (D3)**: nunca a la IA en la nube, a las bocinas ni a la tablet pública. Casa no ve nada.

### Quién es quién (`cui_perfil(hogar)`)

| Perfil | Quién es |
|---|---|
| `dueno` | Rol `dueno` (también cuida: domingos y tardes de sábado y lunes) |
| `pareja` / `pareja_consentida` | Rol `coadministrador` (la cuenta maestra también); `pareja_consentida` si tiene `cui_consentimientos.concedido` para sí misma |
| `cuidadora` | Rol `cuidador` o `familiar` con algún turno de tipo `cuidadora` |
| `hermana` | Rol `cuidador` o `familiar` con algún turno de tipo `hermana_visita` |
| nulo | Casa, un cuidador o familiar **sin turnos**, un miembro dado de baja, otro hogar, `anon`: sin acceso |

Una baja (`activa = false` o `hasta` vencido) quita el perfil **en la misma consulta**: todas las reglas parten de `rol_en_hogar()`. Además `cui_baja_cancela_avisos()` cancela sus avisos de Cuidados pendientes y `cui_quien_en_turno()` deja de contarla. Lo que registró queda a su nombre.

**Cuidados v1.1 (`20261117`, respuestas del dueño del 7/nov/2026, spec §8c).** (1) La política `cui_bitacora_leer` limita a la cuidadora a sus propias entradas y a las de autores que `cui_autor_visible_cuidadora()` acepta (el dueño del hogar y quien tiene turnos de hermana); no ve las de la pareja ni de nadie más. Dueño y hermana siguen leyendo toda la bitácora de cuidados. (2) Turno residual: `cui_quien_en_turno(hogar, ts)`, misma firma y misma fuente de los recordatorios, devuelve al dueño vigente (tipo `dueno`) cuando no hay cuidadora ni hermana de turno; antes devolvía vacío (noches, madrugadas, huecos). Con cuidadora o hermana de turno todo queda igual, y el dueño no sale repetido si ya tiene turno propio. Los recordatorios y `cui_marcar_toma` (que sigue exigiendo cuidadora de turno o dueño) no cambian; `cui_crear_cambio_urgente` sigue avisando solo a cuidadores distintos del dueño, que es quien lo manda.

| Objeto | Dueño | Pareja | Pareja consentida | Cuidadora | Hermana |
|---|---|---|---|---|---|
| Turnos | lee y edita | lee | lee | lee | lee |
| Medicamentos y tomas | lee y edita | nada | **solo lee** | lee; marca tomas (RPC) | solo lee |
| Comidas | lee y registra | nada | solo lee | lee; registra (si tiene turno ese día) | solo lee |
| Bitácora de cuidados | lee y escribe | nada | nada | escribe; lee **lo suyo y lo del dueño y la hermana** (v1.1) | lee y escribe |
| Entregas de turno | las suyas y todas | nada | nada | las suyas | las suyas |
| Cambios urgentes | los crea (RPC) y ve todos | nada | nada | los suyos o los que nadie recibió | ídem |
| Gastos de cuidado | todos; confirma (RPC) | solo los suyos | solo los suyos | solo los suyos | solo los suyos |
| Resumen mensual | sí | no | no | no | **solo con autorización del albacea** |
| Resumen del día de Papá | sí | **sí** (conteos, sin nombres) | sí | sí | sí |

### Tablas (contrato; no cambia sin avisar)

| Tabla | Columnas |
|---|---|
| `cui_turnos` | `id`, `hogar_id`, `persona_id`, `dia_semana` 1 a 7 (1 = lunes), `inicio_min`, `fin_min` (minutos desde medianoche, 0 a 1440, `fin > inicio`; un turno no cruza la medianoche), `tipo` (`cuidadora`, `dueno`, `hermana_visita`). `dueno` es del dueño; los otros, de un cuidador o familiar vigente |
| `cui_medicamentos` | `id`, `hogar_id`, `nombre`, `dosis`, `horas text[]` (`HH:MM`, 1 a 12), `notas`, `activo`. No se borran |
| `cui_tomas` | `id`, `hogar_id`, `medicamento_id`, `programada_para`, `estado` (`pendiente`, `dado`, `no_dado`), `marcada_por`, `marcada_en`. Única por (medicamento, hora). Solo cambia con `cui_marcar_toma` |
| `cui_comidas` | `id`, `hogar_id`, `fecha`, `tiempo`, `resultado` (`comio`, `comio_poco`, `rechazo`), `registrada_por`, `registrada_en`. **Solo agregar**: la corrección es una fila nueva (vale la más reciente) |
| `cui_bitacora` | `id`, `hogar_id`, `persona_id`, `nota` (1 a 500), `creada_en`. **Solo agregar** |
| `cui_entregas` | `id`, `hogar_id`, `de_persona`, `para_persona`, `nota` (1 a 500), `creada_en`. **Solo agregar** |
| `cui_cambios_urgentes` | `id`, `hogar_id`, `de_persona`, `para_persona` (nula si nadie estaba de turno), `texto` (1 a 200), `creado_en`, `atendido_en` |
| `cui_gastos` | `id`, `hogar_id`, `persona_id`, `monto_centavos` (> 0), `concepto`, `fecha`, `estado` (`pendiente_confirmacion`, `confirmado`, `rechazado`), `confirmado_en` y dos **extensiones**: `ambito` (`cuidado` por omisión, `casa`) y `registrado_en`. Solo cambian `estado` y `confirmado_en`, una vez |
| `cui_consentimientos` | PK (`hogar_id`, `persona_id`), `concedido`, `cambiado_en`, `cambiado_por`. Solo por RPC |
| `cui_autorizacion_resumen` | PK (`hogar_id`, `persona_id` de la hermana), `autorizado_por`, `vigente`, `cambiado_en`. Solo por RPC |

La app **no manda** `persona_id`, `registrada_por`, `de_persona`, `estado`, `confirmado_en` ni los `*_en` (sin permiso de columna, 42501): los pone el servidor. Cada tabla con persona lleva un tope de 300 registros propios en 24 horas (54000). La bitácora de auditoría (`bitacora`) registra los cambios de turnos, medicamentos (**sin** nombre, dosis, horas ni notas), gastos (sin concepto), cambios urgentes (sin texto), consentimientos y autorizaciones; las tomas, con `cuidados.toma_marcada` y solo el estado.

### Operaciones (RPC)

| Función | Quién | Qué hace |
|---|---|---|
| `cui_perfil(hogar)` · `cui_puede(hogar, objeto, accion)` | cualquiera | Perfil y permiso de la sesión (espejo para la app) |
| `cui_quien_en_turno(hogar, ts = now())` → `(persona_id, tipo)` | quien tiene perfil; el servidor (`service_role`) | Quién está de turno en `ts` (zona del hogar; solo membresías vigentes). **Los recordatorios de medicamentos y comidas se envían solo a estas personas** (criterio 1) |
| `cui_generar_tomas(hogar, desde, dias = 1)` → entero | dueño; servidor | Crea las tomas pendientes de los medicamentos activos (1 a 14 días). Idempotente |
| `cui_marcar_toma(toma, 'dado' \| 'no_dado')` | dueño; cuidadora **de turno a la hora programada de la toma** | Marca y deja `cuidados.toma_marcada` en la bitácora. La hermana y la pareja no (42501) |
| `cui_crear_cambio_urgente(hogar, texto, id)` → `id` | solo el dueño | Crea el cambio y avisa **al instante** (tipo `cambio_urgente_cuidados`, crítico, sin esperar el silencio nocturno) a quien está de turno que no sea él. Idempotente por `id` |
| `cui_atender_cambio_urgente(id)` | quien lo recibe, el dueño o, si nadie estaba de turno, cuidadora u hermana | Marca atendido y resuelve el aviso |
| `cui_confirmar_gasto(gasto, confirmar)` | solo el dueño | `confirmado` o `rechazado`. **Finanzas** parte del estado `confirmado` (su función de paso es de finanzas) |
| `cui_cambiar_consentimiento(hogar, persona, concedido)` | el titular; el albacea por Papá | Concede o retira. Hoy abre a la pareja medicamentos, tomas y comidas (solo lectura) |
| `cui_autorizar_resumen(hogar, persona, vigente)` | solo el albacea (D19) | Autoriza o retira que esa persona vea el resumen mensual |
| `cui_resumen_mensual(mes)` → `(hogar_id, mes, gastos_cuidado_centavos, gastos_casa_centavos, n_gastos)` | dueño; hermana autorizada | Totales del mes de gastos **confirmados** sin los de la pareja ni los del dueño. Nunca filas. Otra sesión: 42501 |
| `cui_resumen_papa(hogar, dia)` | cualquiera con perfil, también la pareja sin consentimiento | Conteos de tomas y comidas del día, sin nombres, dosis ni notas |

Errores: `42501` sin permiso (igual exista o no el registro), `22023` dato inválido, `55000` ya resuelto, `54000` tope, `23514` regla de la tabla.

**Avisos (`20261113`).** `avisos.modulo` admite `cuidados`, `avisos.tipo` el nuevo `cambio_urgente_cuidados` (crítico) y `avisos.objeto_tipo` `cambio_urgente`; el aviso no lleva texto (D3, D20): apunta al cambio con `objeto_id`. Quien envíe los avisos (Edge Function y catálogo de la app) debe conocer el tipo nuevo.

**Matriz (`20261116`).** Dos filas nuevas: `familiar × cuidados × leer` y `escribir`, `restringido` (la hermana). El espejo de la app (`permisos.dart`) debe pasar el familiar de `ninguno` a `restringido` en Cuidados; la prueba `i1_matriz_espejo_servidor_test.dart` lo exige.

**Datos de ejemplo.** `seed.sql` carga los 11 turnos de la spec §3 (Diana, Carla y Ana) y dos medicamentos inventados.

**Límites conocidos.** No hay traslape de turnos de una misma persona (la base lo tolera) y un turno no cruza la medianoche. Los gastos de "la casa" del resumen son los que quien cuida registra con `ambito = 'casa'`; los del libro compartido de Finanzas los suma finanzas, no esta migración.
