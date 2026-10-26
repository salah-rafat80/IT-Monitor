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
  bool _isPeriodicCycleRunning = false;
  Completer<void>? _activeForcedCheckCompleter;

  final Set<int> _inFlightDeviceIds = {};
  final Map<int, DateTime> _lastCheckTimestamps = {};
  late final _AsyncSemaphore _concurrencyLimiter;

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
  ]) {
    _concurrencyLimiter = _AsyncSemaphore(_config.maxConcurrentChecks);
  }

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
    _concurrencyLimiter.updatePermits(newConfig.maxConcurrentChecks);
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
    _isPeriodicCycleRunning = false;
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
    if (_activeForcedCheckCompleter != null) {
      return _activeForcedCheckCompleter!.future;
    }

    final completer = Completer<void>();
    _activeForcedCheckCompleter = completer;

    try {
      if (force) {
        _lastCheckTimestamps.clear();
      }
      await _executeMonitoringCycle(force: force, waitForCompletion: true);
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_activeForcedCheckCompleter == completer) {
        _activeForcedCheckCompleter = null;
      }
    }
  }

  Future<void> _executeMonitoringCycle({
    bool force = false,
    bool waitForCompletion = false,
  }) async {
    if ((!_isRunning && !force) || _isPaused) return;

    if (!force) {
      if (_isPeriodicCycleRunning) {
        _logDiagnostic(
          'Periodic monitoring cycle skipped: previous cycle still in flight.',
        );
        return;
      }
      _isPeriodicCycleRunning = true;
    }

    _cycleCount++;

    final targets = <_MonitoringTarget>[];
    final now = DateTime.now();

    final devicesRes = await _deviceRepo.getDevices();
    if (devicesRes.isFailure) {
      _repositoryFailureCount++;
      _logDiagnostic(
        'Failed to retrieve inventory devices for monitoring cycle: ${devicesRes.failureOrNull?.message}',
      );
    }
    final devices = devicesRes.dataOrNull ?? [];

    for (final device in devices) {
      if (!device.isEnabled ||
          !device.isMonitored ||
          device.ip.trim().isEmpty) {
        continue;
      }

      if (!force) {
        final lastCheck = _lastCheckTimestamps[device.id];
        if (lastCheck != null &&
            now.difference(lastCheck).inSeconds <
                _config.checkIntervalSeconds) {
          continue;
        }
      }

      targets.add(_MonitoringTarget.device(device));
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
        if (!infra.isEnabled || infra.ip.trim().isEmpty) continue;

        final virtualId = 10000 + infra.id;
        if (!force) {
          final lastCheck = _lastCheckTimestamps[virtualId];
          if (lastCheck != null &&
              now.difference(lastCheck).inSeconds <
                  _config.checkIntervalSeconds) {
            continue;
          }
        }

        targets.add(_MonitoringTarget.infra(infra));
      }
    }

    if (waitForCompletion) {
      try {
        await _processTargetsQueue(targets, force: force);
      } finally {
        if (!force) {
          _isPeriodicCycleRunning = false;
        }
      }
    } else {
      unawaited(
        _processTargetsQueue(targets, force: force).whenComplete(() {
          if (!force) {
            _isPeriodicCycleRunning = false;
          }
        }),
      );
    }
  }

  /// Worker queue with bounded concurrency limit.
  /// Considers every eligible device & infrastructure asset and never exceeds maxConcurrentChecks.
  Future<void> _processTargetsQueue(
    List<_MonitoringTarget> targets, {
    required bool force,
  }) async {
    if (targets.isEmpty) return;

    final maxConcurrency = _config.maxConcurrentChecks > 0
        ? _config.maxConcurrentChecks
        : 1;
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        if ((!_isRunning && !force) || _isPaused) {
          break;
        }
        if (nextIndex >= targets.length) {
          break;
        }
        final target = targets[nextIndex++];

        // Do not schedule the same device concurrently twice
        if (_inFlightDeviceIds.contains(target.id)) {
          continue;
        }

        if (target.isInfra) {
          await _runCheckForInfraDevice(target.infra!);
        } else {
          await _runCheckForDevice(target.device!);
        }
      }
    }

    final workerCount = targets.length < maxConcurrency
        ? targets.length
        : maxConcurrency;
    final workers = List.generate(workerCount, (_) => worker());
    await Future.wait(workers);
  }

  Future<void> _runCheckForInfraDevice(UniFiDeviceEntity infra) async {
    final virtualId = 10000 + infra.id;
    await _concurrencyLimiter.acquire();
    try {
      _inFlightDeviceIds.add(virtualId);
      _lastCheckTimestamps[virtualId] = DateTime.now();
      _totalChecksExecuted++;

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
      _concurrencyLimiter.release();
    }
  }

  Future<void> _runCheckForDevice(DeviceEntity device) async {
    await _concurrencyLimiter.acquire();
    try {
      _inFlightDeviceIds.add(device.id);
      _lastCheckTimestamps[device.id] = DateTime.now();
      _totalChecksExecuted++;

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
      _concurrencyLimiter.release();
    }
  }

  void dispose() {
    stopMonitoring();
    _concurrencyLimiter.dispose();
    if (!_checkResultController.isClosed) {
      _checkResultController.close();
    }
    if (!_statusUpdateController.isClosed) {
      _statusUpdateController.close();
    }
  }
}

class _MonitoringTarget {
  final int id;
  final DeviceEntity? device;
  final UniFiDeviceEntity? infra;

  _MonitoringTarget.device(this.device) : id = device!.id, infra = null;

  _MonitoringTarget.infra(this.infra)
    : id = 10000 + infra!.id,
      device = null;

  bool get isInfra => infra != null;
}

/// Asynchronous counting semaphore to strictly bound concurrent checks
/// across all cycles, forced executions, and asset types.
class _AsyncSemaphore {
  int _permits;
  final List<Completer<void>> _waiters = [];

  _AsyncSemaphore(int initialPermits)
    : _permits = initialPermits > 0 ? initialPermits : 1;

  void updatePermits(int newPermits) {
    _permits = newPermits > 0 ? newPermits : 1;
    _drain();
  }

  Future<void> acquire() {
    if (_permits > 0) {
      _permits--;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    _permits++;
    _drain();
  }

  void _drain() {
    while (_permits > 0 && _waiters.isNotEmpty) {
      _permits--;
      final waiter = _waiters.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
  }

  void dispose() {
    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
  }
}
