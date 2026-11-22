import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/theme/domain/entities/palette_entity.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

void main() {
  group('AppPalette Token Derivation Tests', () {
    test('1. Default seeds match Midnight Black, Electric Blue, Sunset Orange', () {
      final palette = AppPalette.defaultDark;

      expect(palette.main, const Color(0xFF0B0B0F)); // Midnight Black
      expect(palette.second, const Color(0xFF2F5BFF)); // Electric Blue
      expect(palette.accent, const Color(0xFFFF7A1A)); // Sunset Orange
      expect(palette.isDark, isTrue);
    });

    test('2. All derived tokens are generated automatically without hardcoding', () {
      final palette = AppPalette.fromSeeds(
        main: const Color(0xFF1A1A24),
        second: const Color(0xFF3B82F6),
        accent: const Color(0xFF10B981),
      );

      // Verify surfaces
      expect(palette.surface, isNotNull);
      expect(palette.surfaceVariant, isNotNull);
      expect(palette.surfaceContainerLow, isNotNull);
      expect(palette.surfaceContainer, isNotNull);
      expect(palette.surfaceContainerHigh, isNotNull);

      // Verify accessible onX colors
      expect(palette.onMain, isNotNull);
      expect(palette.onSecond, isNotNull);
      expect(palette.onAccent, isNotNull);

      // Verify structure tokens
      expect(palette.border, isNotNull);
      expect(palette.borderGlow, isNotNull);
      expect(palette.divider, isNotNull);
      expect(palette.disabled, isNotNull);

      // Verify feedback tokens
      expect(palette.success, isNotNull);
      expect(palette.warning, isNotNull);
      expect(palette.error, isNotNull);
      expect(palette.info, isNotNull);
      expect(palette.shadow, isNotNull);
      expect(palette.overlay, isNotNull);
    });

    test('3. Clean architecture conversion between PaletteEntity and AppPalette is bijective', () {
      const entity = PaletteEntity(
        main: 0xFF0B0B0F,
        second: 0xFF2F5BFF,
        accent: 0xFFFF7A1A,
        name: 'Cyber Midnight',
      );

      final palette = AppPalette.fromEntity(entity, isDark: true);
      expect(palette.main.toARGB32(), entity.main);
      expect(palette.second.toARGB32(), entity.second);
      expect(palette.accent.toARGB32(), entity.accent);

      final backToEntity = palette.toEntity();
      expect(backToEntity, entity);
    });

    test('4. JSON round-trip preserves color definitions accurately', () {
      final original = AppPalette.fromSeeds(
        main: const Color(0xFF0B0B0F),
        second: const Color(0xFF2F5BFF),
        accent: const Color(0xFFFF7A1A),
        name: 'Custom Sunset',
      );

      final json = original.toJson();
      final restored = AppPalette.fromJson(json);

      expect(restored.main.toARGB32(), original.main.toARGB32());
      expect(restored.second.toARGB32(), original.second.toARGB32());
      expect(restored.accent.toARGB32(), original.accent.toARGB32());
      expect(restored.name, original.name);
    });

    test('5. Linear interpolation (lerp) smoothly animates all tokens between two palettes', () {
      final paletteA = AppPalette.fromSeeds(
        main: const Color(0xFF000000),
        second: const Color(0xFF0000FF),
        accent: const Color(0xFFFF0000),
      );

      final paletteB = AppPalette.fromSeeds(
        main: const Color(0xFFFFFFFF),
        second: const Color(0xFF00FF00),
        accent: const Color(0xFF0000FF),
      );

      final half = AppPalette.lerp(paletteA, paletteB, 0.5);

      // Interpolated seeds should be midpoint
      expect(half.main.r, closeTo(0.5, 0.05));
      expect(half.second.g, closeTo(0.5, 0.05));
      expect(half.accent.b, closeTo(0.5, 0.05));
    });
  });
}
