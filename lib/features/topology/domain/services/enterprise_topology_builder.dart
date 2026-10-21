import 'dart:math';
import 'dart:ui';
import 'package:injectable/injectable.dart';

import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import '../entities/enterprise_topology_models.dart';

@lazySingleton
class EnterpriseTopologyBuilder {
  const EnterpriseTopologyBuilder();

  EnterpriseTopologyGraph build({
    required List<MonitoredDevice> monitoredDevices,
    required List<UniFiDeviceEntity> infraDevices,
    Map<String, DeviceStatusEnum>? infraStatuses,
  }) {
    final Map<String, EnterpriseTopologyNode> nodes = {};
    final List<EnterpriseTopologyLink> links = [];
    final List<EnterpriseTopologyNode> unlinkedNodes = [];

    // ── 1. LEVEL 0: WAN / Internet ──────────────────────────────────────────
    const wanId = 'wan_internet';
    nodes[wanId] = const EnterpriseTopologyNode(
      id: wanId,
      title: 'Internet / WAN',
      subtitle: 'Fiber Uplink (Corporate)',
      category: TopologyDeviceCategory.wan,
      status: DeviceStatusEnum.up,
      level: 0,
      location: 'External WAN',
      vendor: 'ISP / Telecom',
      isMonitored: true,
      size: Size(168, 60),
    );

    // ── 2. LEVEL 1: Gateways & Core Routers ──────────────────────────────────
    // Determine gateways from infra devices or standard subnet gateways
    final List<String> gatewayIds = [];

    // Check if infrastructure devices contain a gateway
    final infraGateways = infraDevices.where((d) => d.isGateway).toList();
    if (infraGateways.isNotEmpty) {
      for (final ig in infraGateways) {
        final id = 'gw_${ig.id}';
        final status =
            infraStatuses?[ig.ip] ??
            (ig.isEnabled ? DeviceStatusEnum.up : DeviceStatusEnum.unknown);
        nodes[id] = EnterpriseTopologyNode(
          id: id,
          title: ig.name,
          subtitle: ig.ip,
          category: TopologyDeviceCategory.gateway,
          status: status,
          level: 1,
          location: ig.location ?? 'Server Room',
          mac: ig.mac,
          vendor: 'UniFi Gateway',
          infraRef: ig,
          size: const Size(168, 60),
        );
        gatewayIds.add(id);
        links.add(
          EnterpriseTopologyLink(
            id: 'link_wan_$id',
            fromNodeId: wanId,
            toNodeId: id,
            fromPort: 'WAN1',
            toPort: 'Uplink',
            status: status,
          ),
        );
      }
    } else {
      // Primary Subnet Gateway 192.168.27.1
      const gwPrimaryId = 'gw_core_27';
      final gwPrimaryStatus =
          infraStatuses?['192.168.27.1'] ?? DeviceStatusEnum.up;
      nodes[gwPrimaryId] = EnterpriseTopologyNode(
        id: gwPrimaryId,
        title: 'Core Gateway (VLAN 27)',
        subtitle: '192.168.27.1',
        category: TopologyDeviceCategory.gateway,
        status: gwPrimaryStatus,
        level: 1,
        location: 'Server Room',
        vendor: 'Cisco / Enterprise Gateway',
        size: const Size(168, 60),
      );
      gatewayIds.add(gwPrimaryId);
      links.add(
        EnterpriseTopologyLink(
          id: 'link_wan_gw27',
          fromNodeId: wanId,
          toNodeId: gwPrimaryId,
          fromPort: 'WAN1',
          toPort: 'Uplink',
          status: gwPrimaryStatus,
        ),
      );

      // Secondary Subnet Gateway 192.168.22.1
      const gwSecondaryId = 'gw_core_22';
      final gwSecondaryStatus =
          infraStatuses?['192.168.22.1'] ?? DeviceStatusEnum.up;
      nodes[gwSecondaryId] = EnterpriseTopologyNode(
        id: gwSecondaryId,
        title: 'Subnet Gateway (VLAN 22)',
        subtitle: '192.168.22.1',
        category: TopologyDeviceCategory.gateway,
        status: gwSecondaryStatus,
        level: 1,
        location: 'Server Room',
        vendor: 'Cisco / Enterprise Gateway',
        size: const Size(168, 60),
      );
      gatewayIds.add(gwSecondaryId);
      links.add(
        EnterpriseTopologyLink(
          id: 'link_wan_gw22',
          fromNodeId: wanId,
          toNodeId: gwSecondaryId,
          fromPort: 'WAN2',
          toPort: 'Uplink',
          status: gwSecondaryStatus,
        ),
      );
    }

    // ── 3. Group Monitored Endpoints by Location / Switch ──────────────────
    final Map<String, List<MonitoredDevice>> locationGroups = {};
    for (final md in monitoredDevices) {
      final loc = md.device.officeLocation?.trim().isNotEmpty == true
          ? md.device.officeLocation!.trim()
          : (md.device.department.trim().isNotEmpty
                ? md.device.department.trim()
                : 'General Office');
      locationGroups.putIfAbsent(loc, () => []).add(md);
    }

    // Deterministic sorting of locations: primary VLAN 27 locations first, then VLAN 22 locations, then by name
    final sortedLocations = locationGroups.keys.toList()
      ..sort((a, b) {
        final aIs22 =
            a.toLowerCase().contains('22') ||
            (locationGroups[a]?.first.device.ip.contains('.22.') ?? false);
        final bIs22 =
            b.toLowerCase().contains('22') ||
            (locationGroups[b]?.first.device.ip.contains('.22.') ?? false);
        if (aIs22 != bIs22) return aIs22 ? 1 : -1;
        // Place locations with higher endpoint count first for visual balance
        final countA = locationGroups[a]?.length ?? 0;
        final countB = locationGroups[b]?.length ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });

    // ── 4. LEVEL 2: Distribution / Location Switches ────────────────────────
    final List<String> switchIds = [];
    int switchIndex = 1;

    // Map each location to a dedicated switch node
    final Map<String, String> locationToSwitchId = {};
    for (final loc in sortedLocations) {
      final swId = 'sw_${loc.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}';
      locationToSwitchId[loc] = swId;
      switchIds.add(swId);

      final childrenCount = locationGroups[loc]?.length ?? 0;
      // Determine upstream gateway
      final upstreamGwId =
          loc.toLowerCase().contains('22') ||
              (locationGroups[loc]?.first.device.ip.contains('.22.') ?? false)
          ? (gatewayIds.length > 1 ? gatewayIds[1] : gatewayIds.first)
          : gatewayIds.first;

      nodes[swId] = EnterpriseTopologyNode(
        id: swId,
        title: '$loc Switch',
        subtitle: 'L2 Managed Switch',
        category: TopologyDeviceCategory.switchDevice,
        status: DeviceStatusEnum.up,
        level: 2,
        location: loc,
        vendor: 'Cisco Catalyst / Managed',
        activePortCount: childrenCount,
        totalPortCount: childrenCount > 16 ? 48 : 24,
        size: const Size(168, 60),
      );

      links.add(
        EnterpriseTopologyLink(
          id: 'link_${upstreamGwId}_$swId',
          fromNodeId: upstreamGwId,
          toNodeId: swId,
          fromPort: 'Gi0/${switchIndex++}',
          toPort: 'Uplink (Trunk)',
          status: DeviceStatusEnum.up,
        ),
      );
    }

    // ── 5. LEVEL 3: UniFi Access Points (from Infrastructure Devices) ─────────
    final unifiAps = infraDevices
        .where((d) => d.role == UniFiDeviceRole.accessPoint)
        .toList();
    for (int i = 0; i < unifiAps.length; i++) {
      final ap = unifiAps[i];
      final apId = 'ap_${ap.id}';
      final status =
          infraStatuses?[ap.ip] ??
          (ap.isEnabled ? DeviceStatusEnum.up : DeviceStatusEnum.unknown);

      // Map AP to appropriate location switch or default to first/Main Office switch
      String parentSwId = switchIds.first;
      for (final loc in sortedLocations) {
        if (ap.location != null &&
            ap.location!.toLowerCase().contains(loc.toLowerCase())) {
          parentSwId = locationToSwitchId[loc] ?? parentSwId;
          break;
        }
      }

      nodes[apId] = EnterpriseTopologyNode(
        id: apId,
        title: ap.name,
        subtitle: ap.ip,
        category: TopologyDeviceCategory.accessPoint,
        status: status,
        level: 3,
        location: ap.location ?? 'Facility AP Area',
        mac: ap.mac,
        vendor: 'Ubiquiti UniFi AP',
        infraRef: ap,
        size: const Size(168, 60),
      );

      links.add(
        EnterpriseTopologyLink(
          id: 'link_${parentSwId}_$apId',
          fromNodeId: parentSwId,
          toNodeId: apId,
          fromPort: 'PoE+ / Gi0/${20 + i}',
          toPort: 'ETH0',
          status: status,
        ),
      );
    }

    // ── 6. LEVEL 4: Endpoints & Clients (Monitored Devices) ─────────────────
    for (final loc in sortedLocations) {
      final swId = locationToSwitchId[loc] ?? switchIds.first;
      final devList = locationGroups[loc] ?? [];

      for (int i = 0; i < devList.length; i++) {
        final md = devList[i];
        final devId = 'dev_${md.device.id}';

        TopologyDeviceCategory cat = TopologyDeviceCategory.pc;
        if (md.device.type.name.toLowerCase().contains('laptop')) {
          cat = TopologyDeviceCategory.laptop;
        } else if (md.device.name.toLowerCase().contains('svr') ||
            md.device.name.toLowerCase().contains('server')) {
          cat = TopologyDeviceCategory.server;
        } else if (md.device.type.name.toLowerCase().contains('printer')) {
          cat = TopologyDeviceCategory.printer;
        }

        nodes[devId] = EnterpriseTopologyNode(
          id: devId,
          title: md.device.name,
          subtitle: md.device.ip,
          category: cat,
          status: md.status.status,
          level: 4,
          location: md.device.officeLocation,
          department: md.device.department,
          mac: md.device.mac,
          vendor: md.device.vendor,
          model: md.device.model,
          hostname: md.device.hostname,
          lastLatencyMs: md.status.lastLatencyMs,
          isMonitored: md.device.isMonitored,
          deviceRef: md.device,
          size: const Size(168, 60),
        );

        links.add(
          EnterpriseTopologyLink(
            id: 'link_${swId}_$devId',
            fromNodeId: swId,
            toNodeId: devId,
            fromPort: 'Port ${i + 1}',
            toPort: 'ETH',
            status: md.status.status,
          ),
        );
      }
    }

    // ── 7. Calculate Deterministic Vertical & Horizontal Coordinates ────────
    final positionedGraph = _computeLayout(nodes, links, unlinkedNodes);
    return positionedGraph;
  }

  EnterpriseTopologyGraph _computeLayout(
    Map<String, EnterpriseTopologyNode> inputNodes,
    List<EnterpriseTopologyLink> links,
    List<EnterpriseTopologyNode> unlinked,
  ) {
    const double cardWidth = 168.0;
    const double cardHeight = 60.0;
    const double cardGapY = 8.0;
    const double colSpacing = 220.0;
    const double branchGap = 16.0;
    const double padX = 40.0;
    const double padY = 36.0;

    // Group nodes by level
    final Map<int, List<EnterpriseTopologyNode>> levels = {};
    for (final node in inputNodes.values) {
      levels.putIfAbsent(node.level, () => []).add(node);
    }

    final Map<String, Offset> positions = {};
    double currentY = padY;

    // Map parent switch to its endpoint children (sorted deterministically)
    final Map<String, List<String>> switchChildren = {};
    for (final link in links) {
      if (inputNodes[link.toNodeId]?.level == 4) {
        switchChildren
            .putIfAbsent(link.fromNodeId, () => [])
            .add(link.toNodeId);
      }
    }
    for (final children in switchChildren.values) {
      children.sort(
        (a, b) =>
            (inputNodes[a]?.title ?? a).compareTo(inputNodes[b]?.title ?? b),
      );
    }

    // Map switch to its AP children (Level 3)
    final Map<String, List<String>> switchAps = {};
    for (final link in links) {
      if (inputNodes[link.toNodeId]?.level == 3) {
        switchAps.putIfAbsent(link.fromNodeId, () => []).add(link.toNodeId);
      }
    }
    for (final aps in switchAps.values) {
      aps.sort(
        (a, b) =>
            (inputNodes[a]?.title ?? a).compareTo(inputNodes[b]?.title ?? b),
      );
    }

    final double level0X = padX;
    final double level1X = padX + (1 * colSpacing);
    final double level2X = padX + (2 * colSpacing);
    final double level3X = padX + (3 * colSpacing);
    final double level4X = padX + (4 * colSpacing);
    final double level4X_2 =
        level4X + cardWidth + 30.0; // Compact 2nd column for large branches

    // Iterate through Level 2 switches and allocate vertical space for their branches
    final level2Switches = levels[2] ?? [];
    final Map<String, double> switchYPositions = {};

    for (final swNode in level2Switches) {
      final children = switchChildren[swNode.id] ?? [];
      final aps = switchAps[swNode.id] ?? [];

      final double branchStartY = currentY;

      // 1. Position APs for this switch at Level 3
      if (aps.isNotEmpty) {
        for (int i = 0; i < aps.length; i++) {
          final apId = aps[i];
          positions[apId] = Offset(level3X, currentY);
          currentY += cardHeight + cardGapY;
        }
      }

      // 2. Position Endpoints for this switch at Level 4 (Single or Dual Column)
      if (children.isNotEmpty) {
        if (children.length <= 4) {
          // Single column layout
          for (int i = 0; i < children.length; i++) {
            final childId = children[i];
            positions[childId] = Offset(level4X, currentY);
            currentY += cardHeight + cardGapY;
          }
        } else {
          // Dual column layout to distribute large branches horizontally
          final mid = (children.length / 2).ceil();
          final colA = children.sublist(0, mid);
          final colB = children.sublist(mid);

          final endpointsStartY = currentY;
          for (int i = 0; i < colA.length; i++) {
            positions[colA[i]] = Offset(
              level4X,
              endpointsStartY + (i * (cardHeight + cardGapY)),
            );
          }
          for (int i = 0; i < colB.length; i++) {
            positions[colB[i]] = Offset(
              level4X_2,
              endpointsStartY + (i * (cardHeight + cardGapY)),
            );
          }

          final maxRows = max(colA.length, colB.length);
          currentY = endpointsStartY + (maxRows * (cardHeight + cardGapY));
        }
      } else if (aps.isEmpty) {
        currentY += cardHeight + cardGapY;
      }

      final double branchEndY = currentY - (cardHeight + cardGapY);
      // Center the parent switch relative to its subtree
      final double swY = (branchStartY + branchEndY) / 2;
      positions[swNode.id] = Offset(level2X, swY);
      switchYPositions[swNode.id] = swY;

      // Add compact padding between branches
      currentY += branchGap;
    }

    // Position Level 1 Gateways centered relative to their downstream switches
    final level1Gateways = levels[1] ?? [];
    if (level1Gateways.length == 1) {
      final avgY = switchYPositions.values.isNotEmpty
          ? switchYPositions.values.reduce((a, b) => a + b) /
                switchYPositions.length
          : padY + 100.0;
      positions[level1Gateways.first.id] = Offset(level1X, avgY);
    } else if (level1Gateways.length > 1) {
      // Find switches belonging to Gateway 1 vs Gateway 2 based on links
      final gw1Switches = links
          .where((l) => l.fromNodeId == level1Gateways[0].id)
          .map((l) => switchYPositions[l.toNodeId])
          .whereType<double>()
          .toList();
      final gw2Switches = links
          .where((l) => l.fromNodeId == level1Gateways[1].id)
          .map((l) => switchYPositions[l.toNodeId])
          .whereType<double>()
          .toList();

      final y1 = gw1Switches.isNotEmpty
          ? gw1Switches.reduce((a, b) => a + b) / gw1Switches.length
          : padY + 100.0;
      final y2 = gw2Switches.isNotEmpty
          ? gw2Switches.reduce((a, b) => a + b) / gw2Switches.length
          : y1 + 300.0;

      positions[level1Gateways[0].id] = Offset(level1X, y1);
      positions[level1Gateways[1].id] = Offset(level1X, y2);
    }

    // Position Level 0 WAN centered relative to all gateways
    final level0Nodes = levels[0] ?? [];
    if (level0Nodes.isNotEmpty) {
      final gwYs = level1Gateways.map((g) => positions[g.id]?.dy ?? padY);
      final avgGwY = gwYs.isNotEmpty
          ? gwYs.reduce((a, b) => a + b) / gwYs.length
          : padY + 100.0;
      positions[level0Nodes.first.id] = Offset(level0X, avgGwY);
    }

    // Create positioned nodes
    final Map<String, EnterpriseTopologyNode> positionedNodes = {};
    for (final entry in inputNodes.entries) {
      final pos = positions[entry.key] ?? Offset(level4X, padY);
      positionedNodes[entry.key] = entry.value.copyWith(
        position: pos,
        size: const Size(cardWidth, cardHeight),
      );
    }

    // Compute exact diagram bounds
    double maxX = padX;
    for (final p in positions.values) {
      if (p.dx + cardWidth > maxX) maxX = p.dx + cardWidth;
    }
    double maxY = currentY + padY;

    // Calculate Summary Stats
    final Map<TopologyDeviceCategory, (int online, int total)> stats = {};
    for (final n in positionedNodes.values) {
      final existing = stats[n.category] ?? (0, 0);
      final isOnline = n.status == DeviceStatusEnum.up;
      stats[n.category] = (existing.$1 + (isOnline ? 1 : 0), existing.$2 + 1);
    }

    return EnterpriseTopologyGraph(
      nodes: positionedNodes,
      links: links,
      unlinkedNodes: unlinked,
      canvasSize: Size(max(maxX + padX, 1320.0), max(maxY, 860.0)),
      categoryStats: stats,
    );
  }
}
