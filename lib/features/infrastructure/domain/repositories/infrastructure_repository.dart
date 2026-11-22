import '../../../../core/utils/result.dart';
import '../entities/unifi_device_entity.dart';

abstract class InfrastructureRepository {
  Future<Result<List<UniFiDeviceEntity>>> getInfrastructureDevices({
    String? factoryId,
  });
  Future<Result<UniFiDeviceEntity?>> getDeviceById(int id);
  Future<Result<UniFiDeviceEntity?>> getDeviceByIp(
    String ip, {
    String? factoryId,
  });
  Future<Result<UniFiDeviceEntity>> saveInfrastructureDevice(
    UniFiDeviceEntity device,
  );
  Future<Result<void>> deleteInfrastructureDevice(int id);
  Future<Result<UniFiDeviceEntity>> confirmDeviceRole({
    required int id,
    required UniFiDeviceRole role,
    required bool isCritical,
    required List<String> linkedSubnets,
  });
  Stream<List<UniFiDeviceEntity>> watchInfrastructureDevices({
    String? factoryId,
  });
  Future<Result<void>> bootstrapVerifiedAccessPoints();
  Future<Result<void>> bootstrapVerifiedSwitches();
}
