# Respaldo diario de GRAVITY

Supabase en el plan gratis **no hace copias de seguridad** (D7). La laptop Windows hace una copia completa cada día, cifrada, en dos lugares: una carpeta local y una segunda ubicación fuera de la laptop (p. ej. un disco externo).

| Archivo | Qué es |
|---|---|
| `respaldo_diario.ps1` | Respaldo: volcado, cifrado AES-256, dos ubicaciones, retención y registro |
| `restaurar.ps1` | Restauración en una base **vacía** que ya tiene las migraciones, con verificación |
| `respaldo_comun.ps1` | Funciones comunes de los dos scripts (no se corre solo) |
| `probar_respaldo.sh` | Prueba de todo el flujo en Linux contra una base local |

Los scripts funcionan con **Windows PowerShell 5.1** (el que trae Windows) y con PowerShell 7. Están guardados en UTF-8 con BOM para que 5.1 lea bien los acentos: si los editas, conserva esa codificación.

## Qué guarda y qué no

Cada respaldo es un archivo `gravity_respaldo_AAAAMMDD_HHMMSS.7z` (o `.zip.gpg`) con:

| Contenido | Para qué |
|---|---|
| `datos.sql` | Datos de todas las tablas de `public` más `auth.users` y `auth.identities` (cuentas, con contraseñas en hash). Sin las tablas que llenan las migraciones (`permisos_rol`) |
| `esquema_public.sql` | El esquema de `public`, solo de referencia: la verdad son las migraciones de `supabase/migrations` |
| `manifiesto.json` | Fecha, equipo, versiones, migraciones aplicadas, filas por tabla y SHA-256 de los archivos |
| `LEEME.txt` | Recordatorio de cómo restaurar |

**No guarda:** los archivos de Supabase Storage (la Fase 0 no los usa; hay que agregarlos cuando se usen), los secretos de las funciones de servidor, la configuración del proyecto (proveedores de acceso, plantillas de correo) ni las sesiones abiertas (al restaurar, cada quien vuelve a entrar).

## 1. Preparar la laptop (una sola vez)

1. **Herramientas de PostgreSQL**, de la **misma versión mayor que el servidor de Supabase o más nueva** (en Supabase: *Project Settings › Infrastructure*; los proyectos nuevos usan PostgreSQL 17). Del instalador de PostgreSQL para Windows basta con *Command Line Tools*. El script busca `pg_dump.exe` y `psql.exe` en el PATH y en `C:\Program Files\PostgreSQL\<versión>\bin`; si están en otro lado, usa `-PgBin`. Si `pg_dump` es más viejo que el servidor, el script se detiene y lo dice.
2. **7-Zip**: `winget install 7zip.7zip`. Alternativa sin 7-Zip: **Gpg4win** (`winget install GnuPG.Gpg4win`) y `-Cifrador gpg`, que guarda un ZIP cifrado con GnuPG (AES-256) como `.zip.gpg`.
3. **Variables de entorno del usuario** (nunca en los scripts ni en el repositorio):

| Variable | Valor |
|---|---|
| `GRAVITY_DB_URL` | Cadena de conexión de Supabase: *Connect › Session pooler* (funciona con IPv4), usuario `postgres`. Formato `postgresql://postgres.<ref>:<contraseña>@<host>:5432/postgres` |
| `GRAVITY_RESPALDO_CLAVE` | Clave para cifrar: al menos 12 caracteres (mejor una frase larga), sin comillas dobles. **Guárdala en tu gestor de contraseñas: sin ella los respaldos no se pueden abrir** |
| `GRAVITY_RESPALDO_DESTINO2` | Segunda ubicación, p. ej. `E:\RespaldosGRAVITY` (disco externo) |

   La forma más simple es la ventana de Windows: *Inicio › "Editar las variables de entorno de esta cuenta" › Nueva*. Si prefieres PowerShell, usa `Read-Host` para que el secreto no quede en el historial:

   ```powershell
   $s = Read-Host 'Cadena de conexión de Supabase' -AsSecureString
   [Environment]::SetEnvironmentVariable('GRAVITY_DB_URL',
     [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)), 'User')
   $s = Read-Host 'Clave de los respaldos' -AsSecureString
   [Environment]::SetEnvironmentVariable('GRAVITY_RESPALDO_CLAVE',
     [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)), 'User')
   [Environment]::SetEnvironmentVariable('GRAVITY_RESPALDO_DESTINO2', 'E:\RespaldosGRAVITY', 'User')
   ```

   Cierra y vuelve a abrir PowerShell para que las vea. *Alternativa:* deja la contraseña de la base en `%APPDATA%\postgresql\pgpass.conf` y pon la URL **sin** contraseña en `GRAVITY_DB_URL`.

4. **Prueba manual:**

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\ruta\a\GRAVITY\herramientas\respaldo\respaldo_diario.ps1
   ```

   Por defecto guarda en `%USERPROFILE%\Respaldos\GRAVITY` (fuera del repositorio y de OneDrive). Opciones: `-Destino`, `-DestinoSecundario`, `-DiasRetencion` (30), `-MinimoConservar` (7), `-Cifrador 7zip|gpg`, `-PgBin`. Ayuda completa: `Get-Help .\respaldo_diario.ps1 -Full`.

## 2. Programarlo en el Programador de tareas

Con PowerShell (una sola vez; ajusta la ruta y la hora):

```powershell
$script = 'C:\ruta\a\GRAVITY\herramientas\respaldo\respaldo_diario.ps1'
$accion = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$cuando = New-ScheduledTaskTrigger -Daily -At 21:00
$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName 'GRAVITY - respaldo diario' -Action $accion -Trigger $cuando `
  -Settings $ajustes -Description 'Respaldo cifrado de la base de GRAVITY (Supabase)'
```

O con la ventana (*Programador de tareas › Crear tarea*):

1. **General:** nombre "GRAVITY - respaldo diario"; *Ejecutar solo cuando el usuario haya iniciado sesión* (así ve las variables de entorno de tu cuenta).
2. **Desencadenadores:** *Diariamente*, a una hora en que la laptop suela estar encendida.
3. **Acciones:** *Iniciar un programa* → `powershell.exe`, argumentos `-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\ruta\a\GRAVITY\herramientas\respaldo\respaldo_diario.ps1"`.
4. **Condiciones:** quita *Iniciar la tarea solo si el equipo está conectado a la corriente alterna*.
5. **Configuración:** marca *Ejecutar la tarea lo antes posible si no se ejecutó a la hora programada* (si la laptop estaba apagada, se respalda al encenderla) y *Detener la tarea si se ejecuta durante más de 1 hora*.

**Cómo saber si funcionó:** en el Programador de tareas, *Resultado de la última ejecución*, y en `respaldo.log` dentro de la carpeta local.

| Código | Significado |
|---|---|
| 0 (`0x0`) | Respaldo hecho en las dos ubicaciones |
| 2 (`0x2`) | Respaldo local hecho, pero la segunda ubicación falló o no está configurada (¿disco externo desconectado?) |
| 1 (`0x1`) | No se hizo respaldo: revisa `respaldo.log` |

La retención borra las copias de más de `-DiasRetencion` días en cada ubicación, pero **siempre conserva las `-MinimoConservar` más recientes**, aunque la laptop pase semanas sin respaldar. Solo toca archivos `gravity_respaldo_*`.

## 3. Restaurar

`restaurar.ps1` solo carga en una base **vacía** que ya tiene el esquema (las migraciones aplicadas); se niega si encuentra hogares, personas o cuentas. Carga todo en **una transacción** con `session_replication_role = replica` (sin triggers: la bitácora conserva sus fechas y no se duplican personas) y al final compara las filas de cada tabla con el manifiesto. La base destino se indica en `GRAVITY_DB_URL_DESTINO`, distinta de la del respaldo diario a propósito.

**Simulacro (recomendado cada mes), en Supabase local** (requiere Docker y la CLI de Supabase):

```powershell
supabase start
supabase db reset --no-seed        # migraciones sin datos de ejemplo (o [db.seed] enabled = false en config.toml)
$env:GRAVITY_DB_URL_DESTINO = 'postgresql://postgres:postgres@127.0.0.1:54322/postgres'
.\restaurar.ps1 -Archivo "$env:USERPROFILE\Respaldos\GRAVITY\gravity_respaldo_20261020_210000.7z"
```

**Desastre (se perdió o dañó el proyecto):**

1. Crea un proyecto nuevo de Supabase en la misma región.
2. Aplica las migraciones: `supabase link --project-ref <nuevo>` y `supabase db push` (ver `supabase/README.md`). **No** apliques `seed.sql`.
3. Pon en `GRAVITY_DB_URL_DESTINO` la cadena del proyecto nuevo (*Session pooler*) y corre `restaurar.ps1 -Archivo <el más reciente>`.
4. Rehaz la configuración que no está en el respaldo: ajustes de Auth (URL del sitio, plantillas, confirmación de correo **activa**), secretos de las funciones de servidor; cambia la URL y la llave pública de la app, y `GRAVITY_DB_URL` para los respaldos siguientes.

**Solo revisar el contenido:** `.\restaurar.ps1 -Archivo <archivo> -SoloExtraer -CarpetaExtraccion C:\temp\revisar` deja los archivos **sin cifrar**: bórralos al terminar.

Si al restaurar aparece *permission denied to set parameter "session_replication_role"*, conéctate con un usuario que pueda cambiarlo (en Supabase, `postgres`; en Supabase local también puedes usar `supabase_admin`).

## 4. Seguridad

- Las cadenas de conexión y la clave **solo** viven en variables de entorno de tu cuenta de Windows. El registro (`respaldo.log`) las oculta.
- La contraseña de la base se pasa a `pg_dump` y `psql` por `PGPASSWORD`, no en la línea de comandos. La clave de 7-Zip sí va en la línea de comandos de `7z.exe` mientras corre (es una limitación de 7-Zip); con `-Cifrador gpg` va por la entrada estándar.
- Los datos sin cifrar solo existen en la carpeta temporal mientras corre el script y se borran al terminar, aunque falle.
- Los respaldos contienen datos personales y de dinero: mantén BitLocker activo en la laptop, guarda el disco externo en otro lugar y **nunca** los copies al repositorio.
- Si pierdes la clave, los respaldos cifrados con ella no se pueden recuperar. Si la cambias, guarda también la anterior mientras existan copias hechas con ella.

## 5. Prueba en Linux

```bash
herramientas/respaldo/probar_respaldo.sh          # con pwsh: corre los .ps1 reales
herramientas/respaldo/probar_respaldo.sh --bash   # réplica en bash del flujo básico
```

Levanta un Postgres desechable (ver `supabase/README.md`), crea una base con las migraciones y el seed, respalda con `respaldo_diario.ps1`, restaura con `restaurar.ps1` en una base nueva y compara tabla por tabla (filas y huella MD5). También prueba retención, segunda ubicación caída, falta de clave, base inaccesible, clave equivocada, destino con datos, destino sin esquema y la alternativa con GnuPG. Requiere PostgreSQL, `7z`, `pwsh` (PowerShell 7) y `gpg`.

## Mantenimiento

Cuando una migración llene una tabla de catálogo (como `permisos_rol`), agrégala a `$script:TablasDeMigracion` en `respaldo_comun.ps1`; si no, la restauración chocará con las filas que ya puso la migración.
