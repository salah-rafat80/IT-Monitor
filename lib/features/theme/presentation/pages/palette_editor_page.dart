import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../theme/app_palette.dart';

class PaletteEditorPage extends StatefulWidget {
  const PaletteEditorPage({super.key});

  @override
  State<PaletteEditorPage> createState() => _PaletteEditorPageState();
}

class _PaletteEditorPageState extends State<PaletteEditorPage> {
  // Common enterprise palette colors for quick seed picking
  static const List<Color> _mainColorOptions = [
    Color(0xFF0B0B0F), // Midnight Black (Default 60%)
    Color(0xFF090D19), // Deep Cyber Navy
    Color(0xFF0A0F0D), // Deep Matrix Carbon
    Color(0xFF0B0E17), // Obsidian
    Color(0xFF12100E), // Espresso Dark
    Color(0xFF1E293B), // Slate 800
    Color(0xFFF8FAFD), // Crisp Light
    Color(0xFFF1F5F9), // Light Slate
  ];

  static const List<Color> _secondColorOptions = [
    Color(0xFF2F5BFF), // Electric Blue (Default 30%)
    Color(0xFF151F33), // Cyber Slate
    Color(0xFF064E3B), // Forest Teal
    Color(0xFF4F46E5), // Royal Indigo
    Color(0xFFB45309), // Amber Brown
    Color(0xFF0284C7), // Sky Cobalt
    Color(0xFF7C3AED), // Deep Violet
    Color(0xFF0D9488), // Ocean Teal
  ];

  static const List<Color> _accentColorOptions = [
    Color(0xFFFF7A1A), // Sunset Orange (Default 10%)
    Color(0xFF00E5FF), // Neon Cyan
    Color(0xFF10B981), // Emerald Neon
    Color(0xFFF43F5E), // Rose Magenta
    Color(0xFF06B6D4), // Cyan Spark
    Color(0xFFEAB308), // Solar Gold
    Color(0xFFA855F7), // Neon Purple
    Color(0xFF3B82F6), // Bright Blue
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.colors;
    final cubit = context.watch<ThemeCubit>();
    final palette = cubit.state.palette;
    final isDark = cubit.state.isDark;

    // Contrast calculations
    final onMainRatio = AppPalette.calculateContrastRatio(palette.onMain, palette.main);
    final onSecondRatio = AppPalette.calculateContrastRatio(palette.onSecond, palette.second);
    final onAccentRatio = AppPalette.calculateContrastRatio(palette.onAccent, palette.accent);

    return Scaffold(
      backgroundColor: tokens.main,
      appBar: AppBar(
        title: const Text('Dynamic Palette & Token Editor'),
        backgroundColor: tokens.surfaceContainerLow,
        foregroundColor: tokens.onMain,
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => cubit.toggleMode(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset Defaults'),
            onPressed: () => cubit.resetToDefault(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Intro & 60-30-10 Overview Banner ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.second.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.palette_rounded, color: tokens.accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '60-30-10 Dynamic Theming Engine',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tokens.onMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Main (60% surfaces/backgrounds), Second (30% cards/containers), Accent (10% highlights & CTAs). '
                          'All sub-tokens and WCAG AA contrast colors are derived automatically in real-time.',
                          style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Curated Presets Bar ──
            Text(
              'Preset Palettes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: tokens.onMain,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: PalettePresets.all.map((preset) {
                final isSelected = preset.name == palette.name;
                return InkWell(
                  onTap: () => cubit.setPalette(preset),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.second.withValues(alpha: 0.22)
                          : tokens.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? tokens.accent : tokens.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            width: 21,
                            height: 12,
                            child: Row(
                              children: [
                                Expanded(child: Container(color: preset.main)),
                                Expanded(child: Container(color: preset.second)),
                                Expanded(child: Container(color: preset.accent)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: tokens.onMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── The 3 Core Seed Pickers ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final pickers = [
                  _buildSeedCard(
                    title: 'Main (60%)',
                    subtitle: 'Backdrop, Scaffold & Large Surfaces',
                    currentColor: palette.main,
                    options: _mainColorOptions,
                    role: SeedRole.main,
                    contrastRatio: onMainRatio,
                    onColor: palette.onMain,
                    cubit: cubit,
                    tokens: tokens,
                  ),
                  _buildSeedCard(
                    title: 'Second (30%)',
                    subtitle: 'Cards, Bars, Containers & Navigation',
                    currentColor: palette.second,
                    options: _secondColorOptions,
                    role: SeedRole.second,
                    contrastRatio: onSecondRatio,
                    onColor: palette.onSecond,
                    cubit: cubit,
                    tokens: tokens,
                  ),
                  _buildSeedCard(
                    title: 'Accent (10%)',
                    subtitle: 'CTAs, Active States & Badges',
                    currentColor: palette.accent,
                    options: _accentColorOptions,
                    role: SeedRole.accent,
                    contrastRatio: onAccentRatio,
                    onColor: palette.onAccent,
                    cubit: cubit,
                    tokens: tokens,
                  ),
                ];

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: pickers[0]),
                      const SizedBox(width: 16),
                      Expanded(child: pickers[1]),
                      const SizedBox(width: 16),
                      Expanded(child: pickers[2]),
                    ],
                  );
                }

                return Column(
                  children: [
                    pickers[0],
                    const SizedBox(height: 16),
                    pickers[1],
                    const SizedBox(height: 16),
                    pickers[2],
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Live Component Preview ──
            Text(
              'Live Component Preview (Instant Real-time Re-theming)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: tokens.onMain,
              ),
            ),
            const SizedBox(height: 16),
            _buildLivePreview(tokens),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedCard({
    required String title,
    required String subtitle,
    required Color currentColor,
    required List<Color> options,
    required SeedRole role,
    required double contrastRatio,
    required Color onColor,
    required ThemeCubit cubit,
    required AppColors tokens,
  }) {
    final passesAA = contrastRatio >= 4.5;
    final hexString = '#${(currentColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: tokens.onMain,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.border, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          // Hex code & WCAG badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hexString,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: tokens.onMain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: passesAA
                      ? tokens.success.withValues(alpha: 0.15)
                      : tokens.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: passesAA ? tokens.success : tokens.error,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      passesAA ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      size: 14,
                      color: passesAA ? tokens.success : tokens.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${contrastRatio.toStringAsFixed(1)}:1 (AA)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: passesAA ? tokens.success : tokens.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Swatches
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((col) {
              final isCurrent = col.toARGB32() == currentColor.toARGB32();
              return InkWell(
                onTap: () => cubit.updateSeed(role, col),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? tokens.accent : tokens.border,
                      width: isCurrent ? 3 : 1,
                    ),
                  ),
                  child: isCurrent
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: AppPalette.ensureAccessibleColor(background: col),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(AppColors tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Buttons row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Primary CTA (Accent)'),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.layers_rounded, size: 18),
                label: const Text('Secondary (Second Container)'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Outlined Action'),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Text Action'),
              ),
              FloatingActionButton.small(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Interactive Controls row
          Row(
            children: [
              Switch(value: true, onChanged: (_) {}),
              const SizedBox(width: 8),
              Text('Switch', style: TextStyle(color: tokens.onMain, fontSize: 13)),
              const SizedBox(width: 20),
              Checkbox(value: true, onChanged: (_) {}),
              Text('Checkbox', style: TextStyle(color: tokens.onMain, fontSize: 13)),
              const SizedBox(width: 20),
              Expanded(
                child: Slider(value: 0.7, onChanged: (_) {}),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Badges, Chips & Status Chips
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(Icons.circle, size: 12, color: tokens.success),
                label: const Text('Online (Success)'),
              ),
              Chip(
                avatar: Icon(Icons.circle, size: 12, color: tokens.warning),
                label: const Text('Degraded (Warning)'),
              ),
              Chip(
                avatar: Icon(Icons.circle, size: 12, color: tokens.error),
                label: const Text('Offline (Error)'),
              ),
              Chip(
                avatar: Icon(Icons.info_rounded, size: 14, color: tokens.info),
                label: const Text('Info (Second Seed)'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Input field
          TextField(
            decoration: InputDecoration(
              labelText: 'Sample Text Input Field',
              hintText: 'Shows focus ring & borders in active palette tokens',
              prefixIcon: Icon(Icons.search, color: tokens.accent),
            ),
          ),
        ],
      ),
    );
  }
}
