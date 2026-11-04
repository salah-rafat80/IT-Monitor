import 'dart:ui';
import 'package:equatable/equatable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';

enum TopologyDeviceCategory {
  wan,
  gateway,
  switchDevice,
  accessPoint,
  controller,
  server,
  pc,
  laptop,
  printer,
  camera,
  other;

  String get displayName {
    switch (this) {
      case TopologyDeviceCategory.wan:
        return 'WAN / Internet';
      case TopologyDeviceCategory.gateway:
        return 'Gateway / Router';
      case TopologyDeviceCategory.switchDevice:
        return 'Switch';
      case TopologyDeviceCategory.accessPoint:
        return 'Access Point';
      case TopologyDeviceCategory.controller:
        return 'Controller';
      case TopologyDeviceCategory.server:
        return 'Server';
      case TopologyDeviceCategory.pc:
        return 'PC / Workstation';
      case TopologyDeviceCategory.laptop:
        return 'Laptop';
      case TopologyDeviceCategory.printer:
        return 'Printer';
      case TopologyDeviceCategory.camera:
        return 'IP Camera';
      case TopologyDeviceCategory.other:
        return 'Network Device';
    }
  }

  String get shortName {
    switch (this) {
      case TopologyDeviceCategory.wan:
        return 'WAN';
      case TopologyDeviceCategory.gateway:
        return 'Gateway';
      case TopologyDeviceCategory.switchDevice:
        return 'Switch';
      case TopologyDeviceCategory.accessPoint:
        return 'AP';
      case TopologyDeviceCategory.controller:
        return 'AC / Controller';
      case TopologyDeviceCategory.server:
        return 'Server';
      case TopologyDeviceCategory.pc:
        return 'PC';
      case TopologyDeviceCategory.laptop:
        return 'Laptop';
      case TopologyDeviceCategory.printer:
        return 'Printer';
      case TopologyDeviceCategory.camera:
        return 'Camera';
      case TopologyDeviceCategory.other:
        return 'Other';
    }
  }
}

class EnterpriseTopologyNode extends Equatable {
  final String id;
  final String title;
  final String? subtitle;
  final TopologyDeviceCategory category;
  final DeviceStatusEnum status;
  final int level; // 0=WAN, 1=Gateway, 2=Switch, 3=Access/AP, 4=Clients
  final String? location;
  final String? department;
  final String? mac;
  final String? vendor;
  final String? model;
  final String? hostname;
  final int? lastLatencyMs;
  final int? lastSuccessfulLatencyMs;
  final int? activePortCount;
  final int? totalPortCount;
  final bool isMonitored;
  final bool isUnlinked;
  final bool isInferred;
  final DateTime? lastCheckAt;
  final DateTime? lastSuccessfulCheckAt;
  final String? failureReason;
  final int consecutiveFailures;
  final Offset position;
  final Size size;
  final DeviceEntity? deviceRef;
  final UniFiDeviceEntity? infraRef;
  final int failureThreshold;

  const EnterpriseTopologyNode({
    required this.id,
    required this.title,
    this.subtitle,
    required this.category,
    required this.status,
    required this.level,
    this.location,
    this.department,
    this.mac,
    this.vendor,
    this.model,
    this.hostname,
    this.lastLatencyMs,
    this.lastSuccessfulLatencyMs,
    this.activePortCount,
    this.totalPortCount,
    this.isMonitored = true,
    this.isUnlinked = false,
    this.isInferred = false,
    this.lastCheckAt,
    this.lastSuccessfulCheckAt,
    this.failureReason,
    this.consecutiveFailures = 0,
    this.position = Offset.zero,
    this.size = const Size(168, 60),
    this.deviceRef,
    this.infraRef,
    this.failureThreshold = 3,
  });

  EnterpriseTopologyNode copyWith({
    String? id,
    String? title,
    String? subtitle,
    TopologyDeviceCategory? category,
    DeviceStatusEnum? status,
    int? level,
    String? location,
    String? department,
    String? mac,
    String? vendor,
    String? model,
    String? hostname,
    int? lastLatencyMs,
    int? lastSuccessfulLatencyMs,
    int? activePortCount,
    int? totalPortCount,
    bool? isMonitored,
    bool? isUnlinked,
    bool? isInferred,
    DateTime? lastCheckAt,
    DateTime? lastSuccessfulCheckAt,
    String? failureReason,
    int? consecutiveFailures,
    Offset? position,
    Size? size,
    DeviceEntity? deviceRef,
    UniFiDeviceEntity? infraRef,
    int? failureThreshold,
  }) {
    return EnterpriseTopologyNode(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      status: status ?? this.status,
      level: level ?? this.level,
      location: location ?? this.location,
      department: department ?? this.department,
      mac: mac ?? this.mac,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      hostname: hostname ?? this.hostname,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      lastSuccessfulLatencyMs:
          lastSuccessfulLatencyMs ?? this.lastSuccessfulLatencyMs,
      activePortCount: activePortCount ?? this.activePortCount,
      totalPortCount: totalPortCount ?? this.totalPortCount,
      isMonitored: isMonitored ?? this.isMonitored,
      isUnlinked: isUnlinked ?? this.isUnlinked,
      isInferred: isInferred ?? this.isInferred,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      lastSuccessfulCheckAt:
          lastSuccessfulCheckAt ?? this.lastSuccessfulCheckAt,
      failureReason: failureReason ?? this.failureReason,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      position: position ?? this.position,
      size: size ?? this.size,
      deviceRef: deviceRef ?? this.deviceRef,
      infraRef: infraRef ?? this.infraRef,
      failureThreshold: failureThreshold ?? this.failureThreshold,
    );
  }

  Rect get rect =>
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  Offset get center =>
      Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  Offset get leftAnchor => Offset(position.dx, position.dy + size.height / 2);
  Offset get rightAnchor =>
      Offset(position.dx + size.width, position.dy + size.height / 2);

  /// True when the node is retained as UP by threshold policy,
  /// but has recent probe failures (1 or 2 failures below failureThreshold).
  bool get isTransitionalFailing =>
      status == DeviceStatusEnum.up && consecutiveFailures > 0;

  /// Clear transitional human-readable label when failing below threshold.
  String get transitionalLabel {
    if (isTransitionalFailing) {
      return 'Previously Online · $consecutiveFailures/$failureThreshold Failed Checks';
    }
    return status.displayName;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subtitle,
    category,
    status,
    level,
    location,
    department,
    mac,
    vendor,
    model,
    hostname,
    lastLatencyMs,
    lastSuccessfulLatencyMs,
    activePortCount,
    totalPortCount,
    isMonitored,
    isUnlinked,
    isInferred,
    lastCheckAt,
    lastSuccessfulCheckAt,
    failureReason,
    consecutiveFailures,
    position,
    size,
    failureThreshold,
  ];
}

class CategoryStatusCount extends Equatable {
  final int online;
  final int offline;
  final int degraded;
  final int unknown;
  final int stale;
  final int total;

  const CategoryStatusCount({
    this.online = 0,
    this.offline = 0,
    this.degraded = 0,
    this.unknown = 0,
    this.stale = 0,
    this.total = 0,
  });

  factory CategoryStatusCount.fromStatuses(
    Iterable<DeviceStatusEntity?> statuses, {
    DateTime? now,
    int freshnessWindowSeconds =
        DeviceStatusEntity.defaultFreshnessWindowSeconds,
  }) {
    int on = 0;
    int off = 0;
    int deg = 0;
    int unk = 0;
    int st = 0;
    int tot = 0;

    for (final s in statuses) {
      tot++;
      final eff =
          s?.effectiveStatus(
            now: now,
            freshnessWindowSeconds: freshnessWindowSeconds,
          ) ??
          DeviceStatusEnum.unknown;
      switch (eff) {
        case DeviceStatusEnum.up:
          on++;
          break;
        case DeviceStatusEnum.down:
        case DeviceStatusEnum.unreachable:
          off++;
          break;
        case DeviceStatusEnum.degraded:
          deg++;
          break;
        case DeviceStatusEnum.stale:
          st++;
          break;
        case DeviceStatusEnum.unknown:
        case DeviceStatusEnum.maintenance:
          unk++;
          break;
      }
    }

    return CategoryStatusCount(
      online: on,
      offline: off,
      degraded: deg,
      unknown: unk,
      stale: st,
      total: tot,
    );
  }

  (int online, int total) toRatio() => (online, total);

  @override
  List<Object?> get props => [online, offline, degraded, unknown, stale, total];
}

class EnterpriseTopologyLink extends Equatable {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String? fromPort;
  final String? toPort;
  final DeviceStatusEnum status;
  final String? speed;
  final bool isInferred;

  const EnterpriseTopologyLink({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    this.fromPort,
    this.toPort,
    this.status = DeviceStatusEnum.unknown,
    this.speed,
    this.isInferred = false,
  });

  EnterpriseTopologyLink copyWith({
    String? id,
    String? fromNodeId,
    String? toNodeId,
    String? fromPort,
    String? toPort,
    DeviceStatusEnum? status,
    String? speed,
    bool? isInferred,
  }) {
    return EnterpriseTopologyLink(
      id: id ?? this.id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      fromPort: fromPort ?? this.fromPort,
      toPort: toPort ?? this.toPort,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      isInferred: isInferred ?? this.isInferred,
    );
  }

  @override
  List<Object?> get props => [
    id,
    fromNodeId,
    toNodeId,
    fromPort,
    toPort,
    status,
    speed,
    isInferred,
  ];
}

class EnterpriseTopologyGraph extends Equatable {
  final Map<String, EnterpriseTopologyNode> nodes;
  final List<EnterpriseTopologyLink> links;
  final List<EnterpriseTopologyNode> unlinkedNodes;
  final Size canvasSize;
  final Map<TopologyDeviceCategory, CategoryStatusCount> categoryStats;

  const EnterpriseTopologyGraph({
    required this.nodes,
    required this.links,
    required this.unlinkedNodes,
    required this.canvasSize,
    required this.categoryStats,
  });

  List<EnterpriseTopologyNode> get allNodes => [
    ...nodes.values,
    ...unlinkedNodes,
  ];

  Map<TopologyDeviceCategory, (int online, int total)> get ratioStats =>
      categoryStats.map((k, v) => MapEntry(k, v.toRatio()));

  EnterpriseTopologyGraph copyWith({
    Map<String, EnterpriseTopologyNode>? nodes,
    List<EnterpriseTopologyLink>? links,
    List<EnterpriseTopologyNode>? unlinkedNodes,
    Size? canvasSize,
    Map<TopologyDeviceCategory, CategoryStatusCount>? categoryStats,
  }) {
    return EnterpriseTopologyGraph(
      nodes: nodes ?? this.nodes,
      links: links ?? this.links,
      unlinkedNodes: unlinkedNodes ?? this.unlinkedNodes,
      canvasSize: canvasSize ?? this.canvasSize,
      categoryStats: categoryStats ?? this.categoryStats,
    );
  }

  EnterpriseTopologyGraph updateThreshold(int newThreshold) {
    final updatedNodes = <String, EnterpriseTopologyNode>{
      for (final entry in nodes.entries)
        entry.key: entry.value.copyWith(failureThreshold: newThreshold),
    };
    return copyWith(nodes: updatedNodes);
  }

  EnterpriseTopologyGraph updateStatuses(
    Map<int, DeviceStatusEntity> latestStatusMap, {
    DateTime? now,
    int? freshnessWindowSeconds,
    int? failureThreshold,
  }) {
    final updatedNodes = <String, EnterpriseTopologyNode>{};
    for (final entry in nodes.entries) {
      final node = entry.value;
      DeviceStatusEntity? statusEnt;
      if (node.deviceRef != null &&
          latestStatusMap.containsKey(node.deviceRef!.id)) {
        statusEnt = latestStatusMap[node.deviceRef!.id];
      } else if (node.infraRef != null) {
        final virtualId = 10000 + node.infraRef!.id;
        statusEnt = latestStatusMap[virtualId];
      } else if (node.category == TopologyDeviceCategory.gateway) {
        if (node.id.contains('rnf') ||
            (node.subtitle?.contains('22.1') ?? false)) {
          statusEnt = latestStatusMap[50001];
        } else if (node.id.contains('bnf') ||
            (node.subtitle?.contains('21.1') ?? false)) {
          statusEnt = latestStatusMap[50002];
        }
      }

      if (statusEnt != null) {
        final effStatus = statusEnt.effectiveStatus(
          now: now,
          freshnessWindowSeconds: freshnessWindowSeconds,
        );
        updatedNodes[entry.key] = node.copyWith(
          status: effStatus,
          lastLatencyMs: statusEnt.lastLatencyMs,
          lastSuccessfulLatencyMs: statusEnt.lastSuccessfulLatencyMs,
          failureReason: statusEnt.lastFailureReason,
          consecutiveFailures: statusEnt.consecutiveFailures,
          failureThreshold: failureThreshold ?? node.failureThreshold,
          lastCheckAt: statusEnt.lastCheckAt,
          lastSuccessfulCheckAt: statusEnt.lastSeen,
        );
      } else {
        updatedNodes[entry.key] = failureThreshold != null
            ? node.copyWith(failureThreshold: failureThreshold)
            : node;
      }
    }

    // Actual WAN / Internet status remains strictly Unknown until externally verified.
    // LAN gateway reachability must NEVER be inferred as Internet connectivity!
    final wanNode = updatedNodes['wan_internet'];
    if (wanNode != null) {
      updatedNodes['wan_internet'] = wanNode.copyWith(
        status: DeviceStatusEnum.unknown,
      );
    }

    // Recalculate verified link statuses based on authoritative endpoint states.
    final updatedLinks = <EnterpriseTopologyLink>[];
    for (final link in links) {
      if (link.isInferred) {
        // Inferred links MUST strictly remain Unknown and never turn green (UP).
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.unknown));
        continue;
      }

      final fromNode = updatedNodes[link.fromNodeId];
      final toNode = updatedNodes[link.toNodeId];

      if (fromNode == null || toNode == null) {
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.unknown));
        continue;
      }

      // If either end of a link connects to an inferred location group, the link is unverified.
      if (fromNode.isInferred || toNode.isInferred) {
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.unknown));
        continue;
      }

      // If either end is WAN (Internet), external reachability is unverified -> remain Unknown.
      if (fromNode.category == TopologyDeviceCategory.wan ||
          toNode.category == TopologyDeviceCategory.wan) {
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.unknown));
        continue;
      }

      // Authoritative status resolution between two verified physical endpoints:
      // 1. If either endpoint is Down or Unreachable -> link is Down.
      if (fromNode.status == DeviceStatusEnum.down ||
          fromNode.status == DeviceStatusEnum.unreachable ||
          toNode.status == DeviceStatusEnum.down ||
          toNode.status == DeviceStatusEnum.unreachable) {
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.down));
      } else if (fromNode.status == DeviceStatusEnum.stale ||
          toNode.status == DeviceStatusEnum.stale ||
          link.status == DeviceStatusEnum.stale) {
        // 2. Stale verified link remains Stale!
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.stale));
      } else if (fromNode.consecutiveFailures > 0 ||
          toNode.consecutiveFailures > 0 ||
          fromNode.status == DeviceStatusEnum.degraded ||
          toNode.status == DeviceStatusEnum.degraded) {
        // 3. Only verified physical links may become Amber because an endpoint has consecutive probe failures.
        // Never show a green link after the latest failed probe!
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.degraded));
      } else if (fromNode.status == DeviceStatusEnum.up &&
          toNode.status == DeviceStatusEnum.up &&
          fromNode.consecutiveFailures == 0 &&
          toNode.consecutiveFailures == 0) {
        // 4. Both endpoints verified fresh Online with zero consecutive failures!
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.up));
      } else {
        updatedLinks.add(link.copyWith(status: DeviceStatusEnum.unknown));
      }
    }

    // Recompute category stats strictly from registered assets (exclude inferred & WAN)
    final Map<TopologyDeviceCategory, CategoryStatusCount> stats = {};
    for (final n in updatedNodes.values) {
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
      nodes: updatedNodes,
      links: updatedLinks,
      unlinkedNodes: unlinkedNodes,
      canvasSize: canvasSize,
      categoryStats: stats,
    );
  }

  @override
  List<Object?> get props => [
    nodes,
    links,
    unlinkedNodes,
    canvasSize,
    categoryStats,
  ];
}
