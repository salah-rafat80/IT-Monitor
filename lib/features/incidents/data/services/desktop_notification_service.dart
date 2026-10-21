import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/incident_entity.dart';
import '../../domain/services/notification_service.dart';

@LazySingleton(as: NotificationService)
class DesktopNotificationService implements NotificationService {
  @override
  Future<void> notifyIncidentCreated(IncidentEntity incident) async {
    debugPrint(
      '[DesktopNotification] INCIDENT CREATED: ${incident.deviceName} (${incident.ownerName} - ${incident.department}) - IP: ${incident.deviceIp} - Type: ${incident.incidentType.name}',
    );
  }

  @override
  Future<void> notifyIncidentResolved(IncidentEntity incident) async {
    debugPrint(
      '[DesktopNotification] INCIDENT RESOLVED: ${incident.deviceName} (${incident.ownerName}) - IP: ${incident.deviceIp}',
    );
  }
}
