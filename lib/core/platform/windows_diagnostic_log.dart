import 'dart:io';

class WindowsDiagnosticLog {
  WindowsDiagnosticLog._();

  static Future<void> _pendingWrite = Future<void>.value();

  static String? get filePath {
    if (!Platform.isWindows) {
      return null;
    }
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      return null;
    }
    final separator = Platform.pathSeparator;
    return '$localAppData${separator}AI Limit Status'
        '${separator}windows-popup-diagnostic.log';
  }

  static void write(String event) {
    final path = filePath;
    if (path == null) {
      return;
    }
    final timestamp = DateTime.now().toIso8601String();
    _pendingWrite = _pendingWrite
        .then((_) async {
          final file = File(path);
          await file.parent.create(recursive: true);
          await file.writeAsString(
            '$timestamp [dart] $event\n',
            mode: FileMode.append,
            flush: true,
          );
        })
        .catchError((_) {
          // Diagnostics must never affect the application runtime.
        });
  }
}
