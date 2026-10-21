import 'package:equatable/equatable.dart';

import 'discovered_device_entity.dart';
import 'discovery_scan_job.dart';

class DiscoveryProgress extends Equatable {
  final int scanId;
  final ScanJobStatus status;
  final String? currentRange;
  final int targetsEnumerated;
  final int targetsAttempted;
  final int responsesReceived;
  final int devicesFound;
  final int classifiedCount;
  final int unknownCount;
  final DiscoveredDeviceEntity? latestDevice;
  final String? message;

  const DiscoveryProgress({
    required this.scanId,
    required this.status,
    this.currentRange,
    required this.targetsEnumerated,
    required this.targetsAttempted,
    required this.responsesReceived,
    required this.devicesFound,
    required this.classifiedCount,
    required this.unknownCount,
    this.latestDevice,
    this.message,
  });

  double get progressFraction => targetsEnumerated > 0
      ? (targetsAttempted / targetsEnumerated).clamp(0.0, 1.0)
      : 0.0;

  Map<String, dynamic> toJson() => {
    'scanId': scanId,
    'status': status.toValue(),
    'currentRange': currentRange,
    'targetsEnumerated': targetsEnumerated,
    'targetsAttempted': targetsAttempted,
    'responsesReceived': responsesReceived,
    'devicesFound': devicesFound,
    'classifiedCount': classifiedCount,
    'unknownCount': unknownCount,
    'latestDevice': latestDevice?.toJson(),
    'progressFraction': progressFraction,
    'message': message,
  };

  @override
  List<Object?> get props => [
    scanId,
    status,
    currentRange,
    targetsEnumerated,
    targetsAttempted,
    responsesReceived,
    devicesFound,
    classifiedCount,
    unknownCount,
    latestDevice,
    message,
  ];
}
