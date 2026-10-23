@echo off
setlocal enabledelayedexpansion
:: ============================================================================
:: IT Network Monitor - Production TLS Provisioning (Batch Launcher)
:: ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%provision_tls_certificate.ps1"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Required TLS provisioning script not found: "%PS_SCRIPT%" >&2
    exit /b 1
)

net session >nul 2>&1
if %ERRORLEVEL% equ 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
    set "EXIT_CODE=%ERRORLEVEL%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p = Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%PS_SCRIPT%\"\" %*' -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
    set "EXIT_CODE=%ERRORLEVEL%"
)

if %EXIT_CODE% neq 0 (
    echo [ERROR] provision_tls_certificate.ps1 failed with exit code %EXIT_CODE% >&2
    exit /b %EXIT_CODE%
)

exit /b 0
