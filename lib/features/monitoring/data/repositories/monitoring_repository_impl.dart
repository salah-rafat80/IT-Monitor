import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../datasources/monitoring_service_client.dart';
import '../../domain/entities/check_result.dart';
import '../../domain/entities/device_status_entity.dart';
import '../../domain/repositories/monitoring_repository.dart';

@LazySingleton(as: MonitoringRepository)
class MonitoringRepositoryImpl implements MonitoringRepository {
  final AppDatabase _db;
  final StreamController<List<DeviceStatusEntity>> _allStatusesController =
      StreamController<List<DeviceStatusEntity>>.broadcast();
  final MonitoringServiceClient? _serviceClient;
  StreamSubscription? _serviceEventSub;

  MonitoringRepositoryImpl(this._db, [this._serviceClient]) {
    _initServiceEventSubscription();
  }

  MonitoringServiceClient? get _effectiveClient =>
      _serviceClient ??
      (getIt.isRegistered<MonitoringServiceClient>()
          ? getIt<MonitoringServiceClient>()
          : null);

  void _initServiceEventSubscription() {
    final client = _effectiveClient;
    if (client != null) {
      _serviceEventSub?.cancel();
      _serviceEventSub = client.eventStream.listen((event) {
        if (event['event'] == 'device_statuses_updated' &&
            event['data'] is List) {
          final list = (event['data'] as List)
              .map(
                (e) => DeviceStatusEntity.fromJson(e as Map<String, dynamic>),
              )
              .toList();
          _allStatusesController.add(list);
        }
      });
    }
  }

  @override
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses() async {
    final client = _effectiveClient;
    if (client != null && client.isAuthenticated) {
      final res = await client.getDevices();
      if (res.isSuccess && res.data != null) {
        final list = res.data!.map((item) {
          final stMap = item['status'] as Map<String, dynamic>;
          return DeviceStatusEntity.fromJson(stMap);
        }).toList();
        return Result.success(list);
      } else {
        return Result.failure(
          NetworkFailure(
            'Authoritative monitoring service is unreachable (${res.errorMessage}). '
            'Ensure IT Network Monitor Service is running.',
          ),
        );
      }
    }

    try {
      final rows = await _db.select(_db.deviceStatuses).get();
      final entities = rows.map((r) => _mapToEntity(r)).toList();
      return Result.success(entities);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to load device statuses: $e'),
      );
    }
  }

  @override
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId) async {
    try {
      final r = await (_db.select(
        _db.deviceStatuses,
      )..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
      if (r == null) {
        return Result.success(DeviceStatusEntity.initial(deviceId));
      }
      return Result.success(_mapToEntity(r));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to load device status: $e'),
      );
    }
  }

  @override
  Future<Result<void>> saveCheckResult(CheckResult result) async {
    try {
      await _db
          .into(_db.checkResults)
          .insert(
            CheckResultsCompanion.insert(
              deviceId: result.deviceId,
              assetId: Value(result.assetId),
              targetIp: result.targetIp,
              checkType: Value(result.checkType.toValue()),
              isSuccess: result.isSuccess,
              latencyMs: Value(result.latencyMs),
              packetLossPercent: Value(result.packetLossPercent),
              errorMessage: Value(result.errorMessage),
              timestamp: Value(result.timestamp),
            ),
          );
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to save check result: $e'));
    }
  }

  @override
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status) async {
    try {
      await _db
          .into(_db.deviceStatuses)
          .insertOnConflictUpdate(
            DeviceStatusesCompanion.insert(
              deviceId: Value(status.deviceId),
              status: Value(status.status.toValue()),
              lastSeen: Value(status.lastSeen),
              lastCheckAt: Value(status.lastCheckAt),
              lastLatencyMs: Value(status.lastLatencyMs),
              lastSuccessfulLatencyMs: Value(status.lastSuccessfulLatencyMs),
              lastFailureReason: Value(status.lastFailureReason),
              consecutiveFailures: Value(status.consecutiveFailures),
              consecutiveSuccesses: Value(status.consecutiveSuccesses),
              statusChangedAt: Value(status.statusChangedAt),
              isMaintenance: Value(status.isMaintenance),
            ),
          );

      // Notify broadcast subscribers
      final allRes = await getDeviceStatuses();
      if (allRes.isSuccess) {
        _allStatusesController.add(allRes.dataOrNull!);
      }

      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to save device status: $e'),
      );
    }
  }

  @override
  Future<Result<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async {
    try {
      final currentRes = await getDeviceStatus(deviceId);
      final current =
          currentRes.dataOrNull ?? DeviceStatusEntity.initial(deviceId);

      final updated = current.copyWith(
        isMaintenance: isMaintenance,
        status: isMaintenance
            ? DeviceStatusEnum.maintenance
            : DeviceStatusEnum.unknown,
        statusChangedAt: DateTime.now(),
      );

      return await saveDeviceStatus(updated);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to update maintenance mode: $e'),
      );
    }
  }

  @override
  Stream<DeviceStatusEntity> watchDeviceStatus(int deviceId) {
    return _allStatusesController.stream.map((list) {
      return list.firstWhere(
        (s) => s.deviceId == deviceId,
        orElse: () => DeviceStatusEntity.initial(deviceId),
      );
    });
  }

  @override
  Stream<List<DeviceStatusEntity>> watchAllDeviceStatuses() {
    return _allStatusesController.stream;
  }

  DeviceStatusEntity _mapToEntity(DeviceStatusData r) {
    return DeviceStatusEntity(
      deviceId: r.deviceId,
      status: DeviceStatusEnum.fromString(r.status),
      lastSeen: r.lastSeen,
      lastCheckAt: r.lastCheckAt,
      lastLatencyMs: r.lastLatencyMs,
      lastSuccessfulLatencyMs: r.lastSuccessfulLatencyMs,
      lastFailureReason: r.lastFailureReason,
      consecutiveFailures: r.consecutiveFailures,
      consecutiveSuccesses: r.consecutiveSuccesses,
      statusChangedAt: r.statusChangedAt,
      isMaintenance: r.isMaintenance,
    );
  }
}
