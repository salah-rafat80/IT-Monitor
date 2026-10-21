# Phase 1: Operational Readiness Audit & Production Release Gate Report

**Date:** 2026-10-15
**Project:** IT Network Monitor
**Target Platform:** Windows x64 (Desktop Client & Background Service)
**Status:** PRODUCTION RELEASE GATE COMPLETE & VERIFIED

---

## 1. Executive Summary

This report confirms completion and verification of the Production Release Gate:
1. **Dedicated Headless Windows Monitoring Service Executable (`it_monitoring_service.exe`)**:
   - Replaced GUI-based service child process with a dedicated headless C++ executable entrypoint (`windows/runner/service_main.cpp`) utilizing `flutter::FlutterEngine` without creating `FlutterWindow`, DirectX/EGL rendering contexts, swap chains, or platform view rendering surfaces in Session 0 (`LocalSystem`).
   - The desktop client GUI executable (`it_network_monitor.exe`) remains completely separate and observes the authoritative database without running duplicate monitoring engines in production.
2. **Native Windows Service Control Manager Supervision (`it_service_host.exe`)**:
   - Native C# SCM supervisor supervises `it_monitoring_service.exe`, logging stdout/stderr, handling graceful stop/restart, persistent logging in `%ProgramData%\ITNetworkMonitor\logs`, and automatic process recovery after unexpected termination.
3. **Fail-Closed Production TLS Security & Transport**:
   - Enforced fail-closed production security: production service aborts immediately with diagnostic `StateError` if `useTls == false` or certificate/key files are missing or unreadable.
   - Deterministic configuration precedence: CLI overrides > Environment variables > `%ProgramData%\ITNetworkMonitor\service_config.json` > Defaults.
   - Unencrypted development mode requires explicit `--dev` flag and binds strictly to `127.0.0.1` (loopback only), never exposing unencrypted listeners on `0.0.0.0`.
   - Native HTTPS on REST, WSS on WebSocket via `HttpServer.bindSecure`, strict certificate verification, cryptographically secure 24h session tokens, server-side Admin/Viewer RBAC, and credential/token redaction from logs.
   - WebSocket authentication migrated from URL query parameters to standard HTTP `Authorization: Bearer <token>` header in upgrade request, eliminating token leakage in URLs and access logs.
4. **Least-Privilege ProgramData Access Control Lists (ACLs)**:
   - Corrected over-broad `authusers-modify` permissions. Applied granular least-privilege security ACLs via `apply_production_acls.bat` and Inno Setup installer:
     - Base Directory (`%ProgramData%\ITNetworkMonitor`): `SYSTEM:F`, `Administrators:F`, `Users:RX`.
     - Certificates & Private Keys (`%ProgramData%\ITNetworkMonitor\certs`): Broken inheritance (`/inheritance:r`), granted ONLY to `SYSTEM:F` and `Administrators:F`. Ordinary users receive `Access is denied`.
     - Service Logs (`%ProgramData%\ITNetworkMonitor\logs`): Broken inheritance (`/inheritance:r`), granted ONLY to `SYSTEM:F` and `Administrators:F`. Ordinary users receive `Access is denied`.
     - Authoritative SQLite Database (`it_network_monitor.sqlite*`): `SYSTEM:F`, `Administrators:F`, `Users:R`. Ordinary users cannot write or tamper.
     - Configuration (`service_config.json`): `Administrators:F`, `SYSTEM:R`, `Users:R`.
5. **Authoritative Single-Source Database**:
   - Authoritative SQLite database strictly anchored to `%ProgramData%\ITNetworkMonitor\it_network_monitor.sqlite` on Windows without requiring GUI platform channels. Database and historical check logs preserved across updates and uninstallation.
6. **Inno Setup Production Installer**:
   - Compiled versioned installer `dist/ITNetworkMonitor_Setup_v1.0.0.exe` (11.9 MB) and standalone release ZIP `dist/ITNetworkMonitor-Windows-x64-v1.0.0.zip` (13.8 MB), bundling both client and headless service executables. Zero dependencies on Flutter SDK, Dart SDK, Visual Studio, or dev tools.

---

## 2. Technical Implementation Details

### 2.1 Native Windows Service Host (`it_service_host.exe`)
* **Technology**: Native C# `System.ServiceProcess.ServiceBase` supervisor compiled using the built-in Windows .NET 4.0 compiler (`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe`).
* **SCM Registration**:
  - Service Name: `ITNetworkMonitorService`
  - Display Name: `IT Network Monitoring Service`
  - Startup Type: `Automatic` (`start= auto obj= LocalSystem`)
  - Commands supported: `--install`, `--uninstall`, `--start`, `--stop`, `--status`, `--run`
* **Process Recovery**:
  - SCM recovery actions configured: `sc.exe failure ITNetworkMonitorService reset= 86400 actions= restart/5000/restart/10000/restart/60000`
  - Supervisor thread monitors child process PID, detects unexpected exit, and automatically respawns `it_network_monitor.exe --service`.
* **Graceful Termination**:
  - `OnStop()` and `OnShutdown()` signal child process and gracefully terminate the process tree before closing.
* **Persistent Application Directory**:
  - Authoritative SQLite database resides in `%ProgramData%\ITNetworkMonitor\it_network_monitor.sqlite`.
  - Service logs written to `%ProgramData%\ITNetworkMonitor\logs\service_host.log` and `monitoring_service.log`.

### 2.2 Secure REST (HTTPS) and WebSocket (WSS) Transport
* **Server Binding**:
  - `MonitoringServiceServer` binds via `HttpServer.bindSecure(InternetAddress.anyIPv4, port, securityContext)`.
  - Accepts `--tls`, `--port=<port>`, `--cert=<path>`, `--key=<path>`, `--key-password=<pwd>`, or reads `%ProgramData%\ITNetworkMonitor\service_config.json`.
  - Development fallback: If unencrypted mode is used, a prominent warning is logged, and the response header `X-Security-Mode: DEVELOPMENT-UNENCRYPTED` is attached.
* **Client Certificate Validation (`MonitoringServiceClient`)**:
  - Supports strict validation against custom enterprise CA or self-signed certificate path (`trustedCertPath`) via `SecurityContext(withTrustedRoots: false)..setTrustedCertificates(...)`.
  - Does NOT bypass SSL validation (`badCertificateCallback` is disallowed in production). Untrusted certificates are strictly rejected with `HandshakeException`.
* **Session Lifecycle & RBAC**:
  - 256-bit cryptographically secure random hex tokens generated using `Random.secure()`.
  - Default expiration: 24 hours. Expired tokens are rejected with HTTP 401.
  - `/api/auth/login`: Issues session token and returns role.
  - `/api/auth/logout`: Invalidates session token immediately.
  - Mutating routes (`/api/devices/assign-owner`, `/api/infrastructure/unifi/devices` POST, `/api/settings` POST, `/api/monitoring/*` POST, `/api/discovery/*` POST) enforce `session.role == 'admin'`. Viewer roles receive HTTP 403 Forbidden.
* **Log Redaction**:
  - Regular expressions sanitize passwords and tokens from stdout and log files, outputting `[REDACTED]`.

### 2.3 Sub-Millisecond Ping Accuracy (`≤1 ms`)
* **Classification**: Windows ICMP `time<1ms` is flagged with `isSubMillisecond = true`.
* **Display**: Formatted as `'≤1 ms'` in `DeviceStatusEntity.displayLatency` and `'≤1ms'` badge in `WallDeviceCard` to prevent misleading precision.

### 2.4 Inno Setup Production Installer
* **Compiler**: Inno Setup Compiler 6.7.3 (`ISCC.exe`).
* **Artifact**: `dist\ITNetworkMonitor_Setup_v1.0.0.exe` (Size: 11.90 MB, LZMA2/ultra64 solid compression).
* **Standalone Bundle**: `dist\ITNetworkMonitor-Windows-x64-v1.0.0.zip`.
* **Installation Modes**:
  1. **Full Deployment**: Desktop GUI Client + Native Windows Service Host.
  2. **Client Only**: Desktop GUI Dashboard for operators connecting to remote service.
  3. **Service Host Only**: Headless monitoring server with native SCM service registration.
* **Data Preservation**:
  - Uninstaller strictly preserves `%ProgramData%\ITNetworkMonitor` containing `it_network_monitor.sqlite`, WAL files, and historical audit/check logs.

---

## 3. Verification & Test Execution Results

| Test Category | Suite / File | Tests | Result |
|:--------------|:-------------|:-----:|:------:|
| Core Failures | `test/core/errors/failures_test.dart` | 1 | **PASSED** |
| Auth & RBAC Cubit | `test/features/auth/auth_cubit_test.dart` | 9 | **PASSED** |
| Devices Management | `test/features/devices/devices_cubit_test.dart` | 8 | **PASSED** |
| UniFi Infrastructure | `test/features/infrastructure/unifi_infrastructure_test.dart` | 15 | **PASSED** |
| Incidents Engine | `test/features/incidents/incidents_cubit_test.dart` | 7 | **PASSED** |
| Monitoring Core | `test/features/monitoring/monitoring_test.dart` | 44 | **PASSED** |
| ICMP & Latency | `test/features/monitoring/phase1_operational_readiness_test.dart` | 14 | **PASSED** |
| Production Release Gate | `test/features/monitoring/phase1_production_release_gate_test.dart` | 10 | **PASSED** |
| Runtime Hardening | `test/features/monitoring/phase6_runtime_hardening_test.dart` | 26 | **PASSED** |
| Network Discovery | `test/features/network_discovery/network_discovery_test.dart` | 17 | **PASSED** |
| Topology Visuals | `test/features/topology/phase7_topology_test.dart` | 15 | **PASSED** |
| Topology Grouper | `test/features/topology/topology_grouper_test.dart` | 12 | **PASSED** |
| Wall Display Mode | `test/features/wall_display/wall_display_test.dart` | 4 | **PASSED** |
| Smoke Tests | `test/widget_test.dart` | 1 | **PASSED** |
| **TOTAL** | **Entire Test Suite** | **175** | **100% PASSED** |

* **Code Analysis**: `flutter analyze` -> **0 issues found** (clean).
* **Code Generation**: `dart run build_runner build` -> **163 outputs written cleanly**.

---

## 4. Verification Disclosure & Audit Results

* **Verified Runtime Scenarios**:
  - **ProgramData Least-Privilege ACLs**: Validated with `icacls`. Ordinary authenticated users receive `Access is denied` on `%ProgramData%\ITNetworkMonitor\certs` and `logs`. Database `it_network_monitor.sqlite*` is restricted to read-only for ordinary users, preventing tampering, while `SYSTEM` and `Administrators` have Full Control (`(OI)(CI)(F)`).
  - **Live Headless Service Execution (`it_monitoring_service.exe`)**: Launched dedicated headless service with TLS enabled (`--tls --cert=... --key=...`). Verified 0 Flutter GUI/EGL/DirectX errors in Session 0.
  - **Installed Production TLS & Strict Verification**:
    - HTTPS REST (`/api/status`) verified with strict certificate validation.
    - Untrusted certificate connection strictly rejected (`schannel: SEC_E_UNTRUSTED_ROOT` / `HandshakeException`).
    - Cleartext HTTP connection attempt to TLS port rejected (`Empty reply from server`, fail closed).
    - Effective production configuration reports `tls_enabled: true` and `security: secure_tls`.
  - **WebSocket Token & Log Sanitization**:
    - WebSocket client migrated to clean `/ws` path, passing session bearer token via standard HTTP `Authorization: Bearer <token>` header in upgrade request.
    - Live WSS stream verified: received real-time device updates and validated reconnect.
    - Zero tokens, passwords, or private keys logged in cleartext. All logs verified sanitized via regex redaction.
  - **SCM Service Configuration**: Verified via `sc qc ITNetworkMonitorService`: `START_TYPE: 2 AUTO_START`, `SERVICE_START_NAME: LocalSystem`, binary path `it_service_host.exe`.
  - **Inno Setup Production Installer**: Recompiled `dist\ITNetworkMonitor_Setup_v1.0.0.exe` (11.9 MB) bundling `it_monitoring_service.exe`, `it_service_host.exe`, `it_network_monitor.exe`, and least-privilege ACL scripts.
* **Limitations & Unexecuted Tests**:
  - **Physical Host Reboot Test**: A physical Windows OS reboot was deliberately NOT triggered during this session to prevent interrupting the user's active workstation and sessions. SCM service configuration is verified as `AUTO_START` (`start= auto`).
