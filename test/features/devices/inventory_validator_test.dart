import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/devices/domain/services/inventory_validator.dart';

void main() {
  group('Phase 2 — InventoryValidator Unit Tests', () {
    test('1. Valid rows parse into valid DeviceEntities', () {
      final rows = [
        const RawInventoryRow(
          rowIndex: 2,
          rawName: 'PC-FIN-01',
          rawType: 'PC',
          rawIp: '192.168.1.10',
          rawOwner: 'Ahmed Mohamed',
          rawDepartment: 'Finance',
          rawOffice: 'Floor 2',
        ),
        const RawInventoryRow(
          rowIndex: 3,
          rawName: 'LT-HR-02',
          rawType: 'Laptop',
          rawIp: '192.168.1.11',
          rawOwner: 'Sara Ali',
          rawDepartment: 'HR',
          rawOffice: 'Floor 1',
        ),
      ];

      final preview = InventoryValidator.validateRows(rows: rows);

      expect(preview.totalRowsProcessed, equals(2));
      expect(preview.validCount, equals(2));
      expect(preview.invalidCount, equals(0));
      expect(preview.excludedDuplicateIpCount, equals(0));

      final dev1 = preview.validDevices.first;
      expect(dev1.name, equals('PC-FIN-01'));
      expect(dev1.ownerName, equals('Ahmed Mohamed'));
      expect(dev1.department, equals('Finance'));
      expect(dev1.ip, equals('192.168.1.10'));
    });

    test(
      '2. CRITICAL DUPLICATE IP RULE: Rejects ALL instances of duplicate IPs',
      () {
        final rows = [
          const RawInventoryRow(
            rowIndex: 2,
            rawName: 'PC-FIN-01',
            rawType: 'PC',
            rawIp: '192.168.1.10', // Duplicate IP
            rawOwner: 'Ahmed Mohamed',
            rawDepartment: 'Finance',
          ),
          const RawInventoryRow(
            rowIndex: 3,
            rawName: 'PC-IT-05',
            rawType: 'PC',
            rawIp: '192.168.1.10', // Duplicate IP
            rawOwner: 'Hassan Mahmoud',
            rawDepartment: 'IT',
          ),
          const RawInventoryRow(
            rowIndex: 4,
            rawName: 'PC-SALES-01',
            rawType: 'PC',
            rawIp: '192.168.1.15', // Unique IP
            rawOwner: 'Mona Zaki',
            rawDepartment: 'Sales',
          ),
        ];

        final preview = InventoryValidator.validateRows(rows: rows);

        // Neither instance of 192.168.1.10 must enter validDevices
        expect(preview.validCount, equals(1));
        expect(preview.validDevices.first.ip, equals('192.168.1.15'));

        // Both instances are recorded in invalidRecords and duplicate list
        expect(preview.excludedDuplicateIps, contains('192.168.1.10'));
        expect(preview.invalidCount, equals(2));
        expect(
          preview.invalidRecords.every((r) => r.rawIp == '192.168.1.10'),
          isTrue,
        );
      },
    );

    test(
      '3. Rejects missing required monitoring data (Owner, Department, IP)',
      () {
        final rows = [
          const RawInventoryRow(
            rowIndex: 2,
            rawName: 'PC-NO-OWNER',
            rawType: 'PC',
            rawIp: '192.168.1.20',
            rawOwner: '', // Missing owner
            rawDepartment: 'Finance',
          ),
          const RawInventoryRow(
            rowIndex: 3,
            rawName: 'PC-NO-DEPT',
            rawType: 'PC',
            rawIp: '192.168.1.21',
            rawOwner: 'Omar Khaled',
            rawDepartment: '', // Missing department
          ),
          const RawInventoryRow(
            rowIndex: 4,
            rawName: 'PC-NO-IP',
            rawType: 'PC',
            rawIp: '', // Missing IP
            rawOwner: 'Youssef Nader',
            rawDepartment: 'IT',
          ),
        ];

        final preview = InventoryValidator.validateRows(rows: rows);

        expect(preview.validCount, equals(0));
        expect(preview.invalidCount, equals(3));
      },
    );

    test('4. Rejects invalid IPv4 strings', () {
      final rows = [
        const RawInventoryRow(
          rowIndex: 2,
          rawName: 'PC-INVALID-IP',
          rawType: 'PC',
          rawIp: '999.168.1.1', // Invalid IPv4
          rawOwner: 'Tarek Ibrahim',
          rawDepartment: 'Legal',
        ),
        const RawInventoryRow(
          rowIndex: 3,
          rawName: 'PC-INVALID-STRING',
          rawType: 'PC',
          rawIp: 'not-an-ip-address',
          rawOwner: 'Eslam Said',
          rawDepartment: 'Audit',
        ),
      ];

      final preview = InventoryValidator.validateRows(rows: rows);

      expect(preview.validCount, equals(0));
      expect(preview.invalidCount, equals(2));
    });

    test(
      '5. Rejects Switch infrastructure device types from V1 monitoring',
      () {
        final rows = [
          const RawInventoryRow(
            rowIndex: 2,
            rawName: 'SW-CORE-01',
            rawType: 'Core Switch',
            rawIp: '10.0.0.1',
            rawOwner: 'IT Admin',
            rawDepartment: 'IT',
          ),
          const RawInventoryRow(
            rowIndex: 3,
            rawName: 'PC-VALID-01',
            rawType: 'PC',
            rawIp: '192.168.1.50',
            rawOwner: 'Nour El-Din',
            rawDepartment: 'Marketing',
          ),
        ];

        final preview = InventoryValidator.validateRows(rows: rows);

        expect(preview.validCount, equals(1));
        expect(preview.validDevices.first.name, equals('PC-VALID-01'));
        expect(preview.invalidCount, equals(1));
        expect(
          preview.invalidRecords.first.reason,
          contains('Switch/Network infrastructure'),
        );
      },
    );
  });
}
