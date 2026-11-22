import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../bloc/factory_cubit.dart';
import 'add_factory_dialog.dart';

class FactoryHeaderBar extends StatelessWidget {
  const FactoryHeaderBar({super.key});

  void _onFactoryChanged(BuildContext context, String? factoryId) {
    context.read<FactoryCubit>().selectFactoryById(factoryId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    final FactoryState factoryState;
    try {
      factoryState = context.watch<FactoryCubit>().state;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final isAdmin = true;
    final factories = factoryState.factories;
    final selected = factoryState.selectedFactory;
    final selectedId = selected?.id;
    final isConsolidated = selectedId == null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.header,
        border: Border(
          bottom: BorderSide(color: tokens.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isConsolidated
                              ? tokens.primary.withValues(alpha: 0.12)
                              : tokens.statusOnlineSurface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          isConsolidated
                              ? Icons.hub_rounded
                              : Icons.factory_rounded,
                          size: 20,
                          color: isConsolidated
                              ? tokens.primary
                              : tokens.onStatusOnline,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Factory Context:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: tokens.onHeader,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.input,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: tokens.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedId,
                            isDense: true,
                            dropdownColor: tokens.card,
                            iconEnabledColor: tokens.onSurfaceVariant,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.onInput,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 16,
                                      color: tokens.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'All Factories (Consolidated)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: tokens.onInput,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final f in factories)
                                DropdownMenuItem<String?>(
                                  value: f.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs,
                                          vertical: AppSpacing.xxs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.statusOnlineSurface,
                                          borderRadius: BorderRadius.circular(AppRadius.xs),
                                        ),
                                        child: Text(
                                          f.code,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: tokens.onStatusOnline,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        f.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: tokens.onInput,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) => _onFactoryChanged(context, val),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Scope badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isConsolidated
                              ? tokens.primary.withValues(alpha: 0.12)
                              : tokens.statusOnlineSurface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: isConsolidated
                                ? tokens.primary.withValues(alpha: 0.35)
                                : tokens.onStatusOnline.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          isConsolidated
                              ? 'SCOPE: ALL SITES'
                              : 'ISOLATED SCOPE: ${selected!.code}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConsolidated
                                ? tokens.primary
                                : tokens.onStatusOnline,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Network Detection Status Badge
                      if (factoryState.isDetectingNetwork) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: tokens.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: tokens.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Detecting Network...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (factoryState.detectionResult != null) ...[
                        Tooltip(
                          message: factoryState.detectionResult!.message ?? '',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: factoryState.detectionResult!.isDetected
                                  ? tokens.statusOnlineSurface
                                  : factoryState.detectionResult!.isAmbiguous
                                      ? tokens.statusDegradedSurface
                                      : tokens.statusUnknownSurface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: factoryState.detectionResult!.isDetected
                                    ? tokens.onStatusOnline.withValues(alpha: 0.4)
                                    : factoryState.detectionResult!.isAmbiguous
                                        ? tokens.onStatusDegraded.withValues(alpha: 0.4)
                                        : tokens.onStatusUnknown.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  factoryState.detectionResult!.isDetected
                                      ? Icons.wifi_find_rounded
                                      : factoryState.detectionResult!.isAmbiguous
                                          ? Icons.warning_amber_rounded
                                          : Icons.wifi_off_rounded,
                                  size: 13,
                                  color: factoryState.detectionResult!.isDetected
                                      ? tokens.onStatusOnline
                                      : factoryState.detectionResult!.isAmbiguous
                                          ? tokens.onStatusDegraded
                                          : tokens.onStatusUnknown,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  factoryState.detectionResult!.isDetected
                                      ? 'AUTO: ${factoryState.detectionResult!.detectedFactory?.code}'
                                      : factoryState.detectionResult!.isAmbiguous
                                          ? 'AMBIGUOUS LAN'
                                          : 'UNKNOWN LAN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: factoryState.detectionResult!.isDetected
                                        ? tokens.onStatusOnline
                                        : factoryState.detectionResult!.isAmbiguous
                                            ? tokens.onStatusDegraded
                                            : tokens.onStatusUnknown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: 'Re-detect local network scope',
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context
                            .read<FactoryCubit>()
                            .revalidateNetworkDetection(),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Global Theme Mode Switcher
                      BlocBuilder<ThemeCubit, ThemeState>(
                        builder: (context, themeState) {
                          final isDark = themeState.isDark;
                          return Tooltip(
                            message: isDark
                                ? 'Switch to Professional Light Theme'
                                : 'Switch to Cyber Neon Dark Theme',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                onTap: () =>
                                    context.read<ThemeCubit>().toggleTheme(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceVariant,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: tokens.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDark
                                            ? Icons.dark_mode_rounded
                                            : Icons.light_mode_rounded,
                                        size: 16,
                                        color: tokens.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isDark ? 'CYBER DARK' : 'PRO LIGHT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Tooltip(
                        message: 'Customize 60-30-10 Theme Palette',
                        child: InkWell(
                          onTap: () => GoRouter.of(context).push('/palette-editor'),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: tokens.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.palette_rounded,
                                  size: 16,
                                  color: tokens.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'PALETTE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (isAdmin)
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const AddFactoryDialog(),
                            );
                          },
                          icon: const Icon(
                            Icons.add_business_rounded,
                            size: 16,
                          ),
                          label: const Text('Add Factory'),
                          style: TextButton.styleFrom(
                            foregroundColor: tokens.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
