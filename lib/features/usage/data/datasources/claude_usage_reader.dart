import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:ai_limit_status/core/diagnostics/app_log.dart';
import 'package:ai_limit_status/features/usage/data/datasources/browser_session_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/provider_executable_locator.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/datasources/windows_claude_credential_reader.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

/// Reads Claude subscription usage.
///
/// Sources, in order (mirroring CodexBar's planner):
///
/// 1. The Claude Code OAuth credential (`claudeAiOauth.accessToken`) from the
///    macOS keychain, `.credentials.json`, or Windows Credential Manager, sent to
///    `https://api.anthropic.com/api/oauth/usage`. When the credential lives
///    in a file this reader can also refresh it shortly before it expires and
///    writes the rotated token back so the CLI stays signed in.
/// 2. The user's claude.ai browser session (`sessionKey` cookie) from the
///    opt-in browser bridge (Windows) or the browser cookie stores (macOS),
///    sent to `https://claude.ai/api`.
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
  static const _webSessionCacheTtl = Duration(minutes: 30);

  /// Refresh a file-backed OAuth token this long before it expires so the
  /// usage request never races the expiry.
  static const _refreshLeeway = Duration(minutes: 5);

  /// Back-off after a refresh attempt fails for a transient reason.
  static const _refreshFailureCooldown = Duration(minutes: 10);

  static const _keychainChannel = MethodChannel('com.ailimitstatus/keychain');
  static const _keychainService = 'Claude Code-credentials';

  /// Claude Code's public OAuth client, used only to refresh a token the CLI
  /// itself issued. Same value CodexBar uses.
  static const _oauthClientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  static const _oauthTokenEndpoint =
      'https://platform.claude.com/v1/oauth/token';
  static const _requiredScope = 'user:profile';

  final ProviderExecutableLocator _executableLocator;
  DateTime? _rateLimitedUntil;
  String? _cachedUserAgent;
  ProviderUsageModel? _lastSuccessfulUsage;
  DateTime? _keychainDeniedAt;
  _ClaudeCredentials? _cachedCredentials;
  DateTime? _credentialsReadAt;
  DateTime? _refreshBlockedUntil;
  String? _cachedWebSessionKey;
  String? _cachedWebOrganizationId;
  DateTime? _webSessionReadAt;

  Future<ProviderUsageModel> read() async {
    final cachedUsage = _lastSuccessfulUsage;
    if (cachedUsage != null &&
        DateTime.now().difference(cachedUsage.fetchedAt) <
            _minimumFetchInterval) {
      return cachedUsage;
    }

    Map<String, dynamic>? payload;
    UsageConnectionIssue? directIssue;
    final credentials = await _readCredentialsCached();
    if (credentials != null) {
      try {
        payload = await _fetchUsageWithRefresh(credentials);
        AppLog.log('claude: OAuth usage read succeeded');
      } on UsageReadException catch (error) {
        directIssue = error.issue;
        AppLog.log('claude: OAuth usage read failed: ${error.issue.name}');
      } on Object catch (error) {
        directIssue = UsageConnectionIssue.unavailable;
        AppLog.log('claude: OAuth usage read error: ${error.runtimeType}');
      }
    } else {
      // Stored credentials count as an install even without a resolvable
      // CLI binary; only report "not installed" when both are absent.
      final executable = await _executableLocator.find(UsageProvider.claude);
      directIssue = executable == null
          ? UsageConnectionIssue.cliNotFound
          : UsageConnectionIssue.notSignedIn;
      AppLog.log('claude: no OAuth credential (${directIssue.name})');
    }

    UsageConnectionIssue? webIssue;
    if (payload == null && (Platform.isMacOS || Platform.isWindows)) {
      try {
        payload = await _fetchWebUsage();
        AppLog.log('claude: claude.ai session usage read succeeded');
      } on UsageReadException catch (error) {
        webIssue = error.issue;
        AppLog.log(
          'claude: claude.ai session read failed: ${error.issue.name}',
        );
      } on Object catch (error) {
        webIssue = UsageConnectionIssue.unavailable;
        AppLog.log(
          'claude: claude.ai session read error: ${error.runtimeType}',
        );
      }
    }
    if (payload == null) {
      throw UsageReadException(_mostActionableIssue(directIssue, webIssue));
    }

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

  /// Picks the issue the user can actually act on when every source failed.
  ///
  /// A browser session that exists but is rejected or blocked explains more
  /// than "CLI not found"; a signed-out CLI beats a missing one; and a
  /// temporary failure is reported only when nothing else applies, because
  /// `unavailable` keeps the cached snapshot instead of showing setup
  /// actions.
  UsageConnectionIssue _mostActionableIssue(
    UsageConnectionIssue? directIssue,
    UsageConnectionIssue? webIssue,
  ) {
    if (webIssue == UsageConnectionIssue.browserBlocked ||
        webIssue == UsageConnectionIssue.browserSessionExpired) {
      return directIssue == UsageConnectionIssue.notSignedIn
          ? directIssue!
          : webIssue!;
    }
    if (directIssue == UsageConnectionIssue.notSignedIn ||
        directIssue == UsageConnectionIssue.cliNotFound) {
      return directIssue!;
    }
    return directIssue ?? webIssue ?? UsageConnectionIssue.unavailable;
  }

  Future<_ClaudeCredentials?> _readCredentialsCached() async {
    final cached = _cachedCredentials;
    final readAt = _credentialsReadAt;
    // Windows stores are cheap to read and the CLI/IDE can rotate them while
    // this app stays open. Only cache reads that may prompt on macOS.
    if (!Platform.isWindows &&
        cached != null &&
        readAt != null &&
        DateTime.now().difference(readAt) < _credentialsCacheTtl) {
      return cached;
    }
    final credentials = await _readCredentials();
    _cachedCredentials = credentials;
    _credentialsReadAt = DateTime.now();
    return credentials;
  }

  Future<_ClaudeCredentials?> _readCredentials() async {
    if (Platform.isWindows) {
      // Follow Claude's active store so a leftover file cannot mask an IDE
      // sign-in after migration to Credential Manager.
      if (await _windowsUsesSecureStore()) {
        return await _readWindowsCredentials() ?? await _readCredentialsFile();
      }
      return await _readCredentialsFile() ?? await _readWindowsCredentials();
    }
    final overrideConfigDir = Platform.environment['CLAUDE_CONFIG_DIR'];
    final hasOverride =
        overrideConfigDir != null && overrideConfigDir.isNotEmpty;

    // With a custom CLAUDE_CONFIG_DIR the credentials file is authoritative.
    // Otherwise, on macOS the CLI stores credentials in the keychain first
    // and keeps the file as a fallback. Reading both sides mirrors CodexBar.
    final sources = <Future<_ClaudeCredentials?> Function()>[
      if (hasOverride) _readCredentialsFile,
      if (Platform.isMacOS) _readMacKeychainCredentials,
      if (!hasOverride) _readCredentialsFile,
    ];
    for (final source in sources) {
      final credentials = await source();
      if (credentials != null) {
        return credentials;
      }
    }
    return null;
  }

  Future<bool> _windowsUsesSecureStore() async {
    final environment = Platform.environment;
    if (environment['CLAUDE_CODE_FORCE_WINDOWS_CREDMAN'] == '1') return true;
    final home = environment['USERPROFILE'];
    if (home == null) return false;
    final config = environment['CLAUDE_CONFIG_DIR'];
    final customConfig = config != null && config.isNotEmpty;
    final root = customConfig ? config : '$home\\.claude';
    try {
      // Claude reads the legacy config first if it exists; otherwise it uses
      // .claude.json at the profile root (the home directory by default).
      final legacy = File('$root\\.config.json');
      final file = await legacy.exists()
          ? legacy
          : File('${customConfig ? config : home}\\.claude.json');
      final features = _decodeMap(
        await file.readAsString(),
      )?['cachedGrowthBookFeatures'];
      return features is Map && features['tengu_windows_credman'] == true;
    } on FileSystemException {
      return false;
    }
  }

  Future<_ClaudeCredentials?> _readWindowsCredentials() async {
    try {
      final configDir =
          Platform.environment['CLAUDE_SECURESTORAGE_CONFIG_DIR'] ??
          Platform.environment['CLAUDE_CONFIG_DIR'];
      final raw = await readWindowsClaudeCredentialDocument(
        (part) => _keychainChannel.invokeMethod<Uint8List>(
          'readClaudeWindowsCredential',
          {'part': part, 'configDir': configDir},
        ),
      ).timeout(_requestTimeout);
      // The CLI owns secure-store refreshes; never copy its secret to disk.
      return _parseCredentials(raw, writableFile: null);
    } on Object {
      return null;
    }
  }

  /// Reads the Claude CLI's keychain item the way CodexBar does: through
  /// Security.framework under this app's own identity, so macOS shows its
  /// access prompt once and "Always Allow" keeps every later read silent.
  /// The `security` command-line tool remains a fallback for older builds
  /// whose runner does not implement the channel yet.
  Future<_ClaudeCredentials?> _readMacKeychainCredentials() async {
    final deniedAt = _keychainDeniedAt;
    if (deniedAt != null &&
        DateTime.now().difference(deniedAt) < _keychainDenialCooldown) {
      return null;
    }
    String? raw;
    try {
      final response = await _keychainChannel
          .invokeMapMethod<String, Object?>('readGenericPassword', {
            'service': _keychainService,
          })
          .timeout(_keychainPromptTimeout);
      final value = response?['value'];
      if (value is String && value.isNotEmpty) {
        _keychainDeniedAt = null;
        raw = value;
      } else {
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
      }
    } on Object {
      // The channel is unavailable (old runner build) or timed out; try the
      // command-line fallback once.
      raw = await _readKeychainCredentials();
    }
    // Keychain credentials belong to the CLI, which refreshes them itself;
    // never rotate them from here.
    return _parseCredentials(raw, writableFile: null);
  }

  Future<String?> _readWebSessionKey() async {
    final cached = _cachedWebSessionKey;
    final readAt = _webSessionReadAt;
    if (cached != null &&
        readAt != null &&
        DateTime.now().difference(readAt) < _webSessionCacheTtl) {
      return cached;
    }
    try {
      final sessionKey = await readClaudeBrowserSessionKey();
      if (sessionKey == null || !sessionKey.startsWith('sk-ant-')) {
        AppLog.log('claude: no claude.ai session key available');
        return null;
      }
      AppLog.log('claude: using the claude.ai browser session');
      if (_cachedWebSessionKey != sessionKey) {
        _cachedWebOrganizationId = null;
      }
      _cachedWebSessionKey = sessionKey;
      _webSessionReadAt = DateTime.now();
      return sessionKey;
    } on Object {
      return null;
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

  /// Resolves the credentials file like CodexBar: `CLAUDE_CONFIG_DIR` is a
  /// single literal directory (no `~` expansion), and
  /// `CLAUDE_SECURESTORAGE_CONFIG_DIR` overrides where `.credentials.json`
  /// itself lives.
  File _credentialsFile() {
    final environment = Platform.environment;
    final separator = Platform.isWindows ? r'\' : '/';
    final home = Platform.isWindows
        ? environment['USERPROFILE']
        : environment['HOME'];
    final defaultRoot = '$home$separator.claude';
    final configDir = environment['CLAUDE_CONFIG_DIR'];
    var root = configDir != null && configDir.isNotEmpty
        ? configDir
        : defaultRoot;
    final secureRoot = environment['CLAUDE_SECURESTORAGE_CONFIG_DIR'];
    if (secureRoot != null) {
      root = secureRoot.isEmpty ? defaultRoot : secureRoot;
    }
    return File('$root$separator.credentials.json');
  }

  Future<_ClaudeCredentials?> _readCredentialsFile() async {
    try {
      final credentialsFile = _credentialsFile();
      if (!await credentialsFile.exists()) {
        return null;
      }
      return _parseCredentials(
        await credentialsFile.readAsString(),
        writableFile: credentialsFile,
      );
    } on Object {
      return null;
    }
  }

  _ClaudeCredentials? _parseCredentials(
    String? credentialsJson, {
    required File? writableFile,
  }) {
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
    final expiresAt = oauth['expiresAt'];
    final scopes = oauth['scopes'];
    return _ClaudeCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken is String && refreshToken.isNotEmpty
          ? refreshToken
          : null,
      expiresAt: expiresAt is num
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt())
          : null,
      scopes: scopes is List
          ? scopes.map((scope) => scope.toString()).toList()
          : const [],
      document: credentials!,
      writableFile: writableFile,
    );
  }

  /// Fetches usage, refreshing a file-backed token first when it is about
  /// to expire, and once more after an unexpected `401`.
  Future<Map<String, dynamic>> _fetchUsageWithRefresh(
    _ClaudeCredentials credentials,
  ) async {
    var current = credentials;
    if (current.scopes.isNotEmpty && !current.scopes.contains(_requiredScope)) {
      // The usage endpoint needs `user:profile`; the CLI grants it on sign-in
      // but a `claude setup-token` token may not carry it.
      AppLog.log('claude: OAuth token lacks $_requiredScope scope');
      throw const UsageReadException(UsageConnectionIssue.notSignedIn);
    }
    if (current.isExpiringWithin(_refreshLeeway)) {
      current = await _refreshCredentials(current) ?? current;
    }
    try {
      return await _fetchUsage(current);
    } on _UnauthorizedException {
      // Re-read the store on the next poll instead of retrying a token the
      // server has already rejected.
      _cachedCredentials = null;
      final refreshed = await _refreshCredentials(current);
      if (refreshed != null) {
        try {
          return await _fetchUsage(refreshed);
        } on _UnauthorizedException {
          // Fall through to the classification below.
        }
      }
      // A rejected token alongside a refresh token usually means the access
      // token lapsed and the CLI will repair it on its next run; keep the
      // cached snapshot meanwhile. Without one the user must sign in again.
      throw UsageReadException(
        current.refreshToken != null
            ? UsageConnectionIssue.unavailable
            : UsageConnectionIssue.notSignedIn,
      );
    }
  }

  /// Refreshes a file-backed OAuth credential through Claude Code's own
  /// client and writes the rotated token back to the same file so the CLI
  /// keeps working. Keychain credentials are never refreshed here.
  Future<_ClaudeCredentials?> _refreshCredentials(
    _ClaudeCredentials credentials,
  ) async {
    final refreshToken = credentials.refreshToken;
    final file = credentials.writableFile;
    if (refreshToken == null || file == null) {
      return null;
    }
    final blockedUntil = _refreshBlockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      return null;
    }

    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      final request = await client
          .postUrl(Uri.parse(_oauthTokenEndpoint))
          .timeout(_requestTimeout);
      request.headers
        ..set(
          HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded',
        )
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.write(
        Uri(
          queryParameters: {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'client_id': _oauthClientId,
          },
        ).query,
      );
      final response = await request.close().timeout(_requestTimeout);
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(_requestTimeout);
      if (response.statusCode == HttpStatus.badRequest ||
          response.statusCode == HttpStatus.unauthorized) {
        final error = _decodeMap(body)?['error'];
        AppLog.log(
          'claude: token refresh rejected (${response.statusCode}, $error)',
        );
        if (error == 'invalid_grant') {
          _cachedCredentials = null;
          // The CLI may have rotated the token concurrently; prefer whatever
          // it wrote before declaring the sign-in dead.
          final latest = await _readCredentialsFile();
          if (latest != null && latest.accessToken != credentials.accessToken) {
            AppLog.log('claude: using credential rotated by the CLI');
            _cachedCredentials = latest;
            _credentialsReadAt = DateTime.now();
            return latest;
          }
          throw const UsageReadException(UsageConnectionIssue.notSignedIn);
        }
        _refreshBlockedUntil = DateTime.now().add(_refreshFailureCooldown);
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        AppLog.log('claude: token refresh failed (${response.statusCode})');
        _refreshBlockedUntil = DateTime.now().add(_refreshFailureCooldown);
        return null;
      }
      final payload = _decodeMap(body);
      final accessToken = payload?['access_token'];
      if (accessToken is! String || accessToken.isEmpty) {
        _refreshBlockedUntil = DateTime.now().add(_refreshFailureCooldown);
        return null;
      }
      final expiresIn = payload?['expires_in'];
      final rotatedRefreshToken = payload?['refresh_token'];
      final refreshed = credentials.copyWith(
        accessToken: accessToken,
        refreshToken:
            rotatedRefreshToken is String && rotatedRefreshToken.isNotEmpty
            ? rotatedRefreshToken
            : refreshToken,
        // Anthropic returns `expires_in`; if it ever does not, assume one
        // hour rather than inheriting the old expiry and refreshing on
        // every poll.
        expiresAt: DateTime.now().add(
          expiresIn is num
              ? Duration(seconds: expiresIn.toInt())
              : const Duration(hours: 1),
        ),
      );
      await _writeCredentials(refreshed);
      _cachedCredentials = refreshed;
      _credentialsReadAt = DateTime.now();
      _refreshBlockedUntil = null;
      AppLog.log('claude: OAuth token refreshed and written back');
      return refreshed;
    } on UsageReadException {
      rethrow;
    } on Object catch (error) {
      AppLog.log('claude: token refresh error: ${error.runtimeType}');
      _refreshBlockedUntil = DateTime.now().add(_refreshFailureCooldown);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Writes the rotated credential back, preserving every other key in the
  /// file (`mcpOAuth`, scopes, subscription metadata) and replacing the file
  /// atomically so a crash cannot leave the CLI with a truncated store.
  Future<void> _writeCredentials(_ClaudeCredentials credentials) async {
    final file = credentials.writableFile;
    if (file == null) {
      return;
    }
    final document = Map<String, dynamic>.from(credentials.document);
    final oauth = Map<String, dynamic>.from(
      document['claudeAiOauth'] as Map<String, dynamic>? ?? const {},
    );
    oauth['accessToken'] = credentials.accessToken;
    if (credentials.refreshToken != null) {
      oauth['refreshToken'] = credentials.refreshToken;
    }
    final expiresAt = credentials.expiresAt;
    if (expiresAt != null) {
      oauth['expiresAt'] = expiresAt.millisecondsSinceEpoch;
    }
    document['claudeAiOauth'] = oauth;

    final temporary = File('${file.path}.ai-limit-status.tmp');
    await temporary.writeAsString(jsonEncode(document), flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      // Windows cannot rename over an open file; fall back to an in-place
      // write, which the CLI tolerates.
      await file.writeAsString(jsonEncode(document), flush: true);
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
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
      if (response.statusCode == HttpStatus.unauthorized) {
        await response.drain<void>();
        throw const _UnauthorizedException();
      }
      if (response.statusCode == HttpStatus.forbidden) {
        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(_requestTimeout);
        AppLog.log('claude: OAuth usage forbidden (403)');
        // A token without the profile scope is a sign-in problem the user
        // can fix; anything else is treated as temporary.
        throw UsageReadException(
          body.contains(_requiredScope)
              ? UsageConnectionIssue.notSignedIn
              : UsageConnectionIssue.unavailable,
        );
      }
      if (response.statusCode == HttpStatus.tooManyRequests) {
        _rateLimitedUntil =
            _parseRetryAfter(response.headers.value('retry-after')) ??
            now.add(_rateLimitCooldown);
        await response.drain<void>();
        AppLog.log('claude: OAuth usage rate limited until $_rateLimitedUntil');
        throw const UsageReadException(UsageConnectionIssue.unavailable);
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        AppLog.log('claude: OAuth usage HTTP ${response.statusCode}');
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

  Future<Map<String, dynamic>> _fetchWebUsage() async {
    var sessionKey = await _readWebSessionKey();
    if (sessionKey == null) {
      throw const UsageReadException(UsageConnectionIssue.notSignedIn);
    }

    final client = HttpClient()..connectionTimeout = _requestTimeout;
    try {
      var organizationId = _cachedWebOrganizationId;
      if (organizationId == null) {
        final organizations = await _fetchWebJson(
          client,
          Uri.https('claude.ai', '/api/organizations'),
          sessionKey,
        );
        organizationId = _selectWebOrganizationId(organizations);
        if (organizationId == null) {
          throw const UsageReadException(UsageConnectionIssue.unavailable);
        }
        _cachedWebOrganizationId = organizationId;
        sessionKey = _cachedWebSessionKey ?? sessionKey;
      }

      final payload = await _fetchWebJson(
        client,
        Uri.https(
          'claude.ai',
          '/api/organizations/${Uri.encodeComponent(organizationId)}/usage',
        ),
        sessionKey,
      );
      if (payload is! Map<String, dynamic>) {
        throw const UsageReadException(UsageConnectionIssue.unavailable);
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }

  Future<Object?> _fetchWebJson(
    HttpClient client,
    Uri uri,
    String sessionKey,
  ) async {
    final request = await client.getUrl(uri).timeout(_requestTimeout);
    request.headers
      ..set(HttpHeaders.cookieHeader, 'sessionKey=$sessionKey')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(_requestTimeout);
    _captureRotatedWebSessionKey(response);
    if (response.statusCode == HttpStatus.forbidden &&
        await _isCloudflareChallenge(response)) {
      // Typically a VPN or datacenter network; the session itself is fine,
      // so keep it and let the user know signing in again will not help.
      AppLog.log('claude: claude.ai answered with a Cloudflare challenge');
      throw const UsageReadException(UsageConnectionIssue.browserBlocked);
    }
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      await response.drain<void>();
      _cachedWebSessionKey = null;
      _cachedWebOrganizationId = null;
      _webSessionReadAt = null;
      AppLog.log(
        'claude: claude.ai rejected the session (${response.statusCode})',
      );
      throw const UsageReadException(
        UsageConnectionIssue.browserSessionExpired,
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      AppLog.log(
        'claude: claude.ai HTTP ${response.statusCode} for ${uri.path}',
      );
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    }
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(_requestTimeout);
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    }
  }

  Future<bool> _isCloudflareChallenge(HttpClientResponse response) async {
    final mitigated = response.headers.value('cf-mitigated');
    if (mitigated != null && mitigated.toLowerCase() == 'challenge') {
      await response.drain<void>();
      return true;
    }
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(_requestTimeout);
    return body.contains('Just a moment');
  }

  void _captureRotatedWebSessionKey(HttpClientResponse response) {
    final setCookies = response.headers[HttpHeaders.setCookieHeader];
    if (setCookies == null) {
      return;
    }
    for (final header in setCookies) {
      final match = RegExp(
        r'(?:^|,)\s*sessionKey=([^;,]+)',
        caseSensitive: false,
      ).firstMatch(header);
      final sessionKey = match?.group(1);
      if (sessionKey != null && sessionKey.startsWith('sk-ant-')) {
        _cachedWebSessionKey = sessionKey;
        _webSessionReadAt = DateTime.now();
        return;
      }
    }
  }

  String? _selectWebOrganizationId(Object? payload) {
    if (payload is! List) {
      return null;
    }
    final organizations = payload.whereType<Map<String, dynamic>>().toList();
    if (organizations.isEmpty) {
      return null;
    }

    bool hasCapability(Map<String, dynamic> organization, String capability) {
      final capabilities = organization['capabilities'];
      return capabilities is List &&
          capabilities.any(
            (value) => value.toString().toLowerCase() == capability,
          );
    }

    bool isApiOnly(Map<String, dynamic> organization) {
      final capabilities = organization['capabilities'];
      return capabilities is List &&
          capabilities.isNotEmpty &&
          capabilities.every(
            (value) => value.toString().toLowerCase() == 'api',
          );
    }

    final selected = organizations.firstWhere(
      (organization) => hasCapability(organization, 'chat'),
      orElse: () => organizations.firstWhere(
        (organization) => !isApiOnly(organization),
        orElse: () => organizations.first,
      ),
    );
    final id = selected['uuid'];
    return id is String && id.isNotEmpty ? id : null;
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
    required this.refreshToken,
    required this.expiresAt,
    required this.scopes,
    required this.document,
    required this.writableFile,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final List<String> scopes;

  /// The full decoded credential document, kept so a refresh can write the
  /// file back without dropping keys this app does not understand.
  final Map<String, dynamic> document;

  /// The file that may be rewritten after a refresh; `null` for keychain or
  /// read-only sources.
  final File? writableFile;

  bool isExpiringWithin(Duration leeway) {
    final expiry = expiresAt;
    // Like CodexBar, treat a missing expiry as expired so a stale file token
    // is refreshed rather than sent blindly.
    return expiry == null || DateTime.now().add(leeway).isAfter(expiry);
  }

  _ClaudeCredentials copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return _ClaudeCredentials(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      scopes: scopes,
      document: document,
      writableFile: writableFile,
    );
  }
}

/// Internal signal that the usage endpoint rejected the access token.
class _UnauthorizedException implements Exception {
  const _UnauthorizedException();
}
