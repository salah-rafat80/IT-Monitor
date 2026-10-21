import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';

MonitoredDevice _device({
  required int id,
  required String ownerName,
  required String department,
  String ip = '192.168.1.1',
  String? location,
  String? switchName,
  DeviceType type = DeviceType.pc,
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
      status: DeviceStatusEnum.unknown,
      statusChangedAt: DateTime(2025),
    ),
  );
}

void main() {
  late TopologyGrouper grouper;

  setUp(() {
    grouper = const TopologyGrouper();
  });

  group('TopologyGrouper', () {
    test('1. Empty list produces empty result', () {
      final result = grouper.group([]);
      expect(result, isEmpty);
    });

    test('2. Single device with location and switch appears correctly', () {
      final md = _device(
        id: 1,
        ownerName: 'Ahmed',
        department: 'Finance',
        ip: '10.0.0.1',
        location: 'Floor 1',
        switchName: 'SW-F1-01',
      );

      final result = grouper.group([md]);

      expect(result.length, 1);
      expect(result[0].locationName, 'Floor 1');
      expect(result[0].switchGroups.length, 1);
      expect(result[0].switchGroups[0].switchName, 'SW-F1-01');
      expect(result[0].switchGroups[0].devices.length, 1);
      expect(result[0].switchGroups[0].devices[0].device.ownerName, 'Ahmed');
    });

    test('3. Device with no location goes to "Unknown Location"', () {
      final md = _device(
        id: 2,
        ownerName: 'Sara',
        department: 'IT',
        ip: '10.0.0.2',
        location: null,
        switchName: 'SW-01',
      );

      final result = grouper.group([md]);

      expect(result.length, 1);
      expect(result[0].locationName, 'Unknown Location');
    });

    test('4. Device with no switch name goes under null switch group', () {
      final md = _device(
        id: 3,
        ownerName: 'Omar',
        department: 'HR',
        ip: '10.0.0.3',
        location: 'Floor 2',
        switchName: null,
      );

      final result = grouper.group([md]);

      expect(result[0].switchGroups.length, 1);
      expect(result[0].switchGroups[0].switchName, isNull);
      expect(result[0].switchGroups[0].hasKnownSwitch, isFalse);
      expect(result[0].switchGroups[0].displayName, 'Unknown Switch');
    });

    test(
      '5. Devices in same location but different switches are grouped correctly',
      () {
        final devices = [
          _device(
            id: 1,
            ownerName: 'A',
            department: 'D1',
            ip: '1.1.1.1',
            location: 'Floor 1',
            switchName: 'SW-A',
          ),
          _device(
            id: 2,
            ownerName: 'B',
            department: 'D2',
            ip: '1.1.1.2',
            location: 'Floor 1',
            switchName: 'SW-B',
          ),
          _device(
            id: 3,
            ownerName: 'C',
            department: 'D3',
            ip: '1.1.1.3',
            location: 'Floor 1',
            switchName: 'SW-A',
          ),
        ];

        final result = grouper.group(devices);

        expect(result.length, 1);
        final loc = result[0];
        expect(loc.switchGroups.length, 2);
        // Sorted alphabetically: SW-A first
        expect(loc.switchGroups[0].switchName, 'SW-A');
        expect(loc.switchGroups[0].devices.length, 2);
        expect(loc.switchGroups[1].switchName, 'SW-B');
        expect(loc.switchGroups[1].devices.length, 1);
      },
    );

    test(
      '6. Devices across different locations are each in separate nodes',
      () {
        final devices = [
          _device(
            id: 1,
            ownerName: 'A',
            department: 'D',
            ip: '1.1',
            location: 'Floor 1',
            switchName: 'SW-1',
          ),
          _device(
            id: 2,
            ownerName: 'B',
            department: 'D',
            ip: '1.2',
            location: 'Floor 2',
            switchName: 'SW-2',
          ),
          _device(
            id: 3,
            ownerName: 'C',
            department: 'D',
            ip: '1.3',
            location: 'Floor 2',
            switchName: 'SW-2',
          ),
        ];

        final result = grouper.group(devices);

        expect(result.length, 2);
        // Alphabetical: Floor 1 first
        expect(result[0].locationName, 'Floor 1');
        expect(result[0].totalCount, 1);
        expect(result[1].locationName, 'Floor 2');
        expect(result[1].totalCount, 2);
      },
    );

    test(
      '7. Location nodes are sorted alphabetically, Unknown Location last',
      () {
        final devices = [
          _device(
            id: 1,
            ownerName: 'A',
            department: 'D',
            ip: '1.1',
            location: null,
          ),
          _device(
            id: 2,
            ownerName: 'B',
            department: 'D',
            ip: '1.2',
            location: 'Zebraroom',
          ),
          _device(
            id: 3,
            ownerName: 'C',
            department: 'D',
            ip: '1.3',
            location: 'Alpharoom',
          ),
        ];

        final result = grouper.group(devices);

        expect(result[0].locationName, 'Alpharoom');
        expect(result[1].locationName, 'Zebraroom');
        expect(result[2].locationName, 'Unknown Location');
      },
    );

    test('8. Within a switch group, devices are sorted by ownerName', () {
      final devices = [
        _device(
          id: 1,
          ownerName: 'Ziad',
          department: 'D',
          ip: '1.1',
          location: 'Floor 1',
          switchName: 'SW-01',
        ),
        _device(
          id: 2,
          ownerName: 'Ahmed',
          department: 'D',
          ip: '1.2',
          location: 'Floor 1',
          switchName: 'SW-01',
        ),
        _device(
          id: 3,
          ownerName: 'Omar',
          department: 'D',
          ip: '1.3',
          location: 'Floor 1',
          switchName: 'SW-01',
        ),
      ];

      final result = grouper.group(devices);
      final deviceNames = result[0].switchGroups[0].devices
          .map((d) => d.device.ownerName)
          .toList();

      expect(deviceNames, ['Ahmed', 'Omar', 'Ziad']);
    });

    test('9. Known switches appear before null switch group', () {
      final devices = [
        _device(
          id: 1,
          ownerName: 'A',
          department: 'D',
          ip: '1.1',
          location: 'Floor 1',
          switchName: null,
        ),
        _device(
          id: 2,
          ownerName: 'B',
          department: 'D',
          ip: '1.2',
          location: 'Floor 1',
          switchName: 'SW-01',
        ),
      ];

      final result = grouper.group(devices);
      expect(result[0].switchGroups[0].switchName, 'SW-01');
      expect(result[0].switchGroups[1].switchName, isNull);
    });

    test(
      '10. LocationNode.totalCount sums all devices across switch groups',
      () {
        final devices = [
          _device(
            id: 1,
            ownerName: 'A',
            department: 'D',
            ip: '1.1',
            location: 'Floor 1',
            switchName: 'SW-A',
          ),
          _device(
            id: 2,
            ownerName: 'B',
            department: 'D',
            ip: '1.2',
            location: 'Floor 1',
            switchName: 'SW-B',
          ),
          _device(
            id: 3,
            ownerName: 'C',
            department: 'D',
            ip: '1.3',
            location: 'Floor 1',
            switchName: 'SW-A',
          ),
        ];

        final result = grouper.group(devices);
        expect(result[0].totalCount, 3);
      },
    );

    test('11. Devices with same ip as different ids stay separate', () {
      // Two different devices — different IDs, same switch
      final devices = [
        _device(
          id: 10,
          ownerName: 'X',
          department: 'D',
          ip: '10.0.0.10',
          location: 'Floor 1',
          switchName: 'SW-01',
        ),
        _device(
          id: 11,
          ownerName: 'Y',
          department: 'D',
          ip: '10.0.0.11',
          location: 'Floor 1',
          switchName: 'SW-01',
        ),
      ];
      final result = grouper.group(devices);
      expect(result[0].switchGroups[0].devices.length, 2);
    });

    test(
      '12. Empty switch name string is treated as null (no known switch)',
      () {
        final md = _device(
          id: 5,
          ownerName: 'Test',
          department: 'IT',
          ip: '10.0.0.5',
          location: 'Floor 3',
          switchName: '',
        );

        final result = grouper.group([md]);
        expect(result[0].switchGroups[0].hasKnownSwitch, isFalse);
      },
    );
  });
}
