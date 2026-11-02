import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/device_status_entity.dart';

class DeviceStatusChip extends StatelessWidget {
  final DeviceStatusEnum status;
  final bool isMaintenance;
  final bool compact;

  const DeviceStatusChip({
    super.key,
    required this.status,
    this.isMaintenance = false,
    this.compact = false,
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
        iconData = Icons.check_circle_rounded;
        color = tokens.statusOnline;
        text = 'Connected';
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
    }

    if (compact) {
      return Container(
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
    }

    return Container(
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
}
