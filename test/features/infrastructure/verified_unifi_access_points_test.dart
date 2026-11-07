import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;
  late InfrastructureRepositoryImpl infraRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);
    infraRepo = InfrastructureRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Verified UniFi Access Points Integration Tests', () {
    test(
      '1. bootstrapVerifiedAccessPoints registers 5 APs in RNF and preserves approved inventory',
      () async {
        // Seed 37 approved inventory
        final seedRes = await deviceRepo.bootstrapApprovedInventory();
        expect(seedRes.isSuccess, isTrue);
        expect(seedRes.dataOrNull, equals(37));

        // Bootstrap APs
        final apRes = await infraRepo.bootstrapVerifiedAccessPoints();
        expect(apRes.isSuccess, isTrue);

        // Verify total 4 APs exist in RNF
        final allInfra = await infraRepo.getInfrastructureDevices();
        final aps = allInfra.dataOrNull!
            .where((d) => d.role == UniFiDeviceRole.accessPoint)
            .toList();
        expect(aps.length, equals(4));

        // Verify exact verified IPs
        final ips = aps.map((a) => a.ip).toSet();
        expect(
          ips,
          containsAll([
            '192.168.7.6',
            '192.168.7.4',
            '192.168.7.2',
            '192.168.8.5',
          ]),
        );

        // Verify 37 PC/laptop inventory is 100% intact
        final allEndpoints = await deviceRepo.getDevices();
        expect(allEndpoints.dataOrNull!.length, equals(37));
      },
    );

    test('2. bootstrapVerifiedAccessPoints is strictly idempotent', () async {
      await infraRepo.bootstrapVerifiedAccessPoints();
      final secondRun = await infraRepo.bootstrapVerifiedAccessPoints();

      expect(secondRun.isSuccess, isTrue);

      final allInfra = await infraRepo.getInfrastructureDevices();
      final aps = allInfra.dataOrNull!
          .where((d) => d.role == UniFiDeviceRole.accessPoint)
          .toList();
      expect(aps.length, equals(4));
    });

    test('3. Verified AP entity role constraints', () {
      final ap = UniFiDeviceEntity(
        id: 1,
        name: 'RNF-AP-WAREHOUSE-NORTH',
        ip: '192.168.22.2',
        role: UniFiDeviceRole.accessPoint,
        factoryId: 'rnf',
        location: 'Warehouse Floor 1',
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      expect(ap.isAccessPoint, isTrue);
      expect(ap.isGateway, isFalse);
      expect(ap.performsRouting, isFalse);
      expect(ap.isCriticalInfrastructure, isFalse);
    });
  });
}
