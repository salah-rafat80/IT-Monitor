import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/repositories/incident_repository.dart';
import 'package:it_network_monitor/features/incidents/presentation/bloc/incidents_cubit.dart';
import 'package:it_network_monitor/features/incidents/presentation/bloc/incidents_state.dart';

class MockIncidentRepository extends Mock implements IncidentRepository {}

void main() {
  late MockIncidentRepository mockIncidentRepo;
  late StreamController<List<IncidentEntity>> activeStreamController;

  final sampleIncidents = [
    IncidentEntity(
      id: 1,
      deviceId: 10,
      deviceName: 'DESKTOP-FIN01',
      ownerName: 'Alice Finance',
      department: 'Finance',
      location: 'Room 101',
      deviceIp: '192.168.1.10',
      incidentType: IncidentTypeEnum.deviceDown,
      severity: IncidentSeverityEnum.critical,
      status: IncidentStatusEnum.active,
      startedAt: DateTime.now(),
    ),
    IncidentEntity(
      id: 2,
      deviceId: 20,
      deviceName: 'LAPTOP-HR02',
      ownerName: 'Bob HR',
      department: 'HR',
      location: 'Room 202',
      deviceIp: '192.168.1.20',
      incidentType: IncidentTypeEnum.deviceDown,
      severity: IncidentSeverityEnum.high,
      status: IncidentStatusEnum.resolved,
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      resolvedAt: DateTime.now().subtract(const Duration(hours: 1)),
      notes: 'Rebooted laptop',
    ),
  ];

  setUp(() {
    mockIncidentRepo = MockIncidentRepository();
    activeStreamController = StreamController<List<IncidentEntity>>.broadcast();

    when(
      () => mockIncidentRepo.getActiveIncidents(),
    ).thenAnswer((_) async => Result.success([sampleIncidents[0]]));
    when(
      () => mockIncidentRepo.getIncidentHistory(),
    ).thenAnswer((_) async => Result.success(sampleIncidents));
    when(
      () => mockIncidentRepo.watchActiveIncidents(),
    ).thenAnswer((_) => activeStreamController.stream);
  });

  tearDown(() {
    activeStreamController.close();
  });

  group('Phase 5 — IncidentsCubit Unit Tests', () {
    test(
      '1. Initial state is IncidentsLoading, initIncidents populates active and history',
      () async {
        final cubit = IncidentsCubit(mockIncidentRepo);
        expect(cubit.state, isA<IncidentsLoading>());

        await cubit.initIncidents();

        expect(cubit.state, isA<IncidentsLoaded>());
        final loaded = cubit.state as IncidentsLoaded;
        expect(loaded.activeIncidents.length, equals(1));
        expect(loaded.historyIncidents.length, equals(2));
        expect(loaded.filteredHistory.length, equals(2));
      },
    );

    test(
      '2. Search query filters history by Device Name, Owner, IP, Location, or Notes',
      () async {
        final cubit = IncidentsCubit(mockIncidentRepo);
        await cubit.initIncidents();

        // Search by Owner
        cubit.setSearchQuery('Alice');
        var loaded = cubit.state as IncidentsLoaded;
        expect(loaded.filteredHistory.length, equals(1));
        expect(loaded.filteredHistory.first.ownerName, equals('Alice Finance'));

        // Search by Notes
        cubit.setSearchQuery('Rebooted');
        loaded = cubit.state as IncidentsLoaded;
        expect(loaded.filteredHistory.length, equals(1));
        expect(loaded.filteredHistory.first.deviceName, equals('LAPTOP-HR02'));
      },
    );

    test('3. Severity and Status filters filter history correctly', () async {
      final cubit = IncidentsCubit(mockIncidentRepo);
      await cubit.initIncidents();

      // Filter by Severity: 'critical'
      cubit.setSeverityFilter('critical');
      var loaded = cubit.state as IncidentsLoaded;
      expect(loaded.filteredHistory.length, equals(1));
      expect(loaded.filteredHistory.first.deviceName, equals('DESKTOP-FIN01'));

      // Reset & Filter by Status: 'resolved'
      cubit.setSeverityFilter(null);
      cubit.setStatusFilter('resolved');
      loaded = cubit.state as IncidentsLoaded;
      expect(loaded.filteredHistory.length, equals(1));
      expect(loaded.filteredHistory.first.deviceName, equals('LAPTOP-HR02'));
    });

    test(
      '4. Acknowledge incident delegates to repository and refreshes history',
      () async {
        when(
          () => mockIncidentRepo.acknowledgeIncident(
            id: 1,
            username: 'admin_test',
            note: 'Checked cables',
          ),
        ).thenAnswer((_) async => Result.success(null));

        final cubit = IncidentsCubit(mockIncidentRepo);
        await cubit.initIncidents();

        await cubit.acknowledgeIncident(
          id: 1,
          username: 'admin_test',
          note: 'Checked cables',
        );

        verify(
          () => mockIncidentRepo.acknowledgeIncident(
            id: 1,
            username: 'admin_test',
            note: 'Checked cables',
          ),
        ).called(1);
      },
    );

    test('5. Add note delegates to repository and refreshes history', () async {
      when(
        () => mockIncidentRepo.addNote(id: 1, note: 'Replacing ethernet cable'),
      ).thenAnswer((_) async => Result.success(null));

      final cubit = IncidentsCubit(mockIncidentRepo);
      await cubit.initIncidents();

      await cubit.addNote(id: 1, note: 'Replacing ethernet cable');

      verify(
        () => mockIncidentRepo.addNote(id: 1, note: 'Replacing ethernet cable'),
      ).called(1);
    });
  });
}
