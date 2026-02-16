@echo off
set "BUILDER=C:\Program Files (x86)\Steam\steamapps\common\Arma 3 Tools\AddonBuilder\AddonBuilder.exe"
set "SOURCE=%~dp0source\A3A_Arsenal"
set "DEST=%~dp0addons"

echo Checking for AddonBuilder...
if not exist "%BUILDER%" (
    echo Error: AddonBuilder not found at "%BUILDER%"
    echo Please edit this script to point to your Arma 3 Tools installation.
    pause
    exit /b 1
)

echo Building A3A_Arsenal...
"%BUILDER%" "%SOURCE%" "%DEST%" -clear -packonly

if %ERRORLEVEL% NEQ 0 (
    echo Build Failed!
    pause
    exit /b %ERRORLEVEL%
)

echo Build Successful! PBO created in "%DEST%"
pause
