import 'dart:io';

/// Explicit application runtime mode.
///
/// Determines whether the application runs as an authoritative background service daemon,
/// a desktop UI client connecting exclusively to the service API, or in standalone development/test mode.
enum AppRunMode {
  /// Desktop UI client connected to the authoritative LocalSystem Windows Service.
  /// Fails closed: all reads and writes route strictly through authenticated service APIs.
  /// Direct SQLite access, local database writes, and fallback to local storage are forbidden.
  productionClient,

  /// Background Windows Service daemon running as LocalSystem.
  /// Authoritative owner of the SQLite database, monitoring engine, and scheduler.
  serviceDaemon,

  /// Standalone local development and unit/integration testing mode.
  /// Permits direct SQLite database access when no background service is present.
  standaloneDevelopment,
}

/// Global application configuration defining operational runtime mode and boundaries.
class AppConfig {
  static AppRunMode _detectDefaultRunMode() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return AppRunMode.standaloneDevelopment;
    }
    return AppRunMode.productionClient;
  }

  static AppRunMode runMode = _detectDefaultRunMode();

  static bool get isProductionClient => runMode == AppRunMode.productionClient;
  static bool get isServiceDaemon => runMode == AppRunMode.serviceDaemon;
  static bool get isStandaloneDevelopment =>
      runMode == AppRunMode.standaloneDevelopment;

  static void resetForTesting({
    AppRunMode mode = AppRunMode.standaloneDevelopment,
  }) {
    runMode = mode;
  }
}
