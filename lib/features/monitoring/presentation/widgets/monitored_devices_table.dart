import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/device_status_entity.dart';
import '../../domain/entities/monitored_device.dart';
import 'device_status_chip.dart';

class MonitoredDevicesTable extends StatelessWidget {
  final List<MonitoredDevice> devices;
  final bool isAdmin;
  final Set<int> selectedDeviceIds;
  final ValueChanged<MonitoredDevice> onSelectDevice;
  final Function(int deviceId, bool selected)? onToggleSelect;
  final Function(bool selectAll)? onSelectAll;
  final ValueChanged<MonitoredDevice>? onTriggerCheck;
  final Function(MonitoredDevice device, bool isMaintenance)?
  onToggleMaintenance;
  final int failureThreshold;
  final VoidCallback? onClearFilters;

  const MonitoredDevicesTable({
    super.key,
    required this.devices,
    this.isAdmin = true,
    required this.onSelectDevice,
    this.selectedDeviceIds = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.onTriggerCheck,
    this.onToggleMaintenance,
    this.failureThreshold = 3,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isDark = tokens.isDark;
    final dateFormat = DateFormat('HH:mm:ss');

    if (devices.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: tokens.border),
        ),
        child: AppEmptyState.noFilterResults(
          onClearFilters: onClearFilters ?? () {},
        ),
      );
    }

    final headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: tokens.onTableHeader,
    );

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: DataTable(
            showCheckboxColumn: onToggleSelect != null,
            onSelectAll: onSelectAll != null
                ? (selectAll) => onSelectAll!(selectAll ?? false)
                : null,
            headingRowColor: WidgetStateProperty.all(tokens.tableHeader),
            horizontalMargin: AppSpacing.lg,
            columnSpacing: AppSpacing.xl,
            columns: [
              DataColumn(label: Text('Owner Name', style: headerStyle)),
              DataColumn(label: Text('Department', style: headerStyle)),
              DataColumn(label: Text('Device Name', style: headerStyle)),
              DataColumn(label: Text('IP Address', style: headerStyle)),
              DataColumn(label: Text('Office / Location', style: headerStyle)),
              DataColumn(label: Text('Status', style: headerStyle)),
              DataColumn(label: Text('Latency', style: headerStyle)),
              DataColumn(label: Text('Last Check', style: headerStyle)),
              DataColumn(
                label: SizedBox(
                  width: 120,
                  child: Text('Actions', style: headerStyle),
                ),
              ),
            ],
            rows: devices.map((item) {
              final device = item.device;
              final status = item.status;
              final isOnline =
                  status.status == DeviceStatusEnum.up ||
                  status.status == DeviceStatusEnum.degraded;
              final latencyStr = isOnline && status.lastLatencyMs != null
                  ? '${status.lastLatencyMs} ms'
                  : '-';
              final lastCheckStr = status.lastCheckAt != null
                  ? dateFormat.format(status.lastCheckAt!)
                  : '-';
              final isSelected = selectedDeviceIds.contains(device.id);

              return DataRow(
                selected: isSelected,
                onSelectChanged: onToggleSelect != null
                    ? (selected) =>
                          onToggleSelect!(device.id, selected ?? false)
                    : null,
                cells: [
                  // 1. Owner Name
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          device.type.toValue() == 'laptop'
                              ? Icons.laptop_windows_rounded
                              : Icons.desktop_windows_rounded,
                          size: 18,
                          color: tokens.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            device.displayOwner,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: device.isOwnerAssigned
                                  ? tokens.onTableRow
                                  : tokens.onStatusDegraded,
                              fontStyle: device.isOwnerAssigned
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 2. Department Badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? tokens.surfaceContainerHighest
                            : tokens.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: tokens.border,
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          device.department,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 3. Device Name
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: tokens.onTableRow,
                        ),
                      ),
                    ),
                  ),
                  // 4. IP Address
                  DataCell(
                    Text(
                      device.ip,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: tokens.primary,
                      ),
                    ),
                  ),
                  // 5. Office / Location
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        (device.officeLocation != null &&
                                device.officeLocation!.trim().isNotEmpty)
                            ? device.officeLocation!
                            : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  // 6. Status
                  DataCell(
                    DeviceStatusChip(
                      status: status.status,
                      isMaintenance: status.isMaintenance,
                      compact: true,
                      consecutiveFailures: status.consecutiveFailures,
                      failureThreshold: failureThreshold,
                      failureReason: status.lastFailureReason,
                    ),
                  ),
                  // 7. Latency
                  DataCell(
                    Text(
                      latencyStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: status.lastLatencyMs != null &&
                                status.lastLatencyMs! > 200
                            ? tokens.onStatusDegraded
                            : tokens.onTableRow,
                      ),
                    ),
                  ),
                  // 8. Last Check
                  DataCell(
                    Text(
                      lastCheckStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // 9. Actions (Guaranteed never clipped)
                  DataCell(
                    Container(
                      constraints: const BoxConstraints(minWidth: 120),
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            icon: Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: tokens.onSurfaceVariant,
                            ),
                            tooltip: 'View Details',
                            onPressed: () => onSelectDevice(item),
                          ),
                          if (isAdmin) ...[
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: tokens.onSurfaceVariant,
                              ),
                              tooltip: 'Trigger Manual Check',
                              onPressed: () => onTriggerCheck?.call(item),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              icon: Icon(
                                status.isMaintenance
                                    ? Icons.build_circle_outlined
                                    : Icons.build_circle_rounded,
                                size: 18,
                                color: status.isMaintenance
                                    ? tokens.onStatusDegraded
                                    : tokens.onSurfaceVariant,
                              ),
                              tooltip: status.isMaintenance
                                  ? 'Exit Maintenance'
                                  : 'Set Maintenance',
                              onPressed: () => onToggleMaintenance?.call(
                                item,
                                !status.isMaintenance,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
