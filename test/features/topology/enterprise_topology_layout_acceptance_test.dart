import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/topology/domain/entities/enterprise_topology_models.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_device_card.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_topology_summary_bar.dart';

void main() {
  const builder = EnterpriseTopologyBuilder();

  final realAps = [
    UniFiDeviceEntity(
      id: 1,
      name: 'Packing Area AP',
      ip: '192.168.7.6',
      role: UniFiDeviceRole.accessPoint,
      location: 'Factory Administration Upper Area',
      isCriticalInfrastructure: true,
      requiresAdminConfirmation: false,
      linkedSubnets: const ['192.168.7.0/24'],
      siteName: 'Factory Administration Upper Area',
      isEnabled: true,
      isReadOnly: false,
      createdAt: DateTime(2026),
    ),
    UniFiDeviceEntity(
      id: 2,
      name: 'Meeting Room AP',
      ip: '192.168.7.4',
      role: UniFiDeviceRole.accessPoint,
      location: 'Factory Administration Upper Area',
      isCriticalInfrastructure: true,
      requiresAdminConfirmation: false,
      linkedSubnets: const ['192.168.7.0/24'],
      siteName: 'Factory Administration Upper Area',
      isEnabled: true,
      isReadOnly: false,
      createdAt: DateTime(2026),
    ),
    UniFiDeviceEntity(
      id: 3,
      name: 'FM Office AP',
      ip: '192.168.7.2',
      role: UniFiDeviceRole.accessPoint,
      location: 'Factory Administration Upper Area',
      isCriticalInfrastructure: true,
      requiresAdminConfirmation: false,
      linkedSubnets: const ['192.168.7.0/24'],
      siteName: 'Factory Administration Upper Area',
      isEnabled: true,
      isReadOnly: false,
      createdAt: DateTime(2026),
    ),
    UniFiDeviceEntity(
      id: 4,
      name: 'IoT_Palitizer AP',
      ip: '192.168.8.5',
      role: UniFiDeviceRole.accessPoint,
      location: 'Lower Area',
      isCriticalInfrastructure: true,
      requiresAdminConfirmation: false,
      linkedSubnets: const ['192.168.8.0/24'],
      siteName: 'Lower Area',
      isEnabled: true,
      isReadOnly: false,
      createdAt: DateTime(2026),
    ),
  ];

  final realEndpoints = [
    MonitoredDevice(
      device: DeviceEntity(
        id: 101,
        name: 'PC-MainOffice-01',
        type: DeviceType.pc,
        ip: '192.168.27.10',
        ownerName: 'Ahmed Ali',
        department: 'IT',
        officeLocation: 'Main Office',
        createdAt: DateTime(2026),
      ),
      status: DeviceStatusEntity(
        deviceId: 101,
        status: DeviceStatusEnum.up,
        statusChangedAt: DateTime(2026),
        lastLatencyMs: 1,
      ),
    ),
    MonitoredDevice(
      device: DeviceEntity(
        id: 102,
        name: 'Laptop-Warehouse-01',
        type: DeviceType.laptop,
        ip: '192.168.22.15',
        ownerName: 'Khaled Omar',
        department: 'Logistics',
        officeLocation: 'Warehouse',
        createdAt: DateTime(2026),
      ),
      status: DeviceStatusEntity(
        deviceId: 102,
        status: DeviceStatusEnum.up,
        statusChangedAt: DateTime(2026),
        lastLatencyMs: 4,
      ),
    ),
  ];

  group('Enterprise Topology Layout Acceptance Tests', () {
    test(
      '1. Hierarchy: WAN (L0) -> Gateway (L1) -> Switches (L2) -> APs (L3) -> Endpoints (L4)',
      () {
        final graph = builder.build(
          monitoredDevices: realEndpoints,
          infraDevices: realAps,
          infraStatuses: {
            '192.168.7.6': DeviceStatusEnum.up,
            '192.168.7.4': DeviceStatusEnum.up,
            '192.168.7.2': DeviceStatusEnum.up,
            '192.168.8.5': DeviceStatusEnum.up,
          },
        );

        expect(graph.nodes.containsKey('wan_internet'), isTrue);
        expect(graph.nodes['wan_internet']!.level, 0);

        // Gateways
        final gateways = graph.nodes.values.where((n) => n.level == 1).toList();
        expect(gateways.isNotEmpty, isTrue);
        for (final gw in gateways) {
          expect(gw.category, TopologyDeviceCategory.gateway);
        }

        // Switches
        final switches = graph.nodes.values.where((n) => n.level == 2).toList();
        expect(switches.isNotEmpty, isTrue);
        for (final sw in switches) {
          expect(sw.category, TopologyDeviceCategory.switchDevice);
        }

        // APs
        final aps = graph.nodes.values.where((n) => n.level == 3).toList();
        expect(aps.length, 4);
        for (final ap in aps) {
          expect(ap.category, TopologyDeviceCategory.accessPoint);
        }

        // Endpoints
        final endpoints = graph.nodes.values
            .where((n) => n.level == 4)
            .toList();
        expect(endpoints.length, 2);
      },
    );

    test(
      '2. Left-to-Right Coordinate Ordering: Level 0 X < Level 1 X < Level 2 X < Level 3 X < Level 4 X',
      () {
        final graph = builder.build(
          monitoredDevices: realEndpoints,
          infraDevices: realAps,
          infraStatuses: {
            '192.168.7.6': DeviceStatusEnum.up,
            '192.168.7.4': DeviceStatusEnum.up,
            '192.168.7.2': DeviceStatusEnum.up,
            '192.168.8.5': DeviceStatusEnum.up,
          },
        );

        final wan = graph.nodes['wan_internet']!;
        final gws = graph.nodes.values.where((n) => n.level == 1).toList();
        final sws = graph.nodes.values.where((n) => n.level == 2).toList();
        final aps = graph.nodes.values.where((n) => n.level == 3).toList();
        final clients = graph.nodes.values.where((n) => n.level == 4).toList();

        for (final gw in gws) {
          expect(wan.position.dx, lessThan(gw.position.dx));
        }
        for (final sw in sws) {
          expect(gws.first.position.dx, lessThan(sw.position.dx));
        }
        for (final ap in aps) {
          expect(sws.first.position.dx, lessThan(ap.position.dx));
        }
        for (final client in clients) {
          expect(aps.first.position.dx, lessThan(client.position.dx));
        }
      },
    );

    test('3. Non-overlapping Bounding Rectangles across all nodes', () {
      final graph = builder.build(
        monitoredDevices: realEndpoints,
        infraDevices: realAps,
      );
      final allNodes = graph.nodes.values.toList();

      for (int i = 0; i < allNodes.length; i++) {
        for (int j = i + 1; j < allNodes.length; j++) {
          final n1 = allNodes[i];
          final n2 = allNodes[j];
          expect(
            n1.rect.overlaps(n2.rect),
            isFalse,
            reason:
                '${n1.id} (${n1.rect}) and ${n2.id} (${n2.rect}) must not overlap',
          );
        }
      }
    });

    test(
      '4. Inferred location switch groups are marked inferred without synthetic port counts',
      () {
        final graph = builder.build(
          monitoredDevices: realEndpoints,
          infraDevices: realAps,
          infraStatuses: {
            '192.168.7.6': DeviceStatusEnum.up,
            '192.168.7.4': DeviceStatusEnum.up,
            '192.168.7.2': DeviceStatusEnum.up,
            '192.168.8.5': DeviceStatusEnum.up,
          },
        );
        final swMain = graph.nodes['sw_main_office'];
        expect(swMain, isNotNull);
        expect(swMain!.isInferred, isTrue);
        expect(swMain.activePortCount, isNull);
      },
    );

    test('5. Stable device coordinates between refreshes', () {
      final graph1 = builder.build(
        monitoredDevices: realEndpoints,
        infraDevices: realAps,
      );
      final graph2 = builder.build(
        monitoredDevices: realEndpoints,
        infraDevices: realAps,
      );

      for (final id in graph1.nodes.keys) {
        expect(graph1.nodes[id]!.position, equals(graph2.nodes[id]!.position));
      }
    });

    test('6. In-place status updates without shifting node coordinates', () {
      final graph = builder.build(
        monitoredDevices: realEndpoints,
        infraDevices: realAps,
      );
      final oldPos = graph.nodes['dev_101']!.position;

      final updated = graph.updateStatuses({
        101: DeviceStatusEntity(
          deviceId: 101,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      });

      expect(updated.nodes['dev_101']!.status, DeviceStatusEnum.down);
      expect(updated.nodes['dev_101']!.position, oldPos);
    });

    testWidgets(
      '7. EnterpriseDeviceCard renders name, IP, and status border correctly',
      (tester) async {
        final graph = builder.build(
          monitoredDevices: realEndpoints,
          infraDevices: realAps,
          infraStatuses: {
            '192.168.7.6': DeviceStatusEnum.up,
            '192.168.7.4': DeviceStatusEnum.up,
            '192.168.7.2': DeviceStatusEnum.up,
            '192.168.8.5': DeviceStatusEnum.up,
          },
        );
        final node = graph.nodes['dev_101']!;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: EnterpriseDeviceCard(node: node)),
          ),
        );

        expect(find.text('PC-MainOffice-01'), findsOneWidget);
        expect(find.text('192.168.27.10'), findsOneWidget);
        expect(find.text('PC'), findsOneWidget);
      },
    );

    testWidgets(
      '8. EnterpriseTopologySummaryBar displays category ratios and search',
      (tester) async {
        final graph = builder.build(
          monitoredDevices: realEndpoints,
          infraDevices: realAps,
          infraStatuses: {
            '192.168.7.6': DeviceStatusEnum.up,
            '192.168.7.4': DeviceStatusEnum.up,
            '192.168.7.2': DeviceStatusEnum.up,
            '192.168.8.5': DeviceStatusEnum.up,
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnterpriseTopologySummaryBar(
                stats: graph.categoryStats,
                searchQuery: '',
                onSearchChanged: (_) {},
                onClearSearch: () {},
              ),
            ),
          ),
        );

        expect(find.text('Gateway: '), findsOneWidget);
        expect(find.text('Switch: '), findsOneWidget);
        expect(find.text('AP: '), findsOneWidget);
        expect(find.text('4/4'), findsOneWidget); // 4 online out of 4 UniFi APs
      },
    );

    test(
      '9. Compact Mode: Large branch (e.g. 15 endpoints) distributes into dual columns without overlapping',
      () {
        final largeBranchEndpoints = List.generate(
          15,
          (i) => MonitoredDevice(
            device: DeviceEntity(
              id: 200 + i,
              name: 'PC-MainOffice-${i + 1}',
              type: DeviceType.pc,
              ip: '192.168.27.${10 + i}',
              ownerName: 'Staff $i',
              department: 'Accounting',
              officeLocation: 'Main Office',
              createdAt: DateTime(2026),
            ),
            status: DeviceStatusEntity(
              deviceId: 200 + i,
              status: DeviceStatusEnum.up,
              statusChangedAt: DateTime(2026),
            ),
          ),
        );

        final graph = builder.build(
          monitoredDevices: largeBranchEndpoints,
          infraDevices: realAps,
        );

        // Verify that endpoints are distributed across two distinct X columns (Col A and Col B)
        final mainOfficeEndpoints = graph.nodes.values
            .where(
              (n) => n.level == 4 && (n.title.startsWith('PC-MainOffice-')),
            )
            .toList();

        final distinctXPositions = mainOfficeEndpoints
            .map((n) => n.position.dx)
            .toSet()
            .toList();
        expect(
          distinctXPositions.length,
          2,
          reason: '15 endpoints must distribute into 2 compact columns',
        );

        // Verify no overlap between any two nodes
        final allNodes = graph.nodes.values.toList();
        for (int i = 0; i < allNodes.length; i++) {
          for (int j = i + 1; j < allNodes.length; j++) {
            final n1 = allNodes[i];
            final n2 = allNodes[j];
            expect(
              n1.rect.overlaps(n2.rect),
              isFalse,
              reason: '${n1.title} and ${n2.title} must not overlap',
            );
          }
        }

        // Verify diagram height is substantially compact (less than 1,200px for this branch)
        final branchMaxY = mainOfficeEndpoints
            .map((n) => n.position.dy + n.size.height)
            .reduce((a, b) => a > b ? a : b);
        final branchMinY = mainOfficeEndpoints
            .map((n) => n.position.dy)
            .reduce((a, b) => a < b ? a : b);
        final branchSpanY = branchMaxY - branchMinY;
        expect(
          branchSpanY,
          lessThan(650.0),
          reason:
              'Dual column layout must keep 15 endpoints branch under 650px height',
        );
      },
    );

    test(
      '10. Full Inventory Simulation (38 devices across 9 switches) is noticeably compact',
      () {
        // Simulate real production database layout
        final locations = [
          ('Main Office', 15),
          ('Warehouse', 7),
          ('Quality Office', 6),
          ('Production Floor', 4),
          ('Maintenance Dept', 2),
          ('SparePart', 1),
          ('Safety Office', 1),
          ('Logistics Office', 1),
          ('IT Office', 1),
        ];

        final allSimulated = <MonitoredDevice>[];
        int devId = 1;
        for (final loc in locations) {
          for (int i = 0; i < loc.$2; i++) {
            allSimulated.add(
              MonitoredDevice(
                device: DeviceEntity(
                  id: devId++,
                  name: '${loc.$1}-$i',
                  type: DeviceType.pc,
                  ip: '192.168.27.$devId',
                  ownerName: 'Operator $devId',
                  department: loc.$1,
                  officeLocation: loc.$1,
                  createdAt: DateTime(2026),
                ),
                status: DeviceStatusEntity(
                  deviceId: devId,
                  status: DeviceStatusEnum.up,
                  statusChangedAt: DateTime(2026),
                ),
              ),
            );
          }
        }

        final graph = builder.build(
          monitoredDevices: allSimulated,
          infraDevices: realAps,
        );

        // Verify total nodes = 38 endpoints + 4 APs + 9 switches + 2 gateways + 1 WAN = 54 nodes
        expect(graph.nodes.length, 54);

        // Verify total canvas height is substantially more compact than previous 5,300px
        expect(
          graph.canvasSize.height,
          lessThan(2200.0),
          reason: 'Full topology height must be under 2200px (was ~5300px)',
        );

        // Verify zero bounding rectangle overlaps across all 54 nodes
        final nodeList = graph.nodes.values.toList();
        for (int i = 0; i < nodeList.length; i++) {
          for (int j = i + 1; j < nodeList.length; j++) {
            final n1 = nodeList[i];
            final n2 = nodeList[j];
            expect(
              n1.rect.overlaps(n2.rect),
              isFalse,
              reason:
                  '${n1.title} (${n1.rect}) and ${n2.title} (${n2.rect}) must not overlap',
            );
          }
        }
      },
    );
  });
}
