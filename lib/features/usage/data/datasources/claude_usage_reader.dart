import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class ClaudeUsageReader {
  const ClaudeUsageReader();

  static const _requestTimeout = Duration(seconds: 8);

  Future<ProviderUsageModel> read() async {
    final accessToken = await _readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      final executable = await _findExecutable();
      throw UsageReadException(
        executable == null
            ? UsageConnectionIssue.cliNotFound
            : UsageConnectionIssue.notSignedIn,
      );
    }

    final payload = await _fetchUsage(accessToken);
    final limits = <UsageLimit?>[
      _parseLimit(payload, 'five_hour', UsageLimitType.session),
      _parseLimit(payload, 'seven_day', UsageLimitType.weekly),
      _parseLimit(payload, 'seven_day_opus', UsageLimitType.opusWeekly),
      _parseLimit(payload, 'seven_day_sonnet', UsageLimitType.sonnetWeekly),
    ].nonNulls.toList();
    if (limits.isEmpty) {
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    }

    return ProviderUsageModel(
      provider: UsageProvider.claude,
      limits: limits,
      isConnected: true,
      fetchedAt: DateTime.now(),
    );
  }

  Future<String?> _findExecutable() async {
    final home = Platform.environment['HOME'];
    final candidates = <String>[
      if (Platform.isMacOS) '/opt/homebrew/bin/claude',
      if (Platform.isMacOS) '/usr/local/bin/claude',
      if (Platform.isMacOS && home != null) '$home/.local/bin/claude',
      if (Platform.isWindows) 'claude.exe' else 'claude',
    ];

    for (final candidate in candidates) {
      try {
        final result = await Process.run(candidate, const [
          '--version',
        ]).timeout(_requestTimeout);
        if (result.exitCode == 0) {
          return candidate;
        }
      } on Object {
        continue;
      }
    }

    return null;
  }

  Future<String?> _readAccessToken() async {
    String? credentialsJson;
    if (Platform.isMacOS) {
      final result = await Process.run('/usr/bin/security', const [
        'find-generic-password',
        '-s',
        'Claude Code-credentials',
        '-w',
      ]).timeout(_requestTimeout);
      if (result.exitCode == 0) {
        credentialsJson = result.stdout.toString();
      }
    } else {
      final configDirectory =
          Platform.environment['CLAUDE_CONFIG_DIR'] ??
          (Platform.isWindows
              ? '${Platform.environment['USERPROFILE']}\\.claude'
              : '${Platform.environment['HOME']}/.claude');
      final credentialsFile = File('$configDirectory/.credentials.json');
      if (await credentialsFile.exists()) {
        credentialsJson = await credentialsFile.readAsString();
      }
    }

    final credentials = _decodeMap(credentialsJson);
    final oauth = credentials?['claudeAiOauth'];
    if (oauth is! Map<String, dynamic>) {
      return null;
    }
    return oauth['accessToken'] as String?;
  }

  Future<Map<String, dynamic>> _fetchUsage(String accessToken) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .getUrl(Uri.https('api.anthropic.com', '/api/oauth/usage'))
          .timeout(_requestTimeout);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, 'limit-status/0.1.0')
        ..set('anthropic-beta', 'oauth-2025-04-20');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        throw const UsageReadException(UsageConnectionIssue.notSignedIn);
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const UsageReadException(UsageConnectionIssue.unavailable);
      }

      final body = await utf8.decoder.bind(response).join();
      final payload = _decodeMap(body);
      if (payload == null) {
        throw const UsageReadException(UsageConnectionIssue.unavailable);
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  UsageLimit? _parseLimit(
    Map<String, dynamic> payload,
    String key,
    UsageLimitType type,
  ) {
    final rawLimit = payload[key];
    if (rawLimit is! Map<String, dynamic>) {
      return null;
    }
    final utilization = (rawLimit['utilization'] as num?)?.toDouble();
    if (utilization == null) {
      return null;
    }

    return UsageLimit(
      type: type,
      remainingPercent: (100 - utilization).round().clamp(0, 100),
      resetsAt: _parseResetTime(rawLimit['resets_at']),
    );
  }

  DateTime? _parseResetTime(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * Duration.millisecondsPerSecond,
      );
    }
    return null;
  }

  Map<String, dynamic>? _decodeMap(Object? value) {
    if (value == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(value.toString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
