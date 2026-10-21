import 'package:flutter/material.dart';

import '../../domain/entities/network_range.dart';
import '../../domain/entities/reachability_status.dart';

class DiscoveryRangesCard extends StatelessWidget {
  final List<NetworkRange> ranges;
  final String? activeSubnetFilter;
  final ValueChanged<String?> onSelectSubnet;

  const DiscoveryRangesCard({
    super.key,
    required this.ranges,
    required this.activeSubnetFilter,
    required this.onSelectSubnet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    'Authorized Discovery Scopes (${ranges.length} Subnets)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (activeSubnetFilter != null)
                TextButton.icon(
                  onPressed: () => onSelectSubnet(null),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text(
                    'Show All Subnets',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ranges.map((r) {
              final isSelected = activeSubnetFilter == r.cidr;
              final reachabilityColor = _reachabilityColor(r.reachability);

              return InkWell(
                onTap: () => onSelectSubnet(isSelected ? null : r.cidr),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryColor.withValues(alpha: 0.12)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.dividerColor.withValues(alpha: 0.2),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: reachabilityColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.reachability.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: reachabilityColor,
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
                      const SizedBox(width: 12),
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.filter_alt_outlined,
                        size: 18,
                        color: isSelected
                            ? theme.primaryColor
                            : theme.disabledColor,
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
