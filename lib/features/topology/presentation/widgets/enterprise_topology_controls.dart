import 'package:flutter/material.dart';

/// Floating left-side vertical canvas controls toolbar.
///
/// Features:
/// - Fit to view (auto-centers and scales the entire topology to fit window).
/// - Zoom in (+).
/// - Current zoom percentage display badge (e.g. 100%, 75%).
/// - Zoom out (-).
/// - Reset zoom (100%).
/// - Diagram options / filter toggle.
/// - Help / Legend dialog.
class EnterpriseTopologyControls extends StatelessWidget {
  final double currentZoom;
  final VoidCallback onFitToView;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final VoidCallback? onOptions;
  final VoidCallback? onHelp;

  const EnterpriseTopologyControls({
    super.key,
    required this.currentZoom,
    required this.onFitToView,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.onOptions,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (currentZoom * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fit-to-View
          _ControlButton(
            icon: Icons.fullscreen_rounded,
            tooltip: 'Fit Topology to Screen',
            onPressed: onFitToView,
          ),
          const _ControlDivider(),

          // Zoom In
          _ControlButton(
            icon: Icons.add_rounded,
            tooltip: 'Zoom In (Ctrl + Scroll Up)',
            onPressed: onZoomIn,
          ),

          // Zoom Percentage Display (clickable to reset to 100%)
          Tooltip(
            message: 'Current Zoom (Click to reset to 100%)',
            child: InkWell(
              onTap: onResetZoom,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                width: 44,
                alignment: Alignment.center,
                child: Text(
                  '$zoomPercent%',
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
              ),
            ),
          ),

          // Zoom Out
          _ControlButton(
            icon: Icons.remove_rounded,
            tooltip: 'Zoom Out (Ctrl + Scroll Down)',
            onPressed: onZoomOut,
          ),
          const _ControlDivider(),

          // Diagram Options
          if (onOptions != null) ...[
            _ControlButton(
              icon: Icons.tune_rounded,
              tooltip: 'Display Options',
              onPressed: onOptions,
            ),
            const _ControlDivider(),
          ],

          // Help / Legend
          if (onHelp != null)
            _ControlButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'Topology Legend & Hotkeys',
              onPressed: onHelp,
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        icon: Icon(icon, size: 19, color: const Color(0xFF94A3B8)),
        hoverColor: const Color(0xFF334155),
        tooltip: tooltip,
        onPressed: onPressed,
        splashRadius: 18,
      ),
    );
  }
}

class _ControlDivider extends StatelessWidget {
  const _ControlDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 28, height: 1, color: const Color(0xFF334155));
  }
}
