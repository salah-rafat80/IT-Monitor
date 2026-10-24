import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

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

  const MonitoringClientConfig({
    required this.serviceUrl,
    this.trustedCertPath,
    this.clientToken,
    this.mode = 'local',
  });

  bool get isLanClient =>
      mode.toLowerCase() == 'lanclient' ||
      mode.toLowerCase() == 'remote' ||
      !_isLoopbackUrl(serviceUrl);

  static bool _isLoopbackUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  /// Load client configuration with explicit precedence:
  /// 1. CLI Arguments (Highest)
  /// 2. Environment Variables
  /// 3. Persistent JSON config file (%ProgramData%\ITNetworkMonitor\client_config.json)
  /// 4. Local production defaults (Lowest)
  static MonitoringClientConfig loadFromEnvironmentOrFile([
    List<String>? args,
  ]) {
    args ??= const [];

    // 1. Identify CLI config path override if present
    String? cliConfigPath;
    String? cliServiceUrl;
    String? cliToken;
    String? cliCertPath;
    String? cliMode;

    for (final arg in args) {
      if (arg.startsWith('--config=')) {
        cliConfigPath = arg.substring('--config='.length).trim();
      } else if (arg.startsWith('--service-url=')) {
        cliServiceUrl = arg.substring('--service-url='.length).trim();
      } else if (arg.startsWith('--token=')) {
        cliToken = arg.substring('--token='.length).trim();
      } else if (arg.startsWith('--cert=')) {
        cliCertPath = arg.substring('--cert='.length).trim();
      } else if (arg.startsWith('--mode=')) {
        cliMode = arg.substring('--mode='.length).trim();
      }
    }

    final programData = Platform.environment['ProgramData'];
    final defaultConfigFile = programData != null
        ? p.join(programData, 'ITNetworkMonitor', 'client_config.json')
        : 'client_config.json';

    final effectiveConfigPath =
        cliConfigPath ??
        Platform.environment['IT_MONITOR_CLIENT_CONFIG_PATH'] ??
        Platform.environment['IT_MONITOR_CONFIG_PATH'] ??
        defaultConfigFile;

    // 2. Read persistent JSON config file if present
    String? fileServiceUrl;
    String? fileCertPath;
    String? fileToken;
    String? fileMode;

    final configFile = File(effectiveConfigPath);
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync().trim();
        if (content.isNotEmpty) {
          final json = jsonDecode(content);
          if (json is Map<String, dynamic>) {
            fileServiceUrl =
                (json['serviceUrl'] ?? json['url'])?.toString().trim();
            fileCertPath =
                (json['trustedCertPath'] ?? json['certPath'] ?? json['cert'])
                    ?.toString()
                    .trim();
            fileToken =
                (json['clientToken'] ?? json['token'])?.toString().trim();
            fileMode = json['mode']?.toString().trim();
          }
        }
      } catch (_) {
        // Fall back gracefully if config file contains malformed JSON
      }
    }

    // 3. Resolve Service URL
    final envServiceUrl = Platform.environment['IT_MONITOR_SERVICE_URL']?.trim();
    final defaultUrl = (Platform.environment['IT_MONITOR_USE_TLS'] == 'false')
        ? 'http://127.0.0.1:8080'
        : 'https://127.0.0.1:8443';

    final resolvedServiceUrl =
        cliServiceUrl ??
        envServiceUrl ??
        fileServiceUrl ??
        defaultUrl;

    // 4. Resolve Mode ('local' vs 'lanClient')
    final envMode = Platform.environment['IT_MONITOR_MODE']?.trim();
    String resolvedMode = cliMode ?? envMode ?? fileMode ?? 'local';
    if (!_isLoopbackUrl(resolvedServiceUrl) && resolvedMode == 'local') {
      resolvedMode = 'lanClient';
    }

    // 5. Resolve Public Trusted Certificate Path
    final envCert = Platform.environment['IT_MONITOR_TRUSTED_CERT_PATH']?.trim();
    String? resolvedCertPath = cliCertPath ?? envCert ?? fileCertPath;

    if (resolvedCertPath == null || resolvedCertPath.isEmpty) {
      if (programData != null) {
        final publicCert = p.join(programData, 'ITNetworkMonitor', 'server.crt');
        final certsDirCert = p.join(programData, 'ITNetworkMonitor', 'certs', 'server.crt');
        if (File(publicCert).existsSync()) {
          resolvedCertPath = publicCert;
        } else if (File(certsDirCert).existsSync()) {
          resolvedCertPath = certsDirCert;
        }
      }
    }

    // 6. Resolve Provisioned Client Token
    final envToken = Platform.environment['IT_MONITOR_CLIENT_TOKEN']?.trim();
    String? resolvedToken = cliToken ?? envToken ?? fileToken;

    // For LAN client mode, check if a client.token exists in ProgramData if not provided directly
    if ((resolvedToken == null || resolvedToken.isEmpty) && resolvedMode == 'lanClient' && programData != null) {
      final lanTokenFile = File(p.join(programData, 'ITNetworkMonitor', 'client.token'));
      if (lanTokenFile.existsSync()) {
        try {
          final t = lanTokenFile.readAsStringSync().trim();
          if (t.isNotEmpty) resolvedToken = t;
        } catch (_) {}
      }
    }

    return MonitoringClientConfig(
      serviceUrl: resolvedServiceUrl,
      trustedCertPath: (resolvedCertPath?.isNotEmpty ?? false) ? resolvedCertPath : null,
      clientToken: (resolvedToken?.isNotEmpty ?? false) ? resolvedToken : null,
      mode: resolvedMode,
    );
  }
}
