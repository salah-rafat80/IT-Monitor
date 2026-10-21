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
  final int? activePortCount;
  final int? totalPortCount;
  final bool isMonitored;
  final bool isUnlinked;
  final Offset position;
  final Size size;
  final DeviceEntity? deviceRef;
  final UniFiDeviceEntity? infraRef;

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
    this.activePortCount,
    this.totalPortCount,
    this.isMonitored = true,
    this.isUnlinked = false,
    this.position = Offset.zero,
    this.size = const Size(168, 60),
    this.deviceRef,
    this.infraRef,
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
    int? activePortCount,
    int? totalPortCount,
    bool? isMonitored,
    bool? isUnlinked,
    Offset? position,
    Size? size,
    DeviceEntity? deviceRef,
    UniFiDeviceEntity? infraRef,
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
      activePortCount: activePortCount ?? this.activePortCount,
      totalPortCount: totalPortCount ?? this.totalPortCount,
      isMonitored: isMonitored ?? this.isMonitored,
      isUnlinked: isUnlinked ?? this.isUnlinked,
      position: position ?? this.position,
      size: size ?? this.size,
      deviceRef: deviceRef ?? this.deviceRef,
      infraRef: infraRef ?? this.infraRef,
    );
  }

  Rect get rect =>
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  Offset get center =>
      Offset(position.dx + size.width / 2, position.dy + size.height / 2);
  Offset get leftAnchor => Offset(position.dx, position.dy + size.height / 2);
  Offset get rightAnchor =>
      Offset(position.dx + size.width, position.dy + size.height / 2);

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
    activePortCount,
    totalPortCount,
    isMonitored,
    isUnlinked,
    position,
    size,
  ];
}

class EnterpriseTopologyLink extends Equatable {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String fromPort;
  final String? toPort;
  final DeviceStatusEnum status;
  final String? speed;

  const EnterpriseTopologyLink({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.fromPort,
    this.toPort,
    this.status = DeviceStatusEnum.up,
    this.speed = '1 Gbps',
  });

  @override
  List<Object?> get props => [
    id,
    fromNodeId,
    toNodeId,
    fromPort,
    toPort,
    status,
    speed,
  ];
}

class EnterpriseTopologyGraph extends Equatable {
  final Map<String, EnterpriseTopologyNode> nodes;
  final List<EnterpriseTopologyLink> links;
  final List<EnterpriseTopologyNode> unlinkedNodes;
  final Size canvasSize;
  final Map<TopologyDeviceCategory, (int online, int total)> categoryStats;

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

  EnterpriseTopologyGraph updateStatuses(
    Map<int, DeviceStatusEntity> latestStatusMap,
  ) {
    final updatedNodes = <String, EnterpriseTopologyNode>{};
    for (final entry in nodes.entries) {
      final node = entry.value;
      if (node.deviceRef != null &&
          latestStatusMap.containsKey(node.deviceRef!.id)) {
        final statusEnt = latestStatusMap[node.deviceRef!.id]!;
        updatedNodes[entry.key] = node.copyWith(
          status: statusEnt.status,
          lastLatencyMs: statusEnt.lastLatencyMs,
        );
      } else {
        updatedNodes[entry.key] = node;
      }
    }

    // Recompute category stats
    final Map<TopologyDeviceCategory, (int online, int total)> stats = {};
    for (final n in updatedNodes.values) {
      final existing = stats[n.category] ?? (0, 0);
      final isOnline = n.status == DeviceStatusEnum.up;
      stats[n.category] = (existing.$1 + (isOnline ? 1 : 0), existing.$2 + 1);
    }

    return EnterpriseTopologyGraph(
      nodes: updatedNodes,
      links: links,
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
