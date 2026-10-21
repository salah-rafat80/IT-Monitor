# IT Network Monitor

Enterprise IT Infrastructure & Network Monitoring Application for Windows (Flutter Desktop x64).

Provides real-time ICMP reachability probing, automated network discovery, inventory management, topological dependency mapping, incident lifecycle tracking, and historical availability reporting for enterprise IT operations.

---

## Key Features

- **Direct Administrator Launch & Service Security (Decision 72 / Pattern 26)**: Designed as an internal operations tool with direct entry into the dashboard under the `Local Administrator (No Interactive Login)` role with explicit audit attribution. The background service provisions an ephemeral machine-local trusted client token in `%ProgramData%\ITNetworkMonitor\trusted_client.token` with restricted OS file permissions, granting trusted local GUI sessions full administrative access without an interactive prompt. All sensitive REST endpoints and WebSocket upgrades fail closed with `401 Unauthorized` for unauthenticated requests and `403 Forbidden` for non-admin mutations. Token transmission via URL query parameters (`?token=`) is strictly prohibited.
- **Dedicated Headless Windows Service (`it_monitoring_service.exe`)**: Supervised by native Windows Service Host (`it_service_host.exe`) registered in the Windows Service Control Manager (SCM) under `LocalSystem`. Runs headlessly in Session 0 without DirectX, EGL, or platform view rendering dependencies.
- **Authoritative Drift SQLite Persistence**: High-integrity SQLite database in `%ProgramData%\ITNetworkMonitor\it_network_monitor.sqlite` operating in WAL mode with partial unique indexing (`WHERE ip != '' AND ip IS NOT NULL`) and defensive concurrency error translation.
- **Empirical Reachability vs Wall-Clock Uptime Semantics**: Clearly distinguishes instantaneous probe reachability from continuous 24/7 availability. Automatically flags prolonged unobserved intervals (> 2 hours) and reports `N/A` rather than fabricating 0% or 100% metrics. CSV exports enforce RFC 4180 escaping and sanitize spreadsheet formula injection prefixes (`=`, `+`, `-`, `@`).
- **Active Network Discovery**: Concurrent ICMP sweeps across authorized subnets (`192.168.27.0/24`, `192.168.22.0/24`) with cross-module identity matching against both standard devices and UniFi infrastructure access points. Live physical subnet sweeps are safely gated behind `IT_MONITOR_RUN_LIVE_NETWORK_TESTS=1` so default test runs never scan real subnets.
- **Enterprise Network Topology**: High-density hierarchical layout diagram (WAN $\rightarrow$ Gateways $\rightarrow$ Distribution Switches $\rightarrow$ UniFi APs $\rightarrow$ Endpoints) with responsive dual-column branch balance and dynamic bounding-box auto-fit.
- **Least-Privilege Windows ACL Policy**: SCM installer and ACL configuration enforce least privilege: `SYSTEM` and `Administrators` retain Full Control, ordinary `BUILTIN\Users` receive only Read & Execute permissions on base ProgramData, and private certificates (`certs/`) and service logs (`logs/`) are strictly isolated to `SYSTEM` and `Administrators`.

---

## Architecture Overview

```
it_network_monitor/
├── bin/
│   └── monitoring_service.dart          # Headless service entry point
├── lib/
│   ├── core/                            # Database, DI, routing, theme, errors, IPv4 utilities
│   │   ├── database/                    # Drift SQLite schema & safe transactional v10 migration
│   │   └── di/                          # GetIt & Injectable dependency wiring
│   └── features/
│       ├── auth/                        # No-login administrator context, trusted token & audit
│       ├── devices/                     # Device inventory CRUD, canonicalization, owner assignment
│       ├── infrastructure/              # UniFi gateways, switches, access points
│       ├── monitoring/                  # ICMP ping engine, scheduler diagnostics, server & client
│       ├── network_discovery/           # Subnet scanner, coordinator, approval cubit
│       ├── reports/                     # Availability reporting, full-window gap detection, CSV
│       ├── incidents/                   # Incident detection, tracking, escalation
│       └── topology/                    # Layout diagram builder & compact layout
├── windows/
│   └── runner/
│       ├── main.cpp                     # Client GUI entry point
│       └── service_main.cpp             # Headless C++ engine entry point
├── installer/                           # SCM service host C#, hardened build & Inno Setup scripts
└── test/                                # Automated unit, security, widget & integration tests
```

---

## Development & Verification

### Prerequisites
- Windows 10/11 x64
- Dart SDK `^3.8.1` (as specified in `pubspec.yaml`)
- Flutter 3.29.x or newer
- Visual Studio 2022 with C++ Desktop Workload

### Run Quality Gates
```powershell
# Format check
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze

# Full automated test suite (live subnet sweeps safely skipped by default)
flutter test

# Run live network discovery acceptance tests (requires explicit opt-in on authorized network)
$env:IT_MONITOR_RUN_LIVE_NETWORK_TESTS="1"
flutter test test/features/network_discovery/real_network_discovery_acceptance_test.dart
Remove-Item env:IT_MONITOR_RUN_LIVE_NETWORK_TESTS

# Build production Windows release
flutter build windows --release

# Build standalone distribution and Inno Setup installer
powershell -ExecutionPolicy Bypass -File installer/build_production_release.ps1
```

---

## License & Attribution

Internal IT Operations Tool. All rights reserved.
