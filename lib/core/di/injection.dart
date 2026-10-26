import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../features/monitoring/data/datasources/monitoring_service_client.dart';
import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async {
  if (!getIt.isRegistered<MonitoringServiceClient>()) {
    getIt.registerLazySingleton<MonitoringServiceClient>(
      () => MonitoringServiceClient(
        baseUrl: 'http://127.0.0.1:4040',
        configurationError: 'MonitoringServiceClient not explicitly configured',
      ),
    );
  }
  getIt.init();
}
