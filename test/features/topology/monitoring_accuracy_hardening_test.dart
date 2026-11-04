import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/repositories/infrastructure_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'package:it_network_monitor/features/monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import 'package:it_network_monitor/features/monitoring/presentation/widgets/monitored_devices_table.dart';
import 'package:it_network_monitor/features/topology/domain/entities/enterprise_topology_models.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';
import 'package:it_network_monitor/features/topology/domain/services/topology_grouper.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_cubit.dart';
import 'package:it_network_monitor/features/topology/presentation/bloc/topology_state.dart';
import 'package:it_network_monitor/features/topology/presentation/widgets/enterprise_device_card.dart';

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockInfrastructureRepository extends Mock
    implements InfrastructureRepository {}

class MockMonitoringRepository extends Mock implements MonitoringRepository {}

class MockPingChecker extends Mock implements PingChecker {}

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

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Stale recovery & precedence
    // ─────────────────────────────────────────────────────────────────────────

    test(
      '4a. Stale endpoints -> recovered fresh UP endpoints -> link transitions from Stale to UP',
      () {
        final staleStatuses = <int, DeviceStatusEntity>{
          10050: DeviceStatusEntity(
            deviceId: 10050,
            status: DeviceStatusEnum.stale,
            consecutiveFailures: 0,
            statusChangedAt: DateTime.now().subtract(const Duration(hours: 2)),
            lastCheckAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          10051: DeviceStatusEntity(
            deviceId: 10051,
            status: DeviceStatusEnum.stale,
            consecutiveFailures: 0,
            statusChangedAt: DateTime.now().subtract(const Duration(hours: 2)),
            lastCheckAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        };

        final graph = builder.build(
          monitoredDevices: const [],
          infraDevices: [infraSw, infraAp],
          statuses: staleStatuses,
          factoryId: 'rnf',
        );

        final staleLink = graph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(staleLink.status, DeviceStatusEnum.stale);

        // Both endpoints recover to fresh UP with 0 failures
        final recoveredStatuses = <int, DeviceStatusEntity>{
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

        final updatedGraph = graph.updateStatuses(recoveredStatuses);
        final updatedLink = updatedGraph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(
          updatedLink.status,
          DeviceStatusEnum.up,
          reason:
              'Recovered endpoints must transition link from Stale to UP, not retain permanent Stale',
        );
      },
    );

    test(
      '4b. Stale endpoints: if one remains stale, link remains Stale; if one is Down, link is Down',
      () {
        final initialStatuses = <int, DeviceStatusEntity>{
          10050: DeviceStatusEntity(
            deviceId: 10050,
            status: DeviceStatusEnum.stale,
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

        final link1 = graph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(
          link1.status,
          DeviceStatusEnum.stale,
          reason: 'If either endpoint is stale, link remains stale',
        );

        // Now one endpoint goes Down
        final downStatuses = <int, DeviceStatusEntity>{
          10050: DeviceStatusEntity(
            deviceId: 10050,
            status: DeviceStatusEnum.down,
            consecutiveFailures: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
          10051: DeviceStatusEntity(
            deviceId: 10051,
            status: DeviceStatusEnum.stale,
            consecutiveFailures: 0,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        };

        final downGraph = graph.updateStatuses(downStatuses);
        final link2 = downGraph.links.firstWhere(
          (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
        );
        expect(
          link2.status,
          DeviceStatusEnum.down,
          reason: 'Down/Unreachable takes precedence over stale',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Initial Unreachable physical link states across all 4 types
    // ─────────────────────────────────────────────────────────────────────────

    test('5. Initial Unreachable Physical Link States across all 4 types', () {
      final infraGw = UniFiDeviceEntity(
        id: 1,
        name: 'Gateway-USG',
        ip: '192.168.22.1',
        role: UniFiDeviceRole.gateway,
        location: 'Server Room',
        isCriticalInfrastructure: true,
        requiresAdminConfirmation: false,
        linkedSubnets: const ['192.168.22.0/24'],
        siteName: 'Server Room',
        isEnabled: true,
        isReadOnly: false,
        createdAt: DateTime(2026),
      );

      final dev = MonitoredDevice(
        device: DeviceEntity(
          id: 77,
          name: 'Target-PC',
          type: DeviceType.pc,
          ip: '192.168.22.77',
          ownerName: 'Worker',
          department: 'IT',
          officeLocation: 'Server Room',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 77,
          status: DeviceStatusEnum.unreachable,
          consecutiveFailures: 3,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      );

      // Case A: Gateway Unreachable, Switch UP -> Gateway to Switch link is Down
      final statusesA = <int, DeviceStatusEntity>{
        10001: DeviceStatusEntity(
          deviceId: 10001,
          status: DeviceStatusEnum.unreachable,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graphA = builder.build(
        monitoredDevices: const [],
        infraDevices: [infraGw, infraSw],
        statuses: statusesA,
        factoryId: 'rnf',
      );

      final linkGwSw = graphA.links.firstWhere(
        (l) => l.fromNodeId == 'gw_1' && l.toNodeId == 'sw_50',
      );
      expect(
        linkGwSw.status,
        DeviceStatusEnum.down,
        reason: 'Gateway Unreachable must produce Down physical link to switch',
      );

      // Case B: Switch Unreachable -> Switch to AP link is Down
      final statusesB = <int, DeviceStatusEntity>{
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.unreachable,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10051: DeviceStatusEntity(
          deviceId: 10051,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graphB = builder.build(
        monitoredDevices: const [],
        infraDevices: [infraSw, infraAp],
        statuses: statusesB,
        factoryId: 'rnf',
      );

      final linkSwAp = graphB.links.firstWhere(
        (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
      );
      expect(
        linkSwAp.status,
        DeviceStatusEnum.down,
        reason: 'Switch Unreachable must produce Down physical link to AP',
      );

      // Case C: AP Unreachable -> Switch to AP link is Down
      final statusesC = <int, DeviceStatusEntity>{
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10051: DeviceStatusEntity(
          deviceId: 10051,
          status: DeviceStatusEnum.unreachable,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graphC = builder.build(
        monitoredDevices: const [],
        infraDevices: [infraSw, infraAp],
        statuses: statusesC,
        factoryId: 'rnf',
      );

      final linkSwApC = graphC.links.firstWhere(
        (l) => l.fromNodeId == 'sw_50' && l.toNodeId == 'ap_51',
      );
      expect(
        linkSwApC.status,
        DeviceStatusEnum.down,
        reason: 'AP Unreachable must produce Down physical link',
      );

      // Case D: Endpoint Unreachable -> Switch to Endpoint link is Down
      final statusesD = <int, DeviceStatusEntity>{
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        77: DeviceStatusEntity(
          deviceId: 77,
          status: DeviceStatusEnum.unreachable,
          consecutiveFailures: 3,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graphD = builder.build(
        monitoredDevices: [dev],
        infraDevices: [infraSw],
        statuses: statusesD,
        factoryId: 'rnf',
      );

      final linkSwDev = graphD.links.firstWhere((l) => l.toNodeId == 'dev_77');
      expect(
        linkSwDev.status,
        DeviceStatusEnum.down,
        reason:
            'Endpoint Unreachable must produce Down physical link to endpoint',
      );

      // Case E: Switch Unreachable -> Switch to Endpoint link is Down
      final statusesE = <int, DeviceStatusEntity>{
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.unreachable,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        77: DeviceStatusEntity(
          deviceId: 77,
          status: DeviceStatusEnum.up,
          consecutiveFailures: 0,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graphE = builder.build(
        monitoredDevices: [
          MonitoredDevice(
            device: dev.device,
            status: DeviceStatusEntity(
              deviceId: 77,
              status: DeviceStatusEnum.up,
              consecutiveFailures: 0,
              statusChangedAt: DateTime.now(),
              lastCheckAt: DateTime.now(),
            ),
          ),
        ],
        infraDevices: [infraSw],
        statuses: statusesE,
        factoryId: 'rnf',
      );

      final linkSwDevE = graphE.links.firstWhere((l) => l.toNodeId == 'dev_77');
      expect(
        linkSwDevE.status,
        DeviceStatusEnum.down,
        reason:
            'Switch Unreachable must produce Down physical link to endpoint',
      );

      // Case F: Gateway to Verified Switch when there are NO endpoint locations
      final statusesF = <int, DeviceStatusEntity>{
        10001: DeviceStatusEntity(
          deviceId: 10001,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
        10050: DeviceStatusEntity(
          deviceId: 10050,
          status: DeviceStatusEnum.unreachable,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
        ),
      };

      final graphF = builder.build(
        monitoredDevices: const [],
        infraDevices: [infraGw, infraSw],
        statuses: statusesF,
        factoryId: 'rnf',
      );

      final linkGwSwF = graphF.links.firstWhere(
        (l) => l.fromNodeId == 'gw_1' && l.toNodeId == 'sw_50',
      );
      expect(
        linkGwSwF.status,
        DeviceStatusEnum.down,
        reason: 'Gateway to Switch when Switch Unreachable must be Down',
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Synchronize Selected Node After Configuration Updates
    // ─────────────────────────────────────────────────────────────────────────

    test(
      '6a. Selected node updates threshold and keeps synchronization on updateFailureThreshold',
      () async {
        final mockDevRepo = MockDeviceRepository();
        final mockInfraRepo = MockInfrastructureRepository();
        final mockMonRepo = MockMonitoringRepository();
        final mockPingChecker = MockPingChecker();

        final device = DeviceEntity(
          id: 101,
          name: 'Office-PC',
          type: DeviceType.pc,
          ip: '192.168.22.101',
          ownerName: 'Alice',
          department: 'Finance',
          officeLocation: 'Office A',
          createdAt: DateTime(2026),
        );

        final statusController =
            StreamController<List<DeviceStatusEntity>>.broadcast();

        when(
          () => mockDevRepo.getDevices(factoryId: any(named: 'factoryId')),
        ).thenAnswer((_) async => Result.success([device]));
        when(
          () => mockInfraRepo.getInfrastructureDevices(
            factoryId: any(named: 'factoryId'),
          ),
        ).thenAnswer((_) async => Result.success([]));
        when(() => mockMonRepo.getDeviceStatuses()).thenAnswer(
          (_) async => Result.success([
            DeviceStatusEntity(
              deviceId: 101,
              status: DeviceStatusEnum.up,
              consecutiveFailures: 1,
              statusChangedAt: DateTime.now(),
              lastCheckAt: DateTime.now(),
            ),
          ]),
        );
        when(
          () => mockMonRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final scheduler = MonitoringScheduler(
          mockDevRepo,
          mockMonRepo,
          mockPingChecker,
        );
        final topologyGrouper = TopologyGrouper();
        final cubit = TopologyCubit(
          mockDevRepo,
          mockInfraRepo,
          mockMonRepo,
          topologyGrouper,
          builder,
          scheduler,
        );

        await cubit.init('rnf');
        expect(cubit.state, isA<TopologyLoaded>());
        final loaded1 = cubit.state as TopologyLoaded;

        // Select the node
        final targetNode = loaded1.enterpriseGraph!.nodes['dev_101']!;
        expect(targetNode.failureThreshold, 3);
        cubit.selectNode(targetNode);

        expect((cubit.state as TopologyLoaded).selectedNode!.id, 'dev_101');
        expect(
          (cubit.state as TopologyLoaded).selectedNode!.failureThreshold,
          3,
        );

        // Now change threshold to 7 via cubit.updateFailureThreshold
        cubit.updateFailureThreshold(7);

        final loaded2 = cubit.state as TopologyLoaded;
        expect(loaded2.enterpriseGraph!.nodes['dev_101']!.failureThreshold, 7);
        expect(loaded2.selectedNode, isNotNull);
        expect(loaded2.selectedNode!.id, 'dev_101');
        expect(
          loaded2.selectedNode!.failureThreshold,
          7,
          reason:
              'Selected node must synchronize failureThreshold from updated graph',
        );

        // Live status update preserves threshold 7 on both graph node and selectedNode
        statusController.add([
          DeviceStatusEntity(
            deviceId: 101,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 2,
            failureThreshold: 3, // entity with default 3
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        ]);
        await pumpEventQueue();

        final loaded3 = cubit.state as TopologyLoaded;
        expect(loaded3.enterpriseGraph!.nodes['dev_101']!.failureThreshold, 7);
        expect(
          loaded3.enterpriseGraph!.nodes['dev_101']!.consecutiveFailures,
          2,
        );
        expect(loaded3.selectedNode!.failureThreshold, 7);
        expect(loaded3.selectedNode!.consecutiveFailures, 2);

        await cubit.close();
        await statusController.close();
      },
    );

    test(
      '6b. Selected node is safely cleared if node no longer exists in graph',
      () async {
        final mockDevRepo = MockDeviceRepository();
        final mockInfraRepo = MockInfrastructureRepository();
        final mockMonRepo = MockMonitoringRepository();
        final mockPingChecker = MockPingChecker();

        final statusController =
            StreamController<List<DeviceStatusEntity>>.broadcast();

        when(
          () => mockDevRepo.getDevices(factoryId: any(named: 'factoryId')),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockInfraRepo.getInfrastructureDevices(
            factoryId: any(named: 'factoryId'),
          ),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockMonRepo.getDeviceStatuses(),
        ).thenAnswer((_) async => Result.success([]));
        when(
          () => mockMonRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final scheduler = MonitoringScheduler(
          mockDevRepo,
          mockMonRepo,
          mockPingChecker,
        );
        final topologyGrouper = TopologyGrouper();
        final cubit = TopologyCubit(
          mockDevRepo,
          mockInfraRepo,
          mockMonRepo,
          topologyGrouper,
          builder,
          scheduler,
        );

        await cubit.init('rnf');
        const ghostNode = EnterpriseTopologyNode(
          id: 'dev_ghost',
          title: 'Ghost',
          category: TopologyDeviceCategory.pc,
          status: DeviceStatusEnum.unknown,
          level: 4,
        );
        cubit.selectNode(ghostNode);
        expect((cubit.state as TopologyLoaded).selectedNode, isNotNull);

        // Update failure threshold - ghost node does not exist in graph -> safely cleared
        cubit.updateFailureThreshold(6);
        expect((cubit.state as TopologyLoaded).selectedNode, isNull);

        await cubit.close();
        await statusController.close();
      },
    );

    test(
      '6c. EnterpriseTopologyGraph.updateThreshold updates unlinkedNodes failureThreshold',
      () {
        const unlinkedNode = EnterpriseTopologyNode(
          id: 'unlinked_1',
          title: 'Unlinked PC',
          category: TopologyDeviceCategory.pc,
          status: DeviceStatusEnum.unknown,
          level: 4,
          failureThreshold: 3,
        );
        const linkedNode = EnterpriseTopologyNode(
          id: 'linked_1',
          title: 'Linked PC',
          category: TopologyDeviceCategory.pc,
          status: DeviceStatusEnum.unknown,
          level: 4,
          failureThreshold: 3,
        );

        final graph = EnterpriseTopologyGraph(
          nodes: {'linked_1': linkedNode},
          links: const [],
          unlinkedNodes: const [unlinkedNode],
          canvasSize: const Size(1000, 1000),
          categoryStats: const {},
        );

        final updated = graph.updateThreshold(9);
        expect(updated.nodes['linked_1']!.failureThreshold, 9);
        expect(updated.unlinkedNodes.first.failureThreshold, 9);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Real Runtime Configuration Tests
    // ─────────────────────────────────────────────────────────────────────────

    test(
      '7a. MonitoringScheduler.updateConfig broadcasts to TopologyCubit and syncs selectedNode',
      () async {
        final mockDevRepo = MockDeviceRepository();
        final mockInfraRepo = MockInfrastructureRepository();
        final mockMonRepo = MockMonitoringRepository();
        final mockPingChecker = MockPingChecker();

        final device = DeviceEntity(
          id: 202,
          name: 'Production-PC',
          type: DeviceType.pc,
          ip: '192.168.22.202',
          ownerName: 'Bob',
          department: 'Operations',
          officeLocation: 'Plant Floor',
          createdAt: DateTime(2026),
        );

        final statusController =
            StreamController<List<DeviceStatusEntity>>.broadcast();

        when(
          () => mockDevRepo.getDevices(factoryId: any(named: 'factoryId')),
        ).thenAnswer((_) async => Result.success([device]));
        when(
          () => mockInfraRepo.getInfrastructureDevices(
            factoryId: any(named: 'factoryId'),
          ),
        ).thenAnswer((_) async => Result.success([]));
        when(() => mockMonRepo.getDeviceStatuses()).thenAnswer(
          (_) async => Result.success([
            DeviceStatusEntity(
              deviceId: 202,
              status: DeviceStatusEnum.up,
              consecutiveFailures: 0,
              statusChangedAt: DateTime.now(),
              lastCheckAt: DateTime.now(),
            ),
          ]),
        );
        when(
          () => mockMonRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final scheduler = MonitoringScheduler(
          mockDevRepo,
          mockMonRepo,
          mockPingChecker,
        );
        final topologyGrouper = TopologyGrouper();
        final cubit = TopologyCubit(
          mockDevRepo,
          mockInfraRepo,
          mockMonRepo,
          topologyGrouper,
          builder,
          scheduler,
        );

        await cubit.init('rnf');
        expect(cubit.activeFailureThreshold, 3);

        final nodeBefore =
            (cubit.state as TopologyLoaded).enterpriseGraph!.nodes['dev_202']!;
        cubit.selectNode(nodeBefore);
        expect(
          (cubit.state as TopologyLoaded).selectedNode!.failureThreshold,
          3,
        );

        // 1. MonitoringScheduler.updateConfig broadcasts new MonitoringConfig
        scheduler.updateConfig(const MonitoringConfig(failureThreshold: 5));
        await pumpEventQueue();

        // 2. TopologyCubit receives stream event & 3. existing nodes update immediately
        final loadedAfterConfig = cubit.state as TopologyLoaded;
        expect(cubit.activeFailureThreshold, 5);
        expect(
          loadedAfterConfig.enterpriseGraph!.nodes['dev_202']!.failureThreshold,
          5,
        );

        // 4. Selected details node updates immediately
        expect(loadedAfterConfig.selectedNode, isNotNull);
        expect(loadedAfterConfig.selectedNode!.failureThreshold, 5);

        // 5. Subsequent live status update preserves active configured threshold 5
        statusController.add([
          DeviceStatusEntity(
            deviceId: 202,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 1,
            failureThreshold: 3, // incoming payload carrying default 3
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        ]);
        await pumpEventQueue();

        final loadedAfterStatus = cubit.state as TopologyLoaded;
        expect(
          loadedAfterStatus.enterpriseGraph!.nodes['dev_202']!.failureThreshold,
          5,
        );
        expect(loadedAfterStatus.selectedNode!.failureThreshold, 5);
        expect(loadedAfterStatus.selectedNode!.consecutiveFailures, 1);

        await cubit.close();
        await statusController.close();
      },
    );

    test(
      '7b. MonitoringDashboardCubit preserves active config threshold across incoming updates',
      () async {
        final mockDevRepo = MockDeviceRepository();
        final mockMonRepo = MockMonitoringRepository();
        final mockPingChecker = MockPingChecker();

        final device = DeviceEntity(
          id: 303,
          name: 'Dashboard-PC',
          type: DeviceType.pc,
          ip: '192.168.22.203',
          ownerName: 'Charlie',
          department: 'Quality',
          officeLocation: 'Main Office',
          createdAt: DateTime(2026),
        );

        final statusController =
            StreamController<List<DeviceStatusEntity>>.broadcast();

        when(
          () => mockDevRepo.bootstrapApprovedInventory(
            force: any(named: 'force'),
          ),
        ).thenAnswer((_) async => Result.success(0));
        when(
          () => mockDevRepo.getDevices(factoryId: any(named: 'factoryId')),
        ).thenAnswer((_) async => Result.success([device]));
        when(() => mockMonRepo.getDeviceStatuses()).thenAnswer(
          (_) async => Result.success([
            DeviceStatusEntity(
              deviceId: 303,
              status: DeviceStatusEnum.up,
              consecutiveFailures: 2,
              failureThreshold: 3,
              statusChangedAt: DateTime.now(),
              lastCheckAt: DateTime.now(),
            ),
          ]),
        );
        when(
          () => mockMonRepo.watchAllDeviceStatuses(),
        ).thenAnswer((_) => statusController.stream);

        final scheduler = MonitoringScheduler(
          mockDevRepo,
          mockMonRepo,
          mockPingChecker,
        );
        // Update scheduler config to 6
        scheduler.updateConfig(const MonitoringConfig(failureThreshold: 6));

        final dashboardCubit = MonitoringDashboardCubit(
          mockDevRepo,
          mockMonRepo,
          scheduler,
        );

        await dashboardCubit.initDashboard();
        expect(dashboardCubit.state, isA<MonitoringDashboardLoaded>());
        var dashState = dashboardCubit.state as MonitoringDashboardLoaded;

        // Even though initial status payload had failureThreshold 3, dashboard cubit synced to activeConfig 6
        expect(dashState.allDevices.first.status.failureThreshold, 6);

        // Now incoming live update arrives with default failureThreshold 3
        statusController.add([
          DeviceStatusEntity(
            deviceId: 303,
            status: DeviceStatusEnum.up,
            consecutiveFailures: 3,
            failureThreshold: 3,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        ]);
        await pumpEventQueue();

        dashState = dashboardCubit.state as MonitoringDashboardLoaded;
        expect(
          dashState.allDevices.first.status.failureThreshold,
          6,
          reason:
              'Dashboard must preserve activeConfig failureThreshold 6 despite incoming default 3',
        );
        expect(dashState.allDevices.first.status.consecutiveFailures, 3);

        await dashboardCubit.close();
        await statusController.close();
      },
    );
  });
}
