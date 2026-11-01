import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../devices/presentation/widgets/assign_owner_dialog.dart';
import '../bloc/monitoring_dashboard_cubit.dart';
import '../bloc/monitoring_dashboard_state.dart';
import '../widgets/device_details_modal.dart';
import '../widgets/monitored_devices_table.dart';
import '../widgets/monitoring_filter_bar.dart';
import '../widgets/monitoring_summary_cards.dart';

import '../../../infrastructure/presentation/bloc/infrastructure_cubit.dart';
import '../../../infrastructure/presentation/widgets/infrastructure_status_cards.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../../../factories/presentation/widgets/factory_overview_cards.dart';

class MonitoringDashboardPage extends StatelessWidget {
  const MonitoringDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final initialFactoryId = context
        .read<FactoryCubit>()
        .state
        .selectedFactoryId;
    return MultiBlocProvider(
      providers: [
        BlocProvider<MonitoringDashboardCubit>(
          create: (context) {
            final cubit = getIt<MonitoringDashboardCubit>();
            if (initialFactoryId != null) {
              cubit.setFactoryFilter(initialFactoryId);
            }
            return cubit..initDashboard();
          },
        ),
        BlocProvider<InfrastructureCubit>.value(
          value: getIt<InfrastructureCubit>()
            ..loadInfrastructure(factoryId: initialFactoryId),
        ),
      ],
      child: BlocListener<FactoryCubit, FactoryState>(
        listener: (context, state) {
          context.read<MonitoringDashboardCubit>().setFactoryFilter(
            state.selectedFactoryId,
          );
          context.read<InfrastructureCubit>().setFactory(
            state.selectedFactoryId,
          );
        },
        child: const MonitoringDashboardView(),
      ),
    );
  }
}

class MonitoringDashboardView extends StatelessWidget {
  const MonitoringDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthCubit>().state;
    final userRole = authState is AuthAuthenticated
        ? authState.user.role
        : UserRole.viewer;
    final isAdmin = userRole == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.monitor_heart_rounded, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'PC & Laptop Monitoring Dashboard',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAdmin
                    ? theme.primaryColor.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isAdmin
                      ? theme.primaryColor.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                isAdmin ? 'ADMIN ROLE' : 'VIEWER (READ ONLY)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isAdmin ? theme.primaryColor : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Inventory',
            onPressed: () =>
                context.read<MonitoringDashboardCubit>().refreshDevices(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: BlocBuilder<MonitoringDashboardCubit, MonitoringDashboardState>(
        builder: (context, state) {
          if (state is MonitoringDashboardLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Initializing Monitoring Engine & Persisted Telemetry...',
                  ),
                ],
              ),
            );
          }

          if (state is MonitoringDashboardError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Monitoring Telemetry Issue',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context
                          .read<MonitoringDashboardCubit>()
                          .initDashboard(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Monitoring Initialization'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is MonitoringDashboardLoaded) {
            final cubit = context.read<MonitoringDashboardCubit>();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Summary Cards Grid
                  MonitoringSummaryCards(
                    state: state,
                    onStatusCardTap: (status) => cubit.setStatusFilter(status),
                  ),
                  const SizedBox(height: 24),

                  // Factory Overview Cards for Multi-Factory Architecture (BNF, RNF)
                  FactoryOverviewCards(
                    devices: state.allDevices.map((m) => m.device).toList(),
                    statuses: {
                      for (var m in state.allDevices) m.device.id: m.status,
                    },
                    incidents: state.realActiveIncidents,
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 24),

                  // Critical UniFi Infrastructure Status
                  const InfrastructureStatusCards(),
                  const SizedBox(height: 24),

                  // Search & Filters Bar
                  MonitoringFilterBar(state: state, cubit: cubit),
                  const SizedBox(height: 24),

                  // Header title for table
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Monitored Devices (${state.filteredDevices.length} of ${state.totalCount})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 12),

                  // Prioritized Devices DataTable
                  MonitoredDevicesTable(
                    devices: state.filteredDevices,
                    userRole: userRole,
                    onSelectDevice: (item) => _showDeviceDetails(
                      context,
                      item,
                      userRole,
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
    item,
    UserRole userRole,
    config,
    MonitoringDashboardCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => DeviceDetailsModal(
        item: item,
        userRole: userRole,
        config: config,
        onTriggerCheck: () {
          cubit.triggerManualCheck(item.device.id);
          Navigator.of(ctx).pop();
        },
        onToggleMaintenance: (isMaint) {
          cubit.toggleMaintenanceMode(
            deviceId: item.device.id,
            isMaintenance: isMaint,
          );
          Navigator.of(ctx).pop();
        },
        onEditOwner: userRole == UserRole.admin
            ? () {
                Navigator.of(ctx).pop();
                _showAssignOwnerDialog(context, item.device, cubit);
              }
            : null,
      ),
    );
  }

  void _showAssignOwnerDialog(
    BuildContext context,
    DeviceEntity device,
    MonitoringDashboardCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AssignOwnerDialog(
        device: device,
        onSave: (newOwner) async {
          final repo = getIt<DeviceRepository>();
          final res = await repo.assignDeviceOwner(
            deviceId: device.id,
            ownerName: newOwner,
          );
          if (res.isSuccess && context.mounted) {
            cubit.initDashboard();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Assigned person for ${device.ip} updated to "$newOwner".',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
            return true;
          }
          return false;
        },
        onClear: () async {
          final repo = getIt<DeviceRepository>();
          final res = await repo.assignDeviceOwner(
            deviceId: device.id,
            ownerName: 'Unassigned',
          );
          if (res.isSuccess && context.mounted) {
            cubit.initDashboard();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cleared assigned person for ${device.ip} (marked Unassigned).',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return true;
          }
          return false;
        },
      ),
    );
  }
}
