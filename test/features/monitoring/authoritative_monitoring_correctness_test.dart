import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_state.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/status_engine.dart';
import 'package:it_network_monitor/features/topology/domain/entities/enterprise_topology_models.dart';
import 'package:it_network_monitor/features/topology/domain/services/enterprise_topology_builder.dart';

void main() {
  group('Authoritative Monitoring & Topology Correctness Regression Tests', () {
    const builder = EnterpriseTopologyBuilder();
    const config = MonitoringConfig(failureThreshold: 3, recoveryThreshold: 2);

    final unifiAps = [
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

    final endpoints = [
      MonitoredDevice(
        device: DeviceEntity(
          id: 101,
          name: 'PC-MainOffice-01',
          type: DeviceType.pc,
          ip: '192.168.27.10',
          ownerName: 'Accounting Staff',
          department: 'Accounting',
          officeLocation: 'Main Office',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 101,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
          lastLatencyMs: 4,
        ),
      ),
      MonitoredDevice(
        device: DeviceEntity(
          id: 102,
          name: 'Laptop-Warehouse-01',
          type: DeviceType.laptop,
          ip: '192.168.22.15',
          ownerName: 'Warehouse Staff',
          department: 'Logistics',
          officeLocation: 'Warehouse',
          createdAt: DateTime(2026),
        ),
        status: DeviceStatusEntity(
          deviceId: 102,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
          lastLatencyMs: 3,
        ),
      ),
    ];

    test(
      '1. Enabled AP without any probe history is Unknown, never Online',
      () {
        final state = InfrastructureState(
          devices: unifiAps,
          statuses: const {}, // No probe history
        );

        // Verify InfrastructureState reports Unknown
        expect(state.upCount, 0);
        expect(state.unknownCount, 4);

        // Verify Topology Builder reports Unknown
        final graph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: unifiAps,
          infraStatuses: const {},
        );

        final apNode = graph.nodes['ap_3']; // FM Office AP (192.168.7.2)
        expect(apNode, isNotNull);
        expect(apNode!.status, DeviceStatusEnum.unknown);
        expect(
          graph.categoryStats[TopologyDeviceCategory.accessPoint]!.online,
          0,
        );
        expect(
          graph.categoryStats[TopologyDeviceCategory.accessPoint]!.unknown,
          4,
        );
      },
    );

    test(
      '2. AP with failed latest probe follows configured failure threshold',
      () {
        final initialStatus = DeviceStatusEntity(
          deviceId: 10003,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
          consecutiveFailures: 0,
          lastLatencyMs: 5,
        );

        // 1st failure: retains UP, consecutiveFailures = 1
        final afterFirstFailure = StatusEngine.processCheckResult(
          currentStatus: initialStatus,
          checkResult: CheckResult.failure(
            deviceId: 10003,
            targetIp: '192.168.7.2',
            timestamp: DateTime.now(),
            errorMessage: 'Request timed out',
          ),
          config: config,
        );
        expect(afterFirstFailure.status, DeviceStatusEnum.up);
        expect(afterFirstFailure.consecutiveFailures, 1);

        // 2nd failure: retains UP, consecutiveFailures = 2
        final afterSecondFailure = StatusEngine.processCheckResult(
          currentStatus: afterFirstFailure,
          checkResult: CheckResult.failure(
            deviceId: 10003,
            targetIp: '192.168.7.2',
            timestamp: DateTime.now(),
            errorMessage: 'Request timed out',
          ),
          config: config,
        );
        expect(afterSecondFailure.status, DeviceStatusEnum.up);
        expect(afterSecondFailure.consecutiveFailures, 2);
      },
    );

    test('3. Three consecutive failures mark AP Offline', () {
      final twoFailures = DeviceStatusEntity(
        deviceId: 10003,
        status: DeviceStatusEnum.up,
        statusChangedAt: DateTime.now(),
        lastCheckAt: DateTime.now(),
        consecutiveFailures: 2,
        lastLatencyMs: 5,
      );

      // 3rd failure: transitions to DOWN
      final afterThirdFailure = StatusEngine.processCheckResult(
        currentStatus: twoFailures,
        checkResult: CheckResult.failure(
          deviceId: 10003,
          targetIp: '192.168.7.2',
          timestamp: DateTime.now(),
          errorMessage: 'Request timed out',
        ),
        config: config,
      );
      expect(afterThirdFailure.status, DeviceStatusEnum.down);
      expect(afterThirdFailure.consecutiveFailures, 3);
    });

    test('4. Stale previous Online result is displayed as Stale', () {
      final now = DateTime.now();
      final staleCheckTime = now.subtract(const Duration(seconds: 250));

      final staleStatus = DeviceStatusEntity(
        deviceId: 10003,
        status: DeviceStatusEnum.up,
        statusChangedAt: staleCheckTime,
        lastCheckAt: staleCheckTime,
        lastSeen: staleCheckTime,
        lastLatencyMs: 15,
      );

      expect(
        staleStatus.isStale(now: now, freshnessWindowSeconds: 180),
        isTrue,
      );
      expect(
        staleStatus.effectiveStatus(now: now, freshnessWindowSeconds: 180),
        DeviceStatusEnum.stale,
      );

      // Fresh status check
      final freshStatus = DeviceStatusEntity(
        deviceId: 10003,
        status: DeviceStatusEnum.up,
        statusChangedAt: now.subtract(const Duration(seconds: 30)),
        lastCheckAt: now.subtract(const Duration(seconds: 30)),
        lastSeen: now.subtract(const Duration(seconds: 30)),
      );
      expect(
        freshStatus.isStale(now: now, freshnessWindowSeconds: 180),
        isFalse,
      );
      expect(
        freshStatus.effectiveStatus(now: now, freshnessWindowSeconds: 180),
        DeviceStatusEnum.up,
      );
    });

    test(
      '5. Successful new probe restores Online according to recovery rules',
      () {
        final downStatus = DeviceStatusEntity(
          deviceId: 10003,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now(),
          lastCheckAt: DateTime.now(),
          consecutiveFailures: 3,
          consecutiveSuccesses: 0,
        );

        // 1st recovery success: remains down because recoverySuccessThreshold is 2
        final afterFirstSuccess = StatusEngine.processCheckResult(
          currentStatus: downStatus,
          checkResult: CheckResult.success(
            deviceId: 10003,
            targetIp: '192.168.7.2',
            timestamp: DateTime.now(),
            latencyMs: 12,
          ),
          config: config,
        );
        expect(afterFirstSuccess.status, DeviceStatusEnum.down);
        expect(afterFirstSuccess.consecutiveSuccesses, 1);

        // 2nd recovery success: recovers to UP
        final afterSecondSuccess = StatusEngine.processCheckResult(
          currentStatus: afterFirstSuccess,
          checkResult: CheckResult.success(
            deviceId: 10003,
            targetIp: '192.168.7.2',
            timestamp: DateTime.now(),
            latencyMs: 10,
          ),
          config: config,
        );
        expect(afterSecondSuccess.status, DeviceStatusEnum.up);
        expect(afterSecondSuccess.consecutiveFailures, 0);
        expect(afterSecondSuccess.lastLatencyMs, 10);
      },
    );

    test(
      '6. Switch nodes without a real record are not counted as registered physical switches',
      () {
        final graph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: unifiAps,
        );

        final swMain = graph.nodes['sw_main_office'];
        expect(swMain, isNotNull);
        expect(swMain!.isInferred, isTrue);
        expect(swMain.activePortCount, isNull);
        expect(swMain.status, DeviceStatusEnum.unknown);

        // Inferred switch nodes are excluded from registered physical switch counts
        final switchStats =
            graph.categoryStats[TopologyDeviceCategory.switchDevice];
        expect(switchStats?.total ?? 0, 0);
        expect(switchStats?.online ?? 0, 0);
      },
    );

    test('7. Missing gateway check data never defaults to Online', () {
      final graph = builder.build(
        monitoredDevices: endpoints,
        infraDevices: unifiAps,
        infraStatuses: const {}, // No gateway probe data
      );

      final rnfGw = graph.nodes['gw_rnf_22'];
      final bnfGw = graph.nodes['gw_bnf_21'];
      final wanNode = graph.nodes['wan_internet'];

      expect(rnfGw, isNotNull);
      expect(rnfGw!.status, DeviceStatusEnum.unknown);
      expect(bnfGw, isNotNull);
      expect(bnfGw!.status, DeviceStatusEnum.unknown);
      expect(wanNode, isNotNull);
      expect(wanNode!.status, DeviceStatusEnum.unknown);

      final gwStats = graph.categoryStats[TopologyDeviceCategory.gateway]!;
      expect(gwStats.online, 0);
      expect(gwStats.unknown, 2);
    });

    test('8. RNF and BNF gateway histories remain separate', () {
      final graph = builder.build(
        monitoredDevices: endpoints,
        infraDevices: unifiAps,
        infraStatuses: {
          '192.168.22.1': DeviceStatusEnum.up, // RNF Gateway UP
          '192.168.21.1': DeviceStatusEnum.down, // BNF Gateway DOWN
        },
      );

      expect(graph.nodes['gw_rnf_22']!.status, DeviceStatusEnum.up);
      expect(graph.nodes['gw_bnf_21']!.status, DeviceStatusEnum.down);

      // WAN is reachable if at least one gateway is up
      expect(graph.nodes['wan_internet']!.status, DeviceStatusEnum.up);

      final gwStats = graph.categoryStats[TopologyDeviceCategory.gateway]!;
      expect(gwStats.online, 1);
      expect(gwStats.offline, 1);
    });

    test(
      '9. Infrastructure WebSocket updates refresh AP and gateway topology nodes',
      () {
        final initialGraph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: unifiAps,
        );

        expect(initialGraph.nodes['ap_3']!.status, DeviceStatusEnum.unknown);
        expect(
          initialGraph.nodes['gw_rnf_22']!.status,
          DeviceStatusEnum.unknown,
        );

        // Simulate live incoming WebSocket status updates for infrastructure virtual IDs
        // AP 3 has virtual ID 10003, RNF Gateway has virtual ID 50001
        final now = DateTime.now();
        final updatedGraph = initialGraph.updateStatuses({
          10003: DeviceStatusEntity(
            deviceId: 10003,
            status: DeviceStatusEnum.down,
            statusChangedAt: now,
            lastCheckAt: now,
            lastFailureReason: 'ICMP timeout',
          ),
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
            lastLatencyMs: 2,
          ),
        });

        expect(updatedGraph.nodes['ap_3']!.status, DeviceStatusEnum.down);
        expect(updatedGraph.nodes['ap_3']!.failureReason, 'ICMP timeout');
        expect(updatedGraph.nodes['gw_rnf_22']!.status, DeviceStatusEnum.up);
        expect(updatedGraph.nodes['wan_internet']!.status, DeviceStatusEnum.up);
      },
    );

    test(
      '10. Updating ordinary device statuses does not corrupt infrastructure statuses',
      () {
        final now = DateTime.now();
        final baseGraph = builder
            .build(monitoredDevices: endpoints, infraDevices: unifiAps)
            .updateStatuses({
              10003: DeviceStatusEntity(
                deviceId: 10003,
                status: DeviceStatusEnum.down,
                statusChangedAt: now,
                lastCheckAt: now,
                lastFailureReason: 'Target unreachable',
              ),
              50001: DeviceStatusEntity(
                deviceId: 50001,
                status: DeviceStatusEnum.up,
                statusChangedAt: now,
                lastCheckAt: now,
                lastLatencyMs: 3,
              ),
            });

        expect(baseGraph.nodes['ap_3']!.status, DeviceStatusEnum.down);
        expect(baseGraph.nodes['gw_rnf_22']!.status, DeviceStatusEnum.up);

        // Now update an endpoint device (101)
        final afterEndpointUpdate = baseGraph.updateStatuses({
          101: DeviceStatusEntity(
            deviceId: 101,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
            lastLatencyMs: 1,
          ),
        });

        // Endpoint updated
        expect(
          afterEndpointUpdate.nodes['dev_101']!.status,
          DeviceStatusEnum.up,
        );
        // Infrastructure preserved
        expect(
          afterEndpointUpdate.nodes['ap_3']!.status,
          DeviceStatusEnum.down,
        );
        expect(
          afterEndpointUpdate.nodes['gw_rnf_22']!.status,
          DeviceStatusEnum.up,
        );
      },
    );

    test(
      '11. Category counters match actual registered assets and statuses',
      () {
        final now = DateTime.now();
        final statuses = [
          DeviceStatusEntity(
            deviceId: 1,
            status: DeviceStatusEnum.up,
            lastCheckAt: now,
            statusChangedAt: now,
          ),
          DeviceStatusEntity(
            deviceId: 2,
            status: DeviceStatusEnum.down,
            lastCheckAt: now,
            statusChangedAt: now,
          ),
          DeviceStatusEntity(
            deviceId: 3,
            status: DeviceStatusEnum.degraded,
            lastCheckAt: now,
            statusChangedAt: now,
          ),
          DeviceStatusEntity(
            deviceId: 4,
            status: DeviceStatusEnum.up,
            lastCheckAt: now.subtract(const Duration(seconds: 300)), // Stale
            statusChangedAt: now.subtract(const Duration(seconds: 300)),
          ),
          DeviceStatusEntity(
            deviceId: 5,
            status: DeviceStatusEnum.unknown,
            statusChangedAt: now,
          ),
        ];

        final count = CategoryStatusCount.fromStatuses(
          statuses,
          now: now,
          freshnessWindowSeconds: 180,
        );

        expect(count.total, 5);
        expect(count.online, 1);
        expect(count.offline, 1);
        expect(count.degraded, 1);
        expect(count.stale, 1);
        expect(count.unknown, 1);
        expect(
          count.online +
              count.offline +
              count.degraded +
              count.stale +
              count.unknown,
          count.total,
        );
      },
    );

    test(
      '12. No fake green links or fake active port counts are displayed as verified data',
      () {
        final graph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: unifiAps,
        );

        // Verify that links connected to inferred location groups are marked inferred
        final inferredLinks = graph.links.where((l) => l.isInferred).toList();
        expect(inferredLinks.isNotEmpty, isTrue);

        for (final link in inferredLinks) {
          expect(link.status, DeviceStatusEnum.unknown);
          expect(link.speed, isNull);
          expect(link.fromPort, isNull);
          expect(link.toPort, isNull);
        }

        // Verify inferred switch nodes have no synthetic activePortCount
        for (final node in graph.nodes.values.where((n) => n.isInferred)) {
          expect(node.activePortCount, isNull);
          expect(node.vendor, isNull);
          expect(node.status, DeviceStatusEnum.unknown);
        }
      },
    );
  });
}
