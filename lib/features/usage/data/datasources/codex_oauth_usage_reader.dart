import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/browser_session_reader.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

/// Why the OAuth path could not produce usage, so [CodexUsageReader] can
/// decide whether launching the Codex CLI as a fallback could still help.
enum CodexOAuthIssue {
  /// auth.json is missing or holds no OAuth tokens.
  credentialsNotFound,

  /// The stored tokens were rejected and could not be refreshed.
  unauthorized,

  /// A transient network, server, or decode problem. The CLI talks to the
  /// same backend, so spawning it as a fallback would not do better.
  unavailable,
}

class CodexOAuthReadException implements Exception {
  const CodexOAuthReadException(this.issue);

  final CodexOAuthIssue issue;
}

/// Reads Codex usage the way CodexBar's OAuth strategy does: parse the Codex
/// CLI's auth.json, refresh the token through the official endpoint shortly
/// before it expires, and query the ChatGPT backend usage API directly.
///
/// This avoids spawning the CLI in the common case, which sidesteps the
/// PATH-discovery and shell-quoting differences between macOS and Windows
/// that made the app-server probe unreliable.
class CodexOAuthUsageReader {
  CodexOAuthUsageReader();

  static const _requestTimeout = Duration(seconds: 15);
  static const _usageUrl = 'https://chatgpt.com/backend-api/wham/usage';
  static const _refreshUrl = 'https://auth.openai.com/oauth/token';

  /// Public client identifier used by the Codex CLI's own login flow.
  static const _oauthClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';

  /// Refresh slightly before the access token expires, like CodexBar.
  static const _refreshWindow = Duration(minutes: 5);

  /// Without an exp claim, rotate tokens once the stored refresh timestamp
  /// is older than this, matching the Codex CLI's own cadence.
  static const _staleRefreshAge = Duration(days: 8);

  static const _refreshFailureCooldown = Duration(minutes: 5);
  static const _webCookieCacheTtl = Duration(minutes: 30);

  DateTime? _lastRefreshFailureAt;
  Future<ProviderUsageModel>? _inFlightRead;
  String? _cachedWebCookieHeader;
  DateTime? _webCookieReadAt;

  /// Coalesces overlapping calls so a token refresh (and the auth.json
  /// rewrite it implies) can never race against itself within the app.
  Future<ProviderUsageModel> read() {
    return _inFlightRead ??= _read().whenComplete(() {
      _inFlightRead = null;
    });
  }

  Future<ProviderUsageModel> _read() async {
    var credentials = await _loadCredentials();
    credentials = await _maybeRefresh(credentials);

    var payload = await _fetchUsage(credentials);
    if (payload == null) {
      // The token was rejected outright; force one refresh and retry once.
      credentials = await _forceRefresh(credentials);
      payload = await _fetchUsage(credentials);
      if (payload == null) {
        throw const CodexOAuthReadException(CodexOAuthIssue.unauthorized);
      }
    }

    final limits = _parseLimits(payload);
    if (limits.isEmpty) {
      throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
    }

    return ProviderUsageModel(
      provider: UsageProvider.codex,
      limits: limits,
      isConnected: true,
      isInstalled: true,
      fetchedAt: DateTime.now(),
    );
  }

  Future<ProviderUsageModel> readFromWeb() async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
    }
    final cookieHeader = await _readWebCookieHeader();
    if (cookieHeader == null) {
      throw const CodexOAuthReadException(CodexOAuthIssue.credentialsNotFound);
    }

    final payload = await _fetchUsageRequest(
      (headers) => headers.set(HttpHeaders.cookieHeader, cookieHeader),
    );
    if (payload == null) {
      _cachedWebCookieHeader = null;
      _webCookieReadAt = null;
      throw const CodexOAuthReadException(CodexOAuthIssue.unauthorized);
    }

    final expectedAccountId = await _expectedAccountId();
    final actualAccountId =
        _string(payload['account_id']) ?? _string(payload['accountId']);
    if (expectedAccountId != null &&
        actualAccountId != null &&
        expectedAccountId != actualAccountId) {
      throw const CodexOAuthReadException(CodexOAuthIssue.unauthorized);
    }

    final limits = _parseLimits(payload);
    if (limits.isEmpty) {
      throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
    }
    return ProviderUsageModel(
      provider: UsageProvider.codex,
      limits: limits,
      isConnected: true,
      isInstalled: true,
      fetchedAt: DateTime.now(),
    );
  }

  Future<String?> _readWebCookieHeader() async {
    final cached = _cachedWebCookieHeader;
    final readAt = _webCookieReadAt;
    if (cached != null &&
        readAt != null &&
        DateTime.now().difference(readAt) < _webCookieCacheTtl) {
      return cached;
    }
    try {
      final value = await readChatGptBrowserCookieHeader();
      if (value == null || value.isEmpty) {
        return null;
      }
      _cachedWebCookieHeader = value;
      _webCookieReadAt = DateTime.now();
      return value;
    } on Object {
      return null;
    }
  }

  Future<String?> _expectedAccountId() async {
    try {
      return (await _loadCredentials()).accountId;
    } on CodexOAuthReadException {
      return null;
    }
  }

  File _authFile() {
    final environment = Platform.environment;
    final codexHome = environment['CODEX_HOME'];
    if (codexHome != null && codexHome.trim().isNotEmpty) {
      return File(_joinPath(codexHome.trim(), 'auth.json'));
    }
    final home = Platform.isWindows
        ? environment['USERPROFILE']
        : environment['HOME'];
    if (home == null || home.isEmpty) {
      throw const CodexOAuthReadException(CodexOAuthIssue.credentialsNotFound);
    }
    return File(_joinPath(_joinPath(home, '.codex'), 'auth.json'));
  }

  Future<_CodexCredentials> _loadCredentials() async {
    String raw;
    try {
      final file = _authFile();
      if (!await file.exists()) {
        throw const CodexOAuthReadException(
          CodexOAuthIssue.credentialsNotFound,
        );
      }
      raw = await file.readAsString();
    } on CodexOAuthReadException {
      rethrow;
    } on Object {
      throw const CodexOAuthReadException(CodexOAuthIssue.credentialsNotFound);
    }

    final decoded = _decodeMap(raw);
    final tokens = decoded?['tokens'];
    if (tokens is! Map<String, dynamic>) {
      throw const CodexOAuthReadException(CodexOAuthIssue.credentialsNotFound);
    }
    final accessToken =
        _string(tokens['access_token']) ?? _string(tokens['accessToken']);
    if (accessToken == null) {
      throw const CodexOAuthReadException(CodexOAuthIssue.credentialsNotFound);
    }
    final refreshToken =
        _string(tokens['refresh_token']) ?? _string(tokens['refreshToken']);
    final idToken = _string(tokens['id_token']) ?? _string(tokens['idToken']);
    final accountId =
        _string(tokens['account_id']) ??
        _string(tokens['accountId']) ??
        _accountIdFromJwt(idToken, accessToken);
    return _CodexCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      accountId: accountId,
      expiresAt: _jwtExpiration(accessToken),
      lastRefresh: DateTime.tryParse(
        _string(decoded?['last_refresh']) ?? '',
      )?.toLocal(),
    );
  }

  bool _needsRefresh(_CodexCredentials credentials) {
    final refreshToken = credentials.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    final expiresAt = credentials.expiresAt;
    if (expiresAt != null) {
      return !DateTime.now().add(_refreshWindow).isBefore(expiresAt);
    }
    final lastRefresh = credentials.lastRefresh;
    if (lastRefresh == null) {
      return true;
    }
    return DateTime.now().difference(lastRefresh) > _staleRefreshAge;
  }

  Future<_CodexCredentials> _maybeRefresh(_CodexCredentials credentials) async {
    if (!_needsRefresh(credentials)) {
      return credentials;
    }
    final expiresAt = credentials.expiresAt;
    final hardExpired =
        expiresAt != null && !DateTime.now().isBefore(expiresAt);
    final failureAt = _lastRefreshFailureAt;
    if (failureAt != null &&
        DateTime.now().difference(failureAt) < _refreshFailureCooldown) {
      if (hardExpired) {
        throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
      }
      return credentials;
    }
    try {
      final refreshed = await _refresh(credentials);
      await _persist(refreshed);
      return refreshed;
    } on CodexOAuthReadException catch (error) {
      if (error.issue == CodexOAuthIssue.unauthorized) {
        rethrow;
      }
      _lastRefreshFailureAt = DateTime.now();
      if (hardExpired) {
        rethrow;
      }
      // Not expired yet; the current token may still be accepted.
      return credentials;
    } on Object {
      _lastRefreshFailureAt = DateTime.now();
      if (hardExpired) {
        throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
      }
      return credentials;
    }
  }

  Future<_CodexCredentials> _forceRefresh(_CodexCredentials credentials) async {
    try {
      final refreshed = await _refresh(credentials);
      await _persist(refreshed);
      return refreshed;
    } on CodexOAuthReadException {
      rethrow;
    } on Object {
      throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
    }
  }

  Future<_CodexCredentials> _refresh(_CodexCredentials credentials) async {
    final refreshToken = credentials.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const CodexOAuthReadException(CodexOAuthIssue.unauthorized);
    }
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .postUrl(Uri.parse(_refreshUrl))
          .timeout(_requestTimeout);
      final requestBody = utf8.encode(
        jsonEncode({
          'client_id': _oauthClientId,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'scope': 'openid profile email',
        }),
      );
      request.headers
        ..contentType = ContentType.json
        // Send a fixed-length body; a chunked POST can be rejected by
        // strict servers and proxies.
        ..contentLength = requestBody.length;
      request.add(requestBody);
      final response = await request.close().timeout(_requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        // The token endpoint reports revoked/expired/reused refresh tokens
        // with 400/401/403 responses; anything else is transient.
        if (response.statusCode == HttpStatus.badRequest ||
            response.statusCode == HttpStatus.unauthorized ||
            response.statusCode == HttpStatus.forbidden) {
          throw const CodexOAuthReadException(CodexOAuthIssue.unauthorized);
        }
        throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
      }
      final decoded = _decodeMap(body);
      if (decoded == null) {
        throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
      }
      final accessToken =
          _string(decoded['access_token']) ?? credentials.accessToken;
      return _CodexCredentials(
        accessToken: accessToken,
        refreshToken: _string(decoded['refresh_token']) ?? refreshToken,
        idToken: _string(decoded['id_token']) ?? credentials.idToken,
        accountId: credentials.accountId,
        expiresAt: _jwtExpiration(accessToken),
        lastRefresh: DateTime.now(),
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Persists rotated tokens back into auth.json (merged with the existing
  /// content) so the Codex CLI keeps working with the new refresh token,
  /// exactly like CodexBar and the CLI itself do. The write goes through a
  /// temporary file plus rename so a crash mid-write cannot corrupt the
  /// CLI's credentials.
  Future<void> _persist(_CodexCredentials credentials) async {
    try {
      final file = _authFile();
      var json = <String, dynamic>{};
      try {
        json = _decodeMap(await file.readAsString()) ?? <String, dynamic>{};
      } on Object {
        json = <String, dynamic>{};
      }
      final tokens = switch (json['tokens']) {
        final Map<String, dynamic> existing => existing,
        _ => <String, dynamic>{},
      };
      tokens['access_token'] = credentials.accessToken;
      if (credentials.refreshToken != null) {
        tokens['refresh_token'] = credentials.refreshToken;
      }
      if (credentials.idToken != null) {
        tokens['id_token'] = credentials.idToken;
      }
      if (credentials.accountId != null) {
        tokens['account_id'] = credentials.accountId;
      }
      json['tokens'] = tokens;
      json['last_refresh'] = DateTime.now().toUtc().toIso8601String();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode(json), flush: true);
      if (!Platform.isWindows) {
        // Keep the credentials private like the CLI does; best effort.
        await Process.run('chmod', ['600', temporary.path]);
      }
      await temporary.rename(file.path);
    } on Object {
      // Keeping the refreshed tokens in memory is still useful when the file
      // is not writable; the next CLI login rewrites it anyway.
    }
  }

  /// Returns the decoded payload on success, null when the token was
  /// rejected (401/403), and throws [CodexOAuthIssue.unavailable] for
  /// transient failures.
  Future<Map<String, dynamic>?> _fetchUsage(_CodexCredentials credentials) {
    return _fetchUsageRequest((headers) {
      headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${credentials.accessToken}',
      );
      final accountId = credentials.accountId;
      if (accountId != null && accountId.isNotEmpty) {
        headers.set('ChatGPT-Account-Id', accountId);
      }
    });
  }

  Future<Map<String, dynamic>?> _fetchUsageRequest(
    void Function(HttpHeaders headers) authorize,
  ) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse(_usageUrl))
          .timeout(_requestTimeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, 'ai-limit-status');
      authorize(request.headers);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
      }
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_requestTimeout);
      final decoded = _decodeMap(body);
      if (decoded == null) {
        throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
      }
      return decoded;
    } on CodexOAuthReadException {
      rethrow;
    } on Object {
      throw const CodexOAuthReadException(CodexOAuthIssue.unavailable);
    } finally {
      client.close(force: true);
    }
  }

  List<UsageLimit> _parseLimits(Map<String, dynamic> payload) {
    final rateLimit = payload['rate_limit'];
    if (rateLimit is! Map<String, dynamic>) {
      return const [];
    }

    final parsed = <UsageLimitType, UsageLimit>{};
    for (final key in const ['primary_window', 'secondary_window']) {
      final rawWindow = rateLimit[key];
      if (rawWindow is! Map<String, dynamic>) {
        continue;
      }
      final usedPercent = (rawWindow['used_percent'] as num?)?.toDouble();
      if (usedPercent == null) {
        continue;
      }
      final windowSeconds = (rawWindow['limit_window_seconds'] as num?)
          ?.toInt();
      final type = windowSeconds != null
          ? (windowSeconds >= Duration.secondsPerDay
                ? UsageLimitType.weekly
                : UsageLimitType.session)
          : (key == 'primary_window'
                ? UsageLimitType.session
                : UsageLimitType.weekly);
      final remaining = (100 - usedPercent).round().clamp(0, 100);
      final resetSeconds = (rawWindow['reset_at'] as num?)?.toInt();
      final limit = UsageLimit(
        type: type,
        remainingPercent: remaining,
        resetsAt: resetSeconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                resetSeconds * Duration.millisecondsPerSecond,
              ),
      );
      final existing = parsed[type];
      if (existing == null || remaining < existing.remainingPercent) {
        parsed[type] = limit;
      }
    }

    return [
      parsed[UsageLimitType.session],
      parsed[UsageLimitType.weekly],
    ].nonNulls.toList();
  }

  static String? _accountIdFromJwt(String? idToken, String accessToken) {
    for (final token in [idToken, accessToken]) {
      final payload = _jwtPayload(token);
      if (payload == null) {
        continue;
      }
      final direct = _string(payload['chatgpt_account_id']);
      if (direct != null) {
        return direct;
      }
      final auth = payload['https://api.openai.com/auth'];
      if (auth is Map<String, dynamic>) {
        final nested = _string(auth['chatgpt_account_id']);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  static DateTime? _jwtExpiration(String accessToken) {
    final exp = _jwtPayload(accessToken)?['exp'];
    if (exp is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * Duration.millisecondsPerSecond,
    );
  }

  static Map<String, dynamic>? _jwtPayload(String? token) {
    if (token == null) {
      return null;
    }
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeMap(Object? value) {
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

  static String? _string(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static String _joinPath(String directory, String name) {
    final separator = Platform.isWindows ? r'\' : '/';
    final trimmed = directory.endsWith('/') || directory.endsWith(r'\')
        ? directory.substring(0, directory.length - 1)
        : directory;
    return '$trimmed$separator$name';
  }
}

class _CodexCredentials {
  const _CodexCredentials({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.accountId,
    this.expiresAt,
    this.lastRefresh,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String? accountId;
  final DateTime? expiresAt;
  final DateTime? lastRefresh;
}
