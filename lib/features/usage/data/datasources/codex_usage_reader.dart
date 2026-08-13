import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class CodexUsageReader {
  const CodexUsageReader();

  static const _timeout = Duration(seconds: 8);

  Future<ProviderUsageModel> read() async {
    final process = await _startProcess();
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
            'clientInfo': {'name': 'limit-status', 'version': '0.1.0'},
            'capabilities': {'experimentalApi': true},
          },
        }),
      );
      await _responseFor(lines, 1);
      process.stdin.writeln(jsonEncode({'method': 'initialized'}));
      process.stdin.writeln(
        jsonEncode({
          'id': 2,
          'method': 'account/rateLimits/read',
          'params': null,
        }),
      );

      final response = await _responseFor(lines, 2);
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
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      throw const UsageReadException(UsageConnectionIssue.unavailable);
    } finally {
      await lines.cancel();
      process.kill();
    }
  }

  Future<Process> _startProcess() async {
    final home = Platform.environment['HOME'];
    final candidates = <String>[
      if (Platform.isMacOS)
        '/Applications/ChatGPT.app/Contents/Resources/codex',
      if (Platform.isMacOS) '/opt/homebrew/bin/codex',
      if (Platform.isMacOS) '/usr/local/bin/codex',
      if (Platform.isMacOS && home != null) '$home/.local/bin/codex',
      if (Platform.isWindows) 'codex.exe' else 'codex',
    ];

    for (final candidate in candidates) {
      try {
        return await Process.start(candidate, const ['app-server', '--stdio']);
      } on ProcessException {
        continue;
      }
    }

    throw const UsageReadException(UsageConnectionIssue.cliNotFound);
  }

  Future<Map<String, dynamic>> _responseFor(
    StreamIterator<String> lines,
    int requestId,
  ) async {
    return _readResponse(lines, requestId).timeout(_timeout);
  }

  Future<Map<String, dynamic>> _readResponse(
    StreamIterator<String> lines,
    int requestId,
  ) async {
    while (await lines.moveNext()) {
      final decoded = jsonDecode(lines.current);
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
