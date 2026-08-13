import 'dart:io';

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
    };
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
    final executable = await _executableLocator.find(provider);
    if (executable == null) {
      return ProviderSetupResult.failed;
    }
    final arguments = switch (provider) {
      UsageProvider.codex => const ['login'],
      UsageProvider.claude => const ['auth', 'login'],
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
    };
    try {
      final ProcessResult result;
      if (Platform.isWindows) {
        result = await Process.run('cmd.exe', ['/d', '/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        result = await Process.run('/usr/bin/open', [url]);
      } else {
        result = await Process.run('xdg-open', [url]);
      }
      return result.exitCode == 0
          ? ProviderSetupResult.succeeded
          : ProviderSetupResult.failed;
    } on Object {
      return ProviderSetupResult.failed;
    }
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
