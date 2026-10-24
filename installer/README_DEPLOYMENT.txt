============================================================================
IT NETWORK MONITOR - PRODUCTION RELEASE (Windows x64)
============================================================================

Requirements:
- Windows 10 / 11 / Server 2016+ (64-bit)
- NO Flutter, Dart, Visual Studio, or dev tools required.

CONTENTS:
1. it_network_monitor.exe          : IT Desktop Monitoring Dashboard GUI Client
2. it_monitoring_service.exe       : Dedicated Headless Windows Monitoring Service Executable
3. it_service_host.exe             : Native Windows Service Control Manager Host
4. install_windows_service_scm.bat : Native Windows Service Installer (services.msc)
5. uninstall_windows_service_scm.bat: Service Uninstaller Script
6. START_MONITOR.bat               : Desktop Dashboard Quick Launcher Script
7. service_config.json.default     : Production TLS and Configuration Template
8. دليل_التشغيل_والتثبيت.txt       : Comprehensive Arabic Setup and Operator Guide

DEPLOYMENT INSTRUCTIONS:
----------------------------------------------------------------------------
A. Standard Desktop Client (IT Desktop Users):
   - Double-click 'it_network_monitor.exe' (or 'START_MONITOR.bat') to launch the GUI monitoring client.

B. Always-On Monitoring Host (Dedicated Server):
   - Right-click 'install_windows_service_scm.bat' -> "Run as Administrator".
   - The monitoring service will start automatically in services.msc.
   - Closing the GUI desktop app will NOT stop background monitoring.
   - SCM automatically restarts the service on unexpected process failure.

============================================================================
