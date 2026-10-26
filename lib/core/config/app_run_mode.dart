import 'dart:io';
import 'package:flutter/foundation.dart';

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
  /// Security enforcement: when true (or when kReleaseMode is true), standalone mode is strictly forbidden.
  static bool enforceReleaseModeSecurity = kReleaseMode;

  static bool get isReleaseEnforced =>
      kReleaseMode || enforceReleaseModeSecurity;

  static AppRunMode _detectDefaultRunMode() {
    if (isReleaseEnforced) {
      return AppRunMode.productionClient;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST') || kDebugMode) {
      return AppRunMode.standaloneDevelopment;
    }
    return AppRunMode.productionClient;
  }

  static AppRunMode _runMode = _detectDefaultRunMode();

  static AppRunMode get runMode => _runMode;
  static set runMode(AppRunMode mode) {
    if (isReleaseEnforced && mode == AppRunMode.standaloneDevelopment) {
      // In production release builds, standalone mode is strictly forbidden.
      _runMode = AppRunMode.productionClient;
      return;
    }
    _runMode = mode;
  }

  static bool get isProductionClient => runMode == AppRunMode.productionClient;
  static bool get isServiceDaemon => runMode == AppRunMode.serviceDaemon;
  static bool get isStandaloneDevelopment =>
      runMode == AppRunMode.standaloneDevelopment;

  static void resetForTesting({
    AppRunMode mode = AppRunMode.standaloneDevelopment,
  }) {
    if (isReleaseEnforced && mode == AppRunMode.standaloneDevelopment) {
      _runMode = AppRunMode.productionClient;
      return;
    }
    _runMode = mode;
  }
}
