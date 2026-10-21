import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/devices/presentation/pages/devices_page.dart';
import '../../features/incidents/presentation/pages/incidents_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/network_discovery/presentation/pages/network_discovery_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/topology/presentation/pages/topology_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../di/injection.dart';
import '../presentation/widgets/desktop_shell.dart';
import '../../features/wall_display/presentation/pages/wall_display_page.dart';
import '../../features/infrastructure/presentation/pages/infrastructure_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class AppRouter {
  static String initialLocation = '/dashboard';

  static GoRouter? _routerInstance;

  static GoRouter get router => _routerInstance ??= GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
    redirect: (context, state) {
      // Direct access in administrator mode: any route to /login redirects to dashboard
      if (state.uri.path == '/login') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
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
            path: '/infrastructure',
            builder: (context, state) => const InfrastructurePage(),
          ),
          GoRoute(
            path: '/incidents',
            builder: (context, state) => const IncidentsPage(),
          ),
          GoRoute(
            path: '/topology',
            builder: (context, state) => const TopologyPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
          GoRoute(
            path: '/discovery',
            builder: (context, state) => const NetworkDiscoveryPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
