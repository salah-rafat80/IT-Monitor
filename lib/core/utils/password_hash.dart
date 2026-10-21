import 'dart:convert';
import 'dart:typed_data';
import 'package:argon2/argon2.dart';

class PasswordHash {
  static const String _defaultSalt = 'IT_NETWORK_MONITOR_ARGON2ID_SALT_2026';

  static String hashPassword(String password) {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      utf8.encode(_defaultSalt),
      iterations: 2,
      memory: 19456,
      lanes: 1,
    );
    final generator = Argon2BytesGenerator();
    generator.init(parameters);
    final result = Uint8List(32);
    generator.generateBytes(utf8.encode(password), result, 0, result.length);
    return base64.encode(result);
  }

  static bool verifyPassword(String password, String hashedPassword) {
    return hashPassword(password) == hashedPassword;
  }
}
