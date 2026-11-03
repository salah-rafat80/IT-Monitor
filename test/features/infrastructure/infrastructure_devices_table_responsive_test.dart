import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_state.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/widgets/infrastructure_devices_table.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';

class MockAuthCubit extends Mock implements AuthCubit {}

class MockInfrastructureCubit extends Mock implements InfrastructureCubit {}

void main() {
  late MockAuthCubit mockAuthCubit;
  late MockInfrastructureCubit mockInfraCubit;

  final adminUser = UserEntity(
    id: 1,
    username: 'admin',
    role: UserRole.admin,
    isEnabled: true,
    createdAt: DateTime(2026),
  );

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
    mockAuthCubit = MockAuthCubit();
    mockInfraCubit = MockInfrastructureCubit();

    when(() => mockAuthCubit.state).thenReturn(AuthAuthenticated(adminUser));
    when(
      () => mockAuthCubit.stream,
    ).thenAnswer((_) => Stream.value(AuthAuthenticated(adminUser)));

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
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: mockAuthCubit),
          BlocProvider<InfrastructureCubit>.value(value: mockInfraCubit),
        ],
        child: const Scaffold(
          body: SingleChildScrollView(
            child: InfrastructureDevicesTable(showHeaderActions: true),
          ),
        ),
      ),
    );
  }

  group('InfrastructureDevicesTable Responsive & Overflow Checks', () {
    testWidgets(
      'renders without overflow at exactly 663px width (reported crash boundary)',
      (tester) async {
        tester.view.physicalSize = const Size(663, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Total Assets: 2'), findsOneWidget);
        expect(find.text('Ping All Assets'), findsOneWidget);
      },
    );

    testWidgets('renders without overflow at compact 500px width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at wide 1200px width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
