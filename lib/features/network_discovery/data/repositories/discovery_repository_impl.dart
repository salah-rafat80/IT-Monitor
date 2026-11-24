import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
import '../../domain/entities/classification_confidence.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/discovery_config_entity.dart';
import '../../domain/entities/discovery_evidence_item.dart';
import '../../domain/entities/discovery_scan_job.dart';
import '../../domain/entities/network_range.dart';
import '../../domain/entities/review_state.dart';
import '../../domain/repositories/discovery_repository.dart';

@LazySingleton(as: DiscoveryRepository)
class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final AppDatabase _db;
  final MonitoringServiceClient? _serviceClient;
  StreamSubscription? _serviceEventSub;

  final StreamController<List<DiscoveredDeviceEntity>>
  _discoveredDevicesController =
      StreamController<List<DiscoveredDeviceEntity>>.broadcast();
  final StreamController<DiscoveryScanJob?> _scanJobController =
      StreamController<DiscoveryScanJob?>.broadcast();
  final StreamController<List<NetworkRange>> _rangesController =
      StreamController<List<NetworkRange>>.broadcast();

  DiscoveryRepositoryImpl(this._db, [this._serviceClient]) {
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
        final ev = event['event']?.toString();
        if (ev == 'discovery_device_found' ||
            ev == 'discovery_scan_completed' ||
            ev == 'discovery_scan_cancelled' ||
            ev == 'discovery_scan_failed') {
          // Refresh discovered devices scoped to the latest scan job
          getLatestScanJob().then((latestRes) {
            final latestJob = latestRes.dataOrNull;
            if (latestRes.isSuccess && !_scanJobController.isClosed) {
              _scanJobController.add(latestJob);
            }
            if (latestJob != null) {
              getDiscoveredDevices(
                scanId: latestJob.id,
                factoryId: latestJob.factoryId,
              ).then((res) {
                if (res.isSuccess && !_discoveredDevicesController.isClosed) {
                  _discoveredDevicesController.add(res.dataOrNull ?? []);
                }
              });
            } else {
              if (!_discoveredDevicesController.isClosed) {
                _discoveredDevicesController.add([]);
              }
            }
          });
        } else if (ev == 'discovery_config_updated') {
          getRanges().then((res) {
            if (res.isSuccess && !_rangesController.isClosed) {
              _rangesController.add(res.dataOrNull ?? []);
            }
          });
        }
      });
    }
  }

  @override
  Future<Result<DiscoveryConfigEntity>> getConfig() async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.getDiscoveryConfig();
      if (res.isSuccess && res.data != null) {
        final config = DiscoveryConfigEntity.fromJson(res.data!);
        if (!_rangesController.isClosed) {
          _rangesController.add(config.networkRanges);
        }
        return Result.success(config);
      } else {
        return Result.failure(
          NetworkFailure(
            'Authoritative monitoring service is unreachable (${res.errorMessage}).',
          ),
        );
      }
    }

    try {
      final row = await (_db.select(
        _db.discoveryConfigurations,
      )..limit(1)).getSingleOrNull();
      if (row == null) {
        final initial = DiscoveryConfigEntity.initial();
        await saveConfig(initial);
        return Result.success(initial);
      }

      final rawRanges = jsonDecode(row.authorizedRangesJson) as List<dynamic>;
      final List<NetworkRange> networkRanges = [];
      for (final item in rawRanges) {
        if (item is Map<String, dynamic>) {
          networkRanges.add(NetworkRange.fromJson(item));
        } else if (item is String) {
          final parsed = NetworkRange.tryParse(item);
          if (parsed != null) {
            networkRanges.add(parsed);
          }
        }
      }
      final strategies =
          (jsonDecode(row.enabledStrategiesJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();

      final config = DiscoveryConfigEntity(
        networkRanges: networkRanges,
        enabledStrategies: strategies,
        maxConcurrency: row.maxConcurrency,
        timeoutSeconds: row.timeoutSeconds,
        updatedAt: row.updatedAt,
      );
      if (!_rangesController.isClosed) {
        _rangesController.add(networkRanges);
      }
      return Result.success(config);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to load discovery configuration: $e'),
      );
    }
  }

  @override
  Future<Result<void>> saveConfig(DiscoveryConfigEntity config) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.saveDiscoveryConfig(config.toJson());
      if (res.isSuccess) {
        if (!_rangesController.isClosed) {
          _rangesController.add(config.networkRanges);
        }
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to save discovery configuration via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      final existing = await (_db.select(
        _db.discoveryConfigurations,
      )..limit(1)).getSingleOrNull();
      final companion = DiscoveryConfigurationsCompanion(
        authorizedRangesJson: Value(
          jsonEncode(config.networkRanges.map((r) => r.toJson()).toList()),
        ),
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
      if (!_rangesController.isClosed) {
        _rangesController.add(config.networkRanges);
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to save discovery configuration: $e'),
      );
    }
  }

  @override
  Future<Result<List<NetworkRange>>> getRanges({String? factoryId}) async {
    final configRes = await getConfig();
    if (configRes.isSuccess) {
      final all = configRes.dataOrNull?.networkRanges ?? [];
      if (factoryId != null && factoryId.isNotEmpty) {
        return Result.success(
          all.where((r) => r.factoryId == factoryId).toList(),
        );
      }
      return Result.success(all);
    }
    return Result.failure(configRes.failureOrNull!);
  }

  @override
  Future<Result<void>> addRange(NetworkRange range) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.addNetworkRange(range.toJson());
      if (res.isSuccess) {
        await getConfig();
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to add network range via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.discoveryConfigurations,
        )..limit(1)).getSingleOrNull();

        final List<NetworkRange> currentRanges = [];
        if (existing != null) {
          final raw =
              jsonDecode(existing.authorizedRangesJson) as List<dynamic>;
          for (final item in raw) {
            if (item is Map<String, dynamic>) {
              currentRanges.add(NetworkRange.fromJson(item));
            } else if (item is String) {
              final p = NetworkRange.tryParse(item);
              if (p != null) currentRanges.add(p);
            }
          }
        }

        if (currentRanges.any(
          (r) =>
              (r.cidr == range.cidr && r.factoryId == range.factoryId) ||
              r.id == range.id,
        )) {
          return Result.failure(
            ValidationFailure(
              'Network range ${range.cidr} already exists for factory ${range.factoryId}.',
            ),
          );
        }

        final updatedRanges = [...currentRanges, range];
        final companion = DiscoveryConfigurationsCompanion(
          authorizedRangesJson: Value(
            jsonEncode(updatedRanges.map((r) => r.toJson()).toList()),
          ),
          updatedAt: Value(DateTime.now()),
        );

        if (existing == null) {
          await _db.into(_db.discoveryConfigurations).insert(companion);
        } else {
          await (_db.update(
            _db.discoveryConfigurations,
          )..where((t) => t.id.equals(existing.id))).write(companion);
        }

        if (!_rangesController.isClosed) {
          _rangesController.add(updatedRanges);
        }
        return Result.success(null);
      });
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to add network range atomically: $e'),
      );
    }
  }

  @override
  Future<Result<void>> updateRange(NetworkRange range) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.updateNetworkRange(range.toJson());
      if (res.isSuccess) {
        await getConfig();
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to update network range via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.discoveryConfigurations,
        )..limit(1)).getSingleOrNull();

        if (existing == null) {
          return Result.failure(
            ValidationFailure('Network range ${range.cidr} was not found.'),
          );
        }

        final List<NetworkRange> currentRanges = [];
        final raw = jsonDecode(existing.authorizedRangesJson) as List<dynamic>;
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            currentRanges.add(NetworkRange.fromJson(item));
          } else if (item is String) {
            final p = NetworkRange.tryParse(item);
            if (p != null) currentRanges.add(p);
          }
        }

        final index = currentRanges.indexWhere(
          (r) =>
              r.id == range.id ||
              (r.cidr == range.cidr && r.factoryId == range.factoryId),
        );
        if (index == -1) {
          return Result.failure(
            ValidationFailure('Network range ${range.cidr} was not found.'),
          );
        }

        final updatedRanges = List<NetworkRange>.from(currentRanges);
        updatedRanges[index] = range.copyWith(updatedAt: DateTime.now());

        await (_db.update(
          _db.discoveryConfigurations,
        )..where((t) => t.id.equals(existing.id))).write(
          DiscoveryConfigurationsCompanion(
            authorizedRangesJson: Value(
              jsonEncode(updatedRanges.map((r) => r.toJson()).toList()),
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );

        if (!_rangesController.isClosed) {
          _rangesController.add(updatedRanges);
        }
        return Result.success(null);
      });
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to update network range atomically: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteRange(String rangeId) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.deleteNetworkRange(rangeId);
      if (res.isSuccess) {
        await getConfig();
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Failed to delete network range via service API: ${res.errorMessage}',
          ),
        );
      }
    }

    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.discoveryConfigurations,
        )..limit(1)).getSingleOrNull();

        if (existing == null) {
          return Result.failure(
            ValidationFailure('Network range $rangeId was not found.'),
          );
        }

        final List<NetworkRange> currentRanges = [];
        final raw = jsonDecode(existing.authorizedRangesJson) as List<dynamic>;
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            currentRanges.add(NetworkRange.fromJson(item));
          } else if (item is String) {
            final p = NetworkRange.tryParse(item);
            if (p != null) currentRanges.add(p);
          }
        }

        final updatedRanges = currentRanges
            .where((r) => r.id != rangeId && r.cidr != rangeId)
            .toList();

        if (updatedRanges.length == currentRanges.length) {
          return Result.failure(
            ValidationFailure('Network range $rangeId was not found.'),
          );
        }

        await (_db.update(
          _db.discoveryConfigurations,
        )..where((t) => t.id.equals(existing.id))).write(
          DiscoveryConfigurationsCompanion(
            authorizedRangesJson: Value(
              jsonEncode(updatedRanges.map((r) => r.toJson()).toList()),
            ),
            updatedAt: Value(DateTime.now()),
          ),
        );

        if (!_rangesController.isClosed) {
          _rangesController.add(updatedRanges);
        }
        return Result.success(null);
      });
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to delete network range atomically: $e'),
      );
    }
  }

  @override
  Stream<List<NetworkRange>> watchRanges({String? factoryId}) {
    getRanges(factoryId: factoryId).then((res) {
      if (res.isSuccess && !_rangesController.isClosed) {
        _rangesController.add(res.dataOrNull ?? []);
      }
    });
    return _rangesController.stream.map((ranges) {
      if (factoryId != null && factoryId.isNotEmpty) {
        return ranges.where((r) => r.factoryId == factoryId).toList();
      }
      return ranges;
    });
  }

  @override
  Future<Result<int>> createScanJob(DiscoveryScanJob job) async {
    if (AppConfig.isProductionClient) {
      return Result.failure(
        NetworkFailure(
          'Scan job creation is restricted to the authoritative service daemon.',
        ),
      );
    }

    try {
      final id = await _db
          .into(_db.discoveryScans)
          .insert(
            DiscoveryScansCompanion(
              factoryId: Value(job.factoryId),
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
    if (AppConfig.isProductionClient) {
      return Result.failure(
        NetworkFailure(
          'Scan job updates are restricted to the authoritative service daemon.',
        ),
      );
    }

    try {
      await (_db.update(
        _db.discoveryScans,
      )..where((t) => t.id.equals(job.id))).write(
        DiscoveryScansCompanion(
          factoryId: Value(job.factoryId),
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
    if (AppConfig.isProductionClient) {
      final latest = await getLatestScanJob();
      if (latest.isFailure) {
        return Result.failure(latest.failureOrNull!);
      }
      if (latest.dataOrNull != null && latest.dataOrNull!.id == scanId) {
        return Result.success(latest.dataOrNull!);
      }
      return Result.failure(const NotFoundFailure('Scan job not found'));
    }

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
  Future<Result<DiscoveryScanJob?>> getLatestScanJob({
    String? factoryId,
  }) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.getDiscoveryStatus(factoryId: factoryId);
      if (res.isSuccess && res.data != null) {
        final latest = res.data!['latestScan'] as Map<String, dynamic>?;
        if (latest != null) {
          return Result.success(DiscoveryScanJob.fromJson(latest));
        }
        return Result.success(null);
      } else {
        return Result.failure(
          NetworkFailure(
            'Authoritative monitoring service is unreachable (${res.errorMessage}).',
          ),
        );
      }
    }

    try {
      var query = _db.select(_db.discoveryScans);
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((t) => t.factoryId.equals(factoryId));
      }
      final row =
          await (query
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
  Future<Result<List<DiscoveryScanJob>>> getAllScanJobs({
    String? factoryId,
  }) async {
    if (AppConfig.isProductionClient) {
      final latest = await getLatestScanJob(factoryId: factoryId);
      if (latest.isFailure) {
        return Result.failure(latest.failureOrNull!);
      }
      if (latest.dataOrNull != null) {
        return Result.success([latest.dataOrNull!]);
      }
      return Result.success([]);
    }

    try {
      var query = _db.select(_db.discoveryScans);
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((t) => t.factoryId.equals(factoryId));
      }
      final rows =
          await (query..orderBy([
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
    if (AppConfig.isProductionClient) {
      return Result.failure(
        NetworkFailure(
          'Saving discovered devices directly is restricted to the authoritative service daemon.',
        ),
      );
    }

    try {
      // Check if IP already recorded for this specific scan
      final existing =
          await (_db.select(_db.discoveredDevices)
                ..where(
                  (t) =>
                      t.factoryId.equals(device.factoryId) &
                      t.scanId.equals(device.scanId) &
                      t.ip.equals(device.ip),
                )
                ..limit(1))
              .getSingleOrNull();

      // Check earlier scans to preserve original firstSeen timestamp if device was previously seen
      final prior =
          await (_db.select(_db.discoveredDevices)
                ..where(
                  (t) =>
                      t.factoryId.equals(device.factoryId) &
                      t.ip.equals(device.ip),
                )
                ..orderBy([
                  (t) =>
                      OrderingTerm(expression: t.firstSeen, mode: OrderingMode.asc),
                ])
                ..limit(1))
              .getSingleOrNull();

      // Check most recent prior row for this (factoryId, ip) that has an admin review decision
      final priorReview =
          await (_db.select(_db.discoveredDevices)
                ..where(
                  (t) =>
                      t.factoryId.equals(device.factoryId) &
                      t.ip.equals(device.ip) &
                      t.reviewState.isNotValue('pending_review'),
                )
                ..orderBy([
                  (t) =>
                      OrderingTerm(expression: t.lastSeen, mode: OrderingMode.desc),
                ])
                ..limit(1))
              .getSingleOrNull();

      final existingReview =
          existing != null && existing.reviewState != 'pending_review'
              ? existing
              : null;
      final effectiveReview = existingReview ?? priorReview;

      final companion = DiscoveredDevicesCompanion(
        factoryId: Value(device.factoryId),
        scanId: Value(device.scanId),
        ip: Value(device.ip),
        mac: Value(device.mac ?? existing?.mac ?? prior?.mac),
        hostname: Value(device.hostname ?? existing?.hostname ?? prior?.hostname),
        vendor: Value(device.vendor ?? existing?.vendor ?? prior?.vendor),
        observedServicesJson: Value(jsonEncode(device.observedServices)),
        predictedCategory: Value(device.predictedCategory.toValue()),
        confidence: Value(device.confidence.toValue()),
        evidenceJson: Value(
          jsonEncode(device.evidence.map((e) => e.toJson()).toList()),
        ),
        classificationMethod: Value(device.classificationMethod),
        firstSeen: Value(existing?.firstSeen ?? prior?.firstSeen ?? device.firstSeen),
        lastSeen: Value(device.lastSeen),
        lastSuccessfulProbe: Value(
          device.lastSuccessfulProbe ?? existing?.lastSuccessfulProbe ?? prior?.lastSuccessfulProbe,
        ),
        lastProbeFailureReason: Value(device.lastProbeFailureReason),
        reviewState: Value(
          (device.reviewState != ReviewState.pendingReview
              ? device.reviewState.toValue()
              : effectiveReview?.reviewState) ??
              device.reviewState.toValue(),
        ),
        adminConfirmedCategory: Value(
          device.adminConfirmedCategory?.toValue() ??
              effectiveReview?.adminConfirmedCategory,
        ),
        adminReviewerId: Value(
          device.adminReviewerId ??
              effectiveReview?.adminReviewerId,
        ),
        adminReviewTimestamp: Value(
          device.adminReviewTimestamp ??
              effectiveReview?.adminReviewTimestamp,
        ),
        associatedDeviceId: Value(
          device.associatedDeviceId ??
              effectiveReview?.associatedDeviceId ??
              existing?.associatedDeviceId ??
              prior?.associatedDeviceId,
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
    String? factoryId,
  }) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      final res = await client.getDiscoveryDevices(scanId, factoryId);
      if (res.isSuccess && res.data != null) {
        final list = res.data!
            .map((item) => DiscoveredDeviceEntity.fromJson(item))
            .toList();
        return Result.success(list);
      } else {
        return Result.failure(
          NetworkFailure(
            'Authoritative monitoring service is unreachable (${res.errorMessage}).',
          ),
        );
      }
    }

    try {
      var query = _db.select(_db.discoveredDevices);
      if (scanId != null) {
        query = query..where((t) => t.scanId.equals(scanId));
      }
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((t) => t.factoryId.equals(factoryId));
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
    String ip, {
    String? factoryId,
  }) async {
    if (AppConfig.isProductionClient) {
      final allRes = await getDiscoveredDevices(factoryId: factoryId);
      if (allRes.isFailure) return Result.failure(allRes.failureOrNull!);
      final match = allRes.dataOrNull!
          .where((d) => d.ip.trim() == ip.trim())
          .firstOrNull;
      return Result.success(match);
    }

    try {
      var query = _db.select(_db.discoveredDevices)
        ..where((t) => t.ip.equals(ip));
      if (factoryId != null && factoryId.isNotEmpty) {
        query = query..where((t) => t.factoryId.equals(factoryId));
      }
      final row =
          await (query
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
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null || !client.isAuthenticated) {
        return Result.failure(
          NetworkFailure(
            'Production client is not authenticated with the authoritative IT Network Monitor Service.',
          ),
        );
      }
      if (state == ReviewState.approved) {
        final res = await client.approveDiscoveryDevice({
          'deviceId': deviceId,
          if (confirmedCategory != null)
            'category': confirmedCategory.toValue(),
        });
        if (res.isSuccess) {
          return Result.success(null);
        } else {
          return Result.failure(
            NetworkFailure(
              'Failed to approve device via service API: ${res.errorMessage}',
            ),
          );
        }
      } else if (state == ReviewState.rejected) {
        final res = await client.rejectDiscoveryDevice(deviceId);
        if (res.isSuccess) {
          return Result.success(null);
        } else {
          return Result.failure(
            NetworkFailure(
              'Failed to reject device via service API: ${res.errorMessage}',
            ),
          );
        }
      }
      return Result.success(null);
    }

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
    if (AppConfig.isProductionClient) {
      return Result.failure(
        NetworkFailure(
          'Saving evidence directly is restricted to the authoritative service daemon.',
        ),
      );
    }

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
    if (AppConfig.isProductionClient) {
      final allRes = await getDiscoveredDevices();
      if (allRes.isFailure) return Result.failure(allRes.failureOrNull!);
      final match = allRes.dataOrNull!
          .where((d) => d.id == deviceId)
          .firstOrNull;
      return Result.success(match?.evidence ?? []);
    }

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
  Stream<DiscoveryScanJob?> watchLatestScanJob({String? factoryId}) {
    if (AppConfig.isProductionClient) {
      return _scanJobController.stream;
    }
    var query = _db.select(_db.discoveryScans);
    if (factoryId != null && factoryId.isNotEmpty) {
      query = query..where((t) => t.factoryId.equals(factoryId));
    }
    return (query
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapScanJob(row) : null);
  }

  @override
  Stream<List<DiscoveredDeviceEntity>> watchDiscoveredDevices({
    int? scanId,
    String? factoryId,
  }) {
    if (AppConfig.isProductionClient) {
      return _discoveredDevicesController.stream.map((list) {
        var filtered = list;
        if (scanId != null) {
          filtered = filtered.where((d) => d.scanId == scanId).toList();
        }
        if (factoryId != null && factoryId.isNotEmpty) {
          filtered = filtered.where((d) => d.factoryId == factoryId).toList();
        }
        return filtered;
      });
    }
    var query = _db.select(_db.discoveredDevices);
    if (scanId != null) {
      query = query..where((t) => t.scanId.equals(scanId));
    }
    if (factoryId != null && factoryId.isNotEmpty) {
      query = query..where((t) => t.factoryId.equals(factoryId));
    }
    return (query..orderBy([
          (t) => OrderingTerm(expression: t.ip, mode: OrderingMode.asc),
        ]))
        .watch()
        .map((rows) => rows.map(_mapDevice).toList());
  }

  @override
  Future<Result<void>> deleteDiscoveredDevicesForOlderScans({
    required String factoryId,
    required int keepScanId,
  }) async {
    if (AppConfig.isProductionClient) {
      return Result.success(null);
    }
    try {
      final oldDevices = await (_db.select(_db.discoveredDevices)
            ..where((t) =>
                t.factoryId.equals(factoryId) &
                t.scanId.isNotValue(keepScanId)))
          .get();

      final oldDeviceIds = oldDevices.map((d) => d.id).toList();
      if (oldDeviceIds.isNotEmpty) {
        await (_db.delete(_db.discoveryEvidences)
              ..where((t) => t.discoveredDeviceId.isIn(oldDeviceIds)))
            .go();

        await (_db.delete(_db.discoveredDevices)
              ..where((t) => t.id.isIn(oldDeviceIds)))
            .go();
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to cleanup older scan devices: $e'),
      );
    }
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
      factoryId: r.factoryId,
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
      factoryId: r.factoryId,
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
