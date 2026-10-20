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
| `membresias` | Rol de la persona en el hogar (`dueno`, `coadministrador`, `familiar`, `cuidador`, `casa`), `activa`, `desde`, `hasta` | Cada quien las suyas; el dueño todas. El dueño cambia roles y da de baja (no a sí mismo, ni nombra otro dueño). No se borran |
| `permisos_rol` | Matriz rol × módulo × acción con su `alcance` | Cualquier sesión (espejo de la app). Solo cambia por migración |
| `invitaciones` | Invitación a un hogar: correo, rol, **hash** del token, expiración, aceptación, revocación | Solo el dueño |
| `dispositivos` | Dispositivos de cada persona y su token de avisos (FCM) | Cada quien los suyos |
| `bitacora` | Auditoría **solo agregar**: quién (`persona_id`), qué (`accion`), cuándo (`ocurrido_en`, `registrado_en`), `tabla`, `registro_id`, `detalle`. `accion` en minúsculas (`^[a-z][a-z0-9_.]*$`, p. ej. `entrega_de_turno`, `gravity.abrir`); `insertar`, `actualizar` y `borrar` están **reservadas** a los triggers | El dueño la de su hogar; cada quien lo que él hizo |
| `finanzas_muestra` | **Muestra** de la Fase 0 para demostrar la regla del dinero; la reemplaza el esquema de Finanzas en la Fase 1 | Dueño lee y escribe; coadministrador solo lee; familiar, cuidador y casa nada |

**Matriz (`permisos_rol`).** Es la de `docs/specs/fase-0-cimientos.md`, sección 5, con una columna `alcance`:

| Alcance | Significa | Ejemplo |
|---|---|---|
| `total` | Todo el módulo en el hogar | Dueño en Finanzas; coadministrador lee Finanzas |
| `propio` | Solo los registros de la persona | Hábitos para todos (ni el dueño ve los de otros, D13); Ajustes "lo propio" |
| `restringido` | Un subconjunto que el módulo define en su fase (la `nota` dice cuál) | Cuidador en Cuidados: "su turno" (Fase 5) |

Sin fila = sin acceso. `restringido` tampoco da acceso mientras el módulo no defina su regla en su fase: hoy el coadministrador **no** entra a Cuidados (hasta que exista el consentimiento, Fase 5) y el cuidador **no lee** Finanzas (solo escribirá sus gastos de cuidado, Fase 5).

El módulo `gravity` no está en la sección 5; se alineó con el espejo de la app en la revisión de la Fase 0 (hallazgo I1): dueño `total`; coadministrador, familiar y casa `propio`; cuidador **sin acceso** (D5: solo Cuidados). Si cambias la matriz, cambia también el espejo (`app/lib/nucleo/permisos/permisos.dart`): la prueba `app/test/revision_calidad/i1_matriz_espejo_servidor_test.dart` lee esta migración y compara.

**Funciones para las reglas** (SECURITY DEFINER, `search_path` vacío; las pueden usar las reglas de cualquier tabla):

| Función | Devuelve |
|---|---|
| `persona_actual()` | `personas.id` de la sesión |
| `rol_en_hogar(hogar)` | Rol **vigente** de la sesión en el hogar (nulo si no es miembro o está dado de baja) |
| `alcance(hogar, modulo, accion)` | `total`, `propio`, `restringido` o nulo |
| `puede(hogar, modulo, accion)` | Verdadero **solo** con alcance `total` |
| `puede_sobre(hogar, modulo, accion, persona)` | `total`, o `propio` si el registro es de la sesión |
| `puede_ver_persona(persona)` | Para la regla de `personas` |
| `mis_permisos(hogar)` | Los permisos del rol de la sesión (espejo para la app) |

Un módulo o acción mal escrito en una regla **lanza error** en lugar de negar en silencio.

**Operaciones (RPC) para la app:** `crear_hogar(nombre)` (quien lo crea queda como dueño); `crear_invitacion(hogar, correo, rol, dias)` (solo dueño; devuelve el token **una vez**); `aceptar_invitacion(token)` (correo confirmado igual al invitado); `revocar_invitacion(id)`.

**Solo agregar.** `impedir_cambios_solo_agregar()` es un trigger reutilizable que bloquea UPDATE, DELETE y TRUNCATE para cualquier rol, también para el dueño de la tabla. La bitácora además no tiene reglas de UPDATE ni DELETE ni esos privilegios. Los cambios de `hogares`, `membresias`, `invitaciones` y `finanzas_muestra` se registran solos con `registrar_cambio_en_bitacora()`.

**Privilegios.** Supabase concede todo por defecto a `anon` y `authenticated`; la migración revoca y concede solo lo necesario, por columna cuando aplica (p. ej. nadie puede fijar `persona_id` ni `registrado_en` de la bitácora: los pone el servidor). `anon` no tiene acceso a nada.

**Red de seguridad para lo que se cree después** (hallazgo M1), por si una migración olvida revocar: las funciones nuevas no se pueden ejecutar desde `PUBLIC` ni `anon` (PostgreSQL da `EXECUTE` a `PUBLIC` en todos los esquemas, por eso se revoca sin `in schema`); las tablas nuevas no dan nada a `anon`, ni `TRUNCATE`, `REFERENCES` o `TRIGGER` a `authenticated`, ni `TRUNCATE` a `service_role`. Ojo: una función nueva en `public` **sí** la ejecuta `authenticated` (privilegio de Supabase) y queda expuesta como RPC: revoca si no es para la app.

**Bitácora.** Las entradas automáticas (`insertar`, `actualizar`, `borrar`) solo las escribe `registrar_cambio_en_bitacora()`; la regla de inserción las rechaza para cualquier sesión de la app, también la cuenta Casa (hallazgo M2). El formato de `accion` impide acciones parecidas (`Borrar`, ` borrar`, letras de otro alfabeto) para todos, también `service_role`.

## Pruebas

```bash
supabase/tests/correr.sh            # resumen por archivo
supabase/tests/correr.sh -v         # cada afirmación
supabase/tests/correr.sh 20_finanzas_muestra.sql
```

Crea una base desechable, aplica `tests/00_emulacion_supabase.sql` (roles `anon`, `authenticated`, `service_role`, `auth.users` y `auth.uid()` como en Supabase), las migraciones (cada una en su transacción), `seed.sql` y `tests/01_utilidades.sql`; luego corre cada `tests/NN_*.sql` (de 10 a 99) dentro de `begin … rollback`. Sale con error si algo falla.

| Archivo | Comprueba |
|---|---|
| `10_esquema.sql` | RLS en **todas** las tablas de `public` (también las futuras); funciones SECURITY DEFINER con `search_path`; `anon` sin privilegios; nadie con TRUNCATE; matriz de la sección 5 y su alineación con la app (I1); persona automática al registrarse; privilegios por omisión de lo que se cree después (M1) |
| `20_finanzas_muestra.sql` | Dueño lee y escribe; coadministrador lee y no escribe; familiar, cuidador y casa no leen (ni por la bitácora); la baja quita el acceso |
| `30_bitacora.sql` | Nadie la actualiza, borra ni vacía (cada rol, `service_role` y el dueño de la tabla); cada quien agrega solo a su nombre y en su hogar; nadie usa las acciones reservadas a los triggers (M2) |
| `40_aislamiento_hogares.sql` | Una persona de otro hogar no ve ni toca nada |
| `50_invitaciones.sql` | Solo el dueño las ve y crea; token solo en hash; correo confirmado; expiración, revocación y reuso; volver al hogar con la membresía vencida (M3) |
| `60_anon.sql` | Sin sesión no se ve ni se ejecuta nada, aun con un `sub` falsificado |
| `70_membresias_personas.sql` | El cuidador no ve a la familia ni usa GRAVITY; el coadministrador no entra a Cuidados; el dueño, GRAVITY total (I1); roles, bajas y fechas de fin; lo propio; dispositivos |

Los casos de la revisión de calidad de la Fase 0 (`docs/revisiones/fase-0.md`: I1, M1, M2 y M3) viven en estos archivos con la clave del hallazgo al inicio de su descripción (p. ej. `M2: …`); `hallazgos_fase0.sql` ya no existe.

**Requisitos:** PostgreSQL 15 o superior con el servidor (`initdb`, `pg_ctl`). En Ubuntu: `apt-get install postgresql-16`. El script busca los binarios en el PATH, con `pg_config` o en `/usr/lib/postgresql/*/bin` (o usa `PG_BIN`). El clúster temporal solo escucha por un socket en `/tmp/gravity-pg.*` y se borra al terminar; como root corre el servidor con el usuario `postgres`. En Windows, córrelo en WSL.

**Variables:** `GRAVITY_PG_URL` usa un servidor existente en lugar del clúster temporal (crea y borra una base de prueba; p. ej. el Postgres de Supabase local, `postgresql://postgres:postgres@127.0.0.1:54322/postgres`); `GRAVITY_PG_MANTENER=1` deja el clúster encendido para revisarlo.

**Ayudantes** (`tests/01_utilidades.sql`): `pruebas.como('correo')`, `pruebas.como_anon()`, `pruebas.como_servicio()`, `pruebas.como_postgres()`, `pruebas.ok`, `pruebas.igual`, `pruebas.cuenta(sql)`, `pruebas.afecta(sql)`, `pruebas.falla(sql, desc, sqlstate)`.

## Datos de ejemplo (`seed.sql`)

Hogar Ejemplo con una persona por rol (`ana@` dueño, `beto@` coadministrador, `carla@` familiar, `diana@` cuidador, `casa@` casa), Hogar Vecino (`elena@`, dueña) y `nuevo@` sin hogar con una invitación pendiente (token `token-de-ejemplo-solo-local`). Todos en `@ejemplo.test`. Las cuentas **no tienen contraseña**: nadie puede entrar con ellas aunque el seed llegara por error a un proyecto real. Para entrar en Supabase local, ponles contraseña en Studio (*Authentication › Users*) o crea tus propias cuentas.

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

**Desarrollo con Supabase local** (Docker): `supabase start` y `supabase db reset` (migraciones + seed). `supabase/.branches` y `supabase/.temp` están ignoradas por git.

**Nota:** `20261020000000_base.sql` se corrigió en el mismo archivo tras la revisión de calidad de la Fase 0, porque aún no se había aplicado al proyecto real. Si ya la tenías en Supabase local, corre `supabase db reset`. Desde que se aplique al proyecto real, todo cambio va en una migración nueva.

## Convenciones para migraciones nuevas

1. Archivo nuevo `AAAAMMDDHHMMSS_descripcion.sql`; nunca editar una migración ya aplicada. Compatible con PostgreSQL 15.
2. Cada tabla nueva: `enable row level security`; `revoke all … from public, anon, authenticated, service_role` y `grant` explícito (por columna si hay columnas que pone el servidor); reglas `to authenticated` con `puede()` / `puede_sobre()` / `alcance()`.
3. Funciones SECURITY DEFINER con `set search_path = ''` y nombres calificados; `revoke execute … from public, anon, authenticated` y `grant` a quien corresponda (en `public`, `authenticated` las recibe por omisión y quedan como RPC).
4. Dinero en `bigint` de centavos; fechas `date` / `timestamptz`; UUID que puede generar el dispositivo (cola sin conexión idempotente).
5. Libros solo-agregar: sin reglas ni privilegios de UPDATE/DELETE y los dos triggers de `impedir_cambios_solo_agregar()` (fila y TRUNCATE), como en `bitacora`. Los movimientos de Finanzas (Fase 1) así; `finanzas_muestra` es solo una muestra y se borra.
6. Cambios que importan: trigger `registrar_cambio_en_bitacora('hogar_id', <columnas a omitir>)`. Las entradas que agregue la app usan acciones propias en minúsculas (nunca `insertar`, `actualizar` ni `borrar`).
7. Pruebas nuevas en `tests/NN_*.sql`. Las de `10_esquema.sql` y `60_anon.sql` ya revisan solas que toda tabla nueva tenga RLS y que `anon` no la vea.
8. Si la migración llena una tabla de catálogo, agrégala a `$script:TablasDeMigracion` en `herramientas/respaldo/respaldo_comun.ps1`.

## Pendientes conocidos

| De la revisión | Qué | Cuándo |
|---|---|---|
| M2 (parte 2) | Límite de entradas por persona en la bitácora (hoy cada miembro puede agregar sin límite, hasta 32 KB por entrada). Conviene hacerlo junto con la cola sin conexión de la app (I4, M16), para que un rechazo no se pierda en silencio, y con un trigger por sentencia (una inserción en lote se salta un conteo por fila) | Fase 1 |
| M4 | Hogar preferido o función `mi_perfil()` para que la app no elija al azar entre dos hogares | Con plataforma |
| M12 | Los movimientos reales de Finanzas, solo-agregar con `impedir_cambios_solo_agregar()` (`finanzas_muestra` permite UPDATE y DELETE: es muestra) | Fase 1 |
| M13 | Un mismo token de avisos puede quedar a nombre de varias personas (tablet compartida): token único global con una función que lo reasigne, o avisos de la tablet solo a la cuenta Casa | Fase 2 |
| M15 | Mantener activa la confirmación de correo en Supabase Auth (`aceptar_invitacion` confía en ella) | Al crear el proyecto (dueño) |

## Respaldos

Ver `herramientas/respaldo/README.md` (respaldo diario cifrado desde la laptop y restauración).
