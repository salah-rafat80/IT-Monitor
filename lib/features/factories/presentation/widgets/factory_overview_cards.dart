import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../network_discovery/domain/entities/discovery_config_entity.dart';
import '../../../network_discovery/domain/entities/discovery_scan_job.dart';
import '../../../network_discovery/domain/entities/network_range.dart';
import '../../../network_discovery/presentation/bloc/network_discovery_cubit.dart';
import '../../../network_discovery/presentation/bloc/network_discovery_state.dart';
import '../../../network_discovery/presentation/widgets/discovery_start_dialog.dart';
import '../../../network_discovery/presentation/widgets/manage_network_ranges_dialog.dart';
import '../../domain/entities/factory_entity.dart';
import '../bloc/factory_cubit.dart';

class FactoryOverviewCards extends StatelessWidget {
  final List<DeviceEntity> devices;
  final Map<int, DeviceStatusEntity> statuses;
  final bool isAdmin;

  const FactoryOverviewCards({
    super.key,
    required this.devices,
    required this.statuses,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final factoryState = context.watch<FactoryCubit>().state;
    final discoveryState = context.watch<NetworkDiscoveryCubit>().state;

    final factories = factoryState.factories;
    final allRanges = discoveryState is NetworkDiscoveryLoaded
        ? discoveryState.config.networkRanges
        : <NetworkRange>[];
    final allScans = discoveryState is NetworkDiscoveryLoaded
        ? discoveryState.allScans
        : <DiscoveryScanJob>[];

    if (factories.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = context.appTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.apartment_rounded, size: 20, color: tokens.primary),
            const SizedBox(width: 8),
            Text(
              'Factory Overview & Network Scopes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: tokens.onBackground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisExtent: 275,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: factories.length,
              itemBuilder: (context, index) {
                final factory = factories[index];
                return _FactoryCard(
                  factory: factory,
                  devices: devices
                      .where((d) => d.factoryId == factory.id)
                      .toList(),
                  statuses: statuses,
                  ranges: allRanges
                      .where((r) => r.factoryId == factory.id)
                      .toList(),
                  latestScan: allScans
                      .where((s) => s.factoryId == factory.id)
                      .firstOrNull,
                  isAdmin: isAdmin,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _FactoryCard extends StatelessWidget {
  final FactoryEntity factory;
  final List<DeviceEntity> devices;
  final Map<int, DeviceStatusEntity> statuses;
  final List<NetworkRange> ranges;
  final DiscoveryScanJob? latestScan;
  final bool isAdmin;

  const _FactoryCard({
    required this.factory,
    required this.devices,
    required this.statuses,
    required this.ranges,
    required this.latestScan,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final activeFactory = context.watch<FactoryCubit>().state.selectedFactory;
    final isSelected = activeFactory?.id == factory.id;

    final isRnf = factory.code.toUpperCase() == 'RNF';
    final factoryBrandColor = isRnf ? tokens.factoryRnf : tokens.factoryBnf;

    final monitoredDevices = devices.where((d) => d.isMonitored).toList();
    final onlineCount = monitoredDevices.where((d) {
      final st = statuses[d.id];
      return st?.effectiveStatus() == DeviceStatusEnum.up;
    }).length;
    final offlineCount = monitoredDevices.length - onlineCount;

    final enabledRanges = ranges.where((r) => r.isEnabled).length;
    final activeAlerts = offlineCount;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? factoryBrandColor : tokens.cardBorder,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: factoryBrandColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: factoryBrandColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    factory.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: factoryBrandColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    factory.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.statusOnline.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: tokens.statusOnline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'ACTIVE SCOPE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: tokens.statusOnline,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Authoritative Gateway Health Row
            Builder(
              builder: (context) {
                final gwStatus = context
                    .watch<FactoryCubit>()
                    .state
                    .gatewayStatuses[factory.id];
                final gwIp = factory.gatewayIp ?? 'N/A';
                final isGwOnline = gwStatus?.isOnline ?? false;
                final isGwDown = gwStatus?.isDown ?? false;
                final gwLatency = gwStatus?.latencyMs;

                Color gwColor = tokens.statusUnknown;
                String statusText = 'CHECKING';
                IconData gwIcon = Icons.help_outline;

                if (isGwOnline) {
                  gwColor = tokens.statusOnline;
                  statusText =
                      'ONLINE (${gwLatency != null ? "${gwLatency}ms" : "OK"})';
                  gwIcon = Icons.check_circle_outline;
                } else if (gwStatus?.isDegraded ?? false) {
                  gwColor = tokens.statusDegraded;
                  statusText =
                      'DEGRADED (${gwLatency != null ? "${gwLatency}ms" : "HIGH LATENCY"})';
                  gwIcon = Icons.warning_amber_rounded;
                } else if (isGwDown) {
                  gwColor = tokens.statusOffline;
                  statusText = 'DOWN';
                  gwIcon = Icons.cancel_outlined;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gwColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: gwColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.router_rounded, size: 16, color: gwColor),
                      const SizedBox(width: 6),
                      Text(
                        'Gateway ($gwIp):',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(gwIcon, size: 14, color: gwColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: gwColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        factory.expectedCidr ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Metrics row
            Row(
              children: [
                _MetricTile(
                  label: 'Devices',
                  value: '${devices.length}',
                  subtext: '$onlineCount on / $offlineCount off',
                  color: tokens.primary,
                ),
                const SizedBox(width: 8),
                _MetricTile(
                  label: 'Ranges',
                  value: '$enabledRanges / ${ranges.length}',
                  subtext: 'enabled',
                  color: tokens.factoryBnf,
                ),
                const SizedBox(width: 8),
                _MetricTile(
                  label: 'Alerts',
                  value: '$activeAlerts',
                  subtext: activeAlerts == 0 ? 'Normal' : 'Active',
                  color: activeAlerts > 0
                      ? tokens.statusOffline
                      : tokens.statusOnline,
                ),
                const SizedBox(width: 8),
                _MetricTile(
                  label: 'Scan Status',
                  value: latestScan != null
                      ? latestScan!.status.name.toUpperCase()
                      : 'NEVER',
                  subtext: latestScan != null
                      ? '${latestScan!.classifiedCount + latestScan!.unknownCount} assets'
                      : 'No scans',
                  color: tokens.textSecondary,
                ),
              ],
            ),
            const Spacer(),
            Divider(height: 1, color: tokens.cardBorder),
            const SizedBox(height: 8),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<FactoryCubit>().selectFactoryById(factory.id);
                    showDialog(
                      context: context,
                      builder: (_) => ManageNetworkRangesDialog(
                        isAdmin: isAdmin,
                        factoryId: factory.id,
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_ethernet, size: 14),
                  label: const Text('Manage Ranges'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<FactoryCubit>().selectFactoryById(factory.id);
                    final discoveryCubit = context
                        .read<NetworkDiscoveryCubit>();
                    final discoveryState = discoveryCubit.state;
                    final config = discoveryState is NetworkDiscoveryLoaded
                        ? discoveryState.config
                        : DiscoveryConfigEntity.initial();
                    showDialog(
                      context: context,
                      builder: (_) => DiscoveryStartDialog(
                        config: config,
                        ranges: ranges,
                        onStart:
                            ({
                              required ranges,
                              required strategies,
                              required concurrency,
                              required timeoutSeconds,
                            }) {
                              discoveryCubit.startScan(
                                factoryId: factory.id,
                                requestedRanges: ranges,
                                enabledStrategies: strategies,
                                maxConcurrency: concurrency,
                                timeoutSeconds: timeoutSeconds,
                              );
                            },
                      ),
                    );
                  },
                  icon: const Icon(Icons.radar, size: 14),
                  label: const Text('Start Discovery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primary,
                    foregroundColor: tokens.onPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: tokens.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtext,
              style: TextStyle(fontSize: 9, color: tokens.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
