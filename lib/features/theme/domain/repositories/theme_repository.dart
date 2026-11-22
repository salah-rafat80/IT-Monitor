import '../entities/palette_entity.dart';

/// Abstract contract for theme and palette persistence & retrieval.
///
/// Pure Dart interface ensuring clean architecture isolation from data sources.
abstract class ThemeRepository {
  /// Retrieves the active saved palette, or returns [PaletteEntity.defaultPalette].
  Future<PaletteEntity> getPalette();

  /// Persists a new palette.
  Future<void> savePalette(PaletteEntity palette);

  /// Resets the palette to [PaletteEntity.defaultPalette].
  Future<PaletteEntity> resetPalette();

  /// Loads a remote palette (e.g. from an API or JSON url), falling back gracefully.
  Future<PaletteEntity> getRemotePalette({String? url});

  /// Retrieves the persisted theme mode ('dark', 'light', or 'system').
  Future<String> getThemeMode();

  /// Persists the selected theme mode ('dark', 'light', or 'system').
  Future<void> saveThemeMode(String mode);
}
