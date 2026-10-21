import 'package:equatable/equatable.dart';

enum ScanJobStatus {
  draft,
  validating,
  ready,
  running,
  cancelling,
  cancelled,
  completed,
  completedWithErrors,
  failed;

  static ScanJobStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('-', '_')) {
      case 'validating':
        return ScanJobStatus.validating;
      case 'ready':
        return ScanJobStatus.ready;
      case 'running':
        return ScanJobStatus.running;
      case 'cancelling':
        return ScanJobStatus.cancelling;
      case 'cancelled':
        return ScanJobStatus.cancelled;
      case 'completed':
        return ScanJobStatus.completed;
      case 'completed_with_errors':
        return ScanJobStatus.completedWithErrors;
      case 'failed':
        return ScanJobStatus.failed;
      case 'draft':
      default:
        return ScanJobStatus.draft;
    }
  }

  String toValue() {
    switch (this) {
      case ScanJobStatus.draft:
        return 'draft';
      case ScanJobStatus.validating:
        return 'validating';
      case ScanJobStatus.ready:
        return 'ready';
      case ScanJobStatus.running:
        return 'running';
      case ScanJobStatus.cancelling:
        return 'cancelling';
      case ScanJobStatus.cancelled:
        return 'cancelled';
      case ScanJobStatus.completed:
        return 'completed';
      case ScanJobStatus.completedWithErrors:
        return 'completed_with_errors';
      case ScanJobStatus.failed:
        return 'failed';
    }
  }

  String get displayName {
    switch (this) {
      case ScanJobStatus.draft:
        return 'Draft';
      case ScanJobStatus.validating:
        return 'Validating';
      case ScanJobStatus.ready:
        return 'Ready';
      case ScanJobStatus.running:
        return 'Running';
      case ScanJobStatus.cancelling:
        return 'Cancelling...';
      case ScanJobStatus.cancelled:
        return 'Cancelled';
      case ScanJobStatus.completed:
        return 'Completed';
      case ScanJobStatus.completedWithErrors:
        return 'Completed With Errors';
      case ScanJobStatus.failed:
        return 'Failed';
    }
  }

  bool get isActive =>
      this == ScanJobStatus.running ||
      this == ScanJobStatus.validating ||
      this == ScanJobStatus.cancelling;
  bool get isFinished =>
      this == ScanJobStatus.completed ||
      this == ScanJobStatus.completedWithErrors ||
      this == ScanJobStatus.cancelled ||
      this == ScanJobStatus.failed;
}

class DiscoveryScanJob extends Equatable {
  final int id;
  final ScanJobStatus status;
  final List<String>
  targetRanges; // e.g. ['192.168.27.0/24', '192.168.22.0/24']
  final List<String> enabledStrategies;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetsEnumerated;
  final int targetsAttempted;
  final int responsesReceived;
  final int classifiedCount;
  final int unknownCount;
  final int failureCount;
  final String? diagnosticSummary;

  const DiscoveryScanJob({
    this.id = 0,
    this.status = ScanJobStatus.draft,
    required this.targetRanges,
    this.enabledStrategies = const [
      'icmp',
      'arp',
      'dns',
      'tcp_probe',
      'onvif',
      'mdns',
    ],
    required this.startedAt,
    this.completedAt,
    this.targetsEnumerated = 0,
    this.targetsAttempted = 0,
    this.responsesReceived = 0,
    this.classifiedCount = 0,
    this.unknownCount = 0,
    this.failureCount = 0,
    this.diagnosticSummary,
  });

  DiscoveryScanJob copyWith({
    int? id,
    ScanJobStatus? status,
    List<String>? targetRanges,
    List<String>? enabledStrategies,
    DateTime? startedAt,
    DateTime? completedAt,
    int? targetsEnumerated,
    int? targetsAttempted,
    int? responsesReceived,
    int? classifiedCount,
    int? unknownCount,
    int? failureCount,
    String? diagnosticSummary,
  }) {
    return DiscoveryScanJob(
      id: id ?? this.id,
      status: status ?? this.status,
      targetRanges: targetRanges ?? this.targetRanges,
      enabledStrategies: enabledStrategies ?? this.enabledStrategies,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetsEnumerated: targetsEnumerated ?? this.targetsEnumerated,
      targetsAttempted: targetsAttempted ?? this.targetsAttempted,
      responsesReceived: responsesReceived ?? this.responsesReceived,
      classifiedCount: classifiedCount ?? this.classifiedCount,
      unknownCount: unknownCount ?? this.unknownCount,
      failureCount: failureCount ?? this.failureCount,
      diagnosticSummary: diagnosticSummary ?? this.diagnosticSummary,
    );
  }

  double get progressFraction => targetsEnumerated > 0
      ? (targetsAttempted / targetsEnumerated).clamp(0.0, 1.0)
      : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.toValue(),
    'targetRanges': targetRanges,
    'enabledStrategies': enabledStrategies,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'targetsEnumerated': targetsEnumerated,
    'targetsAttempted': targetsAttempted,
    'responsesReceived': responsesReceived,
    'classifiedCount': classifiedCount,
    'unknownCount': unknownCount,
    'failureCount': failureCount,
    'diagnosticSummary': diagnosticSummary,
    'progressFraction': progressFraction,
  };

  factory DiscoveryScanJob.fromJson(Map<String, dynamic> json) {
    return DiscoveryScanJob(
      id: json['id'] as int? ?? 0,
      status: ScanJobStatus.fromString(json['status'] as String? ?? 'draft'),
      targetRanges:
          (json['targetRanges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      enabledStrategies:
          (json['enabledStrategies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      targetsEnumerated: json['targetsEnumerated'] as int? ?? 0,
      targetsAttempted: json['targetsAttempted'] as int? ?? 0,
      responsesReceived: json['responsesReceived'] as int? ?? 0,
      classifiedCount: json['classifiedCount'] as int? ?? 0,
      unknownCount: json['unknownCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
      diagnosticSummary: json['diagnosticSummary'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    targetRanges,
    enabledStrategies,
    startedAt,
    completedAt,
    targetsEnumerated,
    targetsAttempted,
    responsesReceived,
    classifiedCount,
    unknownCount,
    failureCount,
    diagnosticSummary,
  ];
}
