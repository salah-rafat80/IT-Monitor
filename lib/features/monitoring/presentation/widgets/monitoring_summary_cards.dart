import 'package:flutter/material.dart';
import '../bloc/monitoring_dashboard_state.dart';

class MonitoringSummaryCards extends StatelessWidget {
  final MonitoringDashboardLoaded state;
  final ValueChanged<String?>? onStatusCardTap;

  const MonitoringSummaryCards({
    super.key,
    required this.state,
    this.onStatusCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth;
            if (constraints.maxWidth >= 1100) {
              cardWidth = (constraints.maxWidth - (5 * 12)) / 6;
            } else if (constraints.maxWidth >= 720) {
              cardWidth = (constraints.maxWidth - (2 * 12)) / 3;
            } else {
              cardWidth = (constraints.maxWidth - 12) / 2;
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSummaryCard(
                  context,
                  width: cardWidth,
                  title: 'Total Devices',
                  count: state.totalCount,
                  icon: Icons.devices_rounded,
                  color: const Color(0xFF6366F1), // Indigo
                  filterValue: null,
                  isSelected: state.statusFilter == null,
                ),
                _buildSummaryCard(
                  context,
                  width: cardWidth,
                  title: 'Online (Up)',
                  count: state.upCount,
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981), // Green
                  filterValue: 'up',
                  isSelected: state.statusFilter == 'up',
                ),
                _buildSummaryCard(
                  context,
                  width: cardWidth,
                  title: 'Degraded',
                  count: state.degradedCount,
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B), // Orange
                  filterValue: 'degraded',
                  isSelected: state.statusFilter == 'degraded',
                ),
                _buildSummaryCard(
                  context,
                  width: cardWidth,
                  title: 'Down',
                  count: state.downCount,
                  icon: Icons.cancel_rounded,
                  color: const Color(0xFFEF4444), // Red
                  filterValue: 'down',
                  isSelected: state.statusFilter == 'down',
                ),
                _buildSummaryCard(
                  context,
                  width: cardWidth,
                  title: 'Unknown',
                  count: state.unknownCount,
                  icon: Icons.help_outline_rounded,
                  color: const Color(0xFF6B7280), // Grey
                  filterValue: 'unknown',
                  isSelected: state.statusFilter == 'unknown',
                ),
                _buildSummaryCard(
                  context,
                  width: cardWidth,
                  title: 'Maintenance',
                  count: state.maintenanceCount,
                  icon: Icons.build_circle_rounded,
                  color: const Color(0xFF3B82F6), // Blue
                  filterValue: 'maintenance',
                  isSelected: state.statusFilter == 'maintenance',
                ),
              ],
            );
          },
        ),

        // Active Incidents Banner
        if (state.activeIncidents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Active Monitoring Incidents: ${state.activeIncidents.length} device(s) requiring attention (${state.downCount} Down, ${state.degradedCount} Degraded)',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onStatusCardTap?.call('down'),
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Filter Incidents',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required double width,
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String? filterValue,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final minW = width < 150 ? 150.0 : width;

    return SizedBox(
      width: minW,
      child: InkWell(
        onTap: () => onStatusCardTap?.call(filterValue),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : theme.dividerColor.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
