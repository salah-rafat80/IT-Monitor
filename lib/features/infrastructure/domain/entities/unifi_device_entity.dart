import 'package:equatable/equatable.dart';

enum UniFiDeviceRole {
  gateway,
  controller,
  switchDevice,
  accessPoint,
  otherUnknown;

  String toValue() {
    switch (this) {
      case UniFiDeviceRole.gateway:
        return 'gateway';
      case UniFiDeviceRole.controller:
        return 'controller';
      case UniFiDeviceRole.switchDevice:
        return 'switch';
      case UniFiDeviceRole.accessPoint:
        return 'ap';
      case UniFiDeviceRole.otherUnknown:
        return 'other_unknown';
    }
  }

  String get displayName {
    switch (this) {
      case UniFiDeviceRole.gateway:
        return 'UniFi Gateway / Cloud Gateway';
      case UniFiDeviceRole.controller:
        return 'UniFi Controller / CloudKey';
      case UniFiDeviceRole.switchDevice:
        return 'UniFi Switch';
      case UniFiDeviceRole.accessPoint:
        return 'UniFi Access Point';
      case UniFiDeviceRole.otherUnknown:
        return 'Other / Unknown UniFi Device';
    }
  }

  static UniFiDeviceRole fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'gateway':
      case 'cloud_gateway':
      case 'udm':
      case 'usg':
        return UniFiDeviceRole.gateway;
      case 'controller':
      case 'cloudkey':
      case 'network_application':
        return UniFiDeviceRole.controller;
      case 'switch':
      case 'usw':
        return UniFiDeviceRole.switchDevice;
      case 'ap':
      case 'uap':
      case 'access_point':
        return UniFiDeviceRole.accessPoint;
      default:
        return UniFiDeviceRole.otherUnknown;
    }
  }
}

class UniFiDeviceEntity extends Equatable {
  final int id;
  final String name;
  final String ip;
  final String? mac;
  final UniFiDeviceRole role;
  final String? location;
  final bool isCriticalInfrastructure;
  final bool requiresAdminConfirmation;
  final List<String> linkedSubnets;
  final String? controllerUrl;
  final String siteName;
  final bool isEnabled;
  final bool isReadOnly;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UniFiDeviceEntity({
    required this.id,
    required this.name,
    required this.ip,
    this.mac,
    this.role = UniFiDeviceRole.otherUnknown,
    this.location,
    this.isCriticalInfrastructure = false,
    this.requiresAdminConfirmation = true,
    this.linkedSubnets = const [],
    this.controllerUrl,
    this.siteName = 'default',
    this.isEnabled = true,
    this.isReadOnly = true,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isGateway => role == UniFiDeviceRole.gateway;
  bool get isController => role == UniFiDeviceRole.controller;
  bool get performsRouting => isGateway && isCriticalInfrastructure;

  UniFiDeviceEntity copyWith({
    int? id,
    String? name,
    String? ip,
    String? mac,
    UniFiDeviceRole? role,
    String? location,
    bool? isCriticalInfrastructure,
    bool? requiresAdminConfirmation,
    List<String>? linkedSubnets,
    String? controllerUrl,
    String? siteName,
    bool? isEnabled,
    bool? isReadOnly,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UniFiDeviceEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      role: role ?? this.role,
      location: location ?? this.location,
      isCriticalInfrastructure:
          isCriticalInfrastructure ?? this.isCriticalInfrastructure,
      requiresAdminConfirmation:
          requiresAdminConfirmation ?? this.requiresAdminConfirmation,
      linkedSubnets: linkedSubnets ?? this.linkedSubnets,
      controllerUrl: controllerUrl ?? this.controllerUrl,
      siteName: siteName ?? this.siteName,
      isEnabled: isEnabled ?? this.isEnabled,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    ip,
    mac,
    role,
    location,
    isCriticalInfrastructure,
    requiresAdminConfirmation,
    linkedSubnets,
    controllerUrl,
    siteName,
    isEnabled,
    isReadOnly,
    createdAt,
    updatedAt,
  ];
}
