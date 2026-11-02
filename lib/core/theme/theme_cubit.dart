import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

class ThemeState extends Equatable {
  final ThemeMode themeMode;

  const ThemeState({this.themeMode = ThemeMode.dark});

  bool get isDark => themeMode == ThemeMode.dark;
  bool get isLight => themeMode == ThemeMode.light;

  ThemeState copyWith({ThemeMode? themeMode}) {
    return ThemeState(themeMode: themeMode ?? this.themeMode);
  }

  @override
  List<Object?> get props => [themeMode];
}

@lazySingleton
class ThemeCubit extends Cubit<ThemeState> {
  static const String _prefFileName = 'theme_preference.json';
  static String? defaultCustomConfigPath;
  String? _customConfigPath;

  ThemeCubit({String? customConfigPath})
    : super(const ThemeState(themeMode: ThemeMode.dark)) {
    _customConfigPath = customConfigPath ?? defaultCustomConfigPath;
    _loadPreference();
  }

  /// Optional static path for test isolation
  static void setCustomConfigPath(String? path) {
    defaultCustomConfigPath = path;
  }

  /// Optional instance path for test isolation
  void setCustomPath(String? path) {
    _customConfigPath = path;
    _loadPreference();
  }

  File _getPreferenceFile() {
    if (_customConfigPath != null) {
      return File(_customConfigPath!);
    }
    final programData = Platform.environment['ProgramData'];
    if (programData != null && programData.isNotEmpty) {
      return File(p.join(programData, 'ITNetworkMonitor', _prefFileName));
    }
    return File(_prefFileName);
  }

  void _loadPreference() {
    try {
      final file = _getPreferenceFile();
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final modeStr = json['themeMode'] as String?;
        if (modeStr == 'light') {
          emit(const ThemeState(themeMode: ThemeMode.light));
          return;
        } else if (modeStr == 'dark') {
          emit(const ThemeState(themeMode: ThemeMode.dark));
          return;
        }
      }
    } catch (_) {
      // Fallback default: Dark mode on first install
    }
    emit(const ThemeState(themeMode: ThemeMode.dark));
  }

  void setThemeMode(ThemeMode mode) {
    if (state.themeMode == mode) return;
    emit(state.copyWith(themeMode: mode));
    _persistPreference(mode);
  }

  void toggleTheme() {
    final next = state.isDark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  void _persistPreference(ThemeMode mode) {
    try {
      final file = _getPreferenceFile();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final data = jsonEncode({'themeMode': mode.name});
      file.writeAsStringSync(data, flush: true);
    } catch (_) {}
  }
}
