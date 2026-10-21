import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/device_status_entity.dart';
import '../../domain/entities/monitoring_config.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../../domain/services/monitoring_scheduler.dart';

sealed class MonitoringState extends Equatable {
  const MonitoringState();

  @override
  List<Object?> get props => [];
}

final class MonitoringInitial extends MonitoringState {
  const MonitoringInitial();
}

final class MonitoringActive extends MonitoringState {
  final List<DeviceStatusEntity> statuses;
  final bool isRunning;
  final bool isPaused;
  final MonitoringConfig config;

  const MonitoringActive({
    required this.statuses,
    required this.isRunning,
    required this.isPaused,
    required this.config,
  });

  @override
  List<Object?> get props => [statuses, isRunning, isPaused, config];
}

final class MonitoringError extends MonitoringState {
  final String message;

  const MonitoringError(this.message);

  @override
  List<Object?> get props => [message];
}

@injectable
class MonitoringCubit extends Cubit<MonitoringState> {
  final MonitoringScheduler _scheduler;
  final MonitoringRepository _monitoringRepo;
  StreamSubscription<List<DeviceStatusEntity>>? _statusSubscription;

  MonitoringCubit(this._scheduler, this._monitoringRepo)
    : super(const MonitoringInitial());

  Future<void> initMonitoring({bool startScheduler = false}) async {
    final initialStatusesRes = await _monitoringRepo.getDeviceStatuses();
    if (isClosed) return;
    final initialStatuses = initialStatusesRes.dataOrNull ?? [];

    emit(
      MonitoringActive(
        statuses: initialStatuses,
        isRunning: _scheduler.isRunning,
        isPaused: _scheduler.isPaused,
        config: _scheduler.config,
      ),
    );

    _statusSubscription?.cancel();
    _statusSubscription = _monitoringRepo.watchAllDeviceStatuses().listen((
      statuses,
    ) {
      if (isClosed) return;
      final current = state;
      if (current is MonitoringActive) {
        emit(
          MonitoringActive(
            statuses: statuses,
            isRunning: _scheduler.isRunning,
            isPaused: _scheduler.isPaused,
            config: _scheduler.config,
          ),
        );
      }
    });

    // Authoritative monitoring is owned by the Windows background service.
    // Only start scheduler locally if explicitly requested (e.g. standalone test mode).
    if (startScheduler) {
      _scheduler.startMonitoring();
    }
  }

  void toggleMonitoringEngine() {
    if (_scheduler.isRunning) {
      _scheduler.stopMonitoring();
    } else {
      _scheduler.startMonitoring();
    }

    final current = state;
    if (current is MonitoringActive) {
      emit(
        MonitoringActive(
          statuses: current.statuses,
          isRunning: _scheduler.isRunning,
          isPaused: _scheduler.isPaused,
          config: _scheduler.config,
        ),
      );
    }
  }

  Future<void> setMaintenanceMode({
    required int deviceId,
    required bool isMaintenance,
  }) async {
    final res = await _monitoringRepo.setMaintenanceMode(
      deviceId: deviceId,
      isMaintenance: isMaintenance,
    );

    res.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(MonitoringError(failure.message)),
    );
  }

  void updateConfig(MonitoringConfig newConfig) {
    _scheduler.updateConfig(newConfig);
    final current = state;
    if (current is MonitoringActive) {
      emit(
        MonitoringActive(
          statuses: current.statuses,
          isRunning: current.isRunning,
          isPaused: current.isPaused,
          config: newConfig,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }
}
