import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/presentation/widgets/app_empty_state.dart';
import 'package:it_network_monitor/core/presentation/widgets/app_error_card.dart';
import 'package:it_network_monitor/core/presentation/widgets/app_skeleton.dart';
import 'package:it_network_monitor/core/theme/app_colors.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitored_devices_table.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';

void main() {
  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [
          AppColors.defaultDark,
        ],
      ),
      home: Scaffold(body: child),
    );
  }

  group('Unhappy-Path Core Widgets & Resilient States', () {
    testWidgets('AppSkeleton displays pulse shimmer without exceptions', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: [
              const AppSkeleton(width: 100, height: 20),
              AppSkeleton.summaryCards(count: 3),
              AppSkeleton.table(rowCount: 3, columnCount: 4),
            ],
          ),
        ),
      );

      expect(find.byType(AppSkeleton), findsWidgets);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppSkeleton.table handles tight bounded constraints without vertical overflow', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: 409.4,
            width: 990.6,
            child: Column(
              children: [
                const SizedBox(height: 44),
                Expanded(
                  child: AppSkeleton.table(rowCount: 8, columnCount: 9),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppEmptyState.noFilterResults fires onClearFilters callback', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.noFilterResults(
            query: 'NonExistentDevice',
            onClearFilters: () => cleared = true,
          ),
        ),
      );

      expect(find.textContaining('NonExistentDevice'), findsOneWidget);
      expect(find.text('Clear All Filters'), findsOneWidget);

      await tester.tap(find.text('Clear All Filters'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('AppEmptyState.firstUse fires primary action callback', (tester) async {
      bool actionTriggered = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppEmptyState.firstUse(
            entityName: 'UniFi AP',
            actionLabel: 'Add UniFi AP',
            onAction: () => actionTriggered = true,
          ),
        ),
      );

      expect(find.text('No UniFi AP registered yet'), findsOneWidget);
      expect(find.text('Add UniFi AP'), findsOneWidget);

      await tester.tap(find.text('Add UniFi AP'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });

    testWidgets('AppErrorCard displays explanation and triggers retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        wrapWithTheme(
          AppErrorCard(
            title: 'Socket Disconnected',
            message: 'Authoritative telemetry link timed out after 5000ms',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Socket Disconnected'), findsOneWidget);
      expect(find.text('Authoritative telemetry link timed out after 5000ms'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);

      await tester.tap(find.text('Retry Connection'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('MonitoredDevicesTable renders AppEmptyState when list is empty', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        wrapWithTheme(
          MonitoredDevicesTable(
            devices: const [],
            onSelectDevice: (_) {},
            onClearFilters: () => cleared = true,
          ),
        ),
      );

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Clear All Filters'), findsOneWidget);

      await tester.tap(find.text('Clear All Filters'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('MonitoredDevicesTable renders extreme strings without RenderFlex overflow', (tester) async {
      final extremeDevice = MonitoredDevice(
        device: DeviceEntity(
          id: 1,
          name: 'Super_Long_Industrial_Core_Distribution_Switch_Rack_42_Cabinet_B_Floor_3_Sector_9',
          ip: '192.168.100.254',
          ownerName: 'Dr. Very Long-Named Administrator With Many Degrees and Extraordinary Titles',
          department: 'Department of Advanced Cybernetic Systems & Industrial Automation Research',
          officeLocation: 'Underground Server Vault Sector B Sub-level 4 Near Cooling Duct 12',
          type: DeviceType.pc,
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
        status: DeviceStatusEntity(
          deviceId: 1,
          status: DeviceStatusEnum.up,
          lastCheckAt: DateTime.now(),
          statusChangedAt: DateTime.now(),
          lastLatencyMs: 4,
          consecutiveFailures: 0,
        ),
      );

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpWidget(
        wrapWithTheme(
          SingleChildScrollView(
            child: MonitoredDevicesTable(
              devices: [extremeDevice],
              onSelectDevice: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
