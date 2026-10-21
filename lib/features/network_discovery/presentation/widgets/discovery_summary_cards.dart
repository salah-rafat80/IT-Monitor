import 'package:flutter/material.dart';

import '../bloc/network_discovery_state.dart';

class DiscoverySummaryCards extends StatelessWidget {
  final NetworkDiscoveryLoaded state;

  const DiscoverySummaryCards({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 5
            : (constraints.maxWidth > 700 ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.1,
          children: [
            _Card(
              title: 'Discovered Devices',
              value: '${state.totalDiscovered}',
              subtitle:
                  '${state.classifiedCount} Classified / ${state.unknownCount} Unknown',
              icon: Icons.radar_rounded,
              color: const Color(0xFF0F62FE),
            ),
            _Card(
              title: 'Pending Review',
              value: '${state.pendingReviewCount}',
              subtitle: 'Awaiting Admin evaluation',
              icon: Icons.pending_actions_rounded,
              color: Colors.orange,
            ),
            _Card(
              title: 'Already in Inventory',
              value: '${state.alreadyKnownCount}',
              subtitle: 'Protected production assets',
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF10B981),
            ),
            _Card(
              title: 'Approved Assets',
              value: '${state.approvedCount}',
              subtitle: 'Promoted or verified assets',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF059669),
            ),
            _Card(
              title: 'Conflicts / Rejected',
              value: '${state.conflictCount + state.rejectedCount}',
              subtitle:
                  '${state.conflictCount} Conflicts / ${state.rejectedCount} Rejected',
              icon: Icons.warning_amber_rounded,
              color: state.conflictCount > 0 ? Colors.red : Colors.grey,
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _Card({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
