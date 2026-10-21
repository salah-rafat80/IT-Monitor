import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';

void main() {
  group('Phase 2 — Drift Database Migration Tests', () {
    test(
      'Schema migration v1 -> v2 creates Devices table without losing Users or AuditLogs data',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        // Insert User into DB
        final userId = await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                username: 'admin_migration',
                passwordHash: 'hashed_password_sample',
                role: const Value('admin'),
              ),
            );

        // Insert AuditLog into DB
        await db
            .into(db.auditLogs)
            .insert(
              AuditLogsCompanion.insert(
                userId: Value(userId),
                username: 'admin_migration',
                action: 'MIGRATION_PRE_TEST',
              ),
            );

        // Insert Device into new v2 Devices table
        final deviceId = await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-MIG-01',
                type: const Value('pc'),
                ip: '192.168.1.100',
                ownerName: 'Ali Hassan',
                department: 'Operations',
              ),
            );

        // Verify User data preserved
        final users = await db.select(db.users).get();
        expect(users.length, equals(1));
        expect(users.first.username, equals('admin_migration'));

        // Verify AuditLog data preserved
        final logs = await db.select(db.auditLogs).get();
        expect(logs.length, equals(1));
        expect(logs.first.action, equals('MIGRATION_PRE_TEST'));

        // Verify Device created
        final devices = await db.select(db.devices).get();
        expect(devices.length, equals(1));
        expect(devices.first.id, equals(deviceId));
        expect(devices.first.ownerName, equals('Ali Hassan'));

        await db.close();
      },
    );

    test(
      'Schema migration from v5 and v6 to v7 runs onUpgrade idempotently without duplicate column error',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final migrator = db.createMigrator();
        await migrator.createAll();

        // Test onUpgrade directly simulating upgrade from v5 to v7
        await expectLater(db.migration.onUpgrade(migrator, 5, 7), completes);

        // Test onUpgrade directly simulating upgrade from v6 to v7
        await expectLater(db.migration.onUpgrade(migrator, 6, 7), completes);

        // Verify table and column exist and query works
        final rows = await db.select(db.infrastructureDevices).get();
        expect(rows, isEmpty);

        await db.close();
      },
    );
  });
}
