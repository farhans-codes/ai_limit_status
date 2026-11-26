import 'dart:io';

import 'package:ai_limit_status/core/platform/open_external_url.dart';
import 'package:ai_limit_status/features/usage/data/datasources/provider_executable_locator.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_setup_result.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/provider_setup_repository.dart';

class ProviderSetupRepositoryImpl implements ProviderSetupRepository {
  const ProviderSetupRepositoryImpl(this._executableLocator);

  static const _installTimeout = Duration(minutes: 10);
  static const _codexGuideUrl = 'https://developers.openai.com/codex/cli/';
  static const _claudeGuideUrl =
      'https://code.claude.com/docs/en/getting-started';
  static const _antigravityGuideUrl = 'https://antigravity.google/';

  final ProviderExecutableLocator _executableLocator;

  @override
  bool get supportsAutomaticInstall => Platform.isWindows;

  @override
  Future<ProviderSetupResult> install(UsageProvider provider) async {
    if (!Platform.isWindows) {
      return ProviderSetupResult.unsupported;
    }

    final winget = await _findWinget();
    if (winget == null) {
      return ProviderSetupResult.installerUnavailable;
    }

    final packageId = switch (provider) {
      UsageProvider.codex => 'OpenAI.Codex',
      UsageProvider.claude => 'Anthropic.ClaudeCode',
      UsageProvider.antigravity => null,
    };
    if (packageId == null) {
      return ProviderSetupResult.unsupported;
    }
    try {
      final result = await Process.run(winget, [
        'install',
        '--id',
        packageId,
        '--exact',
        '--source',
        'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity',
        '--silent',
      ]).timeout(_installTimeout);
      if (result.exitCode != 0) {
        return ProviderSetupResult.failed;
      }
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await _executableLocator.find(provider) != null) {
          return ProviderSetupResult.succeeded;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      return ProviderSetupResult.failed;
    } on Object {
      return ProviderSetupResult.failed;
    }
  }

  @override
  Future<ProviderSetupResult> signIn(UsageProvider provider) async {
    if (provider == UsageProvider.antigravity) {
      return _openAntigravity();
    }
    final executable = await _executableLocator.find(provider);
    if (executable == null) {
      return ProviderSetupResult.failed;
    }
    final arguments = switch (provider) {
      UsageProvider.codex => const ['login'],
      UsageProvider.claude => const ['auth', 'login'],
      UsageProvider.antigravity => const <String>[],
    };

    try {
      if (Platform.isWindows) {
        final executablePath = _quotePowerShell(executable.path);
        final argumentList = arguments.map(_quotePowerShell).join(', ');
        final result = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Start-Process -FilePath $executablePath '
              '-ArgumentList @($argumentList)',
        ]);
        return result.exitCode == 0
            ? ProviderSetupResult.succeeded
            : ProviderSetupResult.failed;
      }

      if (Platform.isMacOS) {
        final command = executable.posixCommand(arguments);
        final escapedCommand = command
            .replaceAll(r'\', r'\\')
            .replaceAll('"', r'\"');
        final result = await Process.run('/usr/bin/osascript', [
          '-e',
          'tell application "Terminal" to do script "$escapedCommand"',
          '-e',
          'tell application "Terminal" to activate',
        ]);
        return result.exitCode == 0
            ? ProviderSetupResult.succeeded
            : ProviderSetupResult.failed;
      }

      return ProviderSetupResult.unsupported;
    } on Object {
      return ProviderSetupResult.failed;
    }
  }

  @override
  Future<ProviderSetupResult> openSetupGuide(UsageProvider provider) async {
    final url = switch (provider) {
      UsageProvider.codex => _codexGuideUrl,
      UsageProvider.claude => _claudeGuideUrl,
      UsageProvider.antigravity => _antigravityGuideUrl,
    };
    return await openExternalUrl(Uri.parse(url))
        ? ProviderSetupResult.succeeded
        : ProviderSetupResult.failed;
  }

  /// Antigravity is read from its running app, so "signing in" is opening it.
  Future<ProviderSetupResult> _openAntigravity() async {
    if (!Platform.isMacOS) {
      return ProviderSetupResult.unsupported;
    }
    for (final app in const ['Antigravity', 'Antigravity IDE']) {
      try {
        final result = await Process.run('/usr/bin/open', ['-a', app]);
        if (result.exitCode == 0) {
          return ProviderSetupResult.succeeded;
        }
      } on Object {
        continue;
      }
    }
    return ProviderSetupResult.failed;
  }

  Future<String?> _findWinget() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final candidates = [
      if (localAppData != null)
        '$localAppData\\Microsoft\\WindowsApps\\winget.exe',
      'winget.exe',
    ];
    for (final candidate in candidates) {
      if (candidate.contains(r'\')) {
        if (await File(candidate).exists()) {
          return candidate;
        }
        continue;
      }
      try {
        final result = await Process.run('where.exe', [candidate]);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().split(RegExp(r'[\r\n]+')).first;
          if (path.isNotEmpty) {
            return path;
          }
        }
      } on Object {
        continue;
      }
    }
    return null;
  }
}

String _quotePowerShell(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
