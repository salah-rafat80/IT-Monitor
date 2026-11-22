import 'package:injectable/injectable.dart';

import '../entities/palette_entity.dart';
import '../repositories/theme_repository.dart';

@lazySingleton
class SavePaletteUseCase {
  final ThemeRepository _repository;

  const SavePaletteUseCase(this._repository);

  Future<void> call(PaletteEntity palette) => _repository.savePalette(palette);
}
