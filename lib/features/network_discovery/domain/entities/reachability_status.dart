enum ReachabilityStatus {
  rangeConfigured,
  reachabilityNotTested,
  reachable,
  partiallyReachable,
  inaccessible,
  scanCompleted,
  scanCompletedWithErrors;

  static ReachabilityStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('-', '_')) {
      case 'range_configured':
        return ReachabilityStatus.rangeConfigured;
      case 'reachable':
        return ReachabilityStatus.reachable;
      case 'partially_reachable':
        return ReachabilityStatus.partiallyReachable;
      case 'inaccessible':
        return ReachabilityStatus.inaccessible;
      case 'scan_completed':
        return ReachabilityStatus.scanCompleted;
      case 'scan_completed_with_errors':
        return ReachabilityStatus.scanCompletedWithErrors;
      case 'reachability_not_tested':
      default:
        return ReachabilityStatus.reachabilityNotTested;
    }
  }

  String toValue() => name;

  String get displayName {
    switch (this) {
      case ReachabilityStatus.rangeConfigured:
        return 'Range Configured';
      case ReachabilityStatus.reachabilityNotTested:
        return 'Reachability Not Tested';
      case ReachabilityStatus.reachable:
        return 'Reachable';
      case ReachabilityStatus.partiallyReachable:
        return 'Partially Reachable';
      case ReachabilityStatus.inaccessible:
        return 'Inaccessible';
      case ReachabilityStatus.scanCompleted:
        return 'Scan Completed';
      case ReachabilityStatus.scanCompletedWithErrors:
        return 'Scan Completed with Errors';
    }
  }
}
