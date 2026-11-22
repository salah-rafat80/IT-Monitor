import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/di/injection.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
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
  final PingChecker _pingChecker;
  final DeviceRepository? _deviceRepo;

  StreamSubscription<List<UniFiDeviceEntity>>? _devicesSub;
  StreamSubscription<List<DeviceStatusEntity>>? _statusesSub;
  String? _activeFactoryId;
  String? get activeFactoryId => _activeFactoryId;
  List<UniFiDeviceEntity> _allInfraDevices = [];

  InfrastructureCubit(
    this._infrastructureRepo,
    this._monitoringRepo,
    this._pingChecker, [
    DeviceRepository? deviceRepo,
  ])  : _deviceRepo = deviceRepo ??
            (getIt.isRegistered<DeviceRepository>()
                ? getIt<DeviceRepository>()
                : null),
        super(const InfrastructureState()) {
    _devicesSub = _infrastructureRepo.watchInfrastructureDevices().listen((
      devices,
    ) {
      _onDevicesUpdated(devices);
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

    try {
      await _infrastructureRepo
          .bootstrapVerifiedAccessPoints()
          .timeout(const Duration(seconds: 10));
      await _infrastructureRepo
          .bootstrapVerifiedSwitches()
          .timeout(const Duration(seconds: 10));
      final res = await _infrastructureRepo
          .getInfrastructureDevices(factoryId: _activeFactoryId)
          .timeout(const Duration(seconds: 10));

      if (isClosed) return;
      if (res.isSuccess) {
        final devices = res.dataOrNull ?? [];
        await _onDevicesUpdated(devices);
        if (isClosed) return;

        // In development / standalone mode, probe initial reachability.
        // In production client mode, the authoritative service daemon manages probe schedules.
        if (triggerPing && devices.isNotEmpty && !AppConfig.isProductionClient) {
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
    } on TimeoutException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Loading infrastructure timed out after 10s: $e',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load infrastructure: $e',
        ),
      );
    }
  }

  Future<void> _onStatusesUpdated(List<DeviceStatusEntity> allStatuses) async {
    if (isClosed) return;
    final statusMap = Map<int, DeviceStatusEntity>.from(state.statuses);
    for (final st in allStatuses) {
      statusMap[st.deviceId] = st;
    }
    await _applyInferredSwitchStatuses(_allInfraDevices, statusMap);
    if (isClosed) return;
    emit(state.copyWith(statuses: statusMap));
  }

  Future<void> _onDevicesUpdated(List<UniFiDeviceEntity> devices) async {
    _allInfraDevices = devices;
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

    await _applyInferredSwitchStatuses(_allInfraDevices, statusMap);

    if (isClosed) return;
    // Exclude switches from the infrastructure management screen and table.
    // Switches have no IP addresses and are structural topology/blueprint components,
    // not pingable/monitored infrastructure assets.
    final visibleDevices = devices
        .where((d) => d.role != UniFiDeviceRole.switchDevice)
        .toList();
    emit(
      state.copyWith(
        isLoading: false,
        devices: visibleDevices,
        statuses: statusMap,
      ),
    );
  }

  /// Evaluates and applies inferred statuses for switches from their downstream devices.
  /// Switches have no IP addresses and are never pinged directly.
  Future<void> _applyInferredSwitchStatuses(
    List<UniFiDeviceEntity> devices,
    Map<int, DeviceStatusEntity> statusMap,
  ) async {
    final switches = devices.where((d) => d.role == UniFiDeviceRole.switchDevice).toList();
    if (switches.isEmpty) return;

    List<DeviceEntity> endpoints = [];
    if (_deviceRepo != null) {
      try {
        final devRes = await _deviceRepo
            .getDevices(factoryId: _activeFactoryId)
            .timeout(const Duration(seconds: 5));
        endpoints = devRes.dataOrNull ?? [];
      } catch (_) {}
    }

    final aps = devices.where((d) => d.role == UniFiDeviceRole.accessPoint).toList();

    for (final sw in switches) {
      final virtualId = 10000 + sw.id;
      final swNameLower = sw.name.toLowerCase();

      final attachedEndpoints = endpoints.where((ep) {
        if (ep.parentSwitchId != null && ep.parentSwitchId == sw.id) return true;
        if (ep.parentSwitchName != null && ep.parentSwitchName!.trim().isNotEmpty) {
          final t = ep.parentSwitchName!.trim().toLowerCase();
          if (t == swNameLower) return true;
          if (t == 'switch 1' && (swNameLower.contains('switch 1') || swNameLower.contains('west'))) return true;
          if (t == 'switch 2' && (swNameLower.contains('switch 2') || swNameLower.contains('east'))) return true;
          if (t.contains('warehouse') && swNameLower.contains('warehouse')) return true;
          if (t.contains('d-link') && swNameLower.contains('d-link')) return true;
          if (t.contains('spare') && swNameLower.contains('spare')) return true;
          if (t.contains('security') && swNameLower.contains('security')) return true;
        }
        return false;
      }).toList();

      final attachedAps = aps.where((ap) {
        final apName = ap.name.toLowerCase();
        if (swNameLower.contains('west') && apName.contains('meeting')) return true;
        if (swNameLower.contains('east') && apName.contains('fm office')) return true;
        if (swNameLower.contains('warehouse core') && (apName.contains('packing') || apName.contains('palitizer'))) return true;
        return false;
      }).toList();

      final childStatuses = <DeviceStatusEnum>[];
      for (final ep in attachedEndpoints) {
        final epSt = statusMap[ep.id]?.effectiveStatus();
        if (epSt != null) {
          childStatuses.add(epSt);
        } else {
          childStatuses.add(DeviceStatusEnum.unknown);
        }
      }

      for (final ap in attachedAps) {
        final apVirtualId = 10000 + ap.id;
        final apSt = statusMap[apVirtualId]?.effectiveStatus();
        if (apSt != null) {
          childStatuses.add(apSt);
        } else {
          childStatuses.add(DeviceStatusEnum.unknown);
        }
      }

      final DeviceStatusEnum inferredStatus;
      if (childStatuses.isEmpty) {
        inferredStatus = DeviceStatusEnum.unknown;
      } else if (childStatuses.any((s) => s == DeviceStatusEnum.up)) {
        inferredStatus = DeviceStatusEnum.up;
      } else if (childStatuses.every((s) => s == DeviceStatusEnum.down || s == DeviceStatusEnum.unreachable)) {
        inferredStatus = DeviceStatusEnum.down;
      } else if (childStatuses.any((s) => s == DeviceStatusEnum.degraded)) {
        inferredStatus = DeviceStatusEnum.degraded;
      } else {
        inferredStatus = DeviceStatusEnum.unknown;
      }

      final current = statusMap[virtualId] ?? DeviceStatusEntity.initial(virtualId);
      final updated = current.copyWith(
        status: inferredStatus,
        lastFailureReason: inferredStatus == DeviceStatusEnum.down
            ? 'All downstream devices unreachable'
            : null,
      );
      statusMap[virtualId] = updated;

      unawaited(_monitoringRepo.saveDeviceStatus(updated));
    }
  }

  /// Pings a specific infrastructure device immediately, updating its status and active incident.
  Future<CheckResult> pingDevice(UniFiDeviceEntity device) async {
    final virtualId = 10000 + device.id;
    if (device.role == UniFiDeviceRole.switchDevice) {
      // Switches have no IP addresses and must never be pinged directly.
      return CheckResult(
        deviceId: virtualId,
        targetIp: '',
        checkType: CheckType.icmp,
        isSuccess: false,
        errorMessage: 'Switches have no IP addresses and are not probed directly.',
        timestamp: DateTime.now(),
      );
    }

    final updatedChecking = Set<int>.from(state.checkingDeviceIds)
      ..add(virtualId);
    if (!isClosed) {
      emit(state.copyWith(checkingDeviceIds: updatedChecking));
    }

    try {
      if (AppConfig.isProductionClient) {
        final client = getIt.isRegistered<MonitoringServiceClient>()
            ? getIt<MonitoringServiceClient>()
            : null;
        if (client != null && client.isAuthenticated) {
          await client.manualCheck(virtualId);
          final currentStatusRes = await _monitoringRepo.getDeviceStatus(
            virtualId,
          );
          final currentStatus =
              currentStatusRes.dataOrNull ??
              DeviceStatusEntity.initial(virtualId);

          final statusMap = Map<int, DeviceStatusEntity>.from(state.statuses);
          statusMap[virtualId] = currentStatus;

          if (!isClosed) {
            final remainingChecking = Set<int>.from(state.checkingDeviceIds)
              ..remove(virtualId);
            emit(
              state.copyWith(
                statuses: statusMap,
                checkingDeviceIds: remainingChecking,
                successMessage: currentStatus.status == DeviceStatusEnum.up
                    ? '${device.name} (${device.ip}) is UP (${currentStatus.lastLatencyMs ?? 0} ms)'
                    : '${device.name} (${device.ip}) is DOWN / ${currentStatus.lastFailureReason ?? "Request timed out"}',
              ),
            );
          }

          return CheckResult(
            deviceId: virtualId,
            targetIp: device.ip,
            checkType: CheckType.icmp,
            isSuccess: currentStatus.status == DeviceStatusEnum.up,
            latencyMs: currentStatus.lastLatencyMs,
            errorMessage: currentStatus.lastFailureReason,
            timestamp: DateTime.now(),
          );
        }
      }

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

      final statusMap = Map<int, DeviceStatusEntity>.from(state.statuses);
      statusMap[virtualId] = newStatus;

      if (!isClosed) {
        final remainingChecking = Set<int>.from(state.checkingDeviceIds)
          ..remove(virtualId);
        emit(
          state.copyWith(
            statuses: statusMap,
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
          .where((d) =>
              d.isEnabled &&
              d.role != UniFiDeviceRole.switchDevice &&
              d.ip.trim().isNotEmpty)
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
    _statusesSub?.cancel();
    return super.close();
  }
}
