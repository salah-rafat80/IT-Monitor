import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/device_status_entity.dart';

class DeviceStatusChip extends StatelessWidget {
  final DeviceStatusEnum status;
  final bool isMaintenance;
  final bool compact;
  final int consecutiveFailures;
  final String? failureReason;

  const DeviceStatusChip({
    super.key,
    required this.status,
    this.isMaintenance = false,
    this.compact = false,
    this.consecutiveFailures = 0,
    this.failureReason,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final effectiveStatus = isMaintenance
        ? DeviceStatusEnum.maintenance
        : status;

    IconData iconData;
    Color color;
    String text;

    switch (effectiveStatus) {
      case DeviceStatusEnum.up:
        if (consecutiveFailures > 0) {
          iconData = Icons.warning_amber_rounded;
          color = const Color(0xFFF59E0B);
          text = compact
              ? '$consecutiveFailures/3 Fail'
              : 'Previously Online · $consecutiveFailures/3 Failed Checks';
        } else {
          iconData = Icons.check_circle_rounded;
          color = tokens.statusOnline;
          text = 'Connected';
        }
        break;
      case DeviceStatusEnum.degraded:
        iconData = Icons.warning_amber_rounded;
        color = tokens.statusDegraded;
        text = 'Degraded';
        break;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        iconData = Icons.cancel_rounded;
        color = tokens.statusOffline;
        text = 'Disconnected';
        break;
      case DeviceStatusEnum.unknown:
        iconData = Icons.help_outline_rounded;
        color = tokens.statusUnknown;
        text = 'Unknown';
        break;
      case DeviceStatusEnum.maintenance:
        iconData = Icons.build_circle_rounded;
        color = tokens.statusMaintenance;
        text = 'Maintenance';
        break;
      case DeviceStatusEnum.stale:
        iconData = Icons.history_rounded;
        color = const Color(0xFFF59E0B);
        text = 'Stale';
        break;
    }

    final Widget chip;
    if (compact) {
      chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: color,
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
