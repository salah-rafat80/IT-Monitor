import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../../features/factories/presentation/widgets/factory_header_bar.dart';

class DesktopShell extends StatelessWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final authState = context.watch<AuthCubit>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 1000;
    final sidebarWidth = isCompact ? 72.0 : 240.0;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            color: Theme.of(context).colorScheme.surface,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, sidebarConstraints) {
                  final isSidebarCompact = sidebarConstraints.maxWidth < 180;
                  return Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSidebarCompact ? 12 : 20,
                          vertical: 24,
                        ),
                        alignment: isSidebarCompact
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: isSidebarCompact
                            ? const Tooltip(
                                message: 'IT Network Monitor',
                                child: Icon(
                                  Icons.monitor_heart,
                                  color: Color(0xFF0F62FE),
                                  size: 28,
                                ),
                              )
                            : Row(
                                children: [
                                  const Icon(
                                    Icons.monitor_heart,
                                    color: Color(0xFF0F62FE),
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'IT Monitor',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          children: [
                            _NavTile(
                              icon: Icons.dashboard_outlined,
                              selectedIcon: Icons.dashboard,
                              label: 'Dashboard',
                              isSelected:
                                  location == '/' || location == '/dashboard',
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/dashboard'),
                            ),
                            _NavTile(
                              icon: Icons.devices_outlined,
                              selectedIcon: Icons.devices,
                              label: 'Devices',
                              isSelected: location.startsWith('/devices'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/devices'),
                            ),
                            _NavTile(
                              icon: Icons.hub_outlined,
                              selectedIcon: Icons.hub,
                              label: 'Infrastructure',
                              isSelected: location.startsWith(
                                '/infrastructure',
                              ),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/infrastructure'),
                            ),
                            _NavTile(
                              icon: Icons.warning_amber_outlined,
                              selectedIcon: Icons.warning,
                              label: 'Incidents',
                              isSelected: location.startsWith('/incidents'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/incidents'),
                            ),
                            _NavTile(
                              icon: Icons.hub_outlined,
                              selectedIcon: Icons.hub,
                              label: 'Topology',
                              isSelected: location.startsWith('/topology'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/topology'),
                            ),
                            _NavTile(
                              icon: Icons.bar_chart_outlined,
                              selectedIcon: Icons.bar_chart,
                              label: 'Reports',
                              isSelected: location.startsWith('/reports'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/reports'),
                            ),
                            _NavTile(
                              icon: Icons.people_outline,
                              selectedIcon: Icons.people,
                              label: 'Users & Audit',
                              isSelected: location.startsWith('/users'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/users'),
                            ),
                            _NavTile(
                              icon: Icons.radar_outlined,
                              selectedIcon: Icons.radar,
                              label: 'Discovery',
                              isSelected: location.startsWith('/discovery'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/discovery'),
                            ),
                            _NavTile(
                              icon: Icons.settings_outlined,
                              selectedIcon: Icons.settings,
                              label: 'Settings',
                              isSelected: location.startsWith('/settings'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/settings'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: EdgeInsets.all(isSidebarCompact ? 12 : 16),
                        child: isSidebarCompact
                            ? Tooltip(
                                message:
                                    '${currentUser?.username ?? 'Administrator'} (ADMINISTRATOR)',
                                child: const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Color(0xFF0F62FE),
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFF0F62FE),
                                    child: Icon(
                                      Icons.admin_panel_settings,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          currentUser?.username ??
                                              'Administrator',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text(
                                          'ADMINISTRATOR',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Tooltip(
                                    message:
                                        'Administrator Mode (No Interactive Login Required)',
                                    child: Icon(
                                      Icons.verified_user_rounded,
                                      size: 20,
                                      color: Color(0xFF10B981),
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
          const VerticalDivider(width: 1),
          // Main Body
          Expanded(
            child: Column(
              children: [
                const FactoryHeaderBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? activeColor
                      : Theme.of(context).iconTheme.color,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? activeColor
                      : Theme.of(context).iconTheme.color,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? activeColor : null,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
