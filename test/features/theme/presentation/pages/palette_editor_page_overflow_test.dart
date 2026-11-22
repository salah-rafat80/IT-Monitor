import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:it_network_monitor/core/theme/theme_cubit.dart';
import 'package:it_network_monitor/core/theme/app_theme.dart';
import 'package:it_network_monitor/features/theme/presentation/pages/palette_editor_page.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/get_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/save_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/usecases/reset_palette_use_case.dart';
import 'package:it_network_monitor/features/theme/domain/repositories/theme_repository.dart';
import 'package:it_network_monitor/features/theme/domain/entities/palette_entity.dart';

class _FakeThemeRepository implements ThemeRepository {
  PaletteEntity _palette = PaletteEntity.defaultPalette;
  String _mode = 'dark';

  @override
  Future<PaletteEntity> getPalette() async => _palette;
  @override
  Future<void> savePalette(PaletteEntity palette) async => _palette = palette;
  @override
  Future<PaletteEntity> resetPalette() async {
    _palette = PaletteEntity.defaultPalette;
    return _palette;
  }
  @override
  Future<PaletteEntity> getRemotePalette({String? url}) async => _palette;
  @override
  Future<String> getThemeMode() async => _mode;
  @override
  Future<void> saveThemeMode(String mode) async => _mode = mode;
}

void main() {
  testWidgets('PaletteEditorPage renders without any overflow', (tester) async {
    final repo = _FakeThemeRepository();
    final cubit = ThemeCubit(
      getPaletteUseCase: GetPaletteUseCase(repo),
      savePaletteUseCase: SavePaletteUseCase(repo),
      resetPaletteUseCase: ResetPaletteUseCase(repo),
      themeRepository: repo,
    );

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>.value(
        value: cubit,
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, state) {
            return MaterialApp(
              theme: AppTheme.buildTheme(palette: state.palette, isDark: false),
              darkTheme: AppTheme.buildTheme(palette: state.palette, isDark: true),
              themeMode: state.themeMode,
              home: const PaletteEditorPage(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Dynamic Palette & Token Editor'), findsOneWidget);
    expect(find.text('Preset Palettes'), findsOneWidget);
    expect(find.text('Cyber Midnight'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
