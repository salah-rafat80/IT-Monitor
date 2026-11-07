import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/factories/presentation/widgets/factory_header_bar.dart';
import '../../theme/app_colors.dart';

class DesktopShell extends StatelessWidget {
  final Widget child;

  const DesktopShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final location = GoRouterState.of(context).uri.path;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 1000;
    final sidebarWidth = isCompact ? 72.0 : 240.0;

    return Scaffold(
      backgroundColor: tokens.background,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(right: BorderSide(color: tokens.border, width: 1)),
              boxShadow: tokens.isDark
                  ? [
                      BoxShadow(
                        color: tokens.primary.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(2, 0),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                          horizontal: isSidebarCompact ? 12 : 20,
                          vertical: 22,
                        ),
                        alignment: isSidebarCompact
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: isSidebarCompact
                            ? Tooltip(
                                message: 'IT Network Monitor',
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: tokens.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: tokens.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.monitor_heart_rounded,
                                    color: tokens.primary,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: tokens.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: tokens.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.monitor_heart_rounded,
                                      color: tokens.primary,
                                      size: 24,
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
                                          'IT Monitor',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: tokens.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          tokens.isDark
                                              ? 'CYBER OPS'
                                              : 'ENTERPRISE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            color: tokens.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      Divider(height: 1, color: tokens.border),
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
                              icon: Icons.table_chart_outlined,
                              selectedIcon: Icons.table_chart,
                              label: 'Inventory',
                              isSelected: location.startsWith('/inventory'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/inventory'),
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
                              icon: Icons.account_tree_outlined,
                              selectedIcon: Icons.account_tree,
                              label: 'Topology',
                              isSelected: location.startsWith('/topology'),
                              isCompact: isSidebarCompact,
                              onTap: () => context.go('/topology'),
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
                            ? const Tooltip(
                                message: 'Local Administrator (ADMINISTRATOR)',
                                child: CircleAvatar(
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
                                          'Local Administrator',
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

class _NavTile extends StatefulWidget {
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
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final activeColor = tokens.primary;

    final bgColor = widget.isSelected
        ? activeColor.withValues(alpha: tokens.isDark ? 0.16 : 0.12)
        : (_isHovered
              ? tokens.surfaceSecondary.withValues(alpha: 0.6)
              : Colors.transparent);

    final borderColor = widget.isSelected
        ? (tokens.isDark
              ? tokens.borderGlow
              : activeColor.withValues(alpha: 0.4))
        : (_isHovered ? tokens.border : Colors.transparent);

    final iconColor = widget.isSelected
        ? activeColor
        : (_isHovered ? tokens.textPrimary : tokens.textSecondary);

    final textColor = widget.isSelected
        ? (tokens.isDark ? tokens.primary : activeColor)
        : (_isHovered ? tokens.textPrimary : tokens.textSecondary);

    if (widget.isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: widget.label,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: widget.isSelected && tokens.isDark
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.25),
                              blurRadius: 8,
                              spreadRadius: -1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.isSelected ? widget.selectedIcon : widget.icon,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: widget.isSelected && tokens.isDark
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isSelected ? widget.selectedIcon : widget.icon,
                    color: iconColor,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
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
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: tokens.isDark
                            ? [
                                BoxShadow(
                                  color: activeColor,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
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
