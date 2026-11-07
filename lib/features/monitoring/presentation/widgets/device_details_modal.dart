import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/monitored_device.dart';
import '../../domain/entities/monitoring_config.dart';
import 'device_status_chip.dart';

class DeviceDetailsModal extends StatelessWidget {
  final MonitoredDevice item;
  final bool isAdmin;
  final MonitoringConfig config;
  final VoidCallback? onTriggerCheck;
  final ValueChanged<bool>? onToggleMaintenance;
  final VoidCallback? onEditOwner;

  const DeviceDetailsModal({
    super.key,
    required this.item,
    this.isAdmin = true,
    required this.config,
    this.onTriggerCheck,
    this.onToggleMaintenance,
    this.onEditOwner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = item.device;
    final status = item.status;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          device.type.toValue() == 'laptop'
                              ? Icons.laptop_windows_rounded
                              : Icons.desktop_windows_rounded,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.displayOwner,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: device.isOwnerAssigned
                                  ? null
                                  : Colors.orangeAccent,
                              fontStyle: device.isOwnerAssigned
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                          Text(
                            '${device.name} • ${device.department}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      DeviceStatusChip(
                        status: status.status,
                        isMaintenance: status.isMaintenance,
                        consecutiveFailures: status.consecutiveFailures,
                        failureThreshold: config.failureThreshold,
                        failureReason: status.lastFailureReason,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),

              // Overview Telemetry Cards
              Row(
                children: [
                  Expanded(
                    child: _buildTelemetryCard(
                      context,
                      title: 'Current Latency',
                      value: status.lastLatencyMs != null
                          ? '${status.lastLatencyMs} ms'
                          : '-',
                      icon: Icons.speed_rounded,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTelemetryCard(
                      context,
                      title: 'Consecutive Failures',
                      value:
                          '${status.consecutiveFailures} / ${config.failureThreshold}',
                      icon: Icons.warning_amber_rounded,
                      color: status.consecutiveFailures > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTelemetryCard(
                      context,
                      title: 'Consecutive Successes',
                      value:
                          '${status.consecutiveSuccesses} / ${config.recoveryThreshold}',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Device & Network Metadata Section
              Text(
                'Device & Network Identity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildMetaRow('Assigned Person', device.displayOwner),
                    const Divider(height: 16),
                    _buildMetaRow('Department', device.department),
                    const Divider(height: 16),
                    _buildMetaRow('Device Name', device.name),
                    const Divider(height: 16),
                    _buildMetaRow('IP Address', device.ip),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Office / Location',
                      device.officeLocation ?? '-',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Device Type',
                      device.type.toValue().toUpperCase(),
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Parent Switch Metadata',
                      device.parentSwitchName ?? '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Monitoring Telemetry & History Timestamps
              Text(
                'Monitoring Telemetry',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    _buildMetaRow(
                      'Last Check Timestamp',
                      status.lastCheckAt != null
                          ? dateFormat.format(status.lastCheckAt!)
                          : '-',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Last Successful Check (Seen)',
                      status.lastSeen != null
                          ? dateFormat.format(status.lastSeen!)
                          : '-',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Last Successful Latency',
                      status.lastSuccessfulLatencyMs != null
                          ? '${status.lastSuccessfulLatencyMs} ms (Historical)'
                          : '-',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Latest Failure Reason',
                      status.lastFailureReason ?? 'None',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Status Changed At',
                      dateFormat.format(status.statusChangedAt),
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Check Interval',
                      '${config.checkIntervalSeconds} seconds',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Ping Timeout',
                      '${config.timeoutSeconds} seconds',
                    ),
                    const Divider(height: 16),
                    _buildMetaRow(
                      'Max Global Concurrency',
                      '${config.maxConcurrentChecks} concurrent checks',
                    ),
                  ],
                ),
              ),

              // Admin Role Action Buttons
              if (isAdmin) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onTriggerCheck,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Trigger Manual Check'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            onToggleMaintenance?.call(!status.isMaintenance),
                        icon: Icon(
                          status.isMaintenance
                              ? Icons.build_circle_outlined
                              : Icons.build_circle_rounded,
                          size: 18,
                        ),
                        label: Text(
                          status.isMaintenance
                              ? 'Exit Maintenance'
                              : 'Set Maintenance Mode',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status.isMaintenance
                              ? Colors.orange
                              : theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (onEditOwner != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onEditOwner,
                      icon: Icon(
                        device.isOwnerAssigned
                            ? Icons.edit_rounded
                            : Icons.person_add_alt_1_rounded,
                        size: 18,
                        color: theme.primaryColor,
                      ),
                      label: Text(
                        device.isOwnerAssigned
                            ? 'Edit Assigned Person (${device.displayOwner})'
                            : 'Assign Person to Device',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
