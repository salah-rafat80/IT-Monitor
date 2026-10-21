import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/repositories/incident_repository.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../users/domain/repositories/audit_log_repository.dart';

@LazySingleton(as: IncidentRepository)
class IncidentRepositoryImpl implements IncidentRepository {
  final AppDatabase _db;
  final AuditLogRepository _auditLogRepo;

  final StreamController<List<IncidentEntity>> _activeIncidentsController =
      StreamController<List<IncidentEntity>>.broadcast();

  IncidentRepositoryImpl(this._db, this._auditLogRepo);

  @override
  Future<Result<IncidentEntity>> createIncident(IncidentEntity incident) async {
    try {
      final insertedId = await _db
          .into(_db.incidents)
          .insert(
            IncidentsCompanion.insert(
              deviceId: incident.deviceId,
              deviceName: incident.deviceName,
              ownerName: incident.ownerName,
              department: incident.department,
              location: Value(incident.location),
              deviceIp: incident.deviceIp,
              incidentType: incident.incidentType.toValue(),
              severity: Value(incident.severity.toValue()),
              status: Value(incident.status.toValue()),
              startedAt: Value(incident.startedAt),
              notes: Value(incident.notes),
              correlationMessage: Value(incident.correlationMessage),
            ),
          );

      final created = incident.copyWith(id: insertedId);

      await _auditLogRepo.recordLog(
        action: 'INCIDENT_CREATED',
        username: 'System',
        details:
            'Created incident #${created.id} (${created.incidentType.name}) for ${created.deviceName} (${created.ownerName})',
      );

      _notifyActiveIncidentsChanged();
      return Result.success(created);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to create incident: $e'));
    }
  }

  @override
  Future<Result<List<IncidentEntity>>> getActiveIncidents() async {
    try {
      final query = _db.select(_db.incidents)
        ..where((t) => t.status.isIn(['active', 'acknowledged']))
        ..orderBy([
          (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
        ]);
      final rows = await query.get();
      final entities = rows.map(_mapToEntity).toList();
      return Result.success(entities);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch active incidents: $e'),
      );
    }
  }

  @override
  Future<Result<IncidentEntity?>> getActiveIncidentForDevice(
    int deviceId,
  ) async {
    try {
      final query = _db.select(_db.incidents)
        ..where(
          (t) =>
              t.deviceId.equals(deviceId) &
              t.status.isIn(['active', 'acknowledged']),
        );
      final rows = await query.get();
      if (rows.isEmpty) return Result.success(null);
      return Result.success(_mapToEntity(rows.first));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to fetch device active incident: $e'),
      );
    }
  }

  @override
  Future<Result<IncidentEntity?>> getIncidentById(int id) async {
    try {
      final query = _db.select(_db.incidents)..where((t) => t.id.equals(id));
      final rows = await query.get();
      if (rows.isEmpty) return Result.success(null);
      return Result.success(_mapToEntity(rows.first));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to get incident by id: $e'),
      );
    }
  }

  @override
  Stream<List<IncidentEntity>> watchActiveIncidents() {
    return _activeIncidentsController.stream;
  }

  @override
  Future<Result<void>> resolveIncident(int id, DateTime resolvedAt) async {
    try {
      final currentRes = await getIncidentById(id);
      final current = currentRes.dataOrNull;
      if (current == null) return Result.success(null);

      await (_db.update(_db.incidents)..where((t) => t.id.equals(id))).write(
        IncidentsCompanion(
          status: const Value('resolved'),
          resolvedAt: Value(resolvedAt),
        ),
      );

      await _auditLogRepo.recordLog(
        action: 'INCIDENT_RESOLVED',
        username: 'System',
        details:
            'Resolved incident #$id for device ${current.deviceName} (${current.ownerName})',
      );

      _notifyActiveIncidentsChanged();
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to resolve incident: $e'));
    }
  }

  @override
  Future<Result<void>> acknowledgeIncident({
    required int id,
    required String username,
    String? note,
  }) async {
    try {
      final currentRes = await getIncidentById(id);
      final current = currentRes.dataOrNull;
      if (current == null) {
        return Result.failure(const DatabaseFailure('Incident not found'));
      }

      final now = DateTime.now();
      String? updatedNotes = current.notes;
      if (note != null && note.trim().isNotEmpty) {
        final newEntry =
            '[${now.toIso8601String()}] Ack Note by $username: ${note.trim()}';
        updatedNotes = (updatedNotes != null && updatedNotes.isNotEmpty)
            ? '$updatedNotes\n$newEntry'
            : newEntry;
      }

      await (_db.update(_db.incidents)..where((t) => t.id.equals(id))).write(
        IncidentsCompanion(
          status: const Value('acknowledged'),
          acknowledgedAt: Value(now),
          acknowledgedBy: Value(username),
          notes: Value(updatedNotes),
        ),
      );

      await _auditLogRepo.recordLog(
        action: 'INCIDENT_ACKNOWLEDGED',
        username: username,
        details:
            'Acknowledged incident #$id for ${current.deviceName} by $username',
      );

      _notifyActiveIncidentsChanged();
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to acknowledge incident: $e'),
      );
    }
  }

  @override
  Future<Result<void>> addNote({required int id, required String note}) async {
    try {
      final currentRes = await getIncidentById(id);
      final current = currentRes.dataOrNull;
      if (current == null) {
        return Result.failure(const DatabaseFailure('Incident not found'));
      }

      final now = DateTime.now();
      final newEntry = '[${now.toIso8601String()}] Note: ${note.trim()}';
      final updatedNotes = (current.notes != null && current.notes!.isNotEmpty)
          ? '${current.notes}\n$newEntry'
          : newEntry;

      await (_db.update(_db.incidents)..where((t) => t.id.equals(id))).write(
        IncidentsCompanion(notes: Value(updatedNotes)),
      );

      await _auditLogRepo.recordLog(
        action: 'INCIDENT_NOTE_ADDED',
        username: 'User',
        details: 'Added note to incident #$id',
      );

      _notifyActiveIncidentsChanged();
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to add incident note: $e'));
    }
  }

  @override
  Future<Result<List<IncidentEntity>>> getIncidentHistory({
    DateTime? from,
    DateTime? to,
    String? type,
    String? severity,
    int? deviceId,
    String? location,
  }) async {
    try {
      final query = _db.select(_db.incidents)
        ..orderBy([
          (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
        ]);

      if (type != null) {
        query.where((t) => t.incidentType.equals(type));
      }
      if (severity != null) {
        query.where((t) => t.severity.equals(severity));
      }
      if (deviceId != null) {
        query.where((t) => t.deviceId.equals(deviceId));
      }
      if (location != null) {
        query.where((t) => t.location.equals(location));
      }

      final rows = await query.get();
      final entities = rows.map(_mapToEntity).toList();
      return Result.success(entities);
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Failed to query incident history: $e'),
      );
    }
  }

  Future<void> _notifyActiveIncidentsChanged() async {
    final activeRes = await getActiveIncidents();
    if (activeRes.isSuccess && !_activeIncidentsController.isClosed) {
      _activeIncidentsController.add(activeRes.dataOrNull!);
    }
  }

  IncidentEntity _mapToEntity(IncidentData r) {
    return IncidentEntity(
      id: r.id,
      deviceId: r.deviceId,
      deviceName: r.deviceName,
      ownerName: r.ownerName,
      department: r.department,
      location: r.location,
      deviceIp: r.deviceIp,
      incidentType: IncidentTypeEnum.fromString(r.incidentType),
      severity: IncidentSeverityEnum.fromString(r.severity),
      status: IncidentStatusEnum.fromString(r.status),
      startedAt: r.startedAt,
      resolvedAt: r.resolvedAt,
      acknowledgedAt: r.acknowledgedAt,
      acknowledgedBy: r.acknowledgedBy,
      notes: r.notes,
      correlationMessage: r.correlationMessage,
    );
  }
}
