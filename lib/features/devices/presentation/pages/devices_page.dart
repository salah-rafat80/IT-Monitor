import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/presentation/bloc/monitoring_cubit.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../domain/entities/device_entity.dart';
import '../../domain/entities/inventory_import_preview.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../../infrastructure/presentation/bloc/infrastructure_cubit.dart';
import '../../../infrastructure/presentation/widgets/infrastructure_devices_table.dart';
import '../bloc/devices_cubit.dart';
import '../widgets/assign_owner_dialog.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialFactoryId = context
        .read<FactoryCubit>()
        .state
        .selectedFactoryId;
    context.read<DevicesCubit>().setFactory(initialFactoryId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(DeviceType type) {
    switch (type) {
      case DeviceType.pc:
        return Icons.desktop_windows_outlined;
      case DeviceType.laptop:
        return Icons.laptop_mac_outlined;
      case DeviceType.mobile:
        return Icons.smartphone_outlined;
      case DeviceType.ipCamera:
        return Icons.videocam_outlined;
      case DeviceType.printer:
        return Icons.print_outlined;
      case DeviceType.server:
        return Icons.dns_outlined;
      case DeviceType.switchDevice:
        return Icons.alt_route_outlined;
      case DeviceType.router:
        return Icons.router_outlined;
      case DeviceType.wirelessAccessPoint:
        return Icons.wifi_outlined;
      case DeviceType.otherNetworkDevice:
        return Icons.hub_outlined;
      case DeviceType.other:
        return Icons.devices_other_outlined;
      case DeviceType.unknown:
        return Icons.device_unknown_outlined;
    }
  }

  void _showAddDeviceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final ownerController = TextEditingController();
    final deptController = TextEditingController();
    final officeController = TextEditingController();
    final vendorController = TextEditingController();
    final modelController = TextEditingController();
    final macController = TextEditingController();
    final hostnameController = TextEditingController();
    final notesController = TextEditingController();
    final switchController = TextEditingController();

    DeviceType selectedType = DeviceType.pc;
    bool isMonitored = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline, color: Color(0xFF0F62FE)),
              SizedBox(width: 8),
              Text('Add Asset to Authoritative Inventory'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Device Name *',
                            hintText: 'e.g. PC-FIN-021',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP Address *',
                            hintText: 'e.g. 192.168.27.45',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<DeviceType>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Device Category *',
                          ),
                          items: DeviceType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t.displayName,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedType = val;
                                isMonitored = val.isMonitoredByDefault;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: deptController,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            hintText: 'e.g. Finance, IT, Operations',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ownerController,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Owner / Person',
                            hintText: 'e.g. Ahmed Mostafa (or Unassigned)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: officeController,
                          decoration: const InputDecoration(
                            labelText: 'Office / Location',
                            hintText: 'e.g. Building A - Room 204',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vendorController,
                          decoration: const InputDecoration(
                            labelText: 'Vendor / Manufacturer',
                            hintText: 'e.g. Dell, HP, Apple',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: modelController,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText: 'e.g. Latitude 5520',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: macController,
                          decoration: const InputDecoration(
                            labelText: 'MAC Address',
                            hintText: 'e.g. 00:1A:2B:3C:4D:5E',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hostnameController,
                          decoration: const InputDecoration(
                            labelText: 'Hostname / FQDN',
                            hintText: 'e.g. fin-pc02.company.local',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: switchController,
                          decoration: const InputDecoration(
                            labelText: 'Parent Switch Name (Optional)',
                            hintText: 'e.g. SW-FL2-MAIN',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Asset tag, serial, remarks...',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Continuous 24/7 Monitoring',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      isMonitored
                          ? 'Device will receive regular ICMP health checks and alerts.'
                          : 'Kept in inventory as unmonitored asset without ping alerts.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    value: isMonitored,
                    onChanged: (val) => setState(() => isMonitored = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final ip = ipController.text.trim();
                final name = nameController.text.trim();
                if (ip.isNotEmpty && name.isNotEmpty) {
                  final now = DateTime.now();
                  final factoryId =
                      context.read<FactoryCubit>().state.selectedFactoryId ??
                      'bnf';
                  final newDevice = DeviceEntity(
                    id: 0,
                    factoryId: factoryId,
                    name: name,
                    type: selectedType,
                    ip: ip,
                    ownerName: ownerController.text.trim().isNotEmpty
                        ? ownerController.text.trim()
                        : 'Unassigned',
                    department: deptController.text.trim().isNotEmpty
                        ? deptController.text.trim()
                        : 'General',
                    officeLocation: officeController.text.trim().isNotEmpty
                        ? officeController.text.trim()
                        : null,
                    parentSwitchName: switchController.text.trim().isNotEmpty
                        ? switchController.text.trim()
                        : null,
                    vendor: vendorController.text.trim().isNotEmpty
                        ? vendorController.text.trim()
                        : null,
                    model: modelController.text.trim().isNotEmpty
                        ? modelController.text.trim()
                        : null,
                    mac: macController.text.trim().isNotEmpty
                        ? macController.text.trim()
                        : null,
                    hostname: hostnameController.text.trim().isNotEmpty
                        ? hostnameController.text.trim()
                        : null,
                    notes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                    isMonitored: isMonitored,
                    isEnabled: true,
                    createdAt: now,
                  );
                  context.read<DevicesCubit>().addDevice(newDevice);
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save Asset'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeviceDialog(BuildContext context, DeviceEntity device) {
    final nameController = TextEditingController(text: device.name);
    final ipController = TextEditingController(text: device.ip);
    final ownerController = TextEditingController(
      text: device.ownerName == 'Unassigned' ? '' : device.ownerName,
    );
    final deptController = TextEditingController(text: device.department);
    final officeController = TextEditingController(
      text: device.officeLocation ?? '',
    );
    final vendorController = TextEditingController(text: device.vendor ?? '');
    final modelController = TextEditingController(text: device.model ?? '');
    final macController = TextEditingController(text: device.mac ?? '');
    final hostnameController = TextEditingController(
      text: device.hostname ?? '',
    );
    final notesController = TextEditingController(text: device.notes ?? '');
    final switchController = TextEditingController(
      text: device.parentSwitchName ?? '',
    );

    DeviceType selectedType = device.type;
    bool isMonitored = device.isMonitored;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFF0F62FE)),
              const SizedBox(width: 8),
              Text('Edit Asset: ${device.name}'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Device Name *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ipController,
                          decoration: const InputDecoration(
                            labelText: 'IP Address *',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<DeviceType>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Device Category *',
                          ),
                          items: DeviceType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t.displayName,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedType = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: deptController,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ownerController,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Owner / Person',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: officeController,
                          decoration: const InputDecoration(
                            labelText: 'Office / Location',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vendorController,
                          decoration: const InputDecoration(
                            labelText: 'Vendor / Manufacturer',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: modelController,
                          decoration: const InputDecoration(labelText: 'Model'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: macController,
                          decoration: const InputDecoration(
                            labelText: 'MAC Address',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hostnameController,
                          decoration: const InputDecoration(
                            labelText: 'Hostname / FQDN',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: switchController,
                          decoration: const InputDecoration(
                            labelText: 'Parent Switch Name',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: notesController,
                          decoration: const InputDecoration(labelText: 'Notes'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Continuous 24/7 Monitoring',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      isMonitored
                          ? 'Device receives ICMP reachability checks.'
                          : 'Unmonitored asset; will not trigger down alerts.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    value: isMonitored,
                    onChanged: (val) => setState(() => isMonitored = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final ip = ipController.text.trim();
                final name = nameController.text.trim();
                if (ip.isNotEmpty && name.isNotEmpty) {
                  final updated = device.copyWith(
                    name: name,
                    type: selectedType,
                    ip: ip,
                    ownerName: ownerController.text.trim().isNotEmpty
                        ? ownerController.text.trim()
                        : 'Unassigned',
                    department: deptController.text.trim().isNotEmpty
                        ? deptController.text.trim()
                        : 'General',
                    officeLocation: officeController.text.trim().isNotEmpty
                        ? officeController.text.trim()
                        : null,
                    parentSwitchName: switchController.text.trim().isNotEmpty
                        ? switchController.text.trim()
                        : null,
                    vendor: vendorController.text.trim().isNotEmpty
                        ? vendorController.text.trim()
                        : null,
                    model: modelController.text.trim().isNotEmpty
                        ? modelController.text.trim()
                        : null,
                    mac: macController.text.trim().isNotEmpty
                        ? macController.text.trim()
                        : null,
                    hostname: hostnameController.text.trim().isNotEmpty
                        ? hostnameController.text.trim()
                        : null,
                    notes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                    isMonitored: isMonitored,
                    updatedAt: DateTime.now(),
                  );
                  context.read<DevicesCubit>().updateDevice(updated);
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDeviceDialog(BuildContext context, DeviceEntity device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Asset Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${device.name}" (${device.ip}) from the authoritative inventory?\n\n'
          'This action removes the asset from the persistent database.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              context.read<DevicesCubit>().deleteDevice(device.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete Asset',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetailsDialog(BuildContext context, DeviceEntity device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_getCategoryIcon(device.type), color: const Color(0xFF0F62FE)),
            const SizedBox(width: 8),
            Expanded(child: Text(device.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Asset ID', '#${device.id}'),
              _DetailRow('Device Category', device.type.displayName),
              _DetailRow('IP Address', device.ip),
              if (device.hostname != null)
                _DetailRow('Hostname', device.hostname!),
              if (device.mac != null) _DetailRow('MAC Address', device.mac!),
              _DetailRow('Assigned Person', device.displayOwner),
              _DetailRow('Department', device.department),
              _DetailRow('Office / Location', device.officeLocation ?? '—'),
              if (device.vendor != null) _DetailRow('Vendor', device.vendor!),
              if (device.model != null) _DetailRow('Model', device.model!),
              if (device.parentSwitchName != null)
                _DetailRow('Parent Switch', device.parentSwitchName!),
              _DetailRow(
                '24/7 Monitoring',
                device.isMonitored ? 'Enabled' : 'Disabled (Unmonitored Asset)',
              ),
              _DetailRow(
                'Active State',
                device.isEnabled ? 'Enabled' : 'Disabled',
              ),
              if (device.notes != null) _DetailRow('Notes', device.notes!),
              _DetailRow(
                'Created At',
                device.createdAt.toLocal().toString().split('.').first,
              ),
              if (device.updatedAt != null)
                _DetailRow(
                  'Last Updated',
                  device.updatedAt!.toLocal().toString().split('.').first,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAssignOwnerDialog(BuildContext context, DeviceEntity device) {
    final cubit = context.read<DevicesCubit>();
    showDialog(
      context: context,
      builder: (dialogCtx) => AssignOwnerDialog(
        device: device,
        onSave: (newOwner) async {
          final success = await cubit.assignDeviceOwner(
            deviceId: device.id,
            ownerName: newOwner,
          );
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Assigned person for ${device.ip} updated to "$newOwner".',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
          return success;
        },
        onClear: () async {
          final success = await cubit.assignDeviceOwner(
            deviceId: device.id,
            ownerName: 'Unassigned',
          );
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cleared assigned person for ${device.ip} (marked Unassigned).',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return success;
        },
      ),
    );
  }

  void _showImportPreviewDialog(
    BuildContext context,
    InventoryImportPreview preview,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F62FE)),
            const SizedBox(width: 8),
            Text(
              'Inventory Import Preview (${preview.totalRowsProcessed} Rows Processed)',
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SummaryChip(
                    label: 'Valid Devices: ${preview.validCount}',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label:
                        'Excluded Duplicate IPs: ${preview.excludedDuplicateIpCount}',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Invalid Records: ${preview.invalidCount}',
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (preview.excludedDuplicateIps.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade700),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Duplicate IP Protection Rule Triggered',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The following duplicate IPs appeared more than once or exist in DB and were REJECTED ENTIRELY from monitoring: '
                        '${preview.excludedDuplicateIps.join(", ")}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Valid Monitored Devices Ready to Commit'),
                          Tab(text: 'Validation Error Log'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Owner Name')),
                                    DataColumn(label: Text('Department')),
                                    DataColumn(label: Text('Device Name')),
                                    DataColumn(label: Text('IP Address')),
                                    DataColumn(label: Text('Location')),
                                  ],
                                  rows: preview.validDevices
                                      .map(
                                        (d) => DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                d.ownerName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(d.department)),
                                            DataCell(Text(d.name)),
                                            DataCell(Text(d.ip)),
                                            DataCell(
                                              Text(d.officeLocation ?? '—'),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Row #')),
                                    DataColumn(label: Text('Device / IP')),
                                    DataColumn(label: Text('Rejection Reason')),
                                  ],
                                  rows: preview.invalidRecords
                                      .map(
                                        (err) => DataRow(
                                          cells: [
                                            DataCell(
                                              Text('Row ${err.rowIndex}'),
                                            ),
                                            DataCell(
                                              Text(
                                                '${err.deviceName} (${err.rawIp})',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                err.reason,
                                                style: TextStyle(
                                                  color: Colors.red.shade300,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: preview.validCount == 0
                ? null
                : () {
                    context.read<DevicesCubit>().confirmImport(
                      preview.validDevices,
                    );
                    Navigator.pop(dialogContext);
                  },
            child: Text('Confirm & Commit ${preview.validCount} Devices'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;

    final infraState = context.watch<InfrastructureCubit>().state;
    final devicesState = context.watch<DevicesCubit>().state;
    final totalAssetsCount = devicesState is DevicesLoaded
        ? devicesState.allDevices.length
        : 37;

    return BlocListener<FactoryCubit, FactoryState>(
      listener: (context, fState) {
        context.read<DevicesCubit>().setFactory(fState.selectedFactoryId);
        context.read<InfrastructureCubit>().setFactory(
          fState.selectedFactoryId,
        );
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Authoritative Inventory & Infrastructure'),
            bottom: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  text: 'All Persistent Assets ($totalAssetsCount)',
                ),
                Tab(
                  icon: const Icon(Icons.hub_outlined, size: 18),
                  text:
                      'Network Infrastructure & UniFi APs (${infraState.totalCount})',
                ),
              ],
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () async {
                  final cubit = context.read<DevicesCubit>();
                  if (cubit.state is DevicesLoaded) {
                    final loaded = cubit.state as DevicesLoaded;
                    final buffer = StringBuffer();
                    buffer.writeln(
                      'Owner Name,Department,Device Name,IP Address,Category,Location,MAC,Hostname,Monitored,Status',
                    );
                    for (final d in loaded.filteredDevices) {
                      buffer.writeln(
                        '"${d.ownerName}","${d.department}","${d.name}",${d.ip},"${d.type.displayName}","${d.officeLocation ?? ''}","${d.mac ?? ''}","${d.hostname ?? ''}",${d.isMonitored ? 'Yes' : 'No'},${d.isEnabled ? 'Enabled' : 'Disabled'}',
                      );
                    }
                    final dir =
                        await getDownloadsDirectory() ??
                        await getApplicationDocumentsDirectory();
                    final file = File(
                      '${dir.path}/Inventory_Assets_${DateTime.now().millisecondsSinceEpoch}.csv',
                    );
                    await file.writeAsString(buffer.toString());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Assets exported to ${file.path}'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: 12),
              if (isAdmin) ...[
                ElevatedButton.icon(
                  onPressed: () => _showAddDeviceDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Device'),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          body: TabBarView(
            children: [
              BlocConsumer<DevicesCubit, DevicesState>(
                listener: (context, state) {
                  if (state is DevicesError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  } else if (state is ImportPreviewState) {
                    _showImportPreviewDialog(context, state.preview);
                  }
                },
                builder: (context, state) {
                  if (state is DevicesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is DevicesLoaded) {
                    final departments = {
                      'All',
                      ...state.allDevices.map((d) => d.department),
                    };
                    final categories = {
                      'All',
                      ...state.allDevices.map((d) => d.type.displayName),
                    };

                    return Column(
                      children: [
                        // Top Search & Filter Bar
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Search by Owner, Department, Name, IP, MAC, Hostname...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    context.read<DevicesCubit>().filterDevices(
                                      query: val,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value:
                                    categories.contains(state.selectedCategory)
                                    ? state.selectedCategory
                                    : 'All',
                                items: categories
                                    .map(
                                      (cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text('Category: $cat'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    context.read<DevicesCubit>().filterDevices(
                                      category: val,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value:
                                    departments.contains(
                                      state.selectedDepartment,
                                    )
                                    ? state.selectedDepartment
                                    : 'All',
                                items: departments
                                    .map(
                                      (dept) => DropdownMenuItem(
                                        value: dept,
                                        child: Text('Dept: $dept'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    context.read<DevicesCubit>().filterDevices(
                                      department: val,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: state.selectedMonitoring,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('Monitoring: All'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Monitored',
                                    child: Text('Monitoring: Monitored'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Unmonitored',
                                    child: Text('Monitoring: Not Monitored'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    context.read<DevicesCubit>().filterDevices(
                                      monitoring: val,
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Showing: ${state.filteredDevices.length} / ${state.allDevices.length}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Devices Table
                        Expanded(
                          child: state.filteredDevices.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No persistent assets found matching filter.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: BlocBuilder<MonitoringCubit, MonitoringState>(
                                      builder: (context, monitoringState) {
                                        final Map<int, DeviceStatusEntity>
                                        liveStatusMap = {};
                                        if (monitoringState
                                            is MonitoringActive) {
                                          for (final s
                                              in monitoringState.statuses) {
                                            liveStatusMap[s.deviceId] = s;
                                          }
                                        }

                                        return DataTable(
                                          columns: const [
                                            DataColumn(
                                              label: Text('Owner Name'),
                                            ),
                                            DataColumn(
                                              label: Text('Department'),
                                            ),
                                            DataColumn(
                                              label: Text('Device Name'),
                                            ),
                                            DataColumn(
                                              label: Text('IP Address'),
                                            ),
                                            DataColumn(label: Text('Category')),
                                            DataColumn(label: Text('Location')),
                                            DataColumn(label: Text('Status')),
                                            DataColumn(
                                              label: Text('Monitoring'),
                                            ),
                                            DataColumn(label: Text('Actions')),
                                          ],
                                          rows: state.filteredDevices.map((
                                            device,
                                          ) {
                                            final liveStatus =
                                                liveStatusMap[device.id];
                                            final DeviceStatusEnum statusEnum =
                                                liveStatus?.status ??
                                                DeviceStatusEnum.unknown;
                                            final bool isMaint =
                                                liveStatus?.isMaintenance ??
                                                false;

                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  InkWell(
                                                    onTap: isAdmin
                                                        ? () =>
                                                              _showAssignOwnerDialog(
                                                                context,
                                                                device,
                                                              )
                                                        : null,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            device.displayOwner,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                              color:
                                                                  device
                                                                      .isOwnerAssigned
                                                                  ? null
                                                                  : Colors
                                                                        .orangeAccent,
                                                              fontStyle:
                                                                  device
                                                                      .isOwnerAssigned
                                                                  ? FontStyle
                                                                        .normal
                                                                  : FontStyle
                                                                        .italic,
                                                            ),
                                                          ),
                                                          if (isAdmin) ...[
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                            Icon(
                                                              device.isOwnerAssigned
                                                                  ? Icons
                                                                        .edit_rounded
                                                                  : Icons
                                                                        .add_circle_outline_rounded,
                                                              size: 14,
                                                              color: Theme.of(
                                                                context,
                                                              ).primaryColor,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(device.department),
                                                ),
                                                DataCell(Text(device.name)),
                                                DataCell(
                                                  Text(
                                                    device.ip,
                                                    style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        _getCategoryIcon(
                                                          device.type,
                                                        ),
                                                        size: 16,
                                                        color: Colors.blueGrey,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        device.type.displayName,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    device.officeLocation ??
                                                        '—',
                                                  ),
                                                ),
                                                DataCell(
                                                  !device.isEnabled
                                                      ? Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red
                                                                .withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors.red
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            'Disabled',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                          ),
                                                        )
                                                      : (device.isMonitored
                                                            ? DeviceStatusChip(
                                                                status:
                                                                    statusEnum,
                                                                isMaintenance:
                                                                    isMaint,
                                                                compact: true,
                                                              )
                                                            : Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .grey
                                                                      .withValues(
                                                                        alpha:
                                                                            0.15,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .grey
                                                                        .withValues(
                                                                          alpha:
                                                                              0.4,
                                                                        ),
                                                                  ),
                                                                ),
                                                                child: const Text(
                                                                  'Not Monitored',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                                ),
                                                              )),
                                                ),
                                                DataCell(
                                                  Switch(
                                                    value: device.isEnabled,
                                                    onChanged: isAdmin
                                                        ? (val) {
                                                            context
                                                                .read<
                                                                  DevicesCubit
                                                                >()
                                                                .toggleMonitoring(
                                                                  device.id,
                                                                  val,
                                                                );
                                                          }
                                                        : null,
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.info_outline,
                                                          size: 18,
                                                        ),
                                                        tooltip: 'Details',
                                                        onPressed: () =>
                                                            _showDeviceDetailsDialog(
                                                              context,
                                                              device,
                                                            ),
                                                      ),
                                                      if (isAdmin) ...[
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.edit_outlined,
                                                            size: 18,
                                                          ),
                                                          tooltip:
                                                              'Edit Device',
                                                          onPressed: () =>
                                                              _showEditDeviceDialog(
                                                                context,
                                                                device,
                                                              ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            size: 18,
                                                            color: Colors
                                                                .redAccent,
                                                          ),
                                                          tooltip:
                                                              'Delete Asset',
                                                          onPressed: () =>
                                                              _showDeleteDeviceDialog(
                                                                context,
                                                                device,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),

              // Tab 2: Network Infrastructure & UniFi APs
              const SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: InfrastructureDevicesTable(showHeaderActions: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
