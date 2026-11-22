import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/theme/data/datasources/theme_local_datasource.dart';
import 'package:it_network_monitor/features/theme/data/datasources/theme_remote_datasource.dart';
import 'package:it_network_monitor/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:it_network_monitor/features/theme/domain/entities/palette_entity.dart';

void main() {
  late Directory tempDir;
  late String testConfigPath;
  late ThemeLocalDataSource localDataSource;
  late ThemeRemoteDataSource remoteDataSource;
  late ThemeRepositoryImpl repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('theme_repo_test_');
    testConfigPath = '${tempDir.path}${Platform.pathSeparator}repo_test.json';

    localDataSource = ThemeLocalDataSourceImpl();
    localDataSource.setCustomConfigPath(testConfigPath);

    remoteDataSource = ThemeRemoteDataSourceImpl();
    repository = ThemeRepositoryImpl(localDataSource, remoteDataSource);
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('ThemeRepository Clean Architecture Tests', () {
    test('1. getPalette returns defaultPalette when no preference exists', () async {
      final palette = await repository.getPalette();
      expect(palette.main, PaletteEntity.defaultPalette.main);
      expect(palette.second, PaletteEntity.defaultPalette.second);
      expect(palette.accent, PaletteEntity.defaultPalette.accent);
    });

    test('2. savePalette persists entity and getPalette reads it back', () async {
      const custom = PaletteEntity(
        main: 0xFF121212,
        second: 0xFF2563EB,
        accent: 0xFFF59E0B,
        name: 'Enterprise Blue',
      );

      await repository.savePalette(custom);
      final retrieved = await repository.getPalette();

      expect(retrieved.main, custom.main);
      expect(retrieved.second, custom.second);
      expect(retrieved.accent, custom.accent);
    });

    test('3. resetPalette wipes custom palette and restores default', () async {
      const custom = PaletteEntity(
        main: 0xFFFFFFFF,
        second: 0xFF888888,
        accent: 0xFF111111,
      );
      await repository.savePalette(custom);

      final reset = await repository.resetPalette();
      expect(reset.main, PaletteEntity.defaultPalette.main);

      final current = await repository.getPalette();
      expect(current.main, PaletteEntity.defaultPalette.main);
    });

    test('4. getRemotePalette falls back gracefully on network or empty url failure', () async {
      // Empty url
      final fallback1 = await repository.getRemotePalette(url: null);
      expect(fallback1.main, PaletteEntity.defaultPalette.main);

      // Invalid url
      final fallback2 = await repository.getRemotePalette(url: 'http://invalid.nonexistent.domain.local/theme.json');
      expect(fallback2.main, PaletteEntity.defaultPalette.main);
    });

    test('5. getThemeMode and saveThemeMode persist theme state correctly', () async {
      expect(await repository.getThemeMode(), 'dark');

      await repository.saveThemeMode('light');
      expect(await repository.getThemeMode(), 'light');

      await repository.saveThemeMode('dark');
      expect(await repository.getThemeMode(), 'dark');
    });
  });
}
