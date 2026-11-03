import 'package:flutter/material.dart';

import '../../domain/entities/enterprise_topology_models.dart';

/// Top Summary Bar matching enterprise network management layout diagrams.
///
/// Displays category icons and live online/total ratios:
/// - Gateway: X/Y
/// - Switch: X/Y
/// - AP: X/Y
/// - Server: X/Y
/// - PC: X/Y
/// - Laptop: X/Y
///
/// Numerator = verified online devices in that category.
/// Denominator = total monitored devices in that category.
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
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Dark surface
        border: Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 1.0),
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
                    color: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  _CategoryStatPill(
                    icon: Icons.hub_rounded,
                    label: 'Switch',
                    stats: stats[TopologyDeviceCategory.switchDevice] ?? (0, 0),
                    color: const Color(0xFF2DD4BF),
                  ),
                  const SizedBox(width: 8),
                  _CategoryStatPill(
                    icon: Icons.wifi_rounded,
                    label: 'AP',
                    stats: stats[TopologyDeviceCategory.accessPoint] ?? (0, 0),
                    color: const Color(0xFF34D399),
                  ),
                  const SizedBox(width: 8),
                  _CategoryStatPill(
                    icon: Icons.dns_rounded,
                    label: 'Server',
                    stats: stats[TopologyDeviceCategory.server] ?? (0, 0),
                    color: const Color(0xFFFB923C),
                  ),
                  const SizedBox(width: 8),
                  _CategoryStatPill(
                    icon: Icons.desktop_windows_rounded,
                    label: 'PC',
                    stats: stats[TopologyDeviceCategory.pc] ?? (0, 0),
                    color: const Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 8),
                  _CategoryStatPill(
                    icon: Icons.laptop_rounded,
                    label: 'Laptop',
                    stats: stats[TopologyDeviceCategory.laptop] ?? (0, 0),
                    color: const Color(0xFF818CF8),
                  ),
                  const SizedBox(width: 8),
                  _CategoryStatPill(
                    icon: Icons.print_rounded,
                    label: 'Printer',
                    stats: stats[TopologyDeviceCategory.printer] ?? (0, 0),
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ── Search Field in Summary Row ────────────────────────────────────
          SizedBox(
            width: 220,
            height: 30,
            child: TextField(
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: searchQuery.length),
                ),
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 12.0, color: Color(0xFFF8FAFC)),
              decoration: InputDecoration(
                hintText: 'Locate device or IP…',
                hintStyle: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
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
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                ),
              ),
            ),
          ),

          if (onRefresh != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
                color: Color(0xFF94A3B8),
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

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: hasDown
                ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                : hasWarning
                ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              '$label: ',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            Text(
              '$online/$total',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'Consolas',
                color: hasDown
                    ? const Color(0xFFEF4444)
                    : hasWarning
                    ? const Color(0xFFF59E0B)
                    : allOnline
                    ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
