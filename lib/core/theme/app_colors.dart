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
  Color get statusStale => palette.statusStale;

  // --- Dynamic Helper Getters ---
  bool get isDark => palette.isDark;
  Color get surfaceSecondary => palette.surfaceContainer;
  Color get elevatedSurface => palette.surfaceContainerHigh;
  Color get shadowColor => palette.shadow;
  Color get transparent => const Color(0x00000000);

  // Core semantic aliases
  Color get primary => palette.second;
  Color get onPrimary => palette.onSecond;
  Color get secondary => palette.accent;
  Color get onSecondary => palette.onAccent;
  Color get textPrimary => palette.onSurface;
  Color get textSecondary => palette.onSurfaceVariant;
  Color get cardBorder => palette.border;

  // Backward compatibility alias
  Color get success => palette.statusOnline;
  Color get onSuccess => palette.onStatusOnline;
  Color get warning => palette.statusDegraded;
  Color get onWarning => palette.onStatusDegraded;
  Color get error => palette.statusOffline;
  Color get onError => palette.onStatusOffline;
  Color get info => palette.second;
  Color get onInfo => palette.onSecond;

  // Status aliases
  Color get statusUp => palette.statusOnline;
  Color get statusDown => palette.statusOffline;
  Color get statusUnreachable => palette.statusOffline;

  // Factory aliases
  Color get factoryRnf => palette.second;
  Color get factoryBnf => palette.statusMaintenance;
  Color get factoryAll => palette.accent;

  // Static Fallback Defaults
  static final AppColors defaultDark = AppColors(palette: AppPalette.defaultDark);
  static final AppColors defaultLight = AppColors(palette: AppPalette.defaultLight);

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
  Color get darkCard => palette.surfaceContainerLow;
  Color get lightCard => palette.surfaceContainerLowest;
  Color get textPrimaryDark => palette.onSurface;
  Color get textSecondaryDark => palette.onSurfaceVariant;
  Color get textPrimaryLight => palette.onSurface;
  Color get textSecondaryLight => palette.onSurfaceVariant;
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
