import 'dart:io';
import 'package:flutter/services.dart';

/// Service providing native Windows window management (borderless true fullscreen, frameless kiosk mode).
class WindowService {
  static const MethodChannel _channel = MethodChannel('it_network_monitor/window');

  /// Enters true borderless fullscreen mode (covers taskbar, removes title bar and window frame).
  static Future<bool> enterFullScreen() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<bool>('enterFullScreen');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Exits fullscreen mode and restores normal window decoration, borders, and position.
  static Future<bool> exitFullScreen() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<bool>('exitFullScreen');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Toggles between fullscreen and normal windowed mode.
  static Future<bool> toggleFullScreen() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<bool>('toggleFullScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Queries whether the window is currently in fullscreen mode.
  static Future<bool> isFullScreen() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isFullScreen');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
