import '../../../../core/utils/result.dart';
import '../entities/incident_entity.dart';

abstract class IncidentRepository {
  Future<Result<IncidentEntity>> createIncident(IncidentEntity incident);
  Future<Result<List<IncidentEntity>>> getActiveIncidents();
  Future<Result<IncidentEntity?>> getActiveIncidentForDevice(int deviceId);
  Future<Result<IncidentEntity?>> getIncidentById(int id);
  Stream<List<IncidentEntity>> watchActiveIncidents();
  Future<Result<void>> resolveIncident(int id, DateTime resolvedAt);
  Future<Result<void>> acknowledgeIncident({
    required int id,
    required String username,
    String? note,
  });
  Future<Result<void>> addNote({required int id, required String note});
  Future<Result<List<IncidentEntity>>> getIncidentHistory({
    DateTime? from,
    DateTime? to,
    String? type,
    String? severity,
    int? deviceId,
    String? location,
  });
}
