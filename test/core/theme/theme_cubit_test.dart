import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/theme/theme_cubit.dart';
import 'package:it_network_monitor/features/theme/domain/entities/palette_entity.dart';
import 'package:it_network_monitor/features/theme/domain/repositories/theme_repository.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String tempConfigPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('theme_cubit_test_');
    tempConfigPath =
        '${tempDir.path}${Platform.pathSeparator}theme_preference.json';
    ThemeCubit.setCustomConfigPath(tempConfigPath);
  });

  tearDown(() async {
    ThemeCubit.setCustomConfigPath(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ThemeCubit', () {
    test('defaults to ThemeMode.dark when no config file exists', () {
      final cubit = ThemeCubit();
      expect(cubit.state.themeMode, equals(ThemeMode.dark));
      expect(cubit.state.isDark, isTrue);
      cubit.close();
    });

    test('toggleTheme alternates between dark and light', () async {
      final cubit = ThemeCubit();
      expect(cubit.state.themeMode, equals(ThemeMode.dark));

      cubit.toggleTheme();
      expect(cubit.state.themeMode, equals(ThemeMode.light));
      expect(cubit.state.isDark, isFalse);

      cubit.toggleTheme();
      expect(cubit.state.themeMode, equals(ThemeMode.dark));
      expect(cubit.state.isDark, isTrue);

      await cubit.close();
    });

    test('setThemeMode updates themeMode and persists to disk', () async {
      final cubit = ThemeCubit();

      cubit.setThemeMode(ThemeMode.light);
      expect(cubit.state.themeMode, equals(ThemeMode.light));
      await Future.delayed(const Duration(milliseconds: 50));

      final file = File(tempConfigPath);
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content.contains('"themeMode":"light"'), isTrue);

      await cubit.close();

      // Create a second cubit with the same config file to verify restoration on restart
      final restoredCubit = ThemeCubit();
      expect(restoredCubit.state.themeMode, equals(ThemeMode.light));
      expect(restoredCubit.state.isDark, isFalse);
      await restoredCubit.close();
    });

    test(
      'recovers safely to dark mode if persistence file is corrupted',
      () async {
        final file = File(tempConfigPath);
        await file.writeAsString('{ malformed json !*?');

        final cubit = ThemeCubit();
        expect(cubit.state.themeMode, equals(ThemeMode.dark));
        expect(cubit.state.isDark, isTrue);
        await cubit.close();
      },
    );

    test('surfaces error in state when setPalette persistence fails', () async {
      final failingRepo = _FailingThemeRepository();
      final cubit = ThemeCubit(themeRepository: failingRepo);

      await expectLater(
        () => cubit.setPalette(PalettePresets.all.first),
        throwsA(isA<Exception>()),
      );
      expect(cubit.state.errorMessage, contains('Failed to persist palette'));
      await cubit.close();
    });
  });
}

class _FailingThemeRepository implements ThemeRepository {
  @override
  Future<PaletteEntity> getPalette() async => PaletteEntity.defaultPalette;

  @override
  Future<void> savePalette(PaletteEntity palette) async {
    throw Exception('Disk I/O error');
  }

  @override
  Future<PaletteEntity> resetPalette() async => PaletteEntity.defaultPalette;

  @override
  Future<PaletteEntity> getRemotePalette({String? url}) async =>
      PaletteEntity.defaultPalette;

  @override
  Future<String> getThemeMode() async => 'dark';

  @override
  Future<void> saveThemeMode(String mode) async {}
}
