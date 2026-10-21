; ============================================================================
; Inno Setup Compiler Script for IT Network Monitor (Windows x64)
; Production Release Gate: Multi-Mode Installer (Client / Service / Full)
; Registers Native Windows Service in SCM & Preserves Authoritative Database
; ============================================================================

#define MyAppName "IT Network Monitor"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "IT Department"
#define MyAppExeName "it_network_monitor.exe"
#define MyServiceHostName "it_service_host.exe"
#define MyAppBuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{D814FA7A-92E1-4B2E-84D0-37E74971A09E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ITNetworkMonitor
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=ITNetworkMonitor_Setup_v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full Deployment (Desktop GUI Client + Native Windows Service Host)"
Name: "clientonly"; Description: "Desktop Client Only (Wall Display, Dashboard & Remote Management)"
Name: "serviceonly"; Description: "Service Host Only (Dedicated Headless Monitoring Server)"
Name: "custom"; Description: "Custom Installation"; Flags: iscustom

[Components]
Name: "client"; Description: "Desktop Dashboard GUI Application (it_network_monitor.exe)"; Types: full clientonly custom
Name: "service"; Description: "Native Windows Monitoring Service (it_service_host.exe -> services.msc)"; Types: full serviceonly custom

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; Components: client
Name: "startservice"; Description: "Register and start Native Windows Service (auto-start on Windows boot)"; GroupDescription: "Service Configuration:"; Flags: unchecked; Components: service

[Files]
; 1. Core Executable and Flutter Release Bundle Dependencies
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 2. Native Windows Service Host Supervisor & Registration Scripts
Source: "it_service_host.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: service
Source: "install_windows_service_scm.bat"; DestDir: "{app}"; Flags: ignoreversion; Components: service
Source: "uninstall_windows_service_scm.bat"; DestDir: "{app}"; Flags: ignoreversion; Components: service
Source: "install_service.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall_service.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "apply_production_acls.bat"; DestDir: "{app}"; Flags: ignoreversion

; 3. Default Configuration Template (Preserved Across Upgrades and Uninstallation)
Source: "service_config.json.default"; DestDir: "{commonappdata}\ITNetworkMonitor"; DestName: "service_config.json"; Flags: onlyifdoesntexist uninsneveruninstall

[Dirs]
; Least-privilege production permissions:
; SYSTEM & Administrators have Full Control.
; BUILTIN\Users has NO inherited permissions on ProgramData.
; Approved operators are granted access via the dedicated ITNetworkMonitorAdministrators local group.
; certs (private TLS keys) and logs are strictly restricted to SYSTEM & Administrators only.
Name: "{commonappdata}\ITNetworkMonitor"; Permissions: system-full admins-full
Name: "{commonappdata}\ITNetworkMonitor\certs"; Permissions: system-full admins-full
Name: "{commonappdata}\ITNetworkMonitor\logs"; Permissions: system-full admins-full

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Components: client
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Components: client

[Run]
; Enforce least-privilege ACLs on ProgramData directories and authoritative files
Filename: "{app}\apply_production_acls.bat"; StatusMsg: "Configuring least-privilege security ACLs on data directories..."; Flags: runhidden waituntilterminated

; Service Registration and Startup via SCM
Filename: "{app}\{#MyServiceHostName}"; Parameters: "--install"; StatusMsg: "Registering IT Network Monitor Windows Service in services.msc..."; Flags: runhidden waituntilterminated; Components: service; Tasks: startservice
Filename: "{app}\{#MyServiceHostName}"; Parameters: "--start"; StatusMsg: "Starting background monitoring daemon..."; Flags: runhidden waituntilterminated; Components: service; Tasks: startservice

; Optional GUI Launch
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent; Components: client

[UninstallRun]
; Gracefully stop and unregister Windows Service before removing installed binaries
Filename: "{app}\{#MyServiceHostName}"; Parameters: "--stop"; Flags: runhidden waituntilterminated
Filename: "{app}\{#MyServiceHostName}"; Parameters: "--uninstall"; Flags: runhidden waituntilterminated
Filename: "sc.exe"; Parameters: "stop ITNetworkMonitorService"; Flags: runhidden waituntilterminated
Filename: "sc.exe"; Parameters: "delete ITNetworkMonitorService"; Flags: runhidden waituntilterminated

; NOTE ON DATA PRESERVATION:
; Database files in %ProgramData%\ITNetworkMonitor (it_network_monitor.sqlite, WAL, and logs)
; are intentionally preserved and never deleted by the uninstaller.
