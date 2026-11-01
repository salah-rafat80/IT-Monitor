import 'package:equatable/equatable.dart';

import 'device_entity.dart';

/// Explicit contract separating INSERT and UPDATE operations during inventory import.
class DeviceImportCommitPayload extends Equatable {
  final List<DeviceEntity> inserts;
  final List<DeviceEntity> updates;
  final String targetFactoryId;

  const DeviceImportCommitPayload({
    this.inserts = const [],
    this.updates = const [],
    required this.targetFactoryId,
  });

  int get totalCount => inserts.length + updates.length;

  Map<String, dynamic> toJson() => {
    'inserts': inserts.map((d) => d.toJson()).toList(),
    'updates': updates.map((d) => d.toJson()).toList(),
    'targetFactoryId': targetFactoryId,
  };

  factory DeviceImportCommitPayload.fromJson(Map<String, dynamic> json) {
    return DeviceImportCommitPayload(
      inserts: (json['inserts'] as List<dynamic>? ?? [])
          .map((d) => DeviceEntity.fromJson(d as Map<String, dynamic>))
          .toList(),
      updates: (json['updates'] as List<dynamic>? ?? [])
          .map((d) => DeviceEntity.fromJson(d as Map<String, dynamic>))
          .toList(),
      targetFactoryId: json['targetFactoryId'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [inserts, updates, targetFactoryId];
}
