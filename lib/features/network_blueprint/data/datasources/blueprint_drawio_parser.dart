import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:xml/xml.dart';

import '../../domain/entities/blueprint_cable_entity.dart';
import '../../domain/entities/blueprint_element_entity.dart';
import '../../domain/entities/blueprint_page_entity.dart';
import '../models/blueprint_translation_map.dart';
import '../../../theme/presentation/theme/app_palette.dart';

@lazySingleton
class BlueprintDrawioParser {
  /// Loads and parses the Draw.io XML file from Flutter asset bundle.
  Future<List<BlueprintPageEntity>> parseFromAsset(String assetPath) async {
    final xmlContent = await rootBundle.loadString(assetPath);
    Map<String, Rect>? svgBoundsMap;
    try {
      final jsonContent = await rootBundle.loadString(
        'assets/topology/rnf/blueprint_svg_index.json',
      );
      svgBoundsMap = parseSvgBoundsIndex(jsonContent);
    } catch (_) {
      // Graceful fallback if index asset is unavailable
    }
    return parseXmlString(xmlContent, svgBoundsMap: svgBoundsMap);
  }

  /// Parses an extracted SVG element index into a map of cell IDs to SVG [Rect] bounds.
  static Map<String, Rect> parseSvgBoundsIndex(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    final map = <String, Rect>{};
    for (final page in list) {
      final elements =
          (page as Map<String, dynamic>)['elements'] as List<dynamic>? ?? [];
      for (final el in elements) {
        final cellId = el['cell_id'] as String?;
        final x = (el['x'] as num?)?.toDouble() ?? 0.0;
        final y = (el['y'] as num?)?.toDouble() ?? 0.0;
        final w = (el['width'] as num?)?.toDouble() ?? 0.0;
        final h = (el['height'] as num?)?.toDouble() ?? 0.0;
        if (cellId != null && w > 0 && h > 0) {
          map[cellId] = Rect.fromLTWH(x, y, w, h);
        }
      }
    }
    return map;
  }

  /// Parses Draw.io XML content string into a list of [BlueprintPageEntity].
  List<BlueprintPageEntity> parseXmlString(
    String xmlString, {
    Map<String, Rect>? svgBoundsMap,
  }) {
    final document = XmlDocument.parse(xmlString);
    final diagramElements = document.findAllElements('diagram');

    final pages = <BlueprintPageEntity>[];

    for (final diagElem in diagramElements) {
      final page = _parseDiagram(diagElem, svgBoundsMap: svgBoundsMap);
      if (page != null) {
        pages.add(page);
      }
    }

    return pages;
  }

  BlueprintPageEntity? _parseDiagram(
    XmlElement diagElem, {
    Map<String, Rect>? svgBoundsMap,
  }) {
    final pageId = diagElem.getAttribute('id') ?? '';
    final originalName = diagElem.getAttribute('name') ?? pageId;

    // Resolve English title
    final englishTitle = BlueprintTranslationMap.pageTitles[pageId] ??
        BlueprintTranslationMap.pageTitles[originalName] ??
        originalName;

    var modelElem = diagElem.findElements('mxGraphModel').firstOrNull;
    if (modelElem == null) {
      final text = diagElem.innerText.trim();
      if (text.isNotEmpty) {
        try {
          final decodedBytes = base64.decode(text);
          final decompressed = utf8.decode(ZLibDecoder(raw: true).convert(decodedBytes));
          final urlDecoded = Uri.decodeComponent(decompressed);
          final decompDoc = XmlDocument.parse(urlDecoded);
          modelElem = decompDoc.findElements('mxGraphModel').firstOrNull ??
              decompDoc.rootElement;
        } catch (e) {
          throw FormatException(
            'Failed to decompress Draw.io diagram "$originalName": $e',
          );
        }
      }
      if (modelElem == null) {
        throw FormatException(
          'Draw.io diagram "$originalName" is missing <mxGraphModel> definition.',
        );
      }
    }

    final rootElem = modelElem.findElements('root').firstOrNull;
    if (rootElem == null) return null;

    final rawCells = <_RawCell>[];

    // Collect all cell declarations (direct mxCell or inside UserObject/object)
    for (final child in rootElem.children.whereType<XmlElement>()) {
      if (child.name.local == 'UserObject' || child.name.local == 'object') {
        final id = child.getAttribute('id');
        final label = child.getAttribute('label') ?? '';
        final innerCell = child.findElements('mxCell').firstOrNull;
        if (id != null && innerCell != null) {
          rawCells.add(_extractRawCell(id, label, innerCell));
        }
      } else if (child.name.local == 'mxCell') {
        final id = child.getAttribute('id');
        final value = child.getAttribute('value') ?? '';
        if (id != null) {
          rawCells.add(_extractRawCell(id, value, child));
        }
      }
    }

    // Index cells by ID for recursive parent coordinate lookup
    final cellMap = <String, _RawCell>{
      for (final c in rawCells) c.id: c,
    };

    // Precalculate absolute positions
    final absPositions = <String, Offset>{};
    for (final c in rawCells) {
      absPositions[c.id] = _calculateAbsolutePosition(c.id, cellMap, {});
    }

    // Precalculate Draw.io -> SVG coordinate space translation offset
    double svgOffsetX = 0.0;
    double svgOffsetY = 0.0;
    int matchedCount = 0;
    if (svgBoundsMap != null) {
      final xDiffs = <double>[];
      final yDiffs = <double>[];
      for (final cell in rawCells) {
        if (!cell.isVertex) continue;
        final svgRect = svgBoundsMap[cell.id];
        if (svgRect != null) {
          final absPos = absPositions[cell.id] ?? Offset.zero;
          xDiffs.add(svgRect.left - absPos.dx);
          yDiffs.add(svgRect.top - absPos.dy);
          matchedCount++;
        }
      }
      if (xDiffs.isNotEmpty) {
        xDiffs.sort();
        yDiffs.sort();
        svgOffsetX = xDiffs[xDiffs.length ~/ 2];
        svgOffsetY = yDiffs[yDiffs.length ~/ 2];
      }
    }

    // Build elements & cables
    final elements = <BlueprintElementEntity>[];
    final cables = <BlueprintCableEntity>[];

    for (final cell in rawCells) {
      // Ignore root containers
      if (cell.id == '0' || cell.id == '1') continue;

      if (cell.isVertex) {
        final absPos = absPositions[cell.id] ?? Offset.zero;
        final width = cell.width;
        final height = cell.height;

        // Skip completely dimensionless cells
        if (width <= 0 && height <= 0) continue;

        final rawClean = _cleanHtml(cell.label);
        final english = BlueprintTranslationMap.translate(rawClean, cellId: cell.id);
        final category = BlueprintTranslationMap.resolveCategory(english, cell.id, cell.style);

        final fillColor = _parseColor(cell.styleMap['fillColor']);
        final strokeColor = _parseColor(cell.styleMap['strokeColor']);
        final strokeWidth = double.tryParse(cell.styleMap['strokeWidth'] ?? '1') ?? 1.0;
        final isDashed = cell.styleMap['dashed'] == '1';
        final isRounded = cell.styleMap['rounded'] == '1';
        final shape = cell.styleMap['shape'] ?? 'rectangle';

        final svgRect = svgBoundsMap?[cell.id];
        final unifiedBounds = svgRect ??
            (matchedCount > 0
                ? Rect.fromLTWH(absPos.dx + svgOffsetX, absPos.dy + svgOffsetY, width, height)
                : Rect.fromLTWH(absPos.dx, absPos.dy, width, height));

        elements.add(
          BlueprintElementEntity(
            id: cell.id,
            parentId: cell.parentId,
            rawLabel: rawClean,
            englishLabel: english,
            category: category,
            bounds: unifiedBounds,
            svgBounds: unifiedBounds,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            isDashed: isDashed,
            isRounded: isRounded,
            shapeType: shape,
            rawStyle: cell.style,
          ),
        );
      } else if (cell.isEdge) {
        final strokeColor = _parseColor(cell.styleMap['strokeColor']) ?? AppPalette.defaultDark.border;
        final strokeWidth = double.tryParse(cell.styleMap['strokeWidth'] ?? '1.5') ?? 1.5;
        final isDashed = cell.styleMap['dashed'] == '1';
        final edgeStyle = cell.styleMap['edgeStyle'] ?? 'orthogonal';
        final rawClean = _cleanHtml(cell.label);
        final english = rawClean.isNotEmpty
            ? BlueprintTranslationMap.translate(rawClean, cellId: cell.id)
            : null;

        // Waypoints calculation converted to unified SVG space
        final rawWaypoints = _resolveCableWaypoints(cell, cellMap, absPositions);
        final waypoints = matchedCount > 0
            ? rawWaypoints
                .map((pt) => Offset(pt.dx + svgOffsetX, pt.dy + svgOffsetY))
                .toList()
            : rawWaypoints;
        if (waypoints.isNotEmpty) {
          cables.add(
            BlueprintCableEntity(
              id: cell.id,
              sourceId: cell.sourceId,
              targetId: cell.targetId,
              rawLabel: rawClean.isNotEmpty ? rawClean : null,
              englishLabel: english,
              strokeColor: strokeColor,
              strokeWidth: strokeWidth,
              isDashed: isDashed,
              edgeStyle: edgeStyle,
              waypoints: waypoints,
            ),
          );
        }
      }
    }

    // Calculate content bounding box
    final contentBounds = _calculateContentBounds(elements, cables);

    // Determine authoritative vector SVG and high-resolution raster asset and dimensions
    final String svgAsset;
    final String imageAsset;
    final Size svgDimension;
    if (pageId == 'Page-1' ||
        originalName.contains('الاول') ||
        englishTitle.contains('First')) {
      svgAsset = 'assets/topology/rnf/pages/first_floor.svg';
      imageAsset = 'assets/topology/rnf/pages/first_floor.png';
      svgDimension = const Size(3545, 2663);
    } else if (pageId == 'CZwG6OWdVMjHw0YqGgOi' ||
        originalName.contains('الارضي') ||
        englishTitle.contains('Ground')) {
      svgAsset = 'assets/topology/rnf/pages/ground_floor_warehouses.svg';
      imageAsset = 'assets/topology/rnf/pages/ground_floor_warehouses.png';
      svgDimension = const Size(1192, 1379);
    } else if (pageId == '2SKE6Rj-lpadhde2bo0e' ||
        originalName.contains('بواب') ||
        englishTitle.contains('Gate') ||
        englishTitle.contains('Security')) {
      svgAsset = 'assets/topology/rnf/pages/security_gates.svg';
      imageAsset = 'assets/topology/rnf/pages/security_gates.png';
      svgDimension = const Size(684, 890);
    } else {
      // Unknown diagram page: strictly avoid falling through to an unrelated background
      svgAsset = '';
      imageAsset = '';
      svgDimension = Size(
        contentBounds.width > 0 ? contentBounds.width : 1000,
        contentBounds.height > 0 ? contentBounds.height : 1000,
      );
    }

    return BlueprintPageEntity(
      id: pageId,
      drawioId: pageId,
      englishTitle: englishTitle,
      originalTitle: originalName,
      elements: elements,
      cables: cables,
      contentBounds: contentBounds,
      gridSize:
          double.tryParse(modelElem.getAttribute('gridSize') ?? '10') ?? 10.0,
      svgAssetPath: svgAsset,
      imageAssetPath: imageAsset,
      svgSize: svgDimension,
    );
  }

  _RawCell _extractRawCell(String id, String label, XmlElement cellElem) {
    final parent = cellElem.getAttribute('parent');
    final isVertex = cellElem.getAttribute('vertex') == '1';
    final isEdge = cellElem.getAttribute('edge') == '1';
    final source = cellElem.getAttribute('source');
    final target = cellElem.getAttribute('target');
    final style = cellElem.getAttribute('style') ?? '';

    final geom = cellElem.findElements('mxGeometry').firstOrNull;
    double x = 0;
    double y = 0;
    double width = 0;
    double height = 0;
    bool relative = false;
    Offset? sourcePoint;
    Offset? targetPoint;
    final points = <Offset>[];

    if (geom != null) {
      x = double.tryParse(geom.getAttribute('x') ?? '0') ?? 0;
      y = double.tryParse(geom.getAttribute('y') ?? '0') ?? 0;
      width = double.tryParse(geom.getAttribute('width') ?? '0') ?? 0;
      height = double.tryParse(geom.getAttribute('height') ?? '0') ?? 0;
      relative = geom.getAttribute('relative') == '1';

      for (final pt in geom.findElements('mxPoint')) {
        final ptAs = pt.getAttribute('as');
        final px = double.tryParse(pt.getAttribute('x') ?? '0') ?? 0;
        final py = double.tryParse(pt.getAttribute('y') ?? '0') ?? 0;
        if (ptAs == 'sourcePoint') {
          sourcePoint = Offset(px, py);
        } else if (ptAs == 'targetPoint') {
          targetPoint = Offset(px, py);
        }
      }

      final arrayElem = geom.findElements('Array').firstOrNull;
      if (arrayElem != null) {
        for (final pt in arrayElem.findElements('mxPoint')) {
          final px = double.tryParse(pt.getAttribute('x') ?? '0') ?? 0;
          final py = double.tryParse(pt.getAttribute('y') ?? '0') ?? 0;
          points.add(Offset(px, py));
        }
      }
    }

    final styleMap = <String, String>{};
    for (final segment in style.split(';')) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('=')) {
        final parts = trimmed.split('=');
        styleMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
      } else {
        styleMap[trimmed] = 'true';
      }
    }

    return _RawCell(
      id: id,
      parentId: parent,
      label: label,
      style: style,
      styleMap: styleMap,
      isVertex: isVertex,
      isEdge: isEdge,
      sourceId: source,
      targetId: target,
      x: x,
      y: y,
      width: width,
      height: height,
      relative: relative,
      sourcePoint: sourcePoint,
      targetPoint: targetPoint,
      intermediatePoints: points,
    );
  }

  Offset _calculateAbsolutePosition(
    String cellId,
    Map<String, _RawCell> cellMap,
    Set<String> visited,
  ) {
    if (visited.contains(cellId) || !cellMap.containsKey(cellId)) {
      return Offset.zero;
    }
    visited.add(cellId);

    final cell = cellMap[cellId]!;
    final pId = cell.parentId;

    if (pId != null && pId != '0' && pId != '1' && cellMap.containsKey(pId)) {
      final parentAbs = _calculateAbsolutePosition(pId, cellMap, visited);
      return Offset(parentAbs.dx + cell.x, parentAbs.dy + cell.y);
    }

    return Offset(cell.x, cell.y);
  }

  List<Offset> _resolveCableWaypoints(
    _RawCell cable,
    Map<String, _RawCell> cellMap,
    Map<String, Offset> absPositions,
  ) {
    final waypoints = <Offset>[];

    // Determine start point
    Offset? start;
    if (cable.sourcePoint != null) {
      start = cable.sourcePoint;
    } else if (cable.sourceId != null && cellMap.containsKey(cable.sourceId)) {
      final src = cellMap[cable.sourceId]!;
      final srcPos = absPositions[cable.sourceId] ?? Offset(src.x, src.y);
      start = Offset(srcPos.dx + src.width / 2, srcPos.dy + src.height / 2);
    }

    if (start != null) {
      waypoints.add(start);
    }

    // Add intermediate points
    waypoints.addAll(cable.intermediatePoints);

    // Determine end point
    Offset? end;
    if (cable.targetPoint != null) {
      end = cable.targetPoint;
    } else if (cable.targetId != null && cellMap.containsKey(cable.targetId)) {
      final tgt = cellMap[cable.targetId]!;
      final tgtPos = absPositions[cable.targetId] ?? Offset(tgt.x, tgt.y);
      end = Offset(tgtPos.dx + tgt.width / 2, tgtPos.dy + tgt.height / 2);
    }

    if (end != null) {
      waypoints.add(end);
    }

    return waypoints;
  }

  Rect _calculateContentBounds(
    List<BlueprintElementEntity> elements,
    List<BlueprintCableEntity> cables,
  ) {
    if (elements.isEmpty && cables.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1000, 800);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final el in elements) {
      final b = el.renderBounds;
      minX = minX < b.left ? minX : b.left;
      minY = minY < b.top ? minY : b.top;
      maxX = maxX > b.right ? maxX : b.right;
      maxY = maxY > b.bottom ? maxY : b.bottom;
    }

    for (final cable in cables) {
      for (final pt in cable.waypoints) {
        minX = minX < pt.dx ? minX : pt.dx;
        minY = minY < pt.dy ? minY : pt.dy;
        maxX = maxX > pt.dx ? maxX : pt.dx;
        maxY = maxY > pt.dy ? maxY : pt.dy;
      }
    }

    // Safety fallback
    if (minX == double.infinity) minX = 0;
    if (minY == double.infinity) minY = 0;
    if (maxX == -double.infinity) maxX = 1000;
    if (maxY == -double.infinity) maxY = 800;

    // Apply comfortable padding around diagram content
    const padding = 60.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null) return null;
    final trimmed = colorStr.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'none') return null;

    // Support draw.io light-dark(#light, #dark)
    if (trimmed.startsWith('light-dark(')) {
      final inner = trimmed.substring(11, trimmed.length - 1);
      final parts = inner.split(',');
      if (parts.isNotEmpty) {
        return _parseColor(parts[0].trim());
      }
    }

    if (trimmed.startsWith('#')) {
      final hex = trimmed.substring(1);
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        return val != null ? Color(val) : null;
      } else if (hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        return val != null ? Color(val) : null;
      } else if (hex.length == 3) {
        final r = hex[0];
        final g = hex[1];
        final b = hex[2];
        final val = int.tryParse('FF$r$r$g$g$b$b', radix: 16);
        return val != null ? Color(val) : null;
      }
    }

    return null;
  }

  String _cleanHtml(String raw) {
    if (raw.isEmpty) return '';
    var text = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return text.trim();
  }
}

class _RawCell {
  final String id;
  final String? parentId;
  final String label;
  final String style;
  final Map<String, String> styleMap;
  final bool isVertex;
  final bool isEdge;
  final String? sourceId;
  final String? targetId;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool relative;
  final Offset? sourcePoint;
  final Offset? targetPoint;
  final List<Offset> intermediatePoints;

  const _RawCell({
    required this.id,
    this.parentId,
    required this.label,
    required this.style,
    required this.styleMap,
    required this.isVertex,
    required this.isEdge,
    this.sourceId,
    this.targetId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.relative,
    this.sourcePoint,
    this.targetPoint,
    required this.intermediatePoints,
  });
}
