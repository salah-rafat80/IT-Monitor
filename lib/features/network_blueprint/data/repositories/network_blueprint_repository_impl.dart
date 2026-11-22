import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/repositories/monitoring_repository.dart';
import '../../domain/entities/blueprint_page_entity.dart';
import '../../domain/repositories/network_blueprint_repository.dart';
import '../datasources/blueprint_drawio_parser.dart';
import '../datasources/blueprint_inventory_matcher.dart';

@LazySingleton(as: NetworkBlueprintRepository)
class NetworkBlueprintRepositoryImpl implements NetworkBlueprintRepository {
  static const String _defaultAssetPath = 'assets/topology/rnf/RNFip.drawio';

  final BlueprintDrawioParser _parser;
  final BlueprintInventoryMatcher _matcher;
  final DeviceRepository _deviceRepository;
  final MonitoringRepository _monitoringRepository;

  List<BlueprintPageEntity>? _cachedRawPages;

  NetworkBlueprintRepositoryImpl(
    this._deviceRepository,
    this._monitoringRepository, [
    BlueprintDrawioParser? parser,
    BlueprintInventoryMatcher? matcher,
  ])  : _parser = parser ?? BlueprintDrawioParser(),
        _matcher = matcher ?? BlueprintInventoryMatcher();

  @override
  Future<Result<List<BlueprintPageEntity>>> loadBlueprintPages() async {
    try {
      _cachedRawPages ??= await _parser.parseFromAsset(_defaultAssetPath);
      return await _applyLiveInventoryAndStatus(_cachedRawPages!);
    } catch (e) {
      return Result.failure(
        NetworkFailure('Failed to load Network Blueprint: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<List<BlueprintPageEntity>>> refreshMonitoringStatuses() async {
    try {
      if (_cachedRawPages == null) {
        return await loadBlueprintPages();
      }
      return await _applyLiveInventoryAndStatus(_cachedRawPages!);
    } catch (e) {
      return Result.failure(
        NetworkFailure('Failed to refresh Blueprint statuses: ${e.toString()}'),
      );
    }
  }

  Future<Result<List<BlueprintPageEntity>>> _applyLiveInventoryAndStatus(
    List<BlueprintPageEntity> rawPages,
  ) async {
    // 1. Fetch registered devices
    final devicesRes = await _deviceRepository.getDevices();
    final devices = devicesRes.dataOrNull ?? [];

    // 2. Fetch live monitoring statuses
    final statusesRes = await _monitoringRepository.getDeviceStatuses();
    final statusMap = <int, DeviceStatusEntity>{};
    final statuses = statusesRes.dataOrNull;
    if (statuses != null) {
      for (final s in statuses) {
        statusMap[s.deviceId] = s;
      }
    }

    // 3. Match devices and overlay live status
    final matchedPages = _matcher.matchPages(
      pages: rawPages,
      inventoryDevices: devices,
      liveStatuses: statusMap,
    );

    return Result.success(matchedPages);
  }
}
