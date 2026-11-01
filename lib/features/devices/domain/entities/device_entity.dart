import 'package:equatable/equatable.dart';

enum DeviceType {
  pc,
  laptop,
  mobile,
  ipCamera,
  printer,
  server,
  switchDevice,
  router,
  wirelessAccessPoint,
  otherNetworkDevice,
  other,
  unknown;

  static DeviceType fromString(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    switch (normalized) {
      case 'laptop':
      case 'notebook':
        return DeviceType.laptop;
      case 'pc':
      case 'desktop':
      case 'workstation':
      case 'pc_workstation':
        return DeviceType.pc;
      case 'mobile':
      case 'phone':
      case 'smartphone':
      case 'tablet':
      case 'mobile_device':
        return DeviceType.mobile;
      case 'ip_camera':
      case 'camera':
      case 'cctv':
      case 'nvr':
        return DeviceType.ipCamera;
      case 'printer':
      case 'scanner':
      case 'copier':
      case 'mfp':
        return DeviceType.printer;
      case 'server':
        return DeviceType.server;
      case 'switch':
      case 'switch_device':
      case 'network_switch':
        return DeviceType.switchDevice;
      case 'router':
      case 'gateway':
      case 'router_gateway':
        return DeviceType.router;
      case 'access_point':
      case 'ap':
      case 'wireless_access_point':
      case 'wap':
      case 'wireless_ap':
        return DeviceType.wirelessAccessPoint;
      case 'other_network_device':
      case 'network_device':
      case 'network_equipment':
        return DeviceType.otherNetworkDevice;
      case 'other':
      case 'other_asset':
        return DeviceType.other;
      case 'unknown':
        return DeviceType.unknown;
    }

    // Heuristic fallbacks:
    if (normalized.contains('switch')) {
      return DeviceType.switchDevice;
    }
    if (normalized.contains('router') || normalized.contains('gateway')) {
      return DeviceType.router;
    }
    if (normalized.contains('access_point') ||
        normalized.contains('wireless') ||
        normalized.contains('wap')) {
      return DeviceType.wirelessAccessPoint;
    }
    if (normalized.contains('camera') || normalized.contains('cctv')) {
      return DeviceType.ipCamera;
    }
    if (normalized.contains('print') || normalized.contains('scan')) {
      return DeviceType.printer;
    }
    if (normalized.contains('server')) {
      return DeviceType.server;
    }
    if (normalized.contains('laptop') || normalized.contains('notebook')) {
      return DeviceType.laptop;
    }
    if (normalized.contains('phone') ||
        normalized.contains('mobile') ||
        normalized.contains('tablet')) {
      return DeviceType.mobile;
    }
    if (normalized.contains('workstation') ||
        normalized.contains('desktop') ||
        normalized.contains('pc')) {
      return DeviceType.pc;
    }

    return DeviceType.pc;
  }

  String toValue() {
    switch (this) {
      case DeviceType.pc:
        return 'pc';
      case DeviceType.laptop:
        return 'laptop';
      case DeviceType.mobile:
        return 'mobile';
      case DeviceType.ipCamera:
        return 'ip_camera';
      case DeviceType.printer:
        return 'printer';
      case DeviceType.server:
        return 'server';
      case DeviceType.switchDevice:
        return 'switch';
      case DeviceType.router:
        return 'router';
      case DeviceType.wirelessAccessPoint:
        return 'access_point';
      case DeviceType.otherNetworkDevice:
        return 'other_network_device';
      case DeviceType.other:
        return 'other';
      case DeviceType.unknown:
        return 'unknown';
    }
  }

  String get displayName {
    switch (this) {
      case DeviceType.pc:
        return 'PC / Workstation';
      case DeviceType.laptop:
        return 'Laptop';
      case DeviceType.mobile:
        return 'Mobile Device';
      case DeviceType.ipCamera:
        return 'IP Camera';
      case DeviceType.printer:
        return 'Printer';
      case DeviceType.server:
        return 'Server';
      case DeviceType.switchDevice:
        return 'Network Switch';
      case DeviceType.router:
        return 'Router / Gateway';
      case DeviceType.wirelessAccessPoint:
        return 'Wireless Access Point';
      case DeviceType.otherNetworkDevice:
        return 'Network Equipment';
      case DeviceType.other:
        return 'Other Asset';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  bool get isMonitoredByDefault {
    switch (this) {
      case DeviceType.pc:
      case DeviceType.laptop:
      case DeviceType.server:
        return true;
      default:
        return false;
    }
  }
}

class DeviceEntity extends Equatable {
  final int id;
  final String factoryId;
  final String name;
  final DeviceType type;
  final String ip;
  final String ownerName;
  final String department;
  final String? officeLocation;
  final int? parentSwitchId;
  final String? parentSwitchName;
  final String? vendor;
  final String? model;
  final String? mac;
  final String? hostname;
  final String? operatingSystem;
  final String? notes;
  final bool isMonitored;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DeviceEntity({
    required this.id,
    this.factoryId = 'unassigned',
    required this.name,
    required this.type,
    required this.ip,
    required this.ownerName,
    required this.department,
    this.officeLocation,
    this.parentSwitchId,
    this.parentSwitchName,
    this.vendor,
    this.model,
    this.mac,
    this.hostname,
    this.operatingSystem,
    this.notes,
    this.isMonitored = true,
    this.isEnabled = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Canonical display name for the assigned person.
  /// Strictly shows 'Unassigned' if empty or not set.
  String get displayOwner {
    final trimmed = ownerName.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'unassigned') {
      return 'Unassigned';
    }
    return trimmed;
  }

  /// Whether a real person name is currently assigned to this device.
  bool get isOwnerAssigned {
    final trimmed = ownerName.trim();
    return trimmed.isNotEmpty && trimmed.toLowerCase() != 'unassigned';
  }

  DeviceEntity copyWith({
    int? id,
    String? factoryId,
    String? name,
    DeviceType? type,
    String? ip,
    String? ownerName,
    String? department,
    String? officeLocation,
    int? parentSwitchId,
    String? parentSwitchName,
    String? vendor,
    String? model,
    String? mac,
    String? hostname,
    String? operatingSystem,
    String? notes,
    bool? isMonitored,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceEntity(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      name: name ?? this.name,
      type: type ?? this.type,
      ip: ip ?? this.ip,
      ownerName: ownerName ?? this.ownerName,
      department: department ?? this.department,
      officeLocation: officeLocation ?? this.officeLocation,
      parentSwitchId: parentSwitchId ?? this.parentSwitchId,
      parentSwitchName: parentSwitchName ?? this.parentSwitchName,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      mac: mac ?? this.mac,
      hostname: hostname ?? this.hostname,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      notes: notes ?? this.notes,
      isMonitored: isMonitored ?? this.isMonitored,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name,
      'type': type.toValue(),
      'ip': ip,
      'ownerName': ownerName,
      'department': department,
      'officeLocation': officeLocation,
      'parentSwitchId': parentSwitchId,
      'parentSwitchName': parentSwitchName,
      'vendor': vendor,
      'model': model,
      'mac': mac,
      'hostname': hostname,
      'operatingSystem': operatingSystem,
      'notes': notes,
      'isMonitored': isMonitored,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory DeviceEntity.fromJson(Map<String, dynamic> json) {
    return DeviceEntity(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      factoryId: json['factoryId']?.toString() ?? 'unassigned',
      name: json['name']?.toString() ?? '',
      type: DeviceType.fromString(json['type']?.toString() ?? 'pc'),
      ip: json['ip']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      officeLocation: json['officeLocation']?.toString(),
      parentSwitchId: json['parentSwitchId'] is int
          ? json['parentSwitchId'] as int
          : null,
      parentSwitchName: json['parentSwitchName']?.toString(),
      vendor: json['vendor']?.toString(),
      model: json['model']?.toString(),
      mac: json['mac']?.toString(),
      hostname: json['hostname']?.toString(),
      operatingSystem: json['operatingSystem']?.toString(),
      notes: json['notes']?.toString(),
      isMonitored: json['isMonitored'] != false,
      isEnabled: json['isEnabled'] != false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    factoryId,
    name,
    type,
    ip,
    ownerName,
    department,
    officeLocation,
    parentSwitchId,
    parentSwitchName,
    vendor,
    model,
    mac,
    hostname,
    operatingSystem,
    notes,
    isMonitored,
    isEnabled,
    createdAt,
    updatedAt,
  ];
}
