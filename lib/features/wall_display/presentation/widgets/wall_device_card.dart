import 'package:flutter/material.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../../../core/theme/app_colors.dart';

class WallDeviceCard extends StatelessWidget {
  final MonitoredDevice item;

  const WallDeviceCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    Color statusColor;
    switch (item.status.status) {
      case DeviceStatusEnum.up:
        statusColor = tokens.statusOnline;
        break;
      case DeviceStatusEnum.degraded:
        statusColor = tokens.statusDegraded;
        break;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unknown:
      case DeviceStatusEnum.unreachable:
        statusColor = tokens.statusOffline;
        break;
      case DeviceStatusEnum.maintenance:
        statusColor = tokens.statusMaintenance;
        break;
    }

    final isCritical =
        item.status.status == DeviceStatusEnum.down ||
        item.status.status == DeviceStatusEnum.unknown ||
        item.status.status == DeviceStatusEnum.unreachable ||
        item.status.status == DeviceStatusEnum.degraded;

    return Container(
      decoration: BoxDecoration(
        color: isCritical
            ? statusColor.withValues(alpha: 0.12)
            : tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCritical ? statusColor : tokens.cardBorder,
          width: isCritical ? 2.0 : 1.0,
        ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: tokens.isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : tokens.shadowColor.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message:
            '${item.device.name} (${item.device.ip})\n'
            'Owner: ${item.device.displayOwner}\n'
            'Dept: ${item.device.department} • ${item.device.officeLocation ?? "N/A"}\n'
            'Status: ${item.status.status.name.toUpperCase()}\n'
            'Current Latency: ${item.status.lastLatencyMs != null ? item.status.displayLatency : "Unavailable"}\n'
            'Last Successful Latency: ${item.status.lastSuccessfulLatencyMs != null ? "${item.status.lastSuccessfulLatencyMs} ms (Historical)" : "None"}\n'
            'Last Seen: ${item.status.lastSeen != null ? item.status.lastSeen.toString().split(".")[0] : "Never"}'
            '${item.status.lastFailureReason != null ? "\nFailure: ${item.status.lastFailureReason}" : ""}',
        child: LayoutBuilder(
          builder: (context, cardConstraints) {
            return SizedBox(
              width: cardConstraints.maxWidth,
              height: cardConstraints.maxHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: cardConstraints.maxWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Owner Name & Status Chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.device.displayOwner,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: item.device.isOwnerAssigned
                                    ? tokens.textPrimary
                                    : tokens.statusDegraded,
                                fontStyle: item.device.isOwnerAssigned
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          DeviceStatusChip(
                            status: item.status.status,
                            compact: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 1),

                      // Department & Location
                      Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 11,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${item.device.department} • ${item.device.officeLocation ?? "N/A"}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: tokens.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 1),

                      // Bottom Row: Device Name, IP, and Latency
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Device Name & IP
                          Expanded(
                            child: Text(
                              '${item.device.name} (${item.device.ip})',
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: tokens.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Current Latency Badge (strictly only displayed when current check latency is available)
                          if ((item.status.status == DeviceStatusEnum.up ||
                                  item.status.status ==
                                      DeviceStatusEnum.degraded) &&
                              item.status.lastLatencyMs != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSecondary,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: tokens.cardBorder.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                item.status.isSubMillisecond
                                    ? '≤1ms'
                                    : '${item.status.lastLatencyMs}ms',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: item.status.lastLatencyMs! > 150
                                      ? tokens.statusDegraded
                                      : tokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
