import 'package:injectable/injectable.dart';

import '../../domain/entities/palette_entity.dart';
import '../../domain/repositories/theme_repository.dart';
import '../datasources/theme_local_datasource.dart';
import '../datasources/theme_remote_datasource.dart';
import '../models/palette_model.dart';

@LazySingleton(as: ThemeRepository)
class ThemeRepositoryImpl implements ThemeRepository {
  final ThemeLocalDataSource _localDataSource;
  final ThemeRemoteDataSource _remoteDataSource;

  const ThemeRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
  );

  @override
  Future<PaletteEntity> getPalette() async {
    return _localDataSource.getSavedPalette();
  }

  @override
  Future<void> savePalette(PaletteEntity palette) async {
    final model = PaletteModel.fromEntity(palette);
    await _localDataSource.savePalette(model);
  }

  @override
  Future<PaletteEntity> resetPalette() async {
    const defaultPalette = PaletteEntity.defaultPalette;
    await savePalette(defaultPalette);
    return defaultPalette;
  }

  @override
  Future<PaletteEntity> getRemotePalette({String? url}) async {
    try {
      final remoteModel = await _remoteDataSource.fetchRemotePalette(url: url);
      return remoteModel;
    } catch (_) {
      return PaletteEntity.defaultPalette;
    }
  }

  @override
  Future<String> getThemeMode() async {
    return _localDataSource.getSavedThemeMode();
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    await _localDataSource.saveThemeMode(mode);
  }
}
