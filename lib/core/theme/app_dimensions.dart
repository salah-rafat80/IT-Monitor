/// Standard design system spacing and border radius scales for IT Network Monitor 2.0.
///
/// Follows an 8pt grid system with 4pt half-steps for micro-spacing.
class AppSpacing {
  AppSpacing._();

  /// 2.0 - Micro spacing, badge internal padding, divider offsets
  static const double xxs = 2.0;

  /// 4.0 - Tight spacing between icon and label, chip vertical padding
  static const double xs = 4.0;

  /// 8.0 - Standard element spacing, small card padding
  static const double sm = 8.0;

  /// 12.0 - Grid gaps, medium card padding, filter item spacing
  static const double md = 12.0;

  /// 16.0 - Standard card internal padding, dialog inner margins
  static const double lg = 16.0;

  /// 24.0 - Page horizontal padding, major section gaps
  static const double xl = 24.0;

  /// 32.0 - Hero spacing, large empty state padding
  static const double xxl = 32.0;
}

/// Standard design system border radius scale.
class AppRadius {
  AppRadius._();

  /// 4.0 - Tooltips, small badges
  static const double xs = 4.0;

  /// 6.0 - Status chips, table row indicators, small buttons
  static const double sm = 6.0;

  /// 8.0 - Dropdowns, text fields, medium buttons
  static const double md = 8.0;

  /// 12.0 - Cards, modal bottom sheets, table containers
  static const double lg = 12.0;

  /// 16.0 - Large modal dialogs, featured cards
  static const double xl = 16.0;

  /// 999.0 - Full pill / circular controls
  static const double pill = 999.0;
}
