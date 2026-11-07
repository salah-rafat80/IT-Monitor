import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_state.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/widgets/infrastructure_devices_table.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';

class MockInfrastructureCubit extends Mock implements InfrastructureCubit {}

void main() {
  late MockInfrastructureCubit mockInfraCubit;

  final List<UniFiDeviceEntity> testDevices = [
    UniFiDeviceEntity(
      id: 1,
      name: 'RNF-CORE-GW-01',
      ip: '192.168.22.1',
      role: UniFiDeviceRole.gateway,
      factoryId: 'rnf',
      location: 'Server Room',
      isEnabled: true,
      createdAt: DateTime(2026),
    ),
    UniFiDeviceEntity(
      id: 2,
      name: 'RNF-AP-WAREHOUSE-NORTH',
      ip: '192.168.22.50',
      role: UniFiDeviceRole.accessPoint,
      factoryId: 'rnf',
      location: 'Warehouse Floor 1',
      isEnabled: true,
      createdAt: DateTime(2026),
    ),
  ];

  final testStatuses = {
    10001: DeviceStatusEntity.initial(10001).copyWith(
      status: DeviceStatusEnum.up,
      lastLatencyMs: 2,
      lastCheckAt: DateTime.now(),
    ),
    10002: DeviceStatusEntity.initial(10002).copyWith(
      status: DeviceStatusEnum.up,
      lastLatencyMs: 14,
      lastCheckAt: DateTime.now(),
    ),
  };

  setUp(() {
    mockInfraCubit = MockInfrastructureCubit();

    final infraState = InfrastructureState(
      devices: testDevices,
      statuses: testStatuses,
    );
    when(() => mockInfraCubit.state).thenReturn(infraState);
    when(
      () => mockInfraCubit.stream,
    ).thenAnswer((_) => Stream.value(infraState));
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: BlocProvider<InfrastructureCubit>.value(
        value: mockInfraCubit,
        child: const Scaffold(
          body: SingleChildScrollView(child: InfrastructureDevicesTable()),
        ),
      ),
    );
  }

  testWidgets(
    'InfrastructureDevicesTable renders without horizontal RenderFlex overflow in responsive layout',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(InfrastructureDevicesTable), findsOneWidget);
      expect(find.text('RNF-CORE-GW-01'), findsOneWidget);
    },
  );

  testWidgets(
    'InfrastructureDevicesTable adapts correctly on standard 1366x768 desktop viewport without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('RNF-CORE-GW-01'), findsOneWidget);
      expect(find.text('RNF-AP-WAREHOUSE-NORTH'), findsOneWidget);
    },
  );

  testWidgets(
    'InfrastructureDevicesTable adapts on constrained 1024x768 display without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('RNF-CORE-GW-01'), findsOneWidget);
      expect(find.text('RNF-AP-WAREHOUSE-NORTH'), findsOneWidget);
    },
  );
}
