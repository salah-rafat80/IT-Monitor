import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../topology/domain/services/topology_grouper.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/entities/device_import_commit_payload.dart';
import '../../../network_discovery/domain/entities/device_category.dart';
import '../../../network_discovery/domain/entities/discovery_config_entity.dart';
import '../../../network_discovery/domain/entities/discovery_progress.dart';
import '../../../network_discovery/domain/entities/discovery_scan_job.dart';
import '../../../network_discovery/domain/entities/network_range.dart';
import '../../../network_discovery/domain/entities/review_state.dart';
import '../../../network_discovery/domain/repositories/discovery_repository.dart';
import '../../../network_discovery/domain/services/discovery_coordinator.dart';
import '../../domain/entities/device_status_entity.dart';
import '../../domain/entities/monitored_device.dart';
import '../../domain/entities/monitoring_config.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../../domain/services/monitoring_scheduler.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';
import '../../../../core/config/app_run_mode.dart';
import '../../../factories/domain/entities/factory_entity.dart';
import '../../../factories/domain/repositories/factory_repository.dart';

/// Cryptographically secure user session for the monitoring service.
class ServiceSession {
  final String token;
  final int userId;
  final String username;
  final String role;
  final DateTime createdAt;
  final DateTime expiresAt;

  const ServiceSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get isViewer => role.toLowerCase() == 'viewer';
}

/// Service configuration for port, TLS certificates, and session parameters.
class MonitoringServiceConfig {
  final int port;
  final bool useTls;
  final String? certPath;
  final String? keyPath;
  final String? keyPassword;
  final Duration sessionTimeout;
  final String? customDataDir;
  final bool isDevelopment;

  const MonitoringServiceConfig({
    this.port = 8443,
    this.useTls = true,
    this.certPath,
    this.keyPath,
    this.keyPassword,
    this.sessionTimeout = const Duration(hours: 24),
    this.customDataDir,
    this.isDevelopment = false,
  });

  static MonitoringServiceConfig loadFromEnvironmentOrFile([
    List<String>? args,
  ]) {
    args ??= const [];

    // 1. Check for custom config path in CLI args or env
    String? cliConfigPath;
    for (final arg in args) {
      if (arg.startsWith('--config=')) {
        cliConfigPath = arg.substring(9).trim();
      }
    }

    final configFilePath =
        cliConfigPath ??
        Platform.environment['IT_MONITOR_CONFIG_PATH'] ??
        (Platform.environment['ProgramData'] != null
            ? p.join(
                Platform.environment['ProgramData']!,
                'ITNetworkMonitor',
                'service_config.json',
              )
            : 'service_config.json');

    // Default configuration values (Production defaults: TLS enabled, port 8443, devMode false)
    int port = 8443;
    bool useTls = true;
    final programData = Platform.environment['ProgramData'];
    String? certPath = programData != null
        ? p.join(programData, 'ITNetworkMonitor', 'certs', 'server.crt')
        : p.join(
            'C:',
            'ProgramData',
            'ITNetworkMonitor',
            'certs',
            'server.crt',
          );
    String? keyPath = programData != null
        ? p.join(programData, 'ITNetworkMonitor', 'certs', 'server.key')
        : p.join(
            'C:',
            'ProgramData',
            'ITNetworkMonitor',
            'certs',
            'server.key',
          );
    String? keyPassword;
    Duration sessionTimeout = const Duration(hours: 24);
    String? customDataDir;
    bool isDevelopment = false;

    // 2. Read from config file if exists
    final file = File(configFilePath);
    if (file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (json.containsKey('port')) {
          port = json['port'] as int;
        }
        if (json.containsKey('useTls')) {
          useTls = json['useTls'] as bool;
        }
        if (json.containsKey('certPath')) {
          certPath = json['certPath'] as String?;
        }
        if (json.containsKey('keyPath')) {
          keyPath = json['keyPath'] as String?;
        }
        if (json.containsKey('keyPassword')) {
          keyPassword = json['keyPassword'] as String?;
        }
        if (json.containsKey('sessionTimeoutHours')) {
          sessionTimeout = Duration(hours: json['sessionTimeoutHours'] as int);
        }
        if (json.containsKey('dataDir')) {
          customDataDir = json['dataDir'] as String?;
        }
        if (json.containsKey('developmentMode')) {
          isDevelopment = json['developmentMode'] as bool;
        }
      } catch (_) {}
    }

    // 3. Environment variable overrides
    if (Platform.environment['IT_MONITOR_PORT'] != null) {
      final pVal = int.tryParse(Platform.environment['IT_MONITOR_PORT']!);
      if (pVal != null) port = pVal;
    }
    if (Platform.environment['IT_MONITOR_USE_TLS'] != null) {
      final tlsVal = Platform.environment['IT_MONITOR_USE_TLS']!.toLowerCase();
      useTls = tlsVal == 'true' || tlsVal == '1';
    }
    if (Platform.environment['IT_MONITOR_CERT_PATH'] != null) {
      certPath = Platform.environment['IT_MONITOR_CERT_PATH'];
    }
    if (Platform.environment['IT_MONITOR_KEY_PATH'] != null) {
      keyPath = Platform.environment['IT_MONITOR_KEY_PATH'];
    }
    if (Platform.environment['IT_MONITOR_KEY_PASSWORD'] != null) {
      keyPassword = Platform.environment['IT_MONITOR_KEY_PASSWORD'];
    }
    if (Platform.environment['IT_MONITOR_DATA_DIR'] != null) {
      customDataDir = Platform.environment['IT_MONITOR_DATA_DIR'];
    }
    if (Platform.environment['IT_MONITOR_DEV_MODE'] != null) {
      final dVal = Platform.environment['IT_MONITOR_DEV_MODE']!.toLowerCase();
      isDevelopment = dVal == 'true' || dVal == '1';
    }

    // 4. CLI Argument overrides (Highest Precedence)
    for (final arg in args) {
      if (arg.startsWith('--port=')) {
        final pVal = int.tryParse(arg.substring(7));
        if (pVal != null) port = pVal;
      } else if (arg == '--tls') {
        useTls = true;
      } else if (arg == '--no-tls') {
        useTls = false;
      } else if (arg.startsWith('--cert=')) {
        certPath = arg.substring(7);
      } else if (arg.startsWith('--key=')) {
        keyPath = arg.substring(6);
      } else if (arg.startsWith('--key-password=')) {
        keyPassword = arg.substring(15);
      } else if (arg.startsWith('--data-dir=')) {
        customDataDir = arg.substring(11);
      } else if (arg == '--dev' || arg == '--development') {
        isDevelopment = true;
      }
    }

    return MonitoringServiceConfig(
      port: port,
      useTls: useTls,
      certPath: certPath,
      keyPath: keyPath,
      keyPassword: keyPassword,
      sessionTimeout: sessionTimeout,
      customDataDir: customDataDir,
      isDevelopment: isDevelopment,
    );
  }
}

class MonitoringServiceServer {
  final int port;
  final bool useTls;
  final String? certPath;
  final String? keyPath;
  final String? keyPassword;
  final Duration sessionTimeout;
  final String? customDataDir;
  final bool isDevelopment;

  HttpServer? _server;
  final List<WebSocket> _wsClients = [];
  final Map<WebSocket, String> _wsClientTokens = {};
  final DateTime _startTime = DateTime.now();

  final Map<String, ServiceSession> _activeSessions = {};

  String? _trustedClientToken;
  String? _trustedTokenFilePath;

  String? get trustedClientToken => _trustedClientToken;
  String? get trustedTokenFilePath => _trustedTokenFilePath;
  int? get boundPort => _server?.port;

  StreamSubscription<List<DeviceStatusEntity>>? _statusSub;
  StreamSubscription<DiscoveryProgress>? _discoveryProgressSub;

  String? _resolvedLogFilePath;

  MonitoringServiceServer({
    this.port = 8443,
    this.useTls = true,
    this.certPath,
    this.keyPath,
    this.keyPassword,
    this.sessionTimeout = const Duration(hours: 24),
    this.customDataDir,
    this.isDevelopment = false,
  }) {
    _initLogPath();
  }

  factory MonitoringServiceServer.fromConfig(MonitoringServiceConfig config) {
    return MonitoringServiceServer(
      port: config.port,
      useTls: config.useTls,
      certPath: config.certPath,
      keyPath: config.keyPath,
      keyPassword: config.keyPassword,
      sessionTimeout: config.sessionTimeout,
      customDataDir: config.customDataDir,
      isDevelopment: config.isDevelopment,
    );
  }

  void _initLogPath() {
    try {
      final programData = Platform.environment['ProgramData'];
      final baseDir =
          customDataDir ??
          (programData != null
              ? p.join(programData, 'ITNetworkMonitor')
              : Directory.current.path);
      final logDir = Directory(p.join(baseDir, 'logs'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      _resolvedLogFilePath = p.join(logDir.path, 'monitoring_service.log');
    } catch (_) {
      _resolvedLogFilePath = 'monitoring_service.log';
    }
  }

  Future<void> start() async {
    AppConfig.runMode = AppRunMode.serviceDaemon;
    _log(
      'Initializing IT Network Monitor Service (Port: $port, TLS: $useTls, DevMode: $isDevelopment)...',
    );

    // Production fail-closed security enforcement
    if (!isDevelopment) {
      if (!useTls) {
        final err =
            'Production security violation: Production monitoring service must have TLS enabled. '
            'Unencrypted HTTP transport is forbidden on production network interfaces. '
            'To run unencrypted for local development testing only, pass --dev or configure developmentMode: true.';
        _log('FATAL: $err');
        throw StateError(err);
      }
      if (certPath == null || !File(certPath!).existsSync()) {
        final err =
            'Production security violation: TLS certificate file not found or inaccessible at "$certPath". '
            'In production, valid certificate and private key files are required. '
            'ACTION REQUIRED: Run "provision_tls_certificate.bat" (or "installer\\provision_tls_certificate.ps1") as Administrator '
            'to generate and provision initial production TLS credentials, or place your organization\'s valid server.crt in the certs directory.';
        _log('FATAL: $err');
        throw StateError(err);
      }
      if (keyPath == null || !File(keyPath!).existsSync()) {
        final err =
            'Production security violation: TLS private key file not found or inaccessible at "$keyPath". '
            'In production, valid certificate and private key files are required. '
            'ACTION REQUIRED: Run "provision_tls_certificate.bat" (or "installer\\provision_tls_certificate.ps1") as Administrator '
            'to generate and provision initial production TLS credentials, or place your organization\'s valid server.key in the certs directory.';
        _log('FATAL: $err');
        throw StateError(err);
      }
    }

    // 1. Initialize DI and Database if not already initialized
    if (!getIt.isRegistered<AppDatabase>()) {
      if (customDataDir != null && customDataDir!.trim().isNotEmpty) {
        DatabaseConfig.customDataDir = customDataDir!.trim();
      }
      await configureDependencies();
      _log('Database and dependencies configured successfully.');
    }

    // Ensure authoritative inventory and verified access points are bootstrapped
    if (getIt.isRegistered<DeviceRepository>()) {
      try {
        final devRepo = getIt<DeviceRepository>();
        await devRepo.bootstrapApprovedInventory();
      } catch (e) {
        _log('Warning: Failed to bootstrap approved inventory at startup: $e');
      }
    }
    if (getIt.isRegistered<InfrastructureRepository>()) {
      try {
        final infraRepo = getIt<InfrastructureRepository>();
        await infraRepo.bootstrapVerifiedAccessPoints();
      } catch (e) {
        _log('Warning: Failed to bootstrap verified APs at startup: $e');
      }
    }

    // Reconcile and initialize status rows for any inventory devices missing from device_statuses
    if (getIt.isRegistered<AppDatabase>()) {
      try {
        final db = getIt<AppDatabase>();
        final uninitializedRows = await db
            .customSelect(
              'SELECT d.id FROM devices d LEFT JOIN device_statuses s ON d.id = s.device_id WHERE s.device_id IS NULL',
            )
            .get();
        if (uninitializedRows.isNotEmpty) {
          final now = DateTime.now();
          await db.batch((batch) {
            for (final row in uninitializedRows) {
              final devId = row.read<int>('id');
              batch.insert(
                db.deviceStatuses,
                DeviceStatusesCompanion.insert(
                  deviceId: Value(devId),
                  status: const Value('unknown'),
                  statusChangedAt: Value(now),
                ),
                mode: InsertMode.insertOrIgnore,
              );
            }
          });
          _log(
            'Reconciled and initialized status rows for ${uninitializedRows.length} inventory devices.',
          );
        }
      } catch (e) {
        _log('Warning: Failed to reconcile initial device statuses: $e');
      }
    }

    // 2. Bind HTTP / HTTPS Server
    if (useTls) {
      if (certPath == null || !File(certPath!).existsSync()) {
        throw StateError(
          'TLS enabled but certificate file not found at: $certPath',
        );
      }
      if (keyPath == null || !File(keyPath!).existsSync()) {
        throw StateError(
          'TLS enabled but private key file not found at: $keyPath',
        );
      }

      final securityContext = SecurityContext();
      try {
        securityContext.useCertificateChain(certPath!);
        securityContext.usePrivateKey(keyPath!, password: keyPassword);
      } catch (e) {
        if (Platform.isWindows && !isDevelopment) {
          _log(
            'Warning: Initial TLS credentials load failed ($e). Attempting self-healing...',
          );
          final healed = _trySelfHealTlsCredentials();
          if (healed) {
            try {
              securityContext.useCertificateChain(certPath!);
              securityContext.usePrivateKey(keyPath!, password: keyPassword);
            } catch (e2) {
              final err =
                  'Production security violation: Failed to load TLS certificate chain or private key after self-healing: $e2';
              _log('FATAL: $err');
              throw StateError(err);
            }
          } else {
            final err =
                'Production security violation: Failed to load TLS certificate chain or private key: $e';
            _log('FATAL: $err');
            throw StateError(err);
          }
        } else {
          final err =
              'Production security violation: Failed to load TLS certificate chain or private key: $e';
          _log('FATAL: $err');
          throw StateError(err);
        }
      }

      _server = await HttpServer.bindSecure(
        InternetAddress.anyIPv4,
        port,
        securityContext,
      );
      _log(
        'SECURE TRANSPORT ACTIVE: Authoritative Monitoring Service listening on https://0.0.0.0:$port (WSS enabled). TLS enforced.',
      );
      _publishPublicCertificate();
    } else {
      // Development-only mode: MUST bind strictly to 127.0.0.1 (loopback), NEVER 0.0.0.0
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _log(
        '*** [WARNING] DEVELOPMENT MODE ACTIVE: Bound strictly to localhost (http://127.0.0.1:$port, ws://127.0.0.1:$port). NEVER USE IN PRODUCTION. ***',
      );
      _log('Monitoring Service listening on http://127.0.0.1:$port');
    }

    // 3. Start Monitoring Engine if registered
    if (getIt.isRegistered<MonitoringScheduler>()) {
      final scheduler = getIt<MonitoringScheduler>();
      scheduler.startMonitoring();
      _log('Monitoring Engine Scheduler active.');
    }

    // 4. Setup Broadcast Event Subscriptions
    if (getIt.isRegistered<MonitoringRepository>()) {
      final monitoringRepo = getIt<MonitoringRepository>();
      _statusSub = monitoringRepo.watchAllDeviceStatuses().listen((statuses) {
        _broadcastEvent(
          'device_statuses_updated',
          statuses.map((s) => s.toJson()).toList(),
        );
      });
    }

    if (getIt.isRegistered<DiscoveryCoordinator>()) {
      final discoveryCoordinator = getIt<DiscoveryCoordinator>();
      _discoveryProgressSub = discoveryCoordinator.progressStream.listen((
        prog,
      ) {
        _broadcastEvent('discovery_progress_updated', prog.toJson());
        if (prog.latestDevice != null) {
          _broadcastEvent(
            'discovery_device_found',
            prog.latestDevice!.toJson(),
          );
        }
        if (prog.status == ScanJobStatus.completed) {
          _broadcastEvent('discovery_scan_completed', prog.toJson());
        } else if (prog.status == ScanJobStatus.cancelled) {
          _broadcastEvent('discovery_scan_cancelled', prog.toJson());
        } else if (prog.status == ScanJobStatus.failed) {
          _broadcastEvent('discovery_scan_failed', prog.toJson());
        }
      });
    }

    // 5. Handle Incoming Requests
    _server!.listen(_handleRequest);

    // 6. Provision trusted local client token for local direct-launch
    _provisionLocalTrustedToken();
  }

  void _provisionLocalTrustedToken() {
    _cleanupLocalTrustedToken();

    String? tempPath;
    String? targetPath;
    try {
      final programData = Platform.environment['ProgramData'];
      final baseDir =
          customDataDir ??
          (programData != null
              ? p.join(programData, 'ITNetworkMonitor')
              : Directory.current.path);
      final dir = Directory(baseDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // On Windows production, verify that the dedicated operator group exists.
      // Group creation requires elevation and belongs in the installer/setup phase.
      // The background service must fail closed if the required security group is absent.
      if (Platform.isWindows && !isDevelopment) {
        final groupCheck = Process.runSync('net', [
          'localgroup',
          'ITNetworkMonitorAdministrators',
        ]);
        if (groupCheck.exitCode != 0) {
          final err =
              'Security Violation: Required local Windows security group '
              '"ITNetworkMonitorAdministrators" does not exist. '
              'The service cannot provision trusted client tokens without explicit operator boundary. '
              'Run apply_production_acls.ps1 or the elevated installer to create the group.';
          _log('FATAL: $err');
          throw StateError(err);
        }
      }

      final token = _generateSecureToken();
      targetPath = p.join(baseDir, 'trusted_client.token');
      tempPath = p.join(
        baseDir,
        'trusted_client.token.tmp_${DateTime.now().microsecondsSinceEpoch}',
      );

      final tempFile = File(tempPath);
      // 1. Create empty temporary file in protected service directory
      tempFile.createSync(exclusive: true);

      // 2. Before writing any secret contents, apply restrictive DACL to the empty file on Windows
      if (Platform.isWindows) {
        _applyRestrictedTokenAcls(tempPath);
        // 3. Verify the resulting ACL using Windows security tools before writing secret
        _verifyTokenAcls(tempPath);
      }

      // 4. Only write and flush the token after the temporary file's ACL has been verified
      tempFile.writeAsStringSync(token, flush: true);

      // 5. Windows filesystem replacement semantics:
      // On Win32, moving/renaming across an existing destination file requires unlinking the destination first.
      // Interruption behavior: If an unexpected crash occurs between target deletion and rename completion,
      // the token file is absent upon recovery, which fails closed (unauthenticated) rather than leaving
      // a corrupted or leaked token.
      final targetFile = File(targetPath);
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      tempFile.renameSync(targetPath);

      if (!File(targetPath).existsSync()) {
        throw StateError(
          'Failed to verify presence of target token file after rename: $targetPath',
        );
      }

      // 6. ONLY publish session in-memory after publication on disk is 100% verified and hardened
      final session = ServiceSession(
        token: token,
        userId: 1,
        username: 'Local Administrator (No Interactive Login)',
        role: 'admin',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 365)),
      );
      _activeSessions[token] = session;
      _trustedClientToken = token;
      _trustedTokenFilePath = targetPath;
      _log('Provisioned trusted local client token at: $_trustedTokenFilePath');
    } catch (e) {
      // Fail closed: clean up in-memory references and temporary files on error
      _cleanupLocalTrustedToken();
      if (tempPath != null) {
        try {
          final tf = File(tempPath);
          if (tf.existsSync()) tf.deleteSync();
        } catch (_) {}
      }
      _log(
        'Security Error: Could not safely provision trusted local client token (failing closed): $e',
      );
    }
  }

  void _applyRestrictedTokenAcls(String filePath) {
    bool hasOperatorGroup = false;
    try {
      final res = Process.runSync('net', [
        'localgroup',
        'ITNetworkMonitorAdministrators',
      ]);
      hasOperatorGroup = (res.exitCode == 0);
    } catch (_) {}

    if (!hasOperatorGroup && !isDevelopment) {
      throw StateError(
        'Required Windows security group "ITNetworkMonitorAdministrators" does not exist. '
        'In production, operator group must exist before provisioning trusted client tokens.',
      );
    }

    final grants = [
      filePath,
      '/inheritance:r',
      '/grant',
      'NT AUTHORITY\\SYSTEM:(F)',
      '/grant',
      'BUILTIN\\Administrators:(F)',
    ];

    if (hasOperatorGroup) {
      grants.addAll(['/grant', 'ITNetworkMonitorAdministrators:(R)']);
    }
    if (isDevelopment) {
      final currentUser = Platform.environment['USERNAME'];
      if (currentUser != null && currentUser.isNotEmpty) {
        grants.addAll(['/grant', '$currentUser:(F)']);
      }
    }

    grants.addAll(['/c', '/q']);

    final grantResult = Process.runSync('icacls', grants);
    if (grantResult.exitCode != 0) {
      throw StateError(
        'Failed to apply restrictive ACLs to token: ${grantResult.stderr} ${grantResult.stdout}',
      );
    }

    // Explicitly purge any potential explicit grants for unapproved principals
    final removeResult = Process.runSync('icacls', [
      filePath,
      '/remove:g',
      'BUILTIN\\Users',
      'Everyone',
      'NT AUTHORITY\\Authenticated Users',
      '/c',
      '/q',
    ]);
    if (removeResult.exitCode != 0) {
      final out = '${removeResult.stderr} ${removeResult.stdout}';
      if (!out.contains('No mappings') && !out.contains('0 files')) {
        throw StateError(
          'Failed to remove unapproved principals from token: $out',
        );
      }
    }
  }

  static String? _findAclScriptPath() {
    final candidates = [
      p.join(Directory.current.path, 'installer', 'apply_production_acls.ps1'),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'installer',
        'apply_production_acls.ps1',
      ),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'apply_production_acls.ps1',
      ),
      p.join(
        Platform.environment['ProgramData'] ?? r'C:\ProgramData',
        'ITNetworkMonitor',
        'apply_production_acls.ps1',
      ),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  static String? _findProvisionScriptPath() {
    final candidates = [
      p.join(
        Directory.current.path,
        'installer',
        'provision_tls_certificate.ps1',
      ),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'provision_tls_certificate.ps1',
      ),
      p.join(
        p.dirname(Platform.resolvedExecutable),
        'installer',
        'provision_tls_certificate.ps1',
      ),
      p.join(
        Platform.environment['ProgramData'] ?? r'C:\ProgramData',
        'ITNetworkMonitor',
        'provision_tls_certificate.ps1',
      ),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  void _publishPublicCertificate() {
    try {
      if (certPath == null || !File(certPath!).existsSync()) return;
      if (isDevelopment) return;

      final normCert = p.normalize(certPath!).toLowerCase();
      // Only publish for production service deployments rooted in ProgramData
      if (!normCert.contains('programdata') && customDataDir == null) return;

      final programData = Platform.environment['ProgramData'];
      final baseDir =
          customDataDir ??
          (programData != null
              ? p.join(programData, 'ITNetworkMonitor')
              : Directory.current.path);
      final publicCertPath = p.join(baseDir, 'server.crt');

      if (p.equals(p.normalize(certPath!), p.normalize(publicCertPath))) return;

      final certFile = File(certPath!);
      final certBytes = certFile.readAsBytesSync();
      if (certBytes.isEmpty) return;

      final publicFile = File(publicCertPath);
      publicFile.writeAsBytesSync(certBytes, flush: true);

      if (Platform.isWindows && !isDevelopment) {
        try {
          Process.runSync('icacls', [
            publicCertPath,
            '/grant',
            'ITNetworkMonitorAdministrators:(R)',
            '/c',
            '/q',
          ]);
        } catch (_) {}
      }
      _log('Published operator public certificate to: $publicCertPath');
    } catch (e) {
      _log('Notice: Could not publish public certificate: $e');
    }
  }

  bool _trySelfHealTlsCredentials() {
    try {
      final scriptPath = _findProvisionScriptPath();
      if (scriptPath == null) {
        _log(
          'TLS self-healing skipped: provision_tls_certificate.ps1 not found.',
        );
        return false;
      }

      _log('Executing TLS provisioning script: $scriptPath');
      final res = Process.runSync('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-Force',
        '-AddToTrustedRoot',
      ]);
      _log('TLS provisioning result code: ${res.exitCode}');
      return res.exitCode == 0;
    } catch (e) {
      _log('TLS self-healing error: $e');
      return false;
    }
  }

  @visibleForTesting
  void verifyTokenAclsForTesting(String filePath) {
    _verifyTokenAcls(filePath);
  }

  void _verifyTokenAcls(String filePath) {
    if (!Platform.isWindows) return;

    final scriptPath = _findAclScriptPath();
    final operatorGroup = 'ITNetworkMonitorAdministrators';

    // 1. If apply_production_acls.ps1 is available, reuse canonical policy validator
    if (scriptPath != null) {
      final args = [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-TargetTokenFile',
        filePath,
        '-OperatorGroup',
        operatorGroup,
      ];
      if (isDevelopment) {
        args.add('-DevMode');
        final u = Platform.environment['USERNAME'];
        if (u != null && u.isNotEmpty) {
          args.addAll(['-ServiceUser', u]);
        }
      }
      final scriptResult = Process.runSync('powershell', args);
      if (scriptResult.exitCode == 0) {
        _log(
          '[Security] Verified token file ACL using canonical policy validator: $filePath',
        );
        return;
      } else {
        throw StateError(
          'Security violation: Token ACL rejected by authoritative policy validator:\n'
          '${scriptResult.stdout}\n${scriptResult.stderr}',
        );
      }
    }

    // 2. Authoritative standalone PowerShell validator based on actual SecurityDescriptors, SIDs, and rights.
    // Dynamic values are passed strictly via the process environment map,
    // avoiding PowerShell source string interpolation, argument parsing bugs, and script injection.
    const psScript = r'''
$ErrorActionPreference = 'Stop'

$TargetFilePath = $env:IT_MONITOR_TARGET_TOKEN_FILE
$OperatorGroupName = $env:IT_MONITOR_OPERATOR_GROUP
$IsDevMode = $env:IT_MONITOR_IS_DEV -eq 'true'
$CurrentUsername = $env:IT_MONITOR_CURRENT_USER

$SID_SYSTEM = 'S-1-5-18'
$SID_ADMINS = 'S-1-5-32-544'
$PROHIBITED = @('S-1-5-32-545', 'S-1-1-0', 'S-1-5-11')

# Risky / write-modify rights mask including DeleteSubdirectoriesAndFiles (0x40)
$DELETE_CHILD = [int][System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
$WRITE_MODIFY_MASK = [int][System.Security.AccessControl.FileSystemRights]::Write -bor
                     [int][System.Security.AccessControl.FileSystemRights]::Delete -bor
                     $DELETE_CHILD -bor
                     [int][System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
                     [int][System.Security.AccessControl.FileSystemRights]::TakeOwnership

# Exact allowed operator rights allowlist on token file (Read + Synchronize only)
$OPERATOR_TOKEN_ALLOWED_RIGHTS = [int][System.Security.AccessControl.FileSystemRights]::Read -bor
                                 [int][System.Security.AccessControl.FileSystemRights]::Synchronize

if (-not $TargetFilePath -or -not [System.IO.File]::Exists($TargetFilePath)) {
    throw "Target token file does not exist or is inaccessible: '$TargetFilePath'"
}

$acl = [System.IO.File]::GetAccessControl($TargetFilePath)
if (-not $acl.AreAccessRulesProtected) {
    throw 'DACL inheritance is not disabled (/inheritance:r required).'
}

$operatorSid = $null
try {
    $operatorSid = (New-Object System.Security.Principal.NTAccount($OperatorGroupName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch {
    if (-not $IsDevMode) {
        throw "Could not resolve operator group '$OperatorGroupName' to SID."
    }
}

$currentUserSid = $null
if ($CurrentUsername) {
    try {
        $currentUserSid = (New-Object System.Security.Principal.NTAccount($CurrentUsername)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {}
}

$hasSystem = $false
$hasAdmins = $false
$hasOperator = $false

foreach ($rule in $acl.Access) {
    if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
        throw "Non-Allow ACE found for $($rule.IdentityReference.Value)."
    }
    $sid = try { $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $rule.IdentityReference.Value }
    $rights = $rule.FileSystemRights

    if ($PROHIBITED -contains $sid) {
        throw "Prohibited principal SID $sid has unauthorized rights: $rights."
    }

    if ($sid -eq $SID_SYSTEM) {
        if (-not $rights.HasFlag([System.Security.AccessControl.FileSystemRights]::FullControl)) {
            throw 'SYSTEM has insufficient rights; FullControl required.'
        }
        $hasSystem = $true
        continue
    }

    if ($sid -eq $SID_ADMINS) {
        if (-not $rights.HasFlag([System.Security.AccessControl.FileSystemRights]::FullControl)) {
            throw 'BUILTIN\Administrators has insufficient rights; FullControl required.'
        }
        $hasAdmins = $true
        continue
    }

    if ($operatorSid -and $sid -eq $operatorSid) {
        if (([int]$rights -band -bnot $OPERATOR_TOKEN_ALLOWED_RIGHTS) -ne 0) {
            throw "Operator group has unauthorized rights outside allowlist: $rights."
        }
        if (([int]$rights -band $WRITE_MODIFY_MASK) -ne 0) {
            throw "Operator group has unauthorized write/modify rights: $rights."
        }
        if ($rights.HasFlag([System.Security.AccessControl.FileSystemRights]::ExecuteFile)) {
            throw "Operator group has unauthorized execute rights: $rights."
        }
        if (-not $rights.HasFlag([System.Security.AccessControl.FileSystemRights]::Read)) {
            throw "Operator group missing Read rights: $rights."
        }
        if ($rule.InheritanceFlags -ne [System.Security.AccessControl.InheritanceFlags]::None -or
            $rule.PropagationFlags -ne [System.Security.AccessControl.PropagationFlags]::None) {
            throw 'Operator group must have non-inheriting ACE.'
        }
        $hasOperator = $true
        continue
    }

    if ($IsDevMode -and $currentUserSid -and $sid -eq $currentUserSid) {
        continue
    }

    throw "Unexpected unapproved principal with SID $sid (Name: $($rule.IdentityReference.Value))."
}

if (-not $hasSystem) { throw 'Missing required FullControl ACE for SYSTEM.' }
if (-not $hasAdmins) { throw 'Missing required FullControl ACE for BUILTIN\Administrators.' }
if (-not $IsDevMode -and -not $hasOperator) { throw "Missing required Read ACE for operator group '$OperatorGroupName'." }
Write-Output 'OK'
''';

    final envMap = {
      'IT_MONITOR_TARGET_TOKEN_FILE': filePath,
      'IT_MONITOR_OPERATOR_GROUP': operatorGroup,
      'IT_MONITOR_IS_DEV': isDevelopment ? 'true' : 'false',
      'IT_MONITOR_CURRENT_USER': Platform.environment['USERNAME'] ?? '',
    };

    final result = Process.runSync('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      psScript,
    ], environment: envMap);

    if (result.exitCode != 0) {
      throw StateError(
        'Security violation: Token ACL inspection failed or rejected by authoritative DACL validator:\n'
        '${result.stderr}\n${result.stdout}',
      );
    }
  }

  void _cleanupLocalTrustedToken() {
    if (_trustedClientToken != null) {
      _activeSessions.remove(_trustedClientToken);
      _trustedClientToken = null;
    }
    if (_trustedTokenFilePath != null) {
      try {
        final f = File(_trustedTokenFilePath!);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
      _trustedTokenFilePath = null;
    }
  }

  // --- Session & Security Helpers ---

  /// Programmatically registers an authorized machine session token (for provisioning, IPC, tests).
  void registerAuthorizedSession({
    required String token,
    required String username,
    String role = 'admin',
    int userId = 1,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now();
    _activeSessions[token] = ServiceSession(
      token: token,
      userId: userId,
      username: username,
      role: role,
      createdAt: now,
      expiresAt: expiresAt ?? now.add(sessionTimeout),
    );
  }

  static String _generateSecureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  ServiceSession? _authenticateRequest(HttpRequest request) {
    // 1. Check Authorization: Bearer <token>
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    String? token;
    if (authHeader != null && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7).trim();
    }

    if (token == null || token.isEmpty) {
      return null;
    }

    final session = _activeSessions[token];
    if (session == null) {
      return null;
    }

    // Check expiration
    if (session.isExpired) {
      _activeSessions.remove(token);
      return null;
    }

    return session;
  }

  bool _isAdmin(ServiceSession? session) {
    return session != null && !session.isExpired && session.isAdmin;
  }

  // --- Request Routing ---

  Future<void> _handleRequest(HttpRequest request) async {
    // Security & CORS headers - restrict origin to local origins (no wildcard *)
    final origin = request.headers.value('Origin');
    if (origin != null &&
        (origin.startsWith('http://localhost') ||
            origin.startsWith('https://localhost') ||
            origin.startsWith('http://127.0.0.1') ||
            origin.startsWith('https://127.0.0.1'))) {
      request.response.headers.add('Access-Control-Allow-Origin', origin);
      request.response.headers.add('Access-Control-Allow-Credentials', 'true');
    }
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, Authorization',
    );

    if (useTls) {
      request.response.headers.add(
        'Strict-Transport-Security',
        'max-age=31536000; includeSubDomains',
      );
      request.response.headers.add('X-Security-Mode', 'SECURE-TLS');
    } else {
      request.response.headers.add(
        'X-Security-Mode',
        'DEVELOPMENT-UNENCRYPTED',
      );
    }

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // WebSocket Endpoint: Requires authenticated session
    if (path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final session = _authenticateRequest(request);
        if (session == null) {
          _log(
            'Rejected unauthenticated WebSocket connection attempt from ${request.connectionInfo?.remoteAddress.address}',
          );
          request.response.statusCode = HttpStatus.unauthorized;
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Unauthorized: Valid authentication token required for WebSocket stream.',
          }, status: HttpStatus.unauthorized);
          return;
        }

        try {
          final socket = await WebSocketTransformer.upgrade(request);
          _wsClients.add(socket);
          _wsClientTokens[socket] = session.token;
          _log(
            'Client [${session.username}] (${session.role}) connected to WebSocket. Total clients: ${_wsClients.length}',
          );

          // Send initial state snapshot
          final monitoringRepo = getIt<MonitoringRepository>();

          final statusRes = await monitoringRepo.getDeviceStatuses();

          if (statusRes.isSuccess) {
            socket.add(
              jsonEncode({
                'event': 'device_statuses_updated',
                'data': statusRes.dataOrNull!.map((s) => s.toJson()).toList(),
              }),
            );
          }

          socket.listen(
            (data) {},
            onDone: () {
              _wsClients.remove(socket);
              _wsClientTokens.remove(socket);
              _log(
                'Client [${session.username}] disconnected from WebSocket. Total clients: ${_wsClients.length}',
              );
            },
            onError: (err) {
              _wsClients.remove(socket);
              _wsClientTokens.remove(socket);
              _log('WebSocket client error: $err');
            },
          );
        } catch (e) {
          _log('WebSocket upgrade error: $e');
        }
      }
      return;
    }

    // REST API Routes
    try {
      if ((path == '/api/status' || path == '/api/health') &&
          request.method == 'GET') {
        await _jsonResponse(request, {
          'status': 'online',
          'service': 'IT Network Monitoring Service',
          'security': useTls ? 'secure_tls' : 'development_unencrypted',
          'tls_enabled': useTls,
          'uptime_seconds': DateTime.now().difference(_startTime).inSeconds,
          'engine_active':
              getIt.isRegistered<MonitoringScheduler>() &&
              getIt<MonitoringScheduler>().isRunning,
          'connected_clients': _wsClients.length,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else if (path == '/api/auth/logout' && request.method == 'POST') {
        final body = await _readJsonBody(request);
        final authHeader = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        String? token = body['token']?.toString();
        if ((token == null || token.isEmpty) &&
            authHeader != null &&
            authHeader.startsWith('Bearer ')) {
          token = authHeader.substring(7).trim();
        }

        if (token != null) {
          final removed = _activeSessions.remove(token);
          _terminateWebSocketSessions(token);
          _log(
            'Session for user [${removed?.username}] invalidated successfully and active WebSockets terminated.',
          );
        }

        await _jsonResponse(request, {
          'success': true,
          'message': 'Session invalidated',
        });
      } else if ((path == '/api/auth/verify' || path == '/api/auth/session') &&
          request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        await _jsonResponse(request, {
          'success': true,
          'session': {
            'userId': session.userId,
            'username': session.username,
            'role': session.role,
            'expiresAt': session.expiresAt.toIso8601String(),
          },
        });
      } else if (path == '/api/factories' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final includeInactive =
            request.uri.queryParameters['includeInactive'] == 'true';
        final factoryRepo = getIt<FactoryRepository>();
        final res = await factoryRepo.getFactories(
          includeInactive: includeInactive,
        );
        if (res.isSuccess) {
          await _jsonResponse(request, {
            'success': true,
            'factories': res.dataOrNull!.map((f) => f.toJson()).toList(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to list factories',
          }, status: 500);
        }
      } else if (path == '/api/factories' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to create factory',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final factory = FactoryEntity.fromJson(body);
        final factoryRepo = getIt<FactoryRepository>();
        final res = await factoryRepo.createFactory(factory);
        if (res.isSuccess) {
          _broadcastEvent('factory_created', res.dataOrNull!.toJson());
          await _jsonResponse(request, {
            'success': true,
            'factory': res.dataOrNull!.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to create factory',
          }, status: 400);
        }
      } else if (path.startsWith('/api/factories/') &&
          request.method == 'PUT') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to update factory',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final factory = FactoryEntity.fromJson(body);
        final factoryRepo = getIt<FactoryRepository>();
        final res = await factoryRepo.updateFactory(factory);
        if (res.isSuccess) {
          _broadcastEvent('factory_updated', res.dataOrNull!.toJson());
          await _jsonResponse(request, {
            'success': true,
            'factory': res.dataOrNull!.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to update factory',
          }, status: 400);
        }
      } else if (path.startsWith('/api/factories/') &&
          request.method == 'DELETE') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to delete factory',
          }, status: HttpStatus.forbidden);
          return;
        }

        final id = path.substring('/api/factories/'.length).trim();
        final factoryRepo = getIt<FactoryRepository>();
        final res = await factoryRepo.deleteFactory(id);
        if (res.isSuccess) {
          _broadcastEvent('factory_deleted', {'id': id});
          await _jsonResponse(request, {
            'success': true,
            'message': 'Factory deactivated',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to delete factory',
          }, status: 400);
        }
      } else if (path == '/api/devices' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final factoryId = request.uri.queryParameters['factoryId'];
        final deviceRepo = getIt<DeviceRepository>();
        final monitoringRepo = getIt<MonitoringRepository>();

        final devRes = await deviceRepo.getDevices(factoryId: factoryId);
        final statRes = await monitoringRepo.getDeviceStatuses();

        if (devRes.isSuccess && statRes.isSuccess) {
          final statusesMap = {
            for (var s in statRes.dataOrNull!) s.deviceId: s,
          };
          final payload = <Map<String, dynamic>>[];
          for (final d in devRes.dataOrNull!) {
            var st = statusesMap[d.id];
            if (st == null) {
              st = DeviceStatusEntity.initial(d.id);
              await monitoringRepo.saveDeviceStatus(st);
            }
            payload.add({'device': d.toJson(), 'status': st.toJson()});
          }

          await _jsonResponse(request, {'success': true, 'devices': payload});
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Failed to load devices',
          }, status: 500);
        }
      } else if (path == '/api/device-statuses' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final monitoringRepo = getIt<MonitoringRepository>();
        final statRes = await monitoringRepo.getDeviceStatuses();
        if (statRes.isSuccess) {
          final list = statRes.dataOrNull!.map((s) => s.toJson()).toList();
          await _jsonResponse(request, {'success': true, 'statuses': list});
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error':
                statRes.failureOrNull?.message ?? 'Failed to load statuses',
          }, status: 500);
        }
      } else if (path == '/api/devices' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to create device',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final device = DeviceEntity.fromJson(body);
        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.addDevice(device);

        if (res.isSuccess) {
          final created = res.dataOrNull!;
          _broadcastEvent('device_created', created.toJson());
          await _jsonResponse(request, {
            'success': true,
            'device': created.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to add device',
          }, status: 400);
        }
      } else if ((path == '/api/devices' ||
              path.startsWith('/api/devices/update')) &&
          request.method == 'PUT') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to update device',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final device = DeviceEntity.fromJson(body);
        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.updateDevice(device);

        if (res.isSuccess) {
          final updated = res.dataOrNull!;
          _broadcastEvent('device_updated', updated.toJson());
          await _jsonResponse(request, {
            'success': true,
            'device': updated.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to update device',
          }, status: 400);
        }
      } else if (path.startsWith('/api/devices/') &&
          path != '/api/devices/assign-owner' &&
          path != '/api/devices/toggle-monitoring' &&
          path != '/api/devices/import' &&
          request.method == 'DELETE') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to delete device',
          }, status: HttpStatus.forbidden);
          return;
        }

        final idStr = path.substring('/api/devices/'.length);
        final id = int.tryParse(idStr);
        if (id == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Invalid device ID',
          }, status: 400);
          return;
        }

        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.deleteDevice(id);

        if (res.isSuccess) {
          _broadcastEvent('device_deleted', {'deviceId': id});
          await _jsonResponse(request, {
            'success': true,
            'message': 'Device deleted successfully',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to delete device',
          }, status: 400);
        }
      } else if (path == '/api/devices/toggle-monitoring' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to toggle monitoring',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;
        final isMonitored = body['isMonitored'] as bool? ?? true;

        if (deviceId == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId',
          }, status: 400);
          return;
        }

        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.toggleDeviceMonitoring(
          deviceId: deviceId,
          isEnabled: isMonitored,
        );
        if (res.isSuccess) {
          final updated = await deviceRepo.getDeviceById(deviceId);
          _broadcastEvent('device_updated', updated.dataOrNull?.toJson());
          await _jsonResponse(request, {
            'success': true,
            'device': updated.dataOrNull?.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error':
                res.failureOrNull?.message ?? 'Failed to toggle monitoring',
          }, status: 400);
        }
      } else if (path == '/api/devices/import' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to import devices',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceRepo = getIt<DeviceRepository>();
        Result<int> res;

        if (body.containsKey('inserts') || body.containsKey('updates')) {
          final payload = DeviceImportCommitPayload.fromJson(body);
          res = await deviceRepo.commitImportPayload(payload);
        } else {
          final rawDevices = body['devices'] as List<dynamic>? ?? [];
          final devices = rawDevices
              .map((d) => DeviceEntity.fromJson(d as Map<String, dynamic>))
              .toList();
          res = await deviceRepo.commitImport(devices);
        }
        if (res.isSuccess) {
          _broadcastEvent('devices_imported', {'count': res.dataOrNull});
          await _jsonResponse(request, {
            'success': true,
            'importedCount': res.dataOrNull,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to import devices',
          }, status: 400);
        }
      } else if (path == '/api/devices/assign-owner' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to assign device owner',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;
        final ownerName = body['ownerName']?.toString();

        if (deviceId == null || ownerName == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId or ownerName',
          }, status: 400);
          return;
        }

        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.assignDeviceOwner(
          deviceId: deviceId,
          ownerName: ownerName,
          adminUsername: session.username,
        );

        if (res.isSuccess) {
          final updatedDevice = res.dataOrNull!;
          _broadcastEvent('device_updated', updatedDevice.toJson());
          _broadcastEvent('device_owner_changed', {
            'deviceId': deviceId,
            'ownerName': updatedDevice.ownerName,
            'ip': updatedDevice.ip,
          });
          await _jsonResponse(request, {
            'success': true,
            'device': updatedDevice.toJson(),
          });
        } else {
          final statusCode = res.failureOrNull is UnauthorizedFailure
              ? HttpStatus.forbidden
              : (res.failureOrNull is NotFoundFailure
                    ? HttpStatus.notFound
                    : HttpStatus.internalServerError);
          await _jsonResponse(request, {
            'success': false,
            'error':
                res.failureOrNull?.message ?? 'Failed to assign device owner',
          }, status: statusCode);
        }
      } else if (path == '/api/devices/reassign-factory' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to reassign device factory',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final rawIds = body['deviceIds'] as List<dynamic>? ?? [];
        final deviceIds = rawIds.map((id) => int.parse(id.toString())).toList();
        final factoryId = body['factoryId']?.toString() ?? 'unassigned';

        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.reassignDevicesFactory(
          deviceIds: deviceIds,
          targetFactoryId: factoryId,
          adminUsername: session.username,
        );

        if (res.isSuccess) {
          _broadcastEvent('devices_reassigned_factory', {
            'count': res.dataOrNull,
            'targetFactoryId': factoryId,
          });
          await _jsonResponse(request, {
            'success': true,
            'reassignedCount': res.dataOrNull,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to reassign factory',
          }, status: 400);
        }
      } else if (path == '/api/devices/bulk-delete' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to delete devices',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final rawIds = body['deviceIds'] as List<dynamic>? ?? [];
        final deviceIds = rawIds.map((id) => int.parse(id.toString())).toList();

        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.deleteDevices(deviceIds);

        if (res.isSuccess) {
          _broadcastEvent('devices_deleted', {'count': res.dataOrNull});
          await _jsonResponse(request, {
            'success': true,
            'deletedCount': res.dataOrNull,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message ?? 'Failed to delete devices',
          }, status: 400);
        }
      } else if (path == '/api/devices/bulk-update' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to update devices',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final rawIds = body['deviceIds'] as List<dynamic>? ?? [];
        final deviceIds = rawIds.map((id) => int.parse(id.toString())).toList();

        final typeStr = body['type']?.toString();
        final type = typeStr != null ? DeviceType.fromString(typeStr) : null;
        final dept = body['department']?.toString();
        final loc = body['officeLocation']?.toString();
        final vendor = body['vendor']?.toString();
        final isMonitored = body['isMonitored'] as bool?;
        final isEnabled = body['isEnabled'] as bool?;

        final deviceRepo = getIt<DeviceRepository>();
        final res = await deviceRepo.bulkUpdateDevices(
          deviceIds: deviceIds,
          type: type,
          department: dept,
          officeLocation: loc,
          vendor: vendor,
          isMonitored: isMonitored,
          isEnabled: isEnabled,
        );

        if (res.isSuccess) {
          _broadcastEvent('devices_updated', {'count': res.dataOrNull});
          await _jsonResponse(request, {
            'success': true,
            'updatedCount': res.dataOrNull,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error':
                res.failureOrNull?.message ?? 'Failed to bulk update devices',
          }, status: 400);
        }
      } else if (path == '/api/infrastructure/unifi/devices' &&
          request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final factoryId = request.uri.queryParameters['factoryId'];
        final infraRepo = getIt<InfrastructureRepository>();
        final res = await infraRepo.getInfrastructureDevices(
          factoryId: factoryId,
        );
        if (res.isSuccess) {
          final monitoringRepo = getIt<MonitoringRepository>();
          final allStatusesRes = await monitoringRepo.getDeviceStatuses();
          final statusMap = <int, DeviceStatusEntity>{};
          if (allStatusesRes.isSuccess) {
            for (final s in allStatusesRes.dataOrNull!) {
              statusMap[s.deviceId] = s;
            }
          }

          final list = res.dataOrNull!.map((d) {
            final virtualId = 10000 + d.id;
            final st =
                statusMap[virtualId] ?? DeviceStatusEntity.initial(virtualId);
            return {
              'id': d.id,
              'factoryId': d.factoryId,
              'name': d.name,
              'ip': d.ip,
              'mac': d.mac,
              'role': d.role.toValue(),
              'roleDisplayName': d.role.displayName,
              'isCriticalInfrastructure': d.isCriticalInfrastructure,
              'requiresAdminConfirmation': d.requiresAdminConfirmation,
              'linkedSubnets': d.linkedSubnets,
              'controllerUrl': d.controllerUrl,
              'isEnabled': d.isEnabled,
              'isReadOnly': d.isReadOnly,
              'status': st.toJson(),
            };
          }).toList();
          await _jsonResponse(request, {'success': true, 'devices': list});
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message,
          }, status: 500);
        }
      } else if (path == '/api/infrastructure/unifi/devices' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to manage infrastructure',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final infraRepo = getIt<InfrastructureRepository>();
        final factoryId = body['factoryId']?.toString().trim() ?? 'unassigned';
        final name = body['name']?.toString() ?? 'UniFi Device';
        final ip = body['ip']?.toString() ?? '';
        final roleStr = body['deviceRole']?.toString();
        final isCritical = body['isCriticalInfrastructure'] == true;
        final subnets = (body['linkedSubnets'] is List)
            ? (body['linkedSubnets'] as List).map((e) => e.toString()).toList()
            : <String>[];

        final device = UniFiDeviceEntity(
          id: body['id'] is int ? body['id'] as int : 0,
          factoryId: factoryId,
          name: name,
          ip: ip,
          role: UniFiDeviceRole.fromString(roleStr),
          isCriticalInfrastructure: isCritical,
          requiresAdminConfirmation: body['requiresAdminConfirmation'] != false,
          linkedSubnets: subnets,
          controllerUrl: body['controllerUrl']?.toString(),
          createdAt: DateTime.now(),
        );

        final res = await infraRepo.saveInfrastructureDevice(device);
        if (res.isSuccess) {
          _broadcastEvent('infrastructure_updated', {
            'deviceId': res.dataOrNull!.id,
            'ip': res.dataOrNull!.ip,
          });
          await _jsonResponse(request, {
            'success': true,
            'device': {
              'id': res.dataOrNull!.id,
              'name': res.dataOrNull!.name,
              'ip': res.dataOrNull!.ip,
            },
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message,
          }, status: 400);
        }
      } else if (path.startsWith('/api/infrastructure/unifi/devices/') &&
          request.method == 'DELETE') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to delete infrastructure',
          }, status: HttpStatus.forbidden);
          return;
        }

        final idStr = path.substring(
          '/api/infrastructure/unifi/devices/'.length,
        );
        final id = int.tryParse(idStr);
        if (id == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Invalid infrastructure device ID',
          }, status: 400);
          return;
        }

        final infraRepo = getIt<InfrastructureRepository>();
        final res = await infraRepo.deleteInfrastructureDevice(id);
        if (res.isSuccess) {
          _broadcastEvent('infrastructure_deleted', {'deviceId': id});
          await _jsonResponse(request, {
            'success': true,
            'message': 'Infrastructure device deleted',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error':
                res.failureOrNull?.message ??
                'Failed to delete infrastructure device',
          }, status: 400);
        }
      } else if (path == '/api/topology' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final factoryId = request.uri.queryParameters['factoryId'];
        final deviceRepo = getIt<DeviceRepository>();
        final monitoringRepo = getIt<MonitoringRepository>();

        final devRes = await deviceRepo.getDevices(factoryId: factoryId);
        final statRes = await monitoringRepo.getDeviceStatuses();

        if (devRes.isSuccess && statRes.isSuccess) {
          final statusesMap = {
            for (var s in statRes.dataOrNull!) s.deviceId: s,
          };
          final monitoredDevices = devRes.dataOrNull!.map((d) {
            final st = statusesMap[d.id] ?? DeviceStatusEntity.initial(d.id);
            return MonitoredDevice(device: d, status: st);
          }).toList();

          final grouper = getIt<TopologyGrouper>();
          final groups = grouper.group(monitoredDevices);

          await _jsonResponse(request, {
            'success': true,
            'groups': groups
                .map(
                  (g) => {
                    'locationName': g.locationName,
                    'switchGroupsCount': g.switchGroups.length,
                  },
                )
                .toList(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Failed to load topology',
          }, status: 500);
        }
      } else if (path == '/api/settings' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final scheduler = getIt<MonitoringScheduler>();
        final cfg = scheduler.config;
        await _jsonResponse(request, {
          'success': true,
          'config': {
            'checkIntervalSeconds': cfg.checkIntervalSeconds,
            'timeoutSeconds': cfg.timeoutSeconds,
            'failureThreshold': cfg.failureThreshold,
            'recoveryThreshold': cfg.recoveryThreshold,
            'maxConcurrentChecks': cfg.maxConcurrentChecks,
          },
        });
      } else if (path == '/api/settings' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to modify settings',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final scheduler = getIt<MonitoringScheduler>();
        final currentCfg = scheduler.config;

        final newConfig = MonitoringConfig(
          checkIntervalSeconds:
              body['checkIntervalSeconds'] as int? ??
              currentCfg.checkIntervalSeconds,
          timeoutSeconds:
              body['timeoutSeconds'] as int? ?? currentCfg.timeoutSeconds,
          failureThreshold:
              body['failureThreshold'] as int? ?? currentCfg.failureThreshold,
          recoveryThreshold:
              body['recoveryThreshold'] as int? ?? currentCfg.recoveryThreshold,
          maxConcurrentChecks:
              body['maxConcurrentChecks'] as int? ??
              currentCfg.maxConcurrentChecks,
        );

        scheduler.updateConfig(newConfig);
        await _jsonResponse(request, {
          'success': true,
          'message': 'Monitoring configuration updated',
        });
      } else if (path == '/api/monitoring/manual-check' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to trigger manual checks',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;

        if (deviceId != null) {
          final scheduler = getIt<MonitoringScheduler>();
          await scheduler.triggerSingleCheck(deviceId);
          await _jsonResponse(request, {
            'success': true,
            'message': 'Check triggered for device $deviceId',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId',
          }, status: 400);
        }
      } else if (path == '/api/monitoring/toggle-maintenance' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to modify maintenance mode',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;
        final isMaintenance = body['isMaintenance'] as bool? ?? false;

        if (deviceId != null) {
          final monitoringRepo = getIt<MonitoringRepository>();
          await monitoringRepo.setMaintenanceMode(
            deviceId: deviceId,
            isMaintenance: isMaintenance,
          );
          await _jsonResponse(request, {
            'success': true,
            'message': 'Maintenance mode updated',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId',
          }, status: 400);
        }
      } else if (path == '/api/admin/service-config' &&
          request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to view service config',
          }, status: HttpStatus.forbidden);
          return;
        }
        await _jsonResponse(request, {
          'success': true,
          'config': {
            'port': port,
            'useTls': useTls,
            'certPath': certPath,
            'keyPath': keyPath,
            'isDevelopment': isDevelopment,
            'sessionTimeoutHours': sessionTimeout.inHours,
            'customDataDir': customDataDir,
          },
        });
      } else if (path == '/api/admin/service-config' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to modify service config',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final configFilePath =
            Platform.environment['IT_MONITOR_CONFIG_PATH'] ??
            (Platform.environment['ProgramData'] != null
                ? p.join(
                    Platform.environment['ProgramData']!,
                    'ITNetworkMonitor',
                    'service_config.json',
                  )
                : 'service_config.json');

        final file = File(configFilePath);
        Map<String, dynamic> currentContent = {};
        if (file.existsSync()) {
          try {
            currentContent =
                jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          } catch (_) {}
        }

        if (body.containsKey('useTls')) {
          currentContent['useTls'] = body['useTls'];
        }
        if (body.containsKey('port')) {
          currentContent['port'] = body['port'];
        }
        if (body.containsKey('certPath')) {
          currentContent['certPath'] = body['certPath'];
        }
        if (body.containsKey('keyPath')) {
          currentContent['keyPath'] = body['keyPath'];
        }
        if (body.containsKey('developmentMode')) {
          currentContent['developmentMode'] = body['developmentMode'];
        }
        if (body.containsKey('sessionTimeoutHours')) {
          currentContent['sessionTimeoutHours'] = body['sessionTimeoutHours'];
        }

        file.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(currentContent),
        );
        _log(
          'Service configuration updated via admin API by [${session.username}].',
        );

        final restart = body['restart'] == true;
        await _jsonResponse(request, {
          'success': true,
          'message': 'Service configuration updated',
          'restartScheduled': restart,
        });

        if (restart) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _log(
              'Service restart requested via admin API. Terminating process for supervisor recovery...',
            );
            exit(0);
          });
        }
      } else if (path == '/api/admin/service/restart' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to restart service',
          }, status: HttpStatus.forbidden);
          return;
        }

        _log(
          'Service restart triggered via REST API by admin [${session.username}].',
        );
        await _jsonResponse(request, {
          'success': true,
          'message': 'Service shutting down for supervisor restart.',
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          exit(0);
        });
      } else if (path == '/api/discovery/config' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final discoveryRepo = getIt<DiscoveryRepository>();
        final configRes = await discoveryRepo.getConfig();
        if (configRes.isSuccess) {
          await _jsonResponse(request, {
            'success': true,
            'config': configRes.dataOrNull!.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': configRes.failureOrNull?.message,
          }, status: 500);
        }
      } else if (path == '/api/discovery/config' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to configure discovery',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final discoveryRepo = getIt<DiscoveryRepository>();
        final currentConfigRes = await discoveryRepo.getConfig();
        final currentConfig =
            currentConfigRes.dataOrNull ?? DiscoveryConfigEntity.initial();

        List<NetworkRange>? newRanges;
        if (body['networkRanges'] is List) {
          newRanges = (body['networkRanges'] as List<dynamic>)
              .map((e) => NetworkRange.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (body['authorizedRanges'] is List) {
          newRanges = (body['authorizedRanges'] as List<dynamic>)
              .map((e) => NetworkRange.parse(e.toString()))
              .whereType<NetworkRange>()
              .toList();
        }

        final updated = currentConfig.copyWith(
          networkRanges: newRanges,
          enabledStrategies: (body['enabledStrategies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          maxConcurrency: body['maxConcurrency'] as int?,
          timeoutSeconds: body['timeoutSeconds'] as int?,
          updatedAt: DateTime.now(),
        );

        final saveRes = await discoveryRepo.saveConfig(updated);
        if (saveRes.isSuccess) {
          _broadcastEvent('discovery_config_updated', {
            'config': updated.toJson(),
          });
        }
        await _jsonResponse(request, {
          'success': saveRes.isSuccess,
          'message': saveRes.isSuccess
              ? 'Discovery config updated'
              : saveRes.failureOrNull?.message,
        });
      } else if (path == '/api/discovery/ranges' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final factoryId = request.uri.queryParameters['factoryId'];
        final discoveryRepo = getIt<DiscoveryRepository>();
        final rangesRes = await discoveryRepo.getRanges(factoryId: factoryId);
        if (rangesRes.isSuccess) {
          await _jsonResponse(request, {
            'success': true,
            'ranges':
                rangesRes.dataOrNull?.map((r) => r.toJson()).toList() ?? [],
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': rangesRes.failureOrNull?.message,
          }, status: 500);
        }
      } else if (path == '/api/discovery/ranges' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to add discovery ranges',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final rawCidr = body['cidr']?.toString();
        if (rawCidr == null || rawCidr.trim().isEmpty) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'CIDR range is required (e.g. 10.10.20.0/24)',
          }, status: 400);
          return;
        }

        final parsed = NetworkRange.tryParse(rawCidr.trim());
        if (parsed == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Invalid CIDR format. Prefix must be between /16 and /32.',
          }, status: 400);
          return;
        }

        final factoryId = body['factoryId']?.toString().trim();
        if (factoryId == null ||
            factoryId.isEmpty ||
            factoryId.toLowerCase() == 'unassigned') {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'A valid, active factoryId is required to add a network range. '
                'Range creation requires explicit factory selection.',
          }, status: 400);
          return;
        }

        final factoryRepo = getIt.isRegistered<FactoryRepository>()
            ? getIt<FactoryRepository>()
            : null;
        if (factoryRepo != null) {
          final factRes = await factoryRepo.getFactoryById(factoryId);
          final factory = factRes.dataOrNull;
          if (factRes.isFailure || factory == null) {
            await _jsonResponse(request, {
              'success': false,
              'error': 'Factory "$factoryId" does not exist.',
            }, status: 400);
            return;
          }
          if (!factory.isActive) {
            await _jsonResponse(request, {
              'success': false,
              'error':
                  'Factory "${factory.name}" ($factoryId) is inactive. '
                  'Ranges cannot be added to inactive factories.',
            }, status: 400);
            return;
          }
        }

        final name = body['name']?.toString().trim();
        final isEnabled = body['isEnabled'] is bool
            ? body['isEnabled'] as bool
            : true;
        final range = parsed.copyWith(
          factoryId: factoryId,
          name: (name != null && name.isNotEmpty) ? name : null,
          isEnabled: isEnabled,
          createdAt: DateTime.now(),
        );

        final discoveryRepo = getIt<DiscoveryRepository>();
        final addRes = await discoveryRepo.addRange(range);
        if (addRes.isSuccess) {
          final configRes = await discoveryRepo.getConfig();
          if (configRes.isSuccess) {
            _broadcastEvent('discovery_config_updated', {
              'config': configRes.dataOrNull!.toJson(),
              'range': range.toJson(),
            });
          }
          await _jsonResponse(request, {
            'success': true,
            'range': range.toJson(),
            'message': 'Range ${range.cidr} added successfully',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': addRes.failureOrNull?.message,
          }, status: 400);
        }
      } else if ((path == '/api/discovery/ranges/update' &&
              request.method == 'POST') ||
          (path == '/api/discovery/ranges' && request.method == 'PUT')) {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to update discovery ranges',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final rawCidr = body['cidr']?.toString();
        if (rawCidr == null || rawCidr.trim().isEmpty) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'CIDR range is required',
          }, status: 400);
          return;
        }

        final parsed = NetworkRange.tryParse(rawCidr.trim());
        if (parsed == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Invalid CIDR format',
          }, status: 400);
          return;
        }

        final id = body['id']?.toString() ?? parsed.id;
        final factoryId = body['factoryId']?.toString().trim();
        if (factoryId == null ||
            factoryId.isEmpty ||
            factoryId.toLowerCase() == 'unassigned') {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'A valid, active factoryId is required to update a network range.',
          }, status: 400);
          return;
        }

        final factoryRepo = getIt.isRegistered<FactoryRepository>()
            ? getIt<FactoryRepository>()
            : null;
        if (factoryRepo != null) {
          final factRes = await factoryRepo.getFactoryById(factoryId);
          final factory = factRes.dataOrNull;
          if (factRes.isFailure || factory == null) {
            await _jsonResponse(request, {
              'success': false,
              'error': 'Factory "$factoryId" does not exist.',
            }, status: 400);
            return;
          }
          if (!factory.isActive) {
            await _jsonResponse(request, {
              'success': false,
              'error': 'Factory "${factory.name}" ($factoryId) is inactive.',
            }, status: 400);
            return;
          }
        }

        final name = body['name']?.toString().trim();
        final isEnabled = body['isEnabled'] is bool
            ? body['isEnabled'] as bool
            : true;
        final range = parsed.copyWith(
          id: id,
          factoryId: factoryId,
          name: (name != null && name.isNotEmpty) ? name : null,
          isEnabled: isEnabled,
          updatedAt: DateTime.now(),
        );

        final discoveryRepo = getIt<DiscoveryRepository>();
        final updateRes = await discoveryRepo.updateRange(range);
        if (updateRes.isSuccess) {
          final configRes = await discoveryRepo.getConfig();
          if (configRes.isSuccess) {
            _broadcastEvent('discovery_config_updated', {
              'config': configRes.dataOrNull!.toJson(),
              'range': range.toJson(),
            });
          }
          await _jsonResponse(request, {
            'success': true,
            'range': range.toJson(),
            'message': 'Range ${range.cidr} updated successfully',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': updateRes.failureOrNull?.message,
          }, status: 400);
        }
      } else if (path.startsWith('/api/discovery/ranges') &&
          request.method == 'DELETE') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to delete discovery ranges',
          }, status: HttpStatus.forbidden);
          return;
        }

        String? rangeId;
        final parts = path.split('/').where((p) => p.isNotEmpty).toList();
        if (parts.length >= 4) {
          rangeId = Uri.decodeComponent(parts[3]);
        }
        rangeId ??=
            request.uri.queryParameters['id'] ??
            request.uri.queryParameters['cidr'];
        if (rangeId == null || rangeId.trim().isEmpty) {
          final body = await _readJsonBody(request);
          rangeId = body['id']?.toString() ?? body['cidr']?.toString();
        }

        if (rangeId == null || rangeId.trim().isEmpty) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Range ID or CIDR required to delete',
          }, status: 400);
          return;
        }

        final discoveryRepo = getIt<DiscoveryRepository>();
        final delRes = await discoveryRepo.deleteRange(rangeId.trim());
        if (delRes.isSuccess) {
          final configRes = await discoveryRepo.getConfig();
          if (configRes.isSuccess) {
            _broadcastEvent('discovery_config_updated', {
              'config': configRes.dataOrNull!.toJson(),
              'deletedRangeId': rangeId,
            });
          }
          await _jsonResponse(request, {
            'success': true,
            'message': 'Range deleted successfully',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': delRes.failureOrNull?.message,
          }, status: 400);
        }
      } else if (path == '/api/discovery/start' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to start discovery scan',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final rawFactoryId = body['factoryId']?.toString().trim();
        if (rawFactoryId == null ||
            rawFactoryId.isEmpty ||
            rawFactoryId.toLowerCase() == 'unassigned') {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'A valid, active factoryId is required to start a discovery scan. '
                'Consolidated or unassigned scans are forbidden.',
          }, status: 400);
          return;
        }

        final factoryRepo = getIt.isRegistered<FactoryRepository>()
            ? getIt<FactoryRepository>()
            : null;
        if (factoryRepo != null) {
          final factRes = await factoryRepo.getFactoryById(rawFactoryId);
          final factory = factRes.dataOrNull;
          if (factRes.isFailure || factory == null) {
            await _jsonResponse(request, {
              'success': false,
              'error': 'Factory "$rawFactoryId" does not exist.',
            }, status: 400);
            return;
          }
          if (!factory.isActive) {
            await _jsonResponse(request, {
              'success': false,
              'error':
                  'Factory "${factory.name}" ($rawFactoryId) is inactive. '
                  'Discovery scans cannot be launched for inactive factories.',
            }, status: 400);
            return;
          }
        }

        final ranges =
            ((body['ranges'] ?? body['requestedRanges']) as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList();
        final strategies = (body['strategies'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final concurrency = body['concurrency'] as int?;
        final timeout = body['timeoutSeconds'] as int?;

        final coordinator = getIt<DiscoveryCoordinator>();
        final res = await coordinator.startScan(
          factoryId: rawFactoryId,
          requestedRanges: ranges,
          enabledStrategies: strategies,
          maxConcurrency: concurrency,
          timeoutSeconds: timeout,
        );

        if (res.isSuccess) {
          await _jsonResponse(request, {
            'success': true,
            'scan': res.dataOrNull!.toJson(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message,
          }, status: 400);
        }
      } else if (path == '/api/discovery/cancel' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Forbidden: Admin role required to cancel discovery scan',
          }, status: HttpStatus.forbidden);
          return;
        }

        final coordinator = getIt<DiscoveryCoordinator>();
        final res = await coordinator.cancelScan();
        await _jsonResponse(request, {
          'success': res.isSuccess,
          'message': 'Scan cancelled',
        });
      } else if (path == '/api/discovery/status' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final factoryId = request.uri.queryParameters['factoryId'];
        final coordinator = getIt.isRegistered<DiscoveryCoordinator>()
            ? getIt<DiscoveryCoordinator>()
            : null;
        final discoveryRepo = getIt.isRegistered<DiscoveryRepository>()
            ? getIt<DiscoveryRepository>()
            : null;
        final latestJob = discoveryRepo != null
            ? await discoveryRepo.getLatestScanJob(factoryId: factoryId)
            : null;

        await _jsonResponse(request, {
          'success': true,
          'isScanning': coordinator?.isScanning ?? false,
          'activeScanId': coordinator?.activeScanId,
          'latestScan': latestJob?.dataOrNull?.toJson(),
        });
      } else if (path == '/api/discovery/devices' && request.method == 'GET') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final factoryId = request.uri.queryParameters['factoryId'];
        final discoveryRepo = getIt<DiscoveryRepository>();
        final scanIdStr = request.uri.queryParameters['scanId'];
        final scanId = scanIdStr != null ? int.tryParse(scanIdStr) : null;

        final res = await discoveryRepo.getDiscoveredDevices(
          factoryId: factoryId,
          scanId: scanId,
        );
        if (res.isSuccess) {
          await _jsonResponse(request, {
            'success': true,
            'devices': res.dataOrNull!.map((d) => d.toJson()).toList(),
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message,
          }, status: 500);
        }
      } else if (path == '/api/discovery/approve' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to approve discovered devices',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;
        final ownerName = body['ownerName']?.toString();
        final department = body['department']?.toString();
        final deviceName = body['deviceName']?.toString();
        final location = body['location']?.toString();
        final categoryStr = body['category']?.toString();
        final isMonitoredVal = body['isMonitored'] as bool?;
        final vendor = body['vendor']?.toString();
        final model = body['model']?.toString();
        final notes = body['notes']?.toString();

        if (deviceId == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId',
          }, status: 400);
          return;
        }

        final discoveryRepo = getIt<DiscoveryRepository>();
        final devRes = await discoveryRepo.getDiscoveredDevices();
        final discovered = devRes.dataOrNull
            ?.where((d) => d.id == deviceId)
            .firstOrNull;

        if (discovered == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Discovered device not found',
          }, status: 404);
          return;
        }

        final cat = categoryStr != null
            ? DeviceCategory.fromString(categoryStr)
            : discovered.effectiveCategory;
        final deviceType = DeviceType.fromString(cat.toValue());

        final owner = (ownerName != null && ownerName.trim().isNotEmpty)
            ? ownerName.trim()
            : 'Unassigned';
        final dept = (department != null && department.trim().isNotEmpty)
            ? department.trim()
            : 'General';
        final devName = (deviceName != null && deviceName.trim().isNotEmpty)
            ? deviceName.trim()
            : (discovered.hostname?.trim().isNotEmpty == true
                  ? discovered.hostname!.trim()
                  : '${deviceType.displayName}-${discovered.ip.replaceAll('.', '-')}');

        final deviceRepo = getIt<DeviceRepository>();
        final existingDevicesRes = await deviceRepo.getDevices(
          factoryId: discovered.factoryId,
        );
        final existingDevices = existingDevicesRes.dataOrNull ?? [];
        final existing = existingDevices
            .where(
              (d) =>
                  d.factoryId == discovered.factoryId &&
                  d.ip.trim() == discovered.ip.trim(),
            )
            .firstOrNull;

        int? savedId;
        final shouldMonitor = isMonitoredVal ?? deviceType.isMonitoredByDefault;

        if (existing != null) {
          final updated = existing.copyWith(
            name: devName,
            type: deviceType,
            ownerName: owner != 'Unassigned' ? owner : existing.ownerName,
            department: dept != 'General' ? dept : existing.department,
            officeLocation: location?.trim().isNotEmpty == true
                ? location!.trim()
                : existing.officeLocation,
            vendor: vendor?.trim().isNotEmpty == true
                ? vendor!.trim()
                : (discovered.vendor ?? existing.vendor),
            model: model?.trim().isNotEmpty == true
                ? model!.trim()
                : existing.model,
            mac: discovered.mac ?? existing.mac,
            hostname: discovered.hostname ?? existing.hostname,
            notes: notes?.trim().isNotEmpty == true
                ? notes!.trim()
                : existing.notes,
            isMonitored: shouldMonitor,
            updatedAt: DateTime.now(),
          );
          final updateRes = await deviceRepo.updateDevice(updated);
          if (updateRes.isFailure) {
            await _jsonResponse(request, {
              'success': false,
              'error': updateRes.failureOrNull?.message,
            }, status: 400);
            return;
          }
          savedId = existing.id;
        } else {
          final createRes = await deviceRepo.addDevice(
            DeviceEntity(
              id: 0,
              factoryId: discovered.factoryId,
              name: devName,
              type: deviceType,
              ip: discovered.ip,
              ownerName: owner,
              department: dept,
              officeLocation: location?.trim().isNotEmpty == true
                  ? location!.trim()
                  : null,
              vendor: vendor?.trim().isNotEmpty == true
                  ? vendor!.trim()
                  : discovered.vendor,
              model: model?.trim().isNotEmpty == true ? model!.trim() : null,
              mac: discovered.mac,
              hostname: discovered.hostname,
              notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
              isMonitored: shouldMonitor,
              createdAt: DateTime.now(),
            ),
          );

          if (createRes.isFailure) {
            await _jsonResponse(request, {
              'success': false,
              'error': createRes.failureOrNull?.message,
            }, status: 400);
            return;
          }
          savedId = createRes.dataOrNull?.id;
        }

        await discoveryRepo.updateDeviceReview(
          deviceId: deviceId,
          state: ReviewState.approved,
          confirmedCategory: cat,
        );

        await discoveryRepo.saveDiscoveredDevice(
          discovered.copyWith(
            reviewState: ReviewState.approved,
            adminConfirmedCategory: cat,
            associatedDeviceId: savedId,
          ),
        );

        await _jsonResponse(request, {
          'success': true,
          'message':
              'Asset approved and permanently saved to authoritative inventory',
          'savedDeviceId': savedId,
        });
      } else if (path == '/api/discovery/reject' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to reject discovered devices',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;
        if (deviceId != null) {
          final discoveryRepo = getIt<DiscoveryRepository>();
          await discoveryRepo.updateDeviceReview(
            deviceId: deviceId,
            state: ReviewState.rejected,
          );
          await _jsonResponse(request, {
            'success': true,
            'message': 'Device rejected',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId',
          }, status: 400);
        }
      } else if (path == '/api/discovery/override-category' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }
        if (!_isAdmin(session)) {
          await _jsonResponse(request, {
            'success': false,
            'error':
                'Forbidden: Admin role required to override classification',
          }, status: HttpStatus.forbidden);
          return;
        }

        final body = await _readJsonBody(request);
        final deviceId = body['deviceId'] as int?;
        final catStr = body['category']?.toString();
        if (deviceId != null && catStr != null) {
          final category = DeviceCategory.fromString(catStr);
          final discoveryRepo = getIt<DiscoveryRepository>();
          await discoveryRepo.updateDeviceReview(
            deviceId: deviceId,
            state: ReviewState.pendingReview,
            confirmedCategory: category,
          );
          await _jsonResponse(request, {
            'success': true,
            'message': 'Classification updated',
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing deviceId or category',
          }, status: 400);
        }
      } else {
        await _jsonResponse(request, {
          'error': 'Route not found: $path',
        }, status: 404);
      }
    } catch (e, st) {
      _log('API Error on $path: $e\n$st');
      await _jsonResponse(request, {
        'error': 'Internal server error: $e',
      }, status: 500);
    }
  }

  void _terminateWebSocketSessions(String token) {
    for (final entry in List.of(_wsClientTokens.entries)) {
      if (entry.value == token) {
        final socket = entry.key;
        _wsClients.remove(socket);
        _wsClientTokens.remove(socket);
        try {
          socket.close(
            WebSocketStatus.policyViolation,
            'Session terminated or revoked',
          );
        } catch (_) {}
      }
    }
  }

  void _broadcastEvent(String eventName, dynamic data) {
    final payload = jsonEncode({'event': eventName, 'data': data});
    for (final entry in List.of(_wsClientTokens.entries)) {
      final client = entry.key;
      final token = entry.value;
      final session = _activeSessions[token];

      if (session == null || session.isExpired) {
        // Session was revoked or expired: terminate connection immediately and do not deliver event!
        _activeSessions.remove(token);
        _wsClients.remove(client);
        _wsClientTokens.remove(client);
        try {
          client.close(
            WebSocketStatus.policyViolation,
            'Session expired or revoked',
          );
        } catch (_) {}
        continue;
      }

      try {
        client.add(payload);
      } catch (_) {
        _wsClients.remove(client);
        _wsClientTokens.remove(client);
      }
    }
  }

  Future<void> _jsonResponse(
    HttpRequest request,
    Map<String, dynamic> jsonMap, {
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(jsonMap));
    await request.response.close();
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.trim().isEmpty) return {};
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Logs messages with redaction for tokens, passwords, private keys, and sensitive credentials.
  void _log(String message) {
    final redacted = message
        .replaceAllMapped(
          RegExp(r'("password"\s*:\s*)"[^"]*"', caseSensitive: false),
          (m) => '${m[1]}"[REDACTED]"',
        )
        .replaceAllMapped(
          RegExp(r'("keyPassword"\s*:\s*)"[^"]*"', caseSensitive: false),
          (m) => '${m[1]}"[REDACTED]"',
        )
        .replaceAllMapped(
          RegExp(r'("token"\s*:\s*)"[^"]*"', caseSensitive: false),
          (m) => '${m[1]}"[REDACTED]"',
        )
        .replaceAllMapped(
          RegExp(r'([?&]token=)[^&\s]+', caseSensitive: false),
          (m) => '${m[1]}[REDACTED]',
        )
        .replaceAllMapped(
          RegExp(r'(token=)[a-zA-Z0-9_\-]+', caseSensitive: false),
          (m) => '${m[1]}[REDACTED]',
        )
        .replaceAllMapped(
          RegExp(r'(password=)[^&\s]+', caseSensitive: false),
          (m) => '${m[1]}[REDACTED]',
        )
        .replaceAllMapped(
          RegExp(r'(keyPassword=)[^&\s]+', caseSensitive: false),
          (m) => '${m[1]}[REDACTED]',
        )
        .replaceAllMapped(
          RegExp(r'Bearer\s+[a-zA-Z0-9_\-\.]+', caseSensitive: false),
          (m) => 'Bearer [REDACTED]',
        )
        .replaceAllMapped(
          RegExp(
            r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
          ),
          (_) => '[REDACTED PRIVATE KEY]',
        );

    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [MonitoringService] $redacted';
    // ignore: avoid_print
    print(logLine);

    try {
      if (_resolvedLogFilePath != null) {
        File(
          _resolvedLogFilePath!,
        ).writeAsStringSync('$logLine\n', mode: FileMode.append);
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    _log('Stopping Monitoring Service...');
    _cleanupLocalTrustedToken();
    await _statusSub?.cancel();
    await _discoveryProgressSub?.cancel();
    for (final client in List.of(_wsClients)) {
      try {
        await client.close(
          WebSocketStatus.normalClosure,
          'Service shutting down',
        );
      } catch (_) {}
    }
    _wsClients.clear();
    _wsClientTokens.clear();
    await _server?.close(force: true);
    _log('Monitoring Service stopped cleanly.');
  }
}
