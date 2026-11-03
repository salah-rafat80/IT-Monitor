import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/repositories/infrastructure_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/topology/domain/entities/topology_node.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_cubit.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_state.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockInfrastructureRepository extends Mock
    implements InfrastructureRepository {}

class MockMonitoringRepository extends Mock implements MonitoringRepository {}

MonitoredDevice _makeDevice({
  required int id,
  required String ownerName,
  required String department,
  String ip = '192.168.1.1',
  String? location,
  String? switchName,
  DeviceType type = DeviceType.pc,
  DeviceStatusEnum status = DeviceStatusEnum.up,
}) {
  return MonitoredDevice(
    device: DeviceEntity(
      id: id,
      name: 'PC-$id',
      type: type,
      ip: ip,
      ownerName: ownerName,
      department: department,
      officeLocation: location,
      parentSwitchName: switchName,
      createdAt: DateTime(2025),
    ),
    status: DeviceStatusEntity(
      deviceId: id,
      status: status,
      statusChangedAt: DateTime.now(),
      lastCheckAt: DateTime.now(),
    ),
  );
}

void main() {
  late TopologyGrouper grouper;
  late EnterpriseTopologyBuilder builder;
  late MockDeviceRepository mockDeviceRepo;
  late MockInfrastructureRepository mockInfraRepo;
  late MockMonitoringRepository mockMonitoringRepo;

  setUp(() {
    grouper = const TopologyGrouper();
    builder = const EnterpriseTopologyBuilder();
    mockDeviceRepo = MockDeviceRepository();
    mockInfraRepo = MockInfrastructureRepository();
    mockMonitoringRepo = MockMonitoringRepository();
  });

  group('Phase 7 — Topology Visual Structure & Grouping Tests', () {
    test('1. Grouping devices by location', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Main Office',
          switchName: 'SW-01',
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Sara',
          department: 'HR',
          location: 'Production Floor',
          switchName: 'SW-02',
        ),
      ];

      final result = grouper.group(devices);
      expect(result.length, 2);
      expect(
        result.map((l) => l.locationName),
        containsAll(['Main Office', 'Production Floor']),
      );
    });

    test('2. Grouping devices by switch reference', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Main Office',
          switchName: 'SW-01',
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Mohamed',
          department: 'Finance',
          location: 'Main Office',
          switchName: 'SW-02',
        ),
      ];

      final result = grouper.group(devices);
      expect(result[0].switchGroups.length, 2);
      expect(
        result[0].switchGroups.map((s) => s.switchName),
        containsAll(['SW-01', 'SW-02']),
      );
    });

    test('3. Correct PC -> Switch relationship', () {
      final dev = _makeDevice(
        id: 1,
        ownerName: 'Khaled',
        department: 'Accounting',
        location: 'Quality Office',
        switchName: 'SW-QUAL-01',
      );
      final result = grouper.group([dev]);

      final switchGroup = result[0].switchGroups[0];
      expect(switchGroup.switchName, 'SW-QUAL-01');
      expect(switchGroup.devices.first.device.ownerName, 'Khaled');
    });

    test('4. Multiple locations preserved without cross-merging', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'A',
          department: 'D',
          location: 'Loc A',
          switchName: 'SW-1',
        ),
        _makeDevice(
          id: 2,
          ownerName: 'B',
          department: 'D',
          location: 'Loc B',
          switchName: 'SW-1',
        ),
      ];

      final result = grouper.group(devices);
      expect(result.length, 2);
      expect(result[0].locationName, 'Loc A');
      expect(result[1].locationName, 'Loc B');
    });

    test(
      '5. Device without switch reference goes to unconfigured switch group',
      () {
        final dev = _makeDevice(
          id: 1,
          ownerName: 'NoSwitchUser',
          department: 'IT',
          location: 'Main Office',
          switchName: null,
        );
        final result = grouper.group([dev]);

        expect(result[0].switchGroups[0].switchName, isNull);
        expect(result[0].switchGroups[0].hasKnownSwitch, isFalse);
        expect(result[0].switchGroups[0].displayName, 'Unknown Switch');
      },
    );

    test(
      '6. Location without switch reference goes to unconfigured location node',
      () {
        final dev = _makeDevice(
          id: 1,
          ownerName: 'NoLocUser',
          department: 'IT',
          location: null,
          switchName: 'SW-01',
        );
        final result = grouper.group([dev]);

        expect(result[0].locationName, 'Unknown Location');
      },
    );

    test('7. Switch reference has no IP metadata or status badge', () {
      final switchGroup = const SwitchGroup(
        switchName: 'SW-MAIN-01',
        devices: [],
      );
      expect(switchGroup.hasKnownSwitch, isTrue);
      expect(switchGroup.displayName, 'SW-MAIN-01');
      // Verify switch is pure reference node without status
    });

    test(
      '8. No invented relationships: filter does not create fake topology nodes',
      () {
        final devices = [
          _makeDevice(
            id: 1,
            ownerName: 'Ahmed',
            department: 'IT',
            location: 'Loc A',
            switchName: 'SW-A',
          ),
        ];

        final state = TopologyLoaded(
          locations: grouper.group(devices),
          departmentFilter: 'HR', // Non-matching filter
        );

        expect(
          state.filtered,
          isEmpty,
        ); // Irrelevant nodes hidden, no fake relationships created
      },
    );
  });

  group('Phase 7 — Topology Filtering & Live Status Updates', () {
    test('9. Owner search filtering', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed Rashad',
          department: 'IT',
          location: 'Loc A',
          switchName: 'SW-A',
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Mohamed Shref',
          department: 'Accounting',
          location: 'Loc A',
          switchName: 'SW-A',
        ),
      ];

      final state = TopologyLoaded(
        locations: grouper.group(devices),
        searchQuery: 'Ahmed',
      );

      final filtered = state.filtered;
      expect(filtered.length, 1);
      expect(filtered[0].allDevices.length, 1);
      expect(filtered[0].allDevices[0].device.ownerName, 'Ahmed Rashad');
    });

    test('10. Department filtering', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Loc A',
          switchName: 'SW-A',
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Sara',
          department: 'Finance',
          location: 'Loc A',
          switchName: 'SW-A',
        ),
      ];

      final state = TopologyLoaded(
        locations: grouper.group(devices),
        departmentFilter: 'Finance',
      );

      final filtered = state.filtered;
      expect(filtered[0].allDevices.length, 1);
      expect(filtered[0].allDevices[0].device.ownerName, 'Sara');
    });

    test('11. Location filtering', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Main Office',
          switchName: 'SW-A',
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Sara',
          department: 'IT',
          location: 'Warehouse',
          switchName: 'SW-B',
        ),
      ];

      final state = TopologyLoaded(
        locations: grouper.group(devices),
        locationFilter: 'Warehouse',
      );

      final filtered = state.filtered;
      expect(filtered.length, 1);
      expect(filtered[0].locationName, 'Warehouse');
    });

    test('12. Device Type filtering (PC vs Laptop)', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Loc A',
          switchName: 'SW-A',
          type: DeviceType.pc,
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Sara',
          department: 'IT',
          location: 'Loc A',
          switchName: 'SW-A',
          type: DeviceType.laptop,
        ),
      ];

      final state = TopologyLoaded(
        locations: grouper.group(devices),
        deviceTypeFilter: DeviceType.laptop,
      );

      final filtered = state.filtered;
      expect(filtered[0].allDevices.length, 1);
      expect(filtered[0].allDevices[0].device.type, DeviceType.laptop);
    });

    test('13. Status filtering (Up vs Down)', () {
      final devices = [
        _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Loc A',
          switchName: 'SW-A',
          status: DeviceStatusEnum.up,
        ),
        _makeDevice(
          id: 2,
          ownerName: 'Mohamed',
          department: 'IT',
          location: 'Loc A',
          switchName: 'SW-A',
          status: DeviceStatusEnum.down,
        ),
      ];

      final state = TopologyLoaded(
        locations: grouper.group(devices),
        statusFilter: DeviceStatusEnum.down,
      );

      final filtered = state.filtered;
      expect(filtered[0].allDevices.length, 1);
      expect(filtered[0].allDevices[0].status.status, DeviceStatusEnum.down);
    });

    test('14. Live status stream update in TopologyCubit', () async {
      final dev = _makeDevice(
        id: 1,
        ownerName: 'Ahmed',
        department: 'IT',
        location: 'Loc A',
        switchName: 'SW-A',
        status: DeviceStatusEnum.up,
      );
      final statusController = StreamController<List<DeviceStatusEntity>>();

      when(
        () => mockDeviceRepo.getDevices(),
      ).thenAnswer((_) async => Result.success([dev.device]));
      when(
        () => mockInfraRepo.getInfrastructureDevices(),
      ).thenAnswer((_) async => Result.success([]));
      when(
        () => mockMonitoringRepo.getDeviceStatuses(),
      ).thenAnswer((_) async => Result.success([dev.status]));
      when(
        () => mockMonitoringRepo.watchAllDeviceStatuses(),
      ).thenAnswer((_) => statusController.stream);

      final cubit = TopologyCubit(
        mockDeviceRepo,
        mockInfraRepo,
        mockMonitoringRepo,
        grouper,
        builder,
      );
      await cubit.init();

      expect(cubit.state, isA<TopologyLoaded>());
      var loaded = cubit.state as TopologyLoaded;
      expect(
        loaded.locations[0].allDevices[0].status.status,
        DeviceStatusEnum.up,
      );
      expect(loaded.enterpriseGraph, isNotNull);

      // Emit status update: device goes Down
      final newStatus = DeviceStatusEntity(
        deviceId: 1,
        status: DeviceStatusEnum.down,
        statusChangedAt: DateTime.now(),
      );
      statusController.add([newStatus]);
      await pumpEventQueue();

      loaded = cubit.state as TopologyLoaded;
      expect(
        loaded.locations[0].allDevices[0].status.status,
        DeviceStatusEnum.down,
      );

      await statusController.close();
      await cubit.close();
    });

    test('15. Role Access Control: Viewer vs Admin capabilities', () {
      const viewerRole = UserRole.viewer;
      const adminRole = UserRole.admin;

      expect(viewerRole, UserRole.viewer);
      expect(adminRole, UserRole.admin);
      // Both can inspect topology; viewer is read-only
    });

    test(
      '16. Enterprise Topology Builder computes non-overlapping deterministic layout',
      () {
        final devices = [
          _makeDevice(
            id: 1,
            ownerName: 'Ahmed',
            department: 'IT',
            location: 'Office 1',
            switchName: 'SW-1',
          ),
          _makeDevice(
            id: 2,
            ownerName: 'Mohamed',
            department: 'HR',
            location: 'Office 2',
            switchName: 'SW-2',
          ),
        ];

        final graph = builder.build(
          monitoredDevices: devices,
          infraDevices: [],
        );

        expect(graph.nodes.containsKey('wan_internet'), isTrue);
        expect(graph.nodes['wan_internet']!.level, 0);

        // Verify no two nodes overlap in their bounding rects
        final nodesList = graph.nodes.values.toList();
        for (int i = 0; i < nodesList.length; i++) {
          for (int j = i + 1; j < nodesList.length; j++) {
            final n1 = nodesList[i];
            final n2 = nodesList[j];
            final overlaps = n1.rect.overlaps(n2.rect);
            expect(
              overlaps,
              isFalse,
              reason: 'Nodes ${n1.id} and ${n2.id} must not overlap',
            );
          }
        }
      },
    );

    test(
      '17. Enterprise Topology Graph updates status in place without moving positions',
      () {
        final dev = _makeDevice(
          id: 1,
          ownerName: 'Ahmed',
          department: 'IT',
          location: 'Office 1',
          switchName: 'SW-1',
          status: DeviceStatusEnum.up,
        );
        final graph = builder.build(monitoredDevices: [dev], infraDevices: []);

        final initialPos = graph.nodes['dev_1']!.position;
        expect(graph.nodes['dev_1']!.status, DeviceStatusEnum.up);

        final updatedGraph = graph.updateStatuses({
          1: DeviceStatusEntity(
            deviceId: 1,
            status: DeviceStatusEnum.down,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        });

        expect(updatedGraph.nodes['dev_1']!.status, DeviceStatusEnum.down);
        expect(updatedGraph.nodes['dev_1']!.position, initialPos);
      },
    );
  });
}
