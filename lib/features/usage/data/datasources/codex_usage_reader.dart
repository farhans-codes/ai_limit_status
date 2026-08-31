import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/codex_oauth_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/provider_executable_locator.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class CodexUsageReader {
  const CodexUsageReader(this._executableLocator, this._oauthReader);

  /// The app-server handshake includes a cold process start (on Windows
  /// often a node shim), so give the first response more headroom.
  static const _initializeTimeout = Duration(seconds: 15);
  static const _requestTimeout = Duration(seconds: 10);

  final ProviderExecutableLocator _executableLocator;
  final CodexOAuthUsageReader _oauthReader;

  Future<ProviderUsageModel> read() async {
    // Mirror CodexBar's auto mode: prefer the OAuth strategy (auth.json plus
    // the usage API) and fall back to the CLI app-server only for issues the
    // CLI can actually repair, so transient network errors never spawn
    // processes in a loop.
    try {
      return await _oauthReader.read();
    } on CodexOAuthReadException catch (error) {
      switch (error.issue) {
        case CodexOAuthIssue.credentialsNotFound:
          return _readFromCliOrWeb(oauthCredentialsExisted: false);
        case CodexOAuthIssue.unauthorized:
          return _readFromCliOrWeb(oauthCredentialsExisted: true);
        case CodexOAuthIssue.unavailable:
          return _readFromWebOrThrow(
            const UsageReadException(UsageConnectionIssue.unavailable),
          );
      }
    }
  }

  Future<ProviderUsageModel> _readFromCliOrWeb({
    required bool oauthCredentialsExisted,
  }) async {
    try {
      return await _readFromCli(
        oauthCredentialsExisted: oauthCredentialsExisted,
      );
    } on UsageReadException catch (error) {
      return _readFromWebOrThrow(error);
    }
  }

  Future<ProviderUsageModel> _readFromWebOrThrow(
    UsageReadException originalError,
  ) async {
    if (Platform.isMacOS) {
      try {
        return await _oauthReader.readFromWeb();
      } on CodexOAuthReadException {
        // Preserve the primary OAuth/CLI error when the optional browser
        // fallback is unavailable too.
      }
    }
    throw originalError;
  }

  Future<ProviderUsageModel> _readFromCli({
    required bool oauthCredentialsExisted,
  }) async {
    try {
      return await _readFromAppServer();
    } on UsageReadException catch (error) {
      if (error.issue == UsageConnectionIssue.cliNotFound &&
          oauthCredentialsExisted) {
        // Tokens exist but were rejected, and no CLI is present to repair
        // them: the account needs a fresh sign-in rather than an install.
        throw const UsageReadException(UsageConnectionIssue.notSignedIn);
      }
      rethrow;
    }
  }

  Future<ProviderUsageModel> _readFromAppServer() async {
    final process = await _startProcess();
    // A CLI that exits immediately (for example an outdated version that
    // does not know app-server) closes stdin; without a listener that
    // broken-pipe error would surface as an unhandled async exception.
    process.stdin.done.ignore();
    final lines = StreamIterator<String>(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    unawaited(process.stderr.drain<void>());

    try {
      process.stdin.writeln(
        jsonEncode({
          'id': 1,
          'method': 'initialize',
          'params': {
            'clientInfo': {'name': 'limit-status', 'version': '0.3.0'},
            'capabilities': {'experimentalApi': true},
          },
        }),
      );
      await _responseFor(lines, 1, _initializeTimeout);
      process.stdin.writeln(jsonEncode({'method': 'initialized'}));
      process.stdin.writeln(
        jsonEncode({
          'id': 2,
          'method': 'account/rateLimits/read',
          'params': null,
        }),
      );

      final response = await _responseFor(lines, 2, _requestTimeout);
      final result = response['result'];
      if (result is! Map<String, dynamic>) {
        throw const UsageReadException(UsageConnectionIssue.notSignedIn);
      }

      final activeRateLimits = result['rateLimits'];
      if (activeRateLimits is! Map<String, dynamic>) {
        throw const UsageReadException(UsageConnectionIssue.notSignedIn);
      }

      final limits = _parseLimits(activeRateLimits);
      if (limits.isEmpty) {
        throw const UsageReadException(UsageConnectionIssue.unavailable);
      }

      return ProviderUsageModel(
        provider: UsageProvider.codex,
        limits: limits,
        isConnected: true,
        isInstalled: true,
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    } finally {
      await lines.cancel();
      await terminateProviderProcess(process);
    }
  }

  Future<Process> _startProcess() async {
    final executable = await _executableLocator.find(UsageProvider.codex);
    if (executable == null) {
      throw const UsageReadException(UsageConnectionIssue.cliNotFound);
    }
    try {
      // Same launch arguments CodexBar uses: a read-only sandbox with
      // approvals disabled, so the app-server can never prompt or mutate
      // anything, and no extra flags that newer CLI versions reject.
      return await executable.start(const [
        '-s',
        'read-only',
        '-a',
        'never',
        'app-server',
      ]);
    } on ProcessException {
      throw const UsageReadException(UsageConnectionIssue.cliNotFound);
    }
  }

  Future<Map<String, dynamic>> _responseFor(
    StreamIterator<String> lines,
    int requestId,
    Duration timeout,
  ) async {
    return _readResponse(lines, requestId).timeout(timeout);
  }

  Future<Map<String, dynamic>> _readResponse(
    StreamIterator<String> lines,
    int requestId,
  ) async {
    while (await lines.moveNext()) {
      final Object? decoded;
      try {
        decoded = jsonDecode(lines.current);
      } on FormatException {
        // Ignore non-JSON noise (for example npm shim banners) on stdout.
        continue;
      }
      if (decoded is Map<String, dynamic> && decoded['id'] == requestId) {
        if (decoded['error'] != null) {
          throw const UsageReadException(UsageConnectionIssue.unavailable);
        }
        return decoded;
      }
    }

    throw const UsageReadException(UsageConnectionIssue.unavailable);
  }

  List<UsageLimit> _parseLimits(Map<String, dynamic> rateLimits) {
    final parsed = <UsageLimitType, UsageLimit>{};

    for (final key in const ['primary', 'secondary']) {
      final rawWindow = rateLimits[key];
      if (rawWindow is! Map<String, dynamic>) {
        continue;
      }

      final usedPercent = (rawWindow['usedPercent'] as num?)?.toDouble();
      final durationMinutes = (rawWindow['windowDurationMins'] as num?)
          ?.toInt();
      if (usedPercent == null || durationMinutes == null) {
        continue;
      }

      final type = durationMinutes >= const Duration(days: 1).inMinutes
          ? UsageLimitType.weekly
          : UsageLimitType.session;
      final remaining = (100 - usedPercent).round().clamp(0, 100);
      final resetSeconds = (rawWindow['resetsAt'] as num?)?.toInt();
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
}
