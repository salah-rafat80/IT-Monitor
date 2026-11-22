import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import '../../../monitoring/presentation/bloc/monitoring_dashboard_state.dart';
import '../widgets/wall_display_grid.dart';
import '../widgets/wall_display_header.dart';
import '../widgets/wall_display_summary_bar.dart';

import '../../../infrastructure/presentation/bloc/infrastructure_cubit.dart';
import '../../../infrastructure/presentation/bloc/infrastructure_state.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';

class WallDisplayPage extends StatelessWidget {
  const WallDisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    String? initialFactoryId;
    try {
      initialFactoryId = context.read<FactoryCubit>().state.selectedFactoryId;
    } catch (_) {}

    return _WallDisplayView(initialFactoryId: initialFactoryId);
  }
}

class _WallDisplayView extends StatefulWidget {
  final String? initialFactoryId;
  const _WallDisplayView({this.initialFactoryId});

  @override
  State<_WallDisplayView> createState() => _WallDisplayViewState();
}

class _WallDisplayViewState extends State<_WallDisplayView> {
  final FocusNode _focusNode = FocusNode();
  String? _currentFactoryId;

  @override
  void initState() {
    super.initState();
    _currentFactoryId = widget.initialFactoryId;
    // Default to severity sorting for Wall Display Mode and clear all filters to guarantee all approved devices are visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<MonitoringDashboardCubit>();
      cubit.setSearchQuery('');
      cubit.setStatusFilter(null);
      cubit.setDepartmentFilter(null);
      cubit.setLocationFilter(null);
      cubit.setTypeFilter(null);
      cubit.setEnabledFilter(null);
      cubit.setSorting('severity');
      if (_currentFactoryId != null) {
        cubit.setFactoryFilter(_currentFactoryId);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _exitWallDisplay();
    }
  }

  void _exitWallDisplay() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    return KeyboardListener(
      focusNode: _focusNode..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: tokens.background,
        body: SafeArea(
          child: BlocBuilder<MonitoringDashboardCubit, MonitoringDashboardState>(
            builder: (context, state) {
              if (state is MonitoringDashboardLoading) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: tokens.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Initializing Wall Display Mode...',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              if (state is MonitoringDashboardError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: tokens.statusOffline,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: tokens.statusOffline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context
                            .read<MonitoringDashboardCubit>()
                            .initDashboard(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is MonitoringDashboardLoaded) {
                final isConnected =
                    state.isEngineRunning && !state.isEnginePaused;
                final lastUpdated = DateTime.now();

                return Column(
                  children: [
                    // Header
                    WallDisplayHeader(
                      isConnected: isConnected,
                      lastUpdatedAt: lastUpdated,
                      currentSortBy: state.sortBy,
                      activeFactoryId: _currentFactoryId,
                      onFactoryChanged: (factoryId) {
                        setState(() {
                          _currentFactoryId = factoryId;
                        });
                        try {
                          context
                              .read<FactoryCubit>()
                              .selectFactoryById(factoryId);
                        } catch (_) {}
                        context
                            .read<MonitoringDashboardCubit>()
                            .setFactoryFilter(factoryId);
                        context
                            .read<InfrastructureCubit>()
                            .setFactory(factoryId);
                      },
                      onSortChanged: (sortBy) {
                        context.read<MonitoringDashboardCubit>().setSorting(
                          sortBy,
                        );
                      },
                    ),

                    // Disconnected Warning Banner if connection drops
                    if (!isConnected)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 16,
                        ),
                        color: tokens.statusOfflineSurface,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: tokens.onStatusOffline,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SERVICE DISCONNECTED — DISPLAYING LAST KNOWN MONITORING STATE',
                              style: TextStyle(
                                color: tokens.onStatusOffline,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Summary Counters Bar
                    WallDisplaySummaryBar(
                      totalCount: state.totalCount,
                      upCount: state.upCount,
                      degradedCount: state.degradedCount,
                      downCount: state.downCount,
                      unknownCount: state.unknownCount,
                      maintenanceCount: state.maintenanceCount,
                    ),

                    // Critical UniFi Infrastructure Bar
                    _buildWallInfrastructureBar(),

                    // Full-Screen Device Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: WallDisplayGrid(devices: state.filteredDevices),
                      ),
                    ),

                    // Footer Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        border: Border(
                          top: BorderSide(color: tokens.cardBorder, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monitored Devices Grid • No Scroll / Full Coverage',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: tokens.textSecondary,
                            ),
                          ),
                          Text(
                            'Press ESC to exit Wall Display Mode',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWallInfrastructureBar() {
    return BlocBuilder<InfrastructureCubit, InfrastructureState>(
      builder: (context, infraState) {
        if (infraState.devices.isEmpty) return const SizedBox.shrink();
        final tokens = context.appTokens;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined, color: tokens.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Infrastructure Assets:',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${infraState.totalCount} assets (${infraState.upCount} UP, ${infraState.downCount + infraState.unknownCount} DISCONNECTED)',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),
                  Text(
                    'Read-Only Monitoring',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: infraState.devices.map((device) {
                    final status = infraState.getStatusFor(device);
                    final locationText =
                        device.location != null && device.location!.isNotEmpty
                        ? ' [${device.location}]'
                        : '';
                    final latencyText =
                        status?.status == DeviceStatusEnum.up &&
                            status?.lastLatencyMs != null
                        ? ' (${status!.lastLatencyMs}ms)'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildInfraPill(
                        context: context,
                        label:
                            '${device.name} (${device.ip})$locationText$latencyText',
                        status: status?.status,
                        isCritical: device.isCriticalInfrastructure,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfraPill({
    required BuildContext context,
    required String label,
    required DeviceStatusEnum? status,
    required bool isCritical,
  }) {
    final tokens = context.appTokens;
    Color color;
    String statusText;
    switch (status) {
      case DeviceStatusEnum.up:
        color = tokens.statusOnline;
        statusText = 'UP';
        break;
      case DeviceStatusEnum.degraded:
        color = tokens.statusDegraded;
        statusText = 'DEGRADED';
        break;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        color = tokens.statusOffline;
        statusText = 'OFFLINE';
        break;
      case DeviceStatusEnum.unknown:
        color = tokens.statusUnknown;
        statusText = 'UNKNOWN';
        break;
      case DeviceStatusEnum.stale:
        color = tokens.statusDegraded;
        statusText = 'STALE';
        break;
      case DeviceStatusEnum.maintenance:
        color = tokens.statusMaintenance;
        statusText = 'MAINT';
        break;
      default:
        color = tokens.statusOffline;
        statusText = 'DISCONNECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $statusText',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
