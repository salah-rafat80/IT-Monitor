import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../domain/entities/topology_node.dart';

/// Hand-drawn Whiteboard style interactive Network Topology canvas & node map.
class HandDrawnTopologyCanvas extends StatefulWidget {
  final List<LocationNode> locations;
  final String searchQuery;

  const HandDrawnTopologyCanvas({
    super.key,
    required this.locations,
    this.searchQuery = '',
  });

  @override
  State<HandDrawnTopologyCanvas> createState() =>
      _HandDrawnTopologyCanvasState();
}

class _HandDrawnTopologyCanvasState extends State<HandDrawnTopologyCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final Set<String> _collapsedLocations = {};
  final Set<String> _collapsedSwitches = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleLocation(String locationName) {
    setState(() {
      if (_collapsedLocations.contains(locationName)) {
        _collapsedLocations.remove(locationName);
      } else {
        _collapsedLocations.add(locationName);
      }
    });
  }

  void _toggleSwitch(String key) {
    setState(() {
      if (_collapsedSwitches.contains(key)) {
        _collapsedSwitches.remove(key);
      } else {
        _collapsedSwitches.add(key);
      }
    });
  }

  void _showNodeDetails(
    BuildContext context,
    MonitoredDevice md,
    String locationName,
    String switchName,
  ) {
    final tokens = context.appTokens;
    final device = md.device;
    final status = md.status;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: tokens.border,
            width: 1.5,
          ),
        ),
        backgroundColor: tokens.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                device.type.name == 'laptop'
                    ? Icons.laptop_rounded
                    : Icons.desktop_windows_rounded,
                color: tokens.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayOwner,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    '${device.name} • ${device.department}',
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            DeviceStatusChip(
              status: status.status,
              isMaintenance: status.isMaintenance,
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(color: tokens.divider),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Assigned Person',
                value: device.displayOwner,
              ),
              _DetailRow(
                icon: Icons.business_outlined,
                label: 'Department',
                value: device.department,
              ),
              _DetailRow(
                icon: Icons.computer_outlined,
                label: 'Device Name',
                value: device.name,
              ),
              _DetailRow(
                icon: Icons.lan_outlined,
                label: 'IP Address',
                value: device.ip,
                isMonospace: true,
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: locationName,
              ),
              _DetailRow(
                icon: Icons.hub_outlined,
                label: 'Parent Switch',
                value: switchName,
              ),
              _DetailRow(
                icon: Icons.timer_outlined,
                label: 'Latency',
                value: status.lastLatencyMs != null
                    ? '${status.lastLatencyMs} ms'
                    : '—',
              ),
              _DetailRow(
                icon: Icons.history_outlined,
                label: 'Last Checked',
                value: status.lastCheckAt != null
                    ? dateFormat.format(status.lastCheckAt!)
                    : 'Not checked yet',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: TextStyle(color: tokens.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return CustomPaint(
      painter: WhiteboardGridPainter(
        dotColor: tokens.onSurface.withValues(alpha: tokens.isDark ? 0.07 : 0.04),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topology Legend & Status Summary Header
            _buildCanvasHeader(context),
            const SizedBox(height: 20),

            // Location Nodes Tree Diagram
            ...widget.locations.map(
              (loc) => _buildLocationCluster(context, loc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasHeader(BuildContext context) {
    final tokens = context.appTokens;

    int upCount = 0;
    int downCount = 0;
    int degradedCount = 0;
    int maintenanceCount = 0;

    for (final loc in widget.locations) {
      for (final dev in loc.allDevices) {
        if (dev.status.isMaintenance) {
          maintenanceCount++;
          continue;
        }
        switch (dev.status.effectiveStatus()) {
          case DeviceStatusEnum.up:
            upCount++;
            break;
          case DeviceStatusEnum.down:
          case DeviceStatusEnum.unreachable:
          case DeviceStatusEnum.unknown:
            downCount++;
            break;
          case DeviceStatusEnum.degraded:
          case DeviceStatusEnum.stale:
            degradedCount++;
            break;
          case DeviceStatusEnum.maintenance:
            maintenanceCount++;
            break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.card.withValues(alpha: tokens.isDark ? 0.9 : 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tokens.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: tokens.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Interactive Whiteboard Map',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusLegendBadge(
                    label: 'Up ($upCount)',
                    color: tokens.statusOnline,
                  ),
                  const SizedBox(width: 8),
                  _StatusLegendBadge(
                    label: 'Disconnected ($downCount)',
                    color: tokens.statusOffline,
                  ),
                  const SizedBox(width: 8),
                  _StatusLegendBadge(
                    label: 'Degraded ($degradedCount)',
                    color: tokens.statusDegraded,
                  ),
                  const SizedBox(width: 8),
                  _StatusLegendBadge(
                    label: 'Maintenance ($maintenanceCount)',
                    color: tokens.statusMaintenance,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCluster(BuildContext context, LocationNode loc) {
    final tokens = context.appTokens;
    final isCollapsed = _collapsedLocations.contains(loc.locationName);

    final downCount = loc.allDevices
        .where((d) => d.status.status == DeviceStatusEnum.down)
        .length;
    final hasIssues = downCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: tokens.isDark ? 0.85 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasIssues
              ? tokens.statusOffline.withValues(alpha: 0.7)
              : tokens.border,
          width: hasIssues ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasIssues ? tokens.statusOffline : tokens.shadow)
                .withValues(alpha: tokens.isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Cluster Main Header
          InkWell(
            onTap: () => _toggleLocation(loc.locationName),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tokens.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: tokens.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              loc.locationName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: tokens.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${loc.switchGroups.length} Switch Hub${loc.switchGroups.length == 1 ? "" : "s"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${loc.totalCount} Monitored Devices • ${loc.allDevices.length - downCount} Up / $downCount Down',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasIssues
                                ? tokens.statusOffline
                                : tokens.textSecondary,
                            fontWeight: hasIssues
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isCollapsed
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: tokens.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          if (!isCollapsed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: loc.switchGroups.map((sg) {
                  final switchKey = '${loc.locationName}_${sg.switchName}';
                  return _buildSwitchGroupHub(
                    context,
                    loc.locationName,
                    sg,
                    switchKey,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchGroupHub(
    BuildContext context,
    String locationName,
    SwitchGroup sg,
    String switchKey,
  ) {
    final tokens = context.appTokens;
    final isSwitchCollapsed = _collapsedSwitches.contains(switchKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Switch Hub Header Node
          InkWell(
            onTap: () => _toggleSwitch(switchKey),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sg.hasKnownSwitch
                      ? tokens.primary.withValues(alpha: 0.5)
                      : tokens.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sg.hasKnownSwitch
                        ? Icons.hub_rounded
                        : Icons.help_center_outlined,
                    size: 20,
                    color: sg.hasKnownSwitch ? tokens.primary : tokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sg.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: sg.hasKnownSwitch
                          ? tokens.primary
                          : tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${sg.devices.length} Devices',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSwitchCollapsed
                        ? Icons.arrow_drop_down
                        : Icons.arrow_drop_up,
                    color: tokens.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (!isSwitchCollapsed) ...[
            const SizedBox(height: 16),
            // Vector Diagram Network Wire & Monitor Nodes
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: sg.devices.map((md) {
                    return _VectorMonitorNodeCard(
                      monitoredDevice: md,
                      pulseAnimation: _pulseController,
                      onTap: () => _showNodeDetails(
                        context,
                        md,
                        locationName,
                        sg.displayName,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Vector Network Diagram PC Monitor Card (matching reference diagram style)
class _VectorMonitorNodeCard extends StatelessWidget {
  final MonitoredDevice monitoredDevice;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _VectorMonitorNodeCard({
    required this.monitoredDevice,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final device = monitoredDevice.device;
    final status = monitoredDevice.status;

    final isDown = status.status == DeviceStatusEnum.down;
    final isUp = status.status == DeviceStatusEnum.up;
    final isDegraded = status.status == DeviceStatusEnum.degraded;

    final statusColor = isDown
        ? tokens.statusOffline
        : (isUp
              ? tokens.statusOnline
              : (isDegraded
                    ? tokens.statusDegraded
                    : tokens.statusUnknown));

    final onScreenColor = isDown
        ? tokens.onStatusOffline
        : (isUp
              ? tokens.onStatusOnline
              : (isDegraded
                    ? tokens.onStatusDegraded
                    : tokens.onStatusUnknown));

    final latencyStr = status.lastLatencyMs != null
        ? '${status.lastLatencyMs} ms'
        : '-';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          final pulseVal = isDown ? pulseAnimation.value : 0.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Vector Monitor Body (Screen Frame + Screen Fill)
              Container(
                width: 170,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDown
                        ? Color.lerp(
                            tokens.statusOffline,
                            tokens.statusOffline.withValues(alpha: 0.6),
                            pulseVal,
                          )!
                        : statusColor.withValues(alpha: 0.8),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(
                        alpha: isDown ? (0.3 + (pulseVal * 0.3)) : 0.15,
                      ),
                      blurRadius: isDown ? 12 + (pulseVal * 6) : 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filled Display Screen (Vector Screen Box like reference image)
                    Container(
                      width: double.infinity,
                      height: 65,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDown ? (0.85 + (pulseVal * 0.15)) : 0.9,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            device.type.name == 'laptop'
                                ? Icons.laptop_windows_rounded
                                : Icons.desktop_windows_rounded,
                            size: 24,
                            color: onScreenColor,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            device.displayOwner,
                            style: TextStyle(
                              color: onScreenColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Device IP & Latency
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          device.ip,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          isDown ? 'Down' : latencyStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Monitor Stand Neck
              Container(
                width: 16,
                height: 8,
                color: statusColor.withValues(alpha: 0.6),
              ),

              // 3. Monitor Base Stand
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusLegendBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusLegendBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isMonospace;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: isMonospace ? 'monospace' : null,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for Whiteboard Grid Background Pattern
class WhiteboardGridPainter extends CustomPainter {
  final Color dotColor;

  WhiteboardGridPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = dotColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardGridPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
}
