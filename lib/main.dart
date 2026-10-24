import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import 'core/config/app_run_mode.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/devices/presentation/bloc/devices_cubit.dart';
import 'features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'features/monitoring/data/datasources/monitoring_service_client.dart';
import 'features/monitoring/presentation/bloc/monitoring_cubit.dart';
import 'features/monitoring/presentation/services/monitoring_service_server.dart';
import 'features/network_discovery/presentation/bloc/network_discovery_cubit.dart';
import 'features/users/presentation/bloc/user_management_cubit.dart';

void main(List<String> args) async {
  if (args.contains('--service')) {
    AppConfig.runMode = AppRunMode.serviceDaemon;
    DartPluginRegistrant.ensureInitialized();
    final config = MonitoringServiceConfig.loadFromEnvironmentOrFile(args);
    final service = MonitoringServiceServer.fromConfig(config);
    await service.start();
    return;
  }

  if (args.contains('--client')) {
    AppConfig.runMode = AppRunMode.productionClient;
  } else if (args.contains('--standalone') ||
      Platform.environment['IT_MONITOR_STANDALONE'] == 'true' ||
      kDebugMode) {
    AppConfig.runMode = AppRunMode.standaloneDevelopment;
  } else {
    // Check if the service token exists and is readable, or if remote token is configured
    final programData = Platform.environment['ProgramData'];
    final defaultToken = programData != null
        ? File(p.join(programData, 'ITNetworkMonitor', 'trusted_client.token'))
        : null;
    final hasEnvToken =
        Platform.environment['IT_MONITOR_CLIENT_TOKEN']?.isNotEmpty ?? false;

    bool hasReadableLocalToken = false;
    if (defaultToken != null && defaultToken.existsSync()) {
      try {
        final content = defaultToken.readAsStringSync().trim();
        hasReadableLocalToken = content.isNotEmpty;
      } catch (_) {
        hasReadableLocalToken = false;
      }
    }

    bool isServiceActive = false;
    if (hasEnvToken || hasReadableLocalToken) {
      final serviceUrlStr =
          Platform.environment['IT_MONITOR_SERVICE_URL'] ??
          (Platform.environment['IT_MONITOR_USE_TLS'] == 'false'
              ? 'http://127.0.0.1:8080'
              : 'https://127.0.0.1:8443');
      final serviceUri = Uri.tryParse(serviceUrlStr);
      final probeHost = serviceUri?.host.isNotEmpty == true
          ? serviceUri!.host
          : '127.0.0.1';
      final probePort = serviceUri?.hasPort == true
          ? serviceUri!.port
          : (serviceUri?.scheme == 'http' ? 8080 : 8443);

      try {
        final socket = await Socket.connect(
          probeHost,
          probePort,
          timeout: const Duration(milliseconds: 300),
        );
        socket.destroy();
        isServiceActive = true;
      } catch (_) {
        isServiceActive = false;
      }
    }

    if (isServiceActive) {
      AppConfig.runMode = AppRunMode.productionClient;
    } else {
      // Default to standalone mode so the application always opens directly on any computer
      AppConfig.runMode = AppRunMode.standaloneDevelopment;
    }
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

  // In Desktop Client mode, register authoritative MonitoringServiceClient in getIt before configureDependencies
  if (AppConfig.isProductionClient) {
    final programData = Platform.environment['ProgramData'];
    final defaultPublicCertPath = programData != null
        ? p.join(programData, 'ITNetworkMonitor', 'server.crt')
        : null;
    final defaultCertsDirCertPath = programData != null
        ? p.join(programData, 'ITNetworkMonitor', 'certs', 'server.crt')
        : null;
    final trustedCert =
        Platform.environment['IT_MONITOR_TRUSTED_CERT_PATH'] ??
        (defaultPublicCertPath != null &&
                File(defaultPublicCertPath).existsSync()
            ? defaultPublicCertPath
            : (defaultCertsDirCertPath != null &&
                      File(defaultCertsDirCertPath).existsSync()
                  ? defaultCertsDirCertPath
                  : null));
    final envToken = Platform.environment['IT_MONITOR_CLIENT_TOKEN']?.trim();

    final client = MonitoringServiceClient(
      baseUrl:
          Platform.environment['IT_MONITOR_SERVICE_URL'] ??
          (Platform.environment['IT_MONITOR_USE_TLS'] == 'false'
              ? 'http://127.0.0.1:8080'
              : 'https://127.0.0.1:8443'),
      trustedCertPath: trustedCert,
      provisionedToken: envToken,
    );
    if (!getIt.isRegistered<MonitoringServiceClient>()) {
      getIt.registerSingleton<MonitoringServiceClient>(client);
    }
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
