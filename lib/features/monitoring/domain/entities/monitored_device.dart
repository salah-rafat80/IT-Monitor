import 'package:equatable/equatable.dart';
import '../../../devices/domain/entities/device_entity.dart';
import 'device_status_entity.dart';

class MonitoredDevice extends Equatable {
  final DeviceEntity device;
  final DeviceStatusEntity status;

  const MonitoredDevice({required this.device, required this.status});

  @override
  List<Object?> get props => [device, status];
}
