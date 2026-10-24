@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure_lan_client.ps1" %*
exit /b %ERRORLEVEL%
