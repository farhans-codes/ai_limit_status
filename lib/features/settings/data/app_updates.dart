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
