import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/device_status_entity.dart';
import '../../domain/entities/monitored_device.dart';
import 'device_status_chip.dart';

class MonitoredDevicesTable extends StatelessWidget {
  final List<MonitoredDevice> devices;
  final UserRole userRole;
  final ValueChanged<MonitoredDevice> onSelectDevice;
  final ValueChanged<MonitoredDevice>? onTriggerCheck;
  final Function(MonitoredDevice device, bool isMaintenance)?
  onToggleMaintenance;

  const MonitoredDevicesTable({
    super.key,
    required this.devices,
    required this.userRole,
    required this.onSelectDevice,
    this.onTriggerCheck,
    this.onToggleMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = userRole == UserRole.admin;
    final dateFormat = DateFormat('HH:mm:ss');

    if (devices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.devices_other_rounded,
              size: 48,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Monitored Devices Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No PC/Laptop devices match the current filter or search criteria.',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.primaryColor.withValues(alpha: 0.04),
            ),
            horizontalMargin: 20,
            columnSpacing: 24,
            columns: const [
              // Prioritized columns: Owner Name, Department, Device Name, IP, Office/Location, Status, Latency, Last Check, Actions
              DataColumn(
                label: Text(
                  'Owner Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Department',
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
                  'Office / Location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
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
                  'Last Check',
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

              return DataRow(
                onSelectChanged: (_) => onSelectDevice(item),
                cells: [
                  // 1. Owner Name (Bold primary text)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          device.type.toValue() == 'laptop'
                              ? Icons.laptop_windows_rounded
                              : Icons.desktop_windows_rounded,
                          size: 18,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          device.displayOwner,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: device.isOwnerAssigned
                                ? null
                                : Colors.orangeAccent,
                            fontStyle: device.isOwnerAssigned
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 2. Department
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        device.department,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  // 3. Device Name
                  DataCell(
                    Text(device.name, style: const TextStyle(fontSize: 13)),
                  ),
                  // 4. IP Address
                  DataCell(
                    Text(
                      device.ip,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // 5. Office / Location
                  DataCell(
                    Text(
                      device.officeLocation ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  // 6. Status (Icon + Text Chip)
                  DataCell(
                    DeviceStatusChip(
                      status: status.status,
                      isMaintenance: status.isMaintenance,
                      compact: true,
                    ),
                  ),
                  // 7. Latency
                  DataCell(
                    Text(
                      latencyStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                            status.lastLatencyMs != null &&
                                status.lastLatencyMs! > 200
                            ? Colors.orange
                            : null,
                      ),
                    ),
                  ),
                  // 8. Last Check
                  DataCell(
                    Text(
                      lastCheckStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  // 9. Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                          ),
                          tooltip: 'View Details',
                          onPressed: () => onSelectDevice(item),
                        ),
                        if (isAdmin) ...[
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: 'Trigger Manual Check',
                            onPressed: () => onTriggerCheck?.call(item),
                          ),
                          IconButton(
                            icon: Icon(
                              status.isMaintenance
                                  ? Icons.build_circle_outlined
                                  : Icons.build_circle_rounded,
                              size: 18,
                              color: status.isMaintenance ? Colors.blue : null,
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
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
