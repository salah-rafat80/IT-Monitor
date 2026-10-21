@echo off
:: ============================================================================
:: IT Network Monitor Service - Windows Service / Startup Installer
:: Runs on always-on monitoring host machine as a background Windows Task.
:: ============================================================================

title IT Network Monitor - Service Installer
color 0A

echo ============================================================================
echo   Installing IT Network Monitor Shared Background Service
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

set "SERVICE_EXE=%~dp0it_monitoring_service.exe"

if not exist "%SERVICE_EXE%" (
    set "SERVICE_EXE=%~dp0it_network_monitor.exe --service"
)

echo Registering Windows Automatic Scheduled Task...
schtasks /Create /TN "ITNetworkMonitorService" /TR "\"%SERVICE_EXE%\"" /SC ONSTART /RU "SYSTEM" /RL HIGHEST /F

if %errorLevel% equ 0 (
    echo [SUCCESS] Service installed successfully!
    echo [INFO] Service configured to run automatically on Windows boot.
    echo.
    echo Starting service now...
    schtasks /Run /TN "ITNetworkMonitorService"
) else (
    echo [ERROR] Failed to register service.
)

echo.
pause
