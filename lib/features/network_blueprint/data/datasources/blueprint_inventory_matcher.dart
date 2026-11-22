import 'package:injectable/injectable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/blueprint_element_entity.dart';
import '../../domain/entities/blueprint_page_entity.dart';

@lazySingleton
class BlueprintInventoryMatcher {
  static final RegExp _ipRegex = RegExp(r'192\.168\.\d+\.\d+');
  static final RegExp _shortIpRegex = RegExp(r'(?:^|[^\d])(\d{1,3}\.\d{1,3})(?:[^\d]|$)');

  /// Matches elements in a list of pages against registered inventory devices
  /// and applies live monitoring health statuses.
  List<BlueprintPageEntity> matchPages({
    required List<BlueprintPageEntity> pages,
    required List<DeviceEntity> inventoryDevices,
    required Map<int, DeviceStatusEntity> liveStatuses,
  }) {
    // Map devices by normalized IP and lower-case name
    final devicesByIp = <String, DeviceEntity>{};
    final devicesByName = <String, DeviceEntity>{};

    for (final dev in inventoryDevices) {
      final ipTrimmed = dev.ip.trim();
      if (ipTrimmed.isNotEmpty) {
        devicesByIp[ipTrimmed] = dev;
      }
      final nameTrimmed = dev.name.trim().toLowerCase();
      if (nameTrimmed.isNotEmpty) {
        devicesByName[nameTrimmed] = dev;
      }
    }

    return pages.map((page) {
      final matchedElements = page.elements.map((el) {
        return _matchElement(el, devicesByIp, devicesByName, liveStatuses);
      }).toList();

      return page.copyWith(elements: matchedElements);
    }).toList();
  }

  BlueprintElementEntity _matchElement(
    BlueprintElementEntity element,
    Map<String, DeviceEntity> devicesByIp,
    Map<String, DeviceEntity> devicesByName,
    Map<int, DeviceStatusEntity> liveStatuses,
  ) {
    // 1. Try IP extraction from labels
    final extractedIp = _extractIp(element.rawLabel) ?? _extractIp(element.englishLabel);

    DeviceEntity? matchedDevice;
    var confidence = BlueprintMappingConfidence.unmapped;

    if (extractedIp != null && devicesByIp.containsKey(extractedIp)) {
      matchedDevice = devicesByIp[extractedIp];
      confidence = BlueprintMappingConfidence.confirmedIp;
    } else if (element.englishLabel.trim().isNotEmpty) {
      // 2. Try Name matching
      final cleanName = element.englishLabel.trim().toLowerCase();
      if (devicesByName.containsKey(cleanName)) {
        matchedDevice = devicesByName[cleanName];
        confidence = BlueprintMappingConfidence.candidate;
      }
    }

    // 3. Extract live status if device matched
    DeviceStatusEnum? liveStatus;
    int? latency;
    DateTime? lastCheck;

    if (matchedDevice != null && liveStatuses.containsKey(matchedDevice.id)) {
      final status = liveStatuses[matchedDevice.id]!;
      liveStatus = status.status;
      latency = status.lastLatencyMs;
      lastCheck = status.lastCheckAt;
    }

    return element.copyWith(
      mappedDeviceId: matchedDevice?.id,
      mappedDeviceName: matchedDevice?.name,
      mappedIp: matchedDevice?.ip ?? extractedIp,
      mappingConfidence: confidence,
      liveStatus: liveStatus,
      lastLatencyMs: latency,
      lastCheckAt: lastCheck,
    );
  }

  String? _extractIp(String text) {
    if (text.isEmpty) return null;

    // Full 192.168.x.x
    final match = _ipRegex.firstMatch(text);
    if (match != null) {
      return match.group(0);
    }

    // Subnet shorthand e.g. "22.117" or ".22.117"
    final shortMatch = _shortIpRegex.firstMatch(text);
    if (shortMatch != null) {
      final part = shortMatch.group(1);
      if (part != null && (part.startsWith('22.') || part.startsWith('21.') || part.startsWith('20.'))) {
        return '192.168.$part';
      }
    }

    return null;
  }
}
