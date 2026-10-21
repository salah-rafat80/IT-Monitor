@echo off
:: ============================================================================
:: IT Network Monitor - Native Windows Service Uninstaller
:: Safely unregisters background monitoring service without deleting database.
:: ============================================================================

title IT Network Monitor - Service Uninstaller
color 0C

echo ============================================================================
echo   Uninstalling IT Network Monitor Windows Service
echo ============================================================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrative privileges required.
    echo Please right-click this script and select "Run as Administrator".
    echo.
    pause
    exit /b 1
)

echo Stopping Windows Service...
sc.exe stop ITNetworkMonitorService >nul 2>&1
schtasks /End /TN "ITNetworkMonitorService" >nul 2>&1

echo Removing Service Registration...
sc.exe delete ITNetworkMonitorService >nul 2>&1
schtasks /Delete /TN "ITNetworkMonitorService" /F >nul 2>&1

echo [SUCCESS] Service uninstalled cleanly.
echo [NOTE] Database files in AppData were preserved.
echo.
pause
