import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/di/injection.dart';
import 'package:it_network_monitor/main.dart';

void main() {
  testWidgets('IT Network Monitor App smoke test', (WidgetTester tester) async {
    await getIt.reset();
    await configureDependencies();

    await tester.pumpWidget(const ITNetworkMonitorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ITNetworkMonitorApp), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 22));
  });
}
