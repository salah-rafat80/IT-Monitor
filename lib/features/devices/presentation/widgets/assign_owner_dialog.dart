import 'package:flutter/material.dart';

import '../../domain/entities/device_entity.dart';

class AssignOwnerDialog extends StatefulWidget {
  final DeviceEntity device;
  final Future<bool> Function(String newOwnerName) onSave;
  final Future<bool> Function()? onClear;

  const AssignOwnerDialog({
    super.key,
    required this.device,
    required this.onSave,
    this.onClear,
  });

  @override
  State<AssignOwnerDialog> createState() => _AssignOwnerDialogState();
}

class _AssignOwnerDialogState extends State<AssignOwnerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ownerController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(
      text: widget.device.isOwnerAssigned ? widget.device.ownerName : '',
    );
  }

  @override
  void dispose() {
    _ownerController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final success = await widget.onSave(_ownerController.text.trim());
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _handleClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_off_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm Clear Assignment'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the assigned person from device ${widget.device.name} (${widget.device.ip})? It will be marked as "Unassigned".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear Assignment'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onClear != null) {
      setState(() => _isSubmitting = true);
      final success = await widget.onClear!();
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.device.isOwnerAssigned;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F62FE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.manage_accounts_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: const Color(0xFF0F62FE),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Edit Assigned Person'
                              : 'Assign Person to Device',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Update authoritative inventory owner records.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Read-only Context Box (IP, Name, Department, Location)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    _ReadOnlyContextRow(
                      icon: Icons.lan_rounded,
                      label: 'Device IP Address (Immutable)',
                      value: widget.device.ip,
                      isMonospace: true,
                      isPrimaryBadge: true,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyContextRow(
                      icon: Icons.computer_rounded,
                      label: 'Device Name',
                      value: widget.device.name,
                    ),
                    const SizedBox(height: 10),
                    _ReadOnlyContextRow(
                      icon: Icons.business_rounded,
                      label: 'Department',
                      value: widget.device.department,
                    ),
                    if (widget.device.officeLocation != null &&
                        widget.device.officeLocation!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _ReadOnlyContextRow(
                        icon: Icons.location_on_outlined,
                        label: 'Office / Location',
                        value: widget.device.officeLocation!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form: Assigned Person's Name
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Person\'s Name *',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _ownerController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ahmed Mostafa',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        helperText:
                            'Manually maintained authoritative inventory owner.',
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Please enter the assigned person\'s name or use Clear Assignment.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dialog Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isEditing && widget.onClear != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                      icon: const Icon(Icons.person_off_rounded, size: 18),
                      label: const Text('Clear Assignment'),
                      onPressed: _isSubmitting ? null : _handleClear,
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          isEditing ? 'Save Changes' : 'Assign Person',
                        ),
                        onPressed: _isSubmitting ? null : _handleSave,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyContextRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isMonospace;
  final bool isPrimaryBadge;

  const _ReadOnlyContextRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.isPrimaryBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isPrimaryBadge ? const Color(0xFF0F62FE) : theme.disabledColor,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: isMonospace ? 'monospace' : null,
              color: isPrimaryBadge ? const Color(0xFF0F62FE) : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
