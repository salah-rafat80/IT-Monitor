import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../devices/domain/entities/device_entity.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../domain/entities/device_category.dart';
import '../../domain/entities/discovered_device_entity.dart';
import '../../domain/entities/discovery_config_entity.dart';
import '../../domain/entities/discovery_progress.dart';
import '../../domain/entities/discovery_scan_job.dart';
import '../../domain/entities/network_range.dart';
import '../../domain/entities/reachability_status.dart';
import '../../domain/entities/review_state.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../../domain/services/discovery_coordinator.dart';
import '../../../infrastructure/domain/repositories/infrastructure_repository.dart';
import '../../domain/services/network_range_validator.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import 'network_discovery_state.dart';

@injectable
class NetworkDiscoveryCubit extends Cubit<NetworkDiscoveryState> {
  final DiscoveryRepository _discoveryRepo;
  final DeviceRepository _deviceRepo;
  final DiscoveryCoordinator _coordinator;
  final NetworkRangeValidator _rangeValidator;
  final InfrastructureRepository? _infrastructureRepo;

  StreamSubscription<DiscoveryProgress>? _progressSub;
  StreamSubscription<DiscoveryScanJob?>? _scanSub;
  StreamSubscription<List<DiscoveredDeviceEntity>>? _deviceSub;
  StreamSubscription<List<NetworkRange>>? _rangesSub;

  NetworkDiscoveryCubit(
    this._discoveryRepo,
    this._deviceRepo,
    this._coordinator,
    this._rangeValidator, [
    this._infrastructureRepo,
  ]) : super(const NetworkDiscoveryInitial());

  Future<void> init() async {
    emit(const NetworkDiscoveryLoading());
    try {
      final configRes = await _discoveryRepo.getConfig();
      final config = configRes.dataOrNull ?? DiscoveryConfigEntity.initial();

      final latestScanRes = await _discoveryRepo.getLatestScanJob();
      final latestScan = latestScanRes.dataOrNull;

      final allScansRes = await _discoveryRepo.getAllScanJobs();
      final allScans = allScansRes.dataOrNull ?? [];

      final devicesRes = await _discoveryRepo.getDiscoveredDevices();
      final devices = devicesRes.dataOrNull ?? [];

      final ranges = _evaluateRanges(config.networkRanges, devices);

      _progressSub?.cancel();
      _progressSub = _coordinator.progressStream.listen(_handleProgress);

      _scanSub?.cancel();
      _scanSub = _discoveryRepo.watchLatestScanJob().listen(
        _handleScanJobUpdate,
      );

      _deviceSub?.cancel();
      _deviceSub = _discoveryRepo.watchDiscoveredDevices().listen(
        _handleDevicesUpdate,
      );

      _rangesSub?.cancel();
      _rangesSub = _discoveryRepo.watchRanges().listen(_handleRangesUpdate);

      if (isClosed) return;
      emit(
        NetworkDiscoveryLoaded(
          config: config,
          latestScan: latestScan,
          discoveredDevices: devices,
          filteredDevices: devices,
          allScans: allScans,
          rangesWithStatus: ranges,
          isScanning: _coordinator.isScanning,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(NetworkDiscoveryError('Failed to initialize discovery: $e'));
    }
  }

  List<NetworkRange> _evaluateRanges(
    List<dynamic> rangesOrStrings,
    List<DiscoveredDeviceEntity> devices,
  ) {
    final List<NetworkRange> ranges = [];
    for (final item in rangesOrStrings) {
      if (item is NetworkRange) {
        ranges.add(item);
      } else if (item is String) {
        final parsed = NetworkRange.tryParse(item);
        if (parsed != null) ranges.add(parsed);
      }
    }
    return ranges.map((r) {
      final hasDiscoveredInSubnet = devices.any((d) => r.containsIp(d.ip));
      final status = hasDiscoveredInSubnet
          ? ReachabilityStatus.reachable
          : ReachabilityStatus.reachabilityNotTested;
      return r.copyWith(reachability: status);
    }).toList();
  }

  void _handleRangesUpdate(List<NetworkRange> ranges) {
    if (isClosed) return;
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final updatedConfig = current.config.copyWith(networkRanges: ranges);
      final rangesWithStatus = _evaluateRanges(
        ranges,
        current.discoveredDevices,
      );
      emit(
        current.copyWith(
          config: updatedConfig,
          rangesWithStatus: rangesWithStatus,
        ),
      );
    }
  }

  void _handleProgress(DiscoveryProgress progress) {
    if (isClosed) return;
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final isScanActive =
          progress.status == ScanJobStatus.running ||
          progress.status == ScanJobStatus.validating;

      emit(current.copyWith(isScanning: isScanActive, progress: progress));
    }
  }

  void _handleScanJobUpdate(DiscoveryScanJob? job) {
    if (isClosed) return;
    final current = state;
    if (current is NetworkDiscoveryLoaded && job != null) {
      final isScanActive =
          job.status == ScanJobStatus.running ||
          job.status == ScanJobStatus.validating;
      emit(current.copyWith(latestScan: job, isScanning: isScanActive));
    }
  }

  void _handleDevicesUpdate(List<DiscoveredDeviceEntity> devices) {
    if (isClosed) return;
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final ranges = _evaluateRanges(current.config.networkRanges, devices);
      final updated = current.copyWith(
        discoveredDevices: devices,
        rangesWithStatus: ranges,
      );
      emit(_applyFilters(updated));
    }
  }

  Future<void> startScan({
    List<String>? requestedRanges,
    List<String>? enabledStrategies,
    int? maxConcurrency,
    int? timeoutSeconds,
  }) async {
    final res = await _coordinator.startScan(
      requestedRanges: requestedRanges,
      enabledStrategies: enabledStrategies,
      maxConcurrency: maxConcurrency,
      timeoutSeconds: timeoutSeconds,
    );
    if (res.isFailure) {
      // Non-fatal error display
      final current = state;
      if (current is NetworkDiscoveryLoaded) {
        emit(
          current.copyWith(
            errorMessage: res.failureOrNull?.message,
            progress: DiscoveryProgress(
              scanId: 0,
              status: ScanJobStatus.failed,
              targetsEnumerated: 0,
              targetsAttempted: 0,
              responsesReceived: 0,
              devicesFound: 0,
              classifiedCount: 0,
              unknownCount: 0,
              message: res.failureOrNull?.message,
            ),
          ),
        );
      }
    }
  }

  Future<void> cancelScan() async {
    await _coordinator.cancelScan();
  }

  Future<Result<void>> updateConfig(DiscoveryConfigEntity newConfig) async {
    final saveRes = await _discoveryRepo.saveConfig(newConfig);
    final current = state;
    if (saveRes.isFailure) {
      if (current is NetworkDiscoveryLoaded) {
        emit(
          current.copyWith(
            errorMessage:
                saveRes.failureOrNull?.message ??
                'Failed to persist discovery configuration',
          ),
        );
      }
      return saveRes;
    }
    if (current is NetworkDiscoveryLoaded) {
      final ranges = _evaluateRanges(
        newConfig.networkRanges,
        current.discoveredDevices,
      );
      emit(
        current.copyWith(
          config: newConfig,
          rangesWithStatus: ranges,
          clearErrorMessage: true,
        ),
      );
    }
    return Result.success(null);
  }

  Future<Result<void>> addNetworkRange({
    required String cidr,
    String? name,
    bool isEnabled = true,
  }) async {
    final parsed = _rangeValidator.validateSingleRange(cidr.trim());
    if (parsed == null) {
      const msg =
          'Invalid CIDR format. Prefix must be between /16 and /32 (e.g. 10.10.20.0/24).';
      final current = state;
      if (current is NetworkDiscoveryLoaded) {
        emit(current.copyWith(errorMessage: msg));
      }
      return Result.failure(ValidationFailure(msg));
    }

    final range = parsed.copyWith(
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      isEnabled: isEnabled,
      createdAt: DateTime.now(),
    );

    final addRes = await _discoveryRepo.addRange(range);
    final current = state;
    if (addRes.isFailure) {
      if (current is NetworkDiscoveryLoaded) {
        emit(current.copyWith(errorMessage: addRes.failureOrNull?.message));
      }
      return addRes;
    }

    final configRes = await _discoveryRepo.getConfig();
    if (configRes.isSuccess && current is NetworkDiscoveryLoaded) {
      final newConfig = configRes.dataOrNull!;
      emit(
        current.copyWith(
          config: newConfig,
          rangesWithStatus: _evaluateRanges(
            newConfig.networkRanges,
            current.discoveredDevices,
          ),
          clearErrorMessage: true,
        ),
      );
    }
    return Result.success(null);
  }

  Future<Result<void>> updateNetworkRange(NetworkRange range) async {
    final updateRes = await _discoveryRepo.updateRange(range);
    final current = state;
    if (updateRes.isFailure) {
      if (current is NetworkDiscoveryLoaded) {
        emit(current.copyWith(errorMessage: updateRes.failureOrNull?.message));
      }
      return updateRes;
    }

    final configRes = await _discoveryRepo.getConfig();
    if (configRes.isSuccess && current is NetworkDiscoveryLoaded) {
      final newConfig = configRes.dataOrNull!;
      emit(
        current.copyWith(
          config: newConfig,
          rangesWithStatus: _evaluateRanges(
            newConfig.networkRanges,
            current.discoveredDevices,
          ),
          clearErrorMessage: true,
        ),
      );
    }
    return Result.success(null);
  }

  Future<Result<void>> toggleRangeEnabled(
    String rangeId,
    bool isEnabled,
  ) async {
    final current = state;
    if (current is! NetworkDiscoveryLoaded) {
      return Result.failure(
        const ValidationFailure('Discovery state not loaded'),
      );
    }

    final range = current.config.networkRanges.firstWhere(
      (r) => r.id == rangeId || r.cidr == rangeId,
      orElse: () => throw StateError('Range $rangeId not found'),
    );

    return updateNetworkRange(
      range.copyWith(isEnabled: isEnabled, updatedAt: DateTime.now()),
    );
  }

  Future<Result<void>> deleteNetworkRange(String rangeId) async {
    final delRes = await _discoveryRepo.deleteRange(rangeId);
    final current = state;
    if (delRes.isFailure) {
      if (current is NetworkDiscoveryLoaded) {
        emit(current.copyWith(errorMessage: delRes.failureOrNull?.message));
      }
      return delRes;
    }

    final configRes = await _discoveryRepo.getConfig();
    if (configRes.isSuccess && current is NetworkDiscoveryLoaded) {
      final newConfig = configRes.dataOrNull!;
      emit(
        current.copyWith(
          config: newConfig,
          rangesWithStatus: _evaluateRanges(
            newConfig.networkRanges,
            current.discoveredDevices,
          ),
          clearErrorMessage: true,
        ),
      );
    }
    return Result.success(null);
  }

  void clearErrorMessage() {
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      emit(current.copyWith(clearErrorMessage: true));
    }
  }

  Future<bool> approveDevice({
    required DiscoveredDeviceEntity discoveredDevice,
    String? ownerName,
    String? department,
    String? deviceName,
    String? location,
    DeviceCategory? confirmedCategory,
    bool? isMonitored,
    String? vendor,
    String? model,
    String? notes,
  }) async {
    final cat = confirmedCategory ?? discoveredDevice.effectiveCategory;
    final deviceType = DeviceType.fromString(cat.toValue());

    final devName = (deviceName != null && deviceName.trim().isNotEmpty)
        ? deviceName.trim()
        : (discoveredDevice.hostname?.trim().isNotEmpty == true
              ? discoveredDevice.hostname!.trim()
              : '${deviceType.displayName}-${discoveredDevice.ip.replaceAll('.', '-')}');

    final owner = (ownerName != null && ownerName.trim().isNotEmpty)
        ? ownerName.trim()
        : 'Unassigned';
    final dept = (department != null && department.trim().isNotEmpty)
        ? department.trim()
        : 'General';
    final loc = (location != null && location.trim().isNotEmpty)
        ? location.trim()
        : null;
    final ven = (vendor != null && vendor.trim().isNotEmpty)
        ? vendor.trim()
        : discoveredDevice.vendor;
    final mod = (model != null && model.trim().isNotEmpty)
        ? model.trim()
        : null;
    final note = (notes != null && notes.trim().isNotEmpty)
        ? notes.trim()
        : null;
    final shouldMonitor = isMonitored ?? deviceType.isMonitoredByDefault;

    // 1. Check if this IP is an existing infrastructure asset (e.g. UniFi AP or Gateway)
    if (_infrastructureRepo != null) {
      final infraRes = await _infrastructureRepo.getDeviceByIp(
        discoveredDevice.ip.trim(),
      );
      final infra = infraRes.dataOrNull;
      if (infra != null) {
        // Discovered device belongs to authoritative infrastructure
        // Update review state and associate without inserting a duplicate inventory device
        final savedId = 10000 + infra.id;
        await _discoveryRepo.updateDeviceReview(
          deviceId: discoveredDevice.id,
          state: ReviewState.approved,
          confirmedCategory: cat,
        );
        await _discoveryRepo.saveDiscoveredDevice(
          discoveredDevice.copyWith(
            reviewState: ReviewState.approved,
            adminConfirmedCategory: cat,
            associatedDeviceId: savedId,
          ),
        );
        return true;
      }
    }

    // 2. Check if device with this IP already exists in persistent inventory
    final existingDevicesRes = await _deviceRepo.getDevices();
    final existingDevices = existingDevicesRes.dataOrNull ?? [];
    final existingDevice = existingDevices
        .where((d) => d.ip.trim() == discoveredDevice.ip.trim())
        .firstOrNull;

    int? savedId;
    if (existingDevice != null) {
      // Update existing device's technical observation metadata without silently destroying confirmed owner/department
      final updatedDevice = existingDevice.copyWith(
        name: devName,
        type: deviceType,
        ownerName: owner != 'Unassigned' ? owner : existingDevice.ownerName,
        department: dept != 'General' ? dept : existingDevice.department,
        officeLocation: loc ?? existingDevice.officeLocation,
        vendor: ven ?? existingDevice.vendor,
        model: mod ?? existingDevice.model,
        mac: discoveredDevice.mac ?? existingDevice.mac,
        hostname: discoveredDevice.hostname ?? existingDevice.hostname,
        notes: note ?? existingDevice.notes,
        isMonitored: shouldMonitor,
        updatedAt: DateTime.now(),
      );
      final updateRes = await _deviceRepo.updateDevice(updatedDevice);
      if (updateRes.isFailure) return false;
      savedId = existingDevice.id;
    } else {
      // Add new persistent device
      final createRes = await _deviceRepo.addDevice(
        DeviceEntity(
          id: 0,
          name: devName,
          type: deviceType,
          ip: discoveredDevice.ip,
          ownerName: owner,
          department: dept,
          officeLocation: loc,
          vendor: ven,
          model: mod,
          mac: discoveredDevice.mac,
          hostname: discoveredDevice.hostname,
          notes: note,
          isMonitored: shouldMonitor,
          createdAt: DateTime.now(),
        ),
      );

      if (createRes.isFailure) {
        return false;
      }
      savedId = createRes.dataOrNull?.id;
    }

    await _discoveryRepo.updateDeviceReview(
      deviceId: discoveredDevice.id,
      state: ReviewState.approved,
      confirmedCategory: cat,
    );

    // Save with associated authoritative device ID
    await _discoveryRepo.saveDiscoveredDevice(
      discoveredDevice.copyWith(
        reviewState: ReviewState.approved,
        adminConfirmedCategory: cat,
        associatedDeviceId: savedId,
      ),
    );

    return true;
  }

  Future<void> rejectDevice(int deviceId) async {
    await _discoveryRepo.updateDeviceReview(
      deviceId: deviceId,
      state: ReviewState.rejected,
    );
  }

  Future<void> overrideCategory({
    required int deviceId,
    required DeviceCategory category,
  }) async {
    await _discoveryRepo.updateDeviceReview(
      deviceId: deviceId,
      state: ReviewState.pendingReview,
      confirmedCategory: category,
    );
  }

  void setSearchQuery(String query) {
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final updated = current.copyWith(searchQuery: query);
      emit(_applyFilters(updated));
    }
  }

  void setCategoryFilter(DeviceCategory? category) {
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final updated = category == null
          ? current.copyWith(clearCategoryFilter: true)
          : current.copyWith(categoryFilter: category);
      emit(_applyFilters(updated));
    }
  }

  void setReviewFilter(ReviewState? reviewState) {
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final updated = reviewState == null
          ? current.copyWith(clearReviewFilter: true)
          : current.copyWith(reviewFilter: reviewState);
      emit(_applyFilters(updated));
    }
  }

  void setSubnetFilter(String? cidr) {
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final updated = cidr == null
          ? current.copyWith(clearSubnetFilter: true)
          : current.copyWith(subnetFilter: cidr);
      emit(_applyFilters(updated));
    }
  }

  void resetFilters() {
    final current = state;
    if (current is NetworkDiscoveryLoaded) {
      final updated = current.copyWith(
        searchQuery: '',
        clearCategoryFilter: true,
        clearReviewFilter: true,
        clearSubnetFilter: true,
      );
      emit(_applyFilters(updated));
    }
  }

  NetworkDiscoveryLoaded _applyFilters(NetworkDiscoveryLoaded current) {
    final query = current.searchQuery.toLowerCase().trim();
    final catFilter = current.categoryFilter;
    final revFilter = current.reviewFilter;
    final subFilter = current.subnetFilter;

    final filtered = current.discoveredDevices.where((d) {
      if (query.isNotEmpty) {
        final matchesIp = d.ip.toLowerCase().contains(query);
        final matchesMac = d.mac?.toLowerCase().contains(query) ?? false;
        final matchesHost = d.hostname?.toLowerCase().contains(query) ?? false;
        final matchesVendor = d.vendor?.toLowerCase().contains(query) ?? false;
        if (!matchesIp && !matchesMac && !matchesHost && !matchesVendor) {
          return false;
        }
      }

      if (catFilter != null && d.effectiveCategory != catFilter) {
        return false;
      }

      if (revFilter != null && d.reviewState != revFilter) {
        return false;
      }

      if (subFilter != null) {
        final parsed = NetworkRange.parse(subFilter);
        if (parsed != null && !parsed.containsIp(d.ip)) {
          return false;
        }
      }

      return true;
    }).toList();

    return current.copyWith(filteredDevices: filtered);
  }

  String exportToCsv() {
    final current = state;
    if (current is! NetworkDiscoveryLoaded) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      'IP Address,Hostname,MAC Address,Vendor,Category,Confidence,Review State,First Seen,Last Seen,Evidence',
    );

    for (final d in current.filteredDevices) {
      final ip = d.ip;
      final host = d.hostname ?? '';
      final mac = d.mac ?? '';
      final vendor = d.vendor ?? '';
      final category = d.effectiveCategory.displayName;
      final confidence = d.confidence.displayName;
      final review = d.reviewState.displayName;
      final first = d.firstSeen.toIso8601String();
      final last = d.lastSeen.toIso8601String();
      final evidence = d.evidence
          .map((e) => '${e.strategyName}:${e.details}')
          .join('; ')
          .replaceAll(',', ' ');

      buffer.writeln(
        '"$ip","$host","$mac","$vendor","$category","$confidence","$review","$first","$last","$evidence"',
      );
    }

    return buffer.toString();
  }

  @override
  Future<void> close() {
    _progressSub?.cancel();
    _scanSub?.cancel();
    _deviceSub?.cancel();
    _rangesSub?.cancel();
    return super.close();
  }
}
