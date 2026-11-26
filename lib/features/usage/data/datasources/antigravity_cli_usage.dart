import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_limit_status/features/usage/data/datasources/antigravity_usage_reader.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

/// Reads Antigravity quota by asking the `agy` command-line tool for its usage
/// report, which works while the Antigravity app and IDE are both closed.
///
/// Each report starts a whole `agy` process and takes several seconds, so the
/// result is kept for [_reuseFor] and a failure is not retried before then.
/// A refresh waits only [_patience] for it, so the other providers are not
/// held up; a report that arrives later is picked up by the next refresh.
///
/// macOS only for now: the browser guard below relies on `agy` opening the
/// sign-in page through `open`, which is not how Windows opens a browser.
abstract final class AntigravityCliUsage {
  static const _reuseFor = Duration(minutes: 10);
  static const _patience = Duration(seconds: 2);
  static const _versionTimeout = Duration(seconds: 3);
  static const _reportTimeout = Duration(seconds: 45);
  static const _maximumOutputBytes = 1024 * 1024;

  /// Usage reports exist from this version; older ones would treat the
  /// command as a prompt for the model.
  static const _firstVersionWithReports = [1, 1, 11];

  static DateTime? _lastAttempt;
  static List<UsageLimit>? _lastLimits;
  static Future<List<UsageLimit>?>? _running;

  /// The limits from the latest report, or `null` when `agy` is missing, too
  /// old, signed out, or has not answered yet.
  static Future<List<UsageLimit>?> read() {
    final lastAttempt = _lastAttempt;
    if (_running == null &&
        lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < _reuseFor) {
      return Future.value(_lastLimits);
    }
    final report = _running ??= _report().whenComplete(() => _running = null);
    return report.timeout(_patience, onTimeout: () => null);
  }

  static Future<List<UsageLimit>?> _report() async {
    _lastAttempt = DateTime.now();
    _lastLimits = null;
    if (!Platform.isMacOS) {
      return null;
    }
    final executable = await _executable();
    if (executable == null || !await _supportsReports(executable)) {
      return null;
    }
    return _lastLimits = await _runReport(executable);
  }

  /// Where `agy` is usually installed. The Antigravity IDE keeps its own
  /// copy under `~/.gemini/bin`.
  static Future<String?> _executable() async {
    final home = Platform.environment['HOME'];
    final candidates = [
      if (home != null) ...['$home/.gemini/bin/agy', '$home/.local/bin/agy'],
      '/opt/homebrew/bin/agy',
      '/usr/local/bin/agy',
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  static Future<bool> _supportsReports(String executable) async {
    try {
      final result = await Process.run(
        executable,
        const ['--version'],
        environment: const {'AGY_CLI_DISABLE_AUTO_UPDATE': 'true'},
      ).timeout(_versionTimeout);
      final match = RegExp(
        r'^(\d+)\.(\d+)\.(\d+)$',
      ).firstMatch(result.stdout.toString().trim());
      if (match == null) {
        return false;
      }
      for (var part = 0; part < 3; part++) {
        final difference =
            int.parse(match[part + 1]!) - _firstVersionWithReports[part];
        if (difference != 0) {
          return difference > 0;
        }
      }
      return true;
    } on Object {
      return false;
    }
  }

  static Future<List<UsageLimit>?> _runReport(String executable) async {
    final directory = await Directory.systemTemp.createTemp('agy-usage-');
    Process? process;
    try {
      // When its saved sign-in no longer works, agy opens the browser to
      // sign in again. A background check must never do that, so it finds
      // these launchers first and they refuse.
      for (final launcher in const ['open', 'xdg-open']) {
        final file = File('${directory.path}/$launcher');
        await file.writeAsString('#!/bin/sh\nexit 1\n');
        final made = await Process.run('/bin/chmod', ['700', file.path]);
        if (made.exitCode != 0) {
          return null;
        }
      }
      process = await Process.start(
        executable,
        const [
          '-p',
          '/usage',
          '--output-format',
          'json',
          '--print-timeout',
          '30s',
        ],
        workingDirectory: directory.path,
        environment: {
          'PATH': '${directory.path}:${Platform.environment['PATH'] ?? ''}',
          'BROWSER': '${directory.path}/open',
          'AGY_CLI_DISABLE_AUTO_UPDATE': 'true',
        },
      );
      await process.stdin.close();
      unawaited(process.stderr.drain<void>());
      final output = BytesBuilder(copy: false);
      await for (final chunk in process.stdout.timeout(_reportTimeout)) {
        output.add(chunk);
        if (output.length > _maximumOutputBytes) {
          return null;
        }
      }
      if (await process.exitCode.timeout(_reportTimeout) != 0) {
        return null;
      }
      final limits = parseReport(
        jsonDecode(utf8.decode(output.takeBytes(), allowMalformed: true)),
      );
      return limits.isEmpty ? null : limits;
    } on Object {
      return null;
    } finally {
      process?.kill(ProcessSignal.sigkill);
      try {
        await directory.delete(recursive: true);
      } on Object {
        // A leftover empty folder in the temporary directory is harmless.
      }
    }
  }

  /// Maps the JSON of `agy -p /usage --output-format json` to limits.
  static List<UsageLimit> parseReport(Object? decoded) {
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'SUCCESS') {
      return const [];
    }
    final command = decoded['command'];
    if (command is! Map<String, dynamic> || command['name'] != 'usage') {
      return const [];
    }
    return AntigravityUsageReader.parseQuotaSummary(command['data']);
  }
}
