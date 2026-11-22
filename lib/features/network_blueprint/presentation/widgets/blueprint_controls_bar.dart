import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class BlueprintControlsBar extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitToScreen;
  final VoidCallback onResetView;
  final VoidCallback? onCenterSelected;
  final bool isLiveMonitoringActive;
  final VoidCallback onToggleLiveMonitoring;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const BlueprintControlsBar({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitToScreen,
    required this.onResetView,
    this.onCenterSelected,
    required this.isLiveMonitoringActive,
    required this.onToggleLiveMonitoring,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(
            color: tokens.cardBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: onSearchChanged,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search elements, devices, or IP addresses...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: tokens.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => onSearchChanged(''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  filled: true,
                  fillColor: tokens.surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Live Monitoring Toggle Pill
          InkWell(
            onTap: onToggleLiveMonitoring,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isLiveMonitoringActive
                    ? tokens.statusOnline.withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLiveMonitoringActive
                      ? tokens.statusOnline.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLiveMonitoringActive
                          ? tokens.statusOnline
                          : (isDark ? Colors.grey : Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLiveMonitoringActive ? 'Live Telemetry' : 'Telemetry Paused',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isLiveMonitoringActive
                          ? tokens.statusOnline
                          : (tokens.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Viewport Controls
          _IconButton(
            icon: Icons.zoom_in,
            tooltip: 'Zoom In',
            isDark: isDark,
            onPressed: onZoomIn,
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.zoom_out,
            tooltip: 'Zoom Out',
            isDark: isDark,
            onPressed: onZoomOut,
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.fullscreen_exit,
            tooltip: 'Fit to Screen',
            isDark: isDark,
            onPressed: onFitToScreen,
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.refresh,
            tooltip: 'Reset View',
            isDark: isDark,
            onPressed: onResetView,
          ),

          if (onCenterSelected != null) ...[
            const SizedBox(width: 4),
            _IconButton(
              icon: Icons.center_focus_strong,
              tooltip: 'Center on Selection',
              isDark: isDark,
              onPressed: onCenterSelected!,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onPressed;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      color: tokens.textPrimary,
      onPressed: onPressed,
    );
  }
}
