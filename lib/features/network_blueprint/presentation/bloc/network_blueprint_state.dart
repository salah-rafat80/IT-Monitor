import 'package:equatable/equatable.dart';

import '../../domain/entities/blueprint_element_entity.dart';
import '../../domain/entities/blueprint_page_entity.dart';

sealed class NetworkBlueprintState extends Equatable {
  const NetworkBlueprintState();
}

final class NetworkBlueprintLoading extends NetworkBlueprintState {
  const NetworkBlueprintLoading();

  @override
  List<Object?> get props => [];
}

final class NetworkBlueprintLoaded extends NetworkBlueprintState {
  final List<BlueprintPageEntity> pages;
  final int selectedPageIndex;
  final BlueprintElementEntity? selectedElement;
  final String searchQuery;
  final bool isLiveMonitoringActive;

  const NetworkBlueprintLoaded({
    required this.pages,
    this.selectedPageIndex = 0,
    this.selectedElement,
    this.searchQuery = '',
    this.isLiveMonitoringActive = true,
  });

  BlueprintPageEntity get currentPage =>
      pages.isNotEmpty && selectedPageIndex < pages.length
          ? pages[selectedPageIndex]
          : pages.first;

  List<BlueprintElementEntity> get filteredElements {
    if (searchQuery.trim().isEmpty) return currentPage.elements;
    final q = searchQuery.trim().toLowerCase();
    return currentPage.elements.where((e) {
      return e.englishLabel.toLowerCase().contains(q) ||
          e.rawLabel.toLowerCase().contains(q) ||
          (e.mappedIp?.toLowerCase().contains(q) ?? false) ||
          (e.mappedDeviceName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  NetworkBlueprintLoaded copyWith({
    List<BlueprintPageEntity>? pages,
    int? selectedPageIndex,
    BlueprintElementEntity? selectedElement,
    bool clearSelectedElement = false,
    String? searchQuery,
    bool? isLiveMonitoringActive,
  }) {
    return NetworkBlueprintLoaded(
      pages: pages ?? this.pages,
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
      selectedElement: clearSelectedElement
          ? null
          : (selectedElement ?? this.selectedElement),
      searchQuery: searchQuery ?? this.searchQuery,
      isLiveMonitoringActive:
          isLiveMonitoringActive ?? this.isLiveMonitoringActive,
    );
  }

  @override
  List<Object?> get props => [
        pages,
        selectedPageIndex,
        selectedElement,
        searchQuery,
        isLiveMonitoringActive,
      ];
}

final class NetworkBlueprintError extends NetworkBlueprintState {
  final String message;

  const NetworkBlueprintError(this.message);

  @override
  List<Object?> get props => [message];
}
