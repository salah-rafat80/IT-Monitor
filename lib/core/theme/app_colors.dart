import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette
  static const Color primary = Color(0xFF0F62FE); // IT Blue
  static const Color primaryHover = Color(0xFF0043CE);
  static const Color accent = Color(0xFF00D68F); // Cyber Teal/Green

  // Dark Theme Palette (Default for Monitoring Dashboard)
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkCard = Color(0xFF334155); // Slate 700
  static const Color darkBorder = Color(0xFF475569); // Slate 600

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200

  // Device Status Colors (Strict Operational Standards)
  static const Color statusUp = Color(0xFF10B981); // Emerald 500
  static const Color statusDegraded = Color(0xFFF59E0B); // Amber 500
  static const Color statusDown = Color(0xFFEF4444); // Red 500
  static const Color statusUnreachable = Color(0xFF8B5CF6); // Purple 500
  static const Color statusMaintenance = Color(0xFF64748B); // Slate 500
  static const Color statusUnknown = Color(0xFF94A3B8); // Slate 400

  // Status Background Badges (Dark Mode)
  static const Color statusUpBgDark = Color(0x1A10B981);
  static const Color statusDegradedBgDark = Color(0x1AF59E0B);
  static const Color statusDownBgDark = Color(0x1AEF4444);
  static const Color statusUnreachableBgDark = Color(0x1A8B5CF6);
  static const Color statusMaintenanceBgDark = Color(0x1A64748B);

  // Status Background Badges (Light Mode)
  static const Color statusUpBgLight = Color(0xFFD1FAE5);
  static const Color statusDegradedBgLight = Color(0xFFFEF3C7);
  static const Color statusDownBgLight = Color(0xFFFEE2E2);
  static const Color statusUnreachableBgLight = Color(0xFFEDE9FE);
  static const Color statusMaintenanceBgLight = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
}
