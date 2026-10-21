# IT Network Monitor — Active Context

## Current Status
- **Phase**: Production Hardening & Bug Fixes — Completed & Fully Verified
- **Architecture**: Clean Architecture, Drift SQLite WAL mode, Cubit state management, Authoritative Windows background service (`it_monitoring_service.exe`), SCM Host (`it_service_host.exe`).
- **Direct Administrator Launch (Decision 72 / Pattern 26)**: Direct entry without interactive login; service provisions an OS-protected machine-bound ephemeral token (`trusted_client.token`) in ProgramData, granting authorized local admin access.
- **Fail-Closed API Security**: All sensitive REST endpoints (`/api/devices`, `/api/incidents`, `/api/topology`, `/api/settings`, `/api/reports/*`, `/api/discovery/*`) and WebSocket `/ws` enforce authentication (`401 Unauthorized`) and role authorization (`403 Forbidden` for non-admin mutations). URL query parameter tokens (`?token=`) rejected. Minimal public health endpoint `/api/health` and `/api/status`.
- **Argon2id Password Hashing**: Cryptographically secure, versioned Argon2id (`$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`) with 16-byte random salt, constant-time comparison, backward compatibility for legacy fixed-salt hashes, and automatic in-place hash upgrade upon successful login.
- **Windows Least-Privilege ACL Policy**: `%ProgramData%\ITNetworkMonitor` restricted so `BUILTIN\Users` receive only Read & Execute; `certs` and `logs` strictly isolated to `SYSTEM` and `Administrators`. Non-destructive validation mode `-ValidateOnly` in `apply_production_acls.ps1`.
- **Availability Reporting & CSV Hardening**: Accurate full-window gap detection (initial window gap, adjacent gaps, final window gap against 2-hour threshold). Nullable latency semantics (distinguishing true 0.0ms ping from unmeasured/missing latency). CSV exports protected against spreadsheet formula injection (`=`, `+`, `-`, `@`) and RFC 4180 compliant.
- **Safe Transactional Migrations**: Schema v10 wrapped in transaction boundary with structured migration failure diagnostics, selective duplicate column handling, and core `Ipv4Utils` canonicalization.
- **Monitoring Scheduler Diagnostics**: Structured logging and internal error counters for persistence/repository failures without silent exception swallowing or state corruption.
- **Live Test Isolation**: Physical subnet ping/sweeps gated behind `IT_MONITOR_RUN_LIVE_NETWORK_TESTS=1`. Default tests run safely on developer and CI runners.
- **Release Build Hardening**: `installer/build_production_release.ps1` checks `$LASTEXITCODE` after all compiler calls, purges stale binaries, discovers Inno Setup dynamically, and verifies non-empty artifacts.
- **Database Schema**: Drift SQLite schema v10 with partial unique index `idx_devices_ip ON devices(ip) WHERE ip != '' AND ip IS NOT NULL`.

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
