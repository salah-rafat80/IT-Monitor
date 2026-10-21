import 'package:equatable/equatable.dart';

class DiscoveryEvidenceItem extends Equatable {
  final String
  strategyName; // 'icmp', 'arp', 'dns', 'tcp_probe', 'onvif', 'mdns', 'mac_vendor'
  final String probeTarget; // e.g. '192.168.27.30:554' or '192.168.27.30'
  final bool isSuccess;
  final String
  details; // e.g. 'RTSP port open', 'MAC OUI: Dahua Technology', 'PTR: FIN-117.corp'
  final DateTime timestamp;

  const DiscoveryEvidenceItem({
    required this.strategyName,
    required this.probeTarget,
    required this.isSuccess,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'strategyName': strategyName,
    'probeTarget': probeTarget,
    'isSuccess': isSuccess,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DiscoveryEvidenceItem.fromJson(Map<String, dynamic> json) {
    return DiscoveryEvidenceItem(
      strategyName: json['strategyName'] as String,
      probeTarget: json['probeTarget'] as String,
      isSuccess: json['isSuccess'] as bool? ?? false,
      details: json['details'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    strategyName,
    probeTarget,
    isSuccess,
    details,
    timestamp,
  ];
}
