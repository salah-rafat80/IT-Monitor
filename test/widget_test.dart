import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/main.dart';

void main() {
  testWidgets('IT Network Monitor App smoke test', (WidgetTester tester) async {
    await configureDependencies();

    await tester.pumpWidget(const ITNetworkMonitorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Monitoring Dashboard'), findsOneWidget);
  });
}
