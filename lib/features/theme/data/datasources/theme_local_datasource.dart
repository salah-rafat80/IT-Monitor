import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/palette_entity.dart';
import '../models/palette_model.dart';

abstract class ThemeLocalDataSource {
  PaletteModel getSavedPaletteSync();
  Future<PaletteModel> getSavedPalette();
  Future<void> savePalette(PaletteModel palette);
  String getSavedThemeModeSync();
  Future<String> getSavedThemeMode();
  Future<void> saveThemeMode(String mode);
  void setCustomConfigPath(String? path);
}

@LazySingleton(as: ThemeLocalDataSource)
class ThemeLocalDataSourceImpl implements ThemeLocalDataSource {
  static const String _prefFileName = 'theme_preference.json';
  static String? globalCustomConfigPath;
  String? _instanceCustomConfigPath;

  ThemeLocalDataSourceImpl() {
    _instanceCustomConfigPath = globalCustomConfigPath;
  }

  @override
  void setCustomConfigPath(String? path) {
    _instanceCustomConfigPath = path;
  }

  File _getPreferenceFile() {
    if (_instanceCustomConfigPath != null) {
      return File(_instanceCustomConfigPath!);
    }
    // Check if bundled next to executable in portable mode
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final portablePref = File(p.join(exeDir, _prefFileName));
    if (portablePref.existsSync()) {
      return portablePref;
    }
    final programData = Platform.environment['ProgramData'];
    if (programData != null && programData.isNotEmpty) {
      return File(p.join(programData, 'ITNetworkMonitor', _prefFileName));
    }
    return File(_prefFileName);
  }

  Map<String, dynamic> _readContentMap() {
    try {
      final file = _getPreferenceFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        if (content.trim().isNotEmpty) {
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return {};
  }

  void _writeContentMap(Map<String, dynamic> map) {
    try {
      final file = _getPreferenceFile();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(map), flush: true);
    } catch (e) {
      throw FileSystemException(
        'Failed to persist theme preference configuration: $e',
      );
    }
  }

  @override
  PaletteModel getSavedPaletteSync() {
    final map = _readContentMap();
    if (map.containsKey('palette') && map['palette'] is Map<String, dynamic>) {
      return PaletteModel.fromJson(map['palette'] as Map<String, dynamic>);
    }
    return PaletteModel.fromEntity(PaletteEntity.defaultPalette);
  }

  @override
  Future<PaletteModel> getSavedPalette() async {
    return getSavedPaletteSync();
  }

  @override
  Future<void> savePalette(PaletteModel palette) async {
    final map = _readContentMap();
    map['palette'] = palette.toJson();
    _writeContentMap(map);
  }

  @override
  String getSavedThemeModeSync() {
    final map = _readContentMap();
    return map['themeMode'] as String? ?? 'dark';
  }

  @override
  Future<String> getSavedThemeMode() async {
    return getSavedThemeModeSync();
  }

  @override
  Future<void> saveThemeMode(String mode) async {
    final map = _readContentMap();
    map['themeMode'] = mode;
    _writeContentMap(map);
  }
}
