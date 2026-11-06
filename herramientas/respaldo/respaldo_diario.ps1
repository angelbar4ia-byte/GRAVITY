<#
.SYNOPSIS
    Respaldo diario de la base de datos de GRAVITY (Supabase) desde la laptop.

.DESCRIPTION
    1. Lee la cadena de conexión de una variable de entorno (GRAVITY_DB_URL); nunca
       va escrita en este archivo. La contraseña se pasa a pg_dump por PGPASSWORD.
    2. Vuelca con pg_dump:
         esquema_public.sql  esquema de public (referencia; la verdad son las migraciones)
         datos.sql           datos de public (menos tablas de migración) + auth.users + auth.identities
    3. Escribe manifiesto.json: fecha, versiones, migraciones aplicadas, filas por tabla y SHA-256.
    4. Comprime y cifra con AES-256: 7-Zip (.7z con nombres cifrados) o, como
       alternativa, ZIP + GnuPG (.zip.gpg). Clave en GRAVITY_RESPALDO_CLAVE.
    5. Comprueba que el archivo se puede abrir con la clave.
    6. Lo guarda en la carpeta local y lo copia a la segunda ubicación (disco externo).
    7. Borra copias de más de -DiasRetencion días, conservando siempre las -MinimoConservar más recientes.
    8. Deja registro en respaldo.log (sin secretos). Los datos sin cifrar se borran al terminar,
       y al empezar se borran los que haya dejado una corrida interrumpida (más de 6 horas).

    Códigos de salida: 0 = todo bien; 1 = error (no hay respaldo nuevo);
    2 = respaldo local bien, pero la segunda ubicación falló o no está configurada.

.PARAMETER Destino
    Carpeta local de respaldos. Por defecto %USERPROFILE%\Respaldos\GRAVITY.
.PARAMETER DestinoSecundario
    Segunda ubicación (p. ej. E:\RespaldosGRAVITY). Por defecto la variable GRAVITY_RESPALDO_DESTINO2.
.PARAMETER DiasRetencion
    Días que se conservan las copias (por defecto 30).
.PARAMETER MinimoConservar
    Copias más recientes que nunca se borran, aunque sean viejas (por defecto 7).
.PARAMETER Cifrador
    7zip (por defecto) o gpg.
.PARAMETER PgBin
    Carpeta con pg_dump.exe y psql.exe si no están en el PATH ni en C:\Program Files\PostgreSQL.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\respaldo_diario.ps1
.EXAMPLE
    .\respaldo_diario.ps1 -DestinoSecundario 'E:\RespaldosGRAVITY' -DiasRetencion 60
#>
[CmdletBinding()]
param(
    [string]$Destino,
    [string]$DestinoSecundario = $env:GRAVITY_RESPALDO_DESTINO2,
    [ValidateRange(1, 3650)][int]$DiasRetencion = 30,
    [ValidateRange(1, 365)][int]$MinimoConservar = 7,
    [ValidateSet('7zip', 'gpg')][string]$Cifrador = '7zip',
    [string]$PgBin,
    [string]$SieteZip,
    [string]$Gpg,
    [string]$VariableConexion = 'GRAVITY_DB_URL',
    [string]$VariableClave = 'GRAVITY_RESPALDO_CLAVE'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'respaldo_comun.ps1')

if (-not $Destino) {
    $base = $env:USERPROFILE
    if (-not $base) { $base = $HOME }
    $Destino = Join-Path (Join-Path $base 'Respaldos') 'GRAVITY'
}

function Remove-RespaldosAntiguos {
    param([string]$Carpeta, [int]$Dias, [int]$Minimo)
    $limite = (Get-Date).AddDays(-$Dias)
    $cultura = [System.Globalization.CultureInfo]::InvariantCulture
    $copias = @(Get-ChildItem -LiteralPath $Carpeta -File -ErrorAction SilentlyContinue | ForEach-Object {
            $m = [regex]::Match($_.Name, '^gravity_respaldo_(\d{8}_\d{6})\.(7z|zip\.gpg)$')
            if ($m.Success) {
                [pscustomobject]@{
                    Archivo = $_
                    Fecha   = [datetime]::ParseExact($m.Groups[1].Value, 'yyyyMMdd_HHmmss', $cultura)
                }
            }
        } | Sort-Object Fecha -Descending)
    $borradas = 0
    foreach ($c in @($copias | Select-Object -Skip $Minimo)) {
        if ($c.Fecha -lt $limite) {
            Remove-Item -LiteralPath $c.Archivo.FullName -Force
            Write-Bitacora "Borrada copia antigua: $($c.Archivo.FullName)"
            $borradas++
        }
    }
    Write-Bitacora ("{0}: {1} copias, {2} borradas por antigüedad (más de {3} días; se conservan al menos {4})." -f
        $Carpeta, $copias.Count, $borradas, $Dias, $Minimo)
}

$codigoSalida = 0
$temporal = $null
try {
    New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    $script:ArchivoLog = Join-Path $Destino 'respaldo.log'
    Write-Bitacora '=== Inicio del respaldo de GRAVITY ==='
    Remove-TemporalesHuerfanos

    # Secretos y herramientas.
    $url = Get-Secreto -Variable $VariableConexion -Descripcion 'cadena de conexión de Supabase'
    $clave = Get-Secreto -Variable $VariableClave -Descripcion 'clave para cifrar los respaldos'
    if ($clave.Length -lt 12) { throw "La clave de $VariableClave debe tener al menos 12 caracteres." }
    if ($clave.Contains('"')) { throw "La clave de $VariableClave no debe llevar comillas dobles (""): PowerShell 5.1 no las pasa bien a 7-Zip." }
    $urlSinClave = Split-ClaveDeUrl $url
    $pg = Find-HerramientasPostgres -PgBin $PgBin
    if ($Cifrador -eq '7zip') { $herramientaCifrado = Find-SieteZip -Ruta $SieteZip }
    else { $herramientaCifrado = Find-Gpg -Ruta $Gpg }

    # pg_dump debe ser de la misma versión mayor que el servidor, o más nueva.
    $versionDump = ((Invoke-Nativo -Programa $pg.PgDump -Argumentos @('--version')).Salida -join ' ')
    $mayorDump = Get-VersionMayor ($versionDump -replace '^[^0-9]*', '')
    $numServidor = [int]((Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql 'show server_version_num') | Select-Object -First 1)
    $mayorServidor = [int][math]::Floor($numServidor / 10000)
    if ($mayorDump -lt $mayorServidor) {
        throw "pg_dump $mayorDump es más viejo que el servidor (PostgreSQL $mayorServidor). Instala las herramientas de PostgreSQL $mayorServidor."
    }
    Write-Bitacora "Servidor PostgreSQL $mayorServidor; $versionDump; cifrado: $Cifrador."

    # Volcado en una carpeta temporal (se borra siempre al terminar).
    $marca = Get-Date -Format 'yyyyMMdd_HHmmss'
    $nombre = "gravity_respaldo_$marca"
    $temporal = New-CarpetaTemporal -Prefijo 'gravity_respaldo'
    $carpeta = Join-Path $temporal $nombre
    New-Item -ItemType Directory -Path $carpeta | Out-Null
    $esquema = Join-Path $carpeta 'esquema_public.sql'
    $datos = Join-Path $carpeta 'datos.sql'

    $comunes = @('--no-owner', '--no-privileges', "--dbname=$urlSinClave")
    Invoke-Nativo -Programa $pg.PgDump -Argumentos ($comunes + @('--schema-only', '--schema=public', "--file=$esquema")) | Out-Null
    $argsDatos = $comunes + @('--data-only', '--table=public.*', '--table=auth.users', '--table=auth.identities', "--file=$datos")
    foreach ($t in $script:TablasDeMigracion) { $argsDatos += "--exclude-table-data=$t" }
    Invoke-Nativo -Programa $pg.PgDump -Argumentos $argsDatos | Out-Null

    # Migraciones aplicadas (si se usó la CLI de Supabase).
    $migraciones = $null
    $hayTabla = Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql "select to_regclass('supabase_migrations.schema_migrations') is not null"
    if (($hayTabla | Select-Object -First 1) -eq 't') {
        $migraciones = @(Invoke-Consulta -Psql $pg.Psql -Url $urlSinClave -Sql 'select version from supabase_migrations.schema_migrations order by version')
    }

    $filas = Measure-FilasVolcado -Ruta $datos
    $totalFilas = 0
    foreach ($v in $filas.Values) { $totalFilas += $v }
    $manifiesto = [ordered]@{
        formato               = 1
        proyecto              = 'GRAVITY'
        creado_en             = (Get-Date).ToString('o')
        equipo                = [Environment]::MachineName
        servidor_version      = $numServidor
        pg_dump_version       = $versionDump
        migraciones           = $migraciones
        tablas_de_migracion   = $script:TablasDeMigracion
        filas                 = $filas
        sha256                = [ordered]@{
            'datos.sql'          = (Get-Sha256 $datos)
            'esquema_public.sql' = (Get-Sha256 $esquema)
        }
    }
    Write-TextoUtf8 -Ruta (Join-Path $carpeta 'manifiesto.json') -Texto ($manifiesto | ConvertTo-Json -Depth 5)
    Write-TextoUtf8 -Ruta (Join-Path $carpeta 'LEEME.txt') -Texto (
        "Respaldo de GRAVITY del $marca. Para restaurar: herramientas/respaldo/restaurar.ps1 " +
        "(ver herramientas/respaldo/README.md). Contiene datos personales y de dinero: no lo compartas.")
    Write-Bitacora ("Volcado listo: {0} tablas, {1} filas." -f $filas.Count, $totalFilas)

    # Comprimir y cifrar (AES-256) dentro de la carpeta temporal; verificar.
    if ($Cifrador -eq '7zip') {
        $archivoTemporal = Join-Path $temporal "$nombre.7z"
        Invoke-Nativo -Programa $herramientaCifrado -Argumentos @('a', '-t7z', '-mx=9', '-mhe=on',
            "-p$clave", '-bso0', '-bsp0', '--', $archivoTemporal, $carpeta) | Out-Null
        Invoke-Nativo -Programa $herramientaCifrado -Argumentos @('t', "-p$clave", '-bso0', '-bsp0', '--',
            $archivoTemporal) | Out-Null
    } else {
        $zip = Join-Path $temporal "$nombre.zip"
        Compress-Archive -Path $carpeta -DestinationPath $zip -CompressionLevel Optimal
        $archivoTemporal = "$zip.gpg"
        Invoke-Nativo -Programa $herramientaCifrado -Entrada $clave -Argumentos @('--batch', '--yes',
            '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--symmetric', '--cipher-algo', 'AES256',
            '--s2k-digest-algo', 'SHA512', '--s2k-count', '65011712', '--output', $archivoTemporal, $zip) | Out-Null
        $prueba = Join-Path $temporal 'verificacion.zip'
        Invoke-Nativo -Programa $herramientaCifrado -Entrada $clave -Argumentos @('--batch', '--yes',
            '--pinentry-mode', 'loopback', '--passphrase-fd', '0', '--decrypt', '--output', $prueba,
            $archivoTemporal) | Out-Null
        if ((Get-Sha256 $prueba) -ne (Get-Sha256 $zip)) { throw 'La verificación del archivo cifrado con gpg falló.' }
    }
    Write-Bitacora 'Archivo cifrado (AES-256) y verificado con la clave.'

    $archivoFinal = Join-Path $Destino (Split-Path -Leaf $archivoTemporal)
    Move-Item -LiteralPath $archivoTemporal -Destination $archivoFinal
    $hashFinal = Get-Sha256 $archivoFinal
    $tamanoMb = [math]::Round((Get-Item -LiteralPath $archivoFinal).Length / 1MB, 2)
    Write-Bitacora "Respaldo local: $archivoFinal ($tamanoMb MB)."
    Remove-RespaldosAntiguos -Carpeta $Destino -Dias $DiasRetencion -Minimo $MinimoConservar

    # Segunda ubicación (fuera de la laptop, p. ej. disco externo).
    if (-not $DestinoSecundario) {
        Write-Bitacora 'No hay segunda ubicación (GRAVITY_RESPALDO_DESTINO2 o -DestinoSecundario). D7 pide una copia fuera de la laptop.' 'AVISO'
        $codigoSalida = 2
    } else {
        try {
            if (-not (Test-Path -LiteralPath $DestinoSecundario)) {
                $raiz = [System.IO.Path]::GetPathRoot($DestinoSecundario)
                if (-not $raiz -or -not (Test-Path -LiteralPath $raiz)) {
                    throw "La segunda ubicación $DestinoSecundario no está disponible (¿disco externo conectado?)."
                }
                New-Item -ItemType Directory -Path $DestinoSecundario -Force | Out-Null
            }
            $copia = Join-Path $DestinoSecundario (Split-Path -Leaf $archivoFinal)
            Copy-Item -LiteralPath $archivoFinal -Destination $copia -Force
            if ((Get-Sha256 $copia) -ne $hashFinal) { throw "La copia en $copia no coincide con el original." }
            Write-Bitacora "Copia en la segunda ubicación: $copia"
            Remove-RespaldosAntiguos -Carpeta $DestinoSecundario -Dias $DiasRetencion -Minimo $MinimoConservar
        } catch {
            Write-Bitacora "Segunda ubicación: $($_.Exception.Message)" 'AVISO'
            $codigoSalida = 2
        }
    }
    Write-Bitacora ("=== Respaldo terminado (código {0}) ===" -f $codigoSalida)
} catch {
    Write-Bitacora "Respaldo FALLIDO: $($_.Exception.Message)" 'ERROR'
    $codigoSalida = 1
} finally {
    Remove-CarpetaSegura $temporal
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
exit $codigoSalida
