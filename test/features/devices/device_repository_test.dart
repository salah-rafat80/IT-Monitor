import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);

    // Create admin user for repository operations
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 2 — DeviceRepository & Import Integration Tests', () {
    test('1. Add, fetch, update, toggle and delete device', () async {
      final device = DeviceEntity(
        id: 0,
        name: 'PC-TEST-01',
        type: DeviceType.pc,
        ip: '192.168.1.100',
        ownerName: 'Test Owner',
        department: 'Finance',
        officeLocation: 'Floor 3',
        createdAt: DateTime.now(),
      );

      // Add Device
      final addRes = await deviceRepo.addDevice(device);
      expect(addRes.isSuccess, isTrue);
      final added = addRes.dataOrNull!;
      expect(added.id, greaterThan(0));
      expect(added.ownerName, equals('Test Owner'));

      // Fetch Devices
      final getRes = await deviceRepo.getDevices();
      expect(getRes.dataOrNull?.length, equals(1));
      expect(getRes.dataOrNull?.first.ip, equals('192.168.1.100'));

      // Update Device
      final updatedDevice = added.copyWith(ownerName: 'Updated Owner Name');
      final updateRes = await deviceRepo.updateDevice(updatedDevice);
      expect(updateRes.isSuccess, isTrue);
      expect(updateRes.dataOrNull?.ownerName, equals('Updated Owner Name'));

      // Toggle Monitoring
      final toggleRes = await deviceRepo.toggleDeviceMonitoring(
        deviceId: added.id,
        isEnabled: false,
      );
      expect(toggleRes.isSuccess, isTrue);

      final fetchedAfterToggle = await deviceRepo.getDeviceById(added.id);
      expect(fetchedAfterToggle.dataOrNull?.isEnabled, isFalse);

      // Delete Device
      final deleteRes = await deviceRepo.deleteDevice(added.id);
      expect(deleteRes.isSuccess, isTrue);

      final finalGet = await deviceRepo.getDevices();
      expect(finalGet.dataOrNull?.length, equals(0));
    });

    test(
      '2. Inventory CSV parsing, validation preview and batch commit',
      () async {
        const csvData = '''
Owner,Department,Device Name,IP,Office,Switch
Ahmed Mohamed,Finance,PC-FIN-01,192.168.2.10,Floor 2,SW-FL2
Sara Ali,HR,LT-HR-02,192.168.2.11,Floor 1,SW-FL1
Duplicate User 1,IT,PC-DUP-01,192.168.2.99,Floor 3,SW-FL3
Duplicate User 2,Sales,PC-DUP-02,192.168.2.99,Floor 3,SW-FL3
''';

        final bytes = csvData.codeUnits;

        // Parse and Validate
        final previewRes = await deviceRepo.parseAndValidateImport(
          bytes,
          'inventory.csv',
        );
        expect(previewRes.isSuccess, isTrue);

        final preview = previewRes.dataOrNull!;
        expect(preview.totalRowsProcessed, equals(4));

        // Duplicate IP 192.168.2.99 must be rejected for both entries
        expect(preview.validCount, equals(2));
        expect(preview.excludedDuplicateIps, contains('192.168.2.99'));

        // Commit valid devices to DB
        final commitRes = await deviceRepo.commitImport(preview.validDevices);
        expect(commitRes.isSuccess, isTrue);
        expect(commitRes.dataOrNull, equals(2));

        // Verify committed devices exist in DB
        final dbDevicesRes = await deviceRepo.getDevices();
        expect(dbDevicesRes.dataOrNull?.length, equals(2));
        expect(
          dbDevicesRes.dataOrNull?.map((d) => d.ownerName),
          containsAll(['Ahmed Mohamed', 'Sara Ali']),
        );

        // Verify Audit Log recorded INVENTORY_IMPORTED
        final logs = await db.select(db.auditLogs).get();
        expect(logs.any((l) => l.action == 'INVENTORY_IMPORTED'), isTrue);
      },
    );

    test('3. addDevice rejects duplicate IP address', () async {
      final dev1 = DeviceEntity(
        id: 0,
        name: 'PC-PRIMARY',
        type: DeviceType.pc,
        ip: '192.168.10.50',
        ownerName: 'Primary User',
        department: 'Operations',
        officeLocation: 'Main Office',
        createdAt: DateTime.now(),
      );

      final add1 = await deviceRepo.addDevice(dev1);
      expect(add1.isSuccess, isTrue);

      final dev2 = DeviceEntity(
        id: 0,
        name: 'PC-COLLISION',
        type: DeviceType.pc,
        ip: '192.168.10.50', // Same IP
        ownerName: 'Colliding User',
        department: 'Support',
        officeLocation: 'Helpdesk',
        createdAt: DateTime.now(),
      );

      final add2 = await deviceRepo.addDevice(dev2);
      expect(add2.isFailure, isTrue);
      expect(add2.failureOrNull?.message, contains('already exists'));
    });

    test(
      '4. updateDevice rejects collision with another device IP, but permits keeping own IP',
      () async {
        final dev1 = (await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-01',
            type: DeviceType.pc,
            ip: '192.168.10.51',
            ownerName: 'User One',
            department: 'Finance',
            officeLocation: 'Room 1',
            createdAt: DateTime.now(),
          ),
        )).dataOrNull!;

        final dev2 = (await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-02',
            type: DeviceType.pc,
            ip: '192.168.10.52',
            ownerName: 'User Two',
            department: 'Finance',
            officeLocation: 'Room 2',
            createdAt: DateTime.now(),
          ),
        )).dataOrNull!;

        expect(dev1.id, greaterThan(0));

        // Attempt to change dev2's IP to dev1's IP: must fail
        final collidingUpdate = dev2.copyWith(ip: dev1.ip);
        final updateFail = await deviceRepo.updateDevice(collidingUpdate);
        expect(updateFail.isFailure, isTrue);
        expect(updateFail.failureOrNull?.message, contains('already exists'));

        // Update dev2's owner and office while keeping its own IP: must succeed
        final validUpdate = dev2.copyWith(
          ownerName: 'User Two Renamed',
          officeLocation: 'Room 2B',
        );
        final updateSuccess = await deviceRepo.updateDevice(validUpdate);
        expect(updateSuccess.isSuccess, isTrue);
        expect(updateSuccess.dataOrNull?.ownerName, equals('User Two Renamed'));
      },
    );

    test(
      '5. Database persistence boundary enforces unique IP index on devices table',
      () async {
        final now = DateTime.now();

        // Insert directly via Drift into db.devices
        await db
            .into(db.devices)
            .insert(
              DevicesCompanion.insert(
                name: 'PC-DIRECT-1',
                type: const Value('pc'),
                ip: '10.50.0.1',
                ownerName: 'Owner 1',
                department: 'IT',
                createdAt: Value(now),
              ),
            );

        // A second insert with the identical IP directly bypassing repo pre-checks must throw SqliteException
        expect(
          () async => await db
              .into(db.devices)
              .insert(
                DevicesCompanion.insert(
                  name: 'PC-DIRECT-2',
                  type: const Value('pc'),
                  ip: '10.50.0.1',
                  ownerName: 'Owner 2',
                  department: 'IT',
                  createdAt: Value(now),
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
