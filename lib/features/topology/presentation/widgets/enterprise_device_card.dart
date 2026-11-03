import 'package:flutter/material.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';

/// Enterprise Device Card matching enterprise NMS layout topology diagrams.
///
/// Features:
/// - Pure white rectangular card with rounded corners and subtle elevation.
/// - Border color communicating device state (Green = Up, Red = Down, Amber = Degraded, Gray = Unknown).
/// - Top icon with category-tailored visual badge.
/// - Prominent device name with overflow protection.
/// - Monospace IP address / secondary identifier.
/// - Blue numeric port count badge on switch nodes showing active downstream connections.
/// - Latency / health indicator pill.
/// - Interactive hover and click handlers.
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
    DeviceStatusEnum status, {
    bool isTransitional = false,
  }) {
    if (isTransitional) {
      return const Color(0xFFF59E0B); // Warning Amber for 1/3 or 2/3 failing
    }
    switch (status) {
      case DeviceStatusEnum.up:
        return const Color(0xFF10B981); // Emerald Green
      case DeviceStatusEnum.down:
      case DeviceStatusEnum.unreachable:
        return const Color(0xFFEF4444); // Alert Red
      case DeviceStatusEnum.unknown:
        return const Color(0xFF94A3B8); // Neutral Slate
      case DeviceStatusEnum.degraded:
        return const Color(0xFFF59E0B); // Warning Amber
      case DeviceStatusEnum.stale:
        return const Color(0xFFEAB308); // Stale Amber
      case DeviceStatusEnum.maintenance:
        return const Color(0xFF64748B); // Slate
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

  Color _getCategoryThemeColor(TopologyDeviceCategory category) {
    switch (category) {
      case TopologyDeviceCategory.wan:
        return const Color(0xFF818CF8); // Indigo
      case TopologyDeviceCategory.gateway:
        return const Color(0xFF38BDF8); // Sky Blue
      case TopologyDeviceCategory.switchDevice:
        return const Color(0xFF2DD4BF); // Teal
      case TopologyDeviceCategory.accessPoint:
        return const Color(0xFF34D399); // Emerald
      case TopologyDeviceCategory.controller:
        return const Color(0xFFA78BFA); // Purple
      case TopologyDeviceCategory.server:
        return const Color(0xFFFB923C); // Orange
      case TopologyDeviceCategory.pc:
      case TopologyDeviceCategory.laptop:
        return const Color(0xFF60A5FA); // Royal Blue
      case TopologyDeviceCategory.printer:
        return const Color(0xFF94A3B8); // Slate
      case TopologyDeviceCategory.camera:
        return const Color(0xFF10B981); // Forest
      case TopologyDeviceCategory.other:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransitional = widget.node.isTransitionalFailing;
    final statusColor = _getStatusColor(
      widget.node.status,
      isTransitional: isTransitional,
    );
    final themeColor = _getCategoryThemeColor(widget.node.category);
    final hasPortBadge =
        widget.node.category == TopologyDeviceCategory.switchDevice &&
        widget.node.activePortCount != null &&
        widget.node.activePortCount! > 0;

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
            color: const Color(0xFF1E293B), // Dark surface slate 800
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF3B82F6)
                  : widget.isHighlighted
                  ? const Color(0xFF60A5FA)
                  : (_isHovered
                        ? statusColor.withValues(alpha: 0.9)
                        : statusColor.withValues(alpha: 0.55)),
              width: widget.isSelected ? 2.0 : (_isHovered ? 1.6 : 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.2),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Row 1: Icon + Category Tag + Status Dot
                    Row(
                      children: [
                        // Category Icon in subtle soft badge
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            _getCategoryIcon(widget.node.category),
                            size: 12,
                            color: themeColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        // Category short label
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
                        // Status Indicator Dot & Pulse / Transitional Badge
                        if (isTransitional)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              '${widget.node.consecutiveFailures}/3 FAIL',
                              style: const TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF59E0B),
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
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Row 2: Device Title
                    Text(
                      widget.node.title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF8FAFC), // White / Slate 50
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Row 3: Subtitle / Monospace IP & Health Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // IP Address or Subtitle
                        Expanded(
                          child: Text(
                            widget.node.subtitle ?? widget.node.ip ?? '--',
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8), // Slate 400
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Latency pill if available
                        if (widget.node.lastLatencyMs != null &&
                            widget.node.lastLatencyMs! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Text(
                              '${widget.node.lastLatencyMs}ms',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Port Count Badge for Switch Nodes (Ruijie/Enterprise Style) ─
              if (hasPortBadge)
                Positioned(
                  top: -7,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7), // Blue numeric badge
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF0F172A),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cable_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${widget.node.activePortCount}p',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

extension on EnterpriseTopologyNode {
  String? get ip => subtitle ?? deviceRef?.ip ?? infraRef?.ip;
}
