# IT Network Monitor — Active Context

## Current Status
- **Phase**: Final Production Security Audit & Installed-Service Verification — Complete & Production Ready
- **Test Suite**: 175/175 automated unit & integration tests passing (100% pass rate).
- **Static Analysis**: `flutter analyze` reports 0 errors and 0 warnings.
- **Dedicated Headless Windows Service Executable**: `it_monitoring_service.exe` running headlessly via `flutter::FlutterEngine` in Session 0 (`LocalSystem`) without GUI/EGL/DirectX initialization errors.
- **Native Windows Service Host (SCM)**: `it_service_host.exe` supervising headless service, registered as `AUTO_START` under `LocalSystem`.
- **ProgramData Least-Privilege ACLs**: Corrected broad permissions; `%ProgramData%\ITNetworkMonitor\certs` and `logs` strictly isolated to `SYSTEM` and `Administrators` (verified ordinary users receive `Access is denied`); SQLite database restricted to read-only for standard users.
- **Production TLS & Header-Based WebSocket**: Fail-closed production mode; verified HTTPS REST & WSS over strict TLS; untrusted cert rejected; WebSocket bearer tokens passed via `Authorization: Bearer <token>` header with zero URL leakage; secrets and private keys redacted from logs.
- **Windows Packaging**: Production Inno Setup installer compiled at `dist\ITNetworkMonitor_Setup_v1.0.0.exe` (11.9 MB) and standalone release zip `dist\ITNetworkMonitor-Windows-x64-v1.0.0.zip` (13.8 MB).
- **Database Schema**: Drift SQLite schema v7 preserving all 37 PC/Laptop records, 4 verified UniFi APs, Users, Incidents, and Discovery tables.

## Critical UniFi Infrastructure Monitoring
- **Authoritative IP Management**: Supports UniFi Gateways (Cloud Gateway/UDM), UniFi Controllers (CloudKey/Network Application), UniFi Switches, and Access Points. Never invents IPs, credentials, or metrics.
- **Role Differentiation & Routing Logic**: Routing capability is strictly reserved for verified Core Gateways. Switches and APs are never assumed to perform routing. Unconfirmed devices are flagged with `requiresAdminConfirmation: true`.
- **Deduplicated Critical Incidents**: When a verified core gateway goes Down, creates exactly ONE deduplicated critical incident (`gateway_down`, severity: `critical`) reporting affected network segments.
- **Dependency Isolation**: Does NOT cascade-fail dependent PCs! Real PC ICMP probe results are independently preserved, distinguishing dependency impact from direct LAN reachability.
- **Controller Separation**: Management controller availability is kept completely separate from gateway routing. Controller down creates `controller_down` without claiming routing failure.
- **Strictly Read-Only**: `UniFiApiClient` prohibits all write/mutation/provisioning operations by design.
- **Dashboard & Wall Display**: Main Dashboard features responsive Critical Infrastructure cards with routing impact warnings; Wall Display includes operational status pills.
- **Central Continuous Daemon**: `MonitoringScheduler` polls infrastructure management IPs in `bin/monitoring_service.dart`, continuing even when Desktop Clients are closed.

## Manual Device Owner Assignment in Inventory
- **Persistent Storage**: Reuses canonical `Devices.ownerName` column in Drift SQLite without destructive migration.
- **Role Enforcement**: Admin can assign, edit, and clear assignments; Viewer is strictly read-only (enforced in repository and REST API).
- **Audit Logging**: Recorded actions `DEVICE_OWNER_ASSIGNED`, `DEVICE_OWNER_MODIFIED`, and `DEVICE_OWNER_CLEARED` with user ID, device ID, previous value, new value, and timestamp.
- **Immutable IP**: Device IP address is strictly protected and cannot be changed or corrupted during owner assignment.
- **Consistent Display**: Prioritizes (1) Assigned person's name, (2) Department, (3) Device name, (4) IP address, (5) Monitoring status across Dashboard, Devices Table, Device Details modal, Incidents, Topology, Wall Display, Network Discovery review, and CSV export.
- **Fallback Standard**: Displays `Unassigned` when no person is assigned (never invents names).
- **REST & Real-Time Sync**: `POST /api/devices/assign-owner` endpoint with WebSocket event broadcast (`device_owner_changed`, `device_updated`) to synchronize all desktop clients.
- **Search & Filtering**: Search by assigned person's name, department, device name, IP, and location works seamlessly and persists across restarts.
- **Excel/CSV Import**: Mapped `person` and `assigned` headers to canonical owner; duplicate IPs rejected without overwriting existing DB owners.

## Live Network Discovery Verification
- **Target Ranges Tested**: `192.168.27.0/24` and `192.168.22.0/24` (508 candidate targets).
- **Execution Duration**: 36.1 seconds with bounded concurrency (30 parallel workers).
- **Live Devices Responding**: 51 active physical/virtual devices observed.
- **Already Known Matches**: 19 active devices recognized from the existing approved 37-device production inventory and tagged `AlreadyKnown` without duplicate records.
- **Pending Review**: 32 unmanaged discovered assets available for Admin evaluation.
- **Production Inventory**: Existing 37 monitored devices completely preserved and untouched.

## Next Capabilities
- Switch SNMP & port mapping (pending management credentials and IP allowlist).
- Gateway and internet health monitors.
