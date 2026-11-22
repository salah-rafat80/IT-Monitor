import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../features/theme/data/datasources/theme_local_datasource.dart';
import '../../features/theme/data/datasources/theme_remote_datasource.dart';
import '../../features/theme/data/repositories/theme_repository_impl.dart';
import '../../features/theme/domain/repositories/theme_repository.dart';
import '../../features/theme/domain/usecases/get_palette_use_case.dart';
import '../../features/theme/domain/usecases/reset_palette_use_case.dart';
import '../../features/theme/domain/usecases/save_palette_use_case.dart';
import '../../features/theme/presentation/theme/app_palette.dart';

enum SeedRole { main, second, accent }

class ThemeState extends Equatable {
  final AppPalette palette;
  final ThemeMode themeMode;

  const ThemeState({
    required this.palette,
    this.themeMode = ThemeMode.dark,
  });

  bool get isDark => themeMode == ThemeMode.dark;
  bool get isLight => themeMode == ThemeMode.light;

  ThemeState copyWith({
    AppPalette? palette,
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      palette: palette ?? this.palette,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [palette, themeMode];
}

@lazySingleton
class ThemeCubit extends Cubit<ThemeState> {
  final GetPaletteUseCase _getPaletteUseCase;
  final SavePaletteUseCase _savePaletteUseCase;
  final ResetPaletteUseCase _resetPaletteUseCase;
  final ThemeRepository _themeRepository;
  final ThemeLocalDataSource _localDataSource;

  static String? defaultCustomConfigPath;

  ThemeCubit({
    GetPaletteUseCase? getPaletteUseCase,
    SavePaletteUseCase? savePaletteUseCase,
    ResetPaletteUseCase? resetPaletteUseCase,
    ThemeRepository? themeRepository,
    ThemeLocalDataSource? localDataSource,
  }) : _localDataSource = localDataSource ?? ThemeLocalDataSourceImpl(),
       _themeRepository = themeRepository ??
           ThemeRepositoryImpl(
             localDataSource ?? ThemeLocalDataSourceImpl(),
             ThemeRemoteDataSourceImpl(),
           ),
       _getPaletteUseCase = getPaletteUseCase ??
           GetPaletteUseCase(
             themeRepository ??
                 ThemeRepositoryImpl(
                   localDataSource ?? ThemeLocalDataSourceImpl(),
                   ThemeRemoteDataSourceImpl(),
                 ),
           ),
       _savePaletteUseCase = savePaletteUseCase ??
           SavePaletteUseCase(
             themeRepository ??
                 ThemeRepositoryImpl(
                   localDataSource ?? ThemeLocalDataSourceImpl(),
                   ThemeRemoteDataSourceImpl(),
                 ),
           ),
       _resetPaletteUseCase = resetPaletteUseCase ??
           ResetPaletteUseCase(
             themeRepository ??
                 ThemeRepositoryImpl(
                   localDataSource ?? ThemeLocalDataSourceImpl(),
                   ThemeRemoteDataSourceImpl(),
                 ),
           ),
       super(_getInitialState(localDataSource ?? ThemeLocalDataSourceImpl(), defaultCustomConfigPath)) {
    if (defaultCustomConfigPath != null) {
      _localDataSource.setCustomConfigPath(defaultCustomConfigPath);
    }
  }

  /// Synchronously loads initial state from disk before first frame to eliminate theme flash.
  static ThemeState _getInitialState(ThemeLocalDataSource localDs, String? customPath) {
    if (customPath != null) {
      localDs.setCustomConfigPath(customPath);
    }
    try {
      final savedModel = localDs.getSavedPaletteSync();
      final modeStr = localDs.getSavedThemeModeSync();
      final mode = modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
      final palette = AppPalette.fromEntity(savedModel, isDark: mode == ThemeMode.dark);
      return ThemeState(palette: palette, themeMode: mode);
    } catch (_) {
      return ThemeState(
        palette: AppPalette.defaultDark,
        themeMode: ThemeMode.dark,
      );
    }
  }

  /// Sets custom configuration path for test isolation.
  static void setCustomConfigPath(String? path) {
    defaultCustomConfigPath = path;
    ThemeLocalDataSourceImpl.globalCustomConfigPath = path;
  }

  void setCustomPath(String? path) {
    _localDataSource.setCustomConfigPath(path);
    _reloadPreference();
  }

  void _reloadPreference() {
    final newState = _getInitialState(_localDataSource, null);
    emit(newState);
  }

  /// Reloads palette asynchronously using the domain usecase.
  Future<void> reloadFromDomain() async {
    final entity = await _getPaletteUseCase();
    final palette = AppPalette.fromEntity(entity, isDark: state.isDark);
    emit(state.copyWith(palette: palette));
  }

  /// Replaces the current palette with [palette] and persists it.
  Future<void> setPalette(AppPalette palette) async {
    final updated = palette.copyWith(isDark: state.isDark);
    emit(state.copyWith(palette: updated));
    try {
      await _savePaletteUseCase(updated.toEntity());
    } catch (e) {
      debugPrint('[ThemeCubit] Failed to persist palette: $e');
      rethrow;
    }
  }

  /// Updates a single seed color (main, second, accent) and re-derives all tokens.
  Future<void> updateSeed(SeedRole role, Color color) async {
    final AppPalette updated;
    switch (role) {
      case SeedRole.main:
        updated = state.palette.copyWith(main: color);
        break;
      case SeedRole.second:
        updated = state.palette.copyWith(second: color);
        break;
      case SeedRole.accent:
        updated = state.palette.copyWith(accent: color);
        break;
    }
    await setPalette(updated);
  }

  /// Resets the palette to the default seeds (Midnight Black, Electric Blue, Sunset Orange).
  Future<void> resetToDefault() async {
    final defaultEntity = await _resetPaletteUseCase();
    final defaultPalette = AppPalette.fromEntity(defaultEntity, isDark: state.isDark);
    emit(state.copyWith(palette: defaultPalette));
  }

  /// Sets the active [ThemeMode] ('dark' or 'light') and persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;
    final isDark = mode == ThemeMode.dark;
    final updatedPalette = state.palette.copyWith(isDark: isDark);
    emit(state.copyWith(themeMode: mode, palette: updatedPalette));
    await _themeRepository.saveThemeMode(mode.name);
  }

  /// Toggles between light and dark modes.
  Future<void> toggleMode() async {
    final next = state.isDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  /// Legacy alias for toggleMode
  Future<void> toggleTheme() => toggleMode();

  /// Loads palette from a JSON map (e.g. Remote Config or file).
  Future<void> loadFromJson(Map<String, dynamic> json) async {
    try {
      final palette = AppPalette.fromJson(json, isDark: state.isDark);
      await setPalette(palette);
    } catch (_) {
      // Keep existing state if JSON is corrupted
    }
  }

  /// Loads palette from a remote endpoint URL, falling back gracefully.
  Future<void> loadFromRemote({String? url}) async {
    try {
      final entity = await _themeRepository.getRemotePalette(url: url);
      final palette = AppPalette.fromEntity(entity, isDark: state.isDark);
      await setPalette(palette);
    } catch (_) {
      await resetToDefault();
    }
  }
}
