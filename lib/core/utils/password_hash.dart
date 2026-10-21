import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:argon2/argon2.dart';

/// Cryptographically secure, versioned Argon2id password hashing and verification.
///
/// Encoded format:
///   `$argon2id$v=<version>$m=<memory>,t=<iterations>,p=<lanes>$<base64_salt>$<base64_derived_hash>`
///
/// Backwards-compatible with legacy fixed-salt hashes:
/// Legacy hashes (unversioned raw base64 hashes) are verified using the legacy parameters
/// and should be automatically re-hashed with a fresh cryptographically random salt on next login.
class PasswordHash {
  static const String _legacySalt = 'IT_NETWORK_MONITOR_ARGON2ID_SALT_2026';
  static const int _defaultIterations = 2;
  static const int _defaultMemory = 19456;
  static const int _defaultLanes = 1;
  static const int _saltByteLength = 16;
  static const int _derivedKeyByteLength = 32;

  /// Returns true if [storedHash] is an old unversioned fixed-salt hash that should be upgraded.
  static bool needsRehash(String storedHash) {
    return !storedHash.startsWith(r'$argon2id$');
  }

  /// Hashes [password] using Argon2id with a cryptographically secure, random 16-byte salt.
  ///
  /// Returns a standard versioned hash string:
  /// `$argon2id$v=19$m=19456,t=2,p=1$<b64_salt>$<b64_hash>`
  static String hashPassword(
    String password, {
    int iterations = _defaultIterations,
    int memory = _defaultMemory,
    int lanes = _defaultLanes,
  }) {
    final random = Random.secure();
    final saltBytes = Uint8List.fromList(
      List<int>.generate(_saltByteLength, (_) => random.nextInt(256)),
    );

    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      saltBytes,
      iterations: iterations,
      memory: memory,
      lanes: lanes,
    );

    final generator = Argon2BytesGenerator();
    generator.init(parameters);
    final result = Uint8List(_derivedKeyByteLength);
    generator.generateBytes(utf8.encode(password), result, 0, result.length);

    final b64Salt = base64.encode(saltBytes);
    final b64Hash = base64.encode(result);

    return '\$argon2id\$v=19\$m=$memory,t=$iterations,p=$lanes\$$b64Salt\$$b64Hash';
  }

  /// Verifies [password] against [storedHash].
  ///
  /// Supports:
  /// 1. Versioned `$argon2id$v=19$m=...,t=...,p=...$<salt>$<hash>` format with constant-time byte comparison.
  /// 2. Legacy unversioned base64 hashes generated with the historical fixed salt.
  /// Returns `false` safely for malformed, corrupted, or unsupported hash strings.
  static bool verifyPassword(String password, String storedHash) {
    if (storedHash.isEmpty) return false;

    if (storedHash.startsWith(r'$argon2id$')) {
      return _verifyVersionedArgon2id(password, storedHash);
    }

    // Fall back to legacy fixed-salt verification for seamless user account continuity
    return _verifyLegacyHash(password, storedHash);
  }

  static bool _verifyVersionedArgon2id(String password, String encoded) {
    try {
      final parts = encoded.split(r'$');
      // Format: ['', 'argon2id', 'v=19', 'm=19456,t=2,p=1', '<salt>', '<hash>']
      if (parts.length != 6) return false;
      if (parts[1] != 'argon2id') return false;
      if (parts[2] != 'v=19') return false;

      final paramParts = parts[3].split(',');
      int? memory;
      int? iterations;
      int? lanes;

      for (final p in paramParts) {
        final kv = p.split('=');
        if (kv.length == 2) {
          if (kv[0] == 'm') memory = int.tryParse(kv[1]);
          if (kv[0] == 't') iterations = int.tryParse(kv[1]);
          if (kv[0] == 'p') lanes = int.tryParse(kv[1]);
        }
      }

      if (memory == null || iterations == null || lanes == null) {
        return false;
      }
      if (memory <= 0 || iterations <= 0 || lanes <= 0) {
        return false;
      }

      final saltBytes = base64.decode(parts[4]);
      final expectedHashBytes = base64.decode(parts[5]);

      final parameters = Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        saltBytes,
        iterations: iterations,
        memory: memory,
        lanes: lanes,
      );

      final generator = Argon2BytesGenerator();
      generator.init(parameters);
      final derivedBytes = Uint8List(expectedHashBytes.length);
      generator.generateBytes(
        utf8.encode(password),
        derivedBytes,
        0,
        derivedBytes.length,
      );

      return _constantTimeEquals(
        derivedBytes,
        Uint8List.fromList(expectedHashBytes),
      );
    } catch (_) {
      // Fail closed safely on malformed or invalid base64 input
      return false;
    }
  }

  static bool _verifyLegacyHash(String password, String legacyHash) {
    try {
      final parameters = Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        utf8.encode(_legacySalt),
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

      final expectedBytes = base64.decode(legacyHash);
      return _constantTimeEquals(
        derivedBytes,
        Uint8List.fromList(expectedBytes),
      );
    } catch (_) {
      return false;
    }
  }

  /// Constant-time byte array comparison to prevent timing side-channel attacks.
  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
