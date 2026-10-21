@echo off
:: ============================================================================
:: IT Network Monitor - Native Windows Service Installer (services.msc)
:: Registers background monitoring daemon into Windows Service Control Manager.
:: ============================================================================

title IT Network Monitor - Native Windows Service Installer
color 0A

echo ============================================================================
echo   Installing IT Network Monitor Native Windows Service (services.msc)
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

set "HOST_EXE=%~dp0it_service_host.exe"
set "ENGINE_EXE=%~dp0it_monitoring_service.exe"
if not exist "%ENGINE_EXE%" (
    set "ENGINE_EXE=%~dp0it_network_monitor.exe"
)

if not exist "%ENGINE_EXE%" (
    echo [ERROR] Monitoring engine executable not found in %~dp0.
    echo Please ensure this batch script is located in the release folder.
    pause
    exit /b 1
)

if exist "%~dp0apply_production_acls.bat" (
    echo Applying least-privilege production security ACLs...
    call "%~dp0apply_production_acls.bat"
)

if exist "%HOST_EXE%" (
    echo Using native Windows Service Control Manager Host (it_service_host.exe)...
    "%HOST_EXE%" --install
    if %errorLevel% equ 0 (
        echo [SUCCESS] Windows Service registered successfully in services.msc!
        echo Starting service...
        "%HOST_EXE%" --start
        echo.
        echo [INFO] Service is running in the background and will auto-start on boot.
    ) else (
        echo [ERROR] Failed to register Windows Service.
    )
) else (
    echo [WARNING] Native service host wrapper not found.
    echo Falling back to scheduled task registration...
    schtasks /Create /TN "ITNetworkMonitorService" /TR "\"%ENGINE_EXE%\" --service" /SC ONSTART /RU "SYSTEM" /RL HIGHEST /F
    schtasks /Run /TN "ITNetworkMonitorService"
)

echo.
pause
