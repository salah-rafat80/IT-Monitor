import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';
import 'enterprise_device_card.dart';
import 'enterprise_topology_controls.dart';

/// Interactive Enterprise Topology Canvas.
///
/// Features:
/// - Light canvas with subtle square grid.
/// - Deterministic left-to-right layout.
/// - Smooth bezier connection lines with interface port labels (e.g. Gi0/1, Port 1).
/// - White rectangular device cards with status borders.
/// - Floating vertical controls (Fit-to-view, Zoom in/out, Zoom %).
/// - Mouse pan & zoom with interactive bounds.
class EnterpriseTopologyCanvas extends StatefulWidget {
  final EnterpriseTopologyGraph graph;
  final String searchQuery;
  final ValueChanged<EnterpriseTopologyNode>? onNodeSelected;
  final ValueChanged<EnterpriseTopologyLink>? onLinkSelected;

  const EnterpriseTopologyCanvas({
    super.key,
    required this.graph,
    this.searchQuery = '',
    this.onNodeSelected,
    this.onLinkSelected,
  });

  @override
  State<EnterpriseTopologyCanvas> createState() =>
      _EnterpriseTopologyCanvasState();
}

class _EnterpriseTopologyCanvasState extends State<EnterpriseTopologyCanvas>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  Animation<Matrix4>? _animation;
  late AnimationController _animController;
  double _currentScale = 1.0;
  String? _selectedNodeId;
  String? _selectedLinkId;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        )..addListener(() {
          if (_animation != null) {
            _transformationController.value = _animation!.value;
          }
        });

    // Auto fit-to-view initially after layout is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fitToView();
      }
    });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward(from: 0);
  }

  static const double canvasPadding = 1200.0;

  /// Fit the entire topology graph into the current viewport based on actual node bounds.
  void fitToView() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewportSize = renderBox.size;
    final allNodes = widget.graph.nodes.values;
    if (allNodes.isEmpty) return;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in allNodes) {
      final nx = node.position.dx + canvasPadding;
      final ny = node.position.dy + canvasPadding;
      if (nx < minX) minX = nx;
      if (ny < minY) minY = ny;
      final r = nx + node.size.width;
      final b = ny + node.size.height;
      if (r > maxX) maxX = r;
      if (b > maxY) maxY = b;
    }

    final boundsW = maxX - minX;
    final boundsH = maxY - minY;
    if (boundsW <= 0 || boundsH <= 0) return;

    const double padH = 48.0;
    const double padV = 36.0;

    final double scaleX = (viewportSize.width - padH * 2) / boundsW;
    final double scaleY = (viewportSize.height - padV * 2) / boundsH;
    double scale = math.min(scaleX, scaleY).clamp(0.40, 1.15);

    // Center the diagram bounds inside the viewport
    final double tx = (viewportSize.width - boundsW * scale) / 2 - minX * scale;
    final double ty =
        (viewportSize.height - boundsH * scale) / 2 - minY * scale;

    final matrix = Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(tx, ty, 0.0);

    _animateToMatrix(matrix);
  }

  void zoomIn() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(800, 600);
    final center = Offset(size.width / 2, size.height / 2);

    _zoom(1.25, center);
  }

  void zoomOut() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(800, 600);
    final center = Offset(size.width / 2, size.height / 2);

    _zoom(0.8, center);
  }

  void resetZoom() {
    double minX = double.infinity;
    double minY = double.infinity;
    for (final node in widget.graph.nodes.values) {
      if (node.position.dx < minX) minX = node.position.dx;
      if (node.position.dy < minY) minY = node.position.dy;
    }
    if (minX.isInfinite) {
      minX = 0;
      minY = 0;
    }
    final tx = 40.0 - (minX + canvasPadding);
    final ty = 40.0 - (minY + canvasPadding);
    final matrix = Matrix4.identity()..setTranslationRaw(tx, ty, 0.0);
    _animateToMatrix(matrix);
  }

  void _zoom(double factor, Offset focalPoint) {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.2, 2.5);
    final actualFactor = newScale / currentScale;

    final oldTx = currentMatrix.storage[12];
    final oldTy = currentMatrix.storage[13];
    final newTx = focalPoint.dx - actualFactor * (focalPoint.dx - oldTx);
    final newTy = focalPoint.dy - actualFactor * (focalPoint.dy - oldTy);

    final targetMatrix = Matrix4.diagonal3Values(newScale, newScale, 1.0)
      ..setTranslationRaw(newTx, newTy, 0.0);

    _animateToMatrix(targetMatrix);
  }

  @override
  Widget build(BuildContext context) {
    final allNodes = widget.graph.nodes;
    final links = widget.graph.links;
    final search = widget.searchQuery.trim().toLowerCase();

    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double canvasW = math.max(
            widget.graph.canvasSize.width + canvasPadding * 2,
            constraints.maxWidth,
          );
          final double canvasH = math.max(
            widget.graph.canvasSize.height + canvasPadding * 2,
            constraints.maxHeight,
          );
          final effectiveCanvasSize = Size(canvasW, canvasH);

          return Stack(
            children: [
              // ── Interactive Canvas Viewport ──────────────────────────────────
              Positioned.fill(
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(800),
                    minScale: 0.2,
                    maxScale: 2.5,
                    constrained: false,
                    child: Container(
                      width: effectiveCanvasSize.width,
                      height: effectiveCanvasSize.height,
                      color: const Color(
                        0xFF0F172A,
                      ), // Unified enterprise dark canvas
                      child: Stack(
                        children: [
                          // Layer 1: Background Square Grid across entire viewport
                          Positioned.fill(
                            child: CustomPaint(
                              size: effectiveCanvasSize,
                              painter: _EnterpriseGridPainter(
                                gridSpacing: 24.0,
                                gridColor: const Color(
                                  0xFF1E293B,
                                ).withValues(alpha: 0.6),
                              ),
                            ),
                          ),

                          // Layer 2: Connection Lines & Port Badges
                          Positioned.fill(
                            child: CustomPaint(
                              size: effectiveCanvasSize,
                              painter: _EnterpriseLinksPainter(
                                nodes: allNodes,
                                links: links,
                                selectedLinkId: _selectedLinkId,
                                canvasPadding: canvasPadding,
                              ),
                            ),
                          ),

                          // Layer 3: Interactive Device Cards
                          ...allNodes.values.map((node) {
                            final isSelected = node.id == _selectedNodeId;
                            final isHighlighted =
                                search.isNotEmpty &&
                                (node.title.toLowerCase().contains(search) ||
                                    (node.subtitle?.toLowerCase().contains(
                                          search,
                                        ) ??
                                        false) ||
                                    (node.location?.toLowerCase().contains(
                                          search,
                                        ) ??
                                        false));

                            return Positioned(
                              left: node.position.dx + canvasPadding,
                              top: node.position.dy + canvasPadding,
                              child: EnterpriseDeviceCard(
                                node: node,
                                isSelected: isSelected,
                                isHighlighted: isHighlighted,
                                onTap: () {
                                  setState(() {
                                    _selectedNodeId = node.id;
                                  });
                                  widget.onNodeSelected?.call(node);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Floating Left-Side Canvas Controls ──────────────────────────
              Positioned(
                left: 20,
                top: 20,
                child: EnterpriseTopologyControls(
                  currentZoom: _currentScale,
                  onFitToView: fitToView,
                  onZoomIn: zoomIn,
                  onZoomOut: zoomOut,
                  onResetZoom: resetZoom,
                  onHelp: () => _showTopologyLegend(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTopologyLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.hub_rounded, color: Color(0xFF38BDF8)),
            SizedBox(width: 10),
            Text(
              'Network Topology Legend & Guide',
              style: TextStyle(color: Color(0xFFF8FAFC)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Layout Hierarchy (Left to Right):',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Level 0: External WAN / Internet\n'
                '• Level 1: Enterprise Gateway / Core Routers\n'
                '• Level 2: Distribution & Location Switches\n'
                '• Level 3: UniFi Wireless Access Points\n'
                '• Level 4: Monitored Endpoints (Workstations, Laptops, Servers, Printers)',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Status Color Code:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 6),
              _buildLegendRow(
                const Color(0xFF10B981),
                'Online / Healthy: Normal operational response',
              ),
              _buildLegendRow(
                const Color(0xFFEF4444),
                'Down: Consecutive ICMP/Service ping timeouts',
              ),
              _buildLegendRow(
                const Color(0xFFF59E0B),
                'Degraded: Packet loss or elevated latency',
              ),
              _buildLegendRow(
                const Color(0xFF94A3B8),
                'Unknown: Insufficient reachability evidence',
              ),
              const SizedBox(height: 14),
              const Text(
                'Navigation Controls:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Pan: Click and drag anywhere on the canvas\n'
                '• Zoom: Scroll wheel or use the floating left toolbar\n'
                '• Inspect: Click any card to view detailed interface, IP, and location metrics',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF38BDF8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for subtle square grid lines on dark canvas.
class _EnterpriseGridPainter extends CustomPainter {
  final double gridSpacing;
  final Color gridColor;

  _EnterpriseGridPainter({required this.gridSpacing, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnterpriseGridPainter oldDelegate) {
    return oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.gridColor != gridColor;
  }
}

/// Custom painter for smooth bezier connection paths and port interface badges.
class _EnterpriseLinksPainter extends CustomPainter {
  final Map<String, EnterpriseTopologyNode> nodes;
  final List<EnterpriseTopologyLink> links;
  final String? selectedLinkId;
  final double canvasPadding;

  _EnterpriseLinksPainter({
    required this.nodes,
    required this.links,
    this.selectedLinkId,
    this.canvasPadding = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final link in links) {
      final fromNode = nodes[link.fromNodeId];
      final toNode = nodes[link.toNodeId];
      if (fromNode == null || toNode == null) continue;

      final start = fromNode.rightAnchor + Offset(canvasPadding, canvasPadding);
      final end = toNode.leftAnchor + Offset(canvasPadding, canvasPadding);

      // Determine path color based on link and endpoint status
      final isDown =
          link.status == DeviceStatusEnum.down ||
          link.status == DeviceStatusEnum.unreachable ||
          fromNode.status == DeviceStatusEnum.down ||
          fromNode.status == DeviceStatusEnum.unreachable ||
          toNode.status == DeviceStatusEnum.down ||
          toNode.status == DeviceStatusEnum.unreachable;

      final isAmber =
          !isDown &&
          (link.status == DeviceStatusEnum.degraded ||
              fromNode.consecutiveFailures > 0 ||
              toNode.consecutiveFailures > 0 ||
              fromNode.status == DeviceStatusEnum.degraded ||
              toNode.status == DeviceStatusEnum.degraded);

      final isUnknown =
          !isDown &&
          !isAmber &&
          (link.isInferred ||
              link.status == DeviceStatusEnum.unknown ||
              link.status == DeviceStatusEnum.stale ||
              fromNode.isInferred ||
              toNode.isInferred ||
              fromNode.status == DeviceStatusEnum.unknown ||
              fromNode.status == DeviceStatusEnum.stale ||
              toNode.status == DeviceStatusEnum.unknown ||
              toNode.status == DeviceStatusEnum.stale ||
              fromNode.category == TopologyDeviceCategory.wan ||
              toNode.category == TopologyDeviceCategory.wan);

      final Color linkColor;
      if (isDown) {
        linkColor = const Color(0xFFEF4444); // Alert red
      } else if (isAmber) {
        linkColor = const Color(0xFFF59E0B); // Amber warning
      } else if (isUnknown) {
        linkColor = const Color(0xFF64748B); // Slate 500 / Unknown
      } else {
        linkColor = const Color(0xFF10B981); // Enterprise Emerald green
      }

      linePaint
        ..color = linkColor.withValues(
          alpha: link.id == selectedLinkId ? 1.0 : 0.85,
        )
        ..strokeWidth = link.id == selectedLinkId ? 2.5 : 1.6;

      final path = Path();
      path.moveTo(start.dx, start.dy);

      final double dx = (end.dx - start.dx).abs();

      // Check if this is a Col B endpoint link that needs corridor routing
      if (toNode.level == 4 && toNode.position.dx > 1000.0) {
        final double channelX = end.dx - 16.0;
        final bool isAbove = end.dy < start.dy;
        final double detourY = isAbove
            ? math.min(
                    fromNode.position.dy + canvasPadding,
                    toNode.position.dy + canvasPadding,
                  ) -
                  10.0
            : math.max(
                    fromNode.position.dy + canvasPadding + fromNode.size.height,
                    toNode.position.dy + canvasPadding + toNode.size.height,
                  ) +
                  10.0;

        path.cubicTo(
          start.dx + 40,
          start.dy,
          channelX - 30,
          detourY,
          channelX,
          detourY,
        );
        path.cubicTo(
          channelX + 8,
          detourY,
          end.dx - 10,
          end.dy,
          end.dx,
          end.dy,
        );
      } else {
        // Draw smooth S-curve cubic bezier path
        final double cp1x = start.dx + dx * 0.45;
        final double cp1y = start.dy;
        final double cp2x = end.dx - dx * 0.45;
        final double cp2y = end.dy;
        path.cubicTo(cp1x, cp1y, cp2x, cp2y, end.dx, end.dy);
      }

      canvas.drawPath(path, linePaint);

      // Draw port labels if available (e.g. Gi0/1 on source, Port 1 or ETH on dest)
      if (link.fromPort != null && link.fromPort!.isNotEmpty) {
        _drawPortPill(canvas, link.fromPort!, Offset(start.dx + 26, start.dy));
      }
      if (link.toPort != null && link.toPort!.isNotEmpty) {
        _drawPortPill(canvas, link.toPort!, Offset(end.dx - 26, end.dy));
      }
    }
  }

  void _drawPortPill(Canvas canvas, String label, Offset center) {
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        fontFamily: 'Consolas',
        fontSize: 9.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFFCBD5E1), // Slate 300
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillWidth = textPainter.width + 10.0;
    final pillHeight = textPainter.height + 4.0;
    final pillRect = Rect.fromCenter(
      center: center,
      width: pillWidth,
      height: pillHeight,
    );

    // Pill background
    final bgPaint = Paint()
      ..color =
          const Color(0xFF1E293B) // Slate 800
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color =
          const Color(0xFF334155) // Slate 700 border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rrect = RRect.fromRectAndRadius(pillRect, const Radius.circular(4));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Paint text centered inside pill
    textPainter.paint(canvas, Offset(pillRect.left + 5.0, pillRect.top + 2.0));
  }

  @override
  bool shouldRepaint(covariant _EnterpriseLinksPainter oldDelegate) {
    return oldDelegate.links != links ||
        oldDelegate.nodes != nodes ||
        oldDelegate.selectedLinkId != selectedLinkId;
  }
}
