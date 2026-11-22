import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Network Blueprint Vector SVG Acceptance Tests', () {
    final pageFiles = [
      'first_floor.svg',
      'ground_floor_warehouses.svg',
      'security_gates.svg',
    ];

    for (final filename in pageFiles) {
      test('SVG file $filename exists and is non-empty vector data', () {
        final file = File('assets/topology/rnf/pages/$filename');
        expect(file.existsSync(), isTrue, reason: 'File $filename must exist');
        final content = file.readAsStringSync();
        expect(content.contains('<svg'), isTrue);
        expect(content.contains('</svg>'), isTrue);
        expect(content.length, greaterThan(10000), reason: '$filename must contain full-fidelity vector data');
      });

      testWidgets('flutter_svg parses and renders $filename without error', (tester) async {
        final file = File('assets/topology/rnf/pages/$filename');
        final content = file.readAsStringSync();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SvgPicture.string(
                  content,
                  width: 800,
                  height: 600,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(SvgPicture), findsOneWidget);
      });
    }

    test(
      'Explicit source cable & boundary colors are preserved exactly without mutation',
      () {
        // Floor 0: First Floor
        final f0 = File(
          'assets/topology/rnf/pages/first_floor.svg',
        ).readAsStringSync();
        expect(
          f0.contains('stroke="#9673a6"'),
          isTrue,
          reason: 'Source #9673a6 (Purple) must be preserved',
        );
        expect(
          f0.contains('stroke="#99CCFF"'),
          isTrue,
          reason: 'Source #99CCFF (Light Blue) must be preserved',
        );
        expect(
          f0.contains('stroke="#3399FF"'),
          isTrue,
          reason: 'Source #3399FF (Electric Blue) must be preserved',
        );
        expect(
          f0.contains('stroke="#9577a3"'),
          isFalse,
          reason: 'Mutated #9577a3 must not exist in Floor 1',
        );
        expect(
          f0.contains('stroke="#2b82da"'),
          isFalse,
          reason: 'Mutated #2b82da must not exist in Floor 1',
        );

        // Floor 1: Ground Floor & Warehouses
        final f1 = File(
          'assets/topology/rnf/pages/ground_floor_warehouses.svg',
        ).readAsStringSync();
        expect(
          f1.contains('stroke="#9673a6"'),
          isTrue,
          reason: 'Source #9673a6 (Purple) must be preserved',
        );
        expect(
          f1.contains('stroke="#3399FF"'),
          isTrue,
          reason: 'Source #3399FF (Electric Blue) must be preserved',
        );
        expect(
          f1.contains('stroke="#1e4a76"'),
          isTrue,
          reason:
              'Dynamic light-dark(#0f7ae6, #1e4a76) resolved to concrete dark theme #1e4a76',
        );
        expect(
          f1.contains('stroke="#9577a3"'),
          isFalse,
          reason: 'Mutated #9577a3 must not exist in Floor 0',
        );
        expect(
          f1.contains('stroke="#2b82da"'),
          isFalse,
          reason: 'Mutated #2b82da must not exist in Floor 0',
        );

        // Floor 2: Security Gates
        final f2 = File(
          'assets/topology/rnf/pages/security_gates.svg',
        ).readAsStringSync();
        expect(
          f2.contains('stroke="#17B81C"'),
          isTrue,
          reason: 'Source #17B81C (Dark Green) must be preserved',
        );
        expect(
          f2.contains('stroke="#2FFF5F"'),
          isTrue,
          reason: 'Source #2FFF5F (Bright Green) must be preserved',
        );
        expect(
          f2.contains('stroke="#139d17"'),
          isFalse,
          reason: 'Mutated #139d17 must not exist in Gates',
        );
        expect(
          f2.contains('stroke="#007200"'),
          isFalse,
          reason: 'Mutated #007200 must not exist in Gates',
        );
      },
    );
  });
}
