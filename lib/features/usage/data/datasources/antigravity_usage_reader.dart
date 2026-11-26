import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/provider_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

/// Reads Antigravity quota from the language server that the Antigravity app
/// (or Antigravity IDE) runs on this machine while it is open.
///
/// The server listens on a random loopback port and requires the CSRF token
/// it was started with, so both are taken from its process: the token from
/// its command line (Antigravity up to 2.32) or its environment (2.35 and
/// later), the port from its listening sockets. Nothing is read when the app
/// is closed. The approach follows CodexBar's local probe
/// (https://github.com/steipete/CodexBar, MIT).
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
    if (servers.isEmpty) {
      throw UsageReadException(
        await isInstalled()
            ? UsageConnectionIssue.appNotRunning
            : UsageConnectionIssue.cliNotFound,
      );
    }
    for (final server in servers) {
      for (final port in await _listeningPorts(server.pid)) {
        final limits = await _readLimits(port, server.csrfToken);
        if (limits != null && limits.isNotEmpty) {
          return ProviderUsageModel(
            provider: UsageProvider.antigravity,
            limits: limits,
            isConnected: true,
            isInstalled: true,
            fetchedAt: DateTime.now(),
          );
        }
      }
    }
    // The app is open but no server answered: still starting, or signed out.
    throw const UsageReadException(UsageConnectionIssue.unavailable);
  }

  /// Whether an Antigravity app exists on this machine, so a closed app can
  /// be told apart from a provider the user does not have.
  static Future<bool> isInstalled() async {
    final environment = Platform.environment;
    final candidates = <String>[
      if (Platform.isMacOS)
        for (final root in [
          '/Applications',
          if (environment['HOME'] case final home?) '$home/Applications',
        ]) ...['$root/Antigravity.app', '$root/Antigravity IDE.app'],
      if (Platform.isWindows)
        if (environment['LOCALAPPDATA'] case final local?) ...[
          '$local\\Programs\\Antigravity',
          '$local\\Programs\\Antigravity IDE',
        ],
    ];
    for (final candidate in candidates) {
      if (await Directory(candidate).exists()) {
        return true;
      }
    }
    return false;
  }

  /// Running Antigravity language servers, the standalone app before the IDE.
  Future<List<({int pid, String csrfToken})>> _languageServers() async {
    final lines = Platform.isWindows
        ? await _run('powershell.exe', const [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "Get-CimInstance Win32_Process -Filter \"Name LIKE 'language_server%'\" "
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
      if (!lower.contains('language_server') ||
          !lower.contains('antigravity')) {
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
  /// bucket.
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
        final id = bucket['bucketId'];
        final remaining = bucket['remaining'];
        final fraction =
            bucket['remainingFraction'] ??
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
        final resetTime = bucket['resetTime'];
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
            groupLabel: group['displayName'] as String?,
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
