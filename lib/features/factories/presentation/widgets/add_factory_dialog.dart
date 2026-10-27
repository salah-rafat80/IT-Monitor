import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
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
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Factory ${_codeController.text.trim().toUpperCase()} added successfully.',
          ),
          backgroundColor: const Color(0xFF10B981),
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

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.factory_rounded, color: Color(0xFF0F62FE)),
          SizedBox(width: 10),
          Text('Add New Factory / Site'),
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
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
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
                          _errorMessage!,
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
            backgroundColor: const Color(0xFF0F62FE),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create Factory'),
        ),
      ],
    );
  }
}
