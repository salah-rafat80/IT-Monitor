import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Client session state for authenticating with the background Monitoring Service.
class ClientSessionInfo {
  final String token;
  final String username;
  final String role;
  final DateTime expiresAt;

  const ClientSessionInfo({
    required this.token,
    required this.username,
    required this.role,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get isViewer => role.toLowerCase() == 'viewer';
}

/// Result returned from API calls.
class ServiceApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int statusCode;

  const ServiceApiResponse.success(this.data, {this.statusCode = 200})
    : isSuccess = true,
      errorMessage = null;

  const ServiceApiResponse.failure(this.errorMessage, {this.statusCode = 400})
    : isSuccess = false,
      data = null;

  bool get isFailure => !isSuccess;
}

/// Secure HTTPS / WSS client connector for Desktop Clients communicating
/// with the authoritative Windows Monitoring Service.
class MonitoringServiceClient {
  final String
  baseUrl; // e.g. "https://127.0.0.1:8443" or "http://127.0.0.1:8080"
  final String? trustedCertPath;
  final SecurityContext? customSecurityContext;

  HttpClient? _httpClient;
  WebSocket? _webSocket;
  ClientSessionInfo? _currentSession;

  final StreamController<Map<String, dynamic>> _eventStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  MonitoringServiceClient({
    required this.baseUrl,
    this.trustedCertPath,
    this.customSecurityContext,
  }) {
    _initHttpClient();
  }

  void _initHttpClient() {
    SecurityContext? secContext = customSecurityContext;
    if (secContext == null &&
        trustedCertPath != null &&
        File(trustedCertPath!).existsSync()) {
      secContext = SecurityContext(withTrustedRoots: false);
      secContext.setTrustedCertificates(trustedCertPath!);
    }

    _httpClient = HttpClient(context: secContext);
    // Explicitly enforce certificate validation (strict validation against trusted roots)
    // No bypass or permissive badCertificateCallback is allowed in production.
  }

  ClientSessionInfo? get currentSession => _currentSession;

  bool get isAuthenticated =>
      _currentSession != null && !_currentSession!.isExpired;

  bool get isAdmin => isAuthenticated && _currentSession!.isAdmin;

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  String? _lastConnectionError;

  String? get lastConnectionError => _lastConnectionError;
  bool get isWebSocketConnected => _webSocket != null;

  /// Verify a session token with the authoritative service and receive explicit confirmation.
  Future<ServiceApiResponse<ClientSessionInfo>> verifySession([
    String? tokenToVerify,
  ]) async {
    final token = tokenToVerify ?? _currentSession?.token;
    if (token == null || token.isEmpty) {
      _currentSession = null;
      return const ServiceApiResponse.failure(
        'No session token available to verify.',
        statusCode: 401,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/auth/verify');
      final request = await _httpClient!.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      dynamic parsed;
      try {
        parsed = jsonDecode(responseBody);
      } catch (_) {
        parsed = null;
      }

      if (response.statusCode == 200 &&
          parsed is Map &&
          parsed['success'] == true &&
          parsed['session'] is Map) {
        final sessionData = parsed['session'] as Map<String, dynamic>;
        _currentSession = ClientSessionInfo(
          token: token,
          username:
              sessionData['username']?.toString() ??
              'Local Administrator (No Interactive Login)',
          role: sessionData['role']?.toString() ?? 'admin',
          expiresAt:
              DateTime.tryParse(sessionData['expiresAt']?.toString() ?? '') ??
              DateTime.now().add(const Duration(hours: 24)),
        );
        _lastConnectionError = null;
        return ServiceApiResponse.success(_currentSession!);
      } else {
        _currentSession = null;
        final errMsg = (parsed is Map && parsed.containsKey('error'))
            ? parsed['error']?.toString()
            : 'Session token rejected by service (Status: ${response.statusCode})';
        _lastConnectionError = errMsg;
        return ServiceApiResponse.failure(
          errMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      _currentSession = null;
      _lastConnectionError = 'Cannot reach authoritative service: $e';
      return ServiceApiResponse.failure(
        'Failed to connect to authoritative monitoring service: $e',
        statusCode: 503,
      );
    }
  }

  /// Authenticate using local machine-bound trusted token created by the service in ProgramData.
  /// Preserves direct launch without interactive login by requiring explicit server verification.
  Future<ServiceApiResponse<ClientSessionInfo>>
  authenticateWithTrustedLocalToken([String? customTokenPath]) async {
    try {
      final programData = Platform.environment['ProgramData'];
      final tokenPath =
          customTokenPath ??
          Platform.environment['IT_MONITOR_TRUSTED_TOKEN_PATH'] ??
          (programData != null
              ? p.join(programData, 'ITNetworkMonitor', 'trusted_client.token')
              : 'trusted_client.token');

      final file = File(tokenPath);
      if (!file.existsSync()) {
        _currentSession = null;
        return const ServiceApiResponse.failure(
          'Trusted local client token not found. The IT Network Monitor Service may not be running.',
          statusCode: 401,
        );
      }

      final token = file.readAsStringSync().trim();
      if (token.isEmpty || token.length < 32) {
        _currentSession = null;
        return const ServiceApiResponse.failure(
          'Trusted local client token is empty or invalid.',
          statusCode: 401,
        );
      }

      // Send token over secure transport and require explicit server-side acceptance
      return await verifySession(token);
    } catch (e) {
      _currentSession = null;
      return ServiceApiResponse.failure(
        'Failed to read or verify trusted client token: $e',
        statusCode: 401,
      );
    }
  }

  /// Authenticate using an explicitly provisioned token (e.g. for remote Client-Only deployments).
  void authenticateWithProvisionedToken(
    String token, {
    String role = 'admin',
    String username = 'Provisioned Administrator',
  }) {
    _currentSession = ClientSessionInfo(
      token: token.trim(),
      username: username,
      role: role,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );
  }

  /// Authenticate with the service and obtain a 24-hour cryptographically secure session token.
  Future<ServiceApiResponse<ClientSessionInfo>> login({
    required String username,
    required String password,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/auth/login',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );

    if (response.isSuccess && response.data != null) {
      final json = response.data as Map<String, dynamic>;
      if (json['success'] == true) {
        final token = json['token'] as String;
        final expiresAt = DateTime.parse(json['expiresAt'] as String);
        final userMap = json['user'] as Map<String, dynamic>;

        _currentSession = ClientSessionInfo(
          token: token,
          username: userMap['username']?.toString() ?? username,
          role: userMap['role']?.toString() ?? 'viewer',
          expiresAt: expiresAt,
        );

        return ServiceApiResponse.success(_currentSession!);
      }
    }

    return ServiceApiResponse.failure(
      response.errorMessage ?? 'Authentication failed',
      statusCode: response.statusCode,
    );
  }

  /// Invalidate the active session on the service.
  Future<ServiceApiResponse<void>> logout() async {
    if (_currentSession == null) {
      return const ServiceApiResponse.success(null);
    }

    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/auth/logout',
      body: {'token': _currentSession!.token},
      requireAuth: true,
    );

    _currentSession = null;
    await disconnectWebSocket();
    return ServiceApiResponse.success(null, statusCode: response.statusCode);
  }

  /// Check server health and security status.
  Future<ServiceApiResponse<Map<String, dynamic>>> getServiceStatus() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/status',
      requireAuth: false,
    );
    if (response.isSuccess) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch devices and their authoritative statuses.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getDevices() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/devices',
      requireAuth: true,
    );
    if (response.isSuccess) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['devices'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Assign owner to a device (Server-side Admin role required).
  Future<ServiceApiResponse<Map<String, dynamic>>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/assign-owner',
      body: {'deviceId': deviceId, 'ownerName': ownerName},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Add a new device to authoritative inventory on the service.
  Future<ServiceApiResponse<Map<String, dynamic>>> addDevice(
    Map<String, dynamic> deviceJson,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices',
      body: deviceJson,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Update an existing device in authoritative inventory on the service.
  Future<ServiceApiResponse<Map<String, dynamic>>> updateDevice(
    Map<String, dynamic> deviceJson,
  ) async {
    final response = await _sendRequest(
      method: 'PUT',
      endpoint: '/api/devices',
      body: deviceJson,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Delete a device from authoritative inventory on the service.
  Future<ServiceApiResponse<void>> deleteDevice(int id) async {
    final response = await _sendRequest(
      method: 'DELETE',
      endpoint: '/api/devices/$id',
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Toggle monitoring enabled state on a device.
  Future<ServiceApiResponse<Map<String, dynamic>>> toggleDeviceMonitoring(
    int deviceId,
    bool isMonitored,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/toggle-monitoring',
      body: {'deviceId': deviceId, 'isMonitored': isMonitored},
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Import batch of devices into authoritative inventory.
  Future<ServiceApiResponse<int>> importDevices(
    List<Map<String, dynamic>> devicesJson,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/import',
      body: {'devices': devicesJson},
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(json['importedCount'] as int? ?? 0);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Delete an infrastructure device from the service.
  Future<ServiceApiResponse<void>> deleteInfrastructureDevice(int id) async {
    final response = await _sendRequest(
      method: 'DELETE',
      endpoint: '/api/infrastructure/unifi/devices/$id',
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Resolve an active incident on the service.
  Future<ServiceApiResponse<void>> resolveIncident(int incidentId) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/incidents/resolve',
      body: {'incidentId': incidentId},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Export historical availability report as CSV.
  Future<ServiceApiResponse<String>> exportReportCsv(String period) async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/reports/export-csv?period=$period',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(json['csv']?.toString() ?? '');
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch users list from the service.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getUsers() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/users',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['users'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch audit logs from the service.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getAuditLogs({
    int limit = 100,
  }) async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/audit-logs?limit=$limit',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['logs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch active incidents and incident history from the service.
  Future<ServiceApiResponse<Map<String, dynamic>>> getIncidents() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/incidents',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Acknowledge an incident on the authoritative service.
  Future<ServiceApiResponse<void>> acknowledgeIncident(int incidentId) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/incidents/acknowledge',
      body: {'incidentId': incidentId},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Add notes to an active or historical incident on the authoritative service.
  Future<ServiceApiResponse<void>> addIncidentNote(
    int incidentId,
    String notes,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/incidents/notes',
      body: {'incidentId': incidentId, 'notes': notes},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch infrastructure devices (UniFi gateways, switches, APs) from the service.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>>
  getInfrastructureDevices() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/infrastructure/unifi/devices',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['devices'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Save or update an infrastructure device on the service.
  Future<ServiceApiResponse<Map<String, dynamic>>> saveInfrastructureDevice(
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/infrastructure/unifi/devices',
      body: body,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Generate a reporting summary from authoritative historical checks.
  Future<ServiceApiResponse<Map<String, dynamic>>> getReportSummary(
    String period,
  ) async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/reports/summary?period=$period',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch discovery scan status and latest job info.
  Future<ServiceApiResponse<Map<String, dynamic>>> getDiscoveryStatus() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/discovery/status',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch discovered devices from scan results.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getDiscoveryDevices([
    int? scanId,
  ]) async {
    final endpoint = scanId != null
        ? '/api/discovery/devices?scanId=$scanId'
        : '/api/discovery/devices';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: endpoint,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['devices'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Start a network discovery scan job on the background service.
  Future<ServiceApiResponse<Map<String, dynamic>>> startDiscoveryScan({
    List<String>? ranges,
    List<String>? strategies,
    int? concurrency,
    int? timeoutSeconds,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/start',
      body: {
        if (ranges != null) 'ranges': ranges,
        if (strategies != null) 'strategies': strategies,
        if (concurrency != null) 'concurrency': concurrency,
        if (timeoutSeconds != null) 'timeoutSeconds': timeoutSeconds,
      },
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Cancel an ongoing discovery scan job.
  Future<ServiceApiResponse<void>> cancelDiscoveryScan() async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/cancel',
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Approve a discovered device into authoritative inventory.
  Future<ServiceApiResponse<Map<String, dynamic>>> approveDiscoveryDevice(
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/approve',
      body: body,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Reject a discovered device.
  Future<ServiceApiResponse<void>> rejectDiscoveryDevice(int deviceId) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/reject',
      body: {'deviceId': deviceId},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch discovery configuration from authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> getDiscoveryConfig() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/discovery/config',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['config'] as Map<String, dynamic>? ?? {},
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Save discovery configuration to authoritative service.
  Future<ServiceApiResponse<void>> saveDiscoveryConfig(
    Map<String, dynamic> config,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/config',
      body: config,
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch monitoring configuration from authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> getMonitoringConfig() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/settings',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['config'] as Map<String, dynamic>? ?? {},
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Update monitoring configuration on authoritative service.
  Future<ServiceApiResponse<void>> updateMonitoringConfig(
    Map<String, dynamic> config,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/settings',
      body: config,
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Trigger a manual ping/port check for a device via the service.
  Future<ServiceApiResponse<void>> manualCheck(int deviceId) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/monitoring/manual-check',
      body: {'deviceId': deviceId},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Set maintenance mode for a device via the service.
  Future<ServiceApiResponse<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/monitoring/toggle-maintenance',
      body: {'deviceId': deviceId, 'isMaintenance': isMaintenance},
      requireAuth: true,
    );
    if (response.isSuccess) {
      return const ServiceApiResponse.success(null);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch grouped topology from authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> getTopology() async {
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/topology',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      return ServiceApiResponse.success(response.data as Map<String, dynamic>);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Connect to the live WebSocket event stream (WSS if HTTPS).
  Future<void> connectWebSocket() async {
    if (_currentSession == null || _currentSession!.isExpired) {
      throw StateError(
        'Cannot establish secure WebSocket without an active authenticated session.',
      );
    }

    // Connect without exposing the bearer token in the URL / query parameters.
    // Use the standard HTTP Authorization header in the WebSocket upgrade handshake.
    final wsUri = Uri.parse(
      baseUrl,
    ).replace(scheme: baseUrl.startsWith('https') ? 'wss' : 'ws', path: '/ws');

    SecurityContext? secContext = customSecurityContext;
    if (secContext == null &&
        trustedCertPath != null &&
        File(trustedCertPath!).existsSync()) {
      secContext = SecurityContext(withTrustedRoots: false);
      secContext.setTrustedCertificates(trustedCertPath!);
    }

    _webSocket = await WebSocket.connect(
      wsUri.toString(),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${_currentSession!.token}',
      },
      customClient: HttpClient(context: secContext),
    );

    _webSocket!.listen(
      (data) {
        try {
          final event = jsonDecode(data.toString()) as Map<String, dynamic>;
          _eventStreamController.add(event);
        } catch (_) {}
      },
      onDone: () {
        _webSocket = null;
      },
      onError: (_) {
        _webSocket = null;
      },
    );
  }

  Future<void> disconnectWebSocket() async {
    await _webSocket?.close();
    _webSocket = null;
  }

  Future<ServiceApiResponse<dynamic>> _sendRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    try {
      if (requireAuth &&
          (_currentSession == null || _currentSession!.isExpired)) {
        return const ServiceApiResponse.failure(
          'Unauthorized: Session expired or not logged in',
          statusCode: 401,
        );
      }

      final uri = Uri.parse('$baseUrl$endpoint');
      final request = await _httpClient!.openUrl(method, uri);

      request.headers.contentType = ContentType.json;
      if (_currentSession != null && !_currentSession!.isExpired) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${_currentSession!.token}',
        );
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      dynamic parsed;
      if (responseBody.isNotEmpty) {
        try {
          parsed = jsonDecode(responseBody);
        } catch (_) {
          parsed = responseBody;
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ServiceApiResponse.success(
          parsed,
          statusCode: response.statusCode,
        );
      } else {
        String? errMsg;
        if (parsed is Map && parsed.containsKey('error')) {
          errMsg = parsed['error']?.toString();
        } else if (parsed is Map && parsed.containsKey('message')) {
          errMsg = parsed['message']?.toString();
        } else {
          errMsg = 'HTTP ${response.statusCode}: $responseBody';
        }
        return ServiceApiResponse.failure(
          errMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ServiceApiResponse.failure(
        'Network transport error: $e',
        statusCode: 0,
      );
    }
  }

  void dispose() {
    disconnectWebSocket();
    _httpClient?.close(force: true);
    _eventStreamController.close();
  }
}
