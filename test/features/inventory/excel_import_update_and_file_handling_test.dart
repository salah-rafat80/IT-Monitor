import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:it_network_monitor/core/config/app_run_mode.dart';
import 'package:it_network_monitor/core/database/app_database.dart';
import 'package:it_network_monitor/core/utils/result.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Issues 1, 2, 4: Excel Import UPDATE, Template Sample Data, and File Type Handling',
    () {
      late AppDatabase db;
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

        factoryRepo = FactoryRepositoryImpl(db);
        deviceRepo = DeviceRepositoryImpl(db);
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
          if (getIt.isRegistered<AppDatabase>()) {
            await getIt.unregister<AppDatabase>();
          }
          getIt.registerSingleton<AppDatabase>(db);
          if (getIt.isRegistered<DeviceRepository>()) {
            await getIt.unregister<DeviceRepository>();
          }
          getIt.registerSingleton<DeviceRepository>(deviceRepo);

          if (getIt.isRegistered<FactoryRepository>()) {
            await getIt.unregister<FactoryRepository>();
          }
          getIt.registerSingleton<FactoryRepository>(factoryRepo);
          if (getIt.isRegistered<MonitoringRepository>()) {
            await getIt.unregister<MonitoringRepository>();
          }
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
            final authRes = await client.authenticateWithTrustedLocalToken(
              server.trustedTokenFilePath!,
            );
            expect(authRes.isSuccess, isTrue);

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
            if (getIt.isRegistered<MonitoringRepository>()) {
              await getIt.unregister<MonitoringRepository>();
            }
            if (getIt.isRegistered<FactoryRepository>()) {
              await getIt.unregister<FactoryRepository>();
            }

            if (getIt.isRegistered<DeviceRepository>()) {
              await getIt.unregister<DeviceRepository>();
            }
            if (getIt.isRegistered<AppDatabase>()) {
              await getIt.unregister<AppDatabase>();
            }
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

      // ──────────────────────────────────────────────────────────────────────────
      // Final Regression Suite: Header Mapping, Round-Trips, and Boolean Semantics
      // ──────────────────────────────────────────────────────────────────────────
      group(
        'Final Regression Suite: Header Mapping, Round-Trips, and Boolean Semantics',
        () {
          late List<DeviceEntity> roundTripSeedDevices;

          setUp(() {
            roundTripSeedDevices = [
              DeviceEntity(
                id: 101,
                factoryId: 'rnf',
                name: 'Core Switch Alpha',
                type: DeviceType.switchDevice,
                ip: '192.168.22.1',
                ownerName: 'Network Ops',
                department: 'Infrastructure',
                officeLocation: 'Server Room Rack 1',
                mac: '00:11:22:33:44:55',
                hostname: 'sw-core-01',
                vendor: 'Cisco',
                model: 'Catalyst 9300',
                operatingSystem: 'Cisco IOS-XE',
                parentSwitchName: null,
                isMonitored: true,
                isEnabled: true,
                notes: 'Core distribution switch',
                createdAt: DateTime(2026, 1, 1),
              ),
              DeviceEntity(
                id: 102,
                factoryId: 'rnf',
                name: 'Border Router Gateway',
                type: DeviceType.router,
                ip: '192.168.22.254',
                ownerName: 'Security Team',
                department: 'CyberSec',
                officeLocation: 'Edge Gateway Room',
                mac: 'AA:BB:CC:DD:EE:01',
                hostname: 'gw-border-01',
                vendor: 'Fortinet',
                model: 'FortiGate 100F',
                operatingSystem: 'FortiOS 7.2',
                parentSwitchName: 'Core Switch Alpha',
                isMonitored: true,
                isEnabled: true,
                notes: 'Primary firewall & router',
                createdAt: DateTime(2026, 1, 2),
              ),
              DeviceEntity(
                id: 103,
                factoryId: 'rnf',
                name: 'Warehouse AP 03',
                type: DeviceType.wirelessAccessPoint,
                ip: '192.168.22.15',
                ownerName: 'Logistics IT',
                department: 'Warehouse',
                officeLocation: 'Aisle 4 High Bay',
                mac: 'AA:BB:CC:DD:EE:02',
                hostname: 'ap-wh-03',
                vendor: 'Aruba',
                model: 'AP-515',
                operatingSystem: 'ArubaOS',
                parentSwitchName: 'Core Switch Alpha',
                isMonitored: false,
                isEnabled: true,
                notes: 'Access point with monitoring disabled',
                createdAt: DateTime(2026, 1, 3),
              ),
              DeviceEntity(
                id: 104,
                factoryId: 'rnf',
                name: 'Finance Laser Printer',
                type: DeviceType.printer,
                ip: '192.168.22.50',
                ownerName: 'Finance Dept',
                department: 'Accounting',
                officeLocation: 'Finance Office 201',
                mac: 'AA:BB:CC:DD:EE:03',
                hostname: 'prn-fin-m404',
                vendor: 'HP',
                model: 'LaserJet Pro M404',
                operatingSystem: 'FutureSmart',
                parentSwitchName: 'Core Switch Alpha',
                isMonitored: true,
                isEnabled: false,
                notes: 'Printer disabled for maintenance',
                createdAt: DateTime(2026, 1, 4),
              ),
              DeviceEntity(
                id: 105,
                factoryId: 'rnf',
                name: 'Engineering Workstation 09',
                type: DeviceType.pc,
                ip: '192.168.22.109',
                ownerName: 'Jane Designer',
                department: 'Engineering',
                officeLocation: 'Design Lab Desk 9',
                mac: 'AA:BB:CC:DD:EE:04',
                hostname: 'ws-cad-09',
                vendor: 'Dell',
                model: 'Precision 5820',
                operatingSystem: 'Windows 11 Pro',
                parentSwitchName: 'Core Switch Alpha',
                isMonitored: true,
                isEnabled: true,
                notes: 'CAD/CAM workstation',
                createdAt: DateTime(2026, 1, 5),
              ),
              DeviceEntity(
                id: 106,
                factoryId: 'rnf',
                name: 'Executive Laptop',
                type: DeviceType.laptop,
                ip: '192.168.22.110',
                ownerName: 'CEO Office',
                department: 'Executive',
                officeLocation: 'Executive Suite 500',
                mac: 'AA:BB:CC:DD:EE:05',
                hostname: 'lt-exec-01',
                vendor: 'Lenovo',
                model: 'ThinkPad X1 Carbon',
                operatingSystem: 'Windows 11 Enterprise',
                parentSwitchName: null,
                isMonitored: false,
                isEnabled: false,
                notes: 'Executive laptop unmonitored and disabled',
                createdAt: DateTime(2026, 1, 6),
              ),
            ];
          });

          test(
            'Round-Trip 1: exportToExcel() followed by parseAndValidateExcel() preserves all 17 fields, names, types, and booleans without degradation',
            () {
              final excelBytes = excelService.exportToExcel(
                devices: roundTripSeedDevices,
                factoryCode: 'RNF',
              );
              expect(excelBytes.isNotEmpty, isTrue);

              final summary = excelService.parseAndValidateExcel(
                bytes: excelBytes,
                targetFactoryId: 'rnf',
                existingFactoryDevices: roundTripSeedDevices,
              );

              expect(summary.invalidCount, equals(0));
              expect(summary.skippedCount, equals(0));
              expect(summary.insertCount, equals(0));
              expect(summary.updateCount, equals(6));
              expect(summary.validDevices.length, equals(6));

              for (final original in roundTripSeedDevices) {
                final reimported = summary.validDevices.firstWhere(
                  (d) => d.id == original.id,
                );
                expect(
                  reimported.name,
                  equals(original.name),
                  reason: 'Device name must not be overwritten by device type',
                );
                expect(
                  reimported.type,
                  equals(original.type),
                  reason: 'Device type ${original.type} must be preserved',
                );
                expect(reimported.ip, equals(original.ip));
                expect(reimported.factoryId, equals('rnf'));
                expect(reimported.ownerName, equals(original.ownerName));
                expect(reimported.department, equals(original.department));
                expect(
                  reimported.officeLocation,
                  equals(original.officeLocation),
                );
                expect(reimported.mac, equals(original.mac));
                expect(reimported.hostname, equals(original.hostname));
                expect(reimported.vendor, equals(original.vendor));
                expect(reimported.model, equals(original.model));
                expect(
                  reimported.operatingSystem,
                  equals(original.operatingSystem),
                );
                expect(
                  reimported.parentSwitchName,
                  equals(original.parentSwitchName),
                );
                expect(reimported.isMonitored, equals(original.isMonitored));
                expect(reimported.isEnabled, equals(original.isEnabled));
                expect(reimported.notes, equals(original.notes));
              }
            },
          );

          test(
            'Round-Trip 2: exportToTsv() followed by parseTabularTsv() preserves all fields and maps Device Type correctly',
            () {
              final tsvText = excelService.exportToTsv(roundTripSeedDevices);
              expect(tsvText.isNotEmpty, isTrue);

              final summary = excelService.parseTabularTsv(
                tsvText: tsvText,
                targetFactoryId: 'rnf',
                existingFactoryDevices: roundTripSeedDevices,
              );

              expect(summary.invalidCount, equals(0));
              expect(summary.skippedCount, equals(0));
              expect(summary.insertCount, equals(0));
              expect(summary.updateCount, equals(6));
              expect(summary.validDevices.length, equals(6));

              for (final original in roundTripSeedDevices) {
                final reimported = summary.validDevices.firstWhere(
                  (d) => d.id == original.id,
                );
                expect(
                  reimported.name,
                  equals(original.name),
                  reason: 'TSV: Device name must be preserved',
                );
                expect(
                  reimported.type,
                  equals(original.type),
                  reason: 'TSV: Device type ${original.type} must match',
                );
                expect(reimported.ip, equals(original.ip));
                expect(reimported.factoryId, equals('rnf'));
                expect(reimported.ownerName, equals(original.ownerName));
                expect(reimported.department, equals(original.department));
                expect(
                  reimported.officeLocation,
                  equals(original.officeLocation),
                );
                expect(reimported.mac, equals(original.mac));
                expect(reimported.hostname, equals(original.hostname));
                expect(reimported.vendor, equals(original.vendor));
                expect(reimported.model, equals(original.model));
                expect(
                  reimported.operatingSystem,
                  equals(original.operatingSystem),
                );
                expect(
                  reimported.parentSwitchName,
                  equals(original.parentSwitchName),
                );
                expect(reimported.isMonitored, equals(original.isMonitored));
                expect(reimported.isEnabled, equals(original.isEnabled));
                expect(reimported.notes, equals(original.notes));
              }
            },
          );

          test(
            'Round-Trip 3: CSV parsing with application exported header names maps Device Name and Device Type exclusively',
            () {
              final csvLines = [
                'ID,Factory,Device Name,Device Type,IP Address,Owner Name,Department,Office Location,MAC Address,Hostname,Vendor,Model,Operating System,Parent Switch,Monitored,Enabled,Notes',
                '201,OTHER_FACTORY,Primary Switch,Network Switch,192.168.22.101,Alice Smith,IT Dept,Server Room,00:11:22:33:44:01,sw-pri,Cisco,C2960,IOS,None,Yes,Yes,Primary Core',
                '202,OTHER_FACTORY,Distribution Router,Router / Gateway,192.168.22.102,Bob Jones,IT Dept,MDF,00:11:22:33:44:02,rt-dist,Juniper,SRX300,Junos,Primary Switch,No,No,Backup Gateway',
              ];
              final csvBytes = utf8.encode(csvLines.join('\n'));

              final summary = excelService.parseAndValidateFile(
                bytes: csvBytes,
                fileName: 'exported_inventory.csv',
                targetFactoryId: 'rnf',
                existingFactoryDevices: [],
              );

              expect(summary.invalidCount, equals(0));
              expect(summary.insertCount, equals(2));
              final dev1 = summary.validDevices.firstWhere(
                (d) => d.ip == '192.168.22.101',
              );
              final dev2 = summary.validDevices.firstWhere(
                (d) => d.ip == '192.168.22.102',
              );

              // Device Name exclusively to name
              expect(dev1.name, equals('Primary Switch'));
              expect(dev2.name, equals('Distribution Router'));

              // Device Type exclusively to type
              expect(dev1.type, equals(DeviceType.switchDevice));
              expect(dev2.type, equals(DeviceType.router));

              // Target Factory not overridden by spreadsheet factory column
              expect(dev1.factoryId, equals('rnf'));
              expect(dev2.factoryId, equals('rnf'));

              // Booleans respected
              expect(dev1.isMonitored, isTrue);
              expect(dev1.isEnabled, isTrue);
              expect(dev2.isMonitored, isFalse);
              expect(dev2.isEnabled, isFalse);
            },
          );

          test(
            'Boolean Semantics: Existing false booleans remain false with blank cells; explicit Yes/No update appropriately',
            () async {
              // 1. Seed existing device with isMonitored=false, isEnabled=false
              final seedRes = await deviceRepo.addDevice(
                DeviceEntity(
                  id: 0,
                  factoryId: 'rnf',
                  name: 'Disabled Server',
                  type: DeviceType.server,
                  ip: '192.168.22.77',
                  ownerName: 'Sysadmin',
                  department: 'IT',
                  isMonitored: false,
                  isEnabled: false,
                  createdAt: DateTime.now(),
                ),
              );
              final existingDev = (seedRes as Success<DeviceEntity>).data;
              expect(existingDev.isMonitored, isFalse);
              expect(existingDev.isEnabled, isFalse);

              // 2. Import CSV with BLANK Monitored and Enabled cells -> Must remain false
              final csvWithBlanks = [
                'ID,Factory,Device Name,Device Type,IP Address,Owner Name,Department,Monitored,Enabled',
                '${existingDev.id},RNF,Disabled Server,Server,192.168.22.77,Sysadmin,IT,,',
              ].join('\n');

              final blankSummary = excelService.parseAndValidateFile(
                bytes: utf8.encode(csvWithBlanks),
                fileName: 'blank_booleans.csv',
                targetFactoryId: 'rnf',
                existingFactoryDevices: [existingDev],
              );

              expect(blankSummary.updateCount, equals(1));
              final updatedWithBlanks = blankSummary.updateDevices.first;
              expect(
                updatedWithBlanks.isMonitored,
                isFalse,
                reason: 'Blank Monitored cell must preserve existing false',
              );
              expect(
                updatedWithBlanks.isEnabled,
                isFalse,
                reason: 'Blank Enabled cell must preserve existing false',
              );

              // Commit to DB and verify DB preservation
              final commitRes1 = await deviceRepo.commitImportPayload(
                blankSummary.toCommitPayload(),
              );
              expect(commitRes1.isSuccess, isTrue);
              final inDb1 =
                  (await deviceRepo.getDeviceById(existingDev.id)
                          as Success<DeviceEntity>)
                      .data;
              expect(inDb1.isMonitored, isFalse);
              expect(inDb1.isEnabled, isFalse);

              // 3. Explicit 'Yes' updates to true
              final csvWithYes = [
                'ID,Factory,Device Name,Device Type,IP Address,Owner Name,Department,Monitored,Enabled',
                '${existingDev.id},RNF,Disabled Server,Server,192.168.22.77,Sysadmin,IT,Yes,Yes',
              ].join('\n');
              final yesSummary = excelService.parseAndValidateFile(
                bytes: utf8.encode(csvWithYes),
                fileName: 'yes_booleans.csv',
                targetFactoryId: 'rnf',
                existingFactoryDevices: [inDb1],
              );
              expect(yesSummary.updateDevices.first.isMonitored, isTrue);
              expect(yesSummary.updateDevices.first.isEnabled, isTrue);
              await deviceRepo.commitImportPayload(
                yesSummary.toCommitPayload(),
              );
              final inDb2 =
                  (await deviceRepo.getDeviceById(existingDev.id)
                          as Success<DeviceEntity>)
                      .data;
              expect(inDb2.isMonitored, isTrue);
              expect(inDb2.isEnabled, isTrue);

              // 4. Explicit 'No' updates to false
              final csvWithNo = [
                'ID,Factory,Device Name,Device Type,IP Address,Owner Name,Department,Monitored,Enabled',
                '${existingDev.id},RNF,Disabled Server,Server,192.168.22.77,Sysadmin,IT,No,No',
              ].join('\n');
              final noSummary = excelService.parseAndValidateFile(
                bytes: utf8.encode(csvWithNo),
                fileName: 'no_booleans.csv',
                targetFactoryId: 'rnf',
                existingFactoryDevices: [inDb2],
              );
              expect(noSummary.updateDevices.first.isMonitored, isFalse);
              expect(noSummary.updateDevices.first.isEnabled, isFalse);
              await deviceRepo.commitImportPayload(noSummary.toCommitPayload());
              final inDb3 =
                  (await deviceRepo.getDeviceById(existingDev.id)
                          as Success<DeviceEntity>)
                      .data;
              expect(inDb3.isMonitored, isFalse);
              expect(inDb3.isEnabled, isFalse);
            },
          );

          test(
            'Boolean Semantics on INSERT: New devices with Monitored=No or Enabled=No are inserted with false in SQLite DB',
            () async {
              final csvNewDevices = [
                'Device Name,Device Type,IP Address,Owner Name,Department,Monitored,Enabled',
                'Inserted Disabled Device,PC,192.168.22.88,John Disabled,Operations,Yes,No',
                'Inserted Unmonitored Device,Printer,192.168.22.89,Jane Unmonitored,Operations,No,Yes',
              ].join('\n');

              final summary = excelService.parseAndValidateFile(
                bytes: utf8.encode(csvNewDevices),
                fileName: 'new_disabled_devices.csv',
                targetFactoryId: 'rnf',
                existingFactoryDevices: [],
              );

              expect(summary.insertCount, equals(2));
              final devDisabled = summary.insertDevices.firstWhere(
                (d) => d.ip == '192.168.22.88',
              );
              final devUnmonitored = summary.insertDevices.firstWhere(
                (d) => d.ip == '192.168.22.89',
              );

              expect(devDisabled.isEnabled, isFalse);
              expect(devDisabled.isMonitored, isTrue);
              expect(devUnmonitored.isEnabled, isTrue);
              expect(devUnmonitored.isMonitored, isFalse);

              // Commit to DB and verify SQLite records
              final commitRes = await deviceRepo.commitImportPayload(
                summary.toCommitPayload(),
              );
              expect(commitRes.isSuccess, isTrue);

              final rnfDevices =
                  (await deviceRepo.getDevices(factoryId: 'rnf')
                          as Success<List<DeviceEntity>>)
                      .data;
              final dbDisabled = rnfDevices.firstWhere(
                (d) => d.ip == '192.168.22.88',
              );
              final dbUnmonitored = rnfDevices.firstWhere(
                (d) => d.ip == '192.168.22.89',
              );

              expect(
                dbDisabled.isEnabled,
                isFalse,
                reason: 'Database must store isEnabled=false',
              );
              expect(dbDisabled.isMonitored, isTrue);
              expect(dbUnmonitored.isEnabled, isTrue);
              expect(
                dbUnmonitored.isMonitored,
                isFalse,
                reason: 'Database must store isMonitored=false',
              );
            },
          );

          test(
            'End-to-End Database Round-Trip: Adding devices to DB, exporting to Excel, importing without changes updates existing IDs and preserves relationships',
            () async {
              // 1. Add 3 distinct devices to DB in factory BNF
              final d1Res = await deviceRepo.addDevice(
                DeviceEntity(
                  id: 0,
                  factoryId: 'bnf',
                  name: 'BNF-SW-MAIN',
                  type: DeviceType.switchDevice,
                  ip: '192.168.21.10',
                  ownerName: 'Plant IT',
                  department: 'Plant Infra',
                  officeLocation: 'Line 1 Rack',
                  vendor: 'Cisco',
                  model: 'SG350',
                  isMonitored: true,
                  isEnabled: true,
                  notes: 'Main plant switch',
                  createdAt: DateTime.now(),
                ),
              );
              final swDev = (d1Res as Success<DeviceEntity>).data;

              final d2Res = await deviceRepo.addDevice(
                DeviceEntity(
                  id: 0,
                  factoryId: 'bnf',
                  name: 'BNF-ROBOT-01',
                  type: DeviceType.other,
                  ip: '192.168.21.20',
                  ownerName: 'Automation Team',
                  department: 'Robotics',
                  officeLocation: 'Cell A',
                  parentSwitchId: swDev.id,
                  parentSwitchName: 'BNF-SW-MAIN',
                  vendor: 'Kuka',
                  model: 'KR C4',
                  isMonitored: false,
                  isEnabled: true,
                  notes: 'Welding robot controller',
                  createdAt: DateTime.now(),
                ),
              );
              final robotDev = (d2Res as Success<DeviceEntity>).data;

              final d3Res = await deviceRepo.addDevice(
                DeviceEntity(
                  id: 0,
                  factoryId: 'bnf',
                  name: 'BNF-QC-WORKSTATION',
                  type: DeviceType.pc,
                  ip: '192.168.21.30',
                  ownerName: 'QC Tech',
                  department: 'Quality',
                  parentSwitchId: swDev.id,
                  parentSwitchName: 'BNF-SW-MAIN',
                  isMonitored: true,
                  isEnabled: false,
                  notes: 'Defect logging PC',
                  createdAt: DateTime.now(),
                ),
              );
              final qcDev = (d3Res as Success<DeviceEntity>).data;

              // 2. Export all BNF devices to Excel
              final bnfDevices =
                  (await deviceRepo.getDevices(factoryId: 'bnf')
                          as Success<List<DeviceEntity>>)
                      .data;
              expect(bnfDevices.length, equals(3));

              final excelBytes = excelService.exportToExcel(
                devices: bnfDevices,
                factoryCode: 'BNF',
              );

              // 3. Import without changes
              final summary = excelService.parseAndValidateExcel(
                bytes: excelBytes,
                targetFactoryId: 'bnf',
                existingFactoryDevices: bnfDevices,
              );

              expect(summary.invalidCount, equals(0));
              expect(summary.insertCount, equals(0));
              expect(summary.updateCount, equals(3));

              // 4. Commit import payload to database
              final commitRes = await deviceRepo.commitImportPayload(
                summary.toCommitPayload(),
              );
              expect(commitRes.isSuccess, isTrue);

              // 5. Verify database state
              final bnfDevicesAfter =
                  (await deviceRepo.getDevices(factoryId: 'bnf')
                          as Success<List<DeviceEntity>>)
                      .data;
              expect(
                bnfDevicesAfter.length,
                equals(3),
                reason: 'No duplicate records inserted',
              );

              final swAfter = bnfDevicesAfter.firstWhere(
                (d) => d.id == swDev.id,
              );
              final robotAfter = bnfDevicesAfter.firstWhere(
                (d) => d.id == robotDev.id,
              );
              final qcAfter = bnfDevicesAfter.firstWhere(
                (d) => d.id == qcDev.id,
              );

              expect(swAfter.name, equals('BNF-SW-MAIN'));
              expect(swAfter.type, equals(DeviceType.switchDevice));
              expect(swAfter.isMonitored, isTrue);
              expect(swAfter.isEnabled, isTrue);

              expect(robotAfter.name, equals('BNF-ROBOT-01'));
              expect(
                robotAfter.parentSwitchId,
                equals(swDev.id),
                reason: 'Parent switch relationship ID preserved',
              );
              expect(robotAfter.parentSwitchName, equals('BNF-SW-MAIN'));
              expect(
                robotAfter.isMonitored,
                isFalse,
                reason: 'isMonitored=false preserved',
              );
              expect(robotAfter.isEnabled, isTrue);

              expect(qcAfter.name, equals('BNF-QC-WORKSTATION'));
              expect(qcAfter.parentSwitchId, equals(swDev.id));
              expect(qcAfter.isMonitored, isTrue);
              expect(
                qcAfter.isEnabled,
                isFalse,
                reason: 'isEnabled=false preserved',
              );
            },
          );
        },
      );
    },
  );
}
