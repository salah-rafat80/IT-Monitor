import 'package:injectable/injectable.dart';

import '../../../monitoring/domain/entities/monitored_device.dart';
import '../entities/topology_node.dart';

/// Groups a flat list of [MonitoredDevice] records into a structured
/// topology: Location → Switch Group → Devices.
///
/// Rules (from master plan §27 Phase 7):
/// - Use `device.officeLocation` as the location key.
/// - Use `device.parentSwitchName` as the switch key within a location.
/// - Devices with no `officeLocation` are placed under an "Unknown Location" node.
/// - Devices with no `parentSwitchName` are placed under a null-keyed switch group.
/// - No switch IPs or invented relationships are used.
@lazySingleton
class TopologyGrouper {
  const TopologyGrouper();

  static const String _unknownLocation = 'Unknown Location';

  List<LocationNode> group(List<MonitoredDevice> devices) {
    // Step 1: bucket by location.
    final Map<String, List<MonitoredDevice>> byLocation = {};
    for (final md in devices) {
      final loc = md.device.officeLocation?.isNotEmpty == true
          ? md.device.officeLocation!
          : _unknownLocation;
      byLocation.putIfAbsent(loc, () => []).add(md);
    }

    // Step 2: within each location, bucket by switch name.
    final List<LocationNode> nodes = [];
    for (final entry in byLocation.entries) {
      final Map<String?, List<MonitoredDevice>> bySwitch = {};
      for (final md in entry.value) {
        final sw = md.device.parentSwitchName?.isNotEmpty == true
            ? md.device.parentSwitchName
            : null;
        bySwitch.putIfAbsent(sw, () => []).add(md);
      }

      // Sort switch groups: known switches first (alphabetically), then null.
      final sortedSwitchKeys = bySwitch.keys.toList()
        ..sort((a, b) {
          if (a == null && b == null) return 0;
          if (a == null) return 1;
          if (b == null) return -1;
          return a.compareTo(b);
        });

      final switchGroups = sortedSwitchKeys
          .map(
            (sw) => SwitchGroup(
              switchName: sw,
              devices: bySwitch[sw]!
                ..sort(
                  (a, b) => a.device.ownerName.compareTo(b.device.ownerName),
                ),
            ),
          )
          .toList();

      nodes.add(
        LocationNode(locationName: entry.key, switchGroups: switchGroups),
      );
    }

    // Sort location nodes alphabetically, Unknown Location last.
    nodes.sort((a, b) {
      if (a.locationName == _unknownLocation) return 1;
      if (b.locationName == _unknownLocation) return -1;
      return a.locationName.compareTo(b.locationName);
    });

    return nodes;
  }
}
