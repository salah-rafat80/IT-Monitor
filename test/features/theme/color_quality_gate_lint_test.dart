import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/theme/app_colors.dart';
import 'package:it_network_monitor/core/theme/app_theme.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

void main() {
  group('Quality Gate: 60-30-10 Token Discipline & Dynamic Theming Gate', () {
    test('1. Every semantic token role is defined on AppPalette and AppColors without hardcoded gaps', () {
      final palette = AppPalette.defaultDark;
      final colors = AppColors(palette: palette);

      // 60-30-10 Seeds
      expect(colors.main, palette.main);
      expect(colors.second, palette.second);
      expect(colors.accent, palette.accent);

      // Surfaces
      expect(colors.surface, palette.surface);
      expect(colors.surfaceVariant, palette.surfaceVariant);
      expect(colors.surfaceContainerLowest, palette.surfaceContainerLowest);
      expect(colors.surfaceContainerLow, palette.surfaceContainerLow);
      expect(colors.surfaceContainer, palette.surfaceContainer);
      expect(colors.surfaceContainerHigh, palette.surfaceContainerHigh);
      expect(colors.surfaceContainerHighest, palette.surfaceContainerHighest);

      // onX Accessible Text/Icons
      expect(colors.onMain, palette.onMain);
      expect(colors.onSecond, palette.onSecond);
      expect(colors.onAccent, palette.onAccent);
      expect(colors.onSurface, palette.onSurface);
      expect(colors.onSurfaceVariant, palette.onSurfaceVariant);

      // Structural
      expect(colors.border, palette.border);
      expect(colors.borderGlow, palette.borderGlow);
      expect(colors.divider, palette.divider);
      expect(colors.disabled, palette.disabled);
      expect(colors.shadow, palette.shadow);
      expect(colors.overlay, palette.overlay);

      // Feedback
      expect(colors.success, palette.success);
      expect(colors.warning, palette.warning);
      expect(colors.error, palette.error);
      expect(colors.info, palette.info);
    });

    test('2. ThemeData builds dynamic ColorScheme strictly utilizing active palette seeds', () {
      final customPalette = AppPalette.fromSeeds(
        main: const Color(0xFF18181B), // Zinc 900
        second: const Color(0xFF6366F1), // Indigo 500
        accent: const Color(0xFFF97316), // Orange 500
      );

      final theme = AppTheme.buildTheme(palette: customPalette, isDark: true);

      expect(theme.scaffoldBackgroundColor, customPalette.main);
      expect(theme.colorScheme.primary, customPalette.second);
      expect(theme.colorScheme.secondary, customPalette.accent);
      expect(theme.cardTheme.color, customPalette.card);
      expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), customPalette.accent);
    });

    test('3. ThemeExtension lerp guarantees smooth animations between arbitrary custom palettes', () {
      final palette1 = AppPalette.fromSeeds(
        main: const Color(0xFF000000),
        second: const Color(0xFF101010),
        accent: const Color(0xFF202020),
      );
      final palette2 = AppPalette.fromSeeds(
        main: const Color(0xFFFFFFFF),
        second: const Color(0xFFEEEEEE),
        accent: const Color(0xFFDDDDDD),
      );

      final colors1 = AppColors(palette: palette1);
      final colors2 = AppColors(palette: palette2);

      final lerped = colors1.lerp(colors2, 0.5);

      expect(lerped.main.r, closeTo(0.5, 0.05));
      expect(lerped.second.r, closeTo(0.5, 0.05));
      expect(lerped.accent.r, closeTo(0.5, 0.05));
    });
  });
}
