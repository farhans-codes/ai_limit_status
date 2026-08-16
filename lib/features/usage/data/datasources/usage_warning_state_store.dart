import 'dart:collection';
import 'dart:convert';
import 'dart:io';

class UsageWarningStateStore {
  const UsageWarningStateStore();

  static const _maximumIdentifiers = 200;

  Future<LinkedHashSet<String>> readIdentifiers() async {
    final file = _stateFile();
    try {
      if (!await file.exists()) {
        return LinkedHashSet<String>();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return LinkedHashSet<String>();
      }
      return LinkedHashSet<String>.from(decoded.whereType<String>());
    } on Object {
      return LinkedHashSet<String>();
    }
  }

  Future<void> writeIdentifiers(LinkedHashSet<String> identifiers) async {
    while (identifiers.length > _maximumIdentifiers) {
      identifiers.remove(identifiers.first);
    }
    final file = _stateFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(identifiers.toList()));
  }

  File _stateFile() {
    final environment = Platform.environment;
    if (Platform.isWindows) {
      final base = environment['LOCALAPPDATA'] ?? environment['USERPROFILE'];
      return File('$base\\AI Limit Status\\warning_state.json');
    }
    final home = environment['HOME'];
    if (Platform.isMacOS) {
      return File(
        '$home/Library/Application Support/AI Limit Status/warning_state.json',
      );
    }
    final dataHome = environment['XDG_DATA_HOME'] ?? '$home/.local/share';
    return File('$dataHome/ai_limit_status/warning_state.json');
  }
}
