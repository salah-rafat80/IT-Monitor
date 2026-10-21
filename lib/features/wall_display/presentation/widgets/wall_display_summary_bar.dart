import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class WallDisplaySummaryBar extends StatelessWidget {
  final int totalCount;
  final int upCount;
  final int degradedCount;
  final int downCount;
  final int unknownCount;
  final int maintenanceCount;
  final int activeIncidentsCount;

  const WallDisplaySummaryBar({
    super.key,
    required this.totalCount,
    required this.upCount,
    required this.degradedCount,
    required this.downCount,
    required this.unknownCount,
    required this.maintenanceCount,
    required this.activeIncidentsCount,
  });

  Widget _buildSummaryItem({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight
              ? color.withValues(alpha: 0.12)
              : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHighlight
                ? color
                : AppColors.darkBorder.withValues(alpha: 0.6),
            width: isHighlight ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color == AppColors.statusUnknown
                          ? AppColors.textPrimaryDark
                          : color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSummaryItem(
            label: 'TOTAL DEVICES',
            count: totalCount,
            icon: Icons.devices_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            label: 'UP (HEALTHY)',
            count: upCount,
            icon: Icons.check_circle_rounded,
            color: AppColors.statusUp,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            label: 'DEGRADED',
            count: degradedCount,
            icon: Icons.warning_rounded,
            color: AppColors.statusDegraded,
            isHighlight: degradedCount > 0,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            label: 'DOWN',
            count: downCount,
            icon: Icons.cancel_rounded,
            color: AppColors.statusDown,
            isHighlight: downCount > 0,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            label: 'UNKNOWN',
            count: unknownCount,
            icon: Icons.help_outline_rounded,
            color: AppColors.statusUnknown,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            label: 'MAINTENANCE',
            count: maintenanceCount,
            icon: Icons.build_circle_rounded,
            color: AppColors.statusMaintenance,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            label: 'ACTIVE INCIDENTS',
            count: activeIncidentsCount,
            icon: Icons.report_problem_rounded,
            color: activeIncidentsCount > 0
                ? AppColors.statusDown
                : AppColors.statusUp,
            isHighlight: activeIncidentsCount > 0,
          ),
        ],
      ),
    );
  }
}
