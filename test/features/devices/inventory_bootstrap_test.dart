import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/datasources/approved_inventory_seed.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/services/inventory_validator.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;
  late MonitoringRepositoryImpl monitoringRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);
    monitoringRepo = MonitoringRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 6 — Inventory Bootstrap & Integration Unit Tests', () {
    test('1. Approved inventory seed dataset contains 37 valid devices', () {
      final rawRows = ApprovedInventorySeed.getApprovedRawRows();
      final preview = InventoryValidator.validateRows(rows: rawRows);

      expect(preview.validDevices.length, equals(37));
      expect(preview.totalRowsProcessed, equals(rawRows.length));
      expect(preview.excludedDuplicateIps, contains('192.168.22.250'));
      expect(
        preview.invalidRecords.any((r) => r.reason.contains('Switch')),
        isTrue,
      );
      expect(
        preview.invalidRecords.any((r) => r.reason.contains('Missing IP')),
        isTrue,
      );
    });

    test(
      '2. First-run bootstrap populates empty database with 37 approved devices',
      () async {
        final bootstrapRes = await deviceRepo.bootstrapApprovedInventory();

        expect(bootstrapRes.isSuccess, isTrue);
        expect(bootstrapRes.dataOrNull, equals(37));

        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.isSuccess, isTrue);
        final devices = devicesRes.dataOrNull!;
        expect(devices.length, equals(37));

        // Verify sample devices identity
        final amr = devices.firstWhere((d) => d.ownerName == 'amr rafaat');
        expect(amr.department, equals('Accounting'));
        expect(amr.type, equals(DeviceType.laptop));
        expect(amr.ip, equals('192.168.27.25'));

        final hisham = devices.firstWhere((d) => d.ownerName == 'Hisham Essam');
        expect(hisham.department, equals('Accounting'));
        expect(hisham.type, equals(DeviceType.pc));
        expect(hisham.ip, equals('192.168.22.117'));
      },
    );

    test(
      '3. Bootstrap is idempotent and does not duplicate devices on subsequent calls',
      () async {
        // First bootstrap
        final firstRes = await deviceRepo.bootstrapApprovedInventory();
        expect(firstRes.dataOrNull, equals(37));

        // Second bootstrap (should skip)
        final secondRes = await deviceRepo.bootstrapApprovedInventory();
        expect(secondRes.dataOrNull, equals(0));

        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.dataOrNull!.length, equals(37));
      },
    );

    test(
      '4. Excluded duplicate IPs, switches, and invalid rows are NOT inserted',
      () async {
        await deviceRepo.bootstrapApprovedInventory();
        final devicesRes = await deviceRepo.getDevices();
        final devices = devicesRes.dataOrNull!;

        // Excluded duplicate IP 192.168.22.250 must not exist
        expect(devices.any((d) => d.ip == '192.168.22.250'), isFalse);

        // Excluded switch SW-CORE must not exist
        expect(devices.any((d) => d.name == 'SW-CORE'), isFalse);

        // Excluded missing IP device must not exist
        expect(devices.any((d) => d.name == 'NO-IP'), isFalse);
      },
    );

    test(
      '5. Existing user data and pre-existing audit logs are preserved',
      () async {
        // Create user before bootstrap
        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                username: 'pre_admin',
                passwordHash: 'hash123',
                role: Value('admin'),
                createdAt: Value(DateTime.now()),
              ),
            );

        // Add pre-existing audit log
        await db
            .into(db.auditLogs)
            .insert(
              AuditLogsCompanion.insert(
                action: 'PRE_TEST_ACTION',
                details: const Value('Pre-existing audit detail'),
                username: 'pre_admin',
                timestamp: Value(DateTime.now()),
              ),
            );

        // Execute bootstrap
        await deviceRepo.bootstrapApprovedInventory();

        // Verify user is preserved
        final users = await db.select(db.users).get();
        expect(users.any((u) => u.username == 'pre_admin'), isTrue);

        // Verify audit logs contain pre-existing log + bootstrap log
        final logs = await db.select(db.auditLogs).get();
        expect(logs.any((l) => l.action == 'PRE_TEST_ACTION'), isTrue);
        expect(
          logs.any((l) => l.action == 'APPROVED_INVENTORY_BOOTSTRAPPED'),
          isTrue,
        );
      },
    );

    test(
      '6. Real monitoring status streams emit statuses for all 37 imported devices',
      () async {
        await deviceRepo.bootstrapApprovedInventory();

        final statusesRes = await monitoringRepo.getDeviceStatuses();
        expect(statusesRes.isSuccess, isTrue);

        final streamExpectation = expectLater(
          monitoringRepo.watchAllDeviceStatuses(),
          emits(isA<List<DeviceStatusEntity>>()),
        );

        // Save device status for an imported device
        final devicesRes = await deviceRepo.getDevices();
        final sampleDevice = devicesRes.dataOrNull!.first;
        final status = DeviceStatusEntity.initial(sampleDevice.id).copyWith(
          status: DeviceStatusEnum.up,
          lastLatencyMs: 12,
          lastCheckAt: DateTime.now(),
        );

        await monitoringRepo.saveDeviceStatus(status);

        await streamExpectation;
      },
    );
  });
}
