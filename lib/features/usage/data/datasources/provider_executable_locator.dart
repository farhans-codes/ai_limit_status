import 'dart:io';

import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class ProviderExecutable {
  const ProviderExecutable(this.path);

  final String path;

  bool get _isWindowsScript {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.cmd') || lowerPath.endsWith('.bat');
  }

  Future<Process> start(List<String> arguments) {
    if (Platform.isWindows && _isWindowsScript) {
      return Process.start('cmd.exe', [
        '/d',
        '/s',
        '/c',
        '"${windowsCommand(arguments)}"',
      ]);
    }
    return Process.start(path, arguments);
  }

  String windowsCommand(List<String> arguments) {
    return [path, ...arguments].map(_quoteWindowsArgument).join(' ');
  }

  String posixCommand(List<String> arguments) {
    return [path, ...arguments].map(_quotePosixArgument).join(' ');
  }
}

class ProviderExecutableLocator {
  const ProviderExecutableLocator();

  Future<ProviderExecutable?> find(UsageProvider provider) async {
    for (final candidate in _candidates(provider)) {
      if (candidate.contains('/') || candidate.contains(r'\')) {
        if (await File(candidate).exists()) {
          return ProviderExecutable(candidate);
        }
        continue;
      }

      final resolved = await _resolveFromPath(candidate);
      if (resolved != null) {
        return ProviderExecutable(resolved);
      }
    }
    return null;
  }

  List<String> _candidates(UsageProvider provider) {
    final environment = Platform.environment;
    final home = environment['HOME'];
    final userProfile = environment['USERPROFILE'];
    final localAppData = environment['LOCALAPPDATA'];
    final roamingAppData = environment['APPDATA'];
    final executableName = switch (provider) {
      UsageProvider.codex => 'codex',
      UsageProvider.claude => 'claude',
    };

    if (Platform.isWindows) {
      return [
        '$executableName.exe',
        '$executableName.cmd',
        if (userProfile != null)
          '$userProfile\\.local\\bin\\$executableName.exe',
        if (localAppData != null)
          '$localAppData\\Microsoft\\WinGet\\Links\\$executableName.exe',
        if (localAppData != null)
          '$localAppData\\Programs\\$executableName\\$executableName.exe',
        if (roamingAppData != null) '$roamingAppData\\npm\\$executableName.cmd',
      ];
    }

    return [
      if (provider == UsageProvider.codex && Platform.isMacOS)
        '/Applications/ChatGPT.app/Contents/Resources/codex',
      if (Platform.isMacOS) '/opt/homebrew/bin/$executableName',
      if (Platform.isMacOS) '/usr/local/bin/$executableName',
      if (home != null) '$home/.local/bin/$executableName',
      executableName,
    ];
  }

  Future<String?> _resolveFromPath(String executableName) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where.exe' : 'which',
        [executableName],
      ).timeout(const Duration(seconds: 3));
      if (result.exitCode != 0) {
        return null;
      }
      for (final line in result.stdout.toString().split(RegExp(r'[\r\n]+'))) {
        final path = line.trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }
}

String _quoteWindowsArgument(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

String _quotePosixArgument(String value) {
  return "'${value.replaceAll("'", "'\\''")}'";
}
