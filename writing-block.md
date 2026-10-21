# IT NETWORK MONITOR — BRUTAL FULL-SYSTEM ENGINEERING AUDIT
## Real-World Correctness, Adversarial Testing, Data Integrity, Clean Architecture, Responsive UI, and Production Reliability

Act as a principal software engineer, Flutter desktop architect, senior QA engineer, SRE, network monitoring specialist, database engineer, and adversarial test engineer.

Your mission is to conduct the most rigorous practical audit of the existing IT Network Monitor project, then fix the confirmed defects and validate the fixes against the real application.

**Do not give me a report that merely says the architecture looks good, the tests pass, or the application is ready. Prove each important claim with evidence from source code, executed tests, real runtime behavior, and verified data.**

I want you to deliberately challenge the application, expose unexpected failures, eliminate fragile assumptions, refactor demonstrably poor code, and improve the responsive UI.

A test suite that passes because its mocks were written to match the implementation is not sufficient.

A UI that looks good only at 1920×1080 is not sufficient.

A network discovery screen that displays plausible but unverified devices is not sufficient.

A service that starts successfully but silently stops monitoring or writes to the wrong database is not sufficient.

Do not stop after writing an audit plan. Inspect the repository, execute the available checks, document the findings, fix confirmed defects, add regression tests, and repeat verification until the remaining failures and limitations are explicitly accounted for.

---

# PHASE 0 — NON-NEGOTIABLE PROJECT CONSTRAINTS

First, identify the real project root and inspect the current source code, project configuration, existing tests, documentation, installer, service implementation, and Git status if available.

Preserve these established product decisions:

- Platform: Windows x64 Flutter desktop application.
- State management: the existing flutter_bloc/Cubit approach.
- Persistence: existing SQLite/Drift architecture and WAL behavior.
- Background monitoring: the existing dedicated Windows monitoring service remains the authoritative monitoring scheduler.
- Product Decision 72 / Pattern 26: the application launches directly without an interactive login screen.
- No endpoint agents are to be installed on employee PCs.
- Existing network discovery, inventory, incidents, topology, dashboard, Wall Display, reports, infrastructure, and audit functionality must not be casually removed.
- Preserve the 37 approved PC/Laptop records and the four known UniFi Access Points, along with existing incidents, audit logs, discovery history, and other legitimate persistent data.
- Previously approved scan ranges are `192.168.27.0/24` and `192.168.22.0/24`. Do not scan arbitrary additional networks.
- The existing monitoring service must not be duplicated by the desktop client.

Do not assume these details are still implemented exactly as previously documented. Verify them in the current source and installed runtime.

Never execute destructive migrations, delete production records, reset the production database, alter production ACLs, or run an unverified cleanup script during this audit.

Create isolated test databases, controlled backups, and disposable test configurations. Any test requiring destructive actions must run against isolated test data.

Do not overwrite the user's existing local changes. Inspect and preserve unrelated modifications.

Do not add interactive login, change the approved product decisions, or undertake a wholesale architecture rewrite unless a demonstrated defect requires it and the consequences have been explained.

---

# PHASE 1 — SOURCE-CODE FORENSIC AUDIT

Inspect the actual implementation of every feature and create a source-referenced audit matrix.

Include every implemented module you find, at minimum:

1. Application startup and dependency injection.
2. No-login authentication state and routing.
3. Dashboard and category counters.
4. Device inventory, CRUD, details, filters, and search.
5. Network Discovery, scan scheduling, result classification, and discovery review.
6. Inventory approval from discovered devices.
7. Infrastructure and Access Point management.
8. Device monitoring and health-state transitions.
9. Incident creation, deduplication, recovery, and history.
10. Network topology and its underlying relationships.
11. Wall Display.
12. Reports and export functionality.
13. Users and Audit, wherever these modules actually exist.
14. Application settings and persistence.
15. Monitoring service initialization, scheduling, lifecycle, and IPC/REST/WebSocket communication where implemented.
16. SQLite/Drift schema, migrations, transactions, concurrency, and backup/restore.
17. Logging, error reporting, and notification capabilities if implemented.
18. Installer, service host, release configuration, Windows startup, and shutdown.
19. Responsive behavior, accessibility, localization, and window resizing.
20. Other modules discovered in the repository.

For each feature, report:

- Implemented source files and actual entry points.
- Business rules and authoritative data source.
- Whether the displayed values are grounded in the actual database, service responses, network evidence, or merely defaults/mock data.
- Error handling and recovery behavior.
- Automated test coverage and its limitations.
- Runtime verification performed.
- Confirmed defects and reproducible steps.
- Severity: Critical, High, Medium, or Low.
- Fix applied, regression test added, or explicit reason it remains unresolved.

Do not confuse documentation, comments, model fields, buttons, or placeholder implementations with working features.

Trace important functionality end to end:

User interaction → Widget → Cubit/BLoC → Use Case, if present → Repository → Data Source or Monitoring Service → actual database or external system → result mapping → UI state.

Identify cases where a screen appears functional but its action is a no-op, persists only in memory, returns stale data, uses a hardcoded response, or ignores a backend/service failure.

Inspect all navigation routes, button handlers, refresh actions, filters, empty states, dialogs, confirmation flows, and cancellation paths.

Do not mark a feature fully working until its actual behavior is verified.

---

# PHASE 2 — BUILD TESTS THAT CHALLENGE THE IMPLEMENTATION

## Critical Testing Rule

Do not write tests merely to confirm what the current implementation already does.

Derive expected behavior independently from the intended requirements, domain invariants, database constraints, protocol contracts, and observable outcomes.

Avoid tests that repeat the implementation's own algorithm as their oracle. Such tests can reproduce the same bug and still pass.

Do not hardcode expected error messages from a faulty implementation.

Test invariants, safe failure behavior, correct state transitions, resource cleanup, data integrity, and whether the application remains usable after the failure.

For expected failures, assert the semantic outcome rather than brittle wording. For unexpected failures, the application must handle the failure safely, record useful diagnostics, preserve valid data, and recover or expose an honest error state.

Never swallow an error and then return a fabricated success.

## A. Unit Tests

Test domain logic, parsers, state transitions, validation, repositories, mapping, layout calculations, monitoring rules, and other pure business logic independently.

Include:

- Empty collections and null values.
- Missing optional fields.
- Unexpected enum values and unknown device categories.
- Duplicate IDs, duplicate IPs, conflicting identities, and conflicting updates.
- Malformed JSON, missing keys, incorrect types, unexpected nesting, empty strings, whitespace, invalid encodings, and excessively large inputs.
- Invalid, private, reserved, and malformed IPv4 ranges where relevant to the intended scanner rules.
- CIDR boundaries, first and last allowed hosts, network/broadcast handling, and invalid masks.
- Latency that is missing, zero, extremely large, negative, stale, or associated with a failed ping.
- Clock changes, different timestamps, long-running processes, and boundary values for timeouts.
- Repeated transitions between healthy, degraded, down, recovering, and unknown states.
- Cancellation, re-entry, concurrent calls, and race conditions.
- Unexpected repository results and partial failures.
- Integer overflow risks, invalid numeric values, NaN, infinity, and invalid percentages where numeric inputs are used.
- Very long device names, Unicode, Arabic text, emoji, and text that exceeds the available UI space.

Challenge parser logic with real Windows process outputs and deliberately misleading outputs.

For ICMP parsing, explicitly verify that:

`Reply from 192.168.27.64: Destination host unreachable`

does not count as a successful response from target `192.168.27.28`.

Check for stale latency being carried forward after a failed probe. A failed probe must not be treated as success merely because output contains the word `Reply`, a timestamp, or a previous latency value.

Use table-driven tests and property-based or fuzz-style testing when appropriate and practical. Do not introduce unnecessary dependencies just to claim that fuzz testing exists.

## B. Database and Persistence Tests

Test against isolated temporary databases using the actual Drift schema and the actual production data-access paths.

Test:

- Fresh database initialization.
- Every existing schema migration, including upgrade from a supported older schema.
- Reopening the database after closing all connections.
- Repeated startup and shutdown.
- WAL and SHM creation, checkpointing, deletion, and recreation.
- Concurrent desktop-client and service reads/writes.
- Multiple concurrent inventory updates.
- A database lock held beyond the configured busy timeout.
- Read-only files, directory permission loss, disk-space failures where safely reproducible, and database-open errors.
- Interrupted transactions, exceptions in the middle of a multi-step update, and rollback behavior.
- Process shutdown during pending writes.
- Corrupt or truncated database files in disposable test environments.
- Missing database files and invalid database paths.
- Backup consistency while data changes.
- Restore into an isolated database and verify restored records.
- Duplicate prevention when an operation is retried.
- Race conditions during discovery approval and concurrent inventory updates.
- Partial migrations, failed schema changes, and repeated migration attempts.

Verify that transactions either commit a logically complete operation or leave a recoverable state. Never allow partially updated inventory records simply because one step failed.

Verify that audit records are produced for the intended operations and that failed operations are not reported as successful.

Do not corrupt or manipulate the production database to test corruption recovery.

## C. Repository and API/Service Contract Tests

Test actual serialization, deserialization, database mappings, service request/response contracts, validation, timeout behavior, and error propagation.

Where the service exposes an endpoint, test:

- Valid requests.
- Missing or malformed fields.
- Wrong data types.
- Unknown identifiers.
- Empty results.
- Duplicate requests.
- Concurrent requests.
- Requests arriving during shutdown.
- Service timeouts and connection refusal.
- Disconnected clients and partially received messages.
- Malformed responses and unexpected status codes.
- TLS/certificate failures where relevant.
- Retry behavior without duplicate writes.
- Authentication or local trust failures where applicable to the implemented transport.

Check that the UI receives actual authoritative values and that the repository does not silently substitute demo data after a request fails.

Use mocks for isolated unit tests, but also add integration and contract tests against the real local service implementation where feasible. Clearly identify what is mocked and what is real.

## D. Monitoring Service and Scheduler

Verify the actual service and client lifecycle, not just Cubit emissions.

Test:

- Service starts after Windows reboot according to its configured start policy.
- Service startup is delayed or fails because configuration, database, or certificates are unavailable.
- Client launches before the service becomes ready.
- Service stops while the client is open.
- Service becomes unresponsive.
- A monitoring cycle throws an unexpected exception.
- One device probe fails without terminating the entire scheduler.
- A scan or monitoring cycle is cancelled during shutdown.
- Two monitoring cycles attempt to overlap.
- A previous cycle takes longer than the configured interval.
- The service process is restarted while the application remains open.
- Database locking, permission failure, disk errors, or unexpected data prevent a write.
- An invalid service configuration is detected and handled safely.
- A stale UI connection is recovered without duplicate subscriptions.
- Repeated reconnect attempts use bounded backoff rather than causing a tight retry loop.
- No duplicate scheduler is started by the desktop client.
- A failed probe does not incorrectly cause a device to be marked healthy or down.

Verify resource disposal, timers, streams, process handles, sockets, database connections, and subscriptions. Repeated start/stop operations must not accumulate duplicate workers or leaking resources.

If an external service provider or a real Windows reboot is unavailable, report the item as unverified. Never replace an unperformed runtime test with a passing unit test and claim equivalence.

## E. Real Network Discovery Tests

Inspect the scanner and classification algorithms in the actual application.

Use isolated fixtures for deterministic automated testing and bounded, read-only real-network checks for runtime acceptance.

Respect the previously approved CIDRs:
- `192.168.27.0/24`
- `192.168.22.0/24`

Do not perform credential guessing, intrusive probing, uncontrolled port scanning, or scans outside the approved ranges.

Test:

- Target is genuinely reachable.
- Target returns a timeout.
- Another host returns an ICMP error on behalf of the target.
- Destination is unreachable.
- DNS resolution fails or returns multiple results.
- ARP cache entries are stale, missing, or refer to a different observation.
- The scanner runs on a remote subnet without Layer 2 access.
- TCP connection is refused versus timed out.
- One probe throws unexpectedly while other targets remain processable.
- Partial discovery results are returned before cancellation.
- Multiple scans overlap.
- A scan finishes after the user has cancelled it.
- The network interface or route changes during discovery.
- No targets respond.
- Every target responds.
- The result set contains duplicates or conflicting IP/MAC/hostname evidence.
- A scanned device is already in the approved inventory.
- A known device changes IP, hostname, or observed MAC address.
- A discovered device is deleted and discovered again.
- Approval is retried after a timeout or service restart.
- Classification evidence is insufficient or contradictory.
- A scan is run twice against unchanged results.

Verify correct handling of network/broadcast addresses, scan bounds, concurrency limits, cancellation, timeouts, and partial failures.

Do not classify every responding IP as a PC or every MAC vendor as definitive proof of device type.

Never treat no response as proof that a device does not exist. Distinguish `unresponsive`, `unknown`, `unconfirmed`, and `confirmed down` according to the actual domain design.

For every real scan, report the actual interface, CIDR, attempted targets, confirmed responses, already-known targets, pending discoveries, duration, and errors. Do not invent results.

Do not insert test fixtures into the production inventory. Any approved runtime test that changes production data must be reversible and explicitly identified.

## F. Inventory and Discovery Approval Integrity

Verify complete end-to-end persistence of:

- Device identity.
- Name.
- IP address.
- MAC address where available.
- Category.
- Vendor and model.
- Owner.
- Department.
- Location.
- Monitoring enabled/disabled state.
- Created and updated timestamps.
- Discovery evidence and last-seen information.
- Incident associations and audit metadata where supported.

Test that approving a discovered device twice does not create duplicate authoritative records.

Test that repeated scans update technical observations without overwriting manually assigned business metadata.

Test that a device with monitoring disabled is not polled or incorrectly marked down.

Test category transitions, deletion, stale discovery records, missing owner/location fields, and concurrent edit/approval attempts.

Check that device counts across Inventory, Dashboard, Discovery, and Topology are consistent when those screens refer to the same authoritative population.

Do not demand equal counts where the underlying scopes legitimately differ. Define and verify each count's inclusion rules.

Do not allow a UI success toast if the actual save failed.

## G. Incident Engine and Alert Integrity

Verify actual incident creation, deduplication, recovery, and audit behavior.

Test:

- Repeated failures below and above the configured down threshold.
- Recovery below and above the success threshold.
- Intermittent loss that should not flap the device constantly.
- Sustained degradation and subsequent recovery.
- Multiple polling loops reporting the same failure.
- A device already having an open incident.
- Service restart during an active outage.
- Incident creation failing after the device state changes.
- Incident recovery failing after the device comes online.
- Simultaneous device incidents and upstream-device failure.
- Long-duration incidents, timestamps, and duration calculations.
- Clock discontinuities and invalid timestamps.
- Repeated notification/incident processing after a retry.

Ensure an error while processing one device does not prevent incidents for other devices from being evaluated.

Ensure recovered incidents are not left open indefinitely because one recovery write failed.

If alerts are not implemented, report them as not implemented. Do not label notification functionality complete because incidents exist.

## H. Topology and Wall Display

For Topology, verify:

- Every node maps to an actual authoritative asset or explicitly identified external node.
- Every edge has a valid relationship record or supported discovery evidence.
- No fictional links are introduced to improve the visual design.
- Missing interface information is handled honestly.
- Stale and unknown connections are clearly distinguished from verified links.
- Counts match the actual defined category scope.
- Branches remain stable during ordinary status updates.
- Large topologies do not overlap or silently hide nodes.
- Pan, zoom, fit-to-view, refresh, and full-screen operations work together.
- Compact layout calculations handle extreme branching, disconnected devices, duplicate identities, and missing roots.

For Wall Display, verify the real target resolution, card capacity, counters, status updates, and behavior with zero, one, and many devices. Do not claim all cards fit based only on a calculation if the rendered application was not inspected.

---

# PHASE 3 — VERIFY THAT DISPLAYED INFORMATION IS ACTUALLY TRUE

Audit every significant number and status shown on the Dashboard, Inventory, Discovery, Topology, Incidents, Reports, Infrastructure, and Wall Display.

For each displayed field, identify:

1. Its authoritative source.
2. How it is calculated or mapped.
3. Whether it can become stale.
4. How unavailable or invalid values are represented.
5. How the user can distinguish live observations from historical observations.

Explicitly investigate:

- Device online counts.
- Total inventory counts.
- Gateway, switch, AP, PC, laptop, and other category counts.
- Latency and last-known latency.
- Last-seen timestamps.
- Uptime and outage duration.
- Active and resolved incident counts.
- Discovery counts and classifications.
- Topology node/edge counts and parent-child relationships.
- Wall Display status colors.
- Service health and database health.

Requirements:

- Never display an old latency value as if it were the result of a failed current probe.
- Do not count a stale observation as a current success without explicitly defined freshness rules.
- Do not silently substitute zeros for an API/database failure.
- Distinguish a genuine zero from unknown, unavailable, stale, and error.
- Do not compute uptime from incomplete history without disclosing the limitation.
- Do not invent device types based only on suggestive names.
- Do not claim physical topology from ICMP reachability alone.
- Do not label cached values as live.
- Do not present predicted or estimated values as verified facts.
- Ensure all displayed counts have clearly defined inclusion and exclusion rules.

Add consistency tests across repositories, computed values, and widgets. Use independent expected results derived from known fixtures rather than reproducing the same production calculation in the test.

For runtime acceptance, sample actual application values and trace them to the underlying database/service response or network observation.

If a data source is missing, report the capability as limited or unavailable rather than fabricating data.

---

# PHASE 4 — DESTROY FRAGILE ERROR HANDLING

Inspect every asynchronous call, error boundary, exception handler, background worker, database operation, external process invocation, file operation, network request, and stream subscription.

Look specifically for:

- Empty catch blocks.
- Broad catch blocks that discard important exceptions.
- `catch` blocks returning fake successful values.
- `null` being converted into an incorrect default.
- Silent fallback to another database or demo dataset.
- Success notifications shown before persistence completes.
- Unawaited futures that can fail outside the intended error boundary.
- Unhandled exceptions in timers and stream listeners.
- Retry loops without limits or backoff.
- Unbounded concurrency.
- Missing timeouts.
- Incorrect cancellation behavior.
- Resources not disposed.
- Race conditions between refresh, navigation, and async completion.
- UI state updates after a Cubit/Widget is disposed.
- Stale data retained after an operation has actually failed.
- Duplicate actions caused by rapid repeated clicks.
- Missing loading, error, empty, stale, and retry states.
- Errors that are logged without enough contextual information to diagnose them.
- Secrets, private information, or tokens leaked into logs.

For each issue, implement the appropriate recovery behavior.

A failure should result in one of:
- A successful, verified recovery.
- A safely preserved previous state marked as stale where appropriate.
- An explicit unavailable/error state with a useful recovery action.
- A controlled shutdown or abort when continuing would risk data corruption.

Never convert a failure into fake data merely to keep the UI looking healthy.

Ensure diagnostics include useful context such as operation, device ID where safe, request/correlation ID, and underlying failure category. Redact credentials and sensitive payloads.

Test unexpected errors at the relevant boundary and verify that they do not crash unrelated modules.

Do not overfit tests to an exact English exception string. Validate the semantic behavior, safe state, data integrity, and observability.

---

# PHASE 5 — ELIMINATE BAD HARDCODING AND CLEAN UP THE CODEBASE

Audit the entire project for hardcoded values, duplicated business rules, large classes, oversized Widgets, unnecessary abstractions, and violations of the architecture actually used by this repository.

Search for:

- Hardcoded IP addresses, CIDRs, ports, URLs, file paths, and service endpoints.
- Magic timeout, retry, debounce, concurrency, polling, and threshold values.
- Duplicated status transition logic.
- Duplicated category mappings and display labels.
- Duplicated color rules and status-to-icon mappings.
- Hardcoded device counts or dashboard values.
- Sample/demo responses accidentally used in production.
- Device data or topology relationships embedded directly in UI code.
- Configuration values scattered across multiple files.
- Hardcoded installer and service paths that break after installation in another directory.
- UI dimensions that assume a single screen size.
- Embedded environment-specific assumptions.
- Repeated model mapping and parsing rules.
- Large methods, God Cubits, massive Widgets, and files mixing unrelated responsibilities.
- Duplicate repository implementations.
- Unnecessary dependencies and unused code.
- Obsolete routes, dead feature flags, abandoned implementations, and stale comments.
- TODO/FIXME markers representing unfinished production behavior.

Classify each hardcoded value instead of blindly replacing all literals.

Use appropriate constants or typed configuration for genuine policy and tuning values. Keep test fixtures in test code. Preserve legitimate defaults and intentional product decisions.

Do not turn every literal into a configurable setting merely to reduce search results.

Do not hide hardcoded data behind a wrapper that still returns the same fake values.

Do not introduce enormous configuration files or generic frameworks for trivial functionality.

Apply the existing feature-first structure and separate Presentation, Domain, and Data responsibilities where the current architecture calls for them.

Presentation should not execute SQL directly or contain core business algorithms.

Cubit/BLoC should not duplicate repository persistence or contain large parsing/layout algorithms.

The Data layer should correctly map storage and transport representations into domain entities.

Use descriptive names, small cohesive files, explicit types where beneficial, immutable domain models where appropriate, and predictable error handling.

Delete or simplify code only after proving it is unused and verifying there is no runtime dependency on it.

Do not perform a risky mass refactor without regression tests.

---

# PHASE 6 — RESPONSIVE WINDOWS UI AUDIT

The application must be usable at different window sizes, DPI scales, and text lengths.

Audit every implemented screen, not just the Dashboard or Topology.

Required test viewports include:

- 1024×768
- 1280×720
- 1366×768
- 1600×900
- 1920×1080
- A narrow, resized window approaching the smallest supported practical size.
- Windows display scaling at 100%, 125%, 150%, and 200% where the test environment supports it.

Also test live window resizing while a screen is open.

At each feasible viewport, inspect:

- Sidebar and navigation.
- Top bars and summary counters.
- Tables and device lists.
- Inventory filters and search controls.
- Dialogs and forms.
- Error banners and long messages.
- Discovery review screens.
- Topology node sizes and edge labels.
- Wall Display.
- Reports and export dialogs.
- Device detail panels.
- Settings and administration screens.

Test:

- Very long device names and hostnames.
- Long IP/metadata combinations.
- Arabic text, mixed Arabic/English, Unicode, and emoji.
- Empty, sparse, and very large datasets.
- Large numbers in counters.
- Multiple active incidents.
- Small available width and height.
- Keyboard focus and tab navigation where appropriate.
- Window resizing during async data loading.
- Zooming in the topology when the window is small.
- Scrolling long forms and data tables.
- Dialogs near viewport boundaries.

Find and fix:

- RenderFlex overflow.
- Clipped controls.
- Tiny unreadable text.
- Off-screen buttons.
- Overlapping cards.
- Dialogs larger than the available viewport.
- Unnecessary horizontal scrolling.
- Layout jumps during loading.
- Content hidden behind the Windows taskbar or fixed headers.
- Controls that disappear without an accessible alternative.

Use LayoutBuilder, constraints, scrollable layouts, flexible arrangements, adaptive breakpoints, and other suitable Flutter patterns. Do not solve every layout problem by shrinking fonts globally or using fixed percentages without considering minimum viable dimensions.

Respect the existing visual design and application theme. Responsiveness must improve layout without casually redesigning the entire product.

Create widget tests with multiple constraints and run screenshot/golden comparisons if the repository supports them. Follow up with actual rendered Windows screenshots at representative sizes.

A passing widget test alone does not prove Windows DPI scaling is correct. Clearly distinguish automated layout checks from actual Windows rendering verification.

---

# PHASE 7 — PERFORMANCE, CONCURRENCY, AND RESOURCE MANAGEMENT

Identify actual performance bottlenecks rather than prematurely optimizing arbitrary code.

Measure and test:

- Startup time and initialization dependencies.
- Time to first usable dashboard.
- Large inventory queries and filters.
- Repeated full-table reads.
- Expensive rebuilds caused by Cubit state emissions.
- Large topology layout calculations.
- Long lists without appropriate virtualization.
- Unnecessary network probes or duplicate timers.
- Excessive database writes and transaction contention.
- Excessive log volume.
- Retried operations that allocate unbounded resources.
- Memory and handle growth over repeated screen navigation.
- Background work continuing after application/service shutdown.

Use realistic synthetic test data for scale testing without placing test records into production.

Test realistic larger inventories and topologies, and report measured results, test machine/environment, and timing methodology.

Do not invent performance benchmarks or claim an improvement without measurement.

If a benchmark reveals a problem, optimize the actual bottleneck and add a regression benchmark or test where appropriate.

---

# PHASE 8 — SECURITY, OPERATING SYSTEM, AND DEPLOYMENT

Perform a pragmatic security review appropriate to a single-operator, no-login Windows application.

Preserve the no-interactive-login requirement.

Review:

- Actual service startup identity and lifecycle.
- Database location consistency between client and service.
- TLS configuration and certificate validation, where enabled.
- Service API exposure and local-client trust boundaries, where applicable.
- Sensitive material in configuration and logs.
- File path assumptions and path traversal opportunities.
- Unsafe process invocation and command-line parsing.
- SQL input handling and validation.
- Installer permissions and executable locations.
- Data backup and restore.
- Windows ACL dependencies.
- Service restart and crash recovery.
- Unintended production fallbacks to a different database.
- Dependency vulnerabilities using available local tooling.
- Production-versus-development configuration separation.

Do not run permission-changing scripts or security remediation against the user's installed production environment without explicit approval.

Build and validate the release artifacts separately from the existing installation. Do not silently claim that release installer behavior is verified merely because compilation succeeds.

If an issue depends on a real Windows machine, administrator access, certificates, or external providers, record the exact manual acceptance procedure and mark it pending until actually verified.

---

# PHASE 9 — TEST THE TESTS

Challenge the reliability of the test suite itself.

Look for:

- Tests that assert an implementation-specific detail without validating the actual requirement.
- Tests that duplicate production calculations as the expected result.
- Tests that only inspect mocked Cubit states and never verify persistence or runtime behavior.
- Tests with no meaningful assertions.
- Tests that pass when the implementation is bypassed.
- Shared global state that causes order-dependent results.
- Race-prone sleeps instead of deterministic synchronization.
- Tests that rely on the developer's current machine or local files.
- Golden tests that were regenerated to accept a regression without review.
- Incorrectly mocked network responses.
- Tests that do not clean up temporary files, processes, or database connections.
- Retry logic that is never tested past its first attempt.
- Exception handlers whose failure behavior is never asserted.
- Broad test coverage that still misses critical application flows.

Where practical, use mutation testing or controlled fault injection to prove that important tests fail when relevant behavior is deliberately broken. Do not claim mutation testing was performed if no mutation tool or equivalent controlled experiment was actually used.

Use independent fixtures and invariants to validate output.

Run tests independently where needed to identify shared-state problems. Verify that the suite is reproducible on a clean checkout and does not depend on a previous test run.

Do not weaken or delete a failing test just to achieve a green build. If an expectation was wrong, justify the correction against documented requirements and observable behavior.

---

# PHASE 10 — REQUIRED EXECUTION AND FIX CYCLE

Work in controlled, testable batches:

1. Establish the current baseline.
2. Inventory the actual code and feature flows.
3. Run existing checks without modifying behavior.
4. Reproduce and classify defects.
5. Fix critical correctness and data-integrity defects first.
6. Fix false data, stale values, service/database errors, and broken workflows.
7. Fix error handling, cancellation, concurrency, and resource leaks.
8. Refactor hardcoded behavior and poor code with regression protection.
9. Fix responsive UI defects.
10. Improve performance only where evidence supports it.
11. Re-run targeted tests after every logical change.
12. Run the complete regression suite.
13. Build the actual Windows release.
14. Verify the installed/runtime workflow where the environment permits.
15. Document outstanding failures and manual verification requirements.

Do not dump hundreds of changes into one untested commit or edit unrelated features simultaneously.

Prefer small coherent modifications with clear evidence. Preserve existing behavior unless a defect or approved requirement justifies changing it.

If the audit is too large to complete reliably in one pass, finish each logical batch, leave the project in a buildable state, and continue through the remaining modules. Do not label the whole system fully audited simply because the first batch is complete.

Do not stop after producing the initial matrix. Continue into implementation and verification.

---

# PHASE 11 — FINAL EVIDENCE AND COMPLETION GATE

Run every available relevant check against the actual current source tree.

At minimum, evaluate:

- `flutter pub get`
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- Full `flutter test`
- Test coverage collection and inspection
- Database migration and concurrency integration tests
- Relevant service/contract tests
- Windows compilation and release build
- Installer build, if available
- Responsive widget/layout tests
- Runtime/manual acceptance checks, where feasible

Do not fabricate a passing result. If a command fails, preserve its relevant output, investigate the reason, and fix the underlying defect when feasible.

Do not assume all commands exist in every workspace; verify project tooling before running optional commands.

Provide a completion report with:

## A. Overall Status
- Features audited versus total identified.
- Features fully verified.
- Features with confirmed defects fixed.
- Features partially verified.
- Features not implemented.
- Features still unverified because of environmental limitations.

## B. Defect Register
For each finding:
- Severity.
- Affected files/modules.
- Reproduction steps.
- Root cause.
- Fix.
- Regression test.
- Verification evidence.

## C. Data Correctness
Show how critical displayed counts, statuses, latency, timestamps, discovery results, and topology relationships were validated against actual authoritative data.

## D. Error and Adversarial Test Results
List the important unusual scenarios executed, the observable outcomes, and any remaining failure modes.

## E. Code Quality and Hardcoding
Report confirmed hardcoding removed or centralized, duplicate logic eliminated, obsolete code removed, architectural violations fixed, and issues intentionally retained.

## F. Responsive UI
Provide screenshots at representative supported sizes, identified overflow defects, and the validation performed. Do not claim screenshots exist unless generated and inspected.

## G. Test Results
Report actual command results, number of passing/failing/skipped tests, branch/line coverage where collected, and what the tests do not cover.

Do not treat a numerical coverage threshold as proof of correctness. Explain gaps in critical behavior even if overall coverage is high.

## H. Deployment and Runtime
Report service state, database path, startup behavior, persistence results, installer/build status, and required real-machine tests.

## I. Remaining Risks
List every important unresolved issue, missing capability, environmental blocker, and manual validation step.

Use only these overall statuses:
- **PASS**: required behavior was verified with appropriate evidence.
- **FAIL**: a defect was reproduced and remains unresolved.
- **PARTIAL**: some relevant paths were verified but the requirement is not fully covered.
- **UNVERIFIED**: insufficient evidence or unavailable environment.
- **NOT IMPLEMENTED**: required capability does not exist in the current application.

Never translate an unexecuted test into PASS. Never call a mocked result a real-network verification. Never claim full system readiness while critical defects or required runtime checks remain unresolved.

## FINAL INSTRUCTION

I am asking you to challenge the software, not to reassure me.

Find the unexpected cases. Expose the lies hidden by mock data, stale values, bad defaults, and shallow tests. Make the application robust without destroying its working architecture or production data.

Inspect first, reproduce issues, fix them, prove the fixes, and continue until every module has an honest status backed by evidence.

Do not invent findings, tests, performance results, device counts, screenshots, or runtime verification.

Do not stop with a plan. Execute the audit and fixes using the capabilities actually available in the current environment. When something cannot be verified from this environment, say exactly what is missing and provide the precise remaining validation procedure.

Preserve Decision 72 / Pattern 26 and the existing product requirements throughout the work.