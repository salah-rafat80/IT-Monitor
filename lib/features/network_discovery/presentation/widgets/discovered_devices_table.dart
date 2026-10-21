import 'package:flutter/material.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/classification_confidence.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/review_state.dart';

class DiscoveredDevicesTable extends StatelessWidget {
  final List<DiscoveredDeviceEntity> devices;
  final UserRole userRole;
  final ValueChanged<DiscoveredDeviceEntity> onViewEvidence;
  final ValueChanged<DiscoveredDeviceEntity> onApprove;
  final ValueChanged<DiscoveredDeviceEntity> onReject;
  final Function(DiscoveredDeviceEntity device, DeviceCategory newCategory)
  onOverrideCategory;
  final VoidCallback? onLaunchScan;

  const DiscoveredDevicesTable({
    super.key,
    required this.devices,
    required this.userRole,
    required this.onViewEvidence,
    required this.onApprove,
    required this.onReject,
    required this.onOverrideCategory,
    this.onLaunchScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = userRole == UserRole.admin;

    if (devices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.radar_rounded, size: 48, color: theme.disabledColor),
            const SizedBox(height: 16),
            const Text(
              'No Discovered Assets Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Run a discovery scan over the authorized scopes or adjust your filter query.',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            if (onLaunchScan != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onLaunchScan,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Launch Discovery Scan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.primaryColor.withValues(alpha: 0.04),
            ),
            horizontalMargin: 20,
            columnSpacing: 20,
            columns: const [
              DataColumn(
                label: Text(
                  'IP Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Hostname',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'MAC Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Manufacturer / OUI',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Classification',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Confidence',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Review State',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: devices.map((d) {
              final cat = d.effectiveCategory;
              final isKnown = d.reviewState == ReviewState.alreadyKnown;
              final isApproved = d.reviewState == ReviewState.approved;

              return DataRow(
                cells: [
                  // 1. IP Address
                  DataCell(
                    Text(
                      d.ip,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // 2. Hostname
                  DataCell(
                    Text(
                      d.hostname ?? '-',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  // 3. MAC
                  DataCell(
                    Text(
                      d.mac ?? '-',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // 4. Vendor
                  DataCell(
                    Text(
                      d.vendor ?? '-',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 5. Category (Icon + Label + Override menu)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcon(cat),
                          size: 16,
                          color: _categoryColor(cat),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor(cat),
                          ),
                        ),
                        if (isAdmin && !isKnown)
                          PopupMenuButton<DeviceCategory>(
                            icon: const Icon(Icons.arrow_drop_down, size: 16),
                            tooltip: 'Override Classification',
                            onSelected: (newCat) =>
                                onOverrideCategory(d, newCat),
                            itemBuilder: (_) => DeviceCategory.values
                                .map(
                                  (c) => PopupMenuItem(
                                    value: c,
                                    child: Text(
                                      c.displayName,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  // 6. Confidence
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _confidenceColor(
                          d.confidence,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        d.confidence.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _confidenceColor(d.confidence),
                        ),
                      ),
                    ),
                  ),
                  // 7. Review State
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _reviewColor(
                          d.reviewState,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.reviewState.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _reviewColor(d.reviewState),
                        ),
                      ),
                    ),
                  ),
                  // 8. Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.fingerprint_rounded, size: 18),
                          tooltip: 'View Fingerprint Evidence',
                          onPressed: () => onViewEvidence(d),
                        ),
                        if (isAdmin && !isKnown && !isApproved) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                            tooltip: 'Approve Asset',
                            onPressed: () => onApprove(d),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: Colors.red,
                            ),
                            tooltip: 'Reject',
                            onPressed: () => onReject(d),
                          ),
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
    );
  }

  IconData _categoryIcon(DeviceCategory cat) {
    switch (cat) {
      case DeviceCategory.pc:
        return Icons.desktop_windows_rounded;
      case DeviceCategory.laptop:
        return Icons.laptop_windows_rounded;
      case DeviceCategory.mobile:
        return Icons.smartphone_rounded;
      case DeviceCategory.ipCamera:
        return Icons.videocam_rounded;
      case DeviceCategory.printer:
        return Icons.print_rounded;
      case DeviceCategory.server:
        return Icons.dns_rounded;
      case DeviceCategory.switchDevice:
        return Icons.hub_rounded;
      case DeviceCategory.router:
        return Icons.router_rounded;
      case DeviceCategory.wirelessAccessPoint:
        return Icons.wifi_rounded;
      case DeviceCategory.otherNetworkDevice:
        return Icons.device_hub_rounded;
      case DeviceCategory.other:
      case DeviceCategory.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color _categoryColor(DeviceCategory cat) {
    switch (cat) {
      case DeviceCategory.pc:
      case DeviceCategory.laptop:
        return const Color(0xFF0F62FE);
      case DeviceCategory.ipCamera:
        return Colors.purple;
      case DeviceCategory.printer:
        return Colors.teal;
      case DeviceCategory.server:
        return Colors.indigo;
      case DeviceCategory.switchDevice:
      case DeviceCategory.router:
      case DeviceCategory.wirelessAccessPoint:
      case DeviceCategory.otherNetworkDevice:
        return Colors.amber.shade800;
      case DeviceCategory.mobile:
        return Colors.blueGrey;
      case DeviceCategory.other:
      case DeviceCategory.unknown:
        return Colors.grey;
    }
  }

  Color _confidenceColor(ClassificationConfidence c) {
    switch (c) {
      case ClassificationConfidence.high:
        return const Color(0xFF10B981);
      case ClassificationConfidence.medium:
        return Colors.orange;
      case ClassificationConfidence.low:
      case ClassificationConfidence.unknown:
        return Colors.grey;
    }
  }

  Color _reviewColor(ReviewState s) {
    switch (s) {
      case ReviewState.pendingReview:
        return Colors.orange;
      case ReviewState.approved:
        return const Color(0xFF10B981);
      case ReviewState.alreadyKnown:
        return const Color(0xFF0F62FE);
      case ReviewState.rejected:
        return Colors.grey;
      case ReviewState.conflict:
        return Colors.red;
      case ReviewState.needsMoreEvidence:
        return Colors.purple;
    }
  }
}
