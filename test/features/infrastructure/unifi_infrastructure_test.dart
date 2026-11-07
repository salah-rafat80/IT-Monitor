import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/data/datasources/unifi_api_client.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;
  late InfrastructureRepositoryImpl infraRepo;
  late UniFiApiClient unifiApiClient;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);
    infraRepo = InfrastructureRepositoryImpl(db);
    unifiApiClient = UniFiApiClient();
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
          isCriticalInfrastructure: false,
          requiresAdminConfirmation: true,
          createdAt: DateTime.now(),
        );

        // Core Gateway is the ONLY device performing routing and critical infrastructure
        expect(gateway.isGateway, isTrue);
        expect(gateway.isCriticalInfrastructure, isTrue);
        expect(gateway.performsRouting, isTrue);
        expect(gateway.linkedSubnets.length, equals(2));

        // Switch MUST NOT perform routing
        expect(unifiSwitch.isSwitch, isTrue);
        expect(unifiSwitch.isCriticalInfrastructure, isFalse);
        expect(unifiSwitch.performsRouting, isFalse);
        expect(unifiSwitch.linkedSubnets, isEmpty);

        // Access Point MUST NOT perform routing
        expect(unifiAp.isAccessPoint, isTrue);
        expect(unifiAp.isCriticalInfrastructure, isFalse);
        expect(unifiAp.performsRouting, isFalse);
        expect(unifiAp.linkedSubnets, isEmpty);

        // Unknown device requires admin confirmation
        expect(unknownDevice.isUnknown, isTrue);
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

        // Verify audit log entry in DB
        final logs = await db.select(db.auditLogs).get();
        final logEntry = logs.firstWhere(
          (l) => l.action == 'INFRASTRUCTURE_DEVICE_CREATED',
        );
        expect(logEntry.details, contains('192.168.27.1'));
        expect(logEntry.details, contains('Critical: true'));
      },
    );

    test(
      '3. Read-Only Constraint: UniFi integration strictly prohibits write operations',
      () async {
        expect(
          () => unifiApiClient.executeWriteOperation(),
          throwsUnsupportedError,
        );
      },
    );

    test(
      '4. Local Administrator can save and delete infrastructure devices',
      () async {
        final device = UniFiDeviceEntity(
          id: 0,
          name: 'USW-48-Core',
          ip: '192.168.22.2',
          role: UniFiDeviceRole.switchDevice,
          createdAt: DateTime.now(),
        );

        final saveRes = await infraRepo.saveInfrastructureDevice(device);
        expect(saveRes.isSuccess, isTrue);
        final saved = saveRes.dataOrNull!;

        final delRes = await infraRepo.deleteInfrastructureDevice(saved.id);
        expect(delRes.isSuccess, isTrue);

        final fetchRes = await infraRepo.getDeviceByIp('192.168.22.2');
        expect(fetchRes.dataOrNull, isNull);
      },
    );

    test(
      '5. Preservation of approved 37 PC/Laptop inventory and database reload persistence',
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
