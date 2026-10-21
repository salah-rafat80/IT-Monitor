import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/reports/data/repositories/report_repository_impl.dart';
import 'package:it_network_monitor/features/reports/domain/entities/report_entity.dart';

void main() {
  late AppDatabase db;
  late ReportRepositoryImpl reportRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reportRepo = ReportRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ReportRepositoryImpl Unit & Forensic Tests', () {
    test(
      '1. Aggregates both inventory and infrastructure with overlapping IDs without collision',
      () async {
        final now = DateTime.now();

        // Insert 1 inventory device (ID will be 1)
        final devId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-FINANCE-01',
                type: const Value('pc'),
                ip: '192.168.1.100',
                ownerName: 'Finance User',
                department: 'Finance',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(days: 2))),
              ),
            );

        // Insert 1 infrastructure device (ID will ALSO be 1 in its table!)
        final infraId = await db
            .into(db.infrastructureDevices)
            .insert(
              InfrastructureDevicesCompanion.insert(
                name: 'UniFi Gateway Pro',
                role: const Value('Primary Gateway'),
                ip: '192.168.1.1',
                isEnabled: const Value(true),
                createdAt: Value(now.subtract(const Duration(days: 2))),
              ),
            );

        expect(devId, equals(1));
        expect(infraId, equals(1)); // Intentionally overlapping database PKs

        // Insert check results for inventory device: 4 checks (3 success, 1 failure => 75% uptime)
        for (int i = 0; i < 3; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: const Value('device:1'),
                  deviceId: devId,
                  targetIp: '192.168.1.100',
                  timestamp: Value(
                    now.subtract(Duration(minutes: 10 * (i + 1))),
                  ),
                  isSuccess: true,
                  latencyMs: const Value(10),
                ),
              );
        }
        await db
            .into(db.checkResults)
            .insert(
              CheckResultsCompanion.insert(
                assetId: const Value('device:1'),
                deviceId: devId,
                targetIp: '192.168.1.100',
                timestamp: Value(now.subtract(const Duration(minutes: 5))),
                isSuccess: false,
                errorMessage: const Value('Request timed out'),
              ),
            );

        // Insert check results for infrastructure device: 2 checks (2 success => 100% uptime)
        for (int i = 0; i < 2; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: const Value('infra:1'),
                  deviceId: infraId,
                  targetIp: '192.168.1.1',
                  timestamp: Value(
                    now.subtract(Duration(minutes: 8 * (i + 1))),
                  ),
                  isSuccess: true,
                  latencyMs: const Value(2),
                ),
              );
        }

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        // Total checks = 4 (inventory) + 2 (infra) = 6. Success = 5.
        expect(summary.totalCheckCount, equals(6));
        expect(summary.successfulCheckCount, equals(5));
        expect(summary.failedCheckCount, equals(1));
        expect(
          summary.overallAvailabilityPercent,
          closeTo((5 / 6) * 100.0, 0.01),
        );

        // Both devices must be present with collision-free composite assetIds
        expect(summary.deviceUptimes.length, equals(2));

        final inventoryUptime = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:1',
        );
        expect(inventoryUptime.deviceId, equals(1));
        expect(inventoryUptime.assetType, equals('inventory'));
        expect(inventoryUptime.deviceName, equals('PC-FINANCE-01'));
        expect(inventoryUptime.uptimePercent, equals(75.0));
        expect(inventoryUptime.totalChecks, equals(4));
        expect(inventoryUptime.successfulChecks, equals(3));
        expect(inventoryUptime.failedChecks, equals(1));
        expect(inventoryUptime.hasSufficientHistory, isTrue);

        final infraUptime = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'infra:1',
        );
        expect(infraUptime.deviceId, equals(1));
        expect(infraUptime.assetType, equals('infrastructure'));
        expect(infraUptime.deviceName, equals('UniFi Gateway Pro'));
        expect(infraUptime.uptimePercent, equals(100.0));
        expect(infraUptime.totalChecks, equals(2));
        expect(infraUptime.successfulChecks, equals(2));
        expect(infraUptime.failedChecks, equals(0));
        expect(infraUptime.hasSufficientHistory, isTrue);
      },
    );

    test(
      '2. Unmonitored devices and devices with 0 checks yield null uptime and false sufficient history',
      () async {
        final now = DateTime.now();

        // Device with 0 checks
        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-NEW-NO-CHECKS',
                type: const Value('pc'),
                ip: '192.168.1.150',
                ownerName: 'New User',
                department: 'Sales',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now),
              ),
            );

        // Unmonitored device
        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-UNMONITORED',
                type: const Value('pc'),
                ip: '192.168.1.151',
                ownerName: 'Guest User',
                department: 'Guest',
                isEnabled: const Value(true),
                isMonitored: const Value(false),
                createdAt: Value(now),
              ),
            );

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        // Unmonitored device must NOT be in the report
        expect(
          summary.deviceUptimes.any((d) => d.deviceName == 'PC-UNMONITORED'),
          isFalse,
        );

        // Device with 0 checks must be present but NOT report 0% or 100% availability
        final dev = summary.deviceUptimes.firstWhere(
          (d) => d.deviceName == 'PC-NEW-NO-CHECKS',
        );
        expect(dev.totalChecks, equals(0));
        expect(dev.uptimePercent, isNull);
        expect(dev.hasSufficientHistory, isFalse);
        // Overall availability must be null because no devices have sufficient history
        expect(summary.overallAvailabilityPercent, isNull);
      },
    );

    test(
      '3. Zero monitored devices / zero checks does not divide by zero and returns null overall availability',
      () async {
        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        expect(summary.totalDevices, equals(0));
        expect(summary.totalCheckCount, equals(0));
        expect(summary.overallAvailabilityPercent, isNull);
      },
    );

    test(
      '4. IP reassignment over time does not falsely attribute old checks to new device',
      () async {
        final now = DateTime.now();

        // Device A (id: 1) was created 5 days ago with IP 192.168.1.50
        final devAId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-OLD-DEV-A',
                type: const Value('pc'),
                ip: '192.168.1.50',
                ownerName: 'Old User A',
                department: 'HR',
                isEnabled: const Value(false), // Retired/disabled
                isMonitored: const Value(false),
                createdAt: Value(now.subtract(const Duration(days: 5))),
              ),
            );

        // Generate 10 failed checks for Device A on IP 192.168.1.50
        for (int i = 0; i < 10; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devAId'),
                  deviceId: devAId,
                  targetIp: '192.168.1.50',
                  timestamp: Value(now.subtract(Duration(hours: 12 + i))),
                  isSuccess: false,
                  errorMessage: const Value('Host unreachable'),
                ),
              );
        }

        // Reassign Device A to another IP or retired IP so IP 192.168.1.50 becomes available
        await (db.update(db.devices)..where((d) => d.id.equals(devAId))).write(
          const DevicesCompanion(
            ip: Value('192.168.1.199'),
            isEnabled: Value(false),
            isMonitored: Value(false),
          ),
        );

        // Device B (id: 2) is created 2 hours ago and gets assigned the vacated IP 192.168.1.50
        final devBId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-NEW-DEV-B',
                type: const Value('pc'),
                ip: '192.168.1.50',
                ownerName: 'New User B',
                department: 'HR',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(hours: 2))),
              ),
            );

        // Generate 2 successful checks for Device B
        for (int i = 0; i < 2; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devBId'),
                  deviceId: devBId,
                  targetIp: '192.168.1.50',
                  timestamp: Value(
                    now.subtract(Duration(minutes: 15 * (i + 1))),
                  ),
                  isSuccess: true,
                  latencyMs: const Value(5),
                ),
              );
        }

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        // Device B should be in the report
        final devBReport = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:$devBId',
        );

        // CRITICAL ADVERSARIAL ASSERTION:
        // Device B must have EXACTLY 2 checks and 100.0% uptime.
        // It must NOT inherit Device A's 10 failed checks!
        expect(devBReport.totalChecks, equals(2));
        expect(devBReport.successfulChecks, equals(2));
        expect(devBReport.failedChecks, equals(0));
        expect(devBReport.uptimePercent, equals(100.0));
      },
    );

    test(
      '5. Ambiguous legacy check records without valid asset identity are not attributed',
      () async {
        final now = DateTime.now();

        final devId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-AUDIT-01',
                type: const Value('pc'),
                ip: '192.168.1.99',
                ownerName: 'Audit User',
                department: 'Audit',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(hours: 1))),
              ),
            );

        // Insert legacy ambiguous check with matching targetIp but deviceId: 0 and null assetId
        await db
            .into(db.checkResults)
            .insert(
              CheckResultsCompanion.insert(
                deviceId: 0,
                targetIp: '192.168.1.99',
                timestamp: Value(now.subtract(const Duration(minutes: 30))),
                isSuccess: false,
                errorMessage: const Value('Unattributed legacy probe'),
              ),
            );

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        final devReport = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:$devId',
        );

        // Ambiguous check must NOT be attributed to PC-AUDIT-01
        expect(devReport.totalChecks, equals(0));
        expect(devReport.uptimePercent, isNull);
        expect(devReport.hasSufficientHistory, isFalse);
      },
    );

    test(
      '6. All-success vs all-failure checks accurately reflect 100.0% and 0.0%',
      () async {
        final now = DateTime.now();

        // 100% Up Device
        final devUpId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-ALL-UP',
                type: const Value('pc'),
                ip: '192.168.1.201',
                ownerName: 'Up User',
                department: 'Ops',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(days: 1))),
              ),
            );
        for (int i = 0; i < 5; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devUpId'),
                  deviceId: devUpId,
                  targetIp: '192.168.1.201',
                  timestamp: Value(now.subtract(Duration(minutes: i + 1))),
                  isSuccess: true,
                  latencyMs: const Value(4),
                ),
              );
        }

        // 0% Up Device (All Failures)
        final devDownId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-ALL-DOWN',
                type: const Value('pc'),
                ip: '192.168.1.202',
                ownerName: 'Down User',
                department: 'Ops',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(days: 1))),
              ),
            );
        for (int i = 0; i < 5; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devDownId'),
                  deviceId: devDownId,
                  targetIp: '192.168.1.202',
                  timestamp: Value(now.subtract(Duration(minutes: i + 1))),
                  isSuccess: false,
                  errorMessage: const Value('Timeout'),
                ),
              );
        }

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        final upDev = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:$devUpId',
        );
        final downDev = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:$devDownId',
        );

        expect(upDev.uptimePercent, equals(100.0));
        expect(downDev.uptimePercent, equals(0.0));
        // Total across both: 5 successes out of 10 checks = 50.0%
        expect(summary.overallAvailabilityPercent, equals(50.0));
      },
    );

    test(
      '7. Export to CSV handles both valid and null uptime values cleanly',
      () async {
        final now = DateTime.now();

        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-CSV-01',
                type: const Value('pc'),
                ip: '192.168.1.200',
                ownerName: 'CSV Owner',
                department: 'Finance',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now),
              ),
            );

        final reportRes = await reportRepo.generateReport(
          ReportPeriod.last24Hours,
        );
        expect(reportRes.isSuccess, isTrue);

        final tempDir = await Directory.systemTemp.createTemp('report_test_');
        final exportRes = await reportRepo.exportReportToCsv(
          reportRes.dataOrNull!,
          tempDir.path,
        );
        expect(exportRes.isSuccess, isTrue);

        final csvFile = File(exportRes.dataOrNull!);
        expect(csvFile.existsSync(), isTrue);

        final csvContent = await csvFile.readAsString();
        expect(
          csvContent,
          contains('Overall Network Availability,N/A (Insufficient Data)'),
        );
        expect(
          csvContent,
          contains(',N/A,0,0,0,0.0,Insufficient / No Checks in Period'),
        );

        tempDir.deleteSync(recursive: true);
      },
    );

    test(
      '8. Two successful checks separated by a long unobserved interval (>2h) yield null uptime and false sufficient history',
      () async {
        final now = DateTime.now();

        final devId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-SPARSE-PROBES',
                type: const Value('pc'),
                ip: '192.168.1.180',
                ownerName: 'Sparse User',
                department: 'Marketing',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(days: 1))),
              ),
            );

        // Check 1: 18 hours ago
        await db
            .into(db.checkResults)
            .insert(
              CheckResultsCompanion.insert(
                assetId: Value('device:$devId'),
                deviceId: devId,
                targetIp: '192.168.1.180',
                timestamp: Value(now.subtract(const Duration(hours: 18))),
                isSuccess: true,
                latencyMs: const Value(5),
              ),
            );

        // Check 2: 1 hour ago (17-hour gap!)
        await db
            .into(db.checkResults)
            .insert(
              CheckResultsCompanion.insert(
                assetId: Value('device:$devId'),
                deviceId: devId,
                targetIp: '192.168.1.180',
                timestamp: Value(now.subtract(const Duration(hours: 1))),
                isSuccess: true,
                latencyMs: const Value(6),
              ),
            );

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        final devReport = summary.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:$devId',
        );

        // Even though both checks succeeded (100% of samples), the 17-hour unobserved gap
        // forbids claiming continuous availability over the 24-hour period!
        expect(devReport.totalChecks, equals(2));
        expect(devReport.successfulChecks, equals(2));
        expect(devReport.hasSufficientHistory, isFalse);
        expect(devReport.uptimePercent, isNull);
        // Overall availability ignores insufficient history
        expect(summary.overallAvailabilityPercent, isNull);
      },
    );

    test(
      '9. Service shutdown during reporting window produces unobserved gap, safely rendered as N/A in CSV',
      () async {
        final now = DateTime.now();

        final devId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-OUTAGE-GAP',
                type: const Value('pc'),
                ip: '192.168.1.181',
                ownerName: 'Outage User',
                department: 'Marketing',
                isEnabled: const Value(true),
                isMonitored: const Value(true),
                createdAt: Value(now.subtract(const Duration(days: 1))),
              ),
            );

        // Checks before monitoring service shutdown
        for (int i = 0; i < 3; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devId'),
                  deviceId: devId,
                  targetIp: '192.168.1.181',
                  timestamp: Value(
                    now.subtract(Duration(hours: 15, minutes: i * 5)),
                  ),
                  isSuccess: true,
                  latencyMs: const Value(8),
                ),
              );
        }

        // Monitoring service was shut down for 10 hours, then restarted
        for (int i = 0; i < 3; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devId'),
                  deviceId: devId,
                  targetIp: '192.168.1.181',
                  timestamp: Value(
                    now.subtract(Duration(hours: 1, minutes: i * 5)),
                  ),
                  isSuccess: true,
                  latencyMs: const Value(8),
                ),
              );
        }

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final devReport = res.dataOrNull!.deviceUptimes.firstWhere(
          (d) => d.assetId == 'device:$devId',
        );

        expect(devReport.totalChecks, equals(6));
        expect(devReport.hasSufficientHistory, isFalse);
        expect(devReport.uptimePercent, isNull);

        final tempDir = await Directory.systemTemp.createTemp(
          'report_gap_test_',
        );
        final exportRes = await reportRepo.exportReportToCsv(
          res.dataOrNull!,
          tempDir.path,
        );
        expect(exportRes.isSuccess, isTrue);
        final csvContent = await File(exportRes.dataOrNull!).readAsString();
        expect(
          csvContent,
          contains('Insufficient / Prolonged Monitoring Gap (>2h)'),
        );
        tempDir.deleteSync(recursive: true);
      },
    );

    test(
      '10. Device with monitoring disabled partway through a period does not appear in active monitored list',
      () async {
        final now = DateTime.now();

        final devId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-DISABLED-MIDPERIOD',
                type: const Value('pc'),
                ip: '192.168.1.182',
                ownerName: 'Disabled User',
                department: 'Finance',
                isEnabled: const Value(true),
                isMonitored: const Value(false), // Monitored was turned off
                createdAt: Value(now.subtract(const Duration(days: 3))),
              ),
            );

        // Historical checks while it was monitored
        for (int i = 0; i < 5; i++) {
          await db
              .into(db.checkResults)
              .insert(
                CheckResultsCompanion.insert(
                  assetId: Value('device:$devId'),
                  deviceId: devId,
                  targetIp: '192.168.1.182',
                  timestamp: Value(
                    now.subtract(Duration(hours: 10, minutes: i * 5)),
                  ),
                  isSuccess: true,
                  latencyMs: const Value(12),
                ),
              );
        }

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        // Must not be included in active device uptimes because isMonitored == false
        expect(
          summary.deviceUptimes.any((d) => d.assetId == 'device:$devId'),
          isFalse,
        );
      },
    );

    test(
      '11. Incident spanning report boundary is accurately counted in totalIncidents',
      () async {
        final now = DateTime.now();

        // Incident A: started 2 days ago (before startDate), resolved 5 hours ago (inside window) -> SPANS BOUNDARY
        await db
            .into(db.incidents)
            .insert(
              IncidentsCompanion.insert(
                deviceId: 1,
                deviceName: 'PC-BOUNDARY-1',
                ownerName: 'Owner 1',
                department: 'IT',
                deviceIp: '192.168.1.5',
                incidentType: 'device_down',
                status: const Value('resolved'),
                startedAt: Value(now.subtract(const Duration(days: 2))),
                resolvedAt: Value(now.subtract(const Duration(hours: 5))),
              ),
            );

        // Incident B: started 3 days ago, STILL UNRESOLVED (active now) -> SPANS BOUNDARY
        await db
            .into(db.incidents)
            .insert(
              IncidentsCompanion.insert(
                deviceId: 2,
                deviceName: 'PC-BOUNDARY-2',
                ownerName: 'Owner 2',
                department: 'IT',
                deviceIp: '192.168.1.6',
                incidentType: 'high_latency',
                status: const Value('active'),
                startedAt: Value(now.subtract(const Duration(days: 3))),
                resolvedAt: const Value(null),
              ),
            );

        // Incident C: started 5 days ago, resolved 3 days ago (COMPLETELY BEFORE WINDOW) -> EXCLUDED
        await db
            .into(db.incidents)
            .insert(
              IncidentsCompanion.insert(
                deviceId: 3,
                deviceName: 'PC-OLD-INCIDENT',
                ownerName: 'Owner 3',
                department: 'IT',
                deviceIp: '192.168.1.7',
                incidentType: 'device_down',
                status: const Value('resolved'),
                startedAt: Value(now.subtract(const Duration(days: 5))),
                resolvedAt: Value(now.subtract(const Duration(days: 3))),
              ),
            );

        // Incident D: started 2 hours ago (INSIDE WINDOW) -> INCLUDED
        await db
            .into(db.incidents)
            .insert(
              IncidentsCompanion.insert(
                deviceId: 4,
                deviceName: 'PC-NEW-INCIDENT',
                ownerName: 'Owner 4',
                department: 'IT',
                deviceIp: '192.168.1.8',
                incidentType: 'device_down',
                status: const Value('active'),
                startedAt: Value(now.subtract(const Duration(hours: 2))),
              ),
            );

        final res = await reportRepo.generateReport(ReportPeriod.last24Hours);
        expect(res.isSuccess, isTrue);

        final summary = res.dataOrNull!;
        // Exactly 3 incidents were active during [startDate, now]: Incident A, B, and D!
        // Incident C was completely outside the window.
        expect(summary.totalIncidents, equals(3));
      },
    );
  });
}
