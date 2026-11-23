import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/factory_cubit.dart';

class AddFactoryDialog extends StatefulWidget {
  const AddFactoryDialog({super.key});

  @override
  State<AddFactoryDialog> createState() => _AddFactoryDialogState();
}

class _AddFactoryDialogState extends State<AddFactoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _gatewayController = TextEditingController();
  final _subnetController = TextEditingController(text: '255.255.255.0');
  final _cidrController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _gatewayController.addListener(_recalculateCidr);
    _subnetController.addListener(_recalculateCidr);
  }

  void _recalculateCidr() {
    final gateway = _gatewayController.text.trim();
    final mask = _subnetController.text.trim();
    if (gateway.isEmpty) return;

    final gParts = gateway.split('.').map(int.tryParse).toList();
    final mParts = mask.split('.').map(int.tryParse).toList();
    if (gParts.length == 4 &&
        mParts.length == 4 &&
        !gParts.contains(null) &&
        !mParts.contains(null)) {
      final baseOctets = <int>[];
      int prefix = 0;
      for (int i = 0; i < 4; i++) {
        baseOctets.add(gParts[i]! & mParts[i]!);
        final binary = mParts[i]!.toRadixString(2).padLeft(8, '0');
        prefix += binary.split('').where((b) => b == '1').length;
      }
      _cidrController.text = '${baseOctets.join(".")}/$prefix';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _gatewayController.dispose();
    _subnetController.dispose();
    _cidrController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final cubit = context.read<FactoryCubit>();
    final success = await cubit.addFactory(
      code: _codeController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      gatewayIp: _gatewayController.text.trim().isEmpty
          ? null
          : _gatewayController.text.trim(),
      subnetMask: _subnetController.text.trim().isEmpty
          ? null
          : _subnetController.text.trim(),
      expectedCidr: _cidrController.text.trim().isEmpty
          ? null
          : _cidrController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Factory ${_codeController.text.trim().toUpperCase()} added successfully.',
          ),
          backgroundColor: context.appTokens.statusOnline,
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage =
            cubit.state.errorMessage ?? 'Failed to create new factory.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.factory_rounded, color: tokens.primary),
          const SizedBox(width: 10),
          const Text('Add New Factory / Site'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure a new independently managed factory with isolated network scopes and device inventory.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.statusOfflineSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: tokens.statusOffline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: tokens.statusOffline,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: tokens.statusOffline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Factory Code *',
                  hintText: 'e.g. BNF, RNF, MNF',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                validator: (val) {
                  final text = val?.trim().toUpperCase() ?? '';
                  if (text.isEmpty) return 'Factory code is required';
                  if (text.length < 2 || text.length > 10) {
                    return 'Code must be between 2 and 10 characters';
                  }
                  if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(text)) {
                    return 'Letters, numbers, and dashes only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Factory Display Name *',
                  hintText: 'e.g. Beni Suef Factory, Sadat City Factory',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) return 'Display name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Factory Network Scope Configuration',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tokens.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gatewayController,
                      decoration: const InputDecoration(
                        labelText: 'Gateway IP',
                        hintText: 'e.g. 192.168.22.1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.router_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _subnetController,
                      decoration: const InputDecoration(
                        labelText: 'Subnet Mask',
                        hintText: 'e.g. 255.255.255.0',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.grid_3x3_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cidrController,
                decoration: const InputDecoration(
                  labelText: 'Expected Network Scope (CIDR)',
                  hintText: 'e.g. 192.168.22.0/24',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lan_rounded),
                  helperText:
                      'Auto-calculated from Gateway & Mask or enter custom CIDR',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.primary,
            foregroundColor: tokens.onPrimary,
          ),
          child: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.onPrimary,
                  ),
                )
              : const Text('Create Factory'),
        ),
      ],
    );
  }
}
