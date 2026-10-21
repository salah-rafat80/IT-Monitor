import 'package:injectable/injectable.dart';

import '../entities/classification_confidence.dart';
import '../entities/device_category.dart';
import '../entities/discovery_evidence_item.dart';
import 'mac_vendor_lookup.dart';

class ClassificationDecision {
  final DeviceCategory category;
  final ClassificationConfidence confidence;
  final List<String> reasons;

  const ClassificationDecision({
    required this.category,
    required this.confidence,
    required this.reasons,
  });
}

@lazySingleton
class DeviceClassificationEngine {
  final MacVendorLookup _vendorLookup;

  DeviceClassificationEngine(this._vendorLookup);

  ClassificationDecision classify({
    required String ip,
    String? mac,
    String? hostname,
    List<String> observedServices = const [],
    List<DiscoveryEvidenceItem> evidence = const [],
    DeviceCategory? adminOverride,
    bool isKnownInventoryDevice = false,
  }) {
    // 1. Admin Override always takes strict precedence
    if (adminOverride != null) {
      return ClassificationDecision(
        category: adminOverride,
        confidence: ClassificationConfidence.high,
        reasons: [
          'Admin user confirmed category explicitly as ${adminOverride.displayName}',
        ],
      );
    }

    // 2. Already Known in Production Monitored Inventory
    if (isKnownInventoryDevice) {
      return const ClassificationDecision(
        category: DeviceCategory.pc,
        confidence: ClassificationConfidence.high,
        reasons: [
          'IP matched in approved production inventory database (PC/Laptop)',
        ],
      );
    }

    final reasons = <String>[];
    final vendor = _vendorLookup.lookupVendor(mac);
    final vendorLower = vendor?.toLowerCase() ?? '';
    final hostnameLower = hostname?.toLowerCase() ?? '';
    final servicesLower = observedServices.map((s) => s.toLowerCase()).toSet();

    // Check 3: IP Camera (ONVIF, RTSP 554, Camera Vendors)
    final hasOnvif = evidence.any(
      (e) => e.strategyName == 'onvif' && e.isSuccess,
    );
    final hasRtsp =
        servicesLower.contains('rtsp') || servicesLower.contains('port:554');
    final isCameraVendor =
        vendorLower.contains('hikvision') ||
        vendorLower.contains('dahua') ||
        vendorLower.contains('axis') ||
        vendorLower.contains('hanwha') ||
        vendorLower.contains('uniview');

    if (hasOnvif) {
      reasons.add('Verified ONVIF WS-Discovery probe response received');
      return ClassificationDecision(
        category: DeviceCategory.ipCamera,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (hasRtsp && isCameraVendor) {
      reasons.add(
        'RTSP service (port 554) open and verified camera vendor ($vendor)',
      );
      return ClassificationDecision(
        category: DeviceCategory.ipCamera,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (hasRtsp) {
      reasons.add('RTSP streaming port (554) open');
      return ClassificationDecision(
        category: DeviceCategory.ipCamera,
        confidence: ClassificationConfidence.medium,
        reasons: reasons,
      );
    }

    // Check 4: Printer (Port 9100 RAW, Port 631 IPP, Printer Vendors)
    final hasRawPrint =
        servicesLower.contains('port:9100') ||
        servicesLower.contains('raw-print');
    final hasIpp =
        servicesLower.contains('port:631') || servicesLower.contains('ipp');
    final isPrinterVendor =
        vendorLower.contains('printer') ||
        vendorLower.contains('canon') ||
        vendorLower.contains('epson') ||
        vendorLower.contains('brother') ||
        vendorLower.contains('xerox') ||
        vendorLower.contains('lexmark') ||
        vendorLower.contains('ricoh');

    if ((hasRawPrint || hasIpp) && isPrinterVendor) {
      reasons.add(
        'Print spooler port active (9100/631) and manufacturer is $vendor',
      );
      return ClassificationDecision(
        category: DeviceCategory.printer,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (hasRawPrint || hasIpp) {
      reasons.add('Network print spooler port active (9100/631)');
      return ClassificationDecision(
        category: DeviceCategory.printer,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (isPrinterVendor &&
        (hostnameLower.contains('print') ||
            hostnameLower.contains('hp') ||
            hostnameLower.contains('canon'))) {
      reasons.add(
        'Printer manufacturer ($vendor) and hostname pattern ($hostname)',
      );
      return ClassificationDecision(
        category: DeviceCategory.printer,
        confidence: ClassificationConfidence.medium,
        reasons: reasons,
      );
    }

    // Check 5: Network Infrastructure (Switch, Router, AP)
    final isMikrotik = vendorLower.contains('mikrotik');
    final isCisco = vendorLower.contains('cisco');
    final isUbiquiti = vendorLower.contains('ubiquiti');
    final isTpLink = vendorLower.contains('tp-link');

    if (hostnameLower.contains('switch') ||
        hostnameLower.contains('sw-') ||
        hostnameLower.contains('sw0')) {
      reasons.add(
        'Host naming convention indicates switch infrastructure ($hostname)',
      );
      return ClassificationDecision(
        category: DeviceCategory.switchDevice,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (hostnameLower.contains('router') ||
        hostnameLower.contains('gw-') ||
        hostnameLower.contains('gateway')) {
      reasons.add(
        'Host naming convention indicates router / gateway ($hostname)',
      );
      return ClassificationDecision(
        category: DeviceCategory.router,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (hostnameLower.contains('ap-') ||
        hostnameLower.contains('unifi') ||
        hostnameLower.contains('wap')) {
      reasons.add('Host naming indicates wireless access point ($hostname)');
      return ClassificationDecision(
        category: DeviceCategory.wirelessAccessPoint,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }
    if (isCisco || isMikrotik || isUbiquiti || isTpLink) {
      reasons.add('MAC vendor belongs to enterprise network vendor: $vendor');
      return ClassificationDecision(
        category: DeviceCategory.otherNetworkDevice,
        confidence: ClassificationConfidence.medium,
        reasons: reasons,
      );
    }

    // Check 6: Server
    final isVmware =
        vendorLower.contains('vmware') || vendorLower.contains('hyper-v');
    final hasSsh =
        servicesLower.contains('port:22') || servicesLower.contains('ssh');
    final isServerHost =
        hostnameLower.contains('srv') ||
        hostnameLower.contains('server') ||
        hostnameLower.contains('dc0') ||
        hostnameLower.contains('esxi');

    if (isServerHost || (isVmware && hasSsh)) {
      reasons.add(
        'Server indicator in hostname ($hostname) or virtualization stack ($vendor)',
      );
      return ClassificationDecision(
        category: DeviceCategory.server,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }

    // Check 7: Mobile Device (Apple iPhone/iPad, Android vendors, mDNS Cast/AirPlay)
    final isMobileVendor =
        vendorLower.contains('iphone') ||
        vendorLower.contains('ipad') ||
        vendorLower.contains('xiaomi') ||
        (vendorLower.contains('samsung') && !isPrinterVendor);

    if (isMobileVendor &&
        !servicesLower.contains('port:445') &&
        !servicesLower.contains('port:139')) {
      reasons.add(
        'Vendor is consumer mobile device ($vendor) with no desktop sharing ports',
      );
      return ClassificationDecision(
        category: DeviceCategory.mobile,
        confidence: ClassificationConfidence.medium,
        reasons: reasons,
      );
    }

    // Check 8: PC / Laptop
    final isPcVendor =
        vendorLower.contains('dell') ||
        vendorLower.contains('lenovo') ||
        vendorLower.contains('hewlett-packard') ||
        vendorLower.contains('hp inc') ||
        vendorLower.contains('surface') ||
        vendorLower.contains('asustek') ||
        vendorLower.contains('acer') ||
        vendorLower.contains('intel');

    final isCorporateHost =
        hostnameLower.startsWith('pc-') ||
        hostnameLower.startsWith('laptop-') ||
        hostnameLower.startsWith('lt-') ||
        hostnameLower.startsWith('rnf-') ||
        hostnameLower.startsWith('maint-') ||
        hostnameLower.startsWith('fin-') ||
        hostnameLower.startsWith('ppic-');

    if (isCorporateHost) {
      final isLaptop =
          hostnameLower.contains('laptop') ||
          hostnameLower.contains('nb') ||
          hostnameLower.contains('lt');
      reasons.add('Corporate hostname naming convention matched: $hostname');
      return ClassificationDecision(
        category: isLaptop ? DeviceCategory.laptop : DeviceCategory.pc,
        confidence: ClassificationConfidence.high,
        reasons: reasons,
      );
    }

    if (isPcVendor) {
      reasons.add('Workstation / PC manufacturer identified ($vendor)');
      return ClassificationDecision(
        category: DeviceCategory.pc,
        confidence: ClassificationConfidence.medium,
        reasons: reasons,
      );
    }

    // Fallback: If device responded to ICMP or ARP, but has no identifiable fingerprint
    if (evidence.any((e) => e.isSuccess)) {
      reasons.add(
        'Device responded on network but fingerprint evidence is insufficient for conclusive classification',
      );
      return ClassificationDecision(
        category: DeviceCategory.unknown,
        confidence: ClassificationConfidence.unknown,
        reasons: reasons,
      );
    }

    return const ClassificationDecision(
      category: DeviceCategory.unknown,
      confidence: ClassificationConfidence.unknown,
      reasons: ['No response or fingerprint evidence available'],
    );
  }
}
