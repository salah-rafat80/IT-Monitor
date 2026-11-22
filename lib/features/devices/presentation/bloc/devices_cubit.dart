import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/device_entity.dart';
import '../../domain/entities/device_import_commit_payload.dart';
import '../../domain/entities/inventory_import_preview.dart';
import '../../domain/repositories/device_repository.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';

sealed class DevicesState extends Equatable {
  const DevicesState();

  @override
  List<Object?> get props => [];
}

final class DevicesInitial extends DevicesState {
  const DevicesInitial();
}

final class DevicesLoading extends DevicesState {
  const DevicesLoading();
}

final class DevicesLoaded extends DevicesState {
  final List<DeviceEntity> allDevices;
  final List<DeviceEntity> filteredDevices;
  final String searchQuery;
  final String selectedDepartment;
  final String selectedLocation;
  final String selectedCategory;
  final String selectedMonitoring;

  const DevicesLoaded({
    required this.allDevices,
    required this.filteredDevices,
    this.searchQuery = '',
    this.selectedDepartment = 'All',
    this.selectedLocation = 'All',
    this.selectedCategory = 'All',
    this.selectedMonitoring = 'All',
  });

  @override
  List<Object?> get props => [
    allDevices,
    filteredDevices,
    searchQuery,
    selectedDepartment,
    selectedLocation,
    selectedCategory,
    selectedMonitoring,
  ];
}

final class ImportPreviewState extends DevicesState {
  final InventoryImportPreview preview;

  const ImportPreviewState(this.preview);

  @override
  List<Object?> get props => [preview];
}

final class DevicesError extends DevicesState {
  final String message;

  const DevicesError(this.message);

  @override
  List<Object?> get props => [message];
}

class DeviceReassignmentResult {
  final int count;
  final String? refreshError;

  const DeviceReassignmentResult({required this.count, this.refreshError});

  bool get hasRefreshError => refreshError != null && refreshError!.isNotEmpty;
}

@injectable
class DevicesCubit extends Cubit<DevicesState> {
  final DeviceRepository _deviceRepo;
  String? _activeFactoryId;
  String? get activeFactoryId => _activeFactoryId;

  DevicesCubit(this._deviceRepo) : super(const DevicesInitial());

  Future<void> setFactory(String? factoryId) async {
    _activeFactoryId = factoryId;
    await loadDevices(factoryId: factoryId, forceSetFactory: true);
  }

  Future<void> loadDevices({String? factoryId, bool forceSetFactory = false}) async {
    if (forceSetFactory) {
      _activeFactoryId = factoryId;
    } else if (factoryId != null) {
      _activeFactoryId = factoryId;
    }
    if (isClosed) return;
    emit(const DevicesLoading());

    try {
      final res = await _deviceRepo
          .getDevices(factoryId: _activeFactoryId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => Result.failure(
              NetworkFailure('Loading devices timed out after 10s'),
            ),
          );
      if (isClosed) return;

      res.fold(
        onSuccess: (devices) =>
            emit(DevicesLoaded(allDevices: devices, filteredDevices: devices)),
        onFailure: (failure) => emit(DevicesError(failure.message)),
      );
    } catch (e) {
      if (!isClosed) {
        emit(DevicesError('Failed to load devices: $e'));
      }
    }
  }

  Future<void> bootstrapApprovedInventory({bool force = false}) async {
    if (isClosed) return;
    emit(const DevicesLoading());
    final res = await _deviceRepo.bootstrapApprovedInventory(force: force);
    if (isClosed) return;
    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  void filterDevices({
    String? query,
    String? department,
    String? location,
    String? category,
    String? monitoring,
  }) {
    final current = state;
    if (current is! DevicesLoaded) return;

    final q = (query ?? current.searchQuery).toLowerCase().trim();
    final dept = department ?? current.selectedDepartment;
    final loc = location ?? current.selectedLocation;
    final cat = category ?? current.selectedCategory;
    final mon = monitoring ?? current.selectedMonitoring;

    final filtered = current.allDevices.where((device) {
      final matchesQuery =
          q.isEmpty ||
          device.displayOwner.toLowerCase().contains(q) ||
          device.ownerName.toLowerCase().contains(q) ||
          device.department.toLowerCase().contains(q) ||
          device.name.toLowerCase().contains(q) ||
          device.ip.toLowerCase().contains(q) ||
          (device.hostname?.toLowerCase().contains(q) ?? false) ||
          (device.mac?.toLowerCase().contains(q) ?? false) ||
          (device.notes?.toLowerCase().contains(q) ?? false) ||
          (device.officeLocation?.toLowerCase().contains(q) ?? false);

      final matchesDept =
          dept == 'All' ||
          device.department.toLowerCase() == dept.toLowerCase();
      final matchesLoc =
          loc == 'All' ||
          (device.officeLocation?.toLowerCase() == loc.toLowerCase());
      final matchesCat =
          cat == 'All' ||
          device.type.displayName.toLowerCase() == cat.toLowerCase() ||
          device.type.name.toLowerCase() == cat.toLowerCase();
      final matchesMon =
          mon == 'All' ||
          (mon == 'Monitored' && device.isMonitored && device.isEnabled) ||
          (mon == 'Unmonitored' && (!device.isMonitored || !device.isEnabled));

      return matchesQuery &&
          matchesDept &&
          matchesLoc &&
          matchesCat &&
          matchesMon;
    }).toList();

    emit(
      DevicesLoaded(
        allDevices: current.allDevices,
        filteredDevices: filtered,
        searchQuery: q,
        selectedDepartment: dept,
        selectedLocation: loc,
        selectedCategory: cat,
        selectedMonitoring: mon,
      ),
    );
  }

  void resetFilters() {
    final current = state;
    if (current is! DevicesLoaded) return;
    emit(
      DevicesLoaded(
        allDevices: current.allDevices,
        filteredDevices: current.allDevices,
        searchQuery: '',
        selectedDepartment: 'All',
        selectedLocation: 'All',
        selectedCategory: 'All',
        selectedMonitoring: 'All',
      ),
    );
  }

  Future<void> addDevice(DeviceEntity device) async {
    final res = await _deviceRepo.addDevice(device);

    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<void> updateDevice(DeviceEntity device) async {
    final res = await _deviceRepo.updateDevice(device);

    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<void> deleteDevice(int id) async {
    final res = await _deviceRepo.deleteDevice(id);

    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<bool> assignDeviceOwner({
    required int deviceId,
    required String ownerName,
  }) async {
    final res = await _deviceRepo.assignDeviceOwner(
      deviceId: deviceId,
      ownerName: ownerName,
    );

    return res.fold(
      onSuccess: (_) {
        loadDevices();
        return true;
      },
      onFailure: (failure) {
        emit(DevicesError(failure.message));
        return false;
      },
    );
  }

  Future<void> toggleMonitoring(int deviceId, bool isEnabled) async {
    final res = await _deviceRepo.toggleDeviceMonitoring(
      deviceId: deviceId,
      isEnabled: isEnabled,
    );

    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<void> parseImportFile(List<int> bytes, String filename) async {
    emit(const DevicesLoading());

    final res = await _deviceRepo.parseAndValidateImport(bytes, filename);

    res.fold(
      onSuccess: (preview) => emit(ImportPreviewState(preview)),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<void> confirmImportPayload(DeviceImportCommitPayload payload) async {
    emit(const DevicesLoading());

    final res = await _deviceRepo.commitImportPayload(payload);

    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<void> confirmImport(List<DeviceEntity> validDevices) async {
    emit(const DevicesLoading());

    final res = await _deviceRepo.commitImport(validDevices);

    res.fold(
      onSuccess: (_) => loadDevices(),
      onFailure: (failure) => emit(DevicesError(failure.message)),
    );
  }

  Future<Result<DeviceReassignmentResult>> reassignDevicesFactory({
    required List<int> deviceIds,
    required String targetFactoryId,
  }) async {
    final res = await _deviceRepo.reassignDevicesFactory(
      deviceIds: deviceIds,
      targetFactoryId: targetFactoryId,
    );

    return res.fold(
      onSuccess: (count) async {
        String? refreshError;
        try {
          await loadDevices();
          if (state is DevicesError) {
            refreshError = (state as DevicesError).message;
          }
        } catch (e) {
          refreshError = e.toString();
        }
        return Result.success(
          DeviceReassignmentResult(count: count, refreshError: refreshError),
        );
      },
      onFailure: (failure) {
        // Do not overwrite current DevicesLoaded state with DevicesError on mutation failure,
        // so the user does not lose their current inventory view or see misleading empty states.
        return Result.failure(failure);
      },
    );
  }

  Future<bool> deleteDevices(List<int> deviceIds) async {
    final res = await _deviceRepo.deleteDevices(deviceIds);

    return res.fold(
      onSuccess: (_) {
        loadDevices();
        return true;
      },
      onFailure: (failure) {
        emit(DevicesError(failure.message));
        return false;
      },
    );
  }

  Future<bool> bulkUpdateDevices({
    required List<int> deviceIds,
    DeviceType? type,
    String? department,
    String? officeLocation,
    String? vendor,
    bool? isMonitored,
    bool? isEnabled,
  }) async {
    final res = await _deviceRepo.bulkUpdateDevices(
      deviceIds: deviceIds,
      type: type,
      department: department,
      officeLocation: officeLocation,
      vendor: vendor,
      isMonitored: isMonitored,
      isEnabled: isEnabled,
    );

    return res.fold(
      onSuccess: (_) {
        loadDevices();
        return true;
      },
      onFailure: (failure) {
        emit(DevicesError(failure.message));
        return false;
      },
    );
  }
}
