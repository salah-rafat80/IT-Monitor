import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/devices/presentation/pages/devices_page.dart';
import '../../features/infrastructure/presentation/pages/infrastructure_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/network_blueprint/presentation/pages/network_blueprint_page.dart';
import '../../features/network_discovery/presentation/pages/network_discovery_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/theme/presentation/pages/palette_editor_page.dart';
import '../../features/topology/presentation/pages/topology_page.dart';
import '../../features/wall_display/presentation/pages/wall_display_page.dart';
import '../presentation/widgets/desktop_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class AppRouter {
  static String initialLocation = '/dashboard';

  static GoRouter? _routerInstance;

  static GoRouter get router => _routerInstance ??= GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wall-display',
        builder: (context, state) => const WallDisplayPage(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => DesktopShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesPage(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryPage(),
          ),
          GoRoute(
            path: '/infrastructure',
            builder: (context, state) => const InfrastructurePage(),
          ),
          GoRoute(
            path: '/topology',
            builder: (context, state) => const TopologyPage(),
          ),
          GoRoute(
            path: '/network-blueprint',
            builder: (context, state) => const NetworkBlueprintPage(),
          ),
          GoRoute(
            path: '/discovery',
            builder: (context, state) => const NetworkDiscoveryPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/palette-editor',
            builder: (context, state) => const PaletteEditorPage(),
          ),
        ],
      ),
    ],
  );
}
