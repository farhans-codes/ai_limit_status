import 'dart:io';

import 'package:ai_limit_status/core/diagnostics/app_log.dart';
import 'package:flutter/services.dart';

/// Status and helpers for the opt-in Windows browser extension bridge that
/// hands the app the signed-in claude.ai / chatgpt.com sessions.
class BrowserBridgeService {
  static const _channel = MethodChannel('com.ailimitstatus/keychain');
  static const _probeTimeout = Duration(seconds: 2);

  bool get isSupported => Platform.isWindows;

  /// Whether a browser currently has the bridge extension loaded and its
  /// native host running. `null` when the platform has no bridge.
  Future<bool?> isConnected() async {
    if (!isSupported) {
      return null;
    }
    try {
      final connected = await _channel
          .invokeMethod<bool>('isWindowsBrowserBridgeConnected')
          .timeout(_probeTimeout);
      return connected ?? false;
    } on Object catch (error) {
      AppLog.log('bridge: status probe failed: ${error.runtimeType}');
      return false;
    }
  }

  /// The unpacked Chromium extension folder shipped next to the executable,
  /// or `null` when it is not bundled (for example in a `flutter run` build).
  Directory? extensionDirectory() {
    if (!isSupported) {
      return null;
    }
    final executable = File(Platform.resolvedExecutable);
    final directory = Directory(
      '${executable.parent.path}\\browser_extension\\chromium',
    );
    return directory.existsSync() ? directory : null;
  }

  /// Opens the extension folder in Explorer so "Load unpacked" is one step
  /// away. Returns `false` when the folder is missing or cannot be opened.
  Future<bool> openExtensionFolder() async {
    final directory = extensionDirectory();
    if (directory == null) {
      return false;
    }
    try {
      await Process.start('explorer.exe', [directory.path]);
      return true;
    } on Object catch (error) {
      AppLog.log('bridge: could not open extension folder: $error');
      return false;
    }
  }
}
