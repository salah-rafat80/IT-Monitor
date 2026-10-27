import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../../incidents/domain/services/incident_engine.dart';
import '../../../monitoring/domain/entities/check_result.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitoring_config.dart';
import '../../../monitoring/domain/repositories/monitoring_repository.dart';
import '../../../monitoring/domain/services/ping_checker.dart';
import '../../../monitoring/domain/services/status_engine.dart';
import '../../domain/entities/unifi_device_entity.dart';
import '../../domain/repositories/infrastructure_repository.dart';
import 'infrastructure_state.dart';

@lazySingleton
class InfrastructureCubit extends Cubit<InfrastructureState> {
  final InfrastructureRepository _infrastructureRepo;
  final MonitoringRepository _monitoringRepo;
  final IncidentRepository _incidentRepo;
  final PingChecker _pingChecker;
  final IncidentEngine _incidentEngine;

  StreamSubscription<List<UniFiDeviceEntity>>? _devicesSub;
  StreamSubscription<List<IncidentEntity>>? _incidentsSub;
  StreamSubscription<List<DeviceStatusEntity>>? _statusesSub;
  String? _activeFactoryId;
  String? get activeFactoryId => _activeFactoryId;

  InfrastructureCubit(
    this._infrastructureRepo,
    this._monitoringRepo,
    this._incidentRepo,
    this._pingChecker,
    this._incidentEngine,
  ) : super(const InfrastructureState()) {
    _devicesSub = _infrastructureRepo.watchInfrastructureDevices().listen((
      devices,
    ) {
      _onDevicesUpdated(devices);
    });
    _incidentsSub = _incidentRepo.watchActiveIncidents().listen((incidents) {
      _onIncidentsUpdated(incidents);
    });
    _statusesSub = _monitoringRepo.watchAllDeviceStatuses().listen((statuses) {
      _onStatusesUpdated(statuses);
    });
  }

  Future<void> setFactory(String? factoryId) async {
    _activeFactoryId = factoryId;
    await loadInfrastructure(factoryId: factoryId);
  }

  Future<void> loadInfrastructure({
    bool triggerPing = true,
    String? factoryId,
  }) async {
    if (isClosed) return;
    _activeFactoryId = factoryId ?? _activeFactoryId;
    emit(state.copyWith(isLoading: true, clearError: true));

    _devicesSub?.cancel();
    _devicesSub = _infrastructureRepo
        .watchInfrastructureDevices(factoryId: _activeFactoryId)
        .listen((devices) {
          _onDevicesUpdated(devices);
        });

    _incidentsSub?.cancel();
    _incidentsSub = _incidentRepo
        .watchActiveIncidents(factoryId: _activeFactoryId)
        .listen((incidents) {
          _onIncidentsUpdated(incidents);
        });

    await _infrastructureRepo.bootstrapVerifiedAccessPoints();
    final res = await _infrastructureRepo.getInfrastructureDevices(
      factoryId: _activeFactoryId,
    );

    if (isClosed) return;
    if (res.isSuccess) {
      final devices = res.dataOrNull ?? [];
      await _onDevicesUpdated(devices);
      if (isClosed) return;
      final activeIncRes = await _incidentRepo.getActiveIncidents(
        factoryId: _activeFactoryId,
      );
      if (isClosed) return;
      if (activeIncRes.isSuccess) {
        _onIncidentsUpdated(activeIncRes.dataOrNull ?? []);
      }

      // Automatically run an initial reachability probe so real statuses and latencies are known
      if (triggerPing && devices.isNotEmpty) {
        unawaited(pingAllInfrastructure());
      }
    } else {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              res.failureOrNull?.message ??
              'Failed to load infrastructure devices',
        ),
      );
    }
  }

  void _onIncidentsUpdated(List<IncidentEntity> incidents) {
    if (isClosed) return;
    final incidentMap = <int, IncidentEntity>{};
    for (final inc in incidents) {
      incidentMap[inc.deviceId] = inc;
    }
    emit(state.copyWith(activeIncidents: incidentMap));
  }

  void _onStatusesUpdated(List<DeviceStatusEntity> allStatuses) {
    if (isClosed) return;
    final statusMap = Map<int, DeviceStatusEntity>.from(state.statuses);
    bool changed = false;
    for (final st in allStatuses) {
      if (st.deviceId >= 10000) {
        statusMap[st.deviceId] = st;
        changed = true;
      }
    }
    if (changed) {
      emit(state.copyWith(statuses: statusMap));
    }
  }

  Future<void> _onDevicesUpdated(List<UniFiDeviceEntity> devices) async {
    final statusMap = Map<int, DeviceStatusEntity>.from(state.statuses);

    for (final dev in devices) {
      final virtualId = 10000 + dev.id;
      final stRes = await _monitoringRepo.getDeviceStatus(virtualId);
      if (isClosed) return;
      if (stRes.isSuccess && stRes.dataOrNull != null) {
        statusMap[virtualId] = stRes.dataOrNull!;
      } else if (!statusMap.containsKey(virtualId)) {
        statusMap[virtualId] = DeviceStatusEntity.initial(virtualId);
      }
    }

    if (isClosed) return;
    emit(
      state.copyWith(isLoading: false, devices: devices, statuses: statusMap),
    );
  }

  /// Pings a specific infrastructure device immediately, updating its status and active incident.
  Future<CheckResult> pingDevice(UniFiDeviceEntity device) async {
    final virtualId = 10000 + device.id;
    final updatedChecking = Set<int>.from(state.checkingDeviceIds)
      ..add(virtualId);
    if (!isClosed) {
      emit(state.copyWith(checkingDeviceIds: updatedChecking));
    }

    try {
      final checkResult = await _pingChecker.checkPing(
        deviceId: virtualId,
        targetIp: device.ip,
        timeout: const Duration(seconds: 3),
      );

      await _monitoringRepo.saveCheckResult(checkResult);

      final currentStatusRes = await _monitoringRepo.getDeviceStatus(virtualId);
      final currentStatus =
          currentStatusRes.dataOrNull ?? DeviceStatusEntity.initial(virtualId);

      final newStatus = StatusEngine.processCheckResult(
        currentStatus: currentStatus,
        checkResult: checkResult,
        config: const MonitoringConfig(
          checkIntervalSeconds: 30,
          timeoutSeconds: 3,
          failureThreshold: 2,
          recoveryThreshold: 1,
        ),
      );

      await _monitoringRepo.saveDeviceStatus(newStatus);
      await _incidentEngine.processInfrastructureStatusChange(
        device,
        newStatus,
      );

      final statusMap = Map<int, DeviceStatusEntity>.from(state.statuses);
      statusMap[virtualId] = newStatus;

      final activeIncRes = await _incidentRepo.getActiveIncidents();
      final incidentMap = <int, IncidentEntity>{};
      if (activeIncRes.isSuccess) {
        for (final inc in (activeIncRes.dataOrNull ?? [])) {
          incidentMap[inc.deviceId] = inc;
        }
      }

      if (!isClosed) {
        final remainingChecking = Set<int>.from(state.checkingDeviceIds)
          ..remove(virtualId);
        emit(
          state.copyWith(
            statuses: statusMap,
            activeIncidents: incidentMap,
            checkingDeviceIds: remainingChecking,
            successMessage: checkResult.isSuccess
                ? '${device.name} (${device.ip}) is UP (${checkResult.latencyMs} ms)'
                : '${device.name} (${device.ip}) is DOWN / Request timed out',
          ),
        );
      }
      return checkResult;
    } finally {
      if (!isClosed && state.checkingDeviceIds.contains(virtualId)) {
        final remainingChecking = Set<int>.from(state.checkingDeviceIds)
          ..remove(virtualId);
        emit(state.copyWith(checkingDeviceIds: remainingChecking));
      }
    }
  }

  /// Pings all enabled infrastructure devices in parallel.
  Future<void> pingAllInfrastructure() async {
    if (isClosed || state.isCheckingAll) return;
    emit(state.copyWith(isCheckingAll: true));

    try {
      final targetDevices = state.devices
          .where((d) => d.isEnabled && d.ip.trim().isNotEmpty)
          .toList();
      await Future.wait(targetDevices.map((d) => pingDevice(d)));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isCheckingAll: false));
      }
    }
  }

  Future<bool> saveDevice(UniFiDeviceEntity device) async {
    if (isClosed) return false;
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    final res = await _infrastructureRepo.saveInfrastructureDevice(device);

    if (isClosed) return false;
    if (res.isSuccess) {
      await loadInfrastructure(triggerPing: false);
      if (isClosed) return true;
      emit(
        state.copyWith(
          isLoading: false,
          successMessage: 'UniFi device ${device.name} saved successfully',
        ),
      );
      return true;
    } else {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              res.failureOrNull?.message ?? 'Failed to save UniFi device',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteDevice(int id) async {
    if (isClosed) return false;
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    final res = await _infrastructureRepo.deleteInfrastructureDevice(id);

    if (isClosed) return false;
    if (res.isSuccess) {
      await loadInfrastructure(triggerPing: false);
      if (isClosed) return true;
      emit(
        state.copyWith(
          isLoading: false,
          successMessage: 'UniFi device deleted successfully',
        ),
      );
      return true;
    } else {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              res.failureOrNull?.message ?? 'Failed to delete UniFi device',
        ),
      );
      return false;
    }
  }

  Future<bool> confirmRole({
    required int id,
    required UniFiDeviceRole role,
    required bool isCritical,
    required List<String> linkedSubnets,
  }) async {
    if (isClosed) return false;
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    final res = await _infrastructureRepo.confirmDeviceRole(
      id: id,
      role: role,
      isCritical: isCritical,
      linkedSubnets: linkedSubnets,
    );

    if (isClosed) return false;
    if (res.isSuccess) {
      await loadInfrastructure(triggerPing: false);
      if (isClosed) return true;
      emit(
        state.copyWith(
          isLoading: false,
          successMessage: 'UniFi role confirmed successfully',
        ),
      );
      return true;
    } else {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: res.failureOrNull?.message ?? 'Failed to confirm role',
        ),
      );
      return false;
    }
  }

  void updateStatus(DeviceStatusEntity status) {
    if (isClosed) return;
    final updated = Map<int, DeviceStatusEntity>.from(state.statuses);
    updated[status.deviceId] = status;
    emit(state.copyWith(statuses: updated));
  }

  @override
  Future<void> close() {
    _devicesSub?.cancel();
    _incidentsSub?.cancel();
    _statusesSub?.cancel();
    return super.close();
  }
}
