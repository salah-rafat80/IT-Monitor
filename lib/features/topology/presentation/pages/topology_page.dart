import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_card.dart';
import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../factories/presentation/bloc/factory_cubit.dart';
import '../bloc/topology_cubit.dart';
import '../bloc/topology_state.dart';
import '../widgets/enterprise_device_details_sheet.dart';
import '../widgets/enterprise_topology_canvas.dart';
import '../widgets/enterprise_topology_summary_bar.dart';
import '../widgets/topology_widgets.dart';

class TopologyPage extends StatefulWidget {
  const TopologyPage({super.key});

  @override
  State<TopologyPage> createState() => _TopologyPageState();
}

class _TopologyPageState extends State<TopologyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final currentFactoryId =
            context.read<FactoryCubit>().state.selectedFactoryId;
        final cubit = context.read<TopologyCubit>();
        if (cubit.currentFactoryId != currentFactoryId) {
          cubit.setFactory(currentFactoryId);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FactoryCubit, FactoryState>(
      listenWhen: (prev, curr) =>
          prev.selectedFactoryId != curr.selectedFactoryId,
      listener: (context, state) {
        context.read<TopologyCubit>().setFactory(state.selectedFactoryId);
      },
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
    final tokens = context.appTokens;

    return BlocBuilder<TopologyCubit, TopologyState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: tokens.background,
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
                  horizontal: AppSpacing.xl,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tokens.card,
                  border: Border(
                    bottom: BorderSide(color: tokens.border),
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
                              Icon(
                                Icons.account_tree_rounded,
                                size: 18,
                                color: tokens.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Network Infrastructure Topology',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.onCard,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Deterministic Layout Diagram: WAN (L0) → Gateways (L1) → Switches (L2) → UniFi APs (L3) → Endpoints (L4)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.onSurfaceVariant,
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
              Expanded(child: _buildBody(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TopologyState state) {
    final tokens = context.appTokens;
    switch (state) {
      case TopologyLoading():
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.summaryCards(count: 4),
              const SizedBox(height: AppSpacing.xl),
              const Expanded(
                child: AppSkeleton(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: AppRadius.lg,
                ),
              ),
            ],
          ),
        );

      case TopologyError(:final message):
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: AppErrorCard(
              title: 'Topology Graph Construction Fault',
              message: message,
              onRetry: () => context.read<TopologyCubit>().init(),
            ),
          ),
        );

      case TopologyLoaded():
        if (state.enterpriseGraph == null ||
            state.enterpriseGraph!.nodes.isEmpty) {
          return Center(
            child: AppEmptyState.firstUse(
              entityName: 'Infrastructure Topology Nodes',
              actionLabel: 'Refresh Topology Discovery',
              onAction: () => context.read<TopologyCubit>().init(),
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
          return Center(
            child: Text(
              'No devices match the active filter or search query.',
              style: TextStyle(fontSize: 14, color: tokens.onSurfaceVariant),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: nodes.length,
          itemBuilder: (context, i) =>
              LocationGroupCard(location: nodes[i], initiallyExpanded: true),
        );
    }
  }
}
