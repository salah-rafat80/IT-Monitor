import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';

/// Flyout inspector pane rendered on the right when an enterprise topology node is clicked.
class EnterpriseDeviceDetailsSheet extends StatelessWidget {
  final EnterpriseTopologyNode node;
  final VoidCallback onClose;
  final VoidCallback? onRefresh;

  const EnterpriseDeviceDetailsSheet({
    super.key,
    required this.node,
    required this.onClose,
    this.onRefresh,
  });

  Color _getStatusColor(DeviceStatusEnum status, AppColors tokens) {
    switch (status) {
      case DeviceStatusEnum.up:
        return tokens.statusOnline;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        return tokens.statusOffline;
      case DeviceStatusEnum.unknown:
        return tokens.statusUnknown;
      case DeviceStatusEnum.degraded:
      case DeviceStatusEnum.stale:
        return tokens.statusDegraded;
      case DeviceStatusEnum.maintenance:
        return tokens.statusMaintenance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isTransitional =
        node.consecutiveFailures > 0 &&
        node.consecutiveFailures < 3 &&
        node.status != DeviceStatusEnum.down;

    final statusColor = isTransitional
        ? tokens.statusDegraded
        : _getStatusColor(node.status, tokens);

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(left: BorderSide(color: tokens.border)),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 12,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
              color: tokens.header,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.account_tree_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.onHeader,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${node.category.displayName} • Level ${node.level}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: tokens.onSurfaceVariant,
                  ),
                  onPressed: onClose,
                  splashRadius: 16,
                ),
              ],
            ),
          ),

          // ── Body Metrics & Inspection Details ─────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _buildSectionTitle('Operational Telemetry', tokens),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Status',
                        value: isTransitional
                            ? 'Failing (${node.consecutiveFailures}/3)'
                            : node.status.name.toUpperCase(),
                        color: statusColor,
                        tokens: tokens,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Latency',
                        value: node.lastLatencyMs != null
                            ? '${node.lastLatencyMs} ms'
                            : 'N/A',
                        color: node.lastLatencyMs != null && node.lastLatencyMs! > 100
                            ? tokens.statusDegraded
                            : tokens.primary,
                        tokens: tokens,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Downstream Links',
                        value: '${node.activePortCount ?? 0} Active',
                        color: tokens.primary,
                        tokens: tokens,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Failures',
                        value: '${node.consecutiveFailures} checks',
                        color: node.consecutiveFailures > 0
                            ? tokens.statusOffline
                            : tokens.statusOnline,
                        tokens: tokens,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildSectionTitle('Device Identity & IP', tokens),
                const SizedBox(height: AppSpacing.sm),
                _buildInfoRow('IP Address', node.subtitle ?? '-', tokens),
                _buildInfoRow('Category', node.category.displayName, tokens),
                _buildInfoRow(
                  'Scope Verification',
                  node.isInferred ? 'Inferred Uplink' : 'Verified Physical',
                  tokens,
                ),
                if ((node.deviceRef?.factoryId ?? node.infraRef?.factoryId) != null)
                  _buildInfoRow(
                    'Factory Context',
                    (node.deviceRef?.factoryId ?? node.infraRef?.factoryId)!.toUpperCase(),
                    tokens,
                  ),

                if (isTransitional) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: tokens.statusDegradedSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: tokens.onStatusDegraded.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: tokens.onStatusDegraded,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Probe failed (${node.consecutiveFailures}/3). Awaiting threshold confirmation before transitioning state.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.onStatusDegraded,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.border)),
              color: tokens.header,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Close Inspector'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.primary,
                      foregroundColor: tokens.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppColors tokens) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: tokens.onSurfaceVariant,
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required AppColors tokens,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, AppColors tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.onCard,
            ),
          ),
        ],
      ),
    );
  }
}
