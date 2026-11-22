import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';

/// Enterprise Device Card matching enterprise NMS layout topology diagrams.
class EnterpriseDeviceCard extends StatefulWidget {
  final EnterpriseTopologyNode node;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const EnterpriseDeviceCard({
    super.key,
    required this.node,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  State<EnterpriseDeviceCard> createState() => _EnterpriseDeviceCardState();
}

class _EnterpriseDeviceCardState extends State<EnterpriseDeviceCard> {
  bool _isHovered = false;

  Color _getStatusColor(
    DeviceStatusEnum status,
    AppColors tokens, {
    bool isTransitional = false,
  }) {
    if (isTransitional) {
      return tokens.statusDegraded;
    }
    switch (status) {
      case DeviceStatusEnum.up:
        return tokens.statusOnline;
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        return tokens.statusOffline;
      case DeviceStatusEnum.unknown:
        return tokens.statusUnknown;
      case DeviceStatusEnum.degraded:
      case DeviceStatusEnum.stale:
        return tokens.statusDegraded;
      case DeviceStatusEnum.maintenance:
        return tokens.statusMaintenance;
    }
  }

  IconData _getCategoryIcon(TopologyDeviceCategory category) {
    switch (category) {
      case TopologyDeviceCategory.wan:
        return Icons.public_rounded;
      case TopologyDeviceCategory.gateway:
        return Icons.router_rounded;
      case TopologyDeviceCategory.switchDevice:
        return Icons.hub_rounded;
      case TopologyDeviceCategory.accessPoint:
        return Icons.wifi_rounded;
      case TopologyDeviceCategory.controller:
        return Icons.settings_input_composite_rounded;
      case TopologyDeviceCategory.server:
        return Icons.dns_rounded;
      case TopologyDeviceCategory.pc:
        return Icons.desktop_windows_rounded;
      case TopologyDeviceCategory.laptop:
        return Icons.laptop_rounded;
      case TopologyDeviceCategory.printer:
        return Icons.print_rounded;
      case TopologyDeviceCategory.camera:
        return Icons.videocam_rounded;
      case TopologyDeviceCategory.other:
        return Icons.devices_other_rounded;
    }
  }

  Color _getCategoryThemeColor(TopologyDeviceCategory category, AppColors tokens) {
    switch (category) {
      case TopologyDeviceCategory.wan:
        return tokens.primary;
      case TopologyDeviceCategory.gateway:
        return tokens.primary;
      case TopologyDeviceCategory.switchDevice:
        return tokens.accent;
      case TopologyDeviceCategory.accessPoint:
        return tokens.statusOnline;
      case TopologyDeviceCategory.controller:
        return tokens.statusMaintenance;
      case TopologyDeviceCategory.server:
        return tokens.statusDegraded;
      case TopologyDeviceCategory.pc:
        return tokens.primary;
      case TopologyDeviceCategory.laptop:
        return tokens.statusMaintenance;
      case TopologyDeviceCategory.printer:
        return tokens.onSurfaceVariant;
      case TopologyDeviceCategory.camera:
        return tokens.accent;
      case TopologyDeviceCategory.other:
        return tokens.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isTransitional =
        widget.node.consecutiveFailures > 0 &&
        widget.node.consecutiveFailures < widget.node.failureThreshold &&
        widget.node.status != DeviceStatusEnum.down;

    final statusColor = _getStatusColor(
      widget.node.status,
      tokens,
      isTransitional: isTransitional,
    );

    final themeColor = _getCategoryThemeColor(widget.node.category, tokens);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.node.size.width,
          height: widget.node.size.height,
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: widget.isSelected
                  ? tokens.accent
                  : widget.isHighlighted
                      ? tokens.primary
                      : (_isHovered
                          ? statusColor.withValues(alpha: 0.9)
                          : statusColor.withValues(alpha: 0.55)),
              width: widget.isSelected ? 2.0 : (_isHovered ? 1.6 : 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                blurRadius: _isHovered ? 8 : 4,
                offset: Offset(0, _isHovered ? 3 : 1.5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main Card Content ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Row 1: Icon + Category Tag + Status Dot
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(3.5),
                          ),
                          child: Icon(
                            _getCategoryIcon(widget.node.category),
                            size: 11,
                            color: themeColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.node.category.shortName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: themeColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTransitional)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.statusDegradedSurface,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: tokens.onStatusDegraded.withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '${widget.node.consecutiveFailures}/${widget.node.failureThreshold} FAIL',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: tokens.onStatusDegraded,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    // Row 2: Device Title
                    Text(
                      widget.node.title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.onCard,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Row 3: IP Address & Subtitle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.node.subtitle ?? '',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                              color: tokens.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.node.lastLatencyMs != null)
                          Text(
                            '${widget.node.lastLatencyMs}ms',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: widget.node.lastLatencyMs! > 100
                                  ? tokens.statusDegraded
                                  : tokens.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Downstream Active Link Count Badge ─────────────────────────
              if (widget.node.category == TopologyDeviceCategory.switchDevice &&
                  (widget.node.activePortCount ?? 0) > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: tokens.card, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.shadow,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.node.activePortCount ?? 0}',
                      style: TextStyle(
                        color: tokens.onPrimary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
