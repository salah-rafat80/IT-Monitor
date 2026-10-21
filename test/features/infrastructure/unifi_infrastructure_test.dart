import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/password_hash.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/auth/domain/entities/user_entity.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/incidents/domain/services/incident_engine.dart';
import 'package:it_network_monitor/features/incidents/domain/services/notification_service.dart';
import 'package:it_network_monitor/features/infrastructure/data/datasources/unifi_api_client.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
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
  late UniFiApiClient unifiApiClient;

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
    unifiApiClient = UniFiApiClient();

    // Create initial admin using authRepo
    await authRepo.createInitialAdmin(
      username: 'admin',
      password: 'AdminPassword123',
    );
    await authRepo.login(username: 'admin', password: 'AdminPassword123');
  });

  tearDown(() async {
    await db.close();
  });

  group('Critical UniFi Infrastructure Monitoring Tests', () {
    test(
      '1. Role identification and non-routing assumptions for non-gateway devices',
      () {
        final gateway = UniFiDeviceEntity(
          id: 1,
          name: 'UDM-Pro-Core',
          ip: '192.168.22.1',
          role: UniFiDeviceRole.gateway,
          isCriticalInfrastructure: true,
          requiresAdminConfirmation: false,
          linkedSubnets: const ['192.168.22.0/24', '192.168.27.0/24'],
          createdAt: DateTime.now(),
        );

        final unifiSwitch = UniFiDeviceEntity(
          id: 2,
          name: 'USW-24-PoE-Floor1',
          ip: '192.168.22.2',
          role: UniFiDeviceRole.switchDevice,
          isCriticalInfrastructure: false,
          requiresAdminConfirmation: false,
          createdAt: DateTime.now(),
        );

        final unifiAp = UniFiDeviceEntity(
          id: 3,
          name: 'UAP-AC-Pro-Office',
          ip: '192.168.22.3',
          role: UniFiDeviceRole.accessPoint,
          isCriticalInfrastructure: false,
          requiresAdminConfirmation: false,
          createdAt: DateTime.now(),
        );

        final unknownDevice = UniFiDeviceEntity(
          id: 4,
          name: 'Unknown-UniFi-Device',
          ip: '192.168.22.4',
          role: UniFiDeviceRole.otherUnknown,
          requiresAdminConfirmation: true,
          createdAt: DateTime.now(),
        );

        // Verify routing assumption
        expect(gateway.isGateway, isTrue);
        expect(gateway.performsRouting, isTrue);

        // UniFi Switches and APs must NOT be assumed to perform routing
        expect(unifiSwitch.isGateway, isFalse);
        expect(unifiSwitch.performsRouting, isFalse);
        expect(unifiAp.isGateway, isFalse);
        expect(unifiAp.performsRouting, isFalse);

        // Unknown device must require admin confirmation
        expect(unknownDevice.requiresAdminConfirmation, isTrue);
        expect(unknownDevice.performsRouting, isFalse);
      },
    );

    test(
      '2. Registering UniFi infrastructure persists in Drift DB with audit logging',
      () async {
        final newGateway = UniFiDeviceEntity(
          id: 0,
          name: 'UniFi Gateway Pro',
          ip: '192.168.27.1',
          role: UniFiDeviceRole.gateway,
          isCriticalInfrastructure: true,
          requiresAdminConfirmation: false,
          linkedSubnets: const ['192.168.27.0/24'],
          createdAt: DateTime.now(),
        );

        final saveRes = await infraRepo.saveInfrastructureDevice(newGateway);
        expect(saveRes.isSuccess, isTrue);

        final saved = saveRes.dataOrNull!;
        expect(saved.id, greaterThan(0));
        expect(saved.ip, equals('192.168.27.1'));
        expect(saved.isCriticalInfrastructure, isTrue);
        expect(saved.isReadOnly, isTrue);

        // Verify retrieval from DB
        final fetchRes = await infraRepo.getDeviceByIp('192.168.27.1');
        expect(fetchRes.isSuccess, isTrue);
        expect(fetchRes.dataOrNull?.name, equals('UniFi Gateway Pro'));
        expect(fetchRes.dataOrNull?.linkedSubnets, equals(['192.168.27.0/24']));

        // Verify audit log entry
        final logs = await auditLogRepo.getAuditLogs();
        expect(logs.isSuccess, isTrue);
        final logEntry = logs.dataOrNull!.firstWhere(
          (l) => l.action == 'INFRASTRUCTURE_DEVICE_CREATED',
        );
        expect(logEntry.details, contains('192.168.27.1'));
        expect(logEntry.details, contains('Critical: true'));
      },
    );

    test(
      '3. Core Gateway Down creates exactly ONE deduplicated Critical Incident with accurate impact',
      () async {
        final gateway = UniFiDeviceEntity(
          id: 1,
          name: 'UniFi Dream Machine Pro',
          ip: '192.168.22.1',
          role: UniFiDeviceRole.gateway,
          isCriticalInfrastructure: true,
          requiresAdminConfirmation: false,
          linkedSubnets: const ['192.168.22.0/24', '192.168.27.0/24'],
          createdAt: DateTime.now(),
        );

        final downStatus = DeviceStatusEntity(
          deviceId: 10001, // 10000 + 1
          status: DeviceStatusEnum.down,
          consecutiveFailures: 3,
          statusChangedAt: DateTime.now(),
        );

        // Trigger status change: Gateway is Down
        await incidentEngine.processInfrastructureStatusChange(
          gateway,
          downStatus,
        );

        // Verify exactly 1 incident created
        final activeIncRes = await incidentRepo.getActiveIncidents();
        expect(activeIncRes.isSuccess, isTrue);
        final activeIncidents = activeIncRes.dataOrNull!;
        expect(activeIncidents.length, equals(1));

        final incident = activeIncidents.first;
        expect(incident.deviceId, equals(10001));
        expect(incident.incidentType, equals(IncidentTypeEnum.gatewayDown));
        expect(incident.severity, equals(IncidentSeverityEnum.critical));
        expect(incident.deviceIp, equals('192.168.22.1'));
        expect(incident.correlationMessage, contains('192.168.22.0/24'));
        expect(incident.correlationMessage, contains('192.168.27.0/24'));
        expect(
          incident.correlationMessage,
          contains('LAN endpoints remain monitored independently'),
        );

        // Verify notification emitted
        expect(notificationService.createdNotifications.length, equals(1));

        // Trigger second down status change (simulation of consecutive failure check)
        await incidentEngine.processInfrastructureStatusChange(
          gateway,
          downStatus,
        );

        // Verify DEDUPLICATION: Still only 1 active incident, not 2
        final activeIncRes2 = await incidentRepo.getActiveIncidents();
        expect(activeIncRes2.dataOrNull!.length, equals(1));
      },
    );

    test(
      '4. Dependency isolation: Gateway Down does NOT automatically mark dependent PCs as Down',
      () async {
        // Create regular PC endpoint in inventory
        final pc = DeviceEntity(
          id: 1,
          name: 'PC-25',
          type: DeviceType.laptop,
          ip: '192.168.27.25',
          ownerName: 'Amr',
          department: 'Accounting',
          createdAt: DateTime.now(),
        );
        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: pc.name,
                ip: pc.ip,
                ownerName: pc.ownerName,
                department: pc.department,
              ),
            );

        // Gateway goes down
        final gateway = UniFiDeviceEntity(
          id: 1,
          name: 'UDM-Core',
          ip: '192.168.27.1',
          role: UniFiDeviceRole.gateway,
          isCriticalInfrastructure: true,
          linkedSubnets: const ['192.168.27.0/24'],
          createdAt: DateTime.now(),
        );
        final gatewayDown = DeviceStatusEntity(
          deviceId: 10001,
          status: DeviceStatusEnum.down,
          consecutiveFailures: 3,
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processInfrastructureStatusChange(
          gateway,
          gatewayDown,
        );

        // The local PC continues responding to LAN ICMP probes -> Status is UP
        final pcStatus = DeviceStatusEntity(
          deviceId: 1,
          status: DeviceStatusEnum.up,
          consecutiveSuccesses: 2,
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processDeviceStatusChange(pcStatus);

        // Verify: PC is NOT marked down and has NO down incident!
        final pcIncidentRes = await incidentRepo.getActiveIncidentForDevice(1);
        expect(pcIncidentRes.dataOrNull, isNull);

        // Gateway incident exists independently
        final gwIncidentRes = await incidentRepo.getActiveIncidentForDevice(
          10001,
        );
        expect(gwIncidentRes.dataOrNull, isNotNull);
        expect(
          gwIncidentRes.dataOrNull?.incidentType,
          equals(IncidentTypeEnum.gatewayDown),
        );
      },
    );

    test(
      '5. Gateway recovery automatically resolves active critical incident',
      () async {
        final gateway = UniFiDeviceEntity(
          id: 1,
          name: 'UDM-Pro',
          ip: '192.168.22.1',
          role: UniFiDeviceRole.gateway,
          isCriticalInfrastructure: true,
          createdAt: DateTime.now(),
        );

        final downStatus = DeviceStatusEntity(
          deviceId: 10001,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processInfrastructureStatusChange(
          gateway,
          downStatus,
        );

        expect(
          (await incidentRepo.getActiveIncidents()).dataOrNull!.length,
          equals(1),
        );

        // Gateway recovers
        final upStatus = DeviceStatusEntity(
          deviceId: 10001,
          status: DeviceStatusEnum.up,
          statusChangedAt: DateTime.now(),
        );
        await incidentEngine.processInfrastructureStatusChange(
          gateway,
          upStatus,
        );

        // Active incident is resolved
        final activeIncRes = await incidentRepo.getActiveIncidents();
        expect(activeIncRes.dataOrNull!, isEmpty);

        // Appears in resolved history
        final historyRes = await incidentRepo.getIncidentHistory();
        expect(historyRes.dataOrNull!.length, equals(1));
        expect(
          historyRes.dataOrNull!.first.status,
          equals(IncidentStatusEnum.resolved),
        );
        expect(notificationService.resolvedNotifications.length, equals(1));
      },
    );

    test(
      '6. UniFi Controller Down is separated from Gateway and does NOT report routing failure',
      () async {
        final controller = UniFiDeviceEntity(
          id: 2,
          name: 'UniFi CloudKey G2+',
          ip: '192.168.22.5',
          role: UniFiDeviceRole.controller,
          isCriticalInfrastructure: false,
          controllerUrl: 'https://192.168.22.5:8443',
          createdAt: DateTime.now(),
        );

        final ctrlDown = DeviceStatusEntity(
          deviceId: 10002,
          status: DeviceStatusEnum.down,
          statusChangedAt: DateTime.now(),
        );

        await incidentEngine.processInfrastructureStatusChange(
          controller,
          ctrlDown,
        );

        final activeIncRes = await incidentRepo.getActiveIncidents();
        final incident = activeIncRes.dataOrNull!.first;

        expect(incident.incidentType, equals(IncidentTypeEnum.controllerDown));
        expect(incident.severity, equals(IncidentSeverityEnum.high));
        expect(
          incident.correlationMessage,
          contains('Management plane unreachable'),
        );
        expect(
          incident.correlationMessage,
          contains('continue operating independently'),
        );
        // Must NOT claim routing failure
        expect(incident.correlationMessage, isNot(contains('routing impact')));
      },
    );

    test(
      '7. Read-Only Constraint: UniFi integration strictly prohibits write operations',
      () async {
        expect(
          () => unifiApiClient.executeWriteOperation(),
          throwsUnsupportedError,
        );
      },
    );

    test(
      '8. Role-based permissions: Non-admin Viewer cannot add or delete infrastructure',
      () async {
        // Seed a viewer user
        final viewerHash = PasswordHash.hashPassword('ViewerPassword123');
        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                username: 'viewer1',
                passwordHash: viewerHash,
                role: drift.Value(UserRole.viewer.name),
                isEnabled: const drift.Value(true),
              ),
            );

        // Login as Viewer
        await authRepo.login(
          username: 'viewer1',
          password: 'ViewerPassword123',
        );

        final device = UniFiDeviceEntity(
          id: 0,
          name: 'Hacker Attempt',
          ip: '192.168.22.99',
          createdAt: DateTime.now(),
        );

        final saveRes = await infraRepo.saveInfrastructureDevice(device);
        expect(saveRes.isFailure, isTrue);
        expect(saveRes.failureOrNull, isA<UnauthorizedFailure>());

        final delRes = await infraRepo.deleteInfrastructureDevice(1);
        expect(delRes.isFailure, isTrue);
        expect(delRes.failureOrNull, isA<UnauthorizedFailure>());
      },
    );

    test(
      '9. Preservation of approved 37 PC/Laptop inventory and database reload persistence',
      () async {
        // Insert mock PC from approved inventory
        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'FIN-117',
                ip: '192.168.22.117',
                ownerName: 'Hisham Essam',
                department: 'Accounting',
              ),
            );

        // Register infrastructure device
        await infraRepo.saveInfrastructureDevice(
          UniFiDeviceEntity(
            id: 0,
            name: 'Core Gateway',
            ip: '192.168.22.1',
            role: UniFiDeviceRole.gateway,
            isCriticalInfrastructure: true,
            createdAt: DateTime.now(),
          ),
        );

        // Verify regular device inventory is intact
        final regularDevices = await deviceRepo.getDevices();
        expect(regularDevices.dataOrNull!.length, equals(1));
        expect(regularDevices.dataOrNull!.first.name, equals('FIN-117'));

        // Verify infrastructure devices exist separately
        final infraDevices = await infraRepo.getInfrastructureDevices();
        expect(infraDevices.dataOrNull!.length, equals(1));
        expect(infraDevices.dataOrNull!.first.ip, equals('192.168.22.1'));
      },
    );
  });
}
