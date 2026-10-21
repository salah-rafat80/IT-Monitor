import 'package:equatable/equatable.dart';

class DiscoveryConfigEntity extends Equatable {
  final List<String> authorizedRanges;
  final List<String> enabledStrategies;
  final int maxConcurrency;
  final int timeoutSeconds;
  final DateTime updatedAt;

  const DiscoveryConfigEntity({
    this.authorizedRanges = const ['192.168.27.0/24', '192.168.22.0/24'],
    this.enabledStrategies = const [
      'icmp',
      'arp',
      'dns',
      'tcp_probe',
      'onvif',
      'mdns',
    ],
    this.maxConcurrency = 20,
    this.timeoutSeconds = 2,
    required this.updatedAt,
  });

  factory DiscoveryConfigEntity.initial() {
    return DiscoveryConfigEntity(updatedAt: DateTime.now());
  }

  DiscoveryConfigEntity copyWith({
    List<String>? authorizedRanges,
    List<String>? enabledStrategies,
    int? maxConcurrency,
    int? timeoutSeconds,
    DateTime? updatedAt,
  }) {
    return DiscoveryConfigEntity(
      authorizedRanges: authorizedRanges ?? this.authorizedRanges,
      enabledStrategies: enabledStrategies ?? this.enabledStrategies,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'authorizedRanges': authorizedRanges,
    'enabledStrategies': enabledStrategies,
    'maxConcurrency': maxConcurrency,
    'timeoutSeconds': timeoutSeconds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DiscoveryConfigEntity.fromJson(Map<String, dynamic> json) {
    return DiscoveryConfigEntity(
      authorizedRanges:
          (json['authorizedRanges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['192.168.27.0/24', '192.168.22.0/24'],
      enabledStrategies:
          (json['enabledStrategies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['icmp', 'arp', 'dns', 'tcp_probe', 'onvif', 'mdns'],
      maxConcurrency: json['maxConcurrency'] as int? ?? 20,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 2,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    authorizedRanges,
    enabledStrategies,
    maxConcurrency,
    timeoutSeconds,
    updatedAt,
  ];
}
