import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/device_status_chip.dart';
import 'package:it_network_monitor/features/topology/domain/entities/enterprise_topology_models.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_device_card.dart';

void main() {
  group('Monitoring Accuracy Hardening Tests', () {
    const builder = EnterpriseTopologyBuilder();

    // ─────────────────────────────────────────────────────────────────────────
    // Fix 1: Verified topology links must show Amber when either endpoint has
    // consecutiveFailures > 0, even while its retained status is UP.
    // ─────────────────────────────────────────────────────────────────────────
    test(
      '1. Verified topology links turn Amber when either endpoint has consecutiveFailures > 0',
      () {
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

        // Initially both endpoints UP with 0 failures -> link should be UP
        final initialLink = graph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(initialLink.status, DeviceStatusEnum.up);

        // Probe failure occurs on AP: consecutiveFailures becomes 1, but status retained as UP
        final updatedStatuses = <int, DeviceStatusEntity>{
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

        final updatedGraph = graph.updateStatuses(updatedStatuses);
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

        // Now resolve the failure: consecutiveFailures resets to 0
        final resolvedStatuses = <int, DeviceStatusEntity>{
          ...initialStatuses,
          10051: DeviceStatusEntity(
            deviceId: 10051,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 0,
            failureThreshold: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        };

        final resolvedGraph = updatedGraph.updateStatuses(resolvedStatuses);
        final resolvedLink = resolvedGraph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );

        // Now both endpoints are UP and failures == 0 -> link returns to UP (Green)
        expect(resolvedLink.status, DeviceStatusEnum.up);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Fix 2: Remove the automatic RNF gateway fallback from EnterpriseTopologyBuilder.
    // Never fabricate a gateway when none is registered. Respect factory contexts.
    // ─────────────────────────────────────────────────────────────────────────
    test(
      '2. Never fabricate fallback gateway for unknown or unconfigured factory contexts',
      () {
        // Build with unknown factory context and no registered infrastructure gateways
        final unknownFactoryGraph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          factoryId: 'factory_unknown_999',
        );

        final unknownGateways = unknownFactoryGraph.nodes.values
            .where((n) => n.category == TopologyDeviceCategory.gateway)
            .toList();
        expect(
          unknownGateways.isEmpty,
          isTrue,
          reason:
              'Must not fabricate a fallback gateway for unknown factory context',
        );

        // Build with RNF context: only RNF gateway should exist, NOT BNF
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

        // Build with BNF context: only BNF gateway should exist, NOT RNF
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

        // Build with All Factories context: both RNF and BNF gateways should exist
        final allGraph = builder.build(
          monitoredDevices: const [],
          infraDevices: const [],
          factoryId: null, // null represents All Factories
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
    // Fix 3: Replace every hardcoded /3 in transitional failure labels and badges
    // with the actual configured MonitoringConfig.failureThreshold.
    // ─────────────────────────────────────────────────────────────────────────
    test(
      '3. Transitional failure labels and badges dynamically reflect configured failureThreshold',
      () {
        // Test DeviceStatusEntity transitionalLabel
        final statusEntity = DeviceStatusEntity(
          deviceId: 10,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 2,
          failureThreshold: 5,
          statusChangedAt: DateTime(2026),
        );
        expect(
          statusEntity.transitionalLabel,
          'Previously Online · 2/5 Failed Checks',
        );

        // Test EnterpriseTopologyNode transitionalLabel
        const topologyNode = EnterpriseTopologyNode(
          id: 'dev_10',
          title: 'Workstation',
          category: TopologyDeviceCategory.pc,
          level: 4,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 3,
          failureThreshold: 7,
        );
        expect(
          topologyNode.transitionalLabel,
          'Previously Online · 3/7 Failed Checks',
        );
      },
    );

    testWidgets(
      '3b. DeviceStatusChip and EnterpriseDeviceCard render dynamic failureThreshold',
      (tester) async {
        // Test DeviceStatusChip with threshold 4 (compact)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DeviceStatusChip(
                status: DeviceStatusEnum.up,
                consecutiveFailures: 2,
                failureThreshold: 4,
                compact: true,
              ),
            ),
          ),
        );

        expect(find.text('2/4 Fail'), findsOneWidget);

        // Test DeviceStatusChip with threshold 4 (full)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DeviceStatusChip(
                status: DeviceStatusEnum.up,
                consecutiveFailures: 2,
                failureThreshold: 4,
                compact: false,
              ),
            ),
          ),
        );

        expect(
          find.text('Previously Online · 2/4 Failed Checks'),
          findsOneWidget,
        );

        // Test EnterpriseDeviceCard with threshold 6
        const nodeWithCustomThreshold = EnterpriseTopologyNode(
          id: 'dev_20',
          title: 'Accounting PC',
          subtitle: '192.168.22.100',
          category: TopologyDeviceCategory.pc,
          level: 4,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 2,
          failureThreshold: 6,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EnterpriseDeviceCard(node: nodeWithCustomThreshold),
            ),
          ),
        );

        expect(find.text('2/6 FAIL'), findsOneWidget);
      },
    );
  });
}
