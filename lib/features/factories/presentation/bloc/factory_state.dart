import 'package:equatable/equatable.dart';

import '../../domain/entities/factory_entity.dart';

class FactoryState extends Equatable {
  final List<FactoryEntity> factories;
  final FactoryEntity?
  selectedFactory; // null represents "All Factories (Consolidated)"
  final bool isLoading;
  final String? errorMessage;

  const FactoryState({
    this.factories = const [],
    this.selectedFactory,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAllFactories => selectedFactory == null;
  String? get activeFactoryId => selectedFactory?.id;
  String? get selectedFactoryId => selectedFactory?.id;
  String get activeFactoryName =>
      selectedFactory?.name ?? 'All Factories (Consolidated)';
  String get activeFactoryCode => selectedFactory?.code ?? 'ALL';

  FactoryState copyWith({
    List<FactoryEntity>? factories,
    FactoryEntity? Function()? selectedFactory,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return FactoryState(
      factories: factories ?? this.factories,
      selectedFactory: selectedFactory != null
          ? selectedFactory()
          : this.selectedFactory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    factories,
    selectedFactory,
    isLoading,
    errorMessage,
  ];
}
