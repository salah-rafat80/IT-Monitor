import 'package:injectable/injectable.dart';

import '../../../devices/domain/repositories/device_repository.dart';
import '../../../infrastructure/domain/entities/unifi_device_entity.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../entities/incident_entity.dart';
import '../repositories/incident_repository.dart';
import 'notification_service.dart';

@lazySingleton
class IncidentEngine {
  final IncidentRepository _incidentRepo;
  final DeviceRepository _deviceRepo;
  final NotificationService _notificationService;

  IncidentEngine(
    this._incidentRepo,
    this._deviceRepo,
    this._notificationService,
  );

  Future<void> processDeviceStatusChange(DeviceStatusEntity status) async {
    // 1. Maintenance or Unknown status check: Suppress incident creation
    if (status.isMaintenance ||
        status.status == DeviceStatusEnum.maintenance ||
        status.status == DeviceStatusEnum.unknown) {
      return;
    }

    final deviceId = status.deviceId;

    // Fetch device metadata
    final deviceRes = await _deviceRepo.getDeviceById(deviceId);
    final device = deviceRes.dataOrNull;
    if (device == null || !device.isEnabled) return;

    // Fetch any active/acknowledged incident for this device
    final activeIncRes = await _incidentRepo.getActiveIncidentForDevice(
      deviceId,
    );
    final activeIncident = activeIncRes.dataOrNull;

    if (status.status == DeviceStatusEnum.down) {
      // 2. Device Down Handling
      if (activeIncident == null) {
        // No active incident exists -> create exactly 1 new incident
        // Evaluate location-level correlation
        String? correlationMsg;
        if (device.officeLocation != null &&
            device.officeLocation!.isNotEmpty) {
          final activeAllRes = await _incidentRepo.getActiveIncidents();
          final activeAll = activeAllRes.dataOrNull ?? [];
          final locationActiveCount = activeAll
              .where((i) => i.location == device.officeLocation)
              .length;

          if (locationActiveCount >= 1) {
            correlationMsg =
                'Multiple devices affected in ${device.officeLocation}';
          }
        }

        final newIncident = IncidentEntity(
          id: 0,
          deviceId: device.id,
          deviceName: device.name,
          ownerName: device.ownerName,
          department: device.department,
          location: device.officeLocation,
          deviceIp: device.ip,
          incidentType: IncidentTypeEnum.deviceDown,
          severity: IncidentSeverityEnum.critical,
          status: IncidentStatusEnum.active,
          startedAt: status.statusChangedAt,
          correlationMessage: correlationMsg,
        );

        final createRes = await _incidentRepo.createIncident(newIncident);
        if (createRes.isSuccess) {
          final created = createRes.dataOrNull!;
          try {
            await _notificationService.notifyIncidentCreated(created);
          } catch (_) {
            // Notification tray failure must not crash monitoring engine
          }
        }
      }
      // If activeIncident already exists -> do not create duplicate!
    } else if (status.status == DeviceStatusEnum.up) {
      // 3. Automatic Recovery Handling
      if (activeIncident != null) {
        final resolveTime = DateTime.now();
        await _incidentRepo.resolveIncident(activeIncident.id, resolveTime);

        final resolvedEntity = activeIncident.copyWith(
          status: IncidentStatusEnum.resolved,
          resolvedAt: resolveTime,
        );
        try {
          await _notificationService.notifyIncidentResolved(resolvedEntity);
        } catch (_) {
          // Notification tray failure must not crash monitoring engine
        }
      }
    }
  }

  /// Process status changes for critical infrastructure (UniFi Gateways, Controllers, Switches)
  Future<void> processInfrastructureStatusChange(
    UniFiDeviceEntity infraDevice,
    DeviceStatusEntity status,
  ) async {
    if (status.isMaintenance ||
        status.status == DeviceStatusEnum.maintenance ||
        status.status == DeviceStatusEnum.unknown) {
      return;
    }

    // Use reserved infrastructure deviceId offset (10000 + infraDevice.id) to prevent collision with PCs
    final infraDeviceId = 10000 + infraDevice.id;

    final activeIncRes = await _incidentRepo.getActiveIncidentForDevice(
      infraDeviceId,
    );
    final activeIncident = activeIncRes.dataOrNull;

    if (status.status == DeviceStatusEnum.down) {
      if (activeIncident == null) {
        IncidentTypeEnum incidentType;
        IncidentSeverityEnum severity;
        String correlationMsg;

        if (infraDevice.isGateway) {
          incidentType = IncidentTypeEnum.gatewayDown;
          severity = IncidentSeverityEnum.critical;
          if (infraDevice.linkedSubnets.isNotEmpty) {
            correlationMsg =
                'Critical Core Gateway Down (${infraDevice.ip}). Suspected routing & internet impact on confirmed segments: ${infraDevice.linkedSubnets.join(', ')}. LAN endpoints remain monitored independently.';
          } else {
            correlationMsg =
                'UniFi Gateway Down (${infraDevice.ip}). Network dependencies unconfirmed (Admin confirmation required). LAN endpoints remain monitored independently.';
          }
        } else if (infraDevice.isController) {
          incidentType = IncidentTypeEnum.controllerDown;
          severity = IncidentSeverityEnum.high;
          correlationMsg =
              'UniFi Controller Down (${infraDevice.ip}). Management plane unreachable. Gateway routing and network traffic continue operating independently.';
        } else if (infraDevice.role == UniFiDeviceRole.accessPoint) {
          incidentType = IncidentTypeEnum.deviceDown;
          severity = IncidentSeverityEnum.medium;
          final area = infraDevice.location != null
              ? ' in ${infraDevice.location}'
              : '';
          correlationMsg =
              'UniFi Access Point Down (${infraDevice.ip})$area. Affected local wireless coverage only. Core routing and network endpoints remain operational.';
        } else {
          incidentType = IncidentTypeEnum.deviceDown;
          severity = infraDevice.isCriticalInfrastructure
              ? IncidentSeverityEnum.critical
              : IncidentSeverityEnum.medium;
          correlationMsg =
              'UniFi Infrastructure (${infraDevice.role.displayName}) Down (${infraDevice.ip}).';
        }

        final newIncident = IncidentEntity(
          id: 0,
          deviceId: infraDeviceId,
          deviceName: infraDevice.name,
          ownerName: 'Infrastructure (${infraDevice.role.displayName})',
          department: 'IT Network Infrastructure',
          location: infraDevice.location ?? 'Network Core',
          deviceIp: infraDevice.ip,
          incidentType: incidentType,
          severity: severity,
          status: IncidentStatusEnum.active,
          startedAt: status.statusChangedAt,
          correlationMessage: correlationMsg,
        );

        final createRes = await _incidentRepo.createIncident(newIncident);
        if (createRes.isSuccess) {
          try {
            await _notificationService.notifyIncidentCreated(
              createRes.dataOrNull!,
            );
          } catch (_) {}
        }
      }
    } else if (status.status == DeviceStatusEnum.up) {
      if (activeIncident != null) {
        final resolveTime = DateTime.now();
        await _incidentRepo.resolveIncident(activeIncident.id, resolveTime);

        final resolvedEntity = activeIncident.copyWith(
          status: IncidentStatusEnum.resolved,
          resolvedAt: resolveTime,
        );
        try {
          await _notificationService.notifyIncidentResolved(resolvedEntity);
        } catch (_) {}
      }
    }
  }
}
