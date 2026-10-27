import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../domain/entities/unifi_device_entity.dart';
import '../bloc/infrastructure_cubit.dart';
import '../bloc/infrastructure_state.dart';
import 'infrastructure_device_details_modal.dart';
import 'manage_infrastructure_dialog.dart';

class InfrastructureDevicesTable extends StatefulWidget {
  final bool showHeaderActions;

  const InfrastructureDevicesTable({super.key, this.showHeaderActions = true});

  @override
  State<InfrastructureDevicesTable> createState() =>
      _InfrastructureDevicesTableState();
}

class _InfrastructureDevicesTableState
    extends State<InfrastructureDevicesTable> {
  final TextEditingController _searchController = TextEditingController();
  UniFiDeviceRole? _roleFilter;
  DeviceStatusEnum? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = context.watch<AuthCubit>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;

    return BlocConsumer<InfrastructureCubit, InfrastructureState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.statusDown,
            ),
          );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor:
                  state.successMessage!.contains('UP') ||
                      state.successMessage!.contains('succeeded')
                  ? AppColors.statusUp
                  : AppColors.statusDown,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<InfrastructureCubit>();
        final query = _searchController.text.trim().toLowerCase();

        final filteredDevices = state.devices.where((d) {
          if (query.isNotEmpty) {
            final matchName = d.name.toLowerCase().contains(query);
            final matchIp = d.ip.toLowerCase().contains(query);
            final matchLoc = (d.location ?? '').toLowerCase().contains(query);
            final matchRole = d.role.displayName.toLowerCase().contains(query);
            if (!matchName && !matchIp && !matchLoc && !matchRole) return false;
          }

          if (_roleFilter != null && d.role != _roleFilter) {
            return false;
          }

          if (_statusFilter != null) {
            final st =
                state.getStatusFor(d)?.status ?? DeviceStatusEnum.unknown;
            if (st != _statusFilter) return false;
          }

          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toolbar & KPI Summary ──
            if (widget.showHeaderActions) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildSummaryBadge(
                        'Total Assets: ${state.totalCount}',
                        AppColors.primary,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryBadge(
                        'Up: ${state.upCount}',
                        AppColors.statusUp,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryBadge(
                        'Down: ${state.downCount}',
                        AppColors.statusDown,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryBadge(
                        'Unknown: ${state.unknownCount}',
                        AppColors.statusUnknown,
                        isDark,
                      ),
                    ],
                  ),
                  Row(
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
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          state.isCheckingAll
                              ? 'Testing All...'
                              : 'Ping All Assets',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ManageInfrastructureDialog.show(context),
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('Manage Assets'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Search & Filter Controls ──
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by AP name, IP address, or location...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<UniFiDeviceRole?>(
                    initialValue: _roleFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter Role',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Roles'),
                      ),
                      ...UniFiDeviceRole.values.map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.displayName),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _roleFilter = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<DeviceStatusEnum?>(
                    initialValue: _statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Filter Status',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(
                        value: DeviceStatusEnum.up,
                        child: Text('Up'),
                      ),
                      DropdownMenuItem(
                        value: DeviceStatusEnum.down,
                        child: Text('Down'),
                      ),
                      DropdownMenuItem(
                        value: DeviceStatusEnum.degraded,
                        child: Text('Degraded'),
                      ),
                      DropdownMenuItem(
                        value: DeviceStatusEnum.unknown,
                        child: Text('Unknown'),
                      ),
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Table Content ──
            if (filteredDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 40,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.devices.isEmpty
                          ? 'No UniFi infrastructure devices registered yet.'
                          : 'No devices matched your search filter.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use "Ping All Assets" to verify connectivity or "Manage Assets" to add new infrastructure.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Device Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'IP Address',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Role / Category',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Location',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Latency',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Last Checked',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Actions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: filteredDevices.map((dev) {
                        final status = state.getStatusFor(dev);
                        final incident = state.getIncidentFor(dev);
                        final statusEnum =
                            status?.status ?? DeviceStatusEnum.unknown;
                        final isChecking = state.isChecking(dev);

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DeviceStatusChip(status: statusEnum),
                                  if (incident != null) ...[
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message:
                                          incident.correlationMessage ??
                                          'Active incident',
                                      child: const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: AppColors.statusDown,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () =>
                                    InfrastructureDeviceDetailsModal.show(
                                      context,
                                      dev,
                                    ),
                                child: Text(
                                  dev.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dev.ip,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                    ),
                                    tooltip: 'Copy IP',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: dev.ip),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copied ${dev.ip} to clipboard',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleBadgeColor(
                                    dev.role,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getRoleBadgeColor(
                                      dev.role,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  dev.role.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getRoleBadgeColor(dev.role),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                dev.location?.isNotEmpty == true
                                    ? dev.location!
                                    : 'Not specified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                status?.status == DeviceStatusEnum.up &&
                                        status?.lastLatencyMs != null
                                    ? '${status!.lastLatencyMs} ms'
                                    : '--',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: status?.status == DeviceStatusEnum.up
                                      ? AppColors.statusUp
                                      : null,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                status?.lastCheckAt != null
                                    ? DateFormat(
                                        'HH:mm:ss',
                                      ).format(status!.lastCheckAt!)
                                    : 'Never',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'Test Reachability / Ping Now',
                                    child: IconButton(
                                      icon: isChecking
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.network_ping_rounded,
                                              size: 18,
                                            ),
                                      onPressed: isChecking
                                          ? null
                                          : () => cubit.pingDevice(dev),
                                    ),
                                  ),
                                  Tooltip(
                                    message: 'View Diagnostics & Specs',
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          InfrastructureDeviceDetailsModal.show(
                                            context,
                                            dev,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getRoleBadgeColor(UniFiDeviceRole role) {
    switch (role) {
      case UniFiDeviceRole.gateway:
        return AppColors.primary;
      case UniFiDeviceRole.controller:
        return AppColors.statusUnreachable;
      case UniFiDeviceRole.switchDevice:
        return Colors.indigo;
      case UniFiDeviceRole.accessPoint:
        return Colors.teal;
      case UniFiDeviceRole.otherUnknown:
        return Colors.blueGrey;
    }
  }
}
