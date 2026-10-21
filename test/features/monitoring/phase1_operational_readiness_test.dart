import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/platform_ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/status_engine.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_device_card.dart';
import 'package:it_network_monitor/features/wall_display/presentation/widgets/wall_display_grid.dart';

void main() {
  group('Phase 1: Windows ICMP Result Classification & Latency Accuracy', () {
    const targetIp = '192.168.27.28';

    test(
      '1. Successful Echo Reply from intended target extracts latency and confirms success',
      () {
        const stdout = '''
Pinging 192.168.27.28 with 32 bytes of data:
Reply from 192.168.27.28: bytes=32 time=3ms TTL=128

Ping statistics for 192.168.27.28:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 3ms, Maximum = 3ms, Average = 3ms
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: targetIp,
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(3));
        expect(res.failureReason, equals(PingFailureReason.none));
        expect(res.respondingSourceIp, equals(targetIp));
      },
    );

    test(
      '2. Sub-1ms successful Echo Reply (time<1ms) correctly records 1ms latency',
      () {
        const stdout = '''
Pinging 192.168.27.28 with 32 bytes of data:
Reply from 192.168.27.28: bytes=32 time<1ms TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: targetIp,
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(1));
        expect(res.failureReason, equals(PingFailureReason.none));
      },
    );

    test(
      '3. Multilingual successful response (Arabic locale) is correctly recognized',
      () {
        const stdout = '''
يتم الآن الاتصال بـ 192.168.27.28 مع 32 بايت من البيانات:
الرد من 192.168.27.28: بايت=32 الوقت=5 مللي ثانية TTL=64
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 0,
          targetIp: targetIp,
        );

        expect(res.isSuccess, isTrue);
        expect(res.latencyMs, equals(5));
        expect(res.failureReason, equals(PingFailureReason.none));
      },
    );

    test(
      '4. Destination Host Unreachable from monitoring host adapter is NOT success and has null latency',
      () {
        // The exact failure reported by the user: Reply from 192.168.27.64: Destination host unreachable
        const stdout = '''
Pinging 192.168.27.28 with 32 bytes of data:
Reply from 192.168.27.64: Destination host unreachable.

Ping statistics for 192.168.27.28:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode:
              0, // Windows ping returns exit code 0 when ICMP packet is received!
          targetIp: targetIp,
        );

        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(
          res.failureReason,
          equals(PingFailureReason.destinationUnreachable),
        );
        expect(res.respondingSourceIp, equals('192.168.27.64'));
      },
    );

    test('5. Request timed out is classified as timeout with null latency', () {
      const stdout = '''
Pinging 192.168.27.28 with 32 bytes of data:
Request timed out.

Ping statistics for 192.168.27.28:
    Packets: Sent = 1, Received = 0, Lost = 1 (100% loss),
''';

      final res = PlatformPingChecker.parsePingOutput(
        stdout: stdout,
        stderr: '',
        exitCode: 1,
        targetIp: targetIp,
      );

      expect(res.isSuccess, isFalse);
      expect(res.latencyMs, isNull);
      expect(res.failureReason, equals(PingFailureReason.timeout));
    });

    test(
      '6. General failure / hardware error is classified as general network failure',
      () {
        const stdout = '''
Pinging 192.168.27.28 with 32 bytes of data:
General failure.
''';

        final res = PlatformPingChecker.parsePingOutput(
          stdout: stdout,
          stderr: '',
          exitCode: 1,
          targetIp: targetIp,
        );

        expect(res.isSuccess, isFalse);
        expect(res.latencyMs, isNull);
        expect(
          res.failureReason,
          equals(PingFailureReason.generalNetworkFailure),
        );
      },
    );
  });

  group('Phase 1: StatusEngine Latency & Debounce Semantics', () {
    const config = MonitoringConfig(failureThreshold: 3, recoveryThreshold: 2);

    test(
      '1. Failed check sets current latency to null and preserves historical latency',
      () {
        final initialStatus = DeviceStatusEntity(
          deviceId: 1,
          status: DeviceStatusEnum.up,
          lastLatencyMs: 12,
          lastSuccessfulLatencyMs: 12,
          lastSeen: DateTime(2026, 10, 13, 10, 0),
          statusChangedAt: DateTime(2026, 10, 13, 10, 0),
        );

        final failedCheck = CheckResult.failure(
          deviceId: 1,
          targetIp: '192.168.27.28',
          timestamp: DateTime(2026, 10, 13, 10, 5),
          errorMessage: 'Destination host unreachable',
          failureReason: PingFailureReason.destinationUnreachable,
          respondingSourceIp: '192.168.27.64',
        );

        final updated = StatusEngine.processCheckResult(
          currentStatus: initialStatus,
          checkResult: failedCheck,
          config: config,
        );

        // Current check latency MUST be null
        expect(updated.lastLatencyMs, isNull);
        // Historical latency is preserved
        expect(updated.lastSuccessfulLatencyMs, equals(12));
        // Last seen is not updated
        expect(updated.lastSeen, equals(DateTime(2026, 10, 13, 10, 0)));
        // Consecutive failures incremented
        expect(updated.consecutiveFailures, equals(1));
        // Status remains UP until 3 failures
        expect(updated.status, equals(DeviceStatusEnum.up));
        // Failure reason recorded
        expect(
          updated.lastFailureReason,
          equals('Destination host unreachable'),
        );
      },
    );

    test('2. Three consecutive failures transition status to Down', () {
      var status = DeviceStatusEntity(
        deviceId: 1,
        status: DeviceStatusEnum.up,
        lastLatencyMs: 8,
        lastSuccessfulLatencyMs: 8,
        statusChangedAt: DateTime.now(),
      );

      final checkFail = CheckResult.failure(
        deviceId: 1,
        targetIp: '192.168.27.28',
        timestamp: DateTime.now(),
        errorMessage: 'Request timed out',
        failureReason: PingFailureReason.timeout,
      );

      // 1st failure -> Up (debouncing)
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: checkFail,
        config: config,
      );
      expect(status.status, equals(DeviceStatusEnum.up));
      expect(status.consecutiveFailures, equals(1));
      expect(status.lastLatencyMs, isNull);

      // 2nd failure -> Up (debouncing)
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: checkFail,
        config: config,
      );
      expect(status.status, equals(DeviceStatusEnum.up));
      expect(status.consecutiveFailures, equals(2));

      // 3rd failure -> Down (threshold reached)
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: checkFail,
        config: config,
      );
      expect(status.status, equals(DeviceStatusEnum.down));
      expect(status.consecutiveFailures, equals(3));
      expect(status.lastLatencyMs, isNull);
      expect(status.lastSuccessfulLatencyMs, equals(8)); // Historical preserved
    });

    test('3. Intervening success resets failure streak', () {
      var status = DeviceStatusEntity(
        deviceId: 1,
        status: DeviceStatusEnum.up,
        consecutiveFailures: 2,
        statusChangedAt: DateTime.now(),
      );

      final checkSuccess = CheckResult.success(
        deviceId: 1,
        targetIp: '192.168.27.28',
        timestamp: DateTime.now(),
        latencyMs: 5,
      );

      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: checkSuccess,
        config: config,
      );
      expect(status.consecutiveFailures, equals(0));
      expect(status.status, equals(DeviceStatusEnum.up));
      expect(status.lastLatencyMs, equals(5));
      expect(status.lastSuccessfulLatencyMs, equals(5));
      expect(status.lastFailureReason, isNull);
    });

    test('4. Two consecutive successes recover Down device to Up', () {
      var status = DeviceStatusEntity(
        deviceId: 1,
        status: DeviceStatusEnum.down,
        consecutiveFailures: 3,
        statusChangedAt: DateTime.now(),
      );

      final checkSuccess = CheckResult.success(
        deviceId: 1,
        targetIp: '192.168.27.28',
        timestamp: DateTime.now(),
        latencyMs: 6,
      );

      // 1st success -> still Down (recovery threshold is 2)
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: checkSuccess,
        config: config,
      );
      expect(status.status, equals(DeviceStatusEnum.down));
      expect(status.consecutiveSuccesses, equals(1));

      // 2nd success -> recovers to Up
      status = StatusEngine.processCheckResult(
        currentStatus: status,
        checkResult: checkSuccess,
        config: config,
      );
      expect(status.status, equals(DeviceStatusEnum.up));
      expect(status.consecutiveSuccesses, equals(2));
      expect(status.lastLatencyMs, equals(6));
    });

    test(
      '5. Failed check during recovery resets consecutive successes to zero',
      () {
        var status = DeviceStatusEntity(
          deviceId: 1,
          status: DeviceStatusEnum.down,
          consecutiveSuccesses: 1,
          statusChangedAt: DateTime.now(),
        );

        final checkFail = CheckResult.failure(
          deviceId: 1,
          targetIp: '192.168.27.28',
          timestamp: DateTime.now(),
          errorMessage: 'Request timed out',
          failureReason: PingFailureReason.timeout,
        );

        status = StatusEngine.processCheckResult(
          currentStatus: status,
          checkResult: checkFail,
          config: config,
        );
        expect(status.status, equals(DeviceStatusEnum.down));
        expect(status.consecutiveSuccesses, equals(0));
        expect(status.consecutiveFailures, equals(1));
      },
    );
  });

  group('Phase 1: Wall Display Fit & Latency Accuracy Verification', () {
    testWidgets(
      '1. Down device does NOT render active latency badge on WallDeviceCard',
      (tester) async {
        final downDevice = MonitoredDevice(
          device: DeviceEntity(
            id: 1,
            name: 'WS-ENG-01',
            type: DeviceType.pc,
            ip: '192.168.27.28',
            ownerName: 'Ahmed Salah',
            department: 'Engineering',
            createdAt: DateTime.now(),
          ),
          status: DeviceStatusEntity(
            deviceId: 1,
            status: DeviceStatusEnum.down,
            lastLatencyMs: null, // failed check -> null
            lastSuccessfulLatencyMs: 4, // historical
            lastFailureReason: 'Destination host unreachable',
            statusChangedAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 100,
                child: WallDeviceCard(item: downDevice),
              ),
            ),
          ),
        );

        // Must find Owner, Dept, Device Name, IP, Disconnected chip
        expect(find.text('Ahmed Salah'), findsOneWidget);
        expect(find.textContaining('Engineering'), findsOneWidget);
        expect(find.textContaining('WS-ENG-01'), findsOneWidget);
        expect(find.textContaining('192.168.27.28'), findsOneWidget);
        expect(find.text('Disconnected'), findsOneWidget);

        // Must NOT find a "4ms" active badge
        expect(find.text('4ms'), findsNothing);
      },
    );

    testWidgets('2. Up device renders active latency badge on WallDeviceCard', (
      tester,
    ) async {
      final upDevice = MonitoredDevice(
        device: DeviceEntity(
          id: 2,
          name: 'WS-FIN-02',
          type: DeviceType.laptop,
          ip: '192.168.27.35',
          ownerName: 'Sara Ali',
          department: 'Finance',
          createdAt: DateTime.now(),
        ),
        status: DeviceStatusEntity(
          deviceId: 2,
          status: DeviceStatusEnum.up,
          lastLatencyMs: 3,
          lastSuccessfulLatencyMs: 3,
          statusChangedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 100,
              child: WallDeviceCard(item: upDevice),
            ),
          ),
        ),
      );

      expect(find.text('Sara Ali'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('3ms'), findsOneWidget);
    });

    testWidgets(
      '3. All 37 approved devices fit in single screen without scroll physics',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final devices37 = List.generate(
          37,
          (i) => MonitoredDevice(
            device: DeviceEntity(
              id: i + 1,
              name: 'DEV-${i + 1}',
              type: DeviceType.pc,
              ip: '192.168.27.${i + 10}',
              ownerName: 'User ${i + 1}',
              department: 'IT',
              createdAt: DateTime.now(),
            ),
            status: DeviceStatusEntity.initial(i + 1),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WallDisplayGrid(devices: devices37)),
          ),
        );

        await tester.pumpAndSettle();

        // Check Grid physics
        final gridFinder = find.byType(GridView);
        expect(gridFinder, findsOneWidget);
        final gridWidget = tester.widget<GridView>(gridFinder);
        expect(gridWidget.physics, isA<NeverScrollableScrollPhysics>());

        // All 37 cards present
        expect(find.byType(WallDeviceCard), findsNWidgets(37));
      },
    );
  });
}
