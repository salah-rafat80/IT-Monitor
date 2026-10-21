/// Shared core IPv4 utilities and canonicalization logic.
///
/// Keeps core infrastructure (such as database migrations) independent
/// of outer feature domain layers (Clean Architecture layer compliance).
class Ipv4Utils {
  /// Canonicalizes an IPv4 string into standard dotted-decimal notation
  /// (e.g. " 192.168.01.001 " -> "192.168.1.1").
  ///
  /// Returns `null` if the input is not a valid 4-octet IPv4 address (e.g.,
  /// invalid character, fewer or more than 4 octets, octet value > 255).
  static String? canonicalizeIpv4(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('.');
    if (parts.length != 4) return null;

    final canonicalOctets = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final parsed = int.tryParse(part);
      if (parsed == null || parsed < 0 || parsed > 255) {
        return null;
      }
      canonicalOctets.add(parsed);
    }

    return canonicalOctets.join('.');
  }
}
