import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/config/app_run_mode.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../monitoring/data/datasources/monitoring_service_client.dart';
import '../../domain/entities/factory_entity.dart';
import '../../domain/repositories/factory_repository.dart';

@LazySingleton(as: FactoryRepository)
class FactoryRepositoryImpl implements FactoryRepository {
  final AppDatabase _db;
  final MonitoringServiceClient? _serviceClient;
  StreamSubscription? _serviceEventSub;

  final StreamController<List<FactoryEntity>> _factoriesController =
      StreamController<List<FactoryEntity>>.broadcast();

  FactoryRepositoryImpl(this._db, [this._serviceClient]) {
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
        if (event['event'] == 'factory_created' ||
            event['event'] == 'factory_updated' ||
            event['event'] == 'factory_deleted') {
          _notifyChanged();
        }
      });
    }
  }

  void _notifyChanged() async {
    final res = await getFactories(includeInactive: true);
    if (res.isSuccess &&
        !_factoriesController.isClosed &&
        res.dataOrNull != null) {
      _factoriesController.add(res.dataOrNull!);
    }
  }

  FactoryEntity _mapRowToEntity(FactoryData row) {
    return FactoryEntity(
      id: row.id,
      code: row.code,
      name: row.name,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<Result<List<FactoryEntity>>> getFactories({
    bool includeInactive = false,
  }) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null) {
        return Result.failure(
          const NetworkFailure('Monitoring service client is not configured'),
        );
      }
      try {
        final res = await client.getFactories(includeInactive: includeInactive);
        if (res.isSuccess && res.data != null) {
          final list = res.data!.map(FactoryEntity.fromJson).toList();
          return Result.success(list);
        }
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to fetch factories'),
        );
      } catch (e) {
        return Result.failure(NetworkFailure('Failed to fetch factories: $e'));
      }
    }

    try {
      final query = _db.select(_db.factories);
      if (!includeInactive) {
        query.where((f) => f.isActive.equals(true));
      }
      query.orderBy([(f) => OrderingTerm.asc(f.code)]);
      final rows = await query.get();
      return Result.success(rows.map(_mapRowToEntity).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to query factories: $e'));
    }
  }

  @override
  Future<Result<FactoryEntity?>> getFactoryById(String id) async {
    if (AppConfig.isProductionClient) {
      final res = await getFactories(includeInactive: true);
      if (res.isSuccess && res.dataOrNull != null) {
        final match = res.dataOrNull!.where((f) => f.id == id).firstOrNull;
        return Result.success(match);
      }
      return Result.failure(
        res.failureOrNull ?? const NetworkFailure('Failed to fetch factory'),
      );
    }

    try {
      final row = await (_db.select(
        _db.factories,
      )..where((f) => f.id.equals(id))).getSingleOrNull();
      return Result.success(row != null ? _mapRowToEntity(row) : null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get factory by id: $e'));
    }
  }

  @override
  Future<Result<FactoryEntity?>> getFactoryByCode(String code) async {
    final upper = code.trim().toUpperCase();
    if (AppConfig.isProductionClient) {
      final res = await getFactories(includeInactive: true);
      if (res.isSuccess && res.dataOrNull != null) {
        final match = res.dataOrNull!
            .where((f) => f.code.toUpperCase() == upper)
            .firstOrNull;
        return Result.success(match);
      }
      return Result.failure(
        res.failureOrNull ?? const NetworkFailure('Failed to fetch factory'),
      );
    }

    try {
      final row = await (_db.select(
        _db.factories,
      )..where((f) => f.code.equals(upper))).getSingleOrNull();
      return Result.success(row != null ? _mapRowToEntity(row) : null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to get factory by code: $e'),
      );
    }
  }

  @override
  Future<Result<FactoryEntity>> createFactory(FactoryEntity factory) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null) {
        return Result.failure(
          const NetworkFailure('Monitoring service client is not configured'),
        );
      }
      try {
        final res = await client.createFactory(factory.toJson());
        if (res.isSuccess && res.data != null) {
          final created = FactoryEntity.fromJson(res.data!);
          _notifyChanged();
          return Result.success(created);
        }
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to create factory'),
        );
      } catch (e) {
        return Result.failure(NetworkFailure('Failed to create factory: $e'));
      }
    }

    try {
      final normalizedCode = factory.code.trim().toUpperCase();
      final normalizedId = factory.id.trim().toLowerCase();
      final companion = FactoriesCompanion(
        id: Value(normalizedId),
        code: Value(normalizedCode),
        name: Value(factory.name.trim()),
        isActive: Value(factory.isActive),
        createdAt: Value(factory.createdAt),
        updatedAt: Value(factory.updatedAt ?? DateTime.now()),
      );
      await _db.into(_db.factories).insert(companion);
      _notifyChanged();
      return Result.success(
        factory.copyWith(id: normalizedId, code: normalizedCode),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to insert factory: $e'));
    }
  }

  @override
  Future<Result<FactoryEntity>> updateFactory(FactoryEntity factory) async {
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null) {
        return Result.failure(
          const NetworkFailure('Monitoring service client is not configured'),
        );
      }
      try {
        final res = await client.updateFactory(factory.id, factory.toJson());
        if (res.isSuccess && res.data != null) {
          final updated = FactoryEntity.fromJson(res.data!);
          _notifyChanged();
          return Result.success(updated);
        }
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to update factory'),
        );
      } catch (e) {
        return Result.failure(NetworkFailure('Failed to update factory: $e'));
      }
    }

    try {
      final companion = FactoriesCompanion(
        name: Value(factory.name.trim()),
        isActive: Value(factory.isActive),
        updatedAt: Value(DateTime.now()),
      );
      await (_db.update(
        _db.factories,
      )..where((f) => f.id.equals(factory.id))).write(companion);
      _notifyChanged();
      return Result.success(factory);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update factory: $e'));
    }
  }

  @override
  Future<Result<void>> deleteFactory(String id) async {
    // Soft-deactivate to prevent breaking historical records
    if (AppConfig.isProductionClient) {
      final client = _effectiveClient;
      if (client == null) {
        return Result.failure(
          const NetworkFailure('Monitoring service client is not configured'),
        );
      }
      try {
        final res = await client.deleteFactory(id);
        if (res.isSuccess) {
          _notifyChanged();
          return Result.success(null);
        }
        return Result.failure(
          NetworkFailure(res.errorMessage ?? 'Failed to delete factory'),
        );
      } catch (e) {
        return Result.failure(NetworkFailure('Failed to delete factory: $e'));
      }
    }

    try {
      await (_db.update(_db.factories)..where((f) => f.id.equals(id))).write(
        FactoriesCompanion(
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
      _notifyChanged();
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to deactivate factory: $e'),
      );
    }
  }

  @override
  Stream<List<FactoryEntity>> watchFactories() {
    if (AppConfig.isProductionClient) {
      getFactories(includeInactive: true).then((res) {
        if (res.isSuccess &&
            !_factoriesController.isClosed &&
            res.dataOrNull != null) {
          _factoriesController.add(res.dataOrNull!);
        }
      });
      return _factoriesController.stream;
    }

    return _db
        .select(_db.factories)
        .watch()
        .map((rows) => rows.map(_mapRowToEntity).toList());
  }
}
