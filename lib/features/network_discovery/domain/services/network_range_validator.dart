import 'package:injectable/injectable.dart';

import '../entities/network_range.dart';
import '../entities/reachability_status.dart';

@lazySingleton
class NetworkRangeValidator {
  /// Default approved company network ranges
  static const List<String> initialAuthorizedRanges = [
    '192.168.27.0/24',
    '192.168.22.0/24',
  ];

  /// Parses and validates a list of CIDR strings against corporate security limits.
  /// Bounded to prefix length between /16 and /30.
  List<NetworkRange> validateRanges(List<String> cidrList) {
    final validRanges = <NetworkRange>[];
    for (final raw in cidrList) {
      final parsed = NetworkRange.parse(raw);
      if (parsed != null) {
        validRanges.add(parsed);
      }
    }
    return validRanges;
  }

  /// Calculates total candidate host target count across all provided ranges.
  int calculateTotalUsableHosts(List<NetworkRange> ranges) {
    return ranges.fold<int>(0, (sum, r) => sum + r.usableHostsCount);
  }

  /// Returns true if the target IP falls within any of the authorized network ranges.
  bool isIpInScope(String ip, List<NetworkRange> authorizedRanges) {
    for (final range in authorizedRanges) {
      if (range.containsIp(ip)) {
        return true;
      }
    }
    return false;
  }

  /// Checks reachability of a range:
  /// Evaluates gateway or any responsive address in the subnet.
  ReachabilityStatus evaluateSubnetReachability({
    required NetworkRange range,
    required bool hasAnyResponse,
    required bool routingError,
  }) {
    if (routingError) {
      return ReachabilityStatus.inaccessible;
    }
    if (hasAnyResponse) {
      return ReachabilityStatus.reachable;
    }
    return ReachabilityStatus.partiallyReachable;
  }
}
