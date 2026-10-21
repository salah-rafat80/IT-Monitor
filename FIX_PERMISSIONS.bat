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

title Repairing IT Network Monitor Database Permissions
color 0A

echo ============================================================================
echo   Repairing IT Network Monitor Database ACLs & Permissions
echo ============================================================================
echo.

set "DATA_DIR=%ProgramData%\ITNetworkMonitor"
set "DB_FILE=%DATA_DIR%\it_network_monitor.sqlite"

echo [1/3] Stopping background Windows Service...
sc.exe stop ITNetworkMonitorService >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/3] Applying Modify permissions to BUILTIN\Users...
icacls "%DATA_DIR%" /grant:r "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" "BUILTIN\Users:(OI)(CI)(M)" /q
if exist "%DB_FILE%" (
    icacls "%DATA_DIR%\it_network_monitor.sqlite*" /grant:r "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" "BUILTIN\Users:M" /q
)

echo [3/3] Restarting background Windows Service...
sc.exe start ITNetworkMonitorService >nul 2>&1

echo.
echo [SUCCESS] Authoritative database permissions repaired successfully!
echo You can now click 'Retry Monitoring Initialization' in the Dashboard.
echo.
pause
