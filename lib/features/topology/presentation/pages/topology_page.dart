import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/topology_cubit.dart';
import '../bloc/topology_state.dart';
import '../widgets/enterprise_device_details_sheet.dart';
import '../widgets/enterprise_topology_canvas.dart';
import '../widgets/enterprise_topology_summary_bar.dart';
import '../widgets/topology_widgets.dart';

class TopologyPage extends StatelessWidget {
  const TopologyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TopologyCubit>(
      create: (_) => getIt<TopologyCubit>()..init(),
      child: const _TopologyView(),
    );
  }
}

class _TopologyView extends StatefulWidget {
  const _TopologyView();

  @override
  State<_TopologyView> createState() => _TopologyViewState();
}

class _TopologyViewState extends State<_TopologyView> {
  bool _isCanvasView = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<TopologyCubit, TopologyState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark
              ? AppColors.darkBackground
              : const Color(0xFFF1F5F9),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Top Summary Bar (Enterprise ratios & search) ───────────
              if (state is TopologyLoaded && state.enterpriseGraph != null)
                EnterpriseTopologySummaryBar(
                  stats: state.enterpriseGraph!.categoryStats,
                  searchQuery: state.searchQuery,
                  onSearchChanged: (q) =>
                      context.read<TopologyCubit>().search(q.trim()),
                  onClearSearch: () =>
                      context.read<TopologyCubit>().clearSearch(),
                  onRefresh: () => context.read<TopologyCubit>().init(),
                ),

              // ── 2. Subheader Bar (Title, Legend & View Mode Toggle) ───────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Title & Architecture Hint
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_tree_rounded,
                                size: 18,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Network Infrastructure Topology',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Deterministic Layout Diagram: WAN (L0) → Gateways (L1) → Switches (L2) → UniFi APs (L3) → Endpoints (L4)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // View Mode Switcher
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Layout Diagram'),
                          icon: Icon(Icons.schema_rounded, size: 16),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Tree View'),
                          icon: Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 16,
                          ),
                        ),
                      ],
                      selected: {_isCanvasView},
                      onSelectionChanged: (set) {
                        setState(() {
                          _isCanvasView = set.first;
                        });
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 3. Main Topology Viewport / Tree ──────────────────────────
              Expanded(child: _buildBody(context, state, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TopologyState state, bool isDark) {
    switch (state) {
      case TopologyLoading():
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF2563EB)),
              SizedBox(height: 12),
              Text(
                'Constructing deterministic topology graph…',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        );

      case TopologyError(:final message):
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.statusDown,
                size: 44,
              ),
              const SizedBox(height: 10),
              Text(
                'Failed to construct topology',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.statusDown,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<TopologyCubit>().init(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        );

      case TopologyLoaded():
        if (state.enterpriseGraph == null ||
            state.enterpriseGraph!.nodes.isEmpty) {
          return const Center(
            child: Text(
              'No infrastructure or endpoints discovered.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          );
        }

        // Layout Diagram View
        if (_isCanvasView) {
          return Stack(
            children: [
              // Interactive Canvas
              Positioned.fill(
                child: EnterpriseTopologyCanvas(
                  graph: state.enterpriseGraph!,
                  searchQuery: state.searchQuery,
                  onNodeSelected: (node) {
                    context.read<TopologyCubit>().selectNode(node);
                  },
                ),
              ),

              // Right Flyout Details Panel when a device is tapped
              if (state.selectedNode != null)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: EnterpriseDeviceDetailsSheet(
                    node: state.selectedNode!,
                    onClose: () {
                      context.read<TopologyCubit>().clearSelectedNode();
                    },
                  ),
                ),
            ],
          );
        }

        // Alternative Tree List View
        final nodes = state.filtered;
        if (nodes.isEmpty) {
          return const Center(
            child: Text(
              'No devices match the active filter or search query.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: nodes.length,
          itemBuilder: (context, i) =>
              LocationGroupCard(location: nodes[i], initiallyExpanded: true),
        );
    }
  }
}
