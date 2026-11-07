import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../domain/entities/device_status_entity.dart';
import '../../domain/entities/monitoring_config.dart';
import '../../domain/entities/monitored_device.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../../domain/services/monitoring_scheduler.dart';
import 'monitoring_dashboard_state.dart';

@injectable
class MonitoringDashboardCubit extends Cubit<MonitoringDashboardState> {
  final DeviceRepository _deviceRepo;
  final MonitoringRepository _monitoringRepo;
  final MonitoringScheduler _scheduler;

  StreamSubscription<List<DeviceStatusEntity>>? _statusSubscription;
  StreamSubscription<MonitoringConfig>? _configSubscription;
  MonitoringConfig? _pendingConfig;
  List<DeviceEntity> _cachedDevices = [];
  Map<int, DeviceStatusEntity> _cachedStatusMap = {};
  String? _activeFactoryId;
  String? get activeFactoryId => _activeFactoryId;

  MonitoringDashboardCubit(
    this._deviceRepo,
    this._monitoringRepo,
    this._scheduler,
  ) : super(const MonitoringDashboardLoading()) {
    try {
      _configSubscription = _scheduler.configUpdatesStream.listen((cfg) {
        _pendingConfig = cfg;
        // Configuration stream updates must not emit an empty Loaded state while
        // dashboard initialization is still running.
        if (state is MonitoringDashboardLoaded) {
          _rebuildAndEmitLoaded();
        }
      });
    } catch (_) {
      // Gracefully handle mocked schedulers in tests that don't stub configUpdatesStream
    }
  }

  Future<void> setFactoryFilter(String? factoryId) async {
    _activeFactoryId = factoryId;
    await initDashboard(factoryId: factoryId);
  }

  Future<void> initDashboard({
    bool startScheduler = false,
    String? factoryId,
  }) async {
    if (factoryId != null || _activeFactoryId != null) {
      _activeFactoryId = factoryId ?? _activeFactoryId;
    }
    emit(const MonitoringDashboardLoading());

    try {
      await _deviceRepo.bootstrapApprovedInventory();

      final devicesRes = await _deviceRepo.getDevices(
        factoryId: _activeFactoryId,
      );
      final statusesRes = await _monitoringRepo.getDeviceStatuses();

      if (devicesRes.isFailure) {
        emit(
          MonitoringDashboardError(
            devicesRes.failureOrNull?.message ?? 'Failed to load devices',
          ),
        );
        return;
      }

      if (statusesRes.isFailure) {
        final reason = statusesRes.failureOrNull?.message;
        emit(
          MonitoringDashboardError(
            'Failed to load device statuses from authoritative monitoring service${reason != null ? ": $reason" : "."}',
          ),
        );
        return;
      }

      _cachedDevices = devicesRes.dataOrNull ?? [];
      final statusList = statusesRes.dataOrNull ?? [];
      _cachedStatusMap = {for (final s in statusList) s.deviceId: s};

      _statusSubscription?.cancel();
      _statusSubscription = _monitoringRepo.watchAllDeviceStatuses().listen(
        _handleStatusUpdate,
        onError: (e) {
          if (!isClosed) {
            emit(
              MonitoringDashboardError(
                'Monitoring status stream interrupted: $e',
              ),
            );
          }
        },
      );

      // Dedicated Windows monitoring service owns the authoritative background scheduler.
      // Do not duplicate scheduler in desktop client unless explicitly requested (e.g. standalone test mode).
      if (startScheduler && !_scheduler.isRunning) {
        _scheduler.startMonitoring();
      }

      _rebuildAndEmitLoaded();
    } catch (e) {
      emit(MonitoringDashboardError('Dashboard initialization failed: $e'));
    }
  }

  Future<void> refreshDevices() async {
    try {
      await _scheduler.triggerAllChecks(force: true);
      final devicesRes = await _deviceRepo.getDevices(
        factoryId: _activeFactoryId,
      );
      final statusesRes = await _monitoringRepo.getDeviceStatuses();
      if (devicesRes.isFailure) {
        if (!isClosed) {
          emit(
            MonitoringDashboardError(
              devicesRes.failureOrNull?.message ?? 'Failed to refresh devices',
            ),
          );
        }
        return;
      }
      if (statusesRes.isFailure) {
        if (!isClosed) {
          emit(
            MonitoringDashboardError(
              statusesRes.failureOrNull?.message ??
                  'Failed to refresh device statuses from authoritative monitoring service.',
            ),
          );
        }
        return;
      }
      _cachedDevices = devicesRes.dataOrNull ?? [];
      final statusList = statusesRes.dataOrNull ?? [];
      _cachedStatusMap = {for (final s in statusList) s.deviceId: s};
      _rebuildAndEmitLoaded();
    } catch (e) {
      if (!isClosed) {
        emit(MonitoringDashboardError('Failed to refresh devices: $e'));
      }
    }
  }

  void setSearchQuery(String query) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final updated = current.copyWith(searchQuery: query);
      emit(_applyFilterAndSort(updated));
    }
  }

  void setStatusFilter(String? status) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final updated = current.copyWith(
        statusFilter: status,
        clearStatusFilter: status == null,
      );
      emit(_applyFilterAndSort(updated));
    }
  }

  void setDepartmentFilter(String? dept) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final updated = current.copyWith(
        departmentFilter: dept,
        clearDepartmentFilter: dept == null,
      );
      emit(_applyFilterAndSort(updated));
    }
  }

  void setLocationFilter(String? location) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final updated = current.copyWith(
        locationFilter: location,
        clearLocationFilter: location == null,
      );
      emit(_applyFilterAndSort(updated));
    }
  }

  void setTypeFilter(String? type) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final updated = current.copyWith(
        typeFilter: type,
        clearTypeFilter: type == null,
      );
      emit(_applyFilterAndSort(updated));
    }
  }

  void setEnabledFilter(bool? enabled) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final updated = current.copyWith(
        enabledFilter: enabled,
        clearEnabledFilter: enabled == null,
      );
      emit(_applyFilterAndSort(updated));
    }
  }

  void setSorting(String sortBy) {
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      final isSameSort = current.sortBy == sortBy;
      final sortAscending = isSameSort ? !current.sortAscending : true;
      final updated = current.copyWith(
        sortBy: sortBy,
        sortAscending: sortAscending,
      );
      emit(_applyFilterAndSort(updated));
    }
  }

  Future<void> triggerManualCheck(int deviceId) async {
    await _scheduler.triggerSingleCheck(deviceId);
  }

  Future<void> toggleMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async {
    await _monitoringRepo.setMaintenanceMode(
      deviceId: deviceId,
      isMaintenance: isMaintenance,
    );
  }

  void updateConfig(MonitoringConfig newConfig) {
    _pendingConfig = newConfig;
    _scheduler.updateConfig(newConfig);
    if (state is MonitoringDashboardLoaded) {
      _rebuildAndEmitLoaded();
    }
  }

  void toggleEngine() {
    if (_scheduler.isRunning) {
      _scheduler.stopMonitoring();
    } else {
      _scheduler.startMonitoring();
    }
    final current = state;
    if (current is MonitoringDashboardLoaded) {
      emit(
        current.copyWith(
          isEngineRunning: _scheduler.isRunning,
          isEnginePaused: _scheduler.isPaused,
        ),
      );
    }
  }

  void _handleStatusUpdate(List<DeviceStatusEntity> statuses) {
    for (final s in statuses) {
      _cachedStatusMap[s.deviceId] = s;
    }
    _rebuildAndEmitLoaded();
  }

  void _rebuildAndEmitLoaded() {
    if (isClosed) return;
    if (state is! MonitoringDashboardLoaded && _cachedDevices.isEmpty) {
      // Configuration stream updates must not emit an empty Loaded state while
      // dashboard initialization is still running.
      return;
    }
    final activeConfig = _pendingConfig ?? _scheduler.config;
    final allMonitoredDevices = _cachedDevices.map((d) {
      final status = _cachedStatusMap[d.id] ?? DeviceStatusEntity.initial(d.id);
      final syncedStatus = status.copyWith(
        failureThreshold: activeConfig.failureThreshold,
      );
      return MonitoredDevice(device: d, status: syncedStatus);
    }).toList();

    int up = 0;
    int degraded = 0;
    int down = 0;
    int unknown = 0;
    int stale = 0;
    int maintenance = 0;
    for (final md in allMonitoredDevices) {
      switch (md.status.effectiveStatus()) {
        case DeviceStatusEnum.up:
          up++;
          break;
        case DeviceStatusEnum.degraded:
          degraded++;
          break;
        case DeviceStatusEnum.down:
          down++;
          break;
        case DeviceStatusEnum.stale:
          stale++;
          break;
        case DeviceStatusEnum.unknown:
          unknown++;
          break;
        case DeviceStatusEnum.maintenance:
          maintenance++;
          break;
        case DeviceStatusEnum.unreachable:
          down++;
          break;
      }
    }

    final currentState = state;
    final baseLoaded = (currentState is MonitoringDashboardLoaded)
        ? currentState.copyWith(
            allDevices: allMonitoredDevices,
            totalCount: allMonitoredDevices.length,
            upCount: up,
            degradedCount: degraded,
            downCount: down,
            unknownCount: unknown,
            staleCount: stale,
            maintenanceCount: maintenance,
            isEngineRunning: _scheduler.isRunning,
            isEnginePaused: _scheduler.isPaused,
            config: activeConfig,
          )
        : MonitoringDashboardLoaded(
            allDevices: allMonitoredDevices,
            filteredDevices: allMonitoredDevices,
            isEngineRunning: _scheduler.isRunning,
            isEnginePaused: _scheduler.isPaused,
            config: activeConfig,
            totalCount: allMonitoredDevices.length,
            upCount: up,
            degradedCount: degraded,
            downCount: down,
            unknownCount: unknown,
            staleCount: stale,
            maintenanceCount: maintenance,
          );

    if (isClosed) return;
    emit(_applyFilterAndSort(baseLoaded));
  }

  MonitoringDashboardLoaded _applyFilterAndSort(
    MonitoringDashboardLoaded loaded,
  ) {
    List<MonitoredDevice> list = List.from(loaded.allDevices);

    // Search query filter
    final query = loaded.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((item) {
        final d = item.device;
        return d.ownerName.toLowerCase().contains(query) ||
            d.department.toLowerCase().contains(query) ||
            d.name.toLowerCase().contains(query) ||
            d.ip.toLowerCase().contains(query) ||
            (d.officeLocation?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Status filter
    if (loaded.statusFilter != null) {
      if (loaded.statusFilter == 'down') {
        list = list
            .where(
              (item) =>
                  item.status.status == DeviceStatusEnum.down ||
                  item.status.status == DeviceStatusEnum.unknown ||
                  item.status.status == DeviceStatusEnum.unreachable,
            )
            .toList();
      } else {
        list = list
            .where(
              (item) => item.status.status.toValue() == loaded.statusFilter,
            )
            .toList();
      }
    }

    // Department filter
    if (loaded.departmentFilter != null) {
      list = list
          .where((item) => item.device.department == loaded.departmentFilter)
          .toList();
    }

    // Location filter
    if (loaded.locationFilter != null) {
      list = list
          .where((item) => item.device.officeLocation == loaded.locationFilter)
          .toList();
    }

    // Type filter
    if (loaded.typeFilter != null) {
      list = list
          .where((item) => item.device.type.toValue() == loaded.typeFilter)
          .toList();
    }

    // Enabled filter
    if (loaded.enabledFilter != null) {
      list = list
          .where((item) => item.device.isEnabled == loaded.enabledFilter)
          .toList();
    }

    // Sorting
    list.sort((a, b) {
      int comp = 0;
      switch (loaded.sortBy) {
        case 'severity':
          final rankA = _getSeverityRank(a.status.status);
          final rankB = _getSeverityRank(b.status.status);
          comp = rankA.compareTo(rankB);
          if (comp == 0) {
            comp = a.device.ownerName.compareTo(b.device.ownerName);
          }
          break;
        case 'owner':
          comp = a.device.ownerName.compareTo(b.device.ownerName);
          break;
        case 'department':
          comp = a.device.department.compareTo(b.device.department);
          break;
        case 'name':
          comp = a.device.name.compareTo(b.device.name);
          break;
        case 'ip':
          comp = a.device.ip.compareTo(b.device.ip);
          break;
        case 'status':
          comp = a.status.status.toValue().compareTo(b.status.status.toValue());
          break;
        case 'latency':
          final latA = a.status.lastLatencyMs ?? 999999;
          final latB = b.status.lastLatencyMs ?? 999999;
          comp = latA.compareTo(latB);
          break;
        case 'lastCheck':
          final timeA =
              a.status.lastCheckAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB =
              b.status.lastCheckAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          comp = timeA.compareTo(timeB);
          break;
        default:
          comp = a.device.ownerName.compareTo(b.device.ownerName);
      }
      return loaded.sortAscending ? comp : -comp;
    });

    return loaded.copyWith(filteredDevices: list);
  }

  int _getSeverityRank(DeviceStatusEnum status) {
    switch (status) {
      case DeviceStatusEnum.down:
        return 1;
      case DeviceStatusEnum.degraded:
        return 2;
      case DeviceStatusEnum.stale:
        return 3;
      case DeviceStatusEnum.unreachable:
        return 4;
      case DeviceStatusEnum.unknown:
        return 4;
      case DeviceStatusEnum.maintenance:
        return 5;
      case DeviceStatusEnum.up:
        return 6;
    }
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _configSubscription?.cancel();
    return super.close();
  }
}
