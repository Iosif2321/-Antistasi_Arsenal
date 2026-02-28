@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

set "BUILDER=C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\AddonBuilder\AddonBuilder.exe"
set "SOURCE=%~dp0source\A4A_Arsenal"
set "DEST=%~dp0addons"

echo ============================================
echo   Antistasi Arsenal - PBO Builder
echo ============================================
echo.

:: Check Steam is running (AddonBuilder requires it)
tasklist /FI "IMAGENAME eq steam.exe" 2>nul | find /I "steam.exe" >nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Steam is not running!
    echo AddonBuilder requires Steam to be running.
    echo Please start Steam and try again.
    echo.
    pause
    exit /b 1
)
echo [OK] Steam is running.

:: Check AddonBuilder exists
if not exist "%BUILDER%" (
    echo [ERROR] AddonBuilder not found at:
    echo   "%BUILDER%"
    echo.
    echo Install "Arma 3 Tools" from Steam Library ^(Tools section^).
    pause
    exit /b 1
)
echo [OK] AddonBuilder found.

:: Check source directory exists
if not exist "%SOURCE%\config.cpp" (
    echo [ERROR] Source not found or missing config.cpp:
    echo   "%SOURCE%"
    pause
    exit /b 1
)
echo [OK] Source directory verified.

:: Create output directory if missing
if not exist "%DEST%" (
    mkdir "%DEST%"
    echo [OK] Created addons directory.
)

echo.
echo Building A4A_Arsenal...
echo.

"%BUILDER%" "%SOURCE%" "%DEST%" -clear -packonly

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [FAILED] Build failed with error code %ERRORLEVEL%.
    echo If AddonBuilder shows no output, make sure Steam is fully loaded.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================
echo   [OK] Build Successful!
echo   PBO: "%DEST%\A4A_Arsenal.pbo"
echo ============================================
pause
