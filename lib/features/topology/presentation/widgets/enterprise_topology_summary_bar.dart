import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/enterprise_topology_models.dart';

/// Top horizontal telemetry strip above the topology canvas.
class EnterpriseTopologySummaryBar extends StatelessWidget {
  final Map<TopologyDeviceCategory, dynamic> stats;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback? onRefresh;

  const EnterpriseTopologySummaryBar({
    super.key,
    required this.stats,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.header,
        border: Border(
          bottom: BorderSide(color: tokens.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // ── Category Ratios List ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _CategoryStatPill(
                    icon: Icons.router_rounded,
                    label: 'Gateway',
                    stats: stats[TopologyDeviceCategory.gateway] ?? (0, 0),
                    color: tokens.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryStatPill(
                    icon: Icons.hub_rounded,
                    label: 'Switch',
                    stats: stats[TopologyDeviceCategory.switchDevice] ?? (0, 0),
                    color: tokens.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryStatPill(
                    icon: Icons.wifi_rounded,
                    label: 'AP',
                    stats: stats[TopologyDeviceCategory.accessPoint] ?? (0, 0),
                    color: tokens.statusOnline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryStatPill(
                    icon: Icons.dns_rounded,
                    label: 'Server',
                    stats: stats[TopologyDeviceCategory.server] ?? (0, 0),
                    color: tokens.statusDegraded,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryStatPill(
                    icon: Icons.desktop_windows_rounded,
                    label: 'PC',
                    stats: stats[TopologyDeviceCategory.pc] ?? (0, 0),
                    color: tokens.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryStatPill(
                    icon: Icons.laptop_rounded,
                    label: 'Laptop',
                    stats: stats[TopologyDeviceCategory.laptop] ?? (0, 0),
                    color: tokens.statusMaintenance,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CategoryStatPill(
                    icon: Icons.print_rounded,
                    label: 'Printer',
                    stats: stats[TopologyDeviceCategory.printer] ?? (0, 0),
                    color: tokens.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // ── Fast Topology Node Locator Input ──────────────────────────────
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: searchQuery.length),
                ),
              onChanged: onSearchChanged,
              style: TextStyle(fontSize: 12.0, color: tokens.onInput),
              decoration: InputDecoration(
                hintText: 'Locate device or IP…',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: tokens.inputHint,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: tokens.onSurfaceVariant,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: tokens.onSurfaceVariant,
                        ),
                        onPressed: onClearSearch,
                        padding: EdgeInsets.zero,
                        splashRadius: 12,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                filled: true,
                fillColor: tokens.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: tokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: tokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: tokens.accent, width: 1.5),
                ),
              ),
            ),
          ),

          if (onRefresh != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                size: 17,
                color: tokens.onSurfaceVariant,
              ),
              tooltip: 'Refresh Topology Data',
              onPressed: onRefresh,
              splashRadius: 16,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final dynamic stats;
  final Color color;

  const _CategoryStatPill({
    required this.icon,
    required this.label,
    required this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    int online = 0;
    int offline = 0;
    int degraded = 0;
    int unknown = 0;
    int stale = 0;
    int total = 0;

    if (stats is CategoryStatusCount) {
      final c = stats as CategoryStatusCount;
      online = c.online;
      offline = c.offline;
      degraded = c.degraded;
      unknown = c.unknown;
      stale = c.stale;
      total = c.total;
    } else if (stats is (int, int)) {
      final t = stats as (int, int);
      online = t.$1;
      total = t.$2;
      offline = total > online ? total - online : 0;
    }

    final allOnline =
        total > 0 && online == total && stale == 0 && degraded == 0;
    final hasDown = offline > 0;
    final hasWarning = !hasDown && (stale > 0 || degraded > 0);

    final tooltipMsg =
        '$label Status Breakdown:\n'
        '• Online: $online\n'
        '• Stale: $stale\n'
        '• Degraded: $degraded\n'
        '• Offline: $offline\n'
        '• Unknown: $unknown\n'
        '• Total Registered: $total';

    final Color statusTextColor = hasDown
        ? tokens.statusOffline
        : hasWarning
            ? tokens.statusDegraded
            : allOnline
                ? tokens.statusOnline
                : tokens.onSurfaceVariant;

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: hasDown
                ? tokens.statusOffline.withValues(alpha: 0.6)
                : hasWarning
                    ? tokens.statusDegraded.withValues(alpha: 0.6)
                    : tokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: tokens.onSurfaceVariant,
              ),
            ),
            Text(
              '$online/$total',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: statusTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
