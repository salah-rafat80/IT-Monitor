import '../../../../core/utils/result.dart';
import '../entities/device_entity.dart';
import '../entities/device_import_commit_payload.dart';
import '../entities/inventory_import_preview.dart';

abstract class DeviceRepository {
  Future<Result<List<DeviceEntity>>> getDevices({String? factoryId});
  Future<Result<DeviceEntity>> getDeviceById(int id);
  Future<Result<DeviceEntity>> addDevice(DeviceEntity device);
  Future<Result<DeviceEntity>> updateDevice(DeviceEntity device);
  Future<Result<DeviceEntity>> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
    String? adminUsername,
  });
  Future<Result<void>> deleteDevice(int id);
  Future<Result<void>> toggleDeviceMonitoring({
    required int deviceId,
    required bool isEnabled,
  });
  Future<Result<InventoryImportPreview>> parseAndValidateImport(
    List<int> bytes,
    String filename,
  );
  Future<Result<int>> commitImportPayload(DeviceImportCommitPayload payload);
  Future<Result<int>> commitImport(List<DeviceEntity> validDevices);
  Future<Result<int>> bootstrapApprovedInventory({bool force = false});
  Future<Result<int>> reassignDevicesFactory({
    required List<int> deviceIds,
    required String targetFactoryId,
    String? adminUsername,
  });
  Future<Result<int>> deleteDevices(List<int> deviceIds);
  Future<Result<int>> bulkUpdateDevices({
    required List<int> deviceIds,
    DeviceType? type,
    String? department,
    String? officeLocation,
    String? vendor,
    bool? isMonitored,
    bool? isEnabled,
  });
}
