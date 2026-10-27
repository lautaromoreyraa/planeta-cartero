# Exporta el juego a build/PlanetaCartero.exe con el preset "Windows Desktop".
#
# Es el respaldo local del workflow de release: genera el mismo ejecutable
# que el CI, con el .pck embebido. Compatible con Windows PowerShell 5.1.
#
# Uso, desde la raiz del repo:  powershell -File scripts/export.ps1

$ErrorActionPreference = 'Stop'

$raiz = Split-Path -Parent $PSScriptRoot
$salida = Join-Path $raiz 'build\PlanetaCartero.exe'

# Godot puede estar en el PATH o instalado suelto en C:\Godot. Se prefiere la
# variante de consola porque espera al proceso y muestra su salida.
function Find-Godot {
    foreach ($nombre in @('godot_console', 'godot')) {
        $comando = Get-Command $nombre -ErrorAction SilentlyContinue
        if ($null -ne $comando) {
            return $comando.Source
        }
    }
    foreach ($patron in @('C:\Godot\*console*.exe', 'C:\Godot\godot*.exe', 'C:\Godot\Godot*.exe')) {
        $encontrado = Get-ChildItem -Path $patron -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $encontrado) {
            return $encontrado.FullName
        }
    }
    return $null
}

# El contenido real vive en data/config.local.json, fuera de git. Sin ese
# archivo el ejecutable sale igual, pero con los placeholders del repo: se
# avisa para no entregar por error un regalo vacio (RNF-06).
if (-not (Test-Path (Join-Path $raiz 'data\config.local.json'))) {
    Write-Warning 'No existe data/config.local.json: el .exe va a salir con los textos de placeholder de data/config.json.'
}

$godot = Find-Godot
if ($null -eq $godot) {
    Write-Error 'No se encontro Godot en el PATH ni en C:\Godot.'
    exit 1
}
Write-Host "Godot: $godot"

# Sin la carpeta .godot (repo recien clonado) el export no conoce las clases
# globales ni los recursos importados: primero se importa el proyecto.
if (-not (Test-Path (Join-Path $raiz '.godot'))) {
    Write-Host 'Importando el proyecto...'
    & $godot --headless --path $raiz --editor --quit
    if ($LASTEXITCODE -ne 0) {
        Write-Error "El import fallo con codigo $LASTEXITCODE."
        exit 1
    }
}

$carpeta = Split-Path -Parent $salida
if (-not (Test-Path $carpeta)) {
    New-Item -ItemType Directory -Path $carpeta | Out-Null
}
# Se borra el ejecutable anterior para que un export fallido no deje pasar
# como bueno el de una corrida vieja.
if (Test-Path $salida) {
    Remove-Item -Path $salida -Force
}

Write-Host 'Exportando...'
& $godot --headless --path $raiz --export-release 'Windows Desktop' $salida
$codigo = $LASTEXITCODE

if ($codigo -ne 0) {
    Write-Error "El export fallo con codigo $codigo."
    exit 1
}
if (-not (Test-Path $salida)) {
    Write-Error "El export termino pero no genero $salida."
    exit 1
}

$megas = [math]::Round((Get-Item $salida).Length / 1MB, 1)
Write-Host "Listo: $salida ($megas MB)"
exit 0
