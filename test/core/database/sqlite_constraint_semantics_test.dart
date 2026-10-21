import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Inspect exact SQLite exception properties on UNIQUE index violation',
    () async {
      final db = NativeDatabase.memory();
      await db.ensureOpen(_FakeExecutorUser());

      // Create a simple table and a unique index
      await db.runCustom(
        'CREATE TABLE items (id INTEGER PRIMARY KEY, ip TEXT);',
      );
      await db.runCustom('CREATE UNIQUE INDEX idx_items_ip ON items(ip);');

      // First insert succeeds
      await db.runCustom(
        "INSERT INTO items (id, ip) VALUES (1, '192.168.1.1');",
      );

      // Second insert with same IP must fail
      try {
        await db.runCustom(
          "INSERT INTO items (id, ip) VALUES (2, '192.168.1.1');",
        );
        fail('Expected SqliteException was not thrown');
      } catch (e) {
        expect(e, isA<SqliteException>());
        final sqlEx = e as SqliteException;
        // SQLite returns base resultCode 19 (SQLITE_CONSTRAINT)
        // and extendedResultCode 2067 (SQLITE_CONSTRAINT_UNIQUE)
        expect(sqlEx.resultCode, equals(19));
        expect(sqlEx.extendedResultCode, equals(2067));
        expect(sqlEx.message, contains('UNIQUE constraint failed'));
      }

      await db.close();
    },
  );
}

class _FakeExecutorUser extends QueryExecutorUser {
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}

  @override
  int get schemaVersion => 1;
}
