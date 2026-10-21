import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/services/incident_engine.dart';
import 'package:it_network_monitor/features/incidents/domain/services/notification_service.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

class MockNotificationService implements NotificationService {
  final List<IncidentEntity> createdNotifications = [];
  final List<IncidentEntity> resolvedNotifications = [];

  @override
  Future<void> notifyIncidentCreated(IncidentEntity incident) async {
    createdNotifications.add(incident);
  }

  @override
  Future<void> notifyIncidentResolved(IncidentEntity incident) async {
    resolvedNotifications.add(incident);
  }
}

void main() {
  late AppDatabase db;
  late AuditLogRepositoryImpl auditLogRepo;
  late AuthRepositoryImpl authRepo;
  late DeviceRepositoryImpl deviceRepo;
  late IncidentRepositoryImpl incidentRepo;
  late MockNotificationService mockNotificationService;
  late IncidentEngine incidentEngine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auditLogRepo = AuditLogRepositoryImpl(db);
    authRepo = AuthRepositoryImpl(db, auditLogRepo);
    deviceRepo = DeviceRepositoryImpl(db, auditLogRepo, authRepo);
    incidentRepo = IncidentRepositoryImpl(db, auditLogRepo);
    mockNotificationService = MockNotificationService();
    incidentEngine = IncidentEngine(
      incidentRepo,
      deviceRepo,
      mockNotificationService,
    );

    await authRepo.createInitialAdmin(
      username: 'admin_inc',
      password: 'Password123',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 5 — Incident Engine & Root Cause Unit Tests', () {
    test(
      '1. Transition to Down creates exactly 1 active incident with notification',
      () async {
        final createDevRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'DESKTOP-FIN01',
            type: DeviceType.pc,
            ip: '192.168.1.10',
            ownerName: 'Alice Finance',
            department: 'Finance',
            officeLocation: 'Room 101',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final device = createDevRes.dataOrNull!;

        final downStatus = DeviceStatusEntity(
          deviceId: device.id,
          status: DeviceStatusEnum.down,
          isMaintenance: false,
          consecutiveFailures: 3,
          consecutiveSuccesses: 0,
          lastLatencyMs: null,
          lastCheckAt: DateTime.now(),
          statusChangedAt: DateTime.now(),
        );

        await incidentEngine.processDeviceStatusChange(downStatus);

        final activeIncidentsRes = await incidentRepo.getActiveIncidents();
        final activeIncidents = activeIncidentsRes.dataOrNull!;
        expect(activeIncidents.length, equals(1));
        expect(activeIncidents.first.deviceId, equals(device.id));
        expect(activeIncidents.first.deviceName, equals('DESKTOP-FIN01'));
        expect(activeIncidents.first.ownerName, equals('Alice Finance'));
        expect(activeIncidents.first.status, equals(IncidentStatusEnum.active));
        expect(mockNotificationService.createdNotifications.length, equals(1));
      },
    );

    test(
      '2. Deduplication: Subsequent Down status updates do NOT create duplicate active incidents',
      () async {
        final createDevRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'DESKTOP-FIN01',
            type: DeviceType.pc,
            ip: '192.168.1.10',
            ownerName: 'Alice Finance',
            department: 'Finance',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final device = createDevRes.dataOrNull!;

        final downStatus = DeviceStatusEntity(
          deviceId: device.id,
          status: DeviceStatusEnum.down,
          isMaintenance: false,
          consecutiveFailures: 3,
          consecutiveSuccesses: 0,
          lastLatencyMs: null,
          lastCheckAt: DateTime.now(),
          statusChangedAt: DateTime.now(),
        );

        // Process 3 consecutive Down status cycles
        await incidentEngine.processDeviceStatusChange(downStatus);
        await incidentEngine.processDeviceStatusChange(downStatus);
        await incidentEngine.processDeviceStatusChange(downStatus);

        final activeIncidentsRes = await incidentRepo.getActiveIncidents();
        final activeIncidents = activeIncidentsRes.dataOrNull!;
        expect(activeIncidents.length, equals(1)); // Strictly 1 active incident
        expect(mockNotificationService.createdNotifications.length, equals(1));
      },
    );

    test(
      '3. Automatic Recovery: Transitioning to Up resolves active incident',
      () async {
        final createDevRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'LAPTOP-HR01',
            type: DeviceType.laptop,
            ip: '192.168.1.20',
            ownerName: 'Bob HR',
            department: 'HR',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final device = createDevRes.dataOrNull!;

        final downStatus = DeviceStatusEntity(
          deviceId: device.id,
          status: DeviceStatusEnum.down,
          isMaintenance: false,
          consecutiveFailures: 3,
          consecutiveSuccesses: 0,
          lastLatencyMs: null,
          lastCheckAt: DateTime.now(),
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processDeviceStatusChange(downStatus);

        expect(
          (await incidentRepo.getActiveIncidents()).dataOrNull!.length,
          equals(1),
        );

        // Device recovers to Up
        final upStatus = DeviceStatusEntity(
          deviceId: device.id,
          status: DeviceStatusEnum.up,
          isMaintenance: false,
          consecutiveFailures: 0,
          consecutiveSuccesses: 2,
          lastLatencyMs: 14,
          lastCheckAt: DateTime.now(),
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processDeviceStatusChange(upStatus);

        final activeAfterRecovery =
            (await incidentRepo.getActiveIncidents()).dataOrNull!;
        expect(activeAfterRecovery.isEmpty, isTrue);

        final historyRes = await incidentRepo.getIncidentHistory();
        final history = historyRes.dataOrNull!;
        expect(history.length, equals(1));
        expect(history.first.status, equals(IncidentStatusEnum.resolved));
        expect(history.first.resolvedAt, isNotNull);
        expect(mockNotificationService.resolvedNotifications.length, equals(1));
      },
    );

    test(
      '4. Maintenance Mode: Incident creation is suppressed when device is in maintenance',
      () async {
        final createDevRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'DESKTOP-IT01',
            type: DeviceType.pc,
            ip: '192.168.1.30',
            ownerName: 'Charlie IT',
            department: 'IT',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final device = createDevRes.dataOrNull!;

        final maintenanceStatus = DeviceStatusEntity(
          deviceId: device.id,
          status: DeviceStatusEnum.down,
          isMaintenance: true, // Maintenance enabled
          consecutiveFailures: 3,
          consecutiveSuccesses: 0,
          lastLatencyMs: null,
          lastCheckAt: DateTime.now(),
          statusChangedAt: DateTime.now(),
        );

        await incidentEngine.processDeviceStatusChange(maintenanceStatus);

        final activeRes = await incidentRepo.getActiveIncidents();
        expect(activeRes.dataOrNull!.isEmpty, isTrue);
      },
    );

    test(
      '5. Location-Level Correlation: Adds correlation message when 2+ devices down in same location',
      () async {
        final dev1Res = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'DESKTOP-L1',
            type: DeviceType.pc,
            ip: '192.168.1.41',
            ownerName: 'User A',
            department: 'Ops',
            officeLocation: 'Room 303',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final dev2Res = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'DESKTOP-L2',
            type: DeviceType.pc,
            ip: '192.168.1.42',
            ownerName: 'User B',
            department: 'Ops',
            officeLocation: 'Room 303',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final dev1 = dev1Res.dataOrNull!;
        final dev2 = dev2Res.dataOrNull!;

        // Down status for Dev 1
        await incidentEngine.processDeviceStatusChange(
          DeviceStatusEntity(
            deviceId: dev1.id,
            status: DeviceStatusEnum.down,
            isMaintenance: false,
            consecutiveFailures: 3,
            consecutiveSuccesses: 0,
            lastLatencyMs: null,
            lastCheckAt: DateTime.now(),
            statusChangedAt: DateTime.now(),
          ),
        );

        // Down status for Dev 2 in same location
        await incidentEngine.processDeviceStatusChange(
          DeviceStatusEntity(
            deviceId: dev2.id,
            status: DeviceStatusEnum.down,
            isMaintenance: false,
            consecutiveFailures: 3,
            consecutiveSuccesses: 0,
            lastLatencyMs: null,
            lastCheckAt: DateTime.now(),
            statusChangedAt: DateTime.now(),
          ),
        );

        final activeIncidents =
            (await incidentRepo.getActiveIncidents()).dataOrNull!;
        expect(activeIncidents.length, equals(2));

        final dev2Incident = activeIncidents.firstWhere(
          (i) => i.deviceId == dev2.id,
        );
        expect(
          dev2Incident.correlationMessage,
          contains('Multiple devices affected in Room 303'),
        );
      },
    );

    test(
      '6. Acknowledgment & Notes: Acknowledgment sets status and generates audit log',
      () async {
        final createDevRes = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'DESKTOP-FIN02',
            type: DeviceType.pc,
            ip: '192.168.1.50',
            ownerName: 'Dave Finance',
            department: 'Finance',
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        final device = createDevRes.dataOrNull!;

        await incidentEngine.processDeviceStatusChange(
          DeviceStatusEntity(
            deviceId: device.id,
            status: DeviceStatusEnum.down,
            isMaintenance: false,
            consecutiveFailures: 3,
            consecutiveSuccesses: 0,
            lastLatencyMs: null,
            lastCheckAt: DateTime.now(),
            statusChangedAt: DateTime.now(),
          ),
        );

        final activeInc =
            (await incidentRepo.getActiveIncidents()).dataOrNull!.first;

        final ackRes = await incidentRepo.acknowledgeIncident(
          id: activeInc.id,
          username: 'admin_inc',
          note: 'Investigating power outlet issue',
        );
        expect(ackRes.isSuccess, isTrue);

        final updatedHistory =
            (await incidentRepo.getIncidentHistory()).dataOrNull!.first;
        expect(updatedHistory.status, equals(IncidentStatusEnum.acknowledged));
        expect(updatedHistory.acknowledgedBy, equals('admin_inc'));
        expect(
          updatedHistory.notes,
          contains('Investigating power outlet issue'),
        );

        final logsRes = await auditLogRepo.getAuditLogs();
        final ackLogs = logsRes.dataOrNull!
            .where((l) => l.action == 'INCIDENT_ACKNOWLEDGED')
            .toList();
        expect(ackLogs.length, equals(1));
      },
    );
  });
}
