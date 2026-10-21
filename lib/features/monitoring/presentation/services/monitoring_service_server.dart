import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/password_hash.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../incidents/domain/entities/incident_entity.dart';
import '../../../incidents/domain/repositories/incident_repository.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/domain/repositories/report_repository.dart';
import '../../../topology/domain/services/topology_grouper.dart';
import '../../../devices/domain/entities/device_entity.dart';
import '../../../network_discovery/domain/entities/device_category.dart';
import '../../../network_discovery/domain/entities/discovery_config_entity.dart';
import '../../../network_discovery/domain/entities/discovery_progress.dart';
import '../../../network_discovery/domain/entities/discovery_scan_job.dart';
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
  final DateTime _startTime = DateTime.now();

  final Map<String, ServiceSession> _activeSessions = {};

  StreamSubscription<List<DeviceStatusEntity>>? _statusSub;
  StreamSubscription<List<IncidentEntity>>? _incidentSub;
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
            'In production, valid certificate and private key files are required. Ensure certificate exists and '
            'the service account has read access.';
        _log('FATAL: $err');
        throw StateError(err);
      }
      if (keyPath == null || !File(keyPath!).existsSync()) {
        final err =
            'Production security violation: TLS private key file not found or inaccessible at "$keyPath". '
            'In production, valid certificate and private key files are required. Ensure private key exists and '
            'the service account has read access.';
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

    // 2. Start Monitoring Engine if registered
    if (getIt.isRegistered<MonitoringScheduler>()) {
      final scheduler = getIt<MonitoringScheduler>();
      scheduler.startMonitoring();
      _log('Monitoring Engine Scheduler active.');
    }

    // 3. Bind HTTP / HTTPS Server
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
        final err =
            'Production security violation: Failed to load TLS certificate chain or private key: $e';
        _log('FATAL: $err');
        throw StateError(err);
      }

      _server = await HttpServer.bindSecure(
        InternetAddress.anyIPv4,
        port,
        securityContext,
      );
      _log(
        'SECURE TRANSPORT ACTIVE: Authoritative Monitoring Service listening on https://0.0.0.0:$port (WSS enabled). TLS enforced.',
      );
    } else {
      // Development-only mode: MUST bind strictly to 127.0.0.1 (loopback), NEVER 0.0.0.0
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _log(
        '*** [WARNING] DEVELOPMENT MODE ACTIVE: Bound strictly to localhost (http://127.0.0.1:$port, ws://127.0.0.1:$port). NEVER USE IN PRODUCTION. ***',
      );
      _log('Monitoring Service listening on http://127.0.0.1:$port');
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

    if (getIt.isRegistered<IncidentRepository>()) {
      final incidentRepo = getIt<IncidentRepository>();
      _incidentSub = incidentRepo.watchActiveIncidents().listen((incidents) {
        _broadcastEvent(
          'active_incidents_updated',
          incidents.map((i) => i.toJson()).toList(),
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
  }

  // --- Session & Security Helpers ---

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

    // 2. Fallback to query parameter ?token= (used for WebSocket upgrades)
    if (token == null || token.isEmpty) {
      token = request.uri.queryParameters['token'];
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
    // Security & CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, PUT, DELETE, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, Authorization, X-User-Role',
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
          _log(
            'Client [${session.username}] (${session.role}) connected to WebSocket. Total clients: ${_wsClients.length}',
          );

          // Send initial state snapshot
          final monitoringRepo = getIt<MonitoringRepository>();
          final incidentRepo = getIt<IncidentRepository>();

          final statusRes = await monitoringRepo.getDeviceStatuses();
          final incidentRes = await incidentRepo.getActiveIncidents();

          if (statusRes.isSuccess) {
            socket.add(
              jsonEncode({
                'event': 'device_statuses_updated',
                'data': statusRes.dataOrNull!.map((s) => s.toJson()).toList(),
              }),
            );
          }

          if (incidentRes.isSuccess) {
            socket.add(
              jsonEncode({
                'event': 'active_incidents_updated',
                'data': incidentRes.dataOrNull!.map((i) => i.toJson()).toList(),
              }),
            );
          }

          socket.listen(
            (data) {},
            onDone: () {
              _wsClients.remove(socket);
              _log(
                'Client [${session.username}] disconnected from WebSocket. Total clients: ${_wsClients.length}',
              );
            },
            onError: (err) {
              _wsClients.remove(socket);
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
      if (path == '/api/status' && request.method == 'GET') {
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
          'active_sessions': _activeSessions.length,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else if (path == '/api/auth/login' && request.method == 'POST') {
        final body = await _readJsonBody(request);
        final username = body['username']?.toString() ?? '';
        final password = body['password']?.toString() ?? '';

        final db = getIt<AppDatabase>();
        final user = await (db.select(
          db.users,
        )..where((u) => u.username.equals(username))).getSingleOrNull();

        if (user != null &&
            user.isEnabled &&
            PasswordHash.verifyPassword(password, user.passwordHash)) {
          final token = _generateSecureToken();
          final session = ServiceSession(
            token: token,
            userId: user.id,
            username: user.username,
            role: user.role,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(sessionTimeout),
          );

          _activeSessions[token] = session;
          _log(
            'User [${user.username}] successfully authenticated with role [${user.role}]. Active sessions: ${_activeSessions.length}',
          );

          await _jsonResponse(request, {
            'success': true,
            'token': token,
            'expiresAt': session.expiresAt.toIso8601String(),
            'user': {
              'id': user.id,
              'username': user.username,
              'role': user.role,
            },
          });
        } else {
          _log('Failed authentication attempt for username: $username');
          await _jsonResponse(request, {
            'success': false,
            'error': 'Invalid username or password',
          }, status: HttpStatus.unauthorized);
        }
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

        if (token != null && _activeSessions.containsKey(token)) {
          final removed = _activeSessions.remove(token);
          _log(
            'Session for user [${removed?.username}] invalidated successfully.',
          );
        }

        await _jsonResponse(request, {
          'success': true,
          'message': 'Session invalidated',
        });
      } else if (path == '/api/devices' && request.method == 'GET') {
        final deviceRepo = getIt<DeviceRepository>();
        final monitoringRepo = getIt<MonitoringRepository>();

        final devRes = await deviceRepo.getDevices();
        final statRes = await monitoringRepo.getDeviceStatuses();

        if (devRes.isSuccess && statRes.isSuccess) {
          final statusesMap = {
            for (var s in statRes.dataOrNull!) s.deviceId: s,
          };
          final payload = devRes.dataOrNull!.map((d) {
            final st = statusesMap[d.id] ?? DeviceStatusEntity.initial(d.id);
            return {'device': d.toJson(), 'status': st.toJson()};
          }).toList();

          await _jsonResponse(request, {'success': true, 'devices': payload});
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Failed to load devices',
          }, status: 500);
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
      } else if (path == '/api/infrastructure/unifi/devices' &&
          request.method == 'GET') {
        final infraRepo = getIt<InfrastructureRepository>();
        final res = await infraRepo.getInfrastructureDevices();
        if (res.isSuccess) {
          final list = res.dataOrNull!
              .map(
                (d) => {
                  'id': d.id,
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
                },
              )
              .toList();
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
        final name = body['name']?.toString() ?? 'UniFi Device';
        final ip = body['ip']?.toString() ?? '';
        final roleStr = body['deviceRole']?.toString();
        final isCritical = body['isCriticalInfrastructure'] == true;
        final subnets = (body['linkedSubnets'] is List)
            ? (body['linkedSubnets'] as List).map((e) => e.toString()).toList()
            : <String>[];

        final device = UniFiDeviceEntity(
          id: body['id'] is int ? body['id'] as int : 0,
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
      } else if (path == '/api/incidents' && request.method == 'GET') {
        final incidentRepo = getIt<IncidentRepository>();
        final activeRes = await incidentRepo.getActiveIncidents();
        final historyRes = await incidentRepo.getIncidentHistory();

        await _jsonResponse(request, {
          'success': true,
          'active': activeRes.isSuccess
              ? activeRes.dataOrNull!.map((i) => i.toJson()).toList()
              : [],
          'history': historyRes.isSuccess
              ? historyRes.dataOrNull!.map((i) => i.toJson()).toList()
              : [],
        });
      } else if (path == '/api/topology' && request.method == 'GET') {
        final deviceRepo = getIt<DeviceRepository>();
        final monitoringRepo = getIt<MonitoringRepository>();

        final devRes = await deviceRepo.getDevices();
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
      } else if (path == '/api/incidents/acknowledge' &&
          request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final body = await _readJsonBody(request);
        final incidentId = body['incidentId'] as int?;
        final ackBy = session.username;

        if (incidentId != null) {
          final incidentRepo = getIt<IncidentRepository>();
          final res = await incidentRepo.acknowledgeIncident(
            id: incidentId,
            username: ackBy,
          );
          await _jsonResponse(request, {
            'success': res.isSuccess,
            'message': res.isSuccess
                ? 'Incident acknowledged'
                : res.failureOrNull?.message,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing incidentId',
          }, status: 400);
        }
      } else if (path == '/api/incidents/notes' && request.method == 'POST') {
        final session = _authenticateRequest(request);
        if (session == null) {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Unauthorized: Valid session token required',
          }, status: HttpStatus.unauthorized);
          return;
        }

        final body = await _readJsonBody(request);
        final incidentId = body['incidentId'] as int?;
        final notes = body['notes']?.toString() ?? '';

        if (incidentId != null) {
          final incidentRepo = getIt<IncidentRepository>();
          final res = await incidentRepo.addNote(id: incidentId, note: notes);
          await _jsonResponse(request, {
            'success': res.isSuccess,
            'message': res.isSuccess
                ? 'Notes added'
                : res.failureOrNull?.message,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': 'Missing incidentId',
          }, status: 400);
        }
      } else if (path == '/api/settings' && request.method == 'GET') {
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
      } else if (path == '/api/reports/summary' && request.method == 'GET') {
        final periodStr =
            request.uri.queryParameters['period'] ?? 'last24Hours';
        final period = periodStr == 'last7Days'
            ? ReportPeriod.last7Days
            : (periodStr == 'last30Days'
                  ? ReportPeriod.last30Days
                  : ReportPeriod.last24Hours);

        final reportRepo = getIt<ReportRepository>();
        final res = await reportRepo.generateReport(period);
        if (res.isSuccess) {
          final r = res.dataOrNull!;
          await _jsonResponse(request, {
            'success': true,
            'period': r.period.name,
            'overallAvailabilityPercent': r.overallAvailabilityPercent,
            'totalCheckCount': r.totalCheckCount,
            'successfulCheckCount': r.successfulCheckCount,
            'failedCheckCount': r.failedCheckCount,
            'avgLatencyMs': r.avgLatencyMs,
            'totalIncidents': r.totalIncidents,
          });
        } else {
          await _jsonResponse(request, {
            'success': false,
            'error': res.failureOrNull?.message,
          }, status: 500);
        }
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

        final updated = currentConfig.copyWith(
          authorizedRanges: (body['authorizedRanges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          enabledStrategies: (body['enabledStrategies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          maxConcurrency: body['maxConcurrency'] as int?,
          timeoutSeconds: body['timeoutSeconds'] as int?,
          updatedAt: DateTime.now(),
        );

        final saveRes = await discoveryRepo.saveConfig(updated);
        await _jsonResponse(request, {
          'success': saveRes.isSuccess,
          'message': saveRes.isSuccess
              ? 'Discovery config updated'
              : saveRes.failureOrNull?.message,
        });
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
        final ranges = (body['ranges'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final strategies = (body['strategies'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final concurrency = body['concurrency'] as int?;
        final timeout = body['timeoutSeconds'] as int?;

        final coordinator = getIt<DiscoveryCoordinator>();
        final res = await coordinator.startScan(
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
        final coordinator = getIt<DiscoveryCoordinator>();
        final discoveryRepo = getIt<DiscoveryRepository>();
        final latestJob = await discoveryRepo.getLatestScanJob();

        await _jsonResponse(request, {
          'success': true,
          'isScanning': coordinator.isScanning,
          'activeScanId': coordinator.activeScanId,
          'latestScan': latestJob.dataOrNull?.toJson(),
        });
      } else if (path == '/api/discovery/devices' && request.method == 'GET') {
        final discoveryRepo = getIt<DiscoveryRepository>();
        final scanIdStr = request.uri.queryParameters['scanId'];
        final scanId = scanIdStr != null ? int.tryParse(scanIdStr) : null;

        final res = await discoveryRepo.getDiscoveredDevices(scanId: scanId);
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
        final existingDevicesRes = await deviceRepo.getDevices();
        final existingDevices = existingDevicesRes.dataOrNull ?? [];
        final existing = existingDevices
            .where((d) => d.ip.trim() == discovered.ip.trim())
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

  void _broadcastEvent(String eventName, dynamic data) {
    final payload = jsonEncode({'event': eventName, 'data': data});
    for (final client in List.of(_wsClients)) {
      try {
        client.add(payload);
      } catch (_) {
        _wsClients.remove(client);
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
    await _statusSub?.cancel();
    await _incidentSub?.cancel();
    await _discoveryProgressSub?.cancel();
    for (final client in _wsClients) {
      await client.close();
    }
    await _server?.close(force: true);
    _log('Monitoring Service stopped cleanly.');
  }
}
