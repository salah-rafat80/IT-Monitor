import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/review_state.dart';
import '../bloc/network_discovery_cubit.dart';
import '../bloc/network_discovery_state.dart';
import '../widgets/discovered_devices_table.dart';
import '../widgets/discovery_approve_dialog.dart';
import '../widgets/discovery_evidence_dialog.dart';
import '../widgets/discovery_ranges_card.dart';
import '../widgets/discovery_start_dialog.dart';
import '../widgets/discovery_summary_cards.dart';
import '../widgets/manage_network_ranges_dialog.dart';

class NetworkDiscoveryPage extends StatelessWidget {
  const NetworkDiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    const userRole = UserRole.admin;
    final isAdmin = true;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.radar_rounded, size: 24, color: Color(0xFF0F62FE)),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Network Discovery & Asset Classification',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'ADMIN ROLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Discovery CSV',
            onPressed: () {
              final cubit = context.read<NetworkDiscoveryCubit>();
              final csv = cubit.exportToCsv();
              if (csv.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Discovery CSV generated (${csv.split('\n').length - 2} assets exported).',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Discovery Results',
            onPressed: () => context.read<NetworkDiscoveryCubit>().init(),
          ),
          const SizedBox(width: 8),
          BlocBuilder<NetworkDiscoveryCubit, NetworkDiscoveryState>(
            builder: (context, state) {
              final isScanning =
                  state is NetworkDiscoveryLoaded && state.isScanning;

              if (isScanning) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () =>
                        context.read<NetworkDiscoveryCubit>().cancelScan(),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Cancel Scan'),
                  ),
                );
              }

              final factoryState = context.watch<FactoryCubit>().state;
              final activeFactoryId = factoryState.selectedFactoryId;

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Tooltip(
                  message: activeFactoryId == null
                      ? 'Select a specific factory from the top bar to launch a scan'
                      : 'Configure and launch network discovery scan',
                  child: ElevatedButton.icon(
                    onPressed: state is NetworkDiscoveryLoaded
                        ? () {
                            _showStartScanDialog(context, state);
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Launch Scan'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocListener<FactoryCubit, FactoryState>(
        listener: (context, fState) {
          context.read<NetworkDiscoveryCubit>().setFactory(
            fState.selectedFactoryId,
          );
        },
        child: BlocConsumer<NetworkDiscoveryCubit, NetworkDiscoveryState>(
          listener: (context, state) {
            if (state is NetworkDiscoveryLoaded && state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
              context.read<NetworkDiscoveryCubit>().clearErrorMessage();
            }
          },
          builder: (context, state) {
            if (state is NetworkDiscoveryLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading Discovery Engine & Scopes...'),
                  ],
                ),
              );
            }

            if (state is NetworkDiscoveryError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text('Discovery Error: ${state.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<NetworkDiscoveryCubit>().init(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is NetworkDiscoveryLoaded) {
              final cubit = context.read<NetworkDiscoveryCubit>();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Scan Progress Banner
                    if (state.isScanning && state.progress != null) ...[
                      _ScanProgressBar(progress: state.progress!),
                      const SizedBox(height: 24),
                    ],

                    // Authorized Network Scopes
                    DiscoveryRangesCard(
                      ranges: state.rangesWithStatus,
                      activeSubnetFilter: state.subnetFilter,
                      onSelectSubnet: (cidr) => cubit.setSubnetFilter(cidr),
                      onScanRange: (range) {
                        _showStartScanDialog(
                          context,
                          state,
                          initialSelectedRanges: {range.cidr},
                        );
                      },
                      isAdmin: isAdmin,
                      onManageScopes: () =>
                          _showManageRangesDialog(context, isAdmin),
                    ),
                    const SizedBox(height: 24),

                    // Real KPI Summary Cards
                    DiscoverySummaryCards(state: state),
                    const SizedBox(height: 24),

                    // Filters & Search Bar
                    _FilterBar(state: state, cubit: cubit),
                    const SizedBox(height: 16),

                    // Header and Counter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discovered Assets (${state.filteredDevices.length} of ${state.totalDiscovered})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (state.searchQuery.isNotEmpty ||
                            state.categoryFilter != null ||
                            state.reviewFilter != null ||
                            state.subnetFilter != null)
                          TextButton.icon(
                            onPressed: () => cubit.resetFilters(),
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text(
                              'Reset All Filters',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Discovered Devices DataTable
                    DiscoveredDevicesTable(
                      devices: state.filteredDevices,
                      userRole: userRole,
                      onViewEvidence: (d) => _showEvidenceDialog(context, d),
                      onApprove: (d) => _showApproveDialog(context, d, cubit),
                      onReject: (d) => cubit.rejectDevice(d.id),
                      onOverrideCategory: (d, cat) =>
                          cubit.overrideCategory(deviceId: d.id, category: cat),
                      onLaunchScan: () {
                        _showStartScanDialog(context, state);
                      },
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _showStartScanDialog(
    BuildContext context,
    NetworkDiscoveryLoaded state, {
    Set<String>? initialSelectedRanges,
  }) {
    final factoryCubit = context.read<FactoryCubit>();
    final activeFactoryId = factoryCubit.state.selectedFactoryId;
    if (activeFactoryId == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Factory Selection Required'),
            ],
          ),
          content: const Text(
            'A discovery scan must belong to an individual active factory.\n\n'
            'Please select an explicit factory (e.g. BNF or RNF) from the top bar before launching a scan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final ranges = state.rangesWithStatus
        .where((r) => r.factoryId == activeFactoryId)
        .toList();

    final effectiveInitialRanges =
        initialSelectedRanges ??
        (state.subnetFilter != null ? {state.subnetFilter!} : null);

    showDialog(
      context: context,
      builder: (ctx) => DiscoveryStartDialog(
        config: state.config,
        ranges: ranges,
        initialSelectedRanges: effectiveInitialRanges,
        onStart:
            ({
              required ranges,
              required strategies,
              required concurrency,
              required timeoutSeconds,
            }) {
              context.read<NetworkDiscoveryCubit>().startScan(
                factoryId: activeFactoryId,
                requestedRanges: ranges,
                enabledStrategies: strategies,
                maxConcurrency: concurrency,
                timeoutSeconds: timeoutSeconds,
              );
            },
      ),
    );
  }

  void _showManageRangesDialog(BuildContext context, bool isAdmin) {
    final factoryCubit = context.read<FactoryCubit>();
    final activeFactoryId = factoryCubit.state.selectedFactoryId;
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<NetworkDiscoveryCubit>(),
        child: ManageNetworkRangesDialog(
          isAdmin: isAdmin,
          factoryId: activeFactoryId,
        ),
      ),
    );
  }

  void _showEvidenceDialog(
    BuildContext context,
    DiscoveredDeviceEntity device,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => DiscoveryEvidenceDialog(device: device),
    );
  }

  void _showApproveDialog(
    BuildContext context,
    DiscoveredDeviceEntity device,
    NetworkDiscoveryCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => DiscoveryApproveDialog(
        device: device,
        onApprove:
            ({
              required device,
              ownerName,
              department,
              deviceName,
              location,
              confirmedCategory,
              isMonitored,
              vendor,
              model,
              notes,
            }) async {
              final messenger = ScaffoldMessenger.of(context);
              final success = await cubit.approveDevice(
                discoveredDevice: device,
                ownerName: ownerName,
                department: department,
                deviceName: deviceName,
                location: location,
                confirmedCategory: confirmedCategory,
                isMonitored: isMonitored,
                vendor: vendor,
                model: model,
                notes: notes,
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Device ${device.ip} saved to persistent inventory.'
                        : 'Failed to save device.',
                  ),
                  backgroundColor: success
                      ? const Color(0xFF10B981)
                      : Colors.red,
                ),
              );
            },
      ),
    );
  }
}

class _ScanProgressBar extends StatelessWidget {
  final dynamic progress;

  const _ScanProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress.progressFraction * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F62FE).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F62FE).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0F62FE),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Active Discovery Scan in Progress ($percent%)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                'Attempted ${progress.targetsAttempted} of ${progress.targetsEnumerated} targets (${progress.responsesReceived} active responses)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.progressFraction,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          if (progress.message != null) ...[
            const SizedBox(height: 6),
            Text(
              progress.message!,
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final NetworkDiscoveryLoaded state;
  final NetworkDiscoveryCubit cubit;

  const _FilterBar({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Field
          SizedBox(
            width: 280,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search IP, Hostname, MAC, Vendor...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (val) => cubit.setSearchQuery(val),
            ),
          ),
          // Category Filter
          DropdownButton<DeviceCategory?>(
            value: state.categoryFilter,
            hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Categories', style: TextStyle(fontSize: 13)),
              ),
              ...DeviceCategory.values.map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    c.displayName,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            onChanged: (cat) => cubit.setCategoryFilter(cat),
          ),
          // Review State Filter
          DropdownButton<ReviewState?>(
            value: state.reviewFilter,
            hint: const Text(
              'All Review States',
              style: TextStyle(fontSize: 13),
            ),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text(
                  'All Review States',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ...ReviewState.values.map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.displayName,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            onChanged: (rev) => cubit.setReviewFilter(rev),
          ),
        ],
      ),
    );
  }
}
