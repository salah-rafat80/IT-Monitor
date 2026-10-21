import 'package:equatable/equatable.dart';

import '../../../monitoring/domain/entities/monitored_device.dart';

/// A switch group within a location: all devices sharing the same
/// [parentSwitchName] (or `null` for devices with no known switch).
class SwitchGroup extends Equatable {
  final String? switchName;
  final List<MonitoredDevice> devices;

  const SwitchGroup({required this.switchName, required this.devices});

  /// Display label — falls back to "Unknown Switch" when [switchName] is null.
  String get displayName => switchName ?? 'Unknown Switch';

  bool get hasKnownSwitch => switchName != null && switchName!.isNotEmpty;

  @override
  List<Object?> get props => [switchName, devices];
}

/// A location group containing one or more [SwitchGroup]s.
class LocationNode extends Equatable {
  final String locationName;
  final List<SwitchGroup> switchGroups;

  const LocationNode({required this.locationName, required this.switchGroups});

  /// Flat list of all devices in this location.
  List<MonitoredDevice> get allDevices =>
      switchGroups.expand((g) => g.devices).toList();

  int get totalCount => allDevices.length;

  @override
  List<Object?> get props => [locationName, switchGroups];
}
