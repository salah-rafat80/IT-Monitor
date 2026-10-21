import 'dart:io';
import 'package:injectable/injectable.dart';

import '../../../domain/services/discovery_strategy.dart';
import '../../../domain/services/mac_vendor_lookup.dart';

@lazySingleton
class ArpDiscoveryStrategy implements DiscoveryStrategy {
  final MacVendorLookup _vendorLookup;

  ArpDiscoveryStrategy(this._vendorLookup);

  @override
  String get name => 'arp';

  @override
  Future<StrategyProbeResult> probe(String targetIp, Duration timeout) async {
    try {
      if (!Platform.isWindows) {
        return StrategyProbeResult.failure(
          strategyName: name,
          targetIp: targetIp,
          errorMessage: 'ARP inspection currently optimized for Windows host',
        );
      }

      // Query Windows ARP table for the specific IP
      final result =
          await Process.run('arp', ['-a', targetIp], runInShell: true).timeout(
            const Duration(seconds: 2),
            onTimeout: () => ProcessResult(-1, -1, '', 'ARP query timeout'),
          );

      final stdout = result.stdout.toString();
      final mac = _extractMacAddress(stdout, targetIp);

      if (mac != null) {
        final normalizedMac = _vendorLookup.normalizeMac(mac);
        final vendor = _vendorLookup.lookupVendor(normalizedMac);
        final details = vendor != null
            ? 'ARP MAC: $normalizedMac ($vendor)'
            : 'ARP MAC: $normalizedMac';

        return StrategyProbeResult.success(
          strategyName: name,
          targetIp: targetIp,
          mac: normalizedMac,
          evidenceDetails: details,
        );
      } else {
        return StrategyProbeResult.failure(
          strategyName: name,
          targetIp: targetIp,
          errorMessage: 'No active ARP table entry found for $targetIp',
        );
      }
    } catch (e) {
      return StrategyProbeResult.failure(
        strategyName: name,
        targetIp: targetIp,
        errorMessage: 'ARP execution error: $e',
      );
    }
  }

  static String? _extractMacAddress(String stdout, String targetIp) {
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.contains(targetIp)) {
        // Find MAC format xx-xx-xx-xx-xx-xx or xx:xx:xx:xx:xx:xx
        final match = RegExp(
          r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})',
        ).firstMatch(trimmed);
        if (match != null) {
          final candidate = match.group(0);
          // Ignore broadcast/multicast (ff-ff-ff-ff-ff-ff, 01-00-5e-*, etc.)
          if (candidate != null &&
              !candidate.toLowerCase().startsWith('ff') &&
              !candidate.toLowerCase().startsWith('01-00-5e')) {
            return candidate;
          }
        }
      }
    }
    return null;
  }
}
