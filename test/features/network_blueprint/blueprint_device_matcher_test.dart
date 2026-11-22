import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/devices/domain/entities/device_entity.dart';
import 'package:it_network_monitor/features/monitoring/domain/entities/device_status_entity.dart';
import 'package:it_network_monitor/features/network_blueprint/data/datasources/blueprint_inventory_matcher.dart';
import 'package:it_network_monitor/features/network_blueprint/domain/entities/blueprint_element_entity.dart';
import 'package:it_network_monitor/features/network_blueprint/domain/entities/blueprint_page_entity.dart';

void main() {
  group('BlueprintInventoryMatcher', () {
    late BlueprintInventoryMatcher matcher;

    setUp(() {
      matcher = BlueprintInventoryMatcher();
    });

    final testPage = BlueprintPageEntity(
      id: 'test-page',
      drawioId: 'test-page',
      englishTitle: 'Test Floor',
      originalTitle: 'Test Floor Original',
      contentBounds: const Rect.fromLTWH(0, 0, 800, 600),
      cables: const [],
      elements: const [
        BlueprintElementEntity(
          id: 'el-1',
          rawLabel: 'Ahmed Helmy\n192.168.22.117',
          englishLabel: 'Ahmed Helmy 192.168.22.117',
          category: BlueprintElementCategory.workstation,
          bounds: Rect.fromLTWH(100, 100, 60, 40),
        ),
        BlueprintElementEntity(
          id: 'el-2',
          rawLabel: '.22.105',
          englishLabel: '192.168.22.105',
          category: BlueprintElementCategory.workstation,
          bounds: Rect.fromLTWH(200, 100, 60, 40),
        ),
        BlueprintElementEntity(
          id: 'el-3',
          rawLabel: 'Spare Parts Switch',
          englishLabel: 'Spare Parts Switch',
          category: BlueprintElementCategory.switchDevice,
          bounds: Rect.fromLTWH(300, 100, 80, 50),
        ),
      ],
    );

    final inventoryDevices = [
      DeviceEntity(
        id: 101,
        name: 'PC-Ahmed-Helmy',
        type: DeviceType.pc,
        ip: '192.168.22.117',
        ownerName: 'Ahmed Helmy',
        department: 'IT',
        createdAt: DateTime(2026, 1, 1),
      ),
      DeviceEntity(
        id: 102,
        name: 'PC-Accounting-105',
        type: DeviceType.pc,
        ip: '192.168.22.105',
        ownerName: 'Hisham',
        department: 'Accounting',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    final liveStatuses = {
      101: DeviceStatusEntity(
        deviceId: 101,
        status: DeviceStatusEnum.up,
        lastLatencyMs: 3,
        lastCheckAt: DateTime(2026, 11, 7, 14, 0),
        statusChangedAt: DateTime(2026, 11, 7, 10, 0),
      ),
      102: DeviceStatusEntity(
        deviceId: 102,
        status: DeviceStatusEnum.down,
        lastLatencyMs: null,
        lastCheckAt: DateTime(2026, 11, 7, 14, 0),
        statusChangedAt: DateTime(2026, 11, 7, 13, 0),
      ),
    };

    test('accurately matches element with exact IP and maps live status', () {
      final matchedPages = matcher.matchPages(
        pages: [testPage],
        inventoryDevices: inventoryDevices,
        liveStatuses: liveStatuses,
      );

      final p = matchedPages.first;
      final el1 = p.elements.firstWhere((e) => e.id == 'el-1');

      expect(el1.mappingConfidence, equals(BlueprintMappingConfidence.confirmedIp));
      expect(el1.mappedDeviceId, equals(101));
      expect(el1.mappedIp, equals('192.168.22.117'));
      expect(el1.liveStatus, equals(DeviceStatusEnum.up));
      expect(el1.lastLatencyMs, equals(3));
      expect(el1.isMonitored, isTrue);
    });

    test('resolves shorthand subnet IP and maps offline status', () {
      final matchedPages = matcher.matchPages(
        pages: [testPage],
        inventoryDevices: inventoryDevices,
        liveStatuses: liveStatuses,
      );

      final p = matchedPages.first;
      final el2 = p.elements.firstWhere((e) => e.id == 'el-2');

      expect(el2.mappingConfidence, equals(BlueprintMappingConfidence.confirmedIp));
      expect(el2.mappedDeviceId, equals(102));
      expect(el2.mappedIp, equals('192.168.22.105'));
      expect(el2.liveStatus, equals(DeviceStatusEnum.down));
      expect(el2.lastLatencyMs, isNull);
    });

    test('unmatched elements retain unmapped confidence without fabricated values', () {
      final matchedPages = matcher.matchPages(
        pages: [testPage],
        inventoryDevices: inventoryDevices,
        liveStatuses: liveStatuses,
      );

      final p = matchedPages.first;
      final el3 = p.elements.firstWhere((e) => e.id == 'el-3');

      expect(el3.mappingConfidence, equals(BlueprintMappingConfidence.unmapped));
      expect(el3.mappedDeviceId, isNull);
      expect(el3.liveStatus, isNull);
      expect(el3.isMonitored, isFalse);
    });
  });
}
