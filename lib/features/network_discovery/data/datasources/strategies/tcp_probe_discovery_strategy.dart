import 'dart:io';
import 'package:injectable/injectable.dart';

import '../../../domain/services/discovery_strategy.dart';

@lazySingleton
class TcpProbeDiscoveryStrategy implements DiscoveryStrategy {
  /// Strictly configured enterprise allowlist of identification ports.
  /// No unrestricted full port scanning is performed.
  static const Map<int, String> probePortAllowlist = {
    80: 'http',
    443: 'https',
    554: 'rtsp',
    9100: 'raw-print',
    631: 'ipp',
    22: 'ssh',
    445: 'smb',
    8000: 'http-alt',
    8080: 'http-proxy',
  };

  @override
  String get name => 'tcp_probe';

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    final openServices = <String>[];
    final perPortTimeout = Duration(
      milliseconds: (timeout.inMilliseconds / 2).clamp(300, 800).toInt(),
    );

    for (final entry in probePortAllowlist.entries) {
      final port = entry.key;
      final serviceName = entry.value;

      try {
        final socket = await Socket.connect(
          targetIp,
          port,
          timeout: perPortTimeout,
        );
        socket.destroy();
        openServices.add('port:$port ($serviceName)');
      } catch (_) {
        // Port closed or filtered, non-fatal
      }
    }

    if (openServices.isNotEmpty) {
      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        observedServices: openServices,
        evidenceDetails:
            'Open identification ports: ${openServices.join(', ')}',
      );
    } else {
      return StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'No allowlisted TCP ports open',
      );
    }
  }
}
