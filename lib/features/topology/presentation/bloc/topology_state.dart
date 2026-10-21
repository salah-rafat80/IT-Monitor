import 'package:equatable/equatable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';
import '../../domain/entities/topology_node.dart';

sealed class TopologyState extends Equatable {
  const TopologyState();
}

final class TopologyLoading extends TopologyState {
  const TopologyLoading();

  @override
  List<Object?> get props => [];
}

final class TopologyLoaded extends TopologyState {
  final List<LocationNode> locations;
  final EnterpriseTopologyGraph? enterpriseGraph;
  final EnterpriseTopologyNode? selectedNode;
  final String searchQuery;
  final String? departmentFilter;
  final String? locationFilter;
  final DeviceType? deviceTypeFilter;
  final DeviceStatusEnum? statusFilter;

  const TopologyLoaded({
    required this.locations,
    this.enterpriseGraph,
    this.selectedNode,
    this.searchQuery = '',
    this.departmentFilter,
    this.locationFilter,
    this.deviceTypeFilter,
    this.statusFilter,
  });

  /// Filtered view — applies searchQuery, department, location, device type, and status
  /// while preserving valid topology relationships.
  List<LocationNode> get filtered {
    final q = searchQuery.trim().toLowerCase();
    final hasSearch = q.isNotEmpty;

    final result = <LocationNode>[];
    for (final loc in locations) {
      if (locationFilter != null &&
          locationFilter!.isNotEmpty &&
          loc.locationName != locationFilter) {
        continue;
      }

      final locMatches =
          hasSearch && loc.locationName.toLowerCase().contains(q);

      final matchingGroups = <SwitchGroup>[];
      for (final group in loc.switchGroups) {
        final switchMatches =
            hasSearch && (group.switchName?.toLowerCase().contains(q) ?? false);

        final matchingDevices = group.devices.where((md) {
          final device = md.device;
          final status = md.status;

          if (departmentFilter != null &&
              departmentFilter!.isNotEmpty &&
              device.department != departmentFilter) {
            return false;
          }

          if (deviceTypeFilter != null && device.type != deviceTypeFilter) {
            return false;
          }

          if (statusFilter != null && status.status != statusFilter) {
            return false;
          }

          if (!hasSearch) return true;

          return device.ownerName.toLowerCase().contains(q) ||
              device.name.toLowerCase().contains(q) ||
              device.department.toLowerCase().contains(q) ||
              device.ip.contains(q);
        }).toList();

        if (locMatches || switchMatches || matchingDevices.isNotEmpty) {
          matchingGroups.add(
            SwitchGroup(
              switchName: group.switchName,
              devices: (hasSearch && (locMatches || switchMatches))
                  ? group.devices
                  : matchingDevices,
            ),
          );
        }
      }

      if (matchingGroups.isNotEmpty) {
        result.add(
          LocationNode(
            locationName: loc.locationName,
            switchGroups: matchingGroups,
          ),
        );
      }
    }
    return result;
  }

  int get totalDevices => locations.fold(0, (s, l) => s + l.totalCount);

  int get totalLocations => locations.length;

  TopologyLoaded copyWith({
    List<LocationNode>? locations,
    EnterpriseTopologyGraph? enterpriseGraph,
    EnterpriseTopologyNode? selectedNode,
    bool clearSelectedNode = false,
    String? searchQuery,
    String? departmentFilter,
    String? locationFilter,
    DeviceType? deviceTypeFilter,
    DeviceStatusEnum? statusFilter,
    bool clearDepartment = false,
    bool clearLocation = false,
    bool clearDeviceType = false,
    bool clearStatus = false,
  }) {
    return TopologyLoaded(
      locations: locations ?? this.locations,
      enterpriseGraph: enterpriseGraph ?? this.enterpriseGraph,
      selectedNode: clearSelectedNode
          ? null
          : (selectedNode ?? this.selectedNode),
      searchQuery: searchQuery ?? this.searchQuery,
      departmentFilter: clearDepartment
          ? null
          : (departmentFilter ?? this.departmentFilter),
      locationFilter: clearLocation
          ? null
          : (locationFilter ?? this.locationFilter),
      deviceTypeFilter: clearDeviceType
          ? null
          : (deviceTypeFilter ?? this.deviceTypeFilter),
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
    );
  }

  @override
  List<Object?> get props => [
    locations,
    enterpriseGraph,
    selectedNode,
    searchQuery,
    departmentFilter,
    locationFilter,
    deviceTypeFilter,
    statusFilter,
  ];
}

final class TopologyError extends TopologyState {
  final String message;

  const TopologyError(this.message);

  @override
  List<Object?> get props => [message];
}
