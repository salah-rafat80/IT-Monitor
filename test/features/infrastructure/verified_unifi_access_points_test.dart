import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/data/repositories/infrastructure_repository_impl.dart';
import 'package:it_network_monitor/features/infrastructure/domain/entities/unifi_device_entity.dart';
import 'package:it_network_monitor/features/infrastructure/presentation/bloc/infrastructure_cubit.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/platform_ping_checker.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';

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
      '1. bootstrapVerifiedAccessPoints registers 4 APs in RNF and preserves approved inventory',
      () async {
        // Seed 28 test devices via explicit user import
        final testDevices = List.generate(
          28,
          (i) => DeviceEntity(
            id: -(i + 1),
            factoryId: 'rnf',
            name: 'Device-$i',
            ip: '192.168.22.${50 + i}',
            type: DeviceType.pc,
            ownerName: 'User $i',
            department: 'IT',
            createdAt: DateTime.now(),
          ),
        );
        await deviceRepo.commitImport(testDevices);

        // Bootstrap APs
        final apRes = await infraRepo.bootstrapVerifiedAccessPoints();
        expect(apRes.isSuccess, isTrue);

        // Verify total 4 APs exist when RNF is selected
        final rnfInfra = await infraRepo.getInfrastructureDevices(factoryId: 'rnf');
        final aps = rnfInfra.dataOrNull!
            .where((d) => d.role == UniFiDeviceRole.accessPoint)
            .toList();
        expect(aps.length, equals(4));

        // Verify exact verified IPs and RNF factory attribution
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
        for (final ap in aps) {
          expect(ap.factoryId, equals('rnf'));
        }

        // Verify UniFis are NOT displayed when BNF is selected
        final bnfInfra = await infraRepo.getInfrastructureDevices(factoryId: 'bnf');
        expect(bnfInfra.dataOrNull!.any((d) => d.role == UniFiDeviceRole.accessPoint), isFalse);

        final allInfra = await infraRepo.getInfrastructureDevices();
        expect(allInfra.dataOrNull!.any((d) => d.role == UniFiDeviceRole.accessPoint), isTrue);

        // Verify 28 PC/laptop inventory is 100% intact
        final allEndpoints = await deviceRepo.getDevices();
        expect(allEndpoints.dataOrNull!.length, equals(28));
      },
    );

    test('2. bootstrapVerifiedAccessPoints is strictly idempotent', () async {
      await infraRepo.bootstrapVerifiedAccessPoints();
      final secondRun = await infraRepo.bootstrapVerifiedAccessPoints();

      expect(secondRun.isSuccess, isTrue);

      final rnfInfra = await infraRepo.getInfrastructureDevices(factoryId: 'rnf');
      final aps = rnfInfra.dataOrNull!
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

    test(
      '4. InfrastructureCubit excludes switches from visible devices (state.devices)',
      () async {
        final monitoringRepo = MonitoringRepositoryImpl(db);
        final pingChecker = PlatformPingChecker();

        await infraRepo.bootstrapVerifiedAccessPoints();
        await infraRepo.bootstrapVerifiedSwitches();

        final cubit = InfrastructureCubit(
          infraRepo,
          monitoringRepo,
          pingChecker,
          deviceRepo,
        );

        await cubit.loadInfrastructure(triggerPing: false, factoryId: 'rnf');

        // Total visible devices in state must be exactly 4 APs, 0 switches
        expect(cubit.state.devices.length, equals(4));
        expect(
          cubit.state.devices.every(
            (d) => d.role != UniFiDeviceRole.switchDevice,
          ),
          isTrue,
        );
        expect(cubit.state.totalCount, equals(4));

        await cubit.close();
      },
    );
  });
}
