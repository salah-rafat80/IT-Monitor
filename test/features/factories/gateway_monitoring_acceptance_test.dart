import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/config/factory_network_config.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/factories/domain/entities/factory_entity.dart';
import 'package:it_network_monitor/features/factories/domain/entities/gateway_status_entity.dart';
import 'package:it_network_monitor/features/factories/domain/repositories/factory_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitoring_config.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/monitoring_scheduler.dart';
import 'package:it_network_monitor/features/monitoring/domain/services/ping_checker.dart';

class _MockDeviceRepository implements DeviceRepository {
  final List<DeviceEntity> devices;
  _MockDeviceRepository(this.devices);

  @override
  Future<Result<List<DeviceEntity>>> getDevices({
    String? factoryId,
    String? department,
    String? officeLocation,
    DeviceType? type,
    bool? isEnabled,
    bool? isMonitored,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    var filtered = devices.toList();
    if (factoryId != null) {
      filtered = filtered.where((d) => d.factoryId == factoryId).toList();
    }
    return Result.success(filtered);
  }

  @override
  Future<Result<DeviceEntity>> getDeviceById(int id) async {
    final dev = devices.firstWhere((d) => d.id == id);
    return Result.success(dev);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMonitoringRepository implements MonitoringRepository {
  final List<CheckResult> savedChecks = [];
  final Map<int, DeviceStatusEntity> statuses = {};

  @override
  Future<Result<void>> saveCheckResult(CheckResult result) async {
    savedChecks.add(result);
    return Result.success(null);
  }

  @override
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses() async {
    return Result.success(statuses.values.toList());
  }

  @override
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId) async {
    return Result.success(
      statuses[deviceId] ?? DeviceStatusEntity.initial(deviceId),
    );
  }

  @override
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status) async {
    statuses[status.deviceId] = status;
    return Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFactoryRepository implements FactoryRepository {
  final List<FactoryEntity> factories;
  final Map<String, GatewayStatusEntity> gatewayStatuses = {};

  _MockFactoryRepository(this.factories);

  @override
  Future<Result<List<FactoryEntity>>> getFactories({
    bool includeInactive = false,
  }) async {
    return Result.success(factories);
  }

  @override
  Future<Result<GatewayStatusEntity?>> getGatewayStatus(
    String factoryId,
  ) async {
    return Result.success(gatewayStatuses[factoryId]);
  }

  @override
  Future<Result<void>> saveGatewayStatus(GatewayStatusEntity status) async {
    gatewayStatuses[status.factoryId] = status;
    return Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPingChecker implements PingChecker {
  final Map<String, bool> targetResults;
  final Map<String, int> targetLatencies;

  _MockPingChecker({
    required this.targetResults,
    required this.targetLatencies,
  });

  @override
  Future<CheckResult> checkPing({
    required int deviceId,
    required String targetIp,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final isSuccess = targetResults[targetIp] ?? false;
    final latency = targetLatencies[targetIp] ?? 10;
    return CheckResult(
      deviceId: deviceId,
      targetIp: targetIp,
      checkType: CheckType.icmp,
      isSuccess: isSuccess,
      latencyMs: isSuccess ? latency : null,
      errorMessage: isSuccess ? null : 'Destination unreachable',
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('Factory Gateway Independent Monitoring & Isolation Acceptance Tests', () {
    late _MockDeviceRepository deviceRepo;
    late _MockMonitoringRepository monitoringRepo;
    late _MockFactoryRepository factoryRepo;
    late _MockPingChecker pingChecker;
    late MonitoringScheduler scheduler;

    final rnfFactory = FactoryEntity(
      id: FactoryNetworkConfig.rnfId,
      code: FactoryNetworkConfig.rnfCode,
      name: FactoryNetworkConfig.rnfName,
      gatewayIp: FactoryNetworkConfig.rnfGatewayIp,
      subnetMask: FactoryNetworkConfig.rnfSubnetMask,
      expectedCidr: FactoryNetworkConfig.rnfCidr,
      createdAt: DateTime.now(),
    );

    final bnfFactory = FactoryEntity(
      id: FactoryNetworkConfig.bnfId,
      code: FactoryNetworkConfig.bnfCode,
      name: FactoryNetworkConfig.bnfName,
      gatewayIp: FactoryNetworkConfig.bnfGatewayIp,
      subnetMask: FactoryNetworkConfig.bnfSubnetMask,
      expectedCidr: FactoryNetworkConfig.bnfCidr,
      createdAt: DateTime.now(),
    );

    final rnfDevice = DeviceEntity(
      id: 1,
      factoryId: FactoryNetworkConfig.rnfId,
      name: 'RNF-PC-01',
      ip: '192.168.22.50',
      type: DeviceType.pc,
      ownerName: 'Alice',
      department: 'IT',
      isEnabled: true,
      isMonitored: true,
      createdAt: DateTime.now(),
    );

    final bnfDevice = DeviceEntity(
      id: 2,
      factoryId: FactoryNetworkConfig.bnfId,
      name: 'BNF-PC-01',
      ip: '192.168.21.50',
      type: DeviceType.pc,
      ownerName: 'Bob',
      department: 'Finance',
      isEnabled: true,
      isMonitored: true,
      createdAt: DateTime.now(),
    );

    setUp(() {
      deviceRepo = _MockDeviceRepository([rnfDevice, bnfDevice]);
      monitoringRepo = _MockMonitoringRepository();
      factoryRepo = _MockFactoryRepository([rnfFactory, bnfFactory]);
      pingChecker = _MockPingChecker(
        targetResults: {
          FactoryNetworkConfig.rnfGatewayIp: true, // 192.168.22.1 UP
          FactoryNetworkConfig.bnfGatewayIp: false, // 192.168.21.1 DOWN
          rnfDevice.ip: true,
          bnfDevice.ip: false,
        },
        targetLatencies: {
          FactoryNetworkConfig.rnfGatewayIp: 2,
          rnfDevice.ip: 5,
        },
      );

      scheduler = MonitoringScheduler(
        deviceRepo,
        monitoringRepo,
        pingChecker,
        null,
        null,
        factoryRepo,
      );

      scheduler.updateConfig(
        const MonitoringConfig(
          checkIntervalSeconds: 60,
          timeoutSeconds: 3,
          failureThreshold: 3,
          recoveryThreshold: 1,
          maxConcurrentChecks: 20,
        ),
      );
    });

    test(
      '1. Authoritative Gateway targets are checked as first-class persistent entities',
      () async {
        final success = await scheduler.triggerAllChecks(force: true);
        expect(success, isTrue);

        // Verify RNF Gateway check result
        final rnfGatewayCheck = monitoringRepo.savedChecks.firstWhere(
          (c) =>
              c.assetId == 'gateway' &&
              c.factoryId == FactoryNetworkConfig.rnfId,
        );
        expect(
          rnfGatewayCheck.targetIp,
          equals(FactoryNetworkConfig.rnfGatewayIp),
        );
        expect(rnfGatewayCheck.isSuccess, isTrue);
        expect(rnfGatewayCheck.latencyMs, equals(2));

        // Verify BNF Gateway check result
        final bnfGatewayCheck = monitoringRepo.savedChecks.firstWhere(
          (c) =>
              c.assetId == 'gateway' &&
              c.factoryId == FactoryNetworkConfig.bnfId,
        );
        expect(
          bnfGatewayCheck.targetIp,
          equals(FactoryNetworkConfig.bnfGatewayIp),
        );
        expect(bnfGatewayCheck.isSuccess, isFalse);

        // Verify Gateway Status persistence
        final rnfStatus =
            factoryRepo.gatewayStatuses[FactoryNetworkConfig.rnfId];
        final bnfStatus =
            factoryRepo.gatewayStatuses[FactoryNetworkConfig.bnfId];

        expect(rnfStatus, isNotNull);
        expect(rnfStatus!.isOnline, isTrue);
        expect(rnfStatus.consecutiveSuccesses, equals(1));
        expect(rnfStatus.latencyMs, equals(2));

        expect(bnfStatus, isNotNull);
        expect(bnfStatus!.consecutiveFailures, equals(1));
      },
    );

    test(
      '2. Disconnecting one gateway does NOT halt or impact monitoring of the other',
      () async {
        await scheduler.triggerAllChecks(force: true);

        final rnfStatus =
            factoryRepo.gatewayStatuses[FactoryNetworkConfig.rnfId];
        final bnfStatus =
            factoryRepo.gatewayStatuses[FactoryNetworkConfig.bnfId];

        expect(rnfStatus?.isOnline, isTrue);
        expect(bnfStatus?.consecutiveFailures, equals(1));

        // Device checks also ran independently
        final rnfDeviceCheck = monitoringRepo.savedChecks.firstWhere(
          (c) => c.deviceId == rnfDevice.id,
        );
        final bnfDeviceCheck = monitoringRepo.savedChecks.firstWhere(
          (c) => c.deviceId == bnfDevice.id,
        );

        expect(rnfDeviceCheck.isSuccess, isTrue);
        expect(bnfDeviceCheck.isSuccess, isFalse);
      },
    );

    test('3. Three consecutive failures transition gateway to Down', () async {
      await scheduler.triggerAllChecks(force: true);
      expect(
        factoryRepo
            .gatewayStatuses[FactoryNetworkConfig.bnfId]!
            .consecutiveFailures,
        equals(1),
      );
      expect(
        factoryRepo.gatewayStatuses[FactoryNetworkConfig.bnfId]!.isDown,
        isFalse,
      );

      await scheduler.triggerAllChecks(force: true);
      expect(
        factoryRepo
            .gatewayStatuses[FactoryNetworkConfig.bnfId]!
            .consecutiveFailures,
        equals(2),
      );
      expect(
        factoryRepo.gatewayStatuses[FactoryNetworkConfig.bnfId]!.isDown,
        isFalse,
      );

      await scheduler.triggerAllChecks(force: true);
      expect(
        factoryRepo
            .gatewayStatuses[FactoryNetworkConfig.bnfId]!
            .consecutiveFailures,
        equals(3),
      );
      expect(
        factoryRepo.gatewayStatuses[FactoryNetworkConfig.bnfId]!.isDown,
        isTrue,
      );
    });
  });
}
