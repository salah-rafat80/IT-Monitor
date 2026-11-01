import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  final String? provisionedToken;
  String? _configurationError;
  String? get configurationError => _configurationError;
  bool get hasConfigurationError => _configurationError != null;

  HttpClient? _httpClient;
  WebSocket? _webSocket;
  SecurityContext? _securityContext;
  ClientSessionInfo? _currentSession;
  bool _isRemoteTokenMode = false;
  String? _effectiveProvisionedToken;
  Timer? _wsReconnectTimer;
  bool _isDisposed = false;
  String? _lastWebSocketError;

  final StreamController<Map<String, dynamic>> _eventStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static bool isLoopbackUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1' ||
        host == '[::1]';
  }

  MonitoringServiceClient({
    required this.baseUrl,
    this.trustedCertPath,
    this.customSecurityContext,
    this.provisionedToken,
    String? configurationError,
  }) : _configurationError = configurationError {
    if (provisionedToken != null && provisionedToken!.trim().isNotEmpty) {
      _isRemoteTokenMode = true;
      _effectiveProvisionedToken = provisionedToken!.trim();
    }
    // Reject unencrypted HTTP for remote connections before creating HTTP client or sending tokens
    if (!isLoopbackUrl(baseUrl) &&
        baseUrl.toLowerCase().startsWith('http://')) {
      _configurationError =
          'Insecure transport: Service endpoint ($baseUrl) must use HTTPS. Plain HTTP is forbidden for remote connections.';
    }
    if (_configurationError == null) {
      _initHttpClient();
    }
  }

  void _initHttpClient() {
    SecurityContext? secContext = customSecurityContext;
    String? certPath = trustedCertPath;

    final isHttps = baseUrl.toLowerCase().startsWith('https:');

    if (isHttps && secContext == null) {
      if (certPath != null) {
        final certFile = File(certPath);
        if (!certFile.existsSync()) {
          throw StateError(
            'Configured trusted TLS certificate file not found: "$certPath".',
          );
        }
        try {
          final certBytes = certFile.readAsBytesSync();
          if (certBytes.isEmpty) {
            throw StateError(
              'Configured trusted TLS certificate file is empty: "$certPath".',
            );
          }
          final testSec = SecurityContext(withTrustedRoots: false);
          testSec.setTrustedCertificates(certPath);
          secContext = testSec;
        } on PathAccessException catch (e) {
          if (isLoopbackUrl(baseUrl)) {
            debugPrint(
              '[MonitoringServiceClient] Access denied reading cert file "$certPath" on loopback: $e. Falling back to public cert / system root trust.',
            );
            secContext = _tryResolveLoopbackSecurityContext();
          } else {
            throw StateError(
              'Failed to load configured trusted TLS certificate from "$certPath": $e',
            );
          }
        } catch (e) {
          if (isLoopbackUrl(baseUrl) &&
              (e is PathAccessException ||
                  e.toString().contains('Access is denied') ||
                  e.toString().contains('errno = 5'))) {
            debugPrint(
              '[MonitoringServiceClient] Access denied reading cert file "$certPath" on loopback: $e. Falling back to public cert / system root trust.',
            );
            secContext = _tryResolveLoopbackSecurityContext();
          } else {
            throw StateError(
              'Failed to load configured trusted TLS certificate from "$certPath": $e',
            );
          }
        }
      } else {
        final envCert = Platform.environment['IT_MONITOR_TRUSTED_CERT_PATH'];
        if (envCert != null && envCert.trim().isNotEmpty) {
          final envFile = File(envCert.trim());
          if (!envFile.existsSync()) {
            throw StateError(
              'Environment trusted TLS certificate file not found: "$envCert".',
            );
          }
          try {
            final testSec = SecurityContext(withTrustedRoots: false);
            testSec.setTrustedCertificates(envFile.path);
            secContext = testSec;
            certPath = envFile.path;
          } catch (e) {
            throw StateError(
              'Failed to load environment trusted TLS certificate from "$envCert": $e',
            );
          }
        }
      }
    }

    _securityContext = secContext;
    _httpClient = HttpClient(context: _securityContext);
  }

  SecurityContext? _tryResolveLoopbackSecurityContext() {
    final programData = Platform.environment['ProgramData'];
    if (programData != null) {
      final publicCert = p.join(programData, 'ITNetworkMonitor', 'server.crt');
      if (File(publicCert).existsSync()) {
        try {
          final testSec = SecurityContext(withTrustedRoots: false);
          testSec.setTrustedCertificates(publicCert);
          return testSec;
        } catch (_) {}
      }
      final certsDirCert = p.join(
        programData,
        'ITNetworkMonitor',
        'certs',
        'server.crt',
      );
      if (File(certsDirCert).existsSync()) {
        try {
          final testSec = SecurityContext(withTrustedRoots: false);
          testSec.setTrustedCertificates(certsDirCert);
          return testSec;
        } catch (_) {}
      }
    }
    if (isLoopbackUrl(baseUrl)) {
      return SecurityContext(withTrustedRoots: true);
    }
    return null;
  }

  ClientSessionInfo? get currentSession => _currentSession;

  SecurityContext? get securityContext => _securityContext;

  bool get isAuthenticated =>
      _currentSession != null && !_currentSession!.isExpired;

  bool get isAdmin => isAuthenticated && _currentSession!.isAdmin;

  bool get isRemoteTokenMode {
    if (_isRemoteTokenMode) return true;
    final envToken = Platform.environment['IT_MONITOR_CLIENT_TOKEN'];
    return envToken != null && envToken.trim().isNotEmpty;
  }

  String? get currentProvisionedToken {
    if (_effectiveProvisionedToken != null &&
        _effectiveProvisionedToken!.isNotEmpty) {
      return _effectiveProvisionedToken;
    }
    final envToken = Platform.environment['IT_MONITOR_CLIENT_TOKEN']?.trim();
    if (envToken != null && envToken.isNotEmpty) {
      return envToken;
    }
    return null;
  }

  void clearSession() {
    _currentSession = null;
    _lastConnectionError = null;
    _lastWebSocketError = null;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    disconnectWebSocket();
  }

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  String? _lastConnectionError;
  String? get lastConnectionError => _lastConnectionError;
  String? get lastWebSocketError => _lastWebSocketError;
  bool get isWebSocketConnected => _webSocket != null;

  String classifyConnectionException(Object error) =>
      _classifyConnectionException(error);

  String _classifyConnectionException(Object error) {
    if (error is SocketException) {
      final osCode = error.osError?.errorCode;
      final osMsg = error.osError?.message ?? '';
      if (osCode == 10061 ||
          osCode == 1225 ||
          osMsg.toLowerCase().contains('connection refused')) {
        return 'Cannot reach authoritative service ($baseUrl). Service connection refused: The IT Network Monitor Windows Service is not running, stopped, or not listening on this port.';
      }
      if (osCode == 10060 ||
          osCode == 10065 ||
          osCode == 10051 ||
          osMsg.toLowerCase().contains('timed out') ||
          osMsg.toLowerCase().contains('unreachable')) {
        return 'Cannot reach authoritative service ($baseUrl). Service host unreachable: Verify network routing, server IP, and firewall rules for port 8443.';
      }
      return 'Cannot reach authoritative service ($baseUrl). Network socket error: ${error.message}';
    } else if (error is HandshakeException ||
        error is TlsException ||
        error.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
      final errStr = error.toString();
      if (errStr.contains('Hostname mismatch') ||
          errStr.contains('IP address mismatch')) {
        return 'TLS SAN Mismatch: Server certificate does not match the service endpoint in "$baseUrl". Certificate SAN must contain this IP address or hostname.';
      }
      return 'TLS Trust Verification Failed: Service certificate is untrusted, expired, or not trusted by client context. Ensure public server.crt is trusted: $error';
    } else if (error is PathAccessException ||
        error.toString().contains('Access is denied')) {
      return 'Access Denied: Current Windows user does not have permission to access client credentials. Membership in "ITNetworkMonitorAdministrators" is required: $error';
    } else if (error is TimeoutException) {
      return 'Connection timed out connecting to authoritative service ($baseUrl). Check server health and firewall.';
    }
    return 'Failed to connect to authoritative monitoring service ($baseUrl): $error';
  }

  /// Verify a session token with the authoritative service and receive explicit confirmation.
  Future<ServiceApiResponse<ClientSessionInfo>> verifySession([
    String? tokenToVerify,
  ]) async {
    if (configurationError != null) {
      clearSession();
      _lastConnectionError = configurationError;
      return ServiceApiResponse.failure(configurationError!, statusCode: 400);
    }

    if (!isLoopbackUrl(baseUrl) &&
        baseUrl.toLowerCase().startsWith('http://')) {
      clearSession();
      const errMsg =
          'Insecure transport: Bearer tokens cannot be sent over unencrypted remote HTTP connections.';
      _lastConnectionError = errMsg;
      return const ServiceApiResponse.failure(errMsg, statusCode: 400);
    }

    final token = tokenToVerify ?? _currentSession?.token;
    if (token == null || token.trim().isEmpty) {
      clearSession();
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

      if (response.statusCode != 200) {
        clearSession();
        final errMsg = (parsed is Map && parsed.containsKey('error'))
            ? parsed['error']?.toString()
            : 'Session token rejected by service (Status: ${response.statusCode})';
        _lastConnectionError = errMsg;
        return ServiceApiResponse.failure(
          errMsg,
          statusCode: response.statusCode,
        );
      }

      if (parsed is! Map ||
          parsed['success'] != true ||
          parsed['session'] is! Map) {
        clearSession();
        const errMsg =
            'Malformed service response: success flag or session object missing.';
        _lastConnectionError = errMsg;
        return const ServiceApiResponse.failure(errMsg, statusCode: 401);
      }

      final sessionData = parsed['session'] as Map<String, dynamic>;

      // 1. Strict username validation
      final username = sessionData['username']?.toString().trim();
      if (username == null || username.isEmpty) {
        clearSession();
        const errMsg =
            'Malformed session contract: username is missing or empty.';
        _lastConnectionError = errMsg;
        return const ServiceApiResponse.failure(errMsg, statusCode: 401);
      }

      // 2. Strict role validation
      final rawRole = sessionData['role']?.toString().trim();
      if (rawRole == null || rawRole.isEmpty) {
        clearSession();
        const errMsg = 'Malformed session contract: role is missing or empty.';
        _lastConnectionError = errMsg;
        return const ServiceApiResponse.failure(errMsg, statusCode: 401);
      }
      final roleStr = rawRole.toLowerCase();
      if (roleStr != 'admin' && roleStr != 'viewer') {
        clearSession();
        final errMsg =
            'Malformed session contract: invalid or unrecognized role "$rawRole".';
        _lastConnectionError = errMsg;
        return ServiceApiResponse.failure(errMsg, statusCode: 401);
      }

      // 3. Strict expiration validation
      final expiresRaw = sessionData['expiresAt']?.toString().trim();
      if (expiresRaw == null || expiresRaw.isEmpty) {
        clearSession();
        const errMsg =
            'Malformed session contract: missing session expiration timestamp.';
        _lastConnectionError = errMsg;
        return const ServiceApiResponse.failure(errMsg, statusCode: 401);
      }

      final parsedExpires = DateTime.tryParse(expiresRaw);
      if (parsedExpires == null) {
        clearSession();
        final errMsg =
            'Malformed session contract: unparseable expiration timestamp "$expiresRaw".';
        _lastConnectionError = errMsg;
        return ServiceApiResponse.failure(errMsg, statusCode: 401);
      }

      if (parsedExpires.isBefore(DateTime.now())) {
        clearSession();
        final errMsg =
            'Session expired: expiration timestamp "$expiresRaw" is in the past.';
        _lastConnectionError = errMsg;
        return ServiceApiResponse.failure(errMsg, statusCode: 401);
      }

      _currentSession = ClientSessionInfo(
        token: token,
        username: username,
        role: roleStr,
        expiresAt: parsedExpires,
      );
      _lastConnectionError = null;
      return ServiceApiResponse.success(_currentSession!);
    } catch (e) {
      clearSession();
      final classified = _classifyConnectionException(e);
      _lastConnectionError = classified;
      return ServiceApiResponse.failure(
        classified,
        statusCode:
            (e is SocketException &&
                (e.osError?.errorCode == 10061 || e.osError?.errorCode == 1225))
            ? 503
            : 500,
      );
    }
  }

  /// Authenticate using local machine-bound trusted token created by the service in ProgramData.
  /// Preserves direct launch without interactive login by requiring explicit server verification.
  Future<ServiceApiResponse<ClientSessionInfo>>
  authenticateWithTrustedLocalToken([String? customTokenPath]) async {
    _isRemoteTokenMode = false;
    if (configurationError != null) {
      _currentSession = null;
      _lastConnectionError = configurationError;
      return ServiceApiResponse.failure(configurationError!, statusCode: 400);
    }
    if (!isLoopbackUrl(baseUrl) &&
        baseUrl.toLowerCase().startsWith('http://')) {
      _currentSession = null;
      const errMsg =
          'Insecure transport: Bearer tokens cannot be sent over unencrypted remote HTTP connections.';
      _lastConnectionError = errMsg;
      return const ServiceApiResponse.failure(errMsg, statusCode: 400);
    }
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
    } on PathAccessException catch (e) {
      _currentSession = null;
      return ServiceApiResponse.failure(
        'Access Denied: Current Windows account does not have read permissions for the trusted client token. Membership in "ITNetworkMonitorAdministrators" is required: $e',
        statusCode: 403,
      );
    } catch (e) {
      _currentSession = null;
      return ServiceApiResponse.failure(
        'Failed to read or verify trusted client token: ${_classifyConnectionException(e)}',
        statusCode: 401,
      );
    }
  }

  /// Authenticate using an explicitly provisioned token (e.g. from environment or secure storage),
  /// requiring server-confirmed verification via /api/auth/verify before establishing an authenticated session.
  /// Obtains role, username, and expiration directly from the authoritative server response.
  Future<ServiceApiResponse<ClientSessionInfo>>
  authenticateWithProvisionedToken(String token) async {
    if (configurationError != null) {
      _currentSession = null;
      _lastConnectionError = configurationError;
      return ServiceApiResponse.failure(configurationError!, statusCode: 400);
    }
    if (!isLoopbackUrl(baseUrl) &&
        baseUrl.toLowerCase().startsWith('http://')) {
      _currentSession = null;
      const errMsg =
          'Insecure transport: Bearer tokens cannot be sent over unencrypted remote HTTP connections.';
      _lastConnectionError = errMsg;
      return const ServiceApiResponse.failure(errMsg, statusCode: 400);
    }
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      _currentSession = null;
      _lastConnectionError =
          'Cannot authenticate with an empty provisioned token.';
      return const ServiceApiResponse.failure(
        'Cannot authenticate with an empty provisioned token.',
        statusCode: 400,
      );
    }
    if (cleanToken.length < 32) {
      _currentSession = null;
      _lastConnectionError = 'Provisioned token is invalid (< 32 characters).';
      return const ServiceApiResponse.failure(
        'Provisioned token is invalid (< 32 characters). Verify provisioned token in client_config.json.',
        statusCode: 401,
      );
    }
    _isRemoteTokenMode = true;
    _effectiveProvisionedToken = cleanToken;
    return await verifySession(cleanToken);
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
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getDevices({
    String? factoryId,
  }) async {
    final query = factoryId != null && factoryId.isNotEmpty
        ? '?factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/devices$query',
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

  /// Import batch of devices using explicit INSERT and UPDATE payload contract.
  Future<ServiceApiResponse<int>> importDevicesPayload(
    Map<String, dynamic> payloadJson,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/import',
      body: payloadJson,
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

  /// Reassign a list of devices to a target factory on the authoritative service.
  Future<ServiceApiResponse<int>> reassignDevicesFactory({
    required List<int> deviceIds,
    required String targetFactoryId,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/reassign-factory',
      body: {'deviceIds': deviceIds, 'factoryId': targetFactoryId},
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['reassignedCount'] as int? ?? deviceIds.length,
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Delete multiple devices from the authoritative service.
  Future<ServiceApiResponse<int>> deleteDevices(List<int> deviceIds) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/bulk-delete',
      body: {'deviceIds': deviceIds},
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['deletedCount'] as int? ?? deviceIds.length,
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Bulk update attributes for multiple devices on the authoritative service.
  Future<ServiceApiResponse<int>> bulkUpdateDevices({
    required List<int> deviceIds,
    String? type,
    String? department,
    String? officeLocation,
    String? vendor,
    bool? isMonitored,
    bool? isEnabled,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/devices/bulk-update',
      body: {
        'deviceIds': deviceIds,
        if (type != null) 'type': type,
        if (department != null) 'department': department,
        if (officeLocation != null) 'officeLocation': officeLocation,
        if (vendor != null) 'vendor': vendor,
        if (isMonitored != null) 'isMonitored': isMonitored,
        if (isEnabled != null) 'isEnabled': isEnabled,
      },
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['updatedCount'] as int? ?? deviceIds.length,
      );
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
  Future<ServiceApiResponse<String>> exportReportCsv(
    String period, {
    String? factoryId,
  }) async {
    final factoryQuery = factoryId != null && factoryId.isNotEmpty
        ? '&factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/reports/export-csv?period=$period$factoryQuery',
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
  Future<ServiceApiResponse<Map<String, dynamic>>> getIncidents({
    String? factoryId,
  }) async {
    final query = factoryId != null && factoryId.isNotEmpty
        ? '?factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/incidents$query',
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
  getInfrastructureDevices({String? factoryId}) async {
    final query = factoryId != null && factoryId.isNotEmpty
        ? '?factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/infrastructure/unifi/devices$query',
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
    String period, {
    String? factoryId,
  }) async {
    final factoryQuery = factoryId != null && factoryId.isNotEmpty
        ? '&factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/reports/summary?period=$period$factoryQuery',
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
  Future<ServiceApiResponse<Map<String, dynamic>>> getDiscoveryStatus({
    String? factoryId,
  }) async {
    final query = factoryId != null && factoryId.isNotEmpty
        ? '?factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/discovery/status$query',
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
    String? factoryId,
  ]) async {
    final params = <String>[];
    if (scanId != null) params.add('scanId=$scanId');
    if (factoryId != null && factoryId.isNotEmpty) {
      params.add('factoryId=${Uri.encodeComponent(factoryId)}');
    }
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final endpoint = '/api/discovery/devices$query';
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
    String? factoryId,
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/start',
      body: {
        if (factoryId != null) 'factoryId': factoryId,
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

  /// Fetch all configured network ranges from authoritative service.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getNetworkRanges({
    String? factoryId,
  }) async {
    final query = factoryId != null && factoryId.isNotEmpty
        ? '?factoryId=${Uri.encodeComponent(factoryId)}'
        : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/discovery/ranges$query',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['ranges'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Fetch factories from the authoritative service.
  Future<ServiceApiResponse<List<Map<String, dynamic>>>> getFactories({
    bool includeInactive = false,
  }) async {
    final query = includeInactive ? '?includeInactive=true' : '';
    final response = await _sendRequest(
      method: 'GET',
      endpoint: '/api/factories$query',
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      final list =
          (json['factories'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];
      return ServiceApiResponse.success(list);
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Create a new factory on the authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> createFactory(
    Map<String, dynamic> factoryData,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/factories',
      body: factoryData,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['factory'] as Map<String, dynamic>? ?? factoryData,
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Update a factory on the authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> updateFactory(
    String factoryId,
    Map<String, dynamic> factoryData,
  ) async {
    final response = await _sendRequest(
      method: 'PUT',
      endpoint: '/api/factories/$factoryId',
      body: factoryData,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['factory'] as Map<String, dynamic>? ?? factoryData,
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Delete/deactivate a factory on the authoritative service.
  Future<ServiceApiResponse<void>> deleteFactory(String factoryId) async {
    final response = await _sendRequest(
      method: 'DELETE',
      endpoint: '/api/factories/$factoryId',
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

  /// Add a new authorized network range to the authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> addNetworkRange(
    Map<String, dynamic> rangeData,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/ranges',
      body: rangeData,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['range'] as Map<String, dynamic>? ?? rangeData,
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Update an existing network range on the authoritative service.
  Future<ServiceApiResponse<Map<String, dynamic>>> updateNetworkRange(
    Map<String, dynamic> rangeData,
  ) async {
    final response = await _sendRequest(
      method: 'POST',
      endpoint: '/api/discovery/ranges/update',
      body: rangeData,
      requireAuth: true,
    );
    if (response.isSuccess && response.data is Map) {
      final json = response.data as Map<String, dynamic>;
      return ServiceApiResponse.success(
        json['range'] as Map<String, dynamic>? ?? rangeData,
      );
    }
    return ServiceApiResponse.failure(
      response.errorMessage,
      statusCode: response.statusCode,
    );
  }

  /// Delete a network range from the authoritative service.
  Future<ServiceApiResponse<void>> deleteNetworkRange(String rangeId) async {
    final response = await _sendRequest(
      method: 'DELETE',
      endpoint: '/api/discovery/ranges/$rangeId',
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

    if (!isLoopbackUrl(baseUrl) && !baseUrl.toLowerCase().startsWith('https')) {
      throw StateError(
        'Cannot establish unencrypted WebSocket connection to remote host ($baseUrl). WSS is required.',
      );
    }

    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;

    final wsUri = Uri.parse(
      baseUrl,
    ).replace(scheme: baseUrl.startsWith('https') ? 'wss' : 'ws', path: '/ws');

    try {
      final ws = await WebSocket.connect(
        wsUri.toString(),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${_currentSession!.token}',
        },
        customClient: HttpClient(context: _securityContext),
      );

      _webSocket = ws;
      _lastWebSocketError = null;

      ws.listen(
        (data) {
          try {
            final event = jsonDecode(data.toString()) as Map<String, dynamic>;
            _eventStreamController.add(event);
          } catch (_) {}
        },
        onDone: () {
          _webSocket = null;
          if (!_isDisposed && isAuthenticated) {
            _scheduleWebSocketReconnect();
          }
        },
        onError: (err) {
          _webSocket = null;
          _lastWebSocketError = _classifyConnectionException(err);
          if (!_isDisposed && isAuthenticated) {
            _scheduleWebSocketReconnect();
          }
        },
      );
    } catch (e) {
      _webSocket = null;
      _lastWebSocketError = _classifyConnectionException(e);
      if (!_isDisposed && isAuthenticated) {
        _scheduleWebSocketReconnect();
      }
      rethrow;
    }
  }

  void _scheduleWebSocketReconnect() {
    if (_isDisposed || !isAuthenticated || _wsReconnectTimer != null) return;
    _wsReconnectTimer = Timer(const Duration(seconds: 3), () async {
      _wsReconnectTimer = null;
      if (!_isDisposed && isAuthenticated && _webSocket == null) {
        try {
          await connectWebSocket();
        } catch (_) {
          // Reconnection attempt failed; will retry again via scheduler on error
        }
      }
    });
  }

  Future<void> disconnectWebSocket() async {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    final ws = _webSocket;
    _webSocket = null;
    try {
      await ws?.close();
    } catch (_) {}
  }

  Future<ServiceApiResponse<dynamic>> _sendRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    try {
      if (configurationError != null) {
        return ServiceApiResponse.failure(configurationError!, statusCode: 400);
      }
      if (!isLoopbackUrl(baseUrl) &&
          baseUrl.toLowerCase().startsWith('http://')) {
        return const ServiceApiResponse.failure(
          'Insecure transport: Remote service requests must use HTTPS.',
          statusCode: 400,
        );
      }
      if (_httpClient == null) {
        return const ServiceApiResponse.failure(
          'HTTP client is not initialized.',
          statusCode: 500,
        );
      }
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
    _isDisposed = true;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    disconnectWebSocket();
    _httpClient?.close(force: true);
    _eventStreamController.close();
  }
}
