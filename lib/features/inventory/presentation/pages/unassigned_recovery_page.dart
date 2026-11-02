import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/ipv4_utils.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/presentation/bloc/devices_cubit.dart';
import '../../../factories/domain/entities/factory_entity.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../../network_discovery/domain/entities/network_range.dart';

class FactorySuggestionResult {
  final String status; // 'single', 'ambiguous', 'none'
  final FactoryEntity? matchedFactory;
  final List<FactoryEntity> matchedCandidates;

  const FactorySuggestionResult.single(FactoryEntity factory)
    : status = 'single',
      matchedFactory = factory,
      matchedCandidates = const [];

  const FactorySuggestionResult.ambiguous(List<FactoryEntity> candidates)
    : status = 'ambiguous',
      matchedFactory = null,
      matchedCandidates = candidates;

  const FactorySuggestionResult.none()
    : status = 'none',
      matchedFactory = null,
      matchedCandidates = const [];

  bool get isSingle => status == 'single';
  bool get isAmbiguous => status == 'ambiguous';
  bool get isNone => status == 'none';
}

class UnassignedRecoveryPage extends StatefulWidget {
  final VoidCallback? onBackToInventory;

  const UnassignedRecoveryPage({super.key, this.onBackToInventory});

  static FactorySuggestionResult suggestFactoryForIp(
    String ip,
    List<FactoryEntity> factories,
  ) {
    final canon = Ipv4Utils.canonicalizeIpv4(ip);
    if (canon == null) return const FactorySuggestionResult.none();

    final matches = <FactoryEntity>[];
    for (final f in factories) {
      if (f.id == 'unassigned' || !f.isActive) continue;
      final cidr = f.expectedCidr;
      if (cidr != null && cidr.isNotEmpty) {
        final range = NetworkRange.parse(cidr);
        if (range != null && range.containsIp(canon)) {
          matches.add(f);
        }
      }
    }

    if (matches.length == 1) {
      return FactorySuggestionResult.single(matches.first);
    } else if (matches.length > 1) {
      return FactorySuggestionResult.ambiguous(matches);
    } else {
      return const FactorySuggestionResult.none();
    }
  }

  @override
  State<UnassignedRecoveryPage> createState() => _UnassignedRecoveryPageState();
}

class _UnassignedRecoveryPageState extends State<UnassignedRecoveryPage> {
  final _searchController = TextEditingController();
  final Set<int> _selectedDeviceIds = {};
  bool _isAssigning = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load unassigned devices
    context.read<DevicesCubit>().loadDevices(factoryId: 'unassigned');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  FactorySuggestionResult _suggestFactoryForIp(
    String ip,
    List<FactoryEntity> factories,
  ) => UnassignedRecoveryPage.suggestFactoryForIp(ip, factories);

  void _showAssignmentPreviewDialog({
    required BuildContext context,
    required String targetFactoryId,
    required String targetFactoryName,
    required List<DeviceEntity> selectedDevices,
  }) {
    if (selectedDevices.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.assignment_turned_in_rounded,
              color: Color(0xFF0F62FE),
            ),
            const SizedBox(width: 10),
            Text(
              'Assign ${selectedDevices.length} Devices to $targetFactoryName',
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to reassign ${selectedDevices.length} legacy unassigned devices to $targetFactoryName ($targetFactoryId).',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.blue,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Data Preservation Guarantee',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Original Device IDs are preserved exactly.\n'
                      '• All device metadata (owner, dept, MAC, OS, notes) is maintained.\n'
                      '• Historical check results, latencies, and incident references remain intact.\n'
                      '• Operation will be logged with your administrator identity in the audit trail.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Selected Devices:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: selectedDevices.length,
                  itemBuilder: (context, idx) {
                    final d = selectedDevices[idx];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: Text(
                        '#${d.id}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        '${d.name} (${d.ip})',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${d.ownerName} / ${d.department}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
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
              setState(() => _isAssigning = true);

              final cubit = context.read<DevicesCubit>();
              final messenger = ScaffoldMessenger.of(context);

              final res = await cubit.reassignDevicesFactory(
                deviceIds: selectedDevices.map((d) => d.id).toList(),
                targetFactoryId: targetFactoryId,
              );

              if (mounted) {
                setState(() {
                  _isAssigning = false;
                  if (res.isSuccess) {
                    _selectedDeviceIds.clear();
                  }
                });

                final errorMsg = res.failureOrNull?.message;
                if (res.isSuccess) {
                  final data = res.dataOrNull;
                  final count = data?.count ?? selectedDevices.length;
                  if (data != null && data.hasRefreshError) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Successfully assigned $count devices to $targetFactoryName, but refreshing inventory failed: ${data.refreshError}',
                        ),
                        backgroundColor: Colors.orange.shade800,
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Successfully assigned $count devices to $targetFactoryName.',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to assign devices: ${errorMsg ?? "Unknown error"}',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 8),
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Assignment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthCubit>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final isAdmin = currentUser?.role == UserRole.admin;

    final factoryState = context.watch<FactoryCubit>().state;
    final availableFactories = factoryState.factories
        .where((f) => f.id != 'unassigned' && f.isActive)
        .toList();

    return Scaffold(
      body: BlocConsumer<DevicesCubit, DevicesState>(
        listener: (context, state) {
          if (state is DevicesLoaded) {
            final validIds = state.allDevices
                .where(
                  (d) => d.factoryId == 'unassigned' || d.factoryId.isEmpty,
                )
                .map((d) => d.id)
                .toSet();
            setState(() {
              _selectedDeviceIds.retainWhere(validIds.contains);
            });
          } else if (state is DevicesError) {
            setState(() {
              _selectedDeviceIds.clear();
            });
          }
        },
        builder: (context, state) {
          final isLoaded = state is DevicesLoaded;
          final List<DeviceEntity> unassignedList;
          if (isLoaded) {
            unassignedList = state.allDevices
                .where(
                  (d) => d.factoryId == 'unassigned' || d.factoryId.isEmpty,
                )
                .toList();
          } else {
            unassignedList = [];
          }

          final filteredList = unassignedList.where((d) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return d.name.toLowerCase().contains(q) ||
                d.ip.toLowerCase().contains(q) ||
                d.ownerName.toLowerCase().contains(q) ||
                d.department.toLowerCase().contains(q);
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header with Back button
                Row(
                  children: [
                    if (widget.onBackToInventory != null) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back to Factory Inventory',
                        onPressed: widget.onBackToInventory,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Legacy Unassigned Inventory Recovery',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  state is DevicesError
                                      ? 'Error Loading'
                                      : '${unassignedList.length} Unassigned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: state is DevicesError
                                        ? Colors.red
                                        : Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assign legacy inventory devices to RNF or BNF without losing IDs, historical records, or check history.',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Bar: Search + Bulk Assignment actions
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
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        // Search box
                        SizedBox(
                          width: 280,
                          height: 38,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search unassigned devices...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
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
                        const SizedBox(width: 16),

                        // Select All button
                        TextButton.icon(
                          onPressed: !isLoaded || unassignedList.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    if (_selectedDeviceIds.length ==
                                        filteredList.length) {
                                      _selectedDeviceIds.clear();
                                    } else {
                                      _selectedDeviceIds.addAll(
                                        filteredList.map((d) => d.id),
                                      );
                                    }
                                  });
                                },
                          icon: Icon(
                            _selectedDeviceIds.length == filteredList.length &&
                                    filteredList.isNotEmpty
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _selectedDeviceIds.length == filteredList.length &&
                                    filteredList.isNotEmpty
                                ? 'Deselect All'
                                : 'Select All (${filteredList.length})',
                          ),
                        ),
                        const Spacer(),

                        // Assignment buttons
                        if (isAdmin) ...[
                          Text(
                            'Assign Selected (${isLoaded ? _selectedDeviceIds.length : 0}):',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (final f in availableFactories) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: f.code == 'RNF'
                                    ? const Color(0xFF0F62FE)
                                    : const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed:
                                  !isLoaded ||
                                      _selectedDeviceIds.isEmpty ||
                                      _isAssigning
                                  ? null
                                  : () {
                                      final selectedDevs = unassignedList
                                          .where(
                                            (d) => _selectedDeviceIds.contains(
                                              d.id,
                                            ),
                                          )
                                          .toList();
                                      _showAssignmentPreviewDialog(
                                        context: context,
                                        targetFactoryId: f.id,
                                        targetFactoryName: f.name,
                                        selectedDevices: selectedDevs,
                                      );
                                    },
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                              ),
                              label: Text('Assign to ${f.code}'),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Table
                Expanded(
                  child: state is DevicesLoading || _isAssigning
                      ? const Center(child: CircularProgressIndicator())
                      : state is DevicesError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load unassigned inventory:\n${state.message}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .read<DevicesCubit>()
                                    .loadDevices(factoryId: 'unassigned'),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 48,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                unassignedList.isEmpty
                                    ? 'No unassigned devices remain! All devices are assigned to active factories.'
                                    : 'No unassigned devices match your search query.',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 42,
                                dataRowMinHeight: 40,
                                dataRowMaxHeight: 40,
                                columns: [
                                  const DataColumn(label: Text('Select')),
                                  const DataColumn(label: Text('ID')),
                                  const DataColumn(label: Text('Device Name')),
                                  const DataColumn(label: Text('IP Address')),
                                  const DataColumn(label: Text('Owner Name')),
                                  const DataColumn(label: Text('Department')),
                                  const DataColumn(
                                    label: Text('Office Location'),
                                  ),
                                  const DataColumn(
                                    label: Text('Suggested Factory'),
                                  ),
                                  const DataColumn(
                                    label: Text('Quick Actions'),
                                  ),
                                ],
                                rows: filteredList.map((d) {
                                  final isSelected = _selectedDeviceIds
                                      .contains(d.id);
                                  final suggestion = _suggestFactoryForIp(
                                    d.ip,
                                    availableFactories,
                                  );

                                  return DataRow(
                                    selected: isSelected,
                                    cells: [
                                      DataCell(
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedDeviceIds.add(d.id);
                                              } else {
                                                _selectedDeviceIds.remove(d.id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '#${d.id}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          d.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          d.ip,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(d.ownerName)),
                                      DataCell(Text(d.department)),
                                      DataCell(Text(d.officeLocation ?? '—')),
                                      DataCell(
                                        suggestion.isSingle
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.15,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.blue
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Matches ${suggestion.matchedFactory!.code}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              )
                                            : suggestion.isAmbiguous
                                            ? Tooltip(
                                                message:
                                                    'IP matches multiple factory subnets (${suggestion.matchedCandidates.map((f) => f.code).join(', ')}). Administrator must select target factory manually.',
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.amber
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        size: 13,
                                                        color: Colors.amber,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Ambiguous (${suggestion.matchedCandidates.map((f) => f.code).join('/')})',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.amber,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : const Text(
                                                'No Match',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (final f
                                                in availableFactories) ...[
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                ),
                                                onPressed:
                                                    !isLoaded || _isAssigning
                                                    ? null
                                                    : () {
                                                        _showAssignmentPreviewDialog(
                                                          context: context,
                                                          targetFactoryId: f.id,
                                                          targetFactoryName:
                                                              f.name,
                                                          selectedDevices: [d],
                                                        );
                                                      },
                                                child: Text(
                                                  'Assign to ${f.code}',
                                                ),
                                              ),
                                              const SizedBox(width: 4),
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
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
