import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/ipv4_utils.dart';
import '../../../network_discovery/domain/entities/network_range.dart';
import '../entities/factory_entity.dart';

enum FactoryDetectionStatus { detected, ambiguous, unknown }

class FactoryDetectionResult extends Equatable {
  final FactoryDetectionStatus status;
  final FactoryEntity? detectedFactory;
  final List<FactoryEntity> candidateFactories;
  final List<String> matchedIps;
  final List<String> detectedLocalIps;
  final String? message;

  const FactoryDetectionResult({
    required this.status,
    this.detectedFactory,
    this.candidateFactories = const [],
    this.matchedIps = const [],
    this.detectedLocalIps = const [],
    this.message,
  });

  bool get isDetected => status == FactoryDetectionStatus.detected;
  bool get isAmbiguous => status == FactoryDetectionStatus.ambiguous;
  bool get isUnknown => status == FactoryDetectionStatus.unknown;

  @override
  List<Object?> get props => [
    status,
    detectedFactory,
    candidateFactories,
    matchedIps,
    detectedLocalIps,
    message,
  ];
}

abstract class NetworkDetectionService {
  Future<List<String>> getLocalIpv4Addresses({
    List<NetworkInterface>? mockInterfaces,
  });

  Future<FactoryDetectionResult> detectFactory({
    required List<FactoryEntity> factories,
    List<NetworkInterface>? mockInterfaces,
    List<String>? mockLocalIps,
    List<NetworkRange>? additionalDiscoveryRanges,
  });
}

@LazySingleton(as: NetworkDetectionService)
class NetworkDetectionServiceImpl implements NetworkDetectionService {
  @override
  Future<List<String>> getLocalIpv4Addresses({
    List<NetworkInterface>? mockInterfaces,
  }) async {
    final ips = <String>{};

    try {
      final interfaces =
          mockInterfaces ??
          await NetworkInterface.list(
            includeLoopback: false,
            type: InternetAddressType.IPv4,
          );

      for (final iface in interfaces) {
        // Filter out known loopback interface names
        final name = iface.name.toLowerCase();
        if (name.contains('loopback')) continue;

        for (final addr in iface.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          if (addr.isLoopback || addr.isLinkLocal || addr.isMulticast) continue;

          final rawIp = addr.address.trim();
          final canon = Ipv4Utils.canonicalizeIpv4(rawIp);
          if (canon == null) continue;

          // Reject loopback 127.x.x.x, link-local 169.254.x.x, unspecified 0.0.0.0
          if (canon.startsWith('127.') ||
              canon.startsWith('169.254.') ||
              canon == '0.0.0.0' ||
              canon == '255.255.255.255') {
            continue;
          }

          // Reject public IP addresses (do not use public IP for factory detection)
          if (!_isPrivateIpv4(canon)) {
            continue;
          }

          ips.add(canon);
        }
      }
    } catch (_) {}

    return ips.toList();
  }

  @override
  Future<FactoryDetectionResult> detectFactory({
    required List<FactoryEntity> factories,
    List<NetworkInterface>? mockInterfaces,
    List<String>? mockLocalIps,
    List<NetworkRange>? additionalDiscoveryRanges,
  }) async {
    final activeFactories = factories
        .where((f) => f.isActive && f.id != 'unassigned')
        .toList();

    final List<String> localIps;
    if (mockLocalIps != null) {
      localIps = mockLocalIps
          .map((ip) => Ipv4Utils.canonicalizeIpv4(ip.trim()))
          .whereType<String>()
          .where(
            (ip) =>
                !ip.startsWith('127.') &&
                !ip.startsWith('169.254.') &&
                ip != '0.0.0.0' &&
                _isPrivateIpv4(ip),
          )
          .toList();
    } else {
      localIps = await getLocalIpv4Addresses(mockInterfaces: mockInterfaces);
    }

    if (localIps.isEmpty) {
      return FactoryDetectionResult(
        status: FactoryDetectionStatus.unknown,
        detectedLocalIps: const [],
        message:
            'No active private LAN IPv4 interfaces detected on this system.',
      );
    }

    // Map each factory to matching local IPs
    final matchedFactories = <FactoryEntity>{};
    final matchedIps = <String>{};

    for (final factory in activeFactories) {
      final factoryRanges = <NetworkRange>[];

      // 1. Factory's own registered expected CIDR
      if (factory.expectedCidr != null &&
          factory.expectedCidr!.trim().isNotEmpty) {
        final parsed = NetworkRange.parse(factory.expectedCidr!.trim());
        if (parsed != null) {
          factoryRanges.add(parsed);
        }
      }

      // 2. Any additional discovery ranges registered for this factory
      if (additionalDiscoveryRanges != null) {
        for (final r in additionalDiscoveryRanges) {
          if (r.factoryId.toLowerCase() == factory.id.toLowerCase() &&
              r.isEnabled) {
            factoryRanges.add(r);
          }
        }
      }

      for (final ip in localIps) {
        for (final range in factoryRanges) {
          if (range.containsIp(ip)) {
            matchedFactories.add(factory);
            matchedIps.add(ip);
            break;
          }
        }
      }
    }

    // Evaluate matching outcome
    if (matchedFactories.length == 1) {
      final detected = matchedFactories.first;
      return FactoryDetectionResult(
        status: FactoryDetectionStatus.detected,
        detectedFactory: detected,
        candidateFactories: [detected],
        matchedIps: matchedIps.toList(),
        detectedLocalIps: localIps,
        message:
            'Automatically detected ${detected.name} (${detected.code}) via local address ${matchedIps.join(", ")}.',
      );
    } else if (matchedFactories.length > 1) {
      return FactoryDetectionResult(
        status: FactoryDetectionStatus.ambiguous,
        candidateFactories: matchedFactories.toList(),
        matchedIps: matchedIps.toList(),
        detectedLocalIps: localIps,
        message:
            'Ambiguous network detection: active adapters match multiple factories (${matchedFactories.map((f) => f.code).join(", ")}). Manual selection required.',
      );
    } else {
      return FactoryDetectionResult(
        status: FactoryDetectionStatus.unknown,
        detectedLocalIps: localIps,
        message:
            'Active local addresses (${localIps.join(", ")}) do not match any registered factory network scope.',
      );
    }
  }

  /// Private IPv4 ranges according to RFC 1918:
  /// 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
  bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return false;

    final p0 = parts[0]!;
    final p1 = parts[1]!;

    if (p0 == 10) return true;
    if (p0 == 172 && p1 >= 16 && p1 <= 31) return true;
    if (p0 == 192 && p1 == 168) return true;

    return false;
  }
}
