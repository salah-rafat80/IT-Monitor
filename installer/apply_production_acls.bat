@echo off
:: ============================================================================
:: IT Network Monitor - Practical Production ACLs (Batch Launcher)
:: ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0apply_production_acls.ps1""' -Verb RunAs -Wait"
exit /b %ERRORLEVEL%
