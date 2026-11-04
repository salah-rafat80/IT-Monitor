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

import '../../../factories/domain/entities/factory_entity.dart';
import '../../../factories/domain/entities/gateway_status_entity.dart';
import '../../../factories/domain/repositories/factory_repository.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';

@lazySingleton
class MonitoringScheduler {
  final DeviceRepository _deviceRepo;
  final MonitoringRepository _monitoringRepo;
  final PingChecker _pingChecker;
  final IncidentEngine? _incidentEngine;
  final InfrastructureRepository? _infrastructureRepo;
  final FactoryRepository? _factoryRepo;

  MonitoringConfig _config = const MonitoringConfig();
  Timer? _schedulerLoopTimer;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isPeriodicCycleRunning = false;
  Completer<bool>? _activeForcedCheckCompleter;

  final Set<int> _inFlightDeviceIds = {};
  final Map<int, Completer<void>> _inFlightCheckCompleters = {};
  final Map<int, DateTime> _lastCheckTimestamps = {};
  late final AsyncSemaphore _concurrencyLimiter;

  final StreamController<CheckResult> _checkResultController =
      StreamController<CheckResult>.broadcast();
  final StreamController<DeviceStatusEntity> _statusUpdateController =
      StreamController<DeviceStatusEntity>.broadcast();
  final StreamController<MonitoringConfig> _configUpdateController =
      StreamController<MonitoringConfig>.broadcast();

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
    this._factoryRepo,
  ]) {
    _concurrencyLimiter = AsyncSemaphore(_config.maxConcurrentChecks);
  }

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  MonitoringConfig get config => _config;
  Stream<CheckResult> get checkResultsStream => _checkResultController.stream;
  Stream<DeviceStatusEntity> get statusUpdatesStream =>
      _statusUpdateController.stream;
  Stream<MonitoringConfig> get configUpdatesStream =>
      _configUpdateController.stream;

  int get cycleCount => _cycleCount;
  int get totalChecksExecuted => _totalChecksExecuted;
  int get persistenceFailureCount => _persistenceFailureCount;
  int get repositoryFailureCount => _repositoryFailureCount;
  int get unexpectedExceptionCount => _unexpectedExceptionCount;
  int get currentActiveChecks => _concurrencyLimiter.activeCount;
  int get maxPermits => _concurrencyLimiter.maxPermits;
  List<String> get diagnosticLogs => List.unmodifiable(_diagnosticLogs);

  void updateConfig(MonitoringConfig newConfig) {
    _config = newConfig;
    _concurrencyLimiter.updatePermits(newConfig.maxConcurrentChecks);
    if (!_configUpdateController.isClosed) {
      _configUpdateController.add(newConfig);
    }
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
    if (deviceId >= 50000 && _factoryRepo != null) {
      final factoryId = deviceId == 50001
          ? 'rnf'
          : (deviceId == 50002 ? 'bnf' : null);
      if (factoryId != null) {
        final fRes = await _factoryRepo.getFactoryById(factoryId);
        final factory = fRes.dataOrNull;
        if (factory != null &&
            factory.gatewayIp != null &&
            factory.gatewayIp!.trim().isNotEmpty) {
          await _runCheckForGateway(factory, deviceId);
        }
      }
      return;
    }

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

  Future<bool> triggerAllChecks({bool force = true}) async {
    if (_activeForcedCheckCompleter != null) {
      return _activeForcedCheckCompleter!.future;
    }

    final completer = Completer<bool>();
    _activeForcedCheckCompleter = completer;

    try {
      if (force) {
        _lastCheckTimestamps.clear();
      }
      final success = await _executeMonitoringCycle(
        force: force,
        waitForCompletion: true,
      );
      completer.complete(success);
      return success;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_activeForcedCheckCompleter == completer) {
        _activeForcedCheckCompleter = null;
      }
    }
  }

  Future<bool> _executeMonitoringCycle({
    bool force = false,
    bool waitForCompletion = false,
  }) async {
    if ((!_isRunning && !force) || _isPaused) return false;

    if (!force) {
      if (_isPeriodicCycleRunning) {
        _logDiagnostic(
          'Periodic monitoring cycle skipped: previous cycle still in flight.',
        );
        return false;
      }
      _isPeriodicCycleRunning = true;
    }

    _cycleCount++;
    var repositorySuccess = true;

    final targets = <_MonitoringTarget>[];
    final now = DateTime.now();

    final devicesRes = await _deviceRepo.getDevices();
    if (devicesRes.isFailure) {
      _repositoryFailureCount++;
      repositorySuccess = false;
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
        repositorySuccess = false;
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

    // Monitor factory gateways (RNF 192.168.22.1, BNF 192.168.21.1) as first-class persistent targets
    if (_factoryRepo != null) {
      final factoriesRes = await _factoryRepo.getFactories(
        includeInactive: false,
      );
      final activeFactories = (factoriesRes.dataOrNull ?? [])
          .where(
            (f) =>
                f.id != 'unassigned' &&
                f.gatewayIp != null &&
                f.gatewayIp!.trim().isNotEmpty,
          )
          .toList();

      for (final factory in activeFactories) {
        final virtualId = factory.id == 'rnf'
            ? 50001
            : (factory.id == 'bnf'
                  ? 50002
                  : (50000 + factory.id.hashCode.abs() % 1000));
        if (!force) {
          final lastCheck = _lastCheckTimestamps[virtualId];
          if (lastCheck != null &&
              now.difference(lastCheck).inSeconds <
                  _config.checkIntervalSeconds) {
            continue;
          }
        }
        targets.add(_MonitoringTarget.gateway(factory, virtualId));
      }
    }

    if (waitForCompletion) {
      try {
        return await _processTargetsQueue(
          targets,
          force: force,
          repositorySuccess: repositorySuccess,
        );
      } finally {
        if (!force) {
          _isPeriodicCycleRunning = false;
        }
      }
    } else {
      unawaited(
        _processTargetsQueue(
          targets,
          force: force,
          repositorySuccess: repositorySuccess,
        ).whenComplete(() {
          if (!force) {
            _isPeriodicCycleRunning = false;
          }
        }),
      );
      return repositorySuccess;
    }
  }

  /// Worker queue with bounded concurrency limit.
  /// Considers every eligible device & infrastructure asset and never exceeds maxConcurrentChecks.
  Future<bool> _processTargetsQueue(
    List<_MonitoringTarget> targets, {
    required bool force,
    required bool repositorySuccess,
  }) async {
    if (targets.isEmpty) return repositorySuccess;

    final maxConcurrency = _config.maxConcurrentChecks > 0
        ? _config.maxConcurrentChecks
        : 1;
    var nextIndex = 0;
    var allCompletedSuccessfully = repositorySuccess;

    Future<void> worker() async {
      while (true) {
        if ((!_isRunning && !force) || _isPaused) {
          allCompletedSuccessfully = false;
          break;
        }
        if (nextIndex >= targets.length) {
          break;
        }
        final target = targets[nextIndex++];

        // Account for targets already in flight (e.g. from an overlapping periodic cycle).
        // Wait for the active check to finish rather than silently omitting the target!
        if (_inFlightDeviceIds.contains(target.id)) {
          final inFlightCompleter = _inFlightCheckCompleters[target.id];
          if (inFlightCompleter != null) {
            await inFlightCompleter.future;
          }
          continue;
        }

        if (target.isGateway) {
          await _runCheckForGateway(target.factory!, target.id);
        } else if (target.isInfra) {
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

    if (_isPaused || (!_isRunning && !force)) {
      allCompletedSuccessfully = false;
    }

    return allCompletedSuccessfully;
  }

  Future<void> _runCheckForGateway(FactoryEntity factory, int virtualId) async {
    final gatewayIp = factory.gatewayIp;
    if (gatewayIp == null || gatewayIp.trim().isEmpty) return;

    final checkCompleter = Completer<void>();
    _inFlightCheckCompleters[virtualId] = checkCompleter;
    await _concurrencyLimiter.acquire();
    try {
      _inFlightDeviceIds.add(virtualId);
      final checkTime = DateTime.now();
      _lastCheckTimestamps[virtualId] = checkTime;
      _totalChecksExecuted++;

      final pingRes = await _pingChecker.checkPing(
        deviceId: virtualId,
        targetIp: gatewayIp,
        timeout: Duration(seconds: _config.timeoutSeconds),
      );

      final checkResult = CheckResult(
        deviceId: virtualId,
        assetId: 'gateway',
        factoryId: factory.id,
        targetIp: gatewayIp,
        checkType: CheckType.icmp,
        isSuccess: pingRes.isSuccess,
        latencyMs: pingRes.latencyMs,
        packetLossPercent: pingRes.packetLossPercent,
        errorMessage: pingRes.errorMessage,
        timestamp: checkTime,
      );

      if (!_checkResultController.isClosed) {
        _checkResultController.add(checkResult);
      }

      await _monitoringRepo.saveCheckResult(checkResult);

      if (_factoryRepo != null) {
        final currentStatRes = await _factoryRepo.getGatewayStatus(factory.id);
        final currentStat =
            currentStatRes.dataOrNull ??
            GatewayStatusEntity(
              factoryId: factory.id,
              gatewayIp: gatewayIp,
              status: GatewayHealthStatus.unknown,
            );

        int consecutiveFailures = currentStat.consecutiveFailures;
        int consecutiveSuccesses = currentStat.consecutiveSuccesses;
        GatewayHealthStatus newHealth = currentStat.status;
        DateTime? lastSuccessful = currentStat.lastSuccessfulCheckAt;

        if (checkResult.isSuccess) {
          consecutiveSuccesses++;
          consecutiveFailures = 0;
          lastSuccessful = checkTime;

          if (consecutiveSuccesses >= _config.recoveryThreshold) {
            final latency = checkResult.latencyMs ?? 0;
            newHealth = latency > 150
                ? GatewayHealthStatus.degraded
                : GatewayHealthStatus.online;
          }
        } else {
          consecutiveFailures++;
          consecutiveSuccesses = 0;

          if (consecutiveFailures >= _config.failureThreshold) {
            newHealth = GatewayHealthStatus.down;
          }
        }

        final updatedStatus = GatewayStatusEntity(
          factoryId: factory.id,
          gatewayIp: gatewayIp,
          status: newHealth,
          lastCheckAt: checkTime,
          lastSuccessfulCheckAt: lastSuccessful,
          latencyMs: checkResult.latencyMs,
          consecutiveFailures: consecutiveFailures,
          consecutiveSuccesses: consecutiveSuccesses,
          failureReason: checkResult.errorMessage,
        );

        await _factoryRepo.saveGatewayStatus(updatedStatus);

        // Also persist gateway status to authoritative DeviceStatuses table (virtual ID 50001 / 50002)
        final gwDeviceStatus = DeviceStatusEntity(
          deviceId: virtualId,
          status: newHealth == GatewayHealthStatus.online
              ? DeviceStatusEnum.up
              : (newHealth == GatewayHealthStatus.degraded
                    ? DeviceStatusEnum.degraded
                    : (newHealth == GatewayHealthStatus.down
                          ? DeviceStatusEnum.down
                          : DeviceStatusEnum.unknown)),
          lastCheckAt: checkTime,
          lastSeen: checkResult.isSuccess ? checkTime : lastSuccessful,
          lastLatencyMs: checkResult.latencyMs,
          lastSuccessfulLatencyMs: lastSuccessful != null
              ? (checkResult.latencyMs ?? currentStat.latencyMs)
              : null,
          consecutiveFailures: consecutiveFailures,
          consecutiveSuccesses: consecutiveSuccesses,
          lastFailureReason: checkResult.errorMessage,
          statusChangedAt: checkTime,
          hasInternet: checkResult.isSuccess,
          failureThreshold: _config.failureThreshold,
        );
        await _monitoringRepo.saveDeviceStatus(gwDeviceStatus);
        if (!_statusUpdateController.isClosed) {
          _statusUpdateController.add(gwDeviceStatus);
        }
      }
    } catch (e, st) {
      _unexpectedExceptionCount++;
      _logDiagnostic(
        'Unexpected error checking factory gateway ${factory.id} ($gatewayIp)',
        error: e,
        stackTrace: st,
      );
    } finally {
      _inFlightDeviceIds.remove(virtualId);
      if (!checkCompleter.isCompleted) {
        checkCompleter.complete();
      }
      _inFlightCheckCompleters.remove(virtualId);
      _concurrencyLimiter.release();
    }
  }

  Future<void> _runCheckForInfraDevice(UniFiDeviceEntity infra) async {
    final virtualId = 10000 + infra.id;
    final checkCompleter = Completer<void>();
    _inFlightCheckCompleters[virtualId] = checkCompleter;
    await _concurrencyLimiter.acquire();
    try {
      _inFlightDeviceIds.add(virtualId);
      _lastCheckTimestamps[virtualId] = DateTime.now();
      _totalChecksExecuted++;

      final pingRes = await _pingChecker.checkPing(
        deviceId: virtualId,
        targetIp: infra.ip,
        timeout: Duration(seconds: _config.timeoutSeconds),
      );

      final checkResult = CheckResult(
        deviceId: virtualId,
        assetId: 'infra_${infra.id}',
        factoryId: infra.factoryId,
        targetIp: infra.ip,
        checkType: CheckType.icmp,
        isSuccess: pingRes.isSuccess,
        latencyMs: pingRes.latencyMs,
        packetLossPercent: pingRes.packetLossPercent,
        errorMessage: pingRes.errorMessage,
        failureReason: pingRes.failureReason,
        timestamp: DateTime.now(),
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
      if (!checkCompleter.isCompleted) {
        checkCompleter.complete();
      }
      _inFlightCheckCompleters.remove(virtualId);
      _concurrencyLimiter.release();
    }
  }

  Future<void> _runCheckForDevice(DeviceEntity device) async {
    final checkCompleter = Completer<void>();
    _inFlightCheckCompleters[device.id] = checkCompleter;
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
      if (!checkCompleter.isCompleted) {
        checkCompleter.complete();
      }
      _inFlightCheckCompleters.remove(device.id);
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
    if (!_configUpdateController.isClosed) {
      _configUpdateController.close();
    }
  }
}

class _MonitoringTarget {
  final int id;
  final DeviceEntity? device;
  final UniFiDeviceEntity? infra;
  final FactoryEntity? factory;

  _MonitoringTarget.device(this.device)
    : id = device!.id,
      infra = null,
      factory = null;

  _MonitoringTarget.infra(this.infra)
    : id = 10000 + infra!.id,
      device = null,
      factory = null;

  _MonitoringTarget.gateway(this.factory, this.id)
    : device = null,
      infra = null;

  bool get isInfra => infra != null;
  bool get isGateway => factory != null;
}

/// Asynchronous counting semaphore to strictly bound concurrent checks
/// across all cycles, forced executions, and asset types.
class AsyncSemaphore {
  int _maxPermits;
  int _activeCount = 0;
  final List<Completer<void>> _waiters = [];

  AsyncSemaphore(int initialPermits)
    : _maxPermits = initialPermits > 0 ? initialPermits : 1;

  int get maxPermits => _maxPermits;
  int get activeCount => _activeCount;
  int get waitingCount => _waiters.length;

  void updatePermits(int newPermits) {
    _maxPermits = newPermits > 0 ? newPermits : 1;
    _drain();
  }

  Future<void> acquire() {
    if (_activeCount < _maxPermits) {
      _activeCount++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    _activeCount--;
    if (_activeCount < 0) {
      _activeCount = 0;
    }
    _drain();
  }

  void _drain() {
    while (_activeCount < _maxPermits && _waiters.isNotEmpty) {
      _activeCount++;
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
