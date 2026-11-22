import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/theme/app_colors.dart';
import 'package:it_network_monitor/core/theme/app_theme.dart';
import 'package:it_network_monitor/core/theme/theme_cubit.dart';
import 'package:it_network_monitor/features/theme/data/datasources/theme_local_datasource.dart';
import 'package:it_network_monitor/features/theme/data/datasources/theme_remote_datasource.dart';
import 'package:it_network_monitor/features/theme/data/repositories/theme_repository_impl.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/get_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/reset_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/save_palette_use_case.dart';

void main() {
  late Directory tempDir;
  late String testConfigPath;
  late ThemeLocalDataSource localDataSource;
  late ThemeRepositoryImpl repository;
  late ThemeCubit cubit;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('theme_widget_test_');
    testConfigPath = '${tempDir.path}${Platform.pathSeparator}widget_test.json';

    localDataSource = ThemeLocalDataSourceImpl();
    localDataSource.setCustomConfigPath(testConfigPath);

    final remoteDataSource = ThemeRemoteDataSourceImpl();
    repository = ThemeRepositoryImpl(localDataSource, remoteDataSource);

    cubit = ThemeCubit(
      getPaletteUseCase: GetPaletteUseCase(repository),
      savePaletteUseCase: SavePaletteUseCase(repository),
      resetPaletteUseCase: ResetPaletteUseCase(repository),
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

  Widget createTestApp(ThemeCubit themeCubit) {
    return BlocProvider<ThemeCubit>.value(
      value: themeCubit,
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            theme: AppTheme.buildTheme(palette: state.palette, isDark: false),
            darkTheme: AppTheme.buildTheme(palette: state.palette, isDark: true),
            themeMode: state.themeMode,
            home: Builder(
              builder: (ctx) {
                final tokens = ctx.colors;
                return Scaffold(
                  backgroundColor: tokens.main,
                  appBar: AppBar(
                    title: const Text('Dynamic Palette Test App'),
                  ),
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          key: const ValueKey('cta-btn'),
                          onPressed: () {},
                          child: const Text('Action CTA'),
                        ),
                        Container(
                          key: const ValueKey('surface-card'),
                          color: tokens.surfaceContainerLow,
                          child: Text(
                            'Themed Card Content',
                            style: TextStyle(color: tokens.onMain),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  testWidgets('1. MaterialApp renders with default Cyber Midnight palette in dark mode', (tester) async {
    await tester.pumpWidget(createTestApp(cubit));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF0B0B0F)); // Default Midnight Black

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), const Color(0xFFFF7A1A)); // Default Sunset Orange
    expect(theme.colorScheme.secondary, const Color(0xFFFF7A1A));
  });

  testWidgets('2. Changing palette seed dynamically at runtime re-themes widgets without restart', (tester) async {
    await tester.pumpWidget(createTestApp(cubit));
    await tester.pumpAndSettle();

    // Change Accent to Neon Cyan
    await cubit.updateSeed(SeedRole.accent, const Color(0xFF00E5FF));
    await tester.pumpAndSettle();

    final themeAfter = Theme.of(tester.element(find.byType(Scaffold)));
    expect(themeAfter.filledButtonTheme.style?.backgroundColor?.resolve({}), const Color(0xFF00E5FF));

    // Change Main to Deep Matrix
    await cubit.updateSeed(SeedRole.main, const Color(0xFF0A0F0D));
    await tester.pumpAndSettle();

    final scaffoldAfter = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffoldAfter.backgroundColor, const Color(0xFF0A0F0D));
  });

  testWidgets('3. Switching to light mode adapts scaffolds and surfaces seamlessly', (tester) async {
    await tester.pumpWidget(createTestApp(cubit));
    await tester.pumpAndSettle();

    await cubit.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.light);
  });
}
