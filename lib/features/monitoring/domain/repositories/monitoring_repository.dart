import '../../../../core/utils/result.dart';
import '../entities/check_result.dart';
import '../entities/device_status_entity.dart';

abstract class MonitoringRepository {
  Future<Result<List<DeviceStatusEntity>>> getDeviceStatuses();
  Future<Result<DeviceStatusEntity>> getDeviceStatus(int deviceId);
  Future<Result<void>> saveCheckResult(CheckResult result);
  Future<Result<void>> saveDeviceStatus(DeviceStatusEntity status);
  Future<Result<void>> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  });
  Stream<DeviceStatusEntity> watchDeviceStatus(int deviceId);
  Stream<List<DeviceStatusEntity>> watchAllDeviceStatuses();
}
