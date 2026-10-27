import 'package:equatable/equatable.dart';

import 'classification_confidence.dart';
import 'device_category.dart';
import 'discovery_evidence_item.dart';
import 'review_state.dart';

class DiscoveredDeviceEntity extends Equatable {
  final int id;
  final int scanId;
  final String factoryId;
  final String ip;
  final String? mac;
  final String? hostname;
  final String? vendor;
  final List<String> observedServices;
  final DeviceCategory predictedCategory;
  final ClassificationConfidence confidence;
  final List<DiscoveryEvidenceItem> evidence;
  final String classificationMethod;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final DateTime? lastSuccessfulProbe;
  final String? lastProbeFailureReason;
  final ReviewState reviewState;
  final DeviceCategory? adminConfirmedCategory;
  final int? adminReviewerId;
  final DateTime? adminReviewTimestamp;
  final int? associatedDeviceId;

  const DiscoveredDeviceEntity({
    this.id = 0,
    required this.scanId,
    this.factoryId = 'unassigned',
    required this.ip,
    this.mac,
    this.hostname,
    this.vendor,
    this.observedServices = const [],
    this.predictedCategory = DeviceCategory.unknown,
    this.confidence = ClassificationConfidence.unknown,
    this.evidence = const [],
    this.classificationMethod = 'multi_evidence_v1',
    required this.firstSeen,
    required this.lastSeen,
    this.lastSuccessfulProbe,
    this.lastProbeFailureReason,
    this.reviewState = ReviewState.pendingReview,
    this.adminConfirmedCategory,
    this.adminReviewerId,
    this.adminReviewTimestamp,
    this.associatedDeviceId,
  });

  DiscoveredDeviceEntity copyWith({
    int? id,
    int? scanId,
    String? factoryId,
    String? ip,
    String? mac,
    String? hostname,
    String? vendor,
    List<String>? observedServices,
    DeviceCategory? predictedCategory,
    ClassificationConfidence? confidence,
    List<DiscoveryEvidenceItem>? evidence,
    String? classificationMethod,
    DateTime? firstSeen,
    DateTime? lastSeen,
    DateTime? lastSuccessfulProbe,
    String? lastProbeFailureReason,
    ReviewState? reviewState,
    DeviceCategory? adminConfirmedCategory,
    int? adminReviewerId,
    DateTime? adminReviewTimestamp,
    int? associatedDeviceId,
  }) {
    return DiscoveredDeviceEntity(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      factoryId: factoryId ?? this.factoryId,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      hostname: hostname ?? this.hostname,
      vendor: vendor ?? this.vendor,
      observedServices: observedServices ?? this.observedServices,
      predictedCategory: predictedCategory ?? this.predictedCategory,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      classificationMethod: classificationMethod ?? this.classificationMethod,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSuccessfulProbe: lastSuccessfulProbe ?? this.lastSuccessfulProbe,
      lastProbeFailureReason:
          lastProbeFailureReason ?? this.lastProbeFailureReason,
      reviewState: reviewState ?? this.reviewState,
      adminConfirmedCategory:
          adminConfirmedCategory ?? this.adminConfirmedCategory,
      adminReviewerId: adminReviewerId ?? this.adminReviewerId,
      adminReviewTimestamp: adminReviewTimestamp ?? this.adminReviewTimestamp,
      associatedDeviceId: associatedDeviceId ?? this.associatedDeviceId,
    );
  }

  DeviceCategory get effectiveCategory =>
      adminConfirmedCategory ?? predictedCategory;

  Map<String, dynamic> toJson() => {
    'id': id,
    'scanId': scanId,
    'factoryId': factoryId,
    'ip': ip,
    'mac': mac,
    'hostname': hostname,
    'vendor': vendor,
    'observedServices': observedServices,
    'predictedCategory': predictedCategory.toValue(),
    'confidence': confidence.toValue(),
    'evidence': evidence.map((e) => e.toJson()).toList(),
    'classificationMethod': classificationMethod,
    'firstSeen': firstSeen.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'lastSuccessfulProbe': lastSuccessfulProbe?.toIso8601String(),
    'lastProbeFailureReason': lastProbeFailureReason,
    'reviewState': reviewState.toValue(),
    'adminConfirmedCategory': adminConfirmedCategory?.toValue(),
    'adminReviewerId': adminReviewerId,
    'adminReviewTimestamp': adminReviewTimestamp?.toIso8601String(),
    'associatedDeviceId': associatedDeviceId,
  };

  factory DiscoveredDeviceEntity.fromJson(Map<String, dynamic> json) {
    return DiscoveredDeviceEntity(
      id: json['id'] as int? ?? 0,
      scanId: json['scanId'] as int? ?? 0,
      factoryId: json['factoryId'] as String? ?? 'unassigned',
      ip: json['ip'] as String,
      mac: json['mac'] as String?,
      hostname: json['hostname'] as String?,
      vendor: json['vendor'] as String?,
      observedServices:
          (json['observedServices'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      predictedCategory: DeviceCategory.fromString(
        json['predictedCategory'] as String? ?? 'unknown',
      ),
      confidence: ClassificationConfidence.fromString(
        json['confidence'] as String? ?? 'unknown',
      ),
      evidence:
          (json['evidence'] as List<dynamic>?)
              ?.map(
                (e) =>
                    DiscoveryEvidenceItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      classificationMethod:
          json['classificationMethod'] as String? ?? 'multi_evidence_v1',
      firstSeen:
          DateTime.tryParse(json['firstSeen'] as String? ?? '') ??
          DateTime.now(),
      lastSeen:
          DateTime.tryParse(json['lastSeen'] as String? ?? '') ??
          DateTime.now(),
      lastSuccessfulProbe: json['lastSuccessfulProbe'] != null
          ? DateTime.tryParse(json['lastSuccessfulProbe'] as String)
          : null,
      lastProbeFailureReason: json['lastProbeFailureReason'] as String?,
      reviewState: ReviewState.fromString(
        json['reviewState'] as String? ?? 'pending_review',
      ),
      adminConfirmedCategory: json['adminConfirmedCategory'] != null
          ? DeviceCategory.fromString(json['adminConfirmedCategory'] as String)
          : null,
      adminReviewerId: json['adminReviewerId'] as int?,
      adminReviewTimestamp: json['adminReviewTimestamp'] != null
          ? DateTime.tryParse(json['adminReviewTimestamp'] as String)
          : null,
      associatedDeviceId: json['associatedDeviceId'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    scanId,
    factoryId,
    ip,
    mac,
    hostname,
    vendor,
    observedServices,
    predictedCategory,
    confidence,
    evidence,
    classificationMethod,
    firstSeen,
    lastSeen,
    lastSuccessfulProbe,
    lastProbeFailureReason,
    reviewState,
    adminConfirmedCategory,
    adminReviewerId,
    adminReviewTimestamp,
    associatedDeviceId,
  ];
}
