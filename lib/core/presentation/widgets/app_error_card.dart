import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Reusable actionable error card complying with Unhappy-Path standards.
/// Explains the exact failure in plain language, offers a clear retry action,
/// and never swallows underlying exceptions.
class AppErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String? technicalDetails;
  final bool compact;

  const AppErrorCard({
    super.key,
    this.title = 'Unable to Load Telemetry',
    required this.message,
    this.onRetry,
    this.technicalDetails,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 400 : 540),
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        decoration: BoxDecoration(
          color: tokens.statusOfflineSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: tokens.statusOffline.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: tokens.onStatusOffline,
                  size: compact ? 20 : 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: tokens.onStatusOffline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                color: tokens.onStatusOffline.withValues(alpha: 0.9),
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (technicalDetails != null && technicalDetails!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Diagnostic: $technicalDetails',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: tokens.onStatusOffline.withValues(alpha: 0.75),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.statusOffline,
                    foregroundColor: tokens.onError,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
