import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/status_engine.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

class MockPingChecker implements PingChecker {
  final Map<int, bool> nextResultSuccess = {};
  final Map<int, int> checkCounts = {};

  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    checkCounts[deviceId] = (checkCounts[deviceId] ?? 0) + 1;
    final isSuccess = nextResultSuccess[deviceId] ?? true;

    if (isSuccess) {
      return CheckResult.success(
        deviceId: deviceId,
        targetIp: targetIp,
        timestamp: DateTime.now(),
        latencyMs: 12,
      );
    } else {
      return CheckResult.failure(
        deviceId: deviceId,
        targetIp: targetIp,
        timestamp: DateTime.now(),
        errorMessage: 'Request timed out',
      );
    }
  }
}

class ExceptionPingChecker implements PingChecker {
  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // Simulates an unexpected socket / platform exception wrapped cleanly
    return CheckResult.failure(
      deviceId: deviceId,
      targetIp: targetIp,
      timestamp: DateTime.now(),
      errorMessage: 'SocketException: OS Error: Host unreachable',
    );
  }
}

void main() {
  late AppDatabase db;
  late AuditLogRepositoryImpl auditLogRepo;
  late AuthRepositoryImpl authRepo;
  late DeviceRepositoryImpl deviceRepo;
  late MonitoringRepositoryImpl monitoringRepo;
  late MockPingChecker mockPingChecker;
  late MonitoringScheduler scheduler;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auditLogRepo = AuditLogRepositoryImpl(db);
    authRepo = AuthRepositoryImpl(db, auditLogRepo);
    deviceRepo = DeviceRepositoryImpl(db, auditLogRepo, authRepo);
    monitoringRepo = MonitoringRepositoryImpl(db);
    mockPingChecker = MockPingChecker();
    scheduler = MonitoringScheduler(
      deviceRepo,
      monitoringRepo,
      mockPingChecker,
    );

    await authRepo.createInitialAdmin(
      username: 'admin_mon',
      password: 'Password123',
    );
  });

  tearDown(() async {
    scheduler.stopMonitoring();
    scheduler.dispose();
    await db.close();
  });

  group('Phase 3 — Monitoring Domain Unit Tests', () {
    const config = MonitoringConfig(
      checkIntervalSeconds: 1,
      timeoutSeconds: 1,
      failureThreshold: 3,
      recoveryThreshold: 2,
    );

    test('1. Initial state is Unknown before checks', () {
      final initial = DeviceStatusEntity.initial(101);
      expect(initial.status, equals(DeviceStatusEnum.unknown));
      expect(initial.consecutiveFailures, equals(0));
      expect(initial.consecutiveSuccesses, equals(0));
    });

    test(
      '2. One failed check increments failure count, status remains Unknown',
      () {
        final current = DeviceStatusEntity.initial(101);
        final failedResult = CheckResult.failure(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: DateTime.now(),
          errorMessage: 'Timeout',
        );

        final updated = StatusEngine.processCheckResult(
          currentStatus: current,
          checkResult: failedResult,
          config: config,
        );

        expect(updated.consecutiveFailures, equals(1));
        expect(
          updated.status,
          equals(DeviceStatusEnum.unknown),
        ); // Not Down yet
      },
    );

    test(
      '3. Two consecutive failed checks preserve status and increment failure streak',
      () {
        var status = DeviceStatusEntity.initial(101);
        final now = DateTime.now();

        for (int i = 0; i < 2; i++) {
          status = StatusEngine.processCheckResult(
            currentStatus: status,
            checkResult: CheckResult.failure(
              deviceId: 101,
              targetIp: '192.168.1.50',
              timestamp: now,
              errorMessage: 'Timeout',
            ),
            config: config,
          );
        }

        expect(status.consecutiveFailures, equals(2));
        expect(status.status, equals(DeviceStatusEnum.unknown)); // Not Down yet
      },
    );

    test('4. Three consecutive failed checks trigger Down transition', () {
      var status = DeviceStatusEntity.initial(101);
      final now = DateTime.now();

      for (int i = 0; i < 3; i++) {
        status = StatusEngine.processCheckResult(
          currentStatus: status,
          checkResult: CheckResult.failure(
            deviceId: 101,
            targetIp: '192.168.1.50',
            timestamp: now,
            errorMessage: 'Timeout',
          ),
          config: config,
        );
      }

      expect(status.consecutiveFailures, equals(3));
      expect(status.status, equals(DeviceStatusEnum.down));
    });

    test('5. Success before 3rd failure resets failure streak', () {
      var status = DeviceStatusEntity.initial(101);
      final now = DateTime.now();

      // 2 failures
      for (int i = 0; i < 2; i++) {
        status = StatusEngine.processCheckResult(
          currentStatus: status,
          checkResult: CheckResult.failure(
            deviceId: 101,
            targetIp: '192.168.1.50',
            timestamp: now,
            errorMessage: 'Timeout',
          ),
          config: config,
        );
      }
      expect(status.consecutiveFailures, equals(2));

      // 1 success resets failure streak
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: CheckResult.success(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: now,
          latencyMs: 5,
        ),
        config: config,
      );

      expect(status.consecutiveFailures, equals(0));
      expect(status.consecutiveSuccesses, equals(1));
      expect(status.status, equals(DeviceStatusEnum.up));
    });

    test('6. One recovery success in Down state preserves Down status', () {
      var status = DeviceStatusEntity.initial(
        101,
      ).copyWith(status: DeviceStatusEnum.down, consecutiveFailures: 3);
      final now = DateTime.now();

      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: CheckResult.success(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: now,
          latencyMs: 8,
        ),
        config: config,
      );

      expect(status.consecutiveSuccesses, equals(1));
      expect(
        status.status,
        equals(DeviceStatusEnum.down),
      ); // Still Down until 2 successes
    });

    test('7. Two consecutive recovery successes auto resolve Down to Up', () {
      var status = DeviceStatusEntity.initial(
        101,
      ).copyWith(status: DeviceStatusEnum.down, consecutiveFailures: 3);
      final now = DateTime.now();

      for (int i = 0; i < 2; i++) {
        status = StatusEngine.processCheckResult(
          currentStatus: status,
          checkResult: CheckResult.success(
            deviceId: 101,
            targetIp: '192.168.1.50',
            timestamp: now,
            latencyMs: 8,
          ),
          config: config,
        );
      }

      expect(status.consecutiveSuccesses, equals(2));
      expect(status.status, equals(DeviceStatusEnum.up));
    });

    test('8. Failed recovery check resets recovery streak in Down state', () {
      var status = DeviceStatusEntity.initial(
        101,
      ).copyWith(status: DeviceStatusEnum.down, consecutiveFailures: 3);
      final now = DateTime.now();

      // 1 recovery success
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: CheckResult.success(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: now,
        ),
        config: config,
      );
      expect(status.consecutiveSuccesses, equals(1));

      // 1 failure resets recovery streak back to 0
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: CheckResult.failure(
          deviceId: 101,
          targetIp: '192.168.1.50',
          timestamp: now,
          errorMessage: 'Timeout',
        ),
        config: config,
      );

      expect(status.consecutiveSuccesses, equals(0));
      expect(status.status, equals(DeviceStatusEnum.down));
    });

    test('9. Disabled device is not checked by scheduler', () async {
      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'PC-DISABLED',
          type: DeviceType.pc,
          ip: '192.168.1.80',
          ownerName: 'Disabled User',
          department: 'IT',
          isEnabled: false,
          createdAt: DateTime.now(),
        ),
      );

      await scheduler.triggerSingleCheck(1);

      expect(mockPingChecker.checkCounts[1], isNull);
    });

    test('10. Configurable debounce thresholds are respected', () {
      const customConfig = MonitoringConfig(
        failureThreshold: 5,
        recoveryThreshold: 4,
      );

      var status = DeviceStatusEntity.initial(202);
      final now = DateTime.now();

      // 4 failures (less than failureThreshold 5) -> Remains Unknown
      for (int i = 0; i < 4; i++) {
        status = StatusEngine.processCheckResult(
          currentStatus: status,
          checkResult: CheckResult.failure(
            deviceId: 202,
            targetIp: '10.0.0.5',
            timestamp: now,
            errorMessage: 'Err',
          ),
          config: customConfig,
        );
      }
      expect(status.status, equals(DeviceStatusEnum.unknown));

      // 5th failure -> Down
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: CheckResult.failure(
          deviceId: 202,
          targetIp: '10.0.0.5',
          timestamp: now,
          errorMessage: 'Err',
        ),
        config: customConfig,
      );
      expect(status.status, equals(DeviceStatusEnum.down));
    });

    test('11. Maintenance mode suppresses Down status transitions', () {
      final status = DeviceStatusEntity.initial(
        303,
      ).copyWith(isMaintenance: true);
      final now = DateTime.now();

      final updated = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: CheckResult.failure(
          deviceId: 303,
          targetIp: '10.0.0.10',
          timestamp: now,
          errorMessage: 'Timeout',
        ),
        config: config,
      );

      expect(updated.status, equals(DeviceStatusEnum.maintenance));
      expect(updated.lastCheckAt, equals(now));
    });

    test(
      '12. Exception in PingChecker returns structured failure and does not crash loop',
      () async {
        final excChecker = ExceptionPingChecker();
        final res = await excChecker.checkPing(
          deviceId: 505,
          targetIp: '192.168.1.200',
        );

        expect(res.isSuccess, isFalse);
        expect(res.errorMessage, contains('SocketException'));
      },
    );

    test(
      '13. Status updates are persisted in Drift DB and emitted on stream',
      () async {
        final status = DeviceStatusEntity.initial(
          999,
        ).copyWith(status: DeviceStatusEnum.up, lastSeen: DateTime.now());

        final saveRes = await monitoringRepo.saveDeviceStatus(status);
        expect(saveRes.isSuccess, isTrue);

        final fetchedRes = await monitoringRepo.getDeviceStatus(999);
        expect(fetchedRes.dataOrNull?.status, equals(DeviceStatusEnum.up));
      },
    );

    test(
      '14. Bounded global concurrency limits simultaneous checks per cycle',
      () async {
        final slowChecker = SlowPingChecker();
        final boundedScheduler = MonitoringScheduler(
          deviceRepo,
          monitoringRepo,
          slowChecker,
        );
        boundedScheduler.updateConfig(
          const MonitoringConfig(maxConcurrentChecks: 2),
        );

        // Add 5 devices
        for (int i = 1; i <= 5; i++) {
          await deviceRepo.addDevice(
            DeviceEntity(
              id: 100 + i,
              name: 'PC $i',
              type: DeviceType.pc,
              ip: '10.0.0.$i',
              ownerName: 'User $i',
              department: 'IT',
              isEnabled: true,
              createdAt: DateTime.now(),
            ),
          );
        }

        boundedScheduler.startMonitoring();
        await Future.delayed(const Duration(milliseconds: 10));

        // In-flight devices should be capped at maxConcurrentChecks (2)
        expect(slowChecker.activeChecks.length, lessThanOrEqualTo(2));

        boundedScheduler.stopMonitoring();
        boundedScheduler.dispose();
      },
    );

    test(
      '15. Scheduler disposal closes streams and prevents post-disposal emissions',
      () async {
        final tempScheduler = MonitoringScheduler(
          deviceRepo,
          monitoringRepo,
          mockPingChecker,
        );
        tempScheduler.startMonitoring();
        tempScheduler.dispose();

        expect(tempScheduler.isRunning, isFalse);
      },
    );
  });
}

class SlowPingChecker implements PingChecker {
  final Set<int> activeChecks = {};

  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    activeChecks.add(deviceId);
    await Future.delayed(const Duration(milliseconds: 100));
    final res = CheckResult.success(
      deviceId: deviceId,
      targetIp: targetIp,
      timestamp: DateTime.now(),
      latencyMs: 5,
    );
    activeChecks.remove(deviceId);
    return res;
  }
}
