# IT Network Monitor

Enterprise IT Infrastructure & Network Monitoring Application for Windows (Flutter Desktop x64).

Provides real-time ICMP reachability probing, automated network discovery, inventory management, topological dependency mapping, incident lifecycle tracking, and historical availability reporting for enterprise IT operations.

---

## Key Features

- **Direct Administrator Launch (Decision 72 / Pattern 26)**: Designed as an internal operations tool with direct entry into the dashboard under the `Local Administrator (No Interactive Login)` role with explicit audit attribution.
- **Dedicated Headless Windows Service (`it_monitoring_service.exe`)**: Supervised by native Windows Service Host (`it_service_host.exe`) registered in the Windows Service Control Manager (SCM) under `LocalSystem`. Runs headlessly in Session 0 without DirectX, EGL, or platform view rendering dependencies.
- **Authoritative Drift SQLite Persistence**: High-integrity SQLite database in `%ProgramData%\ITNetworkMonitor\it_network_monitor.sqlite` operating in WAL mode with partial unique indexing (`WHERE ip != '' AND ip IS NOT NULL`) and defensive concurrency error translation.
- **Empirical Reachability vs Wall-Clock Uptime Semantics**: Clearly distinguishes instantaneous probe reachability from continuous 24/7 availability. Automatically flags prolonged unobserved intervals (> 2 hours) and reports `N/A` rather than fabricating 0% or 100% metrics.
- **Active Network Discovery**: Concurrent ICMP sweeps across authorized subnets (`192.168.27.0/24`, `192.168.22.0/24`) with cross-module identity matching against both standard devices and UniFi infrastructure access points.
- **Enterprise Network Topology**: High-density hierarchical layout diagram (WAN $\rightarrow$ Gateways $\rightarrow$ Distribution Switches $\rightarrow$ UniFi APs $\rightarrow$ Endpoints) with responsive dual-column branch balance and dynamic bounding-box auto-fit.
- **Production Packaging**: Inno Setup installer script (`InnoSetup_Installer_Script.iss`) supporting Full, Client-Only, and Headless Service deployments with least-privilege ProgramData ACL enforcement.

---

## Architecture Overview

```
it_network_monitor/
├── bin/
│   └── monitoring_service.dart          # Headless service entry point
├── lib/
│   ├── core/                            # Database, DI, routing, theme, errors
│   │   ├── database/                    # Drift SQLite schema & safe v10 migration
│   │   └── di/                          # GetIt & Injectable dependency wiring
│   └── features/
│       ├── auth/                        # No-login administrator context & audit
│       ├── devices/                     # Device inventory CRUD, canonicalization
│       ├── infrastructure/              # UniFi gateways, switches, access points
│       ├── monitoring/                  # ICMP ping engine, scheduler, latency tracker
│       ├── network_discovery/           # Subnet scanner, coordinator, approval cubit
│       ├── reports/                     # Availability reporting, boundary incident query
│       ├── incidents/                   # Incident detection, tracking, escalation
│       └── topology/                    # Layout diagram builder & compact layout
├── windows/
│   └── runner/
│       ├── main.cpp                     # Client GUI entry point
│       └── service_main.cpp             # Headless C++ engine entry point
├── installer/                           # SCM service host C# code & Inno Setup scripts
└── test/                                # 272 passing automated unit, widget & integration tests
```

---

## Development & Verification

### Prerequisites
- Windows 10/11 x64
- Flutter 3.29.x
- Dart 3.7.x
- Visual Studio 2022 with C++ Desktop Workload

### Run Quality Gates
```powershell
# Format check
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze

# Full automated test suite (272 tests)
flutter test

# Build production Windows release
flutter build windows --release
```

---

## License & Attribution

Internal IT Operations Tool. All rights reserved.
