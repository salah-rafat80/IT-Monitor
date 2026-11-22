import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/theme/presentation/theme/app_palette.dart';

void main() {
  group('WCAG AA Contrast Enforcement Tests (>= 4.5:1)', () {
    test('1. On-colors for default seeds pass WCAG AA contrast ratio (>= 4.5:1)', () {
      final palette = AppPalette.defaultDark;

      final mainContrast = AppPalette.calculateContrastRatio(palette.onMain, palette.main);
      final secondContrast = AppPalette.calculateContrastRatio(palette.onSecond, palette.second);
      final accentContrast = AppPalette.calculateContrastRatio(palette.onAccent, palette.accent);

      expect(mainContrast, greaterThanOrEqualTo(4.5), reason: 'onMain against Main must satisfy WCAG AA');
      expect(secondContrast, greaterThanOrEqualTo(4.5), reason: 'onSecond against Second must satisfy WCAG AA');
      expect(accentContrast, greaterThanOrEqualTo(4.5), reason: 'onAccent against Accent must satisfy WCAG AA');
    });

    test('2. Automatic selection picks light text on dark backgrounds and dark text on light backgrounds', () {
      const veryDark = Color(0xFF0A0A0E);
      const veryLight = Color(0xFFF9FAFB);

      final onDark = AppPalette.ensureAccessibleColor(background: veryDark);
      final onLight = AppPalette.ensureAccessibleColor(background: veryLight);

      expect(AppPalette.calculateLuminance(onDark), greaterThan(0.5));
      expect(AppPalette.calculateLuminance(onLight), lessThan(0.5));

      expect(AppPalette.calculateContrastRatio(onDark, veryDark), greaterThanOrEqualTo(4.5));
      expect(AppPalette.calculateContrastRatio(onLight, veryLight), greaterThanOrEqualTo(4.5));
    });

    test('3. High-luminance accent colors (e.g. Sunset Orange, Bright Yellow) guarantee readable onAccent text', () {
      const sunsetOrange = Color(0xFFFF7A1A); // Default Accent
      const brightYellow = Color(0xFFFFEB3B);

      final onSunset = AppPalette.ensureAccessibleColor(background: sunsetOrange);
      final onYellow = AppPalette.ensureAccessibleColor(background: brightYellow);

      final contrastSunset = AppPalette.calculateContrastRatio(onSunset, sunsetOrange);
      final contrastYellow = AppPalette.calculateContrastRatio(onYellow, brightYellow);

      expect(contrastSunset, greaterThanOrEqualTo(4.5));
      expect(contrastYellow, greaterThanOrEqualTo(4.5));
    });

    test('4. All curated presets strictly pass WCAG AA contrast for all three seeds', () {
      for (final preset in PalettePresets.all) {
        final onMain = AppPalette.calculateContrastRatio(preset.onMain, preset.main);
        final onSecond = AppPalette.calculateContrastRatio(preset.onSecond, preset.second);
        final onAccent = AppPalette.calculateContrastRatio(preset.onAccent, preset.accent);

        expect(
          onMain,
          greaterThanOrEqualTo(4.5),
          reason: '${preset.name}: onMain failed WCAG AA ($onMain < 4.5)',
        );
        expect(
          onSecond,
          greaterThanOrEqualTo(4.5),
          reason: '${preset.name}: onSecond failed WCAG AA ($onSecond < 4.5)',
        );
        expect(
          onAccent,
          greaterThanOrEqualTo(4.5),
          reason: '${preset.name}: onAccent failed WCAG AA ($onAccent < 4.5)',
        );
      }
    });
  });
}
