import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config/app_run_mode.dart';
import 'core/config/client_config.dart';
import 'core/database/app_database.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/devices/presentation/bloc/devices_cubit.dart';
import 'features/factories/presentation/bloc/factory_cubit.dart';
import 'features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'features/monitoring/data/datasources/monitoring_service_client.dart';
import 'features/monitoring/presentation/bloc/monitoring_cubit.dart';
import 'features/monitoring/presentation/bloc/monitoring_dashboard_cubit.dart';
import 'features/monitoring/presentation/services/monitoring_service_server.dart';
import 'features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import 'features/topology/presentation/bloc/topology_cubit.dart';

void main(List<String> args) async {
  if (args.contains('--service')) {
    AppConfig.runMode = AppRunMode.serviceDaemon;
    DartPluginRegistrant.ensureInitialized();
    final config = MonitoringServiceConfig.loadFromEnvironmentOrFile(args);
    final service = MonitoringServiceServer.fromConfig(config);
    await service.start();
    return;
  }

  // Determine AppRunMode:
  // 1. Explicit --client flag forces productionClient mode.
  // 2. Explicit --standalone flag forces standaloneDevelopment mode.
  // 3. Otherwise: probe if background service is running on 127.0.0.1:5050.
  //    If running -> productionClient.
  //    If not running -> standaloneDevelopment (direct local database & auto admin login).
  if (args.contains('--client')) {
    AppConfig.runMode = AppRunMode.productionClient;
  } else if (args.contains('--standalone') ||
      Platform.environment['IT_MONITOR_STANDALONE'] == 'true') {
    AppConfig.runMode = AppRunMode.standaloneDevelopment;
  } else if (AppConfig.isReleaseEnforced) {
    AppConfig.runMode = AppRunMode.productionClient;
  } else {
    bool serviceRunning = false;
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        5050,
        timeout: const Duration(milliseconds: 150),
      );
      socket.destroy();
      serviceRunning = true;
    } catch (_) {
      serviceRunning = false;
    }

    if (serviceRunning) {
      AppConfig.runMode = AppRunMode.productionClient;
    } else {
      AppConfig.runMode = AppRunMode.standaloneDevelopment;
    }
  }

  if (AppConfig.isStandaloneDevelopment) {
    DatabaseConfig.isDevelopment = true;
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

  // Register authoritative MonitoringServiceClient in getIt before configureDependencies
  if (!getIt.isRegistered<MonitoringServiceClient>()) {
    MonitoringClientConfig clientConfig;
    try {
      clientConfig = MonitoringClientConfig.loadFromEnvironmentOrFile(args);
    } catch (e) {
      debugPrint('[MonitoringClientConfig error]: $e');
      clientConfig = MonitoringClientConfig.error(errorMessage: e.toString());
    }

    MonitoringServiceClient client;
    try {
      client = MonitoringServiceClient(
        baseUrl: clientConfig.serviceUrl,
        trustedCertPath: clientConfig.trustedCertPath,
        provisionedToken: clientConfig.clientToken,
        configurationError: clientConfig.errorMessage,
      );
    } catch (e) {
      debugPrint('[MonitoringServiceClient init error]: $e');
      client = MonitoringServiceClient(
        baseUrl: clientConfig.serviceUrl,
        trustedCertPath: clientConfig.trustedCertPath,
        provisionedToken: clientConfig.clientToken,
        configurationError: e.toString(),
      );
    }
    getIt.registerSingleton<MonitoringServiceClient>(client);
  }

  await configureDependencies();

  // Attempt initial server authentication:
  // - Local operator deployments: Read local trusted token from %ProgramData%\ITNetworkMonitor\trusted_client.token
  // - Remote client deployments: Read provisioned token from environment variable IT_MONITOR_CLIENT_TOKEN
  // Both flows require authoritative server verification via /api/auth/verify before establishing an authenticated session.
  // Direct launch UX is preserved without an interactive password prompt.
  if (AppConfig.isProductionClient &&
      getIt.isRegistered<MonitoringServiceClient>()) {
    final client = getIt<MonitoringServiceClient>();
    if (client.hasConfigurationError) {
      debugPrint(
        '[MonitoringServiceClient startup auth skipped due to config error]: ${client.configurationError}',
      );
    } else {
      try {
        final authRes =
            client.isRemoteTokenMode && client.currentProvisionedToken != null
            ? await client.authenticateWithProvisionedToken(
                client.currentProvisionedToken!,
              )
            : await client.authenticateWithTrustedLocalToken();

        if (authRes.isSuccess && client.isAuthenticated) {
          client.connectWebSocket().catchError((error) {
            debugPrint('[MonitoringServiceClient WebSocket error]: $error');
          });
        } else {
          debugPrint(
            '[MonitoringServiceClient startup auth notice]: ${authRes.errorMessage}',
          );
        }
      } catch (e, stack) {
        debugPrint(
          '[MonitoringServiceClient startup connection error]: $e\n$stack',
        );
      }
    }
  }

  runApp(const ITNetworkMonitorApp());
}

class ITNetworkMonitorApp extends StatelessWidget {
  const ITNetworkMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FactoryCubit>(
          create: (_) => getIt<FactoryCubit>()..loadFactories(),
        ),
        BlocProvider<DevicesCubit>(
          create: (_) => getIt<DevicesCubit>()..loadDevices(),
        ),
        BlocProvider<MonitoringCubit>(
          create: (_) => getIt<MonitoringCubit>()
            ..initMonitoring(startScheduler: AppConfig.isStandaloneDevelopment),
        ),
        BlocProvider<MonitoringDashboardCubit>(
          create: (ctx) {
            final factoryId = ctx.read<FactoryCubit>().state.selectedFactoryId;
            return getIt<MonitoringDashboardCubit>()
              ..initDashboard(factoryId: factoryId);
          },
        ),
        BlocProvider<TopologyCubit>(
          create: (ctx) {
            final factoryId = ctx.read<FactoryCubit>().state.selectedFactoryId;
            return getIt<TopologyCubit>()..init(factoryId);
          },
        ),
        BlocProvider<NetworkDiscoveryCubit>(
          create: (_) => getIt<NetworkDiscoveryCubit>()..init(),
        ),
        BlocProvider<InfrastructureCubit>.value(
          value: getIt<InfrastructureCubit>()..loadInfrastructure(),
        ),
        BlocProvider<ThemeCubit>(create: (_) => getIt<ThemeCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'IT Network Monitor - Indomie',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildTheme(
              palette: themeState.palette,
              isDark: false,
            ),
            darkTheme: AppTheme.buildTheme(
              palette: themeState.palette,
              isDark: true,
            ),
            themeMode: themeState.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
