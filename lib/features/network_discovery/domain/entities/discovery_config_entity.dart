import 'package:equatable/equatable.dart';

import 'network_range.dart';

class DiscoveryConfigEntity extends Equatable {
  final List<NetworkRange> networkRanges;
  final List<String> enabledStrategies;
  final int maxConcurrency;
  final int timeoutSeconds;
  final DateTime updatedAt;

  DiscoveryConfigEntity({
    List<NetworkRange>? networkRanges,
    List<String>? authorizedRanges,
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
  }) : networkRanges =
           networkRanges ??
           (authorizedRanges != null
               ? authorizedRanges
                     .map((c) => NetworkRange.parse(c, factoryId: 'unassigned'))
                     .whereType<NetworkRange>()
                     .toList()
               : const []);

  /// Returns canonical CIDRs for all currently enabled network ranges across all factories.
  List<String> get authorizedRanges =>
      networkRanges.where((r) => r.isEnabled).map((r) => r.cidr).toList();

  /// Returns all configured CIDRs regardless of enabled state.
  List<String> get allConfiguredRanges =>
      networkRanges.map((r) => r.cidr).toList();

  /// Returns all configured ranges belonging to a specific factory.
  List<NetworkRange> getRangesForFactory(String factoryId) {
    final clean = factoryId.trim().toLowerCase();
    return networkRanges
        .where((r) => r.factoryId.trim().toLowerCase() == clean)
        .toList();
  }

  /// Returns canonical CIDRs for enabled network ranges belonging to a specific factory.
  List<String> getAuthorizedRangesForFactory(String factoryId) {
    return getRangesForFactory(
      factoryId,
    ).where((r) => r.isEnabled).map((r) => r.cidr).toList();
  }

  /// Fresh installations initialize with zero hardcoded network ranges.
  /// Administrators must configure authorized scopes explicitly.
  factory DiscoveryConfigEntity.initial() {
    return DiscoveryConfigEntity(
      networkRanges: const [],
      updatedAt: DateTime.now(),
    );
  }

  DiscoveryConfigEntity copyWith({
    List<NetworkRange>? networkRanges,
    List<String>? authorizedRanges,
    List<String>? enabledStrategies,
    int? maxConcurrency,
    int? timeoutSeconds,
    DateTime? updatedAt,
  }) {
    List<NetworkRange>? effectiveRanges = networkRanges;
    if (effectiveRanges == null && authorizedRanges != null) {
      effectiveRanges = authorizedRanges
          .map((c) => NetworkRange.parse(c, factoryId: 'unassigned'))
          .whereType<NetworkRange>()
          .toList();
    }

    return DiscoveryConfigEntity(
      networkRanges: effectiveRanges ?? this.networkRanges,
      enabledStrategies: enabledStrategies ?? this.enabledStrategies,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'authorizedRanges': authorizedRanges,
    'networkRanges': networkRanges.map((r) => r.toJson()).toList(),
    'enabledStrategies': enabledStrategies,
    'maxConcurrency': maxConcurrency,
    'timeoutSeconds': timeoutSeconds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DiscoveryConfigEntity.fromJson(Map<String, dynamic> json) {
    List<NetworkRange> ranges = const [];

    if (json['networkRanges'] is List) {
      ranges = (json['networkRanges'] as List)
          .map((e) {
            if (e is Map<String, dynamic>) {
              return NetworkRange.fromJson(e);
            } else if (e is String) {
              return NetworkRange.parse(e, factoryId: 'unassigned');
            }
            return null;
          })
          .whereType<NetworkRange>()
          .toList();
    } else if (json['authorizedRanges'] is List) {
      ranges = (json['authorizedRanges'] as List)
          .map((e) => NetworkRange.parse(e.toString(), factoryId: 'unassigned'))
          .whereType<NetworkRange>()
          .toList();
    }

    return DiscoveryConfigEntity(
      networkRanges: ranges,
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
    networkRanges,
    enabledStrategies,
    maxConcurrency,
    timeoutSeconds,
    updatedAt,
  ];
}
