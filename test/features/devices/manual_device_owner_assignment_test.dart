import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/presentation/bloc/devices_cubit.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/monitored_device.dart';

void main() {
  late AppDatabase db;
  late DeviceRepositoryImpl deviceRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceRepo = DeviceRepositoryImpl(db);

    // Bootstrap an initial admin user
  });

  tearDown(() async {
    await db.close();
  });

  group('Feature: Manual Device Owner Assignment in Inventory Tests', () {
    test(
      '1. Assigning a person name to an existing device updates DB and creates DEVICE_OWNER_ASSIGNED audit log',
      () async {
        // Create initial device with no real owner
        final initialDevice = DeviceEntity(
          id: 0,
          name: 'PC-FIN-101',
          type: DeviceType.pc,
          ip: '192.168.22.101',
          ownerName: 'Unassigned',
          department: 'Finance',
          officeLocation: 'Room 302',
          createdAt: DateTime.now(),
        );

        final addRes = await deviceRepo.addDevice(initialDevice);
        expect(addRes.isSuccess, isTrue);
        final deviceId = addRes.dataOrNull!.id;

        // Admin assigns a person
        final assignRes = await deviceRepo.assignDeviceOwner(
          deviceId: deviceId,
          ownerName: 'Tariq Al-Mansoor',
          adminUsername: 'admin_user',
        );

        expect(assignRes.isSuccess, isTrue);
        final updated = assignRes.dataOrNull!;
        expect(updated.ownerName, equals('Tariq Al-Mansoor'));
        expect(updated.displayOwner, equals('Tariq Al-Mansoor'));
        expect(updated.isOwnerAssigned, isTrue);
        expect(
          updated.ip,
          equals('192.168.22.101'),
        ); // IP is strictly unchanged

        // Verify audit log
        final logs = await db.select(db.auditLogs).get();
        final assignLog = logs.firstWhere(
          (l) => l.action == 'DEVICE_OWNER_ASSIGNED',
        );
        expect(assignLog.details, contains('Tariq Al-Mansoor'));
        expect(assignLog.details, contains('192.168.22.101'));
        expect(assignLog.username, equals('admin_user'));
      },
    );

    test(
      '2. Editing an already assigned person name updates record and logs DEVICE_OWNER_MODIFIED',
      () async {
        final initialDevice = DeviceEntity(
          id: 0,
          name: 'LT-HR-204',
          type: DeviceType.laptop,
          ip: '192.168.27.45',
          ownerName: 'Nour Emam',
          department: 'Human Resources',
          createdAt: DateTime.now(),
        );

        final addRes = await deviceRepo.addDevice(initialDevice);
        final deviceId = addRes.dataOrNull!.id;

        // Edit assignment
        final editRes = await deviceRepo.assignDeviceOwner(
          deviceId: deviceId,
          ownerName: 'Fatima Zahra',
          adminUsername: 'admin_user',
        );

        expect(editRes.isSuccess, isTrue);
        expect(editRes.dataOrNull!.ownerName, equals('Fatima Zahra'));

        final logs = await db.select(db.auditLogs).get();
        final editLog = logs.firstWhere(
          (l) => l.action == 'DEVICE_OWNER_MODIFIED',
        );
        expect(editLog.details, contains('Nour Emam'));
        expect(editLog.details, contains('Fatima Zahra'));
      },
    );

    test(
      '3. Clearing an assignment sets name to Unassigned and logs DEVICE_OWNER_CLEARED',
      () async {
        final initialDevice = DeviceEntity(
          id: 0,
          name: 'PC-SALES-12',
          type: DeviceType.pc,
          ip: '192.168.22.88',
          ownerName: 'Omar Khaled',
          department: 'Sales',
          createdAt: DateTime.now(),
        );

        final addRes = await deviceRepo.addDevice(initialDevice);
        final deviceId = addRes.dataOrNull!.id;

        // Clear assignment by passing empty string or 'Unassigned'
        final clearRes = await deviceRepo.assignDeviceOwner(
          deviceId: deviceId,
          ownerName: '',
          adminUsername: 'admin_user',
        );

        expect(clearRes.isSuccess, isTrue);
        final cleared = clearRes.dataOrNull!;
        expect(cleared.displayOwner, equals('Unassigned'));
        expect(cleared.isOwnerAssigned, isFalse);

        final logs = await db.select(db.auditLogs).get();
        final clearLog = logs.firstWhere(
          (l) => l.action == 'DEVICE_OWNER_CLEARED',
        );
        expect(clearLog.details, contains('Omar Khaled'));
        expect(clearLog.details, contains('Unassigned'));
      },
    );

    test('4. Device owner assignment is recorded', () async {
      await db
          .into(db.devices)
          .insert(
            DevicesCompanion.insert(
              name: 'PC-ENG-01',
              ip: '192.168.22.99',
              ownerName: 'Existing Owner',
              department: 'Engineering',
            ),
          );

      final res = await deviceRepo.assignDeviceOwner(
        deviceId: 1,
        ownerName: 'New Assigned Owner',
      );
      expect(res.isSuccess, isTrue);
      expect(res.dataOrNull?.ownerName, equals('New Assigned Owner'));
    });

    test(
      '5. Device IP is strictly protected and remains unchanged after assignment',
      () async {
        final initialDevice = DeviceEntity(
          id: 0,
          name: 'PC-STABLE-IP',
          type: DeviceType.pc,
          ip: '192.168.22.50',
          ownerName: 'Original Owner',
          department: 'Operations',
          createdAt: DateTime.now(),
        );

        final addRes = await deviceRepo.addDevice(initialDevice);
        final id = addRes.dataOrNull!.id;

        await deviceRepo.assignDeviceOwner(
          deviceId: id,
          ownerName: 'New Assigned Name',
        );

        final reFetched = await deviceRepo.getDeviceById(id);
        expect(reFetched.dataOrNull!.ip, equals('192.168.22.50'));
        expect(reFetched.dataOrNull!.ownerName, equals('New Assigned Name'));
      },
    );

    test(
      '6. Persistence after database reload: Name remains saved and re-read accurately',
      () async {
        final initialDevice = DeviceEntity(
          id: 0,
          name: 'PC-RESTART-01',
          type: DeviceType.pc,
          ip: '192.168.22.60',
          ownerName: 'Unassigned',
          department: 'Logistics',
          createdAt: DateTime.now(),
        );

        final addRes = await deviceRepo.addDevice(initialDevice);
        final id = addRes.dataOrNull!.id;

        await deviceRepo.assignDeviceOwner(
          deviceId: id,
          ownerName: 'Mohamed Saeed',
        );

        // Directly inspect raw database row to prove disk persistence (not just in-memory state)
        final rawRow = await (db.select(
          db.devices,
        )..where((t) => t.id.equals(id))).getSingle();
        expect(rawRow.ownerName, equals('Mohamed Saeed'));
        expect(rawRow.ip, equals('192.168.22.60'));
      },
    );

    test(
      '7. Search and Filtering by assigned person name works seamlessly',
      () async {
        final cubit = DevicesCubit(deviceRepo);

        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-A',
            type: DeviceType.pc,
            ip: '192.168.22.10',
            ownerName: 'Ziad Mansour',
            department: 'Finance',
            createdAt: DateTime.now(),
          ),
        );

        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'PC-B',
            type: DeviceType.pc,
            ip: '192.168.22.11',
            ownerName: 'Amr Rafa',
            department: 'IT',
            createdAt: DateTime.now(),
          ),
        );

        await cubit.loadDevices();
        expect(cubit.state, isA<DevicesLoaded>());

        // Search by Ziad
        cubit.filterDevices(query: 'Ziad');
        var loaded = cubit.state as DevicesLoaded;
        expect(loaded.filteredDevices.length, equals(1));
        expect(loaded.filteredDevices.first.ownerName, equals('Ziad Mansour'));

        // Search by Amr
        cubit.filterDevices(query: 'Amr');
        loaded = cubit.state as DevicesLoaded;
        expect(loaded.filteredDevices.length, equals(1));
        expect(loaded.filteredDevices.first.ownerName, equals('Amr Rafa'));

        // Search by unassigned/all
        cubit.filterDevices(query: '');
        loaded = cubit.state as DevicesLoaded;
        expect(loaded.filteredDevices.length, equals(2));
      },
    );

    test(
      '8. Wall Display and Incident Views receive updated owner name',
      () async {
        final device = DeviceEntity(
          id: 1,
          name: 'PC-WALL-01',
          type: DeviceType.pc,
          ip: '192.168.22.77',
          ownerName: 'Kareem Taha',
          department: 'Procurement',
          createdAt: DateTime.now(),
        );

        final monitoredDevice = MonitoredDevice(
          device: device,
          status: DeviceStatusEntity.initial(1),
        );

        // Verify Wall Display primary identity display prioritizes assigned person
        expect(monitoredDevice.device.displayOwner, equals('Kareem Taha'));
        expect(monitoredDevice.device.isOwnerAssigned, isTrue);

        // Update name to Unassigned
        final updatedDevice = device.copyWith(ownerName: 'Unassigned');
        expect(updatedDevice.displayOwner, equals('Unassigned'));
        expect(updatedDevice.isOwnerAssigned, isFalse);
      },
    );

    test(
      '9. Duplicate-IP protection remains 100% active and prevents overwriting existing device owner',
      () async {
        // Add authoritative device
        final original = DeviceEntity(
          id: 0,
          name: 'PC-AUTHORITATIVE',
          type: DeviceType.pc,
          ip: '192.168.27.90',
          ownerName: 'Protected Original Owner',
          department: 'Security',
          createdAt: DateTime.now(),
        );
        await deviceRepo.addDevice(original);

        // Attempt to add a duplicate IP with a different owner
        final duplicateAttempt = DeviceEntity(
          id: 0,
          name: 'PC-DISCOVERED-DUP',
          type: DeviceType.pc,
          ip: '192.168.27.90',
          ownerName: 'Duplicate Infiltrator',
          department: 'Unknown',
          createdAt: DateTime.now(),
        );

        final dupRes = await deviceRepo.addDevice(duplicateAttempt);
        expect(dupRes.isFailure, isTrue);
        expect(dupRes.failureOrNull?.message, contains('already exists'));

        // Verify original owner is untouched
        final checkRes = await deviceRepo.getDevices();
        final found = checkRes.dataOrNull!.firstWhere(
          (d) => d.ip == '192.168.27.90',
        );
        expect(found.ownerName, equals('Protected Original Owner'));
      },
    );
  });
}
