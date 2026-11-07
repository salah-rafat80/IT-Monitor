import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class WallDisplaySummaryBar extends StatelessWidget {
  final int totalCount;
  final int upCount;
  final int degradedCount;
  final int downCount;
  final int unknownCount;
  final int maintenanceCount;

  const WallDisplaySummaryBar({
    super.key,
    required this.totalCount,
    required this.upCount,
    required this.degradedCount,
    required this.downCount,
    required this.unknownCount,
    required this.maintenanceCount,
  });

  Widget _buildSummaryItem({
    required BuildContext context,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    bool isHighlight = false,
  }) {
    final tokens = context.appTokens;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight ? color.withValues(alpha: 0.12) : tokens.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHighlight ? color : tokens.cardBorder,
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
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color == tokens.statusUnknown
                          ? tokens.textPrimary
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
    final tokens = context.appTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSummaryItem(
            context: context,
            label: 'TOTAL DEVICES',
            count: totalCount,
            icon: Icons.devices_rounded,
            color: tokens.primary,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            context: context,
            label: 'UP (HEALTHY)',
            count: upCount,
            icon: Icons.check_circle_rounded,
            color: tokens.statusOnline,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            context: context,
            label: 'DEGRADED',
            count: degradedCount,
            icon: Icons.warning_rounded,
            color: tokens.statusDegraded,
            isHighlight: degradedCount > 0,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            context: context,
            label: 'DISCONNECTED',
            count: downCount,
            icon: Icons.cancel_rounded,
            color: tokens.statusOffline,
            isHighlight: downCount > 0,
          ),
          const SizedBox(width: 8),
          _buildSummaryItem(
            context: context,
            label: 'UNKNOWN',
            count: unknownCount,
            icon: Icons.help_outline_rounded,
            color: tokens.statusUnknown,
          ),

          const SizedBox(width: 8),
          _buildSummaryItem(
            context: context,
            label: 'MAINTENANCE',
            count: maintenanceCount,
            icon: Icons.build_circle_rounded,
            color: tokens.statusMaintenance,
          ),
        ],
      ),
    );
  }
}
