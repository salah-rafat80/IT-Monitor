import 'package:injectable/injectable.dart';

import '../entities/palette_entity.dart';
import '../repositories/theme_repository.dart';

@lazySingleton
class GetPaletteUseCase {
  final ThemeRepository _repository;

  const GetPaletteUseCase(this._repository);

  Future<PaletteEntity> call() => _repository.getPalette();
}
