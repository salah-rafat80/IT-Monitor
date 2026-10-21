@echo off
:: ============================================================================
:: IT Network Monitor Service - Windows Service / Startup Uninstaller
:: ============================================================================

title IT Network Monitor - Service Uninstaller
color 0C

echo ============================================================================
echo   Uninstalling IT Network Monitor Shared Background Service
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

echo Stopping and removing Windows Task...
schtasks /End /TN "ITNetworkMonitorService" >nul 2>&1
schtasks /Delete /TN "ITNetworkMonitorService" /F

if %errorLevel% equ 0 (
    echo [SUCCESS] Service stopped and uninstalled successfully.
) else (
    echo [INFO] Service was not found or already uninstalled.
)

echo.
pause
