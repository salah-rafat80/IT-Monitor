import 'package:equatable/equatable.dart';

enum ReportPeriod { last24Hours, last7Days, last30Days }

class DeviceUptimeEntity extends Equatable {
  final String
  assetId; // Collision-free composite identifier: 'device:1' or 'infra:1'
  final int deviceId; // Raw authentic ID in its respective table
  final String assetType; // 'inventory' or 'infrastructure'
  final String deviceName;
  final String ownerName;
  final String department;
  final String ip;
  final double? uptimePercent;
  final int totalChecks;
  final int successfulChecks;
  final int failedChecks;
  final double avgLatencyMs;
  final bool hasSufficientHistory;

  const DeviceUptimeEntity({
    String? assetId,
    required this.deviceId,
    this.assetType = 'inventory',
    required this.deviceName,
    required this.ownerName,
    required this.department,
    required this.ip,
    this.uptimePercent,
    required this.totalChecks,
    required this.successfulChecks,
    required this.failedChecks,
    required this.avgLatencyMs,
    this.hasSufficientHistory = true,
  }) : assetId =
           assetId ??
           (assetType == 'infrastructure'
               ? 'infra:$deviceId'
               : 'device:$deviceId');

  @override
  List<Object?> get props => [
    assetId,
    deviceId,
    assetType,
    deviceName,
    ownerName,
    department,
    ip,
    uptimePercent,
    totalChecks,
    successfulChecks,
    failedChecks,
    avgLatencyMs,
    hasSufficientHistory,
  ];
}

class ReportSummaryEntity extends Equatable {
  final ReportPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDevices;
  final double? overallAvailabilityPercent;
  final int totalCheckCount;
  final int successfulCheckCount;
  final int failedCheckCount;
  final double avgLatencyMs;
  final int totalIncidents;
  final List<DeviceUptimeEntity> deviceUptimes;

  const ReportSummaryEntity({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalDevices,
    required this.overallAvailabilityPercent,
    required this.totalCheckCount,
    required this.successfulCheckCount,
    required this.failedCheckCount,
    required this.avgLatencyMs,
    required this.totalIncidents,
    required this.deviceUptimes,
  });

  @override
  List<Object?> get props => [
    period,
    startDate,
    endDate,
    totalDevices,
    overallAvailabilityPercent,
    totalCheckCount,
    successfulCheckCount,
    failedCheckCount,
    avgLatencyMs,
    totalIncidents,
    deviceUptimes,
  ];
}
