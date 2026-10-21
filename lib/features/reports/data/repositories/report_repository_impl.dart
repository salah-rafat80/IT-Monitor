import 'dart:io';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';

@LazySingleton(as: ReportRepository)
class ReportRepositoryImpl implements ReportRepository {
  final AppDatabase _db;

  ReportRepositoryImpl(this._db);

  /// Sanitizes text fields for RFC 4180 CSV compliance and neutralizes
  /// spreadsheet formula injection (CSV/DDE injection) on leading characters (=, +, -, @, \t).
  static String escapeCsvField(String? value) {
    if (value == null) return '';
    String sanitized = value;

    // Neutralize formula injection if leading character could be interpreted as a formula
    if (sanitized.isNotEmpty &&
        (sanitized.startsWith('=') ||
            sanitized.startsWith('+') ||
            sanitized.startsWith('-') ||
            sanitized.startsWith('@') ||
            sanitized.startsWith('\t'))) {
      sanitized = "'$sanitized";
    }

    // RFC 4180: if field contains quote, comma, carriage return, or newline,
    // enclose in double quotes and escape internal double quotes by doubling them.
    if (sanitized.contains('"') ||
        sanitized.contains(',') ||
        sanitized.contains('\n') ||
        sanitized.contains('\r')) {
      return '"${sanitized.replaceAll('"', '""')}"';
    }
    return sanitized;
  }

  @override
  Future<Result<ReportSummaryEntity>> generateReport(
    ReportPeriod period,
  ) async {
    try {
      final now = DateTime.now();
      late DateTime startDate;

      switch (period) {
        case ReportPeriod.last24Hours:
          startDate = now.subtract(const Duration(hours: 24));
          break;
        case ReportPeriod.last7Days:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case ReportPeriod.last30Days:
          startDate = now.subtract(const Duration(days: 30));
          break;
      }

      final devices =
          await (_db.select(_db.devices)..where(
                (d) => d.isEnabled.equals(true) & d.isMonitored.equals(true),
              ))
              .get();
      final infraDevices = await (_db.select(
        _db.infrastructureDevices,
      )..where((d) => d.isEnabled.equals(true))).get();

      // Exclude future-dated check results and checks before startDate
      final checkResults =
          await (_db.select(_db.checkResults)..where(
                (c) =>
                    c.timestamp.isBiggerOrEqualValue(startDate) &
                    c.timestamp.isSmallerOrEqualValue(now),
              ))
              .get();

      final incidents =
          await (_db.select(_db.incidents)..where(
                (i) =>
                    i.startedAt.isSmallerOrEqualValue(now) &
                    (i.resolvedAt.isNull() |
                        i.resolvedAt.isBiggerOrEqualValue(startDate)),
              ))
              .get();

      int totalCheckCount = checkResults.length;
      int successfulCheckCount = checkResults.where((c) => c.isSuccess).length;
      int failedCheckCount = totalCheckCount - successfulCheckCount;

      final latencies = checkResults
          .where((c) => c.isSuccess && c.latencyMs != null)
          .map((c) => c.latencyMs!)
          .toList();

      final double? avgLatency = latencies.isNotEmpty
          ? double.parse(
              (latencies.reduce((a, b) => a + b) / latencies.length)
                  .toStringAsFixed(1),
            )
          : null;

      final deviceUptimes = <DeviceUptimeEntity>[];

      // 1. Process Monitored Inventory Devices using stable asset identity & temporal validity
      for (final dev in devices) {
        // Expected beginning of the monitoring window:
        // If device was created after startDate, monitoring could not have started earlier than dev.createdAt
        final expectedStart = dev.createdAt.isAfter(startDate)
            ? dev.createdAt
            : startDate;

        // Filter checks strictly within [expectedStart, now]
        final devChecks = checkResults.where((c) {
          if (c.timestamp.isBefore(expectedStart) || c.timestamp.isAfter(now)) {
            return false;
          }
          if (c.assetId != null && c.assetId!.isNotEmpty) {
            return c.assetId == 'device:${dev.id}';
          }
          if (c.deviceId == dev.id) {
            return c.targetIp.trim().toLowerCase() ==
                dev.ip.trim().toLowerCase();
          }
          return false;
        }).toList();

        // Sort chronologically to detect missing observation intervals
        devChecks.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        bool hasProlongedGap = false;
        if (devChecks.isEmpty) {
          hasProlongedGap = true;
        } else {
          // Check initial gap: between expectedStart and first valid observation
          if (devChecks.first.timestamp.difference(expectedStart) >
              const Duration(hours: 2)) {
            hasProlongedGap = true;
          }
          // Check consecutive gaps: between adjacent observations
          if (!hasProlongedGap) {
            for (int i = 1; i < devChecks.length; i++) {
              if (devChecks[i].timestamp.difference(
                    devChecks[i - 1].timestamp,
                  ) >
                  const Duration(hours: 2)) {
                hasProlongedGap = true;
                break;
              }
            }
          }
          // Check final gap: between last valid observation and report end time (now)
          if (!hasProlongedGap) {
            if (now.difference(devChecks.last.timestamp) >
                const Duration(hours: 2)) {
              hasProlongedGap = true;
            }
          }
        }

        final devTotal = devChecks.length;
        final devSuccess = devChecks.where((c) => c.isSuccess).length;
        final devFailed = devTotal - devSuccess;

        final bool hasSufficient = devTotal > 0 && !hasProlongedGap;

        // Honest reachability semantics:
        // Lack of checks or unobserved intervals (> 2h) prevents continuous availability claims.
        final double? devUptime = hasSufficient
            ? double.parse(((devSuccess / devTotal) * 100.0).toStringAsFixed(2))
            : null;

        final devLatencies = devChecks
            .where((c) => c.isSuccess && c.latencyMs != null)
            .map((c) => c.latencyMs!)
            .toList();

        final double? devAvgLatency = devLatencies.isNotEmpty
            ? double.parse(
                (devLatencies.reduce((a, b) => a + b) / devLatencies.length)
                    .toStringAsFixed(1),
              )
            : null;

        deviceUptimes.add(
          DeviceUptimeEntity(
            assetId: 'device:${dev.id}',
            deviceId: dev.id,
            assetType: 'inventory',
            deviceName: dev.name,
            ownerName: dev.ownerName,
            department: dev.department,
            ip: dev.ip,
            uptimePercent: devUptime,
            totalChecks: devTotal,
            successfulChecks: devSuccess,
            failedChecks: devFailed,
            avgLatencyMs: devAvgLatency,
            hasSufficientHistory: hasSufficient,
          ),
        );
      }

      // 2. Process Critical Infrastructure Assets (Gateways & APs)
      for (final infra in infraDevices) {
        final expectedStart = infra.createdAt.isAfter(startDate)
            ? infra.createdAt
            : startDate;

        final devChecks = checkResults.where((c) {
          if (c.timestamp.isBefore(expectedStart) || c.timestamp.isAfter(now)) {
            return false;
          }
          if (c.assetId != null && c.assetId!.isNotEmpty) {
            return c.assetId == 'infra:${infra.id}';
          }
          final isLegacyMatch =
              c.deviceId == infra.id || c.deviceId == 10000 + infra.id;
          if (isLegacyMatch) {
            return c.targetIp.trim().toLowerCase() ==
                infra.ip.trim().toLowerCase();
          }
          return false;
        }).toList();

        // Sort chronologically to detect prolonged monitoring gaps
        devChecks.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        bool hasProlongedGap = false;
        if (devChecks.isEmpty) {
          hasProlongedGap = true;
        } else {
          // Check initial gap
          if (devChecks.first.timestamp.difference(expectedStart) >
              const Duration(hours: 2)) {
            hasProlongedGap = true;
          }
          // Check consecutive gaps
          if (!hasProlongedGap) {
            for (int i = 1; i < devChecks.length; i++) {
              if (devChecks[i].timestamp.difference(
                    devChecks[i - 1].timestamp,
                  ) >
                  const Duration(hours: 2)) {
                hasProlongedGap = true;
                break;
              }
            }
          }
          // Check final gap
          if (!hasProlongedGap) {
            if (now.difference(devChecks.last.timestamp) >
                const Duration(hours: 2)) {
              hasProlongedGap = true;
            }
          }
        }

        final devTotal = devChecks.length;
        final devSuccess = devChecks.where((c) => c.isSuccess).length;
        final devFailed = devTotal - devSuccess;

        final bool hasSufficient = devTotal > 0 && !hasProlongedGap;

        final double? devUptime = hasSufficient
            ? double.parse(((devSuccess / devTotal) * 100.0).toStringAsFixed(2))
            : null;

        final devLatencies = devChecks
            .where((c) => c.isSuccess && c.latencyMs != null)
            .map((c) => c.latencyMs!)
            .toList();

        final double? devAvgLatency = devLatencies.isNotEmpty
            ? double.parse(
                (devLatencies.reduce((a, b) => a + b) / devLatencies.length)
                    .toStringAsFixed(1),
              )
            : null;

        deviceUptimes.add(
          DeviceUptimeEntity(
            assetId: 'infra:${infra.id}',
            deviceId: infra.id,
            assetType: 'infrastructure',
            deviceName: infra.name,
            ownerName: 'Infrastructure (${infra.role})',
            department: 'Network Infrastructure',
            ip: infra.ip,
            uptimePercent: devUptime,
            totalChecks: devTotal,
            successfulChecks: devSuccess,
            failedChecks: devFailed,
            avgLatencyMs: devAvgLatency,
            hasSufficientHistory: hasSufficient,
          ),
        );
      }

      // Sort by lowest uptime first to highlight degraded devices; null uptimes placed last
      deviceUptimes.sort((a, b) {
        if (a.uptimePercent == null && b.uptimePercent == null) return 0;
        if (a.uptimePercent == null) return 1;
        if (b.uptimePercent == null) return -1;
        return a.uptimePercent!.compareTo(b.uptimePercent!);
      });

      // Aggregate availability: average only over assets with sufficient history
      final devicesWithHistory = deviceUptimes
          .where((d) => d.hasSufficientHistory && d.uptimePercent != null)
          .toList();
      double? overallAvailability;
      if (devicesWithHistory.isNotEmpty) {
        final sumChecks = devicesWithHistory.fold<int>(
          0,
          (sum, d) => sum + d.totalChecks,
        );
        final sumSuccess = devicesWithHistory.fold<int>(
          0,
          (sum, d) => sum + d.successfulChecks,
        );
        if (sumChecks > 0) {
          overallAvailability = double.parse(
            ((sumSuccess / sumChecks) * 100.0).toStringAsFixed(2),
          );
        }
      }

      final summary = ReportSummaryEntity(
        period: period,
        startDate: startDate,
        endDate: now,
        totalDevices: devices.length + infraDevices.length,
        overallAvailabilityPercent: overallAvailability,
        totalCheckCount: totalCheckCount,
        successfulCheckCount: successfulCheckCount,
        failedCheckCount: failedCheckCount,
        avgLatencyMs: avgLatency,
        totalIncidents: incidents.length,
        deviceUptimes: deviceUptimes,
      );

      return Result.success(summary);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to generate report: $e'));
    }
  }

  @override
  Future<Result<String>> exportReportToCsv(
    ReportSummaryEntity report, [
    String? outputDirectoryPath,
  ]) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('IT NETWORK MONITOR - AVAILABILITY REPORT');
      buffer.writeln('Period,${escapeCsvField(report.period.name)}');
      buffer.writeln('Start Date,${report.startDate.toIso8601String()}');
      buffer.writeln('End Date,${report.endDate.toIso8601String()}');
      buffer.writeln('Total Devices,${report.totalDevices}');
      buffer.writeln(
        'Overall Network Availability,${report.overallAvailabilityPercent != null ? '${report.overallAvailabilityPercent}%' : 'N/A (Insufficient Data)'}',
      );
      buffer.writeln('Total Checks,${report.totalCheckCount}');
      buffer.writeln('Successful Checks,${report.successfulCheckCount}');
      buffer.writeln('Failed Checks,${report.failedCheckCount}');
      buffer.writeln(
        'Average Latency,${report.avgLatencyMs != null ? '${report.avgLatencyMs} ms' : 'N/A'}',
      );
      buffer.writeln('Total Incidents,${report.totalIncidents}');
      buffer.writeln();
      buffer.writeln(
        'Asset ID,Asset Type,Device Name,Owner Name,Department,IP Address,Availability %,Total Checks,Successful,Failed,Avg Latency (ms),History Status',
      );

      for (final d in report.deviceUptimes) {
        final uptimeStr = d.uptimePercent != null
            ? '${d.uptimePercent}%'
            : 'N/A';
        final latencyStr = d.avgLatencyMs != null
            ? d.avgLatencyMs.toString()
            : 'N/A';
        final histStatus = d.hasSufficientHistory && d.uptimePercent != null
            ? 'Sufficient'
            : (d.totalChecks == 0
                  ? 'Insufficient / No Checks in Period'
                  : 'Insufficient / Prolonged Monitoring Gap (>2h)');
        buffer.writeln(
          '${escapeCsvField(d.assetId)},${escapeCsvField(d.assetType)},${escapeCsvField(d.deviceName)},${escapeCsvField(d.ownerName)},${escapeCsvField(d.department)},${escapeCsvField(d.ip)},$uptimeStr,${d.totalChecks},${d.successfulChecks},${d.failedChecks},$latencyStr,${escapeCsvField(histStatus)}',
        );
      }

      Directory targetDir;
      if (outputDirectoryPath != null &&
          outputDirectoryPath.trim().isNotEmpty) {
        targetDir = Directory(outputDirectoryPath.trim());
      } else {
        try {
          targetDir =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
        } catch (_) {
          targetDir = Directory.systemTemp;
        }
      }

      if (!targetDir.existsSync()) {
        try {
          targetDir.createSync(recursive: true);
        } catch (_) {
          targetDir = Directory.systemTemp;
        }
      }

      final filePath =
          '${targetDir.path}/IT_Network_Monitor_Report_${DateTime.now().millisecondsSinceEpoch}.csv';

      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      return Result.success(filePath);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to export report CSV: $e'));
    }
  }

  @override
  Future<Result<int>> purgeCheckResultsOlderThanDays(int days) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final count = await (_db.delete(
        _db.checkResults,
      )..where((c) => c.timestamp.isSmallerThanValue(cutoffDate))).go();

      return Result.success(count);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to purge historical check results: $e'),
      );
    }
  }
}
