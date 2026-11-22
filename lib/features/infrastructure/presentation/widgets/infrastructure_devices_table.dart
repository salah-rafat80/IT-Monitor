import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_skeleton.dart';
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
    final tokens = context.appTokens;
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = true;

    return BlocConsumer<InfrastructureCubit, InfrastructureState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: tokens.statusDown,
            ),
          );
        } else if (state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.successMessage!),
              backgroundColor:
                  state.successMessage!.contains('UP') ||
                      state.successMessage!.contains('succeeded')
                  ? tokens.statusUp
                  : tokens.statusDown,
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
            final st = state.getStatusFor(d)?.status ?? DeviceStatusEnum.down;
            if (_statusFilter == DeviceStatusEnum.down) {
              if (st != DeviceStatusEnum.down &&
                  st != DeviceStatusEnum.unknown &&
                  st != DeviceStatusEnum.unreachable) {
                return false;
              }
            } else if (st != _statusFilter) {
              return false;
            }
          }

          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toolbar & KPI Summary ──
            if (widget.showHeaderActions) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 950;
                  final badges = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildSummaryBadge(
                        'Total Assets: ${state.totalCount}',
                        tokens.primary,
                        isDark,
                      ),
                      _buildSummaryBadge(
                        'Up: ${state.upCount}',
                        tokens.statusUp,
                        isDark,
                      ),
                      _buildSummaryBadge(
                        'Down: ${state.downCount}',
                        tokens.statusDown,
                        isDark,
                      ),
                      _buildSummaryBadge(
                        'Unknown: ${state.unknownCount}',
                        tokens.statusUnknown,
                        isDark,
                      ),
                    ],
                  );

                  final actions = Wrap(
                    spacing: 12,
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
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          state.isCheckingAll
                              ? 'Testing All...'
                              : 'Ping All Assets',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (isAdmin)
                        OutlinedButton.icon(
                          onPressed: () =>
                              ManageInfrastructureDialog.show(context),
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('Manage Assets'),
                        ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [badges, const SizedBox(height: 12), actions],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: badges),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Search & Filter Controls ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;

                final searchField = TextField(
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
                );

                final roleDropdown = DropdownButtonFormField<UniFiDeviceRole?>(
                  isExpanded: true,
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
                      child: Text('All Roles', overflow: TextOverflow.ellipsis),
                    ),
                    ...UniFiDeviceRole.values.map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          r.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _roleFilter = val),
                );

                final statusDropdown =
                    DropdownButtonFormField<DeviceStatusEnum?>(
                      isExpanded: true,
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
                          child: Text(
                            'All Statuses',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: DeviceStatusEnum.up,
                          child: Text('Up', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: DeviceStatusEnum.down,
                          child: Text(
                            'Disconnected',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: DeviceStatusEnum.degraded,
                          child: Text(
                            'Degraded',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _statusFilter = val),
                    );

                if (isNarrow) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: roleDropdown),
                          const SizedBox(width: 10),
                          Expanded(child: statusDropdown),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: roleDropdown),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: statusDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Table Content ──
            if (state.isLoading && state.devices.isEmpty)
              AppSkeleton.table(rowCount: 6, columnCount: 8)
            else if (filteredDevices.isEmpty)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tokens.cardBorder,
                  ),
                ),
                child: state.devices.isEmpty
                    ? AppEmptyState.firstUse(
                        entityName: 'Infrastructure Assets',
                        actionLabel: 'Manage Assets',
                        onAction: () => ManageInfrastructureDialog.show(context),
                      )
                    : AppEmptyState.noFilterResults(
                        query: _searchController.text,
                        onClearFilters: () {
                          setState(() {
                            _searchController.clear();
                            _roleFilter = null;
                            _statusFilter = null;
                          });
                        },
                      ),
              )
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tokens.cardBorder,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        tokens.surfaceContainerLow,
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
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    dev.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                    tokens,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getRoleBadgeColor(
                                      dev.role,
                                      tokens,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  dev.role.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getRoleBadgeColor(dev.role, tokens),
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
                                  color: tokens.textSecondary,
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
                                      ? tokens.statusUp
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
                                  color: tokens.textSecondary,
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

  Color _getRoleBadgeColor(UniFiDeviceRole role, AppColors tokens) {
    switch (role) {
      case UniFiDeviceRole.gateway:
        return tokens.primary;
      case UniFiDeviceRole.controller:
        return tokens.statusUnreachable;
      case UniFiDeviceRole.switchDevice:
        return tokens.second;
      case UniFiDeviceRole.accessPoint:
        return tokens.accent;
      case UniFiDeviceRole.otherUnknown:
        return tokens.statusUnknown;
    }
  }
}
