import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/presentation/widgets/desktop_shell.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitored_devices_table.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitoring_summary_cards.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_display_summary_bar.dart';

class MockAuthCubit extends Mock implements AuthCubit {}

void main() {
  late MockAuthCubit mockAuthCubit;

  final adminUser = UserEntity(
    id: 1,
    username: 'admin',
    role: UserRole.admin,
    isEnabled: true,
    createdAt: DateTime(2026),
  );

  setUp(() {
    mockAuthCubit = MockAuthCubit();
    when(() => mockAuthCubit.state).thenReturn(AuthAuthenticated(adminUser));
    when(
      () => mockAuthCubit.stream,
    ).thenAnswer((_) => Stream.value(AuthAuthenticated(adminUser)));
  });

  group('Windows Responsive & DPI Scaling Audit (100%, 125%, 150%, 200%)', () {
    final sampleDevices = [
      MonitoredDevice(
        device: DeviceEntity(
          id: 1,
          name: 'DESKTOP-EXTREME-LONG-MACHINE-NAME-FOR-TESTING-PURPOSES',
          type: DeviceType.pc,
          ip: '192.168.100.254',
          ownerName:
              'عبدالرحمن محمد الشناوي المهندس الأول / Senior Staff Enterprise Systems Engineer',
          department:
              'إدارة تكنولوجيا المعلومات والاتصالات المتطورة / Advanced Information Systems',
          officeLocation:
              'مبنى الإدارة الرئيسي - الطابق الرابع - غرفة المراقبة والتحكم 402B',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity.initial(1).copyWith(
          status: DeviceStatusEnum.up,
          lastLatencyMs: 25,
          lastCheckAt: DateTime.now(),
        ),
      ),
      MonitoredDevice(
        device: DeviceEntity(
          id: 2,
          name: 'SHORT',
          type: DeviceType.laptop,
          ip: '10.0.0.1',
          ownerName: 'Ali',
          department: 'HR',
          officeLocation: 'FL1',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity.initial(2).copyWith(
          status: DeviceStatusEnum.down,
          consecutiveFailures: 5,
          lastFailureReason:
              'Destination host unreachable (responded by gateway 10.0.0.254)',
          lastCheckAt: DateTime.now(),
        ),
      ),
    ];

    final loadedState = MonitoringDashboardLoaded(
      allDevices: sampleDevices,
      filteredDevices: sampleDevices,
      isEngineRunning: true,
      isEnginePaused: false,
      config: const MonitoringConfig(),
      totalCount: 99999, // Large counter test
      upCount: 98765,
      degradedCount: 432,
      downCount: 789,
      unknownCount: 12,
      maintenanceCount: 1,
      activeIncidents: const [],
    );

    final viewports = [
      const Size(1024, 768), // XGA
      const Size(1280, 720), // 720p HD
      const Size(1366, 768), // 1366x768 Standard Laptop
      const Size(1920, 1080), // 1080p Full HD
    ];

    final dpiScales = [
      1.0, // 100% Normal
      1.25, // 125% Windows scaling
      1.5, // 150% High-DPI scaling
      2.0, // 200% Ultra-High DPI (4K display)
    ];

    Widget createTestApp({required Widget child}) {
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => child),
        ],
      );

      return BlocProvider<AuthCubit>.value(
        value: mockAuthCubit,
        child: MaterialApp.router(
          theme: ThemeData.dark(),
          routerConfig: router,
        ),
      );
    }

    for (final size in viewports) {
      for (final dpi in dpiScales) {
        testWidgets(
          'DesktopShell & Dashboard renders without overflow at ${size.width.toInt()}x${size.height.toInt()} @ ${(dpi * 100).toInt()}% DPI',
          (tester) async {
            tester.view.physicalSize = Size(
              size.width * dpi,
              size.height * dpi,
            );
            tester.view.devicePixelRatio = dpi;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              createTestApp(
                child: DesktopShell(
                  child: Scaffold(
                    body: Column(
                      children: [
                        MonitoringSummaryCards(state: loadedState),
                        Expanded(
                          child: MonitoredDevicesTable(
                            devices: sampleDevices,
                            userRole: UserRole.admin,
                            onSelectDevice: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            // Strict zero-overflow assertion
            expect(tester.takeException(), isNull);

            // Large counters must render without crashing or wrapping out of bounds
            expect(find.text('99999'), findsOneWidget);
            expect(find.text('98765'), findsOneWidget);
          },
        );
      }
    }

    testWidgets(
      'WallDisplaySummaryBar renders without overflow at 1366x768 at 125% and 150% scaling',
      (tester) async {
        for (final dpi in [1.25, 1.5]) {
          tester.view.physicalSize = Size(1366 * dpi, 768 * dpi);
          tester.view.devicePixelRatio = dpi;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WallDisplaySummaryBar(
                  totalCount: 37,
                  upCount: 35,
                  degradedCount: 1,
                  downCount: 1,
                  unknownCount: 0,
                  maintenanceCount: 0,
                  activeIncidentsCount: 0,
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('37'), findsOneWidget);
          expect(find.text('35'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'Live dynamic resizing down to narrow 800x600 window executes smoothly without crash',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestApp(
            child: DesktopShell(
              child: Scaffold(
                body: Column(
                  children: [
                    MonitoringSummaryCards(state: loadedState),
                    Expanded(
                      child: MonitoredDevicesTable(
                        devices: sampleDevices,
                        userRole: UserRole.admin,
                        onSelectDevice: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Dynamically shrink window live down to narrow 800x600 constraint
        await tester.binding.setSurfaceSize(const Size(800, 600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
