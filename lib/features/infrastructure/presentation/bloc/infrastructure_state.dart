import 'package:equatable/equatable.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../domain/entities/unifi_device_entity.dart';

class InfrastructureState extends Equatable {
  final bool isLoading;
  final bool isCheckingAll;
  final Set<int>
  checkingDeviceIds; // virtual IDs currently undergoing ping check
  final List<UniFiDeviceEntity> devices;
  final Map<int, DeviceStatusEntity>
  statuses; // keyed by virtualId (10000 + id)
  final String? errorMessage;
  final String? successMessage;

  const InfrastructureState({
    this.isLoading = false,
    this.isCheckingAll = false,
    this.checkingDeviceIds = const {},
    this.devices = const [],
    this.statuses = const {},
    this.errorMessage,
    this.successMessage,
  });

  bool isChecking(UniFiDeviceEntity device) {
    return checkingDeviceIds.contains(10000 + device.id);
  }

  UniFiDeviceEntity? get primaryGateway =>
      devices
          .where((d) => d.isGateway && d.isCriticalInfrastructure)
          .firstOrNull ??
      devices.where((d) => d.isGateway).firstOrNull;

  UniFiDeviceEntity? get primaryController =>
      devices.where((d) => d.isController).firstOrNull;

  DeviceStatusEntity? getStatusFor(UniFiDeviceEntity device) {
    return statuses[10000 + device.id];
  }

  int get totalCount => devices.length;
  int get upCount => devices
      .where((d) => getStatusFor(d)?.effectiveStatus() == DeviceStatusEnum.up)
      .length;
  int get degradedCount => devices
      .where(
        (d) => getStatusFor(d)?.effectiveStatus() == DeviceStatusEnum.degraded,
      )
      .length;
  int get downCount => devices
      .where(
        (d) =>
            getStatusFor(d)?.effectiveStatus() == DeviceStatusEnum.down ||
            getStatusFor(d)?.effectiveStatus() == DeviceStatusEnum.unreachable,
      )
      .length;
  int get staleCount => devices
      .where(
        (d) => getStatusFor(d)?.effectiveStatus() == DeviceStatusEnum.stale,
      )
      .length;
  int get unknownCount => devices.where((d) {
    final s = getStatusFor(d)?.effectiveStatus();
    return s == null || s == DeviceStatusEnum.unknown;
  }).length;
  int get maintenanceCount => devices
      .where(
        (d) =>
            getStatusFor(d)?.effectiveStatus() == DeviceStatusEnum.maintenance,
      )
      .length;

  InfrastructureState copyWith({
    bool? isLoading,
    bool? isCheckingAll,
    Set<int>? checkingDeviceIds,
    List<UniFiDeviceEntity>? devices,
    Map<int, DeviceStatusEntity>? statuses,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return InfrastructureState(
      isLoading: isLoading ?? this.isLoading,
      isCheckingAll: isCheckingAll ?? this.isCheckingAll,
      checkingDeviceIds: checkingDeviceIds ?? this.checkingDeviceIds,
      devices: devices ?? this.devices,
      statuses: statuses ?? this.statuses,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isCheckingAll,
    checkingDeviceIds,
    devices,
    statuses,
    errorMessage,
    successMessage,
  ];
}
