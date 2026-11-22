import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/inventory/domain/services/excel_inventory_service.dart';

void main() {
  group('RNF WMI/AD Inventory Excel Schema & Diff Verification', () {
    late ExcelInventoryServiceImpl service;
    late List<int> excelBytes;

    setUp(() {
      service = ExcelInventoryServiceImpl();
      final file = File(
        r'C:\Users\Salah\.gemini\antigravity\brain\ae93d6c8-5a71-401b-a446-3ccde161ce12\.user_uploaded\media_1795272428105_6a6a883d.xlsx',
      );
      expect(file.existsSync(), isTrue, reason: 'Uploaded Excel file must exist on disk');
      excelBytes = file.readAsBytesSync();
    });

    test('parses all 28 rows with 0 invalid records and exact insert/update diff', () {
      final now = DateTime.now();
      final existingDbDevices = <DeviceEntity>[
        DeviceEntity(
          id: 49,
          factoryId: 'rnf',
          name: 'PC-67-QC',
          type: DeviceType.pc,
          ip: '192.168.22.67',
          ownerName: 'rm.inspector',
          department: 'QC-QA',
          isMonitored: true,
          isEnabled: true,
          createdAt: now,
        ),
        DeviceEntity(
          id: 31,
          factoryId: 'rnf',
          name: 'RNF-lap-03',
          type: DeviceType.laptop,
          ip: '192.168.22.69',
          ownerName: 'lab',
          department: 'QC-QA',
          isMonitored: true,
          isEnabled: true,
          createdAt: now,
        ),
        DeviceEntity(
          id: 17,
          factoryId: 'rnf',
          name: 'RNF-WHS-02',
          type: DeviceType.pc,
          ip: '192.168.22.72',
          ownerName: 'Hamdy Ahmed',
          department: 'Warehouse',
          isMonitored: true,
          isEnabled: true,
          createdAt: now,
        ),
        DeviceEntity(
          id: 3,
          factoryId: 'rnf',
          name: 'FIN-112',
          type: DeviceType.pc,
          ip: '192.168.22.112',
          ownerName: 'Mostafa Ayman',
          department: 'Accounting',
          isMonitored: true,
          isEnabled: true,
          createdAt: now,
        ),
      ];

      final summary = service.parseAndValidateFile(
        bytes: excelBytes,
        fileName: 'Company_PCs_Inventory.xlsx',
        targetFactoryId: 'rnf',
        existingFactoryDevices: existingDbDevices,
      );

      // Total rows in file: 28
      expect(summary.rows.length, equals(28));
      expect(summary.invalidCount, equals(0), reason: 'Zero rows should be rejected');

      // Check existing matches (should be UPDATE)
      final qcMatch = summary.rows.firstWhere((r) => r.device?.ip == '192.168.22.67');
      expect(qcMatch.action, equals('update'));
      expect(qcMatch.device?.id, equals(49));
      expect(qcMatch.device?.department, equals('QC-QA'), reason: 'Preserves existing DB department');
      expect(qcMatch.device?.mac, equals('8C-EC-4B-D7-09-E7'));
      expect(qcMatch.device?.vendor, equals('Dell Inc.'));
      expect(qcMatch.device?.model, equals('OptiPlex 3060'));
      expect(qcMatch.device?.notes, contains('SN: 22SRHT2'));
      expect(qcMatch.device?.notes, contains('RAM: 4GB@2666MHz'));

      // Check new device TECH (192.168.200.254) -> should be INSERT with inferred Maintenance dept
      final techNew = summary.rows.firstWhere((r) => r.device?.ip == '192.168.200.254');
      expect(techNew.action, equals('insert'));
      expect(techNew.device?.name, equals('TECH'));
      expect(techNew.device?.department, equals('Maintenance'), reason: 'Inferred from user/email');
      expect(techNew.device?.ownerName, equals('maintenance'));
      expect(techNew.device?.mac, equals('8C-EC-4B-D4-F0-BD'));
      expect(techNew.device?.notes, contains('SN: FX57HT2'));
    });
  });
}
