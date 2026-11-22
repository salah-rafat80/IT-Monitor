import 'package:flutter/material.dart';

import '../../features/theme/presentation/theme/app_palette.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_dimensions.dart';

/// Dynamic Material Design 3 Theme System for IT Network Monitor 2.0.
///
/// Builds complete M3 component themes generated dynamically from any [AppPalette]
/// following the 60-30-10 palette rules:
/// - Main (60%): Scaffolds, backgrounds, large surfaces.
/// - Second (30%): Cards, app bars, containers, secondary surfaces.
/// - Accent (10%): CTAs, FABs, highlights, active states, interactive controls.
class AppTheme {
  AppTheme._();

  /// Default dark theme instance for startup before Cubit is initialized.
  static ThemeData get darkTheme => buildTheme(palette: AppPalette.defaultDark, isDark: true);

  /// Default light theme instance.
  static ThemeData get lightTheme => buildTheme(palette: AppPalette.defaultLight, isDark: false);

  /// Builds a fully dynamic M3 [ThemeData] from any [AppPalette] seeds and mode.
  static ThemeData buildTheme({
    required AppPalette palette,
    required bool isDark,
  }) {
    final activePalette = palette.copyWith(isDark: isDark);
    final themeTokens = AppColors(palette: activePalette);

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: activePalette.second,
      onPrimary: activePalette.onSecond,
      primaryContainer: activePalette.second.withValues(alpha: isDark ? 0.25 : 0.15),
      onPrimaryContainer: isDark ? const Color(0xFFD0E1FD) : const Color(0xFF001B3F),
      secondary: activePalette.accent,
      onSecondary: activePalette.onAccent,
      secondaryContainer: activePalette.accent.withValues(alpha: isDark ? 0.25 : 0.15),
      onSecondaryContainer: isDark ? const Color(0xFFFFD9E2) : const Color(0xFF4E1D00),
      tertiary: activePalette.accent,
      onTertiary: activePalette.onAccent,
      tertiaryContainer: activePalette.accent.withValues(alpha: 0.2),
      onTertiaryContainer: activePalette.onAccent,
      error: activePalette.statusOffline,
      onError: activePalette.onStatusOffline,
      errorContainer: activePalette.statusOfflineSurface,
      onErrorContainer: activePalette.onStatusOffline,
      surface: activePalette.surface,
      onSurface: activePalette.onSurface,
      onSurfaceVariant: activePalette.onSurfaceVariant,
      surfaceContainerLowest: activePalette.surfaceContainerLowest,
      surfaceContainerLow: activePalette.surfaceContainerLow,
      surfaceContainer: activePalette.surfaceContainer,
      surfaceContainerHigh: activePalette.surfaceContainerHigh,
      surfaceContainerHighest: activePalette.surfaceContainerHighest,
      outline: activePalette.border,
      outlineVariant: activePalette.divider,
      shadow: activePalette.shadow,
      scrim: activePalette.overlay,
      inverseSurface: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
      onInverseSurface: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      inversePrimary: isDark ? const Color(0xFF2F5BFF) : const Color(0xFF00E5FF),
    );

    final textTheme = AppTypography.buildTextTheme(
      onSurface: activePalette.onSurface,
      onSurfaceVariant: activePalette.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: activePalette.second,
      scaffoldBackgroundColor: activePalette.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [themeTokens],

      // Instant, zero-lag page transitions on desktop platforms
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.linux: _NoAnimationPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoAnimationPageTransitionsBuilder(),
        },
      ),

      // --- M3 Card Theme ---
      cardTheme: CardThemeData(
        color: activePalette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: activePalette.border, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // --- M3 Divider Theme ---
      dividerTheme: DividerThemeData(
        color: activePalette.divider,
        thickness: 1,
        space: 1,
      ),

      // --- M3 Button Themes ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 40),
          backgroundColor: activePalette.accent,
          foregroundColor: activePalette.onAccent,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 40),
          backgroundColor: activePalette.surfaceContainerLow,
          foregroundColor: activePalette.onSurface,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: activePalette.border),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 40),
          foregroundColor: activePalette.second,
          side: BorderSide(color: activePalette.border, width: 1),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          foregroundColor: activePalette.second,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: activePalette.accent,
        foregroundColor: activePalette.onAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        elevation: 3,
      ),

      // --- M3 DataTable Theme ---
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.titleSmall?.copyWith(
          color: activePalette.onTableHeader,
          fontWeight: FontWeight.bold,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: activePalette.onTableRow,
        ),
        headingRowColor: WidgetStatePropertyAll(
          activePalette.tableHeader,
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return activePalette.second.withValues(alpha: isDark ? 0.15 : 0.08);
          }
          if (states.contains(WidgetState.hovered)) {
            return activePalette.surfaceContainerHigh.withValues(alpha: 0.5);
          }
          return Colors.transparent;
        }),
        dividerThickness: 1,
      ),

      // --- M3 Input Decoration Theme ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: activePalette.input,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: activePalette.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: activePalette.inputHint,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: activePalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: activePalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: activePalette.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: activePalette.statusOffline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: activePalette.statusOffline, width: 2),
        ),
      ),

      // --- M3 Navigation Bar Theme ---
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: activePalette.surfaceContainer,
        elevation: 0,
        indicatorColor: activePalette.second.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: activePalette.accent);
          }
          return IconThemeData(color: activePalette.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: activePalette.onSurface,
              fontWeight: FontWeight.bold,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: activePalette.onSurfaceVariant,
          );
        }),
      ),

      // --- M3 Navigation Rail Theme ---
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: activePalette.sidebar,
        elevation: 0,
        indicatorColor: activePalette.second.withValues(alpha: 0.25),
        selectedIconTheme: IconThemeData(
          color: activePalette.accent,
        ),
        unselectedIconTheme: IconThemeData(
          color: activePalette.onSurfaceVariant,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: activePalette.onSidebar,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: activePalette.onSurfaceVariant,
        ),
      ),

      // --- M3 App Bar Theme ---
      appBarTheme: AppBarTheme(
        backgroundColor: activePalette.header,
        foregroundColor: activePalette.onHeader,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: activePalette.onHeader),
        titleTextStyle: TextStyle(
          color: activePalette.onHeader,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // --- M3 Dialog & BottomSheet Theme ---
      dialogTheme: DialogThemeData(
        backgroundColor: activePalette.surfaceContainerHigh,
        elevation: 6,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: activePalette.border, width: 1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: activePalette.onSurface,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: activePalette.onSurfaceVariant,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: activePalette.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: activePalette.border, width: 1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // --- M3 Chip Theme ---
      chipTheme: ChipThemeData(
        backgroundColor: activePalette.surfaceContainerLow,
        disabledColor: activePalette.disabled.withValues(alpha: 0.1),
        selectedColor: activePalette.second.withValues(alpha: 0.2),
        secondarySelectedColor: activePalette.accent.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: activePalette.onSurface,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: activePalette.onSurface,
        ),
        brightness: isDark ? Brightness.dark : Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: activePalette.border),
        ),
      ),

      // --- M3 Checkbox Theme ---
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return activePalette.accent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(activePalette.onAccent),
        side: BorderSide(color: activePalette.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
      ),

      // --- M3 Switch Theme ---
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return activePalette.onAccent;
          }
          return activePalette.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return activePalette.accent;
          }
          return activePalette.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStatePropertyAll(activePalette.border),
      ),

      // --- M3 Slider Theme ---
      sliderTheme: SliderThemeData(
        activeTrackColor: activePalette.accent,
        inactiveTrackColor: activePalette.surfaceContainerHighest,
        thumbColor: activePalette.accent,
        overlayColor: activePalette.accent.withValues(alpha: 0.2),
      ),

      // --- M3 SnackBar Theme ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: activePalette.surfaceContainerHighest,
        contentTextStyle: TextStyle(
          color: activePalette.onSurface,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: activePalette.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: activePalette.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // --- M3 TabBar Theme ---
      tabBarTheme: TabBarThemeData(
        labelColor: activePalette.onSurface,
        unselectedLabelColor: activePalette.onSurfaceVariant,
        indicatorColor: activePalette.accent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: textTheme.titleSmall,
      ),

      // --- M3 Tooltip Theme ---
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: activePalette.border),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFFF8FAFC),
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

/// Instant, zero-lag page transition builder for enterprise desktop applications.
class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
