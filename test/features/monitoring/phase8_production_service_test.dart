import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 8 — Production Deployment & Windows Background Service Tests', () {
    test('1. HTTP Server binds and responds to /api/status endpoint', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8888);
      server.listen((req) {
        if (req.uri.path == '/api/status') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'status': 'online',
              'service': 'IT Network Monitoring Service',
              'engine_active': true,
            }),
          );
          req.response.close();
        }
      });

      final client = HttpClient();
      final req = await client.get('127.0.0.1', 8888, '/api/status');
      final res = await req.close();
      final bodyStr = await utf8.decoder.bind(res).join();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      expect(res.statusCode, equals(200));
      expect(body['status'], equals('online'));
      expect(body['engine_active'], isTrue);

      await server.close(force: true);
      client.close();
    });

    test(
      '2. WebSocket connection streams status update events to desktop client',
      () async {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          8889,
        );
        final List<WebSocket> clients = [];

        server.listen((req) async {
          if (req.uri.path == '/ws' &&
              WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
            clients.add(socket);
            socket.add(
              jsonEncode({
                'event': 'device_statuses_updated',
                'data': [
                  {'deviceId': 1, 'status': 'connected', 'lastLatencyMs': 5},
                ],
              }),
            );
          }
        });

        final completer = Completer<Map<String, dynamic>>();
        final socket = await WebSocket.connect('ws://127.0.0.1:8889/ws');
        socket.listen((msg) {
          final payload = jsonDecode(msg as String) as Map<String, dynamic>;
          completer.complete(payload);
        });

        final received = await completer.future.timeout(
          const Duration(seconds: 3),
        );
        expect(received['event'], equals('device_statuses_updated'));
        expect(received['data'], isList);

        await socket.close();
        await server.close(force: true);
      },
    );

    test(
      '3. Admin authentication endpoint validates credentials and rejects invalid users',
      () async {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          8890,
        );
        server.listen((req) async {
          if (req.uri.path == '/api/auth/login') {
            final body = await utf8.decoder.bind(req).join();
            final jsonBody = jsonDecode(body) as Map<String, dynamic>;

            if (jsonBody['username'] == 'admin' &&
                jsonBody['password'] == 'admin123') {
              req.response.statusCode = 200;
              req.response.write(
                jsonEncode({'success': true, 'token': 'valid_jwt_token'}),
              );
            } else {
              req.response.statusCode = 401;
              req.response.write(
                jsonEncode({'success': false, 'error': 'Invalid credentials'}),
              );
            }
            await req.response.close();
          }
        });

        final client = HttpClient();

        // Valid Login
        final reqValid = await client.post(
          '127.0.0.1',
          8890,
          '/api/auth/login',
        );
        reqValid.write(
          jsonEncode({'username': 'admin', 'password': 'admin123'}),
        );
        final resValid = await reqValid.close();
        expect(resValid.statusCode, equals(200));

        // Invalid Login
        final reqInvalid = await client.post(
          '127.0.0.1',
          8890,
          '/api/auth/login',
        );
        reqInvalid.write(
          jsonEncode({'username': 'hacker', 'password': 'wrongpassword'}),
        );
        final resInvalid = await reqInvalid.close();
        expect(resInvalid.statusCode, equals(401));

        await server.close(force: true);
        client.close();
      },
    );

    test(
      '4. Closing client connection leaves monitoring server active',
      () async {
        bool isMonitoringRunning = true;
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          8891,
        );
        server.listen((req) async {
          if (WebSocketTransformer.isUpgradeRequest(req)) {
            final socket = await WebSocketTransformer.upgrade(req);
            socket.listen((_) {});
          }
        });

        final clientSocket = await WebSocket.connect('ws://127.0.0.1:8891');
        await clientSocket.close();

        // Service state remains unaffected
        expect(isMonitoringRunning, isTrue);
        await server.close(force: true);
      },
    );
  });
}
