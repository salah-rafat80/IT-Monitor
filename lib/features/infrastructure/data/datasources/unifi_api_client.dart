import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';

class UniFiReadonlyTelemetry {
  final String ip;
  final String name;
  final String? model;
  final String? version;
  final int? uptimeSeconds;
  final double? cpuUsage;
  final double? memoryUsage;
  final bool isAdopted;
  final bool isConnected;
  final List<String> supportedSubnets;
  final Map<String, dynamic> rawAttributes;

  const UniFiReadonlyTelemetry({
    required this.ip,
    required this.name,
    this.model,
    this.version,
    this.uptimeSeconds,
    this.cpuUsage,
    this.memoryUsage,
    this.isAdopted = true,
    this.isConnected = true,
    this.supportedSubnets = const [],
    this.rawAttributes = const {},
  });
}

@lazySingleton
class UniFiApiClient {
  late final Dio _dio;

  UniFiApiClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Accept self-signed local SSL certificates commonly used by internal UniFi controllers
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }

  /// Authenticate with read-only credentials against local UniFi OS or CloudKey
  Future<Result<String>> authenticateReadOnly({
    required String controllerUrl,
    required String username,
    required String password,
  }) async {
    if (controllerUrl.trim().isEmpty || username.trim().isEmpty) {
      return Result.failure(
        ValidationFailure(
          'UniFi controller URL and username are required for API integration',
        ),
      );
    }

    try {
      final cleanUrl = controllerUrl.trim().replaceAll(RegExp(r'/+$'), '');

      // Try UniFi OS auth endpoint first (/api/auth/login)
      Response response;
      try {
        response = await _dio.post(
          '$cleanUrl/api/auth/login',
          data: jsonEncode({'username': username, 'password': password}),
        );
      } catch (_) {
        // Fallback to classic controller auth endpoint (/api/login)
        response = await _dio.post(
          '$cleanUrl/api/login',
          data: jsonEncode({'username': username, 'password': password}),
        );
      }

      final setCookie = response.headers.map['set-cookie'];
      final cookieHeader = setCookie != null ? setCookie.join('; ') : '';

      return Result.success(cookieHeader);
    } catch (e) {
      return Result.failure(
        NetworkFailure(
          'Failed to authenticate with UniFi controller (read-only): $e',
        ),
      );
    }
  }

  /// Query read-only device telemetry from /api/s/{site}/stat/device
  Future<Result<List<UniFiReadonlyTelemetry>>> fetchReadonlyDeviceStats({
    required String controllerUrl,
    String siteName = 'default',
    String? sessionCookie,
  }) async {
    if (controllerUrl.trim().isEmpty) {
      return Result.failure(ValidationFailure('Controller URL is required'));
    }

    try {
      final cleanUrl = controllerUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final options = Options(
        headers: sessionCookie != null && sessionCookie.isNotEmpty
            ? {'Cookie': sessionCookie}
            : null,
      );

      // Probe UniFi OS proxy endpoint first, fallback to standard endpoint
      Response response;
      try {
        response = await _dio.get(
          '$cleanUrl/proxy/network/api/s/$siteName/stat/device',
          options: options,
        );
      } catch (_) {
        response = await _dio.get(
          '$cleanUrl/api/s/$siteName/stat/device',
          options: options,
        );
      }

      final data = response.data;
      final rawList = data is Map
          ? (data['data'] as List? ?? [])
          : (data is List ? data : []);

      final results = <UniFiReadonlyTelemetry>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final ip = item['ip']?.toString() ?? '';
          if (ip.isEmpty) continue;

          final name =
              item['name']?.toString() ??
              item['model']?.toString() ??
              'UniFi Device';
          final model = item['model']?.toString();
          final version = item['version']?.toString();
          final uptime = (item['uptime'] is num)
              ? (item['uptime'] as num).toInt()
              : null;
          final state = item['state'];
          final isConnected = state == 1 || state == 'connected';

          results.add(
            UniFiReadonlyTelemetry(
              ip: ip,
              name: name,
              model: model,
              version: version,
              uptimeSeconds: uptime,
              isConnected: isConnected,
              rawAttributes: Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      return Result.success(results);
    } catch (e) {
      return Result.failure(
        NetworkFailure('Failed to query read-only device statistics: $e'),
      );
    }
  }

  /// Safety guard: Explicitly forbid any write/mutation operation
  Future<void> executeWriteOperation() async {
    throw UnsupportedError(
      'UniFi integration is strictly read-only. Configuration changes, provisioning, and reboots are prohibited by policy.',
    );
  }
}
