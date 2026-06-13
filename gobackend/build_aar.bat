@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  FutbolGO - Build AAR
echo ============================================
echo.

REM --------------------------------------------------
REM  Android SDK / NDK auto-detection
REM --------------------------------------------------

if not "%ANDROID_NDK_HOME%" == "" (
    echo [INFO] Usando ANDROID_NDK_HOME=%ANDROID_NDK_HOME%
    goto :build
)

REM Try common NDK locations
set NDK_CANDIDATES[0]=%LOCALAPPDATA%\Android\Sdk\ndk
set NDK_CANDIDATES[1]=%USERPROFILE%\Android\Sdk\ndk
set NDK_CANDIDATES[2]=C:\Android\Sdk\ndk

for %%L in (0 1 2) do (
    set "CURRENT_DIR=!NDK_CANDIDATES[%%L]!"
    if exist "!CURRENT_DIR!\" (
        echo [INFO] Buscando NDK en !CURRENT_DIR!...
        for /f "delims=" %%D in ('dir "!CURRENT_DIR!\" /b /ad /o-n 2^>nul') do (
            set "FOUND_NDK=!CURRENT_DIR!\%%D"
            echo [INFO] NDK encontrado: !FOUND_NDK!
            goto :set_ndk
        )
    )
)

echo [ERROR] No se encontro el NDK de Android.
echo.
echo Para instalar el NDK:
echo   1. Abri Android Studio ^> SDK Manager ^> SDK Tools
echo   2. Marca "NDK (Side by side)" y aplica
echo   3. O ejecuta: sdkmanager "ndk;28.0.13004105"
echo.
echo Luego ajusta la ruta manualmente o define ANDROID_NDK_HOME.
pause
exit /b 1

:set_ndk
set ANDROID_NDK_HOME=%FOUND_NDK%
echo [OK] ANDROID_NDK_HOME=%ANDROID_NDK_HOME%
echo.

:build
echo [1/2] Compilando AAR desde ./scraper...
gomobile bind -target=android -o build/futbolgo.aar ./scraper
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Fallo la compilacion del AAR
    pause
    exit /b 1
)
echo [OK] AAR generado en: build/futbolgo.aar

REM Copy to Flutter Android libs
echo [2/2] Copiando AAR a Flutter Android libs...
if not exist "..\android\app\libs" mkdir "..\android\app\libs"
copy /Y "build\futbolgo.aar" "..\android\app\libs\futbolgo.aar"
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] No se pudo copiar el AAR a la carpeta de Flutter
) else (
    echo [OK] AAR copiado a android/app/libs/futbolgo.aar
)

echo.
echo ============================================
echo  AAR generado y copiado exitosamente
echo ============================================
pause
