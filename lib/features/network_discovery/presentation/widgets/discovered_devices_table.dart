import 'package:flutter/material.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/theme/app_colors.dart';

import '../../domain/entities/classification_confidence.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/review_state.dart';

class DiscoveredDevicesTable extends StatelessWidget {
  final List<DiscoveredDeviceEntity> devices;
  final bool isAdmin;
  final ValueChanged<DiscoveredDeviceEntity> onViewEvidence;
  final ValueChanged<DiscoveredDeviceEntity> onApprove;
  final ValueChanged<DiscoveredDeviceEntity> onReject;
  final Function(DiscoveredDeviceEntity device, DeviceCategory newCategory)
  onOverrideCategory;
  final VoidCallback? onLaunchScan;

  const DiscoveredDevicesTable({
    super.key,
    required this.devices,
    this.isAdmin = true,
    required this.onViewEvidence,
    required this.onApprove,
    required this.onReject,
    required this.onOverrideCategory,
    this.onLaunchScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    if (devices.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: AppEmptyState(
          icon: Icons.radar_rounded,
          title: 'No Discovered Assets Found',
          message:
              'Run a discovery scan over the authorized scopes or adjust your filter query.',
          actionLabel: onLaunchScan != null ? 'Launch Discovery Scan' : null,
          onAction: onLaunchScan,
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        d.hostname ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  // 3. MAC
                  DataCell(
                    Text(
                      d.mac ?? '-',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  // 4. Vendor
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        d.vendor ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
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
                          color: _categoryColor(cat, tokens),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor(cat, tokens),
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
                          tokens,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        d.confidence.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _confidenceColor(d.confidence, tokens),
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
                          tokens,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.reviewState.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _reviewColor(d.reviewState, tokens),
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
                            icon: Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: tokens.statusOnline,
                            ),
                            tooltip: 'Approve Asset',
                            onPressed: () => onApprove(d),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: tokens.statusOffline,
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

  Color _categoryColor(DeviceCategory cat, AppColors tokens) {
    switch (cat) {
      case DeviceCategory.pc:
      case DeviceCategory.laptop:
        return tokens.primary;
      case DeviceCategory.ipCamera:
        return tokens.secondary;
      case DeviceCategory.printer:
        return tokens.accent;
      case DeviceCategory.server:
        return tokens.primary;
      case DeviceCategory.switchDevice:
      case DeviceCategory.router:
      case DeviceCategory.wirelessAccessPoint:
      case DeviceCategory.otherNetworkDevice:
        return tokens.statusDegraded;
      case DeviceCategory.mobile:
        return tokens.onSurfaceVariant;
      case DeviceCategory.other:
      case DeviceCategory.unknown:
        return tokens.disabled;
    }
  }

  Color _confidenceColor(ClassificationConfidence c, AppColors tokens) {
    switch (c) {
      case ClassificationConfidence.high:
        return tokens.statusOnline;
      case ClassificationConfidence.medium:
        return tokens.statusDegraded;
      case ClassificationConfidence.low:
      case ClassificationConfidence.unknown:
        return tokens.disabled;
    }
  }

  Color _reviewColor(ReviewState s, AppColors tokens) {
    switch (s) {
      case ReviewState.pendingReview:
        return tokens.statusDegraded;
      case ReviewState.approved:
        return tokens.statusOnline;
      case ReviewState.alreadyKnown:
        return tokens.primary;
      case ReviewState.rejected:
        return tokens.disabled;
      case ReviewState.conflict:
        return tokens.statusOffline;
      case ReviewState.needsMoreEvidence:
        return tokens.secondary;
    }
  }
}
