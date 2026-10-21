import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

void main() {
  group('SQLite Unique-IP Enforcement & Safe Migration Integration Tests', () {
    test(
      '1. Persistence boundary rejects duplicate IP and returns ValidationFailure',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final auditRepo = AuditLogRepositoryImpl(db);
        final authRepo = AuthRepositoryImpl(db, auditRepo);
        await authRepo.createInitialAdmin(
          username: 'admin_test',
          password: 'Password123',
        );
        final repo = DeviceRepositoryImpl(db, auditRepo, authRepo);

        // First device insert succeeds
        final dev1 = DeviceEntity(
          id: 0,
          name: 'PC-FIN-01',
          type: DeviceType.pc,
          ip: '192.168.1.10',
          ownerName: 'Alice',
          department: 'Finance',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final res1 = await repo.addDevice(dev1);
        expect(res1.isSuccess, isTrue);

        // Second device with exact duplicate IP must fail
        final dev2 = DeviceEntity(
          id: 0,
          name: 'PC-FIN-02',
          type: DeviceType.pc,
          ip: '192.168.1.10',
          ownerName: 'Bob',
          department: 'Finance',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final res2 = await repo.addDevice(dev2);
        expect(res2.isSuccess, isFalse);
        expect(res2.failureOrNull, isA<ValidationFailure>());
        expect(
          res2.failureOrNull?.message,
          anyOf(contains('already exists'), contains('already assigned')),
        );

        // Verify existing valid asset was NEVER modified or deleted
        final allDevicesRes = await repo.getDevices();
        expect(allDevicesRes.isSuccess, isTrue);
        final devices = allDevicesRes.dataOrNull!;
        expect(devices.length, equals(1));
        expect(devices.first.name, equals('PC-FIN-01'));
        expect(devices.first.ownerName, equals('Alice'));

        await db.close();
      },
    );

    test(
      '2. Canonical IP equivalence cannot bypass unique validation (leading zeros, spaces)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final auditRepo = AuditLogRepositoryImpl(db);
        final authRepo = AuthRepositoryImpl(db, auditRepo);
        await authRepo.createInitialAdmin(
          username: 'admin_test',
          password: 'Password123',
        );
        final repo = DeviceRepositoryImpl(db, auditRepo, authRepo);

        final dev1 = DeviceEntity(
          id: 0,
          name: 'PC-HR-01',
          type: DeviceType.pc,
          ip: '192.168.1.25',
          ownerName: 'Charlie',
          department: 'HR',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final res1 = await repo.addDevice(dev1);
        expect(res1.isSuccess, isTrue);

        // Canonical equivalent with leading zeros and surrounding whitespace: ' 192.168.01.025 '
        final devEquivalent = DeviceEntity(
          id: 0,
          name: 'PC-HR-02',
          type: DeviceType.pc,
          ip: ' 192.168.01.025 ',
          ownerName: 'Dave',
          department: 'HR',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final res2 = await repo.addDevice(devEquivalent);
        expect(res2.isSuccess, isFalse);
        expect(res2.failureOrNull, isA<ValidationFailure>());
        expect(
          res2.failureOrNull?.message,
          anyOf(contains('already exists'), contains('already assigned')),
        );

        await db.close();
      },
    );

    test(
      '3. Blank, whitespace, and malformed IPs are rejected without bypassing uniqueness',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final auditRepo = AuditLogRepositoryImpl(db);
        final authRepo = AuthRepositoryImpl(db, auditRepo);
        await authRepo.createInitialAdmin(
          username: 'admin_test',
          password: 'Password123',
        );
        final repo = DeviceRepositoryImpl(db, auditRepo, authRepo);

        final invalidIps = [
          '',
          '   ',
          'not-an-ip',
          '256.1.1.1',
          '192.168.1',
          '192.168.1.1.1',
          'abc.def.ghi.jkl',
        ];

        for (final badIp in invalidIps) {
          final badDevice = DeviceEntity(
            id: 0,
            name: 'PC-BAD',
            type: DeviceType.pc,
            ip: badIp,
            ownerName: 'Bad User',
            department: 'Testing',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          );
          final res = await repo.addDevice(badDevice);
          expect(
            res.isSuccess,
            isFalse,
            reason: 'Should reject invalid IP "$badIp"',
          );
          expect(res.failureOrNull, isA<ValidationFailure>());
        }

        // Database must remain completely clean
        final count = await (db.select(db.devices)).get();
        expect(count.isEmpty, isTrue);

        await db.close();
      },
    );

    test(
      '4. Concurrent inserts for the same IP: exactly one succeeds, one rejected',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final auditRepo = AuditLogRepositoryImpl(db);
        final authRepo = AuthRepositoryImpl(db, auditRepo);
        await authRepo.createInitialAdmin(
          username: 'admin_test',
          password: 'Password123',
        );
        final repo = DeviceRepositoryImpl(db, auditRepo, authRepo);

        final devA = DeviceEntity(
          id: 0,
          name: 'PC-CONCURRENT-A',
          type: DeviceType.pc,
          ip: '192.168.1.88',
          ownerName: 'Racer A',
          department: 'IT',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );
        final devB = DeviceEntity(
          id: 0,
          name: 'PC-CONCURRENT-B',
          type: DeviceType.pc,
          ip: '192.168.1.88',
          ownerName: 'Racer B',
          department: 'IT',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        );

        // Fire both simultaneously
        final results = await Future.wait<Result<DeviceEntity>>([
          repo.addDevice(devA),
          repo.addDevice(devB),
        ]);

        final successCount = results.where((r) => r.isSuccess).length;
        final failureCount = results.where((r) => !r.isSuccess).length;

        expect(successCount, equals(1));
        expect(failureCount, equals(1));

        // DB must contain exactly 1 record
        final allDevices = await (db.select(db.devices)).get();
        expect(allDevices.length, equals(1));
        expect(allDevices.first.ip, equals('192.168.1.88'));

        await db.close();
      },
    );

    test(
      '5. Safe schema migration v9 -> v10 preserves duplicate records, clears conflict IP to unassigned without fabricated strings, and disables monitoring',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final migrator = db.createMigrator();
        await migrator.createAll();

        // Drop unique index to simulate pre-v10 legacy state
        await db.customStatement('DROP INDEX IF EXISTS idx_devices_ip;');

        // Insert legacy data WITH duplicate IP in devices
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await db.customStatement('''
          INSERT INTO devices (id, name, ip, owner_name, department, created_at, is_monitored, is_enabled)
          VALUES (1, 'Legacy PC A', '192.168.1.100', 'Owner 1', 'Finance', $nowMs, 1, 1);
        ''');
        await db.customStatement('''
          INSERT INTO devices (id, name, ip, owner_name, department, created_at, is_monitored, is_enabled)
          VALUES (2, 'Legacy PC B', '192.168.1.100', 'Owner 2', 'Finance', $nowMs, 1, 1);
        ''');

        // Execute onUpgrade from v9 to v10
        await db.migration.onUpgrade(migrator, 9, 10);

        // Query devices: both records MUST be preserved without silent deletion
        final devices = await (db.select(db.devices)).get();
        expect(devices.length, equals(2));

        // First device kept original IP and monitoring enabled
        expect(devices[0].ip, equals('192.168.1.100'));
        expect(devices[0].isMonitored, isTrue);

        // Second device: NO fabricated '#conflict_' string! Represented as clean unassigned ''
        expect(devices[1].ip, equals(''));
        expect(devices[1].isMonitored, isFalse);
        expect(devices[1].isEnabled, isFalse);
        expect(devices[1].notes, contains('MIGRATION_CONFLICT'));
        expect(devices[1].notes, contains('192.168.1.100'));

        // Partial unique index was successfully established without crash
        final idxCheck = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='index' AND name='idx_devices_ip';",
            )
            .get();
        expect(idxCheck.length, equals(1));
        expect(
          idxCheck.first.read<String>('sql'),
          contains('WHERE ip != \'\''),
        );

        await db.close();
      },
    );

    test(
      '6. Migration normalizes leading zeros/whitespace, clears malformed/blank IPs, and preserves foreign key relationships',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final migrator = db.createMigrator();
        await migrator.createAll();
        await db.customStatement('DROP INDEX IF EXISTS idx_devices_ip;');

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        // Device 1: leading zeros and whitespace
        await db.customStatement('''
          INSERT INTO devices (id, name, ip, owner_name, department, created_at)
          VALUES (10, 'Leading Zero PC', '  192.168.027.005  ', 'Alice', 'Engineering', $nowMs);
        ''');
        // Device 2: blank IP
        await db.customStatement('''
          INSERT INTO devices (id, name, ip, owner_name, department, created_at)
          VALUES (11, 'Blank IP PC', '   ', 'Bob', 'HR', $nowMs);
        ''');
        // Device 3: malformed IP
        await db.customStatement('''
          INSERT INTO devices (id, name, ip, owner_name, department, created_at)
          VALUES (12, 'Malformed IP PC', 'not-a-valid-ip', 'Charlie', 'Legal', $nowMs);
        ''');

        // Historical check result referencing Device 12
        await db.customStatement('''
          INSERT INTO check_results (id, device_id, target_ip, is_success, timestamp)
          VALUES (101, 12, 'not-a-valid-ip', 0, $nowMs);
        ''');

        // Incident referencing Device 10
        await db.customStatement('''
          INSERT INTO incidents (id, device_id, device_name, owner_name, department, device_ip, incident_type, status, started_at)
          VALUES (201, 10, 'Leading Zero PC', 'Alice', 'Engineering', '192.168.27.5', 'device_down', 'active', $nowMs);
        ''');

        // Run migration
        await db.migration.onUpgrade(migrator, 9, 10);

        final devices = await (db.select(
          db.devices,
        )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
        expect(devices.length, equals(3));

        // Device 10: normalized to canonical 192.168.27.5
        expect(devices[0].id, equals(10));
        expect(devices[0].ip, equals('192.168.27.5'));

        // Device 11: blank IP cleared to '', monitoring disabled
        expect(devices[1].id, equals(11));
        expect(devices[1].ip, equals(''));
        expect(devices[1].isMonitored, isFalse);
        expect(devices[1].notes, contains('MIGRATION_UNASSIGNED_IP'));

        // Device 12: malformed IP cleared to '', monitoring disabled
        expect(devices[2].id, equals(12));
        expect(devices[2].ip, equals(''));
        expect(devices[2].isMonitored, isFalse);
        expect(devices[2].notes, contains('MIGRATION_MALFORMED_IP'));

        // Check history and incident relationships are preserved intact
        final checks = await db
            .customSelect("SELECT * FROM check_results WHERE id = 101;")
            .get();
        expect(checks.length, equals(1));
        expect(checks.first.read<int>('device_id'), equals(12));

        final incs = await db
            .customSelect("SELECT * FROM incidents WHERE id = 201;")
            .get();
        expect(incs.length, equals(1));
        expect(incs.first.read<int>('device_id'), equals(10));

        await db.close();
      },
    );

    test(
      '7. Cross-table IP collision with infrastructure device clears inventory IP to unassigned',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final migrator = db.createMigrator();
        await migrator.createAll();
        await db.customStatement('DROP INDEX IF EXISTS idx_devices_ip;');

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        // Authoritative UniFi Gateway in infrastructure_devices on 192.168.1.1
        await db.customStatement('''
          INSERT INTO infrastructure_devices (id, name, ip, role, is_enabled, created_at)
          VALUES (1, 'UniFi Dream Machine Pro', '192.168.1.1', 'gateway', 1, $nowMs);
        ''');

        // Conflicting inventory row mistakenly given 192.168.1.1 in legacy database
        await db.customStatement('''
          INSERT INTO devices (id, name, ip, owner_name, department, created_at, is_monitored, is_enabled)
          VALUES (50, 'Duplicate Gateway Entry', '192.168.1.1', 'IT Admin', 'IT', $nowMs, 1, 1);
        ''');

        // Run migration
        await db.migration.onUpgrade(migrator, 9, 10);

        final dev = await (db.select(
          db.devices,
        )..where((t) => t.id.equals(50))).getSingle();
        // Inventory row IP is cleared to unassigned; monitoring disabled
        expect(dev.ip, equals(''));
        expect(dev.isMonitored, isFalse);
        expect(dev.isEnabled, isFalse);
        expect(dev.notes, contains('MIGRATION_CROSS_TABLE_CONFLICT'));
        expect(dev.notes, contains('UniFi Dream Machine Pro'));

        await db.close();
      },
    );

    test('8. Interrupted and retried migration is idempotent and safe', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final migrator = db.createMigrator();
      await migrator.createAll();

      // Run migration twice in succession
      await db.migration.onUpgrade(migrator, 9, 10);
      await db.migration.onUpgrade(migrator, 9, 10);

      final idxCheck = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_devices_ip';",
          )
          .get();
      expect(idxCheck.length, equals(1));

      await db.close();
    });
  });
}
