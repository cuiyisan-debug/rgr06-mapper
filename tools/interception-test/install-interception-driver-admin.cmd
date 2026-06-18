@echo off
setlocal
cd /d "%~dp0Interception\Interception\command line installer"
echo Installing Interception driver...
echo.
echo This requires Administrator permission and may require a reboot.
echo To uninstall later, run:
echo   install-interception.exe /uninstall
echo.
install-interception.exe /install
echo.
pause
