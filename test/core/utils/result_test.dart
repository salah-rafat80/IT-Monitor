import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/errors/failures.dart';
import 'package:it_network_monitor/core/utils/result.dart';

void main() {
  group('Result Abstraction Unit Tests', () {
    test('Success result holds data and isSuccess is true', () {
      final result = Result<String>.success('Operational');

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals('Operational'));
      expect(result.failureOrNull, isNull);
    });

    test('Failure result holds failure and isFailure is true', () {
      const failure = DatabaseFailure('DB connection failed');
      final result = Result<String>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));
    });

    test('fold evaluates onSuccess for Success result', () {
      final result = Result<int>.success(42);

      final val = result.fold(
        onSuccess: (data) => 'Value: $data',
        onFailure: (failure) => 'Error',
      );

      expect(val, equals('Value: 42'));
    });

    test('fold evaluates onFailure for Failure result', () {
      const failure = PingFailure('Timeout');
      final result = Result<int>.failure(failure);

      final val = result.fold(
        onSuccess: (data) => 'Value: $data',
        onFailure: (f) => f.message,
      );

      expect(val, equals('Timeout'));
    });
  });
}
