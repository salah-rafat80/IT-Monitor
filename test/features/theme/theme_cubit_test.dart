import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/theme/theme_cubit.dart';
import 'package:it_network_monitor/features/theme/data/datasources/theme_local_datasource.dart';
import 'package:it_network_monitor/features/theme/data/datasources/theme_remote_datasource.dart';
import 'package:it_network_monitor/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/get_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/reset_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/save_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

void main() {
  late Directory tempDir;
  late String testConfigPath;
  late ThemeLocalDataSource localDataSource;
  late ThemeRemoteDataSource remoteDataSource;
  late ThemeRepositoryImpl repository;
  late GetPaletteUseCase getPaletteUseCase;
  late SavePaletteUseCase savePaletteUseCase;
  late ResetPaletteUseCase resetPaletteUseCase;
  late ThemeCubit cubit;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('theme_cubit_test_');
    testConfigPath = '${tempDir.path}${Platform.pathSeparator}theme_test.json';

    localDataSource = ThemeLocalDataSourceImpl();
    localDataSource.setCustomConfigPath(testConfigPath);

    remoteDataSource = ThemeRemoteDataSourceImpl();
    repository = ThemeRepositoryImpl(localDataSource, remoteDataSource);

    getPaletteUseCase = GetPaletteUseCase(repository);
    savePaletteUseCase = SavePaletteUseCase(repository);
    resetPaletteUseCase = ResetPaletteUseCase(repository);

    cubit = ThemeCubit(
      getPaletteUseCase: getPaletteUseCase,
      savePaletteUseCase: savePaletteUseCase,
      resetPaletteUseCase: resetPaletteUseCase,
      themeRepository: repository,
      localDataSource: localDataSource,
    );
  });

  tearDown(() {
    cubit.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('ThemeCubit State & Behavior Tests', () {
    test('1. Initial state defaults to Cyber Midnight in dark mode', () {
      expect(cubit.state.palette.main, const Color(0xFF0B0B0F));
      expect(cubit.state.palette.second, const Color(0xFF2F5BFF));
      expect(cubit.state.palette.accent, const Color(0xFFFF7A1A));
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(cubit.state.isDark, isTrue);
    });

    test('2. updateSeed changes the target seed and recalculates tokens immediately', () async {
      await cubit.updateSeed(SeedRole.accent, const Color(0xFF00E5FF));

      expect(cubit.state.palette.accent, const Color(0xFF00E5FF));
      expect(cubit.state.palette.main, const Color(0xFF0B0B0F)); // Main untouched
      expect(cubit.state.palette.second, const Color(0xFF2F5BFF)); // Second untouched
    });

    test('3. setPalette updates and persists new palette to disk', () async {
      final newPalette = AppPalette.fromSeeds(
        main: const Color(0xFF111827),
        second: const Color(0xFF4F46E5),
        accent: const Color(0xFF10B981),
        name: 'Persisted Green',
      );

      await cubit.setPalette(newPalette);
      expect(cubit.state.palette.name, 'Persisted Green');

      // Verify persistence by reading with new data source instance
      final freshLocal = ThemeLocalDataSourceImpl();
      freshLocal.setCustomConfigPath(testConfigPath);
      final persisted = freshLocal.getSavedPaletteSync();

      expect(persisted.main, const Color(0xFF111827).toARGB32());
      expect(persisted.second, const Color(0xFF4F46E5).toARGB32());
      expect(persisted.accent, const Color(0xFF10B981).toARGB32());
      expect(persisted.name, 'Persisted Green');
    });

    test('4. toggleMode switches between dark and light modes cleanly', () async {
      expect(cubit.state.isDark, isTrue);

      await cubit.toggleMode();
      expect(cubit.state.isDark, isFalse);
      expect(cubit.state.themeMode, ThemeMode.light);

      await cubit.toggleMode();
      expect(cubit.state.isDark, isTrue);
      expect(cubit.state.themeMode, ThemeMode.dark);
    });

    test('5. resetToDefault restores the default 60-30-10 palette', () async {
      await cubit.updateSeed(SeedRole.main, const Color(0xFFFFFFFF));
      await cubit.updateSeed(SeedRole.second, const Color(0xFF000000));
      expect(cubit.state.palette.main, const Color(0xFFFFFFFF));

      await cubit.resetToDefault();
      expect(cubit.state.palette.main, const Color(0xFF0B0B0F));
      expect(cubit.state.palette.second, const Color(0xFF2F5BFF));
      expect(cubit.state.palette.accent, const Color(0xFFFF7A1A));
    });

    test('6. loadFromJson parses hex color strings and updates active palette', () async {
      final json = {
        'main': '#0A0F0D',
        'second': '#064E3B',
        'accent': '#10B981',
        'name': 'Remote Matrix',
      };

      await cubit.loadFromJson(json);

      expect(cubit.state.palette.main, const Color(0xFF0A0F0D));
      expect(cubit.state.palette.second, const Color(0xFF064E3B));
      expect(cubit.state.palette.accent, const Color(0xFF10B981));
      expect(cubit.state.palette.name, 'Remote Matrix');
    });
  });
}
