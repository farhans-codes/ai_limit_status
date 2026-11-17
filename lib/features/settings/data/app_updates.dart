import 'dart:convert';
import 'dart:io';

enum AppUpdatePlatform {
  macOS('AI-Limit-Status-macOS.dmg'),
  windows('AI-Limit-Status-Windows-x64-Setup.exe');

  const AppUpdatePlatform(this.assetName);

  final String assetName;

  static AppUpdatePlatform? get current => switch (Platform.operatingSystem) {
    'macos' => macOS,
    'windows' => windows,
    _ => null,
  };
}

typedef AppUpdate = ({String version, Uri? downloadUrl});

const _repository = 'farhans-codes/ai_limit_status';
const _timeout = Duration(seconds: 10);
final _stableVersion = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

Future<AppUpdate?> checkForAppUpdate(
  String installedVersion,
  AppUpdatePlatform platform,
) async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    final request = await client
        .getUrl(
          Uri.https('api.github.com', '/repos/$_repository/releases/latest'),
        )
        .timeout(_timeout);
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    final response = await request.close().timeout(_timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'GitHub release lookup returned ${response.statusCode}',
      );
    }
    final release = jsonDecode(
      await response.transform(utf8.decoder).join().timeout(_timeout),
    );
    if (release is! Map<String, dynamic> ||
        release['draft'] != false ||
        release['prerelease'] != false) {
      throw const FormatException('Expected a published stable release');
    }
    final tag = release['tag_name'];
    if (tag is! String || !tag.startsWith('v')) {
      throw const FormatException('Invalid release tag');
    }
    final version = tag.substring(1);
    if (!_isNewer(version, installedVersion)) {
      return null;
    }

    final assets = release['assets'];
    if (assets is! List) {
      throw const FormatException('Invalid release assets');
    }
    final url = Uri.https(
      'github.com',
      '/$_repository/releases/download/$tag/${platform.assetName}',
    );
    final hasInstaller = assets.any(
      (asset) =>
          asset is Map<String, dynamic> &&
          asset['name'] == platform.assetName &&
          asset['state'] == 'uploaded' &&
          asset['browser_download_url'] == url.toString(),
    );
    return (version: version, downloadUrl: hasInstaller ? url : null);
  } finally {
    client.close(force: true);
  }
}

const _downloadTimeout = Duration(minutes: 5);

/// Downloads the installer, installs it, and quits so the new version can
/// replace this one; the update relaunches the app itself. Throws, leaving the
/// running app untouched, when any step before quitting fails.
Future<Never> installAppUpdate(Uri url, AppUpdatePlatform platform) async {
  // Fail before downloading when the app cannot be replaced in place, for
  // example when it runs from the DMG or from a folder the user can't write.
  final macBundle = platform == AppUpdatePlatform.macOS
      ? await _writableMacBundle()
      : null;
  final work = await Directory.systemTemp.createTemp('ai-limit-status-update-');
  final installer = File('${work.path}/${platform.assetName}');
  await _download(url, installer);
  switch (platform) {
    case AppUpdatePlatform.macOS:
      await _installMac(installer, work, macBundle!);
    case AppUpdatePlatform.windows:
      // Inno Setup closes and replaces this app, then relaunches it.
      await Process.start(installer.path, const [
        '/SILENT',
        '/SP-',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
  }
  exit(0);
}

Future<void> _download(Uri url, File target) async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    final request = await client.getUrl(url).timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Update download returned ${response.statusCode}');
    }
    await response.pipe(target.openWrite()).timeout(_downloadTimeout);
  } finally {
    client.close(force: true);
  }
}

Future<String> _writableMacBundle() async {
  final bundle = File(Platform.resolvedExecutable).parent.parent.parent.path;
  if (!bundle.endsWith('.app')) {
    throw FileSystemException('Not running from an app bundle', bundle);
  }
  final probe = File('${File(bundle).parent.path}/.ai-limit-status-update');
  await probe.create();
  await probe.delete();
  return bundle;
}

Future<void> _installMac(File dmg, Directory work, String bundle) async {
  final mount = '${work.path}/mount';
  final staged = '${work.path}/AI Limit Status.app';
  await _run('/usr/bin/hdiutil', [
    'attach',
    dmg.path,
    '-nobrowse',
    '-readonly',
    '-noautoopen',
    '-mountpoint',
    mount,
  ]);
  try {
    final app = Directory(mount).listSync().firstWhere(
      (entry) => entry is Directory && entry.path.endsWith('.app'),
    );
    await _run('/usr/bin/ditto', [app.path, staged]);
  } finally {
    await Process.run('/usr/bin/hdiutil', ['detach', mount, '-quiet']);
  }
  // Refuse a damaged or tampered download before touching the installed app.
  await _run('/usr/bin/codesign', ['--verify', '--deep', '--strict', staged]);

  // Swap the bundles once this process has exited, keeping the old copy until
  // the new one is in place, then relaunch whichever copy ended up installed.
  const swap = r'''
while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
old="$2.previous"
rm -rf "$old"
if mv "$2" "$old"; then
  if mv "$3" "$2"; then rm -rf "$old"; else mv "$old" "$2"; fi
fi
rm -rf "$4"
open "$2"
''';
  await Process.start('/bin/sh', [
    '-c',
    swap,
    'sh',
    '$pid',
    bundle,
    staged,
    work.path,
  ], mode: ProcessStartMode.detached);
}

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stderr}',
      result.exitCode,
    );
  }
}

bool _isNewer(String latest, String installed) {
  final release = _stableVersion.firstMatch(latest);
  final current = _stableVersion.firstMatch(installed);
  if (release == null || current == null) {
    throw const FormatException('Expected a three-part stable version');
  }
  for (var part = 1; part <= 3; part++) {
    final difference = int.parse(
      release[part]!,
    ).compareTo(int.parse(current[part]!));
    if (difference != 0) {
      return difference > 0;
    }
  }
  return false;
}
