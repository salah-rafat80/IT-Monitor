import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/device_status_entity.dart';

class DeviceStatusChip extends StatelessWidget {
  final DeviceStatusEnum status;
  final bool isMaintenance;
  final bool compact;
  final int consecutiveFailures;
  final int failureThreshold;
  final String? failureReason;

  const DeviceStatusChip({
    super.key,
    required this.status,
    this.isMaintenance = false,
    this.compact = false,
    this.consecutiveFailures = 0,
    this.failureThreshold = 3,
    this.failureReason,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final effectiveStatus = isMaintenance
        ? DeviceStatusEnum.maintenance
        : status;

    final IconData iconData;
    final Color textColor;
    final Color surfaceColor;
    final String text;

    switch (effectiveStatus) {
      case DeviceStatusEnum.up:
        if (consecutiveFailures > 0) {
          iconData = Icons.warning_amber_rounded;
          textColor = tokens.onStatusDegraded;
          surfaceColor = tokens.statusDegradedSurface;
          text = compact
              ? '$consecutiveFailures/$failureThreshold Fail'
              : 'Previously Online · $consecutiveFailures/$failureThreshold Failed Checks';
        } else {
          iconData = Icons.check_circle_rounded;
          textColor = tokens.onStatusOnline;
          surfaceColor = tokens.statusOnlineSurface;
          text = 'Connected';
        }
        break;
      case DeviceStatusEnum.degraded:
        iconData = Icons.warning_amber_rounded;
        textColor = tokens.onStatusDegraded;
        surfaceColor = tokens.statusDegradedSurface;
        text = 'Degraded';
        break;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        iconData = Icons.cancel_rounded;
        textColor = tokens.onStatusOffline;
        surfaceColor = tokens.statusOfflineSurface;
        text = 'Disconnected';
        break;
      case DeviceStatusEnum.unknown:
        iconData = Icons.help_outline_rounded;
        textColor = tokens.onStatusUnknown;
        surfaceColor = tokens.statusUnknownSurface;
        text = 'Unknown';
        break;
      case DeviceStatusEnum.maintenance:
        iconData = Icons.build_circle_rounded;
        textColor = tokens.onStatusMaintenance;
        surfaceColor = tokens.statusMaintenanceSurface;
        text = 'Maintenance';
        break;
      case DeviceStatusEnum.stale:
        iconData = Icons.history_rounded;
        textColor = tokens.onStatusDegraded;
        surfaceColor = tokens.statusDegradedSurface;
        text = 'Stale';
        break;
    }

    final Widget chip;
    if (compact) {
      chip = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: textColor.withValues(alpha: tokens.isDark ? 0.35 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 14, color: textColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      chip = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: textColor.withValues(alpha: tokens.isDark ? 0.35 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (failureReason != null && failureReason!.isNotEmpty) {
      return Tooltip(
        message: 'Latest Failure Reason: $failureReason',
        child: chip,
      );
    }
    return chip;
  }
}
