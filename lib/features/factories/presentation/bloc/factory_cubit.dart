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
  Timer? _networkPollTimer;
  Set<String> _lastDetectedIps = {};

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

    // Controlled periodic network revalidation (runs every 10s to detect network changes)
    _networkPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => checkNetworkInterfaces(),
    );
  }

  Future<void> loadFactories({
    bool autoDetect = true,
    List<String>? mockLocalIps,
    List<NetworkInterface>? mockInterfaces,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    final res = await _factoryRepository.getFactories(includeInactive: false);
    if (isClosed) return;
    if (res.isSuccess && res.dataOrNull != null) {
      final active = res.dataOrNull!
          .where((f) => f.id != 'unassigned')
          .toList();

      if (!autoDetect) {
        if (!isClosed) {
          emit(state.copyWith(factories: active, isLoading: false));
        }
        return;
      }

      if (!isClosed) {
        emit(state.copyWith(factories: active, isDetectingNetwork: true));
      }

      final detectionResult = await _networkDetectionService.detectFactory(
        factories: active,
        mockLocalIps: mockLocalIps,
        mockInterfaces: mockInterfaces,
      );
      if (isClosed) {
        return;
      }

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
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: () =>
                res.failureOrNull?.message ?? 'Failed to load factories',
          ),
        );
      }
    }
  }

  Future<void> checkNetworkInterfaces({
    List<String>? mockLocalIps,
    List<NetworkInterface>? mockInterfaces,
  }) async {
    if (isClosed || state.factories.isEmpty) return;

    final currentIps = mockLocalIps != null
        ? mockLocalIps.toSet()
        : (await _networkDetectionService.getLocalIpv4Addresses(
            mockInterfaces: mockInterfaces,
          )).toSet();
    if (isClosed) return;

    // Avoid unnecessary repeated scans if interface IPs have not changed
    if (_lastDetectedIps.isNotEmpty &&
        _lastDetectedIps.length == currentIps.length &&
        _lastDetectedIps.containsAll(currentIps)) {
      return;
    }

    _lastDetectedIps = currentIps;

    final detectionResult = await _networkDetectionService.detectFactory(
      factories: state.factories,
      mockLocalIps: mockLocalIps ?? currentIps.toList(),
      mockInterfaces: mockInterfaces,
    );
    if (isClosed) return;

    // Preserve administrator manual override behavior until explicitly cleared
    if (state.isManualOverride) {
      emit(state.copyWith(detectionResult: () => detectionResult));
      return;
    }

    FactoryEntity? newSelected = state.selectedFactory;
    if (detectionResult.isDetected) {
      // Confirmed factory change (e.g. movement from RNF to BNF or BNF to RNF)
      newSelected = detectionResult.detectedFactory;
    } else {
      // Do not silently change to All Factories when ambiguous or unknown!
      // Keep existing selected factory context and display detectionResult badge.
      newSelected = state.selectedFactory;
    }

    emit(
      state.copyWith(
        detectionResult: () => detectionResult,
        selectedFactory: () => newSelected,
      ),
    );
  }

  Future<void> revalidateNetworkDetection({
    List<String>? mockLocalIps,
    List<NetworkInterface>? mockInterfaces,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(isDetectingNetwork: true));
    final detectionResult = await _networkDetectionService.detectFactory(
      factories: state.factories,
      mockLocalIps: mockLocalIps,
      mockInterfaces: mockInterfaces,
    );
    if (isClosed) return;

    FactoryEntity? newSelected = state.selectedFactory;
    if (!state.isManualOverride) {
      if (detectionResult.isDetected) {
        newSelected = detectionResult.detectedFactory;
      } else {
        // Do not silently change to All Factories when ambiguous or unknown!
        newSelected = state.selectedFactory;
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

  Future<void> clearManualOverride({
    List<String>? mockLocalIps,
    List<NetworkInterface>? mockInterfaces,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(isManualOverride: false));
    _lastDetectedIps.clear();
    await revalidateNetworkDetection(
      mockLocalIps: mockLocalIps,
      mockInterfaces: mockInterfaces,
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
    _networkPollTimer?.cancel();
    _factoriesSub?.cancel();
    return super.close();
  }
}
