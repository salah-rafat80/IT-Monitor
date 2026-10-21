import 'package:flutter/material.dart';
import '../../domain/entities/incident_entity.dart';

class IncidentStatusChip extends StatelessWidget {
  final IncidentStatusEnum status;

  const IncidentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData iconData;
    String label;

    switch (status) {
      case IncidentStatusEnum.active:
        color = const Color(0xFFEF4444); // Red
        iconData = Icons.error_outline_rounded;
        label = 'Active';
        break;
      case IncidentStatusEnum.acknowledged:
        color = const Color(0xFFF59E0B); // Amber
        iconData = Icons.rule_folder_rounded;
        label = 'Acknowledged';
        break;
      case IncidentStatusEnum.resolved:
        color = const Color(0xFF10B981); // Emerald
        iconData = Icons.check_circle_outline_rounded;
        label = 'Resolved';
        break;
    }

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
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class IncidentSeverityChip extends StatelessWidget {
  final IncidentSeverityEnum severity;

  const IncidentSeverityChip({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (severity) {
      case IncidentSeverityEnum.critical:
        color = const Color(0xFFEF4444); // Red
        label = 'CRITICAL';
        break;
      case IncidentSeverityEnum.high:
        color = const Color(0xFFF97316); // Orange
        label = 'HIGH';
        break;
      case IncidentSeverityEnum.medium:
        color = const Color(0xFFF59E0B); // Amber
        label = 'MEDIUM';
        break;
      case IncidentSeverityEnum.low:
        color = const Color(0xFF3B82F6); // Blue
        label = 'LOW';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
