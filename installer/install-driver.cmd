@echo off
setlocal
cd /d "%~dp0drivers\Interception\command line installer"
install-interception.exe /install
exit /b %errorlevel%
