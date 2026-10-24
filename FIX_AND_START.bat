@echo off
title IT Network Monitor - Auto Repair and Launch
cd /d "%~dp0"

echo ============================================================================
echo   IT Network Monitor - Auto Repair and Launch
echo ============================================================================
echo.
echo Requesting Administrator privileges to repair permissions and start background service...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0installer\fix_local_installation.ps1\"\"' -Verb RunAs -Wait"

echo.
echo Launching IT Network Monitor Desktop App...
if exist "%~dp0dist\ITNetworkMonitor-Windows-x64\it_network_monitor.exe" (
    start "" "%~dp0dist\ITNetworkMonitor-Windows-x64\it_network_monitor.exe"
) else if exist "%~dp0build\windows\x64\runner\Release\it_network_monitor.exe" (
    start "" "%~dp0build\windows\x64\runner\Release\it_network_monitor.exe"
)
exit
