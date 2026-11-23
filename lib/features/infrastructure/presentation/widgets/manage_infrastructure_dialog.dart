import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/unifi_device_entity.dart';
import '../bloc/infrastructure_cubit.dart';

class ManageInfrastructureDialog extends StatefulWidget {
  final UniFiDeviceEntity? initialDevice;

  const ManageInfrastructureDialog({super.key, this.initialDevice});

  static Future<void> show(BuildContext context, {UniFiDeviceEntity? device}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ManageInfrastructureDialog(initialDevice: device),
    );
  }

  @override
  State<ManageInfrastructureDialog> createState() =>
      _ManageInfrastructureDialogState();
}

class _ManageInfrastructureDialogState
    extends State<ManageInfrastructureDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _locationController;
  late TextEditingController _subnetsController;
  late TextEditingController _controllerUrlController;

  late UniFiDeviceRole _selectedRole;
  late bool _isCritical;
  late bool _requiresConfirmation;
  late bool _isEnabled;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDevice;
    _nameController = TextEditingController(text: d?.name ?? '');
    _ipController = TextEditingController(text: d?.ip ?? '');
    _locationController = TextEditingController(text: d?.location ?? '');
    _subnetsController = TextEditingController(
      text: d?.linkedSubnets.join(', ') ?? '',
    );
    _controllerUrlController = TextEditingController(
      text: d?.controllerUrl ?? '',
    );

    _selectedRole = d?.role ?? UniFiDeviceRole.otherUnknown;
    _isCritical = d?.isCriticalInfrastructure ?? false;
    _requiresConfirmation =
        d?.requiresAdminConfirmation ?? (d == null ? true : false);
    _isEnabled = d?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _locationController.dispose();
    _subnetsController.dispose();
    _controllerUrlController.dispose();
    super.dispose();
  }

  bool _isValidIp(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final subnets = _subnetsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final entity = UniFiDeviceEntity(
      id: widget.initialDevice?.id ?? 0,
      name: _nameController.text.trim(),
      ip: _ipController.text.trim(),
      role: _selectedRole,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      isCriticalInfrastructure:
          _selectedRole == UniFiDeviceRole.gateway && _isCritical,
      requiresAdminConfirmation: _requiresConfirmation,
      linkedSubnets: subnets,
      controllerUrl: _controllerUrlController.text.trim().isNotEmpty
          ? _controllerUrlController.text.trim()
          : null,
      isEnabled: _isEnabled,
      isReadOnly: true,
      createdAt: widget.initialDevice?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await context.read<InfrastructureCubit>().saveDevice(
      entity,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.initialDevice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Infrastructure Device'),
        content: Text(
          'Are you sure you want to remove ${widget.initialDevice!.name} (${widget.initialDevice!.ip}) from monitored infrastructure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTokens.statusDown,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSaving = true);
      final success = await context.read<InfrastructureCubit>().deleteDevice(
        widget.initialDevice!.id,
      );
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final isEdit = widget.initialDevice != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.router,
                        color: tokens.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? 'Edit UniFi Infrastructure Asset'
                                : 'Add Critical UniFi Asset',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Authoritative management IP monitoring & read-only integration',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Read-only Policy Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tokens.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: tokens.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Strictly Read-Only: No write, provisioning, or configuration operations are performed on UniFi devices.',
                          style: TextStyle(
                            color: tokens.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form fields (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Device Name *',
                            hintText:
                                'e.g. UniFi Dream Machine Pro / USW-24-PoE',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Device name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'Management IP Address *',
                            hintText: 'e.g. 192.168.27.1 or 192.168.22.1',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Management IP is required';
                            }
                            if (!_isValidIp(val)) {
                              return 'Enter a valid IPv4 address (e.g. 192.168.22.1)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Physical Location / Area',
                            hintText:
                                'e.g. Factory Administration, Upper Area / Lower Area',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<UniFiDeviceRole>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Device Role *',
                            border: OutlineInputBorder(),
                          ),
                          items: UniFiDeviceRole.values
                              .where((role) =>
                                  role != UniFiDeviceRole.switchDevice)
                              .map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role.displayName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedRole = val;
                                if (_selectedRole != UniFiDeviceRole.gateway) {
                                  _isCritical = false;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),

                        if (_selectedRole == UniFiDeviceRole.gateway) ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Verified Core Gateway (Critical Infrastructure)',
                            ),
                            subtitle: const Text(
                              'When Down, raises a deduplicated Critical Incident and evaluates cross-segment routing impact.',
                            ),
                            value: _isCritical,
                            activeThumbColor: tokens.primary,
                            onChanged: (val) =>
                                setState(() => _isCritical = val),
                          ),
                          const SizedBox(height: 10),
                        ],

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Requires Admin Confirmation'),
                          subtitle: const Text(
                            'Keep checked if device role or downstream network dependencies are still unconfirmed.',
                          ),
                          value: _requiresConfirmation,
                          activeThumbColor: tokens.statusDegraded,
                          onChanged: (val) =>
                              setState(() => _requiresConfirmation = val),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _subnetsController,
                          decoration: const InputDecoration(
                            labelText:
                                'Linked Network Segments (optional, comma-separated)',
                            hintText: 'e.g. 192.168.22.0/24, 192.168.27.0/24',
                            border: OutlineInputBorder(),
                            helper: Text(
                              'Segments affected if this gateway or core switch is unreachable.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _controllerUrlController,
                          decoration: const InputDecoration(
                            labelText:
                                'UniFi Controller URL (optional read-only telemetry)',
                            hintText: 'e.g. https://192.168.22.1:8443',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active Monitoring Enabled'),
                          value: _isEnabled,
                          activeThumbColor: tokens.statusUp,
                          onChanged: (val) => setState(() => _isEnabled = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEdit)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.statusDown,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Delete'),
                        onPressed: _isSaving ? null : _handleDelete,
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: _isSaving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: tokens.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(
                            isEdit ? 'Save Changes' : 'Register Asset',
                          ),
                          onPressed: _isSaving ? null : _handleSave,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
