import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/audit_log_entity.dart';
import '../../domain/repositories/audit_log_repository.dart';

@LazySingleton(as: AuditLogRepository)
class AuditLogRepositoryImpl implements AuditLogRepository {
  final AppDatabase _db;

  AuditLogRepositoryImpl(this._db);

  @override
  Future<Result<List<AuditLogEntity>>> getAuditLogs({int limit = 100}) async {
    try {
      final query = _db.select(_db.auditLogs)
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(limit);

      final rows = await query.get();
      final entities = rows
          .map(
            (row) => AuditLogEntity(
              id: row.id,
              userId: row.userId,
              username: row.username,
              action: row.action,
              details: row.details,
              timestamp: row.timestamp,
            ),
          )
          .toList();

      return Result.success(entities);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to fetch audit logs: $e'));
    }
  }

  @override
  Future<Result<void>> recordLog({
    int? userId,
    required String username,
    required String action,
    String? details,
  }) async {
    try {
      await _db
          .into(_db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              userId: Value(userId),
              username: username,
              action: action,
              details: Value(details),
              timestamp: Value(DateTime.now()),
            ),
          );
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to record audit log: $e'));
    }
  }
}
