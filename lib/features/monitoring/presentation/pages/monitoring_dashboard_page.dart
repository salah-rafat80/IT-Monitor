import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/presentation/widgets/app_error_card.dart';
import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../devices/presentation/widgets/assign_owner_dialog.dart';
import '../../domain/entities/monitored_device.dart';
import '../bloc/monitoring_dashboard_cubit.dart';
import '../bloc/monitoring_dashboard_state.dart';
import '../widgets/device_details_modal.dart';
import '../widgets/monitored_devices_table.dart';
import '../widgets/monitoring_filter_bar.dart';
import '../widgets/monitoring_summary_cards.dart';

import '../../../infrastructure/presentation/widgets/infrastructure_status_cards.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../../factories/presentation/widgets/factory_overview_cards.dart';

class MonitoringDashboardPage extends StatefulWidget {
  const MonitoringDashboardPage({super.key});

  @override
  State<MonitoringDashboardPage> createState() =>
      _MonitoringDashboardPageState();
}

class _MonitoringDashboardPageState extends State<MonitoringDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final currentFactoryId =
            context.read<FactoryCubit>().state.selectedFactoryId;
        final cubit = context.read<MonitoringDashboardCubit>();
        if (cubit.activeFactoryId != currentFactoryId) {
          cubit.setFactoryFilter(currentFactoryId);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FactoryCubit, FactoryState>(
      listenWhen: (prev, curr) =>
          prev.selectedFactoryId != curr.selectedFactoryId,
      listener: (context, state) {
        context
            .read<MonitoringDashboardCubit>()
            .setFactoryFilter(state.selectedFactoryId);
      },
      child: const MonitoringDashboardView(),
    );
  }
}

class MonitoringDashboardView extends StatefulWidget {
  const MonitoringDashboardView({super.key});

  @override
  State<MonitoringDashboardView> createState() =>
      _MonitoringDashboardViewState();
}

class _MonitoringDashboardViewState extends State<MonitoringDashboardView> {
  final Set<int> _selectedDeviceIds = {};
  bool _isBulkChecking = false;

  Future<void> _bulkTriggerCheck(
    List<MonitoredDevice> devices,
    MonitoringDashboardCubit cubit,
    AppColors tokens,
  ) async {
    final targets = devices
        .where((d) => _selectedDeviceIds.contains(d.device.id))
        .toList();
    if (targets.isEmpty) return;

    setState(() => _isBulkChecking = true);
    try {
      for (final item in targets) {
        await cubit.triggerManualCheck(item.device.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Triggered instant check for ${targets.length} device(s)',
              style: TextStyle(color: tokens.onStatusOnline),
            ),
            backgroundColor: tokens.statusOnlineSurface,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBulkChecking = false);
      }
    }
  }

  Future<void> _bulkSetMaintenance(
    List<MonitoredDevice> devices,
    bool isMaintenance,
    MonitoringDashboardCubit cubit,
    AppColors tokens,
  ) async {
    final targets = devices
        .where((d) => _selectedDeviceIds.contains(d.device.id))
        .toList();
    if (targets.isEmpty) return;

    for (final item in targets) {
      await cubit.toggleMaintenanceMode(
        deviceId: item.device.id,
        isMaintenance: isMaintenance,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMaintenance
                ? 'Set ${targets.length} device(s) into maintenance mode'
                : 'Exited maintenance mode for ${targets.length} device(s)',
            style: TextStyle(color: tokens.onSurface),
          ),
          backgroundColor: tokens.surfaceVariant,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isAdmin = true;

    return Scaffold(
      backgroundColor: tokens.background,
      body: BlocBuilder<MonitoringDashboardCubit, MonitoringDashboardState>(
        builder: (context, state) {
          if (state is MonitoringDashboardLoading) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppSkeleton(
                        width: 42,
                        height: 42,
                        borderRadius: AppRadius.md,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AppSkeleton(width: 260, height: 20),
                          SizedBox(height: 6),
                          AppSkeleton(width: 180, height: 14),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppSkeleton.summaryCards(count: 4),
                  const SizedBox(height: AppSpacing.xl),
                  AppSkeleton.table(rowCount: 6, columnCount: 9),
                ],
              ),
            );
          }

          if (state is MonitoringDashboardError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: AppErrorCard(
                  title: 'Monitoring Telemetry Issue',
                  message: state.message,
                  onRetry: () => context
                      .read<MonitoringDashboardCubit>()
                      .initDashboard(),
                ),
              ),
            );
          }

          if (state is MonitoringDashboardLoaded) {
            final cubit = context.read<MonitoringDashboardCubit>();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Integrated In-Page Header Bar ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          Icons.monitor_heart_rounded,
                          size: 22,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PC & Laptop Monitoring Dashboard',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.onBackground,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                    border: Border.all(
                                      color: tokens.primary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'ADMIN ROLE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Real-time automated telemetry and connectivity monitoring across all plant assets',
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: tokens.onSurfaceVariant),
                        tooltip: 'Refresh Inventory',
                        onPressed: () => cubit.refreshDevices(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // KPI Summary Cards Grid
                  MonitoringSummaryCards(
                    state: state,
                    onStatusCardTap: (status) => cubit.setStatusFilter(status),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Factory Overview Cards for Multi-Factory Architecture (BNF, RNF)
                  FactoryOverviewCards(
                    devices: state.allDevices.map((m) => m.device).toList(),
                    statuses: {
                      for (var m in state.allDevices) m.device.id: m.status,
                    },
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Critical UniFi Infrastructure Status
                  const InfrastructureStatusCards(),
                  const SizedBox(height: AppSpacing.xl),

                  // Search & Filters Bar
                  MonitoringFilterBar(state: state, cubit: cubit),
                  const SizedBox(height: AppSpacing.xl),

                  // Header title for table
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Text(
                        'Monitored Devices (${state.filteredDevices.length} of ${state.totalCount})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: tokens.onBackground,
                        ),
                      ),
                      if (state.searchQuery.isNotEmpty ||
                          state.statusFilter != null ||
                          state.departmentFilter != null)
                        TextButton.icon(
                          onPressed: () {
                            cubit.setSearchQuery('');
                            cubit.setStatusFilter(null);
                            cubit.setDepartmentFilter(null);
                            cubit.setLocationFilter(null);
                            cubit.setTypeFilter(null);
                            cubit.setEnabledFilter(null);
                          },
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text(
                            'Reset All Filters',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Bulk Actions Floating / Sticky Bar ──
                  if (_selectedDeviceIds.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: tokens.border,
                        ),
                      ),
                      child: Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: tokens.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedDeviceIds.length} device(s) selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: tokens.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _isBulkChecking
                                ? null
                                : () => _bulkTriggerCheck(
                                    state.filteredDevices,
                                    cubit,
                                    tokens,
                                  ),
                            icon: _isBulkChecking
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: tokens.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              _isBulkChecking
                                  ? 'Checking...'
                                  : 'Check Selected (${_selectedDeviceIds.length})',
                            ),
                          ),
                          if (isAdmin) ...[
                            OutlinedButton.icon(
                              onPressed: () => _bulkSetMaintenance(
                                state.filteredDevices,
                                true,
                                cubit,
                                tokens,
                              ),
                              icon: const Icon(
                                Icons.build_circle_rounded,
                                size: 16,
                              ),
                              label: const Text('Set Maintenance'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _bulkSetMaintenance(
                                state.filteredDevices,
                                false,
                                cubit,
                                tokens,
                              ),
                              icon: const Icon(
                                Icons.build_circle_outlined,
                                size: 16,
                              ),
                              label: const Text('Exit Maintenance'),
                            ),
                          ],
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedDeviceIds.clear()),
                            child: const Text('Clear Selection'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Prioritized Devices DataTable
                  MonitoredDevicesTable(
                    devices: state.filteredDevices,
                    isAdmin: isAdmin,
                    failureThreshold: state.config.failureThreshold,
                    selectedDeviceIds: _selectedDeviceIds,
                    onClearFilters: () => cubit.clearAllFilters(),
                    isFiltered: state.totalCount > 0,
                    onToggleSelect: (deviceId, selected) {
                      setState(() {
                        if (selected) {
                          _selectedDeviceIds.add(deviceId);
                        } else {
                          _selectedDeviceIds.remove(deviceId);
                        }
                      });
                    },
                    onSelectAll: (selectAll) {
                      setState(() {
                        if (selectAll) {
                          _selectedDeviceIds.addAll(
                            state.filteredDevices.map((d) => d.device.id),
                          );
                        } else {
                          _selectedDeviceIds.clear();
                        }
                      });
                    },
                    onSelectDevice: (item) => _showDeviceDetails(
                      context,
                      item,
                      isAdmin,
                      state.config,
                      cubit,
                    ),
                    onTriggerCheck: (item) =>
                        cubit.triggerManualCheck(item.device.id),
                    onToggleMaintenance: (item, isMaint) =>
                        cubit.toggleMaintenanceMode(
                          deviceId: item.device.id,
                          isMaintenance: isMaint,
                        ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showDeviceDetails(
    BuildContext context,
    MonitoredDevice item,
    bool isAdmin,
    dynamic config,
    MonitoringDashboardCubit cubit,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeviceDetailsModal(
        item: item,
        isAdmin: isAdmin,
        config: config,
        onTriggerCheck: () {
          Navigator.pop(ctx);
          cubit.triggerManualCheck(item.device.id);
        },
        onToggleMaintenance: (isMaint) {
          Navigator.pop(ctx);
          cubit.toggleMaintenanceMode(
            deviceId: item.device.id,
            isMaintenance: isMaint,
          );
        },
        onAssignOwner: () async {
          Navigator.pop(ctx);
          final devRepo = getIt<DeviceRepository>();
          showDialog(
            context: context,
            builder: (_) => AssignOwnerDialog(
              device: item.device,
              onSave: (newOwnerName) async {
                final res = await devRepo.assignDeviceOwner(
                  deviceId: item.device.id,
                  ownerName: newOwnerName,
                );
                if (context.mounted) {
                  cubit.refreshDevices();
                }
                return res.isSuccess;
              },
            ),
          );
        },
      ),
    );
  }
}
