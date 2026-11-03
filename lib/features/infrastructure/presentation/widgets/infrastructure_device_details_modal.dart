import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../monitoring/domain/entities/check_result.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../domain/entities/unifi_device_entity.dart';
import '../bloc/infrastructure_cubit.dart';
import '../bloc/infrastructure_state.dart';
import 'manage_infrastructure_dialog.dart';

class InfrastructureDeviceDetailsModal extends StatefulWidget {
  final UniFiDeviceEntity device;

  const InfrastructureDeviceDetailsModal({super.key, required this.device});

  static Future<void> show(BuildContext context, UniFiDeviceEntity device) {
    return showDialog(
      context: context,
      builder: (ctx) => InfrastructureDeviceDetailsModal(device: device),
    );
  }

  @override
  State<InfrastructureDeviceDetailsModal> createState() =>
      _InfrastructureDeviceDetailsModalState();
}

class _InfrastructureDeviceDetailsModalState
    extends State<InfrastructureDeviceDetailsModal> {
  bool _isPinging = false;
  CheckResult? _lastTestResult;

  Future<void> _runPingTest() async {
    setState(() {
      _isPinging = true;
    });

    try {
      final cubit = context.read<InfrastructureCubit>();
      final result = await cubit.pingDevice(widget.device);
      if (mounted) {
        setState(() {
          _lastTestResult = result;
          _isPinging = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPinging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;

    return BlocBuilder<InfrastructureCubit, InfrastructureState>(
      builder: (context, state) {
        final currentDevice = state.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );
        final status = state.getStatusFor(currentDevice);
        final incident = state.getIncidentFor(currentDevice);
        final statusEnum = status?.status ?? DeviceStatusEnum.unknown;

        return Dialog(
          backgroundColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Modal Header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getRoleIcon(currentDevice.role),
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentDevice.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${currentDevice.role.displayName} • ${currentDevice.ip}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      DeviceStatusChip(status: statusEnum),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // ── Modal Content ──
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Active Incident Banner (if any)
                          if (incident != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.statusDown.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.statusDown.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: AppColors.statusDown,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Active Incident #${incident.id}: ${incident.incidentType.name}',
                                        style: const TextStyle(
                                          color: AppColors.statusDown,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    incident.correlationMessage ??
                                        'Device is unreachable via ping.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Started: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(incident.startedAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Specification Details Grid
                          Text(
                            'Device Specifications',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  context,
                                  'Device Name',
                                  currentDevice.name,
                                ),
                                _buildDetailRow(
                                  context,
                                  'Management IP',
                                  currentDevice.ip,
                                ),
                                _buildDetailRow(
                                  context,
                                  'Device Category',
                                  currentDevice.role.displayName,
                                ),
                                _buildDetailRow(
                                  context,
                                  'Physical Location',
                                  currentDevice.location?.isNotEmpty == true
                                      ? currentDevice.location!
                                      : 'Not specified',
                                ),
                                _buildDetailRow(
                                  context,
                                  'Core Routing',
                                  currentDevice.performsRouting
                                      ? 'Yes (Core Gateway)'
                                      : 'No (Local Endpoint)',
                                ),
                                _buildDetailRow(
                                  context,
                                  'Critical Infrastructure',
                                  currentDevice.isCriticalInfrastructure
                                      ? 'Yes'
                                      : 'No',
                                ),
                                _buildDetailRow(
                                  context,
                                  'Monitoring Mode',
                                  'ICMP Ping Probe (Read-Only)',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Live Telemetry
                          Text(
                            'Live Status & Metrics',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  context,
                                  'Current Status',
                                  statusEnum.name.toUpperCase(),
                                  valueColor: _getStatusColor(statusEnum),
                                ),
                                _buildDetailRow(
                                  context,
                                  'Round-Trip Latency',
                                  status?.lastLatencyMs != null
                                      ? '${status!.lastLatencyMs} ms'
                                      : '--',
                                  valueColor:
                                      status?.status == DeviceStatusEnum.up
                                      ? AppColors.statusUp
                                      : null,
                                ),
                                _buildDetailRow(
                                  context,
                                  'Last Check Timestamp',
                                  status?.lastCheckAt != null
                                      ? DateFormat(
                                          'yyyy-MM-dd HH:mm:ss',
                                        ).format(status!.lastCheckAt!)
                                      : 'Never checked',
                                ),
                                _buildDetailRow(
                                  context,
                                  'Consecutive Failures',
                                  '${status?.consecutiveFailures ?? 0}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Interactive Ping Diagnostic Tool
                          Text(
                            'Live Diagnostics & Reachability',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'On-Demand ICMP Echo Probe',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isPinging
                                          ? null
                                          : _runPingTest,
                                      icon: _isPinging
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.network_ping_rounded,
                                              size: 16,
                                            ),
                                      label: Text(
                                        _isPinging
                                            ? 'Pinging...'
                                            : 'Ping Device Now',
                                      ),
                                    ),
                                  ],
                                ),
                                if (_lastTestResult != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _lastTestResult!.isSuccess
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _lastTestResult!.isSuccess
                                            ? Colors.green.withValues(
                                                alpha: 0.3,
                                              )
                                            : Colors.red.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _lastTestResult!.isSuccess
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: _lastTestResult!.isSuccess
                                              ? Colors.green
                                              : Colors.red,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _lastTestResult!.isSuccess
                                                ? 'Ping succeeded! Latency: ${_lastTestResult!.latencyMs} ms at ${DateFormat('HH:mm:ss').format(_lastTestResult!.timestamp)}'
                                                : 'Ping timed out (no ICMP reply from ${currentDevice.ip}) at ${DateFormat('HH:mm:ss').format(_lastTestResult!.timestamp)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: _lastTestResult!.isSuccess
                                                  ? Colors.green
                                                  : Colors.red,
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
                        ],
                      ),
                    ),
                  ),

                  // ── Modal Actions ──
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isAdmin)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ManageInfrastructureDialog.show(context);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Device Settings'),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color:
                  valueColor ??
                  (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(UniFiDeviceRole role) {
    switch (role) {
      case UniFiDeviceRole.gateway:
        return Icons.router;
      case UniFiDeviceRole.controller:
        return Icons.dns;
      case UniFiDeviceRole.switchDevice:
        return Icons.switch_access_shortcut;
      case UniFiDeviceRole.accessPoint:
        return Icons.wifi;
      case UniFiDeviceRole.otherUnknown:
        return Icons.devices_other;
    }
  }

  Color _getStatusColor(DeviceStatusEnum status) {
    switch (status) {
      case DeviceStatusEnum.up:
        return AppColors.statusUp;
      case DeviceStatusEnum.degraded:
        return AppColors.statusDegraded;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        return AppColors.statusDown;
      case DeviceStatusEnum.unknown:
        return AppColors.statusUnknown;
      case DeviceStatusEnum.stale:
        return AppColors.statusDegraded;
      case DeviceStatusEnum.maintenance:
        return AppColors.statusMaintenance;
    }
  }
}
