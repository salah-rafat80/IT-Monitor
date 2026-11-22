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
    int failureThreshold = 3,
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
          vendor: null,
          infraRef: ig,
          isInferred: false,
          lastLatencyMs: ent?.lastLatencyMs,
          lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
          lastCheckAt: ent?.lastCheckAt,
          lastSuccessfulCheckAt: ent?.lastSeen,
          failureReason: ent?.lastFailureReason,
          consecutiveFailures: ent?.consecutiveFailures ?? 0,
          size: const Size(168, 60),
          failureThreshold: failureThreshold,
          virtualStatusId: virtualId,
        );
        gatewayIds.add(id);
      }
    }

    // Include registered factory gateways: RNF (192.168.22.1) and BNF (192.168.21.1)
    final isAllFactories = factoryId == null;
    final isRnf = factoryId?.toLowerCase() == 'rnf';
    final isBnf = factoryId?.toLowerCase() == 'bnf';

    if ((isAllFactories || isRnf) &&
        !nodes.values.any((n) => n.subtitle == '192.168.22.1')) {
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
        isInferred: false,
        lastLatencyMs: ent?.lastLatencyMs,
        lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
        lastCheckAt: ent?.lastCheckAt,
        lastSuccessfulCheckAt: ent?.lastSeen,
        failureReason: ent?.lastFailureReason,
        consecutiveFailures: ent?.consecutiveFailures ?? 0,
        size: const Size(168, 60),
        failureThreshold: failureThreshold,
        virtualStatusId: 50001,
      );
      gatewayIds.add(gwRnfId);
    }

    if ((isAllFactories || isBnf) &&
        !nodes.values.any((n) => n.subtitle == '192.168.21.1')) {
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
        isInferred: false,
        lastLatencyMs: ent?.lastLatencyMs,
        lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
        lastCheckAt: ent?.lastCheckAt,
        lastSuccessfulCheckAt: ent?.lastSeen,
        failureReason: ent?.lastFailureReason,
        consecutiveFailures: ent?.consecutiveFailures ?? 0,
        size: const Size(168, 60),
        failureThreshold: failureThreshold,
        virtualStatusId: 50002,
      );
      gatewayIds.add(gwBnfId);
    }

    // Never fabricate a fallback gateway when none is registered!
    // Respects RNF, BNF, All Factories, and unknown factory contexts.

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
      vendor: null,
      isMonitored: false,
      failureThreshold: failureThreshold,
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

    // ── 3. LEVEL 2: Distribution Switches & Blueprint Hierarchy ─────────────
    final List<String> switchIds = [];
    final verifiedSwitches = infraDevices
        .where((d) => d.role == UniFiDeviceRole.switchDevice)
        .toList();

    // Helper: compute verified link status strictly following precedence rules
    DeviceStatusEnum computeLinkStatus(
      EnterpriseTopologyNode? fromNode,
      EnterpriseTopologyNode? toNode, {
      bool isInferred = false,
    }) {
      if (fromNode == null || toNode == null) {
        return DeviceStatusEnum.unknown;
      }
      final s1 = fromNode.status;
      final s2 = toNode.status;
      if (s1 == DeviceStatusEnum.down ||
          s1 == DeviceStatusEnum.unreachable ||
          s2 == DeviceStatusEnum.down ||
          s2 == DeviceStatusEnum.unreachable) {
        return DeviceStatusEnum.down;
      }
      if (isInferred || fromNode.isInferred || toNode.isInferred) {
        return DeviceStatusEnum.unknown;
      }
      if (s1 == DeviceStatusEnum.stale || s2 == DeviceStatusEnum.stale) {
        return DeviceStatusEnum.stale;
      }
      if (s1 == DeviceStatusEnum.degraded ||
          s2 == DeviceStatusEnum.degraded ||
          fromNode.consecutiveFailures > 0 ||
          toNode.consecutiveFailures > 0) {
        return DeviceStatusEnum.degraded;
      }
      if (s1 == DeviceStatusEnum.up &&
          s2 == DeviceStatusEnum.up &&
          fromNode.consecutiveFailures == 0 &&
          toNode.consecutiveFailures == 0) {
        return DeviceStatusEnum.up;
      }
      return DeviceStatusEnum.unknown;
    }

    DeviceStatusEnum inferSwitchStatus(List<DeviceStatusEnum> childStatuses) {
      if (childStatuses.isEmpty) {
        return DeviceStatusEnum.unknown;
      }
      if (childStatuses.any((s) => s == DeviceStatusEnum.up)) {
        return DeviceStatusEnum.up;
      }
      if (childStatuses.every((s) => s == DeviceStatusEnum.down || s == DeviceStatusEnum.unreachable)) {
        return DeviceStatusEnum.down;
      }
      if (childStatuses.any((s) => s == DeviceStatusEnum.degraded)) {
        return DeviceStatusEnum.degraded;
      }
      return DeviceStatusEnum.unknown;
    }

    if (verifiedSwitches.isNotEmpty) {
      // ══════════════════════════════════════════════════════════════════════
      // PATH A: Production & Verified Hardware Mode (Authoritative Blueprint)
      // ══════════════════════════════════════════════════════════════════════
      // Helper: Match endpoint to its verified switch
      UniFiDeviceEntity? findMatchingSwitch(MonitoredDevice md) {
        // 1. Direct parentSwitchId match
        if (md.device.parentSwitchId != null) {
          for (final sw in verifiedSwitches) {
            if (sw.id == md.device.parentSwitchId) return sw;
          }
        }

        // 2. Direct parentSwitchName match (exact or normalized alias)
        if (md.device.parentSwitchName?.isNotEmpty == true) {
          final target = md.device.parentSwitchName!.trim().toLowerCase();
          for (final sw in verifiedSwitches) {
            final swName = sw.name.trim().toLowerCase();
            if (swName == target) return sw;
            if (target == 'switch 1' && (swName.contains('switch 1') || swName.contains('west'))) return sw;
            if (target == 'switch 2' && (swName.contains('switch 2') || swName.contains('east'))) return sw;
            if (target.contains('warehouse') && swName.contains('warehouse')) return sw;
            if (target.contains('d-link') && swName.contains('d-link')) return sw;
            if (target.contains('spare') && swName.contains('spare')) return sw;
            if (target.contains('security') && swName.contains('security')) return sw;
          }
        }

        // 3. Exact location match when defined on both switch and device
        if (md.device.officeLocation?.trim().isNotEmpty == true) {
          final loc = md.device.officeLocation!.trim().toLowerCase();
          for (final sw in verifiedSwitches) {
            final swLoc = sw.location?.trim().toLowerCase();
            if (swLoc != null && swLoc.isNotEmpty && swLoc == loc) {
              return sw;
            }
          }
        }

        // 4. Single switch fallback in targeted single-switch test/isolated contexts
        if (verifiedSwitches.length == 1) {
          return verifiedSwitches.first;
        }

        // Zero fabrication: NO heuristic guessing by IP subnet, device name!
        return null;
      }

      // Establish Authoritative Physical Backbone and Distribution Links between Verified Switches
      final swWest = verifiedSwitches.where((s) => s.name.contains('West') || s.name.contains('Switch 1')).firstOrNull;
      final swEast = verifiedSwitches.where((s) => s.name.contains('East') || s.name.contains('Switch 2')).firstOrNull;
      final swGroundCore = verifiedSwitches.where((s) => s.name.contains('Warehouse Core')).firstOrNull;
      final swDlink = verifiedSwitches.where((s) => s.name.contains('Raw Materials') || s.name.contains('D-Link')).firstOrNull;
      final swSpareparts = verifiedSwitches.where((s) => s.name.contains('Spare Parts')).firstOrNull;
      final swSecurity = verifiedSwitches.where((s) => s.name.contains('Security')).firstOrNull;

      // LEVEL 3: UniFi APs (Strictly scoped by factoryId)
      final unifiAps = infraDevices.where((d) {
        if (d.role != UniFiDeviceRole.accessPoint) return false;
        if (factoryId == null || factoryId.isEmpty) return true;
        final devFact = d.factoryId.toLowerCase();
        if (factoryId.toLowerCase() == 'rnf') {
          return devFact == 'rnf' || devFact == 'unassigned';
        }
        return devFact == factoryId.toLowerCase();
      }).toList();

      for (final vSw in verifiedSwitches) {
        final swId = 'sw_${vSw.id}';
        switchIds.add(swId);
        final virtualId = 10000 + vSw.id;

        // Inferred switch status from attached monitored endpoint devices and APs
        final attachedEndpoints = monitoredDevices.where((md) => findMatchingSwitch(md)?.id == vSw.id);
        final childStatuses = attachedEndpoints.map((md) => md.status.effectiveStatus()).toList();

        final lowerSwName = vSw.name.toLowerCase();
        for (final ap in unifiAps) {
          final lowerApName = ap.name.toLowerCase();
          bool attached = false;
          if (lowerSwName.contains('west') && lowerApName.contains('meeting')) attached = true;
          if (lowerSwName.contains('east') && lowerApName.contains('fm office')) attached = true;
          if (lowerSwName.contains('warehouse core') && (lowerApName.contains('packing') || lowerApName.contains('palitizer'))) attached = true;
          if (attached) {
            childStatuses.add(resolveInfraStatus(10000 + ap.id, ap.ip));
          }
        }

        final recordedStatus = resolveInfraStatus(virtualId, vSw.ip);
        final swStatus = (recordedStatus == DeviceStatusEnum.down ||
                recordedStatus == DeviceStatusEnum.unreachable)
            ? recordedStatus
            : (childStatuses.isNotEmpty
                ? inferSwitchStatus(childStatuses)
                : recordedStatus);

        nodes[swId] = EnterpriseTopologyNode(
          id: swId,
          title: vSw.name,
          subtitle: null,
          category: TopologyDeviceCategory.switchDevice,
          status: swStatus,
          level: 2,
          location: vSw.location,
          vendor: null,
          model: null,
          infraRef: vSw,
          isInferred: false,
          isMonitored: false,
          size: const Size(168, 60),
          failureThreshold: failureThreshold,
          virtualStatusId: virtualId,
          totalPortCount: vSw.name.contains('D-Link') ? 16 : (vSw.name.contains('Spare Parts') ? 8 : 24),
        );
      }

      const rnfGwId = 'gw_rnf_22';

      // RNF Blueprint Links
      if (swWest != null) {
        final westId = 'sw_${swWest.id}';
        if (nodes.containsKey(rnfGwId)) {
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${rnfGwId}_$westId',
              fromNodeId: rnfGwId,
              toNodeId: westId,
              fromPort: 'LAN 1',
              toPort: 'Gigabit0/24 (Trunk)',
              speed: '1 Gbps',
              status: computeLinkStatus(nodes[rnfGwId], nodes[westId]),
              isInferred: false,
            ),
          );
        }

        if (swEast != null) {
          final eastId = 'sw_${swEast.id}';
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${westId}_$eastId',
              fromNodeId: westId,
              toNodeId: eastId,
              fromPort: 'SFP 1',
              toPort: 'SFP 1',
              speed: '10G SFP+ Trunk',
              status: computeLinkStatus(nodes[westId], nodes[eastId]),
              isInferred: false,
            ),
          );
        }

        if (swGroundCore != null) {
          final gcId = 'sw_${swGroundCore.id}';
          // AUTHORITATIVE BLUEPRINT BACKBONE: Floor 1 West -> Warehouse Core Switch (0SK14sVCR1hRAYqBbC6O-16 / فايبر +كات6)
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${westId}_$gcId',
              fromNodeId: westId,
              toNodeId: gcId,
              fromPort: 'Backbone (Fiber)',
              toPort: 'Backbone (Fiber)',
              speed: 'Fiber Optic + Cat6 Backbone',
              status: computeLinkStatus(nodes[westId], nodes[gcId]),
              isInferred: false,
            ),
          );
        }
      }

      if (swGroundCore != null) {
        final gcId = 'sw_${swGroundCore.id}';
        if (swDlink != null) {
          final dlinkId = 'sw_${swDlink.id}';
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${gcId}_$dlinkId',
              fromNodeId: gcId,
              toNodeId: dlinkId,
              fromPort: 'Port 16',
              toPort: 'Uplink',
              speed: '100 Mbps / 1 Gbps',
              status: computeLinkStatus(nodes[gcId], nodes[dlinkId]),
              isInferred: false,
            ),
          );
        }

        if (swSpareparts != null) {
          final spId = 'sw_${swSpareparts.id}';
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${gcId}_$spId',
              fromNodeId: gcId,
              toNodeId: spId,
              fromPort: 'Port 18',
              toPort: 'Uplink',
              speed: '100 Mbps / 1 Gbps',
              status: computeLinkStatus(nodes[gcId], nodes[spId]),
              isInferred: false,
            ),
          );
        }
      }

      if (swSecurity != null) {
        final secId = 'sw_${swSecurity.id}';
        if (nodes.containsKey(rnfGwId)) {
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${rnfGwId}_$secId',
              fromNodeId: rnfGwId,
              toNodeId: secId,
              fromPort: 'LAN 2',
              toPort: 'Gigabit0/1',
              speed: '1 Gbps (Perimeter Trunk)',
              status: computeLinkStatus(nodes[rnfGwId], nodes[secId]),
              isInferred: false,
            ),
          );
        }
      }

      // Link any other verified switches from infraDevices not yet linked
      for (final vSw in verifiedSwitches) {
        final swId = 'sw_${vSw.id}';
        if (!links.any((l) => l.toNodeId == swId)) {
          String? upstreamGwId = gatewayIds.firstOrNull;
          if (vSw.factoryId.toLowerCase() == 'bnf' || vSw.ip.contains('.21.')) {
            upstreamGwId = gatewayIds.where((id) => id.contains('bnf')).firstOrNull ?? upstreamGwId;
          } else if (vSw.factoryId.toLowerCase() == 'rnf' || vSw.ip.contains('.22.')) {
            upstreamGwId = gatewayIds.where((id) => id.contains('rnf')).firstOrNull ?? upstreamGwId;
          }
          if (upstreamGwId != null) {
            links.add(
              EnterpriseTopologyLink(
                id: 'link_${upstreamGwId}_$swId',
                fromNodeId: upstreamGwId,
                toNodeId: swId,
                status: computeLinkStatus(nodes[upstreamGwId], nodes[swId]),
                isInferred: false,
              ),
            );
          }
        }
      }

      // LEVEL 3: UniFi APs (Strictly scoped by factoryId)
      for (int i = 0; i < unifiAps.length; i++) {
        final ap = unifiAps[i];
        final apId = 'ap_${ap.id}';
        final virtualId = 10000 + ap.id;
        final status = resolveInfraStatus(virtualId, ap.ip);
        final ent = getStatusEntity(virtualId);

        String parentSwId = 'sw_${verifiedSwitches.first.id}';
        final lowerName = ap.name.toLowerCase();
        if (lowerName.contains('meeting') && swWest != null) {
          parentSwId = 'sw_${swWest.id}';
        } else if (lowerName.contains('fm office') && swEast != null) {
          parentSwId = 'sw_${swEast.id}';
        } else if ((lowerName.contains('packing') || lowerName.contains('palitizer')) && swGroundCore != null) {
          parentSwId = 'sw_${swGroundCore.id}';
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
          vendor: null,
          infraRef: ap,
          isInferred: false,
          lastLatencyMs: ent?.lastLatencyMs,
          lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
          lastCheckAt: ent?.lastCheckAt,
          lastSuccessfulCheckAt: ent?.lastSeen,
          failureReason: ent?.lastFailureReason,
          consecutiveFailures: ent?.consecutiveFailures ?? 0,
          size: const Size(168, 60),
          failureThreshold: failureThreshold,
          virtualStatusId: virtualId,
        );

        final parentNode = nodes[parentSwId];
        final apLinkStatus = computeLinkStatus(parentNode, nodes[apId]);

        links.add(
          EnterpriseTopologyLink(
            id: 'link_${parentSwId}_$apId',
            fromNodeId: parentSwId,
            toNodeId: apId,
            toPort: 'PoE ETH0',
            status: apLinkStatus,
            isInferred: false,
          ),
        );
      }

      // LEVEL 4: Endpoints
      for (int i = 0; i < monitoredDevices.length; i++) {
        final md = monitoredDevices[i];
        final devId = 'dev_${md.device.id}';
        final parentSw = findMatchingSwitch(md);
        final String swId;
        if (parentSw != null) {
          swId = 'sw_${parentSw.id}';
        } else {
          final fid = md.device.factoryId.trim().isEmpty
              ? 'unassigned'
              : md.device.factoryId.trim().toLowerCase();
          swId = 'sw_unassigned_$fid';
          if (!nodes.containsKey(swId)) {
            nodes[swId] = EnterpriseTopologyNode(
              id: swId,
              title: 'Unassigned Switch (${fid.toUpperCase()})',
              subtitle: 'Unlinked Endpoints',
              category: TopologyDeviceCategory.switchDevice,
              status: DeviceStatusEnum.unknown,
              level: 2,
              location: 'Unassigned',
              isInferred: true,
              isMonitored: false,
              size: const Size(168, 60),
              failureThreshold: failureThreshold,
            );
            final upstreamGwId = gatewayIds
                    .where((id) => id.contains(fid))
                    .firstOrNull ??
                gatewayIds.firstOrNull;
            if (upstreamGwId != null) {
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
        }

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
          failureThreshold: failureThreshold,
          isMonitored: md.device.isMonitored,
          isInferred: false,
          deviceRef: md.device,
          size: const Size(168, 60),
          virtualStatusId: md.device.id,
        );

        final swNode = nodes[swId];
        final devLinkStatus = computeLinkStatus(swNode, nodes[devId]);

        links.add(
          EnterpriseTopologyLink(
            id: 'link_${swId}_$devId',
            fromNodeId: swId,
            toNodeId: devId,
            toPort: 'ETH',
            status: devLinkStatus,
            isInferred: false,
          ),
        );
      }
    } else {
      // ══════════════════════════════════════════════════════════════════════
      // PATH B: Synthetic Test Fallback Mode (Grouping by Office Location)
      // ══════════════════════════════════════════════════════════════════════
      final Map<String, List<MonitoredDevice>> locationGroups = {};
      for (final md in monitoredDevices) {
        final loc = md.device.officeLocation?.trim().isNotEmpty == true
            ? md.device.officeLocation!.trim()
            : (md.device.department.trim().isNotEmpty
                ? md.device.department.trim()
                : 'General Office');
        locationGroups.putIfAbsent(loc, () => []).add(md);
      }

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

      final Map<String, String> locationToSwitchId = {};
      for (final loc in sortedLocations) {
        final swId = 'sw_${loc.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}';
        locationToSwitchId[loc] = swId;
        switchIds.add(swId);

        final childrenCount = locationGroups[loc]?.length ?? 0;

        String? upstreamGwId = gatewayIds.firstOrNull;
        final firstDeviceIp = locationGroups[loc]?.first.device.ip;
        if (loc.toLowerCase().contains('21') ||
            (firstDeviceIp?.contains('.21.') ?? false)) {
          final bnfMatch = gatewayIds.where((id) => id.contains('bnf')).firstOrNull;
          if (bnfMatch != null) upstreamGwId = bnfMatch;
        } else if (loc.toLowerCase().contains('22') ||
            (firstDeviceIp?.contains('.22.') ?? false)) {
          final rnfMatch = gatewayIds.where((id) => id.contains('rnf')).firstOrNull;
          if (rnfMatch != null) upstreamGwId = rnfMatch;
        }

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
          failureThreshold: failureThreshold,
        );

        if (upstreamGwId != null) {
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

      // LEVEL 3: APs in Path B
      final unifiAps = infraDevices
          .where((d) => d.role == UniFiDeviceRole.accessPoint)
          .toList();
      for (int i = 0; i < unifiAps.length; i++) {
        final ap = unifiAps[i];
        final apId = 'ap_${ap.id}';
        final virtualId = 10000 + ap.id;
        final status = resolveInfraStatus(virtualId, ap.ip);
        final ent = getStatusEntity(virtualId);

        String? parentSwId = switchIds.isNotEmpty ? switchIds.first : gatewayIds.firstOrNull;
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
          vendor: null,
          infraRef: ap,
          isInferred: false,
          lastLatencyMs: ent?.lastLatencyMs,
          lastSuccessfulLatencyMs: ent?.lastSuccessfulLatencyMs,
          lastCheckAt: ent?.lastCheckAt,
          lastSuccessfulCheckAt: ent?.lastSeen,
          failureReason: ent?.lastFailureReason,
          consecutiveFailures: ent?.consecutiveFailures ?? 0,
          size: const Size(168, 60),
          failureThreshold: failureThreshold,
          virtualStatusId: virtualId,
        );

        if (parentSwId != null) {
          links.add(
            EnterpriseTopologyLink(
              id: 'link_${parentSwId}_$apId',
              fromNodeId: parentSwId,
              toNodeId: apId,
              toPort: null,
              status: DeviceStatusEnum.unknown,
              isInferred: true,
            ),
          );
        }
      }

      // LEVEL 4: Endpoints in Path B
      for (final loc in sortedLocations) {
        final swId = locationToSwitchId[loc] ?? (switchIds.isNotEmpty ? switchIds.first : gatewayIds.firstOrNull);
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
            failureThreshold: failureThreshold,
            isMonitored: md.device.isMonitored,
            isInferred: false,
            deviceRef: md.device,
            size: const Size(168, 60),
            virtualStatusId: md.device.id,
          );

          if (swId != null) {
            links.add(
              EnterpriseTopologyLink(
                id: 'link_${swId}_$devId',
                fromNodeId: swId,
                toNodeId: devId,
                toPort: null,
                status: DeviceStatusEnum.unknown,
                isInferred: true,
              ),
            );
          }
        }
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

    int compareIpStrings(String? ip1, String? ip2) {
      if (ip1 == null || ip2 == null) return (ip1 ?? '').compareTo(ip2 ?? '');
      final parts1 = ip1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final parts2 = ip2.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts1.length == 4 && parts2.length == 4) {
        for (int i = 0; i < 4; i++) {
          final diff = parts1[i].compareTo(parts2[i]);
          if (diff != 0) return diff;
        }
      }
      return ip1.compareTo(ip2);
    }

    const switchOrder = [
      'west',
      'switch 1',
      'east',
      'switch 2',
      'warehouse',
      'raw materials',
      'd-link',
      'spare',
      'security',
      'unassigned',
    ];

    level2Switches.sort((a, b) {
      if (a.subtitle != null &&
          b.subtitle != null &&
          a.subtitle!.contains('.') &&
          b.subtitle!.contains('.')) {
        final comp = compareIpStrings(a.subtitle, b.subtitle);
        if (comp != 0) return comp;
      }
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();
      int aIdx = 99;
      int bIdx = 99;
      for (int i = 0; i < switchOrder.length; i++) {
        if (aTitle.contains(switchOrder[i])) {
          aIdx = i;
          break;
        }
      }
      for (int i = 0; i < switchOrder.length; i++) {
        if (bTitle.contains(switchOrder[i])) {
          bIdx = i;
          break;
        }
      }
      if (aIdx != bIdx) return aIdx.compareTo(bIdx);
      return a.title.compareTo(b.title);
    });

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
