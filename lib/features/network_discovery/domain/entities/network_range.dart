import 'dart:io';
import 'package:equatable/equatable.dart';

import 'reachability_status.dart';

class NetworkRange extends Equatable {
  final String id; // Stable unique identifier, e.g. 'range_10_10_0_0_24'
  final String? name; // Optional human-readable name, e.g. 'Core Office VLAN'
  final String cidr; // e.g., '192.168.27.0/24'
  final String baseIp; // e.g., '192.168.27.0'
  final int prefixLength; // e.g., 24
  final int totalHosts; // e.g., 256
  final int usableHostsCount; // e.g., 254
  final bool isEnabled; // Active in scans and scope filtering
  final ReachabilityStatus reachability;
  final String? diagnosticNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const NetworkRange({
    required this.id,
    this.name,
    required this.cidr,
    required this.baseIp,
    required this.prefixLength,
    required this.totalHosts,
    required this.usableHostsCount,
    this.isEnabled = true,
    this.reachability = ReachabilityStatus.reachabilityNotTested,
    this.diagnosticNotes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Deterministic ID generator from canonical normalized CIDR
  static String generateId(String normalizedCidr) {
    return 'range_${normalizedCidr.replaceAll('.', '_').replaceAll('/', '_')}';
  }

  static NetworkRange? tryParse(
    String cidrStr, {
    String? id,
    String? name,
    bool isEnabled = true,
    ReachabilityStatus status = ReachabilityStatus.reachabilityNotTested,
    String? diagnosticNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => parse(
    cidrStr,
    id: id,
    name: name,
    isEnabled: isEnabled,
    status: status,
    diagnosticNotes: diagnosticNotes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static NetworkRange? parse(
    String cidrStr, {
    String? id,
    String? name,
    bool isEnabled = true,
    ReachabilityStatus status = ReachabilityStatus.reachabilityNotTested,
    String? diagnosticNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final trimmed = cidrStr.trim();
    final parts = trimmed.split('/');
    if (parts.length != 2) return null;

    final ipStr = parts[0].trim();
    final prefix = int.tryParse(parts[1].trim());
    if (prefix == null || prefix < 16 || prefix > 32) {
      return null; // Bounded safe enterprise discovery scope (16 to 32)
    }

    final ipParts = ipStr.split('.');
    if (ipParts.length != 4) return null;

    final octets = <int>[];
    for (final p in ipParts) {
      final octet = int.tryParse(p);
      if (octet == null || octet < 0 || octet > 255) return null;
      octets.add(octet);
    }

    final total = prefix == 32 ? 1 : (1 << (32 - prefix));
    final usable = prefix == 32
        ? 1
        : (prefix == 31 ? 2 : (total > 2 ? total - 2 : total));

    // Calculate normalized base network IP
    final ipInt =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final maskInt = prefix == 0
        ? 0
        : ((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF);
    final baseInt = ipInt & maskInt;

    final baseOctets = [
      (baseInt >> 24) & 0xFF,
      (baseInt >> 16) & 0xFF,
      (baseInt >> 8) & 0xFF,
      baseInt & 0xFF,
    ];
    final normalizedBaseIp = baseOctets.join('.');
    final normalizedCidr = '$normalizedBaseIp/$prefix';
    final effectiveId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : generateId(normalizedCidr);

    return NetworkRange(
      id: effectiveId,
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      cidr: normalizedCidr,
      baseIp: normalizedBaseIp,
      prefixLength: prefix,
      totalHosts: total,
      usableHostsCount: usable,
      isEnabled: isEnabled,
      reachability: status,
      diagnosticNotes: diagnosticNotes,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
    );
  }

  /// Generates the deterministic list of usable host IP addresses.
  /// Strictly excludes network address and broadcast address.
  List<String> enumerateUsableHosts() {
    if (prefixLength == 32) {
      return [baseIp];
    }
    if (prefixLength == 31) {
      final parts = baseIp.split('.').map(int.parse).toList();
      final baseInt =
          (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
      return [
        baseIp,
        '${(baseInt + 1 >> 24) & 0xFF}.${(baseInt + 1 >> 16) & 0xFF}.${(baseInt + 1 >> 8) & 0xFF}.${(baseInt + 1) & 0xFF}',
      ];
    }

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
    final maskInt = prefixLength == 0
        ? 0
        : ((0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF);

    return (targetInt & maskInt) == baseInt;
  }

  NetworkRange copyWith({
    String? id,
    String? name,
    String? cidr,
    String? baseIp,
    int? prefixLength,
    int? totalHosts,
    int? usableHostsCount,
    bool? isEnabled,
    ReachabilityStatus? reachability,
    String? diagnosticNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NetworkRange(
      id: id ?? this.id,
      name: name ?? this.name,
      cidr: cidr ?? this.cidr,
      baseIp: baseIp ?? this.baseIp,
      prefixLength: prefixLength ?? this.prefixLength,
      totalHosts: totalHosts ?? this.totalHosts,
      usableHostsCount: usableHostsCount ?? this.usableHostsCount,
      isEnabled: isEnabled ?? this.isEnabled,
      reachability: reachability ?? this.reachability,
      diagnosticNotes: diagnosticNotes ?? this.diagnosticNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cidr': cidr,
    'baseIp': baseIp,
    'prefixLength': prefixLength,
    'totalHosts': totalHosts,
    'usableHostsCount': usableHostsCount,
    'isEnabled': isEnabled,
    'reachability': reachability.toValue(),
    'diagnosticNotes': diagnosticNotes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory NetworkRange.fromJson(Map<String, dynamic> json) {
    final cidrStr = json['cidr'] as String;
    final prefix = json['prefixLength'] as int? ?? 24;
    final base = json['baseIp'] as String? ?? cidrStr.split('/').first;
    final effectiveId = json['id'] as String? ?? generateId(cidrStr);

    return NetworkRange(
      id: effectiveId,
      name: json['name'] as String?,
      cidr: cidrStr,
      baseIp: base,
      prefixLength: prefix,
      totalHosts: json['totalHosts'] as int? ?? (1 << (32 - prefix)),
      usableHostsCount: json['usableHostsCount'] as int? ?? 254,
      isEnabled: json['isEnabled'] as bool? ?? true,
      reachability: ReachabilityStatus.fromString(
        json['reachability'] as String? ?? 'reachability_not_tested',
      ),
      diagnosticNotes: json['diagnosticNotes'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    cidr,
    baseIp,
    prefixLength,
    totalHosts,
    usableHostsCount,
    isEnabled,
    reachability,
    diagnosticNotes,
    createdAt,
    updatedAt,
  ];
}
