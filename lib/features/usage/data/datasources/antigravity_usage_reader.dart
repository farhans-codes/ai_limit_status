import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/antigravity_cli_usage.dart';
import 'package:ai_limit_status/features/usage/data/datasources/provider_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

/// Reads Antigravity quota from the local server that the Antigravity app or
/// Antigravity IDE runs on this machine while it is open. The app runs a
/// `language_server`; the IDE runs the `agy` command-line tool as a hub. Both
/// answer the same quota request.
///
/// The server listens on a random loopback port and requires the CSRF token
/// it was started with, so both are taken from its process: the token from
/// its command line (Antigravity up to 2.32) or its environment (2.35 and
/// later), the port from its listening sockets. Nothing is read when the app
/// is closed.
///
/// Windows cannot read another process's environment from here, so newer
/// Antigravity versions are only readable on macOS for now.
class AntigravityUsageReader implements ProviderUsageReader {
  const AntigravityUsageReader();

  static const _commandTimeout = Duration(seconds: 5);
  static const _requestTimeout = Duration(seconds: 4);
  static const _quotaPath =
      '/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary';
  static const _requestBody =
      '{"metadata":{"ideName":"antigravity","extensionName":"antigravity",'
      '"locale":"en","ideVersion":"unknown"}}';

  @override
  Future<ProviderUsageModel> read() async {
    final servers = await _languageServers();
    for (final server in servers) {
      for (final port in await _listeningPorts(server.pid)) {
        final limits = await _readLimits(port, server.csrfToken);
        if (limits != null && limits.isNotEmpty) {
          return _connected(limits);
        }
      }
    }
    // Nothing is open, or nothing answered: ask the command-line tool, which
    // needs neither the app nor the IDE.
    final cliLimits = await AntigravityCliUsage.read();
    if (cliLimits != null) {
      return _connected(cliLimits);
    }
    if (servers.isNotEmpty) {
      // The app is open but did not answer: still starting, or signed out.
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    }
    throw UsageReadException(
      await isInstalled()
          ? UsageConnectionIssue.appNotRunning
          : UsageConnectionIssue.cliNotFound,
    );
  }

  static ProviderUsageModel _connected(List<UsageLimit> limits) {
    return ProviderUsageModel(
      provider: UsageProvider.antigravity,
      limits: limits,
      isConnected: true,
      isInstalled: true,
      fetchedAt: DateTime.now(),
    );
  }

  /// Whether Antigravity is on this machine, so a closed app can be told
  /// apart from a provider the user does not have.
  ///
  /// People install it wherever they like, so the app's location is not
  /// relied on: the folders Antigravity keeps in the user's home are the same
  /// wherever the app itself lives, and macOS can find the app by its
  /// identifier.
  static Future<bool> isInstalled() async {
    final environment = Platform.environment;
    final home = environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    final candidates = <String>[
      if (home != null) ...[
        '$home/.gemini/antigravity',
        '$home/.gemini/antigravity-ide',
        '$home/.antigravity',
        '$home/.antigravity-ide',
      ],
      if (Platform.isMacOS) ...[
        for (final root in [
          '/Applications',
          if (home != null) '$home/Applications',
        ]) ...['$root/Antigravity.app', '$root/Antigravity IDE.app'],
        if (home != null) ...[
          '$home/Library/Application Support/Antigravity',
          '$home/Library/Application Support/Antigravity IDE',
        ],
      ],
      if (Platform.isWindows) ...[
        if (environment['LOCALAPPDATA'] case final local?) ...[
          '$local\\Programs\\Antigravity',
          '$local\\Programs\\Antigravity IDE',
        ],
        if (environment['APPDATA'] case final roaming?) ...[
          '$roaming\\Antigravity',
          '$roaming\\Antigravity IDE',
        ],
      ],
    ];
    for (final candidate in candidates) {
      if (await Directory(candidate).exists()) {
        return true;
      }
    }
    return Platform.isMacOS && await _spotlightFindsApp();
  }

  /// Asks Spotlight for the app by bundle identifier, which finds it in any
  /// folder or on another drive.
  static Future<bool> _spotlightFindsApp() async {
    try {
      final result = await Process.run('/usr/bin/mdfind', const [
        "kMDItemCFBundleIdentifier == 'com.google.antigravity*'",
      ]).timeout(_commandTimeout);
      return result.stdout.toString().trim().isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Matches the `agy` executable itself, not a path that merely contains it.
  static final _agyExecutable = RegExp(r'(^|[/\\])agy(\.exe)?(\s|$)');

  /// Running Antigravity servers, the standalone app before the IDE.
  Future<List<({int pid, String csrfToken})>> _languageServers() async {
    final lines = Platform.isWindows
        ? await _run('powershell.exe', const [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "Get-CimInstance Win32_Process -Filter \"Name LIKE 'language_server%' OR Name = 'agy.exe'\" "
                "| ForEach-Object { \"\$(\$_.ProcessId) \$(\$_.CommandLine)\" }",
          ])
        : await _run('/bin/ps', const ['-axww', '-o', 'pid=,command=']);
    final servers = <({int pid, String csrfToken, bool isIde})>[];
    for (final line in lines) {
      final match = RegExp(r'^\s*(\d+)\s+(.*)$').firstMatch(line);
      if (match == null) {
        continue;
      }
      final command = match[2]!;
      final lower = command.toLowerCase();
      final isAgy = _agyExecutable.hasMatch(lower);
      final isLanguageServer =
          lower.contains('language_server') && lower.contains('antigravity');
      if (!isAgy && !isLanguageServer) {
        continue;
      }
      final pid = int.parse(match[1]!);
      final token =
          RegExp(r'--csrf_token[= ](\S+)').firstMatch(command)?[1] ??
          await _environmentToken(pid);
      if (token == null) {
        continue;
      }
      servers.add((
        pid: pid,
        csrfToken: token,
        isIde:
            isAgy ||
            lower.contains('antigravity-ide') ||
            lower.contains('antigravity ide'),
      ));
    }
    return [
      for (final ide in [false, true])
        for (final server in servers)
          if (server.isIde == ide)
            (pid: server.pid, csrfToken: server.csrfToken),
    ];
  }

  /// Newer versions pass the token in the server's environment instead of
  /// its arguments. Only this one process's environment is read.
  Future<String?> _environmentToken(int pid) async {
    if (Platform.isWindows) {
      return null;
    }
    final lines = await _run('/bin/ps', [
      '-Eww',
      '-o',
      'command=',
      '-p',
      '$pid',
    ]);
    return RegExp(
      r'\bANTIGRAVITY_SERVER_CSRF_TOKEN=(\S+)',
    ).firstMatch(lines.join(' '))?[1];
  }

  Future<List<int>> _listeningPorts(int pid) async {
    final lines = Platform.isWindows
        ? await _run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Get-NetTCPConnection -State Listen -OwningProcess $pid '
                '| ForEach-Object { ":\$(\$_.LocalPort)" }',
          ])
        : await _run('/usr/sbin/lsof', [
            '-nP',
            '-iTCP',
            '-sTCP:LISTEN',
            '-a',
            '-p',
            '$pid',
          ]);
    return {
      for (final line in lines)
        if (RegExp(r':(\d+)(?:\s|$)').firstMatch(line)?[1] case final port?)
          int.parse(port),
    }.toList();
  }

  /// Returns `null` when [port] is not the quota server.
  Future<List<UsageLimit>?> _readLimits(int port, String csrfToken) async {
    final client = HttpClient()
      ..connectionTimeout = _requestTimeout
      // The language server uses a self-signed certificate. Accept it only
      // for this loopback port; every other connection keeps normal checks.
      ..badCertificateCallback = (_, host, certificatePort) =>
          host == '127.0.0.1' && certificatePort == port;
    try {
      final request = await client
          .postUrl(Uri.parse('https://127.0.0.1:$port$_quotaPath'))
          .timeout(_requestTimeout);
      request.headers
        ..set('X-Codeium-Csrf-Token', csrfToken)
        ..set('Connect-Protocol-Version', '1')
        ..contentType = ContentType.json;
      request.write(_requestBody);
      final response = await request.close().timeout(_requestTimeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }
      return parseQuotaSummary(jsonDecode(body));
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Maps a `RetrieveUserQuotaSummary` response to limits. Each group
  /// ("Gemini Models", "Claude and GPT models") has a weekly and a five-hour
  /// bucket. The command-line tool reports the same groups with snake_case
  /// names, so both spellings are read.
  static List<UsageLimit> parseQuotaSummary(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }
    final summary = decoded['response'] ?? decoded['summary'] ?? decoded;
    final groups = summary is Map<String, dynamic> ? summary['groups'] : null;
    if (groups is! List) {
      return const [];
    }
    final limits = <UsageLimit>[];
    for (final group in groups.whereType<Map<String, dynamic>>()) {
      final buckets = group['buckets'];
      if (buckets is! List) {
        continue;
      }
      for (final bucket in buckets.whereType<Map<String, dynamic>>()) {
        final id = bucket['bucketId'] ?? bucket['id'];
        final remaining = bucket['remaining'];
        final fraction =
            bucket['remainingFraction'] ??
            bucket['remaining_fraction'] ??
            (remaining is Map<String, dynamic>
                ? remaining['remainingFraction']
                : null);
        if (id is! String || fraction is! num || bucket['disabled'] == true) {
          continue;
        }
        final window = bucket['window'] ?? id;
        final type = switch (window) {
          '5h' => UsageLimitType.session,
          'weekly' => UsageLimitType.weekly,
          String() when id.endsWith('-5h') => UsageLimitType.session,
          String() when id.endsWith('-weekly') => UsageLimitType.weekly,
          _ => null,
        };
        if (type == null) {
          continue;
        }
        final resetTime = bucket['resetTime'] ?? bucket['reset_time'];
        limits.add(
          UsageLimit(
            type: type,
            remainingPercent: (fraction * 100).round().clamp(0, 100),
            // An untouched window has not started: its reported reset time
            // is just "now plus the window" and moves with every request.
            resetsAt: fraction >= 1 || resetTime is! String
                ? null
                : DateTime.tryParse(resetTime)?.toLocal(),
            groupId: id.replaceFirst(RegExp(r'-(5h|weekly)$'), ''),
            groupLabel: (group['displayName'] ?? group['name']) as String?,
          ),
        );
      }
    }
    return limits;
  }

  Future<List<String>> _run(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
      ).timeout(_commandTimeout);
      return const LineSplitter().convert(result.stdout.toString());
    } on Object {
      return const [];
    }
  }
}
