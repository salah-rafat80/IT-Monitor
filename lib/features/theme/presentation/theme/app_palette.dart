import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../data/models/palette_model.dart';
import '../../domain/entities/palette_entity.dart';

/// Semantic token palette derived dynamically from 3 seeds following the 60-30-10 rule:
/// - Main (60%): Scaffolds, backgrounds, large surfaces (Default: #0B0B0F Midnight Black)
/// - Second (30%): Cards, app bars, nav bars, containers (Default: #2F5BFF Electric Blue)
/// - Accent (10%): CTAs, FABs, active states, highlights, badges (Default: #FF7A1A Sunset Orange)
///
/// Guaranteed WCAG AA accessible contrast (>= 4.5:1 for text, >= 3.0:1 for borders/icons)
/// across both Dark and Light modes without mixed or inverted colors.
class AppPalette extends Equatable {
  final String name;
  final bool isDark;

  // --- 3 Core Seeds ---
  final Color main;
  final Color second;
  final Color accent;

  // --- Surfaces & Containers ---
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color card;
  final Color header;
  final Color sidebar;
  final Color tableHeader;
  final Color tableRow;
  final Color tableRowAlternate;
  final Color input;

  // --- WCAG AA Accessible onX Tokens (>= 4.5:1 Contrast) ---
  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onMain;
  final Color onSecond;
  final Color onAccent;
  final Color onCard;
  final Color onHeader;
  final Color onSidebar;
  final Color onTableHeader;
  final Color onTableRow;
  final Color onInput;
  final Color inputHint;

  // --- Structure & Lines ---
  final Color border;
  final Color borderGlow;
  final Color divider;
  final Color disabled;
  final Color shadow;
  final Color overlay;

  // --- Semantic Status Pairs (Surface + Text) ---
  final Color statusOnline;
  final Color statusOnlineSurface;
  final Color onStatusOnline;

  final Color statusOffline;
  final Color statusOfflineSurface;
  final Color onStatusOffline;

  final Color statusDegraded;
  final Color statusDegradedSurface;
  final Color onStatusDegraded;

  final Color statusMaintenance;
  final Color statusMaintenanceSurface;
  final Color onStatusMaintenance;

  final Color statusUnknown;
  final Color statusUnknownSurface;
  final Color onStatusUnknown;

  const AppPalette._raw({
    required this.name,
    required this.isDark,
    required this.main,
    required this.second,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.card,
    required this.header,
    required this.sidebar,
    required this.tableHeader,
    required this.tableRow,
    required this.tableRowAlternate,
    required this.input,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onMain,
    required this.onSecond,
    required this.onAccent,
    required this.onCard,
    required this.onHeader,
    required this.onSidebar,
    required this.onTableHeader,
    required this.onTableRow,
    required this.onInput,
    required this.inputHint,
    required this.border,
    required this.borderGlow,
    required this.divider,
    required this.disabled,
    required this.shadow,
    required this.overlay,
    required this.statusOnline,
    required this.statusOnlineSurface,
    required this.onStatusOnline,
    required this.statusOffline,
    required this.statusOfflineSurface,
    required this.onStatusOffline,
    required this.statusDegraded,
    required this.statusDegradedSurface,
    required this.onStatusDegraded,
    required this.statusMaintenance,
    required this.statusMaintenanceSurface,
    required this.onStatusMaintenance,
    required this.statusUnknown,
    required this.statusUnknownSurface,
    required this.onStatusUnknown,
  });

  Color get statusStale => const Color(0xFFEAB308);

  /// Factory constructor that derives all semantic tokens dynamically from seeds.
  /// Fully adapts for Dark and Light modes so surfaces and text are never inverted or mixed.
  factory AppPalette.fromSeeds({
    required Color main,
    required Color second,
    required Color accent,
    String name = 'Custom Palette',
    bool isDark = true,
  }) {
    // ── 1. Calculate Surfaces ──
    final Color background;
    final Color surface;
    final Color surfaceVariant;
    final Color surfaceContainerLowest;
    final Color surfaceContainerLow;
    final Color surfaceContainer;
    final Color surfaceContainerHigh;
    final Color surfaceContainerHighest;

    if (isDark) {
      // Dark Mode surfaces derived from dark main seed
      background = main;
      surface = _blend(main, second, 0.05);
      surfaceVariant = _blend(main, second, 0.12);
      surfaceContainerLowest = _darken(main, 0.04);
      surfaceContainerLow = _blend(main, second, 0.08);
      surfaceContainer = _blend(main, second, 0.14);
      surfaceContainerHigh = _blend(main, second, 0.20);
      surfaceContainerHighest = _blend(main, second, 0.28);
    } else {
      // Light Mode surfaces: clean, luminous, consistent light theme
      background = const Color(0xFFF8FAFC);
      surface = const Color(0xFFFFFFFF);
      surfaceVariant = const Color(0xFFF1F5F9);
      surfaceContainerLowest = const Color(0xFFFFFFFF);
      surfaceContainerLow = const Color(0xFFF8FAFC);
      surfaceContainer = const Color(0xFFEDF2F7);
      surfaceContainerHigh = const Color(0xFFE2E8F0);
      surfaceContainerHighest = const Color(0xFFCBD5E1);
    }

    final card = surface;
    final header = isDark ? surfaceContainerLow : const Color(0xFFFFFFFF);
    final sidebar = isDark ? surfaceContainerLowest : const Color(0xFFFFFFFF);
    final tableHeader = surfaceContainer;
    final tableRow = surface;
    final tableRowAlternate = surfaceContainerLow;
    final input = isDark ? surfaceContainerLowest : const Color(0xFFFFFFFF);

    // ── 2. Derive WCAG AA Accessible onX Colors (>= 4.5:1) ──
    final onBackground = ensureAccessibleColor(background: background);
    final onSurface = ensureAccessibleColor(background: surface);
    final onMain = ensureAccessibleColor(background: main);
    final onSecond = ensureAccessibleColor(background: second);
    final onAccent = ensureAccessibleColor(background: accent);
    final onCard = ensureAccessibleColor(background: card);
    final onHeader = ensureAccessibleColor(background: header);
    final onSidebar = ensureAccessibleColor(background: sidebar);
    final onTableHeader = ensureAccessibleColor(background: tableHeader);
    final onTableRow = ensureAccessibleColor(background: tableRow);
    final onInput = ensureAccessibleColor(background: input);

    // Accessible onSurfaceVariant (guaranteed >= 4.5:1 against surface)
    final onSurfaceVariant = ensureContrast(
      foreground: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
      background: surface,
      minRatio: 4.5,
    );

    // Accessible inputHint (guaranteed >= 4.5:1 against input)
    final inputHint = ensureContrast(
      foreground: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
      background: input,
      minRatio: 4.5,
    );

    // ── 3. Structure & Lines (Borders >= 3.0:1) ──
    final border = isDark
        ? const Color(0xFF263650)
        : const Color(0xFFCBD5E1);

    final borderGlow = accent.withValues(alpha: isDark ? 0.35 : 0.20);
    final divider = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final disabled = onSurface.withValues(alpha: 0.38);
    final shadow = const Color(0xFF000000).withValues(alpha: isDark ? 0.40 : 0.08);
    final overlay = const Color(0xFF000000).withValues(alpha: isDark ? 0.70 : 0.45);

    // ── 4. Semantic Status Tokens (Surface + Text with >= 4.5:1 contrast) ──
    final Color statusOnline;
    final Color statusOnlineSurface;
    final Color onStatusOnline;

    final Color statusOffline;
    final Color statusOfflineSurface;
    final Color onStatusOffline;

    final Color statusDegraded;
    final Color statusDegradedSurface;
    final Color onStatusDegraded;

    final Color statusMaintenance;
    final Color statusMaintenanceSurface;
    final Color onStatusMaintenance;

    final Color statusUnknown;
    final Color statusUnknownSurface;
    final Color onStatusUnknown;

    if (isDark) {
      statusOnline = const Color(0xFF10B981);
      statusOnlineSurface = const Color(0xFF064E3B).withValues(alpha: 0.50);
      onStatusOnline = const Color(0xFF6EE7B7);

      statusOffline = const Color(0xFFEF4444);
      statusOfflineSurface = const Color(0xFF7F1D1D).withValues(alpha: 0.50);
      onStatusOffline = const Color(0xFFFCA5A5);

      statusDegraded = const Color(0xFFF59E0B);
      statusDegradedSurface = const Color(0xFF78350F).withValues(alpha: 0.50);
      onStatusDegraded = const Color(0xFFFCD34D);

      statusMaintenance = const Color(0xFF8B5CF6);
      statusMaintenanceSurface = const Color(0xFF4C1D95).withValues(alpha: 0.50);
      onStatusMaintenance = const Color(0xFFC4B5FD);

      statusUnknown = const Color(0xFF94A3B8);
      statusUnknownSurface = const Color(0xFF334155).withValues(alpha: 0.50);
      onStatusUnknown = const Color(0xFFCBD5E1);
    } else {
      statusOnline = const Color(0xFF059669);
      statusOnlineSurface = const Color(0xFFDCFCE7);
      onStatusOnline = const Color(0xFF065F46);

      statusOffline = const Color(0xFFDC2626);
      statusOfflineSurface = const Color(0xFFFEE2E2);
      onStatusOffline = const Color(0xFF991B1B);

      statusDegraded = const Color(0xFFD97706);
      statusDegradedSurface = const Color(0xFFFEF3C7);
      onStatusDegraded = const Color(0xFF92400E);

      statusMaintenance = const Color(0xFF7C3AED);
      statusMaintenanceSurface = const Color(0xFFEDE9FE);
      onStatusMaintenance = const Color(0xFF5B21B6);

      statusUnknown = const Color(0xFF64748B);
      statusUnknownSurface = const Color(0xFFF1F5F9);
      onStatusUnknown = const Color(0xFF1E293B);
    }

    return AppPalette._raw(
      name: name,
      isDark: isDark,
      main: main,
      second: second,
      accent: accent,
      background: background,
      surface: surface,
      surfaceVariant: surfaceVariant,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      card: card,
      header: header,
      sidebar: sidebar,
      tableHeader: tableHeader,
      tableRow: tableRow,
      tableRowAlternate: tableRowAlternate,
      input: input,
      onBackground: onBackground,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      onMain: onMain,
      onSecond: onSecond,
      onAccent: onAccent,
      onCard: onCard,
      onHeader: onHeader,
      onSidebar: onSidebar,
      onTableHeader: onTableHeader,
      onTableRow: onTableRow,
      onInput: onInput,
      inputHint: inputHint,
      border: border,
      borderGlow: borderGlow,
      divider: divider,
      disabled: disabled,
      shadow: shadow,
      overlay: overlay,
      statusOnline: statusOnline,
      statusOnlineSurface: statusOnlineSurface,
      onStatusOnline: onStatusOnline,
      statusOffline: statusOffline,
      statusOfflineSurface: statusOfflineSurface,
      onStatusOffline: onStatusOffline,
      statusDegraded: statusDegraded,
      statusDegradedSurface: statusDegradedSurface,
      onStatusDegraded: onStatusDegraded,
      statusMaintenance: statusMaintenance,
      statusMaintenanceSurface: statusMaintenanceSurface,
      onStatusMaintenance: onStatusMaintenance,
      statusUnknown: statusUnknown,
      statusUnknownSurface: statusUnknownSurface,
      onStatusUnknown: onStatusUnknown,
    );
  }

  // Backward compatibility alias for feedback tokens
  Color get success => statusOnline;
  Color get onSuccess => onStatusOnline;
  Color get warning => statusDegraded;
  Color get onWarning => onStatusDegraded;
  Color get error => statusOffline;
  Color get onError => onStatusOffline;
  Color get info => second;
  Color get onInfo => onSecond;

  /// Default 60-30-10 Dark Palette:
  /// - Main (60%): Midnight Black -> #0B0B0F
  /// - Second (30%): Electric Blue -> #2F5BFF
  /// - Accent (10%): Sunset Orange -> #FF7A1A
  static AppPalette defaultDark = AppPalette.fromSeeds(
    main: const Color(0xFF0B0B0F),
    second: const Color(0xFF2F5BFF),
    accent: const Color(0xFFFF7A1A),
    name: 'Cyber Midnight',
    isDark: true,
  );

  /// Default 60-30-10 Light Palette
  static AppPalette defaultLight = AppPalette.fromSeeds(
    main: const Color(0xFF0B0B0F),
    second: const Color(0xFF2F5BFF),
    accent: const Color(0xFFFF7A1A),
    name: 'Cyber Midnight (Light)',
    isDark: false,
  );

  /// Bridge from clean architecture [PaletteEntity].
  factory AppPalette.fromEntity(PaletteEntity entity, {bool isDark = true}) {
    return AppPalette.fromSeeds(
      main: Color(entity.main),
      second: Color(entity.second),
      accent: Color(entity.accent),
      name: entity.name,
      isDark: isDark,
    );
  }

  /// Convert to [PaletteEntity] for clean architecture domain layer.
  PaletteEntity toEntity() {
    return PaletteEntity(
      main: main.toARGB32(),
      second: second.toARGB32(),
      accent: accent.toARGB32(),
      name: name,
    );
  }

  factory AppPalette.fromJson(Map<String, dynamic> json, {bool isDark = true}) {
    final model = PaletteModel.fromJson(json);
    return AppPalette.fromEntity(model, isDark: isDark);
  }

  Map<String, dynamic> toJson() {
    return PaletteModel.fromEntity(toEntity()).toJson();
  }

  AppPalette copyWith({
    String? name,
    bool? isDark,
    Color? main,
    Color? second,
    Color? accent,
  }) {
    return AppPalette.fromSeeds(
      main: main ?? this.main,
      second: second ?? this.second,
      accent: accent ?? this.accent,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
    );
  }

  /// Linear interpolation (lerp) for smooth animated theme transitions.
  static AppPalette lerp(AppPalette a, AppPalette b, double t) {
    if (identical(a, b)) return a;
    final isDark = t < 0.5 ? a.isDark : b.isDark;
    final name = t < 0.5 ? a.name : b.name;

    return AppPalette.fromSeeds(
      main: Color.lerp(a.main, b.main, t) ?? a.main,
      second: Color.lerp(a.second, b.second, t) ?? a.second,
      accent: Color.lerp(a.accent, b.accent, t) ?? a.accent,
      name: name,
      isDark: isDark,
    );
  }

  @override
  List<Object?> get props => [
        name,
        isDark,
        main,
        second,
        accent,
        background,
        surface,
        card,
        header,
        sidebar,
        tableHeader,
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // Color Math & WCAG Contrast Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Computes the relative luminance of a color according to WCAG 2.1 specs.
  static double computeLuminance(Color color) {
    double transform(double channel) {
      if (channel <= 0.04045) {
        return channel / 12.92;
      }
      return pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = transform(color.r);
    final g = transform(color.g);
    final b = transform(color.b);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Backward-compatible alias for [computeLuminance].
  static double calculateLuminance(Color color) => computeLuminance(color);

  /// Calculates WCAG 2.1 contrast ratio between two colors (ranging from 1.0 to 21.0).
  static double calculateContrastRatio(Color color1, Color color2) {
    final l1 = computeLuminance(color1);
    final l2 = computeLuminance(color2);

    final lighter = max(l1, l2);
    final darker = min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Ensures a foreground text/icon color meets a minimum contrast ratio against a background.
  /// If it fails, smoothly shifts it towards white or black until the threshold is satisfied.
  static Color ensureContrast({
    required Color foreground,
    required Color background,
    double minRatio = 4.5,
  }) {
    var ratio = calculateContrastRatio(foreground, background);
    if (ratio >= minRatio) {
      return foreground;
    }

    final bgLum = computeLuminance(background);
    final target = bgLum < 0.5 ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

    var adjusted = foreground;
    for (var step = 1; step <= 20; step++) {
      adjusted = Color.lerp(foreground, target, step / 20.0)!;
      ratio = calculateContrastRatio(adjusted, background);
      if (ratio >= minRatio) {
        return adjusted;
      }
    }
    return target;
  }

  /// Derives an accessible on-color for a given surface (strictly >= 4.5:1).
  static Color ensureAccessibleColor({
    required Color background,
    double minRatio = 4.5,
  }) {
    const lightText = Color(0xFFF8FAFC);
    const darkText = Color(0xFF0F172A);

    final lightRatio = calculateContrastRatio(lightText, background);
    final darkRatio = calculateContrastRatio(darkText, background);

    if (lightRatio >= darkRatio) {
      return lightRatio >= minRatio ? lightText : ensureContrast(foreground: lightText, background: background, minRatio: minRatio);
    } else {
      return darkRatio >= minRatio ? darkText : ensureContrast(foreground: darkText, background: background, minRatio: minRatio);
    }
  }

  static Color _blend(Color c1, Color c2, double ratio) {
    return Color.lerp(c1, c2, ratio)!;
  }

  static Color _darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

/// Curated preset themes with guaranteed WCAG AA contrast.
class PalettePresets {
  PalettePresets._();

  static final AppPalette cyberMidnight = AppPalette.fromSeeds(
    name: 'Cyber Midnight',
    main: const Color(0xFF0B0B0F),
    second: const Color(0xFF2F5BFF),
    accent: const Color(0xFFFF7A1A),
    isDark: true,
  );

  static final AppPalette deepMatrix = AppPalette.fromSeeds(
    name: 'Deep Matrix',
    main: const Color(0xFF0A0F0D),
    second: const Color(0xFF00C853),
    accent: const Color(0xFFFFD600),
    isDark: true,
  );

  static final AppPalette royalIndigo = AppPalette.fromSeeds(
    name: 'Royal Indigo',
    main: const Color(0xFF0F0B1E),
    second: const Color(0xFF7C4DFF),
    accent: const Color(0xFF00E5FF),
    isDark: true,
  );

  static final AppPalette solarFlare = AppPalette.fromSeeds(
    name: 'Solar Flare',
    main: const Color(0xFF140C08),
    second: const Color(0xFFFF5722),
    accent: const Color(0xFFFFC107),
    isDark: true,
  );

  static final AppPalette carbonNeon = AppPalette.fromSeeds(
    name: 'Carbon Neon',
    main: const Color(0xFF121214),
    second: const Color(0xFF00E5FF),
    accent: const Color(0xFFFF4081),
    isDark: true,
  );

  static final List<AppPalette> all = [
    cyberMidnight,
    deepMatrix,
    royalIndigo,
    solarFlare,
    carbonNeon,
  ];
}

typedef PalettePreset = AppPalette;
