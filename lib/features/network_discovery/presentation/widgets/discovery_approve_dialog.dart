import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';

class DiscoveryApproveDialog extends StatefulWidget {
  final DiscoveredDeviceEntity device;
  final Function({
    required DiscoveredDeviceEntity device,
    String? ownerName,
    String? department,
    String? deviceName,
    String? location,
    DeviceCategory? confirmedCategory,
    bool? isMonitored,
    String? vendor,
    String? model,
    String? notes,
  })
  onApprove;

  const DiscoveryApproveDialog({
    super.key,
    required this.device,
    required this.onApprove,
  });

  @override
  State<DiscoveryApproveDialog> createState() => _DiscoveryApproveDialogState();
}

class _DiscoveryApproveDialogState extends State<DiscoveryApproveDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ownerController;
  late TextEditingController _deptController;
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _vendorController;
  late TextEditingController _modelController;
  late TextEditingController _notesController;

  late DeviceCategory _selectedCategory;
  late bool _isMonitored;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.device.effectiveCategory;
    _isMonitored =
        _selectedCategory == DeviceCategory.pc ||
        _selectedCategory == DeviceCategory.laptop ||
        _selectedCategory == DeviceCategory.server;

    _ownerController = TextEditingController();
    _deptController = TextEditingController();

    final defaultPrefix = _selectedCategory == DeviceCategory.laptop
        ? 'Laptop'
        : _selectedCategory == DeviceCategory.server
        ? 'SRV'
        : _selectedCategory == DeviceCategory.printer
        ? 'PRN'
        : _selectedCategory == DeviceCategory.ipCamera
        ? 'CAM'
        : 'DEV';

    _nameController = TextEditingController(
      text:
          widget.device.hostname ??
          '$defaultPrefix-${widget.device.ip.replaceAll('.', '-')}',
    );
    _locationController = TextEditingController();
    _vendorController = TextEditingController(text: widget.device.vendor ?? '');
    _modelController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _deptController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _vendorController.dispose();
    _modelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: tokens.statusOnline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Save Asset to Persistent Inventory',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tokens.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: tokens.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Saving this asset persists it permanently in the authoritative inventory. It will appear on the Inventory screen, Dashboard, and survive scans and restarts.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Read-only observed evidence summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _ReviewRow('Discovered IP', widget.device.ip),
                      if (widget.device.mac != null &&
                          widget.device.mac!.isNotEmpty)
                        _ReviewRow('Observed MAC', widget.device.mac!),
                      if (widget.device.hostname != null &&
                          widget.device.hostname!.isNotEmpty)
                        _ReviewRow(
                          'Observed Hostname',
                          widget.device.hostname!,
                        ),
                      if (widget.device.vendor != null &&
                          widget.device.vendor!.isNotEmpty)
                        _ReviewRow('Identified Vendor', widget.device.vendor!),
                      _ReviewRow(
                        'Detected Category',
                        widget.device.predictedCategory.displayName,
                      ),
                      _ReviewRow(
                        'Classification Confidence',
                        widget.device.confidence.displayName,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Editable Fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Device Name *',
                          hintText: 'e.g. PC-RNF-021',
                          prefixIcon: Icon(Icons.devices),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Device Name is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<DeviceCategory>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Device Category *',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: DeviceCategory.values
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat.displayName,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _isMonitored =
                                  val == DeviceCategory.pc ||
                                  val == DeviceCategory.laptop ||
                                  val == DeviceCategory.server;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ownerController,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Owner / Person',
                          hintText: 'e.g. Ahmed Mostafa (or Unassigned)',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _deptController,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          hintText: 'e.g. Finance, IT, Operations',
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Office / Location',
                          hintText: 'e.g. Building A - Room 102',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Manufacturer / Vendor',
                          hintText: 'e.g. Dell, HP, Apple, Canon',
                          prefixIcon: Icon(Icons.factory),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model (Optional)',
                          hintText: 'e.g. OptiPlex 7090',
                          prefixIcon: Icon(Icons.memory),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Asset tags, maintenance notes...',
                          prefixIcon: Icon(Icons.note),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Monitoring Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable Continuous 24/7 Monitoring',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    _isMonitored
                        ? 'Device will receive regular ICMP health checks and trigger alerts if down.'
                        : 'Device will be kept in inventory as unmonitored asset (no false ping alerts).',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  value: _isMonitored,
                  onChanged: (val) => setState(() => _isMonitored = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              widget.onApprove(
                device: widget.device,
                ownerName: _ownerController.text.trim(),
                department: _deptController.text.trim(),
                deviceName: _nameController.text.trim(),
                location: _locationController.text.trim(),
                confirmedCategory: _selectedCategory,
                isMonitored: _isMonitored,
                vendor: _vendorController.text.trim(),
                model: _modelController.text.trim(),
                notes: _notesController.text.trim(),
              );
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.save),
          label: const Text('Save Asset to Inventory'),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appTokens.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
