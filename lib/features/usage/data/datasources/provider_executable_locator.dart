import 'dart:async';
import 'dart:convert';
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
      // Batch scripts (for example npm shims) only run through cmd.exe.
      // Running the bare script name from its own directory keeps every
      // argument free of quotes, sidestepping both Dart's re-escaping of a
      // pre-quoted command string (which used to mangle the arguments the
      // script received) and cmd.exe's fragile quote-stripping rules for
      // paths that contain spaces or special characters.
      final separatorIndex = path.lastIndexOf(RegExp(r'[\\/]'));
      final directory = separatorIndex > 0
          ? path.substring(0, separatorIndex)
          : null;
      final scriptName = separatorIndex >= 0
          ? path.substring(separatorIndex + 1)
          : path;
      return Process.start('cmd.exe', [
        '/d',
        '/c',
        scriptName,
        ...arguments,
      ], workingDirectory: directory);
    }
    return Process.start(path, arguments);
  }

  String posixCommand(List<String> arguments) {
    return [path, ...arguments].map(_quotePosixArgument).join(' ');
  }
}

class ProviderExecutableLocator {
  const ProviderExecutableLocator();

  static const _pathProbeTimeout = Duration(seconds: 3);
  static const _loginShellTimeout = Duration(seconds: 6);

  static Future<List<String>>? _loginShellPathFuture;

  Future<ProviderExecutable?> find(UsageProvider provider) async {
    // 1) Explicit override, mirroring CodexBar's CODEX_CLI_PATH and
    // CLAUDE_CLI_PATH escape hatches.
    final override =
        Platform.environment[switch (provider) {
          UsageProvider.codex => 'CODEX_CLI_PATH',
          UsageProvider.claude => 'CLAUDE_CLI_PATH',
        }];
    if (override != null &&
        override.isNotEmpty &&
        await _isExecutableFile(override)) {
      return ProviderExecutable(override);
    }

    // 2) Scan the effective PATH. On macOS this includes the login shell's
    // PATH, because GUI apps launch with a minimal PATH that misses
    // Homebrew, nvm, npm-global and similar installs.
    final names = _executableNames(provider);
    for (final directory in await _searchDirectories()) {
      for (final name in names) {
        final candidate = _join(directory, name);
        if (await _isExecutableFile(candidate)) {
          return ProviderExecutable(candidate);
        }
      }
    }

    // 3) which / where as a safety net for lookup rules the scan misses.
    final resolved = await _resolveFromPath(provider);
    if (resolved != null) {
      return ProviderExecutable(resolved);
    }

    // 4) Well-known install locations that are usually not on a GUI PATH.
    for (final candidate in await _wellKnownPaths(provider)) {
      if (await _isExecutableFile(candidate)) {
        return ProviderExecutable(candidate);
      }
    }
    return null;
  }

  List<String> _executableNames(UsageProvider provider) {
    final executableName = _executableName(provider);
    if (Platform.isWindows) {
      return ['$executableName.exe', '$executableName.cmd'];
    }
    return [executableName];
  }

  String _executableName(UsageProvider provider) {
    return switch (provider) {
      UsageProvider.codex => 'codex',
      UsageProvider.claude => 'claude',
    };
  }

  Future<List<String>> _searchDirectories() async {
    final directories = <String>[];
    if (!Platform.isWindows) {
      directories.addAll(await _loginShellPath());
    }
    final pathValue = Platform.environment['PATH'];
    if (pathValue != null && pathValue.isNotEmpty) {
      directories.addAll(pathValue.split(Platform.isWindows ? ';' : ':'));
    }
    final seen = <String>{};
    return [
      for (final directory in directories)
        if (directory.isNotEmpty && seen.add(directory)) directory,
    ];
  }

  /// Captures the login shell's PATH once per app run, the same trick
  /// CodexBar uses so version-manager installs (nvm, fnm, mise) resolve.
  static Future<List<String>> _loginShellPath() {
    return _loginShellPathFuture ??= _captureLoginShellPath();
  }

  static Future<List<String>> _captureLoginShellPath() async {
    var shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    if (shell.isEmpty || shell.endsWith('fish')) {
      // fish formats $PATH differently; zsh is always present on macOS and
      // sources the common version-manager setup files.
      shell = '/bin/zsh';
    }
    const marker = '__AI_LIMIT_STATUS_PATH__';
    try {
      final process = await Process.start(shell, const [
        '-l',
        '-i',
        '-c',
        'printf "$marker%s$marker" "\$PATH"',
      ]);
      final outputFuture = process.stdout.transform(utf8.decoder).join();
      unawaited(process.stderr.drain<void>());
      await process.exitCode.timeout(
        _loginShellTimeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final output = await outputFuture.timeout(_loginShellTimeout);
      final start = output.indexOf(marker);
      final end = output.lastIndexOf(marker);
      if (start < 0 || end <= start + marker.length) {
        return const [];
      }
      return output
          .substring(start + marker.length, end)
          .split(':')
          .where((part) => part.isNotEmpty)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<List<String>> _wellKnownPaths(UsageProvider provider) async {
    final environment = Platform.environment;
    final executableName = _executableName(provider);

    if (Platform.isWindows) {
      final userProfile = environment['USERPROFILE'];
      final localAppData = environment['LOCALAPPDATA'];
      final roamingAppData = environment['APPDATA'];
      return [
        if (userProfile != null) ...[
          '$userProfile\\.local\\bin\\$executableName.exe',
          if (provider == UsageProvider.claude)
            '$userProfile\\.claude\\local\\$executableName.exe',
          '$userProfile\\scoop\\shims\\$executableName.exe',
          '$userProfile\\scoop\\shims\\$executableName.cmd',
          '$userProfile\\.bun\\bin\\$executableName.exe',
        ],
        if (localAppData != null) ...[
          '$localAppData\\Microsoft\\WinGet\\Links\\$executableName.exe',
          '$localAppData\\Programs\\$executableName\\$executableName.exe',
          '$localAppData\\Volta\\bin\\$executableName.exe',
        ],
        if (roamingAppData != null) '$roamingAppData\\npm\\$executableName.cmd',
      ];
    }

    final home = environment['HOME'];
    return [
      if (provider == UsageProvider.codex && Platform.isMacOS) ...[
        if (home != null) ...[
          '$home/Applications/ChatGPT.app/Contents/Resources/codex',
          '$home/Applications/Codex.app/Contents/Resources/codex',
        ],
        '/Applications/ChatGPT.app/Contents/Resources/codex',
        '/Applications/Codex.app/Contents/Resources/codex',
      ],
      if (Platform.isMacOS) '/opt/homebrew/bin/$executableName',
      '/usr/local/bin/$executableName',
      if (home != null) ...[
        '$home/.local/bin/$executableName',
        if (provider == UsageProvider.claude) ...[
          '$home/.claude/local/$executableName',
          '$home/.claude/bin/$executableName',
        ],
        '$home/.npm-global/bin/$executableName',
        '$home/.volta/bin/$executableName',
        '$home/.bun/bin/$executableName',
        '$home/.yarn/bin/$executableName',
        ...await _versionManagerBinPaths(home, executableName),
      ],
    ];
  }

  /// nvm, fnm and mise keep per-version bin directories that never appear on
  /// a GUI app's PATH; scan them directly as a last resort.
  Future<List<String>> _versionManagerBinPaths(
    String home,
    String executableName,
  ) async {
    final roots = [
      '$home/.nvm/versions/node',
      '$home/Library/Application Support/fnm/node-versions',
      '$home/.local/share/fnm/node-versions',
      '$home/.local/share/mise/installs/node',
    ];
    final candidates = <String>[];
    for (final root in roots) {
      try {
        final directory = Directory(root);
        if (!await directory.exists()) {
          continue;
        }
        final versions = <String>[];
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is Directory) {
            versions.add(entry.path);
          }
        }
        // Highest-sorting version first so the newest install usually wins.
        versions.sort((a, b) => b.compareTo(a));
        for (final version in versions) {
          candidates
            ..add('$version/bin/$executableName')
            ..add('$version/installation/bin/$executableName');
        }
      } on Object {
        continue;
      }
    }
    return candidates;
  }

  Future<String?> _resolveFromPath(UsageProvider provider) async {
    final executableName = _executableName(provider);
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where.exe' : 'which',
        [executableName],
      ).timeout(_pathProbeTimeout);
      if (result.exitCode != 0) {
        return null;
      }
      for (final line in result.stdout.toString().split(RegExp(r'[\r\n]+'))) {
        final path = line.trim();
        if (path.isNotEmpty && await _isExecutableFile(path)) {
          return path;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<bool> _isExecutableFile(String path) async {
    if (path.isEmpty) {
      return false;
    }
    try {
      if (!await File(path).exists()) {
        return false;
      }
      if (Platform.isWindows) {
        return true;
      }
      final stat = await File(path).stat();
      // Any execute bit (owner, group, or other).
      return (stat.mode & 0x49) != 0;
    } on Object {
      return false;
    }
  }

  String _join(String directory, String name) {
    final separator = Platform.isWindows ? r'\' : '/';
    final trimmed = directory.endsWith('/') || directory.endsWith(r'\')
        ? directory.substring(0, directory.length - 1)
        : directory;
    return '$trimmed$separator$name';
  }
}

String _quotePosixArgument(String value) {
  return "'${value.replaceAll("'", "'\\''")}'";
}

/// Terminates a provider process, including the whole tree on Windows where
/// the CLI may run behind a cmd.exe shim whose children a plain kill would
/// orphan.
Future<void> terminateProviderProcess(Process process) async {
  if (Platform.isWindows) {
    try {
      await Process.run('taskkill', [
        '/pid',
        '${process.pid}',
        '/T',
        '/F',
      ]).timeout(const Duration(seconds: 5));
      return;
    } on Object {
      // Fall through to the plain kill below.
    }
  }
  process.kill();
}
