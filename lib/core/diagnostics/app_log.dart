import 'dart:async';
import 'dart:io';

/// Small local diagnostic log so Windows/macOS bug reports can say what the
/// app actually did (window toggles, provider source attempts, failures).
///
/// The log never contains tokens, cookies, or usage payloads; callers log
/// outcomes and status codes only. It lives next to the app's other local
/// files and is capped at [_maximumBytes] with a single rotated copy.
class AppLog {
  AppLog._();

  static const _maximumBytes = 512 * 1024;
  static const _sizeCheckInterval = 64;

  static File? _file;
  static Future<void> _pending = Future<void>.value();
  static int _linesSinceSizeCheck = 0;
  static bool _enabled = true;

  /// The active log file, or `null` when logging is disabled or unavailable.
  static File? get file => _enabled ? (_file ??= _resolveFile()) : null;

  static set enabled(bool value) => _enabled = value;

  static void log(String message) {
    if (!_enabled) {
      return;
    }
    final target = file;
    if (target == null) {
      return;
    }
    final line = '${DateTime.now().toIso8601String()} $message\n';
    _pending = _pending
        .then((_) => _append(target, line))
        .catchError((Object _) {});
  }

  static Future<void> _append(File target, String line) async {
    if (++_linesSinceSizeCheck >= _sizeCheckInterval) {
      _linesSinceSizeCheck = 0;
      await _rotateIfNeeded(target);
    }
    await target.parent.create(recursive: true);
    await target.writeAsString(line, mode: FileMode.append, flush: true);
  }

  static Future<void> _rotateIfNeeded(File target) async {
    try {
      if (!await target.exists() || await target.length() < _maximumBytes) {
        return;
      }
      final rotated = File('${target.path}.1');
      if (await rotated.exists()) {
        await rotated.delete();
      }
      await target.rename(rotated.path);
    } on FileSystemException {
      // Rotation is best effort; keep appending to the current file.
    }
  }

  static File? _resolveFile() {
    try {
      final environment = Platform.environment;
      if (Platform.isWindows) {
        final base = environment['LOCALAPPDATA'] ?? environment['USERPROFILE'];
        if (base == null) {
          return null;
        }
        return File('$base\\AI Limit Status\\logs\\app.log');
      }
      final home = environment['HOME'];
      if (Platform.isMacOS && home != null) {
        return File('$home/Library/Logs/AI Limit Status/app.log');
      }
      final stateHome = environment['XDG_STATE_HOME'];
      if (stateHome != null) {
        return File('$stateHome/ai_limit_status/app.log');
      }
      if (home != null) {
        return File('$home/.local/state/ai_limit_status/app.log');
      }
      return null;
    } on Object {
      return null;
    }
  }
}
