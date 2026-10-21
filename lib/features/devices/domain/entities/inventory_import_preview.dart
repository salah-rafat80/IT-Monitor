import 'package:equatable/equatable.dart';

import 'device_entity.dart';

class InventoryValidationError extends Equatable {
  final int rowIndex;
  final String deviceName;
  final String rawIp;
  final String reason;

  const InventoryValidationError({
    required this.rowIndex,
    required this.deviceName,
    required this.rawIp,
    required this.reason,
  });

  @override
  List<Object?> get props => [rowIndex, deviceName, rawIp, reason];
}

class InventoryImportPreview extends Equatable {
  final List<DeviceEntity> validDevices;
  final List<String> excludedDuplicateIps;
  final List<InventoryValidationError> invalidRecords;
  final int totalRowsProcessed;

  const InventoryImportPreview({
    required this.validDevices,
    required this.excludedDuplicateIps,
    required this.invalidRecords,
    required this.totalRowsProcessed,
  });

  int get validCount => validDevices.length;
  int get excludedDuplicateIpCount => excludedDuplicateIps.length;
  int get invalidCount => invalidRecords.length;

  @override
  List<Object?> get props => [
    validDevices,
    excludedDuplicateIps,
    invalidRecords,
    totalRowsProcessed,
  ];
}
