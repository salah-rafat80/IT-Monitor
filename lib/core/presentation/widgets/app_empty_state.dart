import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Reusable enterprise empty-state widget adhering to the Unhappy-Path design standards.
/// Never displays a blank screen or a vague "No data" message.
/// Clearly states what is empty, why, and what primary action the user should take next.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  const AppEmptyState({
    super.key,
    this.icon = Icons.search_off_rounded,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  /// Factory for search or filter results that matched zero records.
  factory AppEmptyState.noFilterResults({
    Key? key,
    String? query,
    required VoidCallback onClearFilters,
    bool compact = false,
  }) {
    return AppEmptyState(
      key: key,
      icon: Icons.filter_alt_off_rounded,
      title: query != null && query.isNotEmpty
          ? 'No matching results for "$query"'
          : 'No records match the current filters',
      message: 'Try clearing search terms or resetting active filter selections.',
      actionLabel: 'Clear All Filters',
      onAction: onClearFilters,
      compact: compact,
    );
  }

  /// Factory for first-time use when no records exist yet in the system/scope.
  factory AppEmptyState.firstUse({
    Key? key,
    required String entityName,
    required String actionLabel,
    required VoidCallback onAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    bool compact = false,
  }) {
    return AppEmptyState(
      key: key,
      icon: Icons.add_circle_outline_rounded,
      title: 'No $entityName registered yet',
      message: 'Get started by adding your first $entityName or importing inventory.',
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      compact: compact,
    );
  }

  /// Factory for completed / all caught up states.
  factory AppEmptyState.allCaughtUp({
    Key? key,
    required String title,
    required String message,
    VoidCallback? onRefresh,
    bool compact = false,
  }) {
    return AppEmptyState(
      key: key,
      icon: Icons.check_circle_outline_rounded,
      title: title,
      message: message,
      actionLabel: onRefresh != null ? 'Refresh Telemetry' : null,
      onAction: onRefresh,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 360 : 520),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.xl,
          vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: compact ? 44 : 64,
              height: compact ? 44 : 64,
              decoration: BoxDecoration(
                color: tokens.surfaceContainerLow,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border),
              ),
              child: Icon(
                icon,
                size: compact ? 22 : 32,
                color: tokens.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: tokens.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                color: tokens.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(actionLabel!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.primary,
                      foregroundColor: tokens.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (secondaryActionLabel != null && onSecondaryAction != null)
                    OutlinedButton(
                      onPressed: onSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.onSurface,
                        side: BorderSide(color: tokens.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: Text(secondaryActionLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
