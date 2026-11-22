import 'package:equatable/equatable.dart';

/// Pure Dart entity representing the 60-30-10 palette seeds.
///
/// Must not import Flutter or dart:ui to uphold Clean Architecture boundaries.
class PaletteEntity extends Equatable {
  /// 60% Main (scaffolds, backgrounds, large surfaces)
  /// Default: Midnight Black (0xFF0B0B0F)
  final int main;

  /// 30% Second (cards, bars, secondary surfaces, containers)
  /// Default: Electric Blue (0xFF2F5BFF)
  final int second;

  /// 10% Accent (CTAs, FABs, active states, highlights, badges)
  /// Default: Sunset Orange (0xFFFF7A1A)
  final int accent;

  /// Name or identifier for presets (e.g. 'Cyber Midnight')
  final String name;

  const PaletteEntity({
    required this.main,
    required this.second,
    required this.accent,
    this.name = 'Cyber Midnight',
  });

  /// Default seed values per the 60-30-10 specification:
  /// - Main (60%): 0xFF0B0B0F (#0B0B0F Midnight Black)
  /// - Second (30%): 0xFF2F5BFF (#2F5BFF Electric Blue)
  /// - Accent (10%): 0xFFFF7A1A (#FF7A1A Sunset Orange)
  static const PaletteEntity defaultPalette = PaletteEntity(
    main: 0xFF0B0B0F,
    second: 0xFF2F5BFF,
    accent: 0xFFFF7A1A,
    name: 'Cyber Midnight',
  );

  PaletteEntity copyWith({
    int? main,
    int? second,
    int? accent,
    String? name,
  }) {
    return PaletteEntity(
      main: main ?? this.main,
      second: second ?? this.second,
      accent: accent ?? this.accent,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [main, second, accent, name];
}
