@echo off
REM ==============================================================================
REM Titofy — Compilador de Release y Generador de Instalador en Windows
REM ==============================================================================
echo ==========================================================
echo          COMPILANDO TITOFY PARA WINDOWS (RELEASE)
echo ==========================================================

cd /d "%~dp0..\..\desktop"
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo Error al compilar Flutter en Windows.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ==========================================================
echo Compilacion exitosa.
echo Si tienes Inno Setup instalado, puedes compilar titofy_setup.iss
echo para generar el ejecutable instalador final (Titofy-Setup-v1.0.0.exe).
echo ==========================================================
pause
