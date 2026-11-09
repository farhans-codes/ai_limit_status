import 'dart:io';

Future<bool> openExternalUrl(Uri url) async {
  final (executable, arguments) = switch (Platform.operatingSystem) {
    'windows' => ('cmd.exe', ['/d', '/c', 'start', '', url.toString()]),
    'macos' => ('/usr/bin/open', [url.toString()]),
    _ => ('xdg-open', [url.toString()]),
  };
  try {
    final result = await Process.run(executable, arguments);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
