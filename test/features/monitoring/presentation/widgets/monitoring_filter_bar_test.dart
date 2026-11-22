import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitoring_filter_bar.dart';

class MockMonitoringDashboardCubit extends Mock
    implements MonitoringDashboardCubit {}

void main() {
  late MockMonitoringDashboardCubit mockCubit;

  setUp(() {
    mockCubit = MockMonitoringDashboardCubit();
  });

  MonitoringDashboardLoaded createLoadedState({required String sortBy}) {
    return MonitoringDashboardLoaded(
      allDevices: const [],
      filteredDevices: const [],
      sortBy: sortBy,
      isEngineRunning: true,
      isEnginePaused: false,
      config: const MonitoringConfig(),
      totalCount: 0,
      upCount: 0,
      degradedCount: 0,
      downCount: 0,
      unknownCount: 0,
      maintenanceCount: 0,
    );
  }

  Widget buildTestWidget(MonitoringDashboardLoaded state) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MonitoringFilterBar(
            state: state,
            cubit: mockCubit,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'MonitoringFilterBar renders cleanly when sortBy is "severity" without throwing AssertionError',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = createLoadedState(sortBy: 'severity');

      await tester.pumpWidget(buildTestWidget(state));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MonitoringFilterBar), findsOneWidget);
      expect(find.text('Severity'), findsOneWidget);
    },
  );

  testWidgets(
    'MonitoringFilterBar handles unlisted sortBy value gracefully via defensive fallback without crashing',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = createLoadedState(sortBy: 'unknown_sort_column');

      await tester.pumpWidget(buildTestWidget(state));
      await tester.pumpAndSettle();

      // No AssertionError must be thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(MonitoringFilterBar), findsOneWidget);
    },
  );
}
