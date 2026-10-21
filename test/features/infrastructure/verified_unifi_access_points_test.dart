import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/services/incident_engine.dart';
import 'package:it_network_monitor/features/incidents/domain/services/notification_service.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_state.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

class _MockNotificationService implements NotificationService {
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
  late InfrastructureRepositoryImpl infraRepo;
  late _MockNotificationService notificationService;
  late IncidentEngine incidentEngine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auditLogRepo = AuditLogRepositoryImpl(db);
    authRepo = AuthRepositoryImpl(db, auditLogRepo);
    deviceRepo = DeviceRepositoryImpl(db, auditLogRepo, authRepo);
    incidentRepo = IncidentRepositoryImpl(db, auditLogRepo);
    infraRepo = InfrastructureRepositoryImpl(db, auditLogRepo, authRepo);
    notificationService = _MockNotificationService();
    incidentEngine = IncidentEngine(
      incidentRepo,
      deviceRepo,
      notificationService,
    );

    // Initial admin login
    await authRepo.createInitialAdmin(
      username: 'admin',
      password: 'AdminPassword123',
    );
    await authRepo.login(username: 'admin', password: 'AdminPassword123');
  });

  tearDown(() async {
    await db.close();
  });

  group('Verified UniFi Access Points Infrastructure Tests', () {
    test(
      '1. Bootstraps the four verified UniFi Access Points with exact names, IPs, and locations',
      () async {
        final bootstrapRes = await infraRepo.bootstrapVerifiedAccessPoints();
        expect(bootstrapRes.isSuccess, isTrue);

        final devicesRes = await infraRepo.getInfrastructureDevices();
        expect(devicesRes.isSuccess, isTrue);
        final devices = devicesRes.dataOrNull!;

        expect(devices.length, equals(4));

        // Device 1: Packing Area
        final packingArea = devices.firstWhere((d) => d.ip == '192.168.7.6');
        expect(packingArea.name, equals('Packing Area'));
        expect(
          packingArea.location,
          equals('Factory Administration, Upper Area'),
        );
        expect(packingArea.role, equals(UniFiDeviceRole.accessPoint));
        expect(packingArea.isCriticalInfrastructure, isFalse);
        expect(packingArea.isGateway, isFalse);
        expect(packingArea.performsRouting, isFalse);

        // Device 2: Meeting Room
        final meetingRoom = devices.firstWhere((d) => d.ip == '192.168.7.4');
        expect(meetingRoom.name, equals('Meeting Room'));
        expect(
          meetingRoom.location,
          equals('Factory Administration, Upper Area'),
        );
        expect(meetingRoom.role, equals(UniFiDeviceRole.accessPoint));
        expect(meetingRoom.isCriticalInfrastructure, isFalse);

        // Device 3: FM Office
        final fmOffice = devices.firstWhere((d) => d.ip == '192.168.7.2');
        expect(fmOffice.name, equals('FM Office'));
        expect(fmOffice.location, equals('Factory Administration, Upper Area'));
        expect(fmOffice.role, equals(UniFiDeviceRole.accessPoint));
        expect(fmOffice.isCriticalInfrastructure, isFalse);

        // Device 4: IoT_Palitizer
        final iotPalitizer = devices.firstWhere((d) => d.ip == '192.168.8.5');
        expect(iotPalitizer.name, equals('IoT_Palitizer'));
        expect(iotPalitizer.location, equals('Lower Area'));
        expect(iotPalitizer.role, equals(UniFiDeviceRole.accessPoint));
        expect(iotPalitizer.isCriticalInfrastructure, isFalse);
      },
    );

    test(
      '2. Initial monitoring status is Unknown in database until actual check results exist',
      () async {
        await infraRepo.bootstrapVerifiedAccessPoints();
        final devices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull!;

        for (final ap in devices) {
          final virtualId = 10000 + ap.id;
          final statusRow = await (db.select(
            db.deviceStatuses,
          )..where((t) => t.deviceId.equals(virtualId))).getSingleOrNull();

          expect(statusRow, isNotNull);
          expect(statusRow!.status, equals('unknown'));
        }
      },
    );

    test(
      '3. Bootstrap is idempotent and does not create duplicate records on restart',
      () async {
        await infraRepo.bootstrapVerifiedAccessPoints();
        await infraRepo.bootstrapVerifiedAccessPoints();
        await infraRepo.bootstrapVerifiedAccessPoints();

        final devices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull!;
        expect(devices.length, equals(4));
      },
    );

    test(
      '4. AP Down creates medium-severity incident with actual name, IP, location, and localized scope',
      () async {
        await infraRepo.bootstrapVerifiedAccessPoints();
        final devices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull!;
        final packingArea = devices.firstWhere((d) => d.ip == '192.168.7.6');

        final downStatus = DeviceStatusEntity(
          deviceId: 10000 + packingArea.id,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now(),
        );

        await incidentEngine.processInfrastructureStatusChange(
          packingArea,
          downStatus,
        );

        final activeIncRes = await incidentRepo.getActiveIncidentForDevice(
          10000 + packingArea.id,
        );
        expect(activeIncRes.isSuccess, isTrue);
        final incident = activeIncRes.dataOrNull!;

        expect(incident.deviceName, equals('Packing Area'));
        expect(incident.deviceIp, equals('192.168.7.6'));
        expect(incident.location, equals('Factory Administration, Upper Area'));
        expect(incident.severity, equals(IncidentSeverityEnum.medium));
        expect(incident.incidentType, equals(IncidentTypeEnum.deviceDown));
        expect(
          incident.correlationMessage,
          contains('UniFi Access Point Down (192.168.7.6)'),
        );
        expect(
          incident.correlationMessage,
          contains('Factory Administration, Upper Area'),
        );
        expect(
          incident.correlationMessage,
          contains('Affected local wireless coverage only'),
        );
        expect(
          incident.correlationMessage,
          contains('Core routing and network endpoints remain operational'),
        );

        // Verify notification was sent
        expect(notificationService.createdNotifications.length, equals(1));
        expect(
          notificationService.createdNotifications.first.deviceName,
          equals('Packing Area'),
        );
      },
    );

    test(
      '5. AP Down does not cascade or mark PC/Laptop inventory as Down',
      () async {
        // Create approved PC device
        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'WS-PACK-01',
                ip: '192.168.22.105',
                ownerName: 'Ahmed Mahmoud',
                department: 'Packaging',
                officeLocation: const drift.Value(
                  'Factory Administration, Upper Area',
                ),
              ),
            );

        await infraRepo.bootstrapVerifiedAccessPoints();
        final devices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull!;
        final packingArea = devices.firstWhere((d) => d.ip == '192.168.7.6');

        final downStatus = DeviceStatusEntity(
          deviceId: 10000 + packingArea.id,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now(),
        );

        await incidentEngine.processInfrastructureStatusChange(
          packingArea,
          downStatus,
        );

        // Check regular device incident
        final regularDeviceInc = await incidentRepo.getActiveIncidentForDevice(
          1,
        );
        expect(regularDeviceInc.dataOrNull, isNull);

        // Verify regular device count remains 1 and infrastructure count is 4
        final regularDevices = (await deviceRepo.getDevices()).dataOrNull!;
        expect(regularDevices.length, equals(1));
        expect(devices.length, equals(4));
      },
    );

    test(
      '6. Recovery of AP to Up status automatically resolves active incident',
      () async {
        await infraRepo.bootstrapVerifiedAccessPoints();
        final devices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull!;
        final fmOffice = devices.firstWhere((d) => d.ip == '192.168.7.2');

        final downStatus = DeviceStatusEntity(
          deviceId: 10000 + fmOffice.id,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        await incidentEngine.processInfrastructureStatusChange(
          fmOffice,
          downStatus,
        );

        expect(
          (await incidentRepo.getActiveIncidentForDevice(
            10000 + fmOffice.id,
          )).dataOrNull,
          isNotNull,
        );

        final upStatus = DeviceStatusEntity(
          deviceId: 10000 + fmOffice.id,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processInfrastructureStatusChange(
          fmOffice,
          upStatus,
        );

        expect(
          (await incidentRepo.getActiveIncidentForDevice(
            10000 + fmOffice.id,
          )).dataOrNull,
          isNull,
        );
        expect(notificationService.resolvedNotifications.length, equals(1));
      },
    );

    test(
      '7. InfrastructureState provides distinct summary counts and active incident access',
      () async {
        await infraRepo.bootstrapVerifiedAccessPoints();
        final devices =
            (await infraRepo.getInfrastructureDevices()).dataOrNull!;

        final state = InfrastructureState(
          devices: devices,
          statuses: {
            10001: DeviceStatusEntity(
              deviceId: 10001,
              status: DeviceStatusEnum.up,
              lastLatencyMs: 12,
              statusChangedAt: DateTime.now(),
            ),
            10002: DeviceStatusEntity(
              deviceId: 10002,
              status: DeviceStatusEnum.down,
              statusChangedAt: DateTime.now(),
            ),
            10003: DeviceStatusEntity(
              deviceId: 10003,
              status: DeviceStatusEnum.unknown,
              statusChangedAt: DateTime.now(),
            ),
            10004: DeviceStatusEntity(
              deviceId: 10004,
              status: DeviceStatusEnum.degraded,
              lastLatencyMs: 85,
              statusChangedAt: DateTime.now(),
            ),
          },
        );

        expect(state.totalCount, equals(4));
        expect(state.upCount, equals(1));
        expect(state.downCount, equals(1));
        expect(state.unknownCount, equals(1));
        expect(state.degradedCount, equals(1));
      },
    );
  });
}
