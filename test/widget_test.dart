import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/monitoring_service_client.dart';
import 'package:it_network_monitor/main.dart';

void main() {
  testWidgets('IT Network Monitor App smoke test', (WidgetTester tester) async {
    await getIt.reset();
    if (!getIt.isRegistered<MonitoringServiceClient>()) {
      getIt.registerSingleton<MonitoringServiceClient>(
        MonitoringServiceClient(baseUrl: 'http://127.0.0.1:4040'),
      );
    }
    await configureDependencies();

    await tester.pumpWidget(const ITNetworkMonitorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ITNetworkMonitorApp), findsOneWidget);
  });
}
