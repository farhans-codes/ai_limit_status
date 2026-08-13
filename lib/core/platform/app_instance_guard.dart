import 'dart:io';

class AppInstanceGuard {
  AppInstanceGuard._();

  static RandomAccessFile? _lockHandle;

  static Future<bool> acquire() async {
    if (_lockHandle != null) {
      return true;
    }

    final lockFile = File(
      '${_applicationSupportDirectory().path}/instance.lock',
    );
    RandomAccessFile? handle;
    try {
      await lockFile.parent.create(recursive: true);
      handle = await lockFile.open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      _lockHandle = handle;
      return true;
    } on FileSystemException {
      await handle?.close();
      return false;
    }
  }

  static Directory _applicationSupportDirectory() {
    final environment = Platform.environment;
    final userHome = environment['HOME'];
    if (Platform.isWindows) {
      final baseDirectory =
          environment['LOCALAPPDATA'] ?? environment['USERPROFILE'];
      if (baseDirectory != null) {
        return Directory('$baseDirectory\\AI Limit Status');
      }
    }
    if (Platform.isMacOS && userHome != null) {
      return Directory('$userHome/Library/Application Support/AI Limit Status');
    }
    final dataHome = environment['XDG_DATA_HOME'];
    if (dataHome != null) {
      return Directory('$dataHome/ai_limit_status');
    }
    if (userHome != null) {
      return Directory('$userHome/.local/share/ai_limit_status');
    }
    return Directory('${Directory.systemTemp.path}/ai_limit_status');
  }
}
