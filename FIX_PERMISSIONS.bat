@echo off
:: ============================================================================
:: IT Network Monitor - Live Permission & ACL Hardening Tool
:: Automatically elevates to Administrator and repairs ProgramData ACLs
:: ============================================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Elevating privileges to Administrator...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title Hardening IT Network Monitor Least-Privilege Permissions
color 0A

echo ============================================================================
echo   Hardening IT Network Monitor Least-Privilege ACLs
echo ============================================================================
echo.

set "DATA_DIR=%ProgramData%\ITNetworkMonitor"
set "DB_FILE=%DATA_DIR%\it_network_monitor.sqlite"
set "GROUP_NAME=ITNetworkMonitorAdministrators"

echo [1/4] Ensuring dedicated local group "%GROUP_NAME%" exists...
net localgroup "%GROUP_NAME%" >nul 2>&1
if %errorLevel% neq 0 (
    net localgroup "%GROUP_NAME%" /add /comment:"Authorized operators permitted to access IT Network Monitor trusted client token without interactive login" >nul 2>&1
    echo   Created local Windows group: %GROUP_NAME%
) else (
    echo   Local Windows group already exists: %GROUP_NAME%
)

echo.
echo [2/4] Stopping background Windows Service...
sc.exe stop ITNetworkMonitorService >nul 2>&1
timeout /t 2 /nobreak >nul

echo.
echo [3/4] Applying least-privilege permissions...
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

:: Remove broad inherited permissions and configure strict grants
icacls "%DATA_DIR%" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" "%GROUP_NAME%:(RX)" /q
icacls "%DATA_DIR%" /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Failed to clean some old ACEs on %DATA_DIR%
)

if exist "%DATA_DIR%\certs" (
    icacls "%DATA_DIR%\certs" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" /q
    icacls "%DATA_DIR%\certs" /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q >nul 2>&1
)
if exist "%DATA_DIR%\logs" (
    icacls "%DATA_DIR%\logs" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)" "BUILTIN\Administrators:(OI)(CI)(F)" /q
    icacls "%DATA_DIR%\logs" /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q >nul 2>&1
)
if exist "%DB_FILE%" (
    icacls "%DATA_DIR%\it_network_monitor.sqlite*" /inheritance:r /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" /q
    icacls "%DATA_DIR%\it_network_monitor.sqlite*" /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q >nul 2>&1
)
if exist "%DATA_DIR%\service_config.json" (
    icacls "%DATA_DIR%\service_config.json" /inheritance:r /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" /q
    icacls "%DATA_DIR%\service_config.json" /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q >nul 2>&1
)
if exist "%DATA_DIR%\trusted_client.token" (
    icacls "%DATA_DIR%\trusted_client.token" /inheritance:r /grant "NT AUTHORITY\SYSTEM:F" "BUILTIN\Administrators:F" "%GROUP_NAME%:R" /q
    icacls "%DATA_DIR%\trusted_client.token" /remove:g "BUILTIN\Users" "Everyone" "NT AUTHORITY\Authenticated Users" /q >nul 2>&1
)

echo.
echo [4/4] Restarting background Windows Service...
sc.exe start ITNetworkMonitorService >nul 2>&1

echo.
echo ============================================================================
echo [SUCCESS] Authoritative directory permissions secured with least privilege!
echo.
echo To grant an operator direct-launch access without an interactive login,
echo run the following command in an elevated prompt:
echo.
echo   net localgroup %GROUP_NAME% ^<username^> /add
echo.
echo ============================================================================
echo.
pause
