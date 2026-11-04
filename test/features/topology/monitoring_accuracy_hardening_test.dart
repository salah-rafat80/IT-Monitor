import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitored_devices_table.dart';
import 'package:it_network_monitor/features/topology/domain/entities/enterprise_topology_models.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_device_card.dart';

void main() {
  group('Monitoring Accuracy Hardening & Audit Tests', () {
    const builder = EnterpriseTopologyBuilder();

    final infraSw = UniFiDeviceEntity(
      id: 50,
      name: 'Switch-Core',
      ip: '192.168.22.10',
      role: UniFiDeviceRole.switchDevice,
      location: 'Server Room',
      isCriticalInfrastructure: true,
      requiresAdminConfirmation: false,
      linkedSubnets: const ['192.168.22.0/24'],
      siteName: 'Server Room',
      isEnabled: true,
      isReadOnly: false,
      createdAt: DateTime(2026),
    );

    final infraAp = UniFiDeviceEntity(
      id: 51,
      name: 'AP-Office',
      ip: '192.168.22.20',
      role: UniFiDeviceRole.accessPoint,
      location: 'Server Room',
      isCriticalInfrastructure: true,
      requiresAdminConfirmation: false,
      linkedSubnets: const ['192.168.22.0/24'],
      siteName: 'Server Room',
      isEnabled: true,
      isReadOnly: false,
      createdAt: DateTime(2026),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Topology link color precedence
    // ─────────────────────────────────────────────────────────────────────────

    test('1a. Verified physical link + endpoint failure = Amber (degraded)', () {
      final initialStatuses = <int, DeviceStatusEntity>{
        50001: DeviceStatusEntity(
          deviceId: 50001,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 0,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 0,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10051: DeviceStatusEntity(
          deviceId: 10051,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 0,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graph = builder.build(
        monitoredDevices: const [],
        infraDevices: [infraSw, infraAp],
        statuses: initialStatuses,
        factoryId: 'rnf',
      );

      final initialLink = graph.links.firstWhere(
        (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
      );
      expect(initialLink.status, DeviceStatusEnum.up);

      // Probe failure occurs on AP: consecutiveFailures becomes 1, but status retained as UP
      final failingStatuses = <int, DeviceStatusEntity>{
        ...initialStatuses,
        10051: DeviceStatusEntity(
          deviceId: 10051,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 1,
          failureThreshold: 3,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final updatedGraph = graph.updateStatuses(failingStatuses);
      final updatedLink = updatedGraph.links.firstWhere(
        (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
      );

      // MUST be degraded (Amber), never UP (Green)
      expect(
        updatedLink.status,
        DeviceStatusEnum.degraded,
        reason:
            'Link must turn Amber when an endpoint has consecutive probe failures',
      );
    });

    test(
      '1b. Inferred link + endpoint failure = Unknown (never Amber or Green)',
      () {
        final endpointDevice = MonitoredDevice(
          device: DeviceEntity(
            id: 101,
            name: 'PC-Inferred-01',
            type: DeviceType.pc,
            ip: '192.168.22.105',
            ownerName: 'Test Owner',
            officeLocation: 'Warehouse Lower Section',
            department: 'Logistics',
            createdAt: DateTime(2026),
          ),
          status: DeviceStatusEntity(
            deviceId: 101,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 2,
            failureThreshold: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        );

        // No physical switch for Warehouse Lower Section -> will generate an inferred switch group
        final graph = builder.build(
          monitoredDevices: [endpointDevice],
          infraDevices: const [],
          factoryId: 'rnf',
        );

        // Verify the switch is inferred
        final swNode = graph.nodes.values.firstWhere(
          (n) => n.id.contains('warehouse_lower_section'),
        );
        expect(swNode.isInferred, isTrue);

        final endpointLink = graph.links.firstWhere(
          (l) => l.toNodeId == 'dev_101',
        );
        expect(endpointLink.isInferred, isTrue);
        expect(
          endpointLink.status,
          DeviceStatusEnum.unknown,
          reason:
              'Inferred link must always remain Unknown even if endpoint has failures',
        );

        // Live update should also strictly retain Unknown status
        final liveGraph = graph.updateStatuses({
          101: endpointDevice.status.copyWith(consecutiveFailures: 2),
        });
        final liveLink = liveGraph.links.firstWhere(
          (l) => l.toNodeId == 'dev_101',
        );
        expect(liveLink.status, DeviceStatusEnum.unknown);
      },
    );

    test(
      '1c. WAN link + gateway failure = Unknown (never inferred or Amber)',
      () {
        final statuses = <int, DeviceStatusEntity>{
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 2,
            failureThreshold: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        };

        final graph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          statuses: statuses,
          factoryId: 'rnf',
        );

        final wanLink = graph.links.firstWhere(
          (l) => l.fromNodeId == 'wan_internet' && l.toNodeId == 'gw_rnf_22',
        );
        expect(
          wanLink.status,
          DeviceStatusEnum.unknown,
          reason:
              'WAN link must always be Unknown regardless of gateway failure count',
        );

        // Even if gateway goes completely down, WAN link remains Unknown
        final downStatuses = <int, DeviceStatusEntity>{
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.down,
            consecutiveFailures: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        };

        final liveGraph = graph.updateStatuses(downStatuses);
        final liveWanLink = liveGraph.links.firstWhere(
          (l) => l.fromNodeId == 'wan_internet' && l.toNodeId == 'gw_rnf_22',
        );
        expect(liveWanLink.status, DeviceStatusEnum.unknown);
      },
    );

    test('1d. Stale verified link remains Stale', () {
      final statuses = <int, DeviceStatusEntity>{
        50001: DeviceStatusEntity(
          deviceId: 50001,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 0,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 0,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10051: DeviceStatusEntity(
          deviceId: 10051,
          status: DeviceStatusEnum.stale,
          consecutiveFailures:
              1, // Has failures, but freshness expired -> Stale takes precedence
          statusChangedAt: DateTime.now().subtract(const Duration(hours: 1)),
          lastCheckAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      };

      final graph = builder.build(
        monitoredDevices: const [],
        infraDevices: [infraSw, infraAp],
        statuses: statuses,
        factoryId: 'rnf',
      );

      final staleLink = graph.links.firstWhere(
        (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
      );
      expect(
        staleLink.status,
        DeviceStatusEnum.stale,
        reason: 'Stale verified link must retain Stale state',
      );

      final liveGraph = graph.updateStatuses(statuses);
      final liveStaleLink = liveGraph.links.firstWhere(
        (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
      );
      expect(liveStaleLink.status, DeviceStatusEnum.stale);
    });

    test(
      '1e. Recovered verified link returns to Green only after failures reset to zero',
      () {
        final initialStatuses = <int, DeviceStatusEntity>{
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 0,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
          10050: DeviceStatusEntity(
            deviceId: 10050,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 0,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
          10051: DeviceStatusEntity(
            deviceId: 10051,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 1, // In failure state
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        };

        final graph = builder.build(
          monitoredDevices: const [],
          infraDevices: [infraSw, infraAp],
          statuses: initialStatuses,
          factoryId: 'rnf',
        );

        final linkWhileFailing = graph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(linkWhileFailing.status, DeviceStatusEnum.degraded);

        // Full recovery: consecutiveFailures resets to 0
        final recoveredStatuses = <int, DeviceStatusEntity>{
          ...initialStatuses,
          10051: DeviceStatusEntity(
            deviceId: 10051,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 0,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        };

        final recoveredGraph = graph.updateStatuses(recoveredStatuses);
        final recoveredLink = recoveredGraph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(
          recoveredLink.status,
          DeviceStatusEnum.up,
          reason:
              'Link returns to UP/Green only when consecutive failures reset to zero',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Gateway Fabrication Fallback Removal
    // ─────────────────────────────────────────────────────────────────────────

    test(
      '2. Never fabricate fallback gateway for unknown or unconfigured factory contexts',
      () {
        final unknownFactoryGraph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          factoryId: 'factory_unknown_999',
        );

        final unknownGateways = unknownFactoryGraph.nodes.values
            .where((n) => n.category == TopologyDeviceCategory.gateway)
            .toList();
        expect(unknownGateways.isEmpty, isTrue);

        final rnfGraph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          factoryId: 'rnf',
        );
        final rnfGateways = rnfGraph.nodes.values
            .where((n) => n.category == TopologyDeviceCategory.gateway)
            .toList();
        expect(rnfGateways.length, 1);
        expect(rnfGateways.first.id, 'gw_rnf_22');

        final bnfGraph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          factoryId: 'bnf',
        );
        final bnfGateways = bnfGraph.nodes.values
            .where((n) => n.category == TopologyDeviceCategory.gateway)
            .toList();
        expect(bnfGateways.length, 1);
        expect(bnfGateways.first.id, 'gw_bnf_21');

        final allGraph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          factoryId: null,
        );
        final allGateways = allGraph.nodes.values
            .where((n) => n.category == TopologyDeviceCategory.gateway)
            .toList();
        expect(allGateways.length, 2);
        expect(allGateways.any((g) => g.id == 'gw_rnf_22'), isTrue);
        expect(allGateways.any((g) => g.id == 'gw_bnf_21'), isTrue);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Dynamic failureThreshold propagation across entities, graph, and widgets
    // ─────────────────────────────────────────────────────────────────────────

    test(
      '3a. Start with threshold 3, update MonitoringConfig to 5, verify all transitional labels show /5',
      () {
        final dev = MonitoredDevice(
          device: DeviceEntity(
            id: 10,
            name: 'Device-10',
            type: DeviceType.pc,
            ip: '192.168.22.10',
            ownerName: 'Test Owner',
            department: 'IT',
            officeLocation: 'Main Office',
            createdAt: DateTime(2026),
          ),
          status: DeviceStatusEntity(
            deviceId: 10,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 2,
            failureThreshold: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        );

        final graph3 = builder.build(
          monitoredDevices: [dev],
          infraDevices: const [],
          factoryId: 'rnf',
          failureThreshold: 3,
        );
        expect(graph3.nodes['dev_10']!.failureThreshold, 3);
        expect(
          graph3.nodes['dev_10']!.transitionalLabel,
          'Previously Online · 2/3 Failed Checks',
        );

        // Update configuration to threshold 5
        final updatedGraph5 = graph3.updateThreshold(5);
        expect(updatedGraph5.nodes['dev_10']!.failureThreshold, 5);
        expect(
          updatedGraph5.nodes['dev_10']!.transitionalLabel,
          'Previously Online · 2/5 Failed Checks',
        );
        expect(updatedGraph5.nodes['gw_rnf_22']!.failureThreshold, 5);
        expect(updatedGraph5.nodes['wan_internet']!.failureThreshold, 5);
      },
    );

    test(
      '3b. Topology nodes with missing or default status records still use active threshold',
      () {
        final devWithoutStatus = MonitoredDevice(
          device: DeviceEntity(
            id: 99,
            name: 'Unchecked-Device',
            type: DeviceType.pc,
            ip: '192.168.22.99',
            ownerName: 'Test Owner',
            department: 'IT',
            officeLocation: 'Main Office',
            createdAt: DateTime(2026),
          ),
          // DeviceStatusEntity.initial defaults to 3 internally
          status: DeviceStatusEntity.initial(99),
        );

        final graph = builder.build(
          monitoredDevices: [devWithoutStatus],
          infraDevices: const [],
          factoryId: 'rnf',
          failureThreshold: 6, // Active configured threshold
        );

        // Must be 6, NOT overridden by the entity's default 3
        expect(graph.nodes['dev_99']!.failureThreshold, 6);
        expect(graph.nodes['gw_rnf_22']!.failureThreshold, 6);
      },
    );

    testWidgets(
      '3c. Dashboard chips use active configuration even when entity contains default threshold 3',
      (tester) async {
        final dev = MonitoredDevice(
          device: DeviceEntity(
            id: 1,
            name: 'PC-Test',
            type: DeviceType.pc,
            ip: '192.168.22.100',
            ownerName: 'Test Owner',
            department: 'IT',
            officeLocation: 'Main Office',
            createdAt: DateTime(2026),
          ),
          status: DeviceStatusEntity(
            deviceId: 1,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 2,
            failureThreshold: 3, // Entity has default 3
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        );

        // MonitoredDevicesTable is supplied failureThreshold: 5 from active config
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MonitoredDevicesTable(
                devices: [dev],
                userRole: UserRole.admin,
                failureThreshold: 5,
                onSelectDevice: (_) {},
              ),
            ),
          ),
        );

        // Must show 2/5 Fail, NOT 2/3 Fail!
        expect(find.text('2/5 Fail'), findsOneWidget);
        expect(find.text('2/3 Fail'), findsNothing);
      },
    );

    test('3d. Threshold remains correct after live status updates', () {
      final dev = MonitoredDevice(
        device: DeviceEntity(
          id: 5,
          name: 'Live-PC',
          type: DeviceType.pc,
          ip: '192.168.22.50',
          ownerName: 'Test Owner',
          department: 'IT',
          officeLocation: 'Main Office',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 5,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 1,
          failureThreshold: 5,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      );

      final graph = builder.build(
        monitoredDevices: [dev],
        infraDevices: const [],
        factoryId: 'rnf',
        failureThreshold: 5,
      );

      // Live update arrives where status entity still carries default 3
      final liveStatusMap = <int, DeviceStatusEntity>{
        5: DeviceStatusEntity(
          deviceId: 5,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 2,
          failureThreshold: 3, // Incoming entity with default 3
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      // updateStatuses with authoritative failureThreshold: 5
      final liveGraph = graph.updateStatuses(
        liveStatusMap,
        failureThreshold: 5,
      );
      expect(liveGraph.nodes['dev_5']!.failureThreshold, 5);
      expect(liveGraph.nodes['dev_5']!.consecutiveFailures, 2);
      expect(
        liveGraph.nodes['dev_5']!.transitionalLabel,
        'Previously Online · 2/5 Failed Checks',
      );
    });

    testWidgets(
      '3e. EnterpriseDeviceCard dynamically displays active failureThreshold',
      (tester) async {
        const nodeWithCustomThreshold = EnterpriseTopologyNode(
          id: 'dev_20',
          title: 'Accounting PC',
          subtitle: '192.168.22.100',
          category: TopologyDeviceCategory.pc,
          level: 4,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 3,
          failureThreshold: 8,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EnterpriseDeviceCard(node: nodeWithCustomThreshold),
            ),
          ),
        );

        expect(find.text('3/8 FAIL'), findsOneWidget);
      },
    );
  });
}
