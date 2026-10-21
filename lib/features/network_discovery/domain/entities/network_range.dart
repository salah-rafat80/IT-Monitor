import 'dart:io';
import 'package:equatable/equatable.dart';

import 'reachability_status.dart';

class NetworkRange extends Equatable {
  final String cidr; // e.g., '192.168.27.0/24'
  final String baseIp; // e.g., '192.168.27.0'
  final int prefixLength; // e.g., 24
  final int totalHosts; // e.g., 256
  final int usableHostsCount; // e.g., 254
  final ReachabilityStatus reachability;
  final String? diagnosticNotes;

  const NetworkRange({
    required this.cidr,
    required this.baseIp,
    required this.prefixLength,
    required this.totalHosts,
    required this.usableHostsCount,
    this.reachability = ReachabilityStatus.reachabilityNotTested,
    this.diagnosticNotes,
  });

  static NetworkRange? parse(
    String cidrStr, {
    ReachabilityStatus status = ReachabilityStatus.reachabilityNotTested,
  }) {
    final trimmed = cidrStr.trim();
    final parts = trimmed.split('/');
    if (parts.length != 2) return null;

    final ipStr = parts[0].trim();
    final prefix = int.tryParse(parts[1].trim());
    if (prefix == null || prefix < 16 || prefix > 30) {
      return null; // Bounded safe enterprise discovery scope (16 to 30)
    }

    final ipParts = ipStr.split('.');
    if (ipParts.length != 4) return null;

    final octets = <int>[];
    for (final p in ipParts) {
      final octet = int.tryParse(p);
      if (octet == null || octet < 0 || octet > 255) return null;
      octets.add(octet);
    }

    final total = 1 << (32 - prefix);
    final usable = total > 2 ? total - 2 : total;

    // Calculate normalized base network IP
    final ipInt =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final maskInt = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    final baseInt = ipInt & maskInt;

    final baseOctets = [
      (baseInt >> 24) & 0xFF,
      (baseInt >> 16) & 0xFF,
      (baseInt >> 8) & 0xFF,
      baseInt & 0xFF,
    ];
    final normalizedBaseIp = baseOctets.join('.');
    final normalizedCidr = '$normalizedBaseIp/$prefix';

    return NetworkRange(
      cidr: normalizedCidr,
      baseIp: normalizedBaseIp,
      prefixLength: prefix,
      totalHosts: total,
      usableHostsCount: usable,
      reachability: status,
    );
  }

  /// Generates the deterministic list of usable host IP addresses.
  /// Strictly excludes network address and broadcast address.
  List<String> enumerateUsableHosts() {
    final parts = baseIp.split('.').map(int.parse).toList();
    final baseInt =
        (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];

    final list = <String>[];
    // Start at 1 (exclude network address) and end before totalHosts - 1 (exclude broadcast)
    for (int i = 1; i < totalHosts - 1; i++) {
      final hostInt = baseInt + i;
      final ip =
          '${(hostInt >> 24) & 0xFF}.${(hostInt >> 16) & 0xFF}.${(hostInt >> 8) & 0xFF}.${hostInt & 0xFF}';
      list.add(ip);
    }
    return list;
  }

  bool containsIp(String ip) {
    final parsed = InternetAddress.tryParse(ip);
    if (parsed == null || parsed.type != InternetAddressType.IPv4) return false;

    final ipParts = ip.split('.').map(int.tryParse).toList();
    if (ipParts.any((p) => p == null)) return false;

    final targetInt =
        (ipParts[0]! << 24) |
        (ipParts[1]! << 16) |
        (ipParts[2]! << 8) |
        ipParts[3]!;
    final baseParts = baseIp.split('.').map(int.parse).toList();
    final baseInt =
        (baseParts[0] << 24) |
        (baseParts[1] << 16) |
        (baseParts[2] << 8) |
        baseParts[3];
    final maskInt = (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;

    return (targetInt & maskInt) == baseInt;
  }

  NetworkRange copyWith({
    ReachabilityStatus? reachability,
    String? diagnosticNotes,
  }) {
    return NetworkRange(
      cidr: cidr,
      baseIp: baseIp,
      prefixLength: prefixLength,
      totalHosts: totalHosts,
      usableHostsCount: usableHostsCount,
      reachability: reachability ?? this.reachability,
      diagnosticNotes: diagnosticNotes ?? this.diagnosticNotes,
    );
  }

  Map<String, dynamic> toJson() => {
    'cidr': cidr,
    'baseIp': baseIp,
    'prefixLength': prefixLength,
    'totalHosts': totalHosts,
    'usableHostsCount': usableHostsCount,
    'reachability': reachability.toValue(),
    'diagnosticNotes': diagnosticNotes,
  };

  factory NetworkRange.fromJson(Map<String, dynamic> json) {
    return NetworkRange(
      cidr: json['cidr'] as String,
      baseIp: json['baseIp'] as String,
      prefixLength: json['prefixLength'] as int,
      totalHosts: json['totalHosts'] as int,
      usableHostsCount: json['usableHostsCount'] as int,
      reachability: ReachabilityStatus.fromString(
        json['reachability'] as String? ?? 'reachability_not_tested',
      ),
      diagnosticNotes: json['diagnosticNotes'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    cidr,
    baseIp,
    prefixLength,
    totalHosts,
    usableHostsCount,
    reachability,
    diagnosticNotes,
  ];
}
