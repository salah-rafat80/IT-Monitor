import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/network_blueprint/data/datasources/blueprint_drawio_parser.dart';
import 'package:it_network_monitor/features/network_blueprint/domain/entities/blueprint_element_entity.dart';

void main() {
  group('BlueprintDrawioParser', () {
    late BlueprintDrawioParser parser;
    late String xmlContent;

    setUpAll(() {
      parser = BlueprintDrawioParser();
      final file = File('assets/topology/rnf/RNFip.drawio');
      expect(file.existsSync(), isTrue, reason: 'Source RNFip.drawio must exist in assets');
      xmlContent = file.readAsStringSync();
    });

    test('successfully parses all 3 diagram pages from RNFip.drawio', () {
      final pages = parser.parseXmlString(xmlContent);

      expect(pages.length, equals(3));

      // Page 0: First Floor
      final p0 = pages[0];
      expect(p0.id, equals('Page-1'));
      expect(p0.englishTitle, equals('First Floor'));
      expect(p0.elements.isNotEmpty, isTrue);
      expect(p0.cables.isNotEmpty, isTrue);
      expect(p0.contentBounds.isFinite, isTrue);
      expect(p0.contentBounds.width, greaterThan(1000));
      expect(p0.contentBounds.height, greaterThan(1000));

      // Page 1: Ground Floor & Warehouses
      final p1 = pages[1];
      expect(p1.id, equals('CZwG6OWdVMjHw0YqGgOi'));
      expect(p1.englishTitle, equals('Ground Floor & Warehouses'));
      expect(p1.elements.isNotEmpty, isTrue);
      expect(p1.cables.isNotEmpty, isTrue);
      expect(p1.contentBounds.width, greaterThan(800));

      // Page 2: Security Gates
      final p2 = pages[2];
      expect(p2.id, equals('2SKE6Rj-lpadhde2bo0e'));
      expect(p2.englishTitle, equals('Security Gates'));
      expect(p2.elements.isNotEmpty, isTrue);
      expect(p2.cables.isNotEmpty, isTrue);
    });

    test('recursively resolves nested child element positions to absolute coordinates', () {
      final pages = parser.parseXmlString(xmlContent);
      final p0 = pages[0];

      // Cell '6' is inside UserObject '2' (at x=-114, y=66), with local x=76.06, y=27
      final cell6 = p0.elements.firstWhere((e) => e.id == '6');
      expect(cell6.bounds.left, closeTo(-114.0 + 76.06, 0.1));
      expect(cell6.bounds.top, closeTo(66.0 + 27.0, 0.1));
    });

    test('properly parses cable edge connections and waypoints', () {
      final pages = parser.parseXmlString(xmlContent);

      for (final page in pages) {
        for (final cable in page.cables) {
          expect(cable.id.isNotEmpty, isTrue);
          expect(cable.waypoints.length, greaterThanOrEqualTo(2));
          for (final pt in cable.waypoints) {
            expect(pt.dx.isFinite, isTrue);
            expect(pt.dy.isFinite, isTrue);
          }
        }
      }
    });

    test('identifies critical infrastructure elements like switches and servers', () {
      final pages = parser.parseXmlString(xmlContent);
      final allElements = pages.expand((p) => p.elements).toList();

      final switches = allElements.where((e) => e.category == BlueprintElementCategory.switchDevice).toList();
      final servers = allElements.where((e) => e.category == BlueprintElementCategory.server).toList();

      expect(switches.isNotEmpty, isTrue, reason: 'Must detect switch devices');
      expect(servers.isNotEmpty, isTrue, reason: 'Must detect server infrastructure');

      // Verify specific known IDs
      final mainServer = allElements.firstWhere((e) => e.id == '43');
      expect(mainServer.englishLabel, equals('Main Server'));
      expect(mainServer.category, equals(BlueprintElementCategory.server));

      final ipPbx = allElements.firstWhere((e) => e.id == '48');
      expect(ipPbx.englishLabel, equals('IP-PBX Telephony System'));
      expect(ipPbx.category, equals(BlueprintElementCategory.telephony));
    });
  });
}
