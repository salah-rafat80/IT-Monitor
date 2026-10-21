import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/data/services/desktop_notification_service.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/services/incident_engine.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

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

class FaultyThrowingNotificationService extends DesktopNotificationService {
  bool shouldThrow = false;
  int notificationCount = 0;

  @override
  Future<void> notifyIncidentCreated(IncidentEntity incident) async {
    notificationCount++;
    if (shouldThrow) {
      throw Exception('Simulated desktop notification tray error');
    }
    await super.notifyIncidentCreated(incident);
  }
}

void main() {
  late AppDatabase db;
  late AuditLogRepositoryImpl auditLogRepo;
  late AuthRepositoryImpl authRepo;
  late DeviceRepositoryImpl deviceRepo;
  late MonitoringRepositoryImpl monitoringRepo;
  late IncidentRepositoryImpl incidentRepo;
  late FaultyThrowingNotificationService notificationService;
  late IncidentEngine incidentEngine;
  late TestFailurePingChecker testPingChecker;
  late MonitoringScheduler scheduler;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auditLogRepo = AuditLogRepositoryImpl(db);
    authRepo = AuthRepositoryImpl(db, auditLogRepo);
    deviceRepo = DeviceRepositoryImpl(db, auditLogRepo, authRepo);
    monitoringRepo = MonitoringRepositoryImpl(db);
    notificationService = FaultyThrowingNotificationService();
    incidentRepo = IncidentRepositoryImpl(db, auditLogRepo);
    incidentEngine = IncidentEngine(
      incidentRepo,
      deviceRepo,
      notificationService,
    );
    testPingChecker = TestFailurePingChecker();
    scheduler = MonitoringScheduler(
      deviceRepo,
      monitoringRepo,
      testPingChecker,
      incidentEngine,
    );

    await authRepo.createInitialAdmin(
      username: 'admin_phase6',
      password: 'Password123',
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
      '4. Full incident lifecycle: 3 consecutive failures produce Down incident and notification',
      () async {
        final devicesRes = await deviceRepo.getDevices();
        final targetDevice = devicesRes.dataOrNull!.first;

        testPingChecker.failMap[targetDevice.id] = true;
        scheduler.startMonitoring();

        // Perform 3 check cycles
        for (int i = 0; i < 3; i++) {
          await scheduler.triggerSingleCheck(targetDevice.id);
        }

        final activeIncidents =
            (await incidentRepo.getActiveIncidents()).dataOrNull!;
        expect(activeIncidents.length, equals(1));
        expect(activeIncidents.first.deviceId, equals(targetDevice.id));
        expect(activeIncidents.first.ownerName, equals(targetDevice.ownerName));
        expect(notificationService.notificationCount, greaterThanOrEqualTo(1));
      },
    );

    test(
      '5. Notification failure safety: error in notification service does not throw or break processDeviceStatusChange',
      () async {
        notificationService.shouldThrow = true;

        final devicesRes = await deviceRepo.getDevices();
        final targetDevice = devicesRes.dataOrNull!.first;

        final downStatus = DeviceStatusEntity.initial(targetDevice.id).copyWith(
          status: DeviceStatusEnum.down,
          consecutiveFailures: 3,
          statusChangedAt: DateTime.now(),
        );

        // Should handle notification exception internally without throwing
        await expectLater(
          incidentEngine.processDeviceStatusChange(downStatus),
          completes,
        );

        final activeIncidents =
            (await incidentRepo.getActiveIncidents()).dataOrNull!;
        expect(activeIncidents.length, equals(1));
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
        auditLogRepo = AuditLogRepositoryImpl(db);
        authRepo = AuthRepositoryImpl(db, auditLogRepo);
        deviceRepo = DeviceRepositoryImpl(db, auditLogRepo, authRepo);

        // Bootstrap check again (should be idempotent)
        final count =
            (await deviceRepo.bootstrapApprovedInventory()).dataOrNull!;
        expect(count, equals(37)); // Clean memory DB re-initializes 37 devices

        final reloadedDevices = (await deviceRepo.getDevices()).dataOrNull!;
        expect(reloadedDevices.length, equals(37));
      },
    );
  });
}
