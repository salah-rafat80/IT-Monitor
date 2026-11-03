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
    Map<dynamic, DeviceStatusEnum>? infraStatuses,
    Map<int, DeviceStatusEntity>? statuses,
    String? factoryId,
  }) {
    final Map<String, EnterpriseTopologyNode> nodes = {};
    final List<EnterpriseTopologyLink> links = [];
    final List<EnterpriseTopologyNode> unlinkedNodes = [];

    DeviceStatusEnum resolveInfraStatus(int virtualId, [String? fallbackIp]) {
      if (statuses != null && statuses.containsKey(virtualId)) {
        return statuses[virtualId]!.effectiveStatus();
      }
      if (infraStatuses != null) {
        if (infraStatuses.containsKey(virtualId)) {
          return infraStatuses[virtualId]!;
        }
        if (fallbackIp != null && infraStatuses.containsKey(fallbackIp)) {
          return infraStatuses[fallbackIp]!;
        }
      }
      return DeviceStatusEnum.unknown;
    }

    DeviceStatusEntity? getStatusEntity(int virtualId) {
      return statuses?[virtualId];
    }

    // ── 1. LEVEL 1: Gateways & Core Routers ──────────────────────────────────
    // Core gateways MUST come only from registered factory gateways or verified infrastructure records.
    // Never fabricate guessed gateways (e.g. 192.168.27.1 or dynamic $subnet.1).
    final List<String> gatewayIds = [];
    final infraGateways = infraDevices.where((d) => d.isGateway).toList();

    if (infraGateways.isNotEmpty) {
      for (final ig in infraGateways) {
        final id = 'gw_${ig.id}';
        final virtualId = 10000 + ig.id;
        final status = resolveInfraStatus(virtualId, ig.ip);
        final ent = getStatusEntity(virtualId);
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
          isInferred: false,
          lastLatencyMs: ent?.lastLatencyMs,
          lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
          lastCheckAt: ent?.lastCheckAt,
          lastSuccessfulCheckAt: ent?.lastSeen,
          failureReason: ent?.lastFailureReason,
          consecutiveFailures: ent?.consecutiveFailures ?? 0,
          size: const Size(168, 60),
        );
        gatewayIds.add(id);
      }
    }

    // Include registered factory gateways: RNF (192.168.22.1) and BNF (192.168.21.1)
    final includeRnf = factoryId == null || factoryId.toLowerCase() == 'rnf';
    final includeBnf = factoryId == null || factoryId.toLowerCase() == 'bnf';

    if (includeRnf && !nodes.values.any((n) => n.subtitle == '192.168.22.1')) {
      const gwRnfId = 'gw_rnf_22';
      final gwRnfStatus = resolveInfraStatus(50001, '192.168.22.1');
      final ent = getStatusEntity(50001);
      nodes[gwRnfId] = EnterpriseTopologyNode(
        id: gwRnfId,
        title: 'RNF Factory Gateway',
        subtitle: '192.168.22.1',
        category: TopologyDeviceCategory.gateway,
        status: gwRnfStatus,
        level: 1,
        location: 'RNF Server Room',
        vendor: 'Cisco / Enterprise Gateway',
        isInferred: false,
        lastLatencyMs: ent?.lastLatencyMs,
        lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
        lastCheckAt: ent?.lastCheckAt,
        lastSuccessfulCheckAt: ent?.lastSeen,
        failureReason: ent?.lastFailureReason,
        consecutiveFailures: ent?.consecutiveFailures ?? 0,
        size: const Size(168, 60),
      );
      gatewayIds.add(gwRnfId);
    }

    if (includeBnf && !nodes.values.any((n) => n.subtitle == '192.168.21.1')) {
      const gwBnfId = 'gw_bnf_21';
      final gwBnfStatus = resolveInfraStatus(50002, '192.168.21.1');
      final ent = getStatusEntity(50002);
      nodes[gwBnfId] = EnterpriseTopologyNode(
        id: gwBnfId,
        title: 'BNF Factory Gateway',
        subtitle: '192.168.21.1',
        category: TopologyDeviceCategory.gateway,
        status: gwBnfStatus,
        level: 1,
        location: 'BNF Server Room',
        vendor: 'Cisco / Enterprise Gateway',
        isInferred: false,
        lastLatencyMs: ent?.lastLatencyMs,
        lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
        lastCheckAt: ent?.lastCheckAt,
        lastSuccessfulCheckAt: ent?.lastSeen,
        failureReason: ent?.lastFailureReason,
        consecutiveFailures: ent?.consecutiveFailures ?? 0,
        size: const Size(168, 60),
      );
      gatewayIds.add(gwBnfId);
    }

    // Fallback if no gateways were configured (e.g. unassigned factory filter)
    if (gatewayIds.isEmpty) {
      const fallbackGwId = 'gw_rnf_22';
      final fallbackStatus = resolveInfraStatus(50001, '192.168.22.1');
      final ent = getStatusEntity(50001);
      nodes[fallbackGwId] = EnterpriseTopologyNode(
        id: fallbackGwId,
        title: 'Factory Gateway',
        subtitle: '192.168.22.1',
        category: TopologyDeviceCategory.gateway,
        status: fallbackStatus,
        level: 1,
        location: 'Server Room',
        vendor: 'Enterprise Gateway',
        isInferred: false,
        lastLatencyMs: ent?.lastLatencyMs,
        lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
        lastCheckAt: ent?.lastCheckAt,
        lastSuccessfulCheckAt: ent?.lastSeen,
        failureReason: ent?.lastFailureReason,
        consecutiveFailures: ent?.consecutiveFailures ?? 0,
        size: const Size(168, 60),
      );
      gatewayIds.add(fallbackGwId);
    }

    // ── 2. LEVEL 0: WAN / Internet ──────────────────────────────────────────
    // WAN / Internet status remains strictly Unknown until externally verified.
    // Core gateway ICMP reachability must NEVER be inferred as Internet connectivity!
    const wanStatus = DeviceStatusEnum.unknown;

    const wanId = 'wan_internet';
    nodes[wanId] = EnterpriseTopologyNode(
      id: wanId,
      title: 'Internet / WAN',
      subtitle: 'External Gateway Reachability',
      category: TopologyDeviceCategory.wan,
      status: wanStatus,
      level: 0,
      location: 'External WAN',
      vendor: 'ISP / Telecom',
      isMonitored: false,
      isInferred: false,
      size: const Size(168, 60),
    );

    // Links from WAN to Core Gateways: unverified external uplink -> status: unknown
    for (int i = 0; i < gatewayIds.length; i++) {
      final gId = gatewayIds[i];
      links.add(
        EnterpriseTopologyLink(
          id: 'link_wan_$gId',
          fromNodeId: wanId,
          toNodeId: gId,
          fromPort: 'WAN${i + 1}',
          toPort: 'Uplink',
          status: DeviceStatusEnum.unknown,
          isInferred: false,
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

    // Deterministic sorting of locations: BNF (.21.) / RNF (.22.) / other, then endpoint count, then name
    final sortedLocations = locationGroups.keys.toList()
      ..sort((a, b) {
        final aIs22 =
            a.toLowerCase().contains('22') ||
            (locationGroups[a]?.first.device.ip.contains('.22.') ?? false);
        final bIs22 =
            b.toLowerCase().contains('22') ||
            (locationGroups[b]?.first.device.ip.contains('.22.') ?? false);
        if (aIs22 != bIs22) return aIs22 ? 1 : -1;
        final countA = locationGroups[a]?.length ?? 0;
        final countB = locationGroups[b]?.length ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });

    // ── 4. LEVEL 2: Distribution / Inferred Location Groups ────────────────
    final List<String> switchIds = [];
    final verifiedSwitches = infraDevices
        .where((d) => d.role == UniFiDeviceRole.switchDevice)
        .toList();

    final Map<String, String> locationToSwitchId = {};
    for (final loc in sortedLocations) {
      final swId = 'sw_${loc.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}';
      locationToSwitchId[loc] = swId;
      switchIds.add(swId);

      final childrenCount = locationGroups[loc]?.length ?? 0;

      // Determine upstream gateway
      final firstDeviceIp = locationGroups[loc]?.first.device.ip;
      String upstreamGwId = gatewayIds.first;
      if (loc.toLowerCase().contains('21') ||
          (firstDeviceIp?.contains('.21.') ?? false)) {
        final bnfMatch = gatewayIds
            .where((id) => id.contains('bnf'))
            .firstOrNull;
        if (bnfMatch != null) upstreamGwId = bnfMatch;
      } else if (loc.toLowerCase().contains('22') ||
          (firstDeviceIp?.contains('.22.') ?? false)) {
        final rnfMatch = gatewayIds
            .where((id) => id.contains('rnf'))
            .firstOrNull;
        if (rnfMatch != null) upstreamGwId = rnfMatch;
      }

      // Check if there is an actual verified switch record matching this location
      final matchingVerifiedSwitch = verifiedSwitches.where((s) {
        return s.location != null &&
            s.location!.toLowerCase().contains(loc.toLowerCase());
      }).firstOrNull;

      if (matchingVerifiedSwitch != null) {
        final virtualId = 10000 + matchingVerifiedSwitch.id;
        final swStatus = resolveInfraStatus(
          virtualId,
          matchingVerifiedSwitch.ip,
        );
        final ent = getStatusEntity(virtualId);
        nodes[swId] = EnterpriseTopologyNode(
          id: swId,
          title: matchingVerifiedSwitch.name,
          subtitle: matchingVerifiedSwitch.ip,
          category: TopologyDeviceCategory.switchDevice,
          status: swStatus,
          level: 2,
          location: loc,
          vendor: 'UniFi Switch',
          infraRef: matchingVerifiedSwitch,
          isInferred: false,
          lastLatencyMs: ent?.lastLatencyMs,
          lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
          lastCheckAt: ent?.lastCheckAt,
          lastSuccessfulCheckAt: ent?.lastSeen,
          failureReason: ent?.lastFailureReason,
          consecutiveFailures: ent?.consecutiveFailures ?? 0,
          size: const Size(168, 60),
        );

        final gwStatus =
            nodes[upstreamGwId]?.status ?? DeviceStatusEnum.unknown;
        DeviceStatusEnum swLinkStatus = DeviceStatusEnum.unknown;
        if (gwStatus == DeviceStatusEnum.down ||
            swStatus == DeviceStatusEnum.down) {
          swLinkStatus = DeviceStatusEnum.down;
        } else if (gwStatus == DeviceStatusEnum.up &&
            swStatus == DeviceStatusEnum.up) {
          swLinkStatus = DeviceStatusEnum.up;
        }

        links.add(
          EnterpriseTopologyLink(
            id: 'link_${upstreamGwId}_$swId',
            fromNodeId: upstreamGwId,
            toNodeId: swId,
            status: swLinkStatus,
            isInferred: false,
          ),
        );
      } else {
        // Inferred logical grouping — clearly labeled, never claimed as verified hardware
        nodes[swId] = EnterpriseTopologyNode(
          id: swId,
          title: '$loc (Logical Group)',
          subtitle: 'Inferred Grouping ($childrenCount endpoints)',
          category: TopologyDeviceCategory.switchDevice,
          status: DeviceStatusEnum.unknown,
          level: 2,
          location: loc,
          isInferred: true,
          size: const Size(168, 60),
        );

        links.add(
          EnterpriseTopologyLink(
            id: 'link_${upstreamGwId}_$swId',
            fromNodeId: upstreamGwId,
            toNodeId: swId,
            status: DeviceStatusEnum.unknown,
            isInferred: true,
          ),
        );
      }
    }

    // If no locations exist (empty endpoints), ensure at least one distribution node if verified switches exist
    if (switchIds.isEmpty) {
      for (final vSw in verifiedSwitches) {
        final swId = 'sw_${vSw.id}';
        switchIds.add(swId);
        final virtualId = 10000 + vSw.id;
        final swStatus = resolveInfraStatus(virtualId, vSw.ip);
        final ent = getStatusEntity(virtualId);
        nodes[swId] = EnterpriseTopologyNode(
          id: swId,
          title: vSw.name,
          subtitle: vSw.ip,
          category: TopologyDeviceCategory.switchDevice,
          status: swStatus,
          level: 2,
          location: vSw.location,
          vendor: 'UniFi Switch',
          infraRef: vSw,
          isInferred: false,
          lastLatencyMs: ent?.lastLatencyMs,
          lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
          lastCheckAt: ent?.lastCheckAt,
          lastSuccessfulCheckAt: ent?.lastSeen,
          failureReason: ent?.lastFailureReason,
          consecutiveFailures: ent?.consecutiveFailures ?? 0,
          size: const Size(168, 60),
        );
        final gwStatus =
            nodes[gatewayIds.first]?.status ?? DeviceStatusEnum.unknown;
        DeviceStatusEnum swLinkStatus = DeviceStatusEnum.unknown;
        if (gwStatus == DeviceStatusEnum.down ||
            swStatus == DeviceStatusEnum.down) {
          swLinkStatus = DeviceStatusEnum.down;
        } else if (gwStatus == DeviceStatusEnum.up &&
            swStatus == DeviceStatusEnum.up) {
          swLinkStatus = DeviceStatusEnum.up;
        }
        links.add(
          EnterpriseTopologyLink(
            id: 'link_${gatewayIds.first}_$swId',
            fromNodeId: gatewayIds.first,
            toNodeId: swId,
            status: swLinkStatus,
            isInferred: false,
          ),
        );
      }
    }

    // ── 5. LEVEL 3: UniFi Access Points (from Infrastructure Devices) ─────────
    final unifiAps = infraDevices
        .where((d) => d.role == UniFiDeviceRole.accessPoint)
        .toList();
    for (int i = 0; i < unifiAps.length; i++) {
      final ap = unifiAps[i];
      final apId = 'ap_${ap.id}';
      final virtualId = 10000 + ap.id;
      final status = resolveInfraStatus(virtualId, ap.ip);
      final ent = getStatusEntity(virtualId);

      String parentSwId = switchIds.isNotEmpty
          ? switchIds.first
          : gatewayIds.first;
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
        isInferred: false,
        lastLatencyMs: ent?.lastLatencyMs,
        lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
        lastCheckAt: ent?.lastCheckAt,
        lastSuccessfulCheckAt: ent?.lastSeen,
        failureReason: ent?.lastFailureReason,
        consecutiveFailures: ent?.consecutiveFailures ?? 0,
        size: const Size(168, 60),
      );

      final isParentInferred = nodes[parentSwId]?.isInferred ?? true;
      final parentStatus =
          nodes[parentSwId]?.status ?? DeviceStatusEnum.unknown;
      DeviceStatusEnum apLinkStatus = DeviceStatusEnum.unknown;
      if (!isParentInferred) {
        if (parentStatus == DeviceStatusEnum.down ||
            status == DeviceStatusEnum.down) {
          apLinkStatus = DeviceStatusEnum.down;
        } else if (parentStatus == DeviceStatusEnum.up &&
            status == DeviceStatusEnum.up) {
          apLinkStatus = DeviceStatusEnum.up;
        }
      }

      links.add(
        EnterpriseTopologyLink(
          id: 'link_${parentSwId}_$apId',
          fromNodeId: parentSwId,
          toNodeId: apId,
          toPort: isParentInferred ? null : 'ETH0',
          status: isParentInferred ? DeviceStatusEnum.unknown : apLinkStatus,
          isInferred: isParentInferred,
        ),
      );
    }

    // ── 6. LEVEL 4: Endpoints & Clients (Monitored Devices) ─────────────────
    for (final loc in sortedLocations) {
      final swId =
          locationToSwitchId[loc] ??
          (switchIds.isNotEmpty ? switchIds.first : gatewayIds.first);
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

        final effectiveStatus = md.status.effectiveStatus();

        nodes[devId] = EnterpriseTopologyNode(
          id: devId,
          title: md.device.name,
          subtitle: md.device.ip,
          category: cat,
          status: effectiveStatus,
          level: 4,
          location: md.device.officeLocation,
          department: md.device.department,
          mac: md.device.mac,
          vendor: md.device.vendor,
          model: md.device.model,
          hostname: md.device.hostname,
          lastLatencyMs: md.status.lastLatencyMs,
          lastSuccessfulLatencyMs: md.status.lastSuccessfulLatencyMs,
          lastCheckAt: md.status.lastCheckAt,
          lastSuccessfulCheckAt: md.status.lastSeen,
          failureReason: md.status.lastFailureReason,
          consecutiveFailures: md.status.consecutiveFailures,
          isMonitored: md.device.isMonitored,
          isInferred: false,
          deviceRef: md.device,
          size: const Size(168, 60),
        );

        final isSwInferred = nodes[swId]?.isInferred ?? true;
        links.add(
          EnterpriseTopologyLink(
            id: 'link_${swId}_$devId',
            fromNodeId: swId,
            toNodeId: devId,
            toPort: isSwInferred ? null : 'ETH',
            status: isSwInferred ? DeviceStatusEnum.unknown : effectiveStatus,
            isInferred: isSwInferred,
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

      // Position any additional gateways (index >= 2) on level1X without overlapping
      double lastY = y2;
      for (int i = 2; i < level1Gateways.length; i++) {
        final gwSwitches = links
            .where((l) => l.fromNodeId == level1Gateways[i].id)
            .map((l) => switchYPositions[l.toNodeId])
            .whereType<double>()
            .toList();
        double gwY = gwSwitches.isNotEmpty
            ? gwSwitches.reduce((a, b) => a + b) / gwSwitches.length
            : lastY + cardHeight + cardGapY + 20.0;
        if (gwY < lastY + cardHeight + cardGapY) {
          gwY = lastY + cardHeight + cardGapY;
        }
        positions[level1Gateways[i].id] = Offset(level1X, gwY);
        lastY = gwY;
      }
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

    // Calculate Summary Stats strictly from real registered assets (exclude inferred groups & WAN)
    final Map<TopologyDeviceCategory, CategoryStatusCount> stats = {};
    for (final n in positionedNodes.values) {
      if (n.isInferred || n.category == TopologyDeviceCategory.wan) {
        continue;
      }
      final current = stats[n.category] ?? const CategoryStatusCount();
      final isOnline = n.status == DeviceStatusEnum.up;
      final isOffline =
          n.status == DeviceStatusEnum.down ||
          n.status == DeviceStatusEnum.unreachable;
      final isDegraded = n.status == DeviceStatusEnum.degraded;
      final isStale = n.status == DeviceStatusEnum.stale;
      final isUnknown = n.status == DeviceStatusEnum.unknown;

      stats[n.category] = CategoryStatusCount(
        online: current.online + (isOnline ? 1 : 0),
        offline: current.offline + (isOffline ? 1 : 0),
        degraded: current.degraded + (isDegraded ? 1 : 0),
        unknown: current.unknown + (isUnknown ? 1 : 0),
        stale: current.stale + (isStale ? 1 : 0),
        total: current.total + 1,
      );
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
