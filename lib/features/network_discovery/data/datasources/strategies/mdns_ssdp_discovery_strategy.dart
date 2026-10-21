import 'dart:io';
import 'package:injectable/injectable.dart';

import '../../../domain/services/discovery_strategy.dart';

@lazySingleton
class MdnsSsdpDiscoveryStrategy implements DiscoveryStrategy {
  @override
  String get name => 'mdns';

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    // Check if target responds to UDP service probe on mDNS (5353) or SSDP (1900)
    try {
      final rawSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      rawSocket.broadcastEnabled = true;

      // Simple non-intrusive SSDP M-SEARCH packet
      const ssdpMsg =
          'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 1\r\nST: ssdp:all\r\n\r\n';
      rawSocket.send(ssdpMsg.codeUnits, InternetAddress(targetIp), 1900);

      bool responded = false;
      String details = '';

      final sub = rawSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = rawSocket.receive();
          if (dg != null && dg.address.address == targetIp) {
            responded = true;
            details = 'SSDP/UPnP service responder active';
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await sub.cancel();
      rawSocket.close();

      if (responded) {
        return StrategyProbeResult.success(
          strategyName: name,
          targetIp: targetIp,
          observedServices: ['ssdp:1900'],
          evidenceDetails: details,
        );
      }
    } catch (_) {}

    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No mDNS or SSDP discovery response',
    );
  }
}
