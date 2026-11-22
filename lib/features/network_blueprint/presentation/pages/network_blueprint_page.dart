import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/blueprint_element_entity.dart';
import '../../domain/entities/blueprint_page_entity.dart';
import '../bloc/network_blueprint_cubit.dart';
import '../bloc/network_blueprint_state.dart';
import '../widgets/blueprint_canvas.dart';
import '../widgets/blueprint_controls_bar.dart';
import '../widgets/blueprint_details_sheet.dart';
import '../widgets/blueprint_floor_tabs.dart';

class NetworkBlueprintPage extends StatelessWidget {
  const NetworkBlueprintPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<NetworkBlueprintCubit>()..loadBlueprint(),
      child: const _NetworkBlueprintView(),
    );
  }
}

class _NetworkBlueprintView extends StatefulWidget {
  const _NetworkBlueprintView();

  @override
  State<_NetworkBlueprintView> createState() => _NetworkBlueprintViewState();
}

class _NetworkBlueprintViewState extends State<_NetworkBlueprintView> {
  final TransformationController _transformationController = TransformationController();
  Size _lastViewportSize = Size.zero;
  String? _lastFittedPageId;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.25).clamp(0.05, 4.0);
    final factor = newScale / currentScale;
    final matrix = currentMatrix.clone();
    // ignore: deprecated_member_use
    matrix.scale(factor, factor, 1.0);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (currentScale * 0.8).clamp(0.05, 4.0);
    final factor = newScale / currentScale;
    final matrix = currentMatrix.clone();
    // ignore: deprecated_member_use
    matrix.scale(factor, factor, 1.0);
    _transformationController.value = matrix;
  }

  void _fitToScreen(BlueprintPageEntity page) {
    if (_lastViewportSize.width <= 0 || _lastViewportSize.height <= 0) return;

    final bounds = page.contentBounds;
    if (bounds.width <= 0 || bounds.height <= 0) return;

    final scaleX = _lastViewportSize.width / bounds.width;
    final scaleY = _lastViewportSize.height / bounds.height;
    final scale = math.min(scaleX, scaleY) * 0.92;

    // Honor the bounding box origin (bounds.left, bounds.top)
    final offsetX = (_lastViewportSize.width - bounds.width * scale) / 2 - bounds.left * scale;
    final offsetY = (_lastViewportSize.height - bounds.height * scale) / 2 - bounds.top * scale;

    final matrix = Matrix4.diagonal3Values(scale, scale, 1.0)
      ..setTranslationRaw(offsetX, offsetY, 0.0);

    _transformationController.value = matrix;
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  void _centerElement(BlueprintElementEntity element, BlueprintPageEntity page) {
    if (_lastViewportSize.width <= 0 || _lastViewportSize.height <= 0) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    // Use renderBounds (strictly in SVG coordinate space matching canvas rendering)
    final elCenter = element.renderBounds.center;

    final targetX = _lastViewportSize.width / 2 - elCenter.dx * currentScale;
    final targetY = _lastViewportSize.height / 2 - elCenter.dy * currentScale;

    final matrix = Matrix4.diagonal3Values(currentScale, currentScale, 1.0)
      ..setTranslationRaw(targetX, targetY, 0.0);

    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
      backgroundColor: tokens.background,
      body: BlocConsumer<NetworkBlueprintCubit, NetworkBlueprintState>(
        listener: (context, state) {
          if (state is NetworkBlueprintLoaded && _lastViewportSize != Size.zero) {
            // Auto-fit ONLY on initial load or explicit page change; preserve zoom across telemetry refreshes
            if (_lastFittedPageId != state.currentPage.id) {
              _lastFittedPageId = state.currentPage.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fitToScreen(state.currentPage);
              });
            }
          }
        },
        builder: (context, state) {
          if (state is NetworkBlueprintLoading) {
            return _buildLoading(context, isDark);
          } else if (state is NetworkBlueprintError) {
            return _buildError(context, state.message, isDark);
          } else if (state is NetworkBlueprintLoaded) {
            return _buildLoaded(context, state, isDark);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoading(BuildContext context, bool isDark) {
    final tokens = context.appTokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: tokens.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Network Blueprint diagrams & telemetry...',
            style: TextStyle(
              fontSize: 14,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message, bool isDark) {
    final tokens = context.appTokens;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.statusOffline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: tokens.statusOffline),
            const SizedBox(height: 16),
            Text(
              'Blueprint Rendering Error',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.read<NetworkBlueprintCubit>().loadBlueprint();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Loading'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    NetworkBlueprintLoaded state,
    bool isDark,
  ) {
    final cubit = context.read<NetworkBlueprintCubit>();
    final currentPage = state.currentPage;

    return Column(
      children: [
        // Floor Tabs Selector
        BlueprintFloorTabs(
          pages: state.pages,
          selectedIndex: state.selectedPageIndex,
          onTabSelected: (index) {
            _lastFittedPageId = state.pages[index].id;
            cubit.selectPage(index);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitToScreen(state.pages[index]);
            });
          },
        ),

        // Controls Bar
        BlueprintControlsBar(
          searchQuery: state.searchQuery,
          onSearchChanged: cubit.updateSearchQuery,
          isLiveMonitoringActive: state.isLiveMonitoringActive,
          onToggleLiveMonitoring: cubit.toggleLiveMonitoring,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onFitToScreen: () => _fitToScreen(currentPage),
          onResetView: _resetView,
          onCenterSelected: state.selectedElement != null
              ? () => _centerElement(state.selectedElement!, currentPage)
              : null,
        ),

        // Main Interactive Canvas Area + Side Details Sheet
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lastViewportSize = Size(constraints.maxWidth, constraints.maxHeight);

              return Row(
                children: [
                  Expanded(
                    child: BlueprintCanvas(
                      page: currentPage,
                      selectedElement: state.selectedElement,
                      transformationController: _transformationController,
                      showLiveStatus: state.isLiveMonitoringActive,
                      onElementSelected: cubit.selectElement,
                    ),
                  ),

                  // Collapsible Details Sheet
                  if (state.selectedElement != null)
                    BlueprintDetailsSheet(
                      element: state.selectedElement!,
                      onClose: () => cubit.selectElement(null),
                      onCenterOnCanvas: () => _centerElement(state.selectedElement!, currentPage),
                    ),
                ],
              );
            },
          ),
        ),

        // Bottom Telemetry Summary Bar
        _buildBottomBar(context, currentPage, isDark),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, BlueprintPageEntity page, bool isDark) {
    final tokens = context.appTokens;
    final monitoredCount = page.elements.where((e) => e.isMonitored).length;
    final totalElements = page.elements.length;
    final totalCables = page.cables.length;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: tokens.surfaceSecondary,
        border: Border(
          top: BorderSide(
            color: tokens.cardBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Diagram: ${page.englishTitle}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$totalElements Elements · $totalCables Cable Routes',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                Icons.sensors,
                size: 14,
                color: monitoredCount > 0 ? tokens.statusOnline : tokens.statusUnknown,
              ),
              const SizedBox(width: 6),
              Text(
                'Monitored Endpoints: $monitoredCount Confirmed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: monitoredCount > 0
                      ? tokens.statusOnline
                      : (tokens.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
