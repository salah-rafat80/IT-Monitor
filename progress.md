# IT Network Monitor — Progress Log

## Workstream History & Milestone Progress

### Completed Milestones
1. **Authentication & Session Management**: Argon2id hashing, role-based route guards (Admin/Viewer), session tokens, user management UI & service endpoints.
2. **Approved Inventory Management**: 37 approved PC/Laptop devices active in SQLite database with duplicate IP protection, non-destructive import, and CSV export.
3. **Continuous ICMP Monitoring & Incident Engine**: Background ICMP pinger, configurable debounce (3 failures to Down / 2 recoveries to Up), bounded concurrency (50 workers), auto-recovery incidents, acknowledge & resolution notes.
4. **Desktop Monitoring Dashboard & Topology View**: Real-time KPI summary cards, filterable DataTable, location & switch grouping topology view, full audit logging.
5. **Wall Display Mode**: 1920x1080 operational dashboard displaying all 37 devices simultaneously with 0 scrollbars, live clock, and ESC exit.
6. **Central Monitoring Service Architecture**: Decoupled daemon running REST & WebSocket on port 8080 with native Windows SCM service installer scripts (`services.msc`).
7. **Network Discovery & Device Classification**: Multi-strategy read-only discovery, deterministic 12-category classifier, approval workflow, evidence inspector.
8. **Critical UniFi Infrastructure & Verified AP Monitoring**: Drift schema v7 with `InfrastructureDevices` table; 4 verified UniFi APs; core gateway deduplicated incidents.
9. **Production Security Audit & Installed-Service Verification**: Dedicated headless `it_monitoring_service.exe`, native SCM host `it_service_host.exe`, least-privilege ProgramData ACLs, production TLS with strict verification.
10. **Direct Administrator Launch (Decision 72 / Pattern 26)**: Direct entry to dashboard under `Local Administrator (No Interactive Login)` with full audit attribution and zero login prompts.
11. **Compact Enterprise Topology Layout Mode**: Widescreen-balanced 16:9 layout with dual-column branch balance, corridor routing, and dynamic bounding-box auto-fit.
12. **Composite Asset Identity & SQLite Uniqueness Hardening**: Persistence boundary unique index (`idx_devices_ip`), composite identifiers (`device:$id` / `infra:$id`), and ping error shadowing resolution.
13. **Final Data Integrity & Runtime Acceptance Gate**:
    - *Legacy IP Migration Safety*: Safe v10 migration mapping duplicate legacy IPs to unassigned non-pingable states (`ip = ''`, `isMonitored = false`, `isEnabled = false`) with diagnostic notes. Partial unique index `idx_devices_ip ON devices(ip) WHERE ip != '' AND ip IS NOT NULL;`.
    - *Uptime Semantics & Availability*: Disentangled empirical probe reachability from continuous wall-clock availability. Detects prolonged unobserved gaps (>2h) and returns `uptimePercent = null` (`N/A`) with `hasSufficientHistory = false`. Fixed boundary-spanning incident queries.
    - *Cross-Module Identity Harmonization*: Injected `InfrastructureRepository` into discovery and cubits, eliminating duplicate inventory creation for infrastructure assets and ensuring idempotent approvals.
    - *Verification*: Automated tests passing (100%), 0 analyze issues, clean code formatting, Windows x64 Release binary verified.
14. **Production Hardening & Security (Phases 0-10)**:
    - *API & Service Security*: Fail-closed 401 on sensitive endpoints, 403 on mutations, removed `?token=` leakage, provisioned ephemeral machine-local token (`trusted_client.token`) for direct launch without interactive prompt, minimal public health endpoint.
    - *Password Hashing*: Versioned Argon2id with 16-byte cryptographically secure random salt, constant-time comparison, legacy fixed-salt fallback, and automatic in-place hash re-hashing on successful login.
    - *Least-Privilege Windows ACLs*: Updated PowerShell, batch, and Inno Setup scripts to restrict `BUILTIN\Users` to Read & Execute, strictly isolating `certs` and `logs` to `SYSTEM` and `Administrators`. Added non-destructive `-ValidateOnly`.
    - *Reporting Accuracy & CSV Safety*: Full-window gap detection (initial, adjacent, final window gaps), nullable latency (distinguishing 0.0ms from unmeasured/null), RFC 4180 CSV escaping, and spreadsheet formula injection neutralization (`=`, `+`, `-`, `@`).
    - *Database Migrations*: Transactional schema v10 migration with diagnostic logging and selective duplicate column handling; extracted shared `Ipv4Utils` in `lib/core/utils/` to decouple domain service from database core.
    - *Monitoring Diagnostics*: Unswallowed errors, structured logs, and error counters for persistence/repository failures.
    - *Test Isolation*: Live physical subnet scans safely gated behind `IT_MONITOR_RUN_LIVE_NETWORK_TESTS=1`.
    - *Release Build Hardening*: Hardened `installer/build_production_release.ps1` with `$LASTEXITCODE` checks, stale binary deletion, configurable Inno Setup discovery, and artifact size verification.
