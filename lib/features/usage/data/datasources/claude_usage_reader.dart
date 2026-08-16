import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/provider_executable_locator.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class ClaudeUsageReader {
  ClaudeUsageReader(this._executableLocator);

  static const _requestTimeout = Duration(seconds: 8);
  static const _versionTimeout = Duration(seconds: 3);
  static const _rateLimitCooldown = Duration(minutes: 5);
  static const _minimumFetchInterval = Duration(minutes: 5);
  static const _fallbackUserAgent = 'claude-code/2.1.0';

  final ProviderExecutableLocator _executableLocator;
  DateTime? _rateLimitedUntil;
  String? _cachedUserAgent;
  ProviderUsageModel? _lastSuccessfulUsage;

  Future<ProviderUsageModel> read() async {
    final executable = await _executableLocator.find(UsageProvider.claude);
    if (executable == null) {
      throw const UsageReadException(UsageConnectionIssue.cliNotFound);
    }

    final cachedUsage = _lastSuccessfulUsage;
    if (cachedUsage != null &&
        DateTime.now().difference(cachedUsage.fetchedAt) <
            _minimumFetchInterval) {
      return cachedUsage;
    }

    final accessToken = await _readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const UsageReadException(UsageConnectionIssue.notSignedIn);
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

    return _lastSuccessfulUsage = ProviderUsageModel(
      provider: UsageProvider.claude,
      limits: limits,
      isConnected: true,
      isInstalled: true,
      fetchedAt: DateTime.now(),
    );
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
    final now = DateTime.now();
    final rateLimitedUntil = _rateLimitedUntil;
    if (rateLimitedUntil != null && now.isBefore(rateLimitedUntil)) {
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    }

    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .getUrl(Uri.https('api.anthropic.com', '/api/oauth/usage'))
          .timeout(_requestTimeout);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, await _claudeCodeUserAgent())
        ..set('anthropic-beta', 'oauth-2025-04-20');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        throw const UsageReadException(UsageConnectionIssue.notSignedIn);
      }
      if (response.statusCode == HttpStatus.tooManyRequests) {
        _rateLimitedUntil =
            _parseRetryAfter(response.headers.value('retry-after')) ??
            now.add(_rateLimitCooldown);
        await response.drain<void>();
        throw const UsageReadException(UsageConnectionIssue.unavailable);
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
      _rateLimitedUntil = null;
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _claudeCodeUserAgent() async {
    final cachedUserAgent = _cachedUserAgent;
    if (cachedUserAgent != null) {
      return cachedUserAgent;
    }

    try {
      final executable = await _executableLocator.find(UsageProvider.claude);
      if (executable == null) {
        return _cachedUserAgent = _fallbackUserAgent;
      }
      final process = await executable.start(const ['--version']);
      final outputFuture = process.stdout.transform(utf8.decoder).join();
      unawaited(process.stderr.drain<void>());
      final exitCode = await process.exitCode.timeout(
        _versionTimeout,
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      final output = await outputFuture.timeout(_versionTimeout);
      if (exitCode == 0) {
        final version = RegExp(
          r'\b\d+\.\d+\.\d+\b',
        ).firstMatch(output)?.group(0);
        if (version != null) {
          return _cachedUserAgent = 'claude-code/$version';
        }
      }
    } on Object {
      return _cachedUserAgent = _fallbackUserAgent;
    }

    return _cachedUserAgent = _fallbackUserAgent;
  }

  DateTime? _parseRetryAfter(String? value) {
    if (value == null) {
      return null;
    }
    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0) {
      return DateTime.now().add(Duration(seconds: seconds));
    }
    try {
      return HttpDate.parse(value).toLocal();
    } on FormatException {
      return null;
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
