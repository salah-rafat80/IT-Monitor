import 'dart:io';
import 'package:injectable/injectable.dart';

import '../../../domain/services/discovery_strategy.dart';

@lazySingleton
class OnvifDiscoveryStrategy implements DiscoveryStrategy {
  @override
  String get name => 'onvif';

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    // 1. Direct non-intrusive probe on standard RTSP camera port 554
    bool rtspOpen = false;
    try {
      final socket = await Socket.connect(
        targetIp,
        554,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      rtspOpen = true;
    } catch (_) {}

    // 2. Direct probe on ONVIF / Camera Web Management alternate port 8000
    bool port8000Open = false;
    try {
      final socket = await Socket.connect(
        targetIp,
        8000,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      port8000Open = true;
    } catch (_) {}

    if (rtspOpen) {
      final services = ['rtsp:554'];
      if (port8000Open) services.add('onvif-mgmt:8000');

      return StrategyProbeResult.success(
        strategyName: name,
        targetIp: targetIp,
        observedServices: services,
        evidenceDetails: 'Video streaming endpoint (RTSP 554) active',
      );
    }

    return StrategyProbeResult.failure(
      strategyName: name,
      targetIp: targetIp,
      errorMessage: 'No ONVIF or RTSP video streaming endpoints responding',
    );
  }
}
