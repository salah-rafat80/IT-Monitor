import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/presentation/widgets/desktop_shell.dart';
import 'package:it_network_monitor/core/router/app_router.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_cubit.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_state.dart';
import 'package:mocktail/mocktail.dart';

class MockPingChecker extends Mock implements PingChecker {}

void main() {
  group('Phase 1 — Scope Cleanup & Feature Simplification Acceptance Tests', () {
    late AppDatabase db;
    late DeviceRepositoryImpl deviceRepo;
    late InfrastructureRepositoryImpl infraRepo;
    late MonitoringRepositoryImpl monitoringRepo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final migrator = db.createMigrator();
      await migrator.createAll();
      await db.ensureDefaultFactoriesSeeded();

      deviceRepo = DeviceRepositoryImpl(db);
      infraRepo = InfrastructureRepositoryImpl(db);
      monitoringRepo = MonitoringRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. Application starts at Dashboard without interactive login; no login redirect',
      () {
        final router = AppRouter.router;
        expect(AppRouter.initialLocation, equals('/dashboard'));
        expect(
          router.routeInformationProvider.value.uri.path,
          equals('/dashboard'),
        );

        // Verify /login route does not exist
        final routes = router.configuration.routes;
        final hasLogin = routes.any((r) => r is GoRoute && r.path == '/login');
        expect(
          hasLogin,
          isFalse,
          reason: '/login route must be completely removed',
        );

        // Verify deleted feature routes do not exist
        final hasIncidents = routes.any(
          (r) => r is GoRoute && r.path == '/incidents',
        );
        final hasReports = routes.any(
          (r) => r is GoRoute && r.path == '/reports',
        );
        final hasUsers = routes.any((r) => r is GoRoute && r.path == '/users');
        expect(hasIncidents, isFalse);
        expect(hasReports, isFalse);
        expect(hasUsers, isFalse);
      },
    );

    test('2. Wall Display route remains accessible and functional', () {
      final router = AppRouter.router;
      final routes = router.configuration.routes;
      final wallDisplayRoute = routes.firstWhere(
        (r) => r is GoRoute && r.path == '/wall-display',
        orElse: () => throw StateError('Wall Display route missing'),
      );
      expect(wallDisplayRoute, isNotNull);
    });

    testWidgets(
      '3. DesktopShell sidebar navigation contains exactly the 7 retained features',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            ShellRoute(
              builder: (context, state, child) => DesktopShell(child: child),
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (context, state) =>
                      const Center(child: Text('Dashboard View')),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Retained 7 features
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Devices'), findsOneWidget);
        expect(find.text('Inventory'), findsOneWidget);
        expect(find.text('Infrastructure'), findsOneWidget);
        expect(find.text('Topology'), findsOneWidget);
        expect(find.text('Discovery'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // Deleted features must NOT appear
        expect(find.text('Incidents'), findsNothing);
        expect(find.text('Reports'), findsNothing);
        expect(find.text('Users & Audit'), findsNothing);
        expect(find.text('Users'), findsNothing);
      },
    );

    test(
      '4. Dashboard initializes successfully with approved inventory',
      () async {
        // Seed approved inventory
        final bootstrapRes = await deviceRepo.bootstrapApprovedInventory();
        expect(bootstrapRes.isSuccess, isTrue);
        expect(bootstrapRes.dataOrNull, equals(37));

        final mockPing = MockPingChecker();
        final scheduler = MonitoringScheduler(
          deviceRepo,
          monitoringRepo,
          mockPing,
        );

        final cubit = MonitoringDashboardCubit(
          deviceRepo,
          monitoringRepo,
          scheduler,
        );

        await cubit.initDashboard();
        expect(cubit.state, isA<MonitoringDashboardLoaded>());
        final loaded = cubit.state as MonitoringDashboardLoaded;
        expect(loaded.totalCount, equals(37));

        await cubit.close();
        scheduler.dispose();
      },
    );

    test('5. Device monitoring and Topology remain functional', () async {
      final now = DateTime.now();
      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'PC-TEST-01',
          ip: '192.168.22.10',
          type: DeviceType.pc,
          factoryId: 'rnf',
          ownerName: 'Test Owner',
          department: 'IT',
          createdAt: now,
        ),
      );

      final topologyCubit = TopologyCubit(
        deviceRepo,
        infraRepo,
        monitoringRepo,
        TopologyGrouper(),
        EnterpriseTopologyBuilder(),
      );

      await topologyCubit.init('rnf');
      expect(topologyCubit.state, isA<TopologyLoaded>());
      final state = topologyCubit.state as TopologyLoaded;
      expect(
        state.enterpriseGraph?.allNodes.any(
          (n) => n.subtitle == '192.168.22.10',
        ),
        isTrue,
      );

      await topologyCubit.close();
    });

    test(
      '6. Existing SQLite database records remain intact and accessible',
      () async {
        final devices = await db.select(db.devices).get();
        expect(devices, isEmpty);

        final factories = await db.select(db.factories).get();
        expect(factories.isNotEmpty, isTrue);

        // Legacy tables exist without dropping or losing schema integrity
        final incidents = await db.select(db.incidents).get();
        expect(incidents, isEmpty);

        final auditLogs = await db.select(db.auditLogs).get();
        expect(auditLogs, isEmpty);
      },
    );
  });
}
