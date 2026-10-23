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

**Bitácora.** Las entradas automáticas (`insertar`, `actualizar`, `borrar`) solo las escribe `registrar_cambio_en_bitacora()`; la regla de inserción las rechaza para cualquier sesión de la app, también la cuenta Casa (hallazgo M2). El formato de `accion` impide acciones parecidas (`Borrar`, ` borrar`, letras de otro alfabeto) para todos, también `service_role`. Desde la Fase 1 también están reservadas al servidor las acciones `finanzas*` y las entradas de tablas `fin_*` (hallazgo I5 de la revisión de la Fase 1).

## Finanzas (Fase 1)

Migraciones `20261021000000_finanzas_mvp1.sql` (tablas, reglas y triggers), según `docs/specs/fase-1-finanzas.md` v0.2 (secciones 4.1 a 4.5), D18 y D19, `20261023000000_finanzas_salvaguardas.sql` (hallazgos I1 a I5, M6 y M10 de la revisión de calidad, `docs/revisiones/fase-1.md`) y `20261024000000_finanzas_respuestas_dueno.sql` (respuestas del dueño del 23/oct: cuenta maestra con login propio y solo lectura, libros compartidos privados o públicos, cuentas de periodo) y `20261025000000_finanzas_compartidos_privados.sql` (2.ª ronda del 23/oct: un compartido que se queda con menos de 2 miembros pasa a privado y sigue activo, el último miembro no se sale, y `fin_adultos_con_finanzas`); ver la sección "Respuestas del dueño del 23/oct". Todas las tablas `fin_*` llevan `hogar_id`, RLS, privilegios por columna y bitácora automática. Dinero en `bigint` de centavos; porcentajes y tasas en puntos base (`integer`, 2000 = 20 %).

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
| Dueño del hogar | **No entra** a un compartido privado del que no es miembro (no lo ve ni lo cambia). Si es miembro, puede agregar y sacar aunque no lo haya creado |
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
- **Errores:** `23503` = falta algo de lo que depende (otra cuenta, el original de una anulación…; la cola reintenta). `23505` = duplicado o mismo id con otro contenido. `23514` = check de la tabla o falta `en_nombre_de`/motivo en el libro de Papá (monto, motivo, lunes, cascada…). `22023` = regla de negocio (combinación de cuentas, libro equivocado, papel…). `55000` = estado (cuenta no activa, semana cerrada). `42501` = sin permiso o columna que no cambia. Ninguno es de las clases que la cola reintenta (08, 40001, 40P01, 53, 57).
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
| `10_esquema.sql` | RLS en **todas** las tablas de `public` (también las futuras); funciones SECURITY DEFINER con `search_path`; `anon` sin privilegios; nadie con TRUNCATE; matriz (59 filas, D18 y D19) y su alineación con la app (I1); persona automática al registrarse; privilegios por omisión de lo que se cree después (M1); las 21 tablas `fin_*` con `hogar_id` y bitácora, los libros solo agregar sin UPDATE/DELETE/TRUNCATE ni reglas para eso, vistas con `security_invoker`, una cuenta maestra por hogar; triggers de las salvaguardas y ayudantes internos que la API no puede ejecutar; la columna `fin_libros.visibilidad`, `invitaciones.es_maestra` y una sola `crear_invitacion` (5 parámetros) |
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
| `34_finanzas_maestra_login.sql` | **Cuenta maestra con login propio (23/oct):** la invitación del dueño con `es_maestra` (solo el dueño la crea, solo con rol coadministrador, con un correo de fuera del hogar; se revoca al reinvitar; la vencida no sirve); al aceptarla no se crea libro personal, es solo lectura total, no es miembro de nada, no ve Cuidados ni Hábitos y sigue necesitando la consulta de 30 minutos; reemplaza a la anterior con su entrada en la bitácora |
| `40_aislamiento_hogares.sql` | Una persona de otro hogar no ve ni toca nada |
| `50_invitaciones.sql` | Solo el dueño las ve y crea; token solo en hash; correo confirmado; expiración, revocación y reuso; volver al hogar con la membresía vencida (M3) |
| `60_anon.sql` | Sin sesión no se ve ni se ejecuta nada, aun con un `sub` falsificado |
| `70_membresias_personas.sql` | El cuidador no ve a la familia y su GRAVITY es restringido (D18); el coadministrador no entra a Cuidados; el dueño, GRAVITY propio (D18); quien comparte un libro ve a sus miembros (D19); roles, bajas y fechas de fin; lo propio; dispositivos |

| `80_calidad_fase1.sql` | Guardias de la revisión de calidad de la Fase 1: escalada, roles sin Finanzas, solo agregar (con TRUNCATE en cascada), cruce entre libros, reenvío de otra persona |

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
| M2 (parte 2) | Límite de entradas por persona en la bitácora (hoy cada miembro puede agregar sin límite, hasta 32 KB por entrada). Conviene hacerlo junto con la cola sin conexión de la app (I4, M16), para que un rechazo no se pierda en silencio, y con un trigger por sentencia (una inserción en lote se salta un conteo por fila) | Fase 1 |
| M4 | Hogar preferido o función `mi_perfil()` para que la app no elija al azar entre dos hogares | Con plataforma |
| M13 | Un mismo token de avisos puede quedar a nombre de varias personas (tablet compartida): token único global con una función que lo reasigne, o avisos de la tablet solo a la cuenta Casa | Fase 2 |
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
