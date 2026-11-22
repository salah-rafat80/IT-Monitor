import 'package:injectable/injectable.dart';

import '../entities/palette_entity.dart';
import '../repositories/theme_repository.dart';

@lazySingleton
class ResetPaletteUseCase {
  final ThemeRepository _repository;

  const ResetPaletteUseCase(this._repository);

  Future<PaletteEntity> call() => _repository.resetPalette();
}
