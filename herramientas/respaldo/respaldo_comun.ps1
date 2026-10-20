# GRAVITY - funciones comunes de respaldo_diario.ps1 y restaurar.ps1.
# Se carga con: . (Join-Path $PSScriptRoot 'respaldo_comun.ps1')
# Compatible con Windows PowerShell 5.1 y PowerShell 7 (Windows y Linux).
# Guardado como UTF-8 con BOM para que PowerShell 5.1 lea bien los acentos.

Set-StrictMode -Version 2.0

# Texto hacia programas externos (stdin) en UTF-8 (en 5.1 es ASCII por defecto).
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

# Tablas que llenan las migraciones (no son datos del usuario): no se respaldan
# sus filas, porque la base destino ya las tiene al aplicar las migraciones.
$script:TablasDeMigracion = @('public.permisos_rol')

$script:Secretos = New-Object System.Collections.Generic.List[string]
$script:ArchivoLog = $null

function Get-EsWindows {
    if (Test-Path variable:IsWindows) { return [bool]$IsWindows }
    return $true  # Windows PowerShell 5.1 solo corre en Windows
}

function Add-Secreto {
    param([string]$Valor)
    if ($Valor -and $Valor.Length -ge 4) { $script:Secretos.Add($Valor) }
}

function Hide-Secretos {
    param([string]$Texto)
    if ($null -eq $Texto) { return $Texto }
    foreach ($s in $script:Secretos) { $Texto = $Texto.Replace($s, '***') }
    return $Texto
}

function Write-Bitacora {
    param([string]$Mensaje, [ValidateSet('INFO', 'AVISO', 'ERROR')][string]$Nivel = 'INFO')
    $linea = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Nivel, (Hide-Secretos $Mensaje)
    if ($Nivel -eq 'ERROR') { Write-Host $linea -ForegroundColor Red }
    elseif ($Nivel -eq 'AVISO') { Write-Host $linea -ForegroundColor Yellow }
    else { Write-Host $linea }
    if ($script:ArchivoLog) {
        try { Add-Content -LiteralPath $script:ArchivoLog -Value $linea -Encoding UTF8 }
        catch { Write-Verbose "No pude escribir en $($script:ArchivoLog): $($_.Exception.Message)" }
    }
}

# Corre un programa externo; devuelve Codigo, Salida (stdout) y Todo (stdout+stderr).
# Lanza error si el código de salida no es 0 (salvo -PermitirFallo).
function Invoke-Nativo {
    param(
        [Parameter(Mandatory = $true)][string]$Programa,
        [string[]]$Argumentos = @(),
        [string]$Entrada,
        [switch]$PermitirFallo
    )
    $preferencia = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($PSBoundParameters.ContainsKey('Entrada')) {
            $resultado = $Entrada | & $Programa @Argumentos 2>&1
        } else {
            $resultado = & $Programa @Argumentos 2>&1
        }
        $codigo = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $preferencia
    }
    $todo = @($resultado | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" }
        } | Where-Object { $_ -and $_.Trim() })
    $salida = @($resultado | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
        ForEach-Object { "$_" })
    if ($codigo -ne 0 -and -not $PermitirFallo) {
        $detalle = ($todo | Select-Object -Last 12) -join ' | '
        throw (Hide-Secretos ('{0} terminó con código {1}: {2}' -f
                (Split-Path -Leaf $Programa), $codigo, $detalle))
    }
    return [pscustomobject]@{ Codigo = $codigo; Salida = $salida; Todo = $todo }
}

# Busca un programa: ruta explícita, PATH o carpetas típicas de Windows.
function Find-Programa {
    param([string]$Nombre, [string]$Carpeta, [string[]]$Patrones = @())
    $exe = $Nombre
    if (Get-EsWindows) { $exe = "$Nombre.exe" }
    if ($Carpeta) {
        $ruta = Join-Path $Carpeta $exe
        if (Test-Path -LiteralPath $ruta) { return $ruta }
        throw "No encontré $exe en $Carpeta"
    }
    $cmd = Get-Command $Nombre -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Path }
    foreach ($patron in $Patrones) {
        if (-not $patron) { continue }
        $hallado = Get-ChildItem -Path $patron -ErrorAction SilentlyContinue |
            Sort-Object { [int](($_.Directory.Parent.Name -replace '[^0-9].*$', '') + '0') } -Descending |
            Select-Object -First 1
        if ($hallado) { return $hallado.FullName }
    }
    return $null
}

function Find-HerramientasPostgres {
    param([string]$PgBin)
    $patronesDump = @()
    $patronesPsql = @()
    if ($env:ProgramFiles) {
        $patronesDump += (Join-Path $env:ProgramFiles 'PostgreSQL\*\bin\pg_dump.exe')
        $patronesPsql += (Join-Path $env:ProgramFiles 'PostgreSQL\*\bin\psql.exe')
    }
    $pgDump = Find-Programa -Nombre 'pg_dump' -Carpeta $PgBin -Patrones $patronesDump
    $psql = Find-Programa -Nombre 'psql' -Carpeta $PgBin -Patrones $patronesPsql
    if (-not $pgDump -or -not $psql) {
        throw ('No encontré pg_dump y psql. Instala las herramientas de línea de comandos de ' +
               'PostgreSQL (misma versión mayor que el servidor de Supabase o más nueva) o usa -PgBin.')
    }
    return [pscustomobject]@{ PgDump = $pgDump; Psql = $psql }
}

function Find-SieteZip {
    param([string]$Ruta)
    if ($Ruta) { if (Test-Path -LiteralPath $Ruta) { return $Ruta }; throw "No existe $Ruta" }
    $patrones = @()
    if ($env:ProgramFiles) { $patrones += (Join-Path $env:ProgramFiles '7-Zip\7z.exe') }
    if (${env:ProgramFiles(x86)}) { $patrones += (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe') }
    foreach ($nombre in @('7z', '7zz', '7za')) {
        $cmd = Get-Command $nombre -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { return $cmd.Path }
    }
    foreach ($p in $patrones) { if (Test-Path -LiteralPath $p) { return $p } }
    throw 'No encontré 7-Zip. Instálalo (winget install 7zip.7zip) o usa -Cifrador gpg.'
}

function Find-Gpg {
    param([string]$Ruta)
    if ($Ruta) { if (Test-Path -LiteralPath $Ruta) { return $Ruta }; throw "No existe $Ruta" }
    $cmd = Get-Command 'gpg' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Path }
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not $base) { continue }
        $p = Join-Path $base 'GnuPG\bin\gpg.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    throw 'No encontré gpg. Instala Gpg4win (winget install GnuPG.Gpg4win) o usa -Cifrador 7zip.'
}

# Lee un secreto de una variable de entorno (proceso, usuario o máquina).
function Get-Secreto {
    param([string]$Variable, [string]$Descripcion)
    $valor = [Environment]::GetEnvironmentVariable($Variable)
    if (-not $valor -and (Get-EsWindows)) {
        $valor = [Environment]::GetEnvironmentVariable($Variable, 'User')
        if (-not $valor) { $valor = [Environment]::GetEnvironmentVariable($Variable, 'Machine') }
    }
    if (-not $valor) {
        throw "Falta la variable de entorno $Variable ($Descripcion). Ver herramientas/respaldo/README.md."
    }
    Add-Secreto $valor
    return $valor
}

# Separa la contraseña de una URL postgresql://usuario:clave@host/... y la deja
# en PGPASSWORD, para que no aparezca en la lista de procesos. Devuelve la URL sin clave.
function Split-ClaveDeUrl {
    param([string]$Url)
    $m = [regex]::Match($Url, '^(postgres(?:ql)?://)([^:@/]+):(.*)@([^@]*)$')
    if ($m.Success) {
        $clave = [System.Uri]::UnescapeDataString($m.Groups[3].Value)
        Add-Secreto $clave
        Add-Secreto $m.Groups[3].Value
        $env:PGPASSWORD = $clave
        return $m.Groups[1].Value + $m.Groups[2].Value + '@' + $m.Groups[4].Value
    }
    return $Url
}

function Get-VersionMayor {
    param([string]$Texto)
    $m = [regex]::Match($Texto, '(\d+)(\.\d+)?')
    if (-not $m.Success) { throw "No pude leer la versión en: $Texto" }
    return [int]$m.Groups[1].Value
}

function Invoke-Consulta {
    param([string]$Psql, [string]$Url, [string]$Sql)
    $r = Invoke-Nativo -Programa $Psql -Argumentos @('-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
        "--dbname=$Url", '-c', $Sql)
    return @($r.Salida | Where-Object { $_ -ne '' })
}

# Cuenta las filas de cada bloque COPY de un volcado de datos de pg_dump.
function Measure-FilasVolcado {
    param([string]$Ruta)
    $conteo = [ordered]@{}
    $tabla = $null
    $n = 0
    foreach ($linea in [System.IO.File]::ReadLines($Ruta)) {
        if ($null -eq $tabla) {
            $m = [regex]::Match($linea, '^COPY (\S+) \(.*\) FROM stdin;$')
            if ($m.Success) { $tabla = $m.Groups[1].Value; $n = 0 }
        } elseif ($linea -eq '\.') {
            $conteo[$tabla] = $n
            $tabla = $null
        } else {
            $n++
        }
    }
    return $conteo
}

function Get-Sha256 {
    param([string]$Ruta)
    return (Get-FileHash -LiteralPath $Ruta -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-TextoUtf8 {
    param([string]$Ruta, [string]$Texto)
    [System.IO.File]::WriteAllText($Ruta, $Texto, (New-Object System.Text.UTF8Encoding $false))
}

function New-CarpetaTemporal {
    param([string]$Prefijo)
    $ruta = Join-Path ([System.IO.Path]::GetTempPath()) ('{0}_{1}' -f $Prefijo, [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $ruta -Force | Out-Null
    return $ruta
}

function Remove-CarpetaSegura {
    param([string]$Ruta)
    if ($Ruta -and (Test-Path -LiteralPath $Ruta)) {
        Remove-Item -LiteralPath $Ruta -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Borra carpetas temporales que dejó una corrida anterior interrumpida (corte de
# luz, proceso cerrado): pueden tener datos SIN cifrar. Solo toca carpetas con el
# nombre exacto que crea New-CarpetaTemporal (gravity_respaldo_<guid> o
# gravity_restaurar_<guid>) y con más de -Horas sin cambios, para no tocar una
# corrida que siga en curso.
function Remove-TemporalesHuerfanos {
    param([int]$Horas = 6)
    $limite = (Get-Date).AddHours(-$Horas)
    $base = [System.IO.Path]::GetTempPath()
    $borradas = 0
    foreach ($d in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -match '^gravity_(respaldo|restaurar)_[0-9a-f]{32}$' -and $d.LastWriteTime -lt $limite) {
            Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $d.FullName) {
                Write-Bitacora "No pude borrar la carpeta temporal $($d.FullName): bórrala a mano (puede tener datos sin cifrar)." 'AVISO'
            } else {
                $borradas++
            }
        }
    }
    if ($borradas -gt 0) {
        Write-Bitacora "Borradas $borradas carpetas temporales de corridas interrumpidas (datos sin cifrar)." 'AVISO'
    }
}
