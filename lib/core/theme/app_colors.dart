import 'package:flutter/material.dart';

/// Semantic Design System Tokens for IT Network Monitor 2.0.
///
/// Features two distinct visual identities:
/// 1. Professional Light Theme: Corporate, clean, off-white, deep navy text, primary blue #1769FF.
/// 2. Cyber Neon Dark Theme: Cyber Operations Center, deep midnight navy #090D19, neon cyan #00E5FF,
///    electric violet #A78BFA, magenta alerts #FF4D91, glowing borders #263650.
class AppColors {
  AppColors._();

  // --- Professional Light Theme Palette ---
  static const Color lightBackground = Color(0xFFF3F6FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFEAF0F8);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF1769FF);
  static const Color lightPrimaryHover = Color(0xFF0956D9);
  static const Color lightAccent = Color(0xFF0AA6B7);
  static const Color lightTextPrimary = Color(0xFF172B4D);
  static const Color lightTextSecondary = Color(0xFF697B95);
  static const Color lightBorder = Color(0xFFE1E8F2);
  static const Color lightBorderSubtle = Color(0xFFEDF2F9);

  // --- Cyber Neon Dark Theme Palette ---
  static const Color darkBackground = Color(0xFF090D19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceSecondary = Color(0xFF151F33);
  static const Color darkElevatedSurface = Color(0xFF19243B);
  static const Color darkPrimary = Color(0xFF00E5FF); // Neon Cyan
  static const Color darkPrimaryHover = Color(0xFF33EBFF);
  static const Color darkSecondary = Color(0xFFA78BFA); // Electric Violet
  static const Color darkAccent = Color(0xFFFF4D91); // Magenta
  static const Color darkAccentBlue = Color(0xFF4388FF);
  static const Color darkTextPrimary = Color(0xFFF2F5FF);
  static const Color darkTextSecondary = Color(0xFF95A5C4);
  static const Color darkBorder = Color(0xFF263650);
  static const Color darkBorderGlow = Color(0x3300E5FF);

  // --- Universal Operational Statuses (Strict Consistency) ---
  static const Color statusOnline = Color(0xFF10B981); // Emerald / Neon Green
  static const Color statusDegraded = Color(0xFFF59E0B); // Amber
  static const Color statusOffline = Color(0xFFEF4444); // Crimson / Red
  static const Color statusUnknown = Color(0xFF94A3B8); // Slate 400
  static const Color statusMaintenance = Color(0xFF8B5CF6); // Violet

  // Backward compatibility aliases
  static const Color primary = darkPrimary;
  static const Color primaryHover = darkPrimaryHover;
  static const Color accent = darkPrimary;
  static const Color statusUp = statusOnline;
  static const Color statusDown = statusOffline;
  static const Color statusUnreachable = statusOffline;
  static const Color darkCard = darkSurface;
  static const Color lightCard = lightSurface;
  static const Color textPrimaryDark = darkTextPrimary;
  static const Color textSecondaryDark = darkTextSecondary;
  static const Color textPrimaryLight = lightTextPrimary;
  static const Color textSecondaryLight = lightTextSecondary;

  // --- Factory Identity Colors (Distinct from operational statuses) ---
  static const Color factoryRnf = Color(0xFF00B4D8); // Cyan Blue for RNF
  static const Color factoryBnf = Color(0xFF8B5CF6); // Royal Violet for BNF
  static const Color factoryAll = Color(0xFF3B82F6); // Cobalt Blue for All
}

/// ThemeExtension providing type-safe semantic tokens to BuildContext.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceSecondary;
  final Color elevatedSurface;
  final Color primary;
  final Color primaryHover;
  final Color secondary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderGlow;
  final Color statusOnline;
  final Color statusDegraded;
  final Color statusOffline;
  final Color statusUnknown;
  final Color statusMaintenance;
  final Color factoryRnf;
  final Color factoryBnf;
  final Color factoryAll;

  Color get cardBorder => border;
  Color get shadowColor => isDark ? Colors.black : const Color(0x1A000000);

  const AppThemeTokens({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.elevatedSurface,
    required this.primary,
    required this.primaryHover,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderGlow,
    required this.statusOnline,
    required this.statusDegraded,
    required this.statusOffline,
    required this.statusUnknown,
    required this.statusMaintenance,
    required this.factoryRnf,
    required this.factoryBnf,
    required this.factoryAll,
  });

  static const light = AppThemeTokens(
    isDark: false,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceSecondary: AppColors.lightSurfaceSecondary,
    elevatedSurface: AppColors.lightElevatedSurface,
    primary: AppColors.lightPrimary,
    primaryHover: AppColors.lightPrimaryHover,
    secondary: Color(0xFF6366F1),
    accent: AppColors.lightAccent,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    border: AppColors.lightBorder,
    borderGlow: Color(0x1A1769FF),
    statusOnline: AppColors.statusOnline,
    statusDegraded: AppColors.statusDegraded,
    statusOffline: AppColors.statusOffline,
    statusUnknown: AppColors.statusUnknown,
    statusMaintenance: AppColors.statusMaintenance,
    factoryRnf: AppColors.factoryRnf,
    factoryBnf: AppColors.factoryBnf,
    factoryAll: AppColors.factoryAll,
  );

  static const dark = AppThemeTokens(
    isDark: true,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceSecondary: AppColors.darkSurfaceSecondary,
    elevatedSurface: AppColors.darkElevatedSurface,
    primary: AppColors.darkPrimary,
    primaryHover: AppColors.darkPrimaryHover,
    secondary: AppColors.darkSecondary,
    accent: AppColors.darkAccent,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    border: AppColors.darkBorder,
    borderGlow: AppColors.darkBorderGlow,
    statusOnline: AppColors.statusOnline,
    statusDegraded: AppColors.statusDegraded,
    statusOffline: AppColors.statusOffline,
    statusUnknown: AppColors.statusUnknown,
    statusMaintenance: AppColors.statusMaintenance,
    factoryRnf: AppColors.factoryRnf,
    factoryBnf: AppColors.factoryBnf,
    factoryAll: AppColors.factoryAll,
  );

  @override
  AppThemeTokens copyWith({
    bool? isDark,
    Color? background,
    Color? surface,
    Color? surfaceSecondary,
    Color? elevatedSurface,
    Color? primary,
    Color? primaryHover,
    Color? secondary,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? borderGlow,
    Color? statusOnline,
    Color? statusDegraded,
    Color? statusOffline,
    Color? statusUnknown,
    Color? statusMaintenance,
    Color? factoryRnf,
    Color? factoryBnf,
    Color? factoryAll,
  }) {
    return AppThemeTokens(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSecondary: surfaceSecondary ?? this.surfaceSecondary,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      borderGlow: borderGlow ?? this.borderGlow,
      statusOnline: statusOnline ?? this.statusOnline,
      statusDegraded: statusDegraded ?? this.statusDegraded,
      statusOffline: statusOffline ?? this.statusOffline,
      statusUnknown: statusUnknown ?? this.statusUnknown,
      statusMaintenance: statusMaintenance ?? this.statusMaintenance,
      factoryRnf: factoryRnf ?? this.factoryRnf,
      factoryBnf: factoryBnf ?? this.factoryBnf,
      factoryAll: factoryAll ?? this.factoryAll,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSecondary: Color.lerp(
        surfaceSecondary,
        other.surfaceSecondary,
        t,
      )!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderGlow: Color.lerp(borderGlow, other.borderGlow, t)!,
      statusOnline: Color.lerp(statusOnline, other.statusOnline, t)!,
      statusDegraded: Color.lerp(statusDegraded, other.statusDegraded, t)!,
      statusOffline: Color.lerp(statusOffline, other.statusOffline, t)!,
      statusUnknown: Color.lerp(statusUnknown, other.statusUnknown, t)!,
      statusMaintenance: Color.lerp(
        statusMaintenance,
        other.statusMaintenance,
        t,
      )!,
      factoryRnf: Color.lerp(factoryRnf, other.factoryRnf, t)!,
      factoryBnf: Color.lerp(factoryBnf, other.factoryBnf, t)!,
      factoryAll: Color.lerp(factoryAll, other.factoryAll, t)!,
    );
  }
}

extension AppThemeContextExtension on BuildContext {
  AppThemeTokens get appTokens =>
      Theme.of(this).extension<AppThemeTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppThemeTokens.dark
          : AppThemeTokens.light);
}

extension ThemeDataAppTokens on ThemeData {
  AppThemeTokens get appTokens =>
      extension<AppThemeTokens>() ??
      (brightness == Brightness.dark
          ? AppThemeTokens.dark
          : AppThemeTokens.light);
}
