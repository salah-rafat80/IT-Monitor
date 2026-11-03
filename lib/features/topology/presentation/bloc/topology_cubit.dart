import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import '../../../monitoring/domain/repositories/monitoring_repository.dart';
import '../../domain/entities/enterprise_topology_models.dart';
import '../../domain/services/enterprise_topology_builder.dart';
import '../../domain/services/topology_grouper.dart';
import 'topology_state.dart';

DeviceStatusEntity _unknownStatus(int deviceId) => DeviceStatusEntity(
  deviceId: deviceId,
  status: DeviceStatusEnum.unknown,
  statusChangedAt: DateTime.now(),
);

@injectable
class TopologyCubit extends Cubit<TopologyState> {
  final DeviceRepository _deviceRepo;
  final InfrastructureRepository _infraRepo;
  final MonitoringRepository _monitoringRepo;
  final TopologyGrouper _grouper;
  final EnterpriseTopologyBuilder _builder;

  StreamSubscription<List<DeviceStatusEntity>>? _statusSubscription;
  List<DeviceEntity> _cachedDevices = [];
  List<UniFiDeviceEntity> _cachedInfra = [];
  String? _factoryId;

  TopologyCubit(
    this._deviceRepo,
    this._infraRepo,
    this._monitoringRepo,
    this._grouper,
    this._builder,
  ) : super(const TopologyLoading());

  String? get currentFactoryId => _factoryId;

  void setFactory(String? factoryId) {
    if (_factoryId != factoryId) {
      _factoryId = factoryId;
      init(_factoryId);
    }
  }

  Future<void> init([String? factoryId]) async {
    if (factoryId != null || (factoryId == null && _factoryId != null)) {
      _factoryId = factoryId;
    }
    emit(const TopologyLoading());
    try {
      final devRes = await _deviceRepo.getDevices(factoryId: _factoryId);
      if (devRes.isFailure) {
        emit(
          TopologyError(
            devRes.failureOrNull?.message ?? 'Failed to load devices',
          ),
        );
        return;
      }
      _cachedDevices = devRes.dataOrNull!;

      final infraRes = await _infraRepo.getInfrastructureDevices(
        factoryId: _factoryId,
      );
      _cachedInfra = infraRes.dataOrNull ?? [];

      // Initial statuses
      final statusRes = await _monitoringRepo.getDeviceStatuses();
      if (statusRes.isFailure) {
        final reason = statusRes.failureOrNull?.message;
        emit(
          TopologyError(
            'Failed to load device statuses from authoritative monitoring service${reason != null ? ": $reason" : "."}',
          ),
        );
        return;
      }
      final statusMap = <int, DeviceStatusEntity>{};
      for (final s in statusRes.dataOrNull!) {
        statusMap[s.deviceId] = s;
      }

      // Map infrastructure statuses using stable virtual ID (10000 + infra.id)
      final infraStatuses = <String, DeviceStatusEnum>{};
      for (final infra in _cachedInfra) {
        final virtualId = 10000 + infra.id;
        final st = statusMap[virtualId];
        infraStatuses[infra.ip] =
            st?.effectiveStatus() ?? DeviceStatusEnum.unknown;
      }

      // Map registered factory gateways: RNF (50001, 192.168.22.1) & BNF (50002, 192.168.21.1)
      if (statusMap.containsKey(50001)) {
        infraStatuses['192.168.22.1'] = statusMap[50001]!.effectiveStatus();
      }
      if (statusMap.containsKey(50002)) {
        infraStatuses['192.168.21.1'] = statusMap[50002]!.effectiveStatus();
      }

      final monitoredList = _cachedDevices.map((d) {
        final status = statusMap[d.id] ?? _unknownStatus(d.id);
        return MonitoredDevice(device: d, status: status);
      }).toList();

      // Build enterprise hierarchical layout graph with authoritative infrastructure statuses
      final graph = _builder.build(
        monitoredDevices: monitoredList,
        infraDevices: _cachedInfra,
        infraStatuses: infraStatuses,
        factoryId: _factoryId,
      );

      final locationNodes = _grouper.group(monitoredList);

      emit(TopologyLoaded(locations: locationNodes, enterpriseGraph: graph));

      // Watch live status updates
      _statusSubscription?.cancel();
      _statusSubscription = _monitoringRepo.watchAllDeviceStatuses().listen((
        statuses,
      ) {
        final latestStatusMap = {for (final s in statuses) s.deviceId: s};
        _updateLiveStatuses(latestStatusMap);
      });
    } catch (e) {
      if (!isClosed) emit(TopologyError(e.toString()));
    }
  }

  void _updateLiveStatuses(Map<int, DeviceStatusEntity> latestStatusMap) {
    if (isClosed) return;
    final current = state;
    if (current is TopologyLoaded) {
      // Update enterprise graph in-place without moving positions
      final updatedGraph = current.enterpriseGraph?.updateStatuses(
        latestStatusMap,
      );

      final monitoredList = _cachedDevices.map((d) {
        final status = latestStatusMap[d.id] ?? _unknownStatus(d.id);
        return MonitoredDevice(device: d, status: status);
      }).toList();
      final updatedLocations = _grouper.group(monitoredList);

      emit(
        current.copyWith(
          enterpriseGraph: updatedGraph,
          locations: updatedLocations,
        ),
      );
    }
  }

  void selectNode(EnterpriseTopologyNode? node) {
    final current = state;
    if (current is TopologyLoaded) {
      emit(
        current.copyWith(selectedNode: node, clearSelectedNode: node == null),
      );
    }
  }

  void clearSelectedNode() {
    selectNode(null);
  }

  void search(String query) {
    final current = state;
    if (current is TopologyLoaded) {
      emit(current.copyWith(searchQuery: query));
    }
  }

  void clearSearch() {
    final current = state;
    if (current is TopologyLoaded) {
      emit(current.copyWith(searchQuery: ''));
    }
  }

  void setDepartmentFilter(String? dept) {
    final current = state;
    if (current is TopologyLoaded) {
      emit(
        dept == null || dept.isEmpty
            ? current.copyWith(clearDepartment: true)
            : current.copyWith(departmentFilter: dept),
      );
    }
  }

  void setLocationFilter(String? loc) {
    final current = state;
    if (current is TopologyLoaded) {
      emit(
        loc == null || loc.isEmpty
            ? current.copyWith(clearLocation: true)
            : current.copyWith(locationFilter: loc),
      );
    }
  }

  void setDeviceTypeFilter(DeviceType? type) {
    final current = state;
    if (current is TopologyLoaded) {
      emit(
        type == null
            ? current.copyWith(clearDeviceType: true)
            : current.copyWith(deviceTypeFilter: type),
      );
    }
  }

  void setStatusFilter(DeviceStatusEnum? status) {
    final current = state;
    if (current is TopologyLoaded) {
      emit(
        status == null
            ? current.copyWith(clearStatus: true)
            : current.copyWith(statusFilter: status),
      );
    }
  }

  void resetFilters() {
    final current = state;
    if (current is TopologyLoaded) {
      emit(
        TopologyLoaded(
          locations: current.locations,
          enterpriseGraph: current.enterpriseGraph,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }
}
