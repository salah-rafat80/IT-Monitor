import 'dart:io';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';

void main(List<String> args) async {
  int port = 8080;
  if (args.contains('--port')) {
    final idx = args.indexOf('--port');
    if (idx + 1 < args.length) {
      port = int.tryParse(args[idx + 1]) ?? 8080;
    }
  } else if (Platform.environment.containsKey('PORT')) {
    port = int.tryParse(Platform.environment['PORT']!) ?? 8080;
  }

  final service = MonitoringServiceServer(port: port);
  await service.start();

  ProcessSignal.sigint.watch().listen((_) async {
    await service.stop();
    exit(0);
  });
}
