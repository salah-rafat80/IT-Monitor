import '../../domain/entities/palette_entity.dart';

class PaletteModel extends PaletteEntity {
  static const PaletteModel defaultPalette = PaletteModel(
    main: 0xFF0B0B0F,
    second: 0xFF2F5BFF,
    accent: 0xFFFF7A1A,
    name: 'Cyber Midnight',
  );

  const PaletteModel({
    required super.main,
    required super.second,
    required super.accent,
    super.name = 'Cyber Midnight',
  });

  factory PaletteModel.fromEntity(PaletteEntity entity) {
    return PaletteModel(
      main: entity.main,
      second: entity.second,
      accent: entity.accent,
      name: entity.name,
    );
  }

  factory PaletteModel.fromJson(Map<String, dynamic> json) {
    return PaletteModel(
      main: _parseColorValue(json['main'], PaletteEntity.defaultPalette.main),
      second: _parseColorValue(json['second'], PaletteEntity.defaultPalette.second),
      accent: _parseColorValue(json['accent'], PaletteEntity.defaultPalette.accent),
      name: json['name'] as String? ?? 'Custom Palette',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'main': _toHexString(main),
      'second': _toHexString(second),
      'accent': _toHexString(accent),
      'name': name,
    };
  }

  static int _parseColorValue(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is String) {
      var hex = value.trim().replaceAll('#', '');
      if (hex.startsWith('0x') || hex.startsWith('0X')) {
        hex = hex.substring(2);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static String _toHexString(int color) {
    return '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
