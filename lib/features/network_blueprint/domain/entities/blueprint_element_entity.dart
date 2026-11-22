import 'dart:ui';
import 'package:equatable/equatable.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';

enum BlueprintElementCategory {
  room,
  office,
  switchDevice,
  server,
  workstation,
  laptop,
  wallDrop,
  telephony,
  security,
  generic;

  String get displayName {
    switch (this) {
      case BlueprintElementCategory.room:
        return 'Room / Facility Zone';
      case BlueprintElementCategory.office:
        return 'Department Office';
      case BlueprintElementCategory.switchDevice:
        return 'Network Switch';
      case BlueprintElementCategory.server:
        return 'Server Infrastructure';
      case BlueprintElementCategory.workstation:
        return 'Desktop Workstation';
      case BlueprintElementCategory.laptop:
        return 'Wireless Laptop';
      case BlueprintElementCategory.wallDrop:
        return 'Network Drop Port';
      case BlueprintElementCategory.telephony:
        return 'IP-PBX Telephony';
      case BlueprintElementCategory.security:
        return 'Security Equipment';
      case BlueprintElementCategory.generic:
        return 'Blueprint Element';
    }
  }
}

enum BlueprintMappingConfidence {
  confirmedIp,
  candidate,
  unmapped;

  String get displayName {
    switch (this) {
      case BlueprintMappingConfidence.confirmedIp:
        return 'Confirmed (IP Match)';
      case BlueprintMappingConfidence.candidate:
        return 'Candidate (Needs Review)';
      case BlueprintMappingConfidence.unmapped:
        return 'Monitoring Unavailable';
    }
  }
}

class BlueprintElementEntity extends Equatable {
  final String id;
  final String? parentId;
  final String rawLabel;
  final String englishLabel;
  final BlueprintElementCategory category;
  final Rect bounds;
  final Rect? svgBounds;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final bool isDashed;
  final bool isRounded;
  final String shapeType;
  final String rawStyle;
  final int? mappedDeviceId;
  final String? mappedDeviceName;
  final String? mappedIp;
  final BlueprintMappingConfidence mappingConfidence;
  final DeviceStatusEnum? liveStatus;
  final int? lastLatencyMs;
  final DateTime? lastCheckAt;

  const BlueprintElementEntity({
    required this.id,
    this.parentId,
    required this.rawLabel,
    required this.englishLabel,
    required this.category,
    required this.bounds,
    this.svgBounds,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.0,
    this.isDashed = false,
    this.isRounded = false,
    this.shapeType = 'rectangle',
    this.rawStyle = '',
    this.mappedDeviceId,
    this.mappedDeviceName,
    this.mappedIp,
    this.mappingConfidence = BlueprintMappingConfidence.unmapped,
    this.liveStatus,
    this.lastLatencyMs,
    this.lastCheckAt,
  });

  bool get isMonitored =>
      mappingConfidence == BlueprintMappingConfidence.confirmedIp &&
      mappedDeviceId != null;

  Rect get renderBounds => svgBounds ?? bounds;

  String get displayTitle {
    if (englishLabel.trim().isNotEmpty) {
      return englishLabel.trim();
    }
    if (category != BlueprintElementCategory.generic) {
      return category.displayName;
    }
    return 'Unclassified Diagram Element ($id)';
  }

  BlueprintElementEntity copyWith({
    String? id,
    String? parentId,
    String? rawLabel,
    String? englishLabel,
    BlueprintElementCategory? category,
    Rect? bounds,
    Rect? svgBounds,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    bool? isDashed,
    bool? isRounded,
    String? shapeType,
    String? rawStyle,
    int? mappedDeviceId,
    String? mappedDeviceName,
    String? mappedIp,
    BlueprintMappingConfidence? mappingConfidence,
    DeviceStatusEnum? liveStatus,
    int? lastLatencyMs,
    DateTime? lastCheckAt,
  }) {
    return BlueprintElementEntity(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      rawLabel: rawLabel ?? this.rawLabel,
      englishLabel: englishLabel ?? this.englishLabel,
      category: category ?? this.category,
      bounds: bounds ?? this.bounds,
      svgBounds: svgBounds ?? this.svgBounds,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isDashed: isDashed ?? this.isDashed,
      isRounded: isRounded ?? this.isRounded,
      shapeType: shapeType ?? this.shapeType,
      rawStyle: rawStyle ?? this.rawStyle,
      mappedDeviceId: mappedDeviceId ?? this.mappedDeviceId,
      mappedDeviceName: mappedDeviceName ?? this.mappedDeviceName,
      mappedIp: mappedIp ?? this.mappedIp,
      mappingConfidence: mappingConfidence ?? this.mappingConfidence,
      liveStatus: liveStatus ?? this.liveStatus,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        parentId,
        rawLabel,
        englishLabel,
            category,
    bounds,
    svgBounds,
    fillColor,
        strokeColor,
        strokeWidth,
        isDashed,
        isRounded,
        shapeType,
        rawStyle,
        mappedDeviceId,
        mappedDeviceName,
        mappedIp,
        mappingConfidence,
        liveStatus,
        lastLatencyMs,
        lastCheckAt,
      ];
}
