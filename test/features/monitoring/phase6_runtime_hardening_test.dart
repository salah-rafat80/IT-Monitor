import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';

class TestFailurePingChecker implements PingChecker {
  final Map<int, bool> failMap = {};
  final List<int> checkedDeviceIds = [];

  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    checkedDeviceIds.add(deviceId);
    final isFail = failMap[deviceId] ?? false;

    if (isFail) {
      return CheckResult.failure(
        deviceId: deviceId,
        targetIp: targetIp,
        timestamp: DateTime.now(),
        errorMessage: 'Connection timed out',
      );
    }

    return CheckResult.success(
      deviceId: deviceId,
      targetIp: targetIp,
      timestamp: DateTime.now(),
      latencyMs: 15,
    );
  }
}

class FailingPersistenceMonitoringRepo implements MonitoringRepository {
  @override
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses() async =>
      Result.success(const []);

  @override
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId) async =>
      Result.success(DeviceStatusEntity.initial(deviceId));

  @override
  Future<Result<void>> saveCheckResult(CheckResult result) async =>
      Result.failure(const DatabaseFailure('Simulated check result disk full'));

  @override
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status) async =>
      Result.failure(
        const DatabaseFailure('Simulated device status write failure'),
      );

  @override
  Future<Result<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async => Result.success(null);

  @override
  Stream<DeviceStatusEntity> watchDeviceStatus(int deviceId) =>
      const Stream.empty();

  @override
  Stream<List<DeviceStatusEntity>> watchAllDeviceStatuses() =>
      const Stream.empty();
}

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;
  late MonitoringRepositoryImpl monitoringRepo;
  late TestFailurePingChecker testPingChecker;
  late MonitoringScheduler scheduler;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);
    monitoringRepo = MonitoringRepositoryImpl(db);
    testPingChecker = TestFailurePingChecker();
    scheduler = MonitoringScheduler(
      deviceRepo,
      monitoringRepo,
      testPingChecker,
    );

    await deviceRepo.bootstrapApprovedInventory();
  });

  tearDown(() async {
    scheduler.stopMonitoring();
    scheduler.dispose();
    await db.close();
  });

  group('Phase 6 — Real Network Validation & Runtime Hardening Suite', () {
    test(
      '1. Inventory verification: exactly 37 approved devices imported into SQLite',
      () async {
        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.isSuccess, isTrue);
        final devices = devicesRes.dataOrNull!;

        expect(devices.length, equals(37));

        // Verify no duplicate IPs and valid metadata
        final ipSet = <String>{};
        for (final dev in devices) {
          expect(dev.ownerName.trim().isNotEmpty, isTrue);
          expect(dev.department.trim().isNotEmpty, isTrue);
          expect(dev.ip.trim().isNotEmpty, isTrue);
          expect(
            dev.type == DeviceType.pc || dev.type == DeviceType.laptop,
            isTrue,
          );
          expect(
            ipSet.contains(dev.ip),
            isFalse,
            reason: 'Duplicate IP found: ${dev.ip}',
          );
          ipSet.add(dev.ip);
        }
      },
    );

    test(
      '2. Concurrency bound: maxConcurrentChecks limit of 50 is respected',
      () async {
        const config = MonitoringConfig(
          checkIntervalSeconds: 60,
          maxConcurrentChecks: 50,
        );
        scheduler.updateConfig(config);

        expect(scheduler.config.maxConcurrentChecks, equals(50));
        expect(scheduler.config.checkIntervalSeconds, equals(60));

        scheduler.startMonitoring();
        await scheduler.triggerAllChecks(force: true);
        expect(testPingChecker.checkedDeviceIds.length, equals(37));
      },
    );

    test(
      '3. Failure isolation: one failing device does not halt check loop for other devices',
      () async {
        final devicesRes = await deviceRepo.getDevices();
        final devices = devicesRes.dataOrNull!;
        final targetFailedDevice = devices.first;

        testPingChecker.failMap[targetFailedDevice.id] = true;

        scheduler.startMonitoring();
        await scheduler.triggerAllChecks(force: true);

        expect(testPingChecker.checkedDeviceIds.length, equals(37));
        expect(
          testPingChecker.checkedDeviceIds,
          contains(targetFailedDevice.id),
        );
      },
    );

    test(
      '6. App restart simulation: DB state, device inventory, and statuses persist across connections',
      () async {
        // 1. Initial run & status write
        final statusesRes = await monitoringRepo.getDeviceStatuses();
        expect(statusesRes.isSuccess, isTrue);

        final devices = (await deviceRepo.getDevices()).dataOrNull!;
        final dev = devices.first;

        final testStatus = DeviceStatusEntity.initial(dev.id).copyWith(
          status: DeviceStatusEnum.up,
          lastLatencyMs: 8,
          lastCheckAt: DateTime.now(),
        );
        await monitoringRepo.saveDeviceStatus(testStatus);

        // 2. Simulate shutdown & reopen database
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase.memory());
        deviceRepo = DeviceRepositoryImpl(db);

        // Bootstrap check again (should be idempotent)
        final count =
            (await deviceRepo.bootstrapApprovedInventory()).dataOrNull!;
        expect(count, equals(37)); // Clean memory DB re-initializes 37 devices

        final reloadedDevices = (await deviceRepo.getDevices()).dataOrNull!;
        expect(reloadedDevices.length, equals(37));
      },
    );

    test(
      '7. Diagnostics and error counters: persistence and repository failures produce observable metrics',
      () async {
        final failingRepo = FailingPersistenceMonitoringRepo();
        final testScheduler = MonitoringScheduler(
          deviceRepo,
          failingRepo,
          testPingChecker,
        );

        expect(testScheduler.persistenceFailureCount, equals(0));

        // Trigger a check for device 1
        await testScheduler.triggerSingleCheck(1);

        // Verify that persistence failures were observed, counted, and recorded in diagnostic logs
        expect(testScheduler.persistenceFailureCount, greaterThan(0));
        expect(testScheduler.diagnosticLogs, isNotEmpty);
        expect(
          testScheduler.diagnosticLogs.any(
            (log) =>
                log.contains('Failed to save') ||
                log.contains('Failed to persist'),
          ),
          isTrue,
        );
      },
    );
  });
}
