@echo off
:: ============================================================================
:: IT Network Monitor - Live Permission & SQLite Repair Tool
:: Automatically elevates to Administrator and repairs ProgramData ACLs
:: ============================================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Elevating privileges to Administrator...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title Repairing IT Network Monitor Least-Privilege Permissions
color 0A

call "%~dp0apply_production_acls.bat"
exit /b %ERRORLEVEL%
