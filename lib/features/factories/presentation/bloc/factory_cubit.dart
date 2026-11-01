import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/factory_entity.dart';
import '../../domain/repositories/factory_repository.dart';
import '../../domain/services/network_detection_service.dart';
import 'factory_state.dart';
export 'factory_state.dart';

@lazySingleton
class FactoryCubit extends Cubit<FactoryState> {
  final FactoryRepository _factoryRepository;
  final NetworkDetectionService _networkDetectionService;
  StreamSubscription? _factoriesSub;

  FactoryCubit(this._factoryRepository, this._networkDetectionService)
    : super(const FactoryState()) {
    _init();
  }

  void _init() {
    loadFactories();
    _factoriesSub = _factoryRepository.watchFactories().listen((factories) {
      final active = factories
          .where((f) => f.isActive && f.id != 'unassigned')
          .toList();
      FactoryEntity? updatedSelected = state.selectedFactory;
      if (updatedSelected != null) {
        final match = active
            .where((f) => f.id == updatedSelected!.id)
            .firstOrNull;
        updatedSelected = match;
      }
      emit(
        state.copyWith(
          factories: active,
          selectedFactory: () => updatedSelected,
        ),
      );
    });
  }

  Future<void> loadFactories({
    bool autoDetect = true,
    List<String>? mockLocalIps,
    List<NetworkInterface>? mockInterfaces,
  }) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    final res = await _factoryRepository.getFactories(includeInactive: false);
    if (res.isSuccess && res.dataOrNull != null) {
      final active = res.dataOrNull!
          .where((f) => f.id != 'unassigned')
          .toList();

      if (!autoDetect) {
        emit(state.copyWith(factories: active, isLoading: false));
        return;
      }

      emit(state.copyWith(factories: active, isDetectingNetwork: true));

      final detectionResult = await _networkDetectionService.detectFactory(
        factories: active,
        mockLocalIps: mockLocalIps,
        mockInterfaces: mockInterfaces,
      );

      FactoryEntity? initial = state.selectedFactory;
      final isManual = state.isManualOverride;

      if (!isManual) {
        if (detectionResult.isDetected) {
          initial = detectionResult.detectedFactory;
        } else {
          // Ambiguous or Unknown network: NEVER silently default to BNF or RNF!
          initial = null;
        }
      }

      emit(
        state.copyWith(
          factories: active,
          selectedFactory: () => initial,
          detectionResult: () => detectionResult,
          isDetectingNetwork: false,
          isLoading: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: () =>
              res.failureOrNull?.message ?? 'Failed to load factories',
        ),
      );
    }
  }

  Future<void> revalidateNetworkDetection({
    List<String>? mockLocalIps,
    List<NetworkInterface>? mockInterfaces,
  }) async {
    emit(state.copyWith(isDetectingNetwork: true));
    final detectionResult = await _networkDetectionService.detectFactory(
      factories: state.factories,
      mockLocalIps: mockLocalIps,
      mockInterfaces: mockInterfaces,
    );

    FactoryEntity? newSelected = state.selectedFactory;
    if (!state.isManualOverride) {
      if (detectionResult.isDetected) {
        newSelected = detectionResult.detectedFactory;
      } else {
        newSelected = null;
      }
    }

    emit(
      state.copyWith(
        detectionResult: () => detectionResult,
        selectedFactory: () => newSelected,
        isDetectingNetwork: false,
      ),
    );
  }

  void selectFactory(FactoryEntity? factory, {bool isManual = true}) {
    emit(
      state.copyWith(
        selectedFactory: () => factory,
        isManualOverride: isManual,
      ),
    );
  }

  void selectFactoryById(String? factoryId, {bool isManual = true}) {
    if (factoryId == null ||
        factoryId.isEmpty ||
        factoryId.toLowerCase() == 'all') {
      emit(
        state.copyWith(selectedFactory: () => null, isManualOverride: isManual),
      );
      return;
    }
    final match = state.factories
        .where((f) => f.id.toLowerCase() == factoryId.toLowerCase())
        .firstOrNull;
    if (match != null) {
      emit(
        state.copyWith(
          selectedFactory: () => match,
          isManualOverride: isManual,
        ),
      );
    }
  }

  Future<bool> addFactory({
    required String code,
    required String name,
    String? gatewayIp,
    String? subnetMask,
    String? expectedCidr,
  }) async {
    final entity = FactoryEntity(
      id: FactoryEntity.generateId(code),
      code: code.trim().toUpperCase(),
      name: name.trim(),
      gatewayIp: gatewayIp?.trim(),
      subnetMask: subnetMask?.trim(),
      expectedCidr: expectedCidr?.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    final res = await _factoryRepository.createFactory(entity);
    if (res.isSuccess) {
      await loadFactories(autoDetect: false);
      selectFactory(res.dataOrNull);
      return true;
    } else {
      emit(state.copyWith(errorMessage: () => res.failureOrNull?.message));
      return false;
    }
  }

  Future<bool> updateFactoryNetworkSettings({
    required String factoryId,
    required String? gatewayIp,
    required String? subnetMask,
    required String? expectedCidr,
  }) async {
    final match = state.factories
        .where((f) => f.id.toLowerCase() == factoryId.toLowerCase())
        .firstOrNull;
    if (match == null) return false;

    final updated = match.copyWith(
      gatewayIp: gatewayIp?.trim(),
      subnetMask: subnetMask?.trim(),
      expectedCidr: expectedCidr?.trim(),
      updatedAt: DateTime.now(),
    );

    final res = await _factoryRepository.updateFactory(updated);
    if (res.isSuccess) {
      await loadFactories(autoDetect: false);
      if (state.selectedFactory?.id == factoryId) {
        selectFactory(res.dataOrNull, isManual: state.isManualOverride);
      }
      return true;
    } else {
      emit(state.copyWith(errorMessage: () => res.failureOrNull?.message));
      return false;
    }
  }

  @override
  Future<void> close() {
    _factoriesSub?.cancel();
    return super.close();
  }
}
