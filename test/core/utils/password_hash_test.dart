import 'dart:convert';
import 'dart:typed_data';
import 'package:argon2/argon2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_network_monitor/core/utils/password_hash.dart';

void main() {
  group('PasswordHash Security & Regression Tests', () {
    const password = 'CorrectHorseBatteryStaple2026!';
    const wrongPassword = 'WrongPassword123!';

    test(
      '1. Hashing the same password twice produces different salts and hashes',
      () {
        final hash1 = PasswordHash.hashPassword(password);
        final hash2 = PasswordHash.hashPassword(password);

        expect(hash1, isNotEmpty);
        expect(hash2, isNotEmpty);
        expect(hash1, startsWith(r'$argon2id$v=19$m=19456,t=2,p=1$'));
        expect(hash2, startsWith(r'$argon2id$v=19$m=19456,t=2,p=1$'));
        // Cryptographically random 16-byte salt must ensure unique hash representations
        expect(hash1, isNot(equals(hash2)));
      },
    );

    test(
      '2. Both independently generated hashes verify successfully with correct password',
      () {
        final hash1 = PasswordHash.hashPassword(password);
        final hash2 = PasswordHash.hashPassword(password);

        expect(PasswordHash.verifyPassword(password, hash1), isTrue);
        expect(PasswordHash.verifyPassword(password, hash2), isTrue);
      },
    );

    test('3. Incorrect password fails verification', () {
      final hash = PasswordHash.hashPassword(password);

      expect(PasswordHash.verifyPassword(wrongPassword, hash), isFalse);
      expect(PasswordHash.verifyPassword('', hash), isFalse);
    });

    test(
      '4. Legacy fixed-salt hashes remain verifiable for backward compatibility',
      () {
        // Generate a legacy hash matching the historical fixed-salt algorithm
        const legacySalt = 'IT_NETWORK_MONITOR_ARGON2ID_SALT_2026';
        final parameters = Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          utf8.encode(legacySalt),
          iterations: 2,
          memory: 19456,
          lanes: 1,
        );
        final generator = Argon2BytesGenerator();
        generator.init(parameters);
        final derivedBytes = Uint8List(32);
        generator.generateBytes(
          utf8.encode(password),
          derivedBytes,
          0,
          derivedBytes.length,
        );
        final legacyStoredHash = base64.encode(derivedBytes);

        // Verify that needsRehash detects this as a legacy hash needing upgrade
        expect(PasswordHash.needsRehash(legacyStoredHash), isTrue);

        // Verify password succeeds against legacy hash
        expect(PasswordHash.verifyPassword(password, legacyStoredHash), isTrue);

        // Incorrect password fails against legacy hash
        expect(
          PasswordHash.verifyPassword(wrongPassword, legacyStoredHash),
          isFalse,
        );
      },
    );

    test('5. Versioned hashes do not require rehash', () {
      final hash = PasswordHash.hashPassword(password);
      expect(PasswordHash.needsRehash(hash), isFalse);
    });

    test(
      '6. Malformed, corrupted, or unsupported hashes fail safely without throwing',
      () {
        expect(PasswordHash.verifyPassword(password, ''), isFalse);
        expect(
          PasswordHash.verifyPassword(password, 'not_a_valid_hash'),
          isFalse,
        );
        expect(
          PasswordHash.verifyPassword(password, r'$argon2id$v=99$invalid'),
          isFalse,
        );
        expect(
          PasswordHash.verifyPassword(
            password,
            r'$argon2id$v=19$m=-1,t=2,p=1$abc$def',
          ),
          isFalse,
        );
        expect(
          PasswordHash.verifyPassword(
            password,
            r'$argon2id$v=19$m=abc,t=2,p=1$abc$def',
          ),
          isFalse,
        );
        expect(
          PasswordHash.verifyPassword(
            password,
            r'$argon2id$v=19$m=19456,t=2,p=1$notBase64!@#$notBase64!@#',
          ),
          isFalse,
        );
        expect(
          PasswordHash.verifyPassword(
            password,
            r'$argon2d$v=19$m=19456,t=2,p=1$abc$def',
          ),
          isFalse,
        );
      },
    );

    test(
      '7. Verification handles custom parameters encoded in versioned hash',
      () {
        // Hash with custom cost parameters
        final customHash = PasswordHash.hashPassword(
          password,
          iterations: 3,
          memory: 20480,
          lanes: 2,
        );

        expect(customHash, contains('m=20480,t=3,p=2'));
        expect(PasswordHash.verifyPassword(password, customHash), isTrue);
        expect(PasswordHash.verifyPassword(wrongPassword, customHash), isFalse);
      },
    );
  });
}
