/// Single authoritative source of factory network configuration constants.
///
/// Properties:
/// - RNF: Gateway 192.168.22.1, Subnet Mask 255.255.255.0, Network CIDR 192.168.22.0/24
/// - BNF: Gateway 192.168.21.1, Subnet Mask 255.255.255.0, Network CIDR 192.168.21.0/24
///
/// NOTE: BNF Gateway is 192.168.21.1. Never replace BNF Gateway with 192.168.21.231.
class FactoryNetworkConfig {
  const FactoryNetworkConfig._();

  // Factory IDs
  static const String rnfId = 'rnf';
  static const String bnfId = 'bnf';
  static const String unassignedId = 'unassigned';

  // Factory Codes
  static const String rnfCode = 'RNF';
  static const String bnfCode = 'BNF';
  static const String unassignedCode = 'UNASSIGNED';

  // RNF Configuration
  static const String rnfName = 'RNF Factory';
  static const String rnfGatewayIp = '192.168.22.1';
  static const String rnfSubnetMask = '255.255.255.0';
  static const String rnfCidr = '192.168.22.0/24';

  // BNF Configuration
  static const String bnfName = 'BNF Factory';
  static const String bnfGatewayIp = '192.168.21.1';
  static const String bnfSubnetMask = '255.255.255.0';
  static const String bnfCidr = '192.168.21.0/24';

  // Default Monitoring Parameters
  static const int defaultMonitoringIntervalSeconds = 60;
  static const int defaultPingTimeoutSeconds = 3;
  static const int defaultChecksPerTargetPerCycle = 1;
  static const int defaultMaxConcurrentChecks = 20;
  static const int defaultFailureThreshold = 3;
  static const int defaultRecoveryThreshold = 1;
}
