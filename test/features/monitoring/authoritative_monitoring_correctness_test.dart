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

    test(
      '8. RNF and BNF gateway histories remain separate and do not mark WAN as UP',
      () {
        final graph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: unifiAps,
          infraStatuses: {
            50001: DeviceStatusEnum.up, // RNF Gateway UP
            50002: DeviceStatusEnum.down, // BNF Gateway DOWN
          },
        );

        expect(graph.nodes['gw_rnf_22']!.status, DeviceStatusEnum.up);
        expect(graph.nodes['gw_bnf_21']!.status, DeviceStatusEnum.down);

        // LAN gateway reachability must NEVER be inferred as Internet / WAN connectivity!
        expect(graph.nodes['wan_internet']!.status, DeviceStatusEnum.unknown);

        final gwStats = graph.categoryStats[TopologyDeviceCategory.gateway]!;
        expect(gwStats.online, 1);
        expect(gwStats.offline, 1);
      },
    );

    test(
      '9. Infrastructure WebSocket updates refresh AP and gateway topology nodes without fabricating WAN online',
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
        // WAN remains strictly Unknown until externally verified!
        expect(
          updatedGraph.nodes['wan_internet']!.status,
          DeviceStatusEnum.unknown,
        );
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

    test(
      '13. Same infrastructure IP in RNF and BNF with different statuses does not collide',
      () {
        final multiFactoryAps = [
          UniFiDeviceEntity(
            id: 3,
            name: 'RNF AP Floor 1',
            ip: '192.168.7.2', // Identical IP in RNF
            role: UniFiDeviceRole.accessPoint,
            location: 'RNF Production',
            isCriticalInfrastructure: true,
            requiresAdminConfirmation: false,
            linkedSubnets: const ['192.168.7.0/24'],
            siteName: 'RNF Factory Site',
            isEnabled: true,
            isReadOnly: false,
            createdAt: DateTime(2026),
          ),
          UniFiDeviceEntity(
            id: 7,
            name: 'BNF AP Admin Office',
            ip: '192.168.7.2', // Identical IP in BNF
            role: UniFiDeviceRole.accessPoint,
            location: 'BNF Main Office',
            isCriticalInfrastructure: true,
            requiresAdminConfirmation: false,
            linkedSubnets: const ['192.168.7.0/24'],
            siteName: 'BNF Factory Site',
            isEnabled: true,
            isReadOnly: false,
            createdAt: DateTime(2026),
          ),
        ];

        // Build graph with stable virtual IDs: RNF AP is 10003 (UP), BNF AP is 10007 (DOWN)
        final now = DateTime.now();
        final statusMap = {
          10003: DeviceStatusEntity(
            deviceId: 10003,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
            lastLatencyMs: 8,
          ),
          10007: DeviceStatusEntity(
            deviceId: 10007,
            status: DeviceStatusEnum.down,
            statusChangedAt: now,
            lastCheckAt: now,
            lastFailureReason: 'Port link down',
          ),
        };

        final graph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: multiFactoryAps,
          statuses: statusMap,
        );

        final rnfApNode = graph.nodes['ap_3'];
        final bnfApNode = graph.nodes['ap_7'];

        expect(rnfApNode, isNotNull);
        expect(bnfApNode, isNotNull);
        // Both nodes share the same IP
        expect(rnfApNode!.subtitle, '192.168.7.2');
        expect(bnfApNode!.subtitle, '192.168.7.2');
        // But statuses are completely independent and uncollided!
        expect(rnfApNode.status, DeviceStatusEnum.up);
        expect(bnfApNode.status, DeviceStatusEnum.down);
        expect(bnfApNode.failureReason, 'Port link down');
      },
    );

    test(
      '14. Verified links dynamically transition from UP to DOWN when connected endpoint fails',
      () {
        final verifiedSwitch = UniFiDeviceEntity(
          id: 11,
          name: 'USW-Core-RNF',
          ip: '192.168.22.5',
          role: UniFiDeviceRole.switchDevice,
          location: 'RNF Server Room',
          isCriticalInfrastructure: true,
          requiresAdminConfirmation: false,
          linkedSubnets: const ['192.168.22.0/24'],
          siteName: 'RNF Site',
          isEnabled: true,
          isReadOnly: false,
          createdAt: DateTime(2026),
        );

        final now = DateTime.now();
        // Initially both Switch (10011) and AP 3 (10003) and Gateway (50001) are UP
        final initialStatuses = {
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
          10011: DeviceStatusEntity(
            deviceId: 10011,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
        };

        final initialGraph = builder.build(
          monitoredDevices: [],
          infraDevices: [verifiedSwitch],
          statuses: initialStatuses,
          factoryId: 'rnf',
        );

        final linkGwSw = initialGraph.links.firstWhere(
          (l) => l.fromNodeId == 'gw_rnf_22' && l.toNodeId == 'sw_11',
        );
        expect(linkGwSw.status, DeviceStatusEnum.up);
        expect(linkGwSw.isInferred, isFalse);

        // Now Switch (10011) goes DOWN
        final updatedGraph = initialGraph.updateStatuses({
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
          10011: DeviceStatusEntity(
            deviceId: 10011,
            status: DeviceStatusEnum.down,
            statusChangedAt: now,
            lastCheckAt: now,
            lastFailureReason: 'Power loss',
          ),
        });

        final updatedLinkGwSw = updatedGraph.links.firstWhere(
          (l) => l.fromNodeId == 'gw_rnf_22' && l.toNodeId == 'sw_11',
        );
        // Link must dynamically update to DOWN!
        expect(updatedLinkGwSw.status, DeviceStatusEnum.down);
      },
    );

    test(
      '15. Verified links dynamically recover from DOWN to UP when endpoint recovers',
      () {
        final verifiedSwitch = UniFiDeviceEntity(
          id: 11,
          name: 'USW-Core-RNF',
          ip: '192.168.22.5',
          role: UniFiDeviceRole.switchDevice,
          location: 'RNF Server Room',
          isCriticalInfrastructure: true,
          requiresAdminConfirmation: false,
          linkedSubnets: const ['192.168.22.0/24'],
          siteName: 'RNF Site',
          isEnabled: true,
          isReadOnly: false,
          createdAt: DateTime(2026),
        );

        final now = DateTime.now();
        // Start in DOWN state
        final downGraph = builder.build(
          monitoredDevices: [],
          infraDevices: [verifiedSwitch],
          statuses: {
            50001: DeviceStatusEntity(
              deviceId: 50001,
              status: DeviceStatusEnum.up,
              statusChangedAt: now,
              lastCheckAt: now,
            ),
            10011: DeviceStatusEntity(
              deviceId: 10011,
              status: DeviceStatusEnum.down,
              statusChangedAt: now,
              lastCheckAt: now,
            ),
          },
          factoryId: 'rnf',
        );

        expect(
          downGraph.links
              .firstWhere(
                (l) => l.fromNodeId == 'gw_rnf_22' && l.toNodeId == 'sw_11',
              )
              .status,
          DeviceStatusEnum.down,
        );

        // Now Switch recovers to UP
        final recoveredGraph = downGraph.updateStatuses({
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
          10011: DeviceStatusEntity(
            deviceId: 10011,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
        });

        // Link must restore to UP!
        expect(
          recoveredGraph.links
              .firstWhere(
                (l) => l.fromNodeId == 'gw_rnf_22' && l.toNodeId == 'sw_11',
              )
              .status,
          DeviceStatusEnum.up,
        );
      },
    );

    test(
      '16. Inferred links strictly remain UNKNOWN even when downstream endpoint is UP',
      () {
        final now = DateTime.now();
        final graph = builder.build(
          monitoredDevices: endpoints,
          infraDevices: unifiAps,
        );

        // Both endpoint 101 and gateway 50001 are UP
        final updatedGraph = graph.updateStatuses({
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
          101: DeviceStatusEntity(
            deviceId: 101,
            status: DeviceStatusEnum.up,
            statusChangedAt: now,
            lastCheckAt: now,
          ),
        });

        final inferredLinks = updatedGraph.links
            .where((l) => l.isInferred)
            .toList();
        expect(inferredLinks.isNotEmpty, isTrue);

        // Inferred relationships MUST NEVER turn green (UP)!
        for (final l in inferredLinks) {
          expect(l.status, DeviceStatusEnum.unknown);
        }
      },
    );

    test('17. Gateway reachability is not reported as Internet connectivity', () {
      final graph = builder.build(
        monitoredDevices: endpoints,
        infraDevices: unifiAps,
        statuses: {
          50001: DeviceStatusEntity(
            deviceId: 50001,
            status: DeviceStatusEnum.up,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
          50002: DeviceStatusEntity(
            deviceId: 50002,
            status: DeviceStatusEnum.up,
            statusChangedAt: DateTime.now(),
            lastCheckAt: DateTime.now(),
          ),
        },
      );

      // Gateways are UP
      expect(graph.nodes['gw_rnf_22']!.status, DeviceStatusEnum.up);
      expect(graph.nodes['gw_bnf_21']!.status, DeviceStatusEnum.up);

      // But Internet / WAN node status must remain UNKNOWN (not inferred from LAN gateways)
      expect(graph.nodes['wan_internet']!.status, DeviceStatusEnum.unknown);

      // And links from WAN to gateways remain UNKNOWN
      final wanLinks = graph.links
          .where((l) => l.fromNodeId == 'wan_internet')
          .toList();
      for (final wl in wanLinks) {
        expect(wl.status, DeviceStatusEnum.unknown);
      }
    });

    test(
      '18. One and two consecutive failures are visibly distinguished as transitional states',
      () {
        final now = DateTime.now();
        final freshOnline = DeviceStatusEntity(
          deviceId: 101,
          status: DeviceStatusEnum.up,
          statusChangedAt: now,
          lastCheckAt: now,
          consecutiveFailures: 0,
        );
        expect(freshOnline.isTransitionalFailing, isFalse);
        expect(freshOnline.transitionalLabel, 'Online');

        // 1st failure: retained as UP, but transitional failing is TRUE
        final fail1 = StatusEngine.processCheckResult(
          currentStatus: freshOnline,
          checkResult: CheckResult.failure(
            deviceId: 101,
            targetIp: '192.168.27.10',
            timestamp: now,
            errorMessage: 'Request timed out',
          ),
          config: config,
        );
        expect(fail1.status, DeviceStatusEnum.up);
        expect(fail1.consecutiveFailures, 1);
        expect(fail1.isTransitionalFailing, isTrue);
        expect(
          fail1.transitionalLabel,
          'Previously Online · 1/3 Failed Checks',
        );
        expect(fail1.lastFailureReason, 'Request timed out');

        // 2nd failure: still UP, but 2/3 Failed Checks
        final fail2 = StatusEngine.processCheckResult(
          currentStatus: fail1,
          checkResult: CheckResult.failure(
            deviceId: 101,
            targetIp: '192.168.27.10',
            timestamp: now,
            errorMessage: 'Request timed out',
          ),
          config: config,
        );
        expect(fail2.status, DeviceStatusEnum.up);
        expect(fail2.consecutiveFailures, 2);
        expect(fail2.isTransitionalFailing, isTrue);
        expect(
          fail2.transitionalLabel,
          'Previously Online · 2/3 Failed Checks',
        );

        // Verify EnterpriseTopologyNode exposes this state
        final node = EnterpriseTopologyNode(
          id: 'dev_101',
          title: 'PC-101',
          category: TopologyDeviceCategory.pc,
          status: fail2.status,
          level: 4,
          consecutiveFailures: fail2.consecutiveFailures,
          failureReason: fail2.lastFailureReason,
        );
        expect(node.isTransitionalFailing, isTrue);
        expect(node.transitionalLabel, 'Previously Online · 2/3 Failed Checks');
      },
    );

    test('19. Three consecutive failures produce Offline', () {
      final now = DateTime.now();
      final fail2 = DeviceStatusEntity(
        deviceId: 101,
        status: DeviceStatusEnum.up,
        statusChangedAt: now,
        lastCheckAt: now,
        consecutiveFailures: 2,
      );

      // 3rd failure reaches threshold of 3 -> marks DOWN
      final fail3 = StatusEngine.processCheckResult(
        currentStatus: fail2,
        checkResult: CheckResult.failure(
          deviceId: 101,
          targetIp: '192.168.27.10',
          timestamp: now,
          errorMessage: 'Request timed out',
        ),
        config: config,
      );
      expect(fail3.status, DeviceStatusEnum.down);
      expect(fail3.consecutiveFailures, 3);
      expect(fail3.effectiveStatus(), DeviceStatusEnum.down);
      expect(fail3.isTransitionalFailing, isFalse);
    });
  });
}
