import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockMonitoringRepository extends Mock implements MonitoringRepository {}

class MockMonitoringScheduler extends Mock implements MonitoringScheduler {}

void main() {
  late MockDeviceRepository mockDeviceRepo;
  late MockMonitoringRepository mockMonitoringRepo;
  late MockMonitoringScheduler mockScheduler;
  late StreamController<List<DeviceStatusEntity>> statusController;

  setUp(() {
    mockDeviceRepo = MockDeviceRepository();
    mockMonitoringRepo = MockMonitoringRepository();
    mockScheduler = MockMonitoringScheduler();
    statusController = StreamController<List<DeviceStatusEntity>>.broadcast();

    when(
      () =>
          mockDeviceRepo.bootstrapApprovedInventory(force: any(named: 'force')),
    ).thenAnswer((_) async => Result.success(0));
    when(() => mockScheduler.isRunning).thenReturn(false);
    when(() => mockScheduler.isPaused).thenReturn(false);
    when(() => mockScheduler.config).thenReturn(const MonitoringConfig());
  });

  tearDown(() {
    statusController.close();
  });

  group('Section 1.B: Monitoring Scheduler & Service Failure Resilience Tests', () {
    test('1. Client never starts scheduler in normal client mode', () async {
      when(
        () => mockDeviceRepo.getDevices(),
      ).thenAnswer((_) async => Result.success([]));
      when(
        () => mockMonitoringRepo.getDeviceStatuses(),
      ).thenAnswer((_) async => Result.success([]));
      when(
        () => mockMonitoringRepo.watchAllDeviceStatuses(),
      ).thenAnswer((_) => statusController.stream);

      final cubit = MonitoringDashboardCubit(
        mockDeviceRepo,
        mockMonitoringRepo,
        mockScheduler,
      );
      await cubit.initDashboard(startScheduler: false);

      verifyNever(() => mockScheduler.startMonitoring());
      await cubit.close();
    });

    test(
      '2. Client startup when database/service is unavailable reports honest error state',
      () async {
        when(() => mockDeviceRepo.getDevices()).thenAnswer(
          (_) async =>
              Result.failure(const DatabaseFailure('Service DB unreachable')),
        );
        when(
          () => mockMonitoringRepo.getDeviceStatuses(),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockMonitoringRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        await cubit.initDashboard();

        expect(cubit.state, isA<MonitoringDashboardError>());
        final err = cubit.state as MonitoringDashboardError;
        expect(err.message, contains('Service DB unreachable'));
        await cubit.close();
      },
    );

    test(
      '3. Stale/interrupted stream emits honest error state without fabricating healthy status',
      () async {
        final sampleDevice = DeviceEntity(
          id: 1,
          name: 'PC-01',
          type: DeviceType.pc,
          ip: '192.168.1.10',
          ownerName: 'User',
          department: 'IT',
          createdAt: DateTime.now(),
        );

        when(
          () => mockDeviceRepo.getDevices(),
        ).thenAnswer((_) async => Result.success([sampleDevice]));
        when(
          () => mockMonitoringRepo.getDeviceStatuses(),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockMonitoringRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );
        await cubit.initDashboard();
        expect(cubit.state, isA<MonitoringDashboardLoaded>());

        // Simulate abrupt stream termination with error from service disconnect
        statusController.addError('Connection reset by service host');
        await pumpEventQueue();

        expect(cubit.state, isA<MonitoringDashboardError>());
        final err = cubit.state as MonitoringDashboardError;
        expect(err.message, contains('Connection reset'));
        await cubit.close();
      },
    );

    test(
      '4. Repeated initDashboard calls cancel previous subscriptions without duplicating listeners',
      () async {
        when(
          () => mockDeviceRepo.getDevices(),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockMonitoringRepo.getDeviceStatuses(),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockMonitoringRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );

        // Call init 3 times consecutively (e.g. repeated navigation)
        await cubit.initDashboard();
        await cubit.initDashboard();
        await cubit.initDashboard();

        // Only 1 active listener should be subscribed to the broadcast stream
        expect(statusController.hasListener, isTrue);

        await cubit.close();
        expect(statusController.hasListener, isFalse);
      },
    );

    test('5. refreshDevices handles scheduler exception gracefully', () async {
      when(
        () => mockDeviceRepo.getDevices(),
      ).thenAnswer((_) async => Result.success([]));
      when(
        () => mockMonitoringRepo.getDeviceStatuses(),
      ).thenAnswer((_) async => Result.success([]));
      when(
        () => mockMonitoringRepo.watchAllDeviceStatuses(),
      ).thenAnswer((_) => statusController.stream);
      when(
        () => mockScheduler.triggerAllChecks(force: true),
      ).thenThrow(Exception('RPC pipe broken'));

      final cubit = MonitoringDashboardCubit(
        mockDeviceRepo,
        mockMonitoringRepo,
        mockScheduler,
      );
      await cubit.initDashboard();

      await cubit.refreshDevices();
      expect(cubit.state, isA<MonitoringDashboardError>());
      final err = cubit.state as MonitoringDashboardError;
      expect(err.message, contains('RPC pipe broken'));
      await cubit.close();
    });
  });
}
