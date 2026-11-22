import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/enterprise_topology_models.dart';
import 'enterprise_device_card.dart';
import 'enterprise_topology_controls.dart';

/// Interactive Enterprise Topology Canvas.
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

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitToView();
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

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scaleByDouble(1.25, 1.25, 1.0, 1.0);
    _animateToMatrix(matrix);
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    _animateToMatrix(matrix);
  }

  void _resetZoom() {
    _animateToMatrix(Matrix4.identity());
  }

  void _fitToView() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewportSize = renderBox.size;
    final contentSize = widget.graph.canvasSize;

    if (contentSize.width <= 0 || contentSize.height <= 0) return;

    final padding = 48.0;
    final scaleX = (viewportSize.width - padding * 2) / contentSize.width;
    final scaleY = (viewportSize.height - padding * 2) / contentSize.height;
    final scale = math.min(scaleX, scaleY).clamp(0.25, 1.2);

    final dx = (viewportSize.width - contentSize.width * scale) / 2;
    final dy = (viewportSize.height - contentSize.height * scale) / 2;

    // ignore: deprecated_member_use
    final matrix = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(dx, dy)
      // ignore: deprecated_member_use
      ..scale(scale);

    _animateToMatrix(matrix);
  }

  void _animateToMatrix(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final allNodes = widget.graph.nodes;
    final links = widget.graph.links;
    final search = widget.searchQuery.trim().toLowerCase();

    return ColoredBox(
      color: tokens.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const canvasPadding = 32.0;
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
                      color: tokens.background,
                      child: Stack(
                        children: [
                          // Layer 1: Background Square Grid
                          Positioned.fill(
                            child: CustomPaint(
                              size: effectiveCanvasSize,
                              painter: _EnterpriseGridPainter(
                                gridSpacing: 24.0,
                                gridColor: tokens.border.withValues(alpha: 0.3),
                              ),
                            ),
                          ),

                          // Layer 2: Connection Lines & Port Badges
                          Positioned.fill(
                            child: CustomPaint(
                              size: effectiveCanvasSize,
                              painter: EnterpriseLinksPainter(
                                nodes: allNodes.values.toList(),
                                links: links,
                                selectedLinkId: _selectedLinkId,
                                canvasPadding: canvasPadding,
                                tokens: tokens,
                              ),
                            ),
                          ),

                          // Layer 3: Interactive Rectangular Device Cards
                          ...allNodes.values.map((node) {
                            final isMatch = search.isNotEmpty &&
                                (node.title.toLowerCase().contains(search) ||
                                    (node.subtitle?.toLowerCase().contains(search) ?? false) ||
                                    node.category.displayName.toLowerCase().contains(search));

                            final isDimmed = search.isNotEmpty && !isMatch;

                            return Positioned(
                              left: node.position.dx + canvasPadding,
                              top: node.position.dy + canvasPadding,
                              child: Opacity(
                                opacity: isDimmed ? 0.25 : 1.0,
                                child: EnterpriseDeviceCard(
                                  node: node,
                                  isSelected: node.id == _selectedNodeId,
                                  isHighlighted: isMatch,
                                  onTap: () {
                                    setState(() {
                                      _selectedNodeId = node.id;
                                    });
                                    widget.onNodeSelected?.call(node);
                                  },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Floating Zoom & View Controls (Left Center) ──────────────────
              Positioned(
                left: 16,
                top: 16,
                child: EnterpriseTopologyControls(
                  zoomPercent: (_currentScale * 100).round(),
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                  onResetZoom: _resetZoom,
                  onFitToView: _fitToView,
                  onLegendTap: () => _showTopologyLegend(context, tokens),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTopologyLegend(BuildContext context, AppColors tokens) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: tokens.border),
        ),
        title: Row(
          children: [
            Icon(Icons.hub_rounded, color: tokens.primary),
            const SizedBox(width: 10),
            Text(
              'Network Topology Legend & Guide',
              style: TextStyle(color: tokens.onCard, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Layout Hierarchy (Left to Right):',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: tokens.onCard,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Level 0: External WAN / Internet\n'
                '• Level 1: Enterprise Gateway / Core Routers\n'
                '• Level 2: Distribution & Location Switches\n'
                '• Level 3: UniFi Wireless Access Points\n'
                '• Level 4: Monitored Endpoints (Workstations, Laptops, Servers, Printers)',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Status Color Code:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: tokens.onCard,
                ),
              ),
              const SizedBox(height: 6),
              _buildLegendRow(
                tokens.statusOnline,
                'Online / Healthy: Normal operational response',
                tokens,
              ),
              _buildLegendRow(
                tokens.statusOffline,
                'Down: Consecutive ICMP/Service ping timeouts',
                tokens,
              ),
              _buildLegendRow(
                tokens.statusDegraded,
                'Degraded: Packet loss or elevated latency',
                tokens,
              ),
              _buildLegendRow(
                tokens.statusUnknown,
                'Unknown: Insufficient reachability evidence',
                tokens,
              ),
              const SizedBox(height: 14),
              Text(
                'Navigation Controls:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: tokens.onCard,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Pan: Click and drag anywhere on the canvas\n'
                '• Zoom: Scroll wheel or use the floating left toolbar\n'
                '• Inspect: Click any card to view detailed interface, IP, and location metrics',
                style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: tokens.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String text, AppColors tokens) {
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
              style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for subtle square grid lines on canvas.
class _EnterpriseGridPainter extends CustomPainter {
  final double gridSpacing;
  final Color gridColor;

  _EnterpriseGridPainter({
    required this.gridSpacing,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
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

/// Custom Painter for bezier connection lines and port badges.
class EnterpriseLinksPainter extends CustomPainter {
  final List<EnterpriseTopologyNode> nodes;
  final List<EnterpriseTopologyLink> links;
  final String? selectedLinkId;
  final double canvasPadding;
  final AppColors tokens;

  EnterpriseLinksPainter({
    required this.nodes,
    required this.links,
    this.selectedLinkId,
    this.canvasPadding = 32.0,
    required this.tokens,
  });

  static Color resolveLinkColor({
    required EnterpriseTopologyNode fromNode,
    required EnterpriseTopologyNode toNode,
    required EnterpriseTopologyLink link,
    AppColors? tokens,
  }) {
    final isInferredOrWan =
        link.isInferred ||
        fromNode.isInferred ||
        toNode.isInferred ||
        fromNode.category == TopologyDeviceCategory.wan ||
        toNode.category == TopologyDeviceCategory.wan;

    if (isInferredOrWan) {
      return tokens?.statusUnknown ?? const Color(0xFF64748B);
    }

    final isDown =
        link.status == DeviceStatusEnum.down ||
        link.status == DeviceStatusEnum.unreachable ||
        fromNode.status == DeviceStatusEnum.down ||
        fromNode.status == DeviceStatusEnum.unreachable ||
        toNode.status == DeviceStatusEnum.down ||
        toNode.status == DeviceStatusEnum.unreachable;

    if (isDown) {
      return tokens?.statusOffline ?? const Color(0xFFEF4444);
    }

    final isStale =
        link.status == DeviceStatusEnum.stale ||
        fromNode.status == DeviceStatusEnum.stale ||
        toNode.status == DeviceStatusEnum.stale;

    if (isStale) {
      return tokens?.statusDegraded ?? const Color(0xFFEAB308);
    }

    final isUnknown =
        link.status == DeviceStatusEnum.unknown ||
        fromNode.status == DeviceStatusEnum.unknown ||
        toNode.status == DeviceStatusEnum.unknown;

    if (isUnknown) {
      return tokens?.statusUnknown ?? const Color(0xFF64748B);
    }

    final isDegraded =
        link.status == DeviceStatusEnum.degraded ||
        fromNode.status == DeviceStatusEnum.degraded ||
        toNode.status == DeviceStatusEnum.degraded ||
        fromNode.consecutiveFailures > 0 ||
        toNode.consecutiveFailures > 0;

    if (isDegraded) {
      return tokens?.statusDegraded ?? const Color(0xFFF59E0B);
    }

    final isUp =
        link.status == DeviceStatusEnum.up &&
        fromNode.status == DeviceStatusEnum.up &&
        toNode.status == DeviceStatusEnum.up;

    if (isUp) {
      return tokens?.statusOnline ?? const Color(0xFF10B981);
    }

    return tokens?.statusUnknown ?? const Color(0xFF64748B);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final link in links) {
      final fromNode = nodeMap[link.fromNodeId];
      final toNode = nodeMap[link.toNodeId];

      if (fromNode == null || toNode == null) continue;

      final isSelected = link.id == selectedLinkId;
      final linkColor = resolveLinkColor(
        fromNode: fromNode,
        toNode: toNode,
        link: link,
        tokens: tokens,
      );

      Offset p1;
      Offset p2;
      Offset cp1;
      Offset cp2;

      final isSameColumn =
          (fromNode.position.dx - toNode.position.dx).abs() < 50;

      if (isSameColumn) {
        // Intra-column vertical link (e.g. between switches in the same tier)
        final p1IsAbove = fromNode.position.dy < toNode.position.dy;
        p1 = Offset(
          fromNode.position.dx + fromNode.size.width + canvasPadding,
          fromNode.position.dy + fromNode.size.height / 2 + canvasPadding,
        );
        p2 = Offset(
          toNode.position.dx + toNode.size.width + canvasPadding,
          toNode.position.dy + toNode.size.height / 2 + canvasPadding,
        );
        final dy = (p2.dy - p1.dy).abs();
        const curveOffset = 36.0;
        cp1 = Offset(
          p1.dx + curveOffset,
          p1.dy + (p1IsAbove ? dy * 0.25 : -dy * 0.25),
        );
        cp2 = Offset(
          p2.dx + curveOffset,
          p2.dy + (p1IsAbove ? -dy * 0.25 : dy * 0.25),
        );
      } else {
        // Inter-column left-to-right link
        p1 = Offset(
          fromNode.position.dx + fromNode.size.width + canvasPadding,
          fromNode.position.dy + fromNode.size.height / 2 + canvasPadding,
        );
        p2 = Offset(
          toNode.position.dx + canvasPadding,
          toNode.position.dy + toNode.size.height / 2 + canvasPadding,
        );
        final dx = (p2.dx - p1.dx).abs();
        cp1 = Offset(p1.dx + dx * 0.45, p1.dy);
        cp2 = Offset(p2.dx - dx * 0.45, p2.dy);
      }

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

      final strokeWidth = isSelected
          ? 2.8
          : (link.status == DeviceStatusEnum.up ? 1.6 : 1.2);

      final strokeAlpha = isSelected
          ? 1.0
          : (link.status == DeviceStatusEnum.up ? 0.75 : 0.45);

      final linePaint = Paint()
        ..color = linkColor.withValues(alpha: strokeAlpha)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, linePaint);

      if (link.fromPort != null && link.fromPort!.isNotEmpty) {
        final pillCenter = isSameColumn
            ? Offset(p1.dx + 28, p1.dy)
            : Offset(p1.dx + 22, p1.dy - 10);
        _drawPortPill(canvas, link.fromPort!, pillCenter);
      }
      if (link.toPort != null && link.toPort!.isNotEmpty) {
        final pillCenter = isSameColumn
            ? Offset(p2.dx + 28, p2.dy)
            : Offset(p2.dx - 22, p2.dy - 10);
        _drawPortPill(canvas, link.toPort!, pillCenter);
      }
    }
  }

  void _drawPortPill(Canvas canvas, String label, Offset center) {
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 9.0,
        fontWeight: FontWeight.w700,
        color: tokens.onSurfaceVariant,
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

    final bgPaint = Paint()
      ..color = tokens.surfaceVariant
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = tokens.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rrect = RRect.fromRectAndRadius(pillRect, const Radius.circular(AppRadius.xs));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    textPainter.paint(canvas, Offset(pillRect.left + 5.0, pillRect.top + 2.0));
  }

  @override
  bool shouldRepaint(covariant EnterpriseLinksPainter oldDelegate) {
    return oldDelegate.links != links ||
        oldDelegate.nodes != nodes ||
        oldDelegate.selectedLinkId != selectedLinkId ||
        oldDelegate.tokens != tokens;
  }
}
