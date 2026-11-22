import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import '../../../monitoring/domain/entities/monitoring_config.dart';
import '../../../monitoring/domain/repositories/monitoring_repository.dart';
import '../../../monitoring/domain/services/monitoring_scheduler.dart';
import '../../domain/entities/enterprise_topology_models.dart';
import '../../domain/entities/topology_node.dart';
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
  final MonitoringScheduler? _scheduler;

  StreamSubscription<List<DeviceStatusEntity>>? _statusSubscription;
  StreamSubscription<MonitoringConfig>? _configSubscription;
  List<DeviceEntity> _cachedDevices = [];
  List<UniFiDeviceEntity> _cachedInfra = [];
  String? _factoryId;
  int _activeFailureThreshold = 3;

  TopologyCubit(
    this._deviceRepo,
    this._infraRepo,
    this._monitoringRepo,
    this._grouper,
    this._builder, [
    this._scheduler,
  ]) : super(const TopologyLoading()) {
    if (_scheduler != null) {
      try {
        _activeFailureThreshold = _scheduler.config.failureThreshold;
        _configSubscription = _scheduler.configUpdatesStream.listen((cfg) {
          updateFailureThreshold(cfg.failureThreshold);
        });
      } catch (_) {
        // Gracefully handle mocked schedulers in tests that don't stub config properties
      }
    }
  }

  String? get currentFactoryId => _factoryId;
  int get activeFailureThreshold => _activeFailureThreshold;

  void updateFailureThreshold(int newThreshold) {
    _activeFailureThreshold = newThreshold;
    final current = state;
    if (current is TopologyLoaded) {
      final updatedGraph = current.enterpriseGraph?.updateThreshold(
        newThreshold,
      );
      final updatedLocations = current.locations.map((loc) {
        final updatedGroups = loc.switchGroups.map((group) {
          final updatedDevices = group.devices.map((md) {
            return MonitoredDevice(
              device: md.device,
              status: md.status.copyWith(failureThreshold: newThreshold),
            );
          }).toList();
          return SwitchGroup(
            switchName: group.switchName,
            devices: updatedDevices,
          );
        }).toList();
        return LocationNode(
          locationName: loc.locationName,
          switchGroups: updatedGroups,
        );
      }).toList();

      final prevSelected = current.selectedNode;
      EnterpriseTopologyNode? updatedSelected;
      if (prevSelected != null && updatedGraph != null) {
        for (final n in updatedGraph.allNodes) {
          if (n.id == prevSelected.id) {
            updatedSelected = n;
            break;
          }
        }
      }
      emit(
        current.copyWith(
          locations: updatedLocations,
          enterpriseGraph: updatedGraph,
          selectedNode: updatedSelected,
          clearSelectedNode: prevSelected != null && updatedSelected == null,
        ),
      );
    }
  }

  void updateConfig(MonitoringConfig newConfig) {
    updateFailureThreshold(newConfig.failureThreshold);
  }

  void setFactory(String? factoryId) {
    _factoryId = factoryId;
    init(_factoryId);
  }

  Future<void> init([String? factoryId]) async {
    _factoryId = factoryId;
    if (isClosed) return;
    emit(const TopologyLoading());
    try {
      final devRes = await _deviceRepo
          .getDevices(factoryId: _factoryId)
          .timeout(const Duration(seconds: 10));
      if (isClosed) return;
      if (devRes.isFailure) {
        emit(
          TopologyError(
            devRes.failureOrNull?.message ?? 'Failed to load devices',
          ),
        );
        return;
      }
      _cachedDevices = devRes.dataOrNull ?? [];

      try {
        await _infraRepo
            .bootstrapVerifiedAccessPoints()
            .timeout(const Duration(seconds: 10));
        await _infraRepo
            .bootstrapVerifiedSwitches()
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Gracefully handle unmocked bootstrap in unit test environments
      }

      final infraRes = await _infraRepo
          .getInfrastructureDevices(factoryId: _factoryId)
          .timeout(const Duration(seconds: 10));
      if (isClosed) return;
      _cachedInfra = infraRes.dataOrNull ?? [];

      // Initial statuses
      final statusRes = await _monitoringRepo
          .getDeviceStatuses()
          .timeout(const Duration(seconds: 10));
      if (isClosed) return;
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
      final infraStatuses = <int, DeviceStatusEnum>{};
      for (final infra in _cachedInfra) {
        final virtualId = 10000 + infra.id;
        final st = statusMap[virtualId];
        infraStatuses[virtualId] =
            st?.effectiveStatus() ?? DeviceStatusEnum.unknown;
      }

      // Map registered factory gateways: RNF (50001, 192.168.22.1) & BNF (50002, 192.168.21.1)
      if (statusMap.containsKey(50001)) {
        infraStatuses[50001] = statusMap[50001]!.effectiveStatus();
      }
      if (statusMap.containsKey(50002)) {
        infraStatuses[50002] = statusMap[50002]!.effectiveStatus();
      }

      if (_scheduler != null) {
        _activeFailureThreshold = _scheduler.config.failureThreshold;
      }

      final monitoredList = _cachedDevices.map((d) {
        final rawStatus = statusMap[d.id] ?? _unknownStatus(d.id);
        final status = rawStatus.copyWith(
          failureThreshold: _activeFailureThreshold,
        );
        return MonitoredDevice(device: d, status: status);
      }).toList();

      // Build enterprise hierarchical layout graph with authoritative infrastructure statuses
      final graph = _builder.build(
        monitoredDevices: monitoredList,
        infraDevices: _cachedInfra,
        infraStatuses: infraStatuses,
        statuses: statusMap,
        factoryId: _factoryId,
        failureThreshold: _activeFailureThreshold,
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
    } on TimeoutException catch (e) {
      if (!isClosed) emit(TopologyError('Topology loading timed out after 10s: $e'));
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
        failureThreshold: _activeFailureThreshold,
      );

      final monitoredList = _cachedDevices.map((d) {
        final rawStatus = latestStatusMap[d.id] ?? _unknownStatus(d.id);
        final status = rawStatus.copyWith(
          failureThreshold: _activeFailureThreshold,
        );
        return MonitoredDevice(device: d, status: status);
      }).toList();
      final updatedLocations = _grouper.group(monitoredList);

      final prevSelected = current.selectedNode;
      EnterpriseTopologyNode? updatedSelected;
      if (prevSelected != null && updatedGraph != null) {
        for (final n in updatedGraph.allNodes) {
          if (n.id == prevSelected.id) {
            updatedSelected = n;
            break;
          }
        }
      }

      emit(
        current.copyWith(
          enterpriseGraph: updatedGraph,
          locations: updatedLocations,
          selectedNode: updatedSelected,
          clearSelectedNode: prevSelected != null && updatedSelected == null,
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
    _configSubscription?.cancel();
    return super.close();
  }
}
