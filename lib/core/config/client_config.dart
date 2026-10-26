import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_run_mode.dart';

/// Configuration for Desktop Clients connecting to the authoritative Windows Service.
///
/// Supports two explicit operational modes:
/// 1. Local Mode: Client connects to the authoritative service running on the same computer (default: 127.0.0.1:8443).
/// 2. LAN Client Mode: Client connects to a central service host (e.g. https://192.168.1.50:8443) using a trusted
///    public certificate and securely provisioned client token.
class MonitoringClientConfig {
  final String serviceUrl;
  final String? trustedCertPath;
  final String? clientToken;
  final String mode; // 'local' or 'lanClient'
  final String? errorMessage;

  const MonitoringClientConfig({
    required this.serviceUrl,
    this.trustedCertPath,
    this.clientToken,
    this.mode = 'local',
    this.errorMessage,
  });

  const MonitoringClientConfig.error({
    required String this.errorMessage,
    this.serviceUrl = '',
    this.trustedCertPath,
    this.clientToken,
    this.mode = 'error',
  });

  bool get hasError => errorMessage != null;

  bool get isLanClient =>
      mode.toLowerCase() == 'lanclient' ||
      mode.toLowerCase() == 'remote' ||
      !isLoopbackUrl(serviceUrl);

  static bool isLoopbackUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return isLoopbackHost(uri.host);
  }

  static bool isLoopbackHost(String host) {
    var clean = host.trim().toLowerCase();
    if (clean.startsWith('[') && clean.endsWith(']')) {
      clean = clean.substring(1, clean.length - 1);
    }
    return clean == '127.0.0.1' || clean == 'localhost' || clean == '::1';
  }

  /// Construct and validate an HTTPS or HTTP URL from host and port.
  static String formatServiceUrl({
    required String host,
    int port = 8443,
    bool useTls = true,
  }) {
    var cleanHost = host.trim();
    if (cleanHost.startsWith('https://')) {
      cleanHost = cleanHost.substring('https://'.length);
    } else if (cleanHost.startsWith('http://')) {
      cleanHost = cleanHost.substring('http://'.length);
    }
    // Remove trailing slashes or path
    if (cleanHost.contains('/')) {
      cleanHost = cleanHost.split('/').first;
    }
    // If host contains port (e.g. "192.168.1.50:8443"), extract it
    if (cleanHost.contains(':') && !cleanHost.contains(']')) {
      final parts = cleanHost.split(':');
      cleanHost = parts[0];
      final parsedPort = int.tryParse(parts[1]);
      if (parsedPort != null && parsedPort >= 1 && parsedPort <= 65535) {
        port = parsedPort;
      }
    }

    if (cleanHost.isEmpty || cleanHost.contains(' ')) {
      throw FormatException('Invalid service host: "$host".');
    }
    if (port < 1 || port > 65535) {
      throw FormatException(
        'Invalid service port: "$port". Port must be between 1 and 65535.',
      );
    }

    if (!useTls && !isLoopbackHost(cleanHost)) {
      throw FormatException(
        'Production remote endpoint must use HTTPS. Plain HTTP is forbidden for non-loopback host: "$host".',
      );
    }
    if (!useTls && AppConfig.isReleaseEnforced) {
      throw const FormatException(
        'Unencrypted HTTP connections are strictly forbidden in Release mode.',
      );
    }

    final scheme = useTls ? 'https' : 'http';
    return '$scheme://$cleanHost:$port';
  }

  /// Normalize and validate a provided service URL without prepending double schemes.
  static String normalizeServiceUrl(String rawUrl, {bool defaultTls = true}) {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Service URL cannot be empty.');
    }

    if (!trimmed.startsWith('https://') && !trimmed.startsWith('http://')) {
      // Avoid prepending scheme if a custom scheme exists
      if (trimmed.contains('://')) {
        throw FormatException(
          'Unsupported URL scheme in "$rawUrl". Only HTTP and HTTPS are permitted.',
        );
      }
      // Infer host from string to check if remote
      var hostCandidate = trimmed;
      if (hostCandidate.contains('/')) {
        hostCandidate = hostCandidate.split('/').first;
      }
      if (hostCandidate.contains(':') && !hostCandidate.contains(']')) {
        hostCandidate = hostCandidate.split(':').first;
      }
      final isRemoteCandidate = !isLoopbackHost(hostCandidate);
      final defaultScheme = (isRemoteCandidate || defaultTls)
          ? 'https://'
          : 'http://';
      trimmed = '$defaultScheme$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || uri.host.contains(' ')) {
      throw FormatException(
        'Invalid service URL: "$rawUrl". Must be a valid HTTP or HTTPS URL.',
      );
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      throw FormatException(
        'Invalid port in service URL: "$rawUrl". Port must be between 1 and 65535.',
      );
    }

    final isRemote = !isLoopbackHost(uri.host);
    final isHttp = trimmed.toLowerCase().startsWith('http://');

    if (isHttp && isRemote) {
      throw FormatException(
        'Production remote endpoint must use HTTPS. Plain HTTP is forbidden for non-loopback host: "${uri.host}".',
      );
    }
    if (isHttp && AppConfig.isReleaseEnforced) {
      throw FormatException(
        'Unencrypted HTTP connections are strictly forbidden in Release mode: "$rawUrl".',
      );
    }

    return trimmed;
  }

  /// Load client configuration with explicit precedence:
  /// 1. CLI Arguments (Highest)
  /// 2. Environment Variables
  /// 3. Persistent JSON config file (%ProgramData%\ITNetworkMonitor\client_config.json)
  /// 4. Local production defaults (Lowest — only for local deployments without LAN config)
  static MonitoringClientConfig loadFromEnvironmentOrFile([
    List<String>? args,
  ]) {
    args ??= const [];

    // 1. Identify CLI overrides if present
    String? cliConfigPath;
    String? cliServiceUrl;
    String? cliServiceHost;
    int? cliServicePort;
    String? cliToken;
    String? cliTokenFile;
    String? cliCertPath;
    String? cliMode;

    for (final arg in args) {
      if (arg.startsWith('--config=')) {
        cliConfigPath = arg.substring('--config='.length).trim();
      } else if (arg.startsWith('--service-url=')) {
        cliServiceUrl = arg.substring('--service-url='.length).trim();
      } else if (arg.startsWith('--service-host=')) {
        cliServiceHost = arg.substring('--service-host='.length).trim();
      } else if (arg.startsWith('--service-port=')) {
        final portStr = arg.substring('--service-port='.length).trim();
        final parsed = int.tryParse(portStr);
        if (parsed == null || parsed < 1 || parsed > 65535) {
          throw FormatException(
            'Invalid CLI argument --service-port: "$portStr". Port must be an integer between 1 and 65535.',
          );
        }
        cliServicePort = parsed;
      } else if (arg.startsWith('--token=')) {
        cliToken = arg.substring('--token='.length).trim();
      } else if (arg.startsWith('--token-file=')) {
        cliTokenFile = arg.substring('--token-file='.length).trim();
      } else if (arg.startsWith('--cert=')) {
        cliCertPath = arg.substring('--cert='.length).trim();
      } else if (arg.startsWith('--mode=')) {
        cliMode = arg.substring('--mode='.length).trim();
      }
    }

    // Resolve effective CLI service URL if host/port provided
    if (cliServiceUrl == null && cliServiceHost != null) {
      final port = cliServicePort ?? 8443;
      cliServiceUrl = formatServiceUrl(host: cliServiceHost, port: port);
    } else if (cliServiceUrl != null) {
      cliServiceUrl = normalizeServiceUrl(cliServiceUrl);
    }

    // 2. Identify config file location
    final programData = Platform.environment['ProgramData'];
    final defaultConfigFile = programData != null
        ? p.join(programData, 'ITNetworkMonitor', 'client_config.json')
        : 'client_config.json';

    final effectiveConfigPath =
        cliConfigPath ??
        Platform.environment['IT_MONITOR_CLIENT_CONFIG_PATH']?.trim() ??
        Platform.environment['IT_MONITOR_CONFIG_PATH']?.trim() ??
        defaultConfigFile;

    final configDir = p.dirname(effectiveConfigPath);

    // 3. Read persistent JSON config file if present
    String? fileServiceUrl;
    String? fileServiceHost;
    int? fileServicePort;
    String? fileCertPath;
    String? fileToken;
    String? fileTokenFile;
    String? fileMode;

    final configFile = File(effectiveConfigPath);
    if (configFile.existsSync()) {
      String content;
      try {
        content = configFile.readAsStringSync().trim();
      } catch (e) {
        throw StateError(
          'Persistent client configuration file at "${configFile.path}" exists but cannot be read: $e. Access Denied or file locked.',
        );
      }

      if (content.isNotEmpty) {
        dynamic json;
        try {
          json = jsonDecode(content);
        } catch (e) {
          throw FormatException(
            'Persistent client configuration file at "${configFile.path}" contains malformed JSON: $e.',
          );
        }

        if (json is! Map<String, dynamic>) {
          throw FormatException(
            'Persistent client configuration file at "${configFile.path}" must contain a JSON object.',
          );
        }

        fileServiceUrl = (json['serviceUrl'] ?? json['url'])?.toString().trim();
        fileServiceHost = (json['serviceHost'] ?? json['host'])
            ?.toString()
            .trim();
        final rawPort = json['servicePort'] ?? json['port'];
        if (rawPort != null) {
          final pNum = int.tryParse(rawPort.toString().trim());
          if (pNum == null || pNum < 1 || pNum > 65535) {
            throw FormatException(
              'Invalid port "$rawPort" in client configuration file at "${configFile.path}".',
            );
          }
          fileServicePort = pNum;
        }

        fileCertPath =
            (json['trustedCertPath'] ?? json['certPath'] ?? json['cert'])
                ?.toString()
                .trim();
        fileToken = (json['clientToken'] ?? json['token'])?.toString().trim();
        fileTokenFile =
            (json['tokenFile'] ?? json['clientTokenPath'] ?? json['tokenPath'])
                ?.toString()
                .trim();
        fileMode = json['mode']?.toString().trim();
      }
    }

    // 4. Resolve Environment overrides
    final envHost = Platform.environment['IT_MONITOR_SERVICE_HOST']?.trim();
    final envPortStr = Platform.environment['IT_MONITOR_SERVICE_PORT']?.trim();
    int? envPort;
    if (envPortStr != null && envPortStr.isNotEmpty) {
      final pNum = int.tryParse(envPortStr);
      if (pNum == null || pNum < 1 || pNum > 65535) {
        throw FormatException(
          'Invalid environment variable IT_MONITOR_SERVICE_PORT: "$envPortStr". Must be between 1 and 65535.',
        );
      }
      envPort = pNum;
    }

    var envServiceUrl = Platform.environment['IT_MONITOR_SERVICE_URL']?.trim();
    if (envServiceUrl == null && envHost != null && envHost.isNotEmpty) {
      final port = envPort ?? 8443;
      envServiceUrl = formatServiceUrl(host: envHost, port: port);
    } else if (envServiceUrl != null && envServiceUrl.isNotEmpty) {
      envServiceUrl = normalizeServiceUrl(envServiceUrl);
    }

    // Resolve file service URL if host/port specified
    if (fileServiceUrl == null &&
        fileServiceHost != null &&
        fileServiceHost.isNotEmpty) {
      final port = fileServicePort ?? 8443;
      fileServiceUrl = formatServiceUrl(host: fileServiceHost, port: port);
    } else if (fileServiceUrl != null && fileServiceUrl.isNotEmpty) {
      fileServiceUrl = normalizeServiceUrl(fileServiceUrl);
    }

    // 5. Resolve Mode ('local' vs 'lanClient')
    final envMode = Platform.environment['IT_MONITOR_MODE']?.trim();
    String? rawMode = cliMode ?? envMode ?? fileMode;

    // 6. Resolve Service URL
    String resolvedServiceUrl;
    if (cliServiceUrl != null) {
      resolvedServiceUrl = cliServiceUrl;
    } else if (envServiceUrl != null) {
      resolvedServiceUrl = envServiceUrl;
    } else if (fileServiceUrl != null) {
      resolvedServiceUrl = fileServiceUrl;
    } else {
      // If persistent config exists and was configured for LAN mode, do NOT silently fall back to localhost!
      if (rawMode != null &&
          (rawMode.toLowerCase() == 'lanclient' ||
              rawMode.toLowerCase() == 'remote')) {
        throw StateError(
          'LAN Client Configuration Error: Configuration specifies mode "$rawMode" but no service URL or host was provided.',
        );
      }
      final defaultTls = Platform.environment['IT_MONITOR_USE_TLS'] != 'false';
      resolvedServiceUrl = defaultTls
          ? 'https://127.0.0.1:8443'
          : 'http://127.0.0.1:8080';
    }

    // Respect explicit mode if specified; otherwise infer LAN mode if host is non-loopback.
    // If the effective endpoint is remote (non-loopback), mode: local is NEVER allowed to bypass remote validation!
    final isRemoteEndpoint = !isLoopbackUrl(resolvedServiceUrl);
    String resolvedMode;
    if (isRemoteEndpoint) {
      resolvedMode = 'lanClient';
    } else if (rawMode != null &&
        (rawMode.toLowerCase() == 'lanclient' ||
            rawMode.toLowerCase() == 'remote')) {
      resolvedMode = 'lanClient';
    } else {
      resolvedMode = 'local';
    }

    final isLan =
        resolvedMode.toLowerCase() == 'lanclient' ||
        resolvedMode.toLowerCase() == 'remote' ||
        isRemoteEndpoint;

    // Enforce HTTPS on remote endpoints and in Release mode
    final isHttp = resolvedServiceUrl.toLowerCase().startsWith('http://');
    if (isHttp && isRemoteEndpoint) {
      throw FormatException(
        'Insecure remote endpoint rejected: Service endpoint ($resolvedServiceUrl) must use HTTPS. Plain HTTP is forbidden for remote connections.',
      );
    }
    if (isHttp && AppConfig.isReleaseEnforced) {
      throw FormatException(
        'Insecure endpoint rejected: Unencrypted HTTP connections ($resolvedServiceUrl) are strictly forbidden in Release mode.',
      );
    }

    // 7. Resolve Dedicated Client Token File (client.token)
    final envTokenFile =
        Platform.environment['IT_MONITOR_CLIENT_TOKEN_PATH']?.trim() ??
        Platform.environment['IT_MONITOR_TOKEN_PATH']?.trim();

    String? tokenContent;

    // Check explicit CLI token first
    if (cliToken != null && cliToken.isNotEmpty) {
      tokenContent = cliToken;
    } else if (Platform.environment['IT_MONITOR_CLIENT_TOKEN']?.trim() !=
            null &&
        Platform.environment['IT_MONITOR_CLIENT_TOKEN']!.trim().isNotEmpty) {
      tokenContent = Platform.environment['IT_MONITOR_CLIENT_TOKEN']!.trim();
    } else {
      // Check client.token file location
      final effectiveTokenFilePath =
          cliTokenFile ??
          envTokenFile ??
          fileTokenFile ??
          p.join(configDir, 'client.token');

      final tokenFile = File(effectiveTokenFilePath);
      if (tokenFile.existsSync()) {
        try {
          final t = tokenFile.readAsStringSync().trim();
          if (t.isNotEmpty) {
            tokenContent = t;
          }
        } catch (e) {
          throw StateError(
            'Client token file exists at "$effectiveTokenFilePath" but cannot be read: $e.',
          );
        }
      } else if (fileToken != null && fileToken.isNotEmpty) {
        // Fallback to token embedded in client_config.json if client.token is not present
        tokenContent = fileToken;
      }
    }

    // 8. Resolve Public Trusted Certificate Path
    final envCert = Platform.environment['IT_MONITOR_TRUSTED_CERT_PATH']
        ?.trim();
    String? rawCertPath = cliCertPath ?? envCert ?? fileCertPath;

    String? resolvedCertPath;
    if (rawCertPath != null && rawCertPath.isNotEmpty) {
      // If relative path, resolve relative to config file directory
      if (!p.isAbsolute(rawCertPath)) {
        resolvedCertPath = p.normalize(p.join(configDir, rawCertPath));
      } else {
        resolvedCertPath = rawCertPath;
      }
    } else {
      // Default locations: check config directory first
      final candidate1 = p.join(configDir, 'server.crt');
      if (File(candidate1).existsSync()) {
        resolvedCertPath = candidate1;
      } else if (!isLan && cliConfigPath == null) {
        // Only inspect global service directories if local service and no custom --config was specified
        final candidate2 = programData != null
            ? p.join(programData, 'ITNetworkMonitor', 'server.crt')
            : null;
        final candidate3 = programData != null
            ? p.join(programData, 'ITNetworkMonitor', 'certs', 'server.crt')
            : null;

        if (candidate2 != null && File(candidate2).existsSync()) {
          resolvedCertPath = candidate2;
        } else if (candidate3 != null && File(candidate3).existsSync()) {
          resolvedCertPath = candidate3;
        }
      }
    }

    // 9. Fail-Closed Validation for LAN Client Mode
    if (isLan) {
      // LAN client must have a non-empty token
      if (tokenContent == null || tokenContent.isEmpty) {
        throw StateError(
          'LAN Client Configuration Error: Missing client token. Connecting to remote service ($resolvedServiceUrl) requires an authorized bearer token in client.token, --token, or IT_MONITOR_CLIENT_TOKEN.',
        );
      }

      // LAN client must use HTTPS
      if (!resolvedServiceUrl.toLowerCase().startsWith('https://')) {
        throw StateError(
          'LAN Client Configuration Error: Connecting to remote service ($resolvedServiceUrl) requires HTTPS. Plain HTTP is forbidden.',
        );
      }

      // LAN client over HTTPS must have a configured trusted certificate path
      if (resolvedCertPath == null || resolvedCertPath.trim().isEmpty) {
        throw StateError(
          'LAN Client Configuration Error: Missing trusted TLS certificate path. Connecting to remote service ($resolvedServiceUrl) requires a trusted public certificate in client_config.json, --cert, or IT_MONITOR_TRUSTED_CERT_PATH.',
        );
      }
    }

    return MonitoringClientConfig(
      serviceUrl: resolvedServiceUrl,
      trustedCertPath: (resolvedCertPath?.isNotEmpty ?? false)
          ? resolvedCertPath
          : null,
      clientToken: (tokenContent?.isNotEmpty ?? false) ? tokenContent : null,
      mode: resolvedMode,
    );
  }
}
