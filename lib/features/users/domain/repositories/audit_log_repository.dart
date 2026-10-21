import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/audit_log_entity.dart';

abstract class AuditLogRepository {
  Future<Result<List<AuditLogEntity>>> getAuditLogs({int limit = 100});
  Future<Result<void>> recordLog({
    int? userId,
    required String username,
    required String action,
    String? details,
  });
}
