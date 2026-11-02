import 'package:flutter/material.dart';

import '../../domain/entities/network_range.dart';
import '../../domain/entities/reachability_status.dart';

class DiscoveryRangesCard extends StatelessWidget {
  final List<NetworkRange> ranges;
  final String? activeSubnetFilter;
  final ValueChanged<String?> onSelectSubnet;
  final ValueChanged<NetworkRange>? onScanRange;
  final VoidCallback? onManageScopes;
  final bool isAdmin;

  const DiscoveryRangesCard({
    super.key,
    required this.ranges,
    required this.activeSubnetFilter,
    required this.onSelectSubnet,
    this.onScanRange,
    this.onManageScopes,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledCount = ranges.where((r) => r.isEnabled).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.lan_rounded,
                    size: 20,
                    color: Color(0xFF0F62FE),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Authorized Discovery Scopes ($enabledCount Active Subnets)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (onManageScopes != null)
                    TextButton.icon(
                      onPressed: onManageScopes,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(
                        isAdmin ? 'Manage Scopes' : 'View Scopes',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (activeSubnetFilter != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => onSelectSubnet(null),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text(
                        'Show All Subnets',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ranges.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 36,
                    color: Color(0xFF0F62FE),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Authorized Network Scopes Configured',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAdmin
                        ? 'An administrator must add an authorized network range before discovery can run.'
                        : 'No network ranges have been configured. Contact an administrator to add discovery scopes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  if (isAdmin && onManageScopes != null) ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: onManageScopes,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Authorized Network Scope'),
                    ),
                  ],
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ranges.map((r) {
                final isSelected = activeSubnetFilter == r.cidr;
                final reachabilityColor = _reachabilityColor(r.reachability);

                return InkWell(
                  onTap: r.isEnabled
                      ? () => onSelectSubnet(isSelected ? null : r.cidr)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: !r.isEnabled
                          ? theme.disabledColor.withValues(alpha: 0.05)
                          : (isSelected
                                ? theme.primaryColor.withValues(alpha: 0.12)
                                : theme.colorScheme.surface),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !r.isEnabled
                            ? Colors.grey.withValues(alpha: 0.2)
                            : (isSelected
                                  ? theme.primaryColor
                                  : theme.dividerColor.withValues(alpha: 0.2)),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r.cidr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: r.isEnabled ? null : Colors.grey,
                                  ),
                                ),
                                if (r.name != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${r.name})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !r.isEnabled
                                        ? Colors.grey.withValues(alpha: 0.15)
                                        : reachabilityColor.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    !r.isEnabled
                                        ? 'Disabled'
                                        : r.reachability.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: !r.isEnabled
                                          ? Colors.grey
                                          : reachabilityColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.usableHostsCount} Usable Target Hosts (${r.baseIp.substring(0, r.baseIp.lastIndexOf('.'))}.1 – .${r.usableHostsCount})',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        if (isAdmin && onScanRange != null && r.isEnabled) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 22,
                              color: Color(0xFF10B981),
                            ),
                            tooltip: 'Scan ${r.cidr} Now',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () => onScanRange!(r),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Tooltip(
                          message: isSelected
                              ? 'Clear Subnet Filter'
                              : 'Filter by ${r.cidr}',
                          child: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.filter_alt_outlined,
                            size: 18,
                            color: !r.isEnabled
                                ? Colors.transparent
                                : (isSelected
                                      ? theme.primaryColor
                                      : theme.disabledColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color _reachabilityColor(ReachabilityStatus status) {
    switch (status) {
      case ReachabilityStatus.reachable:
      case ReachabilityStatus.scanCompleted:
        return const Color(0xFF10B981); // Green
      case ReachabilityStatus.partiallyReachable:
      case ReachabilityStatus.scanCompletedWithErrors:
        return Colors.orange;
      case ReachabilityStatus.inaccessible:
        return Colors.red;
      case ReachabilityStatus.rangeConfigured:
      case ReachabilityStatus.reachabilityNotTested:
        return const Color(0xFF0F62FE); // Blue
    }
  }
}
