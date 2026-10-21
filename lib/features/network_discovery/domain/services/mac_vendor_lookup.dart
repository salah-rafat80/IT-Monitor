import 'package:injectable/injectable.dart';

@lazySingleton
class MacVendorLookup {
  /// Well-known IEEE OUI 24-bit prefixes mapped to manufacturer names.
  /// Bundled offline database ensuring zero untrusted network downloads at runtime.
  static final Map<String, String> _ouiDatabase = {
    // Cameras (Hikvision, Dahua, Axis, Hanwha, Uniview)
    '44:19:B6': 'Hikvision Digital Technology',
    'C4:2F:90': 'Hikvision Digital Technology',
    'BC:54:51': 'Hikvision Digital Technology',
    '00:12:12': 'Hikvision Digital Technology',
    '3C:EF:8C': 'Dahua Technology',
    '40:2C:76': 'Dahua Technology',
    '90:02:A9': 'Dahua Technology',
    '38:AF:29': 'Dahua Technology',
    '00:40:8C': 'Axis Communications',
    'AC:CC:8E': 'Axis Communications',
    '00:09:18': 'Hanwha Techwin (Samsung Techwin)',
    '1C:61:B4': 'Uniview Technologies',

    // Printers (HP, Canon, Epson, Brother, Xerox, Ricoh, Lexmark)
    '00:1E:0B': 'HP Inc. (Printer Division)',
    '00:17:A4': 'HP Inc.',
    '3C:D9:2B': 'HP Inc.',
    '00:00:85': 'Canon Inc.',
    '70:8A:09': 'Canon Inc.',
    '00:26:AB': 'Seiko Epson Corp.',
    '00:21:55': 'Epson Europe',
    '00:80:77': 'Brother Industries',
    '30:05:5C': 'Brother Industries',
    '00:00:AA': 'Xerox Corporation',
    '00:00:21': 'Ricoh Company',
    '00:04:00': 'Lexmark International',

    // PC / Laptop / Workstation (Dell, HP, Lenovo, Apple, Microsoft, Intel)
    '00:14:22': 'Dell Inc.',
    '18:66:DA': 'Dell Inc.',
    'B8:2A:72': 'Dell Inc.',
    'D4:BE:D9': 'Dell Inc.',
    '00:21:70': 'Dell Inc.',
    '00:50:56': 'VMware Virtual Workstation',
    '00:0C:29': 'VMware Virtual Machine',
    '00:23:24': 'Lenovo Mobile/PC',
    'E8:6A:64': 'Lenovo ThinkPad/PC',
    '54:EE:75': 'Lenovo',
    '70:72:CF': 'Lenovo',
    '98:FA:9B': 'Lenovo',
    '00:1F:29': 'Hewlett-Packard',
    'A0:48:1C': 'Hewlett-Packard',
    '28:F1:0E': 'Microsoft Corporation (Surface)',
    '00:15:5D': 'Microsoft Hyper-V',
    '00:03:FF': 'Microsoft Corporation',
    'F8:75:A4': 'Apple Inc.',
    'A4:83:E7': 'Apple Inc.',
    'F0:18:98': 'Apple Inc.',
    'BC:D0:74': 'Apple Inc.',
    '70:85:C2': 'Apple Inc.',
    '00:1A:11': 'Google Inc.',
    '00:1B:21': 'Intel Corporate',
    '00:0E:0C': 'Intel Corporate',
    'F8:63:3F': 'ASUSTeK Computer',
    '00:1F:C6': 'ASUSTeK Computer',
    '00:1B:FC': 'Acer Inc.',

    // Mobile (Samsung, Xiaomi, Apple, Google, Huawei, OnePlus, Oppo)
    '50:C7:BF': 'Samsung Electronics',
    '34:23:87': 'Samsung Electronics',
    '94:65:2D': 'Samsung Electronics',
    'BC:47:60': 'Samsung Electronics',
    '28:6C:07': 'Xiaomi Communications',
    '64:CC:2E': 'Xiaomi Communications',
    '78:02:F8': 'Xiaomi Communications',
    'AC:BC:32': 'Apple iPhone/iPad',
    'DC:08:0F': 'Apple iPhone/iPad',
    '20:DF:B9': 'Huawei Device Co.',
    '00:E0:FC': 'Huawei Technologies',

    // Network Equipment (Cisco, MikroTik, TP-Link, Ubiquiti, Netgear, D-Link, Arista, Juniper)
    '00:00:0C': 'Cisco Systems',
    '00:1D:A1': 'Cisco Systems',
    '00:27:0D': 'Cisco Systems',
    '6C:41:6A': 'Cisco Systems (Catalyst Switch)',
    '70:69:79': 'Cisco Systems',
    '48:8B:55': 'MikroTik RouterOS',
    '6C:3B:6B': 'MikroTik RouterOS',
    '74:4D:28': 'MikroTik RouterOS',
    'CC:2D:E0': 'MikroTik RouterOS',
    'E4:8D:8C': 'MikroTik RouterOS',
    'D4:61:9D': 'MikroTik RouterOS',
    '00:27:22': 'Ubiquiti Inc. (UniFi)',
    '24:A4:3C': 'Ubiquiti Inc.',
    'B4:FB:E4': 'Ubiquiti Inc.',
    '78:8A:20': 'Ubiquiti Inc.',
    'F4:92:BF': 'Ubiquiti Inc.',
    '50:D4:F7': 'TP-Link Technologies',
    'E8:48:B8': 'TP-Link Technologies',
    'A0:F3:C1': 'TP-Link Technologies',
    '00:14:D1': 'Trendnet',
    '00:0F:B5': 'Netgear Inc.',
    '20:E5:2A': 'Netgear Inc.',
    '00:05:5D': 'D-Link Corporation',
    '1C:7E:E5': 'D-Link Corporation',
    '00:1C:73': 'Arista Networks',
    '00:12:1E': 'Juniper Networks',

    // Server / Storage / NAS
    '00:11:32': 'Synology Inc.',
    '00:08:9B': 'QNAP Systems',
    '00:25:90': 'Super Micro Computer',
    '00:30:48': 'Super Micro Computer',
  };

  /// Normalizes and cleans MAC string to standard format: XX:XX:XX:XX:XX:XX
  String? normalizeMac(String? rawMac) {
    if (rawMac == null) return null;
    final cleaned = rawMac
        .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
        .toUpperCase();
    if (cleaned.length != 12) return null;

    return '${cleaned.substring(0, 2)}:${cleaned.substring(2, 4)}:${cleaned.substring(4, 6)}:'
        '${cleaned.substring(6, 8)}:${cleaned.substring(8, 10)}:${cleaned.substring(10, 12)}';
  }

  /// Checks if MAC address is locally administered (randomized MAC)
  bool isLocallyAdministered(String? mac) {
    final normalized = normalizeMac(mac);
    if (normalized == null) return false;

    final firstByte = int.tryParse(normalized.substring(0, 2), radix: 16);
    if (firstByte == null) return false;

    // Bit 1 of first byte = 1 indicates locally administered / randomized address
    return (firstByte & 0x02) != 0;
  }

  /// Looks up manufacturer name by MAC address.
  /// Returns vendor name or 'Locally Administered / Randomized' or null.
  String? lookupVendor(String? mac) {
    final normalized = normalizeMac(mac);
    if (normalized == null) return null;

    if (isLocallyAdministered(normalized)) {
      return 'Locally Administered / Randomized MAC';
    }

    final prefix = normalized.substring(0, 8); // e.g. '00:14:22'
    if (_ouiDatabase.containsKey(prefix)) {
      return _ouiDatabase[prefix];
    }

    return null;
  }
}
