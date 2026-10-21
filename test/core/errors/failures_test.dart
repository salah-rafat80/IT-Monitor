import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/errors/failures.dart';

void main() {
  group('Failures Unit Tests', () {
    test('Failures with same props are equal', () {
      const f1 = DatabaseFailure('Error', code: 'DB_01');
      const f2 = DatabaseFailure('Error', code: 'DB_01');

      expect(f1, equals(f2));
    });

    test('ImportFailure holds detailed error messages list', () {
      const importFailure = ImportFailure(
        'Validation failed',
        details: ['Duplicate IP 192.168.1.10', 'Missing owner on line 5'],
      );

      expect(importFailure.details.length, equals(2));
      expect(importFailure.details.first, contains('Duplicate IP'));
    });
  });
}
