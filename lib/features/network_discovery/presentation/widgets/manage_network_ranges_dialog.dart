import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../domain/entities/network_range.dart';
import '../bloc/network_discovery_cubit.dart';
import '../bloc/network_discovery_state.dart';

/// Administrator dialog to centrally manage dynamic network ranges
class ManageNetworkRangesDialog extends StatefulWidget {
  final bool isAdmin;
  final String? factoryId;

  const ManageNetworkRangesDialog({
    super.key,
    required this.isAdmin,
    this.factoryId,
  });

  @override
  State<ManageNetworkRangesDialog> createState() =>
      _ManageNetworkRangesDialogState();
}

class _ManageNetworkRangesDialogState extends State<ManageNetworkRangesDialog> {
  final _cidrController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  String? _errorMessage;
  NetworkRange? _livePreviewRange;
  String? _selectedFactoryId;

  @override
  void initState() {
    super.initState();
    _selectedFactoryId = widget.factoryId;
    _cidrController.addListener(_updateLivePreview);
  }

  @override
  void dispose() {
    _cidrController.removeListener(_updateLivePreview);
    _cidrController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _updateLivePreview() {
    final text = _cidrController.text.trim();
    if (text.isEmpty) {
      if (_livePreviewRange != null) {
        setState(() => _livePreviewRange = null);
      }
      return;
    }
    final parsed = NetworkRange.tryParse(text);
    if (parsed != _livePreviewRange) {
      setState(() => _livePreviewRange = parsed);
    }
  }

  Future<void> _saveRange({bool launchDiscovery = false}) async {
    final factoryCubit = context.read<FactoryCubit>();
    final effectiveFactoryId =
        _selectedFactoryId ??
        widget.factoryId ??
        factoryCubit.state.selectedFactoryId;

    if (effectiveFactoryId == null ||
        effectiveFactoryId.trim().isEmpty ||
        effectiveFactoryId.toLowerCase() == 'unassigned') {
      setState(() {
        _errorMessage =
            'An explicit target factory must be selected before saving a network range. '
            'Please choose a factory above.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final cidr = _cidrController.text.trim();
    final name = _nameController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final cubit = context.read<NetworkDiscoveryCubit>();
    final res = await cubit.addNetworkRange(
      cidr: cidr,
      name: name.isNotEmpty ? name : null,
      isEnabled: true,
      factoryId: effectiveFactoryId,
    );

    if (!mounted) return;

    if (res.isFailure) {
      setState(() {
        _isSaving = false;
        _errorMessage =
            res.failureOrNull?.message ?? 'Failed to save network range';
      });
      return;
    }

    _cidrController.clear();
    _nameController.clear();
    setState(() {
      _isSaving = false;
      _livePreviewRange = null;
      _errorMessage = null;
    });

    if (launchDiscovery) {
      final parsed = NetworkRange.tryParse(cidr);
      final targetCidr = parsed?.cidr ?? cidr;
      Navigator.of(context).pop();
      await cubit.startScan(
        factoryId: effectiveFactoryId,
        requestedRanges: [targetCidr],
      );
    }
  }

  Future<void> _confirmDeleteRange(
    BuildContext context,
    NetworkDiscoveryCubit cubit,
    NetworkRange range,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ctx.appTokens.statusDegraded),
            const SizedBox(width: 8),
            const Text('Remove Network Range'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${range.cidr}${range.name != null ? ' (${range.name})' : ''}?\n\n'
          'Existing device inventory, historical discovery scans, and reports will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.appTokens.statusOffline,
              foregroundColor: ctx.appTokens.onStatusOffline,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove Range'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await cubit.deleteNetworkRange(range.id);
      if (res.isFailure && mounted) {
        setState(() {
          _errorMessage = res.failureOrNull?.message;
        });
      }
    }
  }

  Future<void> _editRangeDialog(
    BuildContext context,
    NetworkDiscoveryCubit cubit,
    NetworkRange range,
  ) async {
    final editNameCtrl = TextEditingController(text: range.name ?? '');
    bool isEnabled = range.isEnabled;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Range: ${range.cidr}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: editNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descriptive Name (optional)',
                  hintText: 'e.g. Branch Office, DMZ, IoT VLAN',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled for Scans'),
                subtitle: Text(
                  isEnabled
                      ? 'Included in automated & manual scans'
                      : 'Excluded from new discovery scans',
                  style: const TextStyle(fontSize: 12),
                ),
                value: isEnabled,
                onChanged: (val) {
                  setDialogState(() => isEnabled = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = range.copyWith(
                  name: editNameCtrl.text.trim().isNotEmpty
                      ? editNameCtrl.text.trim()
                      : null,
                  isEnabled: isEnabled,
                  updatedAt: DateTime.now(),
                );
                await cubit.updateNetworkRange(updated);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocBuilder<NetworkDiscoveryCubit, NetworkDiscoveryState>(
            builder: (context, state) {
              final cubit = context.read<NetworkDiscoveryCubit>();
              final factoryCubit = context.watch<FactoryCubit>();
              final currentFactoryId =
                  _selectedFactoryId ??
                  widget.factoryId ??
                  factoryCubit.state.selectedFactoryId;
              final selectedFactory = factoryCubit.state.factories
                  .where((f) => f.id == currentFactoryId)
                  .firstOrNull;

              final rawRanges = state is NetworkDiscoveryLoaded
                  ? state.config.networkRanges
                  : <NetworkRange>[];
              final ranges = currentFactoryId != null
                  ? rawRanges
                        .where((r) => r.factoryId == currentFactoryId)
                        .toList()
                  : <NetworkRange>[];
              final isScanning =
                  state is NetworkDiscoveryLoaded && state.isScanning;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: tokens.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedFactory != null
                                  ? 'Manage Ranges: ${selectedFactory.code} (${selectedFactory.name})'
                                  : 'Manage Authorized Network Ranges (Select Factory)',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              selectedFactory != null
                                  ? 'Authoritative CIDR scopes isolated to ${selectedFactory.name}.'
                                  : 'Authoritative CIDR scopes for discovery, device reconciliation, and monitoring.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
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
                  const Divider(height: 24),

                  // Factory Selection Bar (when in Consolidated mode)
                  if (widget.factoryId == null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: currentFactoryId == null
                            ? tokens.statusDegradedSurface
                            : tokens.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: currentFactoryId == null
                              ? tokens.statusDegraded.withValues(alpha: 0.3)
                              : tokens.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.factory_rounded,
                            color: currentFactoryId == null
                                ? tokens.statusDegraded
                                : tokens.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Target Factory: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentFactoryId,
                                isDense: true,
                                hint: Text(
                                  'Select Factory to Manage Ranges (Required)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.statusDegraded,
                                  ),
                                ),
                                items: factoryCubit.state.factories
                                    .where((f) => f.isActive)
                                    .map(
                                      (f) => DropdownMenuItem(
                                        value: f.id,
                                        child: Text(
                                          '${f.name} (${f.code})',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedFactoryId = val;
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Error notification if present
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.statusOfflineSurface,
                        borderRadius: BorderRadius.circular(8),
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
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setState(() => _errorMessage = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Add Range Form (Admin Only)
                  if (widget.isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add New Network Scope',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _cidrController,
                                    decoration: const InputDecoration(
                                      labelText: 'IPv4 CIDR Notation *',
                                      hintText:
                                          'e.g. 10.10.20.0/24 or 192.168.1.0/24',
                                      isDense: true,
                                      prefixIcon: Icon(
                                        Icons.lan_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'CIDR is required';
                                      }
                                      final parsed = NetworkRange.tryParse(
                                        val.trim(),
                                      );
                                      if (parsed == null) {
                                        return 'Invalid CIDR format (/16 to /32 allowed)';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Scope Name (optional)',
                                      hintText: 'e.g. Headquarters LAN',
                                      isDense: true,
                                      prefixIcon: Icon(
                                        Icons.label_outline,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_livePreviewRange != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: tokens.statusOnline,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Normalized: ${_livePreviewRange!.cidr} (${_livePreviewRange!.usableHostsCount} usable hosts: ${_livePreviewRange!.baseIp.substring(0, _livePreviewRange!.baseIp.lastIndexOf('.'))}.1 – .${_livePreviewRange!.usableHostsCount})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.statusOnline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      (_isSaving || currentFactoryId == null)
                                      ? null
                                      : () =>
                                            _saveRange(launchDiscovery: false),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          size: 16,
                                        ),
                                  label: const Text('Save Scope'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tokens.primary,
                                    foregroundColor: tokens.onPrimary,
                                  ),
                                  onPressed:
                                      (_isSaving ||
                                          isScanning ||
                                          currentFactoryId == null)
                                      ? null
                                      : () => _saveRange(launchDiscovery: true),
                                  icon: const Icon(
                                    Icons.radar_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Save & Discover Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Range List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Configured Network Scopes (${ranges.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Total Usable: ${ranges.where((r) => r.isEnabled).fold<int>(0, (sum, r) => sum + r.usableHostsCount)} hosts',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Range List View
                  Expanded(
                    child: currentFactoryId == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.factory_outlined,
                                  size: 48,
                                  color: tokens.statusDegraded,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Factory Selection Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Please select a specific factory from the dropdown above to view, create, and manage its network ranges.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ranges.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.radar_outlined,
                                  size: 48,
                                  color: tokens.disabled,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Authorized Network Scopes Configured',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.isAdmin
                                      ? 'Add a CIDR range above to authorize network discovery and monitoring.'
                                      : 'An administrator must configure an authorized network scope before discovery can run.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: ranges.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final range = ranges[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: range.isEnabled
                                      ? theme.colorScheme.surface
                                      : theme.disabledColor.withValues(
                                          alpha: 0.05,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: range.isEnabled
                                        ? theme.dividerColor.withValues(
                                            alpha: 0.3,
                                          )
                                        : tokens.disabled.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      range.isEnabled
                                          ? Icons.lan_rounded
                                          : Icons.lan_outlined,
                                      color: range.isEnabled
                                          ? tokens.primary
                                          : tokens.disabled,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                range.cidr,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: range.isEnabled
                                                      ? null
                                                      : tokens.disabled,
                                                ),
                                              ),
                                              if (range.name != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '•  ${range.name}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color
                                                        ?.withValues(
                                                          alpha: 0.8,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: range.isEnabled
                                                      ? tokens.statusOnlineSurface
                                                      : tokens.disabled.withValues(
                                                          alpha: 0.15,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  range.isEnabled
                                                      ? 'Enabled'
                                                      : 'Disabled',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: range.isEnabled
                                                        ? tokens.statusOnline
                                                        : tokens.disabled,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${range.usableHostsCount} Usable Target Hosts (${range.baseIp.substring(0, range.baseIp.lastIndexOf('.'))}.1 – .${range.usableHostsCount})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.isAdmin) ...[
                                      // Discover Now for this specific range
                                      TextButton.icon(
                                        onPressed:
                                            (isScanning || !range.isEnabled)
                                            ? null
                                            : () async {
                                                Navigator.of(context).pop();
                                                await cubit.startScan(
                                                  factoryId: range.factoryId,
                                                  requestedRanges: [range.cidr],
                                                );
                                              },
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Discover Now',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      // Enable/Disable Switch
                                      Switch(
                                        value: range.isEnabled,
                                        onChanged: (val) {
                                          cubit.toggleRangeEnabled(
                                            range.id,
                                            val,
                                          );
                                        },
                                      ),
                                      // Edit
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        tooltip: 'Edit Scope',
                                        onPressed: () => _editRangeDialog(
                                          context,
                                          cubit,
                                          range,
                                        ),
                                      ),
                                      // Delete
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: tokens.statusOffline,
                                        ),
                                        tooltip: 'Remove Scope',
                                        onPressed: () => _confirmDeleteRange(
                                          context,
                                          cubit,
                                          range,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
