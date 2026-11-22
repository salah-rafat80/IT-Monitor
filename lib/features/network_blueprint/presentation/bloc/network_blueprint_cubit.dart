import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../monitoring/domain/entities/device_status_entity.dart';
import '../../../monitoring/domain/repositories/monitoring_repository.dart';
import '../../domain/entities/blueprint_element_entity.dart';
import '../../domain/repositories/network_blueprint_repository.dart';
import 'network_blueprint_state.dart';

@injectable
class NetworkBlueprintCubit extends Cubit<NetworkBlueprintState> {
  final NetworkBlueprintRepository _repository;
  final MonitoringRepository _monitoringRepository;
  StreamSubscription<List<DeviceStatusEntity>>? _statusSubscription;
  Timer? _statusDebounceTimer;

  NetworkBlueprintCubit(
    this._repository,
    this._monitoringRepository,
  ) : super(const NetworkBlueprintLoading()) {
    _initStatusListener();
  }

  void _initStatusListener() {
    _statusSubscription = _monitoringRepository
        .watchAllDeviceStatuses()
        .listen((_) {
      _statusDebounceTimer?.cancel();
      _statusDebounceTimer = Timer(const Duration(milliseconds: 600), () {
        if (!isClosed) {
          _handleLiveStatusUpdate();
        }
      });
    });
  }

  Future<void> loadBlueprint() async {
    emit(const NetworkBlueprintLoading());
    final result = await _repository.loadBlueprintPages();
    final pages = result.dataOrNull;

    if (pages != null && pages.isNotEmpty) {
      emit(NetworkBlueprintLoaded(pages: pages));
    } else {
      emit(
        NetworkBlueprintError(
          result.failureOrNull?.message ?? 'Failed to load Network Blueprint pages.',
        ),
      );
    }
  }

  void selectPage(int index) {
    final s = state;
    if (s is NetworkBlueprintLoaded) {
      if (index >= 0 && index < s.pages.length) {
        emit(s.copyWith(
          selectedPageIndex: index,
          clearSelectedElement: true,
        ));
      }
    }
  }

  void selectElement(BlueprintElementEntity? element) {
    final s = state;
    if (s is NetworkBlueprintLoaded) {
      emit(s.copyWith(
        selectedElement: element,
        clearSelectedElement: element == null,
      ));
    }
  }

  void updateSearchQuery(String query) {
    final s = state;
    if (s is NetworkBlueprintLoaded) {
      emit(s.copyWith(searchQuery: query));
    }
  }

  void toggleLiveMonitoring() {
    final s = state;
    if (s is NetworkBlueprintLoaded) {
      emit(s.copyWith(isLiveMonitoringActive: !s.isLiveMonitoringActive));
    }
  }

  Future<void> refreshStatuses() async {
    final s = state;
    if (s is NetworkBlueprintLoaded) {
      final res = await _repository.refreshMonitoringStatuses();
      final pages = res.dataOrNull;
      if (pages != null) {
        emit(s.copyWith(pages: pages));
      }
    }
  }

  Future<void> _handleLiveStatusUpdate() async {
    final s = state;
    if (s is NetworkBlueprintLoaded && s.isLiveMonitoringActive) {
      final res = await _repository.refreshMonitoringStatuses();
      final pages = res.dataOrNull;
      if (pages != null && !isClosed) {
        // Preserve selected element if it still exists
        BlueprintElementEntity? updatedSelected;
        if (s.selectedElement != null) {
          final currentPage = pages[s.selectedPageIndex];
          updatedSelected = currentPage.elements.cast<BlueprintElementEntity?>().firstWhere(
                (e) => e?.id == s.selectedElement!.id,
                orElse: () => s.selectedElement,
              );
        }
        emit(s.copyWith(
          pages: pages,
          selectedElement: updatedSelected,
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _statusDebounceTimer?.cancel();
    _statusSubscription?.cancel();
    return super.close();
  }
}
