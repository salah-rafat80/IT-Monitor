import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/factory_entity.dart';
import '../../domain/repositories/factory_repository.dart';
import 'factory_state.dart';
export 'factory_state.dart';

@lazySingleton
class FactoryCubit extends Cubit<FactoryState> {
  final FactoryRepository _factoryRepository;
  StreamSubscription? _factoriesSub;

  FactoryCubit(this._factoryRepository) : super(const FactoryState()) {
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

  Future<void> loadFactories() async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    final res = await _factoryRepository.getFactories(includeInactive: false);
    if (res.isSuccess && res.dataOrNull != null) {
      final active = res.dataOrNull!
          .where((f) => f.id != 'unassigned')
          .toList();
      FactoryEntity? initial = state.selectedFactory;
      if (initial == null && active.isNotEmpty) {
        initial =
            active.where((f) => f.code == 'BNF').firstOrNull ?? active.first;
      }
      emit(
        state.copyWith(
          factories: active,
          selectedFactory: () => initial,
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

  void selectFactory(FactoryEntity? factory) {
    emit(state.copyWith(selectedFactory: () => factory));
  }

  void selectFactoryById(String? factoryId) {
    if (factoryId == null ||
        factoryId.isEmpty ||
        factoryId.toLowerCase() == 'all') {
      emit(state.copyWith(selectedFactory: () => null));
      return;
    }
    final match = state.factories
        .where((f) => f.id.toLowerCase() == factoryId.toLowerCase())
        .firstOrNull;
    if (match != null) {
      emit(state.copyWith(selectedFactory: () => match));
    }
  }

  Future<bool> addFactory({required String code, required String name}) async {
    final entity = FactoryEntity(
      id: FactoryEntity.generateId(code),
      code: code.trim().toUpperCase(),
      name: name.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    final res = await _factoryRepository.createFactory(entity);
    if (res.isSuccess) {
      await loadFactories();
      selectFactory(res.dataOrNull);
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
