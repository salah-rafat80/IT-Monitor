import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/classification_confidence.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/discovery_config_entity.dart';
import '../../domain/entities/discovery_evidence_item.dart';
import '../../domain/entities/discovery_scan_job.dart';
import '../../domain/entities/review_state.dart';
import '../../domain/repositories/discovery_repository.dart';

@LazySingleton(as: DiscoveryRepository)
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final AppDatabase _db;

  DiscoveryRepositoryImpl(this._db);

  @override
  Future<Result<DiscoveryConfigEntity>> getConfig() async {
    try {
      final row = await (_db.select(
        _db.discoveryConfigurations,
      )..limit(1)).getSingleOrNull();
      if (row == null) {
        final initial = DiscoveryConfigEntity.initial();
        await saveConfig(initial);
        return Result.success(initial);
      }

      final ranges = (jsonDecode(row.authorizedRangesJson) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      final strategies =
          (jsonDecode(row.enabledStrategiesJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();

      return Result.success(
        DiscoveryConfigEntity(
          authorizedRanges: ranges,
          enabledStrategies: strategies,
          maxConcurrency: row.maxConcurrency,
          timeoutSeconds: row.timeoutSeconds,
          updatedAt: row.updatedAt,
        ),
      );
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to load discovery configuration: $e'),
      );
    }
  }

  @override
  Future<Result<void>> saveConfig(DiscoveryConfigEntity config) async {
    try {
      final existing = await (_db.select(
        _db.discoveryConfigurations,
      )..limit(1)).getSingleOrNull();
      final companion = DiscoveryConfigurationsCompanion(
        authorizedRangesJson: Value(jsonEncode(config.authorizedRanges)),
        enabledStrategiesJson: Value(jsonEncode(config.enabledStrategies)),
        maxConcurrency: Value(config.maxConcurrency),
        timeoutSeconds: Value(config.timeoutSeconds),
        updatedAt: Value(DateTime.now()),
      );

      if (existing == null) {
        await _db.into(_db.discoveryConfigurations).insert(companion);
      } else {
        await (_db.update(
          _db.discoveryConfigurations,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to save discovery configuration: $e'),
      );
    }
  }

  @override
  Future<Result<int>> createScanJob(DiscoveryScanJob job) async {
    try {
      final id = await _db
          .into(_db.discoveryScans)
          .insert(
            DiscoveryScansCompanion(
              status: Value(job.status.toValue()),
              rangesJson: Value(jsonEncode(job.targetRanges)),
              enabledStrategiesJson: Value(jsonEncode(job.enabledStrategies)),
              startedAt: Value(job.startedAt),
              completedAt: Value(job.completedAt),
              targetsEnumerated: Value(job.targetsEnumerated),
              targetsAttempted: Value(job.targetsAttempted),
              responsesReceived: Value(job.responsesReceived),
              classifiedCount: Value(job.classifiedCount),
              unknownCount: Value(job.unknownCount),
              failureCount: Value(job.failureCount),
              diagnosticSummary: Value(job.diagnosticSummary),
            ),
          );
      return Result.success(id);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create scan job: $e'));
    }
  }

  @override
  Future<Result<void>> updateScanJob(DiscoveryScanJob job) async {
    try {
      await (_db.update(
        _db.discoveryScans,
      )..where((t) => t.id.equals(job.id))).write(
        DiscoveryScansCompanion(
          status: Value(job.status.toValue()),
          rangesJson: Value(jsonEncode(job.targetRanges)),
          enabledStrategiesJson: Value(jsonEncode(job.enabledStrategies)),
          completedAt: Value(job.completedAt),
          targetsEnumerated: Value(job.targetsEnumerated),
          targetsAttempted: Value(job.targetsAttempted),
          responsesReceived: Value(job.responsesReceived),
          classifiedCount: Value(job.classifiedCount),
          unknownCount: Value(job.unknownCount),
          failureCount: Value(job.failureCount),
          diagnosticSummary: Value(job.diagnosticSummary),
        ),
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update scan job: $e'));
    }
  }

  @override
  Future<Result<DiscoveryScanJob>> getScanJob(int scanId) async {
    try {
      final row = await (_db.select(
        _db.discoveryScans,
      )..where((t) => t.id.equals(scanId))).getSingleOrNull();
      if (row == null) {
        return Result.failure(const NotFoundFailure('Scan job not found'));
      }
      return Result.success(_mapScanJob(row));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to fetch scan job: $e'));
    }
  }

  @override
  Future<Result<DiscoveryScanJob?>> getLatestScanJob() async {
    try {
      final row =
          await (_db.select(_db.discoveryScans)
                ..orderBy([
                  (t) =>
                      OrderingTerm(expression: t.id, mode: OrderingMode.desc),
                ])
                ..limit(1))
              .getSingleOrNull();
      return Result.success(row != null ? _mapScanJob(row) : null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch latest scan job: $e'),
      );
    }
  }

  @override
  Future<Result<List<DiscoveryScanJob>>> getAllScanJobs() async {
    try {
      final rows =
          await (_db.select(_db.discoveryScans)..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ]))
              .get();
      return Result.success(rows.map(_mapScanJob).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to list scan jobs: $e'));
    }
  }

  @override
  Future<Result<int>> saveDiscoveredDevice(
    DiscoveredDeviceEntity device,
  ) async {
    try {
      // Check if IP already recorded for this scan or existing records
      final existing =
          await (_db.select(_db.discoveredDevices)
                ..where((t) => t.ip.equals(device.ip))
                ..orderBy([
                  (t) =>
                      OrderingTerm(expression: t.id, mode: OrderingMode.desc),
                ])
                ..limit(1))
              .getSingleOrNull();

      final companion = DiscoveredDevicesCompanion(
        scanId: Value(device.scanId),
        ip: Value(device.ip),
        mac: Value(device.mac ?? existing?.mac),
        hostname: Value(device.hostname ?? existing?.hostname),
        vendor: Value(device.vendor ?? existing?.vendor),
        observedServicesJson: Value(jsonEncode(device.observedServices)),
        predictedCategory: Value(device.predictedCategory.toValue()),
        confidence: Value(device.confidence.toValue()),
        evidenceJson: Value(
          jsonEncode(device.evidence.map((e) => e.toJson()).toList()),
        ),
        classificationMethod: Value(device.classificationMethod),
        firstSeen: Value(existing?.firstSeen ?? device.firstSeen),
        lastSeen: Value(device.lastSeen),
        lastSuccessfulProbe: Value(
          device.lastSuccessfulProbe ?? existing?.lastSuccessfulProbe,
        ),
        lastProbeFailureReason: Value(device.lastProbeFailureReason),
        reviewState: Value(device.reviewState.toValue()),
        adminConfirmedCategory: Value(device.adminConfirmedCategory?.toValue()),
        adminReviewerId: Value(device.adminReviewerId),
        adminReviewTimestamp: Value(device.adminReviewTimestamp),
        associatedDeviceId: Value(
          device.associatedDeviceId ?? existing?.associatedDeviceId,
        ),
      );

      if (existing != null) {
        await (_db.update(
          _db.discoveredDevices,
        )..where((t) => t.id.equals(existing.id))).write(companion);
        return Result.success(existing.id);
      } else {
        final id = await _db.into(_db.discoveredDevices).insert(companion);
        return Result.success(id);
      }
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to save discovered device: $e'),
      );
    }
  }

  @override
  Future<Result<List<DiscoveredDeviceEntity>>> getDiscoveredDevices({
    int? scanId,
  }) async {
    try {
      var query = _db.select(_db.discoveredDevices);
      if (scanId != null) {
        query = query..where((t) => t.scanId.equals(scanId));
      }
      final rows =
          await (query..orderBy([
                (t) => OrderingTerm(expression: t.ip, mode: OrderingMode.asc),
              ]))
              .get();
      return Result.success(rows.map(_mapDevice).toList());
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch discovered devices: $e'),
      );
    }
  }

  @override
  Future<Result<DiscoveredDeviceEntity?>> getDiscoveredDeviceByIp(
    String ip,
  ) async {
    try {
      final row =
          await (_db.select(_db.discoveredDevices)
                ..where((t) => t.ip.equals(ip))
                ..orderBy([
                  (t) =>
                      OrderingTerm(expression: t.id, mode: OrderingMode.desc),
                ])
                ..limit(1))
              .getSingleOrNull();
      return Result.success(row != null ? _mapDevice(row) : null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch device by IP: $e'),
      );
    }
  }

  @override
  Future<Result<void>> updateDeviceReview({
    required int deviceId,
    required ReviewState state,
    DeviceCategory? confirmedCategory,
    int? reviewerId,
  }) async {
    try {
      await (_db.update(
        _db.discoveredDevices,
      )..where((t) => t.id.equals(deviceId))).write(
        DiscoveredDevicesCompanion(
          reviewState: Value(state.toValue()),
          adminConfirmedCategory: Value(confirmedCategory?.toValue()),
          adminReviewerId: Value(reviewerId),
          adminReviewTimestamp: Value(DateTime.now()),
        ),
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to update device review state: $e'),
      );
    }
  }

  @override
  Future<Result<void>> saveEvidence(
    int deviceId,
    DiscoveryEvidenceItem item,
  ) async {
    try {
      await _db
          .into(_db.discoveryEvidences)
          .insert(
            DiscoveryEvidencesCompanion(
              discoveredDeviceId: Value(deviceId),
              strategyName: Value(item.strategyName),
              probeTarget: Value(item.probeTarget),
              isSuccess: Value(item.isSuccess),
              details: Value(item.details),
              timestamp: Value(item.timestamp),
            ),
          );
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to save evidence: $e'));
    }
  }

  @override
  Future<Result<List<DiscoveryEvidenceItem>>> getEvidenceForDevice(
    int deviceId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.discoveryEvidences)
                ..where((t) => t.discoveredDeviceId.equals(deviceId))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.timestamp,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();

      final list = rows
          .map(
            (r) => DiscoveryEvidenceItem(
              strategyName: r.strategyName,
              probeTarget: r.probeTarget,
              isSuccess: r.isSuccess,
              details: r.details,
              timestamp: r.timestamp,
            ),
          )
          .toList();

      return Result.success(list);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch evidence for device: $e'),
      );
    }
  }

  @override
  Stream<DiscoveryScanJob?> watchLatestScanJob() {
    return (_db.select(_db.discoveryScans)
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapScanJob(row) : null);
  }

  @override
  Stream<List<DiscoveredDeviceEntity>> watchDiscoveredDevices({int? scanId}) {
    var query = _db.select(_db.discoveredDevices);
    if (scanId != null) {
      query = query..where((t) => t.scanId.equals(scanId));
    }
    return (query..orderBy([
          (t) => OrderingTerm(expression: t.ip, mode: OrderingMode.asc),
        ]))
        .watch()
        .map((rows) => rows.map(_mapDevice).toList());
  }

  DiscoveryScanJob _mapScanJob(DiscoveryScanData r) {
    List<String> ranges = [];
    List<String> strategies = [];
    try {
      ranges = (jsonDecode(r.rangesJson) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {}
    try {
      strategies = (jsonDecode(r.enabledStrategiesJson) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {}

    return DiscoveryScanJob(
      id: r.id,
      status: ScanJobStatus.fromString(r.status),
      targetRanges: ranges,
      enabledStrategies: strategies,
      startedAt: r.startedAt,
      completedAt: r.completedAt,
      targetsEnumerated: r.targetsEnumerated,
      targetsAttempted: r.targetsAttempted,
      responsesReceived: r.responsesReceived,
      classifiedCount: r.classifiedCount,
      unknownCount: r.unknownCount,
      failureCount: r.failureCount,
      diagnosticSummary: r.diagnosticSummary,
    );
  }

  DiscoveredDeviceEntity _mapDevice(DiscoveredDeviceData r) {
    List<String> services = [];
    List<DiscoveryEvidenceItem> evidence = [];
    try {
      if (r.observedServicesJson != null) {
        services = (jsonDecode(r.observedServicesJson!) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      }
    } catch (_) {}
    try {
      if (r.evidenceJson != null) {
        evidence = (jsonDecode(r.evidenceJson!) as List<dynamic>)
            .map(
              (e) => DiscoveryEvidenceItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}

    return DiscoveredDeviceEntity(
      id: r.id,
      scanId: r.scanId,
      ip: r.ip,
      mac: r.mac,
      hostname: r.hostname,
      vendor: r.vendor,
      observedServices: services,
      predictedCategory: DeviceCategory.fromString(r.predictedCategory),
      confidence: ClassificationConfidence.fromString(r.confidence),
      evidence: evidence,
      classificationMethod: r.classificationMethod,
      firstSeen: r.firstSeen,
      lastSeen: r.lastSeen,
      lastSuccessfulProbe: r.lastSuccessfulProbe,
      lastProbeFailureReason: r.lastProbeFailureReason,
      reviewState: ReviewState.fromString(r.reviewState),
      adminConfirmedCategory: r.adminConfirmedCategory != null
          ? DeviceCategory.fromString(r.adminConfirmedCategory!)
          : null,
      adminReviewerId: r.adminReviewerId,
      adminReviewTimestamp: r.adminReviewTimestamp,
      associatedDeviceId: r.associatedDeviceId,
    );
  }
}
