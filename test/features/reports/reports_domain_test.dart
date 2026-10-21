import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/reports/domain/entities/report_entity.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  group('Reports Domain & Repository Unit Tests', () {
    test('ReportSummaryEntity properties and props equality', () {
      final now = DateTime.now();
      final summary = ReportSummaryEntity(
        period: ReportPeriod.last24Hours,
        startDate: now.subtract(const Duration(hours: 24)),
        endDate: now,
        totalDevices: 37,
        overallAvailabilityPercent: 99.5,
        totalCheckCount: 100,
        successfulCheckCount: 99,
        failedCheckCount: 1,
        avgLatencyMs: 12.4,
        totalIncidents: 1,
        deviceUptimes: const [],
      );

      expect(summary.totalDevices, equals(37));
      expect(summary.overallAvailabilityPercent, equals(99.5));
      expect(summary.period, equals(ReportPeriod.last24Hours));
    });

    test('DeviceUptimeEntity calculation properties', () {
      const dev = DeviceUptimeEntity(
        deviceId: 1,
        deviceName: 'PC-FIN-01',
        ownerName: 'Ahmed Hassan',
        department: 'Finance',
        ip: '192.168.1.10',
        uptimePercent: 100.0,
        totalChecks: 50,
        successfulChecks: 50,
        failedChecks: 0,
        avgLatencyMs: 5.2,
      );

      expect(dev.deviceId, equals(1));
      expect(dev.uptimePercent, equals(100.0));
      expect(dev.failedChecks, equals(0));
    });
  });
}
