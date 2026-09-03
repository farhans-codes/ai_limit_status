import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/core/diagnostics/app_log.dart';
import 'package:flutter/services.dart';

/// Stores a claude.ai `sessionKey` the user pasted in Settings.
///
/// Windows only: the value is encrypted with the user's DPAPI key by the
/// runner (`protect`/`unprotect` on the secure-store channel) before it
/// touches disk, so only the same Windows account can read it back. On other
/// platforms the store reports itself unsupported and the app keeps relying
/// on the automatic browser-session readers.
class ManualClaudeSessionStore {
  static const _channel = MethodChannel('com.ailimitstatus/secure_store');
  static const _fileName = 'claude_session.bin';

  bool get isSupported => Platform.isWindows;

  Future<bool> exists() async {
    final file = _file();
    return file != null && await file.exists();
  }

  Future<String?> read() async {
    final file = _file();
    if (file == null) {
      return null;
    }
    try {
      if (!await file.exists()) {
        return null;
      }
      final protectedBytes = await file.readAsBytes();
      final plain = await _channel.invokeMethod<Uint8List>('unprotect', {
        'data': protectedBytes,
      });
      if (plain == null || plain.isEmpty) {
        return null;
      }
      final value = utf8.decode(plain).trim();
      return value.isEmpty ? null : value;
    } on Object catch (error) {
      AppLog.log('manual session: read failed: ${error.runtimeType}');
      return null;
    }
  }

  Future<bool> write(String sessionKey) async {
    final file = _file();
    if (file == null) {
      return false;
    }
    try {
      final protectedBytes = await _channel.invokeMethod<Uint8List>('protect', {
        'data': Uint8List.fromList(utf8.encode(sessionKey.trim())),
      });
      if (protectedBytes == null || protectedBytes.isEmpty) {
        return false;
      }
      await file.parent.create(recursive: true);
      await file.writeAsBytes(protectedBytes, flush: true);
      return true;
    } on Object catch (error) {
      AppLog.log('manual session: write failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<bool> clear() async {
    final file = _file();
    if (file == null) {
      return false;
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  File? _file() {
    if (!isSupported) {
      return null;
    }
    final environment = Platform.environment;
    final base = environment['LOCALAPPDATA'] ?? environment['USERPROFILE'];
    if (base == null) {
      return null;
    }
    return File('$base\\AI Limit Status\\$_fileName');
  }
}
