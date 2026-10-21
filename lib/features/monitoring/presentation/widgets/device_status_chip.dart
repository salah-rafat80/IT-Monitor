import 'package:flutter/material.dart';
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
    final effectiveStatus = isMaintenance
        ? DeviceStatusEnum.maintenance
        : status;

    IconData iconData;
    Color color;
    String text;

    switch (effectiveStatus) {
      case DeviceStatusEnum.up:
        iconData = Icons.check_circle_rounded;
        color = const Color(0xFF10B981); // Emerald Green
        text = 'Connected';
        break;
      case DeviceStatusEnum.degraded:
        iconData = Icons.warning_amber_rounded;
        color = const Color(0xFFF59E0B); // Amber / Orange
        text = 'Degraded';
        break;
      case DeviceStatusEnum.down:
        iconData = Icons.cancel_rounded;
        color = const Color(0xFFEF4444); // Red
        text = 'Disconnected';
        break;
      case DeviceStatusEnum.maintenance:
        iconData = Icons.build_circle_rounded;
        color = const Color(0xFF3B82F6); // Blue
        text = 'Maintenance';
        break;
      case DeviceStatusEnum.unreachable:
        iconData = Icons.do_not_disturb_on_rounded;
        color = const Color(0xFF8B5CF6); // Purple
        text = 'Unreachable';
        break;
      case DeviceStatusEnum.unknown:
        iconData = Icons.help_outline_rounded;
        color = const Color(0xFF6B7280); // Grey
        text = 'Unknown';
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
