import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/blueprint_element_entity.dart';
import '../../domain/entities/blueprint_page_entity.dart';

class BlueprintCanvas extends StatefulWidget {
  final BlueprintPageEntity page;
  final BlueprintElementEntity? selectedElement;
  final ValueChanged<BlueprintElementEntity?> onElementSelected;
  final TransformationController transformationController;
  final bool showLiveStatus;

  const BlueprintCanvas({
    super.key,
    required this.page,
    this.selectedElement,
    required this.onElementSelected,
    required this.transformationController,
    this.showLiveStatus = true,
  });

  @override
  State<BlueprintCanvas> createState() => _BlueprintCanvasState();
}

class _BlueprintCanvasState extends State<BlueprintCanvas> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svgSize = widget.page.svgSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          child: ClipRect(
            child: GestureDetector(
              onTapUp: (details) {
                _handleTap(details.localPosition);
              },
              child: InteractiveViewer(
                transformationController: widget.transformationController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(5000),
                minScale: 0.05,
                maxScale: 4.0,
                child: Container(
                  width: svgSize.width,
                  height: svgSize.height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B111E),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Layer 1: Authoritative High-Fidelity Network Blueprint Diagram
                      widget.page.imageAssetPath.isNotEmpty
                          ? Image.asset(
                              widget.page.imageAssetPath,
                              width: svgSize.width,
                              height: svgSize.height,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            )
                          : SvgPicture.asset(
                              widget.page.svgAssetPath,
                              width: svgSize.width,
                              height: svgSize.height,
                              fit: BoxFit.fill,
                            ),

                      // Layer 2: Interactive Overlays (Selection Highlight & Live Telemetry Badges)
                      CustomPaint(
                        size: Size(svgSize.width, svgSize.height),
                        painter: _BlueprintInteractiveOverlayPainter(
                          page: widget.page,
                          selectedElement: widget.selectedElement,
                          isDark: isDark,
                          showLiveStatus: widget.showLiveStatus,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset localTapPos) {
    final scenePos = widget.transformationController.toScene(localTapPos);

    BlueprintElementEntity? bestMatch;
    double smallestArea = double.infinity;

    for (final el in widget.page.elements) {
      if (el.renderBounds.contains(scenePos)) {
        final area = el.renderBounds.width * el.renderBounds.height;
        if (area < smallestArea) {
          smallestArea = area;
          bestMatch = el;
        }
      }
    }

    widget.onElementSelected(bestMatch);
  }
}

class _BlueprintInteractiveOverlayPainter extends CustomPainter {
  final BlueprintPageEntity page;
  final BlueprintElementEntity? selectedElement;
  final bool isDark;
  final bool showLiveStatus;

  _BlueprintInteractiveOverlayPainter({
    required this.page,
    required this.selectedElement,
    required this.isDark,
    required this.showLiveStatus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Selection Highlight if an element is selected
    if (selectedElement != null) {
      final rect = selectedElement!.renderBounds.inflate(4.0);
      final highlightFill = Paint()
        ..color = const Color(0x333B82F6)
        ..style = PaintingStyle.fill;
      final highlightStroke = Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6.0));
      canvas.drawRRect(rrect, highlightFill);
      canvas.drawRRect(rrect, highlightStroke);
    }

    // 2. Draw Live Telemetry Status Badges on monitored devices
    if (showLiveStatus) {
      for (final el in page.elements) {
        if (!el.isMonitored) continue;

        final badgePos = Offset(
          el.renderBounds.right - 2,
          el.renderBounds.top + 2,
        );

        final statusColor = _resolveStatusColor(el.liveStatus);

        // Draw shadow / ring
        final ringPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(badgePos, 5.5, ringPaint);
        final ringStroke = Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        canvas.drawCircle(badgePos, 5.5, ringStroke);

        // Draw status dot
        final dotPaint = Paint()
          ..color = statusColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(badgePos, 4.0, dotPaint);

        // If Down or Degraded, draw outer pulse indicator
        if (el.liveStatus == DeviceStatusEnum.down ||
            el.liveStatus == DeviceStatusEnum.degraded) {
          final alertPaint = Paint()
            ..color = statusColor.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(badgePos, 8.0, alertPaint);
        }
      }
    }
  }

  Color _resolveStatusColor(DeviceStatusEnum? status) {
    switch (status) {
      case DeviceStatusEnum.up:
        return const Color(0xFF10B981);
      case DeviceStatusEnum.down:
        return const Color(0xFFEF4444);
      case DeviceStatusEnum.degraded:
        return const Color(0xFFF59E0B);
      case DeviceStatusEnum.unknown:
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  bool shouldRepaint(
    covariant _BlueprintInteractiveOverlayPainter oldDelegate,
  ) {
    return oldDelegate.selectedElement != selectedElement ||
        oldDelegate.showLiveStatus != showLiveStatus ||
        oldDelegate.isDark != isDark ||
        oldDelegate.page != page;
  }
}
