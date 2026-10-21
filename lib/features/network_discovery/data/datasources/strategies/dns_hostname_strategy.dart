import 'dart:io';
import 'package:injectable/injectable.dart';

import '../../../domain/services/discovery_strategy.dart';

@lazySingleton
class DnsHostnameStrategy implements DiscoveryStrategy {
  @override
  String get name => 'dns';

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    try {
      final addr = InternetAddress(targetIp);
      final reversed = await addr.reverse().timeout(
        timeout,
        onTimeout: () => throw 'Reverse DNS timeout',
      );

      final host = reversed.host.trim();
      if (host.isNotEmpty && host != targetIp) {
        return StrategyProbeResult.success(
          strategyName: name,
          targetIp: targetIp,
          hostname: host,
          evidenceDetails: 'Reverse DNS PTR: $host',
        );
      } else {
        return StrategyProbeResult.failure(
          strategyName: name,
          targetIp: targetIp,
          errorMessage: 'No reverse PTR record configured for $targetIp',
        );
      }
    } catch (e) {
      return StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'DNS lookup failed: $e',
      );
    }
  }
}
