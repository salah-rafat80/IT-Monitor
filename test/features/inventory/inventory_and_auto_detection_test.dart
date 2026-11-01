import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/factories/data/repositories/factory_repository_impl.dart';
import 'package:it_network_monitor/features/factories/domain/services/network_detection_service.dart';
import 'package:it_network_monitor/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:it_network_monitor/features/incidents/domain/entities/incident_entity.dart';
import 'package:it_network_monitor/features/inventory/domain/services/excel_inventory_service.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/check_result.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';

extension ResultTestX<T> on Result<T> {
  T get value => (this as Success<T>).data;
}

void main() {
  group('16 Regression Tests: Inventory Management & Automatic Factory Detection', () {
    late AppDatabase db;
    late AuditLogRepositoryImpl auditRepo;
    late AuthRepositoryImpl authRepo;
    late FactoryRepositoryImpl factoryRepo;
    late DeviceRepositoryImpl deviceRepo;
    late IncidentRepositoryImpl incidentRepo;
    late MonitoringRepositoryImpl monitoringRepo;
    late ExcelInventoryService excelService;

    setUp(() async {
      AppConfig.enforceReleaseModeSecurity = false;
      AppConfig.resetForTesting(mode: AppRunMode.standaloneDevelopment);

      db = AppDatabase.forTesting(NativeDatabase.memory());
      final migrator = db.createMigrator();
      await migrator.createAll();
      await db.ensureDefaultFactoriesSeeded();

      auditRepo = AuditLogRepositoryImpl(db);
      authRepo = AuthRepositoryImpl(db, auditRepo);
      await authRepo.createInitialAdmin(
        username: 'admin',
        password: 'Password123',
      );

      factoryRepo = FactoryRepositoryImpl(db);
      deviceRepo = DeviceRepositoryImpl(db, auditRepo, authRepo);
      incidentRepo = IncidentRepositoryImpl(db, auditRepo);
      monitoringRepo = MonitoringRepositoryImpl(db);
      excelService = ExcelInventoryServiceImpl();
    });

    tearDown(() async {
      await db.close();
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 1. RNF Automatically Detected from RNF LAN Address
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 1: RNF automatically detected from an RNF LAN address (e.g. 192.168.22.50)',
      () async {
        final factoriesRes = await factoryRepo.getFactories();
        expect(factoriesRes.isSuccess, isTrue);
        final factories = factoriesRes.value;

        final detectionService = NetworkDetectionServiceImpl();
        final result = await detectionService.detectFactory(
          factories: factories,
          mockLocalIps: ['192.168.22.50'],
        );

        expect(result.status, equals(FactoryDetectionStatus.detected));
        expect(result.detectedFactory?.id, equals('rnf'));
        expect(result.matchedIps, contains('192.168.22.50'));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 2. BNF Automatically Detected from BNF LAN Address
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 2: BNF automatically detected from a BNF LAN address (e.g. 192.168.21.50)',
      () async {
        final factoriesRes = await factoryRepo.getFactories();
        final factories = factoriesRes.value;

        final detectionService = NetworkDetectionServiceImpl();
        final result = await detectionService.detectFactory(
          factories: factories,
          mockLocalIps: ['192.168.21.50'],
        );

        expect(result.status, equals(FactoryDetectionStatus.detected));
        expect(result.detectedFactory?.id, equals('bnf'));
        expect(result.matchedIps, contains('192.168.21.50'));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Unknown Network Requires Manual Selection (No Silent Default)
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 3: Unknown network requires manual selection (no silent default)',
      () async {
        final factoriesRes = await factoryRepo.getFactories();
        final factories = factoriesRes.value;

        final detectionService = NetworkDetectionServiceImpl();
        // External or foreign LAN address
        final result = await detectionService.detectFactory(
          factories: factories,
          mockLocalIps: ['10.10.50.100', '127.0.0.1', '169.254.1.2'],
        );

        expect(result.status, equals(FactoryDetectionStatus.unknown));
        expect(result.detectedFactory, isNull);
        expect(result.isAmbiguous, isFalse);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Ambiguous Network Does Not Silently Select a Factory
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 4: Ambiguous network (multi-homed/VPN) does not silently select a factory',
      () async {
        final factoriesRes = await factoryRepo.getFactories();
        final factories = factoriesRes.value;

        final detectionService = NetworkDetectionServiceImpl();
        // Has interfaces on both RNF and BNF networks
        final result = await detectionService.detectFactory(
          factories: factories,
          mockLocalIps: ['192.168.21.25', '192.168.22.25'],
        );

        expect(result.status, equals(FactoryDetectionStatus.ambiguous));
        expect(result.detectedFactory, isNull);
        expect(result.isAmbiguous, isTrue);
        expect(
          result.candidateFactories.map((f) => f.id).toList(),
          containsAll(['bnf', 'rnf']),
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 5. RNF Inventory Does Not Display BNF Records
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 5: RNF inventory does not display BNF records', () async {
      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'RNF-PC-01',
          ip: '192.168.22.10',
          type: DeviceType.pc,
          factoryId: 'rnf',
          department: 'IT',
          ownerName: 'Salah RNF',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );

      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'BNF-PC-01',
          ip: '192.168.21.10',
          type: DeviceType.pc,
          factoryId: 'bnf',
          department: 'Finance',
          ownerName: 'Ahmed BNF',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );

      final rnfDevicesRes = await deviceRepo.getDevices(factoryId: 'rnf');
      expect(rnfDevicesRes.isSuccess, isTrue);
      final rnfDevices = rnfDevicesRes.value;

      expect(rnfDevices.length, equals(1));
      expect(rnfDevices.first.name, equals('RNF-PC-01'));
      expect(rnfDevices.any((d) => d.name == 'BNF-PC-01'), isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 6. BNF Inventory Does Not Display RNF Records
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 6: BNF inventory does not display RNF records', () async {
      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'RNF-Server-01',
          ip: '192.168.22.20',
          type: DeviceType.server,
          factoryId: 'rnf',
          department: 'IT',
          ownerName: 'Admin RNF',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );

      await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'BNF-Server-01',
          ip: '192.168.21.20',
          type: DeviceType.server,
          factoryId: 'bnf',
          department: 'IT',
          ownerName: 'Admin BNF',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );

      final bnfDevicesRes = await deviceRepo.getDevices(factoryId: 'bnf');
      expect(bnfDevicesRes.isSuccess, isTrue);
      final bnfDevices = bnfDevicesRes.value;

      expect(bnfDevices.length, equals(1));
      expect(bnfDevices.first.name, equals('BNF-Server-01'));
      expect(bnfDevices.any((d) => d.name == 'RNF-Server-01'), isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 7. Same IP Can Exist in Both Factories
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 7: Same IP can exist in both factories without conflict',
      () async {
        const sharedIp = '10.0.0.50';

        final dev1Res = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'RNF Device Shared IP',
            ip: sharedIp,
            type: DeviceType.pc,
            factoryId: 'rnf',
            department: 'Operations',
            ownerName: 'Owner RNF',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        expect(dev1Res.isSuccess, isTrue);

        final dev2Res = await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'BNF Device Shared IP',
            ip: sharedIp,
            type: DeviceType.printer,
            factoryId: 'bnf',
            department: 'Logistics',
            ownerName: 'Owner BNF',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );
        expect(dev2Res.isSuccess, isTrue);

        expect(dev1Res.value.id, isNot(equals(dev2Res.value.id)));
        expect(dev1Res.value.factoryId, equals('rnf'));
        expect(dev2Res.value.factoryId, equals('bnf'));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 8. Duplicate IP Within One Factory is Rejected
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 8: Duplicate IP within one factory is rejected', () async {
      const duplicateIp = '192.168.22.33';

      final firstRes = await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'Device Alpha',
          ip: duplicateIp,
          type: DeviceType.pc,
          factoryId: 'rnf',
          department: 'IT',
          ownerName: 'User One',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );
      expect(firstRes.isSuccess, isTrue);

      // Attempting to add same IP into same factory 'rnf'
      final secondRes = await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'Device Beta Duplicate',
          ip: duplicateIp,
          type: DeviceType.laptop,
          factoryId: 'rnf',
          department: 'HR',
          ownerName: 'User Two',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );
      expect(secondRes.isSuccess, isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 9. Direct Cell Editing Persists Correctly
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 9: Direct cell editing persists correctly', () async {
      final addRes = await deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: 'Original Name',
          ip: '192.168.22.40',
          type: DeviceType.pc,
          factoryId: 'rnf',
          department: 'Original Dept',
          ownerName: 'Original Owner',
          officeLocation: 'Room 101',
          vendor: 'Dell',
          model: 'OptiPlex 7080',
          isMonitored: true,
          isEnabled: true,
          createdAt: DateTime.now(),
        ),
      );
      expect(addRes.isSuccess, isTrue);
      final created = addRes.value;

      // Inline edits saved
      final edited = created.copyWith(
        name: 'Updated Name',
        department: 'Updated Dept',
        ownerName: 'New Owner Name',
        officeLocation: 'Room 202',
        vendor: 'HP',
        model: 'EliteDesk 800',
        isMonitored: false,
      );

      final updateRes = await deviceRepo.updateDevice(edited);
      expect(updateRes.isSuccess, isTrue);

      // Re-fetch from DB
      final fetchRes = await deviceRepo.getDeviceById(created.id);
      expect(fetchRes.isSuccess, isTrue);
      final updatedDb = fetchRes.value;

      expect(updatedDb.name, equals('Updated Name'));
      expect(updatedDb.department, equals('Updated Dept'));
      expect(updatedDb.ownerName, equals('New Owner Name'));
      expect(updatedDb.officeLocation, equals('Room 202'));
      expect(updatedDb.vendor, equals('HP'));
      expect(updatedDb.model, equals('EliteDesk 800'));
      expect(updatedDb.isMonitored, isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // 10. Adding and Deleting Inventory Rows Works Safely
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 10: Adding and deleting inventory rows works safely',
      () async {
        final dev1 = (await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Dev to Delete',
            ip: '192.168.22.61',
            type: DeviceType.pc,
            factoryId: 'rnf',
            department: 'IT',
            ownerName: 'Owner 1',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        )).value;

        final dev2 = (await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Dev to Keep',
            ip: '192.168.22.62',
            type: DeviceType.laptop,
            factoryId: 'rnf',
            department: 'Finance',
            ownerName: 'Owner 2',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        )).value;

        final delRes = await deviceRepo.deleteDevices([dev1.id]);
        expect(delRes.isSuccess, isTrue);
        expect(delRes.value, equals(1));

        final allRnf = (await deviceRepo.getDevices(factoryId: 'rnf')).value;
        expect(allRnf.any((d) => d.id == dev1.id), isFalse);
        expect(allRnf.any((d) => d.id == dev2.id), isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 11. Excel Import Assigns Records to the Selected Factory
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 11: Excel import assigns records to the selected factory',
      () async {
        const tsvContent =
            'Owner Name\tDepartment\tDevice Name\tIP Address\tType\tLocation\n'
            'Zaid BNF\tEngineering\tBNF-CAD-01\t192.168.21.70\tPC\tBuilding A';

        final summary = excelService.parseTabularTsv(
          tsvText: tsvContent,
          targetFactoryId: 'bnf',
          existingFactoryDevices: [],
        );

        expect(summary.validDevices.length, equals(1));
        expect(summary.validDevices.first.factoryId, equals('bnf'));

        final commitRes = await deviceRepo.commitImport(summary.validDevices);
        expect(commitRes.isSuccess, isTrue);

        final bnfDevices = (await deviceRepo.getDevices(
          factoryId: 'bnf',
        )).value;
        expect(
          bnfDevices.any((d) => d.name == 'BNF-CAD-01' && d.factoryId == 'bnf'),
          isTrue,
        );

        // Verify not in RNF
        final rnfDevices = (await deviceRepo.getDevices(
          factoryId: 'rnf',
        )).value;
        expect(rnfDevices.any((d) => d.name == 'BNF-CAD-01'), isFalse);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 12. Excel Import Does Not Delete Records Omitted From the File
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 12: Excel import does not delete records omitted from the file',
      () async {
        // Pre-existing devices
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Existing Device A',
            ip: '192.168.22.81',
            type: DeviceType.pc,
            factoryId: 'rnf',
            department: 'IT',
            ownerName: 'Owner A',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );

        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Existing Device B',
            ip: '192.168.22.82',
            type: DeviceType.printer,
            factoryId: 'rnf',
            department: 'IT',
            ownerName: 'Owner B',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );

        // File containing only Device C (Device A and B omitted)
        const tsvContent =
            'Owner Name\tDepartment\tDevice Name\tIP Address\n'
            'Owner C\tHR\tNew Device C\t192.168.22.83';

        final summary = excelService.parseTabularTsv(
          tsvText: tsvContent,
          targetFactoryId: 'rnf',
          existingFactoryDevices: (await deviceRepo.getDevices(
            factoryId: 'rnf',
          )).value,
        );

        await deviceRepo.commitImport(summary.validDevices);

        final rnfList = (await deviceRepo.getDevices(factoryId: 'rnf')).value;
        expect(rnfList.any((d) => d.name == 'Existing Device A'), isTrue);
        expect(rnfList.any((d) => d.name == 'Existing Device B'), isTrue);
        expect(rnfList.any((d) => d.name == 'New Device C'), isTrue);
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 13. Export Contains Only the Selected Factory's Records
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 13: Export contains only the selected factory records',
      () async {
        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Device For RNF',
            ip: '192.168.22.91',
            type: DeviceType.pc,
            factoryId: 'rnf',
            department: 'IT',
            ownerName: 'RNF Owner',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );

        await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Device For BNF',
            ip: '192.168.21.91',
            type: DeviceType.pc,
            factoryId: 'bnf',
            department: 'Sales',
            ownerName: 'BNF Owner',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        );

        final rnfOnly = (await deviceRepo.getDevices(factoryId: 'rnf')).value;
        final tsv = excelService.exportToTsv(rnfOnly);

        expect(tsv, contains('Device For RNF'));
        expect(tsv, contains('192.168.22.91'));
        expect(tsv, isNot(contains('Device For BNF')));
        expect(tsv, isNot(contains('192.168.21.91')));
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 14. Unassigned Records Remain Visible and Can Be Assigned
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 14: Unassigned records remain visible and can be assigned',
      () async {
        final unassignedDev = (await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Legacy Device',
            ip: '192.168.22.105',
            type: DeviceType.pc,
            factoryId: 'unassigned',
            department: 'Legacy Dept',
            ownerName: 'Legacy Owner',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        )).value;

        // Verify visible in unassigned inventory
        final unassignedList = (await deviceRepo.getDevices(
          factoryId: 'unassigned',
        )).value;
        expect(unassignedList.any((d) => d.id == unassignedDev.id), isTrue);

        // Assign to RNF
        final assignRes = await deviceRepo.reassignDevicesFactory(
          deviceIds: [unassignedDev.id],
          targetFactoryId: 'rnf',
        );
        expect(assignRes.isSuccess, isTrue);

        // Verify no longer unassigned
        final updatedUnassigned = (await deviceRepo.getDevices(
          factoryId: 'unassigned',
        )).value;
        expect(updatedUnassigned.any((d) => d.id == unassignedDev.id), isFalse);

        // Verify now in RNF
        final rnfList = (await deviceRepo.getDevices(factoryId: 'rnf')).value;
        expect(
          rnfList.any((d) => d.id == unassignedDev.id && d.factoryId == 'rnf'),
          isTrue,
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 15. Assignment Preserves Device IDs and Existing Relationships
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 15: Assignment preserves device IDs and check/incident relationships',
      () async {
        final dev = (await deviceRepo.addDevice(
          DeviceEntity(
            id: 0,
            name: 'Critical Switch',
            ip: '192.168.21.110',
            type: DeviceType.switchDevice,
            factoryId: 'unassigned',
            department: 'Infrastructure',
            ownerName: 'NetAdmin',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          ),
        )).value;

        // Add a check result for this device
        await monitoringRepo.saveCheckResult(
          CheckResult(
            deviceId: dev.id,
            targetIp: dev.ip,
            timestamp: DateTime.now(),
            latencyMs: 15,
            isSuccess: true,
            factoryId: 'unassigned',
          ),
        );

        // Add an incident for this device
        final incRes = await incidentRepo.createIncident(
          IncidentEntity(
            id: 0,
            deviceId: dev.id,
            deviceName: dev.name,
            deviceIp: dev.ip,
            ownerName: dev.ownerName,
            department: dev.department,
            incidentType: IncidentTypeEnum.deviceDown,
            severity: IncidentSeverityEnum.critical,
            status: IncidentStatusEnum.active,
            startedAt: DateTime.now(),
            factoryId: 'unassigned',
          ),
        );
        expect(incRes.isSuccess, isTrue);

        // Reassign to BNF
        final reassignRes = await deviceRepo.reassignDevicesFactory(
          deviceIds: [dev.id],
          targetFactoryId: 'bnf',
        );
        expect(reassignRes.isSuccess, isTrue);

        // Verify device ID remains identical
        final devAfter = (await deviceRepo.getDeviceById(dev.id)).value;
        expect(devAfter.id, equals(dev.id));
        expect(devAfter.factoryId, equals('bnf'));
        expect(devAfter.name, equals('Critical Switch'));
        expect(devAfter.department, equals('Infrastructure'));

        // Verify incidents still linked and updated to bnf
        final incs = (await incidentRepo.getActiveIncidents(
          factoryId: 'bnf',
        )).value;
        expect(
          incs.any((i) => i.deviceId == dev.id && i.factoryId == 'bnf'),
          isTrue,
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────────────
    // 16. Existing Inventory Survives Database Migration
    // ──────────────────────────────────────────────────────────────────────────
    test(
      'Scenario 16: Existing inventory survives database migration (v13 network fields & factories)',
      () async {
        final factories = (await factoryRepo.getFactories()).value;

        final rnfFactory = factories.firstWhere((f) => f.id == 'rnf');
        expect(rnfFactory.gatewayIp, equals('192.168.22.1'));
        expect(rnfFactory.subnetMask, equals('255.255.255.0'));
        expect(rnfFactory.expectedCidr, equals('192.168.22.0/24'));

        final bnfFactory = factories.firstWhere((f) => f.id == 'bnf');
        expect(bnfFactory.gatewayIp, equals('192.168.21.1'));
        expect(bnfFactory.subnetMask, equals('255.255.255.0'));
        expect(bnfFactory.expectedCidr, equals('192.168.21.0/24'));

        // Verify schema version is at least 13
        expect(db.schemaVersion, equals(13));
      },
    );
  });
}
