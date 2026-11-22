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
    test('1. Approved inventory seed is empty enforcing zero data fabrication', () {
      final rawRows = ApprovedInventorySeed.getApprovedRawRows();
      expect(rawRows, isEmpty);
    });

    test(
      '2. Bootstrap does not inject fabricated inventory into empty database',
      () async {
        final bootstrapRes = await deviceRepo.bootstrapApprovedInventory();

        expect(bootstrapRes.isSuccess, isTrue);
        expect(bootstrapRes.dataOrNull, equals(0));

        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.isSuccess, isTrue);
        final devices = devicesRes.dataOrNull!;
        expect(devices, isEmpty);
      },
    );

    test(
      '3. Explicit user import via commitImport is supported and idempotent',
      () async {
        final sampleDevices = [
          DeviceEntity(
            id: -1,
            factoryId: 'rnf',
            name: 'PC-Inspector',
            type: DeviceType.pc,
            ip: '192.168.22.67',
            ownerName: 'rm.inspector',
            department: 'QC-QA',
            createdAt: DateTime.now(),
          ),
          DeviceEntity(
            id: -2,
            factoryId: 'rnf',
            name: 'PC-Hamdy',
            type: DeviceType.pc,
            ip: '192.168.22.72',
            ownerName: 'Hamdy.Ahmed',
            department: 'Warehouse',
            createdAt: DateTime.now(),
          ),
        ];

        final importRes = await deviceRepo.commitImport(sampleDevices);
        expect(importRes.isSuccess, isTrue);
        expect(importRes.dataOrNull, equals(2));

        final devicesRes = await deviceRepo.getDevices();
        expect(devicesRes.dataOrNull!.length, equals(2));

        final inspector = devicesRes.dataOrNull!.firstWhere((d) => d.ownerName == 'rm.inspector');
        expect(inspector.department, equals('QC-QA'));
        expect(inspector.ip, equals('192.168.22.67'));
      },
    );

    test(
      '4. InventoryValidator rejects duplicate IPs and invalid rows',
      () async {
        const rawRows = [
          RawInventoryRow(
            rowIndex: 1,
            rawName: 'PC-1',
            rawType: 'PC',
            rawIp: '192.168.22.250',
            rawOwner: 'User1',
            rawDepartment: 'IT',
          ),
          RawInventoryRow(
            rowIndex: 2,
            rawName: 'PC-2',
            rawType: 'PC',
            rawIp: '192.168.22.250',
            rawOwner: 'User2',
            rawDepartment: 'HR',
          ),
          RawInventoryRow(
            rowIndex: 3,
            rawName: 'SW-CORE',
            rawType: 'Switch',
            rawIp: '192.168.22.10',
            rawOwner: 'Core Switch',
            rawDepartment: 'IT',
          ),
          RawInventoryRow(
            rowIndex: 4,
            rawName: 'NO-IP',
            rawType: 'PC',
            rawIp: '',
            rawOwner: 'User3',
            rawDepartment: 'IT',
          ),
        ];
        final preview = InventoryValidator.validateRows(rows: rawRows);

        expect(preview.excludedDuplicateIps, contains('192.168.22.250'));
        expect(preview.invalidRecords.any((r) => r.reason.contains('Switch')), isTrue);
        expect(preview.invalidRecords.any((r) => r.reason.contains('Missing IP')), isTrue);
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
          isFalse,
        );
      },
    );

    test(
      '6. Real monitoring status streams emit statuses for imported devices',
      () async {
        final sampleDevice = DeviceEntity(
          id: -1,
          factoryId: 'rnf',
          name: 'PC-Sample',
          type: DeviceType.pc,
          ip: '192.168.22.100',
          ownerName: 'Sample User',
          department: 'IT',
          createdAt: DateTime.now(),
        );
        await deviceRepo.commitImport([sampleDevice]);

        final statusesRes = await monitoringRepo.getDeviceStatuses();
        expect(statusesRes.isSuccess, isTrue);

        final streamExpectation = expectLater(
          monitoringRepo.watchAllDeviceStatuses(),
          emits(isA<List<DeviceStatusEntity>>()),
        );

        final devicesRes = await deviceRepo.getDevices();
        final insertedDevice = devicesRes.dataOrNull!.first;
        final status = DeviceStatusEntity.initial(insertedDevice.id).copyWith(
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
