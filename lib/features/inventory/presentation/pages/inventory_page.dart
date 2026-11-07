import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/ipv4_utils.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/presentation/bloc/devices_cubit.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../domain/services/excel_inventory_service.dart';
import '../widgets/excel_import_preview_dialog.dart';
import 'unassigned_recovery_page.dart';

class InventoryPage extends StatefulWidget {
  final String? initialFactoryId;

  const InventoryPage({super.key, this.initialFactoryId});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final Set<int> _selectedIds = {};
  String _searchQuery = '';
  String _sortByColumn = 'id';
  bool _sortAscending = true;
  String _selectedDeptFilter = 'All';
  String _selectedTypeFilter = 'All';

  // Inline editing state: rowId -> editing values
  final Map<int, Map<String, dynamic>> _editingRows = {};
  final Map<int, String?> _rowErrors = {};
  bool _isShowingUnassignedRecovery = false;

  ExcelInventoryService get _excelService =>
      getIt.isRegistered<ExcelInventoryService>()
      ? getIt<ExcelInventoryService>()
      : ExcelInventoryServiceImpl();

  @override
  void initState() {
    super.initState();
    final factoryCubit = context.read<FactoryCubit>();
    if (widget.initialFactoryId != null) {
      factoryCubit.selectFactoryById(widget.initialFactoryId);
    }
    final activeId = factoryCubit.state.selectedFactoryId;
    context.read<DevicesCubit>().setFactory(activeId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFactoryTabChanged(String? factoryId) {
    setState(() {
      _selectedIds.clear();
      _editingRows.clear();
      _rowErrors.clear();
      _isShowingUnassignedRecovery = false;
    });
    context.read<FactoryCubit>().selectFactoryById(factoryId);
    context.read<DevicesCubit>().setFactory(factoryId);
  }

  void _sort(String column) {
    setState(() {
      if (_sortByColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortByColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<DeviceEntity> _sortAndFilter(List<DeviceEntity> devices) {
    var list = devices.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.name.toLowerCase().contains(q) ||
          d.ip.toLowerCase().contains(q) ||
          d.ownerName.toLowerCase().contains(q) ||
          d.department.toLowerCase().contains(q) ||
          (d.hostname?.toLowerCase().contains(q) ?? false) ||
          (d.mac?.toLowerCase().contains(q) ?? false) ||
          (d.vendor?.toLowerCase().contains(q) ?? false) ||
          (d.model?.toLowerCase().contains(q) ?? false) ||
          (d.officeLocation?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (_selectedDeptFilter != 'All') {
      list = list
          .where(
            (d) =>
                d.department.toLowerCase() == _selectedDeptFilter.toLowerCase(),
          )
          .toList();
    }

    if (_selectedTypeFilter != 'All') {
      list = list
          .where(
            (d) =>
                d.type.displayName.toLowerCase() ==
                _selectedTypeFilter.toLowerCase(),
          )
          .toList();
    }

    list.sort((a, b) {
      int cmp = 0;
      switch (_sortByColumn) {
        case 'id':
          cmp = a.id.compareTo(b.id);
          break;
        case 'name':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'ip':
          cmp = a.ip.compareTo(b.ip);
          break;
        case 'owner':
          cmp = a.ownerName.toLowerCase().compareTo(b.ownerName.toLowerCase());
          break;
        case 'dept':
          cmp = a.department.toLowerCase().compareTo(
            b.department.toLowerCase(),
          );
          break;
        case 'type':
          cmp = a.type.displayName.compareTo(b.type.displayName);
          break;
        case 'location':
          cmp = (a.officeLocation ?? '').compareTo(b.officeLocation ?? '');
          break;
        default:
          cmp = a.id.compareTo(b.id);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  Future<void> _saveEditedRow(
    DeviceEntity original,
    Map<String, dynamic> edits,
  ) async {
    final rawName = (edits['name'] as String? ?? original.name).trim();
    final rawIp = (edits['ip'] as String? ?? original.ip).trim();
    final rawOwner = (edits['ownerName'] as String? ?? original.ownerName)
        .trim();
    final rawDept = (edits['department'] as String? ?? original.department)
        .trim();

    if (rawName.isEmpty) {
      setState(() => _rowErrors[original.id] = 'Device Name is required.');
      return;
    }
    if (rawOwner.isEmpty) {
      setState(() => _rowErrors[original.id] = 'Owner Name is required.');
      return;
    }
    if (rawDept.isEmpty) {
      setState(() => _rowErrors[original.id] = 'Department is required.');
      return;
    }

    final canonIp = Ipv4Utils.canonicalizeIpv4(rawIp);
    if (canonIp == null) {
      setState(
        () => _rowErrors[original.id] = 'Invalid IPv4 address: "$rawIp".',
      );
      return;
    }

    // Duplicate IP check within same factory
    final currentDevices =
        (context.read<DevicesCubit>().state as DevicesLoaded).allDevices;
    final conflict = currentDevices
        .where(
          (d) =>
              d.id != original.id &&
              d.factoryId.toLowerCase() == original.factoryId.toLowerCase() &&
              Ipv4Utils.canonicalizeIpv4(d.ip) == canonIp,
        )
        .firstOrNull;

    if (conflict != null) {
      setState(
        () => _rowErrors[original.id] =
            'Duplicate IP $canonIp already assigned to "${conflict.name}" in this factory.',
      );
      return;
    }

    final updated = original.copyWith(
      name: rawName,
      ip: canonIp,
      ownerName: rawOwner,
      department: rawDept,
      officeLocation: edits.containsKey('officeLocation')
          ? (edits['officeLocation'] as String?)?.trim()
          : original.officeLocation,
      type: edits.containsKey('type')
          ? edits['type'] as DeviceType
          : original.type,
      mac: edits.containsKey('mac')
          ? (edits['mac'] as String?)?.trim()
          : original.mac,
      hostname: edits.containsKey('hostname')
          ? (edits['hostname'] as String?)?.trim()
          : original.hostname,
      vendor: edits.containsKey('vendor')
          ? (edits['vendor'] as String?)?.trim()
          : original.vendor,
      model: edits.containsKey('model')
          ? (edits['model'] as String?)?.trim()
          : original.model,
      operatingSystem: edits.containsKey('operatingSystem')
          ? (edits['operatingSystem'] as String?)?.trim()
          : original.operatingSystem,
      parentSwitchName: edits.containsKey('parentSwitchName')
          ? (edits['parentSwitchName'] as String?)?.trim()
          : original.parentSwitchName,
      isMonitored: edits.containsKey('isMonitored')
          ? edits['isMonitored'] as bool
          : original.isMonitored,
      isEnabled: edits.containsKey('isEnabled')
          ? edits['isEnabled'] as bool
          : original.isEnabled,
      notes: edits.containsKey('notes')
          ? (edits['notes'] as String?)?.trim()
          : original.notes,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _rowErrors.remove(original.id);
      _editingRows.remove(original.id);
    });

    await context.read<DevicesCubit>().updateDevice(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${updated.name}" successfully.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddNewRowDialog(String activeFactoryId) {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final macCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DeviceType selectedType = DeviceType.pc;
    bool isMonitored = true;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.playlist_add_rounded, color: Color(0xFF0F62FE)),
              const SizedBox(width: 8),
              Text('Add New Device Row (${activeFactoryId.toUpperCase()})'),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Device Name *',
                            hintText: 'e.g. PC-ENG-05',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ipCtrl,
                          decoration: const InputDecoration(
                            labelText: 'IP Address *',
                            hintText: 'e.g. 192.168.22.85',
                            border: OutlineInputBorder(),
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
                          controller: ownerCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Owner / User Name *',
                            hintText: 'e.g. Tamer Nabil',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: deptCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Department *',
                            hintText: 'e.g. Maintenance',
                            border: OutlineInputBorder(),
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
                            labelText: 'Device Type',
                            border: OutlineInputBorder(),
                          ),
                          items: DeviceType.values.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: locCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Office Location',
                            hintText: 'e.g. Factory Floor #2',
                            border: OutlineInputBorder(),
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
                          controller: macCtrl,
                          decoration: const InputDecoration(
                            labelText: 'MAC Address',
                            hintText: '00:1B:44:11:3A:B7',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hostCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Hostname',
                            hintText: 'PC-ENG-05.corp',
                            border: OutlineInputBorder(),
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
                          controller: vendorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vendor',
                            hintText: 'Dell, HP, Lenovo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: modelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText: 'OptiPlex 7090',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional asset notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Automated ICMP Monitoring'),
                    value: isMonitored,
                    onChanged: (val) => setDialogState(() => isMonitored = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F62FE),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final ip = ipCtrl.text.trim();
                final owner = ownerCtrl.text.trim();
                final dept = deptCtrl.text.trim();

                if (name.isEmpty ||
                    ip.isEmpty ||
                    owner.isEmpty ||
                    dept.isEmpty) {
                  setDialogState(
                    () => dialogError =
                        'Name, IP, Owner, and Department are required.',
                  );
                  return;
                }

                final canonIp = Ipv4Utils.canonicalizeIpv4(ip);
                if (canonIp == null) {
                  setDialogState(
                    () => dialogError = 'Invalid IPv4 address format: "$ip".',
                  );
                  return;
                }

                final currentDevices =
                    (context.read<DevicesCubit>().state as DevicesLoaded)
                        .allDevices;
                final conflict = currentDevices
                    .where(
                      (d) =>
                          d.factoryId.toLowerCase() ==
                              activeFactoryId.toLowerCase() &&
                          Ipv4Utils.canonicalizeIpv4(d.ip) == canonIp,
                    )
                    .firstOrNull;

                if (conflict != null) {
                  setDialogState(
                    () => dialogError =
                        'Duplicate IP $canonIp already exists in this factory (${conflict.name}).',
                  );
                  return;
                }

                Navigator.of(dialogCtx).pop();

                final newDevice = DeviceEntity(
                  id: 0,
                  factoryId: activeFactoryId,
                  name: name,
                  type: selectedType,
                  ip: canonIp,
                  ownerName: owner,
                  department: dept,
                  officeLocation: locCtrl.text.trim().isEmpty
                      ? null
                      : locCtrl.text.trim(),
                  vendor: vendorCtrl.text.trim().isEmpty
                      ? null
                      : vendorCtrl.text.trim(),
                  model: modelCtrl.text.trim().isEmpty
                      ? null
                      : modelCtrl.text.trim(),
                  mac: macCtrl.text.trim().isEmpty ? null : macCtrl.text.trim(),
                  hostname: hostCtrl.text.trim().isEmpty
                      ? null
                      : hostCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  isMonitored: isMonitored,
                  isEnabled: true,
                  createdAt: DateTime.now(),
                );

                await context.read<DevicesCubit>().addDevice(newDevice);
              },
              child: const Text('Add Row'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(List<DeviceEntity> devicesToDelete) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Delete ${devicesToDelete.length} Device(s)?'),
          ],
        ),
        content: Text(
          devicesToDelete.length == 1
              ? 'Are you sure you want to permanently delete "${devicesToDelete.first.name}" (${devicesToDelete.first.ip}) from the inventory?'
              : 'Are you sure you want to delete ${devicesToDelete.length} selected devices from this factory inventory? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final cubit = context.read<DevicesCubit>();
              if (devicesToDelete.length == 1) {
                await cubit.deleteDevice(devicesToDelete.first.id);
              } else {
                await cubit.deleteDevices(
                  devicesToDelete.map((d) => d.id).toList(),
                );
              }
              setState(() {
                for (final d in devicesToDelete) {
                  _selectedIds.remove(d.id);
                }
              });
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showBulkEditDialog(List<DeviceEntity> selectedDevices) {
    String? newDept;
    String? newLoc;
    String? newVendor;
    DeviceType? newType;
    bool? newMonitored;

    final deptCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF0F62FE)),
              const SizedBox(width: 8),
              Text('Bulk Edit ${selectedDevices.length} Devices'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Only fields with entered values will be updated across all selected records. Leave blank to keep existing values.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: deptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Department',
                    hintText: 'Leave empty to keep existing',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      newDept = val.trim().isNotEmpty ? val.trim() : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Office Location',
                    hintText: 'Leave empty to keep existing',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      newLoc = val.trim().isNotEmpty ? val.trim() : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vendorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Vendor',
                    hintText: 'Leave empty to keep existing',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) =>
                      newVendor = val.trim().isNotEmpty ? val.trim() : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DeviceType?>(
                  decoration: const InputDecoration(
                    labelText: 'Change Device Type',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: newType,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Keep existing types'),
                    ),
                    ...DeviceType.values.map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => newType = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<bool?>(
                  decoration: const InputDecoration(
                    labelText: 'Change Monitoring State',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: newMonitored,
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Keep existing monitoring status'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Enable Monitoring'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Disable Monitoring'),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => newMonitored = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F62FE),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await context.read<DevicesCubit>().bulkUpdateDevices(
                  deviceIds: selectedDevices.map((d) => d.id).toList(),
                  department: newDept,
                  officeLocation: newLoc,
                  vendor: newVendor,
                  type: newType,
                  isMonitored: newMonitored,
                );
              },
              child: const Text('Apply Bulk Updates'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel(
    List<DeviceEntity> devices,
    String factoryCode,
  ) async {
    final excelService = _excelService;
    final bytes = excelService.exportToExcel(
      devices: devices,
      factoryCode: factoryCode,
    );

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${factoryCode.toUpperCase()}_Inventory_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${devices.length} records to "${file.path}".',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _downloadTemplate(String factoryCode) async {
    final excelService = _excelService;
    final bytes = excelService.generateTemplate(factoryCode: factoryCode);

    final dir = await getApplicationDocumentsDirectory();
    final filename = '${factoryCode.toUpperCase()}_Inventory_Template.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded Excel Template to "${file.path}".'),
          backgroundColor: const Color(0xFF0F62FE),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _importExcel(String targetFactoryId, String factoryCode) async {
    final files = await FilePickerPlatform.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );

    if (files.isEmpty || files.first.path == null) {
      return;
    }

    final bytes = await File(files.first.path!).readAsBytes();
    if (!mounted) return;

    final excelService = _excelService;
    final currentDevices =
        (context.read<DevicesCubit>().state as DevicesLoaded).allDevices;

    final summary = excelService.parseAndValidateFile(
      bytes: bytes,
      fileName: files.first.name,
      targetFactoryId: targetFactoryId,
      existingFactoryDevices: currentDevices,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => ExcelImportPreviewDialog(
        summary: summary,
        factoryCode: factoryCode,
        onConfirm: () async {
          final cubit = context.read<DevicesCubit>();
          await cubit.confirmImportPayload(summary.toCommitPayload());
        },
      ),
    );
  }

  Future<void> _copySelectedToClipboard(
    List<DeviceEntity> selectedDevices,
  ) async {
    final excelService = _excelService;
    final tsv = excelService.exportToTsv(selectedDevices);
    await Clipboard.setData(ClipboardData(text: tsv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${selectedDevices.length} tabular rows to clipboard (Excel paste ready).',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard(
    String targetFactoryId,
    String factoryCode,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard is empty. Copy tabular rows from Excel first.',
          ),
        ),
      );
      return;
    }

    final excelService = _excelService;
    final currentDevices =
        (context.read<DevicesCubit>().state as DevicesLoaded).allDevices;

    final summary = excelService.parseTabularTsv(
      tsvText: text,
      targetFactoryId: targetFactoryId,
      existingFactoryDevices: currentDevices,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => ExcelImportPreviewDialog(
        summary: summary,
        factoryCode: factoryCode,
        onConfirm: () async {
          final cubit = context.read<DevicesCubit>();
          await cubit.confirmImportPayload(summary.toCommitPayload());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factoryState = context.watch<FactoryCubit>().state;
    final activeFactory = factoryState.selectedFactory;
    final activeFactoryId = activeFactory?.id ?? 'all';
    final activeFactoryCode = activeFactory?.code ?? 'ALL';
    final isConsolidated = activeFactory == null;

    final isAdmin = true;

    final factories = factoryState.factories
        .where((f) => f.id != 'unassigned' && f.isActive)
        .toList();

    if (_isShowingUnassignedRecovery) {
      return UnassignedRecoveryPage(
        onBackToInventory: () {
          setState(() => _isShowingUnassignedRecovery = false);
          _onFactoryTabChanged(factoryState.selectedFactoryId);
        },
      );
    }

    return BlocListener<FactoryCubit, FactoryState>(
      listener: (context, fState) {
        context.read<DevicesCubit>().setFactory(fState.selectedFactoryId);
        setState(() {
          _selectedIds.clear();
          _editingRows.clear();
          _rowErrors.clear();
        });
      },
      child: Scaffold(
        body: BlocConsumer<DevicesCubit, DevicesState>(
          listener: (context, state) {
            if (state is DevicesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            final List<DeviceEntity> allDevices;
            if (state is DevicesLoaded) {
              allDevices = state.allDevices;
            } else {
              allDevices = [];
            }

            final displayDevices = _sortAndFilter(allDevices);
            final selectedDevices = allDevices
                .where((d) => _selectedIds.contains(d.id))
                .toList();

            final depts = {
              'All',
              ...allDevices
                  .map((d) => d.department.trim())
                  .where((d) => d.isNotEmpty),
            }.toList();
            final types = {
              'All',
              ...allDevices.map((d) => d.type.displayName),
            }.toList();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Factory Switcher Tabs
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tabs = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final f in factories)
                            _FactoryTabButton(
                              code: f.code,
                              name: f.name,
                              isSelected: activeFactoryId == f.id,
                              onTap: () => _onFactoryTabChanged(f.id),
                            ),
                          _FactoryTabButton(
                            code: 'ALL',
                            name: 'All Factories (Consolidated)',
                            isSelected: isConsolidated,
                            onTap: () => _onFactoryTabChanged(null),
                          ),
                        ],
                      );

                      final recoveryButton = OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber,
                          side: const BorderSide(color: Colors.amber),
                        ),
                        onPressed: () =>
                            setState(() => _isShowingUnassignedRecovery = true),
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('Legacy Unassigned Recovery'),
                      );

                      final isCompact = constraints.maxWidth < 840;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tabs,
                            const SizedBox(height: 8),
                            recoveryButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: tabs),
                          recoveryButton,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Main Toolbar
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Search box
                          SizedBox(
                            width: 220,
                            height: 36,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search $activeFactoryCode devices...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 16,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val.trim()),
                            ),
                          ),

                          // Dept Filter
                          DropdownButton<String>(
                            value: depts.contains(_selectedDeptFilter)
                                ? _selectedDeptFilter
                                : 'All',
                            underline: const SizedBox.shrink(),
                            items: depts
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text('Dept: $d'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDeptFilter = val);
                              }
                            },
                          ),

                          // Type Filter
                          DropdownButton<String>(
                            value: types.contains(_selectedTypeFilter)
                                ? _selectedTypeFilter
                                : 'All',
                            underline: const SizedBox.shrink(),
                            items: types
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text('Type: $t'),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedTypeFilter = val);
                              }
                            },
                          ),

                          const SizedBox(width: 8),

                          // Add Row (only in single factory mode, not consolidated)
                          if (!isConsolidated)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F62FE),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  _showAddNewRowDialog(activeFactoryId),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Row'),
                            ),

                          // Delete Selected
                          if (_selectedIds.isNotEmpty && isAdmin)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  _showDeleteConfirmation(selectedDevices),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: Text('Delete (${_selectedIds.length})'),
                            ),

                          // Bulk Edit Selected
                          if (_selectedIds.isNotEmpty &&
                              isAdmin &&
                              !isConsolidated)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  _showBulkEditDialog(selectedDevices),
                              icon: const Icon(Icons.edit_note, size: 16),
                              label: Text('Bulk Edit (${_selectedIds.length})'),
                            ),

                          // Copy to Clipboard (TSV)
                          if (_selectedIds.isNotEmpty)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  _copySelectedToClipboard(selectedDevices),
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              label: Text('Copy (${_selectedIds.length})'),
                            ),

                          // Paste from Clipboard (TSV)
                          if (!isConsolidated && isAdmin)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _pasteFromClipboard(
                                activeFactoryId,
                                activeFactoryCode,
                              ),
                              icon: const Icon(Icons.paste_rounded, size: 15),
                              label: const Text('Paste Excel'),
                            ),

                          // Import XLSX
                          if (!isConsolidated && isAdmin)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _importExcel(
                                activeFactoryId,
                                activeFactoryCode,
                              ),
                              icon: const Icon(
                                Icons.file_upload_outlined,
                                size: 16,
                              ),
                              label: const Text('Import XLSX'),
                            ),

                          // Export XLSX
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: displayDevices.isEmpty
                                ? null
                                : () => _exportExcel(
                                    displayDevices,
                                    activeFactoryCode,
                                  ),
                            icon: const Icon(
                              Icons.file_download_outlined,
                              size: 16,
                            ),
                            label: const Text('Export XLSX'),
                          ),

                          // Download Template
                          if (!isConsolidated)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  _downloadTemplate(activeFactoryCode),
                              icon: const Icon(
                                Icons.description_outlined,
                                size: 15,
                              ),
                              label: const Text('Template'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Device Count Info Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text(
                          'Showing ${displayDevices.length} of ${allDevices.length} records in $activeFactoryCode Inventory',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        if (isConsolidated) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CONSOLIDATED READ-ONLY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (_selectedIds.isNotEmpty)
                          Text(
                            '${_selectedIds.length} row(s) selected',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F62FE),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Data Grid
                  Expanded(
                    child: state is DevicesLoading
                        ? const Center(child: CircularProgressIndicator())
                        : displayDevices.isEmpty
                        ? Center(
                            child: Text(
                              allDevices.isEmpty
                                  ? 'No devices registered in $activeFactoryCode yet. Click "+ Add Row" or "Import XLSX".'
                                  : 'No devices match your filter criteria.',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowHeight: 40,
                                  dataRowMinHeight: 38,
                                  dataRowMaxHeight: 52,
                                  horizontalMargin: 12,
                                  columnSpacing: 16,
                                  showCheckboxColumn: false,
                                  columns: [
                                    // Checkbox Select
                                    DataColumn(
                                      label: Checkbox(
                                        value:
                                            _selectedIds.length ==
                                                displayDevices.length &&
                                            displayDevices.isNotEmpty,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedIds.addAll(
                                                displayDevices.map((d) => d.id),
                                              );
                                            } else {
                                              _selectedIds.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    DataColumn(
                                      label: const Text('ID'),
                                      onSort: (idx, asc) => _sort('id'),
                                    ),
                                    DataColumn(
                                      label: const Text('Device Name *'),
                                      onSort: (idx, asc) => _sort('name'),
                                    ),
                                    DataColumn(
                                      label: const Text('IP Address *'),
                                      onSort: (idx, asc) => _sort('ip'),
                                    ),
                                    DataColumn(
                                      label: const Text('Owner Name *'),
                                      onSort: (idx, asc) => _sort('owner'),
                                    ),
                                    DataColumn(
                                      label: const Text('Department *'),
                                      onSort: (idx, asc) => _sort('dept'),
                                    ),
                                    DataColumn(
                                      label: const Text('Device Type'),
                                      onSort: (idx, asc) => _sort('type'),
                                    ),
                                    DataColumn(
                                      label: const Text('Location'),
                                      onSort: (idx, asc) => _sort('location'),
                                    ),
                                    const DataColumn(
                                      label: Text('MAC Address'),
                                    ),
                                    const DataColumn(label: Text('Hostname')),
                                    const DataColumn(label: Text('Vendor')),
                                    const DataColumn(label: Text('Model')),
                                    const DataColumn(label: Text('OS')),
                                    const DataColumn(
                                      label: Text('Parent Switch'),
                                    ),
                                    const DataColumn(label: Text('Monitored')),
                                    const DataColumn(label: Text('Enabled')),
                                    const DataColumn(label: Text('Notes')),
                                    const DataColumn(label: Text('Actions')),
                                  ],
                                  rows: displayDevices.map((d) {
                                    final isSelected = _selectedIds.contains(
                                      d.id,
                                    );
                                    final isEditing = _editingRows.containsKey(
                                      d.id,
                                    );
                                    final edits = _editingRows[d.id] ?? {};
                                    final error = _rowErrors[d.id];

                                    return DataRow(
                                      selected: isSelected,
                                      color:
                                          WidgetStateProperty.resolveWith<
                                            Color?
                                          >((states) {
                                            if (error != null) {
                                              return Colors.red.withValues(
                                                alpha: 0.1,
                                              );
                                            }
                                            if (isSelected) {
                                              return theme.colorScheme.primary
                                                  .withValues(alpha: 0.1);
                                            }
                                            return null;
                                          }),
                                      cells: [
                                        // Checkbox
                                        DataCell(
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedIds.add(d.id);
                                                } else {
                                                  _selectedIds.remove(d.id);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        // ID
                                        DataCell(
                                          Text(
                                            '#${d.id}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Device Name
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['name'] as String? ??
                                                d.name,
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['name'] = val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['name'] = val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // IP Address
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['ip'] as String? ?? d.ip,
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            isMonospace: true,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['ip'] = val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['ip'] = val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Owner Name
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['ownerName'] as String? ??
                                                d.ownerName,
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['ownerName'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['ownerName'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Department
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['department']
                                                    as String? ??
                                                d.department,
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['department'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['department'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Device Type
                                        DataCell(
                                          isConsolidated || !isAdmin
                                              ? Text(d.type.displayName)
                                              : DropdownButtonHideUnderline(
                                                  child: DropdownButton<DeviceType>(
                                                    value:
                                                        edits['type']
                                                            as DeviceType? ??
                                                        d.type,
                                                    isDense: true,
                                                    items: DeviceType.values.map(
                                                      (t) {
                                                        return DropdownMenuItem(
                                                          value: t,
                                                          child: Text(
                                                            t.displayName,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ).toList(),
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        _editingRows[d.id] ??=
                                                            {};
                                                        _editingRows[d
                                                                .id]!['type'] =
                                                            val;
                                                        _saveEditedRow(
                                                          d,
                                                          _editingRows[d.id]!,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                        ),

                                        // Office Location
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['officeLocation']
                                                    as String? ??
                                                (d.officeLocation ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['officeLocation'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['officeLocation'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // MAC Address
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['mac'] as String? ??
                                                (d.mac ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            isMonospace: true,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['mac'] = val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['mac'] = val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Hostname
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['hostname'] as String? ??
                                                (d.hostname ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['hostname'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['hostname'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Vendor
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['vendor'] as String? ??
                                                (d.vendor ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['vendor'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['vendor'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Model
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['model'] as String? ??
                                                (d.model ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['model'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['model'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // OS
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['operatingSystem']
                                                    as String? ??
                                                (d.operatingSystem ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['operatingSystem'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['operatingSystem'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Parent Switch
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['parentSwitchName']
                                                    as String? ??
                                                (d.parentSwitchName ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['parentSwitchName'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d
                                                      .id]!['parentSwitchName'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Monitored Toggle
                                        DataCell(
                                          Switch(
                                            value:
                                                edits['isMonitored'] as bool? ??
                                                d.isMonitored,
                                            onChanged:
                                                isConsolidated || !isAdmin
                                                ? null
                                                : (val) {
                                                    _editingRows[d.id] ??= {};
                                                    _editingRows[d
                                                            .id]!['isMonitored'] =
                                                        val;
                                                    _saveEditedRow(
                                                      d,
                                                      _editingRows[d.id]!,
                                                    );
                                                  },
                                          ),
                                        ),

                                        // Enabled Toggle
                                        DataCell(
                                          Switch(
                                            value:
                                                edits['isEnabled'] as bool? ??
                                                d.isEnabled,
                                            onChanged:
                                                isConsolidated || !isAdmin
                                                ? null
                                                : (val) {
                                                    _editingRows[d.id] ??= {};
                                                    _editingRows[d
                                                            .id]!['isEnabled'] =
                                                        val;
                                                    _saveEditedRow(
                                                      d,
                                                      _editingRows[d.id]!,
                                                    );
                                                  },
                                          ),
                                        ),

                                        // Notes
                                        DataCell(
                                          _EditableTextCell(
                                            value:
                                                edits['notes'] as String? ??
                                                (d.notes ?? ''),
                                            isReadOnly:
                                                isConsolidated || !isAdmin,
                                            onChanged: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['notes'] =
                                                  val;
                                            },
                                            onSubmitted: (val) {
                                              _editingRows[d.id] ??= {};
                                              _editingRows[d.id]!['notes'] =
                                                  val;
                                              _saveEditedRow(
                                                d,
                                                _editingRows[d.id]!,
                                              );
                                            },
                                          ),
                                        ),

                                        // Actions
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isEditing)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.check,
                                                    color: Color(0xFF10B981),
                                                    size: 18,
                                                  ),
                                                  tooltip: 'Save edits',
                                                  onPressed: () =>
                                                      _saveEditedRow(d, edits),
                                                ),
                                              if (!isConsolidated && isAdmin)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                    size: 18,
                                                  ),
                                                  tooltip: 'Delete device',
                                                  onPressed: () =>
                                                      _showDeleteConfirmation([
                                                        d,
                                                      ]),
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FactoryTabButton extends StatelessWidget {
  final String code;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _FactoryTabButton({
    required this.code,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = code == 'RNF'
        ? const Color(0xFF0F62FE)
        : code == 'BNF'
        ? const Color(0xFF10B981)
        : const Color(0xFF8A3FFC);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableTextCell extends StatefulWidget {
  final String value;
  final bool isReadOnly;
  final bool isMonospace;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _EditableTextCell({
    required this.value,
    this.isReadOnly = false,
    this.isMonospace = false,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  State<_EditableTextCell> createState() => _EditableTextCellState();
}

class _EditableTextCellState extends State<_EditableTextCell> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
        if (_controller.text != widget.value) {
          widget.onSubmitted(_controller.text);
        }
      }
    });
  }

  @override
  void didUpdateWidget(_EditableTextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_isEditing) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isReadOnly) {
      return Text(
        widget.value.isEmpty ? '—' : widget.value,
        style: TextStyle(
          fontFamily: widget.isMonospace ? 'monospace' : null,
          color: widget.value.isEmpty ? Colors.grey : null,
        ),
      );
    }

    if (_isEditing) {
      return SizedBox(
        width: 140,
        height: 32,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          style: TextStyle(
            fontSize: 13,
            fontFamily: widget.isMonospace ? 'monospace' : null,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: widget.onChanged,
          onSubmitted: (val) {
            setState(() => _isEditing = false);
            widget.onSubmitted(val);
          },
        ),
      );
    }

    return InkWell(
      onDoubleTap: () => setState(() => _isEditing = true),
      onTap: () => setState(() => _isEditing = true),
      child: Tooltip(
        message: 'Click to edit',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.value.isEmpty ? '—' : widget.value,
              style: TextStyle(
                fontFamily: widget.isMonospace ? 'monospace' : null,
                color: widget.value.isEmpty ? Colors.grey : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 11,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
