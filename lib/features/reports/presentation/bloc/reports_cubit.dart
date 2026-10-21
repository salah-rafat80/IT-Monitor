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

  ReportsCubit(this._repository) : super(ReportsInitial());

  Future<void> loadReport([
    ReportPeriod period = ReportPeriod.last24Hours,
  ]) async {
    emit(ReportsLoading());
    final res = await _repository.generateReport(period);
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
      final res = await _repository.exportReportToCsv(currentState.report);
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
      final currentState = state;
      final currentPeriod = currentState is ReportsLoaded
          ? currentState.report.period
          : ReportPeriod.last24Hours;
      await loadReport(currentPeriod);
    }
  }
}
