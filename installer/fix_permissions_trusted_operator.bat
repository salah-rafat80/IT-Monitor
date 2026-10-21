@echo off
:: ============================================================================
:: IT Network Monitor - Practical Permissions Fix (One-Click)
:: ============================================================================
echo Requesting administrator elevation...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File ""%~dp0fix_permissions_trusted_operator.ps1""' -Verb RunAs"
exit /b %ERRORLEVEL%
