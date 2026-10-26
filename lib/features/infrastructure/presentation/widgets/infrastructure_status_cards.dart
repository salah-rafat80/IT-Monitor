import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../domain/entities/unifi_device_entity.dart';
import '../bloc/infrastructure_cubit.dart';
import '../bloc/infrastructure_state.dart';
import 'infrastructure_device_details_modal.dart';
import 'manage_infrastructure_dialog.dart';

class InfrastructureStatusCards extends StatelessWidget {
  const InfrastructureStatusCards({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<InfrastructureCubit, InfrastructureState>(
      builder: (context, state) {
        final authState = context.watch<AuthCubit>().state;
        final isAdmin = authState is AuthAuthenticated
            ? authState.user.isAdmin
            : false;

        if (state.devices.isEmpty) {
          return _buildEmptyStateCard(context, theme, isDark, isAdmin);
        }

        final cubit = context.read<InfrastructureCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.hub_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Critical UniFi Infrastructure',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${state.totalCount} Assets (${state.upCount} Up, ${state.downCount} Down, ${state.unknownCount} Unknown)',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: state.isCheckingAll
                          ? null
                          : () => cubit.pingAllInfrastructure(),
                      icon: state.isCheckingAll
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.network_ping_rounded, size: 16),
                      label: Text(
                        state.isCheckingAll ? 'Testing All...' : 'Ping All',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Manage Infrastructure'),
                        onPressed: () =>
                            ManageInfrastructureDialog.show(context),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final items = state.devices.map((device) {
                  return _buildDeviceCard(
                    context,
                    theme,
                    isDark,
                    device,
                    state.getStatusFor(device),
                    state.getIncidentFor(device),
                    isAdmin,
                  );
                }).toList();

                if (isWide) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: items
                        .map((w) => SizedBox(width: 320, child: w))
                        .toList(),
                  );
                } else {
                  return Column(
                    children: items
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: w,
                          ),
                        )
                        .toList(),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isAdmin,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.router, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical UniFi Infrastructure',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No UniFi infrastructure devices registered yet. Authoritative management IPs can be configured for core routing and controller health tracking.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Configure Infrastructure'),
              onPressed: () => ManageInfrastructureDialog.show(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    UniFiDeviceEntity device,
    DeviceStatusEntity? status,
    dynamic incident,
    bool isAdmin,
  ) {
    final statusEnum = status?.status ?? DeviceStatusEnum.unknown;
    final isDown = statusEnum == DeviceStatusEnum.down;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDown ? AppColors.statusDown : cardBorder,
          width: isDown ? 1.5 : 1.0,
        ),
        boxShadow: isDown
            ? [
                BoxShadow(
                  color: AppColors.statusDown.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Icon(
                      _getRoleIcon(device.role),
                      color: device.isCriticalInfrastructure
                          ? AppColors.primary
                          : textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        device.role.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: device.isCriticalInfrastructure
                              ? AppColors.primary
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DeviceStatusChip(status: statusEnum),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            device.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            device.ip,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          if (device.location != null && device.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    device.location!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, size: 13, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    status?.status == DeviceStatusEnum.up &&
                            status?.lastLatencyMs != null
                        ? '${status!.lastLatencyMs} ms'
                        : '--',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: status?.status == DeviceStatusEnum.up
                          ? AppColors.statusUp
                          : textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    status?.lastCheckAt != null
                        ? _formatTime(status!.lastCheckAt!)
                        : 'Never',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (device.isCriticalInfrastructure)
                _buildBadge('Critical Core Gateway', AppColors.primary),
              if (device.requiresAdminConfirmation)
                _buildBadge('Needs Confirmation', AppColors.statusDegraded),
              if (device.isController)
                _buildBadge('Management Plane', AppColors.statusUnreachable),
              if (device.role == UniFiDeviceRole.accessPoint)
                _buildBadge('Wireless AP', Colors.teal),
              if (device.linkedSubnets.isNotEmpty)
                _buildBadge(
                  '${device.linkedSubnets.length} Subnet(s)',
                  AppColors.accent,
                ),
            ],
          ),

          if (incident != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.statusDown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.statusDown.withValues(alpha: 0.3),
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
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active Incident #${incident.id}',
                        style: const TextStyle(
                          color: AppColors.statusDown,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (incident.correlationMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      incident.correlationMessage!,
                      style: const TextStyle(
                        color: AppColors.statusDown,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (device.isGateway && isDown) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.statusDown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.statusDown.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.statusDown,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      device.linkedSubnets.isNotEmpty
                          ? 'Routing impacted on: ${device.linkedSubnets.join(', ')}'
                          : 'Core routing impacted. Check downstream connectivity.',
                      style: const TextStyle(
                        color: AppColors.statusDown,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.info_outline, size: 14),
                label: const Text(
                  'Diagnostics',
                  style: TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                ),
                onPressed: () =>
                    InfrastructureDeviceDetailsModal.show(context, device),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon:
                        context.watch<InfrastructureCubit>().state.isChecking(
                          device,
                        )
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 18),
                    tooltip: 'Test Reachability / Ping Now',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        context.read<InfrastructureCubit>().pingDevice(device),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit Settings',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ManageInfrastructureDialog.show(
                        context,
                        device: device,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getRoleIcon(UniFiDeviceRole role) {
    switch (role) {
      case UniFiDeviceRole.gateway:
        return Icons.router;
      case UniFiDeviceRole.controller:
        return Icons.cloud_outlined;
      case UniFiDeviceRole.switchDevice:
        return Icons.alt_route;
      case UniFiDeviceRole.accessPoint:
        return Icons.wifi;
      case UniFiDeviceRole.otherUnknown:
        return Icons.devices_other;
    }
  }
}
