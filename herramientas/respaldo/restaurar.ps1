<#
.SYNOPSIS
    Restaura un respaldo cifrado de GRAVITY en una base de datos VACÍA.

.DESCRIPTION
    1. Descifra el archivo (.7z con 7-Zip o .zip.gpg con GnuPG) con la clave de
       GRAVITY_RESPALDO_CLAVE en una carpeta temporal y comprueba su SHA-256.
    2. Comprueba la base destino (variable GRAVITY_DB_URL_DESTINO, distinta de la
       del respaldo diario a propósito): debe tener ya el esquema (migraciones
       aplicadas) y estar vacía (sin hogares, personas ni cuentas).
    3. Carga los datos en UNA transacción con session_replication_role = replica
       (sin triggers: la bitácora conserva sus fechas y no se duplican personas).
    4. Compara las filas de cada tabla con el manifiesto.
    Los datos sin cifrar se borran al terminar (salvo con -SoloExtraer), y al
    empezar se borran los que haya dejado una corrida interrumpida (más de 6 horas).

    Antes de restaurar en un proyecto NUEVO de Supabase: aplica las migraciones
    (supabase db push) y NO apliques seed.sql. En Supabase local: supabase db reset
    sin seed (o bórralo antes), ver README.

.PARAMETER Archivo
    gravity_respaldo_AAAAMMDD_HHMMSS.7z o .zip.gpg.
.PARAMETER Confirmar
    No pregunta antes de escribir en la base destino.
.PARAMETER SoloExtraer
    Solo descifra en -CarpetaExtraccion para revisar el contenido (queda SIN cifrar: bórralo al terminar).

.EXAMPLE
    $env:GRAVITY_DB_URL_DESTINO = 'postgresql://postgres:postgres@127.0.0.1:54322/postgres'
    .\restaurar.ps1 -Archivo "$env:USERPROFILE\Respaldos\GRAVITY\gravity_respaldo_20261020_210000.7z"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Archivo,
    [switch]$Confirmar,
    [switch]$SoloExtraer,
    [string]$CarpetaExtraccion,
    [string]$PgBin,
    [string]$SieteZip,
    [string]$Gpg,
    [string]$VariableConexion = 'GRAVITY_DB_URL_DESTINO',
    [string]$VariableClave = 'GRAVITY_RESPALDO_CLAVE'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'respaldo_comun.ps1')

$codigoSalida = 0
$temporal = $null
try {
    if (-not (Test-Path -LiteralPath $Archivo)) { throw "No existe el archivo $Archivo" }
    $Archivo = (Resolve-Path -LiteralPath $Archivo).Path
    $clave = Get-Secreto -Variable $VariableClave -Descripcion 'clave con la que se cifró el respaldo'
    Remove-TemporalesHuerfanos

    # 1. Descifrar y extraer.
    $temporal = New-CarpetaTemporal -Prefijo 'gravity_restaurar'
    if ($Archivo -like '*.7z') {
        $sieteZip = Find-SieteZip -Ruta $SieteZip
        Invoke-Nativo -Programa $sieteZip -Argumentos @('x', "-p$clave", "-o$temporal", '-y', '-bso0', '-bsp0',
            '--', $Archivo) | Out-Null
    } elseif ($Archivo -like '*.zip.gpg') {
        $gpgExe = Find-Gpg -Ruta $Gpg
        $zip = Join-Path $temporal 'respaldo.zip'
        Invoke-Nativo -Programa $gpgExe -Entrada $clave -Argumentos @('--batch', '--yes', '--pinentry-mode',
            'loopback', '--passphrase-fd', '0', '--decrypt', '--output', $zip, $Archivo) | Out-Null
        Expand-Archive -LiteralPath $zip -DestinationPath $temporal -Force
        Remove-Item -LiteralPath $zip -Force
    } else {
        throw 'El archivo debe terminar en .7z o .zip.gpg'
    }
    $manifiestoArchivo = Get-ChildItem -LiteralPath $temporal -Recurse -Filter 'manifiesto.json' | Select-Object -First 1
    if (-not $manifiestoArchivo) { throw 'El respaldo no tiene manifiesto.json' }
    $carpeta = $manifiestoArchivo.DirectoryName
    $manifiesto = [System.IO.File]::ReadAllText($manifiestoArchivo.FullName) | ConvertFrom-Json
    $datos = Join-Path $carpeta 'datos.sql'
    if ((Get-Sha256 $datos) -ne $manifiesto.sha256.'datos.sql') { throw 'datos.sql no coincide con el SHA-256 del manifiesto.' }
    $creado = $manifiesto.creado_en
    if ($creado -is [datetime]) { $creado = $creado.ToString('yyyy-MM-dd HH:mm:ss') }
    Write-Bitacora ("Respaldo descifrado y verificado: creado {0} en {1}." -f $creado, $manifiesto.equipo)

    if ($SoloExtraer) {
        if (-not $CarpetaExtraccion) { throw 'Indica -CarpetaExtraccion para usar -SoloExtraer.' }
        New-Item -ItemType Directory -Path $CarpetaExtraccion -Force | Out-Null
        $salida = Join-Path $CarpetaExtraccion (Split-Path -Leaf $carpeta)
        Move-Item -LiteralPath $carpeta -Destination $salida
        Write-Bitacora "Extraído SIN CIFRAR en $salida. Contiene datos personales: bórralo al terminar." 'AVISO'
        return
    }

    # 2. Revisar la base destino.
    $url = Get-Secreto -Variable $VariableConexion -Descripcion 'cadena de conexión de la base DESTINO'
    $urlSinClave = Split-ClaveDeUrl $url
    $pg = Find-HerramientasPostgres -PgBin $PgBin
    $numServidor = [int]((Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql 'show server_version_num') | Select-Object -First 1)

    $tieneEsquema = Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql "select to_regclass('public.hogares') is not null and to_regclass('auth.users') is not null"
    if (($tieneEsquema | Select-Object -First 1) -ne 't') {
        throw 'La base destino no tiene el esquema de GRAVITY. Aplica primero las migraciones (supabase db push).'
    }
    $ocupadas = [int]((Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql 'select (select count(*) from public.hogares) + (select count(*) from public.personas) + (select count(*) from auth.users)') | Select-Object -First 1)
    if ($ocupadas -gt 0) {
        throw 'La base destino no está vacía (tiene hogares, personas o cuentas). Solo se restaura en una base nueva.'
    }
    if ($manifiesto.migraciones) {
        $hay = Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql "select to_regclass('supabase_migrations.schema_migrations') is not null"
        if (($hay | Select-Object -First 1) -eq 't') {
            $destinoMig = @(Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql 'select version from supabase_migrations.schema_migrations order by version')
            if ((@($manifiesto.migraciones) -join ',') -ne ($destinoMig -join ',')) {
                Write-Bitacora ('Las migraciones del destino ({0}) no son las del respaldo ({1}). Aplica las mismas antes de restaurar.' -f
                    ($destinoMig -join ', '), (@($manifiesto.migraciones) -join ', ')) 'AVISO'
            }
        }
    }

    if (-not $Confirmar) {
        $respuesta = Read-Host 'Se cargarán los datos del respaldo en la base destino. Escribe RESTAURAR para continuar'
        if ($respuesta -cne 'RESTAURAR') { throw 'Cancelado por el usuario.' }
    }

    # pg_dump 17 escribe SET transaction_timeout, que no existe antes de PostgreSQL 17.
    $archivoCarga = $datos
    if ($numServidor -lt 170000) {
        $archivoCarga = Join-Path $carpeta 'datos_carga.sql'
        $escritor = New-Object System.IO.StreamWriter($archivoCarga, $false, (New-Object System.Text.UTF8Encoding $false))
        try {
            foreach ($linea in [System.IO.File]::ReadLines($datos)) {
                if ($linea -notmatch '^SET transaction_timeout = ') { $escritor.WriteLine($linea) }
            }
        } finally { $escritor.Close() }
    }

    # 3. Cargar en una sola transacción, sin triggers.
    Invoke-Nativo -Programa $pg.Psql -Argumentos @('-X', '-q', '-v', 'ON_ERROR_STOP=1', '--single-transaction',
        "--dbname=$urlSinClave", '-c', 'SET session_replication_role = replica', '-f', $archivoCarga) | Out-Null
    Write-Bitacora 'Datos cargados.'

    # 4. Verificar filas contra el manifiesto.
    $diferencias = 0
    foreach ($p in $manifiesto.filas.PSObject.Properties) {
        $n = [int]((Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql "select count(*) from $($p.Name)") | Select-Object -First 1)
        if ($n -ne [int]$p.Value) {
            Write-Bitacora ("{0}: {1} filas (el respaldo tiene {2})" -f $p.Name, $n, $p.Value) 'ERROR'
            $diferencias++
        } else {
            Write-Bitacora ("{0}: {1} filas" -f $p.Name, $n)
        }
    }
    if ($diferencias -gt 0) { throw "$diferencias tablas no coinciden con el respaldo." }
    Write-Bitacora 'Restauración completa y verificada.'
} catch {
    Write-Bitacora "Restauración FALLIDA: $($_.Exception.Message)" 'ERROR'
    $codigoSalida = 1
} finally {
    Remove-CarpetaSegura $temporal
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
exit $codigoSalida
