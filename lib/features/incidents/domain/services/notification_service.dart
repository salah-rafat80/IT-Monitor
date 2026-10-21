import '../entities/incident_entity.dart';

abstract class NotificationService {
  Future<void> notifyIncidentCreated(IncidentEntity incident);
  Future<void> notifyIncidentResolved(IncidentEntity incident);
}
