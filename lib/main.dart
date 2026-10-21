import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/devices/presentation/bloc/devices_cubit.dart';
import 'features/monitoring/presentation/bloc/monitoring_cubit.dart';
import 'features/users/presentation/bloc/user_management_cubit.dart';
import 'features/network_discovery/presentation/bloc/network_discovery_cubit.dart';

import 'features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'features/monitoring/presentation/services/monitoring_service_server.dart';

void main(List<String> args) async {
  if (args.contains('--service')) {
    DartPluginRegistrant.ensureInitialized();
    final config = MonitoringServiceConfig.loadFromEnvironmentOrFile(args);
    final service = MonitoringServiceServer.fromConfig(config);
    await service.start();
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();

  for (final arg in args) {
    if (arg.startsWith('--route=')) {
      AppRouter.initialLocation = arg.substring('--route='.length);
    }
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[Unhandled Async Error]: $error');
    debugPrint(stack.toString());
    return true;
  };

  await configureDependencies();

  runApp(const ITNetworkMonitorApp());
}

class ITNetworkMonitorApp extends StatelessWidget {
  const ITNetworkMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(
          value: getIt<AuthCubit>()..checkAuthStatus(),
        ),
        BlocProvider<UserManagementCubit>(
          create: (_) => getIt<UserManagementCubit>(),
        ),
        BlocProvider<DevicesCubit>(
          create: (_) => getIt<DevicesCubit>()..loadDevices(),
        ),
        BlocProvider<MonitoringCubit>(
          create: (_) => getIt<MonitoringCubit>()..initMonitoring(),
        ),
        BlocProvider<NetworkDiscoveryCubit>(
          create: (_) => getIt<NetworkDiscoveryCubit>()..init(),
        ),
        BlocProvider<InfrastructureCubit>.value(
          value: getIt<InfrastructureCubit>()..loadInfrastructure(),
        ),
      ],
      child: MaterialApp.router(
        title: 'IT Network Monitor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
