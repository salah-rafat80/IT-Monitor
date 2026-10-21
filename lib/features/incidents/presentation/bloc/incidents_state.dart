import 'package:equatable/equatable.dart';
import '../../domain/entities/incident_entity.dart';

sealed class IncidentsState extends Equatable {
  const IncidentsState();

  @override
  List<Object?> get props => [];
}

final class IncidentsLoading extends IncidentsState {
  const IncidentsLoading();
}

final class IncidentsError extends IncidentsState {
  final String message;

  const IncidentsError(this.message);

  @override
  List<Object?> get props => [message];
}

final class IncidentsLoaded extends IncidentsState {
  final List<IncidentEntity> activeIncidents;
  final List<IncidentEntity> historyIncidents;
  final List<IncidentEntity> filteredHistory;

  // Filter criteria for history
  final String searchQuery;
  final String? typeFilter;
  final String? severityFilter;
  final String? statusFilter;

  const IncidentsLoaded({
    required this.activeIncidents,
    required this.historyIncidents,
    required this.filteredHistory,
    this.searchQuery = '',
    this.typeFilter,
    this.severityFilter,
    this.statusFilter,
  });

  IncidentsLoaded copyWith({
    List<IncidentEntity>? activeIncidents,
    List<IncidentEntity>? historyIncidents,
    List<IncidentEntity>? filteredHistory,
    String? searchQuery,
    String? typeFilter,
    String? severityFilter,
    String? statusFilter,
    bool clearTypeFilter = false,
    bool clearSeverityFilter = false,
    bool clearStatusFilter = false,
  }) {
    return IncidentsLoaded(
      activeIncidents: activeIncidents ?? this.activeIncidents,
      historyIncidents: historyIncidents ?? this.historyIncidents,
      filteredHistory: filteredHistory ?? this.filteredHistory,
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      severityFilter: clearSeverityFilter
          ? null
          : (severityFilter ?? this.severityFilter),
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
    );
  }

  @override
  List<Object?> get props => [
    activeIncidents,
    historyIncidents,
    filteredHistory,
    searchQuery,
    typeFilter,
    severityFilter,
    statusFilter,
  ];
}
