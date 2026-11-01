import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/utils/result.dart';
import 'package:it_network_monitor/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:it_network_monitor/features/auth/domain/repositories/auth_repository.dart';
import 'package:it_network_monitor/features/devices/data/repositories/device_repository_impl.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_import_commit_payload.dart';
import 'package:it_network_monitor/features/devices/domain/repositories/device_repository.dart';
import 'package:it_network_monitor/features/factories/data/repositories/factory_repository_impl.dart';
import 'package:it_network_monitor/features/factories/domain/repositories/factory_repository.dart';
import 'package:it_network_monitor/features/inventory/domain/services/excel_inventory_service.dart';
import 'package:it_network_monitor/features/monitoring/data/datasources/monitoring_service_client.dart';
import 'package:it_network_monitor/features/monitoring/data/repositories/monitoring_repository_impl.dart';
import 'package:it_network_monitor/features/monitoring/domain/repositories/monitoring_repository.dart';
import 'package:it_network_monitor/features/monitoring/presentation/services/monitoring_service_server.dart';
import 'package:it_network_monitor/features/users/data/repositories/audit_log_repository_impl.dart';
import 'package:it_network_monitor/features/users/domain/repositories/audit_log_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Issues 1, 2, 4: Excel Import UPDATE, Template Sample Data, and File Type Handling',
    () {
      late AppDatabase db;
      late AuditLogRepositoryImpl auditRepo;
      late AuthRepositoryImpl authRepo;
      late FactoryRepositoryImpl factoryRepo;
      late DeviceRepositoryImpl deviceRepo;
      late MonitoringRepositoryImpl monitoringRepo;
      late ExcelInventoryServiceImpl excelService;

      setUp(() async {
        HttpOverrides.global = null;
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
        monitoringRepo = MonitoringRepositoryImpl(db);
        excelService = ExcelInventoryServiceImpl();
      });

      tearDown(() async {
        await db.close();
      });

      // ──────────────────────────────────────────────────────────────────────────
      // Issue 1: Excel Import UPDATE vs INSERT Behavior
      // ──────────────────────────────────────────────────────────────────────────
      test(
        '1.1: INSERT creates new device with new ID; UPDATE updates existing device preserving ID',
        () async {
          // 1. Seed existing device in RNF
          final existingRes = await deviceRepo.addDevice(
            DeviceEntity(
              id: 0,
              factoryId: 'rnf',
              name: 'RNF-SRV-01',
              type: DeviceType.server,
              ip: '192.168.22.10',
              ownerName: 'Alice Smith',
              department: 'IT',
              officeLocation: 'Rack A1',
              notes: 'Primary DC',
              isMonitored: true,
              isEnabled: true,
              createdAt: DateTime.now().subtract(const Duration(days: 30)),
            ),
          );
          expect(existingRes.isSuccess, isTrue);
          final existingDev = (existingRes as Success<DeviceEntity>).data;
          final originalId = existingDev.id;
          expect(originalId, greaterThan(0));

          // 2. Prepare payload: 1 INSERT (new IP) and 1 UPDATE (existing device ID & IP)
          final newDevice = DeviceEntity(
            id: 0,
            factoryId: 'rnf',
            name: 'RNF-PRINTER-02',
            type: DeviceType.printer,
            ip: '192.168.22.25',
            ownerName: 'Bob Jones',
            department: 'Operations',
            isMonitored: true,
            isEnabled: true,
            createdAt: DateTime.now(),
          );

          final updatedDevice = existingDev.copyWith(
            name: 'RNF-SRV-01-RENAMED',
            ownerName: 'Alice Updated',
            department: 'IT Infrastructure',
          );

          final payload = DeviceImportCommitPayload(
            inserts: [newDevice],
            updates: [updatedDevice],
            targetFactoryId: 'rnf',
          );

          // 3. Commit import payload
          final commitRes = await deviceRepo.commitImportPayload(payload);
          expect(commitRes.isSuccess, isTrue);
          expect((commitRes as Success<int>).data, equals(2));

          // 4. Verify existing device was updated and did NOT create an extra record
          final allRnfDevices =
              (await deviceRepo.getDevices(factoryId: 'rnf')
                      as Success<List<DeviceEntity>>)
                  .data;
          expect(
            allRnfDevices.length,
            equals(2),
            reason: 'Must contain exactly 1 updated + 1 inserted device',
          );

          final updatedInDb = allRnfDevices.firstWhere(
            (d) => d.id == originalId,
          );
          expect(
            updatedInDb.id,
            equals(originalId),
            reason: 'Existing device ID must be preserved',
          );
          expect(updatedInDb.name, equals('RNF-SRV-01-RENAMED'));
          expect(updatedInDb.ownerName, equals('Alice Updated'));
          expect(updatedInDb.department, equals('IT Infrastructure'));
          expect(
            updatedInDb.officeLocation,
            equals('Rack A1'),
            reason: 'Unchanged fields must be preserved',
          );
          expect(
            updatedInDb.notes,
            equals('Primary DC'),
            reason: 'Notes preserved',
          );

          // 5. Verify new device received new ID
          final newInDb = allRnfDevices.firstWhere(
            (d) => d.ip == '192.168.22.25',
          );
          expect(newInDb.id, isNot(equals(originalId)));
          expect(newInDb.name, equals('RNF-PRINTER-02'));
        },
      );

      test(
        '1.2: Empty spreadsheet cells do not overwrite existing populated database fields',
        () async {
          final existingRes = await deviceRepo.addDevice(
            DeviceEntity(
              id: 0,
              factoryId: 'rnf',
              name: 'RNF-PC-WORKSTATION',
              type: DeviceType.pc,
              ip: '192.168.22.50',
              ownerName: 'Original Owner',
              department: 'Engineering',
              officeLocation: 'Building 2 Floor 3',
              notes: 'Do not clear this note',
              vendor: 'Dell',
              model: 'Precision 3650',
              mac: '00:11:22:33:44:55',
              hostname: 'eng-ws-50',
              operatingSystem: 'Ubuntu 22.04',
              isMonitored: true,
              isEnabled: true,
              createdAt: DateTime.now(),
            ),
          );
          final existingDev = (existingRes as Success<DeviceEntity>).data;

          // Update row with null / blank fields for notes, location, vendor, etc.
          final partialUpdate = DeviceEntity(
            id: existingDev.id,
            factoryId: 'rnf',
            name: 'RNF-PC-WORKSTATION-UPDATED',
            type: DeviceType.pc,
            ip: '192.168.22.50',
            ownerName: 'New Owner',
            department: 'Engineering',
            officeLocation: null, // Empty in spreadsheet
            notes: null, // Empty in spreadsheet
            vendor: null,
            model: null,
            mac: null,
            hostname: null,
            operatingSystem: null,
            createdAt: DateTime.now(),
          );

          final payload = DeviceImportCommitPayload(
            inserts: [],
            updates: [partialUpdate],
            targetFactoryId: 'rnf',
          );

          final res = await deviceRepo.commitImportPayload(payload);
          expect(res.isSuccess, isTrue);

          final reloaded =
              (await deviceRepo.getDeviceById(existingDev.id)
                      as Success<DeviceEntity>)
                  .data;
          expect(reloaded.name, equals('RNF-PC-WORKSTATION-UPDATED'));
          expect(reloaded.ownerName, equals('New Owner'));
          expect(
            reloaded.officeLocation,
            equals('Building 2 Floor 3'),
            reason: 'Non-empty DB value preserved',
          );
          expect(
            reloaded.notes,
            equals('Do not clear this note'),
            reason: 'Non-empty DB note preserved',
          );
          expect(reloaded.vendor, equals('Dell'), reason: 'Vendor preserved');
          expect(
            reloaded.model,
            equals('Precision 3650'),
            reason: 'Model preserved',
          );
          expect(
            reloaded.mac,
            equals('00:11:22:33:44:55'),
            reason: 'MAC preserved',
          );
          expect(
            reloaded.hostname,
            equals('eng-ws-50'),
            reason: 'Hostname preserved',
          );
          expect(
            reloaded.operatingSystem,
            equals('Ubuntu 22.04'),
            reason: 'OS preserved',
          );
        },
      );

      test(
        '1.3: Cross-factory updates are strictly rejected and transaction safely rolled back',
        () async {
          // Create a device belonging to BNF
          final bnfDevRes = await deviceRepo.addDevice(
            DeviceEntity(
              id: 0,
              factoryId: 'bnf',
              name: 'BNF-ROBOT-01',
              type: DeviceType.other,
              ip: '192.168.21.100',
              ownerName: 'Production BNF',
              department: 'Robotics',
              createdAt: DateTime.now(),
            ),
          );
          final bnfDev = (bnfDevRes as Success<DeviceEntity>).data;

          // Try to update this BNF device while importing into targetFactoryId = 'rnf'
          final crossFactoryPayload = DeviceImportCommitPayload(
            inserts: [
              DeviceEntity(
                id: 0,
                factoryId: 'rnf',
                name: 'RNF-NEW-DEV',
                type: DeviceType.pc,
                ip: '192.168.22.99',
                ownerName: 'RNF Staff',
                department: 'IT',
                createdAt: DateTime.now(),
              ),
            ],
            updates: [bnfDev.copyWith(name: 'ILLEGAL-CROSS-FACTORY-NAME')],
            targetFactoryId: 'rnf',
          );

          final res = await deviceRepo.commitImportPayload(crossFactoryPayload);
          expect(res.isFailure, isTrue);
          expect(
            res.failureOrNull?.message,
            contains('cannot be updated under target factory'),
          );

          // Verify transaction rolled back: new device was NOT inserted
          final rnfDevices =
              (await deviceRepo.getDevices(factoryId: 'rnf')
                      as Success<List<DeviceEntity>>)
                  .data;
          expect(rnfDevices.any((d) => d.ip == '192.168.22.99'), isFalse);

          // Verify BNF device was NOT modified
          final bnfDevAfter =
              (await deviceRepo.getDeviceById(bnfDev.id)
                      as Success<DeviceEntity>)
                  .data;
          expect(bnfDevAfter.name, equals('BNF-ROBOT-01'));
        },
      );

      test(
        '1.4: Duplicate IP addresses within import payload are rejected before commit',
        () async {
          final payload = DeviceImportCommitPayload(
            inserts: [
              DeviceEntity(
                id: 0,
                factoryId: 'rnf',
                name: 'Device A',
                type: DeviceType.pc,
                ip: '192.168.22.30',
                ownerName: 'User A',
                department: 'IT',
                createdAt: DateTime.now(),
              ),
              DeviceEntity(
                id: 0,
                factoryId: 'rnf',
                name: 'Device B',
                type: DeviceType.pc,
                ip: '192.168.22.30', // Duplicate IP!
                ownerName: 'User B',
                department: 'IT',
                createdAt: DateTime.now(),
              ),
            ],
            updates: [],
            targetFactoryId: 'rnf',
          );

          final res = await deviceRepo.commitImportPayload(payload);
          expect(res.isFailure, isTrue);
          expect(res.failureOrNull?.message, contains('Duplicate IP'));

          final rnfDevices =
              (await deviceRepo.getDevices(factoryId: 'rnf')
                      as Success<List<DeviceEntity>>)
                  .data;
          expect(rnfDevices.isEmpty, isTrue);
        },
      );

      test(
        '1.5: Authoritative Windows Service API (/api/devices/import) processes commit payload with identical semantics',
        () async {
          final getIt = GetIt.instance;
          if (getIt.isRegistered<AppDatabase>())
            await getIt.unregister<AppDatabase>();
          getIt.registerSingleton<AppDatabase>(db);
          if (getIt.isRegistered<DeviceRepository>())
            await getIt.unregister<DeviceRepository>();
          getIt.registerSingleton<DeviceRepository>(deviceRepo);
          if (getIt.isRegistered<AuthRepository>())
            await getIt.unregister<AuthRepository>();
          getIt.registerSingleton<AuthRepository>(authRepo);
          if (getIt.isRegistered<AuditLogRepository>())
            await getIt.unregister<AuditLogRepository>();
          getIt.registerSingleton<AuditLogRepository>(auditRepo);
          if (getIt.isRegistered<FactoryRepository>())
            await getIt.unregister<FactoryRepository>();
          getIt.registerSingleton<FactoryRepository>(factoryRepo);
          if (getIt.isRegistered<MonitoringRepository>())
            await getIt.unregister<MonitoringRepository>();
          getIt.registerSingleton<MonitoringRepository>(monitoringRepo);

          final tempDir = Directory.systemTemp.createTempSync('svc_test_');
          final server = MonitoringServiceServer(
            port: 0,
            useTls: false,
            isDevelopment: true,
            customDataDir: tempDir.path,
          );
          await server.start();
          final boundPort = server.boundPort!;
          expect(boundPort, greaterThan(0));

          final client = MonitoringServiceClient(
            baseUrl: 'http://127.0.0.1:$boundPort',
          );

          try {
            final loginRes = await client.login(
              username: 'admin',
              password: 'Password123',
            );
            expect(loginRes.isSuccess, isTrue);

            // Seed existing device in RNF
            final seedDev =
                (await deviceRepo.addDevice(
                          DeviceEntity(
                            id: 0,
                            factoryId: 'rnf',
                            name: 'RNF-API-TEST',
                            type: DeviceType.pc,
                            ip: '192.168.22.15',
                            ownerName: 'Initial API Owner',
                            department: 'IT',
                            createdAt: DateTime.now(),
                          ),
                        )
                        as Success<DeviceEntity>)
                    .data;

            // Prepare payload JSON matching DeviceImportCommitPayload
            final payloadJson = {
              'targetFactoryId': 'rnf',
              'inserts': [
                {
                  'name': 'RNF-API-INSERTED',
                  'type': 'laptop',
                  'ip': '192.168.22.16',
                  'ownerName': 'Inserted User',
                  'department': 'Finance',
                  'factoryId': 'rnf',
                },
              ],
              'updates': [
                {
                  'id': seedDev.id,
                  'name': 'RNF-API-TEST-UPDATED',
                  'type': 'pc',
                  'ip': '192.168.22.15',
                  'ownerName': 'Updated API Owner',
                  'department': 'IT Admin',
                  'factoryId': 'rnf',
                },
              ],
            };

            final importRes = await client.importDevicesPayload(payloadJson);
            expect(importRes.isSuccess, isTrue);
            expect(importRes.data, equals(2));

            // Verify in DB
            final updated =
                (await deviceRepo.getDeviceById(seedDev.id)
                        as Success<DeviceEntity>)
                    .data;
            expect(updated.name, equals('RNF-API-TEST-UPDATED'));
            expect(updated.ownerName, equals('Updated API Owner'));

            final insertedList =
                (await deviceRepo.getDevices(factoryId: 'rnf')
                        as Success<List<DeviceEntity>>)
                    .data;
            expect(
              insertedList.any(
                (d) => d.name == 'RNF-API-INSERTED' && d.ip == '192.168.22.16',
              ),
              isTrue,
            );
          } finally {
            client.dispose();
            await server.stop();
            if (getIt.isRegistered<MonitoringRepository>())
              await getIt.unregister<MonitoringRepository>();
            if (getIt.isRegistered<FactoryRepository>())
              await getIt.unregister<FactoryRepository>();
            if (getIt.isRegistered<AuditLogRepository>())
              await getIt.unregister<AuditLogRepository>();
            if (getIt.isRegistered<AuthRepository>())
              await getIt.unregister<AuthRepository>();
            if (getIt.isRegistered<DeviceRepository>())
              await getIt.unregister<DeviceRepository>();
            if (getIt.isRegistered<AppDatabase>())
              await getIt.unregister<AppDatabase>();
            try {
              tempDir.deleteSync(recursive: true);
            } catch (_) {}
          }
        },
      );

      // ──────────────────────────────────────────────────────────────────────────
      // Issue 2: Excel Template Sample Data
      // ──────────────────────────────────────────────────────────────────────────
      test(
        '2.1: generateTemplate() produces a headers-only spreadsheet without demo devices',
        () async {
          final templateBytes = excelService.generateTemplate(
            factoryCode: 'RNF',
          );
          expect(templateBytes.isNotEmpty, isTrue);

          // Parse the generated template directly
          final parseResult = excelService.parseAndValidateFile(
            bytes: templateBytes,
            fileName: 'Inventory_Template.xlsx',
            existingFactoryDevices: [],
            targetFactoryId: 'rnf',
          );

          // An untouched generated template must yield zero valid devices, zero updates, zero invalid records
          expect(
            parseResult.validDevices.isEmpty,
            isTrue,
            reason: 'Untouched template must yield 0 devices',
          );
          expect(parseResult.insertDevices.isEmpty, isTrue);
          expect(parseResult.updateDevices.isEmpty, isTrue);
          expect(parseResult.invalidCount, equals(0));
          expect(
            parseResult.rows.isEmpty,
            isTrue,
            reason: 'Headers-only template processed 0 data rows',
          );
        },
      );

      test(
        '2.2: Parser explicitly ignores demonstration/example rows',
        () async {
          const csvWithDemoRow = '''
IP,Name,Type,Owner,Department,Location
[EXAMPLE] 192.168.1.100,Sample PC,PC,Demo User,IT,Floor 1
192.168.22.44,Real Workstation,PC,John Doe,Engineering,Desk 4
''';

          final csvBytes = utf8.encode(csvWithDemoRow);
          final parseResult = excelService.parseAndValidateFile(
            bytes: csvBytes,
            fileName: 'devices.csv',
            existingFactoryDevices: [],
            targetFactoryId: 'rnf',
          );

          expect(parseResult.validDevices.length, equals(1));
          expect(parseResult.validDevices.first.ip, equals('192.168.22.44'));
          expect(
            parseResult.validDevices.first.name,
            equals('Real Workstation'),
          );
          expect(parseResult.insertDevices.length, equals(1));
        },
      );

      // ──────────────────────────────────────────────────────────────────────────
      // Issue 4: Spreadsheet File Type Handling
      // ──────────────────────────────────────────────────────────────────────────
      test(
        '4.1: CSV parsing handles commas, semicolons, and quotes seamlessly',
        () async {
          const csvContent = '''
"IP";"Name";"Type";"Owner";"Department";"Location"
"192.168.22.60";"Accounting PC";"PC";"Jane Smith";"Finance";"Room 202"
"192.168.22.61";"HR Laptop";"Laptop";"Mark Davis";"HR";"Mobile"
''';
          final csvBytes = utf8.encode(csvContent);

          final parseResult = excelService.parseAndValidateFile(
            bytes: csvBytes,
            fileName: 'import_devices.csv',
            existingFactoryDevices: [],
            targetFactoryId: 'rnf',
          );

          expect(parseResult.validDevices.length, equals(2));
          expect(parseResult.validDevices[0].ip, equals('192.168.22.60'));
          expect(parseResult.validDevices[0].name, equals('Accounting PC'));
          expect(parseResult.validDevices[1].ip, equals('192.168.22.61'));
          expect(parseResult.validDevices[1].name, equals('HR Laptop'));
        },
      );

      test(
        '4.2: Malformed or corrupted bytes return clear validation error without crash',
        () async {
          final corruptBytes = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66];

          final parseResult = excelService.parseAndValidateFile(
            bytes: corruptBytes,
            fileName: 'corrupted_file.xlsx',
            existingFactoryDevices: [],
            targetFactoryId: 'rnf',
          );

          expect(parseResult.validDevices.isEmpty, isTrue);
          expect(parseResult.invalidCount, greaterThan(0));
          expect(
            parseResult.rows.first.rejectionReason,
            contains('Failed to decode spreadsheet file'),
          );
        },
      );
    },
  );
}
