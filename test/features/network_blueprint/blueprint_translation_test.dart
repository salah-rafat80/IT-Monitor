import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/features/network_blueprint/data/datasources/blueprint_drawio_parser.dart';
import 'package:it_network_monitor/features/network_blueprint/data/models/blueprint_translation_map.dart';

void main() {
  group('BlueprintTranslationMap', () {
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');

    test('static translation dictionary contains zero Arabic in output values', () {
      for (final entry in BlueprintTranslationMap.phraseDictionary.entries) {
        expect(
          arabicRegex.hasMatch(entry.value),
          isFalse,
          reason: 'Dictionary entry "${entry.key}" -> "${entry.value}" must not contain Arabic characters',
        );
      }

      for (final entry in BlueprintTranslationMap.pageTitles.entries) {
        expect(
          arabicRegex.hasMatch(entry.value),
          isFalse,
          reason: 'Page title "${entry.key}" -> "${entry.value}" must not contain Arabic characters',
        );
      }

      for (final entry in BlueprintTranslationMap.cellOverrides.entries) {
        expect(
          arabicRegex.hasMatch(entry.value.english),
          isFalse,
          reason: 'Cell override ${entry.key} -> "${entry.value.english}" must not contain Arabic characters',
        );
      }
    });

    test('all parsed blueprint element labels contain zero Arabic characters', () {
      final parser = BlueprintDrawioParser();
      final file = File('assets/topology/rnf/RNFip.drawio');
      final xmlContent = file.readAsStringSync();
      final pages = parser.parseXmlString(xmlContent);

      for (final page in pages) {
        expect(
          arabicRegex.hasMatch(page.englishTitle),
          isFalse,
          reason: 'Page title "${page.englishTitle}" must not contain Arabic characters',
        );

        for (final el in page.elements) {
          if (el.englishLabel.isNotEmpty) {
            expect(
              arabicRegex.hasMatch(el.englishLabel),
              isFalse,
              reason: 'Element ID ${el.id} with label "${el.englishLabel}" contains untranslated Arabic characters!',
            );
          }
        }
      }
    });

    test('translate cleans short subnet notation into full IP format', () {
      final res1 = BlueprintTranslationMap.translate('.22.117');
      expect(res1, contains('192.168.22.117'));

      final res2 = BlueprintTranslationMap.translate('22.100');
      expect(res2, contains('192.168.22.100'));
    });
  });
}
