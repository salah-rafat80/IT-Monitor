import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/incidents/domain/repositories/incident_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_device_card.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_display_grid.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_display_header.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_display_summary_bar.dart';
import 'package:it_network_monitor/core/utils/result.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockMonitoringRepository extends Mock implements MonitoringRepository {}

class MockMonitoringScheduler extends Mock implements MonitoringScheduler {}

class MockIncidentRepository extends Mock implements IncidentRepository {}

void main() {
  late MockDeviceRepository mockDeviceRepo;
  late MockMonitoringRepository mockMonitoringRepo;
  late MockMonitoringScheduler mockScheduler;
  late MockIncidentRepository mockIncidentRepo;

  final testDevices = List.generate(
    37,
    (index) => DeviceEntity(
      id: index + 1,
      name: 'PC-${index + 1}',
      type: index % 2 == 0 ? DeviceType.pc : DeviceType.laptop,
      ip: '192.168.1.${index + 10}',
      ownerName: 'Owner ${index + 1}',
      department: index % 3 == 0
          ? 'IT'
          : (index % 3 == 1 ? 'Finance' : 'Operations'),
      officeLocation: 'Office ${(index % 4) + 1}',
      createdAt: DateTime.now(),
    ),
  );

  setUp(() {
    mockDeviceRepo = MockDeviceRepository();
    mockMonitoringRepo = MockMonitoringRepository();
    mockScheduler = MockMonitoringScheduler();
    mockIncidentRepo = MockIncidentRepository();

    when(
      () => mockDeviceRepo.bootstrapApprovedInventory(),
    ).thenAnswer((_) async => Result.success(37));
    when(
      () => mockDeviceRepo.getDevices(),
    ).thenAnswer((_) async => Result.success(testDevices));
    when(
      () => mockMonitoringRepo.getDeviceStatuses(),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => mockIncidentRepo.getActiveIncidents(),
    ).thenAnswer((_) async => Result.success([]));
    when(
      () => mockIncidentRepo.watchActiveIncidents(),
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => mockMonitoringRepo.watchAllDeviceStatuses(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockScheduler.isRunning).thenReturn(true);
    when(() => mockScheduler.isPaused).thenReturn(false);
    when(() => mockScheduler.config).thenReturn(const MonitoringConfig());
    when(() => mockScheduler.startMonitoring()).thenAnswer((_) {});
  });

  group('Wall Display Mode — Phase 9 Tests', () {
    testWidgets(
      '1. All 37 approved devices render on screen simultaneously without scroll physics',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
          mockIncidentRepo,
        );

        await cubit.initDashboard();

        final monitoredList = testDevices
            .map(
              (d) => MonitoredDevice(
                device: d,
                status: DeviceStatusEntity.initial(d.id),
              ),
            )
            .toList();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WallDisplayGrid(devices: monitoredList)),
          ),
        );

        await tester.pumpAndSettle();

        // Verify GridView has NeverScrollableScrollPhysics
        final gridFinder = find.byType(GridView);
        expect(gridFinder, findsOneWidget);

        final gridWidget = tester.widget<GridView>(gridFinder);
        expect(gridWidget.physics, isA<NeverScrollableScrollPhysics>());

        // Verify all 37 WallDeviceCard instances exist
        final cardFinder = find.byType(WallDeviceCard);
        expect(cardFinder, findsNWidgets(37));
      },
    );

    testWidgets(
      '2. WallDeviceCard displays Owner, Department, Device Name, IP, and Status Chip',
      (tester) async {
        final sampleDevice = MonitoredDevice(
          device: testDevices[0],
          status: DeviceStatusEntity(
            deviceId: testDevices[0].id,
            status: DeviceStatusEnum.up,
            lastLatencyMs: 4,
            statusChangedAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 120,
                child: WallDeviceCard(item: sampleDevice),
              ),
            ),
          ),
        );

        expect(find.text('Owner 1'), findsOneWidget);
        expect(find.textContaining('IT'), findsOneWidget);
        expect(find.textContaining('PC-1'), findsOneWidget);
        expect(find.textContaining('192.168.1.10'), findsOneWidget);
        expect(find.text('4ms'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Summary bar displays exact counts for total, status categories, and incidents',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: WallDisplaySummaryBar(
                totalCount: 37,
                upCount: 30,
                degradedCount: 2,
                downCount: 3,
                unknownCount: 1,
                maintenanceCount: 1,
                activeIncidentsCount: 5,
              ),
            ),
          ),
        );

        expect(find.text('37'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('1'), findsNWidgets(2)); // unknown and maintenance
        expect(find.text('5'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Header displays time, connection status, sort controls, and exit button',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool sortToggled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WallDisplayHeader(
                isConnected: true,
                lastUpdatedAt: DateTime.now(),
                currentSortBy: 'severity',
                onSortChanged: (newSort) {
                  sortToggled = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('IT NETWORK MONITOR'), findsOneWidget);
        expect(find.text('WALL DISPLAY'), findsOneWidget);
        expect(find.textContaining('CONNECTED'), findsOneWidget);
        expect(find.text('Exit [ESC]'), findsOneWidget);

        // Tap Sort button
        await tester.tap(find.text('Sort: Severity'));
        expect(sortToggled, isTrue);
      },
    );
  });
}
