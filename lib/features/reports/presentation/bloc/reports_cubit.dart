import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {}

class ReportsLoading extends ReportsState {}

class ReportsLoaded extends ReportsState {
  final ReportSummaryEntity report;
  final String? exportPath;
  final String? message;

  const ReportsLoaded({required this.report, this.exportPath, this.message});

  @override
  List<Object?> get props => [report, exportPath, message];
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}

@injectable
class ReportsCubit extends Cubit<ReportsState> {
  final ReportRepository _repository;
  String? _factoryId;
  ReportPeriod _currentPeriod = ReportPeriod.last24Hours;

  ReportsCubit(this._repository) : super(ReportsInitial());

  String? get currentFactoryId => _factoryId;
  ReportPeriod get currentPeriod => _currentPeriod;

  void setFactory(String? factoryId) {
    if (_factoryId != factoryId) {
      _factoryId = factoryId;
      loadReport(_currentPeriod, _factoryId);
    }
  }

  Future<void> loadReport([ReportPeriod? period, String? factoryId]) async {
    if (period != null) _currentPeriod = period;
    if (factoryId != null || (factoryId == null && _factoryId != null)) {
      _factoryId = factoryId;
    }
    if (isClosed) return;
    emit(ReportsLoading());
    final res = await _repository.generateReport(
      _currentPeriod,
      factoryId: _factoryId,
    );
    if (isClosed) return;
    if (res.isSuccess) {
      emit(ReportsLoaded(report: res.dataOrNull!));
    } else {
      emit(
        ReportsError(res.failureOrNull?.message ?? 'Failed to generate report'),
      );
    }
  }

  Future<void> exportCsv() async {
    final currentState = state;
    if (currentState is ReportsLoaded) {
      final res = await _repository.exportReportToCsv(
        currentState.report,
        null,
        _factoryId,
      );
      if (res.isSuccess) {
        emit(
          ReportsLoaded(
            report: currentState.report,
            exportPath: res.dataOrNull!,
            message: 'Report exported to ${res.dataOrNull!}',
          ),
        );
      } else {
        emit(
          ReportsLoaded(
            report: currentState.report,
            message: 'CSV Export failed: ${res.failureOrNull?.message}',
          ),
        );
      }
    }
  }

  Future<void> purgeOldData(int days) async {
    final res = await _repository.purgeCheckResultsOlderThanDays(days);
    if (res.isSuccess) {
      await loadReport(_currentPeriod, _factoryId);
    }
  }
}
