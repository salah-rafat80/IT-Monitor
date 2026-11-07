import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
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
                              ? const Color(0xFF0F62FE).withValues(alpha: 0.12)
                              : const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isConsolidated
                              ? Icons.hub_rounded
                              : Icons.factory_rounded,
                          size: 20,
                          color: isConsolidated
                              ? const Color(0xFF0F62FE)
                              : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Factory Context:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedId,
                            isDense: true,
                            dropdownColor: theme.colorScheme.surface,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.all_inclusive_rounded,
                                      size: 16,
                                      color: Color(0xFF0F62FE),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'All Factories (Consolidated)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
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
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          f.code,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(f.name),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) => _onFactoryChanged(context, val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Scope badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isConsolidated
                              ? const Color(0xFF0F62FE).withValues(alpha: 0.1)
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isConsolidated
                                ? const Color(0xFF0F62FE).withValues(alpha: 0.3)
                                : const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.3),
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
                                ? const Color(0xFF0F62FE)
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Network Detection Status Badge
                      if (factoryState.isDetectingNetwork) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Detecting Network...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: factoryState.detectionResult!.isDetected
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.15)
                                  : factoryState.detectionResult!.isAmbiguous
                                  ? Colors.amber.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: factoryState.detectionResult!.isDetected
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.4)
                                    : factoryState.detectionResult!.isAmbiguous
                                    ? Colors.amber.withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  factoryState.detectionResult!.isDetected
                                      ? Icons.wifi_find_rounded
                                      : factoryState
                                            .detectionResult!
                                            .isAmbiguous
                                      ? Icons.warning_amber_rounded
                                      : Icons.wifi_off_rounded,
                                  size: 13,
                                  color:
                                      factoryState.detectionResult!.isDetected
                                      ? const Color(0xFF10B981)
                                      : factoryState
                                            .detectionResult!
                                            .isAmbiguous
                                      ? Colors.amber[400]
                                      : Colors.grey[400],
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  factoryState.detectionResult!.isDetected
                                      ? 'AUTO: ${factoryState.detectionResult!.detectedFactory?.code}'
                                      : factoryState
                                            .detectionResult!
                                            .isAmbiguous
                                      ? 'AMBIGUOUS LAN'
                                      : 'UNKNOWN LAN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        factoryState.detectionResult!.isDetected
                                        ? const Color(0xFF10B981)
                                        : factoryState
                                              .detectionResult!
                                              .isAmbiguous
                                        ? Colors.amber[400]
                                        : Colors.grey[400],
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
                  const SizedBox(width: 16),
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
                                borderRadius: BorderRadius.circular(8),
                                onTap: () =>
                                    context.read<ThemeCubit>().toggleTheme(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.appTokens.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.appTokens.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDark
                                            ? Icons.dark_mode_rounded
                                            : Icons.light_mode_rounded,
                                        size: 16,
                                        color: isDark
                                            ? const Color(0xFF00E5FF)
                                            : const Color(0xFF1769FF),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isDark ? 'CYBER DARK' : 'PRO LIGHT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFF00E5FF)
                                              : const Color(0xFF1769FF),
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
                      const SizedBox(width: 12),
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
                            foregroundColor: theme.appTokens.primary,
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
