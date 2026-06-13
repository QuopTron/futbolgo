@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  FutbolGO - Inicio en Windows
echo ============================================
echo.

:: Verificar que Go esta instalado
where go >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Go no esta instalado. Instalalo desde https://go.dev/dl/
    pause
    exit /b 1
)

:: Verificar que Flutter esta instalado
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter no esta instalado. Instalalo desde https://flutter.dev/
    pause
    exit /b 1
)

echo [1/4] Compilando servidor Go backend...
cd /d "%~dp0gobackend"
go build -o build/futbolgo-server.exe ./cmd/server/main.go
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Fallo la compilacion del servidor Go
    pause
    exit /b 1
)
echo [OK] Servidor Go compilado correctamente

echo [2/4] Iniciando servidor Go en puerto 8080...
start "FutbolGO-Backend" /min "build\futbolgo-server.exe" --port 8080
echo [OK] Servidor iniciado en http://localhost:8080

:: Esperar a que el servidor este listo
echo [3/4] Esperando al servidor...
timeout /t 3 /nobreak >nul

echo [4/4] Iniciando app Flutter...
cd /d "%~dp0"
start "FutbolGO" flutter run -d windows

echo.
echo ============================================
echo  FutbolGO iniciado correctamente
echo  Servidor: http://localhost:8080
echo  App: Corriendo en Windows
echo  Para cerrar, cierra la ventana de la app
echo  y luego cierra la ventana del backend
echo ============================================
echo.
pause
