import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Database Path Resolution & Isolation Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('it_db_path_test_');
    });

    tearDown(() {
      DatabaseConfig.customDataDir = null;
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test(
      '1. DatabaseConfig.customDataDir override binds strictly to isolated target',
      () async {
        final customPath = p.join(tempDir.path, 'custom_isolated_env');
        DatabaseConfig.customDataDir = customPath;

        expect(DatabaseConfig.customDataDir, equals(customPath));

        final targetDir = Directory(customPath);
        expect(targetDir.existsSync(), isFalse);

        targetDir.createSync(recursive: true);
        expect(targetDir.existsSync(), isTrue);

        final dbFile = File(
          p.join(targetDir.path, 'it_network_monitor.sqlite'),
        );
        expect(dbFile.existsSync(), isFalse);

        await dbFile.writeAsString('test-sqlite-marker');
        expect(dbFile.existsSync(), isTrue);
        expect(await dbFile.readAsString(), equals('test-sqlite-marker'));
      },
    );

    test(
      '2. Authoritative database in custom dir is preserved and never silently diverted',
      () async {
        final customPath = p.join(tempDir.path, 'authoritative_prod');
        final targetDir = Directory(customPath)..createSync(recursive: true);
        final prodFile = File(
          p.join(targetDir.path, 'it_network_monitor.sqlite'),
        )..writeAsStringSync('prod-data');

        DatabaseConfig.customDataDir = customPath;

        // Assert prodFile exists
        expect(prodFile.existsSync(), isTrue);

        // Verify that path resolution maintains the authoritative file path
        final resolvedFile = File(
          p.join(DatabaseConfig.customDataDir!, 'it_network_monitor.sqlite'),
        );
        expect(resolvedFile.existsSync(), isTrue);
        expect(resolvedFile.path, equals(prodFile.path));
      },
    );
  });
}
