import 'package:flutter/material.dart';

import '../../features/theme/presentation/theme/app_palette.dart';

/// Semantic Design System Tokens for IT Network Monitor 2.0 (Material Design 3).
///
/// Implements [ThemeExtension<AppColors>] holding the 60-30-10 dynamic [AppPalette].
/// Fully dynamic at runtime with smooth linear interpolation (lerp).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final AppPalette palette;

  const AppColors({required this.palette});

  factory AppColors.fromPalette(AppPalette palette) => AppColors(palette: palette);

  // --- 60-30-10 Core Seeds ---
  Color get main => palette.main;
  Color get second => palette.second;
  Color get accent => palette.accent;
  Color get onPrimary => palette.onSecond;

  // --- Surfaces & Containers ---
  Color get background => palette.background;
  Color get surface => palette.surface;
  Color get surfaceVariant => palette.surfaceVariant;
  Color get surfaceContainerLowest => palette.surfaceContainerLowest;
  Color get surfaceContainerLow => palette.surfaceContainerLow;
  Color get surfaceContainer => palette.surfaceContainer;
  Color get surfaceContainerHigh => palette.surfaceContainerHigh;
  Color get surfaceContainerHighest => palette.surfaceContainerHighest;
  Color get card => palette.card;
  Color get header => palette.header;
  Color get sidebar => palette.sidebar;
  Color get tableHeader => palette.tableHeader;
  Color get tableRow => palette.tableRow;
  Color get tableRowAlternate => palette.tableRowAlternate;
  Color get input => palette.input;

  // --- Accessible onX Text & Icons (WCAG AA >= 4.5:1) ---
  Color get onBackground => palette.onBackground;
  Color get onSurface => palette.onSurface;
  Color get onSurfaceVariant => palette.onSurfaceVariant;
  Color get onMain => palette.onMain;
  Color get onSecond => palette.onSecond;
  Color get onAccent => palette.onAccent;
  Color get onCard => palette.onCard;
  Color get onHeader => palette.onHeader;
  Color get onSidebar => palette.onSidebar;
  Color get onTableHeader => palette.onTableHeader;
  Color get onTableRow => palette.onTableRow;
  Color get onInput => palette.onInput;
  Color get inputHint => palette.inputHint;

  // --- Structure & Lines ---
  Color get border => palette.border;
  Color get borderGlow => palette.borderGlow;
  Color get divider => palette.divider;
  Color get disabled => palette.disabled;
  Color get shadow => palette.shadow;
  Color get overlay => palette.overlay;

  // --- Status Semantic Pairs (Background + Accessible Text) ---
  Color get statusOnline => palette.statusOnline;
  Color get statusOnlineSurface => palette.statusOnlineSurface;
  Color get onStatusOnline => palette.onStatusOnline;

  Color get statusOffline => palette.statusOffline;
  Color get statusOfflineSurface => palette.statusOfflineSurface;
  Color get onStatusOffline => palette.onStatusOffline;

  Color get statusDegraded => palette.statusDegraded;
  Color get statusDegradedSurface => palette.statusDegradedSurface;
  Color get onStatusDegraded => palette.onStatusDegraded;

  Color get statusMaintenance => palette.statusMaintenance;
  Color get statusMaintenanceSurface => palette.statusMaintenanceSurface;
  Color get onStatusMaintenance => palette.onStatusMaintenance;

  Color get statusUnknown => palette.statusUnknown;
  Color get statusUnknownSurface => palette.statusUnknownSurface;
  Color get onStatusUnknown => palette.onStatusUnknown;

  // --- Dynamic Helper Getters ---
  bool get isDark => palette.isDark;
  Color get surfaceSecondary => palette.surfaceContainer;
  Color get elevatedSurface => palette.surfaceContainerHigh;
  Color get shadowColor => palette.shadow;

  // Backward compatibility alias
  Color get success => palette.statusOnline;
  Color get onSuccess => palette.onStatusOnline;
  Color get warning => palette.statusDegraded;
  Color get onWarning => palette.onStatusDegraded;
  Color get error => palette.statusOffline;
  Color get onError => palette.onStatusOffline;
  Color get info => palette.second;
  Color get onInfo => palette.onSecond;

  // Static Fallback Defaults
  static final AppColors defaultDark = AppColors(palette: AppPalette.defaultDark);
  static final AppColors defaultLight = AppColors(palette: AppPalette.defaultLight);

  // --- Static Constant Definitions for Legacy Non-Context References ---
  static const Color darkBackground = Color(0xFF0B0B0F);
  static const Color darkSurface = Color(0xFF111625);
  static const Color darkPrimary = Color(0xFF2F5BFF);
  static const Color darkSecondary = Color(0xFF2F5BFF);
  static const Color darkAccent = Color(0xFFFF7A1A);
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkOutline = Color(0xFF263650);
  static const Color darkOutlineVariant = Color(0xFF1E293B);
  static const Color darkSurfaceContainerLowest = Color(0xFF080B12);
  static const Color darkSurfaceContainerLow = Color(0xFF111625);
  static const Color darkSurfaceContainer = Color(0xFF151F33);
  static const Color darkSurfaceContainerHigh = Color(0xFF1C2A44);
  static const Color darkSurfaceContainerHighest = Color(0xFF243554);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF263650);
  static const Color darkBorderGlow = Color(0x33FF7A1A);
  static const Color darkError = Color(0xFFEF4444);
  static const Color darkOnError = Color(0xFFFFFFFF);
  static const Color darkErrorContainer = Color(0xFF7F1D1D);
  static const Color darkOnErrorContainer = Color(0xFFFCA5A5);
  static const Color darkPrimaryContainer = Color(0xFF1E3A8A);
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkOnPrimaryContainer = Color(0xFFD0E1FD);
  static const Color darkSecondaryContainer = Color(0xFF1E3A8A);
  static const Color darkOnSecondary = Color(0xFFFFFFFF);
  static const Color darkOnSecondaryContainer = Color(0xFFEADDFF);
  static const Color darkTertiary = Color(0xFFFF7A1A);
  static const Color darkOnTertiary = Color(0xFF0B0B0F);
  static const Color darkTertiaryContainer = Color(0xFF83003C);
  static const Color darkOnTertiaryContainer = Color(0xFFFFD9E2);

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF2F5BFF);
  static const Color lightSecondary = Color(0xFF2F5BFF);
  static const Color lightAccent = Color(0xFFFF7A1A);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightOnSurfaceVariant = Color(0xFF475569);
  static const Color lightOutline = Color(0xFFCBD5E1);
  static const Color lightOutlineVariant = Color(0xFFE2E8F0);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF8FAFC);
  static const Color lightSurfaceContainer = Color(0xFFEDF2F7);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color lightSurfaceContainerHighest = Color(0xFFCBD5E1);
  static const Color lightPrimaryContainer = Color(0xFFD0E1FD);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnPrimaryContainer = Color(0xFF001B3F);
  static const Color lightSecondaryContainer = Color(0xFFE0E7FF);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightOnSecondaryContainer = Color(0xFF1E1B4B);
  static const Color lightTertiary = Color(0xFFFF7A1A);
  static const Color lightOnTertiary = Color(0xFF0B0B0F);
  static const Color lightTertiaryContainer = Color(0xFFFFE0B2);
  static const Color lightOnTertiaryContainer = Color(0xFF4E1D00);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFEE2E2);
  static const Color lightOnErrorContainer = Color(0xFF991B1B);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightBorder = Color(0xFFCBD5E1);

  // Static Backward Compatibility Aliases
  static const Color primary = darkPrimary;
  static const Color cardBorder = darkBorder;
  static const Color darkCard = darkSurfaceContainerLow;
  static const Color lightCard = lightSurfaceContainerLowest;
  static const Color darkSurfaceSecondary = darkSurfaceContainer;
  static const Color lightSurfaceSecondary = lightSurfaceContainer;
  static const Color textPrimaryDark = darkTextPrimary;
  static const Color textSecondaryDark = darkTextSecondary;
  static const Color textPrimaryLight = lightTextPrimary;
  static const Color textSecondaryLight = lightTextSecondary;
  static const Color staticStatusOnline = Color(0xFF10B981);
  static const Color staticStatusDegraded = Color(0xFFF59E0B);
  static const Color staticStatusOffline = Color(0xFFEF4444);
  static const Color staticStatusUnknown = Color(0xFF94A3B8);
  static const Color staticStatusMaintenance = Color(0xFF8B5CF6);
  static const Color factoryRnf = Color(0xFF2F5BFF);
  static const Color factoryBnf = Color(0xFF8B5CF6);
  static const Color factoryAll = Color(0xFFFF7A1A);

  @override
  AppColors copyWith({AppPalette? palette}) {
    return AppColors(palette: palette ?? this.palette);
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      palette: AppPalette.lerp(palette, other.palette, t),
    );
  }
}

/// Dynamic instance tokens on [AppColors].
extension AppColorsTokens on AppColors {
  Color get primary => palette.second;
  Color get onPrimary => palette.onSecond;
  Color get textPrimary => palette.onSurface;
  Color get textSecondary => palette.onSurfaceVariant;
  Color get cardBorder => palette.border;
  Color get darkCard => palette.surfaceContainerLow;
  Color get lightCard => palette.surfaceContainerLowest;
  Color get textPrimaryDark => const Color(0xFFF8FAFC);
  Color get textSecondaryDark => const Color(0xFF94A3B8);
  Color get textPrimaryLight => const Color(0xFF0F172A);
  Color get textSecondaryLight => const Color(0xFF475569);
  Color get statusUp => palette.statusOnline;
  Color get statusDown => palette.statusOffline;
  Color get statusUnreachable => palette.statusOffline;
  Color get factoryRnf => palette.second;
  Color get factoryBnf => palette.statusMaintenance;
  Color get factoryAll => palette.accent;
}

/// Backwards compatibility alias for AppColors ThemeExtension.
typedef AppThemeTokens = AppColors;

/// BuildContext helper extensions.
extension BuildContextColorsExtension on BuildContext {
  /// Direct access to dynamic design tokens: context.colors.accent, context.colors.surface, etc.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.defaultDark
          : AppColors.defaultLight);

  /// Backwards-compatible alias for context.colors.
  AppColors get appTokens => colors;

  /// Current active palette.
  AppPalette get palette => colors.palette;
}

extension ThemeDataColorsExtension on ThemeData {
  AppColors get colors =>
      extension<AppColors>() ??
      (brightness == Brightness.dark
          ? AppColors.defaultDark
          : AppColors.defaultLight);

  AppColors get appTokens => colors;
}
