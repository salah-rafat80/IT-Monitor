import 'package:equatable/equatable.dart';

import '../../domain/entities/factory_entity.dart';
import '../../domain/services/network_detection_service.dart';

class FactoryState extends Equatable {
  final List<FactoryEntity> factories;
  final FactoryEntity?
  selectedFactory; // null represents "All Factories (Consolidated)"
  final bool isLoading;
  final bool isDetectingNetwork;
  final FactoryDetectionResult? detectionResult;
  final bool isManualOverride;
  final String? errorMessage;

  const FactoryState({
    this.factories = const [],
    this.selectedFactory,
    this.isLoading = false,
    this.isDetectingNetwork = false,
    this.detectionResult,
    this.isManualOverride = false,
    this.errorMessage,
  });

  bool get isAllFactories => selectedFactory == null;
  String? get activeFactoryId => selectedFactory?.id;
  String? get selectedFactoryId => selectedFactory?.id;
  String get activeFactoryName =>
      selectedFactory?.name ?? 'All Factories (Consolidated)';
  String get activeFactoryCode => selectedFactory?.code ?? 'ALL';

  bool get requiresManualSelection =>
      selectedFactory == null &&
      detectionResult != null &&
      (detectionResult!.isAmbiguous || detectionResult!.isUnknown);

  FactoryState copyWith({
    List<FactoryEntity>? factories,
    FactoryEntity? Function()? selectedFactory,
    bool? isLoading,
    bool? isDetectingNetwork,
    FactoryDetectionResult? Function()? detectionResult,
    bool? isManualOverride,
    String? Function()? errorMessage,
  }) {
    return FactoryState(
      factories: factories ?? this.factories,
      selectedFactory: selectedFactory != null
          ? selectedFactory()
          : this.selectedFactory,
      isLoading: isLoading ?? this.isLoading,
      isDetectingNetwork: isDetectingNetwork ?? this.isDetectingNetwork,
      detectionResult: detectionResult != null
          ? detectionResult()
          : this.detectionResult,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    factories,
    selectedFactory,
    isLoading,
    isDetectingNetwork,
    detectionResult,
    isManualOverride,
    errorMessage,
  ];
}
