import 'dart:ui';
import 'package:equatable/equatable.dart';

class BlueprintCableEntity extends Equatable {
  final String id;
  final String? sourceId;
  final String? targetId;
  final String? rawLabel;
  final String? englishLabel;
  final Color strokeColor;
  final double strokeWidth;
  final bool isDashed;
  final String edgeStyle;
  final List<Offset> waypoints;

  const BlueprintCableEntity({
    required this.id,
    this.sourceId,
    this.targetId,
    this.rawLabel,
    this.englishLabel,
    required this.strokeColor,
    this.strokeWidth = 1.5,
    this.isDashed = false,
    this.edgeStyle = 'orthogonal',
    required this.waypoints,
  });

  @override
  List<Object?> get props => [
        id,
        sourceId,
        targetId,
        rawLabel,
        englishLabel,
        strokeColor,
        strokeWidth,
        isDashed,
        edgeStyle,
        waypoints,
      ];
}
