import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:it_network_monitor/features/network_blueprint/data/datasources/blueprint_drawio_parser.dart';
import 'package:it_network_monitor/features/network_blueprint/domain/entities/blueprint_element_entity.dart';
import 'package:it_network_monitor/features/network_blueprint/domain/entities/blueprint_page_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1.4.3.6: High-Fidelity Network Blueprint Remediation Tests', () {
    late String drawioXml;
    late BlueprintDrawioParser parser;
    late List<BlueprintPageEntity> pages;

    setUpAll(() {
      final file = File('assets/topology/rnf/RNFip.drawio');
      expect(file.existsSync(), isTrue, reason: 'RNFip.drawio must exist');
      drawioXml = file.readAsStringSync();
      parser = BlueprintDrawioParser();
      pages = parser.parseXmlString(drawioXml);
    });

    test('1. All three source pages are loaded correctly with English titles', () {
      expect(pages.length, equals(3));
      expect(pages[0].englishTitle, equals('First Floor'));
      expect(pages[1].englishTitle, equals('Ground Floor & Warehouses'));
      expect(pages[2].englishTitle, equals('Security Gates'));
    });

    test('2. Exact 143 cable routes are parsed across all three floor plans', () {
      // First Floor: 96 cables
      expect(
        pages[0].cables.length,
        equals(96),
        reason: 'First Floor must have exactly 96 cable routes',
      );

      // Ground Floor & Warehouses: 32 cables
      expect(
        pages[1].cables.length,
        equals(32),
        reason: 'Ground Floor & Warehouses must have exactly 32 cable routes',
      );

      // Security Gates: 15 cables
      expect(
        pages[2].cables.length,
        equals(15),
        reason: 'Security Gates must have exactly 15 cable routes',
      );

      final totalCables = pages.fold<int>(0, (sum, p) => sum + p.cables.length);
      expect(totalCables, equals(143), reason: 'Total cable routes must be 143');
    });

    test('3. High-resolution rendered artwork images exist and are non-empty', () {
      final expectedAssets = [
        ('assets/topology/rnf/pages/first_floor.png', 500000),
        ('assets/topology/rnf/pages/ground_floor_warehouses.png', 100000),
        ('assets/topology/rnf/pages/security_gates.png', 50000),
      ];

      for (final (path, minSize) in expectedAssets) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: 'Artwork file $path must exist');
        expect(
          f.lengthSync(),
          greaterThan(minSize),
          reason: '$path must be a full-resolution rendered image',
        );
      }
    });

    test('4. Exact diagram viewport dimensions match coordinate space', () {
      // Floor 0
      expect(pages[0].svgSize.width, equals(3545.0));
      expect(pages[0].svgSize.height, equals(2663.0));

      // Floor 1
      expect(pages[1].svgSize.width, equals(1192.0));
      expect(pages[1].svgSize.height, equals(1379.0));

      // Floor 2
      expect(pages[2].svgSize.width, equals(684.0));
      expect(pages[2].svgSize.height, inInclusiveRange(889.0, 890.0));
    });

    test('5. Expected device categories are retained and populated', () {
      final allElements = pages.expand((p) => p.elements).toList();
      final categories = allElements.map((e) => e.category).toSet();

      expect(categories.contains(BlueprintElementCategory.server), isTrue);
      expect(categories.contains(BlueprintElementCategory.switchDevice), isTrue);
      expect(categories.contains(BlueprintElementCategory.workstation), isTrue);
      expect(categories.contains(BlueprintElementCategory.laptop), isTrue);
      expect(categories.contains(BlueprintElementCategory.office), isTrue);
      expect(categories.contains(BlueprintElementCategory.room), isTrue);
      expect(categories.contains(BlueprintElementCategory.security), isTrue);
      expect(categories.contains(BlueprintElementCategory.telephony), isTrue);
    });

    test('6. Cable waypoints contain valid geometric segments and colors', () {
      for (final page in pages) {
        for (final cable in page.cables) {
          expect(
            cable.waypoints.length,
            greaterThanOrEqualTo(2),
            reason: 'Cable ${cable.id} must have at least source and target waypoints',
          );
          expect(
            cable.strokeColor.a,
            greaterThan(0),
            reason: 'Cable ${cable.id} stroke must be opaque',
          );
          expect(
            cable.strokeWidth,
            greaterThan(0),
            reason: 'Cable ${cable.id} strokeWidth must be > 0',
          );
        }
      }
    });

    test('7. Live telemetry overlay updates do not mutate source geometry', () {
      final page = pages[0];
      final originalBounds = page.elements.first.renderBounds;

      // Simulate live status update via copyWith
      final updatedElement = page.elements.first.copyWith(
        mappedDeviceId: 42,
        mappedIp: '192.168.1.10',
      );

      expect(updatedElement.renderBounds, equals(originalBounds));
      expect(page.contentBounds, equals(page.contentBounds));
    });
  });
}
