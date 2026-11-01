import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/incident_entity.dart';
import '../../domain/repositories/incident_repository.dart';
import 'incidents_state.dart';

@injectable
class IncidentsCubit extends Cubit<IncidentsState> {
  final IncidentRepository _incidentRepo;
  StreamSubscription<List<IncidentEntity>>? _activeIncidentsSub;
  String? _factoryId;

  IncidentsCubit(this._incidentRepo) : super(const IncidentsLoading());

  String? get currentFactoryId => _factoryId;

  void setFactory(String? factoryId) {
    if (_factoryId != factoryId) {
      _factoryId = factoryId;
      initIncidents(_factoryId);
    }
  }

  Future<void> initIncidents([String? factoryId]) async {
    if (factoryId != null || (factoryId == null && _factoryId != null)) {
      _factoryId = factoryId;
    }
    emit(const IncidentsLoading());
    try {
      final activeRes = await _incidentRepo.getActiveIncidents(
        factoryId: _factoryId,
      );
      final historyRes = await _incidentRepo.getIncidentHistory(
        factoryId: _factoryId,
      );

      if (isClosed) return;
      if (activeRes.isFailure || historyRes.isFailure) {
        emit(
          IncidentsError(
            activeRes.failureOrNull?.message ??
                historyRes.failureOrNull?.message ??
                'Failed to load incidents',
          ),
        );
        return;
      }

      final active = activeRes.dataOrNull ?? [];
      final history = historyRes.dataOrNull ?? [];

      _activeIncidentsSub?.cancel();
      _activeIncidentsSub = _incidentRepo
          .watchActiveIncidents(factoryId: _factoryId)
          .listen((updatedActive) {
            _refreshWithActive(updatedActive);
          });

      if (isClosed) return;
      emit(
        _applyHistoryFilters(
          IncidentsLoaded(
            activeIncidents: active,
            historyIncidents: history,
            filteredHistory: history,
          ),
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(IncidentsError('Incidents initialization error: $e'));
    }
  }

  Future<void> refreshHistory() async {
    final historyRes = await _incidentRepo.getIncidentHistory(
      factoryId: _factoryId,
    );
    if (isClosed) return;
    if (historyRes.isSuccess) {
      final current = state;
      if (current is IncidentsLoaded) {
        final history = historyRes.dataOrNull ?? [];
        emit(_applyHistoryFilters(current.copyWith(historyIncidents: history)));
      }
    }
  }

  Future<void> acknowledgeIncident({
    required int id,
    required String username,
    String? note,
  }) async {
    final res = await _incidentRepo.acknowledgeIncident(
      id: id,
      username: username,
      note: note,
    );

    res.fold(
      onSuccess: (_) async => refreshHistory(),
      onFailure: (failure) => emit(IncidentsError(failure.message)),
    );
  }

  Future<void> addNote({required int id, required String note}) async {
    final res = await _incidentRepo.addNote(id: id, note: note);

    res.fold(
      onSuccess: (_) async => refreshHistory(),
      onFailure: (failure) => emit(IncidentsError(failure.message)),
    );
  }

  void setSearchQuery(String query) {
    final current = state;
    if (current is IncidentsLoaded) {
      emit(_applyHistoryFilters(current.copyWith(searchQuery: query)));
    }
  }

  void setTypeFilter(String? type) {
    final current = state;
    if (current is IncidentsLoaded) {
      emit(
        _applyHistoryFilters(
          current.copyWith(typeFilter: type, clearTypeFilter: type == null),
        ),
      );
    }
  }

  void setSeverityFilter(String? severity) {
    final current = state;
    if (current is IncidentsLoaded) {
      emit(
        _applyHistoryFilters(
          current.copyWith(
            severityFilter: severity,
            clearSeverityFilter: severity == null,
          ),
        ),
      );
    }
  }

  void setStatusFilter(String? status) {
    final current = state;
    if (current is IncidentsLoaded) {
      emit(
        _applyHistoryFilters(
          current.copyWith(
            statusFilter: status,
            clearStatusFilter: status == null,
          ),
        ),
      );
    }
  }

  void _refreshWithActive(List<IncidentEntity> updatedActive) async {
    final historyRes = await _incidentRepo.getIncidentHistory();
    final history = historyRes.dataOrNull ?? [];

    final current = state;
    if (current is IncidentsLoaded) {
      emit(
        _applyHistoryFilters(
          current.copyWith(
            activeIncidents: updatedActive,
            historyIncidents: history,
          ),
        ),
      );
    }
  }

  IncidentsLoaded _applyHistoryFilters(IncidentsLoaded loaded) {
    List<IncidentEntity> list = List.from(loaded.historyIncidents);

    final query = loaded.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((i) {
        return i.deviceName.toLowerCase().contains(query) ||
            i.ownerName.toLowerCase().contains(query) ||
            i.department.toLowerCase().contains(query) ||
            i.deviceIp.toLowerCase().contains(query) ||
            (i.location?.toLowerCase().contains(query) ?? false) ||
            (i.notes?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    if (loaded.typeFilter != null) {
      list = list
          .where((i) => i.incidentType.toValue() == loaded.typeFilter)
          .toList();
    }

    if (loaded.severityFilter != null) {
      list = list
          .where((i) => i.severity.toValue() == loaded.severityFilter)
          .toList();
    }

    if (loaded.statusFilter != null) {
      list = list
          .where((i) => i.status.toValue() == loaded.statusFilter)
          .toList();
    }

    return loaded.copyWith(filteredHistory: list);
  }

  @override
  Future<void> close() {
    _activeIncidentsSub?.cancel();
    return super.close();
  }
}
