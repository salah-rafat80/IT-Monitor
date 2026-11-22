import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/theme/app_theme.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/device_status_chip.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

Widget _wrap(Widget child, {bool isDark = true}) {
  return MaterialApp(
    theme: AppTheme.buildTheme(
      palette: isDark ? AppPalette.defaultDark : AppPalette.defaultLight,
      isDark: isDark,
    ),
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('DeviceStatusChip Widget Tests (flutter-add-widget-test)', () {
    testWidgets('renders Connected when status is Up with 0 consecutive failures', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.up,
          compact: true,
        ),
      ));

      expect(find.text('Connected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders warning and failure count when status is Up but has consecutive failures', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.up,
          consecutiveFailures: 2,
          failureThreshold: 3,
          compact: true,
        ),
      ));

      expect(find.text('2/3 Fail'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders full text format when compact is false', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.up,
          consecutiveFailures: 1,
          failureThreshold: 3,
          compact: false,
        ),
      ));

      expect(
        find.text('Previously Online · 1/3 Failed Checks'),
        findsOneWidget,
      );
    });

    testWidgets('renders Disconnected when status is Down', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.down,
          compact: true,
        ),
      ));

      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('renders Degraded when status is Degraded', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.degraded,
          compact: true,
        ),
      ));

      expect(find.text('Degraded'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders Maintenance when status is maintenance or isMaintenance is true', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.up,
          isMaintenance: true,
          compact: true,
        ),
      ));

      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.byIcon(Icons.build_circle_rounded), findsOneWidget);
    });

    testWidgets('renders Stale when status is Stale', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.stale,
          compact: true,
        ),
      ));

      expect(find.text('Stale'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('renders Unknown when status is Unknown', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.unknown,
          compact: true,
        ),
      ));

      expect(find.text('Unknown'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('wraps chip in Tooltip when failureReason is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.down,
          failureReason: 'Connection timed out on port 80',
          compact: true,
        ),
      ));

      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);

      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, 'Latest Failure Reason: Connection timed out on port 80');
    });

    testWidgets('maintains accessible semantic text color in light mode', (tester) async {
      await tester.pumpWidget(_wrap(
        const DeviceStatusChip(
          status: DeviceStatusEnum.up,
          compact: true,
        ),
        isDark: false,
      ));

      expect(find.text('Connected'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Connected'));
      expect(textWidget.style?.color, isNotNull);
    });
  });
}
