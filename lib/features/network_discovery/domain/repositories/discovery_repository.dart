import '../../../../core/utils/result.dart';
import '../entities/device_category.dart';
import '../entities/discovered_device_entity.dart';
import '../entities/discovery_config_entity.dart';
import '../entities/discovery_evidence_item.dart';
import '../entities/discovery_scan_job.dart';
import '../entities/network_range.dart';
import '../entities/review_state.dart';

abstract class DiscoveryRepository {
  Future<Result<DiscoveryConfigEntity>> getConfig();
  Future<Result<void>> saveConfig(DiscoveryConfigEntity config);

  // Authoritative Network Range Management
  Future<Result<List<NetworkRange>>> getRanges();
  Future<Result<void>> addRange(NetworkRange range);
  Future<Result<void>> updateRange(NetworkRange range);
  Future<Result<void>> deleteRange(String rangeId);
  Stream<List<NetworkRange>> watchRanges();

  Future<Result<int>> createScanJob(DiscoveryScanJob job);
  Future<Result<void>> updateScanJob(DiscoveryScanJob job);
  Future<Result<DiscoveryScanJob>> getScanJob(int scanId);
  Future<Result<DiscoveryScanJob?>> getLatestScanJob();
  Future<Result<List<DiscoveryScanJob>>> getAllScanJobs();

  Future<Result<int>> saveDiscoveredDevice(DiscoveredDeviceEntity device);
  Future<Result<List<DiscoveredDeviceEntity>>> getDiscoveredDevices({
    int? scanId,
  });
  Future<Result<DiscoveredDeviceEntity?>> getDiscoveredDeviceByIp(String ip);

  Future<Result<void>> updateDeviceReview({
    required int deviceId,
    required ReviewState state,
    DeviceCategory? confirmedCategory,
    int? reviewerId,
  });

  Future<Result<void>> saveEvidence(int deviceId, DiscoveryEvidenceItem item);
  Future<Result<List<DiscoveryEvidenceItem>>> getEvidenceForDevice(
    int deviceId,
  );

  Stream<DiscoveryScanJob?> watchLatestScanJob();
  Stream<List<DiscoveredDeviceEntity>> watchDiscoveredDevices({int? scanId});
}
