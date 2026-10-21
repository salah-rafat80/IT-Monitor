class AppConstants {
  static const String appName = 'IT Network Monitor';
  static const String appVersion = '1.0.0';

  // Monitoring Defaults
  static const int defaultCheckIntervalSeconds = 30;
  static const int defaultTimeoutSeconds = 3;
  static const int defaultFailureThreshold = 3;
  static const int defaultRecoveryThreshold = 2;
  static const int maxWorkerConcurrency = 20;

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleViewer = 'viewer';

  // Local Storage / DB
  static const String dbName = 'it_network_monitor.db';
}
