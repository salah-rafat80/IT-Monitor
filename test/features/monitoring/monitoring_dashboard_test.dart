import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/device_status_chip.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitored_devices_table.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockMonitoringRepository extends Mock implements MonitoringRepository {}

class MockMonitoringScheduler extends Mock implements MonitoringScheduler {}

void main() {
  late MockDeviceRepository mockDeviceRepo;
  late MockMonitoringRepository mockMonitoringRepo;
  late MockMonitoringScheduler mockScheduler;
  late StreamController<List<DeviceStatusEntity>> statusStreamController;

  final sampleDevices = [
    DeviceEntity(
      id: 1,
      name: 'DESKTOP-FIN01',
      type: DeviceType.pc,
      ip: '192.168.1.10',
      ownerName: 'Alice Finance',
      department: 'Finance',
      officeLocation: 'Room 101',
      isEnabled: true,
      createdAt: DateTime.now(),
    ),
    DeviceEntity(
      id: 2,
      name: 'LAPTOP-HR02',
      type: DeviceType.laptop,
      ip: '192.168.1.20',
      ownerName: 'Bob HR',
      department: 'HR',
      officeLocation: 'Room 202',
      isEnabled: true,
      createdAt: DateTime.now(),
    ),
    DeviceEntity(
      id: 3,
      name: 'DESKTOP-IT03',
      type: DeviceType.pc,
      ip: '192.168.1.30',
      ownerName: 'Charlie IT',
      department: 'IT',
      officeLocation: 'Server Room',
      isEnabled: false,
      createdAt: DateTime.now(),
    ),
  ];

  final sampleStatuses = [
    DeviceStatusEntity.initial(1).copyWith(
      status: DeviceStatusEnum.up,
      lastLatencyMs: 15,
      lastCheckAt: DateTime.now(),
    ),
    DeviceStatusEntity.initial(2).copyWith(
      status: DeviceStatusEnum.down,
      consecutiveFailures: 3,
      lastCheckAt: DateTime.now(),
    ),
    DeviceStatusEntity.initial(3).copyWith(
      status: DeviceStatusEnum.maintenance,
      isMaintenance: true,
      lastCheckAt: DateTime.now(),
    ),
  ];

  setUp(() {
    mockDeviceRepo = MockDeviceRepository();
    mockMonitoringRepo = MockMonitoringRepository();
    mockScheduler = MockMonitoringScheduler();
    statusStreamController =
        StreamController<List<DeviceStatusEntity>>.broadcast();

    when(
      () =>
          mockDeviceRepo.bootstrapApprovedInventory(force: any(named: 'force')),
    ).thenAnswer((_) async => Result.success(0));
    when(
      () => mockDeviceRepo.getDevices(),
    ).thenAnswer((_) async => Result.success(sampleDevices));
    when(
      () => mockMonitoringRepo.getDeviceStatuses(),
    ).thenAnswer((_) async => Result.success(sampleStatuses));
    when(
      () => mockMonitoringRepo.watchAllDeviceStatuses(),
    ).thenAnswer((_) => statusStreamController.stream);

    when(() => mockScheduler.isRunning).thenReturn(true);
    when(() => mockScheduler.isPaused).thenReturn(false);
    when(() => mockScheduler.config).thenReturn(const MonitoringConfig());
    when(() => mockScheduler.startMonitoring()).thenAnswer((_) {});
    when(() => mockScheduler.stopMonitoring()).thenAnswer((_) {});
    when(
      () => mockScheduler.triggerAllChecks(force: any(named: 'force')),
    ).thenAnswer((_) async => true);
  });

  tearDown(() {
    statusStreamController.close();
  });

  group('Phase 4 — MonitoringDashboardCubit Unit Tests', () {
    test(
      '1. Initial state is Loading, initDashboard populates devices & statuses',
      () async {
        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        expect(cubit.state, isA<MonitoringDashboardLoading>());

        await cubit.initDashboard();

        expect(cubit.state, isA<MonitoringDashboardLoaded>());
        final loaded = cubit.state as MonitoringDashboardLoaded;

        expect(loaded.totalCount, equals(3));
        expect(loaded.upCount, equals(1));
        expect(loaded.downCount, equals(1));
        expect(loaded.maintenanceCount, equals(1));

        // Client mode: scheduler must NOT be started automatically by default
        verifyNever(() => mockScheduler.startMonitoring());
      },
    );

    test(
      '1b. initDashboard with startScheduler: true explicitly starts scheduler when not running',
      () async {
        when(() => mockScheduler.isRunning).thenReturn(false);
        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        await cubit.initDashboard(startScheduler: true);
        verify(() => mockScheduler.startMonitoring()).called(1);
      },
    );

    test(
      '2. Search query filters by Owner Name, Department, Device Name, and IP',
      () async {
        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        await cubit.initDashboard();

        // Search by Owner
        cubit.setSearchQuery('Alice');
        var loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.filteredDevices.length, equals(1));
        expect(
          loaded.filteredDevices.first.device.ownerName,
          equals('Alice Finance'),
        );

        // Search by IP
        cubit.setSearchQuery('192.168.1.20');
        loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.filteredDevices.length, equals(1));
        expect(loaded.filteredDevices.first.device.name, equals('LAPTOP-HR02'));
      },
    );

    test(
      '3. Status, Department, and Type filters correctly filter items',
      () async {
        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        await cubit.initDashboard();

        // Filter by Status: 'down'
        cubit.setStatusFilter('down');
        var loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.filteredDevices.length, equals(1));
        expect(loaded.filteredDevices.first.device.name, equals('LAPTOP-HR02'));

        // Reset & Filter by Type: 'laptop'
        cubit.setStatusFilter(null);
        cubit.setTypeFilter('laptop');
        loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.filteredDevices.length, equals(1));
        expect(loaded.filteredDevices.first.device.name, equals('LAPTOP-HR02'));
      },
    );

    test('4. Sorting by Owner Name, IP, and Status works correctly', () async {
      final cubit = MonitoringDashboardCubit(
        mockDeviceRepo,
        mockMonitoringRepo,
        mockScheduler,
      );
      await cubit.initDashboard();

      // Default sorting is owner ascending ('Alice Finance')
      var loaded = cubit.state as MonitoringDashboardLoaded;
      expect(
        loaded.filteredDevices.first.device.ownerName,
        equals('Alice Finance'),
      );

      // Toggling 'owner' switches to descending ('Charlie IT')
      cubit.setSorting('owner');
      loaded = cubit.state as MonitoringDashboardLoaded;
      expect(
        loaded.filteredDevices.first.device.ownerName,
        equals('Charlie IT'),
      );
    });

    test(
      '5. Live stream updates trigger state emissions automatically',
      () async {
        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        await cubit.initDashboard();

        // Update Device 1 status to Down via stream
        final updatedStatus = DeviceStatusEntity.initial(1).copyWith(
          status: DeviceStatusEnum.down,
          consecutiveFailures: 3,
          lastCheckAt: DateTime.now(),
        );

        statusStreamController.add([updatedStatus]);
        await Future.delayed(Duration.zero);

        final loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.downCount, equals(2)); // Device 1 and Device 2 now down
      },
    );
  });

  group('Phase 4 — Dashboard UI Widget Tests', () {
    testWidgets(
      '6. DeviceStatusChip renders BOTH icon and text for every status',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  DeviceStatusChip(status: DeviceStatusEnum.up),
                  DeviceStatusChip(status: DeviceStatusEnum.degraded),
                  DeviceStatusChip(status: DeviceStatusEnum.down),
                  DeviceStatusChip(status: DeviceStatusEnum.unknown),
                  DeviceStatusChip(
                    status: DeviceStatusEnum.maintenance,
                    isMaintenance: true,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Degraded'), findsOneWidget);
        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.text('Unknown'), findsOneWidget);
        expect(find.text('Maintenance'), findsOneWidget);

        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
        expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.build_circle_rounded), findsOneWidget);
      },
    );

    testWidgets(
      '7. MonitoredDevicesTable renders prioritized Owner, Department, Device Name, IP, Status',
      (tester) async {
        final monitoredList = [
          MonitoredDevice(device: sampleDevices[0], status: sampleStatuses[0]),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MonitoredDevicesTable(
                devices: monitoredList,
                isAdmin: false,
                onSelectDevice: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Alice Finance'), findsOneWidget);
        expect(find.text('Finance'), findsOneWidget);
        expect(find.text('DESKTOP-FIN01'), findsOneWidget);
        expect(find.text('192.168.1.10'), findsOneWidget);
        expect(find.text('Room 101'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
      },
    );

    testWidgets(
      '8. Viewer role renders read-only table without Admin action triggers',
      (tester) async {
        final monitoredList = [
          MonitoredDevice(device: sampleDevices[0], status: sampleStatuses[0]),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MonitoredDevicesTable(
                devices: monitoredList,
                isAdmin: false,
                onSelectDevice: (_) {},
              ),
            ),
          ),
        );

        // Trigger Manual Check and Set Maintenance tooltip buttons must NOT exist for Viewer
        expect(find.byTooltip('Trigger Manual Check'), findsNothing);
        expect(find.byTooltip('Set Maintenance'), findsNothing);
      },
    );

    testWidgets('9. Admin role renders management action buttons', (
      tester,
    ) async {
      final monitoredList = [
        MonitoredDevice(device: sampleDevices[0], status: sampleStatuses[0]),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonitoredDevicesTable(
              devices: monitoredList,
              isAdmin: true,
              onSelectDevice: (_) {},
              onTriggerCheck: (_) {},
              onToggleMaintenance: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Trigger Manual Check'), findsOneWidget);
      expect(find.byTooltip('Set Maintenance'), findsOneWidget);
    });
  });
}
