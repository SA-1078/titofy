# ==============================================================================
# Titofy — Instalador Portable / Local para Windows (PowerShell)
# ==============================================================================
$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         🚀 INSTALADOR DE TITOFY PARA WINDOWS             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$RepoDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BundleSrc = Join-Path $RepoDir "desktop\build\windows\x64\runner\Release"
$InstallDir = Join-Path $env:LocalAppData "Titofy"
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Titofy.lnk"
$StartMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "Titofy"

# 1. Compilar si no existe
if (-not (Test-Path "$BundleSrc\desktop.exe")) {
    Write-Host "⚙️ Compilando release nativo de Titofy en Windows..." -ForegroundColor Yellow
    Push-Location (Join-Path $RepoDir "desktop")
    flutter build windows --release
    Pop-Location
}

# 2. Copiar archivos
Write-Host "📦 Copiando archivos de Titofy a $InstallDir..." -ForegroundColor Green
if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item "$BundleSrc\*" -Destination $InstallDir -Recurse -Force

# 3. Enlazar backend de IA
Write-Host "🧠 Conectando backend de IA..." -ForegroundColor Green
$BackendSrc = Join-Path $RepoDir "backend"
$BackendDst = Join-Path $InstallDir "backend"
if (-not (Test-Path $BackendDst)) {
    New-Item -ItemType SymbolicLink -Path $BackendDst -Target $BackendSrc -Force | Out-Null
}

# 4. Crear accesos directos
Write-Host "🖥️ Creando accesos directos..." -ForegroundColor Green
$WshShell = New-Object -ComObject WScript.Shell
$ExePath = Join-Path $InstallDir "desktop.exe"

# Acceso directo en escritorio
$Shortcut = $WshShell.CreateShortcut($DesktopShortcut)
$Shortcut.TargetPath = $ExePath
$Shortcut.WorkingDirectory = $InstallDir
$Shortcut.IconLocation = $ExePath
$Shortcut.Description = "Titofy - Reproductor de Música y Letras IA"
$Shortcut.Save()

# Acceso directo en Menú Inicio
New-Item -ItemType Directory -Path $StartMenuDir -Force | Out-Null
$MenuShortcut = $WshShell.CreateShortcut((Join-Path $StartMenuDir "Titofy.lnk"))
$MenuShortcut.TargetPath = $ExePath
$MenuShortcut.WorkingDirectory = $InstallDir
$MenuShortcut.IconLocation = $ExePath
$MenuShortcut.Description = "Titofy - Reproductor de Música y Letras IA"
$MenuShortcut.Save()

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ✅ ¡Instalación completada con éxito en Windows!        " -ForegroundColor Green
Write-Host "  • Puedes abrir Titofy desde tu Escritorio o Menú Inicio." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
