import 'package:equatable/equatable.dart';

import '../../../incidents/domain/entities/incident_entity.dart';
import '../../domain/entities/monitoring_config.dart';
import '../../domain/entities/monitored_device.dart';

sealed class MonitoringDashboardState extends Equatable {
  const MonitoringDashboardState();

  @override
  List<Object?> get props => [];
}

final class MonitoringDashboardLoading extends MonitoringDashboardState {
  const MonitoringDashboardLoading();
}

final class MonitoringDashboardError extends MonitoringDashboardState {
  final String message;

  const MonitoringDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

final class MonitoringDashboardLoaded extends MonitoringDashboardState {
  final List<MonitoredDevice> allDevices;
  final List<MonitoredDevice> filteredDevices;

  // Filter parameters
  final String searchQuery;
  final String? statusFilter;
  final String? departmentFilter;
  final String? locationFilter;
  final String? typeFilter;
  final bool? enabledFilter;

  // Sort parameters
  final String sortBy;
  final bool sortAscending;

  // Engine Status
  final bool isEngineRunning;
  final bool isEnginePaused;
  final MonitoringConfig config;

  // Summary Metrics
  final int totalCount;
  final int upCount;
  final int degradedCount;
  final int downCount;
  final int unknownCount;
  final int maintenanceCount;
  final List<MonitoredDevice> activeIncidents;
  final List<IncidentEntity> realActiveIncidents;

  const MonitoringDashboardLoaded({
    required this.allDevices,
    required this.filteredDevices,
    this.searchQuery = '',
    this.statusFilter,
    this.departmentFilter,
    this.locationFilter,
    this.typeFilter,
    this.enabledFilter,
    this.sortBy = 'owner',
    this.sortAscending = true,
    required this.isEngineRunning,
    required this.isEnginePaused,
    required this.config,
    required this.totalCount,
    required this.upCount,
    required this.degradedCount,
    required this.downCount,
    required this.unknownCount,
    required this.maintenanceCount,
    required this.activeIncidents,
    this.realActiveIncidents = const [],
  });

  MonitoringDashboardLoaded copyWith({
    List<MonitoredDevice>? allDevices,
    List<MonitoredDevice>? filteredDevices,
    String? searchQuery,
    String? statusFilter,
    String? departmentFilter,
    String? locationFilter,
    String? typeFilter,
    bool? enabledFilter,
    bool clearStatusFilter = false,
    bool clearDepartmentFilter = false,
    bool clearLocationFilter = false,
    bool clearTypeFilter = false,
    bool clearEnabledFilter = false,
    String? sortBy,
    bool? sortAscending,
    bool? isEngineRunning,
    bool? isEnginePaused,
    MonitoringConfig? config,
    int? totalCount,
    int? upCount,
    int? degradedCount,
    int? downCount,
    int? unknownCount,
    int? maintenanceCount,
    List<MonitoredDevice>? activeIncidents,
    List<IncidentEntity>? realActiveIncidents,
  }) {
    return MonitoringDashboardLoaded(
      allDevices: allDevices ?? this.allDevices,
      filteredDevices: filteredDevices ?? this.filteredDevices,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      departmentFilter: clearDepartmentFilter
          ? null
          : (departmentFilter ?? this.departmentFilter),
      locationFilter: clearLocationFilter
          ? null
          : (locationFilter ?? this.locationFilter),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      enabledFilter: clearEnabledFilter
          ? null
          : (enabledFilter ?? this.enabledFilter),
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      isEngineRunning: isEngineRunning ?? this.isEngineRunning,
      isEnginePaused: isEnginePaused ?? this.isEnginePaused,
      config: config ?? this.config,
      totalCount: totalCount ?? this.totalCount,
      upCount: upCount ?? this.upCount,
      degradedCount: degradedCount ?? this.degradedCount,
      downCount: downCount ?? this.downCount,
      unknownCount: unknownCount ?? this.unknownCount,
      maintenanceCount: maintenanceCount ?? this.maintenanceCount,
      activeIncidents: activeIncidents ?? this.activeIncidents,
      realActiveIncidents: realActiveIncidents ?? this.realActiveIncidents,
    );
  }

  @override
  List<Object?> get props => [
    allDevices,
    filteredDevices,
    searchQuery,
    statusFilter,
    departmentFilter,
    locationFilter,
    typeFilter,
    enabledFilter,
    sortBy,
    sortAscending,
    isEngineRunning,
    isEnginePaused,
    config,
    totalCount,
    upCount,
    degradedCount,
    downCount,
    unknownCount,
    maintenanceCount,
    activeIncidents,
    realActiveIncidents,
  ];
}
