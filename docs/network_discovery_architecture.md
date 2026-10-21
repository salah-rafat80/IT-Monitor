# IT Network Monitor — Network Discovery & Classification Architecture

## 1. Overview
The Network Discovery & Device Classification subsystem discovers, fingerprints, and classifies active devices across authorized corporate subnets. It operates inside the Central Monitoring Service daemon to ensure continuous operation, bounded system resource usage, and non-interference with continuous production ICMP monitoring.

## 2. Core Constraints & Guarantees
- **Approved Scopes Only**: Initial authorized scopes:
  - `192.168.27.0/24` (254 usable hosts: `192.168.27.1` to `192.168.27.254`)
  - `192.168.22.0/24` (254 usable hosts: `192.168.22.1` to `192.168.22.254`)
  - Total candidate targets: 508 host IPs. Excludes network (.0) and broadcast (.255).
- **Non-Destructive Inventory Preservation**: Existing approved 37 PC/Laptop inventory items are strictly preserved. Discovered devices matching known IPs are tagged as `AlreadyKnown`.
- **Decoupled Discovery from Monitoring**: A device responding to discovery is NOT automatically added to the continuous monitoring scheduler. Approval as a monitored PC/Laptop is a separate administrative workflow requiring valid owner and department assignments.
- **Read-Only Probing**: Only non-intrusive connection attempts (ICMP echo, ARP cache inspection, reverse DNS PTR, conservative TCP connection attempts on allowed ports: 80, 443, 554, 8080, 9100, 631, 22, and ONVIF WS-Discovery). No brute-forcing, password attempts, or camera video streaming.
- **Windows x64 Native Compatibility**: All strategies run cleanly on Windows without requiring third-party unbundled tools like Nmap.

## 3. High-Level Architecture

```text
[ Windows Flutter Desktop Client ]
        │
        │ HTTP REST & WebSocket (/ws)
        ▼
[ Central Monitoring Service (monitoring_service_server.dart) ]
        │
        ├── [ Discovery Coordinator ]
        │       ├── Range Validator & CIDR Target Enumerator
        │       ├── Reachability Evaluator
        │       ├── Concurrency Limiter (Default: 20 concurrent targets)
        │       └── Job Lifecycle (Draft -> Running -> Completed/Cancelled/Failed)
        │
        ├── [ Discovery Strategies Pipeline ]
        │       ├── ICMP Discovery Strategy (Echo request, timeout 2s)
        │       ├── ARP Discovery Strategy (Layer 2 MAC cache lookup)
        │       ├── DNS / Hostname Strategy (Reverse PTR lookup)
        │       ├── TCP Probes Strategy (Port allowlist: 80, 443, 554, 8080, 9100, 631, 22)
        │       ├── ONVIF WS-Discovery Strategy (UDP multicast 239.255.255.250:3702 & RTSP check)
        │       ├── mDNS / SSDP Strategy (Local service discovery)
        │       └── MAC Vendor Lookup (Deterministic IEEE OUI prefix table)
        │
        ├── [ Multi-Source Classification Engine ]
        │       ├── Evidence Aggregation
        │       ├── Deterministic Scoring & Confidence Assignment (High/Med/Low/Unknown)
        │       └── Protection of Manual Overrides
        │
        ├── [ Approval & Review Engine ]
        │       ├── PendingReview -> Approved / Rejected / AlreadyKnown / Conflict
        │       ├── PC/Laptop Promotion -> Devices Repository (Requires Owner/Department)
        │       └── Other Categories -> Discovered Assets Repository
        │
        └── [ Persistence & Auditing (Drift SQLite v5) ]
                ├── DiscoveryConfigurations
                ├── DiscoveryScans
                ├── DiscoveredDevices
                ├── DiscoveryEvidence
                └── AuditLogs
```

## 4. Device Categories
- `PC`
- `Laptop`
- `Mobile`
- `IP Camera`
- `Printer`
- `Server`
- `Switch`
- `Router`
- `Wireless Access Point`
- `Other Network Device`
- `Other`
- `Unknown`

## 5. Review States
- `PendingReview`: Newly discovered asset awaiting Admin evaluation.
- `Approved`: Asset confirmed. If PC/Laptop, promoted to monitored inventory. If other, saved as verified asset.
- `Rejected`: Discarded or untracked device.
- `AlreadyKnown`: IP matches an existing device in the 37-device production inventory.
- `NeedsMoreEvidence`: Responded to probe but insufficient evidence to classify.
- `Conflict`: IP matches existing record with conflicting MAC or conflicting host name.

## 6. Real-Time Events
WebSocket broadcast events:
- `discovery_scan_started`
- `discovery_progress_updated`
- `discovery_device_found`
- `discovery_scan_completed`
- `discovery_scan_cancelled`
- `discovery_scan_failed`
- `discovery_device_reviewed`

## 7. Unified Persistent Inventory & No-Login Mode Integration
- **Canonical Asset Persistence**:
  - The authoritative `Devices` table stores ALL approved network assets regardless of category (all 12 categories: PC, Laptop, Mobile, IP Camera, Printer, Server, Switch, Router, Wireless Access Point, Other Network Device, Other, Unknown).
  - Schema v9 columns: `id`, `name`, `type`, `ip`, `mac`, `hostname`, `operating_system`, `owner_name`, `department`, `office_location`, `vendor`, `model`, `notes`, `is_monitored`, `is_enabled`, `created_at`.
- **Deduplication & Repeated Scans**:
  - `DiscoveredDevices` stores technical observation records from scans.
  - When an asset is approved, it is written to `Devices` (or updated if matching IP exists).
  - Subsequent discovery scans update observed technical attributes (MAC, hostname, vendor) without creating duplicate inventory records or overwriting confirmed business ownership (`owner_name`, `department`, `office_location`).
- **Monitoring Scheduler Separation**:
  - Continuous 24/7 ICMP monitoring strictly targets assets with `isMonitored == true` (PCs/Laptops default to monitored; infrastructure/peripherals default to unmonitored unless explicitly toggled on).
  - Unmonitored devices never receive fake ICMP ping checks, preventing false down alerts.
- **Direct Administrator Mode**:
  - Interactive login screen removed. App launches immediately into `Local Administrator (No Interactive Login)` mode with role `admin`.
  - All admin operations (discovery approval, manual add, edit, delete) are logged with audit attribution to `Local Administrator (No Interactive Login)`.
