import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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
    final tokens = context.appTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary KPI Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final double cardWidth;
            if (constraints.maxWidth >= 1100) {
              cardWidth = (constraints.maxWidth - (4 * 12)) / 5;
            } else if (constraints.maxWidth >= 720) {
              cardWidth = (constraints.maxWidth - (2 * 12)) / 3;
            } else if (constraints.maxWidth >= 420) {
              cardWidth = (constraints.maxWidth - 12) / 2;
            } else {
              cardWidth = constraints.maxWidth;
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryKpiCard(
                  width: cardWidth,
                  title: 'Total Devices',
                  count: state.totalCount,
                  icon: Icons.devices_rounded,
                  color: tokens.isDark
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFF1769FF),
                  filterValue: null,
                  isSelected: state.statusFilter == null,
                  onTap: () => onStatusCardTap?.call(null),
                ),
                _SummaryKpiCard(
                  width: cardWidth,
                  title: 'Online (Up)',
                  count: state.upCount,
                  icon: Icons.check_circle_rounded,
                  color: tokens.statusOnline,
                  filterValue: 'up',
                  isSelected: state.statusFilter == 'up',
                  onTap: () => onStatusCardTap?.call('up'),
                ),
                _SummaryKpiCard(
                  width: cardWidth,
                  title: 'Degraded',
                  count: state.degradedCount,
                  icon: Icons.warning_amber_rounded,
                  color: tokens.statusDegraded,
                  filterValue: 'degraded',
                  isSelected: state.statusFilter == 'degraded',
                  onTap: () => onStatusCardTap?.call('degraded'),
                ),
                _SummaryKpiCard(
                  width: cardWidth,
                  title: 'Disconnected',
                  count: state.downCount + state.unknownCount,
                  icon: Icons.cancel_rounded,
                  color: tokens.statusOffline,
                  filterValue: 'down',
                  isSelected:
                      state.statusFilter == 'down' ||
                      state.statusFilter == 'unknown',
                  onTap: () => onStatusCardTap?.call('down'),
                ),
                _SummaryKpiCard(
                  width: cardWidth,
                  title: 'Maintenance',
                  count: state.maintenanceCount,
                  icon: Icons.build_circle_rounded,
                  color: tokens.isDark
                      ? const Color(0xFFA78BFA)
                      : const Color(0xFF8B5CF6),
                  filterValue: 'maintenance',
                  isSelected: state.statusFilter == 'maintenance',
                  onTap: () => onStatusCardTap?.call('maintenance'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SummaryKpiCard extends StatefulWidget {
  final double width;
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final String? filterValue;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryKpiCard({
    required this.width,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.filterValue,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SummaryKpiCard> createState() => _SummaryKpiCardState();
}

class _SummaryKpiCardState extends State<_SummaryKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final safeWidth = widget.width <= 0 ? 150.0 : widget.width;

    final bgColor = widget.isSelected
        ? widget.color.withValues(alpha: tokens.isDark ? 0.16 : 0.12)
        : (_isHovered ? tokens.surfaceSecondary : tokens.surface);

    final borderColor = widget.isSelected
        ? widget.color
        : (_isHovered
              ? (tokens.isDark ? tokens.borderGlow : tokens.border)
              : tokens.border);

    return SizedBox(
      width: safeWidth,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: (widget.isSelected || _isHovered) && tokens.isDark
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: tokens.isDark ? 0.2 : 0.03,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, size: 16, color: widget.color),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Text(
                    '${widget.count}',
                    key: ValueKey<int>(widget.count),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: widget.isSelected
                          ? widget.color
                          : tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
