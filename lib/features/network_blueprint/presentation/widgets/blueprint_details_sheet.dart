import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/blueprint_element_entity.dart';

class BlueprintDetailsSheet extends StatelessWidget {
  final BlueprintElementEntity element;
  final VoidCallback onClose;
  final VoidCallback? onCenterOnCanvas;

  const BlueprintDetailsSheet({
    super.key,
    required this.element,
    required this.onClose,
    this.onCenterOnCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          left: BorderSide(
            color: tokens.cardBorder,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context, tokens, isDark),
          const Divider(height: 1),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCategoryBanner(tokens, isDark),
                const SizedBox(height: 16),

                // Live Telemetry / Monitoring Section
                if (element.liveStatus != null) ...[
                  _buildLiveStatusCard(tokens, isDark),
                  const SizedBox(height: 16),
                ],

                // Matched Inventory Section
                if (element.mappedDeviceId != null || element.mappedIp != null) ...[
                  _buildInventoryCard(tokens, isDark),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildUnmappedCard(tokens, isDark),
                  const SizedBox(height: 16),
                ],

                // Blueprint Technical Properties
                _buildBlueprintPropertiesCard(tokens, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors tokens, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _getCategoryIcon(element.category, tokens, isDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                Text(
                  element.displayTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID: ${element.id}',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onCenterOnCanvas != null)
            IconButton(
              icon: const Icon(Icons.center_focus_strong, size: 18),
              tooltip: 'Focus on Canvas',
              visualDensity: VisualDensity.compact,
              splashRadius: 16,
              onPressed: onCenterOnCanvas,
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close Details',
            visualDensity: VisualDensity.compact,
            splashRadius: 16,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBanner(AppColors tokens, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.category_outlined,
            size: 16,
            color: tokens.second,
          ),
          const SizedBox(width: 8),
          Text(
            element.category.displayName,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard(AppColors tokens, bool isDark) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (element.liveStatus!) {
      case DeviceStatusEnum.up:
        statusColor = tokens.statusOnline;
        statusLabel = 'ONLINE';
        statusIcon = Icons.check_circle_outline;
        break;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        statusColor = tokens.statusOffline;
        statusLabel = 'OFFLINE';
        statusIcon = Icons.error_outline;
        break;
      case DeviceStatusEnum.degraded:
      case DeviceStatusEnum.stale:
        statusColor = tokens.statusDegraded;
        statusLabel = 'DEGRADED';
        statusIcon = Icons.warning_amber_outlined;
        break;
      case DeviceStatusEnum.maintenance:
        statusColor = tokens.statusMaintenance;
        statusLabel = 'MAINTENANCE';
        statusIcon = Icons.build_outlined;
        break;
      case DeviceStatusEnum.unknown:
        statusColor = tokens.statusUnknown;
        statusLabel = 'UNKNOWN';
        statusIcon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                'LIVE TELEMETRY: $statusLabel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (element.lastLatencyMs != null) ...[
            const SizedBox(height: 8),
            _buildDataRow('Ping Latency', '${element.lastLatencyMs} ms', tokens, isDark,
              highlightValue: true,
            ),
          ],
          if (element.lastCheckAt != null) ...[
            const SizedBox(height: 4),
            _buildDataRow('Last Polled', _formatTimestamp(element.lastCheckAt!), tokens, isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryCard(AppColors tokens, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                size: 16,
                color: tokens.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Matched Inventory Record',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (element.mappedDeviceName != null)
            _buildDataRow('Device Name', element.mappedDeviceName!, tokens, isDark),
          if (element.mappedIp != null)
            _buildDataRow('IP Address', element.mappedIp!, tokens, isDark),
          _buildDataRow('Mapping Status', element.mappingConfidence.displayName, tokens, isDark),
        ],
      ),
    );
  }

  Widget _buildUnmappedCard(AppColors tokens, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.cardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: tokens.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Architectural Blueprint Element. Live ping telemetry is only active for devices registered in the inventory database.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueprintPropertiesCard(AppColors tokens, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blueprint Properties',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildDataRow('Dimensions', '${element.bounds.width.toStringAsFixed(0)} × ${element.bounds.height.toStringAsFixed(0)} px', tokens, isDark,
          ),
          _buildDataRow('Position', '(${element.bounds.left.toStringAsFixed(0)}, ${element.bounds.top.toStringAsFixed(0)})', tokens, isDark,
          ),
          if (element.rawLabel.isNotEmpty && element.rawLabel != element.englishLabel)
            _buildDataRow('Original Diagram Text', element.rawLabel, tokens, isDark),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    String label,
    String value,
    AppColors tokens,
    bool isDark, {
    bool highlightValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: tokens.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: highlightValue ? FontWeight.w700 : FontWeight.w500,
                color: highlightValue
                    ? (tokens.primary)
                    : (tokens.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCategoryIcon(BlueprintElementCategory cat, AppColors tokens, bool isDark) {
    IconData icon;
    Color color;

    switch (cat) {
      case BlueprintElementCategory.switchDevice:
        icon = Icons.hub;
        color = const Color(0xFF00E5FF);
        break;
      case BlueprintElementCategory.server:
        icon = Icons.dns;
        color = const Color(0xFFA78BFA);
        break;
      case BlueprintElementCategory.workstation:
        icon = Icons.computer;
        color = const Color(0xFF10B981);
        break;
      case BlueprintElementCategory.laptop:
        icon = Icons.laptop;
        color = const Color(0xFF38BDF8);
        break;
      case BlueprintElementCategory.wallDrop:
        icon = Icons.settings_ethernet;
        color = const Color(0xFFF59E0B);
        break;
      case BlueprintElementCategory.telephony:
        icon = Icons.phone_in_talk;
        color = const Color(0xFFEC4899);
        break;
      case BlueprintElementCategory.security:
        icon = Icons.videocam;
        color = const Color(0xFFEF4444);
        break;
      case BlueprintElementCategory.room:
      case BlueprintElementCategory.office:
        icon = Icons.meeting_room;
        color = const Color(0xFF94A3B8);
        break;
      case BlueprintElementCategory.generic:
        icon = Icons.crop_square;
        color = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
