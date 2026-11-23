import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../features/devices/presentation/bloc/devices_cubit.dart';
import '../../../features/factories/presentation/bloc/factory_cubit.dart';
import '../../../features/factories/presentation/widgets/factory_header_bar.dart';
import '../../../features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import '../../../features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import '../../../features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import '../../../features/topology/presentation/bloc/topology_cubit.dart';
import '../../di/injection.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import 'enterprise_svg_icons.dart';

class DesktopShell extends StatelessWidget {
  final Widget? child;
  final StatefulNavigationShell? navigationShell;

  const DesktopShell({
    super.key,
    this.child,
    this.navigationShell,
  });

  void _navigateTo(BuildContext context, int branchIndex, String routePath) {
    if (navigationShell != null) {
      navigationShell!.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell!.currentIndex,
      );
    } else {
      context.go(routePath);
    }
  }

  bool _isBranchSelected(String location, int branchIndex, String routePrefix) {
    if (navigationShell != null) {
      return navigationShell!.currentIndex == branchIndex;
    }
    return routePrefix == '/dashboard'
        ? (location == '/' || location == '/dashboard')
        : location.startsWith(routePrefix);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final location = GoRouterState.of(context).uri.path;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 1000;
    final sidebarWidth = isCompact ? 72.0 : 240.0;

    final shellScaffold = Scaffold(
      backgroundColor: tokens.background,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: tokens.sidebar,
              border: Border(right: BorderSide(color: tokens.border, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow,
                  blurRadius: 8,
                  offset: const Offset(1, 0),
                ),
              ],
            ),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, sidebarConstraints) {
                  final isSidebarCompact = sidebarConstraints.maxWidth < 180;
                  return Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSidebarCompact ? AppSpacing.md : AppSpacing.xl,
                          vertical: 20,
                        ),
                        alignment: isSidebarCompact
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: isSidebarCompact
                            ? Tooltip(
                                message: 'IT Network Monitor - Indomie',
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: tokens.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: tokens.border),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    child: Image.asset(
                                      'assets/images/app_logo.png',
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surface,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(color: tokens.border),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      child: Image.asset(
                                        'assets/images/app_logo.png',
                                        width: 44,
                                        height: 30,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'IT Monitor',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: tokens.onSidebar,
                                            letterSpacing: -0.3,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'INDOMIE ENTERPRISE',
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            color: tokens.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      Divider(height: 1, color: tokens.divider),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.sm,
                          ),
                          children: [
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.dashboard,
                              label: 'Dashboard',
                              isSelected: _isBranchSelected(location, 0, '/dashboard'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 0, '/dashboard'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.devices,
                              label: 'Devices',
                              isSelected: _isBranchSelected(location, 1, '/devices'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 1, '/devices'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.inventory,
                              label: 'Inventory',
                              isSelected: _isBranchSelected(location, 2, '/inventory'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 2, '/inventory'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.infrastructure,
                              label: 'Infrastructure',
                              isSelected: _isBranchSelected(location, 3, '/infrastructure'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 3, '/infrastructure'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.topology,
                              label: 'Topology',
                              isSelected: _isBranchSelected(location, 4, '/topology'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 4, '/topology'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.blueprint,
                              label: 'Network Blueprint',
                              isSelected: _isBranchSelected(location, 5, '/network-blueprint'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 5, '/network-blueprint'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.discovery,
                              label: 'Discovery',
                              isSelected: _isBranchSelected(location, 6, '/discovery'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 6, '/discovery'),
                            ),
                            _NavTile(
                              svgIcon: EnterpriseSvgIcons.settings,
                              label: 'Settings',
                              isSelected: _isBranchSelected(location, 7, '/settings'),
                              isCompact: isSidebarCompact,
                              onTap: () => _navigateTo(context, 7, '/settings'),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: tokens.divider),
                      Padding(
                        padding: EdgeInsets.all(isSidebarCompact ? AppSpacing.md : AppSpacing.lg),
                        child: isSidebarCompact
                            ? Tooltip(
                                message: 'Local Administrator (ADMINISTRATOR)',
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: tokens.primary.withValues(alpha: 0.15),
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    size: 18,
                                    color: tokens.primary,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: tokens.primary.withValues(alpha: 0.15),
                                    child: Icon(
                                      Icons.admin_panel_settings,
                                      size: 18,
                                      color: tokens.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Local Administrator',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: tokens.onSidebar,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'ADMINISTRATOR',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: tokens.onStatusOnline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Tooltip(
                                    message:
                                        'Administrator Mode (Verified Active Session)',
                                    child: Icon(
                                      Icons.verified_user_rounded,
                                      size: 18,
                                      color: tokens.statusOnline,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          VerticalDivider(width: 1, color: tokens.divider),
          // Main Body
          Expanded(
            child: Column(
              children: [
                const FactoryHeaderBar(),
                Expanded(
                  child: navigationShell ?? child ?? const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!getIt.isRegistered<FactoryCubit>()) {
      return shellScaffold;
    }

    final factoryCubit = getIt<FactoryCubit>();
    return MultiBlocListener(
      listeners: [
        BlocListener<FactoryCubit, FactoryState>(
          bloc: factoryCubit,
          listenWhen: (prev, curr) =>
              prev.selectedFactoryId != curr.selectedFactoryId,
          listener: (context, state) {
            final factoryId = state.selectedFactoryId;
            final futures = <Future<void>>[];

            try {
              futures.add(context.read<DevicesCubit>().setFactory(factoryId));
            } catch (_) {}

            try {
              futures.add(
                context.read<InfrastructureCubit>().setFactory(factoryId),
              );
            } catch (_) {}

            try {
              futures.add(
                context
                    .read<MonitoringDashboardCubit>()
                    .setFactoryFilter(factoryId),
              );
            } catch (_) {}

            try {
              futures.add(
                context.read<NetworkDiscoveryCubit>().setFactory(factoryId),
              );
            } catch (_) {}

            if (futures.isNotEmpty) {
              Future.wait(futures);
            }

            try {
              context.read<TopologyCubit>().setFactory(factoryId);
            } catch (_) {}
          },
        ),
      ],
      child: shellScaffold,
    );
  }
}

class _NavTile extends StatefulWidget {
  final String svgIcon;
  final String label;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavTile({
    required this.svgIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    final bgColor = widget.isSelected
        ? tokens.primary.withValues(alpha: tokens.isDark ? 0.20 : 0.12)
        : (_isHovered
            ? tokens.surfaceVariant.withValues(alpha: 0.6)
            : tokens.transparent);

    final borderColor = widget.isSelected
        ? tokens.accent
        : (_isHovered ? tokens.border : tokens.transparent);

    final iconColor = widget.isSelected
        ? tokens.accent
        : (_isHovered ? tokens.onSidebar : tokens.onSurfaceVariant);

    final textColor = widget.isSelected
        ? tokens.onSidebar
        : (_isHovered ? tokens.onSidebar : tokens.onSurfaceVariant);

    if (widget.isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Tooltip(
          message: widget.label,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Material(
              color: tokens.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Center(
                    child: EnterpriseSvgIcon(
                      svgString: widget.svgIcon,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: tokens.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  EnterpriseSvgIcon(
                    svgString: widget.svgIcon,
                    color: iconColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: textColor,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (widget.isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
