import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:ai_limit_status/features/usage/data/datasources/provider_executable_locator.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class ClaudeUsageReader {
  ClaudeUsageReader(this._executableLocator);

  static const _requestTimeout = Duration(seconds: 8);
  static const _versionTimeout = Duration(seconds: 3);
  static const _rateLimitCooldown = Duration(minutes: 5);
  static const _minimumFetchInterval = Duration(minutes: 2);
  static const _fallbackUserAgent = 'claude-code/2.1.0';

  /// The keychain access prompt needs time for the user to respond.
  static const _keychainPromptTimeout = Duration(seconds: 45);

  /// After the user denies keychain access, wait before asking again so the
  /// prompt does not reappear on every two-minute refresh.
  static const _keychainDenialCooldown = Duration(minutes: 30);

  static const _credentialsCacheTtl = Duration(minutes: 10);

  static const _keychainChannel = MethodChannel('com.ailimitstatus/keychain');
  static const _keychainService = 'Claude Code-credentials';

  final ProviderExecutableLocator _executableLocator;
  DateTime? _rateLimitedUntil;
  String? _cachedUserAgent;
  ProviderUsageModel? _lastSuccessfulUsage;
  DateTime? _keychainDeniedAt;
  _ClaudeCredentials? _cachedCredentials;
  DateTime? _credentialsReadAt;

  Future<ProviderUsageModel> read() async {
    final cachedUsage = _lastSuccessfulUsage;
    if (cachedUsage != null &&
        DateTime.now().difference(cachedUsage.fetchedAt) <
            _minimumFetchInterval) {
      return cachedUsage;
    }

    final credentials = await _readCredentialsCached();
    if (credentials == null) {
      // Stored credentials count as an install even without a resolvable
      // CLI binary; only report "not installed" when both are absent.
      final executable = await _executableLocator.find(UsageProvider.claude);
      throw UsageReadException(
        executable == null
            ? UsageConnectionIssue.cliNotFound
            : UsageConnectionIssue.notSignedIn,
      );
    }
    if (credentials.isExpired) {
      // Re-read the store on the next poll; the CLI may have refreshed the
      // token in the meantime.
      _cachedCredentials = null;
      // The Claude CLI refreshes its own token the next time it runs. A
      // stored refresh token means the user is still signed in, so treat
      // this as a temporary outage (keeping the cached snapshot) instead of
      // asking for a fresh sign-in.
      throw UsageReadException(
        credentials.hasRefreshToken
            ? UsageConnectionIssue.unavailable
            : UsageConnectionIssue.notSignedIn,
      );
    }

    final payload = await _fetchUsage(credentials);
    final limits = _parseLimits(payload);
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

  Future<_ClaudeCredentials?> _readCredentialsCached() async {
    final cached = _cachedCredentials;
    final readAt = _credentialsReadAt;
    if (cached != null &&
        readAt != null &&
        !cached.isExpired &&
        DateTime.now().difference(readAt) < _credentialsCacheTtl) {
      return cached;
    }
    final credentials = await _readCredentials();
    _cachedCredentials = credentials;
    _credentialsReadAt = DateTime.now();
    return credentials;
  }

  Future<_ClaudeCredentials?> _readCredentials() async {
    final overrideConfigDir = Platform.environment['CLAUDE_CONFIG_DIR'];
    final hasOverride =
        overrideConfigDir != null && overrideConfigDir.isNotEmpty;

    // With a custom CLAUDE_CONFIG_DIR the credentials file is authoritative.
    // Otherwise, on macOS the CLI stores credentials in the keychain first
    // and keeps the file as a fallback; on Windows the file is the only
    // store. Reading both sides mirrors CodexBar.
    final sources = <Future<String?> Function()>[
      if (hasOverride) _readCredentialsFile,
      if (Platform.isMacOS) _readMacKeychainCredentials,
      if (!hasOverride) _readCredentialsFile,
    ];
    for (final source in sources) {
      final credentials = _parseCredentials(await source());
      if (credentials != null) {
        return credentials;
      }
    }
    return null;
  }

  /// Reads the Claude CLI's keychain item the way CodexBar does: through
  /// Security.framework under this app's own identity, so macOS shows its
  /// access prompt once and "Always Allow" keeps every later read silent.
  /// The `security` command-line tool remains a fallback for older builds
  /// whose runner does not implement the channel yet.
  Future<String?> _readMacKeychainCredentials() async {
    final deniedAt = _keychainDeniedAt;
    if (deniedAt != null &&
        DateTime.now().difference(deniedAt) < _keychainDenialCooldown) {
      return null;
    }
    try {
      final response = await _keychainChannel
          .invokeMapMethod<String, Object?>('readGenericPassword', {
            'service': _keychainService,
          })
          .timeout(_keychainPromptTimeout);
      final value = response?['value'];
      if (value is String && value.isNotEmpty) {
        _keychainDeniedAt = null;
        return value;
      }
      final status = response?['status'];
      // -128: the user canceled the prompt; -25293: authorization failed.
      // Back off so the prompt does not reappear on every refresh.
      if (status == -128 || status == -25293) {
        _keychainDeniedAt = DateTime.now();
      }
      // Any explicit status (including -25300 item-not-found) is a
      // conclusive answer from the same keychain the CLI tool would query,
      // so do not run the CLI and risk a second prompt.
      return null;
    } on Object {
      // The channel is unavailable (old runner build) or timed out; try the
      // command-line fallback once.
      return _readKeychainCredentials();
    }
  }

  Future<String?> _readKeychainCredentials() async {
    Process process;
    try {
      process = await Process.start('/usr/bin/security', const [
        'find-generic-password',
        '-s',
        'Claude Code-credentials',
        '-w',
      ]);
    } on Object {
      return null;
    }
    try {
      final outputFuture = process.stdout.transform(utf8.decoder).join();
      unawaited(process.stderr.drain<void>());
      final exitCode = await process.exitCode.timeout(
        _requestTimeout,
        onTimeout: () {
          // Killing on timeout also dismisses a still-open keychain prompt
          // instead of stacking a new one on every refresh.
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await outputFuture.timeout(_requestTimeout);
      if (exitCode != 0) {
        return null;
      }
      return output;
    } on Object {
      // Keychain access can be denied or time out; fall back to the
      // credentials file.
      process.kill(ProcessSignal.sigkill);
      return null;
    }
  }

  Future<String?> _readCredentialsFile() async {
    try {
      final configDirectory =
          Platform.environment['CLAUDE_CONFIG_DIR'] ??
          (Platform.isWindows
              ? '${Platform.environment['USERPROFILE']}\\.claude'
              : '${Platform.environment['HOME']}/.claude');
      final separator = Platform.isWindows ? r'\' : '/';
      final credentialsFile = File(
        '$configDirectory$separator.credentials.json',
      );
      if (!await credentialsFile.exists()) {
        return null;
      }
      return await credentialsFile.readAsString();
    } on Object {
      return null;
    }
  }

  _ClaudeCredentials? _parseCredentials(String? credentialsJson) {
    final credentials = _decodeMap(credentialsJson);
    final oauth = credentials?['claudeAiOauth'];
    if (oauth is! Map<String, dynamic>) {
      return null;
    }
    final accessToken = oauth['accessToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      return null;
    }
    final refreshToken = oauth['refreshToken'];
    final expiresAtMs = (oauth['expiresAt'] as num?)?.toInt();
    return _ClaudeCredentials(
      accessToken: accessToken,
      expiresAt: expiresAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      hasRefreshToken: refreshToken is String && refreshToken.isNotEmpty,
    );
  }

  Future<Map<String, dynamic>> _fetchUsage(
    _ClaudeCredentials credentials,
  ) async {
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
        ..set(
          HttpHeaders.authorizationHeader,
          'Bearer ${credentials.accessToken}',
        )
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, await _claudeCodeUserAgent())
        ..set('anthropic-beta', 'oauth-2025-04-20');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        // Re-read the store on the next poll instead of retrying a token
        // the server has already rejected.
        _cachedCredentials = null;
        // A rejected token alongside a refresh token usually means the
        // access token lapsed between the local expiry check and this call;
        // the CLI will repair it, so keep the cached snapshot meanwhile.
        throw UsageReadException(
          credentials.hasRefreshToken
              ? UsageConnectionIssue.unavailable
              : UsageConnectionIssue.notSignedIn,
        );
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

      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_requestTimeout);
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
          unawaited(terminateProviderProcess(process));
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
    } on Object {
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
    return _parseRawLimit(rawLimit, type);
  }

  List<UsageLimit> _parseLimits(Map<String, dynamic> payload) {
    final parsed = <UsageLimitType, UsageLimit>{};

    void add(UsageLimit? limit) {
      if (limit != null) {
        parsed[limit.type] = limit;
      }
    }

    add(_parseLimit(payload, 'five_hour', UsageLimitType.session));
    add(_parseLimit(payload, 'seven_day', UsageLimitType.weekly));
    add(_parseLimit(payload, 'seven_day_opus', UsageLimitType.opusWeekly));
    add(_parseLimit(payload, 'seven_day_sonnet', UsageLimitType.sonnetWeekly));
    add(
      _parseLimit(payload, 'seven_day_fable', UsageLimitType.fableWeekly) ??
          _parseLimit(
            payload,
            'seven_day_overage_included',
            UsageLimitType.fableWeekly,
          ),
    );

    final rawLimits = payload['limits'];
    if (rawLimits is List) {
      for (final rawLimit in rawLimits) {
        if (rawLimit is! Map<String, dynamic>) {
          continue;
        }
        final type = _genericLimitType(rawLimit);
        if (type != null) {
          add(_parseRawLimit(rawLimit, type));
        }
      }
    }

    return const [
      UsageLimitType.session,
      UsageLimitType.weekly,
      UsageLimitType.fableWeekly,
      UsageLimitType.opusWeekly,
      UsageLimitType.sonnetWeekly,
    ].map((type) => parsed[type]).nonNulls.toList();
  }

  UsageLimit? _parseRawLimit(
    Map<String, dynamic> rawLimit,
    UsageLimitType type,
  ) {
    final utilization =
        (rawLimit['utilization'] as num?)?.toDouble() ??
        (rawLimit['percent'] as num?)?.toDouble();
    if (utilization == null) {
      return null;
    }

    return UsageLimit(
      type: type,
      remainingPercent: (100 - utilization).round().clamp(0, 100),
      resetsAt: _parseResetTime(rawLimit['resets_at']),
    );
  }

  UsageLimitType? _genericLimitType(Map<String, dynamic> rawLimit) {
    final kind = rawLimit['kind']?.toString().toLowerCase();
    if (kind == 'session' || kind == 'five_hour') {
      return UsageLimitType.session;
    }
    if (kind == 'weekly_all' || kind == 'seven_day') {
      return UsageLimitType.weekly;
    }

    final scope = rawLimit['scope'];
    final model = scope is Map<String, dynamic> ? scope['model'] : null;
    final modelName = model is Map<String, dynamic>
        ? (model['display_name'] ?? model['id'])?.toString().toLowerCase()
        : null;
    final isScopedWeekly =
        kind == 'weekly_scoped' ||
        (rawLimit['group']?.toString().toLowerCase() == 'weekly' &&
            modelName != null);
    if (!isScopedWeekly || modelName == null) {
      return null;
    }
    if (modelName.contains('fable')) {
      return UsageLimitType.fableWeekly;
    }
    if (modelName.contains('opus')) {
      return UsageLimitType.opusWeekly;
    }
    if (modelName.contains('sonnet')) {
      return UsageLimitType.sonnetWeekly;
    }
    return null;
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

class _ClaudeCredentials {
  const _ClaudeCredentials({
    required this.accessToken,
    this.expiresAt,
    this.hasRefreshToken = false,
  });

  final String accessToken;
  final DateTime? expiresAt;
  final bool hasRefreshToken;

  bool get isExpired {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !DateTime.now().isBefore(expiresAt);
  }
}
