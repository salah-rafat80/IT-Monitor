import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/entities/monitored_device.dart';
import '../../../monitoring/presentation/widgets/device_status_chip.dart';
import '../../domain/entities/topology_node.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Location Group Card
// ──────────────────────────────────────────────────────────────────────────────

class LocationGroupCard extends StatefulWidget {
  final LocationNode location;
  final bool initiallyExpanded;

  const LocationGroupCard({
    super.key,
    required this.location,
    this.initiallyExpanded = true,
  });

  @override
  State<LocationGroupCard> createState() => _LocationGroupCardState();
}

class _LocationGroupCardState extends State<LocationGroupCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Color _locationHeaderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkSurface : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalDevices = widget.location.totalCount;
    final downCount = widget.location.allDevices
        .where((d) => d.status.status == DeviceStatusEnum.down)
        .length;
    final hasIssues = downCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _locationHeaderColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasIssues
              ? AppColors.statusDown.withValues(alpha: 0.4)
              : isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
          width: hasIssues ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Location Header ──
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Location icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Location name + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.location.locationName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '$totalDevices device${totalDevices == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            if (hasIssues) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.statusDown.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$downCount down',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.statusDown,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Switch count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.location.switchGroups.length} switch${widget.location.switchGroups.length == 1 ? '' : 'es'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Animated Body ──
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: widget.location.switchGroups
                    .map((sg) => SwitchGroupWidget(switchGroup: sg))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Switch Group Widget
// ──────────────────────────────────────────────────────────────────────────────

class SwitchGroupWidget extends StatelessWidget {
  final SwitchGroup switchGroup;

  const SwitchGroupWidget({super.key, required this.switchGroup});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Switch header row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Vertical connector line
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  switchGroup.hasKnownSwitch
                      ? Icons.device_hub_rounded
                      : Icons.help_outline_rounded,
                  size: 16,
                  color: switchGroup.hasKnownSwitch
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
                const SizedBox(width: 6),
                Text(
                  switchGroup.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: switchGroup.hasKnownSwitch
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${switchGroup.devices.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                // "Metadata only" badge — never monitored
                if (!switchGroup.hasKnownSwitch)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusMaintenance.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'no switch data',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.statusMaintenance,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Device rows
          ...switchGroup.devices.map(
            (md) => TopologyDeviceRow(monitoredDevice: md),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Topology Device Row
// ──────────────────────────────────────────────────────────────────────────────

class TopologyDeviceRow extends StatelessWidget {
  final MonitoredDevice monitoredDevice;

  const TopologyDeviceRow({super.key, required this.monitoredDevice});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final device = monitoredDevice.device;
    final status = monitoredDevice.status;

    return Container(
      margin: const EdgeInsets.only(left: 28, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.6)
            : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Device type icon
          Icon(
            device.type.name == 'laptop'
                ? Icons.laptop_rounded
                : Icons.computer_rounded,
            size: 16,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 10),
          // Owner + department (primary identity)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayOwner,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: device.isOwnerAssigned
                        ? (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                        : Colors.orangeAccent,
                    fontStyle: device.isOwnerAssigned
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  device.department,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Device name + IP
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  device.ip,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark
                        ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                        : AppColors.textSecondaryLight.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Status chip
          DeviceStatusChip(
            status: status.status,
            isMaintenance: status.isMaintenance,
            compact: true,
          ),
          // Latency
          if (status.lastLatencyMs != null) ...[
            const SizedBox(width: 8),
            Text(
              '${status.lastLatencyMs} ms',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
