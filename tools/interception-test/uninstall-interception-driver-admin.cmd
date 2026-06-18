@echo off
setlocal
cd /d "%~dp0Interception\Interception\command line installer"
echo Uninstalling Interception driver...
echo.
install-interception.exe /uninstall
echo.
pause
