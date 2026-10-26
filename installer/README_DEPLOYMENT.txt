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
7. configure_lan_client.bat        : Remote LAN Client Configuration Setup Utility
8. configure_lan_client.ps1        : Hardened PowerShell 5.1 LAN Client Configurator
9. service_config.json.default     : Production TLS and Configuration Template
10. client_config.json.default     : Client Endpoint Configuration Template
11. README_ARABIC.txt              : Comprehensive Arabic Setup and Operator Guide

DEPLOYMENT INSTRUCTIONS:
----------------------------------------------------------------------------
A. Standard Desktop Client (Local Operator / Server Console):
   - Double-click 'it_network_monitor.exe' (or 'START_MONITOR.bat') to launch the GUI monitoring client.
   - Automatically authenticates with the local background service via machine token.

B. Always-On Monitoring Host (Dedicated Server):
   - Right-click 'install_windows_service_scm.bat' -> "Run as Administrator".
   - The monitoring service will start automatically in services.msc.
   - Closing the GUI desktop app will NOT stop background monitoring.
   - SCM automatically restarts the service on unexpected process failure.

C. Remote Operator Workstations on Local Network (LAN Client):
   To connect an operator PC over the LAN to the central monitoring server:
   1. Obtain the server's public certificate 'server.crt' (%ProgramData%\ITNetworkMonitor\server.crt).
   2. Run 'configure_lan_client.bat' (or PowerShell 5.1):
      configure_lan_client.bat -ServerHost <Server_IP_or_Host> -Port 8443 -ServerCertPath server.crt -ClientToken <Authorized_Token> [-AddToTrustedRoot]
      Example:
      configure_lan_client.bat -ServerHost 192.168.1.50 -Port 8443 -ServerCertPath server.crt -ClientToken <token>
   3. Launch 'it_network_monitor.exe'. It connects securely to the central service over TLS
      without prompting for an interactive login password.

============================================================================
