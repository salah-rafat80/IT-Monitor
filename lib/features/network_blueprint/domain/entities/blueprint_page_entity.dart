import 'dart:ui';
import 'package:equatable/equatable.dart';

import 'blueprint_cable_entity.dart';
import 'blueprint_element_entity.dart';

class BlueprintPageEntity extends Equatable {
  final String id;
  final String drawioId;
  final String englishTitle;
  final String originalTitle;
  final List<BlueprintElementEntity> elements;
  final List<BlueprintCableEntity> cables;
  final Rect contentBounds;
  final double gridSize;
  final String svgAssetPath;
  final String imageAssetPath;
  final Size svgSize;

  const BlueprintPageEntity({
    required this.id,
    required this.drawioId,
    required this.englishTitle,
    required this.originalTitle,
    required this.elements,
    required this.cables,
    required this.contentBounds,
    this.gridSize = 10.0,
    this.svgAssetPath = '',
    this.imageAssetPath = '',
    this.svgSize = const Size(1000, 1000),
  });

  /// Total width of the diagram content
  double get contentWidth => svgSize.width > 0 ? svgSize.width : contentBounds.width;

  /// Total height of the diagram content
  double get contentHeight => svgSize.height > 0 ? svgSize.height : contentBounds.height;

  BlueprintPageEntity copyWith({
    String? id,
    String? drawioId,
    String? englishTitle,
    String? originalTitle,
    List<BlueprintElementEntity>? elements,
    List<BlueprintCableEntity>? cables,
    Rect? contentBounds,
    double? gridSize,
    String? svgAssetPath,
    String? imageAssetPath,
    Size? svgSize,
  }) {
    return BlueprintPageEntity(
      id: id ?? this.id,
      drawioId: drawioId ?? this.drawioId,
      englishTitle: englishTitle ?? this.englishTitle,
      originalTitle: originalTitle ?? this.originalTitle,
      elements: elements ?? this.elements,
      cables: cables ?? this.cables,
      contentBounds: contentBounds ?? this.contentBounds,
      gridSize: gridSize ?? this.gridSize,
      svgAssetPath: svgAssetPath ?? this.svgAssetPath,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
      svgSize: svgSize ?? this.svgSize,
    );
  }

  @override
  List<Object?> get props => [
    id,
    drawioId,
    englishTitle,
    originalTitle,
    elements,
    cables,
    contentBounds,
    gridSize,
    svgAssetPath,
    imageAssetPath,
    svgSize,
  ];
}
