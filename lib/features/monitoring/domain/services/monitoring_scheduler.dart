import 'dart:async';
import 'package:injectable/injectable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';

import '../entities/check_result.dart';
import '../entities/device_status_entity.dart';
import '../entities/monitoring_config.dart';
import '../repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/incidents/domain/services/incident_engine.dart';
import 'ping_checker.dart';
import 'status_engine.dart';

import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';

@lazySingleton
class MonitoringScheduler {
  final DeviceRepository _deviceRepo;
  final MonitoringRepository _monitoringRepo;
  final PingChecker _pingChecker;
  final IncidentEngine? _incidentEngine;
  final InfrastructureRepository? _infrastructureRepo;

  MonitoringConfig _config = const MonitoringConfig();
  Timer? _schedulerLoopTimer;
  bool _isRunning = false;
  bool _isPaused = false;

  final Set<int> _inFlightDeviceIds = {};
  final Map<int, DateTime> _lastCheckTimestamps = {};

  final StreamController<CheckResult> _checkResultController =
      StreamController<CheckResult>.broadcast();
  final StreamController<DeviceStatusEntity> _statusUpdateController =
      StreamController<DeviceStatusEntity>.broadcast();

  // Internal health and error diagnostics telemetry
  int _cycleCount = 0;
  int _totalChecksExecuted = 0;
  int _persistenceFailureCount = 0;
  int _repositoryFailureCount = 0;
  int _unexpectedExceptionCount = 0;
  final List<String> _diagnosticLogs = [];

  MonitoringScheduler(
    this._deviceRepo,
    this._monitoringRepo,
    this._pingChecker, [
    this._incidentEngine,
    this._infrastructureRepo,
  ]);

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  MonitoringConfig get config => _config;
  Stream<CheckResult> get checkResultsStream => _checkResultController.stream;
  Stream<DeviceStatusEntity> get statusUpdatesStream =>
      _statusUpdateController.stream;

  int get cycleCount => _cycleCount;
  int get totalChecksExecuted => _totalChecksExecuted;
  int get persistenceFailureCount => _persistenceFailureCount;
  int get repositoryFailureCount => _repositoryFailureCount;
  int get unexpectedExceptionCount => _unexpectedExceptionCount;
  List<String> get diagnosticLogs => List.unmodifiable(_diagnosticLogs);

  void updateConfig(MonitoringConfig newConfig) {
    _config = newConfig;
  }

  void _logDiagnostic(String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = error != null
        ? '[$timestamp] [MonitoringScheduler] $message (Error: $error)'
        : '[$timestamp] [MonitoringScheduler] $message';
    if (_diagnosticLogs.length >= 100) {
      _diagnosticLogs.removeAt(0);
    }
    _diagnosticLogs.add(logLine);

    // Safe contextual logging (no secrets or user passwords)
    // ignore: avoid_print
    print(logLine);
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }

  void startMonitoring() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;

    // Run immediate cycle then set periodic timer
    _executeMonitoringCycle();
    _schedulerLoopTimer = Timer.periodic(
      Duration(seconds: _config.checkIntervalSeconds),
      (_) => _executeMonitoringCycle(),
    );
  }

  void pauseMonitoring() {
    _isPaused = true;
  }

  void resumeMonitoring() {
    _isPaused = false;
    _executeMonitoringCycle();
  }

  void stopMonitoring() {
    _schedulerLoopTimer?.cancel();
    _schedulerLoopTimer = null;
    _isRunning = false;
    _isPaused = false;
    _inFlightDeviceIds.clear();
  }

  Future<void> triggerSingleCheck(int deviceId) async {
    if (deviceId >= 10000 && _infrastructureRepo != null) {
      final infraId = deviceId - 10000;
      final infraRes = await _infrastructureRepo.getDeviceById(infraId);
      final infra = infraRes.dataOrNull;
      if (infra != null && infra.isEnabled && infra.ip.trim().isNotEmpty) {
        await _runCheckForInfraDevice(infra);
      }
      return;
    }

    final deviceRes = await _deviceRepo.getDeviceById(deviceId);
    final device = deviceRes.dataOrNull;

    if (device == null || !device.isEnabled || device.ip.trim().isEmpty) return;

    await _runCheckForDevice(device);
  }

  Future<void> triggerAllChecks({bool force = true}) async {
    if (force) {
      _lastCheckTimestamps.clear();
    }
    await _executeMonitoringCycle(force: force);
  }

  Future<void> _executeMonitoringCycle({bool force = false}) async {
    if (!_isRunning || _isPaused) return;
    _cycleCount++;

    final devicesRes = await _deviceRepo.getDevices();
    if (devicesRes.isFailure) {
      _repositoryFailureCount++;
      _logDiagnostic(
        'Failed to retrieve inventory devices for monitoring cycle: ${devicesRes.failureOrNull?.message}',
      );
    }
    final devices = devicesRes.dataOrNull ?? [];

    for (final device in devices) {
      if (!_isRunning || _isPaused) {
        break;
      }

      // Enforce bounded global concurrency limit
      if (_inFlightDeviceIds.length >= _config.maxConcurrentChecks) {
        break;
      }

      // Ignore disabled devices, unmonitored assets, or devices with invalid/empty IP
      if (!device.isEnabled ||
          !device.isMonitored ||
          device.ip.trim().isEmpty) {
        continue;
      }

      // Prevent duplicate concurrent check for the exact same device
      if (_inFlightDeviceIds.contains(device.id)) {
        continue;
      }

      final lastCheck = _lastCheckTimestamps[device.id];
      final now = DateTime.now();

      // Check interval elapsed check (bypassed if force is true)
      if (!force &&
          lastCheck != null &&
          now.difference(lastCheck).inSeconds < _config.checkIntervalSeconds) {
        continue;
      }

      // Dispatch async check without blocking loop or UI thread
      unawaited(_runCheckForDevice(device));
    }

    // Monitor critical infrastructure assets (UniFi Gateways, Controllers, Switches)
    if (_infrastructureRepo != null) {
      final infraRes = await _infrastructureRepo.getInfrastructureDevices();
      if (infraRes.isFailure) {
        _repositoryFailureCount++;
        _logDiagnostic(
          'Failed to retrieve infrastructure devices for monitoring cycle: ${infraRes.failureOrNull?.message}',
        );
      }
      final infraDevices = infraRes.dataOrNull ?? [];

      for (final infra in infraDevices) {
        if (!_isRunning || _isPaused) break;
        if (_inFlightDeviceIds.length >= _config.maxConcurrentChecks) break;
        if (!infra.isEnabled || infra.ip.trim().isEmpty) continue;

        final virtualId = 10000 + infra.id;
        if (_inFlightDeviceIds.contains(virtualId)) continue;

        final lastCheck = _lastCheckTimestamps[virtualId];
        final now = DateTime.now();

        if (!force &&
            lastCheck != null &&
            now.difference(lastCheck).inSeconds <
                _config.checkIntervalSeconds) {
          continue;
        }

        unawaited(_runCheckForInfraDevice(infra));
      }
    }
  }

  Future<void> _runCheckForInfraDevice(UniFiDeviceEntity infra) async {
    final virtualId = 10000 + infra.id;
    _inFlightDeviceIds.add(virtualId);
    _lastCheckTimestamps[virtualId] = DateTime.now();
    _totalChecksExecuted++;

    try {
      final checkResult = await _pingChecker.checkPing(
        deviceId: virtualId,
        targetIp: infra.ip,
        timeout: Duration(seconds: _config.timeoutSeconds),
      );

      if (!_checkResultController.isClosed) {
        _checkResultController.add(checkResult);
      }

      final saveCheckRes = await _monitoringRepo.saveCheckResult(checkResult);
      if (saveCheckRes.isFailure) {
        _persistenceFailureCount++;
        _logDiagnostic(
          'Failed to persist check result for infrastructure asset #${infra.id} (${infra.ip}): ${saveCheckRes.failureOrNull?.message}',
        );
      }

      final currentStatusRes = await _monitoringRepo.getDeviceStatus(virtualId);
      if (currentStatusRes.isFailure) {
        _repositoryFailureCount++;
        _logDiagnostic(
          'Failed to load status for infrastructure asset #${infra.id}: ${currentStatusRes.failureOrNull?.message}',
        );
      }
      final currentStatus =
          currentStatusRes.dataOrNull ?? DeviceStatusEntity.initial(virtualId);

      final newStatus = StatusEngine.processCheckResult(
        currentStatus: currentStatus,
        checkResult: checkResult,
        config: _config,
      );

      final saveStatusRes = await _monitoringRepo.saveDeviceStatus(newStatus);
      if (saveStatusRes.isFailure) {
        _persistenceFailureCount++;
        _logDiagnostic(
          'Failed to persist status for infrastructure asset #${infra.id}: ${saveStatusRes.failureOrNull?.message}',
        );
      }

      if (!_statusUpdateController.isClosed) {
        _statusUpdateController.add(newStatus);
      }
      if (_incidentEngine != null) {
        try {
          await _incidentEngine.processInfrastructureStatusChange(
            infra,
            newStatus,
          );
        } catch (e, st) {
          _unexpectedExceptionCount++;
          _logDiagnostic(
            'Failed to process incident update for infrastructure asset #${infra.id}',
            error: e,
            stackTrace: st,
          );
        }
      }
    } catch (e, st) {
      _unexpectedExceptionCount++;
      _logDiagnostic(
        'Unexpected error checking infrastructure asset #${infra.id} (${infra.ip})',
        error: e,
        stackTrace: st,
      );
    } finally {
      _inFlightDeviceIds.remove(virtualId);
    }
  }

  Future<void> _runCheckForDevice(DeviceEntity device) async {
    _inFlightDeviceIds.add(device.id);
    _lastCheckTimestamps[device.id] = DateTime.now();
    _totalChecksExecuted++;

    try {
      final checkResult = await _pingChecker.checkPing(
        deviceId: device.id,
        targetIp: device.ip,
        timeout: Duration(seconds: _config.timeoutSeconds),
      );

      if (!_checkResultController.isClosed) {
        _checkResultController.add(checkResult);
      }

      final saveCheckRes = await _monitoringRepo.saveCheckResult(checkResult);
      if (saveCheckRes.isFailure) {
        _persistenceFailureCount++;
        _logDiagnostic(
          'Failed to persist check result for device #${device.id} (${device.ip}): ${saveCheckRes.failureOrNull?.message}',
        );
      }

      // Load current status and evaluate status transition
      final currentStatusRes = await _monitoringRepo.getDeviceStatus(device.id);
      if (currentStatusRes.isFailure) {
        _repositoryFailureCount++;
        _logDiagnostic(
          'Failed to load device status for device #${device.id}: ${currentStatusRes.failureOrNull?.message}',
        );
      }
      final currentStatus =
          currentStatusRes.dataOrNull ?? DeviceStatusEntity.initial(device.id);

      final newStatus = StatusEngine.processCheckResult(
        currentStatus: currentStatus,
        checkResult: checkResult,
        config: _config,
      );

      final saveStatusRes = await _monitoringRepo.saveDeviceStatus(newStatus);
      if (saveStatusRes.isFailure) {
        _persistenceFailureCount++;
        _logDiagnostic(
          'Failed to persist status for device #${device.id}: ${saveStatusRes.failureOrNull?.message}',
        );
      }

      if (!_statusUpdateController.isClosed) {
        _statusUpdateController.add(newStatus);
      }
      if (_incidentEngine != null) {
        try {
          await _incidentEngine.processDeviceStatusChange(newStatus);
        } catch (e, st) {
          _unexpectedExceptionCount++;
          _logDiagnostic(
            'Failed to process incident update for device #${device.id}',
            error: e,
            stackTrace: st,
          );
        }
      }
    } catch (e, st) {
      _unexpectedExceptionCount++;
      _logDiagnostic(
        'Unexpected error checking device #${device.id} (${device.ip})',
        error: e,
        stackTrace: st,
      );
    } finally {
      _inFlightDeviceIds.remove(device.id);
    }
  }

  void dispose() {
    stopMonitoring();
    if (!_checkResultController.isClosed) {
      _checkResultController.close();
    }
    if (!_statusUpdateController.isClosed) {
      _statusUpdateController.close();
    }
  }
}
