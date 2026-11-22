import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/devices/presentation/bloc/devices_cubit.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/repositories/infrastructure_repository.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_cubit.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_state.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockInfrastructureRepository extends Mock
    implements InfrastructureRepository {}

class MockMonitoringRepository extends Mock implements MonitoringRepository {}

class MockMonitoringScheduler extends Mock implements MonitoringScheduler {}

class MockPingChecker extends Mock implements PingChecker {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      UniFiDeviceEntity(
        id: 1,
        name: 'test',
        ip: '192.168.1.1',
        role: UniFiDeviceRole.accessPoint,
        isCriticalInfrastructure: false,
        requiresAdminConfirmation: false,
        linkedSubnets: const [],
        siteName: 'default',
        isEnabled: true,
        createdAt: DateTime.now(),
      ),
    );
    registerFallbackValue(
      DeviceStatusEntity(
        deviceId: 1,
        status: DeviceStatusEnum.unknown,
        statusChangedAt: DateTime.now(),
      ),
    );
  });

  group('Factory Select Bounded Timeouts & Inferred Status Regression Tests', () {
    testWidgets('1. DevicesCubit times out and emits DevicesError when repository hangs', (tester) async {
      final mockDeviceRepo = MockDeviceRepository();
      final hangingCompleter = Completer<Result<List<DeviceEntity>>>();

      when(() => mockDeviceRepo.getDevices(factoryId: any(named: 'factoryId')))
          .thenAnswer((_) => hangingCompleter.future);

      final cubit = DevicesCubit(mockDeviceRepo);
      expect(cubit.state, isA<DevicesInitial>());

      // Trigger load
      unawaited(cubit.loadDevices(factoryId: 'bnf'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(cubit.state, isA<DevicesLoading>());

      // Advance time past 10s timeout
      await tester.pump(const Duration(seconds: 11));

      expect(cubit.state, isA<DevicesError>());
      final err = cubit.state as DevicesError;
      expect(err.message, contains('timed out'));

      await cubit.close();
    });

    testWidgets('2. InfrastructureCubit times out and clears loading when repository hangs', (tester) async {
      final mockInfraRepo = MockInfrastructureRepository();
      final mockMonitoringRepo = MockMonitoringRepository();
      final mockPingChecker = MockPingChecker();
      final hangingCompleter = Completer<Result<List<UniFiDeviceEntity>>>();

      when(() => mockInfraRepo.watchInfrastructureDevices(factoryId: any(named: 'factoryId')))
          .thenAnswer((_) => const Stream.empty());
      when(() => mockInfraRepo.watchInfrastructureDevices())
          .thenAnswer((_) => const Stream.empty());
      when(() => mockMonitoringRepo.watchAllDeviceStatuses())
          .thenAnswer((_) => const Stream.empty());
      when(() => mockInfraRepo.bootstrapVerifiedAccessPoints())
          .thenAnswer((_) async => Result.success(null));
      when(() => mockInfraRepo.bootstrapVerifiedSwitches())
          .thenAnswer((_) async => Result.success(null));
      when(() => mockInfraRepo.getInfrastructureDevices(factoryId: any(named: 'factoryId')))
          .thenAnswer((_) => hangingCompleter.future);

      final cubit = InfrastructureCubit(
        mockInfraRepo,
        mockMonitoringRepo,
        mockPingChecker,
      );

      unawaited(cubit.loadInfrastructure(factoryId: 'bnf'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(cubit.state.isLoading, isTrue);

      // Advance time past 10s timeout
      await tester.pump(const Duration(seconds: 11));

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.errorMessage, contains('timed out'));

      await cubit.close();
    });

    testWidgets('3. TopologyCubit times out and emits TopologyError when device repo hangs', (tester) async {
      final mockDeviceRepo = MockDeviceRepository();
      final mockInfraRepo = MockInfrastructureRepository();
      final mockMonitoringRepo = MockMonitoringRepository();
      final hangingCompleter = Completer<Result<List<DeviceEntity>>>();

      when(() => mockDeviceRepo.getDevices(factoryId: any(named: 'factoryId')))
          .thenAnswer((_) => hangingCompleter.future);

      final cubit = TopologyCubit(
        mockDeviceRepo,
        mockInfraRepo,
        mockMonitoringRepo,
        const TopologyGrouper(),
        const EnterpriseTopologyBuilder(),
      );

      unawaited(cubit.init('bnf'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(cubit.state, isA<TopologyLoading>());

      // Advance time past 10s timeout
      await tester.pump(const Duration(seconds: 11));

      expect(cubit.state, isA<TopologyError>());
      final err = cubit.state as TopologyError;
      expect(err.message, contains('timed out'));

      await cubit.close();
    });

    test('4. Switches are never probed directly: pingDevice rejects switch ping', () async {
      final mockInfraRepo = MockInfrastructureRepository();
      final mockMonitoringRepo = MockMonitoringRepository();
      final mockPingChecker = MockPingChecker();

      when(() => mockInfraRepo.watchInfrastructureDevices()).thenAnswer((_) => const Stream.empty());
      when(() => mockMonitoringRepo.watchAllDeviceStatuses()).thenAnswer((_) => const Stream.empty());

      final cubit = InfrastructureCubit(
        mockInfraRepo,
        mockMonitoringRepo,
        mockPingChecker,
      );

      final switchDevice = UniFiDeviceEntity(
        id: 42,
        name: 'RNF Core Switch 1',
        ip: '',
        role: UniFiDeviceRole.switchDevice,
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const [],
        siteName: 'rnf',
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      final result = await cubit.pingDevice(switchDevice);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Switches have no IP addresses'));
      verifyNever(() => mockPingChecker.checkPing(deviceId: any(named: 'deviceId'), targetIp: any(named: 'targetIp')));

      await cubit.close();
    });

    test('5. Switch status is inferred: UP when any child is UP, DOWN when all children are DOWN', () {
      final builder = const EnterpriseTopologyBuilder();
      final now = DateTime.now();

      final switch1 = UniFiDeviceEntity(
        id: 1,
        name: 'RNF Core Switch 1 (Floor 1 - West)',
        ip: '',
        role: UniFiDeviceRole.switchDevice,
        factoryId: 'rnf',
        location: 'Floor 1 - Server Area',
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const [],
        siteName: 'default',
        isEnabled: true,
        createdAt: now,
      );

      final device1 = DeviceEntity(
        id: 101,
        name: 'PC-WEST-01',
        type: DeviceType.pc,
        ip: '192.168.22.10',
        ownerName: 'Worker 1',
        department: 'Production',
        factoryId: 'rnf',
        parentSwitchId: 1,
        parentSwitchName: 'RNF Core Switch 1 (Floor 1 - West)',
        createdAt: now,
      );

      // Case A: Endpoint is UP -> Switch is UP
      final graphUp = builder.build(
        monitoredDevices: [
          MonitoredDevice(
            device: device1,
            status: DeviceStatusEntity(
              deviceId: 101,
              status: DeviceStatusEnum.up,
              statusChangedAt: now,
              lastCheckAt: now,
            ),
          ),
        ],
        infraDevices: [switch1],
        factoryId: 'rnf',
      );

      expect(graphUp.nodes['sw_1']?.status, DeviceStatusEnum.up);
      expect(graphUp.nodes['sw_1']?.isInferred, isFalse);
      expect(graphUp.nodes['sw_1']?.isMonitored, isFalse);

      // Case B: Endpoint is DOWN -> Switch is DOWN
      final graphDown = builder.build(
        monitoredDevices: [
          MonitoredDevice(
            device: device1,
            status: DeviceStatusEntity(
              deviceId: 101,
              status: DeviceStatusEnum.down,
              statusChangedAt: now,
              lastCheckAt: now,
            ),
          ),
        ],
        infraDevices: [switch1],
        factoryId: 'rnf',
      );

      expect(graphDown.nodes['sw_1']?.status, DeviceStatusEnum.down);

      // Case C: No attached endpoints -> Switch is UNKNOWN
      final graphEmpty = builder.build(
        monitoredDevices: [],
        infraDevices: [switch1],
        factoryId: 'rnf',
      );

      expect(graphEmpty.nodes['sw_1']?.status, DeviceStatusEnum.unknown);
    });

    test(
      '6. MonitoringDashboardCubit transitions from Loading to Loaded when switching to an empty factory (e.g. BNF)',
      () async {
        final mockDeviceRepo = MockDeviceRepository();
        final mockMonitoringRepo = MockMonitoringRepository();
        final mockScheduler = MockMonitoringScheduler();

        when(() => mockMonitoringRepo.watchAllDeviceStatuses())
            .thenAnswer((_) => const Stream.empty());
        when(() => mockMonitoringRepo.getDeviceStatuses())
            .thenAnswer((_) async => Result.success([]));
        when(() => mockScheduler.isRunning).thenReturn(false);
        when(() => mockScheduler.isPaused).thenReturn(false);
        when(() => mockScheduler.config).thenReturn(const MonitoringConfig());

        // For BNF, getDevices returns empty list (0 devices)
        when(() => mockDeviceRepo.getDevices(factoryId: 'bnf'))
            .thenAnswer((_) async => Result.success([]));

        final cubit = MonitoringDashboardCubit(
          mockDeviceRepo,
          mockMonitoringRepo,
          mockScheduler,
        );

        await cubit.setFactoryFilter('bnf');

        // Must emit MonitoringDashboardLoaded and NOT stay stuck in MonitoringDashboardLoading
        expect(cubit.state, isA<MonitoringDashboardLoaded>());
        final loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.allDevices, isEmpty);
        expect(loaded.filteredDevices, isEmpty);
        expect(loaded.totalCount, equals(0));

        await cubit.close();
      },
    );
  });
}
